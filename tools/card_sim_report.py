#!/usr/bin/env python3
"""Summarize real-rules simulation output without third-party dependencies."""
from __future__ import annotations

import argparse
import csv
import json
import math
import random
import statistics
from collections import Counter, defaultdict
from pathlib import Path


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = (len(ordered) - 1) * fraction
    low = math.floor(index)
    high = math.ceil(index)
    return ordered[low] + (ordered[high] - ordered[low]) * (index - low)


def wilson(wins: int, count: int) -> list[float] | None:
    """Two-sided 95% Wilson score interval, including boundary cases."""
    if not count:
        return None
    z = 1.959963984540054
    p = wins / count
    denominator = 1 + z * z / count
    center = (p + z * z / (2 * count)) / denominator
    radius = z * math.sqrt(p * (1 - p) / count + z * z / (4 * count * count)) / denominator
    return [max(0.0, center - radius), min(1.0, center + radius)]


def mean(values: list[float]) -> float | None:
    return statistics.fmean(values) if values else None


def aggregate(matches: list[dict]) -> dict:
    outcomes = Counter(m["winner"] for m in matches)
    resolved = [m for m in matches if m["winner"] != "timeout"]
    rounds = [m["turns"] for m in resolved]
    counters = Counter()
    cards: dict[str, Counter] = defaultdict(Counter)
    units = []
    for match in matches:
        counters.update(match.get("counters", {}))
        for card_id, values in match.get("cards", {}).items():
            cards[card_id].update(values)
            cards[card_id]["games_seen"] += int(values.get("drawn", 0) > 0)
            cards[card_id]["games_played"] += int(values.get("played", 0) > 0)
        units.extend(match.get("units", []))
    player_units = [unit for unit in units if unit["side"] == "player"]
    dead = [unit for unit in player_units if unit["death_turn"] >= 0]
    alive = [unit for unit in player_units if unit["death_turn"] < 0]
    turn_count = sum(len(m.get("timeline", [])) for m in matches)
    return {
        "matches": len(matches), "wins": outcomes["player"], "losses": outcomes["enemy"],
        "timeouts": outcomes["timeout"], "resolved": len(resolved),
        "win_rate": outcomes["player"] / len(resolved) if resolved else None,
        "win_interval": wilson(outcomes["player"], len(resolved)),
        "rounds": {"median": percentile(rounds, .5), "p10": percentile(rounds, .1),
                   "p90": percentile(rounds, .9)},
        "turn_count": turn_count, "counters": dict(counters),
        "unused_attention_fraction": counters["attention_unused"] / counters["attention_available"]
        if counters["attention_available"] else None,
        "no_legal_fraction": counters["turns_no_legal_actions"] / turn_count if turn_count else None,
        "full_board_fraction": counters["full_board_turns"] / turn_count if turn_count else None,
        "cards": {key: dict(value) for key, value in sorted(cards.items())},
        "durability": {
            "deaths": len(dead), "survivors_censored": len(alive),
            "dead_turns_median": percentile([u["turns_in_play"] for u in dead], .5),
            "dead_hits_median": percentile([u["hits_taken"] for u in dead], .5),
            "survivor_age_median": percentile([u["turns_in_play"] for u in alive], .5),
            "distributions": {
                "dead_turns": dict(Counter(u["turns_in_play"] for u in dead)),
                "dead_hits": dict(Counter(u["hits_taken"] for u in dead)),
                "survivor_ages": dict(Counter(u["turns_in_play"] for u in alive)),
            },
        },
    }


def paired_comparison(variant: list[dict], baseline: list[dict]) -> dict:
    """Compare the same policy and seed. Unresolved matches are never losses."""
    lookup = {(m["policy"], m["seed"]): m for m in baseline}
    differences = []
    round_differences = []
    gains = losses = unresolved = 0
    for match in variant:
        reference = lookup.get((match["policy"], match["seed"]))
        if reference is None:
            continue
        if "timeout" in (match["winner"], reference["winner"]):
            unresolved += 1
            continue
        difference = int(match["winner"] == "player") - int(reference["winner"] == "player")
        differences.append(difference)
        gains += difference > 0
        losses += difference < 0
        round_differences.append(match["turns"] - reference["turns"])
    # A fixed RNG makes report generation reproducible without consuming match RNG.
    rng = random.Random(1977)
    bootstrap = [sum(rng.choices(differences, k=len(differences))) / len(differences)
                 for _ in range(2000)] if differences else []
    return {
        "pairs": len(differences), "unresolved_pairs": unresolved,
        "win_delta": mean(differences), "win_delta_interval":
        [percentile(bootstrap, .025), percentile(bootstrap, .975)] if bootstrap else None,
        "gained_wins": gains, "lost_wins": losses,
        "mean_round_delta": mean(round_differences),
    }


def build_summary(data: dict) -> dict:
    scenarios = {s["id"]: s for s in data["config"]["scenarios"]}
    grouped: dict[tuple[str, str], list[dict]] = defaultdict(list)
    identities = set()
    for match in data["matches"]:
        identity = (match["scenario"], match["policy"], match["seed"])
        if identity in identities:
            raise ValueError(f"Duplicate match identity: {identity}")
        if match["scenario"] not in scenarios:
            raise ValueError(f"Unknown scenario: {match['scenario']}")
        if match["winner"] not in ("player", "enemy", "timeout"):
            raise ValueError(f"Unknown match result: {match['winner']}")
        identities.add(identity)
        grouped[(match["scenario"], match["policy"])].append(match)
    groups = []
    flags = []
    for (scenario_id, policy), matches in sorted(grouped.items()):
        scenario = scenarios[scenario_id]
        result = {"scenario": scenario_id, "policy": policy, **aggregate(matches)}
        baseline = scenario.get("baseline")
        if baseline and baseline != scenario_id:
            result["paired"] = {"baseline": baseline, **paired_comparison(
                matches, grouped.get((baseline, policy), []))}
        groups.append(result)
        prefix = {"scenario": scenario_id, "policy": policy}
        if result["timeouts"]:
            flags.append({**prefix, "level": "warn", "title": "Unresolved matches",
                          "body": f"{result['timeouts']} matches reached the turn cap. They are excluded from resolved win rates and pacing; inspect them before treating this condition as balanced."})
        if result["resolved"] >= 20 and result["win_rate"] >= .95 and policy not in ("passive", "pass"):
            flags.append({**prefix, "level": "signal", "title": "Difficulty ceiling",
                          "body": f"This policy won {result['wins']}/{result['resolved']} resolved matches. A stronger opponent or a weaker starter deck may create more room for decisions; this is a bot result, not a human win-rate estimate."})
        if (result["unused_attention_fraction"] or 0) >= .4:
            flags.append({**prefix, "level": "signal", "title": "Attention often goes unspent",
                          "body": "At least 40% of available Attention is unused. Check draw supply, occupied lanes and card targets before increasing the resource cap. A policy may also deliberately hold cards."})
        if (result["full_board_fraction"] or 0) >= .5:
            flags.append({**prefix, "level": "signal", "title": "Crowded board",
                          "body": "The player starts planning with all lanes occupied on at least half of turns. Durable creatures may reduce opportunities to play new units; inspect hand congestion and movement options."})
        if (result["no_legal_fraction"] or 0) >= .25:
            flags.append({**prefix, "level": "signal", "title": "Turns without a legal play",
                          "body": "At least a quarter of turns offer no legal card action. This can signal a resource, target or board-space bottleneck; it is different from choosing to pass."})
    return {"schema_version": 1, "metadata": data.get("metadata", {}),
            "scenarios": list(scenarios.values()), "groups": groups, "flags": flags}


def write_csv_files(data: dict, summary: dict, output_dir: Path) -> None:
    counter_names = sorted({key for match in data["matches"] for key in match.get("counters", {})})
    fields = ["scenario", "policy", "seed", "winner", "turns", "final_balance", "goal"]
    with (output_dir / "matches.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields + counter_names)
        writer.writeheader()
        for match in data["matches"]:
            writer.writerow({**{field: match.get(field, "") for field in fields}, **match.get("counters", {})})
    card_fields = ["scenario", "policy", "card", "matches", "drawn", "played", "legal_turns",
                   "held_turns", "burned", "games_seen", "games_played"]
    with (output_dir / "cards.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=card_fields, extrasaction="ignore")
        writer.writeheader()
        for group in summary["groups"]:
            for card, values in group["cards"].items():
                writer.writerow({"scenario": group["scenario"], "policy": group["policy"],
                                 "card": card, "matches": group["matches"], **values})


def generate_report(data: dict, output_dir: Path) -> Path:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    summary = build_summary(data)
    # Store the exact configuration beside the report, rather than relying on a
    # source file whose contents might change before someone follows a replay.
    saved_config = output_dir.resolve() / "experiments.json"
    saved_config.write_text(json.dumps(data.get("experiment_config", data["config"]), indent=2) + "\n", encoding="utf-8")
    summary["replay_config_path"] = str(saved_config)
    (output_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    (output_dir / "results.json").write_text(json.dumps(data, separators=(",", ":")) + "\n", encoding="utf-8")
    write_csv_files(data, summary, output_dir)
    # Keep HTML practical for tens of thousands of matches. Full telemetry and
    # traces remain in results.json; the explorer needs only this compact view.
    scenario_ids = [s["id"] for s in summary["scenarios"]]
    policy_ids = sorted({m["policy"] for m in data["matches"]})
    matches = []
    for match in data["matches"]:
        timeline = [[t.get(key, 0) for key in ("turn", "balance_after", "plays",
                    "attention_available", "attention_unused", "player_occupied", "enemy_occupied")]
                    for t in match.get("timeline", [])]
        matches.append([scenario_ids.index(match["scenario"]), policy_ids.index(match["policy"]),
                        match["seed"], ("player", "enemy", "timeout").index(match["winner"]),
                        match["turns"], match["final_balance"], match["goal"],
                        match.get("counters", {}).get("actions", 0),
                        match.get("counters", {}).get("swaps", 0), timeline])
    embedded = {"summary": summary, "scenario_ids": scenario_ids,
                "policy_ids": policy_ids, "match_rows": matches}
    payload = json.dumps(embedded, separators=(",", ":")).replace("<", "\\u003c").replace("&", "\\u0026")
    template = Path(__file__).with_suffix(".html").read_text(encoding="utf-8")
    destination = output_dir / "report.html"
    destination.write_text(template.replace("__SIMULATION_DATA__", payload), encoding="utf-8")
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    data = json.loads(args.results.read_text(encoding="utf-8"))
    print(generate_report(data, args.output or args.results.parent))


if __name__ == "__main__":
    main()
