extends RefCounted
## Observational telemetry. Decisions and resolution remain in the live rules engine.

var counters := {
	"attention_available": 0, "attention_unused": 0, "turns_no_legal_actions": 0,
	"full_board_turns": 0, "overflow": 0, "player_direct_damage": 0,
	"enemy_direct_damage": 0, "player_unit_hits": 0, "enemy_unit_hits": 0,
	"player_intercepts": 0, "enemy_intercepts": 0,
	"player_intercepted_damage": 0, "enemy_intercepted_damage": 0,
	"swaps": 0, "enemy_deployments": 0, "blocked_deployments": 0,
	"player_fatigue_damage": 0, "enemy_fatigue_damage": 0, "lead_changes": 0,
	"player_spells_damage": 0, "player_healing": 0, "actions": 0,
}
var cards: Dictionary = {}
var units: Dictionary = {}
var timeline: Array[Dictionary] = []
var _active: Dictionary = {}
var _intercepted: Dictionary = {}
var _held: Dictionary = {}
var _legal: Dictionary = {}
var _round: Dictionary = {}
var _lead := 0
var _min_balance := 0
var _max_balance := 0

func start(state: Dictionary) -> void:
	for id: String in state.hand:
		_card(id).drawn += 1
	_observe_units(state, true)
	_observe_balance(state.balance)

func begin_turn(state: Dictionary, actions: Array) -> void:
	_held.clear()
	_legal.clear()
	var occupied := _occupied(state.player)
	_round = {"turn": state.turn, "balance_before": state.balance,
		"attention_available": state.energy, "attention_unused": 0,
		"legal_actions": actions.size(), "plays": 0, "player_occupied": occupied,
		"enemy_occupied": _occupied(state.enemy), "hand_size": state.hand.size()}
	counters.attention_available += int(state.energy)
	if actions.is_empty():
		counters.turns_no_legal_actions += 1
	if occupied == int(state.lane_count):
		counters.full_board_turns += 1
	note_choices(state, actions)

func note_choices(state: Dictionary, actions: Array) -> void:
	for id: String in state.hand:
		_held[id] = true
	for action: Dictionary in actions:
		_legal[action.card] = true

func played(id: String) -> void:
	_card(id).played += 1
	counters.actions += 1
	_round.plays += 1

func consume(events: Array) -> void:
	for event: Dictionary in events:
		var state: Dictionary = event.state
		var side: String = event.get("side", "")
		var target_side: String = event.get("target_side", "")
		var amount := int(event.get("amount", 0))
		match event.type:
			"draw":
				if event.get("burned", false):
					counters.overflow += 1
					_card(event.card).burned += 1
				else:
					_card(event.card).drawn += 1
			"enemy_play":
				counters.enemy_deployments += 1
			"intercept":
				counters[side + "_intercepts"] += 1
				var guard: Dictionary = state[side][event.target_lane]
				_intercepted[int(guard.uid)] = side
			"attack":
				if event.get("direct", false):
					counters[side + "_direct_damage"] += amount
				else:
					counters[side + "_unit_hits"] += 1
					var target: Dictionary = state[target_side][event.target_lane]
					var uid := int(target.uid)
					if units.has(uid):
						units[uid].hits_taken += 1
					if _intercepted.has(uid):
						counters[target_side + "_intercepted_damage"] += amount
						_intercepted.erase(uid)
			"spell":
				if target_side == "enemy":
					counters.player_spells_damage += amount
					var target: Dictionary = state.enemy[event.target_lane]
					if units.has(int(target.uid)):
						units[int(target.uid)].hits_taken += 1
				else:
					counters.player_healing += amount
			"heal":
				if target_side == "player":
					counters.player_healing += amount
			"swap":
				counters.swaps += 1
			"fatigue":
				counters[target_side + "_fatigue_damage"] += amount
		_observe_units(state)
		_observe_balance(state.balance)

func end_turn(before_combat: Dictionary, events: Array, after: Dictionary) -> void:
	_round.attention_unused = before_combat.energy
	counters.attention_unused += int(before_combat.energy)
	# A published lane can become occupied by interception before deployment.
	# Count only a turn that reached deployment (not a player-phase victory).
	if not before_combat.intent.is_empty() and int(before_combat.enemy_deck_count) != 0:
		var reached_deployment: bool = after.winner == "" or after.winner == "enemy"
		var deployed := false
		for event: Dictionary in events:
			if event.type == "enemy_play":
				deployed = true
			if event.type == "attack" and event.side == "enemy":
				reached_deployment = true
		if reached_deployment and not deployed:
			counters.blocked_deployments += 1
	_round.balance_after = after.balance
	timeline.append(_round.duplicate(true))
	for id: String in _held:
		_card(id).held_turns += 1
	for id: String in _legal:
		_card(id).legal_turns += 1

func result(state: Dictionary) -> Dictionary:
	var unit_rows: Array[Dictionary] = []
	for uid: int in units:
		var row: Dictionary = units[uid].duplicate(true)
		var last_round := int(row.death_turn) if int(row.death_turn) >= 0 else int(timeline.back().turn if not timeline.is_empty() else state.turn)
		row.turns_in_play = maxi(1, last_round - int(row.entered_turn) + 1)
		unit_rows.append(row)
	return {"winner": state.winner if state.winner != "" else "timeout",
		"turns": timeline.size(), "final_turn": state.turn, "final_balance": state.balance,
		"goal": state.goal, "min_balance": _min_balance, "max_balance": _max_balance,
		"comeback_win": state.winner == "player" and _min_balance < 0,
		"counters": counters, "cards": cards, "units": unit_rows, "timeline": timeline}

func _card(id: String) -> Dictionary:
	if not cards.has(id):
		cards[id] = {"drawn": 0, "played": 0, "legal_turns": 0, "held_turns": 0, "burned": 0}
	return cards[id]

func _observe_units(state: Dictionary, opening := false) -> void:
	var present: Dictionary = {}
	for side: String in ["player", "enemy"]:
		for unit: Dictionary in state[side]:
			if unit.is_empty():
				continue
			var uid := int(unit.uid)
			present[uid] = int(unit.hp)
			if not units.has(uid):
				units[uid] = {"uid": uid, "id": unit.id, "side": side,
					"entered_turn": state.turn, "death_turn": -1, "opening": opening,
					"hits_taken": 0, "damage_taken": 0}
			elif _active.has(uid):
				units[uid].damage_taken += maxi(0, int(_active[uid]) - int(unit.hp))
	for uid: int in _active:
		if not present.has(uid):
			units[uid].death_turn = state.turn
	_active = present

func _observe_balance(balance: int) -> void:
	_min_balance = mini(_min_balance, balance)
	_max_balance = maxi(_max_balance, balance)
	var lead := signi(balance)
	if lead != 0:
		if _lead != 0 and lead != _lead:
			counters.lead_changes += 1
		_lead = lead

func _occupied(board: Array) -> int:
	var result := 0
	for unit: Dictionary in board:
		result += 0 if unit.is_empty() else 1
	return result
