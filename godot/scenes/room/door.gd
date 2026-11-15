class_name DoubleDoor
extends Interactable
## Double doors mounted on a wall. Local +z is the room side.
## Set `target_scene` to make them lead somewhere; otherwise they're locked
## and show `locked_message`.

@export var door_label := "Doors"
@export var locked_message := "The doors are sealed."
@export var locked_speaker := ""  ## shown as the speaker of locked_message
@export_file("*.tscn") var target_scene := ""
@export var accent := Color(0.25, 0.85, 1.0)
## Hinged leaves (industrial door): LeafL/LeafR sit at their hinges and swing into the room, instead of sliding apart.
@export var swing := false

@onready var _label: Label3D = $Label
@onready var _light: OmniLight3D = $Light
@onready var _leaf_l: Node3D = $LeafL
@onready var _leaf_r: Node3D = $LeafR
@onready var _gap: Node3D = $Gap

const LEAF_X := 0.72     # closed offset of each leaf from centre
const LEAF_SLIDE := 1.4  # how far each leaf slides when open
const SWING_DEGREES := 100.0

var _slide: Tween


func _ready() -> void:
	super()
	prompt = "Open"
	_label.text = door_label
	_light.light_color = accent
	var glow := StandardMaterial3D.new()
	glow.albedo_color = accent
	glow.emission_enabled = true
	glow.emission = accent
	glow.emission_energy_multiplier = 2.0
	var strip := get_node_or_null("LeafL/Strip")
	if strip:
		strip.material_override = glow
	$Lintel.material_override = glow


func interact(player: Node3D) -> void:
	if target_scene != "":
		SceneManager.change_scene(target_scene)
	else:
		await Dialogue.say(locked_speaker, [locked_message])
	await super(player)


## Slide the leaves apart (light spills through) or shut them.
func set_open(open: bool, animate := true, time := 0.9) -> void:
	if _slide:
		_slide.kill()
	if swing:
		_set_open_swing(open, animate, time)
		return
	var lx := -(LEAF_X + (LEAF_SLIDE if open else 0.0))
	var rx := LEAF_X + (LEAF_SLIDE if open else 0.0)
	if open:
		_gap.visible = true
	if not animate:
		_leaf_l.position.x = lx
		_leaf_r.position.x = rx
		_gap.visible = open
		return
	_slide = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_slide.tween_property(_leaf_l, "position:x", lx, time)
	_slide.tween_property(_leaf_r, "position:x", rx, time)
	if not open:
		_slide.chain().tween_callback(func(): _gap.visible = false)


func _on_focus_changed(value: bool) -> void:
	create_tween().tween_property(_light, "light_energy", 3.0 if value else 1.0, 0.2)


## Hinged version of set_open: the left leaf swings one way, the right the other, both towards +z (the room).
func _set_open_swing(open: bool, animate: bool, time: float) -> void:
	var angle := deg_to_rad(SWING_DEGREES if open else 0.0)
	if open:
		_gap.visible = true
	if not animate:
		_leaf_l.rotation.y = -angle
		_leaf_r.rotation.y = angle
		_gap.visible = open
		return
	_slide = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_slide.tween_property(_leaf_l, "rotation:y", -angle, time)
	_slide.tween_property(_leaf_r, "rotation:y", angle, time)
	if not open:
		_slide.chain().tween_callback(func(): _gap.visible = false)
