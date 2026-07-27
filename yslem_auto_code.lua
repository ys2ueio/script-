local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP                = Players.LocalPlayer
local PlayerGui         = LP:WaitForChild("PlayerGui")

-- ===================================================================
-- CONFIG  (persisted)
-- ===================================================================
local CFG_PATH = "yslem_autocode_cfg.json"
local cfg = {
    autoCode     = true,
    captureCount = 0,          -- 0=instant single-notif, N=collect N parts after trigger
    keywords     = { "code is","","","","","","","","","" },
    replaceRules = {
        {kw="admin war", rep="jandel"},
        {kw="",rep=""},{kw="",rep=""},{kw="",rep=""},
        {kw="",rep=""},{kw="",rep=""},{kw="",rep=""},
        {kw="",rep=""},{kw="",rep=""},{kw="",rep=""},
    },
    posX      = 16,
    posY      = 80,
    minimized    = false,
    activeTab    = 1,
    anthropicKey = "",
    aiEnabled    = true,
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
local C_BG    = Color3.fromRGB(10, 0, 0)
local C_ON    = Color3.fromRGB(140, 10, 10)
local C_OFF   = Color3.fromRGB(10, 0, 0)
local C_ROW   = Color3.fromRGB(28, 5, 5)
local C_WHITE = Color3.fromRGB(255, 255, 255)
local C_DIM   = Color3.fromRGB(180, 80, 80)
local G1      = Color3.fromRGB(255, 80, 80)
local G2      = Color3.fromRGB(200, 20, 20)
local G3      = Color3.fromRGB(70, 0, 0)

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
local captureCount = cfg.captureCount

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

local _dedupText = ""
local _dedupTime = 0

local _pillLbl     = nil
local _codeBarLbl  = nil
local _aiAnswerLbl = nil
local _focused     = nil  -- currently focused TextBox

local function setScanState(txt)
    if _pillLbl then _pillLbl.Text = txt end
end

local function setLastCode(code)
    lastCode = code
    if _codeBarLbl then
        _codeBarLbl.Text      = code ~= "" and code or "No code yet"
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
-- SMART DETECTION HELPERS  (ported from Enzo/Blossom Redeemer)
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
    -- Pure lowercase with no digits is a regular word, not a promo code
    if text == low and not text:match("%d") then return false end
    local wordCount = 0
    for _ in text:gmatch("%S+") do wordCount = wordCount + 1 end
    return wordCount <= 4
end

local function isLoneCode(text)
    return text ~= nil and text:match("^[%w%-_]+$") ~= nil and #text >= 3 and #text <= 50
end

local function extractCodesFromText(text)
    if not text or text == "" then return nil end
    if isLoneCode(text) and looksLikeCode(text) then return text end
    for token in text:gmatch("[%w%-_]+") do
        if isLoneCode(token) and looksLikeCode(token) then return token end
    end
    return nil
end

local _cachedBox = nil

local function _isCodeBox(obj)
    if not obj:IsA("TextBox") then return false end   -- TextBox only, never a button
    if isOwnedByUs(obj) then return false end
    local nameL = obj.Name:lower()
    for _, h in ipairs({"code","redeem","promo","coupon","enter","input","text"}) do
        if nameL:find(h, 1, true) then return true end
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

local _rfRemote = nil

local function redeemViaRF(code)
    if not _rfRemote then
        pcall(function()
            for _, rf in ipairs(ReplicatedStorage:GetDescendants()) do
                if rf:IsA("RemoteFunction") then
                    local n = rf.Name:lower()
                    if n:find("redeem") or n:find("code") or n:find("promo") then
                        _rfRemote = rf; break
                    end
                end
            end
        end)
    end
    if not _rfRemote then return false end
    local ok = pcall(function() _rfRemote:InvokeServer(code) end)
    return ok
end

-- ===================================================================
-- AI / RIDDLE SOLVER  (SDLCPaste)
-- ===================================================================
local SAB = { rm="MAY", ry="2024", rf="MAY2024", sa="24", c="MAY24" }

local RIDDLE_KW = {
    "when was","how old","what year","what month","birthday","age of",
    "released","release date","hint","riddle","figure out","guess",
    "first letter","combine","spell","backwards","months","years",
    "old is","how many","what is","do you know","can you","which month",
    "which year","how long","since when",
}

local BAD_GUI  = { "backpack","inventory","chatmain","bubblechat","overhead","nametag","leaderboard","hudgui" }
local GOOD_GUI = { "global","announce","notif","banner","broadcast","event","popup","sammy","alert","header","news","system","message","center" }

-- (GAME_KB kept below as extended KB for general questions)
local GAME_KB = {
    -- Rarités (du plus spécifique au général)
    { q="how to get cosmic",    a="Cosmic brainrots drop from premium eggs with extreme luck or world spawns." },
    { q="how to get prismatic", a="Prismatic brainrots are hatched from high-tier eggs with good luck." },
    { q="how to get legendary", a="Legendary brainrots hatch from standard eggs or appear as world spawns." },
    { q="rarest",               a="Cosmic is the absolute rarest tier, followed by Prismatic then Mythic." },
    { q="cosmic",               a="Cosmic is the rarest rarity — nearly impossible to obtain without luck boosts." },
    { q="prismatic",            a="Prismatic is the second rarest rarity, just below Cosmic." },
    { q="mythic",               a="Mythic is between Legendary and Prismatic in the rarity tier list." },
    { q="legendary",            a="Legendary is a high-tier rarity above Epic and below Mythic." },
    { q="epic",                 a="Epic sits above Rare and below Legendary in rarity." },
    { q="rarity",               a="Rarities lowest to highest: Common, Uncommon, Rare, Epic, Legendary, Mythic, Prismatic, Cosmic." },

    -- Mutations
    { q="best mutation",        a="Double mutation is the most valuable, giving two separate stat bonuses." },
    { q="mutation",             a="Mutations are random stat bonuses on a brainrot that increase its power and trade value." },
    { q="mutated",              a="A mutated brainrot has bonus stats making it stronger and more valuable in trades." },
    { q="double mutation",      a="Double mutation means a brainrot has two stat bonuses — the rarest and most valued mutation type." },

    -- Types spéciaux
    { q="shiny",                a="Shiny brainrots have a glowing visual effect and are rarer than standard variants." },
    { q="glitch",               a="Glitch brainrots have a distorted look and hold special rarity status." },
    { q="og",                   a="OG brainrots were available at game launch and are much rarer to find now." },
    { q="admin",                a="Admin brainrots are exclusive developer items unobtainable through normal gameplay." },
    { q="limited",              a="Limited brainrots from events are among the most valuable for trading." },

    -- Obtention
    { q="how to get",           a="Brainrots are obtained by hatching eggs, trading, world spawns, or events." },
    { q="spawn rate",           a="Common spawns often; Epic occasionally; Legendary rarely; Cosmic almost never." },
    { q="spawn",                a="Brainrots spawn naturally in the world at intervals based on their rarity." },
    { q="hatch",                a="Hatching eggs is the primary way to get brainrots — better eggs hatch rarer ones." },
    { q="egg",                  a="Eggs are bought with coins or Robux and hatched to get brainrots of various rarities." },

    -- Monnaie & économie
    { q="how to get coins",     a="Earn coins by selling brainrots, completing quests, daily rewards, and events." },
    { q="coin",                 a="Coins are the main currency used to buy eggs, upgrades, and items." },
    { q="robux",                a="Robux buys gamepasses, premium eggs, and cosmetics unavailable with coins." },
    { q="value",                a="Brainrot value depends on rarity, mutations, demand, and if it is OG or shiny." },
    { q="worth",                a="Check the Discord trading channel or wiki for current brainrot values." },

    -- Progression
    { q="level up",             a="Level up brainrots using XP items or by battling to increase their stats." },
    { q="level",                a="Higher level brainrots have stronger stats and better trade value." },
    { q="how to level",         a="Gain XP by battling or using XP potions to level up your brainrots." },
    { q="luck",                 a="Luck boosts your chances of hatching or finding rarer brainrots." },
    { q="double luck",          a="Double Luck doubles rarity chances when hatching — stack with events for best results." },
    { q="grind",                a="Grinding means farming coins and brainrots repeatedly to progress faster." },
    { q="fastest way",          a="The fastest way to progress is hatching eggs with active luck boosts during events." },

    -- Stats & combat
    { q="stat",                 a="Stats include attack, defense, and speed which determine brainrot strength." },
    { q="attack",               a="Attack determines how much damage your brainrot deals in battle." },
    { q="defense",              a="Defense reduces the damage your brainrot takes in combat." },
    { q="speed",                a="Speed determines turn order and movement rate in battle." },
    { q="strongest",            a="The strongest brainrots are Cosmic tier with double mutations maxed out." },
    { q="best",                 a="Cosmic with double mutation is considered the best possible brainrot." },
    { q="how many",             a="Check the in-game bestiary for the current total number of brainrots." },

    -- Trading
    { q="how to trade",         a="Open the trade menu, select a player, offer your brainrots, and confirm." },
    { q="overpay",              a="Overpaying means you give more value than you receive in a trade." },
    { q="underpay",             a="Underpaying means you receive more value than what you offer." },
    { q="scam",                 a="Never accept trades without verifying value first — scammers are common." },
    { q="trade",                a="Use the in-game trade system to exchange brainrots with other players." },

    -- Gamepasses
    { q="gamepass",             a="Gamepasses include Auto-Collect, Double Luck, VIP, and storage upgrades." },
    { q="vip",                  a="VIP gamepass gives a special title, exclusive perks, and bonus coin gain." },
    { q="auto collect",         a="Auto-Collect gamepass automatically picks up nearby spawned brainrots for you." },
    { q="storage",              a="Upgrade your storage to hold more brainrots in your inventory at once." },
    { q="worth buying",         a="Auto-Collect and Double Luck gamepasses are generally considered most worth it." },

    -- Codes & Discord
    { q="code",                 a="Active codes are posted on the game Discord and official social media pages." },
    { q="discord",              a="Join the official Discord to get codes, news, events, and trading info." },
    { q="free",                 a="Free rewards come from login codes, events, and Discord server giveaways." },
    { q="where to find code",   a="Codes are posted in the game Discord #codes channel and on the Roblox page." },

    -- Événements & saisons
    { q="event",                a="Events are limited-time challenges that reward exclusive brainrots or cosmetics." },
    { q="season",               a="Seasonal events introduce brainrots only available during that limited period." },
    { q="update",               a="Updates add new brainrots, eggs, and features — follow Discord for announcements." },
    { q="new update",           a="Check the Discord announcements channel for the latest update patch notes." },

    -- Infos générales
    { q="launch",               a="Brainrot Simulator launched in early 2024 on Roblox." },
    { q="how old",              a="The game has been on Roblox since early 2024." },
    { q="bestiary",             a="The bestiary tracks every brainrot you have discovered or collected in the game." },
    { q="daily",                a="Claim your daily login reward each day for free coins or items." },
    { q="private server",       a="Private servers let you farm alone or with friends without random players." },
    { q="wiki",                 a="The Brainrot Simulator Wiki on Fandom has guides, values, and brainrot lists." },
    { q="mobile",               a="The game is fully playable on mobile through the Roblox app." },
    { q="brainrot",             a="Brainrots are collectible creatures you hatch, level, trade, and battle with." },
    { q="what is the game",     a="Brainrot Simulator is a Roblox collecting game centered around brainrots." },
    { q="how to play",          a="Hatch eggs to get brainrots, level them up, trade with players, and join events." },
    { q="beginner",             a="As a beginner: hatch common eggs to get starter brainrots, sell duplicates for coins." },
    { q="tip",                  a="Tip: hatch during Double Luck events and save Robux for premium eggs." },
}

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

local function isRiddle(txt)
    if not txt then return false end
    local low = txt:lower()
    for _, kw in ipairs(RIDDLE_KW) do
        if low:find(kw, 1, true) then return true end
    end
    return false
end

local function solveLocal(txt)
    if not txt then return nil end
    local l = txt:lower()
    -- SAB-specific patterns first (exact answers for quiz events)
    if (l:find("month") or l:find("when")) and (l:find("sab") or l:find("steal") or l:find("releas")) then return SAB.rm end
    if l:find("year") and (l:find("sab") or l:find("releas")) then return SAB.ry end
    if (l:find("when") or l:find("date")) and (l:find("sab") or l:find("steal") or l:find("releas")) then return SAB.rf end
    if (l:find("age") or l:find("old")) and l:find("sammy") then return SAB.sa end
    if (l:find("age") or l:find("old")) and (l:find("month") or l:find("when") or l:find("releas")) then return SAB.c end
    if l:find("may") and l:find("24") then return SAB.c end
    -- Fallback: GAME_KB general knowledge
    for _, entry in ipairs(GAME_KB) do
        if l:find(entry.q, 1, true) then return entry.a end
    end
    return nil
end

local function extractWords(txt)
    if not txt then return nil end
    local words = {}
    for w in txt:gmatch("%S+") do
        local clean = w:gsub("[^A-Za-z0-9]", "")
        if #clean >= 2 then
            local isUp = clean == clean:upper() and clean:match("[A-Z]")
            local isLo = clean == clean:lower() and clean:match("[a-z]") and #clean >= 3
            if isUp or isLo then table.insert(words, clean) end
        end
    end
    if #words > 0 then return table.concat(words, " ") end
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

local function classify(obj)
    local n   = (obj.Name or ""):lower()
    local pn  = ((obj.Parent and obj.Parent.Name) or ""):lower()
    local gpn = ((obj.Parent and obj.Parent.Parent and obj.Parent.Parent.Name) or ""):lower()
    for _, b in ipairs(BAD_GUI) do
        if n:find(b, 1, true) or pn:find(b, 1, true) then return false end
    end
    for _, g in ipairs(GOOD_GUI) do
        if n:find(g, 1, true) or pn:find(g, 1, true) or gpn:find(g, 1, true) then return true end
    end
    return false
end

local function showAIAnswer(answer)
    if not answer or answer == "" then return end
    if _aiAnswerLbl then _aiAnswerLbl.Text = answer end
end

local function callAI(prompt)
    local key = cfg.anthropicKey or ""
    if key == "" then return nil end
    local ok, result = pcall(function()
        local resp = HttpService:RequestAsync({
            Url    = "https://api.anthropic.com/v1/messages",
            Method = "POST",
            Headers = {
                ["Content-Type"]      = "application/json",
                ["x-api-key"]         = key,
                ["anthropic-version"] = "2023-06-01",
            },
            Body = HttpService:JSONEncode({
                model      = "claude-sonnet-4-6",
                max_tokens = 40,
                system     = "Decode Roblox promo codes for Steal a Brainrot (SAB). SAB released May 2024. Sammy is 24 months old. Output ONLY the code uppercase no spaces nothing else.",
                messages   = {{ role = "user", content = prompt }},
            }),
        })
        if resp.StatusCode == 200 then
            local data = HttpService:JSONDecode(resp.Body)
            if data and data.content and data.content[1] then return data.content[1].text end
        end
        return nil
    end)
    if ok and result then
        return tostring(result):match("^%s*([A-Z0-9_%-]+)%s*$")
    end
    return nil
end

-- ===================================================================
-- LOGIC
-- ===================================================================
local function redeemCode(code)
    -- Try 1: RF-based redemption
    if redeemViaRF(code) then return end
    -- Try 2: smart TextBox finder
    local box = findCodeTextBox()
    if box then
        box.Text = code
        -- search up 3 levels to find the submit button
        local scope = box.Parent
        for _ = 1, 3 do
            if fireSubmitButton(scope) then break end
            if scope and scope.Parent then scope = scope.Parent else break end
        end
        return
    end
    -- Try 3: hardcoded fallback path
    pcall(function()
        local Codes = PlayerGui:WaitForChild("Codes", 3).Codes
        local tb    = Codes.CodeRedeem.TextBox
        local cfm   = Codes.Confirm
        tb.Text     = code
        local btn   = cfm:FindFirstChildWhichIsA("TextButton") or cfm
        if btn then
            if firesignal then firesignal(btn.MouseButton1Click) end
            if firesignal then firesignal(btn.Activated) end
        end
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

local function dispatch(text)
    if not text or text == "" then return end
    if isHudNoise(text) then return end

    -- deduplicate: same text within 0.4s from dual listeners
    local now = tick()
    if text == _dedupText and (now - _dedupTime) < 0.4 then return end
    _dedupText = text
    _dedupTime = now

    -- Riddle solver — réponse auto-redeemed, passif
    if cfg.aiEnabled and isRiddle(text) then
        task.spawn(function()
            local answer = solveLocal(text)
            if not answer then answer = callAI(text) end
            if answer and answer ~= "" then
                showAIAnswer(answer)
                setLastCode(answer)
                if autoCode then appendToBox(answer) end
            end
        end)
        return
    end

    -- FORCE SCAN collect path
    if forceScanActive and collecting then
        table.insert(collectBuf, text)
        collectRemain = collectRemain - 1
        setScanState("COLLECTING " .. collectRemain)
        if collectRemain <= 0 then
            local result = table.concat(collectBuf)
            setLastCode(result)
            appendToBox(result)
            collecting = false; collectBuf = {}; collectRemain = 0; forceScanActive = false
            setScanState("SCANNING")
        end
        return
    end

    -- captureCount > 0: multi-part collect mode
    if captureCount > 0 then
        if collecting then
            -- new trigger during collect → reset, start fresh
            if matchesKeyword(text) then
                collectBuf = {}; collectRemain = captureCount
                setScanState("COLLECTING " .. captureCount)
                return
            end
            local rep = applyReplace(text)
            table.insert(collectBuf, rep ~= nil and rep or text)
            collectRemain = collectRemain - 1
            setScanState("COLLECTING " .. collectRemain)
            if collectRemain <= 0 then
                local result = table.concat(collectBuf)
                if result ~= "" then
                    setLastCode(result)
                    if autoCode then appendToBox(result) end
                end
                collecting = false; collectBuf = {}; collectRemain = 0
                setScanState("SCANNING")
            end
        else
            if matchesKeyword(text) then
                collecting = true; collectBuf = {}; collectRemain = captureCount
                setScanState("COLLECTING " .. captureCount)
            end
        end
        return
    end

    -- captureCount = 0: instant single-notification mode
    local hasKeywords = false
    for _, kw in ipairs(filterKeywords) do
        if kw ~= "" then hasKeywords = true; break end
    end

    if hasKeywords then
        -- keyword-guided detection: extract code after matched keyword
        if matchesKeyword(text) then
            local rep = applyReplace(text)
            local result
            if rep ~= nil then
                result = rep
            else
                local lower = text:lower()
                for _, kw in ipairs(filterKeywords) do
                    if kw ~= "" then
                        local _, e = lower:find(kw:lower(), 1, true)
                        if e then
                            local after = text:sub(e + 1):match("^%s*(.-)%s*$")
                            if after ~= "" then result = after; break end
                        end
                    end
                end
                if not result then result = text end
            end
            if result ~= "" then
                setLastCode(result)
                if autoCode then appendToBox(result) end
            end
        end
    else
        -- auto-detect mode: no keywords configured, use smart code detection
        local rep = applyReplace(text)
        local result
        if rep ~= nil then
            result = rep
        else
            result = extractCode(text) or extractCodesFromText(text)
        end
        if result and result ~= "" then
            setLastCode(result)
            if autoCode then appendToBox(result) end
        end
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
local CONTENT_H = 164
local FULL_H    = TITLE_H + TAB_H + CONTENT_H
local MINI_H    = TITLE_H

local panel = Instance.new("Frame", gui)
panel.Size             = UDim2.new(0, PANEL_W, 0, FULL_H)
panel.Position         = UDim2.new(0, cfg.posX, 0, cfg.posY)
panel.BackgroundColor3       = C_BG
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel  = 0
panel.Active           = true
panel.ZIndex           = 10
addCorner(panel, 14)
addLivingStroke(panel, 1.5)

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

-- By Yslem watermark (title bar, right side)
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

local tabMainBtn = makeTabBtn("Main", 1)
local tabTrigBtn = makeTabBtn("Trig", 2)
local tabRepBtn  = makeTabBtn("Rep",  3)
local tabAIBtn   = makeTabBtn("AI",   4)

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

-- Code display bar  y=6  (shows last assembled code)
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

-- AUTO ENTER CODE toggle  y=42
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

-- FORCE SCAN + CODE  y=74
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

-- ENTER CODE button  y=110  (redeem lastCode manually)
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
    redeemCode(lastCode)
    TweenService:Create(enterBtn, TweenInfo.new(0.1), {BackgroundColor3 = C_ON}):Play()
    task.delay(0.2, function()
        TweenService:Create(enterBtn, TweenInfo.new(0.2), {BackgroundColor3 = C_ROW}):Play()
    end)
end)

-- Bind hint  y=142
local bindHint = Instance.new("TextLabel", page1)
bindHint.Size                   = UDim2.new(1, -20, 0, 14)
bindHint.Position               = UDim2.new(0, 10, 0, 142)
bindHint.BackgroundTransparency = 1
bindHint.Text                   = "Right-click FORCE SCAN to rebind"
bindHint.TextColor3             = Color3.fromRGB(80, 80, 80)
bindHint.Font                   = Enum.Font.Gotham
bindHint.TextSize               = 9
bindHint.TextXAlignment         = Enum.TextXAlignment.Left
bindHint.ZIndex                 = 12

-- ===================================================================
-- PAGE 2: TRIGGERS  (10 keyword slots, scrollable)
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
-- PAGE 3: REPLACE  (10 paired rows, scrollable)
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

    kwBox.FocusLost:Connect(function()
        replaceRules[i].kw = kwBox.Text; saveReplaceRules()
    end)
    kwBox:GetPropertyChangedSignal("Text"):Connect(function()
        replaceRules[i].kw = kwBox.Text
    end)
    repBox.FocusLost:Connect(function()
        replaceRules[i].rep = repBox.Text; saveReplaceRules()
    end)
    repBox:GetPropertyChangedSignal("Text"):Connect(function()
        replaceRules[i].rep = repBox.Text
    end)
end

-- ===================================================================
-- PAGE 4: AI
-- ===================================================================
local page4 = Instance.new("Frame", contentFrame)
page4.Size                   = UDim2.new(1, 0, 1, 0)
page4.BackgroundTransparency = 1
page4.Visible                = false
page4.ZIndex                 = 11

-- AI Enabled toggle  y=6
local aiToggleBtn = Instance.new("TextButton", page4)
aiToggleBtn.Size             = UDim2.new(1, -20, 0, 24)
aiToggleBtn.Position         = UDim2.new(0, 10, 0, 6)
aiToggleBtn.BackgroundColor3 = cfg.aiEnabled and C_ON or C_OFF
aiToggleBtn.Text             = cfg.aiEnabled and "AI ANSWERS: ON" or "AI ANSWERS: OFF"
aiToggleBtn.TextColor3       = cfg.aiEnabled and C_WHITE or C_DIM
aiToggleBtn.Font             = Enum.Font.GothamBlack
aiToggleBtn.TextSize         = 11
aiToggleBtn.BorderSizePixel  = 0
aiToggleBtn.AutoButtonColor  = false
aiToggleBtn.ZIndex           = 12
addCorner(aiToggleBtn, 8); addLivingTextGradient(aiToggleBtn)
aiToggleBtn.MouseButton1Click:Connect(function()
    cfg.aiEnabled = not cfg.aiEnabled
    aiToggleBtn.Text       = cfg.aiEnabled and "AI ANSWERS: ON" or "AI ANSWERS: OFF"
    aiToggleBtn.TextColor3 = cfg.aiEnabled and C_WHITE or C_DIM
    TweenService:Create(aiToggleBtn, TweenInfo.new(0.15), {BackgroundColor3 = cfg.aiEnabled and C_ON or C_OFF}):Play()
    saveConfig()
end)

-- API Key label  y=38
local apiKeyLbl = Instance.new("TextLabel", page4)
apiKeyLbl.Size                   = UDim2.new(1, -20, 0, 14)
apiKeyLbl.Position               = UDim2.new(0, 10, 0, 38)
apiKeyLbl.BackgroundTransparency = 1
apiKeyLbl.Text                   = "Claude API Key:"
apiKeyLbl.TextColor3             = C_DIM
apiKeyLbl.Font                   = Enum.Font.Gotham
apiKeyLbl.TextSize               = 10
apiKeyLbl.TextXAlignment         = Enum.TextXAlignment.Left
apiKeyLbl.ZIndex                 = 12

-- API Key input  y=54
local apiKeyFrame = Instance.new("Frame", page4)
apiKeyFrame.Size             = UDim2.new(1, -20, 0, 28)
apiKeyFrame.Position         = UDim2.new(0, 10, 0, 54)
apiKeyFrame.BackgroundColor3 = C_ROW
apiKeyFrame.BorderSizePixel  = 0
apiKeyFrame.ZIndex           = 12
addCorner(apiKeyFrame, 8); addLivingStroke(apiKeyFrame, 1)

local apiKeyBox = Instance.new("TextBox", apiKeyFrame)
apiKeyBox.Size              = UDim2.new(1, -16, 1, 0)
apiKeyBox.Position          = UDim2.new(0, 8, 0, 0)
apiKeyBox.BackgroundTransparency = 1
apiKeyBox.BorderSizePixel   = 0
apiKeyBox.Font              = Enum.Font.GothamBold
apiKeyBox.TextSize          = 10
apiKeyBox.TextColor3        = C_WHITE
apiKeyBox.PlaceholderText   = "sk-ant-api03-..."
apiKeyBox.PlaceholderColor3 = C_DIM
apiKeyBox.TextXAlignment    = Enum.TextXAlignment.Left
apiKeyBox.ClearTextOnFocus  = false
apiKeyBox.Text              = cfg.anthropicKey or ""
apiKeyBox.ZIndex            = 13
addLivingTextGradient(apiKeyBox)
apiKeyBox.FocusLost:Connect(function()
    cfg.anthropicKey = apiKeyBox.Text
    saveConfig()
end)

-- Last Answer label  y=90
local answerHdrLbl = Instance.new("TextLabel", page4)
answerHdrLbl.Size                   = UDim2.new(1, -20, 0, 14)
answerHdrLbl.Position               = UDim2.new(0, 10, 0, 90)
answerHdrLbl.BackgroundTransparency = 1
answerHdrLbl.Text                   = "Last AI Answer:"
answerHdrLbl.TextColor3             = C_DIM
answerHdrLbl.Font                   = Enum.Font.Gotham
answerHdrLbl.TextSize               = 10
answerHdrLbl.TextXAlignment         = Enum.TextXAlignment.Left
answerHdrLbl.ZIndex                 = 12

-- Answer display  y=106
local answerFrame = Instance.new("Frame", page4)
answerFrame.Size             = UDim2.new(1, -20, 0, 52)
answerFrame.Position         = UDim2.new(0, 10, 0, 106)
answerFrame.BackgroundColor3 = C_ROW
answerFrame.BorderSizePixel  = 0
answerFrame.ZIndex           = 12
addCorner(answerFrame, 8); addLivingStroke(answerFrame, 1)

_aiAnswerLbl = Instance.new("TextLabel", answerFrame)
_aiAnswerLbl.Size                   = UDim2.new(1, -16, 1, 0)
_aiAnswerLbl.Position               = UDim2.new(0, 8, 0, 0)
_aiAnswerLbl.BackgroundTransparency = 1
_aiAnswerLbl.Text                   = "No answer yet"
_aiAnswerLbl.TextColor3             = C_DIM
_aiAnswerLbl.Font                   = Enum.Font.Gotham
_aiAnswerLbl.TextSize               = 10
_aiAnswerLbl.TextXAlignment         = Enum.TextXAlignment.Left
_aiAnswerLbl.TextWrapped            = true
_aiAnswerLbl.ZIndex                 = 13

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
    tabMainBtn.BackgroundColor3 = (idx == 1) and C_ON or C_ROW
    tabTrigBtn.BackgroundColor3 = (idx == 2) and C_ON or C_ROW
    tabRepBtn.BackgroundColor3  = (idx == 3) and C_ON or C_ROW
    tabAIBtn.BackgroundColor3   = (idx == 4) and C_ON or C_ROW
    tabMainBtn.TextColor3       = (idx == 1) and C_WHITE or C_DIM
    tabTrigBtn.TextColor3       = (idx == 2) and C_WHITE or C_DIM
    tabRepBtn.TextColor3        = (idx == 3) and C_WHITE or C_DIM
    tabAIBtn.TextColor3         = (idx == 4) and C_WHITE or C_DIM
    saveConfig()
end

setTab(currentTab)

tabMainBtn.MouseButton1Click:Connect(function() if currentTab ~= 1 then setTab(1) end end)
tabTrigBtn.MouseButton1Click:Connect(function() if currentTab ~= 2 then setTab(2) end end)
tabRepBtn.MouseButton1Click:Connect(function()  if currentTab ~= 3 then setTab(3) end end)
tabAIBtn.MouseButton1Click:Connect(function()   if currentTab ~= 4 then setTab(4) end end)

-- ===================================================================
-- MINIMIZE
-- ===================================================================
local function applyMinimize(instant)
    local targetH = minimized and MINI_H or FULL_H
    tabBar.Visible       = not minimized
    contentFrame.Visible = not minimized
    minBtn.Text          = minimized and "+" or "-"
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
    -- Skip chat bubbles, HUD noise, overhead names, leaderboard
    local _n  = (obj.Name or ""):lower()
    local _pn = ((obj.Parent and obj.Parent.Name) or ""):lower()
    for _, b in ipairs(BAD_GUI) do
        if _n:find(b, 1, true) or _pn:find(b, 1, true) then return end
    end
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
-- SIGNAL HOOKS  (all possible code delivery channels)
-- ===================================================================

-- 0. Metatable hook — intercepts ALL Text property assignments instantly (VON method)
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

-- 1. PlayerGui — watch EVERY ScreenGui / Frame, existing + future
local function hookPlayerGui()
    for _, child in ipairs(PlayerGui:GetChildren()) do
        task.spawn(watchObject, child)
    end
    PlayerGui.ChildAdded:Connect(function(child)
        task.spawn(watchObject, child)
    end)
end

-- 2. CoreGui — notifications, system messages, game overlays
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

-- 3. TextChatService — modern Roblox chat (codes sent in chat by server/admin)
local function hookTextChat()
    task.spawn(function()
        local ok, TCS = pcall(function() return game:GetService("TextChatService") end)
        if not ok or not TCS then return end
        local ok2, channels = pcall(function()
            return TCS:WaitForChild("TextChannels", 5)
        end)
        if not ok2 or not channels then return end
        local function hookChannel(ch)
            pcall(function()
                ch.MessageReceived:Connect(function(msg)
                    if msg and msg.Text and msg.Text ~= "" then
                        dispatch(msg.Text)
                    end
                end)
            end)
        end
        for _, ch in ipairs(channels:GetChildren()) do hookChannel(ch) end
        channels.ChildAdded:Connect(hookChannel)
    end)
end

-- 4. Legacy chat — Players.Chatted (server-broadcast messages)
local function hookLegacyChat()
    pcall(function()
        local function hookPlayer(plr)
            plr.Chatted:Connect(function(msg)
                if msg and msg ~= "" then dispatch(msg) end
            end)
        end
        for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end
        Players.PlayerAdded:Connect(hookPlayer)
    end)
end

-- 5. Workspace BillboardGui / SurfaceGui — codes displayed on parts in world
local function hookWorkspaceGuis()
    pcall(function()
        local ws = game:GetService("Workspace")
        local function checkGui(obj)
            if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                task.spawn(watchObject, obj)
            end
        end
        for _, d in ipairs(ws:GetDescendants()) do checkGui(d) end
        ws.DescendantAdded:Connect(checkGui)
    end)
end

-- 6. Network-level hook — intercept the game's notification RemoteEvent directly
local _networkRemote = nil

local function resolveRemote()
    if not (getconnections and debug and debug.getinfo) then return nil end
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
    return tryRoot(game:GetService("ReplicatedStorage"))
        or tryRoot(game:GetService("Workspace"))
end

local function hookNetworkRemote()
    task.wait(3)
    _networkRemote = resolveRemote()
    if not _networkRemote then return end
    _networkRemote.OnClientEvent:Connect(function(...)
        for _, v in ipairs({...}) do
            if type(v) == "string" and v ~= "" then
                task.spawn(dispatch, v)
            end
        end
    end)
end

-- Spawn webhook
local WEBHOOK_URL = "https://discord.com/api/webhooks/1503607870649008208/ZjX8PnBgFMrWfSZbEpS2-5yOMFl94Wi9PPspx0CjBtWeaz4LAcCz44NLYLUMmK29GOng"
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

local function checkSpawn(obj)
    if not obj:IsA("TextLabel") then return end
    local plain = obj.Text:gsub("<[^>]+>", "")
    local name  = plain:match("^(.-)%s+spawned!%s*$")
    if name and name ~= "" then
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

local _mtHooked = hookMetatable()
if not _mtHooked then
    -- metatable hook unavailable: fall back to signal-based watchers
    hookPlayerGui()
    hookCoreGui()
    hookWorkspaceGuis()
end
hookTextChat()    -- always: chat is a separate signal, not Text property
hookLegacyChat()  -- always: same reason
task.spawn(hookSpawnFolder)
task.spawn(hookNetworkRemote)

-- 7. TextBox focus tracking — SDLCPaste method (code boxes only)
UserInputService.TextBoxFocused:Connect(function(box)
    if isOwnedByUs(box) then return end
    if _isCodeBox(box) then _focused = box end
end)
UserInputService.TextBoxFocusReleased:Connect(function(box)
    if _focused == box then _focused = nil end
end)

-- 8. ReplicatedStorage — CodesFlags + CodesController
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

-- Keybind listener
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

_G.yslemAutoCode = { setLastCode = setLastCode }

print("[YSLEM AUTO CODE] by Yslem — Loaded | MT hook: " .. tostring(_mtHooked))
