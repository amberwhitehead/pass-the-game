extends RefCounted
## A deliberately limited bot evaluation, using the production combat resolver.
## Projects visible combat only: it cannot predict the enemy's hidden deployment.
const Combat := preload("res://minigames/cards/match_combat.gd")

class Board:
	extends RefCounted
	var _player: Array = []
	var _enemy: Array = []
	var _balance := 0
	var _winner := ""
	var goal := 12
	var lane_count := 4

	func _record(events: Array[Dictionary], type: String, _message: String, side := "", lane := -1,
			target_side := "", target_lane := -1, amount := 0, card := "") -> void:
		events.append({"type": type, "side": side, "lane": lane, "target_side": target_side,
			"target_lane": target_lane, "amount": amount, "card": card})

	func _remove_dead(side: String, lane: int, _events: Array[Dictionary]) -> void:
		var board: Array = _player if side == "player" else _enemy
		if not board[lane].is_empty() and int(board[lane].hp) <= 0:
			board[lane] = {}

	func _check_victory(_events: Array[Dictionary]) -> void:
		if absi(_balance) >= goal:
			_winner = "player" if _balance >= goal else "enemy"

static func after_action(state: Dictionary, action: Dictionary = {}) -> Dictionary:
	var result := state.duplicate(true)
	if action.is_empty():
		return result
	var card: Dictionary = state.catalog[action.card]
	var lane: int = action.lane
	result.energy -= int(card.cost)
	# This is a policy estimate, not the authoritative simulation. Real actions
	# always go through match_rules.play_card; tests keep supported effects aligned.
	match card.kind:
		"unit":
			var unit := card.duplicate(true)
			unit.uid = -100 - lane
			unit.hp = card.health
			unit.max_hp = card.health
			if card.ability == "intercept":
				unit.intercept_ready = true
			result.player[lane] = unit
			if card.ability == "heal_allies":
				for other in result.player.size():
					var ally: Dictionary = result.player[other]
					if other != lane and not ally.is_empty():
						ally.hp = mini(ally.max_hp, ally.hp + int(card.get("amount", 1)))
		"damage":
			result.enemy[lane].hp -= int(card.get("amount", 2))
			if result.enemy[lane].hp <= 0:
				result.enemy[lane] = {}
		"heal":
			var ally: Dictionary = result.player[lane]
			ally.hp = mini(ally.max_hp, ally.hp + int(card.get("amount", 2)))
		"swap":
			var unit: Dictionary = result.player[lane]
			result.player[lane] = result.player[action.other_lane]
			result.player[action.other_lane] = unit
	return result

static func combat(state: Dictionary) -> Dictionary:
	var board := Board.new()
	board._player = state.player.duplicate(true)
	board._enemy = state.enemy.duplicate(true)
	board._balance = state.balance
	board.goal = state.goal
	board.lane_count = state.lane_count
	var events: Array[Dictionary] = []
	Combat.phase(board, "player", events)
	if board._winner == "":
		Combat.phase(board, "enemy", events)
	return {"player": board._player, "enemy": board._enemy, "balance": board._balance,
		"winner": board._winner, "events": events}

static func board_value(board: Array) -> float:
	var value := 0.0
	for lane in board.size():
		var unit: Dictionary = board[lane]
		if unit.is_empty():
			continue
		var attacks := 1
		if unit.get("ability", "") == "diagonal":
			attacks = 2 if lane > 0 and lane < board.size() - 1 else 1
		value += float(unit.power) * attacks * 2.1 + float(unit.hp) * .22 + .35
		if unit.get("ability", "") == "intercept":
			for target in [lane - 1, lane + 1]:
				if target >= 0 and target < board.size() and board[target].is_empty():
					value += .6
	return value
