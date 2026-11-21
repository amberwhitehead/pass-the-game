extends MiniGame
## Playable table controller. Rendering, cards and deterministic rules are separate modules.

signal entrance_finished

const Rules := preload("res://minigames/cards/match_rules.gd")
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const View := preload("res://minigames/cards/table_view.gd")
const Dialog := preload("res://minigames/cards/table_dialog.gd")
const Entrance := preload("res://minigames/cards/table_entrance.gd")
const Copy := preload("res://minigames/cards/encounter_text.gd")
const Config := preload("res://minigames/cards/match_config.gd")
const Progression := preload("res://minigames/cards/deck_progression.gd")
const SaveGame := preload("res://autoload/save_game.gd")
const Pad := preload("res://minigames/cards/table_pad.gd")

@export_enum("little_brother", "older_brother") var opponent_id := "little_brother"
var match_state: RefCounted
var table: Control
var _shown: Dictionary
var _selected := -1
var _swap_source := -1
var _busy := false
var _entering := false
var external_entrance := false
var _ever_won := false
var _seed := 1
var _dialog: Control
var _notes: Array[String] = []
var _found_cards: Array[String] = []
var _encounter_settings: Dictionary = {}
var _match_seed := 1
var _actions: Array = []  # Every rules call this match, so a later visit can replay it exactly.
var _resumed := false
var pad: Node  ## Controller focus and buttons (table_pad.gd).


func _ready() -> void:
	use_touch_controls = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = Color("0b2026")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	table = View.new()
	table.opponent_id = opponent_id
	add_child(table)
	table.hand_chosen.connect(_choose_card)
	table.lane_chosen.connect(_choose_lane)
	table.end_requested.connect(_end_turn)
	table.rules_requested.connect(_show_rules)
	table.restart_requested.connect(_confirm_restart)
	pad = Pad.new()
	pad.name = "Pad"
	pad.configure(self, table)
	add_child(pad)
	super()
	if _older():
		# Re-entering the room starts a fresh deal; the pure rules stay seedable.
		_seed = int(randi() % 2147483646) + 1
	_start_match()
	if not resume_state.is_empty():
		_resume_match(resume_state)
	_entering = true
	_busy = true
	_refresh()
	if external_entrance:
		table.hud.hide()
		table.hand.hide()
		return
	var entrance := Entrance.new()
	entrance.name = "BattleEntrance"
	table.world.add_child(entrance)
	entrance.start(table)
	await entrance.finished
	if _done or entrance.cancelled:
		return
	complete_entrance()


func complete_entrance() -> void:
	if _done or not _entering:
		return
	Sound.play("card_deal", self)
	# A window resize during the entrance must not leave its captured old FOV.
	table.fit_camera()
	_entering = false
	_busy = false
	table.hud.show()
	table.hud.modulate.a = 1.0
	table.hand.show()
	_refresh()
	if _resumed:
		table.hint.text = "Back at the table. The match is where you left it."
	else:
		_show_rules()
	entrance_finished.emit()


func _start_match() -> void:
	_close_dialog()
	_selected = -1
	_swap_source = -1
	_busy = false
	_notes.clear()
	_found_cards.clear()
	if _older():
		# Hall discoveries and bonus cards both join the deck; only the former are "N / 5".
		_found_cards = Progression.found(Game.collected_cards)
	var overrides := {"collected_cards": _found_cards} if _older() else {}
	_encounter_settings = Config.resolve(opponent_id, overrides)
	match_state = Rules.new(opponent_id, overrides)
	_match_seed = _seed
	_actions.clear()
	_shown = match_state.start(_seed)
	_seed += 1
	table.hud.collection_count = Progression.owned(_found_cards).size() if _older() else -1
	table.banter.text = Copy.opening(_older(), Progression.owned(_found_cards).size())
	table.hint.text = "Move to the bottom edge to raise your hand. Pick a card, then a target. Ring the bell to attack."
	table.history.text = "%d / 5 discoveries in this deck.\nFive opening cards. Discoveries are shuffled in." % Progression.owned(_found_cards).size() if _older() else "Your opening hand is fixed.\nExperiment freely."
	_refresh()


func _refresh() -> void:
	table.render(_shown, _selected, _busy or is_instance_valid(_dialog) or _shown.winner != "", _swap_source)


func _choose_card(index: int) -> void:
	if Sound.settings_open or _busy or is_instance_valid(_dialog) or _shown.winner != "":
		return
	Sound.play("card_draw", self)
	_swap_source = -1
	_selected = -1 if _selected == index else index
	if _selected < 0:
		table.hint.text = "Select a card, then choose its target."
	else:
		var card: Dictionary = match_state.get_card(_shown.hand[index])
		var target: String = "an empty friendly lane" if card.kind == "unit" else ("an enemy creature" if card.kind == "damage" else "a wounded friendly creature")
		if card.kind == "swap":
			target = "a friendly creature to swap with its neighbor"
		table.hint.text = "%s: choose %s. Costs %d Attention." % [card.name, target, card.cost]
		if card.cost > _shown.energy:
			table.hint.text = "Not enough Attention for %s. End your turn to refill." % card.name
	_refresh()


func _choose_lane(side: String, lane: int) -> void:
	if Sound.settings_open or _busy or is_instance_valid(_dialog) or _shown.winner != "":
		return
	if _selected < 0:
		var unit: Dictionary = _shown[side][lane]
		table.hint.text = "Choose a card from your hand first." if unit.is_empty() else "%s: %s" % [unit.name, unit.description]
		return
	var card: Dictionary = match_state.get_card(_shown.hand[_selected])
	var expected: String = "enemy" if card.kind == "damage" else "player"
	if side != expected:
		table.hint.text = "Choose %s for %s." % ["an enemy creature" if expected == "enemy" else "your side of the table", card.name]
		return
	if card.kind == "swap":
		await _choose_swap(lane)
		return
	var error: String = match_state.legality_error(_selected, lane)
	if error != "":
		Sound.play("unavailable", self)
		table.hint.text = error
		table.slot(side, lane).pulse(Color("e77e6c"))
		return
	_actions.append({"card": _selected, "lane": lane, "other": -1})
	var events: Array = match_state.play_card(_selected, lane)
	_selected = -1
	_swap_source = -1
	await _animate_events(events)


func _choose_swap(lane: int) -> void:
	if _swap_source == lane:
		_swap_source = -1
		table.hint.text = "Switcheroo: choose the first friendly creature again."
		_refresh()
		return
	if _swap_source < 0:
		if _shown.player[lane].is_empty():
			table.hint.text = "Switcheroo needs two neighboring friendly creatures."
			return
		var has_neighbor := false
		for neighbor in [lane - 1, lane + 1]:
			if neighbor >= 0 and neighbor < _shown.player.size() and not _shown.player[neighbor].is_empty():
				has_neighbor = true
		if not has_neighbor:
			table.hint.text = "That creature has no adjacent ally to swap with."
			return
		var card: Dictionary = match_state.get_card(_shown.hand[_selected])
		if card.cost > _shown.energy:
			table.hint.text = "Not enough Attention for Switcheroo."
			return
		_swap_source = lane
		table.hint.text = "Switcheroo: choose an occupied neighboring lane. Click the first creature again to cancel."
		_refresh()
		return
	var error: String = match_state.legality_error(_selected, _swap_source, lane)
	if not error.is_empty():
		Sound.play("unavailable", self)
		table.hint.text = error
		return
	_actions.append({"card": _selected, "lane": _swap_source, "other": lane})
	var events: Array = match_state.play_card(_selected, _swap_source, lane)
	_selected = -1
	_swap_source = -1
	await _animate_events(events)


func _end_turn() -> void:
	if Sound.settings_open or _busy or is_instance_valid(_dialog) or _shown.winner != "":
		return
	Sound.play("end_turn", self, 0, .8)
	_selected = -1
	_swap_source = -1
	_actions.append({"end": true})
	await _animate_events(match_state.end_turn())


func _animate_events(events: Array) -> void:
	_busy = true
	_refresh()
	for event: Dictionary in events:
		await table.animate_before(event)
		if _done or not is_instance_valid(table):
			return
		_shown = event.state
		_refresh()
		var message: String = event.get("message", "")
		if message != "":
			_notes.append(message)
			if _notes.size() > 4:
				_notes.pop_front()
			table.history.text = "\n\n".join(_notes)
			table.hint.text = message
		await table.animate_after(event)
		if _done or not is_instance_valid(table):
			return
		await create_tween().tween_interval(0.18).finished
		if _done or not is_instance_valid(table):
			return
	_busy = false
	_refresh()
	if _shown.winner != "":
		_show_result()
	else:
		table.hint.text = "Play another card, or ring the brass bell to attack."
		var banter := Copy.banter(_older(), _shown)
		if not banter.is_empty():
			table.banter.text = banter


func _show_rules() -> void:
	if _busy or is_instance_valid(_dialog):
		return
	_open_dialog("A larger wager" if _older() else "A friendly little card game", Copy.rules(_older(), _encounter_settings, Progression.owned(_found_cards)), [{"label": "Let's play", "callback": _close_dialog}])


func _confirm_restart() -> void:
	if _busy or _entering:
		return
	var body := "This resets the current duel. Your four opening cards stay the same; the remaining deck is shuffled."
	if _older():
		body = "This resets the current duel. You start with five cards: Bruiser, Forkshot, Sentinel, and two random draws. Found cards are shuffled into your deck and may appear in your opening hand or later. Cards you have collected stay yours."
	_open_dialog("Deal a new match?", body, [{"label": "Keep playing", "callback": _close_dialog}, {"label": "New match", "callback": _start_match}])


func _show_result() -> void:
	var won: bool = _shown.winner == "player"
	_ever_won = _ever_won or won
	var title := "You won!" if won else ("Older brother wins" if _older() else "Little brother wins")
	_open_dialog(title, Copy.result(_older(), won, Progression.owned(_found_cards)), [{"label": "Rematch", "callback": _start_match}, {"label": "Back to room", "callback": func(): finish({"won": _ever_won})}])


func _open_dialog(title: String, body: String, actions: Array) -> void:
	_close_dialog()
	_dialog = Dialog.new()
	add_child(_dialog)
	_dialog.setup(title, body, actions, "THE OLDER BROTHER'S TABLE" if _older() else "THE LITTLE BROTHER'S TABLE")
	_refresh()


func _close_dialog() -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
	if not _shown.is_empty():
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if Sound.settings_open:
		return
	if event.is_action_pressed("back") and is_instance_valid(_dialog) and _shown.winner == "":
		_close_dialog()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("back") and _swap_source >= 0 and not _busy:
		_swap_source = -1
		table.hint.text = "Switcheroo: choose the first friendly creature."
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("back") and _selected >= 0 and not _busy and _shown.winner == "":
		_selected = -1
		table.hint.text = "Select a card, then choose its target."
		_refresh()
		get_viewport().set_input_as_handled()
		return
	super(event)


## An unfinished match as its seed, starting deck and actions. The final snapshot lets a
## later visit confirm the replay still matches (card or rules tuning may have changed).
func save_state() -> Dictionary:
	if match_state == null or _actions.is_empty() or match_state.snapshot().winner != "":
		return {}
	return {"seed": _match_seed, "next_seed": _seed, "found": _found_cards.duplicate(),
		"actions": _actions.duplicate(true), "notes": _notes.duplicate(), "snapshot": match_state.snapshot()}


## Rebuilds a saved match by replaying it through the rules. Anything that no longer
## replays exactly (an illegal step or a different result) deals a fresh match instead.
func _resume_match(state: Dictionary) -> void:
	var found: Array[String] = []
	found.assign(state.get("found", []))
	var overrides := {"collected_cards": found} if _older() else {}
	var rules: RefCounted = Rules.new(opponent_id, overrides)
	rules.start(int(state.get("seed", 1)))
	var actions: Array = state.get("actions", [])
	for action: Dictionary in actions:
		if action.has("end"):
			if rules.snapshot().winner != "":
				return
			rules.end_turn()
		elif rules.legality_error(int(action.card), int(action.lane), int(action.other)) == "":
			rules.play_card(int(action.card), int(action.lane), int(action.other))
		else:
			return
	# Saved numbers come back as floats, so compare as saved data rather than with ==.
	if not SaveGame.same_data(rules.snapshot(), state.get("snapshot", {})):
		return
	_found_cards = found
	_encounter_settings = Config.resolve(opponent_id, overrides)
	match_state = rules
	_shown = rules.snapshot()
	_match_seed = int(state.get("seed", 1))
	_seed = int(state.get("next_seed", _seed))
	_actions = actions.duplicate(true)
	_notes.assign(state.get("notes", []))
	_resumed = true
	table.hud.collection_count = Progression.owned(_found_cards).size() if _older() else -1
	table.history.text = "\n\n".join(_notes)
	_refresh()


## Back still leaves during the entrance and once the match is decided.
func _back_leaves() -> bool:
	return _entering or _shown.get("winner", "") != ""


func finish(result: Dictionary) -> void:
	Sound.stop_owner(self)
	if _ever_won or _shown.get("winner", "") == "player":
		result = {"won": true, "opponent": opponent_id, "rounds": _shown.get("turn", 1)}
	super(result)


func _older() -> bool:
	return opponent_id == "older_brother"
