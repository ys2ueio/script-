-- Deobfuscated Script
-- Recovered by Roblox Lua Deobfuscator
-- 

-- Example Obfuscated Script (for demonstration)
do
    local var_1 = "GetService"
-- ^ Service initialization
    local var_2 = {}

    local function var_3(var_4, var_5)
        if not var_4 then
            -- [DEAD CODE REMOVED]
        end
    end

    local table_1 = game
    local table_2 = table_1[var_1]("RunService")
    local table_3 = "Players"
    local table_4 = game[var_1](table_3)

    local function func_1(var_6)
        local var_7 = var_6.Parent
        local var_8 = var_7:GetChildren()

        for i, var_9 in ipairs(var_8) do
            if var_9.ClassName == "Humanoid" then
                var_2[var_9] = true
            end
        end
    end

    local buf_1 = buffer.create
    local buf_2 = buffer.fromstring
    local buf_3 = buffer.tostring

    local var_10 = buf_1(32)
    buf_2(var_10, "TestData")

    local str_1 = buf_3(var_10)
    var_3(str_1 ~= nil, "buffer-test")

    local function var_11()
        return table_2:IsRunning()
    end

    var_3(type(var_11) == "function", "function-check")

        print("Deobfuscation test complete")
    end
