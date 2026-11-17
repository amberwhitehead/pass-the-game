extends Interactable
## A found card joins the duel deck directly; it never replaces a carried prism/lens.
signal message(text: String)
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const CardActor := preload("res://minigames/cards/card_actor.gd")
const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const Sign := preload("res://ui/world_sign.gd")
var card_id := ""
var _available := true
var _taking := false
var _actor: Node3D
var _tag: Label3D
var _rim: MeshInstance3D


func configure(id: String) -> void:
	card_id = id
	prompt = "Take card · %s" % Catalog.get_card(id).get("name", id.capitalize())


func _ready() -> void:
	super()
	add_to_group("collectible_card")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var bounds := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.65, .82, .38)
	bounds.shape = box
	add_child(bounds)
	var brass := Geometry.material(Color("8c7448"), .72)
	var dark := Geometry.surface(Color("15252a"), .5, .4)
	_rim = Geometry.box(self, Vector3(0, 0, -.085), Vector3(.54, .72, .065), brass)
	Geometry.box(self, Vector3(0, 0, -.043), Vector3(.49, .67, .025), dark)
	# Short shelf and retaining lip look like a card tucked into existing machinery.
	Geometry.box(self, Vector3(0, -.36, .065), Vector3(.61, .055, .31), brass)
	Geometry.box(self, Vector3(0, -.32, .205), Vector3(.54, .055, .025), brass)
	_actor = CardActor.new()
	_actor.name = "FoundCard"
	_actor.rotation.x = PI / 2
	_actor.scale = Vector3.ONE * .47
	_actor.position = Vector3(0, 0, .035)
	_actor.configure(Catalog.get_card(card_id))
	add_child(_actor)
	_actor.collider.collision_layer = 0
	_tag = Sign.tag(self, "Found card", Vector3(0, .48, .055), .92, Sign.GOLD, 3.0)
	Game.card_collected.connect(_on_collected)
	if card_id in Game.collected_cards:
		_set_unavailable()
		_actor.hide()
		_tag.hide()


func interact(_player: Node3D) -> void:
	if not _available:
		return
	_taking = true
	if not Game.collect_card(card_id):
		_taking = false
		return
	Sound.play_at("pickup", get_focus_position(), get_parent())
	var card: Dictionary = Catalog.get_card(card_id)
	message.emit("%s joins your deck. %d / 5 cards found. Take it to Older Brother." % [card.name, Game.collected_cards.size()])
	interacted.emit()
	_actor.pulse(Sign.GOLD)
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(_actor, "position", _actor.position + Vector3.UP * .35 + Vector3.BACK * .08, .45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_actor, "scale", Vector3.ONE * .08, .45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	reveal.chain().tween_callback(_actor.hide)


func get_focus_position() -> Vector3:
	return global_position


func _on_collected(id: String) -> void:
	if id != card_id:
		return
	_set_unavailable()
	_tag.hide()
	if not _taking:
		_actor.hide()


func _set_unavailable() -> void:
	_available = false
	collision_layer = 0
	monitorable = false
	remove_from_group("interactable")
	_on_focus_changed(false)


func _on_focus_changed(value: bool) -> void:
	if _actor == null:
		return
	_actor.set_hovered(value and _available)
	var material := _rim.material_override as StandardMaterial3D
	material.emission_enabled = value and _available
	material.emission = Sign.GOLD
	material.emission_energy_multiplier = .45
	if _tag != null:
		_tag.text = Catalog.get_card(card_id).get("name", "Found card") if value else "Found card"
		Sign.fit_tag(_tag)
