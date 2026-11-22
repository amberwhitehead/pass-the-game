extends "res://tests/test_suite.gd"
## The Observatory chamber's blackboard shows one chalk sketch per forged sigil,
## and stays blank when none have been made.
const SaveGame := preload("res://autoload/save_game.gd")
const Math := preload("res://minigames/observatory/observatory_math.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, msg: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: " + msg)


func _run() -> void:
	var game = root.get_node("Game")
	SaveGame.slot_prefix = "user://test_observatory_board_slot_"
	game.new_game(0)
	game.set_flag("room_visited")
	game.collected_cards.clear()
	var room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await physics_frame
	var board: Node = room.find_child("ObservatoryBoard", true, false)
	_expect(board != null, "the Observatory chamber has a blackboard")
	_expect(board != null and board.get_node("Chalk").get_child_count() == 0, "the board is blank with no sigils")
	game.collect_card(Math.sigil(0).card)
	await process_frame
	_expect(board.get_node("Chalk").get_child_count() == 1, "one forged sigil draws one chalk sketch")
	for i in range(1, Math.SIGIL_COUNT):
		game.collect_card(Math.sigil(i).card)
	await process_frame
	_expect(board.get_node("Chalk").get_child_count() == Math.SIGIL_COUNT, "all sigils draw a full board")
	room.queue_free()
	await process_frame
	SaveGame.erase(SaveGame.slot_path(0))
	game.autosave = false
	game.save_path = ""
	print("Observatory board: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)