extends SceneTree
## Discoveries shuffle into a compact deck without growing the opening hand.
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const Progression := preload("res://minigames/cards/deck_progression.gd")
const Config := preload("res://minigames/cards/match_config.gd")
const Rules := preload("res://minigames/cards/match_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var base_counts := counts(Catalog.older_deck())
	var base := Rules.new("older_brother")
	var base_state: Dictionary = base.start(537)
	check(Catalog.older_deck().size() == 12, "The base deck contains twelve cards")
	check(base_state.hand.size() == 5 and base_state.hand.slice(0, 3) == Progression.CORE_HAND, "Five-card opening includes three core creatures")
	check(base_state.deck_count == 7, "Base deal leaves seven cards to draw")
	for mask in 32:
		var found: Array[String] = []
		for bit in Progression.COLLECTIBLES.size():
			if mask & (1 << bit):
				found.append(Progression.COLLECTIBLES[bit])
		var overrides := {"collected_cards": found.duplicate()}
		check(Config.errors("older_brother", overrides).is_empty(), "Every collectible subset is valid")
		var deck := Progression.build(found)
		check(deck.size() == 12 + found.size(), "Each found card increases total deck size")
		var actual := counts(deck)
		for id: String in base_counts:
			check(actual[id] == base_counts[id], "Base copies are conserved for subset %d / %s" % [mask, id])
		for id: String in Progression.COLLECTIBLES:
			check(actual.get(id, 0) == (1 if id in found else 0), "Only discovered unique rewards enter deck")
		var game := Rules.new("older_brother", overrides)
		var state: Dictionary = game.start(537)
		check(state.hand.size() == 5 and state.hand.size() <= state.hand_limit, "Every collection keeps a five-card opening")
		check(state.hand.slice(0, 3) == Progression.CORE_HAND, "Discoveries never displace core creatures")
		check(state.deck_count == 7 + found.size(), "Discoveries increase the shuffled draw supply")
		check(counts(game._hand + game._deck) == actual, "Dealing neither loses nor duplicates any card")
		var repeated := Rules.new("older_brother", overrides)
		check(repeated.start(537) == state and repeated._deck == game._deck, "The same seed repeats both opening and future draws")
		found.reverse()
		check(Progression.build(found) == deck, "Discovery order cannot alter loadout composition/order")
		overrides.collected_cards.clear()
		check(game.snapshot() == state, "Caller collection changes cannot mutate a running duel")
		check(state.winner == "", "Collecting all cards never auto-wins a duel")
	for invalid in [
		{"collected_cards": "champion"}, {"collected_cards": ["bolt"]},
		{"collected_cards": ["champion", "champion"]},
		{"collected_cards": [], "deck": Catalog.older_deck()},
		{"collected_cards": [], "opening_hand": 5},
		{"collected_cards": [], "fixed_opening": 3},
	]:
		check(not Config.errors("older_brother", invalid).is_empty(), "Ambiguous or invalid collection is rejected")
	check(not Config.errors("little_brother", {"collected_cards": []}).is_empty(), "Tutorial never inherits progression")
	var little: Dictionary = Rules.new().start(537)
	check(little.hand == ["scout", "striker", "guard", "bolt"] and little.deck_count == 12, "Tutorial opening/deck unchanged")
	_shuffled_openings()
	_normal_draw()
	_spell("thunderbolt", "enemy")
	_spell("renewal", "player")
	print("Card progression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _shuffled_openings() -> void:
	var seen_opening := {}
	var seen_later := {}
	var variants := {}
	for seed_value in 128:
		var game := Rules.new("older_brother", {"collected_cards": Progression.COLLECTIBLES})
		var state: Dictionary = game.start(seed_value)
		variants[str(state.hand)] = true
		for id: String in Progression.COLLECTIBLES:
			if id in state.hand:
				seen_opening[id] = true
			if id in game._deck:
				seen_later[id] = true
	check(variants.size() > 1, "Different seeds produce different random opening slots")
	for id: String in Progression.COLLECTIBLES:
		check(seen_opening.has(id), "%s can naturally appear in the opening" % id)
		check(seen_later.has(id), "%s is not guaranteed in the opening" % id)

func _normal_draw() -> void:
	var game := Rules.new("older_brother", {"collected_cards": Progression.COLLECTIBLES})
	var state: Dictionary = game.start(537)
	var next_card: String = game._deck[0]
	game._enemy.assign([{}, {}, {}, {}])
	game._intent = {}
	var events: Array = game.end_turn()
	var draws: Array = events.filter(func(event: Dictionary) -> bool: return event.type == "draw")
	check(draws.size() == 1 and draws[0].card == next_card and not draws[0].burned, "Normal next turn draws exactly the next shuffled card")
	check(game._hand.size() == 6 and game._deck.size() == state.deck_count - 1, "Opening random draws do not skip the normal next-turn draw")
	check(game._turn == 2 and game._energy == 4, "Dealing the opening never advances turns or Attention")

func _spell(id: String, side: String) -> void:
	var game := Rules.new("older_brother")
	game.start(1)
	game._hand.assign([id])
	game._energy = 5
	var unit: Dictionary = game._make_unit("champion")
	unit.hp = 1 if side == "player" else unit.max_hp
	var before: int = unit.hp
	if side == "player": game._player[0] = unit
	else: game._enemy[0] = unit
	var events: Array = game.play_card(0, 0)
	var amount: int = Catalog.get_card(id).amount
	check(events[0].type == "spell" and events[0].card == id, "Reward spell emits its own identity")
	check(Catalog.get_card(id).name in events[0].message, "Combat journal names the actual reward")
	check(events[0].state[side][0].hp == (mini(unit.max_hp, before + amount) if side == "player" else maxi(0, before - amount)), "Printed reward magnitude matches real resolution")
	check(game._energy == 5 - Catalog.get_card(id).cost, "Reward costs its printed Attention")

func counts(deck: Array) -> Dictionary:
	var result := {}
	for id: String in deck:
		result[id] = int(result.get(id, 0)) + 1
	return result

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
