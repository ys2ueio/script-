-- MoonDuel_v4_void.lua | VOID rebuild on Ace base | usage strictly private and personal use
if _G["_MOON_V4_VOID"] then pcall(_G["_MOON_V4_VOID"]) end
local _destroy = {}
_G["_MOON_V4_VOID"] = function()
	for _, f in ipairs(_destroy) do pcall(f) end
end
local function reg(f) table.insert(_destroy, f) end

-- ====================================================================
-- ACE LOGIC CORE (verbatim functional base — services, security kernel,
-- state, speed/carry/lagger, aimbot/steal, keybinds, counters, config)
-- ====================================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
_G.AceIsMobile = true
_G.AceCursedResetRemote = _G.AceCursedResetRemote or nil
_G.AceCursedResetGuid = _G.AceCursedResetGuid or "f888ee6e-c86d-46e1-93d7-0639d6635d42"
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
if not _G.AceCursedResetRemote then
for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
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
function cursedInstaReset()
return _G.AceCursedInstaReset()
end
for _, name in ipairs({"AceDuelsAdaptReconstruct", "AdaptHubPolished", "CyberHub"}) do
local old = PlayerGui:FindFirstChild(name)
if old then old:Destroy() end
end
local NS = 59.5
local CS = 28.8
local LAGGER_SPEED = 29
local LAGGER_CARRY_SPEED = 15
local currentSpeedMode = "Normal"
autoCarrySpeedEnabled = false
setAutoCarrySpeedVisual = nil
_G.AceAutoCarryWasCarrying = false
_G.AceAutoCarrySavedMode = nil
local autoStealEnabled = false
local selectedStealMode = "Normal"
local autoStealRadius = 62
_G.AceStealRadii = _G.AceStealRadii or {Normal = 62, Semi = 9}
local autoStealRadiusBox = nil
local selectedAimbotMode = "Normal"
local AIMBOT_SPEED = 58
local LAGGER_AIMBOT_SPEED = 40
_G.AceAntiBypassAimbotSpeed = _G.AceAntiBypassAimbotSpeed or 58
if _G.AceAntiBypassLaggerAimbotSpeed == nil or tonumber(_G.AceAntiBypassLaggerAimbotSpeed) == 58 then _G.AceAntiBypassLaggerAimbotSpeed = 40 end
local autoSwingEnabled = false
local mirrorTPDownEnabled = false
_G.AceNormalAimbotOn = _G.AceNormalAimbotOn or false
_G.AceAntiBypassAimbotOn = _G.AceAntiBypassAimbotOn or false
local antiDesyncAutoSwingEnabled = false
_G.AceAntiDesyncAimbotOn = _G.AceAntiDesyncAimbotOn or false
local ANTI_DESYNC_AIMBOT_SPEED = 58
local batCounterEnabled = false
local medCounterEnabled = false
local antiKickEnabled = false
local setSafeModeVisual = nil
local autoResetOnMedEnabled = false
local espEnabled = false
local showTracerEnabled = false
local ragdollCountdownEnabled = false
local fpsBoostEnabled = false
local antiLagVisualEnabled = false
local nukeOptimiserEnabled = false
local fovEnabled = false
local fovValue = 70
local noCamCollisionEnabled = false
_G.AceNoPlayerCollisionEnabled = _G.AceNoPlayerCollisionEnabled or false
local customFontVisualEnabled = false
local skyTheme = "Off"
local setPlayerESPVisual = nil
local setTracerESPVisual = nil
local setRagdollCountdownVisual = nil
local setFPSBoostVisual = nil
local setAntiLagVisual = nil
local setNukeOptimiserVisual = nil
local setFOVVisual = nil
local setNoCamCollisionVisual = nil
_G.AceSetNoPlayerCollisionVisual = _G.AceSetNoPlayerCollisionVisual or nil
local setCustomFontVisual = nil
local skyValueLabel = nil
local autoLeftEnabled = false
local autoRightEnabled = false
local DEFAULT_SPEED_KEYBINDS = {
SpeedToggle = Enum.KeyCode.Q,
LaggerToggle = Enum.KeyCode.R,
DropBrainrot = Enum.KeyCode.X,
Aimbot = Enum.KeyCode.E,
AntiDesyncAimbot = Enum.KeyCode.V,
AutoLeft = Enum.KeyCode.Z,
AutoRight = Enum.KeyCode.C,
InstantReset = Enum.KeyCode.T,
ToggleUI = Enum.KeyCode.LeftControl,
}
local DEFAULT_TP_DOWN_KEYBIND = Enum.KeyCode.F
local speedKeybinds = {
SpeedToggle = DEFAULT_SPEED_KEYBINDS.SpeedToggle,
LaggerToggle = DEFAULT_SPEED_KEYBINDS.LaggerToggle,
DropBrainrot = DEFAULT_SPEED_KEYBINDS.DropBrainrot,
Aimbot = DEFAULT_SPEED_KEYBINDS.Aimbot,
AntiDesyncAimbot = DEFAULT_SPEED_KEYBINDS.AntiDesyncAimbot,
AutoLeft = DEFAULT_SPEED_KEYBINDS.AutoLeft,
AutoRight = DEFAULT_SPEED_KEYBINDS.AutoRight,
InstantReset = DEFAULT_SPEED_KEYBINDS.InstantReset,
ToggleUI = DEFAULT_SPEED_KEYBINDS.ToggleUI,
}
local speedKeybindButtons = {}
local listeningForSpeedKey = nil
local autoTPEnabled = false
local autoTPHeight = 20
local autoTPConn = nil
local autoTPLastRun = 0
local autoTPClickDebounce = false
local tpDownKeybind = Enum.KeyCode.F
local tpDownKeybindButton = nil
local listeningForTPDownKey = false
local keybindListenStartedAt = 0
local setAutoTPVisual = nil
local function doAutoTPDown(force)
local char=LP.Character;if not char then return end
local hrp=char:FindFirstChild("HumanoidRootPart");if not hrp then return end
local hum2=char:FindFirstChildOfClass("Humanoid");if not hum2 then return end
if not force then
if hum2.FloorMaterial~=Enum.Material.Air then return end
if hrp.Position.Y<autoTPHeight then return end
end
hrp.CFrame=CFrame.new(hrp.Position.X,-7.00,hrp.Position.Z)
*CFrame.Angles(0,select(2,hrp.CFrame:ToEulerAnglesYXZ()),0)
hrp.AssemblyLinearVelocity=Vector3.zero
end
local function _clearAutoTPConnection()
if autoTPConn then
pcall(function() autoTPConn:Disconnect() end)
pcall(function() task.cancel(autoTPConn) end)
autoTPConn = nil
end
end
local function startAutoTP()
autoTPEnabled = true
_clearAutoTPConnection()
autoTPLastRun = 0
autoTPConn = RunService.Heartbeat:Connect(function()
if not autoTPEnabled then
_clearAutoTPConnection()
return
end
local now = tick()
if now - autoTPLastRun < 0.1 then return end
autoTPLastRun = now
pcall(function() doAutoTPDown(false) end)
end)
if setAutoTPVisual then setAutoTPVisual(true) end
end
local function stopAutoTP()
autoTPEnabled = false
_clearAutoTPConnection()
if setAutoTPVisual then setAutoTPVisual(false) end
end
local function runTPFloor()
pcall(function() doAutoTPDown(true) end)
end
local function toggleAutoTP(on)
if on then
startAutoTP()
else
stopAutoTP()
end
saveAceConfig()
end
function _G.AceStopAutoTPForAction()
if autoTPEnabled then
stopAutoTP()
pcall(function() if setAutoTPVisual then setAutoTPVisual(false) end end)
pcall(saveAceConfig)
end
end
local dropBrainrotActive = false
local DROP_ASCEND_DURATION = 0.2
local DROP_ASCEND_SPEED = 150
local function runDropBrainrot()
if dropBrainrotActive then return end
if _G.AceStopAutoTPForAction then _G.AceStopAutoTPForAction() end
local char = LP.Character
if not char then return end
local root = char:FindFirstChild("HumanoidRootPart")
if not root then return end
dropBrainrotActive = true
local startTime = tick()
local dropConn
dropConn = RunService.Heartbeat:Connect(function()
local currentChar = LP.Character
local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
if not currentChar or not currentRoot then
if dropConn then dropConn:Disconnect() end
dropBrainrotActive = false
return
end
if tick() - startTime >= DROP_ASCEND_DURATION then
if dropConn then dropConn:Disconnect() end
local rayParams = RaycastParams.new()
rayParams.FilterDescendantsInstances = {currentChar}
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local rayResult = workspace:Raycast(currentRoot.Position, Vector3.new(0, -2000, 0), rayParams)
if rayResult then
local hum = currentChar:FindFirstChildOfClass("Humanoid")
local offset = (hum and hum.HipHeight or 2) + (currentRoot.Size.Y / 2)
currentRoot.CFrame = CFrame.new(currentRoot.Position.X, rayResult.Position.Y + offset, currentRoot.Position.Z)
currentRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
currentRoot.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end
dropBrainrotActive = false
return
end
currentRoot.Velocity = Vector3.new(currentRoot.Velocity.X, DROP_ASCEND_SPEED, currentRoot.Velocity.Z)
end)
end
local infJumpEnabled = false
local antiRagdollEnabled = false
local antiRagdollConn = nil
local unwalkEnabled = false
local unwalkSavedAnimate = nil
local hitHarderAnimEnabled = false
local hitHarderOriginalAnims = {}
local selectedAnimationPack = "OFF"
local AnimationPacks = {
["Zombie"] = {
idle = {{"rbxassetid://616158929", 1}, {"rbxassetid://616158929", 1}},
walk = "rbxassetid://616168032", run = "rbxassetid://616163682",
jump = "rbxassetid://616161997", fall = "rbxassetid://616157476", climb = "rbxassetid://616156119"
},
["Ninja"] = {
idle = {{"rbxassetid://656117400", 1}, {"rbxassetid://656117400", 1}},
walk = "rbxassetid://656121766", run = "rbxassetid://656118852",
jump = "rbxassetid://656117878", fall = "rbxassetid://656115606", climb = "rbxassetid://656114359"
},
["Knight"] = {
idle = {{"rbxassetid://657595757", 1}, {"rbxassetid://657595757", 1}},
walk = "rbxassetid://657552124", run = "rbxassetid://657564596",
jump = "rbxassetid://658409194", fall = "rbxassetid://657600338", climb = "rbxassetid://658360781"
},
["Elder"] = {
idle = {{"rbxassetid://845397899", 1}, {"rbxassetid://845397899", 1}},
walk = "rbxassetid://845403856", run = "rbxassetid://845386501",
jump = "rbxassetid://845398858", fall = "rbxassetid://845397673", climb = "rbxassetid://845392038"
},
["Levitate"] = {
idle = {{"rbxassetid://616006778", 1}, {"rbxassetid://616006778", 1}},
walk = "rbxassetid://616013216", run = "rbxassetid://616013216",
jump = "rbxassetid://616008936", fall = "rbxassetid://616005863", climb = "rbxassetid://616003713"
},
["Astronaut"] = {
idle = {{"rbxassetid://891621366", 1}, {"rbxassetid://891621366", 1}},
walk = "rbxassetid://891636393", run = "rbxassetid://891636393",
jump = "rbxassetid://891627522", fall = "rbxassetid://891617961", climb = "rbxassetid://891609353"
},
["Pirate"] = {
idle = {{"rbxassetid://750781874", 1}, {"rbxassetid://750781874", 1}},
walk = "rbxassetid://750785693", run = "rbxassetid://750783738",
jump = "rbxassetid://750782230", fall = "rbxassetid://750780242", climb = "rbxassetid://750779899"
},
["Toy"] = {
idle = {{"rbxassetid://782841498", 1}, {"rbxassetid://782841498", 1}},
walk = "rbxassetid://782843345", run = "rbxassetid://782842708",
jump = "rbxassetid://782847020", fall = "rbxassetid://782846423", climb = "rbxassetid://782843869"
},
["Vampire"] = {
idle = {{"rbxassetid://1083445855", 1}, {"rbxassetid://1083445855", 1}},
walk = "rbxassetid://1083473930", run = "rbxassetid://1083462077",
jump = "rbxassetid://1083455352", fall = "rbxassetid://1083443587", climb = "rbxassetid://1083439238"
},
["Werewolf"] = {
idle = {{"rbxassetid://1083195517", 1}, {"rbxassetid://1083195517", 1}},
walk = "rbxassetid://1083178339", run = "rbxassetid://1083216690",
jump = "rbxassetid://1083218792", fall = "rbxassetid://1083189019", climb = "rbxassetid://1083182000"
},
["Rthro"] = {
idle = {{"rbxassetid://2510196951", 1}, {"rbxassetid://2510196951", 1}},
walk = "rbxassetid://2510202577", run = "rbxassetid://2510198475",
jump = "rbxassetid://2510197830", fall = "rbxassetid://2510195892", climb = "rbxassetid://2510192778"
},
["Stylish"] = {
idle = {{"rbxassetid://616136790", 1}, {"rbxassetid://616136790", 1}},
walk = "rbxassetid://616146177", run = "rbxassetid://616140816",
jump = "rbxassetid://616139451", fall = "rbxassetid://616134815", climb = "rbxassetid://616133594"
},
}
local AnimationPackList = {"OFF", "Unwalk", "Hit Harder", "Zombie", "Ninja", "Knight", "Elder", "Levitate", "Astronaut", "Pirate", "Toy", "Vampire", "Werewolf", "Rthro", "Stylish"}
local AnimationPackIndex = 1
local OriginalAnims = {}
local enableUnwalk, disableUnwalk, enableHitHarderAnim, disableHitHarderAnim
local HIT_HARDER_ANIMS = {
idle1 = "rbxassetid://133806214992291",
idle2 = "rbxassetid://94970088341563",
walk = "rbxassetid://707897309",
run = "rbxassetid://707861613",
jump = "rbxassetid://116936326516985",
fall = "rbxassetid://116936326516985",
}
local function getAnimate(char)
char = char or LP.Character
return char and char:FindFirstChild("Animate") or nil
end
local function stopCurrentAnimations(char)
local hum = char and char:FindFirstChildOfClass("Humanoid")
if not hum then return end
for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
pcall(function() track:Stop(0) end)
end
end
local function backupAnimations(char)
local animate = getAnimate(char)
if not animate or next(OriginalAnims) ~= nil then return end
local function getId(obj) return obj and obj.AnimationId or nil end
OriginalAnims = {
idle1 = getId(animate.idle and animate.idle:FindFirstChild("Animation1")),
idle2 = getId(animate.idle and animate.idle:FindFirstChild("Animation2")),
walk = getId(animate.walk and animate.walk:FindFirstChild("WalkAnim")),
run = getId(animate.run and animate.run:FindFirstChild("RunAnim")),
jump = getId(animate.jump and animate.jump:FindFirstChild("JumpAnim")),
fall = getId(animate.fall and animate.fall:FindFirstChild("FallAnim")),
climb = getId(animate.climb and animate.climb:FindFirstChild("ClimbAnim")),
}
end
local function setAnimId(obj, id)
if obj and id then pcall(function() obj.AnimationId = id end) end
end
local function reloadAnimate(animate)
if not animate then return end
pcall(function()
animate.Disabled = true
task.wait()
animate.Disabled = false
end)
end
local function resetAnimations()
local char = LP.Character
local animate = getAnimate(char)
if not animate or next(OriginalAnims) == nil then return end
stopCurrentAnimations(char)
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), OriginalAnims.idle1)
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), OriginalAnims.idle2)
setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"), OriginalAnims.walk)
setAnimId(animate.run and animate.run:FindFirstChild("RunAnim"), OriginalAnims.run)
setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"), OriginalAnims.jump)
setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"), OriginalAnims.fall)
setAnimId(animate.climb and animate.climb:FindFirstChild("ClimbAnim"), OriginalAnims.climb)
reloadAnimate(animate)
end
local function applyAnimationPack(packName)
selectedAnimationPack = packName or "OFF"
if selectedAnimationPack ~= "Unwalk" and unwalkEnabled then
disableUnwalk()
end
if selectedAnimationPack ~= "Hit Harder" and hitHarderAnimEnabled then
hitHarderAnimEnabled = false
resetAnimations()
end
if selectedAnimationPack == "Unwalk" then
resetAnimations()
enableUnwalk()
return
end
if selectedAnimationPack == "Hit Harder" then
disableUnwalk()
enableHitHarderAnim()
return
end
if selectedAnimationPack == "OFF" then
resetAnimations()
return
end
local pack = AnimationPacks[selectedAnimationPack]
local char = LP.Character
local animate = getAnimate(char)
if not pack or not animate then return end
backupAnimations(char)
stopCurrentAnimations(char)
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), pack.idle[1][1])
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), pack.idle[2][1])
setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"), pack.walk)
setAnimId(animate.run and animate.run:FindFirstChild("RunAnim"), pack.run)
setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"), pack.jump)
setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"), pack.fall)
setAnimId(animate.climb and animate.climb:FindFirstChild("ClimbAnim"), pack.climb)
reloadAnimate(animate)
end
enableUnwalk = function()
unwalkEnabled = true
local char = LP.Character
local animate = getAnimate(char)
if animate then
if not unwalkSavedAnimate then
unwalkSavedAnimate = animate:Clone()
end
stopCurrentAnimations(char)
animate:Destroy()
end
end
disableUnwalk = function()
unwalkEnabled = false
local char = LP.Character
if char and not char:FindFirstChild("Animate") and unwalkSavedAnimate then
local newAnimate = unwalkSavedAnimate:Clone()
newAnimate.Parent = char
end
end
enableHitHarderAnim = function()
hitHarderAnimEnabled = true
local char = LP.Character
local animate = getAnimate(char)
if not animate then return end
backupAnimations(char)
stopCurrentAnimations(char)
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), HIT_HARDER_ANIMS.idle1)
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), HIT_HARDER_ANIMS.idle2)
setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"), HIT_HARDER_ANIMS.walk)
setAnimId(animate.run and animate.run:FindFirstChild("RunAnim"), HIT_HARDER_ANIMS.run)
setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"), HIT_HARDER_ANIMS.jump)
setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"), HIT_HARDER_ANIMS.fall)
reloadAnimate(animate)
end
disableHitHarderAnim = function()
hitHarderAnimEnabled = false
resetAnimations()
if selectedAnimationPack ~= "OFF" then
task.wait()
applyAnimationPack(selectedAnimationPack)
end
end
local function startAntiRagdoll()
if antiRagdollConn then return end
antiRagdollConn = RunService.Heartbeat:Connect(function()
if not antiRagdollEnabled then return end
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
local function setAntiRagdoll(on)
antiRagdollEnabled = on and true or false
if antiRagdollEnabled then
startAntiRagdoll()
else
stopAntiRagdoll()
end
end
_G.AceNormalInfJump = _G.AceNormalInfJump or {holdPressed=false, holdActive=false, controllerActive=false, mobilePressed=false, mobileActive=false, hooked={}}
function _G.AceStopNormalInfJumpHoldState()
local S = _G.AceNormalInfJump
S.holdPressed = false
S.holdActive = false
S.controllerActive = false
S.mobilePressed = false
S.mobileActive = false
end
function _G.AceApplyNormalInfJumpBoost(boost)
if not infJumpEnabled then return end
local char = LP.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
local hum = char and char:FindFirstChildOfClass("Humanoid")
if not root or not hum or hum.Health <= 0 then return end
root.Velocity = Vector3.new(root.Velocity.X, boost or 50, root.Velocity.Z)
end
UserInputService.JumpRequest:Connect(function()
_G.AceApplyNormalInfJumpBoost(50)
end)
UserInputService.InputBegan:Connect(function(input)
if UserInputService:GetFocusedTextBox() then return end
local S = _G.AceNormalInfJump
if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
S.holdPressed = true
task.delay(0.12, function()
if _G.AceNormalInfJump.holdPressed and infJumpEnabled then
_G.AceNormalInfJump.holdActive = true
_G.AceApplyNormalInfJumpBoost(50)
end
end)
elseif input.KeyCode == Enum.KeyCode.ButtonA and input.UserInputType.Name:match("^Gamepad") then
S.controllerActive = true
end
end)
UserInputService.InputEnded:Connect(function(input)
local S = _G.AceNormalInfJump
if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
S.holdPressed = false
S.holdActive = false
end
if input.KeyCode == Enum.KeyCode.ButtonA and input.UserInputType.Name:match("^Gamepad") then
S.controllerActive = false
end
end)
function _G.AceHookNormalInfMobileJumpButton(obj)
local S = _G.AceNormalInfJump
if not obj or obj.Name ~= "JumpButton" or not obj:IsA("GuiButton") or S.hooked[obj] then return end
S.hooked[obj] = true
obj.InputBegan:Connect(function(input)
if input.UserInputType ~= Enum.UserInputType.Touch or not infJumpEnabled then return end
_G.AceNormalInfJump.mobilePressed = true
task.delay(0.12, function()
if _G.AceNormalInfJump.mobilePressed and infJumpEnabled then
_G.AceNormalInfJump.mobileActive = true
_G.AceApplyNormalInfJumpBoost(50)
end
end)
end)
obj.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.Touch then
_G.AceNormalInfJump.mobilePressed = false
_G.AceNormalInfJump.mobileActive = false
end
end)
obj.AncestryChanged:Connect(function(_, parent)
if not parent then
_G.AceNormalInfJump.hooked[obj] = nil
_G.AceNormalInfJump.mobilePressed = false
_G.AceNormalInfJump.mobileActive = false
end
end)
end
for _, obj in ipairs(PlayerGui:GetDescendants()) do
_G.AceHookNormalInfMobileJumpButton(obj)
end
PlayerGui.DescendantAdded:Connect(function(obj)
task.defer(_G.AceHookNormalInfMobileJumpButton, obj)
end)
RunService.Heartbeat:Connect(function()
local S = _G.AceNormalInfJump
if infJumpEnabled and (S.holdActive or S.mobileActive or S.controllerActive) then
_G.AceApplyNormalInfJumpBoost(50)
end
end)
setInfJumpInternal = function(on)
infJumpEnabled = on and true or false
if not infJumpEnabled then
_G.AceStopNormalInfJumpHoldState()
end
end
local currentBackground = 0
local aceGuiScaleValue = 0.52
local aceProgressBarScaleValue = 0.83
CONFIG_FILE = "AceDuels_MainGUI_Config_DefaultsV2.json"
KEYBINDS_CONFIG_FILE = "AceDuels_Keybinds_DefaultsV2.json"
_ace_isfile = isfile or (syn and syn.isfile) or function(path)
local ok, result = pcall(function() return readfile(path) end)
return ok and result ~= nil
end
_ace_readfile = readfile or (syn and syn.readfile)
_ace_writefile = writefile or (syn and syn.writefile)
canSaveConfig = (type(_ace_readfile) == "function" and type(_ace_writefile) == "function")

--// Ace Duels Intro + Songs (ported from old source only)
selectedIntroMusic = selectedIntroMusic or 1
_introEnabled = (_introEnabled ~= false)
setIntroVisual = nil
setIntroSongVisual = nil
INTRO_MUSIC_OPTIONS = INTRO_MUSIC_OPTIONS or {
{name="Song 1", url="https://files.catbox.moe/mzvrir.mp3", file="AceDuelsIntroSong_1.mp3"},
{name="Song 2", url="https://files.catbox.moe/2a7jyx.mp3", file="AceDuelsIntroSong_2.mp3"},
{name="Song 3", url="https://files.catbox.moe/rcgr9f.mp3", file="AceDuelsIntroSong_3.mp3"},
{name="Song 4", url="https://files.catbox.moe/iknfuh.mp3", file="AceDuelsIntroSong_4.mp3"},
{name="Song 5", url="https://files.catbox.moe/6eigoh.mp3", file="AceDuelsIntroSong_5.mp3"},
{name="Song 6", url="https://files.catbox.moe/dvjtjk.mp3", file="AceDuelsIntroSong_6.mp3"},
{name="Song 7", url="https://files.catbox.moe/iyw1cb.mp3", file="AceDuelsIntroSong_7.mp3"},
}
function getIntroSongName()
local opt = INTRO_MUSIC_OPTIONS[selectedIntroMusic]
return opt and opt.name or "No Songs Added"
end
introPreviewSound = nil
introPlaybackSound = nil
introPreviewToken = 0
introPlaybackToken = 0
introSongCache = introSongCache or {}
introSongDownloading = introSongDownloading or {}
function stopIntroPreview()
introPreviewToken = introPreviewToken + 1
if introPreviewSound then
pcall(function() introPreviewSound:Stop() end)
pcall(function() introPreviewSound:Destroy() end)
introPreviewSound = nil
end
end
function stopIntroPlayback()
introPlaybackToken = introPlaybackToken + 1
if introPlaybackSound then
pcall(function() introPlaybackSound:Stop() end)
pcall(function() introPlaybackSound:Destroy() end)
introPlaybackSound = nil
end
end
function _safeNotify(msg)
if showActionNotification then pcall(function() showActionNotification(msg) end) end
end
function cacheIntroSong(option, allowDownload)
if not option or not option.url or option.url == "" then return nil end
if not (writefile and getcustomasset) then return nil end
local fileName = option.file or ("AceDuelsIntroSong_" .. tostring(option.name or "song") .. ".mp3")
local function loadExisting()
if introSongCache[fileName] then return introSongCache[fileName] end
local hasFile = false
pcall(function() hasFile = isfile and isfile(fileName) end)
if hasFile then
local ok = pcall(function() introSongCache[fileName] = getcustomasset(fileName) end)
if ok and introSongCache[fileName] then return introSongCache[fileName] end
end
return nil
end
local cached = loadExisting()
if cached then return cached end
if allowDownload == false then return nil end
if introSongDownloading[fileName] then
local waitStart = tick()
while introSongDownloading[fileName] and tick() - waitStart < 12 do task.wait(0.05) end
cached = loadExisting()
if cached then return cached end
end
introSongDownloading[fileName] = true
local ok = pcall(function()
local data = game:HttpGet(option.url)
if data and #data > 0 then
writefile(fileName, data)
introSongCache[fileName] = getcustomasset(fileName)
end
end)
introSongDownloading[fileName] = nil
if ok and introSongCache[fileName] then return introSongCache[fileName] end
return loadExisting()
end
function preloadIntroSongs()
task.spawn(function()
cacheIntroSong(INTRO_MUSIC_OPTIONS[selectedIntroMusic], true)
for _, option in ipairs(INTRO_MUSIC_OPTIONS) do
if option ~= INTRO_MUSIC_OPTIONS[selectedIntroMusic] then
cacheIntroSong(option, true)
task.wait(0.05)
end
end
end)
end
function makeIntroSoundFromId(soundId, name, parent)
if not soundId then return nil end
local sound = Instance.new("Sound")
sound.Name = name or "AceDuelsIntroMusic"
sound.Volume = 0.65
sound.Looped = false
sound.SoundId = soundId
sound.Parent = parent or SoundService
return sound
end
function createIntroSound(option, fileName, parent, allowDownload)
if not option then return nil end
local soundId = cacheIntroSong(option, allowDownload)
if not soundId then return nil end
return makeIntroSoundFromId(soundId, fileName, parent)
end
function previewIntroMusic(index)
stopIntroPreview()
stopIntroPlayback()
if not INTRO_MUSIC_OPTIONS[index] then _safeNotify("ADD SONG LINKS"); return end
local token = introPreviewToken
task.spawn(function()
local option = INTRO_MUSIC_OPTIONS[index]
local sound = createIntroSound(option, "AceDuelsIntroPreview_" .. tostring(token), SoundService, true)
if token ~= introPreviewToken then if sound then sound:Destroy() end; return end
introPreviewSound = sound
if not sound then _safeNotify("SONG LOADING..."); return end
sound.TimePosition = 0
pcall(function() sound:Play() end)
task.delay(15, function() if token == introPreviewToken then stopIntroPreview() end end)
end)
end
function playIntroMusic()
stopIntroPreview()
stopIntroPlayback()
if not _introEnabled then return end
local option = INTRO_MUSIC_OPTIONS[selectedIntroMusic]
if not option then return end
local token = introPlaybackToken
task.spawn(function()
local sound = createIntroSound(option, "AceDuelsIntroMusic_" .. tostring(token), SoundService, true)
if token ~= introPlaybackToken or not _introEnabled then if sound then pcall(function() sound:Destroy() end) end; return end
introPlaybackSound = sound
if not sound then _safeNotify("SONG FAILED"); return end
sound.TimePosition = 0
local loadStart = tick()
while sound and not sound.IsLoaded and tick() - loadStart < 10 do task.wait(0.05) end
pcall(function() sound:Play() end)
task.delay(15, function() if token == introPlaybackToken then stopIntroPlayback() end end)
end)
end
preloadIntroSongs()

savedConfig = {}
_G.AceGuiLocked = _G.AceGuiLocked == true
_G.AceHideMobileButtons = _G.AceHideMobileButtons == true
_G.AceMobileButtonScale = 0.75
_G.AceMobileButtonPositions = _G.AceMobileButtonPositions or {}
savedMainPositionTable = nil
savedMiniPositionTable = nil
function udim2ToTable(u)
return {xs = u.X.Scale, xo = u.X.Offset, ys = u.Y.Scale, yo = u.Y.Offset}
end
function tableToUDim2(t, fallback)
if type(t) == "table" then
return UDim2.new(tonumber(t.xs) or 0, tonumber(t.xo) or 0, tonumber(t.ys) or 0, tonumber(t.yo) or 0)
end
return fallback
end
function collectAceMobileButtonPositions()
local out = {}
for key, entry in pairs(_G.AceMobileButtonRefs or {}) do
local holder = entry and entry.holder
if holder then out[key] = udim2ToTable(holder.Position) end
end
if next(out) == nil and type(_G.AceMobileButtonPositions) == "table" then
return _G.AceMobileButtonPositions
end
_G.AceMobileButtonPositions = out
return out
end
function keyToString(key)
if not key then return "None" end
return tostring(key):gsub("Enum.KeyCode.", "")
end
function stringToKeyCode(value)
if type(value) ~= "string" or value == "" or value == "None" then return nil end
return Enum.KeyCode[value]
end
function keybindsToTable()
local out = {}
for keyId in pairs(DEFAULT_SPEED_KEYBINDS) do
out[keyId] = keyToString(speedKeybinds[keyId])
end
for keyId, key in pairs(speedKeybinds) do
out[keyId] = keyToString(key)
end
return out
end
function collectAceKeybindConfig()
return {
keybinds = keybindsToTable(),
tpDownKeybind = keyToString(tpDownKeybind),
}
end
function applySavedKeybinds(t)
if type(t) ~= "table" then return end
for keyId in pairs(speedKeybinds) do
if t[keyId] ~= nil then
speedKeybinds[keyId] = stringToKeyCode(t[keyId])
end
end
end
function applyDefaultAceKeybinds()
for keyId, key in pairs(DEFAULT_SPEED_KEYBINDS) do
speedKeybinds[keyId] = key
end
tpDownKeybind = DEFAULT_TP_DOWN_KEYBIND
end
function collectAceConfig()
return {
mainPosition = savedMainPositionTable,
keybinds = keybindsToTable(),
tpDownKeybind = keyToString(tpDownKeybind),
NS = NS,
CS = CS,
LAGGER_SPEED = LAGGER_SPEED,
LAGGER_CARRY_SPEED = LAGGER_CARRY_SPEED,
currentSpeedMode = currentSpeedMode,
autoCarrySpeedEnabled = autoCarrySpeedEnabled == true,
autoTPEnabled = autoTPEnabled,
autoTPHeight = autoTPHeight,
infJumpEnabled = infJumpEnabled,
antiRagdollEnabled = antiRagdollEnabled,
selectedAnimationPack = selectedAnimationPack,
selectedStealMode = selectedStealMode,
autoStealEnabled = autoStealEnabled,
autoStealRadius = autoStealRadius,
aceStealRadii = _G.AceStealRadii,
selectedAimbotMode = selectedAimbotMode,
AIMBOT_SPEED = AIMBOT_SPEED,
LAGGER_AIMBOT_SPEED = LAGGER_AIMBOT_SPEED,
ANTI_BYPASS_AIMBOT_SPEED = _G.AceAntiBypassAimbotSpeed,
ANTI_BYPASS_LAGGER_AIMBOT_SPEED = _G.AceAntiBypassLaggerAimbotSpeed,
ANTI_DESYNC_AIMBOT_SPEED = ANTI_DESYNC_AIMBOT_SPEED,
autoSwingEnabled = autoSwingEnabled,
mirrorTPDownEnabled = mirrorTPDownEnabled,
normalAimbotEnabled = _G.AceNormalAimbotOn == true,
antiBypassAimbotEnabled = _G.AceAntiBypassAimbotOn == true,
antiDesyncAutoSwingEnabled = antiDesyncAutoSwingEnabled,
antiDesyncAimbotEnabled = _G.AceAntiDesyncAimbotOn == true,
batCounterEnabled = batCounterEnabled,
medCounterEnabled = medCounterEnabled,
safeMode = antiKickEnabled == true,
autoResetOnMedEnabled = autoResetOnMedEnabled,
espEnabled = espEnabled,
showTracerEnabled = showTracerEnabled,
ragdollCountdownEnabled = ragdollCountdownEnabled,
fpsBoostEnabled = fpsBoostEnabled,
antiLagVisualEnabled = antiLagVisualEnabled,
nukeOptimiserEnabled = nukeOptimiserEnabled,
fovEnabled = fovEnabled,
fovValue = fovValue,
noCamCollisionEnabled = noCamCollisionEnabled,
noPlayerCollisionEnabled = _G.AceNoPlayerCollisionEnabled,
customFontVisualEnabled = false,
skyTheme = skyTheme,
autoLeftEnabled = autoLeftEnabled,
autoRightEnabled = autoRightEnabled,
currentBackground = currentBackground,
aceGuiScaleValue = aceGuiScaleValue,
aceProgressBarScaleValue = aceProgressBarScaleValue,
introEnabled = _introEnabled == true,
selectedIntroMusic = selectedIntroMusic,
guiLocked = _G.AceGuiLocked == true,
hideMobileButtons = _G.AceHideMobileButtons == true,
aceMobileButtonScale = _G.AceMobileButtonScale,
mobileButtonPositions = collectAceMobileButtonPositions(),
}
end
function saveAceConfig()
if not canSaveConfig then return end
pcall(function()
_ace_writefile(CONFIG_FILE, HttpService:JSONEncode(collectAceConfig()))
_ace_writefile(KEYBINDS_CONFIG_FILE, HttpService:JSONEncode(collectAceKeybindConfig()))
end)
end
function loadAceConfig()
if not canSaveConfig or not _ace_isfile(CONFIG_FILE) then return end
local ok, data = pcall(function()
return HttpService:JSONDecode(_ace_readfile(CONFIG_FILE))
end)
if not ok or type(data) ~= "table" then return end
savedConfig = data
local keybindData = data
pcall(function()
if _ace_isfile(KEYBINDS_CONFIG_FILE) then
local kb = HttpService:JSONDecode(_ace_readfile(KEYBINDS_CONFIG_FILE))
if type(kb) == "table" then keybindData = kb end
end
end)
savedMainPositionTable = data.mainPosition
savedMiniPositionTable = nil
_G.AceGuiLocked = data.guiLocked == true
_G.AceHideMobileButtons = data.hideMobileButtons == true
_G.AceMobileButtonScale = math.clamp(tonumber(data.aceMobileButtonScale) or tonumber(_G.AceMobileButtonScale) or 0.75, 0.30, 1.35)
_G.AceMobileButtonPositions = type(data.mobileButtonPositions) == "table" and data.mobileButtonPositions or {}
applySavedKeybinds(keybindData.keybinds)
if keybindData.tpDownKeybind ~= nil then
if tostring(keybindData.tpDownKeybind) == "None" then
tpDownKeybind = nil
else
tpDownKeybind = stringToKeyCode(keybindData.tpDownKeybind) or DEFAULT_TP_DOWN_KEYBIND
end
end
for keyId, defaultKey in pairs(DEFAULT_SPEED_KEYBINDS) do
local savedKeys = keybindData and keybindData.keybinds
if (not savedKeys or savedKeys[keyId] == nil) and speedKeybinds[keyId] == nil then
speedKeybinds[keyId] = defaultKey
end
end
NS = tonumber(data.NS) or NS
CS = tonumber(data.CS) or CS
LAGGER_SPEED = tonumber(data.LAGGER_SPEED) or LAGGER_SPEED
LAGGER_CARRY_SPEED = tonumber(data.LAGGER_CARRY_SPEED) or LAGGER_CARRY_SPEED
currentSpeedMode = data.currentSpeedMode or currentSpeedMode
if currentSpeedMode ~= "Normal" and currentSpeedMode ~= "Carry" and currentSpeedMode ~= "Lagger" and currentSpeedMode ~= "Lagger Carry" then currentSpeedMode = "Normal" end
autoCarrySpeedEnabled = data.autoCarrySpeedEnabled == true
autoTPEnabled = data.autoTPEnabled == true
autoTPHeight = tonumber(data.autoTPHeight) or autoTPHeight
infJumpEnabled = data.infJumpEnabled == true
antiRagdollEnabled = data.antiRagdollEnabled == true
selectedAnimationPack = data.selectedAnimationPack or selectedAnimationPack
selectedStealMode = data.selectedStealMode or selectedStealMode
if selectedStealMode ~= "Semi" then selectedStealMode = "Normal" end
autoStealEnabled = data.autoStealEnabled == true
if type(data.aceStealRadii) == "table" then
_G.AceStealRadii.Normal = tonumber(data.aceStealRadii.Normal) or _G.AceStealRadii.Normal or 62
_G.AceStealRadii.Semi = tonumber(data.aceStealRadii.Semi) or _G.AceStealRadii.Semi or 9
end
autoStealRadius = tonumber(data.autoStealRadius) or autoStealRadius
if selectedStealMode == "Normal" then
_G.AceStealRadii.Normal = tonumber(autoStealRadius) or _G.AceStealRadii.Normal or 62
autoStealRadius = _G.AceStealRadii.Normal
else
autoStealRadius = _G.AceStealRadii.Semi or 9
end
selectedAimbotMode = data.selectedAimbotMode or selectedAimbotMode
if selectedAimbotMode ~= "Anti Bypass" then selectedAimbotMode = "Normal" end
AIMBOT_SPEED = tonumber(data.AIMBOT_SPEED) or AIMBOT_SPEED
LAGGER_AIMBOT_SPEED = tonumber(data.LAGGER_AIMBOT_SPEED) or LAGGER_AIMBOT_SPEED
_G.AceAntiBypassAimbotSpeed = tonumber(data.ANTI_BYPASS_AIMBOT_SPEED) or _G.AceAntiBypassAimbotSpeed or 58
if data.ANTI_BYPASS_LAGGER_AIMBOT_SPEED == nil or tonumber(data.ANTI_BYPASS_LAGGER_AIMBOT_SPEED) == 58 then
_G.AceAntiBypassLaggerAimbotSpeed = 40
else
_G.AceAntiBypassLaggerAimbotSpeed = tonumber(data.ANTI_BYPASS_LAGGER_AIMBOT_SPEED) or 40
end
ANTI_DESYNC_AIMBOT_SPEED = tonumber(data.ANTI_DESYNC_AIMBOT_SPEED) or ANTI_DESYNC_AIMBOT_SPEED or 58
autoSwingEnabled = data.autoSwingEnabled == true
mirrorTPDownEnabled = data.mirrorTPDownEnabled == true
_G.AceNormalAimbotOn = data.normalAimbotEnabled == true
_G.AceAntiBypassAimbotOn = data.antiBypassAimbotEnabled == true
antiDesyncAutoSwingEnabled = data.antiDesyncAutoSwingEnabled == true
_G.AceAntiDesyncAimbotOn = data.antiDesyncAimbotEnabled == true
batCounterEnabled = data.batCounterEnabled == true
medCounterEnabled = data.medCounterEnabled == true
antiKickEnabled = data.safeMode == true
autoResetOnMedEnabled = data.autoResetOnMedEnabled == true
espEnabled = data.espEnabled == true
showTracerEnabled = data.showTracerEnabled == true
ragdollCountdownEnabled = data.ragdollCountdownEnabled == true
fpsBoostEnabled = data.fpsBoostEnabled == true
antiLagVisualEnabled = data.antiLagVisualEnabled == true
nukeOptimiserEnabled = data.nukeOptimiserEnabled == true
fovEnabled = data.fovEnabled == true
fovValue = tonumber(data.fovValue) or fovValue
noCamCollisionEnabled = data.noCamCollisionEnabled == true
_G.AceNoPlayerCollisionEnabled = data.noPlayerCollisionEnabled == true
customFontVisualEnabled = false
skyTheme = (type(data.skyTheme) == "string" and data.skyTheme) or skyTheme
autoLeftEnabled = data.autoLeftEnabled == true
autoRightEnabled = data.autoRightEnabled == true
if data.introEnabled ~= nil then _introEnabled = data.introEnabled == true end
if data.selectedIntroMusic and INTRO_MUSIC_OPTIONS[data.selectedIntroMusic] then selectedIntroMusic = data.selectedIntroMusic end
if autoLeftEnabled and autoRightEnabled then autoRightEnabled = false end
end
loadAceConfig()
local function syncAnimationPackIndex()
for i, name in ipairs(AnimationPackList) do
if name == selectedAnimationPack then
AnimationPackIndex = i
return
end
end
selectedAnimationPack = "OFF"
AnimationPackIndex = 1
end
local function applySavedAnimationPackToCharacter(char)
syncAnimationPackIndex()
if refreshAnimationPackRow then pcall(refreshAnimationPackRow) end
if not char then char = LP.Character end
if not char then return end
local animate = char:FindFirstChild("Animate") or char:WaitForChild("Animate", 6)
if not animate then return end
task.wait(0.2)
OriginalAnims = {}
unwalkSavedAnimate = nil
if selectedAnimationPack and selectedAnimationPack ~= "OFF" then
pcall(function() applyAnimationPack(selectedAnimationPack) end)
else
pcall(function() resetAnimations() end)
end
end
syncAnimationPackIndex()
task.defer(function()
applySavedAnimationPackToCharacter(LP.Character)
end)
LP.CharacterAdded:Connect(function(char)
task.wait(0.65)
applySavedAnimationPackToCharacter(char)
end)
_G.AceAutoResetOnMed = _G.AceAutoResetOnMed or {}
_G.AceAutoResetOnMed.conns = _G.AceAutoResetOnMed.conns or {}
_G.AceAutoResetOnMed.enabled = autoResetOnMedEnabled == true
_G.AceAutoResetOnMed.medTriggered = false
_G.AceAutoResetOnMed.lastFire = _G.AceAutoResetOnMed.lastFire or 0
_G.AceAutoResetOnMed.cooldown = 2.25
_G.AceAutoResetOnMed.charAddedConn = _G.AceAutoResetOnMed.charAddedConn
_G.AceCursedResetGuid = _G.AceCursedResetGuid or "f888ee6e-c86d-46e1-93d7-0639d6635d42"
_G.AceCursedResetRemote = _G.AceCursedResetRemote or nil
pcall(function()
if hookfunction and newcclosure and not _G.AceCursedResetHooked and not _G.AceAutoResetOnMed.remoteHooked then
_G.AceAutoResetOnMed.remoteHooked = true
local oldFire
oldFire = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
if not _G.AceCursedResetRemote
and typeof(self) == "Instance"
and self:IsA("RemoteEvent")
and self.Name:sub(1, 3) == "RE/" then
_G.AceCursedResetRemote = self
end
return oldFire(self, ...)
end))
end
end)
function _G.AceFindCursedResetRemote()
if _G.AceCursedResetRemote then return _G.AceCursedResetRemote end
for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
if desc:IsA("RemoteEvent") and desc.Name:sub(1, 3) == "RE/" then
_G.AceCursedResetRemote = desc
break
end
end
return _G.AceCursedResetRemote
end
function _G.AceAutoResetCursedInstaReset()
local remote = _G.AceFindCursedResetRemote and _G.AceFindCursedResetRemote() or _G.AceCursedResetRemote
if not remote then return end
local character = LP.Character
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if humanoid and humanoid.Health <= 0 then
pcall(function()
remote:FireServer(_G.AceCursedResetGuid, LP, "balloon")
end)
return
end
local resetDetected = false
local resetConns = {}
if humanoid then
table.insert(resetConns, humanoid.Died:Connect(function()
resetDetected = true
end))
table.insert(resetConns, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
if humanoid.Health <= 0 then
resetDetected = true
end
end))
end
if character then
table.insert(resetConns, character.AncestryChanged:Connect(function(_, parent)
if not parent then
resetDetected = true
end
end))
end
task.spawn(function()
for _ = 1, 10 do
if resetDetected then break end
pcall(function()
remote:FireServer(_G.AceCursedResetGuid, LP, "balloon")
end)
task.wait(0.05)
end
for _, conn in ipairs(resetConns) do
pcall(function()
conn:Disconnect()
end)
end
end)
end
function _G.AceAutoResetShouldFire(part)
local state = _G.AceAutoResetOnMed
if not state or not state.enabled then return false end
if state.medTriggered then return false end
if tick() - (state.lastFire or 0) < (state.cooldown or 2.25) then return false end
if not part or not part.Parent then return false end
if part:FindFirstAncestorOfClass("Tool") or part:FindFirstAncestorOfClass("Accessory") then
return false
end
return part.Anchored and part.Transparency == 1
end
function _G.AceAutoResetFireOnce(part)
if not _G.AceAutoResetShouldFire(part) then return end
local state = _G.AceAutoResetOnMed
state.medTriggered = true
state.lastFire = tick()
task.delay(2.3, function()
if state.enabled then
if _G.AceAutoResetCursedInstaReset then
_G.AceAutoResetCursedInstaReset()
elseif cursedInstaReset then
cursedInstaReset()
end
end
end)
end
function _G.AceAutoResetOnAnchorChanged(part)
return part:GetPropertyChangedSignal("Anchored"):Connect(function()
_G.AceAutoResetFireOnce(part)
end)
end
function _G.AceStopAutoResetOnMed()
local state = _G.AceAutoResetOnMed
if not state then return end
for _, conn in ipairs(state.conns or {}) do
pcall(function()
conn:Disconnect()
end)
end
state.conns = {}
state.medTriggered = false
end
function _G.AceStartAutoResetOnMed(char)
local state = _G.AceAutoResetOnMed
if not state then return end
_G.AceStopAutoResetOnMed()
state.medTriggered = false
char = char or LP.Character
if not char then return end
for _, part in ipairs(char:GetDescendants()) do
if part:IsA("BasePart") then
table.insert(state.conns, _G.AceAutoResetOnAnchorChanged(part))
_G.AceAutoResetFireOnce(part)
end
end
table.insert(state.conns, char.DescendantAdded:Connect(function(part)
if part:IsA("BasePart") then
table.insert(state.conns, _G.AceAutoResetOnAnchorChanged(part))
_G.AceAutoResetFireOnce(part)
end
end))
table.insert(state.conns, char.AncestryChanged:Connect(function(_, parent)
if not parent then
state.medTriggered = false
end
end))
end
function _G.AceEnableAutoResetOnMed()
autoResetOnMedEnabled = true
_G.AceAutoResetOnMed.enabled = true
_G.AceStartAutoResetOnMed(LP.Character)
end
function _G.AceDisableAutoResetOnMed()
autoResetOnMedEnabled = false
_G.AceAutoResetOnMed.enabled = false
_G.AceStopAutoResetOnMed()
end
function _G.AceSetAutoResetOnMed(state, noSave)
autoResetOnMedEnabled = state == true
if autoResetOnMedEnabled then
_G.AceEnableAutoResetOnMed()
else
_G.AceDisableAutoResetOnMed()
end
if setAutoResetOnMedVisual then
setAutoResetOnMedVisual(autoResetOnMedEnabled)
end
if not noSave and saveAceConfig then saveAceConfig() end
end
function enableAutoResetOnMed()
_G.AceSetAutoResetOnMed(true)
end
function disableAutoResetOnMed()
_G.AceSetAutoResetOnMed(false)
end
function toggleAutoResetOnMed(on)
_G.AceSetAutoResetOnMed(on == true)
end
if not _G.AceAutoResetOnMed.charAddedConn then
_G.AceAutoResetOnMed.charAddedConn = LP.CharacterAdded:Connect(function(char)
if _G.AceAutoResetOnMed and _G.AceAutoResetOnMed.enabled then
task.wait(0.25)
_G.AceStartAutoResetOnMed(char)
end
end)
end
_G.AceCounterState = _G.AceCounterState or {}
_G.AceCounterState.batConn = nil
_G.AceCounterState.batDebounce = false
_G.AceCounterState.medConns = _G.AceCounterState.medConns or {}
_G.AceCounterState.medDebounce = false
_G.AceCounterState.medLastUsed = _G.AceCounterState.medLastUsed or 0
_G.AceMedusaCooldown = 25
function _G.AceFindMedusa()
local c = LP.Character
if not c then return nil end
for _, t in ipairs(c:GetChildren()) do
if t:IsA("Tool") then
local n = t.Name:lower()
if n:find("medusa") or n:find("head") or n:find("stone") then return t end
end
end
local bp = LP:FindFirstChild("Backpack") or LP:FindFirstChildOfClass("Backpack")
if bp then
for _, t in ipairs(bp:GetChildren()) do
if t:IsA("Tool") then
local n = t.Name:lower()
if n:find("medusa") or n:find("head") or n:find("stone") then return t end
end
end
end
return nil
end
function _G.AceUseMedusaCounter()
if not medCounterEnabled then return end
if _G.AceCounterState.medDebounce then return end
if tick() - (_G.AceCounterState.medLastUsed or 0) < _G.AceMedusaCooldown then return end
local c = LP.Character
if not c then return end
_G.AceCounterState.medDebounce = true
local med = _G.AceFindMedusa()
if not med then
_G.AceCounterState.medDebounce = false
return
end
if med.Parent ~= c then
local hum = c:FindFirstChildOfClass("Humanoid")
if hum then pcall(function() hum:EquipTool(med) end) end
task.wait(0.05)
end
pcall(function() med:Activate() end)
_G.AceCounterState.medLastUsed = tick()
_G.AceCounterState.medDebounce = false
end
function _G.AceOnMedusaAnchorChanged(part)
return part:GetPropertyChangedSignal("Anchored"):Connect(function()
if medCounterEnabled and part.Anchored and part.Transparency == 1 then
_G.AceUseMedusaCounter()
end
end)
end
function _G.AceStartMedCounter(char)
_G.AceStopMedCounter()
char = char or LP.Character
if not char then return end
for _, part in ipairs(char:GetDescendants()) do
if part:IsA("BasePart") then
table.insert(_G.AceCounterState.medConns, _G.AceOnMedusaAnchorChanged(part))
end
end
table.insert(_G.AceCounterState.medConns, char.DescendantAdded:Connect(function(part)
if part:IsA("BasePart") then
table.insert(_G.AceCounterState.medConns, _G.AceOnMedusaAnchorChanged(part))
end
end))
end
function _G.AceStopMedCounter()
for _, c in pairs(_G.AceCounterState.medConns or {}) do
pcall(function() c:Disconnect() end)
end
_G.AceCounterState.medConns = {}
_G.AceCounterState.medDebounce = false
end
_G.AceBatCounterSlapList = {"Bat", "Slap", "Iron Slap", "Gold Slap", "Diamond Slap", "Emerald Slap", "Ruby Slap", "Dark Matter Slap", "Flame Slap", "Nuclear Slap", "Galaxy Slap", "Glitched Slap"}
function _G.AceFindBatForCounter()
local c = LP.Character
if not c then return nil end
local bp = LP:FindFirstChildOfClass("Backpack") or LP:FindFirstChild("Backpack")
for _, name in ipairs(_G.AceBatCounterSlapList) do
local t = c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
if t then return t end
end
for _, ch in ipairs(c:GetChildren()) do
if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
end
if bp then
for _, ch in ipairs(bp:GetChildren()) do
if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
end
end
return nil
end
function _G.AceSwingBatForCounter(bat, char)
if not bat or not char then return end
local hum = char:FindFirstChildOfClass("Humanoid")
if bat.Parent ~= char then
if hum then pcall(function() hum:EquipTool(bat) end) end
task.wait(0.05)
end
local remote = bat:FindFirstChildOfClass("RemoteEvent") or bat:FindFirstChildOfClass("RemoteFunction")
if remote and remote:IsA("RemoteEvent") then
pcall(function() remote:FireServer() end)
task.wait(0.15)
pcall(function() remote:FireServer() end)
else
pcall(function() bat:Activate() end)
task.wait(0.15)
pcall(function() bat:Activate() end)
end
end
function _G.AceCounterIsRagdoll(hum)
if not hum then return false end
local st = hum:GetState()
return st == Enum.HumanoidStateType.Physics
or st == Enum.HumanoidStateType.Ragdoll
or st == Enum.HumanoidStateType.FallingDown
or hum.PlatformStand == true
end
function _G.AceStartBatCounter()
if _G.AceCounterState.batConn then return end
_G.AceCounterState.batDebounce = false
_G.AceCounterState.batConn = RunService.Heartbeat:Connect(function()
if not batCounterEnabled then return end
if _G.AceCounterState.batDebounce then return end
local char = LP.Character
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid")
if not hum then return end
if _G.AceCounterIsRagdoll(hum) then
_G.AceCounterState.batDebounce = true
task.spawn(function()
local bat = _G.AceFindBatForCounter()
if bat then _G.AceSwingBatForCounter(bat, char) end
task.wait(0.5)
_G.AceCounterState.batDebounce = false
end)
end
end)
end
function _G.AceStopBatCounter()
if _G.AceCounterState.batConn then
_G.AceCounterState.batConn:Disconnect()
_G.AceCounterState.batConn = nil
end
_G.AceCounterState.batDebounce = false
end
startBatCounter = _G.AceStartBatCounter
stopBatCounter = _G.AceStopBatCounter
setupMedusaCounter = _G.AceStartMedCounter
stopMedusaCounter = _G.AceStopMedCounter
_G.AceNoPlayerCollisionState = _G.AceNoPlayerCollisionState or {connections = {}}
function _G.AceSetOtherPlayerCollision(state)
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LP and plr.Character then
for _, part in ipairs(plr.Character:GetDescendants()) do
if part:IsA("BasePart") then
pcall(function() part.CanCollide = state end)
end
end
end
end
end
function enableNoPlayerCollision()
if _G.AceNoPlayerCollisionState.running then return end
_G.AceNoPlayerCollisionEnabled = true
_G.AceNoPlayerCollisionState.running = true
for _, conn in ipairs(_G.AceNoPlayerCollisionState.connections or {}) do
pcall(function() conn:Disconnect() end)
end
_G.AceNoPlayerCollisionState.connections = {}
_G.AceSetOtherPlayerCollision(false)
table.insert(_G.AceNoPlayerCollisionState.connections, LP.CharacterAdded:Connect(function()
task.wait(0.5)
if _G.AceNoPlayerCollisionEnabled then _G.AceSetOtherPlayerCollision(false) end
end))
table.insert(_G.AceNoPlayerCollisionState.connections, Players.PlayerAdded:Connect(function(plr)
local c = plr.CharacterAdded:Connect(function()
task.wait(0.5)
if _G.AceNoPlayerCollisionEnabled then _G.AceSetOtherPlayerCollision(false) end
end)
table.insert(_G.AceNoPlayerCollisionState.connections, c)
end))
local collisionScanElapsed = 0
table.insert(_G.AceNoPlayerCollisionState.connections, RunService.Heartbeat:Connect(function(dt)
if not _G.AceNoPlayerCollisionEnabled then return end
collisionScanElapsed = collisionScanElapsed + (dt or 0)
if collisionScanElapsed < 0.25 then return end
collisionScanElapsed = 0
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LP and plr.Character then
for _, part in ipairs(plr.Character:GetDescendants()) do
if part:IsA("BasePart") and part.CanCollide == true then
pcall(function() part.CanCollide = false end)
end
end
end
end
end))
end
function disableNoPlayerCollision()
if not _G.AceNoPlayerCollisionState.running then
_G.AceNoPlayerCollisionEnabled = false
return
end
_G.AceNoPlayerCollisionEnabled = false
_G.AceNoPlayerCollisionState.running = false
for _, conn in ipairs(_G.AceNoPlayerCollisionState.connections or {}) do
pcall(function() conn:Disconnect() end)
end
_G.AceNoPlayerCollisionState.connections = {}
_G.AceSetOtherPlayerCollision(true)
end
function _G.AceSafeModeGetCountdownLabel()
local ok, label = pcall(function()
return LP.PlayerGui
and LP.PlayerGui:FindFirstChild("DuelsMachineTopFrame")
and LP.PlayerGui.DuelsMachineTopFrame:FindFirstChild("DuelsMachineTopFrame")
and LP.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame:FindFirstChild("Timer")
and LP.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame.Timer:FindFirstChild("Label")
end)
return (ok and label) or nil
end
function _G.AceSafeModeCountdownNumber(text)
local t = tostring(text or ""):upper():gsub("^%s+", ""):gsub("%s+$", "")
if t == "GO" or t == "START" or t == "READY" then return true end
local n = tonumber(t)
return n ~= nil and n >= 0 and n <= 10
end
function _G.AceSafeModeInDuelCountdown()
local label = _G.AceSafeModeGetCountdownLabel()
return label and _G.AceSafeModeCountdownNumber(label.Text) or false
end
_G.AceSafeModeBlockedTools = {
bat=true, slap=true, sword=true, gun=true, pistol=true, rifle=true,
medusa=true, hammer=true, axe=true, knife=true, katana=true, blade=true, fist=true,
}
function _G.AceSafeModeIsCarryableTool(tool)
if not tool or not tool:IsA("Tool") then return false end
local name = tool.Name:lower()
for word in pairs(_G.AceSafeModeBlockedTools) do
if name:find(word, 1, true) then return false end
end
return true
end
function _G.AceSafeModeHoldingBrainrot()
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
for _, name in ipairs({"Carrying", "IsCarrying", "Grabbed", "Holding", "StealHold", "HasGrab"}) do
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
function _G.AceSafeModeIsLocked()
if not antiKickEnabled then return false end
return _G.AceSafeModeInDuelCountdown() or _G.AceSafeModeHoldingBrainrot()
end
function _G.AceSafeModeForceStop(reason)
local stopped = false
if _G.AceNormalAimbotOn and _G.AceStopNormalAimbot then _G.AceStopNormalAimbot(); stopped = true end
if _G.AceAntiBypassAimbotOn and _G.AceStopAntiBypassAimbot then _G.AceStopAntiBypassAimbot(false); stopped = true end
if _G.AceAntiDesyncAimbotOn and _G.AceStopAntiDesyncAimbot then _G.AceStopAntiDesyncAimbot(); stopped = true end
if autoLeftEnabled then
autoLeftEnabled = false
if _G.AceSetAutoLeftVisual then _G.AceSetAutoLeftVisual(false) end
if _G.AceStopAutoLeft then _G.AceStopAutoLeft() end
stopped = true
end
if autoRightEnabled then
autoRightEnabled = false
if _G.AceSetAutoRightVisual then _G.AceSetAutoRightVisual(false) end
if _G.AceStopAutoRight then _G.AceStopAutoRight() end
stopped = true
end
if stopped and showActionNotification then pcall(function() showActionNotification(reason or "SAFE MODE LOCK") end) end
end
function _G.AceSafeModeTryStart()
if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
_G.AceSafeModeForceStop("SAFE MODE LOCK")
return false
end
return true
end
_G.AceSafeModeMonitorStarted = _G.AceSafeModeMonitorStarted or false
if not _G.AceSafeModeMonitorStarted then
_G.AceSafeModeMonitorStarted = true
RunService.Heartbeat:Connect(function()
if antiKickEnabled and _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
_G.AceSafeModeForceStop("SAFE MODE LOCK")
end
end)
end
LP.CharacterAdded:Connect(function(char)
task.wait(0.5)
if medCounterEnabled then _G.AceStartMedCounter(char) end
if batCounterEnabled then _G.AceStartBatCounter() end
end)
_G.AceNormalAimbot = _G.AceNormalAimbot or {conn = nil, target = nil, swingCooldown = false}
function _G.AceFindAimbotBat()
local char = LP.Character
if not char then return nil end
for _, tool in ipairs(char:GetChildren()) do
if tool:IsA("Tool") and (tool.Name:lower():find("bat") or tool.Name:lower():find("slap")) then
return tool
end
end
local bp = LP:FindFirstChild("Backpack")
if bp then
for _, tool in ipairs(bp:GetChildren()) do
if tool:IsA("Tool") and (tool.Name:lower():find("bat") or tool.Name:lower():find("slap")) then
return tool
end
end
end
return nil
end
function _G.AceGetClosestAimbotTarget()
local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
if not root then return nil end
local closest, minDist = nil, math.huge
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LP and plr.Character then
local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
local hum = plr.Character:FindFirstChildOfClass("Humanoid")
if tRoot and hum and hum.Health > 0 then
local dist = (tRoot.Position - root.Position).Magnitude
if dist < minDist then
minDist = dist
closest = tRoot
end
end
end
end
return closest
end
function _G.AceGetNormalAimbotSpeed()
if currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry" then
return tonumber(LAGGER_AIMBOT_SPEED) or 40
end
return tonumber(AIMBOT_SPEED) or 58
end
function _G.AceGetAntiBypassAimbotSpeed()
if currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry" then
return tonumber(_G.AceAntiBypassLaggerAimbotSpeed) or 40
end
return tonumber(_G.AceAntiBypassAimbotSpeed) or 58
end
function _G.AceGetSelectedAimbotSpeedValues()
if selectedAimbotMode == "Anti Bypass" then
return tonumber(_G.AceAntiBypassAimbotSpeed) or 58, tonumber(_G.AceAntiBypassLaggerAimbotSpeed) or 40
end
return tonumber(AIMBOT_SPEED) or 58, tonumber(LAGGER_AIMBOT_SPEED) or 40
end
function _G.AceSetSelectedAimbotSpeedValues(normalValue, laggerValue)
if selectedAimbotMode == "Anti Bypass" then
if normalValue then _G.AceAntiBypassAimbotSpeed = normalValue end
if laggerValue then _G.AceAntiBypassLaggerAimbotSpeed = laggerValue end
else
if normalValue then AIMBOT_SPEED = normalValue end
if laggerValue then LAGGER_AIMBOT_SPEED = laggerValue end
end
end
function _G.AceRefreshAimbotSpeedBoxes()
local n, l = _G.AceGetSelectedAimbotSpeedValues()
if _G.AceAimbotSpeedBox then _G.AceAimbotSpeedBox.Text = tostring(n) end
if _G.AceLaggerAimbotSpeedBox then _G.AceLaggerAimbotSpeedBox.Text = tostring(l) end
end
function _G.AceStartNormalAimbot()
if _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then return false end
if _G.AceStopAutoTPForAction then _G.AceStopAutoTPForAction() end
if _G.AceStopAntiBypassAimbot then _G.AceStopAntiBypassAimbot(false) end
_G.AceAntiBypassAimbotOn = false
_G.AceNormalAimbotOn = true
if _G.AceNormalAimbot.conn then
_G.AceNormalAimbot.conn:Disconnect()
_G.AceNormalAimbot.conn = nil
end
local hum0 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
if hum0 then hum0.AutoRotate = false end
_G.AceNormalAimbot.conn = RunService.RenderStepped:Connect(function()
if not _G.AceNormalAimbotOn or selectedAimbotMode ~= "Normal" then return end
local char = LP.Character
if not char then return end
local root = char:FindFirstChild("HumanoidRootPart")
if not root then return end
local hum = char:FindFirstChildOfClass("Humanoid")
if not hum then return end
local bat = char:FindFirstChildOfClass("Tool") or _G.AceFindAimbotBat()
if bat and bat.Parent ~= char then
pcall(function() hum:EquipTool(bat) end)
end
local target = _G.AceGetClosestAimbotTarget()
if not target then return end
_G.AceNormalAimbot.target = target
local targetVel = target.AssemblyLinearVelocity
local myPos = root.Position
local targetPos = target.Position
local predictPos = targetPos + targetVel * 0.14 + target.CFrame.LookVector * 0.3
local direction = predictPos - myPos
if direction.Magnitude < 0.01 then return end
local flatDir = Vector3.new(direction.X, 0, direction.Z)
if flatDir.Magnitude < 0.01 then return end
flatDir = flatDir.Unit
local chaseSpeed = _G.AceGetNormalAimbotSpeed()
local desiredHeight = targetPos.Y + 3.7
local yVel = (desiredHeight - myPos.Y) * 19.5 + targetVel.Y * 0.8
if hum.FloorMaterial ~= Enum.Material.Air then
yVel = math.max(yVel, 13)
end
yVel = math.clamp(yVel, -70, 110)
local desiredVel = Vector3.new(flatDir.X * chaseSpeed, yVel, flatDir.Z * chaseSpeed)
root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)
local speed3 = targetVel.Magnitude
local predictTime = math.clamp(speed3 / 150, 0.05, 0.2)
local predictedPos = targetPos + targetVel * predictTime
local toPredict = predictedPos - myPos
if toPredict.Magnitude > 0.1 then
local goalCF = CFrame.lookAt(myPos, predictedPos)
local diffCF = root.CFrame:Inverse() * goalCF
local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
rx = math.clamp(rx, -2.5, 2.5)
ry = math.clamp(ry, -2.5, 2.5)
rz = math.clamp(rz, -2.5, 2.5)
root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(Vector3.new(rx * 42, ry * 42, rz * 42))
end
if autoSwingEnabled and bat and not _G.AceNormalAimbot.swingCooldown then
_G.AceNormalAimbot.swingCooldown = true
pcall(function() bat:Activate() end)
task.delay(0.08, function()
if _G.AceNormalAimbot then _G.AceNormalAimbot.swingCooldown = false end
end)
end
end)
if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
end
function _G.AceStopNormalAimbot()
_G.AceNormalAimbotOn = false
if _G.AceNormalAimbot and _G.AceNormalAimbot.conn then
_G.AceNormalAimbot.conn:Disconnect()
_G.AceNormalAimbot.conn = nil
end
if _G.AceNormalAimbot then
_G.AceNormalAimbot.target = nil
_G.AceNormalAimbot.swingCooldown = false
end
local c = LP.Character
local root = c and c:FindFirstChild("HumanoidRootPart")
if root then
root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero
end
local hum2 = c and c:FindFirstChildOfClass("Humanoid")
if hum2 then hum2.AutoRotate = true end
if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
end
_G.AceAntiBypassAimbot = _G.AceAntiBypassAimbot or {conn = nil, swingCooldown = false, prevAutoRotate = nil}
_G.AceAntiBypassSlapList = _G.AceAntiBypassSlapList or {"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap"}
function _G.AceAntiBypassFindBat()
local char = LP.Character
if not char then return nil end
for _, name in ipairs(_G.AceAntiBypassSlapList) do
local t = char:FindFirstChild(name)
if t and t:IsA("Tool") then return t end
end
local bp = LP:FindFirstChildOfClass("Backpack")
if bp then
for _, name in ipairs(_G.AceAntiBypassSlapList) do
local t = bp:FindFirstChild(name)
if t and t:IsA("Tool") then
local hum = char:FindFirstChildOfClass("Humanoid")
if hum then pcall(function() hum:EquipTool(t) end) end
return t
end
end
end
for _, ch in ipairs(char:GetChildren()) do
if ch:IsA("Tool") and (ch.Name:lower():find("bat") or ch.Name:lower():find("slap")) then return ch end
end
return nil
end
function _G.AceAntiBypassTrySwing()
if _G.AceAntiBypassAimbot.swingCooldown then return end
_G.AceAntiBypassAimbot.swingCooldown = true
pcall(function()
local char = LP.Character
if not char then return end
local bat = _G.AceAntiBypassFindBat()
if bat then
if bat.Parent ~= char then
local hum = char:FindFirstChildOfClass("Humanoid")
if hum then pcall(function() hum:EquipTool(bat) end) end
end
pcall(function() bat:Activate() end)
end
end)
task.delay(0.35, function()
if _G.AceAntiBypassAimbot then _G.AceAntiBypassAimbot.swingCooldown = false end
end)
end
function _G.AceAntiBypassGetClosest()
local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
if not root then return nil, math.huge end
local closest, minDist = nil, math.huge
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LP and plr.Character then
local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
local hum = plr.Character:FindFirstChildOfClass("Humanoid")
if tRoot and hum and hum.Health > 0 then
local dist = (tRoot.Position - root.Position).Magnitude
if dist < minDist then
minDist = dist
closest = tRoot
end
end
end
end
return closest, minDist
end
function _G.AceStartAntiBypassAimbot()
if _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then return false end
if _G.AceStopAutoTPForAction then _G.AceStopAutoTPForAction() end
if _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end
_G.AceAntiBypassAimbotOn = true
selectedAimbotMode = "Anti Bypass"
if _G.AceAntiBypassAimbot.conn then
_G.AceAntiBypassAimbot.conn:Disconnect()
_G.AceAntiBypassAimbot.conn = nil
end
local hum0 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
if hum0 then
if _G.AceAntiBypassAimbot.prevAutoRotate == nil then _G.AceAntiBypassAimbot.prevAutoRotate = hum0.AutoRotate end
hum0.AutoRotate = false
end
_G.AceAntiBypassAimbot.conn = RunService.RenderStepped:Connect(function()
if not _G.AceAntiBypassAimbotOn or selectedAimbotMode ~= "Anti Bypass" then return end
local char = LP.Character
if not char then return end
local root = char:FindFirstChild("HumanoidRootPart")
if not root then return end
local hum = char:FindFirstChildOfClass("Humanoid")
if not hum then return end
if not char:FindFirstChildOfClass("Tool") then
local bat = _G.AceAntiBypassFindBat()
if bat then pcall(function() hum:EquipTool(bat) end) end
end
local target, targetDist = _G.AceAntiBypassGetClosest()
if not target then return end
local myPos = root.Position
local targetPos = target.Position
local direction = targetPos - myPos
local flatDir = Vector3.new(direction.X, 0, direction.Z)
if flatDir.Magnitude > 0 then flatDir = flatDir.Unit else flatDir = Vector3.zero end
local chaseSpeed = _G.AceGetAntiBypassAimbotSpeed()
local desiredHeight = targetPos.Y + 3.7
local yVel = (desiredHeight - myPos.Y) * 19.5
if hum.FloorMaterial ~= Enum.Material.Air then yVel = math.max(yVel, 13) end
yVel = math.clamp(yVel, -70, 110)
local desiredVel = Vector3.new(flatDir.X * chaseSpeed, yVel, flatDir.Z * chaseSpeed)
root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)
local toTarget = targetPos - myPos
if toTarget.Magnitude > 0.1 then
local goalCF = CFrame.lookAt(myPos, targetPos)
local diffCF = root.CFrame:Inverse() * goalCF
local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
rx = math.clamp(rx, -2.5, 2.5)
ry = math.clamp(ry, -2.5, 2.5)
rz = math.clamp(rz, -2.5, 2.5)
root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(Vector3.new(rx * 42, ry * 42, rz * 42))
end
if autoSwingEnabled and targetDist <= 8 then _G.AceAntiBypassTrySwing() end
end)
if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
end
function _G.AceStopAntiBypassAimbot(keepVisual)
_G.AceAntiBypassAimbotOn = false
if _G.AceAntiBypassAimbot and _G.AceAntiBypassAimbot.conn then
_G.AceAntiBypassAimbot.conn:Disconnect()
_G.AceAntiBypassAimbot.conn = nil
end
if _G.AceAntiBypassAimbot then _G.AceAntiBypassAimbot.swingCooldown = false end
local c = LP.Character
local root = c and c:FindFirstChild("HumanoidRootPart")
if root then
root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero
end
local hum = c and c:FindFirstChildOfClass("Humanoid")
if hum then
hum.AutoRotate = (_G.AceAntiBypassAimbot.prevAutoRotate == nil) and true or _G.AceAntiBypassAimbot.prevAutoRotate
hum.PlatformStand = false
pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
end
if _G.AceAntiBypassAimbot then _G.AceAntiBypassAimbot.prevAutoRotate = nil end
if keepVisual ~= false and _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
end
function _G.AceToggleSelectedAimbot()
if selectedAimbotMode == "Anti Bypass" then
if _G.AceAntiBypassAimbotOn then
if _G.AceStopAntiBypassAimbot then _G.AceStopAntiBypassAimbot() else _G.AceAntiBypassAimbotOn = false end
else
if _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end
if _G.AceStartAntiBypassAimbot then _G.AceStartAntiBypassAimbot() else _G.AceAntiBypassAimbotOn = true end
end
else
if _G.AceNormalAimbotOn then
_G.AceStopNormalAimbot()
else
if _G.AceStopAntiBypassAimbot then _G.AceStopAntiBypassAimbot(false) else _G.AceAntiBypassAimbotOn = false end
_G.AceStartNormalAimbot()
end
end
if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
saveAceConfig()
end
function _G.AceRefreshAimbotVisual()
if _G.AceAimbotSetVisual then
if selectedAimbotMode == "Anti Bypass" then
_G.AceAimbotSetVisual(_G.AceAntiBypassAimbotOn == true)
else
_G.AceAimbotSetVisual(_G.AceNormalAimbotOn == true)
end
end
end
_G.AceNormalAimbotStart = _G.AceStartNormalAimbot
_G.AceNormalAimbotStop = _G.AceStopNormalAimbot
_G.AceAntiBypassStart = _G.AceStartAntiBypassAimbot
_G.AceAntiBypassStop = _G.AceStopAntiBypassAimbot

-- Mirror TP Down: mirror a 3-stud opponent drop while Normal, Anti Bypass, or Anti Desync Bat is active.
local MIRROR_TP_DROP_THRESHOLD = 3
local MIRROR_TP_DOWN_Y = -7.00
local mirrorTPPreviousY = {}
local mirrorTPLastTeleport = 0

local function mirrorTPAimbotActive()
return (_G.AceNormalAimbotOn == true) or (_G.AceAntiBypassAimbotOn == true) or (_G.AceAntiDesyncAimbotOn == true)
end

local function mirrorTPTeleportDown()
local character = LP.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if not root or not humanoid or humanoid.Health <= 0 then return end
local now = tick()
if now - mirrorTPLastTeleport < 0.08 then return end
mirrorTPLastTeleport = now
local _, yaw = root.CFrame:ToEulerAnglesYXZ()
root.CFrame = CFrame.new(root.Position.X, MIRROR_TP_DOWN_Y, root.Position.Z) * CFrame.Angles(0, yaw, 0)
root.Velocity = Vector3.zero
pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
end

RunService.Heartbeat:Connect(function()
if not mirrorTPDownEnabled or not mirrorTPAimbotActive() then
table.clear(mirrorTPPreviousY)
return
end
for _, player in ipairs(Players:GetPlayers()) do
if player ~= LP and player.Character then
local root = player.Character:FindFirstChild("HumanoidRootPart")
if root then
local currentY = root.Position.Y
local previousY = mirrorTPPreviousY[player.UserId]
if previousY and previousY - currentY >= MIRROR_TP_DROP_THRESHOLD then
pcall(mirrorTPTeleportDown)
table.clear(mirrorTPPreviousY)
if type(showActionNotification) == "function" then
pcall(function() showActionNotification("MIRROR TP!") end)
end
return
end
mirrorTPPreviousY[player.UserId] = currentY
end
end
end
end)

function _G.AceSetMirrorTPDown(enabled)
mirrorTPDownEnabled = enabled == true
if not mirrorTPDownEnabled then table.clear(mirrorTPPreviousY) end
if _G.AceMirrorTPDownSetVisual then _G.AceMirrorTPDownSetVisual(mirrorTPDownEnabled) end
end
_G.AceAntiDesync = _G.AceAntiDesync or {conn = nil, hittingCooldown = false, h = nil, hrp = nil}
function _G.AceAntiDesyncGetBat()
local char = LP.Character
if not char then return nil end
local tool = char:FindFirstChild("Bat")
if tool then return tool end
local bp2 = LP:FindFirstChild("Backpack")
if bp2 then
tool = bp2:FindFirstChild("Bat")
if tool then
tool.Parent = char
return tool
end
end
return nil
end
function _G.AceAntiDesyncTrySwing()
if not _G.AceAntiDesync then return end
if _G.AceAntiDesync.hittingCooldown then return end
_G.AceAntiDesync.hittingCooldown = true
pcall(function()
local bat = _G.AceAntiDesyncGetBat()
if bat then
bat:Activate()
local ev = bat:FindFirstChildWhichIsA("RemoteEvent")
if ev then ev:FireServer() end
end
end)
task.delay(0.08, function()
if _G.AceAntiDesync then
_G.AceAntiDesync.hittingCooldown = false
end
end)
end
function _G.AceAntiDesyncGetClosestPlayer()
local hrp = _G.AceAntiDesync and _G.AceAntiDesync.hrp
if not hrp then return nil, math.huge end
local cp, cd = nil, math.huge
for _, p in pairs(Players:GetPlayers()) do
if p ~= LP and p.Character then
local tr = p.Character:FindFirstChild("HumanoidRootPart")
if tr then
local d = (hrp.Position - tr.Position).Magnitude
if d < cd then
cd = d
cp = p
end
end
end
end
return cp, cd
end
function _G.AceAntiDesyncSetupChar(char)
task.wait(0.1)
if not _G.AceAntiDesync then return end
_G.AceAntiDesync.h = char and char:WaitForChild("Humanoid", 5) or nil
_G.AceAntiDesync.hrp = char and char:WaitForChild("HumanoidRootPart", 5) or nil
end
LP.CharacterAdded:Connect(function(char)
pcall(function()
_G.AceAntiDesyncSetupChar(char)
end)
end)
if LP.Character then
task.spawn(function()
pcall(function()
_G.AceAntiDesyncSetupChar(LP.Character)
end)
end)
end
function _G.AceStartAntiDesyncAimbot()
if _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then return false end
if _G.AceStopAutoTPForAction then _G.AceStopAutoTPForAction() end
if _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end
if _G.AceStopAntiBypassAimbot then _G.AceStopAntiBypassAimbot(false) end
_G.AceAntiDesyncAimbotOn = true
if _G.AceAntiDesync.conn then
_G.AceAntiDesync.conn:Disconnect()
_G.AceAntiDesync.conn = nil
end
if LP.Character then
pcall(function()
_G.AceAntiDesyncSetupChar(LP.Character)
end)
end
_G.AceAntiDesync.conn = RunService.Heartbeat:Connect(function()
if not (_G.AceAntiDesyncAimbotOn and _G.AceAntiDesync.h and _G.AceAntiDesync.hrp) then return end
local target, dist = _G.AceAntiDesyncGetClosestPlayer()
_aimbotTargetPlr = target
_G.AceCurrentAimbotTarget = target
_G.AceAntiDesyncBatTarget = target
if target and target.Character then
local tr = target.Character:FindFirstChild("HumanoidRootPart")
if tr then
if sethiddenproperty then
pcall(function()
sethiddenproperty(_G.AceAntiDesync.hrp, "PhysicsRepRootPart", tr)
end)
end
local targetPos = tr.Position + Vector3.new(0, 0.9, 0)
if (_G.AceAntiDesync.hrp.Position - targetPos).Magnitude > 8 then
_G.AceAntiDesync.hrp.CFrame = CFrame.new(targetPos)
end
local cam = workspace.CurrentCamera
if cam then
cam.CFrame = CFrame.new(cam.CFrame.Position, tr.Position)
end
if antiDesyncAutoSwingEnabled or autoSwingEnabled then
_G.AceAntiDesyncTrySwing()
end
end
end
end)
if _G.AceAntiDesyncSetVisual then _G.AceAntiDesyncSetVisual(true) end
saveAceConfig()
return true
end
function _G.AceStopAntiDesyncAimbot()
_G.AceAntiDesyncAimbotOn = false
if _G.AceAntiDesync and _G.AceAntiDesync.conn then
_G.AceAntiDesync.conn:Disconnect()
_G.AceAntiDesync.conn = nil
end
if _G.AceAntiDesync then
_G.AceAntiDesync.hittingCooldown = false
end
_G.AceAntiDesyncBatTarget = nil
if _G.AceCurrentAimbotTarget == _aimbotTargetPlr then _G.AceCurrentAimbotTarget = nil end
_aimbotTargetPlr = nil
if _G.AceAntiDesyncSetVisual then _G.AceAntiDesyncSetVisual(false) end
saveAceConfig()
end
function _G.AceToggleAntiDesyncAimbot()
if _G.AceAntiDesyncAimbotOn then
_G.AceStopAntiDesyncAimbot()
else
_G.AceStartAntiDesyncAimbot()
end
end
_G.__AceSetupNormalAutoSteal = function()
_G.AceNormalSteal = _G.AceNormalSteal or {
enabled = false,
radius = 62,
duration = 1.3,
animals = {},
promptCache = {},
internalCache = {},
scannerStarted = false,
scanning = false,
isStealing = false,
stealConn = nil,
refreshThread = nil,
lastSteal = 0,
cooldown = 0.08,
}
if _G.AceNormalSteal.stealConn then pcall(function() _G.AceNormalSteal.stealConn:Disconnect() end); _G.AceNormalSteal.stealConn = nil end
_G.AceNormalSteal.enabled = false
_G.AceNormalSteal.isStealing = false
local function barProgress(p)
p = math.clamp(tonumber(p) or 0, 0, 1)
pcall(function()
if _G.StealBar then
_G.StealBar.SetState("STEALING")
_G.StealBar.SetProgress(p)
end
end)
end
local function resetBar()
pcall(function()
if _G.StealBar then _G.StealBar.Reset() end
end)
end
local function getRoot()
local char = LP.Character
if not char then return nil end
return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end
local function isMyBase(plotName)
local plots = workspace:FindFirstChild("Plots")
local plot = plots and plots:FindFirstChild(plotName)
if not plot then return false end
local sign = plot:FindFirstChild("PlotSign")
local yourBase = sign and sign:FindFirstChild("YourBase")
return yourBase and yourBase:IsA("BillboardGui") and yourBase.Enabled == true
end
local function scanPlots()
local a = _G.AceNormalSteal
a.animals = {}
local plots = workspace:FindFirstChild("Plots")
if not plots then return end
for _, plot in ipairs(plots:GetChildren()) do
if plot:IsA("Model") and not isMyBase(plot.Name) then
local podiums = plot:FindFirstChild("AnimalPodiums")
if podiums then
for _, podium in ipairs(podiums:GetChildren()) do
if podium:IsA("Model") then
local base = podium:FindFirstChild("Base")
local spawn = base and base:FindFirstChild("Spawn")
if spawn then
table.insert(a.animals, {
plot = plot.Name,
slot = podium.Name,
worldPosition = spawn.Position,
uid = plot.Name .. "_" .. podium.Name,
})
end
end
end
end
end
end
end
local function ensureScanner()
local a = _G.AceNormalSteal
if a.scannerStarted then return end
a.scannerStarted = true
task.spawn(function()
task.wait(1)
while _G.AceNormalSteal do
if _G.AceNormalSteal.enabled then
pcall(scanPlots)
end
task.wait(3)
end
end)
end
local function findPrompt(data)
if not data then return nil end
local a = _G.AceNormalSteal
local cached = a.promptCache[data.uid]
if cached and cached.Parent then return cached end
local plots = workspace:FindFirstChild("Plots")
local plot = plots and plots:FindFirstChild(data.plot)
local podiums = plot and plot:FindFirstChild("AnimalPodiums")
local podium = podiums and podiums:FindFirstChild(data.slot)
local base = podium and podium:FindFirstChild("Base")
local spawn = base and base:FindFirstChild("Spawn")
local attach = spawn and spawn:FindFirstChild("PromptAttachment")
if not attach then return nil end
for _, prompt in ipairs(attach:GetChildren()) do
if prompt:IsA("ProximityPrompt") then
a.promptCache[data.uid] = prompt
return prompt
end
end
return nil
end
local function cacheCallbacks(prompt)
local a = _G.AceNormalSteal
if a.internalCache[prompt] then return end
local data = {hold = {}, trigger = {}, ready = true}
pcall(function()
if getconnections then
for _, conn in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
if type(conn.Function) == "function" then table.insert(data.hold, conn.Function) end
end
for _, conn in ipairs(getconnections(prompt.Triggered)) do
if type(conn.Function) == "function" then table.insert(data.trigger, conn.Function) end
end
end
end)
if #data.hold > 0 or #data.trigger > 0 then
a.internalCache[prompt] = data
end
end
local function doSteal(prompt)
local a = _G.AceNormalSteal
if not prompt or not prompt.Parent or a.isStealing then return end
if tick() - (a.lastSteal or 0) < (a.cooldown or 0.08) then return end
cacheCallbacks(prompt)
local data = a.internalCache[prompt]
if not data or not data.ready then return end
data.ready = false
a.isStealing = true
a.lastSteal = tick()
pcall(function() if _G.StealBar then _G.StealBar.SetState("STEALING") end end)
task.spawn(function()
if #data.hold > 0 then
for _, fn in ipairs(data.hold) do task.spawn(function() pcall(fn) end) end
end
local startTime = tick()
local dur = 1.3
a.duration = dur
while a.enabled and selectedStealMode == "Normal" and tick() - startTime < dur do
barProgress((tick() - startTime) / dur)
task.wait(0.02)
end
if not a.enabled or selectedStealMode ~= "Normal" then
data.ready = true
a.isStealing = false
resetBar()
return
end
barProgress(1)
if #data.trigger > 0 then
for _, fn in ipairs(data.trigger) do task.spawn(function() pcall(fn) end) end
end
pcall(function() if _G.AutoCarrySpeed and _G.AutoCarrySpeed.WatchPickup then _G.AutoCarrySpeed.WatchPickup(1.25) end end)
task.wait(0.12)
data.ready = true
a.isStealing = false
resetBar()
end)
end
local function nearestAnimal()
local a = _G.AceNormalSteal
local root = getRoot()
if not root then return nil end
local best, bestDist = nil, math.huge
for _, data in ipairs(a.animals) do
if data.worldPosition and not isMyBase(data.plot) then
local dist = (root.Position - data.worldPosition).Magnitude
if dist < bestDist then
best = data
bestDist = dist
end
end
end
if best and bestDist <= (tonumber(a.radius) or 62) then
return best
end
return nil
end
_G.AceNormalAutoStealSetRadius = function(v)
_G.AceNormalSteal.radius = tonumber(v) or _G.AceNormalSteal.radius or 62
end
_G.AceNormalAutoStealStop = function()
local a = _G.AceNormalSteal
a.enabled = false
a.isStealing = false
if a.stealConn then a.stealConn:Disconnect(); a.stealConn = nil end
resetBar()
end
_G.AceNormalAutoStealStart = function()
local a = _G.AceNormalSteal
a.radius = tonumber(autoStealRadius) or a.radius or 62
a.duration = 1.3
a.enabled = true
ensureScanner()
pcall(scanPlots)
if a.stealConn then a.stealConn:Disconnect(); a.stealConn = nil end
a.stealConn = RunService.Heartbeat:Connect(function()
if not a.enabled then return end
if selectedStealMode ~= "Normal" then _G.AceNormalAutoStealStop(); return end
if a.isStealing then return end
local target = nearestAnimal()
if not target then return end
local prompt = findPrompt(target)
if prompt then doSteal(prompt) end
end)
end
_G.AceNormalAutoStealSync = function()
if selectedStealMode == "Normal" and autoStealEnabled then
_G.AceNormalAutoStealStart()
else
_G.AceNormalAutoStealStop()
end
end
end
_G.__AceSetupNormalAutoSteal()
_G.__AceSetupSemiAutoSteal = function()
_G.AceSemiSteal = _G.AceSemiSteal or {}
local A = _G.AceSemiSteal
if A.conn then pcall(function() A.conn:Disconnect() end); A.conn = nil end
A.enabled = false
A.holdMin = 1.3
A.holdMax = 2.6
A.entryDelay = 0.3
A.cooldown = 0.05
A.primeRange = 80
A.radius = tonumber(autoStealRadius) or 10
A.conn = A.conn
A.scanThread = A.scanThread
A.plotSync = A.plotSync or {caches = {}, connections = {}}
A.animals = A.animals or {}
A.promptCache = A.promptCache or {}
A.internalCache = A.internalCache or {}
A.state = A.state or {active = false, startTime = 0, phase = "idle", label = "", lastResult = "", lastResultTime = 0}
local function barSet(p, label)
pcall(function()
if _G.StealBar then
_G.StealBar.SetState(label or "STEALING")
_G.StealBar.SetProgress(math.clamp(tonumber(p) or 0, 0, 1))
end
end)
end
local function barReset()
pcall(function()
if _G.StealBar then _G.StealBar.Reset() end
end)
end
local function rootPart()
local char = LP.Character
return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")) or nil
end
local function splitPath(path)
if typeof(path) == "table" then return path end
local out = {}
for part in string.gmatch(tostring(path), "[^%.]+") do
table.insert(out, tonumber(part) or part)
end
return out
end
local function resolvePath(path, root)
local current, parent, key = root, nil, nil
for _, part in ipairs(splitPath(path)) do
parent = current
key = part
current = current and current[part] or nil
end
return current, parent, key
end
local function applySyncDiff(channelName, packet)
local cache = A.plotSync.caches[channelName]
if typeof(cache) ~= "table" then return end
local path, action, a, b = packet[1], packet[2], packet[3], packet[4]
local current, parent, key = resolvePath(path, cache)
if action == "Changed" then
if parent ~= nil then parent[key] = a end
elseif action == "ArrayInsert" then
if current ~= nil then table.insert(current, b, a) end
elseif action == "ArrayRemoved" then
if current ~= nil then table.remove(current, b) end
elseif action == "DictionaryInsert" then
if current ~= nil then current[b] = a end
elseif action == "DictionaryRemoved" then
if current ~= nil then current[b] = nil end
end
end
local function attachPlotChannel(remote, plots, requestData)
if A.plotSync.connections[remote] then return end
local channelName = tostring(remote.Name)
if not plots:FindFirstChild(channelName) then return end
if requestData and A.plotSync.caches[channelName] == nil then
local ok, data = pcall(function() return requestData:InvokeServer(channelName) end)
A.plotSync.caches[channelName] = (ok and typeof(data) == "table") and data or {}
elseif A.plotSync.caches[channelName] == nil then
A.plotSync.caches[channelName] = {}
end
A.plotSync.connections[remote] = remote.OnClientEvent:Connect(function(queue)
for _, packet in ipairs(queue) do applySyncDiff(channelName, packet) end
end)
end
local function ensureSync()
if A.syncReady then return true end
local ok = pcall(function()
local rs = game:GetService("ReplicatedStorage")
A.packages = rs:WaitForChild("Packages", 10)
A.datas = rs:WaitForChild("Datas", 10)
A.plots = workspace:WaitForChild("Plots", 10)
if not (A.packages and A.datas and A.plots) then return end
A.animalsData = require(A.datas:WaitForChild("Animals", 10))
local sync = A.packages:WaitForChild("Synchronizer", 10)
A.channelFolder = sync:WaitForChild("Channel", 10)
A.routeRemote = sync:WaitForChild("CommunicationRoute", 10)
A.requestData = sync:FindFirstChild("RequestData")
for _, child in ipairs(A.channelFolder:GetChildren()) do
if child:IsA("RemoteEvent") then attachPlotChannel(child, A.plots, A.requestData) end
end
A.channelFolder.ChildAdded:Connect(function(child)
if child:IsA("RemoteEvent") then attachPlotChannel(child, A.plots, A.requestData) end
end)
A.routeRemote.OnClientEvent:Connect(function(actions)
for _, action in ipairs(actions) do
local kind, channelName = action[1], tostring(action[2])
if A.plots and A.plots:FindFirstChild(channelName) then
if kind == "ListenerAdded" then
local remote = A.channelFolder and A.channelFolder:FindFirstChild(channelName)
if remote and remote:IsA("RemoteEvent") then attachPlotChannel(remote, A.plots, A.requestData) end
elseif kind == "ListenerRemoved" then
for remote, conn in pairs(A.plotSync.connections) do
if tostring(remote.Name) == channelName then
pcall(function() conn:Disconnect() end)
A.plotSync.connections[remote] = nil
A.plotSync.caches[channelName] = nil
break
end
end
end
end
end
end)
A.syncReady = true
end)
return ok and A.syncReady == true
end
local function getPlotOwner(plot)
local sign = plot and plot:FindFirstChild("PlotSign")
local frame = sign and sign:FindFirstChild("SurfaceGui") and sign.SurfaceGui:FindFirstChild("Frame")
local label = frame and frame:FindFirstChild("TextLabel")
if not label or label.Text == "Empty Base" then return nil end
return label.Text:gsub("'s [Bb]ase$", ""):gsub("%s+$", "")
end
local function isMyBaseAnimal(animalData)
if not animalData or not animalData.plot or not A.plots then return false end
local plot = A.plots:FindFirstChild(animalData.plot)
if not plot then return false end
local owner = getPlotOwner(plot)
return owner == LP.DisplayName or owner == LP.Name
end
local function podiumFor(animalData)
local plot = A.plots and A.plots:FindFirstChild(animalData.plot)
local podiums = plot and plot:FindFirstChild("AnimalPodiums")
return podiums and podiums:FindFirstChild(animalData.slot) or nil
end
local function animalPos(animalData)
local podium = podiumFor(animalData)
return podium and podium:GetPivot().Position or nil
end
local function distToAnimal(animalData)
local root = rootPart()
local pos = animalPos(animalData)
return root and pos and (root.Position - pos).Magnitude or math.huge
end
local function findPromptForAnimal(animalData)
if not animalData then return nil end
local cached = A.promptCache[animalData.uid]
if cached and cached.Parent then return cached end
local podium = podiumFor(animalData)
local base = podium and podium:FindFirstChild("Base")
local spawn = base and base:FindFirstChild("Spawn")
local attach = spawn and spawn:FindFirstChild("PromptAttachment")
if not attach then return nil end
for _, prompt in ipairs(attach:GetChildren()) do
if prompt:IsA("ProximityPrompt") then
A.promptCache[animalData.uid] = prompt
return prompt
end
end
return nil
end
local function scanAllPlots()
if not ensureSync() then return 0 end
local newCache = {}
for _, plot in ipairs(A.plots:GetChildren()) do
local cache = A.plotSync.caches[plot.Name]
local animalList = cache and cache.AnimalList
if typeof(animalList) == "table" then
for slot, animalData in pairs(animalList) do
if type(animalData) == "table" then
local animalName = animalData.Index
local info = A.animalsData and A.animalsData[animalName]
if info then
table.insert(newCache, {
name = info.DisplayName or animalName,
plot = plot.Name,
slot = tostring(slot),
uid = plot.Name .. "_" .. tostring(slot),
})
end
end
end
end
end
A.animals = newCache
return #newCache
end
local function pickClosest()
local root = rootPart()
if not root then return nil end
local best, bestDist = nil, math.huge
for _, animalData in ipairs(A.animals) do
if not isMyBaseAnimal(animalData) then
local pos = animalPos(animalData)
local dist = pos and (root.Position - pos).Magnitude or math.huge
if dist <= (A.primeRange or 80) and dist < bestDist then
best, bestDist = animalData, dist
end
end
end
return best
end
local function buildCallbacks(prompt)
if A.internalCache[prompt] then return end
local data = {holdCallbacks = {}, triggerCallbacks = {}, ready = true}
local okHold, holds = pcall(getconnections, prompt.PromptButtonHoldBegan)
if okHold and type(holds) == "table" then
for _, conn in ipairs(holds) do
if type(conn.Function) == "function" then table.insert(data.holdCallbacks, conn.Function) end
end
end
local okTrigger, triggers = pcall(getconnections, prompt.Triggered)
if okTrigger and type(triggers) == "table" then
for _, conn in ipairs(triggers) do
if type(conn.Function) == "function" then table.insert(data.triggerCallbacks, conn.Function) end
end
end
if #data.holdCallbacks > 0 or #data.triggerCallbacks > 0 then A.internalCache[prompt] = data end
end
local function executeSemi(prompt, animalData)
if not prompt or not prompt.Parent or not animalData then return false end
buildCallbacks(prompt)
local data = A.internalCache[prompt]
if not data or not data.ready then return false end
data.ready = false
A.state.active = true
A.state.startTime = tick()
A.state.phase = "holding"
A.state.label = animalData.name or "Animal"
task.spawn(function()
local startTime = A.state.startTime
for _, fn in ipairs(data.holdCallbacks) do task.spawn(function() pcall(fn) end) end
while A.enabled and selectedStealMode == "Semi" and tick() - startTime < (A.holdMin or 1.3) do
barSet((tick() - startTime) / (A.holdMax or 2.6), "STEALING")
task.wait()
end
A.state.phase = "waitingRange"
local alreadyInRange = distToAnimal(animalData) <= (tonumber(A.radius) or 10)
local fired = false
while A.enabled and selectedStealMode == "Semi" and prompt.Parent do
local elapsed = tick() - startTime
if elapsed > (A.holdMax or 2.6) then break end
barSet(elapsed / (A.holdMax or 2.6), "STEALING")
if distToAnimal(animalData) <= (tonumber(A.radius) or 10) then
if not alreadyInRange then task.wait(A.entryDelay or 0.3) end
if A.enabled and selectedStealMode == "Semi" then
for _, fn in ipairs(data.triggerCallbacks) do task.spawn(function() pcall(fn) end) end
pcall(function() if _G.AutoCarrySpeed and _G.AutoCarrySpeed.WatchPickup then _G.AutoCarrySpeed.WatchPickup(1.25) end end)
fired = true
end
break
end
task.wait()
end
A.state.lastResult = fired and ("Stole " .. tostring(A.state.label)) or ("Missed window: " .. tostring(A.state.label))
A.state.active = false
A.state.phase = "idle"
A.state.lastResultTime = tick()
if fired then barSet(1, "STEALING") end
task.wait(A.cooldown or 0.05)
data.ready = true
barReset()
end)
return true
end
local function ensureScanThread()
if A.scanThread then return end
A.scanThread = task.spawn(function()
while _G.AceSemiSteal do
if A.enabled or selectedStealMode == "Semi" then pcall(scanAllPlots) end
task.wait(5)
end
end)
end
_G.AceSemiAutoStealSetRadius = function(v)
local n = tonumber(v)
if n then A.radius = n end
end
_G.AceSemiAutoStealStop = function()
A.enabled = false
if A.conn then A.conn:Disconnect(); A.conn = nil end
A.state.active = false
A.state.phase = "idle"
barReset()
end
_G.AceSemiAutoStealStart = function()
A.radius = tonumber(autoStealRadius) or A.radius or 10
A.enabled = true
ensureSync()
ensureScanThread()
pcall(scanAllPlots)
if A.conn then A.conn:Disconnect(); A.conn = nil end
A.conn = RunService.Heartbeat:Connect(function()
if not A.enabled then return end
if selectedStealMode ~= "Semi" then _G.AceSemiAutoStealStop(); return end
if A.state.active then return end
local target = pickClosest()
if not target then return end
local prompt = findPromptForAnimal(target)
if prompt then executeSemi(prompt, target) end
end)
end
_G.AceSemiAutoStealSync = function()
if selectedStealMode == "Semi" and autoStealEnabled then
_G.AceSemiAutoStealStart()
else
_G.AceSemiAutoStealStop()
end
end
end
_G.__AceSetupSemiAutoSteal()
_G.AceAutoStealSync = function()
if not autoStealEnabled then
if _G.AceNormalAutoStealStop then _G.AceNormalAutoStealStop() end
if _G.AceSemiAutoStealStop then _G.AceSemiAutoStealStop() end
return
end
if selectedStealMode == "Normal" then
if _G.AceSemiAutoStealStop then _G.AceSemiAutoStealStop() end
if _G.AceNormalAutoStealSync then _G.AceNormalAutoStealSync() end
elseif selectedStealMode == "Semi" then
if _G.AceNormalAutoStealStop then _G.AceNormalAutoStealStop() end
if _G.AceSemiAutoStealSync then _G.AceSemiAutoStealSync() end
end
end
task.spawn(function()
while task.wait(30) do
saveAceConfig()
end
end)
local lastMoveDir = Vector3.new(0, 0, 0)
local _ace_proxy = nil
local _ace_proxy_weld = nil
local function cleanAceProxy()
	if _ace_proxy then pcall(function() _ace_proxy:Destroy() end); _ace_proxy = nil end
	_ace_proxy_weld = nil
end
local function ensureAceProxy(hrp)
	local char = hrp.Parent
	if _ace_proxy and _ace_proxy.Parent == char then return _ace_proxy end
	cleanAceProxy()
	local p = Instance.new("Part")
	p.Name = "_ACE_PX"; p.Size = Vector3.new(1,1,1)
	p.Transparency = 1; p.CanCollide = false; p.Massless = true
	p.Parent = char
	local w = Instance.new("Weld", p)
	w.Part0 = hrp; w.Part1 = p; w.C0 = CFrame.new()
	_ace_proxy_weld = w; _ace_proxy = p
	return p
end
local function getCurrentSpeedValue()
if currentSpeedMode == "Carry" then
return CS
elseif currentSpeedMode == "Lagger" then
return LAGGER_SPEED
elseif currentSpeedMode == "Lagger Carry" then
return LAGGER_CARRY_SPEED
end
return NS
end
local refreshSpeedModeRows = nil
local function setSpeedMode(mode)
if mode ~= "Normal" and mode ~= "Carry" and mode ~= "Lagger" and mode ~= "Lagger Carry" then
mode = "Normal"
end
currentSpeedMode = mode
if refreshSpeedModeRows then
refreshSpeedModeRows()
end
saveAceConfig()
end
local function toggleCarryMode()
if currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry" then
setSpeedMode("Carry")
elseif currentSpeedMode == "Carry" then
setSpeedMode("Normal")
else
setSpeedMode("Carry")
end
end
local function toggleLaggerMode()
if currentSpeedMode ~= "Lagger" and currentSpeedMode ~= "Lagger Carry" then
setSpeedMode("Lagger Carry")
elseif currentSpeedMode == "Lagger Carry" then
setSpeedMode("Lagger")
else
setSpeedMode("Lagger Carry")
end
end
State = State or {}
State.normalSpeed = NS
State.carrySpeed = CS
State.laggerSpeed = LAGGER_SPEED
State.speedToggled = (currentSpeedMode == "Carry" or currentSpeedMode == "Lagger Carry")
State.laggerEnabled = (currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry")
toggleRefs = toggleRefs or {}
function setCarry(on)
if on then
setSpeedMode("Carry")
else
if currentSpeedMode == "Carry" or currentSpeedMode == "Lagger Carry" then
setSpeedMode("Normal")
end
end
State.speedToggled = on == true
end
function setLagger(on)
if on then
setSpeedMode("Lagger")
else
if currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry" then
setSpeedMode("Normal")
end
end
State.laggerEnabled = on == true
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
State = State or {}
State.normalSpeed = State.normalSpeed or 59
State.carrySpeed = State.carrySpeed or 30
State.laggerSpeed = State.laggerSpeed or 60
State.speedToggled = State.speedToggled or false
State.laggerEnabled = State.laggerEnabled or false
State._autoCarryFromSteal = State._autoCarryFromSteal or false
State._autoCarryGraceUntil = State._autoCarryGraceUntil or 0
State._waitingForCarryPickup = State._waitingForCarryPickup or false
State._carryPickupWatchUntil = State._carryPickupWatchUntil or 0
State._autoCarryReturnMode = State._autoCarryReturnMode or nil
toggleRefs = toggleRefs or {}
local function safeSaveConfig()
if type(saveConfig) == "function" then
task.spawn(saveConfig)
end
end
local function isCarryName(name)
local n = tostring(name or ""):lower()
return n:find("brainrot")
or n:find("animal")
or n:find("carry")
or n:find("grab")
or n:find("steal")
or n:find("hold")
end
local function isIgnoredCarryTool(name)
local n = tostring(name or ""):lower()
return n:find("bat")
or n:find("slap")
or n:find("medusa")
or n:find("head")
or n:find("stone")
end
local function isCarryingBrainrot(char)
if not char then return false end
for _, name in ipairs({"Carrying", "IsCarrying", "Grabbed", "Holding", "StealHold", "HasGrab"}) do
local v = char:FindFirstChild(name, true)
if v then
if v:IsA("BoolValue") and v.Value then
return true
end
if v:IsA("ObjectValue") and v.Value then
return true
end
if v:IsA("StringValue") and v.Value ~= "" then
return true
end
end
end
for _, child in ipairs(char:GetChildren()) do
if child:IsA("Model") and child:FindFirstChildWhichIsA("BasePart", true) then
if child:FindFirstChildOfClass("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
return true
end
if isCarryName(child.Name) then
return true
end
elseif child:IsA("Tool") and not isIgnoredCarryTool(child.Name) then
return true
end
end
return false
end
local function setCarrySpeedMode(on)
State.speedToggled = on
if toggleRefs.carryMode then
toggleRefs.carryMode(on)
end
if type(setCarry) == "function" then
setCarry(on)
end
end
local function setLaggerMode(on)
State.laggerEnabled = on
if toggleRefs.laggerMode then
toggleRefs.laggerMode(on)
end
if type(setLagger) == "function" then
setLagger(on)
end
end
local function enableCarrySpeedForSteal()
State._waitingForCarryPickup = false
State._carryPickupWatchUntil = 0
if not State._autoCarryFromSteal then
State._autoCarryReturnMode = currentSpeedMode
end
State._autoCarryFromSteal = true
State._autoCarryGraceUntil = tick() + 0.75
local wasLagger = (State._autoCarryReturnMode == "Lagger" or State._autoCarryReturnMode == "Lagger Carry"
or currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry")
if wasLagger then
State.laggerEnabled = true
State.speedToggled = true
if toggleRefs.laggerMode then toggleRefs.laggerMode(true) end
if toggleRefs.carryMode then toggleRefs.carryMode(true) end
setSpeedMode("Lagger Carry")
else
setLaggerMode(false)
setCarrySpeedMode(true)
end
safeSaveConfig()
end
local function disableAutoCarrySpeed()
if not State._autoCarryFromSteal and not State._waitingForCarryPickup then return end
local wasAutoApplied = State._autoCarryFromSteal == true
local returnMode = State._autoCarryReturnMode
State._autoCarryFromSteal = false
State._waitingForCarryPickup = false
State._autoCarryGraceUntil = 0
State._carryPickupWatchUntil = 0
State._autoCarryReturnMode = nil
if not wasAutoApplied then
return
end
if returnMode == "Lagger" or returnMode == "Lagger Carry" then
State.laggerEnabled = true
State.speedToggled = false
if toggleRefs.laggerMode then toggleRefs.laggerMode(true) end
if toggleRefs.carryMode then toggleRefs.carryMode(false) end
setSpeedMode("Lagger")
elseif returnMode == "Carry" then
State.laggerEnabled = false
State.speedToggled = true
if toggleRefs.laggerMode then toggleRefs.laggerMode(false) end
if toggleRefs.carryMode then toggleRefs.carryMode(true) end
setSpeedMode("Carry")
else
setLaggerMode(false)
setCarrySpeedMode(false)
end
safeSaveConfig()
end
local function startAutoCarryPickupWatch(seconds)
if autoCarrySpeedEnabled ~= true then return end
State._waitingForCarryPickup = true
State._carryPickupWatchUntil = tick() + (seconds or 1.25)
end
local _stealAttrWasActive = false
RunService.RenderStepped:Connect(function()
if autoCarrySpeedEnabled ~= true then
disableAutoCarrySpeed()
return
end
local char = LP.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
local root = char and char:FindFirstChild("HumanoidRootPart")
if not char or not hum or not root then
disableAutoCarrySpeed()
_stealAttrWasActive = false
return
end
local st = hum:GetState()
local gotHit = st == Enum.HumanoidStateType.Physics
or st == Enum.HumanoidStateType.Ragdoll
or st == Enum.HumanoidStateType.FallingDown
local stealingAttr = LP:GetAttribute("Stealing") == true
local carryingBrainrot = isCarryingBrainrot(char)
if stealingAttr and not _stealAttrWasActive then
_stealAttrWasActive = true
enableCarrySpeedForSteal()
elseif not stealingAttr then
_stealAttrWasActive = false
end
if State._waitingForCarryPickup then
if gotHit or tick() > (State._carryPickupWatchUntil or 0) then
State._waitingForCarryPickup = false
State._carryPickupWatchUntil = 0
elseif carryingBrainrot then
enableCarrySpeedForSteal()
end
end
if carryingBrainrot and not State._autoCarryFromSteal then
enableCarrySpeedForSteal()
end
if State._autoCarryFromSteal then
local graceDone = tick() > (State._autoCarryGraceUntil or 0)
if gotHit or (graceDone and not carryingBrainrot and not stealingAttr) then
disableAutoCarrySpeed()
end
end
end)
_G.AutoCarrySpeed = {
IsCarryingBrainrot = isCarryingBrainrot,
Enable = enableCarrySpeedForSteal,
Disable = disableAutoCarrySpeed,
WatchPickup = startAutoCarryPickupWatch,
}
_G.AceAutoPathState = _G.AceAutoPathState or {leftConn=nil,rightConn=nil,leftPhase=1,rightPhase=1}
_G.AceAutoPathPoints = _G.AceAutoPathPoints or {
L1=Vector3.new(-476.48,-6.28,92.73), L2=Vector3.new(-483.12,-4.95,94.80), LFace=Vector3.new(-482.25,-4.96,92.09),
R1=Vector3.new(-476.16,-6.52,25.62), R2=Vector3.new(-483.06,-5.03,25.48), RFace=Vector3.new(-482.06,-6.93,35.47),
}
function _G.AceAutoPathSpeed()
if currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry" then
return LAGGER_SPEED
end
return NS
end
function _G.AceStopAutoLeft()
local S=_G.AceAutoPathState
if S.leftConn then S.leftConn:Disconnect(); S.leftConn=nil end
S.leftPhase=1
local char=LP.Character
local hum=char and char:FindFirstChildOfClass("Humanoid")
local hrp=char and char:FindFirstChild("HumanoidRootPart")
if hum then hum:Move(Vector3.zero,false) end
if hrp then hrp.AssemblyLinearVelocity=Vector3.new(0,hrp.AssemblyLinearVelocity.Y,0) end
end
function _G.AceStopAutoRight()
local S=_G.AceAutoPathState
if S.rightConn then S.rightConn:Disconnect(); S.rightConn=nil end
S.rightPhase=1
local char=LP.Character
local hum=char and char:FindFirstChildOfClass("Humanoid")
local hrp=char and char:FindFirstChild("HumanoidRootPart")
if hum then hum:Move(Vector3.zero,false) end
if hrp then hrp.AssemblyLinearVelocity=Vector3.new(0,hrp.AssemblyLinearVelocity.Y,0) end
end
function _G.AceSetAutoLeft(on, skipSave)
if on and _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then
autoLeftEnabled = false
if _G.AceSetAutoLeftVisual then _G.AceSetAutoLeftVisual(false) end
if not skipSave then saveAceConfig() end
return false
end
autoLeftEnabled = on and true or false
if _G.AceSetAutoLeftVisual then _G.AceSetAutoLeftVisual(autoLeftEnabled) end
if autoLeftEnabled then
autoRightEnabled=false
if _G.AceSetAutoRightVisual then _G.AceSetAutoRightVisual(false) end
if _G.AceStopAutoRight then _G.AceStopAutoRight() end
if _G.AceStartAutoLeft then _G.AceStartAutoLeft() end
else
if _G.AceStopAutoLeft then _G.AceStopAutoLeft() end
end
if not skipSave then saveAceConfig() end
end
function _G.AceSetAutoRight(on, skipSave)
if on and _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then
autoRightEnabled = false
if _G.AceSetAutoRightVisual then _G.AceSetAutoRightVisual(false) end
if not skipSave then saveAceConfig() end
return false
end
autoRightEnabled = on and true or false
if _G.AceSetAutoRightVisual then _G.AceSetAutoRightVisual(autoRightEnabled) end
if autoRightEnabled then
autoLeftEnabled=false
if _G.AceSetAutoLeftVisual then _G.AceSetAutoLeftVisual(false) end
if _G.AceStopAutoLeft then _G.AceStopAutoLeft() end
if _G.AceStartAutoRight then _G.AceStartAutoRight() end
else
if _G.AceStopAutoRight then _G.AceStopAutoRight() end
end
if not skipSave then saveAceConfig() end
end
function _G.AceStartAutoLeft()
local S=_G.AceAutoPathState
if S.leftConn then S.leftConn:Disconnect() end
S.leftPhase=1
S.leftConn=RunService.Heartbeat:Connect(function()
if not autoLeftEnabled then return end
local char=LP.Character; if not char then return end
local hrp=char:FindFirstChild("HumanoidRootPart")
local hum=char:FindFirstChildOfClass("Humanoid")
if not hrp or not hum then return end
local st=hum:GetState()
if hum.PlatformStand or st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then hum:Move(Vector3.zero,false); return end
local P=_G.AceAutoPathPoints
local spd=_G.AceAutoPathSpeed()
if S.leftPhase==1 then
local tgt=Vector3.new(P.L1.X,hrp.Position.Y,P.L1.Z)
if (tgt-hrp.Position).Magnitude<1 then
S.leftPhase=2
local d=P.L2-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
return
end
local d=P.L1-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
elseif S.leftPhase==2 then
local tgt=Vector3.new(P.L2.X,hrp.Position.Y,P.L2.Z)
if (tgt-hrp.Position).Magnitude<1 then
hum:Move(Vector3.zero,false)
hrp.AssemblyLinearVelocity=Vector3.zero
autoLeftEnabled=false
if S.leftConn then S.leftConn:Disconnect(); S.leftConn=nil end
S.leftPhase=1
if _G.AceSetAutoLeftVisual then _G.AceSetAutoLeftVisual(false) end
if P.LFace and (P.LFace-hrp.Position).Magnitude>0.01 then
hrp.CFrame=CFrame.new(hrp.Position,Vector3.new(P.LFace.X,hrp.Position.Y,P.LFace.Z))
end
saveAceConfig()
return
end
local d=P.L2-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
end
end)
end
function _G.AceStartAutoRight()
local S=_G.AceAutoPathState
if S.rightConn then S.rightConn:Disconnect() end
S.rightPhase=1
S.rightConn=RunService.Heartbeat:Connect(function()
if not autoRightEnabled then return end
local char=LP.Character; if not char then return end
local hrp=char:FindFirstChild("HumanoidRootPart")
local hum=char:FindFirstChildOfClass("Humanoid")
if not hrp or not hum then return end
local st=hum:GetState()
if hum.PlatformStand or st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then hum:Move(Vector3.zero,false); return end
local P=_G.AceAutoPathPoints
local spd=_G.AceAutoPathSpeed()
if S.rightPhase==1 then
local tgt=Vector3.new(P.R1.X,hrp.Position.Y,P.R1.Z)
if (tgt-hrp.Position).Magnitude<1 then
S.rightPhase=2
local d=P.R2-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
return
end
local d=P.R1-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
elseif S.rightPhase==2 then
local tgt=Vector3.new(P.R2.X,hrp.Position.Y,P.R2.Z)
if (tgt-hrp.Position).Magnitude<1 then
hum:Move(Vector3.zero,false)
hrp.AssemblyLinearVelocity=Vector3.zero
autoRightEnabled=false
if S.rightConn then S.rightConn:Disconnect(); S.rightConn=nil end
S.rightPhase=1
if _G.AceSetAutoRightVisual then _G.AceSetAutoRightVisual(false) end
if P.RFace and (P.RFace-hrp.Position).Magnitude>0.01 then
hrp.CFrame=CFrame.new(hrp.Position,Vector3.new(P.RFace.X,hrp.Position.Y,P.RFace.Z))
end
saveAceConfig()
return
end
local d=P.R2-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
end
end)
end
LP.CharacterAdded:Connect(function()
task.wait(0.5)
if autoLeftEnabled and _G.AceStartAutoLeft then _G.AceStartAutoLeft() end
if autoRightEnabled and _G.AceStartAutoRight then _G.AceStartAutoRight() end
end)
local overheadGui = nil
local overheadSpeedLabel = nil
local function setupOverheadInfo(char)
if overheadGui then
pcall(function() overheadGui:Destroy() end)
overheadGui = nil
overheadSpeedLabel = nil
end
if not char then return end
local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 5)
if not head then return end
overheadGui = Instance.new("BillboardGui")
overheadGui.Name = "AceDuelsOverheadInfo"
overheadGui.Size = UDim2.new(0, 250, 0, 88)
overheadGui.StudsOffset = Vector3.new(0, 1.75, 0)
overheadGui.AlwaysOnTop = true
overheadGui.LightInfluence = 0
overheadGui.Parent = head
ragdollCountdownLabel = Instance.new("TextLabel")
ragdollCountdownLabel.Name = "RagdollCountdown"
ragdollCountdownLabel.Size = UDim2.new(1, 0, 0, 26)
ragdollCountdownLabel.Position = UDim2.new(0, 0, 0, 0)
ragdollCountdownLabel.BackgroundTransparency = 1
ragdollCountdownLabel.Text = ""
ragdollCountdownLabel.Visible = false
ragdollCountdownLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
ragdollCountdownLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
ragdollCountdownLabel.TextStrokeTransparency = 0
ragdollCountdownLabel.Font = Enum.Font.GothamBlack
ragdollCountdownLabel.TextSize = 22
ragdollCountdownLabel.TextXAlignment = Enum.TextXAlignment.Center
ragdollCountdownLabel.ZIndex = 10
ragdollCountdownLabel.Parent = overheadGui
local discordLbl = Instance.new("TextLabel")
discordLbl.Name = "Discord"
discordLbl.Size = UDim2.new(1, 0, 0, 30)
discordLbl.Position = UDim2.new(0, 0, 0, 26)
discordLbl.BackgroundTransparency = 1
discordLbl.Text = "discord.gg/aceduels"
discordLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
discordLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
discordLbl.TextStrokeTransparency = 0
discordLbl.Font = Enum.Font.GothamBlack
discordLbl.TextSize = 21
discordLbl.TextXAlignment = Enum.TextXAlignment.Center
discordLbl.ZIndex = 10
discordLbl.Parent = overheadGui
overheadSpeedLabel = Instance.new("TextLabel")
overheadSpeedLabel.Name = "Speed"
overheadSpeedLabel.Size = UDim2.new(1, 0, 0, 26)
overheadSpeedLabel.Position = UDim2.new(0, 0, 0, 54)
overheadSpeedLabel.BackgroundTransparency = 1
overheadSpeedLabel.Text = "Speed: 0"
overheadSpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
overheadSpeedLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
overheadSpeedLabel.TextStrokeTransparency = 0
overheadSpeedLabel.Font = Enum.Font.GothamBlack
overheadSpeedLabel.TextSize = 19
overheadSpeedLabel.TextXAlignment = Enum.TextXAlignment.Center
overheadSpeedLabel.ZIndex = 10
overheadSpeedLabel.Parent = overheadGui
end
local ragdollCountdownConn = nil
local ragdollCountdownCharConn = nil
local ragdollCountdownEndTime = 0
local RAGDOLL_COUNTDOWN_SECONDS = 2.6
function stopRagdollCountdown()
if ragdollCountdownConn then ragdollCountdownConn:Disconnect(); ragdollCountdownConn = nil end
if ragdollCountdownCharConn then ragdollCountdownCharConn:Disconnect(); ragdollCountdownCharConn = nil end
if ragdollCountdownLabel then
ragdollCountdownLabel.Visible = false
ragdollCountdownLabel.Text = ""
end
end
function hookRagdollCountdown(char)
stopRagdollCountdown()
if not ragdollCountdownEnabled then return end
char = char or LP.Character
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 4)
if not hum then return end
local function beginCountdown()
ragdollCountdownEndTime = tick() + RAGDOLL_COUNTDOWN_SECONDS
if ragdollCountdownLabel then
ragdollCountdownLabel.Visible = true
end
end
local function isRagdollStateForCountdown()
local st = hum:GetState()
return hum.PlatformStand
or st == Enum.HumanoidStateType.Physics
or st == Enum.HumanoidStateType.Ragdoll
or st == Enum.HumanoidStateType.FallingDown
end
ragdollCountdownCharConn = hum.StateChanged:Connect(function(_, newState)
if newState == Enum.HumanoidStateType.Physics
or newState == Enum.HumanoidStateType.Ragdoll
or newState == Enum.HumanoidStateType.FallingDown then
beginCountdown()
end
end)
ragdollCountdownConn = RunService.RenderStepped:Connect(function()
if not ragdollCountdownEnabled then stopRagdollCountdown(); return end
if not ragdollCountdownLabel or not ragdollCountdownLabel.Parent then return end
if isRagdollStateForCountdown() and ragdollCountdownEndTime < tick() then
beginCountdown()
end
local left = math.max(0, ragdollCountdownEndTime - tick())
if left > 0 then
ragdollCountdownLabel.Visible = true
ragdollCountdownLabel.Text = string.format("RAGDOLL %.1f", left)
if left <= 1 then
ragdollCountdownLabel.TextColor3 = Color3.fromRGB(255, 230, 90)
else
ragdollCountdownLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
end
else
ragdollCountdownLabel.Visible = false
ragdollCountdownLabel.Text = ""
end
end)
end
if LP.Character then
task.spawn(function()
setupOverheadInfo(LP.Character)
end)
end
LP.CharacterAdded:Connect(function(char)
cleanAceProxy()
task.wait(0.5)
setupOverheadInfo(char)
if ragdollCountdownEnabled then hookRagdollCountdown(char) end
end)
RunService.RenderStepped:Connect(function()
local char = LP.Character
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")
if not hum or not hrp then return end
local state = hum:GetState()
if hum.PlatformStand
or state == Enum.HumanoidStateType.Physics
or state == Enum.HumanoidStateType.Ragdoll
or state == Enum.HumanoidStateType.FallingDown then
lastMoveDir = Vector3.new(0, 0, 0)
return
end
local md = hum.MoveDirection
local spd = getCurrentSpeedValue()
if not autoLeftEnabled and not autoRightEnabled and md.Magnitude > 0 then
lastMoveDir = md
local _n = 1 + (math.random() - 0.5) * 0.04
local _px = ensureAceProxy(hrp)
_px.AssemblyLinearVelocity = Vector3.new(md.X * spd * _n, hrp.AssemblyLinearVelocity.Y, md.Z * spd * _n)
end
if overheadSpeedLabel then
local v = hrp.AssemblyLinearVelocity or hrp.Velocity
local speedMag = Vector3.new(v.X, 0, v.Z).Magnitude
local rounded = math.floor(speedMag * 10 + 0.5) / 10
if math.abs(rounded - math.floor(rounded)) < 0.05 then
overheadSpeedLabel.Text = string.format("Speed: %d", math.floor(rounded + 0.5))
else
overheadSpeedLabel.Text = string.format("Speed: %.1f", rounded)
end
end
end)
local COLORS = {
bg = Color3.fromRGB(0, 0, 0),
row = Color3.fromRGB(6, 6, 9),
row2 = Color3.fromRGB(8, 8, 12),
stroke = Color3.fromRGB(90, 90, 105),
strokeSoft = Color3.fromRGB(60, 60, 72),
white = Color3.fromRGB(255, 255, 255),
textDim = Color3.fromRGB(180, 180, 190),
toggleBg = Color3.fromRGB(18, 18, 26),
knob = Color3.fromRGB(238, 238, 245),
}
function corner(parent, radius)
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, radius or 8)
c.Parent = parent
return c
end
function stroke(parent, color, thickness, transparency)
local s = Instance.new("UIStroke")
s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
s.Color = color or COLORS.stroke
s.Thickness = thickness or 1
s.Transparency = transparency or 0.35
s.Parent = parent
local g = Instance.new("UIGradient")
g.Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
ColorSequenceKeypoint.new(0.5, Color3.fromRGB(155, 160, 185)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
})
g.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0.55),
NumberSequenceKeypoint.new(0.5, 0.1),
NumberSequenceKeypoint.new(1, 0.55),
})
g.Parent = s
return s
end
function tween(obj, props, time)
TweenService:Create(obj, TweenInfo.new(time or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
function makeDraggable(frame)
local dragging = false
local dragStart
local startPos
local dragInput
frame.InputBegan:Connect(function(input)
if _G.AceGuiLocked == true then return end
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragging = true
dragStart = input.Position
startPos = frame.Position
input.Changed:Connect(function()
if input.UserInputState == Enum.UserInputState.End then
dragging = false
end
end)
end
end)
frame.InputChanged:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
dragInput = input
end
end)
UserInputService.InputChanged:Connect(function(input)
if _G.AceGuiLocked == true then return end
if input == dragInput and dragging then
local delta = input.Position - dragStart
frame.Position = UDim2.new(
startPos.X.Scale,
startPos.X.Offset + delta.X,
startPos.Y.Scale,
startPos.Y.Offset + delta.Y
)
end
end)
end

-- ====================================================================
-- ACE VISUALS / OPTIMIZATION CORE (verbatim: ESP, tracer, sky themes,
-- stretch-rez, custom FOV, anti-lag, nuke optimiser, remove accessories,
-- no-cam-collision)
-- ====================================================================
do
THEME_ACCENT = THEME_ACCENT or Color3.fromRGB(230, 230, 230)
THEME_ACCENT_DIM = THEME_ACCENT_DIM or Color3.fromRGB(145, 145, 145)
PlayerESP = PlayerESP or {enabled=false, playerData={}, conns={}, discordText="discord.gg/aceduels"}
BoxedESPOptions = BoxedESPOptions or {box=false, tracer=false}
BoxedESPData = BoxedESPData or {}
BoxedESPConn = BoxedESPConn or nil
stretchRezConn = stretchRezConn or nil
antiLagDescConn = antiLagDescConn or nil
noCamCollisionConn = noCamCollisionConn or nil
noCamCollisionParts = noCamCollisionParts or {}
_aceNukeConns = _aceNukeConns or {}
_aceNukeOn = _aceNukeOn or false
_aceCustomFontOrig = _aceCustomFontOrig or {}
_aceCustomFontConn = _aceCustomFontConn or nil
_aceCustomFont = _aceCustomFont or nil
function startPlayerESP()
if PlayerESP.enabled then return end
PlayerESP.enabled = true
function cleanup(plr)
local d=PlayerESP.playerData[plr]; if not d then return end
pcall(function() if d.highlight then d.highlight:Destroy() end end)
pcall(function() if d.billboard then d.billboard:Destroy() end end)
if d.conns then for _,c in ipairs(d.conns) do pcall(function() c:Disconnect() end) end end
PlayerESP.playerData[plr]=nil
end
function setup(plr,char)
if not PlayerESP.enabled or plr==LP then return end
cleanup(plr)
local hrp=char and (char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart",5))
local head=char and (char:FindFirstChild("Head") or char:WaitForChild("Head",5))
if not hrp or not head then return end
local hl=Instance.new("Highlight")
hl.Name="AceDuelsESP"; hl.Adornee=char; hl.FillColor=Color3.fromRGB(35,35,35); hl.FillTransparency=0.72
hl.OutlineColor=Color3.fromRGB(245,245,245); hl.OutlineTransparency=0; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char
local bb=Instance.new("BillboardGui")
bb.Name="AceDuelsESPTag"; bb.Adornee=head; bb.Size=UDim2.new(0,124,0,34); bb.StudsOffset=Vector3.new(0,2.7,0); bb.AlwaysOnTop=true; bb.LightInfluence=0; bb.Parent=head
local box=Instance.new("Frame",bb); box.Size=UDim2.new(1,0,1,0); box.BackgroundTransparency=1; box.BorderSizePixel=0
Instance.new("UICorner",box).CornerRadius=UDim.new(0,9)
local n=Instance.new("TextLabel",box); n.Size=UDim2.new(1,-10,0,17); n.Position=UDim2.new(0,5,0,2); n.BackgroundTransparency=1; n.TextColor3=Color3.fromRGB(255,255,255); n.Font=Enum.Font.GothamBlack; n.TextSize=15; n.TextStrokeTransparency=0.38
local sub=Instance.new("TextLabel",box); sub.Size=UDim2.new(1,-10,0,11); sub.Position=UDim2.new(0,5,0,19); sub.BackgroundTransparency=1; sub.TextColor3=Color3.fromRGB(180,180,180); sub.Font=Enum.Font.GothamBold; sub.TextSize=10; sub.TextStrokeTransparency=0.58
local conn=RunService.Heartbeat:Connect(function()
if not PlayerESP.enabled or not hrp.Parent then return end
local v=hrp.AssemblyLinearVelocity or hrp.Velocity
n.Text=string.format("%d speed", math.floor(Vector3.new(v.X,0,v.Z).Magnitude+0.5)); sub.Text=plr.Name
end)
PlayerESP.playerData[plr]={highlight=hl,billboard=bb,conns={conn}}
end
for _,plr in ipairs(Players:GetPlayers()) do if plr~=LP then if plr.Character then setup(plr,plr.Character) end; table.insert(PlayerESP.conns, plr.CharacterAdded:Connect(function(c) task.defer(setup,plr,c) end)) end end
table.insert(PlayerESP.conns, Players.PlayerAdded:Connect(function(plr) if plr~=LP then table.insert(PlayerESP.conns, plr.CharacterAdded:Connect(function(c) task.defer(setup,plr,c) end)) end end))
table.insert(PlayerESP.conns, Players.PlayerRemoving:Connect(cleanup))
end
function stopPlayerESP()
PlayerESP.enabled=false
for _,c in ipairs(PlayerESP.conns or {}) do pcall(function() c:Disconnect() end) end
PlayerESP.conns={}
for plr,d in pairs(PlayerESP.playerData or {}) do pcall(function() if d.highlight then d.highlight:Destroy() end end); pcall(function() if d.billboard then d.billboard:Destroy() end end) end
PlayerESP.playerData={}
end
function _aceEspColor()
return THEME_ACCENT or Color3.fromRGB(230,230,230)
end
function _safeDrawing(kind, props)
if not Drawing or not Drawing.new then return nil end
local ok, obj = pcall(function() return Drawing.new(kind) end)
if not ok or not obj then return nil end
for k,v in pairs(props or {}) do pcall(function() obj[k]=v end) end
return obj
end
function _cleanupBoxedESPPlayer(player)
local data = BoxedESPData[player]
if not data then return end
for _,obj in pairs(data) do
pcall(function()
obj.Visible = false
if obj.Remove then obj:Remove() end
end)
end
BoxedESPData[player] = nil
end
function _cleanupBoxedESP()
for player,_ in pairs(BoxedESPData) do _cleanupBoxedESPPlayer(player) end
end
function _updateBoxedESP()
local cam = workspace.CurrentCamera
if not cam then return end
local anyOn = BoxedESPOptions.box or BoxedESPOptions.tracer
if not anyOn then
_cleanupBoxedESP()
return
end
for _,player in ipairs(Players:GetPlayers()) do
if player == LP then continue end
local char = player.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
local head = char and char:FindFirstChild("Head")
if not root or not head then
_cleanupBoxedESPPlayer(player)
continue
end
local rootPos,onScreen = cam:WorldToViewportPoint(root.Position)
local headPos = cam:WorldToViewportPoint(head.Position + Vector3.new(0,0.55,0))
local data = BoxedESPData[player]
if not data then
data = {
box = _safeDrawing("Square",{Thickness=2,Filled=false,Transparency=1,Color=_aceEspColor()}),
tracer = _safeDrawing("Line",{Thickness=2,Transparency=1,Color=_aceEspColor()}),
}
BoxedESPData[player] = data
end
local color = _aceEspColor()
local height = math.abs(headPos.Y - rootPos.Y) * 2.15
if height < 20 or height ~= height then height = 65 end
local width = height / 2.15
local view = cam.ViewportSize
local centerX, centerY = view.X/2, view.Y/2
local targetX, targetY = rootPos.X, rootPos.Y + height/2
local targetVisible = onScreen and rootPos.Z > 0
if not targetVisible then
local dx = rootPos.X - centerX
local dy = rootPos.Y - centerY
if rootPos.Z <= 0 then
dx = -dx
dy = -dy
end
if math.abs(dx) < 1 and math.abs(dy) < 1 then
local rel = cam.CFrame:PointToObjectSpace(root.Position)
dx = rel.X
dy = -rel.Y
if rootPos.Z <= 0 then
dx = -dx
dy = -dy
end
end
local edgePad = 10
local scaleX = (dx ~= 0) and ((view.X/2 - edgePad) / math.abs(dx)) or math.huge
local scaleY = (dy ~= 0) and ((view.Y/2 - edgePad) / math.abs(dy)) or math.huge
local scale = math.min(scaleX, scaleY)
if scale == math.huge or scale ~= scale then scale = 1 end
targetX = math.clamp(centerX + dx * scale, edgePad, view.X - edgePad)
targetY = math.clamp(centerY + dy * scale, edgePad, view.Y - edgePad)
end
if data.box then
data.box.Color = color
data.box.Size = Vector2.new(width,height)
data.box.Position = Vector2.new(rootPos.X - width/2, rootPos.Y - height/2)
data.box.Visible = BoxedESPOptions.box == true and targetVisible
end
if data.tracer then
data.tracer.Color = color
local localChar = LP.Character
local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
local localHead = localChar and localChar:FindFirstChild("Head")
local fromX, fromY
if localRoot then
local localScreen = cam:WorldToViewportPoint(localRoot.Position)
fromX = localScreen.X
fromY = localScreen.Y + 15
end
if not fromX or not fromY then
fromX = cam.ViewportSize.X/2
fromY = cam.ViewportSize.Y - 88
end
data.tracer.From = Vector2.new(fromX, fromY)
data.tracer.To = Vector2.new(targetX, targetY)
data.tracer.Visible = BoxedESPOptions.tracer == true
end
end
end
function refreshBoxedESP()
local anyOn = BoxedESPOptions.box or BoxedESPOptions.tracer
if anyOn and not BoxedESPConn then
BoxedESPConn = RunService.RenderStepped:Connect(_updateBoxedESP)
elseif (not anyOn) and BoxedESPConn then
BoxedESPConn:Disconnect()
BoxedESPConn = nil
_cleanupBoxedESP()
end
end
Players.PlayerRemoving:Connect(_cleanupBoxedESPPlayer)
SKY_PRESETS_LIST={"Off","Night","Aurora","Sunset","Galaxy","Tech","Sakura","Pink Night","Blood Moon","Emerald Dawn","Volcanic","Arctic","Midnight Ocean","Vaporwave","Toxic","Solar Eclipse","Hellscape","Heaven","Storm","Sunrise","Deep Space","Lavender Dream","Inferno","Mint Sky"}
SKY_PRESETS={Off={kind="off"},Night={clock=22,brightness=2,ambient={110,100,130},outAmb={120,110,140}},Aurora={clock=14,brightness=3,ambient={150,120,150},outAmb={160,130,150}},Sunset={clock=17.2,brightness=2.5,ambient={170,120,100},outAmb={180,130,110}},Galaxy={clock=0,brightness=1.5,ambient={70,60,100},outAmb={80,70,110}},Tech={clock=21,brightness=2.2,ambient={90,130,170},outAmb={100,140,180}},Sakura={clock=11,brightness=3.5,ambient={170,150,160},outAmb={180,160,170}},["Pink Night"]={clock=23,brightness=2.2,ambient={120,60,110},outAmb={140,70,120}},["Blood Moon"]={clock=22.5,brightness=1.6,ambient={130,40,40},outAmb={150,50,50}},["Emerald Dawn"]={clock=6.5,brightness=2.8,ambient={130,170,140},outAmb={140,180,150}},Volcanic={clock=19,brightness=2,ambient={180,80,40},outAmb={200,90,50}},Arctic={clock=9,brightness=3.2,ambient={200,220,235},outAmb={210,230,245}},["Midnight Ocean"]={clock=1.5,brightness=1.7,ambient={60,90,130},outAmb={70,100,140}},Vaporwave={clock=19.5,brightness=2.4,ambient={180,120,200},outAmb={190,130,210}},Toxic={clock=13,brightness=2.5,ambient={140,180,80},outAmb={150,190,90}},["Solar Eclipse"]={clock=12,brightness=0.9,ambient={50,40,60},outAmb={60,50,70}},Hellscape={clock=18,brightness=1.8,ambient={200,60,30},outAmb={220,70,40}},Heaven={clock=12,brightness=4,ambient={240,235,210},outAmb={250,245,220}},Storm={clock=15,brightness=1.4,ambient={90,90,110},outAmb={100,100,120}},Sunrise={clock=6.2,brightness=2.8,ambient={220,180,130},outAmb={230,190,140}},["Deep Space"]={clock=0,brightness=1,ambient={30,25,50},outAmb={40,35,60}},["Lavender Dream"]={clock=18.5,brightness=2.6,ambient={180,160,220},outAmb={190,170,230}},Inferno={clock=17.5,brightness=2.2,ambient={220,100,40},outAmb={235,110,50}},["Mint Sky"]={clock=10,brightness=3.2,ambient={180,230,210},outAmb={190,240,220}}}
function _vC3(t) return Color3.fromRGB(t[1],t[2],t[3]) end
function _v4mpClearSky()
for _,v in ipairs(Lighting:GetChildren()) do if v:GetAttribute("_AceDuelsSky") then pcall(function() v:Destroy() end) end end
local terrain=workspace:FindFirstChildOfClass("Terrain"); if terrain then for _,v in ipairs(terrain:GetChildren()) do if v:GetAttribute("_AceDuelsSky") then pcall(function() v:Destroy() end) end end end
end
function applyCustomSky(mode)
_v4mpClearSky(); local p=SKY_PRESETS[mode]
if not p or p.kind=="off" then Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.GlobalShadows=true; skyTheme="Off"; return end
Lighting.ClockTime=p.clock or 14; Lighting.Brightness=p.brightness or 2; if p.ambient then Lighting.Ambient=_vC3(p.ambient) end; if p.outAmb then Lighting.OutdoorAmbient=_vC3(p.outAmb) end
local atm=Instance.new("Atmosphere"); atm:SetAttribute("_AceDuelsSky",true); atm.Density=0.35; atm.Color=Lighting.Ambient; atm.Decay=Lighting.OutdoorAmbient; atm.Parent=Lighting
local sky=Instance.new("Sky"); sky:SetAttribute("_AceDuelsSky",true); sky.StarCount=(mode=="Galaxy" or mode=="Deep Space") and 10000 or 2000; sky.Parent=Lighting
skyTheme=mode
end
_G.AceStretchFOV = _G.AceStretchFOV or 120
function enableStretchRez()
fpsBoostEnabled=true
local cam=workspace.CurrentCamera
if not cam then return end
if stretchRezConn then stretchRezConn:Disconnect(); stretchRezConn=nil end
stretchRezConn=RunService.RenderStepped:Connect(function()
if not fpsBoostEnabled then if stretchRezConn then stretchRezConn:Disconnect(); stretchRezConn=nil end; return end
cam=workspace.CurrentCamera
if cam then
if not fovEnabled then pcall(function() cam.FieldOfView=_G.AceStretchFOV end) end
end
end)
end
function disableStretchRez()
fpsBoostEnabled=false
if stretchRezConn then stretchRezConn:Disconnect(); stretchRezConn=nil end
if not fovEnabled and workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView=70 end
end
function enableCustomFov() fovEnabled=true; workspace.CurrentCamera.FieldOfView=fovValue; if customFovConn then customFovConn:Disconnect() end; customFovConn=RunService.RenderStepped:Connect(function() if not fovEnabled then customFovConn:Disconnect(); customFovConn=nil; return end; workspace.CurrentCamera.FieldOfView=fovValue end) end
function disableCustomFov() fovEnabled=false; if customFovConn then customFovConn:Disconnect(); customFovConn=nil end; workspace.CurrentCamera.FieldOfView=fpsBoostEnabled and 107 or 70 end
function _applyAntiLagObj(obj)
pcall(function()
if obj:IsA("BasePart") then obj.Material=Enum.Material.Plastic; obj.Reflectance=0; obj.CastShadow=false
elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency=1
elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then obj.Enabled=false end
end)
end
function applyKTMOptimization()
pcall(function() Lighting.GlobalShadows=false; Lighting.FogEnd=1e10; Lighting.EnvironmentDiffuseScale=0; Lighting.EnvironmentSpecularScale=0 end)
for _,obj in ipairs(workspace:GetDescendants()) do _applyAntiLagObj(obj) end
if antiLagDescConn then antiLagDescConn:Disconnect() end
antiLagDescConn=workspace.DescendantAdded:Connect(function(obj) if antiLagVisualEnabled or nukeOptimiserEnabled then _applyAntiLagObj(obj) end end)
end
function enableAntiLag() antiLagVisualEnabled=true; applyKTMOptimization() end
function disableAntiLag() antiLagVisualEnabled=false; if antiLagDescConn and not nukeOptimiserEnabled then antiLagDescConn:Disconnect(); antiLagDescConn=nil end end
function enableNukeOptimizer()
nukeOptimiserEnabled=true; _aceNukeOn=true; applyKTMOptimization(); applyCustomSky("Off")
for _,c in ipairs(_aceNukeConns) do pcall(function() c:Disconnect() end) end; _aceNukeConns={}
table.insert(_aceNukeConns, workspace.DescendantAdded:Connect(function(o) if nukeOptimiserEnabled then _applyAntiLagObj(o) end end))
task.spawn(function() while nukeOptimiserEnabled do pcall(function() setfpscap(240) end); task.wait(3) end end)
end
function disableNukeOptimizer() nukeOptimiserEnabled=false; _aceNukeOn=false; for _,c in ipairs(_aceNukeConns) do pcall(function() c:Disconnect() end) end; _aceNukeConns={} end
function enableNoCamCollision()
noCamCollisionEnabled=true; if noCamCollisionConn then noCamCollisionConn:Disconnect() end
noCamCollisionConn=RunService.RenderStepped:Connect(function()
if not noCamCollisionEnabled then return end
local cam=workspace.CurrentCamera; local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not cam or not hrp then return end
local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={char}; params.IgnoreWater=true
local res=workspace:Raycast(cam.CFrame.Position,(hrp.Position+Vector3.new(0,1.5,0))-cam.CFrame.Position,params)
local hit={}
if res and res.Instance and res.Instance:IsA("BasePart") then hit[res.Instance]=true; if noCamCollisionParts[res.Instance]==nil then noCamCollisionParts[res.Instance]=res.Instance.LocalTransparencyModifier end; res.Instance.LocalTransparencyModifier=1 end
for part,orig in pairs(noCamCollisionParts) do if not hit[part] then pcall(function() if part and part.Parent then part.LocalTransparencyModifier=orig end end); noCamCollisionParts[part]=nil end end
end)
end
function disableNoCamCollision() noCamCollisionEnabled=false; if noCamCollisionConn then noCamCollisionConn:Disconnect(); noCamCollisionConn=nil end; for p,orig in pairs(noCamCollisionParts) do pcall(function() if p and p.Parent then p.LocalTransparencyModifier=orig end end) end; noCamCollisionParts={} end
function enableCustomFont() customFontVisualEnabled=false; if V then V.customFontEnabled=false end end
function disableCustomFont() customFontVisualEnabled=false; if V then V.customFontEnabled=false end end
V = V or {}
V.skyTheme = skyTheme or V.skyTheme or "Off"
V.nukeOptEnabled = nukeOptimiserEnabled == true
V.customFontEnabled = false
V.potatoGraphicsEnabled = V.potatoGraphicsEnabled or false
function enableNoCamCollision()
noCamCollisionEnabled = true
if noCamCollisionConn then noCamCollisionConn:Disconnect() end
noCamCollisionConn = RunService.RenderStepped:Connect(function()
if not noCamCollisionEnabled then
if noCamCollisionConn then noCamCollisionConn:Disconnect();noCamCollisionConn=nil end
return
end
local cam = workspace.CurrentCamera
local char = LP.Character
if not cam or not char then return end
local hrp = char:FindFirstChild("HumanoidRootPart")
if not hrp then return end
local camPos = cam.CFrame.Position
local charPos = hrp.Position + Vector3.new(0,1.5,0)
local toChar = charPos - camPos
if toChar.Magnitude < 0.3 then return end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = {char}
params.IgnoreWater = true
local hit = {}
local origin = camPos
local remaining = toChar
for _ = 1,12 do
if remaining.Magnitude < 0.2 then break end
local res = workspace:Raycast(origin,remaining,params)
if not res then break end
local part = res.Instance
if part and part:IsA("BasePart") and not part:IsDescendantOf(char) then
hit[part] = true
if noCamCollisionParts[part] == nil then noCamCollisionParts[part] = part.LocalTransparencyModifier end
part.LocalTransparencyModifier = 1
end
origin = res.Position + remaining.Unit * 0.02
remaining = charPos - origin
end
for part,orig in pairs(noCamCollisionParts) do
if not hit[part] then
pcall(function() if part and part.Parent then part.LocalTransparencyModifier = orig end end)
noCamCollisionParts[part] = nil
end
end
end)
end
function disableNoCamCollision()
noCamCollisionEnabled = false
if noCamCollisionConn then noCamCollisionConn:Disconnect();noCamCollisionConn=nil end
for part,orig in pairs(noCamCollisionParts) do
pcall(function() if part and part.Parent then part.LocalTransparencyModifier = orig end end)
end
noCamCollisionParts = {}
end
SKY_PRESETS_LIST = {"Off","Night","Aurora","Sunset","Galaxy","Tech","Sakura","Pink Night",
"Blood Moon","Emerald Dawn","Volcanic","Arctic","Midnight Ocean","Vaporwave","Toxic","Solar Eclipse",
"Hellscape","Heaven","Storm","Sunrise","Deep Space","Lavender Dream","Inferno","Mint Sky"}
SKY_PRESETS = {
["Off"] = {kind = "off"},
["Night"] = {clock=22,brightness=2,ambient={110,100,130},outAmb={120,110,140},sky={stars=4000,moon=18,sun=0,moonTex=true},atm={dens=0.45,color={120,60,180},decay={60,20,100},glare=0.5,haze=1.2}},
["Aurora"] = {clock=14,brightness=3,ambient={150,120,150},outAmb={160,130,150},atm={dens=0.55,color={255,80,200},decay={255,20,150},glare=2.5,haze=3},clouds={cover=0.7,dens=0.7,color={255,240,250}}},
["Sunset"] = {clock=17.2,brightness=2.5,ambient={170,120,100},outAmb={180,130,110},sky={stars=0,sun=25,moon=0},atm={dens=0.5,color={255,130,60},decay={255,80,30},glare=2,haze=2.5},clouds={cover=0.55,dens=0.55,color={255,200,140}}},
["Galaxy"] = {clock=0,brightness=1.5,ambient={70,60,100},outAmb={80,70,110},sky={stars=10000,moon=30,sun=0},atm={dens=0.15,color={40,20,80},decay={20,10,50},glare=0.3,haze=0.5}},
["Tech"] = {clock=21,brightness=2.2,ambient={90,130,170},outAmb={100,140,180},sky={stars=2000,moon=12},atm={dens=0.4,color={0,200,255},decay={150,0,255},glare=2,haze=2},clouds={cover=0.4,dens=0.6,color={100,200,255}}},
["Sakura"] = {clock=11,brightness=3.5,ambient={170,150,160},outAmb={180,160,170},sky={sun=8},atm={dens=0.3,color={255,200,220},decay={255,170,200},glare=1,haze=1.5},clouds={cover=0.6,dens=0.4,color={255,250,252}}},
["Pink Night"] = {clock=23,brightness=2.2,ambient={120,60,110},outAmb={140,70,120},sky={stars=5000,moon=22,sun=0,moonTex=true},atm={dens=0.5,color={255,80,180},decay={140,30,100},glare=0.7,haze=1.4},clouds={cover=0.3,dens=0.5,color={180,90,150}}},
["Blood Moon"] = {clock=22.5,brightness=1.6,ambient={130,40,40},outAmb={150,50,50},sky={stars=1500,moon=28,sun=0,moonTex=true},atm={dens=0.6,color={220,30,30},decay={120,10,10},glare=1.4,haze=2},clouds={cover=0.5,dens=0.7,color={120,30,30}}},
["Emerald Dawn"] = {clock=6.5,brightness=2.8,ambient={130,170,140},outAmb={140,180,150},sky={sun=18,moon=0,stars=0},atm={dens=0.4,color={80,200,140},decay={40,150,90},glare=1.8,haze=2.2},clouds={cover=0.5,dens=0.5,color={200,255,220}}},
["Volcanic"] = {clock=19,brightness=2,ambient={180,80,40},outAmb={200,90,50},sky={stars=200,sun=12,moon=0},atm={dens=0.75,color={255,60,0},decay={180,20,0},glare=3,haze=3.5},clouds={cover=0.8,dens=0.9,color={120,40,20}}},
["Arctic"] = {clock=9,brightness=3.2,ambient={200,220,235},outAmb={210,230,245},sky={sun=10,stars=0,moon=0},atm={dens=0.3,color={180,220,255},decay={140,200,240},glare=1.5,haze=1.8},clouds={cover=0.7,dens=0.6,color={250,253,255}}},
["Midnight Ocean"] = {clock=1.5,brightness=1.7,ambient={60,90,130},outAmb={70,100,140},sky={stars=6000,moon=24,sun=0,moonTex=true},atm={dens=0.5,color={20,60,140},decay={10,30,90},glare=0.6,haze=1.5}},
["Vaporwave"] = {clock=19.5,brightness=2.4,ambient={180,120,200},outAmb={190,130,210},sky={stars=1000,moon=14},atm={dens=0.45,color={255,100,220},decay={120,60,255},glare=2.2,haze=2.4},clouds={cover=0.5,dens=0.55,color={200,150,255}}},
["Toxic"] = {clock=13,brightness=2.5,ambient={140,180,80},outAmb={150,190,90},atm={dens=0.55,color={100,220,40},decay={60,150,20},glare=1.8,haze=2.6},clouds={cover=0.65,dens=0.7,color={180,255,120}}},
["Solar Eclipse"] = {clock=12,brightness=0.9,ambient={50,40,60},outAmb={60,50,70},sky={stars=3500,sun=22,moon=0},atm={dens=0.5,color={255,140,40},decay={30,20,40},glare=2.8,haze=1.8}},
["Hellscape"] = {clock=18,brightness=1.8,ambient={200,60,30},outAmb={220,70,40},sky={stars=100,sun=30,moon=0},atm={dens=0.85,color={255,30,0},decay={120,0,0},glare=3.5,haze=4},clouds={cover=0.95,dens=0.95,color={80,20,10}}},
["Heaven"] = {clock=12,brightness=4,ambient={240,235,210},outAmb={250,245,220},sky={sun=16,moon=0,stars=0},atm={dens=0.25,color={255,250,220},decay={255,240,200},glare=3,haze=1.5},clouds={cover=0.85,dens=0.5,color={255,255,255}}},
["Storm"] = {clock=15,brightness=1.4,ambient={90,90,110},outAmb={100,100,120},sky={stars=0,sun=6,moon=0},atm={dens=0.65,color={80,90,120},decay={40,50,80},glare=0.5,haze=3},clouds={cover=0.95,dens=0.95,color={60,65,80}}},
["Sunrise"] = {clock=6.2,brightness=2.8,ambient={220,180,130},outAmb={230,190,140},sky={sun=22,stars=0,moon=0},atm={dens=0.45,color={255,180,100},decay={255,140,80},glare=2.4,haze=2.2},clouds={cover=0.4,dens=0.4,color={255,220,180}}},
["Deep Space"] = {clock=0,brightness=1,ambient={30,25,50},outAmb={40,35,60},sky={stars=15000,moon=0,sun=0},atm={dens=0.08,color={15,5,40},decay={5,0,20},glare=0.2,haze=0.3}},
["Lavender Dream"] = {clock=18.5,brightness=2.6,ambient={180,160,220},outAmb={190,170,230},sky={stars=800,moon=16,sun=0},atm={dens=0.4,color={200,160,255},decay={160,120,220},glare=1.4,haze=1.8},clouds={cover=0.55,dens=0.5,color={220,200,255}}},
["Inferno"] = {clock=17.5,brightness=2.2,ambient={220,100,40},outAmb={235,110,50},sky={sun=26,moon=0,stars=0},atm={dens=0.6,color={255,90,20},decay={200,40,0},glare=3,haze=3.2},clouds={cover=0.7,dens=0.7,color={200,80,40}}},
["Mint Sky"] = {clock=10,brightness=3.2,ambient={180,230,210},outAmb={190,240,220},sky={sun=10},atm={dens=0.32,color={150,255,210},decay={100,220,180},glare=1.6,haze=1.6},clouds={cover=0.55,dens=0.45,color={240,255,250}}},
}
function _vC3(t) return Color3.fromRGB(t[1], t[2], t[3]) end
function _v4mpClearSky()
for _, v in ipairs(Lighting:GetChildren()) do
if v:GetAttribute("_AceDuelsSky") then pcall(function() v:Destroy() end) end
end
local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain then
for _, v in ipairs(terrain:GetChildren()) do
if v:GetAttribute("_AceDuelsSky") then pcall(function() v:Destroy() end) end
end
end
end
function applyCustomSky(mode)
_v4mpClearSky()
local preset = SKY_PRESETS[mode]
if not preset or preset.kind == "off" then
Lighting.FogEnd = 100000; Lighting.FogStart = 0
Lighting.FogColor = Color3.fromRGB(192,192,192)
Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = true
V.skyTheme = "Off"
return
end
Lighting.FogEnd = 100000; Lighting.FogStart = 0
Lighting.FogColor = Color3.fromRGB(200,200,200)
Lighting.GlobalShadows = true
Lighting.ClockTime = preset.clock or 14
Lighting.Brightness = preset.brightness or 2
if preset.outAmb then Lighting.OutdoorAmbient = _vC3(preset.outAmb) end
if preset.ambient then Lighting.Ambient = _vC3(preset.ambient) end
if preset.sky then
local sky = Instance.new("Sky")
sky:SetAttribute("_AceDuelsSky", true)
if preset.sky.stars then sky.StarCount = preset.sky.stars end
if preset.sky.moon then sky.MoonAngularSize = preset.sky.moon end
if preset.sky.sun then sky.SunAngularSize = preset.sky.sun end
if preset.sky.moonTex then sky.MoonTextureId = "rbxasset://sky/moon.jpg" end
sky.Parent = Lighting
end
if preset.atm then
local atm = Instance.new("Atmosphere")
atm:SetAttribute("_AceDuelsSky", true)
atm.Density = preset.atm.dens or 0.3
atm.Color = _vC3(preset.atm.color)
atm.Decay = _vC3(preset.atm.decay)
atm.Glare = preset.atm.glare or 1
atm.Haze = preset.atm.haze or 1
atm.Parent = Lighting
end
local terrain = workspace:FindFirstChildOfClass("Terrain")
if preset.clouds and terrain then
local clouds = Instance.new("Clouds")
clouds:SetAttribute("_AceDuelsSky", true)
clouds.Cover = preset.clouds.cover or 0.5
clouds.Density = preset.clouds.dens or 0.5
clouds.Color = _vC3(preset.clouds.color)
clouds.Parent = terrain
end
V.skyTheme = mode
end
function enableUltraMode()
V.ultraModeEnabled = true
applyKTMOptimization()
end
function disableUltraMode()
V.ultraModeEnabled = false
end
function enableRemoveAccessories()
V.removeAccessoriesEnabledSep = true
removeAccessoriesEnabled = true
removeAllAccessories()
if V.removeAccConn then V.removeAccConn:Disconnect() end
V.removeAccConn = Players.PlayerAdded:Connect(function(player)
player.CharacterAdded:Connect(function(char)
task.wait(0.5)
if V.removeAccessoriesEnabledSep or removeAccessoriesEnabled then
for _,obj in ipairs(char:GetDescendants()) do processAntiLagDescendant(obj) end
end
end)
end)
if antiLagDescConn then antiLagDescConn:Disconnect() end
antiLagDescConn = Workspace.DescendantAdded:Connect(function(obj)
if antiLagEnabled or V.ultraModeEnabled or removeAccessoriesEnabled or V.removeAccessoriesEnabledSep then
processAntiLagDescendant(obj)
end
end)
end
function disableRemoveAccessories()
V.removeAccessoriesEnabledSep = false
removeAccessoriesEnabled = false
if V.removeAccConn then V.removeAccConn:Disconnect(); V.removeAccConn = nil end
if not antiLagEnabled and not V.ultraModeEnabled and antiLagDescConn then antiLagDescConn:Disconnect(); antiLagDescConn = nil end
end
_nukeOptimizerOn = false
_nukeOptimizerConns = {}
_nukeOptimizerThreads = {}
function enableNukeOptimizer()
if _nukeOptimizerOn then return end
_nukeOptimizerOn = true
nukeOptimiserEnabled = true
V.nukeOptEnabled = true
local MaterialService = game:GetService("MaterialService")
local XMin, XMax = -560, -240
local ClothingClasses = {"Shirt","Pants","ShirtGraphic","Accessory","Hat","HairAccessory","FaceAccessory","NeckAccessory","ShoulderAccessory","FrontAccessory","BackAccessory","WaistAccessory"}
local BASE_NAMES = {"baseplate","spawnlocation","spawn location","spawn"}
function SafeDestroy(obj)
if obj and obj.Name == "Overhead" then return end
pcall(function() obj:Destroy() end)
end
function IsClothing(obj)
for _, className in ipairs(ClothingClasses) do
if obj:IsA(className) then return true end
end
return false
end
function IsCharacterPart(obj)
for _, plr in ipairs(Players:GetPlayers()) do
if plr.Character and obj:IsDescendantOf(plr.Character) then return true end
end
return false
end
function IsOutOfRange(obj)
if obj:IsA("BasePart") then
local x = obj.Position.X
return x < XMin or x > XMax
end
return false
end
function IsBase(obj)
if not obj:IsA("BasePart") then return false end
local nl = obj.Name:lower()
for _, n in ipairs(BASE_NAMES) do
if nl:find(n, 1, true) then return true end
end
return false
end
function IsInBase(obj)
local p = obj.Parent
while p and p ~= workspace do
if IsBase(p) then return true end
p = p.Parent
end
return false
end
function MakeTransparent(obj)
pcall(function()
if IsBase(obj) and not IsCharacterPart(obj) then
obj.Transparency = 1
obj.CastShadow = false
end
end)
end
function StripObject(obj)
pcall(function()
if obj:IsA("Texture") or obj:IsA("Decal") or obj:IsA("SpecialMesh") then
SafeDestroy(obj)
elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
pcall(function() obj.Enabled = false end)
SafeDestroy(obj)
elseif obj:IsA("SurfaceAppearance") then
SafeDestroy(obj)
elseif obj:IsA("BasePart") then
obj.CastShadow = false
obj.Material = Enum.Material.Plastic
obj.MaterialVariant = ""
obj.Reflectance = 0
end
end)
end
function CleanObject(obj)
pcall(function()
if obj:IsA("SurfaceAppearance") then
SafeDestroy(obj)
elseif obj:IsA("Decal") or obj:IsA("Texture") then
if not (obj.Name == "face" and obj.Parent and obj.Parent.Name == "Head") then SafeDestroy(obj) end
elseif obj:IsA("SpecialMesh") then
obj.TextureId = ""
elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
SafeDestroy(obj)
elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
SafeDestroy(obj)
elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Explosion") then
SafeDestroy(obj)
elseif obj:IsA("Animation") or obj:IsA("AnimationController") then
SafeDestroy(obj)
elseif obj:IsA("BasePart") then
obj.CastShadow = false
obj.Material = Enum.Material.Plastic
obj.MaterialVariant = ""
obj.Reflectance = 0
end
end)
end
function ApplyGreySky()
pcall(function()
for _, obj in ipairs(Lighting:GetChildren()) do
if obj:IsA("Sky") then obj:Destroy() end
end
local sky = Instance.new("Sky")
sky.SkyboxBk = ""; sky.SkyboxDn = ""; sky.SkyboxFt = ""
sky.SkyboxLf = ""; sky.SkyboxRt = ""; sky.SkyboxUp = ""
sky.CelestialBodiesShown = false
sky.Name = "_AceDuelsNukeSky"
sky.Parent = Lighting
end)
end
function OptimizeLighting()
pcall(function()
Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
Lighting.FogStart = 9e9
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
Lighting.Brightness = 1.5
Lighting.Ambient = Color3.fromRGB(60,60,60)
for _, v in ipairs(Lighting:GetChildren()) do
if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("Atmosphere") or v:IsA("Clouds") then
v:Destroy()
end
end
ApplyGreySky()
end)
end
function ApplyTerrain()
pcall(function()
local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain then
terrain.Decoration = false
terrain.WaterWaveSize = 0
terrain.WaterWaveSpeed = 0
terrain.WaterReflectance = 0
terrain.WaterTransparency = 1
end
end)
end
function OptimizeCharacter(char)
if not char then return end
task.spawn(function()
task.wait(0.3)
if not _nukeOptimizerOn then return end
for _, obj in ipairs(char:GetDescendants()) do
if IsClothing(obj) then SafeDestroy(obj) else CleanObject(obj) end
end
end)
end
pcall(function()
settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
end)
pcall(function() if setfpscap then setfpscap(999) end end)
table.insert(_nukeOptimizerThreads, task.spawn(function()
if not game:IsLoaded() then game.Loaded:Wait() end
OptimizeLighting()
ApplyTerrain()
for _, obj in ipairs(workspace:GetDescendants()) do
if not _nukeOptimizerOn then return end
if IsBase(obj) then
MakeTransparent(obj)
elseif IsClothing(obj) then
SafeDestroy(obj)
elseif IsInBase(obj) then
elseif IsCharacterPart(obj) then
elseif IsOutOfRange(obj) then
SafeDestroy(obj)
else
CleanObject(obj)
StripObject(obj)
end
end
for _, obj in ipairs(workspace:GetDescendants()) do MakeTransparent(obj) end
end))
table.insert(_nukeOptimizerConns, workspace.DescendantAdded:Connect(function(obj)
if not _nukeOptimizerOn then return end
task.defer(function()
if not _nukeOptimizerOn then return end
if IsBase(obj) then MakeTransparent(obj); return end
if IsClothing(obj) then
SafeDestroy(obj)
elseif IsInBase(obj) then
elseif IsCharacterPart(obj) then
elseif IsOutOfRange(obj) then
SafeDestroy(obj)
else
CleanObject(obj)
StripObject(obj)
end
end)
end))
table.insert(_nukeOptimizerConns, Lighting.DescendantAdded:Connect(function(obj)
if not _nukeOptimizerOn then return end
if obj:IsA("Atmosphere") or obj:IsA("Clouds") or obj:IsA("PostEffect") then SafeDestroy(obj) end
end))
table.insert(_nukeOptimizerConns, MaterialService.DescendantAdded:Connect(function(obj)
if not _nukeOptimizerOn then return end
SafeDestroy(obj)
end))
for _, plr in ipairs(Players:GetPlayers()) do
OptimizeCharacter(plr.Character)
table.insert(_nukeOptimizerConns, plr.CharacterAdded:Connect(OptimizeCharacter))
end
table.insert(_nukeOptimizerConns, Players.PlayerAdded:Connect(function(plr)
table.insert(_nukeOptimizerConns, plr.CharacterAdded:Connect(OptimizeCharacter))
end))
table.insert(_nukeOptimizerThreads, task.spawn(function()
while _nukeOptimizerOn do
task.wait(15)
pcall(function() collectgarbage("collect") end)
end
end))
end
function disableNukeOptimizer()
_nukeOptimizerOn = false
nukeOptimiserEnabled = false
V.nukeOptEnabled = false
for _, c in ipairs(_nukeOptimizerConns) do pcall(function() c:Disconnect() end) end
_nukeOptimizerConns = {}
_nukeOptimizerThreads = {}
end
function enableCustomFont() customFontVisualEnabled=false; if V then V.customFontEnabled=false end end
function disableCustomFont() customFontVisualEnabled=false; if V then V.customFontEnabled=false end end
__ace_src_enableNoCamCollision = enableNoCamCollision
function enableNoCamCollision()
__ace_src_enableNoCamCollision()
noCamCollisionEnabled = true
end
__ace_src_disableNoCamCollision = disableNoCamCollision
function disableNoCamCollision()
__ace_src_disableNoCamCollision()
noCamCollisionEnabled = false
end
end

-- ====================================================================
-- AUTO GRAB V2 (verbatim, _KAG_executeSteal copied byte-for-byte,
-- non-negotiable — DO NOT MODIFY)
-- ====================================================================
-- ===================================================================
-- AUTO STEAL (Auto Grab — logique Irish Hub / test_speed.lua)
-- ===================================================================
do
AutoSteal = {
	Enabled=true, Radius=70, IsStealing=false,
	ProgressFill=nil, ProgressText=nil, StatusLabel=nil,
	SetFastPulse=nil, FlashSuccess=nil, Widget=nil,
}


-- ── AUTO GRAB V2 mode (new default) ────────────────────────────
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

function startAutoStealV2()
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
function stopAutoStealV2()
	_KAG_started=false
	if _KAG_conn then _KAG_conn:Disconnect(); _KAG_conn=nil end
	if _KAG_scanTask then pcall(task.cancel,_KAG_scanTask); _KAG_scanTask=nil end
	_KAG_Active=false; State.isStealing=false
	if AutoSteal.StatusLabel then AutoSteal.StatusLabel.Text="READY" end
end

function startAutoSteal() startAutoStealV2() end
end

-- ====================================================================
-- EXTRA ANTI-KICK / ANTI-DETECT LAYER (ported from Moon_Duel_v3, kept as
-- an additional protective layer alongside the Ace safe-mode kernel)
-- ====================================================================
local function setupVoidAntiKick()
	local _nc
	local ok = pcall(function()
		_nc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local m = getnamecallmethod()
			if m == "Kick" then return end
			if m == "Shutdown" and self == game then return end
			return _nc(self, ...)
		end))
	end)
	if not ok then return end
	local h1 = RunService.Heartbeat:Connect(function()
		local c = LP.Character; local h = c and c:FindFirstChildOfClass("Humanoid")
		if h then
			if h.MaxHealth ~= 100 then pcall(function() h.MaxHealth = 100 end) end
			if h.Health < 100 then pcall(function() h.Health = 100 end) end
		end
	end)
	reg(function() h1:Disconnect() end)
	local h2 = RunService.Heartbeat:Connect(function()
		if LP.Character and LP.Character.Parent ~= workspace then
			pcall(function() LP.Character.Parent = workspace end)
		end
	end)
	reg(function() h2:Disconnect() end)
end
pcall(setupVoidAntiKick)

-- ===================================================================
-- VOID UI  (fresh rebuild, style ported from Moon_Duel_v3.lua)
-- ===================================================================
do
	local RS  = RunService
	local UIS = UserInputService

	local function H(s) return Color3.fromHex(s) end
	local BG    = H"060609"
	local SURF  = H"0D0D14"
	local ACC   = H"8B5CF6"
	local HOT   = H"F43F5E"
	local TEXTC = H"E2E2F0"
	local DIM   = H"3D3D55"
	local MUTED = H"6B6B8A"
	local BORD  = H"1C1C2E"

	local W, ROW_H, PAD, HDR_H, TAB_H = 236, 24, 8, 30, 24

	local gui = Instance.new("ScreenGui")
	gui.Name = "MoonDuelV4Void"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if protectgui then pcall(protectgui, gui) end
	gui.Parent = (cloneref or function(s) return s end)(game:GetService("CoreGui"))
	reg(function() pcall(function() gui:Destroy() end) end)

	local frame = Instance.new("Frame", gui)
	frame.Name = "Hub"
	frame.Size = UDim2.new(0, W, 0, 360)
	frame.Position = UDim2.new(0, 120, 0, 120)
	frame.BackgroundColor3 = BG
	frame.BorderSizePixel = 0
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
	do
		local s = Instance.new("UIStroke", frame)
		s.Color = BORD; s.Thickness = 1
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end

	-- drag
	do
		local drag, ox, oy = false, 0, 0
		local hdrHit = frame
		hdrHit.InputBegan:Connect(function(i)
			local t = i.UserInputType
			if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and i.Position.Y - frame.AbsolutePosition.Y <= HDR_H then
				drag = true
				ox = i.Position.X - frame.AbsolutePosition.X
				oy = i.Position.Y - frame.AbsolutePosition.Y
			end
		end)
		UIS.InputChanged:Connect(function(i)
			local t = i.UserInputType
			if drag and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
				frame.Position = UDim2.new(0, i.Position.X - ox, 0, i.Position.Y - oy)
			end
		end)
		UIS.InputEnded:Connect(function(i)
			local t = i.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then drag = false end
		end)
	end

	-- header
	local hdr = Instance.new("Frame", frame)
	hdr.Size = UDim2.new(1, 0, 0, HDR_H)
	hdr.BackgroundColor3 = SURF
	hdr.BorderSizePixel = 0
	Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 10)
	local hdrCover = Instance.new("Frame", hdr)
	hdrCover.Size = UDim2.new(1, 0, 0, 10)
	hdrCover.Position = UDim2.new(0, 0, 1, -10)
	hdrCover.BackgroundColor3 = SURF
	hdrCover.BorderSizePixel = 0

	local adot = Instance.new("Frame", hdr)
	adot.Size = UDim2.new(0, 5, 0, 5)
	adot.Position = UDim2.new(0, 10, 0.5, -2.5)
	adot.BackgroundColor3 = ACC
	adot.BorderSizePixel = 0
	Instance.new("UICorner", adot).CornerRadius = UDim.new(1, 0)

	local title = Instance.new("TextLabel", hdr)
	title.Size = UDim2.new(1, -70, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "MOON DUEL · VOID"
	title.TextColor3 = TEXTC
	title.Font = Enum.Font.GothamBold
	title.TextSize = 10
	title.TextXAlignment = Enum.TextXAlignment.Left

	local minBtn = Instance.new("TextButton", hdr)
	minBtn.Size = UDim2.new(0, 20, 0, 20)
	minBtn.Position = UDim2.new(1, -46, 0.5, -10)
	minBtn.BackgroundTransparency = 1
	minBtn.Text = "–"
	minBtn.TextColor3 = DIM
	minBtn.Font = Enum.Font.GothamBold
	minBtn.TextSize = 14

	local xBtn = Instance.new("TextButton", hdr)
	xBtn.Size = UDim2.new(0, 20, 0, 20)
	xBtn.Position = UDim2.new(1, -24, 0.5, -10)
	xBtn.BackgroundTransparency = 1
	xBtn.Text = "×"
	xBtn.TextColor3 = DIM
	xBtn.Font = Enum.Font.GothamBold
	xBtn.TextSize = 14
	xBtn.MouseButton1Click:Connect(function() _G["_MOON_V4_VOID"]() end)

	-- body container (everything below header, hidden on minimize)
	local body = Instance.new("Frame", frame)
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.new(0, 0, 0, HDR_H)
	body.Size = UDim2.new(1, 0, 1, -HDR_H)
	body.ClipsDescendants = true

	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		body.Visible = not minimized
		frame.Size = minimized and UDim2.new(0, W, 0, HDR_H) or UDim2.new(0, W, 0, 360)
	end)

	local hdiv = Instance.new("Frame", body)
	hdiv.Size = UDim2.new(1, -16, 0, 1)
	hdiv.Position = UDim2.new(0, 8, 0, 0)
	hdiv.BackgroundColor3 = BORD
	hdiv.BorderSizePixel = 0

	-- tab bar
	local tabBar = Instance.new("Frame", body)
	tabBar.Size = UDim2.new(1, -16, 0, TAB_H)
	tabBar.Position = UDim2.new(0, 8, 0, 5)
	tabBar.BackgroundTransparency = 1
	tabBar.BorderSizePixel = 0

	local TAB_NAMES = {"MAIN", "COMBAT", "VISUALS", "KEYBINDS", "STATUS"}
	local tabButtons, pages = {}, {}

	local pageHolder = Instance.new("ScrollingFrame", body)
	pageHolder.Size = UDim2.new(1, -16, 1, -(TAB_H + 14))
	pageHolder.Position = UDim2.new(0, 8, 0, TAB_H + 12)
	pageHolder.BackgroundTransparency = 1
	pageHolder.BorderSizePixel = 0
	pageHolder.ScrollBarThickness = 2
	pageHolder.ScrollBarImageColor3 = DIM
	pageHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
	pageHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local function mkTabBtn(i, name)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1 / #TAB_NAMES, -3, 1, 0)
		b.Position = UDim2.new((i - 1) / #TAB_NAMES, 0, 0, 0)
		b.BackgroundColor3 = SURF
		b.BorderSizePixel = 0
		b.Text = name
		b.TextColor3 = MUTED
		b.Font = Enum.Font.GothamBold
		b.TextSize = 8
		b.Parent = tabBar
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
		return b
	end

	local function setTab(idx)
		for i, pg in ipairs(pages) do
			pg.Visible = (i == idx)
			tabButtons[i].TextColor3 = (i == idx) and TEXTC or MUTED
			tabButtons[i].BackgroundColor3 = (i == idx) and H"14141F" or SURF
		end
	end

	for i, name in ipairs(TAB_NAMES) do
		local b = mkTabBtn(i, name)
		tabButtons[i] = b
		local pg = Instance.new("Frame")
		pg.Name = name
		pg.BackgroundTransparency = 1
		pg.BorderSizePixel = 0
		pg.Size = UDim2.new(1, 0, 0, 0)
		pg.AutomaticSize = Enum.AutomaticSize.Y
		pg.Visible = false
		pg.Parent = pageHolder
		local lay = Instance.new("UIListLayout", pg)
		lay.SortOrder = Enum.SortOrder.LayoutOrder
		lay.Padding = UDim.new(0, 3)
		pages[i] = pg
		b.MouseButton1Click:Connect(function() setTab(i) end)
	end
	setTab(1)

	-- everything below is built inside its own function so its many local
	-- widget references stay scoped to a single fresh register window and
	-- never accumulate against the outer chunk's local-variable budget.
	local function _buildVoidUI()

	-- ── widget builders (mkRow / mkLbl / mkDot / mkIn / mkBtn) ─────────────
	local ROW_ORDER = 0
	local function mkRow(page, h)
		ROW_ORDER = ROW_ORDER + 1
		local f = Instance.new("Frame", page)
		f.Size = UDim2.new(1, 0, 0, h or ROW_H)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.LayoutOrder = ROW_ORDER
		return f
	end

	local function mkSection(page, txt)
		local f = mkRow(page, 16)
		local l = Instance.new("TextLabel", f)
		l.Size = UDim2.new(1, 0, 1, 0)
		l.BackgroundTransparency = 1
		l.Text = txt
		l.TextColor3 = ACC
		l.Font = Enum.Font.GothamBold
		l.TextSize = 8
		l.TextXAlignment = Enum.TextXAlignment.Left
		return f
	end

	local function mkLbl(p, txt, x, w)
		local l = Instance.new("TextLabel", p)
		l.Size = UDim2.new(0, w, 1, 0)
		l.Position = UDim2.new(0, x, 0, 0)
		l.BackgroundTransparency = 1
		l.Text = txt
		l.TextColor3 = MUTED
		l.Font = Enum.Font.Gotham
		l.TextSize = 9
		l.TextXAlignment = Enum.TextXAlignment.Left
		return l
	end

	local function mkDot(p, x, on, cb)
		local outer = Instance.new("Frame", p)
		outer.Size = UDim2.new(0, 14, 0, 14)
		outer.Position = UDim2.new(0, x, 0.5, -7)
		outer.BackgroundColor3 = BORD
		outer.BorderSizePixel = 0
		Instance.new("UICorner", outer).CornerRadius = UDim.new(1, 0)
		local inner = Instance.new("Frame", outer)
		inner.Size = UDim2.new(0, 8, 0, 8)
		inner.Position = UDim2.new(0.5, -4, 0.5, -4)
		inner.BorderSizePixel = 0
		Instance.new("UICorner", inner).CornerRadius = UDim.new(1, 0)
		local st = on and true or false
		local function rf()
			inner.BackgroundColor3 = st and ACC or DIM
			outer.BackgroundColor3 = st and H"18103A" or BORD
		end
		rf()
		local hit = Instance.new("TextButton", outer)
		hit.Size = UDim2.new(1, 0, 1, 0)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.MouseButton1Click:Connect(function()
			st = not st; rf(); if cb then pcall(cb, st) end
		end)
		return function(v) st = v and true or false; rf() end
	end

	local function mkIn(p, x, w, init, cb)
		local b = Instance.new("TextBox", p)
		b.Size = UDim2.new(0, w, 0, 18)
		b.Position = UDim2.new(0, x, 0.5, -9)
		b.BackgroundColor3 = SURF
		b.BorderSizePixel = 0
		b.Text = tostring(init)
		b.TextColor3 = TEXTC
		b.PlaceholderColor3 = DIM
		b.Font = Enum.Font.Gotham
		b.TextSize = 10
		b.ClearTextOnFocus = false
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		local s = Instance.new("UIStroke", b); s.Color = BORD; s.Thickness = 1
		b.Focused:Connect(function() s.Color = ACC end)
		b.FocusLost:Connect(function()
			s.Color = BORD
			local n = tonumber(b.Text)
			if n then pcall(cb, n) else b.Text = tostring(init) end
		end)
		return b
	end

	local function mkBtn(p, txt, cb)
		local b = Instance.new("TextButton", p)
		b.Size = UDim2.new(1, 0, 0, 20)
		b.Position = UDim2.new(0, 0, 0.5, -10)
		b.BackgroundColor3 = SURF
		b.BorderSizePixel = 0
		b.Text = txt
		b.TextColor3 = MUTED
		b.Font = Enum.Font.Gotham
		b.TextSize = 9
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
		local s = Instance.new("UIStroke", b); s.Color = BORD; s.Thickness = 1
		b.MouseEnter:Connect(function() s.Color = HOT; b.TextColor3 = HOT end)
		b.MouseLeave:Connect(function() s.Color = BORD; b.TextColor3 = MUTED end)
		b.MouseButton1Click:Connect(function() pcall(cb) end)
		return b
	end

	-- small helper: full-width toggle row "LABEL ............ [dot]"
	local function toggleRowVoid(page, label, init, cb)
		local r = mkRow(page)
		mkLbl(r, label, 0, W - 60)
		mkDot(r, W - 40, init, cb)
		return r
	end

	-- small helper: label + numeric input row
	local function inputRowVoid(page, label, init, cb, boxW)
		local r = mkRow(page)
		mkLbl(r, label, 0, 100)
		mkIn(r, 100, boxW or 76, init, cb)
		return r
	end

	-- =====================================================================
	-- MAIN TAB
	-- =====================================================================
	local Main = pages[1]
	mkSection(Main, "MOVEMENT")
	toggleRowVoid(Main, "Carry Speed", currentSpeedMode == "Carry", function(on) toggleRefs = toggleRefs or {}; setCarry(on) end)
	toggleRowVoid(Main, "Lagger Mode", currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry", function(on) setLagger(on) end)
	inputRowVoid(Main, "Normal Speed", NS, function(v) NS = v; State.normalSpeed = v; saveAceConfig() end)
	inputRowVoid(Main, "Carry Speed", CS, function(v) CS = v; State.carrySpeed = v; saveAceConfig() end)
	inputRowVoid(Main, "Lagger Speed", LAGGER_SPEED, function(v) LAGGER_SPEED = v; State.laggerSpeed = v; saveAceConfig() end)
	inputRowVoid(Main, "Lagger Carry Spd", LAGGER_CARRY_SPEED, function(v) LAGGER_CARRY_SPEED = v; saveAceConfig() end)
	toggleRowVoid(Main, "Infinite Jump", infJumpEnabled, function(on) setInfJumpInternal(on); saveAceConfig() end)
	toggleRowVoid(Main, "Anti-Ragdoll", antiRagdollEnabled, function(on) setAntiRagdoll(on); saveAceConfig() end)
	toggleRowVoid(Main, "Unwalk", selectedAnimationPack == "Unwalk", function(on)
		applyAnimationPack(on and "Unwalk" or "OFF"); saveAceConfig()
	end)

	mkSection(Main, "AUTO LEFT / RIGHT")
	local rLR = mkRow(Main)
	local lrW = (W - 16) / 2
	do
		local bL = Instance.new("TextButton", rLR)
		bL.Size = UDim2.new(0, lrW, 0, 20)
		bL.Position = UDim2.new(0, 0, 0.5, -10)
		bL.BackgroundColor3 = SURF; bL.BorderSizePixel = 0
		bL.Text = "AUTO LEFT"; bL.TextColor3 = MUTED
		bL.Font = Enum.Font.Gotham; bL.TextSize = 9
		Instance.new("UICorner", bL).CornerRadius = UDim.new(0, 5)
		local sL = Instance.new("UIStroke", bL); sL.Color = BORD; sL.Thickness = 1
		bL.MouseButton1Click:Connect(function()
			_G.AceSetAutoLeft(not autoLeftEnabled)
			bL.TextColor3 = autoLeftEnabled and HOT or MUTED
			sL.Color = autoLeftEnabled and HOT or BORD
		end)
		local bR = Instance.new("TextButton", rLR)
		bR.Size = UDim2.new(0, lrW, 0, 20)
		bR.Position = UDim2.new(0, lrW + 8, 0.5, -10)
		bR.BackgroundColor3 = SURF; bR.BorderSizePixel = 0
		bR.Text = "AUTO RIGHT"; bR.TextColor3 = MUTED
		bR.Font = Enum.Font.Gotham; bR.TextSize = 9
		Instance.new("UICorner", bR).CornerRadius = UDim.new(0, 5)
		local sR = Instance.new("UIStroke", bR); sR.Color = BORD; sR.Thickness = 1
		bR.MouseButton1Click:Connect(function()
			_G.AceSetAutoRight(not autoRightEnabled)
			bR.TextColor3 = autoRightEnabled and HOT or MUTED
			sR.Color = autoRightEnabled and HOT or BORD
		end)
	end

	mkSection(Main, "AUTO TP DOWN")
	toggleRowVoid(Main, "Auto TP Down", autoTPEnabled, function(on) toggleAutoTP(on) end)
	inputRowVoid(Main, "TP Height", autoTPHeight, function(v) autoTPHeight = v; saveAceConfig() end)
	mkBtn(mkRow(Main, 26), "TP DOWN NOW", runTPFloor)
	mkBtn(mkRow(Main, 26), "DROP BRAINROT", runDropBrainrot)
	mkBtn(mkRow(Main, 26), "INSTA RESET", function() cursedInstaReset() end)

	-- =====================================================================
	-- COMBAT TAB (auto steal / counters / safe mode)
	-- =====================================================================
	local Combat = pages[2]
	mkSection(Combat, "AUTO STEAL")
	toggleRowVoid(Combat, "Auto Steal", AutoSteal.Enabled, function(on)
		AutoSteal.Enabled = on
		if on then startAutoStealV2() else stopAutoStealV2() end
	end)
	inputRowVoid(Combat, "Steal Radius", AutoSteal.Radius, function(v) AutoSteal.Radius = v end)
	AutoSteal.StatusLabel = mkLbl(mkRow(Combat), "STATUS: READY", 0, W - 16)

	mkSection(Combat, "COUNTERS")
	toggleRowVoid(Combat, "Bat Counter", batCounterEnabled, function(on)
		batCounterEnabled = on
		if on then _G.AceStartBatCounter() else _G.AceStopBatCounter() end
		saveAceConfig()
	end)
	toggleRowVoid(Combat, "Med Counter", medCounterEnabled, function(on)
		medCounterEnabled = on
		if on then _G.AceStartMedCounter(LP.Character) else _G.AceStopMedCounter() end
		saveAceConfig()
	end)
	toggleRowVoid(Combat, "Auto Reset On Med", autoResetOnMedEnabled, function(on)
		_G.AceSetAutoResetOnMed(on)
	end)
	toggleRowVoid(Combat, "No Player Collision", _G.AceNoPlayerCollisionEnabled, function(on)
		_G.AceNoPlayerCollisionEnabled = on
		if on then
			if enableNoPlayerCollision then enableNoPlayerCollision() end
		else
			if disableNoPlayerCollision then disableNoPlayerCollision() end
		end
		saveAceConfig()
	end)
	toggleRowVoid(Combat, "Safe Mode (Anti-Kick)", antiKickEnabled, function(on)
		antiKickEnabled = on
		if antiKickEnabled and _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE") end
		saveAceConfig()
	end)

	-- =====================================================================
	-- VISUALS TAB (optimize / esp / fov / sky)
	-- =====================================================================
	local Visuals = pages[3]
	mkSection(Visuals, "PERFORMANCE")
	toggleRowVoid(Visuals, "Anti-Lag", antiLagVisualEnabled, function(on)
		if on then pcall(enableAntiLag) else pcall(disableAntiLag) end
		saveAceConfig()
	end)
	toggleRowVoid(Visuals, "Nuke Optimiser", nukeOptimiserEnabled, function(on)
		if on then pcall(enableNukeOptimizer) else pcall(disableNukeOptimizer) end
		saveAceConfig()
	end)
	toggleRowVoid(Visuals, "Remove Accessories", removeAccessoriesEnabled, function(on)
		if on then pcall(enableRemoveAccessories) else pcall(disableRemoveAccessories) end
		saveAceConfig()
	end)
	toggleRowVoid(Visuals, "Stretch Rez (FPS)", fpsBoostEnabled, function(on)
		if on then pcall(enableStretchRez) else pcall(disableStretchRez) end
		saveAceConfig()
	end)
	toggleRowVoid(Visuals, "No Cam Collision", noCamCollisionEnabled, function(on)
		if on then pcall(enableNoCamCollision) else pcall(disableNoCamCollision) end
		saveAceConfig()
	end)
	toggleRowVoid(Visuals, "Custom FOV", fovEnabled, function(on)
		if on then pcall(enableCustomFov) else pcall(disableCustomFov) end
		saveAceConfig()
	end)
	inputRowVoid(Visuals, "FOV Value", fovValue, function(v)
		fovValue = v
		if fovEnabled then pcall(enableCustomFov) end
		saveAceConfig()
	end)

	mkSection(Visuals, "ESP")
	toggleRowVoid(Visuals, "Player ESP", espEnabled, function(on)
		espEnabled = on
		if on then pcall(startPlayerESP) else pcall(stopPlayerESP) end
		saveAceConfig()
	end)
	toggleRowVoid(Visuals, "Tracer", showTracerEnabled, function(on)
		showTracerEnabled = on
		BoxedESPOptions.tracer = on
		pcall(refreshBoxedESP)
		saveAceConfig()
	end)

	mkSection(Visuals, "SKY THEME")
	do
		local r = mkRow(Visuals)
		local skyLbl = mkLbl(r, "Off", 0, W - 16)
		skyLbl.TextXAlignment = Enum.TextXAlignment.Left
		local skyIdx = 1
		for i, n in ipairs(SKY_PRESETS_LIST or {"Off"}) do if n == skyTheme then skyIdx = i end end
		local function refreshSky()
			skyLbl.Text = "Theme: " .. (SKY_PRESETS_LIST[skyIdx] or "Off")
		end
		refreshSky()
		local rb = mkRow(Visuals, 22)
		local halfW = (W - 16 - 8) / 2
		local prevBtn = Instance.new("TextButton", rb)
		prevBtn.Size = UDim2.new(0, halfW, 0, 20)
		prevBtn.Position = UDim2.new(0, 0, 0.5, -10)
		prevBtn.BackgroundColor3 = SURF; prevBtn.BorderSizePixel = 0
		prevBtn.Text = "‹ PREV"; prevBtn.TextColor3 = MUTED
		prevBtn.Font = Enum.Font.Gotham; prevBtn.TextSize = 9
		Instance.new("UICorner", prevBtn).CornerRadius = UDim.new(0, 5)
		Instance.new("UIStroke", prevBtn).Color = BORD
		local nextBtn = Instance.new("TextButton", rb)
		nextBtn.Size = UDim2.new(0, halfW, 0, 20)
		nextBtn.Position = UDim2.new(0, halfW + 8, 0.5, -10)
		nextBtn.BackgroundColor3 = SURF; nextBtn.BorderSizePixel = 0
		nextBtn.Text = "NEXT ›"; nextBtn.TextColor3 = MUTED
		nextBtn.Font = Enum.Font.Gotham; nextBtn.TextSize = 9
		Instance.new("UICorner", nextBtn).CornerRadius = UDim.new(0, 5)
		Instance.new("UIStroke", nextBtn).Color = BORD
		prevBtn.MouseButton1Click:Connect(function()
			skyIdx = skyIdx - 1
			if skyIdx < 1 then skyIdx = #SKY_PRESETS_LIST end
			pcall(applyCustomSky, SKY_PRESETS_LIST[skyIdx])
			refreshSky(); saveAceConfig()
		end)
		nextBtn.MouseButton1Click:Connect(function()
			skyIdx = skyIdx + 1
			if skyIdx > #SKY_PRESETS_LIST then skyIdx = 1 end
			pcall(applyCustomSky, SKY_PRESETS_LIST[skyIdx])
			refreshSky(); saveAceConfig()
		end)
	end

	-- =====================================================================
	-- KEYBINDS TAB
	-- =====================================================================
	local Keybinds = pages[4]
	mkSection(Keybinds, "REBIND (click, then press a key)")
	local listeningKey = nil
	local function keybindRowVoid(label, keyId)
		local r = mkRow(Keybinds)
		mkLbl(r, label, 0, 110)
		local b = Instance.new("TextButton", r)
		b.Size = UDim2.new(0, 90, 0, 18)
		b.Position = UDim2.new(1, -90, 0.5, -9)
		b.BackgroundColor3 = SURF
		b.BorderSizePixel = 0
		b.Text = keyToString(speedKeybinds[keyId])
		b.TextColor3 = TEXTC
		b.Font = Enum.Font.Gotham
		b.TextSize = 9
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		local s = Instance.new("UIStroke", b); s.Color = BORD; s.Thickness = 1
		b.MouseButton1Click:Connect(function()
			listeningKey = keyId
			b.Text = "..."
			s.Color = ACC
		end)
		listeningForSpeedKey = listeningForSpeedKey
		speedKeybindButtons[keyId] = b
		return b, s
	end
	local kbBtns = {}
	for _, kv in ipairs({
		{"Speed Toggle", "SpeedToggle"}, {"Lagger Toggle", "LaggerToggle"},
		{"Drop Brainrot", "DropBrainrot"}, {"Aimbot", "Aimbot"},
		{"Anti-Desync Aimbot", "AntiDesyncAimbot"}, {"Auto Left", "AutoLeft"},
		{"Auto Right", "AutoRight"}, {"Instant Reset", "InstantReset"},
		{"Toggle UI", "ToggleUI"},
	}) do
		local b, s = keybindRowVoid(kv[1], kv[2])
		kbBtns[kv[2]] = {b, s}
	end
	do
		local r = mkRow(Keybinds)
		mkLbl(r, "TP Down Key", 0, 110)
		local b = Instance.new("TextButton", r)
		b.Size = UDim2.new(0, 90, 0, 18)
		b.Position = UDim2.new(1, -90, 0.5, -9)
		b.BackgroundColor3 = SURF
		b.BorderSizePixel = 0
		b.Text = keyToString(tpDownKeybind)
		b.TextColor3 = TEXTC
		b.Font = Enum.Font.Gotham
		b.TextSize = 9
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		local s = Instance.new("UIStroke", b); s.Color = BORD; s.Thickness = 1
		b.MouseButton1Click:Connect(function() listeningKey = "__TPDOWN__"; b.Text = "..."; s.Color = ACC end)
		tpDownKeybindButton = b
	end
	UIS.InputBegan:Connect(function(input, gpe)
		if gpe or not listeningKey then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if listeningKey == "__TPDOWN__" then
			tpDownKeybind = input.KeyCode
			if tpDownKeybindButton then tpDownKeybindButton.Text = keyToString(tpDownKeybind) end
		else
			speedKeybinds[listeningKey] = input.KeyCode
			local ref = kbBtns[listeningKey]
			if ref then ref[1].Text = keyToString(input.KeyCode) end
		end
		local ref = kbBtns[listeningKey]
		if ref then ref[2].Color = BORD end
		listeningKey = nil
		saveAceConfig()
	end)
	mkBtn(mkRow(Keybinds, 26), "RESET DEFAULT KEYBINDS", function()
		applyDefaultAceKeybinds()
		for keyId, ref in pairs(kbBtns) do ref[1].Text = keyToString(speedKeybinds[keyId]) end
		if tpDownKeybindButton then tpDownKeybindButton.Text = keyToString(tpDownKeybind) end
		saveAceConfig()
	end)

	-- =====================================================================
	-- STATUS TAB
	-- =====================================================================
	local Status = pages[5]
	mkSection(Status, "INFO")
	local statLbl = mkLbl(mkRow(Status, 40), "MoonDuel v4 · VOID rebuild\nBase: Ace logic core\nPrivate use only", 0, W - 16)
	statLbl.TextWrapped = true
	statLbl.TextYAlignment = Enum.TextYAlignment.Top

	-- global input handler for the ToggleUI keybind
	UIS.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if listeningKey then return end
		if UIS:GetFocusedTextBox() then return end
		if input.KeyCode == speedKeybinds.ToggleUI then
			frame.Visible = not frame.Visible
		end
	end)

	end -- _buildVoidUI
	_buildVoidUI()

	reg(function() pcall(function() gui:Destroy() end) end)
end
