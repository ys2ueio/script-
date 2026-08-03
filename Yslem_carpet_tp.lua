-- ============================================================
--  Yslem Carpet TP  |  strictly private
-- ============================================================
if _G["_YS_CTP"] then
    pcall(function() _G["_YS_CTP"]:Destroy() end)
    _G["_YS_CTP"] = nil
end

local cloneref     = cloneref or function(x) return x end
local Players      = cloneref(game:GetService("Players"))
local RunService   = cloneref(game:GetService("RunService"))
local UIS          = cloneref(game:GetService("UserInputService"))

local LP = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

-- ── Palette ─────────────────────────────────────────────────
local C_BG     = Color3.fromRGB(4, 6, 18)
local C_WHITE  = Color3.fromRGB(220, 235, 255)
local C_MOON   = Color3.fromRGB(95, 160, 255)
local C_ON_BG  = Color3.fromRGB(18, 45, 115)
local C_OFF_BG = Color3.fromRGB(4, 6, 18)
local C_SILVER = Color3.fromRGB(195, 220, 255)
local C_DIM    = Color3.fromRGB(75, 105, 160)
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
_G["_YS_CTP"] = gui

-- ── Widget ──────────────────────────────────────────────────
local FULL_H, COL_H = 148, 26
local ctW = Instance.new("Frame", gui)
ctW.Name = "CarpetTPWidget"
ctW.Size = UDim2.new(0, 150, 0, FULL_H)
ctW.Position = UDim2.new(0.5, -75, 0.5, 100)
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
titLbl.BackgroundTransparency = 1; titLbl.Text = "Carpet TP"
titLbl.TextColor3 = C_WHITE; titLbl.Font = Enum.Font.GothamBlack; titLbl.TextSize = 10
titLbl.TextXAlignment = Enum.TextXAlignment.Left; titLbl.ZIndex = 4
addLivingTextGradient(titLbl)

local minBtn = Instance.new("TextButton", hdr)
minBtn.Size = UDim2.new(0,18,0,18); minBtn.Position = UDim2.new(1,-24,0.5,-9)
minBtn.BackgroundColor3 = Color3.fromRGB(8,14,38); minBtn.BackgroundTransparency = 0.3
minBtn.BorderSizePixel = 0; minBtn.Text = "-"; minBtn.TextColor3 = C_WHITE
minBtn.Font = Enum.Font.GothamBlack; minBtn.TextSize = 15; minBtn.ZIndex = 4
addCorner(minBtn, 6); addLivingStroke(minBtn, 1)

-- ── Target row ──────────────────────────────────────────────
local tgtRow = Instance.new("Frame", ctW)
tgtRow.Size = UDim2.new(1,-16,0,26); tgtRow.Position = UDim2.new(0,8,0,32)
tgtRow.BackgroundTransparency = 1; tgtRow.ZIndex = 3

local tgtLbl = Instance.new("TextLabel", tgtRow)
tgtLbl.Size = UDim2.new(0.45,0,1,0); tgtLbl.Position = UDim2.new(0,0,0,0)
tgtLbl.BackgroundTransparency = 1; tgtLbl.Text = "Target:"
tgtLbl.TextColor3 = C_WHITE; tgtLbl.Font = Enum.Font.GothamBold; tgtLbl.TextSize = 11
tgtLbl.TextXAlignment = Enum.TextXAlignment.Left; tgtLbl.ZIndex = 4
addLivingTextGradient(tgtLbl)

local tgtName = Instance.new("TextLabel", tgtRow)
tgtName.Size = UDim2.new(0.55,0,1,0); tgtName.Position = UDim2.new(0.45,0,0,0)
tgtName.BackgroundTransparency = 1; tgtName.Text = "—"
tgtName.TextColor3 = C_DIM; tgtName.Font = Enum.Font.GothamBold; tgtName.TextSize = 10
tgtName.TextXAlignment = Enum.TextXAlignment.Right; tgtName.ZIndex = 4
tgtName.TextTruncate = Enum.TextTruncate.AtEnd

-- ── Nav row (< target >) ─────────────────────────────────────
local navRow = Instance.new("Frame", ctW)
navRow.Size = UDim2.new(1,-16,0,22); navRow.Position = UDim2.new(0,8,0,62)
navRow.BackgroundTransparency = 1; navRow.ZIndex = 3

local prevBtn = Instance.new("TextButton", navRow)
prevBtn.Size = UDim2.new(0,20,1,0); prevBtn.Position = UDim2.new(0,0,0,0)
prevBtn.BackgroundColor3 = C_OFF_BG; prevBtn.BackgroundTransparency = 0.3
prevBtn.BorderSizePixel = 0; prevBtn.Text = "<"; prevBtn.TextColor3 = C_SILVER
prevBtn.Font = Enum.Font.GothamBlack; prevBtn.TextSize = 11; prevBtn.ZIndex = 4
addCorner(prevBtn, 5); addLivingStroke(prevBtn, 1)

local nextBtn = Instance.new("TextButton", navRow)
nextBtn.Size = UDim2.new(0,20,1,0); nextBtn.Position = UDim2.new(1,-20,0,0)
nextBtn.BackgroundColor3 = C_OFF_BG; nextBtn.BackgroundTransparency = 0.3
nextBtn.BorderSizePixel = 0; nextBtn.Text = ">"; nextBtn.TextColor3 = C_SILVER
nextBtn.Font = Enum.Font.GothamBlack; nextBtn.TextSize = 11; nextBtn.ZIndex = 4
addCorner(nextBtn, 5); addLivingStroke(nextBtn, 1)

local navLbl = Instance.new("TextLabel", navRow)
navLbl.Size = UDim2.new(1,-46,1,0); navLbl.Position = UDim2.new(0,24,0,0)
navLbl.BackgroundTransparency = 1; navLbl.Text = "Nearest"
navLbl.TextColor3 = C_SILVER; navLbl.Font = Enum.Font.GothamBold; navLbl.TextSize = 9
navLbl.TextXAlignment = Enum.TextXAlignment.Center; navLbl.ZIndex = 4

-- ── TP button ───────────────────────────────────────────────
local tpBtn = Instance.new("TextButton", ctW)
tpBtn.Size = UDim2.new(1,-16,0,28); tpBtn.Position = UDim2.new(0,8,0,90)
tpBtn.BackgroundColor3 = C_ON_BG; tpBtn.BackgroundTransparency = 0.2
tpBtn.BorderSizePixel = 0; tpBtn.Text = "TP  [E]"
tpBtn.TextColor3 = C_WHITE; tpBtn.Font = Enum.Font.GothamBlack; tpBtn.TextSize = 12
tpBtn.ZIndex = 4
addCorner(tpBtn, 8); addLivingStroke(tpBtn, 1.5)
addLivingTextGradient(tpBtn)

-- ── Auto-TP toggle ──────────────────────────────────────────
local autoRow = Instance.new("Frame", ctW)
autoRow.Size = UDim2.new(1,-16,0,22); autoRow.Position = UDim2.new(0,8,0,124)
autoRow.BackgroundTransparency = 1; autoRow.ZIndex = 3

local autoLbl = Instance.new("TextLabel", autoRow)
autoLbl.Size = UDim2.new(0.5,0,1,0); autoLbl.Position = UDim2.new(0,2,0,0)
autoLbl.BackgroundTransparency = 1; autoLbl.Text = "Auto TP:"
autoLbl.TextColor3 = C_WHITE; autoLbl.Font = Enum.Font.GothamBold; autoLbl.TextSize = 11
autoLbl.TextXAlignment = Enum.TextXAlignment.Left; autoLbl.ZIndex = 4
addLivingTextGradient(autoLbl)

local autoPill = Instance.new("Frame", autoRow)
autoPill.Size = UDim2.new(0.44,0,0,18); autoPill.Position = UDim2.new(0.54,0,0.5,-9)
autoPill.BackgroundColor3 = C_OFF_BG; autoPill.BackgroundTransparency = 0.3
autoPill.BorderSizePixel = 0; autoPill.ZIndex = 4
addCorner(autoPill, 6); addLivingStroke(autoPill, 1)

local autoPillLbl = Instance.new("TextLabel", autoPill)
autoPillLbl.Size = UDim2.new(1,0,1,0); autoPillLbl.BackgroundTransparency = 1
autoPillLbl.Text = "OFF"; autoPillLbl.TextColor3 = C_DIM
autoPillLbl.Font = Enum.Font.GothamBlack; autoPillLbl.TextSize = 10; autoPillLbl.ZIndex = 5

local autoClk = Instance.new("TextButton", autoRow)
autoClk.Size = UDim2.new(1,0,1,0); autoClk.BackgroundTransparency = 1
autoClk.Text = ""; autoClk.ZIndex = 6

-- ── Minimize ────────────────────────────────────────────────
local _collapsed = false
local _bodyFrames = { tgtRow, navRow, tpBtn, autoRow }
minBtn.MouseButton1Click:Connect(function()
    _collapsed = not _collapsed
    ctW.Size = UDim2.new(0, 150, 0, _collapsed and COL_H or FULL_H)
    minBtn.Text = _collapsed and "+" or "-"
    for _, v in ipairs(_bodyFrames) do v.Visible = not _collapsed end
end)

-- ── Logic ───────────────────────────────────────────────────
local DUEL_DIST       = 3.5
local _targetIdx      = 0    -- 0 = nearest auto, 1+ = pinned player index
local _autoTP         = false
local _autoConn       = nil
local _lastCarpetName = nil

local function getEnemyList()
    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local pc = p.Character
            if pc and pc:FindFirstChild("HumanoidRootPart") then
                local d = hrp and (pc.HumanoidRootPart.Position - hrp.Position).Magnitude or 0
                table.insert(list, { player = p, dist = d })
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

local function getTarget()
    local list = getEnemyList()
    if #list == 0 then return nil, nil end
    local idx = (_targetIdx == 0) and 1 or ((_targetIdx - 1) % #list + 1)
    local e = list[idx]
    return e.player, e.player.Character and e.player.Character:FindFirstChild("HumanoidRootPart")
end

local function updateNavLbl()
    local list = getEnemyList()
    if _targetIdx == 0 or #list == 0 then
        navLbl.Text = "Nearest"
    else
        local idx = (_targetIdx - 1) % #list + 1
        navLbl.Text = list[idx].player.Name
    end
end

local function findCarpet()
    local char = LP.Character
    local bp   = LP:FindFirstChild("Backpack")
    local function isMatch(t)
        if not t:IsA("Tool") then return false end
        if _lastCarpetName and t.Name == _lastCarpetName then return true end
        return t.Name:lower():find("carpet") ~= nil
    end
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if isMatch(t) then _lastCarpetName = t.Name; return t, false end
        end
    end
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if isMatch(t) then _lastCarpetName = t.Name; return t, true end
        end
    end
    return nil, false
end

local function doTP()
    local tgtPlayer, tgtHrp = getTarget()
    if not tgtHrp then return end

    local char = LP.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end

    -- Dest: in front of enemy facing them
    local fwd = Vector3.new(tgtHrp.CFrame.LookVector.X, 0, tgtHrp.CFrame.LookVector.Z)
    if fwd.Magnitude > 0.01 then fwd = fwd.Unit else fwd = Vector3.new(0, 0, 1) end
    local dest = Vector3.new(
        tgtHrp.Position.X + fwd.X * DUEL_DIST,
        tgtHrp.Position.Y,
        tgtHrp.Position.Z + fwd.Z * DUEL_DIST
    )

    -- Equip carpet
    local carpet, inBP = findCarpet()
    if carpet and inBP then
        carpet.Parent = char
        task.wait()
    end

    -- Fire carpet remote (try all patterns)
    local fired = false
    if carpet then
        for _, v in ipairs(carpet:GetDescendants()) do
            if v:IsA("RemoteEvent") and not fired then
                pcall(function() v:FireServer(CFrame.new(dest)); fired = true end)
                if not fired then pcall(function() v:FireServer(dest); fired = true end) end
            end
            if v:IsA("RemoteFunction") and not fired then
                pcall(function() v:InvokeServer(CFrame.new(dest)); fired = true end)
                if not fired then pcall(function() v:InvokeServer(dest); fired = true end) end
            end
        end
    end

    -- Fallback: direct CFrame (carpet is equipped = AC sees tool active)
    if not fired then
        hrp.CFrame = CFrame.new(dest)
    end

    -- Face enemy after landing
    task.delay(0.06, function()
        if hrp and hrp.Parent then
            hrp.CFrame = CFrame.lookAt(
                hrp.Position,
                Vector3.new(tgtHrp.Position.X, hrp.Position.Y, tgtHrp.Position.Z)
            )
        end
    end)

    -- Return carpet
    if carpet and inBP then
        task.delay(0.25, function() pcall(function() carpet.Parent = LP.Backpack end) end)
    end
end

-- ── Auto TP ─────────────────────────────────────────────────
local function setAuto(on)
    _autoTP = on
    autoPill.BackgroundColor3       = on and C_MOON or C_OFF_BG
    autoPill.BackgroundTransparency = on and 0.15 or 0.3
    autoPillLbl.Text                = on and "ON" or "OFF"
    autoPillLbl.TextColor3          = on and Color3.fromRGB(3, 8, 20) or C_DIM
    if _autoConn then _autoConn:Disconnect(); _autoConn = nil end
    if on then
        local t = 0
        _autoConn = RunService.Heartbeat:Connect(function(dt)
            t = t + dt
            if t >= 0.6 then t = 0; doTP() end
        end)
    end
end

-- ── Live target name ─────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    local p = getTarget()
    if p then
        tgtName.Text      = p.Name
        tgtName.TextColor3 = C_SILVER
    else
        tgtName.Text      = "—"
        tgtName.TextColor3 = C_DIM
    end
end)

-- ── Bindings ─────────────────────────────────────────────────
prevBtn.MouseButton1Click:Connect(function()
    local list = getEnemyList(); if #list == 0 then return end
    _targetIdx = _targetIdx - 1
    if _targetIdx < 0 then _targetIdx = #list end
    updateNavLbl()
end)
nextBtn.MouseButton1Click:Connect(function()
    local list = getEnemyList(); if #list == 0 then return end
    _targetIdx = _targetIdx + 1
    if _targetIdx > #list then _targetIdx = 0 end
    updateNavLbl()
end)

tpBtn.MouseButton1Click:Connect(doTP)
autoClk.MouseButton1Click:Connect(function() setAuto(not _autoTP) end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.E then doTP() end
end)

print("[Yslem CarpetTP] OK — [E] pour TP")
