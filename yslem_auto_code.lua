-- yslem_auto_code.lua

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService") -- noqa (kept for future use)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local LP                = Players.LocalPlayer
local PlayerGui         = LP:WaitForChild("PlayerGui")

-- ===================================================================
-- CONFIG  (edit here)
-- ===================================================================
local CFG = {
    enabled  = true,
    delay    = 0,   -- seconds to wait before redeeming (0 = instant)
    keywords = { "code is", "use code", "new code", "code:", "promo", "redeem" },
    replace  = {
        -- { kw = "admin war", rep = "jandel" },
    },
}

-- ===================================================================
-- GUI — created early so redeemCode can exclude our own TextBoxes
-- ===================================================================
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
-- STATE
-- ===================================================================
local _lastCode  = ""
local _lastTime  = 0
local _pending   = ""
local _token     = 0
local _lock      = false
local _statusLbl = nil  -- filled after UI build
local _codeLbl   = nil

local function setStatus(txt)
    if _statusLbl then _statusLbl.Text = txt end
end

local function showCode(code)
    _lastCode = code
    if _codeLbl then _codeLbl.Text = code end
end

-- ===================================================================
-- DETECTION
-- ===================================================================
local _COMMON = {
    the=1,and=1,for=1,are=1,but=1,not=1,you=1,all=1,can=1,
    was=1,one=1,our=1,out=1,get=1,has=1,him=1,his=1,how=1,
    new=1,now=1,old=1,see=1,two=1,way=1,who=1,did=1,its=1,
    let=1,put=1,say=1,she=1,too=1,use=1,via=1,
}
local _BLOCKED = {
    "join","left","welcome","server","update","version","patch",
    "roblox","game","studio","player","loading","error","warning",
}

local function _isBlocked(w)
    local low = w:lower()
    if _COMMON[low] then return true end
    for _, b in ipairs(_BLOCKED) do
        if low:find(b, 1, true) then return true end
    end
    return false
end

local function _isNoise(txt)
    if not txt or #txt < 3 then return true end
    if txt:match("^%d+[:%.]?%d*$")    then return true end
    if txt:match("^[%+%-]?%d+[kKmMbBgG]?$") then return true end
    if txt:match("^x%d")              then return true end
    return false
end

local function _looksLike(tok)
    if not tok or #tok < 4 or #tok > 25 then return false end
    if not tok:match("^%w[%w%-_]*%w$") then return false end
    if _isBlocked(tok)                  then return false end
    if tok:match("^%d+[smhdSMHD]$")    then return false end
    local letters = 0
    for _ in tok:gmatch("%a") do letters = letters + 1 end
    if letters < 3 then return false end
    local bare   = tok:gsub("[%-_]", "")
    local allUp  = bare:match("%a") ~= nil and bare == bare:upper()
    return tok:match("%d") ~= nil or (allUp and #tok >= 5)
end

local function _extractCodes(text)
    if not text or _isNoise(text) then return {} end
    text = text:match("^%s*(.-)%s*$"):gsub("<[^>]->", "")
    if not text:find("%s") and _looksLike(text) then return { text } end
    local out, seen = {}, {}
    for tok in text:gmatch("[%w][%w%-_]*") do
        if not seen[tok] and _looksLike(tok) then
            seen[tok] = true; out[#out+1] = tok
        end
    end
    return out
end

local function _matchesKeyword(text)
    local low = text:lower()
    for _, kw in ipairs(CFG.keywords) do
        if kw ~= "" and low:find(kw:lower(), 1, true) then return true end
    end
    return false
end

local function _applyReplace(text)
    local low = text:lower()
    for _, r in ipairs(CFG.replace) do
        if r.kw ~= "" and low:find(r.kw:lower(), 1, true) then return r.rep end
    end
    return nil
end

-- ===================================================================
-- REDEEM
-- ===================================================================
local _rfCache = nil

local function _getRF()
    if _rfCache and _rfCache.Parent then return _rfCache end
    _rfCache = nil
    local function try(obj)
        if obj.Name == "RequestRedemption" and obj:IsA("RemoteFunction") then
            _rfCache = obj; return true
        end
    end
    local rfFolder = ReplicatedStorage:FindFirstChild("RF")
    if rfFolder then
        for _, v in ipairs(rfFolder:GetChildren()) do if try(v) then break end end
    end
    if not _rfCache and getinstances then
        for _, v in ipairs(getinstances()) do if try(v) then break end end
    end
    return _rfCache
end

local function _fireBtn(root)
    if not root then return false end
    local HINTS = { "redeem","submit","confirm","ok","enter","apply","send" }
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextButton") or d:IsA("ImageButton") then
            local n = d.Name:lower()
            local t = d:IsA("TextButton") and d.Text:lower() or ""
            for _, h in ipairs(HINTS) do
                if n:find(h,1,true) or t:find(h,1,true) then
                    pcall(function() if firesignal then firesignal(d.MouseButton1Click) end end)
                    pcall(function() if firesignal then firesignal(d.Activated) end end)
                    return true
                end
            end
        end
    end
    return false
end

local function _submitToBox(box, code)
    box.Text = code
    pcall(function() box.CursorPosition = #code + 1 end)
    task.wait(0.05)
end

local function redeemCode(code)
    if _lock then return end
    _lock = true
    setStatus("→ " .. code)

    -- 1. Direct RemoteFunction (fastest, no UI needed)
    local rf = _getRF()
    if rf then
        pcall(function() rf:InvokeServer(code) end)
        task.delay(4, function() _lock = false end)
        return
    end

    local done = false

    -- 2. Codes.Codes.CodeRedeem (common pattern)
    pcall(function()
        local cg = PlayerGui:FindFirstChild("Codes");     if not cg then return end
        local ci = cg:FindFirstChild("Codes");            if not ci then return end
        local cr = ci:FindFirstChild("CodeRedeem");       if not cr then return end
        local tb = cr:FindFirstChildWhichIsA("TextBox");  if not tb then return end
        local wasV = ci.Visible; ci.Visible = true
        _submitToBox(tb, code)
        _fireBtn(cr) or _fireBtn(ci)
        ci.Visible = wasV
        done = true
    end)
    if done then task.delay(4, function() _lock = false end); return end

    -- 3. Generic TextBox scan across PlayerGui + CoreGui
    local function tryScan(root)
        local HINTS = { "code","promo","redeem","coupon","enter" }
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("TextBox") and not d:IsDescendantOf(gui) then
                local ph = (d.PlaceholderText or ""):lower()
                local nm = d.Name:lower()
                for _, h in ipairs(HINTS) do
                    if ph:find(h,1,true) or nm:find(h,1,true) then
                        _submitToBox(d, code)
                        local scope = d.Parent
                        for _ = 1, 6 do
                            if _fireBtn(scope) then done = true; return end
                            if scope and scope.Parent then scope = scope.Parent else break end
                        end
                        return
                    end
                end
            end
        end
    end
    tryScan(PlayerGui)
    if not done then pcall(tryScan, game:GetService("CoreGui")) end

    task.delay(4, function() _lock = false end)
end

-- ===================================================================
-- QUEUE / FLUSH
-- ===================================================================
local function _flush(tok)
    if tok ~= _token then return end
    local code = _pending; _pending = ""
    if code == "" then return end
    showCode(code); _lastTime = tick()
    setStatus("✓ " .. code)
    if CFG.enabled then redeemCode(code) end
end

local function _queue(code)
    if code == _lastCode and (tick() - _lastTime) < 30 then return end
    _pending = code; _token = _token + 1
    local t = _token
    if CFG.delay <= 0 then
        _flush(t)
    else
        setStatus("wait " .. CFG.delay .. "s…")
        task.delay(CFG.delay, function() _flush(t) end)
    end
end

-- ===================================================================
-- DISPATCH — called for every new text string
-- ===================================================================
local _dedupText = ""
local _dedupTime = 0

local function dispatch(text)
    if not text or _isNoise(text) then return end
    local now = tick()
    if text == _dedupText and now - _dedupTime < 0.4 then return end
    _dedupText = text; _dedupTime = now

    local rep = _applyReplace(text)
    if rep then _queue(rep); return end

    if not _matchesKeyword(text) then return end
    for _, c in ipairs(_extractCodes(text)) do _queue(c) end
end

-- ===================================================================
-- SCANNER — event-driven TextLabel watcher, zero polling
-- ===================================================================
local _watched = {}

local function watchLabel(lbl)
    if _watched[lbl] then return end
    _watched[lbl] = true
    lbl:GetPropertyChangedSignal("Text"):Connect(function()
        if CFG.enabled then dispatch(lbl.Text) end
    end)
end

local function scanRoot(root)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") then watchLabel(d) end
    end
    root.DescendantAdded:Connect(function(d)
        if d:IsA("TextLabel") then watchLabel(d) end
    end)
end

scanRoot(PlayerGui)
pcall(function() scanRoot(game:GetService("CoreGui")) end)

-- ===================================================================
-- UI — minimal draggable pill
-- ===================================================================
local C_BG   = Color3.fromRGB(10, 10, 10)
local C_ACC  = Color3.fromRGB(50, 50, 50)
local C_TEXT = Color3.fromRGB(210, 210, 210)
local C_DIM  = Color3.fromRGB(90, 90, 90)

local function corner(p, r)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r or 8); return c
end

local pill = Instance.new("Frame", gui)
pill.AnchorPoint       = Vector2.new(0, 0)
pill.Size              = UDim2.new(0, 190, 0, 52)
pill.Position          = UDim2.new(0, 16, 0, 80)
pill.BackgroundColor3  = C_BG
pill.BorderSizePixel   = 0
corner(pill, 10)
Instance.new("UIStroke", pill).Color = Color3.fromRGB(35, 35, 35)

local titleLbl = Instance.new("TextLabel", pill)
titleLbl.Size              = UDim2.new(1, -50, 0, 20)
titleLbl.Position          = UDim2.new(0, 8, 0, 4)
titleLbl.BackgroundTransparency = 1
titleLbl.Font              = Enum.Font.GothamBold
titleLbl.TextSize          = 11
titleLbl.TextColor3        = C_TEXT
titleLbl.TextXAlignment    = Enum.TextXAlignment.Left
titleLbl.Text              = "YSLEM AUTO CODE"

local toggleBtn = Instance.new("TextButton", pill)
toggleBtn.Size             = UDim2.new(0, 36, 0, 18)
toggleBtn.Position         = UDim2.new(1, -42, 0, 4)
toggleBtn.BackgroundColor3 = C_ACC
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.TextSize         = 10
toggleBtn.TextColor3       = C_TEXT
toggleBtn.Text             = "ON"
toggleBtn.BorderSizePixel  = 0
corner(toggleBtn, 5)

_statusLbl = Instance.new("TextLabel", pill)
_statusLbl.Size             = UDim2.new(1, -8, 0, 14)
_statusLbl.Position         = UDim2.new(0, 8, 0, 24)
_statusLbl.BackgroundTransparency = 1
_statusLbl.Font             = Enum.Font.Code
_statusLbl.TextSize         = 10
_statusLbl.TextColor3       = C_DIM
_statusLbl.TextXAlignment   = Enum.TextXAlignment.Left
_statusLbl.Text             = "SCANNING"

_codeLbl = Instance.new("TextLabel", pill)
_codeLbl.Size              = UDim2.new(1, -8, 0, 14)
_codeLbl.Position          = UDim2.new(0, 8, 0, 36)
_codeLbl.BackgroundTransparency = 1
_codeLbl.Font              = Enum.Font.Code
_codeLbl.TextSize          = 10
_codeLbl.TextColor3        = C_TEXT
_codeLbl.TextXAlignment    = Enum.TextXAlignment.Left
_codeLbl.Text              = ""

toggleBtn.MouseButton1Click:Connect(function()
    CFG.enabled = not CFG.enabled
    toggleBtn.Text             = CFG.enabled and "ON" or "OFF"
    toggleBtn.BackgroundColor3 = CFG.enabled and C_ACC or Color3.fromRGB(20,20,20)
    _statusLbl.Text            = CFG.enabled and "SCANNING" or "PAUSED"
end)

-- drag
local _dragging, _dragStart, _pillStart
pill.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        _dragging  = true
        _dragStart = inp.Position
        _pillStart = pill.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then _dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if _dragging and (
        inp.UserInputType == Enum.UserInputType.MouseMovement or
        inp.UserInputType == Enum.UserInputType.Touch
    ) then
        local d = inp.Position - _dragStart
        pill.Position = UDim2.new(
            _pillStart.X.Scale, _pillStart.X.Offset + d.X,
            _pillStart.Y.Scale, _pillStart.Y.Offset + d.Y
        )
    end
end)
