extends RefCounted
## Shared enamel signs. Meshes and fonts are reused; no offscreen UI viewports.
const Style := preload("res://ui/game_style.gd")
const BODY := Style.BODY
const Meshes := preload("res://scenes/escape/hub_meshes.gd")
const PAPER := Style.PAPER
const MUTED := Style.MUTED
const GOLD := Style.GOLD
static var _materials: Dictionary = {}

static func material(color: Color, metal := false) -> StandardMaterial3D:
	var key := "%s/%s" % [color.to_html(), metal]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.metallic = .65 if metal else .15
		mat.roughness = .36 if metal else .56
		# A restrained self-lit face keeps inscriptions legible in every chamber.
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = .28
		_materials[key] = mat
	return _materials[key]

static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color, metal := false) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = Meshes.chamfer_box(size, minf(.025, minf(size.y, size.z) * .25))
	view.material_override = material(color, metal)
	view.position = at
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	return view

static func style(label: Label3D, height := .12, color := PAPER) -> void:
	label.font = BODY
	label.font_size = 64
	label.pixel_size = height / 64.0
	label.modulate = color
	label.outline_size = 2
	label.outline_modulate = Color(.015, .025, .028, .65)
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

static func text(parent: Node3D, copy: String, at: Vector3, height: float,
		color := PAPER, max_width := 0.0, heading := false) -> Label3D:
	var label := Label3D.new()
	style(label, height, color)
	label.font = Style.font(heading)
	label.text = copy
	if max_width > 0:
		var width := label.font.get_string_size(copy, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * label.pixel_size
		if width > max_width:
			label.pixel_size *= max_width / width
	label.position = at
	parent.add_child(label)
	return label

static func plaque(parent: Node3D, title: String, subtitle: String, at: Vector3,
		size := Vector2(2.3, .5), accent := GOLD) -> Dictionary:
	var root := Node3D.new()
	root.name = "EnamelSign"
	root.position = at
	parent.add_child(root)
	box(root, Vector3(size.x, size.y, .07), Vector3.ZERO, Color("695d45"), true)
	box(root, Vector3(size.x-.055, size.y-.055, .018), Vector3(0, 0, .042), Color("101f23"))
	box(root, Vector3(.025, size.y-.11, .012), Vector3(-size.x*.5+.07, 0, .057), accent, true)
	var heading := text(root, title, Vector3(.02, .045 if not subtitle.is_empty() else 0, .062),
		size.y * .28, PAPER, size.x-.22, size.y >= .4)
	if not subtitle.is_empty():
		text(root, subtitle, Vector3(.02, -size.y*.26, .062), size.y*.14, accent.lightened(.18), size.x-.25)
	return {"root": root, "title": heading}

static func doorway(parent: Node3D, number: String, title: String, subtitle: String,
		at: Vector3, accent := GOLD) -> Node3D:
	var sign: Dictionary = plaque(parent, "", "", at, Vector2(3.5, .78), accent)
	var root: Node3D = sign.root
	(sign.title as Label3D).queue_free()
	box(root, Vector3(.57, .59, .015), Vector3(-1.36, 0, .060), accent.darkened(.75))
	text(root, number, Vector3(-1.36, .015, .076), .34, accent.lightened(.35), .5)
	box(root, Vector3(.012, .49, .012), Vector3(-.99, 0, .065), accent.darkened(.2), true)
	text(root, title, Vector3(.33, .09, .068), .26, PAPER, 2.35, true)
	text(root, subtitle, Vector3(.33, -.22, .068), .085, accent.lightened(.25), 2.3)
	return root

static func tag(parent: Node3D, copy: String, at: Vector3, width := .9,
		accent := GOLD, distance := 3.2) -> Label3D:
	# Compact contextual tags: the face follows the text instead of filling a
	# broad fixed-width billboard across several neighboring instruments.
	var root := Node3D.new()
	root.name = "EquipmentTag"
	root.position = at
	parent.add_child(root)
	var face := MeshInstance3D.new()
	face.name = "TagFace"
	face.mesh = QuadMesh.new()
	face.material_override = _tag_material(accent)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.visibility_range_end = minf(distance, 3.2)
	root.add_child(face)
	var label := text(root, copy, Vector3.ZERO, .105, PAPER)
	label.set_meta("tag_max_width", maxf(width, .45))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.render_priority = 1
	label.visibility_range_end = face.visibility_range_end
	label.no_depth_test = false
	fit_tag(label)
	return label

static func fit_tag(label: Label3D) -> void:
	# Called on content changes only; no frame polling or extra render viewports.
	if label.has_meta("tag_fitted_text") and label.get_meta("tag_fitted_text") == label.text:
		return
	label.set_meta("tag_fitted_text", label.text)
	var face := label.get_parent().get_node_or_null("TagFace") as MeshInstance3D
	if face == null:
		return
	label.pixel_size = .105 / 64.0
	var measured := label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * label.pixel_size
	var maximum: float = label.get_meta("tag_max_width", .9)
	if measured > maximum - .10:
		label.pixel_size *= (maximum - .10) / measured
		measured = maximum - .10
	(face.mesh as QuadMesh).size = Vector2(maxf(.45, measured + .10), .175)

static func _tag_material(accent: Color) -> StandardMaterial3D:
	var key := "tag/" + accent.to_html()
	if not _materials.has(key):
		var pixels := Image.create(64, 16, false, Image.FORMAT_RGBA8)
		pixels.fill(Color(.035, .065, .075, .78))
		var edge := Color(accent, .82)
		for x in [0, 1, 2, 3, 4, 59, 60, 61, 62, 63]:
			pixels.set_pixel(x, 0, edge)
			pixels.set_pixel(x, 15, edge)
		for y in [1, 2, 13, 14]:
			pixels.set_pixel(0, y, edge)
			pixels.set_pixel(63, y, edge)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(pixels)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.render_priority = -1
		_materials[key] = mat
	return _materials[key]
