-- Image Load Test
local url      = "https://litter.catbox.moe/f94g9jip9pkgpeex.jpeg"
local filename = "moon_test.jpeg"

local gui = Instance.new("ScreenGui")
gui.Name = "ImgTest"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 320, 0, 220)
frame.Position = UDim2.new(0.5, -160, 0.5, -110)
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local img = Instance.new("ImageLabel", frame)
img.Size = UDim2.new(1, 0, 1, 0)
img.BackgroundTransparency = 1
img.Image = ""
img.ScaleType = Enum.ScaleType.Crop
Instance.new("UICorner", img).CornerRadius = UDim.new(0, 10)

local lbl = Instance.new("TextLabel", frame)
lbl.Size = UDim2.new(1, 0, 1, 0)
lbl.BackgroundTransparency = 1
lbl.Text = "Chargement..."
lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = 14

task.spawn(function()
	local ok, err = pcall(function()
		local data = game:HttpGet(url)
		writefile(filename, data)
		local assetId = getcustomasset(filename)
		img.Image = assetId
		lbl.Text = ""
	end)
	if not ok then
		lbl.Text = "Erreur:\n" .. tostring(err)
		lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
		lbl.TextSize = 11
	end
end)
