--[[
    run_test.lua — Lance MoonHub_v16.lua dans le simulateur fake_env

    Usage :
        lua5.4 run_test.lua
        lua5.4 run_test.lua /chemin/vers/autre_script.lua

    Sortie :
        [fake_env] Script chargé sans erreur.   → OK
        [fake_env] Erreur à l'exécution : ...   → bug + numéro de ligne exact
]]

local targetScript = arg and arg[1] or "MoonHub_v16.lua"

-- Charge le simulateur
local simulate = dofile("fake_env.lua")

-- Lance le script cible
print("=== fake_env · test de " .. targetScript .. " ===")
simulate(targetScript)
print("=== fin ===")
