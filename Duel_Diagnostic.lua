-- ================================================================
-- DIAGNOSTIC — Duel Script v2
-- Analyse : APIs executor, couches anti-kick, stats live perso
-- ================================================================
if _G["_DIAG_V2_LOADED"] then return end
_G["_DIAG_V2_LOADED"] = true

local LP  = game:GetService("Players").LocalPlayer
local RS  = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

-- ================================================================
-- PALETTE
-- ================================================================
local C = {
    bg       = Color3.fromRGB(12, 12, 14),
    surface  = Color3.fromRGB(20, 20, 24),
    border   = Color3.fromRGB(40, 40, 50),
    header   = Color3.fromRGB(16, 16, 20),
    tabOn    = Color3.fromRGB(28, 28, 36),
    tabOff   = Color3.fromRGB(18, 18, 22),
    green    = Color3.fromRGB(72, 220, 110),
    red      = Color3.fromRGB(240, 70,  70),
    yellow   = Color3.fromRGB(240, 190, 50),
    grey     = Color3.fromRGB(140, 140, 160),
    white    = Color3.fromRGB(240, 240, 245),
    accent   = Color3.fromRGB(90,  140, 255),
    secHead  = Color3.fromRGB(26, 26, 34),
}

-- ================================================================
-- DATA COLLECTION
-- ================================================================
local function apiList()
    local function has(name) return type(_G[name]) == "function" or type(getfenv()[name]) == "function" end
    local function hasG(name)
        local ok, v = pcall(function() return _G[name] end)
        return ok and type(v) == "function"
    end
    local function chk(name)
        local v
        pcall(function() v = _ENV[name] end)
        return type(v) == "function"
    end

    local APIs = {
        "hookfunction", "newcclosure", "getgc", "islclosure",
        "isexecutorclosure", "getupvalues", "getrawmetatable",
        "setreadonly", "checkcaller", "getnamecallmethod",
        "getrenv", "getconnections", "firesignal", "protectgui",
    }

    local rows = {}
    for _, name in ipairs(APIs) do
        local ok = false
        pcall(function()
            local v = load("return " .. name)()
            ok = type(v) == "function"
        end)
        table.insert(rows, { label = name, ok = ok })
    end

    -- syn extras
    pcall(function()
        local synOk = type(syn) == "table"
        table.insert(rows, { label = "syn.protect_gui",   ok = synOk and type(syn.protect_gui) == "function" })
        table.insert(rows, { label = "syn.request",       ok = synOk and type(syn.request)      == "function" })
    end)

    return rows
end

local function layerList()
    local rows = {}

    -- L1: Player:Kick() namecall hook
    pcall(function()
        local mt = getrawmetatable(LP)
        local nc = mt and rawget(mt, "__namecall")
        local hooked = nc ~= nil and isexecutorclosure ~= nil and isexecutorclosure(nc)
        table.insert(rows, { label = "Player:Kick() bloqué",       ok = hooked == true })
    end)
    if #rows == 0 then table.insert(rows, { label = "Player:Kick() bloqué", ok = false }) end

    -- L2: game:Shutdown/BindToClose/Load hook
    pcall(function()
        local gmt = getrawmetatable(game)
        local gnc = gmt and rawget(gmt, "__namecall")
        local hooked = gnc ~= nil and isexecutorclosure ~= nil and isexecutorclosure(gnc)
        table.insert(rows, { label = "Shutdown/BindToClose bloqué", ok = hooked == true })
    end)
    if #rows < 2 then table.insert(rows, { label = "Shutdown/BindToClose bloqué", ok = false }) end

    -- L3: TeleportService hook
    pcall(function()
        local tsvc = game:GetService("TeleportService")
        local tmt  = getrawmetatable(tsvc)
        local tnc  = tmt and rawget(tmt, "__namecall")
        local hooked = tnc ~= nil and isexecutorclosure ~= nil and isexecutorclosure(tnc)
        table.insert(rows, { label = "TeleportService bloqué",      ok = hooked == true })
    end)
    if #rows < 3 then table.insert(rows, { label = "TeleportService bloqué", ok = false }) end

    -- L4: char.__newindex
    pcall(function()
        local char = LP.Character
        if char then
            local cm = getrawmetatable(char)
            local ni = cm and rawget(cm, "__newindex")
            local hooked = ni ~= nil and isexecutorclosure ~= nil and isexecutorclosure(ni)
            table.insert(rows, { label = "char.__newindex (Parent≠nil)", ok = hooked == true })
        else
            table.insert(rows, { label = "char.__newindex (Parent≠nil)", ok = false })
        end
    end)
    if #rows < 4 then table.insert(rows, { label = "char.__newindex (Parent≠nil)", ok = false }) end

    -- L5: HTTP block
    pcall(function()
        local blocked = false
        if isexecutorclosure then
            if type(syn) == "table" and type(syn.request) == "function" then
                blocked = isexecutorclosure(syn.request)
            elseif type(request) == "function" then
                blocked = isexecutorclosure(request)
            elseif type(http_request) == "function" then
                blocked = isexecutorclosure(http_request)
            end
        end
        table.insert(rows, { label = "HTTP report/detect bloqué", ok = blocked })
    end)
    if #rows < 5 then table.insert(rows, { label = "HTTP report/detect bloqué", ok = false }) end

    -- L6: GC scanner (API dispo = scan possible)
    local gcOk = type(getgc) == "function" and type(islclosure) == "function" and type(isexecutorclosure) == "function"
    table.insert(rows, { label = "GC scanner (APIs ok)",         ok = gcOk })

    -- L7: newcclosure dispo (protection hooks)
    local nccOk = type(newcclosure) == "function"
    table.insert(rows, { label = "newcclosure (hooks camouflés)", ok = nccOk })

    -- L8: Remote name-block dispo
    local remOk = type(hookfunction) == "function"
    table.insert(rows, { label = "hookfunction (remote hooks)",   ok = remOk })

    return rows
end

local function liveStats()
    local rows = {}
    local char = LP.Character
    if not char then
        table.insert(rows, { label = "Character", value = "ABSENT", color = C.red })
        return rows
    end

    -- Character parent
    local inWs = char.Parent == workspace
    table.insert(rows, { label = "Char parent",   value = inWs and "Workspace ✓" or tostring(char.Parent), color = inWs and C.green or C.red })

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local hp    = math.round(hum.Health)
        local maxHp = math.round(hum.MaxHealth)
        local hpColor = hp >= maxHp and C.green or (hp > 0 and C.yellow or C.red)
        table.insert(rows, { label = "HP",           value = hp .. " / " .. maxHp, color = hpColor })
        table.insert(rows, { label = "MaxHealth",    value = tostring(maxHp) .. (maxHp == 100 and " ✓" or " ✗"), color = maxHp == 100 and C.green or C.yellow })

        local state = tostring(hum:GetState()):match("%.(%w+)$") or "?"
        local safeStates = {Running=true,Jumping=true,Landed=true,Freefall=true,Standing=true,Climbing=true,Swimming=true,GettingUp=true}
        table.insert(rows, { label = "Hum state",    value = state, color = safeStates[state] and C.green or C.red })
    else
        table.insert(rows, { label = "Humanoid",     value = "ABSENT", color = C.red })
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local vel   = hrp.AssemblyLinearVelocity
        local hSpd  = math.round(Vector3.new(vel.X, 0, vel.Z).Magnitude)
        local vSpd  = math.round(vel.Y)
        local pos   = hrp.Position

        table.insert(rows, { label = "Speed",        value = hSpd .. " st/s", color = hSpd > 0 and C.accent or C.grey })
        local velColor = vSpd < -80 and C.red or (vSpd < -30 and C.yellow or C.grey)
        table.insert(rows, { label = "Vel Y",        value = (vSpd < -50 and "⚠ " or "") .. vSpd, color = velColor })
        table.insert(rows, { label = "Position",     value = string.format("%.0f  %.0f  %.0f", pos.X, pos.Y, pos.Z), color = C.grey })
    else
        table.insert(rows, { label = "HRP",          value = "ABSENT", color = C.red })
    end

    return rows
end

-- count OK in apiList for the summary
local function countOk(list)
    local ok, total = 0, #list
    for _, r in ipairs(list) do if r.ok then ok = ok + 1 end end
    return ok, total
end

-- ================================================================
-- GUI
-- ================================================================
local W, H = 310, 420

local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "DuelDiagnostic"
screenGui.ResetOnSpawn  = false
screenGui.DisplayOrder  = 100
screenGui.ZIndexBehavior= Enum.ZIndexBehavior.Sibling
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(screenGui) end
    if protectgui then protectgui(screenGui) end
end)
if not pcall(function() screenGui.Parent = game:GetService("CoreGui") end) then
    screenGui.Parent = LP:WaitForChild("PlayerGui")
end

-- Root frame
local root = Instance.new("Frame", screenGui)
root.Size              = UDim2.new(0, W, 0, H)
root.Position          = UDim2.new(0.5, -W/2, 0.5, -H/2)
root.BackgroundColor3  = C.bg
root.BorderSizePixel   = 0
root.ClipsDescendants  = true
Instance.new("UICorner", root).CornerRadius = UDim.new(0, 8)
local rootStroke = Instance.new("UIStroke", root)
rootStroke.Color = C.border; rootStroke.Thickness = 1

-- Header
local header = Instance.new("Frame", root)
header.Size           = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = C.header
header.BorderSizePixel = 0

local headerLabel = Instance.new("TextLabel", header)
headerLabel.Size              = UDim2.new(1, -60, 1, 0)
headerLabel.Position          = UDim2.new(0, 12, 0, 0)
headerLabel.BackgroundTransparency = 1
headerLabel.Text              = "DIAGNOSTIC — Duel Script v2"
headerLabel.TextColor3        = C.white
headerLabel.Font               = Enum.Font.GothamBold
headerLabel.TextSize          = 12
headerLabel.TextXAlignment     = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size             = UDim2.new(0, 28, 0, 28)
closeBtn.Position         = UDim2.new(1, -32, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text             = "✕"
closeBtn.TextColor3       = C.white
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.TextSize         = 12
closeBtn.BorderSizePixel  = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy(); _G["_DIAG_V2_LOADED"] = nil end)

-- Separator under header
local sep0 = Instance.new("Frame", root)
sep0.Size = UDim2.new(1, 0, 0, 1); sep0.Position = UDim2.new(0,0,0,34)
sep0.BackgroundColor3 = C.border; sep0.BorderSizePixel = 0

-- Tab bar
local tabBar = Instance.new("Frame", root)
tabBar.Size              = UDim2.new(1, 0, 0, 30)
tabBar.Position          = UDim2.new(0, 0, 0, 35)
tabBar.BackgroundColor3  = C.header
tabBar.BorderSizePixel   = 0

local TABS = {"APIs", "COUCHES", "LIVE"}
local tabBtns = {}
local activeTab = 1

local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder     = Enum.SortOrder.LayoutOrder

for i, name in ipairs(TABS) do
    local tb = Instance.new("TextButton", tabBar)
    tb.Size              = UDim2.new(0, W / #TABS, 1, 0)
    tb.LayoutOrder       = i
    tb.BackgroundColor3  = i == 1 and C.tabOn or C.tabOff
    tb.Text              = name
    tb.TextColor3        = i == 1 and C.white or C.grey
    tb.Font               = Enum.Font.GothamBold
    tb.TextSize          = 11
    tb.BorderSizePixel   = 0
    tabBtns[i] = tb
end

-- Separator under tabs
local sep1 = Instance.new("Frame", root)
sep1.Size = UDim2.new(1, 0, 0, 1); sep1.Position = UDim2.new(0,0,0,65)
sep1.BackgroundColor3 = C.border; sep1.BorderSizePixel = 0

-- Content scroll frame
local content = Instance.new("ScrollingFrame", root)
content.Size              = UDim2.new(1, 0, 1, -67)
content.Position          = UDim2.new(0, 0, 0, 67)
content.BackgroundColor3  = C.bg
content.BorderSizePixel   = 0
content.ScrollBarThickness= 3
content.ScrollBarImageColor3 = C.border
content.CanvasSize        = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y

local listLayout = Instance.new("UIListLayout", content)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding   = UDim.new(0, 0)

-- ================================================================
-- ROW BUILDERS
-- ================================================================
local function clearContent()
    for _, c in ipairs(content:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
end

local function makeSection(title, order)
    local sec = Instance.new("Frame", content)
    sec.Size            = UDim2.new(1, 0, 0, 24)
    sec.BackgroundColor3= C.secHead
    sec.BorderSizePixel = 0
    sec.LayoutOrder     = order

    local lbl = Instance.new("TextLabel", sec)
    lbl.Size             = UDim2.new(1, -10, 1, 0)
    lbl.Position         = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = title
    lbl.TextColor3       = C.accent
    lbl.Font              = Enum.Font.GothamBold
    lbl.TextSize         = 10
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
end

local function makeRow(parent, label, value, color, order, indent)
    local row = Instance.new("Frame", parent)
    row.Size            = UDim2.new(1, 0, 0, 26)
    row.BackgroundColor3= C.surface
    row.BorderSizePixel = 0
    row.LayoutOrder     = order

    local stripe = Instance.new("Frame", row)
    stripe.Size              = UDim2.new(0, 2, 1, 0)
    stripe.BackgroundColor3  = color
    stripe.BorderSizePixel   = 0

    local lblEl = Instance.new("TextLabel", row)
    lblEl.Size             = UDim2.new(0.6, -16, 1, 0)
    lblEl.Position         = UDim2.new(0, 10 + (indent or 0), 0, 0)
    lblEl.BackgroundTransparency = 1
    lblEl.Text             = label
    lblEl.TextColor3       = C.grey
    lblEl.Font              = Enum.Font.Gotham
    lblEl.TextSize         = 10
    lblEl.TextXAlignment   = Enum.TextXAlignment.Left
    lblEl.TextTruncate     = Enum.TextTruncate.AtEnd

    local badge = Instance.new("Frame", row)
    badge.Size              = UDim2.new(0, 90, 0, 18)
    badge.Position          = UDim2.new(1, -98, 0.5, -9)
    badge.BackgroundColor3  = Color3.fromRGB(color.R*255 * 0.12, color.G*255 * 0.12, color.B*255 * 0.12)
    badge.BorderSizePixel   = 0
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 4)

    local valEl = Instance.new("TextLabel", badge)
    valEl.Size             = UDim2.new(1, -6, 1, 0)
    valEl.Position         = UDim2.new(0, 3, 0, 0)
    valEl.BackgroundTransparency = 1
    valEl.Text             = value
    valEl.TextColor3       = color
    valEl.Font              = Enum.Font.GothamBold
    valEl.TextSize         = 9
    valEl.TextXAlignment   = Enum.TextXAlignment.Center
    valEl.TextTruncate     = Enum.TextTruncate.AtEnd

    -- separator line
    local line = Instance.new("Frame", row)
    line.Size              = UDim2.new(1, -4, 0, 1)
    line.Position          = UDim2.new(0, 2, 1, -1)
    line.BackgroundColor3  = C.border
    line.BackgroundTransparency = 0.5
    line.BorderSizePixel   = 0

    return valEl, badge
end

local function makeApiRow2col(list, startOrder)
    -- 2 API entries per row
    local i = 1
    local ord = startOrder
    while i <= #list do
        local row = Instance.new("Frame", content)
        row.Size             = UDim2.new(1, 0, 0, 26)
        row.BackgroundColor3 = C.surface
        row.BorderSizePixel  = 0
        row.LayoutOrder      = ord; ord = ord + 1

        local function addHalf(item, xOff, w)
            if not item then return end
            local color = item.ok and C.green or C.red
            local stripe = Instance.new("Frame", row)
            stripe.Size             = UDim2.new(0, 2, 1, 0)
            stripe.Position         = UDim2.new(0, xOff, 0, 0)
            stripe.BackgroundColor3 = color
            stripe.BorderSizePixel  = 0

            local lbl = Instance.new("TextLabel", row)
            lbl.Size              = UDim2.new(0, w - 36, 1, 0)
            lbl.Position          = UDim2.new(0, xOff + 8, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text              = item.label
            lbl.TextColor3        = C.grey
            lbl.Font               = Enum.Font.Gotham
            lbl.TextSize          = 9
            lbl.TextXAlignment    = Enum.TextXAlignment.Left
            lbl.TextTruncate      = Enum.TextTruncate.AtEnd

            local dot = Instance.new("TextLabel", row)
            dot.Size              = UDim2.new(0, 24, 0, 18)
            dot.Position          = UDim2.new(0, xOff + w - 28, 0.5, -9)
            dot.BackgroundTransparency = 1
            dot.Text              = item.ok and "✓" or "✗"
            dot.TextColor3        = color
            dot.Font               = Enum.Font.GothamBold
            dot.TextSize          = 12
            dot.TextXAlignment    = Enum.TextXAlignment.Center
        end

        local half = math.floor(W / 2)
        addHalf(list[i],    0,    half)
        addHalf(list[i+1],  half, half)

        local line = Instance.new("Frame", row)
        line.Size             = UDim2.new(1, -4, 0, 1)
        line.Position         = UDim2.new(0, 2, 1, -1)
        line.BackgroundColor3 = C.border
        line.BackgroundTransparency = 0.5
        line.BorderSizePixel  = 0

        i = i + 2
    end
    return ord
end

-- ================================================================
-- SUMMARY LINE
-- ================================================================
local summaryFrame = Instance.new("Frame", root)
summaryFrame.Size            = UDim2.new(1, 0, 0, 20)
summaryFrame.Position        = UDim2.new(0, 0, 0, H - 20)
summaryFrame.BackgroundColor3= C.header
summaryFrame.BorderSizePixel = 0
summaryFrame.ZIndex          = 5

local summaryLabel = Instance.new("TextLabel", summaryFrame)
summaryLabel.Size            = UDim2.new(1, -10, 1, 0)
summaryLabel.Position        = UDim2.new(0, 10, 0, 0)
summaryLabel.BackgroundTransparency = 1
summaryLabel.Text            = ""
summaryLabel.TextColor3      = C.grey
summaryLabel.Font             = Enum.Font.Gotham
summaryLabel.TextSize        = 9
summaryLabel.TextXAlignment  = Enum.TextXAlignment.Left
summaryLabel.ZIndex          = 5

local function updateSummary(apiRows, layerRows)
    local aOk, aTotal   = countOk(apiRows)
    local lOk, lTotal   = countOk(layerRows)
    local allOk = lOk == lTotal
    summaryLabel.Text       = string.format("APIs: %d/%d  |  Couches: %d/%d  |  Maj: %s",
        aOk, aTotal, lOk, lTotal, os.date("%H:%M:%S"))
    summaryLabel.TextColor3 = allOk and C.green or C.yellow
end

-- ================================================================
-- LIVE STAT ELEMENTS (stored for update)
-- ================================================================
local liveValEls = {}

local function buildLive(rows, startOrder)
    liveValEls = {}
    local ord = startOrder
    for _, r in ipairs(rows) do
        local valEl, badge = makeRow(content, r.label, r.value, r.color, ord)
        table.insert(liveValEls, { valEl = valEl, badge = badge, label = r.label })
        ord = ord + 1
    end
end

local function updateLiveEls()
    local rows = liveStats()
    for i, el in ipairs(liveValEls) do
        local r = rows[i]
        if r and el.valEl and el.valEl.Parent then
            el.valEl.Text       = r.value
            el.valEl.TextColor3 = r.color
            el.badge.BackgroundColor3 = Color3.fromRGB(
                r.color.R * 0.12, r.color.G * 0.12, r.color.B * 0.12)
        end
    end
end

-- ================================================================
-- TAB RENDERING
-- ================================================================
local cachedApiRows   = {}
local cachedLayerRows = {}

local function renderTab(idx)
    clearContent()
    liveValEls = {}

    if idx == 1 then -- APIs
        local rows = apiList()
        cachedApiRows = rows
        local ok, total = countOk(rows)
        makeSection(string.format("EXECUTOR APIs  (%d / %d)", ok, total), 0)
        makeApiRow2col(rows, 1)

    elseif idx == 2 then -- COUCHES
        local rows = layerList()
        cachedLayerRows = rows
        local ok, total = countOk(rows)
        makeSection(string.format("COUCHES ANTI-KICK  (%d / %d)", ok, total), 0)
        local ord = 1
        for _, r in ipairs(rows) do
            local color = r.ok and C.green or C.red
            makeRow(content, r.label, r.ok and "ACTIF" or "MANQUANT", color, ord)
            ord = ord + 1
        end

    elseif idx == 3 then -- LIVE
        makeSection("STATS LIVE (auto-refresh)", 0)
        buildLive(liveStats(), 1)
    end

    updateSummary(cachedApiRows, cachedLayerRows)
end

-- ================================================================
-- TAB CLICKS
-- ================================================================
local function switchTab(idx)
    activeTab = idx
    for i, tb in ipairs(tabBtns) do
        tb.BackgroundColor3 = i == idx and C.tabOn or C.tabOff
        tb.TextColor3       = i == idx and C.white or C.grey
    end
    renderTab(idx)
end

for i, tb in ipairs(tabBtns) do
    local ii = i
    tb.MouseButton1Click:Connect(function() switchTab(ii) end)
end

-- ================================================================
-- LIVE UPDATE (HEARTBEAT — only active on LIVE tab)
-- ================================================================
RS.Heartbeat:Connect(function()
    if activeTab ~= 3 then return end
    if #liveValEls == 0 then return end
    updateLiveEls()
end)

-- ================================================================
-- DRAG
-- ================================================================
local dragging, dragStart, rootStart = false, nil, nil
header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = inp.Position
        rootStart = root.Position
    end
end)
header.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(inp)
    if not dragging then return end
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then
        local d = inp.Position - dragStart
        root.Position = UDim2.new(
            rootStart.X.Scale, rootStart.X.Offset + d.X,
            rootStart.Y.Scale, rootStart.Y.Offset + d.Y)
    end
end)

-- ================================================================
-- INIT
-- ================================================================
cachedApiRows   = apiList()
cachedLayerRows = layerList()
switchTab(1)
