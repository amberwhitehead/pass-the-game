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
	"cards": {"title": "Little Brother's Card Table", "scene": "res://minigames/cards/cards.tscn"},
	"cards_older": {"title": "Older Brother's Card Table", "scene": "res://minigames/cards/cards_older.tscn"},
	"newton": {"title": "Egypt Fractal", "scene": "res://minigames/newton/newton.tscn",
		"trophy": "res://minigames/newton/newton_trophy.gd"},
	"turing": {"title": "Roman Flow", "scene": "res://minigames/turing/turing.tscn",
		"trophy": "res://minigames/turing/aqueduct.gd"},
}

var current: Node = null
var _current_id := ""
var _backdrop: ColorRect
var transition: Control
var _hub_state: RefCounted
var _launching := false
var _cancel_loading := false
const TableHandoff := preload("res://minigames/cards/table_handoff.gd")
const HubState := preload("res://minigames/cards/hub_camera_state.gd")


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_running() -> bool:
	return current != null or _launching


func current_title() -> String:
	return REGISTRY.get(_current_id, {}).get("title", "")


## Pauses the calling scene, runs the mini-game, resolves with its result.
func play(id: String) -> Dictionary:
	if is_running() or not REGISTRY.has(id):
		return {}
	_launching = true
	_cancel_loading = false
	var path: String = REGISTRY[id].scene
	# Threaded load keeps the web build responsive for heavier mini-games.
	ResourceLoader.load_threaded_request(path)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null or _cancel_loading:
		_launching = false
		if packed == null:
			push_error("Mini-game failed to load: " + path)
		return {}

	_current_id = id
	var source_camera := get_viewport().get_camera_3d()
	var use_handoff := id in ["cards", "cards_older"] and source_camera != null
	if use_handoff:
		_hub_state = HubState.new()
		_hub_state.capture(source_camera, get_tree().current_scene)
		_hub_state.hide_hud()
		var player := source_camera.get_parent()
		if player is Player:
			player._look_finger = -1
	get_tree().paused = true
	_backdrop = ColorRect.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.color = Color(0, 0, 0, 0.85)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = not use_handoff
	add_child(_backdrop)

	current = packed.instantiate()
	if use_handoff:
		current.external_entrance = true
		current.hide()
	current.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(current)
	_launching = false
	started.emit(id)
	Sound.play("transition", current)
	if use_handoff:
		transition = TableHandoff.new()
		add_child(transition)
		transition.completed.connect(_handoff_complete)
		transition.start(source_camera, current)

	var result: Dictionary = await current.finished
	Sound.stop_owner(current)
	if is_instance_valid(transition):
		transition.abort()
		transition.queue_free()
		transition = null
	current.queue_free()
	current = null
	_backdrop.queue_free()
	if _hub_state != null:
		_hub_state.restore()
		_hub_state = null
	else:
		get_tree().paused = false
	if result.get("won", false):
		Game.record_win(id, result)
	ended.emit(id, result)
	return result


func _handoff_complete() -> void:
	_backdrop.show()
	_hub_state.restore_camera()
	transition.queue_free()
	transition = null


func _unhandled_input(event: InputEvent) -> void:
	if _launching and event.is_action_pressed("back"):
		_cancel_loading = true
		get_viewport().set_input_as_handled()
