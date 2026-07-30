--[[
    J1 Duels
    - UI 240x340 (resizable via UI Sizer)
    - Grey theme, transparent header
    - Background Changer: BG 1 = original decal, BG 2-5 = provided decals
    - Mobile buttons: transparent outer frame, black BG, grey text, 54x54, corner radius 14
    - Steal bar: grey theme, width 200, height 26, integrated with auto steal
    - Mobile button: "TP Bat" toggles teleport-to-closest + bat swing
    - ESP: health bars removed
]]

repeat task.wait() until game:IsLoaded()
local Players, RunService, UIS, TS, Lighting, HS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("TweenService"), game:GetService("Lighting"), game:GetService("HttpService")
local LP = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================================
-- CONFIG SYSTEM
-- ============================================================
local FolderName = "J1Duels"
local FileName = FolderName .. "/config.json"

local Config = {
    ["Lagger Mode"] = false,
    ["ESP"] = false,
    ["Speed Display"] = false,
    ["Stretch Rez"] = false,
    ["Auto Reset Medusa"] = true,
    ["Bat Counter"] = false,
    ["Medusa Counter"] = false,
    ["Gummy Aimbot"] = false,
    ["Giant Potion Auto"] = false,
    ["Infinite Jump"] = false,
    ["Inf Jump Mode"] = "Hold",
    ["Unwalk"] = false,
    ["Auto Steal"] = false,
    ["Auto TP"] = false,
    ["Auto Left"] = false,
    ["Auto Right"] = false,
    ["Shiny Graphics"] = false,
    ["Nuke Optimizer"] = false,
    ["TP Gummy"] = false,
    ["BackgroundIndex"] = 1,
    ["UISize"] = 240,   -- default width; height will scale proportionally (340/240)
    ["Normal Speed"] = 53,
    ["Carry Speed"] = 29,
    ["Lagger Boost"] = 10.1,
    ["Lagger Steal"] = 8,
    ["Steal Radius"] = 60,
    ["Auto TP Height"] = 20,
    ["KB AutoLeft"] = "Z",
    ["KB AutoRight"] = "C",
    ["KB TPFloor"] = "F",
    ["KB GuiHide"] = "LeftControl",
    ["KB GummyAimbot"] = "E",
    ["KB DropBrainrot"] = "G",
    ["KB LaggerMode"] = "L",
    ["KB StretchRez"] = "P",
    ["KB Reset"] = "R",
    ["GP AutoLeft"] = nil,
    ["GP AutoRight"] = nil,
    ["GP TPFloor"] = nil,
    ["GP GuiHide"] = nil,
    ["GP GummyAimbot"] = nil,
    ["GP DropBrainrot"] = nil,
    ["GP LaggerMode"] = nil,
    ["GP StretchRez"] = nil,
    ["GP Reset"] = nil,
}

if not isfolder(FolderName) then makefolder(FolderName) end
if not isfile(FileName) then writefile(FileName, HS:JSONEncode(Config)) end

local function LoadConfig()
    local ok, data = pcall(readfile, FileName)
    if ok and data then
        local ok2, decoded = pcall(function() return HS:JSONDecode(data) end)
        if ok2 and decoded then
            for k, v in pairs(decoded) do Config[k] = v end
        end
    end
end

local function SaveConfig()
    pcall(function() writefile(FileName, HS:JSONEncode(Config)) end)
end

LoadConfig()

-- ============================================================
-- BACKGROUND DECAL LIST
-- ============================================================
local BackgroundDecals = {
    [1] = "rbxassetid://102729289645203",   -- original decal (BG 1)
    [2] = "rbxassetid://101441054754597",
    [3] = "rbxassetid://120758001270080",
    [4] = "rbxassetid://91109104793760",
    [5] = "rbxassetid://136734460508488",
}
local currentBgIndex = Config["BackgroundIndex"] or 1
local uiSize = Config["UISize"] or 240

-- ============================================================
-- APPLY LOADED CONFIG TO RUNTIME VARIABLES
-- ============================================================
local infJumpEnabled = Config["Infinite Jump"]
local infJumpMode = Config["Inf Jump Mode"]
local medusaCounterEnabled = Config["Medusa Counter"]
local batCounterEnabled = Config["Bat Counter"]
local unwalkEnabled = Config["Unwalk"]
local autoLeftEnabled = false
local autoRightEnabled = false
local medusaDebounce = false
local medusaLastUsed = 0
local batCounterDebounce = false

local gummyAimbotState = { autoToggled = Config["Gummy Aimbot"], hittingCooldown = false }
local gummyAimbotConns = {aimbot = nil}
local MOB_SWING_COOLDOWN = 0.35   -- Gummy Bear has a use cooldown, give it more time

local dropBrainrotActive = false
local DROP_ASCEND_DURATION = 0.2
local DROP_ASCEND_SPEED = 150

local Steal = {
    AutoStealEnabled = Config["Auto Steal"],
    StealRadius = Config["Steal Radius"],
    StealDuration = 1.4,
    Data = {}
}
local isStealing = false
local stealStartTime = nil
local Conns = {autoSteal = nil, antiRag = nil, batCounter = nil, anchor = {}, progress = nil}

local AP_L1 = Vector3.new(-476.47,-6.28,92.73)
local AP_L2 = Vector3.new(-483.12,-4.95,94.81)
local AP_R1 = Vector3.new(-476.16,-6.52,25.62)
local AP_R2 = Vector3.new(-483.06,-5.03,25.48)

local MEDUSA_COOLDOWN = 25
local setMedusaVisual = nil

local BAT_COUNTER_SLAP_LIST = {"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap"}

local unwalkSavedAnimate = nil

local espEnabled = Config["ESP"]
local espConns = {}
local espObjects = {}
local showSpeed = Config["Speed Display"]
local ACCENT = Color3.fromRGB(180, 180, 180)
local WHITE = Color3.fromRGB(240,240,255)

local normalSpeedValue = Config["Normal Speed"]
local carrySpeedValue = Config["Carry Speed"]
local humanoid = nil
local humanoidRootPart = nil
local normalModeEnabled = true

local laggerBoostValue = Config["Lagger Boost"]
local laggerStealValue = Config["Lagger Steal"]
local isLaggerModeActive = Config["Lagger Mode"]
local setLaggerModeVisual = nil

local stretchRezEnabled = Config["Stretch Rez"]
local stretchRezConn = nil
local STRETCH_NAME = "J1Duels_Stretch"
local setStretchRezVisual = nil

local autoResetOnMedusaEnabled = Config["Auto Reset Medusa"]
local autoResetMedusaDebounce = false
local autoResetMedusaConns = {}
local setAutoResetMedusaVisual = nil

local autoTPEnabled = Config["Auto TP"]
local autoTPHeight = Config["Auto TP Height"]
local autoTPConn = nil
local setAutoTPVisual = nil

local tpGummyEnabled = Config["TP Gummy"] or false
local tpGummyConn = nil
local setTpGummyVisual = nil

local giantPotionAutoEnabled = Config["Giant Potion Auto"] or false
local giantPotionDebounce = false
local giantPotionConn = nil
local setGiantPotionAutoVisual = nil

local bgDecalRef = nil
local bgLabelRef = nil

-- ============================================================
-- GUMMY BEAR / TP GUMMY FUNCTIONS
-- ============================================================
local function getClosestTarget()
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local closest, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and hum and hum.Health > 0 then
                local dist = (tRoot.Position - root.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = tRoot
                end
            end
        end
    end
    return closest
end

local function findGummy()
    local c = LP.Character
    local bp = LP:FindFirstChild("Backpack")
    if c then
        for _, v in ipairs(c:GetChildren()) do
            if v:IsA("Tool") and (v.Name == "Gummy Bear" or v.Name:lower():find("gummy")) then
                return v
            end
        end
    end
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") and (v.Name == "Gummy Bear" or v.Name:lower():find("gummy")) then
                return v
            end
        end
    end
    return nil
end

local function tryHitGummy()
    if gummyAimbotState.hittingCooldown then return end
    gummyAimbotState.hittingCooldown = true
    pcall(function()
        local c = LP.Character
        if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid")
        local tool = findGummy()
        if tool then
            if tool.Parent ~= c and hum then
                pcall(function() hum:EquipTool(tool) end)
                task.wait(0.05)
            end
            pcall(function() tool:Activate() end)
        end
    end)
    task.delay(MOB_SWING_COOLDOWN, function()
        gummyAimbotState.hittingCooldown = false
    end)
end

local function startTpGummy()
    if tpGummyConn then task.cancel(tpGummyConn); tpGummyConn = nil end
    tpGummyConn = task.spawn(function()
        while tpGummyEnabled do
            task.wait(0.05)
            pcall(function()
                local target = getClosestTarget()
                if not target then return end
                local char = LP.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local dist = (target.Position - hrp.Position).Magnitude
                if dist > 8 then
                    hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
                tryHitGummy()
            end)
        end
    end)
end

local function stopTpGummy()
    if tpGummyConn then task.cancel(tpGummyConn); tpGummyConn = nil end
end

local function toggleTpGummy(on)
    tpGummyEnabled = on
    Config["TP Gummy"] = on
    SaveConfig()
    if on then startTpGummy() else stopTpGummy() end
end

-- ============================================================
-- SHINY GRAPHICS (unchanged)
-- ============================================================
local shinyGraphicsEnabled = Config["Shiny Graphics"]
local originalSkybox = nil
local shinyGraphicsSky = nil
local shinyGraphicsConn = nil
local shinyPlanets = {}
local shinyBloom = nil
local shinyCC = nil
local setShinyGraphicsVisual = nil

local function enableShinyGraphics()
    if shinyGraphicsSky then return end
    originalSkybox = Lighting:FindFirstChildOfClass("Sky")
    if originalSkybox then originalSkybox.Parent = nil end
    shinyGraphicsSky = Instance.new("Sky")
    for _, prop in ipairs({"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"}) do
        shinyGraphicsSky[prop] = "rbxassetid://1534951537"
    end
    shinyGraphicsSky.StarCount = 10000
    shinyGraphicsSky.CelestialBodiesShown = false
    shinyGraphicsSky.Parent = Lighting
    shinyBloom = Instance.new("BloomEffect")
    shinyBloom.Intensity = 1.5
    shinyBloom.Size = 40
    shinyBloom.Threshold = 0.8
    shinyBloom.Parent = Lighting
    shinyCC = Instance.new("ColorCorrectionEffect")
    shinyCC.Saturation = 0.8
    shinyCC.Contrast = 0.3
    shinyCC.TintColor = Color3.fromRGB(200, 200, 200)
    shinyCC.Parent = Lighting
    Lighting.Ambient = Color3.fromRGB(100, 100, 110)
    Lighting.Brightness = 3
    Lighting.ClockTime = 0
    for i = 1, 2 do
        local p = Instance.new("Part")
        p.Shape = Enum.PartType.Ball
        p.Size = Vector3.new(800 + i * 200, 800 + i * 200, 800 + i * 200)
        p.Anchored = true
        p.CanCollide = false
        p.CastShadow = false
        p.Material = Enum.Material.Neon
        p.Color = Color3.fromRGB(160 + i * 15, 160 + i * 15, 165 + i * 15)
        p.Transparency = 0.3
        p.Position = Vector3.new(math.cos(i * 2) * (3000 + i * 500), 1500 + i * 300, math.sin(i * 2) * (3000 + i * 500))
        p.Parent = workspace
        table.insert(shinyPlanets, p)
    end
    shinyGraphicsConn = RunService.Heartbeat:Connect(function()
        if not shinyGraphicsEnabled then return end
        local t = tick() * 0.5
        Lighting.Ambient = Color3.fromRGB(100 + math.sin(t) * 30, 100 + math.sin(t * 0.8) * 30, 110 + math.sin(t * 1.2) * 30)
        if shinyBloom then shinyBloom.Intensity = 1.2 + math.sin(t * 2) * 0.4 end
    end)
    shinyGraphicsEnabled = true
    Config["Shiny Graphics"] = true
    SaveConfig()
    if setShinyGraphicsVisual then setShinyGraphicsVisual(true) end
end

local function disableShinyGraphics()
    if shinyGraphicsConn then
        shinyGraphicsConn:Disconnect()
        shinyGraphicsConn = nil
    end
    if shinyGraphicsSky then
        shinyGraphicsSky:Destroy()
        shinyGraphicsSky = nil
    end
    if originalSkybox then originalSkybox.Parent = Lighting end
    if shinyBloom then
        shinyBloom:Destroy()
        shinyBloom = nil
    end
    if shinyCC then
        shinyCC:Destroy()
        shinyCC = nil
    end
    for _, obj in ipairs(shinyPlanets) do
        if obj then obj:Destroy() end
    end
    shinyPlanets = {}
    Lighting.Ambient = Color3.fromRGB(127, 127, 127)
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    shinyGraphicsEnabled = false
    Config["Shiny Graphics"] = false
    SaveConfig()
    if setShinyGraphicsVisual then setShinyGraphicsVisual(false) end
end

-- ============================================================
-- NUKE OPTIMIZER (unchanged)
-- ============================================================
local NukeOn = Config["Nuke Optimizer"]
local NukeConns = {}
local NukeThreads = {}
local setNukeVisual = nil

local ClothingClasses = {
    "Shirt", "Pants", "ShirtGraphic", "Accessory", "Hat",
    "HairAccessory", "FaceAccessory", "NeckAccessory",
    "ShoulderAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory"
}

local BASE_NAMES = {"baseplate", "spawnlocation", "spawn location", "spawn"}
local XMin, XMax = -560, -240

local function SafeDestroy(obj)
    if obj.Name == "Overhead" then return end
    pcall(function() obj:Destroy() end)
end

local function IsClothing(obj)
    for _, c in ipairs(ClothingClasses) do
        if obj:IsA(c) then return true end
    end
    return false
end

local function IsCharacterPart(obj)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and obj:IsDescendantOf(plr.Character) then
            return true
        end
    end
    return false
end

local function IsOutOfRange(obj)
    if obj:IsA("BasePart") then
        local x = obj.Position.X
        return x < XMin or x > XMax
    end
    return false
end

local function IsBase(obj)
    if not obj:IsA("BasePart") then return false end
    local nl = obj.Name:lower()
    for _, n in ipairs(BASE_NAMES) do
        if nl:find(n, 1, true) then return true end
    end
    return false
end

local function IsInBase(obj)
    local p = obj.Parent
    while p and p ~= workspace do
        if IsBase(p) then return true end
        p = p.Parent
    end
    return false
end

local function MakeTransparent(obj)
    pcall(function()
        if IsBase(obj) and not IsCharacterPart(obj) then
            obj.Transparency = 1
            obj.CastShadow = false
        end
    end)
end

local function StripObject(obj)
    pcall(function()
        if obj:IsA("Texture") or obj:IsA("Decal") or obj:IsA("SpecialMesh") then
            SafeDestroy(obj)
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            pcall(function() obj.Enabled = false end)
            SafeDestroy(obj)
        elseif obj:IsA("SurfaceAppearance") then
            SafeDestroy(obj)
        elseif obj:IsA("BasePart") then
            obj.CastShadow = false
            obj.Material = Enum.Material.Plastic
            obj.MaterialVariant = ""
            obj.Reflectance = 0
        end
    end)
end

local function CleanObject(obj)
    pcall(function()
        if obj:IsA("SurfaceAppearance") then
            SafeDestroy(obj)
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            if not (obj.Name == "face" and obj.Parent and obj.Parent.Name == "Head") then
                SafeDestroy(obj)
            end
        elseif obj:IsA("SpecialMesh") then
            obj.TextureId = ""
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
            SafeDestroy(obj)
        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            SafeDestroy(obj)
        elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Explosion") then
            SafeDestroy(obj)
        elseif obj:IsA("Animation") or obj:IsA("AnimationController") then
            SafeDestroy(obj)
        elseif obj:IsA("BasePart") then
            obj.CastShadow = false
            obj.Material = Enum.Material.Plastic
            obj.MaterialVariant = ""
            obj.Reflectance = 0
        end
    end)
end

local function ApplyGreySky()
    pcall(function()
        for _, obj in ipairs(Lighting:GetChildren()) do
            if obj:IsA("Sky") then obj:Destroy() end
        end
        local sky = Instance.new("Sky")
        sky.SkyboxBk = ""
        sky.SkyboxDn = ""
        sky.SkyboxFt = ""
        sky.SkyboxLf = ""
        sky.SkyboxRt = ""
        sky.SkyboxUp = ""
        sky.CelestialBodiesShown = false
        sky.Name = "_NukeSky"
        sky.Parent = Lighting
    end)
end

local function OptimizeLighting()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.FogStart = 9e9
    Lighting.EnvironmentDiffuseScale = 0
    Lighting.EnvironmentSpecularScale = 0
    Lighting.Brightness = 1.5
    Lighting.Ambient = Color3.fromRGB(60, 60, 60)
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("Atmosphere") or v:IsA("Clouds") then
            v:Destroy()
        end
    end
    ApplyGreySky()
end

local function ApplyTerrain()
    pcall(function()
        local T = workspace.Terrain
        T.Decoration = false
        T.WaterWaveSize = 0
        T.WaterWaveSpeed = 0
        T.WaterReflectance = 0
        T.WaterTransparency = 1
    end)
end

local function OptimizeCharacter(char)
    if not char then return end
    task.spawn(function()
        task.wait(0.3)
        if not NukeOn then return end
        for _, obj in ipairs(char:GetDescendants()) do
            if IsClothing(obj) then
                SafeDestroy(obj)
            else
                CleanObject(obj)
            end
        end
    end)
end

function StartNuke()
    if NukeOn then return end
    NukeOn = true
    Config["Nuke Optimizer"] = true
    SaveConfig()
    if setNukeVisual then setNukeVisual(true) end

    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
    end)
    pcall(function() if setfpscap then setfpscap(999) end end)

    table.insert(NukeThreads, task.spawn(function()
        if not game:IsLoaded() then game.Loaded:Wait() end
        OptimizeLighting()
        ApplyTerrain()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if not NukeOn then return end
            if IsBase(obj) then
                MakeTransparent(obj)
            elseif IsClothing(obj) then
                SafeDestroy(obj)
            elseif IsInBase(obj) then
                -- skip
            elseif IsCharacterPart(obj) then
                -- skip
            elseif IsOutOfRange(obj) then
                SafeDestroy(obj)
            else
                CleanObject(obj)
                StripObject(obj)
            end
        end
        for _, obj in ipairs(workspace:GetDescendants()) do
            MakeTransparent(obj)
        end
    end))

    table.insert(NukeConns, workspace.DescendantAdded:Connect(function(obj)
        if not NukeOn then return end
        task.defer(function()
            if not NukeOn then return end
            if IsBase(obj) then
                MakeTransparent(obj)
                return
            end
            if IsClothing(obj) then
                SafeDestroy(obj)
            elseif IsInBase(obj) then
                -- skip
            elseif IsCharacterPart(obj) then
                -- skip
            elseif IsOutOfRange(obj) then
                SafeDestroy(obj)
            else
                CleanObject(obj)
                StripObject(obj)
            end
        end)
    end))

    table.insert(NukeConns, Lighting.DescendantAdded:Connect(function(obj)
        if not NukeOn then return end
        if obj:IsA("Atmosphere") or obj:IsA("Clouds") or obj:IsA("PostEffect") then
            SafeDestroy(obj)
        end
    end))

    table.insert(NukeConns, MaterialService.DescendantAdded:Connect(function(obj)
        if not NukeOn then return end
        SafeDestroy(obj)
    end))

    for _, plr in ipairs(Players:GetPlayers()) do
        OptimizeCharacter(plr.Character)
        table.insert(NukeConns, plr.CharacterAdded:Connect(OptimizeCharacter))
    end

    table.insert(NukeConns, Players.PlayerAdded:Connect(function(plr)
        table.insert(NukeConns, plr.CharacterAdded:Connect(OptimizeCharacter))
    end))

    table.insert(NukeThreads, task.spawn(function()
        while NukeOn do
            task.wait(15)
            pcall(function() collectgarbage("collect") end)
        end
    end))
end

function StopNuke()
    if not NukeOn then return end
    NukeOn = false
    Config["Nuke Optimizer"] = false
    SaveConfig()
    if setNukeVisual then setNukeVisual(false) end
    for _, c in ipairs(NukeConns) do
        pcall(function() c:Disconnect() end)
    end
    NukeConns = {}
    NukeThreads = {}
end

-- ============================================================
-- SPEED VISUAL (ALWAYS ENABLED)
-- ============================================================
local speedVisualBB = nil
local speedVisualConn = nil

local function createSpeedVisual()
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if speedVisualBB then speedVisualBB:Destroy() end
    speedVisualBB = Instance.new("BillboardGui")
    speedVisualBB.Adornee = hrp
    speedVisualBB.Size = UDim2.new(0, 120, 0, 36)
    speedVisualBB.StudsOffset = Vector3.new(0, 4.5, 0)
    speedVisualBB.AlwaysOnTop = true
    speedVisualBB.Parent = hrp
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = ACCENT
    lbl.TextStrokeTransparency = 0
    lbl.TextScaled = true
    lbl.Text = "Speed: 0"
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = speedVisualBB
end

local function startSpeedVisual()
    if speedVisualConn then return end
    if LP.Character then createSpeedVisual() end
    LP.CharacterAdded:Connect(function()
        task.wait(0.5)
        createSpeedVisual()
    end)
    speedVisualConn = RunService.Heartbeat:Connect(function()
        local char = LP.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not speedVisualBB or not speedVisualBB.Parent then
            createSpeedVisual()
        end
        local lbl = speedVisualBB and speedVisualBB:FindFirstChildOfClass("TextLabel")
        if not lbl then return end
        local v = hrp.AssemblyLinearVelocity
        local horizontalSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
        lbl.Text = "Speed: " .. math.floor(horizontalSpeed)
        lbl.TextColor3 = ACCENT
    end)
end

startSpeedVisual()

-- ============================================================
-- KEYBINDS
-- ============================================================
local function strToKeyCode(s)
    if not s then return nil end
    return pcall(function() return Enum.KeyCode[s] end) and Enum.KeyCode[s] or nil
end

local KB = {
    AutoLeft =    {kb = strToKeyCode(Config["KB AutoLeft"]),    gp = strToKeyCode(Config["GP AutoLeft"])},
    AutoRight =   {kb = strToKeyCode(Config["KB AutoRight"]),   gp = strToKeyCode(Config["GP AutoRight"])},
    TPFloor =     {kb = strToKeyCode(Config["KB TPFloor"]),     gp = strToKeyCode(Config["GP TPFloor"])},
    GuiHide =     {kb = strToKeyCode(Config["KB GuiHide"]),     gp = strToKeyCode(Config["GP GuiHide"])},
    GummyAimbot = {kb = strToKeyCode(Config["KB GummyAimbot"]), gp = strToKeyCode(Config["GP GummyAimbot"])},
    DropBrainrot= {kb = strToKeyCode(Config["KB DropBrainrot"]),gp = strToKeyCode(Config["GP DropBrainrot"])},
    LaggerMode =  {kb = strToKeyCode(Config["KB LaggerMode"]),  gp = strToKeyCode(Config["GP LaggerMode"])},
    StretchRez =  {kb = strToKeyCode(Config["KB StretchRez"]),  gp = strToKeyCode(Config["GP StretchRez"])},
    Reset =       {kb = strToKeyCode(Config["KB Reset"]),       gp = strToKeyCode(Config["GP Reset"])},
}

local _anyKeyListening = false
local _updateMobileAutoLeft, _updateMobileAutoRight, _updateMobileGummyAimbot, _updateMobileDropBrainrot, _updateMobileLaggerMode, _updateMobileTpGummy, _updateMobileGiantPotionAuto

local function saveKB(name, kc, isGp)
    if isGp then
        Config["GP "..name] = kc and kc.Name or nil
        Config["KB "..name] = nil
    else
        Config["KB "..name] = kc and kc.Name or nil
        Config["GP "..name] = nil
    end
    SaveConfig()
end

-- ============================================================
-- SPEED
-- ============================================================
local function getNormalModeSpeed()
    if not humanoid then return normalSpeedValue end
    return (humanoid.WalkSpeed < 25) and carrySpeedValue or normalSpeedValue
end

local function getLaggerModeSpeed()
    if not humanoid then return laggerBoostValue end
    return (humanoid.WalkSpeed < 25) and laggerStealValue or laggerBoostValue
end

local function handleSpeed()
    if not humanoid or not humanoidRootPart then return end
    local md = humanoid.MoveDirection
    if md.Magnitude == 0 then return end
    local spd
    if isLaggerModeActive then
        spd = (humanoid.WalkSpeed < 25) and laggerStealValue or laggerBoostValue
    else
        spd = (humanoid.WalkSpeed < 25) and carrySpeedValue or normalSpeedValue
    end
    humanoidRootPart.Velocity = Vector3.new(md.X * spd, humanoidRootPart.Velocity.Y, md.Z * spd)
end

local function setNormalSpeed(v)   normalSpeedValue = math.clamp(v,15,200); Config["Normal Speed"]=normalSpeedValue; SaveConfig() end
local function setCarrySpeed(v)    carrySpeedValue  = math.clamp(v,15,200); Config["Carry Speed"]=carrySpeedValue;   SaveConfig() end
local function setLaggerBoost(v)   laggerBoostValue = math.clamp(v,1,200);  Config["Lagger Boost"]=laggerBoostValue; SaveConfig() end
local function setLaggerSteal(v)   laggerStealValue = math.clamp(v,1,200);  Config["Lagger Steal"]=laggerStealValue; SaveConfig() end
local function isCarrying()        return humanoid and humanoid.WalkSpeed < 25 end

local function setLaggerMode(enabled)
    isLaggerModeActive = enabled
    Config["Lagger Mode"] = enabled
    SaveConfig()
    if setLaggerModeVisual then setLaggerModeVisual(enabled) end
end

LP.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    humanoid = char:FindFirstChildOfClass("Humanoid")
    humanoidRootPart = char:FindFirstChild("HumanoidRootPart")
end)
if LP.Character then
    task.spawn(function()
        task.wait(0.1)
        humanoid = LP.Character:FindFirstChildOfClass("Humanoid")
        humanoidRootPart = LP.Character:FindFirstChild("HumanoidRootPart")
    end)
end
RunService.Heartbeat:Connect(handleSpeed)

-- ============================================================
-- ANTI-RAGDOLL
-- ============================================================
local function antiRagdollTick()
    if not Conns.antiRag then return end
    local char = LP.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BallSocketConstraint") or (v:IsA("Attachment") and v.Name:find("RagdollAttachment")) then
                pcall(function() v:Destroy() end)
            end
        end
        pcall(function() LP:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow()) end)
        if hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Running) end
        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(root.Orientation.Y), 0)
        local cam = workspace.CurrentCamera
        if cam and cam.CameraSubject ~= hum then cam.CameraSubject = hum end
    end
end
local function startAntiRagdoll()
    if Conns.antiRag then return end
    Conns.antiRag = RunService.RenderStepped:Connect(antiRagdollTick)
end
local function stopAntiRagdoll()
    if Conns.antiRag then Conns.antiRag:Disconnect(); Conns.antiRag = nil end
end
startAntiRagdoll()
LP.CharacterAdded:Connect(function() task.wait(0.5); startAntiRagdoll() end)

-- ============================================================
-- STRETCH RESOLUTION
-- ============================================================
local function enableStretchRez()
    stretchRezEnabled = true
    Config["Stretch Rez"] = true; SaveConfig()
    pcall(function() RunService:UnbindFromRenderStep(STRETCH_NAME) end)
    pcall(function()
        RunService:BindToRenderStep(STRETCH_NAME, Enum.RenderPriority.Last.Value - 1, function()
            local cam = workspace.CurrentCamera
            if cam then cam.CFrame = cam.CFrame * CFrame.new(0,0,0,1,0,0,0,0.8,0,0,0,1) end
        end)
    end)
end
local function disableStretchRez()
    stretchRezEnabled = false
    Config["Stretch Rez"] = false; SaveConfig()
    pcall(function() RunService:UnbindFromRenderStep(STRETCH_NAME) end)
end
local function toggleStretchRez()
    if stretchRezEnabled then disableStretchRez() else enableStretchRez() end
    if setStretchRezVisual then setStretchRezVisual(stretchRezEnabled) end
end
if stretchRezEnabled then enableStretchRez() end

loadstring(game:HttpGet("https://raw.githubusercontent.com/Argian-dotcom/Jdkffkfo/refs/heads/main/Coding"))()

-- ============================================================
-- INSTA RESET
-- ============================================================
local resetRemote = nil
local RESET_GUID = "f888ee6e-c86d-46e1-93d7-0639d6635d42"
pcall(function()
    if hookfunction and newcclosure then
        local oldFire
        oldFire = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
            if not resetRemote and typeof(self)=="Instance" and self:IsA("RemoteEvent") and self.Name:sub(1,3)=="RE/" then resetRemote = self end
            return oldFire(self, ...)
        end))
    end
end)
task.spawn(function()
    task.wait(2)
    if not resetRemote then
        for _, desc in ipairs(game:GetDescendants()) do
            if desc:IsA("RemoteEvent") and desc.Name:sub(1,3)=="RE/" then resetRemote = desc; break end
        end
    end
end)
local function instaReset()
    if not resetRemote then
        for _, desc in ipairs(game:GetDescendants()) do
            if desc:IsA("RemoteEvent") and desc.Name:sub(1,3)=="RE/" then resetRemote = desc; break end
        end
        if not resetRemote then return end
    end
    local character = LP.Character
    if not character then pcall(function() resetRemote:FireServer(RESET_GUID, LP, "balloon") end); return end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then pcall(function() resetRemote:FireServer(RESET_GUID, LP, "balloon") end); return end
    local resetDetected = false; local connections = {}
    table.insert(connections, hum.Died:Connect(function() resetDetected = true end))
    table.insert(connections, character.AncestryChanged:Connect(function(_,p) if not p then resetDetected = true end end))
    table.insert(connections, hum:GetPropertyChangedSignal("Health"):Connect(function() if hum.Health<=0 then resetDetected=true end end))
    task.spawn(function()
        local attempts = 0
        while not resetDetected and attempts < 50 do
            attempts = attempts + 1
            pcall(function() resetRemote:FireServer(RESET_GUID, LP, "balloon") end)
            task.wait()
        end
        for _, c in pairs(connections) do c:Disconnect() end
    end)
end

-- ============================================================
-- AUTO RESET ON MEDUSA
-- ============================================================
local function onMedusaPlatformStandChanged()
    if not autoResetOnMedusaEnabled then return end
    local char = LP.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if hum.PlatformStand then
        if autoResetMedusaDebounce then return end
        autoResetMedusaDebounce = true
        task.spawn(function() instaReset(); task.wait(3); autoResetMedusaDebounce = false end)
    end
end
local function onAnchorChangedAutoReset(part)
    return part:GetPropertyChangedSignal("Anchored"):Connect(function()
        if not autoResetOnMedusaEnabled then return end
        if part.Anchored and part.Transparency == 1 then
            if autoResetMedusaDebounce then return end
            autoResetMedusaDebounce = true
            task.spawn(function() instaReset(); task.wait(3); autoResetMedusaDebounce = false end)
        end
    end)
end
local function setupAutoResetOnMedusa(char)
    for _, c in pairs(autoResetMedusaConns) do pcall(function() c:Disconnect() end) end
    autoResetMedusaConns = {}
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        table.insert(autoResetMedusaConns, hum:GetPropertyChangedSignal("PlatformStand"):Connect(onMedusaPlatformStandChanged))
        if hum.PlatformStand then onMedusaPlatformStandChanged() end
    end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then table.insert(autoResetMedusaConns, onAnchorChangedAutoReset(part)) end
    end
    table.insert(autoResetMedusaConns, char.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then table.insert(autoResetMedusaConns, onAnchorChangedAutoReset(part)) end
    end))
end
local function stopAutoResetOnMedusa()
    for _, c in pairs(autoResetMedusaConns) do pcall(function() c:Disconnect() end) end
    autoResetMedusaConns = {}
end
local function toggleAutoResetOnMedusa(enabled)
    autoResetOnMedusaEnabled = enabled
    Config["Auto Reset Medusa"] = enabled; SaveConfig()
    if enabled then setupAutoResetOnMedusa(LP.Character) else stopAutoResetOnMedusa() end
end

-- ============================================================
-- ESP (grey theme, health bars removed)
-- ============================================================
local function getHum(plr) local c=plr.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function isTargetValid(plr)
    if plr==LP then return false end
    local c=plr.Character; if not c then return false end
    local hum=c:FindFirstChildOfClass("Humanoid"); local hrp=c:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end
    if hum.Health<=0 then return false end
    if c:FindFirstChildOfClass("ForceField") then return false end
    return true
end

local function createSpeedDisplay(plr, data)
    if not showSpeed or not espEnabled then return end
    if data.SpeedBB then return end
    local head = data.Head; if not head then return end
    local speedBB = Instance.new("BillboardGui")
    speedBB.Name = "SpeedDisplay"; speedBB.Adornee = head
    speedBB.Size = UDim2.new(0,100,0,28); speedBB.StudsOffset = Vector3.new(0,4.8,0)
    speedBB.AlwaysOnTop = true; speedBB.Parent = data.Group
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = ACCENT
    lbl.TextStrokeTransparency = 0.3; lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    lbl.TextScaled = true; lbl.Text = "0.0"; lbl.Font = Enum.Font.GothamBold; lbl.Parent = speedBB
    data.SpeedBB = speedBB; data.SpeedLbl = lbl
end

local removeESP
local function createESP(plr)
    if not isTargetValid(plr) then return end
    if espObjects[plr] then return end
    local char=plr.Character; local root=char:FindFirstChild("HumanoidRootPart"); local head=char:FindFirstChild("Head")
    if not root or not head then return end
    local group = Instance.new("Folder"); group.Name="TerrorESP"; group.Parent=char
    local box = Instance.new("BoxHandleAdornment"); box.Name="Box"; box.Adornee=root
    box.Size=Vector3.new(4,6,2); box.Color3=ACCENT
    box.Transparency=0.7
    box.ZIndex=10; box.AlwaysOnTop=true; box.Parent=group
    local boxGlow=Instance.new("BoxHandleAdornment"); boxGlow.Name="BoxGlow"; boxGlow.Adornee=root
    boxGlow.Size=Vector3.new(4.4,6.4,2.4); boxGlow.Color3=ACCENT
    boxGlow.Transparency=0.3
    boxGlow.ZIndex=9; boxGlow.AlwaysOnTop=true; boxGlow.Parent=group
    local bb=Instance.new("BillboardGui"); bb.Name="NameTag"; bb.Adornee=head
    bb.Size=UDim2.new(0,200,0,45); bb.StudsOffset=Vector3.new(0,4.2,0); bb.AlwaysOnTop=true; bb.Parent=group
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
    lbl.Text=plr.DisplayName; lbl.TextColor3=ACCENT
    lbl.Font=Enum.Font.GothamBold
    lbl.TextScaled=true; lbl.TextStrokeTransparency=0.3; lbl.TextStrokeColor3=Color3.fromRGB(0,0,0); lbl.Parent=bb
    local tracer=Drawing.new("Line"); tracer.Visible=true; tracer.Color=Color3.new(0.7,0.7,0.7); tracer.Thickness=2; tracer.Transparency=0.5; tracer.ZIndex=5
    local data={Group=group,Box=box,BoxGlow=boxGlow,NameTag=bb,Tracer=tracer,Root=root,Head=head,Player=plr,SpeedBB=nil,SpeedLbl=nil}
    espObjects[plr]=data
    if showSpeed then createSpeedDisplay(plr, data) end
end

local function updateESP()
    if not espEnabled then return end
    local lc=LP.Character; if not lc then return end
    local lr=lc:FindFirstChild("HumanoidRootPart"); if not lr then return end
    local lp2,lv=camera:WorldToViewportPoint(lr.Position)
    if not lv then return end
    for plr, data in pairs(espObjects) do
        if not isTargetValid(plr) then removeESP(plr)
        else
            if showSpeed and data.SpeedLbl and data.Root then
                local v=data.Root.AssemblyLinearVelocity
                data.SpeedLbl.Text=string.format("%.1f",Vector3.new(v.X,0,v.Z).Magnitude)
                data.SpeedLbl.TextColor3=ACCENT
            end
            if data.Root and data.Tracer then
                local ep,ev=camera:WorldToViewportPoint(data.Root.Position)
                if ev and lv then
                    data.Tracer.From=Vector2.new(lp2.X,lp2.Y); data.Tracer.To=Vector2.new(ep.X,ep.Y); data.Tracer.Visible=true
                else data.Tracer.Visible=false end
            end
        end
    end
end

removeESP = function(plr)
    local data=espObjects[plr]
    if data then
        if data.Group then data.Group:Destroy() end
        if data.Tracer then data.Tracer:Remove() end
    end
    espObjects[plr]=nil
end

local function enableESP()
    espEnabled=true; Config["ESP"]=true; SaveConfig()
    for _,plr in ipairs(Players:GetPlayers()) do if plr~=LP then pcall(function() createESP(plr) end) end end
    for _,conn in ipairs(espConns) do if conn and conn.Connected then conn:Disconnect() end end
    espConns={}
    table.insert(espConns, Players.PlayerAdded:Connect(function(plr)
        if plr==LP then return end
        plr.CharacterAdded:Connect(function() task.wait(0.1); if espEnabled then pcall(function() createESP(plr) end) end end)
    end))
    table.insert(espConns, Players.PlayerRemoving:Connect(removeESP))
    table.insert(espConns, RunService.RenderStepped:Connect(function() if espEnabled then updateESP() end end))
end
local function disableESP()
    espEnabled=false; Config["ESP"]=false; SaveConfig()
    for plr in pairs(espObjects) do removeESP(plr) end
    espObjects={}
    for _,conn in ipairs(espConns) do if conn and conn.Connected then conn:Disconnect() end end
    espConns={}
end

LP.CharacterAdded:Connect(function()
    task.wait(1)
    if espEnabled then for _,plr in ipairs(Players:GetPlayers()) do if plr~=LP then pcall(function() createESP(plr) end) end end end
end)
Players.PlayerAdded:Connect(function(plr)
    if plr~=LP then
        plr.CharacterAdded:Connect(function()
            task.wait(0.1); if espEnabled then pcall(function() createESP(plr) end) end
        end)
    end
end)

-- ============================================================
-- GUMMY AIMBOT
-- ============================================================
local function toggleGummyAimbot(on)
    gummyAimbotState.autoToggled = on
    Config["Gummy Aimbot"] = on
    SaveConfig()
    if on then
        if gummyAimbotConns.aimbot then gummyAimbotConns.aimbot:Disconnect() end
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = false end
        gummyAimbotConns.aimbot = RunService.RenderStepped:Connect(function()
            if not gummyAimbotState.autoToggled then return end
            local char = LP.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local hum2 = char:FindFirstChildOfClass("Humanoid")
            if not hum2 then return end
            if not char:FindFirstChildOfClass("Tool") then
                local gummy = findGummy()
                if gummy then pcall(function() hum2:EquipTool(gummy) end) end
            end
            local target = getClosestTarget()
            if not target then return end
            local targetVel = target.AssemblyLinearVelocity
            local myPos = root.Position
            local targetPos = target.Position
            local predictPos = targetPos + targetVel * 0.14 + target.CFrame.LookVector * 0.3
            local direction = predictPos - myPos
            local flatDir = Vector3.new(direction.X, 0, direction.Z).Unit
            local chaseSpeed = 58
            local desiredHeight = targetPos.Y + 3.7
            local yVel = (desiredHeight - myPos.Y) * 19.5 + targetVel.Y * 0.8
            if hum2.FloorMaterial ~= Enum.Material.Air then yVel = math.max(yVel, 13) end
            yVel = math.clamp(yVel, -70, 110)
            local desiredVel = Vector3.new(flatDir.X * chaseSpeed, yVel, flatDir.Z * chaseSpeed)
            root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)
            local speed3 = targetVel.Magnitude
            local predictTime = math.clamp(speed3 / 150, 0.05, 0.2)
            local predictedPos = targetPos + targetVel * predictTime
            local toPredict = predictedPos - myPos
            if toPredict.Magnitude > 0.1 then
                local goalCF = CFrame.lookAt(myPos, predictedPos)
                local curCF = root.CFrame
                local diffCF = curCF:Inverse() * goalCF
                local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
                rx = math.clamp(rx, -2.5, 2.5)
                ry = math.clamp(ry, -2.5, 2.5)
                rz = math.clamp(rz, -2.5, 2.5)
                local tiltSpeed = 42
                root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(Vector3.new(rx * tiltSpeed, ry * tiltSpeed, rz * tiltSpeed))
            end
            if (target.Position - myPos).Magnitude < 10 then
                tryHitGummy()
            end
        end)
    else
        if gummyAimbotConns.aimbot then
            gummyAimbotConns.aimbot:Disconnect()
            gummyAimbotConns.aimbot = nil
        end
        local c = LP.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
        gummyAimbotState.hittingCooldown = false
    end
end

-- ============================================================
-- GIANT POTION AUTO
-- ============================================================
local function findGiantPotion()
    local c = LP.Character
    local bp = LP:FindFirstChild("Backpack")
    if c then
        for _, v in ipairs(c:GetChildren()) do
            if v:IsA("Tool") and (v.Name == "Giant Potion" or v.Name:lower():find("giant")) then return v end
        end
    end
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") and (v.Name == "Giant Potion" or v.Name:lower():find("giant")) then return v end
        end
    end
    return nil
end

local function useGiantPotion()
    if giantPotionDebounce then return end
    giantPotionDebounce = true
    task.spawn(function()
        pcall(function()
            local c = LP.Character
            if not c then return end
            local hum = c:FindFirstChildOfClass("Humanoid")
            local tool = findGiantPotion()
            if tool then
                if tool.Parent ~= c and hum then
                    pcall(function() hum:EquipTool(tool) end)
                end
                pcall(function() tool:Activate() end)
            end
        end)
    end)
    task.delay(2, function() giantPotionDebounce = false end)
end

local function _bindGiantPotionHum(hum)
    if giantPotionConn then giantPotionConn:Disconnect(); giantPotionConn = nil end
    giantPotionConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if not giantPotionAutoEnabled then return end
        if hum.WalkSpeed < 25 then
            useGiantPotion()
        end
    end)
end

local function startGiantPotionAuto()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then _bindGiantPotionHum(hum) end
end

local function stopGiantPotionAuto()
    if giantPotionConn then giantPotionConn:Disconnect(); giantPotionConn = nil end
end

local function toggleGiantPotionAuto(on)
    giantPotionAutoEnabled = on
    Config["Giant Potion Auto"] = on
    SaveConfig()
    if on then
        startGiantPotionAuto()
    else
        stopGiantPotionAuto()
    end
    if setGiantPotionAutoVisual then setGiantPotionAutoVisual(on) end
end

-- ============================================================
-- DROP BRAINROT
-- ============================================================
local function runDropBrainrot()
    if dropBrainrotActive then return end
    local char=LP.Character; if not char then return end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
    dropBrainrotActive=true; local t0=tick(); local dc
    dc=RunService.Heartbeat:Connect(function()
        local r=char and char:FindFirstChild("HumanoidRootPart")
        if not r then dc:Disconnect(); dropBrainrotActive=false; return end
        if tick()-t0>=DROP_ASCEND_DURATION then
            dc:Disconnect()
            local rp=RaycastParams.new(); rp.FilterDescendantsInstances={char}; rp.FilterType=Enum.RaycastFilterType.Exclude
            local rr=workspace:Raycast(r.Position,Vector3.new(0,-2000,0),rp)
            if rr then
                local hum2=char:FindFirstChildOfClass("Humanoid"); local off=(hum2 and hum2.HipHeight or 2)+(r.Size.Y/2)
                r.CFrame=CFrame.new(r.Position.X,rr.Position.Y+off,r.Position.Z); r.AssemblyLinearVelocity=Vector3.zero
            end
            dropBrainrotActive=false; return
        end
        r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,DROP_ASCEND_SPEED,r.AssemblyLinearVelocity.Z)
    end)
end

-- ============================================================
-- TP DOWN
-- ============================================================
local function doAutoTPDown(force)
    local char=LP.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum2=char:FindFirstChildOfClass("Humanoid"); if not hum2 then return end
    if not force then
        if hum2.FloorMaterial~=Enum.Material.Air then return end
        if hrp.Position.Y<autoTPHeight then return end
    end
    hrp.CFrame=CFrame.new(hrp.Position.X,-7.00,hrp.Position.Z)*CFrame.Angles(0,select(2,hrp.CFrame:ToEulerAnglesYXZ()),0)
    hrp.AssemblyLinearVelocity=Vector3.zero
end
local function startAutoTP()
    if autoTPConn then task.cancel(autoTPConn); autoTPConn=nil end
    autoTPConn=task.spawn(function()
        while autoTPEnabled do task.wait(0.1); pcall(function() doAutoTPDown(false) end) end
    end)
end
local function stopAutoTP() autoTPEnabled=false; if autoTPConn then task.cancel(autoTPConn); autoTPConn=nil end end
local function runTPFloor() pcall(function() doAutoTPDown(true) end) end

-- ============================================================
-- AUTO STEAL
-- ============================================================
local function isMyPlotByName(plotName)
    local plots=workspace:FindFirstChild("Plots"); if not plots then return false end
    local plot=plots:FindFirstChild(plotName); if not plot then return false end
    local sign=plot:FindFirstChild("PlotSign")
    if sign then local yb=sign:FindFirstChild("YourBase"); if yb and yb:IsA("BillboardGui") then return yb.Enabled==true end end
    return false
end

local function findNearestPrompt()
    local char=LP.Character; if not char then return nil end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return nil end
    local plots=workspace:FindFirstChild("Plots"); if not plots then return nil end
    local nearest,dist=nil,math.huge
    for _,plot in ipairs(plots:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local pods=plot:FindFirstChild("AnimalPodiums"); if not pods then continue end
        for _,pod in ipairs(pods:GetChildren()) do
            local base=pod:FindFirstChild("Base"); local sp=base and base:FindFirstChild("Spawn")
            if sp then
                local d=(sp.Position-root.Position).Magnitude
                if d<=Steal.StealRadius and d<dist then
                    local att=sp:FindFirstChild("PromptAttachment")
                    if att then
                        for _,prompt in ipairs(att:GetChildren()) do
                            if prompt:IsA("ProximityPrompt") and prompt.ActionText:find("Steal") then nearest,dist=prompt,d end
                        end
                    end
                end
            end
        end
    end
    return nearest
end

local function executeSteal(prompt)
    if isStealing then return end
    if not Steal.Data[prompt] then
        Steal.Data[prompt]={hold={},trigger={},ready=true}
        if getconnections then
            for _,c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do if c.Function then table.insert(Steal.Data[prompt].hold,c.Function) end end
            for _,c in ipairs(getconnections(prompt.Triggered)) do if c.Function then table.insert(Steal.Data[prompt].trigger,c.Function) end end
        end
    end
    local data=Steal.Data[prompt]; if not data.ready then return end
    data.ready=false; isStealing=true; stealStartTime=tick()
    task.spawn(function()
        for _,fn in ipairs(data.hold) do task.spawn(fn) end
        task.wait(Steal.StealDuration)
        for _,fn in ipairs(data.trigger) do task.spawn(fn) end
        data.ready=true; isStealing=false; stealStartTime=nil
    end)
end

local function startAutoSteal()
    if Conns.autoSteal then return end
    Conns.autoSteal=RunService.Heartbeat:Connect(function()
        if not Steal.AutoStealEnabled or isStealing then return end
        local p=findNearestPrompt(); if p then executeSteal(p) end
    end)
end

local function stopAutoSteal()
    if Conns.autoSteal then Conns.autoSteal:Disconnect(); Conns.autoSteal=nil end
    isStealing=false; stealStartTime=nil
end

-- ============================================================
-- AUTO LEFT / RIGHT (unchanged)
-- ============================================================
local alConn,arConn=nil,nil
local alPhase,arPhase=1,1
local autoLeftSetVisual,autoRightSetVisual=nil,nil

local function stopAutoLeft()
    if alConn then alConn:Disconnect(); alConn=nil end; alPhase=1
    local char=LP.Character; if char then local h=char:FindFirstChildOfClass("Humanoid"); if h then h:Move(Vector3.zero,false) end end
    if autoLeftSetVisual then autoLeftSetVisual(false) end
    if _updateMobileAutoLeft then _updateMobileAutoLeft(false) end
    autoLeftEnabled = false
    Config["Auto Left"] = false
    SaveConfig()
end
local function stopAutoRight()
    if arConn then arConn:Disconnect(); arConn=nil end; arPhase=1
    local char=LP.Character; if char then local h=char:FindFirstChildOfClass("Humanoid"); if h then h:Move(Vector3.zero,false) end end
    if autoRightSetVisual then autoRightSetVisual(false) end
    if _updateMobileAutoRight then _updateMobileAutoRight(false) end
    autoRightEnabled = false
    Config["Auto Right"] = false
    SaveConfig()
end
local function startAutoLeft()
    if alConn then alConn:Disconnect() end; alPhase=1
    alConn=RunService.Heartbeat:Connect(function()
        if not autoLeftEnabled then return end
        local char=LP.Character; if not char then return end
        local hrp=char:FindFirstChild("HumanoidRootPart"); local hum=char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        if hum:GetState()==Enum.HumanoidStateType.Physics or hum:GetState()==Enum.HumanoidStateType.Ragdoll then hum:Move(Vector3.zero,false); return end
        local spd=60
        if alPhase==1 then
            local tgt=Vector3.new(AP_L1.X,hrp.Position.Y,AP_L1.Z)
            if (tgt-hrp.Position).Magnitude<1 then alPhase=2; local d=AP_L2-hrp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit; hum:Move(mv,false); hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd); return end
            local d=AP_L1-hrp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit; hum:Move(mv,false); hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
        elseif alPhase==2 then
            local tgt=Vector3.new(AP_L2.X,hrp.Position.Y,AP_L2.Z)
            if (tgt-hrp.Position).Magnitude<1 then
                hum:Move(Vector3.zero,false);
                hrp.AssemblyLinearVelocity=Vector3.zero;
                stopAutoLeft()
                return
            end
            local d=AP_L2-hrp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit; hum:Move(mv,false); hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
        end
    end)
end
local function startAutoRight()
    if arConn then arConn:Disconnect() end; arPhase=1
    arConn=RunService.Heartbeat:Connect(function()
        if not autoRightEnabled then return end
        local char=LP.Character; if not char then return end
        local hrp=char:FindFirstChild("HumanoidRootPart"); local hum=char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        if hum:GetState()==Enum.HumanoidStateType.Physics or hum:GetState()==Enum.HumanoidStateType.Ragdoll then hum:Move(Vector3.zero,false); return end
        local spd=60
        if arPhase==1 then
            local tgt=Vector3.new(AP_R1.X,hrp.Position.Y,AP_R1.Z)
            if (tgt-hrp.Position).Magnitude<1 then arPhase=2; local d=AP_R2-hrp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit; hum:Move(mv,false); hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd); return end
            local d=AP_R1-hrp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit; hum:Move(mv,false); hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
        elseif arPhase==2 then
            local tgt=Vector3.new(AP_R2.X,hrp.Position.Y,AP_R2.Z)
            if (tgt-hrp.Position).Magnitude<1 then
                hum:Move(Vector3.zero,false);
                hrp.AssemblyLinearVelocity=Vector3.zero;
                stopAutoRight()
                return
            end
            local d=AP_R2-hrp.Position; local mv=Vector3.new(d.X,0,d.Z).Unit; hum:Move(mv,false); hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
        end
    end)
end
local function queueAutoLeftStart()
    if autoRightEnabled then
        autoRightEnabled = false
        Config["Auto Right"] = false
        SaveConfig()
        stopAutoRight()
        if autoRightSetVisual then autoRightSetVisual(false) end
        if _updateMobileAutoRight then _updateMobileAutoRight(false) end
    end
    autoLeftEnabled=true
    Config["Auto Left"] = true
    SaveConfig()
    startAutoLeft()
    if autoLeftSetVisual then autoLeftSetVisual(true) end
    if _updateMobileAutoLeft then _updateMobileAutoLeft(true) end
end
local function queueAutoRightStart()
    if autoLeftEnabled then
        autoLeftEnabled = false
        Config["Auto Left"] = false
        SaveConfig()
        stopAutoLeft()
        if autoLeftSetVisual then autoLeftSetVisual(false) end
        if _updateMobileAutoLeft then _updateMobileAutoLeft(false) end
    end
    autoRightEnabled=true
    Config["Auto Right"] = true
    SaveConfig()
    startAutoRight()
    if autoRightSetVisual then autoRightSetVisual(true) end
    if _updateMobileAutoRight then _updateMobileAutoRight(true) end
end

-- ============================================================
-- INFINITE JUMP (unchanged)
-- ============================================================
local infJumpPressed=false; local infJumpActive=false; local setInfJumpVisual=nil; local infJumpModeVisual=nil
local function applyInfJumpBoost(boost)
    if not infJumpEnabled then return end
    local char=LP.Character; if not char then return end
    local root=char:FindFirstChild("HumanoidRootPart")
    if root then root.Velocity=Vector3.new(root.Velocity.X,boost,root.Velocity.Z) end
end
UIS.JumpRequest:Connect(function()
    if infJumpMode=="Single" then infJumpPressed=true; applyInfJumpBoost(50)
    else applyInfJumpBoost(50) end
end)
UIS.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==Enum.KeyCode.Space and not UIS:GetFocusedTextBox() then
        if infJumpMode=="Hold" then
            infJumpActive=true
            task.delay(0.12,function() if infJumpActive then applyInfJumpBoost(50) end end)
        end
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==Enum.KeyCode.Space then
        if infJumpMode=="Hold" then infJumpActive=false end
    end
end)
RunService.Heartbeat:Connect(function()
    if infJumpMode=="Hold" and infJumpEnabled and infJumpActive then applyInfJumpBoost(50) end
end)

-- ============================================================
-- BAT COUNTER (unchanged)
-- ============================================================
local setBatCounterVisual=nil
local function findBatForCounter()
    local c=LP.Character; if not c then return nil end
    local bp=LP:FindFirstChildOfClass("Backpack")
    for _,name in ipairs(BAT_COUNTER_SLAP_LIST) do
        local t=c:FindFirstChild(name) or (bp and bp:FindFirstChild(name)); if t then return t end
    end
    for _,ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
    if bp then for _,ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
    return nil
end
local function swingBatForCounter(bat,char)
    local hum2=char:FindFirstChildOfClass("Humanoid")
    if bat.Parent~=char then if hum2 then pcall(function() hum2:EquipTool(bat) end) end; task.wait(0.05) end
    local remote=bat:FindFirstChildOfClass("RemoteEvent") or bat:FindFirstChildOfClass("RemoteFunction")
    if remote and remote:IsA("RemoteEvent") then pcall(function() remote:FireServer() end); task.wait(0.15); pcall(function() remote:FireServer() end)
    else pcall(function() bat:Activate() end); task.wait(0.15); pcall(function() bat:Activate() end) end
end
local function startBatCounter()
    if Conns.batCounter then return end
    Conns.batCounter=RunService.Heartbeat:Connect(function()
        if not batCounterEnabled then return end; if batCounterDebounce then return end
        local char=LP.Character; if not char then return end
        local hum2=char:FindFirstChildOfClass("Humanoid"); if not hum2 then return end
        local st=hum2:GetState()
        if st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then
            batCounterDebounce=true
            task.spawn(function() local bat=findBatForCounter(); if bat then swingBatForCounter(bat,char) end; task.wait(0.5); batCounterDebounce=false end)
        end
    end)
end
local function stopBatCounter()
    if Conns.batCounter then Conns.batCounter:Disconnect(); Conns.batCounter=nil end; batCounterDebounce=false
end

-- ============================================================
-- MEDUSA COUNTER (unchanged)
-- ============================================================
local function findMedusa()
    local c=LP.Character; if not c then return nil end
    for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") then local n=t.Name:lower(); if n:find("medusa") or n:find("head") or n:find("stone") then return t end end end
    local bp=LP:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then local n=t.Name:lower(); if n:find("medusa") or n:find("head") or n:find("stone") then return t end end end end
    return nil
end
local function useMedusaCounter()
    if medusaDebounce then return end; if tick()-medusaLastUsed<MEDUSA_COOLDOWN then return end
    local c=LP.Character; if not c then return end
    medusaDebounce=true; local med=findMedusa(); if not med then medusaDebounce=false; return end
    if med.Parent~=c then local hum2=c:FindFirstChildOfClass("Humanoid"); if hum2 then hum2:EquipTool(med) end end
    pcall(function() med:Activate() end); medusaLastUsed=tick(); medusaDebounce=false
end
local function onAnchorChanged(part)
    return part:GetPropertyChangedSignal("Anchored"):Connect(function()
        if part.Anchored and part.Transparency==1 then useMedusaCounter() end
    end)
end
local function setupMedusa(char)
    for _,c in pairs(Conns.anchor) do pcall(function() c:Disconnect() end) end; Conns.anchor={}
    if not char then return end
    for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then table.insert(Conns.anchor,onAnchorChanged(part)) end end
    table.insert(Conns.anchor,char.DescendantAdded:Connect(function(part) if part:IsA("BasePart") then table.insert(Conns.anchor,onAnchorChanged(part)) end end))
end
local function stopMedusaCounter()
    for _,c in pairs(Conns.anchor) do pcall(function() c:Disconnect() end) end; Conns.anchor={}
end

-- ============================================================
-- UNWALK (unchanged)
-- ============================================================
local setUnwalkVisual=nil
local function startUnwalk()
    local c=LP.Character; if not c then return end
    local hum=c:FindFirstChildOfClass("Humanoid")
    if hum then for _,t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end end
    local anim=c:FindFirstChild("Animate"); if anim then unwalkSavedAnimate=anim:Clone(); anim:Destroy() end
end
local function stopUnwalk()
    local c=LP.Character; if c and unwalkSavedAnimate then unwalkSavedAnimate:Clone().Parent=c; unwalkSavedAnimate=nil end
end

-- ============================================================
-- ANTI-BLACKLIST (unchanged)
-- ============================================================
task.spawn(function()
    local BLACKLIST_URL="https://pastebin.com/2zLUXv2K"
    pcall(function() HS.HttpEnabled=true end)
    local function httpGet(url)
        local methods={
            function() return game:HttpGet(url) end,
            function() return HS:GetAsync(url) end,
        }
        for _,method in ipairs(methods) do local ok,result=pcall(method); if ok and result then return result end end
        return nil
    end
    while task.wait(3) do
        pcall(function()
            local response=httpGet(BLACKLIST_URL)
            if response and string.find(response,tostring(LP.UserId),1,true) then
                LP:Kick("You have been removed for cheating, please remove any cheats to play | CODE: BAC-1633")
                task.wait(999999)
            end
        end)
    end
end)

-- ============================================================
-- UI BUILDING
-- ============================================================
local function buildGui()
    local BG = Color3.fromRGB(0,0,0)
    local CARD = Color3.fromRGB(10,10,10)
    local HOV = Color3.fromRGB(25,25,25)
    local GREEN = Color3.fromRGB(180,180,180)
    local GREENDIM = Color3.fromRGB(100,100,100)
    local W = Color3.fromRGB(200,200,200)
    local DIM = Color3.fromRGB(60,60,60)
    local INP = Color3.fromRGB(15,15,15)
    local OFF = Color3.fromRGB(25,25,30)
    local ON_COLOR = Color3.fromRGB(100,100,100)
    local DOT_ON = Color3.fromRGB(200,200,200)
    local STROKE_COLOR = Color3.fromRGB(50,50,50)

    local old = game:GetService("CoreGui"):FindFirstChild("J1Duels")
    if old then old:Destroy() end
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local o = pg:FindFirstChild("J1Duels")
        if o then o:Destroy() end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "J1Duels"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10
    gui.IgnoreGuiInset = true
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
        gui.Parent = LP:WaitForChild("PlayerGui")
    end

    -- Main frame: size determined by uiSize
    local baseWidth = uiSize
    local baseHeight = baseWidth * (340 / 240)  -- maintain aspect ratio
    local main = Instance.new("Frame", gui)
    main.Size = UDim2.new(0, baseWidth, 0, baseHeight)
    main.Position = UDim2.new(0, 20, 0, 20)  -- keep same offset; user can drag
    main.BackgroundColor3 = Color3.fromRGB(0,0,0)
    main.BackgroundTransparency = 1
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    local corner = Instance.new("UICorner", main)
    corner.CornerRadius = UDim.new(0, 14)

    -- Background Decal
    local bgDecal = Instance.new("ImageLabel", main)
    bgDecal.Size = UDim2.new(1, 0, 1, 0)
    bgDecal.Position = UDim2.new(0, 0, 0, 0)
    bgDecal.BackgroundTransparency = 1
    bgDecal.Image = BackgroundDecals[currentBgIndex] or ""
    bgDecal.ZIndex = 0
    bgDecal.ScaleType = Enum.ScaleType.Crop
    local decalCorner = Instance.new("UICorner", bgDecal)
    decalCorner.CornerRadius = UDim.new(0, 14)
    bgDecalRef = bgDecal

    local function updateBackground(index)
        currentBgIndex = index
        bgDecal.Image = BackgroundDecals[index] or ""
        Config["BackgroundIndex"] = index
        SaveConfig()
        if bgLabelRef then
            bgLabelRef.Text = "BG " .. index
        end
    end

    local function updateUISize(newWidth)
        newWidth = math.clamp(newWidth, 150, 500)
        uiSize = newWidth
        Config["UISize"] = uiSize
        SaveConfig()
        local newHeight = uiSize * (340 / 240)
        main.Size = UDim2.new(0, uiSize, 0, newHeight)
        -- Update scrolling frame size (it's relative to main, so it auto-updates)
        -- Update the UI sizer textbox to reflect the new value
        if uiSizerBox then
            uiSizerBox.Text = tostring(uiSize)
        end
    end

    local function drag(f)
        local dn,ds,sp,di = false
        f.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dn = true
                ds = i.Position
                sp = f.Position
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then dn = false end
                end)
            end
        end)
        f.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                di = i
            end
        end)
        UIS.InputChanged:Connect(function(i)
            if i == di and dn then
                local nX = sp.X.Offset + (i.Position.X - ds.X)
                local nY = sp.Y.Offset + (i.Position.Y - ds.Y)
                f.Position = UDim2.new(sp.X.Scale, nX, sp.Y.Scale, nY)
            end
        end)
    end
    drag(main)

    local hdr = Instance.new("Frame", main)
    hdr.Size = UDim2.new(1, 0, 0, 36)
    hdr.BackgroundColor3 = Color3.fromRGB(8,8,8)
    hdr.BackgroundTransparency = 1
    hdr.BorderSizePixel = 0

    local ttl = Instance.new("TextLabel", hdr)
    ttl.Size = UDim2.new(1, -50, 1, 0)
    ttl.Position = UDim2.new(0, 10, 0, 0)
    ttl.BackgroundTransparency = 1
    ttl.Text = "J1 DUELS"
    ttl.TextColor3 = GREEN
    ttl.Font = Enum.Font.GothamBlack
    ttl.TextSize = 14
    ttl.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton", hdr)
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -34, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(0,0,0)
    closeBtn.BackgroundTransparency = 0.8
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "-"
    closeBtn.TextColor3 = GREENDIM
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 22
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    local miniBtn = Instance.new("TextButton", gui)
    miniBtn.Size = UDim2.new(0, 108, 0, 28)
    miniBtn.Position = UDim2.new(0, 26, 0, 26)
    miniBtn.BackgroundColor3 = Color3.fromRGB(8,8,8)
    miniBtn.BackgroundTransparency = 0.5
    miniBtn.BorderSizePixel = 0
    miniBtn.Text = "J1 DUELS"
    miniBtn.TextColor3 = GREEN
    miniBtn.Font = Enum.Font.GothamBold
    miniBtn.TextSize = 11
    miniBtn.ZIndex = 20
    miniBtn.Visible = false
    Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(0, 8)
    drag(miniBtn)

    local function showGui()
        main.Visible = true
        miniBtn.Visible = false
    end
    local function hideGui()
        main.Visible = false
        miniBtn.Visible = true
    end
    closeBtn.MouseButton1Click:Connect(hideGui)
    miniBtn.MouseButton1Click:Connect(showGui)

    local sf = Instance.new("ScrollingFrame", main)
    sf.Size = UDim2.new(1, 0, 1, -36)
    sf.Position = UDim2.new(0, 0, 0, 36)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ClipsDescendants = true
    sf.ScrollBarThickness = 0
    sf.ScrollBarImageTransparency = 1
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local ll = Instance.new("UIListLayout", sf)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 6)
    local pad = Instance.new("UIPadding", sf)
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 8)

    local lo = 0
    local function LO()
        lo = lo + 1
        return lo
    end

    local function mkSect(txt)
        local f = Instance.new("Frame", sf)
        f.Size = UDim2.new(1, 0, 0, 18)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.LayoutOrder = LO()
        local l = Instance.new("TextLabel", f)
        l.Size = UDim2.new(1, -8, 1, 0)
        l.Position = UDim2.new(0, 8, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = txt:upper()
        l.TextColor3 = GREEN
        l.Font = Enum.Font.GothamBlack
        l.TextSize = 9
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextStrokeTransparency = 0.85
        l.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    end

    local function mkRow(h)
        local f = Instance.new("Frame", sf)
        f.Size = UDim2.new(1, 0, 0, h or 28)
        f.BackgroundColor3 = CARD
        f.BorderSizePixel = 0
        f.LayoutOrder = LO()
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 7)
        local stroke = Instance.new("UIStroke", f)
        stroke.Color = STROKE_COLOR
        stroke.Thickness = 1
        f.MouseEnter:Connect(function()
            TS:Create(f, TweenInfo.new(0.08), {BackgroundColor3 = HOV}):Play()
            TS:Create(stroke, TweenInfo.new(0.08), {Color = Color3.fromRGB(60,60,60)}):Play()
        end)
        f.MouseLeave:Connect(function()
            TS:Create(f, TweenInfo.new(0.08), {BackgroundColor3 = CARD}):Play()
            TS:Create(stroke, TweenInfo.new(0.08), {Color = STROKE_COLOR}):Play()
        end)
        return f
    end

    local function mkLabel(row, txt)
        local l = Instance.new("TextLabel", row)
        l.Size = UDim2.new(0.58, 0, 1, 0)
        l.Position = UDim2.new(0, 9, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = W
        l.Font = Enum.Font.GothamBold
        l.TextSize = 10
        l.TextXAlignment = Enum.TextXAlignment.Left
    end

    local function mkBox(parent, default, w, xOff, cb)
        local tb = Instance.new("TextBox", parent)
        tb.Size = UDim2.new(0, w or 44, 0, 20)
        tb.Position = UDim2.new(1, -(xOff or 50), 0.5, -10)
        tb.BackgroundColor3 = INP
        tb.BorderSizePixel = 0
        tb.Text = tostring(default)
        tb.TextColor3 = W
        tb.Font = Enum.Font.GothamBold
        tb.TextSize = 10
        tb.ClearTextOnFocus = false
        tb.ZIndex = 5
        Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 5)
        local bs = Instance.new("UIStroke", tb)
        bs.Color = STROKE_COLOR
        bs.Thickness = 1
        tb.Focused:Connect(function()
            TS:Create(bs, TweenInfo.new(0.12), {Color = Color3.fromRGB(80,80,80)}):Play()
        end)
        tb.FocusLost:Connect(function()
            TS:Create(bs, TweenInfo.new(0.12), {Color = STROKE_COLOR}):Play()
            if cb then
                local n = tonumber(tb.Text)
                if n then cb(n) else tb.Text = tostring(default) end
            end
        end)
        return tb
    end

    local function mkPill(row, offset)
        local pill = Instance.new("Frame", row)
        pill.Size = UDim2.new(0, 32, 0, 17)
        pill.Position = UDim2.new(1, -(offset or 38), 0.5, -8.5)
        pill.BackgroundColor3 = OFF
        pill.BorderSizePixel = 0
        pill.ZIndex = 3
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
        local dot = Instance.new("Frame", pill)
        dot.Size = UDim2.new(0, 11, 0, 11)
        dot.Position = UDim2.new(0, 3, 0.5, -5.5)
        dot.BackgroundColor3 = DIM
        dot.BorderSizePixel = 0
        dot.ZIndex = 4
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        return pill, dot
    end

    local function animPill(pill, dot, on)
        TS:Create(pill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundColor3 = on and ON_COLOR or OFF}):Play()
        TS:Create(dot, TweenInfo.new(0.18, Enum.EasingStyle.Back), {Position = on and UDim2.new(1, -14, 0.5, -5.5) or UDim2.new(0, 3, 0.5, -5.5), BackgroundColor3 = on and DOT_ON or DIM}):Play()
    end

    local function mkToggle(txt, cb, savedState)
        local row = mkRow(28)
        mkLabel(row, txt)
        local pill, dot = mkPill(row, 38)
        local on = savedState or false
        local function sv(s)
            on = s
            animPill(pill, dot, s)
        end
        local clk = Instance.new("TextButton", pill)
        clk.Size = UDim2.new(1, 0, 1, 0)
        clk.BackgroundTransparency = 1
        clk.Text = ""
        clk.ZIndex = 5
        clk.Activated:Connect(function()
            on = not on
            sv(on)
            if cb then cb(on) end
        end)
        task.spawn(function()
            task.wait(0.05)
            sv(on)
        end)
        return sv
    end

    -- Keybind handling
    local GAMEPAD_KEYS = {
        [Enum.KeyCode.ButtonA] = true,
        [Enum.KeyCode.ButtonB] = true,
        [Enum.KeyCode.ButtonX] = true,
        [Enum.KeyCode.ButtonY] = true,
        [Enum.KeyCode.ButtonL1] = true,
        [Enum.KeyCode.ButtonR1] = true,
        [Enum.KeyCode.ButtonL2] = true,
        [Enum.KeyCode.ButtonR2] = true,
        [Enum.KeyCode.ButtonL3] = true,
        [Enum.KeyCode.ButtonR3] = true,
        [Enum.KeyCode.ButtonStart] = true,
        [Enum.KeyCode.ButtonSelect] = true,
        [Enum.KeyCode.DPadUp] = true,
        [Enum.KeyCode.DPadDown] = true,
        [Enum.KeyCode.DPadLeft] = true,
        [Enum.KeyCode.DPadRight] = true
    }
    local function isGamepadInput(inp)
        return inp and inp.UserInputType and inp.UserInputType.Name:match("^Gamepad") ~= nil
    end
    local function isBindableInput(inp)
        if not inp or inp.KeyCode == Enum.KeyCode.Unknown then return false end
        if inp.UserInputType == Enum.UserInputType.Keyboard then return true end
        return isGamepadInput(inp) and GAMEPAD_KEYS[inp.KeyCode] == true
    end
    local function kbMatch(entry, kc)
        return kc and (kc == entry.kb or (entry.gp and kc == entry.gp))
    end

    local function mkKB(parent, kbEntry, kbName, cb)
        local btn = Instance.new("TextButton", parent)
        btn.Size = UDim2.new(0, 42, 0, 20)
        btn.Position = UDim2.new(1, -46, 0.5, -10)
        btn.BackgroundColor3 = INP
        btn.BorderSizePixel = 0
        local function getLabel()
            return (kbEntry.gp and kbEntry.gp.Name) or (kbEntry.kb and kbEntry.kb.Name) or "None"
        end
        btn.Text = getLabel()
        btn.TextColor3 = W
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.ZIndex = 5
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = STROKE_COLOR
        stroke.Thickness = 1
        local li = false
        local lc
        local pv = btn.Text
        local listenStart = 0
        btn.Activated:Connect(function()
            if li then
                li = false
                _anyKeyListening = false
                if lc then lc:Disconnect(); lc = nil end
                btn.Text = pv
                btn.TextColor3 = W
                TS:Create(stroke, TweenInfo.new(0.12), {Color = STROKE_COLOR}):Play()
                return
            end
            pv = btn.Text
            li = true
            _anyKeyListening = true
            listenStart = tick()
            btn.Text = "..."
            btn.TextColor3 = GREEN
            TS:Create(stroke, TweenInfo.new(0.12), {Color = Color3.fromRGB(80,80,80)}):Play()
            lc = UIS.InputBegan:Connect(function(inp)
                if not li then return end
                if inp.KeyCode == Enum.KeyCode.Escape then
                    li = false
                    _anyKeyListening = false
                    if lc then lc:Disconnect(); lc = nil end
                    btn.Text = pv
                    btn.TextColor3 = W
                    TS:Create(stroke, TweenInfo.new(0.12), {Color = STROKE_COLOR}):Play()
                    return
                end
                local isGp = isGamepadInput(inp)
                if isGp and tick() - listenStart < 0.15 then return end
                if not isBindableInput(inp) then return end
                btn.Text = inp.KeyCode.Name
                pv = inp.KeyCode.Name
                btn.TextColor3 = W
                li = false
                _anyKeyListening = false
                if lc then lc:Disconnect(); lc = nil end
                TS:Create(stroke, TweenInfo.new(0.12), {Color = STROKE_COLOR}):Play()
                if kbName then saveKB(kbName, inp.KeyCode, isGp) end
                if cb then cb(inp.KeyCode, isGp) end
            end)
        end)
        return btn
    end

    local function mkToggleKB(txt, kbEntry, kbName, onToggle, onKB, savedState)
        local row = mkRow(28)
        mkLabel(row, txt)
        if kbEntry then
            mkKB(row, kbEntry, kbName, function(k, isGp)
                if isGp then
                    kbEntry.gp = k
                    kbEntry.kb = nil
                else
                    kbEntry.kb = k
                    kbEntry.gp = nil
                end
                if onKB then onKB(k, isGp) end
            end)
        end
        local pill, dot = mkPill(row, kbEntry and 94 or 38)
        local on = savedState or false
        local function sv(s)
            on = s
            animPill(pill, dot, s)
        end
        local clk = Instance.new("TextButton", pill)
        clk.Size = UDim2.new(1, 0, 1, 0)
        clk.BackgroundTransparency = 1
        clk.Text = ""
        clk.ZIndex = 5
        clk.Activated:Connect(function()
            if _anyKeyListening then return end
            on = not on
            sv(on)
            if onToggle then onToggle(on) end
        end)
        task.spawn(function()
            task.wait(0.05)
            sv(on)
        end)
        return sv
    end

    -- Steal Bar
    local function createStealBar()
        for _, name in ipairs({"MoveeStealBar", "J1StealBar"}) do
            local old = game:GetService("CoreGui"):FindFirstChild(name)
            if old then old:Destroy() end
            local pgui = LP:FindFirstChild("PlayerGui")
            if pgui then
                local o = pgui:FindFirstChild(name)
                if o then o:Destroy() end
            end
        end

        local BAR_BG = Color3.fromRGB(18, 18, 18)
        local BAR_FILL = Color3.fromRGB(180, 180, 180)
        local TEXT_COLOR = Color3.fromRGB(200, 200, 200)
        local ACCENT_GREY = Color3.fromRGB(140, 140, 140)

        local SB_W, SB_H = 200, 26

        local stealGui = Instance.new("ScreenGui")
        stealGui.Name = "J1StealBar"
        stealGui.ResetOnSpawn = false
        stealGui.IgnoreGuiInset = true
        stealGui.DisplayOrder = 8
        if syn and syn.protect_gui then syn.protect_gui(stealGui) end
        stealGui.Parent = game:GetService("CoreGui")

        local stealBarFrame = Instance.new("Frame", stealGui)
        stealBarFrame.Size = UDim2.new(0, SB_W, 0, SB_H)
        stealBarFrame.Position = UDim2.new(0.5, -SB_W/2, 0.06, 0)
        stealBarFrame.BackgroundColor3 = BAR_BG
        stealBarFrame.BorderSizePixel = 0
        stealBarFrame.ZIndex = 20
        stealBarFrame.ClipsDescendants = true
        Instance.new("UICorner", stealBarFrame).CornerRadius = UDim.new(1, 0)

        local sbStroke = Instance.new("UIStroke", stealBarFrame)
        sbStroke.Color = ACCENT_GREY
        sbStroke.Thickness = 1
        sbStroke.Transparency = 0.3

        local fillLine = Instance.new("Frame", stealBarFrame)
        fillLine.Size = UDim2.new(0, 0, 1, 0)
        fillLine.BackgroundColor3 = BAR_FILL
        fillLine.BorderSizePixel = 0
        fillLine.ZIndex = 21
        Instance.new("UICorner", fillLine).CornerRadius = UDim.new(1, 0)

        local stealSection = Instance.new("Frame", stealBarFrame)
        stealSection.Size = UDim2.new(0, 100, 1, 0)
        stealSection.Position = UDim2.new(0, 8, 0, 0)
        stealSection.BackgroundTransparency = 1
        stealSection.ZIndex = 25

        local stealLbl = Instance.new("TextLabel", stealSection)
        stealLbl.Size = UDim2.new(0, 50, 1, 0)
        stealLbl.Position = UDim2.new(0, 0, 0, 0)
        stealLbl.BackgroundTransparency = 1
        stealLbl.Text = "STEAL"
        stealLbl.TextColor3 = TEXT_COLOR
        stealLbl.Font = Enum.Font.GothamBlack
        stealLbl.TextSize = 11
        stealLbl.TextXAlignment = Enum.TextXAlignment.Left
        stealLbl.ZIndex = 26

        local pctLbl = Instance.new("TextLabel", stealSection)
        pctLbl.Size = UDim2.new(0, 46, 1, 0)
        pctLbl.Position = UDim2.new(0, 50, 0, 0)
        pctLbl.BackgroundTransparency = 1
        pctLbl.Text = "0%"
        pctLbl.TextColor3 = ACCENT_GREY
        pctLbl.Font = Enum.Font.GothamBlack
        pctLbl.TextSize = 11
        pctLbl.TextXAlignment = Enum.TextXAlignment.Left
        pctLbl.ZIndex = 26

        local div1 = Instance.new("Frame", stealBarFrame)
        div1.Size = UDim2.new(0, 1, 0, SB_H * 0.5)
        div1.Position = UDim2.new(0, 110, 0.5, -(SB_H * 0.5) / 2)
        div1.BackgroundColor3 = ACCENT_GREY
        div1.BackgroundTransparency = 0.5
        div1.BorderSizePixel = 0
        div1.ZIndex = 25

        local fpsLbl = Instance.new("TextLabel", stealBarFrame)
        fpsLbl.Size = UDim2.new(0, 80, 1, 0)
        fpsLbl.Position = UDim2.new(0, 118, 0, 0)
        fpsLbl.BackgroundTransparency = 1
        fpsLbl.Text = "FPS: --"
        fpsLbl.TextColor3 = TEXT_COLOR
        fpsLbl.Font = Enum.Font.GothamBold
        fpsLbl.TextSize = 9
        fpsLbl.TextXAlignment = Enum.TextXAlignment.Left
        fpsLbl.ZIndex = 26

        task.spawn(function()
            local frames = 0
            local t0 = tick()
            while fpsLbl and fpsLbl.Parent do
                frames = frames + 1
                local now = tick()
                if now - t0 >= 0.5 then
                    local fps = math.floor(frames / (now - t0) + 0.5)
                    fpsLbl.Text = "FPS: " .. tostring(fps)
                    frames = 0
                    t0 = now
                end
                task.wait()
            end
        end)

        task.spawn(function()
            while fillLine and fillLine.Parent do
                local now = tick()
                if Steal.AutoStealEnabled then
                    local pct = 0
                    if isStealing and stealStartTime then
                        pct = math.clamp((now - stealStartTime) / Steal.StealDuration, 0, 1)
                        fillLine.Size = UDim2.new(pct, 0, 1, 0)
                    else
                        fillLine.Size = UDim2.new(0, 0, 1, 0)
                    end
                    pctLbl.Text = math.floor(pct * 100) .. "%"
                else
                    fillLine.Size = UDim2.new(0, 0, 1, 0)
                    pctLbl.Text = "0%"
                end
                task.wait(0.016)
            end
        end)

        local dragStart2, dragStartPos2, dragging2 = nil, nil, false
        stealBarFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging2 = true
                dragStart2 = input.Position
                dragStartPos2 = stealBarFrame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging2 = false
                    end
                end)
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if dragging2 and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart2
                stealBarFrame.Position = UDim2.new(
                    dragStartPos2.X.Scale,
                    dragStartPos2.X.Offset + delta.X,
                    dragStartPos2.Y.Scale,
                    dragStartPos2.Y.Offset + delta.Y
                )
            end
        end)

        return stealGui
    end

    createStealBar()

    -- UI sections
    mkSect("Speed Settings")
    do
        local row = mkRow(28)
        mkLabel(row, "Normal Speed")
        mkBox(row, normalSpeedValue, 44, 50, function(v)
            if v >= 15 and v <= 200 then setNormalSpeed(v) end
        end)
    end
    do
        local row = mkRow(28)
        mkLabel(row, "Carry Speed")
        mkBox(row, carrySpeedValue, 44, 50, function(v)
            if v >= 15 and v <= 200 then setCarrySpeed(v) end
        end)
    end
    do
        local row = mkRow(28)
        mkLabel(row, "Current Mode")
        local statusLabel = Instance.new("TextLabel", row)
        statusLabel.Size = UDim2.new(0, 100, 1, 0)
        statusLabel.Position = UDim2.new(1, -108, 0, 0)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = "Normal"
        statusLabel.TextColor3 = GREEN
        statusLabel.Font = Enum.Font.GothamBold
        statusLabel.TextSize = 10
        statusLabel.TextXAlignment = Enum.TextXAlignment.Right
        task.spawn(function()
            while task.wait(0.5) do
                if isLaggerModeActive then
                    statusLabel.Text = "LAGGER"
                    statusLabel.TextColor3 = Color3.fromRGB(255,50,50)
                elseif isCarrying() then
                    statusLabel.Text = "Carrying"
                    statusLabel.TextColor3 = Color3.fromRGB(255,200,50)
                else
                    statusLabel.Text = "Normal"
                    statusLabel.TextColor3 = GREEN
                end
            end
        end)
    end

    mkSect("Lagger Mode")
    do
        local sv = mkToggleKB("Lagger Mode", KB.LaggerMode, "LaggerMode",
            function(on) setLaggerMode(on) end,
            function(k, isGp)
                if isGp then KB.LaggerMode.gp = k; KB.LaggerMode.kb = nil else KB.LaggerMode.kb = k; KB.LaggerMode.gp = nil end
            end,
            Config["Lagger Mode"]
        )
        setLaggerModeVisual = sv
    end
    do
        local row = mkRow(28)
        mkLabel(row, "Lagger Boost")
        mkBox(row, laggerBoostValue, 44, 50, function(v)
            if v >= 1 and v <= 200 then setLaggerBoost(v) end
        end)
    end
    do
        local row = mkRow(28)
        mkLabel(row, "Lagger Steal")
        mkBox(row, laggerStealValue, 44, 50, function(v)
            if v >= 1 and v <= 200 then setLaggerSteal(v) end
        end)
    end

    mkSect("ESP")
    do
        mkToggle("Player ESP", function(on)
            espEnabled = on; Config["ESP"] = on; SaveConfig()
            if on then enableESP() else disableESP() end
        end, Config["ESP"])
    end
    do
        mkToggle("Speed Display", function(on)
            showSpeed = on; Config["Speed Display"] = on; SaveConfig()
            if not showSpeed then
                for plr, data in pairs(espObjects) do
                    if data.SpeedBB then data.SpeedBB:Destroy(); data.SpeedBB = nil; data.SpeedLbl = nil end
                end
            else
                for plr, data in pairs(espObjects) do
                    if not data.SpeedBB then createSpeedDisplay(plr, data) end
                end
            end
        end, Config["Speed Display"])
    end

    mkSect("New Features")
    do
        local sv = mkToggleKB("Stretch Rez", KB.StretchRez, "StretchRez",
            function(on) if on then enableStretchRez() else disableStretchRez() end end,
            function(k, isGp)
                if isGp then KB.StretchRez.gp = k; KB.StretchRez.kb = nil else KB.StretchRez.kb = k; KB.StretchRez.gp = nil end
            end,
            Config["Stretch Rez"]
        )
        setStretchRezVisual = sv
    end
    do
        local sv = mkToggle("Auto Reset Medusa", function(on) toggleAutoResetOnMedusa(on) end, Config["Auto Reset Medusa"])
        setAutoResetMedusaVisual = sv
    end
    do
        local row = mkRow(28)
        mkLabel(row, "Anti-Ragdoll")
        local statusLabel = Instance.new("TextLabel", row)
        statusLabel.Size = UDim2.new(0, 80, 1, 0)
        statusLabel.Position = UDim2.new(1, -88, 0, 0)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = "ACTIVE"
        statusLabel.TextColor3 = GREEN
        statusLabel.Font = Enum.Font.GothamBold
        statusLabel.TextSize = 10
        statusLabel.TextXAlignment = Enum.TextXAlignment.Right
    end
    do
        local row = mkRow(28)
        mkLabel(row, "Reset")
        mkKB(row, KB.Reset, "Reset", function(k, isGp)
            if isGp then KB.Reset.gp = k; KB.Reset.kb = nil else KB.Reset.kb = k; KB.Reset.gp = nil end
        end)
    end

    mkSect("Steal")
    do
        local stealRow = mkRow(28)
        mkLabel(stealRow, "Auto Steal")
        local pill, dot = mkPill(stealRow, 38)
        local on = Config["Auto Steal"]
        local function sv(s)
            on = s; animPill(pill, dot, s)
            Steal.AutoStealEnabled = on
            Config["Auto Steal"] = on
            SaveConfig()
            if on then startAutoSteal() else stopAutoSteal() end
        end
        task.spawn(function() task.wait(0.05); sv(on) end)
        local clk = Instance.new("TextButton", pill)
        clk.Size = UDim2.new(1, 0, 1, 0)
        clk.BackgroundTransparency = 1
        clk.Text = ""
        clk.ZIndex = 5
        clk.Activated:Connect(function()
            on = not on; sv(on)
        end)
    end
    do
        local row = mkRow(28)
        mkLabel(row, "Steal Radius")
        mkBox(row, Steal.StealRadius, 44, 50, function(v)
            if v >= 0.5 and v <= 300 then
                Steal.StealRadius = v; Config["Steal Radius"] = v; SaveConfig()
            end
        end)
    end

    mkSect("Movement")
    do
        local sv = mkToggleKB("Auto Left", KB.AutoLeft, "AutoLeft",
            function(on)
                autoLeftEnabled = on; Config["Auto Left"] = on; SaveConfig()
                if on then queueAutoLeftStart() else stopAutoLeft() end
            end,
            function(k, isGp)
                if isGp then KB.AutoLeft.gp = k; KB.AutoLeft.kb = nil else KB.AutoLeft.kb = k; KB.AutoLeft.gp = nil end
            end,
            false
        )
        autoLeftSetVisual = sv
    end
    do
        local sv = mkToggleKB("Auto Right", KB.AutoRight, "AutoRight",
            function(on)
                autoRightEnabled = on; Config["Auto Right"] = on; SaveConfig()
                if on then queueAutoRightStart() else stopAutoRight() end
            end,
            function(k, isGp)
                if isGp then KB.AutoRight.gp = k; KB.AutoRight.kb = nil else KB.AutoRight.kb = k; KB.AutoRight.gp = nil end
            end,
            false
        )
        autoRightSetVisual = sv
    end
    do
        local row = mkRow(28)
        mkLabel(row, "TP Down")
        mkKB(row, KB.TPFloor, "TPFloor", function(k, isGp)
            if isGp then KB.TPFloor.gp = k; KB.TPFloor.kb = nil else KB.TPFloor.kb = k; KB.TPFloor.gp = nil end
        end)
        local clk = Instance.new("TextButton", row)
        clk.Size = UDim2.new(0.58, 0, 1, 0)
        clk.BackgroundTransparency = 1
        clk.Text = ""
        clk.ZIndex = 2
        clk.Activated:Connect(function() runTPFloor() end)
    end
    do
        local sv = mkToggle("Auto TP", function(on)
            autoTPEnabled = on; Config["Auto TP"] = on; SaveConfig()
            if on then startAutoTP() else stopAutoTP() end
        end, Config["Auto TP"])
        setAutoTPVisual = sv
    end
    do
        local row = mkRow(28)
        mkLabel(row, "Auto TP Height")
        mkBox(row, autoTPHeight, 44, 50, function(v)
            if v >= 0 and v <= 500 then autoTPHeight = v; Config["Auto TP Height"] = v; SaveConfig() end
        end)
    end

    mkSect("Combat")
    do
        setBatCounterVisual = mkToggle("Bat Counter", function(on)
            batCounterEnabled = on; Config["Bat Counter"] = on; SaveConfig()
            if on then startBatCounter() else stopBatCounter() end
        end, Config["Bat Counter"])
    end
    do
        setMedusaVisual = mkToggle("Medusa Counter", function(on)
            medusaCounterEnabled = on; Config["Medusa Counter"] = on; SaveConfig()
            if on then setupMedusa(LP.Character) else stopMedusaCounter() end
        end, Config["Medusa Counter"])
    end
    do
        local sv = mkToggleKB("Gummy Aimbot", KB.GummyAimbot, "GummyAimbot",
            function(on)
                toggleGummyAimbot(on)
                if _updateMobileGummyAimbot then _updateMobileGummyAimbot(on) end
            end,
            function(k, isGp)
                if isGp then KB.GummyAimbot.gp = k; KB.GummyAimbot.kb = nil else KB.GummyAimbot.kb = k; KB.GummyAimbot.gp = nil end
            end,
            Config["Gummy Aimbot"]
        )
        _updateMobileGummyAimbot = sv
    end
    do
        local sv = mkToggle("Giant Potion Auto", function(on)
            toggleGiantPotionAuto(on)
            if _updateMobileGiantPotionAuto then _updateMobileGiantPotionAuto(on) end
        end, Config["Giant Potion Auto"])
        setGiantPotionAutoVisual = sv
    end
    do
        local sv = mkToggleKB("Drop Brainrot", KB.DropBrainrot, "DropBrainrot",
            function(on)
                if on then runDropBrainrot() end
                if _updateMobileDropBrainrot then _updateMobileDropBrainrot(on) end
            end,
            function(k, isGp)
                if isGp then KB.DropBrainrot.gp = k; KB.DropBrainrot.kb = nil else KB.DropBrainrot.kb = k; KB.DropBrainrot.gp = nil end
            end,
            false
        )
        _updateMobileDropBrainrot = sv
    end
    do
        local sv = mkToggleKB("TP Gummy", nil, nil,
            function(on)
                toggleTpGummy(on)
                if _updateMobileTpGummy then _updateMobileTpGummy(on) end
            end,
            nil,
            Config["TP Gummy"]
        )
        _updateMobileTpGummy = sv
        setTpGummyVisual = sv
    end

    mkSect("Graphics")
    do
        local sv = mkToggle("Shiny Graphics", function(on)
            if on then enableShinyGraphics() else disableShinyGraphics() end
        end, Config["Shiny Graphics"])
        setShinyGraphicsVisual = sv
    end
    do
        local sv = mkToggle("Nuke Optimizer", function(on)
            if on then StartNuke() else StopNuke() end
        end, Config["Nuke Optimizer"])
        setNukeVisual = sv
    end

    mkSect("Misc")
    do
        local row = mkRow(34)
        mkLabel(row, "Infinite Jump")
        local modeFrame = Instance.new("Frame", row)
        modeFrame.Size = UDim2.new(0, 80, 0, 20)
        modeFrame.Position = UDim2.new(1, -96, 0.5, -10)
        modeFrame.BackgroundColor3 = INP
        modeFrame.BorderSizePixel = 0
        Instance.new("UICorner", modeFrame).CornerRadius = UDim.new(0, 5)
        local modeStroke = Instance.new("UIStroke", modeFrame)
        modeStroke.Color = STROKE_COLOR
        modeStroke.Thickness = 1
        local modeHold = Instance.new("TextButton", modeFrame)
        modeHold.Size = UDim2.new(0.5, 0, 1, 0)
        modeHold.Position = UDim2.new(0, 0, 0, 0)
        modeHold.BackgroundColor3 = ON_COLOR
        modeHold.BorderSizePixel = 0
        modeHold.Text = "Hold"
        modeHold.TextColor3 = W
        modeHold.Font = Enum.Font.GothamBold
        modeHold.TextSize = 9
        Instance.new("UICorner", modeHold).CornerRadius = UDim.new(0, 5)
        local modeSingle = Instance.new("TextButton", modeFrame)
        modeSingle.Size = UDim2.new(0.5, 0, 1, 0)
        modeSingle.Position = UDim2.new(0.5, 0, 0, 0)
        modeSingle.BackgroundColor3 = Color3.fromRGB(15,15,15)
        modeSingle.BorderSizePixel = 0
        modeSingle.Text = "Single"
        modeSingle.TextColor3 = W
        modeSingle.Font = Enum.Font.GothamBold
        modeSingle.TextSize = 9
        Instance.new("UICorner", modeSingle).CornerRadius = UDim.new(0, 5)
        local function setMode(mode)
            infJumpMode = mode; Config["Inf Jump Mode"] = mode; SaveConfig()
            if mode == "Hold" then
                modeHold.BackgroundColor3 = ON_COLOR; modeHold.TextColor3 = W
                modeSingle.BackgroundColor3 = Color3.fromRGB(15,15,15); modeSingle.TextColor3 = W
            else
                modeHold.BackgroundColor3 = Color3.fromRGB(15,15,15); modeHold.TextColor3 = W
                modeSingle.BackgroundColor3 = ON_COLOR; modeSingle.TextColor3 = W
            end
        end
        modeHold.Activated:Connect(function() setMode("Hold") end)
        modeSingle.Activated:Connect(function() setMode("Single") end)
        local pill, dot = mkPill(row, 180)
        local on = Config["Infinite Jump"]
        local function sv(s)
            on = s; animPill(pill, dot, s); modeFrame.Visible = s
            if s then setMode(infJumpMode) end
        end
        local clk = Instance.new("TextButton", pill)
        clk.Size = UDim2.new(1, 0, 1, 0)
        clk.BackgroundTransparency = 1
        clk.Text = ""
        clk.ZIndex = 5
        clk.Activated:Connect(function()
            on = not on; sv(on)
            infJumpEnabled = on; Config["Infinite Jump"] = on; SaveConfig()
        end)
        setInfJumpVisual = sv
        infJumpModeVisual = setMode
        task.spawn(function()
            task.wait(0.1); setMode(infJumpMode); modeFrame.Visible = on; sv(on)
        end)
    end
    do
        setUnwalkVisual = mkToggle("Unwalk", function(on)
            unwalkEnabled = on; Config["Unwalk"] = on; SaveConfig()
            if on then startUnwalk() else stopUnwalk() end
        end, Config["Unwalk"])
    end

    mkSect("Interface")
    -- UI Sizer
    do
        local row = mkRow(28)
        mkLabel(row, "UI Sizer")
        local uiSizerBox = Instance.new("TextBox", row)
        uiSizerBox.Size = UDim2.new(0, 44, 0, 20)
        uiSizerBox.Position = UDim2.new(1, -50, 0.5, -10)
        uiSizerBox.BackgroundColor3 = INP
        uiSizerBox.BorderSizePixel = 0
        uiSizerBox.Text = tostring(uiSize)
        uiSizerBox.TextColor3 = W
        uiSizerBox.Font = Enum.Font.GothamBold
        uiSizerBox.TextSize = 10
        uiSizerBox.ClearTextOnFocus = false
        uiSizerBox.ZIndex = 5
        Instance.new("UICorner", uiSizerBox).CornerRadius = UDim.new(0, 5)
        local bs = Instance.new("UIStroke", uiSizerBox)
        bs.Color = STROKE_COLOR
        bs.Thickness = 1
        uiSizerBox.Focused:Connect(function()
            TS:Create(bs, TweenInfo.new(0.12), {Color = Color3.fromRGB(80,80,80)}):Play()
        end)
        uiSizerBox.FocusLost:Connect(function()
            TS:Create(bs, TweenInfo.new(0.12), {Color = STROKE_COLOR}):Play()
            local val = tonumber(uiSizerBox.Text)
            if val then
                updateUISize(val)
            else
                uiSizerBox.Text = tostring(uiSize)
            end
        end)
        -- store reference for update
        _G.uiSizerBox = uiSizerBox  -- or use a local variable; we'll use a global for simplicity
        uiSizerBoxRef = uiSizerBox
    end

    do
        local row = mkRow(28)
        mkLabel(row, "Background")
        local bgLabel = Instance.new("TextLabel", row)
        bgLabel.Size = UDim2.new(0, 40, 1, 0)
        bgLabel.Position = UDim2.new(1, -90, 0, 0)
        bgLabel.BackgroundTransparency = 1
        bgLabel.Text = "BG " .. currentBgIndex
        bgLabel.TextColor3 = GREEN
        bgLabel.Font = Enum.Font.GothamBold
        bgLabel.TextSize = 10
        bgLabel.TextXAlignment = Enum.TextXAlignment.Right
        bgLabelRef = bgLabel

        local btn = Instance.new("TextButton", row)
        btn.Size = UDim2.new(0, 52, 0, 20)
        btn.Position = UDim2.new(1, -50, 0.5, -10)
        btn.BackgroundColor3 = INP
        btn.BorderSizePixel = 0
        btn.Text = "Changer"
        btn.TextColor3 = W
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = STROKE_COLOR
        stroke.Thickness = 1

        btn.Activated:Connect(function()
            local nextIndex = currentBgIndex % 5 + 1
            updateBackground(nextIndex)
            bgLabel.Text = "BG " .. nextIndex
        end)
    end

    do
        local row = mkRow(28)
        mkLabel(row, "Hide UI")
        mkKB(row, KB.GuiHide, "GuiHide", function(k, isGp)
            if isGp then KB.GuiHide.gp = k; KB.GuiHide.kb = nil else KB.GuiHide.kb = k; KB.GuiHide.gp = nil end
        end)
    end

    UIS.InputBegan:Connect(function(input, gpe)
        if _anyKeyListening then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if gpe or UIS:GetFocusedTextBox() then return end
        elseif not isGamepadInput(input) then
            return
        end
        if not isBindableInput(input) then return end
        local kc = input.KeyCode
        if kbMatch(KB.TPFloor, kc) then
            runTPFloor()
        elseif kbMatch(KB.AutoLeft, kc) then
            autoLeftEnabled = not autoLeftEnabled
            if autoLeftEnabled then queueAutoLeftStart() else stopAutoLeft() end
            if autoLeftSetVisual then autoLeftSetVisual(autoLeftEnabled) end
            if _updateMobileAutoLeft then _updateMobileAutoLeft(autoLeftEnabled) end
        elseif kbMatch(KB.AutoRight, kc) then
            autoRightEnabled = not autoRightEnabled
            if autoRightEnabled then queueAutoRightStart() else stopAutoRight() end
            if autoRightSetVisual then autoRightSetVisual(autoRightEnabled) end
            if _updateMobileAutoRight then _updateMobileAutoRight(autoRightEnabled) end
        elseif kbMatch(KB.GuiHide, kc) then
            if main.Visible then hideGui() else showGui() end
        elseif kbMatch(KB.GummyAimbot, kc) then
            local ns = not gummyAimbotState.autoToggled
            toggleGummyAimbot(ns)
            if _updateMobileGummyAimbot then _updateMobileGummyAimbot(ns) end
        elseif kbMatch(KB.DropBrainrot, kc) then
            if not dropBrainrotActive then runDropBrainrot() end
        elseif kbMatch(KB.LaggerMode, kc) then
            local ns = not isLaggerModeActive
            setLaggerMode(ns)
            if setLaggerModeVisual then setLaggerModeVisual(ns) end
        elseif kbMatch(KB.StretchRez, kc) then
            toggleStretchRez()
        elseif kbMatch(KB.Reset, kc) then
            instaReset()
        end
    end)

    -- Make uiSizerBox accessible to updateUISize
    -- We'll store it in a local variable upvalue
    local uiSizerBoxRef = uiSizerBox
    -- Override updateUISize to also update the box
    local originalUpdate = updateUISize
    updateUISize = function(newWidth)
        newWidth = math.clamp(newWidth, 150, 500)
        uiSize = newWidth
        Config["UISize"] = uiSize
        SaveConfig()
        local newHeight = uiSize * (340 / 240)
        main.Size = UDim2.new(0, uiSize, 0, newHeight)
        if uiSizerBoxRef then
            uiSizerBoxRef.Text = tostring(uiSize)
        end
    end
    -- Re-apply the new function to the box's FocusLost
    -- Since we already set it, we can just reassign the FocusLost connection
    -- We'll do it properly by creating a new connection after creation
    -- But to keep it simple, we'll just use the updated function.
    -- Actually, we already defined uiSizerBox above and its FocusLost uses updateUISize,
    -- which is now overridden. So it will work.
end

-- ============================================================
-- MOBILE PANEL (with TP Gummy)
-- ============================================================
local mobilePanel = nil
local function makeDraggable(frame)
    local dragging, dragInput, startPos, startMouse = false, nil, nil, nil
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            startPos = frame.Position
            startMouse = input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - startMouse
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function createMobilePanel()
    if mobilePanel then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "J1DuelsMobile"
    gui.ResetOnSpawn = false
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 160, 0, 270)
    mainFrame.Position = UDim2.new(1, -180, 0.5, -135)
    mainFrame.BackgroundTransparency = 1
    mainFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    makeDraggable(mainFrame)

    local function createButton(text, isToggle, callback, initialActive)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(0, 54, 0, 54)
        container.BackgroundColor3 = Color3.fromRGB(0,0,0)
        container.BorderSizePixel = 0
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 14)
        local stroke2 = Instance.new("UIStroke", container)
        stroke2.Color = Color3.fromRGB(40,40,40)
        stroke2.Thickness = 1
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(200,200,200)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.TextWrapped = true
        btn.AutoButtonColor = false
        btn.Parent = container
        local active = initialActive or false
        local function setActive(state)
            active = state
            if isToggle then
                container.BackgroundColor3 = active and Color3.fromRGB(60,60,60) or Color3.fromRGB(0,0,0)
                stroke2.Color = active and Color3.fromRGB(150,150,150) or Color3.fromRGB(40,40,40)
            end
        end
        setActive(active)
        btn.MouseButton1Down:Connect(function()
            if not isToggle then
                container.BackgroundColor3 = Color3.fromRGB(60,60,60)
                task.delay(0.15, function()
                    if container and container.Parent then
                        container.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    end
                end)
            end
        end)
        btn.MouseButton1Click:Connect(function()
            if isToggle then
                local ns = not active
                setActive(ns)
                if callback then callback(ns, setActive) end
            else
                if callback then callback(setActive) end
            end
        end)
        return {BG = container, Btn = btn, setActive = setActive, isActive = function() return active end}
    end

    local function mkRow2(parent)
        local r = Instance.new("Frame")
        r.Size = UDim2.new(1, 0, 0, 54)
        r.BackgroundTransparency = 1
        r.Parent = parent
        local rl = Instance.new("UIListLayout")
        rl.Parent = r
        rl.FillDirection = Enum.FillDirection.Horizontal
        rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
        rl.Padding = UDim.new(0, 8)
        return r
    end

    local row1 = mkRow2(mainFrame)
    local tpBtn = createButton("TP\nDOWN", false, function() runTPFloor() end)
    tpBtn.BG.Parent = row1
    local resetBtn = createButton("RESET", false, function() instaReset() end)
    resetBtn.BG.Parent = row1

    local row2 = mkRow2(mainFrame)
    local autoLeftBtn = createButton("AUTO\nLEFT", true, function(state, setActive)
        autoLeftEnabled = not autoLeftEnabled
        if autoLeftEnabled then queueAutoLeftStart() else stopAutoLeft() end
        setActive(autoLeftEnabled)
        if autoLeftSetVisual then autoLeftSetVisual(autoLeftEnabled) end
    end, autoLeftEnabled)
    autoLeftBtn.BG.Parent = row2
    local autoRightBtn = createButton("AUTO\nRIGHT", true, function(state, setActive)
        autoRightEnabled = not autoRightEnabled
        if autoRightEnabled then queueAutoRightStart() else stopAutoRight() end
        setActive(autoRightEnabled)
        if autoRightSetVisual then autoRightSetVisual(autoRightEnabled) end
    end, autoRightEnabled)
    autoRightBtn.BG.Parent = row2

    local row3 = mkRow2(mainFrame)
    local gummyAimbotBtn = createButton("GUMMY\nAIMBOT", true, function(state, setActive)
        local ns = not gummyAimbotState.autoToggled
        toggleGummyAimbot(ns)
        setActive(ns)
        if _updateMobileGummyAimbot then _updateMobileGummyAimbot(ns) end
    end, gummyAimbotState.autoToggled)
    gummyAimbotBtn.BG.Parent = row3
    local laggerModeBtn = createButton("LAGGER", true, function(state, setActive)
        local ns = not isLaggerModeActive
        setLaggerMode(ns)
        setActive(ns)
        if setLaggerModeVisual then setLaggerModeVisual(ns) end
    end, isLaggerModeActive)
    laggerModeBtn.BG.Parent = row3

    local row4 = mkRow2(mainFrame)
    local dropBtn = createButton("DROP\nBRAINROT", false, function()
        if not dropBrainrotActive then runDropBrainrot() end
    end)
    dropBtn.BG.Parent = row4
    local tpGummyBtn = createButton("TP\nGUMMY", true, function(state, setActive)
        local ns = not tpGummyEnabled
        toggleTpGummy(ns)
        setActive(ns)
        if _updateMobileTpGummy then _updateMobileTpGummy(ns) end
    end, tpGummyEnabled)
    tpGummyBtn.BG.Parent = row4

    local row5 = mkRow2(mainFrame)
    local giantPotionBtn = createButton("GIANT\nPOTION", true, function(state, setActive)
        local ns = not giantPotionAutoEnabled
        toggleGiantPotionAuto(ns)
        setActive(ns)
        if _updateMobileGiantPotionAuto then _updateMobileGiantPotionAuto(ns) end
    end, giantPotionAutoEnabled)
    giantPotionBtn.BG.Parent = row5

    local spacing = Instance.new("UIPadding")
    spacing.PaddingTop = UDim.new(0, 10)
    spacing.PaddingBottom = UDim.new(0, 10)
    spacing.Parent = mainFrame
    local layout = Instance.new("UIListLayout")
    layout.Parent = mainFrame
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    mobilePanel = gui
    _updateMobileAutoLeft = autoLeftBtn.setActive
    _updateMobileAutoRight = autoRightBtn.setActive
    _updateMobileGummyAimbot = gummyAimbotBtn.setActive
    _updateMobileDropBrainrot = dropBtn.setActive
    _updateMobileLaggerMode = laggerModeBtn.setActive
    _updateMobileTpGummy = tpGummyBtn.setActive
    _updateMobileGiantPotionAuto = giantPotionBtn.setActive
end

-- ============================================================
-- INIT
-- ============================================================
buildGui()
createMobilePanel()

if Config["Auto Left"] then
    task.spawn(function()
        task.wait(1)
        queueAutoLeftStart()
    end)
end

if Config["Auto Right"] then
    task.spawn(function()
        task.wait(1)
        queueAutoRightStart()
    end)
end

task.spawn(function()
    toggleAutoResetOnMedusa(autoResetOnMedusaEnabled)
    if Steal.AutoStealEnabled then task.wait(0.5); startAutoSteal() end
    if medusaCounterEnabled then task.wait(0.5); setupMedusa(LP.Character) end
    if batCounterEnabled then task.wait(0.5); startBatCounter() end
    if unwalkEnabled then task.wait(0.5); startUnwalk() end
    if autoTPEnabled then task.wait(0.5); startAutoTP() end
    if gummyAimbotState.autoToggled then task.wait(0.5); toggleGummyAimbot(true) end
    if espEnabled then task.wait(1); enableESP() end
    if stretchRezEnabled then enableStretchRez() end
    if shinyGraphicsEnabled then task.wait(0.5); enableShinyGraphics() end
    if NukeOn then task.wait(0.5); StartNuke() end
    if tpGummyEnabled then task.wait(0.5); startTpGummy() end
    if giantPotionAutoEnabled then task.wait(0.5); startGiantPotionAuto() end
end)

LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if autoResetOnMedusaEnabled then setupAutoResetOnMedusa(LP.Character) end
    if gummyAimbotState.autoToggled then
        task.wait(0.3)
        toggleGummyAimbot(true)
    end
    if tpGummyEnabled then
        task.wait(0.3)
        startTpGummy()
    end
    if giantPotionAutoEnabled then
        task.wait(0.3)
        startGiantPotionAuto()
    end
end)