extends RefCounted
## Strict experiment input validation keeps misspelled knobs out of balance reports.
const Config := preload("res://minigames/cards/match_config.gd")
const Policies := preload("res://simulation/cards/policies.gd")

static func parse(arguments: PackedStringArray) -> Dictionary:
	var options := {"config": "res://simulation/cards/experiments.json",
		"output": "res://build/simulation/results.json", "seeds": 100, "seed_start": 0,
		"policies": ["random", "aggressive", "defensive", "tactical"],
		"max_turns": 60, "scenarios": [], "trace": ""}
	var errors: Array[String] = []
	if arguments.size() % 2 != 0:
		return {"errors": ["Options require --name value pairs."]}
	var seen := {}
	for index in range(0, arguments.size(), 2):
		var key := arguments[index].trim_prefix("--").replace("-", "_")
		var value := arguments[index + 1]
		if not arguments[index].begins_with("--") or not options.has(key):
			errors.append("Unknown option: %s" % arguments[index])
			continue
		if seen.has(key):
			errors.append("Repeated option: %s" % arguments[index])
		seen[key] = true
		if key in ["seeds", "seed_start", "max_turns"]:
			if not value.is_valid_int():
				errors.append("%s must be an integer." % arguments[index])
				continue
			options[key] = int(value)
		elif key in ["policies", "scenarios"]:
			options[key] = Array(value.split(",", true))
			if options[key].has(""):
				errors.append("%s requires nonempty comma-separated names." % arguments[index])
		else:
			options[key] = value
	if int(options.seeds) < 1 or int(options.seeds) > 10000:
		errors.append("--seeds must be between 1 and 10000.")
	if int(options.seed_start) < 0 or int(options.seed_start) > 1000000000:
		errors.append("--seed-start must be between 0 and 1000000000.")
	if int(options.max_turns) < 1 or int(options.max_turns) > 1000:
		errors.append("--max-turns must be between 1 and 1000.")
	if options.policies.is_empty():
		errors.append("At least one policy is required.")
	seen.clear()
	for policy: String in options.policies:
		if policy not in Policies.NAMES:
			errors.append("Unknown policy: %s" % policy)
		if seen.has(policy):
			errors.append("Repeated policy: %s" % policy)
		seen[policy] = true
	seen.clear()
	for scenario: String in options.scenarios:
		if seen.has(scenario):
			errors.append("Repeated selected scenario: %s" % scenario)
		seen[scenario] = true
	if str(options.output).is_empty():
		errors.append("--output cannot be empty.")
	options.errors = errors
	return options

static func read_experiments(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"errors": ["Cannot read experiment config: %s" % path]}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {"errors": ["Invalid JSON on line %d: %s" % [json.get_error_line(), json.get_error_message()]]}
	var errors: Array[String] = []
	if not json.data is Dictionary:
		return {"errors": ["Config must be an object with a scenarios array."]}
	var document: Dictionary = json.data
	for key: String in document:
		if key != "scenarios":
			errors.append("Unknown config field: %s" % key)
	if not document.get("scenarios") is Array or document.scenarios.is_empty():
		return {"errors": ["Config requires at least one scenario."]}
	var ids := {}
	for entry: Variant in document.scenarios:
		if not entry is Dictionary:
			errors.append("Every scenario must be an object.")
			continue
		var scenario: Dictionary = entry
		for key: String in scenario:
			if key not in ["id", "label", "opponent", "baseline", "overrides"]:
				errors.append("Unknown scenario field: %s" % key)
		if not scenario.get("id") is String or not str(scenario.id).is_valid_identifier():
			errors.append("Scenario id must be a nonempty identifier.")
			continue
		if ids.has(scenario.id):
			errors.append("Duplicate scenario id: %s" % scenario.id)
		ids[scenario.id] = true
		if not scenario.get("opponent") is String:
			errors.append("%s requires an opponent string." % scenario.id)
			continue
		for field: String in ["label", "baseline"]:
			if scenario.has(field) and not scenario[field] is String:
				errors.append("%s.%s must be a string." % [scenario.id, field])
		if not scenario.get("overrides", {}) is Dictionary:
			errors.append("%s.overrides must be an object." % scenario.id)
			continue
		scenario["overrides"] = scenario.get("overrides", {})
		scenario["label"] = scenario.get("label", scenario.id)
		for error: String in Config.errors(scenario.opponent, scenario.overrides):
			errors.append("%s: %s" % [scenario.id, error])
	for entry: Variant in document.scenarios:
		if entry is Dictionary and entry.has("baseline") and not ids.has(entry.baseline):
			errors.append("Unknown baseline: %s" % str(entry.baseline))
	return {"errors": errors, "config": document}
