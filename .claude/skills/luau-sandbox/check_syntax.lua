--[[
	luau-sandbox / check_syntax.lua
	================================
	Fast, standalone syntax-only check — no mocks, no execution, just the
	real Luau parser. Use this FIRST, before harness.lua, whenever a
	script "doesn't run" and the cause is unclear: it separates "the
	parser rejects this source" (a real syntax error, fix the text) from
	"it parses fine but errors at runtime" (a logic/API bug — go use
	harness.lua to trace where).

	Usage:
	  ./luau check_syntax.lua -a "$(cat target.lua)"
]]

local src = ...
if type(src) ~= "string" or #src == 0 then
	print("SYNTAX_ERROR: no source provided (pass via -a \"$(cat target.lua)\")")
	return
end

local chunk, err = loadstring(src, "target")
if chunk then
	print("SYNTAX_OK (" .. #src .. " bytes parsed cleanly)")
else
	-- err is like "target:LINE: message" — surfaced as-is, it already
	-- points at the exact line/column Luau's parser choked on.
	print("SYNTAX_ERROR: " .. tostring(err))
end
