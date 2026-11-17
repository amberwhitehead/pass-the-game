extends RefCounted
## Encounter tuning is independent of combat rules and presentation.
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const LITTLE_SEQUENCE: Array[String] = ["guard", "scout", "striker", "scout", "heavy", "medic", "striker", "heavy"]
const OLDER_RESERVE: Array[String] = [
	"bulwark",
	"sentry", "veteran", "crossbow", "veteran", "bulwark", "crossbow",
	"veteran", "sentry", "bulwark", "crossbow", "veteran", "bulwark",
	"crossbow", "veteran", "sentry", "bulwark",
]

static func settings(id: String) -> Dictionary:
	if id == "older_brother":
		return {"id": id, "name": "Older Brother", "lanes": 4, "goal": 12,
			"starting_attention": 3, "attention_cap": 5, "opening_hand": 5, "fixed_opening": 3,
			"deck": Catalog.older_deck(), "reserve": OLDER_RESERVE.duplicate(), "opening_lanes": [3]}
	return {"id": "little_brother", "name": "Little Brother", "lanes": 3, "goal": 10,
		"starting_attention": 2, "attention_cap": 4, "opening_hand": 4, "fixed_opening": 4,
		"deck": Catalog.starter_deck(), "reserve": [], "opening_lanes": []}
