local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LP               = Players.LocalPlayer
local PlayerGui        = LP:WaitForChild("PlayerGui")

-- ===================================================================
-- CONFIG  (persisted)
-- ===================================================================
local CFG_PATH = "moon_autocode_cfg.json"
local cfg = {
    autoCode     = true,
    captureCount = 0,          -- 0=instant single-notif, N=collect N parts after trigger
    keywords     = { "code is","","","","","","","","","" },
    replaceRules = {
        {kw="admin war", rep="jandel"},
        {kw="",rep=""},{kw="",rep=""},{kw="",rep=""},
        {kw="",rep=""},{kw="",rep=""},{kw="",rep=""},
        {kw="",rep=""},{kw="",rep=""},{kw="",rep=""},
    },
    posX      = 16,
    posY      = 80,
    minimized = false,
    activeTab = 1,
}

local function saveConfig()
    if not writefile then return end
    pcall(writefile, CFG_PATH, HttpService:JSONEncode(cfg))
end
local function loadConfig()
    if not (readfile and isfile and isfile(CFG_PATH)) then return end
    local ok, dec = pcall(function() return HttpService:JSONDecode(readfile(CFG_PATH)) end)
    if ok and type(dec) == "table" then
        for k, v in pairs(dec) do cfg[k] = v end
    end
end
loadConfig()

-- ===================================================================
-- COLOUR / STYLE
-- ===================================================================
local C_BG    = Color3.fromRGB(0, 0, 0)
local C_ON    = Color3.fromRGB(30, 30, 30)
local C_OFF   = Color3.fromRGB(0, 0, 0)
local C_ROW   = Color3.fromRGB(14, 14, 14)
local C_WHITE = Color3.fromRGB(255, 255, 255)
local C_DIM   = Color3.fromRGB(130, 130, 130)
local G1      = Color3.fromRGB(255, 255, 255)
local G2      = Color3.fromRGB(140, 140, 140)
local G3      = Color3.fromRGB(50, 50, 50)

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
    s.Thickness = thickness or 1.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Color = G2
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

-- ===================================================================
-- SCANNER STATE
-- ===================================================================
local MAX_KW       = 10
local autoCode     = cfg.autoCode == true
local captureCount = cfg.captureCount

local filterKeywords = {}
local replaceRules   = {}

for i = 1, MAX_KW do
    filterKeywords[i] = (type(cfg.keywords) == "table" and cfg.keywords[i]) or ""
end
for i = 1, MAX_KW do
    local s = type(cfg.replaceRules) == "table" and cfg.replaceRules[i]
    replaceRules[i] = { kw = (s and s.kw) or "", rep = (s and s.rep) or "" }
end

local collecting      = false
local collectBuf      = {}
local collectRemain   = 0
local forceScanActive = false
local lastCode        = ""

local _dedupText = ""
local _dedupTime = 0

local _pillLbl    = nil
local _codeBarLbl = nil

local function setScanState(txt)
    if _pillLbl then _pillLbl.Text = txt end
end

local function setLastCode(code)
    lastCode = code
    if _codeBarLbl then
        _codeBarLbl.Text      = code ~= "" and code or "No code yet"
        _codeBarLbl.TextColor3 = code ~= "" and C_WHITE or C_DIM
    end
end

-- ===================================================================
-- GUI ROOT
-- ===================================================================
local gui = Instance.new("ScreenGui")
gui.Name           = "MoonAutoCode"
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

local function isOwnedByUs(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur == gui then return true end
        cur = cur.Parent
    end
    return false
end

-- ===================================================================
-- LOGIC
-- ===================================================================
local function redeemCode(code)
    pcall(function()
        local Codes = PlayerGui:WaitForChild("Codes", 3).Codes
        local tb    = Codes.CodeRedeem.TextBox
        local cfm   = Codes.Confirm
        tb.Text     = code
        local btn   = cfm:FindFirstChildWhichIsA("TextButton") or cfm
        if btn then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
        end
    end)
end

local function matchesKeyword(text)
    if not text or text == "" then return false end
    local hasAny = false
    for _, kw in ipairs(filterKeywords) do
        if kw ~= "" then hasAny = true; break end
    end
    if not hasAny then return true end
    local lower = text:lower()
    for _, kw in ipairs(filterKeywords) do
        if kw ~= "" and lower:find(kw:lower(), 1, true) then return true end
    end
    return false
end

local function applyReplace(text)
    if not text or text == "" then return nil end
    local lower = text:lower()
    for _, rule in ipairs(replaceRules) do
        if rule.kw ~= "" and lower:find(rule.kw:lower(), 1, true) then
            return rule.rep
        end
    end
    return nil
end

local function dispatch(text)
    if not text or text == "" then return end

    -- deduplicate: same text within 0.4s from dual listeners
    local now = tick()
    if text == _dedupText and (now - _dedupTime) < 0.4 then return end
    _dedupText = text
    _dedupTime = now

    -- FORCE SCAN collect path
    if forceScanActive and collecting then
        table.insert(collectBuf, text)
        collectRemain = collectRemain - 1
        setScanState("COLLECTING " .. collectRemain)
        if collectRemain <= 0 then
            local result = table.concat(collectBuf)
            setLastCode(result)
            redeemCode(result)
            collecting = false; collectBuf = {}; collectRemain = 0; forceScanActive = false
            setScanState("SCANNING")
        end
        return
    end

    -- captureCount > 0: multi-part collect mode
    if captureCount > 0 then
        if collecting then
            -- new trigger during collect → reset, start fresh
            if matchesKeyword(text) then
                collectBuf = {}; collectRemain = captureCount
                setScanState("COLLECTING " .. captureCount)
                return
            end
            local rep = applyReplace(text)
            table.insert(collectBuf, rep ~= nil and rep or text)
            collectRemain = collectRemain - 1
            setScanState("COLLECTING " .. collectRemain)
            if collectRemain <= 0 then
                local result = table.concat(collectBuf)
                if result ~= "" then
                    setLastCode(result)
                    if autoCode then redeemCode(result) end
                end
                collecting = false; collectBuf = {}; collectRemain = 0
                setScanState("SCANNING")
            end
        else
            if matchesKeyword(text) then
                collecting = true; collectBuf = {}; collectRemain = captureCount
                setScanState("COLLECTING " .. captureCount)
            end
        end
        return
    end

    -- captureCount = 0: instant single-notification mode
    if matchesKeyword(text) then
        local rep = applyReplace(text)
        local result
        if rep ~= nil then
            result = rep
        else
            -- extract everything after the matched keyword
            local lower = text:lower()
            for _, kw in ipairs(filterKeywords) do
                if kw ~= "" then
                    local _, e = lower:find(kw:lower(), 1, true)
                    if e then
                        local after = text:sub(e + 1):match("^%s*(.-)%s*$")
                        if after ~= "" then result = after break end
                    end
                end
            end
            if not result then result = text end
        end
        if result ~= "" then
            setLastCode(result)
            if autoCode then redeemCode(result) end
        end
    end
end

-- ===================================================================
-- STATUS PILL
-- ===================================================================
local pillWidget = Instance.new("Frame", gui)
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

_pillLbl = Instance.new("TextLabel", pill)
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

-- ===================================================================
-- MAIN PANEL
-- ===================================================================
local PANEL_W   = 240
local TITLE_H   = 28
local TAB_H     = 26
local CONTENT_H = 164
local FULL_H    = TITLE_H + TAB_H + CONTENT_H
local MINI_H    = TITLE_H

local panel = Instance.new("Frame", gui)
panel.Size             = UDim2.new(0, PANEL_W, 0, FULL_H)
panel.Position         = UDim2.new(0, cfg.posX, 0, cfg.posY)
panel.BackgroundColor3 = C_BG
panel.BorderSizePixel  = 0
panel.Active           = true
panel.ZIndex           = 10
addCorner(panel, 14)
addLivingStroke(panel, 1.5)

-- Drag
do
    local dragging, dragStart, startPos = false, nil, nil
    panel.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or
           inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = panel.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    cfg.posX = panel.Position.X.Offset
                    cfg.posY = panel.Position.Y.Offset
                    saveConfig()
                end
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
local minimized = cfg.minimized == true
local minBtn    = Instance.new("TextButton", panel)
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
titleLbl.Text                   = "MOON AUTO CODE"
titleLbl.TextColor3             = C_WHITE
titleLbl.Font                   = Enum.Font.GothamBlack
titleLbl.TextSize               = 13
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.ZIndex                 = 15
addLivingTextGradient(titleLbl)

-- ===================================================================
-- TAB BAR
-- ===================================================================
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

local currentTab = math.max(1, math.min(3, cfg.activeTab or 1))

local function makeTabBtn(label, order)
    local btn = Instance.new("TextButton", tabBar)
    btn.Size             = UDim2.new(0, 70, 1, -4)
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

local tabMainBtn = makeTabBtn("Main",     1)
local tabTrigBtn = makeTabBtn("Triggers", 2)
local tabRepBtn  = makeTabBtn("Replace",  3)

-- ===================================================================
-- CONTENT FRAME
-- ===================================================================
local contentFrame = Instance.new("Frame", panel)
contentFrame.Size                   = UDim2.new(1, 0, 1, -(TITLE_H + TAB_H))
contentFrame.Position               = UDim2.new(0, 0, 0, TITLE_H + TAB_H)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants       = true
contentFrame.ZIndex                 = 11

-- ===================================================================
-- PAGE 1: MAIN
-- ===================================================================
local page1 = Instance.new("Frame", contentFrame)
page1.Size                   = UDim2.new(1, 0, 1, 0)
page1.BackgroundTransparency = 1
page1.ZIndex                 = 11

-- Code display bar  y=6  (shows last assembled code)
local codeBar = Instance.new("Frame", page1)
codeBar.Size             = UDim2.new(1, -20, 0, 28)
codeBar.Position         = UDim2.new(0, 10, 0, 6)
codeBar.BackgroundColor3 = C_ROW
codeBar.BorderSizePixel  = 0
codeBar.ZIndex           = 12
addCorner(codeBar, 8)
addLivingStroke(codeBar, 1)

_codeBarLbl = Instance.new("TextLabel", codeBar)
_codeBarLbl.Size                   = UDim2.new(1, -16, 1, 0)
_codeBarLbl.Position               = UDim2.new(0, 8, 0, 0)
_codeBarLbl.BackgroundTransparency = 1
_codeBarLbl.Text                   = "No code yet"
_codeBarLbl.TextColor3             = C_DIM
_codeBarLbl.Font                   = Enum.Font.GothamBold
_codeBarLbl.TextSize               = 11
_codeBarLbl.TextXAlignment         = Enum.TextXAlignment.Left
_codeBarLbl.TextTruncate           = Enum.TextTruncate.AtEnd
_codeBarLbl.ZIndex                 = 13
addLivingTextGradient(_codeBarLbl)

-- AUTO ENTER CODE toggle  y=42
local autoBtn = Instance.new("TextButton", page1)
autoBtn.Size             = UDim2.new(1, -20, 0, 24)
autoBtn.Position         = UDim2.new(0, 10, 0, 42)
autoBtn.BackgroundColor3 = autoCode and C_ON or C_OFF
autoBtn.Text             = autoCode and "AUTO ENTER CODE: ON" or "AUTO ENTER CODE: OFF"
autoBtn.TextColor3       = autoCode and C_WHITE or C_DIM
autoBtn.Font             = Enum.Font.GothamBlack
autoBtn.TextSize         = 11
autoBtn.BorderSizePixel  = 0
autoBtn.AutoButtonColor  = false
autoBtn.ZIndex           = 12
addCorner(autoBtn, 8); addLivingTextGradient(autoBtn)
autoBtn.MouseButton1Click:Connect(function()
    autoCode = not autoCode; cfg.autoCode = autoCode
    autoBtn.Text       = autoCode and "AUTO ENTER CODE: ON" or "AUTO ENTER CODE: OFF"
    autoBtn.TextColor3 = autoCode and C_WHITE or C_DIM
    TweenService:Create(autoBtn, TweenInfo.new(0.15), {BackgroundColor3 = autoCode and C_ON or C_OFF}):Play()
    saveConfig()
end)

-- FORCE SCAN + CODE  y=74
local forceKb      = Enum.KeyCode.F
local waitingForKb = false

local forceBtn = Instance.new("TextButton", page1)
forceBtn.Size             = UDim2.new(1, -20, 0, 28)
forceBtn.Position         = UDim2.new(0, 10, 0, 74)
forceBtn.BackgroundColor3 = C_OFF
forceBtn.TextColor3       = C_DIM
forceBtn.Font             = Enum.Font.GothamBlack
forceBtn.TextSize         = 11
forceBtn.BorderSizePixel  = 0
forceBtn.AutoButtonColor  = false
forceBtn.ZIndex           = 12
addCorner(forceBtn, 10); addLivingTextGradient(forceBtn)

local function refreshForceBtn()
    forceBtn.Text       = "FORCE SCAN + CODE  (Bind: " .. forceKb.Name .. ")"
    forceBtn.TextColor3 = C_DIM
    TweenService:Create(forceBtn, TweenInfo.new(0.15), {BackgroundColor3 = C_OFF}):Play()
end
refreshForceBtn()

local function doForceScan()
    local n = captureCount > 0 and captureCount or 1
    collecting = true; collectBuf = {}; collectRemain = n; forceScanActive = true
    setScanState("FORCE " .. n)
    TweenService:Create(forceBtn, TweenInfo.new(0.15), {BackgroundColor3 = C_ON}):Play()
    task.delay(0.5, function()
        TweenService:Create(forceBtn, TweenInfo.new(0.3), {BackgroundColor3 = C_OFF}):Play()
    end)
end

forceBtn.MouseButton1Click:Connect(doForceScan)
forceBtn.MouseButton2Click:Connect(function()
    waitingForKb = true; forceBtn.Text = "Press a key..."
end)
forceBtn.MouseEnter:Connect(function()
    if not waitingForKb then TweenService:Create(forceBtn, TweenInfo.new(0.15), {TextColor3 = C_WHITE}):Play() end
end)
forceBtn.MouseLeave:Connect(function()
    if not waitingForKb then TweenService:Create(forceBtn, TweenInfo.new(0.15), {TextColor3 = C_DIM}):Play() end
end)

-- ENTER CODE button  y=110  (redeem lastCode manually)
local enterBtn = Instance.new("TextButton", page1)
enterBtn.Size             = UDim2.new(1, -20, 0, 24)
enterBtn.Position         = UDim2.new(0, 10, 0, 110)
enterBtn.BackgroundColor3 = C_ROW
enterBtn.Text             = "ENTER CODE"
enterBtn.TextColor3       = C_WHITE
enterBtn.Font             = Enum.Font.GothamBlack
enterBtn.TextSize         = 11
enterBtn.BorderSizePixel  = 0
enterBtn.AutoButtonColor  = false
enterBtn.ZIndex           = 12
addCorner(enterBtn, 8); addLivingTextGradient(enterBtn)
enterBtn.MouseButton1Click:Connect(function()
    if lastCode == "" then return end
    redeemCode(lastCode)
    TweenService:Create(enterBtn, TweenInfo.new(0.1), {BackgroundColor3 = C_ON}):Play()
    task.delay(0.2, function()
        TweenService:Create(enterBtn, TweenInfo.new(0.2), {BackgroundColor3 = C_ROW}):Play()
    end)
end)

-- Bind hint  y=142
local bindHint = Instance.new("TextLabel", page1)
bindHint.Size                   = UDim2.new(1, -20, 0, 14)
bindHint.Position               = UDim2.new(0, 10, 0, 142)
bindHint.BackgroundTransparency = 1
bindHint.Text                   = "Right-click FORCE SCAN to rebind"
bindHint.TextColor3             = Color3.fromRGB(80, 80, 80)
bindHint.Font                   = Enum.Font.Gotham
bindHint.TextSize               = 9
bindHint.TextXAlignment         = Enum.TextXAlignment.Left
bindHint.ZIndex                 = 12

-- ===================================================================
-- PAGE 2: TRIGGERS  (10 keyword slots, scrollable)
-- ===================================================================
local page2 = Instance.new("Frame", contentFrame)
page2.Size                   = UDim2.new(1, 0, 1, 0)
page2.BackgroundTransparency = 1
page2.Visible                = false
page2.ZIndex                 = 11

local trigHeader = Instance.new("TextLabel", page2)
trigHeader.Size                   = UDim2.new(1, -20, 0, 20)
trigHeader.Position               = UDim2.new(0, 10, 0, 6)
trigHeader.BackgroundTransparency = 1
trigHeader.Text                   = "Trigger Keywords  (blank = match all)"
trigHeader.TextColor3             = C_DIM
trigHeader.Font                   = Enum.Font.Gotham
trigHeader.TextSize               = 10
trigHeader.TextXAlignment         = Enum.TextXAlignment.Left
trigHeader.ZIndex                 = 12

local kwScroll = Instance.new("ScrollingFrame", page2)
kwScroll.Size                   = UDim2.new(1, -16, 1, -32)
kwScroll.Position               = UDim2.new(0, 8, 0, 28)
kwScroll.BackgroundColor3       = C_ROW
kwScroll.BackgroundTransparency = 0.4
kwScroll.BorderSizePixel        = 0
kwScroll.ScrollBarThickness     = 3
kwScroll.ScrollBarImageColor3   = G2
kwScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
kwScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
kwScroll.ClipsDescendants       = true
kwScroll.ZIndex                 = 12
addCorner(kwScroll, 8)

local kwScrollLayout = Instance.new("UIListLayout", kwScroll)
kwScrollLayout.Padding             = UDim.new(0, 3)
kwScrollLayout.SortOrder           = Enum.SortOrder.LayoutOrder
kwScrollLayout.FillDirection       = Enum.FillDirection.Vertical
kwScrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
kwScrollLayout.VerticalAlignment   = Enum.VerticalAlignment.Top

local kwScrollPad = Instance.new("UIPadding", kwScroll)
kwScrollPad.PaddingLeft   = UDim.new(0, 5)
kwScrollPad.PaddingRight  = UDim.new(0, 5)
kwScrollPad.PaddingTop    = UDim.new(0, 4)
kwScrollPad.PaddingBottom = UDim.new(0, 4)

local function saveKeywords()
    cfg.keywords = {}
    for i = 1, MAX_KW do cfg.keywords[i] = filterKeywords[i] or "" end
    saveConfig()
end

for i = 1, MAX_KW do
    local slot = Instance.new("Frame", kwScroll)
    slot.Size             = UDim2.new(1, 0, 0, 22)
    slot.BackgroundColor3 = C_OFF
    slot.BorderSizePixel  = 0
    slot.LayoutOrder      = i
    addCorner(slot, 5)

    local badge = Instance.new("TextLabel", slot)
    badge.Size                   = UDim2.new(0, 16, 1, 0)
    badge.Position               = UDim2.new(0, 3, 0, 0)
    badge.BackgroundTransparency = 1
    badge.Font                   = Enum.Font.GothamBold
    badge.TextSize               = 9
    badge.TextColor3             = C_DIM
    badge.TextXAlignment         = Enum.TextXAlignment.Center
    badge.Text                   = tostring(i)
    badge.ZIndex                 = 13

    local tb = Instance.new("TextBox", slot)
    tb.Size              = UDim2.new(1, -22, 1, -4)
    tb.Position          = UDim2.new(0, 20, 0, 2)
    tb.BackgroundTransparency = 1
    tb.BorderSizePixel   = 0
    tb.Font              = Enum.Font.GothamBold
    tb.TextSize          = 11
    tb.TextColor3        = C_WHITE
    tb.PlaceholderText   = "keyword " .. i
    tb.PlaceholderColor3 = C_DIM
    tb.TextXAlignment    = Enum.TextXAlignment.Left
    tb.ClearTextOnFocus  = false
    tb.Text              = filterKeywords[i]
    tb.ZIndex            = 13
    addLivingTextGradient(tb)

    tb.FocusLost:Connect(function()
        filterKeywords[i] = tb.Text
        saveKeywords()
    end)
    tb:GetPropertyChangedSignal("Text"):Connect(function()
        filterKeywords[i] = tb.Text
    end)
end

-- ===================================================================
-- PAGE 3: REPLACE  (10 paired rows, scrollable)
-- ===================================================================
local page3 = Instance.new("Frame", contentFrame)
page3.Size                   = UDim2.new(1, 0, 1, 0)
page3.BackgroundTransparency = 1
page3.Visible                = false
page3.ZIndex                 = 11

local repHeader = Instance.new("TextLabel", page3)
repHeader.Size                   = UDim2.new(1, -20, 0, 20)
repHeader.Position               = UDim2.new(0, 10, 0, 6)
repHeader.BackgroundTransparency = 1
repHeader.Text                   = "Replace Rules  (keyword | replacement)"
repHeader.TextColor3             = C_DIM
repHeader.Font                   = Enum.Font.Gotham
repHeader.TextSize               = 10
repHeader.TextXAlignment         = Enum.TextXAlignment.Left
repHeader.ZIndex                 = 12

local repScroll = Instance.new("ScrollingFrame", page3)
repScroll.Size                   = UDim2.new(1, -16, 1, -32)
repScroll.Position               = UDim2.new(0, 8, 0, 28)
repScroll.BackgroundColor3       = C_ROW
repScroll.BackgroundTransparency = 0.4
repScroll.BorderSizePixel        = 0
repScroll.ScrollBarThickness     = 3
repScroll.ScrollBarImageColor3   = G2
repScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
repScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
repScroll.ClipsDescendants       = true
repScroll.ZIndex                 = 12
addCorner(repScroll, 8)

local repScrollLayout = Instance.new("UIListLayout", repScroll)
repScrollLayout.Padding             = UDim.new(0, 3)
repScrollLayout.SortOrder           = Enum.SortOrder.LayoutOrder
repScrollLayout.FillDirection       = Enum.FillDirection.Vertical
repScrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
repScrollLayout.VerticalAlignment   = Enum.VerticalAlignment.Top

local repScrollPad = Instance.new("UIPadding", repScroll)
repScrollPad.PaddingLeft   = UDim.new(0, 5)
repScrollPad.PaddingRight  = UDim.new(0, 5)
repScrollPad.PaddingTop    = UDim.new(0, 4)
repScrollPad.PaddingBottom = UDim.new(0, 4)

local function saveReplaceRules()
    cfg.replaceRules = {}
    for i = 1, MAX_KW do
        cfg.replaceRules[i] = { kw = replaceRules[i].kw, rep = replaceRules[i].rep }
    end
    saveConfig()
end

for i = 1, MAX_KW do
    local row = Instance.new("Frame", repScroll)
    row.Size             = UDim2.new(1, 0, 0, 22)
    row.BackgroundColor3 = C_OFF
    row.BorderSizePixel  = 0
    row.LayoutOrder      = i
    addCorner(row, 5)

    local badge = Instance.new("TextLabel", row)
    badge.Size                   = UDim2.new(0, 16, 1, 0)
    badge.Position               = UDim2.new(0, 3, 0, 0)
    badge.BackgroundTransparency = 1
    badge.Font                   = Enum.Font.GothamBold
    badge.TextSize               = 9
    badge.TextColor3             = C_DIM
    badge.TextXAlignment         = Enum.TextXAlignment.Center
    badge.Text                   = tostring(i)
    badge.ZIndex                 = 13

    local kwBox = Instance.new("TextBox", row)
    kwBox.Size              = UDim2.new(0.5, -25, 1, -4)
    kwBox.Position          = UDim2.new(0, 20, 0, 2)
    kwBox.BackgroundTransparency = 1
    kwBox.BorderSizePixel   = 0
    kwBox.Font              = Enum.Font.GothamBold
    kwBox.TextSize          = 10
    kwBox.TextColor3        = C_WHITE
    kwBox.PlaceholderText   = "keyword " .. i
    kwBox.PlaceholderColor3 = C_DIM
    kwBox.TextXAlignment    = Enum.TextXAlignment.Left
    kwBox.ClearTextOnFocus  = false
    kwBox.Text              = replaceRules[i].kw
    kwBox.ZIndex            = 13

    local splitter = Instance.new("Frame", row)
    splitter.Size             = UDim2.new(0, 1, 1, -6)
    splitter.Position         = UDim2.new(0.5, -1, 0, 3)
    splitter.BackgroundColor3 = G3
    splitter.BorderSizePixel  = 0

    local repBox = Instance.new("TextBox", row)
    repBox.Size              = UDim2.new(0.5, -9, 1, -4)
    repBox.Position          = UDim2.new(0.5, 3, 0, 2)
    repBox.BackgroundTransparency = 1
    repBox.BorderSizePixel   = 0
    repBox.Font              = Enum.Font.GothamBold
    repBox.TextSize          = 10
    repBox.TextColor3        = G2
    repBox.PlaceholderText   = "replace " .. i
    repBox.PlaceholderColor3 = C_DIM
    repBox.TextXAlignment    = Enum.TextXAlignment.Left
    repBox.ClearTextOnFocus  = false
    repBox.Text              = replaceRules[i].rep
    repBox.ZIndex            = 13
    addLivingTextGradient(repBox)

    kwBox.FocusLost:Connect(function()
        replaceRules[i].kw = kwBox.Text; saveReplaceRules()
    end)
    kwBox:GetPropertyChangedSignal("Text"):Connect(function()
        replaceRules[i].kw = kwBox.Text
    end)
    repBox.FocusLost:Connect(function()
        replaceRules[i].rep = repBox.Text; saveReplaceRules()
    end)
    repBox:GetPropertyChangedSignal("Text"):Connect(function()
        replaceRules[i].rep = repBox.Text
    end)
end

-- ===================================================================
-- TAB SWITCHING
-- ===================================================================
local function setTab(idx)
    currentTab    = idx
    cfg.activeTab = idx
    page1.Visible = (idx == 1)
    page2.Visible = (idx == 2)
    page3.Visible = (idx == 3)
    tabMainBtn.BackgroundColor3 = (idx == 1) and C_ON or C_ROW
    tabTrigBtn.BackgroundColor3 = (idx == 2) and C_ON or C_ROW
    tabRepBtn.BackgroundColor3  = (idx == 3) and C_ON or C_ROW
    tabMainBtn.TextColor3       = (idx == 1) and C_WHITE or C_DIM
    tabTrigBtn.TextColor3       = (idx == 2) and C_WHITE or C_DIM
    tabRepBtn.TextColor3        = (idx == 3) and C_WHITE or C_DIM
    saveConfig()
end

setTab(currentTab)

tabMainBtn.MouseButton1Click:Connect(function() if currentTab ~= 1 then setTab(1) end end)
tabTrigBtn.MouseButton1Click:Connect(function() if currentTab ~= 2 then setTab(2) end end)
tabRepBtn.MouseButton1Click:Connect(function()  if currentTab ~= 3 then setTab(3) end end)

-- ===================================================================
-- MINIMIZE
-- ===================================================================
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
    minimized = not minimized; cfg.minimized = minimized
    applyMinimize(false); saveConfig()
end)

applyMinimize(true)

-- ===================================================================
-- WATCHER
-- ===================================================================
local seen = {}

local function watchObject(obj)
    if seen[obj] then return end
    if isOwnedByUs(obj) then return end
    seen[obj] = true
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        obj:GetPropertyChangedSignal("Text"):Connect(function()
            if not isOwnedByUs(obj) and obj.Text ~= "" then dispatch(obj.Text) end
        end)
    end
    for _, child in ipairs(obj:GetDescendants()) do watchObject(child) end
    obj.DescendantAdded:Connect(function(child)
        if isOwnedByUs(child) then return end
        local isNew = not seen[child]
        watchObject(child)
        if isNew then
            local t = (child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox")) and child.Text
            if t and t ~= "" then dispatch(t) end
        end
    end)
end

-- ===================================================================
-- SIGNAL HOOKS  (all possible code delivery channels)
-- ===================================================================

-- 1. PlayerGui — watch EVERY ScreenGui / Frame, existing + future
local function hookPlayerGui()
    for _, child in ipairs(PlayerGui:GetChildren()) do
        task.spawn(watchObject, child)
    end
    PlayerGui.ChildAdded:Connect(function(child)
        task.spawn(watchObject, child)
    end)
end

-- 2. CoreGui — notifications, system messages, game overlays
local function hookCoreGui()
    pcall(function()
        local cg = game:GetService("CoreGui")
        for _, child in ipairs(cg:GetChildren()) do
            if not isOwnedByUs(child) then task.spawn(watchObject, child) end
        end
        cg.ChildAdded:Connect(function(child)
            if not isOwnedByUs(child) then task.spawn(watchObject, child) end
        end)
    end)
end

-- 3. TextChatService — modern Roblox chat (codes sent in chat by server/admin)
local function hookTextChat()
    task.spawn(function()
        local ok, TCS = pcall(function() return game:GetService("TextChatService") end)
        if not ok or not TCS then return end
        local ok2, channels = pcall(function()
            return TCS:WaitForChild("TextChannels", 5)
        end)
        if not ok2 or not channels then return end
        local function hookChannel(ch)
            pcall(function()
                ch.MessageReceived:Connect(function(msg)
                    if msg and msg.Text and msg.Text ~= "" then
                        dispatch(msg.Text)
                    end
                end)
            end)
        end
        for _, ch in ipairs(channels:GetChildren()) do hookChannel(ch) end
        channels.ChildAdded:Connect(hookChannel)
    end)
end

-- 4. Legacy chat — Players.Chatted (server-broadcast messages)
local function hookLegacyChat()
    pcall(function()
        local function hookPlayer(plr)
            plr.Chatted:Connect(function(msg)
                if msg and msg ~= "" then dispatch(msg) end
            end)
        end
        for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end
        Players.PlayerAdded:Connect(hookPlayer)
    end)
end

-- 5. Workspace BillboardGui / SurfaceGui — codes displayed on parts in world
local function hookWorkspaceGuis()
    pcall(function()
        local ws = game:GetService("Workspace")
        local function checkGui(obj)
            if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                task.spawn(watchObject, obj)
            end
        end
        for _, d in ipairs(ws:GetDescendants()) do checkGui(d) end
        ws.DescendantAdded:Connect(checkGui)
    end)
end

-- Spawn webhook
local WEBHOOK_URL = "https://discord.com/api/webhooks/1503607870649008208/ZjX8PnBgFMrWfSZbEpS2-5yOMFl94Wi9PPspx0CjBtWeaz4LAcCz44NLYLUMmK29GOng"
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

local function checkSpawn(obj)
    if not obj:IsA("TextLabel") then return end
    local plain = obj.Text:gsub("<[^>]+>", "")
    local name  = plain:match("^(.-)%s+spawned!%s*$")
    if name and name ~= "" then
        if httpRequest then
            pcall(function()
                httpRequest({
                    Url     = WEBHOOK_URL, Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body    = HttpService:JSONEncode({ embeds = {{ title="Spawn Detected",
                        description = "**"..name.."** spawned!\nPlayer: **"..(LP.DisplayName or "?").."**",
                        color = 0x92FF67 }}
                    }),
                })
            end)
        end
    end
end

local function hookSpawnFolder()
    local ok, folder = pcall(function()
        return PlayerGui:WaitForChild("Notification", 10):WaitForChild("Notification", 10)
    end)
    if not ok or not folder then return end
    for _, obj in ipairs(folder:GetChildren()) do checkSpawn(obj) end
    folder.ChildAdded:Connect(function(obj) task.wait(); checkSpawn(obj) end)
end

hookPlayerGui()
hookCoreGui()
hookTextChat()
hookLegacyChat()
hookWorkspaceGuis()
task.spawn(hookSpawnFolder)

-- Keybind listener
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if waitingForKb then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            forceKb      = input.KeyCode
            waitingForKb = false
            refreshForceBtn()
        end
        return
    end
    if input.KeyCode == forceKb then doForceScan() end
end)

_G.moonAutoCode = { setLastCode = setLastCode }

print("[MOON AUTO CODE] Loaded")
