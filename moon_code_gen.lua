local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LP               = Players.LocalPlayer
local PlayerGui        = LP:WaitForChild("PlayerGui")

-- ===================================================================
-- COLOUR / STYLE  (Moon black theme)
-- ===================================================================
local C_BG    = Color3.fromRGB(0, 0, 0)
local C_ON    = Color3.fromRGB(30, 30, 30)
local C_OFF   = Color3.fromRGB(0, 0, 0)
local C_ROW   = Color3.fromRGB(14, 14, 14)
local C_WHITE = Color3.fromRGB(255, 255, 255)
local C_DIM   = Color3.fromRGB(130, 130, 130)
local C_GREEN = Color3.fromRGB(80, 220, 100)
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
-- GUI ROOT
-- ===================================================================
local gui = Instance.new("ScreenGui")
gui.Name           = "MoonCodeGen"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder   = 998
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui) end
    if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
    gui.Parent = (gethui and gethui()) or PlayerGui
end

-- ===================================================================
-- NOTIF INJECTOR  (writes into PlayerGui.TopNotification)
-- ===================================================================
local injectedLabels = {}

local function getTopNotif()
    local tn = PlayerGui:FindFirstChild("TopNotification")
    if not tn then
        tn = Instance.new("Frame", PlayerGui)
        tn.Name = "TopNotification"
        tn.Size = UDim2.new(0, 1, 0, 1)
        tn.BackgroundTransparency = 1
    end
    return tn
end

local function injectNotif(text, autoRemove)
    local tn  = getTopNotif()
    local lbl = Instance.new("TextLabel", tn)
    lbl.Text                   = text
    lbl.Size                   = UDim2.new(0, 300, 0, 30)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = C_WHITE
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextSize               = 14
    lbl.Visible                = true
    table.insert(injectedLabels, lbl)
    if autoRemove then
        task.delay(3, function()
            if lbl and lbl.Parent then lbl:Destroy() end
        end)
    end
    return lbl
end

local function clearAll()
    for _, lbl in ipairs(injectedLabels) do
        if lbl and lbl.Parent then lbl:Destroy() end
    end
    injectedLabels = {}
end

-- ===================================================================
-- MAIN PANEL
-- ===================================================================
local PANEL_W = 240
local PANEL_H = 336

local panel = Instance.new("Frame", gui)
panel.Size             = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position         = UDim2.new(0, 280, 0, 80)
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

-- Minimize
local minimized = false
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
titleLbl.Size                   = UDim2.new(1, -40, 0, 28)
titleLbl.Position               = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = "MOON CODE GEN"
titleLbl.TextColor3             = C_WHITE
titleLbl.Font                   = Enum.Font.GothamBlack
titleLbl.TextSize               = 13
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.ZIndex                 = 15
addLivingTextGradient(titleLbl)

-- Sub-label
local subLbl = Instance.new("TextLabel", panel)
subLbl.Size                   = UDim2.new(1, -20, 0, 14)
subLbl.Position               = UDim2.new(0, 10, 0, 28)
subLbl.BackgroundTransparency = 1
subLbl.Text                   = "Notification injector — test auto code"
subLbl.TextColor3             = C_DIM
subLbl.Font                   = Enum.Font.Gotham
subLbl.TextSize               = 9
subLbl.TextXAlignment         = Enum.TextXAlignment.Left
subLbl.ZIndex                 = 11

-- ===================================================================
-- CUSTOM NOTIF  (TextBox + Send button)
-- ===================================================================
local function sectionLabel(yPos, text)
    local lbl = Instance.new("TextLabel", panel)
    lbl.Size                   = UDim2.new(1, -20, 0, 14)
    lbl.Position               = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = text
    lbl.TextColor3             = C_DIM
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 9
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 11
    return lbl
end

local function makeBtn(yPos, h, text, color, onClick)
    local btn = Instance.new("TextButton", panel)
    btn.Size             = UDim2.new(1, -20, 0, h)
    btn.Position         = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = color or C_ROW
    btn.Text             = text
    btn.TextColor3       = C_WHITE
    btn.Font             = Enum.Font.GothamBlack
    btn.TextSize         = 11
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.ZIndex           = 11
    addCorner(btn, 8)
    addLivingTextGradient(btn)
    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = C_ON}):Play()
        task.delay(0.15, function()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = color or C_ROW}):Play()
        end)
        onClick()
    end)
    return btn
end

-- Section: Custom
sectionLabel(48, "CUSTOM NOTIFICATION")

local customBox = Instance.new("TextBox", panel)
customBox.Size             = UDim2.new(1, -20, 0, 28)
customBox.Position         = UDim2.new(0, 10, 0, 64)
customBox.BackgroundColor3 = C_ROW
customBox.BorderSizePixel  = 0
customBox.Text             = "code is"
customBox.TextColor3       = C_WHITE
customBox.Font             = Enum.Font.GothamBold
customBox.TextSize         = 11
customBox.ClearTextOnFocus = false
customBox.PlaceholderText  = "type a notification..."
customBox.PlaceholderColor3 = C_DIM
customBox.ZIndex           = 12
addCorner(customBox, 8)
addLivingTextGradient(customBox)

-- Send button (right side of custom row)
local sendBtn = Instance.new("TextButton", panel)
sendBtn.Size             = UDim2.new(0, 56, 0, 22)
sendBtn.Position         = UDim2.new(1, -66, 0, 67)
sendBtn.BackgroundColor3 = C_ON
sendBtn.Text             = "SEND"
sendBtn.TextColor3       = C_WHITE
sendBtn.Font             = Enum.Font.GothamBlack
sendBtn.TextSize         = 10
sendBtn.BorderSizePixel  = 0
sendBtn.AutoButtonColor  = false
sendBtn.ZIndex           = 13
addCorner(sendBtn, 6)
addLivingTextGradient(sendBtn)

local autoRemoveOn = true
local arBtn = Instance.new("TextButton", panel)
arBtn.Size             = UDim2.new(1, -20, 0, 18)
arBtn.Position         = UDim2.new(0, 10, 0, 96)
arBtn.BackgroundTransparency = 1
arBtn.Text             = "Auto-remove injected notifs: ON"
arBtn.TextColor3       = C_DIM
arBtn.Font             = Enum.Font.Gotham
arBtn.TextSize         = 9
arBtn.BorderSizePixel  = 0
arBtn.AutoButtonColor  = false
arBtn.TextXAlignment   = Enum.TextXAlignment.Left
arBtn.ZIndex           = 11
arBtn.MouseButton1Click:Connect(function()
    autoRemoveOn = not autoRemoveOn
    arBtn.Text = "Auto-remove injected notifs: " .. (autoRemoveOn and "ON" or "OFF")
end)

sendBtn.MouseButton1Click:Connect(function()
    local t = customBox.Text
    if t == "" then return end
    if _G.moonAutoCode and _G.moonAutoCode.setLastCode then
        _G.moonAutoCode.setLastCode(t)
    end
    TweenService:Create(sendBtn, TweenInfo.new(0.1), {BackgroundColor3 = C_GREEN}):Play()
    task.delay(0.2, function()
        TweenService:Create(sendBtn, TweenInfo.new(0.2), {BackgroundColor3 = C_ON}):Play()
    end)
end)

-- ===================================================================
-- PRESETS
-- ===================================================================
sectionLabel(120, "PRESETS  (simulate real game flow)")

-- Preset: multi-part code  (trigger + 4 parts)
makeBtn(136, 22, "▶  Trigger: \"code is\"", C_ROW, function()
    injectNotif("code is", autoRemoveOn)
end)

makeBtn(162, 22, "▶  Part 1: \"ABC\"", C_ROW, function()
    injectNotif("ABC", autoRemoveOn)
end)

makeBtn(188, 22, "▶  Part 2: \"123\"", C_ROW, function()
    injectNotif("123", autoRemoveOn)
end)

makeBtn(214, 22, "▶  Part 3: \"XYZ\"", C_ROW, function()
    injectNotif("XYZ", autoRemoveOn)
end)

makeBtn(240, 22, "▶  Part 4: \"456\"", C_ROW, function()
    injectNotif("456", autoRemoveOn)
end)

-- Full auto sequence
sectionLabel(270, "AUTO SEQUENCE  (sends all parts with delay)")

local seqRunning = false
local seqBtn = makeBtn(286, 26, "SEND FULL SEQUENCE  (0.8s delay)", Color3.fromRGB(20, 20, 20), function() end)
seqBtn.MouseButton1Click:Connect(function()
    if seqRunning then return end
    seqRunning = true
    seqBtn.Text      = "Running..."
    seqBtn.TextColor3 = C_DIM
    local parts = { "code is", "ABC", "123", "XYZ", "456" }
    task.spawn(function()
        for _, part in ipairs(parts) do
            injectNotif(part, autoRemoveOn)
            task.wait(0.8)
        end
        seqRunning       = false
        seqBtn.Text      = "SEND FULL SEQUENCE  (0.8s delay)"
        seqBtn.TextColor3 = C_WHITE
    end)
end)

-- Clear all
makeBtn(318, 14, "clear all injected", C_OFF, function()
    clearAll()
end)

-- ===================================================================
-- MINIMIZE
-- ===================================================================
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    minBtn.Text = minimized and "+" or "-"
    panel.Size  = minimized and UDim2.new(0, PANEL_W, 0, 28) or UDim2.new(0, PANEL_W, 0, PANEL_H)
    for _, child in ipairs(panel:GetChildren()) do
        if child ~= minBtn and child ~= titleLbl then
            child.Visible = not minimized
        end
    end
end)

print("[MOON CODE GEN] Loaded — injecting into PlayerGui.TopNotification")
