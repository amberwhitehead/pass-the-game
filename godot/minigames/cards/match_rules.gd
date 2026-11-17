extends RefCounted
## Configurable duel. Each action returns events with independent state
## snapshots so presentation can animate without controlling the rules or AI.

const Catalog := preload("res://minigames/cards/card_catalog.gd")
const Encounter := preload("res://minigames/cards/match_encounter.gd")
const Combat := preload("res://minigames/cards/match_combat.gd")
const AI := preload("res://minigames/cards/match_ai.gd")
const Config := preload("res://minigames/cards/match_config.gd")
const LANES := 3
const WIN_BALANCE := 10
const MAX_ATTENTION := 4
const HAND_LIMIT := 8
const ENEMY_SEQUENCE := Encounter.LITTLE_SEQUENCE

var opponent_id := "little_brother"
var opponent_name := "Little Brother"
var lane_count := LANES
var goal := WIN_BALANCE
var _settings: Dictionary
var _enemy_reserve: Array[String] = []

var _player: Array[Dictionary] = [{}, {}, {}]
var _enemy: Array[Dictionary] = [{}, {}, {}]
var _hand: Array[String] = []
var _deck: Array[String] = []
var _discard: Array[String] = []
var _energy := 2
var _max_energy := 2
var _turn := 1
var _balance := 0
var _winner := ""
var _intent: Dictionary = {}
var _fatigue := 0
var _enemy_fatigue := 0
var _next_uid := 0
var _resolving := false


func _init(id := "little_brother", overrides: Dictionary = {}) -> void:
	var problems := Config.errors(id, overrides)
	assert(problems.is_empty(), "Invalid match tuning: %s" % str(problems))
	_settings = Config.resolve(id, overrides)
	opponent_id = _settings.id
	opponent_name = _settings.name
	lane_count = _settings.lanes
	goal = _settings.goal


func get_card(id: String, side := "player") -> Dictionary:
	return Config.card(_settings, id, side)


func start(seed: int = 1) -> Dictionary:
	_player.clear()
	_enemy.clear()
	for lane in lane_count:
		_player.append({})
		_enemy.append({})
	_hand.clear()
	_discard.clear()
	_deck.assign(_settings.deck)
	_enemy_reserve.assign(_settings.reserve)
	# Reserve the reliable prefix, then draw the remaining opening slots randomly.
	# Finds share the ordinary shuffle; they are neither guaranteed nor excluded.
	for i in int(_settings.fixed_opening):
		_hand.append(_deck.pop_front())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(_deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var card: String = _deck[i]
		_deck[i] = _deck[j]
		_deck[j] = card
	while _hand.size() < int(_settings.opening_hand):
		_hand.append(_deck.pop_front())
	_energy = _settings.starting_attention
	_max_energy = _energy
	_turn = 1
	_balance = 0
	_winner = ""
	_fatigue = 0
	_enemy_fatigue = 0
	_next_uid = 0
	_resolving = false
	# Prepared defenders are visible from the start and paid from the finite reserve.
	for lane: int in _settings.opening_lanes:
		_enemy[lane] = _make_unit(_enemy_reserve.pop_front(), "enemy")
	_intent = AI.choose(self) if opponent_id == "older_brother" else {"card": "guard", "lane": 1}
	return snapshot()


func snapshot() -> Dictionary:
	return {"player": _player.duplicate(true), "enemy": _enemy.duplicate(true),
		"hand": _hand.duplicate(), "hand_limit": HAND_LIMIT, "energy": _energy, "max_energy": _max_energy,
		"turn": _turn, "balance": _balance, "goal": goal, "winner": _winner,
		"lane_count": lane_count, "opponent_id": opponent_id, "opponent_name": opponent_name,
		"enemy_deck_count": _enemy_reserve.size() if opponent_id == "older_brother" else -1,
		"enemy_fatigue": _enemy_fatigue,
		"deck_count": _deck.size(), "discard_count": _discard.size(), "fatigue": _fatigue,
		"intent": _intent.duplicate(true), "phase": "finished" if _winner != "" else "player"}


func legality_error(hand_index: int, lane: int, other_lane: int = -1) -> String:
	if _winner != "":
		return "This match is over."
	if _resolving:
		return "Wait for combat to finish."
	if hand_index < 0 or hand_index >= _hand.size():
		return "Choose a card from your hand."
	if lane < 0 or lane >= lane_count:
		return "Choose one of the %d lanes." % lane_count
	var card: Dictionary = get_card(_hand[hand_index])
	if card.is_empty():
		return "Unknown card."
	if card.cost > _energy:
		return "Not enough Attention. End your turn to refill it."
	match card.kind:
		"unit":
			if not _player[lane].is_empty():
				return "Choose an empty lane on your side."
		"damage":
			if _enemy[lane].is_empty():
				return "%s needs an enemy creature as its target." % card.name
		"heal":
			if _player[lane].is_empty():
				return "%s needs one of your creatures as its target." % card.name
			if _player[lane].hp >= _player[lane].max_hp:
				return "That creature is already at full health."
		"swap":
			if _player[lane].is_empty():
				return "Choose a friendly creature to move."
			if other_lane < 0 or other_lane >= lane_count or absi(other_lane - lane) != 1:
				return "Choose an adjacent friendly creature to swap with."
			if _player[other_lane].is_empty():
				return "Switcheroo needs two friendly creatures."
	return ""


func play_card(hand_index: int, lane: int, other_lane: int = -1) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if legality_error(hand_index, lane, other_lane) != "":
		return events
	var card: Dictionary = get_card(_hand[hand_index])
	_energy -= int(card.cost)
	_hand.remove_at(hand_index)
	match card.kind:
		"unit":
			_player[lane] = _make_unit(card.id)
			_record(events, "play", "%s enters lane %d." % [card.name, lane + 1], "player", lane, "player", lane, 0, card.id)
			if card.ability == "heal_allies":
				_heal_other_allies("player", lane, events)
		"damage":
			_discard.append(card.id)
			_enemy[lane].hp = maxi(0, int(_enemy[lane].hp) - int(card.amount))
			_record(events, "spell", "%s deals %d damage to %s." % [card.name, card.amount, _enemy[lane].name], "player", -1, "enemy", lane, card.amount, card.id)
			_remove_dead("enemy", lane, events)
		"heal":
			_discard.append(card.id)
			var restored: int = mini(int(card.amount), int(_player[lane].max_hp) - int(_player[lane].hp))
			_player[lane].hp += restored
			_record(events, "spell", "%s restores %d health." % [card.name, restored], "player", -1, "player", lane, restored, card.id)
		"swap":
			_discard.append(card.id)
			var first: Dictionary = _player[lane]
			_player[lane] = _player[other_lane]
			_player[other_lane] = first
			_record(events, "swap", "Switcheroo swaps lanes %d and %d." % [lane + 1, other_lane + 1], "player", lane, "player", other_lane, 0, card.id)
	return events


func end_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if _winner != "" or _resolving:
		return events
	_resolving = true
	Combat.phase(self, "player", events)
	if _winner == "":
		_deploy_enemy(events)
		if _winner == "":
			Combat.phase(self, "enemy", events)
	if _winner == "":
		_begin_turn(events)
	_resolving = false
	return events


func _strike(side: String, lane: int, events: Array[Dictionary]) -> void:
	Combat.strike(self, side, lane, events)


func _remove_dead(side: String, lane: int, events: Array[Dictionary]) -> void:
	var board: Array[Dictionary] = _player if side == "player" else _enemy
	if board[lane].is_empty() or int(board[lane].hp) > 0:
		return
	var id: String = board[lane].id
	var label: String = board[lane].name
	if side == "player":
		_discard.append(id)
	board[lane] = {}
	_record(events, "death", "%s is defeated." % label, side, lane, side, lane, 0, id)


func _deploy_enemy(events: Array[Dictionary]) -> void:
	if opponent_id == "older_brother" and _enemy_reserve.is_empty():
		_enemy_fatigue += 1
		_balance = mini(goal, _balance + _enemy_fatigue)
		_record(events, "fatigue", "Older Brother's reserve is empty! Fatigue deals %d direct damage." % _enemy_fatigue, "player", -1, "enemy", -1, _enemy_fatigue)
		events.back()["direct"] = true
		_check_victory(events)
		return
	if _intent.is_empty():
		return
	var lane: int = _intent.lane
	var id: String = _intent.card
	_intent = {}
	if not _enemy[lane].is_empty():
		return
	if opponent_id == "older_brother":
		if _enemy_reserve.is_empty():
			return
		_enemy_reserve.pop_front()
	_enemy[lane] = _make_unit(id, "enemy")
	_record(events, "enemy_play", "%s plays %s in lane %d." % [opponent_name, _enemy[lane].name, lane + 1], "enemy", lane, "enemy", lane, 0, id)
	if _enemy[lane].ability == "heal_allies":
		_heal_other_allies("enemy", lane, events)


func _heal_other_allies(side: String, source_lane: int, events: Array[Dictionary]) -> void:
	var board: Array[Dictionary] = _player if side == "player" else _enemy
	for lane in lane_count:
		if lane == source_lane or board[lane].is_empty() or board[lane].hp >= board[lane].max_hp:
			continue
		board[lane].hp += 1
		_record(events, "heal", "Medic restores 1 health to %s." % board[lane].name, side, source_lane, side, lane, 1, "medic")


func _begin_turn(events: Array[Dictionary]) -> void:
	_turn += 1
	_max_energy = mini(_turn + int(_settings.starting_attention) - 1, int(_settings.attention_cap))
	_energy = _max_energy
	# Planning previews show the readiness for the upcoming combat, not last turn.
	for board: Array in [_player, _enemy]:
		for unit: Dictionary in board:
			if unit.get("ability", "") == "intercept":
				unit.intercept_ready = true
	_choose_intent()
	_record(events, "turn", "Turn %d: Attention refilled." % _turn)
	if not _deck.is_empty():
		var id: String = _deck.pop_front()
		if _hand.size() >= HAND_LIMIT:
			_discard.append(id)
			_record(events, "draw", "Hand full (%d): %s goes to discard." % [HAND_LIMIT, Catalog.get_card(id).name], "player", -1, "player", -1, 0, id)
			events.back()["burned"] = true
		else:
			_hand.append(id)
			_record(events, "draw", "Drew %s." % Catalog.get_card(id).name, "player", -1, "player", -1, 0, id)
			events.back()["burned"] = false
	else:
		_fatigue += 1
		_balance = maxi(-goal, _balance - _fatigue)
		_record(events, "fatigue", "Empty deck! Fatigue deals %d direct damage." % _fatigue, "enemy", -1, "player", -1, _fatigue)
		_check_victory(events)


func _choose_intent() -> void:
	_intent = AI.choose(self)


func _make_unit(id: String, side := "player") -> Dictionary:
	var unit: Dictionary = get_card(id, side)
	_next_uid += 1
	unit["uid"] = _next_uid
	unit["hp"] = unit.health
	unit["max_hp"] = unit.health
	if unit.ability == "intercept":
		unit["intercept_ready"] = true
	return unit


func _check_victory(events: Array[Dictionary]) -> void:
	if absi(_balance) < goal:
		return
	_winner = "player" if _balance >= goal else "enemy"
	_intent = {}
	_record(events, "victory", "You win!" if _winner == "player" else opponent_name + " wins.", _winner)


func _record(events: Array[Dictionary], type: String, message: String, side: String = "", lane: int = -1,
		target_side: String = "", target_lane: int = -1, amount: int = 0, card: String = "") -> void:
	events.append({"type": type, "message": message, "side": side, "lane": lane,
		"target_side": target_side, "target_lane": target_lane, "amount": amount,
		"card": card, "state": snapshot()})
