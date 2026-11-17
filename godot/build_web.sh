#!/usr/bin/env bash
# Build the browser playtest using Godot and its matching Web export template.
set -euo pipefail

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: $0 [OUTPUT_DIRECTORY]"
  echo 'Set GODOT to the Godot 4.7.2 executable if it is not on PATH.'
  exit 0
fi
if (( $# > 1 )); then
  echo "Usage: $0 [OUTPUT_DIRECTORY]" >&2
  exit 1
fi

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

OUTPUT_DIR="${1:-$PROJECT_DIR/build/web}"
if [[ "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="$PWD/$OUTPUT_DIR"
fi
mkdir -p "$PROJECT_DIR/build" "$OUTPUT_DIR"
# Exported assets and audition copies must not become project resources on rebuild.
touch "$PROJECT_DIR/build/.gdignore"
"$GODOT_BIN" --headless --audio-driver Dummy --path "$PROJECT_DIR" --import
"$GODOT_BIN" --headless --audio-driver Dummy --path "$PROJECT_DIR" --export-release Web "$OUTPUT_DIR/index.html"
python3 "$PROJECT_DIR/../tools/build_audio_audition.py" --output "$OUTPUT_DIR/audio"
echo "Built: $OUTPUT_DIR/index.html"
