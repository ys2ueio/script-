-- ============================================================
-- yslemEgg — GAME ANALYSIS (standalone, lecture seule)
-- Comprend la structure complète du jeu : workspace, plots,
-- prompts, remotes, trafic réseau passif — puis génère un
-- rapport texte complet, copié automatiquement dans le presse-
-- papier. 0 clic requis, ~15-18s, aucune modification du jeu.
-- ============================================================
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ys2ueio/script-/refs/heads/main/yslemEgg_Analysis_Standalone.lua"))()

if not game:IsLoaded() then game.Loaded:Wait() end

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local Lighting     = game:GetService("Lighting")
local RS           = game:GetService("ReplicatedStorage")
local LP           = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

local LISTEN_DURATION = 15   -- fenêtre d'écoute passive du trafic réseau
local MAX_LIVE_LISTEN  = 150  -- plafond de connexions OnClientEvent simultanées

-- kill switch (relance propre)
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("YE_AnalysisGui")
	if old then old:Destroy() end
	local old2 = LP.PlayerGui:FindFirstChild("YE_AnalysisGui")
	if old2 then old2:Destroy() end
end)

-- ============================================================
-- PALETTE (Moon Hub)
-- ============================================================
local C_BG     = Color3.fromRGB(0,0,0)
local C_ROW    = Color3.fromRGB(8,8,10)
local C_BORDER = Color3.fromRGB(40,46,58)
local C_MOON   = Color3.fromRGB(90,160,255)
local C_MOON2  = Color3.fromRGB(160,200,255)
local C_WHITE  = Color3.fromRGB(255,255,255)
local C_DIM    = Color3.fromRGB(110,120,140)
local C_GREEN  = Color3.fromRGB(60,220,120)
local C_YELLOW = Color3.fromRGB(230,200,90)

-- ============================================================
-- UI
-- ============================================================
local function corner(inst, r)
	local c = Instance.new("UICorner", inst); c.CornerRadius = UDim.new(0, r or 8); return c
end
local function stroke(inst, col, th)
	local s = Instance.new("UIStroke", inst); s.Color = col or C_BORDER; s.Thickness = th or 1; return s
end

local gui = Instance.new("ScreenGui")
gui.Name = "YE_AnalysisGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP.PlayerGui end

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0,340,0,420)
main.Position = UDim2.new(0.5,-170,0.5,-210)
main.BackgroundColor3 = C_BG
main.BorderSizePixel = 0
corner(main, 10)
stroke(main, C_BORDER, 1.5)

local header = Instance.new("Frame", main)
header.Size = UDim2.new(1,0,0,36)
header.BackgroundColor3 = C_BG
header.BorderSizePixel = 0
corner(header, 10)

local titleLbl = Instance.new("TextLabel", header)
titleLbl.BackgroundTransparency = 1
titleLbl.Size = UDim2.new(1,-40,1,0)
titleLbl.Position = UDim2.new(0,12,0,0)
titleLbl.Text = "yslemEgg — Analyse du jeu"
titleLbl.TextSize = 14
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextColor3 = C_MOON2
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0,22,0,22)
closeBtn.Position = UDim2.new(1,-28,0.5,-11)
closeBtn.BackgroundColor3 = Color3.fromRGB(180,50,50)
closeBtn.Text = "✕"; closeBtn.TextSize = 11
closeBtn.TextColor3 = C_WHITE; closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0; corner(closeBtn, 5)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
-- Fermer la fenêtre n'interrompt PAS l'analyse : elle continue et copie
-- son rapport en fin de course même fenêtre fermée (comme les autres
-- outils standalone de ce projet).

local sep = Instance.new("Frame", main)
sep.Size = UDim2.new(1,-24,0,1)
sep.Position = UDim2.new(0,12,0,36)
sep.BackgroundColor3 = C_BORDER; sep.BorderSizePixel = 0

local statusLbl = Instance.new("TextLabel", main)
statusLbl.BackgroundTransparency = 1
statusLbl.Size = UDim2.new(1,-24,0,18)
statusLbl.Position = UDim2.new(0,12,0,42)
statusLbl.Text = "Initialisation..."
statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.GothamMedium
statusLbl.TextColor3 = C_YELLOW
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local scroll = Instance.new("ScrollingFrame", main)
scroll.Size = UDim2.new(1,-24,1,-72)
scroll.Position = UDim2.new(0,12,0,64)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = C_MOON
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local list = Instance.new("UIListLayout", scroll)
list.Padding = UDim.new(0,1)
list.SortOrder = Enum.SortOrder.LayoutOrder

local _lineOrder = 0
local function uiLine(text, color)
	_lineOrder = _lineOrder + 1
	local l = Instance.new("TextLabel", scroll)
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1,0,0,14)
	l.Text = text
	l.TextSize = 10.5
	l.Font = Enum.Font.Code
	l.TextColor3 = color or C_DIM
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.LayoutOrder = _lineOrder
	return l
end

local function setStatus(txt, col)
	statusLbl.Text = txt
	statusLbl.TextColor3 = col or C_YELLOW
end

-- Force un frame de rendu avant de lancer les scans synchrones lourds
task.wait()

-- ============================================================
-- REPORT BUFFER (texte complet, indépendant de l'UI)
-- ============================================================
local Report = {}
local function R(line) table.insert(Report, line) end
local function log(uiText, uiColor, reportLine)
	print("[YE-ANALYSIS] "..(reportLine or uiText))
	uiLine(uiText, uiColor)
	R(reportLine or uiText)
end

local function safeStr(v)
	local ok, s = pcall(function()
		local t = typeof(v)
		if t == "string" then
			return '"'..v:sub(1,60)..(#v > 60 and "..." or "")..'"'
		elseif t == "number" or t == "boolean" then
			return tostring(v)
		elseif t == "table" then
			local ok2, j = pcall(function() return HttpService:JSONEncode(v) end)
			if ok2 then return j:sub(1,120)..(#j > 120 and "..." or "") end
			return "<table>"
		elseif t == "Instance" then
			return "<"..v.ClassName..":"..v.Name..">"
		elseif t == "Vector3" or t == "CFrame" or t == "Color3" or t == "UDim2" then
			return tostring(v)
		elseif t == "nil" then
			return "nil"
		else
			return "<"..t..">"
		end
	end)
	return ok and s or "<unserializable>"
end

-- ============================================================
-- PHASE 0 — INFOS GENERALES
-- ============================================================
setStatus("Scan: infos generales...", C_YELLOW)
R("======================================================")
R("  yslemEgg — RAPPORT D'ANALYSE DU JEU")
R("======================================================")
R("")
do
	local ok, name = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
	log("Jeu: "..(ok and name or "?"), C_MOON2, "Jeu: "..(ok and name or "inconnu"))
	log("PlaceId: "..tostring(game.PlaceId), C_DIM)
	log("JobId: "..tostring(game.JobId):sub(1,12).."...", C_DIM)
	log("Joueurs: "..#Players:GetPlayers().."/"..Players.MaxPlayers, C_DIM)
	log("LocalPlayer: "..LP.Name.." (id "..LP.UserId..")", C_DIM)
end
R("")

-- ============================================================
-- PHASE 1 — WORKSPACE TOP-LEVEL
-- ============================================================
setStatus("Scan: structure workspace...", C_YELLOW)
R("-- WORKSPACE (top-level) --")
uiLine("-- WORKSPACE --", C_MOON)
do
	local children = workspace:GetChildren()
	table.sort(children, function(a,b) return a.Name < b.Name end)
	for _, c in ipairs(children) do
		local ok, count = pcall(function() return #c:GetDescendants() end)
		local line = c.Name.." ("..c.ClassName..") — "..(ok and count or "?").." descendants"
		log(line, nil, "  "..line)
	end
end
R("")

-- ============================================================
-- PHASE 2 — PLOTS / PODIUMS / PROMPTS
-- ============================================================
setStatus("Scan: plots & prompts...", C_YELLOW)
R("-- PLOTS --")
uiLine("-- PLOTS --", C_MOON)
do
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		log("Aucun dossier 'Plots' trouve dans workspace", C_DIM, "  (aucun dossier Plots — structure differente)")
	else
		local pchildren = plots:GetChildren()
		log("Plots trouves: "..#pchildren, C_MOON2, "Plots trouves: "..#pchildren)
		local shown = 0
		for _, plot in ipairs(pchildren) do
			if shown >= 6 then
				log("... (+"..(#pchildren-shown).." autres plots, non detailles)", C_DIM)
				break
			end
			shown = shown + 1
			local mine = false
			pcall(function()
				local sign = plot:FindFirstChild("PlotSign")
				local yb = sign and sign:FindFirstChild("YourBase")
				if yb and yb:IsA("BillboardGui") then mine = yb.Enabled == true end
			end)
			log("  "..plot.Name.." — "..(mine and "MON PLOT" or "autre joueur"),
				mine and C_GREEN or C_DIM,
				"  Plot "..plot.Name.." ("..(mine and "mine" or "autre")..")")
			local podiums = plot:FindFirstChild("AnimalPodiums")
			if podiums then
				local pods = podiums:GetChildren()
				for i, pod in ipairs(pods) do
					if i > 4 then
						log("    ... (+"..(#pods-4).." autres podiums)", C_DIM)
						break
					end
					pcall(function()
						local base = pod:FindFirstChild("Base")
						local spawn = base and base:FindFirstChild("Spawn")
						local att = spawn and spawn:FindFirstChild("PromptAttachment")
						local prompt = nil
						if att then
							for _, ch in ipairs(att:GetChildren()) do
								if ch:IsA("ProximityPrompt") then prompt = ch; break end
							end
						end
						if prompt then
							local pline = "    "..pod.Name..": \""..prompt.ActionText.."\" / \""..prompt.ObjectText.."\" hold="..prompt.HoldDuration.."s maxDist="..prompt.MaxActivationDistance
							log(pline, C_DIM)
						else
							log("    "..pod.Name..": (pas de ProximityPrompt trouve)", C_DIM)
						end
					end)
				end
			end
		end
	end
end
R("")

-- ============================================================
-- PHASE 2b — OBJETS "EGG" DANS WORKSPACE (recherche par nom)
-- ============================================================
setStatus("Scan: objets 'egg'...", C_YELLOW)
R("-- OBJETS NOMMES 'EGG' (workspace) --")
uiLine("-- OBJETS 'EGG' --", C_MOON)
do
	local found = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if #found >= 25 then break end
		pcall(function()
			if obj.Name:lower():find("egg") and (obj:IsA("Model") or obj:IsA("BasePart")) then
				table.insert(found, obj:GetFullName())
			end
		end)
	end
	if #found == 0 then
		log("Aucun objet nomme 'egg' trouve dans workspace", C_DIM)
	else
		log(#found.." objet(s) trouve(s) (max 25 affiches)", C_MOON2)
		for _, path in ipairs(found) do
			log("  "..path, C_DIM)
		end
	end
end
R("")

-- ============================================================
-- PHASE 2c — ZONES / ILES (recherche d'îles/zones pas encore connues du hub)
-- ============================================================
setStatus("Scan: zones/iles...", C_YELLOW)
R("-- ZONES / ILES --")
uiLine("-- ZONES / ILES --", C_MOON)
do
	local function dumpFolder(path, folder)
		if not folder then
			log(path..": introuvable", C_DIM, path..": introuvable")
			return
		end
		local children = folder:GetChildren()
		log(path..": "..#children.." element(s)", C_MOON2, path..": "..#children.." element(s)")
		for _, c in ipairs(children) do
			log("  "..c.Name.." ("..c.ClassName..")", C_DIM, "  "..c.Name.." ("..c.ClassName..")")
		end
	end
	-- Zones gardees connues du hub (reqSP) — chemin exact utilise par yslemEgg.lua
	local objRoot = workspace:FindFirstChild("__OBJECTS")
	local areasRoot = objRoot and objRoot:FindFirstChild("Areas")
	local guardAreas = areasRoot and areasRoot:FindFirstChild("GuardAreas")
	dumpFolder("__OBJECTS.Areas.GuardAreas", guardAreas)

	-- Recherche large, indépendante du chemin ci-dessus : tout dossier/
	-- modèle dont le NOM évoque une zone/île, n'importe où dans workspace
	-- — c'est ce qui permet de repérer une île AJOUTÉE récemment même si
	-- elle n'est pas rangée au même endroit que les zones déjà connues.
	local seen = {}
	local candidates = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		local lname = inst.Name:lower()
		if (lname:find("area") or lname:find("island") or lname:find("zone") or lname:find("ile"))
			and (inst:IsA("Folder") or inst:IsA("Model") or inst:IsA("Configuration")) then
			local full = inst:GetFullName()
			if not seen[full] and candidates < 40 then
				seen[full] = true
				candidates = candidates + 1
				log("  candidat: "..full, C_DIM, "  candidat: "..full)
			end
		end
	end
	if candidates == 0 then log("Aucun candidat zone/ile trouve par mot-cle", C_DIM) end
end
R("")

-- ============================================================
-- PHASE 2d — OEUFS PAR ZONE + MOTS DE RARETE NON RECONNUS
-- ============================================================
-- Objectif direct : repérer une île/rareté que le hub principal ne
-- connaît pas encore. Liste toutes les zones sous AreaEggSlotsClient
-- (chaque enfant direct = une aire distincte), dump le texte brut par
-- modèle d'oeuf UNIQUE, et isole les mots capitalisés qui ne matchent
-- AUCUN mot-clé de rareté déjà connu du hub — candidats "nouvelle
-- rareté" directement exploitables.
setStatus("Scan: oeufs par zone & raretes...", C_YELLOW)
R("-- OEUFS PAR ZONE + RARETES NON RECONNUES --")
uiLine("-- OEUFS / RARETES --", C_MOON)
do
	local slotsRoot = workspace:FindFirstChild("AreaEggSlotsClient", true)
	if not slotsRoot then
		log("AreaEggSlotsClient introuvable (recherche recursive incluse)", C_YELLOW,
			"AreaEggSlotsClient introuvable (recherche recursive incluse)")
	else
		log("AreaEggSlotsClient: "..slotsRoot:GetFullName(), C_GREEN,
			"AreaEggSlotsClient: "..slotsRoot:GetFullName())

		local zoneNames = {}
		for _, c in ipairs(slotsRoot:GetChildren()) do table.insert(zoneNames, c.Name) end
		table.sort(zoneNames)
		log("Zones ("..#zoneNames.."): "..table.concat(zoneNames, ", "), C_MOON2,
			"Zones ("..#zoneNames.."): "..table.concat(zoneNames, ", "))

		-- Mots-clés de rareté DEJA connus du hub principal (yslemEgg.lua,
		-- variable _RARE_KEYWORDS) — tout mot capitalisé qui n'en fait
		-- pas partie est un candidat "nouvelle rareté / mutation".
		local KNOWN = {
			"secret","eternal","divine","divin","mythic","celestial","ancient",
			"rainbow","golden","shiny","radiant","corrupted","void","legendary",
		}
		local STOP = {
			Steal=true, Grab=true, Take=true, Hold=true, Slot=true, Slots=true,
			Area=true, Egg=true, Eggs=true, Field=true, Growing=true, Zone=true,
			The=true, And=true, For=true, You=true, Your=true, This=true, Not=true,
			Ready=true, Ripe=true, Kg=true, Level=true, Locked=true, Unlock=true,
			Value=true, Weight=true, Price=true, Cost=true, Buy=true, Sell=true,
		}
		local function isKnown(word)
			local lw = word:lower()
			for _, k in ipairs(KNOWN) do if lw:find(k, 1, true) then return true end end
			return false
		end

		local seenModel, unknownWords, total, shown = {}, {}, 0, 0
		for _, prompt in ipairs(slotsRoot:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") then
				total = total + 1
				local part = prompt.Parent
				local model = part
				while model and model.Parent and model.Parent ~= workspace and not model:IsA("Model") do
					model = model.Parent
				end
				local key = (model and model.Name or (part and part.Name) or "?").."@"..(model and model:GetFullName() or "?")
				if not seenModel[key] then
					seenModel[key] = true
					local texts = {}
					pcall(function()
						for _, d in ipairs((model or part):GetDescendants()) do
							if d:IsA("TextLabel") and d.Text ~= "" then table.insert(texts, d.Text) end
						end
					end)
					local full = table.concat(texts, " | ")
					if shown < 40 then
						shown = shown + 1
						log("  "..(model and model.Name or "?")..": "..full:sub(1,140), C_DIM,
							"  "..(model and model.Name or "?")..": "..full)
					end
					for w in full:gmatch("%a[%a']+") do
						if #w >= 4 and w:match("^%u") and not STOP[w] and not isKnown(w) then
							unknownWords[w] = (unknownWords[w] or 0) + 1
						end
					end
				end
			end
		end
		local uniqueModels = 0
		for _ in pairs(seenModel) do uniqueModels = uniqueModels + 1 end
		log("Prompts total: "..total.." | modeles uniques: "..uniqueModels, C_MOON2,
			"Prompts total: "..total.." | modeles uniques: "..uniqueModels)

		local unkList = {}
		for w, n in pairs(unknownWords) do table.insert(unkList, w.." (x"..n..")") end
		table.sort(unkList)
		if #unkList > 0 then
			log("MOTS NON RECONNUS (candidats nouvelle rarete/mutation) :", C_YELLOW,
				"MOTS NON RECONNUS (candidats nouvelle rarete/mutation) :")
			log("  "..table.concat(unkList, ", "), C_YELLOW, "  "..table.concat(unkList, ", "))
		else
			log("Aucun mot inconnu detecte (tout correspond a la liste connue)", C_DIM,
				"Aucun mot inconnu detecte (tout correspond a la liste connue)")
		end
	end
end
R("")

-- ============================================================
-- PHASE 2e — STRUCTURE DÉTAILLÉE D'UN SLOT D'OEUF (AreaEggSlotsClient)
-- ============================================================
-- Le rapport precedent a montre 0 ProximityPrompt sous
-- AreaEggSlotsClient malgre 592 descendants au total — le scanner
-- ESP/Auto Farm actuel (base sur ProximityPrompt) tape donc a cote sur
-- CE build du jeu. Cette phase dump la structure REELLE d'un enfant
-- (souvent un GUID, ex "00921def...") pour trouver le vrai mecanisme
-- (SmartPromptPart, Attributes, ClickDetector, etc.).
setStatus("Scan: structure d'un slot d'oeuf...", C_YELLOW)
R("-- STRUCTURE D'UN SLOT (AreaEggSlotsClient) --")
uiLine("-- STRUCTURE SLOT OEUF --", C_MOON)
do
	local slotsRoot = workspace:FindFirstChild("AreaEggSlotsClient", true)
	if not slotsRoot then
		log("AreaEggSlotsClient introuvable", C_DIM, "AreaEggSlotsClient introuvable")
	else
		local children = slotsRoot:GetChildren()
		local samples = {}
		-- 1 GUID-like + 1 "FirstAreaEgg_..." si possible (deux formes vues)
		for _, c in ipairs(children) do
			if #samples >= 2 then break end
			if c.Name:find(":Slot_") and #samples < 2 then table.insert(samples, c)
			elseif #c.Name == 32 and not c.Name:find(":") and #samples < 1 then table.insert(samples, c) end
		end
		if #samples == 0 and #children > 0 then table.insert(samples, children[1]) end

		for _, slot in ipairs(samples) do
			log("Slot: "..slot.Name.." (".. slot.ClassName ..")", C_GREEN,
				"Slot: "..slot.Name.." (".. slot.ClassName ..")")
			local okA, attrs = pcall(function() return slot:GetAttributes() end)
			if okA and attrs and next(attrs) then
				for k, v in pairs(attrs) do
					log("  [Attribute] "..k.." = "..tostring(v), C_MOON2, "  [Attribute] "..k.." = "..tostring(v))
				end
			else
				log("  (aucun attribute sur le slot lui-meme)", C_DIM)
			end
			local shown = 0
			pcall(function()
				for _, d in ipairs(slot:GetDescendants()) do
					shown = shown + 1
					if shown > 45 then
						log("  ... (+"..(#slot:GetDescendants()-45).." autres descendants, non affiches)", C_DIM)
						return
					end
					local extra = ""
					pcall(function()
						local a2 = d:GetAttributes()
						if a2 and next(a2) then
							local kv = {}
							for k, v in pairs(a2) do table.insert(kv, k.."="..tostring(v)) end
							extra = "  {"..table.concat(kv, ", ").."}"
						end
					end)
					log("    "..d.Name.." (".. d.ClassName ..")"..extra, C_DIM,
						"    "..d.Name.." (".. d.ClassName ..")"..extra)
				end
			end)
		end
	end
end
R("")

-- ============================================================
-- PHASE 2f — SMARTPROMPTPART (mécanisme d'interaction custom ?)
-- ============================================================
-- "SmartPromptPart" apparait plusieurs fois en top-level de workspace
-- dans le rapport precedent — probablement le remplacant maison de
-- ProximityPrompt sur ce jeu. On dump un exemplaire en detail.
setStatus("Scan: SmartPromptPart...", C_YELLOW)
R("-- SMARTPROMPTPART (exemplaire) --")
uiLine("-- SMARTPROMPTPART --", C_MOON)
do
	local found = nil
	local total = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst.Name == "SmartPromptPart" then
			total = total + 1
			if not found then found = inst end
		end
	end
	log("SmartPromptPart trouves au total: "..total, C_MOON2, "SmartPromptPart trouves au total: "..total)
	if found then
		log("Exemplaire: "..found:GetFullName(), C_GREEN, "Exemplaire: "..found:GetFullName())
		log("  ClassName: "..found.ClassName, C_DIM)
		local okA, attrs = pcall(function() return found:GetAttributes() end)
		if okA and attrs and next(attrs) then
			for k, v in pairs(attrs) do
				log("  [Attribute] "..k.." = "..tostring(v), C_MOON2, "  [Attribute] "..k.." = "..tostring(v))
			end
		else
			log("  (aucun attribute)", C_DIM)
		end
		-- Parent chain — pour savoir a quel oeuf/pen/plot il appartient
		local chain, anc = {}, found.Parent
		local hops = 0
		while anc and hops < 6 do
			table.insert(chain, anc.Name.."(".. anc.ClassName ..")")
			anc = anc.Parent; hops = hops + 1
		end
		log("  Parents: "..table.concat(chain, " < "), C_DIM, "  Parents: "..table.concat(chain, " < "))
		local shown = 0
		pcall(function()
			for _, d in ipairs(found:GetDescendants()) do
				shown = shown + 1
				if shown > 25 then log("  ... (troque)", C_DIM); return end
				log("    "..d.Name.." (".. d.ClassName ..")", C_DIM, "    "..d.Name.." (".. d.ClassName ..")")
			end
		end)
	else
		log("Aucun SmartPromptPart trouve", C_DIM)
	end
end
R("")

-- ============================================================
-- PHASE 2g — REMOTES DE LECTURE EggWorld (snapshot complet, non tronque)
-- ============================================================
-- Uniquement les remotes dont le nom sonne "lecture seule" (Ask*Snapshot
-- / AskEggRecord / AskFieldEggRarityShows) — on evite volontairement
-- AskHatch/AskPlaceEgg/AskFieldEggDrop/AskFieldEggCarry/AskSkipGrowth/
-- AskWearTool/AskDoffTool qui modifient l'etat du jeu.
setStatus("Scan: remotes EggWorld (lecture)...", C_YELLOW)
R("-- REMOTES EggWorld (invocations en lecture seule) --")
uiLine("-- EggWorld: donnees completes --", C_MOON)
do
	local netFolder = RS:FindFirstChild("Packages")
	netFolder = netFolder and netFolder:FindFirstChild("Networking")
	local function dumpFull(v, cap)
		cap = cap or 2500
		local ok, s = pcall(function()
			if typeof(v) == "table" then
				local ok2, j = pcall(function() return HttpService:JSONEncode(v) end)
				return ok2 and j or "<table non serialisable>"
			end
			return tostring(v)
		end)
		if not ok then return "<erreur serialisation>" end
		if #s > cap then return s:sub(1, cap).."... (tronque, "..#s.." caracteres au total)" end
		return s
	end
	local function tryInvoke(name, ...)
		if not netFolder then return false, "dossier Networking introuvable" end
		local inst = netFolder:FindFirstChild(name)
		if not inst or not inst:IsA("RemoteFunction") then return false, "remote introuvable: "..name end
		-- Lua 5.1 : '...' n'est pas capturable par une closure imbriquée,
		-- on le fige dans une table avant de créer le pcall(function()...end).
		local args, n = {...}, select("#", ...)
		return pcall(function() return inst:InvokeServer(table.unpack(args, 1, n)) end)
	end

	local sampleUid = nil
	do
		local slotsRoot = workspace:FindFirstChild("AreaEggSlotsClient", true)
		if slotsRoot then
			local kids = slotsRoot:GetChildren()
			if #kids > 0 then sampleUid = kids[1].Name end
		end
	end
	log("UID d'exemple utilise: "..tostring(sampleUid), C_DIM, "UID d'exemple utilise: "..tostring(sampleUid))

	local READ_ONLY = { "RF/EggWorld/AskFieldEggSnapshot", "RF/EggWorld/AskLiveSnapshot",
		"RF/EggWorld/AskFieldEggRarityShows", "RF/EggWorld/AskEggRecord" }
	for _, name in ipairs(READ_ONLY) do
		local ok, res = tryInvoke(name)
		if not ok and sampleUid then
			-- essai avec l'UID d'exemple si l'appel sans argument echoue
			ok, res = tryInvoke(name, sampleUid)
		end
		if ok then
			log(name..":", C_GREEN, name..":")
			log("  "..dumpFull(res), C_DIM, "  "..dumpFull(res))
		else
			log(name..": echec — "..tostring(res), C_YELLOW, name..": echec — "..tostring(res))
		end
	end
end
R("")

-- ============================================================
-- PHASE 3 — LEADERSTATS
-- ============================================================
setStatus("Scan: leaderstats...", C_YELLOW)
R("-- LEADERSTATS --")
uiLine("-- LEADERSTATS --", C_MOON)
do
	local ls = LP:FindFirstChild("leaderstats")
	if not ls then
		log("Pas de 'leaderstats' trouve sur LocalPlayer", C_DIM)
	else
		for _, stat in ipairs(ls:GetChildren()) do
			local line = stat.Name..": "..tostring(stat.Value)
			log(line, C_MOON2, "  "..line)
		end
	end
end
R("")

-- ============================================================
-- PHASE 4 — REMOTES (ReplicatedStorage + RobloxReplicatedStorage)
-- ============================================================
local function scanRemotes(root, rootName)
	local events, funcs = {}, {}
	if not root then return events, funcs end
	for _, v in ipairs(root:GetDescendants()) do
		if v:IsA("RemoteEvent") then
			table.insert(events, v)
		elseif v:IsA("RemoteFunction") then
			table.insert(funcs, v)
		end
	end
	return events, funcs
end

setStatus("Scan: remotes ReplicatedStorage...", C_YELLOW)
R("-- REMOTES (ReplicatedStorage) --")
uiLine("-- REMOTES ReplicatedStorage --", C_MOON)
local rsEvents, rsFuncs = scanRemotes(RS, "ReplicatedStorage")
log("RemoteEvent: "..#rsEvents.." | RemoteFunction: "..#rsFuncs, C_MOON2,
	"RemoteEvent: "..#rsEvents.." | RemoteFunction: "..#rsFuncs)
do
	local shown = 0
	for _, ev in ipairs(rsEvents) do
		shown = shown + 1
		if shown > 60 then
			log("... (+"..(#rsEvents-60).." autres RemoteEvent, non affiches)", C_DIM)
			break
		end
		log("  [Event] "..ev:GetFullName(), C_DIM)
	end
	for _, fn in ipairs(rsFuncs) do
		log("  [Func]  "..fn:GetFullName(), C_DIM)
	end
end
R("")

setStatus("Scan: remotes RobloxReplicatedStorage...", C_YELLOW)
R("-- REMOTES (RobloxReplicatedStorage) --")
uiLine("-- REMOTES RobloxReplicatedStorage --", C_MOON)
local RRS = game:FindFirstChild("RobloxReplicatedStorage")
local rrsEvents, rrsFuncs = scanRemotes(RRS, "RobloxReplicatedStorage")
log("RemoteEvent: "..#rrsEvents.." | RemoteFunction: "..#rrsFuncs, C_MOON2,
	"RemoteEvent: "..#rrsEvents.." | RemoteFunction: "..#rrsFuncs)
for _, ev in ipairs(rrsEvents) do
	log("  [Event] "..ev.Name, C_DIM)
end
for _, fn in ipairs(rrsFuncs) do
	log("  [Func]  "..fn.Name, C_DIM)
end
R("")

-- ============================================================
-- PHASE 5 — ECOUTE PASSIVE DU TRAFIC (lecture seule, zero hook)
-- ============================================================
-- Uniquement des Connect() sur OnClientEvent des RemoteEvent deja
-- decouverts — n'intercepte RIEN, ne bloque RIEN, n'ecrase aucun
-- handler existant (contrairement a un hook __namecall ou a une
-- reaffectation d'OnClientInvoke, tous deux evites ici sciemment).
setStatus("Ecoute du trafic reseau ("..LISTEN_DURATION.."s)...", C_YELLOW)
uiLine("-- TRAFIC RESEAU ("..LISTEN_DURATION.."s d'ecoute passive) --", C_MOON)

local tally, samples, order = {}, {}, {}
local liveConns = {}

local allEvents = {}
for _, ev in ipairs(rsEvents) do table.insert(allEvents, ev) end
for _, ev in ipairs(rrsEvents) do table.insert(allEvents, ev) end

local connected = 0
for _, ev in ipairs(allEvents) do
	if connected >= MAX_LIVE_LISTEN then break end
	local ok, conn = pcall(function()
		return ev.OnClientEvent:Connect(function(...)
			local n = ev:GetFullName()
			if not tally[n] then tally[n] = 0; table.insert(order, n) end
			tally[n] = tally[n] + 1
			if not samples[n] then
				local args = {...}
				local parts = {}
				for i = 1, math.min(#args, 4) do parts[#parts+1] = safeStr(args[i]) end
				samples[n] = table.concat(parts, ", ")
			end
		end)
	end)
	if ok and conn then
		connected = connected + 1
		table.insert(liveConns, conn)
	end
end
log("Connexions d'ecoute actives: "..connected.."/"..#allEvents, C_DIM)

for i = LISTEN_DURATION, 1, -1 do
	setStatus("Ecoute du trafic reseau... "..i.."s restantes", C_YELLOW)
	task.wait(1)
end

-- Cleanup : lecture seule garantie, aucune connexion ne survit à l'analyse
for _, conn in ipairs(liveConns) do pcall(function() conn:Disconnect() end) end

R("-- TRAFIC RESEAU OBSERVE ("..LISTEN_DURATION.."s) --")
if #order == 0 then
	log("Aucun trafic entrant observe pendant la fenetre d'ecoute", C_DIM,
		"Aucun trafic entrant observe pendant la fenetre d'ecoute")
else
	table.sort(order, function(a,b) return tally[a] > tally[b] end)
	for _, n in ipairs(order) do
		local line = n.." — "..tally[n].." appel(s) | ex: "..(samples[n] or "")
		log(line, C_MOON2, line)
	end
end
R("")

-- ============================================================
-- PHASE 6 — LIGHTING / CAMERA (contexte visuel, utile pour Visual tab)
-- ============================================================
R("-- LIGHTING --")
R("Brightness="..Lighting.Brightness.." ClockTime="..Lighting.ClockTime
	.." GlobalShadows="..tostring(Lighting.GlobalShadows))
R("")

-- ============================================================
-- RAPPORT FINAL
-- ============================================================
setStatus("Generation du rapport...", C_YELLOW)
R("======================================================")
R("  FIN DU RAPPORT")
R("======================================================")

local fullReport = table.concat(Report, "\n")

local copied = false
pcall(function()
	if setclipboard then
		setclipboard(fullReport)
		copied = true
	elseif toclipboard then
		toclipboard(fullReport)
		copied = true
	end
end)

if copied then
	setStatus("Termine — rapport copie automatiquement !", C_GREEN)
	uiLine("=== RAPPORT COPIE DANS LE PRESSE-PAPIER ===", C_GREEN)
else
	setStatus("Termine — copie indisponible, voir console (F9)", C_YELLOW)
	uiLine("=== setclipboard indisponible — rapport imprime en console ===", C_YELLOW)
	print(fullReport)
end

print("[YE-ANALYSIS] === RAPPORT COMPLET ("..#fullReport.." caracteres) ===")
