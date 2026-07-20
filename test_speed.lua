--[[
    test_speed.lua — Script solo : Custom Speed + Speed Bypass + Auto Grab + Steal Bar
    (extrait/adapté de MoonHub_v16.lua) — thème 100% noir, effets "Moon" en noir/blanc.

    Teste ça en jeu. Si ça te convient, dis-le moi et je remets ça
    proprement dans MoonHub_v16.lua si besoin.
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

-- ===================================================================
-- THÈME — 100% noir, aucune couleur bleue
-- ===================================================================
local C_BG    = Color3.fromRGB(0,0,0)
local C_ON    = Color3.fromRGB(30,30,30)
local C_OFF   = Color3.fromRGB(0,0,0)
local C_ROW   = Color3.fromRGB(14,14,14)
local C_WHITE = Color3.fromRGB(255,255,255)
local C_DIM   = Color3.fromRGB(130,130,130)

-- Effets "Moon" (dégradé texte + contour qui tourne en boucle) en noir/blanc/gris
local G1 = Color3.fromRGB(255,255,255)
local G2 = Color3.fromRGB(140,140,140)
local G3 = Color3.fromRGB(50,50,50)

local _livingGradients = {}
local _livingStrokes = {}

local function addCorner(inst, r)
	local c = Instance.new("UICorner", inst)
	c.CornerRadius = UDim.new(0, r or 8)
	return c
end

local function addLivingTextGradient(label)
	local g = Instance.new("UIGradient", label)
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
	local stroke = Instance.new("UIStroke", parent)
	stroke.Thickness = thickness or 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = G2
	local g = Instance.new("UIGradient", stroke)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    G3),
		ColorSequenceKeypoint.new(0.25, G2),
		ColorSequenceKeypoint.new(0.5,  G3),
		ColorSequenceKeypoint.new(0.75, G2),
		ColorSequenceKeypoint.new(1,    G3),
	})
	table.insert(_livingStrokes, g)
	return stroke, g
end

local _livingRotationSpeed = 0.6
RunService.RenderStepped:Connect(function()
	for _, g in ipairs(_livingGradients) do if g and g.Parent then g.Rotation=(g.Rotation+_livingRotationSpeed)%360 end end
	for _, g in ipairs(_livingStrokes)   do if g and g.Parent then g.Rotation=(g.Rotation+_livingRotationSpeed)%360 end end
end)

-- ===================================================================
-- CUSTOM SPEED — logique EXACTE du "Speed Booster" du hub :
-- proxy part soudé au HRP + AssemblyLinearVelocity (pas juste WalkSpeed,
-- qui peut être corrigé/ignoré par le serveur). WalkSpeed reste donc
-- intact et sert de vrai signal pour Auto Grab (voir plus bas).
-- ===================================================================
local normalSpeed = 16
local stealSpeed  = 16
local stealMode    = false  -- basculé par le bouton MODE ou automatiquement par Auto Grab

local function getCurrentSpeed()
	return stealMode and stealSpeed or normalSpeed
end

local h, hrp, proxy
local function ensureProxy()
	local char = LP.Character
	if not char then return nil end
	hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	if proxy and proxy.Parent then return proxy end
	proxy = Instance.new("Part")
	proxy.Name = "SpeedProxy"
	proxy.Size = Vector3.new(1,1,1); proxy.Transparency = 1
	proxy.CanCollide = false; proxy.Massless = true; proxy.Parent = char
	local weld = Instance.new("Weld")
	weld.Part0 = hrp; weld.Part1 = proxy; weld.C0 = CFrame.new(0,0,0); weld.Parent = proxy
	return proxy
end

local function proxyMove(dir, speed)
	local char = LP.Character; if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid"); local p = ensureProxy()
	if hum then hum:Move(dir, false) end
	if p then p.AssemblyLinearVelocity = Vector3.new(dir.X*speed, p.AssemblyLinearVelocity.Y, dir.Z*speed) end
end

local function proxyStop()
	local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum:Move(Vector3.zero, false) end
	if proxy then proxy.AssemblyLinearVelocity = Vector3.new(0, proxy.AssemblyLinearVelocity.Y, 0) end
end

local function setupChar(char)
	h = char:WaitForChild("Humanoid", 5)
	hrp = char:WaitForChild("HumanoidRootPart", 5)
	if h then h.WalkSpeed = 16 end
	ensureProxy()
end
LP.CharacterAdded:Connect(setupChar)
if LP.Character then setupChar(LP.Character) end

local customSpeedOn = false
local speedConn = nil
local function startCustomSpeed()
	if speedConn then return end
	customSpeedOn = true
	speedConn = RunService.Stepped:Connect(function()
		if not (h and hrp) then return end
		local md = h.MoveDirection
		if md.Magnitude > 0 then
			proxyMove(md, getCurrentSpeed())
		else
			proxyStop()
		end
	end)
end
local function stopCustomSpeed()
	customSpeedOn = false
	if speedConn then speedConn:Disconnect(); speedConn = nil end
	proxyStop()
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
-- AUTO GRAB — même logique que "Auto Carry On Grab" du hub :
-- surveille le vrai WalkSpeed (signal serveur) pour détecter un grab
-- et bascule automatiquement en mode STEAL. Alimente aussi la barre
-- de steal ci-dessous.
-- ===================================================================
local autoGrabOn = true
local lastCarryDetected = false
local stealBarSetState  -- déclaré plus bas, assigné après création de la barre

RunService.Heartbeat:Connect(function()
	if not autoGrabOn then return end
	local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local carrying = hum.WalkSpeed <= 25
	if carrying == lastCarryDetected then return end
	lastCarryDetected = carrying
	stealMode = carrying
	if stealBarSetState then stealBarSetState(carrying) end
end)

-- ===================================================================
-- STEAL BAR — widget séparé, 100% noir, pilotée par Auto Grab
-- ===================================================================
local stealWidget = Instance.new("Frame", gui)
stealWidget.Name = "StealBarWidget"
stealWidget.Size = UDim2.new(0,200,0,32)
stealWidget.Position = UDim2.new(0.5,-100,0,35)
stealWidget.BackgroundTransparency = 1
stealWidget.Active = true

local stealPill = Instance.new("Frame", stealWidget)
stealPill.Size = UDim2.new(1,0,0,32)
stealPill.BackgroundColor3 = C_BG
stealPill.BackgroundTransparency = 0.1
stealPill.BorderSizePixel = 0
stealPill.ClipsDescendants = true
addCorner(stealPill, 18)
local stealPillStk = addLivingStroke(stealPill, 1.5)

local stealLabel = Instance.new("TextLabel", stealPill)
stealLabel.Size = UDim2.new(0.56,-20,1,0)
stealLabel.Position = UDim2.new(0,12,0,0)
stealLabel.BackgroundTransparency = 1
stealLabel.Text = "READY"
stealLabel.TextColor3 = C_WHITE
stealLabel.Font = Enum.Font.GothamBlack
stealLabel.TextSize = 11
stealLabel.TextXAlignment = Enum.TextXAlignment.Left
stealLabel.ZIndex = 6
addLivingTextGradient(stealLabel)

local stealFill = Instance.new("Frame", stealPill)
stealFill.Size = UDim2.new(0,0,1,0)
stealFill.BackgroundColor3 = Color3.fromRGB(60,60,60)
stealFill.BackgroundTransparency = 0.35
stealFill.BorderSizePixel = 0
stealFill.ZIndex = 1
addCorner(stealFill, 18)
local stealFillGrad = Instance.new("UIGradient", stealFill)
stealFillGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(20,20,20)),
	ColorSequenceKeypoint.new(0.85, Color3.fromRGB(120,120,120)),
	ColorSequenceKeypoint.new(1, C_WHITE),
})

local stealPctLbl = Instance.new("TextLabel", stealPill)
stealPctLbl.Size = UDim2.new(0.44,-12,1,0)
stealPctLbl.Position = UDim2.new(0.56,0,0,0)
stealPctLbl.BackgroundTransparency = 1
stealPctLbl.Text = ""
stealPctLbl.TextColor3 = C_DIM
stealPctLbl.Font = Enum.Font.GothamBlack
stealPctLbl.TextSize = 11
stealPctLbl.TextXAlignment = Enum.TextXAlignment.Right
stealPctLbl.ZIndex = 6

local STEAL_DURATION = 1.4
local _stealAnimConn = nil
stealBarSetState = function(carrying)
	if _stealAnimConn then _stealAnimConn:Disconnect(); _stealAnimConn = nil end
	if carrying then
		stealLabel.Text = "CARRYING"
		local t0 = tick()
		_stealAnimConn = RunService.Heartbeat:Connect(function()
			local prog = math.clamp((tick()-t0)/STEAL_DURATION, 0, 1)
			stealFill.Size = UDim2.new(prog,0,1,0)
			stealPctLbl.Text = math.floor(prog*100).."%"
			if prog >= 1 then
				stealLabel.Text = "GRABBED"
				if _stealAnimConn then _stealAnimConn:Disconnect(); _stealAnimConn = nil end
			end
		end)
	else
		stealLabel.Text = "READY"
		stealFill.Size = UDim2.new(0,0,1,0)
		stealPctLbl.Text = ""
	end
end

-- ===================================================================
-- UI — panneau compact, en haut à gauche (ne recouvre pas l'écran)
-- ===================================================================
local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0,220,0,290)
panel.Position = UDim2.new(0,16,0,80)
panel.BackgroundColor3 = C_BG
panel.BorderSizePixel = 0
panel.Active = true
panel.ZIndex = 10
addCorner(panel, 14)
addLivingStroke(panel, 1.5)

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

-- Bouton "-" pour réduire/cacher le panneau (ne garde que la barre de titre)
local panelFullH = 290
local minimized = false
local minBtn = Instance.new("TextButton", panel)
minBtn.Size = UDim2.new(0,20,0,20)
minBtn.Position = UDim2.new(1,-26,0,4)
minBtn.BackgroundTransparency = 1
minBtn.Text = "-"
minBtn.TextColor3 = C_WHITE
minBtn.Font = Enum.Font.GothamBlack
minBtn.TextSize = 16
minBtn.ZIndex = 11

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1,-40,0,20)
title.Position = UDim2.new(0,10,0,6)
title.BackgroundTransparency = 1
title.Text = "MOON SPEED"
title.TextColor3 = C_WHITE
title.Font = Enum.Font.GothamBlack
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 11
addLivingTextGradient(title)

-- Champ avec boutons -/+ et TextBox éditable
local function makeInputRow(yPos, label, initial, min, max, step, onChange)
	local row = Instance.new("Frame", panel)
	row.Size = UDim2.new(1,-20,0,26)
	row.Position = UDim2.new(0,10,0,yPos)
	row.BackgroundColor3 = C_ROW
	row.BorderSizePixel = 0
	row.ZIndex = 11
	addCorner(row, 8)

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(0.4,0,1,0)
	lbl.Position = UDim2.new(0,8,0,0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = Color3.fromRGB(200,200,200)
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
	minusBtn.TextColor3 = C_WHITE
	minusBtn.Font = Enum.Font.GothamBlack
	minusBtn.TextSize = 14
	minusBtn.BorderSizePixel = 0
	minusBtn.AutoButtonColor = false
	minusBtn.ZIndex = 12
	addCorner(minusBtn, 6)

	local box = Instance.new("TextBox", row)
	box.Size = UDim2.new(0,44,1,-6)
	box.Position = UDim2.new(1,-68,0,3)
	box.BackgroundColor3 = C_OFF
	box.BorderSizePixel = 0
	box.Text = tostring(value)
	box.TextColor3 = C_WHITE
	box.Font = Enum.Font.GothamBold
	box.TextSize = 11
	box.ClearTextOnFocus = false
	box.ZIndex = 12
	addCorner(box, 6)

	local plusBtn = Instance.new("TextButton", row)
	plusBtn.Size = UDim2.new(0,20,0,20)
	plusBtn.Position = UDim2.new(1,-22,0.5,-10)
	plusBtn.BackgroundColor3 = C_OFF
	plusBtn.Text = "+"
	plusBtn.TextColor3 = C_WHITE
	plusBtn.Font = Enum.Font.GothamBlack
	plusBtn.TextSize = 14
	plusBtn.BorderSizePixel = 0
	plusBtn.AutoButtonColor = false
	plusBtn.ZIndex = 12
	addCorner(plusBtn, 6)

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
modeBtn.TextColor3 = C_DIM
modeBtn.Font = Enum.Font.GothamBlack
modeBtn.TextSize = 11
modeBtn.BorderSizePixel = 0
modeBtn.AutoButtonColor = false
modeBtn.ZIndex = 11
addCorner(modeBtn, 8)
modeBtn.MouseButton1Click:Connect(function()
	stealMode = not stealMode
	modeBtn.Text = stealMode and "MODE: STEAL" or "MODE: NORMAL"
	modeBtn.TextColor3 = stealMode and C_WHITE or C_DIM
	TweenService:Create(modeBtn, TweenInfo.new(0.15), {BackgroundColor3 = stealMode and C_ON or C_OFF}):Play()
end)

local speedBtn = Instance.new("TextButton", panel)
speedBtn.Size = UDim2.new(1,-20,0,30)
speedBtn.Position = UDim2.new(0,10,0,118)
speedBtn.BackgroundColor3 = C_OFF
speedBtn.Text = "SPEED: DISABLED"
speedBtn.TextColor3 = C_DIM
speedBtn.Font = Enum.Font.GothamBlack
speedBtn.TextSize = 12
speedBtn.BorderSizePixel = 0
speedBtn.AutoButtonColor = false
speedBtn.ZIndex = 11
addCorner(speedBtn, 10)
speedBtn.MouseButton1Click:Connect(function()
	if customSpeedOn then
		stopCustomSpeed()
		speedBtn.Text = "SPEED: DISABLED"
		speedBtn.TextColor3 = C_DIM
		TweenService:Create(speedBtn, TweenInfo.new(0.15), {BackgroundColor3 = C_OFF}):Play()
	else
		startCustomSpeed()
		speedBtn.Text = "SPEED: ENABLED"
		speedBtn.TextColor3 = C_WHITE
		TweenService:Create(speedBtn, TweenInfo.new(0.15), {BackgroundColor3 = C_ON}):Play()
	end
end)

local grabBtn = Instance.new("TextButton", panel)
grabBtn.Size = UDim2.new(1,-20,0,24)
grabBtn.Position = UDim2.new(0,10,0,152)
grabBtn.BackgroundColor3 = C_ON
grabBtn.Text = "AUTO GRAB: ENABLED"
grabBtn.TextColor3 = C_WHITE
grabBtn.Font = Enum.Font.GothamBlack
grabBtn.TextSize = 11
grabBtn.BorderSizePixel = 0
grabBtn.AutoButtonColor = false
grabBtn.ZIndex = 11
addCorner(grabBtn, 8)
grabBtn.MouseButton1Click:Connect(function()
	autoGrabOn = not autoGrabOn
	grabBtn.Text = autoGrabOn and "AUTO GRAB: ENABLED" or "AUTO GRAB: DISABLED"
	grabBtn.TextColor3 = autoGrabOn and C_WHITE or C_DIM
	TweenService:Create(grabBtn, TweenInfo.new(0.15), {BackgroundColor3 = autoGrabOn and C_ON or C_OFF}):Play()
	if not autoGrabOn then
		lastCarryDetected = false
		if stealBarSetState then stealBarSetState(false) end
	end
end)

local sbTitle = Instance.new("TextLabel", panel)
sbTitle.Size = UDim2.new(1,-40,0,18)
sbTitle.Position = UDim2.new(0,10,0,186)
sbTitle.BackgroundTransparency = 1
sbTitle.Text = "MOON BYPASS"
sbTitle.TextColor3 = C_WHITE
sbTitle.Font = Enum.Font.GothamBlack
sbTitle.TextSize = 12
sbTitle.TextXAlignment = Enum.TextXAlignment.Left
sbTitle.ZIndex = 11
addLivingTextGradient(sbTitle)

local sbBtn = Instance.new("TextButton", panel)
sbBtn.Size = UDim2.new(1,-20,0,26)
sbBtn.Position = UDim2.new(0,10,0,206)
sbBtn.BackgroundColor3 = C_OFF
sbBtn.Text = "BYPASS: DISABLED  (Bind: E)"
sbBtn.TextColor3 = C_DIM
sbBtn.Font = Enum.Font.GothamBlack
sbBtn.TextSize = 11
sbBtn.BorderSizePixel = 0
sbBtn.AutoButtonColor = false
sbBtn.ZIndex = 11
addCorner(sbBtn, 10)

local function refreshSbBtn()
	sbBtn.Text = (sbActive and "BYPASS: ENABLED  (Bind: " or "BYPASS: DISABLED  (Bind: ") .. sbKeybind.Name .. ")"
	sbBtn.TextColor3 = sbActive and C_WHITE or C_DIM
	TweenService:Create(sbBtn, TweenInfo.new(0.15), {BackgroundColor3 = sbActive and C_ON or C_OFF}):Play()
end
local function toggleSpeedBypass()
	sbActive = not sbActive
	if sbActive then startSpeedBypass() else stopSpeedBypass() end
	refreshSbBtn()
end
sbBtn.MouseButton1Click:Connect(toggleSpeedBypass)

local powerRow = makeInputRow(236, "Power (10k-500k)", sbPower, 10000, 500000, 5000, function(n)
	sbApplyPower(n)
end)

local bindHint = Instance.new("TextLabel", panel)
bindHint.Size = UDim2.new(1,-20,0,16)
bindHint.Position = UDim2.new(0,10,0,264)
bindHint.BackgroundTransparency = 1
bindHint.Text = "Clique le bouton BYPASS pour rebind"
bindHint.TextColor3 = Color3.fromRGB(100,100,100)
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

local hideableElements = {normalRow, stealRow, modeBtn, speedBtn, grabBtn, sbTitle, sbBtn, powerRow, bindHint}
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	minBtn.Text = minimized and "+" or "-"
	panel.Size = minimized and UDim2.new(0,220,0,34) or UDim2.new(0,220,0,panelFullH)
	for _, el in ipairs(hideableElements) do el.Visible = not minimized end
end)

print("[SpeedTest] Prêt — clic gauche = toggle, clic droit sur BYPASS = rebind touche, bouton - = réduire.")
