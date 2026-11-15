# Lineup of all characters under NEUTRAL lighting (sky ambient/reflections + one key light),
# so characters are judged on their own, not on the placeholder room lighting.
# godot --path godot -s ../blends/preview/lineup.gd --write-movie out.png --fixed-fps 10 --quit-after 6
extends SceneTree
# Lineup of all characters under the room's lighting, for a visual check.
var names := ["engineer", "officer", "officer_colonel", "metric_a", "metric_b", "augmented", "roman", "egyptian", "mayan"]  # add new characters here
func _initialize():
	var env := Environment.new()
	var sky := Sky.new(); sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -25, 0)
	sun.light_energy = 1.1; root.add_child(sun)
	var scene_root := Node3D.new(); root.add_child(scene_root)
	for i in names.size():
		var n: Node3D = (load("res://assets/characters/%s.glb" % names[i]) as PackedScene).instantiate()
		n.position = Vector3((i - 4.0) * 1.1, 0, 0)
		scene_root.add_child(n)
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation("idle"): ap.play("idle")
	var cam := Camera3D.new(); cam.fov = 35
	cam.position = Vector3(0, 1.15, 27.0); root.add_child(cam); cam.current = true
	print("lineup ready")
