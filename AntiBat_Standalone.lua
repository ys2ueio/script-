-- ===================================================================
-- ANTI BAT STANDALONE
-- ===================================================================
local _NS = tostring(math.random(0x100000, 0xFFFFFF))..tostring(tick()):gsub("%.", "")
if _G[_NS] then return end; _G[_NS] = true

if not game:IsLoaded() then game.Loaded:Wait() end

-- ===================================================================
-- SERVICES
-- ===================================================================
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local LP         = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

-- ===================================================================
-- BAT NAMES
-- ===================================================================
local BAT_NAMES = {
	"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap",
	"Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap",
	"Nuclear Slap","Galaxy Slap","Glitched Slap",
}

-- ===================================================================
-- BC — VELOCITY SPIKE (Envy logic — 1000 spike + XZ restore)
-- ===================================================================
local BC = {active = false, conn = nil}

function BC.start()
	if BC.conn then BC.conn:Disconnect() end
	BC.conn = RunService.Heartbeat:Connect(function()
		if not BC.active then return end
		local char = LP.Character; if not char then return end
		local hum  = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if not hum or not root then return end
		if hum.MoveDirection.Magnitude <= 0 then return end
		local vel = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(vel.X * 50, 50, vel.Z * 50)
		RunService.RenderStepped:Wait()
		root.AssemblyLinearVelocity = vel + Vector3.new(0, 0.05, 0)
	end)
end

function BC.stop()
	if BC.conn then BC.conn:Disconnect(); BC.conn = nil end
end

-- ===================================================================
-- BAT COUNTER — AUTO COUNTER-SWING ON HIT
-- ===================================================================
local BatCounter  = {active = false, conn = nil}
local _bcDebounce = false

local function findBatForCounter()
	local c  = LP.Character; if not c then return nil end
	local bp = LP:FindFirstChildOfClass("Backpack")
	for _, name in ipairs(BAT_NAMES) do
		local t = c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
		if t then return t end
	end
	for _, ch in ipairs(c:GetChildren()) do
		if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
	end
	if bp then
		for _, ch in ipairs(bp:GetChildren()) do
			if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
		end
	end
	return nil
end

local function swingBatForCounter(bat, char)
	local hum2 = char:FindFirstChildOfClass("Humanoid")
	if bat.Parent ~= char then
		if hum2 then pcall(function() hum2:EquipTool(bat) end) end
		task.wait(0.05)
	end
	local remote = bat:FindFirstChildOfClass("RemoteEvent") or bat:FindFirstChildOfClass("RemoteFunction")
	if remote and remote:IsA("RemoteEvent") then
		pcall(function() remote:FireServer() end)
		task.wait(0.15)
		pcall(function() remote:FireServer() end)
	else
		pcall(function() bat:Activate() end)
		task.wait(0.15)
		pcall(function() bat:Activate() end)
	end
end

function BatCounter.start()
	if BatCounter.conn then BatCounter.conn:Disconnect() end
	BatCounter.conn = RunService.Heartbeat:Connect(function()
		if not BatCounter.active or _bcDebounce then return end
		local char = LP.Character; if not char then return end
		local hum2 = char:FindFirstChildOfClass("Humanoid"); if not hum2 then return end
		local st   = hum2:GetState()
		if st == Enum.HumanoidStateType.Physics
			or st == Enum.HumanoidStateType.Ragdoll
			or st == Enum.HumanoidStateType.FallingDown
		then
			_bcDebounce = true
			task.spawn(function()
				local bat = findBatForCounter()
				if bat then swingBatForCounter(bat, char) end
				task.wait(0.5); _bcDebounce = false
			end)
		end
	end)
end

function BatCounter.stop()
	if BatCounter.conn then BatCounter.conn:Disconnect(); BatCounter.conn = nil end
	_bcDebounce = false
end

-- ===================================================================
-- TOGGLE
-- ===================================================================
local _antiBatOn = false

local function applyAntiBat(on)
	_antiBatOn        = on
	BC.active         = on
	BatCounter.active = on
	if on then
		BC.start()
		BatCounter.start()
	else
		BC.stop()
		BatCounter.stop()
	end
end

-- ===================================================================
-- GUI — SCREENGUI + COREGUI PARENT
-- ===================================================================
local sg = Instance.new("ScreenGui")
sg.Name           = "AntiBatStandalone"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local _guiOk = pcall(function()
	if syn and syn.protect_gui then
		syn.protect_gui(sg); sg.Parent = game:GetService("CoreGui")
	elseif gethui then
		sg.Parent = gethui()
	else
		sg.Parent = game:GetService("CoreGui")
	end
end)
if not _guiOk then sg.Parent = LP:FindFirstChildOfClass("PlayerGui") end

local frame = Instance.new("Frame", sg)
frame.Name             = "Container"
frame.Size             = UDim2.new(0, 172, 0, 72)
frame.Position         = UDim2.new(0, 24, 0, 24)
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BorderSizePixel  = 0
frame.Active           = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local fStroke = Instance.new("UIStroke", frame)
fStroke.Color     = Color3.fromRGB(40, 46, 58)
fStroke.Thickness = 1

local toggleBtn = Instance.new("TextButton", frame)
toggleBtn.Name             = "ToggleBtn"
toggleBtn.Size             = UDim2.new(1, -16, 0, 34)
toggleBtn.Position         = UDim2.new(0, 8, 0, 8)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
toggleBtn.BorderSizePixel  = 0
toggleBtn.Text             = "ANTI BAT: OFF"
toggleBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.TextSize         = 13
toggleBtn.AutoButtonColor  = false
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 5)
local tStroke = Instance.new("UIStroke", toggleBtn)
tStroke.Color     = Color3.fromRGB(60, 60, 60)
tStroke.Thickness = 1

local kbBtn = Instance.new("TextButton", frame)
kbBtn.Name             = "KeybindBtn"
kbBtn.Size             = UDim2.new(1, -16, 0, 18)
kbBtn.Position         = UDim2.new(0, 8, 0, 46)
kbBtn.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
kbBtn.BorderSizePixel  = 0
kbBtn.Text             = "Key: B  (click to rebind)"
kbBtn.TextColor3       = Color3.fromRGB(155, 155, 155)
kbBtn.Font             = Enum.Font.Gotham
kbBtn.TextSize         = 10
kbBtn.AutoButtonColor  = false
Instance.new("UICorner", kbBtn).CornerRadius = UDim.new(0, 4)

-- ===================================================================
-- DRAGGABLE
-- ===================================================================
do
	local dragging, dragStart, startPos
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging  = true
			dragStart = input.Position
			startPos  = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local d = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
end

-- ===================================================================
-- VISUAL UPDATE
-- ===================================================================
local function refreshVisual()
	if _antiBatOn then
		toggleBtn.Text             = "ANTI BAT: ON"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 130, 55)
		tStroke.Color              = Color3.fromRGB(35, 190, 85)
	else
		toggleBtn.Text             = "ANTI BAT: OFF"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		tStroke.Color              = Color3.fromRGB(60, 60, 60)
	end
end

-- ===================================================================
-- KEYBIND
-- ===================================================================
local currentKey = Enum.KeyCode.B
local rebinding  = false

kbBtn.MouseButton1Click:Connect(function()
	rebinding        = true
	kbBtn.Text       = "Press any key..."
	kbBtn.TextColor3 = Color3.fromRGB(255, 220, 80)
end)

toggleBtn.MouseButton1Click:Connect(function()
	applyAntiBat(not _antiBatOn)
	refreshVisual()
end)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if rebinding then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			currentKey       = input.KeyCode
			rebinding        = false
			kbBtn.Text       = "Key: "..input.KeyCode.Name.."  (click to rebind)"
			kbBtn.TextColor3 = Color3.fromRGB(155, 155, 155)
		end
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard
		and input.KeyCode == currentKey
	then
		applyAntiBat(not _antiBatOn)
		refreshVisual()
	end
end)

-- ===================================================================
-- INIT
-- ===================================================================
BC.active         = false
BatCounter.active = false
