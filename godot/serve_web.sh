#!/usr/bin/env bash
# Build and serve a local browser playtest on macOS or Linux.
set -euo pipefail

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: $0 [PORT] [OUTPUT_DIRECTORY]"
  echo 'Defaults: port 8060, godot/build/web. Ctrl-C stops the server.'
  exit 0
fi
if (( $# > 2 )); then
  echo "Usage: $0 [PORT] [OUTPUT_DIRECTORY]" >&2
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${1:-8060}"
if [[ ! "$PORT" =~ ^[0-9]{1,5}$ ]] || (( 10#$PORT < 1 || 10#$PORT > 65535 )); then
  echo 'PORT must be an integer from 1 to 65535.' >&2
  exit 1
fi
PORT=$((10#$PORT))
OUTPUT_DIR="${2:-$PROJECT_DIR/build/web}"
if [[ "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="$PWD/$OUTPUT_DIR"
fi
"$PROJECT_DIR/build_web.sh" "$OUTPUT_DIR"
echo "Playtest: http://localhost:$PORT/"
echo 'Serving on this computer. Ctrl-C stops the server.'
exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$OUTPUT_DIR"
