--[[
================================================================================
YSLEM HUB v2 — Steal a Brainrot
================================================================================
Scratchpad for Stealing Brainrot Game Bot
Features: Auto Steal, Auto Carry, Speed Boost, Anti-Ragdoll, FPS Boost
UI redesign + Auto Carry on Grab + fixes

Deobfuscation Notes:
- Expanded variable abbreviations for readability
- Added descriptive comments for sections
- Renamed internal variables to reflect their purpose
- Organized constants with meaningful names
================================================================================
]]

-- ===================================================================
-- ROBLOX SERVICES & GAME REFERENCES
-- ===================================================================
local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = PlayersService.LocalPlayer

-- ===================================================================
-- FORWARD DECLARATIONS (prevent mobile crash)
-- ===================================================================
local startAutoLeftPatrol, stopAutoLeftPatrol, startAutoRightPatrol, stopAutoRightPatrol
local startAntiRagdoll, stopAntiRagdoll
local setupMedusaCounter, stopMedusaCounter
local applyFPSBoost, autoSaveConfig
local setInstaGrab, setAutoBat, setInfJump, setAntiRag, setFps, setMedusaCounter, setAutoTpDown
local setUnwalkToggle, setAutoLeft, setAutoRight, setAutoCarry
local setMenuDropBR, setMenuTpDown
local startAutoSteal, stopAutoSteal
local refreshUIToggles
local modeValueLabel, normalSpeedBox, carrySpeedBox, laggerSpeedBox, carryLaggerSpeedBox
local progressRadialLabel

-- ===================================================================
-- GAME STATE MANAGEMENT
-- ===================================================================
local GameState = {
	-- Speed settings (walk velocity in studs/second)
	normalSpeed = 60,
	carrySpeed = 30,
	laggerSpeed = 13,
	laggerCarrySpeed = 13,

	-- Current movement mode
	speedType = "normal",  -- "normal" or "carry"

	-- Lagger mode (exploit unstable physics for speed)
	laggerActive = false,
	laggerCarryActive = false,

	-- Features toggle states
	autoBatToggled = false,
	hittingCooldown = false,
	infJumpEnabled = false,
	infJumpMode = "manual",
	antiRagdollEnabled = false,
	fpsBoostEnabled = false,
	guiVisible = true,
	isStealing = false,
	autoCarryOnGrab = true,  -- Auto switch to carry mode when grabbing brainrot

	-- Medusa glitch counter
	medusaLastUsed = 0,
	medusaDebounce = false,
	medusaCounterEnabled = false,

	-- Drop brainrot feature
	dropBrainrotActive = false,

	-- Teleport down feature
	autoTpDownEnabled = false,
	autoTpDownY = 20,

	-- Auto movement patterns
	autoLeftEnabled = false,
	autoRightEnabled = false,
	autoLeftPhase = 1,
	autoRightPhase = 1,

	-- Internal state
	_tpInProgress = false,
	lastMoveDirection = Vector3.new(0, 0, 0),
	unwalkEnabled = false,

	-- Keybindings (customizable)
	keyAutoLeft = Enum.KeyCode.Unknown,
	keyAutoRight = Enum.KeyCode.Unknown,
	keyDropBR = Enum.KeyCode.Unknown,
	keyTpDown = Enum.KeyCode.Unknown,
	keyAutoBat = Enum.KeyCode.Unknown,
}

-- ===================================================================
-- AUTO STEAL SYSTEM
-- ===================================================================
local AutoStealSystem = {
	Enabled = false,
	Radius = 20,  -- Detection radius for grab prompts
	Duration = 1.2,  -- Hold duration in seconds
	IsStealing = false,
	Data = {},  -- Cached prompt data
	ProgressFill = nil,  -- UI progress bar
	ProgressText = nil,  -- UI progress text
	RetryMax = 2,  -- Max retry attempts per prompt
}

-- Cache for determining plot ownership
local plotOwnershipCache = {}
local PLOT_CACHE_TTL = 2  -- Cache time-to-live in seconds

-- Proximity prompt cache
local promptsNearbyCache = nil
local promptsCacheTime = 0
local PROMPT_CACHE_TTL = 0.08  -- Very short cache for responsiveness
local lastHumanoidRootPartPosition = Vector3.new(0, 0, 0)

-- ===================================================================
-- HELPER: Check if a plot belongs to the player
-- ===================================================================
local function isPlotOwnedByPlayer(plotName)
	local currentTime = tick()
	local cachedResult = plotOwnershipCache[plotName]

	-- Return cached result if still valid
	if cachedResult and (currentTime - cachedResult.timestamp) < PLOT_CACHE_TTL then
		return cachedResult.isOwned
	end

	-- Query workspace for plot ownership
	local plotsContainer = workspace:FindFirstChild("Plots")
	if not plotsContainer then
		plotOwnershipCache[plotName] = { isOwned = false, timestamp = currentTime }
		return false
	end

	local plot = plotsContainer:FindFirstChild(plotName)
	if not plot then
		plotOwnershipCache[plotName] = { isOwned = false, timestamp = currentTime }
		return false
	end

	-- Check "YourBase" billboard GUI indicator
	local plotSign = plot:FindFirstChild("PlotSign")
	local isOwned = false
	if plotSign then
		local yourBaseBillboard = plotSign:FindFirstChild("YourBase")
		if yourBaseBillboard and yourBaseBillboard:IsA("BillboardGui") then
			isOwned = yourBaseBillboard.Enabled == true
		end
	end

	plotOwnershipCache[plotName] = { isOwned = isOwned, timestamp = currentTime }
	return isOwned
end

-- ===================================================================
-- HELPER: Find nearby steal prompts within radius
-- ===================================================================
local function findNearbyStealPrompts()
	local currentTime = tick()

	-- Return cached results if still valid
	if promptsNearbyCache and (currentTime - promptsCacheTime) < PROMPT_CACHE_TTL then
		return promptsNearbyCache
	end

	local character = LocalPlayer.Character
	local characterRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not characterRootPart then
		promptsNearbyCache = {}
		promptsCacheTime = currentTime
		return {}
	end

	local plotsContainer = workspace:FindFirstChild("Plots")
	if not plotsContainer then
		promptsNearbyCache = {}
		promptsCacheTime = currentTime
		return {}
	end

	-- Search all plots for nearby grab prompts
	local foundPrompts = {}
	for _, plot in ipairs(plotsContainer:GetChildren()) do
		if not isPlotOwnedByPlayer(plot.Name) then
			local podiumsContainer = plot:FindFirstChild("AnimalPodiums")
			if podiumsContainer then
				for _, podium in ipairs(podiumsContainer:GetChildren()) do
					pcall(function()
						local podiumBase = podium:FindFirstChild("Base")
						local podiumSpawn = podiumBase and podiumBase:FindFirstChild("Spawn")

						if podiumSpawn then
							local distanceToSpawn = (podiumSpawn.Position - characterRootPart.Position).Magnitude
							if distanceToSpawn <= AutoStealSystem.Radius then
								local promptAttachment = podiumSpawn:FindFirstChild("PromptAttachment")
								if promptAttachment then
									for _, childObject in ipairs(promptAttachment:GetChildren()) do
										if childObject:IsA("ProximityPrompt") then
											table.insert(foundPrompts, {
												prompt = childObject,
												distance = distanceToSpawn,
												animalName = podium.Name
											})
											break
										end
									end
								end
							end
						end
					end)
				end
			end
		end
	end

	-- Sort by distance (nearest first)
	table.sort(foundPrompts, function(a, b) return a.distance < b.distance end)

	promptsNearbyCache = foundPrompts
	promptsCacheTime = currentTime
	return foundPrompts
end

-- Invalidate cache when player moves significantly
RunService.Heartbeat:Connect(function()
	local character = LocalPlayer.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	if (humanoidRootPart.Position - lastHumanoidRootPartPosition).Magnitude > 1 then
		lastHumanoidRootPartPosition = humanoidRootPart.Position
		promptsNearbyCache = nil
	end
end)

-- ===================================================================
-- HELPER: Initialize cached data for a steal prompt
-- ===================================================================
local function initializeStealPromptData(prompt)
	if AutoStealSystem.Data[prompt] then return end

	AutoStealSystem.Data[prompt] = {
		holdBeganConnections = {},
		triggeredConnections = {},
		isReadyToSteal = true,
		failureCount = 0,
		useFallbackMethod = false
	}

	-- Try to extract connection functions for more natural stealing
	pcall(function()
		if getconnections then
			for _, connection in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
				if connection.Function then
					table.insert(AutoStealSystem.Data[prompt].holdBeganConnections, connection.Function)
				end
			end

			for _, connection in ipairs(getconnections(prompt.Triggered)) do
				if connection.Function then
					table.insert(AutoStealSystem.Data[prompt].triggeredConnections, connection.Function)
				end
			end

			-- If no connections found, must use fallback
			if #AutoStealSystem.Data[prompt].holdBeganConnections == 0 and
			   #AutoStealSystem.Data[prompt].triggeredConnections == 0 then
				AutoStealSystem.Data[prompt].useFallbackMethod = true
			end
		else
			AutoStealSystem.Data[prompt].useFallbackMethod = true
		end
	end)
end

-- ===================================================================
-- HELPER: Attempt to activate a steal prompt (one attempt)
-- ===================================================================
local function attemptStealPromptOnce(prompt, promptData)
	local holdDuration = AutoStealSystem.Duration

	-- NOTE: We do NOT modify prompt.MaxActivationDistance (server detects and bans)

	-- Method 1: Simulate hold begin (if connections available)
	if not promptData.useFallbackMethod and #promptData.holdBeganConnections > 0 then
		pcall(function()
			for _, connectionFunction in ipairs(promptData.holdBeganConnections) do
				task.spawn(connectionFunction)
			end
		end)
	end

	-- Wait with slight humanized variation (avoid pattern detection)
	task.wait(holdDuration + math.random() * 0.08)

	-- Method 2: fireproximityprompt (most reliable if available)
	if fireproximityprompt then
		local success = pcall(function() fireproximityprompt(prompt) end)
		if success then
			task.wait(0.05 + math.random() * 0.05)
			return true
		end
	end

	-- Method 3: Trigger connections directly (if available)
	if not promptData.useFallbackMethod and #promptData.triggeredConnections > 0 then
		local success = pcall(function()
			for _, connectionFunction in ipairs(promptData.triggeredConnections) do
				task.spawn(connectionFunction)
			end
		end)
		if success then
			task.wait(0.05)
			return true
		end
	end

	-- Method 4: Native InputHold (most natural, preferred)
	local success = pcall(function()
		prompt:InputHoldBegin()
		task.wait(holdDuration)
		prompt:InputHoldEnd()
	end)

	return success
end

-- ===================================================================
-- AUTO CARRY MODE: Activate when grabbing brainrot
-- ===================================================================
local function setCarryMode(shouldCarry)
	if not GameState.autoCarryOnGrab then return end
	if GameState.laggerActive or GameState.laggerCarryActive then return end

	local desiredMode = shouldCarry and "carry" or "normal"
	if GameState.speedType == desiredMode then return end

	GameState.speedType = desiredMode
	if refreshUIToggles then refreshUIToggles() end

	if MobileButtons and MobileButtons.Buttons and MobileButtons.Buttons.carrySpeed then
		MobileButtons.Buttons.carrySpeed(shouldCarry)
	end

	autoSaveConfig()
end

-- Debug flag for carry detection
local CARRY_DEBUG = false  -- Disabled, was causing spam
local _walkSpeedConnection = nil

local function setupCarryDetection(humanoid) end  -- Replaced by setupFullDebug

local function setupFullDebug(character, humanoid, humanoidRootPart)
	if not CARRY_DEBUG then return end

	-- 1) Monitor HRP children (brainrot attached via Weld)
	if humanoidRootPart then
		humanoidRootPart.ChildAdded:Connect(function(child)
			print("[DEBUG HRP.ChildAdded]", child.ClassName, "Name=", child.Name)
		end)
		humanoidRootPart.ChildRemoved:Connect(function(child)
			print("[DEBUG HRP.ChildRemoved]", child.ClassName, "Name=", child.Name)
		end)
	end

	-- 2) Monitor character attributes
	character.AttributeChanged:Connect(function(attributeName)
		print("[DEBUG CHAR.Attr]", attributeName, "=", tostring(character:GetAttribute(attributeName)))
	end)

	-- 3) Monitor player object attributes and children
	LocalPlayer.AttributeChanged:Connect(function(attributeName)
		print("[DEBUG LP.Attr]", attributeName, "=", tostring(LocalPlayer:GetAttribute(attributeName)))
	end)
	LocalPlayer.ChildAdded:Connect(function(child)
		print("[DEBUG LP.ChildAdded]", child.ClassName, "Name=", child.Name)
	end)

	-- 4) Monitor WalkSpeed changes
	if humanoid then
		humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			print("[DEBUG WalkSpeed] =", humanoid.WalkSpeed)
		end)
		humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
			print("[DEBUG JumpPower] =", humanoid.JumpPower)
		end)
	end

	print("[DEBUG] Active → steal a brainrot and watch F9 console")
end

local _toolWatchConnections = {}
local function watchCharacterTools(character) end

-- ===================================================================
-- EXECUTE STEAL: Main steal logic with retry
-- ===================================================================
local function executeStealAttempt(prompt, animalName)
	if AutoStealSystem.IsStealing then return end
	if not prompt or not prompt.Parent then return end

	initializeStealPromptData(prompt)
	local promptData = AutoStealSystem.Data[prompt]
	if not promptData or not promptData.isReadyToSteal then return end

	promptData.isReadyToSteal = false
	AutoStealSystem.IsStealing = true
	GameState.isStealing = true
	local stealStartTime = tick()

	-- Animate progress bar
	local progressConnection
	progressConnection = RunService.Heartbeat:Connect(function()
		if not AutoStealSystem.IsStealing then
			progressConnection:Disconnect()
			return
		end

		local progress = math.clamp((tick() - stealStartTime) / AutoStealSystem.Duration, 0, 1)
		if AutoStealSystem.ProgressFill then
			AutoStealSystem.ProgressFill.Size = UDim2.new(progress, 0, 1, 0)
		end
		if AutoStealSystem.ProgressText then
			AutoStealSystem.ProgressText.Text = math.floor(progress * 100) .. "%"
		end
	end)

	task.spawn(function()
		local stealSuccessful = false
		local attemptCount = 0

		-- Retry loop with fallback escalation
		while not stealSuccessful and attemptCount < AutoStealSystem.RetryMax do
			attemptCount = attemptCount + 1
			stealSuccessful = attemptStealPromptOnce(prompt, promptData)

			if not stealSuccessful then
				promptData.failureCount = (promptData.failureCount or 0) + 1
				if promptData.failureCount >= 3 then
					promptData.useFallbackMethod = true
				end
				task.wait(0.03)
			end
		end

		AutoStealSystem.IsStealing = false
		GameState.isStealing = false
		promptData.isReadyToSteal = true

		-- Auto-carry triggered by Tool added to character
		-- (more reliable than checking steal success)
		task.wait(0.4)

		if not AutoStealSystem.IsStealing and AutoStealSystem.ProgressFill then
			TweenService:Create(
				AutoStealSystem.ProgressFill,
				TweenInfo.new(0.3),
				{ Size = UDim2.new(0, 0, 1, 0) }
			):Play()
		end

		if AutoStealSystem.ProgressText then
			AutoStealSystem.ProgressText.Text = "0%"
		end

		promptsNearbyCache = nil
	end)
end

-- ===================================================================
-- AUTO STEAL LOOP
-- ===================================================================
local autoStealLoopConnection = nil
startAutoSteal = function()
	if autoStealLoopConnection then return end

	local lastCheckTime = 0
	autoStealLoopConnection = RunService.Heartbeat:Connect(function()
		if not AutoStealSystem.Enabled or AutoStealSystem.IsStealing then return end

		local currentTime = tick()
		if currentTime - lastCheckTime < 0.05 then return end
		lastCheckTime = currentTime

		local nearbyPrompts = findNearbyStealPrompts()
		if nearbyPrompts and #nearbyPrompts > 0 then
			executeStealAttempt(nearbyPrompts[1].prompt, nearbyPrompts[1].animalName)
		end
	end)
end

stopAutoSteal = function()
	if autoStealLoopConnection then
		autoStealLoopConnection:Disconnect()
		autoStealLoopConnection = nil
	end

	AutoStealSystem.IsStealing = false
	GameState.isStealing = false
	promptsNearbyCache = nil

	-- Reset all prompts to ready state
	for promptObject, promptData in pairs(AutoStealSystem.Data) do
		if promptData.isReadyToSteal ~= nil then
			promptData.isReadyToSteal = true
		end
	end
end

-- ===================================================================
-- CONSTANTS & CONFIGURATION
-- ===================================================================
local MOVEMENT_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Right] = true,
}

local DROP_BRAINROT_ASCEND_DURATION = 0.2
local DROP_BRAINROT_ASCEND_SPEED = 150

-- Waypoint locations (specific to game world)
local WAYPOINT_LOCATIONS = {
	L1 = Vector3.new(-476.48, -6.28, 92.73),
	L2 = Vector3.new(-483.12, -4.95, 94.80),
	R1 = Vector3.new(-476.16, -6.52, 25.62),
	R2 = Vector3.new(-483.04, -5.09, 23.14),
}

local ConnectionsByFeature = {
	antiRagdoll = nil,
	autoLeftPatrol = nil,
	autoRightPatrol = nil,
	anchorParts = {}
}

-- ===================================================================
-- PROXY PART SYSTEM (Anti-rollback by SZG)
-- Instead of modifying HRP velocity (server rollback detection),
-- create invisible Part welded to HRP and modify its velocity.
-- This bypasses anti-cheat while maintaining physics.
-- ===================================================================
local proxyPart = nil

local function ensureProxyPartExists()
	local character = LocalPlayer.Character
	if not character then return nil end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return nil end

	-- Reuse existing proxy if valid
	if proxyPart and proxyPart.Parent == character then
		return proxyPart
	end

	-- Destroy old proxy and create new one
	if proxyPart then pcall(function() proxyPart:Destroy() end) end

	proxyPart = Instance.new("Part")
	proxyPart.Name = "YslemProxy"
	proxyPart.Size = Vector3.new(1, 1, 1)
	proxyPart.Transparency = 1
	proxyPart.CanCollide = false
	proxyPart.Massless = true
	proxyPart.Parent = character

	-- Weld proxy to HRP
	local weldConstraint = Instance.new("Weld")
	weldConstraint.Part0 = humanoidRootPart
	weldConstraint.Part1 = proxyPart
	weldConstraint.C0 = CFrame.new(0, 0, 0)
	weldConstraint.Parent = proxyPart

	return proxyPart
end

local function moveViaProxy(direction, speed)
	local character = LocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local proxy = ensureProxyPartExists()

	-- Use humanoid:Move() for direction input
	if humanoid then humanoid:Move(direction, false) end

	-- Use proxy for speed modification (avoids HRP velocity detection)
	if proxy then
		proxy.AssemblyLinearVelocity = Vector3.new(
			direction.X * speed,
			proxy.AssemblyLinearVelocity.Y,
			direction.Z * speed
		)
	end
end

local function stopProxyMovement()
	local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Move(Vector3.zero, false) end

	if proxyPart then
		proxyPart.AssemblyLinearVelocity = Vector3.new(0, proxyPart.AssemblyLinearVelocity.Y, 0)
	end
end

-- ===================================================================
-- COLOR PALETTE (Vibrant Purple + Pink Theme)
-- ===================================================================
local ColorPalette = {
	Background = Color3.fromRGB(8, 8, 11),
	Panel = Color3.fromRGB(15, 15, 20),
	Row = Color3.fromRGB(20, 20, 27),
	RowHover = Color3.fromRGB(28, 28, 38),
	Border = Color3.fromRGB(38, 34, 58),
	BorderHighlight = Color3.fromRGB(88, 70, 150),
	Header = Color3.fromRGB(12, 12, 16),
	TextPrimary = Color3.fromRGB(228, 222, 245),
	TextSecondary = Color3.fromRGB(196, 160, 255),
	TextMuted = Color3.fromRGB(110, 110, 125),
	TextBright = Color3.fromRGB(255, 255, 255),
	ToggleOnBackground = Color3.fromRGB(74, 46, 128),
	ToggleOffBackground = Color3.fromRGB(24, 24, 32),
	AccentPurple = Color3.fromRGB(168, 85, 247),
	AccentPink = Color3.fromRGB(236, 72, 153),
}

-- ===================================================================
-- CONFIG AUTO-SAVE SYSTEM
-- ===================================================================
local configSaveDebounce = false
local MobileButtons = {
	Visible = true,
	Locked = true,
	Containers = {},
	Buttons = {}
}

autoSaveConfig = function()
	if configSaveDebounce then return end
	configSaveDebounce = true

	task.delay(0.5, function()
		local configData = {
			normalSpeed = GameState.normalSpeed,
			carrySpeed = GameState.carrySpeed,
			laggerSpeed = GameState.laggerSpeed,
			laggerCarrySpeed = GameState.laggerCarrySpeed,
			speedType = GameState.speedType,
			laggerActive = GameState.laggerActive,
			laggerCarryActive = GameState.laggerCarryActive,
			autoBatToggled = GameState.autoBatToggled,
			autoLeftEnabled = GameState.autoLeftEnabled,
			autoRightEnabled = GameState.autoRightEnabled,
			autoStealEnabled = AutoStealSystem.Enabled,
			grabRadius = AutoStealSystem.Radius,
			grabDuration = AutoStealSystem.Duration,
			autoCarryOnGrab = GameState.autoCarryOnGrab,
			infJump = GameState.infJumpEnabled,
			infJumpMode = GameState.infJumpMode,
			antiRagdoll = GameState.antiRagdollEnabled,
			fpsBoost = GameState.fpsBoostEnabled,
			medusaCounter = GameState.medusaCounterEnabled,
			unwalkEnabled = GameState.unwalkEnabled,
			autoTpDown = GameState.autoTpDownEnabled,
			autoTpDownY = GameState.autoTpDownY,
			mobileVisible = MobileButtons.Visible,
			mobileLocked = MobileButtons.Locked,
			keyAutoLeft = GameState.keyAutoLeft.Name,
			keyAutoRight = GameState.keyAutoRight.Name,
			keyDropBR = GameState.keyDropBR.Name,
			keyTpDown = GameState.keyTpDown.Name,
			keyAutoBat = GameState.keyAutoBat.Name,
		}

		pcall(function()
			writefile("YslemHubConfig.json", HttpService:JSONEncode(configData))
		end)

		configSaveDebounce = false
	end)
end

-- ===================================================================
-- SPEED MODE MANAGEMENT
-- ===================================================================
local function deactivateAllSpeedModes()
	if GameState.speedType == "carry" then
		GameState.speedType = "normal"
		if MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(false) end
	end

	if GameState.laggerActive then
		GameState.laggerActive = false
		AutoStealSystem.Enabled = false
		if setInstaGrab then setInstaGrab(false) end
		stopAutoSteal()
		if MobileButtons.Buttons.lagger then MobileButtons.Buttons.lagger(false) end
	end

	if GameState.laggerCarryActive then
		GameState.laggerCarryActive = false
		AutoStealSystem.Enabled = false
		if setInstaGrab then setInstaGrab(false) end
		stopAutoSteal()
		if MobileButtons.Buttons.laggerCarry then MobileButtons.Buttons.laggerCarry(false) end
	end
end

local function toggleCarrySpeedMode()
	if GameState.speedType == "carry" then
		GameState.speedType = "normal"
		refreshUIToggles()
		autoSaveConfig()
		if MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(false) end
		return
	end

	deactivateAllSpeedModes()
	GameState.speedType = "carry"
	refreshUIToggles()
	autoSaveConfig()
	if MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(true) end
end

local function toggleLaggerMode()
	if GameState.laggerActive then
		GameState.laggerActive = false
		AutoStealSystem.Enabled = false
		if setInstaGrab then setInstaGrab(false) end
		stopAutoSteal()
		refreshUIToggles()
		autoSaveConfig()
		if MobileButtons.Buttons.lagger then MobileButtons.Buttons.lagger(false) end
		return
	end

	deactivateAllSpeedModes()
	GameState.laggerActive = true
	AutoStealSystem.Enabled = true
	if setInstaGrab then setInstaGrab(true) end
	startAutoSteal()
	refreshUIToggles()
	autoSaveConfig()
	if MobileButtons.Buttons.lagger then MobileButtons.Buttons.lagger(true) end
end

local function toggleLaggerCarryMode()
	if GameState.laggerCarryActive then
		GameState.laggerCarryActive = false
		AutoStealSystem.Enabled = false
		if setInstaGrab then setInstaGrab(false) end
		stopAutoSteal()
		refreshUIToggles()
		autoSaveConfig()
		if MobileButtons.Buttons.laggerCarry then MobileButtons.Buttons.laggerCarry(false) end
		return
	end

	deactivateAllSpeedModes()
	GameState.laggerCarryActive = true
	AutoStealSystem.Enabled = true
	if setInstaGrab then setInstaGrab(true) end
	startAutoSteal()
	refreshUIToggles()
	autoSaveConfig()
	if MobileButtons.Buttons.laggerCarry then MobileButtons.Buttons.laggerCarry(true) end
end

local function getCurrentMovementSpeed()
	if GameState.laggerCarryActive then
		return GameState.laggerCarrySpeed
	elseif GameState.laggerActive then
		return GameState.laggerCarrySpeed
	else
		return GameState.speedType == "normal" and GameState.normalSpeed or GameState.carrySpeed
	end
end

local function getAutoMovementSpeed()
	if GameState.laggerCarryActive then
		return GameState.normalSpeed
	elseif GameState.laggerActive then
		return GameState.laggerSpeed
	else
		return GameState.normalSpeed
	end
end

-- ===================================================================
-- TELEPORT DOWN FEATURE
-- ===================================================================
local function teleportPlayerToGround()
	local character = LocalPlayer.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local currentRotation = humanoidRootPart.CFrame.Rotation

	-- Raycast down to find ground
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local raycastResult = workspace:Raycast(
		humanoidRootPart.Position,
		Vector3.new(0, -500, 0),
		raycastParams
	)

	-- Teleport to ground with offset
	if raycastResult then
		humanoidRootPart.CFrame = CFrame.new(raycastResult.Position + Vector3.new(0, 3, 0)) * currentRotation
	else
		humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position + Vector3.new(0, -20, 0)) * currentRotation
	end
end

-- ===================================================================
-- DROP BRAINROT FEATURE
-- ===================================================================
local function executeBrainrotDrop()
	if GameState.dropBrainrotActive then return end

	local character = LocalPlayer.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	GameState.dropBrainrotActive = true
	local dropStartTime = tick()

	local heartbeatConnection
	heartbeatConnection = RunService.Heartbeat:Connect(function()
		local currentRoot = character and character:FindFirstChild("HumanoidRootPart")
		if not currentRoot then
			heartbeatConnection:Disconnect()
			GameState.dropBrainrotActive = false
			return
		end

		if tick() - dropStartTime >= DROP_BRAINROT_ASCEND_DURATION then
			heartbeatConnection:Disconnect()

			-- Raycast down to find ground after ascending
			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = { character }
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude

			local raycastResult = workspace:Raycast(
				currentRoot.Position,
				Vector3.new(0, -2000, 0),
				raycastParams
			)

			if raycastResult then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local hipHeightOffset = (humanoid and humanoid.HipHeight or 2) + (currentRoot.Size.Y / 2)
				currentRoot.CFrame = CFrame.new(
					currentRoot.Position.X,
					raycastResult.Position.Y + hipHeightOffset,
					currentRoot.Position.Z
				)
				currentRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			end

			GameState.dropBrainrotActive = false
			return
		end

		-- Ascend at constant speed
		currentRoot.AssemblyLinearVelocity = Vector3.new(
			currentRoot.AssemblyLinearVelocity.X,
			DROP_BRAINROT_ASCEND_SPEED,
			currentRoot.AssemblyLinearVelocity.Z
		)
	end)
end

-- ===================================================================
-- AUTO PATROL: LEFT PATH
-- ===================================================================
local leftPatrolWaypoints = {
	Vector3.new(-476.85, -6.59, 94.91),
	Vector3.new(-485.55, -4.53, 100.61),
	Vector3.new(-475.60, -6.59, 92.80),
	Vector3.new(-475.26, -6.57, 21.54),
}

local rightPatrolWaypoints = {
	Vector3.new(-475.77, -6.57, 26.76),
	Vector3.new(-485.85, -4.48, 20.13),
	Vector3.new(-475.83, -6.59, 26.54),
	Vector3.new(-476.17, -6.09, 97.73),
}

local currentPatrolConnection = nil
local currentPatrolWaypoints = nil
local currentPatrolWaypointIndex = 1

local function moveTowardPatrolWaypoint(targetWaypoint, speed)
	local humanoidRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local directionVector = (targetWaypoint - humanoidRootPart.Position)
	local moveDirection = Vector3.new(directionVector.X, 0, directionVector.Z).Unit

	local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Move(moveDirection, false) end

	moveViaProxy(moveDirection, speed)
end

startAutoLeftPatrol = function()
	stopAutoLeftPatrol()
	stopAutoRightPatrol()

	GameState.autoLeftPhase = 1
	currentPatrolWaypointIndex = 1
	currentPatrolWaypoints = leftPatrolWaypoints
	ensureProxyPartExists()
	GameState.speedType = "normal"

	if refreshUIToggles then refreshUIToggles() end
	if MobileButtons.Buttons and MobileButtons.Buttons.carrySpeed then
		MobileButtons.Buttons.carrySpeed(false)
	end

	currentPatrolConnection = RunService.Stepped:Connect(function()
		if not GameState.autoLeftEnabled or not currentPatrolWaypoints then return end

		local character = LocalPlayer.Character
		if not character then return end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then return end

		local targetWaypoint = currentPatrolWaypoints[currentPatrolWaypointIndex]
		if not targetWaypoint then return end

		local distanceToWaypoint = (targetWaypoint - humanoidRootPart.Position).Magnitude
		local movementSpeed = (currentPatrolWaypointIndex <= 2) and GameState.normalSpeed or GameState.carrySpeed

		if distanceToWaypoint < 2.5 then
			currentPatrolWaypointIndex = currentPatrolWaypointIndex + 1

			if currentPatrolWaypointIndex > #currentPatrolWaypoints then
				stopProxyMovement()
				GameState.autoLeftEnabled = false

				if currentPatrolConnection then
					currentPatrolConnection:Disconnect()
					currentPatrolConnection = nil
				end

				currentPatrolWaypoints = nil
				currentPatrolWaypointIndex = 1

				if setAutoLeft then setAutoLeft(false) end
				if MobileButtons.Buttons.autoLeft then MobileButtons.Buttons.autoLeft(false) end

				-- Auto-carry mode at end of patrol
				if GameState.autoCarryOnGrab then
					GameState.speedType = "carry"
					if refreshUIToggles then refreshUIToggles() end
					if MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(true) end
					autoSaveConfig()
				end

				return
			end
		else
			moveTowardPatrolWaypoint(targetWaypoint, movementSpeed)
		end
	end)
end

stopAutoLeftPatrol = function()
	if currentPatrolConnection and GameState.autoLeftEnabled then
		currentPatrolConnection:Disconnect()
		currentPatrolConnection = nil
	end

	currentPatrolWaypoints = nil
	currentPatrolWaypointIndex = 1
	stopProxyMovement()
	GameState.autoLeftPhase = 1

	if MobileButtons.Buttons.autoLeft then
		MobileButtons.Buttons.autoLeft(false)
	end
end

-- ===================================================================
-- AUTO PATROL: RIGHT PATH
-- ===================================================================
startAutoRightPatrol = function()
	stopAutoRightPatrol()
	stopAutoLeftPatrol()

	GameState.autoRightPhase = 1
	currentPatrolWaypointIndex = 1
	currentPatrolWaypoints = rightPatrolWaypoints
	ensureProxyPartExists()
	GameState.speedType = "normal"

	if refreshUIToggles then refreshUIToggles() end
	if MobileButtons.Buttons and MobileButtons.Buttons.carrySpeed then
		MobileButtons.Buttons.carrySpeed(false)
	end

	currentPatrolConnection = RunService.Stepped:Connect(function()
		if not GameState.autoRightEnabled or not currentPatrolWaypoints then return end

		local character = LocalPlayer.Character
		if not character then return end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then return end

		local targetWaypoint = currentPatrolWaypoints[currentPatrolWaypointIndex]
		if not targetWaypoint then return end

		local distanceToWaypoint = (targetWaypoint - humanoidRootPart.Position).Magnitude
		local movementSpeed = (currentPatrolWaypointIndex <= 2) and GameState.normalSpeed or GameState.carrySpeed

		if distanceToWaypoint < 2.5 then
			currentPatrolWaypointIndex = currentPatrolWaypointIndex + 1

			if currentPatrolWaypointIndex > #currentPatrolWaypoints then
				stopProxyMovement()
				GameState.autoRightEnabled = false

				if currentPatrolConnection then
					currentPatrolConnection:Disconnect()
					currentPatrolConnection = nil
				end

				currentPatrolWaypoints = nil
				currentPatrolWaypointIndex = 1

				if setAutoRight then setAutoRight(false) end
				if MobileButtons.Buttons.autoRight then MobileButtons.Buttons.autoRight(false) end

				-- Auto-carry mode at end of patrol
				if GameState.autoCarryOnGrab then
					GameState.speedType = "carry"
					if refreshUIToggles then refreshUIToggles() end
					if MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(true) end
					autoSaveConfig()
				end

				return
			end
		else
			moveTowardPatrolWaypoint(targetWaypoint, movementSpeed)
		end
	end)
end

stopAutoRightPatrol = function()
	if currentPatrolConnection and GameState.autoRightEnabled then
		currentPatrolConnection:Disconnect()
		currentPatrolConnection = nil
	end

	currentPatrolWaypoints = nil
	currentPatrolWaypointIndex = 1
	stopProxyMovement()
	GameState.autoRightPhase = 1

	if MobileButtons.Buttons.autoRight then
		MobileButtons.Buttons.autoRight(false)
	end
end

-- ===================================================================
-- ANTI-RAGDOLL SYSTEM
-- ===================================================================
startAntiRagdoll = function()
	if ConnectionsByFeature.antiRagdoll then return end

	local lastCheckTime = 0
	ConnectionsByFeature.antiRagdoll = RunService.Heartbeat:Connect(function()
		local currentTime = tick()
		if currentTime - lastCheckTime < 0.1 then return end
		lastCheckTime = currentTime

		local character = LocalPlayer.Character
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

		if humanoid then
			local humanoidState = humanoid:GetState()

			-- Recover from ragdoll states
			if humanoidState == Enum.HumanoidStateType.Physics or
			   humanoidState == Enum.HumanoidStateType.Ragdoll or
			   humanoidState == Enum.HumanoidStateType.FallingDown then
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
				workspace.CurrentCamera.CameraSubject = humanoid

				-- Re-enable player controls
				pcall(function()
					local playerModule = LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")
					if playerModule then
						require(playerModule:FindFirstChild("ControlModule")):Enable()
					end
				end)

				-- Clear velocities
				if humanoidRootPart then
					humanoidRootPart.Velocity = Vector3.zero
					humanoidRootPart.RotVelocity = Vector3.zero
				end
			end
		end

		-- Re-enable all motors in character
		for _, descendantObject in ipairs(character:GetDescendants()) do
			if descendantObject:IsA("Motor6D") and not descendantObject.Enabled then
				descendantObject.Enabled = true
			end
		end
	end)
end

stopAntiRagdoll = function()
	if ConnectionsByFeature.antiRagdoll then
		ConnectionsByFeature.antiRagdoll:Disconnect()
		ConnectionsByFeature.antiRagdoll = nil
	end
end

-- ===================================================================
-- FPS BOOST SYSTEM
-- ===================================================================
applyFPSBoost = function()
	-- Set FPS cap to maximum
	pcall(function() setfpscap(999999999) end)

	local function optimizeObject(object)
		pcall(function()
			if object:IsA("Model") then
				object.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled
			elseif object:IsA("MeshPart") then
				object.CastShadow = false
				object.RenderFidelity = Enum.RenderFidelity.Performance
			elseif object:IsA("BasePart") then
				object.CastShadow = false
				object.Material = Enum.Material.Plastic
				object.Reflectance = 0
			elseif object:IsA("Decal") or object:IsA("Texture") then
				object.Transparency = 1
			elseif object:IsA("SpecialMesh") then
				object.TextureId = ""
			elseif object:IsA("Fire") or object:IsA("SpotLight") or object:IsA("Smoke") or
				   object:IsA("Sparkles") or object:IsA("ParticleEmitter") or object:IsA("Trail") or
				   object:IsA("Beam") then
				object.Enabled = false
			elseif object:IsA("SurfaceAppearance") then
				object:Destroy()
			end
		end)
	end

	-- Optimize all workspace objects
	for _, workspaceChild in pairs(workspace:GetDescendants()) do
		optimizeObject(workspaceChild)
	end

	-- Optimize lighting
	pcall(function()
		local lightingService = game:GetService("Lighting")
		for _, lightChild in pairs(lightingService:GetDescendants()) do
			pcall(function()
				if lightChild:IsA("Sky") or lightChild:IsA("Atmosphere") or
				   lightChild:IsA("BloomEffect") or lightChild:IsA("BlurEffect") or
				   lightChild:IsA("SunRaysEffect") or lightChild:IsA("DepthOfFieldEffect") or
				   lightChild:IsA("ColorCorrectionEffect") then
					lightChild:Destroy()
				end
			end)
		end

		lightingService.GlobalShadows = false
		lightingService.FogEnd = 9e9
		lightingService.Brightness = 0
	end)

	-- Optimize new objects as they're added
	workspace.DescendantAdded:Connect(function(newObject)
		if GameState.fpsBoostEnabled then
			task.spawn(optimizeObject, newObject)
		end
	end)
end

-- ===================================================================
-- INITIALIZATION
-- ===================================================================
print("[Yslem Hub v2] Script loaded successfully!")
