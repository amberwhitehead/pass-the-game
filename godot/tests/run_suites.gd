extends SceneTree
## Runs test suites (tests/*_test.gd, each extending test_suite.gd) one after another in
## this one Godot process, so Godot starts once rather than once per suite. Suite names
## follow "--" on the command line; tools/run_tests.py chooses them and reads the markers:
##   @@compile_failed <script>    @@compiled <count>
##   @@begin <suite>    @@end <suite> <exit code>    @@done
## Every script in the project is compiled first, so a compile error anywhere stops the
## run in about a second instead of surfacing later as unrelated suite failures.
## Between suites everything a fresh process would have reset is put back.

const SaveGame := preload("res://autoload/save_game.gd")
const KeyBindings := preload("res://autoload/key_bindings.gd")
var _defaults := {}
var _autoloads: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_defaults = {"max_fps": Engine.max_fps, "time_scale": Engine.time_scale, "size": root.size}
	for property in ProjectSettings.get_property_list():
		if property.name.begins_with("autoload/"):
			_autoloads.append(property.name.trim_prefix("autoload/"))
	var scripts := _scripts("res://")
	# A script that fails to compile still loads, as an unusable script: ask, don't null-check.
	var failed := scripts.filter(func(path: String):
		var script := load(path) as Script
		return script == null or not script.can_instantiate())
	for path: String in failed:
		print("@@compile_failed ", path)
	if not failed.is_empty():
		quit(1)
		return
	print("@@compiled ", scripts.size())
	for suite_name in OS.get_cmdline_user_args():
		await _reset()
		print("@@begin ", suite_name)
		var script: Script = load("res://tests/%s.gd" % suite_name)
		if script == null:
			print("@@end %s 1" % suite_name)
			continue
		var suite: Node = script.new()
		suite.name = suite_name
		var codes: Array[int] = []
		suite.suite_finished.connect(func(code: int): codes.append(code))
		root.add_child(suite)
		suite._initialize()
		while codes.is_empty():
			await process_frame
		print("@@end %s %d" % [suite_name, codes[0]])
	await _reset()
	print("@@done")
	quit(0)


## Every GDScript file in the project, skipping hidden folders (.godot) and build output.
func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		if not sub.begins_with(".") and sub != "build":
			found.append_array(_scripts(folder.path_join(sub)))
	return found


## Returns the shared engine and autoload state to how a fresh process starts.
func _reset() -> void:
	paused = false
	Engine.max_fps = _defaults.max_fps
	Engine.time_scale = _defaults.time_scale
	root.size = _defaults.size
	current_scene = null
	for child in root.get_children():
		if String(child.name) not in _autoloads:
			child.queue_free()
	var games := root.get_node("MiniGames")
	for child in games.get_children():
		child.queue_free()
	games.current = null
	games.transition = null
	games._hub_state = null
	games._launching = false
	games._cancel_loading = false
	var menu := root.get_node("PauseMenu")
	if menu.is_open():
		menu.close()
	var game := root.get_node("Game")
	game.flags.clear()
	game.completed_minigames.clear()
	game.collected_cards.clear()
	game.autosave = false
	game.save_path = ""
	game._save_timer.stop()
	SaveGame.slot_prefix = SaveGame.DEFAULT_PREFIX
	var sound := root.get_node("Sound")
	sound.settings_open = false
	sound.get_node("SoundSettings")._veil.hide()
	var dialogue := root.get_node("Dialogue")
	dialogue.active = false
	dialogue._panel.visible = false
	root.get_node("SceneManager")._busy = false
	root.get_node("TouchControls").set_enabled(true)
	KeyBindings.path = KeyBindings.DEFAULT_PATH
	KeyBindings.apply(KeyBindings.defaults())
	if menu.controls.is_open():
		menu.controls.close()
	Input.flush_buffered_events()
	for action in InputMap.get_actions():
		Input.action_release(action)
	paused = false
	await process_frame
	await process_frame
