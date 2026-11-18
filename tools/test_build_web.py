import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import build_web


class BuildWebTest(unittest.TestCase):
    def test_version_must_match_export_templates(self):
        self.assertTrue(build_web.version_matches("4.7.2.stable.official.ed1daf0bf\n"))
        self.assertTrue(build_web.version_matches("4.7.2"))
        self.assertFalse(build_web.version_matches("4.1.1.stable.official.bd6af8e0e"))
        self.assertFalse(build_web.version_matches("4.7.20.stable"))
        self.assertFalse(build_web.version_matches(""))

    def test_windows_prefers_console_executable(self):
        with tempfile.TemporaryDirectory() as folder:
            windowed = Path(folder) / "Godot_v4.7.2-stable_win64.exe"
            console = Path(folder) / "Godot_v4.7.2-stable_win64_console.exe"
            windowed.touch()
            self.assertEqual(build_web.console_variant(windowed), windowed)
            console.touch()
            self.assertEqual(build_web.console_variant(windowed), console)
            self.assertEqual(build_web.console_variant(console), console)
        self.assertEqual(build_web.console_variant(Path("/usr/bin/godot")), Path("/usr/bin/godot"))

    def test_search_order_and_missing_godot(self):
        with tempfile.TemporaryDirectory() as folder:
            explicit = Path(folder) / "explicit"
            from_env = Path(folder) / "from_env"
            explicit.touch()
            from_env.touch()
            with mock.patch.dict(os.environ, {"GODOT": str(from_env)}), \
                    mock.patch.object(build_web.shutil, "which", lambda name: None):
                self.assertEqual(build_web.find_godot(str(explicit)), explicit.resolve())
                self.assertEqual(build_web.find_godot(None), from_env.resolve())
        with mock.patch.dict(os.environ, {"GODOT": ""}), \
                mock.patch.object(build_web.shutil, "which", lambda name: None), \
                mock.patch.object(build_web, "MAC_APP", "/nonexistent/Godot"):
            with self.assertRaises(SystemExit):
                build_web.find_godot(None)

    def test_port_range(self):
        self.assertEqual(build_web.port_number("8060"), 8060)
        for bad in ["0", "65536"]:
            with self.assertRaises(Exception):
                build_web.port_number(bad)


if __name__ == "__main__":
    unittest.main()
