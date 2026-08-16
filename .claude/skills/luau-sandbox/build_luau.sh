#!/usr/bin/env bash
# Builds the real Luau CLI from source. Not committed as a binary (repo
# stays platform-independent and diff-clean); this takes ~1-2 min on a
# 4-core box. Re-run is a no-op if the binary already exists.
#
# Usage: ./build_luau.sh [target_dir]
#   target_dir defaults to a sibling "luau-src" directory next to this
#   script. Prints the path to the built `luau` CLI binary on success.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$SCRIPT_DIR/luau-src}"
BUILD_DIR="$TARGET_DIR/build"
BIN="$BUILD_DIR/luau"

if [ -x "$BIN" ]; then
	echo "$BIN"
	exit 0
fi

command -v cmake >/dev/null || { echo "cmake not found (apt-get install -y cmake g++)" >&2; exit 1; }
command -v g++ >/dev/null || { echo "g++ not found (apt-get install -y cmake g++)" >&2; exit 1; }

if [ ! -d "$TARGET_DIR/.git" ]; then
	git clone --depth 1 https://github.com/luau-lang/luau.git "$TARGET_DIR" >&2
fi

mkdir -p "$BUILD_DIR"
cmake -S "$TARGET_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release \
	-DLUAU_BUILD_CLI=ON -DLUAU_BUILD_TESTS=OFF >&2

NPROC="$(nproc 2>/dev/null || echo 2)"
make -C "$BUILD_DIR" -j"$NPROC" Luau.Repl.CLI >&2

if [ ! -x "$BIN" ]; then
	echo "build finished but $BIN not found" >&2
	exit 1
fi

echo "$BIN"
