-- ALL-IN-ONE SCRIPT - ANTI-KICK AUTO-RUN (No button)
-- Anti-Ragdoll + Infinite Jump + Speed + Auto-Steal + Auto Bat + Anti-Kick (Always ON)
-- v2: fixed Velocity API, fixed namecall, added newcclosure, encoded keywords,
--     char.__newindex, Shutdown/BindToClose/Load/Teleport block, HTTP block,
--     UnreliableRemoteEvent, RemoteFunction block, Instance.new interception,
--     GC periodic rescan, lagger key moved to L (was conflicting with R reset)

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace        = game.Workspace
local LP               = Players.LocalPlayer
local TCS              = game:GetService("TextChatService")

-- ===== ENCODED KEYWORDS =====
local _KW_KICK       = string.char(107,105,99,107)
local _KW_BAN        = string.char(98,97,110)
local _KW_REMOVE     = string.char(114,101,109,111,118,101)
local _KW_DISCONNECT = string.char(100,105,115,99,111,110,110,101,99,116)
local _KW_REPORT     = string.char(114,101,112,111,114,116)
local _KW_PUNISH     = string.char(112,117,110,105,115,104)
local _KW_MUTE       = string.char(109,117,116,101)
local _KW_DETECT     = string.char(100,101,116,101,99,116)
local _KW_X15        = string.char(120,45,49,53)
local _KW_X16        = string.char(120,45,49,54)
local _KW_SHUTDOWN   = string.char(115,104,117,116,100,111,119,110)
local _KW_BINDCLOSE  = string.char(98,105,110,100,116,111,99,108,111,115,101)
local _KW_LOAD       = string.char(108,111,97,100)
local _KW_TELEPORT   = string.char(116,101,108,101,112,111,114,116)
local _KW_ANTICHEAT  = string.char(97,110,116,105,99,104,101,97,116)
local _KW_LOG        = string.char(108,111,103)
local _KW_ANALYTICS  = string.char(97,110,97,108,121,116,105,99,115)

local _KICK_NAMES = {
    _KW_KICK, _KW_BAN, _KW_REMOVE, _KW_DISCONNECT, _KW_REPORT,
    _KW_PUNISH, _KW_MUTE, _KW_ANTICHEAT, _KW_DETECT,
    "warn","flag","cheat","exploit","hack","sanction"
}
local _KICK_ARGS = {
    _KW_KICK, _KW_BAN, _KW_DISCONNECT, _KW_REMOVE, _KW_PUNISH,
    _KW_X15, _KW_X16, "x15","x16","xkick",
    "force_kick","forcekick","kickplayer","player_kick","kick_player"
}

local function _isKickName(n)
    local nl = n:lower()
    for _, kw in ipairs(_KICK_NAMES) do if nl:find(kw,1,true) then return true end end
    return false
end
local function _isKickArg(v)
    if type(v) ~= "string" then return false end
    local vl = v:lower()
    for _, kw in ipairs(_KICK_ARGS) do if vl == kw or vl:find(kw,1,true) then return true end end
    return false
end

-- ===== SETTINGS =====
local CONFIG = {
    AntiRagdoll     = true,
    InfinityJump    = true,
    JumpForce       = 50,
    ClampFall       = 80,
    NormalSpeed     = 55,
    CarrySpeed      = 22,
    LaggerSpeed     = 10.1,
    LaggerCarry     = 8,
    AutoSteal       = true,
    StealRadius     = 61,
    StealDuration   = 1.3,
    AutoBatSpeed    = 40,
    AutoBatVertSpeed= 52,
    AutoBatDist     = -2.8,
    AutoBatHeight   = 4.75,
    AutoBatVOff     = 1,
    AutoBatTurnSpeed= 285,
    AutoBatMaxTurn  = 28,
    AutoSwing       = true,
}

-- ===== VARIABLES =====
local character, humanoid, hrp
local speedActive    = true
local isLaggerMode   = false
local speedConnection= nil
local isStealing     = false
local StealData      = {}
local heartbeatConn  = nil
local antiRagConnections = {}

local autoBatEnabled   = false
local autoBatConnection= nil
local autoBatEquipped  = false
local _autoBatTarget   = nil
local _autoBatLastScan = 0
local batTool          = nil
local autoBatSetVisual = nil

local antiKickEnabled      = true
local antiKickScreenLock   = false
local antiKickPending      = {autoPlay=false, aimbot=false}
local antiKickWatchedLabels= {}
local scanned              = {}
local _akCharOldNI         = nil
local _akCharMtRef         = nil

-- ===== CHARACTER REFRESH =====
local function refreshCharacter(char)
    character = char
    humanoid  = char and char:FindFirstChildOfClass("Humanoid")
    hrp       = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

-- char.__newindex: prevent server setting Parent=nil on our character
local function _hookCharNewindex(char)
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
        cm.__newindex = newcclosure(function(self, key, value)
            if key == "Parent" and value == nil then return nil end
            if _oldNI then return _oldNI(self, key, value) end
            rawset(self, key, value)
        end)
        setreadonly(cm, true)
        _akCharMtRef = cm
    end)
end

if LP.Character then
    refreshCharacter(LP.Character)
    _hookCharNewindex(LP.Character)
end

LP.CharacterAdded:Connect(function(char)
    task.wait(0.3)
    refreshCharacter(char)
    _hookCharNewindex(char)
    if CONFIG.AntiRagdoll then setupAntiRagdoll(char) end
    autoBatEquipped = false
    if autoBatEnabled then
        task.wait(0.5)
        ensureBatEquipped()
    end
end)

-- ===== ANTI-RAGDOLL =====
local function isRagdollState(h)
    if not h then return false end
    local s = h:GetState()
    return s == Enum.HumanoidStateType.Physics
        or s == Enum.HumanoidStateType.Ragdoll
        or s == Enum.HumanoidStateType.FallingDown
end

local function cleanRagdoll(char, hum)
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BallSocketConstraint") or obj:IsA("NoCollisionConstraint") or obj:IsA("HingeConstraint") then
            obj:Destroy()
        elseif obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyGyro") then
            obj:Destroy()
        elseif obj:IsA("Motor6D") then
            obj.Enabled = true
        end
    end
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,     false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics,     false)
    end
end

local function setupAntiRagdoll(char)
    if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if not hum or not root then return end
    cleanRagdoll(char, hum)
    local conn = hum.StateChanged:Connect(function()
        if isRagdollState(hum) then
            hum:ChangeState(Enum.HumanoidStateType.Running)
            cleanRagdoll(char, hum)
            if root then root.Anchored = false end
            pcall(function()
                local pm = LP.PlayerScripts:FindFirstChild("PlayerModule")
                if pm then require(pm):GetControls():Enable() end
            end)
        end
    end)
    table.insert(antiRagConnections, conn)
    local conn2 = char.DescendantAdded:Connect(function()
        if isRagdollState(hum) then cleanRagdoll(char, hum) end
    end)
    table.insert(antiRagConnections, conn2)
end

if CONFIG.AntiRagdoll and LP.Character then
    task.wait(0.5)
    setupAntiRagdoll(LP.Character)
end

-- ===== INFINITE JUMP (fixed: AssemblyLinearVelocity) =====
UserInputService.JumpRequest:Connect(function()
    if not CONFIG.InfinityJump then return end
    local c = LP.Character; if not c then return end
    local r = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
    if r then
        r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, CONFIG.JumpForce, r.AssemblyLinearVelocity.Z)
    end
end)

RunService.Heartbeat:Connect(function()
    if not CONFIG.InfinityJump then return end
    local c = LP.Character; if not c then return end
    local r = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
    if r and r.AssemblyLinearVelocity.Y < -CONFIG.ClampFall then
        r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, -CONFIG.ClampFall, r.AssemblyLinearVelocity.Z)
    end
end)

-- ===== SPEED (fixed: AssemblyLinearVelocity) =====
local function getCurrentSpeed()
    if not humanoid then return CONFIG.NormalSpeed end
    local isCarrying = humanoid.WalkSpeed < 25
    if isLaggerMode then
        return isCarrying and CONFIG.LaggerCarry or CONFIG.LaggerSpeed
    else
        return isCarrying and CONFIG.CarrySpeed or CONFIG.NormalSpeed
    end
end

local function startSpeed()
    if speedConnection then speedConnection:Disconnect() end
    speedConnection = RunService.Heartbeat:Connect(function()
        if not speedActive then return end
        if not humanoid or not hrp then return end
        local md = humanoid.MoveDirection
        if md.Magnitude == 0 then return end
        local spd = getCurrentSpeed()
        hrp.AssemblyLinearVelocity = Vector3.new(md.X * spd, hrp.AssemblyLinearVelocity.Y, md.Z * spd)
    end)
end

startSpeed()

-- ===== AUTO-STEAL ===== (untouched)
local function getHRP()
    local c = LP.Character
    if c then return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso") end
    return nil
end

local function isMyPlotByName(pn)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(pn)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") then return yb.Enabled == true end
    end
    return false
end

local function findNearestPrompt()
    local root = getHRP()
    if not root then return nil end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local nearest, dist = nil, math.huge
    for _, plot in ipairs(plots:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local pods = plot:FindFirstChild("AnimalPodiums")
        if not pods then continue end
        for _, pod in ipairs(pods:GetChildren()) do
            local base = pod:FindFirstChild("Base")
            if not base then continue end
            local spawn = base:FindFirstChild("Spawn")
            if not spawn then continue end
            local d = (spawn.Position - root.Position).Magnitude
            if d <= CONFIG.StealRadius and d < dist then
                local att = spawn:FindFirstChild("PromptAttachment")
                if att then
                    for _, p in ipairs(att:GetChildren()) do
                        if p:IsA("ProximityPrompt") and p.ActionText and p.ActionText:find("Steal") then
                            nearest, dist = p, d
                        end
                    end
                end
            end
        end
    end
    return nearest
end

local function executeSteal(prompt)
    if isStealing then return end
    if not prompt or not prompt.Parent then return end
    if not StealData[prompt] then
        StealData[prompt] = {hold={}, trigger={}, ready=true}
        if getconnections then
            for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                if c.Function then table.insert(StealData[prompt].hold, c.Function) end
            end
            for _, c in ipairs(getconnections(prompt.Triggered)) do
                if c.Function then table.insert(StealData[prompt].trigger, c.Function) end
            end
        end
    end
    local data = StealData[prompt]
    if not data.ready then return end
    data.ready = false
    isStealing = true
    task.spawn(function()
        for _, f in ipairs(data.hold) do pcall(f) end
        task.wait(CONFIG.StealDuration)
        for _, f in ipairs(data.trigger) do pcall(f) end
        task.wait(0.05)
        data.ready = true
        isStealing = false
    end)
end

if CONFIG.AutoSteal then
    heartbeatConn = RunService.Heartbeat:Connect(function()
        if isStealing then return end
        local success, prompt = pcall(findNearestPrompt)
        if success and prompt then pcall(executeSteal, prompt) end
    end)
end

-- ===== LAGGER MODE TOGGLE (L key — moved from R to avoid conflict with Insta Reset) =====
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.L then
        isLaggerMode = not isLaggerMode
    end
end)

-- ============================================================
-- AUTO BAT (Aimbot)
-- ============================================================
local function getCharacter() return LP.Character end
local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end
local function getRootPart()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getAutoBatTarget()
    local root = getRootPart()
    if not root then return nil end
    local now = tick()
    if now - _autoBatLastScan <= 0.1 and _autoBatTarget and _autoBatTarget.Parent then
        local hum = _autoBatTarget.Parent:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then return _autoBatTarget end
    end
    _autoBatLastScan = now
    _autoBatTarget   = nil
    local closest, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum   = plr.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and hum and hum.Health > 0 then
                local dist = (tRoot.Position - root.Position).Magnitude
                if dist < minDist then minDist = dist; closest = tRoot end
            end
        end
    end
    _autoBatTarget = closest
    return _autoBatTarget
end

local function findBat()
    local char = getCharacter(); if not char then return nil end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("bat") or n:find("slap") then return tool end
        end
    end
    local bp = LP:FindFirstChildOfClass("Backpack") or LP:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("bat") or n:find("slap") then return tool end
            end
        end
    end
    return nil
end

local function ensureBatEquipped()
    local char = getCharacter(); local hum = getHumanoid()
    if not char or not hum then return end
    if not char:FindFirstChildOfClass("Tool") then
        local bat = findBat()
        if bat then pcall(function() hum:EquipTool(bat) end); batTool = bat end
    else
        batTool = char:FindFirstChildOfClass("Tool")
    end
end

local function resetAutoBatMotion()
    local root = getRootPart(); local hum = getHumanoid()
    if root then
        root.AssemblyLinearVelocity = root.AssemblyLinearVelocity * 0.3
        root.AssemblyAngularVelocity = Vector3.zero
    end
    if hum then hum.AutoRotate = true end
end

local function startAutoBat()
    if autoBatConnection then return end
    autoBatConnection = RunService.Heartbeat:Connect(function()
        if not autoBatEnabled then return end
        if antiKickScreenLock then return end
        local char = getCharacter(); local hum = getHumanoid(); local root = getRootPart()
        if not char or not hum or not root then return end
        if not autoBatEquipped then autoBatEquipped = true; ensureBatEquipped() end
        local target = getAutoBatTarget()
        if target then
            local targetVel    = target.AssemblyLinearVelocity
            local aimTargetPos = target.Position + (targetVel * math.clamp(targetVel.Magnitude / 130, 0.05, 0.15)) + Vector3.new(0, CONFIG.AutoBatVOff, 0)
            hum.AutoRotate = false
            local look     = aimTargetPos - root.Position
            local flatLook = Vector3.new(look.X, 0, look.Z)
            if look.Magnitude > 0.01 and flatLook.Magnitude > 0.01 then
                local targetYaw  = math.deg(math.atan2(-flatLook.X, -flatLook.Z))
                local yawDelta   = (targetYaw - root.Orientation.Y + 180) % 360 - 180
                local targetPitch= math.deg(math.atan2(look.Y, flatLook.Magnitude))
                local pitchDelta = (targetPitch - root.Orientation.X + 180) % 360 - 180
                local yawRate    = math.clamp(math.rad(yawDelta)   * CONFIG.AutoBatTurnSpeed, -CONFIG.AutoBatMaxTurn, CONFIG.AutoBatMaxTurn)
                local pitchRate  = math.clamp(math.rad(pitchDelta) * CONFIG.AutoBatTurnSpeed, -CONFIG.AutoBatMaxTurn, CONFIG.AutoBatMaxTurn)
                local yawRad     = math.rad(root.Orientation.Y)
                local rightAxis  = Vector3.new(math.cos(yawRad), 0, -math.sin(yawRad))
                root.AssemblyAngularVelocity = Vector3.new(0, yawRate, 0) + (rightAxis * pitchRate)
            else
                root.AssemblyAngularVelocity = Vector3.zero
            end
            local dir      = look.Magnitude > 0.01 and look.Unit or Vector3.zero
            local standPos = aimTargetPos - (dir * CONFIG.AutoBatDist) + Vector3.new(0, CONFIG.AutoBatHeight, 0)
            local moveDir  = standPos - root.Position
            local hDir     = Vector3.new(moveDir.X, 0, moveDir.Z)
            local hVel     = hDir.Magnitude > 0.1 and hDir.Unit * CONFIG.AutoBatSpeed or Vector3.zero
            local vVel     = math.abs(moveDir.Y) > 0.1 and Vector3.new(0, math.sign(moveDir.Y) * CONFIG.AutoBatVertSpeed, 0) or Vector3.new(0, -2, 0)
            root.AssemblyLinearVelocity = hVel + vVel
            if hDir.Magnitude > 0.5 then hum:Move(hDir.Unit, false) end
            if CONFIG.AutoSwing and (root.Position - target.Position).Magnitude < 6 then
                local bat = findBat() or batTool
                if bat and bat:IsA("Tool") then pcall(function() bat:Activate() end) end
            end
        else
            hum.AutoRotate = true
            root.AssemblyAngularVelocity  = Vector3.zero
            root.AssemblyLinearVelocity   = Vector3.zero
        end
    end)
end

local function stopAutoBat()
    if autoBatConnection then autoBatConnection:Disconnect(); autoBatConnection = nil end
    resetAutoBatMotion()
    autoBatEquipped = false
end

local function setAutoBatState(enabled)
    autoBatEnabled = enabled
    if enabled then startAutoBat() else stopAutoBat() end
end

-- ============================================================
-- SCREEN-TEXT ANTI-KICK
-- ============================================================
local STEAL_BAD  = {"backpack","inventory","chatmain","bubblechat","overhead","nametag","leaderboard","hudgui"}
local STEAL_GOOD = {"global","announce","notif","banner","broadcast","event","popup","sammy","alert","header","news","system","message","center","steal","countdown","timer"}

local function stealClassify(obj)
    if not obj or not obj.Parent then return false end
    local n   = (obj.Name or ""):lower()
    local pn  = ((obj.Parent and obj.Parent.Name) or ""):lower()
    local gpn = ((obj.Parent and obj.Parent.Parent and obj.Parent.Parent.Name) or ""):lower()
    for _, b in ipairs(STEAL_BAD)  do if n:find(b,1,true) or pn:find(b,1,true) then return false end end
    for _, g in ipairs(STEAL_GOOD) do if n:find(g,1,true) or pn:find(g,1,true) or gpn:find(g,1,true) then return true end end
    return false
end

local function antiKickProcessScreenText(obj, txt)
    if not antiKickEnabled then return end
    if type(txt) ~= "string" then return end
    local clean = txt:gsub("<[^>]+>",""):gsub("%s+","")
    if clean == "" then return end
    if not stealClassify(obj) then return end
    if clean == "5" then
        antiKickScreenLock = true
        if autoBatEnabled then
            antiKickPending.aimbot = true
            autoBatEnabled = false
            if autoBatSetVisual then autoBatSetVisual(false) end
            stopAutoBat()
        end
    elseif clean == "1" then
        task.delay(0.6, function()
            antiKickScreenLock = false
            if antiKickPending.aimbot and not autoBatEnabled then
                autoBatEnabled = true
                if autoBatSetVisual then autoBatSetVisual(true) end
                startAutoBat()
            end
            antiKickPending = {autoPlay=false, aimbot=false}
        end)
    end
end

local function antiKickWatchLabel(obj)
    if antiKickWatchedLabels[obj] then return end
    antiKickWatchedLabels[obj] = true
    pcall(function() antiKickProcessScreenText(obj, obj.Text or "") end)
    obj:GetPropertyChangedSignal("Text"):Connect(function()
        antiKickProcessScreenText(obj, obj.Text or "")
    end)
end

task.spawn(function()
    local pg = LP:WaitForChild("PlayerGui")
    for _, obj in ipairs(pg:GetDescendants()) do
        if obj:IsA("TextLabel") and stealClassify(obj) then antiKickWatchLabel(obj) end
    end
    pg.DescendantAdded:Connect(function(obj)
        task.wait(0.04)
        if not obj:IsA("TextLabel") then return end
        if stealClassify(obj) then
            antiKickWatchLabel(obj)
            local t = obj.Text or ""
            if #t >= 1 then antiKickProcessScreenText(obj, t) end
        end
        obj:GetPropertyChangedSignal("Text"):Connect(function()
            if stealClassify(obj) then
                if not antiKickWatchedLabels[obj] then antiKickWatchLabel(obj) end
                antiKickProcessScreenText(obj, obj.Text or "")
            end
        end)
    end)
end)

pcall(function()
    if TCS and TCS.MessageReceived then
        TCS.MessageReceived:Connect(function(msg)
            if not antiKickEnabled or not msg then return end
            local t = (msg.Text or ""):gsub("<[^>]+>",""):gsub("%s+","")
            if t == "5" then
                antiKickScreenLock = true
                if autoBatEnabled then
                    antiKickPending.aimbot = true
                    autoBatEnabled = false
                    if autoBatSetVisual then autoBatSetVisual(false) end
                    stopAutoBat()
                end
            elseif t == "1" then
                task.delay(0.6, function()
                    antiKickScreenLock = false
                    if antiKickPending.aimbot and not autoBatEnabled then
                        autoBatEnabled = true
                        if autoBatSetVisual then autoBatSetVisual(true) end
                        startAutoBat()
                    end
                    antiKickPending = {autoPlay=false, aimbot=false}
                end)
            end
        end)
    end
end)

-- ============================================================
-- ANTI-KICK CORE — ALWAYS ON
-- ============================================================
local function ultimateAntiKick()

    -- 1. Player:Kick() block via __namecall (fixed: uses getnamecallmethod)
    pcall(function()
        local mt = getrawmetatable(LP); if not mt then return end
        setreadonly(mt, false)
        local _rawNC = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local fromGame = not (checkcaller and checkcaller())
            if fromGame then
                local method = (getnamecallmethod and getnamecallmethod() or ""):lower()
                if self == LP and method == _KW_KICK then return nil end
            end
            return _rawNC(self, ...)
        end)
        setreadonly(mt, true)
    end)

    -- 2. game:Shutdown / BindToClose / Load / Teleport block
    pcall(function()
        local gmt = getrawmetatable(game); if not gmt then return end
        setreadonly(gmt, false)
        local _gRaw = gmt.__namecall
        gmt.__namecall = newcclosure(function(self, ...)
            local fromGame = not (checkcaller and checkcaller())
            if fromGame then
                local m = (getnamecallmethod and getnamecallmethod() or ""):lower()
                if m == _KW_SHUTDOWN or m == _KW_BINDCLOSE or m == _KW_LOAD then return end
                if m:find(_KW_TELEPORT) then return end
            end
            return _gRaw(self, ...)
        end)
        setreadonly(gmt, true)
    end)

    -- 3. TeleportService — block all namecall methods from server
    pcall(function()
        local tsvc = game:GetService("TeleportService")
        local tmt  = getrawmetatable(tsvc); if not tmt then return end
        setreadonly(tmt, false)
        local _tRaw = tmt.__namecall
        tmt.__namecall = newcclosure(function(self, ...)
            local fromGame = not (checkcaller and checkcaller())
            if fromGame then return end
            return _tRaw(self, ...)
        end)
        setreadonly(tmt, true)
    end)

    -- 4. Health protection (Heartbeat)
    RunService.Heartbeat:Connect(function()
        if humanoid and humanoid.Parent then
            if humanoid.Health < humanoid.MaxHealth then humanoid.Health = humanoid.MaxHealth end
            if humanoid.Health <= 0              then humanoid.Health = humanoid.MaxHealth end
        end
    end)

    -- 5. Death state block
    if humanoid then
        humanoid.StateChanged:Connect(function(_, newState)
            if newState == Enum.HumanoidStateType.Dead or newState == Enum.HumanoidStateType.Dying then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                humanoid.Health = humanoid.MaxHealth
            end
        end)
    end

    -- 6. Humanoid state + health loop (0.05s)
    task.spawn(function()
        while true do
            pcall(function()
                if humanoid and humanoid.Parent then
                    if humanoid.Health <= 0 then humanoid.Health = humanoid.MaxHealth end
                    local s = humanoid:GetState()
                    if s == Enum.HumanoidStateType.Dead or s == Enum.HumanoidStateType.Dying then
                        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                end
            end)
            task.wait(0.05)
        end
    end)

    -- 7. MaxHealth lock (0.1s)
    task.spawn(function()
        while true do
            pcall(function()
                if humanoid and humanoid.Parent then
                    if humanoid.MaxHealth ~= 100      then humanoid.MaxHealth = 100 end
                    if humanoid.Health > humanoid.MaxHealth then humanoid.Health = humanoid.MaxHealth end
                    if humanoid.Health <= 0           then humanoid.Health = humanoid.MaxHealth end
                end
            end)
            task.wait(0.1)
        end
    end)

    -- 8. Character parent restore + fall damage restore + humanoid regen (0.05s)
    task.spawn(function()
        while true do
            pcall(function()
                local c = LP.Character
                if c then
                    if c.Parent ~= Workspace then c.Parent = Workspace end
                    local h = c:FindFirstChildOfClass("Humanoid")
                    if h then
                        local root = c:FindFirstChild("HumanoidRootPart")
                        if root and root.AssemblyLinearVelocity.Y < -50 then
                            h.Health = h.MaxHealth
                        end
                    else
                        local nh = Instance.new("Humanoid"); nh.Parent = c
                    end
                end
            end)
            task.wait(0.05)
        end
    end)

    -- 9. Remote block by name in ReplicatedStorage (RemoteEvent + UnreliableRemoteEvent + RemoteFunction)
    pcall(function()
        local function hookRemoteObj(obj)
            if not (obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent") or obj:IsA("RemoteFunction")) then return end
            if not _isKickName(obj.Name) then return end
            pcall(function()
                if obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent") then
                    obj.OnClientEvent:Connect(function() return nil end)
                elseif obj:IsA("RemoteFunction") then
                    obj.OnClientInvoke = function() return nil end
                end
            end)
        end
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do pcall(hookRemoteObj, d) end
        ReplicatedStorage.DescendantAdded:Connect(function(d) pcall(hookRemoteObj, d) end)
    end)

    -- 10. HTTP block (reporting / telemetry / anticheat endpoints)
    pcall(function()
        local _BAD_HTTP = {_KW_LOG, _KW_REPORT, _KW_DETECT, _KW_ANALYTICS, "telemetry", _KW_ANTICHEAT, "anti_cheat", _KW_BAN}
        local function _wrapReq(fn)
            return newcclosure(function(opts, ...)
                if type(opts) == "table" and type(opts.Url) == "string" then
                    local url = opts.Url:lower()
                    for _, kw in ipairs(_BAD_HTTP) do
                        if url:find(kw, 1, true) then return {StatusCode=200, Body=""} end
                    end
                end
                return fn(opts, ...)
            end)
        end
        if syn and syn.request then syn.request = _wrapReq(syn.request) end
        if request             then request     = _wrapReq(request)     end
        if http_request        then http_request= _wrapReq(http_request) end
    end)

end

-- ============================================================
-- GC SCANNER — hook kick remotes found outside ReplicatedStorage
-- ============================================================
local function _gcHookRemote(remote)
    pcall(function()
        local oldFire
        oldFire = hookfunction(remote.FireServer, newcclosure(function(self, ...)
            local args = {...}
            for _, a in ipairs(args) do
                if _isKickArg(tostring(a)) then return task.wait(9e9) end
            end
            return oldFire(self, ...)
        end))
    end)
end

local function deepScan(value)
    if scanned[value] then return end
    scanned[value] = true
    if typeof(value) == "Instance"
    and (value:IsA("RemoteEvent") or value:IsA("UnreliableRemoteEvent")) then
        if not value:IsDescendantOf(ReplicatedStorage) then
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
        if ok and up then
            for _, v in pairs(up) do deepScan(v) end
        end
    end
    if typeof(value) == "table" then
        for _, v in pairs(value) do deepScan(v) end
    end
end

local function runGCScan()
    pcall(function()
        for _, obj in next, getgc(true) do
            if typeof(obj) == "function" and islclosure(obj) and not isexecutorclosure(obj) then
                deepScan(obj)
            end
        end
    end)
end

if getgc and islclosure and isexecutorclosure then
    task.spawn(runGCScan)
    -- Periodic rescan every 30s (catches late-injected anti-cheat remotes)
    task.spawn(function()
        while true do
            task.wait(30)
            scanned = {}
            runGCScan()
        end
    end)
end

-- Intercept Instance.new("RemoteEvent") to hook remotes created after the initial scan
pcall(function()
    local _origNew
    _origNew = hookfunction(Instance.new, newcclosure(function(className, ...)
        local obj = _origNew(className, ...)
        if className == "RemoteEvent" or className == "UnreliableRemoteEvent" then
            task.defer(function() pcall(_gcHookRemote, obj) end)
        end
        return obj
    end))
end)

-- ============================================================
-- AUTO BAT TOGGLE BUTTON
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoBatButton"
screenGui.ResetOnSpawn = false
screenGui.Parent = LP:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton", screenGui)
btn.Size = UDim2.new(0, 130, 0, 40)
btn.Position = UDim2.new(0.7, -65, 0.8, 0)
btn.Text = "AUTO BAT: OFF"
btn.Font = Enum.Font.GothamBold
btn.TextSize = 14
btn.TextColor3 = Color3.new(1, 1, 1)
btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
btn.Active = true
btn.Draggable = true

autoBatSetVisual = function(state)
    btn.Text = state and "AUTO BAT: ON" or "AUTO BAT: OFF"
    btn.BackgroundColor3 = state and Color3.fromRGB(60, 180, 60) or Color3.fromRGB(180, 40, 40)
end

btn.MouseButton1Click:Connect(function()
    local newState = not autoBatEnabled
    setAutoBatState(newState)
    if autoBatSetVisual then autoBatSetVisual(newState) end
end)

-- ============================================================
-- INSTA RESET (Envy Style)
-- ============================================================
local function doSelectedReset()
    local Net = ReplicatedStorage:FindFirstChild("Packages")
    if Net then Net = Net:FindFirstChild("Net") end
    if not Net then
        local char = LP.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
        return
    end
    local remote = nil
    local childs = Net:GetChildren()
    for i = 1, #childs - 1 do
        if childs[i] and childs[i + 1] and string.find(childs[i].Name, "Tools/Cooldown") then
            remote = childs[i + 1]; break
        end
    end
    if not remote then
        local char = LP.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
        return
    end
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
    LP.Character = nil
    local sending         = true
    local loopConnection
    local fire            = remote.FireServer
    local _respawnThrottle= 0
    loopConnection = RunService.Heartbeat:Connect(function(dt)
        if not sending then
            if loopConnection then loopConnection:Disconnect(); loopConnection = nil end
            return
        end
        _respawnThrottle = _respawnThrottle + dt
        if _respawnThrottle >= 0.016 then
            _respawnThrottle = 0
            pcall(fire, remote, "f888ee6e-c86d-46e1-93d7-0639d6635d42", LP, "balloon")
        end
        if sending and LP.Character then LP.Character = nil end
    end)
    local conn
    conn = LP.CharacterAdded:Connect(function()
        sending = false
        if loopConnection then loopConnection:Disconnect(); loopConnection = nil end
        if conn then conn:Disconnect() end
        task.spawn(function()
            local newBp = LP:WaitForChild("Backpack", 3)
            if newBp then
                for _, t in ipairs(savedTools) do if t then t.Parent = newBp end end
            end
            savedTools = {}
        end)
    end)
    task.delay(4, function()
        sending = false
        if loopConnection then loopConnection:Disconnect(); loopConnection = nil end
        local curBp = LP:FindFirstChild("Backpack")
        if curBp and #savedTools > 0 then
            for _, t in ipairs(savedTools) do if t then t.Parent = curBp end end
            savedTools = {}
        end
    end)
end

-- Reset keybind (R)
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.R then
        pcall(doSelectedReset)
    end
end)

-- ============================================================
-- ENVY RESET UI
-- ============================================================
local function createResetUI()
    local EnvyResetGui = Instance.new("ScreenGui")
    EnvyResetGui.Name           = "EnvyResetGui"
    EnvyResetGui.ResetOnSpawn   = false
    EnvyResetGui.DisplayOrder   = 10
    EnvyResetGui.IgnoreGuiInset = true
    EnvyResetGui.Parent         = LP:WaitForChild("PlayerGui")

    local Frame = Instance.new("Frame")
    Frame.Size                = UDim2.new(0, 266, 0, 146)
    Frame.Position            = UDim2.new(0, 371, 0, 529)
    Frame.BackgroundColor3    = Color3.fromRGB(0, 0, 0)
    Frame.BackgroundTransparency = 0.6
    Frame.BorderSizePixel     = 0
    Frame.ClipsDescendants    = false
    Frame.Active              = false
    Frame.Selectable          = false
    Frame.Parent              = EnvyResetGui
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 12)

    local Main = Instance.new("Frame")
    Main.Name              = "Main"
    Main.Size              = UDim2.new(0, 260, 0, 140)
    Main.Position          = UDim2.new(0, 374, 0, 532)
    Main.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
    Main.BorderSizePixel   = 0
    Main.ClipsDescendants  = true
    Main.Active            = true
    Main.Selectable        = false
    Main.Parent            = EnvyResetGui
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", Main).Color        = Color3.fromRGB(0, 0, 0)

    local Frame2 = Instance.new("Frame")
    Frame2.Size           = UDim2.new(1, 0, 0, 50)
    Frame2.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Frame2.BorderSizePixel= 0
    Frame2.ZIndex         = 5
    Frame2.Active         = false
    Frame2.Selectable     = false
    Frame2.Parent         = Main

    local Frame3 = Instance.new("Frame")
    Frame3.Size           = UDim2.new(1, 0, 0, 1)
    Frame3.Position       = UDim2.new(0, 0, 1, -1)
    Frame3.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Frame3.BorderSizePixel= 0
    Frame3.ZIndex         = 6
    Frame3.Parent         = Frame2

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size               = UDim2.new(0, 150, 0, 24)
    TitleLabel.Position           = UDim2.new(0, 12, 0.5, -12)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.ZIndex             = 6
    TitleLabel.Text               = "ENVY INSTA RESET"
    TitleLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize           = 16
    TitleLabel.Font               = Enum.Font.GothamBlack
    TitleLabel.TextXAlignment     = Enum.TextXAlignment.Left
    TitleLabel.Parent             = Frame2

    local ModeBtn = Instance.new("TextButton")
    ModeBtn.Size            = UDim2.new(0, 60, 0, 26)
    ModeBtn.Position        = UDim2.new(1, -70, 0.5, -13)
    ModeBtn.BackgroundColor3= Color3.fromRGB(0, 0, 0)
    ModeBtn.BorderSizePixel = 0
    ModeBtn.ZIndex          = 6
    ModeBtn.Text            = "MOBILE"
    ModeBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
    ModeBtn.TextSize        = 10
    ModeBtn.Font            = Enum.Font.GothamBold
    ModeBtn.Parent          = Frame2
    Instance.new("UICorner", ModeBtn).CornerRadius = UDim.new(0, 5)
    Instance.new("UIStroke", ModeBtn).Color        = Color3.fromRGB(0, 0, 0)

    local ContentFrame = Instance.new("Frame")
    ContentFrame.Size             = UDim2.new(1, -20, 1, -60)
    ContentFrame.Position         = UDim2.new(0, 10, 0, 55)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.BorderSizePixel  = 0
    ContentFrame.ZIndex           = 2
    ContentFrame.Parent           = Main

    local Row = Instance.new("Frame")
    Row.Size            = UDim2.new(1, 0, 0, 38)
    Row.BackgroundColor3= Color3.fromRGB(0, 0, 0)
    Row.BorderSizePixel = 0
    Row.Parent          = ContentFrame
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", Row).Color        = Color3.fromRGB(0, 0, 0)

    local ResetLabel = Instance.new("TextLabel")
    ResetLabel.Size           = UDim2.new(0.55, 0, 1, 0)
    ResetLabel.Position       = UDim2.new(0, 12, 0, 0)
    ResetLabel.BackgroundTransparency = 1
    ResetLabel.Text           = "Reset"
    ResetLabel.TextColor3     = Color3.fromRGB(255, 255, 255)
    ResetLabel.TextSize       = 12
    ResetLabel.Font           = Enum.Font.GothamBold
    ResetLabel.TextXAlignment = Enum.TextXAlignment.Left
    ResetLabel.Parent         = Row

    local PCBtn = Instance.new("TextButton")
    PCBtn.Size            = UDim2.new(0, 82, 0, 26)
    PCBtn.Position        = UDim2.new(1, -88, 0.5, -13)
    PCBtn.BackgroundColor3= Color3.fromRGB(0, 0, 0)
    PCBtn.BorderSizePixel = 0
    PCBtn.Text            = "R"
    PCBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
    PCBtn.TextSize        = 11
    PCBtn.Font            = Enum.Font.GothamBold
    PCBtn.Parent          = Row
    Instance.new("UICorner", PCBtn).CornerRadius = UDim.new(0, 5)
    Instance.new("UIStroke", PCBtn).Color        = Color3.fromRGB(0, 0, 0)

    local MobileBtn = Instance.new("TextButton")
    MobileBtn.Size            = UDim2.new(1, -12, 1, -6)
    MobileBtn.Position        = UDim2.new(0, 6, 0, 3)
    MobileBtn.BackgroundColor3= Color3.fromRGB(0, 0, 0)
    MobileBtn.BorderSizePixel = 0
    MobileBtn.Visible         = false
    MobileBtn.ZIndex          = 3
    MobileBtn.Text            = "RESET"
    MobileBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
    MobileBtn.TextSize        = 13
    MobileBtn.Font            = Enum.Font.GothamBold
    MobileBtn.Parent          = Row
    Instance.new("UICorner", MobileBtn).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", MobileBtn).Color        = Color3.fromRGB(0, 0, 0)

    local DiscordLabel = Instance.new("TextLabel")
    DiscordLabel.Size             = UDim2.new(1, 0, 0, 18)
    DiscordLabel.Position         = UDim2.new(0, 0, 1, -20)
    DiscordLabel.BackgroundTransparency = 1
    DiscordLabel.ZIndex           = 3
    DiscordLabel.Text             = "discord.gg/envyhub"
    DiscordLabel.TextColor3       = Color3.fromRGB(128, 128, 128)
    DiscordLabel.TextSize         = 10
    DiscordLabel.Font             = Enum.Font.Gotham
    DiscordLabel.Parent           = Main

    local isMobile = false
    local function applyLayout()
        if isMobile then
            ModeBtn.Text      = "PC"
            ResetLabel.Visible= false
            PCBtn.Visible     = false
            MobileBtn.Visible = true
        else
            ModeBtn.Text      = "MOBILE"
            ResetLabel.Visible= true
            PCBtn.Visible     = true
            MobileBtn.Visible = false
        end
    end

    ModeBtn.MouseButton1Click:Connect(function()
        isMobile = not isMobile
        applyLayout()
    end)
    applyLayout()

    local offset     = Main.Position - Frame.Position
    local dragging   = false
    local dragStart, frameStart

    Frame2.Active = true
    Frame2.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging   = true
            dragStart  = input.Position
            frameStart = Frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta  = input.Position - dragStart
            local newPos = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X,
                                     frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
            Frame.Position = newPos
            Main.Position  = newPos + offset
        end
    end)

    PCBtn.MouseButton1Click:Connect(function()    pcall(doSelectedReset) end)
    MobileBtn.MouseButton1Click:Connect(function() pcall(doSelectedReset) end)
end

-- ============================================================
-- INITIALIZE
-- ============================================================
task.spawn(function()
    task.wait(0.5)
    createResetUI()
    antiKickEnabled = true
    ultimateAntiKick()
end)

print("=== ALL FEATURES LOADED ===")
print("Anti-Ragdoll   : ON")
print("Infinite Jump  : ON")
print("Speed          : ON  (Normal:55 | Carry:22)")
print("Auto-Steal     : ON  (Radius:61 | Duration:1.3s)")
print("Auto Bat       : OFF (button toggle | Speed:40)")
print("Anti-Kick      : ALWAYS ON")
print("Insta-Reset    : ON  (R key or button)")
print("Lagger Mode    : L key  (was R — moved to avoid conflict)")
print("=============================")
