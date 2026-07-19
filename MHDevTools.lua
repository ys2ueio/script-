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

    -- ── Piège 4 : race condition task.spawn — connection assignée DANS le spawn sans flag guard ──
    do
        local found = {}
        local inSpawn = false
        local spawnLine = 0
        local depth = 0  -- profondeur function/do depuis le task.spawn

        for i, l in ipairs(ls) do
            local stripped = l:gsub("%-%-.*",""):gsub('"[^"]*"',""):gsub("'[^']*'","")

            if not inSpawn then
                -- Entrée dans un task.spawn(function()
                if stripped:match("task%.spawn%s*%(function") then
                    inSpawn = true; spawnLine = i; depth = 1
                end
            else
                -- Compte ouvertures/fermetures pour trouver la fin du spawn
                for _ in stripped:gmatch("%bfunction%b()") do depth = depth + 1 end
                for _ in stripped:gmatch("%bdo%b()") do end
                if stripped:match("^%s*function%s") or stripped:match("=%s*function%s*%(") then
                    depth = depth + 1
                end
                -- end nu
                for _ in stripped:gmatch("%bend%s*$") do depth = depth - 1 end
                for _ in stripped:gmatch("%bend%s*[,%)%]]") do depth = depth - 1 end
                if depth <= 0 then inSpawn = false end

                -- Dans le spawn : cherche une assignation de connection guard
                if inSpawn and depth == 1 then
                    if stripped:match("[Cc]onnection%s*=%s*RunService") or stripped:match("[Cc]onnection%s*=%s*UIS") then
                        -- Faux positif si un flag guard est positionné avant le spawn
                        local hasFlag = false
                        for j = math.max(1, spawnLine-8), spawnLine-1 do
                            if ls[j]:match("Started%s*=%s*true") or ls[j]:match("Running%s*=%s*true")
                            or ls[j]:match("_auto%a+Started") then
                                hasFlag = true
                            end
                        end
                        if not hasFlag then found[#found+1] = i end
                    end
                end
            end
        end

        if #found > 0 then
            warn("Race condition : connection assignée dans task.spawn sans flag guard préalable", found[1])
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

MHDevTools._checkLocalsLuac = function(path)
    -- Utilise luac5.4 pour un résultat exact.
    -- Deux métriques distinctes :
    --   "slots"  = pic de registres actifs simultanément  (vraie limite Luau = 200)
    --   "locals" = total de locals déclarés dans la vie de la fonction (informatif)

    -- Passe 1 : -l (une fois) → slots + locals par fonction
    local h1 = io.popen("luac5.4 -l " .. path .. " 2>&1")
    if not h1 then return nil end
    local out1 = h1:read("*a"); h1:close()
    if out1 == "" or (out1:match("^luac") and out1:match("error")) then return nil end

    local SLOT_LIMIT = 200
    local issues = 0
    local maxSlots = 0; local maxSlotsFunc = nil
    local maxLocals = 0; local maxLocalsFunc = nil
    local funcCount = 0

    for line in out1:gmatch("[^\n]+") do
        local fl, ll = line:match("function <[^:]+:(%d+),(%d+)>")
        if fl then
            -- Ligne suivante : "N params, S slots, U upvalues, L locals, ..."
            -- On capture tout dans la ligne d'en-tête de la fonction
        end
        -- "N params, S slots, U upvalues, L locals, C constants, F functions"
        local s, l2 = line:match("(%d+) slots, %d+ upvalues, (%d+) locals,")
        if s and l2 then
            funcCount = funcCount + 1
            s = tonumber(s); l2 = tonumber(l2)
            -- Récupère les lignes de la fonction courante
            local cfStart, cfEnd = line:match("^function <[^:]+:(%d+),(%d+)>")
            -- (cfStart peut être nil ici car on est sur la ligne suivante)
            -- On utilise un tableau pour corréler
        end
    end

    -- Passe améliorée : on parse bloc par bloc
    local funcs = {}
    local cur = nil
    for line in out1:gmatch("[^\n]+") do
        local fl, ll = line:match("^function <[^:]+:(%d+),(%d+)>")
        if fl then
            cur = { startLine=tonumber(fl), endLine=tonumber(ll), slots=0, locals=0 }
            table.insert(funcs, cur)
            funcCount = funcCount + 1
        end
        if cur then
            local s, lv = line:match("(%d+) slots, %d+ upvalues, (%d+) locals,")
            if s then
                cur.slots  = tonumber(s)
                cur.locals = tonumber(lv)
                if cur.slots > maxSlots then maxSlots = cur.slots; maxSlotsFunc = cur end
                if cur.locals > maxLocals then maxLocals = cur.locals; maxLocalsFunc = cur end
                -- Vérifie la vraie limite (slots = pic actif simultané)
                if cur.slots >= SLOT_LIMIT then
                    issues = issues + 1
                    err(string.format(
                        "Fonction (ligne %d-%d) : %d slots actifs au pic (limite = 200)",
                        cur.startLine, cur.endLine, cur.slots
                    ), cur.startLine)
                end
            end
        end
    end

    -- Résumé
    info(string.format("Fonctions analysées (luac) : %d", #funcs))
    if maxSlotsFunc then
        info(string.format(
            "Pic de slots le plus élevé : ligne %d-%d → %d slots actifs / %d locals déclarés",
            maxSlotsFunc.startLine, maxSlotsFunc.endLine,
            maxSlotsFunc.slots, maxSlotsFunc.locals
        ))
    end
    -- Si total locals > 200 mais slots < 200, explique pourquoi c'est OK
    if maxLocals > SLOT_LIMIT and maxSlotsFunc and maxSlotsFunc.slots < SLOT_LIMIT then
        info(string.format(
            "Note : %d locals déclarés au total dans une fonction, mais do..end libèrent les slots → pic = %d < 200 ✓",
            maxLocals, maxSlotsFunc.slots
        ))
    end

    print("")
    if issues == 0 then
        ok("Limite Luau (200 slots actifs) respectée dans toutes les fonctions [via luac]")
    else
        err(string.format("%d fonction(s) dépassent la limite de 200 slots actifs", issues))
    end
    return issues == 0, true
end

MHDevTools.checkLocals = function(path)
    printHeader("CHECK LOCALS · " .. path)

    -- Essaie d'abord avec luac5.4 (résultat exact)
    local result, usedLuac = MHDevTools._checkLocalsLuac(path)
    if usedLuac then return result end

    info("luac non disponible — fallback sur analyse heuristique")
    local src, readErr = readSource(path)
    if not src then err(readErr); return false end

    local ls = lines(src)
    local LIMIT = 190   -- marge avant 200 (Luau plante à 200 exactement)
    local issues = 0

    --[[
        Algorithme de stack de scopes Lua.
        Luau compte les locals PAR FONCTION (pas par do-block).
        On empile un nouveau scope uniquement sur `function`, pas sur `do`.
        Chaque scope accumule le compte de locals déclarés à son niveau
        direct ET dans ses do-blocks imbriqués (car do ne crée pas de
        nouveau scope de variables en Luau pour la limite 200).
    ]]

    -- Préprocesse la source token par token (ligne par ligne, simplifié)
    -- en supprimant commentaires et strings pour éviter les faux positifs.
    local function stripLine(l)
        -- Supprime commentaires de ligne
        l = l:gsub("%-%-.*", "")
        -- Supprime strings doubles (simple heuristique)
        l = l:gsub('"[^"]*"', '""')
        l = l:gsub("'[^']*'", "''")
        return l
    end

    -- Stack : chaque entrée = { name, startLine, locals, isFunc }
    -- isFunc=true  → scope fonction (comptabilisé pour la limite 200)
    -- isFunc=false → scope do/if/while/for (ne crée pas un scope séparé)
    local stack = {{ name="<top-level>", startLine=1, locals=0, isFunc=true }}
    local allFuncScopes = {}  -- scopes fonction fermés, pour rapport

    -- Mots-clés qui ouvrent un nouveau bloc (sans être une fonction)
    local BLOCK_OPEN = { ["do"]=true, ["then"]=true, ["else"]=true,
                         ["elseif"]=true, ["repeat"]=true }

    for i, rawLine in ipairs(ls) do
        local l = stripLine(rawLine)

        -- ── Détection ouverture de scope fonction ──
        -- `function name(` ou `local function name(` ou `= function(`
        local isFuncOpen = false
        local funcName = nil
        if l:match("%bfunction%s*%(") or l:match("%bfunction%s+[%w_%.%:]+%s*%(") then
            -- Vérifie que c'est bien une définition (pas juste un mot dans un string)
            funcName = l:match("function%s+([%w_%.%:]+)") or "anonymous"
            isFuncOpen = true
        end

        -- ── Détection ouverture de scope bloc (do/then/else/repeat) ──
        local isBlockOpen = false
        if not isFuncOpen then
            -- `do` seul, fin de ligne `then`, `else`, `repeat`
            for kw in pairs(BLOCK_OPEN) do
                if l:match("%b" .. kw .. "%b()") or l:match("^%s*" .. kw .. "%s*$")
                   or l:match("%s" .. kw .. "%s*$") or l:match("^%s*" .. kw .. "%s") then
                    isBlockOpen = true
                    break
                end
            end
        end

        -- ── Compte des locals sur cette ligne ──
        local localCount = 0
        -- `local varname` ou `local varA, varB` (une déclaration par ligne typiquement)
        -- On compte le nombre de variables dans chaque `local ...`
        for decl in l:gmatch("%blocal%s+([%w_%s,]+)") do
            -- Exclut `local function` (la fonction elle-même n'est pas un "local" supplémentaire)
            if not decl:match("^%s*function%s") then
                -- Compte les virgules pour les multi-assigns: `local a, b, c` = 3
                local n = 1
                for _ in decl:gmatch(",") do n = n + 1 end
                localCount = localCount + n
            end
        end

        -- ── Pousse un nouveau scope si nécessaire ──
        if isFuncOpen then
            table.insert(stack, { name=funcName, startLine=i, locals=0, isFunc=true })
        elseif isBlockOpen then
            table.insert(stack, { name="block", startLine=i, locals=0, isFunc=false })
        end

        -- ── Ajoute les locals AU SCOPE FONCTION courant ──
        -- (on remonte la stack jusqu'au premier scope isFunc=true)
        if localCount > 0 then
            for j = #stack, 1, -1 do
                if stack[j].isFunc then
                    stack[j].locals = stack[j].locals + localCount
                    break
                end
            end
        end

        -- ── Détection fermeture de scope (end / until) ──
        -- `end` ou `until` ferment un bloc
        local closeCount = 0
        for _ in l:gmatch("%bend%b()") do end  -- ignore end() appels
        -- end nu en fin de ligne ou seul
        if l:match("%bend%s*[,%)%;%]]") then closeCount = closeCount + 1 end
        if l:match("%bend%s*$") then closeCount = closeCount + 1 end
        if l:match("^%s*end%s*$") then closeCount = closeCount + 1 end
        if l:match("%buntil%s") or l:match("%buntil$") then closeCount = closeCount + 1 end
        -- Évite de compter deux fois si end est seul sur la ligne
        if closeCount > 1 and l:match("^%s*end%s*$") then closeCount = 1 end

        for _ = 1, closeCount do
            if #stack > 1 then
                local popped = table.remove(stack)
                if popped.isFunc then
                    -- Rapport si dépasse la limite
                    if popped.locals >= LIMIT then
                        issues = issues + 1
                        local severity = popped.locals >= 200 and err or warn
                        severity(string.format(
                            "Fonction '%s' : %d locals déclarés (limite Luau = 200)",
                            popped.name, popped.locals
                        ), popped.startLine)
                    end
                    table.insert(allFuncScopes, popped)
                end
            end
        end
    end

    -- Ferme le scope top-level restant
    local top = stack[1]
    table.insert(allFuncScopes, top)
    if top.locals >= LIMIT then
        issues = issues + 1
        warn(string.format("Scope top-level : %d locals (limite Luau = 200)", top.locals), 1)
    end

    -- Trie les scopes par count décroissant pour info
    table.sort(allFuncScopes, function(a,b) return a.locals > b.locals end)

    -- Total
    local totalLocals = 0
    for _, s in ipairs(allFuncScopes) do totalLocals = totalLocals + s.locals end

    info(string.format("Total locals comptabilisés : %d | Fonctions analysées : %d", totalLocals, #allFuncScopes))
    if allFuncScopes[1] then
        info(string.format("Scope le plus chargé : '%s' (ligne %d) — %d locals",
            allFuncScopes[1].name, allFuncScopes[1].startLine, allFuncScopes[1].locals))
    end
    if allFuncScopes[2] then
        info(string.format("2e scope : '%s' (ligne %d) — %d locals",
            allFuncScopes[2].name, allFuncScopes[2].startLine, allFuncScopes[2].locals))
    end

    print("")
    if issues == 0 then
        ok("Limite locals Luau (200) respectée dans toutes les fonctions")
    else
        err(string.format("%d fonction(s) proche(s) ou au-delà de la limite 200", issues))
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
