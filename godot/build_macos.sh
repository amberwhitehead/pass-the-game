#!/usr/bin/env bash
# Build a standalone Mac app using Godot and its matching macOS export template.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_BIN="${GODOT:-}"
if [[ -z "$GODOT_BIN" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
    GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
  else
    echo 'Set GODOT to the Godot 4.7.2 executable or install Godot.app in /Applications.' >&2
    exit 1
  fi
fi

OUTPUT="${1:-$PROJECT_DIR/build/macos/Pass The Game.app}"
if [[ "$OUTPUT" != /* ]]; then
  OUTPUT="$PWD/$OUTPUT"
fi
mkdir -p "$(dirname "$OUTPUT")"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release macOS "$OUTPUT"

# Finder may attach bundle metadata that strict code-signature verification rejects.
if [[ "$OUTPUT" == *.app ]] && command -v codesign >/dev/null 2>&1; then
  if xattr -p com.apple.FinderInfo "$OUTPUT" >/dev/null 2>&1; then
    xattr -d com.apple.FinderInfo "$OUTPUT"
  fi
  codesign --verify --deep --strict "$OUTPUT"
fi
echo "Built: $OUTPUT"
