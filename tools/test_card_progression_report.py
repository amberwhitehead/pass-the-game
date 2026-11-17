import itertools
import json
from pathlib import Path
import tempfile
import unittest

from card_progression_report import COLLECTIBLES, found_cards, generate_report, summarize


def study(seeds=4):
    scenarios, matches = [], []
    for count in range(6):
        for cards in itertools.combinations(COLLECTIBLES, count):
            id = "found_" + str(len(scenarios))
            scenarios.append({"id": id, "opponent": "older_brother", "overrides": {"collected_cards": list(cards)}})
            for seed in range(seeds):
                matches.append({"scenario": id, "policy": "test", "seed": seed,
                                "winner": "player" if count > seed else "enemy", "turns": 8})
    return {"config": {"scenarios": scenarios}, "matches": matches, "metadata": {}}


class ProgressionReportTests(unittest.TestCase):
    def test_full_cube_has_all_counts_and_eighty_marginal_edges(self):
        result = summarize(study())
        self.assertEqual([g["subsets"] for g in result["groups"]], [1,5,10,10,5,1])
        self.assertEqual(len(result["edges"]), 80)
        self.assertTrue(all(g["complete"] for g in result["groups"]))
        self.assertEqual([g["win_rate"] for g in result["groups"]], [0,.25,.5,.75,1,1])
        self.assertEqual(result["edge_totals"][0]["lost"], 0)

    def test_seed_cluster_interval_does_not_invent_independent_replicates(self):
        data = study()
        # At each count every card set has the exact same seed outcomes.
        for match in data["matches"]:
            match["winner"] = "player" if match["seed"] % 2 else "enemy"
        rows = summarize(data)["groups"]
        self.assertEqual(rows[0]["interval"], rows[2]["interval"])
        self.assertEqual(rows[2]["paired_seeds"], 4)
        self.assertEqual(rows[2]["matches"], 40)

    def test_timeout_is_excluded_not_counted_as_a_loss(self):
        data = study()
        data["matches"][0]["winner"] = "timeout"
        result = summarize(data)
        base = result["groups"][0]
        self.assertEqual(base["timeouts"], 1)
        self.assertEqual(base["paired_seeds"], 3)
        self.assertEqual(base["excluded_seeds"], 1)
        self.assertTrue(all(e["pairs"] == 3 for e in result["edges"] if e["from_cards"] == []))

    def test_regression_is_visible_on_the_actual_added_card(self):
        data = study()
        last = data["config"]["scenarios"][-1]["id"]
        for match in data["matches"]:
            if match["scenario"] == last:
                match["winner"] = "enemy"
        result = summarize(data)
        negative = [e for e in result["edges"] if e["delta"] < 0]
        self.assertEqual(len(negative), 5)
        self.assertTrue(all(e["lost"] == 4 and e["delta"] == -1 for e in negative))
        self.assertEqual({e["added"] for e in negative}, set(COLLECTIBLES))

    def test_missing_baseline_remains_visible_as_missing(self):
        data = study()
        data["matches"] = [m for m in data["matches"] if m["scenario"] != "found_0"]
        base = summarize(data)["groups"][0]
        self.assertEqual(base["count"], 0)
        self.assertFalse(base["complete"])
        self.assertIsNone(base["win_rate"])

    def test_resolved_collection_takes_priority_over_deck_inference(self):
        data = study()
        scenario = data["config"]["scenarios"][0]
        data["resolved_scenarios"] = {scenario["id"]: {"settings": {"collected_cards": ["aegis"], "deck": ["champion"]}}}
        self.assertEqual(found_cards(data, scenario), ("aegis",))

    def test_cannot_pool_different_opponent_tuning(self):
        data = study()
        data["config"]["scenarios"][1]["overrides"]["goal"] = 18
        with self.assertRaisesRegex(ValueError, "constant opponent"):
            summarize(data)

    def test_outputs_are_self_contained_and_include_baseline(self):
        with tempfile.TemporaryDirectory() as directory:
            output = generate_report(study(), Path(directory))
            html = output.read_text()
            self.assertIn("<svg", html)
            self.assertIn("Base deck", html)
            self.assertNotIn("__GROUPS__", html)
            summary = json.loads((Path(directory) / "progression-summary.json").read_text())
            self.assertEqual(len(summary["groups"]), 6)


if __name__ == "__main__":
    unittest.main()
