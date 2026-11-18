extends "res://tests/test_suite.gd"
const Rules := preload("res://minigames/cards/match_rules.gd")
const Combat := preload("res://minigames/cards/match_combat.gd")
const Policies := preload("res://simulation/cards/policies.gd")
const Preview := preload("res://simulation/cards/public_preview.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_observation_boundary()
	_actions()
	_previews()
	_tuned_previews()
	_decisions()
	_matches()
	print("Simulation policies: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh() -> RefCounted:
	var game := Rules.new("older_brother")
	game.start(17)
	return game

func _observation_boundary() -> void:
	var game := fresh()
	var first := Policies.observation(game)
	check(first.intent.has("lane") and not first.intent.has("card"), "Observation exposes the glow lane but never its hidden card")
	check(not first.has("deck") and not first.has("reserve") and not first.has("_settings"), "Observation excludes private deck order and settings")
	game._intent.card = "heavy"
	game._deck.reverse()
	game._enemy_reserve.reverse()
	check(Policies.observation(game) == first, "Changing every hidden future leaves observations identical")
	var before: Dictionary = game.snapshot()
	first.enemy[3].hp = 1
	first.hand.clear()
	first.catalog.bruiser.power = 99
	check(game.snapshot() == before and game.get_card("bruiser").power == 2, "Policies cannot mutate the game through observations")

func _actions() -> void:
	var game := fresh()
	game._player[0] = game._make_unit("bruiser")
	game._player[1] = game._make_unit("sentinel")
	game._player[2] = game._make_unit("forkshot")
	game._hand.assign(["switcheroo", "patch", "bolt", "defender"])
	game._player[0].hp = 3
	var actions := Policies.legal_actions(game)
	var swaps := 0
	for action: Dictionary in actions:
		check(game.legality_error(action.hand_index, action.lane, action.other_lane) == "", "Every enumerated action is legal in the real rules")
		if action.card == "switcheroo":
			swaps += 1
			check(action.other_lane == action.lane + 1, "Swap enumeration uses one canonical direction")
	check(swaps == 2, "Three neighboring allies have exactly two distinct swaps")
	check(actions.size() == 5, "Enumeration includes heal, damage and the only empty unit slot")

func normalized(board: Array) -> Array:
	var copy := board.duplicate(true)
	for unit: Dictionary in copy:
		unit.erase("uid")
	return copy

func _previews() -> void:
	for id: String in ["forkshot", "sentinel", "medic", "bolt", "patch", "switcheroo"]:
		var game := fresh()
		game._energy = 10
		game._player[0] = game._make_unit("bruiser")
		game._player[0].hp = 3
		game._player[1] = game._make_unit("sentinel")
		game._enemy[1] = game._make_unit("sentinel", "enemy")
		game._enemy[2] = game._make_unit("forkshot", "enemy")
		game._hand.assign([id])
		var actions := Policies.legal_actions(game)
		check(not actions.is_empty(), "%s fixture has a legal move" % id)
		var action: Dictionary = actions[0]
		var before: Dictionary = game.snapshot()
		var projected := Preview.combat(Preview.after_action(Policies.observation(game), action))
		check(game.snapshot() == before, "Previewing %s leaves the authoritative game untouched" % id)
		game.play_card(action.hand_index, action.lane, action.other_lane)
		var events: Array[Dictionary] = []
		Combat.phase(game, "player", events)
		if game._winner == "":
			Combat.phase(game, "enemy", events)
		check(normalized(projected.player) == normalized(game._player), "%s preview matches player public combat" % id)
		check(normalized(projected.enemy) == normalized(game._enemy) and projected.balance == game._balance, "%s preview matches enemy public combat" % id)

func _decisions() -> void:
	var game := fresh()
	game._player[0] = game._make_unit("bruiser")
	game._enemy.assign([{}, {}, {}, {}])
	game._enemy[0] = game._make_unit("scout", "enemy")
	game._balance = 10
	game._hand.assign(["bolt", "sentinel"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var choice := Policies.choose(Policies.observation(game), Policies.legal_actions(game), rng, "tactical")
	check(choice.get("card", "") == "bolt" and choice.lane == 0, "Tactical player recognizes a spell that opens immediate lethal")
	game._enemy.assign([{}, {}, {}, {}])
	game._player[1] = game._make_unit("bruiser")
	game._hand.assign(["switcheroo"])
	choice = Policies.choose(Policies.observation(game), Policies.legal_actions(game), rng, "tactical")
	check(choice.is_empty(), "Tactical player saves a swap with no positional benefit")
	for policy: String in Policies.NAMES:
		var state := Policies.observation(game)
		var actions := Policies.legal_actions(game)
		rng.seed = 991
		var first := Policies.choose(state, actions, rng, policy)
		game._intent.card = "patch"
		game._deck.reverse()
		rng.seed = 991
		var second := Policies.choose(Policies.observation(game), actions, rng, policy)
		check(first == second, "%s decisions cannot depend on hidden future information" % policy)

func _tuned_previews() -> void:
	var game := Rules.new("older_brother", {"cards": {"bolt": {"amount": 4}, "patch": {"amount": 5},
		"bruiser": {"power": 3, "health": 9}}, "enemy_cards": {"bulwark": {"power": 4, "health": 12}}})
	game.start(17)
	game._player[0] = game._make_unit("bruiser")
	game._player[0].hp = 1
	game._hand.assign(["patch", "bolt"])
	var state := Policies.observation(game)
	var healed := Preview.after_action(state, {"hand_index": 0, "lane": 0, "other_lane": -1, "card": "patch"})
	check(healed.player[0].hp == 6, "Public preview uses the tuned healing amount")
	var damaged := Preview.after_action(state, {"hand_index": 1, "lane": 3, "other_lane": -1, "card": "bolt"})
	check(damaged.enemy[3].hp == 8, "Public preview applies four damage to the tuned twelve-health Bulwark")
	check(state.player[0].power == 3 and state.player[0].max_hp == 9 and state.enemy[3].power == 4 and state.enemy[3].max_hp == 12,
		"Observed creatures retain their actual side-specific tuning")

func run_match(policy: String) -> Dictionary:
	var game := fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1009
	var history: Array = []
	for turn in 60:
		if game._winner != "": break
		for step in 16:
			var action := Policies.choose(Policies.observation(game), Policies.legal_actions(game), rng, policy)
			if action.is_empty(): break
			var events: Array = game.play_card(action.hand_index, action.lane, action.other_lane)
			if events.is_empty():
				return {"error": "Illegal policy action"}
			history.append(action)
		game.end_turn()
	return {"winner": game._winner, "turn": game._turn, "balance": game._balance, "actions": history}

func _matches() -> void:
	for policy: String in Policies.NAMES:
		var first := run_match(policy)
		check(not first.has("error") and first.get("winner", "") != "", "%s completes a legal full match" % policy)
		check(first == run_match(policy), "%s repeats the exact same action history for the same seeds" % policy)
	check(run_match("passive").winner == "enemy", "Passive control loses without playing a card")
