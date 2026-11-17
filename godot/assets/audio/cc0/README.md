# Game audio — CC0

These sound effects are by **Kenney**, released under **CC0 1.0**. They may be
included in this public repository and redistributed with the game. Original
pack license notices are retained in `licenses/`.

| Pack | Source | Included original clips |
| --- | --- | ---: |
| Casino Audio | https://kenney.nl/assets/casino-audio | 17 |
| Interface Sounds | https://kenney.nl/assets/interface-sounds | 22 |
| Impact Sounds | https://kenney.nl/assets/impact-sounds | 22 |
| RPG Audio | https://kenney.nl/assets/rpg-audio | 13 |
| Sci-fi Sounds | https://kenney.nl/assets/sci-fi-sounds | 14 |

The 88 original Ogg files retain their source filenames and bytes. Three engine
files with a `-loop` suffix are prepared alternatives: a 0.5-second tail-to-head
crossfade removes the hard loop boundary, followed by peak normalization to
−3 dB and Ogg Vorbis encoding. Their unedited sources are also included.

The [manifest](../cc0_manifest.json) records each file's source, hash, duration,
measured levels, pack license, and any processing. It contains the full recipe
and source ID for each loop derivative. The library is about 1.8 MB in total and
includes audition alternatives as well as the game's selected sounds.

Sound assignments and mix settings live in [cues.json](../cues.json). See the
[audio guide](../../../audio/README.md) for playback and audition instructions.
