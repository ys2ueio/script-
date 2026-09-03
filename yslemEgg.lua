-- ============================================================
-- yslemEgg — Best Egg + Teleport (compact hub)
-- ============================================================
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ys2ueio/script-/refs/heads/main/yslemEgg.lua"))()
--
-- v2: the previous scanner assumed an "EggWorld remote / AreaEggSlotsClient"
-- structure that doesn't exist in this game — nothing was ever detected.
-- Rebuilt on the SAME structure yslem_hub.lua already uses successfully
-- here: workspace.Plots.<plot>.AnimalPodiums.<pod> — pod.Name IS the
-- pet/brainrot identity (exactly what the reference hub shows: name +
-- rarity + $ value, read directly off the podium before you even steal
-- it — that's "repérer le pet dans l'oeuf").

if not game:IsLoaded() then game.Loaded:Wait() end

local Players       = game:GetService("Players")
local UIS           = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")
local LP = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

-- kill previous instance (clean relaunch)
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("yslemEggGui")
	if old then old:Destroy() end
	local old2 = LP.PlayerGui:FindFirstChild("yslemEggGui")
	if old2 then old2:Destroy() end
end)

-- ============================================================
-- RARITY / VALUE DETECTION
-- ============================================================
local _RARE_KEYWORDS = {
	"secret","eternal","divine","divin","mythic","celestial","ancient",
	"rainbow","golden","shiny","radiant","corrupted","void","legendary",
	"brainrot","og",
}
local _TIER = {
	secret=1, mythic=2, legendary=3, celestial=4, divine=5, divin=5,
	eternal=6, ancient=7, rainbow=8, radiant=9, golden=10, shiny=11,
	corrupted=12, void=13,
}
local RARITY_COLOR = {
	secret    = Color3.fromRGB(255, 205,  70),
	mythic    = Color3.fromRGB(255,  85, 120),
	legendary = Color3.fromRGB(255, 150,  45),
	celestial = Color3.fromRGB(140, 210, 255),
	divine    = Color3.fromRGB(255, 240, 205),
	divin     = Color3.fromRGB(255, 240, 205),
	eternal   = Color3.fromRGB(200, 160, 255),
	ancient   = Color3.fromRGB(190, 150, 100),
	rainbow   = Color3.fromRGB(255, 255, 255),
	radiant   = Color3.fromRGB(255, 255, 150),
	golden    = Color3.fromRGB(255, 215,  60),
	shiny     = Color3.fromRGB(200, 255, 255),
	corrupted = Color3.fromRGB(170,  70, 210),
	void      = Color3.fromRGB(120,  60, 170),
}
local COMMON_COLOR = Color3.fromRGB(150, 150, 158)

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

-- Reads the $ value shown near an egg/pet (e.g. "$578.02K") off any
-- descendant TextLabel — this is the exact readout the reference hub
-- displays, and the primary ranking signal (real worth, not a guess).
local _SUFFIX_MULT = {K=1e3, M=1e6, B=1e9, T=1e12}
local function _extractMoneyText(root)
	local bestTxt, bestVal = nil, -1
	pcall(function()
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("TextLabel") and d.Text ~= "" then
				local txt = d.Text
				local num, suf = txt:match("%$([%d][%d%.,]*)%s*([KMBTkmbt]?)")
				if not num then num, suf = txt:match("([%d][%d%.,]*)%s*([KMBT])") end
				if num then
					local n = tonumber((num:gsub(",", "")))
					if n then
						local mult = (suf and suf ~= "") and (_SUFFIX_MULT[suf:upper()] or 1) or 1
						local val = n * mult
						if val > bestVal then
							bestVal = val
							bestTxt = txt:match("%$?[%d][%d%.,]*%s*[KMBTkmbt]?") or txt
						end
					end
				end
			end
		end
	end)
	if bestTxt then return bestTxt, bestVal end
	return nil, nil
end

-- Scans a model/part for any image ID (decals, textures, ImageLabels, mesh textures).
local function _getEggImageId(root)
	if not root then return nil end
	local id = nil
	pcall(function()
		for _, attr in ipairs({"Thumbnail","Icon","Image","ImageId","TextureId","EggIcon"}) do
			local v = root:GetAttribute(attr)
			if type(v) == "string" and v ~= "" then id = v; return end
		end
		for _, d in ipairs(root:GetDescendants()) do
			if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" then
				id = d.Image; return
			end
			if (d:IsA("Decal") or d:IsA("Texture")) and d.Texture ~= "" then
				id = d.Texture; return
			end
			if d:IsA("SpecialMesh") and d.TextureId ~= "" then
				id = d.TextureId; return
			end
		end
	end)
	return id
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

-- ============================================================
-- EGG / PET SCANNER
-- Source 1 (primary): workspace.Plots.<plot>.AnimalPodiums.<pod>
--   — same structure yslem_hub.lua's AutoSteal already relies on in
--   this game. pod.Name = pet identity, descendant TextLabels carry
--   rarity + $ value, Base.Spawn.PromptAttachment holds the steal prompt.
-- Source 2 (fallback): generic ProximityPrompt scan, for anything not
--   sitting on a podium (dropped eggs, other layouts).
-- ============================================================
local _plotIsMyCache = {}
local function _isMyPlot(plotName)
	local now = tick()
	local cached = _plotIsMyCache[plotName]
	if cached and (now - cached.t) < 2 then return cached.val end
	local plots = workspace:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild(plotName)
	local r = false
	if plot then
		local sign = plot:FindFirstChild("PlotSign")
		if sign then
			local yb = sign:FindFirstChild("YourBase")
			if yb and yb:IsA("BillboardGui") then r = yb.Enabled == true end
		end
	end
	_plotIsMyCache[plotName] = {val=r, t=now}
	return r
end

local cachedEggs = {}
local _lastScanFoundAny = false  -- surfaced in UI so "0 found" is honest, not silent
task.spawn(function()
	while true do
		local eggs = {}

		local function _upsertEgg(entry)
			for i, ex in ipairs(eggs) do
				if (ex.pos - entry.pos).Magnitude < 4 then
					if entry.farmable and not ex.farmable then eggs[i] = entry end
					return false
				end
			end
			table.insert(eggs, entry)
			return true
		end

		-- Source 1: Plots -> AnimalPodiums (proven structure, primary)
		pcall(function()
			local plots = workspace:FindFirstChild("Plots")
			if not plots then return end
			for _, plot in ipairs(plots:GetChildren()) do
				if not _isMyPlot(plot.Name) then
					local podiums = plot:FindFirstChild("AnimalPodiums")
					if podiums then
						for _, pod in ipairs(podiums:GetChildren()) do
							pcall(function()
								local base = pod:FindFirstChild("Base")
								local spawn = base and base:FindFirstChild("Spawn")
								if not spawn then return end
								local att = spawn:FindFirstChild("PromptAttachment")
								local prompt = nil
								if att then
									for _, child in ipairs(att:GetChildren()) do
										if child:IsA("ProximityPrompt") then prompt = child; break end
									end
								end
								if not prompt then return end
								local _, tags, weight = _readEggLabels(pod)
								local valueText, valueNum = _extractMoneyText(pod)
								_upsertEgg({
									pos=spawn.Position, cf=spawn.CFrame, area=plot.Name,
									cat=pod.Name, tags=tags, weight=weight,
									value=valueNum, valueText=valueText,
									uid=tostring(prompt), farmable=true,
									imageId=_getEggImageId(pod), prompt=prompt,
								})
							end)
						end
					end
				end
			end
		end)

		-- Source 2: generic ProximityPrompt fallback
		pcall(function()
			for _, prompt in ipairs(workspace:GetDescendants()) do
				if prompt:IsA("ProximityPrompt") then
					local action = prompt.ActionText:lower()
					local objTxt = prompt.ObjectText:lower()
					local parentName = (prompt.Parent and prompt.Parent.Name or ""):lower()
					local isSellPrompt = action:find("sell",1,true) or objTxt:find("sell",1,true)
						or action:find("vend",1,true) or objTxt:find("vend",1,true)
					local isDropPrompt = action:find("drop",1,true) or objTxt:find("drop",1,true)
					if not isSellPrompt and not isDropPrompt and (action:find("grab") or action:find("steal") or action:find("take")
						or action:find("pick") or action:find("collect") or action:find("hatch")
						or action:find("claim") or action:find("harvest")
						or objTxt:find("egg") or parentName:find("egg") or parentName:find("field") or parentName:find("slot")) then
						local part, model = _promptOwnerModel(prompt)
						if part then
							local _, tags3, weight3 = _readEggLabels(model or part)
							local valueText3, valueNum3 = _extractMoneyText(model or part)
							local cat3 = (model and model.Name ~= "Model" and model.Name)
								or (tags3[1] and tags3[1]:upper())
								or (objTxt ~= "" and prompt.ObjectText) or part.Name
							_upsertEgg({
								pos=part.Position, cf=part.CFrame, area="Trouve", cat=cat3,
								tags=tags3, weight=weight3, value=valueNum3, valueText=valueText3,
								uid=tostring(prompt), farmable=true,
								imageId=_getEggImageId(model or part), prompt=prompt,
							})
						end
					end
				end
			end
		end)

		cachedEggs = eggs
		_lastScanFoundAny = (#eggs > 0)
		task.wait(0.75)
	end
end)

-- ============================================================
-- RANKING — real $ value first (matches the reference hub), then
-- rarity tier, then kg weight as a last resort tiebreaker.
-- ============================================================
local function tierOf(entry)
	local best = 99
	if entry.tags then
		for _, t in ipairs(entry.tags) do
			local v = _TIER[t]
			if v and v < best then best = v end
		end
	end
	return best
end
local function rankEggs()
	local list = {}
	for _, e in ipairs(cachedEggs) do list[#list+1] = e end
	table.sort(list, function(a, b)
		local va, vb = a.value or -1, b.value or -1
		if va ~= vb then return va > vb end
		local ta, tb = tierOf(a), tierOf(b)
		if ta ~= tb then return ta < tb end
		local wa = tonumber((a.weight or ""):gsub(",", "")) or 0
		local wb = tonumber((b.weight or ""):gsub(",", "")) or 0
		return wa > wb
	end)
	return list
end

local _selectedUid = nil  -- nil = auto (#1); set = manual pick
local function currentTarget(ranked)
	if _selectedUid then
		for _, e in ipairs(ranked) do
			if e.uid == _selectedUid then return e end
		end
	end
	return ranked[1]
end

-- ============================================================
-- TELEPORT — Moon Hub bat method
-- CFrame teleport -> InputHoldBegin -> fireproximityprompt (same
-- pattern as yslem_hub.lua tryStealOnce). Fires the EXACT prompt
-- captured during scanning when we have it (more reliable than a
-- fresh nearby search), falls back to a generic search otherwise.
-- ============================================================
local function _fireStealPrompt(prompt)
	if not prompt or not prompt.Parent then return false end
	pcall(function() prompt:InputHoldBegin() end)
	task.wait(0.12 + math.random() * 0.06)
	local hasFire = type(fireproximityprompt) == "function"
	if hasFire then
		pcall(function() fireproximityprompt(prompt) end)
	else
		pcall(function()
			if getconnections then
				for _, c in ipairs(getconnections(prompt.Triggered)) do
					if c.Function then task.spawn(c.Function) end
				end
			end
		end)
		pcall(function() prompt:InputHoldEnd() end)
	end
	return true
end

local function _findNearestStealPrompt(pos)
	local nearest, nearestDist = nil, 12
	for _, prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			local action = (prompt.ActionText or ""):lower()
			local obj    = (prompt.ObjectText or ""):lower()
			local isSell = action:find("sell",1,true) or action:find("vend",1,true)
			local isDrop = action:find("drop",1,true) or obj:find("drop",1,true)
			if not isSell and not isDrop then
				local isTarget = action:find("steal") or action:find("grab")
					or action:find("take") or action:find("pick")
					or action:find("collect") or action:find("hatch")
					or obj:find("egg") or obj:find("field") or obj:find("slot")
				if isTarget then
					local part = prompt.Parent
					if part and part:IsA("BasePart") then
						local d = (part.Position - pos).Magnitude
						if d < nearestDist then nearestDist = d; nearest = prompt end
					end
				end
			end
		end
	end
	return nearest
end

local function doTeleport(entry)
	if not entry or not entry.pos then return false end
	local char = LP.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local ok = pcall(function()
		hrp.CFrame = CFrame.new(entry.pos + Vector3.new(0, 3.5, 0))
	end)
	if not ok then return false end
	task.wait(0.15)
	local target = (entry.prompt and entry.prompt.Parent) and entry.prompt
		or _findNearestStealPrompt(hrp.Position)
	if target then _fireStealPrompt(target) end
	return true
end

-- ============================================================
-- FARM LOOP
-- ============================================================
local _farmLoopOn = false
local setLoopVisual  -- forward decl, defined in UI section

task.spawn(function()
	while true do
		if _farmLoopOn then
			local ranked = rankEggs()
			local target = currentTarget(ranked)
			if target then doTeleport(target) end
		end
		task.wait(1.5)
	end
end)

-- Auto-disable farm loop when egg/pet is in hand (drop prompt appears near LP)
task.spawn(function()
	while true do
		task.wait(0.25)
		if _farmLoopOn then
			local char = LP.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local pos   = hrp.Position
				local found = false
				pcall(function()
					for _, prompt in ipairs(workspace:GetDescendants()) do
						if prompt:IsA("ProximityPrompt") then
							local action = (prompt.ActionText or ""):lower()
							local obj    = (prompt.ObjectText or ""):lower()
							if action:find("drop",1,true) or obj:find("drop",1,true) then
								local part = prompt.Parent
								if part and part:IsA("BasePart") then
									if (part.Position - pos).Magnitude < 15 then
										found = true; return
									end
								end
							end
						end
					end
				end)
				if found then
					_farmLoopOn = false
					if setLoopVisual then setLoopVisual(false) end
				end
			end
		end
	end
end)

-- ============================================================
-- UI
-- ============================================================
local C = {
	BG       = Color3.fromRGB(16, 18, 17),
	CARD     = Color3.fromRGB(24, 27, 25),
	STROKE   = Color3.fromRGB(70, 220, 130),
	TEXT     = Color3.fromRGB(235, 235, 235),
	DIM      = Color3.fromRGB(140, 142, 140),
	GREEN    = Color3.fromRGB(80, 225, 130),
	ROW_SEL  = Color3.fromRGB(34, 40, 36),
	TRACK_OFF = Color3.fromRGB(52, 54, 52),
	KNOB_OFF  = Color3.fromRGB(150, 150, 150),
}

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 10); c.Parent = inst; return c
end
local function stroke(inst, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color; s.Thickness = thick or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst; return s
end
local function label(parent, text, size, color, font, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1; l.Size = size; l.Text = text
	l.TextColor3 = color; l.Font = font or Enum.Font.Gotham
	l.TextSize = 12; l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd; l.Parent = parent; return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "yslemEggGui"; gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local okParent = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not okParent then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Name = "Main"; main.Size = UDim2.new(0, 270, 0, 0)
main.AutomaticSize = Enum.AutomaticSize.Y
main.Position = UDim2.new(0.5, -135, 0.35, 0)
main.BackgroundColor3 = C.BG; main.Parent = gui
corner(main, 16); stroke(main, C.STROKE, 1.5)

do
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = main
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0,10); p.PaddingBottom = UDim.new(0,10)
	p.PaddingLeft = UDim.new(0,10); p.PaddingRight = UDim.new(0,10); p.Parent = main
end

-- HEADER -------------------------------------------------------
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 34); header.BackgroundTransparency = 1
header.LayoutOrder = 1; header.Parent = main

do
	local logo = Instance.new("Frame")
	logo.Size = UDim2.fromOffset(30,30); logo.Position = UDim2.new(0,0,0.5,-15)
	logo.BackgroundColor3 = C.STROKE; logo.Parent = header; corner(logo, 9)
	local lbl = label(logo,"Y",UDim2.new(1,0,1,0),Color3.new(0,0,0),Enum.Font.GothamBlack,Enum.TextXAlignment.Center)
	lbl.TextSize = 16

	local titles = Instance.new("Frame")
	titles.Size = UDim2.new(1,-70,1,0); titles.Position = UDim2.new(0,38,0,0)
	titles.BackgroundTransparency = 1; titles.Parent = header
	local t1 = label(titles,"YSLEM HUB",UDim2.new(1,0,0,18),C.TEXT,Enum.Font.GothamBold)
	t1.TextSize = 14
	local t2 = label(titles,"BEST EGG · PICKER",UDim2.new(1,0,0,14),C.DIM,Enum.Font.Gotham)
	t2.TextSize = 10; t2.Position = UDim2.new(0,0,0,17)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(22,22); closeBtn.Position = UDim2.new(1,-22,0.5,-11)
	closeBtn.BackgroundTransparency = 1; closeBtn.Text = "✕"; closeBtn.TextColor3 = C.DIM
	closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 13; closeBtn.Parent = header
	closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
end

-- header drag
do
	local dragging, dragStart, startPos = false, nil, nil
	header.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dragStart = inp.Position; startPos = main.Position
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch) then
			local delta = inp.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- BEST EGG CARD ------------------------------------------------
local card1 = Instance.new("Frame")
card1.Size = UDim2.new(1,0,0,0); card1.AutomaticSize = Enum.AutomaticSize.Y
card1.BackgroundColor3 = C.CARD; card1.LayoutOrder = 2; card1.Parent = main
corner(card1, 12)
do
	local p = Instance.new("UIPadding")
	p.PaddingTop=UDim.new(0,8); p.PaddingBottom=UDim.new(0,8)
	p.PaddingLeft=UDim.new(0,10); p.PaddingRight=UDim.new(0,10); p.Parent=card1
	local lay = Instance.new("UIListLayout")
	lay.Padding=UDim.new(0,6); lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Parent=card1
end

-- Caption row + chevron
local capRow = Instance.new("Frame")
capRow.Size=UDim2.new(1,0,0,12); capRow.BackgroundTransparency=1; capRow.LayoutOrder=1; capRow.Parent=card1
local capLbl = label(capRow,"BEST EGG",UDim2.new(1,-20,1,0),C.DIM,Enum.Font.GothamBold)
capLbl.TextSize=10
local chevron = Instance.new("TextButton")
chevron.Size=UDim2.fromOffset(18,14); chevron.Position=UDim2.new(1,-18,0,-1)
chevron.BackgroundTransparency=1; chevron.Text="▾"; chevron.TextColor3=C.DIM
chevron.Font=Enum.Font.GothamBold; chevron.TextSize=12; chevron.Parent=capRow

-- Main display row
local mainRow = Instance.new("Frame")
mainRow.Size=UDim2.new(1,0,0,36); mainRow.BackgroundTransparency=1; mainRow.LayoutOrder=2; mainRow.Parent=card1

local mIcon = Instance.new("Frame")
mIcon.Size=UDim2.fromOffset(32,32); mIcon.Position=UDim2.new(0,0,0.5,-16)
mIcon.BackgroundColor3=COMMON_COLOR; mIcon.Parent=mainRow; corner(mIcon,8)
local mIconImg = Instance.new("ImageLabel")
mIconImg.Size=UDim2.new(1,0,1,0); mIconImg.BackgroundTransparency=1
mIconImg.Image=""; mIconImg.ScaleType=Enum.ScaleType.Fit
mIconImg.Visible=false; mIconImg.Parent=mIcon

local mTexts = Instance.new("Frame")
mTexts.Size=UDim2.new(1,-120,1,0); mTexts.Position=UDim2.new(0,40,0,0)
mTexts.BackgroundTransparency=1; mTexts.Parent=mainRow
local mName = label(mTexts,"—",UDim2.new(1,0,0,16),C.TEXT,Enum.Font.GothamBold)
mName.TextSize=13
local mRarity = label(mTexts,"Aucun oeuf",UDim2.new(1,0,0,14),COMMON_COLOR,Enum.Font.GothamMedium)
mRarity.TextSize=11; mRarity.Position=UDim2.new(0,0,0,17)
local mValue = label(mainRow,"—",UDim2.new(0,70,1,0),C.GREEN,Enum.Font.GothamBold)
mValue.TextSize=15; mValue.TextXAlignment=Enum.TextXAlignment.Right
mValue.Position=UDim2.new(1,-70,0,0)

-- Egg/pet picker (Top 6, expandable)
local listFrame = Instance.new("Frame")
listFrame.Size=UDim2.new(1,0,0,0); listFrame.AutomaticSize=Enum.AutomaticSize.Y
listFrame.BackgroundTransparency=1; listFrame.LayoutOrder=3; listFrame.Visible=false; listFrame.Parent=card1
local listLayout = Instance.new("UIListLayout")
listLayout.Padding=UDim.new(0,3); listLayout.SortOrder=Enum.SortOrder.LayoutOrder; listLayout.Parent=listFrame

chevron.MouseButton1Click:Connect(function()
	listFrame.Visible = not listFrame.Visible
	chevron.Text = listFrame.Visible and "▴" or "▾"
end)

-- TELEPORT CARD ------------------------------------------------
local card2 = Instance.new("Frame")
card2.Size=UDim2.new(1,0,0,0); card2.AutomaticSize=Enum.AutomaticSize.Y
card2.BackgroundColor3=C.CARD; card2.LayoutOrder=3; card2.Parent=main
corner(card2,12)
do
	local p = Instance.new("UIPadding")
	p.PaddingTop=UDim.new(0,8); p.PaddingBottom=UDim.new(0,8)
	p.PaddingLeft=UDim.new(0,10); p.PaddingRight=UDim.new(0,10); p.Parent=card2
	local lay = Instance.new("UIListLayout")
	lay.Padding=UDim.new(0,6); lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Parent=card2
end

local capLbl2 = label(card2,"TELEPORT",UDim2.new(1,0,0,12),C.DIM,Enum.Font.GothamBold)
capLbl2.TextSize=10; capLbl2.LayoutOrder=1

local tpRow = Instance.new("Frame")
tpRow.Size=UDim2.new(1,0,0,28); tpRow.BackgroundTransparency=1; tpRow.LayoutOrder=2; tpRow.Parent=card2

local tpBtn = Instance.new("TextButton")
tpBtn.Size=UDim2.new(0.5,-4,1,0); tpBtn.BackgroundColor3=C.BG
tpBtn.AutoButtonColor=false; tpBtn.Text="ONE TELEPORT"; tpBtn.TextColor3=C.TEXT
tpBtn.Font=Enum.Font.GothamBold; tpBtn.TextSize=11; tpBtn.Parent=tpRow; corner(tpBtn,8)

local loopRow = Instance.new("Frame")
loopRow.Size=UDim2.new(0.5,-4,1,0); loopRow.Position=UDim2.new(0.5,4,0,0)
loopRow.BackgroundColor3=C.BG; loopRow.Parent=tpRow; corner(loopRow,8)
local farmLbl = label(loopRow,"FARM LOOP",UDim2.new(1,-40,1,0),C.TEXT,Enum.Font.GothamMedium)
farmLbl.TextSize=10

local toggleTrack = Instance.new("TextButton")
toggleTrack.Text=""; toggleTrack.Size=UDim2.fromOffset(30,16)
toggleTrack.Position=UDim2.new(1,-34,0.5,-8); toggleTrack.BackgroundColor3=C.TRACK_OFF
toggleTrack.Parent=loopRow; corner(toggleTrack,8)
local toggleKnob = Instance.new("Frame")
toggleKnob.Size=UDim2.fromOffset(12,12); toggleKnob.Position=UDim2.new(0,2,0.5,-6)
toggleKnob.BackgroundColor3=C.KNOB_OFF; toggleKnob.Parent=toggleTrack; corner(toggleKnob,6)

setLoopVisual = function(on)
	TweenService:Create(toggleTrack, TweenInfo.new(0.15), {BackgroundColor3 = on and C.STROKE or C.TRACK_OFF}):Play()
	TweenService:Create(toggleKnob, TweenInfo.new(0.15), {
		Position = on and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6),
		BackgroundColor3 = on and Color3.new(1,1,1) or C.KNOB_OFF,
	}):Play()
end

toggleTrack.MouseButton1Click:Connect(function()
	_farmLoopOn = not _farmLoopOn
	setLoopVisual(_farmLoopOn)
end)
tpBtn.MouseButton1Click:Connect(function()
	local ranked = rankEggs()
	local target = currentTarget(ranked)
	local ok = target and doTeleport(target)
	local prev = tpBtn.Text
	tpBtn.Text = ok and "TELEPORTED" or "NO TARGET"
	task.delay(1, function() pcall(function() tpBtn.Text = prev end) end)
end)

-- DEBUG COPY ROW — if detection still misses, this exports what the
-- scanner actually sees so the real structure can be pinned down
-- instead of guessing again.
local debugRow = Instance.new("Frame")
debugRow.Size=UDim2.new(1,0,0,20); debugRow.BackgroundTransparency=1; debugRow.LayoutOrder=3; debugRow.Parent=card2
local debugBtn = Instance.new("TextButton")
debugBtn.Size=UDim2.new(1,0,1,0); debugBtn.BackgroundTransparency=1
debugBtn.Text="Copier debug scan"; debugBtn.TextColor3=C.DIM
debugBtn.Font=Enum.Font.Gotham; debugBtn.TextSize=10; debugBtn.Parent=debugRow
debugBtn.MouseButton1Click:Connect(function()
	local lines = {}
	table.insert(lines, "[yslemEgg debug] Plots exists: "..tostring(workspace:FindFirstChild("Plots") ~= nil))
	table.insert(lines, "cachedEggs: "..#cachedEggs)
	for i, e in ipairs(cachedEggs) do
		if i > 10 then break end
		table.insert(lines, string.format("#%d cat=%s area=%s tags=%s value=%s weight=%s",
			i, tostring(e.cat), tostring(e.area), table.concat(e.tags or {}, ","),
			tostring(e.valueText), tostring(e.weight)))
	end
	local txt = table.concat(lines, "\n")
	print(txt)
	local prev = debugBtn.Text
	if type(setclipboard) == "function" then
		pcall(function() setclipboard(txt) end)
		debugBtn.Text = "Copie ! (voir aussi F9)"
	else
		debugBtn.Text = "Voir console F9"
	end
	task.delay(1.5, function() pcall(function() debugBtn.Text = prev end) end)
end)

-- EGG/PET PICKER ROWS — with ImageLabel support -----------------
local _rowPool = {}
local function getRow(i)
	if _rowPool[i] then return _rowPool[i] end
	local row = Instance.new("TextButton")
	row.Size=UDim2.new(1,0,0,30); row.BackgroundColor3=C.BG
	row.AutoButtonColor=false; row.Text=""; row.LayoutOrder=i; row.Parent=listFrame
	corner(row,8)

	local imgHolder = Instance.new("Frame")
	imgHolder.Size=UDim2.fromOffset(26,26); imgHolder.Position=UDim2.new(0,4,0.5,-13)
	imgHolder.BackgroundColor3=COMMON_COLOR; imgHolder.Parent=row; corner(imgHolder,6)
	local img = Instance.new("ImageLabel")
	img.Size=UDim2.new(1,0,1,0); img.BackgroundTransparency=1
	img.Image=""; img.ScaleType=Enum.ScaleType.Fit; img.Visible=false; img.Parent=imgHolder

	local nm = label(row,"",UDim2.new(1,-110,0,16),C.TEXT,Enum.Font.GothamBold)
	nm.Position=UDim2.new(0,36,0,3); nm.TextSize=12
	local rar = label(row,"",UDim2.new(1,-110,0,12),COMMON_COLOR,Enum.Font.GothamMedium)
	rar.Position=UDim2.new(0,36,0,17); rar.TextSize=10

	local val = label(row,"",UDim2.new(0,65,1,0),C.GREEN,Enum.Font.GothamBold)
	val.Position=UDim2.new(1,-70,0,0); val.TextSize=11
	val.TextXAlignment=Enum.TextXAlignment.Right

	row.MouseButton1Click:Connect(function()
		local e = rankEggs()[i]
		if e then _selectedUid = e.uid end
	end)
	_rowPool[i] = {row=row, imgHolder=imgHolder, img=img, nm=nm, rar=rar, val=val}
	return _rowPool[i]
end

-- LIVE REFRESH -------------------------------------------------
task.spawn(function()
	while gui.Parent do
		local ranked = rankEggs()
		local best   = currentTarget(ranked)

		if best then
			mName.Text = tostring(best.cat or "Egg")
			local tag = best.tags and best.tags[1]
			local col = (tag and RARITY_COLOR[tag]) or COMMON_COLOR
			mRarity.Text = (tag and tag:sub(1,1):upper()..tag:sub(2) or "Common")
				..(best.area and best.area ~= "?" and (" · "..best.area) or "")
			mRarity.TextColor3 = col
			mIcon.BackgroundColor3 = col
			mValue.Text = best.valueText or (best.weight and (best.weight.." kg"))
				or (tag and (tag:sub(1,1):upper()..tag:sub(2)) or "—")
			if best.imageId and best.imageId ~= "" then
				mIconImg.Image = best.imageId; mIconImg.Visible = true
			else
				mIconImg.Image = ""; mIconImg.Visible = false
			end
		else
			mName.Text = "—"
			mRarity.Text = _lastScanFoundAny and "Aucun oeuf detecte" or "Scan: 0 resultat (voir debug)"
			mRarity.TextColor3 = COMMON_COLOR; mIcon.BackgroundColor3 = COMMON_COLOR
			mValue.Text = "—"; mIconImg.Visible = false
		end

		local N = math.min(6, #ranked)
		for i = 1, N do
			local e   = ranked[i]
			local r   = getRow(i)
			r.row.Visible = true
			local tag = e.tags and e.tags[1]
			local col = (tag and RARITY_COLOR[tag]) or COMMON_COLOR
			r.imgHolder.BackgroundColor3 = col
			r.nm.Text  = tostring(e.cat or "Egg")
			r.rar.Text = tag and (tag:sub(1,1):upper()..tag:sub(2)) or "Common"
			r.rar.TextColor3 = col
			r.val.Text = e.valueText or (e.weight and (e.weight.." kg"))
				or (tag and tag:sub(1,1):upper()..tag:sub(2) or "—")
			r.row.BackgroundColor3 = (e.uid == _selectedUid) and C.ROW_SEL or C.BG
			if e.imageId and e.imageId ~= "" then
				if r.img.Image ~= e.imageId then r.img.Image = e.imageId end
				r.img.Visible = true
			else
				r.img.Visible = false
			end
		end
		for i = N + 1, #_rowPool do
			if _rowPool[i] then _rowPool[i].row.Visible = false end
		end

		task.wait(0.5)
	end
end)

print("[yslemEgg] Loaded — Plots/AnimalPodiums scanner + Bat Teleport + Image Picker.")
