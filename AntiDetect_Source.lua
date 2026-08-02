-- ===================================================================
-- ANTI-DETECT SOURCE — yslem (strictly private & personal use)
-- Layers: kick block · char protection · pos/vel safety · remote block
--         workspace monitor · GC scanner (X-15/X-16) · screen-text guard
--         HTTP block · game:Shutdown block · periodic GC rescan
-- ===================================================================
local _NS = "ADSC_v1"
if _G[_NS] then return end; _G[_NS] = true

local cloneref = cloneref or function(o) return o end
local LP  = cloneref(game:GetService("Players")).LocalPlayer
local RS  = cloneref(game:GetService("RunService"))
local TCS = game:GetService("TextChatService")

-- ===================================================================
-- LAYER 1 — ANTI-KICK
-- ===================================================================
local _akActive        = false
local _akOldNamecall   = nil
local _akMt            = nil
local _akPosConn       = nil
local _akDeathConn     = nil
local _akHealthConn    = nil
local _akMaxHpConn     = nil
local _akLastSafe      = nil
local _akRemoteConns   = {}
local _akCharOldNI     = nil
local _akCharMtRef     = nil
local _akLoopActive    = false
local _akCharAddedConn = nil
local _akRespawnCount  = 0
local _akLastRespawn   = 0

local function _akHookHumanoid(char)
	if _akDeathConn  then pcall(function() _akDeathConn:Disconnect()  end); _akDeathConn  = nil end
	if _akHealthConn then pcall(function() _akHealthConn:Disconnect() end); _akHealthConn = nil end
	if _akMaxHpConn  then pcall(function() _akMaxHpConn:Disconnect()  end); _akMaxHpConn  = nil end
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
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

local function _akHookChar(char)
	_akHookHumanoid(char)
	if _akCharMtRef and _akCharOldNI ~= nil then
		pcall(function()
			setreadonly(_akCharMtRef, false)
			_akCharMtRef.__newindex = _akCharOldNI
			setreadonly(_akCharMtRef, true)
		end)
		_akCharOldNI = nil; _akCharMtRef = nil
	end
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
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then _akLastSafe = hrp.CFrame end
end

local function _startAntiKick()
	if _akActive then return end
	-- 1a. Block :Kick() via __namecall on LocalPlayer metatable
	pcall(function()
		local mt = getrawmetatable(LP); if not mt then return end
		setreadonly(mt, false)
		_akOldNamecall = mt.__namecall
		local _raw = _akOldNamecall
		mt.__namecall = newcclosure(function(self, ...)
			local fromGame = not (checkcaller and checkcaller())
			if fromGame then
				local m = tostring(getnamecallmethod and getnamecallmethod() or ""):lower()
				if self == LP and m == "kick" then return nil end
			end
			return _raw(self, ...)
		end)
		setreadonly(mt, true)
		_akMt = mt
	end)
	-- 1b. Block game:Shutdown() + game:BindToClose() via __namecall on game
	pcall(function()
		local gmt = getrawmetatable(game); if not gmt then return end
		setreadonly(gmt, false)
		local _gRaw = gmt.__namecall
		gmt.__namecall = newcclosure(function(self, ...)
			local fromGame = not (checkcaller and checkcaller())
			if fromGame then
				local m = tostring(getnamecallmethod and getnamecallmethod() or ""):lower()
				if m == "shutdown" or m == "bindtoclose" then return end
			end
			return _gRaw(self, ...)
		end)
		setreadonly(gmt, true)
	end)
	-- 2. Per-character protections (humanoid events + __newindex block)
	_akHookChar(LP.Character)
	_akCharAddedConn = LP.CharacterAdded:Connect(function(newChar)
		if not _akActive then return end
		local now = tick()
		if now - _akLastRespawn < 3 then _akRespawnCount += 1
		else _akRespawnCount = 0 end
		_akLastRespawn = now
		task.defer(function()
			if _akActive then _akHookChar(newChar) end
		end)
	end)
	-- 3. Position safety + velocity clamp + health immortality (Heartbeat)
	_akPosConn = RS.Heartbeat:Connect(function()
		local c = LP.Character;                          if not c then return end
		local r = c:FindFirstChild("HumanoidRootPart"); if not r then return end
		local h = c:FindFirstChildOfClass("Humanoid");  if not h then return end
		if _akLastSafe then
			local dist = (r.Position - _akLastSafe.Position).Magnitude
			if dist > 150 and h.MoveDirection.Magnitude < 0.1 then
				r.CFrame = _akLastSafe; return
			end
		end
		if (r.Position - (_akLastSafe and _akLastSafe.Position or r.Position)).Magnitude < 30 then
			_akLastSafe = r.CFrame
		end
		local vel = r.AssemblyLinearVelocity
		if vel.Y < -150 then
			r.AssemblyLinearVelocity = Vector3.new(vel.X, -50, vel.Z)
			h.Health = h.MaxHealth
		elseif vel.Magnitude > 300 and h.MoveDirection.Magnitude < 0.1 then
			r.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
		end
		if vel.Y < -50 then h.Health = h.MaxHealth end
		if h.Health  < h.MaxHealth then h.Health = h.MaxHealth end
	end)
	-- 4. Block kick/ban-named RemoteEvents in ReplicatedStorage
	pcall(function()
		local RSvc = game:GetService("ReplicatedStorage")
		local _KW  = {string.char(107,105,99,107), string.char(98,97,110),
		              string.char(114,101,109,111,118,101), string.char(100,105,115,99,111,110,110,101,99,116)}
		local function hookRemote(obj)
			if not (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then return end
			local n = obj.Name:lower()
			for _, kw in ipairs(_KW) do
				if n:find(kw, 1, true) then
					if obj:IsA("RemoteEvent") then
						_akRemoteConns[#_akRemoteConns+1] = obj.OnClientEvent:Connect(function() return nil end)
					end
					break
				end
			end
		end
		for _, d in ipairs(RSvc:GetDescendants()) do pcall(hookRemote, d) end
		_akRemoteConns[#_akRemoteConns+1] = RSvc.DescendantAdded:Connect(function(d) pcall(hookRemote, d) end)
	end)
	-- 5. Workspace monitor — restore MaxHealth + keep character in workspace
	_akLoopActive = true
	task.spawn(function()
		while _akLoopActive do
			pcall(function()
				local c = LP.Character; if not c then return end
				if c.Parent ~= workspace then c.Parent = workspace end
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then
					if h.MaxHealth ~= 100 then h.MaxHealth = 100 end
					if h.Health <= 0      then h.Health = h.MaxHealth end
				else
					Instance.new("Humanoid").Parent = c
				end
			end)
			task.wait(0.1)
		end
	end)
	-- 6. Character removal monitor (fast loop, 0.05s)
	task.spawn(function()
		while _akLoopActive do
			task.wait(0.05)
			pcall(function()
				local c = LP.Character; if not c then return end
				if c.Parent ~= workspace then c.Parent = workspace end
			end)
		end
	end)
	_akActive = true
end

-- ===================================================================
-- LAYER 2 — GC SCANNER (X-15 / X-16 + coroutine.wrap block)
-- ===================================================================
local _gcScanned = {}

local function _gcHookRemote(remote)
	pcall(function()
		local _X15 = string.char(120,45,49,53)
		local _X16 = string.char(120,45,49,54)
		local oldFire
		oldFire = hookfunction(remote.FireServer, newcclosure(function(self, ...)
			local a1 = select(1,...) and tostring(select(1,...)):lower() or ""
			if a1 == _X15 or a1 == _X16 then return task.wait(9e9) end
			return oldFire(self, ...)
		end))
	end)
end

local function _gcDeepScan(value)
	if _gcScanned[value] then return end
	_gcScanned[value] = true
	if typeof(value) == "Instance" and value:IsA("RemoteEvent") then
		if not value:IsDescendantOf(game:GetService("ReplicatedStorage")) then
			_gcHookRemote(value)
			pcall(function()
				local _cwOld
				_cwOld = hookfunction(getrenv().coroutine.wrap, newcclosure(function(...)
					if not checkcaller() then return task.wait(9e9) end
					return _cwOld(...)
				end))
			end)
		end
		return
	end
	if typeof(value) == "function" then
		local ok, up = pcall(getupvalues, value)
		if ok and up then for _, v in pairs(up) do _gcDeepScan(v) end end
	end
	if typeof(value) == "table" then
		for _, v in pairs(value) do _gcDeepScan(v) end
	end
end

local function _runGCScan()
	pcall(function()
		if not (getgc and islclosure and isexecutorclosure) then return end
		for _, obj in next, getgc(true) do
			if typeof(obj) == "function" and islclosure(obj) and not isexecutorclosure(obj) then
				_gcDeepScan(obj)
			end
		end
	end)
end

-- Initial scan
task.spawn(_runGCScan)

-- Periodic rescan every 30s (catch dynamically injected kick remotes)
task.spawn(function()
	while true do
		task.wait(30)
		task.spawn(_runGCScan)
	end
end)

-- ===================================================================
-- LAYER 3 — HTTP REPORTING BLOCK
-- ===================================================================
pcall(function()
	local _BAD = {"log","report","detect","analytics","telemetry",
	              string.char(97,110,116,105,99,104,101,97,116),  -- "anticheat"
	              string.char(98,97,110)}                          -- "ban"
	local function _wrapReq(fn)
		if not fn then return fn end
		return newcclosure(function(opts, ...)
			if type(opts) == "table" then
				local url = (opts.Url or opts.url or ""):lower()
				for _, kw in ipairs(_BAD) do
					if url:find(kw, 1, true) then
						return {StatusCode=200, Body="", Success=true}
					end
				end
			end
			return fn(opts, ...)
		end)
	end
	if syn and syn.request then syn.request  = _wrapReq(syn.request)  end
	if request             then request      = _wrapReq(request)       end
	if http_request        then http_request = _wrapReq(http_request)  end
end)

-- ===================================================================
-- LAYER 4 — SCREEN-TEXT ANTI-KICK (countdown "5" → "1")
-- ===================================================================
local _akScreenLock  = false
local _akWatchedLbls = {}

local _STKILL_BAD  = {"backpack","inventory","chatmain","bubblechat","overhead","nametag","leaderboard","hudgui"}
local _STKILL_GOOD = {"global","announce","notif","banner","broadcast","event","popup","sammy","alert",
                      "header","news","system","message","center","steal","countdown","timer"}

local function _stClassify(obj)
	if not obj or not obj.Parent then return false end
	local n   = (obj.Name or ""):lower()
	local pn  = ((obj.Parent and obj.Parent.Name) or ""):lower()
	local gpn = ((obj.Parent and obj.Parent.Parent and obj.Parent.Parent.Name) or ""):lower()
	for _, b in ipairs(_STKILL_BAD) do
		if n:find(b,1,true) or pn:find(b,1,true) then return false end
	end
	for _, g in ipairs(_STKILL_GOOD) do
		if n:find(g,1,true) or pn:find(g,1,true) or gpn:find(g,1,true) then return true end
	end
	return false
end

-- Callbacks assignables depuis l'extérieur
local stOnLock   = nil  -- ex: function() stopAutoSteal() end
local stOnResume = nil  -- ex: function() startAutoSteal() end

local function _stHandleText(txt)
	if type(txt) ~= "string" then return end
	local clean = txt:gsub("<[^>]+>",""):gsub("%s+","")
	if clean == "5" then
		_akScreenLock = true
		if stOnLock then pcall(stOnLock) end
	elseif clean == "1" then
		task.delay(0.6, function()
			_akScreenLock = false
			if stOnResume then pcall(stOnResume) end
		end)
	end
end

local function _stWatchLabel(obj)
	if _akWatchedLbls[obj] then return end
	_akWatchedLbls[obj] = true
	pcall(function() _stHandleText(obj.Text or "") end)
	obj:GetPropertyChangedSignal("Text"):Connect(function()
		if _stClassify(obj) then _stHandleText(obj.Text or "") end
	end)
end

task.spawn(function()
	local pg = LP:WaitForChild("PlayerGui", 10); if not pg then return end
	for _, obj in ipairs(pg:GetDescendants()) do
		if obj:IsA("TextLabel") and _stClassify(obj) then _stWatchLabel(obj) end
	end
	pg.DescendantAdded:Connect(function(obj)
		task.wait(0.04)
		if not obj:IsA("TextLabel") then return end
		if _stClassify(obj) then
			_stWatchLabel(obj)
			local t = obj.Text or ""; if #t >= 1 then _stHandleText(t) end
		end
		obj:GetPropertyChangedSignal("Text"):Connect(function()
			if _stClassify(obj) then _stHandleText(obj.Text or "") end
		end)
	end)
end)

pcall(function()
	if TCS and TCS.MessageReceived then
		TCS.MessageReceived:Connect(function(msg)
			if not msg then return end
			_stHandleText((msg.Text or ""):gsub("<[^>]+>",""):gsub("%s+",""))
		end)
	end
end)

-- ===================================================================
-- GUI — status badge draggable
-- ===================================================================
local gui = Instance.new("ScreenGui")
gui.Name = tostring(math.random(0x100000, 0xFFFFFF))
gui.ResetOnSpawn = false; gui.DisplayOrder = 50
pcall(function()
	if syn and syn.protect_gui then syn.protect_gui(gui) end
	if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
	gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 188, 0, 34)
frame.Position = UDim2.new(1, -204, 0, 8)
frame.BackgroundColor3 = Color3.fromRGB(8,8,8)
frame.BorderSizePixel = 0; frame.Active = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
local _stroke = Instance.new("UIStroke", frame)
_stroke.Thickness = 1

local lbl = Instance.new("TextLabel", frame)
lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
lbl.TextColor3 = Color3.fromRGB(255,255,255)
lbl.Text = "ANTI-DETECT: ON"

local function _refresh()
	lbl.TextColor3 = Color3.fromRGB(70,220,110)
	_stroke.Color  = Color3.fromRGB(30,120,60)
end

local _drag, _ds, _fs = false, nil, nil
frame.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		_drag=true; _ds=i.Position; _fs=frame.Position
	end
end)
frame.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then _drag=false end
end)
game:GetService("UserInputService").InputChanged:Connect(function(i)
	if not _drag then return end
	if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
		local d=i.Position-_ds
		frame.Position=UDim2.new(_fs.X.Scale,_fs.X.Offset+d.X,_fs.Y.Scale,_fs.Y.Offset+d.Y)
	end
end)

-- ===================================================================
-- INIT
-- ===================================================================
task.spawn(function() pcall(_startAntiKick) end)
_refresh()
