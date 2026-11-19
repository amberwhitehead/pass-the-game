extends Node3D
## The hall side of room revisits (docs/INTERCONNECTION.md): what changes in the hall
## after other rooms are won, and the ways back into them.
##
##  - The ring tray: where things sent from the Engineer's 1955 workshop arrive, beside
##    the Workshop's portal ring. A carry slot, kept in step with TimeLink's tray flag.
##  - Fuse: after the Workshop is won, the cat wanders out of the ring and naps on the
##    warm optical relay cabinet. Petting him finds a card in his fur (a bonus card).
##  - Egypt's lost sun: after the Workshop is won, Egypt's room goes dark until the
##    flashlight's yellow beam reaches the sun disc by its door (see optics_model.gd).
##    Then the Egyptian's thanks, the Sun Scarab card, waits at the disc.
##
## room.gd adds this node and calls configure(); everything else happens here.

const TimeLink := preload("res://autoload/time_link.gd")
const CarrySlot := preload("res://scenes/escape/carry_slot.gd")
const CardPickup := preload("res://scenes/escape/card_pickup.gd")
const Model := preload("res://scenes/escape/optics_model.gd")
const Geometry := preload("res://scenes/escape/hub_geometry.gd")

const EGYPT_CENTER := Vector3(-6, 0, -11.2)
const EGYPT_HALF := 3.4
const DARK_ENERGY := 0.08

signal message(text: String)

var tray: Interactable
var cat: Interactable
var scarab: Interactable
var _inventory: Node
var _egyptian: Node
var _egypt_lights := {}   ## OmniLight3D -> its normal energy
var _darkness: MeshInstance3D   ## A shadow volume over Egypt's room while its sun is out.


func configure(inventory: Node, workshop_station: Node3D, egyptian: Node) -> void:
	_inventory = inventory
	_egyptian = egyptian
	name = "Revisits"
	_build_tray(workshop_station)
	MiniGames.ended.connect(func(_id: String, _r: Dictionary): refresh())
	Game.flag_changed.connect(func(flag: String, _v: Variant):
		if flag in ["egypt_sun_restored", TimeLink.TRAY_FLAG]:
			refresh())


func _ready() -> void:
	_find_egypt_lights.call_deferred()
	refresh.call_deferred()


## Brings the hall up to date with progress made elsewhere.
func refresh() -> void:
	if not is_inside_tree():
		return
	if tray and tray.slot_item != TimeLink.tray_item():
		tray.set_item(TimeLink.tray_item())
	_refresh_cat()
	_refresh_egypt()


# --- the ring tray ----------------------------------------------------------------------

func _build_tray(station: Node3D) -> void:
	tray = CarrySlot.new()
	tray.name = "RingTray"
	add_child(tray)
	tray.configure(_inventory, TimeLink.tray_item(), "any", "From 1955")
	# On the floor in front of the platform, to the left: under the ring, in reach.
	tray.global_transform = station.global_transform.translated_local(Vector3(-1.05, 0, 0.55))
	tray.changed.connect(func(item: String): TimeLink.set_tray_item(item))
	tray.message.connect(func(text: String): message.emit(text))


# --- Fuse -------------------------------------------------------------------------------

func _refresh_cat() -> void:
	var loose := Game.completed_minigames.has("workshop")
	if loose and cat == null:
		cat = HallCat.new()
		cat.name = "Fuse"
		add_child(cat)
		var engine_top := Model.world(Model.OBSTACLE.get_center(), 2.4)
		cat.global_position = engine_top + Vector3(-0.2, 0, 0.3)
		cat.rotation.y = PI - 0.4   # Facing back into the hall.
		cat.petted.connect(_on_cat_petted)
	elif not loose and cat != null:
		cat.queue_free()
		cat = null


func _on_cat_petted() -> void:
	if TimeLink.is_active("fuse_loose"):
		TimeLink.fix("fuse_loose")
		Game.collect_card("fuse")
		message.emit("Fuse rolls over. A card was stuck in his fur: Fuse joins your deck. Take it to Older Brother.")
	else:
		message.emit("Fuse purrs, and doesn't open his eyes.")


# --- Egypt's sun ------------------------------------------------------------------------

func _find_egypt_lights() -> void:
	var box := AABB(EGYPT_CENTER - Vector3(EGYPT_HALF, 0, EGYPT_HALF), Vector3(EGYPT_HALF * 2, 6, EGYPT_HALF * 2))
	for light in get_parent().find_children("*", "OmniLight3D", true, false):
		if box.has_point(light.global_position):
			_egypt_lights[light] = light.light_energy
	_refresh_egypt()


func _refresh_egypt() -> void:
	var dark := TimeLink.is_active("egypt_dark")
	if dark and _darkness == null:
		_build_darkness()
	if _darkness:
		_darkness.visible = dark
	for light: OmniLight3D in _egypt_lights:
		if is_instance_valid(light):
			light.light_energy = _egypt_lights[light] * (DARK_ENERGY if dark else 1.0)
	if _egyptian:
		if dark:
			_egyptian.lines_repeat.assign(["The sun has gone out of my room. Since your business with that machine-maker and his cat.",
				"Ra does not travel well these days. Perhaps he needs... a lamp."])
		elif bool(Game.get_flag("egypt_sun_restored", false)):
			_egyptian.lines_repeat.assign(["Sunlight from a tin tube, through yellow glass. Ra has been humbled, and so have I. My thanks waits at the disc."])
	var restored := bool(Game.get_flag("egypt_sun_restored", false))
	if restored and scarab == null and "scarab" not in Game.collected_cards:
		scarab = CardPickup.new()
		scarab.name = "ScarabCard"
		scarab.configure("scarab")
		add_child(scarab)
		scarab.global_position = Model.world(Model.SUN_DISC, 0.7) + Vector3(0.75, 0, 0.35)
		scarab.rotation.y = 0.0
		scarab.message.connect(func(text: String): message.emit(text))


## A box over the room drawn only from inside (front faces culled), unshaded and part
## transparent: from the hall or inside the room, everything in it looks dimmed.
func _build_darkness() -> void:
	_darkness = MeshInstance3D.new()
	_darkness.name = "EgyptDarkness"
	var box := BoxMesh.new()
	# Inside the walls and just above the floor, so its far faces aren't hidden by them.
	box.size = Vector3(5.6, 4.1, 5.6)
	_darkness.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.albedo_color = Color(0.0, 0.0, 0.02, 0.7)
	_darkness.material_override = mat
	_darkness.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_darkness)
	_darkness.global_position = EGYPT_CENTER + Vector3(0, 2.1, 0)


## Fuse, napping, built from boxes like the hall's other models.
class HallCat extends Interactable:
	signal petted

	const Geometry := preload("res://scenes/escape/hub_geometry.gd")
	var _t := 0.0
	var _body: Node3D

	func _ready() -> void:
		super()
		prompt = "Pet the cat"
		collision_layer = 1
		collision_mask = 0
		monitoring = false
		var bounds := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.7, 0.4, 0.5)
		bounds.shape = box
		bounds.position = Vector3(0, 0.2, 0)
		add_child(bounds)
		var ginger := Geometry.material(Color("e0954f"))
		var stripe := Geometry.material(Color("b8672e"))
		var cream := Geometry.material(Color("f3d7b0"))
		var chrome := Geometry.material(Color("c7cfd0"), 0.8)
		var red := Geometry.material(Color("c9333f"))
		_body = Node3D.new()
		_body.scale = Vector3.ONE * 1.5
		add_child(_body)
		# A loaf: body, head tucked at the front, tail curled round.
		Geometry.box(_body, Vector3(0, 0.13, 0), Vector3(0.46, 0.24, 0.3), ginger)
		for x in [-0.14, -0.04, 0.06]:
			Geometry.box(_body, Vector3(x, 0.252, 0), Vector3(0.025, 0.012, 0.24), stripe)
		Geometry.box(_body, Vector3(0.26, 0.17, 0.02), Vector3(0.2, 0.18, 0.2), ginger)
		Geometry.box(_body, Vector3(0.36, 0.14, 0.02), Vector3(0.04, 0.08, 0.12), cream)
		for z in [-0.06, 0.09]:
			var ear := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.08, 0.1, 0.03)
			ear.mesh = prism
			ear.material_override = ginger
			ear.position = Vector3(0.27, 0.3, z)
			ear.rotation.y = PI / 2.0
			_body.add_child(ear)
		for z in [-0.04, 0.07]:
			Geometry.box(_body, Vector3(0.365, 0.2, z), Vector3(0.01, 0.012, 0.04), Geometry.material(Color("3a2618")))
		Geometry.box(_body, Vector3(-0.02, 0.04, 0.17), Vector3(0.4, 0.05, 0.05), ginger)
		Geometry.box(_body, Vector3(0.19, 0.04, 0.17), Vector3(0.05, 0.05, 0.05), stripe)
		# His souvenirs: the sardine lid on one ear and a loop of red yarn.
		var lid := Geometry.box(_body, Vector3(0.27, 0.34, 0.1), Vector3(0.11, 0.012, 0.11), chrome)
		lid.rotation.x = 0.5
		Geometry.box(_body, Vector3(-0.02, 0.15, 0.16), Vector3(0.38, 0.03, 0.02), red)

	func _process(delta: float) -> void:
		_t += delta
		_body.scale.y = 1.0 + sin(_t * 1.6) * 0.03   # Breathing.

	func interact(_player: Node3D) -> void:
		var tw := create_tween()
		tw.tween_property(_body, "rotation:x", 0.25, 0.15)
		tw.tween_property(_body, "rotation:x", 0.0, 0.25)
		Sound.play_at("pickup", global_position, self, -6.0, 0.7)
		petted.emit()
		interacted.emit()

	func get_focus_position() -> Vector3:
		return global_position + Vector3.UP * 0.2
