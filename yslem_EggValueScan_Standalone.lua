--[[
	yslem_EggValueScan_Standalone.lua
	================================================================
	Objectif : UN SEUL rapport, complet, qui donne toute la
	connaissance nécessaire sur le systeme d'oeufs de CE jeu — pas
	seulement "y a-t-il une valeur" mais toute la structure autour :
	valeur d'oeuf (comme "Snowy Owl — 26.77M" vu dans LENNON HUB avec
	son toggle "Teleguiado"), tables de donnees statiques, inventaire
	complet des remotes, et carte de la map. yslemEgg.lua ne lit
	aujourd'hui QUE Mutation/NestScale/Zone/CFrame dans les payloads
	FieldEggShifted / AskFieldEggSnapshot — tout autre champ
	(Value/Price/Worth/Species/...) est actuellement ignoré en
	silence. Ce script dump TOUT (toutes les clefs, tous les modules,
	tous les remotes) pour construire une comprehension complete
	avant d'aller batir une fonctionnalite "Best Egg" sur une
	supposition.

	100% lecture seule : aucun hook ne bloque ni ne modifie quoi que
	ce soit. On écoute, on Invoke (lecture), on require() des
	ModuleScripts de données (lecture de leur table retournée). Aucune
	action gameplay.

	Auto-run, auto-stop. Duree totale variable (peut se compter en
	minutes selon la taille du jeu) — c'est attendu: priorite donnee a
	la couverture complete + a ne jamais geler le client, pas a la
	vitesse. Voir les logs "termine — Xs ecoulees" par section dans la
	console pour suivre precisement ou passe le temps. Resultats dans
	une fenêtre en jeu
	(8 sections scrollables) + dump complet dans la console + bouton
	"Copier" — un seul rapport consolidé, a coller integralement.
	================================================================
]]

local Players           = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local LIVE_CAPTURE_DURATION = 40   -- plafond MAXIMUM si (presque) rien ne se passe
local LIVE_CAPTURE_MIN      = 5    -- minimum avant de pouvoir sortir plus tot
local LIVE_CAPTURE_EARLY    = 8    -- sortie anticipee des que ce nombre d'evenements est capture

local function log(...) print("[EGGSCAN]", ...) end
local _scanStart = os.clock()
log("=== DEBUT Analyse complete ===")

-- ============================================================
-- Rapport texte (console + presse-papiers) — rempli au fur et à
-- mesure par chaque section.
-- ============================================================
local report  = {}
local flagged = {}  -- {path, value} — champs dont le NOM sent la valeur monétaire
local function addLine(s) table.insert(report, s) end
local function addHeader(s)
	addLine("")
	addLine("========== "..s.." ==========")
end

-- ============================================================
-- Dump générique d'une table Lua/Roblox — profondeur et largeur
-- bornées pour rester lisible (et pour toujours terminer même sur
-- une table géante ou auto-référentielle).
-- ============================================================
local VALUE_KW = {"value","price","worth","money","cash","coin","reward",
                   "sell","cost","gem","point"}
local function isFlagKey(k)
	if type(k) ~= "string" then return false end
	local kl = k:lower()
	for _, w in ipairs(VALUE_KW) do
		if kl:find(w, 1, true) then return true end
	end
	return false
end

local function fmtLeaf(v)
	local ty = typeof(v)
	if ty == "Instance" then return string.format("<%s:%s>", v.ClassName, v.Name) end
	if ty == "string" then return string.format("%q", v) end
	if ty == "function" then return "<function>" end
	if ty == "thread" then return "<thread>" end
	return tostring(v)
end

-- Detection par FORME de la valeur, independante du nom de la clef —
-- complementaire a isFlagKey (qui ne regarde que le nom). Un champ
-- obfusque/court ("w", "v2", "amt") portant un nombre a 6+ chiffres
-- ou une chaine formatee "26.77M" passe totalement sous le radar
-- d'un filtre par nom ; celui-ci l'attrape par la FORME de la donnee.
local function looksLikeMoney(v)
	if type(v) == "number" then
		return v >= 1000  -- ce jeu affiche des valeurs en dizaines de millions
	end
	if type(v) == "string" then
		-- "26.77M", "1.2K", "500B", "$1,234", "12500"
		return v:match("^%$?%d[%d,%.]*%s*[KkMmBbTt]?$") ~= nil and v:match("%d") ~= nil
	end
	return false
end

-- Caps volontairement larges — "scanner tout" prime sur la lisibilite.
-- MAX_DEPTH/MAX_ITEMS restent en dernier recours anti-crash (stack
-- overflow / rapport de plusieurs dizaines de Mo), pas des filtres de
-- contenu : la detection de cycle (visited) est ce qui protege
-- vraiment contre une table auto-referentielle (OOP a la
-- Roblox, __index vers elle-meme, etc.) — sans elle, un cycle a
-- N'IMPORTE quelle profondeur boucle a l'infini.
local MAX_DEPTH, MAX_ITEMS = 20, 2000
-- Compteur partage entre tous les appels dumpTable — un SEUL module de
-- donnees enorme (large ET profond) peut a lui seul generer des
-- milliers de lignes sans jamais rendre la main tant que le dump n'est
-- pas fini; on yield au fil de l'eau plutot que d'attendre la fin.
local _dumpLineCount = 0
local function emit(lines, s)
	lines[#lines+1] = s
	_dumpLineCount = _dumpLineCount + 1
	if _dumpLineCount % 500 == 0 then task.wait() end
end
local function dumpTable(t, path, depth, lines, visited)
	if visited[t] then
		emit(lines, string.rep("  ", depth).."<cycle: deja visite plus haut>")
		return
	end
	visited[t] = true
	local n = 0
	for k, v in pairs(t) do
		n = n + 1
		if n > MAX_ITEMS then
			emit(lines, string.rep("  ", depth)..string.format("... (+%d entrees restantes, tronque)", 0))
			break
		end
		local ks   = tostring(k)
		local kpath = path.."."..ks
		if typeof(v) == "table" then
			if depth >= MAX_DEPTH then
				emit(lines, string.rep("  ", depth)..ks.." = { ... (profondeur max "..MAX_DEPTH..") }")
			else
				emit(lines, string.rep("  ", depth)..ks.." = {")
				dumpTable(v, kpath, depth+1, lines, visited)
				emit(lines, string.rep("  ", depth).."}")
			end
		else
			local leaf = fmtLeaf(v)
			emit(lines, string.rep("  ", depth)..ks.." = "..leaf)
			if isFlagKey(ks) then
				flagged[#flagged+1] = {path=kpath, value=leaf}
			elseif looksLikeMoney(v) then
				-- Nom de clef quelconque/obfusque mais la VALEUR a la forme
				-- d'un montant — signale separement (moins fiable qu'un nom
				-- explicite, donc marque "?" dans le rapport final).
				flagged[#flagged+1] = {path=kpath.." (forme uniquement)", value=leaf}
			end
		end
	end
	visited[t] = nil  -- depile: un meme sous-tableau reference 2x en parallele (pas en cycle) doit re-dumper
	if n == 0 then
		lines[#lines+1] = string.rep("  ", depth).."(table vide)"
	end
end

local function dumpRoot(label, t)
	local lines = {}
	local ok = pcall(dumpTable, t, label, 1, lines, {})
	if not ok then lines[#lines+1] = "  (erreur pendant le dump — table incompatible)" end
	return table.concat(lines, "\n")
end

-- ============================================================
-- Remotes — même découverte que yslemEgg.lua (Packages.Networking,
-- noms plats "RF/Famille/Action" / "RE/Famille/Action").
-- ============================================================
local NetFolder = ReplicatedStorage:FindFirstChild("Packages")
NetFolder = NetFolder and NetFolder:FindFirstChild("Networking")

local function getRemote(name)
	if not NetFolder then return nil end
	local exact = NetFolder:FindFirstChild(name)
	if exact then return exact end
	if not name:find("/", 1, true) then
		local suffix = "/"..name
		for _, inst in ipairs(NetFolder:GetChildren()) do
			if inst.Name:sub(-#suffix) == suffix then return inst end
		end
	end
	return nil
end

-- require() protege par timeout — indispensable des lors qu'on
-- require() TOUS les ModuleScripts sans filtre par nom: un module
-- "controller" peut faire un WaitForChild/InvokeServer bloquant a
-- son chargement, ce qui gelerait le script entier sans pcall
-- (pcall n'attrape que les erreurs, pas un yield qui ne revient
-- jamais). On lance le require() dans son propre thread et on
-- abandonne si rien n'est revenu apres timeoutSec.
local function requireWithTimeout(mod, timeoutSec)
	local done, ok, result = false, false, nil
	task.spawn(function()
		ok, result = pcall(require, mod)
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < timeoutSec do
		task.wait(0.05)
	end
	if not done then
		return false, string.format("(timeout %.1fs — le module yield probablement au chargement, ignore)", timeoutSec)
	end
	return ok, result
end

-- ============================================================
-- UI — meme esprit visuel que les autres widgets du hub (fond sombre,
-- accent bleu, coins arrondis, liseré). Fenetre autonome, aucune
-- dependance a yslemEgg.lua.
-- ============================================================
local C_BG, C_PANEL, C_ACCENT, C_TEXT, C_DIM =
	Color3.fromRGB(22,22,28), Color3.fromRGB(30,30,38),
	Color3.fromRGB(90,160,255), Color3.fromRGB(235,235,240), Color3.fromRGB(150,150,160)

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst
	return c
end
local function stroke(inst, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or C_ACCENT; s.Thickness = thick or 1; s.Transparency = 0.4
	s.Parent = inst
	return s
end

local ui = {}
local function buildUI()
	local ok = pcall(function()
		local gui = Instance.new("ScreenGui")
		gui.Name = "EggValueScanUI"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		local parentOk = pcall(function() gui.Parent = game:GetService("CoreGui") end)
		if not parentOk or not gui.Parent then
			gui.Parent = LP:WaitForChild("PlayerGui")
		end

		local main = Instance.new("Frame")
		main.Size = UDim2.fromOffset(340, 400)
		main.Position = UDim2.new(0.5, -170, 0.5, -200)
		main.BackgroundColor3 = C_BG
		main.BorderSizePixel = 0
		main.Parent = gui
		corner(main, 10); stroke(main, C_ACCENT, 1)

		local header = Instance.new("Frame")
		header.Size = UDim2.new(1, 0, 0, 40)
		header.BackgroundColor3 = C_PANEL
		header.BorderSizePixel = 0
		header.Parent = main
		corner(header, 10)
		local headerFix = Instance.new("Frame") -- masque l'arrondi du bas du header
		headerFix.Size = UDim2.new(1, 0, 0, 10)
		headerFix.Position = UDim2.new(0, 0, 1, -10)
		headerFix.BackgroundColor3 = C_PANEL
		headerFix.BorderSizePixel = 0
		headerFix.Parent = header

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.new(0, 12, 0, 0)
		title.Size = UDim2.new(1, -80, 1, 0)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 15
		title.TextColor3 = C_TEXT
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "Analyse complete"
		title.Parent = header

		local status = Instance.new("TextLabel")
		status.BackgroundTransparency = 1
		status.Position = UDim2.new(1, -140, 0, 0)
		status.Size = UDim2.new(0, 96, 1, 0)
		status.Font = Enum.Font.Gotham
		status.TextSize = 12
		status.TextColor3 = C_DIM
		status.TextXAlignment = Enum.TextXAlignment.Right
		status.Text = "Demarrage..."
		status.Parent = header

		local closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.fromOffset(28, 28)
		closeBtn.Position = UDim2.new(1, -34, 0, 6)
		closeBtn.BackgroundColor3 = Color3.fromRGB(50,30,32)
		closeBtn.Text = "X"
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.TextSize = 14
		closeBtn.TextColor3 = C_TEXT
		closeBtn.Parent = header
		corner(closeBtn, 6)
		closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

		-- drag
		do
			local dragging, dragStart, startPos = false, nil, nil
			header.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true; dragStart = input.Position; startPos = main.Position
					input.Changed:Connect(function()
						if input.UserInputState == Enum.UserInputState.End then dragging = false end
					end)
				end
			end)
			header.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch) then
					local delta = input.Position - dragStart
					main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
						startPos.Y.Scale, startPos.Y.Offset + delta.Y)
				end
			end)
		end

		local scroll = Instance.new("ScrollingFrame")
		scroll.Position = UDim2.new(0, 8, 0, 46)
		scroll.Size = UDim2.new(1, -16, 1, -92)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 5
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.Parent = main
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.Parent = scroll

		local copyBtn = Instance.new("TextButton")
		copyBtn.Size = UDim2.new(1, -16, 0, 32)
		copyBtn.Position = UDim2.new(0, 8, 1, -40)
		copyBtn.BackgroundColor3 = C_ACCENT
		copyBtn.Font = Enum.Font.GothamBold
		copyBtn.TextSize = 13
		copyBtn.TextColor3 = Color3.new(1,1,1)
		copyBtn.Text = "Copier les resultats"
		copyBtn.Parent = main
		corner(copyBtn, 6)

		ui.gui = gui; ui.status = status; ui.scroll = scroll; ui.copyBtn = copyBtn
	end)
	if not ok then log("UI indisponible — mode console uniquement") end
end
buildUI()

-- setStatus() ne fait plus qu'enregistrer la PHASE en cours — l'affichage
-- reel est pris en charge par un ticker independant ci-dessous, qui
-- tourne en continu meme pendant une section qui ne rappelle pas
-- setStatus elle-meme (ex: le parcours d'arbre D/E). Sans ca, le
-- decompte semblait "fige" a chaque gros bloc de travail alors que le
-- scan avancait bel et bien.
local _currentPhase = "Demarrage..."
local function setStatus(s) _currentPhase = s end
local _scanRunning = true
task.spawn(function()
	while _scanRunning do
		if ui.status then
			pcall(function()
				ui.status.Text = _currentPhase.." — "..math.floor(os.clock()-_scanStart).."s ecoulees"
			end)
		end
		task.wait(1)
	end
end)

local sectionCount = 0
local function addSection(title, body)
	sectionCount = sectionCount + 1
	addHeader(title)
	addLine(body)
	log(title.." — voir console / UI pour le detail")
	if ui.scroll then
		pcall(function()
			local lbl = Instance.new("TextLabel")
			lbl.LayoutOrder = sectionCount
			lbl.BackgroundColor3 = C_PANEL
			lbl.Size = UDim2.new(1, 0, 0, 0)
			lbl.AutomaticSize = Enum.AutomaticSize.Y
			lbl.Font = Enum.Font.Code
			lbl.TextSize = 12
			lbl.TextColor3 = C_TEXT
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextYAlignment = Enum.TextYAlignment.Top
			lbl.TextWrapped = true
			lbl.Text = "» "..title.."\n"..body
			lbl.Parent = ui.scroll
			corner(lbl, 6)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
			pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6)
			pad.Parent = lbl
		end)
	end
	-- Une seule frame suffit a rendre la main entre 2 sections — les
	-- grosses boucles (C, arbres D/E/G, texte H) ont deja leurs propres
	-- pauses internes qui font le vrai travail anti-gel. Une pause d'1s
	-- ICI EN PLUS ne protegeait de rien et ajoutait 8s pour rien sur la
	-- duree totale (8 sections) — coupe.
	task.wait()
	log(string.format("[%s] termine — %.1fs ecoulees depuis le debut", title, os.clock() - _scanStart))
end

-- ============================================================
-- SECTION A — AskFieldEggSnapshot (instantane, source la plus riche :
-- demande directement au serveur la liste actuelle des oeufs).
-- On dump TOUTES les clefs de TOUTES les entrees (pas juste
-- Mutation/NestScale/Zone comme yslemEgg.lua) pour voir ce qui existe.
-- ============================================================
setStatus("Section A...")
do
	local rf = getRemote("RF/EggWorld/AskFieldEggSnapshot")
	if not (rf and rf:IsA("RemoteFunction")) then
		addSection("A. AskFieldEggSnapshot", "Remote introuvable — impossible d'interroger.")
	else
		local ok, snap = pcall(function() return rf:InvokeServer() end)
		if not ok or type(snap) ~= "table" then
			addSection("A. AskFieldEggSnapshot", "Echec ou reponse non-table: "..tostring(snap))
		else
			-- Normalise en tableau d'entrees quel que soit le format
			-- (array direct, ou table indexee par uid).
			local entries = {}
			for k, v in pairs(snap) do
				if type(v) == "table" then entries[#entries+1] = v
				else entries[#entries+1] = {[tostring(k)]=v} end
			end
			local body = string.format("%d entree(s) dans le snapshot.\n", #entries)
			-- Toutes les clefs vues sur TOUTES les entrees (les champs sont
			-- parfois absents sur certaines entrees) + un exemple de valeur.
			local allKeys = {}
			for _, e in ipairs(entries) do
				if type(e) == "table" then
					for k, v in pairs(e) do
						if type(k) == "string" and not allKeys[k] then
							allKeys[k] = fmtLeaf(v)
						end
					end
				end
			end
			local keyLines = {}
			for k, v in pairs(allKeys) do
				keyLines[#keyLines+1] = "  "..k.." (ex: "..v..")"
				if isFlagKey(k) then flagged[#flagged+1] = {path="Snapshot."..k, value=v} end
			end
			table.sort(keyLines)
			body = body.."Clefs vues sur l'ensemble des entrees:\n"..table.concat(keyLines, "\n")
			local entryParts = {body,
				string.format("\n\nDump complet des %d entree(s) (TOUTES, pas un echantillon):\n", #entries)}
			for i = 1, #entries do
				entryParts[#entryParts+1] = dumpRoot("entry"..i, entries[i]).."\n"
				if i % 20 == 0 then task.wait() end
			end
			addSection("A. AskFieldEggSnapshot", table.concat(entryParts))
		end
	end
end

-- ============================================================
-- SECTION C — inventaire de TOUS les ModuleScript (juste les noms,
-- rapide) dans TOUS les conteneurs accessibles cote client, MAIS
-- dump integral (require + contenu) reserve aux modules dont le nom
-- evoque des donnees egg/pet — c'est le retour arriere volontaire
-- apres le test en jeu: dump integral de TOUT (des centaines de
-- modules, la plupart des composants UI generiques sans aucun rapport
-- avec des oeufs) faisait tourner la duree totale a plusieurs
-- minutes pour tres peu de gain reel. Rien n'est invisible pour
-- autant: l'inventaire des noms reste complet et rapide (juste une
-- boucle GetDescendants, pas de require()), donc un module au nom
-- inattendu qu'on aurait mal filtre reste visible — il suffit de me
-- dire lequel dumper en detail.
-- ============================================================
setStatus("Section C: modules...")
do
	-- Decouverte DYNAMIQUE plutot qu'une liste devinee a la main: on
	-- prend TOUT ce que `game` expose comme enfant direct — c'est la
	-- liste reelle des services existants dans CE jeu precis, donc par
	-- construction on ne peut plus en "oublier un" comme le tour d'avant
	-- (StarterPlayer avait ete ajoute a la main, PlayerGui etait reste
	-- manquant). ServerScriptService/ServerStorage apparaissent dans
	-- cette liste mais leur contenu n'est jamais replique au client —
	-- GetDescendants() y renverra 0 module, ce qui EST la reponse
	-- correcte (limite Roblox, pas un bug de ce scan).
	local CONTAINERS = {}
	pcall(function()
		for _, svc in ipairs(game:GetChildren()) do CONTAINERS[#CONTAINERS+1] = svc end
	end)
	-- Ajouts qui ne sont PAS des services top-level de `game` mais des
	-- instances specifiques au LocalPlayer — les copies REELLEMENT
	-- executees de StarterGui/StarterPack/StarterPlayerScripts, la ou
	-- vivent la plupart des controleurs UI/valeur d'un jeu Roblox
	-- moderne (rater ca, c'est rater l'endroit le plus probable).
	pcall(function() if LP:FindFirstChild("PlayerGui") then CONTAINERS[#CONTAINERS+1] = LP.PlayerGui end end)
	pcall(function() if LP:FindFirstChild("PlayerScripts") then CONTAINERS[#CONTAINERS+1] = LP.PlayerScripts end end)
	pcall(function() if LP:FindFirstChild("Backpack") then CONTAINERS[#CONTAINERS+1] = LP.Backpack end end)
	-- CoreGui: normalement proteger par le moteur, mais accessible sur
	-- certains executeurs — tente quand meme, echoue silencieusement
	-- sinon (pcall sur GetDescendants plus bas gere ca).
	pcall(function() CONTAINERS[#CONTAINERS+1] = game:GetService("CoreGui") end)
	local allMods, seen = {}, {}
	for _, root in ipairs(CONTAINERS) do
		pcall(function()
			for i2, inst in ipairs(root:GetDescendants()) do
				if inst:IsA("ModuleScript") and not seen[inst] then
					seen[inst] = true
					allMods[#allMods+1] = inst
				end
				if i2 % 1000 == 0 then task.wait() end
			end
		end)
	end

	local INCLUDE_A = {"egg","pet"}
	local INCLUDE_B = {"value","price","worth","data","config","rarity","mutation","index","list"}
	local EXCLUDE    = {"controller","manager","service","handler","system","network","remote","ui","gui"}
	local function matches(name)
		local nl = name:lower()
		local hasA, hasB, hasEx = false, false, false
		for _, w in ipairs(INCLUDE_A) do if nl:find(w,1,true) then hasA=true break end end
		if not hasA then return false end
		for _, w in ipairs(INCLUDE_B) do if nl:find(w,1,true) then hasB=true break end end
		if not hasB then return false end
		for _, w in ipairs(EXCLUDE) do if nl:find(w,1,true) then hasEx=true break end end
		return not hasEx
	end
	local candidates = {}
	for _, mod in ipairs(allMods) do
		if matches(mod.Name) then candidates[#candidates+1] = mod end
	end

	local bodyParts = {string.format(
		"%d ModuleScript(s) au total (tous conteneurs client confondus). "
		.."Inventaire complet des noms ci-dessous, plafonne a 400 "
		.."(rapide — pas de require()).\n", #allMods)}
	for i, mod in ipairs(allMods) do
		if i > 400 then
			bodyParts[#bodyParts+1] = string.format("  ... (+%d autres, tronque)\n", #allMods - 400)
			break
		end
		bodyParts[#bodyParts+1] = "  "..mod:GetFullName().."\n"
		if i % 300 == 0 then task.wait() end
	end

	bodyParts[#bodyParts+1] = string.format(
		"\n%d candidat(s) donnees egg/pet — dump integral (require + contenu) "
		.."ci-dessous (timeout 0.2s si un chargement bloque):\n", #candidates)
	if #candidates == 0 then
		bodyParts[#bodyParts+1] = "Aucun module dont le nom evoque une table de valeurs "
			.."(egg/pet + value/price/worth/data/config/rarity/mutation).\n"
			.."Regarde l'inventaire complet ci-dessus: si un nom inattendu "
			.."ressemble a une table de donnees egg/pet, dis-le pour que je "
			.."le dump specifiquement au prochain tour."
	end
	local nOk, nErr, nTimeout, nNonTable = 0, 0, 0, 0
	for i, mod in ipairs(candidates) do
		setStatus(string.format("Section C: candidats %d/%d", i, #candidates))
		bodyParts[#bodyParts+1] = "\n--- "..mod:GetFullName().." ---\n"
		local ok, result = requireWithTimeout(mod, 0.2)
		if not ok then
			local msg = tostring(result)
			if msg:find("timeout", 1, true) then nTimeout = nTimeout + 1 else nErr = nErr + 1 end
			bodyParts[#bodyParts+1] = "  echec: "..msg.."\n"
		elseif type(result) ~= "table" then
			nNonTable = nNonTable + 1
			bodyParts[#bodyParts+1] = "  retourne un "..typeof(result)..", pas une table: "..fmtLeaf(result).."\n"
		else
			nOk = nOk + 1
			bodyParts[#bodyParts+1] = dumpRoot(mod.Name, result).."\n"
		end
		task.wait()
	end
	if #candidates > 0 then
		bodyParts[#bodyParts+1] = string.format(
			"\nResume candidats: %d dumpes en table, %d non-table, %d en erreur, %d en timeout (sur %d).",
			nOk, nNonTable, nErr, nTimeout, #candidates)
	end
	addSection("C. ModuleScripts (inventaire complet + dump cible egg/pet)", table.concat(bodyParts))
end

-- ============================================================
-- SECTION D — arbre COMPLET du workspace, tout niveau, tout dossier
-- (plus de plafond "3 niveaux" ni de saut des dossiers >60 enfants —
-- "tout" veut dire tout), ENRICHI de 2 sources de donnees que le
-- premier passage ratait completement :
--   1) ValueBase (.Value) — IntValue/NumberValue/StringValue/
--      BoolValue affichent leur valeur directement (motif classique
--      Roblox pour stocker une donnee sur une instance, comme
--      leaderstats mais n'importe ou dans la hierarchie).
--   2) Attributs (Instance:GetAttributes()) — motif moderne
--      equivalent, tres courant pour poser p.ex. Value/Rarity/Price
--      directement sur le modele d'un oeuf sans passer par un remote.
-- (les tags CollectionService ont ete retires: cout reel par instance
-- pour un signal quasi jamais porteur d'une valeur numerique)
-- MAX_TREE_DEPTH n'est qu'un garde-fou anti-stack-overflow (aucune
-- hierarchie Roblox reelle n'atteint 80 niveaux), pas un filtre de
-- contenu ; MAX_TREE_LINES est un garde-fou de derniere ligne contre
-- un rapport de plusieurs dizaines de Mo si la map est
-- extraordinairement massive.
-- Tally des ClassName rencontres + leaderstats de TOUS les joueurs
-- (pas seulement LocalPlayer — c'est un dossier public, diffuse a
-- tout le monde par design, donc une vraie source si le jeu y affiche
-- une "meilleure valeur" par joueur).
-- ============================================================
setStatus("Section D: map...")
do
	local VALUE_CLASSES = {
		IntValue=true, NumberValue=true, StringValue=true, BoolValue=true,
		ObjectValue=true, Vector3Value=true, CFrameValue=true, Color3Value=true,
	}
	local MAX_TREE_DEPTH, MAX_TREE_LINES = 80, 150000
	local lines = {}
	local classTally = {}
	local truncated = false

	-- CollectionService:GetTags() retire: cout reel (1 appel API de
	-- plus par instance, sur potentiellement des dizaines de milliers
	-- d'instances) pour un signal quasi jamais porteur d'une valeur
	-- numerique (les tags sont categoriels, pas des montants).
	local function extra(child)
		local extras = {}
		if VALUE_CLASSES[child.ClassName] then
			local ok, v = pcall(function() return child.Value end)
			if ok then extras[#extras+1] = "value="..fmtLeaf(v) end
		end
		local okA, attrs = pcall(function() return child:GetAttributes() end)
		if okA and next(attrs) then
			local parts = {}
			for k, v in pairs(attrs) do
				parts[#parts+1] = k.."="..fmtLeaf(v)
				if isFlagKey(k) then flagged[#flagged+1] = {path="Attribute."..child:GetFullName().."."..k, value=fmtLeaf(v)} end
			end
			extras[#extras+1] = "attrs{"..table.concat(parts, ", ").."}"
		end
		if #extras == 0 then return "" end
		return "  <"..table.concat(extras, " | ")..">"
	end

	local function walk(inst, depth, prefix)
		for _, child in ipairs(inst:GetChildren()) do
			if #lines >= MAX_TREE_LINES then truncated = true; return end
			local sub = #child:GetChildren()
			lines[#lines+1] = string.format("%s%s (%s)%s%s", prefix, child.Name, child.ClassName,
				sub > 0 and string.format(" — %d enfant(s)", sub) or "", extra(child))
			classTally[child.ClassName] = (classTally[child.ClassName] or 0) + 1
			-- Une map peut avoir des dizaines de milliers d'instances: sans
			-- pause, ce parcours recursif tourne d'un bloc et gele le jeu.
			if #lines % 300 == 0 then task.wait() end
			if sub > 0 and depth < MAX_TREE_DEPTH then walk(child, depth + 1, prefix.."  ") end
		end
	end
	pcall(function()
		for _, child in ipairs(workspace:GetChildren()) do
			local sub = #child:GetChildren()
			lines[#lines+1] = string.format("%s (%s)%s%s", child.Name, child.ClassName,
				sub > 0 and string.format(" — %d enfant(s)", sub) or "", extra(child))
			classTally[child.ClassName] = (classTally[child.ClassName] or 0) + 1
			if sub > 0 then walk(child, 1, "  ") end
		end
	end)
	local body = "Arbre workspace COMPLET (aucun niveau ni dossier saute; "
		.."<value=/attrs{}/tags[]> quand presents):\n"..table.concat(lines, "\n")
	if truncated then
		body = body..string.format("\n... (garde-fou %d lignes atteint, map exceptionnellement massive)", MAX_TREE_LINES)
	end

	local tallyLines = {}
	for cn, n in pairs(classTally) do tallyLines[#tallyLines+1] = string.format("  %s: %d", cn, n) end
	table.sort(tallyLines)
	body = body.."\n\nRepartition par ClassName:\n"..table.concat(tallyLines, "\n")

	body = body.."\n\nleaderstats — TOUS les joueurs presents (dossier public):\n"
	local anyLs = false
	pcall(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			local ls = plr:FindFirstChild("leaderstats")
			if ls then
				anyLs = true
				body = body.."  ["..plr.Name.."]\n"
				for _, v in ipairs(ls:GetChildren()) do
					body = body..string.format("    %s = %s\n", v.Name, tostring(v.Value))
					if isFlagKey(v.Name) then flagged[#flagged+1] = {path="leaderstats."..plr.Name.."."..v.Name, value=tostring(v.Value)} end
				end
			end
		end
	end)
	if not anyLs then body = body.."  (aucun joueur present n'a de leaderstats)" end
	addSection("D. Catalogue map COMPLET (+ValueBase/attrs) + leaderstats", body)
end

-- ============================================================
-- SECTION E — meme arbre enrichi (ValueBase/.Value + attributs) que
-- la Section D, mais sur ReplicatedStorage au lieu du workspace:
-- l'autre grand conteneur de donnees statiques
-- d'un jeu Roblox (Configuration/Folder avec attributs, en dehors de
-- tout ModuleScript deja couvert par la Section C).
-- ============================================================
setStatus("Section E: ReplicatedStorage...")
do
	local VALUE_CLASSES = {
		IntValue=true, NumberValue=true, StringValue=true, BoolValue=true,
		ObjectValue=true, Vector3Value=true, CFrameValue=true, Color3Value=true,
	}
	local MAX_TREE_DEPTH, MAX_TREE_LINES = 80, 150000
	local lines = {}
	local truncated = false

	-- CollectionService:GetTags() retire ici aussi, meme raison que D.
	local function extra(child)
		local extras = {}
		if VALUE_CLASSES[child.ClassName] then
			local ok, v = pcall(function() return child.Value end)
			if ok then extras[#extras+1] = "value="..fmtLeaf(v) end
		end
		local okA, attrs = pcall(function() return child:GetAttributes() end)
		if okA and next(attrs) then
			local parts = {}
			for k, v in pairs(attrs) do
				parts[#parts+1] = k.."="..fmtLeaf(v)
				if isFlagKey(k) then flagged[#flagged+1] = {path="Attribute."..child:GetFullName().."."..k, value=fmtLeaf(v)} end
			end
			extras[#extras+1] = "attrs{"..table.concat(parts, ", ").."}"
		end
		if #extras == 0 then return "" end
		return "  <"..table.concat(extras, " | ")..">"
	end

	local function walk(inst, depth, prefix)
		for _, child in ipairs(inst:GetChildren()) do
			if #lines >= MAX_TREE_LINES then truncated = true; return end
			-- ModuleScript deja integralement dump en Section C — ici on
			-- note juste sa presence pour ne pas dupliquer un contenu deja
			-- affiche ailleurs dans le meme rapport.
			local tag = child:IsA("ModuleScript") and "  (dump complet: voir Section C)" or extra(child)
			local sub = #child:GetChildren()
			lines[#lines+1] = string.format("%s%s (%s)%s%s", prefix, child.Name, child.ClassName,
				sub > 0 and string.format(" — %d enfant(s)", sub) or "", tag)
			if #lines % 300 == 0 then task.wait() end
			if sub > 0 and depth < MAX_TREE_DEPTH then walk(child, depth + 1, prefix.."  ") end
		end
	end
	pcall(function() walk(ReplicatedStorage, 0, "") end)
	local body = "Arbre ReplicatedStorage COMPLET (aucun niveau ni dossier saute; "
		.."<value=/attrs{}/tags[]> quand presents):\n"..table.concat(lines, "\n")
	if truncated then
		body = body..string.format("\n... (garde-fou %d lignes atteint)", MAX_TREE_LINES)
	end
	addSection("E. Catalogue ReplicatedStorage COMPLET (+ValueBase/attrs)", body)
end

-- ============================================================
-- SECTION F — inventaire COMPLET des remotes (Packages.Networking),
-- groupes par famille (le prefixe avant le 2e "/"). Donne la carte
-- complete de la surface reseau du jeu, pas seulement EggWorld —
-- utile pour reperer d'autres systemes lies a la valeur (Shop,
-- Market, Inventory, PetIndex, ...).
-- ============================================================
setStatus("Section F...")
do
	local body
	if not NetFolder then
		body = "Packages.Networking introuvable — le jeu utilise peut-etre "
			.."un autre systeme de remotes."
	else
		local families = {}
		local total = 0
		for _, inst in ipairs(NetFolder:GetChildren()) do
			total = total + 1
			local fam = inst.Name:match("^([^/]+/[^/]+)/") or inst.Name:match("^([^/]+)/") or "?"
			families[fam] = families[fam] or {}
			table.insert(families[fam], string.format("%s [%s]", inst.Name, inst.ClassName))
		end
		local famNames = {}
		for fam in pairs(families) do famNames[#famNames+1] = fam end
		table.sort(famNames)
		local lines = {string.format("%d remote(s) au total, %d famille(s):", total, #famNames)}
		for _, fam in ipairs(famNames) do
			lines[#lines+1] = "\n"..fam..":"
			for _, entry in ipairs(families[fam]) do lines[#lines+1] = "  "..entry end
		end
		body = table.concat(lines, "\n")
	end
	addSection("F. Inventaire complet des remotes (Networking)", body)
end

-- ============================================================
-- SECTION G — attributs poses directement sur chaque objet Player
-- (pas son Character, deja couvert par l'arbre D — le Player lui-meme,
-- un motif reel pour des donnees "best value" par joueur). Retour
-- arriere volontaire: la version precedente parcourait EN PLUS
-- Lighting/Teams/SoundService/Chat/Starter*/PlayerGui/PlayerScripts/
-- Backpack en entier avec attributs+tags sur chaque instance — cout
-- reel (PlayerGui peut avoir des milliers de descendants) pour une
-- zone quasi jamais porteuse de donnees egg/pet (PlayerGui est deja
-- couvert plus efficacement par le scan textuel cible de la Section
-- H). Coupe pour rester rapide: cout ici = O(nombre de joueurs), donc
-- negligeable.
-- ============================================================
setStatus("Section G: joueurs...")
do
	local lines = {}
	pcall(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			local okA, attrs = pcall(function() return plr:GetAttributes() end)
			if okA and next(attrs) then
				local parts = {}
				for k, v in pairs(attrs) do
					parts[#parts+1] = k.."="..fmtLeaf(v)
					if isFlagKey(k) or looksLikeMoney(v) then
						flagged[#flagged+1] = {path="Attribute.Player."..plr.Name.."."..k, value=fmtLeaf(v)}
					end
				end
				lines[#lines+1] = "  ["..plr.Name.."] "..table.concat(parts, ", ")
			end
		end
	end)
	local body = #lines > 0 and table.concat(lines, "\n")
		or "(aucun joueur present n'a d'attributs)"
	addSection("G. Attributs des objets Player", body)
end

-- ============================================================
-- SECTION H — scan textuel de TOUTE l'interface (PlayerGui, et
-- CoreGui si accessible): tout GuiObject dont la propriete .Text
-- RESSEMBLE a un montant ("26.77M", "1,234", "$500", ...). C'est la
-- source la plus directe qui soit: LENNON HUB affiche litteralement
-- "26.77M" quelque part dans son interface — si CE jeu calcule et
-- affiche deja une valeur d'oeuf/pet cote client (ce qui est presque
-- certain, sinon rien n'apparaitrait a l'ecran), le TextLabel qui la
-- contient est ici, avec son chemin complet pour la retrouver en jeu.
-- ============================================================
setStatus("Section H: texte UI...")
do
	local roots = {}
	pcall(function() if LP:FindFirstChild("PlayerGui") then roots[#roots+1] = LP.PlayerGui end end)
	pcall(function() roots[#roots+1] = game:GetService("CoreGui") end)

	local hits = {}
	for _, root in ipairs(roots) do
		pcall(function()
			for i2, inst in ipairs(root:GetDescendants()) do
				if (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox"))
					and inst.Text ~= "" and looksLikeMoney(inst.Text) then
					hits[#hits+1] = string.format("%s = %q", inst:GetFullName(), inst.Text)
					flagged[#flagged+1] = {path="UI-Text."..inst:GetFullName(), value=inst.Text}
				end
				if i2 % 1000 == 0 then task.wait() end
			end
		end)
	end
	local body
	if #hits == 0 then
		body = "Aucun texte d'interface ne ressemble a un montant sur l'instant T "
			.."(la fenetre de ce scan n'affiche peut-etre pas encore l'ecran "
			.."concerne — p.ex. si le panneau 'Best Egg' du jeu n'est pas ouvert "
			.."au moment du scan). Relancer avec le bon panneau ouvert si "
			.."pertinent."
	else
		body = string.format("%d texte(s) ressemblant a un montant:\n", #hits)..table.concat(hits, "\n")
	end
	addSection("H. Scan textuel UI (valeurs deja affichees a l'ecran)", body)
end

-- ============================================================
-- SECTION B — capture live de RE/EggWorld/FieldEggShifted, JUSQU'A
-- LIVE_CAPTURE_EARLY evenements captures (sortie anticipee des que
-- LIVE_CAPTURE_MIN s sont passees ET qu'on a assez d'echantillons —
-- pas la peine d'attendre le plafond si le jeu spawn des oeufs
-- souvent), sinon plafond dur a LIVE_CAPTURE_DURATION s si peu/rien
-- ne se passe. C'est la SEULE section a duree fixe du scan (toutes
-- les autres ne dependent que de la taille du jeu) — cette sortie
-- anticipee est le levier le plus direct pour aller plus vite sur un
-- jeu actif, sans rien perdre niveau donnees.
-- ============================================================
do
	local re = getRemote("RE/EggWorld/FieldEggShifted")
	local captured = {}
	local conn
	if re and re:IsA("RemoteEvent") then
		conn = re.OnClientEvent:Connect(function(a1, a2)
			if #captured >= 2000 then return end  -- garde-fou memoire, pas une limite intentionnelle
			local data = (type(a2) == "table" and a2) or (type(a1) == "table" and a1) or nil
			if data then captured[#captured+1] = data end
		end)
	end

	local t0 = os.clock()
	while true do
		local elapsed = os.clock() - t0
		if elapsed >= LIVE_CAPTURE_DURATION then break end
		if elapsed >= LIVE_CAPTURE_MIN and #captured >= LIVE_CAPTURE_EARLY then break end
		setStatus(string.format("Ecoute live... %ds/%ds (%d captures)",
			math.floor(elapsed), LIVE_CAPTURE_DURATION, #captured))
		task.wait(1)
	end
	if conn then conn:Disconnect() end

	local body
	if not re then
		body = "Remote RE/EggWorld/FieldEggShifted introuvable."
	elseif #captured == 0 then
		body = "Aucun evenement recu en "..LIVE_CAPTURE_DURATION.."s "
			.."(normal si aucun oeuf n'est apparu pendant l'ecoute)."
	else
		body = string.format("%d evenement(s) captures.\n", #captured)
		for i, data in ipairs(captured) do
			body = body.."\n--- event "..i.." ---\n"..dumpRoot("data"..i, data)
		end
	end
	addSection("B. FieldEggShifted — capture live", body)
end

-- ============================================================
-- RAPPORT FINAL — champs suspects (nom evoquant une valeur) en tete,
-- pour aller droit a l'essentiel avant le detail complet.
-- ============================================================
setStatus("Termine")
do
	local head = {}
	head[#head+1] = ""
	head[#head+1] = "================================================"
	head[#head+1] = "  CHAMPS SUSPECTS (nom evoquant une valeur/prix)"
	head[#head+1] = "================================================"
	if #flagged == 0 then
		head[#head+1] = "Aucun champ dont le NOM contient value/price/worth/"
		head[#head+1] = "money/cash/coin/reward/sell/cost/gem/point n'a ete"
		head[#head+1] = "trouve dans tout ce qui a ete scanne."
		head[#head+1] = "=> Soit ce jeu ne renvoie jamais de valeur cote client"
		head[#head+1] = "   (calculee uniquement serveur), soit elle est"
		head[#head+1] = "   nommee autrement — a verifier dans le dump complet"
		head[#head+1] = "   ci-dessous (sections A a F)."
	else
		for _, f in ipairs(flagged) do
			head[#head+1] = string.format("  %s = %s", f.path, f.value)
		end
	end
	table.insert(report, 1, table.concat(head, "\n"))
end

log("=== RAPPORT COMPLET ===")
for _, line in ipairs(report) do
	for l2 in (line.."\n"):gmatch("(.-)\n") do
		if l2 ~= "" then print(l2) end
	end
end
_scanRunning = false  -- arrete le ticker de statut, le scan est termine
log(string.format("=== FIN — %.1fs ecoulees au total ===", os.clock() - _scanStart))

local fullReport = table.concat(report, "\n")
local function copyToClipboard(text)
	if type(setclipboard) == "function" then return pcall(setclipboard, text) end
	if type(toclipboard) == "function" then return pcall(toclipboard, text) end
	return false
end

if ui.copyBtn then
	ui.copyBtn.MouseButton1Click:Connect(function()
		local ok = copyToClipboard(fullReport)
		ui.copyBtn.Text = ok and "Copie !" or "Copie indisponible"
		task.delay(1.5, function()
			pcall(function() ui.copyBtn.Text = "Copier les resultats" end)
		end)
	end)
end
