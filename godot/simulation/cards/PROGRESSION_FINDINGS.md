# Five-card progression study — 16 November 2026

> Historical configuration: the live Older Brother now uses a 12-card base deck,
> a five-card opening (three core creatures plus two random draws), and shuffled
> discoveries. The measurements and reproduction notes below describe the earlier
> configuration at its recorded revision, not the current human-playtest build.

The selected tuning makes the current Older Brother base deck difficult for all
tested policies, while all five discoveries make it forgiving for the three
policies that reason about the board. The opponent stays fixed across collection
levels; improvements come from added cards and a larger opening hand.

**Verified against the playable rules:** all **25,600** normal-simulator matches
exactly reproduce the held-out tuning study, comparing both winner and resolved
round count for every subset/policy/seed. There are no missing or duplicate
matches and **zero timeouts**. The final production run used clean revision
`1f67f16dd725465f407e745757d33727bf088c2c`, Godot 4.7.2, and took 206.184 seconds.
Source hashes were unchanged throughout execution. Its full telemetry report and
raw data are served at the links below.

## Exact selected rules

Older Brother has four lanes, a ±12 victory threshold, and Attention refills
3 → 4 → 5. His prepared **Bulwark starts in lane 4** and counts against his finite
17-card reserve. The complete reserve, including that opening creature, is:

```text
Bulwark, Sentry, Veteran, Crossbow, Veteran, Bulwark, Crossbow,
Veteran, Sentry, Bulwark, Crossbow, Veteran, Bulwark, Crossbow,
Veteran, Sentry, Bulwark
```

| Opponent card | Attack / health | Ability |
|---|---:|---|
| Veteran | 3 / 8 | Straight attack |
| Bulwark | 2 / 10 | Straight attack |
| Crossbow | 2 / 8 | Both diagonals; one target at an edge |
| Sentry | 0 / 10 | One interception per opposing attack phase |

| Discovery | Attention | Attack / health | Effect |
|---|---:|---:|---|
| Champion | 2 | 2 / 10 | Durable straight attacker |
| Aegis | 2 | 1 / 10 | Intercepts into an empty adjacent lane |
| Tempest | 2 | 1 / 10 | Attacks both diagonals |
| Renewal | 1 | — | Restores up to 4 health to one injured ally |
| Thunderbolt | 1 | — | Deals 4 damage to one enemy creature |

The opening always contains **Bruiser, Forkshot, Sentinel, plus every discovery**.
With `k` discoveries, opening size is `3 + k` and deck size is `20 + k`, up to the
existing eight-card hand limit. Every original base-deck copy remains. The same
17-card tail is shuffled for the same seed at every collection level. Finding a
spell therefore cannot displace the last guaranteed creature or postpone it in
the draw pile. Discovery order does not change the canonical deck layout.

Cards join the deck directly when picked up; they do not replace a carried prism
or lens. Collection persists through rematches and hub recreation in the current
application session. It is not a persistent save across closing/reloading the game.
Little Brother retains his separate tutorial deck and encounter.

## Held-out results

**25,600 matches:** all 32 discovery subsets × four policies × 200 previously
unused seeds, **10000–10199**. The scratch study used the corresponding old role
IDs with explicit stats: Bruiser→Veteran, Defender→Bulwark, Forkshot→Crossbow, and
Sentinel→Sentry. These were role substitutions, not buffs to the player's base cards.

Each row averages equally across **every subset of that size**: coverage is
1, 5, 10, 10, 5, and 1 subsets for collection counts zero through five. This tests
all 80 possible one-card additions rather than only one assumed discovery order.

| Cards found | Tactical wins | Aggressive wins | Defensive wins | Random wins |
|---:|---:|---:|---:|---:|
| 0 | 8.50% | 0.00% | 6.50% | 3.00% |
| 1 | 40.10% | 8.50% | 26.00% | 5.50% |
| 2 | 69.20% | 29.30% | 40.45% | 10.05% |
| 3 | 87.35% | 59.75% | 57.05% | 11.95% |
| 4 | 96.40% | 82.30% | 72.20% | 19.30% |
| 5 | 99.00% | 92.00% | 100.00% | 24.50% |

With all five cards, median durations are six rounds for tactical play, seven for
aggressive, five for defensive, and thirteen for random play. These are bot
diagnostics, not estimated human success rates. Random play ignores position and
has a 12% chance to end its turn before each action, so a low random win rate does
not by itself imply that a fully upgraded human player will find the game hard.

The average curve rises steadily, but discovery identity matters. Tactical
win-rate ranges across subsets are **9–71%** with one card, **18–98.5%** with two,
**59.5–100%** with three, and **85.5–100%** with four. The weakest defensive
four-card subset wins only **28.5%**. A count-level average must not hide those cases.

## Why some bot results get worse after an addition

The opening contract adds options rather than removing a core creature. Bots can
still choose an added option badly. Three negative Aegis edges were tested with
an otherwise identical policy that keeps Aegis in the real hand but ignores it
when choosing actions:

| Policy and prior discoveries | Before Aegis | After Aegis | After Aegis, but ignored |
|---|---:|---:|---:|
| Defensive: Tempest + Renewal | 89 / 200 | 26 / 200 | 89 / 200 |
| Defensive: Tempest | 80 / 200 | 27 / 200 | 80 / 200 |
| Tactical: Champion + Renewal | 158 / 200 | 128 / 200 | 158 / 200 |

Ignoring Aegis restores **every individual seed's winner and round count** in
these fixtures, not merely the aggregate win count. That establishes a policy
choice problem for those examples rather than a forced loss of available
strategy. It does not prove every addition is harmless in every situation:
hand overflow, resource competition, and human decisions still require testing.
The aggregate progression is monotonic; individual subset/policy results are not.

## Reproduce through the normal simulator

From the repository root, using the bundled progression scenarios and current
production encounter:

```sh
python3 tools/card_sim.py --config godot/simulation/cards/progression.json --seed-start 10000 --seeds 200 --policies tactical,aggressive,defensive,random --output godot/build/web/progression
python3 tools/card_progression_report.py godot/build/web/progression/results.json
```

Open [the discovery curve](http://localhost:8060/progression/curve.html) or
[the complete balance report](http://localhost:8060/progression/report.html) with
the normal local server running. The normal run records source hashes, Git
revision, exact resolved settings, full telemetry, and individual replay commands.
The elite-card ID conversion and real `collected_cards` configuration have been
verified to preserve every held-out outcome and match duration.

The curve report resamples whole seeds across card sets for count-level intervals,
uses Wilson intervals for individual subsets, and reports paired gained/lost wins
for each one-card addition. It flags missing subset/seed coverage. Zero-width
bootstrap intervals do not prove a zero effect, and selecting the worst of many
edges is not a statistical significance test.

Workspace evidence is retained in `work/progression/`: `TUNING.md`,
`heldout-cw.json`, `heldout-cw-results.json`, `heldout-cw-summary.json`,
`ignore-proof.json`, `ignore-proof-results.json`, `production-parity.json`,
`compare_production.py`, `fast.gd`, and `ignore.gd`.
Those are tuning artifacts outside the repository; the commands above are the
maintained reproduction path. The earlier [baseline findings](FINDINGS.md) remain
historical evidence and do not describe this harder encounter.

## Playable integration verification

The pure progression suite passes 737 checks covering every subset, base-card
conservation, exact shared-seed draw tails, validation, and real spell effects.
Controller/scene, physical pickup targeting, table input, Older Brother combat,
card face layout, audio routing, and simulator regression suites also pass; the
Python reporting suites pass 17 tests. The Web export was rebuilt headlessly and
tested in a muted background browser. Champion was collected from its hall shelf,
appeared as the fourth opening card with a 1/5 collection count, and was played
onto the table for two Attention. Existing macOS certificate and scene-shutdown
resource warnings remain; there were no failed assertions or script errors.
