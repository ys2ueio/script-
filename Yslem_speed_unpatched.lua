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
local C_HEADER = Color3.fromRGB(4, 6, 18)
local C_ROW    = Color3.fromRGB(8, 14, 38)
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
spW.Size = UDim2.new(0, 150, 0, 168)
spW.Position = UDim2.new(0.5, -75, 0.5, -71)
spW.BackgroundColor3 = C_BG
spW.BorderSizePixel = 0; spW.ClipsDescendants = true; spW.Active = true
addCorner(spW, 12); addLivingStroke(spW, 1.5)

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
local stealSpeed   = 30

local speedBox, speedRow = mkInput(64, "Speed",     currentSpeed, function(n) currentSpeed = n end)
local stealBox, stealRow = mkInput(98, "Steal Spd", stealSpeed,   function(n) stealSpeed   = n end)

-- ── Sélecteur de méthode ────────────────────────────────────
local METHODS = { "ALV Lerp", "ALV Snap", "LinearVelocity", "VectorForce", "BodyPosition", "AlignPos", "ALV+VF" }
local methIdx  = 2

local methRow = Instance.new("Frame", spW)
methRow.Size = UDim2.new(1,-16,0,24); methRow.Position = UDim2.new(0,8,0,130)
methRow.BackgroundTransparency = 1; methRow.BorderSizePixel = 0; methRow.ZIndex = 3

local methBtnL = Instance.new("TextButton", methRow)
methBtnL.Size = UDim2.new(0,20,1,0); methBtnL.Position = UDim2.new(0,0,0,0)
methBtnL.BackgroundColor3 = C_OFF_BG; methBtnL.BackgroundTransparency = 0.3
methBtnL.BorderSizePixel = 0; methBtnL.Text = "<"; methBtnL.TextColor3 = C_SILVER
methBtnL.Font = Enum.Font.GothamBlack; methBtnL.TextSize = 11; methBtnL.ZIndex = 4
addCorner(methBtnL, 5); addLivingStroke(methBtnL, 1)

local methBtnR = Instance.new("TextButton", methRow)
methBtnR.Size = UDim2.new(0,20,1,0); methBtnR.Position = UDim2.new(1,-20,0,0)
methBtnR.BackgroundColor3 = C_OFF_BG; methBtnR.BackgroundTransparency = 0.3
methBtnR.BorderSizePixel = 0; methBtnR.Text = ">"; methBtnR.TextColor3 = C_SILVER
methBtnR.Font = Enum.Font.GothamBlack; methBtnR.TextSize = 11; methBtnR.ZIndex = 4
addCorner(methBtnR, 5); addLivingStroke(methBtnR, 1)

local methLbl = Instance.new("TextLabel", methRow)
methLbl.Size = UDim2.new(1,-46,1,0); methLbl.Position = UDim2.new(0,24,0,0)
methLbl.BackgroundTransparency = 1; methLbl.Text = METHODS[methIdx]
methLbl.TextColor3 = C_SILVER; methLbl.Font = Enum.Font.GothamBold; methLbl.TextSize = 10
methLbl.TextXAlignment = Enum.TextXAlignment.Center; methLbl.ZIndex = 4
addLivingTextGradient(methLbl)

local function _methUpdate()
    methLbl.Text = METHODS[methIdx]
end

-- ── Minimize ────────────────────────────────────────────────
local _collapsed = false
local FULL_H, COL_H = 168, 26
spMinBtn.MouseButton1Click:Connect(function()
    _collapsed = not _collapsed
    spW.Size = UDim2.new(0,150,0, _collapsed and COL_H or FULL_H)
    spMinBtn.Text = _collapsed and "+" or "-"
    stRow.Visible    = not _collapsed
    speedRow.Visible = not _collapsed
    stealRow.Visible = not _collapsed
    methRow.Visible  = not _collapsed
end)

-- ── Logic ───────────────────────────────────────────────────
local ACCESSORIES_TO_REMOVE = {
    "Black Shield", "MechHorseHelmet_AccAccessory", "Glasses",
    "MeshPartAccessory", "LeftShoeAccessory", "RightShoeAccessory",
}

local player       = LP
local boostEnabled = false
local boostConn    = nil
local ownTimer     = 0
local ownInterval  = 0.8 + math.random() * 0.4
local speedRamp    = 0
local _lv          = nil
local _lv_att      = nil
local _vf          = nil
local _vf_att      = nil
local _bp          = nil
local _ap          = nil
local _ap_att0     = nil
local _ap_att1     = nil
local _ap_ghost    = nil
local _proxy       = nil
local _proxy_weld  = nil
local _stealing    = false

local function getHumHrp()
    local char = player.Character; if not char then return nil, nil end
    return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function claimOwn(hrp)
    pcall(function() hrp:SetNetworkOwner(player) end)
end

local function cleanLV()
    if _lv     then pcall(function() _lv:Destroy()     end); _lv     = nil end
    if _lv_att then pcall(function() _lv_att:Destroy() end); _lv_att = nil end
end

local function ensureLV(hrp)
    if _lv and _lv.Parent == hrp then return _lv end
    cleanLV()
    local att        = Instance.new("Attachment", hrp); att.Name = "_YS_A"
    local lv         = Instance.new("LinearVelocity", hrp)
    lv.Name          = "_YS_LV"
    lv.Attachment0   = att
    lv.MaxForce      = 1e9
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.VectorVelocity = Vector3.zero
    _lv_att = att; _lv = lv
    return lv
end

local function cleanVF()
    if _vf     then pcall(function() _vf:Destroy()     end); _vf     = nil end
    if _vf_att then pcall(function() _vf_att:Destroy() end); _vf_att = nil end
end

local function ensureVF(hrp)
    if _vf and _vf.Parent == hrp then return _vf end
    cleanVF()
    local att      = Instance.new("Attachment", hrp); att.Name = "_YS_VA"
    local vf       = Instance.new("VectorForce", hrp)
    vf.Name        = "_YS_VF"
    vf.Attachment0 = att
    vf.RelativeTo  = Enum.ActuatorRelativeTo.World
    vf.ApplyAtCenterOfMass = true
    vf.Force       = Vector3.zero
    _vf_att = att; _vf = vf
    return vf
end

local function cleanProxy()
    if _proxy then pcall(function() _proxy:Destroy() end); _proxy = nil end
    _proxy_weld = nil
end

local function ensureProxy(hrp)
    local char = hrp.Parent
    if _proxy and _proxy.Parent == char then return _proxy end
    cleanProxy()
    local p = Instance.new("Part")
    p.Name = "_YS_PX"; p.Size = Vector3.new(1,1,1)
    p.Transparency = 1; p.CanCollide = false; p.Massless = true
    p.Parent = char
    local w = Instance.new("Weld", p)
    w.Part0 = hrp; w.Part1 = p; w.C0 = CFrame.new()
    _proxy_weld = w; _proxy = p
    return p
end

local function cleanBP()
    if _bp then pcall(function() _bp:Destroy() end); _bp = nil end
end

local function ensureBP(hrp)
    if _bp and _bp.Parent == hrp then return _bp end
    cleanBP()
    local bp      = Instance.new("BodyPosition", hrp)
    bp.Name       = "_YS_BP"
    bp.MaxForce   = Vector3.new(1e9, 0, 1e9)
    bp.P          = 5e4
    bp.D          = 1000
    bp.Position   = hrp.Position
    _bp = bp
    return bp
end

local function cleanAP()
    if _ap       then pcall(function() _ap:Destroy()       end); _ap       = nil end
    if _ap_att0  then pcall(function() _ap_att0:Destroy()  end); _ap_att0  = nil end
    if _ap_att1  then pcall(function() _ap_att1:Destroy()  end); _ap_att1  = nil end
    if _ap_ghost then pcall(function() _ap_ghost:Destroy() end); _ap_ghost = nil end
end

local function ensureAP(hrp)
    if _ap and _ap.Parent == hrp then return end
    cleanAP()
    local ghost = Instance.new("Part")
    ghost.Name = "_YS_G"; ghost.Size = Vector3.new(0.1, 0.1, 0.1)
    ghost.Anchored = true; ghost.CanCollide = false; ghost.Transparency = 1
    ghost.CFrame = hrp.CFrame; ghost.Parent = workspace
    local att0 = Instance.new("Attachment", hrp);   att0.Name = "_YS_AP0"
    local att1 = Instance.new("Attachment", ghost); att1.Name = "_YS_AP1"
    local ap = Instance.new("AlignPosition", hrp)
    ap.Name = "_YS_AP"; ap.Attachment0 = att0; ap.Attachment1 = att1
    ap.MaxForce = 1e9; ap.MaxVelocity = 200
    ap.Responsiveness = 200; ap.RigidityEnabled = false
    _ap_ghost = ghost; _ap_att0 = att0; _ap_att1 = att1; _ap = ap
end

local _ownerWatchConn = nil
local function startOwnerWatch(hrp)
    if _ownerWatchConn then pcall(function() _ownerWatchConn:Disconnect() end) end
    _ownerWatchConn = hrp:GetPropertyChangedSignal("ReceiveAge"):Connect(function()
        if boostEnabled then task.defer(function() claimOwn(hrp) end) end
    end)
end

local function applyBoost()
    local _, hrp = getHumHrp(); if not hrp then return end
    claimOwn(hrp); startOwnerWatch(hrp)
end

local function _cleanupMethod(idx)
    if idx == 3 then cleanLV() end
    if idx == 4 then cleanVF() end
    if idx == 5 then cleanBP() end
    if idx == 6 then cleanAP() end
    if idx == 7 then cleanVF() end
end

local function removeBoost()
    if _ownerWatchConn then pcall(function() _ownerWatchConn:Disconnect() end); _ownerWatchConn = nil end
    _cleanupMethod(methIdx)
    speedRamp = 0
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
        speedRamp = 0; ownTimer = 0; _stealing = false
        applyBoost()
        if boostConn then boostConn:Disconnect() end

        local function _hb(dt)
            local hum, hrp = getHumHrp(); if not hum or not hrp then return end

            ownTimer = ownTimer + dt
            if ownTimer >= ownInterval then
                claimOwn(hrp); ownTimer = 0; ownInterval = 0.8 + math.random() * 0.4
            end

            local dir = hum.MoveDirection
            if dir.Magnitude < 0.1 then
                speedRamp = math.max(speedRamp - dt * 6, 0)
                if methIdx == 3 and _lv    then _lv.VectorVelocity = Vector3.zero end
                if methIdx == 4 and _vf    then _vf.Force = Vector3.zero end
                if methIdx == 5 and _bp    then _bp.Position = hrp.Position end
                if methIdx == 6 and _ap    then _ap.MaxVelocity = 0 end
                if methIdx == 7 and _vf    then _vf.Force = Vector3.zero end
                return
            end

            speedRamp = math.min(speedRamp + dt * 12, 1)
            local ws = hum.WalkSpeed
            if not _stealing and ws < 20 then _stealing = true
            elseif _stealing and ws > 28 then _stealing = false end
            local baseSpeed = _stealing and stealSpeed or currentSpeed
            local effective = 16 + (baseSpeed - 16) * speedRamp

            if methIdx == 1 then
                local vel = hrp.AssemblyLinearVelocity
                local n   = 1 + (math.random() - 0.5) * 0.012
                local a   = math.min(dt * 20, 1)
                hrp.AssemblyLinearVelocity = Vector3.new(
                    vel.X + (dir.X * effective * n - vel.X) * a,
                    vel.Y,
                    vel.Z + (dir.Z * effective * n - vel.Z) * a
                )
            elseif methIdx == 2 then
                local n = 1 + (math.random() - 0.5) * 0.04
                if _stealing then
                    local px = ensureProxy(hrp)
                    px.AssemblyLinearVelocity = Vector3.new(
                        dir.X * effective * n,
                        hrp.AssemblyLinearVelocity.Y,
                        dir.Z * effective * n
                    )
                else
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        dir.X * effective * n,
                        hrp.AssemblyLinearVelocity.Y,
                        dir.Z * effective * n
                    )
                end
            elseif methIdx == 3 then
                local lv = ensureLV(hrp)
                lv.VectorVelocity = Vector3.new(dir.X * effective, 0, dir.Z * effective)
            elseif methIdx == 4 then
                local vf  = ensureVF(hrp)
                local vel = hrp.AssemblyLinearVelocity
                local kP  = 600
                vf.Force  = Vector3.new(
                    (dir.X * effective - vel.X) * kP,
                    0,
                    (dir.Z * effective - vel.Z) * kP
                )
            elseif methIdx == 5 then
                local bp = ensureBP(hrp)
                bp.Position = hrp.Position + dir * (effective * dt)
            elseif methIdx == 6 then
                ensureAP(hrp)
                if _ap      then _ap.MaxVelocity = effective end
                if _ap_ghost then _ap_ghost.CFrame = CFrame.new(hrp.Position + dir * 500) end
            elseif methIdx == 7 then
                local vel = hrp.AssemblyLinearVelocity
                local n   = 1 + (math.random() - 0.5) * 0.012
                local a   = math.min(dt * 20, 1)
                hrp.AssemblyLinearVelocity = Vector3.new(
                    vel.X + (dir.X * effective * n - vel.X) * a,
                    vel.Y,
                    vel.Z + (dir.Z * effective * n - vel.Z) * a
                )
                local vf  = ensureVF(hrp)
                local vel2 = hrp.AssemblyLinearVelocity
                vf.Force  = Vector3.new(
                    (dir.X * effective - vel2.X) * 300,
                    0,
                    (dir.Z * effective - vel2.Z) * 300
                )
            end
        end

        boostConn = RunService.Heartbeat:Connect((newcclosure and newcclosure(_hb)) or _hb)
    else
        if boostConn then boostConn:Disconnect(); boostConn = nil end
        removeBoost()
    end
end

local function _switchMeth(delta)
    local prev = methIdx
    methIdx = ((methIdx - 1 + delta) % #METHODS) + 1
    _cleanupMethod(prev)
    _methUpdate()
end

methBtnL.MouseButton1Click:Connect(function() _switchMeth(-1) end)
methBtnR.MouseButton1Click:Connect(function() _switchMeth(1)  end)

local function onCharacterAdded(char)
    cleanLV(); cleanVF(); cleanBP(); cleanAP(); cleanProxy()
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
