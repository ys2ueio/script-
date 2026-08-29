-- ============================================================
-- yslemEgg — Auto Farm Hub
-- UI: Moon Hub style (black + blue accent)
-- ============================================================
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ys2ueio/script-/refs/heads/main/yslemEgg.lua"))()

if not game:IsLoaded() then game.Loaded:Wait() end

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local Lighting     = game:GetService("Lighting")
local LP           = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end

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

-- ============================================================
-- STATE
-- ============================================================
local St = {
	autoFarm        = false,
	autoHatch       = false,
	autoEquip       = false,
	autoUpgradePen  = false,
	autoUpgradeTM   = false,
	autoUpgradeTrail= false,
	antiRagdoll     = false,
	fly             = false,
	esp             = false,
	antiAFK         = false,
	antiTrap        = false,
	fullbright      = false,
	fpsBoost        = false,
	speed           = 16,
	flySpeed        = 50,
	farmRadius      = 40,
	guiVisible      = true,
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

-- ── AUTO FARM ───────────────────────────────────────────────
local _farmConn = nil
local function stopFarm()
	if _farmConn then _farmConn:Disconnect(); _farmConn = nil end
end
local function startFarm()
	stopFarm()
	local _t = 0
	_farmConn = RunService.Heartbeat:Connect(function()
		if not St.autoFarm then return end
		local now = tick(); if now - _t < 0.08 then return end; _t = now
		local char = LP.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		-- scan workspace for ProximityPrompts near egg-like objects
		local best, bestDist = nil, St.farmRadius
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("ProximityPrompt") then
				pcall(function()
					local part = obj.Parent
					if not part or not part:IsA("BasePart") then return end
					-- filter: egg prompts usually have action text with keywords
					local act = obj.ActionText:lower()
					local isEgg = act:find("egg") or act:find("hatch") or act:find("grab")
						or act:find("steal") or act:find("collect") or act:find("pick")
						or obj.ObjectText:lower():find("egg")
					if not isEgg then return end
					local dist = (part.Position - hrp.Position).Magnitude
					if dist < bestDist then bestDist = dist; best = obj end
				end)
			end
		end
		if best then
			if fireproximityprompt then
				pcall(function() fireproximityprompt(best) end)
			else
				pcall(function() best:InputHoldBegin(); task.wait(best.HoldDuration + 0.05); best:InputHoldEnd() end)
			end
			setStatus("Farm → "..tostring(best.Parent and best.Parent.Name or "?"), C_GREEN)
		else
			setStatus("Farm: scanning...", C_DIM)
		end
	end)
end

makeRow(farmPage, "autoFarm", "Auto Farm Eggs", function(on)
	if on then startFarm() else stopFarm(); setStatus("Farm OFF", C_DIM) end
end)

-- ── AUTO HATCH ──────────────────────────────────────────────
local _hatchConn = nil
local function stopHatch()
	if _hatchConn then _hatchConn:Disconnect(); _hatchConn = nil end
end
local function startHatch()
	stopHatch()
	local _t = 0
	_hatchConn = RunService.Heartbeat:Connect(function()
		if not St.autoHatch then return end
		local now = tick(); if now - _t < 0.5 then return end; _t = now
		local char = LP.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("ProximityPrompt") then
				pcall(function()
					local act = obj.ActionText:lower()
					local isHatch = act:find("hatch") or act:find("open") or act:find("crack")
					if not isHatch then return end
					local part = obj.Parent
					if part and part:IsA("BasePart") then
						local dist = (part.Position - hrp.Position).Magnitude
						if dist < St.farmRadius then
							if fireproximityprompt then
								pcall(function() fireproximityprompt(obj) end)
							else
								pcall(function() obj:InputHoldBegin(); task.wait(obj.HoldDuration+0.05); obj:InputHoldEnd() end)
							end
						end
					end
				end)
			end
		end
		-- also try RemoteEvents named "Hatch" / "HatchEgg"
		pcall(function()
			local RS = game:GetService("ReplicatedStorage")
			for _, v in ipairs(RS:GetDescendants()) do
				if v:IsA("RemoteEvent") then
					local n = v.Name:lower()
					if n:find("hatch") or n:find("crackopen") then
						v:FireServer()
					end
				end
			end
		end)
	end)
end

makeRow(farmPage, "autoHatch", "Auto Hatch", function(on)
	if on then startHatch() else stopHatch() end
end)

-- ── AUTO EQUIP ──────────────────────────────────────────────
local _equipConn = nil
local function stopEquip() if _equipConn then _equipConn:Disconnect(); _equipConn = nil end end
local function startEquip()
	stopEquip()
	local _t = 0
	_equipConn = RunService.Heartbeat:Connect(function()
		if not St.autoEquip then return end
		local now = tick(); if now - _t < 1 then return end; _t = now
		pcall(function()
			local RS = game:GetService("ReplicatedStorage")
			for _, v in ipairs(RS:GetDescendants()) do
				if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
					local n = v.Name:lower()
					if n:find("equip") or n:find("claim") or n:find("collect") then
						if v:IsA("RemoteEvent") then v:FireServer()
						else pcall(function() v:InvokeServer() end) end
					end
				end
			end
		end)
		-- ProximityPrompt fallback
		local char = LP.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("ProximityPrompt") then
					pcall(function()
						local act = obj.ActionText:lower()
						if act:find("equip") or act:find("claim") or act:find("collect") then
							local part = obj.Parent
							if part and part:IsA("BasePart") and (part.Position - hrp.Position).Magnitude < St.farmRadius then
								if fireproximityprompt then pcall(function() fireproximityprompt(obj) end)
								else pcall(function() obj:InputHoldBegin(); task.wait(obj.HoldDuration+0.05); obj:InputHoldEnd() end) end
							end
						end
					end)
				end
			end
		end
	end)
end

makeRow(farmPage, "autoEquip", "Auto Equip / Claim", function(on)
	if on then startEquip() else stopEquip() end
end)

-- ── AUTO UPGRADE ────────────────────────────────────────────
local _upgradeConns = {}
local function stopUpgradeAll()
	for _, c in ipairs(_upgradeConns) do pcall(function() c:Disconnect() end) end
	_upgradeConns = {}
end

local function makeUpgradeLoop(keyword)
	local _t = 0
	return RunService.Heartbeat:Connect(function()
		local now = tick(); if now - _t < 1.5 then return end; _t = now
		pcall(function()
			-- ProximityPrompts
			local char = LP.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("ProximityPrompt") then
						local n = (obj.ActionText..obj.ObjectText):lower()
						if n:find(keyword) then
							local part = obj.Parent
							if part and part:IsA("BasePart") and (part.Position - hrp.Position).Magnitude < 80 then
								if fireproximityprompt then pcall(function() fireproximityprompt(obj) end)
								else pcall(function() obj:InputHoldBegin(); task.wait(obj.HoldDuration+0.05); obj:InputHoldEnd() end) end
							end
						end
					end
				end
			end
			-- Remotes
			local RS = game:GetService("ReplicatedStorage")
			for _, v in ipairs(RS:GetDescendants()) do
				if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and v.Name:lower():find("upgrade") then
					if v.Name:lower():find(keyword) then
						if v:IsA("RemoteEvent") then v:FireServer()
						else pcall(function() v:InvokeServer() end) end
					end
				end
			end
		end)
	end)
end

makeRow(farmPage, "autoUpgradePen", "Auto Upgrade Pen", function(on)
	if on then table.insert(_upgradeConns, makeUpgradeLoop("pen"))
	else stopUpgradeAll() end
end)
makeRow(farmPage, "autoUpgradeTM", "Auto Upgrade Treadmill", function(on)
	if on then table.insert(_upgradeConns, makeUpgradeLoop("treadmill"))
	else stopUpgradeAll() end
end)
makeRow(farmPage, "autoUpgradeTrail", "Auto Upgrade Trail", function(on)
	if on then table.insert(_upgradeConns, makeUpgradeLoop("trail"))
	else stopUpgradeAll() end
end)

-- Farm radius slider
makeSlider(farmPage, "farmRadius", "Farm Radius", 10, 150, "%d studs")

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

-- ── ANTI RAGDOLL ────────────────────────────────────────────
local _ragConn = nil
local function stopAntiRag()
	if _ragConn then _ragConn:Disconnect(); _ragConn = nil end
end
local function startAntiRag()
	stopAntiRag()
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

-- ── ESP ─────────────────────────────────────────────────────
local _espHighlights = {}
local _espConn = nil
local function clearESP()
	for _, h in ipairs(_espHighlights) do pcall(function() h:Destroy() end) end
	_espHighlights = {}
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
		local now = tick(); if now - _t < 2 then return end; _t = now
		clearESP()
		-- highlight egg-like objects in workspace
		for _, obj in ipairs(workspace:GetDescendants()) do
			pcall(function()
				local n = obj.Name:lower()
				local isEgg = n:find("egg") or (obj:IsA("Model") and obj.Name:lower():find("egg"))
				if isEgg and (obj:IsA("BasePart") or obj:IsA("Model")) then
					local hi = Instance.new("SelectionBox")
					hi.Adornee = obj
					hi.Color3 = C_MOON
					hi.LineThickness = 0.05
					hi.SurfaceTransparency = 0.7
					hi.SurfaceColor3 = C_MOON
					hi.Parent = workspace
					table.insert(_espHighlights, hi)
				end
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
local BYPASS_COOLDOWN_S = 5

local function applyBypass()
	if _bypassActive then return end
	local now = tick()
	if now - _bypassCooldown < BYPASS_COOLDOWN_S then
		local left = math.ceil(BYPASS_COOLDOWN_S - (now - _bypassCooldown))
		setStatus("Bypass: attendre "..left.."s", C_DIM)
		return
	end
	local char = LP.Character
	local oldHum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not oldHum then
		setStatus("Bypass: pas de character", C_RED)
		return
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
		setStatus("Bypass applied", C_GREEN)
	else
		setStatus("Bypass failed — voir console", C_RED)
	end
	task.delay(3, function()
		if not _bypassActive then setStatus("Idle", C_DIM) end
	end)
end

do
	local row = Instance.new("Frame", miscPage)
	row.Size = UDim2.new(1,-12,0,30)
	row.BackgroundColor3 = C_ROW; row.BorderSizePixel = 0; corner(row, 6)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	label(row, "Bypass Anti-Cheat", UDim2.new(1,-60,1,0), C_WHITE, Enum.Font.GothamMedium).TextSize = 12
	local btn = Instance.new("TextButton", row)
	btn.Size = UDim2.new(0,54,0,18)
	btn.Position = UDim2.new(1,-54,0.5,-9)
	btn.BackgroundColor3 = C_ON_BG; btn.TextColor3 = C_MOON
	btn.Text = "Apply"; btn.TextSize = 10; btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0; corner(btn, 9)
	btn.MouseButton1Click:Connect(applyBypass)
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
-- AIM BAT
-- ============================================================
local _aimBatActive  = false
local _aimBatConn    = nil
local _aimBatCooldown = 0

local function _getNearestEnemy()
	local char = LP.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil, nil end
	local best, bestDist, bestHrp = nil, 60, nil
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= LP and pl.Character then
			local eh = pl.Character:FindFirstChild("HumanoidRootPart")
			local hum = pl.Character:FindFirstChildOfClass("Humanoid")
			if eh and hum and hum.Health > 0 then
				local d = (eh.Position - hrp.Position).Magnitude
				if d < bestDist then bestDist = d; best = pl; bestHrp = eh end
			end
		end
	end
	return best, bestHrp
end

local function startAimBat()
	if _aimBatConn then _aimBatConn:Disconnect() end
	_aimBatConn = RunService.RenderStepped:Connect(function()
		if not _aimBatActive then return end
		local _, targetHrp = _getNearestEnemy()
		if not targetHrp then return end
		local char = LP.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		-- aim: rotate HRP toward target
		local lookCF = CFrame.lookAt(hrp.Position, Vector3.new(targetHrp.Position.X, hrp.Position.Y, targetHrp.Position.Z))
		hrp.CFrame = lookCF
		-- swing: find equipped Tool with "bat"/"hit"/"swing" in name and fire
		local now = tick()
		if now - _aimBatCooldown < 0.35 then return end
		_aimBatCooldown = now
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then
				local n = tool.Name:lower()
				if n:find("bat") or n:find("hit") or n:find("punch") or n:find("sword") or n:find("stick") then
					-- fire ClickDetector / Activate
					pcall(function() tool:Activate() end)
					-- also try remotes inside the tool
					for _, v in ipairs(tool:GetDescendants()) do
						if v:IsA("RemoteEvent") then
							local vn = v.Name:lower()
							if vn:find("hit") or vn:find("swing") or vn:find("attack") or vn:find("damage") then
								pcall(function() v:FireServer(targetHrp.Position) end)
							end
						end
					end
					break
				end
			end
		end
	end)
end

local function stopAimBat()
	if _aimBatConn then _aimBatConn:Disconnect(); _aimBatConn = nil end
	_aimBatActive = false
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
		_floatBtns["bypass"].btn.MouseButton1Click:Connect(function()
			applyBypass()
			-- flash the dot briefly to confirm
			setAct(true)
			task.delay(1.5, function() setAct(false) end)
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
