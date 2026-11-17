extends SceneTree
## Run: godot --headless --path godot --script res://tests/cards_test.gd
## Pure rules tests; no scenes, graphics, or input devices required.

const Rules := preload("res://minigames/cards/match_rules.gd")
const Cards := preload("res://minigames/cards/card_catalog.gd")
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_opening_and_legality()
	_test_spells_and_medic()
	_test_combat_and_intent()
	_test_turns_and_fatigue()
	_test_hand_limit()
	_test_complete_matches()
	print("Card rules: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _fresh(seed_value := 1) -> RefCounted:
	var game := Rules.new()
	game.start(seed_value)
	return game


func _fixture(hand: Array[String] = []) -> RefCounted:
	var game := _fresh()
	game._hand = hand.duplicate()
	game._energy = 4
	game._max_energy = 4
	game._intent = {}
	return game


func _test_opening_and_legality() -> void:
	var game := _fresh(42)
	var initial: Dictionary = game.snapshot()
	_expect(initial.hand == ["scout", "striker", "guard", "bolt"], "Opening hand is curated")
	_expect(initial.energy == 2 and initial.max_energy == 2, "Opening energy is two")
	_expect(initial.intent.card == "guard" and initial.intent.lane == 1, "First enemy intent teaches center blocking")
	_expect(initial == _fresh(42).snapshot(), "Same seed yields the same opening state")
	var exposed: Dictionary = game.snapshot()
	exposed.hand.clear()
	exposed.intent.card = "heavy"
	_expect(game.snapshot() == initial, "Snapshots do not expose mutable engine state")
	_expect(game.play_card(-1, 0).is_empty(), "Negative hand index is rejected")
	_expect(game.play_card(99, 0).is_empty(), "Out-of-range hand index is rejected")
	_expect(game.play_card(0, -1).is_empty(), "Negative lane is rejected")
	_expect(game.play_card(0, 3).is_empty(), "Out-of-range lane is rejected")
	_expect(game.play_card(3, 0).is_empty(), "Damage spell needs an enemy target")
	_expect(game.snapshot() == initial, "Illegal actions leave the whole match unchanged")
	var events: Array = game.play_card(0, 0)
	var after: Dictionary = game.snapshot()
	_expect(not events.is_empty(), "Legal play generates animation events")
	_expect(after.energy == 1 and after.hand.size() == 3, "Scout costs one energy and one card")
	_expect(after.player[0].id == "scout", "Unit enters the chosen lane")
	_expect(not game.legality_error(0, 2).is_empty(), "Unaffordable card explains why it cannot be played")
	_expect(game.play_card(0, 2).is_empty(), "Unaffordable card cannot be played")
	_expect(game.play_card(1, 0).is_empty(), "An occupied friendly lane rejects another unit")
	_expect(game.snapshot() == after, "Rejected plays preserve resources and board")
	_expect(events.back().has("state"), "Events include a post-action snapshot")
	if events.back().has("state"):
		var saved: Dictionary = events.back().state.duplicate(true)
		game.play_card(1, 2)
		_expect(events.back().state == saved, "Animation event snapshots remain immutable after later plays")


func _test_spells_and_medic() -> void:
	var game := _fixture(["bolt", "patch", "medic"])
	game._enemy[0] = game._make_unit("scout")
	game.play_card(0, 0)
	_expect(game.snapshot().enemy[0].is_empty(), "Two-damage bolt removes a two-health enemy")
	_expect(game.snapshot().energy == 3, "Bolt spends one energy")
	var prior: Dictionary = game.snapshot()
	_expect(game.play_card(0, 1).is_empty(), "Patch cannot target an empty lane")
	_expect(game.snapshot() == prior, "Invalid healing consumes nothing")
	game._player[0] = game._make_unit("heavy")
	prior = game.snapshot()
	_expect(game.play_card(0, 0).is_empty(), "Patch cannot be wasted on a healthy unit")
	_expect(game.snapshot() == prior, "Healthy-target rejection preserves state")
	game._player[0].hp = game._player[0].max_hp - 1
	game.play_card(0, 0)
	_expect(game.snapshot().player[0].hp == game.snapshot().player[0].max_hp, "Patch clamps healing at maximum health")
	game._player[0].hp = 1
	game.play_card(0, 1)
	_expect(game.snapshot().player[0].hp == 2, "Medic heals other allies by one on entry")
	_expect(game.snapshot().player[1].hp == 3, "Medic enters at its normal full health")
	_expect(game.snapshot().energy == 0, "Spells and medic pay their full combined cost")


func _test_combat_and_intent() -> void:
	var game := _fixture()
	game._player[0] = game._make_unit("heavy")
	game._enemy[0] = game._make_unit("scout")
	var events: Array = game.end_turn()
	_expect(game.snapshot().balance == 0, "Blocked attacks do not spill excess damage onto the scale")
	_expect(game.snapshot().enemy[0].is_empty(), "Player attack removes a defeated defender")
	_expect(game.snapshot().player[0].hp == 4, "A destroyed enemy does not retaliate later in the round")
	_expect(not events.is_empty(), "Combat supplies animation events")

	game = _fresh()
	var intended: Dictionary = game.snapshot().intent.duplicate(true)
	game.play_card(0, 0)
	_expect(game.snapshot().intent == intended, "Enemy intent remains fixed during the player's turn")
	game.end_turn()
	_expect(game.snapshot().enemy[intended.lane].id == intended.card, "Enemy deploys the exact announced card and lane")
	_expect(game.snapshot().balance == 1, "A newly played scout attacks on that turn")

	game = _fixture()
	game._balance = Rules.WIN_BALANCE - 1
	game._player[0] = game._make_unit("scout")
	game._enemy[2] = game._make_unit("heavy")
	game.end_turn()
	var won: Dictionary = game.snapshot()
	_expect(won.winner == "player", "Direct damage at the positive threshold wins immediately")
	_expect(won.balance >= Rules.WIN_BALANCE, "Enemy attack cannot undo an already completed victory")
	_expect(game.end_turn().is_empty() and game.play_card(0, 0).is_empty(), "Finished games reject further actions")
	_expect(game.snapshot() == won, "Finished state remains unchanged")

	game = _fixture()
	game._balance = -Rules.WIN_BALANCE + 1
	game._enemy[0] = game._make_unit("scout")
	game.end_turn()
	_expect(game.snapshot().winner == "enemy", "Direct enemy damage at the negative threshold loses")


func _test_turns_and_fatigue() -> void:
	var game := _fixture()
	game._max_energy = 2
	game._energy = 0
	var count: int = game.snapshot().deck_count
	game.end_turn()
	_expect(game.snapshot().energy == 3 and game.snapshot().max_energy == 3, "Second turn replenishes three energy")
	_expect(game.snapshot().deck_count == count - 1 and game.snapshot().hand.size() == 1, "New turn draws exactly one card")
	game._intent = {}
	game.end_turn()
	_expect(game.snapshot().energy == 4 and game.snapshot().max_energy == 4, "Energy grows to four")
	game._intent = {}
	game.end_turn()
	_expect(game.snapshot().max_energy == 4, "Energy cap remains four")

	game = _fixture()
	game._deck.clear()
	game.end_turn()
	_expect(game.snapshot().fatigue == 1 and game.snapshot().balance == -1, "First missed draw deals one fatigue damage")
	game._intent = {}
	game.end_turn()
	_expect(game.snapshot().fatigue == 2 and game.snapshot().balance == -3, "Subsequent fatigue damage escalates")
	game._intent = {}
	game.end_turn()
	game._intent = {}
	game.end_turn()
	_expect(game.snapshot().winner == "enemy", "Deck exhaustion eventually resolves stalled games")


func _test_hand_limit() -> void:
	var game := _fixture(["scout", "scout", "guard", "guard", "patch", "patch", "bolt", "bolt"])
	var before: Dictionary = game.snapshot()
	var burned_id: String = game._deck[0]
	var events: Array = game.end_turn()
	var after: Dictionary = game.snapshot()
	_expect(after.hand == before.hand and after.hand.size() == 8, "Drawing at the hand limit preserves the existing eight cards")
	_expect(after.deck_count == before.deck_count - 1, "Overflow still consumes the drawn deck card")
	_expect(after.discard_count == before.discard_count + 1 and game._discard.back() == burned_id, "Overflow card goes to discard exactly once")
	_expect(after.fatigue == 0 and after.balance == 0, "Overflow is not deck exhaustion or direct damage")
	var burns := 0
	for event: Dictionary in events:
		if event.get("burned", false):
			burns += 1
			_expect(event.card == burned_id and not event.message.is_empty(), "Overflow event identifies the lost card and explains it")
	_expect(burns == 1, "One overflow draw emits one clear burn event")

	game = _fixture(["scout", "scout", "guard", "guard", "patch", "patch", "bolt"])
	var drawn_id: String = game._deck[0]
	game.end_turn()
	_expect(game.snapshot().hand.size() == 8 and game.snapshot().hand.back() == drawn_id, "A seventh-card hand draws normally up to the limit")
	_expect(game.snapshot().discard_count == 0, "Normal draw at the boundary does not discard")


func _test_complete_matches() -> void:
	var idle := _fresh()
	for round_index in 30:
		if idle.snapshot().winner != "":
			break
		idle.end_turn()
	_expect(idle.snapshot().winner == "enemy", "Passing every turn loses to the younger brother")
	var wins := 0
	for seed_value in 12:
		var first: Dictionary = _simulate(seed_value)
		var repeat: Dictionary = _simulate(seed_value)
		_expect(first == repeat, "Match is reproducible for seed %d" % seed_value)
		_expect(first.winner != "", "Match finishes for seed %d" % seed_value)
		if first.winner == "player":
			wins += 1
	_expect(wins > 0, "A straightforward starter-deck strategy can win")
	print("Starter heuristic wins: %d / 12 seeds" % wins)


func _simulate(seed_value: int) -> Dictionary:
	var game := _fresh(seed_value)
	for round_index in 40:
		if game.snapshot().winner != "":
			break
		for action_index in 12:
			var state: Dictionary = game.snapshot()
			var best_score := -INF
			var choice := Vector2i(-1, -1)
			for index in state.hand.size():
				var card: Dictionary = Cards.get_card(state.hand[index])
				for lane in 3:
					if game.legality_error(index, lane) != "":
						continue
					var score: float = _play_score(card, state, lane)
					if score > best_score:
						best_score = score
						choice = Vector2i(index, lane)
			if choice.x < 0:
				break
			game.play_card(choice.x, choice.y)
		game.end_turn()
	return game.snapshot()


func _play_score(card: Dictionary, state: Dictionary, lane: int) -> float:
	var foe: Dictionary = state.enemy[lane]
	if card.kind == "damage":
		return 12.0 if foe.hp <= 2 and foe.power > 0 else 2.0
	if card.kind == "heal":
		return 4.0
	var score: float = card.power * 3.0 + card.health * 0.3 - card.cost * 0.2
	if foe.is_empty():
		score += card.power * 2.0
	elif card.power == 0:
		score += foe.power * 2.0
	return score
