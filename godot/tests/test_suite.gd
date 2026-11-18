extends Node
## Base for test suites. run_suites.gd runs many suites in one Godot process, so a suite
## is a node rather than its own SceneTree; these members stand in for the few SceneTree
## ones suites use, letting a suite read exactly as it did when it was the whole tree.

signal suite_finished(code: int)

var root: Window:
	get: return get_tree().root
var process_frame: Signal:
	get: return get_tree().process_frame
var physics_frame: Signal:
	get: return get_tree().physics_frame
var paused: bool:
	get: return get_tree().paused
	set(value): get_tree().paused = value
var current_scene: Node:
	get: return get_tree().current_scene
	set(value): get_tree().current_scene = value
var _suite_done := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Suites keep running while they pause the game.


## Called by the host once the suite is in the tree, as SceneTree calls it at startup.
func _initialize() -> void:
	pass


func create_timer(seconds: float, process_always := true, process_in_physics := false,
		ignore_time_scale := false) -> SceneTreeTimer:
	return get_tree().create_timer(seconds, process_always, process_in_physics, ignore_time_scale)


## Ends the suite (not the program); the host records the code and moves on.
func quit(code := 0) -> void:
	if _suite_done:
		return
	_suite_done = true
	suite_finished.emit(code)
