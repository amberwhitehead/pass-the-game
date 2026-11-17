"""Workflow contracts: replay one match and preserve the experiment actually run."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import card_sim


class WorkflowTests(unittest.TestCase):
    def execute(self, extra=(), mutate_config=False, after_hashes=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "input.json"
            original = {"scenarios": [{"id": "test", "opponent": "older_brother", "overrides": {}}]}
            config.write_text(json.dumps(original), encoding="utf-8")
            captured = {}

            def run(command, **_kwargs):
                captured["command"] = command
                frozen = Path(command[command.index("--config") + 1])
                captured["frozen"] = json.loads(frozen.read_text(encoding="utf-8"))
                self.assertNotEqual(frozen, config)
                if mutate_config:
                    config.write_text('{"scenarios": []}', encoding="utf-8")
                output = Path(command[command.index("--output") + 1])
                output.write_text(json.dumps({"matches": [{"winner": "player"}], "metadata": {}}), encoding="utf-8")
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            def report(data, output):
                captured["data"] = data
                return output / "report.html"

            argv = ["card_sim.py", "--config", str(config), "--output", str(root / "output"), *extra]
            with patch("sys.argv", argv), patch.object(card_sim, "godot_path", return_value="fake-godot"), \
                    patch.object(card_sim, "provenance", return_value={"source_sha256": {"rules": "before"}}), \
                    patch.object(card_sim, "source_hashes", return_value=after_hashes or {"rules": "before"}), \
                    patch.object(card_sim.subprocess, "run", side_effect=run), \
                    patch.object(card_sim, "generate_report", side_effect=report), \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(card_sim.main(), 0)
            return captured, original

    def test_config_edit_during_run_cannot_change_archived_experiment(self):
        captured, original = self.execute(mutate_config=True)
        self.assertEqual(captured["frozen"], original)
        self.assertEqual(captured["data"]["experiment_config"], original)
        self.assertEqual(captured["data"]["metadata"]["source_changed_during_run"], [])

    def test_trace_selects_exactly_one_match(self):
        captured, _ = self.execute(["--trace", "test:tactical:17", "--seeds", "1000"])
        command = captured["command"]
        for flag, value in [("--scenarios", "test"), ("--policies", "tactical"),
                            ("--seed-start", "17"), ("--seeds", "1")]:
            self.assertEqual(command[command.index(flag) + 1], value)

    def test_source_edits_are_flagged_in_result_provenance(self):
        captured, _ = self.execute(after_hashes={"rules": "after"})
        self.assertEqual(captured["data"]["metadata"]["source_changed_during_run"], ["rules"])
        self.assertEqual(captured["data"]["metadata"]["source_sha256_after_run"], {"rules": "after"})


if __name__ == "__main__":
    unittest.main()
