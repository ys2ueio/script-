-- ===================================================================
-- ANTI-DETECT STANDALONE
-- Anti-kick + GC scanner (X-15/X-16) + screen-text countdown guard
-- ===================================================================
local _NS = "AntiDetect_SA_v1"
if _G[_NS] then return end; _G[_NS] = true

local LP  = game:GetService("Players").LocalPlayer
local RS  = game:GetService("RunService")
local TCS = game:GetService("TextChatService")

-- ===================================================================
-- ANTI-KICK
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

local function startAntiKick()
	if _akActive then return end
	-- 1. Block :Kick() via __namecall
	pcall(function()
		local mt = getrawmetatable(LP); if not mt then return end
		setreadonly(mt, false)
		_akOldNamecall = mt.__namecall
		local _raw = _akOldNamecall
		local _hookBody = function(self, ...)
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
	-- 2. Per-character protections + respawn re-hook
	local char0 = LP.Character
	_akHookChar(char0)
	_akCharAddedConn = LP.CharacterAdded:Connect(function(newChar)
		if not _akActive then return end
		local now = tick()
		if now - _akLastRespawn < 3 then _akRespawnCount = _akRespawnCount + 1
		else _akRespawnCount = 0 end
		_akLastRespawn = now
		task.defer(function()
			if not _akActive then return end
			_akHookChar(newChar)
		end)
	end)
	-- 3. Position safety + velocity clamp + health restore
	if _akPosConn then pcall(function() _akPosConn:Disconnect() end) end
	_akPosConn = RS.Heartbeat:Connect(function()
		local c2 = LP.Character; if not c2 then return end
		local r2 = c2:FindFirstChild("HumanoidRootPart"); if not r2 then return end
		local h2 = c2:FindFirstChildOfClass("Humanoid"); if not h2 then return end
		if _akLastSafe then
			local dist = (r2.Position - _akLastSafe.Position).Magnitude
			if dist > 150 and h2.MoveDirection.Magnitude < 0.1 then
				r2.CFrame = _akLastSafe; return
			end
		end
		local ref = _akLastSafe and _akLastSafe.Position or r2.Position
		if (r2.Position - ref).Magnitude < 30 then _akLastSafe = r2.CFrame end
		local vel = r2.AssemblyLinearVelocity
		if vel.Y < -150 then
			r2.AssemblyLinearVelocity = Vector3.new(vel.X, -50, vel.Z)
			h2.Health = h2.MaxHealth
		elseif vel.Magnitude > 300 and h2.MoveDirection.Magnitude < 0.1 then
			r2.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
		end
		if vel.Y < -50 then h2.Health = h2.MaxHealth end
		if h2.Health < h2.MaxHealth then h2.Health = h2.MaxHealth end
	end)
	-- 4. Block kick/ban-named RemoteEvents in ReplicatedStorage
	pcall(function()
		local RSvc = game:GetService("ReplicatedStorage")
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
		for _, d in ipairs(RSvc:GetDescendants()) do hookRemote(d) end
		local c = RSvc.DescendantAdded:Connect(function(d) pcall(hookRemote, d) end)
		_akRemoteConns[#_akRemoteConns+1] = c
	end)
	-- 5. Workspace monitor + MaxHealth lock
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
					local nh = Instance.new("Humanoid"); nh.Parent = c3
				end
			end)
			task.wait(0.1)
		end
	end)
	_akActive = true
end

-- ===================================================================
-- GC SCANNER — block X-15 / X-16 kick signals + coroutine.wrap block
-- ===================================================================
local _gcScanned = {}

local function _gcHookRemote(remote)
	pcall(function()
		local oldFire
		oldFire = hookfunction(remote.FireServer, newcclosure(function(self, ...)
			local a1 = select(1, ...) and tostring(select(1, ...)):lower() or ""
			if a1 == "x-15" or a1 == "x-16" then return task.wait(9e9) end
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

if getgc and islclosure and isexecutorclosure then
	task.spawn(function()
		pcall(function()
			for _, obj in next, getgc(true) do
				if typeof(obj) == "function" and islclosure(obj) and not isexecutorclosure(obj) then
					_gcDeepScan(obj)
				end
			end
		end)
	end)
end

-- ===================================================================
-- SCREEN-TEXT ANTI-KICK — countdown "5"→"1" suspend external features
-- ===================================================================
local _akScreenLock = false
local _akWatchedLbls = {}

local _STKILL_BAD  = {"backpack","inventory","chatmain","bubblechat","overhead","nametag","leaderboard","hudgui"}
local _STKILL_GOOD = {"global","announce","notif","banner","broadcast","event","popup","sammy","alert","header","news","system","message","center","steal","countdown","timer"}

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

local _stOnLock   = nil  -- set externally: called when countdown "5" fires
local _stOnResume = nil  -- set externally: called when countdown "1" fires

local function _stHandleText(txt)
	if type(txt) ~= "string" then return end
	local clean = txt:gsub("<[^>]+>",""):gsub("%s+","")
	if clean == "5" then
		_akScreenLock = true
		if _stOnLock then pcall(_stOnLock) end
	elseif clean == "1" then
		task.delay(0.6, function()
			_akScreenLock = false
			if _stOnResume then pcall(_stOnResume) end
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
	local pg = LP:WaitForChild("PlayerGui", 10)
	if not pg then return end
	for _, obj in ipairs(pg:GetDescendants()) do
		if obj:IsA("TextLabel") and _stClassify(obj) then _stWatchLabel(obj) end
	end
	pg.DescendantAdded:Connect(function(obj)
		task.wait(0.04)
		if not obj:IsA("TextLabel") then return end
		if _stClassify(obj) then
			_stWatchLabel(obj)
			local t = obj.Text or ""
			if #t >= 1 then _stHandleText(t) end
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
			local t = (msg.Text or ""):gsub("<[^>]+>",""):gsub("%s+","")
			_stHandleText(t)
		end)
	end
end)

-- ===================================================================
-- GUI — draggable status button
-- ===================================================================
local gui = Instance.new("ScreenGui")
gui.Name = _NS; gui.ResetOnSpawn = false; gui.DisplayOrder = 50
pcall(function()
	if syn and syn.protect_gui then syn.protect_gui(gui) end
	if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
	gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 180, 0, 36)
frame.Position = UDim2.new(1, -196, 0, 8)
frame.BackgroundColor3 = Color3.fromRGB(10,10,10)
frame.BorderSizePixel = 0
frame.Active = true

local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0,6)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(50,50,50); stroke.Thickness = 1

local lbl = Instance.new("TextLabel", frame)
lbl.Size = UDim2.new(1,0,1,0)
lbl.BackgroundTransparency = 1
lbl.TextColor3 = Color3.fromRGB(255,255,255)
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = 12
lbl.Text = "ANTI-DETECT: ON"

local function _refreshStatus()
	if _akActive then
		lbl.Text = "ANTI-DETECT: ON"
		lbl.TextColor3 = Color3.fromRGB(80,230,120)
		stroke.Color = Color3.fromRGB(40,140,70)
	else
		lbl.Text = "ANTI-DETECT: OFF"
		lbl.TextColor3 = Color3.fromRGB(200,200,200)
		stroke.Color = Color3.fromRGB(50,50,50)
	end
end

-- draggable
local _dragging, _dragStart, _frameStart = false, nil, nil
frame.InputBegan:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1
	or inp.UserInputType == Enum.UserInputType.Touch then
		_dragging = true
		_dragStart = inp.Position
		_frameStart = frame.Position
	end
end)
frame.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1
	or inp.UserInputType == Enum.UserInputType.Touch then
		_dragging = false
	end
end)
game:GetService("UserInputService").InputChanged:Connect(function(inp)
	if not _dragging then return end
	if inp.UserInputType == Enum.UserInputType.MouseMovement
	or inp.UserInputType == Enum.UserInputType.Touch then
		local delta = inp.Position - _dragStart
		frame.Position = UDim2.new(
			_frameStart.X.Scale, _frameStart.X.Offset + delta.X,
			_frameStart.Y.Scale, _frameStart.Y.Offset + delta.Y
		)
	end
end)

-- ===================================================================
-- INIT
-- ===================================================================
task.spawn(function() pcall(startAntiKick) end)
_refreshStatus()
