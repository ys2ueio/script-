-- ================================================================
-- SCRIPT ANALYSER — Duel Script
-- Détecte features, méthodes, logique et config
-- Usage : colle ton script dans SCRIPT_TEXT ci-dessous
-- ================================================================

-- Reset si déjà chargé (rerun propre)
if _G["_SA_GUI"] and _G["_SA_GUI"].Parent then
    pcall(function() _G["_SA_GUI"]:Destroy() end)
end
_G["_SA_GUI"] = nil

-- ================================================================
-- SCRIPT À ANALYSER — colle ici
-- ================================================================
local SCRIPT_TEXT = [[
-- COLLE TON SCRIPT ICI
]]
local SCRIPT_NAME = "duel_script"

-- Essaye readfile si disponible
pcall(function()
    if type(readfile) == "function" then
        local t = readfile("Duel_Script_v2.lua")
        if t and #t > 50 then SCRIPT_TEXT = t; SCRIPT_NAME = "Duel_Script_v2.lua" end
    end
end)

-- ================================================================
-- SERVICES
-- ================================================================
local LP  = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")

-- ================================================================
-- HELPERS D'ANALYSE
-- ================================================================
local function found(...)
    for _, p in ipairs({...}) do
        if SCRIPT_TEXT:find(p, 1, true) then return true end
    end
    return false
end

local function count(pat)
    local n = 0
    local ok = pcall(function()
        for _ in SCRIPT_TEXT:gmatch(pat) do n = n + 1 end
    end)
    return n
end

-- ================================================================
-- FEATURES
-- ================================================================
local CAT = {
    AK  = { n="ANTI-KICK",    c=Color3.fromRGB(235, 75,  75)  },
    AD  = { n="ANTI-DETECT",  c=Color3.fromRGB(170, 85, 240)  },
    GP  = { n="GAMEPLAY",     c=Color3.fromRGB(65, 210, 100)   },
    AB  = { n="AIMBOT",       c=Color3.fromRGB(235, 155, 45)   },
    UT  = { n="UTILITAIRE",   c=Color3.fromRGB(75, 150, 240)   },
}

local FEATURES = {
    -- ANTI-KICK
    { n="Block Player:Kick()",            cat=CAT.AK,
      det={"__namecall","getnamecallmethod","KW_KICK",'"kick"'},
      meth="getrawmetatable(LP).__namecall  ·  getnamecallmethod()  ·  newcclosure",
      log="Hook LP.__namecall. Si method=='kick' depuis serveur → return nil." },

    { n="Block game:Shutdown / BindToClose / Load", cat=CAT.AK,
      det={"getrawmetatable(game)","KW_SHUTDOWN","shutdown","bindtoclose"},
      meth="getrawmetatable(game).__namecall  ·  getnamecallmethod()  ·  newcclosure",
      log="Hook game.__namecall. Bloque shutdown/bindtoclose/load venant du serveur." },

    { n="Block TeleportService",          cat=CAT.AK,
      det={"TeleportService","KW_TELEPORT","getrawmetatable(tsvc)"},
      meth="game:GetService('TeleportService')  ·  getrawmetatable  ·  newcclosure",
      log="Hook TeleportService.__namecall. Bloque tous les appels non-executor." },

    { n="Block remotes par NOM",          cat=CAT.AK,
      det={"OnClientEvent:Connect","_isKickName","KICK_NAMES",'n:find("kick")','n:find(_KW'},
      meth="RemoteEvent.OnClientEvent  ·  UnreliableRemoteEvent  ·  RemoteFunction.OnClientInvoke",
      log="Connect vide sur tout remote dont le nom matche kick/ban/detect/anticheat/etc." },

    { n="Block remotes par PAYLOAD",      cat=CAT.AK,
      det={"hookfunction","FireServer","_isKickArg","KICK_ARGS","x-15","x-16","KW_X15","9e9"},
      meth="hookfunction(remote.FireServer)  ·  newcclosure  ·  _isKickArg check",
      log="hookfunction sur FireServer. Si arg == x-15/x-16/force_kick/kickplayer → return task.wait(9e9)." },

    { n="Interception Instance.new",      cat=CAT.AK,
      det={"hookfunction(Instance.new","_origNew","className == \"RemoteEvent\""},
      meth="hookfunction(Instance.new)  ·  newcclosure  ·  task.defer",
      log="Hook Instance.new. Chaque RemoteEvent/UnreliableRemoteEvent créé est immédiatement hooké." },

    { n="char.__newindex (block Parent=nil)", cat=CAT.AK,
      det={"__newindex","key == \"Parent\"","value == nil","_akCharOldNI","getrawmetatable(char)"},
      meth="getrawmetatable(char).__newindex  ·  setreadonly  ·  newcclosure",
      log="Hook __newindex du character. key='Parent' et value=nil → bloqué, char reste en jeu." },

    { n="Health Lock / Immortalité",      cat=CAT.AK,
      det={"humanoid.Health","humanoid.MaxHealth","HealthChanged","StateChanged","Dead","Dying"},
      meth="HealthChanged:Connect  ·  StateChanged:Connect  ·  RS.Heartbeat  ·  loop 0.05s",
      log="Multi-couche : Heartbeat+HealthChanged restore HP, StateChanged Dead→GettingUp, loop MaxHealth=100." },

    { n="Char parent restore (Workspace)",cat=CAT.AK,
      det={"c.Parent ~= Workspace","c.Parent = Workspace","char.Parent = Workspace"},
      meth="task.spawn loop (0.05s)  ·  LP.Character.Parent check",
      log="Loop 0.05s : si char.Parent ≠ Workspace → force Workspace. Bloque éjection de la map." },

    -- ANTI-DETECT
    { n="GC Scanner",                     cat=CAT.AD,
      det={"getgc(true)","islclosure","isexecutorclosure","deepScan","_gcHookRemote","gcDeepScan"},
      meth="getgc(true)  ·  islclosure()  ·  isexecutorclosure()  ·  getupvalues()  ·  hookfunction",
      log="Parcourt tout le GC. Chaque lclosure → cherche RemoteEvents hors ReplicatedStorage → hookFunction." },

    { n="GC Rescan périodique (30s)",     cat=CAT.AD,
      det={"task.wait(30)","runGCScan","scanned = {}"},
      meth="task.spawn  ·  task.wait(30)  ·  table reset scanned",
      log="Relance le GC scan complet toutes les 30s pour attraper les remotes anti-cheat injectés tard." },

    { n="Block coroutine.wrap",           cat=CAT.AD,
      det={"coroutine.wrap","getrenv()","checkcaller()","task.wait(9e9)"},
      meth="hookfunction(getrenv().coroutine.wrap)  ·  checkcaller()  ·  newcclosure",
      log="Hook coroutine.wrap. Si appelé depuis code serveur (!checkcaller) → thread suspendu indéfiniment." },

    { n="HTTP Block (telemetry/report)",  cat=CAT.AD,
      det={"syn.request","http_request","BAD_HTTP","_wrapReq","Url:lower()","KW_ANTICHEAT"},
      meth="hook syn.request / request / http_request  ·  url:find check  ·  newcclosure",
      log="Wrap fonctions HTTP. URL contient log/report/detect/anticheat/ban → return {200, body=''}." },

    { n="Keyword encoding string.char()", cat=CAT.AD,
      det={"string.char(107,105,99,107)","string.char(120,45,49,53)","KW_KICK","KW_BAN"},
      meth="string.char(...)  ·  variables _KW_*",
      log="Tous mots-clés (kick, ban, x-15, x-16, shutdown…) encodés en string.char() → évite scan string." },

    -- GAMEPLAY
    { n="Anti-Ragdoll",                   cat=CAT.GP,
      det={"cleanRagdoll","BallSocketConstraint","HingeConstraint","FallingDown","SetStateEnabled"},
      meth="StateChanged:Connect  ·  DescendantAdded:Connect  ·  SetStateEnabled(false)  ·  Motor6D.Enabled=true",
      log="Destroy constraints ragdoll. Désactive états Ragdoll/Physics/FallingDown. Force état Running." },

    { n="Infinite Jump + Fall Clamp",     cat=CAT.GP,
      det={"JumpRequest","JumpForce","AssemblyLinearVelocity","ClampFall"},
      meth="UIS.JumpRequest:Connect  ·  AssemblyLinearVelocity Y inject  ·  RS.Heartbeat clamp",
      log="JumpRequest → injecte velocity Y = JumpForce. Heartbeat clamp la chute à -ClampFall max." },

    { n="Speed Hack",                     cat=CAT.GP,
      det={"NormalSpeed","CarrySpeed","LaggerSpeed","MoveDirection","AssemblyLinearVelocity"},
      meth="RS.Heartbeat:Connect  ·  AssemblyLinearVelocity override  ·  humanoid.MoveDirection",
      log="Heartbeat : si MoveDirection > 0, force velocity H = dir×speed. Lagger mode sur L key." },

    { n="Auto-Steal (ProximityPrompt)",   cat=CAT.GP,
      det={"getconnections","PromptButtonHoldBegan","Triggered","StealData","executeSteal"},
      meth="getconnections(PromptButtonHoldBegan)  ·  getconnections(Triggered)  ·  pcall callbacks",
      log="getconnections capture hold+trigger callbacks. Fire hold → wait(duration) → fire trigger." },

    -- AIMBOT
    { n="Auto Bat Aimbot",                cat=CAT.AB,
      det={"AutoBat","autoBat","AssemblyAngularVelocity","AutoBatSpeed","aimTargetPos","Activate()"},
      meth="RS.Heartbeat  ·  AssemblyLinearVelocity pos  ·  AssemblyAngularVelocity rot  ·  bat:Activate()",
      log="Heartbeat : lead target + velocity targeting, angular pour tourner. Activate() si dist < 6 studs." },

    -- UTILITAIRE
    { n="Insta Reset (Envy style)",       cat=CAT.UT,
      det={"doSelectedReset","LP.Character = nil","Tools/Cooldown","f888ee6e"},
      meth="LP.Character=nil  ·  RS.Heartbeat FireServer loop  ·  CharacterAdded restore tools",
      log="Unequip tools → LP.Character=nil → fire remote boucle → CharacterAdded restitue les tools." },

    { n="Lagger Mode (L key)",            cat=CAT.UT,
      det={"isLaggerMode","LaggerSpeed","LaggerCarry","KeyCode.L"},
      meth="UIS.InputBegan KeyCode.L toggle  ·  getCurrentSpeed() branch",
      log="L key toggle → bascule speed sur LaggerSpeed/LaggerCarry. Simule une connexion lente." },
}

-- ================================================================
-- APIs à détecter
-- ================================================================
local API_CHECKS = {
    "hookfunction","newcclosure","getgc","islclosure","isexecutorclosure",
    "getupvalues","getrawmetatable","setreadonly","checkcaller","getnamecallmethod",
    "getrenv","getconnections","firesignal","protectgui","gethui","readfile",
    "writefile","cloneref","getnamecallmethod","syn.request","http_request",
}

-- ================================================================
-- PALETTE
-- ================================================================
local BG   = Color3.fromRGB(11, 11, 14)
local SURF = Color3.fromRGB(19, 19, 24)
local SURF2= Color3.fromRGB(24, 24, 30)
local BDR  = Color3.fromRGB(40, 40, 52)
local HDR  = Color3.fromRGB(15, 15, 19)
local WHT  = Color3.fromRGB(232, 232, 238)
local GRY  = Color3.fromRGB(128, 128, 146)
local LGR  = Color3.fromRGB(82,  82, 100)
local ACC  = Color3.fromRGB(88, 138, 255)
local GRN  = Color3.fromRGB(65, 210, 100)
local RED  = Color3.fromRGB(235, 70,  70)
local YLW  = Color3.fromRGB(235, 185, 50)

-- ================================================================
-- GUI
-- ================================================================
local W, H = 400, 490

local sg = Instance.new("ScreenGui")
sg.Name = "ScriptAnalyser"; sg.ResetOnSpawn = false; sg.DisplayOrder = 120
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(sg) end
    if protectgui then protectgui(sg) end
end)
if not pcall(function() sg.Parent = game:GetService("CoreGui") end) then
    sg.Parent = LP:WaitForChild("PlayerGui")
end
_G["_SA_GUI"] = sg

local root = Instance.new("Frame", sg)
root.Size = UDim2.new(0,W,0,H)
root.Position = UDim2.new(0.5,-W/2,0.5,-H/2)
root.BackgroundColor3 = BG; root.BorderSizePixel = 0
Instance.new("UICorner",root).CornerRadius = UDim.new(0,8)
local rStroke = Instance.new("UIStroke",root)
rStroke.Color = BDR; rStroke.Thickness = 1

-- ── Header
local hdr = Instance.new("Frame",root)
hdr.Size = UDim2.new(1,0,0,36); hdr.BackgroundColor3 = HDR; hdr.BorderSizePixel = 0

local hLbl = Instance.new("TextLabel",hdr)
hLbl.Size = UDim2.new(1,-46,1,0); hLbl.Position = UDim2.new(0,12,0,0)
hLbl.BackgroundTransparency=1; hLbl.Text="ANALYSER — "..SCRIPT_NAME
hLbl.TextColor3=WHT; hLbl.Font=Enum.Font.GothamBold; hLbl.TextSize=11
hLbl.TextXAlignment=Enum.TextXAlignment.Left; hLbl.TextTruncate=Enum.TextTruncate.AtEnd

local xBtn = Instance.new("TextButton",hdr)
xBtn.Size=UDim2.new(0,26,0,26); xBtn.Position=UDim2.new(1,-32,0,5)
xBtn.BackgroundColor3=Color3.fromRGB(165,42,42); xBtn.Text="✕"
xBtn.TextColor3=WHT; xBtn.Font=Enum.Font.GothamBold; xBtn.TextSize=12; xBtn.BorderSizePixel=0
Instance.new("UICorner",xBtn).CornerRadius=UDim.new(0,4)
xBtn.MouseButton1Click:Connect(function() sg:Destroy(); _G["_SA_GUI"]=nil end)

-- ── Separator hdr
local function sep(parent,y)
    local s=Instance.new("Frame",parent)
    s.Size=UDim2.new(1,0,0,1); s.Position=UDim2.new(0,0,0,y)
    s.BackgroundColor3=BDR; s.BorderSizePixel=0
end
sep(root,36)

-- ── Tabs
local TABS = {"FEATURES","APIs","CONFIG"}
local tabBtns = {}
local activeTab = 1

local tabBar = Instance.new("Frame",root)
tabBar.Size=UDim2.new(1,0,0,30); tabBar.Position=UDim2.new(0,0,0,37)
tabBar.BackgroundColor3=HDR; tabBar.BorderSizePixel=0
local tll=Instance.new("UIListLayout",tabBar)
tll.FillDirection=Enum.FillDirection.Horizontal; tll.SortOrder=Enum.SortOrder.LayoutOrder

for i,name in ipairs(TABS) do
    local tb=Instance.new("TextButton",tabBar)
    tb.Size=UDim2.new(0,W/#TABS,1,0); tb.LayoutOrder=i
    tb.BackgroundColor3 = i==1 and SURF2 or HDR
    tb.Text=name; tb.TextColor3=i==1 and WHT or GRY
    tb.Font=Enum.Font.GothamBold; tb.TextSize=10; tb.BorderSizePixel=0
    tabBtns[i]=tb
end
sep(root,67)

-- ── Scroll
local scroll=Instance.new("ScrollingFrame",root)
scroll.Size=UDim2.new(1,0,1,-90)
scroll.Position=UDim2.new(0,0,0,68)
scroll.BackgroundColor3=BG; scroll.BorderSizePixel=0
scroll.ScrollBarThickness=3; scroll.ScrollBarImageColor3=BDR
scroll.CanvasSize=UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y

local sll=Instance.new("UIListLayout",scroll)
sll.SortOrder=Enum.SortOrder.LayoutOrder; sll.Padding=UDim.new(0,0)

-- ── Status bar
local stBar=Instance.new("Frame",root)
stBar.Size=UDim2.new(1,0,0,22); stBar.Position=UDim2.new(0,0,1,-22)
stBar.BackgroundColor3=HDR; stBar.BorderSizePixel=0
local stLbl=Instance.new("TextLabel",stBar)
stLbl.Size=UDim2.new(1,-8,1,0); stLbl.Position=UDim2.new(0,8,0,0)
stLbl.BackgroundTransparency=1; stLbl.TextColor3=GRY
stLbl.Font=Enum.Font.Gotham; stLbl.TextSize=9
stLbl.TextXAlignment=Enum.TextXAlignment.Left

-- ================================================================
-- BUILDER UTILS
-- ================================================================
local function clear()
    for _,c in ipairs(scroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local ord = 0
local function nextOrd() ord=ord+1; return ord end

local function mkSecHdr(label,col)
    local f=Instance.new("Frame",scroll)
    f.Size=UDim2.new(1,0,0,22); f.BackgroundColor3=SURF2
    f.BorderSizePixel=0; f.LayoutOrder=nextOrd()
    local stripe=Instance.new("Frame",f)
    stripe.Size=UDim2.new(0,3,1,0); stripe.BackgroundColor3=col; stripe.BorderSizePixel=0
    local lbl=Instance.new("TextLabel",f)
    lbl.Size=UDim2.new(1,-10,1,0); lbl.Position=UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=col; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=9
    lbl.TextXAlignment=Enum.TextXAlignment.Left
end

local function mkCard(result)
    local col = result.found and result.cat.c or LGR
    local card=Instance.new("Frame",scroll)
    card.Size=UDim2.new(1,0,0,64); card.BackgroundColor3=SURF
    card.BorderSizePixel=0; card.LayoutOrder=nextOrd(); card.ClipsDescendants=true

    -- stripe
    local stripe=Instance.new("Frame",card)
    stripe.Size=UDim2.new(0,3,1,0); stripe.BackgroundColor3=col; stripe.BorderSizePixel=0

    -- Row 1 : nom + badges
    local nLbl=Instance.new("TextLabel",card)
    nLbl.Size=UDim2.new(1,-170,0,20); nLbl.Position=UDim2.new(0,10,0,4)
    nLbl.BackgroundTransparency=1; nLbl.Text=result.n
    nLbl.TextColor3 = result.found and WHT or LGR
    nLbl.Font=Enum.Font.GothamBold; nLbl.TextSize=10
    nLbl.TextXAlignment=Enum.TextXAlignment.Left; nLbl.TextTruncate=Enum.TextTruncate.AtEnd

    -- status badge
    local sBg=Instance.new("Frame",card)
    sBg.Size=UDim2.new(0,64,0,16); sBg.Position=UDim2.new(1,-144,0,6)
    sBg.BackgroundColor3=result.found and Color3.fromRGB(25,65,35) or Color3.fromRGB(60,18,18)
    sBg.BorderSizePixel=0; Instance.new("UICorner",sBg).CornerRadius=UDim.new(0,4)
    local sLbl=Instance.new("TextLabel",sBg)
    sLbl.Size=UDim2.new(1,0,1,0); sLbl.BackgroundTransparency=1
    sLbl.Text=result.found and "✓  TROUVÉ" or "✗  ABSENT"
    sLbl.TextColor3=result.found and GRN or RED
    sLbl.Font=Enum.Font.GothamBold; sLbl.TextSize=8

    -- category badge
    local cBg=Instance.new("Frame",card)
    cBg.Size=UDim2.new(0,72,0,16); cBg.Position=UDim2.new(1,-68,0,6)
    cBg.BackgroundColor3=Color3.fromRGB(col.R*255*0.14,col.G*255*0.14,col.B*255*0.14)
    cBg.BorderSizePixel=0; Instance.new("UICorner",cBg).CornerRadius=UDim.new(0,4)
    local cLbl=Instance.new("TextLabel",cBg)
    cLbl.Size=UDim2.new(1,-4,1,0); cLbl.Position=UDim2.new(0,2,0,0)
    cLbl.BackgroundTransparency=1; cLbl.Text=result.cat.n
    cLbl.TextColor3=col; cLbl.Font=Enum.Font.GothamBold; cLbl.TextSize=7
    cLbl.TextTruncate=Enum.TextTruncate.AtEnd

    -- Row 2 : méthodes
    local mLbl=Instance.new("TextLabel",card)
    mLbl.Size=UDim2.new(1,-14,0,14); mLbl.Position=UDim2.new(0,10,0,26)
    mLbl.BackgroundTransparency=1
    mLbl.Text="⚙  "..result.meth
    mLbl.TextColor3=result.found and ACC or LGR
    mLbl.Font=Enum.Font.Gotham; mLbl.TextSize=8
    mLbl.TextXAlignment=Enum.TextXAlignment.Left; mLbl.TextTruncate=Enum.TextTruncate.AtEnd

    -- Row 3 : logique
    local lLbl=Instance.new("TextLabel",card)
    lLbl.Size=UDim2.new(1,-14,0,16); lLbl.Position=UDim2.new(0,10,0,43)
    lLbl.BackgroundTransparency=1; lLbl.Text=result.log
    lLbl.TextColor3=result.found and GRY or LGR
    lLbl.Font=Enum.Font.Gotham; lLbl.TextSize=8
    lLbl.TextXAlignment=Enum.TextXAlignment.Left; lLbl.TextTruncate=Enum.TextTruncate.AtEnd

    -- separator
    local line=Instance.new("Frame",card)
    line.Size=UDim2.new(1,-4,0,1); line.Position=UDim2.new(0,2,1,-1)
    line.BackgroundColor3=BDR; line.BackgroundTransparency=0.4; line.BorderSizePixel=0
end

-- ================================================================
-- TAB 1 — FEATURES
-- ================================================================
local function buildFeatures()
    clear(); ord=0

    local results={}
    for _,feat in ipairs(FEATURES) do
        local ok=false
        for _,p in ipairs(feat.det) do
            if SCRIPT_TEXT:find(p,1,true) then ok=true; break end
        end
        table.insert(results,{n=feat.n,cat=feat.cat,meth=feat.meth,log=feat.log,found=ok})
    end

    local catOrd={CAT.AK,CAT.AD,CAT.GP,CAT.AB,CAT.UT}
    local groups={}
    for _,c in ipairs(catOrd) do groups[c]={} end
    for _,r in ipairs(results) do
        if groups[r.cat] then table.insert(groups[r.cat],r) end
    end

    local totalFound,total=0,#results
    for _,r in ipairs(results) do if r.found then totalFound=totalFound+1 end end

    for _,cat in ipairs(catOrd) do
        local items=groups[cat]
        if #items>0 then
            local cf=0
            for _,r in ipairs(items) do if r.found then cf=cf+1 end end
            mkSecHdr(cat.n.."   ("..cf.."/"..#items..")",cat.c)
            for _,r in ipairs(items) do mkCard(r) end
        end
    end

    local pct=totalFound>0 and math.floor(totalFound/total*100) or 0
    stLbl.Text=string.format("Features : %d / %d  (%d%%)   |   Script : %d caractères",totalFound,total,pct,#SCRIPT_TEXT)
    stLbl.TextColor3=pct>=80 and GRN or (pct>=40 and YLW or RED)
end

-- ================================================================
-- TAB 2 — APIs
-- ================================================================
local function buildAPIs()
    clear(); ord=0

    local rows={}
    for _,api in ipairs(API_CHECKS) do
        local n=count(api:gsub("%.","%."))
        if n>0 then table.insert(rows,{name=api,n=n}) end
    end
    table.sort(rows,function(a,b)return a.n>b.n end)

    local maxN=rows[1] and rows[1].n or 1
    mkSecHdr("EXECUTOR APIs DÉTECTÉES   ("..#rows..")",ACC)

    if #rows==0 then
        local f=Instance.new("Frame",scroll)
        f.Size=UDim2.new(1,0,0,40); f.BackgroundColor3=SURF; f.BorderSizePixel=0; f.LayoutOrder=nextOrd()
        local l=Instance.new("TextLabel",f)
        l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
        l.Text="Aucune API trouvée — colle ton script dans SCRIPT_TEXT"
        l.TextColor3=LGR; l.Font=Enum.Font.Gotham; l.TextSize=10
    end

    for _,row in ipairs(rows) do
        local f=Instance.new("Frame",scroll)
        f.Size=UDim2.new(1,0,0,30); f.BackgroundColor3=SURF; f.BorderSizePixel=0
        f.LayoutOrder=nextOrd(); f.ClipsDescendants=true

        local stripe=Instance.new("Frame",f)
        stripe.Size=UDim2.new(0,3,1,0); stripe.BackgroundColor3=ACC; stripe.BorderSizePixel=0

        local barW=math.max(3,math.floor((row.n/maxN)*(W-155)))
        local bar=Instance.new("Frame",f)
        bar.Size=UDim2.new(0,barW,1,0); bar.Position=UDim2.new(0,145,0,0)
        bar.BackgroundColor3=Color3.fromRGB(18,32,60); bar.BorderSizePixel=0

        local nl=Instance.new("TextLabel",f)
        nl.Size=UDim2.new(0,135,1,0); nl.Position=UDim2.new(0,10,0,0)
        nl.BackgroundTransparency=1; nl.Text=row.name
        nl.TextColor3=WHT; nl.Font=Enum.Font.GothamBold; nl.TextSize=10
        nl.TextXAlignment=Enum.TextXAlignment.Left

        local cl=Instance.new("TextLabel",f)
        cl.Size=UDim2.new(0,42,1,0); cl.Position=UDim2.new(1,-46,0,0)
        cl.BackgroundTransparency=1; cl.Text="×"..row.n
        cl.TextColor3=ACC; cl.Font=Enum.Font.GothamBold; cl.TextSize=10
        cl.TextXAlignment=Enum.TextXAlignment.Right

        local line=Instance.new("Frame",f)
        line.Size=UDim2.new(1,-4,0,1); line.Position=UDim2.new(0,2,1,-1)
        line.BackgroundColor3=BDR; line.BackgroundTransparency=0.4; line.BorderSizePixel=0
    end

    stLbl.Text=#rows.." APIs executor trouvées dans ce script"
    stLbl.TextColor3=ACC
end

-- ================================================================
-- TAB 3 — CONFIG
-- ================================================================
local function buildConfig()
    clear(); ord=0

    local cfg={}
    pcall(function()
        for key,val in SCRIPT_TEXT:gmatch("([%u][%u%d_]+)%s*=%s*([%d%.%-]+)") do
            if #key<=22 and tonumber(val) and not cfg[key] then cfg[key]=val end
        end
    end)

    mkSecHdr("VALEURS CONFIG / CONSTANTES",YLW)

    local n=0
    for key,val in pairs(cfg) do
        local f=Instance.new("Frame",scroll)
        f.Size=UDim2.new(1,0,0,28); f.BackgroundColor3=SURF; f.BorderSizePixel=0; f.LayoutOrder=nextOrd()

        local stripe=Instance.new("Frame",f)
        stripe.Size=UDim2.new(0,3,1,0); stripe.BackgroundColor3=YLW; stripe.BorderSizePixel=0

        local kl=Instance.new("TextLabel",f)
        kl.Size=UDim2.new(0.62,-14,1,0); kl.Position=UDim2.new(0,10,0,0)
        kl.BackgroundTransparency=1; kl.Text=key
        kl.TextColor3=GRY; kl.Font=Enum.Font.Gotham; kl.TextSize=10
        kl.TextXAlignment=Enum.TextXAlignment.Left

        local vl=Instance.new("TextLabel",f)
        vl.Size=UDim2.new(0.38,-6,1,0); vl.Position=UDim2.new(0.62,0,0,0)
        vl.BackgroundTransparency=1; vl.Text=val
        vl.TextColor3=YLW; vl.Font=Enum.Font.GothamBold; vl.TextSize=10
        vl.TextXAlignment=Enum.TextXAlignment.Right

        local line=Instance.new("Frame",f)
        line.Size=UDim2.new(1,-4,0,1); line.Position=UDim2.new(0,2,1,-1)
        line.BackgroundColor3=BDR; line.BackgroundTransparency=0.4; line.BorderSizePixel=0

        n=n+1
    end

    if n==0 then
        local f=Instance.new("Frame",scroll)
        f.Size=UDim2.new(1,0,0,36); f.BackgroundColor3=SURF; f.BorderSizePixel=0; f.LayoutOrder=nextOrd()
        local l=Instance.new("TextLabel",f)
        l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
        l.Text="Aucune constante numérique — colle ton script dans SCRIPT_TEXT"
        l.TextColor3=LGR; l.Font=Enum.Font.Gotham; l.TextSize=10
    end

    stLbl.Text=n.." constantes numériques trouvées"
    stLbl.TextColor3=YLW
end

-- ================================================================
-- TAB SWITCH
-- ================================================================
local builders={buildFeatures,buildAPIs,buildConfig}

local function switchTab(i)
    activeTab=i
    for j,tb in ipairs(tabBtns) do
        tb.BackgroundColor3 = j==i and SURF2 or HDR
        tb.TextColor3       = j==i and WHT or GRY
    end
    pcall(builders[i])
end

for i,tb in ipairs(tabBtns) do
    local ii=i
    tb.MouseButton1Click:Connect(function() switchTab(ii) end)
end

-- ================================================================
-- DRAG
-- ================================================================
local _d,_ds,_rs=false,nil,nil
hdr.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then
        _d=true; _ds=inp.Position; _rs=root.Position
    end
end)
hdr.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then _d=false end
end)
UIS.InputChanged:Connect(function(inp)
    if not _d then return end
    if inp.UserInputType==Enum.UserInputType.MouseMovement
    or inp.UserInputType==Enum.UserInputType.Touch then
        local dv=inp.Position-_ds
        root.Position=UDim2.new(_rs.X.Scale,_rs.X.Offset+dv.X,_rs.Y.Scale,_rs.Y.Offset+dv.Y)
    end
end)

-- ================================================================
-- INIT
-- ================================================================
pcall(function() switchTab(1) end)
