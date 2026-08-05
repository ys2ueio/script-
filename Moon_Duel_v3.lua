local _NS = tostring(math.random(0x100000, 0xFFFFFF)) .. tostring(tick()):gsub("%.", "")
local _GH  = {}   -- replaces all _GH.* / _GH.MH_* to leave zero _G footprint

if not game:IsLoaded() then game.Loaded:Wait() end

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UIS           = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")
local Lighting      = game:GetService("Lighting")
local LP            = Players.LocalPlayer
if not LP.Character then LP.CharacterAdded:Wait() end


-- ===================================================================
-- COLOR PALETTE
-- ===================================================================
local C_BG      = Color3.fromRGB(0,0,0)
local C_HEADER  = Color3.fromRGB(0,0,0)
local C_ROW     = Color3.fromRGB(0,0,0)
local C_BORDER  = Color3.fromRGB(40,46,58)
local C_WHITE   = Color3.fromRGB(255,255,255)
local C_MOON    = Color3.fromRGB(90,160,255)
local C_MOON2   = Color3.fromRGB(160,200,255)
-- Text color for anything drawn on top of a C_MOON-colored active surface
-- (active tab, ON pill/status text, …). Was hardcoded near-black
-- everywhere it's used, which is fine while C_MOON stays bright — but
-- White theme's C_MOON is deliberately dark (see _THEME_DEFS), so those
-- spots need light text instead. Theme-synced like everything else here.
local C_MOONTEXT = Color3.fromRGB(0,10,20)
local C_DIM     = Color3.fromRGB(110,120,140)
local C_TABIDLE = Color3.fromRGB(160,200,255)
local C_ON_BG   = Color3.fromRGB(20,45,80)
local C_OFF_BG  = Color3.fromRGB(0,0,0)
local C_SILVER  = Color3.fromRGB(210,222,240)
local C_SILVER2 = Color3.fromRGB(140,165,210)
local C_RED     = Color3.fromRGB(220,60,60)
local C_GREEN   = Color3.fromRGB(60,220,120)
-- Living gradient palette (updated by applyTheme so new buttons always use theme colors)
local C_DEEP1 = Color3.fromRGB(4,7,16)
local C_DEEP2 = Color3.fromRGB(14,28,58)
local C_DEEP3 = Color3.fromRGB(40,80,165)
local C_DEEP4 = Color3.fromRGB(90,150,255)

-- ===================================================================
-- THEME SYSTEM (Défaut = bleu, Noir = monochrome)
-- ===================================================================
-- panel_bg/text: what C_BG/C_ROW/C_OFF_BG/C_HEADER (always identical, always
-- pure black) and C_WHITE (primary label text) resolve to per theme. Every
-- theme except White keeps them at today's black/white — zero visual change,
-- verified by using the exact same value in all four so the swap is a no-op.
local _THEME_DEFS = {
	default = {
		panel_bg= Color3.fromRGB(0,0,0),
		text    = Color3.fromRGB(255,255,255),
		moon_text= Color3.fromRGB(0,10,20),
		moon    = Color3.fromRGB(90,160,255),
		moon2   = Color3.fromRGB(160,200,255),
		on_bg   = Color3.fromRGB(20,45,80),
		border  = Color3.fromRGB(40,46,58),
		silver  = Color3.fromRGB(210,222,240),
		silver2 = Color3.fromRGB(140,165,210),
		dim     = Color3.fromRGB(110,120,140),
		d3      = Color3.fromRGB(40,80,165),
		d4      = Color3.fromRGB(90,150,255),
	},
	noir = {
		panel_bg= Color3.fromRGB(0,0,0),
		text    = Color3.fromRGB(255,255,255),
		moon_text= Color3.fromRGB(0,10,20),
		moon    = Color3.fromRGB(205,205,205),
		moon2   = Color3.fromRGB(175,175,175),
		on_bg   = Color3.fromRGB(28,28,28),
		border  = Color3.fromRGB(44,44,44),
		silver  = Color3.fromRGB(210,210,210),
		silver2 = Color3.fromRGB(148,148,148),
		dim     = Color3.fromRGB(105,105,105),
		d3      = Color3.fromRGB(35,35,35),
		d4      = Color3.fromRGB(165,165,165),
	},
	crimson = {
		panel_bg= Color3.fromRGB(0,0,0),
		text    = Color3.fromRGB(255,255,255),
		moon_text= Color3.fromRGB(0,10,20),
		moon    = Color3.fromRGB(230,70,95),
		moon2   = Color3.fromRGB(255,140,155),
		on_bg   = Color3.fromRGB(70,15,26),
		border  = Color3.fromRGB(60,22,30),
		silver  = Color3.fromRGB(240,210,215),
		silver2 = Color3.fromRGB(195,135,145),
		dim     = Color3.fromRGB(135,85,92),
		d3      = Color3.fromRGB(120,25,42),
		d4      = Color3.fromRGB(225,60,85),
	},
	-- The one theme that actually goes light: panel_bg flips to white and
	-- every text/accent role below was re-picked for contrast against a
	-- WHITE page instead of the black one every other theme uses. moon/moon2
	-- land on a medium (not too dark, not too light) slate-indigo on purpose:
	-- they're also used as inactive-tab text over a small fixed-dark pill
	-- that never changes color, so pure-dark values would vanish there too.
	white = {
		panel_bg= Color3.fromRGB(255,255,255),
		text    = Color3.fromRGB(24,24,30),
		moon_text= Color3.fromRGB(245,246,252),
		moon    = Color3.fromRGB(70,82,125),
		moon2   = Color3.fromRGB(100,112,155),
		on_bg   = Color3.fromRGB(205,210,238),
		border  = Color3.fromRGB(200,202,214),
		silver  = Color3.fromRGB(40,40,52),
		silver2 = Color3.fromRGB(102,104,120),
		dim     = Color3.fromRGB(150,152,164),
		d3      = Color3.fromRGB(85,95,132),
		d4      = Color3.fromRGB(128,140,180),
	},
	purple = {
		panel_bg= Color3.fromRGB(0,0,0),
		text    = Color3.fromRGB(255,255,255),
		moon_text= Color3.fromRGB(0,10,20),
		moon    = Color3.fromRGB(170,110,255),
		moon2   = Color3.fromRGB(205,165,255),
		on_bg   = Color3.fromRGB(45,20,80),
		border  = Color3.fromRGB(55,30,78),
		silver  = Color3.fromRGB(228,212,248),
		silver2 = Color3.fromRGB(172,142,208),
		dim     = Color3.fromRGB(122,98,152),
		d3      = Color3.fromRGB(95,45,165),
		d4      = Color3.fromRGB(182,122,255),
	},
}
local _currentTheme = "default"
local _themeAllGuis = {}
local _G_updateThemeUI = nil

local function _tColKey(col, themeName)
	local t = _THEME_DEFS[themeName]
	local r,g,b = col.R, col.G, col.B
	for k,v in pairs(t) do
		if math.abs(r-v.R)+math.abs(g-v.G)+math.abs(b-v.B) < 0.015 then return k end
	end
end

local function applyTheme(newName)
	if not _THEME_DEFS[newName] then return end
	local oldName = _currentTheme
	_currentTheme = newName
	local new = _THEME_DEFS[newName]
	C_MOON    = new.moon;   C_MOON2   = new.moon2
	C_MOONTEXT= new.moon_text
	C_ON_BG   = new.on_bg; C_BORDER  = new.border
	C_SILVER  = new.silver; C_SILVER2 = new.silver2
	C_DIM     = new.dim;   C_TABIDLE = new.moon2
	C_DEEP3   = new.d3;    C_DEEP4   = new.d4
	-- Keeps anything spawned AFTER this point (new floating buttons,
	-- dynamically-rebuilt rows, …) using the right colors too — without
	-- this, only what already existed when the switch happened would
	-- get caught by the descendant walk below.
	C_BG = new.panel_bg; C_ROW = new.panel_bg; C_OFF_BG = new.panel_bg; C_HEADER = new.panel_bg
	C_WHITE = new.text
	for _, guiRoot in ipairs(_themeAllGuis) do
		pcall(function()
			for _, inst in ipairs(guiRoot:GetDescendants()) do
				pcall(function()
					if inst:IsA("GuiObject") then
						local k = _tColKey(inst.BackgroundColor3, oldName)
						if k then inst.BackgroundColor3 = new[k] end
					end
					if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
						local k = _tColKey(inst.TextColor3, oldName)
						if k then inst.TextColor3 = new[k] end
					end
					if inst:IsA("UIStroke") then
						local k = _tColKey(inst.Color, oldName)
						if k then inst.Color = new[k] end
					end
					if inst:IsA("UIGradient") then
						local cs = inst.Color; local kps = cs.Keypoints
						local changed,newKps = false,{}
						for _,kp in ipairs(kps) do
							local k = _tColKey(kp.Value, oldName)
							if k then table.insert(newKps,ColorSequenceKeypoint.new(kp.Time,new[k])); changed=true
							else table.insert(newKps,kp) end
						end
						if changed then inst.Color = ColorSequence.new(newKps) end
					end
				end)
			end
		end)
	end
	-- steal fill gradient: swap between blue shimmer (default), grey shimmer (noir), crimson shimmer
	if _GH.stealFillGradRef and _GH.stealFillGradRef.Parent then
		if newName == "noir" then
			_GH.stealFillGradRef.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,    Color3.fromRGB(20,  20,  20)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(90,  90,  90)),
				ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(200, 200, 200)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90,  90,  90)),
				ColorSequenceKeypoint.new(1,    Color3.fromRGB(20,  20,  20)),
			})
		elseif newName == "crimson" then
			_GH.stealFillGradRef.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,    Color3.fromRGB(60,  10,  20)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(180, 40,  65)),
				ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(255, 150, 165)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(180, 40,  65)),
				ColorSequenceKeypoint.new(1,    Color3.fromRGB(60,  10,  20)),
			})
		elseif newName == "white" then
			_GH.stealFillGradRef.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,    Color3.fromRGB(55,  55,  65)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(180, 180, 195)),
				ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(180, 180, 195)),
				ColorSequenceKeypoint.new(1,    Color3.fromRGB(55,  55,  65)),
			})
		elseif newName == "purple" then
			_GH.stealFillGradRef.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,    Color3.fromRGB(40,  15,  75)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(120, 60,  210)),
				ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(210, 175, 255)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 60,  210)),
				ColorSequenceKeypoint.new(1,    Color3.fromRGB(40,  15,  75)),
			})
		else
			_GH.stealFillGradRef.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,    Color3.fromRGB(10,  30,  90)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(40,  110, 230)),
				ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(150, 210, 255)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(40,  110, 230)),
				ColorSequenceKeypoint.new(1,    Color3.fromRGB(10,  30,  90)),
			})
		end
	end
	-- steal status label gradient: swap ready color on theme change
	if _GH.stealReadyColorFn then pcall(_GH.stealReadyColorFn) end
	if _G_updateThemeUI then _G_updateThemeUI(newName) end
	-- re-color existing float buttons so active-state uses the new C_ON_BG
	if _GH.refreshFloatActiveColors then pcall(_GH.refreshFloatActiveColors) end
	-- player speed billboards live in Workspace (not in _themeAllGuis), update manually
	local psb = _GH.playerSpeedBBs
	if type(psb) == "table" then
		for _, data in pairs(psb) do
			if data.lbl and data.lbl.Parent then
				data.lbl.TextColor3 = C_MOON2
				local g = data.lbl:FindFirstChildOfClass("UIGradient")
				if g then
					g.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0,    C_DEEP4),
						ColorSequenceKeypoint.new(0.25, C_DEEP3),
						ColorSequenceKeypoint.new(0.5,  C_DEEP4),
						ColorSequenceKeypoint.new(0.75, C_DEEP3),
						ColorSequenceKeypoint.new(1,    C_DEEP4),
					})
				end
			end
		end
	end
	-- stun timer billboard (local player) lives in Workspace, update manually
	for _, lbl in ipairs({_GH.speedLblRef, _GH.timerLblRef}) do
		if lbl and lbl.Parent then
			local g = lbl:FindFirstChildOfClass("UIGradient")
			if g then
				if newName == "noir" then
					g.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0,    Color3.fromRGB(60,  60,  60)),
						ColorSequenceKeypoint.new(0.25, Color3.fromRGB(230, 230, 230)),
						ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(140, 140, 140)),
						ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 255)),
						ColorSequenceKeypoint.new(1,    Color3.fromRGB(60,  60,  60)),
					})
				else
					g.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0,    C_DEEP3),
						ColorSequenceKeypoint.new(0.25, C_DEEP4),
						ColorSequenceKeypoint.new(0.5,  C_DEEP3),
						ColorSequenceKeypoint.new(0.75, C_DEEP4),
						ColorSequenceKeypoint.new(1,    C_DEEP3),
					})
				end
			end
		end
	end
end

-- ===================================================================
-- STATE
-- ===================================================================
local State = {
	normalSpeed = 60, carrySpeed = 30, laggerSpeed = 15, laggerCarrySpeed = 24.5,
	speedType = "normal",
	laggerActive = false, laggerCarryActive = false,
	autoLeftEnabled = false, autoRightEnabled = false,
	autoPlayMode = "Full",
	nukeOptEnabled = false, removeAccEnabled = false, antiLagAdvEnabled = false,
	guiVisible = true,
	antiRagdollEnabled = true, unwalkEnabled = false, autoCarryOnGrab = true,
	dropBrainrotActive = false, isStealing = false,
	_carryManualUntil = 0, _lastCarryDetected = false,
	medusaCounterEnabled = false,
	autoResetOnMedEnabled = false,
}

-- ===================================================================
-- HELPERS
-- ===================================================================
local function addCorner(inst, r)
	local c = Instance.new("UICorner", inst)
	c.CornerRadius = UDim.new(0, r or 8)
	return c
end

local function addStroke(inst, col, th, tr)
	local s = Instance.new("UIStroke", inst)
	s.Color = col; s.Thickness = th or 1; s.Transparency = tr or 0
	return s
end

local function addGradient(inst, c1, c2, rot)
	local g = Instance.new("UIGradient", inst)
	g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,c1), ColorSequenceKeypoint.new(1,c2)})
	g.Rotation = rot or 0
	return g
end

-- ===================================================================
-- LIVING GRADIENTS
-- ===================================================================
local _livingGradients = {}
local _livingStrokes   = {}

local function addLivingTextGradient(label)
	local g = Instance.new("UIGradient", label)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    C_DEEP4),
		ColorSequenceKeypoint.new(0.25, C_DEEP3),
		ColorSequenceKeypoint.new(0.5,  C_DEEP4),
		ColorSequenceKeypoint.new(0.75, C_DEEP3),
		ColorSequenceKeypoint.new(1,    C_DEEP4),
	})
	g.Rotation = 0
	table.insert(_livingGradients, g)
	return g
end

local function addLivingStroke(parent, thickness)
	local stroke = Instance.new("UIStroke", parent)
	stroke.Thickness = thickness or 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = C_DEEP3
	local g = Instance.new("UIGradient", stroke)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    C_DEEP1),
		ColorSequenceKeypoint.new(0.25, C_DEEP2),
		ColorSequenceKeypoint.new(0.5,  C_DEEP1),
		ColorSequenceKeypoint.new(0.75, C_DEEP2),
		ColorSequenceKeypoint.new(1,    C_DEEP1),
	})
	table.insert(_livingStrokes, g)
	return stroke, g
end

local function addGreyShimmer(label)
	local g = Instance.new("UIGradient", label)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(60,  60,  60)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(230, 230, 230)),
		ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(140, 140, 140)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(60,  60,  60)),
	})
	g.Rotation = 0
	table.insert(_livingGradients, g)
	return g
end

local function addGreyStroke(parent, thickness)
	local stroke = Instance.new("UIStroke", parent)
	stroke.Thickness = thickness or 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(100, 100, 100)
	local g = Instance.new("UIGradient", stroke)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(10,  10,  10)),
		ColorSequenceKeypoint.new(0.3,  Color3.fromRGB(220, 220, 220)),
		ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(10,  10,  10)),
		ColorSequenceKeypoint.new(0.7,  Color3.fromRGB(220, 220, 220)),
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(10,  10,  10)),
	})
	table.insert(_livingStrokes, g)
	return stroke, g
end

local _livingRotationSpeed = 0.6
local _purgeCounter = 0
RunService.RenderStepped:Connect(function()
	_purgeCounter = _purgeCounter + 1
	if _purgeCounter >= 300 then
		_purgeCounter = 0
		local alive = {}
		for _, g in ipairs(_livingGradients) do if g and g.Parent then alive[#alive+1]=g end end
		_livingGradients = alive
		local aliveS = {}
		for _, g in ipairs(_livingStrokes) do if g and g.Parent then aliveS[#aliveS+1]=g end end
		_livingStrokes = aliveS
	end
	for _, g in ipairs(_livingGradients) do if g and g.Parent then g.Rotation=(g.Rotation+_livingRotationSpeed)%360 end end
	for _, g in ipairs(_livingStrokes)   do if g and g.Parent then g.Rotation=(g.Rotation+_livingRotationSpeed)%360 end end
end)

-- ===================================================================
-- MOONSCAPE
-- ===================================================================

-- ===================================================================
-- DESTROY EXISTING
-- ===================================================================
local function destroyAllMoonHub()
	if _G["_MH_GUI"] and _G["_MH_GUI"].Parent then
		pcall(function() _G["_MH_GUI"]:Destroy() end)
	end
	_G["_MH_GUI"] = nil
end
destroyAllMoonHub()


-- =================================================================
-- GAME LOGIC MODULES (hoisted from _MH_buildUI to reduce local count)
-- =================================================================

-- Movement engine — Ace proxy-Part method (AssemblyLinearVelocity on a
-- Massless Part welded to HumanoidRootPart). Identical to Ace_duels_modified.
local _aceProxy     = nil
local _aceProxyWeld = nil

local function cleanAceProxy()
	if _aceProxy then pcall(function() _aceProxy:Destroy() end); _aceProxy = nil end
	_aceProxyWeld = nil
end

local function ensureAceProxy(hrp2)
	local char = hrp2.Parent
	if _aceProxy and _aceProxy.Parent == char then return _aceProxy end
	cleanAceProxy()
	local p = Instance.new("Part")
	p.Name = _NS .. "PX"; p.Size = Vector3.new(1,1,1)
	p.Transparency = 1; p.CanCollide = false; p.Massless = true
	p.Parent = char
	local w = Instance.new("Weld", p)
	w.Part0 = hrp2; w.Part1 = p; w.C0 = CFrame.new()
	_aceProxyWeld = w; _aceProxy = p
	return p
end

local function proxyMove(dir, speed)
	local char = LP.Character; if not char then return end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	local hrp2 = char:FindFirstChild("HumanoidRootPart")
	if hum then hum:Move(dir, false) end
	if hrp2 then
		local px = ensureAceProxy(hrp2)
		px.AssemblyLinearVelocity = Vector3.new(dir.X * speed, hrp2.AssemblyLinearVelocity.Y, dir.Z * speed)
	end
end

local function proxyStop()
	local char = LP.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	local hrp2 = char and char:FindFirstChild("HumanoidRootPart")
	if hum  then hum:Move(Vector3.zero, false) end
	if hrp2 and _aceProxy then _aceProxy.AssemblyLinearVelocity = Vector3.zero end
	cleanAceProxy()
end

-- [FIX #1 & #6] Séparation des effets de bord : updateCarryState mute State,
-- getCurrentSpeed ne fait que lire (pur). Le guard _carryManualUntil était
-- toujours vrai car tick()-0 > 0 est trivial ; corrigé en tick() >= seuil.
local function updateCarryState()
	local char = LP.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	local isSteal = hum and hum.WalkSpeed < 25
	if State.autoCarryOnGrab and isSteal and State.speedType ~= "carry" then
		State.speedType = "carry"
	elseif State.autoCarryOnGrab and not isSteal and State.speedType == "carry"
		and tick() >= (State._carryManualUntil or 0) then
		State.speedType = "normal"
	end
end

local function getCurrentSpeed()
	local char    = LP.Character
	local hum     = char and char:FindFirstChildOfClass("Humanoid")
	local isSteal = hum and hum.WalkSpeed < 25
	if State.laggerCarryActive or (State.laggerActive and isSteal) then
		return isSteal and State.laggerCarrySpeed or State.laggerSpeed
	elseif State.laggerActive then
		return State.laggerSpeed
	else
		return isSteal and State.carrySpeed or State.normalSpeed
	end
end

local _speedBoosterActive = false  -- controlled by the Speed Booster widget

local h, hrp
local function setupChar(char)
	h = char:WaitForChild("Humanoid", 5)
	hrp = char:WaitForChild("HumanoidRootPart", 5)
	if h then h.WalkSpeed = getCurrentSpeed() end
	cleanAceProxy()  -- destroy any proxy left from previous life
end
LP.CharacterAdded:Connect(setupChar)
if LP.Character then setupChar(LP.Character) end

-- Ace RenderStepped speed loop — identical behaviour to Ace_duels_modified
RunService.RenderStepped:Connect(function()
	if not _speedBoosterActive then cleanAceProxy(); return end
	local char = LP.Character; if not char then cleanAceProxy(); return end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	local hrp2 = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp2 then cleanAceProxy(); return end
	local state = hum:GetState()
	if hum.PlatformStand
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.FallingDown then
		cleanAceProxy(); return
	end
	updateCarryState()
	local md  = hum.MoveDirection
	local spd = getCurrentSpeed()
	if md.Magnitude > 0 then
		local _n = 1 + (math.random() - 0.5) * 0.04
		local px = ensureAceProxy(hrp2)
		px.AssemblyLinearVelocity = Vector3.new(
			md.X * spd * _n,
			hrp2.AssemblyLinearVelocity.Y,
			md.Z * spd * _n
		)
	end
end)

-- ===================================================================
-- PLOT DETECTION
-- ===================================================================

-- ===================================================================
-- PROMPT DETECTION
-- ===================================================================

-- ===================================================================
-- AUTO STEAL (Auto Grab — logique Irish Hub / test_speed.lua)
-- ===================================================================
local AutoSteal = {
	Enabled=true, Radius=70, IsStealing=false,
	ProgressFill=nil, ProgressText=nil, StatusLabel=nil,
	SetFastPulse=nil, FlashSuccess=nil, Widget=nil,
}


-- ── AUTO GRAB V2 mode (new default) ────────────────────────────
local startAutoSteal, stopAutoSteal   -- pre-declared; assigned inside do..end
do
local _KAG_started  = false
local _KAG_conn     = nil
local _KAG_scanTask = nil
local _KAG_Active   = false
local _KAG_Start    = 0
local _KAG_Sync        = { caches={}, connections={} }
local _KAG_AnimalsCache = {}
local _KAG_PromptCache  = {}
local _KAG_StealCache   = {}
local _KAG_SyncRemotes  = nil
local _V2_CFG = { HOLD_MIN=1.3, HOLD_MAX=2.6, ENTRY_DELAY=0.3, COOLDOWN=0.05, STEAL_RANGE=8 }

local function _KAG_splitPath(path)
	if typeof(path)=="table" then return path end
	local out={}
	for part in string.gmatch(tostring(path),"[^%.]+") do table.insert(out, tonumber(part) or part) end
	return out
end
local function _KAG_resolvePath(path, root)
	local cur=root; local par,key=nil,nil
	for _,p in ipairs(_KAG_splitPath(path)) do par=cur; key=p; cur=cur and cur[p] or nil end
	return cur, par, key
end
local function _KAG_applyDiff(cn, packet)
	local cache=_KAG_Sync.caches[cn]; if typeof(cache)~="table" then return end
	local path,action,a,b=packet[1],packet[2],packet[3],packet[4]
	local cur,par,key=_KAG_resolvePath(path,cache)
	if action=="Changed" then if par~=nil then par[key]=a end
	elseif action=="ArrayInsert" then if cur~=nil then table.insert(cur,b,a) end
	elseif action=="ArrayRemoved" then if cur~=nil then table.remove(cur,b) end
	elseif action=="DictionaryInsert" then if cur~=nil then cur[b]=a end
	elseif action=="DictionaryRemoved" then if cur~=nil then cur[b]=nil end end
end
local function _KAG_attachChannel(remote)
	if _KAG_Sync.connections[remote] then return end
	local cn=tostring(remote.Name)
	local plots=workspace:FindFirstChild("Plots"); if not plots or not plots:FindFirstChild(cn) then return end
	if _KAG_SyncRemotes and _KAG_SyncRemotes.requestData and _KAG_Sync.caches[cn]==nil then
		local ok,data=pcall(function() return _KAG_SyncRemotes.requestData:InvokeServer(cn) end)
		_KAG_Sync.caches[cn]=(ok and typeof(data)=="table") and data or {}
	elseif _KAG_Sync.caches[cn]==nil then _KAG_Sync.caches[cn]={} end
	_KAG_Sync.connections[remote]=remote.OnClientEvent:Connect(function(queue)
		for _,packet in ipairs(queue) do _KAG_applyDiff(cn,packet) end
	end)
end
local function _KAG_detachChannel(channelName)
	for remote,conn in pairs(_KAG_Sync.connections) do
		if tostring(remote.Name)==tostring(channelName) then
			conn:Disconnect(); _KAG_Sync.connections[remote]=nil; _KAG_Sync.caches[tostring(channelName)]=nil; break
		end
	end
end
local function _KAG_initSync()
	if _KAG_SyncRemotes then return end
	local RS=game:GetService("ReplicatedStorage")
	local pkg=RS:FindFirstChild("Packages"); if not pkg then return end
	local f=pkg:FindFirstChild("Synchronizer"); if not f then return end
	_KAG_SyncRemotes={
		channelFolder=f:FindFirstChild("Channel"),
		routeRemote  =f:FindFirstChild("CommunicationRoute"),
		requestData  =f:FindFirstChild("RequestData"),
	}
	local cf=_KAG_SyncRemotes.channelFolder; if not cf then return end
	local plots=workspace:FindFirstChild("Plots"); if not plots then return end
	for _,child in ipairs(cf:GetChildren()) do
		if child:IsA("RemoteEvent") then pcall(_KAG_attachChannel,child) end
	end
	cf.ChildAdded:Connect(function(child)
		if child:IsA("RemoteEvent") then task.spawn(function() pcall(_KAG_attachChannel,child) end) end
	end)
	local rr=_KAG_SyncRemotes.routeRemote
	if rr then
		rr.OnClientEvent:Connect(function(actions)
			local pl=workspace:FindFirstChild("Plots"); if not pl then return end
			for _,action in ipairs(actions) do
				local kind,cn=action[1],tostring(action[2])
				if pl:FindFirstChild(cn) then
					if kind=="ListenerAdded" then
						local r=cf:FindFirstChild(cn)
						if r and r:IsA("RemoteEvent") then task.spawn(function() pcall(_KAG_attachChannel,r) end) end
					elseif kind=="ListenerRemoved" then
						_KAG_detachChannel(cn)
					end
				end
			end
		end)
	end
end
local function _KAG_getPlotOwner(plot)
	local sign=plot:FindFirstChild("PlotSign")
	local frame=sign and sign:FindFirstChild("SurfaceGui") and sign.SurfaceGui:FindFirstChild("Frame")
	local label=frame and frame:FindFirstChild("TextLabel")
	if not label or label.Text=="Empty Base" then return nil end
	return label.Text:gsub("'s [Bb]ase$",""):gsub("%s+$","")
end
local function _KAG_isMyAnimal(a)
	if not a or not a.plot then return false end
	local plots=workspace:FindFirstChild("Plots"); if not plots then return false end
	local plot=plots:FindFirstChild(a.plot); if not plot then return false end
	return _KAG_getPlotOwner(plot)==LP.DisplayName
end
local function _KAG_findPrompt(a)
	if not a then return nil end
	local cached=_KAG_PromptCache[a.uid]; if cached and cached.Parent then return cached end
	local plots=workspace:FindFirstChild("Plots"); if not plots then return nil end
	local plot=plots:FindFirstChild(a.plot); if not plot then return nil end
	local pods=plot:FindFirstChild("AnimalPodiums"); if not pods then return nil end
	local pod=pods:FindFirstChild(a.slot); if not pod then return nil end
	local base=pod:FindFirstChild("Base"); if not base then return nil end
	local sp=base:FindFirstChild("Spawn"); if not sp then return nil end
	local att=sp:FindFirstChild("PromptAttachment"); if not att then return nil end
	for _,p in ipairs(att:GetChildren()) do if p:IsA("ProximityPrompt") then _KAG_PromptCache[a.uid]=p; return p end end
	return nil
end
local function _KAG_getPos(a)
	local plots=workspace:FindFirstChild("Plots"); if not plots then return nil end
	local plot=plots:FindFirstChild(a.plot); if not plot then return nil end
	local pods=plot:FindFirstChild("AnimalPodiums"); if not pods then return nil end
	local pod=pods:FindFirstChild(a.slot); if not pod then return nil end
	local ok,pos=pcall(function() return pod:GetPivot().Position end); return ok and pos or nil
end
local function _KAG_distTo(a)
	local char=LP.Character; if not char then return math.huge end
	local hrp=char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso"); if not hrp then return math.huge end
	local pos=_KAG_getPos(a); if not pos then return math.huge end
	return (hrp.Position-pos).Magnitude
end
local function _KAG_pickClosest()
	local char=LP.Character; if not char then return nil end
	local hrp=char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso"); if not hrp then return nil end
	local best,bestDist=nil,math.huge
	local primeRange=AutoSteal.Radius or 80
	for _,a in ipairs(_KAG_AnimalsCache) do
		if not _KAG_isMyAnimal(a) then
			local pos=_KAG_getPos(a)
			if pos then
				local d=(hrp.Position-pos).Magnitude
				if d<=primeRange and d<bestDist then bestDist=d; best=a end
			end
		end
	end
	return best
end
local function _KAG_buildCallbacks(prompt)
	if _KAG_StealCache[prompt] then return end
	local data={hold={},trigger={},ready=true}
	local ok1,c1=pcall(getconnections,prompt.PromptButtonHoldBegan)
	if ok1 and type(c1)=="table" then for _,c in ipairs(c1) do if type(c.Function)=="function" then table.insert(data.hold,c.Function) end end end
	local ok2,c2=pcall(getconnections,prompt.Triggered)
	if ok2 and type(c2)=="table" then for _,c in ipairs(c2) do if type(c.Function)=="function" then table.insert(data.trigger,c.Function) end end end
	if #data.hold>0 or #data.trigger>0 then _KAG_StealCache[prompt]=data end
end
local function _KAG_executeSteal(prompt, a)
	local data=_KAG_StealCache[prompt]; if not data or not data.ready then return false end
	data.ready=false; _KAG_Active=true; State.isStealing=true
	_KAG_Start=tick()
	-- UNREADY immediately at steal start (test_speed.lua exact)
	if AutoSteal.StatusLabel then AutoSteal.StatusLabel.Text="UNREADY" end
	if AutoSteal.SetReadyColor then AutoSteal.SetReadyColor("UNREADY") end
	task.spawn(function()
		for _,fn in ipairs(data.hold) do task.spawn(fn) end
		-- Progress loop (test_speed.lua exact)
		task.spawn(function()
			local _readyShown=false
			while _KAG_Active do
				local prog=math.clamp((tick()-_KAG_Start)/_V2_CFG.HOLD_MAX,0,1)
				if AutoSteal.ProgressFill then AutoSteal.ProgressFill.Size=UDim2.new(prog,0,1,0) end
				if AutoSteal.ProgressText then AutoSteal.ProgressText.Text=math.floor(prog*100).."%" end
				if prog>=0.6 and not _readyShown then
					_readyShown=true
					if AutoSteal.StatusLabel then AutoSteal.StatusLabel.Text="READY" end
					if AutoSteal.SetReadyColor then AutoSteal.SetReadyColor("READY") end
				end
				task.wait()
			end
		end)
		task.wait(_V2_CFG.HOLD_MIN)
		local alreadyClose=_KAG_distTo(a)<=_V2_CFG.STEAL_RANGE
		local fired=false
		while true do
			if tick()-_KAG_Start>_V2_CFG.HOLD_MAX then break end
			if not prompt.Parent then break end
			if _KAG_distTo(a)<=_V2_CFG.STEAL_RANGE then
				if not alreadyClose then task.wait(_V2_CFG.ENTRY_DELAY) end
				for _,fn in ipairs(data.trigger) do task.spawn(fn) end
				fired=true; break
			end
			task.wait()
		end
		_KAG_Active=false; State.isStealing=false
		if AutoSteal.ProgressFill then AutoSteal.ProgressFill.Size=UDim2.new(0,0,1,0) end
		if AutoSteal.ProgressText then AutoSteal.ProgressText.Text="" end
		if AutoSteal.StatusLabel then AutoSteal.StatusLabel.Text="READY" end
		if AutoSteal.SetReadyColor then AutoSteal.SetReadyColor("READY") end
		if fired and AutoSteal.FlashSuccess then AutoSteal.FlashSuccess() end
		task.wait(_V2_CFG.COOLDOWN); data.ready=true
	end)
	return true
end
local function _KAG_attemptSteal(prompt, a)
	if not prompt or not prompt.Parent then return false end
	_KAG_buildCallbacks(prompt)
	if not _KAG_StealCache[prompt] then return false end
	return _KAG_executeSteal(prompt, a)
end
local function _KAG_scanPlots()
	local newCache={}
	local RS=game:GetService("ReplicatedStorage")
	local datas=RS:FindFirstChild("Datas")
	local animData=nil
	if datas then pcall(function() local m=datas:FindFirstChild("Animals"); if m then animData=require(m) end end) end
	local plots=workspace:FindFirstChild("Plots"); if not plots then _KAG_AnimalsCache=newCache; return end
	for _,plot in ipairs(plots:GetChildren()) do
		local cache=_KAG_Sync.caches[plot.Name]
		if cache and typeof(cache)=="table" then
			local list=cache.AnimalList
			if typeof(list)=="table" then
				for slot,ad in pairs(list) do
					if type(ad)=="table" then
						local name=ad.Index
						local info=animData and animData[name]
						if info or not animData then
							table.insert(newCache,{
								name=(info and info.DisplayName) or name,
								plot=plot.Name, slot=tostring(slot),
								uid=plot.Name.."_"..tostring(slot),
							})
						end
					end
				end
			end
		end
	end
	_KAG_AnimalsCache=newCache
end

local function startAutoStealV2()
	if _KAG_started then return end
	_KAG_started=true
	_KAG_initSync()
	task.spawn(function() pcall(_KAG_scanPlots) end)
	_KAG_scanTask=task.spawn(function()
		while _KAG_started do task.wait(5); pcall(_KAG_scanPlots) end
	end)
	local _kState="READY"
	_KAG_conn=RunService.Heartbeat:Connect(function()
		if not AutoSteal.Enabled or _KAG_Active then return end
		local target=_KAG_pickClosest()
		local newState=target and "UNREADY" or "READY"
		if _kState~=newState then
			_kState=newState
			if AutoSteal.StatusLabel then AutoSteal.StatusLabel.Text=newState end
			if AutoSteal.SetReadyColor then AutoSteal.SetReadyColor(newState) end
		end
		if not target then return end
		local prompt=_KAG_PromptCache[target.uid]
		if not prompt or not prompt.Parent then prompt=_KAG_findPrompt(target) end
		if prompt then _KAG_attemptSteal(prompt,target) end
	end)
end
local function stopAutoStealV2()
	_KAG_started=false
	if _KAG_conn then _KAG_conn:Disconnect(); _KAG_conn=nil end
	if _KAG_scanTask then pcall(task.cancel,_KAG_scanTask); _KAG_scanTask=nil end
	_KAG_Active=false; State.isStealing=false
	if AutoSteal.StatusLabel then AutoSteal.StatusLabel.Text="READY" end
end

startAutoSteal = function() startAutoStealV2() end
stopAutoSteal  = function() stopAutoStealV2()  end
end -- do..end AUTO GRAB V2



-- ===================================================================
-- TP DOWN
-- ===================================================================
local function tpToGround()
	local char = LP.Character; if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
	local hum2 = char:FindFirstChildOfClass("Humanoid"); if not hum2 then return end
	-- Amir Hub logic: direct TP to fixed ground Y (-7.00), keeping Y rotation
	root.CFrame = CFrame.new(root.Position.X, -7.00, root.Position.Z)
		* CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
	root.AssemblyLinearVelocity = Vector3.zero
end

-- ===================================================================
-- DROP BRAINROT
-- ===================================================================
local _dropActive = false
local DROP_ASCEND_DURATION = 0.2
local DROP_ASCEND_SPEED    = 150

local function runDropBrainrot()
	if _dropActive then return end
	local char = LP.Character; if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
	_dropActive = true
	local t0 = tick()
	local dc
	dc = RunService.Heartbeat:Connect(function()
		-- Re-fetch LP.Character à chaque frame (comme Ace) : gère un respawn en plein drop
		local curChar = LP.Character
		local r = curChar and curChar:FindFirstChild("HumanoidRootPart")
		if not curChar or not r then dc:Disconnect(); _dropActive = false; return end
		if tick() - t0 >= DROP_ASCEND_DURATION then
			dc:Disconnect()
			-- Raycast to the ground
			local rp = RaycastParams.new()
			rp.FilterDescendantsInstances = {curChar}
			rp.FilterType = Enum.RaycastFilterType.Exclude
			local rr = workspace:Raycast(r.Position, Vector3.new(0, -2000, 0), rp)
			if rr then
				local hum2 = curChar:FindFirstChildOfClass("Humanoid")
				local off  = (hum2 and hum2.HipHeight or 2) + (r.Size.Y / 2)
				r.CFrame = CFrame.new(r.Position.X, rr.Position.Y + off, r.Position.Z)
				r.AssemblyLinearVelocity  = Vector3.zero
				r.AssemblyAngularVelocity = Vector3.zero
			end
			_dropActive = false
			return
		end
		-- Fast ascent phase
		r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, DROP_ASCEND_SPEED, r.AssemblyLinearVelocity.Z)
	end)
end

-- ===================================================================
-- AUTO LEFT / RIGHT  (logique Taser Hub — 2 phases + orientation finale)
-- ===================================================================
local AP_L1     = Vector3.new(-476.48, -6.28, 92.73)
local AP_L2     = Vector3.new(-483.12, -4.95, 94.80)
local AP_L_FACE = Vector3.new(-482.25, -4.96, 92.09)
local AP_R1     = Vector3.new(-476.16, -6.52, 25.62)
local AP_R2     = Vector3.new(-483.06, -5.03, 25.48)
local AP_R_FACE = Vector3.new(-482.06, -6.93, 35.47)

local alConn, arConn = nil, nil
local alPhase, arPhase = 1, 1

local function stopAutoLeft()
	if alConn then alConn:Disconnect(); alConn = nil end
	alPhase = 1; proxyStop(); State.autoLeftEnabled = false
end

local function stopAutoRight()
	if arConn then arConn:Disconnect(); arConn = nil end
	arPhase = 1; proxyStop(); State.autoRightEnabled = false
end

local function startAutoLeft()
	if _GH.SM_tryStart and not _GH.SM_tryStart() then return end
	if State.autoRightEnabled then stopAutoRight() end
	if alConn then alConn:Disconnect() end
	alPhase = 1; State.autoLeftEnabled = true
	alConn = RunService.Heartbeat:Connect(function()
		if not State.autoLeftEnabled then return end
		local char = LP.Character; if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		local st = hum:GetState()
		if hum.PlatformStand or st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then hum:Move(Vector3.zero,false); return end
		local spd = State.normalSpeed
		if alPhase == 1 then
			if (Vector3.new(AP_L1.X, hrp.Position.Y, AP_L1.Z) - hrp.Position).Magnitude < 1 then
				alPhase = 2
			end
			local d = AP_L1 - hrp.Position
			proxyMove(Vector3.new(d.X, 0, d.Z).Unit, spd)
		elseif alPhase == 2 then
			if (Vector3.new(AP_L2.X, hrp.Position.Y, AP_L2.Z) - hrp.Position).Magnitude < 1 then
				proxyStop(); State.autoLeftEnabled = false
				if alConn then alConn:Disconnect(); alConn = nil end
				alPhase = 1
				hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(AP_L_FACE.X, hrp.Position.Y, AP_L_FACE.Z))
				return
			end
			local d = AP_L2 - hrp.Position
			proxyMove(Vector3.new(d.X, 0, d.Z).Unit, spd)
		end
	end)
end

local function startAutoRight()
	if _GH.SM_tryStart and not _GH.SM_tryStart() then return end
	if State.autoLeftEnabled then stopAutoLeft() end
	if arConn then arConn:Disconnect() end
	arPhase = 1; State.autoRightEnabled = true
	arConn = RunService.Heartbeat:Connect(function()
		if not State.autoRightEnabled then return end
		local char = LP.Character; if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		local st = hum:GetState()
		if hum.PlatformStand or st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then hum:Move(Vector3.zero,false); return end
		local spd = State.normalSpeed
		if arPhase == 1 then
			if (Vector3.new(AP_R1.X, hrp.Position.Y, AP_R1.Z) - hrp.Position).Magnitude < 1 then
				arPhase = 2
			end
			local d = AP_R1 - hrp.Position
			proxyMove(Vector3.new(d.X, 0, d.Z).Unit, spd)
		elseif arPhase == 2 then
			if (Vector3.new(AP_R2.X, hrp.Position.Y, AP_R2.Z) - hrp.Position).Magnitude < 1 then
				proxyStop(); State.autoRightEnabled = false
				if arConn then arConn:Disconnect(); arConn = nil end
				arPhase = 1
				hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(AP_R_FACE.X, hrp.Position.Y, AP_R_FACE.Z))
				return
			end
			local d = AP_R2 - hrp.Position
			proxyMove(Vector3.new(d.X, 0, d.Z).Unit, spd)
		end
	end)
end

-- ===================================================================
-- ANTI RAGDOLL
-- ===================================================================
-- Copie exacte de la logique Ace Duels (startAntiRagdoll/stopAntiRagdoll/
-- setAntiRagdoll) : state Physics/Ragdoll/FallingDown + attribut
-- RagdollEndTime, destroy BallSocketConstraint/RagdollAttachment,
-- re-enable Motor6D, unanchor + zero velocity. Ancienne logique
-- (JumpPower/WalkSpeed/CanCollide/ControlModule/Dead/PlatformStand/Sit)
-- supprimée — Ace ne fait rien de tout ça.
local antiRagdollConn = nil

local function startAntiRagdoll()
	if antiRagdollConn then return end
	antiRagdollConn = RunService.Heartbeat:Connect(function()
		if not State.antiRagdollEnabled then return end
		local char = LP.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if not (hum and root) then return end
		local s = hum:GetState()
		local ragdolled = (
			s == Enum.HumanoidStateType.Physics
			or s == Enum.HumanoidStateType.Ragdoll
			or s == Enum.HumanoidStateType.FallingDown
		)
		local endTime = LP:GetAttribute("RagdollEndTime")
		if endTime and (endTime - workspace:GetServerTimeNow()) > 0 then
			ragdolled = true
		end
		if ragdolled then
			pcall(function()
				LP:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow())
			end)
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and d.Name:find("RagdollAttachment")) then
					pcall(function() d:Destroy() end)
				end
			end
			for _, obj in ipairs(char:GetDescendants()) do
				if obj:IsA("Motor6D") and obj.Enabled == false then
					obj.Enabled = true
				end
			end
			if hum.Health > 0 then
				hum:ChangeState(Enum.HumanoidStateType.Running)
			end
			workspace.CurrentCamera.CameraSubject = hum
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

local function stopAntiRagdoll()
	if antiRagdollConn then
		antiRagdollConn:Disconnect()
		antiRagdollConn = nil
	end
end

LP.CharacterAdded:Connect(function()
	task.wait(0.5)
	if State.antiRagdollEnabled then startAntiRagdoll() end
end)

-- ===================================================================
-- UNWALK
-- ===================================================================
local savedAnimate = nil
local function startUnwalk()
	if State.unwalkEnabled then return end; State.unwalkEnabled = true
	local c=LP.Character; if not c then return end
	local hum=c:FindFirstChildOfClass("Humanoid")
	if hum then for _,t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end end
	local anim=c:FindFirstChild("Animate"); if anim then savedAnimate=anim:Clone(); anim:Destroy() end
end
local function stopUnwalk()
	if not State.unwalkEnabled then return end; State.unwalkEnabled=false
	local c=LP.Character
	if c and savedAnimate then savedAnimate.Parent=c; savedAnimate.Disabled=false; savedAnimate=nil end
end
-- Restart Unwalk after every respawn if active
LP.CharacterAdded:Connect(function(char)
	if State.unwalkEnabled then
		State.unwalkEnabled = false  -- reset so startUnwalk accepts
		savedAnimate = nil
		task.wait(0.5)               -- laisser le character se charger
		startUnwalk()
	end
end)

-- ===================================================================
-- AUTO CARRY ON GRAB
-- ===================================================================
local lastCarryDetected = false
RunService.Heartbeat:Connect(function()
	if not State.autoCarryOnGrab then return end
	if State.laggerActive or State.laggerCarryActive then return end
	if tick() < (State._carryManualUntil or 0) then return end
	local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local carrying = (hum.WalkSpeed <= 25)
	if carrying==lastCarryDetected then return end
	lastCarryDetected=carrying; State.speedType=carrying and "carry" or "normal"
end)

-- ===================================================================
-- OPTIMIZE MODULE
-- ===================================================================
local NukeOpt = {active=false, conns={}, threads={}}
local function nukeOptStart()
	if NukeOpt.active then return end; NukeOpt.active=true
	-- [FIX Perf #1] Lookup O(1) par ClassName au lieu de O(12) par itération de liste.
	-- Ces types n'ont pas de sous-classes Roblox, donc ClassName est équivalent à IsA.
	local ClothingSet = {
		Shirt=true, Pants=true, ShirtGraphic=true, Accessory=true, Hat=true,
		HairAccessory=true, FaceAccessory=true, NeckAccessory=true,
		ShoulderAccessory=true, FrontAccessory=true, BackAccessory=true, WaistAccessory=true,
	}
	local function IsClothing(obj) return ClothingSet[obj.ClassName] == true end
	local function IsCharacterPart(obj) for _,p in ipairs(Players:GetPlayers()) do if p.Character and obj:IsDescendantOf(p.Character) then return true end end end
	local function SafeDestroy(obj) if obj.Name~="Overhead" then pcall(function() obj:Destroy() end) end end
	local function CleanObject(obj)
		pcall(function()
			if obj:IsA("SurfaceAppearance") or obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
				or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")
				or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Explosion") then
				SafeDestroy(obj)
			elseif obj:IsA("Decal") or obj:IsA("Texture") then
				if not (obj.Name=="face" and obj.Parent and obj.Parent.Name=="Head") then SafeDestroy(obj) end
			elseif obj:IsA("BasePart") then obj.CastShadow=false; obj.Material=Enum.Material.Plastic; obj.Reflectance=0 end
		end)
	end
	Lighting.GlobalShadows=false; Lighting.FogEnd=9e9; Lighting.EnvironmentDiffuseScale=0; Lighting.EnvironmentSpecularScale=0
	for _,v in ipairs(Lighting:GetChildren()) do
		if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then v:Destroy() end
	end
	table.insert(NukeOpt.threads, task.spawn(function()
		for _,obj in ipairs(workspace:GetDescendants()) do
			if not NukeOpt.active then return end
			if not IsCharacterPart(obj) then if IsClothing(obj) then SafeDestroy(obj) else CleanObject(obj) end end
		end
	end))
	table.insert(NukeOpt.conns, workspace.DescendantAdded:Connect(function(obj)
		if not NukeOpt.active then return end
		task.defer(function()
			if not NukeOpt.active then return end
			if not IsCharacterPart(obj) then if IsClothing(obj) then SafeDestroy(obj) else CleanObject(obj) end end
		end)
	end))
end
local function nukeOptStop()
	NukeOpt.active=false
	for _,c in ipairs(NukeOpt.conns) do pcall(function() c:Disconnect() end) end; NukeOpt.conns={}
end

local RemoveAcc = {active=false, conn=nil, removed=setmetatable({},{__mode="k"})}
local function removeAccDo()
	if not RemoveAcc.active then return end; local char=LP.Character; if not char then return end
	for _,obj in ipairs(char:GetDescendants()) do
		if (obj:IsA("Accessory") or obj:IsA("Hat")) and not RemoveAcc.removed[obj] then
			RemoveAcc.removed[obj]=true; pcall(function() obj:Destroy() end)
		end
	end
end
local function removeAccStart()
	if RemoveAcc.active then return end; RemoveAcc.active=true; removeAccDo()
	RemoveAcc.conn=LP.CharacterAdded:Connect(function() task.wait(0.5); if RemoveAcc.active then removeAccDo() end end)
end
local function removeAccStop()
	RemoveAcc.active=false; if RemoveAcc.conn then RemoveAcc.conn:Disconnect(); RemoveAcc.conn=nil end
end

local function cleanParticlesAndLights()
	local removed=0
	for _,obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire")
			or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Explosion")
			or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
			pcall(function() obj:Destroy() end); removed=removed+1
		end
	end; return removed
end

local AntiLagAdv = {active=false, conn=nil}
local function _applyAntiLagAdvObj(obj)
	pcall(function()
		if obj:IsA("BasePart") then obj.Material=Enum.Material.Plastic; obj.Reflectance=0; obj.CastShadow=false
		elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency=1
		elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then obj.Enabled=false end
	end)
end
local function antiLagAdvStart()
	if AntiLagAdv.active then return end; AntiLagAdv.active=true; Lighting.GlobalShadows=false
	for _,obj in ipairs(workspace:GetDescendants()) do _applyAntiLagAdvObj(obj) end
	AntiLagAdv.conn=workspace.DescendantAdded:Connect(function(obj) if AntiLagAdv.active then _applyAntiLagAdvObj(obj) end end)
end
local function antiLagAdvStop()
	AntiLagAdv.active=false; if AntiLagAdv.conn then AntiLagAdv.conn:Disconnect(); AntiLagAdv.conn=nil end
end

-- ===================================================================
-- ===================================================================
-- MEDUSA COUNTER (logique raw__59_)
-- MEDUSA COUNTER (raw__59_ logic)
-- Copie exacte de la logique Ace Duels : cooldown 25s (pas 0.5s),
-- check State.medusaCounterEnabled dans useMedusaCounter lui-même,
-- wait 0.05s après l'équip avant d'activer.
local _medLastUsed = 0
local _medDebounce = false
local _medConns = {}
local _MED_COOLDOWN = 25

local function findMedusa()
	local char=LP.Character; if not char then return nil end
	for _,tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then local tn=tool.Name:lower()
			if tn:find("medusa") or tn:find("head") or tn:find("stone") then return tool end
		end
	end
	local bp2=LP:FindFirstChild("Backpack") or LP:FindFirstChildOfClass("Backpack")
	if bp2 then
		for _,tool in ipairs(bp2:GetChildren()) do
			if tool:IsA("Tool") then local tn=tool.Name:lower()
				if tn:find("medusa") or tn:find("head") or tn:find("stone") then return tool end
			end
		end
	end
	return nil
end

local function useMedusaCounter()
	if not State.medusaCounterEnabled then return end
	if _medDebounce then return end
	if tick()-_medLastUsed < _MED_COOLDOWN then return end
	local char=LP.Character; if not char then return end
	_medDebounce=true
	local med=findMedusa(); if not med then _medDebounce=false; return end
	if med.Parent~=char then
		local hum2=char:FindFirstChildOfClass("Humanoid"); if hum2 then pcall(function() hum2:EquipTool(med) end) end
		task.wait(0.05)
	end
	pcall(function() med:Activate() end)
	_medLastUsed=tick(); _medDebounce=false
end

local function setupMedusaCounter(char)
	for _,c in pairs(_medConns) do pcall(function() c:Disconnect() end) end; _medConns={}
	if not char then return end
	local function watchPart(part)
		table.insert(_medConns, part:GetPropertyChangedSignal("Anchored"):Connect(function()
			if part.Anchored and part.Transparency==1 then useMedusaCounter() end
		end))
	end
	for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then watchPart(part) end end
	table.insert(_medConns, char.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then watchPart(part) end
	end))
end
local function stopMedusaCounter()
	for _,c in pairs(_medConns) do pcall(function() c:Disconnect() end) end; _medConns={}
end

LP.CharacterAdded:Connect(function(char) if State.medusaCounterEnabled then task.wait(0.5); setupMedusaCounter(char) end end)

-- ===================================================================
-- AUTO RESET MEDUSA (Taser Hub — PlatformStand + Anchored detect)
-- ===================================================================
-- Copie exacte de la logique Ace Duels (AceAutoResetShouldFire/FireOnce/
-- OnAnchorChanged/Start/Stop) : détecte uniquement Anchored+Transparent
-- (signature freeze Medusa), exclut les parts d'un Tool/Accessory,
-- cooldown 2.25s + debounce medTriggered + délai 2.3s avant le reset.
-- L'ancienne détection PlatformStand (absente chez Ace, faux positifs
-- sur tout ragdoll normal) est supprimée.
local _armState = {
	conns = {}, enabled = false, medTriggered = false,
	lastFire = 0, cooldown = 2.25,
}

local function _armShouldFire(part)
	if not _armState.enabled then return false end
	if _armState.medTriggered then return false end
	if tick() - (_armState.lastFire or 0) < _armState.cooldown then return false end
	if not part or not part.Parent then return false end
	if part:FindFirstAncestorOfClass("Tool") or part:FindFirstAncestorOfClass("Accessory") then
		return false
	end
	return part.Anchored and part.Transparency == 1
end

local function _armFireOnce(part)
	if not _armShouldFire(part) then return end
	_armState.medTriggered = true
	_armState.lastFire = tick()
	task.delay(2.3, function()
		if _armState.enabled and _GH.MH_instareset then
			pcall(_GH.MH_instareset)
		end
	end)
end

local function _armWatchPart(part)
	return part:GetPropertyChangedSignal("Anchored"):Connect(function()
		_armFireOnce(part)
	end)
end

local function setupAutoResetMedusa(char)
	for _, c in pairs(_armState.conns) do pcall(function() c:Disconnect() end) end
	_armState.conns = {}
	_armState.medTriggered = false
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(_armState.conns, _armWatchPart(part))
			_armFireOnce(part)
		end
	end
	table.insert(_armState.conns, char.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			table.insert(_armState.conns, _armWatchPart(part))
			_armFireOnce(part)
		end
	end))
end

local function stopAutoResetMedusa()
	for _, c in pairs(_armState.conns) do pcall(function() c:Disconnect() end) end
	_armState.conns = {}
	_armState.medTriggered = false
end

LP.CharacterAdded:Connect(function(char)
	task.wait(0.5); if _armState.enabled then setupAutoResetMedusa(char) end
end)


-- ===================================================================
-- BAT AIMBOT + AIM BYPASS (logique raw__59_)
-- BAT AIMBOT + AIM BYPASS (raw__59_ logic)
local VYSE_HIT_DIST = 5
local AB_SPEED      = 58
local AB_HIT_CD     = false

local BAT_NAMES = {"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap"}

local function getBat()
	local c=LP.Character; if not c then return nil end
	for _,name in ipairs(BAT_NAMES) do local t=c:FindFirstChild(name); if t and t:IsA("Tool") then return t end end
	local bp=LP:FindFirstChildOfClass("Backpack"); if bp then
		for _,name in ipairs(BAT_NAMES) do local t=bp:FindFirstChild(name); if t then return t end end
	end
end

local function tryHitBat()
	if AB_HIT_CD then return end; AB_HIT_CD=true
	pcall(function()
		local bat=getBat(); if not bat then return end
		local c=LP.Character; local hum2=c and c:FindFirstChildOfClass("Humanoid")
		if bat.Parent~=c and hum2 then pcall(function() hum2:EquipTool(bat) end) end
		pcall(function() bat:Activate() end)
	end)
	task.delay(0.2, function() AB_HIT_CD=false end)
end

local function getClosestPlayerAim()
	local root=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not root then return nil,math.huge end
	local closest,minDist=nil,math.huge
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr~=LP and plr.Character then
			local tr=plr.Character:FindFirstChild("HumanoidRootPart"); local hum2=plr.Character:FindFirstChildOfClass("Humanoid")
			if tr and hum2 and hum2.Health>0 then
				local d=(tr.Position-root.Position).Magnitude; if d<minDist then minDist=d; closest=plr end
			end
		end
	end
	return closest,minDist
end

	-- Aimbot (prediction + 0.8 lerp)
local AB = {active=false, conn=nil, SPEED=AB_SPEED, HEIGHT=3.7}
function AB.start()
	if _GH.SM_tryStart and not _GH.SM_tryStart() then return end
	AB.active=true
	if AB.conn then AB.conn:Disconnect() end
	local hum0=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if hum0 then hum0.AutoRotate=false end
	AB.conn=RunService.RenderStepped:Connect(function()
		if not AB.active then return end
		local char=LP.Character; if not char then return end
		local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
		local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
		if not char:FindFirstChildOfClass("Tool") then local bat=getBat(); if bat then pcall(function() hum:EquipTool(bat) end) end end
		local target,dist=getClosestPlayerAim()
		if not target or not target.Character then return end
		local tr=target.Character:FindFirstChild("HumanoidRootPart"); if not tr then return end
		local targetVel=tr.AssemblyLinearVelocity
		local myPos=root.Position; local targetPos=tr.Position
		local predictPos=targetPos+targetVel*0.14+tr.CFrame.LookVector*0.3
		local direction=predictPos-myPos; local flatDir=Vector3.new(direction.X,0,direction.Z).Unit
		local desiredHeight=targetPos.Y+AB.HEIGHT
		local yVel=(desiredHeight-myPos.Y)*19.5+targetVel.Y*0.8
		if hum.FloorMaterial~=Enum.Material.Air then yVel=math.max(yVel,13) end
		yVel=math.clamp(yVel,-70,110)
		local desiredVel=Vector3.new(flatDir.X*AB.SPEED,yVel,flatDir.Z*AB.SPEED)
		root.AssemblyLinearVelocity=root.AssemblyLinearVelocity:Lerp(desiredVel,0.8)
		local speed3=targetVel.Magnitude; local predictTime=math.clamp(speed3/150,0.05,0.2)
		local predictedPos=targetPos+targetVel*predictTime; local toPredict=predictedPos-myPos
		if toPredict.Magnitude>0.1 then
			local goalCF=CFrame.lookAt(myPos,predictedPos); local diffCF=root.CFrame:Inverse()*goalCF
			local rx,ry,rz=diffCF:ToEulerAnglesXYZ()
			rx=math.clamp(rx,-2.5,2.5); ry=math.clamp(ry,-2.5,2.5); rz=math.clamp(rz,-2.5,2.5)
			root.AssemblyAngularVelocity=root.CFrame:VectorToWorldSpace(Vector3.new(rx*42,ry*42,rz*42))
		end
		if dist<=VYSE_HIT_DIST then tryHitBat() end
	end)
end
function AB.stop()
	AB.active=false; if AB.conn then AB.conn:Disconnect(); AB.conn=nil end
	AB_HIT_CD=false
	local char=LP.Character; local root=char and char:FindFirstChild("HumanoidRootPart"); local hum=char and char:FindFirstChildOfClass("Humanoid")
	if root then root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero end
	if hum then hum.AutoRotate=true end
end

-- Aim Bypass (face tracking)
-- ===================================================================
-- AIM V3 (anti-desync + TP ennemi + frappe)
-- AIM V3 (anti-desync + enemy TP + strike)
local AimV3 = {active=false, conn=nil}
local _av3HitCD = false

local function _av3GetBat()
	local char=LP.Character; if not char then return nil end
	-- Looks for "Bat" only, like in aimv3.txt (simple getBat)
	local tool=char:FindFirstChild("Bat"); if tool then return tool end
	local bp=LP:FindFirstChildOfClass("Backpack")
	if bp then tool=bp:FindFirstChild("Bat"); if tool then tool.Parent=char; return tool end end
	-- Fallback to all bat-type tools (BAT_NAMES already includes "Bat")
	for _,n in ipairs(BAT_NAMES) do
		local t=char:FindFirstChild(n); if t then return t end
		if bp then t=bp:FindFirstChild(n); if t then t.Parent=char; return t end end
	end
	return nil
end

local function _av3Hit()
	if _av3HitCD then return end
	_av3HitCD=true
	pcall(function()
		local bat=_av3GetBat(); if not bat then return end
		pcall(function() bat:Activate() end)
		local ev=bat:FindFirstChildWhichIsA("RemoteEvent")
		if ev then pcall(function() ev:FireServer() end) end
	end)
	task.delay(0.08,function() _av3HitCD=false end)
end

local function _av3Nearest(root)
	local best,bestD=nil,math.huge
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=LP and p.Character then
			local tr=p.Character:FindFirstChild("HumanoidRootPart")
			if tr then local d=(root.Position-tr.Position).Magnitude; if d<bestD then bestD=d; best=p end end
		end
	end
	return best
end

function AimV3.start()
	if _GH.SM_tryStart and not _GH.SM_tryStart() then return end
	if AimV3.conn then AimV3.conn:Disconnect() end; AimV3.active=true
	AimV3.conn=RunService.Heartbeat:Connect(function()
		if not AimV3.active then return end
		local root=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
		local target=_av3Nearest(root); if not target or not target.Character then return end
		local tr=target.Character:FindFirstChild("HumanoidRootPart"); if not tr then return end
		pcall(function()
			if sethiddenproperty then sethiddenproperty(root,"PhysicsRepRootPart",tr) end
			local targetPos=tr.Position+Vector3.new(0,0.9,0)
			if (root.Position-targetPos).Magnitude>8 then root.CFrame=CFrame.new(targetPos) end
			local cam=workspace.CurrentCamera
			cam.CFrame=CFrame.new(cam.CFrame.Position,tr.Position)
			_av3Hit()
		end)
	end)
end
function AimV3.stop()
	if AimV3.conn then AimV3.conn:Disconnect(); AimV3.conn=nil end; AimV3.active=false
end

-- Aim V2 / Anti-Bypass — copie exacte de AceStartAntiBypassAimbot :
-- chase direct (pas de prédiction de vélocité), Lerp 0.8 sur la vitesse,
-- clamp Y [-70,110], rotation via AssemblyAngularVelocity clampée ±2.5
-- rad puis *42. Swing distance-gated (8 studs) avec cooldown 0.35s.
-- Ancien système (unwalk, scan-cache, TURN_SPEED/MAX_TURN_RATE,
-- FOLLOW_DIST/standPos) supprimé — n'existe pas chez Ace.
local ABP = {active=false, conn=nil, swingCooldown=false}
local ABP_SPEED = 58

local function ABP_findBat()
	local char=LP.Character; if not char then return nil end
	for _,name in ipairs(BAT_NAMES) do
		local t=char:FindFirstChild(name)
		if t and t:IsA("Tool") then return t end
	end
	local bp=LP:FindFirstChildOfClass("Backpack")
	if bp then
		for _,name in ipairs(BAT_NAMES) do
			local t=bp:FindFirstChild(name)
			if t and t:IsA("Tool") then
				local hum=char:FindFirstChildOfClass("Humanoid")
				if hum then pcall(function() hum:EquipTool(t) end) end
				return t
			end
		end
	end
	for _,ch in ipairs(char:GetChildren()) do
		if ch:IsA("Tool") and (ch.Name:lower():find("bat") or ch.Name:lower():find("slap")) then return ch end
	end
	return nil
end

local function ABP_trySwing()
	if ABP.swingCooldown then return end
	ABP.swingCooldown = true
	pcall(function()
		local char=LP.Character; if not char then return end
		local bat=ABP_findBat()
		if bat then
			if bat.Parent~=char then
				local hum=char:FindFirstChildOfClass("Humanoid")
				if hum then pcall(function() hum:EquipTool(bat) end) end
			end
			pcall(function() bat:Activate() end)
		end
	end)
	task.delay(0.35, function() ABP.swingCooldown = false end)
end

local function ABP_getClosest()
	local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil, math.huge end
	local closest, minDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and plr.Character then
			local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			if tRoot and hum and hum.Health > 0 then
				local dist = (tRoot.Position - root.Position).Magnitude
				if dist < minDist then minDist = dist; closest = tRoot end
			end
		end
	end
	return closest, minDist
end

function ABP.start()
	if _GH.SM_tryStart and not _GH.SM_tryStart() then return end
	if ABP.conn then ABP.conn:Disconnect() end; ABP.active=true
	local hum0=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if hum0 then hum0.AutoRotate=false end
	ABP.conn=RunService.Heartbeat:Connect(function()
		if not ABP.active then return end
		local char=LP.Character; if not char then return end
		local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
		local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
		if not char:FindFirstChildOfClass("Tool") then
			local bat=ABP_findBat(); if bat then pcall(function() hum:EquipTool(bat) end) end
		end
		local target, targetDist = ABP_getClosest()
		if not target then return end
		local myPos = root.Position
		local targetPos = target.Position
		local direction = targetPos - myPos
		local flatDir = Vector3.new(direction.X, 0, direction.Z)
		flatDir = flatDir.Magnitude > 0 and flatDir.Unit or Vector3.zero
		local desiredHeight = targetPos.Y + 3.7
		local yVel = (desiredHeight - myPos.Y) * 19.5
		if hum.FloorMaterial ~= Enum.Material.Air then yVel = math.max(yVel, 13) end
		yVel = math.clamp(yVel, -70, 110)
		local desiredVel = Vector3.new(flatDir.X * ABP_SPEED, yVel, flatDir.Z * ABP_SPEED)
		root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)
		local toTarget = targetPos - myPos
		if toTarget.Magnitude > 0.1 then
			local goalCF = CFrame.lookAt(myPos, targetPos)
			local diffCF = root.CFrame:Inverse() * goalCF
			local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
			rx = math.clamp(rx, -2.5, 2.5); ry = math.clamp(ry, -2.5, 2.5); rz = math.clamp(rz, -2.5, 2.5)
			root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(Vector3.new(rx*42, ry*42, rz*42))
		end
		if targetDist <= 8 then ABP_trySwing() end
	end)
end
function ABP.stop()
	if ABP.conn then ABP.conn:Disconnect(); ABP.conn=nil end; ABP.active=false
	ABP.swingCooldown = false
	local c=LP.Character; local root=c and c:FindFirstChild("HumanoidRootPart")
	if root then root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero end
	local hum2=c and c:FindFirstChildOfClass("Humanoid")
	if hum2 then hum2.AutoRotate=true end
end

-- ===================================================================
-- INFINITE JUMP
-- ===================================================================
-- Copie exacte de la logique Ace Duels : pas de mode manuel/hold, un
-- seul comportement — boost immédiat à chaque JumpRequest (tap) +
-- boost continu si maintenu >0.12s (clavier Espace, ButtonA manette,
-- bouton mobile JumpButton). Ancien système manual/hold + clamp de
-- chute supprimé — Ace n'a rien de tout ça.
local IJ = {active=false, holdPressed=false, holdActive=false, controllerActive=false,
	mobilePressed=false, mobileActive=false, hooked={}, conns={}}

local function _ijStopHoldState()
	IJ.holdPressed=false; IJ.holdActive=false; IJ.controllerActive=false
	IJ.mobilePressed=false; IJ.mobileActive=false
end

local function _ijApplyBoost(boost)
	if not IJ.active then return end
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end
	root.Velocity = Vector3.new(root.Velocity.X, boost or 50, root.Velocity.Z)
end

local function _ijHookMobileJumpButton(obj)
	if not obj or obj.Name ~= "JumpButton" or not obj:IsA("GuiButton") or IJ.hooked[obj] then return end
	IJ.hooked[obj] = true
	obj.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch or not IJ.active then return end
		IJ.mobilePressed = true
		task.delay(0.12, function()
			if IJ.mobilePressed and IJ.active then
				IJ.mobileActive = true
				_ijApplyBoost(50)
			end
		end)
	end)
	obj.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			IJ.mobilePressed = false; IJ.mobileActive = false
		end
	end)
	obj.AncestryChanged:Connect(function(_, parent)
		if not parent then
			IJ.hooked[obj] = nil; IJ.mobilePressed = false; IJ.mobileActive = false
		end
	end)
end

function IJ.start()
	if IJ.conns.jumpReq then return end -- déjà démarré (les hooks tournent en continu, gated par IJ.active)
	IJ.conns.jumpReq = UIS.JumpRequest:Connect(function()
		_ijApplyBoost(50)
	end)
	IJ.conns.inputBegan = UIS.InputBegan:Connect(function(input)
		if UIS:GetFocusedTextBox() then return end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
			IJ.holdPressed = true
			task.delay(0.12, function()
				if IJ.holdPressed and IJ.active then
					IJ.holdActive = true
					_ijApplyBoost(50)
				end
			end)
		elseif input.KeyCode == Enum.KeyCode.ButtonA and input.UserInputType.Name:match("^Gamepad") then
			IJ.controllerActive = true
		end
	end)
	IJ.conns.inputEnded = UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
			IJ.holdPressed = false; IJ.holdActive = false
		end
		if input.KeyCode == Enum.KeyCode.ButtonA and input.UserInputType.Name:match("^Gamepad") then
			IJ.controllerActive = false
		end
	end)
	local pg = LP:FindFirstChild("PlayerGui")
	if pg then
		for _, obj in ipairs(pg:GetDescendants()) do _ijHookMobileJumpButton(obj) end
		IJ.conns.descAdded = pg.DescendantAdded:Connect(function(obj)
			task.defer(_ijHookMobileJumpButton, obj)
		end)
	end
	IJ.conns.heartbeat = RunService.Heartbeat:Connect(function()
		if IJ.active and (IJ.holdActive or IJ.mobileActive or IJ.controllerActive) then
			_ijApplyBoost(50)
		end
	end)
end
function IJ.stop()
	_ijStopHoldState()
	for _, c in pairs(IJ.conns) do pcall(function() c:Disconnect() end) end
	IJ.conns = {}
end

-- ===================================================================
-- BUILD PAGES
-- ===================================================================
local setAutoStealRowVisual
local setAntiRagdollRowVisual
local setBatCounterRowVisual
local setAimbotRowVisual
local setAimbotV2RowVisual
local setInfJumpRowVisual

	-- Bat Counter — source bat_counter.txt (RemoteEvent support + "bat" keyword fallback)
local BatCounter = {active=false, conn=nil}
local _bcDebounce = false

-- findBatForCounter/swingBatForCounter identiques à Ace. isRagdoll
-- ajoute hum.PlatformStand (absent avant) — copie AceCounterIsRagdoll.
local function findBatForCounter()
	local c=LP.Character; if not c then return nil end
	local bp=LP:FindFirstChildOfClass("Backpack") or LP:FindFirstChild("Backpack")
	for _,name in ipairs(BAT_NAMES) do
		local t=c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
		if t then return t end
	end
	for _,ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
	if bp then for _,ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
	return nil
end
local function swingBatForCounter(bat,char)
	local hum2=char:FindFirstChildOfClass("Humanoid")
	if bat.Parent~=char then if hum2 then pcall(function() hum2:EquipTool(bat) end) end; task.wait(0.05) end
	local remote=bat:FindFirstChildOfClass("RemoteEvent") or bat:FindFirstChildOfClass("RemoteFunction")
	if remote and remote:IsA("RemoteEvent") then
		pcall(function() remote:FireServer() end); task.wait(0.15); pcall(function() remote:FireServer() end)
	else pcall(function() bat:Activate() end); task.wait(0.15); pcall(function() bat:Activate() end) end
end
local function isRagdollForCounter(hum2)
	if not hum2 then return false end
	local st=hum2:GetState()
	return st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll
		or st==Enum.HumanoidStateType.FallingDown or hum2.PlatformStand==true
end
function BatCounter.start()
	if BatCounter.conn then BatCounter.conn:Disconnect() end
	BatCounter.conn=RunService.Heartbeat:Connect(function()
		if not BatCounter.active or _bcDebounce then return end
		local char=LP.Character; if not char then return end
		local hum2=char:FindFirstChildOfClass("Humanoid"); if not hum2 then return end
		if isRagdollForCounter(hum2) then
			_bcDebounce=true
			task.spawn(function()
				local bat=findBatForCounter()
				if bat then swingBatForCounter(bat,char) end
				task.wait(0.5); _bcDebounce=false
			end)
		end
	end)
end
function BatCounter.stop()
	if BatCounter.conn then BatCounter.conn:Disconnect(); BatCounter.conn=nil end
	_bcDebounce=false
end

-- ===================================================================
-- ANTI-DIE (source: anti_die_made_by_mehneymarish_11.txt)
-- ===================================================================
local _adLoop    = nil
local _adCharConn = nil
local _adInvincibleUntil = 0
local _adConfig  = { healthThreshold=25, fallDamageProtection=true, ragdollProtection=true, invincibilityFrames=0.5 }

local function _adSuperHeal(hum)
	if not hum or not hum.Parent then return end
	local max = hum.MaxHealth or 100
	if hum.Health >= max and hum.Health > 0 then return end
	hum.Health = max
	_adInvincibleUntil = tick() + _adConfig.invincibilityFrames
	pcall(function()
		local char = hum.Parent
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("NumberValue") then
				local n = child.Name:lower()
				if n:find("health") or n:find("hp") or n:find("life") then child.Value = 100 end
			elseif child:IsA("BoolValue") and child.Name:lower():find("dead") then
				child.Value = false
			end
		end
	end)
end

local function _adSetup(char)
	if not char then return end
	local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if _adLoop then pcall(function() _adLoop:Disconnect() end); _adLoop = nil end
	_adLoop = RunService.Heartbeat:Connect(function()
		if not hum or not hum.Parent then return end
		if hum.Health <= 0 then
			_adSuperHeal(hum)
			hum:ChangeState(Enum.HumanoidStateType.Running)
			if root and root.Parent then
				root.CFrame = CFrame.new(root.Position + Vector3.new(0,2,0))
				root.AssemblyLinearVelocity = Vector3.zero
			end
			return
		end
		if tick() < _adInvincibleUntil and hum.Health < hum.MaxHealth then
			hum.Health = hum.MaxHealth
		end
		if _adConfig.fallDamageProtection and root and root.Parent then
			local vy = root.AssemblyLinearVelocity.Y
			if vy < -25 then
				root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -3, root.AssemblyLinearVelocity.Z)
				_adSuperHeal(hum)
			end
		end
		if _adConfig.ragdollProtection then
			local st = hum:GetState()
			if st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then
				hum:ChangeState(Enum.HumanoidStateType.Running)
				_adSuperHeal(hum)
				if root and root.Parent then
					root.AssemblyLinearVelocity  = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end
		if hum.Health > 0 and hum.Health <= _adConfig.healthThreshold then _adSuperHeal(hum) end
	end)
end

local function startAntiDie()
	if _adCharConn then pcall(function() _adCharConn:Disconnect() end); _adCharConn = nil end
	_adSetup(LP.Character)
	_adCharConn = LP.CharacterAdded:Connect(function(char) task.wait(0.1); _adSetup(char) end)
end

local function stopAntiDie()
	if _adLoop     then pcall(function() _adLoop:Disconnect() end);     _adLoop     = nil end
	if _adCharConn then pcall(function() _adCharConn:Disconnect() end); _adCharConn = nil end
end

-- ===================================================================
-- ANTI-KICK / SAFE MODE — copie exacte de la logique Ace Duels.
-- Ace n'a AUCUN hook __namecall/Kick(), aucun GC scanner, aucun blocage
-- HTTP, aucun hook Shutdown/BindToClose : leur "anti-kick" est un
-- système passif "Safe Mode" qui met en pause les features risquées
-- (aimbot, auto-left, auto-right) pendant le countdown de duel ou
-- pendant qu'on tient un brainrot, plutôt que de bloquer activement.
-- Tout ce qu'Ace n'a pas (hooks metatable, GC scanner, HTTP block,
-- screen-text watcher) est supprimé, zéro trace.
-- ===================================================================
local _smEnabled = false

local function _smGetCountdownLabel()
	local ok, label = pcall(function()
		return LP.PlayerGui
			and LP.PlayerGui:FindFirstChild("DuelsMachineTopFrame")
			and LP.PlayerGui.DuelsMachineTopFrame:FindFirstChild("DuelsMachineTopFrame")
			and LP.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame:FindFirstChild("Timer")
			and LP.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame.Timer:FindFirstChild("Label")
	end)
	return (ok and label) or nil
end

local function _smCountdownNumber(text)
	local t = tostring(text or ""):upper():gsub("^%s+",""):gsub("%s+$","")
	if t == "GO" or t == "START" or t == "READY" then return true end
	local n = tonumber(t)
	return n ~= nil and n >= 0 and n <= 10
end

local function _smInDuelCountdown()
	local label = _smGetCountdownLabel()
	return label and _smCountdownNumber(label.Text) or false
end

local _smBlockedTools = {
	bat=true, slap=true, sword=true, gun=true, pistol=true, rifle=true,
	medusa=true, hammer=true, axe=true, knife=true, katana=true, blade=true, fist=true,
}
local function _smIsCarryableTool(tool)
	if not tool or not tool:IsA("Tool") then return false end
	local name = tool.Name:lower()
	for word in pairs(_smBlockedTools) do
		if name:find(word, 1, true) then return false end
	end
	return true
end

local function _smHoldingBrainrot()
	local ok, val = pcall(function() return LP:GetAttribute("Stealing") end)
	if ok and val == true then return true end
	local ok2, val2 = pcall(function() return LP:GetAttribute("AntiKick") end)
	if ok2 and val2 == true then return true end
	local char = LP.Character
	if not char then return false end
	local ok3, val3 = pcall(function() return char:GetAttribute("Stealing") end)
	if ok3 and val3 == true then return true end
	if _G.AutoCarrySpeed and type(_G.AutoCarrySpeed.IsCarryingBrainrot) == "function" then
		local okCarry, carrying = pcall(function() return _G.AutoCarrySpeed.IsCarryingBrainrot(char) end)
		if okCarry and carrying then return true end
	end
	for _, name in ipairs({"Carrying","IsCarrying","Grabbed","Holding","StealHold","HasGrab"}) do
		local v = char:FindFirstChild(name, true)
		if v then
			if v:IsA("BoolValue") and v.Value then return true end
			if v:IsA("ObjectValue") and v.Value then return true end
			if v:IsA("StringValue") and v.Value ~= "" then return true end
		end
	end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Model") and child:FindFirstChildWhichIsA("BasePart", true) then
			local n = child.Name:lower()
			if n:find("brainrot") or n:find("animal") or n:find("carry") or n:find("grab") or n:find("steal") or n:find("hold") then
				return true
			end
		end
	end
	return false
end

local function _smIsLocked()
	if not _smEnabled then return false end
	return _smInDuelCountdown() or _smHoldingBrainrot()
end

local function _smForceStop(reason)
	local stopped = false
	if AB.active    then AB.stop();    stopped = true end
	if ABP.active   then ABP.stop();   stopped = true end
	if AimV3.active then AimV3.stop(); stopped = true end
	if State.autoLeftEnabled  then stopAutoLeft();  stopped = true end
	if State.autoRightEnabled then stopAutoRight(); stopped = true end
	if stopped and showActionNotification then pcall(function() showActionNotification(reason or "SAFE MODE LOCK") end) end
end

local function _smTryStart()
	if _smIsLocked() then
		_smForceStop("SAFE MODE LOCK")
		return false
	end
	return true
end

RunService.Heartbeat:Connect(function()
	if _smEnabled and _smIsLocked() then
		_smForceStop("SAFE MODE LOCK")
	end
end)

_GH.SM_enabled    = function() return _smEnabled end
_GH.SM_setEnabled = function(on) _smEnabled = on end
_GH.SM_tryStart   = _smTryStart
_GH.SM_forceStop  = _smForceStop

local _MH_buildUI
_MH_buildUI = function()
local gui = Instance.new("ScreenGui")
gui.Name = _NS; gui.ResetOnSpawn = false; gui.DisplayOrder = 10
gui.IgnoreGuiInset = true; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
table.insert(_themeAllGuis, gui)
pcall(function()
	if syn and syn.protect_gui then syn.protect_gui(gui) end
	if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
	gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end
_G["_MH_GUI"] = gui

-- ===================================================================
-- INTRO CUTSCENE — crescent moon reveal, orbit ring, cinematic zoom (~4.2s)
-- ===================================================================
do
	local introGui = Instance.new("Frame", gui)
	introGui.Name = tostring(math.random(0x10000, 0xFFFFFF))
	introGui.Size = UDim2.new(1,0,1,0)
	introGui.BackgroundColor3 = Color3.fromRGB(2,3,7)
	introGui.BackgroundTransparency = 0
	introGui.ZIndex = 1200
	introGui.BorderSizePixel = 0
	introGui.ClipsDescendants = true
	-- Subtle depth gradient instead of flat black
	addGradient(introGui, Color3.fromRGB(6,10,20), Color3.fromRGB(0,0,0), 90)

	-- Vignette: soft dark edges to frame the scene, done as 4 gradient strips
	do
		local function edgeVignette(size, pos, rot)
			local edge = Instance.new("Frame", introGui)
			edge.Size = size
			edge.Position = pos
			edge.BackgroundColor3 = Color3.new(0,0,0)
			edge.BorderSizePixel = 0
			edge.ZIndex = 30
			local g = Instance.new("UIGradient", edge)
			g.Rotation = rot
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
		edgeVignette(UDim2.new(1,0,0,90), UDim2.new(0,0,0,0), 90)
		edgeVignette(UDim2.new(1,0,0,90), UDim2.new(0,0,1,-90), 270)
		edgeVignette(UDim2.new(0,140,1,0), UDim2.new(0,0,0,0), 0)
		edgeVignette(UDim2.new(0,140,1,0), UDim2.new(1,-140,0,0), 180)
	end

	-- Everything scales together for a cinematic zoom-in on load
	local sceneScale = Instance.new("UIScale", introGui)
	sceneScale.Scale = 1.12

	-- Skip button — top-right, theme-coloured
	local _skipDone = false
	local function doSkip()
		if _skipDone then return end
		_skipDone = true
		TweenService:Create(introGui, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{BackgroundTransparency = 1}):Play()
		task.delay(0.28, function() pcall(function() introGui:Destroy() end) end)
	end
	do
		local skipBtn = Instance.new("TextButton", introGui)
		skipBtn.AnchorPoint  = Vector2.new(1, 0)
		skipBtn.Position     = UDim2.new(1, -14, 0, 14)
		skipBtn.Size         = UDim2.new(0, 72, 0, 26)
		skipBtn.ZIndex       = 1300
		skipBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		skipBtn.BackgroundTransparency = 0.45
		skipBtn.BorderSizePixel = 0
		skipBtn.Text         = "Skip  ›"
		skipBtn.TextColor3   = C_WHITE
		skipBtn.Font         = Enum.Font.GothamBlack
		skipBtn.TextSize     = 13
		skipBtn.AutoButtonColor = false
		Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 6)
		addLivingTextGradient(skipBtn)
		addLivingStroke(skipBtn, 1)
		skipBtn.MouseButton1Click:Connect(doSkip)
	end

	-- Rising particles
	task.spawn(function()
		while introGui.Parent do
			task.wait(math.random(6,16)/100)
			pcall(function()
				local size = math.random(2,5)
				local particle = Instance.new("Frame", introGui)
				particle.Size = UDim2.new(0,size,0,size)
				particle.Position = UDim2.new(math.random(15,85)/100, 0, 1, 10)
				particle.BackgroundColor3 = math.random()<0.3 and Color3.fromRGB(200,225,255) or C_MOON
				particle.BackgroundTransparency = math.random(30,60)/100
				particle.BorderSizePixel = 0
				particle.ZIndex = 50
				Instance.new("UICorner", particle).CornerRadius = UDim.new(1,0)
				local dur = math.random(25,45)/10
				TweenService:Create(particle, TweenInfo.new(dur, Enum.EasingStyle.Linear),
					{Position = UDim2.new(particle.Position.X.Scale, 0, 0, -10), BackgroundTransparency = 1}):Play()
				task.delay(dur+0.1, function() pcall(function() particle:Destroy() end) end)
			end)
		end
	end)

	-- A few large soft drifting orbs for background depth
	for i = 1, 3 do
		local orb = Instance.new("Frame", introGui)
		orb.Size = UDim2.new(0, math.random(90,150), 0, math.random(90,150))
		orb.Position = UDim2.new(math.random(0,100)/100, 0, math.random(0,100)/100, 0)
		orb.BackgroundColor3 = C_MOON
		orb.BackgroundTransparency = 0.96
		orb.BorderSizePixel = 0
		orb.ZIndex = 10
		addCorner(orb, 200)
		task.spawn(function()
			while orb.Parent do
				TweenService:Create(orb, TweenInfo.new(math.random(30,45)/10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{Position = UDim2.new(math.random(0,100)/100, 0, math.random(0,100)/100, 0)}):Play()
				task.wait(math.random(30,45)/10)
			end
		end)
	end

	-- Shooting star — a bright streak with a fading trail crossing the sky
	local function fireShootingStar()
		local startX = math.random(5,30)/100
		local startY = math.random(5,25)/100
		local endX = startX + math.random(35,55)/100
		local endY = startY + math.random(20,35)/100
		local trail = Instance.new("Frame", introGui)
		trail.AnchorPoint = Vector2.new(0.5,0.5)
		trail.Size = UDim2.new(0,60,0,2)
		trail.Position = UDim2.new(startX,0,startY,0)
		trail.Rotation = math.deg(math.atan2(endY-startY, endX-startX))
		trail.BackgroundColor3 = C_WHITE
		trail.BorderSizePixel = 0
		trail.BackgroundTransparency = 1
		trail.ZIndex = 40
		local g = Instance.new("UIGradient", trail)
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0,   1),
			NumberSequenceKeypoint.new(0.85,0.4),
			NumberSequenceKeypoint.new(1,   1),
		})
		TweenService:Create(trail, TweenInfo.new(0.12), {BackgroundTransparency = 0.15}):Play()
		TweenService:Create(trail, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = UDim2.new(endX,0,endY,0),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.6, function() pcall(function() trail:Destroy() end) end)
	end

	-- Shockwave ring — expands outward and fades when the moon bursts in
	local function fireShockwave()
		local ring = Instance.new("Frame", introGui)
		ring.AnchorPoint = Vector2.new(0.5,0.5)
		ring.Position = UDim2.new(0.5,0,0.42,0)
		ring.Size = UDim2.new(0,8,0,8)
		ring.BackgroundTransparency = 1
		ring.ZIndex = 498
		addCorner(ring, 200)
		local stroke = addStroke(ring, C_MOON, 2, 0)
		TweenService:Create(ring, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = UDim2.new(0,280,0,280)}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Transparency = 1}):Play()
		task.delay(0.8, function() pcall(function() ring:Destroy() end) end)
	end

	-- Lueur ambiante lunaire — sphère radiale bleue derrière la lune
	do
		local glowPos = UDim2.new(0.5,0,0.42,0)
		for _, spec in ipairs({{240,0.910},{165,0.930},{95,0.905}}) do
			local g = Instance.new("Frame", introGui)
			g.AnchorPoint = Vector2.new(0.5,0.5)
			g.Position = glowPos
			g.Size = UDim2.new(0,spec[1],0,spec[1])
			g.BackgroundColor3 = Color3.fromRGB(90,170,235)
			g.BackgroundTransparency = spec[2]
			g.BorderSizePixel = 0
			g.ZIndex = 4
			addCorner(g, 200)
		end
	end

	-- Crescent moon icon: bright disc with an offset dark disc cut into it,
	-- plus a slow-rotating orbit ring — replaces the plain dot from before.
	local moonWrap = Instance.new("Frame", introGui)
	moonWrap.AnchorPoint = Vector2.new(0.5,0.5)
	moonWrap.Position = UDim2.new(0.5,0,0.42,0)
	moonWrap.Size = UDim2.new(0,0,0,0)
	moonWrap.BackgroundTransparency = 1
	moonWrap.ZIndex = 501

	local orbitRing = Instance.new("Frame", moonWrap)
	orbitRing.AnchorPoint = Vector2.new(0.5,0.5)
	orbitRing.Position = UDim2.new(0.5,0,0.5,0)
	orbitRing.Size = UDim2.new(2.3,0,0.85,0)   -- ellipse large
	orbitRing.BackgroundTransparency = 1
	orbitRing.Rotation = 0
	orbitRing.ZIndex = 500
	addCorner(orbitRing, 200)
	local orbitStroke, orbitGrad = addLivingStroke(orbitRing, 1)
	orbitStroke.Transparency = 0.62
	local orbitDot = Instance.new("Frame", orbitRing)
	orbitDot.AnchorPoint = Vector2.new(0.5,0.5)
	orbitDot.Position = UDim2.new(0.5,0,0,-2)  -- top of ellipse
	orbitDot.Size = UDim2.new(0,4,0,4)
	orbitDot.BackgroundColor3 = C_MOON2
	orbitDot.BorderSizePixel = 0
	orbitDot.ZIndex = 500
	addCorner(orbitDot, 2)
	local orbitDotGlow = addStroke(orbitDot, C_MOON, 3, 0.4)
	task.spawn(function()
		while orbitRing.Parent do
			orbitRing.Rotation = (orbitRing.Rotation + 3) % 360
			task.wait()
		end
	end)

	-- Soft moonlight halo behind the crescent
	local moonHalo = Instance.new("Frame", moonWrap)
	moonHalo.AnchorPoint = Vector2.new(0.5,0.5)
	moonHalo.Position = UDim2.new(0.5,0,0.5,0)
	moonHalo.Size = UDim2.new(1,0,1,0)
	moonHalo.BackgroundColor3 = C_MOON
	moonHalo.BackgroundTransparency = 0.55
	moonHalo.BorderSizePixel = 0
	moonHalo.ZIndex = 500
	addCorner(moonHalo, 200)
	task.spawn(function()
		while moonHalo.Parent do
			TweenService:Create(moonHalo, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Size = UDim2.new(1.35,0,1.35,0), BackgroundTransparency = 0.75}):Play()
			task.wait(1.4)
			TweenService:Create(moonHalo, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Size = UDim2.new(1,0,1,0), BackgroundTransparency = 0.55}):Play()
			task.wait(1.4)
		end
	end)

	-- Outer second halo — slower, wider pulse
	local moonHalo2 = Instance.new("Frame", moonWrap)
	moonHalo2.AnchorPoint = Vector2.new(0.5,0.5)
	moonHalo2.Position = UDim2.new(0.5,0,0.5,0)
	moonHalo2.Size = UDim2.new(1.6,0,1.6,0)
	moonHalo2.BackgroundColor3 = Color3.fromRGB(90,170,235)
	moonHalo2.BackgroundTransparency = 0.84
	moonHalo2.BorderSizePixel = 0
	moonHalo2.ZIndex = 499
	addCorner(moonHalo2, 200)
	task.spawn(function()
		while moonHalo2.Parent do
			TweenService:Create(moonHalo2, TweenInfo.new(2.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Size = UDim2.new(2.0,0,2.0,0), BackgroundTransparency = 0.93}):Play()
			task.wait(2.1)
			TweenService:Create(moonHalo2, TweenInfo.new(2.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Size = UDim2.new(1.6,0,1.6,0), BackgroundTransparency = 0.84}):Play()
			task.wait(2.1)
		end
	end)

	local moonBase = Instance.new("Frame", moonWrap)
	moonBase.AnchorPoint = Vector2.new(0.5,0.5)
	moonBase.Position = UDim2.new(0.5,0,0.5,0)
	moonBase.Size = UDim2.new(1,0,1,0)
	moonBase.BackgroundColor3 = C_MOON
	moonBase.BorderSizePixel = 0
	moonBase.ZIndex = 501
	addCorner(moonBase, 200)

	-- Small craters for surface texture
	local craterSpots = {{0.32,0.38,0.16},{0.6,0.28,0.11},{0.42,0.6,0.13}}
	for _, c in ipairs(craterSpots) do
		local crater = Instance.new("Frame", moonBase)
		crater.AnchorPoint = Vector2.new(0.5,0.5)
		crater.Position = UDim2.new(c[1],0,c[2],0)
		crater.Size = UDim2.new(c[3],0,c[3],0)
		crater.BackgroundColor3 = C_MOON2
		crater.BackgroundTransparency = 0.35
		crater.BorderSizePixel = 0
		crater.ZIndex = 501
		addCorner(crater, 200)
	end

	local moonBite = Instance.new("Frame", moonWrap)
	moonBite.AnchorPoint = Vector2.new(0.5,0.5)
	moonBite.Position = UDim2.new(0.62,0,0.38,0)
	moonBite.Size = UDim2.new(0.86,0,0.86,0)
	moonBite.BackgroundColor3 = Color3.fromRGB(2,3,7)
	moonBite.BorderSizePixel = 0
	moonBite.ZIndex = 502
	addCorner(moonBite, 200)

	local nameLbl = Instance.new("TextLabel", introGui)
	nameLbl.AnchorPoint = Vector2.new(0.5,0.5)
	nameLbl.Position = UDim2.new(0.5,0,0.54,0)
	nameLbl.Size = UDim2.new(1,-40,0,50)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = "MOON HUB"
	nameLbl.TextColor3 = C_WHITE
	nameLbl.Font = Enum.Font.GothamBlack
	nameLbl.TextSize = 46
	nameLbl.TextTransparency = 1
	nameLbl.ZIndex = 502
	local nameGrad = addLivingTextGradient(nameLbl)

	local subLbl = Instance.new("TextLabel", introGui)
	subLbl.AnchorPoint = Vector2.new(0.5,0.5)
	subLbl.Position = UDim2.new(0.5,0,0.635,0)
	subLbl.Size = UDim2.new(1,-40,0,24)
	subLbl.BackgroundTransparency = 1
	subLbl.Text = "YSLEM  ×  ALN"
	subLbl.TextColor3 = C_DIM
	subLbl.Font = Enum.Font.GothamBold
	subLbl.TextSize = 20
	subLbl.TextTransparency = 1
	subLbl.ZIndex = 502
	addLivingTextGradient(subLbl)

	-- Divider line that draws itself under the subtitle
	local divWrap = Instance.new("Frame", introGui)
	divWrap.AnchorPoint = Vector2.new(0.5,0.5)
	divWrap.Position = UDim2.new(0.5,0,0.685,0)
	divWrap.Size = UDim2.new(0,0,0,1)
	divWrap.BackgroundColor3 = C_MOON
	divWrap.BackgroundTransparency = 0.3
	divWrap.BorderSizePixel = 0
	divWrap.ZIndex = 502

	local verLbl = Instance.new("TextLabel", introGui)
	verLbl.AnchorPoint = Vector2.new(0.5,0.5)
	verLbl.Position = UDim2.new(0.5,0,0.72,0)
	verLbl.Size = UDim2.new(1,-40,0,14)
	verLbl.BackgroundTransparency = 1
	verLbl.Text = "V3"
	verLbl.TextColor3 = C_SILVER2
	verLbl.Font = Enum.Font.Gotham
	verLbl.TextSize = 10
	verLbl.TextTransparency = 1
	verLbl.ZIndex = 502

	-- Champ d'étoiles — 100 étoiles scintillantes (argenté/blanc/bleu)
	local starColors = {C_WHITE, Color3.fromRGB(200,225,255), Color3.fromRGB(180,210,255), Color3.fromRGB(220,235,255)}
	for i = 1, 100 do
		local tw = Instance.new("Frame", introGui)
		local sz = math.random()<0.12 and 2 or 1
		tw.Size = UDim2.new(0,sz,0,sz)
		tw.Position = UDim2.new(math.random(0,100)/100, 0, math.random(0,100)/100, 0)
		tw.BackgroundColor3 = starColors[math.random(1,#starColors)]
		tw.BackgroundTransparency = 1
		tw.BorderSizePixel = 0
		tw.ZIndex = 20
		addCorner(tw, 2)
		task.spawn(function()
			task.wait(math.random(0,30)/10)
			while tw.Parent do
				local peak = math.random(15,60)/100
				local dur = math.random(8,22)/10
				TweenService:Create(tw, TweenInfo.new(dur/2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{BackgroundTransparency = peak}):Play()
				task.wait(dur/2)
				if not tw.Parent then break end
				TweenService:Create(tw, TweenInfo.new(dur/2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{BackgroundTransparency = 1}):Play()
				task.wait(dur/2)
			end
		end)
	end

	-- Star burst finale: a center star plus small sparkles flung outward
	local star = Instance.new("TextLabel", introGui)
	star.AnchorPoint = Vector2.new(0.5,0.5)
	star.Position = UDim2.new(0.5,0,0.8,0)
	star.Size = UDim2.new(0,0,0,0)
	star.BackgroundTransparency = 1
	star.Text = "★"
	star.TextColor3 = C_MOON2
	star.Font = Enum.Font.GothamBold
	star.TextSize = 22
	star.TextTransparency = 1
	star.ZIndex = 502
	addLivingTextGradient(star)

	local function fireStarBurst()
		for i = 1, 10 do
			local ang = (i / 10) * math.pi * 2
			local dist = math.random(55, 100)
			local spark = Instance.new("TextLabel", introGui)
			spark.AnchorPoint = Vector2.new(0.5,0.5)
			spark.Position = UDim2.new(0.5,0,0.8,0)
			spark.Size = UDim2.new(0,14,0,14)
			spark.BackgroundTransparency = 1
			spark.Text = "★"
			spark.TextColor3 = C_MOON2
			spark.Font = Enum.Font.GothamBold
			spark.TextSize = math.random(7,11)
			spark.TextTransparency = 0
			spark.ZIndex = 501
			local dx, dy = math.cos(ang) * dist, math.sin(ang) * dist
			TweenService:Create(spark, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, dx, 0.8, dy),
				TextTransparency = 1,
			}):Play()
			task.delay(0.65, function() pcall(function() spark:Destroy() end) end)
		end
	end

	-- Bright flash accent — a quick full-screen white pulse for punch
	local function fireFlash(peakTransparency)
		local flash = Instance.new("Frame", introGui)
		flash.Size = UDim2.new(1,0,1,0)
		flash.BackgroundColor3 = C_WHITE
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.ZIndex = 999
		TweenService:Create(flash, TweenInfo.new(0.08), {BackgroundTransparency = peakTransparency or 0.82}):Play()
		task.delay(0.08, function()
			pcall(function()
				TweenService:Create(flash, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
				task.delay(0.3, function() pcall(function() flash:Destroy() end) end)
			end)
		end)
	end

	-- ── SFX helper (silent on error) ─────────────────────────────
	local _SS = game:GetService("SoundService")
	local function _sfx(id, vol, pitch)
		pcall(function()
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://" .. id
			s.Volume = vol or 0.5
			s.PlaybackSpeed = pitch or 1
			s.RollOffMaxDistance = 0
			s.Parent = _SS
			s:Play()
			game:GetService("Debris"):AddItem(s, 10)
		end)
	end
	-- IDs  1846359858 = pad éthéré / ambient
	--       5791714739 = swoosh sharp étoile
	--       4115432498 = drop cinématique lune
	--       9120386436 = bell titre
	--       2865227271 = arpège sparkle étoile
	--       1369158167 = fade sweep cinématique

	-- ── SEQUENCE ──────────────────────────────────────────────────
	task.spawn(function()
		TweenService:Create(sceneScale, TweenInfo.new(3.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{Scale = 1}):Play()
		_sfx(3340803765, 0.20, 0.5)            -- nappe ambiante ouverture
		task.delay(0.1, function()
			fireShootingStar()
			_sfx(260430148, 0.32, 1.0)         -- swoosh profond étoile filante
		end)

		task.wait(0.4)
		-- Moonrise: starts low and rises into place instead of just popping
		-- in at its resting spot — reads as an actual moonrise, not a spawn.
		moonWrap.Size = UDim2.new(0,0,0,0)
		moonWrap.Position = UDim2.new(0.5,0,0.62,0)
		TweenService:Create(moonWrap, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Size = UDim2.new(0,70,0,70), Position = UDim2.new(0.5,0,0.42,0)}):Play()
		fireShockwave()
		task.delay(0.18, fireShockwave)
		fireFlash(0.9)
		_sfx(2545463903, 0.78, 1.0)            -- impact cinématique — apparition de la lune
		task.wait(0.5)

		-- Glitch reveal: a few scrambled/jittery frames before the title
		-- locks in clean, reads as "the system just booted" rather than a
		-- plain fade — self-contained, restores the label exactly before
		-- the existing Back-Out reveal tween below takes over.
		do
			local GLITCH_CHARS = "#$%&XZQ019/\\"
			local realText = nameLbl.Text
			for i = 1, 6 do
				local scrambled = {}
				for c in realText:gmatch(".") do
					if c ~= " " and math.random() < 0.5 then
						local gi = math.random(1, #GLITCH_CHARS)
						scrambled[#scrambled+1] = GLITCH_CHARS:sub(gi, gi)
					else
						scrambled[#scrambled+1] = c
					end
				end
				nameLbl.Text = table.concat(scrambled)
				nameLbl.TextTransparency = (i % 2 == 0) and 0 or 0.5
				nameLbl.Position = UDim2.new(0.5, math.random(-3,3), 0.54, 0)
				task.wait(0.03)
			end
			nameLbl.Text = realText
			nameLbl.Position = UDim2.new(0.5, 0, 0.54, 0)
			nameLbl.TextTransparency = 1
		end
		nameLbl.TextSize = 62
		TweenService:Create(nameLbl, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{TextTransparency = 0, TextSize = 46}):Play()
		_sfx(131322600, 0.40, 1.0)             -- cloche cristal — titre
		task.wait(0.35)
		TweenService:Create(subLbl, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
		task.wait(0.2)
		TweenService:Create(divWrap, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = UDim2.new(0,120,0,1)}):Play()
		task.wait(0.2)
		TweenService:Create(verLbl, TweenInfo.new(0.4), {TextTransparency = 0}):Play()

		task.wait(1.5)

		-- End star: appears, glows, bursts into sparkles, then fades
		star.Size = UDim2.new(0,24,0,24)
		TweenService:Create(star, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{TextTransparency = 0}):Play()
		task.wait(0.3)
		fireStarBurst()
		fireFlash(0.94)
		_sfx(876066539, 0.65, 1.0)             -- scintillement magique — étoile burst
		task.wait(0.2)

		-- Text fade out
		TweenService:Create(verLbl, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		task.wait(0.1)
		TweenService:Create(divWrap, TweenInfo.new(0.2), {Size = UDim2.new(0,0,0,1)}):Play()
		TweenService:Create(subLbl, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		task.wait(0.1)
		TweenService:Create(nameLbl, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
		TweenService:Create(moonWrap, TweenInfo.new(0.3), {Size = UDim2.new(0,0,0,0)}):Play()
		task.wait(0.3)

		-- The star fades out (last visible element)
		TweenService:Create(star, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{TextTransparency = 1}):Play()
		_sfx(131070686, 0.25, 1.0)             -- transition sci-fi — fade out cinématique
		task.wait(0.55)

		-- Continuity: the moon that just introduced the hub flies to the
		-- corner where its little floating icon lives before the curtain
		-- drops — same visual language as the close/open "absorb" animation
		-- later, so the intro hands off into the live menu as one gesture
		-- instead of a hard cut. Guarded: miniBtn is created moments after
		-- this whole intro block runs, so by the time this fires (a few
		-- seconds in) it always exists — the pcall is just a safety net.
		pcall(function()
			local mb = _GH.miniBtn
			if mb then
				local targetAbs = mb.AbsolutePosition + mb.AbsoluteSize/2
				TweenService:Create(moonWrap, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
					Position = UDim2.new(0, targetAbs.X, 0, targetAbs.Y),
					Size = UDim2.new(0,8,0,8),
				}):Play()
			end
		end)
		TweenService:Create(introGui, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
		task.wait(0.42)
		introGui:Destroy()
	end)
end



-- ===================================================================
-- DRAG SYSTEM — no dragPosLabel (green Y: label removed)
-- ===================================================================
local _uiLocked = false          -- LOCK : quand true, aucun drag ne fonctionne
local _dragStates = {}           -- registry of all created drag states
local _activeDrag = nil
local _MH_positions = {}         -- registry of draggable frames keyed by posId
_GH.positions = _MH_positions

-- Keeps a dragged position's absolute top-left corner inside the viewport —
-- without this, dragging any window (the moon icon included) far enough
-- toward an edge could push it fully off-screen with no way to grab it
-- back. Only ever adjusts the Offset component, at whatever Scale the
-- frame already had — same convention the drag delta above already uses.
local function _clampToScreen(frame, pos)
	local cam = workspace.CurrentCamera
	if not cam then return pos end
	local vp = cam.ViewportSize
	if vp.X <= 0 or vp.Y <= 0 then return pos end
	local absSize = frame.AbsoluteSize
	local anchor  = frame.AnchorPoint
	local topLeftX = pos.X.Scale * vp.X + pos.X.Offset - anchor.X * absSize.X
	local topLeftY = pos.Y.Scale * vp.Y + pos.Y.Offset - anchor.Y * absSize.Y
	local clampedX = math.clamp(topLeftX, 0, math.max(0, vp.X - absSize.X))
	local clampedY = math.clamp(topLeftY, 0, math.max(0, vp.Y - absSize.Y))
	local offX = clampedX - pos.X.Scale * vp.X + anchor.X * absSize.X
	local offY = clampedY - pos.Y.Scale * vp.Y + anchor.Y * absSize.Y
	return UDim2.new(pos.X.Scale, offX, pos.Y.Scale, offY)
end

UIS.InputChanged:Connect(function(inp)
	if not _activeDrag then return end
	if inp ~= _activeDrag.dragInput then return end
	if not _activeDrag.dragging then return end
	local dx = inp.Position.X - _activeDrag.dragStart.X
	local dy = inp.Position.Y - _activeDrag.dragStart.Y
	local sp = _activeDrag.startPos
	local newPos = UDim2.new(sp.X.Scale, sp.X.Offset+dx, sp.Y.Scale, sp.Y.Offset+dy)
	_activeDrag.frame.Position = _clampToScreen(_activeDrag.frame, newPos)
end)

local function makeDraggable(frame, handle, posId)
	local src = handle or frame
	local state = { frame=frame, dragging=false, dragInput=nil, dragStart=nil, startPos=nil }
	_dragStates[#_dragStates+1] = state
	if posId then _MH_positions[posId] = frame end
	src.InputBegan:Connect(function(inp)
		if _uiLocked then return end   -- LOCK: blocks drag from starting
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			state.dragging = true
			state.dragStart = inp.Position
			state.startPos = frame.Position
			_activeDrag = state
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then
					state.dragging = false
					if _activeDrag == state then _activeDrag = nil end
					if posId and _GH.autoSave then _GH.autoSave() end
				end
			end)
		end
	end)
	src.InputChanged:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch then
			state.dragInput = inp
		end
	end)
end

-- Toggle drag lock (called by the 🔓/🔒 button in the title bar)
-- Locks EVERYTHING: main menu, widgets, and floating buttons.
local function setDragLock(on)
	_uiLocked = on
	if on then
		-- Cancel any drag in progress
		for _, st in ipairs(_dragStates) do st.dragging = false end
		_activeDrag = nil
	end
	if _GH.setFloatLocked then _GH.setFloatLocked(on) end
end

-- ===================================================================
-- TOAST NOTIFICATIONS — small fading badge, top-center, stacks vertically
-- ===================================================================
local toastLayer = Instance.new("Frame", gui)
toastLayer.Name = "ToastLayer"
toastLayer.AnchorPoint = Vector2.new(0.5,0)
toastLayer.Position = UDim2.new(0.5,0,0,10)
toastLayer.Size = UDim2.new(0,240,0,0)
toastLayer.AutomaticSize = Enum.AutomaticSize.Y
toastLayer.BackgroundTransparency = 1
toastLayer.ZIndex = 200
local toastLL = Instance.new("UIListLayout", toastLayer)
toastLL.SortOrder = Enum.SortOrder.LayoutOrder
toastLL.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLL.Padding = UDim.new(0,6)

local _toastOrder = 0
local function showToast(text, kind)
	_toastOrder = _toastOrder + 1
	local order = _toastOrder
	local accent = (kind=="off" and C_RED) or (kind=="info" and C_MOON) or C_GREEN
	local icon   = (kind=="off" and "\226\156\151") or (kind=="info" and "\226\128\162") or "\226\156\147"

	local card = Instance.new("Frame", toastLayer)
	card.Size = UDim2.new(0,0,0,24); card.AutomaticSize = Enum.AutomaticSize.X
	card.BackgroundColor3 = Color3.fromRGB(6,8,14); card.BackgroundTransparency = 1
	card.BorderSizePixel = 0; card.LayoutOrder = order; card.ZIndex = 200
	addCorner(card, 8)
	local stroke = addStroke(card, accent, 1, 1)
	local pad = Instance.new("UIPadding", card)
	pad.PaddingLeft = UDim.new(0,10); pad.PaddingRight = UDim.new(0,10)

	local row = Instance.new("Frame", card)
	row.Size = UDim2.new(0,0,1,0); row.AutomaticSize = Enum.AutomaticSize.X
	row.BackgroundTransparency = 1; row.ZIndex = 201
	local rowLL = Instance.new("UIListLayout", row)
	rowLL.FillDirection = Enum.FillDirection.Horizontal
	rowLL.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLL.Padding = UDim.new(0,6)

	local iconLbl = Instance.new("TextLabel", row)
	iconLbl.Size = UDim2.new(0,12,1,0); iconLbl.BackgroundTransparency = 1
	iconLbl.Text = icon; iconLbl.TextColor3 = accent; iconLbl.TextTransparency = 1
	iconLbl.Font = Enum.Font.GothamBlack; iconLbl.TextSize = 11; iconLbl.ZIndex = 201

	local txtLbl = Instance.new("TextLabel", row)
	txtLbl.Size = UDim2.new(0,0,1,0); txtLbl.AutomaticSize = Enum.AutomaticSize.X
	txtLbl.BackgroundTransparency = 1; txtLbl.Text = text
	txtLbl.TextColor3 = C_WHITE; txtLbl.TextTransparency = 1
	txtLbl.Font = Enum.Font.GothamBold; txtLbl.TextSize = 10; txtLbl.ZIndex = 201

	TweenService:Create(card, TweenInfo.new(0.18), {BackgroundTransparency=0.15}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.18), {Transparency=0.2}):Play()
	TweenService:Create(iconLbl, TweenInfo.new(0.18), {TextTransparency=0}):Play()
	TweenService:Create(txtLbl, TweenInfo.new(0.18), {TextTransparency=0}):Play()

	task.delay(1.4, function()
		if not card or not card.Parent then return end
		TweenService:Create(card, TweenInfo.new(0.25), {BackgroundTransparency=1}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.25), {Transparency=1}):Play()
		TweenService:Create(iconLbl, TweenInfo.new(0.25), {TextTransparency=1}):Play()
		TweenService:Create(txtLbl, TweenInfo.new(0.25), {TextTransparency=1}):Play()
		task.wait(0.26)
		if card then card:Destroy() end
	end)
end
_GH.showToast = showToast

-- ===================================================================
-- MAIN OUTER PANEL
-- ===================================================================
local WIN_W, WIN_H = 300, 340
local TITLE_H = 34

local mainOuter = Instance.new("Frame", gui)
mainOuter.Name = "MainOuter"
mainOuter.Size = UDim2.new(0,WIN_W,0,WIN_H)
mainOuter.Position = UDim2.new(0.5,-WIN_W/2,0.5,-137)
mainOuter.BackgroundTransparency = 1; mainOuter.BorderSizePixel = 0
mainOuter.ClipsDescendants = true; mainOuter.Active = true
local mainCorner = addCorner(mainOuter, 24); makeDraggable(mainOuter, nil, "main")
local mainUIScale = Instance.new("UIScale", mainOuter)

local bgImg = Instance.new("Frame", mainOuter)
bgImg.Name = "BgFill"; bgImg.Size = UDim2.new(1,0,1,0)
bgImg.BackgroundColor3 = C_BG; bgImg.BorderSizePixel = 0; bgImg.ZIndex = 0
local bgCorner = addCorner(bgImg, 24)

local mainStroke = addLivingStroke(mainOuter, 2)

-- ===================================================================
-- TITLE BAR
-- ===================================================================
local titleBar = Instance.new("Frame", mainOuter)
titleBar.Size = UDim2.new(1,0,0,TITLE_H); titleBar.BackgroundTransparency = 1
titleBar.BorderSizePixel = 0; titleBar.ZIndex = 5

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(0,200,0,20); titleLbl.Position = UDim2.new(0,14,0,7)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "MOON V3 - YSLEM X ALN"
titleLbl.TextColor3 = C_WHITE; titleLbl.Font = Enum.Font.GothamBlack; titleLbl.TextSize = 11
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.ZIndex = 6
addLivingTextGradient(titleLbl)

-- LOCK button in the title bar (freezes/unfreezes drag)
local lockTitleBtn = Instance.new("TextButton", titleBar)
lockTitleBtn.Size = UDim2.new(0,22,0,22); lockTitleBtn.Position = UDim2.new(1,-56,0.5,-11)
lockTitleBtn.BackgroundColor3 = Color3.fromRGB(0,0,0); lockTitleBtn.BorderSizePixel = 0
lockTitleBtn.Text = "🔓"; lockTitleBtn.TextColor3 = C_WHITE
lockTitleBtn.Font = Enum.Font.GothamBlack; lockTitleBtn.TextSize = 13
lockTitleBtn.ZIndex = 7; addCorner(lockTitleBtn, 8); addLivingStroke(lockTitleBtn, 1)
lockTitleBtn.MouseEnter:Connect(function() TweenService:Create(lockTitleBtn,TweenInfo.new(0.1),{TextColor3=C_MOON2}):Play() end)
lockTitleBtn.MouseLeave:Connect(function() TweenService:Create(lockTitleBtn,TweenInfo.new(0.1),{TextColor3=C_WHITE}):Play() end)
lockTitleBtn.MouseButton1Click:Connect(function()
	_uiLocked = not _uiLocked
	setDragLock(_uiLocked)
	lockTitleBtn.Text = _uiLocked and "🔒" or "🔓"
	lockTitleBtn.TextColor3 = _uiLocked and C_RED or C_WHITE
end)

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0,22,0,22); closeBtn.Position = UDim2.new(1,-30,0.5,-11)
closeBtn.BackgroundColor3 = Color3.fromRGB(0,0,0); closeBtn.BorderSizePixel = 0
closeBtn.Text = "-"; closeBtn.TextColor3 = C_WHITE; closeBtn.Font = Enum.Font.GothamBlack; closeBtn.TextSize = 16
closeBtn.ZIndex = 7; addCorner(closeBtn, 8); addLivingStroke(closeBtn, 1)
closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn,TweenInfo.new(0.1),{TextColor3=C_MOON2}):Play() end)
closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn,TweenInfo.new(0.1),{TextColor3=C_WHITE}):Play() end)

-- Small "active features" badge — sits between the title and lock/close, stays tiny
local activeBadge = Instance.new("Frame", titleBar)
activeBadge.Size = UDim2.new(0,30,0,16); activeBadge.Position = UDim2.new(1,-90,0.5,-8)
activeBadge.BackgroundColor3 = Color3.fromRGB(0,0,0); activeBadge.BackgroundTransparency = 0.25
activeBadge.BorderSizePixel = 0; activeBadge.ZIndex = 7
addCorner(activeBadge, 8); addStroke(activeBadge, C_BORDER, 1, 0.35)
local activeDot = Instance.new("Frame", activeBadge)
activeDot.Size = UDim2.new(0,6,0,6); activeDot.Position = UDim2.new(0,7,0.5,-3)
activeDot.BackgroundColor3 = C_DIM; activeDot.BorderSizePixel = 0; addCorner(activeDot, 3)
local activeLbl = Instance.new("TextLabel", activeBadge)
activeLbl.Size = UDim2.new(1,-16,1,0); activeLbl.Position = UDim2.new(0,15,0,0)
activeLbl.BackgroundTransparency = 1; activeLbl.Text = "0"
activeLbl.TextColor3 = C_DIM; activeLbl.Font = Enum.Font.GothamBold; activeLbl.TextSize = 9
activeLbl.TextXAlignment = Enum.TextXAlignment.Left; activeLbl.ZIndex = 7
-- updateActiveBadge() is defined below (after _MH_allToggles exists) so it can
-- scan real toggle state — this keeps it correct even when config-load restores
-- toggles directly via entry.set() instead of going through the click handler.

local titleDiv = Instance.new("Frame", mainOuter)
titleDiv.Size = UDim2.new(1,0,0,1); titleDiv.Position = UDim2.new(0,0,0,TITLE_H)
titleDiv.BackgroundColor3 = C_BORDER; titleDiv.BorderSizePixel = 0; titleDiv.ZIndex = 5

-- ===================================================================
-- CONTENT AREA
-- ===================================================================
local CONTENT_Y = TITLE_H + 1
local contentBg = Instance.new("Frame", mainOuter)
contentBg.Size = UDim2.new(1,0,1,-CONTENT_Y); contentBg.Position = UDim2.new(0,0,0,CONTENT_Y)
contentBg.BackgroundTransparency = 1; contentBg.BorderSizePixel = 0
contentBg.ClipsDescendants = true; contentBg.ZIndex = 2

local TABS = {"Combat","Visual","Keybind","Optimize","Settings","Buttons"}
local tabBar = Instance.new("Frame", contentBg)
tabBar.Size = UDim2.new(1,-16,0,26); tabBar.Position = UDim2.new(0,8,0,6)
tabBar.BackgroundTransparency = 1; tabBar.ZIndex = 4
local tabBarLL = Instance.new("UIListLayout", tabBar)
tabBarLL.FillDirection = Enum.FillDirection.Horizontal
tabBarLL.SortOrder = Enum.SortOrder.LayoutOrder
tabBarLL.Padding = UDim.new(0,4)
tabBarLL.HorizontalAlignment = Enum.HorizontalAlignment.Left

local mainScroll = Instance.new("ScrollingFrame", contentBg)
mainScroll.Name = "MainScroll"; mainScroll.Size = UDim2.new(1,0,1,-36); mainScroll.Position = UDim2.new(0,0,0,36)
mainScroll.BackgroundTransparency = 1; mainScroll.BorderSizePixel = 0
mainScroll.ScrollBarThickness = 3; mainScroll.ScrollBarImageColor3 = C_MOON
mainScroll.ScrollBarImageTransparency = 0.4; mainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mainScroll.CanvasSize = UDim2.new(0,0,0,0); mainScroll.ZIndex = 3
-- Captured once, right after Position is set above and never touched again
-- elsewhere — selectTab's per-tab nudge animation snaps from this fixed
-- constant each time (never a live read of mainScroll.Position) so rapid
-- tab-switching can't drift it off its true resting spot mid-tween.
local MAINSCROLL_REST_POS = mainScroll.Position

local mainLL = Instance.new("UIListLayout", mainScroll)
mainLL.SortOrder = Enum.SortOrder.LayoutOrder; mainLL.Padding = UDim.new(0,6)
local mainPad = Instance.new("UIPadding", mainScroll)
mainPad.PaddingLeft = UDim.new(0,12); mainPad.PaddingRight = UDim.new(0,12)
mainPad.PaddingTop = UDim.new(0,6); mainPad.PaddingBottom = UDim.new(0,14)

-- ===================================================================
-- ROW BUILDERS
-- ===================================================================
local UIB = {}
local currentPage, lo = nil, 0
local function LO() lo = lo + 1; return lo end

function UIB.makeGap(px)
	local f = Instance.new("Frame", currentPage)
	f.Size = UDim2.new(1,0,0,px or 6); f.BackgroundTransparency = 1; f.LayoutOrder = LO()
end

function UIB.makeSectionLabel(text)
	local wrap = Instance.new("Frame", currentPage)
	wrap.Size = UDim2.new(1,0,0,22); wrap.BackgroundTransparency = 1; wrap.LayoutOrder = LO()
	local dot = Instance.new("Frame", wrap)
	dot.Size = UDim2.new(0,4,0,4); dot.Position = UDim2.new(0,2,0.5,-2)
	dot.BackgroundColor3 = C_MOON; dot.BorderSizePixel = 0; addCorner(dot, 2)
	local lbl = Instance.new("TextLabel", wrap)
	lbl.Size = UDim2.new(1,-14,1,0); lbl.Position = UDim2.new(0,12,0,0)
	lbl.BackgroundTransparency = 1; lbl.Text = text:upper()
	lbl.TextColor3 = C_WHITE; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	addLivingTextGradient(lbl)
end

local function makeDivider()
	local div = Instance.new("Frame", currentPage)
	div.Size = UDim2.new(1,-8,0,1); div.Position = UDim2.new(0,4,0,0)
	div.BorderSizePixel = 0; div.LayoutOrder = LO()
	div.BackgroundColor3 = C_DEEP3
	addLivingTextGradient(div)
end

local _MH_allToggles = {}
local _MH_allInputs  = {}
_GH.allToggles = _MH_allToggles
_GH.allInputs  = _MH_allInputs

-- Scans real toggle state (not an incremental counter) so it stays correct
-- whether a toggle flips via the click handler or via config-load's entry.set().
local function updateActiveBadge()
	local n = 0
	for _, entry in pairs(_MH_allToggles) do
		if entry.get() then n = n + 1 end
	end
	activeLbl.Text = tostring(n)
	local on = n > 0
	TweenService:Create(activeDot, TweenInfo.new(0.15), {BackgroundColor3 = on and C_GREEN or C_DIM}):Play()
	TweenService:Create(activeLbl, TweenInfo.new(0.15), {TextColor3 = on and C_SILVER or C_DIM}):Play()
end
_GH.updateActiveBadge = updateActiveBadge

function UIB.makeInputRow(label, default, onChange)
	local row = Instance.new("Frame", currentPage)
	row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = C_ROW; row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0; row.LayoutOrder = LO(); addCorner(row, 12)
	addLivingStroke(row, 1)
	row.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.15}):Play() end)
	row.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.35}):Play() end)
	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(1,-96,1,0); lbl.Position = UDim2.new(0,14,0,0)
	lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = C_WHITE
	lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left
	addLivingTextGradient(lbl)
	local boxWrap = Instance.new("Frame", row)
	boxWrap.Size = UDim2.new(0,64,0,24); boxWrap.Position = UDim2.new(1,-76,0.5,-12)
	boxWrap.BackgroundColor3 = C_OFF_BG; boxWrap.BackgroundTransparency = 0.1; boxWrap.BorderSizePixel = 0
	addCorner(boxWrap, 8); addLivingStroke(boxWrap, 1)
	local box = Instance.new("TextBox", boxWrap)
	box.Size = UDim2.new(1,-6,1,0); box.Position = UDim2.new(0,3,0,0)
	box.BackgroundTransparency = 1; box.Text = tostring(default)
	box.TextColor3 = C_SILVER; box.Font = Enum.Font.GothamBold; box.TextSize = 12
	box.ClearTextOnFocus = false; box.TextXAlignment = Enum.TextXAlignment.Center
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			onChange(n)
			if _GH.autoSave then _GH.autoSave() end
		else
			box.Text = tostring(default)
		end
	end)
	makeDivider()
	local key = (currentPage and currentPage.Name or "?") .. "::" .. label
	_MH_allInputs[key] = { box = box, default = default, onChange = onChange }
	return box
end

function UIB.makeToggleRow(label, defaultOn, onToggle)
	local row = Instance.new("Frame", currentPage)
	row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = C_ROW; row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0; row.LayoutOrder = LO(); addCorner(row, 12)
	addLivingStroke(row, 1)
	row.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.15}):Play() end)
	row.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.35}):Play() end)
	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(1,-70,1,0); lbl.Position = UDim2.new(0,14,0,0)
	lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = C_WHITE
	lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left
	addLivingTextGradient(lbl)
	local pill = Instance.new("Frame", row)
	pill.Size = UDim2.new(0,40,0,20); pill.Position = UDim2.new(1,-54,0.5,-10)
	pill.BackgroundColor3 = defaultOn and C_ON_BG or C_OFF_BG; pill.BackgroundTransparency = 0.1
	pill.BorderSizePixel = 0; addCorner(pill, 10); addLivingStroke(pill, 1)
	local ball = Instance.new("Frame", pill)
	ball.Size = UDim2.new(0,14,0,14)
	ball.Position = defaultOn and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
	ball.BackgroundColor3 = defaultOn and C_WHITE or C_SILVER2; ball.BorderSizePixel = 0
	addCorner(ball, 7)

	-- Breathing glow: a dedicated stroke (separate from the always-rotating
	-- "living" one above) that only pulses while this toggle is ON.
	local glowStroke = Instance.new("UIStroke", pill)
	glowStroke.Thickness = 2.5; glowStroke.Color = C_MOON
	glowStroke.Transparency = 1; glowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local _glowRunning = false
	local function startGlow()
		if _glowRunning then return end
		_glowRunning = true
		task.spawn(function()
			while _glowRunning and pill and pill.Parent do
				TweenService:Create(glowStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency=0.35}):Play()
				task.wait(0.9)
				if not _glowRunning then break end
				TweenService:Create(glowStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency=0.85}):Play()
				task.wait(0.9)
			end
		end)
	end
	local function stopGlow()
		_glowRunning = false
		TweenService:Create(glowStroke, TweenInfo.new(0.2), {Transparency=1}):Play()
	end
	if defaultOn then startGlow() end

	local isOn = defaultOn
	local function setV(on)
		isOn = on
		TweenService:Create(pill,TweenInfo.new(0.15),{BackgroundColor3=on and C_ON_BG or C_OFF_BG}):Play()
		TweenService:Create(ball,TweenInfo.new(0.15,Enum.EasingStyle.Back),{
			Position=on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7),
			BackgroundColor3=on and C_WHITE or C_SILVER2,
		}):Play()
		if on then startGlow() else stopGlow() end
	end
	local clk = Instance.new("TextButton", row)
	clk.Size = UDim2.new(1,0,1,0); clk.BackgroundTransparency = 1; clk.Text = ""
	clk.MouseButton1Click:Connect(function()
		isOn = not isOn; setV(isOn)
		updateActiveBadge()
		if onToggle then onToggle(isOn) end
		if _GH.autoSave then _GH.autoSave() end
		if _GH.showToast then _GH.showToast(label, isOn and "on" or "off") end
	end)
	makeDivider()
	local key = (currentPage and currentPage.Name or "?") .. "::" .. label
	_MH_allToggles[key] = {
		get = function() return isOn end,
		set = setV,
		onToggle = onToggle,
	}
	return setV
end

-- ===================================================================
-- TAB PAGES
-- ===================================================================
local tabPages   = {}
local tabButtons = {}

-- Plain Frame, instant Visible switch — this is the version that is known
-- to always show every widget correctly. Two fancier approaches were tried
-- and both risked leaving real content invisible/blank:
--   1. CanvasGroup + GroupTransparency: CanvasGroup renders as a blank
--      black/invisible square on a good chunk of executors.
--   2. Per-descendant transparency caching + tween: relies on every single
--      widget's tween firing correctly; any one silently failing left that
--      widget stuck invisible with no visible symptom until it's too late.
-- Neither is worth the risk for a cosmetic transition, so tab pages just
-- swap Visible directly like before.
local function buildPage(name, buildFn)
	local page = Instance.new("Frame", mainScroll)
	page.Name = name; page.Size = UDim2.new(1,0,0,0); page.AutomaticSize = Enum.AutomaticSize.Y
	page.BackgroundTransparency = 1; page.BorderSizePixel = 0; page.Visible = false
	local ll = Instance.new("UIListLayout", page)
	ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0,6)
	tabPages[name] = page; currentPage = page; lo = 0
	buildFn()
	currentPage = nil
	return page
end

-- Tab-switch flash: ONE overlay Frame, covering the content area, that
-- snaps opaque then fades away. Gives the switch a bit of life without
-- touching a single property on any actual widget — so it can never leave
-- real content stuck invisible, whatever else is going on in the page.
local tabFlash = Instance.new("Frame", contentBg)
tabFlash.Name = "TabFlash"
tabFlash.Position = UDim2.new(0,0,0,36); tabFlash.Size = UDim2.new(1,0,1,-36)
tabFlash.BackgroundColor3 = C_BG; tabFlash.BackgroundTransparency = 1
tabFlash.BorderSizePixel = 0; tabFlash.ZIndex = 45
tabFlash.Active = false

local _activeTabName = nil
local function selectTab(name)
	local newPage = tabPages[name]
	if not newPage or name == _activeTabName then return end
	_activeTabName = name

	for n, page in pairs(tabPages) do page.Visible = (n==name) end

	for n, btn in pairs(tabButtons) do
		local active = (n==name)
		TweenService:Create(btn.frame,TweenInfo.new(0.15),{
			BackgroundColor3=active and C_MOON or Color3.fromRGB(18,22,30),
			BackgroundTransparency=active and 0 or 0.5,
		}):Play()
		btn.lbl.TextColor3 = active and C_MOONTEXT or C_TABIDLE
	end

	tabFlash.BackgroundTransparency = 0.82
	TweenService:Create(tabFlash, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency=1}):Play()

	-- Small per-tab "open" nudge: slides the whole content area in from a
	-- slight offset alongside the flash above, so switching tabs reads as
	-- a touch more alive. Animates mainScroll itself — ONE frame that isn't
	-- managed by any UIListLayout from ITS OWN parent (unlike the pages and
	-- rows inside it, which ARE stacked by nested UIListLayouts and would
	-- fight a direct Position tween the instant the layout recalculates) —
	-- same reasoning that kept tabFlash a single overlay instead of
	-- touching per-widget properties. Always snaps from the fixed rest
	-- constant, never a live read, so rapid tab-switching can't drift it.
	mainScroll.Position = MAINSCROLL_REST_POS + UDim2.new(0,0,0,10)
	TweenService:Create(mainScroll, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=MAINSCROLL_REST_POS}):Play()
end

for i, name in ipairs(TABS) do
	local btn = Instance.new("TextButton", tabBar)
	btn.Size = UDim2.new(0,44,1,0); btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
	btn.BackgroundTransparency = 0.5; btn.BorderSizePixel = 0; btn.Text = ""
	btn.AutoButtonColor = false; btn.LayoutOrder = i; btn.ZIndex = 5
	addCorner(btn, 10); addLivingStroke(btn, 1)
	local lbl = Instance.new("TextLabel", btn)
	lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.Text = name
	lbl.TextColor3 = C_TABIDLE; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10; lbl.ZIndex = 6
	tabButtons[name] = {frame=btn, lbl=lbl}
	btn.MouseButton1Click:Connect(function() selectTab(name) end)
end

-- ===================================================================
-- MINI BUTTON
-- ===================================================================
local miniBtn = Instance.new("TextButton", gui)
-- Left-edge by default (scale-based, not a fixed pixel offset). History of
-- what was tried and why each failed:
--   (0,20,0,140) top-left, fixed pixel  → landed square on the native
--     mobile dock (reported: covered Shop/Rebirth).
--   dead-center                         → sits on screen the WHOLE TIME
--     the hub is minimized (unlike mainOuter, only centered while open),
--     so it permanently covered the character during normal play.
--   right edge, vertically centered     → collided with the hub's OWN
--     floating-buttons grid, which is also right-anchored (AIM V2/DROP
--     BR/AUTO LEFT/… all hug the right edge) — same "swallowed" symptom,
--     just against our own UI instead of the game's.
--   left edge, 0.72 down (mid-lower)    → requested move: too low, wanted
--     up near the Roblox logo at the top instead.
-- Now: left edge, in the gap just below Roblox's own top-left icon row
-- (avatar/menu/chat, roughly the top ~17% of screen) and above the native
-- dock further down — clear of both. Still fully draggable afterward.
local MINI_BTN_DEFAULT_POS = UDim2.new(0,20,0.20,0)
miniBtn.Size = UDim2.new(0,56,0,56); miniBtn.Position = MINI_BTN_DEFAULT_POS
miniBtn.BackgroundTransparency = 1; miniBtn.Text = ""; miniBtn.AutoButtonColor = false
miniBtn.Visible = false; miniBtn.ZIndex = 50

local mbHalo = Instance.new("Frame", miniBtn)
mbHalo.AnchorPoint = Vector2.new(0.5,0.5); mbHalo.Position = UDim2.new(0.5,0,0.5,0)
mbHalo.Size = UDim2.new(1.5,0,1.5,0); mbHalo.BackgroundColor3 = C_MOON
mbHalo.BorderSizePixel = 0; mbHalo.ZIndex = 49
Instance.new("UICorner", mbHalo).CornerRadius = UDim.new(1,0)
local mbHaloGrad = Instance.new("UIGradient", mbHalo)
mbHaloGrad.Color = ColorSequence.new(C_MOON, Color3.fromRGB(10,12,18))
mbHaloGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.55),NumberSequenceKeypoint.new(1,1)})
mbHaloGrad.Rotation = 90

local miniDisc = Instance.new("Frame", miniBtn)
miniDisc.Size = UDim2.new(1,0,1,0); miniDisc.BackgroundColor3 = Color3.fromRGB(0,0,0)
miniDisc.BorderSizePixel = 0; miniDisc.ZIndex = 50
Instance.new("UICorner", miniDisc).CornerRadius = UDim.new(1,0)
addGradient(miniDisc, Color3.fromRGB(22,27,40), Color3.fromRGB(10,12,18), 90)
local miniStk = addLivingStroke(miniDisc, 1.3)

local moonIconSize = 26
local moonIcon = Instance.new("Frame", miniDisc)
moonIcon.AnchorPoint = Vector2.new(0.5,0.5); moonIcon.Position = UDim2.new(0.5,0,0.5,0)
moonIcon.Size = UDim2.new(0,moonIconSize,0,moonIconSize)
moonIcon.BackgroundColor3 = C_SILVER; moonIcon.BorderSizePixel = 0; moonIcon.ZIndex = 51
Instance.new("UICorner", moonIcon).CornerRadius = UDim.new(1,0)
-- Crescent bite: a dark circle overlapping the light disc's edge. NOT
-- wrapped in a ClipsDescendants frame anymore — Roblox clips descendants
-- to a frame's plain RECTANGULAR bounding box no matter what UICorner is
-- set on the clipping frame itself, so the old moonIconShadowClip wrapper
-- was cutting this to a square at the disc's corners ("carré bizarre"
-- wherever the moon icon renders). moonIconShadow already has its own
-- UICorner making IT a real circle, so it doesn't need clipping to look
-- right — any sliver that pokes past moonIcon's own round edge just
-- blends into miniDisc's near-identical dark background behind it.
local moonIconShadow = Instance.new("Frame", moonIcon)
moonIconShadow.AnchorPoint = Vector2.new(0.5,0.5); moonIconShadow.Position = UDim2.new(0.62,0,0.5,0)
-- Deliberately NOT pure (0,0,0): this needs to always match miniDisc's own
-- fixed dark gradient fill (which a theme switch never touches, since a
-- UIGradient overrides the plain BackgroundColor3 underneath it) — if this
-- bite got swept to White theme's panel background instead, it would show
-- as a bright cutout on a disc that stayed dark, breaking the crescent look.
moonIconShadow.Size = UDim2.new(1.05,0,1.05,0); moonIconShadow.BackgroundColor3 = Color3.fromRGB(15,18,28)
moonIconShadow.BorderSizePixel = 0; moonIconShadow.ZIndex = 52
Instance.new("UICorner", moonIconShadow).CornerRadius = UDim.new(1,0)

local _mbAnimRunning = false
local function startMbAnim()
	if _mbAnimRunning then return end
	_mbAnimRunning = true
	task.spawn(function()
		while miniBtn and miniBtn.Parent and _mbAnimRunning do
			TweenService:Create(miniStk,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=0.05}):Play()
			TweenService:Create(mbHalo,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Size=UDim2.new(1.7,0,1.7,0)}):Play()
			task.wait(1.5)
			TweenService:Create(miniStk,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=0.4}):Play()
			TweenService:Create(mbHalo,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Size=UDim2.new(1.5,0,1.5,0)}):Play()
			task.wait(1.5)
		end
	end)
end
startMbAnim()
_GH.mbHalo = mbHalo; _GH.miniStk = miniStk; _GH.startMbAnim = startMbAnim
_GH.stopMbAnim = function() _mbAnimRunning = false end
_GH.miniBtn = miniBtn
-- Deliberately NOT persisted (no posId, unlike every other draggable here) —
-- this button is the ONLY way back into the whole hub once it's minimized.
-- It used to save/restore its dragged position like everything else, which
-- means a bad or stale saved spot from an older/broken build (e.g. the old
-- top-left default that overlapped a game's native dock) would keep loading
-- right back in on every future run, with no way to reach Settings > Reset
-- Position to fix it — the hub would be softlocked shut. Still draggable
-- mid-session for convenience; just always starts fresh and on-screen.
makeDraggable(miniBtn, nil, nil)

-- Ambient dust: a few soft motes drifting off the moon icon while it's
-- minimized — idle life for what would otherwise be a static button.
-- Fully self-contained (own Frames, own loop, reads C_MOON2 fresh each
-- spawn so it follows theme changes) — can't touch drag/click/anything else.
task.spawn(function()
	while gui.Parent do
		task.wait(math.random(4,8)/10)
		if miniBtn.Visible then
			pcall(function()
				local ang = math.random() * math.pi * 2
				local dist = 20 + math.random() * 14
				local mote = Instance.new("Frame", miniBtn)
				mote.AnchorPoint = Vector2.new(0.5,0.5)
				mote.Size = UDim2.new(0, math.random(2,3), 0, math.random(2,3))
				mote.Position = UDim2.new(0.5, math.cos(ang)*10, 0.5, math.sin(ang)*10)
				mote.BackgroundColor3 = C_MOON2
				mote.BackgroundTransparency = 0.3
				mote.BorderSizePixel = 0
				mote.ZIndex = 48
				addCorner(mote, 2)
				local dur = 1.2 + math.random()*0.6
				TweenService:Create(mote, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Position = UDim2.new(0.5, math.cos(ang)*dist, 0.5, math.sin(ang)*dist),
					BackgroundTransparency = 1,
				}):Play()
				task.delay(dur+0.1, function() if mote then mote:Destroy() end end)
			end)
		end
	end
end)

-- Shared guard: the close animation is async (spans several frames), so
-- showGui() must refuse to start a fresh pop-in while the panel is still
-- mid-flight into the moon — avoids the two animations fighting over
-- mainOuter.Position / mainUIScale.Scale at the same time.
local _closeAnimPlaying = false

-- Reuses the existing mainUIScale (persisted UI Scale setting) so the pop-in
-- never fights the user's chosen size — it just animates toward whatever
-- scale/position applyUIScale already settled on.
local function showGui()
	if _closeAnimPlaying then return end
	mainOuter.Visible = true; miniBtn.Visible = false
	local targetScale = mainUIScale.Scale
	local targetPos = mainOuter.Position
	mainUIScale.Scale = targetScale * 0.85
	mainOuter.Position = targetPos + UDim2.new(0,0,0,14)
	TweenService:Create(mainUIScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale=targetScale}):Play()
	TweenService:Create(mainOuter, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position=targetPos}):Play()
end

-- Small glint that "pops" on the moon icon the instant the panel is absorbed.
local function moonAbsorbFlash()
	local cx = miniBtn.Position.X.Offset + miniBtn.Size.X.Offset/2
	local cy = miniBtn.Position.Y.Offset + miniBtn.Size.Y.Offset/2
	local ring = Instance.new("Frame", gui)
	ring.AnchorPoint = Vector2.new(0.5,0.5)
	ring.Position = UDim2.new(miniBtn.Position.X.Scale, cx, miniBtn.Position.Y.Scale, cy)
	ring.Size = UDim2.new(0,8,0,8); ring.BackgroundColor3 = C_MOON
	ring.BackgroundTransparency = 0.15; ring.BorderSizePixel = 0; ring.ZIndex = 60
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1,0)
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size=UDim2.new(0,64,0,64), BackgroundTransparency=1}):Play()
	task.delay(0.36, function() if ring then ring:Destroy() end end)
end

-- Closing "sucks" the panel toward the moon icon (shrink + slide), then flashes
-- a glint on the moon on arrival — restores mainOuter to its resting
-- position/scale afterward so the next showGui() pop-in starts correctly.
local function hideGui()
	if _closeAnimPlaying or not mainOuter.Visible then return end
	_closeAnimPlaying = true
	miniBtn.Visible = true

	local savedPos    = mainOuter.Position
	local savedAnchor = mainOuter.AnchorPoint
	local savedScale  = mainUIScale.Scale
	local savedBg     = bgImg.BackgroundTransparency
	local savedStroke = mainStroke.Transparency
	local savedMainCorner = mainCorner.CornerRadius
	local savedBgCorner   = bgCorner.CornerRadius

	-- Whole animation runs inside pcall + a fixed task.wait (NOT
	-- Tween.Completed:Wait()) so nothing here can hang forever — some
	-- executors never fire Completed reliably, and a stuck Wait() here used
	-- to leave _closeAnimPlaying stuck true, permanently disabling
	-- open/close for the rest of the session.
	pcall(function()
		local half = mainOuter.AbsoluteSize
		mainOuter.AnchorPoint = Vector2.new(0.5,0.5)
		mainOuter.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset + half.X/2, savedPos.Y.Scale, savedPos.Y.Offset + half.Y/2)

		local cx = miniBtn.Position.X.Offset + miniBtn.Size.X.Offset/2
		local cy = miniBtn.Position.Y.Offset + miniBtn.Size.Y.Offset/2
		local targetPos = UDim2.new(miniBtn.Position.X.Scale, cx, miniBtn.Position.Y.Scale, cy)

		local dur = 0.3
		local info = TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		TweenService:Create(mainOuter, info, {Position=targetPos}):Play()
		TweenService:Create(mainUIScale, info, {Scale=0.02}):Play()
		TweenService:Create(bgImg, info, {BackgroundTransparency=1}):Play()
		TweenService:Create(mainStroke, info, {Transparency=1}):Play()
		-- Rounds toward a full circle as it shrinks — without this the
		-- panel keeps its fixed 24px corner radius the whole way down,
		-- which reads as a shrinking square instead of melting into the
		-- round moon icon it's flying toward. UDim.new(1,0) is the actual
		-- "fully round" value (scale is relative to the shorter side, so
		-- 100% = a perfect circle/pill) — the previous 0.5 only rounds
		-- halfway, which still reads as a squarish blob once the panel has
		-- shrunk down small, right on top of the moon icon it lands on.
		TweenService:Create(mainCorner, info, {CornerRadius=UDim.new(1,0)}):Play()
		TweenService:Create(bgCorner, info, {CornerRadius=UDim.new(1,0)}):Play()
		task.wait(dur)

		moonAbsorbFlash()
	end)

	-- Always restore the resting layout and clear the guard, even if the
	-- animation above errored partway — the panel must never get stuck.
	mainOuter.Visible = false
	mainOuter.AnchorPoint = savedAnchor
	mainOuter.Position = savedPos
	mainUIScale.Scale = savedScale
	bgImg.BackgroundTransparency = savedBg
	mainStroke.Transparency = savedStroke
	mainCorner.CornerRadius = savedMainCorner
	bgCorner.CornerRadius = savedBgCorner
	_closeAnimPlaying = false
end
closeBtn.MouseButton1Click:Connect(hideGui)
miniBtn.MouseButton1Click:Connect(showGui)
_GH.showGui = showGui

-- Snaps the main panel back to its default centered position (keeps
-- whatever UI Scale is currently set — only Position moves). Used by the
-- "Reset Position" button in Settings.
local function resetMainPosition()
	local scaledW = WIN_W * mainUIScale.Scale
	local targetPos = UDim2.new(0.5, -scaledW/2, 0.5, -137)
	TweenService:Create(mainOuter, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = targetPos}):Play()
	-- Also snaps the minimized moon icon back to its centered default —
	-- it has its own independent position (dragged separately from the
	-- main panel), so it needs its own reset or it stays wherever it was
	-- left, including on top of a native UI dock if it ever ends up there.
	TweenService:Create(miniBtn, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = MINI_BTN_DEFAULT_POS}):Play()
	if _GH.autoSave then _GH.autoSave() end
end
_GH.resetMainPosition = resetMainPosition

-- ===================================================================
-- Drag-lock is handled only by lockTitleBtn (title button).
-- No additional widget.

-- ===================================================================
-- MOVEMENT LOGIC
-- ===================================================================
buildPage("Combat", function()
	UIB.makeSectionLabel("Combat")
	setBatCounterRowVisual = UIB.makeToggleRow("Bat Counter",false,function(on)
		BatCounter.active=on; if on then BatCounter.start() else BatCounter.stop() end
	end)
	setAimbotRowVisual = UIB.makeToggleRow("Bat Aimbot",false,function(on)
		if on then if ABP.active then ABP.stop() end; AB.start() else AB.stop() end
	end)
	setAimbotV2RowVisual = UIB.makeToggleRow("Bat Aimbot V2",false,function(on)
		if on then if AB.active then AB.stop() end; ABP.start() else ABP.stop() end
	end)
	UIB.makeGap(4); UIB.makeSectionLabel("Aimbot Tuning")
	UIB.makeInputRow("Aim Speed",AB.SPEED,function(n) if n>0 and n<=200 then AB.SPEED=n end end)
	UIB.makeInputRow("Aim Height",AB.HEIGHT,function(n) if n>=0 and n<=30 then AB.HEIGHT=n end end)
	UIB.makeGap(4); UIB.makeSectionLabel("Defense")
	UIB.makeToggleRow("Safe Mode",false,function(on)
		_GH.SM_setEnabled(on)
	end)
	setAntiRagdollRowVisual=UIB.makeToggleRow("Anti Ragdoll",false,function(on)
		State.antiRagdollEnabled=on; if on then startAntiRagdoll() else stopAntiRagdoll() end
	end)
	UIB.makeToggleRow("Medusa Counter",false,function(on)
		State.medusaCounterEnabled=on
		if on then setupMedusaCounter(LP.Character) else stopMedusaCounter() end
	end)
	UIB.makeToggleRow("Auto Reset Medusa",false,function(on)
		_armState.enabled=on
		if on then setupAutoResetMedusa(LP.Character) else stopAutoResetMedusa() end
	end)
	setInfJumpRowVisual = UIB.makeToggleRow("Infinite Jump",false,function(on)
		IJ.active=on; if on then IJ.start() else IJ.stop() end
	end)
	setAutoStealRowVisual=UIB.makeToggleRow("Auto Steal",true,function(on)
		AutoSteal.Enabled=on; if on then startAutoSteal() else stopAutoSteal() end
	end)
	UIB.makeInputRow("Steal Radius",AutoSteal.Radius,function(n) if n and n>=1 and n<=500 then AutoSteal.Radius=n end end)
	local _autoTPEnabled = false
	local _autoTPConn    = nil
	local _autoTPHeight  = 20
	UIB.makeToggleRow("Auto TP Down", false, function(on)
		_autoTPEnabled = on
		if on then
			if _autoTPConn then pcall(function() task.cancel(_autoTPConn) end) end
			_autoTPConn = task.spawn(function()
				while _autoTPEnabled do
					task.wait(0.1)
					pcall(function()
						local char = LP.Character; if not char then return end
						local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
						local hum2 = char:FindFirstChildOfClass("Humanoid"); if not hum2 then return end
						if hum2.FloorMaterial ~= Enum.Material.Air then return end
						if root.Position.Y < _autoTPHeight then return end
						root.CFrame = CFrame.new(root.Position.X, -7.00, root.Position.Z)
							* CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
						root.AssemblyLinearVelocity = Vector3.zero
					end)
				end
			end)
		else
			if _autoTPConn then pcall(function() task.cancel(_autoTPConn) end); _autoTPConn = nil end
		end
	end)
	UIB.makeInputRow("TP Height (Y)", _autoTPHeight, function(n)
		if n >= 0 and n <= 500 then _autoTPHeight = n end
	end)
	local tpDownRow=Instance.new("Frame",currentPage)
	tpDownRow.Size=UDim2.new(1,0,0,32); tpDownRow.BackgroundColor3=C_ROW; tpDownRow.BackgroundTransparency=0.35
	tpDownRow.BorderSizePixel=0; tpDownRow.LayoutOrder=LO(); addCorner(tpDownRow,12); addLivingStroke(tpDownRow,1)
	local tpDownClk=Instance.new("TextButton",tpDownRow)
	tpDownClk.Size=UDim2.new(1,0,1,0); tpDownClk.BackgroundTransparency=1
	tpDownClk.Text="TP Down"; tpDownClk.TextColor3=C_WHITE; tpDownClk.Font=Enum.Font.GothamBold; tpDownClk.TextSize=10
	addLivingTextGradient(tpDownClk); tpDownClk.MouseButton1Click:Connect(tpToGround)
	local dropRow=Instance.new("Frame",currentPage)
	dropRow.Size=UDim2.new(1,0,0,32); dropRow.BackgroundColor3=C_ROW; dropRow.BackgroundTransparency=0.35
	dropRow.BorderSizePixel=0; dropRow.LayoutOrder=LO(); addCorner(dropRow,12); addLivingStroke(dropRow,1)
	local dropClk=Instance.new("TextButton",dropRow)
	dropClk.Size=UDim2.new(1,0,1,0); dropClk.BackgroundTransparency=1
	dropClk.Text="Drop Brainrot"; dropClk.TextColor3=C_WHITE; dropClk.Font=Enum.Font.GothamBold; dropClk.TextSize=10
	addLivingTextGradient(dropClk); dropClk.MouseButton1Click:Connect(runDropBrainrot)
end)

-- Declared here (before buildPage Visual) to be visible in applyScale.
-- "Spawnable" floating button system (replaces the fixed Quick Panel +
-- attach/detach): each action has a toggle in Settings that shows/hides
-- its floating button. "Lock" freezes the drag of all
-- currently displayed buttons.
local _floatDefs      = {}   -- id -> {label, onClick, isActive, momentary}
local _floatBtns      = {}   -- id -> {frame, setActive}
local _floatPositions = {}   -- id -> {xs,xo,ys,yo}
-- Bump this whenever the default layout changes: saved positions from an
-- older version get discarded on load instead of restoring stale/overlapping
-- coordinates, so everyone gets the current clean column layout by default.
local _FLOAT_POS_VERSION = 15  -- bumped: default grid now carries more gap (was 3px, now 8px)
local FLOAT_WIDE_H = 30
local _floatLocked    = false
-- "Move Together": when on, dragging any one spawned floating button
-- carries every other spawned one along by the same delta, so the whole
-- group can be repositioned in a single drag instead of one at a time.
local _floatLinkMove     = false
local _linkDragSnapshot  = nil  -- id -> Position, captured at drag-start while link-move is on
local function setFloatLinkMove(on) _floatLinkMove = on end
_GH.setFloatLinkMove = setFloatLinkMove
local FLOAT_SZ = 46

-- Stable order (independent of activation order) so buttons always line
-- up the same way: a tight 2-wide grid. Declared here (not next to
-- makeFloatButton further down) so both makeFloatButton AND the "Button
-- Size" slider in applyScale can share the exact same position formula —
-- previously the slider only grew each button's Size and never touched
-- Position, so at high scale neighbouring buttons grew into each other.
local _FLOAT_GRID_ORDER = {
	"aimbot","aimv2","dropbr","autoleft",
	"autoright","tpdown","battp","instareset",
}
local function _floatGridIndex(id)
	for i, fid in ipairs(_FLOAT_GRID_ORDER) do
		if fid == id then return i end
	end
	return #_FLOAT_GRID_ORDER + 1
end
local FLOAT_GAP = 8  -- was 3 — the extra room the user asked for
local function _floatGridPos(id, sz)
	local idx = _floatGridIndex(id) - 1
	local col = idx % 2
	local row = math.floor(idx / 2)
	local topOffset = 40
	local blockW = sz * 2 + FLOAT_GAP
	return UDim2.new(1, -(blockW + 12) + col * (sz + FLOAT_GAP), 0, topOffset + row * (sz + FLOAT_GAP))
end

-- Clears every custom-dragged floating-button position and snaps whatever
-- is currently spawned back to the default grid. Used by the "Reset
-- Position" button in Settings (alongside resetMainPosition).
local function resetFloatPositions()
	for k in pairs(_floatPositions) do _floatPositions[k] = nil end
	for id, entry in pairs(_floatBtns) do
		if entry.frame and entry.frame.Parent then
			TweenService:Create(entry.frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{Position = _floatGridPos(id, FLOAT_SZ)}):Play()
		end
	end
	if _GH.autoSave then _GH.autoSave() end
end
_GH.resetFloatPositions = resetFloatPositions

-- Declared here (before buildPage Settings) so the Speed
-- Bypass / Lagger toggles can reference the widgets built further
-- down in the file — otherwise the closure captures a nil global (same
-- trap as the mainFrame bug fixed earlier).
local _sbBypassWidget  = nil
local _lgrBypassWidget = nil

-- Speed Booster "edited" size (via the Visual tab's Scale slider)
-- — shared with the widget's "-" button so it doesn't revert
-- to a hardcoded default size when shrinking/expanding.
local _spExpandedSize = {w = 150, h = 160}
local _spCollapsed    = false

buildPage("Visual", function()
	-- ── FLOATING BUTTON SCALE ─────────────────────────────────────────
	-- Size of spawnable buttons. Scale 1=min(40px) → 10=max(74px).
	-- Stores the current value so the slider reflects the real state.
	UIB.makeSectionLabel("Button Size")
	UIB.makeGap(2)

	-- Display the current value
	local scaleValLbl = Instance.new("TextLabel", currentPage)
	scaleValLbl.Size = UDim2.new(1,0,0,18); scaleValLbl.BackgroundTransparency = 1
	scaleValLbl.Text = "Scale: 5 / 10"
	scaleValLbl.TextColor3 = C_MOON2; scaleValLbl.Font = Enum.Font.GothamBold; scaleValLbl.TextSize = 10
	scaleValLbl.TextXAlignment = Enum.TextXAlignment.Left; scaleValLbl.LayoutOrder = LO()
	addLivingTextGradient(scaleValLbl)

	-- Slider track
	local trackWrap = Instance.new("Frame", currentPage)
	trackWrap.Size = UDim2.new(1,0,0,32); trackWrap.BackgroundColor3 = C_ROW
	trackWrap.BackgroundTransparency = 0.35; trackWrap.BorderSizePixel = 0; trackWrap.LayoutOrder = LO()
	addCorner(trackWrap, 12); addLivingStroke(trackWrap, 1)

	local track = Instance.new("Frame", trackWrap)
	track.Size = UDim2.new(1,-28,0,4); track.Position = UDim2.new(0,14,0.5,-2)
	track.BackgroundColor3 = C_DEEP2; track.BorderSizePixel = 0
	addCorner(track, 2)

	local trackFill = Instance.new("Frame", track)
	trackFill.Size = UDim2.new(0.4,0,1,0)   -- 0.4 = initial position (scale 5 of 10)
	trackFill.BackgroundColor3 = C_MOON; trackFill.BorderSizePixel = 0
	addCorner(trackFill, 2)
	addLivingTextGradient(trackFill)

	local thumb = Instance.new("TextButton", trackWrap)
	thumb.Size = UDim2.new(0,16,0,16); thumb.AnchorPoint = Vector2.new(0.5,0.5)
	thumb.Position = UDim2.new(0.4,14,0.5,0)   -- initial position synced with fill
	thumb.BackgroundColor3 = C_WHITE; thumb.BorderSizePixel = 0; thumb.Text = ""
	thumb.AutoButtonColor = false; thumb.ZIndex = 5
	addCorner(thumb, 8); addLivingStroke(thumb, 1)

	-- Slider drag logic (no dragPosLabel)
	local _scaleVal = 5     -- current value 1-10
	local _thumbDrag = false
	local _trackAbsX, _trackAbsW = 0, 1

	local function applyScale(v)
		_scaleVal = math.clamp(math.floor(v + 0.5), 1, 10)
		local t = (_scaleVal - 1) / 9
		trackFill.Size = UDim2.new(t, 0, 1, 0)
		thumb.Position = UDim2.new(0, 14 + t * math.max(_trackAbsW - 1, 1), 0.5, 0)
		scaleValLbl.Text = "Scale: " .. _scaleVal .. " / 10"

		-- Range: 34px (scale 1) → 70px (scale 10) — floating button size
		local newSz = 34 + math.floor((_scaleVal - 1) * (70 - 34) / 9)
		FLOAT_SZ = newSz
		for id, entry in pairs(_floatBtns) do
			if entry.frame and entry.frame.Parent then
				entry.frame.Size = UDim2.new(0, newSz, 0, newSz)
				-- Only grid-default buttons get repositioned — anything the
				-- user has dragged to a custom spot keeps that spot (growing
				-- in place there), same as before. This is what fixes buttons
				-- overlapping each other as the size grows: previously only
				-- Size changed here and Position never followed along.
				if not _floatPositions[id] then
					entry.frame.Position = _floatGridPos(id, newSz)
				end
			end
		end
	end

	thumb.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			_thumbDrag = true
			_trackAbsX = track.AbsolutePosition.X
			_trackAbsW = track.AbsoluteSize.X
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if not _thumbDrag then return end
		if inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch then
			local rel = math.clamp((inp.Position.X - _trackAbsX) / _trackAbsW, 0, 1)
			applyScale(1 + rel * 9)
		end
	end)
	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			_thumbDrag = false
		end
	end)
	-- Direct click on the track
	local trackBtn = Instance.new("TextButton", trackWrap)
	trackBtn.Size = UDim2.new(1,0,1,0); trackBtn.BackgroundTransparency = 1; trackBtn.Text = ""
	trackBtn.ZIndex = 4
	trackBtn.MouseButton1Click:Connect(function()
		_trackAbsX = track.AbsolutePosition.X
		_trackAbsW = track.AbsoluteSize.X
		local mPos = UIS:GetMouseLocation()
		local rel = math.clamp((mPos.X - _trackAbsX) / _trackAbsW, 0, 1)
		applyScale(1 + rel * 9)
	end)

	-- ── UI SCALE (main hub size) ──────────────────────────────────────
	UIB.makeGap(6)
	UIB.makeSectionLabel("UI Scale")

	local uiScaleValLbl = Instance.new("TextLabel", currentPage)
	uiScaleValLbl.Size = UDim2.new(1,0,0,18); uiScaleValLbl.BackgroundTransparency = 1
	uiScaleValLbl.Text = "Scale: 5 / 10"
	uiScaleValLbl.TextColor3 = C_MOON2; uiScaleValLbl.Font = Enum.Font.GothamBold; uiScaleValLbl.TextSize = 10
	uiScaleValLbl.TextXAlignment = Enum.TextXAlignment.Left; uiScaleValLbl.LayoutOrder = LO()
	addLivingTextGradient(uiScaleValLbl)

	local uiTrackWrap = Instance.new("Frame", currentPage)
	uiTrackWrap.Size = UDim2.new(1,0,0,32); uiTrackWrap.BackgroundColor3 = C_ROW
	uiTrackWrap.BackgroundTransparency = 0.35; uiTrackWrap.BorderSizePixel = 0; uiTrackWrap.LayoutOrder = LO()
	addCorner(uiTrackWrap, 12); addLivingStroke(uiTrackWrap, 1)

	local uiTrack = Instance.new("Frame", uiTrackWrap)
	uiTrack.Size = UDim2.new(1,-28,0,4); uiTrack.Position = UDim2.new(0,14,0.5,-2)
	uiTrack.BackgroundColor3 = C_DEEP2; uiTrack.BorderSizePixel = 0
	addCorner(uiTrack, 2)

	local uiTrackFill = Instance.new("Frame", uiTrack)
	uiTrackFill.Size = UDim2.new(0.4,0,1,0)
	uiTrackFill.BackgroundColor3 = C_MOON; uiTrackFill.BorderSizePixel = 0
	addCorner(uiTrackFill, 2); addLivingTextGradient(uiTrackFill)

	local uiThumb = Instance.new("TextButton", uiTrackWrap)
	uiThumb.Size = UDim2.new(0,16,0,16); uiThumb.AnchorPoint = Vector2.new(0.5,0.5)
	uiThumb.Position = UDim2.new(0.4,14,0.5,0)
	uiThumb.BackgroundColor3 = C_WHITE; uiThumb.BorderSizePixel = 0; uiThumb.Text = ""
	uiThumb.AutoButtonColor = false; uiThumb.ZIndex = 5
	addCorner(uiThumb, 8); addLivingStroke(uiThumb, 1)

	-- WIN_W=300, WIN_H=340 — scale 1=60% → 10=140%
	local _uiScaleVal  = 5
	local _uiThumbDrag = false
	local _uiTrackAbsX, _uiTrackAbsW = 0, 1

	local function applyUIScale(v)
		_uiScaleVal = math.clamp(math.floor(v + 0.5), 1, 10)
		local t   = (_uiScaleVal - 1) / 9
		uiTrackFill.Size    = UDim2.new(t, 0, 1, 0)
		local absW = uiTrack.AbsoluteSize.X
		if absW > 2 then
			uiThumb.Position = UDim2.new(0, 14 + t * absW, 0.5, 0)
		end
		uiScaleValLbl.Text  = "Scale: " .. _uiScaleVal .. " / 10"
		local factor = 0.6 + t * 0.8
		if mainOuter and mainOuter.Parent then
			-- UIScale resizes everything proportionally (text, rows, spacing)
			-- instead of just shrinking the frame — nothing gets cut off
			-- by ClipsDescendants, unlike the old direct resize.
			mainUIScale.Scale = factor
			local scaledW = WIN_W * factor
			mainOuter.Position = UDim2.new(0.5, -scaledW/2, 0.5, -137)
		end
	end
	_GH.applyUIScale = applyUIScale
	_GH.getUIScale   = function() return _uiScaleVal end

	uiThumb.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			_uiThumbDrag = true
			_uiTrackAbsX = uiTrack.AbsolutePosition.X
			_uiTrackAbsW = uiTrack.AbsoluteSize.X
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if not _uiThumbDrag then return end
		if inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch then
			local rel = math.clamp((inp.Position.X - _uiTrackAbsX) / _uiTrackAbsW, 0, 1)
			applyUIScale(1 + rel * 9)
		end
	end)
	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			_uiThumbDrag = false
		end
	end)
	local uiTrackBtn = Instance.new("TextButton", uiTrackWrap)
	uiTrackBtn.Size = UDim2.new(1,0,1,0); uiTrackBtn.BackgroundTransparency = 1; uiTrackBtn.Text = ""
	uiTrackBtn.ZIndex = 4
	uiTrackBtn.MouseButton1Click:Connect(function()
		_uiTrackAbsX = uiTrack.AbsolutePosition.X
		_uiTrackAbsW = uiTrack.AbsoluteSize.X
		local mPos = UIS:GetMouseLocation()
		local rel  = math.clamp((mPos.X - _uiTrackAbsX) / _uiTrackAbsW, 0, 1)
		applyUIScale(1 + rel * 9)
	end)

	UIB.makeGap(4)
	UIB.makeSectionLabel("Lighting")
	UIB.makeToggleRow("Fullbright",false,function(on) Lighting.Brightness=on and 10 or 1 end)
	UIB.makeToggleRow("Shadows OFF",false,function(on) Lighting.GlobalShadows=not on end)
	UIB.makeToggleRow("Fog OFF",false,function(on) Lighting.FogEnd=on and 9e9 or 1000 end)
	UIB.makeInputRow("FOV",70,function(n) if n>=30 and n<=120 then workspace.CurrentCamera.FieldOfView=n end end)
	UIB.makeGap(4)
	UIB.makeSectionLabel("Sky & Atmosphere")
	local _dBri,_dClock,_dAmb,_dOut,_dFogE,_dFogC = Lighting.Brightness,Lighting.ClockTime,Lighting.Ambient,Lighting.OutdoorAmbient,Lighting.FogEnd,Lighting.FogColor
	UIB.makeToggleRow("Dark Mode",false,function(on)
		if on then
			local s=Lighting:FindFirstChild("MoonDS") or Instance.new("Sky"); s.Name="MoonDS"
			s.SkyboxBk="rbxassetid://159454299";s.SkyboxDn="rbxassetid://159454296";s.SkyboxFt="rbxassetid://159454293"
			s.SkyboxLf="rbxassetid://159454286";s.SkyboxRt="rbxassetid://159454289";s.SkyboxUp="rbxassetid://159454291";s.Parent=Lighting
			Lighting.Brightness=0;Lighting.ClockTime=0;Lighting.OutdoorAmbient=Color3.fromRGB(0,0,0)
		else
			local s=Lighting:FindFirstChild("MoonDS");if s then s:Destroy() end
			Lighting.Brightness=_dBri;Lighting.ClockTime=_dClock;Lighting.OutdoorAmbient=_dOut
		end
	end)
	UIB.makeToggleRow("Cloudy Blue",false,function(on)
		if on then
			Lighting.ClockTime=7;Lighting.Brightness=1.2;Lighting.FogEnd=800;Lighting.FogColor=Color3.fromRGB(160,190,255)
			Lighting.Ambient=Color3.fromRGB(190,200,230);Lighting.OutdoorAmbient=Color3.fromRGB(200,210,240)
			local cc=Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect",Lighting)
			cc.TintColor=Color3.fromRGB(180,210,255);cc.Saturation=0.12;cc.Brightness=0.04
		else
			Lighting.ClockTime=_dClock;Lighting.Brightness=_dBri;Lighting.FogEnd=_dFogE;Lighting.FogColor=_dFogC
			Lighting.Ambient=_dAmb;Lighting.OutdoorAmbient=_dOut
			local cc=Lighting:FindFirstChildOfClass("ColorCorrectionEffect");if cc then cc:Destroy() end
		end
	end)

	-- Speed Booster Scale
	UIB.makeGap(4)
	UIB.makeSectionLabel("Speed Booster Scale")
	do
		local spScaleValLbl=Instance.new("TextLabel",currentPage)
		spScaleValLbl.Size=UDim2.new(1,0,0,18); spScaleValLbl.BackgroundTransparency=1
		spScaleValLbl.Text="Scale: 5 / 10"; spScaleValLbl.TextColor3=C_MOON2
		spScaleValLbl.Font=Enum.Font.GothamBold; spScaleValLbl.TextSize=10
		spScaleValLbl.TextXAlignment=Enum.TextXAlignment.Left; spScaleValLbl.LayoutOrder=LO()
		addLivingTextGradient(spScaleValLbl)
		local spScWrap=Instance.new("Frame",currentPage)
		spScWrap.Size=UDim2.new(1,0,0,32); spScWrap.BackgroundColor3=C_ROW
		spScWrap.BackgroundTransparency=0.35; spScWrap.BorderSizePixel=0; spScWrap.LayoutOrder=LO()
		addCorner(spScWrap,12); addLivingStroke(spScWrap,1)
		local spScTrk=Instance.new("Frame",spScWrap)
		spScTrk.Size=UDim2.new(1,-28,0,4); spScTrk.Position=UDim2.new(0,14,0.5,-2)
		spScTrk.BackgroundColor3=C_DEEP2; spScTrk.BorderSizePixel=0; addCorner(spScTrk,2)
		local spScFill=Instance.new("Frame",spScTrk)
		spScFill.Size=UDim2.new(0.44,0,1,0); spScFill.BackgroundColor3=C_MOON; spScFill.BorderSizePixel=0
		addCorner(spScFill,2)
		local spScThumb=Instance.new("TextButton",spScWrap)
		spScThumb.Size=UDim2.new(0,16,0,16); spScThumb.AnchorPoint=Vector2.new(0.5,0.5)
		spScThumb.Position=UDim2.new(0,14+0.44*(spScWrap.AbsoluteSize.X or 100),0.5,0)
		spScThumb.BackgroundColor3=C_WHITE; spScThumb.BorderSizePixel=0; spScThumb.Text=""
		spScThumb.AutoButtonColor=false; spScThumb.ZIndex=5
		addCorner(spScThumb,8); addLivingStroke(spScThumb,1)
		local _sv=5; local _sd=false
		local SP_W=180; local SP_H=194
		local function apSpSc(v)
			_sv=math.clamp(math.floor(v+0.5),1,10)
			local t=(_sv-1)/9
			spScFill.Size=UDim2.new(t,0,1,0)
			local aw=spScTrk.AbsoluteSize.X; if aw>2 then spScThumb.Position=UDim2.new(0,14+t*aw,0.5,0) end
			spScaleValLbl.Text="Scale: ".._sv.." / 10"
			local f=0.6+t*0.8
			_spExpandedSize.w = math.floor(SP_W*f)
			_spExpandedSize.h = math.floor(SP_H*f)
			-- Only resize visually if the widget isn't collapsed
			-- ("-"), otherwise the edited size is just remembered for later.
			if _GH.spW and not _spCollapsed then
				_GH.spW.Size=UDim2.new(0,_spExpandedSize.w,0,_spExpandedSize.h)
			end
		end
		spScThumb.InputBegan:Connect(function(inp)
			if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then _sd=true end
		end)
		UIS.InputChanged:Connect(function(inp)
			if not _sd then return end
			if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then
				local ax=spScTrk.AbsolutePosition.X; local aw=spScTrk.AbsoluteSize.X; if aw<2 then return end
				apSpSc(1+math.clamp((inp.Position.X-ax)/aw,0,1)*9)
			end
		end)
		UIS.InputEnded:Connect(function(inp)
			if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then _sd=false end
		end)
	end
end)

buildPage("Keybind", function()
	-- ================================================================
	-- Keybind system: PC keyboard + PlayStation/Xbox controller
	-- Inspired by Amir Hub — one "..." button per action, click → listens
	-- for the next key pressed (keyboard or gamepad)
	-- ================================================================

	-- Central bindings table (exposed for saving)
	local KB = _GH.MH_KB or {
		DropBR        = {key=nil, gp=nil},
		AutoLeft      = {key=nil, gp=nil},
		AimBot        = {key=nil, gp=nil},
		AutoRight     = {key=nil, gp=nil},
		TPDown        = {key=nil, gp=nil},
		LagNorm       = {key=nil, gp=nil},
		BatTP         = {key=nil, gp=nil},
		AimV2         = {key=nil, gp=nil},
		AimV3Kb       = {key=nil, gp=nil},
		InstantReset  = {key=nil, gp=nil},
		HideUI        = {key=nil, gp=nil},
	}
	_GH.MH_KB = KB

	local GAMEPAD_KEYS = {
		[Enum.KeyCode.ButtonA]=true,[Enum.KeyCode.ButtonB]=true,
		[Enum.KeyCode.ButtonX]=true,[Enum.KeyCode.ButtonY]=true,
		[Enum.KeyCode.ButtonL1]=true,[Enum.KeyCode.ButtonR1]=true,
		[Enum.KeyCode.ButtonL2]=true,[Enum.KeyCode.ButtonR2]=true,
		[Enum.KeyCode.ButtonL3]=true,[Enum.KeyCode.ButtonR3]=true,
		[Enum.KeyCode.ButtonStart]=true,[Enum.KeyCode.ButtonSelect]=true,
		[Enum.KeyCode.DPadUp]=true,[Enum.KeyCode.DPadDown]=true,
		[Enum.KeyCode.DPadLeft]=true,[Enum.KeyCode.DPadRight]=true,
	}

	-- Short readable names for display on the button
	local function keyName(kc)
		if not kc then return "—" end
		local n = tostring(kc):gsub("Enum.KeyCode.", "")
		local map = {
			LeftControl="LCTRL", RightControl="RCTRL",
			LeftShift="LSHIFT", RightShift="RSHIFT",
			LeftAlt="LALT", RightAlt="RALT",
			LeftBracket="[", RightBracket="]",
			ButtonA="✕", ButtonB="○", ButtonX="□", ButtonY="△",
			ButtonL1="L1", ButtonR1="R1", ButtonL2="L2", ButtonR2="R2",
			ButtonL3="L3", ButtonR3="R3",
			ButtonStart="START", ButtonSelect="SEL",
			DPadUp="D↑", DPadDown="D↓", DPadLeft="D←", DPadRight="D→",
		}
		return map[n] or n:sub(1,6)
	end

	local _currentListeningBtn = nil  -- reference to the listening button, only one at a time

	local function makeKBRow(labelTxt, entry)
		local row = Instance.new("Frame", currentPage)
		row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = C_ROW
		row.BackgroundTransparency = 0.35; row.BorderSizePixel = 0; row.LayoutOrder = LO()
		addCorner(row, 12); addLivingStroke(row, 1)
		row.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.15}):Play() end)
		row.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.1),{BackgroundTransparency=0.35}):Play() end)

		local lbl = Instance.new("TextLabel", row)
		lbl.Size = UDim2.new(1,-90,1,0); lbl.Position = UDim2.new(0,12,0,0)
		lbl.BackgroundTransparency = 1; lbl.Text = labelTxt
		lbl.TextColor3 = C_WHITE; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		addLivingTextGradient(lbl)

		local kbWrap = Instance.new("Frame", row)
		kbWrap.Size = UDim2.new(0,72,0,22); kbWrap.Position = UDim2.new(1,-80,0.5,-11)
		kbWrap.BackgroundColor3 = C_ON_BG; kbWrap.BackgroundTransparency = 0.2; kbWrap.BorderSizePixel = 0
		addCorner(kbWrap, 6); addLivingStroke(kbWrap, 1)

		local kbBtn = Instance.new("TextButton", kbWrap)
		kbBtn.Size = UDim2.new(1,0,1,0); kbBtn.BackgroundTransparency = 1
		kbBtn.Text = keyName(entry.key or entry.gp)
		kbBtn.TextColor3 = C_MOON2; kbBtn.Font = Enum.Font.GothamBold; kbBtn.TextSize = 9
		kbBtn.AutoButtonColor = false

		local conn = nil
		local timeoutThread = nil

		local function stopListening(newText)
			if conn then conn:Disconnect(); conn = nil end
			if timeoutThread then pcall(task.cancel, timeoutThread); timeoutThread = nil end
			kbBtn.Text = newText or keyName(entry.key or entry.gp)
			kbBtn.TextColor3 = C_MOON2
			if _currentListeningBtn == kbBtn then _currentListeningBtn = nil end
		end

		kbBtn.MouseButton1Click:Connect(function()
			-- If this button is already listening → cancel
			if _currentListeningBtn == kbBtn then
				stopListening(); return
			end
			-- If another button is listening → cancel it first (via its own conn)
			if _currentListeningBtn then
				-- the previous button will clean itself up via its timeout or next click
				_currentListeningBtn = nil
			end
			_currentListeningBtn = kbBtn
			local prev = kbBtn.Text
			kbBtn.Text = "..."; kbBtn.TextColor3 = C_SILVER2

			conn = UIS.InputBegan:Connect(function(inp, gpe)
				if inp.KeyCode == Enum.KeyCode.Unknown then return end
				if inp.UserInputType ~= Enum.UserInputType.Keyboard
					and not GAMEPAD_KEYS[inp.KeyCode] then return end
				if GAMEPAD_KEYS[inp.KeyCode] then
					entry.gp = inp.KeyCode; entry.key = nil
				else
					entry.key = inp.KeyCode; entry.gp = nil
				end
				stopListening(keyName(inp.KeyCode))
				if _GH.autoSave then _GH.autoSave() end
			end)

			-- 6s timeout if no key is pressed
			timeoutThread = task.delay(6, function()
				stopListening(prev)
			end)
		end)

		-- ✕ clears
		local clrBtn = Instance.new("TextButton", row)
		clrBtn.Size = UDim2.new(0,14,0,14); clrBtn.Position = UDim2.new(1,-158,0.5,-7)
		clrBtn.BackgroundColor3 = C_RED; clrBtn.BackgroundTransparency = 0.4
		clrBtn.BorderSizePixel = 0; clrBtn.Text = "✕"; clrBtn.TextColor3 = C_WHITE
		clrBtn.Font = Enum.Font.GothamBold; clrBtn.TextSize = 8; clrBtn.AutoButtonColor = false
		addCorner(clrBtn, 4)
		clrBtn.MouseButton1Click:Connect(function()
			entry.key = nil; entry.gp = nil
			kbBtn.Text = "—"; kbBtn.TextColor3 = C_DIM
			if _GH.autoSave then _GH.autoSave() end
		end)

		local div = Instance.new("Frame", currentPage)
		div.Size = UDim2.new(1,-8,0,1); div.BackgroundColor3 = C_DEEP3
		div.BorderSizePixel = 0; div.LayoutOrder = LO()
		addLivingTextGradient(div)

		return entry
	end

	UIB.makeSectionLabel("Quick Panel")
	makeKBRow("Drop BR",        KB.DropBR)
	makeKBRow("Auto Left",      KB.AutoLeft)
	makeKBRow("Aim Bot",        KB.AimBot)
	makeKBRow("Auto Right",     KB.AutoRight)
	makeKBRow("TP Down",        KB.TPDown)
	makeKBRow("Lag Normal",     KB.LagNorm)
	makeKBRow("Bat TP",         KB.BatTP)
	makeKBRow("Aim V2",         KB.AimV2)
	makeKBRow("Aim V3",         KB.AimV3Kb)
	makeKBRow("Instant Reset",  KB.InstantReset)
	UIB.makeGap(4)
	UIB.makeSectionLabel("Interface")
	makeKBRow("Hide / Show UI", KB.HideUI)

	UIB.makeGap(6)
	local hint = Instance.new("TextLabel", currentPage)
	hint.Size = UDim2.new(1,0,0,28); hint.BackgroundTransparency = 1; hint.LayoutOrder = LO()
	hint.Text = "Click → listen   |   ✕ → clear   |   PC & PS/Xbox"
	hint.TextColor3 = C_DIM; hint.Font = Enum.Font.Gotham; hint.TextSize = 9
	addLivingTextGradient(hint)

	-- ================================================================
	-- Global UIS.InputBegan loop — triggers the bound actions
	-- ================================================================
	UIS.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		if _currentListeningBtn then return end  -- un rebind est en cours
		if UIS:GetFocusedTextBox() then return end
		local kc = inp.KeyCode
		if kc == Enum.KeyCode.Unknown then return end

		local function match(e)
			return (e.key and kc == e.key) or (e.gp and kc == e.gp)
		end

		if match(KB.DropBR)    then runDropBrainrot()
		elseif match(KB.AutoLeft)  then
			State.autoLeftEnabled = not State.autoLeftEnabled
			if State.autoLeftEnabled then startAutoLeft() else stopAutoLeft() end
		elseif match(KB.AimBot)    then
			local on = not AB.active; if on then AB.start() else AB.stop() end
		elseif match(KB.AutoRight) then
			State.autoRightEnabled = not State.autoRightEnabled
			if State.autoRightEnabled then startAutoRight() else stopAutoRight() end
		elseif match(KB.TPDown)    then tpToGround()
		elseif match(KB.LagNorm)   then
			-- Actually flips the Speed Booster's own Normal/Lagger tab
			-- (updates State, the widget's visuals, and re-applies live if
			-- it's already running) instead of only poking State.laggerActive,
			-- which never touched the widget or engaged Lagger mode for real.
			if _GH.speedBoosterSwitchTab then
				local wantLag = not (_GH.speedBoosterIsLagger and _GH.speedBoosterIsLagger())
				_GH.speedBoosterSwitchTab(wantLag)
			else
				State.laggerActive = not State.laggerActive
				if not State.laggerActive then proxyStop() end
			end
		elseif match(KB.BatTP)     then
			local on = not AimV3.active
			if on then AimV3.start() else AimV3.stop() end
		elseif match(KB.AimV2)     then
			if ABP.active then ABP.stop() else if AB.active then AB.stop() end; ABP.start() end
		elseif match(KB.AimV3Kb)   then
			-- [FIX #2] AimV3Kb doit déclencher AimV3 (Bat TP), pas AB (Aimbot V1)
			if AimV3.active then AimV3.stop() else AimV3.start() end
		elseif match(KB.InstantReset) then
			if _GH.MH_instareset then _GH.MH_instareset() end
		elseif match(KB.HideUI) then
			if mainOuter.Visible then hideGui() else showGui() end
		end
	end)
end)

-- ===================================================================
-- REVUL ANTI LAGGER — engine (snapshot + restore, DescendantAdded hook)
-- ===================================================================
local RevulAL = {active=false, conn=nil}
local _ralOrigLighting = {
	GlobalShadows            = Lighting.GlobalShadows,
	FogEnd                   = Lighting.FogEnd,
	Brightness               = Lighting.Brightness,
	EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
	EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
}
local _ralOrigPostFX = {}
local _ralOrigParts  = {}

-- Initial snapshot of all workspace descendants
local function _ralSnapshot()
	_ralOrigPostFX = {}
	for _, fx in ipairs(Lighting:GetChildren()) do
		if fx:IsA("PostEffect") then _ralOrigPostFX[fx] = fx.Enabled end
	end
	_ralOrigParts = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			_ralOrigParts[obj] = {Enabled=obj.Enabled}
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			_ralOrigParts[obj] = {Transparency=obj.Transparency}
		elseif obj:IsA("BasePart") then
			_ralOrigParts[obj] = {Material=obj.Material, Reflectance=obj.Reflectance, CastShadow=obj.CastShadow}
		end
	end
end

local function _ralApplyObj(obj)
	if not _ralOrigParts[obj] then
		-- snapshot for newly streamed objects
		if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			_ralOrigParts[obj] = {Enabled=obj.Enabled}
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			_ralOrigParts[obj] = {Transparency=obj.Transparency}
		elseif obj:IsA("BasePart") then
			_ralOrigParts[obj] = {Material=obj.Material, Reflectance=obj.Reflectance, CastShadow=obj.CastShadow}
		end
	end
	pcall(function()
		if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			obj.Enabled = false
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			obj.Transparency = 1
		elseif obj:IsA("BasePart") then
			obj.Material=Enum.Material.Plastic; obj.Reflectance=0; obj.CastShadow=false
		end
	end)
end

local function ralStart()
	if RevulAL.active then return end
	RevulAL.active = true
	_ralSnapshot()
	Lighting.GlobalShadows=false; Lighting.FogEnd=8999999488; Lighting.Brightness=1
	Lighting.EnvironmentDiffuseScale=0; Lighting.EnvironmentSpecularScale=0
	for _, fx in ipairs(Lighting:GetChildren()) do if fx:IsA("PostEffect") then fx.Enabled=false end end
	for _, obj in ipairs(workspace:GetDescendants()) do _ralApplyObj(obj) end
	RevulAL.conn = workspace.DescendantAdded:Connect(function(obj)
		if RevulAL.active then _ralApplyObj(obj) end
	end)
end

local function ralStop()
	if not RevulAL.active then return end
	RevulAL.active = false
	if RevulAL.conn then RevulAL.conn:Disconnect(); RevulAL.conn=nil end
	-- Restore Lighting
	Lighting.GlobalShadows            = _ralOrigLighting.GlobalShadows
	Lighting.FogEnd                   = _ralOrigLighting.FogEnd
	Lighting.Brightness               = _ralOrigLighting.Brightness
	Lighting.EnvironmentDiffuseScale  = _ralOrigLighting.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = _ralOrigLighting.EnvironmentSpecularScale
	for fx, wasEnabled in pairs(_ralOrigPostFX) do
		if fx and fx.Parent then fx.Enabled=wasEnabled end
	end
	-- Restore workspace
	for obj, saved in pairs(_ralOrigParts) do
		if obj and obj.Parent then
			pcall(function()
				if saved.Enabled~=nil        then obj.Enabled=saved.Enabled end
				if saved.Transparency~=nil   then obj.Transparency=saved.Transparency end
				if saved.Material~=nil       then obj.Material=saved.Material; obj.Reflectance=saved.Reflectance; obj.CastShadow=saved.CastShadow end
			end)
		end
	end
end

buildPage("Optimize", function()
	UIB.makeSectionLabel("Performance")
	UIB.makeToggleRow("Nuke Optimizer",false,function(on) State.nukeOptEnabled=on; if on then nukeOptStart() else nukeOptStop() end end)
	UIB.makeToggleRow("Remove Accessories",false,function(on) State.removeAccEnabled=on; if on then removeAccStart() else removeAccStop() end end)
	UIB.makeToggleRow("Anti-Lag (Light)",false,function(on) State.antiLagAdvEnabled=on; if on then antiLagAdvStart() else antiLagAdvStop() end end)
	UIB.makeToggleRow("Anti-Lag Booster",false,function(on) if on then ralStart() else ralStop() end end)
	UIB.makeToggleRow("Ultra Mode",false,function(on)
		if on then
			-- raw__59_ logic: plastic-coats everything, disables decals/particles
			Lighting.GlobalShadows=false; Lighting.FogEnd=1e10; Lighting.Brightness=1
			Lighting.EnvironmentDiffuseScale=0; Lighting.EnvironmentSpecularScale=0
			for _,e in pairs(Lighting:GetChildren()) do pcall(function()
				if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect")
					or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then e.Enabled=false end
			end) end
			task.spawn(function()
				for _,obj in pairs(workspace:GetDescendants()) do pcall(function()
					if obj:IsA("BasePart") then obj.Material=Enum.Material.Plastic; obj.Reflectance=0; obj.CastShadow=false
					elseif obj:IsA("Decal") or obj:IsA("Texture") then obj:Destroy()
					elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") then obj.Enabled=false end
				end) end
			end)
			pcall(function() if setfpscap then setfpscap(999999999) end end)
		end
	end)
	UIB.makeToggleRow("Unwalk",false,function(on) if on then startUnwalk() else stopUnwalk() end end)
	UIB.makeGap(4); UIB.makeSectionLabel("Camera")
	do
		local _ncOn = false
		local _ncParts = {}
		local _ncConn = nil
		UIB.makeToggleRow("No Cam Collision",false,function(on)
			_ncOn = on
			if on then
				if _ncConn then _ncConn:Disconnect() end
				_ncConn = RunService.RenderStepped:Connect(function()
					local char=LP.Character; if not char then return end
					local cam=workspace.CurrentCamera; if not cam then return end
					local hrp2=char:FindFirstChild("HumanoidRootPart"); if not hrp2 then return end
					local camPos=cam.CFrame.Position
					local charPos=hrp2.Position+Vector3.new(0,1.5,0)
					local toChar=charPos-camPos; if toChar.Magnitude<0.3 then return end
					local params=RaycastParams.new()
					params.FilterType=Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances={char}
					local hit={}; local origin=camPos; local remaining=toChar
					for _=1,8 do
						if remaining.Magnitude<0.2 then break end
						local res=workspace:Raycast(origin,remaining,params); if not res then break end
						local p2=res.Instance
						if p2 and p2:IsA("BasePart") and not p2:IsDescendantOf(char) then
							hit[p2]=true
							if _ncParts[p2]==nil then _ncParts[p2]=p2.LocalTransparencyModifier end
							p2.LocalTransparencyModifier=1
						end
						origin=res.Position+remaining.Unit*0.02; remaining=charPos-origin
					end
					for p2,orig in pairs(_ncParts) do
						if not hit[p2] then
							pcall(function() if p2 and p2.Parent then p2.LocalTransparencyModifier=orig end end)
							_ncParts[p2]=nil
						end
					end
				end)
			else
				if _ncConn then _ncConn:Disconnect(); _ncConn=nil end
				for p2,orig in pairs(_ncParts) do
					pcall(function() if p2 and p2.Parent then p2.LocalTransparencyModifier=orig end end)
				end
				_ncParts={}
			end
		end)
	end
	UIB.makeGap(4); UIB.makeSectionLabel("Cleanup")
	local cleanRow=Instance.new("TextButton",currentPage)
	cleanRow.Size=UDim2.new(1,0,0,30); cleanRow.BackgroundColor3=C_ROW; cleanRow.BackgroundTransparency=0.35
	cleanRow.BorderSizePixel=0; cleanRow.LayoutOrder=LO(); addCorner(cleanRow,6); addLivingStroke(cleanRow,1)
	cleanRow.Text="Clean Particles & Lights"; cleanRow.TextColor3=C_WHITE; cleanRow.Font=Enum.Font.GothamBold
	cleanRow.TextSize=10; cleanRow.AutoButtonColor=false; addLivingTextGradient(cleanRow)
	cleanRow.MouseButton1Click:Connect(function()
		local n=cleanParticlesAndLights(); cleanRow.Text="Cleaned "..n.." effects"
		task.delay(1.2,function() if cleanRow and cleanRow.Parent then cleanRow.Text="Clean Particles & Lights" end end)
	end)
end)

-- ===================================================================
-- SPEED WIDGET (jxsh — Anti Bat style)
-- ===================================================================
local function _buildSpeedWidget()
local spW=Instance.new("Frame",gui)
spW.Name="SpeedWidget"; spW.Size=UDim2.new(0,150,0,160); _GH.spW=spW
spW.Position=UDim2.new(1,-256,0,210); spW.BackgroundColor3=C_BG
spW.BorderSizePixel=0; spW.ClipsDescendants=true; spW.Active=true; spW.Visible=false
addCorner(spW,12); addLivingStroke(spW,1.5)
local spH=Instance.new("Frame",spW)
spH.Size=UDim2.new(1,0,0,26); spH.BackgroundColor3=C_HEADER; spH.BorderSizePixel=0
addCorner(spH,12); makeDraggable(spW, spH, "speed")
local spDot=Instance.new("Frame",spH)
spDot.Size=UDim2.new(0,5,0,5); spDot.Position=UDim2.new(0,10,0,11)
spDot.BackgroundColor3=C_MOON; spDot.BorderSizePixel=0; addCorner(spDot,3)
local spTitleLbl=Instance.new("TextLabel",spH)
spTitleLbl.Size=UDim2.new(1,-46,1,0); spTitleLbl.Position=UDim2.new(0,16,0,0)
spTitleLbl.BackgroundTransparency=1; spTitleLbl.Text="SPEED BOOSTER"
spTitleLbl.TextColor3=C_WHITE; spTitleLbl.Font=Enum.Font.GothamBlack; spTitleLbl.TextSize=9
spTitleLbl.TextXAlignment=Enum.TextXAlignment.Left; addLivingTextGradient(spTitleLbl)
-- Minimize button: collapsed by default = expanded (Normal/Lagger visible),
-- the user can click "-" to collapse it if they want
local spCollapsedH=64
local spMinBtn=Instance.new("TextButton",spH)
spMinBtn.Size=UDim2.new(0,18,0,18); spMinBtn.Position=UDim2.new(1,-24,0.5,-9)
spMinBtn.BackgroundColor3=Color3.fromRGB(30,30,34); spMinBtn.BorderSizePixel=0
spMinBtn.Text="-"; spMinBtn.TextColor3=C_WHITE; spMinBtn.Font=Enum.Font.GothamBlack; spMinBtn.TextSize=15
addCorner(spMinBtn,6); addLivingStroke(spMinBtn,1)
-- The click is connected further down (after stRow/spNorm/spLag/_spLagger)
-- to keep NORMAL/LAGGER visible and usable even when collapsed.
-- NORMAL / LAGGER Tabs
local tabRow=Instance.new("Frame",spW)
tabRow.Size=UDim2.new(1,-16,0,26); tabRow.Position=UDim2.new(0,8,0,32)
tabRow.BackgroundColor3=C_ROW; tabRow.BackgroundTransparency=0.35
tabRow.BorderSizePixel=0; addCorner(tabRow,8); addLivingStroke(tabRow,1)
local tabLL=Instance.new("UIListLayout",tabRow)
tabLL.FillDirection=Enum.FillDirection.Horizontal; tabLL.SortOrder=Enum.SortOrder.LayoutOrder
tabLL.HorizontalAlignment=Enum.HorizontalAlignment.Center
tabLL.Padding=UDim.new(0,0)
local function mkTab(lbl,ord,act)
	local t=Instance.new("TextButton",tabRow); t.Size=UDim2.new(0.5,0,1,0); t.AnchorPoint=Vector2.new(0,0)
	t.BorderSizePixel=0; t.LayoutOrder=ord
	t.BackgroundColor3=act and C_MOON or C_OFF_BG
	t.BackgroundTransparency=act and 0.15 or 0.5
	t.Text=lbl; t.TextColor3=act and C_MOONTEXT or C_DIM
	t.Font=Enum.Font.GothamBold; t.TextSize=10; t.AutoButtonColor=false
	addCorner(t,6); addLivingTextGradient(t); return t
end
local spTabN=mkTab("NORMAL",1,true); local spTabL=mkTab("LAGGER",2,false)
-- Status ON/OFF
local stRow=Instance.new("Frame",spW)
stRow.Size=UDim2.new(1,-16,0,26); stRow.Position=UDim2.new(0,8,0,64)
stRow.BackgroundColor3=C_ROW; stRow.BackgroundTransparency=0.35
stRow.BorderSizePixel=0; addCorner(stRow,8); addLivingStroke(stRow,1)
local stLbl=Instance.new("TextLabel",stRow)
stLbl.Size=UDim2.new(0.5,0,1,0); stLbl.Position=UDim2.new(0,12,0,0)
stLbl.BackgroundTransparency=1; stLbl.Text="Status:"
stLbl.TextColor3=C_WHITE; stLbl.Font=Enum.Font.GothamBold; stLbl.TextSize=11
stLbl.TextXAlignment=Enum.TextXAlignment.Left; addLivingTextGradient(stLbl)
local stPill=Instance.new("Frame",stRow)
stPill.Size=UDim2.new(0.44,0,0,22); stPill.Position=UDim2.new(0.54,0,0.5,-11)
stPill.BackgroundColor3=C_OFF_BG; stPill.BorderSizePixel=0; addCorner(stPill,6); addLivingStroke(stPill,1)
local stPillLbl=Instance.new("TextLabel",stPill)
stPillLbl.Size=UDim2.new(1,0,1,0); stPillLbl.BackgroundTransparency=1
stPillLbl.Text="OFF"; stPillLbl.TextColor3=C_DIM
stPillLbl.Font=Enum.Font.GothamBlack; stPillLbl.TextSize=11; addLivingTextGradient(stPillLbl)
local stClk=Instance.new("TextButton",stRow)
stClk.Size=UDim2.new(1,0,1,0); stClk.BackgroundTransparency=1; stClk.Text=""
-- Input helper
_G._mhInputBoxesRef = _G._mhInputBoxesRef or {}
local _mhInputBoxes = _G._mhInputBoxesRef
local function mkInput(parent,yPos,lbl,val,cb,stateKey)
	local row=Instance.new("Frame",parent)
	row.Size=UDim2.new(1,-16,0,28); row.Position=UDim2.new(0,8,0,yPos)
	row.BackgroundColor3=C_ROW; row.BackgroundTransparency=0.35
	row.BorderSizePixel=0; addCorner(row,8); addLivingStroke(row,1)
	local l=Instance.new("TextLabel",row)
	l.Size=UDim2.new(1,-80,1,0); l.Position=UDim2.new(0,12,0,0)
	l.BackgroundTransparency=1; l.Text=lbl; l.TextColor3=C_WHITE
	l.Font=Enum.Font.GothamBold; l.TextSize=11; l.TextXAlignment=Enum.TextXAlignment.Left
	addLivingTextGradient(l)
	local bw=Instance.new("Frame",row)
	bw.Size=UDim2.new(0,62,0,22); bw.Position=UDim2.new(1,-70,0.5,-11)
	bw.BackgroundColor3=C_OFF_BG; bw.BackgroundTransparency=0.1
	bw.BorderSizePixel=0; addCorner(bw,6); addLivingStroke(bw,1)
	local box=Instance.new("TextBox",bw)
	box.Size=UDim2.new(1,-6,1,0); box.Position=UDim2.new(0,3,0,0)
	box.BackgroundTransparency=1; box.Text=tostring(val)
	box.TextColor3=C_SILVER; box.Font=Enum.Font.GothamBold; box.TextSize=12
	box.ClearTextOnFocus=false; box.TextXAlignment=Enum.TextXAlignment.Center
	box.FocusLost:Connect(function()
		local n=tonumber(box.Text)
		if n and n>0 and n<=500 then
			cb(n)
			if _GH.autoSave then _GH.autoSave() end
		else box.Text=tostring(val) end
	end)
	if stateKey then _mhInputBoxes[stateKey] = box end
end
-- Normal / Lagger panels
local spNorm=Instance.new("Frame",spW)
spNorm.Size=UDim2.new(1,0,0,68); spNorm.Position=UDim2.new(0,0,0,96)
spNorm.BackgroundTransparency=1; spNorm.BorderSizePixel=0
mkInput(spNorm,0,  "Speed",     State.normalSpeed,     function(n) State.normalSpeed=n end, "normalSpeed")
mkInput(spNorm,40, "Steal Spd", State.carrySpeed,      function(n) State.carrySpeed=n end, "carrySpeed")
local spLag=Instance.new("Frame",spW)
spLag.Size=UDim2.new(1,0,0,68); spLag.Position=UDim2.new(0,0,0,96)
spLag.BackgroundTransparency=1; spLag.BorderSizePixel=0; spLag.Visible=false
mkInput(spLag,0,  "Lagger",    State.laggerSpeed,     function(n) State.laggerSpeed=n end, "laggerSpeed")
mkInput(spLag,40, "Lag Steal", State.laggerCarrySpeed, function(n) State.laggerCarrySpeed=n end, "laggerCarrySpeed")
-- Exact jxsh logic — uses proxyMove + State like the hub
local _spActive=false; local _spLagger=false
local function startSp()
	_speedBoosterActive = true
	-- Activates lagger or normal mode via State (proxyMove uses it automatically)
	if _spLagger then
		State.laggerActive=true; State.laggerCarryActive=false
	else
		State.laggerActive=false; State.laggerCarryActive=false
		State.speedType="normal"
	end
end
local function stopSp()
	_speedBoosterActive = false
	-- Disables everything and stops the proxy
	State.laggerActive=false; State.laggerCarryActive=false
	State.speedType="normal"
	proxyStop()
end
local function toggleSp()
	_spActive=not _spActive
	stPill.BackgroundColor3=_spActive and C_MOON or C_OFF_BG
	stPillLbl.Text=_spActive and "ON" or "OFF"
	stPillLbl.TextColor3=_spActive and C_MOONTEXT or C_DIM
	if _spActive then startSp() else stopSp() end
	if _GH.setSpeedBoosterFloatVisual then _GH.setSpeedBoosterFloatVisual(_spActive) end
end
stClk.MouseButton1Click:Connect(toggleSp)
_GH.speedBoosterToggle = toggleSp
_GH.speedBoosterIsActive = function() return _spActive end
local function switchTab(lag)
	_spLagger=lag
	if _spActive then startSp() end
	spTabN.BackgroundColor3=lag and C_OFF_BG or C_MOON
	spTabN.BackgroundTransparency=lag and 0.5 or 0.15
	spTabN.TextColor3=lag and C_DIM or C_MOONTEXT
	spTabL.BackgroundColor3=lag and C_MOON or C_OFF_BG
	spTabL.BackgroundTransparency=lag and 0.15 or 0.5
	spTabL.TextColor3=lag and C_MOONTEXT or C_DIM
	spNorm.Visible=not lag; spLag.Visible=lag
end
spTabN.MouseButton1Click:Connect(function() switchTab(false) end)
spTabL.MouseButton1Click:Connect(function() switchTab(true) end)
-- Exposed so the "Lag Normal" keybind can actually flip the widget into
-- Lagger mode (updates State + the widget's own tabs, and re-applies live
-- if the booster is already running) instead of poking State directly.
_GH.speedBoosterSwitchTab = switchTab
_GH.speedBoosterIsLagger  = function() return _spLagger end

-- Collapsed ("-"): NORMAL/LAGGER stay visible and usable, only
-- Status and the speed fields are hidden.
spMinBtn.MouseButton1Click:Connect(function()
	_spCollapsed = not _spCollapsed
	if _spCollapsed then
		spW.Size=UDim2.new(0,_spExpandedSize.w,0,spCollapsedH)
	else
		-- Restores the size edited via the Scale slider (Visual), not a
		-- hardcoded default size.
		spW.Size=UDim2.new(0,_spExpandedSize.w,0,_spExpandedSize.h)
	end
	spMinBtn.Text=_spCollapsed and "+" or "-"
	stRow.Visible = not _spCollapsed
	if _spCollapsed then
		spNorm.Visible=false; spLag.Visible=false
	else
		spNorm.Visible = not _spLagger; spLag.Visible = _spLagger
	end
end)

-- Scale slider (same style as UIScale in Visual)

end
_buildSpeedWidget()

-- ===================================================================
-- STEAL BAR WIDGET
-- ===================================================================
do
local stealWidget=Instance.new("Frame",gui)
stealWidget.Name="StealBarWidget"; stealWidget.Size=UDim2.new(0,200,0,32)
stealWidget.Position=UDim2.new(0.5,-100,0,35); stealWidget.BackgroundTransparency=1; stealWidget.Active=true
makeDraggable(stealWidget, nil, "steal")
local stealPill=Instance.new("Frame",stealWidget)
stealPill.Size=UDim2.new(1,0,0,32); stealPill.BackgroundColor3=C_BG
stealPill.BackgroundTransparency=0.1; stealPill.BorderSizePixel=0; stealPill.ClipsDescendants=true
addCorner(stealPill,18)
local stealPillStk=addStroke(stealPill,C_MOON,1.5,0.2)
local stealPulseSpeed=1.2
AutoSteal.SetFastPulse=function(on) stealPulseSpeed=on and 0.35 or 1.2 end
task.spawn(function()
	while stealPill.Parent do
		TweenService:Create(stealPillStk,TweenInfo.new(stealPulseSpeed,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=0.6}):Play()
		task.wait(stealPulseSpeed)
		TweenService:Create(stealPillStk,TweenInfo.new(stealPulseSpeed,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=0.1}):Play()
		task.wait(stealPulseSpeed)
	end
end)
AutoSteal.FlashSuccess=function()
	TweenService:Create(stealPillStk,TweenInfo.new(0.08),{Color=C_WHITE,Transparency=0}):Play()
	TweenService:Create(stealPill,TweenInfo.new(0.08),{BackgroundTransparency=0}):Play()
	task.delay(0.08,function()
		TweenService:Create(stealPillStk,TweenInfo.new(0.35),{Color=C_MOON,Transparency=0.1}):Play()
		TweenService:Create(stealPill,TweenInfo.new(0.35),{BackgroundTransparency=0.1}):Play()
	end)
end
local stealLeftHalf=Instance.new("Frame",stealPill)
stealLeftHalf.Size=UDim2.new(0.56,0,1,0); stealLeftHalf.BackgroundTransparency=1; stealLeftHalf.ZIndex=6
local stealLabel=Instance.new("TextLabel",stealLeftHalf)
stealLabel.Size=UDim2.new(1,-20,1,0); stealLabel.Position=UDim2.new(0,12,0,0)
stealLabel.BackgroundTransparency=1; stealLabel.Text="READY"
stealLabel.TextColor3=C_WHITE; stealLabel.Font=Enum.Font.GothamBlack; stealLabel.TextSize=11
stealLabel.TextXAlignment=Enum.TextXAlignment.Left; stealLabel.ZIndex=6; addLivingTextGradient(stealLabel)
local stealDivider=Instance.new("Frame",stealPill)
stealDivider.Size=UDim2.new(0,1,0,18); stealDivider.Position=UDim2.new(0.56,0,0.5,-9)
stealDivider.BackgroundColor3=C_SILVER2; stealDivider.BackgroundTransparency=0.4; stealDivider.BorderSizePixel=0; stealDivider.ZIndex=6
local infoLabel=Instance.new("TextLabel",stealPill)
infoLabel.Size=UDim2.new(0.44,-12,1,0); infoLabel.Position=UDim2.new(0.56,12,0,0)
infoLabel.BackgroundTransparency=1; infoLabel.Text="0 FPS | --ms"
infoLabel.TextColor3=C_WHITE; infoLabel.Font=Enum.Font.GothamBold; infoLabel.TextSize=11
infoLabel.TextXAlignment=Enum.TextXAlignment.Left; infoLabel.ZIndex=6
local stealFill=Instance.new("Frame",stealPill)
stealFill.Size=UDim2.new(0,0,1,0); stealFill.BackgroundColor3=C_MOON
stealFill.BackgroundTransparency=0.72; stealFill.BorderSizePixel=0; stealFill.ZIndex=1
addCorner(stealFill,18)
local stealFillGrad=Instance.new("UIGradient",stealFill)
stealFillGrad.Color=ColorSequence.new({
	ColorSequenceKeypoint.new(0,Color3.fromRGB(10,50,68)),
	ColorSequenceKeypoint.new(0.85,C_MOON),
	ColorSequenceKeypoint.new(1,C_SILVER),
})
local stealEdge=Instance.new("Frame",stealFill)
stealEdge.AnchorPoint=Vector2.new(1,0.5); stealEdge.Size=UDim2.new(0,4,1,-6); stealEdge.Position=UDim2.new(1,0,0.5,0)
stealEdge.BackgroundColor3=C_WHITE; stealEdge.BorderSizePixel=0; stealEdge.ZIndex=2; addCorner(stealEdge,2)
local stealPctLbl=Instance.new("TextLabel",stealLeftHalf)
stealPctLbl.Size=UDim2.new(1,-32,1,0); stealPctLbl.Position=UDim2.new(0,12,0,0)
stealPctLbl.BackgroundTransparency=1; stealPctLbl.Text=""
stealPctLbl.TextColor3=C_MOON2; stealPctLbl.Font=Enum.Font.GothamBlack; stealPctLbl.TextSize=11
stealPctLbl.TextXAlignment=Enum.TextXAlignment.Right; stealPctLbl.ZIndex=6
AutoSteal.ProgressFill=stealFill; AutoSteal.ProgressText=stealPctLbl; AutoSteal.Widget=stealWidget; AutoSteal.StatusLabel=stealLabel
task.spawn(function() task.wait(0.6); if AutoSteal.SetReadyColor then AutoSteal.SetReadyColor("READY") end end)
local _lastReadyState = "READY"
local function _setReadyColor(state)
	if state then _lastReadyState = state end
	local lbl = AutoSteal.StatusLabel; if not lbl then return end
	local isReady = (_lastReadyState == "READY")
	lbl.TextColor3 = isReady and C_MOON or C_RED
	local g = lbl:FindFirstChildOfClass("UIGradient")
	if g then
		-- Utilise C_ON_BG + C_MOON → suit le thème (bleu default, gris noir)
		local c1 = isReady and C_ON_BG or Color3.fromRGB(120,20,20)
		local c2 = isReady and C_MOON  or Color3.fromRGB(255,100,100)
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,    c2),
			ColorSequenceKeypoint.new(0.25, c1),
			ColorSequenceKeypoint.new(0.5,  c2),
			ColorSequenceKeypoint.new(0.75, c1),
			ColorSequenceKeypoint.new(1,    c2),
		})
	end
end
AutoSteal.SetReadyColor = _setReadyColor
-- Re-applique la couleur à chaque changement de thème
_GH.stealReadyColorFn = function() _setReadyColor(nil) end
local Stats=game:GetService("Stats")
local frameCount,lastFpsTime,lastFps,lastPing=0,tick(),60,nil
local function refreshInfoLabel()
	infoLabel.Text = lastFps.." FPS | "..(lastPing and (lastPing.."ms") or "--ms")
end
RunService.RenderStepped:Connect(function()
	frameCount=frameCount+1; local now=tick()
	if now-lastFpsTime>=1 then
		lastFps=math.floor(frameCount/(now-lastFpsTime)); frameCount=0; lastFpsTime=now; refreshInfoLabel()
	end
end)
-- Only update lastPing if the fetch succeeded, otherwise keep the
-- last known value instead of falling back to 0 (bug: display stuck at "0ms").
task.spawn(function()
	while stealWidget.Parent do
		local success, ping = pcall(function()
			local netStats = Stats:FindFirstChild("Network")
			if not netStats then return nil end
			local sci = netStats:FindFirstChild("ServerStatsItem")
			if not sci then return nil end
			local dp = sci:FindFirstChild("Data Ping")
			if not dp then return nil end
			return math.floor(dp:GetValue() or 0)
		end)
		if success and type(ping) == "number" then
			lastPing = ping
			refreshInfoLabel()
		end
		task.wait(0.5)
	end
end)
end

-- ===================================================================
-- FLOATING BUTTONS — replaces the fixed Quick Panel + attach/detach.
-- Each action has a toggle in Settings that spawns/despawns its
-- own floating square button. "Lock" freezes the drag once placed.
-- ===================================================================
-- Grid order + position formula (_FLOAT_GRID_ORDER / _floatGridIndex /
-- _floatGridPos) live earlier in the file, before buildPage("Visual",...),
-- so the "Button Size" slider can share this exact math.

local function makeFloatButton(id)
	if _floatBtns[id] then return _floatBtns[id] end
	local def = _floatDefs[id]; if not def then return nil end

	local btn = Instance.new("TextButton", gui)
	btn.Name = "Float_"..id
	local saved = _floatPositions[id]
	btn.Size = UDim2.new(0, FLOAT_SZ, 0, FLOAT_SZ)
	btn.Position = saved and UDim2.new(saved[1], saved[2], saved[3], saved[4]) or _floatGridPos(id, FLOAT_SZ)
	btn.BackgroundColor3 = C_ROW; btn.BackgroundTransparency = 0; btn.BorderSizePixel = 0
	btn.Text = def.label; btn.TextColor3 = C_WHITE; btn.Font = Enum.Font.GothamBold
	btn.TextScaled = false; btn.TextSize = 9; btn.TextWrapped = true; btn.AutoButtonColor = false
	btn.ZIndex = 500; btn.Active = true
	addCorner(btn, 14); addLivingStroke(btn, 1); addLivingTextGradient(btn)
	local pad = Instance.new("UIPadding", btn)
	pad.PaddingLeft = UDim.new(0,4); pad.PaddingRight = UDim.new(0,4)
	pad.PaddingTop = UDim.new(0,3); pad.PaddingBottom = UDim.new(0,3)

	local function setActive(on)
		btn.BackgroundColor3 = on and C_ON_BG or C_ROW
		TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
	end

	-- Drag (disabled when locked). When "Move Together" is on (Settings),
	-- dragging any one spawned button carries every other spawned one along
	-- by the same delta — a snapshot of everyone's start position is taken
	-- once, and each frame every button is placed at its own snapshot + d.
	local drag, ds, dp = false, nil, nil
	btn.InputBegan:Connect(function(inp)
		if _floatLocked then return end
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			drag = true; ds = inp.Position; dp = btn.Position
			if _floatLinkMove then
				_linkDragSnapshot = {}
				for lid, lentry in pairs(_floatBtns) do
					if lentry.frame and lentry.frame.Parent then
						_linkDragSnapshot[lid] = lentry.frame.Position
					end
				end
			end
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then
					drag = false
					local p2 = btn.Position
					_floatPositions[id] = {p2.X.Scale, p2.X.Offset, p2.Y.Scale, p2.Y.Offset}
					if _linkDragSnapshot then
						for lid, lentry in pairs(_floatBtns) do
							if lentry.frame and lentry.frame.Parent then
								local lp = lentry.frame.Position
								_floatPositions[lid] = {lp.X.Scale, lp.X.Offset, lp.Y.Scale, lp.Y.Offset}
							end
						end
						_linkDragSnapshot = nil
					end
					if _GH.autoSave then _GH.autoSave() end
				end
			end)
		end
	end)
	btn.InputChanged:Connect(function(inp)
		if _floatLocked or not drag or not ds then return end
		if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
			local d = inp.Position - ds
			btn.Position = UDim2.new(dp.X.Scale, dp.X.Offset + d.X, dp.Y.Scale, dp.Y.Offset + d.Y)
			if _linkDragSnapshot then
				for lid, lentry in pairs(_floatBtns) do
					if lid ~= id and lentry.frame and lentry.frame.Parent then
						local sp = _linkDragSnapshot[lid]
						if sp then
							lentry.frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
						end
					end
				end
			end
		end
	end)

	btn.MouseButton1Click:Connect(function()
		if def.onClick then def.onClick() end
		if def.momentary then
			setActive(true)
			task.delay(0.2, function() setActive(false) end)
		elseif def.isActive then
			setActive(def.isActive())
		end
	end)

	_floatBtns[id] = {frame = btn, setActive = setActive}
	if def.isActive then setActive(def.isActive()) end
	return _floatBtns[id]
end

local function removeFloatButton(id)
	local entry = _floatBtns[id]
	if entry then entry.frame:Destroy(); _floatBtns[id] = nil end
end

local function setFloatLocked(on)
	_floatLocked = on
end

-- Periodic visual sync (real ON/OFF state, no matter where
-- the change came from — clicking the button, a keybind, or another toggle)
task.spawn(function()
	while gui.Parent do
		for id, entry in pairs(_floatBtns) do
			local def = _floatDefs[id]
			if def and def.isActive and not def.momentary then
				entry.setActive(def.isActive())
			end
		end
		task.wait(0.3)
	end
end)

-- Force-refresh all float button background colors against current C_ON_BG.
-- Called by applyTheme and at end of MH_load so theme switches / load order
-- can never leave buttons in the wrong color.
_GH.refreshFloatActiveColors = function()
	for id, entry in pairs(_floatBtns) do
		local def = _floatDefs[id]
		if def and entry.frame and entry.frame.Parent then
			if def.isActive and not def.momentary then
				entry.setActive(def.isActive())
			else
				entry.setActive(false)
			end
		end
	end
end

-- ── Action registration ──────────────────────────────────────
_floatDefs.dropbr = {
	label = "DROP BR",
	onClick = function() runDropBrainrot() end,
	momentary = true,
}
_floatDefs.autoleft = {
	label = "AUTO\nLEFT",
	onClick = function()
		State.autoLeftEnabled = not State.autoLeftEnabled
		if State.autoLeftEnabled then startAutoLeft() else stopAutoLeft() end
	end,
	isActive = function() return State.autoLeftEnabled end,
}
_floatDefs.aimbot = {
	label = "AIM BOT",
	onClick = function()
		local on = not AB.active
		if on then if ABP.active then ABP.stop() end; AB.start() else AB.stop() end
	end,
	isActive = function() return AB.active end,
}
_floatDefs.autoright = {
	label = "AUTO\nRIGHT",
	onClick = function()
		State.autoRightEnabled = not State.autoRightEnabled
		if State.autoRightEnabled then startAutoRight() else stopAutoRight() end
	end,
	isActive = function() return State.autoRightEnabled end,
}
_floatDefs.tpdown = {
	label = "TP DOWN",
	onClick = function() tpToGround() end,
	momentary = true,
}
_floatDefs.battp = {
	label = "BAT TP",
	onClick = function()
		local on = not AimV3.active
		if on then AimV3.start() else AimV3.stop() end
	end,
	isActive = function() return AimV3.active end,
}


-- ===================================================================
-- INSTANT RESET — copie exacte de la logique Ace Duels (100%, zéro trace
-- des anciennes méthodes locales). Hookfunction capture le remote RE/,
-- fallback scan ReplicatedStorage, boucle 10x/0.05s, stop sur resetDetected.
-- ===================================================================
_G.AceCursedResetRemote = _G.AceCursedResetRemote or nil
_G.AceCursedResetGuid   = _G.AceCursedResetGuid or "f888ee6e-c86d-46e1-93d7-0639d6635d42"
pcall(function()
	if not _G.AceCursedResetHooked and hookfunction and newcclosure then
		_G.AceCursedResetHooked = true
		local oldFire
		oldFire = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
			if not _G.AceCursedResetRemote and typeof(self) == "Instance" and self:IsA("RemoteEvent") and self.Name:sub(1,3) == "RE/" then
				_G.AceCursedResetRemote = self
			end
			return oldFire(self, ...)
		end))
	end
end)
function _G.AceCursedInstaReset()
	-- The forced kill/respawn below ragdolls the character just like a real
	-- stun would, which would otherwise falsely flash the "READY!!" speed
	-- billboard into a stun countdown right after a self-reset. Suppressed
	-- for a window generous enough to cover a slow death/respawn/settle
	-- round-trip (server latency can easily eat the old 1.5s on its own,
	-- before the new character has even finished loading in).
	if _GH.setStunSuppressed then _GH.setStunSuppressed(true) end
	task.delay(3.0, function() if _GH.setStunSuppressed then _GH.setStunSuppressed(false) end end)

	if not _G.AceCursedResetRemote then
		for _, desc in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
			if desc:IsA("RemoteEvent") and desc.Name:sub(1,3) == "RE/" then
				_G.AceCursedResetRemote = desc
				break
			end
		end
	end
	if not _G.AceCursedResetRemote then return end
	local character = LP.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		pcall(function() _G.AceCursedResetRemote:FireServer(_G.AceCursedResetGuid, LP, "balloon") end)
		return
	end
	local resetDetected = false
	local resetConns = {}
	if humanoid then
		table.insert(resetConns, humanoid.Died:Connect(function() resetDetected = true end))
		table.insert(resetConns, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
			if humanoid.Health <= 0 then resetDetected = true end
		end))
	end
	if character then
		table.insert(resetConns, character.AncestryChanged:Connect(function(_, parent)
			if not parent then resetDetected = true end
		end))
	end
	task.spawn(function()
		for _ = 1, 10 do
			if resetDetected then break end
			pcall(function() _G.AceCursedResetRemote:FireServer(_G.AceCursedResetGuid, LP, "balloon") end)
			task.wait(0.05)
		end
		for _, conn in ipairs(resetConns) do pcall(function() conn:Disconnect() end) end
	end)
end

do
	_GH.MH_instareset = _G.AceCursedInstaReset

	_floatDefs.instareset = {
		label    = "INSTANT\nRESET",
		onClick  = _G.AceCursedInstaReset,
		momentary = true,
	}
end

_floatDefs.aimv2 = {
	label = "AIM V2",
	onClick = function()
		local on = not ABP.active
		if on then if AB.active then AB.stop() end; ABP.start() else ABP.stop() end
	end,
	isActive = function() return ABP.active end,
}
_GH.makeFloatButton   = makeFloatButton
_GH.removeFloatButton = removeFloatButton
_GH.setFloatLocked    = setFloatLocked
_GH.floatDefs         = _floatDefs
_GH.floatPositions    = _floatPositions

-- ===================================================================
-- STUN TIMER BILLBOARD (au-dessus du personnage)
-- STUN TIMER BILLBOARD (above the character)
-- 3 → red | 2 → yellow | 1 → cyan | 0 → "GO" green
do
	local STUN_DURATION   = 3.0
	local stunActive      = false
	local stunStartTime   = 0
	local stunConn        = nil
	local stateConn       = nil
	local lastSec         = nil
	local bbGui           = nil
	local timerLbl        = nil

	local speedLbl = nil

	-- addGreyShimmer() is a fixed grey/white gradient — fine for a one-time
	-- setup, but this billboard gets torn down and rebuilt from scratch on
	-- EVERY respawn/reset (see below), and applyTheme() only re-colors
	-- whatever label instance already exists at the moment a theme button
	-- is clicked. Net effect: die or reset even once after picking e.g.
	-- Crimson, and the freshly rebuilt "READY!!"/"Speed" labels silently
	-- fall back to grey and never regain the active theme's color until
	-- the theme is manually re-applied. This mirrors applyTheme's own
	-- noir/else branches so a fresh billboard always matches current theme.
	local function themedStunShimmer(label)
		local g = Instance.new("UIGradient", label)
		if _currentTheme == "noir" then
			g.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,    Color3.fromRGB(60,  60,  60)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(230, 230, 230)),
				ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(140, 140, 140)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1,    Color3.fromRGB(60,  60,  60)),
			})
		else
			g.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,    C_DEEP3),
				ColorSequenceKeypoint.new(0.25, C_DEEP4),
				ColorSequenceKeypoint.new(0.5,  C_DEEP3),
				ColorSequenceKeypoint.new(0.75, C_DEEP4),
				ColorSequenceKeypoint.new(1,    C_DEEP3),
			})
		end
		g.Rotation = 0
		table.insert(_livingGradients, g)
		return g
	end

	local function createBB()
		if bbGui then return end
		local char = LP.Character; if not char then return end
		local head = char:FindFirstChild("Head"); if not head then return end
		bbGui = Instance.new("BillboardGui", head)
		bbGui.Name = _NS
		bbGui.Size = UDim2.new(0,130,0,52)
		bbGui.StudsOffset = Vector3.new(0,3.5,0)
		bbGui.AlwaysOnTop = true
		-- "speed" label (above)
		speedLbl = Instance.new("TextLabel", bbGui)
		speedLbl.Size = UDim2.new(1,0,0,26)
		speedLbl.Position = UDim2.new(0,0,0,0)
		speedLbl.BackgroundTransparency = 1
		speedLbl.Text = "Speed: 0"
		speedLbl.TextColor3 = Color3.new(1,1,1)
		speedLbl.TextScaled = false
		speedLbl.TextSize = 19
		speedLbl.Font = Enum.Font.GothamBlack
		speedLbl.TextStrokeTransparency = 1
		speedLbl.TextXAlignment = Enum.TextXAlignment.Center
		themedStunShimmer(speedLbl)
		-- READY!! / timer label (below)
		timerLbl = Instance.new("TextLabel", bbGui)
		timerLbl.Size = UDim2.new(1,0,0,28)
		timerLbl.Position = UDim2.new(0,0,0,24)
		timerLbl.BackgroundTransparency = 1
		timerLbl.Text = "READY!!"
		timerLbl.TextColor3 = Color3.new(1,1,1)
		timerLbl.TextScaled = true
		timerLbl.Font = Enum.Font.GothamBlack
		timerLbl.TextStrokeTransparency = 1
		themedStunShimmer(timerLbl)
		_GH.speedLblRef = speedLbl
		_GH.timerLblRef = timerLbl
	end

	local function updateDisplay()
		if not timerLbl then createBB(); if not timerLbl then return end end
		if not stunActive then
			timerLbl.Text = "READY!!"
			timerLbl.TextColor3 = Color3.new(1,1,1)
			return
		end
		local rem = math.max(0, STUN_DURATION-(tick()-stunStartTime))
		if rem <= 0 then
			stunActive = false
			if stunConn then stunConn:Disconnect(); stunConn = nil end
			timerLbl.Text = "READY!!"
			timerLbl.TextColor3 = Color3.new(1,1,1)
			return
		end
		local sec = math.ceil(rem)
		if sec ~= lastSec then
			lastSec = sec
			timerLbl.Text = tostring(sec)
			if     sec == 3 then timerLbl.TextColor3 = C_RED
			elseif sec == 2 then timerLbl.TextColor3 = C_SILVER
			elseif sec == 1 then timerLbl.TextColor3 = C_MOON2
			end
		end
	end

	-- Suppressed right after an Instant Reset: the forced kill/respawn
	-- ragdolls the character exactly like a real stun would, which was
	-- falsely flashing "READY!!" into a stun countdown (and its red/silver/
	-- moon2 colors) even though nobody actually hit the player.
	local _stunSuppressed = false
	_GH.setStunSuppressed = function(on)
		_stunSuppressed = on
		-- Suppressing only ever blocked a NEW stun countdown from starting.
		-- The common real case is pressing Instant Reset WHILE already
		-- stunned (that's usually exactly why it gets pressed) — the
		-- countdown was already running before suppression turned on, so
		-- it kept cycling its red/silver/moon2 colors underneath the
		-- suppression window regardless. Force it back to READY right now
		-- too, or the "wrong color after reset" symptom never actually
		-- goes away for that (very common) case.
		if on and stunActive then
			stunActive = false
			if stunConn then stunConn:Disconnect(); stunConn = nil end
			if timerLbl then
				timerLbl.Text = "READY!!"
				timerLbl.TextColor3 = Color3.new(1,1,1)
			end
		end
	end

	local function onStun()
		if stunActive or _stunSuppressed then return end
		stunActive = true; stunStartTime = tick(); lastSec = nil
		createBB(); updateDisplay()
		if stunConn then stunConn:Disconnect() end
		stunConn = RunService.Heartbeat:Connect(updateDisplay)
	end

	local function setupDetection(char)
		if stateConn then stateConn:Disconnect() end
		local hum = char and char:FindFirstChildOfClass("Humanoid"); if not hum then return end
		stateConn = hum.StateChanged:Connect(function(_, ns)
			if ns==Enum.HumanoidStateType.Physics or ns==Enum.HumanoidStateType.Ragdoll
				or ns==Enum.HumanoidStateType.FallingDown or ns==Enum.HumanoidStateType.GettingUp then
				onStun()
			end
		end)
	end

	LP.CharacterAdded:Connect(function(char)
		if bbGui then pcall(function() bbGui:Destroy() end); bbGui=nil; timerLbl=nil; speedLbl=nil end
		task.wait(0.2); createBB(); setupDetection(char)
	end)
	if LP.Character then task.wait(0.1); createBB(); setupDetection(LP.Character) end

	-- Speed update — delta position/time calculation (real measured speed, not the property)
	local _lastPos, _lastT = nil, tick()
	RunService.RenderStepped:Connect(function()
		if not speedLbl or not speedLbl.Parent then return end
		local char = LP.Character; if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
		local now = tick()
		local pos = Vector3.new(root.Position.X, 0, root.Position.Z)
		if _lastPos then
			local dt = now - _lastT
			if dt > 0 then
				local dist = (pos - _lastPos).Magnitude
				local spd = dist / dt
				speedLbl.Text = string.format("Speed: %.1f", spd)
			end
		end
		_lastPos, _lastT = pos, now
	end)

	-- Other players' speed (billboard above their head)
	-- Other players' speed — a single global Heartbeat
	local _playerSpeedBBs = {}  -- plr → {bb, lbl, char}
	_GH.playerSpeedBBs = _playerSpeedBBs

	local function setupPlayerSpeedBB(plr)
		if plr == LP then return end
		local function attachBB(char)
			if _playerSpeedBBs[plr] then
				pcall(function() _playerSpeedBBs[plr].bb:Destroy() end)
			end
			local head = char:WaitForChild("Head", 5); if not head then return end
			local bb = Instance.new("BillboardGui", head)
			bb.Name = "MoonSpeedBB"; bb.Size = UDim2.new(0,110,0,22)
			bb.StudsOffset = Vector3.new(0,2.2,0); bb.AlwaysOnTop = true
			local lbl = Instance.new("TextLabel", bb)
			lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
			lbl.Text = "0"; lbl.TextColor3 = C_MOON2
			lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBlack
			lbl.TextStrokeTransparency = 0.35
			lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
			addLivingTextGradient(lbl)
			_playerSpeedBBs[plr] = {bb=bb, lbl=lbl, char=char}
		end
		if plr.Character then task.spawn(function() attachBB(plr.Character) end) end
		plr.CharacterAdded:Connect(function(char) task.spawn(function() attachBB(char) end) end)
	end

	-- A single Heartbeat for all players — delta position/time
	RunService.Heartbeat:Connect(function()
		local now = tick()
		for plr, data in pairs(_playerSpeedBBs) do
			if not data.lbl.Parent then
				_playerSpeedBBs[plr] = nil
			else
				local root = data.char:FindFirstChild("HumanoidRootPart")
				if root then
					local pos = Vector3.new(root.Position.X, 0, root.Position.Z)
					if data._lastPos then
						local dt = now - (data._lastT or now)
						if dt > 0 then
							local dist = (pos - data._lastPos).Magnitude
							local spd2 = dist / dt
							if spd2 < 800 then
								data.lbl.Text = string.format("%.1f", spd2)
							end
						end
					end
					data._lastPos, data._lastT = pos, now
				end
			end
		end
	end)

	for _, plr in ipairs(Players:GetPlayers()) do setupPlayerSpeedBB(plr) end
	Players.PlayerAdded:Connect(setupPlayerSpeedBB)
	Players.PlayerRemoving:Connect(function(plr)
		if _playerSpeedBBs[plr] then
			pcall(function() _playerSpeedBBs[plr].bb:Destroy() end)
			_playerSpeedBBs[plr] = nil
		end
	end)
end

-- ===================================================================
-- AUTO-SAVE SYSTEM (debounce + full states, raw__72_ style)
-- ===================================================================
local HS      = game:GetService("HttpService")
local MH_FILE = "rbxdata_mhv3x_" .. tostring(LP.UserId) .. ".json"
local _saveDebounce = false
local function ks(e)
	return {
		key = e and e.key and tostring(e.key):gsub("Enum.KeyCode.","") or nil,
		gp  = e and e.gp  and tostring(e.gp):gsub("Enum.KeyCode.","")  or nil,
	}
end

-- Deferred save (0.5s) to batch fast successive changes
-- Uses task.spawn + task.wait instead of task.delay (better executor compatibility)
local function MH_save()
	if _saveDebounce then return end
	_saveDebounce = true
	task.spawn(function()
		task.wait(0.5)
		local ok = pcall(function()
			local kb = _GH.MH_KB or {}
			local data = {
				normalSpeed      = State.normalSpeed,
				carrySpeed       = State.carrySpeed,
				laggerSpeed      = State.laggerSpeed,
				laggerCarrySpeed = State.laggerCarrySpeed,
				speedType        = State.speedType,
				laggerActive     = State.laggerActive,
				laggerCarryActive= State.laggerCarryActive,
				autoLeftEnabled  = State.autoLeftEnabled,
				autoRightEnabled = State.autoRightEnabled,
				antiRagdollEnabled  = State.antiRagdollEnabled,
				medusaCounterEnabled= State.medusaCounterEnabled,
				batCounterEnabled= BatCounter and BatCounter.active or false,
				aimbotEnabled    = AB and AB.active or false,
				aimbotV2Enabled  = ABP and ABP.active or false,
				aimSpeed         = AB and AB.SPEED or nil,
				infJumpEnabled   = IJ and IJ.active or false,
				autoGrabEnabled  = AutoSteal and AutoSteal.Enabled or false,
				grabRadius       = AutoSteal and AutoSteal.Radius or nil,
				floatSpawned = (function()
					local ids = {}
					for id in pairs(_floatBtns) do ids[#ids+1] = id end
					return ids
				end)(),
				floatPositions = _floatPositions,
				floatPosV = _FLOAT_POS_VERSION,
				uiLocked = _uiLocked,
				theme             = _currentTheme,
				autoPlayMode      = State.autoPlayMode,
				uiScaleVal        = _GH.getUIScale and _GH.getUIScale() or nil,
				positions = (function()
					local t = {}
					for id, frame in pairs(_GH.positions or {}) do
						if frame and frame.Parent then
							local p = frame.Position
							t[id] = {p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset}
						end
					end
					return t
				end)(),
				toggles = (function()
					local t = {}
					for key, entry in pairs(_GH.allToggles or {}) do
						t[key] = entry.get()
					end
					return t
				end)(),
				inputs = (function()
					local t = {}
					for key, entry in pairs(_GH.allInputs or {}) do
						local n = tonumber(entry.box.Text)
						if n then t[key] = n end
					end
					return t
				end)(),
				kb = {
					DropBR        = ks(kb.DropBR),
					AutoLeft      = ks(kb.AutoLeft),
					AimBot        = ks(kb.AimBot),
					AutoRight     = ks(kb.AutoRight),
					TPDown        = ks(kb.TPDown),
					LagNorm       = ks(kb.LagNorm),
					BatTP         = ks(kb.BatTP),
					AimV2         = ks(kb.AimV2),
					AimV3Kb       = ks(kb.AimV3Kb),
					InstantReset  = ks(kb.InstantReset),
					HideUI        = ks(kb.HideUI),
				},
			}
			if writefile then
				writefile(MH_FILE, HS:JSONEncode(data))
			else
				warn("[H] writefile unavailable — executor does not support saving")
			end
		end)
		if not ok then warn("[H] MH_save error — missing modules?") end
		_saveDebounce = false
	end)
end
_GH.autoSave = MH_save

-- Loading: pushes values straight into State, the widgets, AND restarts active modules
local function MH_load()
	local ok, data = pcall(function()
		if type(readfile) ~= "function" then warn("[MoonHub] readfile missing on this executor"); return nil end
		if type(isfile) ~= "function" then warn("[MoonHub] isfile missing on this executor"); return nil end
		local fileExists = false
		local fOk, fErr = pcall(function() fileExists = isfile(MH_FILE) end)
		if not fOk then warn("[MoonHub] isfile raised an error: "..tostring(fErr)); return nil end
		if not fileExists then return nil end
		local rOk, rContent = pcall(function() return readfile(MH_FILE) end)
		if not rOk then warn("[MoonHub] readfile raised an error: "..tostring(rContent)); return nil end
		local dOk, decoded = pcall(function() return HS:JSONDecode(rContent) end)
		if not dOk then warn("[MoonHub] JSONDecode failed: "..tostring(decoded)); return nil end
		return decoded
	end)
	if not ok or not data then
		return false
	end
	local loadOk = pcall(function()
		if data.normalSpeed then State.normalSpeed=data.normalSpeed
			if _G._mhInputBoxesRef.normalSpeed then _G._mhInputBoxesRef.normalSpeed.Text=tostring(data.normalSpeed) end end
		if data.carrySpeed then State.carrySpeed=data.carrySpeed
			if _G._mhInputBoxesRef.carrySpeed then _G._mhInputBoxesRef.carrySpeed.Text=tostring(data.carrySpeed) end end
		if data.laggerSpeed then State.laggerSpeed=data.laggerSpeed
			if _G._mhInputBoxesRef.laggerSpeed then _G._mhInputBoxesRef.laggerSpeed.Text=tostring(data.laggerSpeed) end end
		if data.laggerCarrySpeed then State.laggerCarrySpeed=data.laggerCarrySpeed
			if _G._mhInputBoxesRef.laggerCarrySpeed then _G._mhInputBoxesRef.laggerCarrySpeed.Text=tostring(data.laggerCarrySpeed) end end
		if data.speedType=="normal" or data.speedType=="carry" then State.speedType=data.speedType end

		-- Only config VALUES are restored here (speeds, keybinds, radius,
		-- mode...) — ON/OFF feature states are never auto-restarted, to
		-- match the "everything OFF at execution" policy. The user
		-- re-enables whichever features they want each session.
		if data.aimSpeed then AB.SPEED=data.aimSpeed end
		if data.grabRadius then AutoSteal.Radius=data.grabRadius end
		if data.autoPlayMode then
			if setAutoPlayModeUI then setAutoPlayModeUI(data.autoPlayMode)
			else State.autoPlayMode = data.autoPlayMode end
		end
		if data.uiScaleVal and _GH.applyUIScale then _GH.applyUIScale(data.uiScaleVal) end
		-- Window/widget positions: restored before anything else so frames
		-- never flash at their default position on load.
		if type(data.positions) == "table" then
			for id, pos in pairs(data.positions) do
				local frame = _GH.positions and _GH.positions[id]
				if frame and type(pos) == "table" and pos[1] then
					frame.Position = UDim2.new(pos[1], pos[2], pos[3], pos[4])
				end
			end
		end

		-- Numeric input rows: restore value + re-apply effect (FOV, radius…)
		if type(data.inputs) == "table" then
			for key, value in pairs(data.inputs) do
				local entry = _GH.allInputs and _GH.allInputs[key]
				if entry and type(value) == "number" then
					entry.box.Text = tostring(value)
					pcall(entry.onChange, value)
				end
			end
		end

		-- Theme must be applied BEFORE toggle restore: TweenService captures C_ON_BG
		-- by value at Create() time, so restoring toggles before applyTheme would
		-- bake the default-blue into all pill tweens even in noir mode.
		if data.theme == "default" or data.theme == "noir" or data.theme == "crimson"
			or data.theme == "white" or data.theme == "purple" then
			applyTheme(data.theme)
		end

		-- Toggle rows: restore saved state (ON and OFF) including defaults-ON features.
		if type(data.toggles) == "table" then
			for key, on in pairs(data.toggles) do
				local entry = _GH.allToggles and _GH.allToggles[key]
				if entry then
					if on then
						if entry.onToggle then pcall(entry.onToggle, true) end
						entry.set(true)
					else
						if entry.onToggle then pcall(entry.onToggle, false) end
						entry.set(false)
					end
				end
			end
		end

		if data.kb then
			local kb = _GH.MH_KB
			if kb then
				for name, entry in pairs(data.kb) do
					if kb[name] then
						if entry.key and Enum.KeyCode[entry.key] then kb[name].key = Enum.KeyCode[entry.key] end
						if entry.gp  and Enum.KeyCode[entry.gp]  then kb[name].gp  = Enum.KeyCode[entry.gp]  end
					end
				end
			end
		end

		-- Floating buttons: positions first, then spawn, then lock.
		-- Positions saved under an older layout version are discarded so
		-- buttons don't restore to stale/overlapping coordinates.
		if type(data.floatPositions) == "table" and data.floatPosV == _FLOAT_POS_VERSION then
			for id, pos in pairs(data.floatPositions) do
				_floatPositions[id] = pos
			end
		end
		-- Floating buttons never auto-spawn from a saved session — matches
		-- the "everything OFF at execution" policy. The user re-toggles
		-- whichever ones they want each time (positions are still remembered
		-- once they do, via floatPositions above).
		if type(data.uiLocked) == "boolean" and data.uiLocked then
			setDragLock(true)
			lockTitleBtn.Text = "🔒"; lockTitleBtn.TextColor3 = C_RED
		end
	end)
	if not loadOk then warn("[H] MH_load failed partway through — check referenced modules") end

	-- Defer one frame so any float buttons spawned by toggle restore are fully
	-- registered before we re-apply their active color against the loaded theme.
	task.defer(function()
		if _GH.refreshFloatActiveColors then _GH.refreshFloatActiveColors() end
	end)

	return true
end

local _floatRowSetters = {}
buildPage("Buttons", function()
	-- Right at the top: direct toggle that spawns the Speed Booster widget
	-- itself (not an intermediary floating button), shown in front.
	UIB.makeSectionLabel("Speed Booster")
	UIB.makeToggleRow("Speed Booster", false, function(on)
		if _GH.spW then
			_GH.spW.Visible = on
			if on then _GH.spW.ZIndex = 1000 end
		end
	end)
	UIB.makeGap(4)

	UIB.makeSectionLabel("Floating Buttons")
	UIB.makeGap(2)

	local FLOAT_LABELS = {
		{id="aimbot",      name="Aim Bot"},
		{id="aimv2",       name="Aim V2"},
		{id="dropbr",      name="Drop Brainrot"},
		{id="autoleft",    name="Auto Left"},
		{id="autoright",   name="Auto Right"},
		{id="tpdown",      name="TP Down"},
		{id="battp",       name="Bat TP"},
		{id="instareset",  name="Instant Reset"},
	}

	do
		-- Select All / Unselect All: spawns or despawns every floating
		-- button in one click and keeps their individual toggle rows in
		-- sync (calling the setter directly only updates the visual — the
		-- actual spawn/despawn call is what a real click does too).
		local allRow = Instance.new("Frame", currentPage)
		allRow.Size = UDim2.new(1,0,0,30); allRow.BackgroundTransparency = 1
		allRow.LayoutOrder = LO()
		local allLL = Instance.new("UIListLayout", allRow)
		allLL.FillDirection = Enum.FillDirection.Horizontal
		allLL.Padding = UDim.new(0,8)

		local selAllBtn = Instance.new("TextButton", allRow)
		selAllBtn.Size = UDim2.new(0.5,-4,1,0); selAllBtn.BackgroundColor3 = C_ON_BG
		selAllBtn.BackgroundTransparency = 0.1; selAllBtn.BorderSizePixel = 0
		selAllBtn.Text = "Select All"; selAllBtn.TextColor3 = C_MOON
		selAllBtn.Font = Enum.Font.GothamBold; selAllBtn.TextSize = 10
		selAllBtn.AutoButtonColor = false; addCorner(selAllBtn,10); addLivingStroke(selAllBtn,1)

		local unselAllBtn = Instance.new("TextButton", allRow)
		unselAllBtn.Size = UDim2.new(0.5,-4,1,0); unselAllBtn.BackgroundColor3 = C_OFF_BG
		unselAllBtn.BackgroundTransparency = 0.3; unselAllBtn.BorderSizePixel = 0
		unselAllBtn.Text = "Unselect All"; unselAllBtn.TextColor3 = C_DIM
		unselAllBtn.Font = Enum.Font.GothamBold; unselAllBtn.TextSize = 10
		unselAllBtn.AutoButtonColor = false; addCorner(unselAllBtn,10); addLivingStroke(unselAllBtn,1)

		selAllBtn.MouseButton1Click:Connect(function()
			for _, entry in ipairs(FLOAT_LABELS) do
				makeFloatButton(entry.id)
				if _floatRowSetters[entry.id] then _floatRowSetters[entry.id](true) end
			end
			if _GH.autoSave then _GH.autoSave() end
			if _GH.showToast then _GH.showToast("All Buttons Shown", "on") end
		end)
		unselAllBtn.MouseButton1Click:Connect(function()
			for _, entry in ipairs(FLOAT_LABELS) do
				removeFloatButton(entry.id)
				if _floatRowSetters[entry.id] then _floatRowSetters[entry.id](false) end
			end
			if _GH.autoSave then _GH.autoSave() end
			if _GH.showToast then _GH.showToast("All Buttons Hidden", "off") end
		end)
	end
	UIB.makeGap(4)

	for _, entry in ipairs(FLOAT_LABELS) do
		_floatRowSetters[entry.id] = UIB.makeToggleRow(entry.name, false, function(on)
			if on then makeFloatButton(entry.id) else removeFloatButton(entry.id) end
			if _GH.autoSave then _GH.autoSave() end
		end)
	end
end)

buildPage("Settings", function()
	UIB.makeSectionLabel("Auto Play")
	do
		local apModes={"Full","Half"}
		local function getIdx()
			for i,m in ipairs(apModes) do if m==State.autoPlayMode then return i end end; return 1
		end
		local apRow=Instance.new("Frame",currentPage)
		apRow.Size=UDim2.new(1,0,0,32);apRow.BackgroundColor3=C_ROW;apRow.BackgroundTransparency=0.35
		apRow.BorderSizePixel=0;apRow.LayoutOrder=LO();addCorner(apRow,12);addLivingStroke(apRow,1)
		local apl=Instance.new("TextLabel",apRow)
		apl.Size=UDim2.new(0,110,1,0);apl.Position=UDim2.new(0,14,0,0)
		apl.BackgroundTransparency=1;apl.Text="Auto Play Mode";apl.TextColor3=C_WHITE
		apl.Font=Enum.Font.GothamBold;apl.TextSize=10;apl.TextXAlignment=Enum.TextXAlignment.Left
		addLivingTextGradient(apl)
		local apBtn=Instance.new("TextButton",apRow)
		apBtn.Size=UDim2.new(0,70,0,22);apBtn.Position=UDim2.new(1,-80,0.5,-11)
		apBtn.BackgroundColor3=C_ON_BG;apBtn.BackgroundTransparency=0.1;apBtn.BorderSizePixel=0
		apBtn.Text=State.autoPlayMode;apBtn.TextColor3=C_MOON
		apBtn.Font=Enum.Font.GothamBold;apBtn.TextSize=10;apBtn.AutoButtonColor=false
		addCorner(apBtn,6);addLivingStroke(apBtn,1)
		apBtn.MouseButton1Click:Connect(function()
			local idx=(getIdx()%#apModes)+1
			State.autoPlayMode=apModes[idx];apBtn.Text=apModes[idx]
		end)
	end
	UIB.makeGap(4)
	UIB.makeSectionLabel("UI Scale")
	UIB.makeGap(2)
	do
		-- S=1, M=4, L=7, XL=10 (on applyUIScale's 1-10 scale)
		local presets = {{"S",1},{"M",4},{"L",7},{"XL",10}}
		local scRow = Instance.new("Frame", currentPage)
		scRow.Size = UDim2.new(1,0,0,34); scRow.BackgroundColor3 = C_ROW
		scRow.BackgroundTransparency = 0.35; scRow.BorderSizePixel = 0
		scRow.LayoutOrder = LO(); addCorner(scRow,12); addLivingStroke(scRow,1)
		local ll2 = Instance.new("UIListLayout", scRow)
		ll2.FillDirection = Enum.FillDirection.Horizontal
		ll2.VerticalAlignment = Enum.VerticalAlignment.Center
		ll2.HorizontalAlignment = Enum.HorizontalAlignment.Center
		ll2.Padding = UDim.new(0,8)
		for _, preset in ipairs(presets) do
			local lbl2, val = preset[1], preset[2]
			local btn2 = Instance.new("TextButton", scRow)
			btn2.Size = UDim2.new(0,48,0,24); btn2.BackgroundColor3 = C_ON_BG
			btn2.BackgroundTransparency = 0.3; btn2.BorderSizePixel = 0
			btn2.Text = lbl2; btn2.TextColor3 = C_MOON
			btn2.Font = Enum.Font.GothamBold; btn2.TextSize = 11
			btn2.AutoButtonColor = false
			addCorner(btn2,8); addLivingStroke(btn2,1)
			btn2.MouseButton1Click:Connect(function()
				if _GH.applyUIScale then _GH.applyUIScale(val) end
				for _, b2 in ipairs(scRow:GetChildren()) do
					if b2:IsA("TextButton") then
						b2.BackgroundTransparency = 0.3; b2.TextColor3 = C_MOON
					end
				end
				btn2.BackgroundTransparency = 0.05; btn2.TextColor3 = C_WHITE
			end)
		end
	end

	UIB.makeGap(4)
	do
		-- Snaps the main panel AND every default-grid floating button back
		-- to their starting spot — the fix for "dragged everything into a
		-- mess" without having to place each one back by hand.
		local resetRow = Instance.new("Frame", currentPage)
		resetRow.Size = UDim2.new(1,0,0,32); resetRow.BackgroundColor3 = C_ROW
		resetRow.BackgroundTransparency = 0.35; resetRow.BorderSizePixel = 0
		resetRow.LayoutOrder = LO(); addCorner(resetRow,12); addLivingStroke(resetRow,1)
		local resetClk = Instance.new("TextButton", resetRow)
		resetClk.Size = UDim2.new(1,0,1,0); resetClk.BackgroundTransparency = 1
		resetClk.Text = "↺  Reset Position"; resetClk.TextColor3 = C_WHITE
		resetClk.Font = Enum.Font.GothamBold; resetClk.TextSize = 10
		addLivingTextGradient(resetClk)
		resetClk.MouseButton1Click:Connect(function()
			if _GH.resetMainPosition then _GH.resetMainPosition() end
			if _GH.resetFloatPositions then _GH.resetFloatPositions() end
			if _GH.showToast then _GH.showToast("Position Reset", "info") end
		end)
	end

	do
		-- When on, dragging any one spawned floating button carries every
		-- other spawned one along by the same delta — moves the whole group
		-- as a block instead of repositioning each one individually.
		UIB.makeToggleRow("Move Buttons Together", false, function(on)
			if _GH.setFloatLinkMove then _GH.setFloatLinkMove(on) end
		end)
	end

	UIB.makeGap(4)
	UIB.makeSectionLabel("Bypass")
	UIB.makeToggleRow("Speed Bypass", false, function(on)
		if _sbBypassWidget then _sbBypassWidget.Visible = on end
		-- Actually triggers the bypass (not just showing the panel)
		if _GH.speedBypassToggle then
			local isActive = _GH.speedBypassIsActive and _GH.speedBypassIsActive() or false
			if isActive ~= on then _GH.speedBypassToggle() end
		end
	end)
	UIB.makeToggleRow("Lagger", false, function(on)
		if _lgrBypassWidget then _lgrBypassWidget.Visible = on end
	end)

	-- ── ANIMATION CHANGER (22 packs, ◀ ▶ navigation) ──────────────
	UIB.makeGap(4)
	UIB.makeSectionLabel("Animation Changer")
	do
		local ANIM_PACKS = {
			["Robot"]       = {WalkAnim=616013216,RunAnim=616010382,JumpAnim=616008936,FallAnim=616005863,SwimIdle=616012453,Swim=616011509,Animation1=616006778,Animation2=616008087,ClimbAnim=616003713},
			["Vampire"]     = {WalkAnim=1083178339,RunAnim=1083216690,JumpAnim=1083218792,FallAnim=1083189019,SwimIdle=1083222527,Swim=1083225406,Animation1=1083445855,Animation2=1083450167,ClimbAnim=1083182000},
			["Superhero"]   = {WalkAnim=616013216,RunAnim=616111765,JumpAnim=616111876,FallAnim=616108001,SwimIdle=616112625,Swim=616112437,Animation1=616111295,Animation2=616111295,ClimbAnim=616110833},
			["Cartoony"]    = {WalkAnim=742640026,RunAnim=742638842,JumpAnim=742637942,FallAnim=742637151,SwimIdle=742639220,Swim=742639812,Animation1=742635424,Animation2=742636889,ClimbAnim=742636889},
			["Ninja"]       = {WalkAnim=656118852,RunAnim=656118852,JumpAnim=656117878,FallAnim=656115606,SwimIdle=656119721,Swim=656119721,Animation1=656117878,Animation2=656118341,ClimbAnim=656114359},
			["Adidas Sports"]    ={WalkAnim=18537392113,RunAnim=18537384940,JumpAnim=18537380791,FallAnim=18537367238,SwimIdle=18537387180,Swim=18537389531,Animation1=18537376492,Animation2=18537371272,ClimbAnim=18537363391},
			["Adidas Community"] ={WalkAnim=122150855457006,RunAnim=82598234841035,JumpAnim=75290611992385,FallAnim=98600215928904,SwimIdle=109346520324160,Swim=133308483266208,Animation1=122257458498464,Animation2=102357151005774,ClimbAnim=88763136693023},
			["Adidas Aura"]      ={WalkAnim=83842218823011,RunAnim=118320322718866,JumpAnim=109996626521204,FallAnim=95603166884636,SwimIdle=94922130551805,Swim=134530128383903,Animation1=110211186840347,Animation2=114191137265065,ClimbAnim=97824616490448},
			["Stylish"]     = {WalkAnim=616122287,RunAnim=616117076,JumpAnim=616119360,FallAnim=616115533,SwimIdle=616120448,Swim=616121235,Animation1=616117076,Animation2=616120861,ClimbAnim=616115533},
			["Levitation"]  = {WalkAnim=616013216,RunAnim=616006778,JumpAnim=616008936,FallAnim=616005863,SwimIdle=616011509,Swim=616012453,Animation1=616006778,Animation2=616008087,ClimbAnim=616003713},
			["Astronaut"]   = {WalkAnim=891667138,RunAnim=891636393,JumpAnim=891627522,FallAnim=891617961,SwimIdle=891639666,Swim=891663592,Animation1=891621366,Animation2=891633237,ClimbAnim=891609353},
			["Werewolf"]    = {WalkAnim=1083195517,RunAnim=1083194401,JumpAnim=1083218792,FallAnim=1083189019,SwimIdle=1083222527,Swim=1083225406,Animation1=1083462077,Animation2=1083450167,ClimbAnim=1083182000},
			["Knight"]      = {WalkAnim=658831042,RunAnim=658831794,JumpAnim=658832070,FallAnim=658831500,SwimIdle=658832437,Swim=658832807,Animation1=657595757,Animation2=657600338,ClimbAnim=658830056},
			["Pirate"]      = {WalkAnim=750785693,RunAnim=750783738,JumpAnim=750782230,FallAnim=750781874,SwimIdle=750785579,Swim=750784579,Animation1=750781874,Animation2=750782770,ClimbAnim=750779899},
			["Toy"]         = {WalkAnim=782841498,RunAnim=782843345,JumpAnim=782847020,FallAnim=782846423,SwimIdle=782844582,Swim=782844235,Animation1=782842708,Animation2=782845736,ClimbAnim=782843869},
			["Elder"]       = {WalkAnim=1092112116,RunAnim=1092114823,JumpAnim=1092114571,FallAnim=1092114319,SwimIdle=1092113582,Swim=1092113478,Animation1=1092110164,Animation2=1092110049,ClimbAnim=1092113209},
			["Bubbly"]      = {WalkAnim=910034870,RunAnim=910025107,JumpAnim=910016857,FallAnim=910001910,SwimIdle=910030921,Swim=910028158,Animation1=910004836,Animation2=910009958,ClimbAnim=910019264},
			["Zombie"]      = {WalkAnim=616163682,RunAnim=616163682,JumpAnim=616161682,FallAnim=616157476,SwimIdle=616165109,Swim=616164682,Animation1=616158929,Animation2=616160636,ClimbAnim=616156119},
			["Sneaky"]      = {WalkAnim=1132510133,RunAnim=1132494274,JumpAnim=1132489853,FallAnim=1132469004,SwimIdle=1132506407,Swim=1132500520,Animation1=1132473842,Animation2=1132477671,ClimbAnim=1132461372},
			["Patrol"]      = {WalkAnim=1151231493,RunAnim=1150967949,JumpAnim=1150944216,FallAnim=1148863382,SwimIdle=1151221899,Swim=1151204998,Animation1=1149612882,Animation2=1150842221,ClimbAnim=1148811837},
			["Popstar"]     = {WalkAnim=1212980338,RunAnim=1212980348,JumpAnim=1212954642,FallAnim=1212900995,SwimIdle=1212998578,Swim=1212852603,Animation1=1212900985,Animation2=1212954651,ClimbAnim=1213044953},
			["Confident"]   = {WalkAnim=1070017263,RunAnim=1070001516,JumpAnim=1069984524,FallAnim=1069973677,SwimIdle=1070012133,Swim=1070009914,Animation1=1069977950,Animation2=1069987858,ClimbAnim=1069946257},
			["Princess"]    = {WalkAnim=941028902,RunAnim=941015281,JumpAnim=941008832,FallAnim=941000007,SwimIdle=941025398,Swim=941018893,Animation1=941003647,Animation2=941013098,ClimbAnim=940996062},
			["Cowboy"]      = {WalkAnim=1014421541,RunAnim=1014401683,JumpAnim=1014394726,FallAnim=1014384571,SwimIdle=1014411816,Swim=1014406523,Animation1=1014390418,Animation2=1014398616,ClimbAnim=1014380606},
		}
		local ANIM_ORDER = {"Default","Robot","Vampire","Superhero","Cartoony","Ninja","Adidas Sports","Adidas Community","Adidas Aura","Stylish","Levitation","Astronaut","Werewolf","Knight","Pirate","Toy","Elder","Bubbly","Zombie","Sneaky","Patrol","Popstar","Confident","Princess","Cowboy"}
		local _animEnabled = false
		local _animIndex = 1

		-- Robust method: direct Animator:LoadAnimation + Heartbeat loop that
		-- keeps reapplying (handles cases where the game regenerates Animate)
		local _animTracks = {}
		local function stopAllTracks()
			for _, tr in ipairs(_animTracks) do pcall(function() tr:Stop(0) end) end
			_animTracks = {}
		end

		local function applyAnimPack(packName)
			stopAllTracks()
			local c = LP.Character; if not c then return end
			local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
			local animator = hum:FindFirstChildOfClass("Animator")
			if not animator then animator = Instance.new("Animator", hum) end
			local pack = ANIM_PACKS[packName]; if not pack then return end

			-- 1. Update Animate script IDs first (walk/run/jump/fall/climb/swim)
			local animate = c:FindFirstChild("Animate")
			if animate then
				local function setAnim(folder,slot,id)
					if not id then return end
					local f=animate:FindFirstChild(folder); if not f then return end
					local a=f:FindFirstChild(slot)
					if a and a:IsA("Animation") then a.AnimationId="rbxassetid://"..tostring(id) end
				end
				setAnim("walk","WalkAnim",pack.WalkAnim)
				setAnim("run","RunAnim",pack.RunAnim)
				setAnim("jump","JumpAnim",pack.JumpAnim)
				setAnim("fall","FallAnim",pack.FallAnim)
				setAnim("idle","Animation1",pack.Animation1)
				setAnim("idle","Animation2",pack.Animation2)
				setAnim("climb","ClimbAnim",pack.ClimbAnim)
				setAnim("swimidle","SwimIdle",pack.SwimIdle)
				setAnim("swim","Swim",pack.Swim)
			end

			-- 2. Stop all currently playing tracks so Animate restarts with new IDs
			for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do pcall(function() tr:Stop(0) end) end

			-- 3. Force-play idle immediately for visual feedback (Animate handles rest)
			local slots = {
				{id=pack.Animation1, prio=Enum.AnimationPriority.Idle,     loop=true},
				{id=pack.WalkAnim,   prio=Enum.AnimationPriority.Movement, loop=true},
			}
			for _, s in ipairs(slots) do
				if s.id then
					local anim = Instance.new("Animation")
					anim.AnimationId = "rbxassetid://"..tostring(s.id)
					local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
					if ok and track then
						track.Priority = s.prio
						track.Looped = s.loop
						track:Play(0)
						table.insert(_animTracks, track)
					end
				end
			end
		end

		local function clearAnimPack()
			stopAllTracks()
		end

		-- Navigation row: ◀  [Name]  ▶
		local animRow = Instance.new("Frame", currentPage)
		animRow.Size=UDim2.new(1,0,0,36); animRow.BackgroundColor3=C_ROW
		animRow.BackgroundTransparency=0.35; animRow.BorderSizePixel=0; animRow.LayoutOrder=LO()
		addCorner(animRow,10); addLivingStroke(animRow,1)

		local animPrevBtn = Instance.new("TextButton", animRow)
		animPrevBtn.Size=UDim2.new(0,36,1,0); animPrevBtn.Position=UDim2.new(0,0,0,0)
		animPrevBtn.BackgroundTransparency=1; animPrevBtn.Text="◀"
		animPrevBtn.TextColor3=C_MOON2; animPrevBtn.Font=Enum.Font.GothamBlack; animPrevBtn.TextSize=16
		animPrevBtn.AutoButtonColor=false

		local animNameLbl = Instance.new("TextLabel", animRow)
		animNameLbl.Size=UDim2.new(1,-72,1,0); animNameLbl.Position=UDim2.new(0,36,0,0)
		animNameLbl.BackgroundTransparency=1; animNameLbl.Text="Default"
		animNameLbl.TextColor3=C_WHITE; animNameLbl.Font=Enum.Font.GothamBlack; animNameLbl.TextSize=12
		animNameLbl.TextXAlignment=Enum.TextXAlignment.Center
		addLivingTextGradient(animNameLbl)

		local animNextBtn = Instance.new("TextButton", animRow)
		animNextBtn.Size=UDim2.new(0,36,1,0); animNextBtn.Position=UDim2.new(1,-36,0,0)
		animNextBtn.BackgroundTransparency=1; animNextBtn.Text="▶"
		animNextBtn.TextColor3=C_MOON2; animNextBtn.Font=Enum.Font.GothamBlack; animNextBtn.TextSize=16
		animNextBtn.AutoButtonColor=false

		local function selectAnim(idx)
			_animIndex = ((idx - 1) % #ANIM_ORDER) + 1
			local name = ANIM_ORDER[_animIndex]
			animNameLbl.Text = name
			if _animEnabled then
				if name == "Default" then clearAnimPack() else applyAnimPack(name) end
			end
		end

		animPrevBtn.MouseButton1Click:Connect(function() selectAnim(_animIndex - 1) end)
		animNextBtn.MouseButton1Click:Connect(function() selectAnim(_animIndex + 1) end)

		UIB.makeToggleRow("Animation Changer", false, function(on)
			_animEnabled = on
			local name = ANIM_ORDER[_animIndex]
			if on then
				if name == "Default" then clearAnimPack() else applyAnimPack(name) end
			else
				clearAnimPack()
			end
		end)

		LP.CharacterAdded:Connect(function()
			task.wait(1)
			_animTracks = {}
			if _animEnabled then
				local name = ANIM_ORDER[_animIndex]
				if name ~= "Default" then applyAnimPack(name) end
			end
		end)
	end

	UIB.makeGap(4)
	UIB.makeSectionLabel("Theme")
	UIB.makeGap(2)
	do
		-- Grid (not manually-positioned buttons) so adding themes never means
		-- re-doing pixel math and risking overlap in a 300px-wide panel —
		-- UIGridLayout wraps to a new row on its own once cells run out of room.
		local THEME_LIST = {
			{id="default", label="Default", swatch=Color3.fromRGB(90,160,255)},
			{id="noir",    label="Dark",    swatch=Color3.fromRGB(205,205,205)},
			{id="crimson", label="Crimson", swatch=Color3.fromRGB(225,70,95)},
			{id="white",   label="White",   swatch=Color3.fromRGB(255,255,255)},
			{id="purple",  label="Purple",  swatch=Color3.fromRGB(170,110,255)},
		}
		local thWrap = Instance.new("Frame", currentPage)
		thWrap.Size = UDim2.new(1,0,0,0); thWrap.AutomaticSize = Enum.AutomaticSize.Y
		thWrap.BackgroundTransparency = 1; thWrap.LayoutOrder = LO()
		local thGrid = Instance.new("UIGridLayout", thWrap)
		thGrid.CellSize = UDim2.new(0,84,0,26)
		thGrid.CellPadding = UDim2.new(0,6,0,6)
		thGrid.SortOrder = Enum.SortOrder.LayoutOrder

		local _themeBtns = {}
		for i, t in ipairs(THEME_LIST) do
			local btn = Instance.new("TextButton", thWrap)
			btn.BackgroundColor3 = C_OFF_BG; btn.BackgroundTransparency = 0.3
			btn.BorderSizePixel = 0; btn.Text = t.label; btn.TextColor3 = C_DIM
			btn.Font = Enum.Font.GothamBold; btn.TextSize = 9
			btn.AutoButtonColor = false; btn.LayoutOrder = i
			addCorner(btn, 8); addLivingStroke(btn, 1)
			_themeBtns[t.id] = {btn = btn, swatch = t.swatch}
			btn.MouseButton1Click:Connect(function()
				applyTheme(t.id)
				if _GH.autoSave then _GH.autoSave() end
				if _GH.showToast then _GH.showToast("Theme: " .. t.label, "info") end
			end)
		end
		_G_updateThemeUI = function(name)
			for id, entry in pairs(_themeBtns) do
				local active = (id == name)
				entry.btn.BackgroundColor3 = active and entry.swatch or C_OFF_BG
				entry.btn.BackgroundTransparency = active and 0.1 or 0.3
				-- silver2 (not dim): it's already picked per-theme to read
				-- against that theme's own panel color everywhere else, so
				-- it stays legible here too now that White's panel (and this
				-- inactive chip's background) is bright instead of black.
				entry.btn.TextColor3 = active and Color3.fromRGB(12,10,16) or C_SILVER2
			end
		end
	end
	UIB.makeGap(6)
	UIB.makeSectionLabel("Credits")
	local creditRow = Instance.new("Frame", currentPage)
	creditRow.Size = UDim2.new(1,0,0,30); creditRow.BackgroundTransparency = 1; creditRow.LayoutOrder = LO()
	local creditFooter = Instance.new("TextLabel", creditRow)
	creditFooter.Size = UDim2.new(1,0,1,0); creditFooter.BackgroundTransparency = 1
	creditFooter.Text = "ALN x YSLEM"
	creditFooter.TextColor3 = C_SILVER2; creditFooter.Font = Enum.Font.Gotham; creditFooter.TextSize = 10
	addLivingTextGradient(creditFooter)
end);  -- required semicolon (otherwise ambiguous merge with the (function() below)

-- ===================================================================
-- ===================================================================
-- ===================================================================
-- SPEED BYPASS (Moon Hub style — blue, +/- power, exact Cz lag logic)
-- ===================================================================
(function()
local activated = false
local keybind = Enum.KeyCode.E
local waitingForKey = false
local power = 79000
local lagAmount = 0.15
local lagConn = nil
local minimized = false

local function applyPower(val)
	power = math.clamp(val, 10000, 500000)
	local t = (power - 10000) / 490000
	lagAmount = t * 0.2
end
applyPower(power)

local function startLag()
	if lagConn then lagConn:Disconnect() end
	lagConn = RunService.RenderStepped:Connect(function()
		if not activated then return end
		if lagAmount > 0 then
			local t = tick()
			while tick() - t < lagAmount do end
		end
	end)
end

local function stopLag()
	activated = false
	if lagConn then lagConn:Disconnect(); lagConn = nil end
end

local sbW = Instance.new("Frame", gui)
sbW.Name = _NS.."c"
sbW.Size = UDim2.new(0, 150, 0, 165)
sbW.Position = UDim2.new(1, -256, 0, 210)
sbW.BackgroundColor3 = C_BG
sbW.BorderSizePixel = 0
sbW.ClipsDescendants = true
sbW.Active = true
sbW.Visible = false
addCorner(sbW, 12); addLivingStroke(sbW, 1.5)
_sbBypassWidget = sbW

local sbHeader = Instance.new("Frame", sbW)
sbHeader.Size = UDim2.new(1, 0, 0, 28); sbHeader.BackgroundColor3 = C_HEADER; sbHeader.BorderSizePixel = 0
addCorner(sbHeader, 12); makeDraggable(sbW, sbHeader, "speedbypass")
local sbPatch = Instance.new("Frame", sbHeader)
sbPatch.Size = UDim2.new(1,0,0,12); sbPatch.Position = UDim2.new(0,0,1,-12)
sbPatch.BackgroundColor3 = C_HEADER; sbPatch.BorderSizePixel = 0
local sbDot = Instance.new("Frame", sbHeader)
sbDot.Size = UDim2.new(0,5,0,5); sbDot.Position = UDim2.new(0,10,0,11)
sbDot.BackgroundColor3 = C_MOON; sbDot.BorderSizePixel = 0; addCorner(sbDot, 3)
local sbTitle = Instance.new("TextLabel", sbHeader)
sbTitle.Size = UDim2.new(1,-52,1,0); sbTitle.Position = UDim2.new(0,20,0,0)
sbTitle.BackgroundTransparency = 1; sbTitle.Text = "SPEED BYPASS"
sbTitle.TextColor3 = C_WHITE; sbTitle.Font = Enum.Font.GothamBlack; sbTitle.TextSize = 10
sbTitle.TextXAlignment = Enum.TextXAlignment.Left; addLivingTextGradient(sbTitle)

local sbFullH = 165
local sbMinBtn = Instance.new("TextButton", sbHeader)
sbMinBtn.Size = UDim2.new(0,20,0,20); sbMinBtn.Position = UDim2.new(1,-26,0.5,-10)
sbMinBtn.BackgroundColor3 = Color3.fromRGB(30,30,34); sbMinBtn.BorderSizePixel = 0
sbMinBtn.Text = "-"; sbMinBtn.TextColor3 = C_WHITE; sbMinBtn.Font = Enum.Font.GothamBlack; sbMinBtn.TextSize = 13
sbMinBtn.AutoButtonColor = false; addCorner(sbMinBtn, 6); addLivingStroke(sbMinBtn, 1)

local toggleBtn = Instance.new("TextButton", sbW)
toggleBtn.Size = UDim2.new(1,-16,0,26); toggleBtn.Position = UDim2.new(0,8,0,34)
toggleBtn.BackgroundColor3 = C_OFF_BG; toggleBtn.BackgroundTransparency = 0.2
toggleBtn.Text = "DISABLED"; toggleBtn.TextColor3 = C_DIM
toggleBtn.Font = Enum.Font.GothamBlack; toggleBtn.TextSize = 11
toggleBtn.BorderSizePixel = 0; toggleBtn.AutoButtonColor = false
addCorner(toggleBtn, 8); addLivingStroke(toggleBtn, 1)

local function toggle()
	if not activated then
		activated = true
		toggleBtn.Text = "ENABLED"
		toggleBtn.BackgroundColor3 = C_ON_BG; toggleBtn.BackgroundTransparency = 0.1
		toggleBtn.TextColor3 = C_MOON
		startLag()
	else
		stopLag()
		toggleBtn.Text = "DISABLED"
		toggleBtn.BackgroundColor3 = C_OFF_BG; toggleBtn.BackgroundTransparency = 0.2
		toggleBtn.TextColor3 = C_DIM
	end
	if _GH.setSpeedBypassQpVisual then _GH.setSpeedBypassQpVisual(activated) end
end
toggleBtn.MouseButton1Click:Connect(toggle)
_GH.speedBypassToggle = toggle
_GH.speedBypassIsActive = function() return activated end

local bindRow = Instance.new("Frame", sbW)
bindRow.Size = UDim2.new(1,-16,0,26); bindRow.Position = UDim2.new(0,8,0,64)
bindRow.BackgroundColor3 = C_ROW; bindRow.BackgroundTransparency = 0.35
bindRow.BorderSizePixel = 0; addCorner(bindRow, 8); addLivingStroke(bindRow, 1)
local bindLabel = Instance.new("TextLabel", bindRow)
bindLabel.Size = UDim2.new(0.5,0,1,0); bindLabel.Position = UDim2.new(0,10,0,0)
bindLabel.BackgroundTransparency = 1; bindLabel.Text = "Bind"
bindLabel.TextColor3 = C_WHITE; bindLabel.Font = Enum.Font.GothamBold; bindLabel.TextSize = 10
bindLabel.TextXAlignment = Enum.TextXAlignment.Left; addLivingTextGradient(bindLabel)
local bindBtn = Instance.new("TextButton", bindRow)
bindBtn.Size = UDim2.new(0,42,0,20); bindBtn.Position = UDim2.new(1,-48,0.5,-10)
bindBtn.BackgroundColor3 = C_OFF_BG; bindBtn.BackgroundTransparency = 0.1
bindBtn.Text = "E"; bindBtn.TextColor3 = C_MOON2; bindBtn.Font = Enum.Font.GothamBold; bindBtn.TextSize = 10
bindBtn.BorderSizePixel = 0; bindBtn.AutoButtonColor = false
addCorner(bindBtn, 5); addLivingTextGradient(bindBtn)
bindBtn.MouseButton1Click:Connect(function()
	waitingForKey = true; bindBtn.Text = "..."
end)

local powerLbl = Instance.new("TextLabel", sbW)
powerLbl.Size = UDim2.new(1,-16,0,14); powerLbl.Position = UDim2.new(0,8,0,94)
powerLbl.BackgroundTransparency = 1; powerLbl.Text = "Power"
powerLbl.TextColor3 = C_WHITE; powerLbl.Font = Enum.Font.GothamBold; powerLbl.TextSize = 9
powerLbl.TextXAlignment = Enum.TextXAlignment.Left; addLivingTextGradient(powerLbl)

local minusBtn = Instance.new("TextButton", sbW)
minusBtn.Size = UDim2.new(0,22,0,22); minusBtn.Position = UDim2.new(0,8,0,110)
minusBtn.BackgroundColor3 = C_OFF_BG; minusBtn.BackgroundTransparency = 0.1
minusBtn.Text = "-"; minusBtn.TextColor3 = C_MOON2; minusBtn.Font = Enum.Font.GothamBold; minusBtn.TextSize = 13
minusBtn.BorderSizePixel = 0; minusBtn.AutoButtonColor = false
addCorner(minusBtn, 5); addLivingStroke(minusBtn, 1)

local powerBox = Instance.new("TextBox", sbW)
powerBox.Size = UDim2.new(0,62,0,22); powerBox.Position = UDim2.new(0.5,-31,0,110)
powerBox.BackgroundColor3 = C_OFF_BG; powerBox.BackgroundTransparency = 0.1
powerBox.Text = tostring(power); powerBox.TextColor3 = C_SILVER
powerBox.Font = Enum.Font.GothamBold; powerBox.TextSize = 11
powerBox.BorderSizePixel = 0; powerBox.ClearTextOnFocus = false
addCorner(powerBox, 5); addLivingStroke(powerBox, 1)

local plusBtn = Instance.new("TextButton", sbW)
plusBtn.Size = UDim2.new(0,22,0,22); plusBtn.Position = UDim2.new(1,-30,0,110)
plusBtn.BackgroundColor3 = C_OFF_BG; plusBtn.BackgroundTransparency = 0.1
plusBtn.Text = "+"; plusBtn.TextColor3 = C_MOON2; plusBtn.Font = Enum.Font.GothamBold; plusBtn.TextSize = 13
plusBtn.BorderSizePixel = 0; plusBtn.AutoButtonColor = false
addCorner(plusBtn, 5); addLivingStroke(plusBtn, 1)

minusBtn.MouseButton1Click:Connect(function()
	applyPower(power - 1000); powerBox.Text = tostring(power)
end)
plusBtn.MouseButton1Click:Connect(function()
	applyPower(power + 1000); powerBox.Text = tostring(power)
end)
powerBox.FocusLost:Connect(function()
	local val = tonumber(powerBox.Text)
	if val then applyPower(val); powerBox.Text = tostring(power)
	else powerBox.Text = tostring(power) end
end)

local footer = Instance.new("TextLabel", sbW)
footer.Size = UDim2.new(1,-16,0,16); footer.Position = UDim2.new(0,8,0,142)
footer.BackgroundTransparency = 1; footer.Text = "MOON V3  •  Speed Bypass"
footer.TextColor3 = C_SILVER2; footer.Font = Enum.Font.Gotham; footer.TextSize = 8
footer.TextXAlignment = Enum.TextXAlignment.Center; addLivingTextGradient(footer)

local function toggleMinimize()
	minimized = not minimized
	sbMinBtn.Text = minimized and "+" or "-"
	sbW.Size = minimized and UDim2.new(0,150,0,34) or UDim2.new(0,150,0,sbFullH)
	local elements = {toggleBtn, bindRow, powerLbl, minusBtn, powerBox, plusBtn, footer}
	for _, el in ipairs(elements) do el.Visible = not minimized end
end
sbMinBtn.MouseButton1Click:Connect(toggleMinimize)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if waitingForKey then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			keybind = input.KeyCode
			bindBtn.Text = keybind.Name
			waitingForKey = false
		end
		return
	end
	if input.KeyCode == keybind then toggle() end
end)

-- [FIX #7] stopLag() forçait activated=false puis on le repassait à true manuellement.
-- On reconnecte la boucle directement sans toucher à `activated`.
LP.CharacterAdded:Connect(function()
	task.wait(1)
	if activated then
		if lagConn then lagConn:Disconnect(); lagConn = nil end
		startLag()
	end
end)
end)();  -- required semicolon (otherwise ambiguous merge with the (function() below)

-- ===================================================================
-- MOON LAGGER (source moon_lgr.txt — integrated as-is)
-- ===================================================================
(function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local ConfigFile = "MoonLaggerConfig.json"

local NIVELES = {
	Low   = { poder = 23 },
	Mid   = { poder = 32 },
	High  = { poder = 70 },
	Ultra = { poder = 90 }
}

local keybind = Enum.KeyCode.M
local listeningForInput = false
local laggerActive = false
local lagThread = nil
local nivelActual = "Low"
local ventanaBloqueada = false

local function SaveConfig()
	local data = { Nivel = nivelActual, Bloqueado = ventanaBloqueada }
	pcall(function() writefile(ConfigFile, HttpService:JSONEncode(data)) end)
end

-- [FIX #4] pcall(isfile, ConfigFile) retourne (bool, résultat) — pas le résultat
-- directement. L'ancien code appelait isfile() deux fois dont une non protégée.
local function LoadConfig()
	local ok, exists = pcall(isfile, ConfigFile)
	if not ok or not exists then return end
	local rok, content = pcall(readfile, ConfigFile)
	if not rok then return end
	pcall(function()
		local data = HttpService:JSONDecode(content)
		nivelActual      = data.Nivel     or "Low"
		ventanaBloqueada = data.Bloqueado or false
	end)
end
LoadConfig()

local function bomb(poder)
	local main, spam = {}, {{}}
	local z = spam[1]
	for i = 1, 25 do local t = {} table.insert(z, t) z = t end
	local max = math.min(12000, poder * 50)
	for i = 1, max do table.insert(main, spam) end
	pcall(function() game:GetService("RobloxReplicatedStorage").SetPlayerBlockList:FireServer(main) end)
end

-- ══════════════════════════════════════
-- CLEANUP
-- ══════════════════════════════════════
pcall(function() if CoreGui:FindFirstChild("MoonLagger_UI") then CoreGui.MoonLagger_UI:Destroy() end end)

-- ══════════════════════════════════════
-- SCREEN GUI
-- ══════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MoonLagger_UI"
if not pcall(function() screenGui.Parent = CoreGui end) then screenGui.Parent = player:WaitForChild("PlayerGui") end
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ResetOnSpawn = false

-- ══════════════════════════════════════
-- MAIN FRAME
-- ══════════════════════════════════════
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel = 1
mainFrame.BorderColor3 = Color3.fromRGB(50, 50, 50)
mainFrame.Size = UDim2.new(0, 200, 0, 88)
mainFrame.Position = UDim2.new(0.15, 0, 0.5, -44)
mainFrame.Parent = screenGui
mainFrame.Visible = false
_lgrBypassWidget = mainFrame
mainFrame.ClipsDescendants = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- MINIMIZE Button

-- STROKE
local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = Color3.fromRGB(60, 60, 60)
mainStroke.Thickness = 1.2
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Animated glow on the edge
task.spawn(function()
	while mainStroke.Parent do
		TweenService:Create(mainStroke, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Color = Color3.fromRGB(120, 120, 120), Thickness = 1.6
		}):Play()
		task.wait(2.1)
		TweenService:Create(mainStroke, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Color = Color3.fromRGB(40, 40, 40), Thickness = 1.2
		}):Play()
		task.wait(2.1)
	end
end)

-- ══════════════════════════════════════
-- RISING BLACK & WHITE BUBBLES
-- ══════════════════════════════════════
local bubbleColors = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(200, 200, 200),
	Color3.fromRGB(160, 160, 160),
	Color3.fromRGB(100, 100, 100),
	Color3.fromRGB(50, 50, 50),
}

local function spawnBubble()
	local size = math.random(3, 9)
	local bub = Instance.new("Frame", mainFrame)
	bub.Size = UDim2.new(0, size, 0, size)
	bub.Position = UDim2.new(math.random(5, 95) / 100, 0, 1, size)
	bub.BackgroundColor3 = bubbleColors[math.random(1, #bubbleColors)]
	bub.BackgroundTransparency = math.random(20, 55) / 100
	bub.BorderSizePixel = 0
	bub.ZIndex = 1
	Instance.new("UICorner", bub).CornerRadius = UDim.new(1, 0)
	local duration = math.random(20, 42) / 10
	TweenService:Create(bub, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Position = UDim2.new(bub.Position.X.Scale, 0, 0, -size - 2),
		BackgroundTransparency = 1
	}):Play()
	task.delay(duration + 0.1, function()
		pcall(function() bub:Destroy() end)
	end)
end

task.spawn(function()
	while mainFrame.Parent do
		task.wait(math.random(10, 28) / 100)
		pcall(spawnBubble)
	end
end)

-- ══════════════════════════════════════
-- CIRCLE WITH IMAGE (moon icon)
-- ══════════════════════════════════════
local iconCircle = Instance.new("ImageLabel", mainFrame)
iconCircle.Name = "IconCircle"
iconCircle.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
iconCircle.BackgroundTransparency = 0
iconCircle.Position = UDim2.new(0, 6, 0, 4)
iconCircle.Size = UDim2.new(0, 20, 0, 20)
iconCircle.Image = "rbxassetid://139714600005415"
iconCircle.ScaleType = Enum.ScaleType.Crop
iconCircle.ZIndex = 3
Instance.new("UICorner", iconCircle).CornerRadius = UDim.new(1, 0)
local iconCircleStroke = Instance.new("UIStroke", iconCircle)
iconCircleStroke.Color = Color3.fromRGB(70, 70, 70)
iconCircleStroke.Thickness = 1

-- ══════════════════════════════════════
-- "MOON LAGGER" TITLE
-- ══════════════════════════════════════
local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.new(0, 30, 0, 0)
titleLabel.Size = UDim2.new(0, 120, 0, 22)
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.Text = "MOON LAGGER"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextYAlignment = Enum.TextYAlignment.Center
titleLabel.ZIndex = 3
titleLabel.TextStrokeTransparency = 0
titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

-- Animated shimmer on the title
local shimmerLbl = Instance.new("TextLabel", mainFrame)
shimmerLbl.BackgroundTransparency = 1
shimmerLbl.Position = UDim2.new(0, 30, 0, 0)
shimmerLbl.Size = UDim2.new(0, 120, 0, 22)
shimmerLbl.Font = Enum.Font.GothamBlack
shimmerLbl.Text = "MOON LAGGER"
shimmerLbl.TextSize = 13
shimmerLbl.TextXAlignment = Enum.TextXAlignment.Left
shimmerLbl.TextYAlignment = Enum.TextYAlignment.Center
shimmerLbl.ZIndex = 4
shimmerLbl.ClipsDescendants = true
shimmerLbl.TextColor3 = Color3.fromRGB(220, 220, 220)

local shimmerGrad = Instance.new("UIGradient", shimmerLbl)
shimmerGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(160, 160, 160)),
	ColorSequenceKeypoint.new(0.3, Color3.fromRGB(220, 220, 220)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.7, Color3.fromRGB(220, 220, 220)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(160, 160, 160)),
})
shimmerGrad.Rotation = 0

task.spawn(function()
	while mainFrame.Parent do
		for i = 0, 1, 0.006 do
			if not mainFrame.Parent then break end
			shimmerGrad.Offset = Vector2.new(i, 0)
			task.wait(0.025)
		end
	end
end)

-- ══════════════════════════════════════
-- KEY & LOCK BUTTONS (top right)
-- ══════════════════════════════════════
local keybindButton = Instance.new("TextButton", mainFrame)
keybindButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
keybindButton.BackgroundTransparency = 0
keybindButton.Position = UDim2.new(1, -65, 0, 2)
keybindButton.Size = UDim2.new(0, 34, 0, 12)
keybindButton.Font = Enum.Font.GothamBlack
keybindButton.TextColor3 = Color3.fromRGB(200, 200, 200)
keybindButton.TextSize = 6
keybindButton.AutoButtonColor = false
keybindButton.ZIndex = 5
Instance.new("UICorner", keybindButton).CornerRadius = UDim.new(0, 5)
Instance.new("UIStroke", keybindButton).Color = Color3.fromRGB(55, 55, 55)

local lockButton = Instance.new("TextButton", mainFrame)
lockButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
lockButton.BackgroundTransparency = 0
lockButton.Position = UDim2.new(1, -29, 0, 2)
lockButton.Size = UDim2.new(0, 26, 0, 12)
lockButton.Font = Enum.Font.GothamBlack
lockButton.TextSize = 9
lockButton.TextColor3 = Color3.fromRGB(200, 200, 200)
lockButton.AutoButtonColor = false
lockButton.ZIndex = 5
Instance.new("UICorner", lockButton).CornerRadius = UDim.new(0, 5)
Instance.new("UIStroke", lockButton).Color = Color3.fromRGB(55, 55, 55)

-- ══════════════════════════════════════
-- "📈" LABEL (formerly "LAGGER")
-- ══════════════════════════════════════
local textLagger = Instance.new("TextLabel", mainFrame)
textLagger.BackgroundTransparency = 1
textLagger.Position = UDim2.new(0, 8, 0, 24)
textLagger.Size = UDim2.new(0, 65, 0, 18)
textLagger.Font = Enum.Font.GothamBlack
textLagger.Text = "📈"
textLagger.TextColor3 = Color3.fromRGB(200, 200, 200)
textLagger.TextSize = 14
textLagger.TextXAlignment = Enum.TextXAlignment.Left
textLagger.TextYAlignment = Enum.TextYAlignment.Center
textLagger.ZIndex = 3
textLagger.TextStrokeTransparency = 0
textLagger.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

-- ══════════════════════════════════════
-- TOGGLE SWITCH
-- ══════════════════════════════════════
local toggleContainer = Instance.new("Frame", mainFrame)
toggleContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
toggleContainer.Position = UDim2.new(1, -54, 0, 25)
toggleContainer.Size = UDim2.new(0, 46, 0, 18)
toggleContainer.ZIndex = 3
Instance.new("UICorner", toggleContainer).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", toggleContainer).Color = Color3.fromRGB(60, 60, 60)

local toggleBall = Instance.new("Frame", toggleContainer)
toggleBall.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
toggleBall.Size = UDim2.new(0, 14, 0, 14)
toggleBall.Position = UDim2.new(0, 2, 0.5, -7)
toggleBall.ZIndex = 4
Instance.new("UICorner", toggleBall).CornerRadius = UDim.new(1, 0)

local toggleClick = Instance.new("TextButton", toggleContainer)
toggleClick.BackgroundTransparency = 1
toggleClick.Size = UDim2.new(1, 0, 1, 0)
toggleClick.ZIndex = 5
toggleClick.Font = Enum.Font.GothamBlack
toggleClick.Text = "INACTIVE"
toggleClick.TextSize = 6
toggleClick.TextColor3 = Color3.fromRGB(180, 50, 50)
toggleClick.TextXAlignment = Enum.TextXAlignment.Center
toggleClick.TextYAlignment = Enum.TextYAlignment.Center
toggleClick.AutoButtonColor = false
Instance.new("UICorner", toggleClick).CornerRadius = UDim.new(1, 0)

-- ══════════════════════════════════════
-- SEPARATOR
-- ══════════════════════════════════════
local sep = Instance.new("Frame", mainFrame)
sep.Size = UDim2.new(1, -16, 0, 1)
sep.Position = UDim2.new(0, 8, 0, 47)
sep.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
sep.BorderSizePixel = 0
sep.ZIndex = 3

-- ══════════════════════════════════════
-- LEVEL SELECTOR — SLIDING PILLS STYLE
-- ══════════════════════════════════════
-- Selector container
local selectorFrame = Instance.new("Frame", mainFrame)
selectorFrame.Size = UDim2.new(1, -16, 0, 24)
selectorFrame.Position = UDim2.new(0, 8, 0, 52)
selectorFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
selectorFrame.BorderSizePixel = 0
selectorFrame.ZIndex = 3
Instance.new("UICorner", selectorFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", selectorFrame).Color = Color3.fromRGB(45, 45, 45)

-- Active pill (slides under the selection)
local activePill = Instance.new("Frame", selectorFrame)
activePill.Size = UDim2.new(0.25, -2, 1, -4)
activePill.Position = UDim2.new(0, 1, 0, 2)
activePill.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
activePill.BorderSizePixel = 0
activePill.ZIndex = 4
Instance.new("UICorner", activePill).CornerRadius = UDim.new(0, 6)

-- Animated stroke on the active pill
local pillStroke = Instance.new("UIStroke", activePill)
pillStroke.Color = Color3.fromRGB(200, 200, 200)
pillStroke.Thickness = 1
pillStroke.Transparency = 0.3

local LEVELS = {"Low", "Mid", "High", "Ultra"}
local LEVEL_COLORS = {
	Low   = Color3.fromRGB(80,  220, 100),
	Mid   = Color3.fromRGB(240, 220, 60),
	High  = Color3.fromRGB(230, 70,  70),
	Ultra = Color3.fromRGB(200, 150, 255),
}

local levelBtns = {}

for i, name in ipairs(LEVELS) do
	local btn = Instance.new("TextButton", selectorFrame)
	btn.Size = UDim2.new(0.25, 0, 1, 0)
	btn.Position = UDim2.new((i - 1) * 0.25, 0, 0, 0)
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBlack
	btn.Text = name:upper()
	btn.TextSize = 7
	btn.TextColor3 = Color3.fromRGB(130, 130, 130)
	btn.ZIndex = 6
	btn.AutoButtonColor = false
	levelBtns[name] = btn
end

-- TRYHARD TEXT (Ultra)
local tryhardText = Instance.new("TextLabel", mainFrame)
tryhardText.BackgroundTransparency = 1
tryhardText.Position = UDim2.new(0, 8, 0, 78)
tryhardText.Size = UDim2.new(0, 140, 0, 10)
tryhardText.Font = Enum.Font.GothamBlack
tryhardText.Text = "Only for tryhards"
tryhardText.TextColor3 = Color3.fromRGB(200, 150, 255)
tryhardText.TextSize = 7
tryhardText.TextXAlignment = Enum.TextXAlignment.Left
tryhardText.ZIndex = 3
tryhardText.Visible = false
tryhardText.TextStrokeTransparency = 0.5
tryhardText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

-- ══════════════════════════════════════
-- UPDATE FUNCTIONS
-- ══════════════════════════════════════
local function getPillXPos(levelName)
	for i, name in ipairs(LEVELS) do
		if name == levelName then
			return UDim2.new((i - 1) * 0.25, 1, 0, 2)
		end
	end
	return UDim2.new(0, 1, 0, 2)
end

local function actualizarBotonesNivel()
	-- Animate the pill toward the selection
	TweenService:Create(activePill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = getPillXPos(nivelActual)
	}):Play()
	-- Pill color = level color
	TweenService:Create(activePill, TweenInfo.new(0.15), {
		BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	}):Play()
	TweenService:Create(pillStroke, TweenInfo.new(0.15), {
		Color = LEVEL_COLORS[nivelActual]
	}):Play()
	-- Texts
	for name, btn in pairs(levelBtns) do
		if name == nivelActual then
			TweenService:Create(btn, TweenInfo.new(0.15), {
				TextColor3 = LEVEL_COLORS[nivelActual]
			}):Play()
		else
			TweenService:Create(btn, TweenInfo.new(0.15), {
				TextColor3 = Color3.fromRGB(100, 100, 100)
			}):Play()
		end
	end
	tryhardText.Visible = (nivelActual == "Ultra")
end

local function actualizarSwitch()
	if laggerActive then
		TweenService:Create(toggleBall, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Position = UDim2.new(1, -16, 0.5, -7),
			BackgroundColor3 = Color3.fromRGB(230, 230, 230)
		}):Play()
		TweenService:Create(toggleContainer, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		}):Play()
		toggleClick.Text = "ACTIVE"
		toggleClick.TextColor3 = Color3.fromRGB(80, 230, 100)
	else
		TweenService:Create(toggleBall, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0, 2, 0.5, -7),
			BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		}):Play()
		TweenService:Create(toggleContainer, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		}):Play()
		toggleClick.Text = "INACTIVE"
		toggleClick.TextColor3 = Color3.fromRGB(180, 50, 50)
	end
end

local function actualizarCandado()
	lockButton.Text = ventanaBloqueada and "🔒" or "🔓"
	lockButton.TextColor3 = ventanaBloqueada
		and Color3.fromRGB(255, 200, 60)
		or  Color3.fromRGB(160, 160, 160)
end

local function actualizarKeybindButton()
	if keybindButton then
		local display = keybind.Name
		if display:match("Button") then display = display:gsub("Button", "") end
		keybindButton.Text = "KEY: " .. display
	end
end

-- ══════════════════════════════════════
-- TOGGLE LAGGER
-- ══════════════════════════════════════
local function toggleLagger()
	laggerActive = not laggerActive
	actualizarSwitch()
	if laggerActive then
		if lagThread then task.cancel(lagThread) end
		lagThread = task.spawn(function()
			while laggerActive do
				pcall(function() game:GetService("NetworkClient"):SetOutgoingKBPSLimit(80000) end)
				bomb(NIVELES[nivelActual].poder)
				task.wait(0.18)
			end
		end)
	else
		if lagThread then task.cancel(lagThread); lagThread = nil end
	end
end

-- ══════════════════════════════════════
-- LEVEL BUTTON CONNECTIONS
-- ══════════════════════════════════════
for _, name in ipairs(LEVELS) do
	local btn = levelBtns[name]
	local n = name
	btn.MouseButton1Click:Connect(function()
		nivelActual = n
		actualizarBotonesNivel()
		SaveConfig()
	end)
end

-- ══════════════════════════════════════
-- TOGGLE CLICK
-- ══════════════════════════════════════
toggleClick.MouseButton1Click:Connect(toggleLagger)

-- ══════════════════════════════════════
-- KEYBIND
-- ══════════════════════════════════════
keybindButton.MouseButton1Click:Connect(function()
	if listeningForInput then return end
	listeningForInput = true
	keybindButton.Text = "KEY: ..."
	keybindButton.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
	keybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if listeningForInput then
		if gp then return end
		local newKey = nil
		if input.KeyCode ~= Enum.KeyCode.Unknown then newKey = input.KeyCode end
		if newKey then
			keybind = newKey
			actualizarKeybindButton()
			listeningForInput = false
			keybindButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			keybindButton.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
		return
	end
	if gp then return end
	if input.KeyCode == keybind then toggleLagger() end
end)

-- ══════════════════════════════════════
-- LOCK BUTTON
-- ══════════════════════════════════════
lockButton.MouseButton1Click:Connect(function()
	ventanaBloqueada = not ventanaBloqueada
	actualizarCandado()
	SaveConfig()
end)

-- ══════════════════════════════════════
-- DRAG
-- ══════════════════════════════════════
local isDragging, dragStart, startPos = false, nil, nil
mainFrame.InputBegan:Connect(function(input)
	if ventanaBloqueada then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = true; dragStart = input.Position; startPos = mainFrame.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not isDragging or ventanaBloqueada then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)
mainFrame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = false
	end
end)

-- ══════════════════════════════════════
-- INIT
-- ══════════════════════════════════════
actualizarKeybindButton()
actualizarCandado()
actualizarBotonesNivel()
actualizarSwitch()
end)()


-- ===================================================================
-- INITIALIZATION
-- ===================================================================
local _configLoaded = MH_load()   -- loads the config at startup
updateActiveBadge()               -- sync the small "active features" badge with real state
selectTab("Combat")
-- No save file: start Auto Steal immediately (it defaults to enabled).
-- When a save exists, MH_load already re-activates it via the toggles table.
if not _configLoaded and AutoSteal.Enabled then
	task.spawn(startAutoSteal)
end
-- Auto-save every 10s
task.spawn(function()
	while gui.Parent do
		task.wait(10)
		MH_save()
	end
end)

-- Immediate save if the player leaves / script is destroyed
LP.AncestryChanged:Connect(function()
	pcall(MH_save)
end)
game:GetService("Players").PlayerRemoving:Connect(function(p)
	if p == LP then pcall(MH_save) end
end)

end
_MH_buildUI()
