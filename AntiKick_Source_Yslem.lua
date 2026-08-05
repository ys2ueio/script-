-- ================================================================
-- ANTI KICK SOURCE — by Yslem  (strictly private & personal use)
-- ================================================================
-- Vecteurs couverts :
--  · Player:Kick() namecall                   · game:Shutdown() namecall
--  · game:BindToClose()                       · TeleportService forced-tp
--  · Character Parent=nil                     · Humanoid death/dying/falling
--  · Health drop / MaxHealth tamper           · Position spike (>150 studs)
--  · Velocity spike (>300 magnitude)          · RemoteEvent kick payloads
--  · X-15 / X-16 signals                     · Obfuscated remote names
--  · Tout remote fire avec payload kick/ban   · Instance.new remote intercept
--  · UnreliableRemoteEvent fire               · coroutine.wrap non-executor
--  · HTTP reporting endpoints                 · GC deep scan + rescan 30s
--  · Screen-text countdown 5→1               · Workspace character ejection
-- ================================================================
local _NS = "AKS_Yslem_v2"
if _G[_NS] then return end; _G[_NS] = true

local cloneref     = cloneref or function(o) return o end
local LP           = cloneref(game:GetService("Players")).LocalPlayer
local RS           = cloneref(game:GetService("RunService"))
local TS           = cloneref(game:GetService("TeleportService"))
local TCS          = game:GetService("TextChatService")
local CoreGui      = game:GetService("CoreGui")

-- encoded kick-related keywords (avoid literal string detection)
local _KW_KICK     = string.char(107,105,99,107)           -- "kick"
local _KW_BAN      = string.char(98,97,110)                -- "ban"
local _KW_REMOVE   = string.char(114,101,109,111,118,101)  -- "remove"
local _KW_DISC     = string.char(100,105,115,99,111,110,110,101,99,116) -- "disconnect"
local _KW_REPORT   = string.char(114,101,112,111,114,116)  -- "report"
local _KW_X15      = string.char(120,45,49,53)             -- "x-15"
local _KW_X16      = string.char(120,45,49,54)             -- "x-16"
local _KW_PUNISH   = string.char(112,117,110,105,115,104)  -- "punish"
local _KW_MUTE     = string.char(109,117,116,101)          -- "mute"
local _KW_ANTICHEAT = "anticheat"

local _KICK_ARGS   = {_KW_KICK, _KW_BAN, _KW_DISC, _KW_REMOVE, _KW_PUNISH,
                      _KW_X15, _KW_X16, "x15", "x16", "xkick", "force_kick",
                      "forcekick", "kickplayer", "player_kick", "kick_player"}
local _KICK_NAMES  = {_KW_KICK, _KW_BAN, _KW_REMOVE, _KW_DISC, _KW_REPORT,
                      _KW_PUNISH, _KW_MUTE, _KW_ANTICHEAT, "warn", "flag",
                      "cheat", "exploit", "hack", "detect", "sanction"}

-- ================================================================
-- UTILITIES
-- ================================================================
local function _fromGame()
	return not (checkcaller and checkcaller())
end
local function _nameMethod()
	return tostring(getnamecallmethod and getnamecallmethod() or ""):lower()
end
local function _isKickArg(v)
	if type(v) ~= "string" then return false end
	local l = v:lower()
	for _, kw in ipairs(_KICK_ARGS) do
		if l == kw or l:find(kw, 1, true) then return true end
	end
	return false
end
local function _isKickName(n)
	local l = tostring(n):lower()
	for _, kw in ipairs(_KICK_NAMES) do
		if l:find(kw, 1, true) then return true end
	end
	return false
end

-- ================================================================
-- LAYER 1 — NAMECALL HOOKS (Player:Kick, game:Shutdown, Teleport)
-- ================================================================
-- 1a. LocalPlayer metatable → block :Kick()
pcall(function()
	local mt = getrawmetatable(LP); if not mt then return end
	setreadonly(mt, false)
	local _raw = mt.__namecall
	mt.__namecall = newcclosure(function(self, ...)
		if _fromGame() then
			local m = _nameMethod()
			if self == LP and m == _KW_KICK then return end
		end
		return _raw(self, ...)
	end)
	setreadonly(mt, true)
end)

-- 1b. game metatable → block :Shutdown() / :BindToClose() / :Load()
pcall(function()
	local mt = getrawmetatable(game); if not mt then return end
	setreadonly(mt, false)
	local _raw = mt.__namecall
	mt.__namecall = newcclosure(function(self, ...)
		if _fromGame() then
			local m = _nameMethod()
			if m == "shutdown" or m == "bindtoclose" or m == "load" then return end
		end
		return _raw(self, ...)
	end)
	setreadonly(mt, true)
end)

-- 1c. TeleportService metatable → block forced teleports from game scripts
pcall(function()
	local mt = getrawmetatable(TS); if not mt then return end
	setreadonly(mt, false)
	local _raw = mt.__namecall
	mt.__namecall = newcclosure(function(self, ...)
		if _fromGame() then
			local m = _nameMethod()
			if m == "teleport" or m == "teleporttoplacewithpartyasync"
			or m == "teleporttoserverinstance" or m == "teleporttoplaceinstance"
			or m == "teleportpartyasync" then return end
		end
		return _raw(self, ...)
	end)
	setreadonly(mt, true)
end)

-- ================================================================
-- LAYER 2 — CHARACTER PROTECTION
-- ================================================================
local _akDeathConn   = nil
local _akHealthConn  = nil
local _akMaxHpConn   = nil
local _akCharMtRef   = nil
local _akCharOldNI   = nil
local _akLastSafe    = nil
local _akPosConn     = nil
local _akRemConns    = {}
local _akCharConn    = nil
local _akLoopActive  = true

local function _hookHumanoid(char)
	if _akDeathConn  then pcall(function() _akDeathConn:Disconnect()  end) end
	if _akHealthConn then pcall(function() _akHealthConn:Disconnect() end) end
	if _akMaxHpConn  then pcall(function() _akMaxHpConn:Disconnect()  end) end
	_akDeathConn = nil; _akHealthConn = nil; _akMaxHpConn = nil
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

local function _hookChar(char)
	_hookHumanoid(char)
	if _akCharMtRef and _akCharOldNI ~= nil then
		pcall(function()
			setreadonly(_akCharMtRef, false)
			_akCharMtRef.__newindex = _akCharOldNI
			setreadonly(_akCharMtRef, true)
		end)
		_akCharMtRef = nil; _akCharOldNI = nil
	end
	pcall(function()
		if not char then return end
		local cm = getrawmetatable(char); if not cm then return end
		setreadonly(cm, false)
		_akCharOldNI = cm.__newindex
		local _old = _akCharOldNI
		cm.__newindex = newcclosure(function(self, key, value)
			if key == "Parent" and value == nil then return end
			if _old then return _old(self, key, value) end
			rawset(self, key, value)
		end)
		setreadonly(cm, true)
		_akCharMtRef = cm
	end)
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then _akLastSafe = hrp.CFrame end
end

-- Position safety + velocity clamp + immortality
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
		r.AssemblyLinearVelocity = Vector3.new(vel.X, -50, vel.Z); h.Health = h.MaxHealth
	elseif vel.Magnitude > 300 and h.MoveDirection.Magnitude < 0.1 then
		r.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
	end
	if vel.Y < -50 then h.Health = h.MaxHealth end
	if h.Health   < h.MaxHealth then h.Health = h.MaxHealth end
end)

_hookChar(LP.Character)
_akCharConn = LP.CharacterAdded:Connect(function(c)
	task.defer(function() _hookChar(c) end)
end)

-- Workspace monitor (2 loops at different rates)
task.spawn(function()
	while _akLoopActive do
		task.wait(0.1)
		pcall(function()
			local c = LP.Character; if not c then return end
			if c.Parent ~= workspace then c.Parent = workspace end
			local h = c:FindFirstChildOfClass("Humanoid")
			if h then
				if h.MaxHealth ~= 100 then h.MaxHealth = 100 end
				if h.Health <= 0      then h.Health = h.MaxHealth end
			else Instance.new("Humanoid").Parent = c end
		end)
	end
end)
task.spawn(function()
	while _akLoopActive do
		task.wait(0.05)
		pcall(function()
			local c = LP.Character; if not c then return end
			if c.Parent ~= workspace then c.Parent = workspace end
		end)
	end
end)

-- ================================================================
-- LAYER 3 — REMOTE BLOCK (name-based + payload-based)
-- ================================================================
-- Hook a single RemoteEvent: block kicks by name AND by first argument
local _hooked = {}
local function _hookRemote(obj)
	if not obj or _hooked[obj] then return end
	if not (obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent")) then return end
	_hooked[obj] = true
	-- a. Block OnClientEvent if name is suspicious
	if _isKickName(obj.Name) then
		pcall(function()
			obj.OnClientEvent:Connect(function() return end)
		end)
	end
	-- b. Hook FireServer to block kick-payload arguments
	pcall(function()
		if not hookfunction then return end
		local oldFire
		oldFire = hookfunction(obj.FireServer, newcclosure(function(self, ...)
			local a1 = select(1, ...)
			if _isKickArg(a1) then return end
			-- block if name is a kick name
			if _isKickName(obj.Name) then return end
			return oldFire(self, ...)
		end))
	end)
end

-- Scan ReplicatedStorage for kick-named remotes
pcall(function()
	local RSvc = game:GetService("ReplicatedStorage")
	for _, d in ipairs(RSvc:GetDescendants()) do pcall(_hookRemote, d) end
	_akRemConns[#_akRemConns+1] = RSvc.DescendantAdded:Connect(function(d)
		task.defer(function() pcall(_hookRemote, d) end)
	end)
end)

-- Intercept Instance.new("RemoteEvent") and Instance.new("UnreliableRemoteEvent")
pcall(function()
	if not hookfunction then return end
	local oldNew
	oldNew = hookfunction(Instance.new, newcclosure(function(cls, parent)
		local inst = oldNew(cls, parent)
		if cls == "RemoteEvent" or cls == "UnreliableRemoteEvent" then
			task.defer(function() pcall(_hookRemote, inst) end)
		end
		return inst
	end))
end)

-- Also block suspicious RemoteFunction InvokeServer calls
pcall(function()
	if not hookfunction then return end
	local RSvc = game:GetService("ReplicatedStorage")
	local function hookRF(obj)
		if not obj or not obj:IsA("RemoteFunction") then return end
		if not _isKickName(obj.Name) then return end
		local oldInvoke
		oldInvoke = hookfunction(obj.InvokeServer, newcclosure(function(self, ...)
			if _isKickArg(select(1,...)) then return nil end
			return oldInvoke(self, ...)
		end))
	end
	for _, d in ipairs(RSvc:GetDescendants()) do pcall(hookRF, d) end
	RSvc.DescendantAdded:Connect(function(d) task.defer(function() pcall(hookRF, d) end) end)
end)

-- ================================================================
-- LAYER 4 — GC SCANNER (X-15/X-16 + out-of-RS remotes + coroutine.wrap)
-- ================================================================
local _gcScanned = {}

local function _gcHookRemote(remote)
	if _hooked[remote] then return end
	_hooked[remote] = true
	pcall(function()
		if not hookfunction then return end
		local oldFire
		oldFire = hookfunction(remote.FireServer, newcclosure(function(self, ...)
			if _isKickArg(select(1,...)) then return end
			return oldFire(self, ...)
		end))
	end)
	-- also block coroutine.wrap used by non-executor
	pcall(function()
		local _cwOld
		_cwOld = hookfunction(getrenv().coroutine.wrap, newcclosure(function(...)
			if not checkcaller() then return task.wait(9e9) end
			return _cwOld(...)
		end))
	end)
end

local function _gcDeepScan(value)
	if _gcScanned[value] then return end
	_gcScanned[value] = true
	if typeof(value) == "Instance" then
		if (value:IsA("RemoteEvent") or value:IsA("UnreliableRemoteEvent")) then
			if not value:IsDescendantOf(game:GetService("ReplicatedStorage")) then
				_gcHookRemote(value)
			else
				pcall(_hookRemote, value)
			end
			return
		end
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

task.spawn(_runGCScan)
task.spawn(function()
	while true do task.wait(30); task.spawn(_runGCScan) end
end)

-- ================================================================
-- LAYER 5 — HTTP REPORTING BLOCK
-- ================================================================
pcall(function()
	local _BAD_URL = {"log","report","detect","analytics","telemetry",
	                  _KW_ANTICHEAT, "anti_cheat", _KW_BAN, _KW_KICK,
	                  "sanction","flag","cheat","exploit"}
	local function _wrapReq(fn)
		if not fn then return fn end
		return newcclosure(function(opts, ...)
			if type(opts) == "table" then
				local url = (opts.Url or opts.url or ""):lower()
				for _, kw in ipairs(_BAD_URL) do
					if url:find(kw, 1, true) then
						return {StatusCode=200, Body="", Success=true, Headers={}}
					end
				end
			end
			return fn(opts, ...)
		end)
	end
	if syn  and syn.request then syn.request  = _wrapReq(syn.request)  end
	if request              then request      = _wrapReq(request)       end
	if http_request         then http_request = _wrapReq(http_request)  end
end)

-- ================================================================
-- LAYER 6 — SCREEN-TEXT COUNTDOWN GUARD ("5" → pause / "1" → resume)
-- ================================================================
local _screenLock    = false
local _watchedLabels = {}

local _ST_BAD  = {"backpack","inventory","chatmain","bubblechat","overhead",
                  "nametag","leaderboard","hudgui"}
local _ST_GOOD = {"global","announce","notif","banner","broadcast","event",
                  "popup","sammy","alert","header","news","system","message",
                  "center","steal","countdown","timer","score","warn"}

local function _stClassify(obj)
	if not obj or not obj.Parent then return false end
	local n   = (obj.Name or ""):lower()
	local pn  = (obj.Parent and obj.Parent.Name or ""):lower()
	local gpn = (obj.Parent and obj.Parent.Parent and obj.Parent.Parent.Name or ""):lower()
	for _, b in ipairs(_ST_BAD)  do if n:find(b,1,true) or pn:find(b,1,true) then return false end end
	for _, g in ipairs(_ST_GOOD) do if n:find(g,1,true) or pn:find(g,1,true) or gpn:find(g,1,true) then return true end end
	return false
end

-- Assign these from outside to hook your own features into the guard
local stOnLock   = nil
local stOnResume = nil

local function _stHandle(txt)
	if type(txt) ~= "string" then return end
	local c = txt:gsub("<[^>]+>",""):gsub("%s+","")
	if c == "5" then
		_screenLock = true
		if stOnLock then pcall(stOnLock) end
	elseif c == "1" then
		task.delay(0.6, function()
			_screenLock = false
			if stOnResume then pcall(stOnResume) end
		end)
	end
end

local function _stWatch(obj)
	if _watchedLabels[obj] then return end
	_watchedLabels[obj] = true
	pcall(function() _stHandle(obj.Text or "") end)
	obj:GetPropertyChangedSignal("Text"):Connect(function()
		if _stClassify(obj) then _stHandle(obj.Text or "") end
	end)
end

task.spawn(function()
	local pg = LP:WaitForChild("PlayerGui", 10); if not pg then return end
	for _, o in ipairs(pg:GetDescendants()) do
		if o:IsA("TextLabel") and _stClassify(o) then _stWatch(o) end
	end
	pg.DescendantAdded:Connect(function(o)
		task.wait(0.04)
		if not o:IsA("TextLabel") then return end
		if _stClassify(o) then
			_stWatch(o)
			local t = o.Text or ""; if #t >= 1 then _stHandle(t) end
		end
		o:GetPropertyChangedSignal("Text"):Connect(function()
			if _stClassify(o) then _stHandle(o.Text or "") end
		end)
	end)
end)
pcall(function()
	if TCS and TCS.MessageReceived then
		TCS.MessageReceived:Connect(function(msg)
			if msg then _stHandle((msg.Text or ""):gsub("<[^>]+>",""):gsub("%s+","")) end
		end)
	end
end)

-- ================================================================
-- GUI — badge draggable
-- ================================================================
local gui = Instance.new("ScreenGui")
gui.Name = tostring(math.random(0x100000, 0xFFFFFF))
gui.ResetOnSpawn = false; gui.DisplayOrder = 50
pcall(function()
	if syn and syn.protect_gui then syn.protect_gui(gui) end
	if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = CoreGui end) then
	gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0,200,0,34); frame.Position = UDim2.new(1,-216,0,8)
frame.BackgroundColor3 = Color3.fromRGB(6,6,6); frame.BorderSizePixel = 0; frame.Active = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
local _sk = Instance.new("UIStroke", frame); _sk.Thickness=1; _sk.Color=Color3.fromRGB(30,130,65)

local lbl = Instance.new("TextLabel", frame)
lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
lbl.Font = Enum.Font.GothamBold; lbl.TextSize=11
lbl.TextColor3 = Color3.fromRGB(70,220,110)
lbl.Text = "ANTI KICK — by Yslem"

local _drag,_ds,_fs=false,nil,nil
frame.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		_drag=true;_ds=i.Position;_fs=frame.Position
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

print("[ANTI KICK] by Yslem — loaded")
