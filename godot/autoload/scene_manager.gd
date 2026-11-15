extends CanvasLayer
## Scene switching with a fade. Use SceneManager.change_scene("res://...").

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func change_scene(path: String, fade_time := 0.4) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow taps mid-transition
	await _fade_to(1.0, fade_time)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _fade_to(0.0, fade_time)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_to(alpha: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", alpha, t)
	await tw.finished
