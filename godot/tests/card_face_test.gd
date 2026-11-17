extends SceneTree
## Both presentations share one face, and card copy must fit printed areas.
const Face := preload("res://minigames/cards/card_face.gd")
const Type := preload("res://minigames/cards/card_typography.gd")
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const Style := preload("res://ui/game_style.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for card: Dictionary in Catalog.CARDS.values():
		var title := Type.fit_title(card.name, Style.font(true), 244)
		check(title.text == card.name, card.name + " title is not truncated")
		check(Style.font(true).get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.size).x <= 244, card.name + " title fits beside cost")
		var copy := Type.rules(card.description, Style.font(), 306)
		check(not copy.truncated and copy.lines.size() <= 3, card.name + " rules fit completely")
		for line: String in copy.lines:
			check(Style.font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, copy.size).x <= 306, "rule line remains inside print area")
	var long_title := Type.fit_title("The Exceptionally Long Named Future Creature", Style.font(true), 244)
	check(long_title.text.ends_with("…"), "future long title truncates explicitly")
	check(Style.font(true).get_string_size(long_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, long_title.size).x <= 244, "long title cannot collide with cost")
	var long_rule := Type.rules("A future card with an extremelylongunbrokentokenwhichmustwrapsafely and several more sentences to ensure it cannot escape its rule area or collide with health and attack badges.", Style.font(), 306)
	check(long_rule.truncated and long_rule.lines.size() == 3, "overlong future rule is bounded")
	for line: String in long_rule.lines:
		check(Style.font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, long_rule.size).x <= 306, "long rule retains horizontal bounds")
	var inspector: Button = load("res://minigames/cards/card_view.gd").new()
	inspector.size = Vector2(235, 313)
	root.add_child(inspector)
	var actor: Node3D = load("res://minigames/cards/card_actor.gd").new()
	root.add_child(actor)
	var wounded := Catalog.get_card("heavy")
	wounded.hp = 1
	wounded.max_hp = 4
	actor.configure(wounded)
	inspector.configure(wounded)
	await process_frame
	check(actor._face.get_script() == inspector._face.get_script(), "world and inspector share face renderer")
	check(actor._face.data.hp == 1 and inspector._face.data.hp == 1, "both presentations retain current wounded health")
	check(inspector.tooltip_text.contains("1 Health"), "wounded inspector accessible text reflects current health")
	check(actor._body.visible and actor.collider.collision_layer == 1, "occupied card keeps physical face and interaction")
	actor.set_empty("Lane 2\nEmpty", "player")
	check(not actor._body.visible and actor.collider.collision_layer == 1, "empty lane reveals actual mat without removing target")
	actor.set_hovered(true)
	check(actor._face.highlighted, "empty lane records its printed hover brackets")
	actor.configure(Catalog.get_card("scout"))
	actor.set_hovered(false)
	check(not actor._face.highlighted, "placing into a hovered lane cannot leave a sticky printed highlight")
	actor.set_selected(true)
	check(actor._face.highlighted, "occupied selected card receives the printed highlight")
	actor.set_selected(false)
	check(not actor._face.highlighted, "occupied selection clears the printed highlight")
	var card := Catalog.get_card("scout")
	var image := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	card.art = ImageTexture.create_from_image(image)
	inspector.configure(card)
	check(inspector._face.art == card.art, "future supplied artwork reaches renderer")
	card.erase("art")
	card.art_path = "res://missing-art-for-test.png"
	inspector.configure(card)
	check(inspector._face.art == null, "missing optional art uses framed placeholder")
	actor.queue_free()
	inspector.queue_free()
	await process_frame
	print("Card faces: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
