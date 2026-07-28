_G.ScriptEnabled     = true
_G.CasingType        = "Normal"
_G.AutoWriteEnabled  = false
_G.AutoSubmitEnabled = false

local activeConnections = {}

local latestCode    = nil
local autoWriteConn = nil

local pendingQueue = {}
local pendingSeen  = {}
local writeBusy    = false

local collectedCodes = {}
local collectedSeen  = {}
local CODE_SEPARATOR = ""

_G.SubmitAfterCount = 1
_G.SubmitAttempts   = 3

local ScreenGui     = nil
local MainFrame     = nil
local LastCodeLabel = nil

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

local function logStatus(message)
    if MainFrame and MainFrame:FindFirstChild("StatusLabel") then
        MainFrame.StatusLabel.Text = "Status: " .. message
    end
end

local function setLastCode(code)
    latestCode = code
    if LastCodeLabel then
        LastCodeLabel.Text       = "Dernier: " .. code
        LastCodeLabel.TextColor3 = Color3.fromRGB(140, 255, 160)
    end
end

local function isGuiVisible(obj)
    if not obj or not obj.Visible then return false end
    local current = obj.Parent
    while current do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        current = current.Parent
    end
    return true
end

local blacklistedWords = {
    "top", "sec", "min", "fps", "ping", "loading",
    "points", "coins", "cash", "rebirth", "slaps", "money",
    "speed", "level", "lvl", "score"
}

local commonWords = {
    ["the"]=true,["and"]=true,["for"]=true,["you"]=true,["your"]=true,
    ["now"]=true,["new"]=true,["use"]=true,["get"]=true,["out"]=true,
    ["all"]=true,["are"]=true,["can"]=true,["with"]=true,["from"]=true,
    ["this"]=true,["that"]=true,["here"]=true,["more"]=true,["info"]=true,
    ["redeem"]=true,["claim"]=true,["enter"]=true,["reward"]=true,
    ["rewards"]=true,["update"]=true,["join"]=true,["group"]=true,
    ["like"]=true,["follow"]=true,["sub"]=true,["click"]=true,
    ["type"]=true,["copy"]=true,["paste"]=true,["server"]=true,
    ["event"]=true,["live"]=true,["news"]=true,["soon"]=true,
    ["available"]=true,["expired"]=true,["welcome"]=true,["thanks"]=true,
    ["thank"]=true,["player"]=true,["players"]=true,["today"]=true,
    ["time"]=true,["wait"]=true,["xp"]=true,["sammy"]=true,
    ["announcement"]=true,["announcements"]=true,["release"]=true,
    ["released"]=true,["limited"]=true,["special"]=true,["gift"]=true,
    ["pet"]=true,["pets"]=true,["egg"]=true,["luck"]=true,["boost"]=true,
    ["double"]=true,["friend"]=true,["friends"]=true,["chat"]=true,
    ["online"]=true,["offline"]=true,["invite"]=true,["party"]=true,
    ["voice"]=true,["report"]=true,["block"]=true,["mute"]=true,
    ["store"]=true,["shop"]=true,["inventory"]=true,["settings"]=true,
    ["leaderboard"]=true,["lobby"]=true,["menu"]=true,["close"]=true,
    ["open"]=true,["back"]=true,["next"]=true,["play"]=true,
    ["exit"]=true,["drop"]=true,["present"]=true,["win"]=true,
    ["wins"]=true,["winner"]=true,["winners"]=true,["winning"]=true,
    ["winter"]=true,["victory"]=true,["lose"]=true,["loss"]=true,
    ["losses"]=true,["defeat"]=true,["daily"]=true,["spin"]=true,
    ["wheel"]=true,["prize"]=true,["bonus"]=true,["streak"]=true,
    ["rank"]=true,["wave"]=true,["round"]=true,["match"]=true,
    ["versus"]=true,["battle"]=true,["quest"]=true,
}

local function isBlacklisted(lowerText)
    if commonWords[lowerText] then return true end
    for _, word in ipairs(blacklistedWords) do
        if lowerText:find(word, 1, true) then return true end
    end
    return false
end

-- Filtre le bruit HUD : timers, fps, chiffres purs, etc.
local function isHudNoise(text)
    if not text or text == "" then return true end
    local t = text:match("^%s*(.-)%s*$")
    if t:match("^%d+$") then return true end
    if t:match("^%d+:%d+$") then return true end
    if t:match("^%d+%.%d+$") then return true end
    if t:match("^%d+%.?%d*%s*[smhdSMHDfF][pP]?[sS]?$") then return true end
    if #t <= 2 then return true end
    return false
end

-- Supporte tirets et underscores dans les codes (ex: SUMMER-2024, FREE_COINS)
local function looksLikeCode(token)
    if not token then return false end
    if #token < 4 or #token > 25 then return false end
    -- doit commencer et finir par alphanum, tirets/underscores autorisés au milieu
    if not token:match("^%w[%w%-_]*%w$") and not token:match("^%w%w$") then return false end
    if isBlacklisted(token:lower()) then return false end

    local letterCount = 0
    for _ in token:gmatch("%a") do letterCount = letterCount + 1 end
    if letterCount < 3 then return false end
    if token:match("^%d+[smhdSMHD]$") then return false end

    local hasDigit   = token:match("%d") ~= nil
    local letterOnly = token:gsub("[%-_]", "")
    local isAllUpper = (letterOnly == letterOnly:upper()) and letterOnly:match("%a") ~= nil
    -- tout-majuscules sans chiffre : accepté seulement si 5+ chars (évite SHOP, RARE, etc.)
    if not (hasDigit or (isAllUpper and #token >= 5)) then return false end

    return true
end

local function isLoneCode(text)
    if not text then return false end
    text = text:match("^%s*(.-)%s*$")
    if text == "" or text:find("%s") then return false end
    if #text < 3 or #text > 25 then return false end
    -- supporte tirets/underscores
    if not text:match("^[%w][%w%-_]*$") then return false end
    if isBlacklisted(text:lower()) then return false end
    if text:match("^%d+[smhdSMHD]$") then return false end
    -- rejette les nombres purs (bruit HUD)
    if text:match("^%d+$") then return false end

    local letters = 0
    for _ in text:gmatch("%a") do letters = letters + 1 end
    return letters >= 2
end

local function extractCodesFromText(text)
    local found = {}
    if not text then return found end
    -- filtre HUD noise avant tout
    if isHudNoise(text) then return found end

    local trimmed = text:match("^%s*(.-)%s*$")
    trimmed = trimmed:gsub("<[^>]->", "")

    if isLoneCode(trimmed) then
        table.insert(found, trimmed)
        return found
    end

    -- capture les tokens incluant tirets/underscores (ex: SUMMER-2024)
    local seen = {}
    for token in trimmed:gmatch("[%w][%w%-_]*") do
        if not seen[token] and looksLikeCode(token) then
            seen[token] = true
            table.insert(found, token)
        end
    end
    return found
end

local function copyCodeToClipboard(code)
    local formatted = code
    if _G.CasingType == "Upper" then
        formatted = string.upper(code)
    elseif _G.CasingType == "Lower" then
        formatted = string.lower(code)
    end

    local success = false
    if setclipboard then
        pcall(function() setclipboard(formatted) end); success = true
    elseif toclipboard then
        pcall(function() toclipboard(formatted) end); success = true
    elseif set_clipboard then
        pcall(function() set_clipboard(formatted) end); success = true
    elseif Clipboard and Clipboard.set then
        pcall(function() Clipboard.set(formatted) end); success = true
    end

    if success then
        logStatus("Copié: " .. formatted)
    else
        logStatus("Erreur: pas de clipboard! " .. formatted)
    end
    return success
end

local function formatCode(code)
    if _G.CasingType == "Upper" then return string.upper(code) end
    if _G.CasingType == "Lower" then return string.lower(code) end
    return code
end

local _cachedBox = nil

local function _isCodeBox(obj)
    if not obj:IsA("TextBox") then return false end
    if ScreenGui and obj:IsDescendantOf(ScreenGui) then return false end
    local hint = ((obj.PlaceholderText or "") .. " " .. obj.Name):lower()
    -- "here" seul est trop large — on veut vraiment "code" ou "redeem"
    return hint:find("code") ~= nil or hint:find("redeem") ~= nil
end

local function findCodeTextBox()
    if _cachedBox and _cachedBox.Parent and isGuiVisible(_cachedBox) then
        return _cachedBox
    end
    _cachedBox = nil
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if _isCodeBox(obj) and isGuiVisible(obj) then
            _cachedBox = obj
            return obj
        end
    end
    return nil
end

local function fireSignal(sig)
    if not sig then return end
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(sig)) do
                if c.Fire then c:Fire() end
            end
        end
    end)
    if firesignal then pcall(function() firesignal(sig) end) end
end

local function isSubmitButton(obj)
    if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then return false end
    if ScreenGui and obj:IsDescendantOf(ScreenGui) then return false end
    if not isGuiVisible(obj) then return false end
    local hint = (((obj:IsA("TextButton") and obj.Text) or "") .. " " .. obj.Name):lower()
    return hint:find("redeem") ~= nil or hint:find("submit") ~= nil
end

local function fireSubmitButton(nearObj)
    local target = nil
    local container = nearObj and nearObj.Parent or nil
    local levels = 0
    while container and not target and levels < 5 do
        for _, obj in ipairs(container:GetDescendants()) do
            if isSubmitButton(obj) then target = obj; break end
        end
        container = container.Parent
        levels = levels + 1
    end
    if not target then return false end
    fireSignal(target.MouseButton1Click)
    fireSignal(target.Activated)
    return true
end

local _rfRemote = nil
local function getRedemptionRF()
    if _rfRemote and _rfRemote.Parent then return _rfRemote end
    _rfRemote = nil
    local rfFolder = ReplicatedStorage:FindFirstChild("RF")
    if rfFolder then
        local rf = rfFolder:FindFirstChild("RequestRedemption")
        if rf and rf:IsA("RemoteFunction") then _rfRemote = rf; return _rfRemote end
        for _, v in ipairs(rfFolder:GetChildren()) do
            if v.Name == "RequestRedemption" and v:IsA("RemoteFunction") then
                _rfRemote = v; return _rfRemote
            end
        end
    end
    if getinstances then
        for _, v in ipairs(getinstances()) do
            if v.Name == "RequestRedemption" and v:IsA("RemoteFunction") then
                _rfRemote = v; return _rfRemote
            end
        end
    end
    return nil
end

local function redeemViaRF(code)
    local rf = getRedemptionRF()
    if not rf then return false end
    local formatted = formatCode(code)
    local ok, result = pcall(function() return rf:InvokeServer(formatted) end)
    if ok then
        logStatus("RF: " .. formatted .. (result ~= nil and (" → " .. tostring(result)) or ""))
        return true
    end
    return false
end

local function writeAndSubmit(code)
    if redeemViaRF(code) then return true end

    local textBox = findCodeTextBox()
    if not textBox then
        logStatus("En attente d'une code box ouverte...")
        return false
    end

    local formatted = formatCode(code)
    pcall(function() textBox.ClearTextOnFocus = false end)

    if not collectedSeen[formatted] then
        collectedSeen[formatted] = true
        table.insert(collectedCodes, formatted)
    end
    local fullText = table.concat(collectedCodes, CODE_SEPARATOR)
    local target   = math.max(1, tonumber(_G.SubmitAfterCount) or 1)
    local ready    = #collectedCodes >= target

    if ready and _G.AutoSubmitEnabled then
        local count    = #collectedCodes
        local attempts = math.max(1, tonumber(_G.SubmitAttempts) or 3)
        local btn      = false
        for _ = 1, attempts do
            local box = findCodeTextBox()
            if not box then break end
            -- écrit directement sans CaptureFocus (évite le bug clavier)
            pcall(function()
                box.Text           = fullText
                box.CursorPosition = #fullText + 1
            end)
            task.wait(0.05)
            if fireSubmitButton(box) then btn = true; break end
        end
        logStatus("Soumis " .. count .. " (btn=" .. tostring(btn) .. "): " .. fullText)
        table.clear(collectedCodes)
        table.clear(collectedSeen)
    else
        -- écrit directement sans CaptureFocus
        pcall(function()
            textBox.Text           = fullText
            textBox.CursorPosition = #fullText + 1
        end)
        if ready then
            logStatus("Collecté " .. #collectedCodes .. " (submit off): " .. fullText)
            table.clear(collectedCodes)
            table.clear(collectedSeen)
        else
            logStatus("Ajouté: " .. formatted .. " (" .. #collectedCodes .. "/" .. target .. ")")
        end
    end

    return true
end

local function triggerWrite()
    if writeBusy or not _G.AutoWriteEnabled or #pendingQueue == 0 then return end
    local focused = UserInputService:GetFocusedTextBox()
    if focused and ScreenGui and focused:IsDescendantOf(ScreenGui) then return end
    local box = findCodeTextBox()
    if not (box and isGuiVisible(box)) then return end
    writeBusy = true
    task.spawn(function()
        local ok, err = pcall(function()
            while _G.AutoWriteEnabled and #pendingQueue > 0 do
                local b = findCodeTextBox()
                if not (b and isGuiVisible(b)) then break end
                local code = table.remove(pendingQueue, 1)
                pendingSeen[code] = nil
                writeAndSubmit(code)
            end
        end)
        writeBusy = false
        if not ok then warn("[GammaHub] triggerWrite error: " .. tostring(err)) end
    end)
end

local function startAutoWriteLoop()
    if autoWriteConn then return end
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        or LocalPlayer:WaitForChild("PlayerGui", 10)
    local boxConn = playerGui and playerGui.DescendantAdded:Connect(function(obj)
        if _isCodeBox(obj) and isGuiVisible(obj) then
            _cachedBox = obj
            triggerWrite()
        end
    end)
    local boxRemConn = playerGui and playerGui.DescendantRemoving:Connect(function(obj)
        if obj == _cachedBox then _cachedBox = nil end
    end)
    autoWriteConn = { Disconnect = function()
        if boxConn    then boxConn:Disconnect()    end
        if boxRemConn then boxRemConn:Disconnect() end
    end }
    table.insert(activeConnections, autoWriteConn)
end

local function extractStrings(val, out)
    out = out or {}
    local t = type(val)
    if t == "string" then
        table.insert(out, val)
    elseif t == "table" then
        for _, v in pairs(val) do extractStrings(v, out) end
    end
    return out
end

local function processText(text)
    if not text or text == "" then return end
    if isHudNoise(text) then return end

    local codes = extractCodesFromText(text)
    if #codes == 0 then return end

    for _, code in ipairs(codes) do
        copyCodeToClipboard(code)
        setLastCode(code)

        if not pendingSeen[code] then
            pendingSeen[code] = true
            table.insert(pendingQueue, code)
            triggerWrite()
        end

        logStatus("Détecté: " .. code)
    end
end

local function resolveRemote()
    if _G.PhiNotifyRemote then return _G.PhiNotifyRemote end

    local Net
    local deadline = tick() + 30
    while not Net and tick() < deadline do
        pcall(function()
            local Pkgs = ReplicatedStorage:FindFirstChild("Packages")
            if Pkgs then Net = Pkgs:FindFirstChild("Net") end
        end)
        if not Net then task.wait(0.5) end
    end
    if not Net then return nil end

    local getinfo = debug and (debug.getinfo or debug.info)

    if getconnections and getinfo then
        for _, d in ipairs(Net:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                local ok, cs = pcall(getconnections, d.OnClientEvent)
                if ok and cs then
                    for _, c in ipairs(cs) do
                        local f, fn = pcall(function() return c.Function end)
                        if f and type(fn) == "function" then
                            local i, info = pcall(getinfo, fn)
                            if i and tostring(
                                (type(info) == "table" and (info.short_src or info.source)) or info or ""
                            ):find("NotificationController", 1, true) then
                                _G.PhiNotifyRemote = d
                                return d
                            end
                        end
                    end
                end
            end
        end
    end

    for _, d in ipairs(Net:GetDescendants()) do
        if d:IsA("RemoteEvent") and d.Name:match("^RE/%x+$") then
            _G.PhiNotifyRemote = d
            return d
        end
    end

    return nil
end

local function startMonitoring()
    task.spawn(function()
        logStatus("Résolution du remote PhiNotify...")

        local NC = resolveRemote()
        if not NC then
            logStatus("Remote PhiNotify introuvable.")
            return
        end

        local conn = NC.OnClientEvent:Connect(function(...)
            if not _G.ScriptEnabled then return end
            local strings = {}
            for _, v in ipairs({...}) do extractStrings(v, strings) end
            for _, s in ipairs(strings) do processText(s) end
        end)

        table.insert(activeConnections, conn)
        logStatus("Hooké " .. NC.Name .. " — écoute active!")
    end)
end

local function cleanupMonitoring()
    for _, conn in pairs(activeConnections) do
        if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
    end
    table.clear(activeConnections)
    table.clear(collectedCodes)
    table.clear(collectedSeen)
    table.clear(pendingQueue)
    table.clear(pendingSeen)
    writeBusy    = false
    autoWriteConn = nil
    latestCode   = nil
end

local function createUI()
    local oldGui = game:GetService("CoreGui"):FindFirstChild("BrainrotRedeemerGui")
        or LocalPlayer.PlayerGui:FindFirstChild("BrainrotRedeemerGui")
    if oldGui then oldGui:Destroy() end

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name         = "BrainrotRedeemerGui"
    ScreenGui.ResetOnSpawn = false

    if not pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end) then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    MainFrame = Instance.new("Frame")
    MainFrame.Name              = "MainFrame"
    MainFrame.Size              = UDim2.new(0, 330, 0, 330)
    MainFrame.Position          = UDim2.new(0.5, -165, 0.4, -165)
    MainFrame.BackgroundColor3  = Color3.fromRGB(12, 8, 18)
    MainFrame.BorderSizePixel   = 0
    MainFrame.Active            = true
    MainFrame.Draggable         = false
    MainFrame.ClipsDescendants  = true
    MainFrame.Parent            = ScreenGui

    local FULL_HEIGHT = 330
    local MINI_HEIGHT = 40

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = MainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color     = Color3.fromRGB(150, 60, 255)
    mainStroke.Thickness = 2
    mainStroke.Parent    = MainFrame

    local strokeGradient = Instance.new("UIGradient")
    strokeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0,  Color3.fromRGB(255, 0,   128)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(140, 0,   255)),
        ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0,   200, 255)),
        ColorSequenceKeypoint.new(1.0,  Color3.fromRGB(255, 0,   128)),
    })
    strokeGradient.Parent = mainStroke

    local rgbConn = RunService.RenderStepped:Connect(function()
        if strokeGradient and strokeGradient.Parent then
            strokeGradient.Rotation = (tick() * 120) % 360
        end
    end)
    table.insert(activeConnections, rgbConn)

    local mainGradient = Instance.new("UIGradient")
    mainGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 12, 38)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8,  6,  14)),
    })
    mainGradient.Rotation = 45
    mainGradient.Parent   = MainFrame

    -- Drag sans TweenService (mouvement direct, pas de lag)
    do
        local dragging, dragStart, startPos = false, nil, nil
        MainFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging  = true
                dragStart = input.Position
                startPos  = MainFrame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (
                input.UserInputType == Enum.UserInputType.MouseMovement or
                input.UserInputType == Enum.UserInputType.Touch
            ) then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    local AccentBar = Instance.new("Frame")
    AccentBar.Size            = UDim2.new(0, 3, 0, 20)
    AccentBar.Position        = UDim2.new(0, 10, 0, 8)
    AccentBar.BackgroundColor3 = Color3.fromRGB(155, 125, 255)
    AccentBar.BorderSizePixel = 0
    AccentBar.Parent          = MainFrame
    local AccentCorner = Instance.new("UICorner")
    AccentCorner.CornerRadius = UDim.new(1, 0)
    AccentCorner.Parent       = AccentBar

    local HeaderLabel = Instance.new("TextLabel")
    HeaderLabel.Size               = UDim2.new(1, -120, 0, 35)
    HeaderLabel.Position           = UDim2.new(0, 20, 0, 0)
    HeaderLabel.BackgroundTransparency = 1
    HeaderLabel.RichText           = true
    HeaderLabel.Text               = '<b>Gamma<font color="#A65CFF"> Hub</font></b>'
        .. '  <font color="#7C7C8C" size="11">Code Copier</font>'
    HeaderLabel.TextColor3         = Color3.fromRGB(240, 240, 255)
    HeaderLabel.TextSize           = 16
    HeaderLabel.Font               = Enum.Font.GothamBold
    HeaderLabel.TextXAlignment     = Enum.TextXAlignment.Left
    HeaderLabel.Parent             = MainFrame

    local function makeHeaderButton(name, char, xOffset, hoverColor)
        local btn = Instance.new("TextButton")
        btn.Name             = name
        btn.Size             = UDim2.new(0, 28, 0, 28)
        btn.Position         = UDim2.new(1, xOffset, 0, 4)
        btn.BackgroundColor3 = Color3.fromRGB(28, 18, 42)
        btn.AutoButtonColor  = false
        btn.Text             = char
        btn.TextColor3       = Color3.fromRGB(200, 190, 220)
        btn.TextSize         = 14
        btn.Font             = Enum.Font.GothamBold
        btn.Parent           = MainFrame
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
        local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(90, 50, 150); s.Thickness = 1; s.Parent = btn
        btn.MouseEnter:Connect(function()
            btn.BackgroundColor3 = hoverColor
            btn.TextColor3       = Color3.fromRGB(255, 255, 255)
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(28, 18, 42)
            btn.TextColor3       = Color3.fromRGB(200, 190, 220)
        end)
        return btn
    end

    local InstructionsButton = makeHeaderButton("InstructionsButton", "?", -101, Color3.fromRGB(120, 60, 200))
    local MinimizeButton     = makeHeaderButton("MinimizeButton",     "–", -68,  Color3.fromRGB(120, 60, 200))
    local CloseButton        = makeHeaderButton("CloseButton",        "X", -35,  Color3.fromRGB(200, 50, 60))

    CloseButton.MouseButton1Click:Connect(function()
        cleanupMonitoring()
        ScreenGui:Destroy()
    end)

    local minimized = false
    MinimizeButton.MouseButton1Click:Connect(function()
        minimized = not minimized
        local h = minimized and MINI_HEIGHT or FULL_HEIGHT
        MinimizeButton.Text = minimized and "+" or "–"
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 330, 0, h)}):Play()
    end)

    local InstructionsFrame = Instance.new("Frame")
    InstructionsFrame.Size             = UDim2.new(1, -20, 1, -45)
    InstructionsFrame.Position         = UDim2.new(0, 10, 0, 40)
    InstructionsFrame.BackgroundColor3 = Color3.fromRGB(16, 10, 24)
    InstructionsFrame.BorderSizePixel  = 0
    InstructionsFrame.Visible          = false
    InstructionsFrame.ZIndex           = 5
    InstructionsFrame.Parent           = MainFrame
    local infoCorner = Instance.new("UICorner"); infoCorner.CornerRadius = UDim.new(0, 8); infoCorner.Parent = InstructionsFrame
    local infoStroke = Instance.new("UIStroke"); infoStroke.Color = Color3.fromRGB(120, 60, 200); infoStroke.Thickness = 1; infoStroke.Parent = InstructionsFrame

    local InfoText = Instance.new("TextLabel")
    InfoText.Size              = UDim2.new(1, -20, 1, -20)
    InfoText.Position          = UDim2.new(0, 10, 0, 10)
    InfoText.BackgroundTransparency = 1
    InfoText.ZIndex            = 6
    InfoText.RichText          = true
    InfoText.TextWrapped       = true
    InfoText.TextXAlignment    = Enum.TextXAlignment.Left
    InfoText.TextYAlignment    = Enum.TextYAlignment.Top
    InfoText.TextColor3        = Color3.fromRGB(215, 205, 230)
    InfoText.TextSize          = 12
    InfoText.Font              = Enum.Font.Gotham
    InfoText.Text              =
        '<b><font color="#A65CFF">Gamma Hub — Utilisation</font></b>\n\n'
        .. '• <b>Start / Stop</b> : active/désactive la détection.\n'
        .. '• <b>Text Formatting</b> : casse des codes copiés.\n'
        .. '• <b>Auto-Write</b> : écrit les codes dans la code box du jeu.\n'
        .. '• <b>Auto-Submit</b> : appuie sur le bouton Redeem.\n'
        .. '• <b>Submit after (#)</b> : nb de codes avant soumission.\n\n'
        .. '<font color="#A65CFF">Source:</font> PhiNotify (RE/&lt;hex&gt;)\n'
        .. 'Les codes viennent directement du serveur.\n\n'
        .. 'Codes toujours copiés dans le presse-papiers.'
    InfoText.Parent = InstructionsFrame

    InstructionsButton.MouseButton1Click:Connect(function()
        InstructionsFrame.Visible = not InstructionsFrame.Visible
    end)

    local Divider = Instance.new("Frame")
    Divider.Size             = UDim2.new(1, -20, 0, 1)
    Divider.Position         = UDim2.new(0, 10, 0, 35)
    Divider.BackgroundColor3 = Color3.fromRGB(70, 60, 110)
    Divider.BorderSizePixel  = 0
    Divider.Parent           = MainFrame

    -- Monitoring Active
    local ToggleLabel = Instance.new("TextLabel")
    ToggleLabel.Size               = UDim2.new(0, 150, 0, 30)
    ToggleLabel.Position           = UDim2.new(0, 15, 0, 50)
    ToggleLabel.BackgroundTransparency = 1
    ToggleLabel.Text               = "Monitoring Active:"
    ToggleLabel.TextColor3         = Color3.fromRGB(200, 200, 210)
    ToggleLabel.TextSize           = 13
    ToggleLabel.Font               = Enum.Font.GothamSemibold
    ToggleLabel.TextXAlignment     = Enum.TextXAlignment.Left
    ToggleLabel.Parent             = MainFrame

    local StartButton = Instance.new("TextButton")
    StartButton.Name             = "StartButton"
    StartButton.Size             = UDim2.new(0, 55, 0, 28)
    StartButton.Position         = UDim2.new(1, -132, 0, 51)
    StartButton.Text             = "Start"
    StartButton.TextColor3       = Color3.fromRGB(255, 255, 255)
    StartButton.TextSize         = 11
    StartButton.Font             = Enum.Font.GothamBold
    StartButton.Parent           = MainFrame
    local startCorner = Instance.new("UICorner"); startCorner.CornerRadius = UDim.new(0, 6); startCorner.Parent = StartButton

    local StopButton = Instance.new("TextButton")
    StopButton.Name             = "StopButton"
    StopButton.Size             = UDim2.new(0, 55, 0, 28)
    StopButton.Position         = UDim2.new(1, -70, 0, 51)
    StopButton.Text             = "Stop"
    StopButton.TextColor3       = Color3.fromRGB(255, 255, 255)
    StopButton.TextSize         = 11
    StopButton.Font             = Enum.Font.GothamBold
    StopButton.Parent           = MainFrame
    local stopCorner = Instance.new("UICorner"); stopCorner.CornerRadius = UDim.new(0, 6); stopCorner.Parent = StopButton

    local function renderStartStop()
        if _G.ScriptEnabled then
            StartButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            StopButton.BackgroundColor3  = Color3.fromRGB(35, 35, 45)
        else
            StartButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            StopButton.BackgroundColor3  = Color3.fromRGB(231, 76, 60)
        end
    end
    renderStartStop()

    StartButton.MouseButton1Click:Connect(function()
        _G.ScriptEnabled = true; renderStartStop(); logStatus("Détection démarrée.")
    end)
    StopButton.MouseButton1Click:Connect(function()
        _G.ScriptEnabled = false; renderStartStop(); logStatus("Détection arrêtée.")
    end)

    -- Text Formatting
    local CaseLabel = Instance.new("TextLabel")
    CaseLabel.Size               = UDim2.new(0, 150, 0, 30)
    CaseLabel.Position           = UDim2.new(0, 15, 0, 95)
    CaseLabel.BackgroundTransparency = 1
    CaseLabel.Text               = "Text Formatting:"
    CaseLabel.TextColor3         = Color3.fromRGB(200, 200, 210)
    CaseLabel.TextSize           = 13
    CaseLabel.Font               = Enum.Font.GothamSemibold
    CaseLabel.TextXAlignment     = Enum.TextXAlignment.Left
    CaseLabel.Parent             = MainFrame

    local ButtonContainer = Instance.new("Frame")
    ButtonContainer.Size               = UDim2.new(1, -30, 0, 32)
    ButtonContainer.Position           = UDim2.new(0, 15, 0, 125)
    ButtonContainer.BackgroundTransparency = 1
    ButtonContainer.Parent             = MainFrame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder     = Enum.SortOrder.LayoutOrder
    layout.Padding       = UDim.new(0, 8)
    layout.Parent        = ButtonContainer

    local optButtons = {}
    local function updateCasingUI(selectedType)
        _G.CasingType = selectedType
        for casing, btn in pairs(optButtons) do
            if casing == selectedType then
                TweenService:Create(btn, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(114, 137, 218),
                    TextColor3       = Color3.fromRGB(255, 255, 255),
                }):Play()
            else
                TweenService:Create(btn, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(35, 35, 45),
                    TextColor3       = Color3.fromRGB(160, 160, 170),
                }):Play()
            end
        end
        logStatus("Formatage: " .. selectedType)
    end

    for _, opt in ipairs({
        {Type="Normal", Label="Normal"},
        {Type="Upper",  Label="UPPER"},
        {Type="Lower",  Label="lower"},
    }) do
        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, 94, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        btn.Text             = opt.Label
        btn.TextColor3       = Color3.fromRGB(160, 160, 170)
        btn.TextSize         = 11
        btn.Font             = Enum.Font.GothamBold
        btn.Parent           = ButtonContainer
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = btn
        optButtons[opt.Type] = btn
        btn.MouseButton1Click:Connect(function() updateCasingUI(opt.Type) end)
    end
    updateCasingUI("Normal")

    -- Toggle helper
    local function createToggleRow(labelText, yPos, startOn, onChanged)
        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(0, 200, 0, 30)
        lbl.Position           = UDim2.new(0, 15, 0, yPos)
        lbl.BackgroundTransparency = 1
        lbl.Text               = labelText
        lbl.TextColor3         = Color3.fromRGB(200, 200, 210)
        lbl.TextSize           = 13
        lbl.Font               = Enum.Font.GothamSemibold
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Parent             = MainFrame

        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, 80, 0, 28)
        btn.Position         = UDim2.new(1, -95, 0, yPos + 1)
        btn.TextColor3       = Color3.fromRGB(255, 255, 255)
        btn.TextSize         = 11
        btn.Font             = Enum.Font.GothamBold
        btn.Parent           = MainFrame
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = btn

        local state = startOn
        local function render()
            if state then
                btn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
                btn.Text             = "ON"
            else
                btn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
                btn.Text             = "OFF"
            end
        end
        render()
        btn.MouseButton1Click:Connect(function()
            state = not state; render(); onChanged(state)
        end)
        return btn
    end

    createToggleRow("Auto-Write:", 165, _G.AutoWriteEnabled, function(on)
        _G.AutoWriteEnabled = on
        if on then
            logStatus("Auto-Write actif (ouvre la code box).")
        else
            table.clear(collectedCodes); table.clear(collectedSeen)
            table.clear(pendingQueue);   table.clear(pendingSeen)
            logStatus("Auto-Write désactivé.")
        end
    end)

    createToggleRow("Auto-Submit (Enter):", 200, _G.AutoSubmitEnabled, function(on)
        _G.AutoSubmitEnabled = on
        logStatus(on and "Auto-Submit actif." or "Auto-Submit désactivé.")
    end)

    -- Submit after (#)
    local CountLabel = Instance.new("TextLabel")
    CountLabel.Size               = UDim2.new(0, 200, 0, 30)
    CountLabel.Position           = UDim2.new(0, 15, 0, 235)
    CountLabel.BackgroundTransparency = 1
    CountLabel.Text               = "Submit after (#):"
    CountLabel.TextColor3         = Color3.fromRGB(200, 200, 210)
    CountLabel.TextSize           = 13
    CountLabel.Font               = Enum.Font.GothamSemibold
    CountLabel.TextXAlignment     = Enum.TextXAlignment.Left
    CountLabel.Parent             = MainFrame

    local CountBox = Instance.new("TextBox")
    CountBox.Name             = "CountBox"
    CountBox.Size             = UDim2.new(0, 80, 0, 28)
    CountBox.Position         = UDim2.new(1, -95, 0, 236)
    CountBox.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    CountBox.Text             = tostring(_G.SubmitAfterCount)
    CountBox.PlaceholderText  = "1"
    CountBox.TextColor3       = Color3.fromRGB(255, 255, 255)
    CountBox.TextSize         = 12
    CountBox.Font             = Enum.Font.GothamBold
    CountBox.ClearTextOnFocus = false
    CountBox.Parent           = MainFrame
    local countCorner = Instance.new("UICorner"); countCorner.CornerRadius = UDim.new(0, 6); countCorner.Parent = CountBox

    CountBox.FocusLost:Connect(function()
        local n = math.floor(tonumber(CountBox.Text) or 0)
        if n < 1 then n = 1 end
        _G.SubmitAfterCount = n
        CountBox.Text = tostring(n)
        logStatus("Soumettra après " .. n .. " code(s). (" .. #collectedCodes .. " collectés)")
    end)

    -- Dernier code détecté
    LastCodeLabel = Instance.new("TextLabel")
    LastCodeLabel.Name               = "LastCodeLabel"
    LastCodeLabel.Size               = UDim2.new(1, -30, 0, 26)
    LastCodeLabel.Position           = UDim2.new(0, 15, 0, 268)
    LastCodeLabel.BackgroundColor3   = Color3.fromRGB(10, 18, 10)
    LastCodeLabel.Text               = "Dernier: —"
    LastCodeLabel.TextColor3         = Color3.fromRGB(100, 120, 100)
    LastCodeLabel.TextSize           = 11
    LastCodeLabel.Font               = Enum.Font.GothamBold
    LastCodeLabel.TextXAlignment     = Enum.TextXAlignment.Center
    LastCodeLabel.TextTruncate       = Enum.TextTruncate.AtEnd
    LastCodeLabel.Parent             = MainFrame
    local lastCorner = Instance.new("UICorner"); lastCorner.CornerRadius = UDim.new(0, 6); lastCorner.Parent = LastCodeLabel
    local lastStroke = Instance.new("UIStroke"); lastStroke.Color = Color3.fromRGB(30, 60, 30); lastStroke.Thickness = 1; lastStroke.Parent = LastCodeLabel

    -- Status
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name               = "StatusLabel"
    StatusLabel.Size               = UDim2.new(1, -30, 0, 28)
    StatusLabel.Position           = UDim2.new(0, 15, 0, 298)
    StatusLabel.BackgroundColor3   = Color3.fromRGB(12, 12, 15)
    StatusLabel.Text               = "Status: Chargé. En attente..."
    StatusLabel.TextColor3         = Color3.fromRGB(170, 170, 185)
    StatusLabel.TextSize           = 11
    StatusLabel.Font               = Enum.Font.Gotham
    StatusLabel.TextXAlignment     = Enum.TextXAlignment.Center
    StatusLabel.TextTruncate       = Enum.TextTruncate.AtEnd
    StatusLabel.Parent             = MainFrame
    local statusCorner = Instance.new("UICorner"); statusCorner.CornerRadius = UDim.new(0, 6); statusCorner.Parent = StatusLabel
    local statusStroke = Instance.new("UIStroke"); statusStroke.Color = Color3.fromRGB(30, 30, 38); statusStroke.Thickness = 1; statusStroke.Parent = StatusLabel
end

local function init()
    pcall(cleanupMonitoring)
    createUI()
    startMonitoring()
    startAutoWriteLoop()
    logStatus("Initialisation réussie!")
end

init()
