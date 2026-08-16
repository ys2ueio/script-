# 🔓 Lua Deobfuscator for Roblox Scripts

Recover your obfuscated Roblox Lua scripts and get back the readable source code!

## Features ✨

- 🔍 **String Extraction** - Decodes `string.char()` encoded strings
- 🔤 **Variable Renaming** - Converts `v1`, `t2`, etc. to meaningful names
- 🗑️ **Dead Code Removal** - Cleans up obviously unused code blocks
- ✨ **Code Formatting** - Prettifies and indents the output
- 💬 **Auto-Comments** - Adds helpful comments for Roblox patterns
- 📊 **Detailed Reports** - Shows variable mapping and recovered strings

## Quick Start 🚀

### Single Script
```bash
python3 deobfuscator.py your_obfuscated_script.lua
```

Output files:
- `your_obfuscated_script_deobf.lua` - Deobfuscated script
- `your_obfuscated_script_deobf_mapping.json` - Variable mapping details

### Multiple Scripts (Batch)
```bash
chmod +x batch_deobfuscate.sh
./batch_deobfuscate.sh ./my_scripts ./recovered_scripts
```

This will:
1. Find all `.lua` files in `./my_scripts`
2. Deobfuscate each one
3. Save results to `./recovered_scripts`

## How It Works 🔧

### Step 1: Extract Encoded Strings
Luraph often encodes strings using `string.char()`:
```lua
-- Before
string.char(72, 101, 108, 108, 111)

-- After
"Hello"
```

### Step 2: Identify Function References
Extracts references like:
```lua
b1 = buffer.create
b2 = buffer.fromstring
-- etc...
```

### Step 3: Rename Variables
Converts obfuscated names to readable ones:
```lua
-- Before
local v1 = {}
local t2 = game:GetService("RunService")

-- After
local var_1 = {}
local table_2 = game:GetService("RunService")
```

### Step 4: Clean Code
Removes dead code and unnecessary loops

### Step 5: Format
Adds proper indentation and structure

### Step 6: Add Comments
Helps identify Roblox-specific patterns

## Output Files 📋

### `.lua` file
The deobfuscated script with readable code

### `.json` file
Contains metadata:
```json
{
  "variables": {
    "v1": "var_1",
    "t2": "table_2"
  },
  "strings": {
    "string.char(72,101,108,108,111)": "Hello"
  },
  "functions": {
    "b1": "buffer.create"
  }
}
```

## Requirements 📦

- Python 3.6+
- Lua 5.1+ (for Lua version)

## Usage Examples 📚

### Example 1: Single File
```bash
$ python3 deobfuscator.py my_script.lua
🔓 Starting deobfuscation...
📝 Extracting encoded strings...
🔍 Extracting table-stored strings...
🔤 Renaming variables...
🗑️ Removing dead code...
✨ Formatting code...
💬 Adding comments...

✅ Deobfuscation complete!

📂 Deobfuscated script: my_script_deobf.lua
📋 Variable mapping: my_script_deobf_mapping.json

📊 Statistics:
   - Variables renamed: 24
   - Strings recovered: 8
   - Functions identified: 12
```

### Example 2: Batch Processing
```bash
$ ./batch_deobfuscate.sh ./obfuscated_scripts ./recovered
🔓 Batch Lua Deobfuscator
==========================

📂 Input directory: ./obfuscated_scripts
📂 Output directory: ./recovered

📊 Found 5 Lua file(s)

[1/5] Processing: script1.lua
✅ Success

[2/5] Processing: script2.lua
✅ Success

[3/5] Processing: script3.lua
✅ Success

[4/5] Processing: script4.lua
✅ Success

[5/5] Processing: script5.lua
✅ Success

==========================
📊 Summary:
   ✅ Success: 5
   ❌ Failed: 0

📂 Deobfuscated scripts saved to: ./recovered
```

## Limitations ⚠️

This tool handles common Luraph obfuscation patterns but may not recover:
- Complex nested encodings
- Dynamically generated code
- Some advanced control flow obfuscation

For these cases, manual analysis may still be needed.

## Tips for Better Results 💡

1. **Start with simpler scripts** to understand the obfuscation pattern
2. **Check the JSON mapping** to verify variable names make sense
3. **Look for Roblox patterns** in the comments - they indicate common code blocks
4. **Test the script** in your Roblox environment after recovery
5. **Save the mapping** - it helps understand the obfuscation technique

## Troubleshooting 🔧

### Error: "File not found"
Make sure the file path is correct:
```bash
python3 deobfuscator.py ./path/to/script.lua
```

### Error: "No Lua files found"
Check that your scripts have `.lua` extension:
```bash
ls -la your_script*.lua
```

### Partial deobfuscation
Some advanced obfuscation patterns may not be fully reversed. In this case:
1. Check the output file - it may still be more readable
2. Use the mapping file to understand variable purposes
3. Add manual comments based on your knowledge

## Contributing 🤝

Found a bug or want to improve? Let me know!

## Support 💬

If you need help:
1. Check the examples above
2. Look at the generated mapping file
3. Try the batch processor on a single file first
4. Check the output formatting

---

**Remember**: These are YOUR scripts! You have the right to recover your own code. 💪
