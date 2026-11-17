class_name Prop
extends Interactable
## A glowing floating object on a pedestal that launches a mini-game.

enum Shape { SPHERE, BOX, PRISM, PYRAMID }

@export var label_text := "Mystery"
@export var color := Color(1.0, 0.6, 0.2)
@export var shape: Shape = Shape.SPHERE
@export var retain_marker_on_win := false  ## Replayable tables without a replacement trophy.

const Sign := preload("res://ui/world_sign.gd")
const CRYSTAL := preload("res://shaders/crystal.gdshader")

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _light: OmniLight3D = $Light
@onready var _label: Label3D = $Label

var _mat: ShaderMaterial
var _trophy: Node3D
var _t := randf() * 10.0


func _ready() -> void:
	super()
	match shape:
		Shape.SPHERE:
			var m := SphereMesh.new(); m.radius = 0.35; m.height = 0.7
			_mesh.mesh = m
		Shape.BOX:
			var m := BoxMesh.new(); m.size = Vector3.ONE * 0.55
			_mesh.mesh = m
		Shape.PRISM:
			var m := PrismMesh.new(); m.size = Vector3(0.6, 0.8, 0.6)
			_mesh.mesh = m
		Shape.PYRAMID:
			_mesh.mesh = _pyramid_mesh(0.42, 0.85)
	_mat = ShaderMaterial.new()
	_mat.shader = CRYSTAL
	_mat.set_shader_parameter("color", color)
	_mesh.material_override = _mat
	_light.light_color = color
	_label.visible = false
	var title := label_text.split(" · ")[0]
	if minigame_id == "cards":
		title = "Little Brother"
	var subtitle := "CHALLENGE AWAITS" if not minigame_id.is_empty() else "AN EXHIBIT YET TO COME"
	Sign.plaque(self, title, subtitle, Vector3(0, .66, 1.1), Vector2(1.65, .40), color)
	for x in [-.56, .56]:
		Sign.box(self, Vector3(.045, .5, .045), Vector3(x, .25, 1.1), Color("74654c"), true)
	_refresh_completed()


## A prop with no `minigame_id` is a placeholder for a mini-game that doesn't exist yet.
func interact(player: Node3D) -> void:
	if minigame_id == "":
		await Dialogue.say(label_text, ["This challenge isn't ready yet. Check back later."])
		interacted.emit()
		return
	await super(player)
	_refresh_completed()


func _process(delta: float) -> void:
	_t += delta
	_mesh.position.y = 1.3 + sin(_t * 2.0) * 0.1
	_mesh.rotate_y(delta * 0.9)


func _on_focus_changed(value: bool) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): _mat.set_shader_parameter("highlight", v),
		0.0 if value else 1.0, 1.0 if value else 0.0, 0.2)
	_light.light_energy = 2.5 if value else 1.0


## Square pyramid (flat-shaded), centred on its middle so it spins like the other shapes.
func _pyramid_mesh(half: float, height: float) -> ArrayMesh:
	var y0 := -height / 2.0
	var c: Array[Vector3] = [Vector3(-half, y0, -half), Vector3(half, y0, -half), Vector3(half, y0, half), Vector3(-half, y0, half)]
	var apex := Vector3(0.0, height / 2.0, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var a := c[k]
		var b := c[(k + 1) % 4]
		# winding so the face normal points away from the axis (Godot front faces are clockwise)
		for v in [a, apex, b]:
			st.add_vertex(v)
	for v in [c[0], c[1], c[2], c[0], c[2], c[3]]:
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Once the station's mini-game is won the floating shape goes away, and the station's platform shows the
## game's trophy instead (MiniGames.REGISTRY[id].trophy builds it from the stored result).
func _refresh_completed() -> void:
	if minigame_id == "" or not Game.completed_minigames.has(minigame_id):
		return
	_mesh.visible = retain_marker_on_win
	_light.visible = retain_marker_on_win
	if _trophy != null:
		return
	var path: String = MiniGames.REGISTRY.get(minigame_id, {}).get("trophy", "")
	var platform := get_node_or_null("Platform") as StationPlatform
	if path == "" or platform == null:
		return
	_trophy = load(path).build(Game.completed_minigames[minigame_id])
	platform.add_to_model(_trophy)
