-- Moon_Duel_v3.lua  |  VOID build  |  usage strictly private
if _G["_YS_MOONDUEL"] then _G["_YS_MOONDUEL"]() end
local _destroy = {}
_G["_YS_MOONDUEL"] = function()
    for _, f in ipairs(_destroy) do pcall(f) end
end
local function reg(f) table.insert(_destroy, f) end

-- ── services ─────────────────────────────────────────────────────────────────
local RS  = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local PL  = game:GetService("Players")
local LP  = PL.LocalPlayer

-- ── config ───────────────────────────────────────────────────────────────────
local CFG = {
    Speed       = 55,
    CarrySpeed  = 22,
    StealSpeed  = 30,
    LaggerSpd   = 10.1,
    LaggerCarry = 8,
    ClampFall   = 80,
    BatSpeed    = 40,
    BatVSpeed   = 52,
    BatTurn     = 285,
}

-- ── state ────────────────────────────────────────────────────────────────────
local speedOn   = true
local laggerOn  = false
local batOn     = false
local batPaused = false
local _stealing = false
local _proxy    = nil
local _proxyWeld= nil

-- ── palette ──────────────────────────────────────────────────────────────────
local function H(s) return Color3.fromHex(s) end
local BG    = H"060609"
local SURF  = H"0D0D14"
local ACC   = H"8B5CF6"
local HOT   = H"F43F5E"
local TEXT  = H"E2E2F0"
local DIM   = H"3D3D55"
local MUTED = H"6B6B8A"
local BORD  = H"1C1C2E"

-- ── dims ─────────────────────────────────────────────────────────────────────
local W      = 172
local COL_H  = 26
local PAD    = 8
local HDR_H  = 28
local FULL_H = HDR_H + 1 + PAD + COL_H * 5 + PAD  -- 175

-- ── Proxy-part speed (source: Ace Duels) ────────────────────────────────────
local function cleanProxy()
    if _proxy then pcall(function() _proxy:Destroy() end); _proxy = nil end
    _proxyWeld = nil
end
reg(cleanProxy)

local function ensureProxy(hrp)
    local char = hrp.Parent
    if _proxy and _proxy.Parent == char then return _proxy end
    cleanProxy()
    local p = Instance.new("Part")
    p.Name = "_MD_PX"; p.Size = Vector3.new(1,1,1)
    p.Transparency = 1; p.CanCollide = false; p.Massless = true
    p.Parent = char
    local w = Instance.new("Weld", p)
    w.Part0 = hrp; w.Part1 = p; w.C0 = CFrame.new()
    _proxyWeld = w; _proxy = p
    return p
end

-- ── anti-ragdoll ─────────────────────────────────────────────────────────────
local function antiRagdoll(char)
    local h = char and char:FindFirstChildOfClass("Humanoid"); if not h then return end
    h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    h.StateChanged:Connect(function(_, n)
        if n == Enum.HumanoidStateType.Ragdoll or n == Enum.HumanoidStateType.FallingDown then
            h:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end

-- ── Insta-reset (source: Ace Duels) ─────────────────────────────────────────
local _RESET_GUID   = "f888ee6e-c86d-46e1-93d7-0639d6635d42"
local _resetRemote  = nil
-- passive hookfunction: capture the RE/ remote as soon as the game fires it
pcall(function()
    if not (hookfunction and newcclosure) then return end
    local _oldFire
    _oldFire = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
        if not _resetRemote and typeof(self) == "Instance"
        and self:IsA("RemoteEvent") and self.Name:sub(1,3) == "RE/" then
            _resetRemote = self
        end
        return _oldFire(self, ...)
    end))
end)
local function instaReset()
    -- fallback scan if hook didn't capture it yet
    if not _resetRemote then
        for _, d in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if d:IsA("RemoteEvent") and d.Name:sub(1,3) == "RE/" then
                _resetRemote = d; break
            end
        end
    end
    if not _resetRemote then return end
    local char     = LP.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    -- already dead: single fire
    if humanoid and humanoid.Health <= 0 then
        pcall(function() _resetRemote:FireServer(_RESET_GUID, LP, "balloon") end)
        return
    end
    local resetDetected = false
    local resetConns    = {}
    if humanoid then
        table.insert(resetConns, humanoid.Died:Connect(function() resetDetected = true end))
        table.insert(resetConns, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if humanoid.Health <= 0 then resetDetected = true end
        end))
    end
    if char then
        table.insert(resetConns, char.AncestryChanged:Connect(function(_, parent)
            if not parent then resetDetected = true end
        end))
    end
    task.spawn(function()
        for _ = 1, 10 do
            if resetDetected then break end
            pcall(function() _resetRemote:FireServer(_RESET_GUID, LP, "balloon") end)
            task.wait(0.05)
        end
        for _, c in ipairs(resetConns) do pcall(function() c:Disconnect() end) end
    end)
end

-- ── Anti-kick (source: MoonHub v16) ─────────────────────────────────────────
local _akActive      = false
local _akOldNamecall = nil
local _akMt          = nil
local _akPosConn     = nil
local _akDeathConn   = nil
local _akHealthConn  = nil
local _akMaxHpConn   = nil
local _akLastSafe    = nil
local _akRemoteConns = {}
local _akCharOldNI   = nil
local _akCharMtRef   = nil
local _akLoopActive  = false
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
    _akHookChar(LP.Character)
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
    -- 3. Position safety + velocity clamp + immortality
    if _akPosConn then pcall(function() _akPosConn:Disconnect() end) end
    _akPosConn = RS.Heartbeat:Connect(function()
        local c2 = LP.Character;                          if not c2 then return end
        local r2 = c2:FindFirstChild("HumanoidRootPart"); if not r2 then return end
        local h2 = c2:FindFirstChildOfClass("Humanoid");  if not h2 then return end
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
    -- 4. Block suspicious RemoteEvents
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
    for _, c in ipairs(_akRemoteConns) do pcall(function() c:Disconnect() end) end
    _akRemoteConns = {}
    if _akCharMtRef and _akCharOldNI ~= nil then
        pcall(function()
            setreadonly(_akCharMtRef, false)
            _akCharMtRef.__newindex = _akCharOldNI
            setreadonly(_akCharMtRef, true)
        end)
        _akCharOldNI = nil; _akCharMtRef = nil
    end
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
reg(stopAntiKick)

-- ── GUI ──────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name            = "MoonDuelV3"
gui.ResetOnSpawn    = false
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
if protectgui then pcall(protectgui, gui) end
gui.Parent = (cloneref or function(s) return s end)(game:GetService("CoreGui"))
reg(function() pcall(function() gui:Destroy() end) end)

local frame = Instance.new("Frame", gui)
frame.Name             = "Hub"
frame.Size             = UDim2.new(0, W, 0, FULL_H)
frame.Position         = UDim2.new(0, 120, 0, 120)
frame.BackgroundColor3 = BG
frame.BorderSizePixel  = 0
do
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local s = Instance.new("UIStroke", frame)
    s.Color           = BORD
    s.Thickness       = 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

-- drag
do
    local drag, ox, oy = false, 0, 0
    frame.InputBegan:Connect(function(i)
        local t = i.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            drag = true
            ox = i.Position.X - frame.AbsolutePosition.X
            oy = i.Position.Y - frame.AbsolutePosition.Y
        end
    end)
    UIS.InputChanged:Connect(function(i)
        local t = i.UserInputType
        if drag and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
            frame.Position = UDim2.new(0, i.Position.X - ox, 0, i.Position.Y - oy)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        local t = i.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            drag = false
        end
    end)
end

-- header
local hdr = Instance.new("Frame", frame)
hdr.Size             = UDim2.new(1, 0, 0, HDR_H)
hdr.BackgroundColor3 = SURF
hdr.BorderSizePixel  = 0
Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 10)
local hdrCover = Instance.new("Frame", hdr)
hdrCover.Size             = UDim2.new(1, 0, 0, 10)
hdrCover.Position         = UDim2.new(0, 0, 1, -10)
hdrCover.BackgroundColor3 = SURF
hdrCover.BorderSizePixel  = 0

local adot = Instance.new("Frame", hdr)
adot.Size             = UDim2.new(0, 5, 0, 5)
adot.Position         = UDim2.new(0, 10, 0.5, -2.5)
adot.BackgroundColor3 = ACC
adot.BorderSizePixel  = 0
Instance.new("UICorner", adot).CornerRadius = UDim.new(1, 0)

local title = Instance.new("TextLabel", hdr)
title.Size               = UDim2.new(1, -46, 1, 0)
title.Position           = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text               = "MOON DUEL"
title.TextColor3         = TEXT
title.Font               = Enum.Font.GothamBold
title.TextSize           = 10
title.TextXAlignment     = Enum.TextXAlignment.Left

local xBtn = Instance.new("TextButton", hdr)
xBtn.Size                = UDim2.new(0, 22, 0, 22)
xBtn.Position            = UDim2.new(1, -26, 0.5, -11)
xBtn.BackgroundTransparency = 1
xBtn.Text                = "×"
xBtn.TextColor3          = DIM
xBtn.Font                = Enum.Font.GothamBold
xBtn.TextSize            = 14
xBtn.MouseButton1Click:Connect(function() _G["_YS_MOONDUEL"]() end)

local hdiv = Instance.new("Frame", frame)
hdiv.Size             = UDim2.new(1, -16, 0, 1)
hdiv.Position         = UDim2.new(0, 8, 0, HDR_H)
hdiv.BackgroundColor3 = BORD
hdiv.BorderSizePixel  = 0

-- row / widget builders
local ROW_Y0 = HDR_H + 1 + PAD
local function mkRow(i)
    local f = Instance.new("Frame", frame)
    f.Size                = UDim2.new(1, -PAD * 2, 0, COL_H)
    f.Position            = UDim2.new(0, PAD, 0, ROW_Y0 + i * COL_H)
    f.BackgroundTransparency = 1
    f.BorderSizePixel     = 0
    return f
end

local function mkLbl(p, txt, x, w)
    local l = Instance.new("TextLabel", p)
    l.Size               = UDim2.new(0, w, 1, 0)
    l.Position           = UDim2.new(0, x, 0, 0)
    l.BackgroundTransparency = 1
    l.Text               = txt
    l.TextColor3         = MUTED
    l.Font               = Enum.Font.Gotham
    l.TextSize           = 9
    l.TextXAlignment     = Enum.TextXAlignment.Left
end

local function mkDot(p, x, on, cb)
    local outer = Instance.new("Frame", p)
    outer.Size             = UDim2.new(0, 14, 0, 14)
    outer.Position         = UDim2.new(0, x, 0.5, -7)
    outer.BackgroundColor3 = BORD
    outer.BorderSizePixel  = 0
    Instance.new("UICorner", outer).CornerRadius = UDim.new(1, 0)
    local inner = Instance.new("Frame", outer)
    inner.Size             = UDim2.new(0, 8, 0, 8)
    inner.Position         = UDim2.new(0.5, -4, 0.5, -4)
    inner.BorderSizePixel  = 0
    Instance.new("UICorner", inner).CornerRadius = UDim.new(1, 0)
    local st = on
    local function rf()
        inner.BackgroundColor3 = st and ACC or DIM
        outer.BackgroundColor3 = st and H"18103A" or BORD
    end
    rf()
    local hit = Instance.new("TextButton", outer)
    hit.Size                = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text                = ""
    hit.MouseButton1Click:Connect(function()
        st = not st; rf(); if cb then cb(st) end
    end)
    return function(v) st = v; rf() end
end

local function mkIn(p, x, w, init, cb)
    local b = Instance.new("TextBox", p)
    b.Size              = UDim2.new(0, w, 0, 18)
    b.Position          = UDim2.new(0, x, 0.5, -9)
    b.BackgroundColor3  = SURF
    b.BorderSizePixel   = 0
    b.Text              = tostring(init)
    b.TextColor3        = TEXT
    b.PlaceholderColor3 = DIM
    b.Font              = Enum.Font.Gotham
    b.TextSize          = 10
    b.ClearTextOnFocus  = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    local s = Instance.new("UIStroke", b); s.Color = BORD; s.Thickness = 1
    b.Focused:Connect(function() s.Color = ACC end)
    b.FocusLost:Connect(function()
        s.Color = BORD
        local n = tonumber(b.Text)
        if n then cb(n) else b.Text = tostring(init) end
    end)
end

local function mkBtn(p, txt, cb)
    local b = Instance.new("TextButton", p)
    b.Size             = UDim2.new(1, 0, 0, 20)
    b.Position         = UDim2.new(0, 0, 0.5, -10)
    b.BackgroundColor3 = SURF
    b.BorderSizePixel  = 0
    b.Text             = txt
    b.TextColor3       = MUTED
    b.Font             = Enum.Font.Gotham
    b.TextSize         = 9
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    local s = Instance.new("UIStroke", b); s.Color = BORD; s.Thickness = 1
    b.MouseEnter:Connect(function() s.Color = HOT; b.TextColor3 = HOT end)
    b.MouseLeave:Connect(function() s.Color = BORD; b.TextColor3 = MUTED end)
    b.MouseButton1Click:Connect(cb)
end

-- ── rows ─────────────────────────────────────────────────────────────────────

-- 0: SPEED  [•]  [___55___]
local r0 = mkRow(0)
mkLbl(r0, "SPEED", 0, 42)
mkDot(r0, 42, speedOn,  function(on) speedOn  = on end)
mkIn (r0, 62, 92, CFG.Speed,      function(v)  CFG.Speed      = v end)

-- 1: STEAL       [___30___]
local r1 = mkRow(1)
mkLbl(r1, "STEAL", 0, 42)
mkIn (r1, 62, 92, CFG.StealSpeed, function(v)  CFG.StealSpeed = v end)

-- 2: LAGGER [•]
local r2 = mkRow(2)
mkLbl(r2, "LAGGER", 0, 50)
mkDot(r2, 50, laggerOn, function(on) laggerOn = on end)

-- 3: AUTO-BAT [•]
local r3 = mkRow(3)
mkLbl(r3, "AUTO-BAT", 0, 60)
mkDot(r3, 60, batOn, function(on)
    batOn = on
    if not on then return end
    task.spawn(function()
        while batOn do
            if not batPaused then
                local char = LP.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local bat
                    for _, t in ipairs(char:GetChildren()) do
                        if t:IsA("Tool") and t.Name:lower():find("bat") then
                            bat = t; break
                        end
                    end
                    local bP, bD = nil, math.huge
                    for _, pl in ipairs(PL:GetPlayers()) do
                        if pl ~= LP and pl.Character then
                            local eh = pl.Character:FindFirstChild("HumanoidRootPart")
                            if eh then
                                local d = (hrp.Position - eh.Position).Magnitude
                                if d < bD then bD = d; bP = eh end
                            end
                        end
                    end
                    if bat and bP and bD < 30 then
                        local dir = (bP.Position - hrp.Position).Unit
                        local xz  = Vector3.new(dir.X, 0, dir.Z)
                        if xz.Magnitude > 0.01 then
                            hrp.CFrame = hrp.CFrame:Lerp(
                                CFrame.new(hrp.Position, hrp.Position + xz),
                                math.rad(CFG.BatTurn) / math.pi
                            )
                        end
                        if bD < 6 then
                            bP.AssemblyLinearVelocity = dir * CFG.BatSpeed
                                + Vector3.new(0, CFG.BatVSpeed, 0)
                            bat:Activate()
                        end
                    end
                end
            end
            task.wait(0.05)
        end
    end)
end)

-- 4: INSTA RESET
local r4 = mkRow(4)
mkBtn(r4, "INSTA RESET", instaReset)

-- ── runtime loops ────────────────────────────────────────────────────────────

-- speed (proxy-move, source: Ace Duels)
local hbS = RS.RenderStepped:Connect(function()
    local char = LP.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then cleanProxy(); return end

    local ws = hum.WalkSpeed
    if not _stealing and ws < 20 then _stealing = true
    elseif _stealing and ws > 28  then _stealing = false end

    if not speedOn then return end

    local eff
    if _stealing then
        eff = CFG.StealSpeed
    elseif laggerOn then
        eff = (ws < 25) and CFG.LaggerCarry or CFG.LaggerSpd
    else
        eff = (ws < 25) and CFG.CarrySpeed or CFG.Speed
    end

    local md = hum.MoveDirection
    if md.Magnitude > 0.1 then
        local _n  = 1 + (math.random() - 0.5) * 0.04
        local _px = ensureProxy(hrp)
        _px.AssemblyLinearVelocity = Vector3.new(md.X * eff * _n, hrp.AssemblyLinearVelocity.Y, md.Z * eff * _n)
    end
end)
reg(function() hbS:Disconnect() end)

-- fall clamp
local hbF = RS.Heartbeat:Connect(function()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local v = hrp.AssemblyLinearVelocity
        if v.Y < -CFG.ClampFall then
            hrp.AssemblyLinearVelocity = Vector3.new(v.X, -CFG.ClampFall, v.Z)
        end
    end
end)
reg(function() hbF:Disconnect() end)

-- infinite jump
local hbJ = UIS.JumpRequest:Connect(function()
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
reg(function() hbJ:Disconnect() end)

-- screen-text watcher (pause bat during countdown)
local hbT = RS.Heartbeat:Connect(function()
    local pg = LP:FindFirstChildOfClass("PlayerGui"); if not pg then return end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") then
            local t = d.Text
            if t == "5" then batPaused = true
            elseif t == "1" then batPaused = false end
        end
    end
end)
reg(function() hbT:Disconnect() end)

-- character events
local function onChar(char)
    antiRagdoll(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
              or char:WaitForChild("HumanoidRootPart", 5)
    if hrp then ensureProxy(hrp) end
end
if LP.Character then task.spawn(onChar, LP.Character) end
local cc = LP.CharacterAdded:Connect(onChar)
reg(function() cc:Disconnect() end)
