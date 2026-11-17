"""The handoff list must not corrupt cue timing or introduce external assets."""
import copy
import unittest

from apply_audio_choices import apply_choices


class AudioChoicesTests(unittest.TestCase):
    def setUp(self):
        self.config = {"version": 1, "cues": {
            "draw": {"files": ["a", "b"], "db": -8, "pitch": .05, "gap": 45,
                     "options": [{"label": "A pair", "files": ["a", "b"]}]},
            "ambience": {"files": ["c"], "db": -22, "loop": True, "pitch": 0, "gap": 0},
        }}
        self.manifest = {"assets": [{"id": name} for name in "abc"]}
        self.export = {"version": 1, "kind": "pass-the-game-audio-choices", "cues": {
            "draw": {"files": ["b", "a"], "db": -10, "notes": " Softer pair "},
            "ambience": {"files": ["c"], "db": -25, "notes": ""},
        }}

    def test_apply_preserves_variations_timing_and_source(self):
        before = copy.deepcopy(self.config)
        result = apply_choices(self.config, self.export, self.manifest)
        self.assertEqual(self.config, before)
        self.assertEqual(result["cues"]["draw"]["files"], ["b", "a"])
        self.assertEqual(result["cues"]["draw"]["db"], -10)
        self.assertEqual(result["cues"]["draw"]["review_notes"], "Softer pair")
        for key in ["pitch", "gap", "options"]:
            self.assertEqual(result["cues"]["draw"][key], before["cues"]["draw"][key])

    def test_bad_asset_and_variation_sets(self):
        for files in [[], ["../elsewhere"], ["https://example.com/sound.ogg"], ["a", "a"], [3]]:
            with self.subTest(files=files):
                self.export["cues"]["draw"]["files"] = files
                with self.assertRaises(ValueError):
                    apply_choices(self.config, self.export, self.manifest)

    def test_unchanged_export_does_not_add_empty_notes(self):
        for cue, data in self.config["cues"].items():
            self.export["cues"][cue] = {"files": data["files"], "db": data["db"], "notes": ""}
        self.assertEqual(apply_choices(self.config, self.export, self.manifest), self.config)

    def test_nonfinite_or_excessive_gain(self):
        for gain in [float("nan"), float("inf"), -61, 7, True, "-10"]:
            with self.subTest(gain=gain):
                self.export["cues"]["draw"]["db"] = gain
                with self.assertRaises(ValueError):
                    apply_choices(self.config, self.export, self.manifest)

    def test_stale_or_unrelated_export(self):
        for field, value in [("version", 2), ("kind", "other"), ("cues", {})]:
            with self.subTest(field=field):
                data = copy.deepcopy(self.export)
                data[field] = value
                with self.assertRaises(ValueError):
                    apply_choices(self.config, data, self.manifest)

    def test_ambience_has_one_clip(self):
        self.export["cues"]["ambience"]["files"] = ["a", "b"]
        with self.assertRaises(ValueError):
            apply_choices(self.config, self.export, self.manifest)

    def test_overlong_notes_rejected(self):
        self.export["cues"]["draw"]["notes"] = "x" * 2001
        with self.assertRaises(ValueError):
            apply_choices(self.config, self.export, self.manifest)


if __name__ == "__main__":
    unittest.main()
