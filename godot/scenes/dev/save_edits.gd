extends RefCounted
## Edits to a save's progress (the Dictionary SaveGame reads and writes), kept apart
## from the editor's UI so they can be tested directly. Every function takes the state
## and changes it in place; anything not edited here is left exactly as it was.

const Progression := preload("res://minigames/cards/deck_progression.gd")
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const OpticsModel := preload("res://scenes/escape/optics_model.gd")
const Inventory := preload("res://scenes/escape/carry_inventory.gd")
## How many of each movable hall item exist; they live in the cradles, hand or mounts.
const ITEM_COUNTS := {"prism": 2, "lens_yellow": 1, "lens_blue": 1}


## A blank save with the three containers Game expects.
static func empty() -> Dictionary:
	return {"flags": {}, "completed_minigames": {}, "collected_cards": []}


## Fills in any missing container so the rest of these functions can assume them.
static func normalize(state: Dictionary) -> Dictionary:
	for key: String in ["flags", "completed_minigames"]:
		if not state.get(key) is Dictionary:
			state[key] = {}
	if not state.get("collected_cards") is Array:
		state.collected_cards = []
	return state


static func flag(state: Dictionary, name: String, default: Variant = false) -> Variant:
	return state.flags.get(name, default)


static func set_flag(state: Dictionary, name: String, value: Variant) -> void:
	state.flags[name] = value


## A win added here records only {"won": true}; trophies that build from a real win's
## details (pyramid positions, the water route) show nothing for it.
static func set_won(state: Dictionary, id: String, won: bool) -> void:
	if won:
		if not state.completed_minigames.has(id):
			state.completed_minigames[id] = {"won": true}
	else:
		state.completed_minigames.erase(id)


static func set_card(state: Dictionary, id: String, found: bool) -> void:
	var cards: Array = state.collected_cards
	if found and id not in cards:
		cards.append(id)
	elif not found:
		cards.erase(id)
	# Keep the game's own order so saves made here match ones made by play.
	state.collected_cards = Progression.COLLECTIBLES.filter(func(card: String): return card in cards)


static func card_name(id: String) -> String:
	return Catalog.get_card(id).get("name", id)


static func cradles(state: Dictionary) -> Array:
	var saved: Array = flag(state, "escape_reward_items", ["prism", "prism"])
	return [str(saved[0]) if saved.size() > 0 else "", str(saved[1]) if saved.size() > 1 else ""]


static func set_cradle(state: Dictionary, index: int, item: String) -> void:
	var contents := cradles(state)
	contents[index] = item
	set_flag(state, "escape_reward_items", contents)


static func held(state: Dictionary) -> String:
	return str(flag(state, "escape_held_item", ""))


static func minigame_progress(state: Dictionary) -> Dictionary:
	return flag(state, "minigame_progress", {})


static func set_progress(state: Dictionary, id: String, value: Dictionary) -> void:
	var progress := minigame_progress(state).duplicate()
	if value.is_empty():
		progress.erase(id)
	else:
		progress[id] = value
	set_flag(state, "minigame_progress", progress)


static func clear_progress(state: Dictionary, id: String) -> void:
	var progress := minigame_progress(state).duplicate()
	progress.erase(id)
	set_flag(state, "minigame_progress", progress)


## Problems the hall would show: items duplicated or lost across cradles, hand and
## optics mounts (counted with the optics model's own starting layout), and
## progress that skips a step.
static func warnings(state: Dictionary) -> Array[String]:
	var found := {}
	var mounts: Dictionary = OpticsModel.new().items
	var stored: Variant = flag(state, "escape_optics_state", {})
	if stored is Dictionary and stored.get("items") is Dictionary:
		mounts = stored.items
	for item: Variant in cradles(state) + [held(state)] + mounts.values():
		found[str(item)] = int(found.get(str(item), 0)) + 1
	var problems: Array[String] = []
	for item: String in ITEM_COUNTS:
		var count := int(found.get(item, 0))
		if count != ITEM_COUNTS[item]:
			problems.append("%d × %s in the hall (expected %d)" % [count, Inventory.item_name(item), ITEM_COUNTS[item]])
	if held(state) not in Inventory.ITEMS:
		problems.append("Holding an unknown item \"%s\"" % held(state))
	if flag(state, "escape_prism_solved") and not flag(state, "escape_rewards_revealed"):
		problems.append("Door 2 is open but Egypt's prisms were never revealed")
	return problems
