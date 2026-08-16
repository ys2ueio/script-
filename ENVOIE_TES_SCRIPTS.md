# 📤 Envoie tes scripts obfusqués ici !

## Comment faire ? 🤔

### Option 1: Copier-coller direct
Tu peux copier-coller le contenu de tes scripts obfusqués directement dans le chat. Je vais les créer comme fichiers et les déobfusquer.

**Exemple:**
```
Voici mon premier script:

do
    local function detected(reason)
        while true do
            reason = reason
        end
    end
    ...
```

### Option 2: Envoyer les fichiers
Si tu as plusieurs scripts ou s'ils sont très longs, tu peux les envoyer directement comme fichiers.

### Option 3: Créer un dossier avec tous les scripts
Crée un dossier `mes_scripts/` avec tous tes fichiers `.lua` obfusqués, et je vais les traiter en batch !

---

## Ce que je vais faire avec tes scripts 🛠️

Pour chaque script obfusqué, je vais créer:

1. **Script déobfusqué** (`script_deobf.lua`)
   - Code lisible avec indentation
   - Variables renommées
   - Strings décodées
   - Commentaires utiles

2. **Mapping file** (`script_deobf_mapping.json`)
   - Toutes les variables renommées
   - Les strings récupérées
   - Les fonctions identifiées

3. **Rapport** 
   - Nombre de variables renommées
   - Nombre de strings récupérées
   - Statistiques

---

## Exemple de résultat 📋

### Avant (Obfusqué)
```lua
do
    local function detected(reason)
        while true do
            reason = reason
        end
    end

    local function check(value, reason)
        if not value then
            detected(reason)
        end
    end
    
    local s1 = "test"
    local ok1, s2 = pcall(function()
        error(s1, 0)
    end)
```

### Après (Déobfusqué)
```lua
-- Deobfuscated Script
-- Recovered by Roblox Lua Deobfuscator

do
    local function detected(reason)
        while true do
            reason = reason
        end
    end

    local function check(value, reason)
        if not value then
            detected(reason)
        end
    end
    
    local var_1 = "test"
    local ok1, var_2 = pcall(function()
        error(var_1, 0)
    end)
```

---

## Prêt ? 🚀

**Envoie-moi tes scripts et je vais les récupérer pour toi !**

### Commandes rapides:

```bash
# Déobfusquer un seul script
python3 deobfuscator.py script_obfusque.lua

# Déobfusquer tous les scripts d'un dossier
./batch_deobfuscate.sh ./mes_scripts ./scripts_recuperes

# Afficher l'aide
python3 deobfuscator.py
./batch_deobfuscate.sh
```

---

**Attends ! Je suis prêt ! 👊**
