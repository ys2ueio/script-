-- Example Obfuscated Script (for demonstration)
do
    local v1 = string.char(71, 101, 116, 83, 101, 114, 118, 105, 99, 101)
    local v2 = {}

    local function v3(v4, v5)
        if not v4 then
            while true do
                v5 = v5
            end
        end
    end

    local t1 = game
    local t2 = t1[v1]("RunService")
    local t3 = string.char(80, 108, 97, 121, 101, 114, 115)
    local t4 = game[v1](t3)

    local function f1(v6)
        local v7 = v6.Parent
        local v8 = v7:GetChildren()

        for i, v9 in ipairs(v8) do
            if v9.ClassName == string.char(72, 117, 109, 97, 110, 111, 105, 100) then
                v2[v9] = true
            end
        end
    end

    local b1 = buffer.create
    local b2 = buffer.fromstring
    local b3 = buffer.tostring

    local v10 = b1(32)
    b2(v10, string.char(84, 101, 115, 116, 68, 97, 116, 97))

    local s1 = b3(v10)
    v3(s1 ~= nil, "buffer-test")

    local function v11()
        return t2:IsRunning()
    end

    v3(type(v11) == "function", "function-check")

    print("Deobfuscation test complete")
end
