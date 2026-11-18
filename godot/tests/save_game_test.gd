extends SceneTree
## Save file round trips, slots, autosave gating and batching, and the title screen.
## Uses its own slot files, so the player's real saves are never read or replaced.
const SaveGame := preload("res://autoload/save_game.gd")
const TITLE := "res://scenes/title/title.tscn"
var checks := 0
var failures := 0
var _game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game = root.get_node("Game")
	SaveGame.slot_prefix = "user://test_save_slot_"
	_erase_all()
	_file_format()
	_slots()
	await _autosave()
	await _title_screen()
	_erase_all()
	_game.autosave = false
	_game.save_path = ""
	print("Save game: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _erase_all() -> void:
	for slot in SaveGame.SLOTS:
		SaveGame.erase(SaveGame.slot_path(slot))


func _file_format() -> void:
	var path := SaveGame.slot_path(0)
	check(SaveGame.read(path).is_empty() and SaveGame.saved_at(path) == 0, "A missing save reads as empty")
	var state := {"flags": {"escape_optics_state": {"head_angles": {"A": 1.5}, "items": ["prism", ""]}},
		"completed_minigames": {"newton": {"won": true, "pyramids": [{"pos": Vector2(.2, -.1), "color": Color(0, 1, 1)}]},
			"turing": {"won": true, "route": PackedVector2Array([Vector2(1, 2), Vector2(3, 4)])}},
		"collected_cards": ["champion", "aegis"]}
	check(SaveGame.write(state, path) == OK, "Progress writes to disk")
	check(SaveGame.read(path) == state, "Nested flags, colors, vectors and routes survive a round trip")
	check(absi(SaveGame.saved_at(path) - int(Time.get_unix_time_from_system())) < 5, "Saves record when they were written")
	check(SaveGame.describe(state) == "Egypt ✓ · Roman Flow ✓ · 2/5 cards", "Slot summary lists wins and found cards")
	check(SaveGame.describe({}) == "Just started", "An empty save has a summary")
	var old := ConfigFile.new()
	old.set_value("meta", "version", SaveGame.VERSION + 1)
	old.set_value("progress", "flags", {"escape_prism_solved": true})
	old.save(path)
	check(SaveGame.read(path).is_empty() and SaveGame.saved_at(path) == 0, "A save from another format version is ignored")
	SaveGame.erase(path)
	check(not SaveGame.exists(path), "Erase removes the save")


func _slots() -> void:
	check(SaveGame.latest_slot() == -1 and SaveGame.first_empty_slot() == 0, "With no saves, slot 1 is free and nothing continues")
	_write_at(1, {"flags": {"escape_prism_solved": true}}, 100)
	_write_at(2, {}, 200)
	check(SaveGame.latest_slot() == 2, "Continue picks the most recently saved slot")
	check(SaveGame.first_empty_slot() == 0, "New game uses the first empty slot")
	_write_at(0, {}, 50)
	check(SaveGame.first_empty_slot() == -1, "Full slots leave no empty slot")
	_erase_all()


func _autosave() -> void:
	_game.autosave = false
	_game.save_path = ""
	_game.set_flag("room_visited")
	await create_timer(_save_wait()).timeout
	check(SaveGame.latest_slot() == -1, "Without autosave, changes never touch the disk")

	_game.flags["stale"] = true
	_game.new_game(1)
	check(_game.autosave and _game.flags.is_empty() and _game.completed_minigames.is_empty() \
		and _game.collected_cards.is_empty(), "New game clears progress and enables autosave")
	check(SaveGame.saved_at(SaveGame.slot_path(1)) != 0, "New game claims its slot immediately")
	var claimed := SaveGame.read(SaveGame.slot_path(1))
	_game.set_flag("escape_prism_solved")
	check(SaveGame.read(SaveGame.slot_path(1)) == claimed, "Saving waits briefly so rapid changes batch into one write")
	_game.collect_card("champion")
	_game.record_win("newton", {"won": true})
	await create_timer(_save_wait()).timeout
	check(SaveGame.read(SaveGame.slot_path(1)).get("collected_cards", []) == ["champion"], "Autosave writes after changes settle")

	_game.autosave = false
	_game.flags.clear()
	_game.completed_minigames.clear()
	_game.collected_cards.clear()
	check(_game.load_slot(1), "Loading a slot succeeds")
	check(_game.flags.get("escape_prism_solved", false) and _game.completed_minigames.has("newton") \
		and _game.collected_cards == ["champion"], "Loading restores flags, wins and found cards")
	check(_game.collected_cards.get_typed_builtin() == TYPE_STRING, "Found cards keep their typed array")
	check(_game.autosave and _game.save_path == SaveGame.slot_path(1), "Loading autosaves back to that slot")
	check(not _game.load_slot(2), "Loading an empty slot fails")

	_game.set_flag("pending_change")
	_game.new_game(0)
	check(SaveGame.read(SaveGame.slot_path(1)).get("flags", {}).has("pending_change"), "Switching slots writes the pending save first")
	_game.new_game(1)
	check(SaveGame.read(SaveGame.slot_path(1)).get("collected_cards", ["x"]).is_empty(), "New game in a used slot replaces it")
	_game.autosave = false
	_erase_all()


func _title_screen() -> void:
	var title: Control = await _open_title()
	check(not title.continue_button.visible and title.load_button.disabled, "With no saves, only New game is offered")
	title.queue_free()
	await process_frame

	_write_at(0, {"completed_minigames": {"newton": {"won": true}}}, 100)
	_write_at(2, {}, 300)
	title = await _open_title()
	check(title.continue_button.visible and not title.load_button.disabled, "Saves offer Continue and Load game")
	check(title.continue_button.has_focus(), "Continue has keyboard and gamepad focus")
	title.load_button.pressed.emit()
	check(title.slot_buttons[0].text.begins_with("Slot 1  ·  Egypt ✓") and title.slot_buttons[1].disabled,
		"Load game lists slot progress and disables empty slots")
	title._show_menu()
	title.new_button.pressed.emit()
	check(_game.save_path == SaveGame.slot_path(1), "New game starts in the first empty slot")
	title.queue_free()
	await process_frame
	_game.autosave = false

	title = await _open_title()
	title.new_button.pressed.emit()
	check(title.slot_buttons[0].visible and title._overwriting, "With every slot full, New game asks which slot to replace")
	title.slot_buttons[0].pressed.emit()
	check(SaveGame.read(SaveGame.slot_path(0)).has("completed_minigames") and "Replace" in title.slot_buttons[0].text,
		"Replacing a slot asks for a second press")
	title.slot_buttons[0].pressed.emit()
	check(SaveGame.read(SaveGame.slot_path(0)).get("completed_minigames", {"x": 1}).is_empty(), "The second press replaces the slot")
	title.queue_free()
	await process_frame
	_game.autosave = false


func _open_title() -> Control:
	var title: Control = load(TITLE).instantiate()
	root.add_child(title)
	await process_frame
	title._leaving = true  # Exercise the menu without leaving for the intro or hall.
	return title


func _write_at(slot: int, state: Dictionary, time: int) -> void:
	var path := SaveGame.slot_path(slot)
	SaveGame.write(state, path)
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("meta", "saved_at", time)
	config.save(path)


func _save_wait() -> float:
	return _game.SAVE_DELAY + 0.3


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
