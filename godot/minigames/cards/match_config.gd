extends RefCounted
## Validated, match-local tuning. Empty overrides preserve the shipped encounters.
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const Encounter := preload("res://minigames/cards/match_encounter.gd")
const Progression := preload("res://minigames/cards/deck_progression.gd")
const FIELDS := ["goal", "lanes", "starting_attention", "attention_cap", "opening_hand", "fixed_opening",
	"deck", "reserve", "opening_lanes", "cards", "player_cards", "enemy_cards", "collected_cards"]
const CARD_FIELDS := ["cost", "power", "health", "ability", "amount"]
const ABILITIES := ["", "intercept", "diagonal", "heal_allies"]


static func errors(id: String, overrides: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if id not in ["little_brother", "older_brother"]:
		problems.append("Unknown opponent: %s" % id)
	for key: String in overrides:
		if key not in FIELDS:
			problems.append("Unknown setting: %s" % key)
	var settings := Encounter.settings(id)
	settings.merge(overrides, true)
	for key: String in ["goal", "lanes", "starting_attention", "attention_cap", "opening_hand"]:
		if not _integer(settings[key]) or float(settings[key]) < 1 or float(settings[key]) > 100:
			problems.append("%s must be an integer in 1..100" % key)
	if not problems.is_empty():
		return problems
	if int(settings.lanes) not in [3, 4]:
		problems.append("lanes must be 3 or 4")
	if int(settings.starting_attention) > int(settings.attention_cap):
		problems.append("starting_attention must not exceed attention_cap")
	if int(settings.opening_hand) > 8:
		problems.append("opening_hand must not exceed the hand limit (8)")
	if not _integer(settings.fixed_opening) or float(settings.fixed_opening) < 0 or float(settings.fixed_opening) > int(settings.opening_hand):
		problems.append("fixed_opening must be an integer in 0..opening_hand")
	for key: String in ["deck", "reserve"]:
		if not settings[key] is Array:
			problems.append("%s must be a list of card IDs" % key)
			continue
		if settings[key].size() > 200:
			problems.append("%s may contain at most 200 cards" % key)
		for card_id: Variant in settings[key]:
			if not card_id is String or not Catalog.CARDS.has(card_id):
				problems.append("Unknown card in %s: %s" % [key, str(card_id)])
			elif key == "reserve" and Catalog.CARDS[card_id].kind != "unit":
				problems.append("Enemy reserve only supports creatures: %s" % card_id)
	if settings.deck is Array and settings.deck.size() < int(settings.opening_hand):
		problems.append("deck must contain at least opening_hand cards")
	if not settings.opening_lanes is Array:
		problems.append("opening_lanes must be a list of unique lane indices")
	else:
		var seen := {}
		for lane: Variant in settings.opening_lanes:
			if not _integer(lane) or int(lane) < 0 or int(lane) >= int(settings.lanes):
				problems.append("Opening lane out of bounds: %s" % str(lane))
			elif seen.has(int(lane)):
				problems.append("Opening lanes must be unique")
			else:
				seen[int(lane)] = true
		if settings.reserve is Array and settings.opening_lanes.size() > settings.reserve.size():
			problems.append("reserve must supply every opening creature")
	if id == "little_brother" and (overrides.has("reserve") or overrides.has("opening_lanes")):
		problems.append("Little Brother uses his repeating sequence; reserve/opening_lanes overrides require Older Brother")
	if overrides.has("collected_cards"):
		if id != "older_brother" or overrides.has("deck") or overrides.has("opening_hand") or overrides.has("fixed_opening"):
			problems.append("collected_cards derives Older Brother's deck and opening; do not override deck, opening_hand, or fixed_opening together")
		if not overrides.collected_cards is Array:
			problems.append("collected_cards must be a list of unique collectible IDs")
		else:
			var seen_cards := {}
			for card_id: Variant in overrides.collected_cards:
				if not card_id is String or card_id not in Progression.all_collectible():
					problems.append("Unknown collectible: %s" % str(card_id))
				elif seen_cards.has(card_id):
					problems.append("Collectibles cannot be duplicated")
				seen_cards[card_id] = true
	for scope: String in ["cards", "player_cards", "enemy_cards"]:
		if overrides.has(scope):
			_validate_cards(overrides[scope], scope, problems)
	return problems


static func resolve(id: String, overrides: Dictionary) -> Dictionary:
	var settings := Encounter.settings(id).duplicate(true)
	settings.merge(overrides.duplicate(true), true)
	if settings.has("collected_cards"):
		settings.deck = Progression.build(settings.collected_cards)
		settings.opening_hand = Progression.OPENING_HAND
		settings.fixed_opening = Progression.CORE_HAND.size()
	return settings


static func card(settings: Dictionary, id: String, side := "player") -> Dictionary:
	var result := Catalog.get_card(id)
	if result.is_empty():
		return result
	if result.kind in ["damage", "heal"]:
		result["amount"] = result.get("amount", 2)
	result.merge(settings.get("cards", {}).get(id, {}), true)
	result.merge(settings.get("enemy_cards" if side == "enemy" else "player_cards", {}).get(id, {}), true)
	return result


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))


static func _validate_cards(value: Variant, scope: String, problems: Array[String]) -> void:
	if not value is Dictionary:
		problems.append("%s must map card IDs to stat overrides" % scope)
		return
	for id: String in value:
		if not Catalog.CARDS.has(id) or not value[id] is Dictionary:
			problems.append("Invalid card override: %s.%s" % [scope, id])
			continue
		var base: Dictionary = Catalog.CARDS[id]
		for key: String in value[id]:
			var item: Variant = value[id][key]
			var path := "%s.%s.%s" % [scope, id, key]
			if key not in CARD_FIELDS:
				problems.append("Unknown card stat: %s" % path)
			elif key == "ability":
				if not item is String or item not in ABILITIES or base.kind != "unit":
					problems.append("%s must name a supported creature ability" % path)
			elif not _integer(item) or float(item) < 0 or float(item) > 100:
				problems.append("%s must be an integer in 0..100" % path)
			elif key == "health" and base.kind == "unit" and int(item) < 1:
				problems.append("%s must be positive for creatures" % path)
			elif key == "amount" and base.kind not in ["damage", "heal"]:
				problems.append("%s is only supported for damage/heal spells" % path)
			elif key in ["health", "power"] and base.kind != "unit":
				problems.append("%s only applies to creatures; spells use amount" % path)
		if scope == "enemy_cards" and base.kind != "unit":
			problems.append("%s.%s cannot apply: enemy only deploys creatures" % [scope, id])
