--[[
	MoonHub_v17_logic_base.lua
	===========================================================================
	Logic-only extraction from MoonHub_v16_fixed.lua.

	Scope: every feature's LOGIC (services, state, helper functions, feature
	start/stop functions, gameplay-driving event connections) with ALL UI
	construction removed. UI-callback hook points are exposed as plain
	function-variable "slots" (onXxxChanged etc.) that a future UI layer can
	assign to update labels/buttons — assigning them is optional, everything
	here works headless.

	HARD EXCLUSION: the Auto Steal / Auto Grab subsystem (in the source this
	was named AutoSteal / the "_KAG_" prompt-hold-and-trigger automation,
	including its Synchronizer channel diffing used to track steal targets)
	has been intentionally removed in full. See the final report for the
	exact source line ranges that were excluded.
]]

-- ===================================================================
-- DEDUP / RE-EXECUTION GUARD
-- ===================================================================
local _MHLB_KEY = "__MoonHub_v17_LogicBase__"
if _G[_MHLB_KEY] then return end
_G[_MHLB_KEY] = true

if not game:IsLoaded() then game.Loaded:Wait() end

-- ===================================================================
-- SERVICES
-- ===================================================================
local Players      = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UIS            = game:GetService("UserInputService")
local Lighting       = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

-- ===================================================================
-- UI CALLBACK SLOTS (future UI assigns these; all default to no-ops)
-- ===================================================================
local UICallbacks = {
	onStatusChanged        = nil, -- function(text)
	onSpeedBypassToggle     = nil, -- function(active:boolean)
	onAntiBatToggle         = nil, -- function(active:boolean)
	onFloatButtonsRefresh   = nil, -- function()
	onThemeChanged          = nil, -- function(themeName)
	onAutoSave              = nil, -- function()  (hook so future persistence layer can save on change)
}
local function _safeCall(fn, ...)
	if fn then local ok = pcall(fn, ...); return ok end
end

-- ===================================================================
-- STATE
-- ===================================================================
local State = {
	normalSpeed = 60, carrySpeed = 30, laggerSpeed = 15, laggerCarrySpeed = 24.5,
	speedType = "normal",
	laggerActive = false, laggerCarryActive = false,
	autoLeftEnabled = false, autoRightEnabled = false,
	autoPlayMode = "Full",
	nukeOptEnabled = false, removeAccEnabled = false, antiLagAdvEnabled = false,
	guiVisible = true,
	antiRagdollEnabled = true, unwalkEnabled = false, autoCarryOnGrab = true,
	dropBrainrotActive = false, isStealing = false,
	_carryManualUntil = 0, _lastCarryDetected = false,
	medusaCounterEnabled = false,
	autoResetOnMedEnabled = false,
}

-- ===================================================================
-- PROXY MOVE (WalkSpeed / velocity-based movement helper)
-- ===================================================================
local proxy = nil
local function ensureProxy()
	local char = LP.Character; if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
	if proxy and proxy.Parent == char then return proxy end
	if proxy then pcall(function() proxy:Destroy() end) end
	proxy = Instance.new("Part")
	proxy.Name = "_MHLB_Proxy" .. tostring(math.random(10,99))
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

-- ===================================================================
-- SPEED LOGIC (normal / carry / lagger / lagger-carry)
-- ===================================================================
-- updateCarryState mutates State; getCurrentSpeed only reads (kept pure,
-- exactly matching source's FIX #1 & #6 comment / behavior).
local function updateCarryState()
	local char = LP.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	local isSteal = hum and hum.WalkSpeed < 25
	if State.autoCarryOnGrab and isSteal and State.speedType ~= "carry" then
		State.speedType = "carry"
	elseif State.autoCarryOnGrab and not isSteal and State.speedType == "carry"
		and tick() >= (State._carryManualUntil or 0) then
		State.speedType = "normal"
	end
end

local function getCurrentSpeed()
	local char    = LP.Character
	local hum     = char and char:FindFirstChildOfClass("Humanoid")
	local isSteal = hum and hum.WalkSpeed < 25
	if State.laggerCarryActive or (State.laggerActive and isSteal) then
		return isSteal and State.laggerCarrySpeed or State.laggerSpeed
	elseif State.laggerActive then
		return State.laggerSpeed
	else
		return isSteal and State.carrySpeed or State.normalSpeed
	end
end

local h, hrp
local function setupChar(char)
	h = char:WaitForChild("Humanoid", 5)
	hrp = char:WaitForChild("HumanoidRootPart", 5)
	if h then h.WalkSpeed = getCurrentSpeed() end
	ensureProxy()
end
LP.CharacterAdded:Connect(setupChar)
if LP.Character then setupChar(LP.Character) end

-- Speed Booster: proxy-move driven movement loop. UI toggles _speedBoosterActive.
local _speedBoosterActive = false
local function setSpeedBoosterActive(on) _speedBoosterActive = on end
local function isSpeedBoosterActive() return _speedBoosterActive end
RunService.Stepped:Connect(function()
	if not _speedBoosterActive then return end
	if not (h and hrp) then return end
	updateCarryState()  -- mutation d'état séparée, avant la lecture
	local md = h.MoveDirection
	if md.Magnitude > 0 then proxyMove(md, getCurrentSpeed()) end
end)

-- ===================================================================
-- AUTO CARRY ON GRAB (carry speed switching — NOT the steal automation)
-- ===================================================================
local lastCarryDetected = false
RunService.Heartbeat:Connect(function()
	if not State.autoCarryOnGrab then return end
	if State.laggerActive or State.laggerCarryActive then return end
	if tick() < (State._carryManualUntil or 0) then return end
	local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local carrying = (hum.WalkSpeed <= 25)
	if carrying==lastCarryDetected then return end
	lastCarryDetected=carrying; State.speedType=carrying and "carry" or "normal"
end)

-- ===================================================================
-- TP DOWN
-- ===================================================================
local function tpToGround()
	local char = LP.Character; if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
	local hum2 = char:FindFirstChildOfClass("Humanoid"); if not hum2 then return end
	-- Amir Hub logic: direct TP to fixed ground Y (-7.00), keeping Y rotation
	root.CFrame = CFrame.new(root.Position.X, -7.00, root.Position.Z)
		* CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
	root.AssemblyLinearVelocity = Vector3.zero
end

-- ===================================================================
-- DROP BRAINROT
-- ===================================================================
local _dropActive = false
local DROP_ASCEND_DURATION = 0.2
local DROP_ASCEND_SPEED    = 150

local function runDropBrainrot()
	if _dropActive then return end
	local char = LP.Character; if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
	_dropActive = true
	local t0 = tick()
	local dc
	dc = RunService.Heartbeat:Connect(function()
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if not r then dc:Disconnect(); _dropActive = false; return end
		if tick() - t0 >= DROP_ASCEND_DURATION then
			dc:Disconnect()
			-- Raycast to the ground
			local rp = RaycastParams.new()
			rp.FilterDescendantsInstances = {char}
			rp.FilterType = Enum.RaycastFilterType.Exclude
			local rr = workspace:Raycast(r.Position, Vector3.new(0, -2000, 0), rp)
			if rr then
				local hum2 = char:FindFirstChildOfClass("Humanoid")
				local off  = (hum2 and hum2.HipHeight or 2) + (r.Size.Y / 2)
				r.CFrame = CFrame.new(r.Position.X, rr.Position.Y + off, r.Position.Z)
				r.AssemblyLinearVelocity = Vector3.zero
			end
			_dropActive = false
			return
		end
		-- Fast ascent phase
		r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, DROP_ASCEND_SPEED, r.AssemblyLinearVelocity.Z)
	end)
end

-- ===================================================================
-- AUTO LEFT / RIGHT  (Taser Hub logic — 2 phases + final orientation)
-- ===================================================================
local AP_L1     = Vector3.new(-476.48, -6.28, 92.73)
local AP_L2     = Vector3.new(-483.12, -4.95, 94.80)
local AP_L_FACE = Vector3.new(-482.25, -4.96, 92.09)
local AP_R1     = Vector3.new(-476.16, -6.52, 25.62)
local AP_R2     = Vector3.new(-483.06, -5.03, 25.48)
local AP_R_FACE = Vector3.new(-482.06, -6.93, 35.47)

local alConn, arConn = nil, nil
local alPhase, arPhase = 1, 1

local function stopAutoLeft()
	if alConn then alConn:Disconnect(); alConn = nil end
	alPhase = 1; proxyStop(); State.autoLeftEnabled = false
end

local function stopAutoRight()
	if arConn then arConn:Disconnect(); arConn = nil end
	arPhase = 1; proxyStop(); State.autoRightEnabled = false
end

local function startAutoLeft()
	if State.autoRightEnabled then stopAutoRight() end
	if alConn then alConn:Disconnect() end
	alPhase = 1; State.autoLeftEnabled = true
	alConn = RunService.Heartbeat:Connect(function()
		if not State.autoLeftEnabled then return end
		local char = LP.Character; if not char then return end
		local hrp2 = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp2 or not hum then return end
		local spd = State.normalSpeed
		if alPhase == 1 then
			if (Vector3.new(AP_L1.X, hrp2.Position.Y, AP_L1.Z) - hrp2.Position).Magnitude < 1 then
				alPhase = 2
			end
			local d = AP_L1 - hrp2.Position
			proxyMove(Vector3.new(d.X, 0, d.Z).Unit, spd)
		elseif alPhase == 2 then
			if (Vector3.new(AP_L2.X, hrp2.Position.Y, AP_L2.Z) - hrp2.Position).Magnitude < 1 then
				proxyStop(); State.autoLeftEnabled = false
				if alConn then alConn:Disconnect(); alConn = nil end
				alPhase = 1
				hrp2.CFrame = CFrame.new(hrp2.Position, Vector3.new(AP_L_FACE.X, hrp2.Position.Y, AP_L_FACE.Z))
				return
			end
			local d = AP_L2 - hrp2.Position
			proxyMove(Vector3.new(d.X, 0, d.Z).Unit, spd)
		end
	end)
end

local function startAutoRight()
	if State.autoLeftEnabled then stopAutoLeft() end
	if arConn then arConn:Disconnect() end
	arPhase = 1; State.autoRightEnabled = true
	arConn = RunService.Heartbeat:Connect(function()
		if not State.autoRightEnabled then return end
		local char = LP.Character; if not char then return end
		local hrp2 = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp2 or not hum then return end
		local spd = State.normalSpeed
		if arPhase == 1 then
			if (Vector3.new(AP_R1.X, hrp2.Position.Y, AP_R1.Z) - hrp2.Position).Magnitude < 1 then
				arPhase = 2
			end
			local d = AP_R1 - hrp2.Position
			proxyMove(Vector3.new(d.X, 0, d.Z).Unit, spd)
		elseif arPhase == 2 then
			if (Vector3.new(AP_R2.X, hrp2.Position.Y, AP_R2.Z) - hrp2.Position).Magnitude < 1 then
				proxyStop(); State.autoRightEnabled = false
				if arConn then arConn:Disconnect(); arConn = nil end
				arPhase = 1
				hrp2.CFrame = CFrame.new(hrp2.Position, Vector3.new(AP_R_FACE.X, hrp2.Position.Y, AP_R_FACE.Z))
				return
			end
			local d = AP_R2 - hrp2.Position
			proxyMove(Vector3.new(d.X, 0, d.Z).Unit, spd)
		end
	end)
end

-- ===================================================================
-- ANTI RAGDOLL
-- ===================================================================
local antiRagdollConn = nil

local function _arResetCharacter(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return end
	pcall(function()
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		hum:ChangeState(Enum.HumanoidStateType.Running)
		root.Velocity = Vector3.zero
		root.RotVelocity = Vector3.zero
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		hum.PlatformStand = false
		hum.Sit = false
		hum.AutoRotate = true
		hum.JumpPower = hum.JumpPower > 0 and hum.JumpPower or 50
		hum.WalkSpeed = hum.WalkSpeed > 0 and hum.WalkSpeed or 16
		for _, obj in ipairs(char:GetDescendants()) do
			if obj:IsA("Motor6D") then
				obj.Enabled = true
			elseif obj:IsA("Constraint") or obj:IsA("BallSocketConstraint") or obj:IsA("HingeConstraint") then
				obj.Enabled = true
			elseif obj:IsA("BasePart") then
				obj.CanCollide = true
				obj.AssemblyLinearVelocity = Vector3.zero
				obj.AssemblyAngularVelocity = Vector3.zero
			end
		end
		workspace.CurrentCamera.CameraSubject = hum
		local PM = LP.PlayerScripts:FindFirstChild("PlayerModule")
		if PM then
			local CM = PM:FindFirstChild("ControlModule")
			if CM then
				local ok, module = pcall(require, CM)
				if ok and module and module.Enable then module:Enable() end
			end
		end
	end)
end

local function startAntiRagdoll()
	if antiRagdollConn then return end
	antiRagdollConn = RunService.Heartbeat:Connect(function()
		if not State.antiRagdollEnabled then return end
		local char = LP.Character; if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
		local st = hum:GetState()
		if st == Enum.HumanoidStateType.Physics or
		   st == Enum.HumanoidStateType.Ragdoll or
		   st == Enum.HumanoidStateType.FallingDown or
		   st == Enum.HumanoidStateType.Dead or
		   hum.PlatformStand == true or
		   hum.Sit == true then
			_arResetCharacter(char)
		end
	end)
end

local function stopAntiRagdoll()
	if antiRagdollConn then antiRagdollConn:Disconnect(); antiRagdollConn = nil end
end

LP.CharacterAdded:Connect(function()
	task.wait(0.5)
	if State.antiRagdollEnabled then startAntiRagdoll() end
end)

-- ===================================================================
-- UNWALK
-- ===================================================================
local savedAnimate = nil
local function startUnwalk()
	if State.unwalkEnabled then return end; State.unwalkEnabled = true
	local c=LP.Character; if not c then return end
	local hum=c:FindFirstChildOfClass("Humanoid")
	if hum then for _,t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end end
	local anim=c:FindFirstChild("Animate"); if anim then savedAnimate=anim:Clone(); anim:Destroy() end
end
local function stopUnwalk()
	if not State.unwalkEnabled then return end; State.unwalkEnabled=false
	local c=LP.Character
	if c and savedAnimate then savedAnimate.Parent=c; savedAnimate.Disabled=false; savedAnimate=nil end
end
-- Restart Unwalk after every respawn if active
LP.CharacterAdded:Connect(function(char)
	if State.unwalkEnabled then
		State.unwalkEnabled = false  -- reset so startUnwalk accepts
		savedAnimate = nil
		task.wait(0.5)               -- let the character load
		startUnwalk()
	end
end)

-- ===================================================================
-- OPTIMIZE MODULE (Nuke Optimizer / Remove Accessories / Anti-Lag / Ultra)
-- ===================================================================
local NukeOpt = {active=false, conns={}, threads={}}
local function nukeOptStart()
	if NukeOpt.active then return end; NukeOpt.active=true
	-- O(1) lookup by ClassName instead of O(12) list scan. These types have
	-- no Roblox subclasses, so ClassName is equivalent to IsA here.
	local ClothingSet = {
		Shirt=true, Pants=true, ShirtGraphic=true, Accessory=true, Hat=true,
		HairAccessory=true, FaceAccessory=true, NeckAccessory=true,
		ShoulderAccessory=true, FrontAccessory=true, BackAccessory=true, WaistAccessory=true,
	}
	local function IsClothing(obj) return ClothingSet[obj.ClassName] == true end
	local function IsCharacterPart(obj) for _,p in ipairs(Players:GetPlayers()) do if p.Character and obj:IsDescendantOf(p.Character) then return true end end end
	local function SafeDestroy(obj) if obj.Name~="Overhead" then pcall(function() obj:Destroy() end) end end
	local function CleanObject(obj)
		pcall(function()
			if obj:IsA("SurfaceAppearance") or obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
				or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")
				or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Explosion") then
				SafeDestroy(obj)
			elseif obj:IsA("Decal") or obj:IsA("Texture") then
				if not (obj.Name=="face" and obj.Parent and obj.Parent.Name=="Head") then SafeDestroy(obj) end
			elseif obj:IsA("BasePart") then obj.CastShadow=false; obj.Material=Enum.Material.Plastic; obj.Reflectance=0 end
		end)
	end
	Lighting.GlobalShadows=false; Lighting.FogEnd=9e9; Lighting.EnvironmentDiffuseScale=0; Lighting.EnvironmentSpecularScale=0
	for _,v in ipairs(Lighting:GetChildren()) do
		if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then v:Destroy() end
	end
	table.insert(NukeOpt.threads, task.spawn(function()
		for _,obj in ipairs(workspace:GetDescendants()) do
			if not NukeOpt.active then return end
			if not IsCharacterPart(obj) then if IsClothing(obj) then SafeDestroy(obj) else CleanObject(obj) end end
		end
	end))
	table.insert(NukeOpt.conns, workspace.DescendantAdded:Connect(function(obj)
		if not NukeOpt.active then return end
		task.defer(function()
			if not NukeOpt.active then return end
			if not IsCharacterPart(obj) then if IsClothing(obj) then SafeDestroy(obj) else CleanObject(obj) end end
		end)
	end))
end
local function nukeOptStop()
	NukeOpt.active=false
	for _,c in ipairs(NukeOpt.conns) do pcall(function() c:Disconnect() end) end; NukeOpt.conns={}
end

local RemoveAcc = {active=false, conn=nil, removed=setmetatable({},{__mode="k"})}
local function removeAccDo()
	if not RemoveAcc.active then return end; local char=LP.Character; if not char then return end
	for _,obj in ipairs(char:GetDescendants()) do
		if (obj:IsA("Accessory") or obj:IsA("Hat")) and not RemoveAcc.removed[obj] then
			RemoveAcc.removed[obj]=true; pcall(function() obj:Destroy() end)
		end
	end
end
local function removeAccStart()
	if RemoveAcc.active then return end; RemoveAcc.active=true; removeAccDo()
	RemoveAcc.conn=LP.CharacterAdded:Connect(function() task.wait(0.5); if RemoveAcc.active then removeAccDo() end end)
end
local function removeAccStop()
	RemoveAcc.active=false; if RemoveAcc.conn then RemoveAcc.conn:Disconnect(); RemoveAcc.conn=nil end
end

local function cleanParticlesAndLights()
	local removed=0
	for _,obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire")
			or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Explosion")
			or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
			pcall(function() obj:Destroy() end); removed=removed+1
		end
	end; return removed
end

local AntiLagAdv = {active=false, conn=nil}
local function _applyAntiLagAdvObj(obj)
	pcall(function()
		if obj:IsA("BasePart") then obj.Material=Enum.Material.Plastic; obj.Reflectance=0; obj.CastShadow=false
		elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency=1
		elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then obj.Enabled=false end
	end)
end
local function antiLagAdvStart()
	if AntiLagAdv.active then return end; AntiLagAdv.active=true; Lighting.GlobalShadows=false
	for _,obj in ipairs(workspace:GetDescendants()) do _applyAntiLagAdvObj(obj) end
	AntiLagAdv.conn=workspace.DescendantAdded:Connect(function(obj) if AntiLagAdv.active then _applyAntiLagAdvObj(obj) end end)
end
local function antiLagAdvStop()
	AntiLagAdv.active=false; if AntiLagAdv.conn then AntiLagAdv.conn:Disconnect(); AntiLagAdv.conn=nil end
end

-- "Ultra Mode" one-shot optimization pass (raw__59_ logic)
local function runUltraMode()
	Lighting.GlobalShadows=false; Lighting.FogEnd=1e10; Lighting.Brightness=1
	Lighting.EnvironmentDiffuseScale=0; Lighting.EnvironmentSpecularScale=0
	for _,e in pairs(Lighting:GetChildren()) do pcall(function()
		if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect")
			or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then e.Enabled=false end
	end) end
	task.spawn(function()
		for _,obj in pairs(workspace:GetDescendants()) do pcall(function()
			if obj:IsA("BasePart") then obj.Material=Enum.Material.Plastic; obj.Reflectance=0; obj.CastShadow=false
			elseif obj:IsA("Decal") or obj:IsA("Texture") then obj:Destroy()
			elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") then obj.Enabled=false end
		end) end
	end)
	pcall(function() if setfpscap then setfpscap(999999999) end end)
end

-- "No Cam Collision" — hides parts between camera and character via raycasts
local NoCamCollision = {active=false, conn=nil, parts={}}
local function noCamCollisionStart()
	if NoCamCollision.active then return end
	NoCamCollision.active = true
	if NoCamCollision.conn then NoCamCollision.conn:Disconnect() end
	NoCamCollision.conn = RunService.RenderStepped:Connect(function()
		local char=LP.Character; if not char then return end
		local cam=workspace.CurrentCamera; if not cam then return end
		local hrp2=char:FindFirstChild("HumanoidRootPart"); if not hrp2 then return end
		local camPos=cam.CFrame.Position
		local charPos=hrp2.Position+Vector3.new(0,1.5,0)
		local toChar=charPos-camPos; if toChar.Magnitude<0.3 then return end
		local params=RaycastParams.new()
		params.FilterType=Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances={char}
		local hit={}; local origin=camPos; local remaining=toChar
		for _=1,8 do
			if remaining.Magnitude<0.2 then break end
			local res=workspace:Raycast(origin,remaining,params); if not res then break end
			local p2=res.Instance
			if p2 and p2:IsA("BasePart") and not p2:IsDescendantOf(char) then
				hit[p2]=true
				if NoCamCollision.parts[p2]==nil then NoCamCollision.parts[p2]=p2.LocalTransparencyModifier end
				p2.LocalTransparencyModifier=1
			end
			origin=res.Position+remaining.Unit*0.02; remaining=charPos-origin
		end
		for p2,orig in pairs(NoCamCollision.parts) do
			if not hit[p2] then
				pcall(function() if p2 and p2.Parent then p2.LocalTransparencyModifier=orig end end)
				NoCamCollision.parts[p2]=nil
			end
		end
	end)
end
local function noCamCollisionStop()
	NoCamCollision.active = false
	if NoCamCollision.conn then NoCamCollision.conn:Disconnect(); NoCamCollision.conn=nil end
	for p2,orig in pairs(NoCamCollision.parts) do
		pcall(function() if p2 and p2.Parent then p2.LocalTransparencyModifier=orig end end)
	end
	NoCamCollision.parts={}
end

-- REVUL ANTI LAGGER — engine (snapshot + restore, DescendantAdded hook)
local RevulAL = {active=false, conn=nil}
local _ralOrigLighting = {
	GlobalShadows            = Lighting.GlobalShadows,
	FogEnd                   = Lighting.FogEnd,
	Brightness               = Lighting.Brightness,
	EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
	EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
}
local _ralOrigPostFX = {}
local _ralOrigParts  = {}

local function _ralSnapshot()
	_ralOrigPostFX = {}
	for _, fx in ipairs(Lighting:GetChildren()) do
		if fx:IsA("PostEffect") then _ralOrigPostFX[fx] = fx.Enabled end
	end
	_ralOrigParts = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			_ralOrigParts[obj] = {Enabled=obj.Enabled}
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			_ralOrigParts[obj] = {Transparency=obj.Transparency}
		elseif obj:IsA("BasePart") then
			_ralOrigParts[obj] = {Material=obj.Material, Reflectance=obj.Reflectance, CastShadow=obj.CastShadow}
		end
	end
end

local function _ralApplyObj(obj)
	if not _ralOrigParts[obj] then
		-- snapshot for newly streamed objects
		if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			_ralOrigParts[obj] = {Enabled=obj.Enabled}
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			_ralOrigParts[obj] = {Transparency=obj.Transparency}
		elseif obj:IsA("BasePart") then
			_ralOrigParts[obj] = {Material=obj.Material, Reflectance=obj.Reflectance, CastShadow=obj.CastShadow}
		end
	end
	pcall(function()
		if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			obj.Enabled = false
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			obj.Transparency = 1
		elseif obj:IsA("BasePart") then
			obj.Material=Enum.Material.Plastic; obj.Reflectance=0; obj.CastShadow=false
		end
	end)
end

local function ralStart()
	if RevulAL.active then return end
	RevulAL.active = true
	_ralSnapshot()
	Lighting.GlobalShadows=false; Lighting.FogEnd=8999999488; Lighting.Brightness=1
	Lighting.EnvironmentDiffuseScale=0; Lighting.EnvironmentSpecularScale=0
	for _, fx in ipairs(Lighting:GetChildren()) do if fx:IsA("PostEffect") then fx.Enabled=false end end
	for _, obj in ipairs(workspace:GetDescendants()) do _ralApplyObj(obj) end
	RevulAL.conn = workspace.DescendantAdded:Connect(function(obj)
		if RevulAL.active then _ralApplyObj(obj) end
	end)
end

local function ralStop()
	if not RevulAL.active then return end
	RevulAL.active = false
	if RevulAL.conn then RevulAL.conn:Disconnect(); RevulAL.conn=nil end
	-- Restore Lighting
	Lighting.GlobalShadows            = _ralOrigLighting.GlobalShadows
	Lighting.FogEnd                   = _ralOrigLighting.FogEnd
	Lighting.Brightness               = _ralOrigLighting.Brightness
	Lighting.EnvironmentDiffuseScale  = _ralOrigLighting.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = _ralOrigLighting.EnvironmentSpecularScale
	for fx, wasEnabled in pairs(_ralOrigPostFX) do
		if fx and fx.Parent then fx.Enabled=wasEnabled end
	end
	-- Restore workspace
	for obj, saved in pairs(_ralOrigParts) do
		if obj and obj.Parent then
			pcall(function()
				if saved.Enabled~=nil        then obj.Enabled=saved.Enabled end
				if saved.Transparency~=nil   then obj.Transparency=saved.Transparency end
				if saved.Material~=nil       then obj.Material=saved.Material; obj.Reflectance=saved.Reflectance; obj.CastShadow=saved.CastShadow end
			end)
		end
	end
end

-- ===================================================================
-- MEDUSA COUNTER (raw__59_ logic)
-- ===================================================================
local _medLastUsed = 0
local _medDebounce = false
local _medConns = {}

local function findMedusa()
	local char=LP.Character; if not char then return nil end
	for _,tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then local tn=tool.Name:lower()
			if tn:find("medusa") or tn:find("head") or tn:find("stone") then return tool end
		end
	end
	local bp2=LP:FindFirstChild("Backpack"); if bp2 then
		for _,tool in ipairs(bp2:GetChildren()) do
			if tool:IsA("Tool") then local tn=tool.Name:lower()
				if tn:find("medusa") or tn:find("head") or tn:find("stone") then return tool end
			end
		end
	end
	return nil
end

local function useMedusaCounter()
	if _medDebounce then return end
	if tick()-_medLastUsed < 0.5 then return end
	local char=LP.Character; if not char then return end
	_medDebounce=true
	local med=findMedusa(); if not med then _medDebounce=false; return end
	if med.Parent~=char then
		local hum2=char:FindFirstChildOfClass("Humanoid"); if hum2 then pcall(function() hum2:EquipTool(med) end) end
	end
	pcall(function() med:Activate() end)
	_medLastUsed=tick(); _medDebounce=false
end

local function setupMedusaCounter(char)
	for _,c in pairs(_medConns) do pcall(function() c:Disconnect() end) end; _medConns={}
	if not char then return end
	local function watchPart(part)
		table.insert(_medConns, part:GetPropertyChangedSignal("Anchored"):Connect(function()
			if part.Anchored and part.Transparency==1 then useMedusaCounter() end
		end))
	end
	for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then watchPart(part) end end
	table.insert(_medConns, char.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then watchPart(part) end
	end))
end
local function stopMedusaCounter()
	for _,c in pairs(_medConns) do pcall(function() c:Disconnect() end) end; _medConns={}
end

LP.CharacterAdded:Connect(function(char) if State.medusaCounterEnabled then task.wait(0.5); setupMedusaCounter(char) end end)

-- ===================================================================
-- INSTANT RESET — manual (Limited Hub logic: tool save, char=nil,
-- heartbeat @60fps remote fire, tool restore on respawn, 4s timeout)
-- ===================================================================
local IR_GUID = game:GetService("HttpService"):GenerateGUID(false)
local IR_resetRemote = nil

local function IR_findRemote()
	if IR_resetRemote and IR_resetRemote.Parent then return IR_resetRemote end
	local _RS = ReplicatedStorage
	-- scan Tools/Cooldown sibling pattern (Limited Hub fallback)
	local pkg = _RS:FindFirstChild("Packages", 2)
	local net = pkg and pkg:FindFirstChild("Net", 2)
	if net then
		local ch = net:GetChildren()
		for i = 1, #ch - 1 do
			if ch[i] and ch[i+1] and string.find(ch[i].Name, "Tools/Cooldown") then
				IR_resetRemote = ch[i+1]; return IR_resetRemote
			end
		end
	end
	return nil
end

local function instaReset()
	local remote = IR_findRemote()
	-- fallback: kill via humanoid if no remote found
	if not remote then
		local char = LP.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.Health = 0 end
		return
	end

	-- 1. Save all tools
	local savedTools = {}
	local char = LP.Character
	local bp   = LP:FindFirstChild("Backpack")
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum:UnequipTools() end) end
		for _, t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") then table.insert(savedTools, t); t.Parent = nil end
		end
	end
	if bp then
		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") then table.insert(savedTools, t); t.Parent = nil end
		end
	end

	-- 2. Heartbeat loop: fire remote + force Character = nil @ 60fps
	LP.Character = nil
	local sending      = true
	local loopConn     = nil
	local throttle     = 0
	loopConn = RunService.Heartbeat:Connect(function(dt)
		if not sending then
			if loopConn then loopConn:Disconnect(); loopConn = nil end
			return
		end
		throttle = throttle + dt
		if throttle >= 0.016 then
			throttle = 0
			pcall(function() remote:FireServer(IR_GUID, LP, "balloon") end)
		end
		if sending and LP.Character then LP.Character = nil end
	end)

	-- 3. As soon as the character respawns: restore tools
	local respawnConn
	respawnConn = LP.CharacterAdded:Connect(function()
		sending = false
		if loopConn  then loopConn:Disconnect();  loopConn  = nil end
		if respawnConn then respawnConn:Disconnect(); respawnConn = nil end
		task.spawn(function()
			local newBp = LP:WaitForChild("Backpack", 3)
			if newBp then
				for _, t in ipairs(savedTools) do if t then t.Parent = newBp end end
			end
			savedTools = {}
		end)
	end)

	-- 4. 4s timeout so this never hangs forever
	task.delay(4, function()
		sending = false
		if loopConn    then loopConn:Disconnect();    loopConn    = nil end
		if respawnConn then respawnConn:Disconnect(); respawnConn = nil end
		local curBp = LP:FindFirstChild("Backpack")
		if curBp and #savedTools > 0 then
			for _, t in ipairs(savedTools) do if t then t.Parent = curBp end end
			savedTools = {}
		end
	end)
end

-- ===================================================================
-- AUTO RESET ON MEDUSA / ANCHORED-DETECT (Taser Hub — PlatformStand +
-- Anchored detection auto-triggers instaReset)
-- ===================================================================
local _armEnabled = false
local _armDebounce = false
local _armConns = {}

local function _armDoReset()
	if _armDebounce then return end
	_armDebounce = true
	task.spawn(function()
		pcall(instaReset)
		task.wait(3); _armDebounce = false
	end)
end

local function _armWatchPart(part)
	return part:GetPropertyChangedSignal("Anchored"):Connect(function()
		if not _armEnabled then return end
		if part.Anchored and part.Transparency == 1 then _armDoReset() end
	end)
end

local function setupAutoResetMedusa(char)
	for _,c in pairs(_armConns) do pcall(function() c:Disconnect() end) end; _armConns={}
	if not char then return end
	local hum=char:FindFirstChildOfClass("Humanoid")
	if hum then
		table.insert(_armConns, hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
			if not _armEnabled then return end
			if hum.PlatformStand then _armDoReset() end
		end))
	end
	for _,part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then table.insert(_armConns, _armWatchPart(part)) end
	end
	table.insert(_armConns, char.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then table.insert(_armConns, _armWatchPart(part)) end
	end))
end

local function stopAutoResetMedusa()
	for _,c in pairs(_armConns) do pcall(function() c:Disconnect() end) end; _armConns={}
end

local function setAutoResetOnMedEnabled(on)
	_armEnabled = on
	State.autoResetOnMedEnabled = on
	if on then setupAutoResetMedusa(LP.Character) else stopAutoResetMedusa() end
end

LP.CharacterAdded:Connect(function(char)
	task.wait(0.5); if _armEnabled then setupAutoResetMedusa(char) end
end)

-- ===================================================================
-- ANTI BAT (Envy logic — 1000 spike + XZ restore)
-- ===================================================================
local BC = {active=false, conn=nil}

function BC.start()
	if BC.conn then BC.conn:Disconnect() end
	BC.conn = RunService.Heartbeat:Connect(function()
		if not BC.active then return end
		local char = LP.Character; if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
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
-- BAT AIMBOT + AIM BYPASS (raw__59_ logic)
-- ===================================================================
local VYSE_HIT_DIST = 5
local AB_SPEED      = 58
local AB_HIT_CD     = false

local BAT_NAMES = {"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap"}

local function getBat()
	local c=LP.Character; if not c then return nil end
	for _,name in ipairs(BAT_NAMES) do local t=c:FindFirstChild(name); if t and t:IsA("Tool") then return t end end
	local bp=LP:FindFirstChildOfClass("Backpack"); if bp then
		for _,name in ipairs(BAT_NAMES) do local t=bp:FindFirstChild(name); if t then return t end end
	end
end

local function tryHitBat()
	if AB_HIT_CD then return end; AB_HIT_CD=true
	pcall(function()
		local bat=getBat(); if not bat then return end
		local c=LP.Character; local hum2=c and c:FindFirstChildOfClass("Humanoid")
		if bat.Parent~=c and hum2 then pcall(function() hum2:EquipTool(bat) end) end
		pcall(function() bat:Activate() end)
	end)
	task.delay(0.2, function() AB_HIT_CD=false end)
end

local function getClosestPlayerAim()
	local root=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not root then return nil,math.huge end
	local closest,minDist=nil,math.huge
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr~=LP and plr.Character then
			local tr=plr.Character:FindFirstChild("HumanoidRootPart"); local hum2=plr.Character:FindFirstChildOfClass("Humanoid")
			if tr and hum2 and hum2.Health>0 then
				local d=(tr.Position-root.Position).Magnitude; if d<minDist then minDist=d; closest=plr end
			end
		end
	end
	return closest,minDist
end

-- Aimbot V1 (prediction + 0.8 lerp)
local AB = {active=false, conn=nil, SPEED=AB_SPEED, HEIGHT=3.7}
function AB.start()
	AB.active=true
	if AB.conn then AB.conn:Disconnect() end
	local hum0=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if hum0 then hum0.AutoRotate=false end
	AB.conn=RunService.RenderStepped:Connect(function()
		if not AB.active then return end
		local char=LP.Character; if not char then return end
		local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
		local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
		if not char:FindFirstChildOfClass("Tool") then local bat=getBat(); if bat then pcall(function() hum:EquipTool(bat) end) end end
		local target,dist=getClosestPlayerAim()
		if not target or not target.Character then return end
		local tr=target.Character:FindFirstChild("HumanoidRootPart"); if not tr then return end
		local targetVel=tr.AssemblyLinearVelocity
		local myPos=root.Position; local targetPos=tr.Position
		local predictPos=targetPos+targetVel*0.14+tr.CFrame.LookVector*0.3
		local direction=predictPos-myPos; local flatDir=Vector3.new(direction.X,0,direction.Z).Unit
		local desiredHeight=targetPos.Y+AB.HEIGHT
		local yVel=(desiredHeight-myPos.Y)*19.5+targetVel.Y*0.8
		if hum.FloorMaterial~=Enum.Material.Air then yVel=math.max(yVel,13) end
		yVel=math.clamp(yVel,-70,110)
		local desiredVel=Vector3.new(flatDir.X*AB.SPEED,yVel,flatDir.Z*AB.SPEED)
		root.AssemblyLinearVelocity=root.AssemblyLinearVelocity:Lerp(desiredVel,0.8)
		local speed3=targetVel.Magnitude; local predictTime=math.clamp(speed3/150,0.05,0.2)
		local predictedPos=targetPos+targetVel*predictTime; local toPredict=predictedPos-myPos
		if toPredict.Magnitude>0.1 then
			local goalCF=CFrame.lookAt(myPos,predictedPos); local diffCF=root.CFrame:Inverse()*goalCF
			local rx,ry,rz=diffCF:ToEulerAnglesXYZ()
			rx=math.clamp(rx,-2.5,2.5); ry=math.clamp(ry,-2.5,2.5); rz=math.clamp(rz,-2.5,2.5)
			root.AssemblyAngularVelocity=root.CFrame:VectorToWorldSpace(Vector3.new(rx*42,ry*42,rz*42))
		end
		if dist<=VYSE_HIT_DIST then tryHitBat() end
	end)
end
function AB.stop()
	AB.active=false; if AB.conn then AB.conn:Disconnect(); AB.conn=nil end
	AB_HIT_CD=false
	local char=LP.Character; local root=char and char:FindFirstChild("HumanoidRootPart"); local hum=char and char:FindFirstChildOfClass("Humanoid")
	if root then root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero end
	if hum then hum.AutoRotate=true end
end

-- AIM V3 (anti-desync + enemy TP + strike)
local AimV3 = {active=false, conn=nil}
local _av3HitCD = false

local function _av3GetBat()
	local char=LP.Character; if not char then return nil end
	local tool=char:FindFirstChild("Bat"); if tool then return tool end
	local bp=LP:FindFirstChildOfClass("Backpack")
	if bp then tool=bp:FindFirstChild("Bat"); if tool then tool.Parent=char; return tool end end
	for _,n in ipairs(BAT_NAMES) do
		local t=char:FindFirstChild(n); if t then return t end
		if bp then t=bp:FindFirstChild(n); if t then t.Parent=char; return t end end
	end
	return nil
end

local function _av3Hit()
	if _av3HitCD then return end
	_av3HitCD=true
	pcall(function()
		local bat=_av3GetBat(); if not bat then return end
		pcall(function() bat:Activate() end)
		local ev=bat:FindFirstChildWhichIsA("RemoteEvent")
		if ev then pcall(function() ev:FireServer() end) end
	end)
	task.delay(0.08,function() _av3HitCD=false end)
end

local function _av3Nearest(root)
	local best,bestD=nil,math.huge
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=LP and p.Character then
			local tr=p.Character:FindFirstChild("HumanoidRootPart")
			if tr then local d=(root.Position-tr.Position).Magnitude; if d<bestD then bestD=d; best=p end end
		end
	end
	return best
end

function AimV3.start()
	if AimV3.conn then AimV3.conn:Disconnect() end; AimV3.active=true
	AimV3.conn=RunService.Heartbeat:Connect(function()
		if not AimV3.active then return end
		local root=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
		local target=_av3Nearest(root); if not target or not target.Character then return end
		local tr=target.Character:FindFirstChild("HumanoidRootPart"); if not tr then return end
		pcall(function()
			if sethiddenproperty then sethiddenproperty(root,"PhysicsRepRootPart",tr) end
			local targetPos=tr.Position+Vector3.new(0,0.9,0)
			if (root.Position-targetPos).Magnitude>8 then root.CFrame=CFrame.new(targetPos) end
			local cam=workspace.CurrentCamera
			cam.CFrame=CFrame.new(cam.CFrame.Position,tr.Position)
			_av3Hit()
		end)
	end)
end
function AimV3.stop()
	if AimV3.conn then AimV3.conn:Disconnect(); AimV3.conn=nil end; AimV3.active=false
end

-- Aim V2 (Taser Hub — prediction + angular rotation + AutoRotate false)
local ABP = {active=false, conn=nil}
local ABP_CFG = {
	CHASE_SPEED   = 58,
	VERT_SPEED    = 52,
	FOLLOW_DIST   = -2,
	HEIGHT_OFFSET = 1.6,
	VERT_OFFSET   = 1,
	TURN_SPEED    = 285,
	MAX_TURN_RATE = 40,
	SWING_RANGE   = 6,
}
local _abpUnwalkSaved = nil
local _abpScanCache, _abpScanTime = nil, 0

local function ABP_findBat()
	local char=LP.Character; if not char then return nil end
	local tool=char:FindFirstChild("Bat"); if tool then return tool end
	local bp=LP:FindFirstChildOfClass("Backpack")
	if bp then tool=bp:FindFirstChild("Bat"); if tool then tool.Parent=char; return tool end end
	for _,n in ipairs(BAT_NAMES) do
		local t=char:FindFirstChild(n) or (bp and bp:FindFirstChild(n))
		if t and t:IsA("Tool") then return t end
	end
	return nil
end

local function ABP_equip()
	local char=LP.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum then return end
	if not char:FindFirstChildOfClass("Tool") then
		local bat=ABP_findBat(); if bat then pcall(function() hum:EquipTool(bat) end) end
	end
end

local function ABP_swing()
	pcall(function()
		local bat=ABP_findBat(); if not bat then return end
		pcall(function() bat:Activate() end)
		local ev=bat:FindFirstChildWhichIsA("RemoteEvent")
		if ev then pcall(function() ev:FireServer() end) end
	end)
end

local function ABP_startUnwalk()
	local char=LP.Character; if not char then return end
	local hum=char:FindFirstChildOfClass("Humanoid")
	if hum then for _,tr in pairs(hum:GetPlayingAnimationTracks()) do tr:Stop() end end
	local anim=char:FindFirstChild("Animate")
	if anim then _abpUnwalkSaved=anim:Clone(); anim:Destroy() end
end

local function ABP_stopUnwalk()
	local char=LP.Character
	if char and _abpUnwalkSaved then _abpUnwalkSaved.Parent=char; _abpUnwalkSaved=nil end
end

local function ABP_resetMotion()
	local char=LP.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	if root then root.AssemblyLinearVelocity=root.AssemblyLinearVelocity*0.3; root.AssemblyAngularVelocity=Vector3.zero end
	if hum then hum.AutoRotate=true end
end

local function ABP_nearest(root)
	local now=tick()
	if now-_abpScanTime<=0.1 and _abpScanCache and _abpScanCache.Parent then
		local hh=_abpScanCache.Parent and _abpScanCache.Parent:FindFirstChildOfClass("Humanoid")
		if hh and hh.Health>0 then return _abpScanCache end
	end
	_abpScanTime=now; _abpScanCache=nil
	local best,bestD=nil,math.huge
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=LP and p.Character then
			local tr=p.Character:FindFirstChild("HumanoidRootPart")
			local hh=p.Character:FindFirstChildOfClass("Humanoid")
			if tr and hh and hh.Health>0 then
				local d=(tr.Position-root.Position).Magnitude
				if d<bestD then bestD=d; best=tr end
			end
		end
	end
	_abpScanCache=best; return best
end

function ABP.start()
	if ABP.conn then ABP.conn:Disconnect() end; ABP.active=true
	ABP_startUnwalk()
	ABP.conn=RunService.Heartbeat:Connect(function()
		if not ABP.active then return end
		local char=LP.Character; if not char then return end
		local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
		local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
		ABP_equip()
		local target=ABP_nearest(root)
		if target then
			local vel=target.AssemblyLinearVelocity
			local aimPos=target.Position+(vel*math.clamp(vel.Magnitude/130,0.05,0.15))+Vector3.new(0,ABP_CFG.VERT_OFFSET,0)
			hum.AutoRotate=false
			local look=aimPos-root.Position
			local flat=Vector3.new(look.X,0,look.Z)
			if look.Magnitude>0.01 and flat.Magnitude>0.01 then
				local tYaw=math.deg(math.atan2(-flat.X,-flat.Z))
				local yawD=(tYaw-root.Orientation.Y+180)%360-180
				local tPitch=math.deg(math.atan2(look.Y,flat.Magnitude))
				local pitD=(tPitch-root.Orientation.X+180)%360-180
				local yawR=math.clamp(math.rad(yawD)*ABP_CFG.TURN_SPEED,-ABP_CFG.MAX_TURN_RATE,ABP_CFG.MAX_TURN_RATE)
				local pitR=math.clamp(math.rad(pitD)*ABP_CFG.TURN_SPEED,-ABP_CFG.MAX_TURN_RATE,ABP_CFG.MAX_TURN_RATE)
				local yr=math.rad(root.Orientation.Y)
				local right=Vector3.new(math.cos(yr),0,-math.sin(yr))
				root.AssemblyAngularVelocity=Vector3.new(0,yawR,0)+(right*pitR)
			else
				root.AssemblyAngularVelocity=Vector3.zero
			end
			local fd=math.max(math.abs(ABP_CFG.FOLLOW_DIST),1)
			local dir=look.Magnitude>0.01 and look.Unit or Vector3.new(1,0,0)
			local standPos=aimPos-(dir*fd)+Vector3.new(0,ABP_CFG.HEIGHT_OFFSET,0)
			local mv=standPos-root.Position
			local hDir=Vector3.new(mv.X,0,mv.Z)
			local hVel=hDir.Magnitude>0.1 and hDir.Unit*ABP_CFG.CHASE_SPEED or Vector3.zero
			local vVel=math.abs(mv.Y)>0.1 and Vector3.new(0,math.sign(mv.Y)*ABP_CFG.VERT_SPEED,0) or Vector3.new(0,-2,0)
			root.AssemblyLinearVelocity=hVel+vVel
			if hDir.Magnitude>0.5 then hum:Move(hDir.Unit,false) end
			if (root.Position-target.Position).Magnitude<ABP_CFG.SWING_RANGE then
				ABP_swing()
			end
		else
			hum.AutoRotate=true
			root.AssemblyAngularVelocity=Vector3.zero
			root.AssemblyLinearVelocity=Vector3.zero
		end
	end)
end
function ABP.stop()
	if ABP.conn then ABP.conn:Disconnect(); ABP.conn=nil end; ABP.active=false
	ABP_resetMotion(); ABP_stopUnwalk(); _abpScanCache=nil
end

-- ===================================================================
-- INFINITE JUMP
-- ===================================================================
local IJ = {active=false, conn=nil, hbConn=nil, wantJump=false, mode="manual"}
function IJ.start()
	if IJ.conn then IJ.conn:Disconnect() end; if IJ.hbConn then IJ.hbConn:Disconnect() end; IJ.wantJump=false
	IJ.conn=UIS.JumpRequest:Connect(function()
		if IJ.active and IJ.mode=="manual" then IJ.wantJump=true end
	end)
	IJ.hbConn=RunService.Heartbeat:Connect(function()
		if not IJ.active then return end
		local c=LP.Character; if not c then return end
		local root=c:FindFirstChild("HumanoidRootPart"); if not root then return end
		if IJ.mode=="manual" then
			if not IJ.wantJump then return end; IJ.wantJump=false
			root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,55,root.AssemblyLinearVelocity.Z)
		elseif IJ.mode=="hold" then
			local hum2=c:FindFirstChildOfClass("Humanoid")
			local jumpHeld=UIS:IsKeyDown(Enum.KeyCode.Space) or (hum2 and hum2.Jump==true)
			if jumpHeld and root.AssemblyLinearVelocity.Y<30 then
				root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,55,root.AssemblyLinearVelocity.Z)
			end
		end
		if root.AssemblyLinearVelocity.Y<-120 then root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,-120,root.AssemblyLinearVelocity.Z) end
	end)
end
function IJ.stop()
	if IJ.conn then IJ.conn:Disconnect(); IJ.conn=nil end
	if IJ.hbConn then IJ.hbConn:Disconnect(); IJ.hbConn=nil end; IJ.wantJump=false
end

-- ===================================================================
-- BAT COUNTER (bat_counter.txt — RemoteEvent support + "bat" keyword fallback)
-- ===================================================================
local BatCounter = {active=false, conn=nil}
local _bcDebounce = false

local function findBatForCounter()
	local c=LP.Character; if not c then return nil end
	local bp=LP:FindFirstChildOfClass("Backpack")
	for _,name in ipairs(BAT_NAMES) do
		local t=c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
		if t then return t end
	end
	for _,ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
	if bp then for _,ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
	return nil
end
local function swingBatForCounter(bat,char)
	local hum2=char:FindFirstChildOfClass("Humanoid")
	if bat.Parent~=char then if hum2 then pcall(function() hum2:EquipTool(bat) end) end; task.wait(0.05) end
	local remote=bat:FindFirstChildOfClass("RemoteEvent") or bat:FindFirstChildOfClass("RemoteFunction")
	if remote and remote:IsA("RemoteEvent") then
		pcall(function() remote:FireServer() end); task.wait(0.15); pcall(function() remote:FireServer() end)
	else pcall(function() bat:Activate() end); task.wait(0.15); pcall(function() bat:Activate() end) end
end
function BatCounter.start()
	if BatCounter.conn then BatCounter.conn:Disconnect() end
	BatCounter.conn=RunService.Heartbeat:Connect(function()
		if not BatCounter.active or _bcDebounce then return end
		local char=LP.Character; if not char then return end
		local hum2=char:FindFirstChildOfClass("Humanoid"); if not hum2 then return end
		local st=hum2:GetState()
		if st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then
			_bcDebounce=true
			task.spawn(function()
				local bat=findBatForCounter()
				if bat then swingBatForCounter(bat,char) end
				task.wait(0.5); _bcDebounce=false
			end)
		end
	end)
end
function BatCounter.stop()
	if BatCounter.conn then BatCounter.conn:Disconnect(); BatCounter.conn=nil end
	_bcDebounce=false
end

-- ===================================================================
-- ANTI-DIE (source: anti_die_made_by_mehneymarish_11.txt)
-- ===================================================================
local _adLoop    = nil
local _adCharConn = nil
local _adInvincibleUntil = 0
local _adConfig  = { healthThreshold=25, fallDamageProtection=true, ragdollProtection=true, invincibilityFrames=0.5 }

local function _adSuperHeal(hum)
	if not hum or not hum.Parent then return end
	local max = hum.MaxHealth or 100
	if hum.Health >= max and hum.Health > 0 then return end
	hum.Health = max
	_adInvincibleUntil = tick() + _adConfig.invincibilityFrames
	pcall(function()
		local char = hum.Parent
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("NumberValue") then
				local n = child.Name:lower()
				if n:find("health") or n:find("hp") or n:find("life") then child.Value = 100 end
			elseif child:IsA("BoolValue") and child.Name:lower():find("dead") then
				child.Value = false
			end
		end
	end)
end

local function _adSetup(char)
	if not char then return end
	local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if _adLoop then pcall(function() _adLoop:Disconnect() end); _adLoop = nil end
	_adLoop = RunService.Heartbeat:Connect(function()
		if not hum or not hum.Parent then return end
		if hum.Health <= 0 then
			_adSuperHeal(hum)
			hum:ChangeState(Enum.HumanoidStateType.Running)
			if root and root.Parent then
				root.CFrame = CFrame.new(root.Position + Vector3.new(0,2,0))
				root.AssemblyLinearVelocity = Vector3.zero
			end
			return
		end
		if tick() < _adInvincibleUntil and hum.Health < hum.MaxHealth then
			hum.Health = hum.MaxHealth
		end
		if _adConfig.fallDamageProtection and root and root.Parent then
			local vy = root.AssemblyLinearVelocity.Y
			if vy < -25 then
				root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -3, root.AssemblyLinearVelocity.Z)
				_adSuperHeal(hum)
			end
		end
		if _adConfig.ragdollProtection then
			local st = hum:GetState()
			if st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then
				hum:ChangeState(Enum.HumanoidStateType.Running)
				_adSuperHeal(hum)
				if root and root.Parent then
					root.AssemblyLinearVelocity  = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end
		if hum.Health > 0 and hum.Health <= _adConfig.healthThreshold then _adSuperHeal(hum) end
	end)
end

local function startAntiDie()
	if _adCharConn then pcall(function() _adCharConn:Disconnect() end); _adCharConn = nil end
	_adSetup(LP.Character)
	_adCharConn = LP.CharacterAdded:Connect(function(char) task.wait(0.1); _adSetup(char) end)
end

local function stopAntiDie()
	if _adLoop     then pcall(function() _adLoop:Disconnect() end);     _adLoop     = nil end
	if _adCharConn then pcall(function() _adCharConn:Disconnect() end); _adCharConn = nil end
end

-- ===================================================================
-- ANTI-KICK / ANTI-DETECT (source: Anti_kick_source_works.txt)
-- Kick blocking, per-char protections, position/velocity safety,
-- suspicious remote blocking, workspace/MaxHealth watchdog.
-- ===================================================================
local _akActive      = false
local _akOldNamecall = nil
local _akMt          = nil
local _akPosConn     = nil
local _akDeathConn   = nil
local _akHealthConn  = nil  -- HealthChanged event (immediate restore)
local _akMaxHpConn   = nil  -- MaxHealth signal (reset only if changed)
local _akLastSafe    = nil
local _akRemoteConns = {}   -- connections from blockRemoteKicks
local _akCharOldNI   = nil  -- saved __newindex for blockCharacterDestruction restore
local _akCharMtRef   = nil  -- character metatable ref
local _akLoopActive    = false -- controls workspace/maxHealth while loops
local _akCharAddedConn = nil   -- re-hook humanoid + char protections after respawn
local _akRespawnCount  = 0     -- rapid-respawn counter (monitorKickAttempts)
local _akLastRespawn   = 0

-- Re-bind humanoid events to whichever humanoid is currently alive.
-- Called both at startAntiKick time and on every CharacterAdded.
local function _akHookHumanoid(char)
	if _akDeathConn  then pcall(function() _akDeathConn:Disconnect()  end); _akDeathConn  = nil end
	if _akHealthConn then pcall(function() _akHealthConn:Disconnect() end); _akHealthConn = nil end
	if _akMaxHpConn  then pcall(function() _akMaxHpConn:Disconnect()  end); _akMaxHpConn  = nil end
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	_akDeathConn = hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Dead
		or new == Enum.HumanoidStateType.Dying
		or new == Enum.HumanoidStateType.FallingDown then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			hum.Health = hum.MaxHealth
		end
	end)
	_akHealthConn = hum.HealthChanged:Connect(function(hp)
		if hp <= 0 then hum.Health = hum.MaxHealth end
	end)
	_akMaxHpConn = hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		if hum.MaxHealth ~= 100 then hum.MaxHealth = 100 end
	end)
end

-- Full per-character setup: humanoid events + character __newindex + position reset.
local function _akHookChar(char)
	_akHookHumanoid(char)
	-- Restore old __newindex on previous char metatable if any
	if _akCharMtRef and _akCharOldNI ~= nil then
		pcall(function()
			setreadonly(_akCharMtRef, false)
			_akCharMtRef.__newindex = _akCharOldNI
			setreadonly(_akCharMtRef, true)
		end)
		_akCharOldNI = nil; _akCharMtRef = nil
	end
	-- Hook new char metatable to block :Destroy() / Parent = nil
	pcall(function()
		if not char then return end
		local cm = getrawmetatable(char); if not cm then return end
		setreadonly(cm, false)
		_akCharOldNI = cm.__newindex
		local _oldNI = _akCharOldNI
		cm.__newindex = function(self, key, value)
			if key == "Parent" and value == nil then return nil end
			if _oldNI then return _oldNI(self, key, value) end
			rawset(self, key, value)
		end
		setreadonly(cm, true)
		_akCharMtRef = cm
	end)
	-- Reset position safety to new spawn point
	local hrp2 = char and char:FindFirstChild("HumanoidRootPart")
	if hrp2 then _akLastSafe = hrp2.CFrame end
end

local function startAntiKick()
	if _akActive then return end
	-- 1. Block :Kick() via __namecall
	pcall(function()
		local mt = getrawmetatable(LP); if not mt then return end
		setreadonly(mt, false)
		_akOldNamecall = mt.__namecall
		local _raw = _akOldNamecall
		local _hookBody = function(self, ...)
			-- only intercept calls coming from game scripts, not from our own code
			local fromGame = not (checkcaller and checkcaller())
			if fromGame then
				local method = tostring(getnamecallmethod and getnamecallmethod() or ""):lower()
				if self == LP and method == "kick" then return nil end
			end
			return _raw(self, ...)
		end
		mt.__namecall = (newcclosure and newcclosure(_hookBody)) or _hookBody
		setreadonly(mt, true)
		_akMt = mt
	end)
	-- 2. Per-character protections (humanoid events + char __newindex) + respawn re-hook
	local char0 = LP.Character
	_akHookChar(char0)
	-- CharacterAdded: re-apply every time the player respawns (monitorKickAttempts + full re-hook)
	_akCharAddedConn = LP.CharacterAdded:Connect(function(newChar)
		if not _akActive then return end
		-- Rapid-respawn detection: 3+ respawns in <9s → possible kick loop
		local now = tick()
		if now - _akLastRespawn < 3 then _akRespawnCount = _akRespawnCount + 1
		else _akRespawnCount = 0 end
		_akLastRespawn = now
		task.defer(function()
			if not _akActive then return end
			_akHookChar(newChar)
		end)
	end)
	-- 3. Position safety (anti-teleport >150 studs while not moving) + velocity clamp
	if _akPosConn then pcall(function() _akPosConn:Disconnect() end) end
	_akPosConn = RunService.Heartbeat:Connect(function()
		local c2   = LP.Character;                          if not c2 then return end
		local r2   = c2:FindFirstChild("HumanoidRootPart"); if not r2 then return end
		local h2   = c2:FindFirstChildOfClass("Humanoid");  if not h2 then return end
		-- position lock
		if _akLastSafe then
			local dist = (r2.Position - _akLastSafe.Position).Magnitude
			if dist > 150 and h2.MoveDirection.Magnitude < 0.1 then
				r2.CFrame = _akLastSafe; return
			end
		end
		local ref = _akLastSafe and _akLastSafe.Position or r2.Position
		if (r2.Position - ref).Magnitude < 30 then
			_akLastSafe = r2.CFrame
		end
		-- velocity clamp: extreme fall speed → soften; extreme horizontal without input → brake
		local vel = r2.AssemblyLinearVelocity
		if vel.Y < -150 then
			r2.AssemblyLinearVelocity = Vector3.new(vel.X, -50, vel.Z)
			h2.Health = h2.MaxHealth
		elseif vel.Magnitude > 300 and h2.MoveDirection.Magnitude < 0.1 then
			r2.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
		end
		-- fall damage prevention: restore health if falling hard
		if vel.Y < -50 then h2.Health = h2.MaxHealth end
		-- immortality: unconditional restore every frame
		if h2.Health < h2.MaxHealth then h2.Health = h2.MaxHealth end
	end)
	-- 4. Block OnClientEvent on suspicious-named RemoteEvents in ReplicatedStorage
	pcall(function()
		local RS = ReplicatedStorage
		local function hookRemote(obj)
			if not (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then return end
			local n = obj.Name:lower()
			if n:find("kick") or n:find("ban") or n:find("remove") or n:find("disconnect") then
				pcall(function()
					if obj:IsA("RemoteEvent") then
						local c = obj.OnClientEvent:Connect(function() return nil end)
						_akRemoteConns[#_akRemoteConns+1] = c
					end
				end)
			end
		end
		for _, d in ipairs(RS:GetDescendants()) do hookRemote(d) end
		local c = RS.DescendantAdded:Connect(function(d) pcall(hookRemote, d) end)
		_akRemoteConns[#_akRemoteConns+1] = c
	end)
	-- 5. Workspace monitor + MaxHealth lock — run as cooperative loops
	_akLoopActive = true
	task.spawn(function()
		while _akLoopActive do
			pcall(function()
				local c3 = LP.Character; if not c3 then return end
				if c3.Parent ~= workspace then c3.Parent = workspace end
				local h3 = c3:FindFirstChildOfClass("Humanoid")
				if h3 then
					if h3.MaxHealth ~= 100 then h3.MaxHealth = 100 end
					if h3.Health <= 0    then h3.Health = h3.MaxHealth end
				else
					local nh = Instance.new("Humanoid")
					nh.Parent = c3
				end
			end)
			task.wait(0.1)
		end
	end)
	_akActive = true
end

local function stopAntiKick()
	if not _akActive then return end
	_akLoopActive = false
	if _akCharAddedConn then pcall(function() _akCharAddedConn:Disconnect() end); _akCharAddedConn = nil end
	if _akPosConn    then pcall(function() _akPosConn:Disconnect()    end); _akPosConn    = nil end
	if _akDeathConn  then pcall(function() _akDeathConn:Disconnect()  end); _akDeathConn  = nil end
	if _akHealthConn then pcall(function() _akHealthConn:Disconnect() end); _akHealthConn = nil end
	if _akMaxHpConn  then pcall(function() _akMaxHpConn:Disconnect()  end); _akMaxHpConn  = nil end
	-- disconnect remote event intercepts
	for _, c in ipairs(_akRemoteConns) do pcall(function() c:Disconnect() end) end
	_akRemoteConns = {}
	-- restore character __newindex
	if _akCharMtRef and _akCharOldNI ~= nil then
		pcall(function()
			setreadonly(_akCharMtRef, false)
			_akCharMtRef.__newindex = _akCharOldNI
			setreadonly(_akCharMtRef, true)
		end)
		_akCharOldNI = nil; _akCharMtRef = nil
	end
	-- restore __namecall
	if _akMt and _akOldNamecall then
		pcall(function()
			setreadonly(_akMt, false)
			_akMt.__namecall = _akOldNamecall
			setreadonly(_akMt, true)
		end)
		_akOldNamecall = nil; _akMt = nil
	end
	_akActive = false
end
-- Anti-kick/anti-detect starts automatically, matching source behavior
-- (source called `task.spawn(function() pcall(startAntiKick) end)` unconditionally).
task.spawn(function() pcall(startAntiKick) end)

-- ===================================================================
-- SPEED BYPASS (Moon Hub style — deliberate render-thread stall "lag
-- switch", +/- power slider, keybind toggle). Exact Cz lag logic kept.
-- ===================================================================
local SpeedBypass = { activated = false, keybind = Enum.KeyCode.E, power = 79000, lagAmount = 0.15, lagConn = nil }

local function sbApplyPower(val)
	SpeedBypass.power = math.clamp(val, 10000, 500000)
	local t = (SpeedBypass.power - 10000) / 490000
	SpeedBypass.lagAmount = t * 0.2
end
sbApplyPower(SpeedBypass.power)

local function sbStartLag()
	if SpeedBypass.lagConn then SpeedBypass.lagConn:Disconnect() end
	SpeedBypass.lagConn = RunService.RenderStepped:Connect(function()
		if not SpeedBypass.activated then return end
		if SpeedBypass.lagAmount > 0 then
			local t = tick()
			while tick() - t < SpeedBypass.lagAmount do end
		end
	end)
end

local function sbStopLag()
	SpeedBypass.activated = false
	if SpeedBypass.lagConn then SpeedBypass.lagConn:Disconnect(); SpeedBypass.lagConn = nil end
end

local function speedBypassToggle()
	if not SpeedBypass.activated then
		SpeedBypass.activated = true
		sbStartLag()
	else
		sbStopLag()
	end
	_safeCall(UICallbacks.onSpeedBypassToggle, SpeedBypass.activated)
end
local function speedBypassIsActive() return SpeedBypass.activated end
local function speedBypassSetPower(val) sbApplyPower(val); return SpeedBypass.power end
local function speedBypassSetKeybind(kc) SpeedBypass.keybind = kc end

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if UIS:GetFocusedTextBox() then return end
	if input.KeyCode == SpeedBypass.keybind then speedBypassToggle() end
end)

-- stopLag() forces activated=false; re-arm the loop directly without
-- touching `activated` so a respawn doesn't silently disable the feature.
LP.CharacterAdded:Connect(function()
	task.wait(1)
	if SpeedBypass.activated then
		if SpeedBypass.lagConn then SpeedBypass.lagConn:Disconnect(); SpeedBypass.lagConn = nil end
		sbStartLag()
	end
end)

-- ===================================================================
-- MOON LAGGER (source moon_lgr.txt) — network "bomb" self-lag levels +
-- keybind toggle. Integrated logic-only (no UI/config persistence file).
-- ===================================================================
local MoonLagger = { NIVELES = { Low={poder=23}, Mid={poder=32}, High={poder=70}, Ultra={poder=90} },
	keybind = Enum.KeyCode.M, active = false, thread = nil, level = "Low" }

local function mlBomb(poder)
	local main, spam = {}, {{}}
	local z = spam[1]
	for i = 1, 25 do local t = {} table.insert(z, t) z = t end
	local max = math.min(12000, poder * 50)
	for i = 1, max do table.insert(main, spam) end
	pcall(function() game:GetService("RobloxReplicatedStorage").SetPlayerBlockList:FireServer(main) end)
end

local function moonLaggerToggle()
	MoonLagger.active = not MoonLagger.active
	if MoonLagger.active then
		if MoonLagger.thread then task.cancel(MoonLagger.thread) end
		MoonLagger.thread = task.spawn(function()
			while MoonLagger.active do
				pcall(function() game:GetService("NetworkClient"):SetOutgoingKBPSLimit(80000) end)
				mlBomb(MoonLagger.NIVELES[MoonLagger.level].poder)
				task.wait(0.18)
			end
		end)
	else
		if MoonLagger.thread then task.cancel(MoonLagger.thread); MoonLagger.thread = nil end
	end
end
local function moonLaggerSetLevel(name) if MoonLagger.NIVELES[name] then MoonLagger.level = name end end
local function moonLaggerIsActive() return MoonLagger.active end
local function moonLaggerSetKeybind(kc) MoonLagger.keybind = kc end

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if UIS:GetFocusedTextBox() then return end
	if input.KeyCode == MoonLagger.keybind then moonLaggerToggle() end
end)

-- ===================================================================
-- KEYBIND SYSTEM (PC keyboard + PlayStation/Xbox controller bindings,
-- Amir-Hub-inspired — logic only, no rebind UI)
-- ===================================================================
local KB = {
	AntiBatAimbot = {key=nil, gp=nil},
	DropBR        = {key=nil, gp=nil},
	AutoLeft      = {key=nil, gp=nil},
	AimBot        = {key=nil, gp=nil},
	AutoRight     = {key=nil, gp=nil},
	TPDown        = {key=nil, gp=nil},
	LagNorm       = {key=nil, gp=nil},
	BatTP         = {key=nil, gp=nil},
	AimV2         = {key=nil, gp=nil},
	AimV3Kb       = {key=nil, gp=nil},
	InstantReset  = {key=nil, gp=nil},
	HideUI        = {key=nil, gp=nil},
}

local GAMEPAD_KEYS = {
	[Enum.KeyCode.ButtonA]=true,[Enum.KeyCode.ButtonB]=true,
	[Enum.KeyCode.ButtonX]=true,[Enum.KeyCode.ButtonY]=true,
	[Enum.KeyCode.ButtonL1]=true,[Enum.KeyCode.ButtonR1]=true,
	[Enum.KeyCode.ButtonL2]=true,[Enum.KeyCode.ButtonR2]=true,
	[Enum.KeyCode.ButtonL3]=true,[Enum.KeyCode.ButtonR3]=true,
	[Enum.KeyCode.ButtonStart]=true,[Enum.KeyCode.ButtonSelect]=true,
	[Enum.KeyCode.DPadUp]=true,[Enum.KeyCode.DPadDown]=true,
	[Enum.KeyCode.DPadLeft]=true,[Enum.KeyCode.DPadRight]=true,
}

-- guiVisible toggle slot — future UI assigns real show/hide functions here
local function _defaultShowGui() State.guiVisible = true end
local function _defaultHideGui() State.guiVisible = false end
local uiShowGui, uiHideGui = _defaultShowGui, _defaultHideGui
local function setGuiVisibilityHandlers(showFn, hideFn) uiShowGui = showFn or _defaultShowGui; uiHideGui = hideFn or _defaultHideGui end

-- Global UIS.InputBegan loop — triggers the bound actions (no rebind-listening
-- state here since there is no rebind UI in this pass; a future UI can guard
-- this dispatcher externally while it is capturing a new key)
local _kbListening = false -- future UI sets true while capturing a rebind
local function setKeybindListening(on) _kbListening = on end

UIS.InputBegan:Connect(function(inp, gpe)
	if gpe then return end
	if _kbListening then return end
	if UIS:GetFocusedTextBox() then return end
	local kc = inp.KeyCode
	if kc == Enum.KeyCode.Unknown then return end

	local function match(e)
		return (e.key and kc == e.key) or (e.gp and kc == e.gp)
	end

	if match(KB.AntiBatAimbot) then
		local on = not BC.active
		BC.active = on; if on then BC.start() else BC.stop() end
		if on and not IJ.active then IJ.active = true; IJ.start() end
		_safeCall(UICallbacks.onAntiBatToggle, on)
	elseif match(KB.DropBR)    then runDropBrainrot()
	elseif match(KB.AutoLeft)  then
		State.autoLeftEnabled = not State.autoLeftEnabled
		if State.autoLeftEnabled then startAutoLeft() else stopAutoLeft() end
	elseif match(KB.AimBot)    then
		local on = not AB.active; if on then AB.start() else AB.stop() end
	elseif match(KB.AutoRight) then
		State.autoRightEnabled = not State.autoRightEnabled
		if State.autoRightEnabled then startAutoRight() else stopAutoRight() end
	elseif match(KB.TPDown)    then tpToGround()
	elseif match(KB.LagNorm)   then
		State.laggerActive = not State.laggerActive
		if not State.laggerActive then proxyStop() end
	elseif match(KB.BatTP)     then
		local on = not AimV3.active
		if on then AimV3.start() else AimV3.stop() end
	elseif match(KB.AimV2)     then
		if ABP.active then ABP.stop() else if AB.active then AB.stop() end; ABP.start() end
	elseif match(KB.AimV3Kb)   then
		if AimV3.active then AimV3.stop() else AimV3.start() end
	elseif match(KB.InstantReset) then
		pcall(instaReset)
	elseif match(KB.HideUI) then
		if State.guiVisible then uiHideGui() else uiShowGui() end
	end
end)

-- ===================================================================
-- APPLY ANTI-BAT STATE (shared toggle helper used by keybind + future UI)
-- ===================================================================
local function applyAntiBatState(on)
	BC.active = on; if on then BC.start() else BC.stop() end
	if on then
		if not IJ.active then IJ.active = true; IJ.start() end
	end
	_safeCall(UICallbacks.onAntiBatToggle, on)
	_safeCall(UICallbacks.onAutoSave)
end

-- ===================================================================
-- PUBLIC API — exposed table for the future UI layer to wire up
-- ===================================================================
local MoonHubLogic = {
	State = State,
	UICallbacks = UICallbacks,
	KB = KB,

	-- speed / movement
	getCurrentSpeed = getCurrentSpeed,
	updateCarryState = updateCarryState,
	proxyMove = proxyMove,
	proxyStop = proxyStop,
	ensureProxy = ensureProxy,
	setSpeedBoosterActive = setSpeedBoosterActive,
	isSpeedBoosterActive = isSpeedBoosterActive,

	-- movement features
	startAutoLeft = startAutoLeft, stopAutoLeft = stopAutoLeft,
	startAutoRight = startAutoRight, stopAutoRight = stopAutoRight,
	tpToGround = tpToGround,
	runDropBrainrot = runDropBrainrot,

	-- survivability
	startAntiRagdoll = startAntiRagdoll, stopAntiRagdoll = stopAntiRagdoll,
	startUnwalk = startUnwalk, stopUnwalk = stopUnwalk,
	startAntiDie = startAntiDie, stopAntiDie = stopAntiDie,
	startAntiKick = startAntiKick, stopAntiKick = stopAntiKick,

	-- reset logic (manual + auto)
	instaReset = instaReset,
	setAutoResetOnMedEnabled = setAutoResetOnMedEnabled,

	-- medusa
	setupMedusaCounter = setupMedusaCounter, stopMedusaCounter = stopMedusaCounter,
	useMedusaCounter = useMedusaCounter,

	-- optimize / anti-lag
	nukeOptStart = nukeOptStart, nukeOptStop = nukeOptStop,
	removeAccStart = removeAccStart, removeAccStop = removeAccStop,
	antiLagAdvStart = antiLagAdvStart, antiLagAdvStop = antiLagAdvStop,
	cleanParticlesAndLights = cleanParticlesAndLights,
	runUltraMode = runUltraMode,
	noCamCollisionStart = noCamCollisionStart, noCamCollisionStop = noCamCollisionStop,
	ralStart = ralStart, ralStop = ralStop,

	-- combat / anti-bat / aimbots
	BC = BC, AB = AB, AimV3 = AimV3, ABP = ABP, IJ = IJ, BatCounter = BatCounter,
	applyAntiBatState = applyAntiBatState,

	-- speed bypass / moon lagger
	speedBypassToggle = speedBypassToggle,
	speedBypassIsActive = speedBypassIsActive,
	speedBypassSetPower = speedBypassSetPower,
	speedBypassSetKeybind = speedBypassSetKeybind,
	moonLaggerToggle = moonLaggerToggle,
	moonLaggerSetLevel = moonLaggerSetLevel,
	moonLaggerIsActive = moonLaggerIsActive,
	moonLaggerSetKeybind = moonLaggerSetKeybind,

	-- keybinds / gui visibility slot
	setGuiVisibilityHandlers = setGuiVisibilityHandlers,
	setKeybindListening = setKeybindListening,
}

_G[_MHLB_KEY .. "_API"] = MoonHubLogic

return MoonHubLogic
