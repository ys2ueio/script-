--[[
    run_mhdev.lua — Lance MHDevTools.fullCheck sur MoonHub_v16.lua

    Usage :
        lua5.4 run_mhdev.lua
        lua5.4 run_mhdev.lua /chemin/vers/script.lua
]]

local target = (arg and arg[1]) or "MoonHub_v16.lua"
local MHDevTools = dofile("MHDevTools.lua")
MHDevTools.fullCheck(target)
