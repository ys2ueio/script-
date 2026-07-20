--[[
    test_antitpbat.lua — Script solo : Anti TP Bat (avec UI Enable/Disable)
    + fond d'écran plein écran avec debug de chargement.

    Teste ça en jeu. Si Anti TP Bat te convient, dis-le moi et je l'intègre
    proprement dans MoonHub_v16.lua (onglet Combat, à côté d'Anti Ragdoll).
]]

local Players      = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local LP = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "AntiTPBatTest"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
pcall(function()
	if syn and syn.protect_gui then syn.protect_gui(gui) end
	if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
	gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end

-- ===================================================================
-- FOND D'ÉCRAN — avec debug pour comprendre pourquoi rien ne s'affichait
-- ===================================================================
local BACKGROUND_ID = "rbxassetid://91640776333981"

-- Couleur de secours visible tout de suite (prouve que le script tourne
-- même si l'image met du temps à charger / est encore en modération)
local bgFallback = Instance.new("Frame", gui)
bgFallback.Name = "BgFallback"
bgFallback.Size = UDim2.new(1,0,1,0)
bgFallback.BackgroundColor3 = Color3.fromRGB(15,5,20)
bgFallback.BorderSizePixel = 0
bgFallback.ZIndex = 1

local bg = Instance.new("ImageLabel", gui)
bg.Name = "BgImage"
bg.Size = UDim2.new(1,0,1,0)
bg.BackgroundTransparency = 1
bg.Image = BACKGROUND_ID
bg.ImageTransparency = 0
bg.ScaleType = Enum.ScaleType.Crop
bg.ZIndex = 2

local overlay = Instance.new("Frame", gui)
overlay.Size = UDim2.new(1,0,1,0)
overlay.BackgroundColor3 = Color3.new(0,0,0)
overlay.BackgroundTransparency = 0.45
overlay.BorderSizePixel = 0
overlay.ZIndex = 3

-- Vérifie si l'image a vraiment une taille (0,0 = pas encore chargée / ID invalide / pas approuvée)
task.spawn(function()
	local ok, contentProvider = pcall(function() return game:GetService("ContentProvider") end)
	if ok and contentProvider then
		pcall(function() contentProvider:PreloadAsync({bg}) end)
	end
	task.wait(1.5)
	local sz = bg.AbsoluteSize
	if sz.X <= 1 or sz.Y <= 1 then
		warn("[BgTest] L'image ne semble pas avoir de taille après 1.5s — causes possibles :")
		warn("[BgTest]  1) L'asset est encore EN MODÉRATION sur Roblox (fréquent pour du contenu anime/violent, peut prendre de qq minutes à qq heures)")
		warn("[BgTest]  2) L'ID "..BACKGROUND_ID.." n'est pas un Decal/Image valide")
		warn("[BgTest]  3) Ton compte n'a pas les droits d'usage sur cet asset (Asset Privacy pas activé)")
	else
		print("[BgTest] Image chargée correctement, taille: "..tostring(sz))
	end
end)

-- ===================================================================
-- ANTI TP BAT
-- ===================================================================
local ATB = { conn = nil, active = false, lastPos = nil }
local ATB_JUMP_THRESHOLD = 18  -- studs en un seul frame = pull/TP hostile

local _selfTPGuardUntil = 0  -- pas utilisé ici (pas de self-TP dans ce test), gardé pour compat si tu colles ça dans le hub

function ATB:reset()
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	self.lastPos = root and root.Position or nil
end

local function startAntiTPBat()
	if ATB.conn then return end
	ATB.active = true
	ATB:reset()
	ATB.conn = RunService.Heartbeat:Connect(function()
		if not ATB.active then return end
		local char = LP.Character; if not char then ATB.lastPos = nil; return end
		local root = char:FindFirstChild("HumanoidRootPart"); if not root then ATB.lastPos = nil; return end
		if not ATB.lastPos then ATB.lastPos = root.Position; return end
		if tick() < _selfTPGuardUntil then
			ATB.lastPos = root.Position
			return
		end
		local delta = (root.Position - ATB.lastPos).Magnitude
		if delta > ATB_JUMP_THRESHOLD then
			pcall(function()
				root.CFrame = CFrame.new(ATB.lastPos) * (root.CFrame - root.CFrame.Position)
				root.AssemblyLinearVelocity = Vector3.zero
			end)
		else
			ATB.lastPos = root.Position
		end
	end)
end

local function stopAntiTPBat()
	ATB.active = false
	if ATB.conn then pcall(function() ATB.conn:Disconnect() end); ATB.conn = nil end
	ATB.lastPos = nil
end

-- ===================================================================
-- UI — panneau Enable/Disabled
-- ===================================================================
local C_BG   = Color3.fromRGB(10,10,14)
local C_MOON = Color3.fromRGB(90,160,255)
local C_ON   = Color3.fromRGB(20,45,80)
local C_OFF  = Color3.fromRGB(0,0,0)

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0,220,0,110)
panel.Position = UDim2.new(0.5,-110,0.5,-55)
panel.BackgroundColor3 = C_BG
panel.BorderSizePixel = 0
panel.Active = true
panel.ZIndex = 10
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,14)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = C_MOON
stroke.Thickness = 1.5
stroke.Transparency = 0.3

-- Drag
do
	local dragging, dragStart, startPos = false, nil, nil
	panel.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dragStart = inp.Position; startPos = panel.Position
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	panel.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local d = inp.Position - dragStart
			panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1,-20,0,26)
title.Position = UDim2.new(0,10,0,10)
title.BackgroundTransparency = 1
title.Text = "ANTI TP BAT"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBlack
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 11

local statusPill = Instance.new("Frame", panel)
statusPill.Size = UDim2.new(1,-20,0,40)
statusPill.Position = UDim2.new(0,10,0,44)
statusPill.BackgroundColor3 = C_OFF
statusPill.BorderSizePixel = 0
statusPill.ZIndex = 11
Instance.new("UICorner", statusPill).CornerRadius = UDim.new(0,10)

local statusBtn = Instance.new("TextButton", statusPill)
statusBtn.Size = UDim2.new(1,0,1,0)
statusBtn.BackgroundTransparency = 1
statusBtn.Text = "DISABLED"
statusBtn.TextColor3 = Color3.fromRGB(140,140,150)
statusBtn.Font = Enum.Font.GothamBlack
statusBtn.TextSize = 15
statusBtn.ZIndex = 12
statusBtn.AutoButtonColor = false

local enabled = false
local function refresh()
	if enabled then
		statusBtn.Text = "ENABLED"
		statusBtn.TextColor3 = C_MOON
		TweenService:Create(statusPill, TweenInfo.new(0.15), {BackgroundColor3 = C_ON}):Play()
	else
		statusBtn.Text = "DISABLED"
		statusBtn.TextColor3 = Color3.fromRGB(140,140,150)
		TweenService:Create(statusPill, TweenInfo.new(0.15), {BackgroundColor3 = C_OFF}):Play()
	end
end
statusBtn.MouseButton1Click:Connect(function()
	enabled = not enabled
	if enabled then startAntiTPBat() else stopAntiTPBat() end
	refresh()
end)

local closeBtn = Instance.new("TextButton", panel)
closeBtn.Size = UDim2.new(0,22,0,22)
closeBtn.Position = UDim2.new(1,-30,0,8)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.ZIndex = 11
closeBtn.MouseButton1Click:Connect(function()
	stopAntiTPBat()
	gui:Destroy()
end)

print("[AntiTPBatTest] Prêt — clique DISABLED pour activer.")
