-- Lua Deobfuscator for Luraph/Roblox Scripts
-- Helps recover obfuscated script source code
-- Usage: lua lua_deobfuscator.lua <obfuscated_script.lua>

local deobfuscator = {}

-- Pattern matching helpers
local patterns = {
    -- Common obfuscated variable patterns
    single_letter_vars = "^[a-z]%d+$",
    double_letter_vars = "^[a-z]{2}%d+$",
    escaped_strings = "string%.char%(%d+[,%)%s]",
}

-- Variable name mapping
local var_map = {}
local var_counter = {}

-- Common Roblox function names to look for
local roblox_functions = {
    "game", "workspace", "script", "Instance", "Vector3", "CFrame",
    "UDim2", "Color3", "Enum", "RunService", "UserInputService",
    "Players", "GetService", "FindFirstChild", "WaitForChild",
    "Connect", "Fire", "GetChildren", "GetDescendants"
}

-- Extract strings encoded as char sequences
function deobfuscator:extract_encoded_strings(code)
    local decoded = code
    local pattern = 'string%.char%(%d+[%d,%s]*%)'

    decoded = string.gsub(decoded, pattern, function(match)
        local nums = match:match('%((.*)%)')
        local result = ""
        for num in nums:gmatch('%d+') do
            result = result .. string.char(tonumber(num))
        end
        return '"' .. result .. '"'
    end)

    return decoded
end

-- Identify and rename obfuscated variables
function deobfuscator:map_variables(code)
    local lines = {}
    for line in code:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local mapped_lines = {}
    for _, line in ipairs(lines) do
        local new_line = line

        -- Find variable patterns like v1, v2, t1, t2, etc
        for var in line:gmatch("%b()") do
            if not var_map[var] then
                -- Create meaningful name based on usage
                local var_type = string.sub(var, 1, 1)
                if not var_counter[var_type] then
                    var_counter[var_type] = 0
                end
                var_counter[var_type] = var_counter[var_type] + 1

                local type_name = ({
                    v = "var", t = "table", f = "func",
                    s = "str", n = "num", b = "bool"
                })[var_type] or "var"

                var_map[var] = type_name .. "_" .. var_counter[var_type]
            end

            new_line = string.gsub(new_line, "%f[%w_]" .. var .. "%f[^%w_]", var_map[var])
        end

        table.insert(mapped_lines, new_line)
    end

    return table.concat(mapped_lines, "\n")
end

-- Format and prettify code
function deobfuscator:format_code(code)
    local formatted = code
    local indent_level = 0
    local lines = {}

    for line in formatted:gmatch("[^\n]+") do
        local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")

        -- Decrease indent for closing brackets
        if trimmed:match("^end") or trimmed:match("^%)") or trimmed:match("^}") then
            indent_level = math.max(0, indent_level - 1)
        end

        -- Add indentation
        local indented = string.rep("  ", indent_level) .. trimmed
        table.insert(lines, indented)

        -- Increase indent for opening keywords
        if trimmed:match("then%s*$") or trimmed:match("do%s*$") or
           trimmed:match("function%s*") or trimmed:match("{%s*$") then
            indent_level = indent_level + 1
        end
    end

    return table.concat(lines, "\n")
end

-- Main deobfuscation function
function deobfuscator:deobfuscate(code)
    print("🔍 Starting deobfuscation...")

    -- Step 1: Extract encoded strings
    print("📝 Extracting encoded strings...")
    local step1 = self:extract_encoded_strings(code)

    -- Step 2: Map variables
    print("🔤 Mapping variables...")
    local step2 = self:map_variables(step1)

    -- Step 3: Format code
    print("✨ Formatting code...")
    local step3 = self:format_code(step2)

    print("✅ Deobfuscation complete!")
    return step3
end

-- CLI interface
if arg[1] then
    local file = io.open(arg[1], "r")
    if not file then
        print("❌ Error: Could not open file: " .. arg[1])
        os.exit(1)
    end

    local content = file:read("*a")
    file:close()

    local result = deobfuscator:deobfuscate(content)

    -- Save to output file
    local output_file = arg[1]:gsub("%.lua$", "_deobf.lua")
    local out = io.open(output_file, "w")
    out:write(result)
    out:close()

    print("\n📂 Output saved to: " .. output_file)
else
    print("Lua Deobfuscator for Luraph/Roblox Scripts")
    print("Usage: lua lua_deobfuscator.lua <obfuscated_script.lua>")
end

return deobfuscator
