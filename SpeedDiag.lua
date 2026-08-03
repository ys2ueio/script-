-- ============================================================
--  SpeedDiag v2  |  Analyse exhaustive des méthodes de speed
--  Lance pendant que l'autre script tourne + que tu bouges
-- ============================================================
task.spawn(function()

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP         = Players.LocalPlayer
local char       = LP.Character
if not char then char = LP.CharacterAdded:Wait() end
local hum = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")
if not hum or not hrp then warn("[SpeedDiag] Humanoid/HRP introuvable"); return end

local DURATION = 8
warn("[SpeedDiag] Démarrage " .. DURATION .. "s — bouge maintenant")

-- ── Snapshot initial ─────────────────────────────────────────
local initWS  = hum.WalkSpeed
local initJP  = hum.JumpPower
local initHH  = hum.HipHeight
local initPS  = hum.PlatformStand

-- ── Compteurs / accumulateurs ────────────────────────────────
local frames        = 0
local movingFrames  = 0
local maxXZSpeed    = 0
local totalXZSpeed  = 0
local wsChanges     = 0
local lastWS        = initWS
local cfTeleports   = 0
local lastPos       = hrp.Position
local alvSpikes     = 0  -- AssemblyLinearVelocity sets directs détectés
local lastVel       = hrp.AssemblyLinearVelocity
local psChanges     = 0
local lastPS        = initPS
local hhChanges     = 0
local lastHH        = initHH
local jpChanges     = 0
local lastJP        = initJP
local bodyVelSeen   = {}
local linVelSeen    = {}
local vecForceSeen  = {}
local bodyForceSeen = {}
local alignPosSeen  = {}
local otherMoverSeen= {}
local hrpChildLog   = {}

-- ── Surveille ChildAdded/Removed sur HRP ────────────────────
local addConn = hrp.ChildAdded:Connect(function(v)
    local entry = string.format("[+%.2fs] %s '%s'", tick(), v.ClassName, v.Name)
    table.insert(hrpChildLog, entry)
end)
local remConn = hrp.ChildRemoved:Connect(function(v)
    local entry = string.format("[-%.2fs] %s '%s'", tick(), v.ClassName, v.Name)
    table.insert(hrpChildLog, entry)
end)

-- ── Boucle de sampling (Heartbeat) ──────────────────────────
local conn
local t0 = tick()
conn = RunService.Heartbeat:Connect(function()
    if tick() - t0 >= DURATION then
        conn:Disconnect()
        addConn:Disconnect()
        remConn:Disconnect()
        return
    end

    frames = frames + 1

    -- Vélocité XZ
    local vel = hrp.AssemblyLinearVelocity
    local xzSpd = Vector3.new(vel.X, 0, vel.Z).Magnitude
    if xzSpd > 1 then
        movingFrames  = movingFrames + 1
        totalXZSpeed  = totalXZSpeed + xzSpd
        if xzSpd > maxXZSpeed then maxXZSpeed = xzSpd end
    end

    -- Spike ALV (set direct : delta élevé en 1 frame sans force)
    local velDelta = (vel - lastVel).Magnitude
    if velDelta > 8 then alvSpikes = alvSpikes + 1 end
    lastVel = vel

    -- WalkSpeed polling
    local ws = hum.WalkSpeed
    if ws ~= lastWS then wsChanges = wsChanges + 1; lastWS = ws end

    -- JumpPower polling
    local jp = hum.JumpPower
    if jp ~= lastJP then jpChanges = jpChanges + 1; lastJP = jp end

    -- HipHeight polling (affecte hauteur = trick de hitbox/speed indirecte)
    local hh = hum.HipHeight
    if hh ~= lastHH then hhChanges = hhChanges + 1; lastHH = hh end

    -- PlatformStand polling (désactive la physique du Humanoid)
    local ps = hum.PlatformStand
    if ps ~= lastPS then psChanges = psChanges + 1; lastPS = ps end

    -- CFrame téléportation (delta position > 3 studs en 1 frame)
    local pos = hrp.Position
    local posDelta = (pos - lastPos).Magnitude
    if posDelta > 3 then cfTeleports = cfTeleports + 1 end
    lastPos = pos

    -- Scan instances HRP chaque 10 frames
    if frames % 10 == 0 then
        for _, v in ipairs(hrp:GetChildren()) do
            local cn = v.ClassName
            if cn == "BodyVelocity"   then bodyVelSeen[v]    = v end
            if cn == "LinearVelocity" then linVelSeen[v]     = v end
            if cn == "VectorForce"    then vecForceSeen[v]   = v end
            if cn == "BodyForce"      then bodyForceSeen[v]  = v end
            if cn == "AlignPosition"  then alignPosSeen[v]   = v end
            if v:IsA("BodyMover") or v:IsA("Constraint") then
                if cn ~= "BodyVelocity" and cn ~= "LinearVelocity"
                and cn ~= "VectorForce" and cn ~= "BodyForce"
                and cn ~= "AlignPosition" then
                    otherMoverSeen[cn] = true
                end
            end
        end
    end
end)

-- Attend fin de la boucle
task.wait(DURATION + 0.1)

-- ── Scan final character entier ──────────────────────────────
local charMoversFinal = {}
for _, v in ipairs(char:GetDescendants()) do
    if v:IsA("BodyMover") or v:IsA("Constraint") then
        table.insert(charMoversFinal, string.format("  [%s] '%s' dans %s", v.ClassName, v.Name, v.Parent.Name))
    end
end

local avgXZ = movingFrames > 0 and (totalXZSpeed / movingFrames) or 0

-- ── Rapport ──────────────────────────────────────────────────
local R = {}
local function r(s) table.insert(R, s) end

r("╔══════════════════════════════════════╗")
r("║        SpeedDiag v2 — RAPPORT       ║")
r("╚══════════════════════════════════════╝")
r(string.format("Frames capturées   : %d  (%.1fs)", frames, DURATION))
r(string.format("Vitesse XZ max     : %.1f studs/s", maxXZSpeed))
r(string.format("Vitesse XZ moy     : %.1f studs/s", avgXZ))
r("")
r("── Changements détectés ──")
r(string.format("WalkSpeed changes  : %d  (init=%.1f, final=%.1f)", wsChanges, initWS, hum.WalkSpeed))
r(string.format("JumpPower changes  : %d  (init=%.1f, final=%.1f)", jpChanges, initJP, hum.JumpPower))
r(string.format("HipHeight changes  : %d  (init=%.4f, final=%.4f)", hhChanges, initHH, hum.HipHeight))
r(string.format("PlatformStand chg  : %d  (init=%s, final=%s)", psChanges, tostring(initPS), tostring(hum.PlatformStand)))
r(string.format("CFrame teleports   : %d  (>3 studs/frame)", cfTeleports))
r(string.format("ALV spikes directs : %d  (delta >8 en 1 frame)", alvSpikes))
r("")
r("── Instances physiques dans HRP ──")
local found = false
if next(bodyVelSeen)    then r("  BodyVelocity      : OUI");  found = true end
if next(linVelSeen)     then r("  LinearVelocity    : OUI");  found = true
    for v in pairs(linVelSeen) do
        pcall(function() r(string.format("    MaxForce=%.0f  Mode=%s", v.MaxForce, tostring(v.VelocityConstraintMode))) end)
    end
end
if next(vecForceSeen)   then r("  VectorForce       : OUI");  found = true end
if next(bodyForceSeen)  then r("  BodyForce         : OUI");  found = true end
if next(alignPosSeen)   then r("  AlignPosition     : OUI");  found = true end
for cn in pairs(otherMoverSeen) do r("  Autre mover       : " .. cn); found = true end
if not found then r("  Aucune instance physique dans HRP") end

if #charMoversFinal > 0 then
    r("")
    r("── Movers/Constraints dans le character ──")
    for _, l in ipairs(charMoversFinal) do r(l) end
end

if #hrpChildLog > 0 then
    r("")
    r("── Instances créées/supprimées runtime ──")
    for _, l in ipairs(hrpChildLog) do r("  " .. l) end
else
    r("")
    r("── Runtime HRP : aucun ajout/suppression détecté")
end

r("")
r("══════════════════════════════════════")
r("  VERDICT")
r("══════════════════════════════════════")

local methods = {}
if next(bodyVelSeen)                           then table.insert(methods, "BodyVelocity (force legacy)") end
if next(linVelSeen)                            then table.insert(methods, "LinearVelocity (constraint)") end
if next(vecForceSeen)                          then table.insert(methods, "VectorForce") end
if next(bodyForceSeen)                         then table.insert(methods, "BodyForce") end
if next(alignPosSeen)                          then table.insert(methods, "AlignPosition") end
if wsChanges > 0                               then table.insert(methods, "WalkSpeed override") end
if cfTeleports > 2                             then table.insert(methods, "CFrame teleportation") end
if psChanges > 0                               then table.insert(methods, "PlatformStand trick") end
if alvSpikes > 10 and wsChanges == 0
   and not next(bodyVelSeen)
   and not next(linVelSeen)                    then table.insert(methods, "AssemblyLinearVelocity direct") end

if #methods == 0 then
    r("  Méthode non identifiée.")
    r("  → Soit le script n'était pas actif, soit méthode exotique.")
    r("  → Relance en bougeant activement pendant les 8s.")
else
    r("  Méthodes détectées :")
    for _, m in ipairs(methods) do r("  ✓ " .. m) end
end

r("══════════════════════════════════════")

-- Print ligne par ligne pour éviter les truncations executor
for _, line in ipairs(R) do warn(line) end

end) -- task.spawn
