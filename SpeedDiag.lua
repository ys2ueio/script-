-- SpeedDiag v4  |  usage strictement privé
if _G["_SPDIAG"] then pcall(function() _G["_SPDIAG"]() end) end
_G["_SPDIAG"] = nil

local cloneref   = cloneref or function(x) return x end
local Players    = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local LP         = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

local char = LP.Character
local hum  = char:FindFirstChildOfClass("Humanoid")
local hrp  = char:FindFirstChild("HumanoidRootPart")

print("[SpeedDiag] Bouge pendant 7 secondes...")

-- ── Données ────────────────────────────────────────────────
local DURATION   = 7
local t0         = tick()

local frames     = 0
local maxSpd     = 0
local totalSpd   = 0
local movingF    = 0
local wsChanges  = {}
local cfTele     = 0
local alvSpikes  = 0
local psChanges  = 0
local sitChanges = 0
local hrpLog     = {}
local lastWS     = hum and hum.WalkSpeed or 16
local lastPS     = hum and hum.PlatformStand or false
local lastSit    = hum and hum.Sit or false
local lastPos    = hrp and hrp.Position or Vector3.zero
local lastVel    = hrp and hrp.AssemblyLinearVelocity or Vector3.zero

-- ── Watchers ChildAdded/Removed ──────────────────────────
local _addC, _remC
if hrp then
    _addC = hrp.ChildAdded:Connect(function(v)
        table.insert(hrpLog, string.format("+[%s] %s", v.ClassName, v.Name))
    end)
    _remC = hrp.ChildRemoved:Connect(function(v)
        table.insert(hrpLog, string.format("-[%s] %s", v.ClassName, v.Name))
    end)
end

-- ── Stopper ──────────────────────────────────────────────
local function _stop()
    _G["_SPDIAG"] = nil
    if _addC then pcall(function() _addC:Disconnect() end) end
    if _remC then pcall(function() _remC:Disconnect() end) end
end
_G["_SPDIAG"] = _stop

-- ── Heartbeat : même pattern que les autres scripts ───────
local _hbConn
_hbConn = RunService.Heartbeat:Connect(function(dt)
    local elapsed = tick() - t0

    if not hum or not hrp then
        hum = char:FindFirstChildOfClass("Humanoid")
        hrp = char:FindFirstChild("HumanoidRootPart")
        return
    end

    frames = frames + 1

    -- Vitesse XZ
    local vel = hrp.AssemblyLinearVelocity
    local spd = Vector3.new(vel.X, 0, vel.Z).Magnitude
    if spd > 1 then
        movingF   = movingF + 1
        totalSpd  = totalSpd + spd
        if spd > maxSpd then maxSpd = spd end
    end

    -- ALV spike (set direct brutal)
    local dv = (vel - lastVel).Magnitude
    if dv > 8 then alvSpikes = alvSpikes + 1 end
    lastVel = vel

    -- CFrame téléport
    local pos = hrp.Position
    if (pos - lastPos).Magnitude > 4 then cfTele = cfTele + 1 end
    lastPos = pos

    -- WalkSpeed
    local ws = hum.WalkSpeed
    if ws ~= lastWS then
        table.insert(wsChanges, string.format("t%.1f: %.1f->%.1f", elapsed, lastWS, ws))
        lastWS = ws
    end

    -- PlatformStand (désactive physique humanoid)
    local ps = hum.PlatformStand
    if ps ~= lastPS then psChanges = psChanges + 1; lastPS = ps end

    -- Sit (autre trick physique)
    local si = hum.Sit
    if si ~= lastSit then sitChanges = sitChanges + 1; lastSit = si end

    -- Fin de collecte
    if elapsed >= DURATION then
        _hbConn:Disconnect()
        _stop()

        -- Scan instances finales
        local hrpInst, charInst = {}, {}
        for _, v in ipairs(hrp:GetChildren()) do
            local s = string.format("[%s] %s", v.ClassName, v.Name)
            pcall(function()
                if v:IsA("BodyVelocity")   then s = s .. " MF="..tostring(v.MaxForce).." V="..tostring(v.Velocity) end
                if v:IsA("LinearVelocity") then s = s .. " MF="..tostring(v.MaxForce) end
                if v:IsA("VectorForce")    then s = s .. " F="..tostring(v.Force) end
                if v:IsA("BodyForce")      then s = s .. " F="..tostring(v.Force) end
                if v:IsA("AlignPosition")  then s = s .. " MF="..tostring(v.MaxForce) end
            end)
            table.insert(hrpInst, s)
        end
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BodyMover") or v:IsA("Constraint") then
                table.insert(charInst, string.format("[%s] %s in:%s", v.ClassName, v.Name, v.Parent.Name))
            end
        end

        -- Verdict
        local methods = {}
        local bv, lv, vf, bf, ap = false, false, false, false, false
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BodyVelocity")   then bv = true end
            if v:IsA("LinearVelocity") then lv = true end
            if v:IsA("VectorForce")    then vf = true end
            if v:IsA("BodyForce")      then bf = true end
            if v:IsA("AlignPosition")  then ap = true end
        end
        if bv then table.insert(methods, "BodyVelocity") end
        if lv then table.insert(methods, "LinearVelocity") end
        if vf then table.insert(methods, "VectorForce") end
        if bf then table.insert(methods, "BodyForce") end
        if ap then table.insert(methods, "AlignPosition") end
        if #wsChanges > 0 then table.insert(methods, "WalkSpeed override") end
        if cfTele > 2     then table.insert(methods, "CFrame teleport") end
        if psChanges > 0  then table.insert(methods, "PlatformStand trick") end
        if sitChanges > 0 then table.insert(methods, "Sit trick") end
        if alvSpikes > 10 and not bv and not lv then
            table.insert(methods, "AssemblyLinearVelocity direct")
        end

        -- Rapport
        local avg = movingF > 0 and (totalSpd / movingF) or 0
        print("========== SpeedDiag v4 ==========")
        print("Frames       : " .. frames)
        print("Spd max XZ   : " .. string.format("%.1f", maxSpd))
        print("Spd moy XZ   : " .. string.format("%.1f", avg))
        print("WalkSpeed fin: " .. hum.WalkSpeed)
        print("WS changes   : " .. #wsChanges)
        for _, l in ipairs(wsChanges)  do print("  " .. l) end
        print("CFrame tele  : " .. cfTele)
        print("ALV spikes   : " .. alvSpikes)
        print("PlatformStand: " .. psChanges .. "x")
        print("Sit changes  : " .. sitChanges .. "x")
        print("--- HRP instances fin ---")
        if #hrpInst == 0 then print("  (vide)") end
        for _, l in ipairs(hrpInst)   do print("  " .. l) end
        print("--- HRP runtime log ---")
        if #hrpLog == 0 then print("  (rien)") end
        for _, l in ipairs(hrpLog)    do print("  " .. l) end
        print("--- Movers/Constraints char ---")
        if #charInst == 0 then print("  (aucun)") end
        for _, l in ipairs(charInst)  do print("  " .. l) end
        print("--- MÉTHODE ---")
        if #methods == 0 then
            print("  Inconnue (relance en bougeant)")
        else
            for _, m in ipairs(methods) do print("  >> " .. m) end
        end
        print("==================================")
    end
end)
