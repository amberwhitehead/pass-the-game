extends Node3D
## Anonymous incoming-card cues. The presentation reads destinations, never card identities.
## A transparent halo works in GL Compatibility without bloom/post-processing.

const Layout := preload("res://minigames/cards/table_layout.gd")
var lane_count := 3
const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.25, 1.65);
	vec2 q = abs(p) - vec2(0.515, 0.695);
	float distance_to_rim = abs(length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.03);
	float core = 1.0 - smoothstep(0.007, 0.025, distance_to_rim);
	float halo = exp(-distance_to_rim * distance_to_rim / 0.0026);
	float breath = 0.82 + 0.18 * sin(TIME * 2.4);
	vec3 amber = vec3(1.0, 0.68, 0.30);
	ALBEDO = amber;
	EMISSION = amber * 0.8;
	ALPHA = (core * 0.65 + halo * 0.24) * breath;
}
"""

var active_lanes: Array[int] = []
var _marks: Array[MeshInstance3D] = []


func _ready() -> void:
	setup()


func setup() -> void:
	if not _marks.is_empty():
		return
	var shader := Shader.new()
	shader.code = HALO_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	for lane in lane_count:
		var mark := MeshInstance3D.new()
		mark.name = "IncomingLane%d" % (lane + 1)
		var plane := QuadMesh.new()
		plane.size = Vector2(1.25, 1.65)
		mark.mesh = plane
		mark.material_override = material
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.position = Layout.lane_position("enemy", lane, lane_count) + Vector3.UP * .03
		mark.rotation.x = -PI / 2
		mark.visible = lane in active_lanes
		add_child(mark)
		_marks.append(mark)


func set_intents(value: Variant) -> void:
	var previous := active_lanes.duplicate()
	active_lanes.clear()
	# Accept one deployment now and several in later encounters without changing the view.
	var entries: Array = value if value is Array else [value]
	for entry: Variant in entries:
		if not entry is Dictionary or not entry.has("lane"):
			continue
		var lane := int(entry.lane)
		if lane >= 0 and lane < lane_count and lane not in active_lanes:
			active_lanes.append(lane)
	active_lanes.sort()
	for lane in _marks.size():
		_marks[lane].visible = lane in active_lanes
	if active_lanes != previous and not active_lanes.is_empty() and is_inside_tree() and is_visible_in_tree():
		Sound.play("intent", self)
