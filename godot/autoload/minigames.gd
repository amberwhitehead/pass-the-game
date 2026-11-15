extends CanvasLayer
## Registry + launcher for mini-games.
##
## To add a mini-game:
##   1. create res://minigames/<id>/<id>.tscn whose root script extends MiniGame
##   2. add one line to REGISTRY below
## Each mini-game loads its own assets in _ready() / via ResourceLoader.
## Interactable objects in the room just set `minigame_id = "<id>"`.
## Optional "trophy": a script with `static func build(result: Dictionary) -> Node3D` that returns what the
## station's platform shows once the game is won (see Prop._refresh_completed).

signal started(id: String)
signal ended(id: String, result: Dictionary)

const REGISTRY := {
	"newton": {"title": "Egypt Fractal", "scene": "res://minigames/newton/newton.tscn",
		"trophy": "res://minigames/newton/newton_trophy.gd"},
	"turing": {"title": "Roman Flow", "scene": "res://minigames/turing/turing.tscn",
		"trophy": "res://minigames/turing/aqueduct.gd"},
}

var current: Node = null
var _current_id := ""
var _backdrop: ColorRect


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_running() -> bool:
	return current != null


## Pauses the calling scene, runs the mini-game, resolves with its result.
func play(id: String) -> Dictionary:
	if current or not REGISTRY.has(id):
		return {}
	var path: String = REGISTRY[id].scene
	# Threaded load keeps the web build responsive for heavier mini-games.
	ResourceLoader.load_threaded_request(path)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		push_error("Mini-game failed to load: " + path)
		return {}

	_current_id = id
	get_tree().paused = true
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.85)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	current = packed.instantiate()
	current.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(current)
	started.emit(id)

	var result: Dictionary = await current.finished
	current.queue_free()
	current = null
	_backdrop.queue_free()
	get_tree().paused = false
	if result.get("won", false):
		Game.completed_minigames[id] = result
	ended.emit(id, result)
	return result
