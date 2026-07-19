--[[
    MHDevTools.lua — Boîte à outils v2 pour MoonHub_v16.lua
    Nécessite fake_env.lua dans le même répertoire.

    Usage :
        lua5.4 -e "require('MHDevTools').fullCheck('MoonHub_v16.lua')"
        lua5.4 mhdev.lua   (via run_mhdev.lua)

    API :
        MHDevTools.lint(path)         → signale les 6 pièges connus
        MHDevTools.checkLocals(path)  → vérifie la limite 200 locals Luau
        MHDevTools.runFile(path)      → charge ET exécute le script
        MHDevTools.fullCheck(path)    → lance les 3 et donne un verdict
]]

local MHDevTools = {}

-- ============================================================
-- Helpers internes
-- ============================================================

local COL = {
    RESET  = "\27[0m",
    RED    = "\27[31m",
    YELLOW = "\27[33m",
    GREEN  = "\27[32m",
    CYAN   = "\27[36m",
    BOLD   = "\27[1m",
    DIM    = "\27[2m",
}

local function readSource(path)
    local f = io.open(path, "r")
    if not f then return nil, "Fichier introuvable : " .. path end
    local src = f:read("*a")
    f:close()
    return src
end

local function lines(src)
    local result = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        result[#result+1] = line
    end
    return result
end

local function printHeader(title)
    print(COL.BOLD .. COL.CYAN .. "\n══════════════════════════════════════" .. COL.RESET)
    print(COL.BOLD .. " " .. title .. COL.RESET)
    print(COL.CYAN .. "══════════════════════════════════════" .. COL.RESET)
end

local function ok(msg)
    print(COL.GREEN .. "  ✓ " .. COL.RESET .. msg)
end

local function warn(msg, line)
    if line then
        print(COL.YELLOW .. "  ⚠ " .. COL.RESET .. msg .. COL.DIM .. "  (ligne " .. line .. ")" .. COL.RESET)
    else
        print(COL.YELLOW .. "  ⚠ " .. COL.RESET .. msg)
    end
end

local function err(msg, line)
    if line then
        print(COL.RED .. "  ✗ " .. COL.RESET .. msg .. COL.DIM .. "  (ligne " .. line .. ")" .. COL.RESET)
    else
        print(COL.RED .. "  ✗ " .. COL.RESET .. msg)
    end
end

local function info(msg)
    print(COL.DIM .. "    " .. msg .. COL.RESET)
end

-- ============================================================
-- MHDevTools.lint(path)
-- Scanne le fichier et signale les 6 pièges connus de MoonHub
-- ============================================================

MHDevTools.lint = function(path)
    printHeader("LINT · " .. path)

    local src, readErr = readSource(path)
    if not src then err(readErr); return false end

    local ls = lines(src)
    local issues = 0

    -- ── Piège 1 : .Velocity déprécié (doit être .AssemblyLinearVelocity) ──
    do
        local found = {}
        for i, l in ipairs(ls) do
            -- Cherche .Velocity suivi d'un espace/=/ mais pas .AssemblyLinearVelocity
            if l:match("%.Velocity%s*[=%(]") and not l:match("AssemblyLinearVelocity") then
                found[#found+1] = i
            end
        end
        if #found > 0 then
            err("`.Velocity` déprécié détecté — utiliser `.AssemblyLinearVelocity`", found[1])
            if #found > 1 then info(string.format("+ %d autre(s) occurrence(s) : lignes %s", #found-1, table.concat({table.unpack(found,2,math.min(#found,5))},","))) end
            issues = issues + 1
        else
            ok(".Velocity non utilisé (toutes les références utilisent AssemblyLinearVelocity)")
        end
    end

    -- ── Piège 2 : boucle `while true do` sans garde (fuite async) ──
    do
        local found = {}
        for i, l in ipairs(ls) do
            if l:match("while%s+true%s+do") then
                found[#found+1] = i
            end
        end
        if #found > 0 then
            err(string.format("`while true do` sans garde Parent détecté (%d occurrence(s))", #found), found[1])
            if #found > 1 then info("Autres : lignes " .. table.concat({table.unpack(found,2,math.min(#found,5))},",")) end
            issues = issues + 1
        else
            ok("Aucun `while true do` sans garde (boucles async sécurisées)")
        end
    end

    -- ── Piège 3 : accès CoreGui sans pcall/protection ──
    do
        local found = {}
        for i, l in ipairs(ls) do
            if l:match("CoreGui") and not l:match("pcall") and not l:match("protect") and not l:match("%-%-") then
                found[#found+1] = i
            end
        end
        -- On filtre : les lignes qui font juste game:GetService("CoreGui") sont OK
        local real = {}
        for _, i in ipairs(found) do
            local l = ls[i]
            if not l:match('GetService%s*%(%s*"CoreGui"') and not l:match("gethui") then
                real[#real+1] = i
            end
        end
        if #real > 0 then
            warn("Accès CoreGui sans protection pcall visible", real[1])
            info("Vérifier que syn.protect_gui/protectgui est appliqué sur le ScreenGui")
            issues = issues + 1
        else
            ok("Accès CoreGui correctement protégés")
        end
    end

    -- ── Piège 4 : race condition task.spawn — flag positionné après spawn ──
    do
        local found = {}
        for i, l in ipairs(ls) do
            -- Pattern : assignation d'une connection DANS un task.spawn
            -- Heuristique : "Connection = RunService" ou "Connection = UIS" dans un bloc spawn
            if l:match("Connection%s*=%s*RunService") or l:match("Connection%s*=%s*UIS") then
                -- Vérifie si les lignes précédentes contiennent task.spawn sans flag
                local prev5 = {}
                for j = math.max(1,i-10), i-1 do prev5[#prev5+1] = ls[j] end
                local inSpawn = false
                for _, pl in ipairs(prev5) do
                    if pl:match("task%.spawn") then inSpawn = true end
                end
                if inSpawn then found[#found+1] = i end
            end
        end
        if #found > 0 then
            warn("Possible race condition : connection assignée à l'intérieur d'un task.spawn", found[1])
            info("Pattern risqué : if conn then return end / task.spawn(function() conn=... end)")
            issues = issues + 1
        else
            ok("Aucune race condition task.spawn détectée")
        end
    end

    -- ── Piège 5 : selectTab / tab index hors limites ──
    do
        -- Compte le nombre de tabs déclarés
        local tabCount = 0
        for _, l in ipairs(ls) do
            if l:match('makeTab%s*%(') or (l:match("tabBtn") and l:match("Instance%.new")) then
                tabCount = tabCount + 1
            end
        end
        -- Cherche selectTab(n) avec n > tabCount
        local found = {}
        for i, l in ipairs(ls) do
            local n = l:match("selectTab%s*%(%s*(%d+)")
            if n then
                n = tonumber(n)
                if tabCount > 0 and n > tabCount then
                    found[#found+1] = {i, n}
                end
            end
        end
        if #found > 0 then
            for _, f in ipairs(found) do
                err(string.format("selectTab(%d) appelé mais seulement %d tab(s) détecté(s)", f[2], tabCount), f[1])
                issues = issues + 1
            end
        else
            ok(string.format("selectTab cohérent avec les tabs déclarés (%d tabs)", tabCount))
        end
    end

    -- ── Piège 6 : hookfunction sans pcall ──
    do
        local found = {}
        for i, l in ipairs(ls) do
            if l:match("hookfunction%s*%(") and not l:match("pcall") and not l:match("%-%-") then
                -- Vérifie si entouré d'un pcall sur les lignes précédentes
                local hasPcall = false
                for j = math.max(1,i-3), i do
                    if ls[j]:match("pcall") then hasPcall = true end
                end
                if not hasPcall then
                    found[#found+1] = i
                end
            end
        end
        if #found > 0 then
            warn("hookfunction sans pcall visible — peut planter sur Delta/Fluxus", found[1])
            issues = issues + 1
        else
            ok("hookfunction correctement protégés (ou absents)")
        end
    end

    -- Résumé lint
    print("")
    if issues == 0 then
        ok(COL.BOLD .. "Lint OK — aucun piège détecté" .. COL.RESET)
    else
        print(COL.YELLOW .. string.format("  %d problème(s) détecté(s)", issues) .. COL.RESET)
    end

    return issues == 0
end

-- ============================================================
-- MHDevTools.checkLocals(path)
-- Vérifie la limite Luau des 200 variables locales par scope
-- ============================================================

MHDevTools.checkLocals = function(path)
    printHeader("CHECK LOCALS · " .. path)

    local src, readErr = readSource(path)
    if not src then err(readErr); return false end

    local ls = lines(src)

    -- Stratégie : suivre les scopes via function/do/end
    -- et compter les `local` dans chaque scope (heuristique)
    local LIMIT = 190  -- marge de sécurité avant 200
    local issues = 0

    -- Passe 1 : compter locals par fonction (heuristique par accolades Lua)
    local scopeStack = {{name="<top>", line=1, count=0}}
    local maxScope = {name="<top>", line=1, count=0}

    for i, l in ipairs(ls) do
        -- Nouvelle fonction/do = push scope
        if l:match("^%s*local%s+function%s+") or l:match("^%s*function%s+") or l:match("%bfunction%b()%s*%)") or l:match("=%s*function%s*%(") then
            local fname = l:match("function%s+([%w_%.]+)") or l:match("local%s+function%s+([%w_]+)") or "anonymous"
            table.insert(scopeStack, {name=fname, line=i, count=0})
        elseif l:match("^%s*do%s*$") or l:match("%sdo%s*$") then
            table.insert(scopeStack, {name="do-block", line=i, count=0})
        end

        -- Compte les locals dans le scope courant
        -- (uniquement déclarations, pas locals dans string/commentaires)
        local stripped = l:gsub("%-%-.*",""):gsub('"[^"]*"',''):gsub("'[^']*'","")
        local localCount = 0
        for _ in stripped:gmatch("%blocal%b()") do end  -- ignorer "local function"
        -- Compte toutes les déclarations locales de variables
        for _ in stripped:gmatch("%blocal%s+[%w_,]") do
            localCount = localCount + 1
        end

        local cur = scopeStack[#scopeStack]
        cur.count = cur.count + localCount

        if cur.count > maxScope.count then
            maxScope = {name=cur.name, line=cur.line, count=cur.count}
        end

        -- Fin de scope (end)
        if l:match("^%s*end%s*$") or l:match("^%s*end[%s,;]") or l:match("^%s*end$") then
            if #scopeStack > 1 then
                local popped = table.remove(scopeStack)
                -- Rapporte si dépasse la limite
                if popped.count >= LIMIT then
                    warn(string.format("Scope '%s' : %d locals (limite Luau = 200)", popped.name, popped.count), popped.line)
                    issues = issues + 1
                end
                -- Propage vers le scope parent (locals imbriqués comptent aussi)
                -- (non — Luau compte par scope indépendamment)
            end
        end
    end

    -- Scope top-level restant
    local top = scopeStack[1]
    if top.count >= LIMIT then
        warn(string.format("Scope top-level : %d locals (limite Luau = 200)", top.count), 1)
        issues = issues + 1
    end

    -- Résultat global
    local totalLocals = 0
    for _, l in ipairs(ls) do
        local stripped = l:gsub("%-%-.*",""):gsub('"[^"]*"',''):gsub("'[^']*'","")
        for _ in stripped:gmatch("%blocal%s+[%w_,]") do
            totalLocals = totalLocals + 1
        end
    end

    info(string.format("Total déclarations `local` dans le fichier : %d", totalLocals))
    if maxScope.count > 0 then
        info(string.format("Scope le plus chargé : '%s' (ligne %d) — %d locals", maxScope.name, maxScope.line, maxScope.count))
    end

    print("")
    if issues == 0 then
        ok("Limite locals Luau respectée dans tous les scopes analysés")
    else
        err(string.format("%d scope(s) proche(s) ou au-delà de la limite 200", issues))
    end

    return issues == 0
end

-- ============================================================
-- MHDevTools.runFile(path)
-- Charge ET exécute vraiment le script via fake_env
-- ============================================================

MHDevTools.runFile = function(path)
    printHeader("RUN · " .. path)

    -- Charge le simulateur (chemin relatif au script courant)
    local fakeEnvPath = "fake_env.lua"
    local simulateFn, loadErr = loadfile(fakeEnvPath)
    if not simulateFn then
        err("Impossible de charger fake_env.lua : " .. tostring(loadErr))
        return false
    end

    local ok2, simulate = pcall(simulateFn)
    if not ok2 then
        err("Erreur dans fake_env.lua : " .. tostring(simulate))
        return false
    end

    if type(simulate) ~= "function" then
        err("fake_env.lua doit retourner une fonction simulate(path)")
        return false
    end

    -- Exécution
    local success, runErr = pcall(simulate, path)
    if not success then
        -- Extrait le numéro de ligne de l'erreur
        local lineNum = tostring(runErr):match(":(%d+):")
        if lineNum then
            err("Erreur d'exécution à la ligne " .. lineNum)
        else
            err("Erreur d'exécution")
        end
        -- Affiche le message complet
        info(tostring(runErr))
        print("")
        return false
    end

    print("")
    ok(COL.BOLD .. "Script exécuté sans erreur" .. COL.RESET)
    return true
end

-- ============================================================
-- MHDevTools.fullCheck(path)
-- Lance les 3 outils et donne un verdict final
-- ============================================================

MHDevTools.fullCheck = function(path)
    print(COL.BOLD .. COL.CYAN)
    print("╔══════════════════════════════════════╗")
    print("║  MHDevTools · fullCheck              ║")
    print("║  " .. path:sub(1,36) .. (" "):rep(math.max(0,36-#path)) .. "║")
    print("╚══════════════════════════════════════╝" .. COL.RESET)

    local r1 = MHDevTools.lint(path)
    local r2 = MHDevTools.checkLocals(path)
    local r3 = MHDevTools.runFile(path)

    -- ── Verdict final ──
    printHeader("VERDICT")
    local checks = {
        {name="Lint (6 pièges)",          pass=r1},
        {name="Locals Luau (<200)",        pass=r2},
        {name="Exécution (fake_env)",      pass=r3},
    }

    for _, c in ipairs(checks) do
        if c.pass then
            ok(c.name)
        else
            err(c.name)
        end
    end

    print("")
    if r1 and r2 and r3 then
        print(COL.BOLD .. COL.GREEN .. "  ✅  PRÊT À LIVRER" .. COL.RESET)
    else
        print(COL.BOLD .. COL.RED .. "  ❌  PROBLÈMES À CORRIGER AVANT LIVRAISON" .. COL.RESET)
    end
    print("")

    return r1 and r2 and r3
end

-- ============================================================
-- Exécution directe (lua5.4 MHDevTools.lua [path])
-- ============================================================

if arg and arg[0] and arg[0]:match("MHDevTools") then
    local target = arg[1] or "MoonHub_v16.lua"
    MHDevTools.fullCheck(target)
end

return MHDevTools
