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
local _lv, _lv_att

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

-- ── LV Plane speed ───────────────────────────────────────────────────────────
local function cleanLV()
    if _lv     then pcall(function() _lv:Destroy()     end); _lv     = nil end
    if _lv_att then pcall(function() _lv_att:Destroy() end); _lv_att = nil end
end
reg(cleanLV)

local function setupLV(hrp)
    cleanLV()
    local att = Instance.new("Attachment", hrp); att.Name = "_MD_A"
    local lv  = Instance.new("LinearVelocity", hrp); lv.Name = "_MD_LV"
    lv.Attachment0            = att
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
    lv.PrimaryTangentAxis     = Vector3.new(1, 0, 0)
    lv.SecondaryTangentAxis   = Vector3.new(0, 0, 1)
    lv.MaxForce               = math.huge
    lv.PlaneVelocity          = Vector2.zero
    lv.RelativeTo             = Enum.ActuatorRelativeTo.World
    _lv_att = att; _lv = lv
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

-- ── insta-reset ──────────────────────────────────────────────────────────────
local RKEY = "f888ee6e-c86d-46e1-93d7-0639d6635d42"
local function instaReset()
    local char = LP.Character; if not char then return end
    local tools = {}
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") then tools[#tools + 1] = t; t.Parent = LP.Backpack end
    end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("RemoteEvent") and d.Name == RKEY then d:FireServer(); break end
    end
    LP.Character = nil
    local c2; c2 = LP.CharacterAdded:Connect(function(nc)
        c2:Disconnect(); task.wait(0.3)
        for _, t in ipairs(tools) do
            if t.Parent == LP.Backpack then t.Parent = nc end
        end
    end)
    task.delay(4, function()
        for _, t in ipairs(tools) do
            if t.Parent == LP.Backpack then t.Parent = LP.Character or LP.Backpack end
        end
    end)
end

-- ── anti-kick (8 layers) ─────────────────────────────────────────────────────
local function setupAntiKick()
    local _nc
    _nc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if m == "Kick" then return end
        if m == "Shutdown" and self == game then return end
        return _nc(self, ...)
    end))
    local h1 = RS.Heartbeat:Connect(function()
        local c = LP.Character; local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then
            if h.MaxHealth ~= 100 then h.MaxHealth = 100 end
            if h.Health    <  100 then h.Health    = 100 end
        end
    end)
    reg(function() h1:Disconnect() end)
    local h2 = RS.Heartbeat:Connect(function()
        if LP.Character and LP.Character.Parent ~= workspace then
            LP.Character.Parent = workspace
        end
    end)
    reg(function() h2:Disconnect() end)
    local function bd(c)
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then h:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end
    end
    bd(LP.Character)
    local cc = LP.CharacterAdded:Connect(bd); reg(function() cc:Disconnect() end)
    task.spawn(function()
        local function scan()
            if not getgc then return end
            for _, v in ipairs(getgc(true)) do
                if type(v) == "function" and islclosure and islclosure(v)
                   and not (isexecutorclosure and isexecutorclosure(v)) then
                    local ok, ups = pcall(getupvalues, v)
                    if ok and ups then
                        for _, u in ipairs(ups) do
                            if type(u) == "function" then
                                pcall(hookfunction, u, newcclosure(function() end))
                            end
                        end
                    end
                end
            end
        end
        scan()
        while true do task.wait(30); scan() end
    end)
end
pcall(setupAntiKick)

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

-- speed (LV Plane)
local hbS = RS.Heartbeat:Connect(function()
    local char = LP.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then cleanLV(); return end
    if not _lv or not _lv.Parent then setupLV(hrp) end

    local ws = hum.WalkSpeed
    if not _stealing and ws < 20 then _stealing = true
    elseif _stealing and ws > 28  then _stealing = false end

    if not speedOn then _lv.PlaneVelocity = Vector2.zero; return end

    local eff
    if _stealing then
        eff = CFG.StealSpeed
    elseif laggerOn then
        eff = (ws < 25) and CFG.LaggerCarry or CFG.LaggerSpd
    else
        eff = (ws < 25) and CFG.CarrySpeed or CFG.Speed
    end

    local dir = hum.MoveDirection
    if dir.Magnitude > 0.1 then
        local f = Vector3.new(dir.X, 0, dir.Z).Unit
        _lv.PlaneVelocity = Vector2.new(f.X * eff, f.Z * eff)
    else
        _lv.PlaneVelocity = Vector2.zero
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
    if hrp then setupLV(hrp) end
end
if LP.Character then task.spawn(onChar, LP.Character) end
local cc = LP.CharacterAdded:Connect(onChar)
reg(function() cc:Disconnect() end)
