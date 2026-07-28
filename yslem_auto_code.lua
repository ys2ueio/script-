local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP                = Players.LocalPlayer
local PlayerGui         = LP:WaitForChild("PlayerGui")

-- ===================================================================
-- CONFIG
-- ===================================================================
local CFG_PATH = "yslem_autocode_cfg.json"
local cfg = {
    autoCode     = true,
    redeemDelay  = 0,       -- secondes d'attente après dernier texte avant auto-redeem
    captureCount = 0,       -- 0 = mode timer, N = collecter exactement N parties
    keywords     = { "code is","use code","new code","code:","codes:","promo","redeem","","","" },
    replaceRules = {
        {kw="admin war", rep="jandel"},
        {kw="",rep=""},{kw="",rep=""},{kw="",rep=""},
        {kw="",rep=""},{kw="",rep=""},{kw="",rep=""},
        {kw="",rep=""},{kw="",rep=""},{kw="",rep=""},
    },
    posX      = 16,
    posY      = 80,
    minimized = false,
    activeTab = 1,
}

local function saveConfig()
    if not writefile then return end
    pcall(writefile, CFG_PATH, HttpService:JSONEncode(cfg))
end
local function loadConfig()
    if not (readfile and isfile and isfile(CFG_PATH)) then return end
    local ok, dec = pcall(function() return HttpService:JSONDecode(readfile(CFG_PATH)) end)
    if ok and type(dec) == "table" then
        for k, v in pairs(dec) do cfg[k] = v end
    end
end
loadConfig()

-- ===================================================================
-- COLOUR / STYLE
-- ===================================================================
local C_BG    = Color3.fromRGB(8, 8, 8)
local C_ON    = Color3.fromRGB(45, 45, 45)
local C_OFF   = Color3.fromRGB(8, 8, 8)
local C_ROW   = Color3.fromRGB(22, 22, 22)
local C_WHITE = Color3.fromRGB(240, 240, 240)
local C_DIM   = Color3.fromRGB(120, 120, 120)
local G1      = Color3.fromRGB(200, 200, 200)
local G2      = Color3.fromRGB(90, 90, 90)
local G3      = Color3.fromRGB(25, 25, 25)

local _livingGradients = {}
local _livingStrokes   = {}

local function addCorner(inst, r)
    local c = Instance.new("UICorner", inst)
    c.CornerRadius = UDim.new(0, r or 8)
    return c
end

local function addLivingTextGradient(lbl)
    local g = Instance.new("UIGradient", lbl)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    G1),
        ColorSequenceKeypoint.new(0.25, G2),
        ColorSequenceKeypoint.new(0.5,  G1),
        ColorSequenceKeypoint.new(0.75, G2),
        ColorSequenceKeypoint.new(1,    G1),
    })
    g.Rotation = 0
    table.insert(_livingGradients, g)
    return g
end

local function addLivingStroke(parent, thickness)
    local s = Instance.new("UIStroke", parent)
    s.Thickness = thickness or 1.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Color = G2
    local g = Instance.new("UIGradient", s)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    G3),
        ColorSequenceKeypoint.new(0.25, G2),
        ColorSequenceKeypoint.new(0.5,  G3),
        ColorSequenceKeypoint.new(0.75, G2),
        ColorSequenceKeypoint.new(1,    G3),
    })
    table.insert(_livingStrokes, g)
    return s, g
end

RunService.RenderStepped:Connect(function()
    for _, g in ipairs(_livingGradients) do if g and g.Parent then g.Rotation = (g.Rotation + 0.6) % 360 end end
    for _, g in ipairs(_livingStrokes)   do if g and g.Parent then g.Rotation = (g.Rotation + 0.6) % 360 end end
end)

-- ===================================================================
-- SCANNER STATE
-- ===================================================================
local MAX_KW       = 10
local autoCode     = cfg.autoCode == true
local captureCount = cfg.captureCount or 0
local redeemDelay  = 0

local filterKeywords = {}
local replaceRules   = {}
for i = 1, MAX_KW do
    filterKeywords[i] = (type(cfg.keywords) == "table" and cfg.keywords[i]) or ""
end
for i = 1, MAX_KW do
    local s = type(cfg.replaceRules) == "table" and cfg.replaceRules[i]
    replaceRules[i] = { kw = (s and s.kw) or "", rep = (s and s.rep) or "" }
end

local collecting      = false
local collectBuf      = {}
local collectRemain   = 0
local forceScanActive = false
local lastCode        = ""
local _dedupText      = ""
local _dedupTime      = 0

-- Timer-based redeem
local _pendingCode  = ""
local _flushToken   = 0
local _lastRedeem   = { code = "", time = 0 }

local _pillLbl    = nil
local _codeBarLbl = nil
local _focused    = nil

-- Status log
local _statusLog      = {}
local _lastLogEntry   = ""
local _statusScroll = nil

local function logStatus(msg)
    if msg == _lastLogEntry then return end
    _lastLogEntry = msg
    local t = os.date and os.date("%H:%M:%S") or "??"
    local entry = "[" .. t .. "] " .. msg
    table.insert(_statusLog, entry)
    if _statusScroll then
        local lbl = Instance.new("TextLabel")
        lbl.Size                   = UDim2.new(1, -8, 0, 0)
        lbl.AutomaticSize          = Enum.AutomaticSize.Y
        lbl.BackgroundTransparency = 1
        lbl.Font                   = Enum.Font.Code
        lbl.TextSize               = 9
        lbl.TextColor3             = C_DIM
        lbl.TextXAlignment         = Enum.TextXAlignment.Left
        lbl.TextWrapped            = true
        lbl.Text                   = entry
        lbl.Parent                 = _statusScroll
        task.defer(function()
            _statusScroll.CanvasPosition = Vector2.new(0, math.huge)
        end)
    end
end

local function setScanState(txt)
    if _pillLbl then _pillLbl.Text = txt end
end

local function setLastCode(code)
    lastCode = code
    if _codeBarLbl then
        _codeBarLbl.Text       = code ~= "" and code or "No code yet"
        _codeBarLbl.TextColor3 = code ~= "" and C_WHITE or C_DIM
    end
end

-- ===================================================================
-- GUI ROOT
-- ===================================================================
local gui = Instance.new("ScreenGui")
gui.Name           = "YslemAutoCode"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder   = 999
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui) end
    if protectgui then protectgui(gui) end
end)
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
    gui.Parent = (gethui and gethui()) or PlayerGui
end

local function isOwnedByUs(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur == gui then return true end
        cur = cur.Parent
    end
    return false
end

-- ===================================================================
-- DETECTION HELPERS
-- ===================================================================
local blacklistedWords = {
    "join","left","connected","disconnected","welcome","server","update",
    "version","patch","event","roblox","game","studio","error","warning",
    "player","loading","please","wait","click","press","open","close",
}
local commonWords = {
    "the","and","for","are","but","not","you","all","can","had","her",
    "was","one","our","out","day","get","has","him","his","how","man",
    "new","now","old","see","two","way","who","boy","did","its","let",
    "put","say","she","too","use",
}

local function isBlacklisted(text)
    local low = text:lower()
    for _, w in ipairs(blacklistedWords) do
        if low:find(w, 1, true) then return true end
    end
    return false
end

local function looksLikeCode(text)
    if not text or #text < 3 or #text > 50 then return false end
    if isBlacklisted(text) then return false end
    local low = text:lower()
    for _, w in ipairs(commonWords) do
        if low == w then return false end
    end
    if not text:match("%a") then return false end
    if text == low and not text:match("%d") then return false end
    local wordCount = 0
    for _ in text:gmatch("%S+") do wordCount = wordCount + 1 end
    return wordCount <= 4
end

local function isLoneCode(text)
    if not text then return false end
    if not text:match("^[%w%-_]+$") then return false end
    if #text < 3 or #text > 50 then return false end
    return text == text:upper() or text:match("%d") ~= nil
end

local function extractCodesFromText(text)
    if not text or text == "" then return nil end
    if isLoneCode(text) and looksLikeCode(text) then return text end
    for token in text:gmatch("[%w%-_]+") do
        if isLoneCode(token) and looksLikeCode(token) then return token end
    end
    return nil
end

local function extractCode(txt)
    if not txt then return nil end
    for token in txt:gmatch("[A-Z][A-Z0-9%-_]+") do
        if #token >= 4 then
            local letters = 0
            for _ in token:gmatch("%a") do letters = letters + 1 end
            if letters >= 3 then return token end
        end
    end
    return nil
end

local function isHudNoise(txt)
    if not txt or txt == "" then return true end
    if txt:match("^%d+$") then return true end
    if txt:match("^%d+:%d+$") then return true end
    if txt:match("^%d+%.%d+$") then return true end
    if txt:match("^[%+%-]?%d") and #txt < 8 then return true end
    if txt:match("^%d+[kKmMbBgG]?$") then return true end
    if txt:match("^x%d") then return true end
    return false
end

local _cachedBox = nil

local function _isCodeBox(obj)
    if not obj:IsA("TextBox") then return false end
    if isOwnedByUs(obj) then return false end
    local nameL = obj.Name:lower()
    local phL   = (obj.PlaceholderText or ""):lower()
    for _, h in ipairs({"code","redeem","promo","coupon","enter","input"}) do
        if nameL:find(h, 1, true) or phL:find(h, 1, true) then return true end
    end
    return false
end

local function findCodeTextBox()
    if _cachedBox and _cachedBox.Parent then return _cachedBox end
    _cachedBox = nil
    local function search(root)
        for _, d in ipairs(root:GetDescendants()) do
            if _isCodeBox(d) then _cachedBox = d; return d end
        end
        return nil
    end
    return search(PlayerGui) or search(game:GetService("CoreGui"))
end

local function fireSignalHelper(btn)
    pcall(function() if firesignal then firesignal(btn.MouseButton1Click) end end)
    pcall(function() if firesignal then firesignal(btn.Activated) end end)
    pcall(function() if mouse1click then mouse1click(btn) end end)
    pcall(function() if click then click(btn) end end)
end

local function isSubmitButton(obj)
    if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then return false end
    local n = obj.Name:lower()
    local t = (obj:IsA("TextButton") and obj.Text:lower()) or ""
    for _, h in ipairs({"submit","confirm","redeem","enter","ok","send","apply"}) do
        if n:find(h,1,true) or t:find(h,1,true) then return true end
    end
    return false
end

local function fireSubmitButton(root)
    if not root then return false end
    for _, d in ipairs(root:GetDescendants()) do
        if isSubmitButton(d) then fireSignalHelper(d); return true end
    end
    return false
end

-- ===================================================================
-- REDEEM LOGIC
-- ===================================================================
local function redeemCode(code)
    -- 0. RemoteFunction ciblé : MerchShop RedeemCode
    pcall(function()
        local rfFolder = game:GetService("ReplicatedStorage").Packages.Net.RF
        local rf = rfFolder:FindFirstChild("MerchShop/RedeemCode")
                or (rfFolder:FindFirstChild("MerchShop") and rfFolder.MerchShop:FindFirstChild("RedeemCode"))
        if rf then
            logStatus("RF → " .. code)
            rf:InvokeServer(code)
        else
            logStatus("RF introuvable")
        end
    end)

    -- 1. Sources Hub Redeemer (si ouvert)
    pcall(function()
        for _, g in ipairs(PlayerGui:GetChildren()) do
            for _, obj in ipairs(g:GetDescendants()) do
                if obj:IsA("TextBox") and (obj.PlaceholderText or ""):lower():find("captured", 1, true) then
                    obj.Text = code
                    local scope = obj.Parent
                    for _ = 1, 6 do
                        for _, btn in ipairs(scope:GetChildren()) do
                            local t = (btn:IsA("TextButton") and btn.Text:lower()) or ""
                            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and t:find("redeem",1,true) then
                                fireSignalHelper(btn); return
                            end
                        end
                        if scope.Parent then scope = scope.Parent else break end
                    end
                    return
                end
            end
        end
    end)

    -- 2. TextBox "Code Here..." — visible ou caché
    local box = findCodeTextBox()
    if box then
        box.Text = code
        task.wait(0.05)
        pcall(function() if firesignal then firesignal(box.FocusLost, true) end end)
        local scope = box.Parent
        for _ = 1, 8 do
            if fireSubmitButton(scope) then break end
            if scope and scope.Parent then scope = scope.Parent else break end
        end
        return
    end

    -- 3. Structure spécifique (SAB / VON)
    pcall(function()
        local Codes = PlayerGui:WaitForChild("Codes", 3).Codes
        local tb    = Codes.CodeRedeem.TextBox
        tb.Text     = code
        pcall(function() if firesignal then firesignal(tb.FocusLost, true) end end)
        local btn = Codes.Confirm:FindFirstChildWhichIsA("TextButton") or Codes.Confirm
        if btn then fireSignalHelper(btn) end
    end)
end

local function appendToBox(text)
    if not text or text == "" then return end
    if not _focused or not _focused.Parent then
        redeemCode(text)
        return
    end
    local cur = _focused.Text or ""
    _focused.Text = cur == "" and text or (cur .. " " .. text)
    setLastCode(text)
end

local function matchesKeyword(text)
    if not text or text == "" then return false end
    local hasAny = false
    for _, kw in ipairs(filterKeywords) do
        if kw ~= "" then hasAny = true; break end
    end
    if not hasAny then return true end
    local lower = text:lower()
    for _, kw in ipairs(filterKeywords) do
        if kw ~= "" and lower:find(kw:lower(), 1, true) then return true end
    end
    return false
end

local function applyReplace(text)
    if not text or text == "" then return nil end
    local lower = text:lower()
    for _, rule in ipairs(replaceRules) do
        if rule.kw ~= "" and lower:find(rule.kw:lower(), 1, true) then
            return rule.rep
        end
    end
    return nil
end

-- Timer flush: token pattern to cancel previous timer without task.cancel
local function flushPending(token)
    if token ~= _flushToken then return end
    local code = _pendingCode
    _pendingCode = ""
    if code == "" then return end
    logStatus("✓ " .. code)
    setLastCode(code)
    setScanState("SCANNING")
    _lastRedeem.code = code
    _lastRedeem.time = tick()
    if autoCode then appendToBox(code) end
end

local function addPending(code)
    _pendingCode = code
    _flushToken  = _flushToken + 1
    local token  = _flushToken
    if redeemDelay <= 0 then
        logStatus("→ " .. code)
        flushPending(token)
    else
        setScanState("ATTENTE " .. redeemDelay .. "s")
        logStatus(redeemDelay .. "s → " .. code)
        task.delay(redeemDelay, function() flushPending(token) end)
    end
end

-- ===================================================================
-- DISPATCH
-- ===================================================================
local function dispatch(text, trusted)
    if not text or text == "" then return end
    if not trusted and isHudNoise(text) then return end

    local now = tick()
    if text == _dedupText and (now - _dedupTime) < 0.4 then return end
    _dedupText = text
    _dedupTime = now

    -- FORCE SCAN
    if forceScanActive and collecting then
        table.insert(collectBuf, text)
        collectRemain = collectRemain - 1
        setScanState("COLLECTING " .. collectRemain)
        if collectRemain <= 0 then
            local result = table.concat(collectBuf)
            logStatus("Force → " .. result)
            setLastCode(result)
            appendToBox(result)
            collecting = false; collectBuf = {}; collectRemain = 0; forceScanActive = false
            setScanState("SCANNING")
        end
        return
    end

    -- captureCount > 0: mode N parties (comme auto_code_typer)
    if captureCount > 0 then
        if collecting then
            -- Un nouveau keyword reset la collecte
            if matchesKeyword(text) then
                collectBuf = {}; collectRemain = captureCount
                logStatus("Keyword reset → collect " .. captureCount)
                setScanState("COLLECTING " .. captureCount)
                return
            end
            local rep = applyReplace(text)
            local part = rep ~= nil and rep or text
            table.insert(collectBuf, part)
            collectRemain = collectRemain - 1
            setScanState("COLLECTING " .. collectRemain)
            logStatus("Part " .. (#collectBuf) .. ": " .. part)
            if collectRemain <= 0 then
                local result = table.concat(collectBuf)
                if result ~= "" then
                    logStatus("Code → " .. result)
                    addPending(result)
                end
                collecting = false; collectBuf = {}; collectRemain = 0
            end
        else
            if matchesKeyword(text) then
                logStatus("Keyword: " .. text)
                collecting = true; collectBuf = {}; collectRemain = captureCount
                setScanState("COLLECTING " .. captureCount)
            end
        end
        return
    end

    -- captureCount = 0: mode timer (hybrid: keyword→prochain texte + détection directe)
    local hasKeywords = false
    for _, kw in ipairs(filterKeywords) do if kw ~= "" then hasKeywords = true; break end end

    local result

    if collecting then
        -- Un keyword vient d'être détecté: ce texte EST le code
        local rep = applyReplace(text)
        result = rep ~= nil and rep or text
        collecting = false
        setScanState("SCANNING")
    elseif hasKeywords and matchesKeyword(text) then
        -- Keyword détecté: attendre le prochain texte comme code
        collecting = true
        setScanState("KEYWORD")
        return
    else
        local rep = applyReplace(text)
        if rep ~= nil then
            result = rep
        elseif trusted then
            -- Source sûre: token seul uniquement (pas "Code is", pas phrases)
            result = isLoneCode(text) and text or extractCode(text)
        else
            result = extractCode(text) or extractCodesFromText(text)
        end
    end

    if result and result ~= "" then
        -- Anti-boucle: bloquer le même code 30s après redeem (MT hook → redeemCode feedback)
        if result:lower() == _lastRedeem.code:lower() and (tick() - _lastRedeem.time) < 30 then return end
        setLastCode(result)
        addPending(result)
    end
end

-- ===================================================================
-- STATUS PILL
-- ===================================================================
local pillWidget = Instance.new("Frame", gui)
pillWidget.Name                   = "ScanPill"
pillWidget.Size                   = UDim2.new(0, 200, 0, 36)
pillWidget.Position               = UDim2.new(0.5, -100, 0, 35)
pillWidget.BackgroundTransparency = 1
pillWidget.Active                 = true

local pill = Instance.new("Frame", pillWidget)
pill.Size                   = UDim2.new(1, 0, 1, 0)
pill.BackgroundColor3       = C_BG
pill.BackgroundTransparency = 0.1
pill.BorderSizePixel        = 0
pill.ClipsDescendants       = true
addCorner(pill, 18)
addLivingStroke(pill, 1.5)

_pillLbl = Instance.new("TextLabel", pill)
_pillLbl.Size                   = UDim2.new(1, -16, 1, 0)
_pillLbl.Position               = UDim2.new(0, 8, 0, 0)
_pillLbl.BackgroundTransparency = 1
_pillLbl.Text                   = "SCANNING"
_pillLbl.TextColor3             = C_WHITE
_pillLbl.Font                   = Enum.Font.GothamBlack
_pillLbl.TextSize               = 13
_pillLbl.TextXAlignment         = Enum.TextXAlignment.Center
_pillLbl.ZIndex                 = 5
addLivingTextGradient(_pillLbl)

local pillByLbl = Instance.new("TextLabel", pillWidget)
pillByLbl.Size                   = UDim2.new(1, 0, 0, 10)
pillByLbl.Position               = UDim2.new(0, 0, 1, 3)
pillByLbl.BackgroundTransparency = 1
pillByLbl.Text                   = "by Yslem"
pillByLbl.TextColor3             = C_DIM
pillByLbl.Font                   = Enum.Font.Gotham
pillByLbl.TextSize               = 8
pillByLbl.TextXAlignment         = Enum.TextXAlignment.Center
pillByLbl.ZIndex                 = 5

-- ===================================================================
-- MAIN PANEL
-- ===================================================================
local PANEL_W   = 240
local TITLE_H   = 28
local TAB_H     = 26
local CONTENT_H = 180
local FULL_H    = TITLE_H + TAB_H + CONTENT_H
local MINI_H    = TITLE_H

local panel = Instance.new("Frame", gui)
panel.Size                   = UDim2.new(0, PANEL_W, 0, FULL_H)
panel.Position               = UDim2.new(0, cfg.posX, 0, cfg.posY)
panel.BackgroundColor3       = C_BG
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel        = 0
panel.Active                 = true
panel.ZIndex                 = 10
addCorner(panel, 14)
addLivingStroke(panel, 1.5)

-- Background image (chargement async depuis workspace si disponible)
local _bgImg = Instance.new("ImageLabel", panel)
_bgImg.Size                   = UDim2.new(1, 0, 1, 0)
_bgImg.Position               = UDim2.new(0, 0, 0, 0)
_bgImg.BackgroundTransparency = 1
_bgImg.Image                  = ""
_bgImg.ScaleType              = Enum.ScaleType.Crop
_bgImg.ZIndex                 = 9
addCorner(_bgImg, 14)
task.spawn(function()
    local fname = "yslem_bg_v2.png"
    if not (getcustomasset and isfile) then return end
    if isfile(fname) then
        local rid = getcustomasset(fname)
        if rid and rid ~= "" then _bgImg.Image = rid end
    end
end)

-- Drag
do
    local dragging, dragStart, startPos = false, nil, nil
    panel.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or
           inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = panel.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    cfg.posX = panel.Position.X.Offset
                    cfg.posY = panel.Position.Y.Offset
                    saveConfig()
                end
            end)
        end
    end)
    panel.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or
                         inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- Minimize button
local minimized = cfg.minimized == true
local minBtn    = Instance.new("TextButton", panel)
minBtn.Size                   = UDim2.new(0, 20, 0, 20)
minBtn.Position               = UDim2.new(1, -24, 0, 4)
minBtn.BackgroundTransparency = 1
minBtn.Text                   = "-"
minBtn.TextColor3             = C_WHITE
minBtn.Font                   = Enum.Font.GothamBlack
minBtn.TextSize               = 16
minBtn.ZIndex                 = 15
addLivingTextGradient(minBtn)

-- Title
local titleLbl = Instance.new("TextLabel", panel)
titleLbl.Size                   = UDim2.new(1, -40, 0, TITLE_H)
titleLbl.Position               = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = "YSLEM AUTO CODE"
titleLbl.TextColor3             = C_WHITE
titleLbl.Font                   = Enum.Font.GothamBlack
titleLbl.TextSize               = 13
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.ZIndex                 = 15
addLivingTextGradient(titleLbl)

local byLbl = Instance.new("TextLabel", panel)
byLbl.Size                   = UDim2.new(0, 64, 0, TITLE_H)
byLbl.Position               = UDim2.new(1, -88, 0, 0)
byLbl.BackgroundTransparency = 1
byLbl.Text                   = "by Yslem"
byLbl.TextColor3             = C_DIM
byLbl.Font                   = Enum.Font.Gotham
byLbl.TextSize               = 9
byLbl.TextXAlignment         = Enum.TextXAlignment.Right
byLbl.ZIndex                 = 15

-- ===================================================================
-- TAB BAR
-- ===================================================================
local tabBar = Instance.new("Frame", panel)
tabBar.Size                   = UDim2.new(1, -16, 0, TAB_H)
tabBar.Position               = UDim2.new(0, 8, 0, TITLE_H)
tabBar.BackgroundTransparency = 1
tabBar.ZIndex                 = 12

local tabBarLayout = Instance.new("UIListLayout", tabBar)
tabBarLayout.FillDirection       = Enum.FillDirection.Horizontal
tabBarLayout.Padding             = UDim.new(0, 4)
tabBarLayout.SortOrder           = Enum.SortOrder.LayoutOrder
tabBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabBarLayout.VerticalAlignment   = Enum.VerticalAlignment.Center

local currentTab = math.max(1, math.min(4, cfg.activeTab or 1))

local function makeTabBtn(label, order)
    local btn = Instance.new("TextButton", tabBar)
    btn.Size             = UDim2.new(0, 50, 1, -4)
    btn.LayoutOrder      = order
    btn.BackgroundColor3 = C_ROW
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Text             = label
    btn.TextColor3       = C_DIM
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 10
    btn.ZIndex           = 13
    addCorner(btn, 6)
    addLivingTextGradient(btn)
    return btn
end

local tabMainBtn   = makeTabBtn("Main",   1)
local tabTrigBtn   = makeTabBtn("Trig",   2)
local tabRepBtn    = makeTabBtn("Rep",    3)
local tabStatusBtn = makeTabBtn("Status", 4)

-- ===================================================================
-- CONTENT FRAME
-- ===================================================================
local contentFrame = Instance.new("Frame", panel)
contentFrame.Size                   = UDim2.new(1, 0, 1, -(TITLE_H + TAB_H))
contentFrame.Position               = UDim2.new(0, 0, 0, TITLE_H + TAB_H)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants       = true
contentFrame.ZIndex                 = 11

-- ===================================================================
-- PAGE 1: MAIN
-- ===================================================================
local page1 = Instance.new("Frame", contentFrame)
page1.Size                   = UDim2.new(1, 0, 1, 0)
page1.BackgroundTransparency = 1
page1.ZIndex                 = 11

-- Code display bar
local codeBar = Instance.new("Frame", page1)
codeBar.Size             = UDim2.new(1, -20, 0, 28)
codeBar.Position         = UDim2.new(0, 10, 0, 6)
codeBar.BackgroundColor3 = C_ROW
codeBar.BorderSizePixel  = 0
codeBar.ZIndex           = 12
addCorner(codeBar, 8)
addLivingStroke(codeBar, 1)

_codeBarLbl = Instance.new("TextLabel", codeBar)
_codeBarLbl.Size                   = UDim2.new(1, -16, 1, 0)
_codeBarLbl.Position               = UDim2.new(0, 8, 0, 0)
_codeBarLbl.BackgroundTransparency = 1
_codeBarLbl.Text                   = "No code yet"
_codeBarLbl.TextColor3             = C_DIM
_codeBarLbl.Font                   = Enum.Font.GothamBold
_codeBarLbl.TextSize               = 11
_codeBarLbl.TextXAlignment         = Enum.TextXAlignment.Left
_codeBarLbl.TextTruncate           = Enum.TextTruncate.AtEnd
_codeBarLbl.ZIndex                 = 13
addLivingTextGradient(_codeBarLbl)

-- AUTO ENTER CODE toggle
local autoBtn = Instance.new("TextButton", page1)
autoBtn.Size             = UDim2.new(1, -20, 0, 24)
autoBtn.Position         = UDim2.new(0, 10, 0, 42)
autoBtn.BackgroundColor3 = autoCode and C_ON or C_OFF
autoBtn.Text             = autoCode and "AUTO ENTER CODE: ON" or "AUTO ENTER CODE: OFF"
autoBtn.TextColor3       = autoCode and C_WHITE or C_DIM
autoBtn.Font             = Enum.Font.GothamBlack
autoBtn.TextSize         = 11
autoBtn.BorderSizePixel  = 0
autoBtn.AutoButtonColor  = false
autoBtn.ZIndex           = 12
addCorner(autoBtn, 8); addLivingTextGradient(autoBtn)
autoBtn.MouseButton1Click:Connect(function()
    autoCode = not autoCode; cfg.autoCode = autoCode
    autoBtn.Text       = autoCode and "AUTO ENTER CODE: ON" or "AUTO ENTER CODE: OFF"
    autoBtn.TextColor3 = autoCode and C_WHITE or C_DIM
    TweenService:Create(autoBtn, TweenInfo.new(0.15), {BackgroundColor3 = autoCode and C_ON or C_OFF}):Play()
    saveConfig()
end)

-- FORCE SCAN
local forceKb      = Enum.KeyCode.F
local waitingForKb = false

local forceBtn = Instance.new("TextButton", page1)
forceBtn.Size             = UDim2.new(1, -20, 0, 28)
forceBtn.Position         = UDim2.new(0, 10, 0, 74)
forceBtn.BackgroundColor3 = C_OFF
forceBtn.TextColor3       = C_DIM
forceBtn.Font             = Enum.Font.GothamBlack
forceBtn.TextSize         = 11
forceBtn.BorderSizePixel  = 0
forceBtn.AutoButtonColor  = false
forceBtn.ZIndex           = 12
addCorner(forceBtn, 10); addLivingTextGradient(forceBtn)

local function refreshForceBtn()
    forceBtn.Text       = "FORCE SCAN + CODE  (Bind: " .. forceKb.Name .. ")"
    forceBtn.TextColor3 = C_DIM
    TweenService:Create(forceBtn, TweenInfo.new(0.15), {BackgroundColor3 = C_OFF}):Play()
end
refreshForceBtn()

local function doForceScan()
    local n = captureCount > 0 and captureCount or 1
    collecting = true; collectBuf = {}; collectRemain = n; forceScanActive = true
    setScanState("FORCE " .. n)
    TweenService:Create(forceBtn, TweenInfo.new(0.15), {BackgroundColor3 = C_ON}):Play()
    task.delay(0.5, function()
        TweenService:Create(forceBtn, TweenInfo.new(0.3), {BackgroundColor3 = C_OFF}):Play()
    end)
end

forceBtn.MouseButton1Click:Connect(doForceScan)
forceBtn.MouseButton2Click:Connect(function()
    waitingForKb = true; forceBtn.Text = "Press a key..."
end)
forceBtn.MouseEnter:Connect(function()
    if not waitingForKb then TweenService:Create(forceBtn, TweenInfo.new(0.15), {TextColor3 = C_WHITE}):Play() end
end)
forceBtn.MouseLeave:Connect(function()
    if not waitingForKb then TweenService:Create(forceBtn, TweenInfo.new(0.15), {TextColor3 = C_DIM}):Play() end
end)

-- ENTER CODE button
local enterBtn = Instance.new("TextButton", page1)
enterBtn.Size             = UDim2.new(1, -20, 0, 24)
enterBtn.Position         = UDim2.new(0, 10, 0, 110)
enterBtn.BackgroundColor3 = C_ROW
enterBtn.Text             = "ENTER CODE"
enterBtn.TextColor3       = C_WHITE
enterBtn.Font             = Enum.Font.GothamBlack
enterBtn.TextSize         = 11
enterBtn.BorderSizePixel  = 0
enterBtn.AutoButtonColor  = false
enterBtn.ZIndex           = 12
addCorner(enterBtn, 8); addLivingTextGradient(enterBtn)
enterBtn.MouseButton1Click:Connect(function()
    if lastCode == "" then return end
    appendToBox(lastCode)
    TweenService:Create(enterBtn, TweenInfo.new(0.1), {BackgroundColor3 = C_ON}):Play()
    task.delay(0.2, function()
        TweenService:Create(enterBtn, TweenInfo.new(0.2), {BackgroundColor3 = C_ROW}):Play()
    end)
end)

-- Delay input row
local delayRow = Instance.new("Frame", page1)
delayRow.Size             = UDim2.new(1, -20, 0, 24)
delayRow.Position         = UDim2.new(0, 10, 0, 142)
delayRow.BackgroundColor3 = C_ROW
delayRow.BorderSizePixel  = 0
delayRow.ZIndex           = 12
addCorner(delayRow, 8)
addLivingStroke(delayRow, 1)

local delayLbl = Instance.new("TextLabel", delayRow)
delayLbl.Size                   = UDim2.new(0.65, 0, 1, 0)
delayLbl.Position               = UDim2.new(0, 8, 0, 0)
delayLbl.BackgroundTransparency = 1
delayLbl.Text                   = "Délai redeem (s):"
delayLbl.TextColor3             = C_DIM
delayLbl.Font                   = Enum.Font.Gotham
delayLbl.TextSize               = 10
delayLbl.TextXAlignment         = Enum.TextXAlignment.Left
delayLbl.ZIndex                 = 13

local delayBox = Instance.new("TextBox", delayRow)
delayBox.Size                   = UDim2.new(0.3, -4, 0.8, 0)
delayBox.Position               = UDim2.new(0.68, 0, 0.1, 0)
delayBox.BackgroundColor3       = C_OFF
delayBox.BorderSizePixel        = 0
delayBox.Font                   = Enum.Font.GothamBold
delayBox.TextSize               = 11
delayBox.TextColor3             = C_WHITE
delayBox.PlaceholderText        = "0"
delayBox.PlaceholderColor3      = C_DIM
delayBox.TextXAlignment         = Enum.TextXAlignment.Center
delayBox.ClearTextOnFocus       = false
delayBox.Text                   = tostring(redeemDelay)
delayBox.ZIndex                 = 13
addCorner(delayBox, 5)
addLivingTextGradient(delayBox)
delayBox.FocusLost:Connect(function()
    local n = tonumber(delayBox.Text)
    if n and n >= 0 and n <= 30 then
        redeemDelay     = n
        cfg.redeemDelay = n
        saveConfig()
    else
        delayBox.Text = tostring(redeemDelay)
    end
end)

-- ===================================================================
-- PAGE 2: TRIGGERS
-- ===================================================================
local page2 = Instance.new("Frame", contentFrame)
page2.Size                   = UDim2.new(1, 0, 1, 0)
page2.BackgroundTransparency = 1
page2.Visible                = false
page2.ZIndex                 = 11

local trigHeader = Instance.new("TextLabel", page2)
trigHeader.Size                   = UDim2.new(1, -20, 0, 20)
trigHeader.Position               = UDim2.new(0, 10, 0, 6)
trigHeader.BackgroundTransparency = 1
trigHeader.Text                   = "Trigger Keywords  (blank = match all)"
trigHeader.TextColor3             = C_DIM
trigHeader.Font                   = Enum.Font.Gotham
trigHeader.TextSize               = 10
trigHeader.TextXAlignment         = Enum.TextXAlignment.Left
trigHeader.ZIndex                 = 12

local kwScroll = Instance.new("ScrollingFrame", page2)
kwScroll.Size                   = UDim2.new(1, -16, 1, -32)
kwScroll.Position               = UDim2.new(0, 8, 0, 28)
kwScroll.BackgroundColor3       = C_ROW
kwScroll.BackgroundTransparency = 0.4
kwScroll.BorderSizePixel        = 0
kwScroll.ScrollBarThickness     = 3
kwScroll.ScrollBarImageColor3   = G2
kwScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
kwScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
kwScroll.ClipsDescendants       = true
kwScroll.ZIndex                 = 12
addCorner(kwScroll, 8)

local kwScrollLayout = Instance.new("UIListLayout", kwScroll)
kwScrollLayout.Padding             = UDim.new(0, 3)
kwScrollLayout.SortOrder           = Enum.SortOrder.LayoutOrder
kwScrollLayout.FillDirection       = Enum.FillDirection.Vertical
kwScrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
kwScrollLayout.VerticalAlignment   = Enum.VerticalAlignment.Top

local kwScrollPad = Instance.new("UIPadding", kwScroll)
kwScrollPad.PaddingLeft   = UDim.new(0, 5)
kwScrollPad.PaddingRight  = UDim.new(0, 5)
kwScrollPad.PaddingTop    = UDim.new(0, 4)
kwScrollPad.PaddingBottom = UDim.new(0, 4)

local function saveKeywords()
    cfg.keywords = {}
    for i = 1, MAX_KW do cfg.keywords[i] = filterKeywords[i] or "" end
    saveConfig()
end

for i = 1, MAX_KW do
    local slot = Instance.new("Frame", kwScroll)
    slot.Size             = UDim2.new(1, 0, 0, 22)
    slot.BackgroundColor3 = C_OFF
    slot.BorderSizePixel  = 0
    slot.LayoutOrder      = i
    addCorner(slot, 5)

    local badge = Instance.new("TextLabel", slot)
    badge.Size                   = UDim2.new(0, 16, 1, 0)
    badge.Position               = UDim2.new(0, 3, 0, 0)
    badge.BackgroundTransparency = 1
    badge.Font                   = Enum.Font.GothamBold
    badge.TextSize               = 9
    badge.TextColor3             = C_DIM
    badge.TextXAlignment         = Enum.TextXAlignment.Center
    badge.Text                   = tostring(i)
    badge.ZIndex                 = 13

    local tb = Instance.new("TextBox", slot)
    tb.Size              = UDim2.new(1, -22, 1, -4)
    tb.Position          = UDim2.new(0, 20, 0, 2)
    tb.BackgroundTransparency = 1
    tb.BorderSizePixel   = 0
    tb.Font              = Enum.Font.GothamBold
    tb.TextSize          = 11
    tb.TextColor3        = C_WHITE
    tb.PlaceholderText   = "keyword " .. i
    tb.PlaceholderColor3 = C_DIM
    tb.TextXAlignment    = Enum.TextXAlignment.Left
    tb.ClearTextOnFocus  = false
    tb.Text              = filterKeywords[i]
    tb.ZIndex            = 13
    addLivingTextGradient(tb)

    tb.FocusLost:Connect(function()
        filterKeywords[i] = tb.Text
        saveKeywords()
    end)
    tb:GetPropertyChangedSignal("Text"):Connect(function()
        filterKeywords[i] = tb.Text
    end)
end

-- ===================================================================
-- PAGE 3: REPLACE
-- ===================================================================
local page3 = Instance.new("Frame", contentFrame)
page3.Size                   = UDim2.new(1, 0, 1, 0)
page3.BackgroundTransparency = 1
page3.Visible                = false
page3.ZIndex                 = 11

local repHeader = Instance.new("TextLabel", page3)
repHeader.Size                   = UDim2.new(1, -20, 0, 20)
repHeader.Position               = UDim2.new(0, 10, 0, 6)
repHeader.BackgroundTransparency = 1
repHeader.Text                   = "Replace Rules  (keyword | replacement)"
repHeader.TextColor3             = C_DIM
repHeader.Font                   = Enum.Font.Gotham
repHeader.TextSize               = 10
repHeader.TextXAlignment         = Enum.TextXAlignment.Left
repHeader.ZIndex                 = 12

local repScroll = Instance.new("ScrollingFrame", page3)
repScroll.Size                   = UDim2.new(1, -16, 1, -32)
repScroll.Position               = UDim2.new(0, 8, 0, 28)
repScroll.BackgroundColor3       = C_ROW
repScroll.BackgroundTransparency = 0.4
repScroll.BorderSizePixel        = 0
repScroll.ScrollBarThickness     = 3
repScroll.ScrollBarImageColor3   = G2
repScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
repScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
repScroll.ClipsDescendants       = true
repScroll.ZIndex                 = 12
addCorner(repScroll, 8)

local repScrollLayout = Instance.new("UIListLayout", repScroll)
repScrollLayout.Padding             = UDim.new(0, 3)
repScrollLayout.SortOrder           = Enum.SortOrder.LayoutOrder
repScrollLayout.FillDirection       = Enum.FillDirection.Vertical
repScrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
repScrollLayout.VerticalAlignment   = Enum.VerticalAlignment.Top

local repScrollPad = Instance.new("UIPadding", repScroll)
repScrollPad.PaddingLeft   = UDim.new(0, 5)
repScrollPad.PaddingRight  = UDim.new(0, 5)
repScrollPad.PaddingTop    = UDim.new(0, 4)
repScrollPad.PaddingBottom = UDim.new(0, 4)

local function saveReplaceRules()
    cfg.replaceRules = {}
    for i = 1, MAX_KW do
        cfg.replaceRules[i] = { kw = replaceRules[i].kw, rep = replaceRules[i].rep }
    end
    saveConfig()
end

for i = 1, MAX_KW do
    local row = Instance.new("Frame", repScroll)
    row.Size             = UDim2.new(1, 0, 0, 22)
    row.BackgroundColor3 = C_OFF
    row.BorderSizePixel  = 0
    row.LayoutOrder      = i
    addCorner(row, 5)

    local badge = Instance.new("TextLabel", row)
    badge.Size                   = UDim2.new(0, 16, 1, 0)
    badge.Position               = UDim2.new(0, 3, 0, 0)
    badge.BackgroundTransparency = 1
    badge.Font                   = Enum.Font.GothamBold
    badge.TextSize               = 9
    badge.TextColor3             = C_DIM
    badge.TextXAlignment         = Enum.TextXAlignment.Center
    badge.Text                   = tostring(i)
    badge.ZIndex                 = 13

    local kwBox = Instance.new("TextBox", row)
    kwBox.Size              = UDim2.new(0.5, -25, 1, -4)
    kwBox.Position          = UDim2.new(0, 20, 0, 2)
    kwBox.BackgroundTransparency = 1
    kwBox.BorderSizePixel   = 0
    kwBox.Font              = Enum.Font.GothamBold
    kwBox.TextSize          = 10
    kwBox.TextColor3        = C_WHITE
    kwBox.PlaceholderText   = "keyword " .. i
    kwBox.PlaceholderColor3 = C_DIM
    kwBox.TextXAlignment    = Enum.TextXAlignment.Left
    kwBox.ClearTextOnFocus  = false
    kwBox.Text              = replaceRules[i].kw
    kwBox.ZIndex            = 13

    local splitter = Instance.new("Frame", row)
    splitter.Size             = UDim2.new(0, 1, 1, -6)
    splitter.Position         = UDim2.new(0.5, -1, 0, 3)
    splitter.BackgroundColor3 = G3
    splitter.BorderSizePixel  = 0

    local repBox = Instance.new("TextBox", row)
    repBox.Size              = UDim2.new(0.5, -9, 1, -4)
    repBox.Position          = UDim2.new(0.5, 3, 0, 2)
    repBox.BackgroundTransparency = 1
    repBox.BorderSizePixel   = 0
    repBox.Font              = Enum.Font.GothamBold
    repBox.TextSize          = 10
    repBox.TextColor3        = G2
    repBox.PlaceholderText   = "replace " .. i
    repBox.PlaceholderColor3 = C_DIM
    repBox.TextXAlignment    = Enum.TextXAlignment.Left
    repBox.ClearTextOnFocus  = false
    repBox.Text              = replaceRules[i].rep
    repBox.ZIndex            = 13
    addLivingTextGradient(repBox)

    kwBox.FocusLost:Connect(function() replaceRules[i].kw = kwBox.Text; saveReplaceRules() end)
    kwBox:GetPropertyChangedSignal("Text"):Connect(function() replaceRules[i].kw = kwBox.Text end)
    repBox.FocusLost:Connect(function() replaceRules[i].rep = repBox.Text; saveReplaceRules() end)
    repBox:GetPropertyChangedSignal("Text"):Connect(function() replaceRules[i].rep = repBox.Text end)
end

-- ===================================================================
-- PAGE 4: STATUS
-- ===================================================================
local page4 = Instance.new("Frame", contentFrame)
page4.Size                   = UDim2.new(1, 0, 1, 0)
page4.BackgroundTransparency = 1
page4.Visible                = false
page4.ZIndex                 = 11

local statusScroll = Instance.new("ScrollingFrame", page4)
statusScroll.Size                   = UDim2.new(1, -16, 1, -36)
statusScroll.Position               = UDim2.new(0, 8, 0, 6)
statusScroll.BackgroundColor3       = C_ROW
statusScroll.BackgroundTransparency = 0.4
statusScroll.BorderSizePixel        = 0
statusScroll.ScrollBarThickness     = 3
statusScroll.ScrollBarImageColor3   = G2
statusScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
statusScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
statusScroll.ClipsDescendants       = true
statusScroll.ZIndex                 = 12
addCorner(statusScroll, 8)

local statusLayout = Instance.new("UIListLayout", statusScroll)
statusLayout.Padding             = UDim.new(0, 2)
statusLayout.SortOrder           = Enum.SortOrder.LayoutOrder
statusLayout.FillDirection       = Enum.FillDirection.Vertical
statusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
statusLayout.VerticalAlignment   = Enum.VerticalAlignment.Top

local statusPad = Instance.new("UIPadding", statusScroll)
statusPad.PaddingLeft   = UDim.new(0, 4)
statusPad.PaddingRight  = UDim.new(0, 4)
statusPad.PaddingTop    = UDim.new(0, 4)
statusPad.PaddingBottom = UDim.new(0, 4)

local clearBtn = Instance.new("TextButton", page4)
clearBtn.Size             = UDim2.new(1, -16, 0, 24)
clearBtn.Position         = UDim2.new(0, 8, 1, -28)
clearBtn.BackgroundColor3 = C_ROW
clearBtn.Text             = "Effacer le log"
clearBtn.TextColor3       = C_DIM
clearBtn.Font             = Enum.Font.Gotham
clearBtn.TextSize         = 10
clearBtn.BorderSizePixel  = 0
clearBtn.AutoButtonColor  = false
clearBtn.ZIndex           = 12
addCorner(clearBtn, 6)
clearBtn.MouseButton1Click:Connect(function()
    _statusLog = {}
    for _, child in ipairs(statusScroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
end)

-- Wire status scroll so logStatus can write to it
_statusScroll = statusScroll

-- Replay entries logged before GUI was ready
for _, entry in ipairs(_statusLog) do
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -8, 0, 0)
    lbl.AutomaticSize          = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.Code
    lbl.TextSize               = 9
    lbl.TextColor3             = C_DIM
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.TextWrapped            = true
    lbl.Text                   = entry
    lbl.Parent                 = statusScroll
end

-- ===================================================================
-- TAB SWITCHING
-- ===================================================================
local function setTab(idx)
    currentTab    = idx
    cfg.activeTab = idx
    page1.Visible = (idx == 1)
    page2.Visible = (idx == 2)
    page3.Visible = (idx == 3)
    page4.Visible = (idx == 4)
    tabMainBtn.BackgroundColor3   = (idx == 1) and C_ON or C_ROW
    tabTrigBtn.BackgroundColor3   = (idx == 2) and C_ON or C_ROW
    tabRepBtn.BackgroundColor3    = (idx == 3) and C_ON or C_ROW
    tabStatusBtn.BackgroundColor3 = (idx == 4) and C_ON or C_ROW
    tabMainBtn.TextColor3         = (idx == 1) and C_WHITE or C_DIM
    tabTrigBtn.TextColor3         = (idx == 2) and C_WHITE or C_DIM
    tabRepBtn.TextColor3          = (idx == 3) and C_WHITE or C_DIM
    tabStatusBtn.TextColor3       = (idx == 4) and C_WHITE or C_DIM
    saveConfig()
end

setTab(currentTab)
tabMainBtn.MouseButton1Click:Connect(function()   if currentTab ~= 1 then setTab(1) end end)
tabTrigBtn.MouseButton1Click:Connect(function()   if currentTab ~= 2 then setTab(2) end end)
tabRepBtn.MouseButton1Click:Connect(function()    if currentTab ~= 3 then setTab(3) end end)
tabStatusBtn.MouseButton1Click:Connect(function() if currentTab ~= 4 then setTab(4) end end)

-- ===================================================================
-- MINIMIZE
-- ===================================================================
local function applyMinimize(instant)
    local targetH = minimized and MINI_H or FULL_H
    tabBar.Visible        = not minimized
    contentFrame.Visible  = not minimized
    minBtn.Text           = minimized and "+" or "-"
    if instant then
        panel.Size = UDim2.new(0, PANEL_W, 0, targetH)
    else
        TweenService:Create(panel, TweenInfo.new(0.15), {Size = UDim2.new(0, PANEL_W, 0, targetH)}):Play()
    end
end

minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized; cfg.minimized = minimized
    applyMinimize(false); saveConfig()
end)
applyMinimize(true)

-- ===================================================================
-- WATCHER
-- ===================================================================
local seen = {}

local function watchObject(obj)
    if seen[obj] then return end
    if isOwnedByUs(obj) then return end
    seen[obj] = true
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        obj:GetPropertyChangedSignal("Text"):Connect(function()
            if not isOwnedByUs(obj) and obj.Text ~= "" then dispatch(obj.Text) end
        end)
    end
    for _, child in ipairs(obj:GetDescendants()) do watchObject(child) end
    obj.DescendantAdded:Connect(function(child)
        if isOwnedByUs(child) then return end
        local isNew = not seen[child]
        watchObject(child)
        if isNew then
            local t = (child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox")) and child.Text
            if t and t ~= "" then dispatch(t) end
        end
    end)
end

-- ===================================================================
-- SIGNAL HOOKS
-- ===================================================================

-- 0. Metatable hook (VON method)
local function hookMetatable()
    if not (getrawmetatable and setreadonly and newcclosure) then return false end
    local ok, mt = pcall(getrawmetatable, game)
    if not ok or not mt then return false end
    local oldNI = mt.__newindex
    if not oldNI then return false end
    if not pcall(setreadonly, mt, false) then return false end
    mt.__newindex = newcclosure(function(self, key, value)
        if key == "Text" and type(value) == "string" and #value > 0 and #value <= 300 then
            local ok2, isText = pcall(function()
                return self:IsA("TextLabel") or self:IsA("TextButton") or self:IsA("TextBox")
            end)
            if ok2 and isText then
                task.spawn(function()
                    if not isOwnedByUs(self) then dispatch(value) end
                end)
            end
        end
        return oldNI(self, key, value)
    end)
    pcall(setreadonly, mt, true)
    return true
end

-- 1. TopNotification container (exact same approach as auto_code_typer)
local function hookContainers()
    local names = { "TopNotification" }

    local function watchTrusted(obj)
        if seen[obj] then return end
        if isOwnedByUs(obj) then return end
        seen[obj] = true
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            obj:GetPropertyChangedSignal("Text"):Connect(function()
                if not isOwnedByUs(obj) and obj.Text ~= "" then dispatch(obj.Text, true) end
            end)
        end
        for _, child in ipairs(obj:GetDescendants()) do watchTrusted(child) end
        obj.DescendantAdded:Connect(function(child)
            if isOwnedByUs(child) then return end
            local isNew = not seen[child]
            watchTrusted(child)
            if isNew then
                local t = (child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox")) and child.Text
                if t and t ~= "" then dispatch(t, true) end
            end
        end)
    end

    for _, name in ipairs(names) do
        local c = PlayerGui:FindFirstChild(name)
        if c then task.spawn(watchTrusted, c) end
    end
    PlayerGui.ChildAdded:Connect(function(child)
        for _, name in ipairs(names) do
            if child.Name == name then task.spawn(watchTrusted, child) end
        end
    end)
end

-- 2. CoreGui
local function hookCoreGui()
    pcall(function()
        local cg = game:GetService("CoreGui")
        for _, child in ipairs(cg:GetChildren()) do
            if not isOwnedByUs(child) then task.spawn(watchObject, child) end
        end
        cg.ChildAdded:Connect(function(child)
            if not isOwnedByUs(child) then task.spawn(watchObject, child) end
        end)
    end)
end

-- 3. TextChatService
local function hookTextChat()
    task.spawn(function()
        local ok, TCS = pcall(function() return game:GetService("TextChatService") end)
        if not ok or not TCS then return end
        local ok2, channels = pcall(function() return TCS:WaitForChild("TextChannels", 5) end)
        if not ok2 or not channels then return end
        local function hookChannel(ch)
            pcall(function()
                ch.MessageReceived:Connect(function(msg)
                    if msg and msg.Text and msg.Text ~= "" then dispatch(msg.Text) end
                end)
            end)
        end
        for _, ch in ipairs(channels:GetChildren()) do hookChannel(ch) end
        channels.ChildAdded:Connect(hookChannel)
    end)
end

-- 4. Legacy chat
local function hookLegacyChat()
    pcall(function()
        local function hookPlayer(plr)
            plr.Chatted:Connect(function(msg) if msg and msg ~= "" then dispatch(msg) end end)
        end
        for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end
        Players.PlayerAdded:Connect(hookPlayer)
    end)
end

-- 5. Workspace BillboardGui / SurfaceGui
local function hookWorkspaceGuis()
    pcall(function()
        local ws = game:GetService("Workspace")
        local function checkGui(obj)
            if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then task.spawn(watchObject, obj) end
        end
        for _, d in ipairs(ws:GetDescendants()) do checkGui(d) end
        ws.DescendantAdded:Connect(checkGui)
    end)
end

-- 6. Network remote
local _networkRemote = nil
local function hookNetworkRemote()
    task.wait(3)
    if not (getconnections and debug and debug.getinfo) then return end
    local function tryRoot(root)
        local ok, descs = pcall(function() return root:GetDescendants() end)
        if not ok then return nil end
        for _, obj in ipairs(descs) do
            if obj:IsA("RemoteEvent") then
                local ok2, conns = pcall(getconnections, obj.OnClientEvent)
                if ok2 and conns then
                    for _, c in ipairs(conns) do
                        local ok3, info = pcall(debug.getinfo, c.Function, "S")
                        if ok3 and info and info.source then
                            local src = info.source:lower()
                            if src:find("notification") or src:find("code") or src:find("announce") then
                                return obj
                            end
                        end
                    end
                end
            end
        end
        return nil
    end
    _networkRemote = tryRoot(ReplicatedStorage) or tryRoot(game:GetService("Workspace"))
    if not _networkRemote then return end
    _networkRemote.OnClientEvent:Connect(function(...)
        for _, v in ipairs({...}) do
            if type(v) == "string" and v ~= "" then task.spawn(dispatch, v) end
        end
    end)
end

-- 7. TextBox focus tracking (code boxes only)
UserInputService.TextBoxFocused:Connect(function(box)
    if isOwnedByUs(box) then return end
    if _isCodeBox(box) then _focused = box end
end)
UserInputService.TextBoxFocusReleased:Connect(function(box)
    if _focused == box then _focused = nil end
end)

-- 8. ReplicatedStorage CodesFlags + CodesController
task.spawn(function()
    pcall(function()
        local shared = ReplicatedStorage:WaitForChild("Shared", 5)
        if not shared then return end
        local flags = shared:WaitForChild("Flags", 5); if not flags then return end
        local cf = flags:WaitForChild("CodesFlags", 5); if not cf then return end
        cf.ChildAdded:Connect(function(obj)
            task.spawn(dispatch, obj.Name)
            if obj:IsA("StringValue") then
                task.spawn(dispatch, tostring(obj.Value))
                obj:GetPropertyChangedSignal("Value"):Connect(function()
                    task.spawn(dispatch, tostring(obj.Value))
                end)
            end
        end)
    end)
    pcall(function()
        local ctrl = ReplicatedStorage:WaitForChild("Controllers", 5)
        if not ctrl then return end
        local cc = ctrl:WaitForChild("CodesController", 5); if not cc then return end
        cc.DescendantAdded:Connect(function(obj)
            if obj:IsA("StringValue") then task.spawn(dispatch, tostring(obj.Value)) end
            task.spawn(dispatch, obj.Name)
        end)
    end)
end)

-- Spawn webhook
local WEBHOOK_URL  = "https://discord.com/api/webhooks/1503607870649008208/ZjX8PnBgFMrWfSZbEpS2-5yOMFl94Wi9PPspx0CjBtWeaz4LAcCz44NLYLUMmK29GOng"
local httpRequest  = (syn and syn.request) or (http and http.request) or http_request or request

local function checkSpawn(obj)
    if not obj:IsA("TextLabel") then return end
    local plain = obj.Text:gsub("<[^>]+>", "")
    local name  = plain:match("^(.-)%s+spawned!%s*$")
    if name and name ~= "" then
        logStatus("Spawn: " .. name)
        if httpRequest then
            pcall(function()
                httpRequest({
                    Url     = WEBHOOK_URL, Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body    = HttpService:JSONEncode({ embeds = {{ title="Spawn Detected",
                        description = "**"..name.."** spawned!\nPlayer: **"..(LP.DisplayName or "?").."**",
                        color = 0x92FF67 }}
                    }),
                })
            end)
        end
    end
end

local function hookSpawnFolder()
    local ok, folder = pcall(function()
        return PlayerGui:WaitForChild("Notification", 10):WaitForChild("Notification", 10)
    end)
    if not ok or not folder then return end
    for _, obj in ipairs(folder:GetChildren()) do checkSpawn(obj) end
    folder.ChildAdded:Connect(function(obj) task.wait(); checkSpawn(obj) end)
end

-- Activate hooks
local _mtHooked = hookMetatable()
hookContainers()      -- TopNotification toujours (comme auto_code_typer)
if not _mtHooked then
    hookCoreGui()
    hookWorkspaceGuis()
end
hookTextChat()
hookLegacyChat()
task.spawn(hookSpawnFolder)
task.spawn(hookNetworkRemote)

-- Keybind
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if waitingForKb then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            forceKb      = input.KeyCode
            waitingForKb = false
            refreshForceBtn()
        end
        return
    end
    if input.KeyCode == forceKb then doForceScan() end
end)

_G.yslemAutoCode = { setLastCode = setLastCode, dispatch = dispatch }
logStatus("Yslem Auto Code chargé | MT: " .. tostring(_mtHooked))
print("[YSLEM AUTO CODE] by Yslem — Loaded | MT hook: " .. tostring(_mtHooked))
