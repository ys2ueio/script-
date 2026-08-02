-- ============================================================
--  Yslem Speed — MoonHub UI  |  usage strictement privé
-- ============================================================
if _G["_YS_SPEED"] then
    pcall(function() _G["_YS_SPEED"]:Destroy() end)
    _G["_YS_SPEED"] = nil
end

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

-- ── Palette MoonHub ─────────────────────────────────────────
local C_BG     = Color3.fromRGB(0,0,0)
local C_ROW    = Color3.fromRGB(0,0,0)
local C_WHITE  = Color3.fromRGB(255,255,255)
local C_MOON   = Color3.fromRGB(90,160,255)
local C_MOON2  = Color3.fromRGB(160,200,255)
local C_ON_BG  = Color3.fromRGB(20,45,80)
local C_OFF_BG = Color3.fromRGB(0,0,0)
local C_SILVER2= Color3.fromRGB(140,165,210)
local C_DIM    = Color3.fromRGB(110,120,140)
local C_DEEP1  = Color3.fromRGB(4,7,16)
local C_DEEP2  = Color3.fromRGB(14,28,58)
local C_DEEP3  = Color3.fromRGB(40,80,165)
local C_DEEP4  = Color3.fromRGB(90,150,255)

-- ── Living gradients (identiques MoonHub) ───────────────────
local _livingGradients = {}
local _livingStrokes   = {}
local _purgeCounter    = 0

RunService.RenderStepped:Connect(function()
    _purgeCounter = _purgeCounter + 1
    if _purgeCounter >= 300 then
        _purgeCounter = 0
        local a, b = {}, {}
        for _, g in ipairs(_livingGradients) do if g and g.Parent then a[#a+1]=g end end
        for _, g in ipairs(_livingStrokes)   do if g and g.Parent then b[#b+1]=g end end
        _livingGradients = a; _livingStrokes = b
    end
    for _, g in ipairs(_livingGradients) do if g and g.Parent then g.Rotation=(g.Rotation+0.6)%360 end end
    for _, g in ipairs(_livingStrokes)   do if g and g.Parent then g.Rotation=(g.Rotation+0.6)%360 end end
end)

local function addCorner(inst, r)
    local c = Instance.new("UICorner", inst)
    c.CornerRadius = UDim.new(0, r or 8)
    return c
end

local function addLivingTextGradient(lbl)
    local g = Instance.new("UIGradient", lbl)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    C_DEEP4),
        ColorSequenceKeypoint.new(0.25, C_DEEP3),
        ColorSequenceKeypoint.new(0.5,  C_DEEP4),
        ColorSequenceKeypoint.new(0.75, C_DEEP3),
        ColorSequenceKeypoint.new(1,    C_DEEP4),
    })
    g.Rotation = 0
    table.insert(_livingGradients, g)
    return g
end

local function addLivingStroke(parent, thickness)
    local stroke = Instance.new("UIStroke", parent)
    stroke.Thickness = thickness or 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = C_DEEP3
    local g = Instance.new("UIGradient", stroke)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    C_DEEP1),
        ColorSequenceKeypoint.new(0.25, C_DEEP2),
        ColorSequenceKeypoint.new(0.5,  C_DEEP1),
        ColorSequenceKeypoint.new(0.75, C_DEEP2),
        ColorSequenceKeypoint.new(1,    C_DEEP1),
    })
    table.insert(_livingStrokes, g)
    return stroke
end

-- ── ScreenGui ───────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "YslemSpeed"; gui.ResetOnSpawn = false
gui.DisplayOrder = 10; gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
    gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end
_G["_YS_SPEED"] = gui

-- ── Fenêtre principale ──────────────────────────────────────
local WIN_W, WIN_H = 280, 252
local TITLE_H      = 34

local mainOuter = Instance.new("Frame", gui)
mainOuter.Name = "Main"; mainOuter.Size = UDim2.new(0,WIN_W,0,WIN_H)
mainOuter.Position = UDim2.new(0.5,-WIN_W/2,0.5,-WIN_H/2)
mainOuter.BackgroundTransparency = 1; mainOuter.BorderSizePixel = 0
mainOuter.ClipsDescendants = true; mainOuter.Active = true
addCorner(mainOuter, 18)

local bgFill = Instance.new("Frame", mainOuter)
bgFill.Size = UDim2.new(1,0,1,0); bgFill.BackgroundColor3 = C_BG
bgFill.BorderSizePixel = 0; bgFill.ZIndex = 0
addCorner(bgFill, 18)
addLivingStroke(mainOuter, 2)

-- drag
local _dragging, _dragInput, _dragStart, _startPos = false, nil, nil, nil
mainOuter.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        _dragging = true; _dragStart = inp.Position; _startPos = mainOuter.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then _dragging = false end
        end)
    end
end)
mainOuter.InputChanged:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then _dragInput = inp end
end)
game:GetService("UserInputService").InputChanged:Connect(function(inp)
    if _dragging and _dragInput and inp == _dragInput then
        local delta = inp.Position - _dragStart
        mainOuter.Position = UDim2.new(
            _startPos.X.Scale, _startPos.X.Offset + delta.X,
            _startPos.Y.Scale, _startPos.Y.Offset + delta.Y
        )
    end
end)

-- ── Title bar ───────────────────────────────────────────────
local titleBar = Instance.new("Frame", mainOuter)
titleBar.Size = UDim2.new(1,0,0,TITLE_H); titleBar.BackgroundTransparency = 1
titleBar.BorderSizePixel = 0; titleBar.ZIndex = 5

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(0,200,0,20); titleLbl.Position = UDim2.new(0,14,0,7)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "SPEED — YSLEM"
titleLbl.TextColor3 = C_WHITE; titleLbl.Font = Enum.Font.GothamBlack; titleLbl.TextSize = 11
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.ZIndex = 6
addLivingTextGradient(titleLbl)

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0,22,0,22); closeBtn.Position = UDim2.new(1,-30,0.5,-11)
closeBtn.BackgroundColor3 = C_BG; closeBtn.BorderSizePixel = 0
closeBtn.Text = "−"; closeBtn.TextColor3 = C_WHITE; closeBtn.Font = Enum.Font.GothamBlack; closeBtn.TextSize = 16
closeBtn.ZIndex = 7; addCorner(closeBtn, 8); addLivingStroke(closeBtn, 1)
closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn,TweenInfo.new(0.1),{TextColor3=C_MOON2}):Play() end)
closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn,TweenInfo.new(0.1),{TextColor3=C_WHITE}):Play() end)
closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(mainOuter,TweenInfo.new(0.2),{Size=UDim2.new(0,WIN_W,0,0)}):Play()
    task.delay(0.22, function() pcall(function() gui:Destroy() end) end)
end)

local titleDiv = Instance.new("Frame", mainOuter)
titleDiv.Size = UDim2.new(1,0,0,1); titleDiv.Position = UDim2.new(0,0,0,TITLE_H)
titleDiv.BackgroundColor3 = Color3.fromRGB(40,46,58); titleDiv.BorderSizePixel = 0; titleDiv.ZIndex = 5

-- ── Content scroll ──────────────────────────────────────────
local scroll = Instance.new("ScrollingFrame", mainOuter)
scroll.Size = UDim2.new(1,0,1,-(TITLE_H+1)); scroll.Position = UDim2.new(0,0,0,TITLE_H+1)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3; scroll.ScrollBarImageColor3 = C_MOON
scroll.ScrollBarImageTransparency = 0.4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.ZIndex = 3

local ll = Instance.new("UIListLayout", scroll)
ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0,6)
local pad = Instance.new("UIPadding", scroll)
pad.PaddingLeft = UDim.new(0,12); pad.PaddingRight = UDim.new(0,12)
pad.PaddingTop = UDim.new(0,8); pad.PaddingBottom = UDim.new(0,12)

-- ── Row builders (identiques MoonHub) ───────────────────────
local _lo = 0
local function LO() _lo = _lo + 1; return _lo end

local function makeDivider()
    local div = Instance.new("Frame", scroll)
    div.Size = UDim2.new(1,-8,0,1); div.BackgroundColor3 = C_DEEP3
    div.BorderSizePixel = 0; div.LayoutOrder = LO()
    addLivingTextGradient(div)
end

local function makeSectionLabel(text)
    local wrap = Instance.new("Frame", scroll)
    wrap.Size = UDim2.new(1,0,0,22); wrap.BackgroundTransparency = 1; wrap.LayoutOrder = LO()
    local dot = Instance.new("Frame", wrap)
    dot.Size = UDim2.new(0,4,0,4); dot.Position = UDim2.new(0,2,0.5,-2)
    dot.BackgroundColor3 = C_MOON; dot.BorderSizePixel = 0; addCorner(dot, 2)
    local lbl = Instance.new("TextLabel", wrap)
    lbl.Size = UDim2.new(1,-14,1,0); lbl.Position = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = text:upper()
    lbl.TextColor3 = C_WHITE; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    addLivingTextGradient(lbl)
end

local function makeInputRow(label, default, onChange)
    local row = Instance.new("Frame", scroll)
    row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = C_ROW; row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0; row.LayoutOrder = LO(); addCorner(row, 12)
    addLivingStroke(row, 1)
    row.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.15}):Play() end)
    row.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.35}):Play() end)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-96,1,0); lbl.Position = UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = C_WHITE
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left
    addLivingTextGradient(lbl)
    local boxWrap = Instance.new("Frame", row)
    boxWrap.Size = UDim2.new(0,64,0,24); boxWrap.Position = UDim2.new(1,-76,0.5,-12)
    boxWrap.BackgroundColor3 = C_OFF_BG; boxWrap.BackgroundTransparency = 0.1; boxWrap.BorderSizePixel = 0
    addCorner(boxWrap, 8); addLivingStroke(boxWrap, 1)
    local box = Instance.new("TextBox", boxWrap)
    box.Size = UDim2.new(1,-6,1,0); box.Position = UDim2.new(0,3,0,0)
    box.BackgroundTransparency = 1; box.Text = tostring(default)
    box.TextColor3 = Color3.fromRGB(210,222,240); box.Font = Enum.Font.GothamBold; box.TextSize = 12
    box.ClearTextOnFocus = false; box.TextXAlignment = Enum.TextXAlignment.Center
    box:GetPropertyChangedSignal("Text"):Connect(function()
        local f = box.Text:gsub("%D", "")
        if box.Text ~= f then box.Text = f end
    end)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then onChange(n) else box.Text = tostring(default) end
    end)
    makeDivider()
    return box
end

local function makePresetRow(values, onPick)
    local row = Instance.new("Frame", scroll)
    row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = C_ROW; row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0; row.LayoutOrder = LO(); addCorner(row, 12)
    addLivingStroke(row, 1)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0,55,1,0); lbl.Position = UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = "Presets"
    lbl.TextColor3 = C_WHITE; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    addLivingTextGradient(lbl)
    local btnArea = Instance.new("Frame", row)
    btnArea.Size = UDim2.new(1,-80,1,-8); btnArea.Position = UDim2.new(0,74,0,4)
    btnArea.BackgroundTransparency = 1; btnArea.BorderSizePixel = 0
    local bll = Instance.new("UIListLayout", btnArea)
    bll.FillDirection = Enum.FillDirection.Horizontal
    bll.Padding = UDim.new(0,4)
    local BW = math.floor(((WIN_W - 24) - 78 - 3*4) / 4)
    for _, v in ipairs(values) do
        local pb = Instance.new("TextButton", btnArea)
        pb.Size = UDim2.new(0,BW,1,0); pb.BackgroundColor3 = C_ON_BG
        pb.BackgroundTransparency = 0.3; pb.BorderSizePixel = 0
        pb.Text = tostring(v); pb.TextColor3 = C_MOON2
        pb.Font = Enum.Font.GothamBold; pb.TextSize = 10
        addCorner(pb, 6); addLivingStroke(pb, 1)
        pb.MouseEnter:Connect(function() TweenService:Create(pb,TweenInfo.new(0.1),{BackgroundTransparency=0.1}):Play() end)
        pb.MouseLeave:Connect(function() TweenService:Create(pb,TweenInfo.new(0.1),{BackgroundTransparency=0.3}):Play() end)
        pb.MouseButton1Click:Connect(function() onPick(v) end)
    end
    makeDivider()
end

local function makeToggleRow(label, defaultOn, onToggle)
    local row = Instance.new("Frame", scroll)
    row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = C_ROW; row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0; row.LayoutOrder = LO(); addCorner(row, 12)
    addLivingStroke(row, 1)
    row.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.15}):Play() end)
    row.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.35}):Play() end)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-70,1,0); lbl.Position = UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = C_WHITE
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left
    addLivingTextGradient(lbl)
    local pill = Instance.new("Frame", row)
    pill.Size = UDim2.new(0,40,0,20); pill.Position = UDim2.new(1,-54,0.5,-10)
    pill.BackgroundColor3 = defaultOn and C_ON_BG or C_OFF_BG; pill.BackgroundTransparency = 0.1
    pill.BorderSizePixel = 0; addCorner(pill, 10); addLivingStroke(pill, 1)
    local ball = Instance.new("Frame", pill)
    ball.Size = UDim2.new(0,14,0,14)
    ball.Position = defaultOn and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
    ball.BackgroundColor3 = defaultOn and C_WHITE or C_SILVER2; ball.BorderSizePixel = 0
    addCorner(ball, 7)
    local isOn = defaultOn
    local function setV(on)
        isOn = on
        TweenService:Create(pill,TweenInfo.new(0.15),{BackgroundColor3=on and C_ON_BG or C_OFF_BG}):Play()
        TweenService:Create(ball,TweenInfo.new(0.15,Enum.EasingStyle.Back),{
            Position=on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7),
            BackgroundColor3=on and C_WHITE or C_SILVER2,
        }):Play()
    end
    local clk = Instance.new("TextButton", row)
    clk.Size = UDim2.new(1,0,1,0); clk.BackgroundTransparency = 1; clk.Text = ""
    clk.MouseButton1Click:Connect(function()
        isOn = not isOn; setV(isOn)
        if onToggle then onToggle(isOn) end
    end)
    makeDivider()
    return setV
end

local function makeStatusRow()
    local row = Instance.new("Frame", scroll)
    row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = C_ROW; row.BackgroundTransparency = 0.5
    row.BorderSizePixel = 0; row.LayoutOrder = LO(); addCorner(row, 12)
    addLivingStroke(row, 1)
    local dot = Instance.new("Frame", row)
    dot.Size = UDim2.new(0,6,0,6); dot.Position = UDim2.new(0,12,0.5,-3)
    dot.BackgroundColor3 = C_DIM; dot.BorderSizePixel = 0; addCorner(dot, 3)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-28,1,0); lbl.Position = UDim2.new(0,24,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = "En attente..."
    lbl.TextColor3 = C_DIM; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    return dot, lbl
end

-- ── Build UI ─────────────────────────────────────────────────
makeSectionLabel("Vitesse")

local currentSpeed = 16
local speedBox = makeInputRow("Valeur", 16, function(n) currentSpeed = n end)

makePresetRow({16, 30, 60, 100}, function(v)
    currentSpeed = v
    speedBox.Text = tostring(v)
end)

makeSectionLabel("Contrôle")

local statusDot, statusLbl = makeStatusRow()
-- ── Source logic (v4gg.xyz) — verbatim ──────────────────────
local player = LP
local character = player.Character or player.CharacterAdded:Wait()

-- Core Speed Variables
local speedEnabled = false
local targetSpeed = 16
local connection
local lastPosition = nil
local lastTime = nil

-- Get char parts safely
local function getCharParts()
    local char = player.Character
    if not char then return nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return nil, nil end
    return hum, root
end

-- Silently reclaim network ownership without triggering resets
local function claimOwnership(root)
    pcall(function()
        root:SetNetworkOwner(player)
    end)
end

local function applySpeed(spd)
    if connection then
        connection:Disconnect()
        connection = nil
    end

    local hum, root = getCharParts()
    if not hum or not root then return end

    -- set walkspeed once cleanly
    hum.WalkSpeed = spd
    claimOwnership(root)

    lastPosition = root.Position
    lastTime = tick()

    local ownershipTimer = 0
    local lagbackCooldown = 0

    connection = RunService.Heartbeat:Connect(function(dt)
        if not speedEnabled then return end

        local hum, root = getCharParts()
        if not hum or not root then return end

        -- reclaim ownership every 1.5s silently
        ownershipTimer += dt
        if ownershipTimer >= 1.5 then
            claimOwnership(root)
            ownershipTimer = 0
        end

        local dir = hum.MoveDirection
        if dir.Magnitude < 0.1 then
            lastPosition = root.Position
            lastTime = tick()
            return
        end

        local currentVel = root.AssemblyLinearVelocity
        local targetVel = Vector3.new(dir.X * spd, currentVel.Y, dir.Z * spd)

        -- framerate independent smooth lerp
        local alpha = math.min(dt * 22, 1)
        root.AssemblyLinearVelocity = currentVel:Lerp(targetVel, alpha)

        -- lagback detection using position delta
        lagbackCooldown -= dt
        local now = tick()
        local elapsed = now - lastTime
        if elapsed > 0.1 and lastPosition then
            local expectedDist = spd * elapsed
            local actualDist = (root.Position - lastPosition).Magnitude

            -- if we moved way less than expected server corrected us
            if actualDist < expectedDist * 0.3 and lagbackCooldown <= 0 then
                -- reapply velocity hard to push back
                root.AssemblyLinearVelocity = targetVel * 1.2
                lagbackCooldown = 0.3 -- cooldown so it doesnt spam
            end
        end

        lastPosition = root.Position
        lastTime = now
    end)
end

player.CharacterAdded:Connect(function(char)
    character = char
    if speedEnabled then
        task.wait(0.1)
        applySpeed(targetSpeed)
    end
end)

-- ── Wiring UI → logique source ───────────────────────────────
local function setStatus(on, spd)
    if on then
        statusDot.BackgroundColor3 = Color3.fromRGB(60,220,120)
        statusLbl.TextColor3       = Color3.fromRGB(60,220,120)
        statusLbl.Text             = "Speed x" .. tostring(spd) .. " actif"
    else
        statusDot.BackgroundColor3 = C_DIM
        statusLbl.TextColor3       = C_DIM
        statusLbl.Text             = "Speed désactivé"
    end
end

makeToggleRow("Speed", false, function(on)
    local inputVal = tonumber(speedBox.Text) or currentSpeed
    if on then
        speedEnabled = true
        targetSpeed  = inputVal
        setStatus(true, targetSpeed)
        applySpeed(targetSpeed)
    else
        speedEnabled = false
        if connection then connection:Disconnect(); connection = nil end
        local hum, _ = getCharParts()
        if hum then hum.WalkSpeed = 16 end
        lastPosition = nil
        lastTime = nil
        setStatus(false, 0)
    end
end)
