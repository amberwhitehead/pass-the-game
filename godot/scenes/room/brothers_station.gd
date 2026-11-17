extends "res://scenes/room/prop.gd"
## A small physical card stand keeps the existing challenge interaction and ID.
const Craft := preload("res://minigames/cards/table_craft.gd")
const Actor := preload("res://minigames/cards/card_actor.gd")
const Catalog := preload("res://minigames/cards/card_catalog.gd")
var _rim_material: StandardMaterial3D
var _focus_tween: Tween

func _ready() -> void:
	var original_children := get_children()
	super()
	# Replace the generic exhibit sign and posts with a label on the stand itself.
	for child in get_children():
		if child not in original_children:
			remove_child(child)
			child.queue_free()
	$Pedestal.hide()
	_mesh.hide()
	_light.hide()
	set_process(false)
	_build_stand()

func _build_stand() -> void:
	var wood := Craft.surface(Color("302219"), true)
	var rail := Craft.surface(Color("4d3423"), true)
	var felt := Craft.surface(Color("183e36"))
	var brass := Craft.material(Color("a58954"), .36, .65)
	_rim_material = brass.duplicate()
	_rim_material.emission = Color("d5b978")
	_rim_material.emission_enabled = true
	_rim_material.emission_energy_multiplier = 0.0
	Craft.box(self, "WalnutCardStand", Vector3(2.12, .16, 1.3), Vector3(0, .86, 0), wood, .055)
	Craft.box(self, "StandBrassRim", Vector3(1.98, .012, 1.16), Vector3(0, .946, 0), _rim_material, .01)
	Craft.box(self, "StandFelt", Vector3(1.93, .016, 1.11), Vector3(0, .957, 0), felt, .01)
	for x in [-.87, .87]:
		for z in [-.45, .45]:
			Craft.box(self, "TaperedStandLeg", Vector3(.13, .79, .13), Vector3(x, .40, z), wood, .022)
			Craft.box(self, "StandBrassFoot", Vector3(.145, .12, .145), Vector3(x, .08, z), brass, .018)
		Craft.box(self, "StandStretcher", Vector3(.065, .08, 1.0), Vector3(x, .25, 0), rail, .01)
	Craft.box(self, "StandCrossbar", Vector3(1.77, .08, .065), Vector3(0, .25, 0), rail, .01)
	var body := StaticBody3D.new()
	body.name = "StandBody"
	var collision := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(2.12, .92, 1.3)
	collision.shape = bounds
	collision.position.y = .46
	body.add_child(collision)
	add_child(body)
	var ids: Array[String] = ["scout", "guard", "bolt"]
	for i in ids.size():
		var card := Actor.new()
		card.name = "DisplayCard%d" % i
		card.position = Vector3((i - 1) * .48, .98, -.05)
		card.scale = Vector3.ONE * .31
		card.rotation.y = deg_to_rad((i - 1) * -7.0)
		card.configure(Catalog.get_card(ids[i]))
		add_child(card)
		card.collider.collision_layer = 0
		card.disabled = true
	Sign.plaque(self, "Little Brother", "TAKE A SEAT  /  THREE LANES", Vector3(0, .82, .68), Vector2(1.65, .32), Sign.GOLD)

func _on_focus_changed(value: bool) -> void:
	if _rim_material == null:
		return
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.tween_property(_rim_material, "emission_energy_multiplier", .6 if value else 0.0, .18)

func _refresh_completed() -> void:
	super()
	# The stand stays available for rematches, including after winning the tutorial.
	_mesh.hide()
	_light.hide()
