#!/usr/bin/env python3
"""Run the real Godot rules headlessly and build a local balance laboratory."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

from card_sim_report import generate_report

ROOT = Path(__file__).resolve().parents[1]


def godot_path(explicit: str | None) -> str:
    candidates = [explicit, os.environ.get("GODOT"), shutil.which("godot"),
                  "/Applications/Godot.app/Contents/MacOS/Godot",
                  str(ROOT.parent / "work/godot-runtime/Godot.app/Contents/MacOS/Godot")]
    for candidate in candidates:
        if candidate:
            resolved = shutil.which(candidate) or candidate
            if Path(resolved).is_file() and os.access(resolved, os.X_OK):
                return str(Path(resolved).resolve())
    raise ValueError("Godot was not found. Set GODOT or pass --godot /path/to/Godot.")


def positive(value: str) -> int:
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def source_hashes() -> dict[str, str]:
    paths = sorted((ROOT / "godot/minigames/cards").glob("match_*.gd"))
    paths += [ROOT / "godot/minigames/cards" / name
              for name in ("card_catalog.gd", "deck_progression.gd")]
    paths += sorted((ROOT / "godot/simulation/cards").glob("*.gd"))
    paths += sorted((ROOT / "tools").glob("card_sim*"))
    paths += sorted((ROOT / "tools").glob("card_progression_report*"))
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in paths if path.is_file()}


def provenance(command: list[str], config: Path, config_bytes: bytes) -> dict:
    def git(*args: str) -> str:
        result = subprocess.run(["git", *args], cwd=ROOT, text=True,
                                capture_output=True, check=True)
        return result.stdout.strip()

    return {"created_utc": datetime.now(timezone.utc).isoformat(),
            "git_commit": git("rev-parse", "HEAD"),
            "git_dirty": bool(git("status", "--porcelain")),
            "source_sha256": source_hashes(),
            "config_sha256": hashlib.sha256(config_bytes).hexdigest(),
            "config_path": str(config), "command": shlex.join(command)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Godot executable; also honors GODOT")
    parser.add_argument("--config", type=Path, default=ROOT / "godot/simulation/cards/experiments.json")
    parser.add_argument("--output", type=Path, help="default: godot/build/web/balance")
    parser.add_argument("--seeds", type=positive, default=200, help="paired seeds per scenario/policy (default 200)")
    parser.add_argument("--seed-start", type=int, default=0)
    parser.add_argument("--policies", default="random,aggressive,defensive,tactical")
    parser.add_argument("--scenarios", help="comma-separated scenario IDs; default all")
    parser.add_argument("--max-turns", type=positive, default=60)
    parser.add_argument("--trace", help="replay one scenario:policy:seed with action/event snapshots")
    args = parser.parse_args()
    try:
        if args.trace:
            parts = args.trace.split(":")
            if len(parts) != 3 or not parts[0] or not parts[1]:
                raise ValueError("--trace must be scenario:policy:seed")
            args.scenarios, args.policies = parts[:2]
            args.seed_start, args.seeds = int(parts[2]), 1
        executable = godot_path(args.godot)
        config = args.config.resolve(strict=True)
        config_bytes = config.read_bytes()
        experiment_config = json.loads(config_bytes)
        output = (args.output or ROOT / "godot/build/web/balance" /
                  ("replay" if args.trace else "")).resolve()
        output.mkdir(parents=True, exist_ok=True)
        run_provenance = provenance([sys.executable, *sys.argv], config, config_bytes)
        # Never mistake an earlier successful report for the result of a failed run.
        with tempfile.TemporaryDirectory(prefix="card-sim-", dir=output) as scratch:
            raw = Path(scratch) / "results.json"
            frozen_config = Path(scratch) / "experiments.json"
            frozen_config.write_bytes(config_bytes)
            log = output / "godot.log"
            command = [executable, "--headless", "--audio-driver", "Dummy", "--path", str(ROOT / "godot"),
                       "--log-file", str(log), "--script", "res://simulation/cards/run.gd", "--",
                       "--config", str(frozen_config), "--output", str(raw), "--seeds", str(args.seeds),
                       "--seed-start", str(args.seed_start), "--policies", args.policies,
                       "--max-turns", str(args.max_turns)]
            if args.scenarios is not None:
                command.extend(["--scenarios", args.scenarios])
            if args.trace:
                command.extend(["--trace", args.trace])
            print("Running real card rules, headless and muted…", flush=True)
            completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=1800)
            transcript = completed.stdout + completed.stderr
            (output / "runner.log").write_text(transcript, encoding="utf-8")
            if completed.returncode or "SCRIPT ERROR:" in transcript or not raw.is_file():
                print(transcript[-12000:], file=sys.stderr)
                raise ValueError(f"Simulation failed; see {output / 'runner.log'}")
            data = json.loads(raw.read_text(encoding="utf-8"))
            if not data.get("matches"):
                raise ValueError("Simulation returned no matches; report was not replaced.")
            data.setdefault("metadata", {}).update(run_provenance)
            after_hashes = source_hashes()
            changed = sorted(path for path in set(after_hashes) | set(run_provenance["source_sha256"])
                             if after_hashes.get(path) != run_provenance["source_sha256"].get(path))
            data["metadata"]["source_changed_during_run"] = changed
            if changed:
                data["metadata"]["source_sha256_after_run"] = after_hashes
                print("Source changed during this run; recorded both versions. Rerun before treating it as a reproducible baseline.", file=sys.stderr)
            # Keep the full input: changing defaults later must not erase an experiment's meaning.
            data["experiment_config"] = experiment_config
            report = generate_report(data, output)
            print(transcript.strip())
            print(f"\nReport: {report}\nRaw data: {output / 'results.json'}")
            try:
                relative = report.relative_to(ROOT / "godot/build/web")
                print(f"Local URL (with the game server running): http://localhost:8060/{relative.as_posix()}")
            except ValueError:
                pass
        return 0
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f"card_sim: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
