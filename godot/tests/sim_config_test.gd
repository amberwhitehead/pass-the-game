extends SceneTree
const Rules := preload("res://minigames/cards/match_rules.gd")
const Config := preload("res://minigames/cards/match_config.gd")
const Catalog := preload("res://minigames/cards/card_catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	for id in ["little_brother", "older_brother"]:
		check(Config.errors(id, {}).is_empty(), "Default encounter validates")
		check(Rules.new(id).start(17) == Rules.new(id, {}).start(17), "No-override snapshots identical")
	for overrides in [
		{"typo": 2}, {"goal": 0}, {"goal": 1.5}, {"goal": "12"}, {"goal": true},
		{"lanes": 2}, {"opening_hand": 9}, {"fixed_opening": -1}, {"fixed_opening": 6},
		{"fixed_opening": 1.5}, {"fixed_opening": "3"}, {"fixed_opening": true}, {"deck": ["unknown"]}, {"deck": "bruiser"},
		{"starting_attention": 8}, {"reserve": ["bolt"]}, {"opening_lanes": [4]},
		{"opening_lanes": [1, 1]}, {"opening_lanes": [1.5]}, {"reserve": []},
		{"cards": []}, {"cards": {"nope": {"cost": 1}}}, {"cards": {"bolt": {"health": 1}}},
		{"cards": {"scout": {"health": 0}}}, {"cards": {"scout": {"power": -1}}},
		{"cards": {"scout": {"damage": 1}}}, {"cards": {"scout": {"ability": "unknown"}}},
		{"cards": {"bolt": {"ability": "intercept"}}}, {"enemy_cards": {"bolt": {"amount": 3}}},
		{"cards": {"scout": {"amount": 3}}}, {"cards": {"scout": {"power": true}}},
	]:
		check(not Config.errors("older_brother", overrides).is_empty(), "Reject malformed tuning %s" % overrides)
	check(not Config.errors("typo", {}).is_empty(), "Unknown encounter rejected")
	check(not Config.errors("little_brother", {"reserve": []}).is_empty(), "Ignored tutorial reserve override rejected")
	var overrides := {"goal": 18, "starting_attention": 2, "attention_cap": 4,
		"opening_lanes": [0], "cards": {"bruiser": {"cost": 1, "health": 10}, "bolt": {"amount": 3}},
		"enemy_cards": {"bruiser": {"power": 4}, "bulwark": {"health": 12}}}
	check(Config.errors("older_brother", overrides).is_empty(), "Valid experiment accepted")
	var game := Rules.new("older_brother", overrides)
	var state: Dictionary = game.start(1)
	check(state.goal == 18 and state.energy == 2 and state.enemy[0].hp == 12, "Tuning controls actual opening")
	game.play_card(0, 0)
	check(game._player[0].hp == 10 and game._player[0].power == 2 and game._energy == 1, "Player uses tuned stats and cost")
	game._hand.assign(["bolt"])
	game.play_card(0, 0)
	check(game._enemy[0].hp == 9, "Spell amount uses actual rules")
	check(game._make_unit("bruiser", "enemy").power == 4, "Enemy-only tuning applied")
	check(game.get_card("bruiser").power == 2, "Enemy tuning cannot leak onto player")
	check(Catalog.get_card("bruiser").health == 6, "Global catalog stays immutable")
	overrides.cards.bruiser.health = 1
	check(game.get_card("bruiser").health == 10, "Caller config mutations cannot change a running game")
	var exposed: Dictionary = game.get_card("bruiser")
	exposed.health = 1
	check(game.get_card("bruiser").health == 10, "Returned cards cannot mutate match tuning")
	check(Rules.new("older_brother").start(1).enemy[3].hp == 10, "Next match preserves the shipped Bulwark health")
	var ablated := Rules.new("older_brother", {"player_cards": {"sentinel": {"ability": ""}}})
	check(ablated.get_card("sentinel").ability == "", "Player-only ability ablation applies")
	check(ablated.get_card("sentinel", "enemy").ability == "intercept", "Player-only ablation leaves enemy unchanged")
	game._hand.assign(["patch"])
	game._energy = 1
	game._player[0].hp = 7
	game.play_card(0, 0)
	check(game._player[0].hp == 9, "Default patch still heals two")
	check(Config.errors("older_brother", {"fixed_opening": 0}).is_empty(), "A fully random opening can be configured explicitly")
	var fixed := Rules.new("older_brother", {"fixed_opening": 5})
	check(fixed.start(17).hand == Catalog.older_deck().slice(0, 5), "A fully fixed opening preserves the requested deck prefix")
	check(Config.errors("older_brother", {"opening_hand": 2, "fixed_opening": 2}).is_empty(), "Explicit smaller fixed openings validate consistently")
	print("Simulation config: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
