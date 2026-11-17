extends SceneTree
## Save file round trips, autosave gating and debouncing, and continue/new game.
## Uses its own file, so the player's real save is never read or replaced.
const SaveGame := preload("res://autoload/save_game.gd")
const TEST_PATH := "user://savegame_test.cfg"
var checks := 0
var failures := 0
var _game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game = root.get_node("Game")
	_game.save_path = TEST_PATH
	SaveGame.erase(TEST_PATH)
	_file_format()
	await _autosave()
	SaveGame.erase(TEST_PATH)
	_game.autosave = false
	_game.save_path = SaveGame.PATH
	print("Save game: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _file_format() -> void:
	check(SaveGame.read(TEST_PATH).is_empty(), "A missing save reads as empty")
	var state := {"flags": {"escape_optics_state": {"head_angles": {"A": 1.5}, "items": ["prism", ""]}},
		"completed_minigames": {"newton": {"won": true, "pyramids": [{"pos": Vector2(.2, -.1), "color": Color(0, 1, 1)}]},
			"turing": {"won": true, "route": PackedVector2Array([Vector2(1, 2), Vector2(3, 4)])}},
		"collected_cards": ["champion", "aegis"]}
	check(SaveGame.write(state, TEST_PATH) == OK, "Progress writes to disk")
	check(SaveGame.read(TEST_PATH) == state, "Nested flags, colors, vectors and routes survive a round trip")
	var old := ConfigFile.new()
	old.set_value("meta", "version", SaveGame.VERSION + 1)
	old.set_value("progress", "flags", {"escape_prism_solved": true})
	old.save(TEST_PATH)
	check(SaveGame.read(TEST_PATH).is_empty(), "A save from another format version is ignored")
	SaveGame.erase(TEST_PATH)
	check(not SaveGame.exists(TEST_PATH), "Erase removes the save")


func _autosave() -> void:
	_game.autosave = false
	_game.set_flag("room_visited")
	await create_timer(_save_wait()).timeout
	check(not _game.has_save(), "Without autosave, changes never touch the disk")

	_game.flags["stale"] = true
	_game.start_new()
	check(_game.autosave and _game.flags.is_empty() and _game.completed_minigames.is_empty() \
		and _game.collected_cards.is_empty(), "New game clears progress and enables autosave")
	_game.set_flag("escape_prism_solved")
	check(not _game.has_save(), "Saving waits briefly so rapid changes batch into one write")
	_game.collect_card("champion")
	_game.record_win("newton", {"won": true})
	await create_timer(_save_wait()).timeout
	check(_game.has_save(), "Autosave writes after changes settle")

	_game.autosave = false
	_game.flags.clear()
	_game.completed_minigames.clear()
	_game.collected_cards.clear()
	check(_game.continue_saved(), "Continue loads the save")
	check(_game.flags.get("escape_prism_solved", false) and _game.completed_minigames.has("newton") \
		and _game.collected_cards == ["champion"], "Continue restores flags, wins and found cards")
	check(_game.collected_cards.get_typed_builtin() == TYPE_STRING, "Found cards keep their typed array")
	check(_game.autosave, "Continue enables autosave")

	_game.start_new()
	check(not _game.has_save() and _game.collected_cards.is_empty(), "New game erases the existing save")
	_game.autosave = false
	check(not _game.continue_saved(), "Continue reports a missing save")


func _save_wait() -> float:
	return _game.SAVE_DELAY + 0.3


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
