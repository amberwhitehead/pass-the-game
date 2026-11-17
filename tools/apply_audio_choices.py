#!/usr/bin/env python3
"""Apply an exported audition list to the game's shared cue configuration."""
import argparse
import copy
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "godot/assets/audio"


def apply_choices(config, selection, manifest):
    if selection.get("version") != 1 or selection.get("kind") != "pass-the-game-audio-choices":
        raise ValueError("Expected a version 1 export from the audio audition page")
    choices = selection.get("cues")
    if not isinstance(choices, dict) or set(choices) != set(config["cues"]):
        raise ValueError("Export must contain exactly the current game's cue IDs")
    known = {asset["id"] for asset in manifest["assets"]}
    result = copy.deepcopy(config)
    for cue, choice in choices.items():
        if not isinstance(choice, dict):
            raise ValueError(f"{cue}: expected a sound choice object")
        files = choice.get("files")
        if (not isinstance(files, list) or not files or
                any(not isinstance(item, str) or item not in known for item in files)):
            raise ValueError(f"{cue}: choose files from the committed CC0 library")
        if len(set(files)) != len(files):
            raise ValueError(f"{cue}: duplicate variations are not allowed")
        if config["cues"][cue].get("loop") and len(files) != 1:
            raise ValueError(f"{cue}: ambience needs one looping clip")
        gain = choice.get("db")
        if (isinstance(gain, bool) or not isinstance(gain, (int, float)) or
                not math.isfinite(gain) or not -60 <= gain <= 6):
            raise ValueError(f"{cue}: gain must be between -60 and +6 dB")
        notes = choice.get("notes", "")
        if not isinstance(notes, str) or len(notes) > 2000:
            raise ValueError(f"{cue}: notes must be text up to 2000 characters")
        result["cues"][cue].update(files=files.copy(), db=float(gain))
        if notes.strip():
            result["cues"][cue]["review_notes"] = notes.strip()
        else:
            result["cues"][cue].pop("review_notes", None)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("choices", type=Path, help="JSON exported by the audition page")
    parser.add_argument("--dry-run", action="store_true", help="Validate without changing files")
    args = parser.parse_args()
    try:
        target = AUDIO / "cues.json"
        config = json.loads(target.read_text())
        selection = json.loads(args.choices.read_text())
        manifest = json.loads((AUDIO / "cc0_manifest.json").read_text())
        if not isinstance(selection, dict):
            raise ValueError("Expected a JSON object")
        result = apply_choices(config, selection, manifest)
        changes = sum(config["cues"][cue] != data for cue, data in result["cues"].items())
        if args.dry_run:
            print(f"Valid export: {len(result['cues'])} cues, {changes} changes; no files written.")
        else:
            temporary = target.with_suffix(".json.tmp")
            temporary.write_text(json.dumps(result, indent=2) + "\n")
            temporary.replace(target)
            print(f"Applied {changes} changes to {target}")
            print("Restart Godot or rebuild Web and refresh to hear the changes.")
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"Audio choices: {error}\n")


if __name__ == "__main__":
    main()
