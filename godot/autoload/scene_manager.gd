extends CanvasLayer
## Scene switching with a fade. Use SceneManager.change_scene("res://...").

var _fade: ColorRect
var _busy := false
var _loading_label: Label
const LOADING_MESSAGES := ["Loading…", "Compiling shaders…", "Counting vertices…", "Reticulating splines…", "Stitching meshes…"]


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_loading_label = Label.new()
	_loading_label.text = "Loading…"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_label.modulate.a = 0.0
	_loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loading_label)


## True from the start of a fade until the next scene is fully shown.
func is_busy() -> bool:
	return _busy


## Loads and shows a scene. Loading is threaded so the engine stays responsive;
## the scene is rendered (invisibly) for a few frames first so its shaders compile
## during the fade-in rather than mid-play.
func change_scene(path: String, fade_time := 0.4) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0, fade_time)
	# show loading text
	var tw := create_tween()
	tw.tween_property(_loading_label, "modulate:a", 1.0, 0.15)
	await tw.finished

	# threaded load with cycling messages
	ResourceLoader.load_threaded_request(path)
	var packed: PackedScene = null
	var msg_index := 0
	var msg_timer := 0.0
	_loading_label.text = LOADING_MESSAGES[0]
	while true:
		msg_timer += get_process_delta_time()
		if msg_timer >= 2.0:
			msg_timer = 0.0
			msg_index = (msg_index + 1) % LOADING_MESSAGES.size()
			_loading_label.text = LOADING_MESSAGES[msg_index]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			packed = ResourceLoader.load_threaded_get(path) as PackedScene
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED:
			break
		await get_tree().process_frame
	if packed == null:
		_loading_label.modulate.a = 0.0
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false
		return

	# instantiate once, keep invisible to warm shaders for a few frames, then show
	var prev := get_tree().current_scene
	var inst := packed.instantiate()
	inst.visible = false
	get_tree().root.add_child(inst)
	for i in 4:
		await get_tree().process_frame
	inst.visible = true
	get_tree().current_scene = inst
	if prev and is_instance_valid(prev):
		prev.queue_free()
	await get_tree().process_frame

	_loading_label.modulate.a = 0.0
	await _fade_to(0.0, fade_time)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_to(alpha: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", alpha, t)
	await tw.finished