@tool
extends EditorScenePostImport
## Character import fix-up. Set as "Import Script" in a character .glb's import settings
## (or `import_script/path` in its .import file).
##
## Blender's glTF exporter pads face animations (talk, blink) with constant single-key
## tracks for every bone and for the unused blend shapes. Played over walk/idle those would
## snap the skeleton to its rest pose. Here we strip them, so a face animation touches only
## the blend shapes it actually animates and can be layered over body animations.


func _post_import(scene: Node) -> Object:
	for player in scene.find_children("*", "AnimationPlayer", true, false):
		var ap := player as AnimationPlayer
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				_strip_face_padding(lib.get_animation(anim_name))
	return scene


func _strip_face_padding(anim: Animation) -> void:
	var is_face := false
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_BLEND_SHAPE and anim.track_get_key_count(i) > 1:
			is_face = true
			break
	if not is_face:
		return
	for i in range(anim.get_track_count() - 1, -1, -1):
		var animated_shape := anim.track_get_type(i) == Animation.TYPE_BLEND_SHAPE and anim.track_get_key_count(i) > 1
		if not animated_shape:
			anim.remove_track(i)
