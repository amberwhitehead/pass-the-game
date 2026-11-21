extends Interactable
## A fixed, recoverable item location. Empty hand picks up; occupied hand swaps.

signal changed(item: String)
signal message(text: String)

const Sign := preload("res://ui/world_sign.gd")
const Inventory := preload("res://scenes/escape/carry_inventory.gd")
const Visual := preload("res://scenes/escape/carry_visual.gd")
var slot_item := ""
var accepted_kind := "any"
var display_title := "Item tray"
var _inventory: Node
var _available := true
var _label: Label3D
var _visual: Node3D
var _rim: MeshInstance3D


func configure(inventory: Node, item := "", kind := "any", title := "Item tray") -> void:
	_inventory = inventory
	slot_item = item
	accepted_kind = kind
	display_title = title
	if not inventory.changed.is_connected(_refresh_prompt):
		inventory.changed.connect(_refresh_prompt)
	if is_node_ready():
		_refresh_visual()
	_refresh_prompt()


func _ready() -> void:
	super()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.58, 0.48, 0.58)
	shape.shape = box
	shape.position.y = 0.22
	add_child(shape)
	_rim = MeshInstance3D.new()
	var base := CylinderMesh.new()
	base.top_radius = 0.31
	base.bottom_radius = 0.34
	base.height = 0.08
	base.radial_segments = 24
	_rim.mesh = base
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.25, 0.16)
	mat.metallic = 0.65
	_rim.material_override = mat
	add_child(_rim)
	_label = Sign.tag(self, display_title, Vector3(0, .68, 0), .85, Sign.GOLD, 3.2)
	_refresh_visual()
	_refresh_prompt()
	set_available(_available)


func accepts(item: String) -> bool:
	return item.is_empty() or accepted_kind == "any" \
		or (accepted_kind == "prism" and item == "prism") \
		or (accepted_kind == "lens" and item.begins_with("lens_"))


func interact(_player: Node3D) -> void:
	if not _available or _inventory == null:
		return
	var held: String = _inventory.held_item
	if not accepts(held):
		Sound.play("unavailable", self)
		get_tree().call_group("player_feedback", "shrug")
		message.emit("This cradle holds %s. Place your %s in an empty matching mount first." % [
			"prisms" if accepted_kind == "prism" else "lenses", Inventory.item_name(held).to_lower()])
		return
	if held.is_empty() and slot_item.is_empty():
		get_tree().call_group("player_feedback", "shrug")
		message.emit("An empty cradle. You can return a matching item here.")
		return
	var taken := slot_item
	slot_item = _inventory.exchange(slot_item)
	if not taken.is_empty():
		Sound.play_at("pickup", get_focus_position(), self)
	if not held.is_empty():
		Sound.play_at("place", get_focus_position(), self)
	_refresh_visual()
	_refresh_prompt()
	changed.emit(slot_item)
	interacted.emit()
	if taken.is_empty():
		message.emit("Placed %s." % Inventory.item_name(slot_item).to_lower())
	elif held.is_empty():
		message.emit("Carrying %s. One item at a time." % Inventory.item_name(taken).to_lower())
	else:
		message.emit("Swapped %s for %s." % [Inventory.item_name(held).to_lower(), Inventory.item_name(taken).to_lower()])


func set_item(item: String) -> void:
	slot_item = item
	if is_node_ready():
		_refresh_visual()
	_refresh_prompt()
	changed.emit(slot_item)


func set_available(value: bool) -> void:
	_available = value
	collision_layer = 1 if value else 0
	collision_mask = 0
	monitorable = value
	monitoring = false


func get_focus_position() -> Vector3:
	return global_position + Vector3.UP * 0.22


func _refresh_prompt(_item := "") -> void:
	var held: String = _inventory.held_item if _inventory != null else ""
	if not accepts(held):
		prompt = "Needs %s — set down held item" % accepted_kind
	elif held.is_empty():
		prompt = "Pick up " + Inventory.item_name(slot_item) if not slot_item.is_empty() else display_title + " (empty)"
	elif slot_item.is_empty():
		prompt = "Place " + Inventory.item_name(held)
	else:
		prompt = "Swap for " + Inventory.item_name(slot_item)


func _refresh_visual() -> void:
	if is_instance_valid(_visual):
		remove_child(_visual)
		_visual.queue_free()
	_visual = Visual.build_item(slot_item)
	_visual.position.y = 0.30
	add_child(_visual)
	if _label != null:
		_label.text = display_title if slot_item.is_empty() else Inventory.item_name(slot_item)
		Sign.fit_tag(_label)


func _on_focus_changed(value: bool) -> void:
	if _rim == null:
		return
	var material := _rim.material_override as StandardMaterial3D
	material.emission_enabled = value
	material.emission = Color(0.5, 0.4, 0.16)
