# Shuffled discoveries experiment — 16 November 2026

> Historical configuration: the live Older Brother now uses a 12-card base deck,
> a five-card opening (three core creatures plus two random draws), and shuffled
> discoveries. The measurements and reproduction notes below describe the earlier
> configuration at its recorded revision, not the current human-playtest build.

Shuffling the current discoveries into the draw pile does not preserve the
intended difficult-base/easy-full-collection progression. This is an experiment;
the playable opening rules have not changed.

## Endpoint comparison

The real Rules and Policies ran 3,000 matches: five conditions × three policies ×
200 seeds (10000–10199). No timeouts occurred. Enemy tuning, Attention, card stats,
and the normal one-card draw per turn were held constant.

| Opening model | Finds | Tactical wins | Aggressive wins | Defensive wins |
|---|---:|---:|---:|---:|
| Three core cards; discoveries shuffled | 0 | 8.5% | 0% | 6.5% |
| Three core cards; discoveries shuffled | 5 | 20% | 1% | 16% |
| Three core plus two random opening cards | 0 | 31% | 8.5% | 23% |
| Three core plus two random opening cards | 5 | 53.5% | 17.5% | 35% |
| Current guaranteed discoveries | 5 | 99% | 92% | 100% |

For shuffled conditions, the deck is `Catalog.older_deck()` followed by the
collected IDs in canonical order. The normal engine deals Bruiser, Forkshot, and
Sentinel, then shuffles the remainder. The five-card-opening prototype moves two
cards from that already-shuffled pile into the hand before the first decision,
without advancing turns, Attention, or opponent AI. The zero-find three-card
opening and guaranteed-five controls reproduce the previous study's endpoints.

The prototype and raw evidence remain in workspace `work/shuffled-opening/`:
`opening.gd`, `endpoints.json`, `results.json`, and `run.log`. The five-card
prototype is not a supported live configuration option.

## Every subset with the strict three-card opening

The normal telemetry simulator also ran **9,600 matches**: all 32 subsets × three
policies × 100 seeds (10000–10099), with **zero timeouts**. Count averages below
include all subsets of that size. This is exploratory reuse of prior seeds, not
an independently held-out validation of a newly selected balance.

| Finds | Tactical wins | Aggressive wins | Defensive wins |
|---:|---:|---:|---:|
| 0 | 5.0% | 0.0% | 5.0% |
| 1 | 11.8% | 0.6% | 6.0% |
| 2 | 10.5% | 0.3% | 10.9% |
| 3 | 19.1% | 1.0% | 12.3% |
| 4 | 18.4% | 2.2% | 16.6% |
| 5 | 20.0% | 2.0% | 16.0% |

For the same 100 seeds, the current guaranteed-discovery tactical curve is
5%, 41%, 71.2%, 88.2%, 96.4%, 99%. Different seed counts explain the difference
between the 5% base result here and the 8.5% base result in the endpoint study.

Reproduce the strict three-card experiment from the repository root:

```sh
python3 tools/card_sim.py --config godot/simulation/cards/shuffled_progression.json --seed-start 10000 --seeds 100 --policies tactical,aggressive,defensive --output godot/build/web/shuffled-progression
python3 tools/card_progression_report.py godot/build/web/shuffled-progression/results.json
```

[Discovery curve](http://localhost:8060/shuffled-progression/curve.html) ·
[Full telemetry report](http://localhost:8060/shuffled-progression/report.html)

## Interpretation and next design choices

The current progression grants both better cards and immediate access to extra
cards. Shuffling removes that opening advantage. With all five discoveries, the
draw pile contains 22 cards. After five draws (the start of turn six), the expected
number of discoveries seen is only `5 * 5 / 22 = 1.14`; the probability of none is
`C(17, 5) / C(22, 5)`, approximately **23.5%**. This describes deck order assuming
the match reaches that turn. With one discovery, its chance of appearing in those
five draws is **5/18 = 27.8%**.

Shuffling also delays fatigue and can delay useful base cards. Negative subset
edges can reflect actual draw tradeoffs as well as poor bot choices; the earlier
guaranteed-opening ignore-card controls cannot establish the cause here.

For a shuffled design, test a smaller base deck (roughly 12–14 cards) and stronger
discoveries that can stabilize a losing board. Keep opening size independent of
collection count. A five-card opening with some safe creatures is a possible
foundation, but the endpoint results show it is not enough by itself. Discoveries
can be allowed to appear naturally in random opening slots without guaranteeing
them. Any new tuning needs a separate seed range and human playtesting; these
heuristic win rates are diagnostics, not human difficulty estimates.
