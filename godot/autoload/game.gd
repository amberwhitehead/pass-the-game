extends Node
## Global game state + input map registration.
## Actions are registered in code so the on-screen buttons, keyboard and
## (later) gamepad all drive the same names.
const DeckProgression := preload("res://minigames/cards/deck_progression.gd")
const SaveGame := preload("res://autoload/save_game.gd")
const KeyBindings := preload("res://autoload/key_bindings.gd")
const SAVE_DELAY := 0.5  # Batches rapid changes, such as turning a prism wheel, into one write.

signal flag_changed(flag: String, value: Variant)
signal card_collected(id: String)

var flags: Dictionary = {}
var completed_minigames: Dictionary = {}  # id -> best result Dictionary
var collected_cards: Array[String] = []  # Discoveries; independent of carried puzzle items.
## Off until the title screen starts or loads a game, so tests and single-scene runs
## never read or overwrite the player's saves.
var autosave := false
var save_path := ""  # The active slot's file; empty until a game starts or loads.
var _save_timer: Timer


func collect_card(id: String) -> bool:
	if id not in DeckProgression.all_collectible() or id in collected_cards:
		return false
	collected_cards.append(id)
	card_collected.emit(id)
	_queue_save()
	return true


func record_win(id: String, result: Dictionary) -> void:
	completed_minigames[id] = result
	_queue_save()


## Unfinished minigame progress, kept in flags so it saves with everything else.
func minigame_progress(id: String) -> Dictionary:
	return (get_flag("minigame_progress", {}) as Dictionary).get(id, {}).duplicate(true)


func set_minigame_progress(id: String, state: Dictionary) -> void:
	var all: Dictionary = (get_flag("minigame_progress", {}) as Dictionary).duplicate(true)
	if state.is_empty():
		all.erase(id)
	else:
		all[id] = state.duplicate(true)
	set_flag("minigame_progress", all)


func has_save() -> bool:
	return save_path != "" and SaveGame.exists(save_path)


func load_slot(slot: int) -> bool:
	return continue_saved(SaveGame.slot_path(slot))


func new_game(slot: int) -> void:
	start_new(SaveGame.slot_path(slot))


## Restores saved progress and autosaves there from now on. Returns false if there is no usable save.
func continue_saved(path := save_path) -> bool:
	var state := SaveGame.read(path)
	if state.is_empty():
		return false
	_flush_pending()
	save_path = path
	_apply(state)
	autosave = true
	return true


## Plays progress without a save slot, so nothing is written (the save editor's Play).
func play_unsaved(state: Dictionary) -> void:
	_flush_pending()
	save_path = ""
	autosave = false
	_apply(state)


func snapshot() -> Dictionary:
	return {"flags": flags, "completed_minigames": completed_minigames, "collected_cards": collected_cards}


func _apply(state: Dictionary) -> void:
	flags = (state.get("flags", {}) as Dictionary).duplicate(true)
	completed_minigames = (state.get("completed_minigames", {}) as Dictionary).duplicate(true)
	collected_cards.assign(state.get("collected_cards", []))


## Clears progress and starts a fresh save at path, replacing anything there.
func start_new(path := save_path) -> void:
	_flush_pending()
	save_path = path
	flags.clear()
	completed_minigames.clear()
	collected_cards.clear()
	autosave = true
	save_now()


func save_now() -> void:
	_save_timer.stop()
	if autosave and save_path != "":
		SaveGame.write(snapshot(), save_path)


func _queue_save() -> void:
	if autosave:
		_save_timer.start(SAVE_DELAY)


## Writes a pending autosave to the current slot before switching to another.
func _flush_pending() -> void:
	if _save_timer != null and not _save_timer.is_stopped():
		save_now()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if autosave:
			MiniGames.capture_progress()  # Closing mid-minigame keeps its progress too.
		_flush_pending()


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS  # Minigames pause the tree.
	_save_timer.timeout.connect(save_now)
	add_child(_save_timer)
	# The built-in font lacks arrows, ▲▼◀▶, ✕, minus and superscripts (and web builds have no
	# system fonts to fall back on), so ship DejaVu Sans as the default and the fallback.
	ThemeDB.fallback_font = load("res://assets/fonts/DejaVuSans.ttf")
	_register_actions()
	# Background browser QA can mute this run without changing normal playtests.
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('muted') === '1'")):
		AudioServer.set_bus_mute(0, true)


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)
	_queue_save()


func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)


## Actions (all devices feed the same names):
##   move_up/down     walk forward/back     (W/S, ↑/↓, left stick Y, D-pad)
##   move_left/right  turn left/right       (arrows, D-pad, touch ◀ ▶)
##   strafe_left/right sidestep             (A/D, left stick X)
##   look_*           look around           (right stick; the captured mouse looks directly)
##   jump                                   (Space)
##   interact / back                        (E/Enter/F, pad A) / (Esc/Backspace, pad B)
## Touch: on-screen pad buttons + drag-to-look (see TouchControls / Player).
## Keyboard keys come from KeyBindings (defaults, then the player's saved choices).
func _register_actions() -> void:
	var pad_buttons := {
		"move_up": [JOY_BUTTON_DPAD_UP],
		"move_down": [JOY_BUTTON_DPAD_DOWN],
		"move_left": [JOY_BUTTON_DPAD_LEFT],
		"move_right": [JOY_BUTTON_DPAD_RIGHT],
		"interact": [JOY_BUTTON_A],
		"back": [JOY_BUTTON_B],
	}
	# [action, axis, direction]
	var pad_axes := [
		["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0],
		["strafe_left", JOY_AXIS_LEFT_X, -1.0], ["strafe_right", JOY_AXIS_LEFT_X, 1.0],
		["look_left", JOY_AXIS_RIGHT_X, -1.0], ["look_right", JOY_AXIS_RIGHT_X, 1.0],
		["look_up", JOY_AXIS_RIGHT_Y, -1.0], ["look_down", JOY_AXIS_RIGHT_Y, 1.0],
	]
	for action in ["look_left", "look_right", "look_up", "look_down", "strafe_left", "strafe_right"]:
		_ensure(action)
	for entry: Dictionary in KeyBindings.ACTIONS:
		_ensure(entry.action)
	KeyBindings.apply(KeyBindings.defaults())
	for action: String in pad_buttons:
		for btn: int in pad_buttons[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = btn as JoyButton
			InputMap.action_add_event(action, ev)
	for a: Array in pad_axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = a[1] as JoyAxis
		ev.axis_value = a[2]
		InputMap.action_add_event(a[0], ev)
	# Saved keyboard choices replace only key events. Headless runs (tests, exports)
	# keep the defaults so they never depend on, or read, the player's preferences.
	if DisplayServer.get_name() != "headless":
		KeyBindings.apply(KeyBindings.load_saved())


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
