# Initial balance study — 16 November 2026

> Historical configuration: the live Older Brother now uses a 12-card base deck,
> a five-card opening (three core creatures plus two random draws), and shuffled
> discoveries. The measurements and reproduction notes below describe the earlier
> configuration at its recorded revision, not the current human-playtest build.

**36,000 matches:** nine scenarios × four policies × seeds 0–999, with a 60-round
cap. All matches resolved. Run `python3 tools/card_sim.py --seeds 1000` to reproduce
this study with this revision's rules and policies. Full records, paired intervals,
and replay commands are in the generated balance report. Production tuning has
not been changed to match the experiments.

## The older brother has durability, but little resistance to strong play

| Policy | Player wins / 1,000 | Win rate, 95% Wilson interval | Median rounds | Rounds, 10th–90th percentile |
|---|---:|---:|---:|---:|
| Random legal play | 559 | 55.9% [52.8–58.9%] | 16 | 9–22 |
| Aggressive | 992 | 99.2% [98.4–99.6%] | 8 | 6–10 |
| Defensive | 964 | 96.4% [95.1–97.4%] | 9 | 6–14 |
| Tactical | 1,000 | 100% [99.6–100%] | 7 | 5–10 |

The tactical bot evaluates immediate visible combat. It neither sees the incoming
card nor searches future turns, so this is a useful difficulty-ceiling warning.
It is not an estimate of human win rate. The fixed teaching hand also means the
study samples shuffled follow-up draws, not arbitrary opening hands.

The durability goal is being met: defeated player creatures have a median of
**five rounds in play and five received hits** under every baseline policy. Hits
include creature attacks and Bolt. For tactical play, 933 creatures died and
3,976 remained alive at match end; survivors are tracked separately rather than
treated as completed lifespans. Increasing health alone would probably add time
without solving the observed difficulty ceiling.

## Knobs that change outcomes

| Older Brother variant | Random wins | Aggressive wins | Defensive wins | Tactical wins | Tactical median rounds |
|---|---:|---:|---:|---:|---:|
| Current game | 55.9% | 99.2% | 96.4% | 100% | 7 |
| Goal 18 instead of 12 | 26.1% | 95.1% | 82.8% | 97.7% | 11 |
| Attention starts at 2, caps at 4 | 40.2% | 100% | 94% | 100% | 7 |
| Enemy Bruiser power 3 instead of 2 | 24.6% | 85.2% | 82.4% | 94.4% | 7 |
| Opening Defender moves left | 63.6% | 99.7% | 97.7% | 99.8% | 6 |
| Player Sentinel loses interception | 41.5% | 98.8% | 94.8% | 99.9% | 7 |
| Player Forkshot attacks straight | 31.1% | 89.6% | 91.5% | 99.6% | 6 |
| Support-heavy fixed hand, same deck counts | 41.1% | 89.5% | 90.1% | 97.1% | 11 |

Each cell uses the same 1,000 seeds for its policy. Paired comparisons matter:

- Raising the goal adds **4.085 rounds on average** for tactical play while
  reducing wins by 2.3 percentage points (paired bootstrap interval −3.3 to −1.4).
- Stronger enemy Bruisers reduce tactical wins by **5.6 points** (−7.1 to −4.2),
  adding 1.128 rounds on average. This is a more promising pressure knob than
  simply making the victory threshold more distant, though stronger attacks can
  also shorten creature lifetimes.
- Lower Attention leaves tactical play undefeated and changes mean duration by
  only −0.143 rounds. This does not prove Attention is irrelevant, especially for
  weaker policies; it shows the current cap is not restricting this strong bot.
- Removing player interception barely affects tactical results but costs random
  play **14.4 points**. The mechanic helps under some strategies; the existing
  encounter does not require mastering it to win reliably.
- Replacing diagonal attacks with straight attacks hurts aggressive play much
  more than tactical play. That may reflect a bot adaptation or policy weakness,
  not a universal ranking of the two attack styles.

The intervals describe uncertainty across this seed sample under these policies.
They do not account for human behavior or correct for trying many experiments.
An interval of [0, 0] when no paired outcomes differ is not proof of zero effect.

## Attention, board space, and the enemy's missing deployments

Baseline bots leave **52.5–60.7% of Attention unspent**. The stronger three begin
roughly **41–43% of turns with all four lanes occupied**. This is evidence to
investigate card supply, occupied lanes, and useful spell targets before adding
more Attention. Intentional restraint and heuristic limitations also contribute.

An especially important interaction happens in **all 1,000 tactical baseline
matches**: the enemy misses at least one announced deployment. There are 1,030
blocked deployments across 7,094 resolved rounds. The adversarial fixture explains
the mechanism: during player attacks, the enemy Sentinel moves into the enemy's
announced deployment lane. The plan then fails even if another lane is empty,
and the reserve card remains unspent. A lane glow therefore sometimes announces
an arrival that never happens. Decide whether this is an intentional exploitable
tactic, a readable cancellation, or a rule to change before balancing around it.

Enemy fatigue never occurs in the 4,000 older baseline matches. Player fatigue
occurs in 480 random matches, 11 aggressive, 43 defensive, and one tactical match.
This is not evidence that enemy fatigue is broken; the reserve only advances on
successful deployments, while the player draws each round.

## Structural probes the batch win rate cannot explain alone

`sim_blindspots_test.gd` makes these situations reproducible with actual combat:

1. **First attack timing.** A new Bruiser deals direct damage through the glowing
   arrival lane before the blocker deploys. Player creatures can also kill before
   an enemy attack phase; new creatures attack immediately.
2. **Directional asymmetry.** A Bruiser/Forkshot/Sentinel arrangement deals two
   direct damage; the mirrored arrangement deals one. Left-to-right creature
   resolution and left-first diagonal hits cause this. Opening-left statistics
   also include bot and AI tie preferences, so they cannot isolate combat alone.
3. **Interception loses destinations on full boards.** The Sentinel remains a
   blocker but its signature movement cannot happen without an empty lane.
4. **Defensive locks punish the player first.** Filled Sentinel boards prevent
   new attackers from being played, even with spare Attention. The player can
   eventually die to draw fatigue while the opponent's blocked reserve never
   exhausts. This fixture proves possibility, not prevalence in normal play.
5. **Movement does have real value.** Swapping an edge Forkshot inward adds one
   direct damage in a fixture, and tactical play identifies the benefit. In the
   baseline, it uses Switcheroo in 756/1,000 matches.

## Recommended next experiments

First decide the intended behavior of blocked deployments and attack order. Then
test opponent pressure while preserving creature lifetime, rather than using
health or the victory threshold as the only difficulty controls. A player action
that repositions or retires an unwanted blocker could address crowded boards,
but would need new rules and its own experiment.

For the eventual hidden-card progression, run paired starter-versus-upgraded deck
experiments against a genuinely threatening older-brother baseline. The current
starter wins too consistently under basic strong play to establish a reliable
need to search the room. Keep Little Brother accessible: he currently loses to
all three heuristics and to random play in 909/1,000 matches, which is compatible
with his teaching role.

Use human playtests to choose desirable pacing and difficulty targets, then use
this lab to test whether a proposed change moves those targets consistently.
