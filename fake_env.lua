--[[
    fake_env.lua — Simulateur d'environnement Roblox pour MoonHub_v16.lua

    Usage (liblua5.4 ou lua5.4 en CLI) :
        lua5.4 run_test.lua

    Ce fichier construit un environnement minimal qui imite l'API Roblox
    pour permettre l'exécution du script sans le vrai client Roblox.

    Limites :
      - Ne vérifie pas la logique métier (steal, aimbot, etc.)
      - Ne simule pas les comportements spécifiques aux executors
        (hookfunction, syn.protect_gui, sethiddenproperty...)
      - task.wait() est un no-op (pas de scheduler de frames)
      - Les connexions RunService/UIS sont stockées mais jamais déclenchées
]]

-- ============================================================
-- Utilitaires internes
-- ============================================================

local function makeInstance(className)
    local props = {}
    local children = {}
    local connections = {}

    local inst = {}
    local mt = {}

    mt.__index = function(t, k)
        if props[k] ~= nil then return props[k] end
        -- Méthodes universelles
        if k == "Connect" or k == "connect" then
            return function(self, fn)
                local conn = { Connected = true, _fn = fn }
                conn.Disconnect = function(self) self.Connected = false end
                table.insert(connections, conn)
                return conn
            end
        end
        if k == "Once" then
            return function(self, fn)
                local conn = { Connected = true }
                conn.Disconnect = function(self) self.Connected = false end
                return conn
            end
        end
        if k == "Wait" then
            return function(self) return 0 end
        end
        if k == "FindFirstChild" then
            return function(self, name, recursive)
                return children[name]
            end
        end
        if k == "FindFirstChildOfClass" then
            return function(self, cls)
                for _, c in pairs(children) do
                    if (rawget(c, "_className") or "") == cls then return c end
                end
                return nil
            end
        end
        if k == "FindFirstChildWhichIsA" then
            return function(self, cls) return nil end
        end
        if k == "GetChildren" then
            return function(self)
                local arr = {}
                for _, c in pairs(children) do arr[#arr+1] = c end
                return arr
            end
        end
        if k == "GetDescendants" then
            return function(self) return {} end
        end
        if k == "IsA" then
            return function(self, cls)
                local cn = rawget(t, "_className") or ""
                if cn == cls then return true end
                -- héritage simplifié
                local hierarchy = {
                    BasePart = {"Part","MeshPart","UnionOperation","SpecialMesh"},
                    Humanoid = {"Humanoid"},
                    Model = {"Model"},
                    LocalScript = {"LocalScript","Script"},
                }
                for base, subs in pairs(hierarchy) do
                    if base == cls then
                        for _, s in ipairs(subs) do
                            if s == cn then return true end
                        end
                    end
                end
                return false
            end
        end
        if k == "WaitForChild" then
            return function(self, name, timeout)
                return children[name] or makeInstance(name)
            end
        end
        if k == "AddItem" or k == "Remove" then
            return function(...) end
        end
        if k == "Destroy" then
            return function(self) props.Parent = nil end
        end
        if k == "Clone" then
            return function(self) return makeInstance(rawget(t,"_className") or "Instance") end
        end
        if k == "GetFullName" then
            return function(self) return rawget(t,"_className") or "Instance" end
        end
        if k == "GetPropertyChangedSignal" then
            return function(self, prop) return makeInstance("RBXScriptSignal") end
        end
        if k == "AncestryChanged" or k == "Changed" or k == "ChildAdded"
            or k == "ChildRemoved" or k == "DescendantAdded" or k == "DescendantRemoving" then
            return makeInstance("RBXScriptSignal")
        end
        -- Propriétés qui retournent des types valeur spéciaux
        if k == "AbsoluteSize" or k == "AbsoluteContentSize" then
            return Vector2.new(100, 100)
        end
        if k == "AbsolutePosition" then
            return Vector2.new(0, 0)
        end
        if k == "AbsoluteRotation" then return 0 end

        -- Retourne une sous-instance par défaut
        local sub = makeInstance(k)
        props[k] = sub
        return sub
    end

    mt.__newindex = function(t, k, v)
        props[k] = v
        if k == "Parent" and v ~= nil then
            local pc = rawget(v, "_children")
            if pc then
                local name = props.Name or rawget(t, "_className") or "Instance"
                pc[name] = t
            end
        end
    end

    mt.__tostring = function(t)
        return (props.Name or rawget(t,"_className") or "Instance")
    end

    rawset(inst, "_className", className)
    rawset(inst, "_props", props)
    rawset(inst, "_children", children)
    rawset(inst, "_connections", connections)
    props.ClassName = className
    props.Name = className

    setmetatable(inst, mt)
    return inst
end

-- ============================================================
-- Types Roblox (Color3, Vector3, UDim2, CFrame, etc.)
-- ============================================================

Color3 = {}
Color3.new = function(r,g,b) return {r=r or 0, g=g or 0, b=b or 0, _type="Color3"} end
Color3.fromRGB = function(r,g,b) return Color3.new((r or 0)/255,(g or 0)/255,(b or 0)/255) end
Color3.fromHSV = function(h,s,v) return Color3.new(h,s,v) end

Vector3 = {}
Vector3.new = function(x,y,z)
    local v = {X=x or 0, Y=y or 0, Z=z or 0, _type="Vector3"}
    local mt = {
        __add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end,
        __sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end,
        __mul = function(a,b)
            if type(b) == "number" then return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
            return Vector3.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
        end,
        __unm = function(a) return Vector3.new(-a.X,-a.Y,-a.Z) end,
        __tostring = function(v) return string.format("(%g,%g,%g)",v.X,v.Y,v.Z) end,
    }
    mt.__index = function(t,k)
        if k == "Magnitude" then
            return math.sqrt(t.X^2+t.Y^2+t.Z^2)
        end
        if k == "Unit" then
            local m = math.sqrt(t.X^2+t.Y^2+t.Z^2)
            if m == 0 then return Vector3.new(0,0,0) end
            return Vector3.new(t.X/m,t.Y/m,t.Z/m)
        end
        if k == "Dot" then return function(self,o) return self.X*o.X+self.Y*o.Y+self.Z*o.Z end end
        if k == "Cross" then
            return function(self,o)
                return Vector3.new(self.Y*o.Z-self.Z*o.Y,self.Z*o.X-self.X*o.Z,self.X*o.Y-self.Y*o.X)
            end
        end
        if k == "Lerp" then return function(self,o,t) return Vector3.new(self.X+(o.X-self.X)*t,self.Y+(o.Y-self.Y)*t,self.Z+(o.Z-self.Z)*t) end end
        return rawget(t,k)
    end
    setmetatable(v, mt)
    return v
end
Vector3.zero = Vector3.new(0,0,0)
Vector3.one  = Vector3.new(1,1,1)

Vector2 = {}
Vector2.new = function(x,y)
    return setmetatable({X=x or 0,Y=y or 0,_type="Vector2"},{
        __add=function(a,b) return Vector2.new(a.X+b.X,a.Y+b.Y) end,
        __sub=function(a,b) return Vector2.new(a.X-b.X,a.Y-b.Y) end,
        __tostring=function(v) return string.format("(%g,%g)",v.X,v.Y) end,
    })
end
Vector2.zero = Vector2.new(0,0)

UDim2 = {}
UDim2.new = function(xs,xo,ys,yo)
    return {X={Scale=xs or 0,Offset=xo or 0},Y={Scale=ys or 0,Offset=yo or 0},_type="UDim2"}
end
UDim2.fromScale  = function(x,y) return UDim2.new(x,0,y,0) end
UDim2.fromOffset = function(x,y) return UDim2.new(0,x,0,y) end

UDim = {}
UDim.new = function(s,o) return {Scale=s or 0,Offset=o or 0,_type="UDim"} end

CFrame = {}
CFrame.new = function(...)
    local args = {...}
    local cf = {
        Position = Vector3.new(args[1] or 0, args[2] or 0, args[3] or 0),
        _type = "CFrame",
    }
    local mt = {
        __mul = function(a,b)
            if b._type == "Vector3" then return b end
            return CFrame.new()
        end,
        __add = function(a,b) return CFrame.new(a.Position.X+b.X,a.Position.Y+b.Y,a.Position.Z+b.Z) end,
        __sub = function(a,b) return CFrame.new(a.Position.X-b.X,a.Position.Y-b.Y,a.Position.Z-b.Z) end,
        __index = function(t,k)
            if k=="p" or k=="Position" then return rawget(t,"Position") end
            if k=="LookVector" then return Vector3.new(0,0,-1) end
            if k=="RightVector" then return Vector3.new(1,0,0) end
            if k=="UpVector" then return Vector3.new(0,1,0) end
            if k=="X" then return rawget(t,"Position").X end
            if k=="Y" then return rawget(t,"Position").Y end
            if k=="Z" then return rawget(t,"Position").Z end
            if k=="Lerp" then return function(self,o,t) return CFrame.new() end end
            if k=="ToWorldSpace" then return function(self,o) return o end end
            if k=="ToObjectSpace" then return function(self,o) return o end end
            if k=="GetComponents" then return function(self) return 0,0,0,1,0,0,0,1,0,0,0,1 end end
            return nil
        end,
    }
    setmetatable(cf, mt)
    return cf
end
CFrame.identity = CFrame.new()
CFrame.fromEulerAnglesXYZ = function(rx,ry,rz) return CFrame.new() end
CFrame.fromEulerAnglesYXZ = function(rx,ry,rz) return CFrame.new() end
CFrame.Angles = function(rx,ry,rz) return CFrame.new() end
CFrame.lookAt = function(eye,target,up) return CFrame.new() end
CFrame.fromMatrix = function(...) return CFrame.new() end

BrickColor = {}
BrickColor.new = function(v) return {Name=tostring(v),_type="BrickColor"} end
BrickColor.White = function() return BrickColor.new("White") end
BrickColor.Black = function() return BrickColor.new("Black") end

TweenInfo = {}
TweenInfo.new = function(t,es,ed,rc,rev,dl)
    return {Time=t or 1,EasingStyle=es,EasingDirection=ed,_type="TweenInfo"}
end

NumberSequence = {}
NumberSequence.new = function(v)
    if type(v) == "number" then return {_type="NumberSequence",_val=v} end
    return {_type="NumberSequence",_val=v}
end

NumberSequenceKeypoint = {}
NumberSequenceKeypoint.new = function(t,v,e)
    return {Time=t,Value=v,Envelope=e or 0,_type="NumberSequenceKeypoint"}
end

ColorSequence = {}
ColorSequence.new = function(v)
    return {_type="ColorSequence",_val=v}
end

ColorSequenceKeypoint = {}
ColorSequenceKeypoint.new = function(t,c)
    return {Time=t,Value=c,_type="ColorSequenceKeypoint"}
end

NumberRange = {}
NumberRange.new = function(min,max)
    return {Min=min,Max=max or min,_type="NumberRange"}
end

Rect = {}
Rect.new = function(x0,y0,x1,y1)
    return {Min=Vector2.new(x0,y0),Max=Vector2.new(x1,y1),_type="Rect"}
end

Ray = {}
Ray.new = function(origin,dir) return {Origin=origin,Direction=dir,_type="Ray"} end

PhysicalProperties = {}
PhysicalProperties.new = function(...) return {_type="PhysicalProperties"} end

-- ============================================================
-- Enum — validé contre la liste réelle Roblox
-- ============================================================

local _enumDefs = {
    Font = {
        Legacy=0,Arial=1,ArialBold=2,SourceSans=3,SourceSansBold=4,
        SourceSansSemibold=5,SourceSansLight=6,SourceSansItalic=7,
        Bodoni=8,Garamond=9,Cartoon=10,Code=11,Highway=12,SciFi=13,
        Arcade=14,Fantasy=15,Antique=16,Gotham=17,GothamBold=18,
        GothamBlack=19,GothamMedium=20,Bangers=21,Creepster=22,
        DenkOne=23,Fondamento=24,FredokaOne=25,GrenzeGotisch=26,
        IndieFlower=27,JosefinSans=28,Jura=29,Kalam=30,LuckiestGuy=31,
        Merriweather=32,Michroma=33,Nunito=34,Oswald=35,PatrickHand=36,
        PermanentMarker=37,Roboto=38,RobotoCondensed=39,RobotoMono=40,
        Sarpanch=41,SpecialElite=42,TitilliumWeb=43,Ubuntu=44,
        Unknown=45,BuilderSans=46,
        -- Roblox 2024+
        BuilderSansMedium=47,BuilderSansBold=48,
    },
    EasingStyle = {
        Linear=0,Sine=1,Back=2,Bounce=3,Elastic=4,Exponential=5,
        Quad=6,Quart=7,Quint=8,Cubic=9,Circular=10,
    },
    EasingDirection = {In=0,Out=1,InOut=2},
    KeyCode = setmetatable({},{
        __index = function(t,k)
            return {Name=k,Value=0,_type="EnumItem",EnumType="KeyCode"}
        end
    }),
    UserInputType = setmetatable({},{
        __index = function(t,k)
            return {Name=k,Value=0,_type="EnumItem",EnumType="UserInputType"}
        end
    }),
    UserInputState = {Begin=0,Change=1,End=2,Cancel=3},
    RenderPriority = {First=0,Input=1,Camera=2,Character=3,Last=4},
    NormalId = {Top=1,Bottom=2,Front=5,Back=4,Right=0,Left=3},
    SortOrder = {LayoutOrder=0,Name=1},
    FillDirection = {Horizontal=0,Vertical=1},
    HorizontalAlignment = {Center=0,Left=1,Right=2},
    VerticalAlignment = {Center=0,Top=1,Bottom=2},
    TextXAlignment = {Center=0,Left=1,Right=2},
    TextYAlignment = {Center=0,Top=1,Bottom=2},
    ScaleType = {Stretch=0,Slice=1,Tile=2,Fit=3,Crop=4},
    AutomaticSize = {None=0,X=1,Y=2,XY=3},
    SizeConstraint = {RelativeXY=0,RelativeXX=1,RelativeYY=2},
    PartType = {Block=0,Ball=1,Cylinder=2},
    Material = setmetatable({SmoothPlastic=0,Neon=1,Glass=2},{
        __index=function(t,k) return {Name=k,Value=0,_type="EnumItem"} end
    }),
    HumanoidStateType = {
        FallingDown=0,Running=8,RunningNoPhysics=10,Climbing=12,
        Seated=13,PlatformStanding=14,Dead=15,Jumping=17,
        Freefall=18,Ragdoll=20,GettingUp=22,Jumping2=23,
        Swimming=4,SwimmingIdle=5,StrafingNoPhysics=11,
        Landed=24,None=25,Physics=16,Flying=6,
    },
    AnimationPriority = {Idle=0,Movement=1,Action=2,Action2=3,Action3=4,Core=1000},
    BodyPart = {Head=0,Torso=1,LeftArm=2,RightArm=3,LeftLeg=4,RightLeg=5},
    ChatColor = {Blue=0,Green=1,Red=2},
    ContextActionResult = {Pass=0,Sink=1},
    CoreGuiType = {All=0,PlayerList=1,Health=2,Backpack=3,Chat=4},
    FrameStyle = {Custom=0},
    GuiType = {ScreenGui=0},
    InOut = {Edge=0,Inset=1,Center=2},
    BorderMode = {Outline=0,Middle=1,Inset=2},
    ZIndexBehavior = {Global=0,Sibling=1},
    ScreenInsets = {None=0,DeviceSafeInsets=1,TopbarSafeInsets=2,CoreUISafeInsets=3},
    HighlightDepthMode = {AlwaysOnTop=0,Occluded=1},
    SelectionBehavior = {Escape=0,Stop=1,ConditionalEscape=2},
    InputType = {NoInput=0,Constant=1,Sin=2},
    ApplyStrokeMode = {Contextual=0,Border=1},
    LineJoinMode = {Round=0,Bevel=1,Miter=2},
}

Enum = setmetatable({}, {
    __index = function(t, enumName)
        local def = _enumDefs[enumName]
        if def then
            return setmetatable({}, {
                __index = function(et, itemName)
                    local val = def[itemName]
                    if val == nil then
                        error(string.format("[fake_env] Enum.%s.%s n'existe pas dans Roblox", enumName, itemName), 2)
                    end
                    if type(val) == "table" then return val end
                    return {Name=itemName, Value=val, _type="EnumItem", EnumType=enumName}
                end,
                __tostring = function() return "Enum."..enumName end,
            })
        end
        -- EnumType inconnu → permissif (on ne plante pas pour les enums non couverts)
        return setmetatable({}, {
            __index = function(et, itemName)
                return {Name=itemName, Value=0, _type="EnumItem", EnumType=enumName}
            end
        })
    end
})

-- ============================================================
-- task — scheduler simplifié (synchrone)
-- ============================================================

task = {}

--[[
    task.wait a un budget d'itérations LOCAL à chaque appel task.spawn
    (pile de budgets, pas de compteur global — évite qu'une boucle épuise
    le budget d'une autre coroutine sans rapport). Une fois épuisé, une
    erreur marquée "_FAKEENV_BUDGET_" est levée et interceptée par
    _runSpawned comme une fin normale (pas un vrai bug). Ça permet
    d'exécuter réellement les coroutines task.spawn (contrairement à un
    no-op complet) sans jamais bloquer sur un `while X.Parent do
    task.wait() end` — tout en laissant remonter les vraies erreurs
    (index nil, variable non déclarée, etc.) qui se produisent avant
    l'épuisement du budget. Le code hors task.spawn (chunk principal)
    n'a pas de budget : task.wait s'y comporte comme avant (no-op).
]]
local _BUDGET_MARKER = "_FAKEENV_BUDGET_EXCEEDED_"
local _budgetStack = {}

task.wait = function(t)
    local top = _budgetStack[#_budgetStack]
    if top then
        top.n = top.n - 1
        if top.n <= 0 then
            error(_BUDGET_MARKER, 0)
        end
    end
    return t or 0
end

local function _runSpawned(fn, ...)
    if type(fn) ~= "function" then return end
    table.insert(_budgetStack, { n = 50 })
    local ok, err = pcall(fn, ...)
    table.remove(_budgetStack)
    if not ok and not tostring(err):find(_BUDGET_MARKER, 1, true) then
        -- Vraie erreur (pas juste le budget épuisé) : la remonter
        error("[fake_env] Erreur dans une coroutine task.spawn : " .. tostring(err), 0)
    end
end

task.spawn  = _runSpawned
task.defer  = _runSpawned
task.delay  = function(t, fn, ...) _runSpawned(fn, ...) end
task.cancel = function(thread) end
task.synchronize = function() end
task.desynchronize = function() end

-- ============================================================
-- Services Roblox
-- ============================================================

local _services = {}

local function makeService(name)
    if _services[name] then return _services[name] end
    local s = makeInstance(name)
    _services[name] = s
    return s
end

-- RunService
local RunService = makeService("RunService")
do
    local _noop_signal = makeInstance("RBXScriptSignal")
    RunService.Heartbeat    = _noop_signal
    RunService.RenderStepped = _noop_signal
    RunService.Stepped      = _noop_signal
    RunService.IsRunning    = function() return true end
    RunService.IsClient     = function() return true end
    RunService.IsServer     = function() return false end
    RunService.IsStudio     = function() return false end
end

-- Players
local Players = makeService("Players")
do
    local fakeChar = makeInstance("Model")
    fakeChar.Name = "FakeCharacter"

    local fakeHRP = makeInstance("Part")
    fakeHRP.Name = "HumanoidRootPart"
    fakeHRP.CFrame = CFrame.new(0,0,0)
    fakeHRP.Position = Vector3.new(0,0,0)
    fakeHRP.AssemblyLinearVelocity = Vector3.new(0,0,0)
    fakeHRP.Velocity = Vector3.new(0,0,0)
    fakeHRP.Anchored = false
    fakeHRP.CanCollide = true
    rawget(fakeChar,"_children")["HumanoidRootPart"] = fakeHRP

    local fakeHuman = makeInstance("Humanoid")
    fakeHuman.Name = "Humanoid"
    fakeHuman.WalkSpeed = 16
    fakeHuman.JumpPower = 50
    fakeHuman.Health = 100
    fakeHuman.MaxHealth = 100
    fakeHuman.PlatformStand = false
    fakeHuman.GetState = function(self) return {Value=8} end
    fakeHuman.ChangeState = function(self, s) end
    fakeHuman.SetStateEnabled = function(self, s, e) end
    fakeHuman.MoveTo = function(self, pos, part) end
    fakeHuman.GetAppliedDescription = function(self) return makeInstance("HumanoidDescription") end
    rawget(fakeChar,"_children")["Humanoid"] = fakeHuman

    local fakeHead = makeInstance("Part")
    fakeHead.Name = "Head"
    fakeHead.Position = Vector3.new(0,5,0)
    fakeHead.CFrame = CFrame.new(0,5,0)
    rawget(fakeChar,"_children")["Head"] = fakeHead

    local fakeLP = makeInstance("Player")
    fakeLP.Name = "FakePlayer"
    fakeLP.DisplayName = "FakePlayer"
    fakeLP.UserId = 12345678
    fakeLP.Character = fakeChar
    fakeLP.CharacterAdded = makeInstance("RBXScriptSignal")
    fakeLP.CharacterRemoving = makeInstance("RBXScriptSignal")
    fakeLP.Backpack = makeInstance("Backpack")
    fakeLP.PlayerGui = makeInstance("PlayerGui")
    fakeLP.GetMouse = function(self) return makeInstance("Mouse") end
    fakeLP.IsA = function(self, cls) return cls=="Player" or cls=="Instance" end
    fakeLP.GetAttribute = function(self, k) return nil end

    Players.LocalPlayer = fakeLP
    Players.PlayerAdded = makeInstance("RBXScriptSignal")
    Players.PlayerRemoving = makeInstance("RBXScriptSignal")
    Players.GetPlayers = function(self) return {fakeLP} end
    Players.GetPlayerFromCharacter = function(self, char) return fakeLP end
    Players.GetCharacters = function(self) return {fakeChar} end
end

-- UserInputService
local UserInputService = makeService("UserInputService")
do
    UserInputService.InputBegan   = makeInstance("RBXScriptSignal")
    UserInputService.InputEnded   = makeInstance("RBXScriptSignal")
    UserInputService.InputChanged  = makeInstance("RBXScriptSignal")
    UserInputService.JumpRequest  = makeInstance("RBXScriptSignal")
    UserInputService.TouchEnded   = makeInstance("RBXScriptSignal")
    UserInputService.MouseBehavior = 0
    UserInputService.MouseDeltaSensitivity = 1
    UserInputService.IsKeyDown     = function(self, key) return false end
    UserInputService.IsMouseButtonPressed = function(self, btn) return false end
    UserInputService.GetMouseLocation = function(self) return Vector2.new(0,0) end
    UserInputService.GetMouseDelta  = function(self) return Vector2.new(0,0) end
    UserInputService.GetFocusedTextBox = function(self) return nil end
end

-- TweenService
local TweenService = makeService("TweenService")
do
    TweenService.Create = function(self, inst, tweenInfo, props)
        local tween = makeInstance("Tween")
        tween.Completed = makeInstance("RBXScriptSignal")
        tween.Play = function(self) end
        tween.Pause = function(self) end
        tween.Cancel = function(self) end
        return tween
    end
    TweenService.GetValue = function(self, alpha, easingStyle, easingDirection)
        return alpha
    end
end

-- HttpService
local HttpService = makeService("HttpService")
do
    HttpService.JSONEncode = function(self, data)
        -- On utilise le JSON encoder natif si disponible, sinon stub
        return "{}"
    end
    HttpService.JSONDecode = function(self, str)
        return {}
    end
    HttpService.GenerateGUID = function(self, wrap)
        return "00000000-0000-0000-0000-000000000000"
    end
    HttpService.GetAsync = function(self, url) return "" end
    HttpService.PostAsync = function(self, url, data) return "" end
end

-- Lighting
local Lighting = makeService("Lighting")
do
    Lighting.Brightness = 1
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = true
    Lighting.OutdoorAmbient = Color3.fromRGB(70,70,70)
    Lighting.GetDescendants = function(self) return {} end
end

-- ContextActionService
local ContextActionService = makeService("ContextActionService")
do
    ContextActionService.BindAction     = function(self, name, fn, touch, ...) end
    ContextActionService.UnbindAction   = function(self, name) end
    ContextActionService.BindActionAtPriority = function(self, name, fn, touch, prio, ...) end
end

-- GuiService
local GuiService = makeService("GuiService")
do
    GuiService.CoreUiEnabled  = true
    GuiService.MenuIsOpen     = false
end

-- CoreGui
local CoreGui = makeService("CoreGui")
do
    CoreGui.SetCore = function(self, ...) end
    CoreGui.GetCore = function(self, ...) return nil end
end

-- StarterGui
local StarterGui = makeService("StarterGui")
do
    StarterGui.SetCoreGuiEnabled = function(self, ...) end
    StarterGui.GetCoreGuiEnabled = function(self, ...) return true end
end

-- Chat
local Chat = makeService("Chat")

-- ReplicatedStorage
local ReplicatedStorage = makeService("ReplicatedStorage")

-- RobloxReplicatedStorage
local RobloxReplicatedStorage = makeService("RobloxReplicatedStorage")

-- workspace
local fakeWorkspace = makeService("Workspace")
do
    fakeWorkspace.CurrentCamera = makeInstance("Camera")
    fakeWorkspace.CurrentCamera.CFrame = CFrame.new(0,10,-20)
    fakeWorkspace.CurrentCamera.CameraType = 0
    fakeWorkspace.CurrentCamera.FieldOfView = 70
    fakeWorkspace.Gravity = 196.2
    fakeWorkspace.StreamingEnabled = false
    fakeWorkspace.GetDescendants = function(self) return {} end
    fakeWorkspace.FindFirstChild = function(self, name)
        if name == "Terrain" then return makeInstance("Terrain") end
        return nil
    end
    fakeWorkspace.Raycast = function(self, origin, dir, params)
        return nil
    end
    fakeWorkspace.FindPartOnRay = function(self, ray, ignore, terrain, water)
        return nil
    end
    fakeWorkspace.FindPartOnRayWithIgnoreList = function(self, ray, ignoreList)
        return nil
    end
end
workspace = fakeWorkspace

-- game
game = setmetatable({}, {
    __index = function(t, k)
        if k == "IsLoaded" then
            return function(self) return true end
        end
        if k == "Loaded" then
            return makeInstance("RBXScriptSignal")
        end
        if k == "GetService" then
            return function(self, serviceName)
                local map = {
                    RunService            = RunService,
                    Players               = Players,
                    UserInputService      = UserInputService,
                    TweenService          = TweenService,
                    HttpService           = HttpService,
                    Lighting              = Lighting,
                    ContextActionService  = ContextActionService,
                    GuiService            = GuiService,
                    CoreGui               = CoreGui,
                    StarterGui            = StarterGui,
                    Chat                  = Chat,
                    ReplicatedStorage     = ReplicatedStorage,
                    RobloxReplicatedStorage = RobloxReplicatedStorage,
                    Workspace             = fakeWorkspace,
                    SoundService          = makeService("SoundService"),
                    VRService             = makeService("VRService"),
                    TextService           = makeService("TextService"),
                    LocalizationService   = makeService("LocalizationService"),
                    PathfindingService    = makeService("PathfindingService"),
                    PhysicsService        = makeService("PhysicsService"),
                    CollectionService     = makeService("CollectionService"),
                    MarketplaceService    = makeService("MarketplaceService"),
                    LogService            = makeService("LogService"),
                }
                local s = map[serviceName]
                if s then return s end
                return makeService(serviceName)
            end
        end
        if k == "Workspace" then return fakeWorkspace end
        if k == "Players" then return Players end
        if k == "Lighting" then return Lighting end
        if k == "ReplicatedStorage" then return ReplicatedStorage end
        return makeInstance(k)
    end,
    __newindex = function(t,k,v) rawset(t,k,v) end,
})

-- ============================================================
-- Instance.new
-- ============================================================

Instance = {}
Instance.new = function(className, parent)
    local inst = makeInstance(className)
    if parent then
        inst.Parent = parent
    end
    return inst
end

-- ============================================================
-- Executor-specific stubs
-- ============================================================

-- Filesystem
writefile  = function(path, data) end
readfile   = function(path) return "" end
isfile     = function(path) return false end
isfolder   = function(path) return false end
makefolder = function(path) end
listfiles  = function(path) return {} end
appendfile = function(path, data) end

-- Hooks
hookfunction = function(fn, hook) return fn end
newcclosure  = function(fn) return fn end
getconnections = function(signal) return {} end
clonefunction  = function(fn) return fn end
checkcaller    = function() return false end

-- Identity / protection
sethiddenproperty = function(inst, prop, val) end
gethiddenproperty = function(inst, prop) return nil end
setreadonly       = function(t, v) end
isreadonly        = function(t) return false end
makereadonly      = function(t) end

-- gethui → retourne un ScreenGui factice
gethui = function()
    return makeInstance("ScreenGui")
end

-- Synapse / Wave / Delta compat
syn = syn or {}
syn.protect_gui = function(gui) end
syn.queue_on_teleport = function(code) end

protectgui = function(gui) end
unprotectgui = function(gui) end

queue_on_teleport = function(code) end
getgenv = function() return _G end
getrenv = function() return _G end
getsenv = function(script) return {} end
getfenv = getfenv or function(fn) return _G end

-- ============================================================
-- Globals Roblox divers
-- ============================================================

shared  = shared  or {}
script  = script  or makeInstance("LocalScript")
plugin  = plugin  or nil

-- warn → comme print mais préfixé
warn = function(...)
    local args = {...}
    for i,v in ipairs(args) do args[i] = tostring(v) end
    print("[WARN] " .. table.concat(args, " "))
end

-- wait → ancienne API Roblox (dépréciée mais encore utilisée)
wait = function(t) return t or 0, 0 end

-- tick / time / os.clock (normaux en Lua)
tick = tick or os.clock

-- elapsedTime
elapsedTime = function() return 0 end

-- math ajouts Roblox
math.clamp = math.clamp or function(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end
math.sign = math.sign or function(v) return v > 0 and 1 or v < 0 and -1 or 0 end
math.round = math.round or function(v) return math.floor(v + 0.5) end
math.noise = math.noise or function(x,y,z) return 0 end
math.map   = function(v,a,b,c,d) return c + (v-a)/(b-a)*(d-c) end

-- table ajouts
table.find = table.find or function(t, val, init)
    for i = init or 1, #t do
        if t[i] == val then return i end
    end
    return nil
end
table.move = table.move or function(a1, f, e, t, a2)
    a2 = a2 or a1
    for i = f, e do a2[t+i-f] = a1[i] end
    return a2
end
table.create = table.create or function(n, val)
    local t = {}
    for i=1,n do t[i]=val end
    return t
end
table.clear = table.clear or function(t)
    for k in pairs(t) do t[k]=nil end
end
table.freeze = table.freeze or function(t) return t end
table.isfrozen = table.isfrozen or function(t) return false end
table.clone = table.clone or function(t)
    local c = {}
    for k,v in pairs(t) do c[k]=v end
    return c
end

-- string ajouts
string.split = string.split or function(s, sep)
    local result = {}
    local pattern = "([^" .. sep .. "]+)"
    for match in s:gmatch(pattern) do
        table.insert(result, match)
    end
    return result
end

-- ============================================================
-- RaycastParams / OverlapParams
-- ============================================================

RaycastParams = {}
RaycastParams.new = function()
    return {FilterDescendantsInstances={},FilterType=0,IgnoreWater=false}
end

OverlapParams = {}
OverlapParams.new = function()
    return {FilterDescendantsInstances={},FilterType=0,MaxParts=0}
end

-- ============================================================
-- Weld / Motor6D helpers
-- ============================================================

-- ============================================================
-- Chargement du script cible
-- ============================================================

return function(scriptPath)
    local chunk, err = loadfile(scriptPath)
    if not chunk then
        error("[fake_env] Erreur de syntaxe : " .. tostring(err), 0)
    end

    -- On injecte l'environnement global dans le chunk
    -- (En Lua 5.4, setfenv n'existe plus — on doit utiliser _ENV via upvalue ou load)
    -- On recompile avec notre _G comme environnement
    local src
    local f = io.open(scriptPath, "r")
    if f then src = f:read("*a"); f:close() end

    if not src then
        error("[fake_env] Impossible de lire " .. scriptPath, 0)
    end

    -- Compile avec _ENV = nos globals
    local env = _G  -- tout ce qu'on a défini ci-dessus est dans _G
    local fn, loadErr = load(src, "@" .. scriptPath, "t", env)
    if not fn then
        error("[fake_env] Erreur de compilation : " .. tostring(loadErr), 0)
    end

    local ok, runErr = pcall(fn)
    if not ok then
        -- Reformate le message d'erreur pour afficher le numéro de ligne
        error("[fake_env] Erreur à l'exécution : " .. tostring(runErr), 0)
    end

    print("[fake_env] Script chargé sans erreur.")
end
