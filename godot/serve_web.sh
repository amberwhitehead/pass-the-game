#!/usr/bin/env bash
# Export the Web build and serve it on your LAN so a phone can open it.
# Needs Web export templates installed (Editor > Manage Export Templates).
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}"
mkdir -p build/web
"$GODOT" --headless --path . --export-release Web build/web/index.html
echo "LAN (HTTP, desktop only): http://$(hostname -I | awk '{print $1}'):8060"
# Godot's web loader refuses plain HTTP (needs a secure context), so phones on the
# tailnet must use HTTPS. `tailscale serve` provides it; it needs Serve + HTTPS
# enabled once for the tailnet (the command prints a link if not).
if command -v tailscale >/dev/null; then
  TS_NAME=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['Self']['DNSName'].rstrip('.'))" 2>/dev/null || true)
  if timeout 20 tailscale serve --bg 8060 >/dev/null 2>&1; then
    echo "Tailscale: https://$TS_NAME"
  else
    echo "Tailscale HTTPS not set up: run 'tailscale serve --bg 8060' once and follow its link."
  fi
fi
python3 -m http.server 8060 --directory build/web
