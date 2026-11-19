extends Interactable
## A 1985 arcade cabinet, smuggled back across the 1963 line and hidden in the secret room.
## Its screen runs CHRONO RAIDER's attract mode live (minigames/arcade); interacting
## plays the game. The front faces local +Z; the floor is y = 0.

const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const Shooter := preload("res://minigames/arcade/shooter.gd")

const SCREEN_AT := Vector3(0, 1.33, .245)

var _attract: SubViewport
var _shooter: Node2D
var _marquee: StandardMaterial3D
var _glow: OmniLight3D


func _init() -> void:
	name = "ArcadeCabinet"
	prompt = "Play CHRONO RAIDER"
	minigame_id = "arcade"


func _ready() -> void:
	super()
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var bounds := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.8, 1.9, .75)
	bounds.shape = box
	bounds.position = Vector3(0, .95, 0)
	add_child(bounds)
	_build()


func _build() -> void:
	var body := Geometry.material(Color("1b1430"), .2)
	var trim := Geometry.material(Color("d77cff"), 0.0, .6)
	var black := Geometry.material(Color("08070c"))
	var steel := Geometry.material(Color("8a90a0"), .8)
	# Cabinet: base, upper housing, sides with neon stripes.
	Geometry.box(self, Vector3(0, .45, 0), Vector3(.72, .9, .7), body)
	Geometry.box(self, Vector3(0, 1.4, -.08), Vector3(.72, 1.0, .54), body)
	for side in [-1.0, 1.0]:
		Geometry.box(self, Vector3(side * .385, .95, 0), Vector3(.05, 1.9, .74), body)
		Geometry.box(self, Vector3(side * .412, .95, .1), Vector3(.01, 1.5, .05), trim)
		Geometry.box(self, Vector3(side * .412, .55, -.12), Vector3(.01, .05, .5), trim)
	# Control panel, tilted toward the player, with a joystick and three buttons.
	var panel := Node3D.new()
	panel.position = Vector3(0, .95, .3)
	panel.rotation.x = .3
	add_child(panel)
	Geometry.box(panel, Vector3.ZERO, Vector3(.72, .06, .3), Geometry.material(Color("2b2350"), .3))
	Geometry.box(panel, Vector3(-.16, .07, 0), Vector3(.025, .1, .025), steel)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .035
	sphere.height = .07
	ball.mesh = sphere
	ball.material_override = Geometry.material(Color("ff4d4d"), 0.0, .3)
	ball.position = Vector3(-.16, .13, 0)
	panel.add_child(ball)
	for k in 3:
		var button := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = .024
		cyl.bottom_radius = .024
		cyl.height = .03
		button.mesh = cyl
		button.material_override = Geometry.material([Color("ffe45c"), Color("6ef2ff"), Color("d77cff")][k], 0.0, .5)
		button.position = Vector3(.04 + k * .085, .04, -.02 + (k % 2) * .03)
		panel.add_child(button)
	# Screen: the attract mode, live, behind a black bezel.
	Geometry.box(self, Vector3(0, 1.33, .2), Vector3(.64, .5, .04), black)
	_attract = SubViewport.new()
	_attract.size = Shooter.SIZE
	_attract.disable_3d = true
	_attract.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_attract.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_attract)
	_shooter = Shooter.new()
	_shooter.attract_only = true
	_shooter.process_mode = Node.PROCESS_MODE_DISABLED
	_attract.add_child(_shooter)
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(.56, .315)
	screen.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _attract.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	screen.material_override = mat
	screen.position = SCREEN_AT
	screen.rotation.x = -.08
	add_child(screen)
	# Marquee.
	_marquee = Geometry.material(Color("ff7a3a"), 0.0, .9)
	Geometry.box(self, Vector3(0, 1.98, .02), Vector3(.72, .2, .42), body)
	Geometry.box(self, Vector3(0, 1.98, .235), Vector3(.64, .14, .01), _marquee)
	var title := Label3D.new()
	title.text = "CHRONO RAIDER"
	title.font_size = 64
	title.pixel_size = .00105
	title.outline_size = 10
	title.modulate = Color("fff4c0")
	title.outline_modulate = Color("6a2bb0")
	title.position = Vector3(0, 1.98, .245)
	add_child(title)
	_glow = OmniLight3D.new()
	_glow.light_color = Color("8a6cff")
	_glow.light_energy = .7
	_glow.omni_range = 1.8
	_glow.position = Vector3(0, 1.3, .6)
	add_child(_glow)
	# The attract screen only runs while the cabinet is on screen.
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-.4, 0, -.4), Vector3(.8, 2.1, .8))
	notifier.screen_entered.connect(_set_running.bind(true))
	notifier.screen_exited.connect(_set_running.bind(false))
	add_child(notifier)


func _set_running(on: bool) -> void:
	_shooter.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	_attract.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func attract_running() -> bool:
	return _attract.render_target_update_mode == SubViewport.UPDATE_ALWAYS


func get_focus_position() -> Vector3:
	return to_global(SCREEN_AT + Vector3(0, 0, .05))


func _on_focus_changed(value: bool) -> void:
	_marquee.emission_energy_multiplier = 2.0 if value else .9
	_glow.light_energy = 1.4 if value else .7
