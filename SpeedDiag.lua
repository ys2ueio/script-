-- ============================================================
--  SpeedDiag  |  Analyse la méthode de speed d'un script tiers
--  Durée : 8 secondes de surveillance, puis rapport complet
-- ============================================================
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP         = Players.LocalPlayer
local char       = LP.Character or LP.CharacterAdded:Wait()
local hum        = char:FindFirstChildOfClass("Humanoid")
local hrp        = char:FindFirstChild("HumanoidRootPart")

local OUT = {}
local function log(s) table.insert(OUT, s) end
local function fmt(v) return string.format("%.4f", v) end

-- ── 1. Snapshot initial ──────────────────────────────────────
log("=== SpeedDiag START ===")
log("WalkSpeed initial : " .. tostring(hum.WalkSpeed))
log("JumpPower initial : " .. tostring(hum.JumpPower))
log("UseJumpPower      : " .. tostring(hum.UseJumpPower))

-- ── 2. Enfants HRP (instances physiques) ────────────────────
log("\n-- HRP children --")
for _, v in ipairs(hrp:GetChildren()) do
    log(string.format("  [%s] %s", v.ClassName, v.Name))
    if v:IsA("BodyVelocity") then
        log(string.format("    MaxForce=%s  Velocity=%s", tostring(v.MaxForce), tostring(v.Velocity)))
    elseif v:IsA("LinearVelocity") then
        log(string.format("    MaxForce=%s  VectorVelocity=%s", tostring(v.MaxForce), tostring(v.VectorVelocity)))
    elseif v:IsA("VectorForce") or v:IsA("BodyForce") then
        log(string.format("    Force=%s", tostring(v.Force)))
    elseif v:IsA("AlignPosition") then
        log(string.format("    MaxForce=%s  MaxVelocity=%s", tostring(v.MaxForce), tostring(v.MaxVelocity)))
    elseif v:IsA("Attachment") then
        log(string.format("    (attachment present)"))
    end
end

-- Contraintes sur le character entier
log("\n-- Constraints in character --")
for _, v in ipairs(char:GetDescendants()) do
    if v:IsA("Constraint") or v:IsA("BodyMover") then
        log(string.format("  [%s] %s  parent=%s", v.ClassName, v.Name, v.Parent.Name))
    end
end

-- ── 3. Surveillance sur 8 secondes ──────────────────────────
local samples        = {}
local wsChanges      = {}
local cframeChanges  = 0
local velChanges     = 0
local lastWS         = hum.WalkSpeed
local lastCF         = hrp.CFrame
local lastVel        = hrp.AssemblyLinearVelocity
local hrpChildAdded  = {}
local hrpChildRemoved= {}

-- Détecte ajout/suppression d'instances dans HRP pendant l'exécution
local addConn = hrp.ChildAdded:Connect(function(v)
    table.insert(hrpChildAdded, string.format("[+] %s '%s'", v.ClassName, v.Name))
end)
local remConn = hrp.ChildRemoved:Connect(function(v)
    table.insert(hrpChildRemoved, string.format("[-] %s '%s'", v.ClassName, v.Name))
end)

-- Détecte changements WalkSpeed
local wsConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
    local ws = hum.WalkSpeed
    if ws ~= lastWS then
        table.insert(wsChanges, string.format("  WS %s -> %s", fmt(lastWS), fmt(ws)))
        lastWS = ws
    end
end)

-- Heartbeat : échantillonne vélocité + CFrame
local t0   = tick()
local hbConn = RunService.Heartbeat:Connect(function()
    local now = tick() - t0
    local vel = hrp.AssemblyLinearVelocity
    local cf  = hrp.CFrame
    local spd = Vector3.new(vel.X, 0, vel.Z).Magnitude

    -- Détecte si CFrame a été téléporté (delta > 2 studs en 1 frame)
    local cfDelta = (cf.Position - lastCF.Position).Magnitude
    if cfDelta > 2 then cframeChanges = cframeChanges + 1 end

    -- Détecte si AssemblyLinearVelocity change brutalement (set direct)
    local velDelta = (vel - lastVel).Magnitude
    if velDelta > 10 then velChanges = velChanges + 1 end

    table.insert(samples, { t = now, spd = spd, ws = hum.WalkSpeed, vy = vel.Y })
    lastCF  = cf
    lastVel = vel
end)

-- Attend 8 secondes
task.wait(8)

-- Déconnecte tout
hbConn:Disconnect(); wsConn:Disconnect(); addConn:Disconnect(); remConn:Disconnect()

-- ── 4. Analyse des samples ───────────────────────────────────
local maxSpd, totalSpd, moving = 0, 0, 0
for _, s in ipairs(samples) do
    if s.spd > 2 then
        moving   = moving + 1
        totalSpd = totalSpd + s.spd
        if s.spd > maxSpd then maxSpd = s.spd end
    end
end
local avgSpd = moving > 0 and (totalSpd / moving) or 0

-- ── 5. HRP children à la fin ─────────────────────────────────
log("\n-- HRP children END --")
for _, v in ipairs(hrp:GetChildren()) do
    log(string.format("  [%s] %s", v.ClassName, v.Name))
    if v:IsA("BodyVelocity") then
        log(string.format("    MaxForce=%s  Velocity=%s", tostring(v.MaxForce), tostring(v.Velocity)))
    elseif v:IsA("LinearVelocity") then
        log(string.format("    MaxForce=%s  VectorVelocity=%s", tostring(v.MaxForce), tostring(v.VectorVelocity)))
    end
end

-- ── 6. Rapport final ─────────────────────────────────────────
log("\n=== RAPPORT (8s) ===")
log("Vitesse XZ max    : " .. fmt(maxSpd) .. " studs/s")
log("Vitesse XZ moy    : " .. fmt(avgSpd) .. " studs/s")
log("WalkSpeed final   : " .. tostring(hum.WalkSpeed))
log("CFrame teleports  : " .. tostring(cframeChanges) .. "x  (>2 studs/frame)")
log("ALV spikes        : " .. tostring(velChanges)    .. "x  (delta >10 direct set)")

if #wsChanges == 0 then
    log("WalkSpeed changes : aucun  → WalkSpeed jamais modifié")
else
    log("WalkSpeed changes : " .. #wsChanges .. "x")
    for _, l in ipairs(wsChanges) do log(l) end
end

if #hrpChildAdded > 0 then
    log("\nInstances créées dans HRP :")
    for _, l in ipairs(hrpChildAdded) do log("  " .. l) end
else
    log("\nAucune instance créée dans HRP  → pas de BodyVelocity/LinearVelocity runtime")
end
if #hrpChildRemoved > 0 then
    log("Instances supprimées de HRP :")
    for _, l in ipairs(hrpChildRemoved) do log("  " .. l) end
end

-- ── 7. Verdict ───────────────────────────────────────────────
log("\n=== VERDICT ===")
local bodyVelPresent = false
local linVelPresent  = false
for _, v in ipairs(hrp:GetChildren()) do
    if v:IsA("BodyVelocity")  then bodyVelPresent = true end
    if v:IsA("LinearVelocity") then linVelPresent  = true end
end

if bodyVelPresent then
    log("METHOD : BodyVelocity (legacy force-based)")
elseif linVelPresent then
    log("METHOD : LinearVelocity (constraint, new API)")
elseif cframeChanges > 5 then
    log("METHOD : CFrame direct (teleportation)")
elseif #wsChanges > 0 and velChanges < 5 then
    log("METHOD : WalkSpeed override uniquement")
elseif velChanges > 20 and #wsChanges == 0 then
    log("METHOD : AssemblyLinearVelocity direct (set chaque frame, WalkSpeed intact)")
elseif #wsChanges > 0 and velChanges > 20 then
    log("METHOD : WalkSpeed + AssemblyLinearVelocity combinés")
else
    log("METHOD : indéterminée — lance le script pendant que tu bouges")
end

-- ── 8. Print ─────────────────────────────────────────────────
print(table.concat(OUT, "\n"))
