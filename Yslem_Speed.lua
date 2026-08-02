-- ============================================================
--  Yslem Speed v1.0  |  usage strictement privé / personnel
-- ============================================================
if _G["_YS_SPEED"] then
    pcall(function() _G["_YS_SPEED"]:Destroy() end)
    _G["_YS_SPEED"] = nil
end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
player.Character = player.Character or player.CharacterAdded:Wait()

-- ── ScreenGui ───────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name             = "YslemSpeed"
sg.ResetOnSpawn     = false
sg.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset   = true
pcall(function() sg.Parent = gethui() end)
if not sg.Parent then sg.Parent = player.PlayerGui end
_G["_YS_SPEED"] = sg

-- ── Dimensions ──────────────────────────────────────────────
local W, H = 245, 205

-- ── Frame principal ─────────────────────────────────────────
local frame = Instance.new("Frame")
frame.Name             = "Main"
frame.Size             = UDim2.new(0, W, 0, H)
frame.Position         = UDim2.new(0.5, -W/2, 0.5, -H/2)
frame.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
frame.ClipsDescendants = true
frame.Parent           = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local fStroke = Instance.new("UIStroke", frame)
fStroke.Color     = Color3.fromRGB(128, 0, 255)
fStroke.Thickness = 1.5

-- ── Header ──────────────────────────────────────────────────
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
header.BorderSizePixel  = 0
header.ZIndex           = 2
header.Parent           = frame
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local dot = Instance.new("Frame")
dot.Size             = UDim2.new(0, 8, 0, 8)
dot.Position         = UDim2.new(0, 12, 0.5, -4)
dot.BackgroundColor3 = Color3.fromRGB(128, 0, 255)
dot.BorderSizePixel  = 0
dot.ZIndex           = 3
dot.Parent           = header
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size                = UDim2.new(1, -28, 1, 0)
titleLbl.Position            = UDim2.new(0, 28, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                = "Yslem Speed"
titleLbl.TextColor3          = Color3.fromRGB(200, 200, 200)
titleLbl.TextSize            = 13
titleLbl.Font                = Enum.Font.GothamBold
titleLbl.TextXAlignment      = Enum.TextXAlignment.Left
titleLbl.ZIndex              = 3
titleLbl.Parent              = header

-- ── Body container ──────────────────────────────────────────
local body = Instance.new("Frame")
body.Size                = UDim2.new(1, -20, 0, H - 44)
body.Position            = UDim2.new(0, 10, 0, 38)
body.BackgroundTransparency = 1
body.Parent              = frame

-- ── Ligne label + valeur courante ───────────────────────────
local lblSpeed = Instance.new("TextLabel")
lblSpeed.Size                = UDim2.new(0.5, 0, 0, 18)
lblSpeed.Position            = UDim2.new(0, 0, 0, 0)
lblSpeed.BackgroundTransparency = 1
lblSpeed.Text                = "VITESSE"
lblSpeed.TextColor3          = Color3.fromRGB(128, 0, 255)
lblSpeed.TextSize            = 10
lblSpeed.Font                = Enum.Font.GothamBold
lblSpeed.TextXAlignment      = Enum.TextXAlignment.Left
lblSpeed.Parent              = body

local curVal = Instance.new("TextLabel")
curVal.Size                = UDim2.new(0.5, 0, 0, 18)
curVal.Position            = UDim2.new(0.5, 0, 0, 0)
curVal.BackgroundTransparency = 1
curVal.Text                = "16"
curVal.TextColor3          = Color3.fromRGB(160, 160, 160)
curVal.TextSize            = 10
curVal.Font                = Enum.Font.Gotham
curVal.TextXAlignment      = Enum.TextXAlignment.Right
curVal.Parent              = body

-- ── TextBox ─────────────────────────────────────────────────
local box = Instance.new("TextBox")
box.Size             = UDim2.new(1, 0, 0, 30)
box.Position         = UDim2.new(0, 0, 0, 22)
box.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
box.BorderSizePixel  = 0
box.Text             = ""
box.PlaceholderText  = "Entrer vitesse..."
box.PlaceholderColor3 = Color3.fromRGB(70, 70, 70)
box.TextColor3       = Color3.fromRGB(220, 220, 220)
box.TextSize         = 13
box.Font             = Enum.Font.Gotham
box.ClearTextOnFocus = false
box.Parent           = body
Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
local bStroke = Instance.new("UIStroke", box)
bStroke.Color     = Color3.fromRGB(45, 45, 45)
bStroke.Thickness = 1

-- ── Presets ─────────────────────────────────────────────────
local presetRow = Instance.new("Frame")
presetRow.Size                = UDim2.new(1, 0, 0, 26)
presetRow.Position            = UDim2.new(0, 0, 0, 58)
presetRow.BackgroundTransparency = 1
presetRow.Parent              = body
local layout = Instance.new("UIListLayout", presetRow)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding       = UDim.new(0, 4)

local BW = math.floor((W - 20 - 4*3) / 4)  -- 4 boutons, 3 gaps de 4px
for _, v in ipairs({16, 30, 60, 100}) do
    local pb = Instance.new("TextButton")
    pb.Size             = UDim2.new(0, BW, 1, 0)
    pb.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
    pb.BorderSizePixel  = 0
    pb.Text             = tostring(v)
    pb.TextColor3       = Color3.fromRGB(150, 150, 150)
    pb.TextSize         = 11
    pb.Font             = Enum.Font.Gotham
    pb.Parent           = presetRow
    Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 5)
    local ps = Instance.new("UIStroke", pb)
    ps.Color     = Color3.fromRGB(40, 40, 40)
    ps.Thickness = 1
    pb.MouseButton1Click:Connect(function()
        box.Text    = tostring(v)
        curVal.Text = tostring(v)
    end)
    pb.MouseEnter:Connect(function()
        pb.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
    end)
    pb.MouseLeave:Connect(function()
        pb.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
    end)
end

-- ── Bouton toggle ────────────────────────────────────────────
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size             = UDim2.new(1, 0, 0, 34)
toggleBtn.Position         = UDim2.new(0, 0, 0, 90)
toggleBtn.BackgroundColor3 = Color3.fromRGB(128, 0, 255)
toggleBtn.BorderSizePixel  = 0
toggleBtn.Text             = "Activer"
toggleBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize         = 13
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.Parent           = body
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 7)

-- ── Barre de statut ─────────────────────────────────────────
local statusBar = Instance.new("Frame")
statusBar.Size             = UDim2.new(1, 0, 0, 24)
statusBar.Position         = UDim2.new(0, 0, 0, 132)
statusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
statusBar.BorderSizePixel  = 0
statusBar.Parent           = body
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 5)

local statusDot = Instance.new("Frame")
statusDot.Size             = UDim2.new(0, 6, 0, 6)
statusDot.Position         = UDim2.new(0, 8, 0.5, -3)
statusDot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
statusDot.BorderSizePixel  = 0
statusDot.Parent           = statusBar
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size                = UDim2.new(1, -22, 1, 0)
statusLbl.Position            = UDim2.new(0, 20, 0, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text                = "En attente..."
statusLbl.TextColor3          = Color3.fromRGB(100, 100, 100)
statusLbl.TextSize            = 10
statusLbl.Font                = Enum.Font.Gotham
statusLbl.TextXAlignment      = Enum.TextXAlignment.Left
statusLbl.Parent              = statusBar

local function setStatus(msg, active)
    statusLbl.Text      = msg
    if active then
        statusLbl.TextColor3  = Color3.fromRGB(0, 210, 80)
        statusDot.BackgroundColor3 = Color3.fromRGB(0, 210, 80)
    else
        statusLbl.TextColor3  = Color3.fromRGB(100, 100, 100)
        statusDot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
end

-- ── Logique speed (unpatch) ──────────────────────────────────
local speedEnabled = false
local targetSpeed  = 16
local connection   = nil
local lastPos      = nil
local lastTime     = nil

local function getCharParts()
    local char = player.Character
    if not char then return nil, nil end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return nil, nil end
    return hum, root
end

local function claimOwnership(root)
    pcall(function() root:SetNetworkOwner(player) end)
end

local function applySpeed(spd)
    if connection then connection:Disconnect(); connection = nil end

    local hum, root = getCharParts()
    if not hum or not root then return end

    hum.WalkSpeed = spd
    claimOwnership(root)
    lastPos  = root.Position
    lastTime = tick()

    local ownerTimer  = 0
    local lagCooldown = 0

    connection = RunService.Heartbeat:Connect(function(dt)
        if not speedEnabled then return end

        local h, r = getCharParts()
        if not h or not r then return end

        -- reclaim network ownership toutes les 1.5s
        ownerTimer = ownerTimer + dt
        if ownerTimer >= 1.5 then
            claimOwnership(r)
            ownerTimer = 0
        end

        local dir = h.MoveDirection
        if dir.Magnitude < 0.1 then
            lastPos  = r.Position
            lastTime = tick()
            return
        end

        local curVel    = r.AssemblyLinearVelocity
        local targetVel = Vector3.new(dir.X * spd, curVel.Y, dir.Z * spd)

        -- lerp smooth indépendant du framerate
        local alpha = math.min(dt * 22, 1)
        r.AssemblyLinearVelocity = curVel:Lerp(targetVel, alpha)

        -- détection lagback + correction
        lagCooldown = lagCooldown - dt
        local now     = tick()
        local elapsed = now - lastTime
        if elapsed > 0.1 and lastPos then
            local expected = spd * elapsed
            local actual   = (r.Position - lastPos).Magnitude
            if actual < expected * 0.3 and lagCooldown <= 0 then
                r.AssemblyLinearVelocity = targetVel * 1.2
                lagCooldown = 0.3
            end
        end

        lastPos  = r.Position
        lastTime = now
    end)
end

local function stopSpeed()
    if connection then connection:Disconnect(); connection = nil end
    local hum, _ = getCharParts()
    if hum then hum.WalkSpeed = 16 end
    lastPos  = nil
    lastTime = nil
end

-- filtre chiffres uniquement
box:GetPropertyChangedSignal("Text"):Connect(function()
    local f = box.Text:gsub("%D", "")
    if box.Text ~= f then box.Text = f end
    if f ~= "" then curVal.Text = f end
end)

-- toggle
toggleBtn.MouseButton1Click:Connect(function()
    local inputVal = tonumber(box.Text)
    if not inputVal or inputVal < 1 then
        setStatus("Valeur invalide!", false)
        statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
        return
    end

    speedEnabled = not speedEnabled
    targetSpeed  = inputVal

    if speedEnabled then
        toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 190, 80)
        toggleBtn.Text             = "Désactiver"
        setStatus("x" .. inputVal .. " actif", true)
        applySpeed(targetSpeed)
    else
        toggleBtn.BackgroundColor3 = Color3.fromRGB(128, 0, 255)
        toggleBtn.Text             = "Activer"
        setStatus("Speed off", false)
        stopSpeed()
    end
end)

-- respawn
player.CharacterAdded:Connect(function()
    if speedEnabled then
        task.wait(0.1)
        applySpeed(targetSpeed)
    end
end)
