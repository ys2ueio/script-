-- ============================================================
--  Yslem Speed Diag  |  strictly private
-- ============================================================
if _G["_YS_SDIAG"] then
    pcall(function() _G["_YS_SDIAG"]:Destroy() end)
    _G["_YS_SDIAG"] = nil
end

local cloneref   = cloneref or function(x) return x end
local Players    = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UIS        = cloneref(game:GetService("UserInputService"))

local LP = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

-- ── Palette ─────────────────────────────────────────────────
local C_BG    = Color3.fromRGB(4, 6, 18)
local C_WHITE = Color3.fromRGB(220, 235, 255)
local C_MOON  = Color3.fromRGB(95, 160, 255)
local C_SILVER= Color3.fromRGB(195, 220, 255)
local C_DIM   = Color3.fromRGB(75, 105, 160)
local C_GREEN = Color3.fromRGB(80, 220, 130)
local C_DEEP1 = Color3.fromRGB(4, 6, 18)
local C_DEEP2 = Color3.fromRGB(12, 25, 70)
local C_DEEP3 = Color3.fromRGB(45, 95, 210)
local C_DEEP4 = Color3.fromRGB(110, 175, 255)

-- ── Living gradients ────────────────────────────────────────
local _livingGradients = {}
local _livingStrokes   = {}
local _purgeCounter    = 0
RunService.RenderStepped:Connect(function()
    _purgeCounter = _purgeCounter + 1
    if _purgeCounter >= 300 then
        _purgeCounter = 0
        local a, b = {}, {}
        for _, g in ipairs(_livingGradients) do if g and g.Parent then a[#a+1] = g end end
        for _, g in ipairs(_livingStrokes)   do if g and g.Parent then b[#b+1] = g end end
        _livingGradients = a; _livingStrokes = b
    end
    for _, g in ipairs(_livingGradients) do if g and g.Parent then g.Rotation = (g.Rotation + 0.6) % 360 end end
    for _, g in ipairs(_livingStrokes)   do if g and g.Parent then g.Rotation = (g.Rotation + 0.6) % 360 end end
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

-- ── ScreenGui ───────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = tostring(math.random(0x10000, 0xFFFFF))
gui.ResetOnSpawn = false; gui.DisplayOrder = 10; gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() if protectgui then protectgui(gui) end end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
    gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end
_G["_YS_SDIAG"] = gui

-- ── Widget ──────────────────────────────────────────────────
local FULL_H, COL_H = 118, 26
local ctW = Instance.new("Frame", gui)
ctW.Name = "SpeedDiagWidget"
ctW.Size = UDim2.new(0, 150, 0, FULL_H)
ctW.Position = UDim2.new(0.5, 90, 0.5, 100)
ctW.BackgroundColor3 = C_BG
ctW.BorderSizePixel = 0; ctW.ClipsDescendants = true; ctW.Active = true
addCorner(ctW, 12); addLivingStroke(ctW, 1.5)

-- ── Header ──────────────────────────────────────────────────
local hdr = Instance.new("Frame", ctW)
hdr.Size = UDim2.new(1,0,0,26); hdr.BackgroundTransparency = 1
hdr.BorderSizePixel = 0; hdr.ZIndex = 3

local _drag, _dragInput, _dragStart, _startPos = false, nil, nil, nil
hdr.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        _drag = true; _dragStart = inp.Position; _startPos = ctW.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then _drag = false end
        end)
    end
end)
hdr.InputChanged:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then _dragInput = inp end
end)
UIS.InputChanged:Connect(function(inp)
    if _drag and _dragInput and inp == _dragInput then
        local d = inp.Position - _dragStart
        ctW.Position = UDim2.new(_startPos.X.Scale, _startPos.X.Offset + d.X, _startPos.Y.Scale, _startPos.Y.Offset + d.Y)
    end
end)

local dot = Instance.new("Frame", hdr)
dot.Size = UDim2.new(0,5,0,5); dot.Position = UDim2.new(0,10,0,11)
dot.BackgroundColor3 = C_MOON; dot.BorderSizePixel = 0; dot.ZIndex = 4
addCorner(dot, 3)

local subLbl = Instance.new("TextLabel", hdr)
subLbl.Size = UDim2.new(1,-46,0,11); subLbl.Position = UDim2.new(0,20,0,2)
subLbl.BackgroundTransparency = 1; subLbl.Text = "yslem"
subLbl.TextColor3 = C_SILVER; subLbl.Font = Enum.Font.Gotham; subLbl.TextSize = 8
subLbl.TextXAlignment = Enum.TextXAlignment.Left; subLbl.ZIndex = 4

local titLbl = Instance.new("TextLabel", hdr)
titLbl.Size = UDim2.new(1,-46,0,13); titLbl.Position = UDim2.new(0,20,0,13)
titLbl.BackgroundTransparency = 1; titLbl.Text = "Speed Diag"
titLbl.TextColor3 = C_WHITE; titLbl.Font = Enum.Font.GothamBlack; titLbl.TextSize = 10
titLbl.TextXAlignment = Enum.TextXAlignment.Left; titLbl.ZIndex = 4
addLivingTextGradient(titLbl)

local minBtn = Instance.new("TextButton", hdr)
minBtn.Size = UDim2.new(0,18,0,18); minBtn.Position = UDim2.new(1,-24,0.5,-9)
minBtn.BackgroundColor3 = Color3.fromRGB(8,14,38); minBtn.BackgroundTransparency = 0.3
minBtn.BorderSizePixel = 0; minBtn.Text = "-"; minBtn.TextColor3 = C_WHITE
minBtn.Font = Enum.Font.GothamBlack; minBtn.TextSize = 15; minBtn.ZIndex = 4
addCorner(minBtn, 6); addLivingStroke(minBtn, 1)

-- ── Méthode row ─────────────────────────────────────────────
local methRow = Instance.new("Frame", ctW)
methRow.Size = UDim2.new(1,-16,0,20); methRow.Position = UDim2.new(0,8,0,32)
methRow.BackgroundTransparency = 1; methRow.ZIndex = 3

local methLbl = Instance.new("TextLabel", methRow)
methLbl.Size = UDim2.new(0.45,0,1,0)
methLbl.BackgroundTransparency = 1; methLbl.Text = "Méthode:"
methLbl.TextColor3 = C_WHITE; methLbl.Font = Enum.Font.GothamBold; methLbl.TextSize = 10
methLbl.TextXAlignment = Enum.TextXAlignment.Left; methLbl.ZIndex = 4
addLivingTextGradient(methLbl)

local methVal = Instance.new("TextLabel", methRow)
methVal.Size = UDim2.new(0.55,0,1,0); methVal.Position = UDim2.new(0.45,0,0,0)
methVal.BackgroundTransparency = 1; methVal.Text = "—"
methVal.TextColor3 = C_DIM; methVal.Font = Enum.Font.GothamBold; methVal.TextSize = 10
methVal.TextXAlignment = Enum.TextXAlignment.Right; methVal.ZIndex = 4
methVal.TextTruncate = Enum.TextTruncate.AtEnd

-- ── Vitesse (grand nombre) ───────────────────────────────────
local speedNum = Instance.new("TextLabel", ctW)
speedNum.Size = UDim2.new(1,-16,0,26); speedNum.Position = UDim2.new(0,8,0,58)
speedNum.BackgroundTransparency = 1; speedNum.Text = "0.0"
speedNum.TextColor3 = C_WHITE; speedNum.Font = Enum.Font.GothamBlack; speedNum.TextSize = 22
speedNum.TextXAlignment = Enum.TextXAlignment.Center; speedNum.ZIndex = 4
addLivingTextGradient(speedNum)

local speedSub = Instance.new("TextLabel", ctW)
speedSub.Size = UDim2.new(1,-16,0,10); speedSub.Position = UDim2.new(0,8,0,84)
speedSub.BackgroundTransparency = 1; speedSub.Text = "studs/s"
speedSub.TextColor3 = C_DIM; speedSub.Font = Enum.Font.Gotham; speedSub.TextSize = 8
speedSub.TextXAlignment = Enum.TextXAlignment.Center; speedSub.ZIndex = 4

-- ── WS / Dépassement row ─────────────────────────────────────
local wsRow = Instance.new("Frame", ctW)
wsRow.Size = UDim2.new(1,-16,0,18); wsRow.Position = UDim2.new(0,8,0,96)
wsRow.BackgroundTransparency = 1; wsRow.ZIndex = 3

local wsLbl = Instance.new("TextLabel", wsRow)
wsLbl.Size = UDim2.new(0.5,0,1,0)
wsLbl.BackgroundTransparency = 1; wsLbl.Text = "WS —"
wsLbl.TextColor3 = C_SILVER; wsLbl.Font = Enum.Font.GothamBold; wsLbl.TextSize = 10
wsLbl.TextXAlignment = Enum.TextXAlignment.Left; wsLbl.ZIndex = 4

local overLbl = Instance.new("TextLabel", wsRow)
overLbl.Size = UDim2.new(0.5,0,1,0); overLbl.Position = UDim2.new(0.5,0,0,0)
overLbl.BackgroundTransparency = 1; overLbl.Text = "+0.0"
overLbl.TextColor3 = C_DIM; overLbl.Font = Enum.Font.GothamBold; overLbl.TextSize = 10
overLbl.TextXAlignment = Enum.TextXAlignment.Right; overLbl.ZIndex = 4

-- ── Minimize ────────────────────────────────────────────────
local _collapsed = false
local _bodyFrames = { methRow, speedNum, speedSub, wsRow }
minBtn.MouseButton1Click:Connect(function()
    _collapsed = not _collapsed
    ctW.Size = UDim2.new(0, 150, 0, _collapsed and COL_H or FULL_H)
    minBtn.Text = _collapsed and "+" or "-"
    for _, v in ipairs(_bodyFrames) do v.Visible = not _collapsed end
end)

-- ── Détection de méthode ─────────────────────────────────────
-- Scan les descendants du char pour identifier la technique active.
-- Priorité: proxy ALV Snap → contraintes → ALV direct → défaut
local function detectMethod(char, hrp)
    if not char or not hrp then return "—", false end
    local hasProxy = char:FindFirstChild("_YS_PX") ~= nil
    local hasVF, hasLV, hasBP, hasAP, hasBV = false, false, false, false, false
    for _, v in ipairs(char:GetDescendants()) do
        local cn = v.ClassName
        if cn == "VectorForce"    then hasVF = true
        elseif cn == "LinearVelocity" then hasLV = true
        elseif cn == "BodyPosition"   then hasBP = true
        elseif cn == "AlignPosition"  then hasAP = true
        elseif cn == "BodyVelocity"   then hasBV = true
        end
    end
    if hasProxy and hasVF then return "ALV+VF", true end
    if hasProxy           then return "ALV Snap", true end
    if hasLV              then return "Linear Vel", true end
    if hasVF              then return "Vector F", true end
    if hasBP              then return "Body Pos", true end
    if hasAP              then return "Align Pos", true end
    if hasBV              then return "Body Vel", true end
    -- Dernier recours: vitesse élevée sans contrainte → ALV direct sur HRP
    local hum = char:FindFirstChildOfClass("Humanoid")
    local vel  = hrp.AssemblyLinearVelocity
    local spd  = Vector3.new(vel.X, 0, vel.Z).Magnitude
    if hum and spd > hum.WalkSpeed + 5 then return "ALV Lerp", true end
    return "Default", false
end

-- ── Heartbeat live ──────────────────────────────────────────
local _detectFrame = 0
local _methCache   = "—"
local _activeCache = false

RunService.Heartbeat:Connect(function()
    local char = LP.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return end

    -- Vitesse XZ
    local vel = hrp.AssemblyLinearVelocity
    local spd = Vector3.new(vel.X, 0, vel.Z).Magnitude
    speedNum.Text = string.format("%.1f", spd)

    -- WS + dépassement
    local ws   = hum.WalkSpeed
    local over = spd - ws
    wsLbl.Text = "WS " .. string.format("%.0f", ws)
    if over > 1 then
        overLbl.Text       = "+" .. string.format("%.1f", over)
        overLbl.TextColor3 = C_GREEN
    else
        overLbl.Text       = string.format("%.1f", math.max(0, over))
        overLbl.TextColor3 = C_DIM
    end

    -- Méthode (re-scan toutes les 10 frames ~6×/s)
    _detectFrame = _detectFrame + 1
    if _detectFrame >= 10 then
        _detectFrame = 0
        _methCache, _activeCache = detectMethod(char, hrp)
    end
    methVal.Text       = _methCache
    methVal.TextColor3 = _activeCache and C_MOON or C_DIM
end)
