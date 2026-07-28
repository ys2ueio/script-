local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LP               = Players.LocalPlayer
local PlayerGui        = LP:WaitForChild("PlayerGui")

-- ===================================================================
-- CONFIG
-- ===================================================================
local CFG_PATH = "yslem_autocode_cfg.json"
local cfg = {
    autoCode     = true,
    captureCount = 0,
    posX         = 16,
    posY         = 80,
    minimized    = false,
    activeTab    = 1,
}
local function saveConfig()
    if writefile then pcall(writefile, CFG_PATH, HttpService:JSONEncode(cfg)) end
end
local function loadConfig()
    if not (readfile and isfile and isfile(CFG_PATH)) then return end
    local ok, d = pcall(function() return HttpService:JSONDecode(readfile(CFG_PATH)) end)
    if ok and type(d) == "table" then for k, v in pairs(d) do cfg[k] = v end end
end
loadConfig()

-- ===================================================================
-- STATE
-- ===================================================================
local autoCode     = cfg.autoCode == true
local captureCount = cfg.captureCount or 0
local collecting   = false
local collectBuf   = {}
local collectRemain= 0
local lastCode     = ""
local _redeemLock  = false
local _dedupText   = ""
local _dedupTime   = 0
local _lastRedeem  = { code = "", time = 0 }
local _seen        = {}
local _codeInput   = nil
local _pillLbl     = nil

-- ===================================================================
-- COLOURS
-- ===================================================================
local C_BG    = Color3.fromRGB(8,  8,  8)
local C_ON    = Color3.fromRGB(45, 45, 45)
local C_ROW   = Color3.fromRGB(22, 22, 22)
local C_WHITE = Color3.fromRGB(240,240,240)
local C_DIM   = Color3.fromRGB(120,120,120)
local G1      = Color3.fromRGB(200,200,200)
local G2      = Color3.fromRGB(90, 90, 90)
local G3      = Color3.fromRGB(25, 25, 25)

local _grads, _strokes = {}, {}
local function addCorner(i, r)
    local c = Instance.new("UICorner", i); c.CornerRadius = UDim.new(0, r or 8); return c
end
local function addGrad(inst)
    local g = Instance.new("UIGradient", inst)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    G1),
        ColorSequenceKeypoint.new(0.25, G2),
        ColorSequenceKeypoint.new(0.5,  G1),
        ColorSequenceKeypoint.new(0.75, G2),
        ColorSequenceKeypoint.new(1,    G1),
    })
    table.insert(_grads, g); return g
end
local function addStroke(inst, t)
    local s = Instance.new("UIStroke", inst)
    s.Thickness = t or 1.5; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Color = G2
    local g = Instance.new("UIGradient", s)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    G3),
        ColorSequenceKeypoint.new(0.25, G2),
        ColorSequenceKeypoint.new(0.5,  G3),
        ColorSequenceKeypoint.new(0.75, G2),
        ColorSequenceKeypoint.new(1,    G3),
    })
    table.insert(_strokes, g); return s
end
RunService.RenderStepped:Connect(function()
    for _, g in ipairs(_grads)   do if g and g.Parent then g.Rotation = (g.Rotation + 0.6) % 360 end end
    for _, g in ipairs(_strokes) do if g and g.Parent then g.Rotation = (g.Rotation + 0.6) % 360 end end
end)

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

local function isOurs(obj)
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
local BLACKLIST = {
    "join","left","connected","disconnected","welcome","server","update",
    "version","patch","event","roblox","game","studio","error","warning",
    "player","loading","please","wait","click","press","open","close","admin",
}
local COMMON = {
    "the","and","for","are","but","not","you","all","can","had","her",
    "was","one","our","out","day","get","has","him","his","how","man",
    "new","now","old","see","two","way","who","boy","did","its","let",
    "put","say","she","too","use",
}
local KEYWORDS = { "code is","use code","new code","code:","codes:","promo code" }

local function isBlacklisted(text)
    local low = text:lower()
    for _, w in ipairs(BLACKLIST) do if low:find(w, 1, true) then return true end end
    return false
end

local function looksLikeCode(text)
    if not text or #text < 4 or #text > 30 then return false end
    if isBlacklisted(text) then return false end
    local low = text:lower()
    for _, w in ipairs(COMMON) do if low == w then return false end end
    if not text:match("%a") then return false end
    if not text:match("%u") then return false end
    -- reject hex colours (3/6/8 hex chars)
    if text:match("^[0-9A-Fa-f]+$") and (#text == 3 or #text == 6 or #text == 8) then return false end
    local wc = 0
    for _ in text:gmatch("%S+") do wc = wc + 1 end
    return wc <= 4
end

local function isLoneCode(text)
    if not text then return false end
    if not text:match("^[%w%-_]+$") then return false end
    if #text < 4 or #text > 30 then return false end
    -- uppercase + digit (CODE2025, EPIC100…)
    if text:match("%u") and text:match("%d") then return true end
    -- all-caps 7+ chars (MOONHUB, RELEASE…)
    if text == text:upper() and text:match("%u") and #text >= 7 then return true end
    return false
end

local function extractCode(txt)
    if not txt then return nil end
    for token in txt:gmatch("[A-Z][A-Z0-9%-_]+") do
        -- require digit OR 7+ chars to reject short UI words (LUCKY, BLACK, RARE…)
        if #token >= 4 and looksLikeCode(token) and (token:match("%d") or #token >= 7) then
            local letters = 0
            for _ in token:gmatch("%a") do letters = letters + 1 end
            if letters >= 3 then return token end
        end
    end
    return nil
end

local function isNoise(txt)
    if not txt or txt == "" then return true end
    if txt:match("^%d+$")           then return true end
    if txt:match("^%d+:%d+$")       then return true end
    if txt:match("^%d+%.%d+$")      then return true end
    if txt:match("^[%+%-]?%d") and #txt < 8 then return true end
    if txt:match("^%d+[kKmMbBgG]?$") then return true end
    if txt:match("^x%d")            then return true end
    return false
end

local function matchKeyword(text)
    local low = text:lower()
    for _, kw in ipairs(KEYWORDS) do
        if low:find(kw, 1, true) then return true end
    end
    return false
end

-- ===================================================================
-- UI HELPERS
-- ===================================================================
local function setScanState(txt)
    if _pillLbl then _pillLbl.Text = txt end
end

local function setCodeInput(code)
    lastCode = code
    if _codeInput then
        _codeInput.Text       = code
        _codeInput.TextColor3 = code ~= "" and C_WHITE or C_DIM
    end
end

-- ===================================================================
-- REDEEM
-- ===================================================================
local function fireSignal(btn)
    pcall(function() if firesignal then firesignal(btn.MouseButton1Click) end end)
    pcall(function() if firesignal then firesignal(btn.Activated) end end)
end

local function fireSubmitIn(root)
    if not root then return false end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextButton") or d:IsA("ImageButton") then
            local n = d.Name:lower()
            local t = (d:IsA("TextButton") and d.Text:lower()) or ""
            for _, h in ipairs({"submit","confirm","redeem","enter","ok","send"}) do
                if n:find(h,1,true) or t:find(h,1,true) then fireSignal(d); return true end
            end
        end
    end
    return false
end

local function redeemCode(code)
    if _redeemLock then return end
    _redeemLock = true
    pcall(function()
        local codesGui = PlayerGui:FindFirstChild("Codes");    if not codesGui then return end
        local inner    = codesGui:FindFirstChild("Codes");     if not inner    then return end
        local cr       = inner:FindFirstChild("CodeRedeem");   if not cr       then return end
        local tb       = cr:FindFirstChildWhichIsA("TextBox"); if not tb       then return end
        local wasVis   = inner.Visible
        inner.Visible  = true
        pcall(function() tb:CaptureFocus() end)
        tb.Text = code
        pcall(function() tb.CursorPosition = #code + 1 end)
        task.wait(0.05)
        pcall(function() tb:ReleaseFocus(true) end)
        task.wait(0.1)
        if not fireSubmitIn(cr) then fireSubmitIn(inner) end
        inner.Visible = wasVis
    end)
    task.delay(4, function() _redeemLock = false end)
end

-- ===================================================================
-- DISPATCH  (no metatable hook — safe watchObject only)
-- ===================================================================
local function dispatch(text)
    if not text or text == "" then return end

    -- In parts mode while collecting, pure digit strings are valid parts
    local isPureDigit = text:match("^%d+$")
    if not (captureCount > 0 and collecting and isPureDigit) then
        if isNoise(text) then return end
    end

    -- Dedup (0.5s window)
    local now = tick()
    if text == _dedupText and (now - _dedupTime) < 0.5 then return end
    _dedupText = text
    _dedupTime = now

    -- ── PARTS MODE ──────────────────────────────────────────────────
    if captureCount > 0 then
        if collecting then
            table.insert(collectBuf, text)
            collectRemain = collectRemain - 1
            local current = table.concat(collectBuf)
            setCodeInput(current)
            setScanState("PARTS " .. #collectBuf .. "/" .. captureCount)
            if collectRemain <= 0 then
                collecting = false; collectBuf = {}; collectRemain = 0
                setScanState("SCANNING")
                _lastRedeem.code = current
                _lastRedeem.time = tick()
                if autoCode then task.spawn(redeemCode, current) end
            end
        else
            -- Start collecting on first valid uppercase word
            if text:match("^[%w%-_]+$") and #text >= 3 and text:match("%u") then
                collectBuf    = { text }
                collectRemain = captureCount - 1
                collecting    = true
                setCodeInput(text)
                setScanState("PARTS 1/" .. captureCount)
                if collectRemain <= 0 then
                    collecting = false; collectBuf = {}; collectRemain = 0
                    setScanState("SCANNING")
                    _lastRedeem.code = text
                    _lastRedeem.time = tick()
                    if autoCode then task.spawn(redeemCode, text) end
                end
            end
        end
        return
    end

    -- ── NORMAL MODE ─────────────────────────────────────────────────
    local result

    if matchKeyword(text) then
        -- Try to find inline code first ("Use Code ABC123!")
        result = extractCode(text)
        -- If no inline code, next text will be treated as standalone code (handled below)
    else
        -- Accept only standalone lone code tokens
        result = (isLoneCode(text) and looksLikeCode(text)) and text or nil
    end

    if result and result ~= "" then
        if result:lower() == _lastRedeem.code:lower() and (tick() - _lastRedeem.time) < 30 then return end
        setCodeInput(result)
        _lastRedeem.code = result
        _lastRedeem.time = tick()
        if autoCode then task.spawn(redeemCode, result) end
    end
end

-- ===================================================================
-- WATCHERS  (safe: GetPropertyChangedSignal only, no MT hook)
-- ===================================================================
local function watchObj(obj)
    if _seen[obj] then return end
    if isOurs(obj) then return end
    _seen[obj] = true
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        obj:GetPropertyChangedSignal("Text"):Connect(function()
            if not isOurs(obj) and obj.Text ~= "" then
                task.spawn(dispatch, obj.Text)
            end
        end)
    end
    obj.DescendantAdded:Connect(function(child)
        if isOurs(child) then return end
        task.spawn(watchObj, child)
        if (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Text ~= "" then
            task.spawn(dispatch, child.Text)
        end
    end)
end

local function watchAll(root)
    pcall(function()
        for _, d in ipairs(root:GetDescendants()) do
            pcall(watchObj, d)
        end
    end)
    pcall(watchObj, root)
end

-- PlayerGui (delayed to avoid init spam)
task.spawn(function()
    task.wait(2)
    watchAll(PlayerGui)
    PlayerGui.ChildAdded:Connect(function(child)
        if not isOurs(child) then task.spawn(watchAll, child) end
    end)
end)

-- TextChatService
task.spawn(function()
    local ok, TCS = pcall(function() return game:GetService("TextChatService") end)
    if not ok or not TCS then return end
    local ok2, channels = pcall(function() return TCS:WaitForChild("TextChannels", 5) end)
    if not ok2 or not channels then return end
    local function hookCh(ch)
        pcall(function()
            ch.MessageReceived:Connect(function(msg)
                if msg and msg.Text and msg.Text ~= "" then task.spawn(dispatch, msg.Text) end
            end)
        end)
    end
    for _, ch in ipairs(channels:GetChildren()) do hookCh(ch) end
    channels.ChildAdded:Connect(hookCh)
end)

-- Legacy chat
pcall(function()
    local function hookPlr(plr)
        plr.Chatted:Connect(function(msg)
            if msg and msg ~= "" then task.spawn(dispatch, msg) end
        end)
    end
    for _, plr in ipairs(Players:GetPlayers()) do hookPlr(plr) end
    Players.PlayerAdded:Connect(hookPlr)
end)

-- ===================================================================
-- PILL
-- ===================================================================
local pillWidget = Instance.new("Frame", gui)
pillWidget.Name                   = "ScanPill"
pillWidget.Size                   = UDim2.new(0, 200, 0, 36)
pillWidget.Position               = UDim2.new(0.5, -100, 0, 35)
pillWidget.BackgroundTransparency = 1
pillWidget.Active                 = true

local pill = Instance.new("Frame", pillWidget)
pill.Size                   = UDim2.new(1,0,1,0)
pill.BackgroundColor3       = C_BG
pill.BackgroundTransparency = 0.1
pill.BorderSizePixel        = 0
addCorner(pill, 18); addStroke(pill, 1.5)

_pillLbl = Instance.new("TextLabel", pill)
_pillLbl.Size                   = UDim2.new(1,-16,1,0)
_pillLbl.Position               = UDim2.new(0,8,0,0)
_pillLbl.BackgroundTransparency = 1
_pillLbl.Text                   = "SCANNING"
_pillLbl.TextColor3             = C_WHITE
_pillLbl.Font                   = Enum.Font.GothamBlack
_pillLbl.TextSize               = 13
_pillLbl.TextXAlignment         = Enum.TextXAlignment.Center
_pillLbl.ZIndex                 = 5
addGrad(_pillLbl)

local pillBy = Instance.new("TextLabel", pillWidget)
pillBy.Size                   = UDim2.new(1,0,0,10)
pillBy.Position               = UDim2.new(0,0,1,3)
pillBy.BackgroundTransparency = 1
pillBy.Text                   = "by Yslem"
pillBy.TextColor3             = C_DIM
pillBy.Font                   = Enum.Font.Gotham
pillBy.TextSize               = 8
pillBy.TextXAlignment         = Enum.TextXAlignment.Center

-- ===================================================================
-- PANEL
-- ===================================================================
local PANEL_W   = 240
local TITLE_H   = 28
local TAB_H     = 26
local CONTENT_H = 200
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
addCorner(panel, 14); addStroke(panel, 1.5)

-- BG image
local bgImg = Instance.new("ImageLabel", panel)
bgImg.Size = UDim2.new(1,0,1,0); bgImg.BackgroundTransparency = 1
bgImg.Image = ""; bgImg.ScaleType = Enum.ScaleType.Crop; bgImg.ZIndex = 9
addCorner(bgImg, 14)
task.spawn(function()
    local fname = "yslem_bg_v3.png"
    local url   = "https://litter.catbox.moe/cya5902wkqpimu2c.png"
    if getcustomasset then
        if isfile and isfile(fname) then
            local rid = getcustomasset(fname)
            if rid and rid ~= "" then bgImg.Image = rid; return end
        end
        local ok, data = pcall(function() return game:HttpGet(url) end)
        if ok and data and data ~= "" then
            pcall(function() if writefile then writefile(fname, data) end end)
            local rid = getcustomasset(fname)
            if rid and rid ~= "" then bgImg.Image = rid end
        end
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
local minBtn = Instance.new("TextButton", panel)
minBtn.Size = UDim2.new(0,20,0,20); minBtn.Position = UDim2.new(1,-24,0,4)
minBtn.BackgroundTransparency = 1; minBtn.Text = "-"
minBtn.TextColor3 = C_WHITE; minBtn.Font = Enum.Font.GothamBlack
minBtn.TextSize = 16; minBtn.ZIndex = 15
addGrad(minBtn)

local titleLbl = Instance.new("TextLabel", panel)
titleLbl.Size = UDim2.new(1,-40,0,TITLE_H); titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "YSLEM AUTO CODE"
titleLbl.TextColor3 = C_WHITE; titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 13; titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.ZIndex = 15
addGrad(titleLbl)

local byLbl = Instance.new("TextLabel", panel)
byLbl.Size = UDim2.new(0,64,0,TITLE_H); byLbl.Position = UDim2.new(1,-88,0,0)
byLbl.BackgroundTransparency = 1; byLbl.Text = "by Yslem"
byLbl.TextColor3 = C_DIM; byLbl.Font = Enum.Font.Gotham
byLbl.TextSize = 9; byLbl.TextXAlignment = Enum.TextXAlignment.Right; byLbl.ZIndex = 15

-- ===================================================================
-- TAB BAR
-- ===================================================================
local tabBar = Instance.new("Frame", panel)
tabBar.Size = UDim2.new(1,-16,0,TAB_H); tabBar.Position = UDim2.new(0,8,0,TITLE_H)
tabBar.BackgroundTransparency = 1; tabBar.ZIndex = 12
local tbl = Instance.new("UIListLayout", tabBar)
tbl.FillDirection = Enum.FillDirection.Horizontal; tbl.Padding = UDim.new(0,4)
tbl.SortOrder = Enum.SortOrder.LayoutOrder
tbl.HorizontalAlignment = Enum.HorizontalAlignment.Left
tbl.VerticalAlignment   = Enum.VerticalAlignment.Center

local currentTab = math.max(1, math.min(2, cfg.activeTab or 1))
local function makeTab(label, order)
    local btn = Instance.new("TextButton", tabBar)
    btn.Size = UDim2.new(0,108,1,-4); btn.LayoutOrder = order
    btn.BackgroundColor3 = C_ROW; btn.BorderSizePixel = 0
    btn.AutoButtonColor = false; btn.Text = label
    btn.TextColor3 = C_DIM; btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10; btn.ZIndex = 13
    addCorner(btn, 6); addGrad(btn)
    return btn
end
local tabMain   = makeTab("Main",   1)
local tabStatus = makeTab("Status", 2)

-- ===================================================================
-- CONTENT
-- ===================================================================
local contentFrame = Instance.new("Frame", panel)
contentFrame.Size = UDim2.new(1,0,1,-(TITLE_H+TAB_H))
contentFrame.Position = UDim2.new(0,0,0,TITLE_H+TAB_H)
contentFrame.BackgroundTransparency = 1; contentFrame.ClipsDescendants = true; contentFrame.ZIndex = 11

-- ── PAGE 1: MAIN ────────────────────────────────────────────────────
local page1 = Instance.new("Frame", contentFrame)
page1.Size = UDim2.new(1,0,1,0); page1.BackgroundTransparency = 1; page1.ZIndex = 11

local function makeRow(parent, y, h)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1,-20,0,h or 24); f.Position = UDim2.new(0,10,0,y)
    f.BackgroundColor3 = C_ROW; f.BorderSizePixel = 0; f.ZIndex = 12
    addCorner(f, 8); addStroke(f, 1)
    return f
end

-- Code input
local codeBar = makeRow(page1, 6, 28)
_codeInput = Instance.new("TextBox", codeBar)
_codeInput.Size = UDim2.new(1,-16,1,0); _codeInput.Position = UDim2.new(0,8,0,0)
_codeInput.BackgroundTransparency = 1; _codeInput.BorderSizePixel = 0
_codeInput.PlaceholderText = "Auto-detect or type code..."
_codeInput.PlaceholderColor3 = C_DIM; _codeInput.Text = ""
_codeInput.TextColor3 = C_WHITE; _codeInput.Font = Enum.Font.GothamBold
_codeInput.TextSize = 11; _codeInput.TextXAlignment = Enum.TextXAlignment.Left
_codeInput.TextTruncate = Enum.TextTruncate.AtEnd
_codeInput.ClearTextOnFocus = false; _codeInput.ZIndex = 13
addGrad(_codeInput)

-- AUTO REDEEM toggle
local autoBtn = Instance.new("TextButton", page1)
autoBtn.Size = UDim2.new(1,-20,0,24); autoBtn.Position = UDim2.new(0,10,0,42)
autoBtn.BackgroundColor3 = autoCode and C_ON or C_BG
autoBtn.Text = autoCode and "AUTO REDEEM: ON" or "AUTO REDEEM: OFF"
autoBtn.TextColor3 = autoCode and C_WHITE or C_DIM
autoBtn.Font = Enum.Font.GothamBlack; autoBtn.TextSize = 11
autoBtn.BorderSizePixel = 0; autoBtn.AutoButtonColor = false; autoBtn.ZIndex = 12
addCorner(autoBtn, 8); addGrad(autoBtn)
autoBtn.MouseButton1Click:Connect(function()
    autoCode = not autoCode; cfg.autoCode = autoCode
    autoBtn.Text       = autoCode and "AUTO REDEEM: ON" or "AUTO REDEEM: OFF"
    autoBtn.TextColor3 = autoCode and C_WHITE or C_DIM
    TweenService:Create(autoBtn, TweenInfo.new(0.15), {BackgroundColor3 = autoCode and C_ON or C_BG}):Play()
    saveConfig()
end)

-- ENTER CODE button
local enterBtn = Instance.new("TextButton", page1)
enterBtn.Size = UDim2.new(1,-20,0,24); enterBtn.Position = UDim2.new(0,10,0,74)
enterBtn.BackgroundColor3 = C_ROW; enterBtn.Text = "ENTER CODE"
enterBtn.TextColor3 = C_WHITE; enterBtn.Font = Enum.Font.GothamBlack
enterBtn.TextSize = 11; enterBtn.BorderSizePixel = 0
enterBtn.AutoButtonColor = false; enterBtn.ZIndex = 12
addCorner(enterBtn, 8); addGrad(enterBtn)
enterBtn.MouseButton1Click:Connect(function()
    local code = (_codeInput and _codeInput.Text or ""):match("^%s*(.-)%s*$")
    if code == "" or code == "Nothing detected" then
        if _codeInput then
            _codeInput.Text       = "Nothing detected"
            _codeInput.TextColor3 = Color3.fromRGB(255, 80, 80)
            task.delay(1.5, function()
                if _codeInput and _codeInput.Text == "Nothing detected" then
                    _codeInput.Text       = lastCode
                    _codeInput.TextColor3 = lastCode ~= "" and C_WHITE or C_DIM
                end
            end)
        end
        return
    end
    task.spawn(redeemCode, code)
    TweenService:Create(enterBtn, TweenInfo.new(0.1), {BackgroundColor3 = C_ON}):Play()
    task.delay(0.2, function() TweenService:Create(enterBtn, TweenInfo.new(0.2), {BackgroundColor3 = C_ROW}):Play() end)
end)

-- Code parts row
local partsRow = makeRow(page1, 106, 24)
local partsLbl = Instance.new("TextLabel", partsRow)
partsLbl.Size = UDim2.new(0.55,0,1,0); partsLbl.Position = UDim2.new(0,8,0,0)
partsLbl.BackgroundTransparency = 1; partsLbl.Text = "Code parts:"
partsLbl.TextColor3 = C_DIM; partsLbl.Font = Enum.Font.Gotham
partsLbl.TextSize = 10; partsLbl.TextXAlignment = Enum.TextXAlignment.Left; partsLbl.ZIndex = 13

local function makeSmallBtn(parent, x, label)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0,22,0.8,0); btn.Position = UDim2.new(0.55,x,0.1,0)
    btn.BackgroundColor3 = C_BG; btn.Text = label; btn.TextColor3 = C_WHITE
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 14
    btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.ZIndex = 13
    addCorner(btn, 5); addGrad(btn)
    return btn
end
local partsMin  = makeSmallBtn(partsRow,  4, "-")
local partsPlus = makeSmallBtn(partsRow, 64, "+")
local partsVal  = Instance.new("TextLabel", partsRow)
partsVal.Size = UDim2.new(0,30,1,0); partsVal.Position = UDim2.new(0.55,30,0,0)
partsVal.BackgroundTransparency = 1
partsVal.Text       = captureCount == 0 and "off" or tostring(captureCount)
partsVal.TextColor3 = captureCount == 0 and C_DIM or C_WHITE
partsVal.Font = Enum.Font.GothamBold; partsVal.TextSize = 11
partsVal.TextXAlignment = Enum.TextXAlignment.Center; partsVal.ZIndex = 13
addGrad(partsVal)

local function refreshParts()
    partsVal.Text       = captureCount == 0 and "off" or tostring(captureCount)
    partsVal.TextColor3 = captureCount == 0 and C_DIM or C_WHITE
    cfg.captureCount    = captureCount
    collecting = false; collectBuf = {}; collectRemain = 0; setScanState("SCANNING")
    saveConfig()
end
partsMin.MouseButton1Click:Connect(function()
    if captureCount > 0 then captureCount = captureCount - 1; refreshParts() end
end)
partsPlus.MouseButton1Click:Connect(function()
    if captureCount < 10 then captureCount = captureCount + 1; refreshParts() end
end)

-- Redeem delay row
local redeemDelay = 0
local delayRow = makeRow(page1, 138, 24)
local delayLbl = Instance.new("TextLabel", delayRow)
delayLbl.Size = UDim2.new(0.65,0,1,0); delayLbl.Position = UDim2.new(0,8,0,0)
delayLbl.BackgroundTransparency = 1; delayLbl.Text = "Redeem delay (s):"
delayLbl.TextColor3 = C_DIM; delayLbl.Font = Enum.Font.Gotham
delayLbl.TextSize = 10; delayLbl.TextXAlignment = Enum.TextXAlignment.Left; delayLbl.ZIndex = 13
local delayBox = Instance.new("TextBox", delayRow)
delayBox.Size = UDim2.new(0.3,-4,0.8,0); delayBox.Position = UDim2.new(0.68,0,0.1,0)
delayBox.BackgroundColor3 = C_BG; delayBox.BorderSizePixel = 0
delayBox.Font = Enum.Font.GothamBold; delayBox.TextSize = 11
delayBox.TextColor3 = C_WHITE; delayBox.PlaceholderText = "0"
delayBox.PlaceholderColor3 = C_DIM; delayBox.TextXAlignment = Enum.TextXAlignment.Center
delayBox.ClearTextOnFocus = false; delayBox.Text = "0"; delayBox.ZIndex = 13
addCorner(delayBox, 5); addGrad(delayBox)
delayBox.FocusLost:Connect(function()
    local n = tonumber(delayBox.Text)
    if n and n >= 0 and n <= 30 then redeemDelay = n
    else delayBox.Text = tostring(redeemDelay) end
end)

-- ── PAGE 2: STATUS ───────────────────────────────────────────────────
local page2 = Instance.new("Frame", contentFrame)
page2.Size = UDim2.new(1,0,1,0); page2.BackgroundTransparency = 1
page2.Visible = false; page2.ZIndex = 11

local statusScroll = Instance.new("ScrollingFrame", page2)
statusScroll.Size = UDim2.new(1,-16,1,-36); statusScroll.Position = UDim2.new(0,8,0,6)
statusScroll.BackgroundColor3 = C_ROW; statusScroll.BackgroundTransparency = 0.4
statusScroll.BorderSizePixel = 0; statusScroll.ScrollBarThickness = 3
statusScroll.ScrollBarImageColor3 = G2; statusScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
statusScroll.CanvasSize = UDim2.new(0,0,0,0); statusScroll.ClipsDescendants = true; statusScroll.ZIndex = 12
addCorner(statusScroll, 8)
local sLayout = Instance.new("UIListLayout", statusScroll)
sLayout.Padding = UDim.new(0,2); sLayout.SortOrder = Enum.SortOrder.LayoutOrder
local sPad = Instance.new("UIPadding", statusScroll)
sPad.PaddingLeft = UDim.new(0,4); sPad.PaddingTop = UDim.new(0,4); sPad.PaddingBottom = UDim.new(0,4)

local _logOrder = 0
local function logStatus(msg)
    _logOrder = _logOrder + 1
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-8,0,0); lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Code
    lbl.TextSize = 9; lbl.TextColor3 = C_DIM
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextWrapped = true
    lbl.Text = msg; lbl.LayoutOrder = _logOrder; lbl.Parent = statusScroll
    task.defer(function() statusScroll.CanvasPosition = Vector2.new(0, math.huge) end)
end

local clearBtn = Instance.new("TextButton", page2)
clearBtn.Size = UDim2.new(1,-16,0,24); clearBtn.Position = UDim2.new(0,8,1,-28)
clearBtn.BackgroundColor3 = C_ROW; clearBtn.Text = "Clear log"
clearBtn.TextColor3 = C_DIM; clearBtn.Font = Enum.Font.Gotham
clearBtn.TextSize = 10; clearBtn.BorderSizePixel = 0; clearBtn.AutoButtonColor = false; clearBtn.ZIndex = 12
addCorner(clearBtn, 6)
clearBtn.MouseButton1Click:Connect(function()
    for _, c in ipairs(statusScroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
end)

-- Hook dispatch to log detected codes
local _origDispatch = dispatch
dispatch = function(text)
    -- (dispatch is local; rewrapping to add logging)
    _origDispatch(text)
end

-- Log redeems
local _origRedeem = redeemCode
redeemCode = function(code)
    logStatus("Redeem: " .. code)
    _origRedeem(code)
end

-- ===================================================================
-- TAB SWITCHING + MINIMIZE
-- ===================================================================
local function setTab(idx)
    currentTab = idx; cfg.activeTab = idx
    page1.Visible = (idx == 1); page2.Visible = (idx == 2)
    tabMain.BackgroundColor3   = (idx == 1) and C_ON or C_ROW
    tabStatus.BackgroundColor3 = (idx == 2) and C_ON or C_ROW
    tabMain.TextColor3   = (idx == 1) and C_WHITE or C_DIM
    tabStatus.TextColor3 = (idx == 2) and C_WHITE or C_DIM
    saveConfig()
end
setTab(currentTab)
tabMain.MouseButton1Click:Connect(function()   if currentTab ~= 1 then setTab(1) end end)
tabStatus.MouseButton1Click:Connect(function() if currentTab ~= 2 then setTab(2) end end)

local function applyMinimize(instant)
    local h = minimized and MINI_H or FULL_H
    tabBar.Visible = not minimized; contentFrame.Visible = not minimized
    minBtn.Text = minimized and "+" or "-"
    if instant then panel.Size = UDim2.new(0,PANEL_W,0,h)
    else TweenService:Create(panel, TweenInfo.new(0.15), {Size = UDim2.new(0,PANEL_W,0,h)}):Play() end
end
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized; cfg.minimized = minimized; applyMinimize(false); saveConfig()
end)
applyMinimize(true)

print("[YSLEM AUTO CODE] Loaded — by Yslem")
