--[[
    test_background.lua — Script solo pour tester un fond d'écran anime.

    À FAIRE AVANT DE LANCER :
    1. Uploade ton image sur https://create.roblox.com/dashboard/creations
       (onglet Decals) — Roblox modère l'image (généralement < 1 min).
    2. Récupère l'ID numérique de la Decal (ex: 18523491023).
    3. Remplace la valeur de BACKGROUND_ID ci-dessous.

    Pourquoi un rbxassetid est obligatoire :
    Roblox ImageLabel/ImageButton ne peuvent afficher QUE des images déjà
    uploadées sur leurs serveurs (rbxassetid://...). Il n'existe aucun moyen
    de charger une URL externe (Discord CDN, Imgur, etc.) directement dans
    l'UI — c'est une restriction de la plateforme, pas une limite du script.

    Une fois que ce test te convient, dis-moi et je l'intègre proprement
    dans MoonHub_v16.lua (probablement derrière le contenu du menu, avec
    un overlay sombre pour garder le texte lisible).
]]

-- ===================================================================
local BACKGROUND_ID = "rbxassetid://0"  -- ← remplace le 0 par ton vrai ID
local DIM_OVERLAY   = true              -- assombrit l'image pour lisibilité
local OVERLAY_ALPHA = 0.55              -- 0 = image brute, 1 = noir complet
-- ===================================================================

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "BgTest"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
	if syn and syn.protect_gui then syn.protect_gui(gui) end
	if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
	gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
end

-- Fond plein écran
local bg = Instance.new("ImageLabel", gui)
bg.Name = "BgImage"
bg.Size = UDim2.new(1, 0, 1, 0)
bg.Position = UDim2.new(0, 0, 0, 0)
bg.BackgroundTransparency = 1
bg.Image = BACKGROUND_ID
bg.ScaleType = Enum.ScaleType.Crop  -- remplit l'écran sans déformer, recadre
bg.ZIndex = 1

if DIM_OVERLAY then
	local overlay = Instance.new("Frame", gui)
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1 - OVERLAY_ALPHA
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 2
end

-- Bouton pour fermer le test (retire le fond)
local closeBtn = Instance.new("TextButton", gui)
closeBtn.Size = UDim2.new(0, 120, 0, 36)
closeBtn.Position = UDim2.new(1, -140, 0, 20)
closeBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
closeBtn.BackgroundTransparency = 0.1
closeBtn.Text = "Fermer test"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.ZIndex = 3
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

print("[BgTest] Fond chargé avec l'ID: " .. BACKGROUND_ID)
if BACKGROUND_ID == "rbxassetid://0" then
	warn("[BgTest] Tu as oublié de remplacer BACKGROUND_ID par ton vrai rbxassetid !")
end
