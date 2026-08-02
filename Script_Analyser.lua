-- ================================================================
-- SCRIPT ANALYSER — Duel Script
-- Détecte features, méthodes, logique et config d'un script duel
-- Usage : colle ton script dans SCRIPT_TEXT, ou via readfile()
-- ================================================================
if _G["_SA_LOADED"] then return end; _G["_SA_LOADED"] = true

-- ================================================================
-- SOURCE À ANALYSER
-- ================================================================
local SCRIPT_TEXT = ""
local SCRIPT_NAME = "script inconnu"

-- Essaye readfile en priorité (si executor le supporte)
local _rf = pcall(function()
    SCRIPT_TEXT = readfile("Duel_Script_v2.lua")
    SCRIPT_NAME = "Duel_Script_v2.lua"
end)
if not _rf or SCRIPT_TEXT == "" then
    -- Sinon tente avec le nom sans version
    pcall(function()
        SCRIPT_TEXT = readfile("duel_script.lua")
        SCRIPT_NAME = "duel_script.lua"
    end)
end
if SCRIPT_TEXT == "" then
    -- Fallback : colle manuellement ici
    SCRIPT_TEXT = [[
-- COLLE TON SCRIPT DUEL ICI
    ]]
    SCRIPT_NAME = "(paste manuel)"
end

-- ================================================================
-- UTILITAIRES
-- ================================================================
local LP  = game:GetService("Players").LocalPlayer
local RS  = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local function has(...)
    for _, p in ipairs({...}) do
        if SCRIPT_TEXT:find(p, 1, true) then return true end
    end
    return false
end

local function countOccurrences(pat)
    local n = 0
    for _ in SCRIPT_TEXT:gmatch(pat) do n = n + 1 end
    return n
end

local function extractConfig()
    local cfg = {}
    for key, val in SCRIPT_TEXT:gmatch("(%w+)%s*=%s*([%d%.%-]+)") do
        local k = key:upper()
        -- filtre les assignments non-config
        if not k:match("^[A-Z_]+$") then goto continue end
        if #k > 22 then goto continue end
        local n = tonumber(val)
        if n and not cfg[k] then cfg[k] = val end
        ::continue::
    end
    return cfg
end

-- ================================================================
-- DÉFINITIONS DES FEATURES
-- ================================================================
local CAT = {
    ANTID  = { name="ANTI-DETECT",  col=Color3.fromRGB(180, 90,240) },
    ANTIK  = { name="ANTI-KICK",    col=Color3.fromRGB(240, 80, 80) },
    GAMEP  = { name="GAMEPLAY",     col=Color3.fromRGB(72, 220,110) },
    AIMBOT = { name="AIMBOT",       col=Color3.fromRGB(240,160, 50) },
    UTIL   = { name="UTILITAIRE",   col=Color3.fromRGB(80, 160,240) },
}

local FEATURES = {

    -- ── ANTI-KICK ──────────────────────────────────────────────
    {
        name    = "Block :Kick() via __namecall",
        cat     = CAT.ANTIK,
        detect  = { "__namecall", "getnamecallmethod", "KW_KICK", '"kick"', "== LP" },
        methods = { "getrawmetatable(LP)", "__namecall hook", "getnamecallmethod()", "newcclosure" },
        logic   = "Hook LP.__namecall. Si method == 'kick' et appel depuis serveur → return nil.",
    },
    {
        name    = "Block game:Shutdown / BindToClose / Load",
        cat     = CAT.ANTIK,
        detect  = { "getrawmetatable(game)", "KW_SHUTDOWN", "shutdown", "bindtoclose", "KW_BINDCLOSE" },
        methods = { "getrawmetatable(game).__namecall", "getnamecallmethod()", "newcclosure" },
        logic   = "Hook game.__namecall. Bloque shutdown/bindtoclose/load depuis serveur.",
    },
    {
        name    = "Block TeleportService",
        cat     = CAT.ANTIK,
        detect  = { "TeleportService", "KW_TELEPORT", "teleport", "getrawmetatable(tsvc)" },
        methods = { "game:GetService('TeleportService')", "getrawmetatable(tsvc).__namecall", "newcclosure" },
        logic   = "Hook TeleportService.__namecall. Bloque tous les appels non-executor.",
    },
    {
        name    = "Block Remote kicks par NOM",
        cat     = CAT.ANTIK,
        detect  = { "OnClientEvent:Connect", "KICK_NAMES", "_isKickName", "n:find(\"kick\")", "n:find(_KW_KICK)" },
        methods = { "RemoteEvent.OnClientEvent", "UnreliableRemoteEvent.OnClientEvent", "RemoteFunction.OnClientInvoke", "DescendantAdded" },
        logic   = "Connect OnClientEvent vide sur tout remote dont le nom contient kick/ban/detect/etc.",
    },
    {
        name    = "Block Remote kicks par PAYLOAD (FireServer)",
        cat     = CAT.ANTIK,
        detect  = { "hookfunction", "FireServer", "_isKickArg", "KICK_ARGS", "x-15", "x-16", "KW_X15" },
        methods = { "hookfunction(remote.FireServer)", "newcclosure", "_isKickArg(tostring(a))" },
        logic   = "hookfunction sur FireServer. Intercepte x-15, x-16, force_kick, kickplayer… → return.",
    },
    {
        name    = "Interception Instance.new (remotes créés tard)",
        cat     = CAT.ANTIK,
        detect  = { "hookfunction(Instance.new", "className == \"RemoteEvent\"", "_origNew", "task.defer" },
        methods = { "hookfunction(Instance.new)", "newcclosure", "task.defer(_gcHookRemote)" },
        logic   = "Hook Instance.new. Chaque RemoteEvent créé après le scan est hooké via defer.",
    },
    {
        name    = "GC Scanner — remotes hors ReplicatedStorage",
        cat     = CAT.ANTID,
        detect  = { "getgc(true)", "islclosure", "isexecutorclosure", "deepScan", "gcDeepScan", "_gcHookRemote" },
        methods = { "getgc(true)", "islclosure()", "isexecutorclosure()", "getupvalues()", "hookfunction" },
        logic   = "Parcourt tout le GC. Pour chaque lclosure, cherche RemoteEvents hors RS → hookFunction.",
    },
    {
        name    = "GC Rescan périodique (30s)",
        cat     = CAT.ANTID,
        detect  = { "task.wait(30)", "while true do", "runGCScan", "scanned = {}" },
        methods = { "task.spawn", "task.wait(30)", "scanned table reset" },
        logic   = "Relance le GC scan complet toutes les 30s pour attraper les remotes injectés tard.",
    },
    {
        name    = "Block coroutine.wrap (anti-cheat threads)",
        cat     = CAT.ANTID,
        detect  = { "coroutine.wrap", "getrenv()", "checkcaller()", "task.wait(9e9)" },
        methods = { "hookfunction(getrenv().coroutine.wrap)", "checkcaller()", "newcclosure" },
        logic   = "Hook coroutine.wrap. Si appelé depuis serveur (!checkcaller) → task.wait(9e9).",
    },
    {
        name    = "char.__newindex (block Parent = nil)",
        cat     = CAT.ANTIK,
        detect  = { "__newindex", "key == \"Parent\"", "value == nil", "_akCharOldNI", "getrawmetatable(char)" },
        methods = { "getrawmetatable(char).__newindex", "setreadonly", "newcclosure" },
        logic   = "Hook __newindex du character. Si key='Parent' et value=nil → bloqué.",
    },
    {
        name    = "HTTP Block (reporting / telemetry)",
        cat     = CAT.ANTID,
        detect  = { "syn.request", "http_request", "BAD_HTTP", "_wrapReq", "Url:lower()", "anticheat", "KW_ANTICHEAT" },
        methods = { "hookfunction sur syn.request/request/http_request", "url:find(kw)", "newcclosure" },
        logic   = "Wrap les fonctions HTTP. Si URL contient log/report/detect/ban/anticheat → return 200 vide.",
    },
    {
        name    = "Keyword encoding (string.char)",
        cat     = CAT.ANTID,
        detect  = { "string.char(107,105,99,107)", "string.char(120,45,49,53)", "KW_KICK", "KW_BAN", "KW_X15" },
        methods = { "string.char(...)", "variables _KW_*" },
        logic   = "Tous les mots-clés (kick, ban, x-15, x-16…) encodés en string.char() — évite scan string.",
    },

    -- ── ANTI-DETECT / PROTECTION PERSO ──────────────────────────
    {
        name    = "Health Lock / Immortalité",
        cat     = CAT.ANTIK,
        detect  = { "humanoid.Health", "humanoid.MaxHealth", "HealthChanged", "StateChanged", "Dead", "Dying" },
        methods = { "HealthChanged:Connect", "StateChanged:Connect", "RS.Heartbeat:Connect", "task.spawn loop" },
        logic   = "Multi-couches : Heartbeat restore HP, loop 0.05s, StateChanged Dead→GettingUp, MaxHealth=100.",
    },
    {
        name    = "Character parent restore (Workspace)",
        cat     = CAT.ANTIK,
        detect  = { "c.Parent ~= Workspace", "c.Parent = Workspace", "char.Parent = Workspace" },
        methods = { "task.spawn loop (0.05s)", "LP.Character.Parent" },
        logic   = "Vérifie toutes les 0.05s que char.Parent == Workspace. Sinon force la remise en place.",
    },

    -- ── GAMEPLAY ─────────────────────────────────────────────────
    {
        name    = "Anti-Ragdoll",
        cat     = CAT.GAMEP,
        detect  = { "cleanRagdoll", "BallSocketConstraint", "HingeConstraint", "FallingDown", "SetStateEnabled" },
        methods = { "StateChanged:Connect", "DescendantAdded:Connect", "SetStateEnabled(false)", "Motor6D.Enabled=true" },
        logic   = "Destroy toutes les constraints ragdoll. Désactive états Ragdoll/Physics/FallingDown. Force Running.",
    },
    {
        name    = "Infinite Jump",
        cat     = CAT.GAMEP,
        detect  = { "JumpRequest", "JumpForce", "AssemblyLinearVelocity", "ClampFall" },
        methods = { "UIS.JumpRequest:Connect", "AssemblyLinearVelocity Y inject", "RS.Heartbeat clamp fall" },
        logic   = "JumpRequest → injecte velocity Y = JumpForce. Heartbeat clamp chute à -ClampFall.",
    },
    {
        name    = "Speed Hack",
        cat     = CAT.GAMEP,
        detect  = { "NormalSpeed", "CarrySpeed", "LaggerSpeed", "MoveDirection", "AssemblyLinearVelocity", "hrp.Velocity" },
        methods = { "RS.Heartbeat:Connect", "AssemblyLinearVelocity override", "humanoid.MoveDirection" },
        logic   = "Heartbeat : si MoveDirection > 0, force velocity H = dir * speed. Mode lagger = L key.",
    },
    {
        name    = "Auto-Steal (ProximityPrompt)",
        cat     = CAT.GAMEP,
        detect  = { "getconnections", "PromptButtonHoldBegan", "Triggered", "StealData", "executeSteal", "findNearestPrompt" },
        methods = { "getconnections(prompt.PromptButtonHoldBegan)", "getconnections(prompt.Triggered)", "pcall(f)" },
        logic   = "getconnections capture hold+trigger callbacks. Fire hold → wait(duration) → fire trigger.",
    },

    -- ── AIMBOT ───────────────────────────────────────────────────
    {
        name    = "Auto Bat Aimbot",
        cat     = CAT.AIMBOT,
        detect  = { "AutoBat", "autoBat", "AssemblyAngularVelocity", "AutoBatSpeed", "aimTargetPos", "Activate()" },
        methods = { "RS.Heartbeat:Connect", "AssemblyLinearVelocity positioning", "AssemblyAngularVelocity rotation", "bat:Activate()" },
        logic   = "Heartbeat : calcule lead target, angular velocity pour tourner vers cible, linear pour avancer. Activate() si < 6 studs.",
    },

    -- ── UTILITAIRE ────────────────────────────────────────────────
    {
        name    = "Insta Reset (Envy style)",
        cat     = CAT.UTIL,
        detect  = { "doSelectedReset", "LP.Character = nil", "Tools/Cooldown", "FireServer", "f888ee6e" },
        methods = { "LP.Character = nil", "RS.Heartbeat FireServer loop", "CharacterAdded restore tools" },
        logic   = "Unequip tools → LP.Character=nil → fire remote 'Tools/Cooldown' en boucle → CharacterAdded remet les tools.",
    },
    {
        name    = "Lagger Mode (L key)",
        cat     = CAT.UTIL,
        detect  = { "isLaggerMode", "LaggerSpeed", "LaggerCarry", "KeyCode.L", "KeyCode.R and isLaggerMode" },
        methods = { "UIS.InputBegan:Connect", "KeyCode.L toggle", "getCurrentSpeed() branch" },
        logic   = "Toggle via L key. Bascule le speed system sur LaggerSpeed/LaggerCarry (vitesse réduite).",
    },
}

-- ================================================================
-- PALETTE
-- ================================================================
local C = {
    bg      = Color3.fromRGB(10, 10, 13),
    surface = Color3.fromRGB(18, 18, 22),
    surface2= Color3.fromRGB(22, 22, 28),
    border  = Color3.fromRGB(38, 38, 50),
    header  = Color3.fromRGB(14, 14, 18),
    white   = Color3.fromRGB(235, 235, 240),
    grey    = Color3.fromRGB(130, 130, 148),
    lgrey   = Color3.fromRGB(90,  90,  108),
    accent  = Color3.fromRGB(90,  140, 255),
    green   = Color3.fromRGB(72,  220, 110),
    red     = Color3.fromRGB(240, 70,  70),
    yellow  = Color3.fromRGB(240, 190, 50),
    tabOn   = Color3.fromRGB(26, 26, 34),
    tabOff  = Color3.fromRGB(16, 16, 20),
}

-- ================================================================
-- ANALYSE
-- ================================================================
local function analyseFeatures()
    local results = {}
    for _, feat in ipairs(FEATURES) do
        local found  = false
        local matched = {}
        for _, pat in ipairs(feat.detect) do
            if SCRIPT_TEXT:find(pat, 1, true) then
                found = true
                table.insert(matched, pat)
            end
        end
        table.insert(results, {
            name    = feat.name,
            cat     = feat.cat,
            methods = feat.methods,
            logic   = feat.logic,
            found   = found,
            matched = matched,
        })
    end
    return results
end

local API_LIST = {
    "hookfunction","newcclosure","getgc","islclosure","isexecutorclosure",
    "getupvalues","getrawmetatable","setreadonly","checkcaller","getnamecallmethod",
    "getrenv","getconnections","firesignal","protectgui","gethui","readfile",
    "writefile","cloneref","syn%.request","syn%.protect_gui","http_request",
}

local function analyseAPIs()
    local rows = {}
    for _, api in ipairs(API_LIST) do
        local count = countOccurrences(api)
        if count > 0 then
            table.insert(rows, { name = api:gsub("%%",""), count = count })
        end
    end
    table.sort(rows, function(a, b) return a.count > b.count end)
    return rows
end

-- ================================================================
-- GUI BUILDER
-- ================================================================
local W, H = 400, 500

local sg = Instance.new("ScreenGui")
sg.Name = "ScriptAnalyser"; sg.ResetOnSpawn = false; sg.DisplayOrder = 120
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(sg) end
    if protectgui then protectgui(sg) end
end)
if not pcall(function() sg.Parent = game:GetService("CoreGui") end) then
    sg.Parent = LP:WaitForChild("PlayerGui")
end

local root = Instance.new("Frame", sg)
root.Size = UDim2.new(0, W, 0, H)
root.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
root.BackgroundColor3 = C.bg; root.BorderSizePixel = 0
root.ClipsDescendants = true
Instance.new("UICorner", root).CornerRadius = UDim.new(0, 8)
local rs = Instance.new("UIStroke", root); rs.Color = C.border; rs.Thickness = 1

-- Header
local hdr = Instance.new("Frame", root)
hdr.Size = UDim2.new(1,0,0,36); hdr.BackgroundColor3 = C.header; hdr.BorderSizePixel = 0

local hdrLbl = Instance.new("TextLabel", hdr)
hdrLbl.Size = UDim2.new(1,-60,0,36); hdrLbl.Position = UDim2.new(0,12,0,0)
hdrLbl.BackgroundTransparency = 1
hdrLbl.Text = "ANALYSER — " .. SCRIPT_NAME
hdrLbl.TextColor3 = C.white; hdrLbl.Font = Enum.Font.GothamBold; hdrLbl.TextSize = 11
hdrLbl.TextXAlignment = Enum.TextXAlignment.Left; hdrLbl.TextTruncate = Enum.TextTruncate.AtEnd

local closeBtn = Instance.new("TextButton", hdr)
closeBtn.Size = UDim2.new(0,28,0,28); closeBtn.Position = UDim2.new(1,-34,0,4)
closeBtn.BackgroundColor3 = Color3.fromRGB(170,45,45); closeBtn.Text = "✕"
closeBtn.TextColor3 = C.white; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 12
closeBtn.BorderSizePixel = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,4)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy(); _G["_SA_LOADED"] = nil end)

-- Separator
local function mkSep(parent, y)
    local s = Instance.new("Frame", parent)
    s.Size = UDim2.new(1,0,0,1); s.Position = UDim2.new(0,0,0,y)
    s.BackgroundColor3 = C.border; s.BorderSizePixel = 0
end
mkSep(root, 36)

-- Tab bar
local tabBar = Instance.new("Frame", root)
tabBar.Size = UDim2.new(1,0,0,30); tabBar.Position = UDim2.new(0,0,0,37)
tabBar.BackgroundColor3 = C.header; tabBar.BorderSizePixel = 0

local TABS = { "FEATURES", "APIs", "CONFIG" }
local tabBtns = {}
local activeTab = 1

local tbl = Instance.new("UIListLayout", tabBar)
tbl.FillDirection = Enum.FillDirection.Horizontal; tbl.SortOrder = Enum.SortOrder.LayoutOrder

for i, name in ipairs(TABS) do
    local tb = Instance.new("TextButton", tabBar)
    tb.Size = UDim2.new(0, W / #TABS, 1, 0); tb.LayoutOrder = i
    tb.BackgroundColor3 = i == 1 and C.tabOn or C.tabOff
    tb.Text = name; tb.TextColor3 = i == 1 and C.white or C.grey
    tb.Font = Enum.Font.GothamBold; tb.TextSize = 10; tb.BorderSizePixel = 0
    tabBtns[i] = tb
end

mkSep(root, 67)

-- Scroll content
local scroll = Instance.new("ScrollingFrame", root)
scroll.Size = UDim2.new(1,0,1,-88)
scroll.Position = UDim2.new(0,0,0,68)
scroll.BackgroundColor3 = C.bg; scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3; scroll.ScrollBarImageColor3 = C.border
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local ll = Instance.new("UIListLayout", scroll)
ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0,0)

-- Status bar
local statusBar = Instance.new("Frame", root)
statusBar.Size = UDim2.new(1,0,0,20); statusBar.Position = UDim2.new(0,0,1,-20)
statusBar.BackgroundColor3 = C.header; statusBar.BorderSizePixel = 0
local statusLbl = Instance.new("TextLabel", statusBar)
statusLbl.Size = UDim2.new(1,-10,1,0); statusLbl.Position = UDim2.new(0,10,0,0)
statusLbl.BackgroundTransparency = 1; statusLbl.TextColor3 = C.grey
statusLbl.Font = Enum.Font.Gotham; statusLbl.TextSize = 9; statusLbl.TextXAlignment = Enum.TextXAlignment.Left

-- ================================================================
-- CONTENT BUILDERS
-- ================================================================
local function clearScroll()
    for _, c in ipairs(scroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local function mkSectionHeader(label, color, order)
    local f = Instance.new("Frame", scroll)
    f.Size = UDim2.new(1,0,0,22); f.BackgroundColor3 = C.surface2
    f.BorderSizePixel = 0; f.LayoutOrder = order

    local stripe = Instance.new("Frame", f)
    stripe.Size = UDim2.new(0,3,1,0); stripe.BackgroundColor3 = color; stripe.BorderSizePixel = 0

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1,-14,1,0); lbl.Position = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = label
    lbl.TextColor3 = color; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left
end

local function mkFeatureCard(result, order)
    local cat   = result.cat
    local found = result.found
    local col   = found and cat.col or C.lgrey

    -- Card frame
    local card = Instance.new("Frame", scroll)
    card.Size = UDim2.new(1,0,0,62); card.BackgroundColor3 = C.surface
    card.BorderSizePixel = 0; card.LayoutOrder = order; card.ClipsDescendants = true

    -- Left border stripe
    local stripe = Instance.new("Frame", card)
    stripe.Size = UDim2.new(0,3,1,0); stripe.BackgroundColor3 = col; stripe.BorderSizePixel = 0

    -- Row 1: name + badges
    local nameLabel = Instance.new("TextLabel", card)
    nameLabel.Size = UDim2.new(1,-160,0,20); nameLabel.Position = UDim2.new(0,10,0,4)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = result.name
    nameLabel.TextColor3 = found and C.white or C.lgrey
    nameLabel.Font = Enum.Font.GothamBold; nameLabel.TextSize = 10
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

    -- Status badge
    local statBadge = Instance.new("Frame", card)
    statBadge.Size = UDim2.new(0,62,0,16); statBadge.Position = UDim2.new(1,-140,0,6)
    statBadge.BackgroundColor3 = found and Color3.fromRGB(30,70,40) or Color3.fromRGB(60,20,20)
    statBadge.BorderSizePixel = 0
    Instance.new("UICorner", statBadge).CornerRadius = UDim.new(0,4)
    local statLbl = Instance.new("TextLabel", statBadge)
    statLbl.Size = UDim2.new(1,0,1,0); statLbl.BackgroundTransparency = 1
    statLbl.Text = found and "✓ TROUVÉ" or "✗ ABSENT"
    statLbl.TextColor3 = found and C.green or C.red
    statLbl.Font = Enum.Font.GothamBold; statLbl.TextSize = 8

    -- Category badge
    local catBadge = Instance.new("Frame", card)
    catBadge.Size = UDim2.new(0,68,0,16); catBadge.Position = UDim2.new(1,-70,0,6)
    catBadge.BackgroundColor3 = Color3.fromRGB(col.R*255*0.15, col.G*255*0.15, col.B*255*0.15)
    catBadge.BorderSizePixel = 0
    Instance.new("UICorner", catBadge).CornerRadius = UDim.new(0,4)
    local catLbl = Instance.new("TextLabel", catBadge)
    catLbl.Size = UDim2.new(1,-4,1,0); catLbl.Position = UDim2.new(0,2,0,0)
    catLbl.BackgroundTransparency = 1
    catLbl.Text = cat.name; catLbl.TextColor3 = col
    catLbl.Font = Enum.Font.GothamBold; catLbl.TextSize = 7
    catLbl.TextTruncate = Enum.TextTruncate.AtEnd

    -- Row 2: methods
    local methText = #result.methods > 0 and table.concat(result.methods, "  ·  ") or "—"
    local methLabel = Instance.new("TextLabel", card)
    methLabel.Size = UDim2.new(1,-14,0,14); methLabel.Position = UDim2.new(0,10,0,26)
    methLabel.BackgroundTransparency = 1
    methLabel.Text = "⚙  " .. methText
    methLabel.TextColor3 = found and C.accent or C.lgrey
    methLabel.Font = Enum.Font.Gotham; methLabel.TextSize = 8
    methLabel.TextXAlignment = Enum.TextXAlignment.Left
    methLabel.TextTruncate = Enum.TextTruncate.AtEnd

    -- Row 3: logic description
    local logicLabel = Instance.new("TextLabel", card)
    logicLabel.Size = UDim2.new(1,-14,0,16); logicLabel.Position = UDim2.new(0,10,0,42)
    logicLabel.BackgroundTransparency = 1
    logicLabel.Text = result.logic
    logicLabel.TextColor3 = found and C.grey or C.lgrey
    logicLabel.Font = Enum.Font.Gotham; logicLabel.TextSize = 8
    logicLabel.TextXAlignment = Enum.TextXAlignment.Left
    logicLabel.TextTruncate = Enum.TextTruncate.AtEnd

    -- Bottom separator
    local line = Instance.new("Frame", card)
    line.Size = UDim2.new(1,-4,0,1); line.Position = UDim2.new(0,2,1,-1)
    line.BackgroundColor3 = C.border; line.BackgroundTransparency = 0.4; line.BorderSizePixel = 0
end

local function buildFeatures()
    clearScroll()
    local results = analyseFeatures()
    local ord     = 0

    -- group by category
    local catOrder = { CAT.ANTIK, CAT.ANTID, CAT.GAMEP, CAT.AIMBOT, CAT.UTIL }
    local grouped  = {}
    for _, cat in ipairs(catOrder) do grouped[cat] = {} end
    for _, r in ipairs(results) do
        if grouped[r.cat] then table.insert(grouped[r.cat], r) end
    end

    local found, total = 0, #results
    for _, r in ipairs(results) do if r.found then found = found + 1 end end

    for _, cat in ipairs(catOrder) do
        local items = grouped[cat]
        if #items > 0 then
            local catFound = 0
            for _, r in ipairs(items) do if r.found then catFound = catFound + 1 end end
            mkSectionHeader(cat.name .. "  (" .. catFound .. "/" .. #items .. ")", cat.col, ord)
            ord = ord + 1
            for _, r in ipairs(items) do
                mkFeatureCard(r, ord); ord = ord + 1
            end
        end
    end

    local pct = math.round(found / total * 100)
    local col = pct >= 80 and C.green or (pct >= 50 and C.yellow or C.red)
    statusLbl.Text = string.format("FEATURES : %d/%d détectées (%d%%)  |  Taille : %d chars", found, total, pct, #SCRIPT_TEXT)
    statusLbl.TextColor3 = col
end

local function buildAPIs()
    clearScroll()
    local rows = analyseAPIs()
    local ord  = 0

    mkSectionHeader("EXECUTOR APIs DÉTECTÉES (" .. #rows .. ")", C.accent, ord); ord = ord + 1

    if #rows == 0 then
        local empty = Instance.new("Frame", scroll)
        empty.Size = UDim2.new(1,0,0,40); empty.BackgroundColor3 = C.surface; empty.BorderSizePixel = 0; empty.LayoutOrder = ord
        local el = Instance.new("TextLabel", empty)
        el.Size = UDim2.new(1,0,1,0); el.BackgroundTransparency = 1
        el.Text = "Aucune API executor détectée (script vide ?)"
        el.TextColor3 = C.lgrey; el.Font = Enum.Font.Gotham; el.TextSize = 10
        return
    end

    local maxCount = rows[1] and rows[1].count or 1
    for _, row in ipairs(rows) do
        local f = Instance.new("Frame", scroll)
        f.Size = UDim2.new(1,0,0,30); f.BackgroundColor3 = C.surface; f.BorderSizePixel = 0; f.LayoutOrder = ord; ord = ord + 1
        f.ClipsDescendants = true

        -- progress bar background
        local barBg = Instance.new("Frame", f)
        barBg.Size = UDim2.new(0, math.max(2, math.floor((row.count / maxCount) * (W - 160))), 1, 0)
        barBg.Position = UDim2.new(0, 140, 0, 0)
        barBg.BackgroundColor3 = Color3.fromRGB(20, 35, 55); barBg.BorderSizePixel = 0

        local stripe = Instance.new("Frame", f)
        stripe.Size = UDim2.new(0,3,1,0); stripe.BackgroundColor3 = C.accent; stripe.BorderSizePixel = 0

        local nameL = Instance.new("TextLabel", f)
        nameL.Size = UDim2.new(0,130,1,0); nameL.Position = UDim2.new(0,10,0,0)
        nameL.BackgroundTransparency = 1; nameL.Text = row.name
        nameL.TextColor3 = C.white; nameL.Font = Enum.Font.GothamBold; nameL.TextSize = 10
        nameL.TextXAlignment = Enum.TextXAlignment.Left

        local countL = Instance.new("TextLabel", f)
        countL.Size = UDim2.new(0,40,1,0); countL.Position = UDim2.new(1,-44,0,0)
        countL.BackgroundTransparency = 1; countL.Text = "×" .. row.count
        countL.TextColor3 = C.accent; countL.Font = Enum.Font.GothamBold; countL.TextSize = 10
        countL.TextXAlignment = Enum.TextXAlignment.Right

        local line = Instance.new("Frame", f)
        line.Size = UDim2.new(1,-4,0,1); line.Position = UDim2.new(0,2,1,-1)
        line.BackgroundColor3 = C.border; line.BackgroundTransparency = 0.4; line.BorderSizePixel = 0
    end

    statusLbl.Text = #rows .. " APIs executor utilisées dans ce script"
    statusLbl.TextColor3 = C.accent
end

local function buildConfig()
    clearScroll()
    local cfg = extractConfig()
    local ord = 0

    mkSectionHeader("VALEURS CONFIG / CONSTANTES", C.yellow, ord); ord = ord + 1

    local count = 0
    for key, val in pairs(cfg) do
        local f = Instance.new("Frame", scroll)
        f.Size = UDim2.new(1,0,0,28); f.BackgroundColor3 = C.surface; f.BorderSizePixel = 0; f.LayoutOrder = ord; ord = ord + 1

        local stripe = Instance.new("Frame", f)
        stripe.Size = UDim2.new(0,3,1,0); stripe.BackgroundColor3 = C.yellow; stripe.BorderSizePixel = 0

        local kl = Instance.new("TextLabel", f)
        kl.Size = UDim2.new(0.65,-14,1,0); kl.Position = UDim2.new(0,10,0,0)
        kl.BackgroundTransparency = 1; kl.Text = key
        kl.TextColor3 = C.grey; kl.Font = Enum.Font.Gotham; kl.TextSize = 10
        kl.TextXAlignment = Enum.TextXAlignment.Left

        local vl = Instance.new("TextLabel", f)
        vl.Size = UDim2.new(0.35,0,1,0); vl.Position = UDim2.new(0.65,0,0,0)
        vl.BackgroundTransparency = 1; vl.Text = val
        vl.TextColor3 = C.yellow; vl.Font = Enum.Font.GothamBold; vl.TextSize = 10
        vl.TextXAlignment = Enum.TextXAlignment.Right

        local line = Instance.new("Frame", f)
        line.Size = UDim2.new(1,-4,0,1); line.Position = UDim2.new(0,2,1,-1)
        line.BackgroundColor3 = C.border; line.BackgroundTransparency = 0.4; line.BorderSizePixel = 0

        count = count + 1
    end

    if count == 0 then
        local empty = Instance.new("Frame", scroll)
        empty.Size = UDim2.new(1,0,0,36); empty.BackgroundColor3 = C.surface; empty.BorderSizePixel = 0; empty.LayoutOrder = ord
        local el = Instance.new("TextLabel", empty)
        el.Size = UDim2.new(1,0,1,0); el.BackgroundTransparency = 1
        el.Text = "Aucune valeur numérique trouvée (script vide ?)"
        el.TextColor3 = C.lgrey; el.Font = Enum.Font.Gotham; el.TextSize = 10
    end

    statusLbl.Text = count .. " valeurs de config / constantes trouvées"
    statusLbl.TextColor3 = C.yellow
end

-- ================================================================
-- TAB SWITCH
-- ================================================================
local tabBuilders = { buildFeatures, buildAPIs, buildConfig }

local function switchTab(idx)
    activeTab = idx
    for i, tb in ipairs(tabBtns) do
        tb.BackgroundColor3 = i == idx and C.tabOn or C.tabOff
        tb.TextColor3       = i == idx and C.white or C.grey
    end
    tabBuilders[idx]()
end

for i, tb in ipairs(tabBtns) do
    local ii = i
    tb.MouseButton1Click:Connect(function() switchTab(ii) end)
end

-- ================================================================
-- DRAG
-- ================================================================
local _drag, _ds, _rs2 = false, nil, nil
hdr.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        _drag = true; _ds = inp.Position; _rs2 = root.Position
    end
end)
hdr.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then _drag = false end
end)
UIS.InputChanged:Connect(function(inp)
    if not _drag then return end
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then
        local d = inp.Position - _ds
        root.Position = UDim2.new(_rs2.X.Scale, _rs2.X.Offset+d.X, _rs2.Y.Scale, _rs2.Y.Offset+d.Y)
    end
end)

-- ================================================================
-- INIT
-- ================================================================
switchTab(1)
