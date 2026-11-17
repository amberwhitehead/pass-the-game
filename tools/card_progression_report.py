#!/usr/bin/env python3
"""Summarize a full five-card subset study, preserving paired seed dependence."""
from __future__ import annotations

import argparse
from collections import defaultdict
from html import escape
import json
import math
from pathlib import Path
import random
import statistics

from card_sim_report import percentile, wilson

COLLECTIBLES = ("champion", "aegis", "tempest", "renewal", "thunderbolt")
COLORS = ("#d9b77a", "#8bd2b1", "#8ebae7", "#dc9fc2", "#ef9e89")


def bootstrap(values: list[float], seed: int = 83) -> list[float] | None:
    if not values:
        return None
    rng = random.Random(seed)
    estimates = [statistics.fmean(rng.choices(values, k=len(values))) for _ in range(1000)]
    return [percentile(estimates, .025), percentile(estimates, .975)]


def found_cards(data: dict, scenario: dict) -> tuple[str, ...]:
    settings = data.get("resolved_scenarios", {}).get(scenario["id"], {}).get("settings", {})
    overrides = scenario.get("overrides", {})
    ids = settings.get("collected_cards", overrides.get("collected_cards"))
    if ids is None:
        ids = settings.get("deck", overrides.get("deck", []))
    return tuple(card for card in COLLECTIBLES if card in ids)


def summarize(data: dict) -> dict:
    scenarios = {s["id"]: s for s in data["config"]["scenarios"] if s["opponent"] == "older_brother"}
    used = {m["scenario"] for m in data["matches"] if m["scenario"] in scenarios}
    fingerprints = set()
    for id in used:
        settings = data.get("resolved_scenarios", {}).get(id, {}).get("settings", scenarios[id].get("overrides", {}))
        fixed = {key: value for key, value in settings.items() if key not in ("deck", "collected_cards", "opening_hand")}
        fingerprints.add(json.dumps(fixed, sort_keys=True))
    if len(fingerprints) > 1:
        raise ValueError("Progression comparisons require constant opponent/card tuning; only collection, deck, and opening size may vary.")
    conditions: dict[tuple[str, tuple[str, ...]], dict] = {}
    seen = set()
    for match in data["matches"]:
        if match["scenario"] not in scenarios:
            continue
        cards = found_cards(data, scenarios[match["scenario"]])
        key = (match["policy"], cards)
        row = conditions.setdefault(key, {"scenario": match["scenario"], "policy": match["policy"],
                                          "cards": list(cards), "count": len(cards), "by_seed": {}})
        if row["scenario"] != match["scenario"]:
            raise ValueError("Multiple scenarios represent the same card set; pass one consistent tuning study.")
        identity = (key, match["seed"])
        if identity in seen:
            raise ValueError(f"Duplicate scenario/policy/seed: {match['scenario']} / {match['policy']} / {match['seed']}")
        if match["winner"] not in ("player", "enemy", "timeout"):
            raise ValueError(f"Unknown outcome: {match['winner']}")
        seen.add(identity)
        row["by_seed"][match["seed"]] = match
    if not conditions:
        raise ValueError("No Older Brother matches found.")
    policies = sorted({key[0] for key in conditions})
    subsets = []
    for row in conditions.values():
        matches = list(row["by_seed"].values())
        resolved = [m for m in matches if m["winner"] != "timeout"]
        wins = sum(m["winner"] == "player" for m in resolved)
        row.update(matches=len(matches), wins=wins, losses=len(resolved)-wins,
                   timeouts=len(matches)-len(resolved), win_rate=wins/len(resolved) if resolved else None,
                   interval=wilson(wins, len(resolved)),
                   median_rounds=percentile([m["turns"] for m in resolved], .5))
        subsets.append({k: v for k, v in row.items() if k != "by_seed"})

    groups = []
    for policy in policies:
        for count in range(6):
            rows = [row for (name, cards), row in conditions.items() if name == policy and len(cards) == count]
            ranked = sorted((row for row in rows if row["win_rate"] is not None), key=lambda row: row["win_rate"])
            # A seed is the resampling unit: all of its subset outcomes travel
            # together. Pooling Bernoulli intervals here would invent independence.
            common = set.intersection(*(set(row["by_seed"]) for row in rows)) if rows else set()
            values = []
            excluded = 0
            for seed in sorted(common):
                outcomes = [row["by_seed"][seed]["winner"] for row in rows]
                if "timeout" in outcomes:
                    excluded += 1
                    continue
                values.append(statistics.fmean(outcome == "player" for outcome in outcomes))
            matches = [match for row in rows for match in row["by_seed"].values()]
            resolved = [m for m in matches if m["winner"] != "timeout"]
            equal_seed_sets = all(set(row["by_seed"]) == common for row in rows)
            complete = len(rows) == math.comb(5, count)
            group = {"policy": policy, "count": count, "subsets": len(rows),
                     "expected_subsets": math.comb(5, count), "complete": complete,
                     "matches": len(matches), "timeouts": len(matches)-len(resolved),
                     "win_rate": statistics.fmean(values) if values else None,
                     "interval": bootstrap(values), "interval_method": "seed-cluster bootstrap",
                     "paired_seeds": len(values), "excluded_seeds": excluded,
                     "unmatched_seed_sets": not equal_seed_sets,
                     "median_rounds": percentile([m["turns"] for m in resolved], .5),
                     "subset_min": ranked[0]["win_rate"] if ranked else None,
                     "subset_max": ranked[-1]["win_rate"] if ranked else None,
                     "weakest_cards": ranked[0]["cards"] if ranked else [],
                     "weakest_interval": ranked[0]["interval"] if ranked else None}
            groups.append(group)

    edges = []
    for (policy, cards), row in conditions.items():
        if len(cards) == 5:
            continue
        for addition in COLLECTIBLES:
            if addition in cards:
                continue
            next_cards = tuple(c for c in COLLECTIBLES if c in cards or c == addition)
            next_row = conditions.get((policy, next_cards))
            if next_row is None:
                continue
            shared = sorted(set(row["by_seed"]) & set(next_row["by_seed"]))
            differences = []
            for seed in shared:
                old = row["by_seed"][seed]["winner"]
                new = next_row["by_seed"][seed]["winner"]
                if "timeout" not in (old, new):
                    differences.append(int(new == "player") - int(old == "player"))
            edges.append({"policy": policy, "from": row["scenario"], "to": next_row["scenario"],
                          "from_cards": list(cards), "added": addition, "pairs": len(differences),
                          "unresolved_pairs": len(shared)-len(differences),
                          "gained": differences.count(1), "lost": differences.count(-1),
                          "delta": statistics.fmean(differences) if differences else None,
                          "_differences": differences})
    worst = sorted((e for e in edges if e["delta"] is not None), key=lambda e: (e["delta"], -e["lost"]))[:12]
    for edge in worst:
        edge["interval"] = bootstrap(edge["_differences"], 199)
    for edge in edges:
        edge.pop("_differences", None)
    edge_totals = []
    for policy in policies:
        rows = [e for e in edges if e["policy"] == policy]
        edge_totals.append({"policy": policy, "edges": len(rows), "expected_edges": 80,
                            "pairs": sum(e["pairs"] for e in rows),
                            "gained": sum(e["gained"] for e in rows),
                            "lost": sum(e["lost"] for e in rows),
                            "negative_edges": sum(e["delta"] is not None and e["delta"] < 0 for e in rows)})
    return {"metadata": data.get("metadata", {}), "policies": policies, "groups": groups,
            "subsets": subsets, "edges": edges, "worst_edges": worst, "edge_totals": edge_totals}


def percent(value: float | None) -> str:
    return "—" if value is None else f"{value * 100:.1f}%"


def names(ids: list[str]) -> str:
    return ", ".join(name.replace("_", " ").title() for name in ids) or "Base deck"


def interval_text(interval: list[float] | None) -> str:
    return "—" if not interval else f"{percent(interval[0])}–{percent(interval[1])}"


def chart(summary: dict) -> str:
    lines = []
    for y in range(0, 101, 20):
        at = 295-y*2.5
        lines.append(f'<line x1="55" y1="{at}" x2="885" y2="{at}" class="grid"/><text x="45" y="{at+4}" text-anchor="end">{y}%</text>')
    for count in range(6):
        x = 55+count*166
        lines.append(f'<text x="{x}" y="322" text-anchor="middle">{count} found</text>')
    for index, policy in enumerate(summary["policies"]):
        color = COLORS[index % len(COLORS)]
        rows = [g for g in summary["groups"] if g["policy"] == policy and g["win_rate"] is not None]
        points = " ".join(f'{55+g["count"]*166},{295-g["win_rate"]*250}' for g in rows)
        lines.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="3"/>')
        for group in rows:
            x, y = 55+group["count"]*166, 295-group["win_rate"]*250
            if group["interval"]:
                low, high = group["interval"]
                lines.append(f'<line x1="{x}" x2="{x}" y1="{295-high*250}" y2="{295-low*250}" stroke="{color}" stroke-width="5" opacity=".5"/>')
            lines.append(f'<circle cx="{x}" cy="{y}" r="5" fill="{color}"><title>{escape(policy)} · {group["count"]} found · {percent(group["win_rate"])}</title></circle>')
    return '<svg viewBox="0 0 940 345" role="img" aria-label="Player win rate as cards are found">' + ''.join(lines) + '</svg>'


def generate_report(data: dict, output_dir: Path) -> Path:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    summary = summarize(data)
    (output_dir / "progression-summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    groups = []
    for group in summary["groups"]:
        note = "" if group["complete"] else " · INCOMPLETE"
        note += " · unequal seed coverage" if group["unmatched_seed_sets"] else ""
        groups.append(f'<tr><td>{escape(group["policy"])}</td><td>{group["count"]}</td><td><b>{percent(group["win_rate"])}</b><small>{interval_text(group["interval"])}</small></td>'
                      f'<td>{group["median_rounds"] if group["median_rounds"] is not None else "—"}</td><td>{percent(group["subset_min"])}–{percent(group["subset_max"])}</td>'
                      f'<td>{escape(names(group["weakest_cards"]))}<small>Wilson: {interval_text(group["weakest_interval"])}</small></td>'
                      f'<td>{group["subsets"]}/{group["expected_subsets"]} sets · {group["paired_seeds"]} seeds{note}<small>{group["timeouts"]} timeouts; {group["excluded_seeds"]} incomplete seeds excluded</small></td></tr>')
    edges = []
    for edge in summary["worst_edges"]:
        delta = "—" if edge["delta"] is None else f'{edge["delta"]*100:+.1f} pp'
        interval = edge.get("interval")
        ci = "—" if not interval else f'{interval[0]*100:+.1f} to {interval[1]*100:+.1f} pp'
        edges.append(f'<tr><td>{escape(edge["policy"])}</td><td>{escape(names(edge["from_cards"]))}</td><td>+ {escape(names([edge["added"]]))}</td><td>{delta}<small>{ci}</small></td>'
                     f'<td>{edge["gained"]} / {edge["lost"]}</td><td>{edge["pairs"]}</td></tr>')
    totals = ''.join(f'<tr><td>{escape(row["policy"])}</td><td>{row["edges"]}/80</td><td>{row["gained"]:,}</td><td>{row["lost"]:,}</td><td>{row["negative_edges"]}</td></tr>' for row in summary["edge_totals"])
    legend = ''.join(f'<span style="--accent:{COLORS[i % len(COLORS)]}">{escape(policy)}</span>' for i, policy in enumerate(summary["policies"]))
    metadata = summary["metadata"]
    stamp = f'{metadata.get("total_matches",len(data["matches"])):,} matches · revision {metadata.get("git_commit","unrecorded")[:10]}'
    template = Path(__file__).with_suffix(".html").read_text(encoding="utf-8")
    values = {"__CHART__": chart(summary), "__GROUPS__": ''.join(groups), "__EDGES__": ''.join(edges),
              "__TOTALS__": totals, "__LEGEND__": legend, "__METADATA__": escape(stamp)}
    for key, value in values.items():
        template = template.replace(key, value)
    destination = output_dir / "curve.html"
    destination.write_text(template, encoding="utf-8")
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
