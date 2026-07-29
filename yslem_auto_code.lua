-- yslem_auto_code.lua

local cloneref = cloneref or function(o) return o end
local Players           = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService        = cloneref(game:GetService("RunService"))
local UserInputService  = cloneref(game:GetService("UserInputService"))
local LP                = Players.LocalPlayer
local PlayerGui         = LP:WaitForChild("PlayerGui")

if getgenv and getgenv().YslemStop then pcall(getgenv().YslemStop) end

-- ===================================================================
-- CONFIG
-- ===================================================================
local CFG = {
    enabled       = true,
    submitAfter   = 1,      -- accumulate N parts before submitting
    retypeInvalid = false,  -- retype code if game says "invalid"
    caseMode      = "EXACT",-- "EXACT" | "UPPER" | "lower"
    wordCount     = 1,      -- words per announcement to collect
    keywords      = { "code is", "use code", "new code", "code:", "promo", "redeem" },
}

-- ACE Duels-specific paths / GUID
local ACE_NET_PATH      = { "Packages", "Net" }
local ACE_REDEEM_GUID   = "7d14a912-1040-4867-b005-98838eb9acc4"
local KNOWN_BOX_PATH    = { "Codes", "Codes", "CodeRedeem", "TextBox" }

-- ===================================================================
-- STATE
-- ===================================================================
local _focused              = nil
local _lastBox              = nil
local _seen                 = {}
local _capturedParts        = {}
local _lastWatchedBox       = nil
local _boxTextConn          = nil
local _boxAncestryConn      = nil
local _boxVisibilityConns   = {}
local _lastNonBlankBoxText  = ""
local _pendingRejectedText  = nil
local _pendingRejectedBox   = nil
local _pendingRejectedUntil = 0
local _pendingRejectedToken = 0
local _RedeemRemote         = nil
local _NotifyRemote         = nil
local _listenConn           = nil
local _collectBuffer        = {}

-- executor upvalue APIs
local getupvalues = (debug and debug.getupvalues) or getupvalues
local getconns    = getconnections or (debug and debug.getconnections)
local setupv      = (debug and debug.setupvalue) or setupvalue

-- forward declarations (used before their definitions)
local setStatus, appendToBox, clearCapture
local rememberPending, clearPending, handleFeedback

-- ===================================================================
-- GUI root — created early so redeem logic can exclude it
-- ===================================================================
pcall(function()
    for _, n in ipairs({ "YslemAutoCode" }) do
        local cg = game:GetService("CoreGui"):FindFirstChild(n)
        if cg then cg:Destroy() end
        local pg = PlayerGui:FindFirstChild(n)
        if pg then pg:Destroy() end
    end
end)
local gui = Instance.new("ScreenGui")
gui.Name           = "YslemAutoCode"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder   = 999
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui) end
    if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
    gui.Parent = (gethui and gethui()) or PlayerGui
end

-- ===================================================================
-- REDEEM — ACE Code Sniper logic
-- ===================================================================
local function findCodeBox()
    -- 1. known path
    local node = PlayerGui
    for _, name in ipairs(KNOWN_BOX_PATH) do
        if not node then break end
        node = node:FindFirstChild(name)
    end
    if node and node:IsA("TextBox") then return node end
    -- 2. scan PlayerGui for code-hinted TextBox
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        if d:IsA("TextBox") and not d:IsDescendantOf(gui) then
            local ph = (d.PlaceholderText or ""):lower()
            local nm = d.Name:lower()
            for _, h in ipairs({ "code","promo","redeem","coupon" }) do
                if ph:find(h,1,true) or nm:find(h,1,true) then return d end
            end
        end
    end
    return nil
end

-- Kill boolean debounce flags in a function's upvalues
local function killDebounce(fn)
    if not (fn and setupv and getupvalues) then return end
    local ok, ups = pcall(getupvalues, fn)
    if ok and type(ups) == "table" then
        for i, v in pairs(ups) do
            if type(v) == "boolean" then pcall(setupv, fn, i, false) end
        end
    end
end

-- Fire FocusLost connections directly (most reliable method)
local function redeemViaBox(code)
    if not getconns then return false, "no getconnections" end
    local box = findCodeBox()
    if not box then return false, "no codebox" end
    local ok, conns = pcall(getconns, box.FocusLost)
    if not ok or type(conns) ~= "table" or #conns == 0 then return false, "no connection" end
    local fired = false
    for _, c in ipairs(conns) do
        local fn; pcall(function() fn = c.Function end)
        killDebounce(fn)
        box.Text = code; box.Active = true; box.Selectable = true
        local fok = pcall(function() if c.Enabled ~= false then c:Fire(true) end end)
        fired = fired or fok
    end
    return fired, fired and "sent" or "fire failed"
end

-- RemoteFunction fallback (ACE GUID → general RequestRedemption → getinstances)
local function resolveRedeemRemote()
    if _RedeemRemote and _RedeemRemote.Parent then return _RedeemRemote end
    _RedeemRemote = nil
    -- ACE Duels: Net package + GUID
    pcall(function()
        local net = ReplicatedStorage
        for _, part in ipairs(ACE_NET_PATH) do
            net = net:WaitForChild(part, 2)
            if not net then return end
        end
        local ok, api = pcall(require, net)
        if ok and type(api) == "table" then
            local rok, rf = pcall(function() return api:RemoteFunction(ACE_REDEEM_GUID) end)
            if rok and typeof(rf) == "Instance" then _RedeemRemote = rf end
        end
    end)
    -- General: RF/RequestRedemption folder
    if not _RedeemRemote then
        pcall(function()
            local rfFolder = ReplicatedStorage:FindFirstChild("RF")
            if not rfFolder then return end
            for _, v in ipairs(rfFolder:GetChildren()) do
                if v.Name == "RequestRedemption" and v:IsA("RemoteFunction") then
                    _RedeemRemote = v; return
                end
            end
        end)
    end
    -- Last resort: getinstances scan
    if not _RedeemRemote and getinstances then
        for _, v in ipairs(getinstances()) do
            if v.Name == "RequestRedemption" and v:IsA("RemoteFunction") then
                _RedeemRemote = v; break
            end
        end
    end
    return _RedeemRemote
end

local function redeemViaRemote(code)
    local rf = resolveRedeemRemote()
    if not rf then return false, "no remote" end
    local ok, result = pcall(function() return rf:InvokeServer(code) end)
    if not ok then return false, tostring(result) end
    return true, result
end

local function doRedeem(code)
    local ok, res = redeemViaBox(code)
    if ok then return true, res end
    return redeemViaRemote(code)
end

-- ===================================================================
-- BOX MANAGEMENT
-- ===================================================================
local function isBoxOpen(box)
    if not box or not box.Parent then return false end
    local cur = box
    while cur do
        if cur:IsA("GuiObject") and cur.Visible == false then return false end
        if cur:IsA("ScreenGui") and cur.Enabled == false then return false end
        cur = cur.Parent
    end
    return true
end

local function resolveCodeBox()
    local node = PlayerGui
    for _, name in ipairs(KNOWN_BOX_PATH) do
        if not node then break end
        node = node:FindFirstChild(name)
    end
    if node and node:IsA("TextBox") and isBoxOpen(node) then return node end
    if isBoxOpen(_focused) then return _focused end
    if isBoxOpen(_lastBox)  then return _lastBox  end
    return nil
end

local function clearBoxWatchers()
    if _boxTextConn     then pcall(function() _boxTextConn:Disconnect() end) end
    if _boxAncestryConn then pcall(function() _boxAncestryConn:Disconnect() end) end
    for _, c in ipairs(_boxVisibilityConns) do pcall(function() c:Disconnect() end) end
    _boxTextConn = nil; _boxAncestryConn = nil; _boxVisibilityConns = {}
    _lastWatchedBox = nil
end

clearCapture = function() _capturedParts = {} end

local function watchBoxReset(box)
    if not box or _lastWatchedBox == box then return end
    clearBoxWatchers()
    _lastWatchedBox = box
    if box.Text ~= "" then _lastNonBlankBoxText = box.Text end
    _boxTextConn = box:GetPropertyChangedSignal("Text"):Connect(function()
        if box.Text == "" then clearCapture()
        else _lastNonBlankBoxText = box.Text end
    end)
    _boxAncestryConn = box.AncestryChanged:Connect(function(_, parent)
        if not parent then clearCapture(); clearBoxWatchers() end
    end)
    local cur = box
    while cur do
        if cur:IsA("GuiObject") then
            _boxVisibilityConns[#_boxVisibilityConns+1] =
                cur:GetPropertyChangedSignal("Visible"):Connect(function()
                    if not isBoxOpen(box) then clearCapture(); clearBoxWatchers() end
                end)
        elseif cur:IsA("ScreenGui") then
            _boxVisibilityConns[#_boxVisibilityConns+1] =
                cur:GetPropertyChangedSignal("Enabled"):Connect(function()
                    if not isBoxOpen(box) then clearCapture(); clearBoxWatchers() end
                end)
        end
        cur = cur.Parent
    end
end

-- ===================================================================
-- REDEMPTION FEEDBACK — retype invalid
-- ===================================================================
clearPending = function()
    _pendingRejectedToken = _pendingRejectedToken + 1
    _pendingRejectedText = nil; _pendingRejectedBox = nil; _pendingRejectedUntil = 0
end

rememberPending = function(box, text, replace)
    if not CFG.retypeInvalid or not text or text == "" then return end
    if not replace and _pendingRejectedText and os.clock() <= _pendingRejectedUntil then return end
    _pendingRejectedToken = _pendingRejectedToken + 1
    local token = _pendingRejectedToken
    _pendingRejectedText = text; _pendingRejectedBox = box
    _pendingRejectedUntil = os.clock() + 8
    task.delay(8, function()
        if token == _pendingRejectedToken then clearPending() end
    end)
end

local function restoreRejected(box, prev)
    if not CFG.retypeInvalid or not prev or prev == "" then return false end
    RunService.Heartbeat:Wait()
    local target = resolveCodeBox() or box
    if not target or not isBoxOpen(target) then return false end
    local ok = pcall(function() target.Text = prev end)
    if ok then _lastBox = target; watchBoxReset(target) end
    return ok
end

handleFeedback = function(text, obj)
    if not CFG.retypeInvalid or not _pendingRejectedText then return end
    if os.clock() > _pendingRejectedUntil then clearPending(); return end
    if obj and obj:IsDescendantOf(gui) then return end
    local low = tostring(text or ""):lower()
    local bad = low:find("invalid code",1,true) or low:find("code is invalid",1,true)
        or low:find("expired",1,true) or low:find("already redeemed",1,true)
        or low:find("already used",1,true) or low:find("doesn't exist",1,true)
        or low:find("not found",1,true) or low:find("rejected",1,true)
    if not bad then return end
    local prev = _pendingRejectedText; local prevBox = _pendingRejectedBox
    local ok = restoreRejected(prevBox, prev)
    clearPending()
    if ok then setStatus("Invalid — repasted: " .. prev) end
end

-- ===================================================================
-- APPEND TO BOX — multi-part capture + submit
-- ===================================================================
appendToBox = function(text)
    if not text or text == "" then return end
    if _lastWatchedBox and not isBoxOpen(_lastWatchedBox) then
        clearCapture(); clearBoxWatchers()
    end
    local box = findCodeBox()
    _capturedParts[#_capturedParts+1] = text
    local combined = table.concat(_capturedParts)
    local count    = #_capturedParts
    if box then
        _lastBox = box
        watchBoxReset(box)
        local wasFocused = UserInputService:GetFocusedTextBox() == box
        box.Text = combined
        if wasFocused then
            pcall(function()
                box.CursorPosition = #combined + 1
                box.SelectionStart  = #combined + 1
            end)
        end
    else
        setStatus("Captured (box closed): " .. combined)
    end
    setStatus("Part " .. count .. "/" .. CFG.submitAfter .. " → " .. combined)
    if count >= CFG.submitAfter then
        _capturedParts = {}
        rememberPending(box, combined, true)
        local ok, res = doRedeem(combined)
        local success = ok and (type(res) ~= "table" or res.success or res.Success)
        if success then
            setStatus("✓ " .. combined)
        else
            local restored = restoreRejected(box, combined)
            clearPending()
            setStatus(restored and ("Invalid — repasted: " .. combined) or "Invalid / cooldown")
        end
    end
end

-- ===================================================================
-- ANNOUNCEMENT DETECTION — ACE notification remote logic
-- ===================================================================
local ACE_POSITIONS = {
    Top=1,Bottom=1,Center=1,Middle=1,Left=1,Right=1,
    TopRight=1,TopLeft=1,BottomRight=1,BottomLeft=1,
}

local function isAceAnnouncement(...)
    local args = table.pack(...)
    if args.n == 0 or typeof(args[1]) ~= "string" then return false end
    for i = 2, args.n do
        local v = args[i]
        if typeof(v) == "string"
        and (v:find("Sounds%.",1,true) or v:find("rbxassetid",1,true) or ACE_POSITIONS[v]) then
            return true
        end
    end
    return false
end

local function stripRich(text)
    return (tostring(text or ""):gsub("<[^>]->", ""))
end

local function applyCase(code)
    if CFG.caseMode == "UPPER" then return code:upper()
    elseif CFG.caseMode == "lower" then return code:lower()
    end
    return code
end

local function onAnnouncement(...)
    if not CFG.enabled then return end
    local text = stripRich(tostring((...) or ""))
    text = text:match("^%s*(.-)%s*$") or ""
    if text == "" or text:find("%s") then return end
    for w in text:gmatch("[%w_]+") do _collectBuffer[#_collectBuffer+1] = w end
    if #_collectBuffer < CFG.wordCount then return end
    local parts = {}
    for i = 1, math.min(#_collectBuffer, CFG.wordCount) do parts[i] = _collectBuffer[i] end
    _collectBuffer = {}
    local captured = applyCase(table.concat(parts))
    if captured == "" or _seen[captured] then return end
    _seen[captured] = true
    task.delay(1.25, function() _seen[captured] = nil end)
    appendToBox(captured)
end

-- ===================================================================
-- GENERAL TEXTLABEL SCANNER — for non-ACE games
-- ===================================================================
local _COMMON = {
    the=1,and=1,for=1,are=1,but=1,not=1,you=1,all=1,can=1,
    was=1,one=1,our=1,out=1,get=1,has=1,him=1,his=1,how=1,
    new=1,now=1,old=1,see=1,two=1,way=1,who=1,did=1,its=1,
}
local _BLOCKED = {
    "join","left","welcome","server","update","version","patch",
    "roblox","game","studio","player","loading","error","warning",
}

local function _isBlocked(w)
    if _COMMON[w:lower()] then return true end
    for _, b in ipairs(_BLOCKED) do
        if w:lower():find(b,1,true) then return true end
    end
    return false
end

local function _isNoise(txt)
    if not txt or #txt < 3 then return true end
    if txt:match("^%d+[:%.]?%d*$") then return true end
    if txt:match("^[%+%-]?%d+[kKmMbBgG]?$") then return true end
    if txt:match("^x%d") then return true end
    return false
end

local function _looksLike(tok)
    if not tok or #tok < 4 or #tok > 25 then return false end
    if not tok:match("^%w[%w%-_]*%w$") then return false end
    if _isBlocked(tok) then return false end
    if tok:match("^%d+[smhdSMHD]$") then return false end
    local letters = 0
    for _ in tok:gmatch("%a") do letters = letters + 1 end
    if letters < 3 then return false end
    local bare  = tok:gsub("[%-_]","")
    local allUp = bare:match("%a") ~= nil and bare == bare:upper()
    return tok:match("%d") ~= nil or (allUp and #tok >= 5)
end

local function _matchesKeyword(text)
    local low = text:lower()
    for _, kw in ipairs(CFG.keywords) do
        if kw ~= "" and low:find(kw:lower(),1,true) then return true end
    end
    return false
end

local _dedupText = ""; local _dedupTime = 0
local function dispatchText(text)
    if not CFG.enabled or _isNoise(text) then return end
    local now = tick()
    if text == _dedupText and now - _dedupTime < 0.4 then return end
    _dedupText = text; _dedupTime = now
    if not _matchesKeyword(text) then return end
    local clean = stripRich(text):match("^%s*(.-)%s*$")
    for tok in clean:gmatch("[%w][%w%-_]*") do
        if _looksLike(tok) and not _seen[tok] then
            _seen[tok] = true
            task.delay(30, function() _seen[tok] = nil end)
            appendToBox(tok)
        end
    end
end

local _watched = {}
local function watchLabel(lbl)
    if _watched[lbl] then return end
    _watched[lbl] = true
    lbl:GetPropertyChangedSignal("Text"):Connect(function()
        dispatchText(lbl.Text)
        handleFeedback(lbl.Text, lbl)
    end)
end

local function scanRoot(root)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") then watchLabel(d) end
    end
    root.DescendantAdded:Connect(function(d)
        if d:IsA("TextLabel") then task.wait(0.04); watchLabel(d) end
    end)
end

scanRoot(PlayerGui)
pcall(function() scanRoot(game:GetService("CoreGui")) end)

-- ===================================================================
-- FOCUS TRACKING
-- ===================================================================
UserInputService.TextBoxFocused:Connect(function(box)
    if box:IsDescendantOf(gui) then return end
    _focused = box; _lastBox = box
    watchBoxReset(box)
end)

UserInputService.TextBoxFocusReleased:Connect(function(box)
    if box:IsDescendantOf(gui) then return end
    if CFG.retypeInvalid then
        local submitted = box.Text ~= "" and box.Text or _lastNonBlankBoxText
        rememberPending(box, submitted, false)
    end
    if _focused == box then _focused = nil end
end)

-- ===================================================================
-- NOTIFICATION REMOTE — ACE NotificationController approach
-- ===================================================================
local function resolveNotifyRemote()
    if _NotifyRemote and _NotifyRemote.Parent then return _NotifyRemote end
    _NotifyRemote = nil
    pcall(function()
        local ok, ctrl = pcall(function()
            return require(ReplicatedStorage.Controllers:FindFirstChild("NotificationController", true))
        end)
        if not (ok and type(ctrl) == "table" and type(ctrl.Start) == "function") then return end
        if not getupvalues then return end
        local ok2, ups = pcall(getupvalues, ctrl.Start)
        if not (ok2 and type(ups) == "table") then return end
        local net = ReplicatedStorage
        for _, part in ipairs(ACE_NET_PATH) do net = net:FindFirstChild(part) if not net then return end end
        for _, v in pairs(ups) do
            if typeof(v) == "Instance" and v:IsA("RemoteEvent") and v.Parent == net then
                _NotifyRemote = v; return
            end
        end
    end)
    return _NotifyRemote
end

local function connectNotifyRemote()
    local remote = resolveNotifyRemote()
    if not remote then return end
    if getgenv then
        local prev = getgenv().YslemNotifyConn
        if prev then pcall(function() prev:Disconnect() end) end
    end
    _listenConn = remote.OnClientEvent:Connect(function(...)
        if not CFG.enabled or not isAceAnnouncement(...) then return end
        pcall(onAnnouncement, ...)
    end)
    if getgenv then getgenv().YslemNotifyConn = _listenConn end
end

task.defer(connectNotifyRemote)

if getgenv then
    getgenv().YslemStop = function()
        if _listenConn then pcall(function() _listenConn:Disconnect() end); _listenConn = nil end
        if gui then pcall(function() gui:Destroy() end) end
    end
end

-- ===================================================================
-- UI
-- ===================================================================
local C = {
    BG     = Color3.fromRGB(6, 6, 7),
    CTRL   = Color3.fromRGB(35, 35, 39),
    BORDER = Color3.fromRGB(82, 82, 89),
    WHITE  = Color3.fromRGB(245, 245, 245),
    DIM    = Color3.fromRGB(120, 120, 130),
    GREEN  = Color3.fromRGB(70, 210, 100),
    RED    = Color3.fromRGB(255, 70, 70),
}

local function mkCorner(p, r)
    local c = Instance.new("UICorner", p); c.CornerRadius = UDim.new(0, r or 8); return c
end
local function mkStroke(p, col, t)
    local s = Instance.new("UIStroke", p)
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Color = col or C.WHITE; s.Thickness = t or 1; return s
end

-- Window
local Window = Instance.new("Frame", gui)
Window.Name            = "Window"
Window.Size            = UDim2.fromOffset(240, 68)
Window.Position        = UDim2.new(1, -248, 0, 8)
Window.BackgroundColor3 = C.BG
Window.BorderSizePixel = 0
mkCorner(Window, 12)
mkStroke(Window, C.WHITE).Transparency = 0.58

-- Title
local titleLbl = Instance.new("TextLabel", Window)
titleLbl.Size             = UDim2.fromOffset(185, 22)
titleLbl.Position         = UDim2.fromOffset(10, 6)
titleLbl.BackgroundTransparency = 1
titleLbl.Font             = Enum.Font.GothamBold
titleLbl.TextSize         = 12
titleLbl.TextColor3       = C.WHITE
titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
titleLbl.Text             = "YSLEM AUTO CODE"

-- Toggle button (styled like ACE switch)
local toggleBtn = Instance.new("TextButton", Window)
toggleBtn.Name            = "Toggle"
toggleBtn.Size            = UDim2.fromOffset(46, 22)
toggleBtn.Position        = UDim2.new(1, -54, 0, 6)
toggleBtn.BackgroundColor3 = C.WHITE
toggleBtn.Font            = Enum.Font.GothamBold
toggleBtn.TextSize        = 9
toggleBtn.TextColor3      = C.BG
toggleBtn.Text            = "ON"
toggleBtn.BorderSizePixel = 0
toggleBtn.AutoButtonColor = false
mkCorner(toggleBtn, 6)
local toggleStroke = mkStroke(toggleBtn, C.WHITE)
toggleStroke.Transparency = 0.62

-- Status label
local statusLbl = Instance.new("TextLabel", Window)
statusLbl.Size            = UDim2.new(1, -12, 0, 24)
statusLbl.Position        = UDim2.fromOffset(10, 34)
statusLbl.BackgroundTransparency = 1
statusLbl.Font            = Enum.Font.Code
statusLbl.TextSize        = 11
statusLbl.TextColor3      = C.DIM
statusLbl.TextXAlignment  = Enum.TextXAlignment.Left
statusLbl.Text            = "scanning…"
statusLbl.TextTruncate    = Enum.TextTruncate.AtEnd

-- Now define setStatus (uses statusLbl)
setStatus = function(msg, col)
    statusLbl.Text       = tostring(msg or "")
    statusLbl.TextColor3 = col or C.DIM
end

-- Toggle logic
local function applyToggle(on)
    CFG.enabled              = on
    toggleBtn.Text           = on and "ON" or "OFF"
    toggleBtn.BackgroundColor3 = on and C.WHITE or C.CTRL
    toggleBtn.TextColor3     = on and C.BG or C.DIM
    toggleStroke.Transparency = on and 0.62 or 0.88
    if not on then clearCapture() end
    setStatus(on and "scanning…" or "paused", on and C.DIM or C.RED)
end

toggleBtn.MouseButton1Click:Connect(function() applyToggle(not CFG.enabled) end)

-- Drag
local _drag, _dragStart, _winStart
Window.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        _drag = true; _dragStart = inp.Position; _winStart = Window.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then _drag = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if not _drag then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement
    and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    local d = inp.Position - _dragStart
    Window.Position = UDim2.new(
        _winStart.X.Scale, _winStart.X.Offset + d.X,
        _winStart.Y.Scale, _winStart.Y.Offset + d.Y
    )
end)
