extends Node3D
## A slate blackboard in the Observatory chamber that shows the sigils the player
## has forged. Blank when none have been made. Sigils are chalk sketches built from
## the same attractor point sets the minigame uses.
##
## Place it on a chamber wall; it builds its own frame and writes in chalk on the
## board's local XY plane (facing +Z).

const Math := preload("res://minigames/observatory/observatory_math.gd")
const Geometry := preload("res://scenes/escape/hub_geometry.gd")

const BOARD := Vector2(2.6, 1.5)
const CELL := 0.32
const CHALK_POINTS := 120

var _chalk: Node3D


func _ready() -> void:
	name = "ObservatoryBoard"
	var wood := Geometry.surface(Color(0.20, 0.14, 0.09), 0.1, 0.72)
	var slate := Geometry.surface(Color(0.045, 0.06, 0.055), 0.0, 0.92)
	var brass := Geometry.material(Color(0.55, 0.44, 0.22), 0.7, 0.3)
	# frame, slate, chalk tray
	Geometry.box(self, Vector3(0, 0, -0.04), Vector3(BOARD.x + 0.16, BOARD.y + 0.16, 0.08), wood)
	Geometry.box(self, Vector3(0, 0, 0), Vector3(BOARD.x, BOARD.y, 0.02), slate)
	Geometry.box(self, Vector3(0, -BOARD.y / 2.0 - 0.10, 0.05), Vector3(BOARD.x + 0.1, 0.06, 0.12), brass)
	# corner brackets
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			Geometry.box(self, Vector3(sx * BOARD.x / 2.0, sy * BOARD.y / 2.0, 0.03), Vector3(0.12, 0.12, 0.03), brass)
	_chalk = Node3D.new()
	_chalk.name = "Chalk"
	add_child(_chalk)
	Game.card_collected.connect(func(_id: String): refresh())
	Game.flag_changed.connect(func(_f: String, _v: Variant): refresh())
	refresh()


## Clears the board and redraws every collected sigil. Called when progress changes.
func refresh() -> void:
	for c in _chalk.get_children():
		c.queue_free()
	var drawn := 0
	for i in Math.SIGIL_COUNT:
		var s: Dictionary = Math.sigil(i)
		if Game.collected_cards.has(s.card):
			_draw_sigil(i, drawn)
			drawn += 1


func _draw_sigil(index: int, slot: int) -> void:
	# five cells in a row; draw only the collected ones left-to-right
	var x := -BOARD.x / 2.0 + 0.28 + float(slot) * (BOARD.x - 0.56) / 4.0
	var center := Vector3(x, 0.05, 0.025)
	var s: Dictionary = Math.sigil(index)
	var pts := Math.attractor_points(int(s.shape), CHALK_POINTS)
	var chalk := Geometry.material(Color(0.85, 0.88, 0.82), 0.0)
	chalk.emission_enabled = true
	chalk.emission = Color(0.5, 0.55, 0.5)
	chalk.emission_energy_multiplier = 0.15
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var dot := BoxMesh.new()
	dot.size = Vector3(0.018, 0.018, 0.006)
	mm.mesh = dot
	dot.surface_set_material(0, chalk)
	mm.instance_count = pts.size()
	for i in pts.size():
		# project the attractor's x/z into the board's xy plane
		var p: Vector3 = center + Vector3(pts[i].x, pts[i].z, 0.0) * CELL
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	_chalk.add_child(inst)