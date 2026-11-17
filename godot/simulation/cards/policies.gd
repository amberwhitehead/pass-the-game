extends RefCounted
## Deterministic, imperfect test players. None can see future draws or card intent.
const Preview := preload("res://simulation/cards/public_preview.gd")
const NAMES := ["random", "aggressive", "defensive", "tactical", "passive"]
const DESCRIPTIONS := {
	"random": "Uniform legal action; 12% chance to end before each play.",
	"aggressive": "Favors power and exposed lanes; spends playable cards freely.",
	"defensive": "Favors survival, healing and coverage of visible enemy attacks.",
	"tactical": "One-action public combat estimate; no hidden deployment or draw search.",
	"passive": "Always ends turn. A negative control, not a player model.",
}

static func observation(game: RefCounted) -> Dictionary:
	var state: Dictionary = game.snapshot()
	# Whitelist observable fields instead of depending on future snapshots keeping
	# private state out. In particular, intent.card is deliberately never copied.
	var visible := {}
	for key in ["player", "enemy", "hand", "hand_limit", "energy", "max_energy", "turn",
			"balance", "goal", "winner", "lane_count", "opponent_id", "opponent_name",
			"enemy_deck_count", "enemy_fatigue", "deck_count", "discard_count", "fatigue", "phase"]:
		visible[key] = state[key]
	visible.intent = {} if state.intent.is_empty() else {"lane": int(state.intent.lane)}
	visible.catalog = {}
	for id: String in state.hand:
		visible.catalog[id] = game.get_card(id)
	return visible

static func legal_actions(game: RefCounted) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var state: Dictionary = game.snapshot()
	for index in state.hand.size():
		var id: String = state.hand[index]
		var card: Dictionary = game.get_card(id)
		for lane in state.lane_count:
			if card.kind == "swap":
				# One canonical direction per adjacent pair; reverse is the same move.
				if game.legality_error(index, lane, lane + 1) == "":
					actions.append({"hand_index": index, "lane": lane, "other_lane": lane + 1, "card": id})
			elif game.legality_error(index, lane) == "":
				actions.append({"hand_index": index, "lane": lane, "other_lane": -1, "card": id})
	return actions

static func choose(state: Dictionary, actions: Array, rng: RandomNumberGenerator, policy: String) -> Dictionary:
	if policy == "passive" or actions.is_empty() or state.winner != "":
		return {}
	if policy == "random":
		return {} if rng.randf() < .12 else actions[rng.randi_range(0, actions.size() - 1)]
	var baseline := Preview.combat(state) if policy == "tactical" else {}
	var best_score := 0.0
	var best: Dictionary = {}
	for action: Dictionary in actions:
		var card: Dictionary = state.catalog[action.card]
		var score := 0.0
		match policy:
			"aggressive": score = _aggressive(state, action, card)
			"defensive": score = _defensive(state, action, card)
			"tactical": score = _tactical(state, action, card, baseline)
		if score > best_score + .00001:
			best_score = score
			best = action
	return best

static func _aggressive(state: Dictionary, action: Dictionary, card: Dictionary) -> float:
	var lane: int = action.lane
	match card.kind:
		"unit":
			var power := float(card.power)
			var score := power * 3 + float(card.health) * .18
			var targets: Array = [lane]
			if card.ability == "diagonal":
				targets = [lane - 1, lane + 1]
			for target: int in targets:
				if target >= 0 and target < state.lane_count:
					score += power * (2.3 if state.enemy[target].is_empty() else .8)
			return score
		"damage":
			var foe: Dictionary = state.enemy[lane]
			return 9.0 + foe.power if foe.hp <= int(card.get("amount", 2)) else 1.0
		"heal": return .5 + float(state.player[lane].power) * .3
		"swap": return _position_gain(state, action) - .3
	return 0.0

static func _defensive(state: Dictionary, action: Dictionary, card: Dictionary) -> float:
	var lane: int = action.lane
	var incoming := _threats(state)
	match card.kind:
		"unit":
			var score := float(card.health) * .4 + float(card.power) + incoming[lane] * 2.0
			if card.ability == "intercept":
				for target in [lane - 1, lane + 1]:
					if target >= 0 and target < state.lane_count and state.player[target].is_empty():
						score += incoming[target] * 1.5
			return score
		"damage":
			var foe: Dictionary = state.enemy[lane]
			return 8.0 + foe.power * 2 if foe.hp <= int(card.get("amount", 2)) else 1.0
		"heal":
			var ally: Dictionary = state.player[lane]
			return minf(card.get("amount", 2), ally.max_hp - ally.hp) * .5 + (6.0 if incoming[lane] >= ally.hp else 0.0)
		"swap": return _position_gain(state, action) - .3
	return 0.0

static func _tactical(state: Dictionary, action: Dictionary, card: Dictionary, baseline: Dictionary) -> float:
	var after := Preview.after_action(state, action)
	var projected := Preview.combat(after)
	var score := _evaluation(projected) - _evaluation(baseline)
	# Save cards that produce no useful change. Spells and swaps have an opportunity
	# cost, so two inverse swaps cannot both be chosen just to consume the hand.
	score -= .35 + float(card.cost) * .12
	if card.kind == "unit":
		# The announced lane is public. Treat an imminent (unknown) arrival as risk.
		if state.intent.get("lane", -1) == action.lane:
			score -= float(card.power) * .25
	return score

static func _evaluation(projected: Dictionary) -> float:
	var score := float(projected.balance) * 2.5
	score += Preview.board_value(projected.player) - Preview.board_value(projected.enemy)
	if projected.winner == "player": score += 1000.0
	if projected.winner == "enemy": score -= 1000.0
	return score

static func _position_gain(state: Dictionary, action: Dictionary) -> float:
	return _evaluation(Preview.combat(Preview.after_action(state, action))) - _evaluation(Preview.combat(state))

static func _threats(state: Dictionary) -> Array[float]:
	var threats: Array[float] = []
	threats.resize(state.lane_count)
	threats.fill(0.0)
	for lane in state.lane_count:
		var foe: Dictionary = state.enemy[lane]
		if foe.is_empty():
			continue
		var targets: Array = [lane - 1, lane + 1] if foe.ability == "diagonal" else [lane]
		for target: int in targets:
			if target >= 0 and target < state.lane_count:
				threats[target] += float(foe.power)
	return threats
