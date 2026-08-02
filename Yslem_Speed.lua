-- ============================================================
--  Yslem Speed  |  strictly private
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

-- ── Palette — adaptée au background (deep navy + electric blue) ─
local C_BG     = Color3.fromRGB(4, 6, 18)
local C_HEADER = Color3.fromRGB(4, 6, 18)
local C_ROW    = Color3.fromRGB(8, 14, 38)
local C_WHITE  = Color3.fromRGB(220, 235, 255)   -- blanc énergie (comme texte YSLEM)
local C_MOON   = Color3.fromRGB(95, 160, 255)    -- bleu électrique
local C_ON_BG  = Color3.fromRGB(18, 45, 115)     -- navy activé
local C_OFF_BG = Color3.fromRGB(4, 6, 18)
local C_SILVER = Color3.fromRGB(195, 220, 255)   -- argent-bleu inputs
local C_DIM    = Color3.fromRGB(75, 105, 160)    -- bleu-gris dim
local C_DEEP1  = Color3.fromRGB(4, 6, 18)
local C_DEEP2  = Color3.fromRGB(12, 25, 70)
local C_DEEP3  = Color3.fromRGB(45, 95, 210)
local C_DEEP4  = Color3.fromRGB(110, 175, 255)

-- ── Living gradients ────────────────────────────────────────
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
    local c = Instance.new("UICorner", inst); c.CornerRadius = UDim.new(0, r or 8); return c
end
local function addLivingTextGradient(lbl)
    local g = Instance.new("UIGradient", lbl)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    C_DEEP4),
        ColorSequenceKeypoint.new(0.25, C_DEEP3),
        ColorSequenceKeypoint.new(0.5,  C_DEEP4),
        ColorSequenceKeypoint.new(0.75, C_DEEP3),
        ColorSequenceKeypoint.new(1,    C_DEEP4),
    }); g.Rotation = 0; table.insert(_livingGradients, g); return g
end
local function addLivingStroke(parent, thickness)
    local s = Instance.new("UIStroke", parent)
    s.Thickness = thickness or 1.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Color = C_DEEP3
    local g = Instance.new("UIGradient", s)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    C_DEEP1),
        ColorSequenceKeypoint.new(0.25, C_DEEP2),
        ColorSequenceKeypoint.new(0.5,  C_DEEP1),
        ColorSequenceKeypoint.new(0.75, C_DEEP2),
        ColorSequenceKeypoint.new(1,    C_DEEP1),
    }); table.insert(_livingStrokes, g); return s
end

-- ── Image loading via executor getcustomasset ───────────────
-- Downloads the image once, caches to disk, returns local rbxassetid://
-- (the only way to display external URLs in Roblox ImageLabel)
local _IMG_URL  = "https://litter.catbox.moe/xnbgt6qhibc9z4db.png"
local _IMG_FILE = "yslem_bg.png"
local _IMG_ASSET
do
    if type(getcustomasset) == "function" then
        if type(isfile) ~= "function" or not isfile(_IMG_FILE) then
            local reqFn = (syn and type(syn.request)=="function" and syn.request)
                       or (type(request)=="function" and request)
                       or (type(http_request)=="function" and http_request)
            if reqFn then
                local ok, res = pcall(reqFn, {Url=_IMG_URL, Method="GET"})
                if ok and res and res.Body and #res.Body > 0 then
                    pcall(writefile, _IMG_FILE, res.Body)
                end
            end
        end
        local ok, asset = pcall(getcustomasset, _IMG_FILE)
        if ok and asset then _IMG_ASSET = asset end
    end
end

-- ── ScreenGui ───────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "YslemSpeed"; gui.ResetOnSpawn = false
gui.DisplayOrder = 10; gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() if protectgui then protectgui(gui) end end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
    gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end
_G["_YS_SPEED"] = gui

-- ── Widget ──────────────────────────────────────────────────
local spW = Instance.new("Frame", gui)
spW.Name = "SpeedWidget"
spW.Size = UDim2.new(0, 150, 0, 142)
spW.Position = UDim2.new(0.5, -75, 0.5, -71)
spW.BackgroundColor3 = C_BG
spW.BorderSizePixel = 0; spW.ClipsDescendants = true; spW.Active = true
addCorner(spW, 12); addLivingStroke(spW, 1.5)

-- Background image (artwork YSLEM)
local bgImg = Instance.new("ImageLabel", spW)
bgImg.Size = UDim2.new(1,0,1,0)
bgImg.BackgroundTransparency = 1
bgImg.Image = _IMG_ASSET or ""
bgImg.ScaleType = Enum.ScaleType.Crop
bgImg.ImageTransparency = 0
bgImg.ZIndex = 1

-- Dark overlay (lisibilité)
local overlay = Instance.new("Frame", spW)
overlay.Size = UDim2.new(1,0,1,0)
overlay.BackgroundColor3 = Color3.fromRGB(3, 5, 16)
overlay.BackgroundTransparency = 0.38
overlay.BorderSizePixel = 0
overlay.ZIndex = 2

-- ── Header ──────────────────────────────────────────────────
local spH = Instance.new("Frame", spW)
spH.Size = UDim2.new(1,0,0,26); spH.BackgroundColor3 = C_HEADER
spH.BackgroundTransparency = 0.55; spH.BorderSizePixel = 0; spH.ZIndex = 3
addCorner(spH, 12)

-- drag
local _dragging, _dragInput, _dragStart, _startPos = false, nil, nil, nil
spH.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        _dragging = true; _dragStart = inp.Position; _startPos = spW.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then _dragging = false end
        end)
    end
end)
spH.InputChanged:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then _dragInput = inp end
end)
game:GetService("UserInputService").InputChanged:Connect(function(inp)
    if _dragging and _dragInput and inp == _dragInput then
        local d = inp.Position - _dragStart
        spW.Position = UDim2.new(_startPos.X.Scale, _startPos.X.Offset+d.X, _startPos.Y.Scale, _startPos.Y.Offset+d.Y)
    end
end)

local spDot = Instance.new("Frame", spH)
spDot.Size = UDim2.new(0,5,0,5); spDot.Position = UDim2.new(0,10,0,11)
spDot.BackgroundColor3 = C_MOON; spDot.BorderSizePixel = 0; spDot.ZIndex = 4
addCorner(spDot, 3)

local spTitle = Instance.new("TextLabel", spH)
spTitle.Size = UDim2.new(1,-46,1,0); spTitle.Position = UDim2.new(0,20,0,0)
spTitle.BackgroundTransparency = 1; spTitle.Text = "SPEED"
spTitle.TextColor3 = C_WHITE; spTitle.Font = Enum.Font.GothamBlack; spTitle.TextSize = 9
spTitle.TextXAlignment = Enum.TextXAlignment.Left; spTitle.ZIndex = 4
addLivingTextGradient(spTitle)

local spMinBtn = Instance.new("TextButton", spH)
spMinBtn.Size = UDim2.new(0,18,0,18); spMinBtn.Position = UDim2.new(1,-24,0.5,-9)
spMinBtn.BackgroundColor3 = Color3.fromRGB(8,14,38); spMinBtn.BackgroundTransparency = 0.3
spMinBtn.BorderSizePixel = 0; spMinBtn.Text = "-"; spMinBtn.TextColor3 = C_WHITE
spMinBtn.Font = Enum.Font.GothamBlack; spMinBtn.TextSize = 15; spMinBtn.ZIndex = 4
addCorner(spMinBtn, 6); addLivingStroke(spMinBtn, 1)

-- ── Status row ──────────────────────────────────────────────
local stRow = Instance.new("Frame", spW)
stRow.Size = UDim2.new(1,-16,0,26); stRow.Position = UDim2.new(0,8,0,32)
stRow.BackgroundColor3 = C_ROW; stRow.BackgroundTransparency = 0.5
stRow.BorderSizePixel = 0; stRow.ZIndex = 3
addCorner(stRow, 8); addLivingStroke(stRow, 1)

local stLbl = Instance.new("TextLabel", stRow)
stLbl.Size = UDim2.new(0.5,0,1,0); stLbl.Position = UDim2.new(0,12,0,0)
stLbl.BackgroundTransparency = 1; stLbl.Text = "Status:"
stLbl.TextColor3 = C_WHITE; stLbl.Font = Enum.Font.GothamBold; stLbl.TextSize = 11
stLbl.TextXAlignment = Enum.TextXAlignment.Left; stLbl.ZIndex = 4
addLivingTextGradient(stLbl)

local stPill = Instance.new("Frame", stRow)
stPill.Size = UDim2.new(0.44,0,0,22); stPill.Position = UDim2.new(0.54,0,0.5,-11)
stPill.BackgroundColor3 = C_OFF_BG; stPill.BackgroundTransparency = 0.3
stPill.BorderSizePixel = 0; stPill.ZIndex = 4
addCorner(stPill, 6); addLivingStroke(stPill, 1)

local stPillLbl = Instance.new("TextLabel", stPill)
stPillLbl.Size = UDim2.new(1,0,1,0); stPillLbl.BackgroundTransparency = 1
stPillLbl.Text = "OFF"; stPillLbl.TextColor3 = C_DIM
stPillLbl.Font = Enum.Font.GothamBlack; stPillLbl.TextSize = 11; stPillLbl.ZIndex = 5
addLivingTextGradient(stPillLbl)

local stClk = Instance.new("TextButton", stRow)
stClk.Size = UDim2.new(1,0,1,0); stClk.BackgroundTransparency = 1
stClk.Text = ""; stClk.ZIndex = 6

-- ── mkInput ─────────────────────────────────────────────────
local function mkInput(yPos, lbl, val, cb)
    local row = Instance.new("Frame", spW)
    row.Size = UDim2.new(1,-16,0,28); row.Position = UDim2.new(0,8,0,yPos)
    row.BackgroundColor3 = C_ROW; row.BackgroundTransparency = 0.5
    row.BorderSizePixel = 0; row.ZIndex = 3
    addCorner(row, 8); addLivingStroke(row, 1)
    local l = Instance.new("TextLabel", row)
    l.Size = UDim2.new(1,-80,1,0); l.Position = UDim2.new(0,12,0,0)
    l.BackgroundTransparency = 1; l.Text = lbl; l.TextColor3 = C_WHITE
    l.Font = Enum.Font.GothamBold; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 4; addLivingTextGradient(l)
    local bw = Instance.new("Frame", row)
    bw.Size = UDim2.new(0,62,0,22); bw.Position = UDim2.new(1,-70,0.5,-11)
    bw.BackgroundColor3 = C_OFF_BG; bw.BackgroundTransparency = 0.25
    bw.BorderSizePixel = 0; bw.ZIndex = 4
    addCorner(bw, 6); addLivingStroke(bw, 1)
    local box = Instance.new("TextBox", bw)
    box.Size = UDim2.new(1,-6,1,0); box.Position = UDim2.new(0,3,0,0)
    box.BackgroundTransparency = 1; box.Text = tostring(val)
    box.TextColor3 = C_SILVER; box.Font = Enum.Font.GothamBold; box.TextSize = 12
    box.ClearTextOnFocus = false; box.TextXAlignment = Enum.TextXAlignment.Center; box.ZIndex = 5
    box:GetPropertyChangedSignal("Text"):Connect(function()
        local f = box.Text:gsub("%D", "")
        if box.Text ~= f then box.Text = f end
    end)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n and n > 0 and n <= 500 then cb(n)
        else box.Text = tostring(val) end
    end)
    return box
end

-- ── Inputs ──────────────────────────────────────────────────
local normalSpeed = 60
local stealSpeed  = 31

local speedBox = mkInput(64,  "Speed",     normalSpeed, function(n) normalSpeed = n end)
local stealBox = mkInput(98,  "Steal Spd", stealSpeed,  function(n) stealSpeed  = n end)

-- ── Minimize ────────────────────────────────────────────────
local _collapsed = false
local FULL_H, COL_H = 142, 64
spMinBtn.MouseButton1Click:Connect(function()
    _collapsed = not _collapsed
    spW.Size = UDim2.new(0,150,0, _collapsed and COL_H or FULL_H)
    spMinBtn.Text = _collapsed and "+" or "-"
    stRow.Visible = not _collapsed
end)

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

-- ── Toggle ──────────────────────────────────────────────────
local _spActive = false

local function toggleSp()
    _spActive = not _spActive
    speedEnabled = _spActive
    stPill.BackgroundColor3 = _spActive and C_MOON or C_OFF_BG
    stPill.BackgroundTransparency = _spActive and 0.15 or 0.3
    stPillLbl.Text = _spActive and "ON" or "OFF"
    stPillLbl.TextColor3 = _spActive and Color3.fromRGB(3, 8, 20) or C_DIM
    if _spActive then
        targetSpeed = normalSpeed
        applySpeed(targetSpeed)
    else
        if connection then connection:Disconnect(); connection = nil end
        local hum, _ = getCharParts()
        if hum then hum.WalkSpeed = 16 end
        lastPosition = nil; lastTime = nil
    end
end

stClk.MouseButton1Click:Connect(toggleSp)
