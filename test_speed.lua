--[[
    test_speed.lua — Script solo : Custom Speed + Speed Bypass (extrait de MoonHub_v16.lua)

    Teste ça en jeu. Si ça te convient, dis-le moi et je remets ça
    proprement dans MoonHub_v16.lua si besoin (déjà présent dedans en fait,
    ceci est juste une version isolée pour tester/ajuster tranquille).
]]

local Players     = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedTest"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
pcall(function()
	if syn and syn.protect_gui then syn.protect_gui(gui) end
	if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
	gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end

local C_BG   = Color3.fromRGB(10,10,14)
local C_MOON = Color3.fromRGB(90,160,255)
local C_ON   = Color3.fromRGB(20,45,80)
local C_OFF  = Color3.fromRGB(0,0,0)
local C_ROW  = Color3.fromRGB(22,22,28)

-- ===================================================================
-- CUSTOM SPEED — WalkSpeed normal / vol (steal), même logique que le hub
-- ===================================================================
local normalSpeed = 16
local stealSpeed  = 16
local stealMode    = false  -- basculé manuellement par le bouton MODE (plus d'auto-détection piégeuse)

local function getCurrentSpeed()
	return stealMode and stealSpeed or normalSpeed
end

local h
local function setupChar(char)
	h = char:WaitForChild("Humanoid", 5)
	if h then h.WalkSpeed = getCurrentSpeed() end
end
LP.CharacterAdded:Connect(setupChar)
if LP.Character then setupChar(LP.Character) end

local customSpeedOn = false
local speedConn = nil
local function startCustomSpeed()
	if speedConn then return end
	customSpeedOn = true
	speedConn = RunService.Heartbeat:Connect(function()
		local char = LP.Character
		h = char and char:FindFirstChildOfClass("Humanoid")
		if h then h.WalkSpeed = getCurrentSpeed() end
	end)
end
local function stopCustomSpeed()
	customSpeedOn = false
	if speedConn then speedConn:Disconnect(); speedConn = nil end
	if h then h.WalkSpeed = 16 end
end

-- ===================================================================
-- SPEED BYPASS — logique busy-wait exacte du hub (RenderStepped lag)
-- ===================================================================
local sbActive = false
local sbKeybind = Enum.KeyCode.E
local sbWaitingForKey = false
local sbPower = 79000
local sbLagAmount = 0.15
local sbConn = nil

local function sbApplyPower(val)
	sbPower = math.clamp(val, 10000, 500000)
	local t = (sbPower - 10000) / 490000
	sbLagAmount = t * 0.2
end
sbApplyPower(sbPower)

local function startSpeedBypass()
	if sbConn then sbConn:Disconnect() end
	sbConn = RunService.RenderStepped:Connect(function()
		if not sbActive then return end
		if sbLagAmount > 0 then
			local t = tick()
			while tick() - t < sbLagAmount do end
		end
	end)
end
local function stopSpeedBypass()
	sbActive = false
	if sbConn then sbConn:Disconnect(); sbConn = nil end
end

-- ===================================================================
-- UI — panneau compact, en haut à gauche (ne recouvre pas l'écran)
-- ===================================================================
local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0,220,0,258)
panel.Position = UDim2.new(0,16,0,80)
panel.BackgroundColor3 = C_BG
panel.BorderSizePixel = 0
panel.Active = true
panel.ZIndex = 10
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,14)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = C_MOON
stroke.Thickness = 1.5
stroke.Transparency = 0.3

-- Drag
do
	local dragging, dragStart, startPos = false, nil, nil
	panel.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dragStart = inp.Position; startPos = panel.Position
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	panel.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local d = inp.Position - dragStart
			panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

local closeBtn = Instance.new("TextButton", panel)
closeBtn.Size = UDim2.new(0,20,0,20)
closeBtn.Position = UDim2.new(1,-26,0,4)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.ZIndex = 11
closeBtn.MouseButton1Click:Connect(function()
	stopCustomSpeed(); stopSpeedBypass()
	gui:Destroy()
end)

-- Bouton "-" pour réduire/cacher le panneau (ne garde que la barre de titre)
local panelFullH = 258
local minimized = false
local minBtn = Instance.new("TextButton", panel)
minBtn.Size = UDim2.new(0,20,0,20)
minBtn.Position = UDim2.new(1,-50,0,4)
minBtn.BackgroundTransparency = 1
minBtn.Text = "-"
minBtn.TextColor3 = Color3.new(1,1,1)
minBtn.Font = Enum.Font.GothamBlack
minBtn.TextSize = 16
minBtn.ZIndex = 11

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1,-64,0,20)
title.Position = UDim2.new(0,10,0,6)
title.BackgroundTransparency = 1
title.Text = "CUSTOM SPEED"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBlack
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 11

-- Champ avec boutons -/+ et TextBox éditable
local function makeInputRow(yPos, label, initial, min, max, step, onChange)
	local row = Instance.new("Frame", panel)
	row.Size = UDim2.new(1,-20,0,26)
	row.Position = UDim2.new(0,10,0,yPos)
	row.BackgroundColor3 = C_ROW
	row.BorderSizePixel = 0
	row.ZIndex = 11
	Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(0.4,0,1,0)
	lbl.Position = UDim2.new(0,8,0,0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = Color3.fromRGB(200,200,210)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 12

	local value = initial

	local minusBtn = Instance.new("TextButton", row)
	minusBtn.Size = UDim2.new(0,20,0,20)
	minusBtn.Position = UDim2.new(1,-92,0.5,-10)
	minusBtn.BackgroundColor3 = C_OFF
	minusBtn.Text = "-"
	minusBtn.TextColor3 = C_MOON
	minusBtn.Font = Enum.Font.GothamBlack
	minusBtn.TextSize = 14
	minusBtn.BorderSizePixel = 0
	minusBtn.AutoButtonColor = false
	minusBtn.ZIndex = 12
	Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(0,6)

	local box = Instance.new("TextBox", row)
	box.Size = UDim2.new(0,44,1,-6)
	box.Position = UDim2.new(1,-68,0,3)
	box.BackgroundColor3 = C_OFF
	box.BorderSizePixel = 0
	box.Text = tostring(value)
	box.TextColor3 = C_MOON
	box.Font = Enum.Font.GothamBold
	box.TextSize = 11
	box.ClearTextOnFocus = false
	box.ZIndex = 12
	Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)

	local plusBtn = Instance.new("TextButton", row)
	plusBtn.Size = UDim2.new(0,20,0,20)
	plusBtn.Position = UDim2.new(1,-22,0.5,-10)
	plusBtn.BackgroundColor3 = C_OFF
	plusBtn.Text = "+"
	plusBtn.TextColor3 = C_MOON
	plusBtn.Font = Enum.Font.GothamBlack
	plusBtn.TextSize = 14
	plusBtn.BorderSizePixel = 0
	plusBtn.AutoButtonColor = false
	plusBtn.ZIndex = 12
	Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0,6)

	local function setValue(n)
		value = math.clamp(n, min, max)
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

local normalRow = makeInputRow(30, "Normal Speed", normalSpeed, 16, 500, 2, function(n) normalSpeed = n end)
local stealRow  = makeInputRow(60, "Steal Speed", stealSpeed, 16, 500, 2, function(n) stealSpeed = n end)

local modeBtn = Instance.new("TextButton", panel)
modeBtn.Size = UDim2.new(1,-20,0,24)
modeBtn.Position = UDim2.new(0,10,0,90)
modeBtn.BackgroundColor3 = C_OFF
modeBtn.Text = "MODE: NORMAL"
modeBtn.TextColor3 = Color3.fromRGB(140,140,150)
modeBtn.Font = Enum.Font.GothamBlack
modeBtn.TextSize = 11
modeBtn.BorderSizePixel = 0
modeBtn.AutoButtonColor = false
modeBtn.ZIndex = 11
Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0,8)
modeBtn.MouseButton1Click:Connect(function()
	stealMode = not stealMode
	modeBtn.Text = stealMode and "MODE: STEAL" or "MODE: NORMAL"
	modeBtn.TextColor3 = stealMode and C_MOON or Color3.fromRGB(140,140,150)
	TweenService:Create(modeBtn, TweenInfo.new(0.15), {BackgroundColor3 = stealMode and C_ON or C_OFF}):Play()
end)

local speedBtn = Instance.new("TextButton", panel)
speedBtn.Size = UDim2.new(1,-20,0,30)
speedBtn.Position = UDim2.new(0,10,0,118)
speedBtn.BackgroundColor3 = C_OFF
speedBtn.Text = "SPEED: DISABLED"
speedBtn.TextColor3 = Color3.fromRGB(140,140,150)
speedBtn.Font = Enum.Font.GothamBlack
speedBtn.TextSize = 12
speedBtn.BorderSizePixel = 0
speedBtn.AutoButtonColor = false
speedBtn.ZIndex = 11
Instance.new("UICorner", speedBtn).CornerRadius = UDim.new(0,10)
speedBtn.MouseButton1Click:Connect(function()
	if customSpeedOn then
		stopCustomSpeed()
		speedBtn.Text = "SPEED: DISABLED"
		speedBtn.TextColor3 = Color3.fromRGB(140,140,150)
		TweenService:Create(speedBtn, TweenInfo.new(0.15), {BackgroundColor3 = C_OFF}):Play()
	else
		startCustomSpeed()
		speedBtn.Text = "SPEED: ENABLED"
		speedBtn.TextColor3 = C_MOON
		TweenService:Create(speedBtn, TweenInfo.new(0.15), {BackgroundColor3 = C_ON}):Play()
	end
end)

local sbTitle = Instance.new("TextLabel", panel)
sbTitle.Size = UDim2.new(1,-40,0,18)
sbTitle.Position = UDim2.new(0,10,0,156)
sbTitle.BackgroundTransparency = 1
sbTitle.Text = "SPEED BYPASS"
sbTitle.TextColor3 = Color3.new(1,1,1)
sbTitle.Font = Enum.Font.GothamBlack
sbTitle.TextSize = 12
sbTitle.TextXAlignment = Enum.TextXAlignment.Left
sbTitle.ZIndex = 11

local sbBtn = Instance.new("TextButton", panel)
sbBtn.Size = UDim2.new(1,-20,0,26)
sbBtn.Position = UDim2.new(0,10,0,176)
sbBtn.BackgroundColor3 = C_OFF
sbBtn.Text = "BYPASS: DISABLED  (Bind: E)"
sbBtn.TextColor3 = Color3.fromRGB(140,140,150)
sbBtn.Font = Enum.Font.GothamBlack
sbBtn.TextSize = 11
sbBtn.BorderSizePixel = 0
sbBtn.AutoButtonColor = false
sbBtn.ZIndex = 11
Instance.new("UICorner", sbBtn).CornerRadius = UDim.new(0,10)

local function refreshSbBtn()
	sbBtn.Text = (sbActive and "BYPASS: ENABLED  (Bind: " or "BYPASS: DISABLED  (Bind: ") .. sbKeybind.Name .. ")"
	sbBtn.TextColor3 = sbActive and C_MOON or Color3.fromRGB(140,140,150)
	TweenService:Create(sbBtn, TweenInfo.new(0.15), {BackgroundColor3 = sbActive and C_ON or C_OFF}):Play()
end
local function toggleSpeedBypass()
	sbActive = not sbActive
	if sbActive then startSpeedBypass() else stopSpeedBypass() end
	refreshSbBtn()
end
sbBtn.MouseButton1Click:Connect(toggleSpeedBypass)

local powerRow = makeInputRow(206, "Power (10k-500k)", sbPower, 10000, 500000, 5000, function(n)
	sbApplyPower(n)
end)

local bindHint = Instance.new("TextLabel", panel)
bindHint.Size = UDim2.new(1,-20,0,16)
bindHint.Position = UDim2.new(0,10,0,234)
bindHint.BackgroundTransparency = 1
bindHint.Text = "Clique le bouton BYPASS pour rebind"
bindHint.TextColor3 = Color3.fromRGB(120,120,130)
bindHint.Font = Enum.Font.Gotham
bindHint.TextSize = 9
bindHint.TextXAlignment = Enum.TextXAlignment.Left
bindHint.ZIndex = 11

sbBtn.MouseButton2Click:Connect(function()
	sbWaitingForKey = true
	sbBtn.Text = "Appuie sur une touche..."
end)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if sbWaitingForKey then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			sbKeybind = input.KeyCode
			sbWaitingForKey = false
			refreshSbBtn()
		end
		return
	end
	if input.KeyCode == sbKeybind then toggleSpeedBypass() end
end)

local hideableElements = {normalRow, stealRow, modeBtn, speedBtn, sbTitle, sbBtn, powerRow, bindHint}
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	minBtn.Text = minimized and "+" or "-"
	panel.Size = minimized and UDim2.new(0,220,0,34) or UDim2.new(0,220,0,panelFullH)
	for _, el in ipairs(hideableElements) do el.Visible = not minimized end
end)

print("[SpeedTest] Prêt — clic gauche = toggle, clic droit sur BYPASS = rebind touche, bouton - = réduire.")
