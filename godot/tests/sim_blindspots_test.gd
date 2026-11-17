extends SceneTree
## Executable design probes. These lock down observed tradeoffs, not target balance.
const Rules := preload("res://minigames/cards/match_rules.gd")
const Combat := preload("res://minigames/cards/match_combat.gd")
const Policies := preload("res://simulation/cards/policies.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_interception_cancels_deployment()
	_full_board_interception()
	_opening_tempo()
	_mirror_asymmetry()
	_swap_gain()
	_defensive_lock()
	print("Simulation blindspot probes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh() -> RefCounted:
	var game := Rules.new("older_brother")
	game.start(23)
	return game

func empty() -> RefCounted:
	var game := fresh()
	game._enemy.assign([{}, {}, {}, {}])
	return game

func phase(game: RefCounted) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	Combat.phase(game, "player", events)
	return events

func count_type(events: Array, type: String) -> int:
	var count := 0
	for event: Dictionary in events:
		if event.type == type: count += 1
	return count

func _interception_cancels_deployment() -> void:
	var game := empty()
	game._enemy[1] = game._make_unit("sentinel", "enemy")
	game._player[0] = game._make_unit("bruiser")
	game._enemy_reserve.assign(["bruiser", "forkshot"])
	game._choose_intent()
	check(game._intent.lane == 0, "AI announces the open lane opposing the visible attacker")
	var reserve_before: Array = game._enemy_reserve.duplicate()
	var events: Array = game.end_turn()
	check(count_type(events, "intercept") == 1 and game._enemy[0].id == "sentinel", "Actual combat moves Sentinel into the announced deployment lane")
	check(count_type(events, "enemy_play") == 0 and game._enemy_reserve == reserve_before,
		"Occupied announcement cancels this deployment without consuming a reserve card")
	check(game._enemy[1].is_empty() and game._enemy_fatigue == 0, "AI waits despite an available alternate lane and does not fatigue")
	print("Probe: interception can cancel one enemy deployment despite free lanes.")

func _full_board_interception() -> void:
	var game := empty()
	for lane in 4:
		game._enemy[lane] = game._make_unit("defender", "enemy")
		game._player[lane] = game._make_unit("defender")
	game._enemy[1] = game._make_unit("sentinel", "enemy")
	game._player[2] = game._make_unit("forkshot")
	var sentinel_uid: int = game._enemy[1].uid
	var events := phase(game)
	check(count_type(events, "intercept") == 0, "A durable full board gives Sentinel no interception opportunity")
	check(game._enemy[1].uid == sentinel_uid and game._enemy[1].intercept_ready,
		"Sentinel remains ready in its original lane after occupied-lane hits")
	check(game._balance == 0 and game._enemy[1].hp < 8, "Sentinel still absorbs normal damage while its signature ability is inactive")

func _opening_tempo() -> void:
	var game := fresh()
	var announced: int = game._intent.lane
	check(game._enemy[announced].is_empty(), "Announced opening lane begins empty")
	game.play_card(0, announced) # The fixed first card is Bruiser.
	var events: Array = game.end_turn()
	var attack_index := -1
	var deployment_index := -1
	for index in events.size():
		var event: Dictionary = events[index]
		if event.type == "attack" and event.side == "player" and attack_index < 0:
			attack_index = index
			check(event.get("direct", false) and event.amount == 2, "New player creature attacks directly before the announced blocker arrives")
		if event.type == "enemy_play":
			deployment_index = index
			check(event.lane == announced, "Enemy still honors the original glowing lane")
	check(attack_index >= 0 and deployment_index > attack_index, "Player combat precedes enemy deployment in the actual turn pipeline")
	print("Probe: opening Bruiser deals 2 direct damage through the announced arrival lane.")

func _mirror_asymmetry() -> void:
	var original := empty()
	original._player[0] = original._make_unit("bruiser")
	original._player[2] = original._make_unit("forkshot")
	original._enemy[1] = original._make_unit("sentinel", "enemy")
	phase(original)
	var mirrored := empty()
	mirrored._player[3] = mirrored._make_unit("bruiser")
	mirrored._player[1] = mirrored._make_unit("forkshot")
	mirrored._enemy[2] = mirrored._make_unit("sentinel", "enemy")
	phase(mirrored)
	check(original._balance == 2 and mirrored._balance == 1,
		"Mirroring the board changes direct damage because attack and diagonal order are left-to-right")
	check(original._enemy[0].hp == 6 and mirrored._enemy[3].hp == 5,
		"Mirror asymmetry reallocates one hit between the balance and the Sentinel")
	var priority := empty()
	priority._player[1] = priority._make_unit("bruiser")
	priority._enemy[0] = priority._make_unit("sentinel", "enemy")
	priority._enemy[2] = priority._make_unit("sentinel", "enemy")
	var left_uid: int = priority._enemy[0].uid
	phase(priority)
	check(priority._enemy[1].uid == left_uid and priority._enemy[2].intercept_ready,
		"Two eligible Sentinels consume the left guard's readiness first")
	print("Probe: mirrored Bruiser/Forkshot versus Sentinel deals 2 versus 1 direct damage.")

func _swap_gain() -> void:
	var baseline := empty()
	baseline._player[0] = baseline._make_unit("forkshot")
	baseline._player[1] = baseline._make_unit("bruiser")
	phase(baseline)
	var moved := empty()
	moved._player[0] = moved._make_unit("forkshot")
	moved._player[1] = moved._make_unit("bruiser")
	moved._hand.assign(["switcheroo"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var choice := Policies.choose(Policies.observation(moved), Policies.legal_actions(moved), rng, "tactical")
	check(choice.get("card", "") == "switcheroo", "Tactical policy recognizes a real positive-value reposition")
	var energy: int = moved._energy
	moved.play_card(0, 0, 1)
	phase(moved)
	check(baseline._balance == 3 and moved._balance == 4, "Moving Forkshot from edge to interior adds exactly one direct hit")
	check(moved._energy == energy - 1 and moved._discard == ["switcheroo"], "The extra attack costs one Attention and one spell")

func _defensive_lock() -> void:
	var game := empty()
	for lane in 4:
		game._player[lane] = game._make_unit("sentinel")
		game._enemy[lane] = game._make_unit("sentinel", "enemy")
	game._hand.assign(["bruiser", "forkshot"])
	game._energy = 5
	game._deck.clear()
	game._choose_intent()
	check(Policies.legal_actions(game).is_empty(), "All-defense full board makes held attackers unplayable despite spare Attention")
	var reserve: int = game._enemy_reserve.size()
	var events: Array = game.end_turn()
	check(count_type(events, "attack") == 0 and count_type(events, "intercept") == 0,
		"Full Sentinel boards create a combat stall with no ability activation")
	for turn in 10:
		if game._winner != "": break
		game.end_turn()
	check(game._winner == "enemy" and game._enemy_reserve.size() == reserve and game._enemy_fatigue == 0,
		"Player draw fatigue breaks the lock while enemy reserve fatigue never starts on its full board")
	print("Probe: a full defensive lock loses to player fatigue; blocked enemy reserves do not exhaust.")
