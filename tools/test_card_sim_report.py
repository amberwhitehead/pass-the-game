"""Statistical and report-integrity checks, using small auditable fixtures."""
import json
import tempfile
import unittest
from pathlib import Path

from card_sim_report import aggregate, build_summary, generate_report, paired_comparison, wilson


def match(seed=0, winner="player", scenario="base", policy="tactical", turns=5):
    return {"scenario": scenario, "policy": policy, "seed": seed, "winner": winner,
            "turns": turns, "final_balance": 12 if winner == "player" else -12, "goal": 12,
            "counters": {"attention_available": 20, "attention_unused": 5},
            "cards": {"bruiser": {"drawn": 2, "played": 1, "legal_turns": 3, "held_turns": 5}},
            "units": [{"side": "player", "death_turn": 3, "turns_in_play": 3, "hits_taken": 2},
                      {"side": "player", "death_turn": -1, "turns_in_play": 4, "hits_taken": 1}],
            "timeline": [{"turn": i + 1, "balance_after": i} for i in range(turns)]}


class ReportTests(unittest.TestCase):
    def test_wilson_boundary_has_nonzero_uncertainty(self):
        low, high = wilson(100, 100)
        self.assertAlmostEqual(low, .9630065018)
        self.assertAlmostEqual(high, 1)
        low, high = wilson(0, 100)
        self.assertAlmostEqual(low, 0)
        self.assertAlmostEqual(high, .0369934982)
        self.assertIsNone(wilson(0, 0))

    def test_timeouts_are_explicit_not_losses_or_finished_pacing(self):
        result = aggregate([match(), match(1, "enemy", turns=9), match(2, "timeout", turns=60)])
        self.assertEqual((result["wins"], result["losses"], result["timeouts"]), (1, 1, 1))
        self.assertEqual(result["win_rate"], .5)
        self.assertEqual(result["rounds"]["median"], 7)
        self.assertEqual(result["cards"]["bruiser"]["drawn"], 6)
        self.assertEqual(result["cards"]["bruiser"]["games_seen"], 3)

    def test_survivors_do_not_masquerade_as_completed_lifetimes(self):
        result = aggregate([match()])["durability"]
        self.assertEqual(result["deaths"], 1)
        self.assertEqual(result["survivors_censored"], 1)
        self.assertEqual(result["dead_turns_median"], 3)
        self.assertEqual(result["survivor_age_median"], 4)
        self.assertEqual(result["distributions"]["dead_hits"], {2: 1})

    def test_pairing_uses_seed_and_policy_and_excludes_unresolved(self):
        baseline = [match(0, "enemy"), match(1), match(2), match(9, "enemy", policy="random")]
        variant = [match(1, "enemy", "variant"), match(0, "player", "variant"),
                   match(2, "timeout", "variant"), match(9, "player", "variant")]
        result = paired_comparison(variant, baseline)
        self.assertEqual(result["pairs"], 2)
        self.assertEqual(result["unresolved_pairs"], 1)
        self.assertEqual(result["gained_wins"], 1)
        self.assertEqual(result["lost_wins"], 1)
        self.assertEqual(result["win_delta"], 0)
        self.assertEqual(result, paired_comparison(variant, baseline))

    def test_duplicate_matches_rejected(self):
        data = {"config": {"scenarios": [{"id": "base"}]}, "matches": [match(), match()]}
        with self.assertRaisesRegex(ValueError, "Duplicate match"):
            build_summary(data)

    def test_report_preserves_config_and_safely_embeds_data(self):
        data = {"metadata": {}, "config": {"scenarios": [{"id": "base", "label": "</script><img src=x>", "opponent": "older_brother"}]},
                "experiment_config": {"scenarios": [{"id": "saved"}]}, "matches": [match()]}
        with tempfile.TemporaryDirectory() as folder:
            path = generate_report(data, Path(folder))
            html = path.read_text(encoding="utf-8")
            self.assertNotIn("</script><img src=x>", html)
            self.assertIn(r"\u003c/script>", html)
            self.assertNotIn("__SIMULATION_DATA__", html)
            saved = json.loads((Path(folder) / "experiments.json").read_text(encoding="utf-8"))
            self.assertEqual(saved, data["experiment_config"])
            raw = json.loads((Path(folder) / "results.json").read_text(encoding="utf-8"))
            self.assertEqual(raw, data)
            for name in ("summary.json", "matches.csv", "cards.csv"):
                self.assertTrue((Path(folder) / name).is_file())


if __name__ == "__main__":
    unittest.main()
