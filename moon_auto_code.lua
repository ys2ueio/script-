local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LP           = Players.LocalPlayer
local PlayerGui    = LP:WaitForChild("PlayerGui")

-- ===================================================================
-- CONFIG  (persisted)
-- ===================================================================
local CFG_PATH = "moon_autocode_cfg.json"
local cfg = {
    autoCode     = true,
    captureCount = 4,
    keyword      = "code is",
    replaceKw    = "admin war",
    replaceWith  = "jandel",
    posX         = 16,
    posY         = 80,
    minimized    = false,
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
-- COLOUR / STYLE  (exact test_speed.lua theme)
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
local autoCode       = cfg.autoCode
local captureCount   = cfg.captureCount
local keyword        = cfg.keyword
local replaceKw      = cfg.replaceKw
local replaceWith    = cfg.replaceWith

local collecting      = false
local collectBuf      = {}
local collectRemain   = 0
local forceScanActive = false

local _pillLbl  = nil   -- assigned after GUI
local _statLbl  = nil   -- assigned after GUI

local function setScanState(txt)
    if _pillLbl then _pillLbl.Text = txt end
end

local function setStatus(txt)
    print("[MOON AUTO CODE] " .. txt)
    if _statLbl then _statLbl.Text = txt end
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
        local Codes  = PlayerGui:WaitForChild("Codes", 3).Codes
        local tb     = Codes.CodeRedeem.TextBox
        local cfm    = Codes.Confirm
        tb.Text      = code
        local btn    = cfm:FindFirstChildWhichIsA("TextButton") or cfm
        if btn then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
        end
    end)
end

local function matchesKeyword(text)
    if not text or text == "" then return false end
    if keyword == "" then return true end
    return text:lower():find(keyword:lower(), 1, true) ~= nil
end

local function applyReplace(text)
    if not text or text == "" or replaceKw == "" then return nil end
    if text:lower():find(replaceKw:lower(), 1, true) then return replaceWith end
    return nil
end

local function dispatch(text)
    if not text or text == "" then return end

    if forceScanActive and collecting then
        table.insert(collectBuf, text)
        collectRemain = collectRemain - 1
        setScanState("COLLECTING " .. collectRemain)
        if collectRemain <= 0 then
            local result = table.concat(collectBuf)
            setStatus("Code: " .. result)
            redeemCode(result)
            collecting = false; collectBuf = {}; collectRemain = 0; forceScanActive = false
            setScanState("SCANNING")
        end
        return
    end

    if captureCount > 0 then
        if collecting then
            local rep = applyReplace(text)
            table.insert(collectBuf, rep ~= nil and rep or text)
            collectRemain = collectRemain - 1
            setScanState("COLLECTING " .. collectRemain)
            if collectRemain <= 0 then
                local result = table.concat(collectBuf)
                if result ~= "" then
                    setStatus("Code: " .. result)
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

    if matchesKeyword(text) then
        local rep    = applyReplace(text)
        local result = rep ~= nil and rep or text
        if result ~= "" then
            setStatus("Code: " .. result)
            if autoCode then redeemCode(result) end
        end
    end
end

-- ===================================================================
-- STATUS PILL  (same design as steal widget in test_speed.lua)
-- ===================================================================
local pillWidget = Instance.new("Frame", gui)
pillWidget.Name                = "ScanPill"
pillWidget.Size                = UDim2.new(0, 200, 0, 36)
pillWidget.Position            = UDim2.new(0.5, -100, 0, 35)
pillWidget.BackgroundTransparency = 1
pillWidget.Active              = true

local pill = Instance.new("Frame", pillWidget)
pill.Size                   = UDim2.new(1, 0, 1, 0)
pill.BackgroundColor3       = C_BG
pill.BackgroundTransparency = 0.1
pill.BorderSizePixel        = 0
pill.ClipsDescendants       = true
addCorner(pill, 18)
addLivingStroke(pill, 1.5)

_pillLbl = Instance.new("TextLabel", pill)
_pillLbl.Size                   = UDim2.new(0.56, -16, 1, 0)
_pillLbl.Position               = UDim2.new(0, 16, 0, 0)
_pillLbl.BackgroundTransparency = 1
_pillLbl.Text                   = "SCANNING"
_pillLbl.TextColor3             = C_WHITE
_pillLbl.Font                   = Enum.Font.GothamBlack
_pillLbl.TextSize               = 13
_pillLbl.TextXAlignment         = Enum.TextXAlignment.Left
_pillLbl.ZIndex                 = 5
addLivingTextGradient(_pillLbl)

local pillInfo = Instance.new("TextLabel", pill)
pillInfo.Size                   = UDim2.new(0.44, -16, 1, 0)
pillInfo.Position               = UDim2.new(0.56, 0, 0, 0)
pillInfo.BackgroundTransparency = 1
pillInfo.Text                   = "0 FPS | 0ms"
pillInfo.TextColor3             = C_WHITE
pillInfo.Font                   = Enum.Font.GothamBold
pillInfo.TextSize               = 13
pillInfo.TextXAlignment         = Enum.TextXAlignment.Right
pillInfo.ZIndex                 = 5
addLivingTextGradient(pillInfo)

-- FPS / Ping loop (exact test_speed.lua)
local frameCount, lastFpsTime, lastFps, lastPing = 0, tick(), 60, 0
local function refreshPillInfo() pillInfo.Text = lastFps .. " FPS | " .. lastPing .. "ms" end
RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = tick()
    if now - lastFpsTime >= 1 then
        lastFps = math.floor(frameCount / (now - lastFpsTime))
        frameCount = 0; lastFpsTime = now; refreshPillInfo()
    end
end)
task.spawn(function()
    local Stats = game:GetService("Stats")
    while true do task.wait(0.5); pcall(function()
        local ns  = Stats:FindFirstChild("Network")
        local sci = ns and ns:FindFirstChild("ServerStatsItem")
        local dp  = sci and sci:FindFirstChild("Data Ping")
        lastPing  = dp and math.floor(dp:GetValue() or 0) or 0
        refreshPillInfo()
    end) end
end)

-- ===================================================================
-- MAIN PANEL  (identical frame to test_speed.lua)
-- ===================================================================
local PANEL_H = 272
local panel   = Instance.new("Frame", gui)
panel.Size            = UDim2.new(0, 220, 0, PANEL_H)
panel.Position        = UDim2.new(0, cfg.posX, 0, cfg.posY)
panel.BackgroundColor3 = C_BG
panel.BorderSizePixel = 0
panel.Active          = true
panel.ZIndex          = 10
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
minBtn.Position               = UDim2.new(1, -26, 0, 4)
minBtn.BackgroundTransparency = 1
minBtn.Text                   = "-"
minBtn.TextColor3             = C_WHITE
minBtn.Font                   = Enum.Font.GothamBlack
minBtn.TextSize               = 16
minBtn.ZIndex                 = 11
addLivingTextGradient(minBtn)

-- Title
local title = Instance.new("TextLabel", panel)
title.Size                   = UDim2.new(1, -40, 0, 20)
title.Position               = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text                   = "MOON AUTO CODE"
title.TextColor3             = C_WHITE
title.Font                   = Enum.Font.GothamBlack
title.TextSize               = 13
title.TextXAlignment         = Enum.TextXAlignment.Left
title.ZIndex                 = 11
addLivingTextGradient(title)

-- ===================================================================
-- ROW BUILDERS  (exact test_speed.lua pattern)
-- ===================================================================
local function makeInputRow(yPos, label, initial, minV, maxV, step, onChange)
    local row = Instance.new("Frame", panel)
    row.Size             = UDim2.new(1, -20, 0, 26)
    row.Position         = UDim2.new(0, 10, 0, yPos)
    row.BackgroundColor3 = C_ROW
    row.BorderSizePixel  = 0
    row.ZIndex           = 11
    addCorner(row, 8)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                   = UDim2.new(0.4, 0, 1, 0)
    lbl.Position               = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = label
    lbl.TextColor3             = Color3.fromRGB(200, 200, 200)
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextSize               = 11
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 12
    addLivingTextGradient(lbl)

    local value = initial

    local minusBtn = Instance.new("TextButton", row)
    minusBtn.Size             = UDim2.new(0, 20, 0, 20)
    minusBtn.Position         = UDim2.new(1, -92, 0.5, -10)
    minusBtn.BackgroundColor3 = C_OFF
    minusBtn.Text             = "-"
    minusBtn.TextColor3       = C_WHITE
    minusBtn.Font             = Enum.Font.GothamBlack
    minusBtn.TextSize         = 14
    minusBtn.BorderSizePixel  = 0
    minusBtn.AutoButtonColor  = false
    minusBtn.ZIndex           = 12
    addCorner(minusBtn, 6); addLivingTextGradient(minusBtn)

    local box = Instance.new("TextBox", row)
    box.Size             = UDim2.new(0, 44, 1, -6)
    box.Position         = UDim2.new(1, -68, 0, 3)
    box.BackgroundColor3 = C_OFF
    box.BorderSizePixel  = 0
    box.Text             = tostring(value)
    box.TextColor3       = C_WHITE
    box.Font             = Enum.Font.GothamBold
    box.TextSize         = 11
    box.ClearTextOnFocus = false
    box.ZIndex           = 12
    addCorner(box, 6); addLivingTextGradient(box)

    local plusBtn = Instance.new("TextButton", row)
    plusBtn.Size             = UDim2.new(0, 20, 0, 20)
    plusBtn.Position         = UDim2.new(1, -22, 0.5, -10)
    plusBtn.BackgroundColor3 = C_OFF
    plusBtn.Text             = "+"
    plusBtn.TextColor3       = C_WHITE
    plusBtn.Font             = Enum.Font.GothamBlack
    plusBtn.TextSize         = 14
    plusBtn.BorderSizePixel  = 0
    plusBtn.AutoButtonColor  = false
    plusBtn.ZIndex           = 12
    addCorner(plusBtn, 6); addLivingTextGradient(plusBtn)

    local function setValue(n)
        value = math.clamp(n, minV, maxV)
        box.Text = tostring(value)
        onChange(value)
    end
    minusBtn.MouseButton1Click:Connect(function() setValue(value - step) end)
    plusBtn.MouseButton1Click:Connect(function() setValue(value + step) end)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then setValue(n) else box.Text = tostring(value) end
    end)
    return row
end

local function makeTextRow(yPos, label, initial, onChange)
    local row = Instance.new("Frame", panel)
    row.Size             = UDim2.new(1, -20, 0, 26)
    row.Position         = UDim2.new(0, 10, 0, yPos)
    row.BackgroundColor3 = C_ROW
    row.BorderSizePixel  = 0
    row.ZIndex           = 11
    addCorner(row, 8)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                   = UDim2.new(0.38, 0, 1, 0)
    lbl.Position               = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = label
    lbl.TextColor3             = Color3.fromRGB(200, 200, 200)
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextSize               = 10
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 12
    addLivingTextGradient(lbl)

    local box = Instance.new("TextBox", row)
    box.Size             = UDim2.new(0.59, -4, 1, -6)
    box.Position         = UDim2.new(0.4, 2, 0, 3)
    box.BackgroundColor3 = C_OFF
    box.BorderSizePixel  = 0
    box.Text             = initial
    box.TextColor3       = C_WHITE
    box.Font             = Enum.Font.GothamBold
    box.TextSize         = 10
    box.ClearTextOnFocus = false
    box.PlaceholderText  = "..."
    box.PlaceholderColor3 = C_DIM
    box.ZIndex           = 12
    addCorner(box, 6); addLivingTextGradient(box)

    box.FocusLost:Connect(function() onChange(box.Text) end)
    box:GetPropertyChangedSignal("Text"):Connect(function() onChange(box.Text) end)
    return row
end

-- ===================================================================
-- ROWS
-- ===================================================================
-- y=30  Capture Count
local captureRow = makeInputRow(30, "Capture Count", captureCount, 0, 20, 1, function(n)
    captureCount = n; cfg.captureCount = n
    collecting = false; collectBuf = {}; collectRemain = 0
    saveConfig()
end)

-- y=62  Trigger keyword
local kwRow = makeTextRow(62, "Trigger KW", keyword, function(v)
    keyword = v; cfg.keyword = v; saveConfig()
end)

-- y=94  Replace keyword
local repKwRow = makeTextRow(94, "Replace KW", replaceKw, function(v)
    replaceKw = v; cfg.replaceKw = v; saveConfig()
end)

-- y=126  Replace with
local repWithRow = makeTextRow(126, "Replace With", replaceWith, function(v)
    replaceWith = v; cfg.replaceWith = v; saveConfig()
end)

-- y=160  AUTO ENTER CODE toggle  (like AUTO STEAL)
local autoBtn = Instance.new("TextButton", panel)
autoBtn.Size             = UDim2.new(1, -20, 0, 24)
autoBtn.Position         = UDim2.new(0, 10, 0, 160)
autoBtn.BackgroundColor3 = autoCode and C_ON or C_OFF
autoBtn.Text             = autoCode and "AUTO ENTER CODE: ON" or "AUTO ENTER CODE: OFF"
autoBtn.TextColor3       = autoCode and C_WHITE or C_DIM
autoBtn.Font             = Enum.Font.GothamBlack
autoBtn.TextSize         = 11
autoBtn.BorderSizePixel  = 0
autoBtn.AutoButtonColor  = false
autoBtn.ZIndex           = 11
addCorner(autoBtn, 8); addLivingTextGradient(autoBtn)
autoBtn.MouseButton1Click:Connect(function()
    autoCode = not autoCode; cfg.autoCode = autoCode
    autoBtn.Text       = autoCode and "AUTO ENTER CODE: ON" or "AUTO ENTER CODE: OFF"
    autoBtn.TextColor3 = autoCode and C_WHITE or C_DIM
    TweenService:Create(autoBtn, TweenInfo.new(0.15), {BackgroundColor3 = autoCode and C_ON or C_OFF}):Play()
    saveConfig()
end)

-- y=190  FORCE SCAN + CODE  (like SPEED button — left-click = trigger, right-click = rebind)
local forceKb         = Enum.KeyCode.F
local waitingForKb    = false

local forceBtn = Instance.new("TextButton", panel)
forceBtn.Size             = UDim2.new(1, -20, 0, 28)
forceBtn.Position         = UDim2.new(0, 10, 0, 190)
forceBtn.BackgroundColor3 = C_OFF
forceBtn.TextColor3       = C_DIM
forceBtn.Font             = Enum.Font.GothamBlack
forceBtn.TextSize         = 11
forceBtn.BorderSizePixel  = 0
forceBtn.AutoButtonColor  = false
forceBtn.ZIndex           = 11
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
    setStatus("Force scan – collecting " .. n)
    TweenService:Create(forceBtn, TweenInfo.new(0.15), {BackgroundColor3 = C_ON}):Play()
    task.delay(0.5, function()
        TweenService:Create(forceBtn, TweenInfo.new(0.3), {BackgroundColor3 = C_OFF}):Play()
    end)
end

forceBtn.MouseButton1Click:Connect(doForceScan)
forceBtn.MouseButton2Click:Connect(function()
    waitingForKb = true
    forceBtn.Text = "Press a key..."
end)
forceBtn.MouseEnter:Connect(function()
    if not waitingForKb then
        TweenService:Create(forceBtn, TweenInfo.new(0.15), {TextColor3 = C_WHITE}):Play()
    end
end)
forceBtn.MouseLeave:Connect(function()
    if not waitingForKb then
        TweenService:Create(forceBtn, TweenInfo.new(0.15), {TextColor3 = C_DIM}):Play()
    end
end)

-- y=224  Bind hint  (clic droit = rebind)
local bindHint = Instance.new("TextLabel", panel)
bindHint.Size                   = UDim2.new(1, -20, 0, 14)
bindHint.Position               = UDim2.new(0, 10, 0, 224)
bindHint.BackgroundTransparency = 1
bindHint.Text                   = "Right-click FORCE SCAN to rebind"
bindHint.TextColor3             = Color3.fromRGB(80, 80, 80)
bindHint.Font                   = Enum.Font.Gotham
bindHint.TextSize               = 9
bindHint.TextXAlignment         = Enum.TextXAlignment.Left
bindHint.ZIndex                 = 11

-- y=242  Status label (last event)
local statRow = Instance.new("Frame", panel)
statRow.Size             = UDim2.new(1, -20, 0, 18)
statRow.Position         = UDim2.new(0, 10, 0, 242)
statRow.BackgroundTransparency = 1
statRow.ZIndex           = 11

_statLbl = Instance.new("TextLabel", statRow)
_statLbl.Size                   = UDim2.new(1, 0, 1, 0)
_statLbl.BackgroundTransparency = 1
_statLbl.Text                   = "Scanning notifications..."
_statLbl.TextColor3             = C_DIM
_statLbl.Font                   = Enum.Font.Gotham
_statLbl.TextSize               = 9
_statLbl.TextXAlignment         = Enum.TextXAlignment.Left
_statLbl.TextTruncate           = Enum.TextTruncate.AtEnd
_statLbl.ZIndex                 = 11
addLivingTextGradient(_statLbl)

-- Minimize logic
local hideable = {captureRow, kwRow, repKwRow, repWithRow, autoBtn, forceBtn, bindHint, statRow}

minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized; cfg.minimized = minimized
    minBtn.Text = minimized and "+" or "-"
    panel.Size  = minimized and UDim2.new(0, 220, 0, 34) or UDim2.new(0, 220, 0, PANEL_H)
    for _, el in ipairs(hideable) do el.Visible = not minimized end
    saveConfig()
end)

if minimized then
    panel.Size = UDim2.new(0, 220, 0, 34)
    for _, el in ipairs(hideable) do el.Visible = false end
    minBtn.Text = "+"
end

-- ===================================================================
-- WATCHER  (hookContainers after GUI exists so isOwnedByUs works)
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

local function hookContainers()
    local names = { "TopNotification" }
    for _, name in ipairs(names) do
        local c = PlayerGui:FindFirstChild(name)
        if c then watchObject(c) end
    end
    PlayerGui.ChildAdded:Connect(function(child)
        for _, name in ipairs(names) do
            if child.Name == name then watchObject(child) end
        end
    end)
end

-- Spawn webhook
local WEBHOOK_URL  = "https://discord.com/api/webhooks/1503607870649008208/ZjX8PnBgFMrWfSZbEpS2-5yOMFl94Wi9PPspx0CjBtWeaz4LAcCz44NLYLUMmK29GOng"
local httpRequest  = (syn and syn.request) or (http and http.request) or http_request or request

local function checkSpawn(obj)
    if not obj:IsA("TextLabel") then return end
    local plain = obj.Text:gsub("<[^>]+>", "")
    local name  = plain:match("^(.-)%s+spawned!%s*$")
    if name and name ~= "" then
        setStatus("Spawn: " .. name)
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

hookContainers()
task.spawn(hookSpawnFolder)

-- Keybind listener
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if waitingForKb then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            forceKb    = input.KeyCode
            waitingForKb = false
            refreshForceBtn()
        end
        return
    end
    if input.KeyCode == forceKb then doForceScan() end
end)

print("[MOON AUTO CODE] Loaded")
