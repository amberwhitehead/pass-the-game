class_name NPC
extends Interactable
## Talkable character. Assign a rigged character `model` (res://assets/characters/*.glb) and set
## name/lines in the inspector. If `minigame_id` is set, the NPC challenges you after talking.
##
## The character models share one rig convention (see blends/README.md): an "idle" body
## animation, plus "blink" and "talk" face animations that only drive blend shapes. Body and face
## play on two AnimationPlayers over the same animation library, so they layer.

@export var npc_name := "Villager"
# These are Array[String], not PackedStringArray: a PackedStringArray set in a scene is silently
# dropped in exported builds (every NPC fell back to the default "Hello there." on the web).
@export_multiline var lines: Array[String] = ["Hello there."]
@export_multiline var lines_repeat: Array[String] = []  ## said on later visits
@export var model: PackedScene
@export var label_height := 2.15  ## metres above the floor; raise it for tall headgear
@export var talked_flag := ""  ## Game flag set after first conversation
## If >= 0, "{n}" in the repeat lines becomes a counter that goes up by one each time they're said,
## starting from this value (formatted with thousands separators). It may run past any "total" in the text.
@export var repeat_counter_start := -1
## Every Nth visit (5th, 10th, ...) an NPC with repeat lines says their first-visit lines again
## instead of the repeat ones. 0 = never.
@export var replay_first_every := 5

@onready var _label: Label3D = $Name

var _model: Node3D
var _body_anim: AnimationPlayer
var _face_anim: AnimationPlayer
var _face_meshes: Array[MeshInstance3D] = []
var _talked := false
var _talking := false
var _repeat_count := 0
var _visits := 0
var _turn: Tween


func _ready() -> void:
	super()
	prompt = "Talk"
	_label.text = npc_name
	_label.position.y = label_height
	_setup_model()
	_blink_loop()


func _setup_model() -> void:
	if model == null:
		push_warning("NPC '%s' has no model assigned" % npc_name)
		return
	_model = model.instantiate()
	add_child(_model)
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		_face_meshes.append(m)
	_body_anim = _model.find_child("AnimationPlayer", true, false)
	if _body_anim == null:
		return
	# Second player over the same library, so a face animation can run over the body one.
	_face_anim = AnimationPlayer.new()
	_body_anim.get_parent().add_child(_face_anim)
	_face_anim.root_node = _body_anim.root_node
	for lib in _body_anim.get_animation_library_list():
		_face_anim.add_animation_library(lib, _body_anim.get_animation_library(lib))
	if _body_anim.has_animation("idle"):
		_body_anim.play("idle")
		_body_anim.seek(randf() * _body_anim.get_animation("idle").length)  # keep a row of NPCs out of sync


func _blink_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.0, 6.0)).timeout
		if is_inside_tree() and not _talking and _face_anim and _face_anim.has_animation("blink"):
			_face_anim.play("blink")


func _set_talking(value: bool) -> void:
	_talking = value
	if _face_anim == null:
		return
	if value and _face_anim.has_animation("talk"):
		_face_anim.play("talk")
	else:
		_face_anim.stop()
		for m in _face_meshes:  # stop() leaves blend shapes where they were
			for i in m.get_blend_shape_count():
				m.set_blend_shape_value(i, 0.0)


static func _with_commas(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < 0 else "") + out


func _face_towards(target: Vector3) -> void:
	var to := target - global_position
	var want := atan2(to.x, to.z)  # model's +z side faces the target
	var from := rotation.y
	if _turn:
		_turn.kill()
	_turn = create_tween()
	_turn.tween_method(func(t: float): rotation.y = lerp_angle(from, want, t), 0.0, 1.0, 0.35)


func interact(player: Node3D) -> void:
	_face_towards(player.global_position)
	_visits += 1
	var repeating := _talked and not lines_repeat.is_empty()
	if repeating and replay_first_every > 0 and _visits % replay_first_every == 0:
		repeating = false   # now and then, the first line again
	var say_lines: Array = Array(lines_repeat if repeating else lines)
	if repeating and repeat_counter_start >= 0:
		var n := _with_commas(repeat_counter_start + _repeat_count)
		_repeat_count += 1
		say_lines = say_lines.map(func(l: String) -> String: return l.replace("{n}", n))
	_set_talking(true)
	await Dialogue.say(npc_name, say_lines)
	_set_talking(false)
	_talked = true
	if talked_flag != "":
		Game.set_flag(talked_flag)
	await super(player)  # launches minigame if one is configured
