---
name: luau-sandbox
description: Dynamic sandbox for running/tracing Luau (Roblox) scripts outside Roblox — reveals real API calls, decoded strings and behavior of heavily obfuscated or VM-protected scripts (MoonVeil, Luraph, etc.), and doubles as a headless way to smoke-test this repo's own hub script. Use whenever a task involves understanding, auditing, or debugging a Luau/Roblox script's actual runtime behavior — "what does this script do", "deobfuscate this", "is this script safe", "trace this script's API calls", or testing changes to yslem_hub.lua without a Roblox client.
---

# luau-sandbox

A reusable tool for **dynamically** analyzing Luau/Roblox scripts by
actually running them under the real Luau interpreter inside a mocked
environment, instead of trying to read obfuscated/minified source
statically. Built while reverse-engineering a MoonVeil-protected script;
generalized here so future tasks don't redo that groundwork.

## Why dynamic instead of static

Roblox script obfuscators (MoonVeil, Luraph, Ironbrew, Prometheus, ...)
commonly compile the original script into a flattened state-machine or a
custom bytecode VM, with every string and number constant encoded and
decoded at runtime. Reading that by eye is unreliable and slow. Running it
for real and *observing* what it does — every `game:GetService` call,
every decoded string, every `Instance.new` property — is far more
reliable and gives ground truth instead of a guess.

## Critical lesson: use REAL Luau, not Lua 5.1/5.3

The first attempt at this used plain `lua5.1`/`lua5.3` (via apt) with
hand-rolled `bit32`/`string.pack` polyfills. It kept crashing deep inside
the target's own decoding routines with cryptic "attempt to call a nil
value" errors from opaque-predicate control-flow flattening taking the
wrong branch. Root causes, in case they bite again:

- **Number formatting differs.** Luau (like Lua 5.1) has a single number
  type and formats `893` as `"893"` when concatenated into a string.
  Lua 5.3+ has separate int/float subtypes and formats a float as
  `"893.0"`. Any obfuscated code that builds strings from decoded numbers
  (very common) silently breaks under 5.3.
- **Luau refuses `number < table` even with `__lt` defined.** Unlike
  reference Lua, Luau's VM will not dispatch a comparison metamethod when
  one operand is a number and the other isn't — it errors immediately.
  Mock objects standing in for real values (Health, Transparency, ...)
  must be real numbers, not tables, or comparisons involving them just
  crash (see `NUMERIC_PROPS` in harness.lua).
- **No `0b` binary literals, no native `bit32` semantics match** unless
  you use real Luau — these obfuscators lean on both heavily for
  aesthetics and for XOR-based constant decoding.

Building the real interpreter from source
(`build_luau.sh`, ~1-2 min) sidesteps all of this instead of chasing
semantic differences one crash at a time.

## Usage

```bash
# 1. Build once (idempotent - skips if already built)
LUAU="$(.claude/skills/luau-sandbox/build_luau.sh)"
echo "$LUAU"   # path to the built CLI

# 2. "It doesn't run" — check syntax FIRST, before anything else. Fast,
#    no mocks, just the real parser. Separates "real syntax error" from
#    "parses fine, fails at runtime" so you're not debugging the wrong
#    problem.
"$LUAU" .claude/skills/luau-sandbox/check_syntax.lua -a "$(cat target.lua)"
#   -> SYNTAX_OK (N bytes parsed cleanly)         => not a syntax problem, go to step 3
#   -> SYNTAX_ERROR: target:LINE: message         => real parse error, fix the text at LINE

# 3. Run the target through the full sandbox, capture the trace
"$LUAU" .claude/skills/luau-sandbox/harness.lua -a "$(cat target.lua)" > trace.log 2>&1
grep -E '^(SYNTAX_OK|SYNTAX_ERROR|PRINT|INVOKE_ERROR|LOAD_ERROR|RUN_RESULT)' trace.log

# 4. Read the full trace for detail
grep -E '^(PRINT|CALL|SET|INVOKE_ERROR)' trace.log | less
```

harness.lua also emits its own `SYNTAX_OK`/`SYNTAX_ERROR` as the very
first trace lines (same check as step 2, just inline) — so even without
running check_syntax.lua separately, the top of `trace.log` always
answers "is this a syntax problem?" before anything else.

**"It doesn't run" is very often NOT a syntax error.** The most common
real cause seen so far: a script calls `readfile()` on its own config/save
file without an `isfile()` guard or `pcall`. That's fine once the file
exists, but on a first run — before the script has ever saved one —
`readfile()` throws on most executors and kills the whole script before
it builds anything. `RUN_RESULT false ...: file does not exist (not in
FAKE_FILES)` in the trace is this exact bug (see below).

The source is passed via a `-a` command-line argument (not read with
`io.open` from inside the sandboxed script) because stock Luau has **no
`io` library at all** — same as real Roblox. `print()` inside the harness
is the *real* print, so the shell redirect (`> trace.log`) is what
captures everything; the sandboxed target's own `print` is separately
wrapped to log through the same channel with a `PRINT` tag.

### Reading the trace

Each line is tab-separated, starting with a tag:
- `SYNTAX_OK` / `SYNTAX_ERROR <message>` — always the first line(s);
  whether the real Luau parser accepted the source at all
- `INDEX <path>` — the script read a property/global (e.g. `game.Players`)
- `CALL <path>(<args>)` — the script called a function/method
- `SET <path> = <value>` — the script assigned a property
- `PRINT ...` — the script's own `print()`/`warn()` output — usually the
  most human-readable signal of what it's doing
- `INVOKE <label>` / `INVOKE_ERROR <label> <message>` — a `task.spawn`,
  `task.delay`, or `.Connect` handler was actually invoked (not just
  logged) so its body executes and traces too
- `WAIT_CALL #n` — a `task.wait()`/`wait()` inside a spawned function;
  each spawned invocation gets its own bounded budget
  (`LUAU_SANDBOX_WAIT_BUDGET`, default 10) so `while true do task.wait()
  end` loops run a few iterations and stop instead of hanging
- `LOADSTRING_SRC_BEGIN` / `..._END` — the script tried to
  `loadstring`/`load` more code at runtime; the source is dumped verbatim
  between these markers (and NOT auto-executed, for safety) — always
  check for this, it's the strongest signal of a second-stage payload
- `UNMOCKED_GLOBAL_READ <name>` — a global harness.lua doesn't already
  know about was read; if a name here looks meaningful, consider whether
  it needs special handling (see below)

### Extending for a specific target

Everything unknown becomes a permissive mock automatically, but two
things are worth tailoring per target if the trace stops early or looks
wrong:

- **`NUMERIC_PROPS`** (top of harness.lua): add any Roblox property the
  script compares/does math on that isn't already listed (Luau errors
  immediately on `number < table`, see above). The trace's
  `INVOKE_ERROR ... attempt to compare` lines point at exactly which
  property needs adding.
- **`FAKE_FILES`**: `readfile()`/`isfile()` default to "the file does not
  exist" for any path NOT listed here — on purpose (see above), to
  surface unguarded readfile() calls instead of hiding them. If the
  script reads a config and branches on its shape (e.g.
  `if config.autoStart then ...`), populate this table with plausible
  JSON so those branches take their real path instead of erroring or
  operating on an opaque mock. `HttpService:JSONDecode` is already wired
  to a real JSON parser, so valid JSON here becomes real Lua
  values/booleans/numbers in the sandboxed script. Test BOTH with and
  without an entry present — a script should survive its very first run
  (no file yet) as gracefully as a later one (file present).
- **`LUAU_SANDBOX_WAIT_BUDGET`** env var: raise it if a loop needs more
  iterations to reach interesting behavior (e.g. `LUAU_SANDBOX_WAIT_BUDGET=30 "$LUAU" ...`).

## Safety notes

- No real network access is ever granted — `request`, `HttpGet`,
  `http_request`, etc. are all inert mocks that just log the call and
  return another mock. A script cannot exfiltrate anything through this
  sandbox even if it tries to.
- `loadstring`/`load` calls are intercepted and logged, never executed —
  if a target tries to run a second-stage payload, you get to read it
  first.
- This is for **understanding behavior**, not a guarantee of a perfect
  byte-for-byte decompilation. A trace tells you what a script *did on
  the path it took through the mocks* — branches gated on real game
  state (actual player position, actual server population, etc.) won't
  be observed exactly as they'd behave in a live game. Say so explicitly
  in any findings/report produced from a trace.

## Also useful for: testing this repo's own script

`yslem_hub.lua` / `upd` in this repo are plain (non-obfuscated) Luau, so
the same harness works directly on them as a **headless smoke test** —
run a change through the sandbox before pushing to catch syntax errors,
nil-global typos, or an unreachable code path, without needing an actual
Roblox session:

```bash
"$LUAU" .claude/skills/luau-sandbox/harness.lua -a "$(cat yslem_hub.lua)" > trace.log 2>&1
grep -E 'INVOKE_ERROR|LOAD_ERROR|RUN_RESULT' trace.log
```
