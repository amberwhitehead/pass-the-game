#!/usr/bin/env python3
"""Build (and optionally serve) the browser playtest on Windows, macOS or Linux.

The same steps as godot/build_web.sh and serve_web.sh: import, export the Web preset,
build the sound audition page, then serve on this computer only.
"""
import argparse
import functools
import http.server
import os
import shutil
import subprocess
import sys
from pathlib import Path

from build_audio_audition import build as build_audition

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot"
DEFAULT_OUTPUT = PROJECT / "build/web"
REQUIRED_VERSION = "4.7.2"
MAC_APP = "/Applications/Godot.app/Contents/MacOS/Godot"


def console_variant(path: Path) -> Path:
    """Windows' windowed Godot.exe prints nothing to a terminal; prefer its _console twin."""
    if path.suffix.lower() == ".exe" and not path.stem.endswith("_console"):
        twin = path.with_name(path.stem + "_console.exe")
        if twin.is_file():
            return twin
    return path


def find_godot(explicit: str | None) -> Path:
    for candidate in [explicit, os.environ.get("GODOT"), shutil.which("godot"), MAC_APP]:
        if not candidate:
            continue
        resolved = shutil.which(candidate) or candidate
        if Path(resolved).is_file():
            return console_variant(Path(resolved).resolve())
    raise SystemExit(f"Godot {REQUIRED_VERSION} was not found. Pass --godot PATH or set GODOT.")


def version_matches(output: str) -> bool:
    """Godot prints e.g. '4.7.2.stable.official.ed1daf0bf'; export templates must match."""
    first = output.strip().splitlines()[0] if output.strip() else ""
    return first == REQUIRED_VERSION or first.startswith(REQUIRED_VERSION + ".")


def check_version(godot: Path) -> None:
    result = subprocess.run([str(godot), "--version"], capture_output=True, text=True, timeout=60)
    if not version_matches(result.stdout):
        found = result.stdout.strip() or "no version output"
        raise SystemExit(f"{godot} is Godot {found}; this project needs {REQUIRED_VERSION}. "
                         "Pass --godot PATH or set GODOT to the right executable.")


def godot_run(godot: Path, *args: str) -> None:
    subprocess.run([str(godot), "--headless", "--audio-driver", "Dummy", "--path", str(PROJECT), *args], check=True)


def build(godot: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    # Exported files and audition copies must not become project resources on the next import.
    (PROJECT / "build/.gdignore").touch()
    print(f"Importing with {godot}", flush=True)
    godot_run(godot, "--import")
    print("Exporting the Web preset", flush=True)
    godot_run(godot, "--export-release", "Web", str(output / "index.html"))
    build_audition(output / "audio")
    _inject_loading_overlay(output / "index.html")
    print(f"Built: {output / 'index.html'}", flush=True)


def _inject_loading_overlay(index_html: Path) -> None:
    '''Inject a loading overlay with cycling messages into the exported index.html.

    The overlay is hidden by default and shown/hidden by the game via JavaScriptBridge.
    Cycling happens in JS so it works even when the main thread is busy loading.'''
    overlay = '''
<style>
#loading-overlay .loading-msg { position:absolute; opacity:0; animation: showmsg 10s infinite; }
#loading-overlay .loading-msg:nth-child(1) { animation-delay: 0s; }
#loading-overlay .loading-msg:nth-child(2) { animation-delay: 2s; }
#loading-overlay .loading-msg:nth-child(3) { animation-delay: 4s; }
#loading-overlay .loading-msg:nth-child(4) { animation-delay: 6s; }
#loading-overlay .loading-msg:nth-child(5) { animation-delay: 8s; }
@keyframes showmsg {
  0% { opacity: 1; }
  19.99% { opacity: 1; }
  20% { opacity: 0; }
  100% { opacity: 0; }
}
</style>
<div id="loading-overlay" style="display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:#000;color:#fff;font-family:sans-serif;font-size:24px;justify-content:center;align-items:center;z-index:9999;">
  <div class="loading-msg">Loading…</div>
  <div class="loading-msg">Compiling shaders…</div>
  <div class="loading-msg">Counting vertices…</div>
  <div class="loading-msg">Reticulating splines…</div>
  <div class="loading-msg">Stitching meshes…</div>
</div>
'''
    text = index_html.read_text(encoding="utf-8")
    if "loading-overlay" in text:
        return  # already injected
    text = text.replace("</body>", overlay + "</body>")
    index_html.write_text(text, encoding="utf-8")


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    """Tell the browser not to cache, so a plain reload always loads the latest build.

    Without this, browsers may reuse a cached index.pck after a rebuild.
    COOP/COEP headers enable SharedArrayBuffer, required for the threaded Web build."""

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


def serve(output: Path, port: int) -> None:
    handler = functools.partial(NoCacheHandler, directory=str(output))
    with http.server.ThreadingHTTPServer(("127.0.0.1", port), handler) as server:
        print(f"Playtest: http://localhost:{port}/", flush=True)
        print("Serving on this computer. Ctrl-C stops the server.", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


def port_number(value: str) -> int:
    number = int(value)
    if not 1 <= number <= 65535:
        raise argparse.ArgumentTypeError("must be from 1 to 65535")
    return number


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--godot", help=f"Godot {REQUIRED_VERSION} executable (default: GODOT, then PATH, then {MAC_APP})")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="export directory (default: godot/build/web)")
    parser.add_argument("--serve", action="store_true", help="serve the build at http://localhost:PORT/ afterwards")
    parser.add_argument("--port", type=port_number, default=8060, help="port for --serve (default: 8060)")
    parser.add_argument("--serve-only", action="store_true", help="serve the existing build without rebuilding")
    args = parser.parse_args(argv)
    output = args.output.resolve()
    if not args.serve_only:
        godot = find_godot(args.godot)
        check_version(godot)
        build(godot, output)
    if args.serve or args.serve_only:
        serve(output, args.port)
    return 0


if __name__ == "__main__":
    sys.exit(main())
