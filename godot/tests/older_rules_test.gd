extends "res://tests/test_suite.gd"
## Deterministic contracts for the older brother's positional combat.
const Rules := preload("res://minigames/cards/match_rules.gd")
const Combat := preload("res://minigames/cards/match_combat.gd")
const Cards := preload("res://minigames/cards/card_catalog.gd")
const Progression := preload("res://minigames/cards/deck_progression.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_opening()
	_interception()
	_diagonals()
	_swapping()
	_reserves()
	_matches()
	print("Older brother rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh(seed_value := 1) -> RefCounted:
	var game := Rules.new("older_brother")
	game.start(seed_value)
	return game

func fixture() -> RefCounted:
	var game := fresh()
	game._enemy.assign([{}, {}, {}, {}])
	return game

func phase(game: RefCounted, side := "player") -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	Combat.phase(game, side, events)
	return events

func _opening() -> void:
	var game := fresh()
	var state: Dictionary = game.snapshot()
	check(state.player.size() == 4 and state.enemy.size() == 4 and state.lane_count == 4, "Older encounter owns four lanes per side")
	check(state.hand.size() == 5 and state.hand.slice(0, 3) == ["bruiser", "forkshot", "sentinel"] and state.deck_count == 7, "Five opening cards include three core creatures from the twelve-card base deck")
	check(state.goal == 12 and state.energy == 3 and state.enemy_deck_count == 16, "Encounter tuning and finite reserve are exposed")
	check(state.enemy[3].id == "bulwark" and state.enemy[3].hp == 10, "Older brother visibly starts with an elite Bulwark in lane four")
	check(game._enemy_reserve.size() + 1 == preload("res://minigames/cards/match_encounter.gd").OLDER_RESERVE.size(), "Prepared defender is paid from the finite reserve")
	game.play_card(0, 3)
	check(game._player[3].id == "bruiser", "Fourth lane accepts legal play")
	for turn in 3:
		game._intent = {}
		game.end_turn()
		check(game._energy == mini(4 + turn, 5), "Older Attention advances to four then five")
	var before: Dictionary = game.snapshot()
	var exposed: Dictionary = game.snapshot()
	exposed.player.clear()
	exposed.intent.clear()
	check(game.snapshot() == before, "External snapshots cannot alter the older encounter")
	check(Rules.new().start().lane_count == 3, "Default encounter remains the three-lane tutorial")

func _interception() -> void:
	var game := fixture()
	game._player[0] = game._make_unit("scout")
	game._player[2] = game._make_unit("forkshot")
	game._enemy[1] = game._make_unit("sentinel")
	game._enemy[2] = game._make_unit("bruiser")
	var events := phase(game)
	check(events[0].type == "intercept" and events[0].lane == 1 and events[0].target_lane == 0, "Guard movement precedes its intercepted hit")
	check(events[0].state.enemy[0].hp == 8 and events[1].state.enemy[0].hp == 7, "Movement snapshot is after relocation but before damage")
	check(game._enemy[0].id == "sentinel" and game._enemy[1].is_empty(), "Guard remains in its new lane and leaves a real opening")
	check(game._balance == 2 and not game._enemy[0].intercept_ready, "Baited guard cannot intercept twice during a phase")
	var saved: Dictionary = events[0].state.duplicate(true)
	game._player[1] = game._make_unit("bruiser")
	events = phase(game)
	check(events[0].type == "ready", "New opposing combat phase refreshes spent guards")
	check(saved.enemy[0].hp == 8, "Later combat cannot mutate earlier animation snapshots")

	game = fixture()
	game._player[1] = game._make_unit("bruiser")
	game._enemy[0] = game._make_unit("sentinel")
	game._enemy[2] = game._make_unit("sentinel")
	var first_uid: int = game._enemy[0].uid
	events = phase(game)
	check(game._enemy[1].uid == first_uid and game._enemy[2].intercept_ready, "Two eligible Sentinels choose the leftmost consistently")
	check(events[0].side == "enemy" and events[0].target_side == "enemy", "Interception event identifies the defender's side")

	game = fixture()
	game._player[0] = game._make_unit("bruiser")
	game._enemy[3] = game._make_unit("sentinel")
	phase(game)
	check(game._balance == 2 and game._enemy[3].intercept_ready, "Sentinel cannot cross a nonadjacent gap")
	game._hand.assign(["bolt"])
	game._enemy[0] = game._make_unit("bruiser")
	game._enemy[1] = game._make_unit("sentinel")
	events = game.play_card(0, 0)
	check(events.size() == 1 and events[0].type == "spell" and game._enemy[1].intercept_ready, "Spells do not trigger interception")
	phase(game)
	check(game._enemy[1].intercept_ready, "Occupied attacked lanes do not trigger interception")

	game = fixture()
	game._enemy[3] = game._make_unit("bruiser")
	game._player[2] = game._make_unit("sentinel")
	phase(game, "enemy")
	check(game._player[3].hp == 6 and game._balance == 0, "Player guards intercept enemy attacks with the same rule")
	game._player[3].hp = 1
	events = phase(game, "enemy")
	check(game._player[3].is_empty() and events.back().type == "death", "Lethal hits remove a guard normally")
	check(game._balance == 0, "Intercepted excess damage never spills onto the score")
	game = fixture()
	game._player[1] = game._make_unit("sentinel")
	game._enemy[0] = game._make_unit("bruiser")
	game._intent = {}
	game.end_turn()
	check(game._player[0].intercept_ready, "Next planning turn exposes refreshed interception readiness")

func _diagonals() -> void:
	var game := fixture()
	game._player[1] = game._make_unit("forkshot")
	for lane in 3:
		game._enemy[lane] = game._make_unit("defender")
	var events := phase(game)
	check(events.size() == 2 and events[0].target_lane == 0 and events[1].target_lane == 2, "Interior Forkshot resolves left diagonal before right diagonal")
	check(game._enemy[0].hp == 7 and game._enemy[1].hp == 8 and game._enemy[2].hp == 7, "Forkshot bypasses the creature straight ahead")
	for lane in [0, 3]:
		game = fixture()
		game._player[lane] = game._make_unit("forkshot")
		events = phase(game)
		check(events.size() == 1 and game._balance == 1, "Edge Forkshot has one in-bounds target")
	game = fixture()
	game._enemy[2] = game._make_unit("forkshot")
	phase(game, "enemy")
	check(game._balance == -2, "Enemy diagonal direct hits move the score negatively")
	game = fixture()
	game._player[1] = game._make_unit("forkshot")
	game._balance = 11
	events = phase(game)
	check(game._winner == "player" and events.size() == 2 and events.back().type == "victory", "Victory on first diagonal cancels the second hit")

func _swapping() -> void:
	var game := fixture()
	game._hand.assign(["switcheroo"])
	game._player[0] = game._make_unit("bruiser")
	game._player[1] = game._make_unit("sentinel")
	game._player[0].hp = 2
	game._player[1].intercept_ready = false
	var before: Dictionary = game.snapshot()
	for pair in [Vector2i(0,-1), Vector2i(0,0), Vector2i(0,2), Vector2i(1,2), Vector2i(4,3)]:
		check(game.play_card(0, pair.x, pair.y).is_empty() and game.snapshot() == before, "Invalid swaps preserve hand, Attention, wounds and board")
	var events: Array = game.play_card(0, 0, 1)
	check(game._energy == 2 and game._hand.is_empty() and game._discard == ["switcheroo"], "Legal swap spends exactly one card and one Attention")
	check(game._player[1].uid == before.player[0].uid and game._player[1].hp == 2, "Swap preserves creature identity and damage")
	check(not game._player[0].intercept_ready, "Swapping does not refresh an interception")
	check(events.size() == 1 and events[0].type == "swap" and events[0].state.player == game._player, "Swap event contains the atomic completed board exchange")

func _reserves() -> void:
	var game := fresh()
	var announced: Dictionary = game._intent.duplicate()
	game.play_card(0, 0)
	check(game._intent == announced, "Enemy does not retarget its published plan after a player action")
	var events: Array[Dictionary] = []
	game._enemy[announced.lane] = game._make_unit("sentinel")
	game._deploy_enemy(events)
	check(events.is_empty() and game._enemy_reserve.size() == 16 and game._enemy_fatigue == 0, "Blocked deployment neither discards reserve cards nor causes fatigue")
	game._enemy[announced.lane] = {}
	game._intent = announced
	game._deploy_enemy(events)
	check(game._enemy_reserve.size() == 15 and game._enemy[announced.lane].id == announced.card, "Actual deployment consumes exactly the announced reserve card")
	game._enemy_reserve.assign(["bruiser"])
	game._enemy.assign([{}, {}, {}, {}])
	game._choose_intent()
	events = []
	game._deploy_enemy(events)
	check(game._enemy_reserve.is_empty() and game._enemy_fatigue == 0, "Last card deploys before exhaustion begins")
	game._choose_intent()
	check(game._intent.is_empty(), "Exhausted reserve cannot manufacture another deployment")
	game._balance = 0
	game._deploy_enemy(events)
	check(game._balance == 1 and game._enemy_fatigue == 1 and events.back().target_side == "enemy", "First missed enemy reserve draw causes one positive fatigue damage")
	game._deploy_enemy(events)
	check(game._balance == 3 and game._enemy_fatigue == 2, "Enemy fatigue escalates symmetrically")
	game._balance = 11
	game._deploy_enemy(events)
	check(game._winner == "player" and events.back().type == "victory", "Exhausting the enemy reserve can win through fatigue")
	game = fixture()
	game._enemy_reserve.assign(["forkshot"])
	game._choose_intent()
	check(game._intent.lane in [1, 2], "Forkshot deployment prefers an interior lane with two targets")
	var plan: Dictionary = game._intent.duplicate()
	game._hand.assign(["defender", "patch"])
	game._choose_intent()
	check(game._intent == plan, "Enemy placement does not inspect hidden player hand contents")

func _matches() -> void:
	var idle := fresh()
	for turn in 40:
		if idle._winner != "":
			break
		idle.end_turn()
	check(idle._winner == "enemy", "Passing every turn still loses")
	for seed_value in 4:
		var first := simulate(seed_value)
		check(first == simulate(seed_value), "Older match repeats deterministically for seed %d" % seed_value)
		check(first.winner != "", "Older match terminates for seed %d" % seed_value)

	for seed_value in 4:
		var upgraded := simulate(seed_value, true)
		check(upgraded.winner != "", "Collected-deck match terminates for seed %d" % seed_value)
		check(upgraded == simulate(seed_value, true), "Collected deck repeats deterministically for seed %d" % seed_value)

func simulate(seed_value: int, upgraded := false) -> Dictionary:
	var game := fresh(seed_value)
	if upgraded:
		game = Rules.new("older_brother", {"collected_cards": Progression.COLLECTIBLES})
		game.start(seed_value)
	for turn in 50:
		if game._winner != "":
			break
		for action in 12:
			var state: Dictionary = game.snapshot()
			var choice := Vector2i(-1, -1)
			var best := -INF
			for index in state.hand.size():
				var card := Cards.get_card(state.hand[index])
				for lane in 4:
					if game.legality_error(index, lane) != "":
						continue
					var score: float = float(card.power) * 3 + float(card.health) * .25
					var foe: Dictionary = state.enemy[lane]
					if card.kind == "damage":
						score = 15 if foe.hp <= 2 and foe.power > 0 else 1
					elif card.kind == "heal":
						score = 5 if state.player[lane].hp <= 3 else .5
					elif card.ability == "diagonal":
						score += 4 if lane in [1,2] else 0
					elif card.ability == "intercept":
						score += 3 if lane in [1,2] else 0
					elif foe.is_empty():
						score += float(card.power) * 2
					if score > best:
						best = score
						choice = Vector2i(index, lane)
			if choice.x < 0:
				break
			game.play_card(choice.x, choice.y)
		game.end_turn()
	return game.snapshot()
