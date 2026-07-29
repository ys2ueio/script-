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
local getconns    = getconnections or (debug and debug.getconnections)
local setupv      = (debug and debug.setupvalue) or setupvalue
local REDEEM_GUID = "7d14a912-1040-4867-b005-98838eb9acc4"
local RedeemRemote

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

local function resolveAceRedeemRemote()
    if RedeemRemote and RedeemRemote.Parent then return RedeemRemote end
    local ok, api = pcall(require, Net)
    if ok and type(api) == "table" then
        local rok, rf = pcall(function() return api:RemoteFunction(REDEEM_GUID) end)
        if rok and typeof(rf) == "Instance" then RedeemRemote = rf end
    end
    return RedeemRemote
end

local function killAceDebounce(fn)
    if not (fn and setupv and getupvalues) then return end
    local ok, ups = pcall(getupvalues, fn)
    if ok and type(ups) == "table" then
        for i, v in pairs(ups) do if type(v) == "boolean" then pcall(setupv, fn, i, false) end end
    end
end

local function aceRedeemViaBox(code)
    if not getconns then return false, "no getconnections" end
    local box = aceCodeBox()
    if not box then return false, "no codebox" end
    local ok, conns = pcall(getconns, box.FocusLost)
    if not ok or type(conns) ~= "table" or #conns == 0 then return false, "no connection" end
    local fired = false
    for _, c in ipairs(conns) do
        local fn; pcall(function() fn = c.Function end)
        killAceDebounce(fn)
        box.Text = code; box.Active = true; box.Selectable = true
        local fok = pcall(function() if c.Enabled ~= false then c:Fire(true) end end)
        fired = fired or fok
    end
    return fired, fired and "sent" or "fire failed"
end

local function aceRedeemViaRemote(code)
    local rf = resolveAceRedeemRemote()
    if not rf then return false, "no remote" end
    local ok, result = pcall(function() return rf:InvokeServer(code) end)
    if not ok then return false, tostring(result) end
    return true, result
end

local function aceRedeem(code)
    local ok, res = aceRedeemViaBox(code)
    if ok then return true, res end
    if getconns then return false, res end
    return aceRedeemViaRemote(code)
end

-- ================================================================
-- RED THEME
-- ================================================================
local C_BG    = Color3.fromRGB(10,   3,   3)
local C_ON    = Color3.fromRGB(90,  15,  15)
local C_OFF   = Color3.fromRGB(10,   3,   3)
local C_ROW   = Color3.fromRGB(28,   8,   8)
local C_WHITE = Color3.fromRGB(255, 200, 200)
local C_DIM   = Color3.fromRGB(150,  70,  70)
local G1      = Color3.fromRGB(255,  80,  80)
local G2      = Color3.fromRGB(160,  25,  25)
local G3      = Color3.fromRGB(35,    5,   5)

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
GUI.Name           = "YslemAutoCode"
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
pillByLbl.TextColor3             = C_DIM
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
task.spawn(function()
    local fname = "yslem_bg_v4.png"
    local url   = "https://litter.catbox.moe/2wfsx1k13uv3vbj2.png"
    if getcustomasset then
        if isfile and isfile(fname) then
            local rid = getcustomasset(fname)
            if rid and rid ~= "" then _bgImg.Image = rid; return end
        end
        local ok, data = pcall(function() return game:HttpGet(url) end)
        if ok and data and data ~= "" then
            pcall(function() if writefile then writefile(fname, data) end end)
            local rid = getcustomasset(fname)
            if rid and rid ~= "" then _bgImg.Image = rid; return end
        end
    else
        local ok, data = pcall(function() return game:HttpGet(url) end)
        if ok and data and data ~= "" then
            pcall(function() if writefile then writefile(fname, data) end end)
        end
    end
end)

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
titleLbl.Text                   = "YSLEM AUTO CODE"
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
byLbl.TextColor3             = C_DIM
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
            rememberPendingSubmission(box, combinedCode, true)
            local ok, res = aceRedeem(combinedCode)
            local success = ok and (type(res) ~= "table" or res.success or res.Success)
            if success then
                setStatus("Redeemed: " .. combinedCode, COLORS.Green)
                _autoResetToken += 1
                local myToken = _autoResetToken
                task.delay(3, function()
                    if myToken ~= _autoResetToken then return end
                    _lastStatusMsg = nil
                    if _codeBarLbl then _codeBarLbl.Text = "" end
                    setStatus("Ready", COLORS.Green)
                end)
            else
                local restored = restoreRejectedText(box, combinedCode)
                clearPendingSubmission()
                if restored then
                    setStatus("Invalid - repasted: " .. combinedCode, COLORS.Text)
                    flashCode(combinedCode, COLORS.Red)
                else
                    setStatus("Invalid / cooldown", COLORS.Red)
                end
            end
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
    task.wait(0.04)
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
    aceListenConnection = aceNotifyRemote.OnClientEvent:Connect(function(...)
        if not _enabled or not isAceAnnouncement(...) then return end
        pcall(onAceAnnouncement, ...)
    end)
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

setStatus("Yslem Auto Code loaded", COLORS.Green)
print("[YSLEM AUTO CODE] by Yslem - Loaded")
