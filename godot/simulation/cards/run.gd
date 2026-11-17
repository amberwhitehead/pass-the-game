extends SceneTree
## Batch experiments run the same Rules, AI and Combat used at the actual table.
const Rules := preload("res://minigames/cards/match_rules.gd")
const Policies := preload("res://simulation/cards/policies.gd")
const Metrics := preload("res://simulation/cards/metrics.gd")
const Options := preload("res://simulation/cards/run_options.gd")
const Config := preload("res://minigames/cards/match_config.gd")
const Catalog := preload("res://minigames/cards/card_catalog.gd")

func _initialize() -> void:
	var options := Options.parse(OS.get_cmdline_user_args())
	if _failed(options.errors):
		return
	var loaded := Options.read_experiments(options.config)
	if _failed(loaded.errors):
		return
	var config: Dictionary = loaded.config
	var selected: Array[Dictionary] = []
	for scenario: Dictionary in config.scenarios:
		if options.scenarios.is_empty() or scenario.id in options.scenarios:
			selected.append(scenario)
	for id: String in options.scenarios:
		if not selected.any(func(scenario: Dictionary) -> bool: return scenario.id == id):
			_failed(["Unknown selected scenario: %s" % id])
			return
	if not str(options.trace).is_empty() and not _trace_is_selected(options, selected):
		_failed(["--trace must be scenario:policy:seed within the selected run."])
		return
	var began := Time.get_ticks_msec()
	var matches: Array[Dictionary] = []
	var traces: Array[Dictionary] = []
	var resolved_scenarios := {}
	for scenario: Dictionary in selected:
		var settings := Config.resolve(scenario.opponent, scenario.overrides)
		var definitions := {"player": {}, "enemy": {}}
		for side: String in definitions:
			for id: String in Catalog.CARDS:
				definitions[side][id] = Config.card(settings, id, side)
		resolved_scenarios[scenario.id] = {"settings": settings, "cards": definitions}
		for policy: String in options.policies:
			var wins := 0
			for seed_value in range(int(options.seed_start), int(options.seed_start) + int(options.seeds)):
				var trace_key := "%s:%s:%d" % [scenario.id, policy, seed_value]
				var result := simulate(scenario, policy, seed_value, int(options.max_turns), options.trace == trace_key)
				if result.has("error"):
					_failed([result.error])
					return
				matches.append(result.match)
				wins += 1 if result.match.winner == "player" else 0
				if result.has("trace"):
					traces.append(result.trace)
			print("%s / %s: %d / %d player wins" % [scenario.id, policy, wins, options.seeds])
	var report := {"schema_version": 1, "config": config, "resolved_scenarios": resolved_scenarios,
		"metadata": {"seed_start": options.seed_start, "seed_count": options.seeds,
			"godot_version": Engine.get_version_info().string,
			"max_turns": options.max_turns, "policies": options.policies,
			"elapsed_seconds": (Time.get_ticks_msec() - began) / 1000.0,
			"generated_utc": Time.get_datetime_string_from_system(true),
			"total_matches": matches.size()}, "matches": matches, "traces": traces}
	var destination := ProjectSettings.globalize_path(options.output)
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK:
		_failed(["Cannot create output directory: %s" % destination.get_base_dir()])
		return
	var output := FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		_failed(["Cannot write output: %s" % destination])
		return
	output.store_string(JSON.stringify(report))
	output.close()
	print("Wrote %d matches to %s in %.2fs" % [matches.size(), destination, report.metadata.elapsed_seconds])
	quit(0)

static func simulate(scenario: Dictionary, policy: String, seed_value: int, max_turns: int, with_trace := false) -> Dictionary:
	var game := Rules.new(scenario.opponent, scenario.get("overrides", {}))
	var state: Dictionary = game.start(seed_value)
	var metrics := Metrics.new()
	metrics.start(state)
	var rng := RandomNumberGenerator.new()
	# Policy randomness has its own RNG: choices never perturb shuffled game draws.
	rng.seed = seed_value
	var trace := {"scenario": scenario.id, "policy": policy, "seed": seed_value,
		"initial": public_snapshot(state), "turns": []}
	for round_index in max_turns:
		if state.winner != "":
			break
		var actions: Array = Policies.legal_actions(game)
		metrics.begin_turn(state, actions)
		var trace_turn := {"turn": state.turn, "actions": [], "combat": []}
		# Every play consumes a card, even at zero cost; the hand bounds action count.
		var action_limit: int = state.hand.size()
		for action_index in action_limit + 1:
			var observation: Dictionary = Policies.observation(game)
			actions = Policies.legal_actions(game)
			metrics.note_choices(observation, actions)
			var chosen: Dictionary = Policies.choose(observation, actions, rng, policy)
			if chosen.is_empty():
				break
			if action_index == action_limit or not actions.has(chosen):
				return {"error": "Policy %s returned an illegal or unbounded action at seed %d." % [policy, seed_value]}
			var events: Array = game.play_card(int(chosen.hand_index), int(chosen.lane), int(chosen.other_lane))
			if events.is_empty():
				return {"error": "Accepted action produced no rules events at seed %d." % seed_value}
			metrics.played(chosen.card)
			metrics.consume(events)
			if with_trace:
				trace_turn.actions.append({"choice": chosen.duplicate(true), "events": public_events(events)})
		var before_combat: Dictionary = game.snapshot()
		var combat_events: Array = game.end_turn()
		metrics.consume(combat_events)
		state = game.snapshot()
		metrics.end_turn(before_combat, combat_events, state)
		if with_trace:
			trace_turn.combat = public_events(combat_events)
			trace.turns.append(trace_turn)
	var row := metrics.result(state)
	row["scenario"] = scenario.id
	row["policy"] = policy
	row["seed"] = seed_value
	var result := {"match": row}
	if with_trace:
		result["trace"] = trace
	return result

static func public_snapshot(state: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	result.intent.erase("card")
	return result

static func public_events(events: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		var copy := event.duplicate(true)
		copy.state = public_snapshot(event.state)
		result.append(copy)
	return result

static func _trace_is_selected(options: Dictionary, scenarios: Array[Dictionary]) -> bool:
	var parts: PackedStringArray = str(options.trace).split(":")
	if parts.size() != 3 or not parts[2].is_valid_int():
		return false
	var seed_value := int(parts[2])
	return scenarios.any(func(scenario: Dictionary) -> bool: return scenario.id == parts[0]) \
		and parts[1] in options.policies and seed_value >= int(options.seed_start) \
		and seed_value < int(options.seed_start) + int(options.seeds)

func _failed(errors: Array) -> bool:
	if errors.is_empty():
		return false
	for error: String in errors:
		push_error(error)
	quit(1)
	return true
