-- yslem_auto_code.lua

local cloneref = cloneref or function(o) return o end
local Players           = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService        = cloneref(game:GetService("RunService"))
local UserInputService  = cloneref(game:GetService("UserInputService"))
local HttpService       = cloneref(game:GetService("HttpService"))
local LP                = Players.LocalPlayer
local PlayerGui         = LP:WaitForChild("PlayerGui")

if getgenv and getgenv().YslemStop then pcall(getgenv().YslemStop) end

-- ===================================================================
-- CONFIG + PERSISTENCE
-- ===================================================================
local CFG_FILE = "yslem_autocode_cfg.json"
local CFG = {
    codeSniper    = true,
    autoSubmit    = true,
    submitAfter   = 1,
    retypeInvalid = false,
    riddleSolver  = false,
    caseMode      = "EXACT",  -- "EXACT" | "UPPER" | "lower"
    wordCount     = 1,
    keywords      = { "code is", "use code", "new code", "code:", "promo", "redeem" },
}

pcall(function()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    if not isfile(CFG_FILE) then return end
    local ok, dec = pcall(function() return HttpService:JSONDecode(readfile(CFG_FILE)) end)
    if not (ok and type(dec) == "table") then return end
    for _, k in ipairs({ "codeSniper","autoSubmit","retypeInvalid","riddleSolver" }) do
        if type(dec[k]) == "boolean" then CFG[k] = dec[k] end
    end
    if type(dec.submitAfter) == "number" then
        CFG.submitAfter = math.max(1, math.floor(dec.submitAfter))
    end
    if type(dec.caseMode) == "string" then CFG.caseMode = dec.caseMode end
end)

local function saveConfig()
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(CFG_FILE, HttpService:JSONEncode({
            codeSniper    = CFG.codeSniper,
            autoSubmit    = CFG.autoSubmit,
            submitAfter   = CFG.submitAfter,
            retypeInvalid = CFG.retypeInvalid,
            riddleSolver  = CFG.riddleSolver,
        }))
    end)
end

-- ACE Duels-specific
local ACE_NET_PATH    = { "Packages", "Net" }
local ACE_REDEEM_GUID = "7d14a912-1040-4867-b005-98838eb9acc4"
local KNOWN_BOX_PATH  = { "Codes", "Codes", "CodeRedeem", "TextBox" }

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
local _lastStatusMsg        = nil

local getupvalues = (debug and debug.getupvalues) or getupvalues
local getconns    = getconnections or (debug and debug.getconnections)
local setupv      = (debug and debug.setupvalue) or setupvalue

-- forward declarations
local setStatus, flashCode, appendConsoleStatus
local appendToBox, clearCapture
local rememberPending, clearPending, handleFeedback

-- ===================================================================
-- COLORS
-- ===================================================================
local C = {
    Window  = Color3.fromRGB(11, 11, 15),
    Row     = Color3.fromRGB(20, 20, 28),
    Control = Color3.fromRGB(38, 38, 54),
    Log     = Color3.fromRGB(12, 12, 17),
    White   = Color3.fromRGB(228, 230, 245),
    Text    = Color3.fromRGB(175, 178, 200),
    Dim     = Color3.fromRGB(100, 103, 125),
    Accent  = Color3.fromRGB(82,  162, 255),
    Green   = Color3.fromRGB(75,  210, 130),
    Red     = Color3.fromRGB(255, 80,  80),
}
local CC = {
    Dim   = "rgb(100,103,125)",
    Amber = "rgb(82,162,255)",
    Green = "rgb(75,210,130)",
    Red   = "rgb(255,80,80)",
    Cyan  = "rgb(150,220,255)",
}

-- ===================================================================
-- UI HELPERS
-- ===================================================================
local function addCorner(parent, r)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, r or 8)
    return c
end

local function addStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke", parent)
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Color        = color or C.White
    s.Thickness    = thickness or 1
    s.Transparency = transparency or 0
    return s
end

local function makeLabel(parent, name, text, size, pos, textSize, color, font)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Name               = name
    lbl.Size               = size
    lbl.Position           = pos
    lbl.BackgroundTransparency = 1
    lbl.Text               = text
    lbl.TextSize           = textSize or 11
    lbl.TextColor3         = color or C.Text
    lbl.Font               = font or Enum.Font.GothamMedium
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.TextYAlignment     = Enum.TextYAlignment.Center
    return lbl
end

-- ===================================================================
-- GUI ROOT — early so redeem logic can exclude it
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
    -- 2. scan for code-hinted TextBox
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

-- Kill boolean debounce upvalues in the game's FocusLost handler
local function killDebounce(fn)
    if not (fn and setupv and getupvalues) then return end
    local ok, ups = pcall(getupvalues, fn)
    if ok and type(ups) == "table" then
        for i, v in pairs(ups) do
            if type(v) == "boolean" then pcall(setupv, fn, i, false) end
        end
    end
end

-- Fire FocusLost connections directly — most reliable method
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

local function resolveRedeemRemote()
    if _RedeemRemote and _RedeemRemote.Parent then return _RedeemRemote end
    _RedeemRemote = nil
    -- ACE: Net package + GUID
    pcall(function()
        local net = ReplicatedStorage
        for _, part in ipairs(ACE_NET_PATH) do
            net = net:WaitForChild(part, 2); if not net then return end
        end
        local ok, api = pcall(require, net)
        if ok and type(api) == "table" then
            local rok, rf = pcall(function() return api:RemoteFunction(ACE_REDEEM_GUID) end)
            if rok and typeof(rf) == "Instance" then _RedeemRemote = rf end
        end
    end)
    -- General: RF/RequestRedemption
    if not _RedeemRemote then
        pcall(function()
            local rfFolder = ReplicatedStorage:FindFirstChild("RF"); if not rfFolder then return end
            for _, v in ipairs(rfFolder:GetChildren()) do
                if v.Name == "RequestRedemption" and v:IsA("RemoteFunction") then
                    _RedeemRemote = v; return
                end
            end
        end)
    end
    -- Last resort: getinstances
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
    _pendingRejectedToken += 1
    _pendingRejectedText = nil; _pendingRejectedBox = nil; _pendingRejectedUntil = 0
end

rememberPending = function(box, text, replace)
    if not CFG.retypeInvalid or not text or text == "" then return end
    if not replace and _pendingRejectedText and os.clock() <= _pendingRejectedUntil then return end
    _pendingRejectedToken += 1
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
    local bad = low:find("invalid code",1,true)    or low:find("code is invalid",1,true)
        or low:find("expired",1,true)              or low:find("already redeemed",1,true)
        or low:find("already used",1,true)         or low:find("doesn't exist",1,true)
        or low:find("not found",1,true)            or low:find("rejected",1,true)
    if not bad then return end
    local prev = _pendingRejectedText; local prevBox = _pendingRejectedBox
    local ok = restoreRejected(prevBox, prev)
    clearPending()
    if ok then
        setStatus("Invalid — repasted: " .. prev, C.Text)
        flashCode(prev, C.Red)
    end
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
        setStatus("Captured; code box is closed", C.Text)
    end

    setStatus("Pasted " .. count .. "/" .. CFG.submitAfter, C.Green)
    flashCode(combined, C.Green)

    if count >= CFG.submitAfter then
        _capturedParts = {}
        if CFG.autoSubmit then
            rememberPending(box, combined, true)
            local ok, res = doRedeem(combined)
            local success = ok and (type(res) ~= "table" or res.success or res.Success)
            if success then
                setStatus("Redeemed: " .. combined, C.Green)
            else
                local restored = restoreRejected(box, combined)
                clearPending()
                if restored then
                    setStatus("Invalid — repasted: " .. combined, C.Text)
                    flashCode(combined, C.Red)
                else
                    setStatus("Invalid / cooldown", C.Red)
                end
            end
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
    if not CFG.codeSniper then return end
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
    the=1, ["and"]=1, ["for"]=1, are=1, but=1, ["not"]=1, you=1, all=1, can=1,
    was=1, one=1, our=1, out=1, get=1, has=1, him=1, his=1, how=1,
    new=1, now=1, old=1, see=1, two=1, way=1, who=1, did=1, its=1,
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
    if not CFG.codeSniper or _isNoise(text) then return end
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
    if CFG.codeSniper then setStatus("Ready", C.Green) end
end)

UserInputService.TextBoxFocusReleased:Connect(function(box)
    if box:IsDescendantOf(gui) then return end
    local codeBox = findCodeBox()
    if box ~= codeBox and box ~= _lastBox then return end
    if CFG.retypeInvalid then
        local submitted = box.Text ~= "" and box.Text or _lastNonBlankBoxText
        rememberPending(box, submitted, false)
    end
    if _focused == box then
        _focused = nil
        if CFG.codeSniper then
            setStatus(
                (_lastBox and _lastBox.Parent) and "Ready" or "Click code box first",
                (_lastBox and _lastBox.Parent) and C.Green or C.Dim
            )
        end
    end
end)

-- ===================================================================
-- NOTIFICATION REMOTE — ACE NotificationController approach
-- ===================================================================
local function aceRemotesFromFunction(fn)
    if not getupvalues then return {} end
    local ok, ups = pcall(getupvalues, fn)
    local out = {}
    if not (ok and type(ups) == "table") then return out end
    local net = ReplicatedStorage
    for _, part in ipairs(ACE_NET_PATH) do
        net = net:FindFirstChild(part); if not net then return out end
    end
    for _, v in pairs(ups) do
        if typeof(v) == "Instance"
        and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("UnreliableRemoteEvent"))
        and v.Parent == net then
            out[#out+1] = v
        end
    end
    return out
end

local function resolveNotifyRemote()
    if _NotifyRemote and _NotifyRemote.Parent then return _NotifyRemote end
    _NotifyRemote = nil
    pcall(function()
        local ok, ctrl = pcall(function()
            return require(ReplicatedStorage.Controllers:FindFirstChild("NotificationController", true))
        end)
        if not (ok and type(ctrl) == "table" and type(ctrl.Start) == "function") then return end
        local remotes = aceRemotesFromFunction(ctrl.Start)
        if remotes[1] then _NotifyRemote = remotes[1] end
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
        if not CFG.codeSniper or not isAceAnnouncement(...) then return end
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
-- UI — Window (300×390, top-right, cadrée)
-- ===================================================================
local Window = Instance.new("Frame", gui)
Window.Name             = "Window"
Window.Size             = UDim2.fromOffset(300, 390)
Window.AnchorPoint      = Vector2.new(1, 0)
Window.Position         = UDim2.new(1, -8, 0, 8)
Window.BackgroundColor3 = C.Window
Window.BackgroundTransparency = 0.06
Window.BorderSizePixel  = 0
Window.ClipsDescendants = true
addCorner(Window, 10)
addStroke(Window, C.Accent, 1, 0.60)

-- Mobile UIScale
local uiScale = Instance.new("UIScale", Window)
uiScale.Scale = 0.92

local viewportConn
local function updateScale()
    local cam = workspace.CurrentCamera
    if not cam then uiScale.Scale = 0.92; return end
    local vp  = cam.ViewportSize
    local fit = math.min((vp.X - 16) / 300, (vp.Y - 16) / 390)
    if UserInputService.TouchEnabled then
        uiScale.Scale = math.max(0.45, math.min(0.72, fit))
    else
        uiScale.Scale = 0.92
    end
end

local function watchViewport()
    if viewportConn then viewportConn:Disconnect(); viewportConn = nil end
    local cam = workspace.CurrentCamera
    if cam then
        viewportConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    end
    updateScale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)
watchViewport()

-- Background image
local BgImg = Instance.new("ImageLabel", Window)
BgImg.Size              = UDim2.new(1,0,1,0)
BgImg.BackgroundTransparency = 1
BgImg.Image             = "https://litter.catbox.moe/2wfsx1k13uv3vbj2.png"
BgImg.ImageTransparency = 0.28
BgImg.ScaleType         = Enum.ScaleType.Crop
BgImg.ZIndex            = 1
addCorner(BgImg, 10)

-- ===================================================================
-- HEADER BAR — fond visible
-- ===================================================================
local Header = Instance.new("Frame", Window)
Header.Name             = "Header"
Header.Size             = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = Color3.fromRGB(17, 17, 24)
Header.BackgroundTransparency = 0.12
Header.BorderSizePixel  = 0
Header.Active           = true
Header.ZIndex           = 3
addCorner(Header, 10)
-- carré en bas (coins arrondis en haut seulement)
local _hbot = Instance.new("Frame", Header)
_hbot.Size = UDim2.new(1,0,0,14); _hbot.Position = UDim2.new(0,0,1,-14)
_hbot.BackgroundColor3 = Color3.fromRGB(17,17,24)
_hbot.BackgroundTransparency = 0.12; _hbot.BorderSizePixel = 0; _hbot.ZIndex = 2

makeLabel(Header, "Title", "YSLEM AUTO CODE",
    UDim2.fromOffset(190, 26), UDim2.fromOffset(14, 6), 14, C.White, Enum.Font.GothamBold)
makeLabel(Header, "Ver", "v2",
    UDim2.fromOffset(22, 14), UDim2.fromOffset(205, 18), 9, C.Accent, Enum.Font.Gotham)

-- Toggle
local ToggleBtn = Instance.new("TextButton", Header)
ToggleBtn.Name             = "Toggle"
ToggleBtn.Size             = UDim2.fromOffset(44, 22)
ToggleBtn.Position         = UDim2.new(1, -54, 0.5, -11)
ToggleBtn.BackgroundColor3 = C.Accent
ToggleBtn.BorderSizePixel  = 0
ToggleBtn.AutoButtonColor  = false
ToggleBtn.Text             = "ON"
ToggleBtn.TextSize         = 10
ToggleBtn.TextColor3       = C.Window
ToggleBtn.Font             = Enum.Font.GothamBold
addCorner(ToggleBtn, 5)
local ToggleStroke = addStroke(ToggleBtn, C.Accent, 1, 0.36)

if UserInputService.TouchEnabled then
    local tt = Instance.new("TextButton", Header)
    tt.Size = UDim2.fromOffset(62, 52); tt.Position = UDim2.new(1, -62, 0, 0)
    tt.BackgroundTransparency = 1; tt.Text = ""
    tt.AutoButtonColor = false; tt.ZIndex = 10
    tt.Activated:Connect(function() ToggleBtn.MouseButton1Click:Fire() end)
end

-- Section label helper
local function secLabel(text, yPos)
    local l = makeLabel(Window, "S_"..text, text,
        UDim2.fromOffset(200, 13), UDim2.fromOffset(14, yPos), 10, C.Accent, Enum.Font.GothamBold)
    l.ZIndex = 3; return l
end

-- ===================================================================
-- SETTINGS
-- ===================================================================
secLabel("SETTINGS", 60)

local featureStates = {}

local Settings = Instance.new("Frame", Window)
Settings.Name             = "Settings"
Settings.Size             = UDim2.new(1, 0, 0, 156)
Settings.Position         = UDim2.fromOffset(0, 73)
Settings.BackgroundTransparency = 1
Settings.ZIndex           = 3

local Console, ConsoleOutput, updateConsoleCanvas

local function scrollConsole()
    task.defer(function()
        task.wait()
        if not Console then return end
        if updateConsoleCanvas then updateConsoleCanvas() end
        local bottom = math.max(0, Console.AbsoluteCanvasSize.Y - Console.AbsoluteWindowSize.Y)
        Console.CanvasPosition = Vector2.new(0, bottom)
    end)
end

appendConsoleStatus = function(name, on)
    if not ConsoleOutput then return end
    local col  = on and CC.Green or CC.Red
    local line = '<font color="' .. CC.Dim .. '">[setting]</font> '
        .. '<font color="' .. CC.Amber .. '">' .. name .. "</font> "
        .. '<font color="' .. CC.Dim .. '">-&gt;</font> '
        .. '<font color="' .. col .. '">' .. (on and "ON" or "OFF") .. "</font>"
    ConsoleOutput.Text = ConsoleOutput.Text == "" and line
        or (ConsoleOutput.Text .. "\n\n" .. line)
    scrollConsole()
end

local function makeCard(name, pos, size)
    local card = Instance.new("Frame", Settings)
    card.Name             = name
    card.Position         = pos
    card.Size             = size
    card.BackgroundColor3 = C.Row
    card.BackgroundTransparency = 0.36
    card.BorderSizePixel  = 0
    addCorner(card, 7)
    addStroke(card, C.Accent, 1, 0.70)
    return card
end

local function makeToggleCard(parent, on, consoleName, onToggle)
    parent.Active = true
    featureStates[consoleName] = on
    local btn = Instance.new("TextButton", parent)
    btn.Name             = "State"
    btn.Size             = UDim2.fromOffset(38, 18)
    btn.Position         = UDim2.new(1, -44, 0.5, -9)
    btn.BackgroundColor3 = on and C.Accent or C.Control
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Text             = on and "ON" or "OFF"
    btn.TextSize         = 9
    btn.TextColor3       = on and C.Window or C.Dim
    btn.Font             = Enum.Font.GothamBold
    addCorner(btn, 4)
    local outline = addStroke(btn, on and C.Accent or C.Dim, 1, on and 0.36 or 0.78)
    local state = on
    local function toggle()
        state = not state
        featureStates[consoleName] = state
        btn.Text             = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and C.Accent or C.Control
        btn.TextColor3       = state and C.Window or C.Dim
        outline.Color        = state and C.Accent or C.Dim
        outline.Transparency = state and 0.36 or 0.78
        if CFG.codeSniper then appendConsoleStatus(consoleName, state) end
        if onToggle then onToggle(state) end
    end
    btn.MouseButton1Click:Connect(toggle)
    parent.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local ptr = inp.Position
        local bp  = btn.AbsolutePosition; local bs = btn.AbsoluteSize
        if not (ptr.X >= bp.X and ptr.X <= bp.X+bs.X and ptr.Y >= bp.Y and ptr.Y <= bp.Y+bs.Y) then
            toggle()
        end
    end)
    return btn
end

-- Row 1: 2 colonnes
local AutoCard = makeCard("AutoSubmit", UDim2.fromOffset(14, 0), UDim2.fromOffset(130, 44))
makeLabel(AutoCard, "T", "Auto submit",
    UDim2.new(1,-50,1,0), UDim2.fromOffset(10,0), 11, C.Text, Enum.Font.GothamMedium)
makeToggleCard(AutoCard, CFG.autoSubmit, "Auto submit", function(state)
    CFG.autoSubmit = state; saveConfig()
end)

local AICard = makeCard("AIRiddles", UDim2.fromOffset(150, 0), UDim2.fromOffset(136, 44))
makeLabel(AICard, "T", "Riddle solver",
    UDim2.new(1,-50,1,0), UDim2.fromOffset(10,0), 11, C.Text, Enum.Font.GothamMedium)
makeToggleCard(AICard, CFG.riddleSolver, "Riddle solver", function(state)
    CFG.riddleSolver = state; saveConfig()
end)

-- Submit after (counter, pleine largeur)
local DelayCard = makeCard("SubmitAfter", UDim2.fromOffset(14, 51), UDim2.fromOffset(272, 42))
makeLabel(DelayCard, "T", "Submit after",
    UDim2.fromOffset(128,42), UDim2.fromOffset(10,0), 11, C.Text, Enum.Font.GothamMedium)

local CounterShell = Instance.new("Frame", DelayCard)
CounterShell.Size              = UDim2.fromOffset(90, 28)
CounterShell.Position          = UDim2.new(1, -98, 0.5, -14)
CounterShell.BackgroundColor3  = C.Control
CounterShell.BackgroundTransparency = 0.24
CounterShell.BorderSizePixel   = 0
addCorner(CounterShell, 6)
addStroke(CounterShell, C.Accent, 1, 0.66)

local function makeCountBtn(text, pos)
    local btn = Instance.new("TextButton", CounterShell)
    btn.Size             = UDim2.fromOffset(24, 22)
    btn.Position         = pos
    btn.BackgroundColor3 = C.Window
    btn.BackgroundTransparency = 0.06
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Text             = text
    btn.TextSize         = 14
    btn.TextColor3       = C.Accent
    btn.Font             = Enum.Font.GothamBold
    addCorner(btn, 4)
    return btn
end

local MinusBtn = makeCountBtn("-", UDim2.fromOffset(3, 3))
local CountLbl = Instance.new("TextLabel", CounterShell)
CountLbl.Size               = UDim2.fromOffset(28, 22)
CountLbl.Position           = UDim2.fromOffset(31, 3)
CountLbl.BackgroundTransparency = 1
CountLbl.Text               = tostring(CFG.submitAfter)
CountLbl.TextSize           = 15
CountLbl.TextColor3         = C.White
CountLbl.Font               = Enum.Font.GothamBold
CountLbl.TextXAlignment     = Enum.TextXAlignment.Center
local PlusBtn = makeCountBtn("+", UDim2.fromOffset(63, 3))

MinusBtn.MouseButton1Click:Connect(function()
    CFG.submitAfter = math.max(1, CFG.submitAfter - 1)
    CountLbl.Text = tostring(CFG.submitAfter)
    clearCapture(); saveConfig()
end)
PlusBtn.MouseButton1Click:Connect(function()
    CFG.submitAfter += 1
    CountLbl.Text = tostring(CFG.submitAfter)
    clearCapture(); saveConfig()
end)

-- Retype invalid
local RetypeCard = makeCard("RetypeInvalid", UDim2.fromOffset(14, 100), UDim2.fromOffset(272, 36))
makeLabel(RetypeCard, "T", "Retype invalid",
    UDim2.new(1,-58,1,0), UDim2.fromOffset(10,0), 11, C.Text, Enum.Font.GothamMedium)
local retypeBtn = makeToggleCard(RetypeCard, CFG.retypeInvalid, "Retype invalid", function(state)
    CFG.retypeInvalid = state; saveConfig()
end)
retypeBtn.Position = UDim2.new(1, -44, 0.5, -9)

-- ===================================================================
-- LOG
-- ===================================================================
secLabel("LOG", 238)

Console = Instance.new("ScrollingFrame", Window)
Console.Name                  = "Console"
Console.Size                  = UDim2.new(1, -28, 0, 118)
Console.Position              = UDim2.fromOffset(14, 251)
Console.BackgroundColor3      = C.Log
Console.BackgroundTransparency = 0.16
Console.BorderSizePixel       = 0
Console.ClipsDescendants      = true
Console.Active                = true
Console.ScrollingEnabled      = true
Console.ScrollingDirection    = Enum.ScrollingDirection.Y
Console.ElasticBehavior       = Enum.ElasticBehavior.WhenScrollable
Console.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
Console.CanvasSize            = UDim2.new(0,0,0,0)
Console.AutomaticCanvasSize   = Enum.AutomaticSize.None
Console.ScrollBarThickness    = 3
Console.ScrollBarImageColor3  = C.Accent
Console.ZIndex                = 3
addCorner(Console, 7)
addStroke(Console, C.Accent, 1, 0.66)

ConsoleOutput = Instance.new("TextLabel", Console)
ConsoleOutput.Name              = "Output"
ConsoleOutput.Size              = UDim2.new(1, -16, 0, 110)
ConsoleOutput.AutomaticSize     = Enum.AutomaticSize.Y
ConsoleOutput.Position          = UDim2.fromOffset(8, 5)
ConsoleOutput.BackgroundTransparency = 1
ConsoleOutput.RichText          = true
ConsoleOutput.TextSize          = 13
ConsoleOutput.Font              = Enum.Font.Code
ConsoleOutput.TextColor3        = C.Dim
ConsoleOutput.TextXAlignment    = Enum.TextXAlignment.Left
ConsoleOutput.TextYAlignment    = Enum.TextYAlignment.Top
ConsoleOutput.TextWrapped       = true
ConsoleOutput.ZIndex            = 4
ConsoleOutput.Text = CFG.codeSniper
    and ('<font color="' .. CC.Amber .. '">&gt;</font> '
        .. '<font color="' .. CC.Dim .. '">scanning for codes...</font>')
    or  ('<font color="' .. CC.Dim .. '">status:</font> '
        .. '<font color="' .. CC.Red .. '">OFF</font>\n'
        .. '<font color="' .. CC.Dim .. '">code sniper paused</font>')

updateConsoleCanvas = function()
    if not Console or not ConsoleOutput then return end
    local h = ConsoleOutput.Position.Y.Offset + ConsoleOutput.AbsoluteSize.Y + 28
    Console.CanvasSize = UDim2.new(0, 0, 0, h)
end
ConsoleOutput:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateConsoleCanvas)
task.defer(updateConsoleCanvas)

local function toCC(col)
    if col == C.Green  then return CC.Green end
    if col == C.Red    then return CC.Red   end
    if col == C.Text   then return CC.Amber end
    if col == C.White  then return CC.Cyan  end
    if col == C.Dim    then return CC.Dim   end
    return ("rgb(%d,%d,%d)"):format(
        math.floor(col.R*255+0.5), math.floor(col.G*255+0.5), math.floor(col.B*255+0.5))
end

setStatus = function(msg, col)
    if not ConsoleOutput or not CFG.codeSniper then return end
    if msg == _lastStatusMsg then return end
    _lastStatusMsg = msg
    col = col or C.Dim
    local line = '<font color="' .. toCC(col) .. '">' .. tostring(msg) .. "</font>"
    ConsoleOutput.Text = ConsoleOutput.Text == "" and line
        or (ConsoleOutput.Text .. "\n\n" .. line)
    scrollConsole()
end

flashCode = function(code, col)
    if not code or code == "" then return end
    setStatus("[code] -> " .. tostring(code), col or C.White)
end

-- ===================================================================
-- MASTER TOGGLE
-- ===================================================================
local function applyMasterToggle(on)
    CFG.codeSniper = on
    if not on then clearCapture() end
    _lastStatusMsg = nil
    ToggleBtn.BackgroundColor3 = on and C.Accent or C.Control
    ToggleBtn.TextColor3       = on and C.Window or C.Dim
    ToggleBtn.Text             = on and "ON" or "OFF"
    ToggleStroke.Color         = on and C.Accent or C.Dim
    ToggleStroke.Transparency  = on and 0.36 or 0.72
    saveConfig()
    if ConsoleOutput then
        if on then
            ConsoleOutput.Text = '<font color="' .. CC.Amber .. '">&gt;</font> '
                .. '<font color="' .. CC.Dim .. '">scanning for codes...</font>'
            for name, state in pairs(featureStates) do
                if state then appendConsoleStatus(name, true) end
            end
        else
            ConsoleOutput.Text = '<font color="' .. CC.Dim .. '">status:</font> '
                .. '<font color="' .. CC.Red .. '">OFF</font>\n'
                .. '<font color="' .. CC.Dim .. '">code sniper paused</font>'
        end
        scrollConsole()
    end
end

applyMasterToggle(CFG.codeSniper)
ToggleBtn.MouseButton1Click:Connect(function() applyMasterToggle(not CFG.codeSniper) end)

-- ===================================================================
-- DRAG — threshold
-- ===================================================================
do
    local dragging, activeDrag, dragStart, startPos, dragMoved
    local THRESHOLD = UserInputService.TouchEnabled and 10 or 3

    local function isOverControl(pos)
        if not UserInputService.TouchEnabled then return false end
        local hp = Header.AbsolutePosition; local hs = Header.AbsoluteSize
        return pos.X >= hp.X + hs.X - 70
            and pos.Y >= hp.Y
            and pos.Y <= hp.Y + hs.Y
    end

    local function stopDrag(inp)
        if inp ~= activeDrag then return end
        dragging = false; activeDrag = nil; dragStart = nil; startPos = nil
    end

    Header.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        if dragging or isOverControl(inp.Position) then return end
        dragging = true; activeDrag = inp
        dragStart = Vector2.new(inp.Position.X, inp.Position.Y)
        startPos = Window.Position; dragMoved = false
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End
            or inp.UserInputState == Enum.UserInputState.Cancel then
                stopDrag(inp)
            end
        end)
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if not dragging or not activeDrag then return end
        local isTouch = activeDrag.UserInputType == Enum.UserInputType.Touch and inp == activeDrag
        local isMouse = activeDrag.UserInputType == Enum.UserInputType.MouseButton1
            and inp.UserInputType == Enum.UserInputType.MouseMovement
        if not isTouch and not isMouse then return end
        local cur = Vector2.new(inp.Position.X, inp.Position.Y)
        local delta = cur - dragStart
        if not dragMoved then
            if delta.Magnitude < THRESHOLD then return end
            dragMoved = true
        end
        Window.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end)
end
