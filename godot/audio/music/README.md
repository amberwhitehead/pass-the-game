# Procedural music

Chiptune music synthesized live in GDScript: no audio files. Songs are short text in an
MML dialect (Music Macro Language, as on old computers and sound chips), compiled once and
played through an `AudioStreamGenerator` on the **Music** bus, so the Sound panel's Music
slider and Mute apply.

| File | Job |
| --- | --- |
| `song.gd` | Compiles a song definition into per-channel event arrays; reports errors. |
| `synth.gd` | Plays a compiled song into samples: pulse, triangle and drum voices, ADSR, vibrato, arpeggios, low-pass, stereo echo. Also renders offline. |
| `music_player.gd` | A Node that plays songs live, crossfading between them; also `render()` and `save_wav()`. |

CHRONO RAIDER's songs (`res://minigames/arcade/songs.gd`) are the worked example.

## Using it from a minigame

```gdscript
const MusicPlayer := preload("res://audio/music/music_player.gd")
var music := MusicPlayer.new()
music.songs = preload("res://minigames/mygame/songs.gd").all()   # id -> definition
add_child(music)
music.play("theme")        # crossfades from whatever was playing (default 0.6 s)
music.play("theme")        # already playing: nothing happens, so you can ask every frame
music.stop()
music.paused = true        # e.g. on NOTIFICATION_DISABLED, when the pause menu opens
```

Music stops when the node leaves the tree. A non-looping song (`"loop": false`) plays once;
asking for it again does nothing until another song (or `stop()`) is requested. The
`song_finished(id)` signal fires when it ends.

## A song

```gdscript
{
	"name": "Up the Timestream",
	"tempo": 150,                 # quarter notes per minute
	"loop": true,                 # loops from the L marker (or the start); default true
	"macros": {"riff": "o5 e8 a8 b8 > c4"},
	"channels": [
		{"wave": "pulse", "duty": 0.25, "volume": 0.15, "echo": 0.3, "mml": "r1 L {riff} {riff}"},
		{"wave": "triangle", "volume": 0.5, "octave": 2, "mml": "l8 [a>a<]8 L [a>a<]8"},
		{"wave": "drums", "volume": 0.4, "mml": "l8 [c e d e]4 L [c e d e]4"},
	],
}
```

Channels of a looping song must all be the same length (the compiler says if not).

### Channel settings

| Setting | Default | Meaning |
| --- | --- | --- |
| `wave` | `pulse` | `pulse` (square, with a duty cycle), `triangle` (a stepped chip triangle; good bass) or `drums` |
| `volume` | 0.2 | Channel level. Pulses are loud; keep leads around 0.15, chords under 0.1. |
| `pan` | 0 | -1 left .. 1 right |
| `duty` | 0.5 | Pulse width (0.125, 0.25, 0.5 or 0.75 sound most "chip") |
| `attack`, `decay`, `sustain`, `release` | 0.005, 0.12, 0.65, 0.08 | Envelope, in seconds (sustain is a level) |
| `vibrato`, `vibrato_rate`, `vibrato_delay` | 0, 5.5, 0.2 | Depth in semitones, Hz, seconds before it starts |
| `lowpass` | 1.0 | One-pole filter, 1 = off; 0.3-0.6 softens a harsh pulse |
| `echo` | 0 | Send to the stereo echo (about 0.2 s, a few repeats) |
| `octave` | 4 | Starting octave |

### MML commands

| Command | Meaning |
| --- | --- |
| `c d e f g a b` | A note, with `+`/`#` sharp or `-` flat, and an optional length: `c+8`, `b-4.` |
| `r` | Rest, with an optional length |
| length | `1` whole, `2` half, `4` quarter, `8`, `16`, `32`; each `.` adds half again |
| `^8` / `&` | Extend the previous note by a length / tie it into the next note of the same pitch |
| `l8` | Default length for notes without one |
| `o4`, `>`, `<` | Set the octave (`o4 c` is middle C), up one, down one |
| `v12` | Volume 0-15 (relative to the channel's `volume`) |
| `q6` | Gate: the fraction of each note that sounds, in eighths (default 7) |
| `@1` | Pulse duty: `@0` 12.5%, `@1` 25%, `@2` 50%, `@3` 75% |
| `k-2` | Transpose by semitones from here on (`k0` resets) |
| `%0,4,7` | Arpeggiate each note through these offsets (a major chord); `%0` stops |
| `[ ... ]3` | Repeat 3 times (2 if no number). In `[a b \| c]3`, the part after `\|` is skipped on the last pass |
| `{name}` | Insert a macro |
| `L` | Loop point: a looping song restarts here |
| `\|` | Outside a repeat, a bar line: ignored, just for reading |

**Drums**: in a `drums` channel the note letters choose a sound: `c` kick, `d` snare,
`e` closed hat, `f` open hat, `g` low tom, `a` high tom, `b` crash.

## Listening and checking

```sh
godot --headless --path godot res://tools/music_render.tscn -- --out=/tmp/music --seconds=40
```

writes each song as a WAV (default: CHRONO RAIDER's; `--songs=res://...` for another
`all()`), with its level and render speed. `tests/music_test.gd` covers parsing, timing,
levels, looping, the live player and the arcade's song choices.

The synth runs at 22,050 Hz and renders about 90x faster than real time on an M-series
Mac, so live playback costs around 1% of a core. It forces stream playback for its own
player, since the non-threaded Web build's default sample playback can't play a generator.

## Ideas

- More waves: a saw, FM bells, a noise-tone "sample" kick.
- Per-note effects: slides (portamento), duty sweeps, volume fades.
- Music for the hall, the Workshop's radio (it plays "the Hit Parade"), the title screen.
