--[[
    test_speed.lua — Script solo : Custom Speed + Speed Bypass + Auto Steal
    (extrait/adapté de MoonHub_v16.lua) — thème 100% noir, effets "Moon" en noir/blanc.

    La détection Auto Steal est la logique EXACTE "Irish Hub" (ProximityPrompt
    + sync ReplicatedStorage), fournie telle quelle — remplace l'ancien
    Auto Grab basé sur WalkSpeed qui n'avait aucun signal réel à détecter.

    Teste ça en jeu. Si ça te convient, dis-le moi et je remets ça
    proprement dans MoonHub_v16.lua si besoin.
]]

local Players     = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats        = game:GetService("Stats")
local RS           = game:GetService("ReplicatedStorage")
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
-- THÈME — 100% noir, aucune couleur bleue (sauf indicateurs READY/UNREADY
-- qui restent vert/rouge, utile fonctionnellement)
-- ===================================================================
local C_BG    = Color3.fromRGB(0,0,0)
local C_ON    = Color3.fromRGB(30,30,30)
local C_OFF   = Color3.fromRGB(0,0,0)
local C_ROW   = Color3.fromRGB(14,14,14)
local C_WHITE = Color3.fromRGB(255,255,255)
local C_DIM   = Color3.fromRGB(130,130,130)
local C_GREEN = Color3.fromRGB(60,220,120)
local C_RED   = Color3.fromRGB(220,60,60)

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
-- proxy part soudé au HRP + AssemblyLinearVelocity. speedType ("normal"/
-- "carry") est maintenant piloté par le bouton MODE ou par Auto Steal
-- (vraie détection ProximityPrompt ci-dessous), plus par WalkSpeed.
-- ===================================================================
local normalSpeed = 60
local stealSpeed  = 30
local speedType = "normal"
local _carryManualUntil = 0  -- garde anti-conflit après un choix manuel

local function getCurrentSpeed()
	return speedType == "carry" and stealSpeed or normalSpeed
end

local h, hrp, proxy
local function ensureProxy()
	local char = LP.Character
	if not char then return nil end
	hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	-- Ne réutilise le proxy existant QUE s'il est encore soudé au HRP actuel
	-- (sinon c'est un proxy périmé de l'ancien personnage, avant mort/reset).
	if proxy and proxy.Parent then
		local w = proxy:FindFirstChildOfClass("Weld")
		if w and w.Part0 == hrp then return proxy end
		pcall(function() proxy:Destroy() end)
	end
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
	-- Personnage précédent (mort/reset) : on jette l'ancien proxy, il pointe
	-- vers un HRP qui n'existe plus.
	if proxy then pcall(function() proxy:Destroy() end); proxy = nil end
	h = char:WaitForChild("Humanoid", 5)
	hrp = char:WaitForChild("HumanoidRootPart", 5)
	if h then h.WalkSpeed = getCurrentSpeed() end
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
	if h then h.WalkSpeed = getCurrentSpeed() end
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
-- AUTO GRAB — logique EXACTE "Auto Carry On Grab" du hub : bascule
-- speedType en "carry" UNIQUEMENT quand l'animal est réellement dans les
-- mains (signal serveur réel : WalkSpeed ≤ 25), pas pendant la simple
-- tentative de vol (READY/UNREADY d'Auto Steal ci-dessous, qui reste
-- séparé et purement informatif).
-- ===================================================================
local autoGrabOn = true
local lastCarryDetected = false

RunService.Heartbeat:Connect(function()
	if not autoGrabOn then return end
	local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if tick() < _carryManualUntil then return end
	local carrying = hum.WalkSpeed <= 25
	if carrying == lastCarryDetected then return end
	lastCarryDetected = carrying
	speedType = carrying and "carry" or "normal"
end)

-- ===================================================================
-- AUTO STEAL — logique EXACTE "Irish Hub" : sync ReplicatedStorage des
-- plots + détection réelle via ProximityPrompt (hold/trigger interceptés),
-- pas de WalkSpeed. C'est la vraie détection utilisée par le hub complet.
-- ===================================================================
local autoStealOn = true
local IrishSync = { caches={}, connections={} }
local _animalsCache = {}
local _promptCache  = {}
local _stealCache   = {}
local _stealActive  = false
local _stealStart   = 0
local _stealState   = "READY"
local RADIUS = 70
local CFG = { HOLD_MIN=1.3, HOLD_MAX=2.6, ENTRY_DELAY=0.3, COOLDOWN=0.05, STEAL_RANGE=8 }

local _packages = RS:FindFirstChild("Packages")
local _datas    = RS:FindFirstChild("Datas")
local _animData = nil
if _datas then task.spawn(function() pcall(function() local m = _datas:FindFirstChild("Animals"); if m then _animData = require(m) end end) end) end

local function splitPath(path)
	if typeof(path)=="table" then return path end
	local out = {}
	for p in string.gmatch(tostring(path), "[^%.]+") do table.insert(out, tonumber(p) or p) end
	return out
end
local function resolvePath(path, root)
	local cur = root; local par = nil; local key = nil
	for _,p in ipairs(splitPath(path)) do par = cur; key = p; cur = cur and cur[p] or nil end
	return cur, par, key
end
local function applyDiff(cn, packet)
	local cache = IrishSync.caches[cn]; if typeof(cache) ~= "table" then return end
	local path, action, a, b = packet[1], packet[2], packet[3], packet[4]
	local cur, par, key = resolvePath(path, cache)
	if action=="Changed" then if par~=nil then par[key]=a end
	elseif action=="ArrayInsert" then if cur~=nil then table.insert(cur,b,a) end
	elseif action=="ArrayRemoved" then if cur~=nil then table.remove(cur,b) end
	elseif action=="DictionaryInsert" then if cur~=nil then cur[b]=a end
	elseif action=="DictionaryRemoved" then if cur~=nil then cur[b]=nil end end
end

local _syncRemotes = nil
pcall(function()
	if not _packages then return end
	local f = _packages:FindFirstChild("Synchronizer"); if not f then return end
	_syncRemotes = {
		channelFolder = f:FindFirstChild("Channel"),
		routeRemote   = f:FindFirstChild("CommunicationRoute"),
		requestData   = f:FindFirstChild("RequestData"),
	}
end)

local function attachChannel(remote)
	if IrishSync.connections[remote] then return end
	local cn = tostring(remote.Name)
	local plots = workspace:FindFirstChild("Plots"); if not plots or not plots:FindFirstChild(cn) then return end
	if _syncRemotes.requestData and IrishSync.caches[cn]==nil then
		local ok,data = pcall(function() return _syncRemotes.requestData:InvokeServer(cn) end)
		IrishSync.caches[cn] = (ok and typeof(data)=="table") and data or {}
	elseif IrishSync.caches[cn]==nil then IrishSync.caches[cn]={} end
	IrishSync.connections[remote] = remote.OnClientEvent:Connect(function(queue)
		for _,packet in ipairs(queue) do applyDiff(cn, packet) end
	end)
end

if _syncRemotes and _syncRemotes.channelFolder then
	task.spawn(function()
		for _,child in ipairs(_syncRemotes.channelFolder:GetChildren()) do
			if child:IsA("RemoteEvent") then pcall(attachChannel, child) end
		end
	end)
	_syncRemotes.channelFolder.ChildAdded:Connect(function(child)
		if child:IsA("RemoteEvent") then task.spawn(function() pcall(attachChannel, child) end) end
	end)
	if _syncRemotes.routeRemote then
		_syncRemotes.routeRemote.OnClientEvent:Connect(function(actions)
			for _,action in ipairs(actions) do
				local kind, cn = action[1], tostring(action[2])
				local plots = workspace:FindFirstChild("Plots")
				if plots and plots:FindFirstChild(cn) then
					if kind=="ListenerAdded" then
						local r = _syncRemotes.channelFolder:FindFirstChild(cn)
						if r and r:IsA("RemoteEvent") then task.spawn(function() pcall(attachChannel,r) end) end
					elseif kind=="ListenerRemoved" then
						for rem,conn in pairs(IrishSync.connections) do
							if tostring(rem.Name)==cn then conn:Disconnect(); IrishSync.connections[rem]=nil; IrishSync.caches[cn]=nil; break end
						end
					end
				end
			end
		end)
	end
end

local function getPlotOwner(plot)
	local sign = plot:FindFirstChild("PlotSign")
	local frame = sign and sign:FindFirstChild("SurfaceGui") and sign.SurfaceGui:FindFirstChild("Frame")
	local label = frame and frame:FindFirstChild("TextLabel")
	if not label or label.Text=="Empty Base" then return nil end
	return label.Text:gsub("'s [Bb]ase$",""):gsub("%s+$","")
end
local function isMyAnimal(a)
	if not a or not a.plot then return false end
	local plots = workspace:FindFirstChild("Plots"); if not plots then return false end
	local plot = plots:FindFirstChild(a.plot); if not plot then return false end
	return getPlotOwner(plot) == LP.DisplayName
end
local function findPrompt(a)
	if not a then return nil end
	local cached = _promptCache[a.uid]; if cached and cached.Parent then return cached end
	local plots = workspace:FindFirstChild("Plots"); if not plots then return nil end
	local plot = plots:FindFirstChild(a.plot); if not plot then return nil end
	local pods = plot:FindFirstChild("AnimalPodiums"); if not pods then return nil end
	local pod = pods:FindFirstChild(a.slot); if not pod then return nil end
	local base = pod:FindFirstChild("Base"); if not base then return nil end
	local sp = base:FindFirstChild("Spawn"); if not sp then return nil end
	local att = sp:FindFirstChild("PromptAttachment"); if not att then return nil end
	for _,p in ipairs(att:GetChildren()) do if p:IsA("ProximityPrompt") then _promptCache[a.uid]=p; return p end end
	return nil
end
local function getPos(a)
	local plots = workspace:FindFirstChild("Plots"); if not plots then return nil end
	local plot = plots:FindFirstChild(a.plot); if not plot then return nil end
	local pods = plot:FindFirstChild("AnimalPodiums"); if not pods then return nil end
	local pod = pods:FindFirstChild(a.slot); if not pod then return nil end
	local ok,pos = pcall(function() return pod:GetPivot().Position end); return ok and pos or nil
end
local function distTo(a)
	local char = LP.Character; if not char then return math.huge end
	local h2 = char:FindFirstChild("HumanoidRootPart"); if not h2 then return math.huge end
	local pos = getPos(a); if not pos then return math.huge end
	return (h2.Position - pos).Magnitude
end
local function pickClosest()
	local char = LP.Character; local h2 = char and char:FindFirstChild("HumanoidRootPart"); if not h2 then return nil end
	local best, bestD = nil, math.huge
	for _,a in ipairs(_animalsCache) do
		if not isMyAnimal(a) then
			local pos = getPos(a)
			if pos then
				local d = (h2.Position-pos).Magnitude
				if d<=RADIUS and d<bestD then bestD=d; best=a end
			end
		end
	end
	return best
end
local function buildCallbacks(prompt)
	if _stealCache[prompt] then return end
	local data = {hold={}, trigger={}, ready=true}
	local ok1,c1 = pcall(getconnections, prompt.PromptButtonHoldBegan)
	if ok1 and type(c1)=="table" then for _,c in ipairs(c1) do if type(c.Function)=="function" then table.insert(data.hold,c.Function) end end end
	local ok2,c2 = pcall(getconnections, prompt.Triggered)
	if ok2 and type(c2)=="table" then for _,c in ipairs(c2) do if type(c.Function)=="function" then table.insert(data.trigger,c.Function) end end end
	if #data.hold>0 or #data.trigger>0 then _stealCache[prompt]=data end
end
local function scanAllPlots()
	local newCache = {}
	local plots = workspace:FindFirstChild("Plots"); if not plots then _animalsCache=newCache; return end
	for _,plot in ipairs(plots:GetChildren()) do
		local cache = IrishSync.caches[plot.Name]
		if cache and typeof(cache)=="table" then
			local list = cache.AnimalList
			if typeof(list)=="table" then
				for slot,ad in pairs(list) do
					if type(ad)=="table" then
						local name = ad.Index
						local info = _animData and _animData[name]
						if info or not _animData then
							table.insert(newCache, {name=(info and info.DisplayName) or name, plot=plot.Name, slot=tostring(slot), uid=plot.Name.."_"..tostring(slot)})
						end
					end
				end
			end
		end
	end
	_animalsCache = newCache
end

-- ===================================================================
-- STEAL WIDGET — READY/UNREADY, %, FPS|ping, noir avec accent vert/rouge
-- ===================================================================
local stealWidget = Instance.new("Frame", gui)
stealWidget.Name = "StealBarWidget"
stealWidget.Size = UDim2.new(0, 280, 0, 40)
stealWidget.Position = UDim2.new(0.5, -140, 0, 35)
stealWidget.BackgroundTransparency = 1
stealWidget.Active = true

local stealPill = Instance.new("Frame", stealWidget)
stealPill.Size = UDim2.new(1,0,1,0)
stealPill.BackgroundColor3 = C_BG
stealPill.BackgroundTransparency = 0.1
stealPill.BorderSizePixel = 0
stealPill.ClipsDescendants = true
addCorner(stealPill, 18)
local stealPillStk = addLivingStroke(stealPill, 1.5)

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
local stealEdge = Instance.new("Frame", stealFill)
stealEdge.AnchorPoint = Vector2.new(1,0.5)
stealEdge.Size = UDim2.new(0,4,1,-6)
stealEdge.Position = UDim2.new(1,0,0.5,0)
stealEdge.BackgroundColor3 = C_WHITE
stealEdge.BorderSizePixel = 0
stealEdge.ZIndex = 2
addCorner(stealEdge, 2)

local readyLbl = Instance.new("TextLabel", stealPill)
readyLbl.Size = UDim2.new(0.56,-16,1,0)
readyLbl.Position = UDim2.new(0,16,0,0)
readyLbl.BackgroundTransparency = 1
readyLbl.Text = "READY"
readyLbl.TextColor3 = C_WHITE
readyLbl.Font = Enum.Font.GothamBlack
readyLbl.TextSize = 13
readyLbl.TextXAlignment = Enum.TextXAlignment.Left
readyLbl.ZIndex = 5
local _readyGradient = addLivingTextGradient(readyLbl)

local pctLbl = Instance.new("TextLabel", stealPill)
pctLbl.Size = UDim2.new(0.56,-40,1,0)
pctLbl.Position = UDim2.new(0,16,0,0)
pctLbl.BackgroundTransparency = 1
pctLbl.Text = ""
pctLbl.TextColor3 = C_WHITE
pctLbl.Font = Enum.Font.GothamBlack
pctLbl.TextSize = 13
pctLbl.TextXAlignment = Enum.TextXAlignment.Right
pctLbl.ZIndex = 5
addLivingTextGradient(pctLbl)

local infoLbl = Instance.new("TextLabel", stealPill)
infoLbl.Size = UDim2.new(0.44,-16,1,0)
infoLbl.Position = UDim2.new(0.56,16,0,0)
infoLbl.BackgroundTransparency = 1
infoLbl.Text = "0 FPS | 0ms"
infoLbl.TextColor3 = C_WHITE
infoLbl.Font = Enum.Font.GothamBold
infoLbl.TextSize = 13
infoLbl.TextXAlignment = Enum.TextXAlignment.Left
infoLbl.ZIndex = 5
addLivingTextGradient(infoLbl)

local function setReadyColor(state)
	local isReady = (state == "READY")
	local col1 = isReady and Color3.fromRGB(30,120,60)  or Color3.fromRGB(120,20,20)
	local col2 = isReady and C_GREEN or C_RED
	local col3 = isReady and Color3.fromRGB(90,255,150) or Color3.fromRGB(255,100,100)
	readyLbl.TextColor3 = col2
	if _readyGradient then
		_readyGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,    col3),
			ColorSequenceKeypoint.new(0.25, col1),
			ColorSequenceKeypoint.new(0.5,  col3),
			ColorSequenceKeypoint.new(0.75, col1),
			ColorSequenceKeypoint.new(1,    col3),
		})
	end
	TweenService:Create(stealPillStk, TweenInfo.new(0.2), {Color = col2}):Play()
end

-- FPS / ping loop
local frameCount, lastFpsTime, lastFps, lastPing = 0, tick(), 60, 0
local function refreshInfo() infoLbl.Text = lastFps .. " FPS | " .. lastPing .. "ms" end
RunService.RenderStepped:Connect(function()
	frameCount = frameCount + 1
	local now = tick()
	if now - lastFpsTime >= 1 then
		lastFps = math.floor(frameCount / (now - lastFpsTime))
		frameCount = 0; lastFpsTime = now; refreshInfo()
	end
end)
task.spawn(function()
	while true do task.wait(0.5); pcall(function()
		local ping = 0
		local ns = Stats:FindFirstChild("Network")
		if ns then local sci = ns:FindFirstChild("ServerStatsItem"); if sci then local dp = sci:FindFirstChild("Data Ping"); if dp then ping = math.floor(dp:GetValue() or 0) end end end
		lastPing = ping; refreshInfo()
	end) end
end)

local function executeSteal(prompt, a)
	local data = _stealCache[prompt]; if not data or not data.ready then return false end
	data.ready = false; _stealActive = true; _stealStart = tick()
	_stealState = "UNREADY"; readyLbl.Text = "UNREADY"; setReadyColor("UNREADY")
	task.spawn(function()
		for _,fn in ipairs(data.hold) do task.spawn(fn) end
		task.spawn(function()
			while _stealActive do
				local prog = math.clamp((tick()-_stealStart)/CFG.HOLD_MAX, 0, 1)
				stealFill.Size = UDim2.new(prog,0,1,0)
				pctLbl.Text = math.floor(prog*100).."%"
				if prog >= 0.6 and _stealState ~= "READY" then
					_stealState = "READY"
					readyLbl.Text = "READY"
					setReadyColor("READY")
				end
				task.wait()
			end
		end)
		task.wait(CFG.HOLD_MIN)
		local alreadyClose = distTo(a) <= CFG.STEAL_RANGE
		while true do
			if tick()-_stealStart > CFG.HOLD_MAX then break end
			if not prompt.Parent then break end
			if distTo(a) <= CFG.STEAL_RANGE then
				if not alreadyClose then task.wait(CFG.ENTRY_DELAY) end
				for _,fn in ipairs(data.trigger) do task.spawn(fn) end
				break
			end
			task.wait()
		end
		_stealActive = false
		stealFill.Size = UDim2.new(0,0,1,0); pctLbl.Text = ""
		_stealState = "READY"; readyLbl.Text = "READY"; setReadyColor("READY")
		task.wait(CFG.COOLDOWN); data.ready = true
	end)
	return true
end
local function attemptSteal(prompt, a)
	if not prompt or not prompt.Parent then return false end
	buildCallbacks(prompt)
	if not _stealCache[prompt] then return false end
	return executeSteal(prompt, a)
end

task.spawn(function() pcall(scanAllPlots) end)
task.spawn(function() while autoStealOn do task.wait(5); pcall(scanAllPlots) end end)

RunService.Heartbeat:Connect(function()
	if not autoStealOn then return end
	if _stealActive then return end
	local target = pickClosest()
	local newState = (target ~= nil) and "UNREADY" or "READY"
	if newState ~= _stealState then
		_stealState = newState
		readyLbl.Text = newState
		setReadyColor(newState)
	end
	if not target then return end
	local prompt = _promptCache[target.uid]
	if not prompt or not prompt.Parent then prompt = findPrompt(target) end
	if prompt then attemptSteal(prompt, target) end
end)

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
addLivingTextGradient(minBtn)

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
	addLivingTextGradient(lbl)

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
	addLivingTextGradient(minusBtn)

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
	addLivingTextGradient(box)

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
	addLivingTextGradient(plusBtn)

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
addLivingTextGradient(modeBtn)
modeBtn.MouseButton1Click:Connect(function()
	speedType = (speedType == "carry") and "normal" or "carry"
	_carryManualUntil = tick() + 0.35
	local isSteal = speedType == "carry"
	modeBtn.Text = isSteal and "MODE: STEAL" or "MODE: NORMAL"
	modeBtn.TextColor3 = isSteal and C_WHITE or C_DIM
	TweenService:Create(modeBtn, TweenInfo.new(0.15), {BackgroundColor3 = isSteal and C_ON or C_OFF}):Play()
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
addLivingTextGradient(speedBtn)
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

local stealBtn = Instance.new("TextButton", panel)
stealBtn.Size = UDim2.new(1,-20,0,24)
stealBtn.Position = UDim2.new(0,10,0,152)
stealBtn.BackgroundColor3 = C_ON
stealBtn.Text = "AUTO STEAL: ENABLED"
stealBtn.TextColor3 = C_WHITE
stealBtn.Font = Enum.Font.GothamBlack
stealBtn.TextSize = 11
stealBtn.BorderSizePixel = 0
stealBtn.AutoButtonColor = false
stealBtn.ZIndex = 11
addCorner(stealBtn, 8)
addLivingTextGradient(stealBtn)
stealBtn.MouseButton1Click:Connect(function()
	autoStealOn = not autoStealOn
	stealBtn.Text = autoStealOn and "AUTO STEAL: ENABLED" or "AUTO STEAL: DISABLED"
	stealBtn.TextColor3 = autoStealOn and C_WHITE or C_DIM
	TweenService:Create(stealBtn, TweenInfo.new(0.15), {BackgroundColor3 = autoStealOn and C_ON or C_OFF}):Play()
	if not autoStealOn then
		_stealState = "READY"; readyLbl.Text = "READY"; setReadyColor("READY")
		stealFill.Size = UDim2.new(0,0,1,0); pctLbl.Text = ""
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
addLivingTextGradient(sbBtn)

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
addLivingTextGradient(bindHint)

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

local hideableElements = {normalRow, stealRow, modeBtn, speedBtn, stealBtn, sbTitle, sbBtn, powerRow, bindHint}
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	minBtn.Text = minimized and "+" or "-"
	panel.Size = minimized and UDim2.new(0,220,0,34) or UDim2.new(0,220,0,panelFullH)
	for _, el in ipairs(hideableElements) do el.Visible = not minimized end
end)

print("[SpeedTest] Prêt — clic gauche = toggle, clic droit sur BYPASS = rebind touche, bouton - = réduire.")
