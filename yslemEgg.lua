-- ============================================================
-- yslemEgg — Auto Farm Hub
-- UI: Moon Hub style (black + blue accent)
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
local LP                 = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

-- ============================================================
-- MODULES DU JEU (Steal An Egg) — chemins tentés d'après la source
-- originale du jeu (Toolbox Hub) ET le rapport d'analyse yslemEgg.
-- [FIX] Chaque require() a maintenant SON PROPRE pcall — la version
-- précédente les empilait tous dans UN SEUL pcall englobant : si le
-- tout premier chemin (EggCmds) était faux, l'erreur coupait la
-- fonction net et TOUS les require() suivants (Network, Save, Bases,
-- Treadmills, Trails...) ne s'exécutaient jamais, même corrects —
-- une seule mauvaise entrée tuait silencieusement 10+ features d'un
-- coup. C'est très probablement la cause du "trop de feature marche
-- mal". _ModuleStatus enregistre individuellement ce qui a chargé ou
-- non, affiché en tête de l'onglet Farm — plus de panne invisible.
-- ============================================================
local EggCmds, Ragdoll, Network, NM, PlotCmds, GEP, GCP, RGSR, SPP, GuardsD, AreasD, SlotId
local Save, Constants, Bases, Treadmills, Trails
local PlotsNet, TreadmillsNet, TrailsNet

-- [FIX] L'ancienne version devinait le CHEMIN complet (Library.Client.X,
-- Directory.Y...) copié de la source d'origine — si le jeu a réorganisé
-- ses dossiers depuis, aucun de ces chemins ne matche même si le
-- ModuleScript existe toujours ailleurs. Nouvelle approche : une seule
-- passe sur TOUT ReplicatedStorage:GetDescendants(), indexée par NOM de
-- ModuleScript — peu importe où il vit réellement. Bien plus robuste
-- qu'un chemin figé, et ça ne coûte qu'un seul scan (pas 16).
local _moduleIndex = {}  -- nom exact -> première instance ModuleScript trouvée
for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
	if inst:IsA("ModuleScript") and not _moduleIndex[inst.Name] then
		_moduleIndex[inst.Name] = inst
	end
end

local _ModuleStatus = {}    -- nom -> true/false (chargé avec succès)
local _ModuleFound  = {}    -- nom -> chemin complet où il a été trouvé (ou nil)
local function _tryRequire(name)
	local inst = _moduleIndex[name]
	_ModuleFound[name] = inst and inst:GetFullName() or nil
	if not inst then
		_ModuleStatus[name] = false
		return nil
	end
	local ok, result = pcall(require, inst)
	_ModuleStatus[name] = ok and result ~= nil
	if ok then return result end
	return nil
end

EggCmds    = _tryRequire("EggCmds")
Ragdoll    = _tryRequire("Ragdoll")
Network    = _tryRequire("Network")
NM         = Network and Network.NET_MAP
PlotCmds   = _tryRequire("PlotCmds")
GEP        = _tryRequire("GuardEscapePrediction")
GCP        = _tryRequire("GuardChasePolicy")
RGSR       = _tryRequire("ResolveGuardSpeedRequirement")
SPP        = _tryRequire("SpeedPowerProjection")
GuardsD    = _tryRequire("Guards")
AreasD     = _tryRequire("Areas")
SlotId     = _tryRequire("AreaEggSlotIdentity")

Save       = _tryRequire("Save")
Constants  = _tryRequire("Constants")
Bases      = _tryRequire("Bases")
Treadmills = _tryRequire("Treadmills")
Trails     = _tryRequire("Trails")

PlotsNet      = Constants and Constants.NETWORK_MAP and Constants.NETWORK_MAP.Plots
TreadmillsNet = Constants and Constants.NETWORK_MAP and Constants.NETWORK_MAP.Treadmills
TrailsNet     = Constants and Constants.NETWORK_MAP and Constants.NETWORK_MAP.Trails

-- Print immédiat en console (F9), sans dépendre de l'UI/du scroll.
-- Distingue maintenant 2 échecs différents :
--  - INTROUVABLE : aucun ModuleScript de ce nom nulle part dans
--    ReplicatedStorage (renommé, déplacé hors RS, ou jamais existé
--    sous ce nom dans ce jeu).
--  - ECHEC : trouvé (chemin affiché) mais require() a levé une
--    erreur — utile pour distinguer "n'existe pas" de "existe mais
--    plante à l'exécution".
do
	local lines = {"[yslemEgg] Statut des modules du jeu :"}
	for _, name in ipairs({"EggCmds","Network","Ragdoll","PlotCmds","GuardEscapePrediction","GuardChasePolicy","ResolveGuardSpeedRequirement","SpeedPowerProjection","Guards","Areas","AreaEggSlotIdentity","Save","Constants","Bases","Treadmills","Trails"}) do
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

-- ── ZONES GARDÉES : Speed Power requis par zone ─────────────
-- Reproduit le calcul du jeu lui-même (RGSR = ResolveGuardSpeedRequirement)
-- pour savoir si une zone (Forest/Desert/Prehistoric/...) est
-- franchissable sans se faire rattraper par son garde, selon la Speed
-- Power actuelle du joueur. Alimente Auto Farm (cible "Best Unlocked")
-- et Egg ESP (couleur verte/rouge locked-unlocked).
local EXIT_DIR = Vector3.new(-1,0,0)
local AREA = {}
pcall(function()
	EXIT_DIR = -workspace.__OBJECTS.Areas.SeparationLine.CFrame.LookVector
end)
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
					hit = GCP.ResolveHitDistance(d.HitDistance),
					reqSP = nil,
				}
				if GEP and RGSR then
					pcall(function()
						local exitPos = a.ClosestExitPoint.Position
						rec.reqSP = RGSR({
							BaseGuardWalkSpeed = rec.speed,
							ExitDirection = EXIT_DIR,
							ExitDistance = GEP.ResolveExitDistance(rec.cf, rec.size, exitPos, EXIT_DIR),
							FlatRadius = rec.radius,
							GuardStartPosition = rec.guardPos,
							HitDistance = rec.hit,
							PlayerStartPosition = exitPos,
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

-- ── SCAN D'ŒUFS EN DIRECT ────────────────────────────────────
-- [FIX] L'ancienne version dépendait d'abord de EggCmds.GetAreaEggSnapshot
-- (module ReplicatedStorage.Library.Client.EggCmds) — si ce module ne
-- charge pas dans ce jeu (voir diagnostic 'Modules: X/Y' de l'onglet
-- Farm), cette source ne donnait RIEN, et le repli ne captait que les
-- œufs tombés au sol avec un mot-clé précis. Nouvelle approche, 100%
-- indépendante de tout module client : `workspace.AreaEggSlotsClient`
-- est un dossier CONFIRMÉ réel par le rapport d'analyse (789
-- descendants) — son nom même indique qu'il contient les slots d'œufs
-- par zone rendus au client. Chaque ProximityPrompt qu'il contient est
-- présumé être un œuf, sans avoir besoin de deviner un mot-clé.
-- En plus de la position, on lit directement le TEXTE déjà affiché à
-- l'écran (BillboardGui/SurfaceGui/TextLabel du même Model) pour en
-- extraire mutation et poids — ce que le jeu montre au joueur, donc
-- toujours exact, jamais une donnée recalculée à la main.
local _RARE_KEYWORDS = {
	"secret","eternal","divine","divin","mythic","celestial","ancient",
	"rainbow","golden","shiny","radiant","corrupted","void","legendary",
}

-- Cherche tout TextLabel (BillboardGui/SurfaceGui) sous `root` et
-- renvoie le texte concaténé + les tags de rareté/mutation trouvés
-- dedans + un poids en kg si présent (ex: "2.4 kg", "150kg").
local function _readEggLabels(root)
	local texts = {}
	pcall(function()
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("TextLabel") and d.Text ~= "" then
				table.insert(texts, d.Text)
			end
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

-- Remonte de prompt.Parent jusqu'au premier Model ancêtre (là où vivent
-- généralement les BillboardGui d'un spawn d'œuf) ; à défaut utilise
-- directement la Part porteuse du prompt.
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

local cachedEggs = {}
task.spawn(function()
	while true do
		local eggs = {}
		local slotsRoot = workspace:FindFirstChild("AreaEggSlotsClient")

		if slotsRoot then
			pcall(function()
				for _, prompt in ipairs(slotsRoot:GetDescendants()) do
					if prompt:IsA("ProximityPrompt") and prompt.Enabled then
						local part, model = _promptOwnerModel(prompt)
						if part then
							local full, tags, weight = _readEggLabels(model or part)
							eggs[#eggs+1] = {
								prompt = prompt, part = part,
								pos = part.Position, cf = part.CFrame,
								area = tostring(model and model.Name or part.Name),
								cat = prompt.ObjectText ~= "" and prompt.ObjectText or (model and model.Name or part.Name),
								mutation = tags[1], tags = tags, weight = weight, rawText = full,
							}
						end
					end
				end
			end)
		else
			-- Repli si le dossier a disparu/été renommé : scan mot-clé
			-- classique sur tout workspace (moins précis, mais jamais
			-- totalement aveugle).
			pcall(function()
				for _, prompt in ipairs(workspace:GetDescendants()) do
					if prompt:IsA("ProximityPrompt") and prompt.Enabled then
						local action = prompt.ActionText:lower()
						local objTxt = prompt.ObjectText:lower()
						local parentName = (prompt.Parent and prompt.Parent.Name or ""):lower()
						if action:find("grab") or action:find("steal") or action:find("take")
							or action:find("pick") or action:find("collect")
							or objTxt:find("egg") or parentName:find("egg") or parentName:find("drop") then
							local part, model = _promptOwnerModel(prompt)
							if part then
								local full, tags, weight = _readEggLabels(model or part)
								eggs[#eggs+1] = {
									prompt = prompt, part = part,
									pos = part.Position, cf = part.CFrame,
									area = "Dropped",
									cat = objTxt ~= "" and prompt.ObjectText or part.Name,
									mutation = tags[1], tags = tags, weight = weight, rawText = full,
								}
							end
						end
					end
				end
			end)
		end

		cachedEggs = eggs
		task.wait(0.35)
	end
end)

-- kill previous instance
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("yslemEggGui")
	if old then old:Destroy() end
	local old2 = LP.PlayerGui:FindFirstChild("yslemEggGui")
	if old2 then old2:Destroy() end
end)

-- ============================================================
-- PALETTE  (Moon Hub default)
-- ============================================================
local C_BG     = Color3.fromRGB(0,0,0)
local C_PANEL  = Color3.fromRGB(0,0,0)
local C_ROW    = Color3.fromRGB(8,8,10)
local C_BORDER = Color3.fromRGB(40,46,58)
local C_MOON   = Color3.fromRGB(90,160,255)
local C_MOON2  = Color3.fromRGB(160,200,255)
local C_WHITE  = Color3.fromRGB(255,255,255)
local C_DIM    = Color3.fromRGB(110,120,140)
local C_ON_BG  = Color3.fromRGB(20,45,80)
local C_OFF_BG = Color3.fromRGB(0,0,0)
local C_GREEN  = Color3.fromRGB(60,220,120)
local C_RED    = Color3.fromRGB(220,60,60)
local C_YELLOW = Color3.fromRGB(230,200,90)
local C_GOLD   = Color3.fromRGB(255,200,60)

-- ============================================================
-- STATE
-- ============================================================
local St = {
	instantGrab      = false,
	autoFarm         = false,
	farmTier         = "Nearest",
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
	speed            = 16,
	flySpeed         = 50,
	guiVisible       = true,
}

-- ============================================================
-- UI HELPERS
-- ============================================================
local function corner(inst, r)
	local c = Instance.new("UICorner", inst); c.CornerRadius = UDim.new(0, r or 8); return c
end
local function stroke(inst, col, th)
	local s = Instance.new("UIStroke", inst)
	s.Color = col or C_BORDER; s.Thickness = th or 1; return s
end
local function label(parent, text, size, color, font, ax, ay)
	local l = Instance.new("TextLabel", parent)
	l.BackgroundTransparency = 1
	l.Size = size or UDim2.new(1,0,1,0)
	l.Text = text or ""; l.TextSize = 13
	l.TextColor3 = color or C_WHITE
	l.Font = font or Enum.Font.GothamMedium
	l.TextXAlignment = ax or Enum.TextXAlignment.Left
	l.TextYAlignment = ay or Enum.TextYAlignment.Center
	return l
end

-- Living gradient for title
local _liveGrads = {}
RunService.RenderStepped:Connect(function()
	for _, g in ipairs(_liveGrads) do
		if g and g.Parent then g.Rotation = (g.Rotation + 1.2) % 360 end
	end
end)
local function liveGrad(inst)
	local g = Instance.new("UIGradient", inst)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(40,80,165)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(90,150,255)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(160,210,255)),
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(40,80,165)),
	})
	table.insert(_liveGrads, g); return g
end

-- ============================================================
-- BUILD GUI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "yslemEggGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP.PlayerGui end

-- Main frame
local main = Instance.new("Frame", gui)
main.Name = "Main"
main.Size = UDim2.new(0,240,0,330)
main.Position = UDim2.new(0,12,0.5,-165)
main.BackgroundColor3 = C_BG
main.BorderSizePixel = 0
main.ClipsDescendants = true
corner(main, 10)
stroke(main, C_BORDER, 1.5)

-- ── Header ──────────────────────────────────────────────────
local header = Instance.new("Frame", main)
header.Name = "Header"
header.Size = UDim2.new(1,0,0,36)
header.BackgroundColor3 = C_BG
header.BorderSizePixel = 0
corner(header, 10)

local titleLbl = Instance.new("TextLabel", header)
titleLbl.BackgroundTransparency = 1
titleLbl.Size = UDim2.new(1,-46,1,0)
titleLbl.Position = UDim2.new(0,12,0,0)
titleLbl.Text = "yslemEgg"
titleLbl.TextSize = 15
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.TextYAlignment = Enum.TextYAlignment.Center
liveGrad(titleLbl)

local verLbl = Instance.new("TextLabel", header)
verLbl.BackgroundTransparency = 1
verLbl.Size = UDim2.new(0,40,1,0)
verLbl.Position = UDim2.new(0,100,0,0)
verLbl.Text = "v1.0"
verLbl.TextSize = 10
verLbl.Font = Enum.Font.GothamMedium
verLbl.TextColor3 = C_DIM
verLbl.TextXAlignment = Enum.TextXAlignment.Left
verLbl.TextYAlignment = Enum.TextYAlignment.Center

-- minimize / close buttons
local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0,22,0,22)
closeBtn.Position = UDim2.new(1,-28,0.5,-11)
closeBtn.BackgroundColor3 = Color3.fromRGB(180,50,50)
closeBtn.Text = "✕"; closeBtn.TextSize = 11
closeBtn.TextColor3 = C_WHITE; closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0; corner(closeBtn, 5)

local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.new(0,22,0,22)
minBtn.Position = UDim2.new(1,-54,0.5,-11)
minBtn.BackgroundColor3 = Color3.fromRGB(40,40,55)
minBtn.Text = "–"; minBtn.TextSize = 13
minBtn.TextColor3 = C_MOON2; minBtn.Font = Enum.Font.GothamBold
minBtn.BorderSizePixel = 0; corner(minBtn, 5)

-- separator
local sep = Instance.new("Frame", main)
sep.Size = UDim2.new(1,-24,0,1)
sep.Position = UDim2.new(0,12,0,36)
sep.BackgroundColor3 = C_BORDER; sep.BorderSizePixel = 0

-- ── Tab bar ─────────────────────────────────────────────────
local TAB_Y = 37
local tabBar = Instance.new("Frame", main)
tabBar.Size = UDim2.new(1,0,0,28)
tabBar.Position = UDim2.new(0,0,0,TAB_Y)
tabBar.BackgroundTransparency = 1

local TABS = {"Farm","Speed","Visual","Misc"}
local tabBtns = {}
local tabW = 1 / #TABS
for i, name in ipairs(TABS) do
	local btn = Instance.new("TextButton", tabBar)
	btn.Size = UDim2.new(tabW, -2, 1, -4)
	btn.Position = UDim2.new((i-1)*tabW, 1, 0, 2)
	btn.BackgroundColor3 = C_OFF_BG
	btn.Text = name; btn.TextSize = 11
	btn.TextColor3 = C_DIM; btn.Font = Enum.Font.GothamMedium
	btn.BorderSizePixel = 0; corner(btn, 6)
	tabBtns[name] = btn
end

-- ── Content area ────────────────────────────────────────────
local CONTENT_Y = TAB_Y + 28
local contentArea = Instance.new("Frame", main)
contentArea.Size = UDim2.new(1,0,1,-CONTENT_Y)
contentArea.Position = UDim2.new(0,0,0,CONTENT_Y)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true

-- Page frames
local pages = {}
for _, name in ipairs(TABS) do
	local pg = Instance.new("ScrollingFrame", contentArea)
	pg.Name = name
	pg.Size = UDim2.new(1,0,1,0)
	pg.Position = UDim2.new(0,0,0,0)
	pg.BackgroundTransparency = 1
	pg.BorderSizePixel = 0
	pg.ScrollBarThickness = 3
	pg.ScrollBarImageColor3 = C_MOON
	pg.CanvasSize = UDim2.new(0,0,0,0)
	pg.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pg.Visible = false
	local list = Instance.new("UIListLayout", pg)
	list.Padding = UDim.new(0,2)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	Instance.new("UIPadding", pg).PaddingTop = UDim.new(0,4)
	pages[name] = pg
end

-- ── Row builder ─────────────────────────────────────────────
local function makeRow(page, key, displayName, onToggle)
	local row = Instance.new("Frame", page)
	row.Size = UDim2.new(1,-12,0,30)
	row.BackgroundColor3 = C_ROW
	row.BorderSizePixel = 0
	corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)

	local nameLbl = label(row, displayName, UDim2.new(1,-50,1,0), C_WHITE, Enum.Font.GothamMedium)
	nameLbl.TextSize = 12

	local pill = Instance.new("TextButton", row)
	pill.Size = UDim2.new(0,44,0,18)
	pill.Position = UDim2.new(1,-44,0.5,-9)
	pill.BorderSizePixel = 0
	pill.TextSize = 10; pill.Font = Enum.Font.GothamBold
	corner(pill, 9)

	local function refresh()
		local on = St[key]
		pill.BackgroundColor3 = on and C_ON_BG or C_OFF_BG
		pill.TextColor3 = on and C_MOON or C_DIM
		pill.Text = on and "ON" or "OFF"
		row.BackgroundColor3 = on and Color3.fromRGB(10,18,32) or C_ROW
	end
	refresh()

	pill.MouseButton1Click:Connect(function()
		St[key] = not St[key]
		refresh()
		if onToggle then pcall(onToggle, St[key]) end
	end)
	return row, pill, refresh
end

-- Slider row
local function makeSlider(page, key, displayName, minV, maxV, fmt)
	local row = Instance.new("Frame", page)
	row.Size = UDim2.new(1,-12,0,44)
	row.BackgroundColor3 = C_ROW
	row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)

	local nameLbl = label(row, displayName, UDim2.new(0.6,0,0,20), C_WHITE, Enum.Font.GothamMedium)
	nameLbl.TextSize = 12; nameLbl.Position = UDim2.new(0,0,0,2)

	local valLbl = label(row, "", UDim2.new(0.4,0,0,20), C_MOON, Enum.Font.GothamBold,
		Enum.TextXAlignment.Right)
	valLbl.TextSize = 12; valLbl.Position = UDim2.new(0.6,0,0,2)

	local track = Instance.new("Frame", row)
	track.Size = UDim2.new(1,0,0,6)
	track.Position = UDim2.new(0,0,1,-12)
	track.BackgroundColor3 = Color3.fromRGB(20,25,35)
	track.BorderSizePixel = 0; corner(track, 3)

	local fill = Instance.new("Frame", track)
	fill.Size = UDim2.new(0,0,1,0)
	fill.BackgroundColor3 = C_MOON
	fill.BorderSizePixel = 0; corner(fill, 3)

	local function setVal(v)
		v = math.clamp(math.floor(v), minV, maxV)
		St[key] = v
		local t = (v - minV) / (maxV - minV)
		fill.Size = UDim2.new(t, 0, 1, 0)
		valLbl.Text = fmt and string.format(fmt, v) or tostring(v)
	end
	setVal(St[key] or minV)

	local dragging = false
	track.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if not dragging then return end
		if inp.UserInputType ~= Enum.UserInputType.MouseMovement
			and inp.UserInputType ~= Enum.UserInputType.Touch then return end
		local abs = track.AbsolutePosition
		local sz  = track.AbsoluteSize
		local rel = math.clamp((inp.Position.X - abs.X) / sz.X, 0, 1)
		setVal(minV + (maxV - minV) * rel)
	end)
	return row
end

-- Status bar at bottom
local statusBar = Instance.new("Frame", main)
statusBar.Size = UDim2.new(1,0,0,20)
statusBar.Position = UDim2.new(0,0,1,-20)
statusBar.BackgroundColor3 = Color3.fromRGB(5,5,8)
statusBar.BorderSizePixel = 0

local statusLbl = Instance.new("TextLabel", statusBar)
statusLbl.BackgroundTransparency = 1
statusLbl.Size = UDim2.new(1,-10,1,0)
statusLbl.Position = UDim2.new(0,8,0,0)
statusLbl.Text = "Idle"
statusLbl.TextSize = 10; statusLbl.Font = Enum.Font.Gotham
statusLbl.TextColor3 = C_DIM
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local function setStatus(txt, col)
	statusLbl.Text = txt
	statusLbl.TextColor3 = col or C_DIM
end

-- ── Tab switching ────────────────────────────────────────────
local activeTab = nil
local function switchTab(name)
	if activeTab == name then return end
	activeTab = name
	for _, n in ipairs(TABS) do
		local pg = pages[n]; local btn = tabBtns[n]
		local on = n == name
		pg.Visible = on
		btn.BackgroundColor3 = on and C_ON_BG or C_OFF_BG
		btn.TextColor3 = on and C_MOON or C_DIM
	end
end
for _, name in ipairs(TABS) do
	tabBtns[name].MouseButton1Click:Connect(function() switchTab(name) end)
end

-- ============================================================
-- ── PAGE: FARM ──────────────────────────────────────────────
-- ============================================================
local farmPage = pages["Farm"]

-- ── DIAGNOSTIC MODULES ───────────────────────────────────────
-- Affiche en clair ce qui a chargé ou non (EggCmds/Network/Save/
-- Bases/Treadmills/Trails/Ragdoll...). Si un module manque, les
-- features qui en dépendent sont explicitement des no-op — plus de
-- panne silencieuse à deviner. Un clic recopie le détail complet.
do
	local okCount, total = 0, 0
	for _, ok in pairs(_ModuleStatus) do
		total = total + 1
		if ok then okCount = okCount + 1 end
	end
	local allOk = okCount == total

	local row = Instance.new("Frame", farmPage)
	row.Size = UDim2.new(1,-12,0,26)
	row.BackgroundColor3 = C_ROW; row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	local lbl = label(row, "Modules: "..okCount.."/"..total.." charges", UDim2.new(1,0,1,0),
		allOk and C_GREEN or C_YELLOW, Enum.Font.GothamMedium)
	lbl.TextSize = 11
	if not allOk then
		local btn = Instance.new("TextButton", row)
		btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""
		btn.MouseButton1Click:Connect(function()
			local lines = {}
			for name, ok in pairs(_ModuleStatus) do
				local path = _ModuleFound[name]
				if ok then
					table.insert(lines, "OK          "..name.."  ("..tostring(path)..")")
				elseif path then
					table.insert(lines, "ECHEC       "..name.."  (trouve a "..path..", require() plante)")
				else
					table.insert(lines, "INTROUVABLE "..name)
				end
			end
			table.sort(lines)
			local msg = table.concat(lines, "\n")
			print("[yslemEgg] Statut modules:\n"..msg)
			pcall(function() if setclipboard then setclipboard(msg) end end)
			setStatus("Details copies / voir console (F9)", C_YELLOW)
		end)
	end
end

-- ── INSTANT GRAB ────────────────────────────────────────────
-- Technique confirmée par la source originale du jeu (Toolbox Hub) :
-- ProximityPromptService.PromptShown se déclenche dès qu'un prompt
-- devient visible (egg, upgrade, claim, tout type confondu) — on met
-- son HoldDuration à 0 pour que la moindre interaction soit instantanée,
-- au lieu de tenir la touche. Contrairement à l'original (appliqué une
-- fois pour toute la session, jamais restauré), version réversible ici :
-- la valeur d'origine est mémorisée par prompt et restaurée au OFF.
local PPS = game:GetService("ProximityPromptService")
local _instaGrabConn = nil
local _instaGrabOriginal = setmetatable({}, {__mode = "k"})  -- prompt -> HoldDuration d'origine

local function setInstantGrab(on)
	St.instantGrab = on
	if on then
		if _instaGrabConn then return end
		_instaGrabConn = PPS.PromptShown:Connect(function(prompt)
			if not St.instantGrab then return end
			if _instaGrabOriginal[prompt] == nil then
				_instaGrabOriginal[prompt] = prompt.HoldDuration
			end
			prompt.HoldDuration = 0
		end)
	else
		if _instaGrabConn then _instaGrabConn:Disconnect(); _instaGrabConn = nil end
		-- Restaure tout prompt déjà modifié (encore en mémoire)
		for prompt, orig in pairs(_instaGrabOriginal) do
			pcall(function()
				if prompt and prompt.Parent then prompt.HoldDuration = orig end
			end)
		end
	end
end

makeRow(farmPage, "instantGrab", "Instant Grab", function(on)
	setInstantGrab(on)
end)

-- ── FARM TIER ────────────────────────────────────────────────
-- [FIX] L'ancien système comparait r.area (nom du Model porteur du
-- ProximityPrompt sous AreaEggSlotsClient — un identifiant de slot,
-- PAS un nom de zone comme "Abyss Ocean") à la valeur choisie ici
-- ("Abyss Ocean" etc, copiées du dropdown de la source d'origine).
-- Cette comparaison ne matchait donc JAMAIS → "aucun oeuf valide"
-- en permanence, quelle que soit la sélection, même quand des œufs
-- étaient bel et bien détectés. Confirmé par capture d'écran.
-- Remplacé par un tri simple et toujours valide : le plus proche
-- d'abord (trajet le plus court, aucune donnée de zone nécessaire).
St.farmTier = "Nearest"
do
	local row = Instance.new("Frame", farmPage)
	row.Size = UDim2.new(1,-12,0,26)
	row.BackgroundColor3 = C_ROW; row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	label(row, "Farm: cible le plus proche", UDim2.new(1,0,1,0), C_DIM, Enum.Font.GothamMedium).TextSize = 11
end

-- ── AUTO FARM — motif "swoop" de la source d'origine ────────
-- 1) Choisit l'œuf le plus proche dans cachedEggs.
-- 2) Tween aller (PlatformStand=true le temps du trajet, pas de
--    vélocité manuelle donc pas de rollback), spam fireproximityprompt
--    pendant le trajet ET sur place, micro-pause pour laisser la
--    réplication réseau rattraper, tween retour à la position de
--    départ exacte.
-- Boucle unique démarrée une fois au chargement (comme la source
-- d'origine) — gate interne sur St.autoFarm, pas de start/stop de
-- connexion à chaque toggle.
task.spawn(function()
	local isFarmingEgg = false
	while true do
		task.wait(0.2)
		local char = LP.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		if St.autoFarm and not isFarmingEgg and rootPart then
			local validEggs = {}
			for _, r in ipairs(cachedEggs) do
				validEggs[#validEggs+1] = r
			end

			if #validEggs == 0 then
				setStatus("Farm: aucun oeuf detecte", C_DIM)
			else
				local myPos = rootPart.Position
				table.sort(validEggs, function(a, b)
					return (a.pos - myPos).Magnitude < (b.pos - myPos).Magnitude
				end)
				local bestEgg = validEggs[1]

				isFarmingEgg = true
				local originalPos = rootPart.CFrame
				if hum then hum.PlatformStand = true end
				local flightSpeed = math.max(St.speed, 40)  -- swoop toujours fluide même à vitesse de marche basse
				local targetPos = bestEgg.cf + Vector3.new(0, 1.5, 0)
				local distToEgg = (rootPart.Position - targetPos.Position).Magnitude
				local timeToEgg = math.max(distToEgg / flightSpeed, 0.02)

				local spamming = true
				task.spawn(function()
					-- Chaque œuf du scanner porte maintenant toujours son vrai
					-- ProximityPrompt (AreaEggSlotsClient ou repli mot-clé) — plus
					-- besoin de deviner isPhysical/uid, on fire directement dessus.
					while spamming do
						pcall(function()
							if bestEgg.prompt and fireproximityprompt then
								fireproximityprompt(bestEgg.prompt)
							end
						end)
						task.wait(0.05)
					end
				end)

				local tweenTo = TweenService:Create(rootPart, TweenInfo.new(timeToEgg, Enum.EasingStyle.Linear), {CFrame = targetPos})
				tweenTo:Play(); tweenTo.Completed:Wait()

				rootPart.AssemblyLinearVelocity = Vector3.zero
				task.wait(0.15)

				local distBack = (rootPart.Position - originalPos.Position).Magnitude
				local timeBack = math.max(distBack / flightSpeed, 0.02)
				local tweenBack = TweenService:Create(rootPart, TweenInfo.new(timeBack, Enum.EasingStyle.Linear), {CFrame = originalPos})
				tweenBack:Play(); tweenBack.Completed:Wait()

				spamming = false
				rootPart.AssemblyLinearVelocity = Vector3.zero
				rootPart.AssemblyAngularVelocity = Vector3.zero
				if hum and not St.fly and not St.antiRagdoll then
					hum.PlatformStand = false
					pcall(function() hum:ChangeState(Enum.HumanoidStateType.Landed) end)
				end
				isFarmingEgg = false
				setStatus("Farm → "..tostring(bestEgg.cat or "?"), C_GREEN)
			end
		end
	end
end)

makeRow(farmPage, "autoFarm", "Auto Farm Eggs", function(on)
	if not on then setStatus("Farm OFF", C_DIM) end
end)

-- ── CLIC UI RÉEL (indépendant de tout module cassé) ──────────
-- Le diagnostic confirme 0/16 modules chargés — EggCmds/Network/etc
-- n'existent sous aucun de ces noms dans ce jeu. Solution robuste :
-- cliquer directement les VRAIS boutons de l'interface du jeu,
-- confirmés par capture d'écran ("Grow All" dans le panneau Growing
-- Eggs, "Equip Best" dans le panneau Pen Roster). firesignal()
-- déclenche exactement le même code que si le joueur cliquait à la
-- main — indépendant de la structure interne du jeu, marche tant que
-- le bouton existe et que l'executor expose firesignal.
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
		setStatus("Clic UI indispo (firesignal manquant sur cet executor)", C_RED)
	end
	return false
end

-- ── AUTO HATCH — clique le vrai bouton "Grow All" ────────────
task.spawn(function()
	local lastHatch = 0
	while true do
		task.wait(1)
		if St.autoHatch and (os.clock() - lastHatch) >= 3 then
			lastHatch = os.clock()
			local clicked = _clickGuiButtonByText(function(t)
				local low = t:lower()
				return low:find("grow all", 1, true) ~= nil
			end)
			if clicked then setStatus("Hatch: 'Grow All' clique", C_GREEN) end
		end
	end
end)

makeRow(farmPage, "autoHatch", "Auto Hatch", function(on) end)

-- ── AUTO EQUIP BEST — clique le vrai bouton "Equip Best" ─────
task.spawn(function()
	local lastEquip = 0
	while true do
		task.wait(2)
		if St.autoEquip and (os.clock() - lastEquip) >= 4 then
			lastEquip = os.clock()
			local clicked = _clickGuiButtonByText(function(t)
				return t:lower():find("equip best", 1, true) ~= nil
			end)
			if clicked then setStatus("'Equip Best' clique", C_GREEN) end
		end
	end
end)

makeRow(farmPage, "autoEquip", "Auto Equip Best", function(on) end)

-- ── AUTO CLAIM — index/free gifts/offline assets/group reward ──
task.spawn(function()
	local lastClaim = 0
	while true do
		task.wait(1)
		if St.autoClaim and (os.clock() - lastClaim) >= 5 then
			lastClaim = os.clock()
			pcall(function()
				if Network and NM then
					if NM.Index and NM.Index.REQUEST_CLAIM_ALL then Network.Invoke(NM.Index.REQUEST_CLAIM_ALL) end
					if NM.FreeGifts and NM.FreeGifts.REQUEST_CLAIM then Network.Invoke(NM.FreeGifts.REQUEST_CLAIM) end
					if NM.OfflineAssets and NM.OfflineAssets.REQUEST_REDEEM then Network.Invoke(NM.OfflineAssets.REQUEST_REDEEM) end
					if NM.GroupReward and NM.GroupReward.CLAIM_REWARD then Network.Invoke(NM.GroupReward.CLAIM_REWARD) end
				end
			end)
		end
	end
end)

makeRow(farmPage, "autoClaim", "Auto Claim", function(on) end)

-- ── AUTO UPGRADE — vraies conditions d'argent (Save.Get + Directory) ──
-- Reproduit exactement tryUpgradePen / tryUpgradeTreadmill / tryBuyTrails
-- de la source d'origine : lit le vrai solde du joueur (Save.Get()) et
-- le vrai coût du prochain palier (Bases/Treadmills/Trails directory)
-- avant d'acheter — jamais de tentative gaspillée sur un remote générique.
local function tryUpgradePen(data)
	local nextLevel = data.BaseUpgradeLevel + 1
	local nextConfig = Bases and Bases.BASES and Bases.BASES[nextLevel]
	if nextConfig == nil then return end
	if data.Money >= nextConfig.Cost then
		pcall(function() Network.Fire(PlotsNet.REQUEST_BASE_UPGRADE) end)
	end
end

local function tryUpgradeTreadmill(data)
	local nextLevel = data.TreadmillUpgradeLevel + 1
	local nextConfig = Treadmills and Treadmills.GetByUpgradeLevel and Treadmills.GetByUpgradeLevel(nextLevel)
	if nextConfig == nil then return end
	if data.Money >= nextConfig.Price then
		pcall(function() Network.Invoke(TreadmillsNet.REQUEST_UPGRADE, nextConfig._id) end)
	end
end

local function tryBuyTrails(data)
	if not Trails or not Trails.Directory then return end
	local affordable = {}
	for name, cfg in pairs(Trails.Directory) do
		if cfg.DisplayInShop and not data.TrailInventory[name] then
			if data.Money >= cfg.Price then
				table.insert(affordable, {name = name, price = cfg.Price})
			end
		end
	end
	table.sort(affordable, function(a, b) return a.price < b.price end)
	if #affordable > 0 then
		local target = affordable[#affordable]
		pcall(function() Network.Invoke(TrailsNet.REQUEST_PURCHASE, target.name) end)
	end
end

task.spawn(function()
	local lastPen, lastTM, lastTrail = 0, 0, 0
	while true do
		task.wait(1.5)
		if St.autoUpgradePen or St.autoUpgradeTM or St.autoBuyTrails then
			local ok, data = pcall(function() return Save and Save.Get and Save.Get() end)
			if ok and data then
				local now = os.clock()
				if St.autoUpgradePen and PlotsNet and (now - lastPen > 1.5) then
					pcall(tryUpgradePen, data); lastPen = now
				end
				if St.autoUpgradeTM and TreadmillsNet and (now - lastTM > 1.5) then
					pcall(tryUpgradeTreadmill, data); lastTM = now
				end
				if St.autoBuyTrails and TrailsNet and (now - lastTrail > 3) then
					pcall(tryBuyTrails, data); lastTrail = now
				end
			end
		end
	end
end)

makeRow(farmPage, "autoUpgradePen", "Auto Upgrade Pen", function(on) end)
makeRow(farmPage, "autoUpgradeTM", "Auto Upgrade Treadmill", function(on) end)
makeRow(farmPage, "autoBuyTrails", "Auto Buy Trails", function(on) end)

-- ── AUTO RUN TREADMILL ───────────────────────────────────────
-- Désactive le mode "lent" du tapis roulant en continu (comme la
-- source d'origine) — permet de rester en vitesse normale sur le
-- tapis au lieu de la vitesse ralentie par défaut du jeu.
task.spawn(function()
	while true do
		if St.autoRunTreadmill and TreadmillsNet then
			pcall(function()
				Network.Invoke(TreadmillsNet.REQUEST_SET_SLOW_TOGGLE_ENABLED, false)
			end)
		end
		task.wait(10)
	end
end)

makeRow(farmPage, "autoRunTreadmill", "Auto Run Treadmill", function(on) end)
-- Note: le slider "Farm Radius" a été retiré ici — Auto Farm cible
-- maintenant le meilleur œuf du snapshot serveur (via farmTier),
-- pas une proximité locale, donc un rayon n'a plus de sens.

-- Farm radius slider
-- ============================================================
-- ── PAGE: SPEED ─────────────────────────────────────────────
-- ============================================================
local speedPage = pages["Speed"]

-- ── PROXY SPEED (méthode Moon Hub) ──────────────────────────
-- Part massless soudé au HRP via Weld.
-- On écrit AssemblyLinearVelocity sur ce proxy chaque RenderStepped,
-- le weld entraîne le personnage sans toucher WalkSpeed (indétectable).
-- SetNetworkOwner(LP) → le client est autoritaire → pas de rollback.
local _speedActive  = false
local _proxy        = nil
local _ownConn      = nil
local _ownTimer     = 0
local _ownInterval  = 0.8 + math.random() * 0.4

local function _claimOwn(hrp)
	pcall(function() hrp:SetNetworkOwner(LP) end)
end

local function _cleanProxy()
	if _ownConn then pcall(function() _ownConn:Disconnect() end); _ownConn = nil end
	if _proxy   then pcall(function() _proxy:Destroy() end);      _proxy   = nil end
end

local function _ensureProxy(hrp)
	local char = hrp.Parent
	if _proxy and _proxy.Parent == char then return _proxy end
	_cleanProxy()
	local p  = Instance.new("Part")
	p.Name         = "YE_Proxy"
	p.Size         = Vector3.new(1,1,1)
	p.Transparency = 1
	p.CanCollide   = false
	p.Massless     = true
	p.Parent       = char
	local w  = Instance.new("Weld", p)
	w.Part0  = hrp; w.Part1 = p; w.C0 = CFrame.new()
	_proxy   = p
	_claimOwn(hrp)
	-- re-claim si le serveur reprend l'ownership
	_ownConn = hrp:GetPropertyChangedSignal("ReceiveAge"):Connect(function()
		if _speedActive then task.defer(function() _claimOwn(hrp) end) end
	end)
	return p
end

-- Boucle principale : RenderStepped comme Moon Hub
RunService.RenderStepped:Connect(function(dt)
	if not _speedActive then _cleanProxy(); return end
	local char = LP.Character; if not char then _cleanProxy(); return end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	local hrp  = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then _cleanProxy(); return end
	-- ne pas forcer en ragdoll / physics
	local st = hum:GetState()
	if hum.PlatformStand
		or st == Enum.HumanoidStateType.Physics
		or st == Enum.HumanoidStateType.Ragdoll
		or st == Enum.HumanoidStateType.FallingDown then
		_cleanProxy(); return
	end
	-- re-claim périodique
	_ownTimer = _ownTimer + dt
	if _ownTimer >= _ownInterval then
		_claimOwn(hrp); _ownTimer = 0; _ownInterval = 0.8 + math.random() * 0.4
	end
	local md  = hum.MoveDirection
	local spd = St.speed
	if md.Magnitude > 0 then
		local jit = 1 + (math.random() - 0.5) * 0.08  -- jitter ±4%
		local px  = _ensureProxy(hrp)
		px.AssemblyLinearVelocity = Vector3.new(
			md.X * spd * jit,
			hrp.AssemblyLinearVelocity.Y,
			md.Z * spd * jit
		)
	end
end)

local function startSpeed()
	_speedActive = true
end
local function stopSpeed()
	_speedActive = false
	_cleanProxy()
end

-- Re-crée le proxy si respawn
LP.CharacterAdded:Connect(function()
	if _speedActive then _cleanProxy() end
end)

-- "Speed Boost" toggle (not a key in St, managed manually)
local speedOn = false
local _, speedPill, speedRefresh
do
	local row = Instance.new("Frame", speedPage)
	row.Size = UDim2.new(1,-12,0,30)
	row.BackgroundColor3 = C_ROW; row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	label(row, "Speed Boost", UDim2.new(1,-50,1,0), C_WHITE, Enum.Font.GothamMedium).TextSize = 12
	speedPill = Instance.new("TextButton", row)
	speedPill.Size = UDim2.new(0,44,0,18)
	speedPill.Position = UDim2.new(1,-44,0.5,-9)
	speedPill.BorderSizePixel = 0; speedPill.TextSize = 10; speedPill.Font = Enum.Font.GothamBold
	corner(speedPill, 9)
	speedRefresh = function()
		speedPill.BackgroundColor3 = speedOn and C_ON_BG or C_OFF_BG
		speedPill.TextColor3 = speedOn and C_MOON or C_DIM
		speedPill.Text = speedOn and "ON" or "OFF"
		row.BackgroundColor3 = speedOn and Color3.fromRGB(10,18,32) or C_ROW
	end
	speedRefresh()
	speedPill.MouseButton1Click:Connect(function()
		speedOn = not speedOn; speedRefresh()
		if speedOn then startSpeed() else stopSpeed() end
	end)
end

makeSlider(speedPage, "speed", "Walk Speed", 4, 500, "%d")

-- ── ANTI RAGDOLL — override du module + filet réactif ───────
-- Double couche : le jeu a son propre module Ragdoll (retrouvé dans
-- la source d'origine) — l'écraser directement (Ragdoll.Ragdoll,
-- IsRagdolled, NpcRagdoll → no-op) empêche le ragdoll de se déclencher
-- DU TOUT, proactif plutôt que réactif. En complément, le filet
-- Heartbeat existant (ChangeState + réactivation des Motor6D) reste
-- actif si jamais le module n'a pas pu être chargé sur ce serveur.
local _ragdollOriginal = {}
local function _applyRagdollModuleOverride(on)
	if not Ragdoll then return end
	if on then
		if _ragdollOriginal.Ragdoll == nil then
			_ragdollOriginal.Ragdoll      = Ragdoll.Ragdoll
			_ragdollOriginal.IsRagdolled  = Ragdoll.IsRagdolled
			_ragdollOriginal.NpcRagdoll   = Ragdoll.NpcRagdoll
		end
		pcall(function()
			Ragdoll.Ragdoll     = function() end
			Ragdoll.IsRagdolled = function() return false end
			Ragdoll.NpcRagdoll  = function() end
		end)
	else
		if _ragdollOriginal.Ragdoll ~= nil then
			pcall(function()
				Ragdoll.Ragdoll     = _ragdollOriginal.Ragdoll
				Ragdoll.IsRagdolled = _ragdollOriginal.IsRagdolled
				Ragdoll.NpcRagdoll  = _ragdollOriginal.NpcRagdoll
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
		local now = tick(); if now - _t < 0.1 then return end; _t = now
		local char = LP.Character; if not char then return end
		local hum  = char:FindFirstChildOfClass("Humanoid")
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

-- ── FLY ─────────────────────────────────────────────────────
local _flyConn = nil
local _flyBP   = nil
local function stopFly()
	if _flyConn then _flyConn:Disconnect(); _flyConn = nil end
	pcall(function() if _flyBP then _flyBP:Destroy(); _flyBP = nil end end)
	local char = LP.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = false end
end
local function startFly()
	stopFly()
	local char = LP.Character; if not char then return end
	local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
	local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
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
		local mv  = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up) then
			mv = mv + cam.CFrame.LookVector
		end
		if UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down) then
			mv = mv - cam.CFrame.LookVector
		end
		if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then
			mv = mv - cam.CFrame.RightVector
		end
		if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then
			mv = mv + cam.CFrame.RightVector
		end
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

-- ── ANTI TRAP ───────────────────────────────────────────────
local _trapConn = nil
local _lastPos  = Vector3.zero
local _stuckSince = 0
local function stopAntiTrap()
	if _trapConn then _trapConn:Disconnect(); _trapConn = nil end
end
local function startAntiTrap()
	stopAntiTrap()
	local _t = 0
	_trapConn = RunService.Heartbeat:Connect(function()
		if not St.antiTrap then return end
		local now = tick(); if now - _t < 0.5 then return end; _t = now
		local char = LP.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then _lastPos = Vector3.zero; _stuckSince = now; return end
		local moved = (hrp.Position - _lastPos).Magnitude
		if moved < 0.5 then
			-- check if we're trying to move
			local hum = char:FindFirstChildOfClass("Humanoid")
			local isMoving = hum and hum.MoveDirection.Magnitude > 0.1
			if isMoving then
				if _stuckSince > 0 and now - _stuckSince > 1.5 then
					-- unstick: teleport slightly up
					hrp.CFrame = hrp.CFrame * CFrame.new(0, 3, 0)
					_stuckSince = 0
					setStatus("Anti-Trap: unstuck!", C_GREEN)
				end
			else
				_stuckSince = 0
			end
		else
			_stuckSince = 0
		end
		_lastPos = hrp.Position
	end)
end

makeRow(speedPage, "antiTrap", "Anti Trap", function(on)
	if on then startAntiTrap() else stopAntiTrap() end
end)

-- ============================================================
-- ── PAGE: VISUAL ────────────────────────────────────────────
-- ============================================================
local visualPage = pages["Visual"]

-- ── EGG ESP — mutation/poids lus directement dans le texte affiché ──
-- Utilise cachedEggs (scanner AreaEggSlotsClient + lecture BillboardGui,
-- voir plus haut) — chaque entrée porte déjà .mutation/.tags/.weight
-- extraits du texte RÉELLEMENT affiché par le jeu (BillboardGui sur le
-- Model de l'œuf), donc toujours exact : pas de recalcul, pas de
-- supposition, juste ce que le joueur voit déjà à l'écran. Or/doré =
-- au moins un tag rare détecté (secret/eternal/divine/mythic/...),
-- vert = normal, rouge = zone verrouillée (Speed Power insuffisante,
-- si le système de zones gardées a pu charger).
local function _shortNum(n)
	if not n then return "?" end
	local a = math.abs(n)
	if a >= 1e12 then return string.format("%.1fT", n/1e12) end
	if a >= 1e9  then return string.format("%.1fB", n/1e9)  end
	if a >= 1e6  then return string.format("%.1fM", n/1e6)  end
	if a >= 1e3  then return string.format("%.1fK", n/1e3)  end
	return string.format("%d", n)
end

local _espParts = {}  -- liste de Part (détruire le Part détruit box+billboard enfants avec)
local _espConn = nil
local function clearESP()
	for _, p in ipairs(_espParts) do pcall(function() p:Destroy() end) end
	_espParts = {}
end
local function stopESP()
	if _espConn then _espConn:Disconnect(); _espConn = nil end
	clearESP()
end
local function startESP()
	stopESP()
	local _t = 0
	_espConn = RunService.Heartbeat:Connect(function()
		if not St.esp then return end
		local now = tick(); if now - _t < 1 then return end; _t = now
		clearESP()
		for _, r in ipairs(cachedEggs) do
			pcall(function()
				local unlocked = areaUnlocked(r.area)
				local hasRareTag = r.tags and #r.tags > 0
				local col = (not unlocked) and C_RED or (hasRareTag and C_GOLD or C_GREEN)

				local part = r.part
				local p = Instance.new("Part")
				p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.Transparency = 1
				p.Size = (part and part:IsA("BasePart") and part.Size.Magnitude > 0.5) and part.Size or Vector3.new(3.5,3.5,3.5)
				p.CFrame = r.cf
				p.Parent = workspace

				local box = Instance.new("SelectionBox")
				box.Adornee = p
				box.Color3 = col
				box.LineThickness = hasRareTag and 0.1 or 0.05
				box.SurfaceTransparency = 0.7
				box.SurfaceColor3 = col
				box.Parent = p

				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(220, 34)
				bb.AlwaysOnTop = true
				bb.MaxDistance = 800
				bb.Parent = p

				local nameLbl = Instance.new("TextLabel", bb)
				nameLbl.Size = UDim2.new(1,0,0.55,0)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Font = Enum.Font.GothamBold
				nameLbl.TextSize = 12
				nameLbl.TextStrokeTransparency = 0.3
				nameLbl.TextColor3 = col
				nameLbl.Text = tostring(r.cat or "Egg")

				local detailLbl = Instance.new("TextLabel", bb)
				detailLbl.Size = UDim2.new(1,0,0.45,0)
				detailLbl.Position = UDim2.new(0,0,0.55,0)
				detailLbl.BackgroundTransparency = 1
				detailLbl.Font = Enum.Font.Gotham
				detailLbl.TextSize = 10
				detailLbl.TextStrokeTransparency = 0.4
				detailLbl.TextColor3 = C_WHITE

				local parts = {}
				if hasRareTag then
					local upper = {}
					for _, t in ipairs(r.tags) do table.insert(upper, t:upper()) end
					table.insert(parts, table.concat(upper, "/"))
				end
				if r.weight then table.insert(parts, r.weight.."kg") end
				if not unlocked then
					local A = AREA[r.area]
					table.insert(parts, "LOCKED ".._shortNum(A and A.reqSP))
				end
				detailLbl.Text = #parts > 0 and table.concat(parts, "  ·  ") or tostring(r.area or "")

				table.insert(_espParts, p)
			end)
		end
	end)
end

makeRow(visualPage, "esp", "Egg ESP", function(on)
	if on then startESP() else stopESP() end
end)

-- ── FULLBRIGHT ──────────────────────────────────────────────
local _origBright = nil
local function startFullbright()
	_origBright = Lighting.Brightness
	Lighting.Brightness = 2
	Lighting.GlobalShadows = false
	Lighting.Ambient = Color3.fromRGB(200,200,200)
	Lighting.OutdoorAmbient = Color3.fromRGB(200,200,200)
end
local function stopFullbright()
	Lighting.Brightness = _origBright or 1
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(70,70,70)
	Lighting.OutdoorAmbient = Color3.fromRGB(100,100,100)
end

makeRow(visualPage, "fullbright", "Fullbright", function(on)
	if on then startFullbright() else stopFullbright() end
end)

-- ── FPS BOOST ───────────────────────────────────────────────
local function applyFpsBoost()
	pcall(function() setfpscap(9999) end)
	local function proc(v)
		pcall(function()
			if v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles")
				or v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
				v.Enabled = false
			elseif v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect")
				or v:IsA("DepthOfFieldEffect") then
				v:Destroy()
			elseif v:IsA("BasePart") then
				v.CastShadow = false
			end
		end)
	end
	for _, v in ipairs(workspace:GetDescendants()) do proc(v) end
	for _, v in ipairs(Lighting:GetDescendants()) do proc(v) end
	workspace.DescendantAdded:Connect(function(v) if St.fpsBoost then task.spawn(proc, v) end end)
end

makeRow(visualPage, "fpsBoost", "FPS Boost", function(on)
	if on then applyFpsBoost() end
end)

-- Simple FOV row
local _fovVal = 70
do
	local row = Instance.new("Frame", visualPage)
	row.Size = UDim2.new(1,-12,0,44)
	row.BackgroundColor3 = C_ROW; row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	label(row, "FOV", UDim2.new(0.6,0,0,20), C_WHITE, Enum.Font.GothamMedium).TextSize = 12
	local vl = label(row, "70°", UDim2.new(0.4,0,0,20), C_MOON, Enum.Font.GothamBold,
		Enum.TextXAlignment.Right)
	vl.TextSize = 12; vl.Position = UDim2.new(0.6,0,0,2)

	local track = Instance.new("Frame", row)
	track.Size = UDim2.new(1,0,0,6); track.Position = UDim2.new(0,0,1,-12)
	track.BackgroundColor3 = Color3.fromRGB(20,25,35); track.BorderSizePixel = 0; corner(track, 3)
	local fill = Instance.new("Frame", track)
	fill.Size = UDim2.new(0.4,0,1,0); fill.BackgroundColor3 = C_MOON
	fill.BorderSizePixel = 0; corner(fill, 3)

	local function setFOV(v)
		v = math.clamp(math.floor(v), 30, 130)
		_fovVal = v
		local t = (v - 30) / (130 - 30)
		fill.Size = UDim2.new(t, 0, 1, 0)
		vl.Text = v.."°"
		pcall(function() workspace.CurrentCamera.FieldOfView = v end)
	end
	local drag = false
	track.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end
	end)
	UIS.InputChanged:Connect(function(i)
		if not drag then return end
		if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
		local r = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		setFOV(30 + r * 100)
	end)
end

-- ── ANTI AFK ────────────────────────────────────────────────
local _afkConn = nil
local function stopAntiAFK()
	if _afkConn then _afkConn:Disconnect(); _afkConn = nil end
end
local function startAntiAFK()
	stopAntiAFK()
	local i = 0
	_afkConn = RunService.Heartbeat:Connect(function()
		if not St.antiAFK then return end
		i = i + 1
		if i % (30 * 60 * 15) == 0 then  -- every ~15 min @ 30fps-equivalent
			-- simulate a small movement
			local char = LP.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local cf = hrp.CFrame
				hrp.CFrame = cf * CFrame.new(0.01, 0, 0)
				task.wait(0.05)
				hrp.CFrame = cf
			end
			-- also fire the VirtualUser service if available
			pcall(function()
				local VU = game:GetService("VirtualUser")
				VU:CaptureController(); VU:ClickButton2(Vector2.new())
			end)
		end
	end)
end

-- antiAFK is on Misc page but visually better here
makeRow(visualPage, "antiAFK", "Anti AFK", function(on)
	if on then startAntiAFK() else stopAntiAFK() end
end)

-- ============================================================
-- ── PAGE: MISC ──────────────────────────────────────────────
-- ============================================================
local miscPage = pages["Misc"]

-- ── BYPASS ANTI-CHEAT (clone trick, safe swap) ──────────────
-- v2 fixes vs la version initiale :
--  1) _bypassActive ne se remettait jamais à false → le bypass ne
--     pouvait être appliqué qu'UNE seule fois par session. Remplacé
--     par un cooldown (ré-applicable, mais pas de spam-click qui
--     enchaînerait des swaps de Humanoid coup sur coup).
--  2) hum.Parent = nil détachait l'ancien Humanoid sans le détruire
--     (connexions internes laissées pendantes) + task.wait(0.1) créait
--     une fenêtre où le character n'a AUCUN Humanoid (autres boucles du
--     hub qui lisent FindFirstChildOfClass("Humanoid") tombent sur nil
--     pendant ce temps). Remplacé par un swap synchrone (clone d'abord,
--     Destroy() propre ensuite, zéro yield entre les deux).
--  3) clone.WalkSpeed = St.speed forçait la vitesse au moindre clic sur
--     Bypass, même si Speed Boost était OFF — un saut de vitesse
--     injustifié aux yeux d'un anti-cheat, et de toute façon inutile
--     depuis le passage à la vitesse par proxy (WalkSpeed n'est plus lu
--     nulle part dans le hub). Supprimé : Clone() recopie déjà la bonne
--     valeur telle quelle, rien à réécrire.
--  4) CameraSubject n'était jamais restauré après le swap → la caméra
--     pouvait rester figée sur l'ancien Humanoid détruit. Ajouté.
--  5) Les contrôles (WASD/tactile) du PlayerModule restent liés à
--     l'ancien Humanoid après un swap → ré-activation via le même motif
--     déjà utilisé et testé par Anti Ragdoll plus haut dans ce fichier.
local _bypassActive    = false  -- true pendant le swap (garde anti-réentrance)
local _bypassCooldown  = 0
local _bypassOn         = false  -- état logique du toggle (ON = swap appliqué)
local _bypassPillRefresh = nil   -- rempli plus bas ; permet au bouton flottant de resynchroniser le pill de l'onglet Misc
-- [BUGFIX] _floatBtns est déclaré PLUS BAS dans ce fichier — une closure
-- créée ici et exécutée plus tard (CharacterAdded) ne capture PAS la
-- variable locale future : elle résoudrait vers une globale toujours
-- nil (même piège que documenté ailleurs dans ce fichier pour
-- refreshUIToggles/mainFrame). Donc pas de référence directe à
-- _floatBtns ici — on passe par ce slot, rempli quand le bouton
-- flottant "bypass" est construit plus bas.
local _bypassFloatRefresh = nil
local BYPASS_COOLDOWN_S = 5

local function applyBypass()
	if _bypassActive then return false end
	local now = tick()
	if now - _bypassCooldown < BYPASS_COOLDOWN_S then
		local left = math.ceil(BYPASS_COOLDOWN_S - (now - _bypassCooldown))
		setStatus("Bypass: attendre "..left.."s", C_DIM)
		return false
	end
	local char = LP.Character
	local oldHum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not oldHum then
		setStatus("Bypass: pas de character", C_RED)
		return false
	end
	_bypassActive = true
	local ok = pcall(function()
		local cam = workspace.CurrentCamera
		local wasSubject = cam and cam.CameraSubject == oldHum

		-- Clone() recopie déjà toutes les propriétés actuelles
		-- (WalkSpeed, JumpPower, HipHeight, Animator inclus) — rien à
		-- réécrire manuellement.
		local clone = oldHum:Clone()
		clone.Parent = char

		-- Destroy() propre : coupe les connexions internes de l'ancien
		-- Humanoid au lieu de le laisser pendouiller, et déclenche
		-- .Destroying pour tout script du jeu qui l'observerait.
		oldHum:Destroy()

		-- Restaure la cible caméra si elle pointait sur l'ancien Humanoid
		-- (sinon la caméra reste figée sur une instance détruite).
		if cam and wasSubject then cam.CameraSubject = clone end

		-- Ré-active les contrôles WASD/tactile sur le nouveau Humanoid.
		pcall(function()
			local pm = LP:FindFirstChild("PlayerScripts")
			local cm = pm and pm:FindFirstChild("PlayerModule")
			if cm then require(cm:FindFirstChild("ControlModule")):Enable() end
		end)
	end)
	_bypassActive = false
	_bypassCooldown = tick()
	if ok then
		setStatus("Bypass applique", C_GREEN)
	else
		setStatus("Bypass echec — voir console", C_RED)
	end
	task.delay(3, function()
		if not _bypassActive then setStatus("Idle", C_DIM) end
	end)
	return ok
end

-- ── RETIRER LE BYPASS ────────────────────────────────────────
-- Le clone-swap est une opération instantanée à sens unique — l'ancien
-- Humanoid est détruit, il n'y a donc RIEN à littéralement "annuler".
-- La seule façon honnête de revenir à un état 100% propre (pas un
-- clone, un Humanoid tout neuf généré par le jeu lui-même) est un
-- respawn contrôlé : humanoid.Health = 0 déclenche le flux de mort/
-- reset normal du jeu, exactement comme le bouton "Respawn Character"
-- séparé de la source d'origine. Même cooldown que l'apply pour éviter
-- un spam de respawns.
local function removeBypass()
	if _bypassActive then return false end
	local now = tick()
	if now - _bypassCooldown < BYPASS_COOLDOWN_S then
		local left = math.ceil(BYPASS_COOLDOWN_S - (now - _bypassCooldown))
		setStatus("Bypass: attendre "..left.."s", C_DIM)
		return false
	end
	local char = LP.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		setStatus("Bypass: pas de character", C_RED)
		return false
	end
	_bypassCooldown = tick()
	local ok = pcall(function() hum.Health = 0 end)
	if ok then
		setStatus("Bypass retire (respawn)", C_MOON2)
	else
		setStatus("Retrait echec — voir console", C_RED)
	end
	task.delay(3, function() setStatus("Idle", C_DIM) end)
	return ok
end

do
	local row = Instance.new("Frame", miscPage)
	row.Size = UDim2.new(1,-12,0,30)
	row.BackgroundColor3 = C_ROW; row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	label(row, "Bypass Anti-Cheat", UDim2.new(1,-50,1,0), C_WHITE, Enum.Font.GothamMedium).TextSize = 12
	local pill = Instance.new("TextButton", row)
	pill.Size = UDim2.new(0,44,0,18)
	pill.Position = UDim2.new(1,-44,0.5,-9)
	pill.BorderSizePixel = 0; pill.TextSize = 10; pill.Font = Enum.Font.GothamBold
	corner(pill, 9)
	local function refresh()
		pill.BackgroundColor3 = _bypassOn and C_ON_BG or C_OFF_BG
		pill.TextColor3 = _bypassOn and C_MOON or C_DIM
		pill.Text = _bypassOn and "ON" or "OFF"
		row.BackgroundColor3 = _bypassOn and Color3.fromRGB(10,18,32) or C_ROW
	end
	refresh()
	_bypassPillRefresh = refresh
	-- ON → applique le swap. OFF → respawn propre (seule vraie façon
	-- de "retirer" un clone-swap déjà appliqué). Le pill ne change
	-- d'état que si l'action a réellement réussi.
	pill.MouseButton1Click:Connect(function()
		if not _bypassOn then
			if applyBypass() then _bypassOn = true; refresh() end
		else
			if removeBypass() then _bypassOn = false; refresh() end
		end
	end)

	-- Respawn depuis le jeu = un Humanoid tout neuf, plus de bypass actif.
	LP.CharacterAdded:Connect(function()
		_bypassOn = false
		refresh()
		if _bypassFloatRefresh then _bypassFloatRefresh(false) end
	end)
end

-- ── TP TO COORDS ─────────────────────────────────────────────
do
	local row = Instance.new("Frame", miscPage)
	row.Size = UDim2.new(1,-12,0,30)
	row.BackgroundColor3 = C_ROW; row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	label(row, "TP to Spawn", UDim2.new(1,-60,1,0), C_WHITE, Enum.Font.GothamMedium).TextSize = 12
	local btn = Instance.new("TextButton", row)
	btn.Size = UDim2.new(0,54,0,18)
	btn.Position = UDim2.new(1,-54,0.5,-9)
	btn.BackgroundColor3 = C_ON_BG; btn.TextColor3 = C_MOON
	btn.Text = "Go"; btn.TextSize = 10; btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0; corner(btn, 9)
	btn.MouseButton1Click:Connect(function()
		pcall(function()
			local char = LP.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			local spawn = workspace:FindFirstChild("SpawnLocation")
			if hrp and spawn then
				hrp.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
			end
		end)
	end)
end

-- ── GO TO MAIN STAND / STOP MOVEMENT ─────────────────────────
-- Coordonnées exactes retrouvées dans la source d'origine du jeu
-- (point de retour "stand" — shop/zone principale). Tween linéaire
-- à vitesse constante (350 studs/s) façon la source d'origine, pas
-- une téléportation instantanée — moins susceptible de déclencher
-- un anti-cheat basé sur la distance parcourue par frame.
local _mainStandTween = nil
do
	local MAIN_STAND_CF = CFrame.new(544.577637, 92.0762939, -364.869049, -1,0,0, 0,1,0, 0,0,-1)

	local row = Instance.new("Frame", miscPage)
	row.Size = UDim2.new(1,-12,0,30)
	row.BackgroundColor3 = C_ROW; row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	label(row, "Go To Main Stand", UDim2.new(1,-60,1,0), C_WHITE, Enum.Font.GothamMedium).TextSize = 12
	local btn = Instance.new("TextButton", row)
	btn.Size = UDim2.new(0,54,0,18)
	btn.Position = UDim2.new(1,-54,0.5,-9)
	btn.BackgroundColor3 = C_ON_BG; btn.TextColor3 = C_MOON
	btn.Text = "Go"; btn.TextSize = 10; btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0; corner(btn, 9)
	btn.MouseButton1Click:Connect(function()
		local char = LP.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not rootPart then return end
		if _mainStandTween then _mainStandTween:Cancel() end

		local dist = (rootPart.Position - MAIN_STAND_CF.Position).Magnitude
		local travelTime = math.max(dist / 350, 0.1)
		_mainStandTween = TweenService:Create(rootPart,
			TweenInfo.new(travelTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{CFrame = MAIN_STAND_CF})
		_mainStandTween.Completed:Connect(function()
			if hum then
				pcall(function()
					hum:ChangeState(Enum.HumanoidStateType.Landed)
					hum.PlatformStand = false
				end)
			end
		end)
		_mainStandTween:Play()
		setStatus("Retour au spawn...", C_MOON2)
	end)

	local row2 = Instance.new("Frame", miscPage)
	row2.Size = UDim2.new(1,-12,0,30)
	row2.BackgroundColor3 = C_ROW; row2.BorderSizePixel = 0; corner(row2, 6)
	local pad2 = Instance.new("UIPadding", row2)
	pad2.PaddingLeft = UDim.new(0,8); pad2.PaddingRight = UDim.new(0,8)
	label(row2, "Stop Movement", UDim2.new(1,-60,1,0), C_WHITE, Enum.Font.GothamMedium).TextSize = 12
	local btn2 = Instance.new("TextButton", row2)
	btn2.Size = UDim2.new(0,54,0,18)
	btn2.Position = UDim2.new(1,-54,0.5,-9)
	btn2.BackgroundColor3 = Color3.fromRGB(60,15,15); btn2.TextColor3 = C_RED
	btn2.Text = "Stop"; btn2.TextSize = 10; btn2.Font = Enum.Font.GothamBold
	btn2.BorderSizePixel = 0; corner(btn2, 9)
	btn2.MouseButton1Click:Connect(function()
		if _mainStandTween then
			_mainStandTween:Cancel(); _mainStandTween = nil
			local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.PlatformStand = false end
			setStatus("Mouvement arrete", C_DIM)
		end
	end)
end

-- ── INF JUMP ────────────────────────────────────────────────
local _ijConn = nil
do
	local _infJumpOn = false
	local row = Instance.new("Frame", miscPage)
	row.Size = UDim2.new(1,-12,0,30)
	row.BackgroundColor3 = C_ROW; row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	label(row, "Infinite Jump", UDim2.new(1,-50,1,0), C_WHITE, Enum.Font.GothamMedium).TextSize = 12
	local pill = Instance.new("TextButton", row)
	pill.Size = UDim2.new(0,44,0,18)
	pill.Position = UDim2.new(1,-44,0.5,-9)
	pill.BorderSizePixel = 0; pill.TextSize = 10; pill.Font = Enum.Font.GothamBold
	corner(pill, 9)
	local function rfr()
		pill.BackgroundColor3 = _infJumpOn and C_ON_BG or C_OFF_BG
		pill.TextColor3 = _infJumpOn and C_MOON or C_DIM
		pill.Text = _infJumpOn and "ON" or "OFF"
		row.BackgroundColor3 = _infJumpOn and Color3.fromRGB(10,18,32) or C_ROW
	end
	rfr()
	pill.MouseButton1Click:Connect(function()
		_infJumpOn = not _infJumpOn; rfr()
		if _infJumpOn then
			if _ijConn then _ijConn:Disconnect() end
			_ijConn = UIS.JumpRequest:Connect(function()
				local char = LP.Character
				local hum  = char and char:FindFirstChildOfClass("Humanoid")
				if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
			end)
		else
			if _ijConn then _ijConn:Disconnect(); _ijConn = nil end
		end
	end)
end

-- ── CLICK TP ──────────────────────────────────────────────────
-- Toggle : une fois actif, chaque clic gauche dans le monde (pas sur
-- l'UI — filtré via gameProcessedEvent) téléporte le joueur à l'endroit
-- visé. Mouse.Hit fait le raycast caméra→souris (méthode native
-- PlayerMouse, pas de Raycast manuel nécessaire). La rotation du
-- personnage est conservée (CFrame.Rotation), seule la position change.
local _clickTpConn = nil
local function stopClickTp()
	if _clickTpConn then _clickTpConn:Disconnect(); _clickTpConn = nil end
end
local function startClickTp()
	stopClickTp()
	local mouse = LP:GetMouse()
	_clickTpConn = UIS.InputBegan:Connect(function(inp, gameProcessed)
		if gameProcessed then return end
		if not St.clickTp then return end
		if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local char = LP.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local target = mouse.Hit
		if not target then return end
		pcall(function()
			hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0)) * hrp.CFrame.Rotation
		end)
		setStatus("Click TP →", C_GREEN)
	end)
end

makeRow(miscPage, "clickTp", "Click TP", function(on)
	if on then startClickTp() else stopClickTp(); setStatus("Click TP OFF", C_DIM) end
end)

-- ── REJOIN ───────────────────────────────────────────────────
do
	local row = Instance.new("Frame", miscPage)
	row.Size = UDim2.new(1,-12,0,30)
	row.BackgroundColor3 = C_ROW; row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	label(row, "Rejoin Server", UDim2.new(1,-60,1,0), C_WHITE, Enum.Font.GothamMedium).TextSize = 12
	local btn = Instance.new("TextButton", row)
	btn.Size = UDim2.new(0,54,0,18)
	btn.Position = UDim2.new(1,-54,0.5,-9)
	btn.BackgroundColor3 = Color3.fromRGB(60,15,15); btn.TextColor3 = C_RED
	btn.Text = "Rejoin"; btn.TextSize = 10; btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0; corner(btn, 9)
	btn.MouseButton1Click:Connect(function()
		pcall(function()
			game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
		end)
	end)
end

-- ── COPY PLAYER ID ──────────────────────────────────────────
do
	local row = Instance.new("Frame", miscPage)
	row.Size = UDim2.new(1,-12,0,30)
	row.BackgroundColor3 = C_ROW; row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	label(row, "Copy Player ID", UDim2.new(1,-60,1,0), C_WHITE, Enum.Font.GothamMedium).TextSize = 12
	local btn = Instance.new("TextButton", row)
	btn.Size = UDim2.new(0,54,0,18)
	btn.Position = UDim2.new(1,-54,0.5,-9)
	btn.BackgroundColor3 = C_ON_BG; btn.TextColor3 = C_MOON
	btn.Text = "Copy"; btn.TextSize = 10; btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0; corner(btn, 9)
	btn.MouseButton1Click:Connect(function()
		pcall(function()
			setclipboard(tostring(LP.UserId))
			setStatus("ID copied: "..LP.UserId, C_GREEN)
			task.delay(2, function() setStatus("Idle", C_DIM) end)
		end)
	end)
end

-- ============================================================
-- DRAG
-- ============================================================
do
	local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
	header.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = inp.Position
			startPos = main.Position
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	header.InputChanged:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragInput = inp
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if inp == dragInput and dragging then
			local delta = inp.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- ============================================================
-- MINIMIZE / CLOSE
-- ============================================================
local minimized = false
local fullHeight = 330
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		TweenService:Create(main, TweenInfo.new(0.2), {Size=UDim2.new(0,240,0,36)}):Play()
		contentArea.Visible = false; sep.Visible = false; tabBar.Visible = false; statusBar.Visible = false
		minBtn.Text = "+"
	else
		TweenService:Create(main, TweenInfo.new(0.2), {Size=UDim2.new(0,240,0,fullHeight)}):Play()
		contentArea.Visible = true; sep.Visible = true; tabBar.Visible = true; statusBar.Visible = true
		minBtn.Text = "–"
	end
end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- ============================================================
-- KEYBIND: RightShift → toggle visibility
-- ============================================================
UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.RightShift then
		St.guiVisible = not St.guiVisible
		main.Visible = St.guiVisible
	end
end)

-- ============================================================
-- DEFAULT TAB
-- ============================================================
switchTab("Farm")

-- ============================================================
-- AIM BAT — portage exact de "AB" (Bat Aimbot V1) de Moon Hub :
-- même HEIGHT (3.7), même distance de frappe (5), même cooldown
-- swing (0.2s), même formule de prédiction vélocité + lookVector,
-- même formule Y (poursuite + clamp au sol), même rotation par
-- AssemblyAngularVelocity (clamp ±2.5 rad puis *42).
-- SPEED n'est PAS fixe (58 chez Moon Hub) : elle est lue en direct
-- sur St.speed — le même slider "Walk Speed" de l'onglet Speed —
-- pour que la vitesse de poursuite de l'aimbot suive toujours la
-- vitesse choisie par l'utilisateur.
-- ============================================================
local AB_HEIGHT   = 3.7
local AB_HIT_DIST = 5
local AB_HIT_CD   = false

-- Noms de bat/gear connus (mêmes que Moon Hub — le jeu utilise déjà
-- la convention "Slap" côté GearGiver, confirmé par l'analyse).
-- Liste exacte prioritaire (motif Moon Hub) + repli substring (voir
-- _abIsBatName) — la liste seule ratait tout tool nommé différemment
-- dans ce jeu précis (ex: "FieldBat", entrevu dans le rapport
-- d'analyse via RF/Codex/AskWearFieldBat).
local BAT_NAMES = {
	"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap",
	"Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap",
	"Galaxy Slap","Glitched Slap","FieldBat","Field Bat",
}

-- Vrai si le nom du tool ressemble à un bat/gear de frappe — testé sur
-- la liste exacte D'ABORD (rapide, pas de faux positif), puis en
-- repli sur un test de sous-chaîne "bat"/"slap" (attrape les variantes
-- non listées, ex: "FieldBat_v2" ou un nom localisé).
local function _abIsBatName(name)
	if not name then return false end
	for _, n in ipairs(BAT_NAMES) do
		if name == n then return true end
	end
	local lower = name:lower()
	return lower:find("bat", 1, true) ~= nil or lower:find("slap", 1, true) ~= nil
end

-- Cherche un bat déjà équipé (Character) EN PREMIER, puis dans le
-- Backpack — priorité à la liste exacte, repli substring sur les deux.
local function _abGetBat()
	local char = LP.Character; if not char then return nil end
	for _, name in ipairs(BAT_NAMES) do
		local t = char:FindFirstChild(name)
		if t and t:IsA("Tool") then return t end
	end
	local bp = LP:FindFirstChildOfClass("Backpack")
	if bp then
		for _, name in ipairs(BAT_NAMES) do
			local t = bp:FindFirstChild(name)
			if t and t:IsA("Tool") then return t end
		end
	end
	-- Repli substring : n'importe quel Tool dont le nom contient bat/slap
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
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
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
			local tr  = plr.Character:FindFirstChild("HumanoidRootPart")
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			if tr and hum and hum.Health > 0 then
				local d = (tr.Position - root.Position).Magnitude
				if d < minDist then minDist = d; closest = plr end
			end
		end
	end
	return closest, minDist
end

local _aimBatActive = false
local _aimBatConn    = nil

local function startAimBat()
	_aimBatActive = true
	if _aimBatConn then _aimBatConn:Disconnect() end
	local hum0 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if hum0 then hum0.AutoRotate = false end
	_aimBatConn = RunService.RenderStepped:Connect(function()
		if not _aimBatActive then return end
		local char = LP.Character; if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
		local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
		-- [FIX] L'ancienne condition ("si AUCUN tool équipé") ne rééquipait
		-- jamais le bat si un AUTRE tool était déjà en main — l'aimbot
		-- pouvait tourner indéfiniment sans jamais "prendre" le bat.
		-- Vérifie maintenant spécifiquement si le tool équipé EST le bat.
		local equipped = char:FindFirstChildOfClass("Tool")
		if not (equipped and _abIsBatName(equipped.Name)) then
			local bat = _abGetBat()
			if bat then pcall(function() hum:EquipTool(bat) end) end
		end
		local target, dist = _abGetClosest()
		if not target or not target.Character then return end
		local tr = target.Character:FindFirstChild("HumanoidRootPart"); if not tr then return end

		local targetVel = tr.AssemblyLinearVelocity
		local myPos, targetPos = root.Position, tr.Position
		local predictPos = targetPos + targetVel * 0.14 + tr.CFrame.LookVector * 0.3
		local direction  = predictPos - myPos
		local flatDir    = Vector3.new(direction.X, 0, direction.Z).Unit
		local desiredHeight = targetPos.Y + AB_HEIGHT
		local yVel = (desiredHeight - myPos.Y) * 19.5 + targetVel.Y * 0.8
		if hum.FloorMaterial ~= Enum.Material.Air then yVel = math.max(yVel, 13) end
		yVel = math.clamp(yVel, -70, 110)
		local pursuitSpeed = St.speed
		local desiredVel = Vector3.new(flatDir.X * pursuitSpeed, yVel, flatDir.Z * pursuitSpeed)
		root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)

		local speed3 = targetVel.Magnitude
		local predictTime = math.clamp(speed3 / 150, 0.05, 0.2)
		local predictedPos = targetPos + targetVel * predictTime
		local toPredict = predictedPos - myPos
		if toPredict.Magnitude > 0.1 then
			local goalCF = CFrame.lookAt(myPos, predictedPos)
			local diffCF = root.CFrame:Inverse() * goalCF
			local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
			rx = math.clamp(rx, -2.5, 2.5); ry = math.clamp(ry, -2.5, 2.5); rz = math.clamp(rz, -2.5, 2.5)
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
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if root then root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end
	if hum then hum.AutoRotate = true end
end

-- ============================================================
-- FLOATING BUTTONS (Moon Hub style, right side)
-- ============================================================
local FLOAT_SZ  = 46
local FLOAT_GAP = 8
local FLOAT_TOP = 80  -- vertical start (below top bar)
local FLOAT_RIGHT_OFF = 12  -- offset from right edge

-- Float button definitions: {id, label, onClick (toggle), isToggle}
local _floatDefs = {
	{ id = "speed",   label = "Speed",   isToggle = true },
	{ id = "aimbat",  label = "Aim\nBat", isToggle = true },
	{ id = "bypass",  label = "Bypass",  isToggle = false },
	{ id = "lock",    label = "Lock",    isToggle = true },
}

-- Gèle le drag de TOUS les boutons flottants (y compris lui-même une fois
-- verrouillé) — même mécanique que le "Lock" de Moon Hub.
local _floatLocked = false

local _floatBtns = {}  -- id -> { btn, setActive, getActive }

local function makeFloatBtn(defIdx, def)
	local col = (defIdx - 1) % 2
	local row = math.floor((defIdx - 1) / 2)
	local xOff = -(FLOAT_SZ * 2 + FLOAT_GAP + FLOAT_RIGHT_OFF) + col * (FLOAT_SZ + FLOAT_GAP)
	local yOff = FLOAT_TOP + row * (FLOAT_SZ + FLOAT_GAP)

	local btn = Instance.new("TextButton", gui)
	btn.Name = "YE_Float_"..def.id
	btn.Size = UDim2.new(0, FLOAT_SZ, 0, FLOAT_SZ)
	btn.Position = UDim2.new(1, xOff, 0, yOff)
	btn.BackgroundColor3 = C_ROW
	btn.BackgroundTransparency = 0
	btn.BorderSizePixel = 0
	btn.Text = ""; btn.AutoButtonColor = false
	btn.ZIndex = 500; btn.Active = true
	corner(btn, 14)
	-- living stroke
	local st2 = Instance.new("UIStroke", btn)
	st2.Thickness = 1.5
	st2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local stGrad = Instance.new("UIGradient", st2)
	stGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(4,7,16)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(14,28,58)),
		ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(4,7,16)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(14,28,58)),
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(4,7,16)),
	})
	table.insert(_liveGrads, stGrad)

	-- label
	local lbl2 = Instance.new("TextLabel", btn)
	lbl2.Size = UDim2.new(1,0,1,0)
	lbl2.BackgroundTransparency = 1
	lbl2.Text = def.label
	lbl2.TextColor3 = C_WHITE
	lbl2.Font = Enum.Font.GothamBold
	lbl2.TextScaled = false; lbl2.TextSize = 9; lbl2.TextWrapped = true
	lbl2.ZIndex = btn.ZIndex + 1
	local lGrad = Instance.new("UIGradient", lbl2)
	lGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(40,80,165)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(90,150,255)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(160,210,255)),
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(40,80,165)),
	})
	table.insert(_liveGrads, lGrad)
	local lPad = Instance.new("UIPadding", lbl2)
	lPad.PaddingLeft = UDim.new(0,4); lPad.PaddingRight = UDim.new(0,4)
	lPad.PaddingTop = UDim.new(0,3);  lPad.PaddingBottom = UDim.new(0,3)

	-- active dot (top-right corner, green)
	local dot = Instance.new("Frame", btn)
	dot.Name = "Dot"
	dot.Size = UDim2.new(0,9,0,9)
	dot.Position = UDim2.new(1,-13,0,4)
	dot.BackgroundColor3 = Color3.fromRGB(80,230,120)
	dot.BorderSizePixel = 0
	dot.ZIndex = lbl2.ZIndex + 1
	dot.Visible = false
	corner(dot, 5)

	local _active = false
	local function setActive(on)
		_active = on
		btn.BackgroundColor3 = on and C_ON_BG or C_ROW
		dot.Visible = on
		if on then
			dot.Size = UDim2.new(0,4,0,4)
			dot.Position = UDim2.new(1,-10.5,0,8.5)
			TweenService:Create(dot, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0,9,0,9), Position = UDim2.new(1,-13,0,4),
			}):Play()
		end
	end

	-- drag (désactivé quand _floatLocked est actif)
	local drag2, dStart, dPos2 = false, nil, nil
	btn.InputBegan:Connect(function(inp)
		if _floatLocked then return end
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			drag2 = true; dStart = inp.Position; dPos2 = btn.Position
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if not drag2 then return end
		if inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch then
			local delta = inp.Position - dStart
			btn.Position = UDim2.new(dPos2.X.Scale, dPos2.X.Offset + delta.X,
				dPos2.Y.Scale, dPos2.Y.Offset + delta.Y)
		end
	end)
	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			drag2 = false
		end
	end)

	_floatBtns[def.id] = { btn = btn, setActive = setActive, getActive = function() return _active end }
	return btn, setActive
end

-- Build float buttons
for i, def in ipairs(_floatDefs) do
	local _, setAct = makeFloatBtn(i, def)

	if def.id == "speed" then
		_floatBtns["speed"].btn.MouseButton1Click:Connect(function()
			speedOn = not speedOn
			if speedOn then startSpeed() else stopSpeed() end
			setAct(speedOn)
			speedRefresh()  -- sync the in-panel pill too
		end)

	elseif def.id == "aimbat" then
		_floatBtns["aimbat"].btn.MouseButton1Click:Connect(function()
			_aimBatActive = not _aimBatActive
			setAct(_aimBatActive)
			if _aimBatActive then startAimBat()
			else stopAimBat() end
		end)

	elseif def.id == "bypass" then
		-- Même toggle que la row de l'onglet Misc (ON = clone-swap
		-- appliqué, OFF = respawn propre) — le dot reste allumé tant
		-- que le bypass est actif, plus un simple flash cosmétique.
		_bypassFloatRefresh = setAct
		_floatBtns["bypass"].btn.MouseButton1Click:Connect(function()
			if not _bypassOn then
				if applyBypass() then
					_bypassOn = true
					if _bypassPillRefresh then _bypassPillRefresh() end
				end
			else
				if removeBypass() then
					_bypassOn = false
					if _bypassPillRefresh then _bypassPillRefresh() end
				end
			end
			setAct(_bypassOn)
		end)

	elseif def.id == "lock" then
		-- Le clic reste toujours actif (MouseButton1Click est indépendant du
		-- drag InputBegan) — on peut donc toujours re-cliquer Lock pour se
		-- déverrouiller, même quand tous les boutons sont gelés.
		_floatBtns["lock"].btn.MouseButton1Click:Connect(function()
			_floatLocked = not _floatLocked
			setAct(_floatLocked)
			setStatus(_floatLocked and "Boutons verrouilles" or "Boutons deverrouilles", C_MOON2)
		end)
	end
end

print("[yslemEgg] Loaded — RightShift hide/show | Float btns: Speed, AimBat, Bypass, Lock")
