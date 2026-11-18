#!/usr/bin/env python3
"""Run every automated check: the Godot test suites and the Python tool tests.

Godot suites run headless and muted, all in one Godot process (tests/run_suites.gd) so
Godot starts once. A suite that hits a script error or stops responding fails at once;
the process is killed and the remaining suites continue in a fresh one. Full logs go to
godot/build/test-logs/. Exits nonzero if anything fails.
"""
import argparse
import os
import queue
import random
import re
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

from build_web import PROJECT, find_godot, check_version

ROOT = Path(__file__).resolve().parents[1]
TESTS = PROJECT / "tests"
LOGS = PROJECT / "build/test-logs"
HOST = "res://tests/run_suites.gd"
# Suites that need a real window and GPU; skipped unless --graphical is passed.
GRAPHICAL = {"cards_transition_render_test": "pixel comparison needs a graphical renderer"}
# Pure logic suites that load no scenes: what --quick runs.
QUICK = {"cards_test", "older_rules_test", "card_progression_test", "card_face_test", "optics_model_test",
         "sim_config_test", "sim_policies_test", "sim_runner_test", "sim_blindspots_test"}
SUMMARY = re.compile(r"(\d+) checks?, (\d+) failures?", re.IGNORECASE)
TIMEOUT = 20  # Seconds a suite may run; the slowest takes about 4.
STARTUP = 15  # Seconds for Godot to start, compile everything and begin the first suite.


def suites(patterns: list[str], quick: bool) -> list[str]:
    names = sorted(path.stem for path in TESTS.glob("*_test.gd"))
    if quick:
        names = [name for name in names if name in QUICK]
    return [name for name in names if not patterns or any(p in name for p in patterns)]


def kill_tree(process: subprocess.Popen) -> None:
    """On Windows, Godot's _console.exe is a wrapper whose real Godot child keeps running
    if only the wrapper is killed, so kill the whole process tree."""
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(process.pid)], capture_output=True)
    else:
        os.killpg(process.pid, signal.SIGKILL)
    process.wait()


def start(command: list[str]) -> tuple[subprocess.Popen, queue.Queue]:
    """Starts a command and returns it with a queue of its output lines (None at the end)."""
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                               encoding="utf-8", errors="replace", start_new_session=os.name != "nt")
    lines: queue.Queue = queue.Queue()

    def pump():
        for line in process.stdout:
            lines.put(line.rstrip("\r\n"))
        lines.put(None)

    threading.Thread(target=pump, daemon=True).start()
    return process, lines


def result(name: str, lines: list[str], code: int, seconds: float, note: str = "") -> dict:
    output = "\n".join(lines) + (f"\n{note}" if note else "") + "\n"
    (LOGS / f"{name}.log").write_text(output, encoding="utf-8")
    counts = SUMMARY.findall(output)
    script_errors = [line.strip() for line in lines if line.startswith("SCRIPT ERROR:")]
    problems = ([note] if note else []) + script_errors + [
        line.strip() for line in lines if line.startswith("ERROR:") and "resources still in use" not in line]
    # Godot carries on after a script error, silently skipping the rest of the suite, so a
    # script error is a failure even when the suite itself reports none.
    return {"name": name, "passed": code == 0 and not script_errors and not note,
            "checks": int(counts[-1][0]) if counts else 0, "seconds": seconds, "problems": problems}


def compile_report(preamble: list[str]) -> list[str]:
    """Prints each compile error with its location, from the host's compile pass."""
    failed = [line.split(" ", 1)[1] for line in preamble if line.startswith("@@compile_failed ")]
    if not failed and any(line.startswith("SCRIPT ERROR:") for line in preamble):
        failed = ["the test host (tests/run_suites.gd or tests/test_suite.gd)"]  # It could not start.
    if not failed:
        return []
    print(f"  COMPILE ERROR in {len(failed)} script(s); no suites were run:", flush=True)
    for index, line in enumerate(preamble):
        if line.startswith("SCRIPT ERROR:"):
            where = next((later.strip() for later in preamble[index + 1:index + 3] if later.strip().startswith("at:")), "")
            print(f"        {line.strip()}\n          {where}", flush=True)
    for path in failed:
        print(f"        failed to load {path}", flush=True)
    (LOGS / "compile.log").write_text("\n".join(preamble) + "\n", encoding="utf-8")
    return failed


def run_godot(godot: Path, names: list[str], graphical: bool, timeout: float, report) -> list[dict]:
    """Runs suites in as few Godot processes as possible, reporting each as it finishes."""
    rows, remaining = [], list(names)
    while remaining:
        command = [str(godot), "--audio-driver", "Dummy", "--path", str(PROJECT), "--script", HOST, "--", *remaining]
        if not graphical:
            command.insert(1, "--headless")
        process, output = start(command)
        current, lines, preamble, progress = None, [], [], False
        began = time.monotonic()
        while True:
            try:
                line = output.get(timeout=0.25)
            except queue.Empty:
                line = ""
            limit = timeout if current else STARTUP
            if line is None or time.monotonic() - began > limit:
                kill_tree(process)
                if current:  # Crashed or stopped responding mid-suite; the rest restart.
                    note = f"TIMEOUT: stopped after {timeout:g}s" if line is not None else "CRASH: Godot exited mid-suite"
                    rows.append(report(result(current, lines, 1, time.monotonic() - began, note)))
                    remaining.remove(current)
                elif not progress:
                    # This process never finished a suite (a compile error, say): retrying won't help.
                    if compile_report(preamble):
                        rows.append({"name": "compile check", "passed": False, "checks": 0,
                                     "seconds": time.monotonic() - began, "problems": []})
                    else:
                        for name in remaining:
                            rows.append(report(result(name, preamble, 1, 0, "Godot did not run the suite; see the log")))
                    remaining = []
                break
            if not line:
                continue
            if line.startswith("@@begin "):
                current, lines, began = line.split(" ", 1)[1].strip(), [], time.monotonic()
            elif line.startswith("@@end ") and current:
                code = int(line.rsplit(" ", 1)[1])
                rows.append(report(result(current, lines, code, time.monotonic() - began)))
                remaining.remove(current)
                current, progress, began = None, True, time.monotonic()
            elif line.startswith("@@done"):
                kill_tree(process)
                break
            elif current:
                lines.append(line)
                if line.startswith("SCRIPT ERROR:"):  # Fail now rather than wait for a timeout.
                    kill_tree(process)
                    rows.append(report(result(current, lines, 1, time.monotonic() - began)))
                    remaining.remove(current)
                    break
            else:
                preamble.append(line)
    return rows


def run_python() -> dict:
    started = time.monotonic()
    completed = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tools", "-p", "test_*.py"],
                               cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    output = completed.stdout + completed.stderr
    (LOGS / "python_tools.log").write_text(output, encoding="utf-8")
    ran = re.search(r"Ran (\d+) tests?", output)
    problems = [line for line in output.splitlines() if line.startswith(("FAIL:", "ERROR:"))]
    return {"name": "python tools (unittest)", "passed": completed.returncode == 0,
            "checks": int(ran.group(1)) if ran else 0, "seconds": time.monotonic() - started, "problems": problems}


def report(row: dict) -> dict:
    mark = "PASS" if row["passed"] else "FAIL"
    print(f"  {mark}  {row['name']:<34} {row['checks']:>5} checks  {row['seconds']:5.1f}s", flush=True)
    if not row["passed"]:
        for line in row["problems"][:5] or ["(no error lines; see the log)"]:
            print(f"        {line}", flush=True)
    return row


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("patterns", nargs="*", help="only run Godot suites whose names contain one of these")
    parser.add_argument("--quick", action="store_true", help="only the logic suites that load no scenes (about 2s)")
    parser.add_argument("--godot", help="Godot 4.7.2 executable (default: GODOT, then PATH, then /Applications)")
    parser.add_argument("--no-import", action="store_true", help="skip the import step (faster when nothing changed)")
    parser.add_argument("--no-python", action="store_true", help="skip the Python tool tests")
    parser.add_argument("--graphical", action="store_true", help="also run window-only suites (opens a Godot window)")
    parser.add_argument("--isolated", action="store_true", help="run each suite in its own Godot process (slower)")
    parser.add_argument("--shuffle", type=int, metavar="SEED", help="run suites in a random order, to check isolation")
    parser.add_argument("--timeout", type=float, default=TIMEOUT,
                        help=f"seconds before a suite is stopped and its Godot processes killed (default: {TIMEOUT})")
    args = parser.parse_args(argv)

    godot = find_godot(args.godot)
    check_version(godot)
    LOGS.mkdir(parents=True, exist_ok=True)
    (PROJECT / "build/.gdignore").touch()
    started = time.monotonic()
    if not args.no_import:
        print(f"Importing with {godot}", flush=True)
        process, output = start([str(godot), "--headless", "--audio-driver", "Dummy", "--path", str(PROJECT), "--import"])
        try:
            process.wait(timeout=120)
        except subprocess.TimeoutExpired:
            kill_tree(process)
        if process.returncode != 0:
            print("Import failed or timed out; run it in the editor to see why.", flush=True)
            return 1

    names = suites(args.patterns, args.quick)
    if args.shuffle is not None:
        random.Random(args.shuffle).shuffle(names)
    skipped = [name for name in names if name in GRAPHICAL and not args.graphical]
    headless = [name for name in names if name not in GRAPHICAL]
    print("Godot suites:", flush=True)
    for name in skipped:
        print(f"  SKIP  {name:<34} {GRAPHICAL[name]} (--graphical runs it)", flush=True)
    rows = []
    for batch in ([[name] for name in headless] if args.isolated else [headless] if headless else []):
        rows += run_godot(godot, batch, False, args.timeout, report)
    for name in names:
        if name in GRAPHICAL and args.graphical:
            rows += run_godot(godot, [name], True, args.timeout, report)
    if not args.no_python and not args.patterns and not args.quick:
        print("Python:", flush=True)
        rows.append(report(run_python()))

    failed = [row["name"] for row in rows if not row["passed"]]
    checks = sum(row["checks"] for row in rows)
    print(f"\n{len(rows) - len(failed)} passed, {len(failed)} failed, {len(skipped)} skipped; "
          f"{checks} checks in {time.monotonic() - started:.1f}s. Logs: {LOGS}", flush=True)
    if failed:
        print("Failed: " + ", ".join(failed), flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
