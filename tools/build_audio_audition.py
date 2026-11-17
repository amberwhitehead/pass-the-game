#!/usr/bin/env python3
"""Build the local sound-choice page from the same cue data used by the game."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools/audio_audition"
AUDIO = ROOT / "godot/assets/audio"
PREFIX = "res://assets/audio/cc0/"


def build(output):
    manifest = json.loads((AUDIO / "cc0_manifest.json").read_text())
    cue_data = json.loads((AUDIO / "cues.json").read_text())
    if manifest.get("license") != "CC0-1.0":
        raise ValueError("The audition library must declare CC0-1.0")
    assets, copies, ids = [], [], set()
    for asset in manifest["assets"]:
        resource = asset["file"]
        if not resource.startswith(PREFIX):
            raise ValueError(f"Unexpected audio resource: {resource}")
        relative = PurePosixPath(resource[len(PREFIX):])
        if relative.is_absolute() or ".." in relative.parts or "\\" in str(relative):
            raise ValueError(f"Invalid audio resource: {resource}")
        source = AUDIO / "cc0" / str(relative)
        if not source.resolve().is_relative_to((AUDIO / "cc0").resolve()):
            raise ValueError(f"Audio resource leaves CC0 directory: {resource}")
        if source.suffix != ".ogg" or not source.is_file():
            raise ValueError(f"Missing Ogg clip: {source}")
        if asset["id"] in ids:
            raise ValueError(f"Duplicate audio ID: {asset['id']}")
        ids.add(asset["id"])
        if hashlib.sha256(source.read_bytes()).hexdigest() != asset["sha256"]:
            raise ValueError(f"Audio checksum mismatch: {asset['id']}")
        url = "clips/" + relative.as_posix()
        copies.append((source, output / url))
        assets.append({**asset, "url": url})
    if not assets or not cue_data.get("cues"):
        raise ValueError("Audio manifest and cue data must not be empty")
    for name, cue in cue_data["cues"].items():
        for selection in [cue, *cue.get("options", [])]:
            if not selection.get("files") or any(file not in ids for file in selection["files"]):
                raise ValueError(f"Unknown or empty clip selection for {name}")
    output.mkdir(parents=True, exist_ok=True)
    for source in SOURCES.iterdir():
        if source.suffix in {".html", ".css", ".js"}:
            shutil.copy2(source, output / source.name)
    for source, destination in copies:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    fonts = output / "fonts"
    fonts.mkdir(exist_ok=True)
    for source, name in [("LibreBaskerville.ttf", "LibreBaskerville-Regular.ttf"),
                         ("LibreBaskerville-LICENSE.txt", "LibreBaskerville-LICENSE.txt")]:
        shutil.copy2(ROOT / "godot/assets/fonts" / source, fonts / name)
    data = {"version": 1, "license": manifest["license"], "packs": manifest["packs"],
            "assets": assets, "cues": cue_data["cues"]}
    (output / "data.json").write_text(json.dumps(data, indent=2) + "\n")
    print(f"Audio audition: {len(cue_data['cues'])} targets, {len(assets)} clips -> {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "godot/build/web/audio")
    args = parser.parse_args()
    try:
        build(args.output.resolve())
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"Audio audition: {error}\n")


if __name__ == "__main__":
    main()
