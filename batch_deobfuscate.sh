#!/bin/bash
# Batch Deobfuscator for Multiple Scripts
# Usage: ./batch_deobfuscate.sh <input_directory> [output_directory]

set -e

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-./deobfuscated}"

if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ Error: Input directory not found: $INPUT_DIR"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "🔓 Batch Lua Deobfuscator"
echo "=========================="
echo ""
echo "📂 Input directory: $INPUT_DIR"
echo "📂 Output directory: $OUTPUT_DIR"
echo ""

# Count files
TOTAL=$(find "$INPUT_DIR" -maxdepth 1 -name "*.lua" | wc -l)

if [ $TOTAL -eq 0 ]; then
    echo "⚠️  No Lua files found in $INPUT_DIR"
    exit 0
fi

echo "📊 Found $TOTAL Lua file(s)"
echo ""

# Process each file
COUNT=0
SUCCESS=0
FAILED=0

for file in "$INPUT_DIR"/*.lua; do
    if [ -f "$file" ]; then
        COUNT=$((COUNT + 1))
        FILENAME=$(basename "$file")

        echo "[$COUNT/$TOTAL] Processing: $FILENAME"

        if python3 deobfuscator.py "$file" -o "$OUTPUT_DIR/${FILENAME%.lua}_deobf.lua" 2>/dev/null; then
            SUCCESS=$((SUCCESS + 1))
            echo "✅ Success"
        else
            FAILED=$((FAILED + 1))
            echo "❌ Failed"
        fi

        echo ""
    fi
done

echo "=========================="
echo "📊 Summary:"
echo "   ✅ Success: $SUCCESS"
echo "   ❌ Failed: $FAILED"
echo ""
echo "📂 Deobfuscated scripts saved to: $OUTPUT_DIR"
