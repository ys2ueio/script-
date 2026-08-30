-- ============================================================
-- yslemEgg — Steal An Egg Hub
-- Refonte complète — nouvelle UI + moteur de mouvement unifié
-- ============================================================
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ys2ueio/script-/refs/heads/main/yslemEgg.lua"))()

if not game:IsLoaded() then game.Loaded:Wait() end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UIS                = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local HttpService        = game:GetService("HttpService")
local Lighting           = game:GetService("Lighting")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local LP                 = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

-- kill previous instance (relance propre)
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("yslemEggGui")
	if old then old:Destroy() end
	local old2 = LP.PlayerGui:FindFirstChild("yslemEggGui")
	if old2 then old2:Destroy() end
end)

-- ============================================================
-- DÉCOUVERTE DES MODULES DU JEU — par NOM, pas par chemin figé
-- ============================================================
-- Une seule passe sur tout ReplicatedStorage, indexée par nom de
-- ModuleScript — peu importe où le jeu l'a réellement placé (vérifié :
-- les vrais dossiers sont Shared.*/Data.*, pas Library.*/Directory.*
-- comme le supposait la source de référence de départ). Chaque
-- require() est isolé dans son propre pcall — une entrée cassée ne
-- désactive plus que la feature qui en dépend, jamais les autres.
local _moduleIndex = {}
for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
	if inst:IsA("ModuleScript") and not _moduleIndex[inst.Name] then
		_moduleIndex[inst.Name] = inst
	end
end

local _ModuleStatus, _ModuleFound = {}, {}
local function _tryRequire(name)
	local inst = _moduleIndex[name]
	_ModuleFound[name] = inst and inst:GetFullName() or nil
	if not inst then _ModuleStatus[name] = false; return nil end
	local ok, result = pcall(require, inst)
	_ModuleStatus[name] = ok and result ~= nil
	if ok then return result end
	return nil
end

local EggCmds    = _tryRequire("EggCmds")
local Ragdoll    = _tryRequire("Ragdoll")
local Network    = _tryRequire("Network")
local NM         = Network and Network.NET_MAP
local GEP        = _tryRequire("GuardEscapePrediction")
local GCP        = _tryRequire("GuardChasePolicy")
local RGSR       = _tryRequire("ResolveGuardSpeedRequirement")
local SPP        = _tryRequire("SpeedPowerProjection")
local GuardsD    = _tryRequire("Guards")
local AreasD     = _tryRequire("Areas")
local SlotId     = _tryRequire("AreaEggSlotIdentity")
local Save       = _tryRequire("Save")
local Constants  = _tryRequire("Constants")
local Bases      = _tryRequire("Bases")
local Treadmills = _tryRequire("Treadmills")
local Trails     = _tryRequire("Trails")

local _MODULE_NAMES = {
	"EggCmds","Network","Ragdoll","GuardEscapePrediction","GuardChasePolicy",
	"ResolveGuardSpeedRequirement","SpeedPowerProjection","Guards","Areas",
	"AreaEggSlotIdentity","Save","Constants","Bases","Treadmills","Trails",
}
do
	local lines = {"[yslemEgg] Statut des modules du jeu :"}
	for _, name in ipairs(_MODULE_NAMES) do
		if _ModuleStatus[name] then
			table.insert(lines, "  OK          "..name.."  (".._ModuleFound[name]..")")
		elseif _ModuleFound[name] then
			table.insert(lines, "  ECHEC       "..name.."  (trouve a ".._ModuleFound[name]..", require() plante)")
		else
			table.insert(lines, "  INTROUVABLE "..name)
		end
	end
	print(table.concat(lines, "\n"))
end
if SlotId then
	pcall(function()
		local keys = {}
		for k, v in pairs(SlotId) do table.insert(keys, tostring(k).." ("..typeof(v)..")") end
		table.sort(keys)
		print("[yslemEgg] AreaEggSlotIdentity — cles disponibles :\n  "..table.concat(keys, "\n  "))
	end)
end

-- ============================================================
-- REMOTES CONFIRMÉS (ReplicatedStorage.Packages.Networking)
-- ============================================================
-- Le rapport d'analyse yslemEgg a listé en direct les vrais Remote*
-- du jeu — leur Name contient déjà le "chemin" complet sous forme de
-- chaîne à slash (ex: instance nommée littéralement
-- "RF/AwayEarnings/AskCollect", parentée directement sous Networking,
-- pas une vraie hiérarchie de dossiers imbriqués). Auto Claim confirmé
-- fonctionnel avec ce système — bien plus fiable que les modules
-- Library.*/Directory.* d'origine.
local _NetworkingFolder = ReplicatedStorage:FindFirstChild("Packages")
_NetworkingFolder = _NetworkingFolder and _NetworkingFolder:FindFirstChild("Networking")

-- Accepte un nom complet ("RF/Famille/Action") ou juste l'action
-- ("Action") — repli automatique sur tout enfant du dossier dont le
-- nom SE TERMINE par ce suffixe, pour ne pas avoir à deviner la
-- famille exacte de chaque nouvelle action découverte.
local function _getRemote(name)
	if not _NetworkingFolder then return nil end
	local exact = _NetworkingFolder:FindFirstChild(name)
	if exact then return exact end
	if not name:find("/", 1, true) then
		local suffix = "/"..name
		for _, inst in ipairs(_NetworkingFolder:GetChildren()) do
			if inst.Name:sub(-#suffix) == suffix then return inst end
		end
	end
	return nil
end

local function _invokeRF(name, ...)
	local r = _getRemote(name)
	if not r or not r:IsA("RemoteFunction") then return false, "introuvable" end
	local ok, result = pcall(function(...) return r:InvokeServer(...) end, ...)
	return ok, result
end

local function _fireRE(name, ...)
	local r = _getRemote(name)
	if not r or not r:IsA("RemoteEvent") then return false end
	return pcall(function(...) r:FireServer(...) end, ...)
end

-- ============================================================
-- ZONES GARDÉES — Speed Power requis par zone
-- ============================================================
local EXIT_DIR = Vector3.new(-1,0,0)
local AREA = {}
pcall(function() EXIT_DIR = -workspace.__OBJECTS.Areas.SeparationLine.CFrame.LookVector end)
do
	local folder = workspace:FindFirstChild("__OBJECTS")
	folder = folder and folder:FindFirstChild("Areas")
	folder = folder and folder:FindFirstChild("GuardAreas")
	if folder and GuardsD and AreasD and GCP then
		for _, a in ipairs(folder:GetChildren()) do
			pcall(function()
				local d = GuardsD.Directory[AreasD.Directory[a.Name].GuardId]
				local rec = {
					cf = a.Bounds.CFrame, size = a.Bounds.Size,
					guardPos = a.Guard:GetPivot().Position,
					speed = d.WalkSpeed, radius = d.FlatRadius,
					hit = GCP.ResolveHitDistance(d.HitDistance), reqSP = nil,
				}
				if GEP and RGSR then
					pcall(function()
						local exitPos = a.ClosestExitPoint.Position
						rec.reqSP = RGSR({
							BaseGuardWalkSpeed = rec.speed, ExitDirection = EXIT_DIR,
							ExitDistance = GEP.ResolveExitDistance(rec.cf, rec.size, exitPos, EXIT_DIR),
							FlatRadius = rec.radius, GuardStartPosition = rec.guardPos,
							HitDistance = rec.hit, PlayerStartPosition = exitPos,
						})
					end)
				end
				AREA[a.Name] = rec
			end)
		end
	end
end
local curSP = 0
task.spawn(function()
	while true do
		if SPP then pcall(function() curSP = SPP.GetSpeedPower() or curSP end) end
		task.wait(1)
	end
end)
local function areaUnlocked(areaId)
	local A = AREA[areaId]
	if not A or not A.reqSP then return true end
	return curSP >= A.reqSP
end

-- ============================================================
-- SCANNER D'ŒUFS — 3 sources complémentaires :
--   1. RE/EggWorld/FieldEggShifted  — œufs physiquement dans le monde
--      (BoundsCFrame = position réelle, Mutation = rareté, NestScale =
--      poids proxy) ; fournit les données les plus riches et fiables.
--   2. AreaEggSlotsClient:GetChildren() — slots LP parsés par nom
--      (FirstAreaEgg_{userId}_{N}_{Zone}:Slot_{N}) pour la zone/île.
--   3. Fallback ProximityPrompt (autres jeux, œufs au sol).
-- ============================================================
local _RARE_KEYWORDS = {
	"secret","eternal","divine","divin","mythic","celestial","ancient",
	"rainbow","golden","shiny","radiant","corrupted","void","legendary",
}
-- Utilisé par le fallback ProximityPrompt (source 3)
local function _readEggLabels(root)
	local texts = {}
	pcall(function()
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("TextLabel") and d.Text ~= "" then table.insert(texts, d.Text) end
		end
	end)
	local full = table.concat(texts, " | ")
	local low = full:lower()
	local tags = {}
	for _, kw in ipairs(_RARE_KEYWORDS) do
		if low:find(kw, 1, true) then table.insert(tags, kw) end
	end
	local weight = full:match("([%d][%d%.,]*)%s*[Kk][Gg]")
	return full, tags, weight
end
local function _promptOwnerModel(prompt)
	local part = prompt.Parent
	if not part then return nil, nil end
	if not part:IsA("BasePart") then
		local anc = part
		while anc and not anc:IsA("BasePart") do anc = anc.Parent end
		part = anc
	end
	if not part then return nil, nil end
	local model = part
	while model and model.Parent and model.Parent ~= workspace and not model:IsA("Model") do
		model = model.Parent
	end
	return part, (model and model:IsA("Model")) and model or part
end

-- Cache réseau : uid → {pos,cf,mutation,nestScale,zone,tags,t}
local _fieldEggNet = {}

-- Zone depuis position monde (AREA doit être construit avant ce bloc)
local function _posToZone(pos)
	for zn, A in pairs(AREA) do
		if A.cf and A.size then
			local lp2 = A.cf:PointToObjectSpace(pos)
			local hs = A.size * 0.5
			if math.abs(lp2.X) <= hs.X and math.abs(lp2.Z) <= hs.Z then return zn end
		end
	end
	return "?"
end

-- Source 1 : écoute RE/EggWorld/FieldEggShifted
-- Signature observée dans l'analyse : (slotId?, {BoundsCFrame, BottomCFrame,
-- Mutation, NestScale, HasParasite, ...}) ou juste ({...}).
pcall(function()
	local re = _getRemote("RE/EggWorld/FieldEggShifted")
	if not (re and re:IsA("RemoteEvent")) then return end
	re.OnClientEvent:Connect(function(a1, a2)
		local uid, data
		if type(a2) == "table" then
			uid = tostring(a1); data = a2
		elseif type(a1) == "table" then
			uid = tostring(tick() % 1e6); data = a1
		else return end

		local cf2, pos2
		if typeof(data.BoundsCFrame) == "CFrame" then
			cf2 = data.BoundsCFrame; pos2 = cf2.Position
		elseif typeof(data.BottomCFrame) == "CFrame" then
			cf2 = data.BottomCFrame; pos2 = cf2.Position
		elseif typeof(data.CFrame) == "CFrame" then
			cf2 = data.CFrame; pos2 = cf2.Position
		end
		if not pos2 then return end

		local mutation = type(data.Mutation) == "string" and data.Mutation or nil
		local nestScale = type(data.NestScale) == "number" and data.NestScale or nil
		local zone = _posToZone(pos2)

		local tags = {}
		local low = (mutation or ""):lower()
		for _, kw in ipairs(_RARE_KEYWORDS) do
			if low:find(kw, 1, true) then table.insert(tags, kw) end
		end

		_fieldEggNet[uid] = {
			pos=pos2, cf=cf2, mutation=mutation, nestScale=nestScale,
			zone=zone, tags=tags, uid=uid, t=tick(), enabled=true,
		}
	end)
end)

-- Diagnostic AskFieldEggSnapshot (snapshot ponctuel, pas utilisé pour le farm)
local _snapshotDebugPrinted = false
task.delay(2, function()
	if _snapshotDebugPrinted then return end
	local ok, snap = _invokeRF("RF/EggWorld/AskFieldEggSnapshot")
	if not ok or type(snap) ~= "table" then return end
	_snapshotDebugPrinted = true
	local dumpOk, dump = pcall(function() return HttpService:JSONEncode(snap) end)
	print("[yslemEgg] AskFieldEggSnapshot:")
	print(dumpOk and dump:sub(1, 800) or "<non serialisable>")
end)

local _eggScanSlotsFound, _eggScanPromptTotal, _eggScanPromptEnabled = false, 0, 0
local cachedEggs = {}

task.spawn(function()
	while true do
		local eggs = {}
		local total, enabledCount = 0, 0
		local slotsRoot = workspace:FindFirstChild("AreaEggSlotsClient", true)

		-- Source 1 : réseau FieldEggShifted — TTL 60s
		-- NOTE poids : NestScale est un facteur d'échelle du modèle (~0.5-2),
		-- PAS un poids en kg — l'afficher avec "kg" serait un mensonge visuel.
		-- On ne fixe donc PAS .weight ici (l'ESP l'omet proprement) ; seul un
		-- poids réellement lu en jeu (sources 2/3, via les TextLabels du
		-- modèle) est affiché avec l'unité kg.
		local now2 = tick()
		for uid, e in pairs(_fieldEggNet) do
			if now2 - e.t > 60 then
				_fieldEggNet[uid] = nil
			else
				total = total + 1; enabledCount = enabledCount + 1
				eggs[#eggs+1] = {
					pos=e.pos, cf=e.cf, area=e.zone,
					cat=e.mutation or (e.zone.." Oeuf"),
					mutation=e.mutation, tags=e.tags,
					weight=nil, scale=e.nestScale, rawText=e.mutation or "",
					enabled=true, uid=e.uid, netOnly=true,
				}
			end
		end

		-- Source 2 : AreaEggSlotsClient:GetChildren() — slots LP par nom
		if slotsRoot then
			_eggScanSlotsFound = true
			for _, slot in ipairs(slotsRoot:GetChildren()) do
				pcall(function()
					local sname = slot.Name
					-- Filtrer : uniquement les slots du LP (contient UserId)
					if not sname:find(tostring(LP.UserId), 1, true) then return end
					-- Extraire la zone : FirstAreaEgg_{id}_{N}_{Zone}:Slot_{N}
					local zone = sname:match("_(%u[%a%s]+):Slot") or "?"
					-- Position depuis le slot ou premier BasePart descendant
					local pos3, cf3
					if slot:IsA("BasePart") then
						pos3=slot.Position; cf3=slot.CFrame
					else
						for _, d in ipairs(slot:GetDescendants()) do
							if d:IsA("BasePart") then pos3=d.Position; cf3=d.CFrame; break end
						end
					end
					if not pos3 then return end
					-- Rareté via attributs, poids réel via les TextLabels du
					-- modèle (même lecture que la source 3 — fiable et déjà
					-- affichée en kg par le jeu lui-même, contrairement à un
					-- attribut de scale qu'on ne connait pas avec certitude).
					local mutation2 = slot:GetAttribute("Mutation") or slot:GetAttribute("EggType")
					local rawText2, tags2, weight2 = _readEggLabels(slot)
					local cat2 = mutation2 or (tags2[1] and tags2[1]:upper()) or (zone.." Oeuf")
					total = total + 1; enabledCount = enabledCount + 1
					eggs[#eggs+1] = {
						slot=slot, pos=pos3, cf=cf3, area=zone,
						cat=cat2,
						mutation=mutation2 or tags2[1], tags=tags2,
						weight=weight2, rawText=rawText2,
						enabled=true, uid=sname,
					}
				end)
			end
		else
			_eggScanSlotsFound = false
		end

		-- Source 3 : fallback ProximityPrompt (autres jeux / œufs au sol)
		pcall(function()
			for _, prompt in ipairs(workspace:GetDescendants()) do
				if prompt:IsA("ProximityPrompt") then
					local action = prompt.ActionText:lower()
					local objTxt = prompt.ObjectText:lower()
					local parentName = (prompt.Parent and prompt.Parent.Name or ""):lower()
					-- Exclut explicitement les prompts de vente (marchands) —
					-- sinon un prompt "Sell Egg" pourrait être compté comme un
					-- oeuf à farmer au lieu d'une cible de livraison.
					local isSellPrompt = action:find("sell",1,true) or objTxt:find("sell",1,true)
						or action:find("vend",1,true) or objTxt:find("vend",1,true)
					if not isSellPrompt and (action:find("grab") or action:find("steal") or action:find("take")
						or action:find("pick") or action:find("collect") or action:find("hatch")
						or action:find("claim") or action:find("harvest")
						or objTxt:find("egg") or parentName:find("egg") or parentName:find("drop")
						or parentName:find("field") or parentName:find("slot")) then
						total = total + 1
						if prompt.Enabled then enabledCount = enabledCount + 1 end
						local part, model = _promptOwnerModel(prompt)
						if part then
							local full, tags3, weight3 = _readEggLabels(model or part)
							-- Priorité à une vraie rareté trouvée dans les labels du
							-- modèle plutôt qu'au texte générique du prompt ("Egg").
							local cat3 = (tags3[1] and tags3[1]:upper())
								or (objTxt ~= "" and prompt.ObjectText) or part.Name
							eggs[#eggs+1] = {
								prompt=prompt, part=part, pos=part.Position, cf=part.CFrame,
								area="Dropped",
								cat=cat3,
								mutation=tags3[1], tags=tags3, weight=weight3, rawText=full,
								enabled=prompt.Enabled,
							}
						end
					end
				end
			end
		end)

		_eggScanPromptTotal = total
		_eggScanPromptEnabled = enabledCount
		cachedEggs = eggs
		task.wait(0.5)
	end
end)

-- ============================================================
-- MARCHANDS — découverte dynamique (aucun nom figé en dur, même
-- principe que les zones/remotes plus haut) : scanne tout ProximityPrompt
-- de vente n'importe où dans workspace. Filtre strict (mentionne
-- "egg"/"oeuf") en priorité ; repli sur tout prompt de vente si rien de
-- plus précis n'est trouvé. Corrige le blocage "prend l'oeuf et reste
-- coincé" — Auto Farm s'en sert pour livrer automatiquement après la
-- prise plutôt que de rester planté sur place.
-- ============================================================
local _merchants = {}
local function _scanMerchants()
	local strict, loose = {}, {}
	pcall(function()
		for _, prompt in ipairs(workspace:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") then
				local a = prompt.ActionText:lower()
				local o = prompt.ObjectText:lower()
				local isSell = a:find("sell",1,true) or o:find("sell",1,true)
					or a:find("vend",1,true) or o:find("vend",1,true)
				if isSell then
					local part = prompt.Parent
					if part and not part:IsA("BasePart") then
						local anc = part
						while anc and not anc:IsA("BasePart") do anc = anc.Parent end
						part = anc
					end
					if part then
						local entry = {pos = part.Position, prompt = prompt}
						local mentionsEgg = a:find("egg",1,true) or o:find("egg",1,true)
							or (part.Parent ~= nil and part.Parent.Name:lower():find("egg",1,true))
						if mentionsEgg then table.insert(strict, entry) else table.insert(loose, entry) end
					end
				end
			end
		end
	end)
	local found = #strict > 0 and strict or loose
	if #found > 0 then _merchants = found end
end
_scanMerchants()
task.spawn(function()
	while true do task.wait(10); if #_merchants == 0 then _scanMerchants() end end
end)
local function _nearestMerchant(fromPos)
	local best, bestD = nil, math.huge
	for _, m in ipairs(_merchants) do
		local d = (m.pos - fromPos).Magnitude
		if d < bestD then bestD = d; best = m end
	end
	return best
end

-- ============================================================
-- PALETTE — IDENTIQUE à Moon Hub (mêmes valeurs RGB exactes, relues
-- directement dans moon_hub_patched.lua) : fond noir pur, accent bleu
-- 90-160-255, mêmes gris/argents, même dégradé "living" 4 tons.
-- ============================================================
-- NOTE : regroupées dans UNE table (au lieu de ~25 locals séparées) —
-- Lua 5.1 limite une fonction (donc tout le chunk racine) à 200 locals
-- actives ; avec ~200 features/handlers dans ce hub, chaque local évitée
-- compte. Toutes les couleurs restent accessibles via C.NOM partout dans
-- le fichier (remplacement mécanique de C_NOM -> C.NOM).
local C = {
	BG       = Color3.fromRGB(0,0,0),
	HEADER   = Color3.fromRGB(0,0,0),
	ROW      = Color3.fromRGB(0,0,0),     -- rows Moon Hub : noir + BackgroundTransparency 0.35 (pas une couleur pleine)
	BORDER   = Color3.fromRGB(40,46,58),
	WHITE    = Color3.fromRGB(255,255,255),
	MOON     = Color3.fromRGB(90,160,255),   -- accent principal (= mon ancien C.ACCENT)
	MOON2    = Color3.fromRGB(160,200,255),  -- accent clair (= mon ancien C.ACCENT2)
	MOONTEXT = Color3.fromRGB(0,10,20),
	DIM      = Color3.fromRGB(110,120,140),
	TABIDLE  = Color3.fromRGB(160,200,255),
	ON_BG    = Color3.fromRGB(20,45,80),
	OFF_BG   = Color3.fromRGB(0,0,0),
	SILVER   = Color3.fromRGB(210,222,240),
	SILVER2  = Color3.fromRGB(140,165,210),
	RED      = Color3.fromRGB(220,60,60),
	GREEN    = Color3.fromRGB(60,220,120),
	YELLOW   = Color3.fromRGB(230,200,90),   -- pas dans Moon Hub par défaut, ajouté pour les diagnostics
	GOLD     = Color3.fromRGB(255,200,60),   -- idem, pour les mutations rares de l'ESP
	DEEP1    = Color3.fromRGB(4,7,16),
	DEEP2    = Color3.fromRGB(14,28,58),
	DEEP3    = Color3.fromRGB(40,80,165),
	DEEP4    = Color3.fromRGB(90,150,255),
}
-- Alias pour compat avec le reste du fichier (noms déjà utilisés partout)
C.ACCENT, C.ACCENT2 = C.MOON, C.MOON2
C.TRACKOFF = C.OFF_BG

-- ============================================================
-- ÉTAT — St entière est persistée (que des valeurs simples)
-- ============================================================
local St = {
	instantGrab      = false,
	autoFarm         = false,
	autoHatch        = false,
	autoEquip        = false,
	autoClaim        = false,
	autoUpgradePen   = false,
	autoUpgradeTM    = false,
	autoBuyTrails    = false,
	autoRunTreadmill = false,
	antiRagdoll      = false,
	fly              = false,
	esp              = false,
	antiAFK          = false,
	antiTrap         = false,
	fullbright       = false,
	fpsBoost         = false,
	clickTp          = false,
	infJump          = false,
	speedOn          = false,
	floatLocked      = false,
	speed            = 16,
	flySpeed         = 50,
	fov              = 70,
	guiVisible       = true,
	farmZone         = "",
	farmRarity       = "",
}

-- ============================================================
-- SAUVEGARDE / CHARGEMENT
-- ============================================================
-- Exclus volontairement : Bypass Anti-Cheat (jamais ré-appliqué seul
-- au chargement — action à risque sur le character) et AimBat
-- (comportement agressif, ne doit démarrer que sur un clic frais).
local CONFIG_FILE = "yslemEgg_Config.json"
local function loadConfig()
	local ok, raw = pcall(function()
		if isfile and isfile(CONFIG_FILE) then return readfile(CONFIG_FILE) end
		return nil
	end)
	if not ok or not raw then return nil end
	local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok2 and type(data) == "table" then return data end
	return nil
end
local _savedConfig = loadConfig()
if _savedConfig then
	for k, v in pairs(_savedConfig) do
		if St[k] ~= nil and type(v) == type(St[k]) then St[k] = v end
	end
end
local _toggleRegistry = {}
local _saveDebounce = false
local function saveConfig()
	if _saveDebounce then return end
	_saveDebounce = true
	task.delay(0.5, function()
		pcall(function() if writefile then writefile(CONFIG_FILE, HttpService:JSONEncode(St)) end end)
		_saveDebounce = false
	end)
end

-- ============================================================
-- MOTEUR DE MOUVEMENT UNIFIÉ
-- ============================================================
-- [FIX MAJEUR] L'ancienne version faisait cohabiter DEUX systèmes de
-- mouvement séparés : Speed Boost (proxy Part + AssemblyLinearVelocity
-- en continu) et Auto Farm (Tween + PlatformStand ponctuel). Quand les
-- deux étaient actifs (Speed Boost restant activé entre sessions grâce
-- à la sauvegarde), ils se battaient pour le contrôle du personnage
-- chaque frame — le Tween d'Auto Farm se faisait écraser par les
-- écritures continues du proxy, donnant un mouvement cassé ou nul.
-- Anti Ragdoll (ChangeState toutes les 0.1s) coupait aussi le
-- PlatformStand du swoop en plein trajet. Une seule autorité de
-- mouvement par frame, choisie par priorité, élimine ces conflits :
-- AimBat (pilote hrp directement, prioritaire — combat) > Auto Farm
-- (pathing actif vers un œuf) > Speed Boost (déplacement manuel WASD).
local _aimBatActive = false
local _farmMoving = false
local _farmTargetPos = nil
local _farmSpeed = 40

-- (bloc do..end : ces variables ne servent qu'au moteur de mouvement,
-- on les libère du compte de locals du chunk racine après "end" — même
-- limite 200 locals que pour la palette, cf. commentaire plus haut)
local startSpeed, stopSpeed
do
	local _proxy, _ownConn = nil, nil
	local _ownTimer, _ownInterval = 0, 0.8 + math.random()*0.4

	local function _claimOwn(hrp) pcall(function() hrp:SetNetworkOwner(LP) end) end
	local function _cleanProxy()
		if _ownConn then pcall(function() _ownConn:Disconnect() end); _ownConn = nil end
		if _proxy then pcall(function() _proxy:Destroy() end); _proxy = nil end
	end
	local function _ensureProxy(hrp)
		local char = hrp.Parent
		if _proxy and _proxy.Parent == char then return _proxy end
		_cleanProxy()
		local p = Instance.new("Part")
		p.Name = "YE_Proxy"; p.Size = Vector3.new(1,1,1)
		p.Transparency = 1; p.CanCollide = false; p.Massless = true
		p.Parent = char
		local w = Instance.new("Weld", p)
		w.Part0 = hrp; w.Part1 = p; w.C0 = CFrame.new()
		_proxy = p
		_claimOwn(hrp)
		_ownConn = hrp:GetPropertyChangedSignal("ReceiveAge"):Connect(function()
			if St.speedOn or _farmMoving then task.defer(function() _claimOwn(hrp) end) end
		end)
		return p
	end

	RunService.RenderStepped:Connect(function(dt)
		local char = LP.Character
		if not char then _cleanProxy(); return end
		if _aimBatActive then return end  -- AimBat pilote hrp directement, ne pas interférer

		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp then _cleanProxy(); return end

		local wantsMove = _farmMoving or St.speedOn
		if not wantsMove then _cleanProxy(); return end

		local st = hum:GetState()
		if hum.PlatformStand or st == Enum.HumanoidStateType.Physics
			or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then
			_cleanProxy(); return
		end

		_ownTimer = _ownTimer + dt
		if _ownTimer >= _ownInterval then
			_claimOwn(hrp); _ownTimer = 0; _ownInterval = 0.8 + math.random()*0.4
		end

		local px = _ensureProxy(hrp)

		if _farmMoving and _farmTargetPos then
			local delta = _farmTargetPos - hrp.Position
			local flat = Vector3.new(delta.X, 0, delta.Z)
			if flat.Magnitude > 1 then
				local dir = flat.Unit
				px.AssemblyLinearVelocity = Vector3.new(dir.X*_farmSpeed, hrp.AssemblyLinearVelocity.Y, dir.Z*_farmSpeed)
			else
				px.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
			end
		else -- St.speedOn
			local md = hum.MoveDirection
			if md.Magnitude > 0 then
				local jit = 1 + (math.random()-0.5)*0.08
				px.AssemblyLinearVelocity = Vector3.new(md.X*St.speed*jit, hrp.AssemblyLinearVelocity.Y, md.Z*St.speed*jit)
			else
				px.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
			end
		end
	end)
	LP.CharacterAdded:Connect(function() _cleanProxy() end)

	startSpeed = function() St.speedOn = true end
	stopSpeed = function() St.speedOn = false; if not _farmMoving then _cleanProxy() end end
end

-- ============================================================
-- UI — SYSTÈME DE DESIGN
-- ============================================================
local function corner(inst, r) local c = Instance.new("UICorner", inst); c.CornerRadius = UDim.new(0, r or 8); return c end
local function stroke(inst, col, th, tr)
	local s = Instance.new("UIStroke", inst)
	s.Color = col or C.BORDER; s.Thickness = th or 1; s.Transparency = tr or 0
	return s
end
local function label(parent, text, size, color, font, ax, ay)
	local l = Instance.new("TextLabel", parent)
	l.BackgroundTransparency = 1
	l.Size = size or UDim2.new(1,0,1,0)
	l.Text = text or ""; l.TextSize = 13
	l.TextColor3 = color or C.WHITE
	l.Font = font or Enum.Font.GothamMedium
	l.TextXAlignment = ax or Enum.TextXAlignment.Left
	l.TextYAlignment = ay or Enum.TextYAlignment.Center
	return l
end

-- Dégradés/liserés "vivants" — identique à Moon Hub : rotation continue,
-- UN FRAME SUR DEUX (perf), incrément doublé (1.2) pour compenser le
-- demi-taux et garder la même vitesse perçue (~0.6/frame en moyenne).
local _liveGrads, _liveStrokes = {}, {}
local _livingFrameToggle = false
RunService.RenderStepped:Connect(function()
	_livingFrameToggle = not _livingFrameToggle
	if not _livingFrameToggle then return end
	for _, g in ipairs(_liveGrads) do
		if g and g.Parent then g.Rotation = (g.Rotation + 1.2) % 360 end
	end
	for _, g in ipairs(_liveStrokes) do
		if g and g.Parent then g.Rotation = (g.Rotation + 1.2) % 360 end
	end
end)
-- addLivingTextGradient Moon Hub : DEEP4 -> DEEP3 -> DEEP4 -> DEEP3 -> DEEP4
local function liveGrad(inst)
	local g = Instance.new("UIGradient", inst)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    C.DEEP4), ColorSequenceKeypoint.new(0.25, C.DEEP3),
		ColorSequenceKeypoint.new(0.5,  C.DEEP4), ColorSequenceKeypoint.new(0.75, C.DEEP3),
		ColorSequenceKeypoint.new(1,    C.DEEP4),
	})
	table.insert(_liveGrads, g); return g
end
-- addLivingStroke Moon Hub : liseré base DEEP3 + dégradé interne
-- DEEP1 -> DEEP2 -> DEEP1 -> DEEP2 -> DEEP1
local function addLivingStroke(parent, thickness)
	local s = Instance.new("UIStroke", parent)
	s.Color = C.DEEP3; s.Thickness = thickness or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local g = Instance.new("UIGradient", s)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    C.DEEP1), ColorSequenceKeypoint.new(0.25, C.DEEP2),
		ColorSequenceKeypoint.new(0.5,  C.DEEP1), ColorSequenceKeypoint.new(0.75, C.DEEP2),
		ColorSequenceKeypoint.new(1,    C.DEEP1),
	})
	table.insert(_liveStrokes, g); return s
end
-- makeDivider Moon Hub : ligne 1px DEEP3 + dégradé vivant, entre chaque row
local function makeDivider(page)
	local d = Instance.new("Frame", page)
	d.Size = UDim2.new(1,-12,0,1)
	d.BackgroundColor3 = C.DEEP3
	d.BorderSizePixel = 0
	liveGrad(d)
	return d
end

-- Section header — hiérarchie visuelle (regroupe des rows par thème)
local function sectionHeader(page, text)
	local wrap = Instance.new("Frame", page)
	wrap.Size = UDim2.new(1,-12,0,20)
	wrap.BackgroundTransparency = 1
	local lbl = label(wrap, text:upper(), UDim2.new(1,-8,1,0), C.DIM, Enum.Font.GothamBold)
	lbl.TextSize = 10
	lbl.Position = UDim2.new(0,4,0,0)
	return wrap
end

-- Switch "pill" Moon Hub exact : pill 40x20 (ON = C.ON_BG, OFF = C.OFF_BG,
-- transparence 0.1) + liseré vivant + bille 14x14 (ON = C.WHITE à droite,
-- OFF = C.SILVER2 à gauche) + halo respirant (UIStroke épaisseur 2.5,
-- couleur C.MOON, Transparency oscillant 0.35<->0.85 toutes les 0.9s,
-- actif seulement quand ON).
local function makeSwitch(parent, initial)
	local pill = Instance.new("Frame", parent)
	pill.Size = UDim2.new(0,40,0,20)
	pill.BackgroundColor3 = initial and C.ON_BG or C.OFF_BG
	pill.BackgroundTransparency = 0.1
	pill.BorderSizePixel = 0
	corner(pill, 10)
	addLivingStroke(pill, 1)

	local glow = Instance.new("UIStroke", pill)
	glow.Thickness = 2.5; glow.Color = C.MOON; glow.Transparency = 1
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local _glowTween = nil
	local function stopGlow()
		if _glowTween then _glowTween:Cancel(); _glowTween = nil end
		glow.Transparency = 1
	end
	local function startGlow()
		if _glowTween then return end
		glow.Transparency = 0.35
		_glowTween = TweenService:Create(glow,
			TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{Transparency = 0.85})
		_glowTween:Play()
	end

	local knob = Instance.new("Frame", pill)
	knob.Size = UDim2.new(0,14,0,14)
	knob.Position = initial and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
	knob.BackgroundColor3 = initial and C.WHITE or C.SILVER2
	knob.BorderSizePixel = 0
	corner(knob, 7)

	local btn = Instance.new("TextButton", pill)
	btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""

	local function setState(on)
		TweenService:Create(pill, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{BackgroundColor3 = on and C.ON_BG or C.OFF_BG}):Play()
		TweenService:Create(knob, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{Position = on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7),
			 BackgroundColor3 = on and C.WHITE or C.SILVER2}):Play()
		if on then startGlow() else stopGlow() end
	end
	if initial then startGlow() end
	return pill, btn, setState
end

-- Row à toggle — style Moon Hub exact (fond noir + transparence 0.35,
-- 0.15 au survol ; liseré vivant ; libellé en dégradé vivant ; pastille
-- + halo respirant ; divider après chaque row). S'enregistre
-- automatiquement pour la restauration/activation post-sauvegarde
-- (_toggleRegistry) et sauvegarde à chaque clic.
local function makeRow(page, key, displayName, onToggle)
	local row = Instance.new("Frame", page)
	row.Size = UDim2.new(1,-12,0,32)
	row.BackgroundColor3 = C.ROW
	row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0
	corner(row, 12)
	addLivingStroke(row, 1)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,10); pad.PaddingRight = UDim.new(0,10)

	row.MouseEnter:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.1), {BackgroundTransparency = 0.15}):Play()
	end)
	row.MouseLeave:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.1), {BackgroundTransparency = 0.35}):Play()
	end)

	local nameLbl = label(row, displayName, UDim2.new(1,-62,1,0), C.WHITE, Enum.Font.GothamBold)
	nameLbl.TextSize = 11
	liveGrad(nameLbl)

	local pill, btn, setSwitch = makeSwitch(row, key and St[key] or false)
	pill.Position = UDim2.new(1,-54,0.5,-10)
	pill.AnchorPoint = Vector2.new(0,0)

	local function refresh() setSwitch(St[key]) end
	refresh()

	if key then _toggleRegistry[key] = onToggle end

	btn.MouseButton1Click:Connect(function()
		St[key] = not St[key]
		refresh()
		if onToggle then pcall(onToggle, St[key]) end
		saveConfig()
	end)
	makeDivider(page)
	return row, btn, refresh
end

-- Slider — track dégradé + thumb, valeur affichée en tabular-ish
local function makeSlider(page, key, displayName, minV, maxV, fmt)
	local row = Instance.new("Frame", page)
	row.Size = UDim2.new(1,-12,0,46)
	row.BackgroundColor3 = C.ROW
	row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0; corner(row, 12)
	addLivingStroke(row, 1)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,10); pad.PaddingRight = UDim.new(0,10)

	local nameLbl = label(row, displayName, UDim2.new(0.6,0,0,20), C.WHITE, Enum.Font.GothamMedium)
	nameLbl.TextSize = 12; nameLbl.Position = UDim2.new(0,0,0,4)

	local valLbl = label(row, "", UDim2.new(0.4,0,0,20), C.ACCENT2, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
	valLbl.TextSize = 12; valLbl.Position = UDim2.new(0.6,0,0,4)

	local track = Instance.new("Frame", row)
	track.Size = UDim2.new(1,0,0,5)
	track.Position = UDim2.new(0,0,1,-13)
	track.BackgroundColor3 = C.TRACKOFF
	track.BorderSizePixel = 0; corner(track, 3)

	local fill = Instance.new("Frame", track)
	fill.Size = UDim2.new(0,0,1,0)
	fill.BackgroundColor3 = C.ACCENT
	fill.BorderSizePixel = 0; corner(fill, 3)
	local fillGrad = Instance.new("UIGradient", fill)
	fillGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, C.DEEP2), ColorSequenceKeypoint.new(1, C.ACCENT2)})

	local thumb = Instance.new("Frame", track)
	thumb.Size = UDim2.new(0,12,0,12)
	thumb.AnchorPoint = Vector2.new(0.5,0.5)
	thumb.BackgroundColor3 = C.WHITE
	thumb.BorderSizePixel = 0; corner(thumb, 6)
	stroke(thumb, C.ACCENT, 1.5)

	local function setVal(v, skipSave)
		v = math.clamp(math.floor(v), minV, maxV)
		St[key] = v
		local t = (v-minV)/(maxV-minV)
		fill.Size = UDim2.new(t,0,1,0)
		thumb.Position = UDim2.new(t,0,0.5,0)
		valLbl.Text = fmt and string.format(fmt, v) or tostring(v)
		if not skipSave then saveConfig() end
	end
	setVal(St[key] or minV, true)

	local dragging = false
	track.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if not dragging then return end
		if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then return end
		local abs, sz = track.AbsolutePosition, track.AbsoluteSize
		local rel = math.clamp((inp.Position.X - abs.X) / sz.X, 0, 1)
		setVal(minV + (maxV-minV)*rel)
	end)
	makeDivider(page)
	return row, setVal
end

-- Bouton d'action simple (pas de toggle, juste un clic) — même habillage
-- de row que makeRow (transparence 0.35, coins 12, liseré vivant) pour
-- une interface cohérente de bout en bout.
local function makeButton(page, displayName, btnText, onClick, danger)
	local row = Instance.new("Frame", page)
	row.Size = UDim2.new(1,-12,0,32)
	row.BackgroundColor3 = C.ROW; row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0; corner(row, 12)
	addLivingStroke(row, 1)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,10); pad.PaddingRight = UDim.new(0,10)
	label(row, displayName, UDim2.new(1,-64,1,0), C.WHITE, Enum.Font.GothamMedium).TextSize = 12
	local btn = Instance.new("TextButton", row)
	btn.Size = UDim2.new(0,56,0,20)
	btn.Position = UDim2.new(1,-56,0.5,-10)
	btn.BackgroundColor3 = danger and Color3.fromRGB(58,20,20) or Color3.fromRGB(20,32,54)
	btn.TextColor3 = danger and C.RED or C.ACCENT2
	btn.Text = btnText; btn.TextSize = 10; btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0; corner(btn, 7)
	if onClick then btn.MouseButton1Click:Connect(onClick) end
	makeDivider(page)
	return row, btn
end

-- ============================================================
-- CONSTRUCTION DE L'INTERFACE
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "yslemEggGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP.PlayerGui end

-- Fenêtre principale — proportions Moon Hub exactes : 300x340, coins 24,
-- header 48px.
local main = Instance.new("Frame", gui)
main.Name = "Main"
main.Size = UDim2.new(0,300,0,340)
main.Position = UDim2.new(0,14,0.5,-170)
main.BackgroundColor3 = C.BG
main.BorderSizePixel = 0
main.ClipsDescendants = true
corner(main, 24)
stroke(main, C.BORDER, 1.5)
local mainShadow = Instance.new("UIStroke", main)
mainShadow.Color = C.ACCENT; mainShadow.Thickness = 1; mainShadow.Transparency = 0.85

-- Header
local header = Instance.new("Frame", main)
header.Size = UDim2.new(1,0,0,48)
header.BackgroundColor3 = C.BG
header.BorderSizePixel = 0
corner(header, 24)

local titleLbl = Instance.new("TextLabel", header)
titleLbl.BackgroundTransparency = 1
titleLbl.Size = UDim2.new(1,-56,1,0)
titleLbl.Position = UDim2.new(0,14,0,0)
titleLbl.Text = "yslemEgg"
titleLbl.TextSize = 16
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.TextYAlignment = Enum.TextYAlignment.Center
liveGrad(titleLbl)

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0,24,0,24)
closeBtn.Position = UDim2.new(1,-32,0.5,-12)
closeBtn.BackgroundColor3 = Color3.fromRGB(58,20,20)
closeBtn.Text = "✕"; closeBtn.TextSize = 12
closeBtn.TextColor3 = C.RED; closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0; corner(closeBtn, 7)

local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.new(0,24,0,24)
minBtn.Position = UDim2.new(1,-60,0.5,-12)
minBtn.BackgroundColor3 = Color3.fromRGB(24,26,35)
minBtn.Text = "–"; minBtn.TextSize = 14
minBtn.TextColor3 = C.ACCENT2; minBtn.Font = Enum.Font.GothamBold
minBtn.BorderSizePixel = 0; corner(minBtn, 7)

local sep = Instance.new("Frame", main)
sep.Size = UDim2.new(1,-24,0,1)
sep.Position = UDim2.new(0,12,0,48)
sep.BackgroundColor3 = C.BORDER; sep.BorderSizePixel = 0

-- Tab bar — style Moon Hub exact : boutons 44px fixes (pas de division
-- proportionnelle), pilule pleine active (C.MOON / texte C.MOONTEXT),
-- inactive semi-transparente (18,22,30 @ 0.5 / texte C.TABIDLE), liseré
-- vivant, flash de transition au clic.
local TAB_Y = 54
local tabBar = Instance.new("Frame", main)
tabBar.Size = UDim2.new(1,0,0,32)
tabBar.Position = UDim2.new(0,0,0,TAB_Y)
tabBar.BackgroundTransparency = 1
local tabList = Instance.new("UIListLayout", tabBar)
tabList.FillDirection = Enum.FillDirection.Horizontal
tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabList.VerticalAlignment = Enum.VerticalAlignment.Center
tabList.Padding = UDim.new(0,8)

local TABS = {"Farm","Speed","Visual","Misc"}
local tabBtns, tabFlashes = {}, {}
for _, name in ipairs(TABS) do
	local btn = Instance.new("TextButton", tabBar)
	btn.Size = UDim2.new(0,44,0,28)
	btn.BackgroundColor3 = Color3.fromRGB(18,22,30)
	btn.BackgroundTransparency = 0.5
	btn.Text = name; btn.TextSize = 11
	btn.TextColor3 = C.TABIDLE; btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0
	corner(btn, 10)
	addLivingStroke(btn, 1)
	local flash = Instance.new("Frame", btn)
	flash.Size = UDim2.new(1,0,1,0)
	flash.BackgroundColor3 = C.WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = btn.ZIndex + 1
	corner(flash, 10)
	tabBtns[name] = btn
	tabFlashes[name] = flash
end

local CONTENT_Y = TAB_Y + 32 + 6
local contentArea = Instance.new("Frame", main)
contentArea.Size = UDim2.new(1,0,1,-CONTENT_Y-24)
contentArea.Position = UDim2.new(0,0,0,CONTENT_Y)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true

local pages = {}
for _, name in ipairs(TABS) do
	local pg = Instance.new("ScrollingFrame", contentArea)
	pg.Name = name
	pg.Size = UDim2.new(1,0,1,0)
	pg.BackgroundTransparency = 1
	pg.BorderSizePixel = 0
	pg.ScrollBarThickness = 3
	pg.ScrollBarImageColor3 = C.ACCENT
	pg.CanvasSize = UDim2.new(0,0,0,0)
	pg.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pg.Visible = false
	local list = Instance.new("UIListLayout", pg)
	list.Padding = UDim.new(0,5)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	local pad = Instance.new("UIPadding", pg)
	pad.PaddingTop = UDim.new(0,4); pad.PaddingLeft = UDim.new(0,6); pad.PaddingRight = UDim.new(0,6)
	pages[name] = pg
end

-- Transition d'onglet Moon Hub : pilule pleine + flash qui s'efface +
-- léger glissement d'entrée du contenu.
local activeTab = nil
local function switchTab(name)
	if activeTab == name then return end
	activeTab = name
	for _, n in ipairs(TABS) do
		local on = n == name
		local btn, flash = tabBtns[n], tabFlashes[n]
		if on then
			pages[n].Visible = true
			pages[n].Position = UDim2.new(0,8,0,0)
			TweenService:Create(pages[n], TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{Position = UDim2.new(0,0,0,0)}):Play()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = C.MOON, BackgroundTransparency = 0, TextColor3 = C.MOONTEXT}):Play()
			flash.BackgroundTransparency = 0.5
			TweenService:Create(flash, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
		else
			pages[n].Visible = false
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(18,22,30), BackgroundTransparency = 0.5, TextColor3 = C.TABIDLE}):Play()
		end
	end
end
for _, name in ipairs(TABS) do
	tabBtns[name].MouseButton1Click:Connect(function() switchTab(name) end)
end

-- Status bar
local statusBar = Instance.new("Frame", main)
statusBar.Size = UDim2.new(1,0,0,24)
statusBar.Position = UDim2.new(0,0,1,-24)
statusBar.BackgroundColor3 = Color3.fromRGB(5,6,9)
statusBar.BorderSizePixel = 0

local statusDot = Instance.new("Frame", statusBar)
statusDot.Size = UDim2.new(0,6,0,6)
statusDot.Position = UDim2.new(0,10,0.5,-3)
statusDot.BackgroundColor3 = C.DIM
statusDot.BorderSizePixel = 0
corner(statusDot, 3)

local statusLbl = Instance.new("TextLabel", statusBar)
statusLbl.BackgroundTransparency = 1
statusLbl.Size = UDim2.new(1,-24,1,0)
statusLbl.Position = UDim2.new(0,22,0,0)
statusLbl.Text = "Idle"
statusLbl.TextSize = 10; statusLbl.Font = Enum.Font.Gotham
statusLbl.TextColor3 = C.DIM
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local function setStatus(txt, col)
	statusLbl.Text = txt
	statusLbl.TextColor3 = col or C.DIM
	statusDot.BackgroundColor3 = col or C.DIM
end

-- ============================================================
-- ONGLET FARM
-- ============================================================
local farmPage = pages["Farm"]

-- Diagnostic modules
do
	local okCount, total = 0, 0
	for _, ok in pairs(_ModuleStatus) do total = total+1; if ok then okCount = okCount+1 end end
	local allOk = okCount == total
	local row = Instance.new("Frame", farmPage)
	row.Size = UDim2.new(1,-12,0,26)
	row.BackgroundColor3 = C.ROW; row.BorderSizePixel = 0; corner(row, 7)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,10); pad.PaddingRight = UDim.new(0,10)
	local lbl = label(row, "Modules: "..okCount.."/"..total.." charges", UDim2.new(1,0,1,0),
		allOk and C.GREEN or C.YELLOW, Enum.Font.GothamMedium)
	lbl.TextSize = 11
	if not allOk then
		local btn = Instance.new("TextButton", row)
		btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""
		btn.MouseButton1Click:Connect(function()
			local lines = {}
			for name, ok in pairs(_ModuleStatus) do
				local path = _ModuleFound[name]
				if ok then table.insert(lines, "OK          "..name.."  ("..tostring(path)..")")
				elseif path then table.insert(lines, "ECHEC       "..name.."  (trouve a "..path..", require() plante)")
				else table.insert(lines, "INTROUVABLE "..name) end
			end
			table.sort(lines)
			local msg = table.concat(lines, "\n")
			print("[yslemEgg] Statut modules:\n"..msg)
			pcall(function() if setclipboard then setclipboard(msg) end end)
			setStatus("Details copies / voir console (F9)", C.YELLOW)
		end)
	end
end

sectionHeader(farmPage, "Grab")

-- Instant Grab
local _instaGrabConn = nil
local _instaGrabOriginal = setmetatable({}, {__mode = "k"})
local function setInstantGrab(on)
	St.instantGrab = on
	if on then
		if _instaGrabConn then return end
		_instaGrabConn = ProximityPromptService.PromptShown:Connect(function(prompt)
			if not St.instantGrab then return end
			if _instaGrabOriginal[prompt] == nil then _instaGrabOriginal[prompt] = prompt.HoldDuration end
			prompt.HoldDuration = 0
		end)
	else
		if _instaGrabConn then _instaGrabConn:Disconnect(); _instaGrabConn = nil end
		for prompt, orig in pairs(_instaGrabOriginal) do
			pcall(function() if prompt and prompt.Parent then prompt.HoldDuration = orig end end)
		end
	end
end
makeRow(farmPage, "instantGrab", "Instant Grab", function(on) setInstantGrab(on) end)

-- Auto Farm — moteur unifié (fini le Tween qui se battait avec Speed
-- Boost/Anti Ragdoll). Timeout de sécurité 6s par trajet : jamais
-- bloqué indéfiniment même si le trajet échoue. Après la prise, va
-- automatiquement livrer au marchand le plus proche (découverte
-- dynamique) au lieu de rester planté sur l'œuf — et TOUT s'arrête
-- immédiatement (mouvement + spam) dès que Auto Farm est désactivé,
-- même en plein trajet.
task.spawn(function()
	local isFarmingEgg = false
	local function _farmFullStop()
		_farmMoving = false
		_farmTargetPos = nil
		isFarmingEgg = false
	end

	while true do
		task.wait(0.2)

		if not St.autoFarm then
			-- Coupe tout immédiatement si l'utilisateur désactive en plein
			-- trajet (les boucles internes ci-dessous vérifient aussi
			-- St.autoFarm en direct, donc l'arrêt réel est quasi instantané —
			-- ceci ne fait que remettre l'état à zéro entre deux cycles).
			if isFarmingEgg or _farmMoving then _farmFullStop() end
		else
		local char = LP.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")

		if not isFarmingEgg and rootPart then
			if #cachedEggs == 0 then
				setStatus(string.format("Farm: 0 oeuf — slots=%s total=%d actif=%d",
					_eggScanSlotsFound and "oui" or "non", _eggScanPromptTotal, _eggScanPromptEnabled), C.DIM)
			else
				-- Ne cibler que les oeufs PRÊTS, filtres zone+rareté actifs
				local myPos = rootPart.Position
				local best, bestDist = nil, math.huge
				for _, r in ipairs(cachedEggs) do
					if r.enabled then
						-- Filtre zone/île
						local zoneOk = St.farmZone == "" or r.area == St.farmZone
						-- Filtre rareté
						local rarityOk = St.farmRarity == ""
						if not rarityOk then
							local low3 = St.farmRarity:lower()
							if r.mutation and r.mutation:lower():find(low3, 1, true) then rarityOk = true end
							if r.tags then
								for _, t in ipairs(r.tags) do
									if t:lower():find(low3, 1, true) then rarityOk = true end
								end
							end
						end
						if zoneOk and rarityOk then
							local d = (r.pos - myPos).Magnitude
							if d < bestDist then bestDist = d; best = r end
						end
					end
				end
				if not best then
					local zTxt = St.farmZone ~= "" and (" île:"..St.farmZone) or ""
					local rTxt = St.farmRarity ~= "" and (" rareté:"..St.farmRarity) or ""
					setStatus(string.format("Farm: %d vu, 0 cible%s%s", #cachedEggs, zTxt, rTxt), C.DIM)
				end

				if best then
					isFarmingEgg = true
					_farmMoving = true
					_farmTargetPos = best.pos
					_farmSpeed = math.max(St.speed, 40)

					-- Retire tout de suite la cible du cache réseau : évite de
					-- re-sélectionner le même œuf en boucle si le monde met du
					-- temps à confirmer la prise (corrige le blocage signalé).
					if best.uid then _fieldEggNet[best.uid] = nil end

					local spamming = true
					task.spawn(function()
						while spamming do
							pcall(function()
								if best.prompt and fireproximityprompt then
									fireproximityprompt(best.prompt)
								elseif best.uid then
									_invokeRF("RF/EggWorld/AskFieldEggCarry", best.uid)
								end
							end)
							task.wait(0.05)
						end
					end)

					local t0 = os.clock()
					while St.autoFarm and _farmMoving and (os.clock()-t0) < 6 do
						local hrp2 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
						if not hrp2 then break end
						if (hrp2.Position - best.pos).Magnitude < 4 then break end
						task.wait(0.1)
					end
					task.wait(0.3)
					spamming = false
					_farmMoving = false

					if St.autoFarm then
						setStatus("Farm: pris → "..tostring(best.cat or "?"), C.GREEN)

						-- Livraison auto au marchand le plus proche (découverte
						-- dynamique, jamais de nom figé) — si aucun marchand
						-- n'est trouvé, on relâche simplement la cible et on
						-- repart farmer au lieu de rester bloqué.
						local hrp3 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
						local merchant = hrp3 and _nearestMerchant(hrp3.Position)
						if merchant then
							_farmMoving = true
							_farmTargetPos = merchant.pos
							setStatus("Farm: retour marchand...", C.ACCENT2)

							local sellSpamming = true
							task.spawn(function()
								while sellSpamming do
									pcall(function()
										if merchant.prompt and fireproximityprompt then
											fireproximityprompt(merchant.prompt)
										end
									end)
									task.wait(0.1)
								end
							end)

							local t1 = os.clock()
							while St.autoFarm and _farmMoving and (os.clock()-t1) < 6 do
								local hrp4 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
								if not hrp4 then break end
								if (hrp4.Position - merchant.pos).Magnitude < 5 then break end
								task.wait(0.1)
							end
							-- Une fois arrivé, continue de spammer le prompt de
							-- vente un court instant (le temps que le serveur
							-- traite la vente) avant de repartir farmer.
							local t2 = os.clock()
							while St.autoFarm and (os.clock()-t2) < 1.2 do task.wait(0.1) end
							sellSpamming = false
							if St.autoFarm then setStatus("Farm: tentative de vente au marchand", C.GREEN) end
						end
					end

					_farmFullStop()
				end
			end
		end
		end
	end
end)
makeRow(farmPage, "autoFarm", "Auto Farm Eggs", function(on) end)

-- ============================================================
-- SÉLECTEUR ÎLE + RARETÉ (visible en permanence sous Auto Farm)
-- ============================================================
do
	local FARM_ZONES = {
		"","Forest","Desert","Prehistoric","Abyss Ocean","Snow",
		"Cosmic","Lake","Volcano","Cherry Blossom","Jungle","Titan Temple",
	}
	local FARM_ZONE_LABELS = {
		"Toutes","Forest","Desert","Prehist.","Abyss","Snow",
		"Cosmic","Lake","Volcano","Cherry","Jungle","Titan",
	}
	local FARM_RARITIES = {"","secret","legendary","mythic","divine","celestial"}
	local FARM_RARITY_LABELS = {"Toutes","Secret","Leg.","Mythic","Divine","Céleste"}

	-- Conteneur principal
	local selOuter = Instance.new("Frame", farmPage)
	selOuter.Size = UDim2.new(1,-12,0,118)
	selOuter.BackgroundColor3 = C.ROW
	selOuter.BackgroundTransparency = 0.25
	selOuter.BorderSizePixel = 0
	corner(selOuter, 10)
	addLivingStroke(selOuter, 1)
	local selPad = Instance.new("UIPadding", selOuter)
	selPad.PaddingLeft = UDim.new(0,8); selPad.PaddingRight = UDim.new(0,8)
	selPad.PaddingTop = UDim.new(0,6); selPad.PaddingBottom = UDim.new(0,6)

	-- Titre île
	local _zoneTitleLbl = label(selOuter, "ÎLE CIBLE", UDim2.new(1,0,0,13), C.DIM, Enum.Font.GothamBold)
	_zoneTitleLbl.TextSize = 9; _zoneTitleLbl.Position = UDim2.new(0,0,0,0)

	-- Grille de zones (3 colonnes)
	local zoneGrid = Instance.new("Frame", selOuter)
	zoneGrid.Size = UDim2.new(1,0,0,56)
	zoneGrid.Position = UDim2.new(0,0,0,14)
	zoneGrid.BackgroundTransparency = 1
	local zGrid = Instance.new("UIGridLayout", zoneGrid)
	zGrid.CellSize = UDim2.new(0,82,0,17)
	zGrid.CellPadding = UDim2.new(0,3,0,3)
	zGrid.FillDirectionMaxCells = 3
	zGrid.SortOrder = Enum.SortOrder.LayoutOrder

	local _zoneBtns = {}
	local function _refreshZoneBtns()
		for _, info in ipairs(_zoneBtns) do
			local on = (info.zone == St.farmZone)
			info.btn.BackgroundColor3 = on and C.MOON or Color3.fromRGB(12,18,32)
			info.btn.TextColor3 = on and C.MOONTEXT or C.SILVER2
		end
	end
	for i, zv in ipairs(FARM_ZONES) do
		local zl = FARM_ZONE_LABELS[i]
		local zBtn = Instance.new("TextButton", zoneGrid)
		zBtn.LayoutOrder = i
		zBtn.Size = UDim2.new(0,1,0,1)
		zBtn.BackgroundColor3 = (St.farmZone == zv) and C.MOON or Color3.fromRGB(12,18,32)
		zBtn.TextColor3 = (St.farmZone == zv) and C.MOONTEXT or C.SILVER2
		zBtn.Text = zl; zBtn.TextSize = 8; zBtn.Font = Enum.Font.GothamMedium
		zBtn.BorderSizePixel = 0; corner(zBtn, 4)
		table.insert(_zoneBtns, {btn=zBtn, zone=zv})
		zBtn.MouseButton1Click:Connect(function()
			St.farmZone = zv; _refreshZoneBtns()
			setStatus("Farm île: "..(zv == "" and "Toutes" or zv), C.ACCENT2)
			saveConfig()
		end)
	end

	-- Titre rareté
	local _rareTitleLbl = label(selOuter, "RARETÉ", UDim2.new(1,0,0,13), C.DIM, Enum.Font.GothamBold)
	_rareTitleLbl.TextSize = 9; _rareTitleLbl.Position = UDim2.new(0,0,0,74)

	-- Boutons rareté (ligne horizontale)
	local rareRow = Instance.new("Frame", selOuter)
	rareRow.Size = UDim2.new(1,0,0,20)
	rareRow.Position = UDim2.new(0,0,0,88)
	rareRow.BackgroundTransparency = 1
	local rList = Instance.new("UIListLayout", rareRow)
	rList.FillDirection = Enum.FillDirection.Horizontal
	rList.Padding = UDim.new(0,3)
	rList.VerticalAlignment = Enum.VerticalAlignment.Center

	local _rareBtns = {}
	local function _refreshRareBtns()
		for _, info in ipairs(_rareBtns) do
			local on = (info.rarity == St.farmRarity)
			info.btn.BackgroundColor3 = on and C.MOON or Color3.fromRGB(12,18,32)
			info.btn.TextColor3 = on and C.MOONTEXT or C.SILVER2
		end
	end
	for i, rv in ipairs(FARM_RARITIES) do
		local rl = FARM_RARITY_LABELS[i]
		local rBtn = Instance.new("TextButton", rareRow)
		rBtn.Size = UDim2.new(0,42,1,0)
		rBtn.BackgroundColor3 = (St.farmRarity == rv) and C.MOON or Color3.fromRGB(12,18,32)
		rBtn.TextColor3 = (St.farmRarity == rv) and C.MOONTEXT or C.SILVER2
		rBtn.Text = rl; rBtn.TextSize = 8; rBtn.Font = Enum.Font.GothamMedium
		rBtn.BorderSizePixel = 0; corner(rBtn, 4)
		table.insert(_rareBtns, {btn=rBtn, rarity=rv})
		rBtn.MouseButton1Click:Connect(function()
			St.farmRarity = rv; _refreshRareBtns()
			setStatus("Farm rareté: "..(rv == "" and "Toutes" or rl), C.ACCENT2)
			saveConfig()
		end)
	end

	makeDivider(farmPage)
end

-- Auto Hatch / Auto Equip — clic direct des vrais boutons UI du jeu
-- ("Grow All", "Equip Best", confirmés par capture d'écran) via
-- firesignal — indépendant de tout module cassé.
local _guiClickWarned = false
local function _clickGuiButtonByText(matchFn)
	local pg = LP:FindFirstChild("PlayerGui")
	if not pg then return false end
	local found = nil
	for _, d in ipairs(pg:GetDescendants()) do
		if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Visible then
			local txt = d:IsA("TextButton") and d.Text or nil
			if not txt then
				local tl = d:FindFirstChildWhichIsA("TextLabel", true)
				txt = tl and tl.Text or ""
			end
			if matchFn(txt or "") then found = d; break end
		end
	end
	if not found then return false end
	if typeof(firesignal) == "function" then
		local ok = pcall(function() firesignal(found.MouseButton1Click) end)
		if ok then return true end
	end
	if not _guiClickWarned then
		_guiClickWarned = true
		setStatus("Clic UI indispo (firesignal manquant)", C.RED)
	end
	return false
end

task.spawn(function()
	local lastHatch = 0
	while true do
		task.wait(1)
		if St.autoHatch and (os.clock()-lastHatch) >= 3 then
			lastHatch = os.clock()
			if _clickGuiButtonByText(function(t) return t:lower():find("grow all", 1, true) ~= nil end) then
				setStatus("Hatch: 'Grow All' clique", C.GREEN)
			end
		end
	end
end)
makeRow(farmPage, "autoHatch", "Auto Hatch", function(on) end)

task.spawn(function()
	local lastEquip = 0
	while true do
		task.wait(2)
		if St.autoEquip and (os.clock()-lastEquip) >= 4 then
			lastEquip = os.clock()
			if _clickGuiButtonByText(function(t) return t:lower():find("equip best", 1, true) ~= nil end) then
				setStatus("'Equip Best' clique", C.GREEN)
			end
		end
	end
end)
makeRow(farmPage, "autoEquip", "Auto Equip Best", function(on) end)

-- Auto Claim — remotes confirmés, aucun coût (récupère des gains déjà acquis)
task.spawn(function()
	local lastClaim = 0
	while true do
		task.wait(1)
		if St.autoClaim and (os.clock()-lastClaim) >= 5 then
			lastClaim = os.clock()
			local a = _invokeRF("RF/AwayEarnings/AskCollect")
			local b = _invokeRF("RF/Codex/AskRedeemAll")
			local c = _invokeRF("RF/GroupPerk/RedeemPerk")
			if a or b or c then setStatus("Claim: away/codex/group tentes", C.GREEN) end
		end
	end
end)
makeRow(farmPage, "autoClaim", "Auto Claim", function(on) end)

sectionHeader(farmPage, "Améliorations")

-- Auto Upgrade Pen/Treadmill — vraie condition d'argent (Save.Get
-- confirmé correct) + vrais remotes confirmés (AskBaseTierRaise,
-- pas AskWearLimit deviné à tort au tour précédent).
task.spawn(function()
	local lastPen = 0
	while true do
		task.wait(1.5)
		if St.autoUpgradePen and (os.clock()-lastPen) >= 2 then
			lastPen = os.clock()
			local ok, data = pcall(function() return Save and Save.Get and Save.Get() end)
			if ok and data then
				local nextLevel = (data.BaseUpgradeLevel or 0) + 1
				local nextConfig = Bases and Bases.BASES and Bases.BASES[nextLevel]
				if nextConfig and data.Money and data.Money >= (nextConfig.Cost or math.huge) then
					if _invokeRF("AskBaseTierRaise") then setStatus("Pen: tier "..nextLevel.." tente", C.GREEN) end
				end
			end
		end
	end
end)
makeRow(farmPage, "autoUpgradePen", "Auto Upgrade Pen", function(on) end)

task.spawn(function()
	local lastTM = 0
	while true do
		task.wait(1.5)
		if St.autoUpgradeTM and (os.clock()-lastTM) >= 2 then
			lastTM = os.clock()
			local ok, data = pcall(function() return Save and Save.Get and Save.Get() end)
			if ok and data then
				local nextLevel = (data.TreadmillUpgradeLevel or 0) + 1
				local nextConfig = Treadmills and Treadmills.GetByUpgradeLevel and Treadmills.GetByUpgradeLevel(nextLevel)
				if nextConfig and data.Money and data.Money >= (nextConfig.Price or math.huge) then
					if _invokeRF("AskTierRaise", nextConfig._id) then setStatus("Treadmill: tier "..nextLevel.." tente", C.GREEN) end
				end
			end
		end
	end
end)
makeRow(farmPage, "autoUpgradeTM", "Auto Upgrade Treadmill", function(on) end)

-- Auto Buy Trails — volontairement désactivé (prix mixtes $/Robux
-- vus dans le Trail Shop, risque de débiter de vrais Robux)
local buyTrailsRefresh
local _, _, _btr = makeRow(farmPage, "autoBuyTrails", "Auto Buy Trails", function(on)
	if on then
		setStatus("Buy Trails: desactive par securite (prix Robux)", C.YELLOW)
		St.autoBuyTrails = false
		if buyTrailsRefresh then buyTrailsRefresh() end
	end
end)
buyTrailsRefresh = _btr

-- Auto Run Treadmill — désactive "Slow Mode" (confirmé par capture d'écran)
task.spawn(function()
	while true do
		if St.autoRunTreadmill then _invokeRF("RF/Treadmill/AskSlowToggleSet", false) end
		task.wait(10)
	end
end)
makeRow(farmPage, "autoRunTreadmill", "Auto Run Treadmill", function(on) end)

-- ============================================================
-- ONGLET SPEED
-- ============================================================
local speedPage = pages["Speed"]

local speedRow, speedBtn, speedRefresh = makeRow(speedPage, "speedOn", "Speed Boost", function(on)
	if on then startSpeed() else stopSpeed() end
end)
makeSlider(speedPage, "speed", "Walk Speed", 4, 500, "%d")

-- Anti Ragdoll — override module + filet réactif
local _ragdollOriginal = {}
local function _applyRagdollModuleOverride(on)
	if not Ragdoll then return end
	if on then
		if _ragdollOriginal.Ragdoll == nil then
			_ragdollOriginal.Ragdoll = Ragdoll.Ragdoll
			_ragdollOriginal.IsRagdolled = Ragdoll.IsRagdolled
			_ragdollOriginal.NpcRagdoll = Ragdoll.NpcRagdoll
		end
		pcall(function()
			Ragdoll.Ragdoll = function() end
			Ragdoll.IsRagdolled = function() return false end
			Ragdoll.NpcRagdoll = function() end
		end)
	else
		if _ragdollOriginal.Ragdoll ~= nil then
			pcall(function()
				Ragdoll.Ragdoll = _ragdollOriginal.Ragdoll
				Ragdoll.IsRagdolled = _ragdollOriginal.IsRagdolled
				Ragdoll.NpcRagdoll = _ragdollOriginal.NpcRagdoll
			end)
		end
	end
end
local _ragConn = nil
local function stopAntiRag()
	if _ragConn then _ragConn:Disconnect(); _ragConn = nil end
	_applyRagdollModuleOverride(false)
end
local function startAntiRag()
	stopAntiRag()
	_applyRagdollModuleOverride(true)
	local _t = 0
	_ragConn = RunService.Heartbeat:Connect(function()
		if not St.antiRagdoll then return end
		local now = tick(); if now-_t < 0.1 then return end; _t = now
		local char = LP.Character; if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			local st = hum:GetState()
			if st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll
				or st==Enum.HumanoidStateType.FallingDown then
				hum:ChangeState(Enum.HumanoidStateType.Running)
			end
		end
		for _, obj in ipairs(char:GetDescendants()) do
			if obj:IsA("Motor6D") and not obj.Enabled then obj.Enabled = true end
		end
	end)
end
makeRow(speedPage, "antiRagdoll", "Anti Ragdoll", function(on)
	if on then startAntiRag() else stopAntiRag() end
end)

-- Fly
local _flyConn, _flyBP = nil, nil
local function stopFly()
	if _flyConn then _flyConn:Disconnect(); _flyConn = nil end
	pcall(function() if _flyBP then _flyBP:Destroy(); _flyBP = nil end end)
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = false end
end
local function startFly()
	stopFly()
	local char = LP.Character; if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
	local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
	hum.PlatformStand = true
	_flyBP = Instance.new("BodyPosition")
	_flyBP.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	_flyBP.P = 1e4; _flyBP.D = 500
	_flyBP.Position = hrp.Position
	_flyBP.Parent = hrp
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = Vector3.zero; bv.Parent = hrp
	_flyConn = RunService.RenderStepped:Connect(function()
		if not St.fly then return end
		local cam = workspace.CurrentCamera
		local mv = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up) then mv = mv + cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down) then mv = mv - cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then mv = mv - cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then mv = mv + cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0,1,0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then mv = mv - Vector3.new(0,1,0) end
		bv.Velocity = mv.Magnitude > 0 and mv.Unit * St.flySpeed or Vector3.zero
		_flyBP.Position = hrp.Position
	end)
end
makeRow(speedPage, "fly", "Fly (WASD + Space)", function(on)
	if on then startFly() else stopFly() end
end)
makeSlider(speedPage, "flySpeed", "Fly Speed", 5, 300, "%d")

-- Anti Trap
local _trapConn, _lastPos, _stuckSince = nil, Vector3.zero, 0
local function stopAntiTrap() if _trapConn then _trapConn:Disconnect(); _trapConn = nil end end
local function startAntiTrap()
	stopAntiTrap()
	local _t = 0
	_trapConn = RunService.Heartbeat:Connect(function()
		if not St.antiTrap then return end
		local now = tick(); if now-_t < 0.5 then return end; _t = now
		local char = LP.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then _lastPos = Vector3.zero; _stuckSince = now; return end
		local moved = (hrp.Position - _lastPos).Magnitude
		if moved < 0.5 then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local isMoving = hum and hum.MoveDirection.Magnitude > 0.1
			if isMoving then
				if _stuckSince > 0 and now-_stuckSince > 1.5 then
					hrp.CFrame = hrp.CFrame * CFrame.new(0,3,0)
					_stuckSince = 0
					setStatus("Anti-Trap: unstuck!", C.GREEN)
				end
			else _stuckSince = 0 end
		else _stuckSince = 0 end
		_lastPos = hrp.Position
	end)
end
makeRow(speedPage, "antiTrap", "Anti Trap", function(on)
	if on then startAntiTrap() else stopAntiTrap() end
end)

-- ============================================================
-- ONGLET VISUAL
-- ============================================================
local visualPage = pages["Visual"]

local function _shortNum(n)
	if not n then return "?" end
	local a = math.abs(n)
	if a >= 1e12 then return string.format("%.1fT", n/1e12) end
	if a >= 1e9  then return string.format("%.1fB", n/1e9)  end
	if a >= 1e6  then return string.format("%.1fM", n/1e6)  end
	if a >= 1e3  then return string.format("%.1fK", n/1e3)  end
	return string.format("%d", n)
end

local _espParts = {}
local _espConn = nil
local _espStatsLbl = nil
local function clearESP()
	for _, p in ipairs(_espParts) do pcall(function() p:Destroy() end) end
	_espParts = {}
end
local function stopESP()
	if _espConn then _espConn:Disconnect(); _espConn = nil end
	clearESP()
	if _espStatsLbl then _espStatsLbl.Text = "ESP inactif" end
end
local function startESP()
	stopESP()
	local _t = 0
	_espConn = RunService.Heartbeat:Connect(function()
		if not St.esp then return end
		local now = tick(); if now-_t < 1 then return end; _t = now
		clearESP()

		local myPos = nil
		do
			local mc = LP.Character
			local mr = mc and mc:FindFirstChild("HumanoidRootPart")
			myPos = mr and mr.Position
		end

		local total, readyCount, rareCount, lockedCount = #cachedEggs, 0, 0, 0
		for _, r in ipairs(cachedEggs) do
			pcall(function()
				local unlocked = areaUnlocked(r.area)
				local hasRareTag = r.tags and #r.tags > 0
				local notReady = r.enabled == false
				local col = notReady and C.DIM or (not unlocked) and C.RED or (hasRareTag and C.GOLD or C.GREEN)
				if r.enabled then readyCount = readyCount + 1 end
				if hasRareTag then rareCount = rareCount + 1 end
				if not unlocked then lockedCount = lockedCount + 1 end

				local part = r.part
				local p = Instance.new("Part")
				p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.Transparency = 1
				p.Size = (part and part:IsA("BasePart") and part.Size.Magnitude > 0.5) and part.Size or Vector3.new(3.5,3.5,3.5)
				p.CFrame = r.cf
				p.Parent = workspace

				local box = Instance.new("SelectionBox")
				box.Adornee = p; box.Color3 = col
				box.LineThickness = hasRareTag and 0.1 or 0.05
				box.SurfaceTransparency = 0.7; box.SurfaceColor3 = col
				box.Parent = p

				-- 3 lignes désormais : nom, statut/rareté/poids, distance+zone
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(230,48); bb.AlwaysOnTop = true; bb.MaxDistance = 800
				bb.Parent = p

				local nameLbl = Instance.new("TextLabel", bb)
				nameLbl.Size = UDim2.new(1,0,0,17)
				nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamBold
				nameLbl.TextSize = 12; nameLbl.TextStrokeTransparency = 0.3
				nameLbl.TextColor3 = col; nameLbl.Text = tostring(r.cat or "Oeuf")

				local detailLbl = Instance.new("TextLabel", bb)
				detailLbl.Size = UDim2.new(1,0,0,15); detailLbl.Position = UDim2.new(0,0,0,17)
				detailLbl.BackgroundTransparency = 1; detailLbl.Font = Enum.Font.Gotham
				detailLbl.TextSize = 10; detailLbl.TextStrokeTransparency = 0.4
				detailLbl.TextColor3 = C.WHITE

				local metaLbl = Instance.new("TextLabel", bb)
				metaLbl.Size = UDim2.new(1,0,0,14); metaLbl.Position = UDim2.new(0,0,0,32)
				metaLbl.BackgroundTransparency = 1; metaLbl.Font = Enum.Font.Gotham
				metaLbl.TextSize = 9; metaLbl.TextStrokeTransparency = 0.5
				metaLbl.TextColor3 = C.DIM

				-- Ligne 2 : statut seul (plus de doublon avec le nom, qui
				-- porte déjà la rareté via r.cat).
				if notReady then
					detailLbl.Text = "CROISSANCE"
				elseif not unlocked then
					local A = AREA[r.area]
					detailLbl.Text = "VERROUILLE ".._shortNum(A and A.reqSP)
				else
					detailLbl.Text = "PRET"
				end

				-- Ligne 3 : poids (uniquement si une vraie valeur en kg a été
				-- lue en jeu — jamais une estimation) + distance + zone.
				local metaParts = {}
				if r.weight then table.insert(metaParts, r.weight.."kg") end
				local distTxt = "?m"
				if myPos then distTxt = math.floor((r.pos - myPos).Magnitude).."m" end
				table.insert(metaParts, distTxt)
				table.insert(metaParts, tostring(r.area or "?"))
				metaLbl.Text = table.concat(metaParts, "  ·  ")

				table.insert(_espParts, p)
			end)
		end

		if _espStatsLbl then
			_espStatsLbl.Text = string.format(
				"Total %d  ·  Prets %d  ·  Rares %d  ·  Verrouilles %d",
				total, readyCount, rareCount, lockedCount)
		end
	end)
end
makeRow(visualPage, "esp", "Egg ESP", function(on) if on then startESP() else stopESP() end end)

-- Petit récap live sous le toggle ESP — totaux mis à jour à chaque
-- rafraîchissement (même cadence que les billboards, 1x/s).
do
	local row = Instance.new("Frame", visualPage)
	row.Size = UDim2.new(1,-12,0,24)
	row.BackgroundColor3 = C.ROW; row.BackgroundTransparency = 0.5
	row.BorderSizePixel = 0; corner(row, 10); addLivingStroke(row, 1)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,10); pad.PaddingRight = UDim.new(0,10)
	_espStatsLbl = label(row, "ESP inactif", UDim2.new(1,0,1,0), C.DIM, Enum.Font.Gotham)
	_espStatsLbl.TextSize = 10.5
	makeDivider(visualPage)
end

local _origBright = nil
local function startFullbright()
	_origBright = Lighting.Brightness
	Lighting.Brightness = 2; Lighting.GlobalShadows = false
	Lighting.Ambient = Color3.fromRGB(200,200,200); Lighting.OutdoorAmbient = Color3.fromRGB(200,200,200)
end
local function stopFullbright()
	Lighting.Brightness = _origBright or 1; Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(70,70,70); Lighting.OutdoorAmbient = Color3.fromRGB(100,100,100)
end
makeRow(visualPage, "fullbright", "Fullbright", function(on) if on then startFullbright() else stopFullbright() end end)

local function applyFpsBoost()
	pcall(function() setfpscap(9999) end)
	local function proc(v)
		pcall(function()
			if v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("ParticleEmitter")
				or v:IsA("Trail") or v:IsA("Beam") then v.Enabled = false
			elseif v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect")
				or v:IsA("DepthOfFieldEffect") then v:Destroy()
			elseif v:IsA("BasePart") then v.CastShadow = false end
		end)
	end
	for _, v in ipairs(workspace:GetDescendants()) do proc(v) end
	for _, v in ipairs(Lighting:GetDescendants()) do proc(v) end
	workspace.DescendantAdded:Connect(function(v) if St.fpsBoost then task.spawn(proc, v) end end)
end
makeRow(visualPage, "fpsBoost", "FPS Boost", function(on) if on then applyFpsBoost() end end)

do
	makeSlider(visualPage, "fov", "FOV", 30, 130, "%d°")
	-- makeSlider est générique (ne connaît pas la caméra) — applique le
	-- FOV séparément, une fois immédiatement puis via une petite boucle
	-- qui observe St.fov (couvre le drag ET la restauration au chargement).
	pcall(function() workspace.CurrentCamera.FieldOfView = St.fov end)
	task.spawn(function()
		local last = St.fov
		while true do
			if St.fov ~= last then
				last = St.fov
				pcall(function() workspace.CurrentCamera.FieldOfView = St.fov end)
			end
			task.wait(0.1)
		end
	end)
end

local _afkConn = nil
local function stopAntiAFK() if _afkConn then _afkConn:Disconnect(); _afkConn = nil end end
local function startAntiAFK()
	stopAntiAFK()
	local i = 0
	_afkConn = RunService.Heartbeat:Connect(function()
		if not St.antiAFK then return end
		i = i + 1
		if i % (30*60*15) == 0 then
			local char = LP.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local cf = hrp.CFrame
				hrp.CFrame = cf * CFrame.new(0.01,0,0)
				task.wait(0.05)
				hrp.CFrame = cf
			end
			pcall(function()
				local VU = game:GetService("VirtualUser")
				VU:CaptureController(); VU:ClickButton2(Vector2.new())
			end)
		end
	end)
end
makeRow(visualPage, "antiAFK", "Anti AFK", function(on) if on then startAntiAFK() else stopAntiAFK() end end)

-- ============================================================
-- ONGLET MISC
-- ============================================================
local miscPage = pages["Misc"]

-- Bypass Anti-Cheat — vrai toggle ON/OFF
local _bypassActive, _bypassCooldown, _bypassOn = false, 0, false
local _bypassPillRefresh, _bypassFloatRefresh = nil, nil
local BYPASS_COOLDOWN_S = 5

local function applyBypass()
	if _bypassActive then return false end
	local now = tick()
	if now - _bypassCooldown < BYPASS_COOLDOWN_S then
		setStatus("Bypass: attendre "..math.ceil(BYPASS_COOLDOWN_S-(now-_bypassCooldown)).."s", C.DIM)
		return false
	end
	local char = LP.Character
	local oldHum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not oldHum then setStatus("Bypass: pas de character", C.RED); return false end
	_bypassActive = true
	local ok = pcall(function()
		local cam = workspace.CurrentCamera
		local wasSubject = cam and cam.CameraSubject == oldHum
		local clone = oldHum:Clone()
		clone.Parent = char
		oldHum:Destroy()
		if cam and wasSubject then cam.CameraSubject = clone end
		pcall(function()
			local pm = LP:FindFirstChild("PlayerScripts")
			local cm = pm and pm:FindFirstChild("PlayerModule")
			if cm then require(cm:FindFirstChild("ControlModule")):Enable() end
		end)
	end)
	_bypassActive = false
	_bypassCooldown = tick()
	setStatus(ok and "Bypass applique" or "Bypass echec — voir console", ok and C.GREEN or C.RED)
	task.delay(3, function() if not _bypassActive then setStatus("Idle", C.DIM) end end)
	return ok
end

-- Retrait du Bypass : il n'y a rien à "annuler" à proprement parler — le
-- clone posé par applyBypass() est un Humanoid parfaitement normal une
-- fois en place (mêmes stats, même comportement). Le forcer à mourir
-- (hum.Health = 0) pour "revenir en arrière" ne faisait que provoquer un
-- respawn brutal et non désiré (signalé : "sa me reset sa marche pas").
-- OFF = simple drapeau d'état, honnête : le swap déjà fait reste en place
-- jusqu'au prochain respawn naturel (mort, téléport, Rejoin...), rien
-- n'est détruit ni recréé ici.
local function removeBypass()
	setStatus("Bypass desactive (deja applique jusqu'au prochain respawn)", C.DIM)
	task.delay(3, function() if not _bypassActive then setStatus("Idle", C.DIM) end end)
	return true
end

do
	local row = Instance.new("Frame", miscPage)
	row.Size = UDim2.new(1,-12,0,32)
	row.BackgroundColor3 = C.ROW; row.BorderSizePixel = 0; corner(row, 8)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,10); pad.PaddingRight = UDim.new(0,10)
	label(row, "Bypass Anti-Cheat", UDim2.new(1,-46,1,0), C.WHITE, Enum.Font.GothamMedium).TextSize = 12
	local track, btn, setSwitch = makeSwitch(row, false)
	track.Position = UDim2.new(1,-38,0.5,-10)
	local function refresh() setSwitch(_bypassOn) end
	refresh()
	_bypassPillRefresh = refresh
	btn.MouseButton1Click:Connect(function()
		if not _bypassOn then
			if applyBypass() then _bypassOn = true; refresh() end
		else
			if removeBypass() then _bypassOn = false; refresh() end
		end
	end)
	LP.CharacterAdded:Connect(function()
		_bypassOn = false; refresh()
		if _bypassFloatRefresh then _bypassFloatRefresh(false) end
	end)
end

makeButton(miscPage, "TP to Spawn", "Go", function()
	pcall(function()
		local char = LP.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local spawn = workspace:FindFirstChild("SpawnLocation")
		if hrp and spawn then hrp.CFrame = spawn.CFrame + Vector3.new(0,5,0) end
	end)
end)

-- Go To Main Stand / Stop Movement
local _mainStandTween = nil
do
	local MAIN_STAND_CF = CFrame.new(544.577637, 92.0762939, -364.869049, -1,0,0, 0,1,0, 0,0,-1)
	makeButton(miscPage, "Go To Main Stand", "Go", function()
		local char = LP.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not rootPart then return end
		if _mainStandTween then _mainStandTween:Cancel() end
		local dist = (rootPart.Position - MAIN_STAND_CF.Position).Magnitude
		local travelTime = math.max(dist/350, 0.1)
		_mainStandTween = TweenService:Create(rootPart, TweenInfo.new(travelTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {CFrame = MAIN_STAND_CF})
		_mainStandTween.Completed:Connect(function()
			if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Landed); hum.PlatformStand = false end) end
		end)
		_mainStandTween:Play()
		setStatus("Retour au spawn...", C.ACCENT2)
	end)
	makeButton(miscPage, "Stop Movement", "Stop", function()
		if _mainStandTween then
			_mainStandTween:Cancel(); _mainStandTween = nil
			local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.PlatformStand = false end
			setStatus("Mouvement arrete", C.DIM)
		end
	end, true)
end

-- Infinite Jump — via makeRow (persisté correctement dans St.infJump +
-- saveConfig() + réactivé au chargement, contrairement à l'ancienne
-- version qui utilisait un local `_on` jamais sauvegardé)
local _ijConn = nil
makeRow(miscPage, "infJump", "Infinite Jump", function(on)
	if on then
		if _ijConn then _ijConn:Disconnect() end
		_ijConn = UIS.JumpRequest:Connect(function()
			local char = LP.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	else
		if _ijConn then _ijConn:Disconnect(); _ijConn = nil end
	end
end)

makeButton(miscPage, "Rejoin Server", "Rejoin", function()
	pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LP) end)
end, true)

makeButton(miscPage, "Copy Player ID", "Copy", function()
	pcall(function()
		setclipboard(tostring(LP.UserId))
		setStatus("ID copied: "..LP.UserId, C.GREEN)
		task.delay(2, function() setStatus("Idle", C.DIM) end)
	end)
end)

-- Click TP
do
	local row = Instance.new("Frame", miscPage)
	row.Size = UDim2.new(1,-12,0,32)
	row.BackgroundColor3 = C.ROW; row.BorderSizePixel = 0; corner(row, 8)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,10); pad.PaddingRight = UDim.new(0,10)
	label(row, "Click TP", UDim2.new(1,-46,1,0), C.WHITE, Enum.Font.GothamMedium).TextSize = 12
	local track, btn, setSwitch = makeSwitch(row, St.clickTp)
	track.Position = UDim2.new(1,-38,0.5,-10)
	local function refresh() setSwitch(St.clickTp) end

	local _clickTpConn = nil
	local function stopClickTp() if _clickTpConn then _clickTpConn:Disconnect(); _clickTpConn = nil end end
	local function startClickTp()
		stopClickTp()
		local mouse = LP:GetMouse()
		_clickTpConn = UIS.InputBegan:Connect(function(inp, gameProcessed)
			if gameProcessed or not St.clickTp then return end
			if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			local char = LP.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			local target = mouse.Hit
			if not target then return end
			pcall(function() hrp.CFrame = CFrame.new(target.Position + Vector3.new(0,3,0)) * hrp.CFrame.Rotation end)
			setStatus("Click TP →", C.GREEN)
		end)
	end
	_toggleRegistry["clickTp"] = function(on) if on then startClickTp() else stopClickTp() end end

	btn.MouseButton1Click:Connect(function()
		St.clickTp = not St.clickTp
		refresh()
		if St.clickTp then startClickTp() else stopClickTp(); setStatus("Click TP OFF", C.DIM) end
		saveConfig()
	end)
end

-- ============================================================
-- FLING — auto-lancement (uniquement le joueur local)
-- ============================================================
-- Note : une version qui prendrait le contrôle physique (NetworkOwner)
-- des AUTRES joueurs pour les projeter de force n'est pas implémentée
-- ici — ça revient à manipuler le personnage d'autres vraies personnes
-- sans leur consentement, ce qui sort du cadre d'un outil pour ton
-- propre compte. Ce bouton lance UNIQUEMENT ton propre personnage
-- (traversal/fun), sans effet sur les autres joueurs.
local _flingActive = false
local _flingConn = nil
local function startFling()
	if _flingConn then _flingConn:Disconnect(); _flingConn = nil end
	local myChar = LP.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then setStatus("Fling: personnage introuvable", C.RED); return end
	pcall(function()
		myRoot.AssemblyLinearVelocity = Vector3.new(myRoot.AssemblyLinearVelocity.X, 90, myRoot.AssemblyLinearVelocity.Z)
	end)
	_flingActive = true
	setStatus("Fling!", C.GREEN)
	task.delay(0.3, function() _flingActive = false end)
end
local function stopFling()
	_flingActive = false
	if _flingConn then _flingConn:Disconnect(); _flingConn = nil end
end

-- ============================================================
-- ANTI-DETECT — Portage complet Moon Hub
-- • Anti-Kick         : avale :Kick() sur LP
-- • Anti-Shutdown     : avale game:Shutdown()
-- • Spoof télémétrie  : remplace valeurs FPS<30 sur remotes keywords
-- • OnClientInvoke    : retourne FPS spoofé si le serveur demande
-- • Anti-Teleport     : logue les téléports non initiés (pas bloquant,
--                       pour diagnostiquer les éjectes de zone)
-- Tout est passif — s'installe au chargement, sans toggle ni bouton.
-- ============================================================
local _adSupported = (type(getrawmetatable) == "function")
	and (type(setreadonly) == "function")
	and (type(getnamecallmethod) == "function")

local _adActive     = false
local _adOrigNC     = nil
local _adIntercepts = 0
local _AD_KW = {"fps","perf","stat","telemetry","framerate","clientinfo",
                "diagnostic","speed","velocity","ping","report","metric"}

local function _adSpoofArgs(args)
	for i, v in ipairs(args) do
		if type(v) == "number" and v < 30 then
			args[i] = 55 + math.random()*6
		elseif type(v) == "table" then
			for k2, v2 in pairs(v) do
				if type(k2) == "string" then
					local kl = k2:lower()
					local kwMatch = false
					for _, kw in ipairs(_AD_KW) do if kl:find(kw,1,true) then kwMatch=true;break end end
					if kwMatch and type(v2)=="number" and v2<30 then v[k2]=55+math.random()*6 end
				end
				if type(v2)=="number" and v2<30 then v[k2]=55+math.random()*6 end
			end
		end
	end
	return args
end

local function _adHookOnClientInvokes()
	-- Hook OnClientInvoke sur toutes les RF de télémétrie connues
	-- (le serveur interroge le client → on renvoie un FPS spoofé)
	local sources = {_NetworkingFolder, ReplicatedStorage}
	for _, src in ipairs(sources) do
		if src then
			pcall(function()
				for _, rf in ipairs(src:GetDescendants()) do
					if rf:IsA("RemoteFunction") then
						local rname = rf.Name:lower()
						for _, k in ipairs(_AD_KW) do
							if rname:find(k, 1, true) then
								pcall(function()
									rf.OnClientInvoke = function(...)
										_adIntercepts = _adIntercepts + 1
										return 60 + math.random()*5, "normal", true
									end
								end)
								break
							end
						end
					end
				end
			end)
		end
	end
end

local function _adStart()
	if _adActive or not _adSupported then return end
	local ok, mt = pcall(getrawmetatable, game)
	if not ok then return end
	pcall(setreadonly, mt, false)
	local _origNC = mt.__namecall
	_adOrigNC = _origNC

	local _hook = function(self, ...)
		local method = getnamecallmethod()

		-- Anti-Kick : avale :Kick() dirigé vers le LocalPlayer
		if method == "Kick" and typeof(self)=="Instance" and self:IsA("Player") and self==LP then
			_adIntercepts = _adIntercepts + 1
			setStatus("Anti-Kick ×".._adIntercepts, C.GREEN)
			return
		end

		-- Anti-Shutdown : avale game:Shutdown() (anti-cheat qui kill le jeu)
		if method == "Shutdown" and typeof(self)=="Instance"
			and (self==game or (pcall(function() return self:IsA("DataModel") end) and true)) then
			_adIntercepts = _adIntercepts + 1
			setStatus("Anti-Shutdown ×".._adIntercepts, C.GREEN)
			return
		end

		-- Spoof télémétrie : remplace FPS<30 sur les remotes sensibles
		if (method=="FireServer" or method=="InvokeServer") and typeof(self)=="Instance" then
			local rname = (self.Name or ""):lower()
			for _, k in ipairs(_AD_KW) do
				if rname:find(k, 1, true) then
					_adIntercepts = _adIntercepts + 1
					local args = _adSpoofArgs({...})
					return _origNC(self, table.unpack(args))
				end
			end
		end

		-- Anti-Teleport inattendu (log only — sans bloquer les téléports légitimes)
		if (method=="Teleport" or method=="TeleportToPlaceInstance") and typeof(self)=="Instance" then
			local sclass = ""
			pcall(function() sclass = self.ClassName end)
			if sclass == "TeleportService" then
				-- On laisse passer : notre propre hopServer() utilise ce chemin
				-- setStatus("Teleport detecte ("..method..")", C.YELLOW)
			end
		end

		return _origNC(self, ...)
	end

	local wrapped = type(newcclosure)=="function" and newcclosure(_hook) or _hook
	mt.__namecall = wrapped
	pcall(setreadonly, mt, true)
	_adActive = true

	-- Hook OnClientInvoke après installation du __namecall
	task.delay(1, _adHookOnClientInvokes)
	-- Re-hook périodique (le jeu peut recréer des RF dynamiquement)
	task.spawn(function()
		while _adActive do task.wait(30); pcall(_adHookOnClientInvokes) end
	end)

	setStatus("Anti-Detect actif", C.GREEN)
end

local function _adStop()
	if not _adActive or not _adOrigNC then return end
	local ok2, mt2 = pcall(getrawmetatable, game)
	if ok2 then
		pcall(setreadonly, mt2, false)
		mt2.__namecall = _adOrigNC
		pcall(setreadonly, mt2, true)
	end
	_adActive = false; _adOrigNC = nil
	setStatus("Anti-Detect OFF", C.DIM)
end

-- Passif — pas de bouton, pas de toggle. Protection immédiate au chargement.
_adStart()

-- ============================================================
-- AIM BAT — portage Moon Hub (AB / Bat Aimbot V1), vitesse liée à St.speed
-- ============================================================
local AB_HEIGHT, AB_HIT_DIST, AB_HIT_CD = 3.7, 5, false
local BAT_NAMES = {
	"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap",
	"Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap",
	"Galaxy Slap","Glitched Slap","FieldBat","Field Bat",
}
local function _abIsBatName(name)
	if not name then return false end
	for _, n in ipairs(BAT_NAMES) do if name == n then return true end end
	local lower = name:lower()
	return lower:find("bat", 1, true) ~= nil or lower:find("slap", 1, true) ~= nil
end
local function _abGetBat()
	local char = LP.Character; if not char then return nil end
	for _, name in ipairs(BAT_NAMES) do
		local t = char:FindFirstChild(name); if t and t:IsA("Tool") then return t end
	end
	local bp = LP:FindFirstChildOfClass("Backpack")
	if bp then
		for _, name in ipairs(BAT_NAMES) do
			local t = bp:FindFirstChild(name); if t and t:IsA("Tool") then return t end
		end
	end
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") and _abIsBatName(t.Name) then return t end
	end
	if bp then
		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") and _abIsBatName(t.Name) then return t end
		end
	end
	return nil
end
local function _abTryHit()
	if AB_HIT_CD then return end
	AB_HIT_CD = true
	pcall(function()
		local bat = _abGetBat(); if not bat then return end
		local char = LP.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if bat.Parent ~= char and hum then pcall(function() hum:EquipTool(bat) end) end
		pcall(function() bat:Activate() end)
	end)
	task.delay(0.2, function() AB_HIT_CD = false end)
end
local function _abGetClosest()
	local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil, math.huge end
	local closest, minDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and plr.Character then
			local tr = plr.Character:FindFirstChild("HumanoidRootPart")
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			if tr and hum and hum.Health > 0 then
				local d = (tr.Position - root.Position).Magnitude
				if d < minDist then minDist = d; closest = plr end
			end
		end
	end
	return closest, minDist
end
local _aimBatConn = nil
local function startAimBat()
	_aimBatActive = true
	if _aimBatConn then _aimBatConn:Disconnect() end
	local hum0 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if hum0 then hum0.AutoRotate = false end
	_aimBatConn = RunService.RenderStepped:Connect(function()
		if not _aimBatActive then return end
		local char = LP.Character; if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
		local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
		local equipped = char:FindFirstChildOfClass("Tool")
		if not (equipped and _abIsBatName(equipped.Name)) then
			local bat = _abGetBat(); if bat then pcall(function() hum:EquipTool(bat) end) end
		end
		local target, dist = _abGetClosest()
		if not target or not target.Character then return end
		local tr = target.Character:FindFirstChild("HumanoidRootPart"); if not tr then return end

		local targetVel = tr.AssemblyLinearVelocity
		local myPos, targetPos = root.Position, tr.Position
		local predictPos = targetPos + targetVel*0.14 + tr.CFrame.LookVector*0.3
		local direction = predictPos - myPos
		local flatDir = Vector3.new(direction.X, 0, direction.Z).Unit
		local desiredHeight = targetPos.Y + AB_HEIGHT
		local yVel = (desiredHeight - myPos.Y)*19.5 + targetVel.Y*0.8
		if hum.FloorMaterial ~= Enum.Material.Air then yVel = math.max(yVel, 13) end
		yVel = math.clamp(yVel, -70, 110)
		local pursuitSpeed = St.speed
		local desiredVel = Vector3.new(flatDir.X*pursuitSpeed, yVel, flatDir.Z*pursuitSpeed)
		root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)

		local speed3 = targetVel.Magnitude
		local predictTime = math.clamp(speed3/150, 0.05, 0.2)
		local predictedPos = targetPos + targetVel*predictTime
		local toPredict = predictedPos - myPos
		if toPredict.Magnitude > 0.1 then
			local goalCF = CFrame.lookAt(myPos, predictedPos)
			local diffCF = root.CFrame:Inverse() * goalCF
			local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
			rx = math.clamp(rx,-2.5,2.5); ry = math.clamp(ry,-2.5,2.5); rz = math.clamp(rz,-2.5,2.5)
			root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(Vector3.new(rx*42, ry*42, rz*42))
		end
		if dist <= AB_HIT_DIST then _abTryHit() end
	end)
end
local function stopAimBat()
	_aimBatActive = false
	if _aimBatConn then _aimBatConn:Disconnect(); _aimBatConn = nil end
	AB_HIT_CD = false
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root then root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end
	if hum then hum.AutoRotate = true end
end

-- ============================================================
-- HOPPER — changer de serveur (Server Hop)
-- ============================================================
-- Passe par l'API publique Roblox (liste des serveurs du même PlaceId)
-- via une fonction HTTP fournie par l'executor (request/http_request/
-- syn.request) pour choisir un serveur DIFFÉRENT du JobId actuel, puis
-- TeleportToPlaceInstance dessus. Si aucune fonction HTTP n'est
-- disponible, repli sur un simple Teleport (rejoin — pas de garantie
-- de changer de serveur, mais ne plante jamais).
local function _getHttpFn()
	if type(request) == "function" then return request end
	if type(http_request) == "function" then return http_request end
	if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
	if type(fluxus) == "table" and type(fluxus.request) == "function" then return fluxus.request end
	return nil
end
local function hopServer()
	local placeId = game.PlaceId
	local httpFn = _getHttpFn()
	if not httpFn then
		setStatus("Hopper: rejoin simple (HTTP indispo)", C.YELLOW)
		pcall(function() game:GetService("TeleportService"):Teleport(placeId, LP) end)
		return
	end
	setStatus("Hopper: recherche...", C.ACCENT2)
	task.spawn(function()
		local candidates = {}
		pcall(function()
			local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", placeId)
			local res = httpFn({Url = url, Method = "GET"})
			local body = res and (res.Body or res.body)
			if not body then return end
			local data = HttpService:JSONDecode(body)
			if data and data.data then
				for _, srv in ipairs(data.data) do
					if srv.id ~= game.JobId and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers then
						table.insert(candidates, srv.id)
					end
				end
			end
		end)
		if #candidates > 0 then
			local pick = candidates[math.random(1, #candidates)]
			setStatus("Hopper → nouveau serveur", C.GREEN)
			pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(placeId, pick, LP) end)
		else
			setStatus("Hopper: aucun serveur libre, rejoin", C.YELLOW)
			pcall(function() game:GetService("TeleportService"):Teleport(placeId, LP) end)
		end
	end)
end

-- ============================================================
-- DOCK FLOTTANT — Speed / AimBat / Bypass / Fling / Hopper / Lock
-- ============================================================
local FLOAT_SZ, FLOAT_GAP, FLOAT_TOP, FLOAT_RIGHT_OFF = 44, 7, 74, 12
local _floatDefs = {
	{ id="speed",  label="Speed" }, { id="aimbat", label="Aim\nBat" },
	{ id="bypass", label="Bypass" }, { id="fling",  label="Fling" },
	{ id="hopper", label="Hop" },    { id="lock",   label="Lock" },
}
local _floatBtns = {}

local function makeFloatBtn(defIdx, def)
	local col = (defIdx-1) % 2
	local row = math.floor((defIdx-1)/2)
	local xOff = -(FLOAT_SZ*2 + FLOAT_GAP + FLOAT_RIGHT_OFF) + col*(FLOAT_SZ+FLOAT_GAP)
	local yOff = FLOAT_TOP + row*(FLOAT_SZ+FLOAT_GAP)

	local btn = Instance.new("TextButton", gui)
	btn.Name = "YE_Float_"..def.id
	btn.Size = UDim2.new(0,FLOAT_SZ,0,FLOAT_SZ)
	btn.Position = UDim2.new(1,xOff,0,yOff)
	btn.BackgroundColor3 = C.ROW; btn.BorderSizePixel = 0
	btn.Text = ""; btn.AutoButtonColor = false
	btn.ZIndex = 500; btn.Active = true
	corner(btn, 13)
	local st2 = stroke(btn, C.BORDER, 1.5)
	local stGrad = Instance.new("UIGradient", st2)
	stGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,C.DEEP1), ColorSequenceKeypoint.new(0.5,C.DEEP2), ColorSequenceKeypoint.new(1,C.DEEP1),
	})
	table.insert(_liveGrads, stGrad)

	local lbl2 = Instance.new("TextLabel", btn)
	lbl2.Size = UDim2.new(1,0,1,0); lbl2.BackgroundTransparency = 1
	lbl2.Text = def.label; lbl2.TextColor3 = C.WHITE; lbl2.Font = Enum.Font.GothamBold
	lbl2.TextSize = 9; lbl2.TextWrapped = true; lbl2.ZIndex = btn.ZIndex+1
	local lPad = Instance.new("UIPadding", lbl2)
	lPad.PaddingLeft = UDim.new(0,4); lPad.PaddingRight = UDim.new(0,4)

	local dot = Instance.new("Frame", btn)
	dot.Size = UDim2.new(0,8,0,8); dot.Position = UDim2.new(1,-12,0,4)
	dot.BackgroundColor3 = C.GREEN; dot.BorderSizePixel = 0; dot.Visible = false
	dot.ZIndex = lbl2.ZIndex+1
	corner(dot, 4)

	local _active = false
	local function setActive(on)
		_active = on
		TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = on and Color3.fromRGB(18,30,50) or C.ROW}):Play()
		dot.Visible = on
	end

	local drag2, dStart, dPos2 = false, nil, nil
	btn.InputBegan:Connect(function(inp)
		if St.floatLocked then return end
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			drag2 = true; dStart = inp.Position; dPos2 = btn.Position
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if not drag2 then return end
		if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
			local delta = inp.Position - dStart
			btn.Position = UDim2.new(dPos2.X.Scale, dPos2.X.Offset+delta.X, dPos2.Y.Scale, dPos2.Y.Offset+delta.Y)
		end
	end)
	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			drag2 = false
		end
	end)

	_floatBtns[def.id] = { btn = btn, setActive = setActive }
	return btn, setActive
end

for i, def in ipairs(_floatDefs) do
	local _, setAct = makeFloatBtn(i, def)
	if def.id == "speed" then
		setAct(St.speedOn)
		_floatBtns["speed"].btn.MouseButton1Click:Connect(function()
			St.speedOn = not St.speedOn
			if St.speedOn then startSpeed() else stopSpeed() end
			setAct(St.speedOn)
			speedRefresh()
			saveConfig()
		end)
	elseif def.id == "aimbat" then
		_floatBtns["aimbat"].btn.MouseButton1Click:Connect(function()
			_aimBatActive = not _aimBatActive
			setAct(_aimBatActive)
			if _aimBatActive then startAimBat() else stopAimBat() end
		end)
	elseif def.id == "bypass" then
		_bypassFloatRefresh = setAct
		_floatBtns["bypass"].btn.MouseButton1Click:Connect(function()
			if not _bypassOn then
				if applyBypass() then _bypassOn = true; if _bypassPillRefresh then _bypassPillRefresh() end end
			else
				if removeBypass() then _bypassOn = false; if _bypassPillRefresh then _bypassPillRefresh() end end
			end
			setAct(_bypassOn)
		end)
	elseif def.id == "fling" then
		-- Action ponctuelle (auto-lancement) : flash le point vert, comme Hopper.
		_floatBtns["fling"].btn.MouseButton1Click:Connect(function()
			setAct(true)
			startFling()
			task.delay(0.4, function() setAct(false) end)
		end)
	elseif def.id == "hopper" then
		-- Action ponctuelle (pas un on/off persistant) : flash le point
		-- vert le temps de la recherche/téléportation.
		_floatBtns["hopper"].btn.MouseButton1Click:Connect(function()
			setAct(true)
			hopServer()
			task.delay(1.2, function() setAct(false) end)
		end)
	elseif def.id == "lock" then
		setAct(St.floatLocked)
		_floatBtns["lock"].btn.MouseButton1Click:Connect(function()
			St.floatLocked = not St.floatLocked
			setAct(St.floatLocked)
			setStatus(St.floatLocked and "Boutons verrouilles" or "Boutons deverrouilles", C.ACCENT2)
			saveConfig()
		end)
	end
end

-- ============================================================
-- DRAG / MINIMIZE / CLOSE / KEYBIND
-- ============================================================
do
	local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
	header.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dragStart = inp.Position; startPos = main.Position
			inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	header.InputChanged:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
			dragInput = inp
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if inp == dragInput and dragging then
			local delta = inp.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)
		end
	end)
end

local minimized, fullHeight = false, 340
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		TweenService:Create(main, TweenInfo.new(0.2), {Size=UDim2.new(0,300,0,48)}):Play()
		contentArea.Visible = false; sep.Visible = false; tabBar.Visible = false; statusBar.Visible = false
		minBtn.Text = "+"
	else
		TweenService:Create(main, TweenInfo.new(0.2), {Size=UDim2.new(0,300,0,fullHeight)}):Play()
		contentArea.Visible = true; sep.Visible = true; tabBar.Visible = true; statusBar.Visible = true
		minBtn.Text = "–"
	end
end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.RightShift then
		St.guiVisible = not St.guiVisible
		main.Visible = St.guiVisible
	end
end)

switchTab("Farm")

-- ============================================================
-- ACTIVATION DES TOGGLES RESTAURÉS
-- ============================================================
-- Volontairement exclus : Bypass Anti-Cheat et AimBat (jamais
-- ré-appliqués seuls au chargement).
if _savedConfig then
	for key, onToggle in pairs(_toggleRegistry) do
		if St[key] == true and onToggle then pcall(onToggle, true) end
	end
	if St.speedOn then startSpeed(); if speedRefresh then speedRefresh() end end
end

print("[yslemEgg] Loaded — refonte complete — RightShift hide/show | Dock: Speed, AimBat, Bypass, Lock")
