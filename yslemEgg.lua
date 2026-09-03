-- ============================================================
-- yslemEgg — Best Egg + Teleport (compact hub)
-- ============================================================
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ys2ueio/script-/refs/heads/main/yslemEgg.lua"))()

if not game:IsLoaded() then game.Loaded:Wait() end

local Players       = game:GetService("Players")
local UIS           = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")
local HttpService   = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
-- REMOTES (ReplicatedStorage.Packages.Networking)
-- ============================================================
local _NetworkingFolder = ReplicatedStorage:FindFirstChild("Packages")
_NetworkingFolder = _NetworkingFolder and _NetworkingFolder:FindFirstChild("Networking")

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
	if not r or not r:IsA("RemoteFunction") then return false, "not found" end
	local ok, result = pcall(function(...) return r:InvokeServer(...) end, ...)
	return ok, result
end

-- ============================================================
-- ZONES
-- ============================================================
local AREA = {}
do
	local folder = workspace:FindFirstChild("__OBJECTS")
	folder = folder and folder:FindFirstChild("Areas")
	folder = folder and folder:FindFirstChild("GuardAreas")
	if folder then
		for _, a in ipairs(folder:GetChildren()) do
			pcall(function()
				local bounds = a:FindFirstChild("Bounds")
				if bounds and bounds:IsA("BasePart") then
					AREA[a.Name] = {cf = bounds.CFrame, size = bounds.Size}
				end
			end)
		end
	end
end
local function _posToZone(pos)
	for zn, A in pairs(AREA) do
		local lp2 = A.cf:PointToObjectSpace(pos)
		local hs = A.size * 0.5
		if math.abs(lp2.X) <= hs.X and math.abs(lp2.Z) <= hs.Z then return zn end
	end
	return "?"
end

-- ============================================================
-- RARITY
-- ============================================================
local _RARE_KEYWORDS = {
	"secret","eternal","divine","divin","mythic","celestial","ancient",
	"rainbow","golden","shiny","radiant","corrupted","void","legendary",
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

-- Scans a model/part for any image ID (decals, textures, ImageLabels, mesh textures).
-- Returns a Roblox asset URL string or nil.
local function _getEggImageId(root)
	if not root then return nil end
	local id = nil
	pcall(function()
		-- 1. Attributes first (some games store thumbnails as attributes)
		for _, attr in ipairs({"Thumbnail","Icon","Image","ImageId","TextureId","EggIcon"}) do
			local v = root:GetAttribute(attr)
			if type(v) == "string" and v ~= "" then id = v; return end
		end
		-- 2. Scan descendants for image-bearing instances
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
-- EGG SCANNER — 3 sources, feeds cachedEggs
-- ============================================================
local _fieldEggNet = {}

pcall(function()
	local re = _getRemote("RE/EggWorld/FieldEggShifted")
	if not (re and re:IsA("RemoteEvent")) then return end
	local _ID_KEYS = {"Uid","UID","Id","ID","SlotId","SlotID","EggId","EggID","EggUid","Guid","GUID"}
	re.OnClientEvent:Connect(function(a1, a2)
		local data, realUid
		if type(a2) == "table" then
			data = a2
			if type(a1) == "string" or type(a1) == "number" then realUid = tostring(a1) end
		elseif type(a1) == "table" then
			data = a1
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

		if not realUid then
			for _, k in ipairs(_ID_KEYS) do
				local v = data[k]
				if type(v) == "string" or type(v) == "number" then realUid = tostring(v); break end
			end
		end

		local mutation = type(data.Mutation) == "string" and data.Mutation or nil
		local zoneDir = data.Zone or data.Area or data.AreaName or data.Island or data.ZoneName
		local zone = (type(zoneDir)=="string" and zoneDir~="") and zoneDir or _posToZone(pos2)

		local tags = {}
		local low = (mutation or ""):lower()
		for _, kw in ipairs(_RARE_KEYWORDS) do
			if low:find(kw, 1, true) then table.insert(tags, kw) end
		end

		local cacheKey = realUid or string.format("%.0f_%.0f_%.0f", pos2.X, pos2.Y, pos2.Z)
		local walkPos = (typeof(data.BottomCFrame)=="CFrame" and data.BottomCFrame.Position) or pos2
		_fieldEggNet[cacheKey] = {
			pos=walkPos, cf=cf2, mutation=mutation, zone=zone, tags=tags,
			uid=realUid, t=tick(), farmable=(realUid ~= nil),
		}
	end)
end)

task.spawn(function()
	while true do
		task.wait(3)
		local ok, snap = _invokeRF("RF/EggWorld/AskFieldEggSnapshot")
		if ok and type(snap) == "table" then
			local now2 = tick()
			pcall(function()
				for uid, data in pairs(snap) do
					local uid2 = tostring(uid)
					if type(data) == "table" and not _fieldEggNet[uid2] then
						local cf2, pos2
						if typeof(data.BoundsCFrame) == "CFrame" then
							cf2 = data.BoundsCFrame; pos2 = cf2.Position
						elseif typeof(data.BottomCFrame) == "CFrame" then
							cf2 = data.BottomCFrame; pos2 = cf2.Position
						elseif typeof(data.CFrame) == "CFrame" then
							cf2 = data.CFrame; pos2 = cf2.Position
						end
						if pos2 then
							local mutation = type(data.Mutation) == "string" and data.Mutation or nil
							local zoneDir2 = data.Zone or data.Area or data.AreaName or data.Island or data.ZoneName
							local zone = (type(zoneDir2)=="string" and zoneDir2~="") and zoneDir2 or _posToZone(pos2)
							local tags2 = {}
							local low2 = (mutation or ""):lower()
							for _, kw in ipairs(_RARE_KEYWORDS) do
								if low2:find(kw,1,true) then table.insert(tags2, kw) end
							end
							local walkPos2 = (typeof(data.BottomCFrame)=="CFrame" and data.BottomCFrame.Position) or pos2
							_fieldEggNet[uid2] = {
								pos=walkPos2, cf=cf2, mutation=mutation, zone=zone,
								tags=tags2, uid=uid2, t=now2, farmable=true,
							}
						end
					end
				end
			end)
		end
	end
end)

local cachedEggs = {}
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

		-- Source 1: FieldEggShifted network events — 60s TTL
		local now2 = tick()
		for cacheKey, e in pairs(_fieldEggNet) do
			if now2 - e.t > 60 then
				_fieldEggNet[cacheKey] = nil
			else
				_upsertEgg({
					pos=e.pos, cf=e.cf, area=e.zone,
					cat=e.mutation or (e.zone.." Egg"),
					tags=e.tags, weight=nil, uid=e.uid, farmable=e.farmable,
					imageId=nil,  -- no accessible model from network events
				})
			end
		end

		-- Source 2: AreaEggSlotsClient (LP's own slots)
		local slotsRoot = workspace:FindFirstChild("AreaEggSlotsClient", true)
		if slotsRoot then
			for _, slot in ipairs(slotsRoot:GetChildren()) do
				pcall(function()
					local sname = slot.Name
					if not sname:find(tostring(LP.UserId), 1, true) then return end
					local zone = sname:match("_(%u[%a%s]+):Slot") or "?"
					local pos3, cf3
					if slot:IsA("BasePart") then
						pos3=slot.Position; cf3=slot.CFrame
					else
						for _, d in ipairs(slot:GetDescendants()) do
							if d:IsA("BasePart") then pos3=d.Position; cf3=d.CFrame; break end
						end
					end
					if not pos3 then return end
					local mutation2 = slot:GetAttribute("Mutation") or slot:GetAttribute("EggType")
					local _, tags2, weight2 = _readEggLabels(slot)
					local cat2 = mutation2 or (tags2[1] and tags2[1]:upper()) or (zone.." Egg")
					_upsertEgg({
						pos=pos3, cf=cf3, area=zone, cat=cat2,
						tags=tags2, weight=weight2, uid=sname, farmable=false,
						imageId=_getEggImageId(slot),
					})
				end)
			end
		end

		-- Source 3: ProximityPrompt fallback
		pcall(function()
			for _, prompt in ipairs(workspace:GetDescendants()) do
				if prompt:IsA("ProximityPrompt") then
					local action = prompt.ActionText:lower()
					local objTxt = prompt.ObjectText:lower()
					local parentName = (prompt.Parent and prompt.Parent.Name or ""):lower()
					local isSellPrompt = action:find("sell",1,true) or objTxt:find("sell",1,true)
						or action:find("vend",1,true) or objTxt:find("vend",1,true)
					if not isSellPrompt and (action:find("grab") or action:find("steal") or action:find("take")
						or action:find("pick") or action:find("collect") or action:find("hatch")
						or action:find("claim") or action:find("harvest")
						or objTxt:find("egg") or parentName:find("egg") or parentName:find("drop")
						or parentName:find("field") or parentName:find("slot")) then
						local part, model = _promptOwnerModel(prompt)
						if part then
							local _, tags3, weight3 = _readEggLabels(model or part)
							local cat3 = (tags3[1] and tags3[1]:upper())
								or (objTxt ~= "" and prompt.ObjectText) or part.Name
							_upsertEgg({
								pos=part.Position, cf=part.CFrame, area="Dropped", cat=cat3,
								tags=tags3, weight=weight3, uid=tostring(part), farmable=true,
								imageId=_getEggImageId(model or part),
							})
						end
					end
				end
			end
		end)

		cachedEggs = eggs
		task.wait(0.5)
	end
end)

-- ============================================================
-- RANKING
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
-- CFrame teleport → InputHoldBegin → fireproximityprompt (same
-- pattern as yslem_hub.lua tryStealOnce), adapted for field eggs.
-- ============================================================
local function _fireNearestStealPrompt(pos)
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
	if not nearest then return false end
	-- Hold begin (visual cue to server), then fire (Moon Hub pattern)
	pcall(function() nearest:InputHoldBegin() end)
	task.wait(0.12 + math.random() * 0.06)
	local hasFire = type(fireproximityprompt) == "function"
	if hasFire then
		pcall(function() fireproximityprompt(nearest) end)
	end
	-- Fallback: trigger getconnections (same as Moon Hub Méthode 2)
	if not hasFire then
		pcall(function()
			if getconnections then
				for _, c in ipairs(getconnections(nearest.Triggered)) do
					if c.Function then task.spawn(c.Function) end
				end
			end
		end)
		-- Fallback 2: InputHoldEnd (Moon Hub Méthode 3)
		pcall(function() nearest:InputHoldEnd() end)
	end
	return true
end

local function doTeleport(entry)
	if not entry or not entry.pos then return false end
	local char = LP.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	-- Bat TP: direct CFrame move to egg position
	local ok = pcall(function()
		hrp.CFrame = CFrame.new(entry.pos + Vector3.new(0, 3.5, 0))
	end)
	if not ok then return false end
	task.wait(0.15)
	-- Then immediately fire the nearest steal prompt
	_fireNearestStealPrompt(hrp.Position)
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

-- Auto-disable farm loop when egg is in hand (drop prompt appears near LP)
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
label(capRow,"BEST EGG",UDim2.new(1,-20,1,0),C.DIM,Enum.Font.GothamBold).TextSize=10
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
-- ImageLabel inside mIcon for real egg image
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

-- Egg picker / top-6 expandable list
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

-- Define the forward-declared setLoopVisual now that toggle elements exist
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

-- EGG PICKER ROWS — with ImageLabel support -------------------
-- Each row: [egg image 24×24] [name / rarity] [value/tag right-aligned]
local _rowPool = {}
local function getRow(i)
	if _rowPool[i] then return _rowPool[i] end
	local row = Instance.new("TextButton")
	row.Size=UDim2.new(1,0,0,30); row.BackgroundColor3=C.BG
	row.AutoButtonColor=false; row.Text=""; row.LayoutOrder=i; row.Parent=listFrame
	corner(row,8)

	-- Image holder (replaces the old 8×8 dot with a 26×26 square)
	local imgHolder = Instance.new("Frame")
	imgHolder.Size=UDim2.fromOffset(26,26); imgHolder.Position=UDim2.new(0,4,0.5,-13)
	imgHolder.BackgroundColor3=COMMON_COLOR; imgHolder.Parent=row; corner(imgHolder,6)
	local img = Instance.new("ImageLabel")
	img.Size=UDim2.new(1,0,1,0); img.BackgroundTransparency=1
	img.Image=""; img.ScaleType=Enum.ScaleType.Fit; img.Visible=false; img.Parent=imgHolder

	-- Name + rarity stacked
	local nm = label(row,"",UDim2.new(1,-110,0,16),C.TEXT,Enum.Font.GothamBold)
	nm.Position=UDim2.new(0,36,0,3); nm.TextSize=12
	local rar = label(row,"",UDim2.new(1,-110,0,12),COMMON_COLOR,Enum.Font.GothamMedium)
	rar.Position=UDim2.new(0,36,0,17); rar.TextSize=10

	-- Value right-aligned
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

		-- Update main "best" display
		if best then
			mName.Text = tostring(best.cat or "Egg")
			local tag = best.tags and best.tags[1]
			local col = (tag and RARITY_COLOR[tag]) or COMMON_COLOR
			mRarity.Text = (tag and tag:sub(1,1):upper()..tag:sub(2) or "Common")
				..(best.area and best.area ~= "?" and (" · "..best.area) or "")
			mRarity.TextColor3 = col
			mIcon.BackgroundColor3 = col
			mValue.Text = best.weight and (best.weight.." kg")
				or (tag and tag:sub(1,1):upper()..tag:sub(2) or "—")
			-- Show egg image if available
			if best.imageId and best.imageId ~= "" then
				mIconImg.Image = best.imageId; mIconImg.Visible = true
			else
				mIconImg.Image = ""; mIconImg.Visible = false
			end
		else
			mName.Text = "—"; mRarity.Text = "Aucun oeuf detecte"
			mRarity.TextColor3 = COMMON_COLOR; mIcon.BackgroundColor3 = COMMON_COLOR
			mValue.Text = "—"; mIconImg.Visible = false
		end

		-- Update picker rows (top 6)
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
			r.val.Text = e.weight and (e.weight.." kg")
				or (tag and tag:sub(1,1):upper()..tag:sub(2) or "—")
			r.row.BackgroundColor3 = (e.uid == _selectedUid) and C.ROW_SEL or C.BG
			-- Egg image
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

print("[yslemEgg] Loaded — Best Egg + Bat Teleport + Image Picker.")
