extends Node3D
## Two individually recoverable rewards. Revealing never refills emptied cradles.

signal revealed
signal message(text: String)

const Sign := preload("res://ui/world_sign.gd")
const Slot := preload("res://scenes/escape/carry_slot.gd")
const Art := preload("res://scenes/escape/optics_art.gd")
var slots: Array = []
var is_revealed := false
var _inventory: Node
var _assembly: Node3D
var _collision: CollisionShape3D
var _light: OmniLight3D
var _glow: StandardMaterial3D
var _reveal_tween: Tween


func configure(inventory: Node) -> void:
	_inventory = inventory
	if is_node_ready() and slots.is_empty():
		_build_slots()


func _ready() -> void:
	_assembly = Node3D.new()
	_assembly.name = "RisingPedestal"
	add_child(_assembly)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.28, 0.19, 0.12)
	stone.roughness = 0.72
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.62, 0.43, 0.15)
	gold.metallic = 0.65
	gold.roughness = 0.3
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(1.0, 0.8, 0.3)
	_glow.emission_enabled = true
	_glow.emission = Color(1.0, 0.61, 0.13)
	_glow.emission_energy_multiplier = 1.4
	_box(Vector3(2.3, 0.16, 1.0), Vector3(0, 0.08, 0), gold)
	_box(Vector3(1.9, 0.72, 0.8), Vector3(0, 0.49, 0), stone)
	_box(Vector3(2.2, 0.12, 1.0), Vector3(0, 0.91, 0), gold)
	_box(Vector3(1.94, 0.045, 0.81), Vector3(0, 0.72, 0), _glow)
	for x in [-0.8, 0.8]:
		_box(Vector3(0.045, 0.50, 0.025), Vector3(x, 0.48, 0.412), _glow)
	var inset := Art.material(Color(.10, .08, .055))
	_box(Vector3(1.37, .42, .025), Vector3(0, .47, .409), inset)
	for x: float in [-.55, .55]:
		Art.ring(_assembly, .24, .27, Vector3(x, .981, 0), gold)
		Art.ring(_assembly, .22, .229, Vector3(x, .987, 0), _glow)
	# A recessed stepped motif makes the reward altar belong to the pyramid room.
	for i in 3:
		var half_span := .22 - i * .065
		Art.line(_assembly, Vector3(-half_span, .35+i*.07, .43), Vector3(half_span, .35+i*.07, .43), gold, .009)
	Art.line(_assembly, Vector3(-.26, .32, .43), Vector3(0, .64, .43), gold, .011)
	Art.line(_assembly, Vector3(.26, .32, .43), Vector3(0, .64, .43), gold, .011)
	var body := StaticBody3D.new()
	_assembly.add_child(body)
	_collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 1.0, 1.0)
	_collision.shape = shape
	_collision.position.y = 0.48
	_collision.disabled = true
	body.add_child(_collision)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.65, 0)
	_light.light_color = Color(1.0, 0.75, 0.3)
	_light.light_energy = 1.4
	_light.omni_range = 5.0
	_assembly.add_child(_light)
	Sign.plaque(_assembly, "Gifts of the Pyramid", "TWO PRISMS / ONE PATH FORWARD", Vector3(0, .78, .53), Vector2(1.7, .34), Sign.GOLD)
	if _inventory != null:
		_build_slots()
	visible = is_revealed
	if is_revealed:
		finish_reveal()


func _build_slots() -> void:
	var saved: Array = Game.get_flag("escape_reward_items", ["prism", "prism"])
	for index in 2:
		var slot := Slot.new()
		slot.name = "PrismReward%d" % (index + 1)
		slot.position = Vector3(-0.55 if index == 0 else 0.55, 1.0, 0)
		var item := str(saved[index]) if saved.size() > index else ""
		if item != "prism":
			item = ""
		slot.configure(_inventory, item, "prism", "Prism cradle")
		_assembly.add_child(slot)
		slot.set_available(is_revealed)
		slot.changed.connect(_store_items)
		slot.message.connect(func(text: String): message.emit(text))
		slots.append(slot)
	_store_items()


func _store_items(_item := "") -> void:
	var contents: Array = []
	for slot in slots:
		contents.append(slot.slot_item)
	Game.set_flag("escape_reward_items", contents)


func reveal(animate := true) -> void:
	if is_revealed:
		return
	is_revealed = true
	if not is_node_ready():
		return
	show()
	if not animate:
		finish_reveal()
		return
	_assembly.position.y = -1.3
	Sound.play_at("reward_rise", global_position + Vector3.UP, self)
	_light.light_energy = 0.0
	_glow.emission_energy_multiplier = 0.0
	_reveal_tween = create_tween().set_parallel(true)
	_reveal_tween.tween_property(_assembly, "position:y", 0.0, 1.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(_light, "light_energy", 3.5, 0.6)
	_reveal_tween.tween_property(_glow, "emission_energy_multiplier", 4.0, 0.6)
	_reveal_tween.chain().tween_property(_light, "light_energy", 1.4, 0.5)
	_reveal_tween.parallel().tween_property(_glow, "emission_energy_multiplier", 1.4, 0.5)
	_reveal_tween.chain().tween_callback(_enable_rewards)
	_reveal_tween.tween_callback(func(): Sound.play_at("discovery", focus_point(), self))


func finish_reveal() -> void:
	if is_instance_valid(_reveal_tween):
		_reveal_tween.kill()
	is_revealed = true
	show()
	if _assembly == null:
		return
	_assembly.position.y = 0.0
	_light.light_energy = 1.4
	_glow.emission_energy_multiplier = 1.4
	_enable_rewards()


func _enable_rewards() -> void:
	_collision.set_deferred("disabled", false)
	for slot in slots:
		slot.set_available(true)
	revealed.emit()


func focus_point() -> Vector3:
	return global_position + Vector3.UP * 1.15


func _box(size: Vector3, at: Vector3, material: Material) -> void:
	Art.rounded_box(_assembly, size, at, material, .04)
