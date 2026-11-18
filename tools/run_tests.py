#!/usr/bin/env python3
"""Run every automated check: the Godot test suites and the Python tool tests.

Godot suites run headless and muted, one at a time, after an import. Full logs go
to godot/build/test-logs/. Exits nonzero if anything fails.
"""
import argparse
import re
import subprocess
import sys
import time
from pathlib import Path

from build_web import PROJECT, find_godot, check_version

ROOT = Path(__file__).resolve().parents[1]
TESTS = PROJECT / "tests"
LOGS = PROJECT / "build/test-logs"
# Suites that need a real window and GPU; skipped unless --graphical is passed.
GRAPHICAL = {"cards_transition_render_test": "pixel comparison needs a graphical renderer"}
SUMMARY = re.compile(r"(\d+) checks?, (\d+) failures?", re.IGNORECASE)
TIMEOUT = 600


def suites(patterns: list[str]) -> list[str]:
    names = sorted(path.stem for path in TESTS.glob("*_test.gd"))
    return [name for name in names if not patterns or any(p in name for p in patterns)]


def run_suite(godot: Path, name: str, graphical: bool) -> dict:
    command = [str(godot), "--audio-driver", "Dummy", "--path", str(PROJECT), "--script", f"res://tests/{name}.gd"]
    if not graphical:
        command.insert(1, "--headless")
    started = time.monotonic()
    try:
        result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=TIMEOUT)
        output, code = result.stdout + result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        output, code = f"{error.stdout or ''}{error.stderr or ''}\nTimed out after {TIMEOUT}s", -1
    (LOGS / f"{name}.log").write_text(output, encoding="utf-8")
    counts = SUMMARY.findall(output)
    checks = int(counts[-1][0]) if counts else 0
    lines = output.splitlines()
    script_errors = [line.strip() for line in lines if line.startswith("SCRIPT ERROR:")]
    problems = script_errors + [line.strip() for line in lines
                                if line.startswith("ERROR:") and "resources still in use" not in line]
    # Godot exits normally after a script error, which silently skips the rest of the
    # suite, so a script error is a failure even when the suite reports none.
    passed = code == 0 and not script_errors
    return {"name": name, "passed": passed, "checks": checks, "seconds": time.monotonic() - started, "problems": problems}


def run_python() -> dict:
    started = time.monotonic()
    result = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tools", "-p", "test_*.py"],
                            cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    output = result.stdout + result.stderr
    (LOGS / "python_tools.log").write_text(output, encoding="utf-8")
    ran = re.search(r"Ran (\d+) tests?", output)
    problems = [line for line in output.splitlines() if line.startswith(("FAIL:", "ERROR:"))]
    return {"name": "python tools (unittest)", "passed": result.returncode == 0, "checks": int(ran.group(1)) if ran else 0,
            "seconds": time.monotonic() - started, "problems": problems}


def report(row: dict) -> None:
    mark = "PASS" if row["passed"] else "FAIL"
    print(f"  {mark}  {row['name']:<34} {row['checks']:>5} checks  {row['seconds']:5.1f}s", flush=True)
    if not row["passed"]:
        for line in row["problems"][:5] or ["(no error lines; see the log)"]:
            print(f"        {line}", flush=True)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("patterns", nargs="*", help="only run Godot suites whose names contain one of these")
    parser.add_argument("--godot", help="Godot 4.7.2 executable (default: GODOT, then PATH, then /Applications)")
    parser.add_argument("--no-import", action="store_true", help="skip the import step (faster when nothing changed)")
    parser.add_argument("--no-python", action="store_true", help="skip the Python tool tests")
    parser.add_argument("--graphical", action="store_true", help="also run window-only suites (opens a Godot window)")
    args = parser.parse_args(argv)

    godot = find_godot(args.godot)
    check_version(godot)
    LOGS.mkdir(parents=True, exist_ok=True)
    (PROJECT / "build/.gdignore").touch()
    if not args.no_import:
        print(f"Importing with {godot}", flush=True)
        subprocess.run([str(godot), "--headless", "--audio-driver", "Dummy", "--path", str(PROJECT), "--import"],
                       check=True, capture_output=True)
    rows, skipped = [], []
    print("Godot suites:", flush=True)
    for name in suites(args.patterns):
        if name in GRAPHICAL and not args.graphical:
            skipped.append(name)
            print(f"  SKIP  {name:<34} {GRAPHICAL[name]} (--graphical runs it)", flush=True)
            continue
        rows.append(run_suite(godot, name, name in GRAPHICAL))
        report(rows[-1])
    if not args.no_python and not args.patterns:
        print("Python:", flush=True)
        rows.append(run_python())
        report(rows[-1])

    failed = [row["name"] for row in rows if not row["passed"]]
    checks = sum(row["checks"] for row in rows)
    print(f"\n{len(rows) - len(failed)} passed, {len(failed)} failed, {len(skipped)} skipped; "
          f"{checks} checks. Logs: {LOGS}", flush=True)
    if failed:
        print("Failed: " + ", ".join(failed), flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
