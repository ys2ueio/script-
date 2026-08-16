#!/usr/bin/env python3
"""
Roblox Lua Deobfuscator
Helps recover obfuscated script source code
"""

import re
import sys
import json
from pathlib import Path
from collections import defaultdict

class LuaDeobfuscator:
    def __init__(self):
        self.var_map = {}
        self.var_counter = defaultdict(int)
        self.string_cache = {}
        self.functions_cache = {}

    def extract_encoded_strings(self, code):
        """Extract and decode string.char() encoded strings"""
        print("📝 Extracting encoded strings...")

        # Pattern for string.char(num, num, ...)
        pattern = r'string\.char\(([0-9,\s]+)\)'

        def decode_chars(match):
            nums = match.group(1)
            chars = re.findall(r'\d+', nums)
            try:
                decoded = ''.join(chr(int(c)) for c in chars)
                self.string_cache[match.group(0)] = decoded
                return f'"{decoded}"'
            except:
                return match.group(0)

        result = re.sub(pattern, decode_chars, code)
        return result

    def extract_table_strings(self, code):
        """Extract strings stored in tables"""
        print("🔍 Extracting table-stored strings...")

        # Look for patterns like: b1=buffer.create, b2=buffer.fromstring, etc.
        pattern = r'([a-z]\d+)\s*=\s*([a-zA-Z0-9_\.]+)'

        for match in re.finditer(pattern, code):
            var_name = match.group(1)
            func_name = match.group(2)
            self.functions_cache[var_name] = func_name

        return code

    def rename_variables(self, code):
        """Rename obfuscated variables to meaningful names"""
        print("🔤 Renaming variables...")

        # Find all variable assignments and usages
        var_pattern = r'\b([a-z]\d+|[a-z]{2}\d+)\b'

        for match in re.finditer(var_pattern, code):
            var = match.group(1)
            if var not in self.var_map:
                # Create meaningful name
                prefix = re.match(r'[a-z]+', var).group(0)
                type_names = {
                    'v': 'var', 't': 'table', 'f': 'func',
                    's': 'str', 'n': 'num', 'b': 'buf',
                    'a': 'arr', 'x': 'result', 'o': 'obj'
                }
                type_name = type_names.get(prefix[0], 'var')
                self.var_counter[type_name] += 1
                self.var_map[var] = f"{type_name}_{self.var_counter[type_name]}"

        # Replace all occurrences
        result = code
        for old_var, new_var in sorted(self.var_map.items(), key=lambda x: -len(x[0])):
            pattern = r'\b' + re.escape(old_var) + r'\b'
            result = re.sub(pattern, new_var, result)

        return result

    def clean_dead_code(self, code):
        """Remove obviously dead code"""
        print("🗑️ Removing dead code...")

        # Remove while true loops that just loop infinitely
        code = re.sub(
            r'while\s+true\s+do\s*\n\s*\w+\s*=\s*\w+\s*\n\s*end',
            '-- [DEAD CODE REMOVED]',
            code
        )

        return code

    def format_code(self, code):
        """Format and prettify the code"""
        print("✨ Formatting code...")

        lines = code.split('\n')
        formatted = []
        indent = 0

        for line in lines:
            stripped = line.strip()

            if not stripped or stripped.startswith('--'):
                formatted.append(line)
                continue

            # Decrease indent for closing statements
            if stripped.startswith('end') or stripped.startswith('elseif') or stripped.startswith('else'):
                indent = max(0, indent - 1)

            # Add proper indentation
            indented = '    ' * indent + stripped
            formatted.append(indented)

            # Increase indent for opening statements
            if any(stripped.endswith(kw) for kw in ['then', 'do', '{']):
                indent += 1
            if 'function' in stripped and '(' in stripped:
                indent += 1

        return '\n'.join(formatted)

    def add_comments(self, code):
        """Add helpful comments"""
        print("💬 Adding comments...")

        lines = code.split('\n')
        result = []

        # Add header
        result.append('-- Deobfuscated Script')
        result.append('-- Recovered by Roblox Lua Deobfuscator')
        result.append('-- ')
        result.append('')

        for line in lines:
            result.append(line)

            # Add comments for common Roblox patterns
            if 'GetService' in line:
                result.append('-- ^ Service initialization')
            elif 'WaitForChild' in line:
                result.append('-- ^ Waiting for child object')
            elif 'Connect' in line:
                result.append('-- ^ Event connection')

        return '\n'.join(result)

    def deobfuscate(self, code):
        """Main deobfuscation process"""
        print("\n🔓 Starting deobfuscation...\n")

        # Step 1: Extract encoded strings
        code = self.extract_encoded_strings(code)

        # Step 2: Extract function references
        code = self.extract_table_strings(code)

        # Step 3: Clean dead code
        code = self.clean_dead_code(code)

        # Step 4: Rename variables
        code = self.rename_variables(code)

        # Step 5: Format code
        code = self.format_code(code)

        # Step 6: Add comments
        code = self.add_comments(code)

        print("\n✅ Deobfuscation complete!\n")
        return code

    def save_results(self, code, output_path):
        """Save deobfuscated code and metadata"""
        output_path.write_text(code)

        # Save variable mapping
        mapping_path = output_path.with_stem(output_path.stem + '_mapping').with_suffix('.json')
        mapping_path.write_text(json.dumps({
            'variables': self.var_map,
            'strings': self.string_cache,
            'functions': self.functions_cache
        }, indent=2))

        return output_path, mapping_path

def main():
    if len(sys.argv) < 2:
        print("🔓 Roblox Lua Deobfuscator")
        print("\nUsage:")
        print("  python3 deobfuscator.py <script.lua>")
        print("  python3 deobfuscator.py <script.lua> -o <output.lua>")
        print("\nExamples:")
        print("  python3 deobfuscator.py obfuscated.lua")
        print("  python3 deobfuscator.py obfuscated.lua -o recovered.lua")
        return

    input_path = Path(sys.argv[1])

    if not input_path.exists():
        print(f"❌ Error: File not found: {input_path}")
        return

    # Determine output path
    if len(sys.argv) > 3 and sys.argv[2] == '-o':
        output_path = Path(sys.argv[3])
    else:
        output_path = input_path.with_stem(input_path.stem + '_deobf')

    # Read input
    code = input_path.read_text(encoding='utf-8', errors='ignore')

    # Deobfuscate
    deobf = LuaDeobfuscator()
    result = deobf.deobfuscate(code)

    # Save results
    script_path, mapping_path = deobf.save_results(result, output_path)

    print(f"📂 Deobfuscated script: {script_path}")
    print(f"📋 Variable mapping: {mapping_path}")
    print(f"\n📊 Statistics:")
    print(f"   - Variables renamed: {len(deobf.var_map)}")
    print(f"   - Strings recovered: {len(deobf.string_cache)}")
    print(f"   - Functions identified: {len(deobf.functions_cache)}")

if __name__ == '__main__':
    main()
