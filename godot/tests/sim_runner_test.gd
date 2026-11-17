extends SceneTree
const Runner := preload("res://simulation/cards/run.gd")
const Metrics := preload("res://simulation/cards/metrics.gd")
const Options := preload("res://simulation/cards/run_options.gd")
const Rules := preload("res://minigames/cards/match_rules.gd")
const Policies := preload("res://simulation/cards/policies.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_determinism_and_records()
	_telemetry_fixture()
	_options()
	_configs()
	_trace_selection()
	print("Simulation runner: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _determinism_and_records() -> void:
	var scenario := {"id": "fixture", "opponent": "older_brother", "overrides": {}}
	for policy: String in Policies.NAMES:
		var first := Runner.simulate(scenario, policy, 19, 60, true)
		check(first == Runner.simulate(scenario, policy, 19, 60, true), "%s match and trace are exactly deterministic" % policy)
		check(first.match.winner in ["player", "enemy"] and first.match.turns <= 60,
			"%s completes within the turn bound" % policy)
		check(_redacted(first.trace), "%s trace never reveals intent.card" % policy)
		var plays := 0
		for row: Dictionary in first.match.cards.values(): plays += int(row.played)
		check(plays == first.match.counters.actions, "%s per-card plays sum to the action total" % policy)
		var trace_actions := 0
		var spent := 0
		var state: Dictionary = first.trace.initial
		for turn: Dictionary in first.trace.turns:
			for action: Dictionary in turn.actions:
				trace_actions += 1
				var after: Dictionary = action.events.back().state
				spent += int(state.energy) - int(after.energy)
				state = after
			if not turn.combat.is_empty(): state = turn.combat.back().state
		check(trace_actions == plays and spent == first.match.counters.attention_available - first.match.counters.attention_unused,
			"%s recorded action count and Attention agree with the actual trace" % policy)
		check(first.match.timeline.size() == first.trace.turns.size(), "%s metrics and replay have the same number of resolved turns" % policy)
	var bounded := Runner.simulate(scenario, "passive", 19, 1, true)
	check(bounded.match.winner == "timeout" and bounded.match.turns == 1 and bounded.trace.turns.size() == 1,
		"Turn cap produces an explicit timeout after exactly one resolved turn")
	check(not Runner.simulate(scenario, "passive", 19, 1).has("trace"), "Unrequested traces are omitted")

func _redacted(value: Variant) -> bool:
	if value is Dictionary:
		if value.has("intent") and value.intent.has("card"): return false
		for child: Variant in value.values():
			if not _redacted(child): return false
	elif value is Array:
		for child: Variant in value:
			if not _redacted(child): return false
	return true

func _telemetry_fixture() -> void:
	var game := Rules.new("older_brother")
	game.start(9)
	game._player[0] = game._make_unit("bruiser")
	game._player[0].hp = 3
	game._enemy.assign([{}, {}, {}, {}])
	game._enemy[0] = game._make_unit("scout", "enemy")
	game._enemy[1] = game._make_unit("sentinel", "enemy")
	game._enemy[3] = game._make_unit("bruiser", "enemy")
	var scout_uid: int = game._enemy[0].uid
	var sentinel_uid: int = game._enemy[1].uid
	game._hand.assign(["bolt", "patch", "switcheroo"])
	game._energy = 5
	game._intent = {} # Isolate the existing boards from deployments.
	var metrics := Metrics.new()
	metrics.start(game.snapshot())
	metrics.begin_turn(game.snapshot(), Policies.legal_actions(game))
	metrics.played("patch")
	metrics.consume(game.play_card(1, 0))
	metrics.note_choices(game.snapshot(), Policies.legal_actions(game))
	metrics.played("bolt")
	metrics.consume(game.play_card(0, 0))
	var before: Dictionary = game.snapshot()
	var events: Array = game.end_turn()
	metrics.consume(events)
	metrics.end_turn(before, events, game.snapshot())
	var result := metrics.result(game.snapshot())
	var c: Dictionary = result.counters
	check(c.actions == 2 and c.attention_available == 5 and c.attention_unused == 3, "Telemetry conserves two spent Attention and two played cards")
	check(c.player_spells_damage == 2 and c.player_healing == 2, "Telemetry records actual spell damage and restored health")
	check(c.enemy_intercepts == 1 and c.enemy_intercepted_damage == 2 and c.player_unit_hits == 1,
		"Interception and the subsequent hit are counted once")
	check(c.enemy_direct_damage == 2 and c.player_direct_damage == 0, "Direct damage is separated by attacking side")
	var scout: Dictionary = metrics.units[scout_uid]
	check(scout.hits_taken == 1 and scout.damage_taken == 2 and scout.death_turn == 1, "Spell kill records one hit, real lost health and a death turn")
	var sentinel: Dictionary = metrics.units[sentinel_uid]
	check(sentinel.hits_taken == 1 and sentinel.damage_taken == 2 and sentinel.death_turn == -1,
		"Survivor is censored rather than falsely counted as dead at the observation boundary")
	check(result.units.all(func(unit: Dictionary) -> bool: return unit.turns_in_play == 1), "Single-turn observations give survivors and casualties one observed turn")
	check(result.cards.patch.played == 1 and result.cards.bolt.played == 1 and result.cards.switcheroo.played == 0,
		"Per-card telemetry distinguishes played from merely held cards")

func _options() -> void:
	check(Options.parse([]).errors.is_empty(), "Default CLI options validate")
	for args: Array in [["--seeds"], ["--seeds", "0"], ["--seeds", "eleven"], ["--seeds", "10001"],
			["--seed-start", "-1"], ["--max-turns", "0"], ["--policies", "oracle"],
			["--policies", "tactical,tactical"], ["--policies", ""], ["--output", ""],
			["--policies", "random,,tactical"], ["--scenarios", ""], ["--scenarios", "older_baseline,older_baseline"],
			["--unknown", "1"], ["--seeds", "1", "--seeds", "2"]]:
		check(not Options.parse(PackedStringArray(args)).errors.is_empty(), "Malformed CLI args fail: %s" % str(args))
	var valid := Options.parse(["--seeds", "7", "--seed-start", "42", "--policies", "random,tactical", "--max-turns", "20"])
	check(valid.errors.is_empty() and valid.seeds == 7 and valid.seed_start == 42 and valid.policies == ["random", "tactical"],
		"Valid options preserve explicit sampling and policy selections")

func _config_document(document: Variant) -> Dictionary:
	var path := OS.get_user_data_dir().path_join("cards_sim_runner_config_fixture.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()
	var loaded := Options.read_experiments(path)
	DirAccess.remove_absolute(path)
	return loaded

func _configs() -> void:
	check(Options.read_experiments("res://simulation/cards/experiments.json").errors.is_empty(), "Bundled experiment suite validates")
	check(not Options.read_experiments(OS.get_user_data_dir().path_join("cards_sim_missing_config_fixture.json")).errors.is_empty(), "Missing config fails with an error")
	for document: Variant in [[], {}, {"scenarios": []}, {"scenarios": ["bad"]},
			{"scenarios": [{"id": "test", "opponent": "unknown"}]},
			{"scenarios": [{"id": "test", "opponent": "older_brother", "overrides": {"gaol": 20}}]},
			{"scenarios": [{"id": "test", "opponent": "older_brother", "baseline": "missing"}]},
			{"scenarios": [{"id": "test", "opponent": "older_brother"}, {"id": "test", "opponent": "older_brother"}]}]:
		check(not _config_document(document).errors.is_empty(), "Malformed experiment config fails: %s" % str(document))
	var valid := _config_document({"scenarios": [{"id": "test", "opponent": "older_brother"}]})
	check(valid.errors.is_empty() and valid.config.scenarios[0].overrides == {}, "Omitted overrides normalize to an empty dictionary")

func _trace_selection() -> void:
	var scenarios: Array[Dictionary] = [{"id": "baseline", "opponent": "older_brother"}]
	var options := {"trace": "baseline:tactical:42", "policies": ["tactical"], "seed_start": 42, "seeds": 3}
	check(Runner._trace_is_selected(options, scenarios), "Trace selection accepts the inclusive seed start")
	options.trace = "baseline:tactical:44"
	check(Runner._trace_is_selected(options, scenarios), "Trace selection accepts the last included seed")
	for key: String in ["missing:tactical:42", "baseline:random:42", "baseline:tactical:41", "baseline:tactical:45",
			"baseline:tactical:not_a_seed", "baseline:tactical", "baseline:tactical:42:extra"]:
		options.trace = key
		check(not Runner._trace_is_selected(options, scenarios), "Invalid or unselected trace fails: %s" % key)
