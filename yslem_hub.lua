loadstring(game:HttpGet("https://raw.githubusercontent.com/ys2ueio/script-/refs/heads/main/yslem_hub.lua"))()--[[
-- ===================================================================
-- YSLEM HUB v2 — Steal a Brainrot
-- UI redesign + Auto Carry on Grab + fixes
-- ===================================================================
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

-- FORWARD DECLARATIONS (fix crash mobile)
local startAutoLeft, stopAutoLeft, startAutoRight, stopAutoRight
local startAntiRagdoll, stopAntiRagdoll
local setupMedusaCounter, stopMedusaCounter
local applyFPSBoost, autoSaveConfig
local setInstaGrab, setAutoBat, setInfJump, setAntiRag, setFps, setMedusaCounter, setAutoTpDown
local setUnwalkToggle, setAutoLeft, setAutoRight, setAutoCarry
local setMenuDropBR, setMenuTpDown
local startAutoSteal, stopAutoSteal
local refreshUIToggles
local modeValLbl, normalBox, carryBox, laggerBox, carryLaggerBox
local progressRadLbl

local State = {
	normalSpeed=60, carrySpeed=30, laggerSpeed=13, laggerCarrySpeed=13,
	speedType="normal",
	laggerActive=false, laggerCarryActive=false,
	autoBatToggled=false, hittingCooldown=false,
	infJumpEnabled=false, infJumpMode="manual",
	antiRagdollEnabled=false, fpsBoostEnabled=false,
	guiVisible=true,
	isStealing=false,
	autoCarryOnGrab=true,
	medusaLastUsed=0, medusaDebounce=false, medusaCounterEnabled=false,
	dropBrainrotActive=false,
	autoTpDownEnabled=false, autoTpDownY=20,
	autoLeftEnabled=false, autoRightEnabled=false,
	autoLeftPhase=1, autoRightPhase=1,
	_tpInProgress=false,
	lastMoveDir=Vector3.new(0,0,0),
	unwalkEnabled=false,
	keyAutoLeft=Enum.KeyCode.Unknown,
	keyAutoRight=Enum.KeyCode.Unknown,
	keyDropBR=Enum.KeyCode.Unknown,
	keyTpDown=Enum.KeyCode.Unknown,
	keyAutoBat=Enum.KeyCode.Unknown,
}

-- ===================================================================
-- AUTO STEAL
-- ===================================================================
local AutoSteal = {
	Enabled=false, Radius=20, Duration=1.2, IsStealing=false,
	Data={}, ProgressFill=nil, ProgressText=nil, RetryMax=2,
}

local _plotIsMyCache = {}
local PLOT_CACHE_TTL = 2

local function isMyPlotByName(plotName)
	local now = tick()
	local cached = _plotIsMyCache[plotName]
	if cached and (now - cached.t) < PLOT_CACHE_TTL then return cached.val end
	local plots = workspace:FindFirstChild("Plots")
	if not plots then _plotIsMyCache[plotName]={val=false,t=now}; return false end
	local plot = plots:FindFirstChild(plotName)
	if not plot then _plotIsMyCache[plotName]={val=false,t=now}; return false end
	local sign = plot:FindFirstChild("PlotSign")
	local r = false
	if sign then
		local yb = sign:FindFirstChild("YourBase")
		if yb and yb:IsA("BillboardGui") then r = yb.Enabled == true end
	end
	_plotIsMyCache[plotName] = {val=r, t=now}
	return r
end

local _promptCache = nil
local _promptCacheTime = 0
local PROMPT_CACHE_TTL = 0.08
local _lastHrpPos = Vector3.new(0,0,0)

local function findNearestPrompts()
	local now = tick()
	if _promptCache and (now - _promptCacheTime) < PROMPT_CACHE_TTL then return _promptCache end
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then _promptCache={}; _promptCacheTime=now; return {} end
	local plots = workspace:FindFirstChild("Plots")
	if not plots then _promptCache={}; _promptCacheTime=now; return {} end
	local results = {}
	for _, plot in ipairs(plots:GetChildren()) do
		if not isMyPlotByName(plot.Name) then
			local podiums = plot:FindFirstChild("AnimalPodiums")
			if podiums then
				for _, pod in ipairs(podiums:GetChildren()) do
					pcall(function()
						local base = pod:FindFirstChild("Base")
						local spawn = base and base:FindFirstChild("Spawn")
						if spawn then
							local dist = (spawn.Position - root.Position).Magnitude
							if dist <= AutoSteal.Radius then
								local att = spawn:FindFirstChild("PromptAttachment")
								if att then
									for _, child in ipairs(att:GetChildren()) do
										if child:IsA("ProximityPrompt") then
											table.insert(results, {prompt=child, dist=dist, name=pod.Name})
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
	table.sort(results, function(a,b) return a.dist < b.dist end)
	_promptCache = results
	_promptCacheTime = now
	return results
end

RunService.Heartbeat:Connect(function()
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if (hrp.Position - _lastHrpPos).Magnitude > 1 then
		_lastHrpPos = hrp.Position
		_promptCache = nil
	end
end)

local function initStealData(prompt)
	if AutoSteal.Data[prompt] then return end
	AutoSteal.Data[prompt] = {hold={}, trigger={}, ready=true, fails=0, useFallback=false}
	pcall(function()
		if getconnections then
			for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
				if c.Function then table.insert(AutoSteal.Data[prompt].hold, c.Function) end
			end
			for _, c in ipairs(getconnections(prompt.Triggered)) do
				if c.Function then table.insert(AutoSteal.Data[prompt].trigger, c.Function) end
			end
			if #AutoSteal.Data[prompt].hold == 0 and #AutoSteal.Data[prompt].trigger == 0 then
				AutoSteal.Data[prompt].useFallback = true
			end
		else
			AutoSteal.Data[prompt].useFallback = true
		end
	end)
end

local function tryStealOnce(prompt, data)
	local DUR = AutoSteal.Duration
	-- PAS de modification des propriétés du prompt (MaxActivationDistance etc.)
	-- Le serveur détecte ces changements → ban

	-- Démarre le hold visuel (si dispo) pendant la durée
	if not data.useFallback and #data.hold > 0 then
		pcall(function() for _, f in ipairs(data.hold) do task.spawn(f) end end)
	end
	-- Délai humanisé (légère variation pour éviter les patterns détectables)
	task.wait(DUR + math.random() * 0.08)
	-- Méthode 1 : fireproximityprompt
	if fireproximityprompt then
		local ok = pcall(function() fireproximityprompt(prompt) end)
		if ok then task.wait(0.05 + math.random() * 0.05); return true end
	end
	-- Méthode 2 : Triggered direct via getconnections
	if not data.useFallback and #data.trigger > 0 then
		local ok = pcall(function()
			for _, f in ipairs(data.trigger) do task.spawn(f) end
		end)
		if ok then task.wait(0.05); return true end
	end
	-- Méthode 3 : InputHold natif (le plus naturel, préféré)
	local ok = pcall(function()
		prompt:InputHoldBegin(); task.wait(DUR); prompt:InputHoldEnd()
	end)
	return ok
end

-- Carry mode automatique : activé UNIQUEMENT quand un Tool (brainrot) est dans les mains
local function setCarryMode(on)
	if not State.autoCarryOnGrab then return end
	if State.laggerActive or State.laggerCarryActive then return end
	local want = on and "carry" or "normal"
	if State.speedType == want then return end
	State.speedType = want
	if refreshUIToggles then refreshUIToggles() end
	if MobileButtons and MobileButtons.Buttons and MobileButtons.Buttons.carrySpeed then
		MobileButtons.Buttons.carrySpeed(on)
	end
	autoSaveConfig()
end

-- DÉTECTION RÉELLE du portage : le jeu force WalkSpeed ≈ 8 quand tu portes un brainrot
-- Puisqu'on utilise le proxy et qu'on ne touche plus WalkSpeed,
local CARRY_DEBUG = false  -- désactivé, causait du spam
local _wsConn = nil

local function setupCarryDetection(hum) end  -- remplacé par setupFullDebug

local function setupFullDebug(char, humanoid, hrpPart)
	if not CARRY_DEBUG then return end

	-- 1) HRP children : brainrot soudé via Weld sur HRP
	if hrpPart then
		hrpPart.ChildAdded:Connect(function(c)
			print("[DEBUG HRP.ChildAdded]", c.ClassName, "Name=", c.Name)
		end)
		hrpPart.ChildRemoved:Connect(function(c)
			print("[DEBUG HRP.ChildRemoved]", c.ClassName, "Name=", c.Name)
		end)
	end

	-- 2) Attributs du character
	char.AttributeChanged:Connect(function(attr)
		print("[DEBUG CHAR.Attr]", attr, "=", tostring(char:GetAttribute(attr)))
	end)

	-- 3) Attributs + enfants du Player (objet, pas character)
	LP.AttributeChanged:Connect(function(attr)
		print("[DEBUG LP.Attr]", attr, "=", tostring(LP:GetAttribute(attr)))
	end)
	LP.ChildAdded:Connect(function(c)
		print("[DEBUG LP.ChildAdded]", c.ClassName, "Name=", c.Name)
	end)

	-- 4) WalkSpeed au cas où
	if humanoid then
		humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			print("[DEBUG WalkSpeed] =", humanoid.WalkSpeed)
		end)
		-- Aussi JumpPower / autres props
		humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
			print("[DEBUG JumpPower] =", humanoid.JumpPower)
		end)
	end

	print("[DEBUG] Actif → vole un brainrot et regarde F9")
end

local _toolWatchConns = {}
local function watchCharacterTools(char) end


local function executeSteal(prompt, animalName)
	if AutoSteal.IsStealing then return end
	if not prompt or not prompt.Parent then return end
	initStealData(prompt)
	local data = AutoSteal.Data[prompt]
	if not data or not data.ready then return end
	data.ready = false
	AutoSteal.IsStealing = true
	State.isStealing = true
	local startTime = tick()

	local progConn
	progConn = RunService.Heartbeat:Connect(function()
		if not AutoSteal.IsStealing then progConn:Disconnect(); return end
		local prog = math.clamp((tick() - startTime) / AutoSteal.Duration, 0, 1)
		if AutoSteal.ProgressFill then AutoSteal.ProgressFill.Size = UDim2.new(prog,0,1,0) end
		if AutoSteal.ProgressText then AutoSteal.ProgressText.Text = math.floor(prog*100).."%" end
	end)

	task.spawn(function()
		-- PAS de prompt.MaxActivationDistance = 9999 (détecté par le serveur)
		local success = false
		local attempts = 0
		while not success and attempts < AutoSteal.RetryMax do
			attempts = attempts + 1
			success = tryStealOnce(prompt, data)
			if not success then
				data.fails = (data.fails or 0) + 1
				if data.fails >= 3 then data.useFallback = true end
				task.wait(0.03)
			end
		end
		AutoSteal.IsStealing = false
		State.isStealing = false
		data.ready = true
		-- Note : auto-carry est déclenché par la détection de Tool ajouté au character
		-- (plus fiable que de se baser sur success qui ne dit pas si on a vraiment reçu l'animal)
		task.wait(0.4)
		if not AutoSteal.IsStealing and AutoSteal.ProgressFill then
			TweenService:Create(AutoSteal.ProgressFill, TweenInfo.new(0.3), {Size=UDim2.new(0,0,1,0)}):Play()
		end
		if AutoSteal.ProgressText then AutoSteal.ProgressText.Text = "0%" end
		_promptCache = nil
	end)
end

local autoStealConnection = nil
startAutoSteal = function()
	if autoStealConnection then return end
	local _t = 0
	autoStealConnection = RunService.Heartbeat:Connect(function()
		if not AutoSteal.Enabled or AutoSteal.IsStealing then return end
		local now = tick()
		if now - _t < 0.05 then return end
		_t = now
		local prompts = findNearestPrompts()
		if prompts and #prompts > 0 then
			executeSteal(prompts[1].prompt, prompts[1].name)
		end
	end)
end
stopAutoSteal = function()
	if autoStealConnection then autoStealConnection:Disconnect(); autoStealConnection = nil end
	AutoSteal.IsStealing = false
	State.isStealing = false
	_promptCache = nil
	for k,v in pairs(AutoSteal.Data) do if v.ready ~= nil then v.ready = true end end
end

-- ===================================================================
-- CONSTANTES
-- ===================================================================
local MOVE_KEYS = {[Enum.KeyCode.W]=true,[Enum.KeyCode.A]=true,[Enum.KeyCode.S]=true,[Enum.KeyCode.D]=true,[Enum.KeyCode.Up]=true,[Enum.KeyCode.Left]=true,[Enum.KeyCode.Down]=true,[Enum.KeyCode.Right]=true}
local DROP_ASCEND_DURATION = 0.2
local DROP_ASCEND_SPEED = 150
local POS = {
	L1=Vector3.new(-476.48,-6.28,92.73), L2=Vector3.new(-483.12,-4.95,94.80),
	R1=Vector3.new(-476.16,-6.52,25.62), R2=Vector3.new(-483.04,-5.09,23.14),
}
local Conns = {antiRag=nil, autoLeft=nil, autoRight=nil, anchor={}}

-- ===================================================================
-- PROXY PART (technique anti-rollback de SZG)
-- Au lieu de modifier la vélocité du HRP (rollback serveur),
-- on crée un Part invisible soudé au HRP. On modifie sa vélocité
-- et le weld entraîne le personnage sans déclencher l'anti-cheat.
-- ===================================================================
local proxy = nil
local function ensureProxy()
	local char = LP.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	if proxy and proxy.Parent == char then return proxy end
	if proxy then pcall(function() proxy:Destroy() end) end
	proxy = Instance.new("Part")
	proxy.Name = "YslemProxy"
	proxy.Size = Vector3.new(1,1,1)
	proxy.Transparency = 1
	proxy.CanCollide = false
	proxy.Massless = true
	proxy.Parent = char
	local weld = Instance.new("Weld")
	weld.Part0 = hrp
	weld.Part1 = proxy
	weld.C0 = CFrame.new(0,0,0)
	weld.Parent = proxy
	return proxy
end

local function proxyMove(dir, speed)
	local char = LP.Character; if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local p = ensureProxy()
	-- Humanoid:Move() pour la direction + proxy pour la vitesse
	-- On évite de toucher hrp.AssemblyLinearVelocity directement (détectable)
	if hum then hum:Move(dir, false) end
	if p then
		p.AssemblyLinearVelocity = Vector3.new(dir.X*speed, p.AssemblyLinearVelocity.Y, dir.Z*speed)
	end
end

local function proxyStop()
	local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum:Move(Vector3.zero, false) end
	if proxy then proxy.AssemblyLinearVelocity = Vector3.new(0, proxy.AssemblyLinearVelocity.Y, 0) end
end

-- ===================================================================
-- PALETTE (redesign : violet vibrant + rose)
-- ===================================================================
local C_BG      = Color3.fromRGB(8,8,11)
local C_PANEL   = Color3.fromRGB(15,15,20)
local C_ROW     = Color3.fromRGB(20,20,27)
local C_ROW_HOV = Color3.fromRGB(28,28,38)
local C_BORDER  = Color3.fromRGB(38,34,58)
local C_BORDER2 = Color3.fromRGB(88,70,150)
local C_HEADER  = Color3.fromRGB(12,12,16)
local C_ACCENT  = Color3.fromRGB(228,222,245)
local C_ACCENT2 = Color3.fromRGB(196,160,255)
local C_DIM     = Color3.fromRGB(110,110,125)
local C_WHITE   = Color3.fromRGB(255,255,255)
local C_ON_BG   = Color3.fromRGB(74,46,128)
local C_OFF_BG  = Color3.fromRGB(24,24,32)
local C_YSLEM   = Color3.fromRGB(168,85,247)
local C_PINK    = Color3.fromRGB(236,72,153)

-- ===================================================================
-- AUTO-SAVE CONFIG
-- ===================================================================
local saveDebounce = false
local MobileButtons = {Visible=true, Locked=true, Containers={}, Buttons={}}

autoSaveConfig = function()
	if saveDebounce then return end
	saveDebounce = true
	task.delay(0.5, function()
		local cfg = {
			normalSpeed=State.normalSpeed, carrySpeed=State.carrySpeed,
			laggerSpeed=State.laggerSpeed, laggerCarrySpeed=State.laggerCarrySpeed,
			speedType=State.speedType, laggerActive=State.laggerActive, laggerCarryActive=State.laggerCarryActive,
			autoBatToggled=State.autoBatToggled,
			autoLeftEnabled=State.autoLeftEnabled, autoRightEnabled=State.autoRightEnabled,
			autoStealEnabled=AutoSteal.Enabled, grabRadius=AutoSteal.Radius, grabDuration=AutoSteal.Duration,
			autoCarryOnGrab=State.autoCarryOnGrab,
			infJump=State.infJumpEnabled, infJumpMode=State.infJumpMode,
			antiRagdoll=State.antiRagdollEnabled, fpsBoost=State.fpsBoostEnabled,
			medusaCounter=State.medusaCounterEnabled, unwalkEnabled=State.unwalkEnabled,
			autoTpDown=State.autoTpDownEnabled, autoTpDownY=State.autoTpDownY,
			mobileVisible=MobileButtons.Visible, mobileLocked=MobileButtons.Locked,
			keyAutoLeft=State.keyAutoLeft.Name, keyAutoRight=State.keyAutoRight.Name,
			keyDropBR=State.keyDropBR.Name, keyTpDown=State.keyTpDown.Name, keyAutoBat=State.keyAutoBat.Name,
		}
		pcall(function() writefile("YslemHubConfig.json", HttpService:JSONEncode(cfg)) end)
		saveDebounce = false
	end)
end

-- ===================================================================
-- SPEED HELPERS
-- ===================================================================
local function deactivateAllSpeedModes()
	if State.speedType == "carry" then State.speedType="normal"; if MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(false) end end
	if State.laggerActive then State.laggerActive=false; AutoSteal.Enabled=false; if setInstaGrab then setInstaGrab(false) end; stopAutoSteal(); if MobileButtons.Buttons.lagger then MobileButtons.Buttons.lagger(false) end end
	if State.laggerCarryActive then State.laggerCarryActive=false; AutoSteal.Enabled=false; if setInstaGrab then setInstaGrab(false) end; stopAutoSteal(); if MobileButtons.Buttons.laggerCarry then MobileButtons.Buttons.laggerCarry(false) end end
end

local function toggleSpeedType()
	if State.speedType == "carry" then
		State.speedType = "normal"; refreshUIToggles(); autoSaveConfig()
		if MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(false) end; return
	end
	deactivateAllSpeedModes()
	State.speedType = "carry"; refreshUIToggles(); autoSaveConfig()
	if MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(true) end
end

local function toggleLagger()
	if State.laggerActive then
		State.laggerActive=false; AutoSteal.Enabled=false
		if setInstaGrab then setInstaGrab(false) end; stopAutoSteal()
		refreshUIToggles(); autoSaveConfig()
		if MobileButtons.Buttons.lagger then MobileButtons.Buttons.lagger(false) end; return
	end
	deactivateAllSpeedModes()
	State.laggerActive=true; AutoSteal.Enabled=true
	if setInstaGrab then setInstaGrab(true) end; startAutoSteal()
	refreshUIToggles(); autoSaveConfig()
	if MobileButtons.Buttons.lagger then MobileButtons.Buttons.lagger(true) end
end

local function toggleLaggerCarry()
	if State.laggerCarryActive then
		State.laggerCarryActive=false; AutoSteal.Enabled=false
		if setInstaGrab then setInstaGrab(false) end; stopAutoSteal()
		refreshUIToggles(); autoSaveConfig()
		if MobileButtons.Buttons.laggerCarry then MobileButtons.Buttons.laggerCarry(false) end; return
	end
	deactivateAllSpeedModes()
	State.laggerCarryActive=true; AutoSteal.Enabled=true
	if setInstaGrab then setInstaGrab(true) end; startAutoSteal()
	refreshUIToggles(); autoSaveConfig()
	if MobileButtons.Buttons.laggerCarry then MobileButtons.Buttons.laggerCarry(true) end
end

local function getCurrentSpeed()
	if State.laggerCarryActive then return State.laggerCarrySpeed
	elseif State.laggerActive then return State.laggerCarrySpeed
	else return State.speedType == "normal" and State.normalSpeed or State.carrySpeed end
end

local function getAutoMoveSpeed()
	if State.laggerCarryActive then return State.normalSpeed
	elseif State.laggerActive then return State.laggerSpeed
	else return State.normalSpeed end
end

-- ===================================================================
-- TP DOWN
-- ===================================================================
local function tpToGround()
	local char = LP.Character; if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
	local rot = root.CFrame.Rotation
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	local res = workspace:Raycast(root.Position, Vector3.new(0,-500,0), params)
	if res then root.CFrame = CFrame.new(res.Position + Vector3.new(0,3,0)) * rot
	else root.CFrame = CFrame.new(root.Position + Vector3.new(0,-20,0)) * rot end
end

-- ===================================================================
-- DROP BRAINROT
-- ===================================================================
local function runDropBrainrot()
	if State.dropBrainrotActive then return end
	local char = LP.Character; if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
	State.dropBrainrotActive = true
	local t0 = tick()
	local dc
	dc = RunService.Heartbeat:Connect(function()
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if not r then dc:Disconnect(); State.dropBrainrotActive=false; return end
		if tick()-t0 >= DROP_ASCEND_DURATION then
			dc:Disconnect()
			local rp = RaycastParams.new(); rp.FilterDescendantsInstances={char}; rp.FilterType=Enum.RaycastFilterType.Exclude
			local rr = workspace:Raycast(r.Position, Vector3.new(0,-2000,0), rp)
			if rr then
				local hum2 = char:FindFirstChildOfClass("Humanoid")
				local off = (hum2 and hum2.HipHeight or 2) + (r.Size.Y/2)
				r.CFrame = CFrame.new(r.Position.X, rr.Position.Y+off, r.Position.Z)
				r.AssemblyLinearVelocity = Vector3.new(0,0,0)
			end
			State.dropBrainrotActive=false; return
		end
		r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, DROP_ASCEND_SPEED, r.AssemblyLinearVelocity.Z)
	end)
end

-- AUTO LEFT / RIGHT
local leftWaypoints = {
	Vector3.new(-476.85, -6.59, 94.91),
	Vector3.new(-485.55, -4.53, 100.61),
	Vector3.new(-475.60, -6.59, 92.80),
	Vector3.new(-475.26, -6.57, 21.54),
}
local rightWaypoints = {
	Vector3.new(-475.77, -6.57, 26.76),
	Vector3.new(-485.85, -4.48, 20.13),
	Vector3.new(-475.83, -6.59, 26.54),
	Vector3.new(-476.17, -6.09, 97.73),
}

local patrolConnection = nil
local patrolWaypoints = nil
local patrolIndex = 1

local function patrolMoveTo(target, speed)
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local dir = (target - hrp.Position)
	local moveDir = Vector3.new(dir.X, 0, dir.Z).Unit
	local hum = LP.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum:Move(moveDir, false) end
	proxyMove(moveDir, speed)
end

startAutoLeft = function()
	stopAutoLeft(); stopAutoRight()
	State.autoLeftPhase = 1; patrolIndex = 1
	patrolWaypoints = leftWaypoints; ensureProxy()
	State.speedType = "normal"
	if refreshUIToggles then refreshUIToggles() end
	if MobileButtons.Buttons and MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(false) end
	patrolConnection = RunService.Stepped:Connect(function()
		if not State.autoLeftEnabled or not patrolWaypoints then return end
		local char = LP.Character; if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
		local target = patrolWaypoints[patrolIndex]; if not target then return end
		local dist = (target - hrp.Position).Magnitude
		local speed = (patrolIndex <= 2) and State.normalSpeed or State.carrySpeed
		if dist < 2.5 then
			patrolIndex = patrolIndex + 1
			if patrolIndex > #patrolWaypoints then
				proxyStop(); State.autoLeftEnabled = false
				if patrolConnection then patrolConnection:Disconnect(); patrolConnection = nil end
				patrolWaypoints = nil; patrolIndex = 1
				if setAutoLeft then setAutoLeft(false) end
				if MobileButtons.Buttons.autoLeft then MobileButtons.Buttons.autoLeft(false) end
				if State.autoCarryOnGrab then
					State.speedType = "carry"
					if refreshUIToggles then refreshUIToggles() end
					if MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(true) end
					autoSaveConfig()
				end
				return
			end
		else
			patrolMoveTo(target, speed)
		end
	end)
end
stopAutoLeft = function()
	if patrolConnection and State.autoLeftEnabled then patrolConnection:Disconnect(); patrolConnection = nil end
	patrolWaypoints = nil; patrolIndex = 1; proxyStop()
	State.autoLeftPhase = 1
	if MobileButtons.Buttons.autoLeft then MobileButtons.Buttons.autoLeft(false) end
end

startAutoRight = function()
	stopAutoRight(); stopAutoLeft()
	State.autoRightPhase = 1; patrolIndex = 1
	patrolWaypoints = rightWaypoints; ensureProxy()
	State.speedType = "normal"
	if refreshUIToggles then refreshUIToggles() end
	if MobileButtons.Buttons and MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(false) end
	patrolConnection = RunService.Stepped:Connect(function()
		if not State.autoRightEnabled or not patrolWaypoints then return end
		local char = LP.Character; if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
		local target = patrolWaypoints[patrolIndex]; if not target then return end
		local dist = (target - hrp.Position).Magnitude
		local speed = (patrolIndex <= 2) and State.normalSpeed or State.carrySpeed
		if dist < 2.5 then
			patrolIndex = patrolIndex + 1
			if patrolIndex > #patrolWaypoints then
				proxyStop(); State.autoRightEnabled = false
				if patrolConnection then patrolConnection:Disconnect(); patrolConnection = nil end
				patrolWaypoints = nil; patrolIndex = 1
				if setAutoRight then setAutoRight(false) end
				if MobileButtons.Buttons.autoRight then MobileButtons.Buttons.autoRight(false) end
				if State.autoCarryOnGrab then
					State.speedType = "carry"
					if refreshUIToggles then refreshUIToggles() end
					if MobileButtons.Buttons.carrySpeed then MobileButtons.Buttons.carrySpeed(true) end
					autoSaveConfig()
				end
				return
			end
		else
			patrolMoveTo(target, speed)
		end
	end)
end
stopAutoRight = function()
	if patrolConnection and State.autoRightEnabled then patrolConnection:Disconnect(); patrolConnection = nil end
	patrolWaypoints = nil; patrolIndex = 1; proxyStop()
	State.autoRightPhase = 1
	if MobileButtons.Buttons.autoRight then MobileButtons.Buttons.autoRight(false) end
end

-- ANTI RAGDOLL
startAntiRagdoll = function()
	if Conns.antiRag then return end
	local _t = 0
	Conns.antiRag = RunService.Heartbeat:Connect(function()
		local now = tick(); if now-_t < 0.1 then return end; _t = now
		local char = LP.Character; if not char then return end
		local hum2 = char:FindFirstChildOfClass("Humanoid"); local root = char:FindFirstChild("HumanoidRootPart")
		if hum2 then
			local st = hum2:GetState()
			if st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then
				hum2:ChangeState(Enum.HumanoidStateType.Running)
				workspace.CurrentCamera.CameraSubject = hum2
				pcall(function() local pm=LP.PlayerScripts:FindFirstChild("PlayerModule"); if pm then require(pm:FindFirstChild("ControlModule")):Enable() end end)
				if root then root.Velocity=Vector3.zero; root.RotVelocity=Vector3.zero end
			end
		end
		for _,obj in ipairs(char:GetDescendants()) do if obj:IsA("Motor6D") and not obj.Enabled then obj.Enabled=true end end
	end)
end
stopAntiRagdoll = function() if Conns.antiRag then Conns.antiRag:Disconnect(); Conns.antiRag=nil end end

-- FPS BOOST
applyFPSBoost = function()
	pcall(function() setfpscap(999999999) end)
	local function processObj(v)
		pcall(function()
			if v:IsA("Model") then v.LevelOfDetail=Enum.ModelLevelOfDetail.Disabled
			elseif v:IsA("MeshPart") then v.CastShadow=false; v.RenderFidelity=Enum.RenderFidelity.Performance
			elseif v:IsA("BasePart") then v.CastShadow=false; v.Material=Enum.Material.Plastic; v.Reflectance=0
			elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency=1
			elseif v:IsA("SpecialMesh") then v.TextureId=""
			elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then v.Enabled=false
			elseif v:IsA("SurfaceAppearance") then v:Destroy() end
		end)
	end
	for _,v in pairs(workspace:GetDescendants()) do processObj(v) end
	pcall(function()
		local lighting = game:GetService("Lighting")
		for _,v in pairs(lighting:GetDescendants()) do
			pcall(function()
				if v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("ColorCorrectionEffect") then v:Destroy() end
			end)
		end
		lighting.GlobalShadows = false; lighting.FogEnd = 9e9; lighting.Brightness = 0
	end)
	workspace.DescendantAdded:Connect(function(v) if State.fpsBoostEnabled then task.spawn(processObj,v) end end)
end

print("[Yslem Hub v2] Script loaded successfully!")
