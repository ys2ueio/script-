--[[
    fake_env.lua — Simulateur Roblox pour Lua 5.4 standard
    Usage : lua5.4 fake_env.lua <script.lua>
    Auteur : MHDevTools (généré pour MoonHub V16)
--]]

-- ─────────────────────────────────────────────────────────────
--  UTILITAIRES INTERNES
-- ─────────────────────────────────────────────────────────────

local _startTime = os.clock()

local function _log(tag, msg)
    io.write(string.format("[%s] %s\n", tag, tostring(msg)))
end

-- Instance générique avec métatables permissives
local function _makeInstance(className)
    local props = {ClassName = className, Name = className}
    local conns = {}
    local children = {}

    local inst = {}
    local mt = {}

    mt.__index = function(t, k)
        if props[k] ~= nil then return props[k] end
        -- signal stub pour .Event, .Changed, etc.
        if type(k) == "string" and (k:match("^On") or k:match("Changed$") or k:match("Added$") or k:match("Removed$") or k:match("Fired$") or k:match("Stepped$") or k:match("ed$")) then
            local sig = {
                Connect = function(self, fn)
                    local c = {_fn = fn, _connected = true,
                        Disconnect = function(self2) self2._connected = false end,
                        Wait = function() return end,
                    }
                    table.insert(conns, c)
                    return c
                end,
                Wait = function() return end,
                Fire = function(self, ...) end,
            }
            props[k] = sig
            return sig
        end
        -- méthodes génériques
        return function(...) return _makeInstance(k) end
    end

    mt.__newindex = function(t, k, v)
        props[k] = v
    end

    mt.__tostring = function() return className end

    setmetatable(inst, mt)

    -- Méthodes Instance standard
    rawset(inst, "GetChildren",     function() return children end)
    rawset(inst, "GetDescendants",  function() return children end)
    rawset(inst, "FindFirstChild",  function(_, n, _r)
        for _, c in ipairs(children) do
            if rawget(c, "Name") == n or (getmetatable(c) and c.Name == n) then return c end
        end
        return nil
    end)
    rawset(inst, "FindFirstChildOfClass", function(_, cls)
        for _, c in ipairs(children) do if c.ClassName == cls then return c end end
        return nil
    end)
    rawset(inst, "WaitForChild", function(_, n, _t)
        for _, c in ipairs(children) do if c.Name == n then return c end end
        return _makeInstance(n)
    end)
    rawset(inst, "IsA",          function(_, cls) return className == cls end)
    rawset(inst, "Destroy",      function() end)
    rawset(inst, "Clone",        function() return _makeInstance(className) end)
    rawset(inst, "GetService",   function(_, svc) return _makeInstance(svc) end)
    rawset(inst, "Remove",       function() end)

    return inst
end

-- ─────────────────────────────────────────────────────────────
--  TYPES MATHÉMATIQUES
-- ─────────────────────────────────────────────────────────────

local Vector3 = {}
Vector3.__index = Vector3
Vector3.new = function(x,y,z)
    return setmetatable({X=x or 0, Y=y or 0, Z=z or 0,
        Magnitude = math.sqrt((x or 0)^2+(y or 0)^2+(z or 0)^2)
    }, Vector3)
end
Vector3.zero  = Vector3.new(0,0,0)
Vector3.one   = Vector3.new(1,1,1)
Vector3.__tostring = function(v) return ("Vector3(%g,%g,%g)"):format(v.X,v.Y,v.Z) end
Vector3.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
Vector3.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
Vector3.__mul = function(a,b)
    if type(b)=="number" then return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
    return Vector3.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
end
function Vector3:Lerp(b,t) return Vector3.new(self.X+(b.X-self.X)*t,self.Y+(b.Y-self.Y)*t,self.Z+(b.Z-self.Z)*t) end
function Vector3:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function Vector3:Cross(b) return Vector3.new(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end

local Vector2 = {}
Vector2.__index = Vector2
Vector2.new = function(x,y) return setmetatable({X=x or 0,Y=y or 0}, Vector2) end
Vector2.__tostring = function(v) return ("Vector2(%g,%g)"):format(v.X,v.Y) end

local UDim  = {}; UDim.__index  = UDim
UDim.new = function(s,o) return setmetatable({Scale=s or 0,Offset=o or 0}, UDim) end

local UDim2 = {}; UDim2.__index = UDim2
UDim2.new = function(xs,xo,ys,yo)
    return setmetatable({
        X=UDim.new(xs,xo), Y=UDim.new(ys,yo),
        Width=UDim.new(xs,xo), Height=UDim.new(ys,yo)
    }, UDim2)
end
UDim2.fromScale  = function(x,y) return UDim2.new(x,0,y,0) end
UDim2.fromOffset = function(x,y) return UDim2.new(0,x,0,y) end
UDim2.__tostring = function(v) return ("UDim2{%g,%g,%g,%g}"):format(v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset) end
UDim2.__add = function(a,b) return UDim2.new(a.X.Scale+b.X.Scale,a.X.Offset+b.X.Offset,a.Y.Scale+b.Y.Scale,a.Y.Offset+b.Y.Offset) end

local Color3 = {}; Color3.__index = Color3
Color3.new = function(r,g,b) return setmetatable({R=r or 0,G=g or 0,B=b or 0}, Color3) end
Color3.fromRGB = function(r,g,b) return Color3.new((r or 0)/255,(g or 0)/255,(b or 0)/255) end
Color3.fromHSV = function(h,s,v)
    -- simple conversion
    local r,g,b = 0,0,0
    local i = math.floor(h*6); local f = h*6-i
    local p,q,t2 = v*(1-s),v*(1-f*s),v*(1-(1-f)*s)
    i = i%6
    if i==0 then r,g,b=v,t2,p elseif i==1 then r,g,b=q,v,p
    elseif i==2 then r,g,b=p,v,t2 elseif i==3 then r,g,b=p,q,v
    elseif i==4 then r,g,b=t2,p,v else r,g,b=v,p,q end
    return Color3.new(r,g,b)
end
Color3.__tostring = function(c) return ("Color3(%g,%g,%g)"):format(c.R,c.G,c.B) end

local CFrame = {}; CFrame.__index = CFrame
CFrame.new = function(x,y,z,...)
    local cf = setmetatable({X=x or 0,Y=y or 0,Z=z or 0,
        Position=Vector3.new(x,y,z),
        LookVector=Vector3.new(0,0,-1),
        UpVector=Vector3.new(0,1,0),
        RightVector=Vector3.new(1,0,0),
    }, CFrame)
    return cf
end
CFrame.identity = CFrame.new(0,0,0)
CFrame.lookAt  = function(eye,target,_up)
    local cf = CFrame.new(eye.X,eye.Y,eye.Z)
    cf.LookVector = Vector3.new(target.X-eye.X,target.Y-eye.Y,target.Z-eye.Z)
    return cf
end
function CFrame:Lerp(b,t) return CFrame.new(self.X+(b.X-self.X)*t,self.Y+(b.Y-self.Y)*t,self.Z+(b.Z-self.Z)*t) end
function CFrame:ToObjectSpace(b) return CFrame.new(b.X-self.X,b.Y-self.Y,b.Z-self.Z) end
function CFrame:PointToWorldSpace(v) return Vector3.new(self.X+v.X,self.Y+v.Y,self.Z+v.Z) end
CFrame.__mul = function(a,b)
    if getmetatable(b)==Vector3 then return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
    return CFrame.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)
end
CFrame.__tostring = function(c) return ("CFrame(%g,%g,%g)"):format(c.X,c.Y,c.Z) end

local TweenInfo = {}; TweenInfo.__index = TweenInfo
TweenInfo.new = function(t,es,ed,rc,rev,dl)
    return setmetatable({Time=t or 1,EasingStyle=es,EasingDirection=ed,
        RepeatCount=rc or 0,Reverses=rev or false,DelayTime=dl or 0}, TweenInfo)
end

local Rect = {}; Rect.__index = Rect
Rect.new = function(x0,y0,x1,y1) return setmetatable({Min=Vector2.new(x0,y0),Max=Vector2.new(x1,y1)}, Rect) end

-- ─────────────────────────────────────────────────────────────
--  ENUM (validé contre la liste Roblox réelle)
-- ─────────────────────────────────────────────────────────────

local _enumValues = {
    Font = {"Legacy","Arial","ArialBold","SourceSans","SourceSansBold","SourceSansLight",
            "SourceSansItalic","SourceSansSemibold","Roboto","RobotoBold","RobotoMono",
            "GothamBold","GothamBook","Gotham","GothamMedium","GothamBlack",
            "AmaticSC","Bangers","Creepster","DenkOne","Fondamento","FredokaOne",
            "Grenze","IndieFlower","JosefinSans","Kalam","LuckiestGuy","Merriweather",
            "Michroma","Nunito","Oswald","PatrickHand","PermanentMarker","Roboto",
            "RobotoCondensed","RobotoMono","SciFly","SpecialElite","TitilliumWeb",
            "Ubuntu","Zekton","Unknown","BuilderSans"},
    EasingStyle = {"Linear","Sine","Back","Bounce","Elastic","Exponential","Circular","Cubic","Quad","Quart","Quint"},
    EasingDirection = {"In","Out","InOut"},
    KeyCode = {"W","A","S","D","E","Q","R","F","G","H","I","J","K","L","M","N","O","P",
               "T","U","V","X","Y","Z","Space","Return","Escape","Tab","Backspace",
               "LeftShift","RightShift","LeftControl","RightControl","LeftAlt","RightAlt",
               "Up","Down","Left","Right","Zero","One","Two","Three","Four","Five","Six",
               "Seven","Eight","Nine","F1","F2","F3","F4","F5","F6","F7","F8","F9","F10",
               "F11","F12","ButtonX","ButtonY","ButtonA","ButtonB","Unknown"},
    UserInputType = {"Keyboard","MouseButton1","MouseButton2","MouseButton3","MouseMovement",
                     "MouseWheel","Touch","Gamepad1","Gamepad2","TextInput","None","Unknown"},
    NormalId = {"Top","Bottom","Front","Back","Left","Right"},
    PartType = {"Block","Sphere","Cylinder","Wedge","CornerWedge"},
    SurfaceType = {"Smooth","Glue","Weld","Studs","Inlet","Universal","Hinge","Motor"},
    Material = {"SmoothPlastic","Plastic","Wood","WoodPlanks","Marble","Granite","Brick",
                "Cobblestone","Concrete","CorrodedMetal","DiamondPlate","Foil","Grass",
                "Ice","Neon","Metal","Pebble","Sand","Fabric","Glass","SandBrick",
                "Slate","Basalt","CrackedLava","Glacier","Ground","LeafyGrass","Limestone",
                "Mud","Pavement","Rock","Salt","Snow","Sandstone","Air","Water"},
    HumanoidStateType = {"Freefall","Jumping","Landed","Running","Seated","Swimming",
                          "Climbing","GettingUp","Ragdoll","StrafingNoPhysics","PlatformStanding",
                          "Dead","Physics","None","Running","RunningNoPhysics"},
    RenderFidelity = {"Automatic","Performance","Precise"},
    TextXAlignment = {"Left","Center","Right"},
    TextYAlignment = {"Top","Center","Bottom"},
    ScaleType = {"Stretch","Slice","Tile","Fit","Crop"},
    BorderMode = {"Outline","Middle","Inset"},
    AutomaticSize = {"None","X","Y","XY"},
    SizeConstraint = {"RelativeXY","RelativeXX","RelativeYY"},
    ZIndexBehavior = {"Global","Sibling"},
    AnimationPriority = {"Core","Idle","Movement","Action","Action2","Action3","Action4"},
}

local Enum = setmetatable({}, {
    __index = function(t, enumName)
        local values = _enumValues[enumName]
        local enumTbl = setmetatable({}, {
            __index = function(_, itemName)
                -- si valeur connue, la retourner
                if values then
                    for _, v in ipairs(values) do
                        if v == itemName then
                            return {Name=itemName, Value=itemName, EnumType=enumName}
                        end
                    end
                    -- valeur inconnue mais enum connu → warn
                    _log("WARN", ("Enum.%s.%s n'existe pas dans Roblox"):format(enumName, tostring(itemName)))
                end
                return {Name=itemName, Value=itemName, EnumType=enumName}
            end,
            __tostring = function() return "Enum."..enumName end,
        })
        rawset(t, enumName, enumTbl)
        return enumTbl
    end,
})

-- ─────────────────────────────────────────────────────────────
--  SERVICES ROBLOX
-- ─────────────────────────────────────────────────────────────

-- Humanoid stub
local function _makeHumanoid()
    local h = _makeInstance("Humanoid")
    h.Health        = 100
    h.MaxHealth     = 100
    h.WalkSpeed     = 16
    h.JumpPower     = 50
    h.JumpHeight    = 7.2
    h.RootPart      = _makeInstance("HumanoidRootPart")
    h.HumanoidDescription = _makeInstance("HumanoidDescription")
    rawset(h, "GetState",   function() return {Value="Running"} end)
    rawset(h, "ChangeState",function() end)
    rawset(h, "Move",       function() end)
    rawset(h, "MoveTo",     function() end)
    rawset(h, "LoadAnimation", function() return {Play=function()end,Stop=function()end,Length=1,AdjustSpeed=function()end} end)
    return h
end

-- Character stub
local function _makeCharacter(name)
    local char = _makeInstance("Model")
    char.Name = name or "Character"
    local hrp = _makeInstance("HumanoidRootPart")
    hrp.Position = Vector3.new(0,5,0)
    hrp.CFrame   = CFrame.new(0,5,0)
    rawset(char, "HumanoidRootPart", hrp)
    rawset(char, "Humanoid", _makeHumanoid())
    rawset(char, "Head", _makeInstance("Part"))
    rawset(char, "Torso", _makeInstance("Part"))
    rawset(char, "FindFirstChild", function(_, n)
        local t = {HumanoidRootPart=hrp, Humanoid=char.Humanoid, Head=char.Head}
        return t[n] or _makeInstance(n)
    end)
    rawset(char, "FindFirstChildOfClass", function(_, cls)
        if cls == "Humanoid" then return char.Humanoid end
        return _makeInstance(cls)
    end)
    rawset(char, "WaitForChild", function(_, n, _t) return char:FindFirstChild(n) or _makeInstance(n) end)
    return char
end

-- Player stub
local function _makePlayer(name, uid)
    local p = _makeInstance("Player")
    p.Name        = name or "LocalPlayer"
    p.DisplayName = name or "LocalPlayer"
    p.UserId      = uid  or 12345678
    p.Team        = nil
    p.Character   = _makeCharacter(name)
    p.Backpack     = _makeInstance("Backpack")
    p.PlayerGui    = _makeInstance("PlayerGui")
    p.PlayerScripts= _makeInstance("PlayerScripts")
    rawset(p, "GetMouse",   function() return {
        X=0,Y=0,Hit=CFrame.new(0,0,0),Target=nil,
        Button1Down={Connect=function(_,fn) return {Disconnect=function()end} end},
        Move={Connect=function(_,fn) return {Disconnect=function()end} end},
    } end)
    rawset(p, "IsInGroup",  function() return false end)
    rawset(p, "GetRankInGroup", function() return 0 end)
    rawset(p, "Kick",       function() end)
    return p
end

local _localPlayer = _makePlayer("LocalPlayer", 12345678)
local _players     = {}
for i=1,4 do _players[i] = _makePlayer("Player"..i, 10000000+i) end
table.insert(_players, _localPlayer)

local Players = _makeInstance("Players")
Players.LocalPlayer = _localPlayer
rawset(Players, "GetPlayers",         function() return _players end)
rawset(Players, "GetPlayerFromCharacter", function(_, char)
    for _, p in ipairs(_players) do if p.Character == char then return p end end
    return nil
end)
rawset(Players, "GetPlayerByUserId",  function(_, uid)
    for _, p in ipairs(_players) do if p.UserId == uid then return p end end
    return nil
end)

-- Workspace
local workspace = _makeInstance("Workspace")
workspace.CurrentCamera = _makeInstance("Camera")
workspace.CurrentCamera.CFrame   = CFrame.new(0,10,-10)
workspace.CurrentCamera.FieldOfView = 70
rawset(workspace, "FindPartOnRay",    function() return nil, Vector3.new(0,0,0), Vector3.new(0,1,0), nil end)
rawset(workspace, "FindPartOnRayWithIgnoreList", function() return nil, Vector3.new(0,0,0), Vector3.new(0,1,0), nil end)
rawset(workspace, "Raycast",          function() return nil end)

-- RunService
local RunService = _makeInstance("RunService")
rawset(RunService, "IsServer",  function() return false end)
rawset(RunService, "IsClient",  function() return true  end)
rawset(RunService, "IsStudio",  function() return false end)
-- Les signaux RunService retournent des connexions inertes
local function _heartbeatSig()
    return {Connect=function(_,fn) return {Disconnect=function()end} end, Wait=function() return 0.016 end}
end
RunService.Heartbeat    = _heartbeatSig()
RunService.RenderStepped= _heartbeatSig()
RunService.Stepped      = _heartbeatSig()

-- UserInputService
local UserInputService = _makeInstance("UserInputService")
rawset(UserInputService, "GetKeysPressed",  function() return {} end)
rawset(UserInputService, "IsKeyDown",       function() return false end)
rawset(UserInputService, "IsMouseButtonPressed", function() return false end)
rawset(UserInputService, "GetMouseLocation", function() return Vector2.new(960,540) end)
UserInputService.InputBegan = {Connect=function(_,fn) return {Disconnect=function()end} end}
UserInputService.InputEnded = {Connect=function(_,fn) return {Disconnect=function()end} end}
UserInputService.InputChanged= {Connect=function(_,fn) return {Disconnect=function()end} end}

-- TweenService
local TweenService = _makeInstance("TweenService")
rawset(TweenService, "Create", function(_, inst, info, props)
    return {
        Play   = function() end,
        Cancel = function() end,
        Pause  = function() end,
        Completed = {Connect=function(_,fn) return {Disconnect=function()end} end},
    }
end)

-- HttpService
local HttpService = _makeInstance("HttpService")
rawset(HttpService, "JSONEncode", function(_, t)
    -- encodeur JSON minimal
    local function enc(v)
        local tv = type(v)
        if tv == "nil" then return "null"
        elseif tv == "boolean" then return tostring(v)
        elseif tv == "number" then return tostring(v)
        elseif tv == "string" then return '"'..v:gsub('"','\\"'):gsub('\n','\\n')..'"'
        elseif tv == "table" then
            -- array ou objet ?
            local isArr = #v > 0
            if isArr then
                local parts = {}; for _, vv in ipairs(v) do parts[#parts+1] = enc(vv) end
                return "["..table.concat(parts,",").."]"
            else
                local parts = {}; for k2,vv in pairs(v) do parts[#parts+1] = '"'..tostring(k2)..'":'..enc(vv) end
                return "{"..table.concat(parts,",").."}"
            end
        end
        return "null"
    end
    return enc(t)
end)
rawset(HttpService, "JSONDecode", function(_, s)
    -- décodeur très basique (suffisant pour readfile JSON de settings)
    local ok, res = pcall(load("return "..s:gsub(':%s*true','= true'):gsub(':%s*false','= false'):gsub(':%s*null','= nil'):gsub('"(%w+)"%s*:','["%1"]='):gsub('%[%[','{')):gsub('%]%]','}')))
    if ok then return res end
    return {}
end)
rawset(HttpService, "RequestAsync", function() return {Success=false,StatusCode=0,Body=""} end)
rawset(HttpService, "GetAsync",     function() return "" end)

-- Instance.new global
local Instance = {}
Instance.new = function(className, parent)
    local inst = _makeInstance(className)
    if parent then
        -- attacher à parent si on peut
        local ch = rawget(parent, "_children")
        if ch then table.insert(ch, inst) end
    end
    return inst
end

-- game stub
local game = _makeInstance("DataModel")
game.Name = "Game"
rawset(game, "GetService", function(_, svc)
    local svcs = {
        Players             = Players,
        RunService          = RunService,
        UserInputService    = UserInputService,
        TweenService        = TweenService,
        HttpService         = HttpService,
        Workspace           = workspace,
        CoreGui             = _makeInstance("CoreGui"),
        StarterGui          = _makeInstance("StarterGui"),
        ReplicatedStorage   = _makeInstance("ReplicatedStorage"),
        RobloxReplicatedStorage = _makeInstance("RobloxReplicatedStorage"),
        ServerStorage       = _makeInstance("ServerStorage"),
        Teams               = _makeInstance("Teams"),
        Lighting            = _makeInstance("Lighting"),
        SoundService        = _makeInstance("SoundService"),
        TextService         = _makeInstance("TextService"),
        GuiService          = _makeInstance("GuiService"),
        VRService           = _makeInstance("VRService"),
        PhysicsService      = _makeInstance("PhysicsService"),
        NetworkClient       = _makeInstance("NetworkClient"),
        NetworkServer       = _makeInstance("NetworkServer"),
        CollectionService   = _makeInstance("CollectionService"),
        ContextActionService= _makeInstance("ContextActionService"),
        PathfindingService  = _makeInstance("PathfindingService"),
        MarketplaceService  = _makeInstance("MarketplaceService"),
        DataStoreService    = _makeInstance("DataStoreService"),
        MemoryStoreService  = _makeInstance("MemoryStoreService"),
        BadgeService        = _makeInstance("BadgeService"),
        ChatService         = _makeInstance("Chat"),
        Chat                = _makeInstance("Chat"),
        LogService          = _makeInstance("LogService"),
        KeyframeSequenceProvider = _makeInstance("KeyframeSequenceProvider"),
        AnimationClipProvider= _makeInstance("AnimationClipProvider"),
        InsertService       = _makeInstance("InsertService"),
        Selection           = _makeInstance("Selection"),
        TeleportService     = _makeInstance("TeleportService"),
        GroupService        = _makeInstance("GroupService"),
        PolicyService       = _makeInstance("PolicyService"),
        LocalizationService = _makeInstance("LocalizationService"),
    }
    return svcs[svc] or _makeInstance(svc)
end)

-- ─────────────────────────────────────────────────────────────
--  API GLOBALES ROBLOX
-- ─────────────────────────────────────────────────────────────

local _fileStore = {}

local function warn(...)
    local args = {...}
    for i,v in ipairs(args) do args[i] = tostring(v) end
    io.write("[WARN] " .. table.concat(args," ") .. "\n")
end

local function print(...)
    local args = {...}
    for i,v in ipairs(args) do args[i] = tostring(v) end
    io.write(table.concat(args," ") .. "\n")
end

local function tick()
    return os.clock() + _startTime
end

local function time()
    return os.clock()
end

local function wait(n)
    -- simulateur : on ne bloque pas vraiment
    return n or 0
end

local task = {
    wait   = function(n) return n or 0 end,
    delay  = function(n, fn, ...) local ok,err = pcall(fn, ...) if not ok then _log("task.delay ERR", err) end end,
    spawn  = function(fn, ...) local ok,err = pcall(fn, ...) if not ok then _log("task.spawn ERR", err) end end,
    defer  = function(fn, ...) local ok,err = pcall(fn, ...) if not ok then _log("task.defer ERR", err) end end,
    cancel = function(t) end,
    synchronize = function() end,
}

local function writefile(path, content)
    _fileStore[path] = content
    -- écriture optionnelle sur disque pour persistance
    local f = io.open(path, "w")
    if f then f:write(content); f:close() end
end

local function readfile(path)
    if _fileStore[path] then return _fileStore[path] end
    local f = io.open(path, "r")
    if f then local c = f:read("*a"); f:close(); return c end
    return ""
end

local function isfile(path)
    if _fileStore[path] then return true end
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

local function isfolder(path) return false end
local function makefolder(path) end
local function listfiles(path) return {} end
local function appendfile(path, content)
    local cur = readfile(path)
    writefile(path, cur..content)
end

local function loadstring(src, chunkname)
    local fn, err = load(src, chunkname or "loadstring", "t", _G)
    if fn then return fn end
    return nil, err
end

local function getrenv() return _G end
local function getgenv() return _G end
local function getsenv(scr) return _G end
local function getrawmetatable(t) return getmetatable(t) end
local function setrawmetatable(t, mt) return setmetatable(t, mt) end
local function hookmetamethod(obj, name, fn) end
local function hookfunction(fn, hook) return fn end
local function newproxy(useMetatable)
    if useMetatable then return setmetatable({},{}) end
    return {}
end

local function typeof(v)
    local mt = getmetatable(v)
    if mt == Vector3 then return "Vector3" end
    if mt == Vector2 then return "Vector2" end
    if mt == CFrame  then return "CFrame"  end
    if mt == Color3  then return "Color3"  end
    if mt == UDim2   then return "UDim2"   end
    if mt == UDim    then return "UDim"    end
    if mt == TweenInfo then return "TweenInfo" end
    return type(v)
end

-- Globals executor-like
local function getconnections(sig) return {} end
local function firesignal(sig, ...) end
local function decompile(fn) return "-- decompiled" end
local function checkcaller() return false end
local function syn = nil  -- not defined intentionally

-- shared / script stubs
local shared = {}
local script = _makeInstance("LocalScript")
script.Name = "MoonHub"

-- ─────────────────────────────────────────────────────────────
--  ENVIRONNEMENT GLOBAL (_G)
-- ─────────────────────────────────────────────────────────────

local _env = {
    -- std Lua
    pairs=pairs, ipairs=ipairs, next=next, select=select,
    type=type, tostring=tostring, tonumber=tonumber,
    rawget=rawget, rawset=rawset, rawequal=rawequal, rawlen=rawlen,
    setmetatable=setmetatable, getmetatable=getmetatable,
    unpack=table.unpack, table=table, string=string, math=math,
    io=io, os=os, pcall=pcall, xpcall=xpcall, error=error, assert=assert,
    load=load, loadfile=loadfile, dofile=dofile,
    require=require, coroutine=coroutine, utf8=utf8,
    collectgarbage=collectgarbage, _VERSION=_VERSION,

    -- overrides
    print=print, warn=warn,

    -- Roblox types
    Instance=Instance, Vector3=Vector3, Vector2=Vector2,
    UDim=UDim, UDim2=UDim2, Color3=Color3, CFrame=CFrame,
    TweenInfo=TweenInfo, Rect=Rect, Enum=Enum,

    -- Roblox globals
    game=game, workspace=workspace, workspace=workspace,
    Players=Players, script=script, shared=shared,
    tick=tick, time=time, wait=wait, task=task,
    typeof=typeof,

    -- API exécuteurs
    writefile=writefile, readfile=readfile, isfile=isfile,
    isfolder=isfolder, makefolder=makefolder, listfiles=listfiles,
    appendfile=appendfile, loadstring=loadstring,
    getrenv=getrenv, getgenv=getgenv, getsenv=getsenv,
    getrawmetatable=getrawmetatable, setrawmetatable=setrawmetatable,
    hookmetamethod=hookmetamethod, hookfunction=hookfunction,
    newproxy=newproxy, getconnections=getconnections,
    firesignal=firesignal, decompile=decompile, checkcaller=checkcaller,

    -- abréviations courantes
    LP=Players.LocalPlayer,
    UIS=UserInputService,
    RS=RunService,
    TS=TweenService,
}
_env._G = _env

-- propager dans _G Lua standard aussi
for k,v in pairs(_env) do _G[k] = v end

-- ─────────────────────────────────────────────────────────────
--  MHDevTools
-- ─────────────────────────────────────────────────────────────

local MHDevTools = {}

-- 6 pièges connus dans les scripts hub Roblox/Luau
local _TRAPS = {
    {
        id   = "GLOBAL_FUNCTION_SHADOW",
        desc = "Redéclaration locale d'une fonction globale déjà définie dans le même scope",
        pat  = "^%s*local%s+(%a[%w_]*)%s*=%s*%1%s*$",
        -- ex: local warn = warn
        check = function(lines)
            local hits = {}
            for i, line in ipairs(lines) do
                local name = line:match("^%s*local%s+(%a[%w_]*)%s*=%s*%1%s*$")
                if name then
                    hits[#hits+1] = {line=i, msg=("Redéclaration inutile 'local %s = %s'"):format(name,name)}
                end
            end
            return hits
        end,
    },
    {
        id   = "ORPHAN_TABLE_FIELD",
        desc = "Virgule en fin d'entrée de table sans champ suivant (orphan field)",
        check = function(lines)
            local hits = {}
            -- chercher pattern: clé = valeur, suivie de } sur la ligne suivante
            for i=1, #lines-1 do
                local l = lines[i]; local n = lines[i+1]
                if l:match(",%s*$") and n:match("^%s*}") then
                    hits[#hits+1] = {line=i, msg="Virgule orpheline avant '}'"}
                end
            end
            return hits
        end,
    },
    {
        id   = "TASK_CANCEL_MISSING",
        desc = "task.spawn stocké sans task.cancel() correspondant dans le cleanup",
        check = function(lines)
            local hits = {}
            local spawns, cancels = {}, {}
            for i, line in ipairs(lines) do
                if line:match("task%.spawn") and line:match("=") then
                    local var = line:match("([%a_][%w_]*)%s*=%s*task%.spawn")
                    if var then spawns[var] = i end
                end
                if line:match("task%.cancel%(") then
                    local var = line:match("task%.cancel%(([%a_][%w_]*)%)")
                    if var then cancels[var] = true end
                end
            end
            for var, li in pairs(spawns) do
                if not cancels[var] then
                    hits[#hits+1] = {line=li, msg=("Thread '%s' = task.spawn(...) sans task.cancel correspondant"):format(var)}
                end
            end
            return hits
        end,
    },
    {
        id   = "RENDERSTEP_NO_THROTTLE",
        desc = "RenderStepped:Connect sans throttle tick() (peut saturer à 60+ appels/s)",
        check = function(lines)
            local hits = {}
            for i, line in ipairs(lines) do
                if line:match("RenderStepped:Connect") then
                    -- chercher tick() dans les 5 lignes suivantes
                    local found = false
                    for j=i, math.min(i+5, #lines) do
                        if lines[j]:match("tick%(%)") or lines[j]:match("os%.clock") then
                            found = true; break
                        end
                    end
                    if not found then
                        hits[#hits+1] = {line=i, msg="RenderStepped:Connect sans throttle tick() détecté dans les 5 lignes suivantes"}
                    end
                end
            end
            return hits
        end,
    },
    {
        id   = "ENUM_KEYCODE_STRING",
        desc = "Comparaison de KeyCode avec une string au lieu de Enum.KeyCode.X",
        check = function(lines)
            local hits = {}
            for i, line in ipairs(lines) do
                -- ex: e.KeyCode == "W"  ou input.KeyCode == "Space"
                if line:match('KeyCode%s*==%s*"') or line:match('"[A-Z][%w]*"%s*==%s*KeyCode') then
                    hits[#hits+1] = {line=i, msg="Comparaison KeyCode avec string littérale (utiliser Enum.KeyCode.X)"}
                end
            end
            return hits
        end,
    },
    {
        id   = "WRITEFILE_NO_PCALL",
        desc = "writefile() appelé sans pcall (peut planter si disque indisponible)",
        check = function(lines)
            local hits = {}
            for i, line in ipairs(lines) do
                if line:match("writefile%(") and not line:match("pcall") then
                    -- vérifier que ce n'est pas dans un pcall englobant
                    local inPcall = false
                    for j = math.max(1,i-3), i do
                        if lines[j]:match("pcall%(") or lines[j]:match("xpcall%(") then
                            inPcall = true; break
                        end
                    end
                    if not inPcall then
                        hits[#hits+1] = {line=i, msg="writefile() sans pcall — risque de crash si accès disque interdit"}
                    end
                end
            end
            return hits
        end,
    },
}

function MHDevTools.lint(path)
    local f = io.open(path, "r")
    if not f then
        return nil, "Fichier introuvable : "..path
    end
    local src = f:read("*a"); f:close()
    local lines = {}
    for l in (src.."\n"):gmatch("([^\n]*)\n") do lines[#lines+1] = l end

    local total = 0
    local report = {}
    for _, trap in ipairs(_TRAPS) do
        local hits = trap.check(lines)
        if #hits > 0 then
            table.insert(report, {id=trap.id, desc=trap.desc, hits=hits})
            total = total + #hits
        end
    end

    if total == 0 then
        io.write("[LINT] ✅ Aucun piège détecté dans "..path.."\n")
    else
        io.write(("[LINT] ⚠️  %d problème(s) dans %s :\n"):format(total, path))
        for _, r in ipairs(report) do
            io.write(("  [%s] %s\n"):format(r.id, r.desc))
            for _, h in ipairs(r.hits) do
                io.write(("    ligne %d : %s\n"):format(h.line, h.msg))
            end
        end
    end
    return report
end

function MHDevTools.checkLocals(path)
    local f = io.open(path, "r")
    if not f then return nil, "Fichier introuvable : "..path end
    local src = f:read("*a"); f:close()

    -- compter les déclarations 'local' de variables (heuristique)
    local count = 0
    local lines = {}
    for l in (src.."\n"):gmatch("([^\n]*)\n") do
        lines[#lines+1] = l
        -- local simple, local avec multi-assign, local function
        if l:match("^%s*local%s+[%a_]") then count = count + 1 end
    end

    io.write(("[LOCALS] %d déclarations 'local' trouvées (limite Luau : 200 par fonction)\n"):format(count))
    if count > 180 then
        io.write("[LOCALS] ⚠️  Approche de la limite — risque de 'too many local variables'\n")
    else
        io.write("[LOCALS] ✅ OK\n")
    end
    return count
end

function MHDevTools.runFile(path)
    local f = io.open(path, "r")
    if not f then
        io.write("[RUN] ❌ Fichier introuvable : "..path.."\n")
        return false, "Fichier introuvable"
    end
    local src = f:read("*a"); f:close()

    -- charger dans l'environnement simulé
    local chunk, loadErr = load(src, "@"..path, "t", _env)
    if not chunk then
        io.write(("[RUN] ❌ Erreur de syntaxe : %s\n"):format(tostring(loadErr)))
        return false, loadErr
    end

    local ok, runErr = xpcall(chunk, function(err)
        return debug.traceback(tostring(err), 2)
    end)

    if ok then
        io.write("[RUN] ✅ Exécution terminée sans erreur\n")
        return true
    else
        io.write(("[RUN] ❌ Erreur d'exécution :\n%s\n"):format(tostring(runErr)))
        return false, runErr
    end
end

function MHDevTools.fullCheck(path)
    io.write(("\n══════════════ MHDevTools.fullCheck : %s ══════════════\n"):format(path))
    io.write("\n─── 1/3  LINT ───────────────────────────────────────────\n")
    MHDevTools.lint(path)

    io.write("\n─── 2/3  LOCALS ─────────────────────────────────────────\n")
    MHDevTools.checkLocals(path)

    io.write("\n─── 3/3  EXÉCUTION ──────────────────────────────────────\n")
    local ok, err = MHDevTools.runFile(path)

    io.write("\n─────────────────────────────────────────────────────────\n")
    if ok then
        io.write("✅ Prêt à livrer\n")
    else
        io.write("❌ Corrections nécessaires avant livraison\n")
        if err then
            io.write("   → "..tostring(err):match("([^\n]+)").."\n")
        end
    end
    io.write("═════════════════════════════════════════════════════════\n\n")
    return ok
end

-- ─────────────────────────────────────────────────────────────
--  POINT D'ENTRÉE
-- ─────────────────────────────────────────────────────────────

-- Exposer MHDevTools globalement
_env.MHDevTools = MHDevTools
_G.MHDevTools   = MHDevTools

local target = arg and arg[1]
if target then
    MHDevTools.fullCheck(target)
else
    io.write("Usage : lua5.4 fake_env.lua <script.lua>\n")
    io.write("Outils disponibles :\n")
    io.write("  MHDevTools.lint(path)        — détecte 6 pièges\n")
    io.write("  MHDevTools.checkLocals(path) — vérifie limite 200 locals\n")
    io.write("  MHDevTools.runFile(path)     — exécute et capture les erreurs\n")
    io.write("  MHDevTools.fullCheck(path)   — lint + locals + exécution\n")
end
