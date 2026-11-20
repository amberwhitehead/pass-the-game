extends RefCounted
## CHRONO RAIDER's soundtrack, in the MML dialect of res://audio/music (see its README).
## Original songs: "title" (attract), "stage", "boss", and the "clear" and "over" jingles.
## all() returns them by id, ready for MusicPlayer.songs.

## Instruments shared by the songs.
const LEAD := {"wave": "pulse", "duty": 0.25, "volume": 0.15, "attack": 0.004, "decay": 0.15, "sustain": 0.6,
	"release": 0.1, "vibrato": 0.25, "vibrato_rate": 5.5, "vibrato_delay": 0.18, "lowpass": 0.55, "echo": 0.35, "pan": -0.15}
const CHORD := {"wave": "pulse", "duty": 0.125, "volume": 0.065, "attack": 0.002, "decay": 0.3, "sustain": 0.5,
	"release": 0.1, "lowpass": 0.45, "echo": 0.25, "pan": 0.35}
const BASS := {"wave": "triangle", "volume": 0.5, "attack": 0.002, "decay": 0.1, "sustain": 0.75, "release": 0.04,
	"lowpass": 0.8, "octave": 2}
const DRUMS := {"wave": "drums", "volume": 0.42, "pan": 0.05}


static func _ch(instrument: Dictionary, mml: String) -> Dictionary:
	var c := instrument.duplicate()
	c.mml = mml
	return c


const STAGE_MACROS := {
	# Lead, A section: Am F G E | Am F G Am.
	"leadA": "o5 e4 a8 b8 > c4 < b8 a8 | o5 a4. g8 f4 e4 | o5 d4 g8 a8 b4 g4 | o5 g+2 e2 |"
		+ " o5 e4 a8 b8 > c4 d8 e8 | o6 f4. e8 d4 c4 | o5 b4 > c8 d8 < b4 g4 | o5 a2. r4 |",
	# Lead, B section: Dm Em F G | Dm Em F E.
	"leadB": "o5 d8 f8 a8 > d8 < a8 f8 d8 f8 | o5 e8 g8 b8 > e8 < b8 g8 e8 g8 | o5 f8 a8 > c8 f8 e8 c8 < a8 > c8 | o6 d4 < b4 g4 b4 |"
		+ " o5 a4. > d8 c4 < a4 | o5 b4. > e8 d4 < b4 | o6 c4 < a4 > c4 f4 | o6 e2 g+2 |",
	# Lead, C section (the breather): F G Em Am | F G E E.
	"leadC": "o5 c2 a2 | o5 d2 b2 | o5 g1 | o5 e1 | o5 c2 f2 | o5 d2 g2 | o5 g+1 | o5 b1 |",
	"chordA": "o4 %0,3,7 a1 %0,4,7 f1 g1 e1 %0,3,7 a1 %0,4,7 f1 g1 %0,3,7 a1 %0",
	"chordB": "o4 %0,3,7 d1 e1 %0,4,7 f1 g1 %0,3,7 d1 e1 %0,4,7 f1 e1 %0",
	"chordC": "o4 %0,4,7 f1 g1 %0,3,7 e1 a1 %0,4,7 f1 g1 e1 e1 %0",
	"bassA": "o2 l8 [a>a<]4 [f>f<]4 [g>g<]4 [e>e<]4 [a>a<]4 [f>f<]4 [g>g<]4 [a>a<]4",
	"bassB": "o2 l8 [d>d<]4 [e>e<]4 [f>f<]4 [g>g<]4 [d>d<]4 [e>e<]4 [f>f<]4 [e>e<]4",
	"bassC": "o2 l4 [f]4 [g]4 [e]4 [a]4 [f]4 [g]4 [e]8 l8",
	"beat": "l8 c e d e c c d e",
	"fill": "l16 d d d d d d d d l8 c d d d",
	"drumsAB": "[{beat}]7 {fill}",
	"drumsC": "[c4 e4 d4 e4]7 {fill}",
}

const TITLE_MACROS := {
	"melody": "o5 e2. a4 | o5 g2. d4 | o5 c2. f4 | o5 e1 | o5 e2 a4 b4 | o6 c2 < b4 g4 | o5 a2 f4 a4 | o5 g+1 |",
	"chords4": "o4 %0,3,7,12 a1 %0,4,7,12 g1 f1 e1 %0",
	"bass4": "o2 a1 g1 f1 e1",
	"beat": "l8 c e e e d e e e",
}

const BOSS_MACROS := {
	"lead": "o5 e8 r8 e8 f8 e8 r8 b8 a+8 | o5 e8 r8 e8 f8 g4 f8 e8 | o5 f8 r8 f8 g8 f8 r8 > c8 < b8 | o5 a4 g4 f4 e4 |"
		+ " o6 e4. d8 c4 < b4 | o5 a+4. a8 g4 f4 | o5 e8 f8 g8 a+8 b8 > c8 d8 d+8 | o6 e2 < b2 |",
	"chords": "o4 %0,3,7 e1 e1 %0,4,7 f1 %0,3,7 e1 %0,4,7 c1 d1 %0,3,7 e1 %0,3,6,9 b1 %0",
	"bass": "o2 l16 [ee>e<e]4 [ee>e<e]4 [ff>f<f]4 [ee>e<e]4 [cc>c<c]4 [dd>d<d]4 [ee>e<e]4 [bb>b<b]4",
	"beat": "l8 c16 c16 e d e c c d e",
	"fill": "l16 d d d d d d d d l8 c d d d",
}

## Every song, by id.
static func all() -> Dictionary:
	return {
	"title": {
		"name": "Insert Coin", "tempo": 104, "loop": true, "macros": TITLE_MACROS,
		"channels": [
			{"wave": "pulse", "duty": 0.25, "volume": 0.14, "attack": 0.02, "decay": 0.4, "sustain": 0.55, "release": 0.3,
				"vibrato": 0.2, "vibrato_rate": 5.0, "vibrato_delay": 0.25, "lowpass": 0.4, "echo": 0.5, "pan": -0.2,
				"mml": "r1 r1 r1 r1 L {melody} k12 {melody} k0"},
			{"wave": "pulse", "duty": 0.125, "volume": 0.06, "attack": 0.002, "decay": 0.5, "sustain": 0.45, "release": 0.2,
				"lowpass": 0.35, "echo": 0.35, "pan": 0.3, "mml": "{chords4} L {chords4} {chords4} {chords4} {chords4}"},
			{"wave": "triangle", "volume": 0.45, "attack": 0.01, "decay": 0.3, "sustain": 0.8, "release": 0.2, "lowpass": 0.7,
				"mml": "{bass4} L {bass4} {bass4} {bass4} {bass4}"},
			{"wave": "drums", "volume": 0.3, "mml": "l8 [e]32 L [{beat}]16"},
		],
	},
	"stage": {
		"name": "Up the Timestream", "tempo": 150, "loop": true, "macros": STAGE_MACROS,
		"channels": [
			_ch(LEAD, "r1 r1 L {leadA} {leadB} {leadA} {leadB} {leadC}"),
			_ch(CHORD, "r1 r1 L {chordA} {chordB} {chordA} {chordB} {chordC}"),
			_ch(BASS, "o2 l8 [a>a<]8 L {bassA} {bassB} {bassA} {bassB} {bassC}"),
			_ch(DRUMS, "l8 {beat} {fill} L {drumsAB} {drumsAB} {drumsAB} {drumsAB} {drumsC}"),
		],
	},
	"boss": {
		"name": "Chronarch", "tempo": 168, "loop": true, "macros": BOSS_MACROS,
		"channels": [
			_ch(LEAD, "r1 L {lead} k12 q5 {lead} q7 k0"),
			_ch(CHORD, "r1 L {chords} {chords}"),
			_ch(BASS, "o2 l16 [e]16 L {bass} {bass}"),
			_ch(DRUMS, "l16 [d]16 L [{beat}]7 {fill} [{beat}]7 {fill}"),
		],
	},
	"clear": {
		"name": "Stage Clear", "tempo": 140, "loop": false,
		"channels": [
			_ch(LEAD, "o5 l8 c e g > c4 < g > c e2. r4"),
			_ch(CHORD, "o4 %0,4,7 c2 g2 c1"),
			_ch(BASS, "o3 l8 c g c g c4 g4 c1"),
			_ch(DRUMS, "l8 c e d e c d c4 b1"),
		],
	},
	"over": {
		"name": "Game Over", "tempo": 84, "loop": false,
		"channels": [
			_ch(LEAD, "o5 l4 a g f e d+2 e2"),
			_ch(CHORD, "o4 %0,3,7 a1 %0,4,7 e1"),
			_ch(BASS, "o2 a1 e1"),
			_ch(DRUMS, "c1 r1"),
		],
	},
}
