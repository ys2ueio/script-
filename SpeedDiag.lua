-- SpeedDiag v3 | Analyse méthode de speed | Bouge pendant 6s
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP         = Players.LocalPlayer

local char = LP.Character
if not char then char = LP.CharacterAdded:Wait() end

local hum = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")

if not hum or not hrp then
    print("[SpeedDiag] ERREUR: Humanoid ou HRP introuvable")
    return
end

print("[SpeedDiag] Démarré — bouge pendant 6 secondes")

local DURATION = 6
local t0       = tick()

local maxSpd      = 0
local totalSpd    = 0
local movingF     = 0
local wsChanges   = {}
local cfTeleports = 0
local alvSpikes   = 0
local frames      = 0
local psChanges   = 0
local hrpNewInst  = {}

local lastWS  = hum.WalkSpeed
local lastPS  = hum.PlatformStand
local lastPos = hrp.Position
local lastVel = hrp.AssemblyLinearVelocity

local addConn = hrp.ChildAdded:Connect(function(v)
    table.insert(hrpNewInst, string.format("+[%s] %s  t=%.2f", v.ClassName, v.Name, tick() - t0))
end)
local remConn = hrp.ChildRemoved:Connect(function(v)
    table.insert(hrpNewInst, string.format("-[%s] %s  t=%.2f", v.ClassName, v.Name, tick() - t0))
end)

-- Boucle principale : Heartbeat:Wait() = compatible tous executors
while tick() - t0 < DURATION do
    RunService.Heartbeat:Wait()
    frames = frames + 1

    -- Vitesse XZ
    local vel = hrp.AssemblyLinearVelocity
    local spd = Vector3.new(vel.X, 0, vel.Z).Magnitude
    if spd > 1 then
        movingF   = movingF + 1
        totalSpd  = totalSpd + spd
        if spd > maxSpd then maxSpd = spd end
    end

    -- ALV spike = set direct (delta brutal en 1 frame)
    local dv = (vel - lastVel).Magnitude
    if dv > 8 then alvSpikes = alvSpikes + 1 end
    lastVel = vel

    -- CFrame téléport
    local pos   = hrp.Position
    local dp    = (pos - lastPos).Magnitude
    if dp > 4 then cfTeleports = cfTeleports + 1 end
    lastPos = pos

    -- WalkSpeed
    local ws = hum.WalkSpeed
    if ws ~= lastWS then
        table.insert(wsChanges, string.format("t=%.2f: %.1f -> %.1f", tick() - t0, lastWS, ws))
        lastWS = ws
    end

    -- PlatformStand
    local ps = hum.PlatformStand
    if ps ~= lastPS then psChanges = psChanges + 1; lastPS = ps end
end

addConn:Disconnect()
remConn:Disconnect()

-- Scan instances finales
local hrpInst  = {}
local charInst = {}
for _, v in ipairs(hrp:GetChildren()) do
    local info = string.format("[%s] %s", v.ClassName, v.Name)
    if v:IsA("BodyVelocity") then
        pcall(function() info = info .. string.format("  MaxForce=%s  Vel=%s", tostring(v.MaxForce), tostring(v.Velocity)) end)
    elseif v:IsA("LinearVelocity") then
        pcall(function() info = info .. string.format("  MaxForce=%s", tostring(v.MaxForce)) end)
    elseif v:IsA("VectorForce") or v:IsA("BodyForce") then
        pcall(function() info = info .. string.format("  Force=%s", tostring(v.Force)) end)
    end
    table.insert(hrpInst, info)
end
for _, v in ipairs(char:GetDescendants()) do
    if v:IsA("BodyMover") or v:IsA("Constraint") then
        table.insert(charInst, string.format("[%s] %s  in:%s", v.ClassName, v.Name, v.Parent.Name))
    end
end

-- Verdict
local methods = {}
local bvFound, lvFound, vfFound = false, false, false
for _, v in ipairs(hrp:GetChildren()) do
    if v:IsA("BodyVelocity")   then bvFound = true end
    if v:IsA("LinearVelocity") then lvFound = true end
    if v:IsA("VectorForce")    then vfFound = true end
end
for _, v in ipairs(char:GetDescendants()) do
    if v:IsA("BodyVelocity")   then bvFound = true end
    if v:IsA("LinearVelocity") then lvFound = true end
end
if bvFound                                        then table.insert(methods, "BodyVelocity") end
if lvFound                                        then table.insert(methods, "LinearVelocity") end
if vfFound                                        then table.insert(methods, "VectorForce") end
if #wsChanges > 0                                 then table.insert(methods, "WalkSpeed override") end
if cfTeleports > 2                                then table.insert(methods, "CFrame teleport") end
if psChanges > 0                                  then table.insert(methods, "PlatformStand trick") end
if alvSpikes > 10 and not bvFound and not lvFound then table.insert(methods, "AssemblyLinearVelocity direct") end

-- Affichage
local avg = movingF > 0 and (totalSpd / movingF) or 0
print("============ SpeedDiag v3 ============")
print("Frames capturées    : " .. frames)
print("Vitesse XZ max      : " .. string.format("%.1f", maxSpd) .. " studs/s")
print("Vitesse XZ moy      : " .. string.format("%.1f", avg)    .. " studs/s")
print("WalkSpeed init/fin  : " .. string.format("%.1f", hum.WalkSpeed))
print("WalkSpeed changes   : " .. #wsChanges)
for _, l in ipairs(wsChanges)  do print("  " .. l) end
print("CFrame teleports    : " .. cfTeleports)
print("ALV spikes directs  : " .. alvSpikes)
print("PlatformStand chg   : " .. psChanges)
print("--------------------------------------")
print("HRP instances finales (" .. #hrpInst .. ") :")
for _, l in ipairs(hrpInst)  do print("  " .. l) end
print("HRP instances runtime (" .. #hrpNewInst .. ") :")
for _, l in ipairs(hrpNewInst) do print("  " .. l) end
print("Movers/Constraints character (" .. #charInst .. ") :")
for _, l in ipairs(charInst) do print("  " .. l) end
print("--------------------------------------")
print("MÉTHODES DÉTECTÉES : " .. (#methods == 0 and "aucune / inconnu" or table.concat(methods, ", ")))
print("======================================")
