extends Node3D
## Main 3D hub. NPCs, props and the player are instanced in room.tscn so you
## can move/duplicate them in the editor. This script adds walls, ceiling,
## HUD (crosshair, interact prompt, vignette shader) and the opening line.


@onready var _player: Player = $Player
@onready var _floor: HexFloor = $HexFloor
@onready var _major: NPC = $Major
@onready var _colonel: NPC = $Colonel
@onready var _metric_b: NPC = $MetricB

const WALL_HEIGHT := 5.5   # ceiling height in metres
const GUARD_INSET := 0.9   # how far in from the west wall the officers stand (the player starts 1.0 in)
const GUARD_SPREAD := 2.6  # how far to the side of the door centre; clear of the player's start
const EAST_WALL_INSET := 0.9  # how far in from the east wall the NPC standing against it is
const EAST_WALL_Z := -3.2

var _prompt: Label


func _ready() -> void:
	TouchControls.set_enabled(true)
	_build_walls()
	# The tile patch is 5 wide x 8 long; lay the long axis left-to-right on screen
	# (better for landscape phones) and mount a door on each end wall.
	_floor.rotation.y = deg_to_rad(90.0)
	var hl := _floor.room_length / 2.0
	$DoorWest.position = Vector3(-hl, 0, 0)
	$DoorWest.rotation.y = deg_to_rad(90.0)    # faces +x, into the room
	$DoorEast.position = Vector3(hl, 0, 0)
	$DoorEast.rotation.y = deg_to_rad(-90.0)   # faces -x
	_build_hud()
	_player.focus_changed.connect(_on_focus_changed)
	_start_from_west_door(hl)


## You've just stepped in through the west door; it shuts behind you and the two
## officers who intercepted you stand guard either side of it, facing into the room. Everyone else
## is next to a station (placed in room.tscn), except Metric B, who stands against the east wall.
func _start_from_west_door(hl: float) -> void:
	_player.global_position = Vector3(-hl + 1.0, 0.0, 0.0)
	_player.rotation.y = deg_to_rad(-90.0)   # facing east, into the room
	for officer: NPC in [_major, _colonel]:
		var side := 1.0 if officer == _major else -1.0
		officer.global_position = Vector3(-hl + GUARD_INSET, 0.0, side * GUARD_SPREAD)
		officer.rotation.y = deg_to_rad(90.0)   # facing east, out into the room
	_metric_b.global_position = Vector3(hl - EAST_WALL_INSET, 0.0, EAST_WALL_Z)
	_metric_b.rotation.y = deg_to_rad(-90.0)    # facing west, into the room
	var door: DoubleDoor = $DoorWest
	if Game.get_flag("room_visited"):
		door.set_open(false, false)
		return
	Game.set_flag("room_visited")
	door.set_open(true, false)
	await get_tree().create_timer(0.9).timeout
	door.set_open(false)
	# Controls tutorial, switched off for now:
	# await get_tree().create_timer(1.6).timeout
	# await Dialogue.say("", ["Drag to look around. ▲ ▼ walk, ◀ ▶ turn. Face something and press A."])


func _process(_delta: float) -> void:
	_floor.update_glow(_player.global_position)


func _on_focus_changed(target: Interactable) -> void:
	_prompt.visible = target != null
	if target:
		_prompt.text = "A  ·  %s" % target.prompt


func _build_walls() -> void:
	var hw := _floor.room_width / 2.0
	var hl := _floor.room_length / 2.0
	var t := 0.4
	var h := WALL_HEIGHT
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.1, 0.12, 0.16)
	steel.metallic = 0.5
	steel.roughness = 0.6
	# Long axis is x. [centre, size, material]
	var specs := [
		[Vector3(0, h / 2, -hw - t / 2), Vector3(hl * 2 + t * 2, h, t), steel],
		[Vector3(0, h / 2, hw + t / 2), Vector3(hl * 2 + t * 2, h, t), steel],
		[Vector3(-hl - t / 2, h / 2, 0), Vector3(t, h, hw * 2), steel],
		[Vector3(hl + t / 2, h / 2, 0), Vector3(t, h, hw * 2), steel],
	]
	for s in specs:
		var body := StaticBody3D.new()
		body.position = s[0]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = s[1]
		shape.shape = box
		body.add_child(shape)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s[1]
		mi.mesh = bm
		mi.material_override = s[2]
		body.add_child(mi)
		add_child(body)

	# Ceiling + a row of lamps so the first-person view isn't a void above you.
	var ceil_mi := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(hl * 2 + t * 2, 0.2, hw * 2 + t * 2)
	ceil_mi.mesh = cm
	ceil_mi.position.y = h + 0.1
	ceil_mi.material_override = steel
	add_child(ceil_mi)
	for ix in 3:
		for iz in 2:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3((ix - 1) * hl * 0.62, h - 0.6, (iz - 0.5) * hw * 0.9)
			lamp.omni_range = hl * 0.75
			lamp.light_energy = 1.1
			lamp.light_color = Color(0.7, 0.85, 1.0)
			add_child(lamp)

	# Pillars along both long walls give the hall scale and rhythm.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.3, 0.85, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.85, 1.0)
	glow.emission_energy_multiplier = 1.5
	for side in [-1.0, 1.0]:
		for px in [-6.4, -3.2, 0.0, 3.2, 6.4]:
			var pillar := StaticBody3D.new()
			pillar.position = Vector3(px, h / 2, side * (hw - 0.35))
			var pshape := CollisionShape3D.new()
			var pbox := BoxShape3D.new()
			pbox.size = Vector3(0.7, h, 0.7)
			pshape.shape = pbox
			pillar.add_child(pshape)
			var pm := MeshInstance3D.new()
			var pbm := BoxMesh.new()
			pbm.size = Vector3(0.7, h, 0.7)
			pm.mesh = pbm
			pm.material_override = steel
			pillar.add_child(pm)
			var strip := MeshInstance3D.new()
			var sbm := BoxMesh.new()
			sbm.size = Vector3(0.1, h - 1.0, 0.1)
			strip.mesh = sbm
			strip.position = Vector3(0, 0, -side * 0.36)
			strip.material_override = glow
			pillar.add_child(strip)
			add_child(pillar)
	# Between the pillars, the north and south walls are covered in rectangular greebles.
	var bays := []
	var xs := [-6.4, -3.2, 0.0, 3.2, 6.4]
	for i in xs.size() - 1:
		bays.append([xs[i] + 0.35, xs[i + 1] - 0.35])
	var count := Greebles.build(self, hw, h, bays)
	if OS.is_debug_build():
		print("wall greebles: ", count, " rectangles")


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/vignette.gdshader")
	vig.material = m
	layer.add_child(vig)

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.5)
	dot.custom_minimum_size = Vector2(6, 6)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -3; dot.offset_right = 3; dot.offset_top = -3; dot.offset_bottom = 3
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dot)

	_prompt = Label.new()
	_prompt.visible = false
	_prompt.add_theme_font_size_override("font_size", 34)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 10)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_top = 0.55
	_prompt.anchor_bottom = 0.55
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_prompt)
