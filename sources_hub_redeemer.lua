-- [[ DEOBFUSCATED BY @Casual ]] --

-- // [1] SERVICES //
local cloneref = cloneref or function(o) return o end
local Players           = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService        = cloneref(game:GetService("RunService"))
local UserInputService  = cloneref(game:GetService("UserInputService"))
local HttpService       = cloneref(game:GetService("HttpService"))
local CoreGui           = cloneref(game:GetService("CoreGui"))
local TweenService      = cloneref(game:GetService("TweenService"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

if getgenv and getgenv().StopAura then
    pcall(getgenv().StopAura)
end

-- // [2] CONFIGURATION //
local CONFIG = {
    Names = {
        ScreenGui    = "SourcesHubRedeemerGui",
        MainFrame    = "MainFrame",
        TopBar       = "TopBar",
        Title        = "Title",
        Subtitle     = "Subtitle",
        StatusDot    = "StatusDot",
        ScanButton   = "ScanButton",
        ModeButton   = "ModeButton",
        PreviewBox   = "PreviewBox",
        RedeemButton = "RedeemButton",
        BottomRow    = "BottomRow",
        DelayLabel   = "DelayLabel",
        DelayBox     = "DelayBox",
        SetButton    = "SetButton",
    },

    Size = {
        MainFrame    = UDim2.new(0, 300, 0, 205),
        TopBar       = UDim2.new(1, 0, 0, 44),
        ScanButton   = UDim2.new(1, -24, 0, 30),
        ModeButton   = UDim2.new(1, -24, 0, 30),
        PreviewBox   = UDim2.new(1, -102, 0, 30),
        RedeemButton = UDim2.new(0, 70, 0, 30),
        BottomRow    = UDim2.new(1, -24, 0, 30),
        DelayBox     = UDim2.new(0, 48, 1, 0),
        SetButton    = UDim2.new(0, 70, 1, 0),
        StatusDot    = UDim2.new(0, 10, 0, 10),
    },

    Position = {
        MainFrame    = UDim2.new(0.5, -90, 0.5, -153),
        TopBar       = UDim2.new(0, 0, 0, 0),
        Title        = UDim2.new(0, 12, 0, 8),
        Subtitle     = UDim2.new(0, 12, 0, 25),
        StatusDot    = UDim2.new(1, -18, 0, 17),
        ScanButton   = UDim2.new(0, 12, 0, 52),
        ModeButton   = UDim2.new(0, 12, 0, 88),
        PreviewBox   = UDim2.new(0, 12, 0, 126),
        RedeemButton = UDim2.new(1, -82, 0, 126),
        BottomRow    = UDim2.new(0, 12, 0, 162),
        DelayLabel   = UDim2.new(0, 10, 0, 0),
        DelayBox     = UDim2.new(0, 62, 0, 0),
        SetButton    = UDim2.new(1, -70, 0, 0),
    },

    Colors = {
        MainFrameBg  = Color3.fromRGB(245, 245, 248),
        TopBarBg     = Color3.fromRGB(255, 255, 255),
        ButtonBg     = Color3.fromRGB(255, 255, 255),
        TextDark     = Color3.fromRGB(80, 10, 15),
        TextMuted    = Color3.fromRGB(90, 95, 105),
        TextSubtitle = Color3.fromRGB(120, 30, 35),
        TextInput    = Color3.fromRGB(40, 45, 55),
        Placeholder  = Color3.fromRGB(130, 135, 145),
        StatusOff    = Color3.fromRGB(220, 40, 50),
        StatusOn     = Color3.fromRGB(40, 200, 80),
        Stroke       = Color3.fromRGB(255, 255, 255),
        Accent       = Color3.fromRGB(90, 12, 18),
    },

    Transparency = {
        MainFrame = 0.1,
        TopBar    = 0.4,
        Button    = 0.35,
        Image     = 0.85,
    },

    CornerRadius = {
        Main   = UDim.new(0, 16),
        Button = UDim.new(0, 10),
        Dot    = UDim.new(1, 0),
    },

    Texts = {
        Title       = "SOURCES HUB REDEEMER",
        Subtitle    = "discord.gg/sourceshubs",
        ScanStart   = "START SCAN",
        ScanActive  = "SCANNING....",
        ModePrefix  = "MODE: ",
        Redeem      = "REDEEM",
        Set         = "SET",
        DelayLabel  = "Delay:",
        Placeholder = "Captured code...",
    },

    Image = {
        MainFrame = "rbxassetid://93857225029776",
    },

    Defaults = {
        Delay         = 0.5,
        ModeIndex     = 1,
        SubmitAfter   = 3,
        Enabled       = false,
        AutoSubmit    = true,
        RetypeInvalid = false,
        RiddleSolver  = false,
    },

    Modes = {
        { Name = "1 GLOBAL MESSAGE",  Count = 1 },
        { Name = "2 GLOBAL MESSAGES", Count = 2 },
        { Name = "3 GLOBAL MESSAGES", Count = 3 },
        { Name = "4 GLOBAL MESSAGES", Count = 4 },
        { Name = "5 GLOBAL MESSAGES", Count = 5 },
    },

    Riddle = {
        URL     = "https://sab-riddle-solver.xyrcheatz.workers.dev",
        Token   = "0facce8d7ac3a4b6fc4b6ae068b3b219883009780cb2ca31",
        Primary = "qwen",
        Backup  = "backup",
        Timeout = 4,
        AI      = true,
    },

    ConfigFile = "sources_hub_redeemer.json",
}

-- // [3] OBJECT REFERENCES //
local ScreenGui
local MainFrame
local TopBar
local TitleLabel
local SubtitleLabel
local StatusDot
local ScanButton
local ModeButton
local PreviewBox
local RedeemButton
local BottomRow
local DelayLabel
local DelayBox
local SetButton

local _enabled       = CONFIG.Defaults.Enabled
local _autoSubmit    = CONFIG.Defaults.AutoSubmit
local _submitAfter   = CONFIG.Defaults.SubmitAfter
local _retypeInvalid = CONFIG.Defaults.RetypeInvalid
local _riddleSolver  = CONFIG.Defaults.RiddleSolver
local _delay         = CONFIG.Defaults.Delay
local _modeIndex     = CONFIG.Defaults.ModeIndex

local _focused        = nil
local _lastBox        = nil
local _lastWatchedBox = nil
local _boxTextConn    = nil
local _boxAncConn     = nil
local _boxVisConns    = {}
local _lastNonBlank   = ""
local _pendText       = nil
local _pendBox        = nil
local _pendUntil      = 0
local _pendToken      = 0
local _writingBox     = false
local _msgBuffer      = {}
local _msgCombined    = ""
local _seenMsgs       = {}
local solving         = 0
local lastTypedSeq    = 0
local riddleSeq       = 0
local _riddleInFlight = {}
local listenConn      = nil
local RedeemRemote    = nil

local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net")
local getupvalues = (debug and debug.getupvalues) or getupvalues
local getconns    = getconnections or (debug and debug.getconnections)
local setupv      = (debug and debug.setupvalue) or setupvalue
local REDEEM_GUID = "7d14a912-1040-4867-b005-98838eb9acc4"

local KNOWN_BOX_PATH = {"Codes", "Codes", "CodeRedeem", "TextBox"}

-- // [4] UTILITY FUNCTIONS //
local function normalise(text)
    return text:lower():gsub("[^%a%d%s]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
end

local function normalizeCode(s)
    if type(s) ~= "string" then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

local function stripRich(t)
    if type(t) ~= "string" then return tostring(t) end
    return (t:gsub("<[^>]->", ""))
end

local FACTS = {
    owner        = "sammy",
    age          = "24",
    country      = "uk",
    nationality  = "british",
    gameName     = "steal a brainrot",
    createdYear  = "2025",
    createdDate  = "may 2025",
    currency     = "coins",
    discord      = "discord.gg/aceduels",
    firstUpdate  = "mutations",
    secondUpdate = "pets",
    thirdUpdate  = "trading",
    goal         = "steal brainrots",
}

local BASE_DB = {}
local function add(key, answer)
    BASE_DB[normalise(key)] = answer
end

local SAB_ALIASES   = {"sab", "steal a brainrot", "this game", "the game", "steal a brain rot"}
local SAMMY_ALIASES = {"sammy", "the owner", "the creator", "the developer", "the dev", "the game owner", "the games owner"}

local WHO_TEMPLATES = {
    "who is the owner of %s", "who owns %s", "who created %s", "who make %s", "who made %s",
    "who developed %s", "whos the owner of %s", "what is the name of the owner of %s",
    "what is the owners name of %s", "can you tell me who made %s", "do you know who owns %s",
    "tell me who created %s", "name the owner of %s", "name the creator of %s", "who is behind %s",
    "who founded %s", "who runs %s", "who is the developer of %s", "who is the creator of %s", "who built %s",
}
for _, alias in ipairs(SAB_ALIASES) do
    for _, tmpl in ipairs(WHO_TEMPLATES) do add(tmpl:format(alias), FACTS.owner) end
end

local AGE_TEMPLATES = {
    "how old is %s", "what is %s age", "whats %s age", "how old is %s currently", "what age is %s",
    "does anyone know how old %s is", "can you tell me how old %s is", "how many years old is %s",
    "what is the age of %s", "what year was %s born",
}
for _, alias in ipairs(SAMMY_ALIASES) do
    for _, tmpl in ipairs(AGE_TEMPLATES) do add(tmpl:format(alias), FACTS.age) end
end

local COUNTRY_TEMPLATES = {
    "what country does %s live in", "where does %s live", "where is %s from",
    "what country is %s from", "which country does %s live in", "where was %s born",
    "what country was %s born in", "does anyone know where %s lives",
    "can you tell me where %s is from", "what continent is %s from",
}
local NATIONALITY_TEMPLATES = {
    "what is %s nationality", "what nationality is %s", "whats %s nationality",
}
for _, alias in ipairs(SAMMY_ALIASES) do
    for _, tmpl in ipairs(COUNTRY_TEMPLATES) do add(tmpl:format(alias), FACTS.country) end
    for _, tmpl in ipairs(NATIONALITY_TEMPLATES) do add(tmpl:format(alias), FACTS.nationality) end
end

local DATE_YEAR_TEMPLATES = {
    "when was %s made", "when was %s created", "when was %s released",
    "what year was %s made", "what year was %s created", "what year was %s released",
    "when did %s come out", "what year did %s come out", "what year did %s release",
}
local DATE_FULL_TEMPLATES = {
    "what day was %s made", "what day was %s created", "what day was %s released",
    "what date was %s made", "what date was %s created", "what date was %s released",
    "what exact date was %s released", "what was the exact release date of %s",
}
for _, alias in ipairs(SAB_ALIASES) do
    for _, tmpl in ipairs(DATE_YEAR_TEMPLATES) do add(tmpl:format(alias), FACTS.createdYear) end
    for _, tmpl in ipairs(DATE_FULL_TEMPLATES) do add(tmpl:format(alias), FACTS.createdDate) end
end

local NAME_TEMPLATES = {
    "what is the name of this game", "what is this game called", "what game is this",
    "what does sab stand for", "what does sab mean", "what is sab short for",
}
for _, tmpl in ipairs(NAME_TEMPLATES) do add(tmpl, FACTS.gameName) end

local ORDINALS = {
    {phrases = {"first", "1st", "number one", "update one", "update 1"}, answer = FACTS.firstUpdate},
    {phrases = {"second", "2nd", "number two", "update two", "update 2"}, answer = FACTS.secondUpdate},
    {phrases = {"third", "3rd", "number three", "update three", "update 3"}, answer = FACTS.thirdUpdate},
}
local UPDATE_TEMPLATES = {
    "what was the %s update", "what was %s update", "what did the %s update add",
    "what was added in the %s update", "name the %s update", "what update was %s",
}
for _, ord in ipairs(ORDINALS) do
    for _, phrase in ipairs(ord.phrases) do
        for _, tmpl in ipairs(UPDATE_TEMPLATES) do add(tmpl:format(phrase), ord.answer) end
    end
end

local MUTATIONS = {
    {name = "cursed",      traits = {"cursed", "hardest to get", "hardest mutation to get", "the rarest mutation"}},
    {name = "haunted",     traits = {"scary", "haunted"}},
    {name = "golden",      traits = {"golden"}},
    {name = "shiny",       traits = {"shiny"}},
    {name = "glitched",    traits = {"glitched", "glitchy"}},
    {name = "frozen",      traits = {"frozen", "ice"}},
    {name = "corrupted",   traits = {"corrupted"}},
    {name = "divine",      traits = {"divine", "best mutation", "the best mutation"}},
    {name = "shadow",      traits = {"shadow"}},
    {name = "radioactive", traits = {"radioactive"}},
    {name = "windy",       traits = {"windy"}},
}
local MUTATION_TEMPLATES = {
    "what is the %s mutation", "what is the %s mutation called", "what mutation is %s",
    "name the %s mutation", "which mutation is %s", "what is %s mutation in steal a brainrot",
    "what is %s mutation in sab",
}
for _, m in ipairs(MUTATIONS) do
    for _, trait in ipairs(m.traits) do
        for _, tmpl in ipairs(MUTATION_TEMPLATES) do add(tmpl:format(trait), m.name) end
    end
end

local BRAINROTS = {
    {trait = "rarest",       name = "tralalelo tralala"},
    {trait = "most common",  name = "bombardino crocodilo"},
    {trait = "starter",      name = "bombardino crocodilo"},
    {trait = "most popular", name = "tralalelo tralala"},
    {trait = "a crocodile",  name = "bombardino crocodilo"},
    {trait = "a shark",      name = "tralalelo tralala"},
    {trait = "flying",       name = "cappuccino assassino"},
    {trait = "a cat",        name = "gatto panceri"},
    {trait = "a dog",        name = "bombombini gusini"},
}
local BRAINROT_TEMPLATES = {
    "what is the %s brainrot", "what brainrot is %s", "which brainrot is %s", "name the %s brainrot",
}
for _, b in ipairs(BRAINROTS) do
    for _, tmpl in ipairs(BRAINROT_TEMPLATES) do add(tmpl:format(b.trait), b.name) end
end

local MISC_FACTS = {
    {templates = {"what is the currency in %s", "what currency does %s use", "what is the main currency in %s", "how do you earn coins in %s", "what is %s currency"}, answer = FACTS.currency, aliases = SAB_ALIASES},
    {templates = {"what is the discord for %s", "what is %s discord", "whats the discord link for %s", "what is the discord server for %s", "does %s have a discord"}, answer = FACTS.discord, aliases = SAB_ALIASES},
    {templates = {"what is the discord", "whats the discord link", "what is sammys discord", "what is the server link"}, answer = FACTS.discord, aliases = {""}},
    {templates = {"what is the goal of %s", "what is the objective of %s", "how do you play %s", "what do you do in %s", "what is the point of %s"}, answer = FACTS.goal, aliases = SAB_ALIASES},
}
for _, fact in ipairs(MISC_FACTS) do
    for _, alias in ipairs(fact.aliases) do
        for _, tmpl in ipairs(fact.templates) do
            local ok, key = pcall(function() return tmpl:format(alias) end)
            if ok then add(key, fact.answer) end
        end
    end
end

local CAPITALS = {
    {"france", "paris"}, {"england", "london"}, {"the uk", "london"}, {"usa", "washington dc"},
    {"america", "washington dc"}, {"japan", "tokyo"}, {"australia", "canberra"}, {"germany", "berlin"},
    {"italy", "rome"}, {"spain", "madrid"}, {"canada", "ottawa"}, {"china", "beijing"}, {"russia", "moscow"},
    {"india", "new delhi"}, {"brazil", "brasilia"}, {"mexico", "mexico city"}, {"egypt", "cairo"},
    {"south korea", "seoul"}, {"north korea", "pyongyang"}, {"greece", "athens"}, {"turkey", "ankara"},
    {"sweden", "stockholm"}, {"norway", "oslo"}, {"finland", "helsinki"}, {"poland", "warsaw"},
    {"portugal", "lisbon"}, {"ireland", "dublin"}, {"scotland", "edinburgh"}, {"netherlands", "amsterdam"},
    {"belgium", "brussels"}, {"switzerland", "bern"}, {"austria", "vienna"}, {"argentina", "buenos aires"},
    {"chile", "santiago"}, {"colombia", "bogota"}, {"peru", "lima"}, {"thailand", "bangkok"},
    {"vietnam", "hanoi"}, {"indonesia", "jakarta"}, {"philippines", "manila"}, {"pakistan", "islamabad"},
    {"saudi arabia", "riyadh"}, {"israel", "jerusalem"}, {"south africa", "pretoria"}, {"nigeria", "abuja"},
    {"kenya", "nairobi"}, {"new zealand", "wellington"}, {"denmark", "copenhagen"}, {"iceland", "reykjavik"},
}
local CAPITAL_TEMPLATES = {
    "what is the capital of %s", "whats the capital city of %s", "name the capital of %s",
    "which city is the capital of %s", "what city is the capital of %s",
}
for _, pair in ipairs(CAPITALS) do
    for _, tmpl in ipairs(CAPITAL_TEMPLATES) do add(tmpl:format(pair[1]), pair[2]) end
end

local ANIMAL_SOUNDS = {
    {"cow", "moo"}, {"pig", "oink"}, {"cat", "meow"}, {"dog", "woof"}, {"sheep", "baa"}, {"duck", "quack"},
    {"horse", "neigh"}, {"lion", "roar"}, {"snake", "hiss"}, {"owl", "hoot"}, {"frog", "ribbit"},
    {"chicken", "cluck"}, {"wolf", "howl"}, {"bee", "buzz"}, {"donkey", "hee haw"},
}
local ANIMAL_SOUND_TEMPLATES = {
    "what animal says %s", "which animal says %s", "what animal makes the sound %s", "what says %s",
}
for _, pair in ipairs(ANIMAL_SOUNDS) do
    for _, tmpl in ipairs(ANIMAL_SOUND_TEMPLATES) do add(tmpl:format(pair[2]), pair[1]) end
end

local ANIMAL_FACTS = {
    {"what animal is known as mans best friend", "dog"}, {"what animal has a trunk", "elephant"},
    {"what is the fastest land animal", "cheetah"}, {"what is the largest animal", "blue whale"},
    {"what is the largest land animal", "elephant"}, {"what animal is known as the king of the jungle", "lion"},
    {"what bird cannot fly", "penguin"}, {"what is the tallest animal", "giraffe"},
    {"what animal has black and white stripes", "zebra"}, {"what is the smallest bird", "hummingbird"},
    {"what is the largest big cat", "tiger"}, {"what animal has a long neck", "giraffe"},
}
for _, pair in ipairs(ANIMAL_FACTS) do add(pair[1], pair[2]) end

local COLORS = {
    {"the sky", "blue"}, {"grass", "green"}, {"the sun", "yellow"}, {"snow", "white"}, {"blood", "red"},
    {"coal", "black"}, {"a banana", "yellow"}, {"a strawberry", "red"}, {"an orange", "orange"},
    {"the ocean", "blue"}, {"a lemon", "yellow"}, {"a lime", "green"}, {"a tomato", "red"},
    {"a carrot", "orange"}, {"grapes", "purple"}, {"chocolate", "brown"},
}
local COLOR_TEMPLATES = {"what color is %s", "what colour is %s", "what color are %s", "what colour are %s"}
for _, pair in ipairs(COLORS) do
    for _, tmpl in ipairs(COLOR_TEMPLATES) do
        local ok, key = pcall(function() return tmpl:format(pair[1]) end)
        if ok then add(key, pair[2]) end
    end
end

local SHAPES = {
    {"triangle", "3"}, {"square", "4"}, {"rectangle", "4"}, {"pentagon", "5"}, {"hexagon", "6"},
    {"heptagon", "7"}, {"octagon", "8"}, {"nonagon", "9"}, {"decagon", "10"},
}
local SHAPE_TEMPLATES = {
    "how many sides does a %s have", "how many sides does an %s have",
    "how many edges does a %s have", "how many sides has a %s got",
}
for _, pair in ipairs(SHAPES) do
    for _, tmpl in ipairs(SHAPE_TEMPLATES) do add(tmpl:format(pair[1]), pair[2]) end
end

local TIME_FACTS = {
    {"how many days are in a week", "7"}, {"how many months are in a year", "12"},
    {"how many hours are in a day", "24"}, {"how many minutes are in an hour", "60"},
    {"how many seconds are in a minute", "60"}, {"how many days are in a year", "365"},
    {"how many days are in a leap year", "366"}, {"how many weeks are in a year", "52"},
    {"how many letters are in the alphabet", "26"}, {"how many continents are there", "7"},
}
for _, pair in ipairs(TIME_FACTS) do add(pair[1], pair[2]) end

local SPACE_FACTS = {
    {"what planet do we live on", "earth"}, {"what is the closest planet to the sun", "mercury"},
    {"what is the largest planet", "jupiter"}, {"what is the smallest planet", "mercury"},
    {"what is the red planet", "mars"}, {"how many planets are in the solar system", "8"},
    {"what is the hottest planet", "venus"}, {"what galaxy do we live in", "milky way"},
    {"what is the closest star to earth", "the sun"}, {"how many moons does earth have", "1"},
}
local SPACE_TEMPLATES = {"%s", "do you know %s", "can you tell me %s"}
for _, pair in ipairs(SPACE_FACTS) do
    for _, tmpl in ipairs(SPACE_TEMPLATES) do add(tmpl:format(pair[1]), pair[2]) end
end

local ROBLOX_FACTS = {
    {"what year was roblox created", "2006"}, {"when was roblox made", "2006"},
    {"when was roblox released", "2006"}, {"who created roblox", "david baszucki"},
    {"who made roblox", "david baszucki"}, {"what is the currency in roblox", "robux"},
}
for _, pair in ipairs(ROBLOX_FACTS) do add(pair[1], pair[2]) end

local FOOD_FACTS = {
    {"what fruit is yellow and curved", "banana"}, {"what fruit is red and has seeds inside", "apple"},
    {"what vegetable makes you cry when you cut it", "onion"},
    {"what is technically a fruit but eaten as a vegetable", "tomato"},
    {"what fruit is orange and round", "orange"}, {"what is a potato", "vegetable"},
}
for _, pair in ipairs(FOOD_FACTS) do add(pair[1], pair[2]) end

local CLASSIC_RIDDLES = {
    {"what has hands but cannot clap", "clock"}, {"what gets wetter as it dries", "towel"},
    {"what has teeth but cannot bite", "comb"}, {"what goes up but never comes down", "age"},
    {"what can run but never walks", "river"}, {"what has a head and a tail but no body", "coin"},
    {"what has keys but no locks", "keyboard"}, {"what has legs but cannot walk", "table"},
    {"what is always in front of you but cannot be seen", "future"},
    {"what has one eye but cannot see", "needle"},
    {"the more you take the more you leave behind", "footsteps"},
    {"what is full of holes but still holds water", "sponge"},
    {"what word is spelled wrong in every dictionary", "wrong"},
    {"what can you catch but not throw", "cold"},
    {"what is black and white and read all over", "newspaper"},
    {"i speak without a mouth and hear without ears", "echo"},
    {"the more you have of it the less you see", "darkness"},
    {"what has a bottom at the top", "legs"},
    {"what invention lets you look right through a wall", "window"},
    {"what do you call a bear with no teeth", "gummy bear"},
}
for _, pair in ipairs(CLASSIC_RIDDLES) do add(pair[1], pair[2]) end

local PREFIXES = {"", "hey ", "quick question ", "do you know ", "can you tell me "}
local SUFFIXES = {"", "please"}
local RIDDLE_DB = {}
local dbCount = 0
for key, answer in pairs(BASE_DB) do
    for _, pre in ipairs(PREFIXES) do
        for _, suf in ipairs(SUFFIXES) do
            local fk = normalise(pre .. key .. suf)
            if RIDDLE_DB[fk] == nil then
                RIDDLE_DB[fk] = answer
                dbCount += 1
            end
        end
    end
end

local function solveRiddleLocal(text)
    local clean = normalise(text)
    if RIDDLE_DB[clean] then return RIDDLE_DB[clean] end
    local bestAns, bestLen = nil, 0
    for q, a in pairs(RIDDLE_DB) do
        if #q > bestLen and clean:find(q, 1, true) then
            bestAns, bestLen = a, #q
        end
    end
    if bestAns then return bestAns end

    local hasSab   = clean:match("sab") or clean:match("steal a brainrot") or clean:match("steal a brain")
    local hasSammy = clean:match("sammy") or clean:match("owner") or clean:match("creator") or clean:match("developer")
    if hasSab then
        if clean:match("day") or clean:match("date") then return FACTS.createdDate end
        if clean:match("when") or clean:match("what year") or clean:match("come out") then return FACTS.createdYear end
        if clean:match("who") or clean:match("made") or clean:match("creat") or clean:match("develop") or clean:match("own") then return FACTS.owner end
        if clean:match("currency") or clean:match("coin") then return FACTS.currency end
        if clean:match("discord") then return FACTS.discord end
        if clean:match("rarest") and clean:match("mutation") then return "cursed" end
        if clean:match("rarest") and clean:match("brainrot") then return "tralalelo tralala" end
    end
    if hasSammy then
        if clean:match("old") or clean:match("age") then return FACTS.age end
        if clean:match("country") or clean:match("where") or clean:match("live") or clean:match("from") then return FACTS.country end
        if clean:match("nation") then return FACTS.nationality end
        if clean:match("discord") then return FACTS.discord end
    end
    if clean:match("cursed") and clean:match("mutation") then return "cursed" end
    if clean:match("haunted") and clean:match("mutation") then return "haunted" end
    if clean:match("scary") and clean:match("mutation") then return "haunted" end
    if clean:match("divine") and clean:match("mutation") then return "divine" end
    if clean:match("golden") and clean:match("mutation") then return "golden" end
    if clean:match("frozen") and clean:match("mutation") then return "frozen" end
    if clean:match("glitch") and clean:match("mutation") then return "glitched" end
    if clean:match("shadow") and clean:match("mutation") then return "shadow" end
    if clean:match("corrupt") and clean:match("mutation") then return "corrupted" end

    local n1, op, n2 = clean:match("(%d+)%s*(plus|minus|times|divided by|multiplied by)%s*(%d+)")
    if n1 and op and n2 then
        n1, n2 = tonumber(n1), tonumber(n2)
        local r
        if op == "plus" then r = n1 + n2
        elseif op == "minus" then r = n1 - n2
        elseif op == "times" or op == "multiplied by" then r = n1 * n2
        elseif op == "divided by" and n2 ~= 0 then r = n1 / n2 end
        if r then return tostring(math.floor(r + 0.5)) end
    end
    local a2, sym, b2 = clean:match("(%d+)%s*([%+%-%*/])%s*(%d+)")
    if a2 and sym and b2 then
        a2, b2 = tonumber(a2), tonumber(b2)
        local r
        if sym == "+" then r = a2 + b2
        elseif sym == "-" then r = a2 - b2
        elseif sym == "*" then r = a2 * b2
        elseif sym == "/" and b2 ~= 0 then r = a2 / b2 end
        if r then return tostring(math.floor(r + 0.5)) end
    end
    return nil
end

local QUESTION_STARTERS = {
    "who ", "what ", "where ", "when ", "why ", "how ", "which ", "name ", "is ", "are ",
    "do ", "does ", "can ", "the more", "i have", "i speak", "hey ", "quick question", "do you know", "can you tell me",
}
local function isRiddleText(text)
    local low = text:lower()
    if low:match("%?%s*$") then return true end
    for _, s in ipairs(QUESTION_STARTERS) do
        if low:sub(1, #s) == s then return true end
    end
    if low:match("%s") and #low > 8 then
        if low:match(" the ") or low:match(" is ") or low:match(" of ") or low:match(" was ")
        or low:match(" did ") or low:match(" does ") or low:match(" are ") or low:match(" have ") then
            return true
        end
    end
    return false
end

local function aceCodeBox()
    local gui = PlayerGui:FindFirstChild("Codes")
    if not gui then return end
    local root = gui:FindFirstChild("Codes") or gui
    local box = (root:FindFirstChild("CodeRedeem") or root):FindFirstChild("TextBox")
    if box and box:IsA("TextBox") then return box end
    for _, o in ipairs(gui:GetDescendants()) do
        if o:IsA("TextBox") then return o end
    end
end

local function resolveRedeemRemote()
    if RedeemRemote and RedeemRemote.Parent then return RedeemRemote end
    local ok, api = pcall(require, Net)
    if ok and type(api) == "table" then
        local rok, rf = pcall(function() return api:RemoteFunction(REDEEM_GUID) end)
        if rok and typeof(rf) == "Instance" then RedeemRemote = rf end
    end
    return RedeemRemote
end

local function killDebounce(fn)
    if not (fn and setupv and getupvalues) then return end
    local ok, ups = pcall(getupvalues, fn)
    if ok and type(ups) == "table" then
        for i, v in pairs(ups) do
            if type(v) == "boolean" then pcall(setupv, fn, i, false) end
        end
    end
end

local function redeemViaBox(code)
    if not getconns then return false, "no getconnections" end
    local box = aceCodeBox()
    if not box then return false, "no codebox" end
    local ok, conns = pcall(getconns, box.FocusLost)
    if not ok or type(conns) ~= "table" or #conns == 0 then return false, "no connection" end
    local fired = false
    for _, c in ipairs(conns) do
        local fn
        pcall(function() fn = c.Function end)
        killDebounce(fn)
        box.Text = code
        box.Active = true
        box.Selectable = true
        fired = fired or pcall(function()
            if c.Enabled ~= false then c:Fire(true) end
        end)
    end
    return fired, fired and "sent" or "fire failed"
end

local function redeemViaRemote(code)
    local rf = resolveRedeemRemote()
    if not rf then return false, "no remote" end
    local ok, result = pcall(function() return rf:InvokeServer(code) end)
    if not ok then return false, tostring(result) end
    return true, result
end

local function aceRedeem(code)
    local ok, res = redeemViaBox(code)
    if ok then return true, res end
    if getconns then return false, res end
    return redeemViaRemote(code)
end

local function loadCfg()
    pcall(function()
        if type(isfile) == "function" and type(readfile) == "function" and isfile(CONFIG.ConfigFile) then
            local d = HttpService:JSONDecode(readfile(CONFIG.ConfigFile))
            if type(d) == "table" then
                if type(d.enabled) == "boolean" then _enabled = d.enabled end
                if type(d.autoSubmit) == "boolean" then _autoSubmit = d.autoSubmit end
                if type(d.retypeInvalid) == "boolean" then _retypeInvalid = d.retypeInvalid end
                if type(d.riddleSolver) == "boolean" then _riddleSolver = d.riddleSolver end
                if type(d.delay) == "number" then _delay = math.max(0, d.delay) end
                if type(d.modeIndex) == "number" then
                    _modeIndex = math.clamp(math.floor(d.modeIndex), 1, #CONFIG.Modes)
                    _submitAfter = CONFIG.Modes[_modeIndex].Count
                end
                if type(d.submitAfter) == "number" then
                    _submitAfter = math.max(1, math.floor(d.submitAfter))
                end
            end
        end
    end)
end

local function saveCfg()
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(CONFIG.ConfigFile, HttpService:JSONEncode({
            enabled       = _enabled,
            autoSubmit    = _autoSubmit,
            retypeInvalid = _retypeInvalid,
            riddleSolver  = _riddleSolver,
            delay         = _delay,
            modeIndex     = _modeIndex,
            submitAfter   = _submitAfter,
        }))
    end)
end

local function clearBoxWatchers()
    if _boxTextConn then pcall(function() _boxTextConn:Disconnect() end) end
    if _boxAncConn then pcall(function() _boxAncConn:Disconnect() end) end
    for _, c in ipairs(_boxVisConns) do pcall(function() c:Disconnect() end) end
    _boxTextConn = nil
    _boxAncConn = nil
    _boxVisConns = {}
    _lastWatchedBox = nil
end

local function isBoxOpen(box)
    if not box or not box.Parent then return false end
    local cur = box
    while cur do
        if cur:IsA("GuiObject") and cur.Visible == false then return false end
        if cur:IsA("ScreenGui") and cur.Enabled == false then return false end
        cur = cur.Parent
    end
    return true
end

local function resolveCodeBox()
    local node = PlayerGui
    for _, n in ipairs(KNOWN_BOX_PATH) do
        if not node then break end
        node = node:FindFirstChild(n)
    end
    if node and node:IsA("TextBox") and isBoxOpen(node) then return node end
    if isBoxOpen(_focused) then return _focused end
    if isBoxOpen(_lastBox) then return _lastBox end
end

local function safeWriteBox(box, text)
    _writingBox = true
    box.Text = text
    pcall(function()
        local e = #text + 1
        box.CursorPosition = e
        box.SelectionStart = e
    end)
    _writingBox = false
end

local function watchBox(box)
    if not box or _lastWatchedBox == box then return end
    clearBoxWatchers()
    _lastWatchedBox = box
    if box.Text ~= "" then _lastNonBlank = box.Text end
    _boxTextConn = box:GetPropertyChangedSignal("Text"):Connect(function()
        if _writingBox then return end
        if box.Text == "" then
            _msgBuffer = {}
            _msgCombined = ""
            if PreviewBox then PreviewBox.Text = "" end
        else
            _lastNonBlank = box.Text
        end
    end)
    _boxAncConn = box.AncestryChanged:Connect(function(_, p)
        if not p then
            _msgBuffer = {}
            _msgCombined = ""
            if PreviewBox then PreviewBox.Text = "" end
            clearBoxWatchers()
        end
    end)
    local cur = box
    while cur do
        if cur:IsA("GuiObject") then
            table.insert(_boxVisConns, cur:GetPropertyChangedSignal("Visible"):Connect(function()
                if not isBoxOpen(box) then
                    _msgBuffer = {}
                    _msgCombined = ""
                    if PreviewBox then PreviewBox.Text = "" end
                    clearBoxWatchers()
                end
            end))
        elseif cur:IsA("ScreenGui") then
            table.insert(_boxVisConns, cur:GetPropertyChangedSignal("Enabled"):Connect(function()
                if not isBoxOpen(box) then
                    _msgBuffer = {}
                    _msgCombined = ""
                    if PreviewBox then PreviewBox.Text = "" end
                    clearBoxWatchers()
                end
            end))
        end
        cur = cur.Parent
    end
end

local clearPending, rememberPending, handleFeedback, restoreRejected

clearPending = function()
    _pendToken += 1
    _pendText = nil
    _pendBox = nil
    _pendUntil = 0
end

rememberPending = function(box, text, replace)
    if not _retypeInvalid or not text or text == "" then return end
    if not replace and _pendText and os.clock() <= _pendUntil then return end
    _pendToken += 1
    local tok = _pendToken
    _pendText = text
    _pendBox = box
    _pendUntil = os.clock() + 8
    task.delay(8, function()
        if tok == _pendToken then clearPending() end
    end)
end

restoreRejected = function(box, prev)
    if not _retypeInvalid or not prev or prev == "" then return false end
    RunService.Heartbeat:Wait()
    local rb = resolveCodeBox() or box
    if not rb or not isBoxOpen(rb) then return false end
    local ok = pcall(function() safeWriteBox(rb, prev) end)
    if ok then
        _lastBox = rb
        watchBox(rb)
        if PreviewBox then PreviewBox.Text = prev end
    end
    return ok
end

handleFeedback = function(text, obj)
    if not _retypeInvalid or not _pendText then return end
    if os.clock() > _pendUntil then
        clearPending()
        return
    end
    if obj and ScreenGui and obj:IsDescendantOf(ScreenGui) then return end
    local l = tostring(text or ""):lower()
    if not (l:find("invalid code", 1, true) or l:find("expired", 1, true)
        or l:find("already redeemed", 1, true) or l:find("not found", 1, true)
        or l:find("rejected", 1, true) or l:find("does not exist", 1, true)) then
        return
    end
    local pt, pb = _pendText, _pendBox
    local ok = restoreRejected(pb, pt)
    clearPending()
    if ok and PreviewBox then
        PreviewBox.Text = pt
    end
end

local function aiPost(path, body)
    if not httpRequest then return nil end
    local ok, res = pcall(httpRequest, {
        Url     = CONFIG.Riddle.URL .. path,
        Method  = "POST",
        Headers = {
            ["Content-Type"]  = "application/json",
            ["Authorization"] = "Bearer " .. CONFIG.Riddle.Token,
        },
        Body = HttpService:JSONEncode(body),
    })
    if not ok or type(res) ~= "table" then return nil end
    local raw = res.Body or res.body
    if type(raw) ~= "string" then return nil end
    local okd, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if okd and type(data) == "table" then return data end
    return nil
end

local submitRiddleAnswer
submitRiddleAnswer = function(ans)
    local box = aceCodeBox()
    if box then safeWriteBox(box, ans) end
    if PreviewBox then PreviewBox.Text = ans end
    if _autoSubmit then
        task.spawn(function()
            task.wait(_delay)
            local ok, res = aceRedeem(ans)
            local success = ok and (type(res) ~= "table" or res.success or res.Success)
            if not success and _retypeInvalid then
                restoreRejected(box, ans)
            end
        end)
    end
end

local function dispatchRiddle(rawText)
    local key = normalise(rawText)
    if _riddleInFlight[key] then return end
    _riddleInFlight[key] = true
    riddleSeq += 1
    local seq = riddleSeq
    local resolved = false
    local deadline = os.clock() + CONFIG.Riddle.Timeout

    local function trySubmit(ans, source)
        if resolved then return end
        local clean = normalizeCode(ans)
        if not clean or #clean == 0 then return end
        if seq < lastTypedSeq then return end
        resolved = true
        lastTypedSeq = seq
        submitRiddleAnswer(clean)
        task.delay(3, function() _riddleInFlight[key] = nil end)
    end

    task.spawn(function()
        local ans = solveRiddleLocal(rawText)
        if ans then trySubmit(ans, "Local") end
    end)

    if CONFIG.Riddle.AI and httpRequest and _riddleSolver then
        solving += 1
        task.spawn(function()
            local model = CONFIG.Riddle.Primary
            local data = aiPost("/solve", {message = rawText, model = model, history = nil})
            solving = math.max(0, solving - 1)
            if os.clock() > deadline then
                _riddleInFlight[key] = nil
                return
            end
            if not _enabled then
                _riddleInFlight[key] = nil
                return
            end
            local top = (data and data.riddle == true and type(data.answers) == "table" and data.answers[1])
                and normalizeCode(data.answers[1]) or nil
            if top and #top > 0 then
                trySubmit(top, "AI")
            else
                _riddleInFlight[key] = nil
            end
        end)
    else
        task.delay(0.5, function()
            if not resolved then _riddleInFlight[key] = nil end
        end)
    end
end

local function appendToBox(rawText)
    if not rawText or rawText == "" then return end
    if not _enabled then return end

    if _riddleSolver and isRiddleText(rawText) then
        dispatchRiddle(rawText)
        return
    end

    if _lastWatchedBox and not isBoxOpen(_lastWatchedBox) then
        _msgBuffer = {}
        _msgCombined = ""
        if PreviewBox then PreviewBox.Text = "" end
        clearBoxWatchers()
    end

    _msgBuffer[#_msgBuffer + 1] = rawText
    _msgCombined = table.concat(_msgBuffer)
    local count = #_msgBuffer

    if PreviewBox then
        PreviewBox.Text = _msgCombined
    end

    local box = aceCodeBox()
    if box then
        _lastBox = box
        watchBox(box)
        safeWriteBox(box, _msgCombined)
    end

    if count >= _submitAfter then
        local final = _msgCombined
        _msgBuffer = {}
        _msgCombined = ""
        if PreviewBox then PreviewBox.Text = final end

        if _autoSubmit then
            rememberPending(box, final, true)
            task.spawn(function()
                task.wait(_delay)
                local ok, res = aceRedeem(final)
                local success = ok and (type(res) ~= "table" or res.success or res.Success)
                if not success then
                    local ok2 = restoreRejected(box, final)
                    clearPending()
                    if not ok2 and PreviewBox then
                        PreviewBox.Text = final
                    end
                else
                    clearPending()
                end
            end)
        end
    end
end

local function getRemotesFromFn(fn)
    if not getupvalues then return {} end
    local ok, vals = pcall(getupvalues, fn)
    local out = {}
    if ok and type(vals) == "table" then
        for _, v in pairs(vals) do
            if typeof(v) == "Instance"
                and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("UnreliableRemoteEvent"))
                and v.Parent == Net then
                table.insert(out, v)
            end
        end
    end
    return out
end

local function resolveNotifyRemote()
    local ok, ctrl = pcall(function()
        return require(ReplicatedStorage.Controllers:FindFirstChild("NotificationController", true))
    end)
    if ok and type(ctrl) == "table" and type(ctrl.Start) == "function" then
        return getRemotesFromFn(ctrl.Start)[1]
    end
end

local ACE_POS = {
    Top = true, Bottom = true, Center = true, Middle = true, Left = true, Right = true,
    TopRight = true, TopLeft = true, BottomRight = true, BottomLeft = true,
}

local function isAnnouncement(...)
    local args = table.pack(...)
    if args.n == 0 or typeof(args[1]) ~= "string" then return false end
    for i = 2, args.n do
        local v = args[i]
        if typeof(v) == "string" and (v:find("Sounds%.") or v:find("rbxassetid") or ACE_POS[v]) then
            return true
        end
    end
    return false
end

local function onAnnouncement(...)
    local raw = tostring((...) or "")
    local text = stripRich(raw):match("^%s*(.-)%s*$") or ""
    if text == "" then return end
    if _seenMsgs[text] then return end
    _seenMsgs[text] = true
    task.delay(2, function() _seenMsgs[text] = nil end)
    -- clipboard backup — code already in clipboard if auto-redeem fails
    if setclipboard then pcall(setclipboard, text) end
    appendToBox(text)
end

local function updateStatusVisual()
    if not StatusDot then return end
    StatusDot.BackgroundColor3 = _enabled and CONFIG.Colors.StatusOn or CONFIG.Colors.StatusOff
end

local function updateScanButton()
    if not ScanButton then return end
    ScanButton.Text = _enabled and CONFIG.Texts.ScanActive or CONFIG.Texts.ScanStart
    ScanButton.TextColor3 = CONFIG.Colors.Accent
end

local function updateModeButton()
    if not ModeButton then return end
    local mode = CONFIG.Modes[_modeIndex]
    ModeButton.Text = CONFIG.Texts.ModePrefix .. mode.Name
end

-- // [5] GUI CREATION //
local function createGUI()
    for _, name in ipairs({
        CONFIG.Names.ScreenGui,
        "MahevyHubSniperUI", "MahevyHubV2", "ACECodeSniperUI", "AutoTypeCodesUI",
    }) do
        pcall(function()
            local g = CoreGui:FindFirstChild(name)
            if g then g:Destroy() end
        end)
        local g = PlayerGui:FindFirstChild(name)
        if g then g:Destroy() end
    end

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = CONFIG.Names.ScreenGui
    ScreenGui.DisplayOrder = 999
    ScreenGui.Enabled = true
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if not pcall(function() ScreenGui.Parent = CoreGui end) then
        ScreenGui.Parent = PlayerGui
    end

    MainFrame = Instance.new("ImageLabel")
    MainFrame.Name = CONFIG.Names.MainFrame
    MainFrame.Active = true
    MainFrame.BackgroundColor3 = CONFIG.Colors.MainFrameBg
    MainFrame.BackgroundTransparency = CONFIG.Transparency.MainFrame
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Position = CONFIG.Position.MainFrame
    MainFrame.Size = CONFIG.Size.MainFrame
    MainFrame.Image = CONFIG.Image.MainFrame
    MainFrame.ImageTransparency = CONFIG.Transparency.Image
    MainFrame.ScaleType = Enum.ScaleType.Crop
    MainFrame.Parent = ScreenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = CONFIG.CornerRadius.Main
    mainCorner.Parent = MainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    mainStroke.Color = CONFIG.Colors.Stroke
    mainStroke.Thickness = 1.5
    mainStroke.Parent = MainFrame

    TopBar = Instance.new("Frame")
    TopBar.Name = CONFIG.Names.TopBar
    TopBar.BackgroundColor3 = CONFIG.Colors.TopBarBg
    TopBar.BackgroundTransparency = CONFIG.Transparency.TopBar
    TopBar.BorderSizePixel = 0
    TopBar.Position = CONFIG.Position.TopBar
    TopBar.Size = CONFIG.Size.TopBar
    TopBar.Parent = MainFrame

    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = CONFIG.CornerRadius.Main
    topCorner.Parent = TopBar

    TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = CONFIG.Names.Title
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Position = CONFIG.Position.Title
    TitleLabel.Size = UDim2.new(0, 200, 0, 14)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = CONFIG.Texts.Title
    TitleLabel.TextColor3 = CONFIG.Colors.TextDark
    TitleLabel.TextSize = 11
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TopBar

    SubtitleLabel = Instance.new("TextLabel")
    SubtitleLabel.Name = CONFIG.Names.Subtitle
    SubtitleLabel.BackgroundTransparency = 1
    SubtitleLabel.Position = CONFIG.Position.Subtitle
    SubtitleLabel.Size = UDim2.new(0, 200, 0, 12)
    SubtitleLabel.Font = Enum.Font.Gotham
    SubtitleLabel.Text = CONFIG.Texts.Subtitle
    SubtitleLabel.TextColor3 = CONFIG.Colors.TextSubtitle
    SubtitleLabel.TextSize = 10
    SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubtitleLabel.Parent = TopBar

    StatusDot = Instance.new("TextButton")
    StatusDot.Name = CONFIG.Names.StatusDot
    StatusDot.BackgroundColor3 = CONFIG.Colors.StatusOff
    StatusDot.BorderSizePixel = 0
    StatusDot.Position = CONFIG.Position.StatusDot
    StatusDot.Size = CONFIG.Size.StatusDot
    StatusDot.AutoButtonColor = false
    StatusDot.Text = ""
    StatusDot.Parent = TopBar

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = CONFIG.CornerRadius.Dot
    dotCorner.Parent = StatusDot

    ScanButton = Instance.new("TextButton")
    ScanButton.Name = CONFIG.Names.ScanButton
    ScanButton.BackgroundColor3 = CONFIG.Colors.ButtonBg
    ScanButton.BackgroundTransparency = CONFIG.Transparency.Button
    ScanButton.BorderSizePixel = 0
    ScanButton.Position = CONFIG.Position.ScanButton
    ScanButton.Size = CONFIG.Size.ScanButton
    ScanButton.AutoButtonColor = false
    ScanButton.Font = Enum.Font.GothamBold
    ScanButton.Text = CONFIG.Texts.ScanStart
    ScanButton.TextColor3 = CONFIG.Colors.Accent
    ScanButton.TextSize = 11
    ScanButton.Parent = MainFrame

    local scanCorner = Instance.new("UICorner")
    scanCorner.CornerRadius = CONFIG.CornerRadius.Button
    scanCorner.Parent = ScanButton

    local scanStroke = Instance.new("UIStroke")
    scanStroke.Color = CONFIG.Colors.Stroke
    scanStroke.Thickness = 1
    scanStroke.Parent = ScanButton

    ModeButton = Instance.new("TextButton")
    ModeButton.Name = CONFIG.Names.ModeButton
    ModeButton.BackgroundColor3 = CONFIG.Colors.ButtonBg
    ModeButton.BackgroundTransparency = CONFIG.Transparency.Button
    ModeButton.BorderSizePixel = 0
    ModeButton.Position = CONFIG.Position.ModeButton
    ModeButton.Size = CONFIG.Size.ModeButton
    ModeButton.AutoButtonColor = false
    ModeButton.Font = Enum.Font.GothamBold
    ModeButton.Text = CONFIG.Texts.ModePrefix .. CONFIG.Modes[_modeIndex].Name
    ModeButton.TextColor3 = CONFIG.Colors.TextMuted
    ModeButton.TextSize = 9
    ModeButton.Parent = MainFrame

    local modeCorner = Instance.new("UICorner")
    modeCorner.CornerRadius = CONFIG.CornerRadius.Button
    modeCorner.Parent = ModeButton

    local modeStroke = Instance.new("UIStroke")
    modeStroke.Color = CONFIG.Colors.Stroke
    modeStroke.Thickness = 1
    modeStroke.Parent = ModeButton

    PreviewBox = Instance.new("TextBox")
    PreviewBox.Name = CONFIG.Names.PreviewBox
    PreviewBox.BackgroundColor3 = CONFIG.Colors.ButtonBg
    PreviewBox.BackgroundTransparency = CONFIG.Transparency.Button
    PreviewBox.BorderSizePixel = 0
    PreviewBox.Position = CONFIG.Position.PreviewBox
    PreviewBox.Size = CONFIG.Size.PreviewBox
    PreviewBox.ClearTextOnFocus = false
    PreviewBox.Font = Enum.Font.GothamBold
    PreviewBox.PlaceholderColor3 = CONFIG.Colors.Placeholder
    PreviewBox.PlaceholderText = CONFIG.Texts.Placeholder
    PreviewBox.Text = ""
    PreviewBox.TextColor3 = CONFIG.Colors.TextInput
    PreviewBox.TextSize = 11
    PreviewBox.TextXAlignment = Enum.TextXAlignment.Left
    PreviewBox.Parent = MainFrame

    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = CONFIG.CornerRadius.Button
    previewCorner.Parent = PreviewBox

    local previewPad = Instance.new("UIPadding")
    previewPad.PaddingLeft = UDim.new(0, 8)
    previewPad.PaddingRight = UDim.new(0, 8)
    previewPad.Parent = PreviewBox

    local previewStroke = Instance.new("UIStroke")
    previewStroke.Color = CONFIG.Colors.Stroke
    previewStroke.Thickness = 1
    previewStroke.Parent = PreviewBox

    RedeemButton = Instance.new("TextButton")
    RedeemButton.Name = CONFIG.Names.RedeemButton
    RedeemButton.BackgroundColor3 = CONFIG.Colors.ButtonBg
    RedeemButton.BorderSizePixel = 0
    RedeemButton.Position = CONFIG.Position.RedeemButton
    RedeemButton.Size = CONFIG.Size.RedeemButton
    RedeemButton.AutoButtonColor = true
    RedeemButton.Font = Enum.Font.GothamBold
    RedeemButton.Text = CONFIG.Texts.Redeem
    RedeemButton.TextColor3 = CONFIG.Colors.Accent
    RedeemButton.TextSize = 10
    RedeemButton.Parent = MainFrame

    local redeemCorner = Instance.new("UICorner")
    redeemCorner.CornerRadius = CONFIG.CornerRadius.Button
    redeemCorner.Parent = RedeemButton

    local redeemStroke = Instance.new("UIStroke")
    redeemStroke.Color = CONFIG.Colors.Stroke
    redeemStroke.Thickness = 1
    redeemStroke.Parent = RedeemButton

    BottomRow = Instance.new("Frame")
    BottomRow.Name = CONFIG.Names.BottomRow
    BottomRow.BackgroundTransparency = 1
    BottomRow.Position = CONFIG.Position.BottomRow
    BottomRow.Size = CONFIG.Size.BottomRow
    BottomRow.Parent = MainFrame

    DelayLabel = Instance.new("TextLabel")
    DelayLabel.Name = CONFIG.Names.DelayLabel
    DelayLabel.BackgroundTransparency = 1
    DelayLabel.Position = CONFIG.Position.DelayLabel
    DelayLabel.Size = UDim2.new(0, 48, 1, 0)
    DelayLabel.Font = Enum.Font.GothamBold
    DelayLabel.Text = CONFIG.Texts.DelayLabel
    DelayLabel.TextColor3 = CONFIG.Colors.TextMuted
    DelayLabel.TextSize = 11
    DelayLabel.TextXAlignment = Enum.TextXAlignment.Left
    DelayLabel.Parent = BottomRow

    DelayBox = Instance.new("TextBox")
    DelayBox.Name = CONFIG.Names.DelayBox
    DelayBox.BackgroundColor3 = CONFIG.Colors.ButtonBg
    DelayBox.BackgroundTransparency = CONFIG.Transparency.Button
    DelayBox.BorderSizePixel = 0
    DelayBox.Position = CONFIG.Position.DelayBox
    DelayBox.Size = CONFIG.Size.DelayBox
    DelayBox.ClearTextOnFocus = false
    DelayBox.Font = Enum.Font.GothamBold
    DelayBox.Text = tostring(_delay)
    DelayBox.TextColor3 = CONFIG.Colors.TextInput
    DelayBox.TextSize = 12
    DelayBox.TextXAlignment = Enum.TextXAlignment.Center
    DelayBox.Parent = BottomRow

    local delayCorner = Instance.new("UICorner")
    delayCorner.CornerRadius = CONFIG.CornerRadius.Button
    delayCorner.Parent = DelayBox

    local delayStroke = Instance.new("UIStroke")
    delayStroke.Color = CONFIG.Colors.Stroke
    delayStroke.Thickness = 1
    delayStroke.Parent = DelayBox

    SetButton = Instance.new("TextButton")
    SetButton.Name = CONFIG.Names.SetButton
    SetButton.BackgroundColor3 = CONFIG.Colors.ButtonBg
    SetButton.BorderSizePixel = 0
    SetButton.Position = CONFIG.Position.SetButton
    SetButton.Size = CONFIG.Size.SetButton
    SetButton.AutoButtonColor = true
    SetButton.Font = Enum.Font.GothamBold
    SetButton.Text = CONFIG.Texts.Set
    SetButton.TextColor3 = CONFIG.Colors.Accent
    SetButton.TextSize = 10
    SetButton.Parent = BottomRow

    local setCorner = Instance.new("UICorner")
    setCorner.CornerRadius = CONFIG.CornerRadius.Button
    setCorner.Parent = SetButton

    local setStroke = Instance.new("UIStroke")
    setStroke.Color = CONFIG.Colors.Stroke
    setStroke.Thickness = 1
    setStroke.Parent = SetButton
end

-- // [6] FUNCTIONALITY //
local function setupDragging()
    local dragging, dragInput, dragStart, startPos
    local threshold = UserInputService.TouchEnabled and 10 or 3

    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if dragging then return end
        dragging = true
        dragInput = input
        dragStart = Vector2.new(input.Position.X, input.Position.Y)
        startPos = MainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End
                or input.UserInputState == Enum.UserInputState.Cancel then
                dragging = false
                dragInput = nil
            end
        end)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging or not dragInput then return end
        local ok = (dragInput.UserInputType == Enum.UserInputType.Touch and input == dragInput)
            or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseMovement)
        if not ok then return end
        local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
        if delta.Magnitude < threshold then return end
        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end)
end

local function setupEvents()
    ScanButton.MouseButton1Click:Connect(function()
        _enabled = not _enabled
        saveCfg()
        updateStatusVisual()
        updateScanButton()
        if not _enabled then
            _msgBuffer = {}
            _msgCombined = ""
            if PreviewBox then PreviewBox.Text = "" end
        end
    end)

    ModeButton.MouseButton1Click:Connect(function()
        _modeIndex = (_modeIndex % #CONFIG.Modes) + 1
        _submitAfter = CONFIG.Modes[_modeIndex].Count
        _msgBuffer = {}
        _msgCombined = ""
        if PreviewBox then PreviewBox.Text = "" end
        updateModeButton()
        saveCfg()
    end)

    RedeemButton.MouseButton1Click:Connect(function()
        local code = PreviewBox and PreviewBox.Text or ""
        code = normalizeCode(code)
        if code == "" then return end
        task.spawn(function()
            task.wait(_delay)
            rememberPending(aceCodeBox(), code, true)
            local ok, res = aceRedeem(code)
            local success = ok and (type(res) ~= "table" or res.success or res.Success)
            if not success then
                restoreRejected(aceCodeBox(), code)
                clearPending()
            else
                clearPending()
            end
        end)
    end)

    SetButton.MouseButton1Click:Connect(function()
        local val = tonumber(DelayBox.Text)
        if val and val >= 0 then
            _delay = val
            DelayBox.Text = tostring(_delay)
            saveCfg()
        else
            DelayBox.Text = tostring(_delay)
        end
    end)

    DelayBox.FocusLost:Connect(function()
        local val = tonumber(DelayBox.Text)
        if val and val >= 0 then
            _delay = val
            saveCfg()
        else
            DelayBox.Text = tostring(_delay)
        end
    end)

    UserInputService.TextBoxFocused:Connect(function(box)
        if ScreenGui and box:IsDescendantOf(ScreenGui) then return end
        if box ~= aceCodeBox() then return end
        _focused = box
        _lastBox = box
        watchBox(box)
    end)

    UserInputService.TextBoxFocusReleased:Connect(function(box)
        if ScreenGui and box:IsDescendantOf(ScreenGui) then return end
        local cb = aceCodeBox()
        if box ~= cb and box ~= _lastBox then return end
        if _retypeInvalid and (box == cb or box == _lastBox) then
            local t = box.Text ~= "" and box.Text or _lastNonBlank
            rememberPending(box, t, false)
        end
        if _focused == box then _focused = nil end
    end)

    local function watchFeedback(obj)
        if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
        handleFeedback(obj.Text or "", obj)
        obj:GetPropertyChangedSignal("Text"):Connect(function()
            handleFeedback(obj.Text or "", obj)
            if _riddleSolver and isRiddleText(obj.Text or "") then
                dispatchRiddle(obj.Text)
            end
        end)
    end

    for _, o in ipairs(PlayerGui:GetDescendants()) do
        watchFeedback(o)
    end
    PlayerGui.DescendantAdded:Connect(function(o)
        task.wait(0.01) -- 0.01s — faster feedback detection
        watchFeedback(o)
    end)

    local notifyRemote = resolveNotifyRemote()
    if notifyRemote then
        if getgenv then
            local prev = getgenv().ACECodeSniperNotifyConnection
            if prev then pcall(function() prev:Disconnect() end) end
        end
        local _cb = function(...)
            if not _enabled or not isAnnouncement(...) then return end
            pcall(onAnnouncement, ...)
        end
        listenConn = notifyRemote.OnClientEvent:Connect(
            (newcclosure and newcclosure(_cb)) or _cb
        )
        if getgenv then
            getgenv().ACECodeSniperNotifyConnection = listenConn
        end
    end
end

-- // [7] INITIALIZATION //
loadCfg()
createGUI()
setupDragging()
setupEvents()
updateStatusVisual()
updateScanButton()
updateModeButton()

if getgenv then
    getgenv().StopAura = function()
        if listenConn then
            pcall(function() listenConn:Disconnect() end)
            listenConn = nil
        end
        if getgenv().ACECodeSniperNotifyConnection then
            pcall(function() getgenv().ACECodeSniperNotifyConnection:Disconnect() end)
            getgenv().ACECodeSniperNotifyConnection = nil
        end
        if ScreenGui then
            ScreenGui:Destroy()
        end
    end
end
