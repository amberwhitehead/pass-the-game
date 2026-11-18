extends "res://tests/test_suite.gd"
## Discoveries reach the actual controller, its rematches, and printed spell effects.
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const Progression := preload("res://minigames/cards/deck_progression.gd")
const Copy := preload("res://minigames/cards/encounter_text.gd")
const Rules := preload("res://minigames/cards/match_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 120
	root.size = Vector2i(1280, 720)
	var session: Node = root.get_node("Game")
	var saved: Array = session.collected_cards.duplicate()
	session.collected_cards.clear()
	var table_game: Node = load("res://minigames/cards/cards_older.tscn").instantiate()
	table_game.external_entrance = true
	root.add_child(table_game)
	await process_frame
	table_game.complete_entrance()
	check(table_game._shown.hand.size() == 5 and table_game._shown.hand.slice(0, 3) == Progression.CORE_HAND, "Older opening has three core creatures and two random cards")
	check(table_game._shown.deck_count == 7 and table_game._found_cards.is_empty(), "Base deal contains twelve cards and no discoveries")
	check(table_game._shown == Rules.new("older_brother").start(table_game._seed - 1), "Actual empty-collection deal matches the simulator's default encounter")
	check(table_game.table.hud.collection_count == 0 and table_game.table.hud._deck.text.contains("0 / 5"), "Table communicates zero discoveries")
	check(_dialog_text(table_game).contains("12 cards") and _dialog_text(table_game).contains("0 / 5"), "Opening rules explain actual deck and collection")
	table_game._close_dialog()
	for id: String in Progression.COLLECTIBLES:
		var previous: Dictionary = table_game.match_state.snapshot()
		session.collect_card(id)
		check(table_game.match_state.snapshot() == previous, "Discovery cannot change a deal already in progress")
		table_game._start_match()
		var count: int = session.collected_cards.size()
		check(table_game._found_cards.size() == count and table_game.table.hud.collection_count == count, "Rematch uses current collection")
		check(table_game._shown.hand.size() == 5 and table_game._shown.deck_count == 7 + count, "Found cards enlarge the deck while keeping the same opening size")
		var actual: Array = table_game.match_state._hand + table_game.match_state._deck
		for found: String in session.collected_cards:
			check(actual.count(found) == 1, "Each discovery is dealt or remains shuffled in the deck exactly once")
		var simulated := Rules.new("older_brother", {"collected_cards": session.collected_cards})
		check(simulated.start(table_game._seed - 1) == table_game._shown and simulated._deck == table_game.match_state._deck, "Actual rematch agrees with real rules for this collection and seed")
		var original := Catalog.older_deck()
		var checked_ids := {}
		for base_id: String in original:
			if checked_ids.has(base_id):
				continue
			checked_ids[base_id] = true
			check(actual.count(base_id) == original.count(base_id), "Discoveries preserve base-deck copies of " + base_id)
		check(table_game.table.history.text.to_lower().contains("shuffl"), "Journal explains shuffled discoveries")
	check(table_game._shown.hand.size() == 5, "Full collection still opens with five cards")
	table_game._show_rules()
	check(_dialog_text(table_game).contains("17 cards") and _dialog_text(table_game).contains("5 / 5"), "Rules refresh to the actual upgraded deck")
	check(_dialog_text(table_game).to_lower().contains("shuffl") and not _dialog_text(table_game).contains("Found cards always start"), "Rules explain shuffled cards without promising them in the opening")
	table_game._close_dialog()
	table_game._shown.winner = "enemy"
	table_game._show_result()
	check(not _dialog_text(table_game).contains("Look between"), "Complete collection receives tactics instead of a missing-card clue")
	check(Copy.result(true, false, []).contains("servers beside our doorway"), "First loss points toward the closest discovery")
	check(Copy.result(true, false, ["champion"]).contains("service shelf"), "Loss hint skips an already found card")
	var effects: GDScript = load("res://minigames/cards/table_effects.gd")
	await effects.after(table_game.table, {"type": "spell", "side": "player", "lane": -1,
		"target_side": "player", "target_lane": 0, "card": "renewal", "amount": 6})
	var numbers: Array = table_game.table.world.get_children().filter(func(node: Node) -> bool: return node is Label3D and node.text == "+6")
	check(numbers.size() == 1, "A discovery healing spell animates a positive health number")
	table_game.finish({"won": false})
	table_game.queue_free()
	await process_frame
	var little: Node = load("res://minigames/cards/cards.tscn").instantiate()
	little.external_entrance = true
	root.add_child(little)
	await process_frame
	check(little._shown.hand == ["scout", "striker", "guard", "bolt"] and little._shown.deck_count == 12, "All five discoveries leave the tutorial deck unchanged")
	check(little._found_cards.is_empty() and little.table.hud.collection_count == -1, "Tutorial does not present the older deck's collection status")
	little.finish({"won": false})
	little.queue_free()
	session.collected_cards.assign(saved)
	await process_frame
	print("Card progression scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _dialog_text(game: Node) -> String:
	var text := ""
	for label: Label in game._dialog.find_children("*", "Label", true, false):
		text += label.text + "\n"
	return text

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
