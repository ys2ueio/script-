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

	Auto-run, auto-stop apres ~40s. Résultats dans une fenêtre en jeu
	(5 sections scrollables) + dump complet dans la console + bouton
	"Copier" — un seul rapport consolidé, a coller integralement.
	================================================================
]]

local Players           = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local LIVE_CAPTURE_DURATION = 40   -- secondes d'écoute FieldEggShifted

local function log(...) print("[EGGSCAN]", ...) end
log("=== DEBUT Analyse complete (40s) ===")

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

-- Caps volontairement larges — "scanner tout" prime sur la lisibilite.
-- MAX_DEPTH/MAX_ITEMS restent en dernier recours anti-crash (stack
-- overflow / rapport de plusieurs dizaines de Mo), pas des filtres de
-- contenu : la detection de cycle (visited) est ce qui protege
-- vraiment contre une table auto-referentielle (OOP a la
-- Roblox, __index vers elle-meme, etc.) — sans elle, un cycle a
-- N'IMPORTE quelle profondeur boucle a l'infini.
local MAX_DEPTH, MAX_ITEMS = 12, 500
local function dumpTable(t, path, depth, lines, visited)
	if visited[t] then
		lines[#lines+1] = string.rep("  ", depth).."<cycle: deja visite plus haut>"
		return
	end
	visited[t] = true
	local n = 0
	for k, v in pairs(t) do
		n = n + 1
		if n > MAX_ITEMS then
			lines[#lines+1] = string.rep("  ", depth)..string.format("... (+%d entrees restantes, tronque)", 0)
			break
		end
		local ks   = tostring(k)
		local kpath = path.."."..ks
		if typeof(v) == "table" then
			if depth >= MAX_DEPTH then
				lines[#lines+1] = string.rep("  ", depth)..ks.." = { ... (profondeur max "..MAX_DEPTH..") }"
			else
				lines[#lines+1] = string.rep("  ", depth)..ks.." = {"
				dumpTable(v, kpath, depth+1, lines, visited)
				lines[#lines+1] = string.rep("  ", depth).."}"
			end
		else
			local leaf = fmtLeaf(v)
			lines[#lines+1] = string.rep("  ", depth)..ks.." = "..leaf
			if isFlagKey(ks) then
				flagged[#flagged+1] = {path=kpath, value=leaf}
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
		title.Text = "Analyse complete (40s)"
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

local function setStatus(s)
	if ui.status then pcall(function() ui.status.Text = s end) end
end

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
			body = body..string.format("\n\nDump complet des %d entree(s) (TOUTES, pas un echantillon):\n", #entries)
			for i = 1, #entries do
				body = body..dumpRoot("entry"..i, entries[i]).."\n"
			end
			addSection("A. AskFieldEggSnapshot", body)
		end
	end
end

-- ============================================================
-- SECTION C — TOUS les ModuleScript, sans filtre par nom, dans TOUS
-- les conteneurs accessibles cote client (ReplicatedStorage,
-- ReplicatedFirst, StarterGui, StarterPack, Lighting, workspace —
-- ServerScriptService/ServerStorage sont invisibles au client, ce
-- n'est pas un choix mais une limite Roblox). Chaque module est
-- require() (protege par timeout, voir requireWithTimeout) et son
-- contenu integralement dump — plus de filtre "egg/pet + value/...":
-- si un module ne matche aucun mot-clef mais contient bien une table
-- de valeurs sous un nom auquel on n'a pas pense, ce scan le trouve
-- quand meme.
-- ============================================================
setStatus("Section C: modules...")
do
	local CONTAINERS = {
		ReplicatedStorage, game:GetService("ReplicatedFirst"),
		game:GetService("StarterGui"), game:GetService("StarterPack"),
		game:GetService("Lighting"), workspace,
	}
	local allMods, seen = {}, {}
	for _, root in ipairs(CONTAINERS) do
		pcall(function()
			for _, inst in ipairs(root:GetDescendants()) do
				if inst:IsA("ModuleScript") and not seen[inst] then
					seen[inst] = true
					allMods[#allMods+1] = inst
				end
			end
		end)
	end

	local body = string.format("%d ModuleScript(s) au total (tous conteneurs client confondus).\n"
		.."require() + dump integral de CHAQUE module ci-dessous "
		.."(timeout 0.3s par module si un chargement bloque).\n", #allMods)
	local nOk, nErr, nTimeout, nNonTable = 0, 0, 0, 0
	for i, mod in ipairs(allMods) do
		setStatus(string.format("Section C: modules %d/%d", i, #allMods))
		body = body.."\n--- "..mod:GetFullName().." ---\n"
		local ok, result = requireWithTimeout(mod, 0.3)
		if not ok then
			local msg = tostring(result)
			if msg:find("timeout", 1, true) then nTimeout = nTimeout + 1 else nErr = nErr + 1 end
			body = body.."  echec: "..msg.."\n"
		elseif type(result) ~= "table" then
			nNonTable = nNonTable + 1
			body = body.."  retourne un "..typeof(result)..", pas une table: "..fmtLeaf(result).."\n"
		else
			nOk = nOk + 1
			body = body..dumpRoot(mod.Name, result).."\n"
		end
	end
	body = body..string.format(
		"\nResume: %d dumpes en table, %d non-table, %d en erreur, %d en timeout (sur %d).",
		nOk, nNonTable, nErr, nTimeout, #allMods)
	addSection("C. TOUS les ModuleScripts (dump integral)", body)
end

-- ============================================================
-- SECTION D — arbre COMPLET du workspace, tout niveau, tout dossier
-- (plus de plafond "3 niveaux" ni de saut des dossiers >60 enfants —
-- "tout" veut dire tout). MAX_TREE_DEPTH n'est qu'un garde-fou anti-
-- stack-overflow (aucune hierarchie Roblox reelle n'atteint 60
-- niveaux), pas un filtre de contenu ; MAX_TREE_LINES est un garde-
-- fou de derniere ligne contre un rapport de plusieurs dizaines de
-- Mo si la map est extraordinairement massive.
-- Tally des ClassName rencontres + leaderstats du joueur (souvent le
-- seul endroit ou une "valeur" en $/points apparait deja formatee).
-- ============================================================
setStatus("Section D: map...")
do
	local MAX_TREE_DEPTH, MAX_TREE_LINES = 60, 50000
	local lines = {}
	local classTally = {}
	local truncated = false
	local function walk(inst, depth, prefix)
		for _, child in ipairs(inst:GetChildren()) do
			if #lines >= MAX_TREE_LINES then truncated = true; return end
			local sub = #child:GetChildren()
			lines[#lines+1] = string.format("%s%s (%s)%s", prefix, child.Name, child.ClassName,
				sub > 0 and string.format(" — %d enfant(s)", sub) or "")
			classTally[child.ClassName] = (classTally[child.ClassName] or 0) + 1
			if sub > 0 and depth < MAX_TREE_DEPTH then walk(child, depth + 1, prefix.."  ") end
		end
	end
	pcall(function()
		for _, child in ipairs(workspace:GetChildren()) do
			local sub = #child:GetChildren()
			lines[#lines+1] = string.format("%s (%s)%s", child.Name, child.ClassName,
				sub > 0 and string.format(" — %d enfant(s)", sub) or "")
			classTally[child.ClassName] = (classTally[child.ClassName] or 0) + 1
			if sub > 0 then walk(child, 1, "  ") end
		end
	end)
	local body = "Arbre workspace COMPLET (aucun niveau ni dossier saute):\n"
		..table.concat(lines, "\n")
	if truncated then
		body = body..string.format("\n... (garde-fou %d lignes atteint, map exceptionnellement massive)", MAX_TREE_LINES)
	end

	local tallyLines = {}
	for cn, n in pairs(classTally) do tallyLines[#tallyLines+1] = string.format("  %s: %d", cn, n) end
	table.sort(tallyLines)
	body = body.."\n\nRepartition par ClassName:\n"..table.concat(tallyLines, "\n")

	local ls = LP:FindFirstChild("leaderstats")
	if ls then
		body = body.."\n\nleaderstats du joueur:\n"
		for _, v in ipairs(ls:GetChildren()) do
			body = body..string.format("  %s = %s\n", v.Name, tostring(v.Value))
		end
	else
		body = body.."\n\n(pas de leaderstats trouve sur le joueur)"
	end
	addSection("D. Catalogue map COMPLET + leaderstats", body)
end

-- ============================================================
-- SECTION E — inventaire COMPLET des remotes (Packages.Networking),
-- groupes par famille (le prefixe avant le 2e "/"). Donne la carte
-- complete de la surface reseau du jeu, pas seulement EggWorld —
-- utile pour reperer d'autres systemes lies a la valeur (Shop,
-- Market, Inventory, PetIndex, ...).
-- ============================================================
setStatus("Section E...")
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
	addSection("E. Inventaire complet des remotes (Networking)", body)
end

-- ============================================================
-- SECTION B — capture live de RE/EggWorld/FieldEggShifted pendant
-- LIVE_CAPTURE_DURATION s. Dump BRUT (toutes les clefs) des premiers
-- evenements distincts — complementaire au snapshot: certains champs
-- (ex: Value calculee a l'apparition) peuvent n'exister QUE dans
-- l'evenement de spawn, pas dans le snapshot.
-- ============================================================
setStatus("Ecoute live... "..LIVE_CAPTURE_DURATION.."s")
do
	local re = getRemote("RE/EggWorld/FieldEggShifted")
	local captured = {}
	local conn
	if re and re:IsA("RemoteEvent") then
		conn = re.OnClientEvent:Connect(function(a1, a2)
			if #captured >= 500 then return end  -- garde-fou memoire, pas une limite intentionnelle
			local data = (type(a2) == "table" and a2) or (type(a1) == "table" and a1) or nil
			if data then captured[#captured+1] = data end
		end)
	end

	local t0 = os.clock()
	while os.clock() - t0 < LIVE_CAPTURE_DURATION do
		task.wait(1)
		setStatus(string.format("Ecoute live... %ds", LIVE_CAPTURE_DURATION - math.floor(os.clock()-t0)))
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
		head[#head+1] = "   ci-dessous (sections A/B/C)."
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
log("=== FIN ===")

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
