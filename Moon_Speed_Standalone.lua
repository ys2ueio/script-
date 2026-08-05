-- ============================================================
--  Moon Speed Standalone  |  strictly private & personal
--  Extracted from Moon_Duel_v3 — same engine, self-contained
-- ============================================================
if _G["_MS_STANDALONE"] then
    pcall(function() _G["_MS_STANDALONE"]:Destroy() end)
    _G["_MS_STANDALONE"] = nil
end

local cloneref   = cloneref or function(x) return x end
local Players    = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local TweenService = cloneref(game:GetService("TweenService"))
local UIS        = cloneref(game:GetService("UserInputService"))
local HttpService = cloneref(game:GetService("HttpService"))

local LP  = Players.LocalPlayer
local _NS = "_MS_"  -- namespace prefix for instances

-- ── Wait for character ───────────────────────────────────────
if not LP.Character then LP.CharacterAdded:Wait() end

-- ── Palette (Moon hub colours) ───────────────────────────────
local C_BG     = Color3.fromRGB(4,   6,  18)
local C_HEADER = Color3.fromRGB(8,  14,  38)
local C_ROW    = Color3.fromRGB(12, 20,  55)
local C_WHITE  = Color3.fromRGB(220,235, 255)
local C_MOON   = Color3.fromRGB(95, 160, 255)
local C_MOONTEXT = Color3.fromRGB(3,   8,  20)
local C_OFF_BG = Color3.fromRGB(4,   6,  18)
local C_SILVER = Color3.fromRGB(195,220, 255)
local C_DIM    = Color3.fromRGB(75, 105, 160)
local C_DEEP3  = Color3.fromRGB(45,  95, 210)
local C_DEEP4  = Color3.fromRGB(110,175, 255)

-- ── Living gradients ─────────────────────────────────────────
local _livingGradients = {}
local _purgeCounter    = 0
RunService.RenderStepped:Connect(function()
    _purgeCounter = _purgeCounter + 1
    if _purgeCounter >= 300 then
        _purgeCounter = 0
        local a = {}
        for _, g in ipairs(_livingGradients) do if g and g.Parent then a[#a+1]=g end end
        _livingGradients = a
    end
    for _, g in ipairs(_livingGradients) do
        if g and g.Parent then g.Rotation = (g.Rotation + 0.6) % 360 end
    end
end)

local function addCorner(inst, r)
    local c = Instance.new("UICorner", inst)
    c.CornerRadius = UDim.new(0, r or 8)
    return c
end
local function addLivingGrad(lbl)
    local g = Instance.new("UIGradient", lbl)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    C_DEEP4),
        ColorSequenceKeypoint.new(0.25, C_DEEP3),
        ColorSequenceKeypoint.new(0.5,  C_DEEP4),
        ColorSequenceKeypoint.new(0.75, C_DEEP3),
        ColorSequenceKeypoint.new(1,    C_DEEP4),
    })
    g.Rotation = 0; table.insert(_livingGradients, g); return g
end
local function addStroke(parent, thickness)
    local s = Instance.new("UIStroke", parent)
    s.Thickness = thickness or 1.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Color = C_DEEP3
    local g = Instance.new("UIGradient", s)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(4,6,18)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(12,25,70)),
        ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(4,6,18)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(12,25,70)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(4,6,18)),
    })
    table.insert(_livingGradients, g)
    return s
end

-- ═══════════════════════════════════════════════════
-- SPEED STATE
-- ═══════════════════════════════════════════════════
local State = {
    normalSpeed      = 60,
    carrySpeed       = 30,
    laggerSpeed      = 15,
    laggerCarrySpeed = 24.5,
    laggerActive     = false,
    autoCarryOnGrab  = true,
    _carryManualUntil = 0,
    speedType        = "normal",
}

local function updateCarryState()
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local isSteal = hum and hum.WalkSpeed < 25
    if State.autoCarryOnGrab and isSteal and State.speedType ~= "carry" then
        State.speedType = "carry"
    elseif State.autoCarryOnGrab and not isSteal and State.speedType == "carry"
        and tick() >= (State._carryManualUntil or 0) then
        State.speedType = "normal"
    end
end

local function getCurrentSpeed()
    local char  = LP.Character
    local hum   = char and char:FindFirstChildOfClass("Humanoid")
    local isSteal = hum and hum.WalkSpeed < 25
    if State.laggerActive then
        return isSteal and State.laggerCarrySpeed or State.laggerSpeed
    end
    return isSteal and State.carrySpeed or State.normalSpeed
end

-- ═══════════════════════════════════════════════════
-- MOVEMENT ENGINE  (Moon_Duel_v3 ace proxy method)
-- ═══════════════════════════════════════════════════
-- Proxy Part welded to HumanoidRootPart + AssemblyLinearVelocity,
-- exactly as in Moon. Network ownership claiming added on top to
-- cut server rollback / rubber-band.

local _boostActive   = false
local _aceProxy      = nil
local _aceProxyWeld  = nil
local _ownWatchConn  = nil
local _ownTimer      = 0
local _ownInterval   = 0.8 + math.random() * 0.4

local function _claimOwn(hrp)
    pcall(function() hrp:SetNetworkOwner(LP) end)
end

local function _watchOwn(hrp)
    if _ownWatchConn then pcall(function() _ownWatchConn:Disconnect() end) end
    _ownWatchConn = hrp:GetPropertyChangedSignal("ReceiveAge"):Connect(function()
        if _boostActive then task.defer(function() _claimOwn(hrp) end) end
    end)
end

local function cleanProxy()
    if _ownWatchConn then pcall(function() _ownWatchConn:Disconnect() end); _ownWatchConn = nil end
    if _aceProxy then pcall(function() _aceProxy:Destroy() end); _aceProxy = nil end
    _aceProxyWeld = nil
end

local function ensureProxy(hrp)
    local char = hrp.Parent
    if _aceProxy and _aceProxy.Parent == char then return _aceProxy end
    cleanProxy()
    local p = Instance.new("Part")
    p.Name = _NS .. "PX"; p.Size = Vector3.new(1,1,1)
    p.Transparency = 1; p.CanCollide = false; p.Massless = true
    p.Parent = char
    local w = Instance.new("Weld", p)
    w.Part0 = hrp; w.Part1 = p; w.C0 = CFrame.new()
    _aceProxyWeld = w; _aceProxy = p
    _claimOwn(hrp)
    _watchOwn(hrp)
    return p
end

local function stopBoost()
    _boostActive = false
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum:Move(Vector3.zero, false) end
    if _aceProxy then pcall(function() _aceProxy.AssemblyLinearVelocity = Vector3.zero end) end
    cleanProxy()
    State.laggerActive = false
    State.speedType = "normal"
end

-- RenderStepped loop — identical to Moon_Duel_v3
RunService.RenderStepped:Connect(function(dt)
    if not _boostActive then cleanProxy(); return end
    local char = LP.Character; if not char then cleanProxy(); return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then cleanProxy(); return end
    local state = hum:GetState()
    if hum.PlatformStand
        or state == Enum.HumanoidStateType.Physics
        or state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.FallingDown then
        cleanProxy(); return
    end
    -- Periodic ownership re-claim (belt-and-braces alongside ReceiveAge watcher)
    _ownTimer = _ownTimer + dt
    if _ownTimer >= _ownInterval then
        _claimOwn(hrp); _ownTimer = 0; _ownInterval = 0.8 + math.random() * 0.4
    end
    updateCarryState()
    local md  = hum.MoveDirection
    local spd = getCurrentSpeed()
    if md.Magnitude > 0 then
        local _n = 1 + (math.random() - 0.5) * 0.04
        local px = ensureProxy(hrp)
        px.AssemblyLinearVelocity = Vector3.new(
            md.X * spd * _n,
            hrp.AssemblyLinearVelocity.Y,
            md.Z * spd * _n
        )
    end
end)

-- Clean proxy on respawn
LP.CharacterAdded:Connect(function(char)
    cleanProxy()
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then hum.WalkSpeed = getCurrentSpeed() end
    if _boostActive then
        task.delay(0.3, function()
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp and _boostActive then _claimOwn(hrp); _watchOwn(hrp) end
        end)
    end
end)

-- ═══════════════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = _NS .. tostring(math.random(0x10000, 0xFFFFF))
gui.ResetOnSpawn = false; gui.DisplayOrder = 10
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() if protectgui then protectgui(gui) end end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
    gui.Parent = LP:WaitForChild("PlayerGui")
end
_G["_MS_STANDALONE"] = gui

-- ── Drag helper ──────────────────────────────────────────────
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = frame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then dragInput = inp end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and dragInput and inp == dragInput then
            local d = inp.Position - dragStart
            local cam = workspace.CurrentCamera
            local vp  = cam and cam.ViewportSize or Vector2.new(1,1)
            local abs = frame.AbsoluteSize
            local nx  = startPos.X.Offset + d.X
            local ny  = startPos.Y.Offset + d.Y
            nx = math.clamp(nx, 0, math.max(0, vp.X - abs.X))
            ny = math.clamp(ny, 0, math.max(0, vp.Y - abs.Y))
            frame.Position = UDim2.new(0, nx, 0, ny)
        end
    end)
end

-- ── Main widget ──────────────────────────────────────────────
local FULL_H = 168
local COLL_H = 64

local spW = Instance.new("Frame", gui)
spW.Name = "MoonSpeedWidget"
spW.Size = UDim2.new(0, 150, 0, FULL_H)
spW.Position = UDim2.new(0, 20, 0.20, 0)
spW.BackgroundColor3 = C_BG
spW.BorderSizePixel = 0; spW.ClipsDescendants = true; spW.Active = true
addCorner(spW, 12); addStroke(spW, 1.5)

-- Header
local spH = Instance.new("Frame", spW)
spH.Size = UDim2.new(1,0,0,26)
spH.BackgroundColor3 = C_HEADER; spH.BorderSizePixel = 0
addCorner(spH, 12)
makeDraggable(spW, spH)

local spDot = Instance.new("Frame", spH)
spDot.Size = UDim2.new(0,5,0,5); spDot.Position = UDim2.new(0,10,0,11)
spDot.BackgroundColor3 = C_MOON; spDot.BorderSizePixel = 0; addCorner(spDot, 3)

local spTitle = Instance.new("TextLabel", spH)
spTitle.Size = UDim2.new(1,-46,1,0); spTitle.Position = UDim2.new(0,18,0,0)
spTitle.BackgroundTransparency = 1; spTitle.Text = "SPEED BYPASS"
spTitle.TextColor3 = C_WHITE; spTitle.Font = Enum.Font.GothamBlack
spTitle.TextSize = 9; spTitle.TextXAlignment = Enum.TextXAlignment.Left
addLivingGrad(spTitle)

local spMinBtn = Instance.new("TextButton", spH)
spMinBtn.Size = UDim2.new(0,18,0,18); spMinBtn.Position = UDim2.new(1,-24,0.5,-9)
spMinBtn.BackgroundColor3 = Color3.fromRGB(30,30,34); spMinBtn.BorderSizePixel = 0
spMinBtn.Text = "-"; spMinBtn.TextColor3 = C_WHITE
spMinBtn.Font = Enum.Font.GothamBlack; spMinBtn.TextSize = 15
addCorner(spMinBtn, 6); addStroke(spMinBtn, 1)

-- NORMAL / LAGGER tabs
local tabRow = Instance.new("Frame", spW)
tabRow.Size = UDim2.new(1,-16,0,26); tabRow.Position = UDim2.new(0,8,0,32)
tabRow.BackgroundColor3 = C_ROW; tabRow.BackgroundTransparency = 0.35
tabRow.BorderSizePixel = 0; addCorner(tabRow, 8); addStroke(tabRow, 1)
local tabLL = Instance.new("UIListLayout", tabRow)
tabLL.FillDirection = Enum.FillDirection.Horizontal
tabLL.SortOrder = Enum.SortOrder.LayoutOrder
tabLL.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function mkTab(lbl, ord, active)
    local t = Instance.new("TextButton", tabRow)
    t.Size = UDim2.new(0.5,0,1,0); t.LayoutOrder = ord
    t.BorderSizePixel = 0
    t.BackgroundColor3 = active and C_MOON or C_OFF_BG
    t.BackgroundTransparency = active and 0.15 or 0.5
    t.Text = lbl; t.TextColor3 = active and C_MOONTEXT or C_DIM
    t.Font = Enum.Font.GothamBold; t.TextSize = 10; t.AutoButtonColor = false
    addCorner(t, 6); addLivingGrad(t); return t
end
local tabN = mkTab("NORMAL", 1, true)
local tabL = mkTab("LAGGER", 2, false)

-- Status row
local stRow = Instance.new("Frame", spW)
stRow.Size = UDim2.new(1,-16,0,26); stRow.Position = UDim2.new(0,8,0,64)
stRow.BackgroundColor3 = C_ROW; stRow.BackgroundTransparency = 0.35
stRow.BorderSizePixel = 0; addCorner(stRow, 8); addStroke(stRow, 1)

local stLbl = Instance.new("TextLabel", stRow)
stLbl.Size = UDim2.new(0.5,0,1,0); stLbl.Position = UDim2.new(0,12,0,0)
stLbl.BackgroundTransparency = 1; stLbl.Text = "Status:"
stLbl.TextColor3 = C_WHITE; stLbl.Font = Enum.Font.GothamBold; stLbl.TextSize = 11
stLbl.TextXAlignment = Enum.TextXAlignment.Left; addLivingGrad(stLbl)

local stPill = Instance.new("Frame", stRow)
stPill.Size = UDim2.new(0.44,0,0,22); stPill.Position = UDim2.new(0.54,0,0.5,-11)
stPill.BackgroundColor3 = C_OFF_BG; stPill.BorderSizePixel = 0
addCorner(stPill, 6); addStroke(stPill, 1)

local stPillLbl = Instance.new("TextLabel", stPill)
stPillLbl.Size = UDim2.new(1,0,1,0); stPillLbl.BackgroundTransparency = 1
stPillLbl.Text = "OFF"; stPillLbl.TextColor3 = C_DIM
stPillLbl.Font = Enum.Font.GothamBlack; stPillLbl.TextSize = 11
addLivingGrad(stPillLbl)

local stClk = Instance.new("TextButton", stRow)
stClk.Size = UDim2.new(1,0,1,0); stClk.BackgroundTransparency = 1; stClk.Text = ""

-- Input builder
local function mkInput(parent, yPos, lbl, val, cb)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,-16,0,28); row.Position = UDim2.new(0,8,0,yPos)
    row.BackgroundColor3 = C_ROW; row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0; addCorner(row, 8); addStroke(row, 1)
    local l = Instance.new("TextLabel", row)
    l.Size = UDim2.new(1,-80,1,0); l.Position = UDim2.new(0,12,0,0)
    l.BackgroundTransparency = 1; l.Text = lbl; l.TextColor3 = C_WHITE
    l.Font = Enum.Font.GothamBold; l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left; addLivingGrad(l)
    local bw = Instance.new("Frame", row)
    bw.Size = UDim2.new(0,62,0,22); bw.Position = UDim2.new(1,-70,0.5,-11)
    bw.BackgroundColor3 = C_OFF_BG; bw.BackgroundTransparency = 0.1
    bw.BorderSizePixel = 0; addCorner(bw, 6); addStroke(bw, 1)
    local box = Instance.new("TextBox", bw)
    box.Size = UDim2.new(1,-6,1,0); box.Position = UDim2.new(0,3,0,0)
    box.BackgroundTransparency = 1; box.Text = tostring(val)
    box.TextColor3 = C_SILVER; box.Font = Enum.Font.GothamBold; box.TextSize = 12
    box.ClearTextOnFocus = false; box.TextXAlignment = Enum.TextXAlignment.Center
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n and n > 0 and n <= 500 then cb(n) else box.Text = tostring(val) end
    end)
    return box
end

-- Normal panel
local spNorm = Instance.new("Frame", spW)
spNorm.Size = UDim2.new(1,0,0,76); spNorm.Position = UDim2.new(0,0,0,96)
spNorm.BackgroundTransparency = 1; spNorm.BorderSizePixel = 0
mkInput(spNorm, 0,  "Speed",     State.normalSpeed, function(n) State.normalSpeed = n end)
mkInput(spNorm, 40, "Steal Spd", State.carrySpeed,  function(n) State.carrySpeed  = n end)

-- Lagger panel
local spLag = Instance.new("Frame", spW)
spLag.Size = UDim2.new(1,0,0,76); spLag.Position = UDim2.new(0,0,0,96)
spLag.BackgroundTransparency = 1; spLag.BorderSizePixel = 0; spLag.Visible = false
mkInput(spLag, 0,  "Lagger",    State.laggerSpeed,     function(n) State.laggerSpeed     = n end)
mkInput(spLag, 40, "Lag Steal", State.laggerCarrySpeed, function(n) State.laggerCarrySpeed = n end)

-- ── Toggle / tab logic ───────────────────────────────────────
local _isLagger  = false
local _isActive  = false
local _collapsed = false

local function applyPill(on)
    stPill.BackgroundColor3 = on and C_MOON or C_OFF_BG
    stPillLbl.Text          = on and "ON"   or "OFF"
    stPillLbl.TextColor3    = on and C_MOONTEXT or C_DIM
end

local function startBoost()
    _boostActive = true
    State.laggerActive = _isLagger
    State.speedType    = "normal"
    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then _claimOwn(hrp); _watchOwn(hrp) end
end

local function toggleBoost()
    _isActive = not _isActive
    applyPill(_isActive)
    if _isActive then startBoost() else stopBoost() end
end

local function switchTab(lag)
    _isLagger = lag
    tabN.BackgroundColor3 = lag and C_OFF_BG or C_MOON
    tabN.BackgroundTransparency = lag and 0.5 or 0.15
    tabN.TextColor3 = lag and C_DIM or C_MOONTEXT
    tabL.BackgroundColor3 = lag and C_MOON or C_OFF_BG
    tabL.BackgroundTransparency = lag and 0.15 or 0.5
    tabL.TextColor3 = lag and C_MOONTEXT or C_DIM
    spNorm.Visible = not lag; spLag.Visible = lag and not _collapsed or false
    if _isActive then
        State.laggerActive = lag
    end
end

stClk.MouseButton1Click:Connect(toggleBoost)
tabN.MouseButton1Click:Connect(function() switchTab(false) end)
tabL.MouseButton1Click:Connect(function() switchTab(true)  end)

spMinBtn.MouseButton1Click:Connect(function()
    _collapsed = not _collapsed
    spW.Size = UDim2.new(0, 150, 0, _collapsed and COLL_H or FULL_H)
    spMinBtn.Text = _collapsed and "+" or "-"
    stRow.Visible = not _collapsed
    if _collapsed then
        spNorm.Visible = false; spLag.Visible = false
    else
        spNorm.Visible = not _isLagger; spLag.Visible = _isLagger
    end
end)
