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
pcall(function()
    if type(readfile) == "function" then
        local t = readfile("MoonHub_v16_fixed.lua")
        if t and #t > 50 then SCRIPT_TEXT = t; SCRIPT_NAME = "MoonHub_v16_fixed.lua" end
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
    -- ── ANTI-KICK ──────────────────────────────────────────────
    { n="Block Player:Kick()",
      cat=CAT.AK,
      det={"__namecall","getnamecallmethod","KW_KICK",'"kick"',"method == \"kick\""},
      meth="getrawmetatable(LP).__namecall  ·  getnamecallmethod()  ·  newcclosure",
      log="Hook LP.__namecall. Si method=='kick' depuis serveur → return nil." },

    { n="Block game:Shutdown / BindToClose / Load",
      cat=CAT.AK,
      det={"getrawmetatable(game)","KW_SHUTDOWN","\"shutdown\"","\"bindtoclose\""},
      meth="getrawmetatable(game).__namecall  ·  getnamecallmethod()  ·  newcclosure",
      log="Hook game.__namecall. Bloque shutdown/bindtoclose/load depuis serveur." },

    { n="Block TeleportService",
      cat=CAT.AK,
      det={"TeleportService","KW_TELEPORT","getrawmetatable(tsvc)","Teleport","TeleportToSpawnByName"},
      meth="game:GetService('TeleportService')  ·  getrawmetatable  ·  newcclosure",
      log="Hook TeleportService.__namecall. Bloque tous les TPs non-executor." },

    { n="Block remotes par NOM",
      cat=CAT.AK,
      det={"OnClientEvent:Connect","_isKickName","KICK_NAMES",'n:find("kick")','n:find(_KW'},
      meth="RemoteEvent.OnClientEvent  ·  UnreliableRemoteEvent  ·  RemoteFunction.OnClientInvoke",
      log="Connect vide sur tout remote dont le nom matche kick/ban/detect/anticheat/etc." },

    { n="Block remotes par PAYLOAD",
      cat=CAT.AK,
      det={"hookfunction","FireServer","_isKickArg","x-15","x-16","KW_X15","9e9"},
      meth="hookfunction(remote.FireServer)  ·  newcclosure  ·  _isKickArg check",
      log="hookfunction sur FireServer. Arg == x-15/x-16/force_kick → return task.wait(9e9)." },

    { n="UnreliableRemoteEvent / RemoteFunction block",
      cat=CAT.AK,
      det={"UnreliableRemoteEvent","OnClientInvoke","OnClientInvoke = function","_rf_block"},
      meth="UnreliableRemoteEvent.OnClientEvent  ·  RemoteFunction.OnClientInvoke = fn",
      log="Connect vide UnreliableRemoteEvent suspects. Override OnClientInvoke → return nil." },

    { n="Interception Instance.new",
      cat=CAT.AK,
      det={"hookfunction(Instance.new","_origNew","className == \"RemoteEvent\""},
      meth="hookfunction(Instance.new)  ·  newcclosure  ·  task.defer",
      log="Hook Instance.new. Chaque RemoteEvent créé est immédiatement hooké." },

    { n="char.__newindex (block Parent=nil)",
      cat=CAT.AK,
      det={"__newindex","key == \"Parent\"","value == nil","_akCharOldNI","getrawmetatable(char)"},
      meth="getrawmetatable(char).__newindex  ·  setreadonly  ·  newcclosure",
      log="Hook __newindex du char. key='Parent' et value=nil → bloqué, char reste en jeu." },

    { n="Health Lock / Immortalité",
      cat=CAT.AK,
      det={"HealthChanged","StateChanged","Dead","Dying","hum.Health = hum.MaxHealth","_akDeathConn"},
      meth="HealthChanged:Connect  ·  StateChanged:Connect  ·  RS.Heartbeat  ·  loop 0.05s",
      log="Multi-couche : Heartbeat+HealthChanged restore HP, StateChanged Dead→GettingUp." },

    { n="Char parent restore (Workspace)",
      cat=CAT.AK,
      det={"char.Parent ~= workspace","char.Parent = workspace","c.Parent ~= Workspace"},
      meth="task.spawn loop (0.05s)  ·  LP.Character.Parent check",
      log="Loop 0.05s : si char.Parent ≠ Workspace → force Workspace. Bloque éjection map." },

    { n="Position Lock (anti-TP forcé)",
      cat=CAT.AK,
      det={"_akLastSafe","dist > 150","akPosConn","MoveDirection.Magnitude < 0.1"},
      meth="RS.Heartbeat  ·  CFrame restore  ·  dist > 150 threshold",
      log="Heartbeat compare pos à lastSafe. Déplacement > 150 studs sans input → restore CFrame." },

    -- ── ANTI-DETECT ────────────────────────────────────────────
    { n="GC Scanner",
      cat=CAT.AD,
      det={"getgc(true)","islclosure","isexecutorclosure","_gcHookRemote","_gcDeepScan"},
      meth="getgc(true)  ·  islclosure()  ·  isexecutorclosure()  ·  getupvalues()  ·  hookfunction",
      log="Parcourt tout le GC. Chaque lclosure → cherche RemoteEvents hors RS → hookFunction." },

    { n="GC Rescan périodique (30s)",
      cat=CAT.AD,
      det={"task.wait(30)","runGCScan","scanned = {}"},
      meth="task.spawn  ·  task.wait(30)  ·  table reset scanned",
      log="Relance le GC scan complet toutes les 30s pour attraper les remotes injectés tard." },

    { n="Block coroutine.wrap",
      cat=CAT.AD,
      det={"coroutine.wrap","getrenv()","checkcaller()","task.wait(9e9)"},
      meth="hookfunction(getrenv().coroutine.wrap)  ·  checkcaller()  ·  newcclosure",
      log="Hook coroutine.wrap. Si appelé depuis serveur (!checkcaller) → thread suspendu." },

    { n="HTTP Block (telemetry/report)",
      cat=CAT.AD,
      det={"syn.request","http_request","_BAD_URL","_wrapReq","Url:lower()"},
      meth="hook syn.request / request / http_request  ·  url:find check  ·  newcclosure",
      log="Wrap fonctions HTTP. URL contient log/report/detect/anticheat/ban → return {200}." },

    { n="Keyword encoding string.char()",
      cat=CAT.AD,
      det={"string.char(107,105,99,107)","string.char(120,45,49,53)","KW_KICK","KW_BAN","_KW_"},
      meth="string.char(...)  ·  variables _KW_*",
      log="Mots-clés (kick, ban, x-15…) encodés en string.char() → évite scan string." },

    { n="protectgui / gethui",
      cat=CAT.AD,
      det={"protectgui","gethui","syn.protect_gui","protect_gui"},
      meth="protectgui(sg)  ·  gethui()  ·  syn.protect_gui",
      log="GUI placé dans gethui() ou protégé via protectgui → invisible aux scripts serveur." },

    { n="cloneref (anti-hook références)",
      cat=CAT.AD,
      det={"cloneref","cloneRef"},
      meth="cloneref()  ·  applied to game services",
      log="Services dupliqués via cloneref → références uniques, résiste __index interception." },

    -- ── GAMEPLAY ───────────────────────────────────────────────
    { n="Anti-Ragdoll",
      cat=CAT.GP,
      det={"BallSocketConstraint","HingeConstraint","FallingDown","Motor6D","antiRagdoll"},
      meth="StateChanged:Connect  ·  DescendantAdded:Connect  ·  Motor6D.Enabled=true",
      log="Destroy constraints ragdoll. Désactive états Ragdoll/Physics/FallingDown → Running." },

    { n="Infinite Jump + Fall Clamp",
      cat=CAT.GP,
      det={"JumpRequest","JumpForce","AssemblyLinearVelocity","ClampFall"},
      meth="UIS.JumpRequest:Connect  ·  AssemblyLinearVelocity Y inject  ·  RS.Heartbeat clamp",
      log="JumpRequest → injecte velocity Y = JumpForce. Heartbeat clamp chute à -ClampFall." },

    { n="Speed Hack (proxy movement)",
      cat=CAT.GP,
      det={"NormalSpeed","CarrySpeed","LaggerSpeed","MoveDirection","AssemblyLinearVelocity","proxyMove"},
      meth="RS.Heartbeat  ·  AssemblyLinearVelocity override  ·  humanoid.MoveDirection  ·  proxy Part",
      log="Heartbeat : proxy part weldée au HRP, velocity = dir×speed via AssemblyLinearVelocity." },

    { n="Auto-Steal (ProximityPrompt)",
      cat=CAT.GP,
      det={"getconnections","PromptButtonHoldBegan","Triggered","executeSteal","_KAG_executeSteal"},
      meth="getconnections(PromptButtonHoldBegan)  ·  getconnections(Triggered)  ·  pcall callbacks",
      log="getconnections capture hold+trigger callbacks. Fire hold → wait(duration) → fire trigger." },

    { n="Drop Brainrot (snap sol)",
      cat=CAT.GP,
      det={"runDropBrainrot","_dropActive","DROP_ASCEND","Raycast","rr.Position.Y"},
      meth="Heartbeat ascent phase  ·  workspace:Raycast  ·  CFrame.new ground snap",
      log="Phase montée rapide (150 u/s) puis Raycast pour snap au sol exact. Évite fall damage." },

    { n="TP Down (Y=-7 snap)",
      cat=CAT.GP,
      det={"tpToGround","ToEulerAnglesYXZ","-7.00","root.CFrame = CFrame.new"},
      meth="CFrame.new fixed Y = -7.00  ·  ToEulerAnglesYXZ rotation preserve",
      log="TP direct à Y=-7 (sol du duel), conserve la rotation YXZ. Anti-éjection verticale." },

    { n="Auto Left / Right",
      cat=CAT.GP,
      det={"autoLeftEnabled","autoRightEnabled","AP_L1","AP_R1","alPhase","arPhase"},
      meth="RS.Heartbeat 2 phases  ·  proxyMove  ·  CFrame.lookAt orientation finale",
      log="2 phases : déplacement vers waypoint 1 → waypoint 2 → orientation finale vers cible." },

    { n="Medusa Counter",
      cat=CAT.GP,
      det={"medusaCounter","findMedusa","useMedusaCounter","med:Activate","medusaCounterEnabled"},
      meth="GetPropertyChangedSignal(Anchored)  ·  hum:EquipTool  ·  med:Activate()",
      log="Surveille Anchored+Transparency=1 sur char → équipe et active Medusa Head auto." },

    { n="Auto Reset on Medusa stun",
      cat=CAT.GP,
      det={"autoResetMedusa","_armDoReset","_armWatchPart","PlatformStand","MH_instareset"},
      meth="GetPropertyChangedSignal(PlatformStand)  ·  _armDoReset  ·  pcall(MH_instareset)",
      log="PlatformStand true ou part Anchored transparent → déclenche instareset auto." },

    -- ── AIMBOT ─────────────────────────────────────────────────
    { n="Auto Bat Aimbot (AB velocity)",
      cat=CAT.AB,
      det={"AB.start","AB.SPEED","AssemblyAngularVelocity","getClosestPlayerAim","tryHitBat"},
      meth="RS.RenderStepped  ·  AssemblyLinearVelocity pos  ·  AssemblyAngularVelocity rot  ·  bat:Activate()",
      log="RenderStepped : prédiction 0.14s + lerp 0.8 velocity, angular vel rotation. Activate() si dist < 5." },

    { n="Aim V2 (ABP prediction)",
      cat=CAT.AB,
      det={"ABP","ABP_CFG","CHASE_SPEED","VERT_SPEED","SWING_RANGE","ABP_findBat"},
      meth="RS.RenderStepped  ·  velocity prediction  ·  AssemblyAngularVelocity  ·  AutoRotate false",
      log="Prediction avancée : FOLLOW_DIST, HEIGHT_OFFSET, TURN_SPEED. Swing si dist < SWING_RANGE." },

    { n="Aim V3 (TP + strike)",
      cat=CAT.AB,
      det={"AimV3","sethiddenproperty","PhysicsRepRootPart","_av3Hit","_av3Nearest"},
      meth="sethiddenproperty(PhysicsRepRootPart)  ·  root.CFrame = tr.Position  ·  bat:FireServer",
      log="Heartbeat : spoofie PhysicsRepRootPart, TP à la cible si dist > 8, Activate+FireServer." },

    -- ── UTILITAIRE ─────────────────────────────────────────────
    { n="Insta Reset (Envy style)",
      cat=CAT.UT,
      det={"doSelectedReset","LP.Character = nil","Tools/Cooldown","f888ee6e","MH_instareset"},
      meth="LP.Character=nil  ·  RS.Heartbeat FireServer loop  ·  CharacterAdded restore tools",
      log="Unequip tools → LP.Character=nil → fire remote boucle → CharacterAdded restore tools." },

    { n="Anti-Lag / Nuke Optimize",
      cat=CAT.UT,
      det={"nukeOptStart","NukeOpt","SurfaceAppearance","ParticleEmitter","FogEnd=9e9","GlobalShadows=false"},
      meth="workspace.DescendantAdded  ·  Destroy particles/trails/beams  ·  GlobalShadows=false",
      log="Destroy effets visuels (particles, lights, beams), désactive ombres. FogEnd=9e9." },

    { n="Save / Load config",
      cat=CAT.UT,
      det={"writefile","JSONEncode","JSONDecode","MH_save","MH_load","rbxdata"},
      meth="writefile(file, JSONEncode(data))  ·  readfile  ·  JSONDecode",
      log="Sauvegarde speeds, keybinds, toggle states dans .json sur disk. Restaure au re-run." },

    { n="Unwalk (stop animations)",
      cat=CAT.UT,
      det={"startUnwalk","savedAnimate","GetPlayingAnimationTracks","t:Stop()"},
      meth="GetPlayingAnimationTracks  ·  t:Stop()  ·  Animate:Destroy()  ·  savedAnimate:Clone",
      log="Stoppe toutes les tracks, destroy script Animate. savedAnimate restauré sur respawn." },

    { n="Lagger Mode (key toggle)",
      cat=CAT.UT,
      det={"isLaggerMode","LaggerSpeed","LaggerCarry","KeyCode.L","laggerActive","_laggerActive"},
      meth="UIS.InputBegan KeyCode toggle  ·  getCurrentSpeed() branch",
      log="Key toggle → bascule speed sur LaggerSpeed/LaggerCarry. Simule connexion lente." },
}

-- ================================================================
-- APIs à détecter
-- ================================================================
local API_CHECKS = {
    "hookfunction","newcclosure","getgc","islclosure","isexecutorclosure",
    "getupvalues","getrawmetatable","setreadonly","checkcaller","getnamecallmethod",
    "getrenv","getconnections","firesignal","protectgui","gethui","readfile",
    "writefile","cloneref","sethiddenproperty","syn.request","http_request",
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
-- GUI  (355 × 440 — compact)
-- ================================================================
local W, H = 355, 440

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
Instance.new("UICorner",root).CornerRadius = UDim.new(0,7)
local rStroke = Instance.new("UIStroke",root)
rStroke.Color = BDR; rStroke.Thickness = 1

-- ── Header (32px)
local hdr = Instance.new("Frame",root)
hdr.Size = UDim2.new(1,0,0,32); hdr.BackgroundColor3 = HDR; hdr.BorderSizePixel = 0

local hLbl = Instance.new("TextLabel",hdr)
hLbl.Size = UDim2.new(1,-42,1,0); hLbl.Position = UDim2.new(0,10,0,0)
hLbl.BackgroundTransparency=1; hLbl.Text="ANALYSER — "..SCRIPT_NAME
hLbl.TextColor3=WHT; hLbl.Font=Enum.Font.GothamBold; hLbl.TextSize=10
hLbl.TextXAlignment=Enum.TextXAlignment.Left; hLbl.TextTruncate=Enum.TextTruncate.AtEnd

local xBtn = Instance.new("TextButton",hdr)
xBtn.Size=UDim2.new(0,22,0,22); xBtn.Position=UDim2.new(1,-27,0,5)
xBtn.BackgroundColor3=Color3.fromRGB(165,42,42); xBtn.Text="✕"
xBtn.TextColor3=WHT; xBtn.Font=Enum.Font.GothamBold; xBtn.TextSize=11; xBtn.BorderSizePixel=0
Instance.new("UICorner",xBtn).CornerRadius=UDim.new(0,4)
xBtn.MouseButton1Click:Connect(function() sg:Destroy(); _G["_SA_GUI"]=nil end)

-- ── Separator
local function sep(parent,y)
    local s=Instance.new("Frame",parent)
    s.Size=UDim2.new(1,0,0,1); s.Position=UDim2.new(0,0,0,y)
    s.BackgroundColor3=BDR; s.BorderSizePixel=0
end
sep(root,32)

-- ── Tabs (26px)
local TABS = {"FEATURES","APIs","CONFIG"}
local tabBtns = {}
local activeTab = 1

local tabBar = Instance.new("Frame",root)
tabBar.Size=UDim2.new(1,0,0,26); tabBar.Position=UDim2.new(0,0,0,33)
tabBar.BackgroundColor3=HDR; tabBar.BorderSizePixel=0
local tll=Instance.new("UIListLayout",tabBar)
tll.FillDirection=Enum.FillDirection.Horizontal; tll.SortOrder=Enum.SortOrder.LayoutOrder

for i,name in ipairs(TABS) do
    local tb=Instance.new("TextButton",tabBar)
    tb.Size=UDim2.new(0,W/#TABS,1,0); tb.LayoutOrder=i
    tb.BackgroundColor3 = i==1 and SURF2 or HDR
    tb.Text=name; tb.TextColor3=i==1 and WHT or GRY
    tb.Font=Enum.Font.GothamBold; tb.TextSize=9; tb.BorderSizePixel=0
    tabBtns[i]=tb
end
sep(root,59)

-- ── Scroll
local scroll=Instance.new("ScrollingFrame",root)
scroll.Size=UDim2.new(1,0,1,-80)
scroll.Position=UDim2.new(0,0,0,60)
scroll.BackgroundColor3=BG; scroll.BorderSizePixel=0
scroll.ScrollBarThickness=3; scroll.ScrollBarImageColor3=BDR
scroll.CanvasSize=UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y

local sll=Instance.new("UIListLayout",scroll)
sll.SortOrder=Enum.SortOrder.LayoutOrder; sll.Padding=UDim.new(0,0)

-- ── Status bar (20px)
local stBar=Instance.new("Frame",root)
stBar.Size=UDim2.new(1,0,0,20); stBar.Position=UDim2.new(0,0,1,-20)
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
    f.Size=UDim2.new(1,0,0,18); f.BackgroundColor3=SURF2
    f.BorderSizePixel=0; f.LayoutOrder=nextOrd()
    local stripe=Instance.new("Frame",f)
    stripe.Size=UDim2.new(0,3,1,0); stripe.BackgroundColor3=col; stripe.BorderSizePixel=0
    local lbl=Instance.new("TextLabel",f)
    lbl.Size=UDim2.new(1,-10,1,0); lbl.Position=UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=col; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=8
    lbl.TextXAlignment=Enum.TextXAlignment.Left
end

-- Card compacte (50px)
local function mkCard(result)
    local col = result.found and result.cat.c or LGR
    local card=Instance.new("Frame",scroll)
    card.Size=UDim2.new(1,0,0,50); card.BackgroundColor3=SURF
    card.BorderSizePixel=0; card.LayoutOrder=nextOrd(); card.ClipsDescendants=true

    local stripe=Instance.new("Frame",card)
    stripe.Size=UDim2.new(0,3,1,0); stripe.BackgroundColor3=col; stripe.BorderSizePixel=0

    -- Nom
    local nLbl=Instance.new("TextLabel",card)
    nLbl.Size=UDim2.new(1,-152,0,17); nLbl.Position=UDim2.new(0,9,0,3)
    nLbl.BackgroundTransparency=1; nLbl.Text=result.n
    nLbl.TextColor3=result.found and WHT or LGR
    nLbl.Font=Enum.Font.GothamBold; nLbl.TextSize=9
    nLbl.TextXAlignment=Enum.TextXAlignment.Left; nLbl.TextTruncate=Enum.TextTruncate.AtEnd

    -- Status badge
    local sBg=Instance.new("Frame",card)
    sBg.Size=UDim2.new(0,58,0,14); sBg.Position=UDim2.new(1,-132,0,4)
    sBg.BackgroundColor3=result.found and Color3.fromRGB(25,65,35) or Color3.fromRGB(60,18,18)
    sBg.BorderSizePixel=0; Instance.new("UICorner",sBg).CornerRadius=UDim.new(0,3)
    local sLbl=Instance.new("TextLabel",sBg)
    sLbl.Size=UDim2.new(1,0,1,0); sLbl.BackgroundTransparency=1
    sLbl.Text=result.found and "✓ TROUVÉ" or "✗ ABSENT"
    sLbl.TextColor3=result.found and GRN or RED
    sLbl.Font=Enum.Font.GothamBold; sLbl.TextSize=7

    -- Cat badge
    local cBg=Instance.new("Frame",card)
    cBg.Size=UDim2.new(0,66,0,14); cBg.Position=UDim2.new(1,-68,0,4)
    cBg.BackgroundColor3=Color3.fromRGB(col.R*255*0.14,col.G*255*0.14,col.B*255*0.14)
    cBg.BorderSizePixel=0; Instance.new("UICorner",cBg).CornerRadius=UDim.new(0,3)
    local cLbl=Instance.new("TextLabel",cBg)
    cLbl.Size=UDim2.new(1,-4,1,0); cLbl.Position=UDim2.new(0,2,0,0)
    cLbl.BackgroundTransparency=1; cLbl.Text=result.cat.n
    cLbl.TextColor3=col; cLbl.Font=Enum.Font.GothamBold; cLbl.TextSize=6
    cLbl.TextTruncate=Enum.TextTruncate.AtEnd

    -- Méthodes
    local mLbl=Instance.new("TextLabel",card)
    mLbl.Size=UDim2.new(1,-12,0,13); mLbl.Position=UDim2.new(0,9,0,21)
    mLbl.BackgroundTransparency=1
    mLbl.Text="⚙ "..result.meth
    mLbl.TextColor3=result.found and ACC or LGR
    mLbl.Font=Enum.Font.Gotham; mLbl.TextSize=7
    mLbl.TextXAlignment=Enum.TextXAlignment.Left; mLbl.TextTruncate=Enum.TextTruncate.AtEnd

    -- Logique
    local lLbl=Instance.new("TextLabel",card)
    lLbl.Size=UDim2.new(1,-12,0,13); lLbl.Position=UDim2.new(0,9,0,35)
    lLbl.BackgroundTransparency=1; lLbl.Text=result.log
    lLbl.TextColor3=result.found and GRY or LGR
    lLbl.Font=Enum.Font.Gotham; lLbl.TextSize=7
    lLbl.TextXAlignment=Enum.TextXAlignment.Left; lLbl.TextTruncate=Enum.TextTruncate.AtEnd

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
            mkSecHdr(cat.n.."  ("..cf.."/"..#items..")",cat.c)
            for _,r in ipairs(items) do mkCard(r) end
        end
    end

    local pct=totalFound>0 and math.floor(totalFound/total*100) or 0
    stLbl.Text=string.format("%d/%d features  (%d%%)  ·  %d chars",totalFound,total,pct,#SCRIPT_TEXT)
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
    mkSecHdr("EXECUTOR APIs DÉTECTÉES  ("..#rows..")",ACC)

    if #rows==0 then
        local f=Instance.new("Frame",scroll)
        f.Size=UDim2.new(1,0,0,36); f.BackgroundColor3=SURF; f.BorderSizePixel=0; f.LayoutOrder=nextOrd()
        local l=Instance.new("TextLabel",f)
        l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
        l.Text="Aucune API — colle ton script dans SCRIPT_TEXT"
        l.TextColor3=LGR; l.Font=Enum.Font.Gotham; l.TextSize=9
    end

    for _,row in ipairs(rows) do
        local f=Instance.new("Frame",scroll)
        f.Size=UDim2.new(1,0,0,26); f.BackgroundColor3=SURF; f.BorderSizePixel=0
        f.LayoutOrder=nextOrd(); f.ClipsDescendants=true

        local stripe=Instance.new("Frame",f)
        stripe.Size=UDim2.new(0,3,1,0); stripe.BackgroundColor3=ACC; stripe.BorderSizePixel=0

        local barW=math.max(3,math.floor((row.n/maxN)*(W-145)))
        local bar=Instance.new("Frame",f)
        bar.Size=UDim2.new(0,barW,1,0); bar.Position=UDim2.new(0,135,0,0)
        bar.BackgroundColor3=Color3.fromRGB(18,32,60); bar.BorderSizePixel=0

        local nl=Instance.new("TextLabel",f)
        nl.Size=UDim2.new(0,125,1,0); nl.Position=UDim2.new(0,9,0,0)
        nl.BackgroundTransparency=1; nl.Text=row.name
        nl.TextColor3=WHT; nl.Font=Enum.Font.GothamBold; nl.TextSize=9
        nl.TextXAlignment=Enum.TextXAlignment.Left

        local cl=Instance.new("TextLabel",f)
        cl.Size=UDim2.new(0,38,1,0); cl.Position=UDim2.new(1,-42,0,0)
        cl.BackgroundTransparency=1; cl.Text="×"..row.n
        cl.TextColor3=ACC; cl.Font=Enum.Font.GothamBold; cl.TextSize=9
        cl.TextXAlignment=Enum.TextXAlignment.Right

        local line=Instance.new("Frame",f)
        line.Size=UDim2.new(1,-4,0,1); line.Position=UDim2.new(0,2,1,-1)
        line.BackgroundColor3=BDR; line.BackgroundTransparency=0.4; line.BorderSizePixel=0
    end

    stLbl.Text=#rows.." APIs executor trouvées"
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
        f.Size=UDim2.new(1,0,0,24); f.BackgroundColor3=SURF; f.BorderSizePixel=0; f.LayoutOrder=nextOrd()

        local stripe=Instance.new("Frame",f)
        stripe.Size=UDim2.new(0,3,1,0); stripe.BackgroundColor3=YLW; stripe.BorderSizePixel=0

        local kl=Instance.new("TextLabel",f)
        kl.Size=UDim2.new(0.62,-12,1,0); kl.Position=UDim2.new(0,9,0,0)
        kl.BackgroundTransparency=1; kl.Text=key
        kl.TextColor3=GRY; kl.Font=Enum.Font.Gotham; kl.TextSize=9
        kl.TextXAlignment=Enum.TextXAlignment.Left

        local vl=Instance.new("TextLabel",f)
        vl.Size=UDim2.new(0.38,-6,1,0); vl.Position=UDim2.new(0.62,0,0,0)
        vl.BackgroundTransparency=1; vl.Text=val
        vl.TextColor3=YLW; vl.Font=Enum.Font.GothamBold; vl.TextSize=9
        vl.TextXAlignment=Enum.TextXAlignment.Right

        local line=Instance.new("Frame",f)
        line.Size=UDim2.new(1,-4,0,1); line.Position=UDim2.new(0,2,1,-1)
        line.BackgroundColor3=BDR; line.BackgroundTransparency=0.4; line.BorderSizePixel=0
        n=n+1
    end

    if n==0 then
        local f=Instance.new("Frame",scroll)
        f.Size=UDim2.new(1,0,0,34); f.BackgroundColor3=SURF; f.BorderSizePixel=0; f.LayoutOrder=nextOrd()
        local l=Instance.new("TextLabel",f)
        l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
        l.Text="Aucune constante — colle ton script dans SCRIPT_TEXT"
        l.TextColor3=LGR; l.Font=Enum.Font.Gotham; l.TextSize=9
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
