--[[
	luau-sandbox / harness.lua
	==========================
	Generic dynamic-tracing sandbox for Luau / Roblox scripts.

	Runs a target script under the REAL Luau interpreter (built by
	build_luau.sh) with every Roblox/executor global replaced by a mock
	that logs each access/call instead of erroring. This lets a script
	run far enough to decode its own obfuscation, reveal its real string
	constants, and show exactly which game APIs it touches — without a
	real Roblox client and without ever making a real network request.

	Usage:
	  ./luau harness.lua -a "$(cat target.lua)" > trace.log 2>&1

	See SKILL.md in this directory for the full write-up, the Luau-vs-Lua
	gotchas that make this necessary, and how to extend the mocks for a
	specific target (fake file contents, known Instance trees, etc).
]]

--=============================================================
-- Logging (no `io` library in stock Luau, matches Roblox — log via
-- print() and let the shell redirect stdout to a file)
--=============================================================
local realprint = print
local LOG_LIMIT = tonumber(os and os.getenv and os.getenv("LUAU_SANDBOX_LOG_LIMIT") or "") or 200000
local logcount = 0
local function logf(...)
	logcount = logcount + 1
	if logcount > LOG_LIMIT then
		error("LOG_LIMIT_REACHED (likely an infinite loop against a mock; raise LUAU_SANDBOX_LOG_LIMIT if needed)")
	end
	local n = select('#', ...)
	local parts = {}
	for i = 1, n do parts[i] = tostring((select(i, ...))) end
	realprint(table.concat(parts, "\t"))
end

--=============================================================
-- Universal recursive mock: any unknown global/property/method resolves
-- to a mock; indexing, calling, comparing, and concatenating all "work"
-- (logged) instead of raising errors, so execution can run deep into a
-- script that touches many APIs we don't have real implementations for.
--=============================================================
local mock_mt = {}
local serviceCache = {} -- game:GetService(name) singleton cache
local jsonEncode, jsonDecode -- defined below, used as upvalues in __call

local function mockname(t) return rawget(t, "__name") or "?" end
local function make_mock(name)
	return setmetatable({__name = name}, mock_mt)
end

-- Roblox properties that real game code virtually always compares/does
-- arithmetic on numerically. Luau refuses number<->table comparisons even
-- via __lt (unlike PUC Lua), so anything the script is likely to compare
-- against a number needs to actually BE a number in the mock, or those
-- branches just error out and the trace stops early. Extend this table
-- for a specific target if it errors on a property not listed here.
local NUMERIC_PROPS = {
	Health = 100, MaxHealth = 100, Transparency = 0, Y = 0, X = 0, Z = 0,
	Magnitude = 10, Value = 0, Time = 0, Volume = 1, PlaybackSpeed = 1,
	WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, CameraFieldOfView = 70,
}

mock_mt.__index = function(t, k)
	-- Numeric keys must return nil (not a fabricated mock), otherwise any
	-- ipairs()/# on a mock "array" loops forever since every index looks
	-- populated. Treat mocks as empty arrays by default.
	if type(k) == "number" then return nil end
	if type(k) == "string" and NUMERIC_PROPS[k] ~= nil then
		logf("INDEX", mockname(t) .. "." .. k, "(numeric mock ->", NUMERIC_PROPS[k], ")")
		return NUMERIC_PROPS[k]
	end
	local nm = mockname(t) .. "." .. tostring(k)
	logf("INDEX", nm)
	local child = make_mock(nm)
	rawset(t, k, child)
	return child
end
mock_mt.__newindex = function(t, k, v)
	logf("SET", mockname(t) .. "." .. tostring(k), "=", tostring(v))
	rawset(t, k, v)
end

-- Scheduler + event mocks that actually invoke the callback once (instead
-- of just logging the call) so we can see inside spawned coroutines and
-- Connect() handlers. A bounded, PER-INVOCATION "wait budget" turns any
-- `while true do task.wait() end` loop into a few traced iterations
-- instead of a hang (and instead of one loop draining a global budget
-- other coroutines never get to use).
local WAIT_BUDGET = tonumber(os and os.getenv and os.getenv("LUAU_SANDBOX_WAIT_BUDGET") or "") or 10
local waitcalls = 0
local STOP_SENTINEL = "__TRACE_STOP__"
local function boundedWait(...)
	waitcalls = waitcalls + 1
	logf("WAIT_CALL", "#" .. waitcalls)
	if waitcalls > WAIT_BUDGET then
		error(STOP_SENTINEL .. ": wait budget exceeded (expected - breaks out of loops)")
	end
	return 0
end
local function runOnce(label, fn, ...)
	logf("INVOKE", label)
	waitcalls = 0
	local ok, err = pcall(fn, ...)
	if not ok and not tostring(err):find(STOP_SENTINEL, 1, true) then
		logf("INVOKE_ERROR", label, tostring(err))
	end
end

mock_mt.__call = function(t, ...)
	local n = select('#', ...)
	local argstrs = {}
	for i = 1, n do
		local v = select(i, ...)
		if type(v) == "table" and rawget(v, "__name") then
			argstrs[i] = "<" .. rawget(v, "__name") .. ">"
		else
			argstrs[i] = tostring(v)
		end
	end
	local nm = mockname(t)
	logf("CALL", nm .. "(" .. table.concat(argstrs, ", ") .. ")")

	-- Simulate event connections firing once, so click/input/property
	-- handlers get traced too instead of just recorded as "connected".
	if nm:match("%.Connect$") then
		-- called as obj:Connect(fn) => (self, fn, ...): handler is arg #2
		local handler = select(2, ...)
		if type(handler) == "function" then
			logf("INVOKE", nm .. " (simulated fire)")
			local ok, err = pcall(handler, make_mock("eventArg1"), make_mock("eventArg2"))
			if not ok and not tostring(err):find(STOP_SENTINEL, 1, true) then
				logf("INVOKE_ERROR", nm, tostring(err))
			end
		end
	end

	-- game:GetService(name) should be a stable singleton by name, not a
	-- fresh anonymous mock per call, both for trace readability and so
	-- HttpService can get a real JSON codec (see below).
	if nm == "game.GetService" then
		local svc = select(2, ...)
		if type(svc) == "string" then
			if serviceCache[svc] then return serviceCache[svc] end
			local m = make_mock(svc)
			serviceCache[svc] = m
			if svc == "HttpService" then
				rawset(m, "JSONEncode", function(_, v) return jsonEncode(v) end)
				rawset(m, "JSONDecode", function(_, s) return jsonDecode(tostring(s)) end)
			end
			return m
		end
	end

	return make_mock(nm .. "()")
end

mock_mt.__tostring = function(t) return "<mock:" .. mockname(t) .. ">" end
mock_mt.__len = function(t) return 0 end

local function coerce(v)
	if type(v) == "table" and rawget(v, "__name") then return tostring(v) end
	return v
end
mock_mt.__concat = function(a, b) return tostring(coerce(a)) .. tostring(coerce(b)) end
mock_mt.__add = function(a, b) return make_mock("(" .. tostring(coerce(a)) .. "+" .. tostring(coerce(b)) .. ")") end
mock_mt.__sub = function(a, b) return make_mock("(" .. tostring(coerce(a)) .. "-" .. tostring(coerce(b)) .. ")") end
mock_mt.__mul = function(a, b) return make_mock("(" .. tostring(coerce(a)) .. "*" .. tostring(coerce(b)) .. ")") end
mock_mt.__div = function(a, b) return make_mock("(" .. tostring(coerce(a)) .. "/" .. tostring(coerce(b)) .. ")") end
mock_mt.__unm = function(a) return make_mock("(-" .. tostring(coerce(a)) .. ")") end
mock_mt.__eq = function(a, b) return rawequal(a, b) end
mock_mt.__lt = function(a, b) return false end
mock_mt.__le = function(a, b) return false end

--=============================================================
-- Tiny JSON codec so HttpService:JSONDecode/JSONEncode round-trip real
-- numbers/strings/booleans instead of opaque mocks (needed since Luau
-- won't compare number<->table even via metamethods, so config values
-- must come back as real numbers for the script's branches to execute
-- instead of erroring).
--=============================================================
jsonEncode = function(v, seen)
	local ty = type(v)
	if ty == "table" and rawget(v, "__name") then return '"' .. tostring(v) .. '"' end
	if ty == "nil" then return "null" end
	if ty == "boolean" then return tostring(v) end
	if ty == "number" then return tostring(v) end
	if ty == "string" then return string.format("%q", v) end
	if ty == "table" then
		seen = seen or {}
		if seen[v] then return "null" end
		seen[v] = true
		local isArray, n = true, 0
		for k in pairs(v) do
			n = n + 1
			if type(k) ~= "number" then isArray = false end
		end
		local parts = {}
		if isArray then
			for i = 1, n do parts[i] = jsonEncode(v[i], seen) end
			return "[" .. table.concat(parts, ",") .. "]"
		else
			for k, val in pairs(v) do
				parts[#parts+1] = string.format("%q", tostring(k)) .. ":" .. jsonEncode(val, seen)
			end
			return "{" .. table.concat(parts, ",") .. "}"
		end
	end
	return "null"
end

jsonDecode = function(s)
	s = tostring(s or "")
	local i = 1
	local function skip() while i <= #s and s:sub(i,i):match("%s") do i = i + 1 end end
	local parseValue
	local function parseString()
		i = i + 1
		local out = {}
		while i <= #s and s:sub(i,i) ~= '"' do
			local c = s:sub(i,i)
			if c == "\\" then i = i + 1; out[#out+1] = s:sub(i,i) else out[#out+1] = c end
			i = i + 1
		end
		i = i + 1
		return table.concat(out)
	end
	parseValue = function()
		skip()
		local c = s:sub(i,i)
		if c == '"' then return parseString()
		elseif c == '{' then
			i = i + 1; local obj = make_mock("json_object"); skip()
			if s:sub(i,i) == '}' then i = i + 1; return obj end
			while true do
				skip()
				local key = parseString()
				skip(); i = i + 1 -- ':'
				local val = parseValue()
				rawset(obj, key, val)
				skip()
				if s:sub(i,i) == ',' then i = i + 1 else break end
			end
			skip(); i = i + 1 -- '}'
			return obj
		elseif c == '[' then
			i = i + 1; local arr = {}; local n = 0; skip()
			if s:sub(i,i) == ']' then i = i + 1; return arr end
			while true do
				n = n + 1
				arr[n] = parseValue()
				skip()
				if s:sub(i,i) == ',' then i = i + 1 else break end
			end
			skip(); i = i + 1 -- ']'
			return arr
		elseif c == 't' then i = i + 4; return true
		elseif c == 'f' then i = i + 5; return false
		elseif c == 'n' then i = i + 4; return nil
		else
			local numstr = s:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", i)
			if numstr and #numstr > 0 then i = i + #numstr; return tonumber(numstr) end
			i = i + 1
			return nil
		end
	end
	if s == "" then return make_mock("json_object") end
	local ok, result = pcall(parseValue)
	if ok then return result end
	return make_mock("json_object")
end

--=============================================================
-- Fake filesystem for readfile/isfile — override FAKE_FILES for a
-- specific target script if it reads config files whose shape matters
-- (see SKILL.md).
--
-- Default is "the file does not exist" for anything not listed here —
-- NOT "every file exists and holds {}". Real executors (Synapse X, KRNL,
-- Wave, ...) throw a real Lua error when readfile() targets a missing
-- file, which is exactly the state of a script's config on someone's
-- very first run before it has ever saved one. A script that calls
-- readfile() without an isfile() guard or a pcall around it will crash
-- on first run in real life — defaulting to "always succeeds" here would
-- silently hide that exact, common bug class instead of catching it.
--=============================================================
local FAKE_FILES = {
	-- ["SomeConfig.txt"] = '{"speed":16,"enabled":true}',
}

--=============================================================
-- The sandboxed environment
--=============================================================
local env = {}
env.string, env.table, env.math, env.bit32 = string, table, math, bit32
env.os = { clock = os.clock, time = os.time, date = os.date }
env.select, env.pcall, env.xpcall = select, pcall, xpcall
env.error, env.assert = error, assert
env.tostring, env.tonumber, env.type = tostring, tonumber, type
env.next, env.pairs, env.ipairs = next, pairs, ipairs
env.rawget, env.rawset, env.rawequal, env.rawlen = rawget, rawset, rawequal, rawlen
env.setmetatable, env.getmetatable = setmetatable, getmetatable
env.unpack, env.newproxy = unpack or table.unpack, newproxy
env.getfenv, env.setfenv = getfenv, setfenv
env.coroutine = coroutine
env.utf8 = utf8
env._VERSION = _VERSION
env.print = function(...) logf("PRINT", ...) end
env.warn = function(...) logf("WARN", ...) end
env._G = env

env.loadstring = function(src, chunkname)
	logf("LOADSTRING", "len=" .. tostring(#(src or "")))
	logf("LOADSTRING_SRC_BEGIN")
	logf(tostring(src))
	logf("LOADSTRING_SRC_END")
	return make_mock("loadstring_result")
end
env.load = env.loadstring

local taskLib = setmetatable({
	wait = boundedWait,
	spawn = function(fn, ...) runOnce("task.spawn", fn, ...); return make_mock("task.spawn()") end,
	defer = function(fn, ...) runOnce("task.defer", fn, ...); return make_mock("task.defer()") end,
	delay = function(t, fn, ...) runOnce("task.delay", fn, ...); return make_mock("task.delay()") end,
	cancel = function() end,
	desynchronize = function() end,
	synchronize = function() end,
}, {
	__index = function(t, k)
		logf("INDEX", "task." .. tostring(k))
		local m = make_mock("task." .. tostring(k))
		rawset(t, k, m)
		return m
	end,
})
env.task = taskLib
env.wait = boundedWait
env.spawn = function(fn, ...) runOnce("spawn", fn, ...); return make_mock("spawn()") end
env.delay = function(t, fn, ...) runOnce("delay", fn, ...); return make_mock("delay()") end

env.readfile = function(path)
	logf("CALL", "readfile(" .. tostring(path) .. ")")
	local content = FAKE_FILES[tostring(path)]
	if content == nil then
		-- Real behavior on most executors when the file doesn't exist:
		-- a thrown error, not an empty/placeholder result. If the target
		-- doesn't guard this with isfile()/pcall(), this is meant to blow
		-- up the trace and point straight at the missing guard.
		error(tostring(path) .. ": file does not exist (not in FAKE_FILES)", 0)
	end
	return content
end
env.writefile = function(path, data) logf("CALL", "writefile(" .. tostring(path) .. ", ...)"); return nil end
env.isfile = function(path)
	logf("CALL", "isfile(" .. tostring(path) .. ")")
	return FAKE_FILES[tostring(path)] ~= nil
end
env.isfolder = function(path) logf("CALL", "isfolder(" .. tostring(path) .. ")"); return true end

for _, name in ipairs({
	"game", "workspace", "script", "syn", "getgenv", "getrenv", "Instance",
	"Enum", "Color3", "Vector2", "Vector3", "UDim2", "UDim", "CFrame", "Rect",
	"TweenInfo", "Drawing", "request", "http_request",
	"makefolder", "delfile", "loadfile", "dofile", "identifyexecutor",
	"getexecutorname", "setclipboard", "queue_on_teleport", "gethui",
	"elapsedTime", "tick", "settings",
	"UserSettings", "getconnections", "hookfunction", "hookmetamethod",
	"getrawmetatable", "setreadonly", "isreadonly", "newcclosure",
	"checkcaller", "clonefunction", "islclosure", "iscclosure", "getupvalue",
	"setupvalue", "debug", "shared", "getgc", "getinstances", "getnilinstances",
	"getscriptclosure", "getscriptbytecode", "cloneref", "compareinstances",
	"fireclickdetector", "firesignal", "firetouchinterest", "fireproximityprompt",
	"getcallbackvalue", "getcustomasset", "getthreadidentity", "setthreadidentity",
	"gethiddenproperty", "sethiddenproperty", "getproperty", "setproperty",
	"get_signal_metatable", "ColorSequence", "ColorSequenceKeypoint",
	"NumberSequence", "NumberSequenceKeypoint", "NumberRange", "PhysicalProperties",
	"BrickColor", "Region3", "Axes", "Faces", "Random", "DateTime",
}) do
	env[name] = make_mock(name)
end

setmetatable(env, {
	__index = function(t, k)
		logf("UNMOCKED_GLOBAL_READ", tostring(k))
		local m = make_mock(tostring(k))
		rawset(t, k, m)
		return m
	end,
	__newindex = function(t, k, v)
		logf("GLOBAL_SET", tostring(k), "=", tostring(v))
		rawset(t, k, v)
	end,
})

--=============================================================
-- Load & run the target (source passed via `-a` command-line arg, since
-- stock Luau has no `io` library to read a file from disk)
--=============================================================
local src = ...
assert(type(src) == "string" and #src > 0, "expected target source via -a \"$(cat target.lua)\"")

-- Syntax is checked and reported FIRST and separately from execution
-- errors below — "it doesn't run" is a syntax problem only if this line
-- says so. A LOAD_ERROR here means Luau's parser rejected the source
-- (real syntax error); everything logged after SYNTAX_OK is runtime
-- behavior, not a parsing problem, even if it later fails.
local chunk, err = loadstring(src, "target")
if not chunk then
	logf("SYNTAX_ERROR", err)
	logf("LOAD_ERROR", err)
	return
end
logf("SYNTAX_OK")
setfenv(chunk, env)

local ok, err2 = xpcall(chunk, function(m) return tostring(m) .. "\n" .. debug.traceback() end)
logf("RUN_RESULT", tostring(ok), tostring(err2))
