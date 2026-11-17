extends RefCounted
## Deterministic deployment based only on public boards and the enemy reserve.
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const Encounter := preload("res://minigames/cards/match_encounter.gd")

static func choose(game: RefCounted) -> Dictionary:
	var older: bool = game.opponent_id == "older_brother"
	if older and game._enemy_reserve.is_empty():
		return {}
	var id: String = game._enemy_reserve[0] if older else Encounter.LITTLE_SEQUENCE[(game._turn - 1) % Encounter.LITTLE_SEQUENCE.size()]
	if not older and int(game.get_card(id, "enemy").cost) > mini(game._turn + 1, 3):
		id = "scout"
	var card: Dictionary = game.get_card(id, "enemy")
	var choice := -1
	var best_score := -INF
	for lane in game.lane_count:
		if not game._enemy[lane].is_empty():
			continue
		var score := -float(lane) * .1
		if not game._player[lane].is_empty():
			score += float(game._player[lane].power)
		if older:
			score += _positional_score(card, game._player, game._enemy, lane)
		if score > best_score:
			best_score = score
			choice = lane
	return {} if choice < 0 else {"card": id, "lane": choice}

static func _positional_score(card: Dictionary, player: Array, enemy: Array, lane: int) -> float:
	var score := 0.0
	if card.ability == "diagonal":
		# Interior positions offer two targets; prioritize openings, not hidden cards.
		for target in [lane - 1, lane + 1]:
			if target >= 0 and target < player.size():
				score += 2.0 if player[target].is_empty() else 1.0
	elif card.ability == "intercept":
		for target in [lane - 1, lane + 1]:
			if target >= 0 and target < enemy.size() and enemy[target].is_empty():
				score += 1.5
				if not player[target].is_empty():
					score += float(player[target].power)
	return score
