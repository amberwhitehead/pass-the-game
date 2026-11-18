# Audio

The effect and ambience library is included in Git under
[`assets/audio/cc0/`](../assets/audio/cc0/). Clone the project, let Godot import its
assets, and play. The selected sounds come from **Kenney's CC0 packs**, which
permit copying, editing and redistribution, including in this public repository.
Source URLs and individual asset identities are recorded in
[`cc0_manifest.json`](../assets/audio/cc0_manifest.json); the original pack notices
are kept in [`cc0/licenses/`](../assets/audio/cc0/licenses/).

## Audition and choose sounds

After a normal Web build, open **[the audition page](http://localhost:8060/audio/)**.
The page provides a dropdown, preview controls, gain adjustment and notes for each
sound target. It starts with the game's current choices. Some targets offer a set
of variations, which preserves the game's random sample variation; others offer
individual clips. Ambience can loop while comparing candidates. Playback starts
only when requested.

1. Browse by group or search for an interaction such as “card draw” or “door.”
   The review filter focuses on choices that particularly need a listening pass.
2. Choose a candidate and preview it. Adjust its gain and add a note if useful.
   Compare the choice in the game as well: room ambience, animation timing and
   simultaneous effects affect how a sound feels.
3. Use **Export JSON** to download a list of choices and hand it back to the
   developer. The page saves its working selections locally in your browser;
   exporting or changing a dropdown does not modify the running game.

To rebuild just the audition page from the repository root, using Python 3's
standard library:

```sh
python3 tools/build_audio_audition.py
```

The default output is `godot/build/web/audio/`. An optional `--output` chooses a
different directory. Keep the normal Web server running, then refresh the page.
On Windows, substitute `py -3` for `python3`.

Apply a reviewed export from the repository root:

```sh
python3 tools/apply_audio_choices.py /path/to/audio-choices.json --dry-run
python3 tools/apply_audio_choices.py /path/to/audio-choices.json
```

The importer validates the asset IDs, variation sets, gains and notes, then updates
`cues.json`. It retains gameplay pitch variation, repeat throttling and looping
settings. Notes are stored as `review_notes`. Review the diff, rebuild Web, and
playtest the result before committing. Restart an editor playtest after edits;
the runtime caches the loaded cue definitions and audio streams.

## Cue data and sources

[`cues.json`](../assets/audio/cues.json) is the shared source for gameplay and the
audition page:

- `files`: the selected clip IDs, or a variation set.
- `db`: the cue's gain before the persistent mixer levels.
- `pitch` and `gap`: random pitch range and minimum time between repeats.
- `loop`: continuous playback for the ambience target.
- `label`, `group`, `description`, `review`, `options`: readable audition labels,
  review priorities and candidate sets.

`cc0_manifest.json` maps each clip ID to its committed file, creator's pack,
source URL, duration and checksum. When adding a sound, keep the audio file,
manifest entry and original license notice together. Use a verified CC0 source
so teammates can continue sharing the complete project in Git. Kenney's
[asset FAQ](https://kenney.nl/support) and the
[CC0 summary](https://creativecommons.org/publicdomain/zero/1.0/) describe the
permissions. Attribution is optional under these terms; we retain source records
so future contributors can identify and replace sounds easily.

## What is wired up

| Area | Cues |
| --- | --- |
| Hall | Footstep variations, looping server ambience, doors, discovery |
| Optics | Pickup, socket placement, wheel grab/turn/snap, lens light, receiver success |
| Rewards | Pedestal rise and reveal |
| Cards | Draw/place, shuffle/deal, attack/direct hit, death, zap/heal, end turn, opponent intent, table transition, win/loss |
| UI | Confirm and unavailable feedback |

NPC voices and a new music pass are still future work. The owner is interested in
recording letter/vowel chatter. The current sample choices are a complete playable
pass; ambience, glass, mechanisms and spells especially benefit from human feedback.

`Sound` owns bounded pools of 12 flat and 12 positional voices. Gameplay uses
semantic cue names through `sound_bank.gd`. Random variation has its own RNG.
Voices carry a weak scene owner, so minigame exit and freed scenes stop their sounds.

Hall footsteps use distance actually walked; teleports and frozen controls do not
produce steps. The server bed loops and ducks during minigames. Optics audio
responds to angle travel, snap acquisition and color changes, rather than redraws.
Card attack contact is synchronized with the forward lunge; placement sounds land
at the end of the card's slide. Sound settings block player input and persist
Master / Effects / Ambience levels.

The game's `?muted=1` query overrides preferences and prevents QA from saving a
forced mute into the player's settings. The audition page also accepts `?muted=1`
for silent UI checks. Remove that query when actually listening.

### Web bus routing

`SoundMixer` creates missing buses by increasing `AudioServer.bus_count`, then
names them and sends them to Master. Keep that initialization path: Godot 4.7.2's
Web sample backend can reorder buses when `AudioServer.add_bus()` appends one,
disconnecting Master from the browser output despite successful playback and
healthy volume settings. See the [engine issue](https://github.com/godotengine/godot/issues/119026).
Growing the count avoids that path and retains the default low-latency Sample
playback mode. Native/headless asset checks cannot detect this Web-only failure;
also verify the browser's sample-bus graph reaches its audio destination.

## Verify

After importing assets, run from the repository root with Godot on PATH (or
substitute its full executable path):

```sh
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- audio_test
python3 -m unittest discover -s tools -p 'test_audio_choices.py'
```

These checks validate decoding, cue references, timing contracts, scene ownership
and input/voice lifecycle. They do not evaluate whether the mix sounds good. Keep
automated checks muted and do the listening pass separately.
