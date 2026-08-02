-- ============================================================
--  Yslem Unpatched  |  strictly private
-- ============================================================
if _G["_YS_UNPATCHED"] then
    pcall(function() _G["_YS_UNPATCHED"]:Destroy() end)
    _G["_YS_UNPATCHED"] = nil
end

local cloneref     = cloneref or function(x) return x end
local Players      = cloneref(game:GetService("Players"))
local RunService   = cloneref(game:GetService("RunService"))
local TweenService = game:GetService("TweenService")
local UIS          = cloneref(game:GetService("UserInputService"))

local LP = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

-- ── Anti-detect ─────────────────────────────────────────────
pcall(function()
    local _BAD = {"log","report","detect","analytics","telemetry","anticheat","anti_cheat","ban","kick","cheat"}
    local function _wrapReq(fn)
        if not fn then return fn end
        return newcclosure(function(opts, ...)
            if type(opts) == "table" then
                local url = ((opts.Url or opts.url) or ""):lower()
                for _, kw in ipairs(_BAD) do
                    if url:find(kw, 1, true) then return {StatusCode=200,Body="",Success=true} end
                end
            end
            return fn(opts, ...)
        end)
    end
    if syn and syn.request then syn.request   = _wrapReq(syn.request)  end
    if request             then request        = _wrapReq(request)       end
    if http_request        then http_request   = _wrapReq(http_request)  end
end)

pcall(function()
    local gmt = getrawmetatable(game); if not gmt then return end
    setreadonly(gmt, false)
    local _nc = gmt.__namecall
    gmt.__namecall = newcclosure(function(self, ...)
        local m = (getnamecallmethod and getnamecallmethod() or ""):lower()
        if m == "shutdown" or m == "bindtoclose" then return end
        return _nc(self, ...)
    end)
    setreadonly(gmt, true)
end)

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

-- ── ScreenGui ───────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = tostring(math.random(0x10000, 0xFFFFF)); gui.ResetOnSpawn = false
gui.DisplayOrder = 10; gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() if protectgui then protectgui(gui) end end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
    gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end
_G["_YS_UNPATCHED"] = gui

-- ── Widget ──────────────────────────────────────────────────
local spW = Instance.new("Frame", gui)
spW.Name = "SpeedWidget"
spW.Size = UDim2.new(0, 150, 0, 142)
spW.Position = UDim2.new(0.5, -75, 0.5, -71)
spW.BackgroundColor3 = C_BG
spW.BorderSizePixel = 0; spW.ClipsDescendants = true; spW.Active = true
addCorner(spW, 12); addLivingStroke(spW, 1.5)

-- Background image
local bgImg = Instance.new("ImageLabel", spW)
bgImg.Size = UDim2.new(1,0,1,0)
bgImg.BackgroundTransparency = 1
bgImg.Image = ""
bgImg.ScaleType = Enum.ScaleType.Crop
bgImg.ImageTransparency = 0
bgImg.ZIndex = 1
addCorner(bgImg, 12)
do
    local fname = "yslem_bg.png"
    local url   = "https://litter.catbox.moe/xnbgt6qhibc9z4db.png"
    local function tryLoad()
        if not (getcustomasset and isfile and isfile(fname)) then return false end
        local rid = getcustomasset(fname)
        if rid and rid ~= "" then bgImg.Image = rid; return true end
        return false
    end
    if not tryLoad() then
        task.spawn(function()
            pcall(function()
                local ok, data = pcall(function() return game:HttpGet(url) end)
                if ok and data and data ~= "" then
                    if writefile then writefile(fname, data) end
                    tryLoad()
                end
            end)
        end)
    end
end

-- ── Header ──────────────────────────────────────────────────
local spH = Instance.new("Frame", spW)
spH.Size = UDim2.new(1,0,0,26); spH.BackgroundTransparency = 1
spH.BorderSizePixel = 0; spH.ZIndex = 3

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
UIS.InputChanged:Connect(function(inp)
    if _dragging and _dragInput and inp == _dragInput then
        local d = inp.Position - _dragStart
        spW.Position = UDim2.new(_startPos.X.Scale, _startPos.X.Offset+d.X, _startPos.Y.Scale, _startPos.Y.Offset+d.Y)
    end
end)

local spDot = Instance.new("Frame", spH)
spDot.Size = UDim2.new(0,5,0,5); spDot.Position = UDim2.new(0,10,0,11)
spDot.BackgroundColor3 = C_MOON; spDot.BorderSizePixel = 0; spDot.ZIndex = 4
addCorner(spDot, 3)

local spSub = Instance.new("TextLabel", spH)
spSub.Size = UDim2.new(1,-46,0,11); spSub.Position = UDim2.new(0,20,0,2)
spSub.BackgroundTransparency = 1; spSub.Text = "yslem"
spSub.TextColor3 = C_SILVER; spSub.Font = Enum.Font.Gotham; spSub.TextSize = 8
spSub.TextXAlignment = Enum.TextXAlignment.Left; spSub.ZIndex = 4

local spTitle = Instance.new("TextLabel", spH)
spTitle.Size = UDim2.new(1,-46,0,13); spTitle.Position = UDim2.new(0,20,0,13)
spTitle.BackgroundTransparency = 1; spTitle.Text = "Speed"
spTitle.TextColor3 = C_WHITE; spTitle.Font = Enum.Font.GothamBlack; spTitle.TextSize = 10
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
stRow.BackgroundTransparency = 1; stRow.BorderSizePixel = 0; stRow.ZIndex = 3

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
    row.BackgroundTransparency = 1; row.BorderSizePixel = 0; row.ZIndex = 3
    local l = Instance.new("TextLabel", row)
    l.Size = UDim2.new(1,-80,1,0); l.Position = UDim2.new(0,12,0,0)
    l.BackgroundTransparency = 1; l.Text = lbl; l.TextColor3 = C_WHITE
    l.Font = Enum.Font.GothamBold; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 4; addLivingTextGradient(l)
    local bw = Instance.new("Frame", row)
    bw.Size = UDim2.new(0,62,0,22); bw.Position = UDim2.new(1,-70,0.5,-11)
    bw.BackgroundColor3 = C_OFF_BG; bw.BackgroundTransparency = 0.45
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
    return box, row
end

-- ── Inputs ──────────────────────────────────────────────────
local currentSpeed = 60
local stealSpeed   = 40

local speedBox,  speedRow  = mkInput(64, "Speed",     currentSpeed, function(n) currentSpeed = n end)
local stealBox,  stealRow  = mkInput(98, "Steal Spd", stealSpeed,   function(n) stealSpeed   = n end)

-- ── Minimize ────────────────────────────────────────────────
local _collapsed = false
local FULL_H, COL_H = 142, 26
spMinBtn.MouseButton1Click:Connect(function()
    _collapsed = not _collapsed
    spW.Size = UDim2.new(0,150,0, _collapsed and COL_H or FULL_H)
    spMinBtn.Text = _collapsed and "+" or "-"
    stRow.Visible    = not _collapsed
    speedRow.Visible = not _collapsed
    stealRow.Visible = not _collapsed
end)

-- ── Logic ───────────────────────────────────────────────────
local ACCESSORIES_TO_REMOVE = {
    "Black Shield", "MechHorseHelmet_AccAccessory", "Glasses",
    "MeshPartAccessory", "LeftShoeAccessory", "RightShoeAccessory",
}

local player        = LP
local boostEnabled  = false
local boostConn     = nil
local lagConn       = nil
local ownTimer      = 0
local ownInterval   = 0.8 + math.random() * 0.4
local speedRamp     = 0
local lastIntended  = nil
local stealTimer    = 0     -- secondes restantes de boost steal
local STEAL_DUR     = 0.8   -- durée du boost après détection steal

local function getHRP()
    local char = player.Character; if not char then return nil, nil end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    return hum, hrp
end

local function claimOwn(hrp)
    pcall(function() hrp:SetNetworkOwner(player) end)
end

local _ownerWatchConn = nil
local function startOwnerWatch(hrp)
    if _ownerWatchConn then pcall(function() _ownerWatchConn:Disconnect() end) end
    _ownerWatchConn = hrp:GetPropertyChangedSignal("ReceiveAge"):Connect(function()
        if boostEnabled then task.defer(function() claimOwn(hrp) end) end
    end)
end

-- Déclenche le boost steal (appelé par le hook)
local function triggerStealSpeed()
    stealTimer = STEAL_DUR
end

-- Hook _KAG_executeSteal sans modifier son comportement
task.spawn(function()
    local attempts = 0
    while not _G._KAG_executeSteal and attempts < 120 do
        task.wait(0.5); attempts = attempts + 1
    end
    if not _G._KAG_executeSteal then return end
    pcall(function()
        if hookfunction then
            -- hookfunction : hook transparent, l'original est toujours appelé
            hookfunction(_G._KAG_executeSteal, newcclosure(function(...)
                triggerStealSpeed()
            end))
        else
            local _orig = _G._KAG_executeSteal
            local _hook = function(...)
                triggerStealSpeed()
                return _orig(...)
            end
            _G._KAG_executeSteal = (newcclosure and newcclosure(_hook)) or _hook
        end
    end)
end)

local function applyBoost()
    local hum, hrp = getHRP(); if not hum or not hrp then return end
    claimOwn(hrp)
    startOwnerWatch(hrp)
end

local function removeBoost()
    if _ownerWatchConn then pcall(function() _ownerWatchConn:Disconnect() end); _ownerWatchConn = nil end
    lastIntended = nil
    speedRamp    = 0
end

local function _pillUpdate(on)
    stPill.BackgroundColor3       = on and C_MOON or C_OFF_BG
    stPill.BackgroundTransparency = on and 0.15 or 0.3
    stPillLbl.Text                = on and "ON" or "OFF"
    stPillLbl.TextColor3          = on and Color3.fromRGB(3, 8, 20) or C_DIM
end

local function toggleBoost()
    boostEnabled = not boostEnabled
    _pillUpdate(boostEnabled)

    if boostEnabled then
        speedRamp = 0
        applyBoost()
        if boostConn then boostConn:Disconnect() end
        if lagConn   then lagConn:Disconnect()   end

        local function _hb(dt)
            local hum, hrp = getHRP(); if not hum or not hrp then return end

            ownTimer = ownTimer + dt
            if ownTimer >= ownInterval then
                claimOwn(hrp)
                ownTimer    = 0
                ownInterval = 0.8 + math.random() * 0.4
            end

            local dir = hum.MoveDirection
            if dir.Magnitude < 0.1 then
                lastIntended = nil
                speedRamp    = math.max(speedRamp - dt * 6, 0)
                return
            end

            -- steal speed actif pendant STEAL_DUR secondes après détection
            stealTimer = math.max(stealTimer - dt, 0)
            local activeSpeed = stealTimer > 0 and stealSpeed or currentSpeed

            speedRamp = math.min(speedRamp + dt * 4, 1)
            local effective = 16 + (activeSpeed - 16) * speedRamp

            local vel  = hrp.AssemblyLinearVelocity
            local n    = 1 + (math.random() - 0.5) * 0.012
            local tgtX = dir.X * effective * n
            local tgtZ = dir.Z * effective * n
            local a    = math.min(dt * 20, 1)
            hrp.AssemblyLinearVelocity = Vector3.new(
                vel.X + (tgtX - vel.X) * a,
                vel.Y,
                vel.Z + (tgtZ - vel.Z) * a
            )

            lastIntended = hrp.Position
        end

        local function _lag()
            if not boostEnabled or not lastIntended then return end
            local _, hrp = getHRP(); if not hrp then return end
            local delta = (hrp.Position - lastIntended).Magnitude
            if delta > 10 then
                hrp.CFrame = CFrame.new(lastIntended.X, hrp.Position.Y, lastIntended.Z)
                            * (hrp.CFrame - hrp.CFrame.Position)
                claimOwn(hrp)
                lastIntended = nil
            end
        end

        boostConn = RunService.Heartbeat:Connect((newcclosure and newcclosure(_hb)) or _hb)
        lagConn   = RunService.Stepped:Connect((newcclosure and newcclosure(_lag)) or _lag)
    else
        if boostConn then boostConn:Disconnect(); boostConn = nil end
        if lagConn   then lagConn:Disconnect();   lagConn   = nil end
        removeBoost()
    end
end

local function onCharacterAdded(char)
    for _, name in ipairs(ACCESSORIES_TO_REMOVE) do
        local p = char:FindFirstChild(name); if p then p:Destroy() end
    end
    if boostEnabled then task.wait(0.3); applyBoost() end
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.T then toggleBoost() end
end)

stClk.MouseButton1Click:Connect(toggleBoost)
