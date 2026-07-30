local _NS = tostring(math.random(0x100000, 0xFFFFFF)) .. tostring(tick()):gsub("%.", "")
if _G[_NS] then return end
_G[_NS] = true
local _GH  = {}   -- replaces all _GH.* / _GH.MH_* to leave zero _G footprint

if not game:IsLoaded() then game.Loaded:Wait() end

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UIS           = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")
local Lighting      = game:GetService("Lighting")
local LP            = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

-- ===================================================================
-- COLOR PALETTE
-- ===================================================================
local C_BG      = Color3.fromRGB(0,0,0)
local C_HEADER  = Color3.fromRGB(0,0,0)
local C_ROW     = Color3.fromRGB(0,0,0)
local C_BORDER  = Color3.fromRGB(40,46,58)
local C_WHITE   = Color3.fromRGB(255,255,255)
local C_MOON    = Color3.fromRGB(90,160,255)
local C_MOON2   = Color3.fromRGB(160,200,255)
local C_DIM     = Color3.fromRGB(110,120,140)
local C_TABIDLE = Color3.fromRGB(160,200,255)
local C_ON_BG   = Color3.fromRGB(20,45,80)
local C_OFF_BG  = Color3.fromRGB(0,0,0)
local C_SILVER  = Color3.fromRGB(210,222,240)
local C_SILVER2 = Color3.fromRGB(140,165,210)
local C_RED     = Color3.fromRGB(220,60,60)
local C_GREEN   = Color3.fromRGB(60,220,120)
-- Living gradient palette (updated by applyTheme so new buttons always use theme colors)
local C_DEEP1 = Color3.fromRGB(4,7,16)
local C_DEEP2 = Color3.fromRGB(14,28,58)
local C_DEEP3 = Color3.fromRGB(40,80,165)
local C_DEEP4 = Color3.fromRGB(90,150,255)

-- ===================================================================
-- THEME SYSTEM (Défaut = bleu, Noir = monochrome)
-- ===================================================================
local _THEME_DEFS = {
	default = {
		moon    = Color3.fromRGB(90,160,255),
		moon2   = Color3.fromRGB(160,200,255),
		on_bg   = Color3.fromRGB(20,45,80),
		border  = Color3.fromRGB(40,46,58),
		silver  = Color3.fromRGB(210,222,240),
		silver2 = Color3.fromRGB(140,165,210),
		dim     = Color3.fromRGB(110,120,140),
		d3      = Color3.fromRGB(40,80,165),
		d4      = Color3.fromRGB(90,150,255),
	},
	noir = {
		moon    = Color3.fromRGB(205,205,205),
		moon2   = Color3.fromRGB(175,175,175),
		on_bg   = Color3.fromRGB(28,28,28),
		border  = Color3.fromRGB(44,44,44),
		silver  = Color3.fromRGB(210,210,210),
		silver2 = Color3.fromRGB(148,148,148),
		dim     = Color3.fromRGB(105,105,105),
		d3      = Color3.fromRGB(35,35,35),
		d4      = Color3.fromRGB(165,165,165),
	}
}
local _currentTheme = "default"
local _themeAllGuis = {}
local _G_updateThemeUI = nil

local function _tColKey(col, themeName)
	local t = _THEME_DEFS[themeName]
	local r,g,b = col.R, col.G, col.B
	for k,v in pairs(t) do
		if math.abs(r-v.R)+math.abs(g-v.G)+math.abs(b-v.B) < 0.015 then return k end
	end
end

local function applyTheme(newName)
	if not _THEME_DEFS[newName] then return end
	local oldName = _currentTheme
	_currentTheme = newName
	local new = _THEME_DEFS[newName]
	C_MOON    = new.moon;   C_MOON2   = new.moon2
	C_ON_BG   = new.on_bg; C_BORDER  = new.border
	C_SILVER  = new.silver; C_SILVER2 = new.silver2
	C_DIM     = new.dim;   C_TABIDLE = new.moon2
	C_DEEP3   = new.d3;    C_DEEP4   = new.d4
	for _, guiRoot in ipairs(_themeAllGuis) do
		pcall(function()
			for _, inst in ipairs(guiRoot:GetDescendants()) do
				pcall(function()
					if inst:IsA("GuiObject") then
						local k = _tColKey(inst.BackgroundColor3, oldName)
						if k then inst.BackgroundColor3 = new[k] end
					end
					if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
						local k = _tColKey(inst.TextColor3, oldName)
						if k then inst.TextColor3 = new[k] end
					end
					if inst:IsA("UIStroke") then
						local k = _tColKey(inst.Color, oldName)
						if k then inst.Color = new[k] end
					end
					if inst:IsA("UIGradient") then
						local cs = inst.Color; local kps = cs.Keypoints
						local changed,newKps = false,{}
						for _,kp in ipairs(kps) do
							local k = _tColKey(kp.Value, oldName)
							if k then table.insert(newKps,ColorSequenceKeypoint.new(kp.Time,new[k])); changed=true
							else table.insert(newKps,kp) end
						end
						if changed then inst.Color = ColorSequence.new(newKps) end
					end
				end)
			end
		end)
	end
	-- steal fill gradient: swap between blue shimmer (default) and grey shimmer (noir)
	if _GH.stealFillGradRef and _GH.stealFillGradRef.Parent then
		if newName == "noir" then
			_GH.stealFillGradRef.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,    Color3.fromRGB(20,  20,  20)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(90,  90,  90)),
				ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(200, 200, 200)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90,  90,  90)),
				ColorSequenceKeypoint.new(1,    Color3.fromRGB(20,  20,  20)),
			})
		else
			_GH.stealFillGradRef.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,    Color3.fromRGB(10,  30,  90)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(40,  110, 230)),
				ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(150, 210, 255)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(40,  110, 230)),
				ColorSequenceKeypoint.new(1,    Color3.fromRGB(10,  30,  90)),
			})
		end
	end
	-- steal status label gradient: swap ready color on theme change
	if _GH.stealReadyColorFn then pcall(_GH.stealReadyColorFn) end
	if _G_updateThemeUI then _G_updateThemeUI(newName) end
	-- re-color existing float buttons so active-state uses the new C_ON_BG
	if _GH.refreshFloatActiveColors then pcall(_GH.refreshFloatActiveColors) end
	-- player speed billboards live in Workspace (not in _themeAllGuis), update manually
	local psb = _GH.playerSpeedBBs
	if type(psb) == "table" then
		for _, data in pairs(psb) do
			if data.lbl and data.lbl.Parent then
				data.lbl.TextColor3 = C_MOON2
				local g = data.lbl:FindFirstChildOfClass("UIGradient")
				if g then
					g.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0,    C_DEEP4),
						ColorSequenceKeypoint.new(0.25, C_DEEP3),
						ColorSequenceKeypoint.new(0.5,  C_DEEP4),
						ColorSequenceKeypoint.new(0.75, C_DEEP3),
						ColorSequenceKeypoint.new(1,    C_DEEP4),
					})
				end
			end
		end
	end
	-- stun timer billboard (local player) lives in Workspace, update manually
	for _, lbl in ipairs({_GH.speedLblRef, _GH.timerLblRef}) do
		if lbl and lbl.Parent then
			local g = lbl:FindFirstChildOfClass("UIGradient")
			if g then
				if newName == "noir" then
					g.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0,    Color3.fromRGB(60,  60,  60)),
						ColorSequenceKeypoint.new(0.25, Color3.fromRGB(230, 230, 230)),
						ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(140, 140, 140)),
						ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 255)),
						ColorSequenceKeypoint.new(1,    Color3.fromRGB(60,  60,  60)),
					})
				else
					g.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0,    C_DEEP3),
						ColorSequenceKeypoint.new(0.25, C_DEEP4),
						ColorSequenceKeypoint.new(0.5,  C_DEEP3),
						ColorSequenceKeypoint.new(0.75, C_DEEP4),
						ColorSequenceKeypoint.new(1,    C_DEEP3),
					})
				end
			end
		end
	end
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
-- HELPERS
-- ===================================================================
local function addCorner(inst, r)
	local c = Instance.new("UICorner", inst)
	c.CornerRadius = UDim.new(0, r or 8)
	return c
end

local function addStroke(inst, col, th, tr)
	local s = Instance.new("UIStroke", inst)
	s.Color = col; s.Thickness = th or 1; s.Transparency = tr or 0
	return s
end

local function addGradient(inst, c1, c2, rot)
	local g = Instance.new("UIGradient", inst)
	g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,c1), ColorSequenceKeypoint.new(1,c2)})
	g.Rotation = rot or 0
	return g
end

-- ===================================================================
-- LIVING GRADIENTS
-- ===================================================================
local _livingGradients = {}
local _livingStrokes   = {}

local function addLivingTextGradient(label)
	local g = Instance.new("UIGradient", label)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    C_DEEP4),
		ColorSequenceKeypoint.new(0.25, C_DEEP3),
		ColorSequenceKeypoint.new(0.5,  C_DEEP4),
		ColorSequenceKeypoint.new(0.75, C_DEEP3),
		ColorSequenceKeypoint.new(1,    C_DEEP4),
	})
	g.Rotation = 0
	table.insert(_livingGradients, g)
	return g
end

local function addLivingStroke(parent, thickness)
	local stroke = Instance.new("UIStroke", parent)
	stroke.Thickness = thickness or 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = C_DEEP3
	local g = Instance.new("UIGradient", stroke)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    C_DEEP1),
		ColorSequenceKeypoint.new(0.25, C_DEEP2),
		ColorSequenceKeypoint.new(0.5,  C_DEEP1),
		ColorSequenceKeypoint.new(0.75, C_DEEP2),
		ColorSequenceKeypoint.new(1,    C_DEEP1),
	})
	table.insert(_livingStrokes, g)
	return stroke, g
end

local function addGreyShimmer(label)
	local g = Instance.new("UIGradient", label)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(60,  60,  60)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(230, 230, 230)),
		ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(140, 140, 140)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(60,  60,  60)),
	})
	g.Rotation = 0
	table.insert(_livingGradients, g)
	return g
end

local function addGreyStroke(parent, thickness)
	local stroke = Instance.new("UIStroke", parent)
	stroke.Thickness = thickness or 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(100, 100, 100)
	local g = Instance.new("UIGradient", stroke)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(10,  10,  10)),
		ColorSequenceKeypoint.new(0.3,  Color3.fromRGB(220, 220, 220)),
		ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(10,  10,  10)),
		ColorSequenceKeypoint.new(0.7,  Color3.fromRGB(220, 220, 220)),
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(10,  10,  10)),
	})
	table.insert(_livingStrokes, g)
	return stroke, g
end

local _livingRotationSpeed = 0.6
local _purgeCounter = 0
RunService.RenderStepped:Connect(function()
	_purgeCounter = _purgeCounter + 1
	if _purgeCounter >= 300 then
		_purgeCounter = 0
		local alive = {}
		for _, g in ipairs(_livingGradients) do if g and g.Parent then alive[#alive+1]=g end end
		_livingGradients = alive
		local aliveS = {}
		for _, g in ipairs(_livingStrokes) do if g and g.Parent then aliveS[#aliveS+1]=g end end
		_livingStrokes = aliveS
	end
	for _, g in ipairs(_livingGradients) do if g and g.Parent then g.Rotation=(g.Rotation+_livingRotationSpeed)%360 end end
	for _, g in ipairs(_livingStrokes)   do if g and g.Parent then g.Rotation=(g.Rotation+_livingRotationSpeed)%360 end end
end)

-- ===================================================================
-- DESTROY EXISTING
-- ===================================================================
local function destroyAllMoonHub()
	local function sweep(container)
		if not container then return end
		pcall(function()
			for _, inst in ipairs(container:GetChildren()) do
				if inst.Name == _NS and inst:IsA("ScreenGui") then pcall(function() inst:Destroy() end) end
			end
		end)
	end
	sweep(LP:FindFirstChildOfClass("PlayerGui"))
	sweep(game:GetService("CoreGui"))
	pcall(function() if gethui then sweep(gethui()) end end)
end
destroyAllMoonHub()


-- =================================================================
-- GAME LOGIC MODULES (hoisted from _MH_buildUI to reduce local count)
-- =================================================================

local proxy = nil
local function ensureProxy()
	local char = LP.Character; if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
	if proxy and proxy.Parent == char then return proxy end
	if proxy then pcall(function() proxy:Destroy() end) end
	proxy = Instance.new("Part")
	proxy.Name = _NS .. tostring(math.random(10,99))
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

-- [FIX #1 & #6] Séparation des effets de bord : updateCarryState mute State,
-- getCurrentSpeed ne fait que lire (pur). Le guard _carryManualUntil était
-- toujours vrai car tick()-0 > 0 est trivial ; corrigé en tick() >= seuil.
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
	ensureProxy()
end
LP.CharacterAdded:Connect(setupChar)
if LP.Character then setupChar(LP.Character) end

local _speedBoosterActive = false  -- controlled by the Speed Booster widget
RunService.Stepped:Connect(function()
	if not _speedBoosterActive then return end
	if not (h and hrp) then return end
	updateCarryState()  -- [FIX #6] mutation d'état séparée, avant la lecture
	local md = h.MoveDirection
	if md.Magnitude > 0 then proxyMove(md, getCurrentSpeed()) end
end)

-- ===================================================================
-- AUTO STEAL (Auto Grab — logique Irish Hub / test_speed.lua)
-- ===================================================================
local AutoSteal = {
	Enabled=true, Radius=70, IsStealing=false,
	ProgressFill=nil, ProgressText=nil, StatusLabel=nil,
	SetFastPulse=nil, FlashSuccess=nil, Widget=nil,
}


-- ── AUTO GRAB V2 mode (new default) ────────────────────────────
local _KAG_started  = false
local _KAG_conn     = nil
local _KAG_scanTask = nil
local _KAG_Active   = false
local _KAG_Start    = 0
local _KAG_Sync        = { caches={}, connections={} }
local _KAG_AnimalsCache = {}
local _KAG_PromptCache  = {}
local _KAG_StealCache   = {}
local _KAG_SyncRemotes  = nil
local _V2_CFG = { HOLD_MIN=1.3, HOLD_MAX=2.6, ENTRY_DELAY=0.3, COOLDOWN=0.05, STEAL_RANGE=8 }

local function _KAG_splitPath(path)
	if typeof(path)=="table" then return path end
	local out={}
	for part in string.gmatch(tostring(path),"[^%.]+") do table.insert(out, tonumber(part) or part) end
	return out
end
local function _KAG_resolvePath(path, root)
	local cur=root; local par,key=nil,nil
	for _,p in ipairs(_KAG_splitPath(path)) do par=cur; key=p; cur=cur and cur[p] or nil end
	return cur, par, key
end
local function _KAG_applyDiff(cn, packet)
	local cache=_KAG_Sync.caches[cn]; if typeof(cache)~="table" then return end
	local path,action,a,b=packet[1],packet[2],packet[3],packet[4]
	local cur,par,key=_KAG_resolvePath(path,cache)
	if action=="Changed" then if par~=nil then par[key]=a end
	elseif action=="ArrayInsert" then if cur~=nil then table.insert(cur,b,a) end
	elseif action=="ArrayRemoved" then if cur~=nil then table.remove(cur,b) end
	elseif action=="DictionaryInsert" then if cur~=nil then cur[b]=a end
	elseif action=="DictionaryRemoved" then if cur~=nil then cur[b]=nil end end
end
local function _KAG_attachChannel(remote)
	if _KAG_Sync.connections[remote] then return end
	local cn=tostring(remote.Name)
	local plots=workspace:FindFirstChild("Plots"); if not plots or not plots:FindFirstChild(cn) then return end
	if _KAG_SyncRemotes and _KAG_SyncRemotes.requestData and _KAG_Sync.caches[cn]==nil then
		local ok,data=pcall(function() return _KAG_SyncRemotes.requestData:InvokeServer(cn) end)
		_KAG_Sync.caches[cn]=(ok and typeof(data)=="table") and data or {}
	elseif _KAG_Sync.caches[cn]==nil then _KAG_Sync.caches[cn]={} end
	_KAG_Sync.connections[remote]=remote.OnClientEvent:Connect(function(queue)
		for _,packet in ipairs(queue) do _KAG_applyDiff(cn,packet) end
	end)
end
local function _KAG_detachChannel(channelName)
	for remote,conn in pairs(_KAG_Sync.connections) do
		if tostring(remote.Name)==tostring(channelName) then
			conn:Disconnect(); _KAG_Sync.connections[remote]=nil; _KAG_Sync.caches[tostring(channelName)]=nil; break
		end
	end
end
local function _KAG_initSync()
	if _KAG_SyncRemotes then return end
	local RS=game:GetService("ReplicatedStorage")
	local pkg=RS:FindFirstChild("Packages"); if not pkg then return end
	local f=pkg:FindFirstChild("Synchronizer"); if not f then return end
	_KAG_SyncRemotes={
		channelFolder=f:FindFirstChild("Channel"),
		routeRemote  =f:FindFirstChild("CommunicationRoute"),
		requestData  =f:FindFirstChild("RequestData"),
	}
	local cf=_KAG_SyncRemotes.channelFolder; if not cf then return end
	local plots=workspace:FindFirstChild("Plots"); if not plots then return end
	for _,child in ipairs(cf:GetChildren()) do
		if child:IsA("RemoteEvent") then pcall(_KAG_attachChannel,child) end
	end
	cf.ChildAdded:Connect(function(child)
		if child:IsA("RemoteEvent") then task.spawn(function() pcall(_KAG_attachChannel,child) end) end
	end)
	local rr=_KAG_SyncRemotes.routeRemote
	if rr then
		rr.OnClientEvent:Connect(function(actions)
			local pl=workspace:FindFirstChild("Plots"); if not pl then return end
			for _,action in ipairs(actions) do
				local kind,cn=action[1],tostring(action[2])
				if pl:FindFirstChild(cn) then
					if kind=="ListenerAdded" then
						local r=cf:FindFirstChild(cn)
						if r and r:IsA("RemoteEvent") then task.spawn(function() pcall(_KAG_attachChannel,r) end) end
					elseif kind=="ListenerRemoved" then
						_KAG_detachChannel(cn)
					end
				end
			end
		end)
	end
end
local function _KAG_getPlotOwner(plot)
	local sign=plot:FindFirstChild("PlotSign")
	local frame=sign and sign:FindFirstChild("SurfaceGui") and sign.SurfaceGui:FindFirstChild("Frame")
	local label=frame and frame:FindFirstChild("TextLabel")
	if not label or label.Text=="Empty Base" then return nil end
	return label.Text:gsub("'s [Bb]ase$",""):gsub("%s+$","")
end
local function _KAG_isMyAnimal(a)
	if not a or not a.plot then return false end
	local plots=workspace:FindFirstChild("Plots"); if not plots then return false end
	local plot=plots:FindFirstChild(a.plot); if not plot then return false end
	return _KAG_getPlotOwner(plot)==LP.DisplayName
end
local function _KAG_findPrompt(a)
	if not a then return nil end
	local cached=_KAG_PromptCache[a.uid]; if cached and cached.Parent then return cached end
	local plots=workspace:FindFirstChild("Plots"); if not plots then return nil end
	local plot=plots:FindFirstChild(a.plot); if not plot then return nil end
	local pods=plot:FindFirstChild("AnimalPodiums"); if not pods then return nil end
	local pod=pods:FindFirstChild(a.slot); if not pod then return nil end
	local base=pod:FindFirstChild("Base"); if not base then return nil end
	local sp=base:FindFirstChild("Spawn"); if not sp then return nil end
	local att=sp:FindFirstChild("PromptAttachment"); if not att then return nil end
	for _,p in ipairs(att:GetChildren()) do if p:IsA("ProximityPrompt") then _KAG_PromptCache[a.uid]=p; return p end end
	return nil
end
local function _KAG_getPos(a)
	local plots=workspace:FindFirstChild("Plots"); if not plots then return nil end
	local plot=plots:FindFirstChild(a.plot); if not plot then return nil end
	local pods=plot:FindFirstChild("AnimalPodiums"); if not pods then return nil end
	local pod=pods:FindFirstChild(a.slot); if not pod then return nil end
	local ok,pos=pcall(function() return pod:GetPivot().Position end); return ok and pos or nil
end
local function _KAG_distTo(a)
	local char=LP.Character; if not char then return math.huge end
	local hrp=char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso"); if not hrp then return math.huge end
	local pos=_KAG_getPos(a); if not pos then return math.huge end
	return (hrp.Position-pos).Magnitude
end
local function _KAG_pickClosest()
	local char=LP.Character; if not char then return nil end
	local hrp=char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso"); if not hrp then return nil end
	local best,bestDist=nil,math.huge
	local primeRange=AutoSteal.Radius or 80
	for _,a in ipairs(_KAG_AnimalsCache) do
		if not _KAG_isMyAnimal(a) then
			local pos=_KAG_getPos(a)
			if pos then
				local d=(hrp.Position-pos).Magnitude
				if d<=primeRange and d<bestDist then bestDist=d; best=a end
			end
		end
	end
	return best
end
local function _KAG_buildCallbacks(prompt)
	if _KAG_StealCache[prompt] then return end
	local data={hold={},trigger={},ready=true}
	local ok1,c1=pcall(getconnections,prompt.PromptButtonHoldBegan)
	if ok1 and type(c1)=="table" then for _,c in ipairs(c1) do if type(c.Function)=="function" then table.insert(data.hold,c.Function) end end end
	local ok2,c2=pcall(getconnections,prompt.Triggered)
	if ok2 and type(c2)=="table" then for _,c in ipairs(c2) do if type(c.Function)=="function" then table.insert(data.trigger,c.Function) end end end
	if #data.hold>0 or #data.trigger>0 then _KAG_StealCache[prompt]=data end
end
local function _KAG_executeSteal(prompt, a)
	local data=_KAG_StealCache[prompt]; if not data or not data.ready then return false end
	data.ready=false; _KAG_Active=true; State.isStealing=true
	_KAG_Start=tick()
	-- UNREADY immediately at steal start (test_speed.lua exact)
	if AutoSteal.StatusLabel then AutoSteal.StatusLabel.Text="UNREADY" end
	if AutoSteal.SetReadyColor then AutoSteal.SetReadyColor("UNREADY") end
	task.spawn(function()
		for _,fn in ipairs(data.hold) do task.spawn(fn) end
		-- Progress loop (test_speed.lua exact)
		task.spawn(function()
			local _readyShown=false
			while _KAG_Active do
				local prog=math.clamp((tick()-_KAG_Start)/_V2_CFG.HOLD_MAX,0,1)
				if AutoSteal.ProgressFill then AutoSteal.ProgressFill.Size=UDim2.new(prog,0,1,0) end
				if AutoSteal.ProgressText then AutoSteal.ProgressText.Text=math.floor(prog*100).."%" end
				if prog>=0.6 and not _readyShown then
					_readyShown=true
					if AutoSteal.StatusLabel then AutoSteal.StatusLabel.Text="READY" end
					if AutoSteal.SetReadyColor then AutoSteal.SetReadyColor("READY") end
				end
				task.wait()
			end
		end)
		task.wait(_V2_CFG.HOLD_MIN)
		local alreadyClose=_KAG_distTo(a)<=_V2_CFG.STEAL_RANGE
		local fired=false
		while true do
			if tick()-_KAG_Start>_V2_CFG.HOLD_MAX then break end
			if not prompt.Parent then break end
			if _KAG_distTo(a)<=_V2_CFG.STEAL_RANGE then
				if not alreadyClose then task.wait(_V2_CFG.ENTRY_DELAY) end
				for _,fn in ipairs(data.trigger) do task.spawn(fn) end
				fired=true; break
			end
			task.wait()
		end
		_KAG_Active=false; State.isStealing=false
		if AutoSteal.ProgressFill then AutoSteal.ProgressFill.Size=UDim2.new(0,0,1,0) end
		if AutoSteal.ProgressText then AutoSteal.ProgressText.Text="" end
		if AutoSteal.StatusLabel then AutoSteal.StatusLabel.Text="READY" end
		if AutoSteal.SetReadyColor then AutoSteal.SetReadyColor("READY") end
		if fired and AutoSteal.FlashSuccess then AutoSteal.FlashSuccess() end
		task.wait(_V2_CFG.COOLDOWN); data.ready=true
	end)
	return true
end
local function _KAG_attemptSteal(prompt, a)
	if not prompt or not prompt.Parent then return false end
	_KAG_buildCallbacks(prompt)
	if not _KAG_StealCache[prompt] then return false end
	return _KAG_executeSteal(prompt, a)
end
local function _KAG_scanPlots()
	local newCache={}
	local RS=game:GetService("ReplicatedStorage")
	local datas=RS:FindFirstChild("Datas")
	local animData=nil
	if datas then pcall(function() local m=datas:FindFirstChild("Animals"); if m then animData=require(m) end end) end
	local plots=workspace:FindFirstChild("Plots"); if not plots then _KAG_AnimalsCache=newCache; return end
	for _,plot in ipairs(plots:GetChildren()) do
		local cache=_KAG_Sync.caches[plot.Name]
		if cache and typeof(cache)=="table" then
			local list=cache.AnimalList
			if typeof(list)=="table" then
				for slot,ad in pairs(list) do
					if type(ad)=="table" then
						local name=ad.Index
						local info=animData and animData[name]
						if info or not animData then
							table.insert(newCache,{
								name=(info and info.DisplayName) or name,
								plot=plot.Name, slot=tostring(slot),
								uid=plot.Name.."_"..tostring(slot),
							})
						end
					end
				end
			end
		end
	end
	_KAG_AnimalsCache=newCache
end

local function startAutoStealV2()
	if _KAG_started then return end
	_KAG_started=true
	_KAG_initSync()
	task.spawn(function() pcall(_KAG_scanPlots) end)
	_KAG_scanTask=task.spawn(function()
		while _KAG_started do task.wait(5); pcall(_KAG_scanPlots) end
	end)
	local _kState="READY"
	_KAG_conn=RunService.Heartbeat:Connect(function()
		if not AutoSteal.Enabled or _KAG_Active then return end
		local target=_KAG_pickClosest()
		local newState=target and "UNREADY" or "READY"
		if _kState~=newState then
			_kState=newState
			if AutoSteal.StatusLabel then AutoSteal.StatusLabel.Text=newState end
			if AutoSteal.SetReadyColor then AutoSteal.SetReadyColor(newState) end
		end
		if not target then return end
		local prompt=_KAG_PromptCache[target.uid]
		if not prompt or not prompt.Parent then prompt=_KAG_findPrompt(target) end
		if prompt then _KAG_attemptSteal(prompt,target) end
	end)
end
local function stopAutoStealV2()
	_KAG_started=false
	if _KAG_conn then _KAG_conn:Disconnect(); _KAG_conn=nil end
	if _KAG_scanTask then pcall(task.cancel,_KAG_scanTask); _KAG_scanTask=nil end
	_KAG_Active=false; State.isStealing=false
	if AutoSteal.StatusLabel then AutoSteal.StatusLabel.Text="READY" end
end

local function startAutoSteal() startAutoStealV2() end
local function stopAutoSteal()  stopAutoStealV2()  end



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
	pcall(function() if sethiddenproperty then sethiddenproperty(root,"PhysicsRepRootPart",root) end end)
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
				pcall(function() if sethiddenproperty then sethiddenproperty(r,"PhysicsRepRootPart",r) end end)
			end
			_dropActive = false
			return
		end
		-- Fast ascent phase
		r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, DROP_ASCEND_SPEED, r.AssemblyLinearVelocity.Z)
	end)
end

-- ===================================================================
-- AUTO LEFT / RIGHT  (logique Taser Hub — 2 phases + orientation finale)
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
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		local spd = State.normalSpeed
		if alPhase == 1 then
			if (Vector3.new(AP_L1.X, hrp.Position.Y, AP_L1.Z) - hrp.Position).Magnitude < 1 then
				alPhase = 2
			end
			local d = AP_L1 - hrp.Position
			proxyMove(Vector3.new(d.X, 0, d.Z).Unit, spd)
		elseif alPhase == 2 then
			if (Vector3.new(AP_L2.X, hrp.Position.Y, AP_L2.Z) - hrp.Position).Magnitude < 1 then
				proxyStop(); State.autoLeftEnabled = false
				if alConn then alConn:Disconnect(); alConn = nil end
				alPhase = 1
				hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(AP_L_FACE.X, hrp.Position.Y, AP_L_FACE.Z))
				pcall(function() if sethiddenproperty then sethiddenproperty(hrp,"PhysicsRepRootPart",hrp) end end)
				return
			end
			local d = AP_L2 - hrp.Position
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
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		local spd = State.normalSpeed
		if arPhase == 1 then
			if (Vector3.new(AP_R1.X, hrp.Position.Y, AP_R1.Z) - hrp.Position).Magnitude < 1 then
				arPhase = 2
			end
			local d = AP_R1 - hrp.Position
			proxyMove(Vector3.new(d.X, 0, d.Z).Unit, spd)
		elseif arPhase == 2 then
			if (Vector3.new(AP_R2.X, hrp.Position.Y, AP_R2.Z) - hrp.Position).Magnitude < 1 then
				proxyStop(); State.autoRightEnabled = false
				if arConn then arConn:Disconnect(); arConn = nil end
				arPhase = 1
				hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(AP_R_FACE.X, hrp.Position.Y, AP_R_FACE.Z))
				pcall(function() if sethiddenproperty then sethiddenproperty(hrp,"PhysicsRepRootPart",hrp) end end)
				return
			end
			local d = AP_R2 - hrp.Position
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
		task.wait(0.5)               -- laisser le character se charger
		startUnwalk()
	end
end)

-- ===================================================================
-- AUTO CARRY ON GRAB
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
-- OPTIMIZE MODULE
-- ===================================================================
local NukeOpt = {active=false, conns={}, threads={}}
local function nukeOptStart()
	if NukeOpt.active then return end; NukeOpt.active=true
	-- [FIX Perf #1] Lookup O(1) par ClassName au lieu de O(12) par itération de liste.
	-- Ces types n'ont pas de sous-classes Roblox, donc ClassName est équivalent à IsA.
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

-- ===================================================================
-- MEDUSA COUNTER (raw__59_ logic)
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

-- AUTO RESET ON MEDUSA — détecte le stun (Anchored + Transparency==1) et fire l'insta reset
local _armState = {enabled=false, conns={}, triggered=false, lastFire=0, cooldown=2.25}

local function _armShouldFire(part)
	if not _armState.enabled then return false end
	if _armState.triggered then return false end
	if tick() - _armState.lastFire < _armState.cooldown then return false end
	if not part or not part.Parent then return false end
	if part:FindFirstAncestorOfClass("Tool") or part:FindFirstAncestorOfClass("Accessory") then return false end
	return part.Anchored and part.Transparency == 1
end

local function _armFireOnce(part)
	if not _armShouldFire(part) then return end
	_armState.triggered = true
	_armState.lastFire = tick()
	task.delay(2.3, function()
		if _armState.enabled and _GH.MH_instareset then
			_GH.MH_instareset()
		end
	end)
end

local function _armStop()
	for _, c in ipairs(_armState.conns) do pcall(function() c:Disconnect() end) end
	_armState.conns = {}
	_armState.triggered = false
end

local function _armStart(char)
	_armStop()
	char = char or LP.Character; if not char then return end
	local function watchPart(p)
		table.insert(_armState.conns, p:GetPropertyChangedSignal("Anchored"):Connect(function()
			_armFireOnce(p)
		end))
		_armFireOnce(p)
	end
	for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then watchPart(p) end end
	table.insert(_armState.conns, char.DescendantAdded:Connect(function(p)
		if p:IsA("BasePart") then watchPart(p) end
	end))
	table.insert(_armState.conns, char.AncestryChanged:Connect(function(_, parent)
		if not parent then _armState.triggered = false end
	end))
end

LP.CharacterAdded:Connect(function(char)
	if State.autoResetOnMedEnabled then task.wait(0.5); _armStart(char) end
end)


-- ANTI BAT (Envy logic — 1000 spike + XZ restore)
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
	-- randomized CD: 280-480ms — realistic human swing variance
	task.delay(math.random(280,480)/1000, function() AB_HIT_CD=false end)
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

	-- Aimbot (velocity lerp toward target)
local AB = {active=false, conn=nil, SPEED=AB_SPEED, HEIGHT=3.7}
local _abEquipLast = 0
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
		local now=tick()
		if not char:FindFirstChildOfClass("Tool") and now-_abEquipLast>2 then
			local bat=getBat(); if bat then pcall(function() hum:EquipTool(bat) end) end
			_abEquipLast=now
		end
		local target,dist=getClosestPlayerAim()
		if not target or not target.Character then return end
		local tr=target.Character:FindFirstChild("HumanoidRootPart"); if not tr then return end
		pcall(function() if sethiddenproperty then sethiddenproperty(root,"PhysicsRepRootPart",tr) end end)
		local targetVel=tr.AssemblyLinearVelocity
		local myPos=root.Position; local targetPos=tr.Position
		local predictPos=targetPos+targetVel*0.14+tr.CFrame.LookVector*0.3
		local direction=predictPos-myPos; local flatDir=Vector3.new(direction.X,0,direction.Z).Unit
		local desiredHeight=targetPos.Y+AB.HEIGHT
		local yVel=(desiredHeight-myPos.Y)*14+targetVel.Y*0.6
		if hum.FloorMaterial~=Enum.Material.Air then yVel=math.max(yVel,12) end
		yVel=math.clamp(yVel,-50,62)
		local desiredVel=Vector3.new(flatDir.X*AB.SPEED,yVel,flatDir.Z*AB.SPEED)
		root.AssemblyLinearVelocity=root.AssemblyLinearVelocity:Lerp(desiredVel,0.28)
		local speed3=targetVel.Magnitude; local predictTime=math.clamp(speed3/150,0.05,0.2)
		local predictedPos=targetPos+targetVel*predictTime; local toPredict=predictedPos-myPos
		if toPredict.Magnitude>0.1 then
			local goalCF=CFrame.lookAt(myPos,predictedPos); local diffCF=root.CFrame:Inverse()*goalCF
			local rx,ry,rz=diffCF:ToEulerAnglesXYZ()
			rx=math.clamp(rx,-2.5,2.5); ry=math.clamp(ry,-2.5,2.5); rz=math.clamp(rz,-2.5,2.5)
			root.AssemblyAngularVelocity=root.CFrame:VectorToWorldSpace(Vector3.new(rx*18,ry*18,rz*18))
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

-- ===================================================================
-- AIM V3 (anti-desync + enemy TP + strike)
local AimV3 = {active=false, conn=nil}
local _av3HitCD  = false
local _av3LastTP = 0
local _av3TP_CD  = 0.12 -- max ~8 TPs/s instead of 60

local function _av3GetBat()
	local char=LP.Character; if not char then return nil end
	-- Looks for "Bat" only, like in aimv3.txt (simple getBat)
	local tool=char:FindFirstChild("Bat"); if tool then return tool end
	local bp=LP:FindFirstChildOfClass("Backpack")
	if bp then tool=bp:FindFirstChild("Bat"); if tool then tool.Parent=char; return tool end end
	-- Fallback to all bat-type tools (BAT_NAMES already includes "Bat")
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
	end)
	-- randomized cooldown (200-350ms) — realistic human swing rate
	task.delay(math.random(200, 350) / 1000, function() _av3HitCD=false end)
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
			-- small random offset so TP destination is never machine-perfect
			local jx=math.random(-12,12)/10
			local jz=math.random(-12,12)/10
			local targetPos=tr.Position+Vector3.new(jx,0.9,jz)
			local now=tick()
			if (root.Position-targetPos).Magnitude>8 and now-_av3LastTP>=_av3TP_CD then
				root.CFrame=CFrame.new(targetPos)
				_av3LastTP=now
			end
			local cam=workspace.CurrentCamera
			-- slight aim jitter so camera movement looks human
			local aimJitter=Vector3.new(math.random(-3,3)/10,math.random(-2,2)/10,0)
			cam.CFrame=CFrame.new(cam.CFrame.Position,tr.Position+aimJitter)
			_av3Hit()
		end)
	end)
end
function AimV3.stop()
	if AimV3.conn then AimV3.conn:Disconnect(); AimV3.conn=nil end; AimV3.active=false
end

-- Aim V2 (v1-3 — velocity directe vers la face de la cible, marche contre anti-bat)
local FACE_OFFSET = 2
local ABP = {active=false, conn=nil}
function ABP.start()
	if ABP.conn then ABP.conn:Disconnect() end; ABP.active=true
	ABP.conn=RunService.Heartbeat:Connect(function()
		if not ABP.active then return end
		local char=LP.Character; if not char then return end
		local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
		local target,dist=getClosestPlayerAim()
		if target and target.Character then
			local tr=target.Character:FindFirstChild("HumanoidRootPart"); if not tr then return end
			pcall(function() if sethiddenproperty then sethiddenproperty(root,"PhysicsRepRootPart",tr) end end)
			local head=target.Character:FindFirstChild("Head")
			local basePos=head and head.Position or tr.Position
			local aimPoint=basePos+tr.CFrame.LookVector*FACE_OFFSET
			local direction=(aimPoint-root.Position).Unit
			root.AssemblyLinearVelocity=direction*AB.SPEED
			if dist<=VYSE_HIT_DIST then tryHitBat() end
		else root.AssemblyLinearVelocity=Vector3.new(0,root.AssemblyLinearVelocity.Y,0) end
	end)
end
function ABP.stop()
	if ABP.conn then ABP.conn:Disconnect(); ABP.conn=nil end; ABP.active=false; AB_HIT_CD=false
	local char=LP.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
	if root then root.AssemblyLinearVelocity=Vector3.new(0,root.AssemblyLinearVelocity.Y,0) end
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
-- BUILD PAGES
-- ===================================================================
local applyAntiBatState

	-- Bat Counter — source bat_counter.txt (RemoteEvent support + "bat" keyword fallback)
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
	pcall(function() bat:Activate() end)
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
				task.wait(0.35 + math.random()*0.30); _bcDebounce=false
			end)
		end
	end)
end
function BatCounter.stop()
	if BatCounter.conn then BatCounter.conn:Disconnect(); BatCounter.conn=nil end
	_bcDebounce=false
end

-- ===================================================================
-- ANTI-KICK (source: Anti_kick_source_works.txt — fixed recursive spawn
--            + deprecated wait() + MoveVector → MoveDirection)
-- ===================================================================
local _akActive      = false
local _akOldNamecall = nil
local _akMt          = nil
local _akPosConn     = nil
local _akDeathConn   = nil
local _akHealthConn  = nil  -- HealthChanged event (restore immédiat)
local _akMaxHpConn   = nil  -- MaxHealth signal (reset seulement si changé)
local _akLastSafe    = nil
local _akRemoteConns = {}   -- connections from blockRemoteKicks
local _akCharOldNI   = nil  -- saved __newindex for blockCharacterDestruction restore
local _akCharMtRef   = nil  -- character metatable ref
local _akLoopActive    = false -- controls workspace/maxHealth while loops
local _akCharAddedConn = nil   -- re-hook humanoid + char protections après respawn
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
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then _akLastSafe = hrp.CFrame end
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
		local RS = game:GetService("ReplicatedStorage")
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
task.spawn(function() pcall(startAntiKick) end)

-- ===================================================================
-- SHINY GRAPHICS (client-side lighting only — no UI toggle)
-- ===================================================================
pcall(function()
	for _, obj in ipairs(Lighting:GetChildren()) do
		if obj:IsA("Sky") then obj:Destroy() end
		if obj:IsA("BloomEffect") or obj:IsA("ColorCorrectionEffect") then obj:Destroy() end
	end
	local sky = Instance.new("Sky")
	sky.SkyboxBk = "rbxassetid://1534951537"; sky.SkyboxDn = "rbxassetid://1534951537"
	sky.SkyboxFt = "rbxassetid://1534951537"; sky.SkyboxLf = "rbxassetid://1534951537"
	sky.SkyboxRt = "rbxassetid://1534951537"; sky.SkyboxUp = "rbxassetid://1534951537"
	sky.StarCount = 10000; sky.CelestialBodiesShown = false; sky.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 1.5; bloom.Size = 40; bloom.Threshold = 0.8; bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.8; cc.Contrast = 0.3; cc.TintColor = Color3.fromRGB(200,200,200); cc.Parent = Lighting
	Lighting.Brightness = 3; Lighting.ClockTime = 0
	RunService.Heartbeat:Connect(function()
		local t = tick() * 0.5
		Lighting.Ambient = Color3.fromRGB(
			100 + math.floor(math.sin(t) * 30),
			100 + math.floor(math.sin(t * 0.8) * 30),
			110 + math.floor(math.sin(t * 1.2) * 30)
		)
		bloom.Intensity = 1.2 + math.sin(t * 2) * 0.4
	end)
end)

local _MH_buildUI
_MH_buildUI = function()
local gui = Instance.new("ScreenGui")
gui.Name = _NS; gui.ResetOnSpawn = false; gui.DisplayOrder = 10
gui.IgnoreGuiInset = true; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
table.insert(_themeAllGuis, gui)
pcall(function()
	if syn and syn.protect_gui then syn.protect_gui(gui) end
	if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
	gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end

-- ===================================================================
-- INTRO CUTSCENE — crescent moon reveal, orbit ring, cinematic zoom (~4.2s)
-- ===================================================================
do
	local introGui = Instance.new("Frame", gui)
	introGui.Name = tostring(math.random(0x10000, 0xFFFFFF))
	introGui.Size = UDim2.new(1,0,1,0)
	introGui.BackgroundColor3 = Color3.fromRGB(2,3,7)
	introGui.BackgroundTransparency = 0
	introGui.ZIndex = 1200
	introGui.BorderSizePixel = 0
	introGui.ClipsDescendants = true
	-- Subtle depth gradient instead of flat black
	addGradient(introGui, Color3.fromRGB(6,10,20), Color3.fromRGB(0,0,0), 90)

	-- Vignette: soft dark edges to frame the scene, done as 4 gradient strips
	do
		local function edgeVignette(size, pos, rot)
			local edge = Instance.new("Frame", introGui)
			edge.Size = size
			edge.Position = pos
			edge.BackgroundColor3 = Color3.new(0,0,0)
			edge.BorderSizePixel = 0
			edge.ZIndex = 30
			local g = Instance.new("UIGradient", edge)
			g.Rotation = rot
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
		edgeVignette(UDim2.new(1,0,0,90), UDim2.new(0,0,0,0), 90)
		edgeVignette(UDim2.new(1,0,0,90), UDim2.new(0,0,1,-90), 270)
		edgeVignette(UDim2.new(0,140,1,0), UDim2.new(0,0,0,0), 0)
		edgeVignette(UDim2.new(0,140,1,0), UDim2.new(1,-140,0,0), 180)
	end

	-- Everything scales together for a cinematic zoom-in on load
	local sceneScale = Instance.new("UIScale", introGui)
	sceneScale.Scale = 1.12

	-- Skip button — top-right, theme-coloured
	local _skipDone = false
	local function doSkip()
		if _skipDone then return end
		_skipDone = true
		TweenService:Create(introGui, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{BackgroundTransparency = 1}):Play()
		task.delay(0.28, function() pcall(function() introGui:Destroy() end) end)
	end
	do
		local skipBtn = Instance.new("TextButton", introGui)
		skipBtn.AnchorPoint  = Vector2.new(1, 0)
		skipBtn.Position     = UDim2.new(1, -14, 0, 14)
		skipBtn.Size         = UDim2.new(0, 72, 0, 26)
		skipBtn.ZIndex       = 1300
		skipBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		skipBtn.BackgroundTransparency = 0.45
		skipBtn.BorderSizePixel = 0
		skipBtn.Text         = "Skip  ›"
		skipBtn.TextColor3   = C_WHITE
		skipBtn.Font         = Enum.Font.GothamBlack
		skipBtn.TextSize     = 13
		skipBtn.AutoButtonColor = false
		Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 6)
		addLivingTextGradient(skipBtn)
		addLivingStroke(skipBtn, 1)
		skipBtn.MouseButton1Click:Connect(doSkip)
	end

	-- Rising particles
	task.spawn(function()
		while introGui.Parent do
			task.wait(math.random(6,16)/100)
			pcall(function()
				local size = math.random(2,5)
				local particle = Instance.new("Frame", introGui)
				particle.Size = UDim2.new(0,size,0,size)
				particle.Position = UDim2.new(math.random(15,85)/100, 0, 1, 10)
				particle.BackgroundColor3 = math.random()<0.3 and Color3.fromRGB(200,225,255) or C_MOON
				particle.BackgroundTransparency = math.random(30,60)/100
				particle.BorderSizePixel = 0
				particle.ZIndex = 50
				Instance.new("UICorner", particle).CornerRadius = UDim.new(1,0)
				local dur = math.random(25,45)/10
				TweenService:Create(particle, TweenInfo.new(dur, Enum.EasingStyle.Linear),
					{Position = UDim2.new(particle.Position.X.Scale, 0, 0, -10), BackgroundTransparency = 1}):Play()
				task.delay(dur+0.1, function() pcall(function() particle:Destroy() end) end)
			end)
		end
	end)

	-- A few large soft drifting orbs for background depth
	for i = 1, 3 do
		local orb = Instance.new("Frame", introGui)
		orb.Size = UDim2.new(0, math.random(90,150), 0, math.random(90,150))
		orb.Position = UDim2.new(math.random(0,100)/100, 0, math.random(0,100)/100, 0)
		orb.BackgroundColor3 = C_MOON
		orb.BackgroundTransparency = 0.96
		orb.BorderSizePixel = 0
		orb.ZIndex = 10
		addCorner(orb, 200)
		task.spawn(function()
			while orb.Parent do
				TweenService:Create(orb, TweenInfo.new(math.random(30,45)/10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{Position = UDim2.new(math.random(0,100)/100, 0, math.random(0,100)/100, 0)}):Play()
				task.wait(math.random(30,45)/10)
			end
		end)
	end

	-- Shooting star — a bright streak with a fading trail crossing the sky
	local function fireShootingStar()
		local startX = math.random(5,30)/100
		local startY = math.random(5,25)/100
		local endX = startX + math.random(35,55)/100
		local endY = startY + math.random(20,35)/100
		local trail = Instance.new("Frame", introGui)
		trail.AnchorPoint = Vector2.new(0.5,0.5)
		trail.Size = UDim2.new(0,60,0,2)
		trail.Position = UDim2.new(startX,0,startY,0)
		trail.Rotation = math.deg(math.atan2(endY-startY, endX-startX))
		trail.BackgroundColor3 = C_WHITE
		trail.BorderSizePixel = 0
		trail.BackgroundTransparency = 1
		trail.ZIndex = 40
		local g = Instance.new("UIGradient", trail)
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0,   1),
			NumberSequenceKeypoint.new(0.85,0.4),
			NumberSequenceKeypoint.new(1,   1),
		})
		TweenService:Create(trail, TweenInfo.new(0.12), {BackgroundTransparency = 0.15}):Play()
		TweenService:Create(trail, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = UDim2.new(endX,0,endY,0),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.6, function() pcall(function() trail:Destroy() end) end)
	end

	-- Shockwave ring — expands outward and fades when the moon bursts in
	local function fireShockwave()
		local ring = Instance.new("Frame", introGui)
		ring.AnchorPoint = Vector2.new(0.5,0.5)
		ring.Position = UDim2.new(0.5,0,0.42,0)
		ring.Size = UDim2.new(0,8,0,8)
		ring.BackgroundTransparency = 1
		ring.ZIndex = 498
		addCorner(ring, 200)
		local stroke = addStroke(ring, C_MOON, 2, 0)
		TweenService:Create(ring, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = UDim2.new(0,280,0,280)}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Transparency = 1}):Play()
		task.delay(0.8, function() pcall(function() ring:Destroy() end) end)
	end

	-- Lueur ambiante lunaire — sphère radiale bleue derrière la lune
	do
		local glowPos = UDim2.new(0.5,0,0.42,0)
		for _, spec in ipairs({{240,0.910},{165,0.930},{95,0.905}}) do
			local g = Instance.new("Frame", introGui)
			g.AnchorPoint = Vector2.new(0.5,0.5)
			g.Position = glowPos
			g.Size = UDim2.new(0,spec[1],0,spec[1])
			g.BackgroundColor3 = Color3.fromRGB(90,170,235)
			g.BackgroundTransparency = spec[2]
			g.BorderSizePixel = 0
			g.ZIndex = 4
			addCorner(g, 200)
		end
	end

	-- Crescent moon icon: bright disc with an offset dark disc cut into it,
	-- plus a slow-rotating orbit ring — replaces the plain dot from before.
	local moonWrap = Instance.new("Frame", introGui)
	moonWrap.AnchorPoint = Vector2.new(0.5,0.5)
	moonWrap.Position = UDim2.new(0.5,0,0.42,0)
	moonWrap.Size = UDim2.new(0,0,0,0)
	moonWrap.BackgroundTransparency = 1
	moonWrap.ZIndex = 501

	local orbitRing = Instance.new("Frame", moonWrap)
	orbitRing.AnchorPoint = Vector2.new(0.5,0.5)
	orbitRing.Position = UDim2.new(0.5,0,0.5,0)
	orbitRing.Size = UDim2.new(2.3,0,0.85,0)   -- ellipse large
	orbitRing.BackgroundTransparency = 1
	orbitRing.Rotation = 0
	orbitRing.ZIndex = 500
	addCorner(orbitRing, 200)
	local orbitStroke, orbitGrad = addLivingStroke(orbitRing, 1)
	orbitStroke.Transparency = 0.62
	local orbitDot = Instance.new("Frame", orbitRing)
	orbitDot.AnchorPoint = Vector2.new(0.5,0.5)
	orbitDot.Position = UDim2.new(0.5,0,0,-2)  -- top of ellipse
	orbitDot.Size = UDim2.new(0,4,0,4)
	orbitDot.BackgroundColor3 = C_MOON2
	orbitDot.BorderSizePixel = 0
	orbitDot.ZIndex = 500
	addCorner(orbitDot, 2)
	local orbitDotGlow = addStroke(orbitDot, C_MOON, 3, 0.4)
	task.spawn(function()
		while orbitRing.Parent do
			orbitRing.Rotation = (orbitRing.Rotation + 3) % 360
			task.wait()
		end
	end)

	-- Soft moonlight halo behind the crescent
	local moonHalo = Instance.new("Frame", moonWrap)
	moonHalo.AnchorPoint = Vector2.new(0.5,0.5)
	moonHalo.Position = UDim2.new(0.5,0,0.5,0)
	moonHalo.Size = UDim2.new(1,0,1,0)
	moonHalo.BackgroundColor3 = C_MOON
	moonHalo.BackgroundTransparency = 0.55
	moonHalo.BorderSizePixel = 0
	moonHalo.ZIndex = 500
	addCorner(moonHalo, 200)
	task.spawn(function()
		while moonHalo.Parent do
			TweenService:Create(moonHalo, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Size = UDim2.new(1.35,0,1.35,0), BackgroundTransparency = 0.75}):Play()
			task.wait(1.4)
			TweenService:Create(moonHalo, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Size = UDim2.new(1,0,1,0), BackgroundTransparency = 0.55}):Play()
			task.wait(1.4)
		end
	end)

	-- Outer second halo — slower, wider pulse
	local moonHalo2 = Instance.new("Frame", moonWrap)
	moonHalo2.AnchorPoint = Vector2.new(0.5,0.5)
	moonHalo2.Position = UDim2.new(0.5,0,0.5,0)
	moonHalo2.Size = UDim2.new(1.6,0,1.6,0)
	moonHalo2.BackgroundColor3 = Color3.fromRGB(90,170,235)
	moonHalo2.BackgroundTransparency = 0.84
	moonHalo2.BorderSizePixel = 0
	moonHalo2.ZIndex = 499
	addCorner(moonHalo2, 200)
	task.spawn(function()
		while moonHalo2.Parent do
			TweenService:Create(moonHalo2, TweenInfo.new(2.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Size = UDim2.new(2.0,0,2.0,0), BackgroundTransparency = 0.93}):Play()
			task.wait(2.1)
			TweenService:Create(moonHalo2, TweenInfo.new(2.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Size = UDim2.new(1.6,0,1.6,0), BackgroundTransparency = 0.84}):Play()
			task.wait(2.1)
		end
	end)

	local moonBase = Instance.new("Frame", moonWrap)
	moonBase.AnchorPoint = Vector2.new(0.5,0.5)
	moonBase.Position = UDim2.new(0.5,0,0.5,0)
	moonBase.Size = UDim2.new(1,0,1,0)
	moonBase.BackgroundColor3 = C_MOON
	moonBase.BorderSizePixel = 0
	moonBase.ZIndex = 501
	addCorner(moonBase, 200)

	-- Small craters for surface texture
	local craterSpots = {{0.32,0.38,0.16},{0.6,0.28,0.11},{0.42,0.6,0.13}}
	for _, c in ipairs(craterSpots) do
		local crater = Instance.new("Frame", moonBase)
		crater.AnchorPoint = Vector2.new(0.5,0.5)
		crater.Position = UDim2.new(c[1],0,c[2],0)
		crater.Size = UDim2.new(c[3],0,c[3],0)
		crater.BackgroundColor3 = C_MOON2
		crater.BackgroundTransparency = 0.35
		crater.BorderSizePixel = 0
		crater.ZIndex = 501
		addCorner(crater, 200)
	end

	local moonBite = Instance.new("Frame", moonWrap)
	moonBite.AnchorPoint = Vector2.new(0.5,0.5)
	moonBite.Position = UDim2.new(0.62,0,0.38,0)
	moonBite.Size = UDim2.new(0.86,0,0.86,0)
	moonBite.BackgroundColor3 = Color3.fromRGB(2,3,7)
	moonBite.BorderSizePixel = 0
	moonBite.ZIndex = 502
	addCorner(moonBite, 200)

	local nameLbl = Instance.new("TextLabel", introGui)
	nameLbl.AnchorPoint = Vector2.new(0.5,0.5)
	nameLbl.Position = UDim2.new(0.5,0,0.54,0)
	nameLbl.Size = UDim2.new(1,-40,0,50)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = "MOON HUB"
	nameLbl.TextColor3 = C_WHITE
	nameLbl.Font = Enum.Font.GothamBlack
	nameLbl.TextSize = 46
	nameLbl.TextTransparency = 1
	nameLbl.ZIndex = 502
	local nameGrad = addLivingTextGradient(nameLbl)

	local subLbl = Instance.new("TextLabel", introGui)
	subLbl.AnchorPoint = Vector2.new(0.5,0.5)
	subLbl.Position = UDim2.new(0.5,0,0.635,0)
	subLbl.Size = UDim2.new(1,-40,0,24)
	subLbl.BackgroundTransparency = 1
	subLbl.Text = "YSLEM  ×  ALN"
	subLbl.TextColor3 = C_DIM
	subLbl.Font = Enum.Font.GothamBold
	subLbl.TextSize = 20
	subLbl.TextTransparency = 1
	subLbl.ZIndex = 502
	addLivingTextGradient(subLbl)

	-- Divider line that draws itself under the subtitle
	local divWrap = Instance.new("Frame", introGui)
	divWrap.AnchorPoint = Vector2.new(0.5,0.5)
	divWrap.Position = UDim2.new(0.5,0,0.685,0)
	divWrap.Size = UDim2.new(0,0,0,1)
	divWrap.BackgroundColor3 = C_MOON
	divWrap.BackgroundTransparency = 0.3
	divWrap.BorderSizePixel = 0
	divWrap.ZIndex = 502

	local verLbl = Instance.new("TextLabel", introGui)
	verLbl.AnchorPoint = Vector2.new(0.5,0.5)
	verLbl.Position = UDim2.new(0.5,0,0.72,0)
	verLbl.Size = UDim2.new(1,-40,0,14)
	verLbl.BackgroundTransparency = 1
	verLbl.Text = "V3"
	verLbl.TextColor3 = C_SILVER2
	verLbl.Font = Enum.Font.Gotham
	verLbl.TextSize = 10
	verLbl.TextTransparency = 1
	verLbl.ZIndex = 502

	-- Champ d'étoiles — 100 étoiles scintillantes (argenté/blanc/bleu)
	local starColors = {C_WHITE, Color3.fromRGB(200,225,255), Color3.fromRGB(180,210,255), Color3.fromRGB(220,235,255)}
	for i = 1, 100 do
		local tw = Instance.new("Frame", introGui)
		local sz = math.random()<0.12 and 2 or 1
		tw.Size = UDim2.new(0,sz,0,sz)
		tw.Position = UDim2.new(math.random(0,100)/100, 0, math.random(0,100)/100, 0)
		tw.BackgroundColor3 = starColors[math.random(1,#starColors)]
		tw.BackgroundTransparency = 1
		tw.BorderSizePixel = 0
		tw.ZIndex = 20
		addCorner(tw, 2)
		task.spawn(function()
			task.wait(math.random(0,30)/10)
			while tw.Parent do
				local peak = math.random(15,60)/100
				local dur = math.random(8,22)/10
				TweenService:Create(tw, TweenInfo.new(dur/2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{BackgroundTransparency = peak}):Play()
				task.wait(dur/2)
				if not tw.Parent then break end
				TweenService:Create(tw, TweenInfo.new(dur/2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{BackgroundTransparency = 1}):Play()
				task.wait(dur/2)
			end
		end)
	end

	-- Star burst finale: a center star plus small sparkles flung outward
	local star = Instance.new("TextLabel", introGui)
	star.AnchorPoint = Vector2.new(0.5,0.5)
	star.Position = UDim2.new(0.5,0,0.8,0)
	star.Size = UDim2.new(0,0,0,0)
	star.BackgroundTransparency = 1
	star.Text = "★"
	star.TextColor3 = C_MOON2
	star.Font = Enum.Font.GothamBold
	star.TextSize = 22
	star.TextTransparency = 1
	star.ZIndex = 502
	addLivingTextGradient(star)

	local function fireStarBurst()
		for i = 1, 10 do
			local ang = (i / 10) * math.pi * 2
			local dist = math.random(55, 100)
			local spark = Instance.new("TextLabel", introGui)
			spark.AnchorPoint = Vector2.new(0.5,0.5)
			spark.Position = UDim2.new(0.5,0,0.8,0)
			spark.Size = UDim2.new(0,14,0,14)
			spark.BackgroundTransparency = 1
			spark.Text = "★"
			spark.TextColor3 = C_MOON2
			spark.Font = Enum.Font.GothamBold
			spark.TextSize = math.random(7,11)
			spark.TextTransparency = 0
			spark.ZIndex = 501
			local dx, dy = math.cos(ang) * dist, math.sin(ang) * dist
			TweenService:Create(spark, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, dx, 0.8, dy),
				TextTransparency = 1,
			}):Play()
			task.delay(0.65, function() pcall(function() spark:Destroy() end) end)
		end
	end

	-- Bright flash accent — a quick full-screen white pulse for punch
	local function fireFlash(peakTransparency)
		local flash = Instance.new("Frame", introGui)
		flash.Size = UDim2.new(1,0,1,0)
		flash.BackgroundColor3 = C_WHITE
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.ZIndex = 999
		TweenService:Create(flash, TweenInfo.new(0.08), {BackgroundTransparency = peakTransparency or 0.82}):Play()
		task.delay(0.08, function()
			pcall(function()
				TweenService:Create(flash, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
				task.delay(0.3, function() pcall(function() flash:Destroy() end) end)
			end)
		end)
	end

	-- ── SFX helper (silent on error) ─────────────────────────────
	local _SS = game:GetService("SoundService")
	local function _sfx(id, vol, pitch)
		pcall(function()
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://" .. id
			s.Volume = vol or 0.5
			s.PlaybackSpeed = pitch or 1
			s.RollOffMaxDistance = 0
			s.Parent = _SS
			s:Play()
			game:GetService("Debris"):AddItem(s, 10)
		end)
	end
	-- IDs  1846359858 = pad éthéré / ambient
	--       5791714739 = swoosh sharp étoile
	--       4115432498 = drop cinématique lune
	--       9120386436 = bell titre
	--       2865227271 = arpège sparkle étoile
	--       1369158167 = fade sweep cinématique

	-- ── SEQUENCE ──────────────────────────────────────────────────
	task.spawn(function()
		TweenService:Create(sceneScale, TweenInfo.new(3.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{Scale = 1}):Play()
		_sfx(3340803765, 0.20, 0.5)            -- nappe ambiante ouverture
		task.delay(0.1, function()
			fireShootingStar()
			_sfx(260430148, 0.32, 1.0)         -- swoosh profond étoile filante
		end)

		task.wait(0.4)
		moonWrap.Size = UDim2.new(0,0,0,0)
		TweenService:Create(moonWrap, TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Size = UDim2.new(0,70,0,70)}):Play()
		fireShockwave()
		task.delay(0.18, fireShockwave)
		fireFlash(0.9)
		_sfx(2545463903, 0.78, 1.0)            -- impact cinématique — apparition de la lune
		task.wait(0.5)
		nameLbl.TextSize = 62
		TweenService:Create(nameLbl, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{TextTransparency = 0, TextSize = 46}):Play()
		_sfx(131322600, 0.40, 1.0)             -- cloche cristal — titre
		task.wait(0.35)
		TweenService:Create(subLbl, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
		task.wait(0.2)
		TweenService:Create(divWrap, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = UDim2.new(0,120,0,1)}):Play()
		task.wait(0.2)
		TweenService:Create(verLbl, TweenInfo.new(0.4), {TextTransparency = 0}):Play()

		task.wait(1.5)

		-- End star: appears, glows, bursts into sparkles, then fades
		star.Size = UDim2.new(0,24,0,24)
		TweenService:Create(star, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{TextTransparency = 0}):Play()
		task.wait(0.3)
		fireStarBurst()
		fireFlash(0.94)
		_sfx(876066539, 0.65, 1.0)             -- scintillement magique — étoile burst
		task.wait(0.2)

		-- Text fade out
		TweenService:Create(verLbl, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		task.wait(0.1)
		TweenService:Create(divWrap, TweenInfo.new(0.2), {Size = UDim2.new(0,0,0,1)}):Play()
		TweenService:Create(subLbl, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		task.wait(0.1)
		TweenService:Create(nameLbl, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
		TweenService:Create(moonWrap, TweenInfo.new(0.3), {Size = UDim2.new(0,0,0,0)}):Play()
		task.wait(0.3)

		-- The star fades out (last visible element)
		TweenService:Create(star, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{TextTransparency = 1}):Play()
		_sfx(131070686, 0.25, 1.0)             -- transition sci-fi — fade out cinématique
		task.wait(0.55)

		doSkip()
	end)
end



-- ===================================================================
-- DRAG SYSTEM — no dragPosLabel (green Y: label removed)
-- ===================================================================
local _uiLocked = false          -- LOCK : quand true, aucun drag ne fonctionne
local _dragStates = {}           -- registry of all created drag states
local _activeDrag = nil
local _MH_positions = {}         -- registry of draggable frames keyed by posId
_GH.positions = _MH_positions

UIS.InputChanged:Connect(function(inp)
	if not _activeDrag then return end
	if inp ~= _activeDrag.dragInput then return end
	if not _activeDrag.dragging then return end
	local dx = inp.Position.X - _activeDrag.dragStart.X
	local dy = inp.Position.Y - _activeDrag.dragStart.Y
	local sp = _activeDrag.startPos
	_activeDrag.frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset+dx, sp.Y.Scale, sp.Y.Offset+dy)
end)

local function makeDraggable(frame, handle, posId)
	local src = handle or frame
	local state = { frame=frame, dragging=false, dragInput=nil, dragStart=nil, startPos=nil }
	_dragStates[#_dragStates+1] = state
	if posId then _MH_positions[posId] = frame end
	src.InputBegan:Connect(function(inp)
		if _uiLocked then return end   -- LOCK: blocks drag from starting
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			state.dragging = true
			state.dragStart = inp.Position
			state.startPos = frame.Position
			_activeDrag = state
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then
					state.dragging = false
					if _activeDrag == state then _activeDrag = nil end
					if posId and _GH.autoSave then _GH.autoSave() end
				end
			end)
		end
	end)
	src.InputChanged:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch then
			state.dragInput = inp
		end
	end)
end

-- Toggle drag lock (called by the 🔓/🔒 button in the title bar)
-- Locks EVERYTHING: main menu, widgets, and floating buttons.
local function setDragLock(on)
	_uiLocked = on
	if on then
		-- Cancel any drag in progress
		for _, st in ipairs(_dragStates) do st.dragging = false end
		_activeDrag = nil
	end
	if _GH.setFloatLocked then _GH.setFloatLocked(on) end
end

-- ===================================================================
-- MAIN OUTER PANEL
-- ===================================================================
local WIN_W, WIN_H = 300, 340
local TITLE_H = 34

local mainOuter = Instance.new("Frame", gui)
mainOuter.Name = "MainOuter"
mainOuter.Size = UDim2.new(0,WIN_W,0,WIN_H)
mainOuter.Position = UDim2.new(0.5,-WIN_W/2,0.5,-137)
mainOuter.BackgroundTransparency = 1; mainOuter.BorderSizePixel = 0
mainOuter.ClipsDescendants = true; mainOuter.Active = true
addCorner(mainOuter, 24); makeDraggable(mainOuter, nil, "main")
local mainUIScale = Instance.new("UIScale", mainOuter)

local bgImg = Instance.new("Frame", mainOuter)
bgImg.Name = "BgFill"; bgImg.Size = UDim2.new(1,0,1,0)
bgImg.BackgroundColor3 = C_BG; bgImg.BorderSizePixel = 0; bgImg.ZIndex = 0
addCorner(bgImg, 24)

addLivingStroke(mainOuter, 2)

-- ===================================================================
-- TITLE BAR
-- ===================================================================
local titleBar = Instance.new("Frame", mainOuter)
titleBar.Size = UDim2.new(1,0,0,TITLE_H); titleBar.BackgroundTransparency = 1
titleBar.BorderSizePixel = 0; titleBar.ZIndex = 5

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(0,200,0,20); titleLbl.Position = UDim2.new(0,14,0,7)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "MOON V3 - YSLEM X ALN"
titleLbl.TextColor3 = C_WHITE; titleLbl.Font = Enum.Font.GothamBlack; titleLbl.TextSize = 11
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.ZIndex = 6
addLivingTextGradient(titleLbl)

-- LOCK button in the title bar (freezes/unfreezes drag)
local lockTitleBtn = Instance.new("TextButton", titleBar)
lockTitleBtn.Size = UDim2.new(0,22,0,22); lockTitleBtn.Position = UDim2.new(1,-56,0.5,-11)
lockTitleBtn.BackgroundColor3 = Color3.fromRGB(0,0,0); lockTitleBtn.BorderSizePixel = 0
lockTitleBtn.Text = "🔓"; lockTitleBtn.TextColor3 = C_WHITE
lockTitleBtn.Font = Enum.Font.GothamBlack; lockTitleBtn.TextSize = 13
lockTitleBtn.ZIndex = 7; addCorner(lockTitleBtn, 8); addLivingStroke(lockTitleBtn, 1)
lockTitleBtn.MouseEnter:Connect(function() TweenService:Create(lockTitleBtn,TweenInfo.new(0.1),{TextColor3=C_MOON2}):Play() end)
lockTitleBtn.MouseLeave:Connect(function() TweenService:Create(lockTitleBtn,TweenInfo.new(0.1),{TextColor3=C_WHITE}):Play() end)
lockTitleBtn.MouseButton1Click:Connect(function()
	_uiLocked = not _uiLocked
	setDragLock(_uiLocked)
	lockTitleBtn.Text = _uiLocked and "🔒" or "🔓"
	lockTitleBtn.TextColor3 = _uiLocked and C_RED or C_WHITE
end)

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0,22,0,22); closeBtn.Position = UDim2.new(1,-30,0.5,-11)
closeBtn.BackgroundColor3 = Color3.fromRGB(0,0,0); closeBtn.BorderSizePixel = 0
closeBtn.Text = "-"; closeBtn.TextColor3 = C_WHITE; closeBtn.Font = Enum.Font.GothamBlack; closeBtn.TextSize = 16
closeBtn.ZIndex = 7; addCorner(closeBtn, 8); addLivingStroke(closeBtn, 1)
closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn,TweenInfo.new(0.1),{TextColor3=C_MOON2}):Play() end)
closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn,TweenInfo.new(0.1),{TextColor3=C_WHITE}):Play() end)

local titleDiv = Instance.new("Frame", mainOuter)
titleDiv.Size = UDim2.new(1,0,0,1); titleDiv.Position = UDim2.new(0,0,0,TITLE_H)
titleDiv.BackgroundColor3 = C_BORDER; titleDiv.BorderSizePixel = 0; titleDiv.ZIndex = 5

-- ===================================================================
-- CONTENT AREA
-- ===================================================================
local CONTENT_Y = TITLE_H + 1
local contentBg = Instance.new("Frame", mainOuter)
contentBg.Size = UDim2.new(1,0,1,-CONTENT_Y); contentBg.Position = UDim2.new(0,0,0,CONTENT_Y)
contentBg.BackgroundTransparency = 1; contentBg.BorderSizePixel = 0
contentBg.ClipsDescendants = true; contentBg.ZIndex = 2

local TABS = {"Combat","Visual","Keybind","Optimize","Settings","Buttons"}
local tabBar = Instance.new("Frame", contentBg)
tabBar.Size = UDim2.new(1,-16,0,26); tabBar.Position = UDim2.new(0,8,0,6)
tabBar.BackgroundTransparency = 1; tabBar.ZIndex = 4
local tabBarLL = Instance.new("UIListLayout", tabBar)
tabBarLL.FillDirection = Enum.FillDirection.Horizontal
tabBarLL.SortOrder = Enum.SortOrder.LayoutOrder
tabBarLL.Padding = UDim.new(0,4)
tabBarLL.HorizontalAlignment = Enum.HorizontalAlignment.Left

local mainScroll = Instance.new("ScrollingFrame", contentBg)
mainScroll.Name = "MainScroll"; mainScroll.Size = UDim2.new(1,0,1,-36); mainScroll.Position = UDim2.new(0,0,0,36)
mainScroll.BackgroundTransparency = 1; mainScroll.BorderSizePixel = 0
mainScroll.ScrollBarThickness = 3; mainScroll.ScrollBarImageColor3 = C_MOON
mainScroll.ScrollBarImageTransparency = 0.4; mainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mainScroll.CanvasSize = UDim2.new(0,0,0,0); mainScroll.ZIndex = 3

local mainLL = Instance.new("UIListLayout", mainScroll)
mainLL.SortOrder = Enum.SortOrder.LayoutOrder; mainLL.Padding = UDim.new(0,6)
local mainPad = Instance.new("UIPadding", mainScroll)
mainPad.PaddingLeft = UDim.new(0,12); mainPad.PaddingRight = UDim.new(0,12)
mainPad.PaddingTop = UDim.new(0,6); mainPad.PaddingBottom = UDim.new(0,14)

-- ===================================================================
-- ROW BUILDERS
-- ===================================================================
local UIB = {}
local currentPage, lo = nil, 0
local function LO() lo = lo + 1; return lo end

function UIB.makeGap(px)
	local f = Instance.new("Frame", currentPage)
	f.Size = UDim2.new(1,0,0,px or 6); f.BackgroundTransparency = 1; f.LayoutOrder = LO()
end

function UIB.makeSectionLabel(text)
	local wrap = Instance.new("Frame", currentPage)
	wrap.Size = UDim2.new(1,0,0,22); wrap.BackgroundTransparency = 1; wrap.LayoutOrder = LO()
	local dot = Instance.new("Frame", wrap)
	dot.Size = UDim2.new(0,4,0,4); dot.Position = UDim2.new(0,2,0.5,-2)
	dot.BackgroundColor3 = C_MOON; dot.BorderSizePixel = 0; addCorner(dot, 2)
	local lbl = Instance.new("TextLabel", wrap)
	lbl.Size = UDim2.new(1,-14,1,0); lbl.Position = UDim2.new(0,12,0,0)
	lbl.BackgroundTransparency = 1; lbl.Text = text:upper()
	lbl.TextColor3 = C_WHITE; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	addLivingTextGradient(lbl)
end

local function makeDivider()
	local div = Instance.new("Frame", currentPage)
	div.Size = UDim2.new(1,-8,0,1); div.Position = UDim2.new(0,4,0,0)
	div.BorderSizePixel = 0; div.LayoutOrder = LO()
	div.BackgroundColor3 = C_DEEP3
	addLivingTextGradient(div)
end

local _MH_allToggles = {}
local _MH_allInputs  = {}
_GH.allToggles = _MH_allToggles
_GH.allInputs  = _MH_allInputs

function UIB.makeInputRow(label, default, onChange)
	local row = Instance.new("Frame", currentPage)
	row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = C_ROW; row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0; row.LayoutOrder = LO(); addCorner(row, 12)
	addLivingStroke(row, 1)
	row.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.15}):Play() end)
	row.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.35}):Play() end)
	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(1,-96,1,0); lbl.Position = UDim2.new(0,14,0,0)
	lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = C_WHITE
	lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left
	addLivingTextGradient(lbl)
	local boxWrap = Instance.new("Frame", row)
	boxWrap.Size = UDim2.new(0,64,0,24); boxWrap.Position = UDim2.new(1,-76,0.5,-12)
	boxWrap.BackgroundColor3 = C_OFF_BG; boxWrap.BackgroundTransparency = 0.1; boxWrap.BorderSizePixel = 0
	addCorner(boxWrap, 8); addLivingStroke(boxWrap, 1)
	local box = Instance.new("TextBox", boxWrap)
	box.Size = UDim2.new(1,-6,1,0); box.Position = UDim2.new(0,3,0,0)
	box.BackgroundTransparency = 1; box.Text = tostring(default)
	box.TextColor3 = C_SILVER; box.Font = Enum.Font.GothamBold; box.TextSize = 12
	box.ClearTextOnFocus = false; box.TextXAlignment = Enum.TextXAlignment.Center
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			onChange(n)
			if _GH.autoSave then _GH.autoSave() end
		else
			box.Text = tostring(default)
		end
	end)
	makeDivider()
	local key = (currentPage and currentPage.Name or "?") .. "::" .. label
	_MH_allInputs[key] = { box = box, default = default, onChange = onChange }
	return box
end

function UIB.makeToggleRow(label, defaultOn, onToggle)
	local row = Instance.new("Frame", currentPage)
	row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = C_ROW; row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0; row.LayoutOrder = LO(); addCorner(row, 12)
	addLivingStroke(row, 1)
	row.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.15}):Play() end)
	row.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.35}):Play() end)
	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(1,-70,1,0); lbl.Position = UDim2.new(0,14,0,0)
	lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = C_WHITE
	lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left
	addLivingTextGradient(lbl)
	local pill = Instance.new("Frame", row)
	pill.Size = UDim2.new(0,40,0,20); pill.Position = UDim2.new(1,-54,0.5,-10)
	pill.BackgroundColor3 = defaultOn and C_ON_BG or C_OFF_BG; pill.BackgroundTransparency = 0.1
	pill.BorderSizePixel = 0; addCorner(pill, 10); addLivingStroke(pill, 1)
	local ball = Instance.new("Frame", pill)
	ball.Size = UDim2.new(0,14,0,14)
	ball.Position = defaultOn and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
	ball.BackgroundColor3 = defaultOn and C_WHITE or C_SILVER2; ball.BorderSizePixel = 0
	addCorner(ball, 7)
	local isOn = defaultOn
	local function setV(on)
		isOn = on
		TweenService:Create(pill,TweenInfo.new(0.15),{BackgroundColor3=on and C_ON_BG or C_OFF_BG}):Play()
		TweenService:Create(ball,TweenInfo.new(0.15,Enum.EasingStyle.Back),{
			Position=on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7),
			BackgroundColor3=on and C_WHITE or C_SILVER2,
		}):Play()
	end
	local clk = Instance.new("TextButton", row)
	clk.Size = UDim2.new(1,0,1,0); clk.BackgroundTransparency = 1; clk.Text = ""
	clk.MouseButton1Down:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
	end)
	clk.MouseButton1Up:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.35}):Play()
	end)
	clk.MouseButton1Click:Connect(function()
		isOn = not isOn; setV(isOn)
		if onToggle then onToggle(isOn) end
		if _GH.autoSave then _GH.autoSave() end
	end)
	makeDivider()
	local key = (currentPage and currentPage.Name or "?") .. "::" .. label
	_MH_allToggles[key] = {
		get = function() return isOn end,
		set = setV,
		onToggle = onToggle,
	}
	return setV
end

-- ===================================================================
-- TAB PAGES
-- ===================================================================
local tabPages   = {}
local tabButtons = {}

local function buildPage(name, buildFn)
	local page = Instance.new("Frame", mainScroll)
	page.Name = name; page.Size = UDim2.new(1,0,0,0); page.AutomaticSize = Enum.AutomaticSize.Y
	page.BackgroundTransparency = 1; page.BorderSizePixel = 0; page.Visible = false
	local ll = Instance.new("UIListLayout", page)
	ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0,6)
	tabPages[name] = page; currentPage = page; lo = 0
	buildFn()
	currentPage = nil
	return page
end

local function selectTab(name)
	for n, page in pairs(tabPages) do page.Visible = (n==name) end
	for n, btn in pairs(tabButtons) do
		local active = (n==name)
		TweenService:Create(btn.frame,TweenInfo.new(0.15),{
			BackgroundColor3=active and C_MOON or Color3.fromRGB(18,22,30),
			BackgroundTransparency=active and 0 or 0.5,
		}):Play()
		btn.lbl.TextColor3 = active and Color3.fromRGB(0,10,20) or C_TABIDLE
	end
end

for i, name in ipairs(TABS) do
	local btn = Instance.new("TextButton", tabBar)
	btn.Size = UDim2.new(0,44,1,0); btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
	btn.BackgroundTransparency = 0.5; btn.BorderSizePixel = 0; btn.Text = ""
	btn.AutoButtonColor = false; btn.LayoutOrder = i; btn.ZIndex = 5
	addCorner(btn, 10); addLivingStroke(btn, 1)
	local lbl = Instance.new("TextLabel", btn)
	lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.Text = name
	lbl.TextColor3 = C_TABIDLE; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10; lbl.ZIndex = 6
	tabButtons[name] = {frame=btn, lbl=lbl}
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.1}):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5}):Play()
	end)
	btn.MouseButton1Click:Connect(function() selectTab(name) end)
end

-- ===================================================================
-- MINI BUTTON
-- ===================================================================
local miniBtn = Instance.new("TextButton", gui)
miniBtn.Size = UDim2.new(0,56,0,56); miniBtn.Position = UDim2.new(0,20,0,140)
miniBtn.BackgroundTransparency = 1; miniBtn.Text = ""; miniBtn.AutoButtonColor = false
miniBtn.Visible = false; miniBtn.ZIndex = 50

local mbHalo = Instance.new("Frame", miniBtn)
mbHalo.AnchorPoint = Vector2.new(0.5,0.5); mbHalo.Position = UDim2.new(0.5,0,0.5,0)
mbHalo.Size = UDim2.new(1.5,0,1.5,0); mbHalo.BackgroundColor3 = C_MOON
mbHalo.BorderSizePixel = 0; mbHalo.ZIndex = 49
Instance.new("UICorner", mbHalo).CornerRadius = UDim.new(1,0)
local mbHaloGrad = Instance.new("UIGradient", mbHalo)
mbHaloGrad.Color = ColorSequence.new(C_MOON, Color3.fromRGB(10,12,18))
mbHaloGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.55),NumberSequenceKeypoint.new(1,1)})
mbHaloGrad.Rotation = 90

local miniDisc = Instance.new("Frame", miniBtn)
miniDisc.Size = UDim2.new(1,0,1,0); miniDisc.BackgroundColor3 = Color3.fromRGB(0,0,0)
miniDisc.BorderSizePixel = 0; miniDisc.ZIndex = 50
Instance.new("UICorner", miniDisc).CornerRadius = UDim.new(1,0)
addGradient(miniDisc, Color3.fromRGB(22,27,40), Color3.fromRGB(10,12,18), 90)
local miniStk = addLivingStroke(miniDisc, 1.3)

local moonIconSize = 26
local moonIcon = Instance.new("Frame", miniDisc)
moonIcon.AnchorPoint = Vector2.new(0.5,0.5); moonIcon.Position = UDim2.new(0.5,0,0.5,0)
moonIcon.Size = UDim2.new(0,moonIconSize,0,moonIconSize)
moonIcon.BackgroundColor3 = C_SILVER; moonIcon.BorderSizePixel = 0; moonIcon.ZIndex = 51
Instance.new("UICorner", moonIcon).CornerRadius = UDim.new(1,0)
local moonIconShadowClip = Instance.new("Frame", moonIcon)
moonIconShadowClip.Size = UDim2.new(1,0,1,0); moonIconShadowClip.BackgroundTransparency = 1
moonIconShadowClip.ClipsDescendants = true; moonIconShadowClip.ZIndex = 52
Instance.new("UICorner", moonIconShadowClip).CornerRadius = UDim.new(1,0)
local moonIconShadow = Instance.new("Frame", moonIconShadowClip)
moonIconShadow.AnchorPoint = Vector2.new(0.5,0.5); moonIconShadow.Position = UDim2.new(0.62,0,0.5,0)
moonIconShadow.Size = UDim2.new(1.05,0,1.05,0); moonIconShadow.BackgroundColor3 = Color3.fromRGB(0,0,0)
moonIconShadow.BorderSizePixel = 0; moonIconShadow.ZIndex = 52
Instance.new("UICorner", moonIconShadow).CornerRadius = UDim.new(1,0)

local _mbAnimRunning = false
local function startMbAnim()
	if _mbAnimRunning then return end
	_mbAnimRunning = true
	task.spawn(function()
		while miniBtn and miniBtn.Parent and _mbAnimRunning do
			TweenService:Create(miniStk,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=0.05}):Play()
			TweenService:Create(mbHalo,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Size=UDim2.new(1.7,0,1.7,0)}):Play()
			task.wait(1.5)
			TweenService:Create(miniStk,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=0.4}):Play()
			TweenService:Create(mbHalo,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Size=UDim2.new(1.5,0,1.5,0)}):Play()
			task.wait(1.5)
		end
	end)
end
startMbAnim()
_GH.mbHalo = mbHalo; _GH.miniStk = miniStk; _GH.startMbAnim = startMbAnim
_GH.stopMbAnim = function() _mbAnimRunning = false end
makeDraggable(miniBtn, nil, "mini")

local function showGui() mainOuter.Visible = true; miniBtn.Visible = false end
local function hideGui() mainOuter.Visible = false; miniBtn.Visible = true end
closeBtn.MouseButton1Click:Connect(hideGui)
miniBtn.MouseButton1Click:Connect(showGui)

-- ===================================================================
-- Drag-lock is handled only by lockTitleBtn (title button).
-- No additional widget.

-- ===================================================================
-- AUTO TP DOWN — Raycast (déclaré ici pour être visible dans Combat)
-- ===================================================================
local _sTPDownEnabled = false
local _sTPDownConn    = nil
local _sTPDownHeight  = 20
local _sTPDownBusy    = false
local function _sRunTPDown()
	if _sTPDownBusy then return end
	_sTPDownBusy = true
	pcall(function()
		local char = LP.Character; if not char then _sTPDownBusy=false; return end
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum2 = char:FindFirstChildOfClass("Humanoid")
		if not root or not hum2 then _sTPDownBusy=false; return end
		local hipH = hum2.HipHeight or 2
		local rp = RaycastParams.new()
		rp.FilterDescendantsInstances = {char}
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local ray = workspace:Raycast(root.Position, Vector3.new(0,-500,0), rp)
		if ray then
			root.CFrame = CFrame.new(root.Position.X, ray.Position.Y + hipH + 0.1, root.Position.Z)
			root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
		end
	end)
	_sTPDownBusy = false
end
local function _sStartAutoTPDown()
	if _sTPDownConn then task.cancel(_sTPDownConn); _sTPDownConn=nil end
	_sTPDownEnabled = true
	_sTPDownConn = task.spawn(function()
		while _sTPDownEnabled do
			task.wait(0.1)
			pcall(function()
				local char = LP.Character; if not char then return end
				local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
				local hum2 = char:FindFirstChildOfClass("Humanoid"); if not hum2 then return end
				if hum2.FloorMaterial ~= Enum.Material.Air then return end
				if root.Position.Y < _sTPDownHeight then return end
				_sRunTPDown()
			end)
		end
	end)
end
local function _sStopAutoTPDown()
	_sTPDownEnabled = false
	if _sTPDownConn then task.cancel(_sTPDownConn); _sTPDownConn=nil end
end

-- ===================================================================
-- MOVEMENT LOGIC
-- ===================================================================
buildPage("Combat", function()
	UIB.makeSectionLabel("Combat")
	UIB.makeToggleRow("Bat Counter",false,function(on)
		BatCounter.active=on; if on then BatCounter.start() else BatCounter.stop() end
	end)
	UIB.makeToggleRow("Bat Aimbot",false,function(on)
		if on then if ABP.active then ABP.stop() end; AB.start() else AB.stop() end
	end)
	UIB.makeToggleRow("Bat Aimbot V2",false,function(on)
		if on then if AB.active then AB.stop() end; ABP.start() else ABP.stop() end
	end)

	UIB.makeGap(4); UIB.makeSectionLabel("Aimbot Tuning")
	UIB.makeInputRow("Aim Speed",AB.SPEED,function(n) if n>0 and n<=200 then AB.SPEED=n end end)
	UIB.makeInputRow("Aim Height",AB.HEIGHT,function(n) if n>=0 and n<=30 then AB.HEIGHT=n end end)
	UIB.makeGap(4); UIB.makeSectionLabel("Defense")
	UIB.makeToggleRow("Anti Ragdoll",true,function(on)
		State.antiRagdollEnabled=on; if on then startAntiRagdoll() else stopAntiRagdoll() end
	end)
	UIB.makeToggleRow("Medusa Counter",false,function(on)
		State.medusaCounterEnabled=on
		if on then setupMedusaCounter(LP.Character) else stopMedusaCounter() end
	end)
	UIB.makeToggleRow("Auto Reset on Med",false,function(on)
		State.autoResetOnMedEnabled=on
		_armState.enabled=on
		if on then _armStart(LP.Character) else _armStop() end
	end)

	UIB.makeToggleRow("Infinite Jump",false,function(on)
		IJ.active=on; if on then IJ.start() else IJ.stop() end
	end)
	do
		local mr=Instance.new("Frame",currentPage); mr.Size=UDim2.new(1,0,0,26); mr.BackgroundColor3=C_ROW; mr.BackgroundTransparency=0.35; mr.BorderSizePixel=0; mr.LayoutOrder=LO(); addCorner(mr,12); addLivingStroke(mr,1)
		local ml=Instance.new("TextLabel",mr); ml.Size=UDim2.new(0,90,1,0); ml.Position=UDim2.new(0,14,0,0); ml.BackgroundTransparency=1; ml.Text="Jump Mode"; ml.TextColor3=C_WHITE; ml.Font=Enum.Font.GothamBold; ml.TextSize=10; ml.TextXAlignment=Enum.TextXAlignment.Left; addLivingTextGradient(ml)
		local BW,BH=50,18
		local manB=Instance.new("TextButton",mr); manB.Size=UDim2.new(0,BW,0,BH); manB.Position=UDim2.new(1,-(BW*2+14),0.5,-BH/2); manB.BackgroundColor3=C_ON_BG; manB.BackgroundTransparency=0.1; manB.BorderSizePixel=0; manB.Text="Manual"; manB.TextColor3=C_SILVER; manB.Font=Enum.Font.GothamBold; manB.TextSize=9; manB.AutoButtonColor=false; addCorner(manB,6); addLivingStroke(manB,1)
		local holB=Instance.new("TextButton",mr); holB.Size=UDim2.new(0,BW,0,BH); holB.Position=UDim2.new(1,-(BW+6),0.5,-BH/2); holB.BackgroundColor3=C_OFF_BG; holB.BackgroundTransparency=0.3; holB.BorderSizePixel=0; holB.Text="Hold"; holB.TextColor3=C_DIM; holB.Font=Enum.Font.GothamBold; holB.TextSize=9; holB.AutoButtonColor=false; addCorner(holB,6)
		local function updM()
			manB.BackgroundColor3 = IJ.mode=="manual" and C_MOON or C_OFF_BG
			manB.BackgroundTransparency = IJ.mode=="manual" and 0.15 or 0.5
			manB.TextColor3 = IJ.mode=="manual" and Color3.fromRGB(0,10,20) or C_DIM
			holB.BackgroundColor3 = IJ.mode=="hold" and C_MOON or C_OFF_BG
			holB.BackgroundTransparency = IJ.mode=="hold" and 0.15 or 0.5
			holB.TextColor3 = IJ.mode=="hold" and Color3.fromRGB(0,10,20) or C_DIM
			if IJ.active then IJ.stop(); IJ.start() end
		end
		updM() -- apply initial state
		manB.MouseButton1Click:Connect(function() IJ.mode="manual"; updM(); if _GH.autoSave then _GH.autoSave() end end)
		holB.MouseButton1Click:Connect(function() IJ.mode="hold"; updM(); if _GH.autoSave then _GH.autoSave() end end)
		makeDivider()
	end
	UIB.makeToggleRow("Auto Steal",true,function(on)
		AutoSteal.Enabled=on; if on then startAutoSteal() else stopAutoSteal() end
	end)
	UIB.makeInputRow("Steal Radius",AutoSteal.Radius,function(n) if n and n>=1 and n<=500 then AutoSteal.Radius=n end end)
	UIB.makeToggleRow("Auto TP Down", false, function(on)
		if on then _sStartAutoTPDown() else _sStopAutoTPDown() end
	end)
	UIB.makeInputRow("Height (Y)", _sTPDownHeight, function(n)
		if n >= 0 and n <= 9999 then _sTPDownHeight = n end
	end)
	local tpDownRow=Instance.new("Frame",currentPage)
	tpDownRow.Size=UDim2.new(1,0,0,32); tpDownRow.BackgroundColor3=C_ROW; tpDownRow.BackgroundTransparency=0.35
	tpDownRow.BorderSizePixel=0; tpDownRow.LayoutOrder=LO(); addCorner(tpDownRow,12); addLivingStroke(tpDownRow,1)
	local tpDownClk=Instance.new("TextButton",tpDownRow)
	tpDownClk.Size=UDim2.new(1,0,1,0); tpDownClk.BackgroundTransparency=1
	tpDownClk.Text="TP Down"; tpDownClk.TextColor3=C_WHITE; tpDownClk.Font=Enum.Font.GothamBold; tpDownClk.TextSize=10
	addLivingTextGradient(tpDownClk); tpDownClk.MouseButton1Click:Connect(tpToGround)
	local dropRow=Instance.new("Frame",currentPage)
	dropRow.Size=UDim2.new(1,0,0,32); dropRow.BackgroundColor3=C_ROW; dropRow.BackgroundTransparency=0.35
	dropRow.BorderSizePixel=0; dropRow.LayoutOrder=LO(); addCorner(dropRow,12); addLivingStroke(dropRow,1)
	local dropClk=Instance.new("TextButton",dropRow)
	dropClk.Size=UDim2.new(1,0,1,0); dropClk.BackgroundTransparency=1
	dropClk.Text="Drop Brainrot"; dropClk.TextColor3=C_WHITE; dropClk.Font=Enum.Font.GothamBold; dropClk.TextSize=10
	addLivingTextGradient(dropClk); dropClk.MouseButton1Click:Connect(runDropBrainrot)
end)

-- Declared here (before buildPage Visual) to be visible in applyScale.
-- "Spawnable" floating button system (replaces the fixed Quick Panel +
-- attach/detach): each action has a toggle in Settings that shows/hides
-- its floating button. "Lock" freezes the drag of all
-- currently displayed buttons.
local _floatDefs      = {}   -- id -> {label, onClick, isActive, momentary}
local _floatBtns      = {}   -- id -> {frame, setActive}
local _floatPositions = {}   -- id -> {xs,xo,ys,yo}
-- Bump this whenever the default layout changes: saved positions from an
-- older version get discarded on load instead of restoring stale/overlapping
-- coordinates, so everyone gets the current clean column layout by default.
local _FLOAT_POS_VERSION = 14
local _floatLocked    = false
local FLOAT_SZ = 44
local FLOAT_WIDE_H = 30  -- height of wide button (antibat) — slimmer than grid buttons

-- Declared here (before buildPage Settings) so the Speed
-- Bypass / Lagger toggles can reference the widgets built further
-- down in the file — otherwise the closure captures a nil global (same
-- trap as the mainFrame bug fixed earlier).
local _sbBypassWidget  = nil
local _lgrBypassWidget = nil

-- Speed Booster "edited" size (via the Visual tab's Scale slider)
-- — shared with the widget's "-" button so it doesn't revert
-- to a hardcoded default size when shrinking/expanding.
local _spExpandedSize = {w = 150, h = 160}
local _spCollapsed    = false

buildPage("Visual", function()
	-- ── FLOATING BUTTON SCALE ─────────────────────────────────────────
	-- Size of spawnable buttons. Scale 1=min(40px) → 10=max(74px).
	-- Stores the current value so the slider reflects the real state.
	UIB.makeSectionLabel("Button Size")
	UIB.makeGap(2)

	-- Display the current value
	local scaleValLbl = Instance.new("TextLabel", currentPage)
	scaleValLbl.Size = UDim2.new(1,0,0,18); scaleValLbl.BackgroundTransparency = 1
	scaleValLbl.Text = "Scale: 5 / 10"
	scaleValLbl.TextColor3 = C_MOON2; scaleValLbl.Font = Enum.Font.GothamBold; scaleValLbl.TextSize = 10
	scaleValLbl.TextXAlignment = Enum.TextXAlignment.Left; scaleValLbl.LayoutOrder = LO()
	addLivingTextGradient(scaleValLbl)

	-- Slider track
	local trackWrap = Instance.new("Frame", currentPage)
	trackWrap.Size = UDim2.new(1,0,0,32); trackWrap.BackgroundColor3 = C_ROW
	trackWrap.BackgroundTransparency = 0.35; trackWrap.BorderSizePixel = 0; trackWrap.LayoutOrder = LO()
	addCorner(trackWrap, 12); addLivingStroke(trackWrap, 1)

	local track = Instance.new("Frame", trackWrap)
	track.Size = UDim2.new(1,-28,0,4); track.Position = UDim2.new(0,14,0.5,-2)
	track.BackgroundColor3 = C_DEEP2; track.BorderSizePixel = 0
	addCorner(track, 2)

	local trackFill = Instance.new("Frame", track)
	trackFill.Size = UDim2.new(0.4,0,1,0)   -- 0.4 = initial position (scale 5 of 10)
	trackFill.BackgroundColor3 = C_MOON; trackFill.BorderSizePixel = 0
	addCorner(trackFill, 2)
	addLivingTextGradient(trackFill)

	local thumb = Instance.new("TextButton", trackWrap)
	thumb.Size = UDim2.new(0,16,0,16); thumb.AnchorPoint = Vector2.new(0.5,0.5)
	thumb.Position = UDim2.new(0.4,14,0.5,0)   -- initial position synced with fill
	thumb.BackgroundColor3 = C_WHITE; thumb.BorderSizePixel = 0; thumb.Text = ""
	thumb.AutoButtonColor = false; thumb.ZIndex = 5
	addCorner(thumb, 8); addLivingStroke(thumb, 1)

	-- Slider drag logic (no dragPosLabel)
	local _scaleVal = 5     -- current value 1-10
	local _thumbDrag = false
	local _trackAbsX, _trackAbsW = 0, 1

	local function applyScale(v)
		_scaleVal = math.clamp(math.floor(v + 0.5), 1, 10)
		local t = (_scaleVal - 1) / 9
		trackFill.Size = UDim2.new(t, 0, 1, 0)
		thumb.Position = UDim2.new(0, 14 + t * math.max(_trackAbsW - 1, 1), 0.5, 0)
		scaleValLbl.Text = "Scale: " .. _scaleVal .. " / 10"

		-- Range: 34px (scale 1) → 70px (scale 10) — floating button size
		local newSz = 34 + math.floor((_scaleVal - 1) * (70 - 34) / 9)
		FLOAT_SZ = newSz
		for id, entry in pairs(_floatBtns) do
			if entry.frame and entry.frame.Parent then
				if id == "antibat" then
					entry.frame.Size = UDim2.new(0, newSz * 2 + 8, 0, newSz)
				else
					entry.frame.Size = UDim2.new(0, newSz, 0, newSz)
				end
			end
		end
	end

	thumb.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			_thumbDrag = true
			_trackAbsX = track.AbsolutePosition.X
			_trackAbsW = track.AbsoluteSize.X
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if not _thumbDrag then return end
		if inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch then
			local rel = math.clamp((inp.Position.X - _trackAbsX) / _trackAbsW, 0, 1)
			applyScale(1 + rel * 9)
		end
	end)
	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			_thumbDrag = false
		end
	end)
	-- Direct click on the track
	local trackBtn = Instance.new("TextButton", trackWrap)
	trackBtn.Size = UDim2.new(1,0,1,0); trackBtn.BackgroundTransparency = 1; trackBtn.Text = ""
	trackBtn.ZIndex = 4
	trackBtn.MouseButton1Click:Connect(function()
		_trackAbsX = track.AbsolutePosition.X
		_trackAbsW = track.AbsoluteSize.X
		local mPos = UIS:GetMouseLocation()
		local rel = math.clamp((mPos.X - _trackAbsX) / _trackAbsW, 0, 1)
		applyScale(1 + rel * 9)
	end)

	-- ── UI SCALE (main hub size) ──────────────────────────────────────
	UIB.makeGap(6)
	UIB.makeSectionLabel("UI Scale")

	local uiScaleValLbl = Instance.new("TextLabel", currentPage)
	uiScaleValLbl.Size = UDim2.new(1,0,0,18); uiScaleValLbl.BackgroundTransparency = 1
	uiScaleValLbl.Text = "Scale: 5 / 10"
	uiScaleValLbl.TextColor3 = C_MOON2; uiScaleValLbl.Font = Enum.Font.GothamBold; uiScaleValLbl.TextSize = 10
	uiScaleValLbl.TextXAlignment = Enum.TextXAlignment.Left; uiScaleValLbl.LayoutOrder = LO()
	addLivingTextGradient(uiScaleValLbl)

	local uiTrackWrap = Instance.new("Frame", currentPage)
	uiTrackWrap.Size = UDim2.new(1,0,0,32); uiTrackWrap.BackgroundColor3 = C_ROW
	uiTrackWrap.BackgroundTransparency = 0.35; uiTrackWrap.BorderSizePixel = 0; uiTrackWrap.LayoutOrder = LO()
	addCorner(uiTrackWrap, 12); addLivingStroke(uiTrackWrap, 1)

	local uiTrack = Instance.new("Frame", uiTrackWrap)
	uiTrack.Size = UDim2.new(1,-28,0,4); uiTrack.Position = UDim2.new(0,14,0.5,-2)
	uiTrack.BackgroundColor3 = C_DEEP2; uiTrack.BorderSizePixel = 0
	addCorner(uiTrack, 2)

	local uiTrackFill = Instance.new("Frame", uiTrack)
	uiTrackFill.Size = UDim2.new(0.4,0,1,0)
	uiTrackFill.BackgroundColor3 = C_MOON; uiTrackFill.BorderSizePixel = 0
	addCorner(uiTrackFill, 2); addLivingTextGradient(uiTrackFill)

	local uiThumb = Instance.new("TextButton", uiTrackWrap)
	uiThumb.Size = UDim2.new(0,16,0,16); uiThumb.AnchorPoint = Vector2.new(0.5,0.5)
	uiThumb.Position = UDim2.new(0.4,14,0.5,0)
	uiThumb.BackgroundColor3 = C_WHITE; uiThumb.BorderSizePixel = 0; uiThumb.Text = ""
	uiThumb.AutoButtonColor = false; uiThumb.ZIndex = 5
	addCorner(uiThumb, 8); addLivingStroke(uiThumb, 1)

	-- WIN_W=300, WIN_H=340 — scale 1=60% → 10=140%
	local _uiScaleVal  = 5
	local _uiThumbDrag = false
	local _uiTrackAbsX, _uiTrackAbsW = 0, 1

	local function applyUIScale(v)
		_uiScaleVal = math.clamp(math.floor(v + 0.5), 1, 10)
		local t   = (_uiScaleVal - 1) / 9
		uiTrackFill.Size    = UDim2.new(t, 0, 1, 0)
		local absW = uiTrack.AbsoluteSize.X
		if absW > 2 then
			uiThumb.Position = UDim2.new(0, 14 + t * absW, 0.5, 0)
		end
		uiScaleValLbl.Text  = "Scale: " .. _uiScaleVal .. " / 10"
		local factor = 0.6 + t * 0.8
		if mainOuter and mainOuter.Parent then
			-- UIScale resizes everything proportionally (text, rows, spacing)
			-- instead of just shrinking the frame — nothing gets cut off
			-- by ClipsDescendants, unlike the old direct resize.
			mainUIScale.Scale = factor
			local scaledW = WIN_W * factor
			mainOuter.Position = UDim2.new(0.5, -scaledW/2, 0.5, -137)
		end
	end
	_GH.applyUIScale = applyUIScale
	_GH.getUIScale   = function() return _uiScaleVal end

	uiThumb.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			_uiThumbDrag = true
			_uiTrackAbsX = uiTrack.AbsolutePosition.X
			_uiTrackAbsW = uiTrack.AbsoluteSize.X
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if not _uiThumbDrag then return end
		if inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch then
			local rel = math.clamp((inp.Position.X - _uiTrackAbsX) / _uiTrackAbsW, 0, 1)
			applyUIScale(1 + rel * 9)
		end
	end)
	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			_uiThumbDrag = false
		end
	end)
	local uiTrackBtn = Instance.new("TextButton", uiTrackWrap)
	uiTrackBtn.Size = UDim2.new(1,0,1,0); uiTrackBtn.BackgroundTransparency = 1; uiTrackBtn.Text = ""
	uiTrackBtn.ZIndex = 4
	uiTrackBtn.MouseButton1Click:Connect(function()
		_uiTrackAbsX = uiTrack.AbsolutePosition.X
		_uiTrackAbsW = uiTrack.AbsoluteSize.X
		local mPos = UIS:GetMouseLocation()
		local rel  = math.clamp((mPos.X - _uiTrackAbsX) / _uiTrackAbsW, 0, 1)
		applyUIScale(1 + rel * 9)
	end)

	UIB.makeGap(4)
	UIB.makeSectionLabel("Lighting")
	UIB.makeToggleRow("Fullbright",false,function(on) Lighting.Brightness=on and 10 or 1 end)
	UIB.makeToggleRow("Shadows OFF",false,function(on) Lighting.GlobalShadows=not on end)
	UIB.makeToggleRow("Fog OFF",false,function(on) Lighting.FogEnd=on and 9e9 or 1000 end)
	UIB.makeInputRow("FOV",70,function(n) if n>=30 and n<=120 then workspace.CurrentCamera.FieldOfView=n end end)
	UIB.makeGap(4)
	UIB.makeSectionLabel("Sky & Atmosphere")
	local _dBri,_dClock,_dAmb,_dOut,_dFogE,_dFogC = Lighting.Brightness,Lighting.ClockTime,Lighting.Ambient,Lighting.OutdoorAmbient,Lighting.FogEnd,Lighting.FogColor
	UIB.makeToggleRow("Dark Mode",false,function(on)
		if on then
			local s=Lighting:FindFirstChild(_NS.."d") or Instance.new("Sky"); s.Name=_NS.."d"
			s.SkyboxBk="rbxassetid://159454299";s.SkyboxDn="rbxassetid://159454296";s.SkyboxFt="rbxassetid://159454293"
			s.SkyboxLf="rbxassetid://159454286";s.SkyboxRt="rbxassetid://159454289";s.SkyboxUp="rbxassetid://159454291";s.Parent=Lighting
			Lighting.Brightness=0;Lighting.ClockTime=0;Lighting.OutdoorAmbient=Color3.fromRGB(0,0,0)
		else
			local s=Lighting:FindFirstChild(_NS.."d");if s then s:Destroy() end
			Lighting.Brightness=_dBri;Lighting.ClockTime=_dClock;Lighting.OutdoorAmbient=_dOut
		end
	end)
	UIB.makeToggleRow("Cloudy Blue",false,function(on)
		if on then
			Lighting.ClockTime=7;Lighting.Brightness=1.2;Lighting.FogEnd=800;Lighting.FogColor=Color3.fromRGB(160,190,255)
			Lighting.Ambient=Color3.fromRGB(190,200,230);Lighting.OutdoorAmbient=Color3.fromRGB(200,210,240)
			local cc=Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect",Lighting)
			cc.TintColor=Color3.fromRGB(180,210,255);cc.Saturation=0.12;cc.Brightness=0.04
		else
			Lighting.ClockTime=_dClock;Lighting.Brightness=_dBri;Lighting.FogEnd=_dFogE;Lighting.FogColor=_dFogC
			Lighting.Ambient=_dAmb;Lighting.OutdoorAmbient=_dOut
			local cc=Lighting:FindFirstChildOfClass("ColorCorrectionEffect");if cc then cc:Destroy() end
		end
	end)
	local _shinyConn=nil
	UIB.makeToggleRow("Shiny Graphics",false,function(on)
		if on then
			for _,obj in ipairs(Lighting:GetChildren()) do
				if obj:IsA("Sky") or obj.Name=="MoonShinyBloom" or obj.Name=="MoonShinyCC" then obj:Destroy() end
			end
			local sky=Instance.new("Sky"); sky.Name=_NS.."e"
			sky.SkyboxBk="rbxassetid://1534951537";sky.SkyboxDn="rbxassetid://1534951537"
			sky.SkyboxFt="rbxassetid://1534951537";sky.SkyboxLf="rbxassetid://1534951537"
			sky.SkyboxRt="rbxassetid://1534951537";sky.SkyboxUp="rbxassetid://1534951537"
			sky.StarCount=10000;sky.CelestialBodiesShown=false;sky.Parent=Lighting
			local bloom=Instance.new("BloomEffect"); bloom.Name=_NS.."f"
			bloom.Intensity=1.5;bloom.Size=40;bloom.Threshold=0.8;bloom.Parent=Lighting
			local cc=Instance.new("ColorCorrectionEffect"); cc.Name=_NS.."g"
			cc.Saturation=0.8;cc.Contrast=0.3;cc.TintColor=Color3.fromRGB(200,200,200);cc.Parent=Lighting
			Lighting.Brightness=3;Lighting.ClockTime=0
			_shinyConn=RunService.Heartbeat:Connect(function()
				local t=tick()*0.5
				Lighting.Ambient=Color3.fromRGB(
					100+math.floor(math.sin(t)*30),
					100+math.floor(math.sin(t*0.8)*30),
					110+math.floor(math.sin(t*1.2)*30))
				local b=Lighting:FindFirstChild(_NS.."f")
				if b then b.Intensity=1.2+math.sin(t*2)*0.4 end
			end)
		else
			if _shinyConn then _shinyConn:Disconnect();_shinyConn=nil end
			local s=Lighting:FindFirstChild(_NS.."e");if s then s:Destroy() end
			local b=Lighting:FindFirstChild(_NS.."f");if b then b:Destroy() end
			local c=Lighting:FindFirstChild(_NS.."g");if c then c:Destroy() end
			Lighting.Brightness=_dBri;Lighting.ClockTime=_dClock;Lighting.Ambient=_dAmb
		end
	end)

	-- Speed Booster Scale
	UIB.makeGap(4)
	UIB.makeSectionLabel("Speed Booster Scale")
	do
		local spScaleValLbl=Instance.new("TextLabel",currentPage)
		spScaleValLbl.Size=UDim2.new(1,0,0,18); spScaleValLbl.BackgroundTransparency=1
		spScaleValLbl.Text="Scale: 5 / 10"; spScaleValLbl.TextColor3=C_MOON2
		spScaleValLbl.Font=Enum.Font.GothamBold; spScaleValLbl.TextSize=10
		spScaleValLbl.TextXAlignment=Enum.TextXAlignment.Left; spScaleValLbl.LayoutOrder=LO()
		addLivingTextGradient(spScaleValLbl)
		local spScWrap=Instance.new("Frame",currentPage)
		spScWrap.Size=UDim2.new(1,0,0,32); spScWrap.BackgroundColor3=C_ROW
		spScWrap.BackgroundTransparency=0.35; spScWrap.BorderSizePixel=0; spScWrap.LayoutOrder=LO()
		addCorner(spScWrap,12); addLivingStroke(spScWrap,1)
		local spScTrk=Instance.new("Frame",spScWrap)
		spScTrk.Size=UDim2.new(1,-28,0,4); spScTrk.Position=UDim2.new(0,14,0.5,-2)
		spScTrk.BackgroundColor3=C_DEEP2; spScTrk.BorderSizePixel=0; addCorner(spScTrk,2)
		local spScFill=Instance.new("Frame",spScTrk)
		spScFill.Size=UDim2.new(0.44,0,1,0); spScFill.BackgroundColor3=C_MOON; spScFill.BorderSizePixel=0
		addCorner(spScFill,2)
		local spScThumb=Instance.new("TextButton",spScWrap)
		spScThumb.Size=UDim2.new(0,16,0,16); spScThumb.AnchorPoint=Vector2.new(0.5,0.5)
		spScThumb.Position=UDim2.new(0,14+0.44*(spScWrap.AbsoluteSize.X or 100),0.5,0)
		spScThumb.BackgroundColor3=C_WHITE; spScThumb.BorderSizePixel=0; spScThumb.Text=""
		spScThumb.AutoButtonColor=false; spScThumb.ZIndex=5
		addCorner(spScThumb,8); addLivingStroke(spScThumb,1)
		local _sv=5; local _sd=false
		local SP_W=180; local SP_H=194
		local function apSpSc(v)
			_sv=math.clamp(math.floor(v+0.5),1,10)
			local t=(_sv-1)/9
			spScFill.Size=UDim2.new(t,0,1,0)
			local aw=spScTrk.AbsoluteSize.X; if aw>2 then spScThumb.Position=UDim2.new(0,14+t*aw,0.5,0) end
			spScaleValLbl.Text="Scale: ".._sv.." / 10"
			local f=0.6+t*0.8
			_spExpandedSize.w = math.floor(SP_W*f)
			_spExpandedSize.h = math.floor(SP_H*f)
			-- Only resize visually if the widget isn't collapsed
			-- ("-"), otherwise the edited size is just remembered for later.
			if _GH.spW and not _spCollapsed then
				_GH.spW.Size=UDim2.new(0,_spExpandedSize.w,0,_spExpandedSize.h)
			end
		end
		spScThumb.InputBegan:Connect(function(inp)
			if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then _sd=true end
		end)
		UIS.InputChanged:Connect(function(inp)
			if not _sd then return end
			if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then
				local ax=spScTrk.AbsolutePosition.X; local aw=spScTrk.AbsoluteSize.X; if aw<2 then return end
				apSpSc(1+math.clamp((inp.Position.X-ax)/aw,0,1)*9)
			end
		end)
		UIS.InputEnded:Connect(function(inp)
			if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then _sd=false end
		end)
	end
end)

buildPage("Keybind", function()
	-- ================================================================
	-- Keybind system: PC keyboard + PlayStation/Xbox controller
	-- Inspired by Amir Hub — one "..." button per action, click → listens
	-- for the next key pressed (keyboard or gamepad)
	-- ================================================================

	-- Central bindings table (exposed for saving)
	local KB = _GH.MH_KB or {
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
	_GH.MH_KB = KB

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

	-- Short readable names for display on the button
	local function keyName(kc)
		if not kc then return "—" end
		local n = tostring(kc):gsub("Enum.KeyCode.", "")
		local map = {
			LeftControl="LCTRL", RightControl="RCTRL",
			LeftShift="LSHIFT", RightShift="RSHIFT",
			LeftAlt="LALT", RightAlt="RALT",
			LeftBracket="[", RightBracket="]",
			ButtonA="✕", ButtonB="○", ButtonX="□", ButtonY="△",
			ButtonL1="L1", ButtonR1="R1", ButtonL2="L2", ButtonR2="R2",
			ButtonL3="L3", ButtonR3="R3",
			ButtonStart="START", ButtonSelect="SEL",
			DPadUp="D↑", DPadDown="D↓", DPadLeft="D←", DPadRight="D→",
		}
		return map[n] or n:sub(1,6)
	end

	local _currentListeningBtn = nil  -- reference to the listening button, only one at a time

	local function makeKBRow(labelTxt, entry)
		local row = Instance.new("Frame", currentPage)
		row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = C_ROW
		row.BackgroundTransparency = 0.35; row.BorderSizePixel = 0; row.LayoutOrder = LO()
		addCorner(row, 12); addLivingStroke(row, 1)
		row.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.15}):Play() end)
		row.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.35}):Play() end)

		local lbl = Instance.new("TextLabel", row)
		lbl.Size = UDim2.new(1,-90,1,0); lbl.Position = UDim2.new(0,12,0,0)
		lbl.BackgroundTransparency = 1; lbl.Text = labelTxt
		lbl.TextColor3 = C_WHITE; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		addLivingTextGradient(lbl)

		local kbWrap = Instance.new("Frame", row)
		kbWrap.Size = UDim2.new(0,72,0,22); kbWrap.Position = UDim2.new(1,-80,0.5,-11)
		kbWrap.BackgroundColor3 = C_ON_BG; kbWrap.BackgroundTransparency = 0.2; kbWrap.BorderSizePixel = 0
		addCorner(kbWrap, 6); addLivingStroke(kbWrap, 1)

		local kbBtn = Instance.new("TextButton", kbWrap)
		kbBtn.Size = UDim2.new(1,0,1,0); kbBtn.BackgroundTransparency = 1
		kbBtn.Text = keyName(entry.key or entry.gp)
		kbBtn.TextColor3 = C_MOON2; kbBtn.Font = Enum.Font.GothamBold; kbBtn.TextSize = 9
		kbBtn.AutoButtonColor = false

		local conn = nil
		local timeoutThread = nil

		local function stopListening(newText)
			if conn then conn:Disconnect(); conn = nil end
			if timeoutThread then pcall(task.cancel, timeoutThread); timeoutThread = nil end
			kbBtn.Text = newText or keyName(entry.key or entry.gp)
			kbBtn.TextColor3 = C_MOON2
			if _currentListeningBtn == kbBtn then _currentListeningBtn = nil end
		end

		kbBtn.MouseButton1Click:Connect(function()
			-- If this button is already listening → cancel
			if _currentListeningBtn == kbBtn then
				stopListening(); return
			end
			-- If another button is listening → cancel it first (via its own conn)
			if _currentListeningBtn then
				-- the previous button will clean itself up via its timeout or next click
				_currentListeningBtn = nil
			end
			_currentListeningBtn = kbBtn
			local prev = kbBtn.Text
			kbBtn.Text = "..."; kbBtn.TextColor3 = C_SILVER2

			conn = UIS.InputBegan:Connect(function(inp, gpe)
				if inp.KeyCode == Enum.KeyCode.Unknown then return end
				if inp.UserInputType ~= Enum.UserInputType.Keyboard
					and not GAMEPAD_KEYS[inp.KeyCode] then return end
				if GAMEPAD_KEYS[inp.KeyCode] then
					entry.gp = inp.KeyCode; entry.key = nil
				else
					entry.key = inp.KeyCode; entry.gp = nil
				end
				stopListening(keyName(inp.KeyCode))
				if _GH.autoSave then _GH.autoSave() end
			end)

			-- 6s timeout if no key is pressed
			timeoutThread = task.delay(6, function()
				stopListening(prev)
			end)
		end)

		-- ✕ clears
		local clrBtn = Instance.new("TextButton", row)
		clrBtn.Size = UDim2.new(0,14,0,14); clrBtn.Position = UDim2.new(1,-158,0.5,-7)
		clrBtn.BackgroundColor3 = C_RED; clrBtn.BackgroundTransparency = 0.4
		clrBtn.BorderSizePixel = 0; clrBtn.Text = "✕"; clrBtn.TextColor3 = C_WHITE
		clrBtn.Font = Enum.Font.GothamBold; clrBtn.TextSize = 8; clrBtn.AutoButtonColor = false
		addCorner(clrBtn, 4)
		clrBtn.MouseButton1Click:Connect(function()
			entry.key = nil; entry.gp = nil
			kbBtn.Text = "—"; kbBtn.TextColor3 = C_DIM
			if _GH.autoSave then _GH.autoSave() end
		end)

		local div = Instance.new("Frame", currentPage)
		div.Size = UDim2.new(1,-8,0,1); div.BackgroundColor3 = C_DEEP3
		div.BorderSizePixel = 0; div.LayoutOrder = LO()
		addLivingTextGradient(div)

		return entry
	end

	UIB.makeSectionLabel("Quick Panel")
	makeKBRow("Antibat Aimbot", KB.AntiBatAimbot)
	makeKBRow("Drop BR",        KB.DropBR)
	makeKBRow("Auto Left",      KB.AutoLeft)
	makeKBRow("Aim Bot",        KB.AimBot)
	makeKBRow("Auto Right",     KB.AutoRight)
	makeKBRow("TP Down",        KB.TPDown)
	makeKBRow("Lag Normal",     KB.LagNorm)
	makeKBRow("Bat TP",         KB.BatTP)
	makeKBRow("Aim V2",         KB.AimV2)
	makeKBRow("Aim V3",         KB.AimV3Kb)
	makeKBRow("Instant Reset",  KB.InstantReset)
	UIB.makeGap(4)
	UIB.makeSectionLabel("Interface")
	makeKBRow("Hide / Show UI", KB.HideUI)

	UIB.makeGap(6)
	local hint = Instance.new("TextLabel", currentPage)
	hint.Size = UDim2.new(1,0,0,28); hint.BackgroundTransparency = 1; hint.LayoutOrder = LO()
	hint.Text = "Click → listen   |   ✕ → clear   |   PC & PS/Xbox"
	hint.TextColor3 = C_DIM; hint.Font = Enum.Font.Gotham; hint.TextSize = 9
	addLivingTextGradient(hint)

	-- ================================================================
	-- Global UIS.InputBegan loop — triggers the bound actions
	-- ================================================================
	UIS.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		if _currentListeningBtn then return end  -- un rebind est en cours
		if UIS:GetFocusedTextBox() then return end
		local kc = inp.KeyCode
		if kc == Enum.KeyCode.Unknown then return end

		local function match(e)
			return (e.key and kc == e.key) or (e.gp and kc == e.gp)
		end

		if match(KB.AntiBatAimbot) then applyAntiBatState(not BC.active)
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
			-- [FIX #2] AimV3Kb doit déclencher AimV3 (Bat TP), pas AB (Aimbot V1)
			if AimV3.active then AimV3.stop() else AimV3.start() end
		elseif match(KB.InstantReset) then
			if _GH.MH_instareset then _GH.MH_instareset() end
		elseif match(KB.HideUI) then
			if mainOuter.Visible then hideGui() else showGui() end
		end
	end)
end)

-- ===================================================================
-- REVUL ANTI LAGGER — engine (snapshot + restore, DescendantAdded hook)
-- ===================================================================
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

-- Initial snapshot of all workspace descendants
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

buildPage("Optimize", function()
	UIB.makeSectionLabel("Performance")
	UIB.makeToggleRow("Nuke Optimizer",false,function(on) State.nukeOptEnabled=on; if on then nukeOptStart() else nukeOptStop() end end)
	UIB.makeToggleRow("Remove Accessories",false,function(on) State.removeAccEnabled=on; if on then removeAccStart() else removeAccStop() end end)
	UIB.makeToggleRow("Anti-Lag (Light)",false,function(on) State.antiLagAdvEnabled=on; if on then antiLagAdvStart() else antiLagAdvStop() end end)
	UIB.makeToggleRow("Anti-Lag Booster",false,function(on) if on then ralStart() else ralStop() end end)
	UIB.makeToggleRow("Ultra Mode",false,function(on)
		if on then
			-- raw__59_ logic: plastic-coats everything, disables decals/particles
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
	end)
	UIB.makeToggleRow("Unwalk",false,function(on) if on then startUnwalk() else stopUnwalk() end end)
	UIB.makeGap(4); UIB.makeSectionLabel("Camera")
	do
		local _ncOn = false
		local _ncParts = {}
		local _ncConn = nil
		UIB.makeToggleRow("No Cam Collision",false,function(on)
			_ncOn = on
			if on then
				if _ncConn then _ncConn:Disconnect() end
				_ncConn = RunService.RenderStepped:Connect(function()
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
							if _ncParts[p2]==nil then _ncParts[p2]=p2.LocalTransparencyModifier end
							p2.LocalTransparencyModifier=1
						end
						origin=res.Position+remaining.Unit*0.02; remaining=charPos-origin
					end
					for p2,orig in pairs(_ncParts) do
						if not hit[p2] then
							pcall(function() if p2 and p2.Parent then p2.LocalTransparencyModifier=orig end end)
							_ncParts[p2]=nil
						end
					end
				end)
			else
				if _ncConn then _ncConn:Disconnect(); _ncConn=nil end
				for p2,orig in pairs(_ncParts) do
					pcall(function() if p2 and p2.Parent then p2.LocalTransparencyModifier=orig end end)
				end
				_ncParts={}
			end
		end)
	end
	UIB.makeGap(4); UIB.makeSectionLabel("Cleanup")
	local cleanRow=Instance.new("TextButton",currentPage)
	cleanRow.Size=UDim2.new(1,0,0,30); cleanRow.BackgroundColor3=C_ROW; cleanRow.BackgroundTransparency=0.35
	cleanRow.BorderSizePixel=0; cleanRow.LayoutOrder=LO(); addCorner(cleanRow,6); addLivingStroke(cleanRow,1)
	cleanRow.Text="Clean Particles & Lights"; cleanRow.TextColor3=C_WHITE; cleanRow.Font=Enum.Font.GothamBold
	cleanRow.TextSize=10; cleanRow.AutoButtonColor=false; addLivingTextGradient(cleanRow)
	cleanRow.MouseButton1Click:Connect(function()
		local n=cleanParticlesAndLights(); cleanRow.Text="Cleaned "..n.." effects"
		task.delay(1.2,function() if cleanRow and cleanRow.Parent then cleanRow.Text="Clean Particles & Lights" end end)
	end)
end)

-- ===================================================================
-- ANTI BAT WIDGET
-- ===================================================================
-- Anti Bat + Infinite Jump logic (no widget — via QP button only)
applyAntiBatState=function(on)
	BC.active=on; if on then BC.start() else BC.stop() end
	if on then
		if not IJ.active then IJ.active=true; IJ.start() end
	end
	if _GH.autoSave then _GH.autoSave() end
end

-- ===================================================================
-- SPEED WIDGET (jxsh — Anti Bat style)
-- ===================================================================
local function _buildSpeedWidget()
local spW=Instance.new("Frame",gui)
spW.Name=_NS.."a"; spW.Size=UDim2.new(0,150,0,160); _GH.spW=spW
spW.Position=UDim2.new(1,-256,0,210); spW.BackgroundColor3=C_BG
spW.BorderSizePixel=0; spW.ClipsDescendants=true; spW.Active=true; spW.Visible=false
addCorner(spW,12); addLivingStroke(spW,1.5)
local spH=Instance.new("Frame",spW)
spH.Size=UDim2.new(1,0,0,26); spH.BackgroundColor3=C_HEADER; spH.BorderSizePixel=0
addCorner(spH,12); makeDraggable(spW, spH, "speed")
local spDot=Instance.new("Frame",spH)
spDot.Size=UDim2.new(0,5,0,5); spDot.Position=UDim2.new(0,10,0,11)
spDot.BackgroundColor3=C_MOON; spDot.BorderSizePixel=0; addCorner(spDot,3)
local spTitleLbl=Instance.new("TextLabel",spH)
spTitleLbl.Size=UDim2.new(1,-46,1,0); spTitleLbl.Position=UDim2.new(0,16,0,0)
spTitleLbl.BackgroundTransparency=1; spTitleLbl.Text="SPEED BOOSTER"
spTitleLbl.TextColor3=C_WHITE; spTitleLbl.Font=Enum.Font.GothamBlack; spTitleLbl.TextSize=9
spTitleLbl.TextXAlignment=Enum.TextXAlignment.Left; addLivingTextGradient(spTitleLbl)
-- Minimize button: collapsed by default = expanded (Normal/Lagger visible),
-- the user can click "-" to collapse it if they want
local spCollapsedH=64
local spMinBtn=Instance.new("TextButton",spH)
spMinBtn.Size=UDim2.new(0,18,0,18); spMinBtn.Position=UDim2.new(1,-24,0.5,-9)
spMinBtn.BackgroundColor3=Color3.fromRGB(30,30,34); spMinBtn.BorderSizePixel=0
spMinBtn.Text="-"; spMinBtn.TextColor3=C_WHITE; spMinBtn.Font=Enum.Font.GothamBlack; spMinBtn.TextSize=15
addCorner(spMinBtn,6); addLivingStroke(spMinBtn,1)
-- The click is connected further down (after stRow/spNorm/spLag/_spLagger)
-- to keep NORMAL/LAGGER visible and usable even when collapsed.
-- NORMAL / LAGGER Tabs
local tabRow=Instance.new("Frame",spW)
tabRow.Size=UDim2.new(1,-16,0,26); tabRow.Position=UDim2.new(0,8,0,32)
tabRow.BackgroundColor3=C_ROW; tabRow.BackgroundTransparency=0.35
tabRow.BorderSizePixel=0; addCorner(tabRow,8); addLivingStroke(tabRow,1)
local tabLL=Instance.new("UIListLayout",tabRow)
tabLL.FillDirection=Enum.FillDirection.Horizontal; tabLL.SortOrder=Enum.SortOrder.LayoutOrder
tabLL.HorizontalAlignment=Enum.HorizontalAlignment.Center
tabLL.Padding=UDim.new(0,0)
local function mkTab(lbl,ord,act)
	local t=Instance.new("TextButton",tabRow); t.Size=UDim2.new(0.5,0,1,0); t.AnchorPoint=Vector2.new(0,0)
	t.BorderSizePixel=0; t.LayoutOrder=ord
	t.BackgroundColor3=act and C_MOON or C_OFF_BG
	t.BackgroundTransparency=act and 0.15 or 0.5
	t.Text=lbl; t.TextColor3=act and Color3.fromRGB(0,10,20) or C_DIM
	t.Font=Enum.Font.GothamBold; t.TextSize=10; t.AutoButtonColor=false
	addCorner(t,6); addLivingTextGradient(t); return t
end
local spTabN=mkTab("NORMAL",1,true); local spTabL=mkTab("LAGGER",2,false)
-- Status ON/OFF
local stRow=Instance.new("Frame",spW)
stRow.Size=UDim2.new(1,-16,0,26); stRow.Position=UDim2.new(0,8,0,64)
stRow.BackgroundColor3=C_ROW; stRow.BackgroundTransparency=0.35
stRow.BorderSizePixel=0; addCorner(stRow,8); addLivingStroke(stRow,1)
local stLbl=Instance.new("TextLabel",stRow)
stLbl.Size=UDim2.new(0.5,0,1,0); stLbl.Position=UDim2.new(0,12,0,0)
stLbl.BackgroundTransparency=1; stLbl.Text="Status:"
stLbl.TextColor3=C_WHITE; stLbl.Font=Enum.Font.GothamBold; stLbl.TextSize=11
stLbl.TextXAlignment=Enum.TextXAlignment.Left; addLivingTextGradient(stLbl)
local stPill=Instance.new("Frame",stRow)
stPill.Size=UDim2.new(0.44,0,0,22); stPill.Position=UDim2.new(0.54,0,0.5,-11)
stPill.BackgroundColor3=C_OFF_BG; stPill.BorderSizePixel=0; addCorner(stPill,6); addLivingStroke(stPill,1)
local stPillLbl=Instance.new("TextLabel",stPill)
stPillLbl.Size=UDim2.new(1,0,1,0); stPillLbl.BackgroundTransparency=1
stPillLbl.Text="OFF"; stPillLbl.TextColor3=C_DIM
stPillLbl.Font=Enum.Font.GothamBlack; stPillLbl.TextSize=11; addLivingTextGradient(stPillLbl)
local stClk=Instance.new("TextButton",stRow)
stClk.Size=UDim2.new(1,0,1,0); stClk.BackgroundTransparency=1; stClk.Text=""
-- Input helper
_G._mhInputBoxesRef = _G._mhInputBoxesRef or {}
local _mhInputBoxes = _G._mhInputBoxesRef
local function mkInput(parent,yPos,lbl,val,cb,stateKey)
	local row=Instance.new("Frame",parent)
	row.Size=UDim2.new(1,-16,0,28); row.Position=UDim2.new(0,8,0,yPos)
	row.BackgroundColor3=C_ROW; row.BackgroundTransparency=0.35
	row.BorderSizePixel=0; addCorner(row,8); addLivingStroke(row,1)
	local l=Instance.new("TextLabel",row)
	l.Size=UDim2.new(1,-80,1,0); l.Position=UDim2.new(0,12,0,0)
	l.BackgroundTransparency=1; l.Text=lbl; l.TextColor3=C_WHITE
	l.Font=Enum.Font.GothamBold; l.TextSize=11; l.TextXAlignment=Enum.TextXAlignment.Left
	addLivingTextGradient(l)
	local bw=Instance.new("Frame",row)
	bw.Size=UDim2.new(0,62,0,22); bw.Position=UDim2.new(1,-70,0.5,-11)
	bw.BackgroundColor3=C_OFF_BG; bw.BackgroundTransparency=0.1
	bw.BorderSizePixel=0; addCorner(bw,6); addLivingStroke(bw,1)
	local box=Instance.new("TextBox",bw)
	box.Size=UDim2.new(1,-6,1,0); box.Position=UDim2.new(0,3,0,0)
	box.BackgroundTransparency=1; box.Text=tostring(val)
	box.TextColor3=C_SILVER; box.Font=Enum.Font.GothamBold; box.TextSize=12
	box.ClearTextOnFocus=false; box.TextXAlignment=Enum.TextXAlignment.Center
	box.FocusLost:Connect(function()
		local n=tonumber(box.Text)
		if n and n>0 and n<=500 then
			cb(n)
			if _GH.autoSave then _GH.autoSave() end
		else box.Text=tostring(val) end
	end)
	if stateKey then _mhInputBoxes[stateKey] = box end
end
-- Normal / Lagger panels
local spNorm=Instance.new("Frame",spW)
spNorm.Size=UDim2.new(1,0,0,68); spNorm.Position=UDim2.new(0,0,0,96)
spNorm.BackgroundTransparency=1; spNorm.BorderSizePixel=0
mkInput(spNorm,0,  "Speed",     State.normalSpeed,     function(n) State.normalSpeed=n end, "normalSpeed")
mkInput(spNorm,40, "Steal Spd", State.carrySpeed,      function(n) State.carrySpeed=n end, "carrySpeed")
local spLag=Instance.new("Frame",spW)
spLag.Size=UDim2.new(1,0,0,68); spLag.Position=UDim2.new(0,0,0,96)
spLag.BackgroundTransparency=1; spLag.BorderSizePixel=0; spLag.Visible=false
mkInput(spLag,0,  "Lagger",    State.laggerSpeed,     function(n) State.laggerSpeed=n end, "laggerSpeed")
mkInput(spLag,40, "Lag Steal", State.laggerCarrySpeed, function(n) State.laggerCarrySpeed=n end, "laggerCarrySpeed")
-- Exact jxsh logic — uses proxyMove + State like the hub
local _spActive=false; local _spLagger=false
local function startSp()
	_speedBoosterActive = true
	-- Activates lagger or normal mode via State (proxyMove uses it automatically)
	if _spLagger then
		State.laggerActive=true; State.laggerCarryActive=false
	else
		State.laggerActive=false; State.laggerCarryActive=false
		State.speedType="normal"
	end
end
local function stopSp()
	_speedBoosterActive = false
	-- Disables everything and stops the proxy
	State.laggerActive=false; State.laggerCarryActive=false
	State.speedType="normal"
	proxyStop()
end
local function toggleSp()
	_spActive=not _spActive
	stPill.BackgroundColor3=_spActive and C_MOON or C_OFF_BG
	stPillLbl.Text=_spActive and "ON" or "OFF"
	stPillLbl.TextColor3=_spActive and Color3.fromRGB(0,10,20) or C_DIM
	if _spActive then startSp() else stopSp() end
	if _GH.setSpeedBoosterFloatVisual then _GH.setSpeedBoosterFloatVisual(_spActive) end
end
stClk.MouseButton1Click:Connect(toggleSp)
_GH.speedBoosterToggle = toggleSp
_GH.speedBoosterIsActive = function() return _spActive end
local function switchTab(lag)
	_spLagger=lag
	if _spActive then startSp() end
	spTabN.BackgroundColor3=lag and C_OFF_BG or C_MOON
	spTabN.BackgroundTransparency=lag and 0.5 or 0.15
	spTabN.TextColor3=lag and C_DIM or Color3.fromRGB(0,10,20)
	spTabL.BackgroundColor3=lag and C_MOON or C_OFF_BG
	spTabL.BackgroundTransparency=lag and 0.15 or 0.5
	spTabL.TextColor3=lag and Color3.fromRGB(0,10,20) or C_DIM
	spNorm.Visible=not lag; spLag.Visible=lag
end
spTabN.MouseButton1Click:Connect(function() switchTab(false) end)
spTabL.MouseButton1Click:Connect(function() switchTab(true) end)

-- Collapsed ("-"): NORMAL/LAGGER stay visible and usable, only
-- Status and the speed fields are hidden.
spMinBtn.MouseButton1Click:Connect(function()
	_spCollapsed = not _spCollapsed
	if _spCollapsed then
		spW.Size=UDim2.new(0,_spExpandedSize.w,0,spCollapsedH)
	else
		-- Restores the size edited via the Scale slider (Visual), not a
		-- hardcoded default size.
		spW.Size=UDim2.new(0,_spExpandedSize.w,0,_spExpandedSize.h)
	end
	spMinBtn.Text=_spCollapsed and "+" or "-"
	stRow.Visible = not _spCollapsed
	if _spCollapsed then
		spNorm.Visible=false; spLag.Visible=false
	else
		spNorm.Visible = not _spLagger; spLag.Visible = _spLagger
	end
end)

-- Scale slider (same style as UIScale in Visual)

end
_buildSpeedWidget()

-- ===================================================================
-- STEAL BAR WIDGET
-- ===================================================================
do
local stealWidget=Instance.new("Frame",gui)
stealWidget.Name=_NS.."b"; stealWidget.Size=UDim2.new(0,200,0,32)
stealWidget.Position=UDim2.new(0.5,-100,0,35); stealWidget.BackgroundTransparency=1; stealWidget.Active=true
makeDraggable(stealWidget, nil, "steal")
local stealPill=Instance.new("Frame",stealWidget)
stealPill.Size=UDim2.new(1,0,0,32); stealPill.BackgroundColor3=C_BG
stealPill.BackgroundTransparency=0.1; stealPill.BorderSizePixel=0; stealPill.ClipsDescendants=true
addCorner(stealPill,18)
local stealPillStk=addStroke(stealPill,C_MOON,1.5,0.2)
local stealPulseSpeed=1.2
AutoSteal.SetFastPulse=function(on) stealPulseSpeed=on and 0.35 or 1.2 end
task.spawn(function()
	while stealPill.Parent do
		TweenService:Create(stealPillStk,TweenInfo.new(stealPulseSpeed,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=0.6}):Play()
		task.wait(stealPulseSpeed)
		TweenService:Create(stealPillStk,TweenInfo.new(stealPulseSpeed,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=0.1}):Play()
		task.wait(stealPulseSpeed)
	end
end)
AutoSteal.FlashSuccess=function()
	TweenService:Create(stealPillStk,TweenInfo.new(0.08),{Color=C_WHITE,Transparency=0}):Play()
	TweenService:Create(stealPill,TweenInfo.new(0.08),{BackgroundTransparency=0}):Play()
	task.delay(0.08,function()
		TweenService:Create(stealPillStk,TweenInfo.new(0.35),{Color=C_MOON,Transparency=0.1}):Play()
		TweenService:Create(stealPill,TweenInfo.new(0.35),{BackgroundTransparency=0.1}):Play()
	end)
end
local stealLeftHalf=Instance.new("Frame",stealPill)
stealLeftHalf.Size=UDim2.new(0.56,0,1,0); stealLeftHalf.BackgroundTransparency=1; stealLeftHalf.ZIndex=6
local stealLabel=Instance.new("TextLabel",stealLeftHalf)
stealLabel.Size=UDim2.new(1,-20,1,0); stealLabel.Position=UDim2.new(0,12,0,0)
stealLabel.BackgroundTransparency=1; stealLabel.Text="READY"
stealLabel.TextColor3=C_WHITE; stealLabel.Font=Enum.Font.GothamBlack; stealLabel.TextSize=11
stealLabel.TextXAlignment=Enum.TextXAlignment.Left; stealLabel.ZIndex=6; addLivingTextGradient(stealLabel)
local stealDivider=Instance.new("Frame",stealPill)
stealDivider.Size=UDim2.new(0,1,0,18); stealDivider.Position=UDim2.new(0.56,0,0.5,-9)
stealDivider.BackgroundColor3=C_SILVER2; stealDivider.BackgroundTransparency=0.4; stealDivider.BorderSizePixel=0; stealDivider.ZIndex=6
local infoLabel=Instance.new("TextLabel",stealPill)
infoLabel.Size=UDim2.new(0.44,-12,1,0); infoLabel.Position=UDim2.new(0.56,12,0,0)
infoLabel.BackgroundTransparency=1; infoLabel.Text="0 FPS | --ms"
infoLabel.TextColor3=C_WHITE; infoLabel.Font=Enum.Font.GothamBold; infoLabel.TextSize=11
infoLabel.TextXAlignment=Enum.TextXAlignment.Left; infoLabel.ZIndex=6
local stealFill=Instance.new("Frame",stealPill)
stealFill.Size=UDim2.new(0,0,1,0); stealFill.BackgroundColor3=C_MOON
stealFill.BackgroundTransparency=0.72; stealFill.BorderSizePixel=0; stealFill.ZIndex=1
addCorner(stealFill,18)
local stealFillGrad=Instance.new("UIGradient",stealFill)
stealFillGrad.Color=ColorSequence.new({
	ColorSequenceKeypoint.new(0,    Color3.fromRGB(10,  30,  90)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(40,  110, 230)),
	ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(150, 210, 255)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(40,  110, 230)),
	ColorSequenceKeypoint.new(1,    Color3.fromRGB(10,  30,  90)),
})
table.insert(_livingGradients, stealFillGrad)
_GH.stealFillGradRef = stealFillGrad
local stealEdge=Instance.new("Frame",stealFill)
stealEdge.AnchorPoint=Vector2.new(1,0.5); stealEdge.Size=UDim2.new(0,4,1,-6); stealEdge.Position=UDim2.new(1,0,0.5,0)
stealEdge.BackgroundColor3=C_WHITE; stealEdge.BorderSizePixel=0; stealEdge.ZIndex=2; addCorner(stealEdge,2)
local stealPctLbl=Instance.new("TextLabel",stealLeftHalf)
stealPctLbl.Size=UDim2.new(1,-32,1,0); stealPctLbl.Position=UDim2.new(0,12,0,0)
stealPctLbl.BackgroundTransparency=1; stealPctLbl.Text=""
stealPctLbl.TextColor3=C_MOON2; stealPctLbl.Font=Enum.Font.GothamBlack; stealPctLbl.TextSize=11
stealPctLbl.TextXAlignment=Enum.TextXAlignment.Right; stealPctLbl.ZIndex=6
AutoSteal.ProgressFill=stealFill; AutoSteal.ProgressText=stealPctLbl; AutoSteal.Widget=stealWidget; AutoSteal.StatusLabel=stealLabel
task.spawn(function() task.wait(0.6); if AutoSteal.SetReadyColor then AutoSteal.SetReadyColor("READY") end end)
local _lastReadyState = "READY"
local function _setReadyColor(state)
	_lastReadyState = state or _lastReadyState
	local lbl = AutoSteal.StatusLabel; if not lbl then return end
	local isReady = (_lastReadyState == "READY")
	local isNoir = (_currentTheme == "noir")
	local col = isReady and C_MOON or C_RED
	lbl.TextColor3 = col
	local g = lbl:FindFirstChildOfClass("UIGradient")
	if g then
		local c1, c2
		if isReady and isNoir then
			c1 = Color3.fromRGB(80,  80,  80)
			c2 = Color3.fromRGB(210, 210, 210)
		elseif isReady then
			c1 = Color3.fromRGB(20,  70,  140)
			c2 = Color3.fromRGB(120, 180, 255)
		else
			c1 = Color3.fromRGB(120, 20,  20)
			c2 = Color3.fromRGB(255, 100, 100)
		end
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,    c2),
			ColorSequenceKeypoint.new(0.25, c1),
			ColorSequenceKeypoint.new(0.5,  c2),
			ColorSequenceKeypoint.new(0.75, c1),
			ColorSequenceKeypoint.new(1,    c2),
		})
	end
end
AutoSteal.SetReadyColor = _setReadyColor
_GH.stealReadyColorFn = function() _setReadyColor(nil) end
local Stats=game:GetService("Stats")
local frameCount,lastFpsTime,lastFps,lastPing=0,tick(),60,nil
local function refreshInfoLabel()
	infoLabel.Text = lastFps.." FPS | "..(lastPing and (lastPing.."ms") or "--ms")
end
RunService.RenderStepped:Connect(function()
	frameCount=frameCount+1; local now=tick()
	if now-lastFpsTime>=1 then
		lastFps=math.floor(frameCount/(now-lastFpsTime)); frameCount=0; lastFpsTime=now; refreshInfoLabel()
	end
end)
-- Only update lastPing if the fetch succeeded, otherwise keep the
-- last known value instead of falling back to 0 (bug: display stuck at "0ms").
task.spawn(function()
	while stealWidget.Parent do
		local success, ping = pcall(function()
			local netStats = Stats:FindFirstChild("Network")
			if not netStats then return nil end
			local sci = netStats:FindFirstChild("ServerStatsItem")
			if not sci then return nil end
			local dp = sci:FindFirstChild("Data Ping")
			if not dp then return nil end
			return math.floor(dp:GetValue() or 0)
		end)
		if success and type(ping) == "number" then
			lastPing = ping
			refreshInfoLabel()
		end
		task.wait(0.5)
	end
end)
end

-- ===================================================================
-- FLOATING BUTTONS — replaces the fixed Quick Panel + attach/detach.
-- Each action has a toggle in Settings that spawns/despawns its
-- own floating square button. "Lock" freezes the drag once placed.
-- ===================================================================
-- Stable order (independent of activation order) so buttons always line
-- up in the same compact block: Anti Bat Aimbot wide on top, the other
-- 8 packed right below it in a tight 2-wide grid (4 rows).
local _FLOAT_GRID_ORDER = {
	"aimbot","aimv2","dropbr","autoleft",
	"autoright","tpdown","battp","instareset",
}
local function _floatGridIndex(id)
	for i, fid in ipairs(_FLOAT_GRID_ORDER) do
		if fid == id then return i end
	end
	return #_FLOAT_GRID_ORDER + 1
end

local function makeFloatButton(id)
	if _floatBtns[id] then return _floatBtns[id] end
	local def = _floatDefs[id]; if not def then return nil end

	local btn = Instance.new("TextButton", gui)
	btn.Name = "Float_"..id
	local saved = _floatPositions[id]
	local GAP = 3
	local blockW = FLOAT_SZ * 2 + GAP
	if id == "antibat" then
		-- Wide standalone button, top of the block.
		btn.Size = UDim2.new(0, blockW, 0, FLOAT_WIDE_H)
		if saved then
			btn.Position = UDim2.new(saved[1], saved[2], saved[3], saved[4])
		else
			btn.Position = UDim2.new(0, 12, 0, 55)
		end
	else
		btn.Size = UDim2.new(0, FLOAT_SZ, 0, FLOAT_SZ)
		if saved then
			btn.Position = UDim2.new(saved[1], saved[2], saved[3], saved[4])
		else
			-- Tight 2-wide grid right under the Anti Bat bar, same block.
			local idx = _floatGridIndex(id) - 1
			local col = idx % 2
			local row = math.floor(idx / 2)
			local topOffset = 55 + FLOAT_WIDE_H + GAP
			btn.Position = UDim2.new(1, -(blockW + 12) + col * (FLOAT_SZ + GAP), 0, topOffset + row * (FLOAT_SZ + GAP))
		end
	end
	btn.BackgroundColor3 = C_ROW; btn.BackgroundTransparency = 0; btn.BorderSizePixel = 0
	btn.Text = def.label; btn.TextColor3 = C_WHITE; btn.Font = Enum.Font.GothamBold
	btn.TextScaled = false; btn.TextSize = 9; btn.TextWrapped = true; btn.AutoButtonColor = false
	btn.ZIndex = 500; btn.Active = true
	addCorner(btn, 14); addLivingStroke(btn, 1); addLivingTextGradient(btn)
	local pad = Instance.new("UIPadding", btn)
	pad.PaddingLeft = UDim.new(0,4); pad.PaddingRight = UDim.new(0,4)
	pad.PaddingTop = UDim.new(0,3); pad.PaddingBottom = UDim.new(0,3)

	local function setActive(on)
		btn.BackgroundColor3 = on and C_ON_BG or C_ROW
		TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
	end

	-- Drag (disabled when locked)
	local drag, ds, dp = false, nil, nil
	btn.InputBegan:Connect(function(inp)
		if _floatLocked then return end
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			drag = true; ds = inp.Position; dp = btn.Position
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then
					drag = false
					local p2 = btn.Position
					_floatPositions[id] = {p2.X.Scale, p2.X.Offset, p2.Y.Scale, p2.Y.Offset}
					if _GH.autoSave then _GH.autoSave() end
				end
			end)
		end
	end)
	btn.InputChanged:Connect(function(inp)
		if _floatLocked or not drag or not ds then return end
		if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
			local d = inp.Position - ds
			btn.Position = UDim2.new(dp.X.Scale, dp.X.Offset + d.X, dp.Y.Scale, dp.Y.Offset + d.Y)
		end
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5}):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
	end)
	btn.MouseButton1Click:Connect(function()
		if def.onClick then def.onClick() end
		if def.momentary then
			setActive(true)
			task.delay(0.2, function() setActive(false) end)
		elseif def.isActive then
			setActive(def.isActive())
		end
	end)

	_floatBtns[id] = {frame = btn, setActive = setActive}
	if def.isActive then setActive(def.isActive()) end
	return _floatBtns[id]
end

local function removeFloatButton(id)
	local entry = _floatBtns[id]
	if entry then entry.frame:Destroy(); _floatBtns[id] = nil end
end

local function setFloatLocked(on)
	_floatLocked = on
end

-- Periodic visual sync (real ON/OFF state, no matter where
-- the change came from — clicking the button, a keybind, or another toggle)
task.spawn(function()
	while gui.Parent do
		for id, entry in pairs(_floatBtns) do
			local def = _floatDefs[id]
			if def and def.isActive and not def.momentary then
				entry.setActive(def.isActive())
			end
		end
		task.wait(0.3)
	end
end)

-- Force-refresh all float button background colors against current C_ON_BG.
-- Called by applyTheme and at end of MH_load so theme switches / load order
-- can never leave buttons in the wrong color.
_GH.refreshFloatActiveColors = function()
	for id, entry in pairs(_floatBtns) do
		local def = _floatDefs[id]
		if def and entry.frame and entry.frame.Parent then
			if def.isActive and not def.momentary then
				entry.setActive(def.isActive())
			else
				entry.setActive(false)
			end
		end
	end
end

-- ── Action registration ──────────────────────────────────────
_floatDefs.antibat = {
	label = "ANTIBAT\nAIMBOT",
	onClick = function() applyAntiBatState(not BC.active) end,
	isActive = function() return BC.active end,
}
_floatDefs.dropbr = {
	label = "DROP BR",
	onClick = function() runDropBrainrot() end,
	momentary = true,
}
_floatDefs.autoleft = {
	label = "AUTO\nLEFT",
	onClick = function()
		State.autoLeftEnabled = not State.autoLeftEnabled
		if State.autoLeftEnabled then startAutoLeft() else stopAutoLeft() end
	end,
	isActive = function() return State.autoLeftEnabled end,
}
_floatDefs.aimbot = {
	label = "AIM BOT",
	onClick = function()
		local on = not AB.active
		if on then if ABP.active then ABP.stop() end; AB.start() else AB.stop() end
	end,
	isActive = function() return AB.active end,
}
_floatDefs.autoright = {
	label = "AUTO\nRIGHT",
	onClick = function()
		State.autoRightEnabled = not State.autoRightEnabled
		if State.autoRightEnabled then startAutoRight() else stopAutoRight() end
	end,
	isActive = function() return State.autoRightEnabled end,
}
_floatDefs.tpdown = {
	label = "TP DOWN",
	onClick = function() tpToGround() end,
	momentary = true,
}
_floatDefs.battp = {
	label = "BAT TP",
	onClick = function()
		local on = not AimV3.active
		if on then AimV3.start() else AimV3.stop() end
	end,
	isActive = function() return AimV3.active end,
}

-- ===================================================================
-- INSTA RESET — logique ACE exacte (AceCursedInstaReset)
-- ===================================================================
do
	local IR_GUID        = "f888ee6e-c86d-46e1-93d7-0639d6635d42"
	local IR_resetRemote = nil

	-- Hook FireServer : capture le remote dès sa première utilisation (newcclosure = invisible)
	pcall(function()
		if not (hookfunction and newcclosure) then return end
		local oldFire
		oldFire = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
			if not IR_resetRemote and typeof(self) == "Instance"
			and self:IsA("RemoteEvent") and self.Name:sub(1,3) == "RE/" then
				IR_resetRemote = self
			end
			return oldFire(self, ...)
		end))
	end)

	local function instareset()
		-- Fallback scan ReplicatedStorage si le remote n'a pas encore été intercepté
		if not IR_resetRemote then
			for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
				if desc:IsA("RemoteEvent") and desc.Name:sub(1,3) == "RE/" then
					IR_resetRemote = desc
					break
				end
			end
		end
		if not IR_resetRemote then return end

		local character = LP.Character
		local humanoid  = character and character:FindFirstChildOfClass("Humanoid")

		-- Si déjà mort : un seul fire et on sort
		if humanoid and humanoid.Health <= 0 then
			pcall(function() IR_resetRemote:FireServer(IR_GUID, LP, "balloon") end)
			return
		end

		-- Watch 3 signaux pour détecter le reset dès qu'il se produit
		local resetDetected = false
		local resetConns    = {}
		if humanoid then
			table.insert(resetConns, humanoid.Died:Connect(function()
				resetDetected = true
			end))
			table.insert(resetConns, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
				if humanoid.Health <= 0 then resetDetected = true end
			end))
		end
		if character then
			table.insert(resetConns, character.AncestryChanged:Connect(function(_, parent)
				if not parent then resetDetected = true end
			end))
		end

		-- 10 essais à 0.05s — s'arrête dès que resetDetected
		task.spawn(function()
			for _ = 1, 10 do
				if resetDetected then break end
				pcall(function() IR_resetRemote:FireServer(IR_GUID, LP, "balloon") end)
				task.wait(0.05)
			end
			for _, conn in ipairs(resetConns) do
				pcall(function() conn:Disconnect() end)
			end
		end)
	end

	_GH.MH_instareset = instareset

	_floatDefs.instareset = {
		label    = "INSTANT\nRESET",
		onClick  = instareset,
		momentary = true,
	}
end

_floatDefs.aimv2 = {
	label = "AIM V2",
	onClick = function()
		local on = not ABP.active
		if on then if AB.active then AB.stop() end; ABP.start() else ABP.stop() end
	end,
	isActive = function() return ABP.active end,
}

_GH.makeFloatButton   = makeFloatButton
_GH.removeFloatButton = removeFloatButton
_GH.setFloatLocked    = setFloatLocked
_GH.floatDefs         = _floatDefs
_GH.floatPositions    = _floatPositions

-- ===================================================================
-- STUN TIMER BILLBOARD (au-dessus du personnage)
-- STUN TIMER BILLBOARD (above the character)
-- 3 → red | 2 → yellow | 1 → cyan | 0 → "GO" green
do
	local STUN_DURATION   = 3.0
	local stunActive      = false
	local stunStartTime   = 0
	local stunConn        = nil
	local stateConn       = nil
	local lastSec         = nil
	local bbGui           = nil
	local timerLbl        = nil

	local speedLbl = nil

	local function createBB()
		if bbGui then return end
		local char = LP.Character; if not char then return end
		local head = char:FindFirstChild("Head"); if not head then return end
		bbGui = Instance.new("BillboardGui", head)
		bbGui.Name = _NS
		bbGui.Size = UDim2.new(0,130,0,52)
		bbGui.StudsOffset = Vector3.new(0,3.5,0)
		bbGui.AlwaysOnTop = true
		-- "speed" label (above)
		speedLbl = Instance.new("TextLabel", bbGui)
		speedLbl.Size = UDim2.new(1,0,0,26)
		speedLbl.Position = UDim2.new(0,0,0,0)
		speedLbl.BackgroundTransparency = 1
		speedLbl.Text = "Speed: 0"
		speedLbl.TextColor3 = Color3.new(1,1,1)
		speedLbl.TextScaled = false
		speedLbl.TextSize = 19
		speedLbl.Font = Enum.Font.GothamBlack
		speedLbl.TextStrokeTransparency = 1
		speedLbl.TextXAlignment = Enum.TextXAlignment.Center
		addGreyShimmer(speedLbl)
		-- READY!! / timer label (below)
		timerLbl = Instance.new("TextLabel", bbGui)
		timerLbl.Size = UDim2.new(1,0,0,28)
		timerLbl.Position = UDim2.new(0,0,0,24)
		timerLbl.BackgroundTransparency = 1
		timerLbl.Text = "READY!!"
		timerLbl.TextColor3 = Color3.new(1,1,1)
		timerLbl.TextScaled = true
		timerLbl.Font = Enum.Font.GothamBlack
		timerLbl.TextStrokeTransparency = 1
		addGreyShimmer(timerLbl)
		_GH.speedLblRef = speedLbl
		_GH.timerLblRef = timerLbl
	end

	local function updateDisplay()
		if not timerLbl then createBB(); if not timerLbl then return end end
		if not stunActive then
			timerLbl.Text = "READY!!"
			timerLbl.TextColor3 = Color3.new(1,1,1)
			return
		end
		local rem = math.max(0, STUN_DURATION-(tick()-stunStartTime))
		if rem <= 0 then
			stunActive = false
			if stunConn then stunConn:Disconnect(); stunConn = nil end
			timerLbl.Text = "READY!!"
			timerLbl.TextColor3 = Color3.new(1,1,1)
			return
		end
		local sec = math.ceil(rem)
		if sec ~= lastSec then
			lastSec = sec
			timerLbl.Text = tostring(sec)
			if     sec == 3 then timerLbl.TextColor3 = C_RED
			elseif sec == 2 then timerLbl.TextColor3 = C_SILVER
			elseif sec == 1 then timerLbl.TextColor3 = C_MOON2
			end
		end
	end

	local function onStun()
		if stunActive then return end
		stunActive = true; stunStartTime = tick(); lastSec = nil
		createBB(); updateDisplay()
		if stunConn then stunConn:Disconnect() end
		stunConn = RunService.Heartbeat:Connect(updateDisplay)
	end

	local function setupDetection(char)
		if stateConn then stateConn:Disconnect() end
		local hum = char and char:FindFirstChildOfClass("Humanoid"); if not hum then return end
		stateConn = hum.StateChanged:Connect(function(_, ns)
			if ns==Enum.HumanoidStateType.Physics or ns==Enum.HumanoidStateType.Ragdoll
				or ns==Enum.HumanoidStateType.FallingDown or ns==Enum.HumanoidStateType.GettingUp then
				onStun()
			end
		end)
	end

	LP.CharacterAdded:Connect(function(char)
		if bbGui then pcall(function() bbGui:Destroy() end); bbGui=nil; timerLbl=nil; speedLbl=nil end
		task.wait(0.2); createBB(); setupDetection(char)
	end)
	if LP.Character then task.wait(0.1); createBB(); setupDetection(LP.Character) end

	-- Speed update — acemobile approach (AssemblyLinearVelocity fallback, smart rounding)
	RunService.RenderStepped:Connect(function()
		if not speedLbl or not speedLbl.Parent then return end
		local char = LP.Character; if not char then return end
		local hrp3 = char:FindFirstChild("HumanoidRootPart"); if not hrp3 then return end
		local v = hrp3.AssemblyLinearVelocity or hrp3.Velocity
		local speedMag = Vector3.new(v.X, 0, v.Z).Magnitude
		local rounded = math.floor(speedMag * 10 + 0.5) / 10
		if math.abs(rounded - math.floor(rounded)) < 0.05 then
			speedLbl.Text = string.format("Speed: %d", math.floor(rounded + 0.5))
		else
			speedLbl.Text = string.format("Speed: %.1f", rounded)
		end
	end)

	-- Other players' speed (billboard above their head)
	-- Other players' speed — a single global Heartbeat
	local _playerSpeedBBs = {}  -- plr → {bb, lbl, char}
	_GH.playerSpeedBBs = _playerSpeedBBs

	local function setupPlayerSpeedBB(plr)
		if plr == LP then return end
		local function attachBB(char)
			if _playerSpeedBBs[plr] then
				pcall(function() _playerSpeedBBs[plr].bb:Destroy() end)
			end
			local head = char:WaitForChild("Head", 5); if not head then return end
			local bb = Instance.new("BillboardGui", head)
			bb.Name = _NS .. "_v"; bb.Size = UDim2.new(0,110,0,22)
			bb.StudsOffset = Vector3.new(0,2.2,0); bb.AlwaysOnTop = true
			local lbl = Instance.new("TextLabel", bb)
			lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
			lbl.Text = "0"; lbl.TextColor3 = C_MOON2
			lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBlack
			lbl.TextStrokeTransparency = 0.35
			lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
			addLivingTextGradient(lbl)
			_playerSpeedBBs[plr] = {bb=bb, lbl=lbl, char=char}
		end
		if plr.Character then task.spawn(function() attachBB(plr.Character) end) end
		plr.CharacterAdded:Connect(function(char) task.spawn(function() attachBB(char) end) end)
	end

	-- A single Heartbeat for all players — delta position/time
	RunService.Heartbeat:Connect(function()
		local now = tick()
		for plr, data in pairs(_playerSpeedBBs) do
			if not data.lbl.Parent then
				_playerSpeedBBs[plr] = nil
			else
				local root = data.char:FindFirstChild("HumanoidRootPart")
				if root then
					local pos = Vector3.new(root.Position.X, 0, root.Position.Z)
					if data._lastPos then
						local dt = now - (data._lastT or now)
						if dt > 0 then
							local dist = (pos - data._lastPos).Magnitude
							local spd2 = dist / dt
							if spd2 < 800 then
								data.lbl.Text = string.format("%.1f", spd2)
							end
						end
					end
					data._lastPos, data._lastT = pos, now
				end
			end
		end
	end)

	for _, plr in ipairs(Players:GetPlayers()) do setupPlayerSpeedBB(plr) end
	Players.PlayerAdded:Connect(setupPlayerSpeedBB)
	Players.PlayerRemoving:Connect(function(plr)
		if _playerSpeedBBs[plr] then
			pcall(function() _playerSpeedBBs[plr].bb:Destroy() end)
			_playerSpeedBBs[plr] = nil
		end
	end)
end

-- ===================================================================
-- AUTO-SAVE SYSTEM (debounce + full states, raw__72_ style)
-- ===================================================================
local HS      = game:GetService("HttpService")
local MH_FILE = "rbxdata_mhv3x_" .. tostring(LP.UserId) .. ".json"
local _saveDebounce = false

local function ks(e)
	return {
		key = e and e.key and tostring(e.key):gsub("Enum.KeyCode.","") or nil,
		gp  = e and e.gp  and tostring(e.gp):gsub("Enum.KeyCode.","")  or nil,
	}
end

-- Deferred save (0.5s) to batch fast successive changes
-- Uses task.spawn + task.wait instead of task.delay (better executor compatibility)
local function MH_save()
	if _saveDebounce then return end
	_saveDebounce = true
	task.spawn(function()
		task.wait(0.5)
		local ok = pcall(function()
			local kb = _GH.MH_KB or {}
			local data = {
				normalSpeed      = State.normalSpeed,
				carrySpeed       = State.carrySpeed,
				laggerSpeed      = State.laggerSpeed,
				laggerCarrySpeed = State.laggerCarrySpeed,
				speedType        = State.speedType,
				laggerActive     = State.laggerActive,
				laggerCarryActive= State.laggerCarryActive,
				autoLeftEnabled  = State.autoLeftEnabled,
				autoRightEnabled = State.autoRightEnabled,
				antiRagdollEnabled  = State.antiRagdollEnabled,
				medusaCounterEnabled= State.medusaCounterEnabled,
				antiBatEnabled   = BC and BC.active or false,
				batCounterEnabled= BatCounter and BatCounter.active or false,
				aimbotEnabled    = AB and AB.active or false,
				aimbotV2Enabled  = ABP and ABP.active or false,
				aimSpeed         = AB and AB.SPEED or nil,
				infJumpEnabled   = IJ and IJ.active or false,
				infJumpMode      = IJ and IJ.mode or nil,
				autoGrabEnabled  = AutoSteal and AutoSteal.Enabled or false,
				grabRadius       = AutoSteal and AutoSteal.Radius or nil,
				floatSpawned = (function()
					local ids = {}
					for id in pairs(_floatBtns) do ids[#ids+1] = id end
					return ids
				end)(),
				floatPositions = _floatPositions,
				floatPosV = _FLOAT_POS_VERSION,
				uiLocked = _uiLocked,
				theme             = _currentTheme,
				autoPlayMode      = State.autoPlayMode,
				uiScaleVal        = _GH.getUIScale and _GH.getUIScale() or nil,
				positions = (function()
					local t = {}
					for id, frame in pairs(_GH.positions or {}) do
						if frame and frame.Parent then
							local p = frame.Position
							t[id] = {p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset}
						end
					end
					return t
				end)(),
				toggles = (function()
					local t = {}
					for key, entry in pairs(_GH.allToggles or {}) do
						t[key] = entry.get()
					end
					return t
				end)(),
				inputs = (function()
					local t = {}
					for key, entry in pairs(_GH.allInputs or {}) do
						local n = tonumber(entry.box.Text)
						if n then t[key] = n end
					end
					return t
				end)(),
				kb = {
					AntiBatAimbot = ks(kb.AntiBatAimbot),
					DropBR        = ks(kb.DropBR),
					AutoLeft      = ks(kb.AutoLeft),
					AimBot        = ks(kb.AimBot),
					AutoRight     = ks(kb.AutoRight),
					TPDown        = ks(kb.TPDown),
					LagNorm       = ks(kb.LagNorm),
					BatTP         = ks(kb.BatTP),
					AimV2         = ks(kb.AimV2),
					AimV3Kb       = ks(kb.AimV3Kb),
					InstantReset  = ks(kb.InstantReset),
					HideUI        = ks(kb.HideUI),
				},
			}
			if writefile then
				writefile(MH_FILE, HS:JSONEncode(data))
			else
				warn("[H] writefile unavailable — executor does not support saving")
			end
		end)
		if not ok then warn("[H] MH_save error — missing modules?") end
		_saveDebounce = false
	end)
end
_GH.autoSave = MH_save

-- Loading: pushes values straight into State, the widgets, AND restarts active modules
local function MH_load()
	local ok, data = pcall(function()
		if type(readfile) ~= "function" then warn("[H] readfile missing on this executor"); return nil end
		if type(isfile) ~= "function" then warn("[H] isfile missing on this executor"); return nil end
		local fileExists = false
		local fOk, fErr = pcall(function() fileExists = isfile(MH_FILE) end)
		if not fOk then warn("[H] isfile raised an error: "..tostring(fErr)); return nil end
		if not fileExists then return nil end
		local rOk, rContent = pcall(function() return readfile(MH_FILE) end)
		if not rOk then warn("[H] readfile raised an error: "..tostring(rContent)); return nil end
		local dOk, decoded = pcall(function() return HS:JSONDecode(rContent) end)
		if not dOk then warn("[H] JSONDecode failed: "..tostring(decoded)); return nil end
		return decoded
	end)
	if not ok or not data then
		return false
	end

	local loadOk = pcall(function()
		if data.normalSpeed then State.normalSpeed=data.normalSpeed
			if _G._mhInputBoxesRef.normalSpeed then _G._mhInputBoxesRef.normalSpeed.Text=tostring(data.normalSpeed) end end
		if data.carrySpeed then State.carrySpeed=data.carrySpeed
			if _G._mhInputBoxesRef.carrySpeed then _G._mhInputBoxesRef.carrySpeed.Text=tostring(data.carrySpeed) end end
		if data.laggerSpeed then State.laggerSpeed=data.laggerSpeed
			if _G._mhInputBoxesRef.laggerSpeed then _G._mhInputBoxesRef.laggerSpeed.Text=tostring(data.laggerSpeed) end end
		if data.laggerCarrySpeed then State.laggerCarrySpeed=data.laggerCarrySpeed
			if _G._mhInputBoxesRef.laggerCarrySpeed then _G._mhInputBoxesRef.laggerCarrySpeed.Text=tostring(data.laggerCarrySpeed) end end
		if data.speedType=="normal" or data.speedType=="carry" then State.speedType=data.speedType end

		if data.aimSpeed then AB.SPEED=data.aimSpeed end
		if data.infJumpMode=="manual" or data.infJumpMode=="hold" then
				IJ.mode=data.infJumpMode
				if setJumpModeUI then setJumpModeUI() end
			end
		if data.grabRadius then AutoSteal.Radius=data.grabRadius end
		if data.autoPlayMode then
			if setAutoPlayModeUI then setAutoPlayModeUI(data.autoPlayMode)
			else State.autoPlayMode = data.autoPlayMode end
		end
		if data.uiScaleVal and _GH.applyUIScale then _GH.applyUIScale(data.uiScaleVal) end

		-- Window/widget positions: restored before anything else so frames
		-- never flash at their default position on load.
		if type(data.positions) == "table" then
			for id, pos in pairs(data.positions) do
				local frame = _GH.positions and _GH.positions[id]
				if frame and type(pos) == "table" and pos[1] then
					frame.Position = UDim2.new(pos[1], pos[2], pos[3], pos[4])
				end
			end
		end

		-- Numeric input rows: restore value + re-apply effect (FOV, radius…)
		if type(data.inputs) == "table" then
			for key, value in pairs(data.inputs) do
				local entry = _GH.allInputs and _GH.allInputs[key]
				if entry and type(value) == "number" then
					entry.box.Text = tostring(value)
					pcall(entry.onChange, value)
				end
			end
		end

		-- Float button positions must be loaded BEFORE toggle restore so that
		-- when a toggle re-spawns a floating button it reads the saved position
		-- at creation time instead of landing at the default grid slot.
		-- Positions from an older layout version are discarded.
		if type(data.floatPositions) == "table" and data.floatPosV == _FLOAT_POS_VERSION then
			for id, pos in pairs(data.floatPositions) do
				_floatPositions[id] = pos
			end
		end

		-- Theme must be applied BEFORE toggle restore: TweenService captures C_ON_BG
		-- by value at Create() time, so restoring toggles before applyTheme would
		-- bake the default-blue into all pill tweens even in noir mode.
		if data.theme == "default" or data.theme == "noir" then
			applyTheme(data.theme)
		end

		-- Toggle rows: restore saved state (ON and OFF) including defaults-ON features.
		if type(data.toggles) == "table" then
			for key, on in pairs(data.toggles) do
				local entry = _GH.allToggles and _GH.allToggles[key]
				if entry then
					if on then
						if entry.onToggle then pcall(entry.onToggle, true) end
						entry.set(true)
					else
						if entry.onToggle then pcall(entry.onToggle, false) end
						entry.set(false)
					end
				end
			end
		end

		if data.kb then
			local kb = _GH.MH_KB
			if kb then
				for name, entry in pairs(data.kb) do
					if kb[name] then
						if entry.key and Enum.KeyCode[entry.key] then kb[name].key = Enum.KeyCode[entry.key] end
						if entry.gp  and Enum.KeyCode[entry.gp]  then kb[name].gp  = Enum.KeyCode[entry.gp]  end
					end
				end
			end
		end

		if type(data.uiLocked) == "boolean" and data.uiLocked then
			setDragLock(true)
			lockTitleBtn.Text = "🔒"; lockTitleBtn.TextColor3 = C_RED
		end
	end)
	if not loadOk then warn("[H] MH_load failed partway through — check referenced modules") end

	-- Defer one frame so any float buttons spawned by toggle restore are fully
	-- registered before we re-apply their active color against the loaded theme.
	task.defer(function()
		if _GH.refreshFloatActiveColors then _GH.refreshFloatActiveColors() end
	end)

	return true
end

local _floatRowSetters = {}
buildPage("Buttons", function()
	local FLOAT_LABELS = {
		{id="antibat",     name="Anti Bat Aimbot"},
		{id="aimbot",      name="Aim Bot"},
		{id="aimv2",       name="Aim V2"},

		{id="dropbr",      name="Drop Brainrot"},
		{id="autoleft",    name="Auto Left"},
		{id="autoright",   name="Auto Right"},
		{id="tpdown",      name="TP Down"},
		{id="battp",       name="Bat TP"},
		{id="instareset",  name="Instant Reset"},
	}

	-- Select All / Unselect All — tout en haut
	do
		local saRow = Instance.new("Frame", currentPage)
		saRow.Size = UDim2.new(1,0,0,34); saRow.BackgroundTransparency = 1
		saRow.BorderSizePixel = 0; saRow.LayoutOrder = LO()
		local bW = 128; local gap = 8
		local startX = (276 - (bW*2+gap)) / 2
		local function makeSelBtn(label, xOff, col)
			local b = Instance.new("TextButton", saRow)
			b.Size = UDim2.new(0,bW,1,0); b.Position = UDim2.new(0,xOff,0,0)
			b.BackgroundColor3 = col; b.BackgroundTransparency = 0.15
			b.BorderSizePixel = 0; b.Text = label
			b.TextColor3 = C_WHITE; b.Font = Enum.Font.GothamBold; b.TextSize = 11
			b.AutoButtonColor = false; addCorner(b,10); addLivingStroke(b,1)
			addLivingTextGradient(b)
			b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundTransparency=0}):Play() end)
			b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundTransparency=0.15}):Play() end)
			return b
		end
		local selBtn = makeSelBtn("✦ Select All",   startX,        Color3.fromRGB(30,60,30))
		local uslBtn = makeSelBtn("✦ Unselect All", startX+bW+gap, Color3.fromRGB(60,20,20))
		selBtn.MouseButton1Click:Connect(function()
			for _, entry in ipairs(FLOAT_LABELS) do
				if _floatRowSetters[entry.id] then _floatRowSetters[entry.id](true) end
				makeFloatButton(entry.id)
			end
			if _GH.autoSave then _GH.autoSave() end
		end)
		uslBtn.MouseButton1Click:Connect(function()
			for _, entry in ipairs(FLOAT_LABELS) do
				if _floatRowSetters[entry.id] then _floatRowSetters[entry.id](false) end
				removeFloatButton(entry.id)
			end
			if _GH.autoSave then _GH.autoSave() end
		end)
	end

	UIB.makeGap(4)
	-- Right at the top: direct toggle that spawns the Speed Booster widget
	UIB.makeSectionLabel("Speed Booster")
	UIB.makeToggleRow("Speed Booster", false, function(on)
		if _GH.spW then
			_GH.spW.Visible = on
			if on then _GH.spW.ZIndex = 1000 end
		end
	end)
	UIB.makeGap(4)

	UIB.makeSectionLabel("Floating Buttons")
	UIB.makeGap(2)

	for _, entry in ipairs(FLOAT_LABELS) do
		_floatRowSetters[entry.id] = UIB.makeToggleRow(entry.name, false, function(on)
			if on then makeFloatButton(entry.id) else removeFloatButton(entry.id) end
			if _GH.autoSave then _GH.autoSave() end
		end)
	end
end)

buildPage("Settings", function()
	UIB.makeSectionLabel("Auto Play")
	do
		local apModes={"Full","Half"}
		local function getIdx()
			for i,m in ipairs(apModes) do if m==State.autoPlayMode then return i end end; return 1
		end
		local apRow=Instance.new("Frame",currentPage)
		apRow.Size=UDim2.new(1,0,0,32);apRow.BackgroundColor3=C_ROW;apRow.BackgroundTransparency=0.35
		apRow.BorderSizePixel=0;apRow.LayoutOrder=LO();addCorner(apRow,12);addLivingStroke(apRow,1)
		local apl=Instance.new("TextLabel",apRow)
		apl.Size=UDim2.new(0,110,1,0);apl.Position=UDim2.new(0,14,0,0)
		apl.BackgroundTransparency=1;apl.Text="Auto Play Mode";apl.TextColor3=C_WHITE
		apl.Font=Enum.Font.GothamBold;apl.TextSize=10;apl.TextXAlignment=Enum.TextXAlignment.Left
		addLivingTextGradient(apl)
		local apBtn=Instance.new("TextButton",apRow)
		apBtn.Size=UDim2.new(0,70,0,22);apBtn.Position=UDim2.new(1,-80,0.5,-11)
		apBtn.BackgroundColor3=C_ON_BG;apBtn.BackgroundTransparency=0.1;apBtn.BorderSizePixel=0
		apBtn.Text=State.autoPlayMode;apBtn.TextColor3=C_MOON
		apBtn.Font=Enum.Font.GothamBold;apBtn.TextSize=10;apBtn.AutoButtonColor=false
		addCorner(apBtn,6);addLivingStroke(apBtn,1)
		apBtn.MouseButton1Click:Connect(function()
			local idx=(getIdx()%#apModes)+1
			State.autoPlayMode=apModes[idx];apBtn.Text=apModes[idx]
		end)
	end
	UIB.makeGap(4)
	UIB.makeSectionLabel("UI Scale")
	UIB.makeGap(2)
	do
		-- S=1, M=4, L=7, XL=10 (on applyUIScale's 1-10 scale)
		local presets = {{"S",1},{"M",4},{"L",7},{"XL",10}}
		local scRow = Instance.new("Frame", currentPage)
		scRow.Size = UDim2.new(1,0,0,34); scRow.BackgroundColor3 = C_ROW
		scRow.BackgroundTransparency = 0.35; scRow.BorderSizePixel = 0
		scRow.LayoutOrder = LO(); addCorner(scRow,12); addLivingStroke(scRow,1)
		local ll2 = Instance.new("UIListLayout", scRow)
		ll2.FillDirection = Enum.FillDirection.Horizontal
		ll2.VerticalAlignment = Enum.VerticalAlignment.Center
		ll2.HorizontalAlignment = Enum.HorizontalAlignment.Center
		ll2.Padding = UDim.new(0,8)
		for _, preset in ipairs(presets) do
			local lbl2, val = preset[1], preset[2]
			local btn2 = Instance.new("TextButton", scRow)
			btn2.Size = UDim2.new(0,48,0,24); btn2.BackgroundColor3 = C_ON_BG
			btn2.BackgroundTransparency = 0.3; btn2.BorderSizePixel = 0
			btn2.Text = lbl2; btn2.TextColor3 = C_MOON
			btn2.Font = Enum.Font.GothamBold; btn2.TextSize = 11
			btn2.AutoButtonColor = false
			addCorner(btn2,8); addLivingStroke(btn2,1)
			btn2.MouseButton1Click:Connect(function()
				if _GH.applyUIScale then _GH.applyUIScale(val) end
				for _, b2 in ipairs(scRow:GetChildren()) do
					if b2:IsA("TextButton") then
						b2.BackgroundTransparency = 0.3; b2.TextColor3 = C_MOON
					end
				end
				btn2.BackgroundTransparency = 0.05; btn2.TextColor3 = C_WHITE
			end)
		end
	end

	UIB.makeGap(4)
	UIB.makeSectionLabel("Bypass")
	UIB.makeToggleRow("Speed Bypass", false, function(on)
		if _sbBypassWidget then _sbBypassWidget.Visible = on end
		-- Actually triggers the bypass (not just showing the panel)
		if _GH.speedBypassToggle then
			local isActive = _GH.speedBypassIsActive and _GH.speedBypassIsActive() or false
			if isActive ~= on then _GH.speedBypassToggle() end
		end
	end)
	UIB.makeToggleRow("Lagger", false, function(on)
		if _lgrBypassWidget then _lgrBypassWidget.Visible = on end
	end)

	-- ── ANIMATION CHANGER (25 packs, ◀ ▶ navigation) ──────────────
	UIB.makeGap(4)
	UIB.makeSectionLabel("Animation Changer")
	do
		local ANIM_PACKS = {
			["Robot"]       = {WalkAnim=616013216,RunAnim=616010382,JumpAnim=616008936,FallAnim=616005863,SwimIdle=616012453,Swim=616011509,Animation1=616006778,Animation2=616008087,ClimbAnim=616003713},
			["Vampire"]     = {WalkAnim=1083178339,RunAnim=1083216690,JumpAnim=1083218792,FallAnim=1083189019,SwimIdle=1083222527,Swim=1083225406,Animation1=1083445855,Animation2=1083450167,ClimbAnim=1083182000},
			["Superhero"]   = {WalkAnim=616013216,RunAnim=616111765,JumpAnim=616111876,FallAnim=616108001,SwimIdle=616112625,Swim=616112437,Animation1=616111295,Animation2=616111295,ClimbAnim=616110833},
			["Cartoony"]    = {WalkAnim=742640026,RunAnim=742638842,JumpAnim=742637942,FallAnim=742637151,SwimIdle=742639220,Swim=742639812,Animation1=742635424,Animation2=742636889,ClimbAnim=742636889},
			["Ninja"]       = {WalkAnim=656118852,RunAnim=656118852,JumpAnim=656117878,FallAnim=656115606,SwimIdle=656119721,Swim=656119721,Animation1=656117878,Animation2=656118341,ClimbAnim=656114359},
			["Adidas Sports"]    ={WalkAnim=18537392113,RunAnim=18537384940,JumpAnim=18537380791,FallAnim=18537367238,SwimIdle=18537387180,Swim=18537389531,Animation1=18537376492,Animation2=18537371272,ClimbAnim=18537363391},
			["Adidas Community"] ={WalkAnim=122150855457006,RunAnim=82598234841035,JumpAnim=75290611992385,FallAnim=98600215928904,SwimIdle=109346520324160,Swim=133308483266208,Animation1=122257458498464,Animation2=102357151005774,ClimbAnim=88763136693023},
			["Adidas Aura"]      ={WalkAnim=83842218823011,RunAnim=118320322718866,JumpAnim=109996626521204,FallAnim=95603166884636,SwimIdle=94922130551805,Swim=134530128383903,Animation1=110211186840347,Animation2=114191137265065,ClimbAnim=97824616490448},
			["Stylish"]     = {WalkAnim=616122287,RunAnim=616117076,JumpAnim=616119360,FallAnim=616115533,SwimIdle=616120448,Swim=616121235,Animation1=616117076,Animation2=616120861,ClimbAnim=616115533},
			["Levitation"]  = {WalkAnim=616013216,RunAnim=616006778,JumpAnim=616008936,FallAnim=616005863,SwimIdle=616011509,Swim=616012453,Animation1=616006778,Animation2=616008087,ClimbAnim=616003713},
			["Astronaut"]   = {WalkAnim=891667138,RunAnim=891636393,JumpAnim=891627522,FallAnim=891617961,SwimIdle=891639666,Swim=891663592,Animation1=891621366,Animation2=891633237,ClimbAnim=891609353},
			["Werewolf"]    = {WalkAnim=1083195517,RunAnim=1083194401,JumpAnim=1083218792,FallAnim=1083189019,SwimIdle=1083222527,Swim=1083225406,Animation1=1083462077,Animation2=1083450167,ClimbAnim=1083182000},
			["Knight"]      = {WalkAnim=658831042,RunAnim=658831794,JumpAnim=658832070,FallAnim=658831500,SwimIdle=658832437,Swim=658832807,Animation1=657595757,Animation2=657600338,ClimbAnim=658830056},
			["Pirate"]      = {WalkAnim=750785693,RunAnim=750783738,JumpAnim=750782230,FallAnim=750781874,SwimIdle=750785579,Swim=750784579,Animation1=750781874,Animation2=750782770,ClimbAnim=750779899},
			["Toy"]         = {WalkAnim=782841498,RunAnim=782843345,JumpAnim=782847020,FallAnim=782846423,SwimIdle=782844582,Swim=782844235,Animation1=782842708,Animation2=782845736,ClimbAnim=782843869},
			["Elder"]       = {WalkAnim=1092112116,RunAnim=1092114823,JumpAnim=1092114571,FallAnim=1092114319,SwimIdle=1092113582,Swim=1092113478,Animation1=1092110164,Animation2=1092110049,ClimbAnim=1092113209},
			["Bubbly"]      = {WalkAnim=910034870,RunAnim=910025107,JumpAnim=910016857,FallAnim=910001910,SwimIdle=910030921,Swim=910028158,Animation1=910004836,Animation2=910009958,ClimbAnim=910019264},
			["Zombie"]      = {WalkAnim=616163682,RunAnim=616163682,JumpAnim=616161682,FallAnim=616157476,SwimIdle=616165109,Swim=616164682,Animation1=616158929,Animation2=616160636,ClimbAnim=616156119},
			["Sneaky"]      = {WalkAnim=1132510133,RunAnim=1132494274,JumpAnim=1132489853,FallAnim=1132469004,SwimIdle=1132506407,Swim=1132500520,Animation1=1132473842,Animation2=1132477671,ClimbAnim=1132461372},
			["Patrol"]      = {WalkAnim=1151231493,RunAnim=1150967949,JumpAnim=1150944216,FallAnim=1148863382,SwimIdle=1151221899,Swim=1151204998,Animation1=1149612882,Animation2=1150842221,ClimbAnim=1148811837},
			["Popstar"]     = {WalkAnim=1212980338,RunAnim=1212980348,JumpAnim=1212954642,FallAnim=1212900995,SwimIdle=1212998578,Swim=1212852603,Animation1=1212900985,Animation2=1212954651,ClimbAnim=1213044953},
			["Confident"]   = {WalkAnim=1070017263,RunAnim=1070001516,JumpAnim=1069984524,FallAnim=1069973677,SwimIdle=1070012133,Swim=1070009914,Animation1=1069977950,Animation2=1069987858,ClimbAnim=1069946257},
			["Princess"]    = {WalkAnim=941028902,RunAnim=941015281,JumpAnim=941008832,FallAnim=941000007,SwimIdle=941025398,Swim=941018893,Animation1=941003647,Animation2=941013098,ClimbAnim=940996062},
			["Cowboy"]      = {WalkAnim=1014421541,RunAnim=1014401683,JumpAnim=1014394726,FallAnim=1014384571,SwimIdle=1014411816,Swim=1014406523,Animation1=1014390418,Animation2=1014398616,ClimbAnim=1014380606},
		}
		local ANIM_ORDER = {"Default","Robot","Vampire","Superhero","Cartoony","Ninja","Adidas Sports","Adidas Community","Adidas Aura","Stylish","Levitation","Astronaut","Werewolf","Knight","Pirate","Toy","Elder","Bubbly","Zombie","Sneaky","Patrol","Popstar","Confident","Princess","Cowboy"}
		local _animEnabled = false
		local _animIndex = 1

		-- Robust method: direct Animator:LoadAnimation + Heartbeat loop that
		-- keeps reapplying (handles cases where the game regenerates Animate)
		local _animTracks = {}
		local function stopAllTracks()
			for _, tr in ipairs(_animTracks) do pcall(function() tr:Stop(0) end) end
			_animTracks = {}
		end

		local function applyAnimPack(packName)
			stopAllTracks()
			local c = LP.Character; if not c then return end
			local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
			local animator = hum:FindFirstChildOfClass("Animator")
			if not animator then animator = Instance.new("Animator", hum) end
			local pack = ANIM_PACKS[packName]; if not pack then return end

			-- 1. Update Animate script IDs first (walk/run/jump/fall/climb/swim)
			local animate = c:FindFirstChild("Animate")
			if animate then
				local function setAnim(folder,slot,id)
					if not id then return end
					local f=animate:FindFirstChild(folder); if not f then return end
					local a=f:FindFirstChild(slot)
					if a and a:IsA("Animation") then a.AnimationId="rbxassetid://"..tostring(id) end
				end
				setAnim("walk","WalkAnim",pack.WalkAnim)
				setAnim("run","RunAnim",pack.RunAnim)
				setAnim("jump","JumpAnim",pack.JumpAnim)
				setAnim("fall","FallAnim",pack.FallAnim)
				setAnim("idle","Animation1",pack.Animation1)
				setAnim("idle","Animation2",pack.Animation2)
				setAnim("climb","ClimbAnim",pack.ClimbAnim)
				setAnim("swimidle","SwimIdle",pack.SwimIdle)
				setAnim("swim","Swim",pack.Swim)
			end

			-- 2. Stop all currently playing tracks so Animate restarts with new IDs
			for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do pcall(function() tr:Stop(0) end) end

			-- 3. Force-play idle immediately for visual feedback (Animate handles rest)
			local slots = {
				{id=pack.Animation1, prio=Enum.AnimationPriority.Idle,     loop=true},
				{id=pack.WalkAnim,   prio=Enum.AnimationPriority.Movement, loop=true},
			}
			for _, s in ipairs(slots) do
				if s.id then
					local anim = Instance.new("Animation")
					anim.AnimationId = "rbxassetid://"..tostring(s.id)
					local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
					if ok and track then
						track.Priority = s.prio
						track.Looped = s.loop
						track:Play(0)
						table.insert(_animTracks, track)
					end
				end
			end
		end

		local function clearAnimPack()
			stopAllTracks()
		end

		-- Navigation row: ◀  [Name]  ▶
		local animRow = Instance.new("Frame", currentPage)
		animRow.Size=UDim2.new(1,0,0,36); animRow.BackgroundColor3=C_ROW
		animRow.BackgroundTransparency=0.35; animRow.BorderSizePixel=0; animRow.LayoutOrder=LO()
		addCorner(animRow,10); addLivingStroke(animRow,1)

		local animPrevBtn = Instance.new("TextButton", animRow)
		animPrevBtn.Size=UDim2.new(0,36,1,0); animPrevBtn.Position=UDim2.new(0,0,0,0)
		animPrevBtn.BackgroundTransparency=1; animPrevBtn.Text="◀"
		animPrevBtn.TextColor3=C_MOON2; animPrevBtn.Font=Enum.Font.GothamBlack; animPrevBtn.TextSize=16
		animPrevBtn.AutoButtonColor=false

		local animNameLbl = Instance.new("TextLabel", animRow)
		animNameLbl.Size=UDim2.new(1,-72,1,0); animNameLbl.Position=UDim2.new(0,36,0,0)
		animNameLbl.BackgroundTransparency=1; animNameLbl.Text="Default"
		animNameLbl.TextColor3=C_WHITE; animNameLbl.Font=Enum.Font.GothamBlack; animNameLbl.TextSize=12
		animNameLbl.TextXAlignment=Enum.TextXAlignment.Center
		addLivingTextGradient(animNameLbl)

		local animNextBtn = Instance.new("TextButton", animRow)
		animNextBtn.Size=UDim2.new(0,36,1,0); animNextBtn.Position=UDim2.new(1,-36,0,0)
		animNextBtn.BackgroundTransparency=1; animNextBtn.Text="▶"
		animNextBtn.TextColor3=C_MOON2; animNextBtn.Font=Enum.Font.GothamBlack; animNextBtn.TextSize=16
		animNextBtn.AutoButtonColor=false

		local function selectAnim(idx)
			_animIndex = ((idx - 1) % #ANIM_ORDER) + 1
			local name = ANIM_ORDER[_animIndex]
			animNameLbl.Text = name
			if _animEnabled then
				if name == "Default" then clearAnimPack() else applyAnimPack(name) end
			end
		end

		animPrevBtn.MouseButton1Click:Connect(function() selectAnim(_animIndex - 1) end)
		animNextBtn.MouseButton1Click:Connect(function() selectAnim(_animIndex + 1) end)

		UIB.makeToggleRow("Animation Changer", false, function(on)
			_animEnabled = on
			local name = ANIM_ORDER[_animIndex]
			if on then
				if name == "Default" then clearAnimPack() else applyAnimPack(name) end
			else
				clearAnimPack()
			end
		end)

		LP.CharacterAdded:Connect(function()
			task.wait(1)
			_animTracks = {}
			if _animEnabled then
				local name = ANIM_ORDER[_animIndex]
				if name ~= "Default" then applyAnimPack(name) end
			end
		end)
	end

	UIB.makeGap(4)
	UIB.makeSectionLabel("Theme")
	UIB.makeGap(2)
	do
		local thRow = Instance.new("Frame", currentPage)
		thRow.Size = UDim2.new(1,0,0,32); thRow.BackgroundColor3 = C_ROW
		thRow.BackgroundTransparency = 0.35; thRow.BorderSizePixel = 0
		thRow.LayoutOrder = LO(); addCorner(thRow,12); addLivingStroke(thRow,1)
		local thLbl = Instance.new("TextLabel", thRow)
		thLbl.Size = UDim2.new(0,80,1,0); thLbl.Position = UDim2.new(0,14,0,0)
		thLbl.BackgroundTransparency = 1; thLbl.Text = "Colors"
		thLbl.TextColor3 = C_WHITE; thLbl.Font = Enum.Font.GothamBold
		thLbl.TextSize = 10; thLbl.TextXAlignment = Enum.TextXAlignment.Left
		addLivingTextGradient(thLbl)
		local BW,BH = 55,22
		local defBtn = Instance.new("TextButton", thRow)
		defBtn.Size = UDim2.new(0,BW,0,BH); defBtn.Position = UDim2.new(1,-(BW*2+14),0.5,-BH/2)
		defBtn.BackgroundColor3 = C_MOON; defBtn.BackgroundTransparency = 0.1
		defBtn.BorderSizePixel = 0; defBtn.Text = "Default"
		defBtn.TextColor3 = Color3.fromRGB(0,10,20)
		defBtn.Font = Enum.Font.GothamBold; defBtn.TextSize = 9
		defBtn.AutoButtonColor = false; addCorner(defBtn,6); addLivingStroke(defBtn,1)
		local noirBtn = Instance.new("TextButton", thRow)
		noirBtn.Size = UDim2.new(0,BW,0,BH); noirBtn.Position = UDim2.new(1,-(BW+6),0.5,-BH/2)
		noirBtn.BackgroundColor3 = C_OFF_BG; noirBtn.BackgroundTransparency = 0.3
		noirBtn.BorderSizePixel = 0; noirBtn.Text = "Dark"
		noirBtn.TextColor3 = C_DIM
		noirBtn.Font = Enum.Font.GothamBold; noirBtn.TextSize = 9
		noirBtn.AutoButtonColor = false; addCorner(noirBtn,6)
		_G_updateThemeUI = function(name)
			defBtn.BackgroundColor3  = name=="default" and C_MOON or C_OFF_BG
			defBtn.BackgroundTransparency  = name=="default" and 0.1 or 0.3
			defBtn.TextColor3  = name=="default" and Color3.fromRGB(0,10,20) or C_DIM
			noirBtn.BackgroundColor3 = name=="noir" and Color3.fromRGB(200,200,200) or C_OFF_BG
			noirBtn.BackgroundTransparency = name=="noir" and 0.15 or 0.3
			noirBtn.TextColor3 = name=="noir" and Color3.fromRGB(10,10,10) or C_DIM
		end
		defBtn.MouseButton1Click:Connect(function()
			applyTheme("default"); if _GH.autoSave then _GH.autoSave() end
		end)
		noirBtn.MouseButton1Click:Connect(function()
			applyTheme("noir"); if _GH.autoSave then _GH.autoSave() end
		end)
	end
	UIB.makeGap(6)
	UIB.makeSectionLabel("Credits")
	local creditRow = Instance.new("Frame", currentPage)
	creditRow.Size = UDim2.new(1,0,0,30); creditRow.BackgroundTransparency = 1; creditRow.LayoutOrder = LO()
	local creditFooter = Instance.new("TextLabel", creditRow)
	creditFooter.Size = UDim2.new(1,0,1,0); creditFooter.BackgroundTransparency = 1
	creditFooter.Text = "ALN x YSLEM"
	creditFooter.TextColor3 = C_SILVER2; creditFooter.Font = Enum.Font.Gotham; creditFooter.TextSize = 10
	addLivingTextGradient(creditFooter)
end);  -- required semicolon (otherwise ambiguous merge with the (function() below)

-- ===================================================================
-- SPEED BYPASS (Moon Hub style — blue, +/- power, exact Cz lag logic)
-- ===================================================================
(function()
local activated = false
local keybind = Enum.KeyCode.E
local waitingForKey = false
local power = 79000
local lagAmount = 0.15
local lagConn = nil
local minimized = false

local function applyPower(val)
	power = math.clamp(val, 10000, 500000)
	local t = (power - 10000) / 490000
	lagAmount = t * 0.2
end
applyPower(power)

local function startLag()
	if lagConn then lagConn:Disconnect() end
	lagConn = RunService.RenderStepped:Connect(function()
		if not activated then return end
		if lagAmount > 0 then
			local t = tick()
			while tick() - t < lagAmount do end
		end
	end)
end

local function stopLag()
	activated = false
	if lagConn then lagConn:Disconnect(); lagConn = nil end
end

local sbW = Instance.new("Frame", gui)
sbW.Name = _NS.."c"
sbW.Size = UDim2.new(0, 150, 0, 165)
sbW.Position = UDim2.new(1, -256, 0, 210)
sbW.BackgroundColor3 = C_BG
sbW.BorderSizePixel = 0
sbW.ClipsDescendants = true
sbW.Active = true
sbW.Visible = false
addCorner(sbW, 12); addLivingStroke(sbW, 1.5)
_sbBypassWidget = sbW

local sbHeader = Instance.new("Frame", sbW)
sbHeader.Size = UDim2.new(1, 0, 0, 28); sbHeader.BackgroundColor3 = C_HEADER; sbHeader.BorderSizePixel = 0
addCorner(sbHeader, 12); makeDraggable(sbW, sbHeader, "speedbypass")
local sbPatch = Instance.new("Frame", sbHeader)
sbPatch.Size = UDim2.new(1,0,0,12); sbPatch.Position = UDim2.new(0,0,1,-12)
sbPatch.BackgroundColor3 = C_HEADER; sbPatch.BorderSizePixel = 0
local sbDot = Instance.new("Frame", sbHeader)
sbDot.Size = UDim2.new(0,5,0,5); sbDot.Position = UDim2.new(0,10,0,11)
sbDot.BackgroundColor3 = C_MOON; sbDot.BorderSizePixel = 0; addCorner(sbDot, 3)
local sbTitle = Instance.new("TextLabel", sbHeader)
sbTitle.Size = UDim2.new(1,-52,1,0); sbTitle.Position = UDim2.new(0,20,0,0)
sbTitle.BackgroundTransparency = 1; sbTitle.Text = "SPEED BYPASS"
sbTitle.TextColor3 = C_WHITE; sbTitle.Font = Enum.Font.GothamBlack; sbTitle.TextSize = 10
sbTitle.TextXAlignment = Enum.TextXAlignment.Left; addLivingTextGradient(sbTitle)

local sbFullH = 165
local sbMinBtn = Instance.new("TextButton", sbHeader)
sbMinBtn.Size = UDim2.new(0,20,0,20); sbMinBtn.Position = UDim2.new(1,-26,0.5,-10)
sbMinBtn.BackgroundColor3 = Color3.fromRGB(30,30,34); sbMinBtn.BorderSizePixel = 0
sbMinBtn.Text = "-"; sbMinBtn.TextColor3 = C_WHITE; sbMinBtn.Font = Enum.Font.GothamBlack; sbMinBtn.TextSize = 13
sbMinBtn.AutoButtonColor = false; addCorner(sbMinBtn, 6); addLivingStroke(sbMinBtn, 1)

local toggleBtn = Instance.new("TextButton", sbW)
toggleBtn.Size = UDim2.new(1,-16,0,26); toggleBtn.Position = UDim2.new(0,8,0,34)
toggleBtn.BackgroundColor3 = C_OFF_BG; toggleBtn.BackgroundTransparency = 0.2
toggleBtn.Text = "DISABLED"; toggleBtn.TextColor3 = C_DIM
toggleBtn.Font = Enum.Font.GothamBlack; toggleBtn.TextSize = 11
toggleBtn.BorderSizePixel = 0; toggleBtn.AutoButtonColor = false
addCorner(toggleBtn, 8); addLivingStroke(toggleBtn, 1)

local function toggle()
	if not activated then
		activated = true
		toggleBtn.Text = "ENABLED"
		toggleBtn.BackgroundColor3 = C_ON_BG; toggleBtn.BackgroundTransparency = 0.1
		toggleBtn.TextColor3 = C_MOON
		startLag()
	else
		stopLag()
		toggleBtn.Text = "DISABLED"
		toggleBtn.BackgroundColor3 = C_OFF_BG; toggleBtn.BackgroundTransparency = 0.2
		toggleBtn.TextColor3 = C_DIM
	end
end
toggleBtn.MouseButton1Click:Connect(toggle)
_GH.speedBypassToggle = toggle
_GH.speedBypassIsActive = function() return activated end

local bindRow = Instance.new("Frame", sbW)
bindRow.Size = UDim2.new(1,-16,0,26); bindRow.Position = UDim2.new(0,8,0,64)
bindRow.BackgroundColor3 = C_ROW; bindRow.BackgroundTransparency = 0.35
bindRow.BorderSizePixel = 0; addCorner(bindRow, 8); addLivingStroke(bindRow, 1)
local bindLabel = Instance.new("TextLabel", bindRow)
bindLabel.Size = UDim2.new(0.5,0,1,0); bindLabel.Position = UDim2.new(0,10,0,0)
bindLabel.BackgroundTransparency = 1; bindLabel.Text = "Bind"
bindLabel.TextColor3 = C_WHITE; bindLabel.Font = Enum.Font.GothamBold; bindLabel.TextSize = 10
bindLabel.TextXAlignment = Enum.TextXAlignment.Left; addLivingTextGradient(bindLabel)
local bindBtn = Instance.new("TextButton", bindRow)
bindBtn.Size = UDim2.new(0,42,0,20); bindBtn.Position = UDim2.new(1,-48,0.5,-10)
bindBtn.BackgroundColor3 = C_OFF_BG; bindBtn.BackgroundTransparency = 0.1
bindBtn.Text = "E"; bindBtn.TextColor3 = C_MOON2; bindBtn.Font = Enum.Font.GothamBold; bindBtn.TextSize = 10
bindBtn.BorderSizePixel = 0; bindBtn.AutoButtonColor = false
addCorner(bindBtn, 5); addLivingTextGradient(bindBtn)
bindBtn.MouseButton1Click:Connect(function()
	waitingForKey = true; bindBtn.Text = "..."
end)

local powerLbl = Instance.new("TextLabel", sbW)
powerLbl.Size = UDim2.new(1,-16,0,14); powerLbl.Position = UDim2.new(0,8,0,94)
powerLbl.BackgroundTransparency = 1; powerLbl.Text = "Power"
powerLbl.TextColor3 = C_WHITE; powerLbl.Font = Enum.Font.GothamBold; powerLbl.TextSize = 9
powerLbl.TextXAlignment = Enum.TextXAlignment.Left; addLivingTextGradient(powerLbl)

local minusBtn = Instance.new("TextButton", sbW)
minusBtn.Size = UDim2.new(0,22,0,22); minusBtn.Position = UDim2.new(0,8,0,110)
minusBtn.BackgroundColor3 = C_OFF_BG; minusBtn.BackgroundTransparency = 0.1
minusBtn.Text = "-"; minusBtn.TextColor3 = C_MOON2; minusBtn.Font = Enum.Font.GothamBold; minusBtn.TextSize = 13
minusBtn.BorderSizePixel = 0; minusBtn.AutoButtonColor = false
addCorner(minusBtn, 5); addLivingStroke(minusBtn, 1)

local powerBox = Instance.new("TextBox", sbW)
powerBox.Size = UDim2.new(0,62,0,22); powerBox.Position = UDim2.new(0.5,-31,0,110)
powerBox.BackgroundColor3 = C_OFF_BG; powerBox.BackgroundTransparency = 0.1
powerBox.Text = tostring(power); powerBox.TextColor3 = C_SILVER
powerBox.Font = Enum.Font.GothamBold; powerBox.TextSize = 11
powerBox.BorderSizePixel = 0; powerBox.ClearTextOnFocus = false
addCorner(powerBox, 5); addLivingStroke(powerBox, 1)

local plusBtn = Instance.new("TextButton", sbW)
plusBtn.Size = UDim2.new(0,22,0,22); plusBtn.Position = UDim2.new(1,-30,0,110)
plusBtn.BackgroundColor3 = C_OFF_BG; plusBtn.BackgroundTransparency = 0.1
plusBtn.Text = "+"; plusBtn.TextColor3 = C_MOON2; plusBtn.Font = Enum.Font.GothamBold; plusBtn.TextSize = 13
plusBtn.BorderSizePixel = 0; plusBtn.AutoButtonColor = false
addCorner(plusBtn, 5); addLivingStroke(plusBtn, 1)

minusBtn.MouseButton1Click:Connect(function()
	applyPower(power - 1000); powerBox.Text = tostring(power)
end)
plusBtn.MouseButton1Click:Connect(function()
	applyPower(power + 1000); powerBox.Text = tostring(power)
end)
powerBox.FocusLost:Connect(function()
	local val = tonumber(powerBox.Text)
	if val then applyPower(val); powerBox.Text = tostring(power)
	else powerBox.Text = tostring(power) end
end)

local footer = Instance.new("TextLabel", sbW)
footer.Size = UDim2.new(1,-16,0,16); footer.Position = UDim2.new(0,8,0,142)
footer.BackgroundTransparency = 1; footer.Text = "MOON V3  •  Speed Bypass"
footer.TextColor3 = C_SILVER2; footer.Font = Enum.Font.Gotham; footer.TextSize = 8
footer.TextXAlignment = Enum.TextXAlignment.Center; addLivingTextGradient(footer)

local function toggleMinimize()
	minimized = not minimized
	sbMinBtn.Text = minimized and "+" or "-"
	sbW.Size = minimized and UDim2.new(0,150,0,34) or UDim2.new(0,150,0,sbFullH)
	local elements = {toggleBtn, bindRow, powerLbl, minusBtn, powerBox, plusBtn, footer}
	for _, el in ipairs(elements) do el.Visible = not minimized end
end
sbMinBtn.MouseButton1Click:Connect(toggleMinimize)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if waitingForKey then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			keybind = input.KeyCode
			bindBtn.Text = keybind.Name
			waitingForKey = false
		end
		return
	end
	if input.KeyCode == keybind then toggle() end
end)

-- [FIX #7] stopLag() forçait activated=false puis on le repassait à true manuellement.
-- On reconnecte la boucle directement sans toucher à `activated`.
LP.CharacterAdded:Connect(function()
	task.wait(1)
	if activated then
		if lagConn then lagConn:Disconnect(); lagConn = nil end
		startLag()
	end
end)
end)();  -- required semicolon (otherwise ambiguous merge with the (function() below)

-- ===================================================================
-- MOON LAGGER (source moon_lgr.txt — integrated as-is)
-- ===================================================================
(function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local ConfigFile = "MoonLaggerConfig.json"

local NIVELES = {
	Low   = { poder = 23 },
	Mid   = { poder = 32 },
	High  = { poder = 70 },
	Ultra = { poder = 90 }
}

local keybind = Enum.KeyCode.M
local listeningForInput = false
local laggerActive = false
local lagThread = nil
local nivelActual = "Low"
local ventanaBloqueada = false

local function SaveConfig()
	local data = { Nivel = nivelActual, Bloqueado = ventanaBloqueada }
	pcall(function() writefile(ConfigFile, HttpService:JSONEncode(data)) end)
end

-- [FIX #4] pcall(isfile, ConfigFile) retourne (bool, résultat) — pas le résultat
-- directement. L'ancien code appelait isfile() deux fois dont une non protégée.
local function LoadConfig()
	local ok, exists = pcall(isfile, ConfigFile)
	if not ok or not exists then return end
	local rok, content = pcall(readfile, ConfigFile)
	if not rok then return end
	pcall(function()
		local data = HttpService:JSONDecode(content)
		nivelActual      = data.Nivel     or "Low"
		ventanaBloqueada = data.Bloqueado or false
	end)
end
LoadConfig()

local function bomb(poder)
	local main, spam = {}, {{}}
	local z = spam[1]
	for i = 1, 25 do local t = {} table.insert(z, t) z = t end
	local max = math.min(12000, poder * 50)
	for i = 1, max do table.insert(main, spam) end
	pcall(function() game:GetService("RobloxReplicatedStorage").SetPlayerBlockList:FireServer(main) end)
end

-- ══════════════════════════════════════
-- CLEANUP
-- ══════════════════════════════════════
pcall(function() if CoreGui:FindFirstChild("MoonLagger_UI") then CoreGui.MoonLagger_UI:Destroy() end end)

-- ══════════════════════════════════════
-- SCREEN GUI
-- ══════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name = _NS
if not pcall(function() screenGui.Parent = CoreGui end) then screenGui.Parent = player:WaitForChild("PlayerGui") end
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ResetOnSpawn = false

-- ══════════════════════════════════════
-- MAIN FRAME
-- ══════════════════════════════════════
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel = 1
mainFrame.BorderColor3 = Color3.fromRGB(50, 50, 50)
mainFrame.Size = UDim2.new(0, 200, 0, 88)
mainFrame.Position = UDim2.new(0.15, 0, 0.5, -44)
mainFrame.Parent = screenGui
mainFrame.Visible = false
_lgrBypassWidget = mainFrame
mainFrame.ClipsDescendants = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- MINIMIZE Button

-- STROKE
local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = Color3.fromRGB(60, 60, 60)
mainStroke.Thickness = 1.2
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Animated glow on the edge
task.spawn(function()
	while mainStroke.Parent do
		TweenService:Create(mainStroke, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Color = Color3.fromRGB(120, 120, 120), Thickness = 1.6
		}):Play()
		task.wait(2.1)
		TweenService:Create(mainStroke, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Color = Color3.fromRGB(40, 40, 40), Thickness = 1.2
		}):Play()
		task.wait(2.1)
	end
end)

-- ══════════════════════════════════════
-- RISING BLACK & WHITE BUBBLES
-- ══════════════════════════════════════
local bubbleColors = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(200, 200, 200),
	Color3.fromRGB(160, 160, 160),
	Color3.fromRGB(100, 100, 100),
	Color3.fromRGB(50, 50, 50),
}

local function spawnBubble()
	local size = math.random(3, 9)
	local bub = Instance.new("Frame", mainFrame)
	bub.Size = UDim2.new(0, size, 0, size)
	bub.Position = UDim2.new(math.random(5, 95) / 100, 0, 1, size)
	bub.BackgroundColor3 = bubbleColors[math.random(1, #bubbleColors)]
	bub.BackgroundTransparency = math.random(20, 55) / 100
	bub.BorderSizePixel = 0
	bub.ZIndex = 1
	Instance.new("UICorner", bub).CornerRadius = UDim.new(1, 0)
	local duration = math.random(20, 42) / 10
	TweenService:Create(bub, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Position = UDim2.new(bub.Position.X.Scale, 0, 0, -size - 2),
		BackgroundTransparency = 1
	}):Play()
	task.delay(duration + 0.1, function()
		pcall(function() bub:Destroy() end)
	end)
end

task.spawn(function()
	while mainFrame.Parent do
		task.wait(math.random(10, 28) / 100)
		pcall(spawnBubble)
	end
end)

-- ══════════════════════════════════════
-- CIRCLE WITH IMAGE (moon icon)
-- ══════════════════════════════════════
local iconCircle = Instance.new("ImageLabel", mainFrame)
iconCircle.Name = "IconCircle"
iconCircle.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
iconCircle.BackgroundTransparency = 0
iconCircle.Position = UDim2.new(0, 6, 0, 4)
iconCircle.Size = UDim2.new(0, 20, 0, 20)
iconCircle.Image = "rbxassetid://139714600005415"
iconCircle.ScaleType = Enum.ScaleType.Crop
iconCircle.ZIndex = 3
Instance.new("UICorner", iconCircle).CornerRadius = UDim.new(1, 0)
local iconCircleStroke = Instance.new("UIStroke", iconCircle)
iconCircleStroke.Color = Color3.fromRGB(70, 70, 70)
iconCircleStroke.Thickness = 1

-- ══════════════════════════════════════
-- "MOON LAGGER" TITLE
-- ══════════════════════════════════════
local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.new(0, 30, 0, 0)
titleLabel.Size = UDim2.new(0, 120, 0, 22)
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.Text = "MOON LAGGER"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextYAlignment = Enum.TextYAlignment.Center
titleLabel.ZIndex = 3
titleLabel.TextStrokeTransparency = 0
titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

-- Animated shimmer on the title
local shimmerLbl = Instance.new("TextLabel", mainFrame)
shimmerLbl.BackgroundTransparency = 1
shimmerLbl.Position = UDim2.new(0, 30, 0, 0)
shimmerLbl.Size = UDim2.new(0, 120, 0, 22)
shimmerLbl.Font = Enum.Font.GothamBlack
shimmerLbl.Text = "MOON LAGGER"
shimmerLbl.TextSize = 13
shimmerLbl.TextXAlignment = Enum.TextXAlignment.Left
shimmerLbl.TextYAlignment = Enum.TextYAlignment.Center
shimmerLbl.ZIndex = 4
shimmerLbl.ClipsDescendants = true
shimmerLbl.TextColor3 = Color3.fromRGB(220, 220, 220)

local shimmerGrad = Instance.new("UIGradient", shimmerLbl)
shimmerGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(160, 160, 160)),
	ColorSequenceKeypoint.new(0.3, Color3.fromRGB(220, 220, 220)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.7, Color3.fromRGB(220, 220, 220)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(160, 160, 160)),
})
shimmerGrad.Rotation = 0

task.spawn(function()
	while mainFrame.Parent do
		for i = 0, 1, 0.006 do
			if not mainFrame.Parent then break end
			shimmerGrad.Offset = Vector2.new(i, 0)
			task.wait(0.025)
		end
	end
end)

-- ══════════════════════════════════════
-- KEY & LOCK BUTTONS (top right)
-- ══════════════════════════════════════
local keybindButton = Instance.new("TextButton", mainFrame)
keybindButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
keybindButton.BackgroundTransparency = 0
keybindButton.Position = UDim2.new(1, -65, 0, 2)
keybindButton.Size = UDim2.new(0, 34, 0, 12)
keybindButton.Font = Enum.Font.GothamBlack
keybindButton.TextColor3 = Color3.fromRGB(200, 200, 200)
keybindButton.TextSize = 6
keybindButton.AutoButtonColor = false
keybindButton.ZIndex = 5
Instance.new("UICorner", keybindButton).CornerRadius = UDim.new(0, 5)
Instance.new("UIStroke", keybindButton).Color = Color3.fromRGB(55, 55, 55)

local lockButton = Instance.new("TextButton", mainFrame)
lockButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
lockButton.BackgroundTransparency = 0
lockButton.Position = UDim2.new(1, -29, 0, 2)
lockButton.Size = UDim2.new(0, 26, 0, 12)
lockButton.Font = Enum.Font.GothamBlack
lockButton.TextSize = 9
lockButton.TextColor3 = Color3.fromRGB(200, 200, 200)
lockButton.AutoButtonColor = false
lockButton.ZIndex = 5
Instance.new("UICorner", lockButton).CornerRadius = UDim.new(0, 5)
Instance.new("UIStroke", lockButton).Color = Color3.fromRGB(55, 55, 55)

-- ══════════════════════════════════════
-- "📈" LABEL (formerly "LAGGER")
-- ══════════════════════════════════════
local textLagger = Instance.new("TextLabel", mainFrame)
textLagger.BackgroundTransparency = 1
textLagger.Position = UDim2.new(0, 8, 0, 24)
textLagger.Size = UDim2.new(0, 65, 0, 18)
textLagger.Font = Enum.Font.GothamBlack
textLagger.Text = "📈"
textLagger.TextColor3 = Color3.fromRGB(200, 200, 200)
textLagger.TextSize = 14
textLagger.TextXAlignment = Enum.TextXAlignment.Left
textLagger.TextYAlignment = Enum.TextYAlignment.Center
textLagger.ZIndex = 3
textLagger.TextStrokeTransparency = 0
textLagger.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

-- ══════════════════════════════════════
-- TOGGLE SWITCH
-- ══════════════════════════════════════
local toggleContainer = Instance.new("Frame", mainFrame)
toggleContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
toggleContainer.Position = UDim2.new(1, -54, 0, 25)
toggleContainer.Size = UDim2.new(0, 46, 0, 18)
toggleContainer.ZIndex = 3
Instance.new("UICorner", toggleContainer).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", toggleContainer).Color = Color3.fromRGB(60, 60, 60)

local toggleBall = Instance.new("Frame", toggleContainer)
toggleBall.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
toggleBall.Size = UDim2.new(0, 14, 0, 14)
toggleBall.Position = UDim2.new(0, 2, 0.5, -7)
toggleBall.ZIndex = 4
Instance.new("UICorner", toggleBall).CornerRadius = UDim.new(1, 0)

local toggleClick = Instance.new("TextButton", toggleContainer)
toggleClick.BackgroundTransparency = 1
toggleClick.Size = UDim2.new(1, 0, 1, 0)
toggleClick.ZIndex = 5
toggleClick.Font = Enum.Font.GothamBlack
toggleClick.Text = "INACTIVE"
toggleClick.TextSize = 6
toggleClick.TextColor3 = Color3.fromRGB(180, 50, 50)
toggleClick.TextXAlignment = Enum.TextXAlignment.Center
toggleClick.TextYAlignment = Enum.TextYAlignment.Center
toggleClick.AutoButtonColor = false
Instance.new("UICorner", toggleClick).CornerRadius = UDim.new(1, 0)

-- ══════════════════════════════════════
-- SEPARATOR
-- ══════════════════════════════════════
local sep = Instance.new("Frame", mainFrame)
sep.Size = UDim2.new(1, -16, 0, 1)
sep.Position = UDim2.new(0, 8, 0, 47)
sep.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
sep.BorderSizePixel = 0
sep.ZIndex = 3

-- ══════════════════════════════════════
-- LEVEL SELECTOR — SLIDING PILLS STYLE
-- ══════════════════════════════════════
-- Selector container
local selectorFrame = Instance.new("Frame", mainFrame)
selectorFrame.Size = UDim2.new(1, -16, 0, 24)
selectorFrame.Position = UDim2.new(0, 8, 0, 52)
selectorFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
selectorFrame.BorderSizePixel = 0
selectorFrame.ZIndex = 3
Instance.new("UICorner", selectorFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", selectorFrame).Color = Color3.fromRGB(45, 45, 45)

-- Active pill (slides under the selection)
local activePill = Instance.new("Frame", selectorFrame)
activePill.Size = UDim2.new(0.25, -2, 1, -4)
activePill.Position = UDim2.new(0, 1, 0, 2)
activePill.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
activePill.BorderSizePixel = 0
activePill.ZIndex = 4
Instance.new("UICorner", activePill).CornerRadius = UDim.new(0, 6)

-- Animated stroke on the active pill
local pillStroke = Instance.new("UIStroke", activePill)
pillStroke.Color = Color3.fromRGB(200, 200, 200)
pillStroke.Thickness = 1
pillStroke.Transparency = 0.3

local LEVELS = {"Low", "Mid", "High", "Ultra"}
local LEVEL_COLORS = {
	Low   = Color3.fromRGB(80,  220, 100),
	Mid   = Color3.fromRGB(240, 220, 60),
	High  = Color3.fromRGB(230, 70,  70),
	Ultra = Color3.fromRGB(200, 150, 255),
}

local levelBtns = {}

for i, name in ipairs(LEVELS) do
	local btn = Instance.new("TextButton", selectorFrame)
	btn.Size = UDim2.new(0.25, 0, 1, 0)
	btn.Position = UDim2.new((i - 1) * 0.25, 0, 0, 0)
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBlack
	btn.Text = name:upper()
	btn.TextSize = 7
	btn.TextColor3 = Color3.fromRGB(130, 130, 130)
	btn.ZIndex = 6
	btn.AutoButtonColor = false
	levelBtns[name] = btn
end

-- TRYHARD TEXT (Ultra)
local tryhardText = Instance.new("TextLabel", mainFrame)
tryhardText.BackgroundTransparency = 1
tryhardText.Position = UDim2.new(0, 8, 0, 78)
tryhardText.Size = UDim2.new(0, 140, 0, 10)
tryhardText.Font = Enum.Font.GothamBlack
tryhardText.Text = "Only for tryhards"
tryhardText.TextColor3 = Color3.fromRGB(200, 150, 255)
tryhardText.TextSize = 7
tryhardText.TextXAlignment = Enum.TextXAlignment.Left
tryhardText.ZIndex = 3
tryhardText.Visible = false
tryhardText.TextStrokeTransparency = 0.5
tryhardText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

-- ══════════════════════════════════════
-- UPDATE FUNCTIONS
-- ══════════════════════════════════════
local function getPillXPos(levelName)
	for i, name in ipairs(LEVELS) do
		if name == levelName then
			return UDim2.new((i - 1) * 0.25, 1, 0, 2)
		end
	end
	return UDim2.new(0, 1, 0, 2)
end

local function actualizarBotonesNivel()
	-- Animate the pill toward the selection
	TweenService:Create(activePill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = getPillXPos(nivelActual)
	}):Play()
	-- Pill color = level color
	TweenService:Create(activePill, TweenInfo.new(0.15), {
		BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	}):Play()
	TweenService:Create(pillStroke, TweenInfo.new(0.15), {
		Color = LEVEL_COLORS[nivelActual]
	}):Play()
	-- Texts
	for name, btn in pairs(levelBtns) do
		if name == nivelActual then
			TweenService:Create(btn, TweenInfo.new(0.15), {
				TextColor3 = LEVEL_COLORS[nivelActual]
			}):Play()
		else
			TweenService:Create(btn, TweenInfo.new(0.15), {
				TextColor3 = Color3.fromRGB(100, 100, 100)
			}):Play()
		end
	end
	tryhardText.Visible = (nivelActual == "Ultra")
end

local function actualizarSwitch()
	if laggerActive then
		TweenService:Create(toggleBall, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Position = UDim2.new(1, -16, 0.5, -7),
			BackgroundColor3 = Color3.fromRGB(230, 230, 230)
		}):Play()
		TweenService:Create(toggleContainer, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		}):Play()
		toggleClick.Text = "ACTIVE"
		toggleClick.TextColor3 = Color3.fromRGB(80, 230, 100)
	else
		TweenService:Create(toggleBall, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0, 2, 0.5, -7),
			BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		}):Play()
		TweenService:Create(toggleContainer, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		}):Play()
		toggleClick.Text = "INACTIVE"
		toggleClick.TextColor3 = Color3.fromRGB(180, 50, 50)
	end
end

local function actualizarCandado()
	lockButton.Text = ventanaBloqueada and "🔒" or "🔓"
	lockButton.TextColor3 = ventanaBloqueada
		and Color3.fromRGB(255, 200, 60)
		or  Color3.fromRGB(160, 160, 160)
end

local function actualizarKeybindButton()
	if keybindButton then
		local display = keybind.Name
		if display:match("Button") then display = display:gsub("Button", "") end
		keybindButton.Text = "KEY: " .. display
	end
end

-- ══════════════════════════════════════
-- TOGGLE LAGGER
-- ══════════════════════════════════════
local function toggleLagger()
	laggerActive = not laggerActive
	actualizarSwitch()
	if laggerActive then
		if lagThread then task.cancel(lagThread) end
		lagThread = task.spawn(function()
			while laggerActive do
				pcall(function() game:GetService("NetworkClient"):SetOutgoingKBPSLimit(80000) end)
				bomb(NIVELES[nivelActual].poder)
				task.wait(0.18)
			end
		end)
	else
		if lagThread then task.cancel(lagThread); lagThread = nil end
	end
end

-- ══════════════════════════════════════
-- LEVEL BUTTON CONNECTIONS
-- ══════════════════════════════════════
for _, name in ipairs(LEVELS) do
	local btn = levelBtns[name]
	local n = name
	btn.MouseButton1Click:Connect(function()
		nivelActual = n
		actualizarBotonesNivel()
		SaveConfig()
	end)
end

-- ══════════════════════════════════════
-- TOGGLE CLICK
-- ══════════════════════════════════════
toggleClick.MouseButton1Click:Connect(toggleLagger)

-- ══════════════════════════════════════
-- KEYBIND
-- ══════════════════════════════════════
keybindButton.MouseButton1Click:Connect(function()
	if listeningForInput then return end
	listeningForInput = true
	keybindButton.Text = "KEY: ..."
	keybindButton.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
	keybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if listeningForInput then
		if gp then return end
		local newKey = nil
		if input.KeyCode ~= Enum.KeyCode.Unknown then newKey = input.KeyCode end
		if newKey then
			keybind = newKey
			actualizarKeybindButton()
			listeningForInput = false
			keybindButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			keybindButton.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
		return
	end
	if gp then return end
	if input.KeyCode == keybind then toggleLagger() end
end)

-- ══════════════════════════════════════
-- LOCK BUTTON
-- ══════════════════════════════════════
lockButton.MouseButton1Click:Connect(function()
	ventanaBloqueada = not ventanaBloqueada
	actualizarCandado()
	SaveConfig()
end)

-- ══════════════════════════════════════
-- DRAG
-- ══════════════════════════════════════
local isDragging, dragStart, startPos = false, nil, nil
mainFrame.InputBegan:Connect(function(input)
	if ventanaBloqueada then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = true; dragStart = input.Position; startPos = mainFrame.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not isDragging or ventanaBloqueada then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)
mainFrame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = false
	end
end)

-- ══════════════════════════════════════
-- INIT
-- ══════════════════════════════════════
actualizarKeybindButton()
actualizarCandado()
actualizarBotonesNivel()
actualizarSwitch()
end)()


-- ===================================================================
-- INITIALIZATION
-- ===================================================================
local _configLoaded = MH_load()   -- loads the config at startup
selectTab("Combat")
-- No save file: start Auto Steal immediately (it defaults to enabled).
-- When a save exists, MH_load already re-activates it via the toggles table.
if not _configLoaded and AutoSteal.Enabled then
	task.spawn(startAutoSteal)
end
-- Auto-save every 10s
task.spawn(function()
	while gui.Parent do
		task.wait(10)
		MH_save()
	end
end)

-- Immediate save if the player leaves / script is destroyed
LP.AncestryChanged:Connect(function()
	pcall(MH_save)
end)
game:GetService("Players").PlayerRemoving:Connect(function(p)
	if p == LP then pcall(MH_save) end
end)

end
_MH_buildUI()
