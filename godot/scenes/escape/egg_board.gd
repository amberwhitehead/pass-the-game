extends Node3D
## A decorative travellers' board in the Easter Egg room (secret_room.gd). The phone in the
## middle is the 21st-century player and is always there; each ring position shows its
## stage's piece once that stage has a recorded win in Game.completed_minigames, the
## game's normal saved completion state. Nothing here is saved, awarded or announced.
## refresh() only shows or hides pieces built once, so it can run any number of times.

const Pieces := preload("res://scenes/escape/board_pieces.gd")
const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const Sign := preload("res://ui/world_sign.gd")

## Stage -> piece. A piece appears when any listed completed_minigames ID is recorded.
## The Brothers' two matches share one piece.
const STAGES := [
	{"stage": "Egypt Fractal", "piece": "pyramid", "wins": ["newton"]},
	{"stage": "Roman Flow", "piece": "arch", "wins": ["turing"]},
	{"stage": "The Brothers", "piece": "augmented", "wins": ["cards", "cards_older"]},
	# AI AGENT IMPLEMENTING A FUTURE STAGE: Connect this stage's genuine success condition
	# to its matching piece on the Easter Egg room's board. The piece asset already exists.
	# Record the win through the game's normal persistent completion path, then update
	# this mapping. Do not require the player to discover the secret room first, and do
	# not award the piece for merely entering or leaving the stage.
	{"stage": "Workshop", "piece": "mainframe", "wins": []},  # Unwired: no Workshop stage yet.
	{"stage": "Calendar", "piece": "maya_temple", "wins": []},  # Unwired: no Calendar stage yet.
	{"stage": "Observatory", "piece": "metric", "wins": []},  # Unwired: no Observatory stage yet.
]
const TOP := .8  # Table height; the board sits on it.

var pieces: Dictionary = {}  # stage name -> its piece (hidden until won)
var player_piece: Node3D


func _ready() -> void:
	name = "TravellersBoard"
	var walnut := Geometry.surface(Color("302219"), .2, .55)
	var felt := Geometry.surface(Color("183e36"), 0.0, .9)
	var brass := Geometry.material(Color("8c7448"), .72)
	Geometry.box(self, Vector3(0, TOP / 2, 0), Vector3(1.3, TOP, .9), walnut, true)  # table, solid
	Geometry.box(self, Vector3(0, TOP + .015, 0), Vector3(1.12, .03, .74), brass)
	Geometry.box(self, Vector3(0, TOP + .032, 0), Vector3(1.06, .006, .68), felt)
	player_piece = Pieces.build("phone")
	player_piece.position = Vector3(0, TOP + .035, 0)
	add_child(player_piece)
	for index in STAGES.size():
		var entry: Dictionary = STAGES[index]
		# A ring around the phone, turned so nothing stands directly behind another piece
		# or the phone from the open side, where every engraved name stays in view.
		var angle := TAU * index / STAGES.size() - PI / 3
		var at := Vector3(cos(angle) * .42, TOP + .035, sin(angle) * .26)
		Geometry.box(self, at + Vector3(0, .002, 0), Vector3(.12, .004, .12), brass)  # position plate
		var label := Sign.text(self, entry.stage, at + Vector3(0, .006, .085), .032, Sign.GOLD.darkened(.1))
		label.rotation.x = -PI / 2  # Engraved flat, read from the room's open side.
		var piece := Pieces.build(entry.piece)
		piece.position = at + Vector3(0, .004, 0)
		piece.visible = false
		add_child(piece)
		pieces[entry.stage] = piece
	MiniGames.ended.connect(_on_minigame_ended)
	refresh()


## Shows exactly the pieces whose stages are won in the current save.
func refresh() -> void:
	for entry: Dictionary in STAGES:
		(pieces[entry.stage] as Node3D).visible = won(entry)


static func won(entry: Dictionary) -> bool:
	for id: String in entry.wins:
		if Game.completed_minigames.has(id):
			return true
	return false


func _on_minigame_ended(_id: String, _result: Dictionary) -> void:
	refresh()  # MiniGames records a win before emitting ended.
