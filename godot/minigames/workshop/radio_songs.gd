extends RefCounted
## The Engineer's tabletop radio: three original 1955 stations and the hiss between them,
## in the MML dialect of res://audio/music (see its README). Soft, filtered timbres so they
## sound like they come out of a small valve radio.
##
## STATIONS lists the dial (id, name, frequency); all() returns every song by id, ready for
## MusicPlayer.songs; song(i) is station i's definition; static_noise() is the hiss.
##
## Playing it from the Workshop (as arcade.gd does with its music):
##   const MusicPlayer := preload("res://audio/music/music_player.gd")
##   const RadioSongs := preload("res://minigames/workshop/radio_songs.gd")
##   var radio_music := MusicPlayer.new()
##   radio_music.songs = RadioSongs.all()
##   add_child(radio_music)
##   radio_music.play(RadioSongs.STATIONS[i].id, 0.25)   # tune to station i (crossfades)
##   radio_music.play("static", 0.1)                     # between stations
##   radio_music.stop(0.3)                                # switched off / tube taken
##   # In the MiniGame's _notification: NOTIFICATION_DISABLED -> radio_music.paused = true,
##   # NOTIFICATION_ENABLED -> radio_music.paused = false (the pause menu).
## Music stops by itself when the node leaves the tree.

const STATIONS := [
	{"id": "easy", "name": "WLTM Easy Listening", "frequency": "550"},
	{"id": "bach", "name": "The Bach Hour", "frequency": "880"},
	{"id": "havana", "name": "Radio Havana", "frequency": "1240"},
]

# --- WLTM Easy Listening: a lounge tune in F, 16 bars at 92 bpm (about 42 s). -------------
const EASY_MACROS := {
	"melody": "o5 a2 g4 f4 o5 a2. r4 o5 b-4 a4 g4 f4 o5 g2. r4 o6 c2 o5 a4 g4 o5 e2. r4"
		+ " o5 d4 f4 a4 > c4 o5 b-2. r4 o5 a4. g8 e4 c4 o5 f2. a4 o5 g4. f8 d4 b-4 o5 g2 e2"
		+ " o5 f4 a4 > c4 < a4 o5 f+2. r4 o5 g4 b-4 a4 g4 o5 f2. r4",
	"pad3": "o4 a1 f1 b-1 e1 a1 > c1 < d1 e1 > c1 < f1 b-1 e1 a1 f+1 b-2 e2 a1",
	"pad7": "o4 e1 c1 f1 b-1 e1 g1 a1 b-1 g1 c1 f1 b-1 e1 c1 f2 b-2 c1",
	"walk": "o2 f4 a4 > c4 < e4 o2 d4 f4 a4 f+4 o2 g4 b-4 > d4 < b4 o2 c4 e4 g4 e4"
		+ " o2 f4 a4 > c4 < g+4 o2 a4 > c4 < g4 b4 o2 b-4 > d4 f4 < a4 o2 c4 e4 g4 b4"
		+ " o2 a4 > c4 < a4 > c+4 o2 d4 f4 a4 f+4 o2 g4 b-4 > d4 < b4 o2 c4 e4 g4 e4"
		+ " o2 f4 a4 > c4 < e4 o2 d4 f+4 a4 f+4 o2 g4 b-4 c4 e4 o2 f4 a4 > c4 < e4",
}

# --- The Bach Hour: an original minuet in G, A A B B, 3/4 at 132 bpm (about 44 s). --------
const BACH_MACROS := {
	"treblaA": "o5 b4 a8 g8 a8 b8 o4 g4 b4 > d4 o5 c4 e8 d8 c8 < b8 o4 a2 > d4"
		+ " o5 e4 d8 c8 < b8 a8 o4 g4 b8 a8 g8 f+8 o4 e8 f+8 g4 f+4 o4 g2.",
	"bassA": "o3 g2 f+4 o3 e2 d4 o3 c2 e4 o3 d2 c4 o3 c4 e4 c4 o2 b2 > c4 o3 c4 d4 d4 o3 g2 o2 g4",
	"trebleB": "o5 f+4 e8 d8 e8 f+8 o5 a4 f+4 d4 o5 e4 c+8 d8 e8 c+8 o5 d2."
		+ " o5 d4 o4 b8 > c8 d8 < b8 o5 c4 o4 a8 b8 > c8 < a8 o4 b8 > c8 d4 < f+4 o4 g2.",
	"bassB": "o3 d2 c+4 o2 b2 > d4 o3 a2 a4 o3 d4 o2 a4 f+4 o3 g2 g4 o2 a2 > c4 o3 g4 d4 d4 o3 g2 o2 g4",
}

# --- Radio Havana: a cha-cha-chá in C, 16 bars at 120 bpm (32 s). ------------------------
const HAVANA_MACROS := {
	# Piano montuno over C F | G F.
	"montuno": "o4 g8 > c8 e8 < g8 r8 a8 > c8 f8 o4 b8 > d8 g8 < b8 r8 a8 > c8 f8",
	# The tumbao: bass on the and-of-two and on four, anticipating the next chord.
	"tumbao": "o2 r4 r8 c8 r4 f4 o2 r4 r8 g8 r4 f4",
	"trumpet": "o5 e4 e8 e8 r8 d8 c8 d8 o5 e4. d8 c4 r4 o5 f4 f8 f8 r8 e8 d8 e8 o5 f4. e8 d4 r4"
		+ " o5 g4 g8 a8 g8 f8 e8 d8 o5 c4 e4 g4 r4 o5 a8 g8 f8 e8 d4. o4 b8 o5 c2 r2",
	# Kick, güiro, conga, and the cha-cha-chá at the end of the bar.
	"groove": "l8 c e a e c e a16 a16 g",
	# 3-2 son clave, two bars, as a rimshot.
	"clave": "l8 d r r d r r d r r r d r d r r r",
}


## One channel: an instrument's settings plus its music.
static func _ch(settings: Dictionary, mml: String) -> Dictionary:
	var c := settings.duplicate()
	c.mml = mml
	return c


static func all() -> Dictionary:
	return {
		"easy": {
			"name": "WLTM Easy Listening", "tempo": 92, "loop": true, "macros": EASY_MACROS,
			"channels": [
				# A mellow lead, like a muted horn: square, filtered hard, slow vibrato.
				_ch({"wave": "pulse", "duty": 0.5, "volume": 0.12, "attack": 0.04, "decay": 0.4, "sustain": 0.6,
					"release": 0.25, "vibrato": 0.18, "vibrato_rate": 4.5, "vibrato_delay": 0.3, "lowpass": 0.22,
					"echo": 0.35, "pan": -0.1}, "{melody}"),
				# Two soft pad voices holding the chords' thirds and sevenths.
				_ch({"wave": "pulse", "duty": 0.25, "volume": 0.045, "attack": 0.12, "decay": 0.6, "sustain": 0.7,
					"release": 0.4, "lowpass": 0.18, "echo": 0.2, "pan": 0.3}, "{pad3}"),
				_ch({"wave": "pulse", "duty": 0.25, "volume": 0.04, "attack": 0.12, "decay": 0.6, "sustain": 0.7,
					"release": 0.4, "lowpass": 0.18, "echo": 0.2, "pan": -0.3}, "{pad7}"),
				# A walking upright bass.
				_ch({"wave": "triangle", "volume": 0.42, "attack": 0.01, "decay": 0.25, "sustain": 0.45,
					"release": 0.08, "lowpass": 0.6}, "q6 {walk}"),
				# Brushes: a soft swung shuffle.
				_ch({"wave": "drums", "volume": 0.14, "pan": 0.1}, "[c4 e8. e16 d4 e8. e16]16"),
			],
		},
		"bach": {
			"name": "The Bach Hour", "tempo": 132, "loop": true, "macros": BACH_MACROS,
			"channels": [
				# Harpsichord-ish: a thin pulse that plucks and fades.
				_ch({"wave": "pulse", "duty": 0.125, "volume": 0.24, "attack": 0.001, "decay": 0.35, "sustain": 0.18,
					"release": 0.12, "lowpass": 0.35, "echo": 0.25, "pan": -0.2},
					"q7 {treblaA} {treblaA} {trebleB} {trebleB}"),
				_ch({"wave": "pulse", "duty": 0.25, "volume": 0.2, "attack": 0.001, "decay": 0.4, "sustain": 0.2,
					"release": 0.12, "lowpass": 0.3, "echo": 0.2, "pan": 0.2},
					"q7 {bassA} {bassA} {bassB} {bassB}"),
			],
		},
		"havana": {
			"name": "Radio Havana", "tempo": 120, "loop": true, "macros": HAVANA_MACROS,
			"channels": [
				# The trumpet: comes in after four bars of band.
				_ch({"wave": "pulse", "duty": 0.5, "volume": 0.11, "attack": 0.01, "decay": 0.2, "sustain": 0.55,
					"release": 0.08, "vibrato": 0.2, "vibrato_rate": 6.0, "vibrato_delay": 0.15, "lowpass": 0.35,
					"echo": 0.25, "pan": -0.15}, "r1 r1 r1 r1 {trumpet} r1 r1 r1 r1"),
				# Piano montuno: short, bright-ish plucks.
				_ch({"wave": "pulse", "duty": 0.25, "volume": 0.06, "attack": 0.001, "decay": 0.18, "sustain": 0.2,
					"release": 0.05, "lowpass": 0.4, "pan": 0.3}, "q5 [{montuno}]8"),
				_ch({"wave": "triangle", "volume": 0.45, "attack": 0.005, "decay": 0.2, "sustain": 0.5,
					"release": 0.06, "lowpass": 0.65}, "q6 [{tumbao}]8"),
				_ch({"wave": "drums", "volume": 0.16, "pan": 0.15}, "[{groove}]16"),
				_ch({"wave": "drums", "volume": 0.07, "pan": -0.25}, "[{clave}]8"),
			],
		},
		"static": static_noise(),
	}


## Station i's song definition (wraps around the dial).
static func song(index: int) -> Dictionary:
	return all()[STATIONS[posmod(index, STATIONS.size())].id]


## The hiss between stations: fast noise and a faint whistle that wavers, as an AM radio
## does when it isn't quite on anything. Loops every two seconds.
static func static_noise() -> Dictionary:
	return {
		"name": "Static", "tempo": 120, "loop": true,
		"channels": [
			_ch({"wave": "drums", "volume": 0.3}, "l32 [e f e e f e e e]8"),
			_ch({"wave": "pulse", "duty": 0.5, "volume": 0.03, "attack": 0.3, "sustain": 1.0, "release": 0.3,
				"vibrato": 0.6, "vibrato_rate": 0.7, "vibrato_delay": 0.0, "lowpass": 0.5}, "o7 c1&c1"),
		],
	}
