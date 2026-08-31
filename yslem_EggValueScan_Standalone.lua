--[[
	yslem_EggValueScan_Standalone.lua
	================================================================
	Objectif : savoir si CE jeu expose une "valeur" d'œuf (prix/worth,
	comme "Snowy Owl — 26.77M" vu dans LENNON HUB, avec un toggle
	"Teleguiado" qui vise toujours l'œuf le plus cher). yslemEgg.lua
	ne lit aujourd'hui QUE Mutation/NestScale/Zone/CFrame dans les
	payloads FieldEggShifted / AskFieldEggSnapshot — tout autre champ
	(Value/Price/Worth/Species/...) est actuellement ignoré en
	silence. Ce script dump TOUT le contenu brut (toutes les clefs)
	pour voir ce qui existe réellement, avant d'aller construire une
	fonctionnalité "Best Egg" sur une supposition.

	100% lecture seule : aucun hook ne bloque ni ne modifie quoi que
	ce soit. On écoute, on Invoke (lecture), on require() des
	ModuleScripts de données (lecture de leur table retournée). Aucune
	action gameplay.

	Auto-run, auto-stop. Résultats dans une fenêtre en jeu (3 sections
	scrollables) + dump complet dans la console + bouton "Copier".
	================================================================
]]

local Players           = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local LIVE_CAPTURE_DURATION = 15   -- secondes d'écoute FieldEggShifted

local function log(...) print("[EGGSCAN]", ...) end
log("=== DEBUT EggValueScan ===")

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

local MAX_DEPTH, MAX_ITEMS = 3, 30
local function dumpTable(t, path, depth, lines)
	local n = 0
	for k, v in pairs(t) do
		n = n + 1
		if n > MAX_ITEMS then
			lines[#lines+1] = string.rep("  ", depth).."... (plus d'entrees, tronque)"
			break
		end
		local ks   = tostring(k)
		local kpath = path.."."..ks
		if typeof(v) == "table" then
			if depth >= MAX_DEPTH then
				lines[#lines+1] = string.rep("  ", depth)..ks.." = { ... (profondeur max) }"
			else
				lines[#lines+1] = string.rep("  ", depth)..ks.." = {"
				dumpTable(v, kpath, depth+1, lines)
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
	if n == 0 then
		lines[#lines+1] = string.rep("  ", depth).."(table vide)"
	end
end

local function dumpRoot(label, t)
	local lines = {}
	local ok = pcall(dumpTable, t, label, 1, lines)
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
		title.Text = "Egg Value Scan"
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
setStatus("Section A/D...")
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
			body = body.."\n\nDump complet des 3 premieres entrees:\n"
			for i = 1, math.min(3, #entries) do
				body = body..dumpRoot("entry"..i, entries[i]).."\n"
			end
			addSection("A. AskFieldEggSnapshot", body)
		end
	end
end

-- ============================================================
-- SECTION C — scan des ModuleScript de donnees dans ReplicatedStorage.
-- Filtre: nom contenant ("egg" ou "pet") ET un mot-clef valeur/config,
-- sans mot-clef "controller/manager/service/handler/system/network"
-- (evite de require() des modules actifs, on cible les tables statiques).
-- ============================================================
setStatus("Section C...")
do
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
	pcall(function()
		for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
			if inst:IsA("ModuleScript") and matches(inst.Name) then
				candidates[#candidates+1] = inst
			end
		end
	end)

	local body = string.format("%d ModuleScript(s) candidat(s) trouve(s).\n", #candidates)
	if #candidates == 0 then
		body = body.."Aucun module dont le nom evoque une table de valeurs "
			.."(egg/pet + value/price/worth/data/config/rarity/mutation).\n"
			.."Le jeu utilise peut-etre un autre nommage, ou les valeurs "
			.."sont calculees cote serveur uniquement (jamais envoyees au client)."
	else
		for _, mod in ipairs(candidates) do
			body = body.."\n--- "..mod:GetFullName().." ---\n"
			local ok, result = pcall(require, mod)
			if not ok then
				body = body.."  require() a echoue: "..tostring(result).."\n"
			elseif type(result) ~= "table" then
				body = body.."  retourne un "..typeof(result)..", pas une table: "..fmtLeaf(result).."\n"
			else
				body = body..dumpRoot(mod.Name, result).."\n"
			end
		end
	end
	addSection("C. ModuleScripts de donnees (ReplicatedStorage)", body)
end

-- ============================================================
-- SECTION D — catalogue rapide de la map (2 niveaux) + leaderstats
-- du joueur (souvent le seul endroit ou une "valeur" en $/points
-- apparait deja formatee, ce qui confirme si le jeu a un concept
-- de valeur monetaire du tout).
-- ============================================================
do
	local lines = {}
	pcall(function()
		for _, child in ipairs(workspace:GetChildren()) do
			local sub = 0
			for _, gc in ipairs(child:GetChildren()) do sub = sub + 1 end
			lines[#lines+1] = string.format("%s (%s) — %d enfant(s)", child.Name, child.ClassName, sub)
		end
	end)
	local body = table.concat(lines, "\n")

	local ls = LP:FindFirstChild("leaderstats")
	if ls then
		body = body.."\n\nleaderstats du joueur:\n"
		for _, v in ipairs(ls:GetChildren()) do
			body = body..string.format("  %s = %s\n", v.Name, tostring(v.Value))
		end
	else
		body = body.."\n\n(pas de leaderstats trouve sur le joueur)"
	end
	addSection("D. Catalogue map + leaderstats", body)
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
			if #captured >= 6 then return end
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
