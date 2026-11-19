extends "res://scenes/room/prop.gd"
## The Workshop's station: a brass portal ring standing on the platform, twin of the one
## in the Engineer's 1955 workshop. Through it, his workshop is hand-drawn; the past just
## looks that way from here. Keeps the Prop's interaction, sign and trophy handling.

const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const SWIRL := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
uniform float strength = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 3.0 + r * 9.0 - TIME * 2.4) * 0.5 + 0.5;
	vec3 deep = vec3(0.30, 0.20, 0.75);
	vec3 bright = vec3(0.50, 0.90, 1.00);
	ALBEDO = mix(deep, bright, swirl * (1.0 - r)) + vec3(1.0) * smoothstep(0.25, 0.0, r) * 0.6;
	ALPHA = smoothstep(1.0, 0.85, r) * 0.85 * strength;
}
"""

var _ring: Node3D


func _ready() -> void:
	super()
	_mesh.hide()
	_light.light_color = Color("7fe7ff")
	_build_ring()


func _process(_delta: float) -> void:
	pass  # The Prop's floating shape is hidden; nothing to bob.


func _build_ring() -> void:
	_ring = Node3D.new()
	_ring.name = "PortalRing"
	_ring.position = Vector3(0, 1.62, -0.15)
	add_child(_ring)
	var brass := Geometry.material(Color("c99a45"), 0.75)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.6
	torus.rings = 48
	torus.ring_segments = 12
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = brass
	ring.rotation.x = PI / 2.0
	ring.scale = Vector3(0.8, 1.0, 1.1)   # A tall oval, like the workshop's.
	_ring.add_child(ring)
	var disc := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.84, 1.14)
	disc.mesh = quad
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SWIRL
	mat.shader = shader
	disc.material_override = mat
	_ring.add_child(disc)
	for x in [-0.3, 0.3]:
		Geometry.box(_ring, Vector3(x, -0.6, 0), Vector3(0.1, 0.12, 0.16), Geometry.material(Color("3c3c3c"), 0.5))
