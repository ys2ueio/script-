-- yslem_auto_code.lua  (strictly private & personal use)

-- ================================================================
-- SERVICES + CLONEREF
-- ================================================================
local cloneref = cloneref or function(object) return object end
local Players           = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService        = cloneref(game:GetService("RunService"))
local TweenService      = game:GetService("TweenService")
local UserInputService  = cloneref(game:GetService("UserInputService"))
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if getgenv and getgenv().StopAura then pcall(getgenv().StopAura) end

-- ================================================================
-- CONFIG
-- ================================================================
local savedConfig = {
    codeSniper    = true,
    autoSubmit    = true,
    submitAfter   = 3,
    retypeInvalid = false,
    riddleSolver  = false,
}

-- ================================================================
-- ACE STATE
-- ================================================================
local _enabled              = savedConfig.codeSniper
local _seen                 = {}
local _focused              = nil
local _lastBox              = nil
local _autoAccept           = savedConfig.autoSubmit
local _submitAfter          = savedConfig.submitAfter
local _capturedParts        = {}
local _lastWatchedBox       = nil
local _boxTextConn          = nil
local _boxAncestryConn      = nil
local _boxVisibilityConns   = {}
local _retypeInvalid        = savedConfig.retypeInvalid
local _riddleSolver         = savedConfig.riddleSolver
local _lastNonBlankBoxText  = ""
local _pendingRejectedText  = nil
local _pendingRejectedBox   = nil
local _pendingRejectedUntil = 0
local _pendingRejectedToken = 0
local ACE_CASE_MODE       = "EXACT"
local ACE_WORD_COUNT      = 1
local KNOWN_CODE_BOX_PATH = {"Codes", "Codes", "CodeRedeem", "TextBox"}
local setStatus, flashCode, appendToBox
local rememberPendingSubmission, clearPendingSubmission, handleRedemptionFeedback
local clearAceCapture
local _lastStatusMsg   = nil
local _autoResetToken  = 0
local Net         = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net")
local getupvalues = (debug and debug.getupvalues) or getupvalues
local _ownGui     = nil   -- set after ScreenGui creation; used by isOwnedByUs

-- ACE COLORS (used by logic functions for setStatus/flashCode calls)
local COLORS = {
    Green = Color3.fromRGB(70,  210, 100),
    Red   = Color3.fromRGB(255, 70,  70),
    Text  = Color3.fromRGB(190, 190, 196),
    White = Color3.fromRGB(245, 245, 245),
    Dim   = Color3.fromRGB(120, 120, 130),
}

-- ================================================================
-- ACE CORE FUNCTIONS
-- ================================================================
local function aceCodeBox()
    local gui = playerGui:FindFirstChild("Codes")
    if not gui then return nil end
    local root   = gui:FindFirstChild("Codes") or gui
    local redeem = root:FindFirstChild("CodeRedeem")
    local box    = redeem and redeem:FindFirstChild("TextBox")
    if box and box:IsA("TextBox") then return box end
    for _, obj in ipairs(gui:GetDescendants()) do
        if obj:IsA("TextBox") then return obj end
    end
end

-- ================================================================
-- REDEEM LOGIC (multi-path)
-- ================================================================
local _redeemLock  = false
local _redeemDelay = 0          -- seconds; wired to the delay TextBox
local _rfRemote    = nil
local _cachedBox   = nil

local function isOwnedByUs(obj)
    if not _ownGui then return false end
    local cur = obj
    while cur and cur ~= game do
        if cur == _ownGui then return true end
        cur = cur.Parent
    end
    return false
end

local function getRedemptionRF()
    if _rfRemote and _rfRemote.Parent then return _rfRemote end
    _rfRemote = nil
    local rfFolder = ReplicatedStorage:FindFirstChild("RF")
    if rfFolder then
        local rf = rfFolder:FindFirstChild("RequestRedemption")
        if rf and rf:IsA("RemoteFunction") then _rfRemote = rf; return _rfRemote end
        for _, v in ipairs(rfFolder:GetChildren()) do
            if v.Name == "RequestRedemption" and v:IsA("RemoteFunction") then
                _rfRemote = v; return _rfRemote
            end
        end
    end
    if getinstances then
        for _, v in ipairs(getinstances()) do
            if v.Name == "RequestRedemption" and v:IsA("RemoteFunction") then
                _rfRemote = v; return _rfRemote
            end
        end
    end
    return nil
end

local function redeemViaRF(code)
    local rf = getRedemptionRF()
    if not rf then return false end
    local ok = pcall(function() rf:InvokeServer(code) end)
    return ok
end

local function _isCodeBox(obj)
    if not obj:IsA("TextBox") then return false end
    if isOwnedByUs(obj) then return false end
    local nameL = obj.Name:lower()
    local phL   = (obj.PlaceholderText or ""):lower()
    for _, h in ipairs({"code","redeem","promo","coupon","enter","input"}) do
        if nameL:find(h, 1, true) or phL:find(h, 1, true) then return true end
    end
    return false
end

local function findCodeTextBox()
    if _cachedBox and _cachedBox.Parent then return _cachedBox end
    _cachedBox = nil
    local function search(root)
        for _, d in ipairs(root:GetDescendants()) do
            if _isCodeBox(d) then _cachedBox = d; return d end
        end
    end
    return search(playerGui) or search(game:GetService("CoreGui"))
end

local function fireSignalHelper(btn)
    -- getconnections dispatches natively — harder to detect than firesignal
    if getconnections then
        pcall(function()
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
        end)
        pcall(function()
            for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
        end)
        return
    end
    pcall(function() if firesignal then firesignal(btn.MouseButton1Click) end end)
    pcall(function() if firesignal then firesignal(btn.Activated) end end)
end

local function isSubmitButton(obj)
    if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then return false end
    local n = obj.Name:lower()
    local t = (obj:IsA("TextButton") and obj.Text:lower()) or ""
    for _, h in ipairs({"submit","confirm","redeem","enter","ok","send","apply"}) do
        if n:find(h,1,true) or t:find(h,1,true) then return true end
    end
    return false
end

local function fireSubmitButton(root)
    if not root then return false end
    for _, d in ipairs(root:GetDescendants()) do
        if isSubmitButton(d) then fireSignalHelper(d); return true end
    end
    return false
end

local function forceParentVisible(obj)
    local cur = obj.Parent
    while cur and cur ~= playerGui and cur ~= game:GetService("CoreGui") do
        pcall(function() cur.Visible = true end)
        cur = cur.Parent
    end
end

local function submitBox(box, code)
    forceParentVisible(box)
    box.Text = code
    pcall(function() box.CursorPosition = #code + 1 end)
end

local function redeemCode(code)
    if _redeemLock then return end
    _redeemLock = true

    -- jitter delay (±20 %) to break fixed-interval detection
    if _redeemDelay > 0 then
        local jitter = _redeemDelay * (0.8 + math.random() * 0.4)
        task.wait(jitter)
    end

    -- 0. Direct RemoteFunction path
    if redeemViaRF(code) then
        task.delay(4, function() _redeemLock = false end)
        return
    end

    -- 1. PlayerGui.Codes.Codes.CodeRedeem (without opening menu)
    local submitted = false
    pcall(function()
        local codesGui = playerGui:FindFirstChild("Codes");    if not codesGui then return end
        local inner    = codesGui:FindFirstChild("Codes");     if not inner    then return end
        local cr       = inner:FindFirstChild("CodeRedeem");   if not cr       then return end
        local tb       = cr:FindFirstChildWhichIsA("TextBox"); if not tb       then return end
        local wasVis   = inner.Visible
        inner.Visible  = true
        tb.Text = code
        pcall(function() tb.CursorPosition = #code + 1 end)
        if not fireSubmitButton(cr) then fireSubmitButton(inner) end
        inner.Visible = wasVis
        submitted = true
    end)
    if submitted then task.delay(4, function() _redeemLock = false end); return end

    -- 2. Shop fallback
    pcall(function()
        local shopGui = playerGui:FindFirstChild("Shop"); if not shopGui then return end
        for _, d in ipairs(shopGui:GetDescendants()) do
            if d:IsA("TextBox") and not isOwnedByUs(d)
            and (d.PlaceholderText or ""):lower():find("code", 1, true) then
                local p = d.Parent; local wasV = p and p.Visible
                if p then p.Visible = true end
                submitBox(d, code)
                local scope = d.Parent
                for _ = 1, 8 do
                    if fireSubmitButton(scope) then break end
                    if scope and scope.Parent then scope = scope.Parent else break end
                end
                if p and wasV ~= nil then p.Visible = wasV end
                submitted = true; return
            end
        end
    end)
    if submitted then task.delay(4, function() _redeemLock = false end); return end

    -- 3. Generic findCodeTextBox fallback
    local box = findCodeTextBox()
    if box then
        submitBox(box, code)
        local scope = box.Parent
        for _ = 1, 8 do
            if fireSubmitButton(scope) then break end
            if scope and scope.Parent then scope = scope.Parent else break end
        end
    end

    task.delay(4, function() _redeemLock = false end)
end

-- ================================================================
-- RED THEME
-- ================================================================
local C_BG    = Color3.fromRGB(8,   8,   8)
local C_ON    = Color3.fromRGB(45,  45,  45)
local C_OFF   = Color3.fromRGB(8,   8,   8)
local C_ROW   = Color3.fromRGB(22,  22,  22)
local C_WHITE = Color3.fromRGB(240, 240, 240)
local C_DIM   = Color3.fromRGB(120, 120, 120)
local G1      = Color3.fromRGB(200, 200, 200)
local G2      = Color3.fromRGB(90,  90,  90)
local G3      = Color3.fromRGB(25,  25,  25)

local _livingGradients = {}
local _livingStrokes   = {}

local function addCorner(inst, r)
    local c = Instance.new("UICorner", inst)
    c.CornerRadius = UDim.new(0, r or 8)
    return c
end

local function addLivingTextGradient(lbl)
    local g = Instance.new("UIGradient", lbl)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    G1),
        ColorSequenceKeypoint.new(0.25, G2),
        ColorSequenceKeypoint.new(0.5,  G1),
        ColorSequenceKeypoint.new(0.75, G2),
        ColorSequenceKeypoint.new(1,    G1),
    })
    g.Rotation = 0
    table.insert(_livingGradients, g)
    return g
end

local function addLivingStroke(parent, thickness)
    local s = Instance.new("UIStroke", parent)
    s.Thickness        = thickness or 1.5
    s.ApplyStrokeMode  = Enum.ApplyStrokeMode.Border
    s.Color            = G2
    local g = Instance.new("UIGradient", s)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    G3),
        ColorSequenceKeypoint.new(0.25, G2),
        ColorSequenceKeypoint.new(0.5,  G3),
        ColorSequenceKeypoint.new(0.75, G2),
        ColorSequenceKeypoint.new(1,    G3),
    })
    table.insert(_livingStrokes, g)
    return s, g
end

RunService.RenderStepped:Connect(function()
    for _, g in ipairs(_livingGradients) do if g and g.Parent then g.Rotation = (g.Rotation + 0.6) % 360 end end
    for _, g in ipairs(_livingStrokes)   do if g and g.Parent then g.Rotation = (g.Rotation + 0.6) % 360 end end
end)

-- ================================================================
-- GUI ROOT
-- ================================================================
local GUI = Instance.new("ScreenGui")
GUI.Name           = "MoonHubAutoCode"
GUI.ResetOnSpawn   = false
GUI.IgnoreGuiInset = true
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.DisplayOrder   = 999
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(GUI) end
    if protectgui then protectgui(GUI) end
end)
if not pcall(function() GUI.Parent = game:GetService("CoreGui") end) then
    GUI.Parent = (gethui and gethui()) or playerGui
end
_ownGui = GUI

-- ================================================================
-- STATUS PILL
-- ================================================================
local pillWidget = Instance.new("Frame", GUI)
pillWidget.Name                   = "ScanPill"
pillWidget.Size                   = UDim2.new(0, 200, 0, 36)
pillWidget.Position               = UDim2.new(0.5, -100, 0, 35)
pillWidget.BackgroundTransparency = 1
pillWidget.Active                 = true

local pill = Instance.new("Frame", pillWidget)
pill.Size                   = UDim2.new(1, 0, 1, 0)
pill.BackgroundColor3       = C_BG
pill.BackgroundTransparency = 0.1
pill.BorderSizePixel        = 0
pill.ClipsDescendants       = true
addCorner(pill, 18)
addLivingStroke(pill, 1.5)

local _pillLbl = Instance.new("TextLabel", pill)
_pillLbl.Size                   = UDim2.new(1, -16, 1, 0)
_pillLbl.Position               = UDim2.new(0, 8, 0, 0)
_pillLbl.BackgroundTransparency = 1
_pillLbl.Text                   = "SCANNING"
_pillLbl.TextColor3             = C_WHITE
_pillLbl.Font                   = Enum.Font.GothamBlack
_pillLbl.TextSize               = 13
_pillLbl.TextXAlignment         = Enum.TextXAlignment.Center
_pillLbl.ZIndex                 = 5
addLivingTextGradient(_pillLbl)

local pillByLbl = Instance.new("TextLabel", pillWidget)
pillByLbl.Size                   = UDim2.new(1, 0, 0, 10)
pillByLbl.Position               = UDim2.new(0, 0, 1, 3)
pillByLbl.BackgroundTransparency = 1
pillByLbl.Text                   = "by Yslem"
pillByLbl.TextColor3             = Color3.fromRGB(185, 185, 185)
pillByLbl.Font                   = Enum.Font.Gotham
pillByLbl.TextSize               = 8
pillByLbl.TextXAlignment         = Enum.TextXAlignment.Center
pillByLbl.ZIndex                 = 5

-- ================================================================
-- MAIN PANEL
-- ================================================================
local PANEL_W   = 240
local TITLE_H   = 28
local TAB_H     = 26
local CONTENT_H = 174
local FULL_H    = TITLE_H + TAB_H + CONTENT_H
local MINI_H    = TITLE_H

local panel = Instance.new("Frame", GUI)
panel.Size                   = UDim2.new(0, PANEL_W, 0, FULL_H)
panel.Position               = UDim2.new(0, 16, 0, 80)
panel.BackgroundColor3       = C_BG
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel        = 0
panel.Active                 = true
panel.ZIndex                 = 10
addCorner(panel, 14)
addLivingStroke(panel, 1.5)

local _bgImg = Instance.new("ImageLabel", panel)
_bgImg.Size                   = UDim2.new(1, 0, 1, 0)
_bgImg.Position               = UDim2.new(0, 0, 0, 0)
_bgImg.BackgroundTransparency = 1
_bgImg.Image                  = ""
_bgImg.ScaleType              = Enum.ScaleType.Crop
_bgImg.ImageTransparency      = 0.25
_bgImg.ZIndex                 = 9
addCorner(_bgImg, 14)
do
    local fname = "moonhub_bg.png"
    local url   = "https://litter.catbox.moe/3tpr3wks0we2rbzo.png"
    local function tryLoad()
        if not (getcustomasset and isfile and isfile(fname)) then return false end
        local rid = getcustomasset(fname)
        if rid and rid ~= "" then _bgImg.Image = rid; return true end
        return false
    end
    -- Cache → immédiat ; pas de cache → téléchargement synchrone puis chargement
    if not tryLoad() then
        pcall(function()
            local ok, data = pcall(function() return game:HttpGet(url) end)
            if ok and data and data ~= "" then
                if writefile then writefile(fname, data) end
                tryLoad()
            end
        end)
    end
end

-- Drag
do
    local dragging, dragStart, startPos = false, nil, nil
    panel.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or
           inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = panel.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    panel.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or
                         inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- Minimize button
local minimized = false
local minBtn = Instance.new("TextButton", panel)
minBtn.Size                   = UDim2.new(0, 20, 0, 20)
minBtn.Position               = UDim2.new(1, -24, 0, 4)
minBtn.BackgroundTransparency = 1
minBtn.Text                   = "-"
minBtn.TextColor3             = C_WHITE
minBtn.Font                   = Enum.Font.GothamBlack
minBtn.TextSize               = 16
minBtn.ZIndex                 = 15
addLivingTextGradient(minBtn)

-- Title
local titleLbl = Instance.new("TextLabel", panel)
titleLbl.Size                   = UDim2.new(1, -40, 0, TITLE_H)
titleLbl.Position               = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = "MOON HUB AUTO CODE"
titleLbl.TextColor3             = C_WHITE
titleLbl.Font                   = Enum.Font.GothamBlack
titleLbl.TextSize               = 13
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.ZIndex                 = 15
addLivingTextGradient(titleLbl)

local byLbl = Instance.new("TextLabel", panel)
byLbl.Size                   = UDim2.new(0, 64, 0, TITLE_H)
byLbl.Position               = UDim2.new(1, -88, 0, 0)
byLbl.BackgroundTransparency = 1
byLbl.Text                   = "by Yslem"
byLbl.TextColor3             = Color3.fromRGB(185, 185, 185)
byLbl.Font                   = Enum.Font.Gotham
byLbl.TextSize               = 9
byLbl.TextXAlignment         = Enum.TextXAlignment.Right
byLbl.ZIndex                 = 15

-- ================================================================
-- TAB BAR
-- ================================================================
local tabBar = Instance.new("Frame", panel)
tabBar.Size                   = UDim2.new(1, -16, 0, TAB_H)
tabBar.Position               = UDim2.new(0, 8, 0, TITLE_H)
tabBar.BackgroundTransparency = 1
tabBar.ZIndex                 = 12

local tabBarLayout = Instance.new("UIListLayout", tabBar)
tabBarLayout.FillDirection       = Enum.FillDirection.Horizontal
tabBarLayout.Padding             = UDim.new(0, 4)
tabBarLayout.SortOrder           = Enum.SortOrder.LayoutOrder
tabBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabBarLayout.VerticalAlignment   = Enum.VerticalAlignment.Center

local currentTab = 1

local function makeTabBtn(label, order)
    local btn = Instance.new("TextButton", tabBar)
    btn.Size             = UDim2.new(0, 108, 1, -4)
    btn.LayoutOrder      = order
    btn.BackgroundColor3 = C_ROW
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Text             = label
    btn.TextColor3       = C_DIM
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 10
    btn.ZIndex           = 13
    addCorner(btn, 6)
    addLivingTextGradient(btn)
    return btn
end

local tabMainBtn   = makeTabBtn("Main",   1)
local tabStatusBtn = makeTabBtn("Status", 2)

-- ================================================================
-- CONTENT FRAME
-- ================================================================
local contentFrame = Instance.new("Frame", panel)
contentFrame.Size                   = UDim2.new(1, 0, 1, -(TITLE_H + TAB_H))
contentFrame.Position               = UDim2.new(0, 0, 0, TITLE_H + TAB_H)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants       = true
contentFrame.ZIndex                 = 11

-- ================================================================
-- PAGE 1: MAIN
-- ================================================================
local page1 = Instance.new("Frame", contentFrame)
page1.Size                   = UDim2.new(1, 0, 1, 0)
page1.BackgroundTransparency = 1
page1.ZIndex                 = 11

-- Code bar
local codeBar = Instance.new("Frame", page1)
codeBar.Size             = UDim2.new(1, -20, 0, 28)
codeBar.Position         = UDim2.new(0, 10, 0, 6)
codeBar.BackgroundColor3 = C_ROW
codeBar.BorderSizePixel  = 0
codeBar.ZIndex           = 12
addCorner(codeBar, 8)
addLivingStroke(codeBar, 1)

local _codeBarLbl = Instance.new("TextBox", codeBar)
_codeBarLbl.Size                   = UDim2.new(1, -16, 1, 0)
_codeBarLbl.Position               = UDim2.new(0, 8, 0, 0)
_codeBarLbl.BackgroundTransparency = 1
_codeBarLbl.BorderSizePixel        = 0
_codeBarLbl.PlaceholderText        = "Auto-detect or type code..."
_codeBarLbl.PlaceholderColor3      = C_DIM
_codeBarLbl.Text                   = ""
_codeBarLbl.TextColor3             = C_WHITE
_codeBarLbl.Font                   = Enum.Font.GothamBold
_codeBarLbl.TextSize               = 11
_codeBarLbl.TextXAlignment         = Enum.TextXAlignment.Left
_codeBarLbl.TextTruncate           = Enum.TextTruncate.AtEnd
_codeBarLbl.ClearTextOnFocus       = false
_codeBarLbl.ZIndex                 = 13
addLivingTextGradient(_codeBarLbl)

-- AUTO ENTER CODE toggle
local autoBtn = Instance.new("TextButton", page1)
autoBtn.Size             = UDim2.new(1, -20, 0, 24)
autoBtn.Position         = UDim2.new(0, 10, 0, 42)
autoBtn.BackgroundColor3 = _autoAccept and C_ON or C_OFF
autoBtn.Text             = _autoAccept and "AUTO ENTER CODE: ON" or "AUTO ENTER CODE: OFF"
autoBtn.TextColor3       = _autoAccept and C_WHITE or C_DIM
autoBtn.Font             = Enum.Font.GothamBlack
autoBtn.TextSize         = 11
autoBtn.BorderSizePixel  = 0
autoBtn.AutoButtonColor  = false
autoBtn.ZIndex           = 12
addCorner(autoBtn, 8)
addLivingTextGradient(autoBtn)
autoBtn.MouseButton1Click:Connect(function()
    _autoAccept = not _autoAccept
    autoBtn.Text       = _autoAccept and "AUTO ENTER CODE: ON" or "AUTO ENTER CODE: OFF"
    autoBtn.TextColor3 = _autoAccept and C_WHITE or C_DIM
    TweenService:Create(autoBtn, TweenInfo.new(0.15), {BackgroundColor3 = _autoAccept and C_ON or C_OFF}):Play()
    if not _autoAccept and clearAceCapture then clearAceCapture() end
    _lastStatusMsg = nil
end)

-- CLEAR CAPTURE button
local forceBtn = Instance.new("TextButton", page1)
forceBtn.Size             = UDim2.new(1, -20, 0, 28)
forceBtn.Position         = UDim2.new(0, 10, 0, 74)
forceBtn.BackgroundColor3 = C_OFF
forceBtn.Text             = "CLEAR CAPTURE"
forceBtn.TextColor3       = C_DIM
forceBtn.Font             = Enum.Font.GothamBlack
forceBtn.TextSize         = 11
forceBtn.BorderSizePixel  = 0
forceBtn.AutoButtonColor  = false
forceBtn.ZIndex           = 12
addCorner(forceBtn, 10)
addLivingTextGradient(forceBtn)
forceBtn.MouseButton1Click:Connect(function()
    if clearAceCapture then clearAceCapture() end
    TweenService:Create(forceBtn, TweenInfo.new(0.15), {BackgroundColor3 = C_ON}):Play()
    task.delay(0.3, function()
        TweenService:Create(forceBtn, TweenInfo.new(0.2), {BackgroundColor3 = C_OFF}):Play()
    end)
end)
forceBtn.MouseEnter:Connect(function()
    TweenService:Create(forceBtn, TweenInfo.new(0.15), {TextColor3 = C_WHITE}):Play()
end)
forceBtn.MouseLeave:Connect(function()
    TweenService:Create(forceBtn, TweenInfo.new(0.15), {TextColor3 = C_DIM}):Play()
end)

-- Delay row (UI element kept; no delay logic in ACE)
local delayRow = Instance.new("Frame", page1)
delayRow.Size             = UDim2.new(1, -20, 0, 24)
delayRow.Position         = UDim2.new(0, 10, 0, 110)
delayRow.BackgroundColor3 = C_ROW
delayRow.BorderSizePixel  = 0
delayRow.ZIndex           = 12
addCorner(delayRow, 8)
addLivingStroke(delayRow, 1)

local delayLbl = Instance.new("TextLabel", delayRow)
delayLbl.Size                   = UDim2.new(0.65, 0, 1, 0)
delayLbl.Position               = UDim2.new(0, 8, 0, 0)
delayLbl.BackgroundTransparency = 1
delayLbl.Text                   = "Redeem delay (s):"
delayLbl.TextColor3             = C_DIM
delayLbl.Font                   = Enum.Font.Gotham
delayLbl.TextSize               = 10
delayLbl.TextXAlignment         = Enum.TextXAlignment.Left
delayLbl.ZIndex                 = 13

local delayBox = Instance.new("TextBox", delayRow)
delayBox.Size              = UDim2.new(0.3, -4, 0.8, 0)
delayBox.Position          = UDim2.new(0.68, 0, 0.1, 0)
delayBox.BackgroundColor3  = C_OFF
delayBox.BorderSizePixel   = 0
delayBox.Font              = Enum.Font.GothamBold
delayBox.TextSize          = 11
delayBox.TextColor3        = C_WHITE
delayBox.PlaceholderText   = "0"
delayBox.PlaceholderColor3 = C_DIM
delayBox.TextXAlignment    = Enum.TextXAlignment.Center
delayBox.ClearTextOnFocus  = false
delayBox.Text              = "0"
delayBox.ZIndex            = 13
addCorner(delayBox, 5)
addLivingTextGradient(delayBox)
delayBox.FocusLost:Connect(function()
    local n = tonumber(delayBox.Text)
    if n and n >= 0 then
        _redeemDelay = n
        delayBox.Text = tostring(n)
    else
        delayBox.Text = tostring(_redeemDelay)
    end
end)

-- Parts row → _submitAfter
local partsRow = Instance.new("Frame", page1)
partsRow.Size             = UDim2.new(1, -20, 0, 24)
partsRow.Position         = UDim2.new(0, 10, 0, 142)
partsRow.BackgroundColor3 = C_ROW
partsRow.BorderSizePixel  = 0
partsRow.ZIndex           = 12
addCorner(partsRow, 8)
addLivingStroke(partsRow, 1)

local partsLbl = Instance.new("TextLabel", partsRow)
partsLbl.Size                   = UDim2.new(0.55, 0, 1, 0)
partsLbl.Position               = UDim2.new(0, 8, 0, 0)
partsLbl.BackgroundTransparency = 1
partsLbl.Text                   = "Submit after:"
partsLbl.TextColor3             = C_DIM
partsLbl.Font                   = Enum.Font.Gotham
partsLbl.TextSize               = 10
partsLbl.TextXAlignment         = Enum.TextXAlignment.Left
partsLbl.ZIndex                 = 13

local partsMinBtn = Instance.new("TextButton", partsRow)
partsMinBtn.Size             = UDim2.new(0, 22, 0.8, 0)
partsMinBtn.Position         = UDim2.new(0.55, 4, 0.1, 0)
partsMinBtn.BackgroundColor3 = C_OFF
partsMinBtn.Text             = "-"
partsMinBtn.TextColor3       = C_WHITE
partsMinBtn.Font             = Enum.Font.GothamBold
partsMinBtn.TextSize         = 14
partsMinBtn.BorderSizePixel  = 0
partsMinBtn.AutoButtonColor  = false
partsMinBtn.ZIndex           = 13
addCorner(partsMinBtn, 5)
addLivingTextGradient(partsMinBtn)

local partsValLbl = Instance.new("TextLabel", partsRow)
partsValLbl.Size                   = UDim2.new(0, 30, 1, 0)
partsValLbl.Position               = UDim2.new(0.55, 30, 0, 0)
partsValLbl.BackgroundTransparency = 1
partsValLbl.Text                   = tostring(_submitAfter)
partsValLbl.TextColor3             = C_WHITE
partsValLbl.Font                   = Enum.Font.GothamBold
partsValLbl.TextSize               = 11
partsValLbl.TextXAlignment         = Enum.TextXAlignment.Center
partsValLbl.ZIndex                 = 13
addLivingTextGradient(partsValLbl)

local partsPlusBtn = Instance.new("TextButton", partsRow)
partsPlusBtn.Size             = UDim2.new(0, 22, 0.8, 0)
partsPlusBtn.Position         = UDim2.new(0.55, 64, 0.1, 0)
partsPlusBtn.BackgroundColor3 = C_OFF
partsPlusBtn.Text             = "+"
partsPlusBtn.TextColor3       = C_WHITE
partsPlusBtn.Font             = Enum.Font.GothamBold
partsPlusBtn.TextSize         = 14
partsPlusBtn.BorderSizePixel  = 0
partsPlusBtn.AutoButtonColor  = false
partsPlusBtn.ZIndex           = 13
addCorner(partsPlusBtn, 5)
addLivingTextGradient(partsPlusBtn)

partsMinBtn.MouseButton1Click:Connect(function()
    _submitAfter = math.max(1, _submitAfter - 1)
    partsValLbl.Text = tostring(_submitAfter)
    if clearAceCapture then clearAceCapture() end
end)
partsPlusBtn.MouseButton1Click:Connect(function()
    _submitAfter = _submitAfter + 1
    partsValLbl.Text = tostring(_submitAfter)
    if clearAceCapture then clearAceCapture() end
end)

-- ================================================================
-- PAGE 2: STATUS
-- ================================================================
local page4 = Instance.new("Frame", contentFrame)
page4.Size                   = UDim2.new(1, 0, 1, 0)
page4.BackgroundTransparency = 1
page4.Visible                = false
page4.ZIndex                 = 11

local _statusScroll = Instance.new("ScrollingFrame", page4)
_statusScroll.Size                   = UDim2.new(1, -16, 1, -36)
_statusScroll.Position               = UDim2.new(0, 8, 0, 6)
_statusScroll.BackgroundColor3       = C_ROW
_statusScroll.BackgroundTransparency = 0.4
_statusScroll.BorderSizePixel        = 0
_statusScroll.ScrollBarThickness     = 3
_statusScroll.ScrollBarImageColor3   = G2
_statusScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
_statusScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
_statusScroll.ClipsDescendants       = true
_statusScroll.ZIndex                 = 12
addCorner(_statusScroll, 8)

local statusLayout = Instance.new("UIListLayout", _statusScroll)
statusLayout.Padding             = UDim.new(0, 2)
statusLayout.SortOrder           = Enum.SortOrder.LayoutOrder
statusLayout.FillDirection       = Enum.FillDirection.Vertical
statusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
statusLayout.VerticalAlignment   = Enum.VerticalAlignment.Top

local statusPad = Instance.new("UIPadding", _statusScroll)
statusPad.PaddingLeft   = UDim.new(0, 4)
statusPad.PaddingRight  = UDim.new(0, 4)
statusPad.PaddingTop    = UDim.new(0, 4)
statusPad.PaddingBottom = UDim.new(0, 4)

local clearBtn = Instance.new("TextButton", page4)
clearBtn.Size             = UDim2.new(1, -16, 0, 24)
clearBtn.Position         = UDim2.new(0, 8, 1, -28)
clearBtn.BackgroundColor3 = C_ROW
clearBtn.Text             = "Clear log"
clearBtn.TextColor3       = C_DIM
clearBtn.Font             = Enum.Font.Gotham
clearBtn.TextSize         = 10
clearBtn.BorderSizePixel  = 0
clearBtn.AutoButtonColor  = false
clearBtn.ZIndex           = 12
addCorner(clearBtn, 6)
clearBtn.MouseButton1Click:Connect(function()
    for _, child in ipairs(_statusScroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
end)

-- ================================================================
-- TAB SWITCHING
-- ================================================================
local function setTab(idx)
    currentTab = idx
    page1.Visible = (idx == 1)
    page4.Visible = (idx == 2)
    tabMainBtn.BackgroundColor3   = (idx == 1) and C_ON or C_ROW
    tabStatusBtn.BackgroundColor3 = (idx == 2) and C_ON or C_ROW
    tabMainBtn.TextColor3         = (idx == 1) and C_WHITE or C_DIM
    tabStatusBtn.TextColor3       = (idx == 2) and C_WHITE or C_DIM
end
setTab(1)
tabMainBtn.MouseButton1Click:Connect(function()   if currentTab ~= 1 then setTab(1) end end)
tabStatusBtn.MouseButton1Click:Connect(function() if currentTab ~= 2 then setTab(2) end end)

-- ================================================================
-- MINIMIZE
-- ================================================================
local function applyMinimize(instant)
    local targetH = minimized and MINI_H or FULL_H
    tabBar.Visible       = not minimized
    contentFrame.Visible = not minimized
    minBtn.Text          = minimized and "+" or "-"
    if instant then
        panel.Size = UDim2.new(0, PANEL_W, 0, targetH)
    else
        TweenService:Create(panel, TweenInfo.new(0.15), {Size = UDim2.new(0, PANEL_W, 0, targetH)}):Play()
    end
end
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    applyMinimize(false)
end)
applyMinimize(true)

-- ================================================================
-- STATUS + FLASH (bridge: ACE logic → scroll log + pill)
-- ================================================================
local function logToScroll(msg)
    if not _statusScroll then return end
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -8, 0, 0)
    lbl.AutomaticSize          = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.Code
    lbl.TextSize               = 9
    lbl.TextColor3             = C_DIM
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.TextWrapped            = true
    lbl.Text                   = msg
    lbl.Parent                 = _statusScroll
    task.defer(function()
        _statusScroll.CanvasPosition = Vector2.new(0, math.huge)
    end)
end

function setStatus(msg, col)
    if not _enabled then return end
    if msg == _lastStatusMsg then return end
    _lastStatusMsg = msg
    local t = os.date and os.date("%H:%M:%S") or "??"
    logToScroll("[" .. t .. "] " .. tostring(msg))
    if _pillLbl then _pillLbl.Text = tostring(msg):sub(1, 26) end
end

function flashCode(code, col)
    if not code or code == "" or code == "—" then return end
    local t = os.date and os.date("%H:%M:%S") or "??"
    logToScroll("[" .. t .. "] [code] -> " .. tostring(code))
    if _codeBarLbl then
        _codeBarLbl.Text       = tostring(code)
        _codeBarLbl.TextColor3 = C_WHITE
    end
end

-- ================================================================
-- BOX WATCHERS + HELPERS
-- ================================================================
local function resetPasteCounter()
    _capturedParts = {}
end

clearAceCapture = function()
    _capturedParts = {}
    _autoResetToken += 1
    _lastStatusMsg = nil
    if _codeBarLbl then _codeBarLbl.Text = "" end
    setStatus("Ready", COLORS.Green)
end

local function clearBoxWatchers()
    if _boxTextConn     then pcall(function() _boxTextConn:Disconnect()     end) end
    if _boxAncestryConn then pcall(function() _boxAncestryConn:Disconnect() end) end
    for _, connection in ipairs(_boxVisibilityConns) do
        pcall(function() connection:Disconnect() end)
    end
    _boxTextConn        = nil
    _boxAncestryConn    = nil
    _boxVisibilityConns = {}
    _lastWatchedBox     = nil
end

local function isBoxStillOpen(box)
    if not box or not box.Parent then return false end
    local current = box
    while current do
        if current:IsA("GuiObject") and current.Visible == false then return false end
        if current:IsA("ScreenGui") and current.Enabled == false then return false end
        current = current.Parent
    end
    return true
end

local function resolveCodeBox()
    local node = playerGui
    for _, name in ipairs(KNOWN_CODE_BOX_PATH) do
        if not node then break end
        node = node:FindFirstChild(name)
    end
    if node and node:IsA("TextBox") and isBoxStillOpen(node) then return node end
    if isBoxStillOpen(_focused) then return _focused end
    if isBoxStillOpen(_lastBox)  then return _lastBox  end
    return nil
end

local function watchBoxForBlankReset(box)
    if not box or _lastWatchedBox == box then return end
    clearBoxWatchers()
    _lastWatchedBox = box
    if box.Text ~= "" then _lastNonBlankBoxText = box.Text end
    _boxTextConn = box:GetPropertyChangedSignal("Text"):Connect(function()
        if box.Text == "" then
            resetPasteCounter()
        else
            _lastNonBlankBoxText = box.Text
        end
    end)
    _boxAncestryConn = box.AncestryChanged:Connect(function(_, parent)
        if not parent then
            resetPasteCounter()
            clearBoxWatchers()
        end
    end)
    local current = box
    while current do
        if current:IsA("GuiObject") then
            table.insert(_boxVisibilityConns, current:GetPropertyChangedSignal("Visible"):Connect(function()
                if not isBoxStillOpen(box) then resetPasteCounter(); clearBoxWatchers() end
            end))
        elseif current:IsA("ScreenGui") then
            table.insert(_boxVisibilityConns, current:GetPropertyChangedSignal("Enabled"):Connect(function()
                if not isBoxStillOpen(box) then resetPasteCounter(); clearBoxWatchers() end
            end))
        end
        current = current.Parent
    end
end

-- ================================================================
-- FOCUS TRACKING (ACE-specific)
-- ================================================================
UserInputService.TextBoxFocused:Connect(function(box)
    if box:IsDescendantOf(GUI) then return end
    if box ~= aceCodeBox() then return end
    _focused = box
    _lastBox = box
    watchBoxForBlankReset(box)
    if _enabled then setStatus("Ready", COLORS.Green) end
end)

UserInputService.TextBoxFocusReleased:Connect(function(box)
    if box:IsDescendantOf(GUI) then return end
    local codeBox = aceCodeBox()
    if box ~= codeBox and box ~= _lastBox then return end
    if _retypeInvalid and rememberPendingSubmission
    and (box == codeBox or box == _lastBox) then
        local submittedText = box.Text ~= "" and box.Text or _lastNonBlankBoxText
        rememberPendingSubmission(box, submittedText, false)
    end
    if _focused == box then
        _focused = nil
        if _enabled then
            setStatus(
                (_lastBox and _lastBox.Parent) and "Ready" or "Click code box first",
                (_lastBox and _lastBox.Parent) and COLORS.Green or COLORS.Dim
            )
        end
    end
end)

-- ================================================================
-- REDEMPTION FEEDBACK
-- ================================================================
clearPendingSubmission = function()
    _pendingRejectedToken += 1
    _pendingRejectedText  = nil
    _pendingRejectedBox   = nil
    _pendingRejectedUntil = 0
end

rememberPendingSubmission = function(box, text, replaceExisting)
    if not _retypeInvalid or not text or text == "" then return end
    if not replaceExisting
    and _pendingRejectedText
    and os.clock() <= _pendingRejectedUntil then return end
    _pendingRejectedToken += 1
    local token           = _pendingRejectedToken
    _pendingRejectedText  = text
    _pendingRejectedBox   = box
    _pendingRejectedUntil = os.clock() + 8
    task.delay(8, function()
        if token == _pendingRejectedToken then clearPendingSubmission() end
    end)
end

local function restoreRejectedText(box, previousText)
    if not _retypeInvalid or not previousText or previousText == "" then return false end
    RunService.Heartbeat:Wait()
    local repasteBox = resolveCodeBox() or box
    if not repasteBox or not isBoxStillOpen(repasteBox) then return false end
    local restored = pcall(function() repasteBox.Text = previousText end)
    if restored then
        _lastBox = repasteBox
        watchBoxForBlankReset(repasteBox)
    end
    return restored
end

handleRedemptionFeedback = function(text, feedbackObject)
    if not _retypeInvalid or not _pendingRejectedText then return end
    if os.clock() > _pendingRejectedUntil then clearPendingSubmission(); return end
    if feedbackObject and feedbackObject:IsDescendantOf(GUI) then return end
    local lower    = tostring(text or ""):lower()
    local rejected = lower:find("invalid code",    1, true)
        or lower:find("code is invalid",  1, true)
        or lower:find("expired",          1, true)
        or lower:find("already redeemed", 1, true)
        or lower:find("already used",     1, true)
        or lower:find("doesn't exist",    1, true)
        or lower:find("does not exist",   1, true)
        or lower:find("not found",        1, true)
        or lower:find("rejected",         1, true)
    if not rejected then return end
    local previousText = _pendingRejectedText
    local previousBox  = _pendingRejectedBox
    local restored     = restoreRejectedText(previousBox, previousText)
    clearPendingSubmission()
    if restored then
        setStatus("Invalid - repasted: " .. previousText, COLORS.Text)
        flashCode(previousText, COLORS.Red)
    end
end

-- ================================================================
-- APPEND TO BOX
-- ================================================================
function appendToBox(text)
    _autoResetToken += 1
    if not text or text == "" then return end
    if _lastWatchedBox and not isBoxStillOpen(_lastWatchedBox) then
        resetPasteCounter()
        clearBoxWatchers()
    end
    local box = aceCodeBox()
    _capturedParts[#_capturedParts + 1] = text
    local combinedCode  = table.concat(_capturedParts)
    local capturedCount = #_capturedParts
    if box then
        _lastBox = box
        watchBoxForBlankReset(box)
        local boxWasFocused = UserInputService:GetFocusedTextBox() == box
        box.Text = combinedCode
        if boxWasFocused then
            pcall(function()
                local caretEnd = #combinedCode + 1
                box.CursorPosition = caretEnd
                box.SelectionStart = caretEnd
            end)
        end
    else
        setStatus("Captured; code box is closed", COLORS.Text)
    end
    setStatus("Pasted " .. tostring(capturedCount) .. "/" .. tostring(_submitAfter), COLORS.Green)
    flashCode(combinedCode, COLORS.Green)
    if capturedCount >= _submitAfter then
        _capturedParts = {}
        if _autoAccept then
            setStatus("Redeeming: " .. combinedCode, COLORS.Green)
            redeemCode(combinedCode)
            _autoResetToken += 1
            local myToken = _autoResetToken
            task.delay(4, function()
                if myToken ~= _autoResetToken then return end
                _lastStatusMsg = nil
                if _codeBarLbl then _codeBarLbl.Text = "" end
                setStatus("Ready", COLORS.Green)
            end)
        end
    end
end

-- ================================================================
-- REDEMPTION FEEDBACK WATCHER
-- ================================================================
local function watchRedemptionFeedbackObject(obj)
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
    handleRedemptionFeedback(obj.Text or "", obj)
    obj:GetPropertyChangedSignal("Text"):Connect(function()
        handleRedemptionFeedback(obj.Text or "", obj)
    end)
end
for _, obj in ipairs(playerGui:GetDescendants()) do
    watchRedemptionFeedbackObject(obj)
end
playerGui.DescendantAdded:Connect(function(obj)
    watchRedemptionFeedbackObject(obj)
end)

-- ================================================================
-- ACE NOTIFY REMOTE
-- ================================================================
local function aceRemotesFromFunction(fn)
    if not getupvalues then return {} end
    local ok, values = pcall(getupvalues, fn)
    local remotes = {}
    if ok and type(values) == "table" then
        for _, value in pairs(values) do
            if typeof(value) == "Instance"
            and (value:IsA("RemoteEvent")
                or value:IsA("RemoteFunction")
                or value:IsA("UnreliableRemoteEvent"))
            and value.Parent == Net then
                table.insert(remotes, value)
            end
        end
    end
    return remotes
end

local function resolveAceNotifyRemote()
    local ok, controller = pcall(function()
        return require(ReplicatedStorage.Controllers:FindFirstChild(
            "NotificationController",
            true
        ))
    end)
    if ok and type(controller) == "table" and type(controller.Start) == "function" then
        return aceRemotesFromFunction(controller.Start)[1]
    end
end

local ACE_POSITIONS = {
    Top = true, Bottom = true, Center = true, Middle = true,
    Left = true, Right = true, TopRight = true, TopLeft = true,
    BottomRight = true, BottomLeft = true,
}

local function isAceAnnouncement(...)
    local args = table.pack(...)
    if args.n == 0 or typeof(args[1]) ~= "string" then return false end
    for index = 2, args.n do
        local value = args[index]
        if typeof(value) == "string"
        and (value:find("Sounds%.")
            or value:find("rbxassetid")
            or ACE_POSITIONS[value]) then
            return true
        end
    end
    return false
end

local function aceStripRich(text)
    if type(text) ~= "string" then return tostring(text) end
    return (text:gsub("<[^>]->", ""))
end

local function aceApplyCase(code)
    if ACE_CASE_MODE == "UPPER" then return code:upper()
    elseif ACE_CASE_MODE == "lower" then return code:lower() end
    return code
end

local function aceTokenize(text)
    local words = {}
    for word in text:gmatch("[%w_]+") do words[#words + 1] = word end
    return words
end

local aceCollectBuffer = {}

local function onAceAnnouncement(...)
    local text = aceStripRich(tostring((...) or ""))
    text = text:match("^%s*(.-)%s*$") or ""
    if text == "" then return end
    -- Sammy sometimes announces normal sentences. Only paste one solid code.
    if text:find("%s") then return end
    for _, word in ipairs(aceTokenize(text)) do
        aceCollectBuffer[#aceCollectBuffer + 1] = word
    end
    local parts = {}
    for index = 1, math.min(#aceCollectBuffer, ACE_WORD_COUNT) do
        parts[index] = aceCollectBuffer[index]
    end
    if #aceCollectBuffer < ACE_WORD_COUNT then return end
    aceCollectBuffer = {}
    local captured = aceApplyCase(table.concat(parts))
    if captured == "" or _seen[captured] then return end
    _seen[captured] = true
    task.delay(1.25, function() _seen[captured] = nil end)
    task.wait(0.0002) -- 0.2 ms post-scan
    appendToBox(captured)
end

-- ================================================================
-- CONNECT + CLEANUP
-- ================================================================
local aceNotifyRemote = resolveAceNotifyRemote()
local aceListenConnection
if aceNotifyRemote then
    if getgenv then
        local previous = getgenv().ACECodeSniperNotifyConnection
        if previous then pcall(function() previous:Disconnect() end) end
    end
    local _cb = function(...)
        if not _enabled or not isAceAnnouncement(...) then return end
        pcall(onAceAnnouncement, ...)
    end
    -- newcclosure makes the callback appear as a C closure, harder to detect
    aceListenConnection = aceNotifyRemote.OnClientEvent:Connect(
        (newcclosure and newcclosure(_cb)) or _cb
    )
    if getgenv then getgenv().ACECodeSniperNotifyConnection = aceListenConnection end
end
if getgenv then
    getgenv().StopAura = function()
        if aceListenConnection then
            pcall(function() aceListenConnection:Disconnect() end)
            aceListenConnection = nil
        end
        if getgenv().ACECodeSniperNotifyConnection then
            pcall(function() getgenv().ACECodeSniperNotifyConnection:Disconnect() end)
            getgenv().ACECodeSniperNotifyConnection = nil
        end
        if GUI then GUI:Destroy() end
    end
end

-- ================================================================
-- ANTI-KICK
-- ================================================================
local _LP = Players.LocalPlayer

-- 1. namecall block (Kick + Shutdown)
pcall(function()
    local _nc
    _nc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if m == "Kick" then return end
        if m == "Shutdown" and self == game then return end
        return _nc(self, ...)
    end))
end)

-- 2. MaxHealth + Health lock
RunService.Heartbeat:Connect(function()
    local c = _LP.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then
        if h.MaxHealth ~= 100 then h.MaxHealth = 100 end
        if h.Health    <  100 then h.Health    = 100 end
    end
end)

-- 3. Death state block
local function _blockDeath(char)
    local h = char and char:FindFirstChildOfClass("Humanoid")
    if h then h:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end
end
if _LP.Character then _blockDeath(_LP.Character) end
_LP.CharacterAdded:Connect(_blockDeath)

-- 4. Char parent restore
RunService.Heartbeat:Connect(function()
    if _LP.Character and _LP.Character.Parent ~= workspace then
        _LP.Character.Parent = workspace
    end
end)

-- 5. TeleportService block
pcall(function()
    local TS = game:GetService("TeleportService")
    local _tsNc
    _tsNc = hookmetamethod(TS, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if m == "Teleport" or m == "TeleportToPlaceInstance" then return end
        return _tsNc(self, ...)
    end))
end)

-- 6. GC scanner — hooks any function whose upvalue literally contains "kick"
task.spawn(function()
    local function scanGC()
        if not getgc then return end
        for _, v in ipairs(getgc(true)) do
            if type(v) == "function"
            and islclosure and islclosure(v)
            and not (isexecutorclosure and isexecutorclosure(v)) then
                local ok, ups = pcall(getupvalues, v)
                if ok and ups then
                    for _, u in ipairs(ups) do
                        if type(u) == "string" and u:lower() == "kick" then
                            pcall(hookfunction, v, newcclosure(function() end))
                        end
                    end
                end
            end
        end
    end
    scanGC()
    while true do task.wait(30); scanGC() end
end)

setStatus("Moon Hub Auto Code loaded", COLORS.Green)
print("[MOON HUB AUTO CODE] by Yslem - Loaded")
