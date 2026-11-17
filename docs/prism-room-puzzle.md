# Main-room progression and two-brother card game

Design notes — November 15, 2026

**Historical design notebook.** These notes preserve the original proposals,
including questions and alternatives subsequently resolved. For the handoff state,
read [HANDOFF.md](HANDOFF.md), the [hall guide](../godot/scenes/escape/README.md),
and the [card guide](../godot/minigames/cards/README.md).

Status — November 16, 2026: the prism connector, side rooms, one-item carrying,
Egypt reward reveal, both brothers' card encounters, five hall discoveries,
shuffled discovery progression, initial sound pass and styled card parlor are
implemented. Persistent saves, final card themes/art, recorded character speech,
later item-based connectors and the final exit remain unfinished. The proposal
sections below are not a current implementation checklist.

Update — November 16: [the concrete prism layout proposal](prism-layout.md) now
maps a ceiling-fed starting prism, two reward prisms, four sockets, movable lenses,
and a central obstacle. That layout is now implemented; human playtesting is next.

## Purpose and progression

Turn the main room into an escape-room-style sequence connecting the larger station puzzles.
The intended progression is linear: solve a station, receive an item, figure out how to use it
in the main room, and unlock the next station. Connector puzzles should be short, tactile,
and atmospheric, while the stations provide the deeper challenges.

Door 1 starts unlocked and leads into the pyramid-themed room containing Egypt Fractal.
Door 2 is locked and has a visible laser receiver nearby. This room/door arrangement is a
proposed change from the current shared-hub implementation.

## Agreed ingredients

- A laser source and one steering prism are already installed in the main room.
- The player can interact with that prism to change the beam's direction.
- Multiple prism mounting slots are distributed around the room.
- Multiple colored lenses are available. Players can pick up and swap lenses among mounts.
- Room geometry or an opaque obstacle blocks an otherwise convenient beam route.
- Reaching the receiver requires routing through two color filters as well as redirecting
  the beam around the obstacle.
- The starting equipment is insufficient. Early experimentation should communicate that
  the player needs a reward from the pyramid puzzle, rather than encourage endless aiming.
- Completing Egypt Fractal awards additional prism equipment for the main-room puzzle.
- Aiming uses target snapping. Exact interaction feel and snapping behavior can be tuned later.
- Solving the beam route opens Door 2 and reveals the next station.

The exact number of reward prisms and total mounting slots remains open. Two reward prisms
and more available slots than prisms are the current working proposal, not a fixed requirement.

## Working color rule

The latest discussion chooses white source light and yellow and blue lenses, which
make green in either order. This is a deliberate magical, paint-like color rule,
superseding the earlier yellow/cyan physical-filter proposal. There is no ready-made
green lens. Lens order alone is not the puzzle: the spatial route must visit both
lenses and still reach the receiver.

The beam should visibly change color after each lens. Frame markings and receiver feedback
should teach the rule through play, without requiring prior knowledge of optics. Supplement
color with readable symbols or other cues where practical.

## Intended discovery sequence

1. Explore the main room and notice the open pyramid door, laser, installed prism, movable
   lenses, empty prism mounts, and locked Door 2.
2. Aim the existing prism. A direct hit produces a clear wrong-color response; single-filter
   routes demonstrate that neither available color alone is sufficient.
3. Recognize the missing steering equipment through visible sockets and matching visual
   cues in the pyramid room.
4. Complete Egypt Fractal and collect the prism reward.
5. Choose prism slots, swap lenses, and route the beam through both filters around the obstacle.
6. Deliver the correct beam to the receiver. Show an unmistakable success response and release
   the door latch.

## Interaction and scope

- Make choosing the route and placing lenses the challenge, not pixel-perfect alignment.
- Use discrete optical targets and forgiving snapping; show the outgoing beam or a preview.
- Keep placements reversible and essential items recoverable. Dedicated mounts and a small
  inventory are preferable to unrestricted physics-based dropping for the first version.
- A tempting but unsuitable route can teach the rules, but should provide useful feedback.
- Preserve clear distinctions between optical hardware and unrelated room decoration.
- Avoid adding timers, consumable items, split beams, or simultaneous receivers to the initial
  version. Those are possible future extensions, not part of the agreed first puzzle.
- Success should visibly transform the room: continuous colored light, a responding receiver,
  and a door that opens. Audio can reinforce each state once an audio system is introduced.

## Questions for the next design session

- How many prisms does Egypt Fractal award, and how many slots offer meaningful alternatives?
- Which slot positions, obstacle, and lens mounts produce a readable but nontrivial route?
- Can each mount hold a prism, a lens, or a dedicated type of component?
- How will players carry and swap lenses without losing track of them?
- What feedback clearly establishes that the starting equipment cannot solve the puzzle?
- Which existing room details can become optical hardware without making the whole room look
  like an arbitrary collection of puzzle props?

## New station: the two-brother card game

### Chosen direction

A compact, Inscryption-inspired physical card game against two NPC brothers. The cards will
eventually draw on the user's friends' interests, recurring jokes, and recognizable habits.
The user will gather those themes later; use generic names, art placeholders, and clear
mechanical roles until then. The game should have its own personality and rules.

This replaces the earlier proposed sensor/neural-network card-layout station as the active
direction. That concept raised concerns about opaque trial and error and is parked for now.

The defining feature is the connection between the duel and the main room: players discover
cards through exploration and small physical interactions, then use them to improve their
deck and overcome the stronger opponent. Main-room interaction is a major part of the game,
not just a corridor between stations.

### Two-stage encounter

1. The younger brother provides a short, forgiving tutorial match that is winnable with the
   default deck. Teach playing a creature, blocking a lane, and dealing an unblocked attack
   through simple cards and readable opponent behavior.
2. On defeat, he theatrically declares that the player will never beat his older brother.
   He mentions that his brother has an epic card he found lying around, introducing the idea
   that cards can be discovered in the environment.
3. The older brother becomes the progression opponent. The player may challenge him immediately
   or explore the room first. Losing is not a requirement for finding cards.
4. The player discovers useful cards, changes their deck, and returns with a new strategy.
5. Defeating the older brother completes the station and awards a physical progression item
   for a subsequent main-room puzzle. The item and next connector are not yet chosen.

Treat these as two successive opponent encounters, not a requirement to replay both matches
on every attempt. The younger brother stays beaten; optional practice rematches can remain.
Keep collected cards and deck changes after losses. Persisting that progress across sessions
is an intended supporting feature; the current game has no save system.

### Brothers and presentation

The younger brother is loud, theatrical, and bad at concealing his plans. He makes readable
mistakes and gives useful advice while pretending to threaten the player. The older brother
is calm, economical, and smug, with a recognizable signature strategy.

A proposed transition has the younger brother get up and call his brother over to the same
table. Both can remain as room characters after the station is completed.

Draft dialogue, not final writing:

> Younger: "NYA HA HA! A practice victory! Against a practice opponent!"
>
> Younger: "You'll never defeat my older brother. He has an EPIC card."
>
> Younger: "Found it just lying around, too. Somewhere you'd never think to look."
>
> Younger: "...Well, I didn't think to look."
>
> Older: "Under a chair."

A possible first discovery is a card tucked beneath the younger brother's vacated chair.
Make this easy to notice so the collection mechanic is demonstrated, not merely hinted at.
The exact location and staging are still proposals.

The older brother can acknowledge deck changes on later attempts ("That card wasn't in your
deck before") and react to losing against a recovered card ("I wondered where that went").

### Hidden cards and main-room play

- Cards can be found before the first match, and players can leave the table freely.
- Mix an easy introductory find, observation-based discoveries, NPC interactions, and small
  environmental puzzles. Avoid pixel hunting.
- Use a recognizable card back or other consistent visual cue for discoverable cards.
- Tie some discoveries to existing room details: the industrial door's wire glass, the floor
  seams Metric B mentions, the mainframe, optical hardware, pipes, and NPC interests.
- The way a card is found should help explain its ability when possible.
- Useful finds provide new tactical answers, not only larger numbers. The player should
  recognize how a discovery could counter something the older brother does.
- Require only a subset of hidden cards to win. Finding every card can be optional.
- Allow an unusually skilled player to beat the older brother early; reward it with a special
  reaction rather than enforcing an invisible collection requirement.
- Preserve the overall linear station progression while letting players choose how they
  prepare for this encounter.

Illustrative discoveries and effects, not a committed card list:

| Discovery | Placeholder card | Possible tactical use |
| --- | --- | --- |
| Card near the far side of the wire-glass door | Backdoor | Bypass a blocker |
| Illuminate a concealed panel with the prism beam | Refraction | Split an attack between lanes |
| Investigate a suspicious floor seam | Rounding Error | Finish an enemy left at one health |
| Help the engineer with a mainframe issue | Patch | Repair a creature or clear a harmful effect |
| Restore a small water mechanism | Overflow | Carry excess damage through a defeated blocker |

Ensure required discoveries are accessible before the older brother is beaten. Do not put
necessary counter-cards behind the progression reward they are meant to help earn.

### Working combat scope

The encounter structure and exploration loop are the chosen concept; exact combat rules
remain to be designed and playtested. Current prototype suggestions are:

- Three lanes, each with one creature on each side.
- Power, health, and at most one special ability per creature.
- A draw/play/resolve turn structure and one simple resource, provisionally "Attention."
- Unblocked damage advances a shared victory marker.
- Telegraph opponent plans so players can reason about the next turn.
- A fixed or curated opening hand for teaching; later draws can introduce variation.
- Approximately 12–16 distinct cards for an initial prototype, with short matches.
- Generic roles such as Guard, Scout, Heavy, Medic, and Saboteur; a Champion as the older
  brother's conspicuous signature card.

Build the older brother around a recognizable threat with several possible counters rather
than making every card in his deck overwhelmingly strong. Losses should be short enough to
invite another attempt and informative enough to suggest what the player needs.

Start with a crude playable prototype before producing final art, extensive animation,
or a card for every friend-group reference. No large collection economy, booster purchases,
or separate campaign is implied by this design.

### Audio direction

The user is interested in recording their own voice for Animal Crossing-inspired letter
speech. Short expressive bursts could suit the brothers' thinking, boasting, frustration,
and reactions to unfamiliar cards. Alphabet/vowel recordings, pacing, pitch, and punctuation
behavior are still to be prototyped; no character voice recordings have been added.

The current effect pass uses CC0 sounds included with the repository for card
handling, impacts, optics and hall interactions. The [audio guide](../godot/audio/README.md)
describes the source library and audition page. Final sample choices and mixing
remain open to listening feedback.

### Open decisions for the next session

- Final combat rules, resource, deck size, and deck-editing interaction.
- The older brother's signature threat and the different counter-strategies available.
- Which cards are starter cards, tutorial rewards, or room discoveries.
- Number and exact placement of discoveries, with a clear first find.
- Names, appearances, and friend-group themes for cards and both brothers.
- The station's place in the door sequence and its physical progression reward.
- How inventory, collected cards, defeated opponents, and deck changes are saved.

Core arc: learn the game → meet the rival → discover cards in the room → build an answer →
return and win. Both brothers, five discoverable cards and session collection are
now implemented. Persistent collection across launches and the next progression
reward/connector remain planned; see the current handoff linked above.
