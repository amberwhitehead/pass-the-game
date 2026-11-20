extends "res://tests/test_suite.gd"
## The Easter Egg room's board against real completion state, in isolated save slots:
## a fresh game shows only the phone; real Egypt and Roman wins and either Brothers win
## add exactly their piece (never twice); losses and leaving add nothing; wins earned
## before the room is found are there on first entry; reloading and switching slots show
## that slot's pieces; the unwired stages never appear; all seven pieces build and differ;
## and the board does not block the signs or the return panel.

const SaveGame := preload("res://autoload/save_game.gd")
const Pieces := preload("res://scenes/escape/board_pieces.gd")
const Board := preload("res://scenes/escape/egg_board.gd")
var _checks := 0
var _failures := 0
var _games: Node
var _game: Node
var _room: Node3D
var _result: Dictionary = {}
var _returned := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_games = root.get_node("MiniGames")
	_game = root.get_node("Game")
	SaveGame.slot_prefix = "user://test_board_slot_"
	_erase_slots()
	_assets()
	_game.new_game(0)
	await _load_room()
	var board: Node3D = _board()
	_expect(board.player_piece.visible and _shown(board).is_empty(), "A fresh game shows the phone and no stage pieces")
	var children: int = board.get_child_count()
	await _visible_from_arrival()
	await _egypt_win()
	_expect(_shown(_board()) == ["Egypt Fractal"], "An Egypt win adds only the pyramid")
	await _roman_win()
	_expect(_shown(_board()) == ["Egypt Fractal", "Roman Flow"], "A Roman win adds only the arch")
	await _cards(false, "cards_older")
	_expect(not "The Brothers" in _shown(_board()), "Leaving a card match without winning adds nothing")
	await _cards(true, "cards")
	_expect("The Brothers" in _shown(_board()), "A Little Brother win adds the augmented pawn")
	await _cards(true, "cards_older")
	await _cards(true, "cards")
	_expect(_shown(_board()).count("The Brothers") == 1 and _board().get_child_count() == children,
		"Older Brother and rematch wins never add a second pawn or anything else")
	for i in 3:
		_board().refresh()
	_expect(_board().get_child_count() == children, "Refreshing again changes nothing")
	_expect(not "Calendar" in _shown(_board()) and not "Observatory" in _shown(_board()),
		"Calendar and Observatory stay empty: they are not wired yet")
	await _workshop(false)
	_expect(not "Workshop" in _shown(_board()), "Leaving the Workshop unsolved adds nothing")
	await _workshop(true)
	_expect(_shown(_board()).count("Workshop") == 1, "A Workshop win adds the mainframe")
	# First visit after the wins: entering the room shows them.
	var secret: Node3D = _room.get_node("SecretRoom")
	_expect(not secret.inside, "The room has not been visited in this save")
	secret._request(1)
	await _physics(3)
	_expect(secret.inside and _shown(_board()).size() == 4, "Wins earned before finding the room are on the board at first entry")
	# Reload and switch slots.
	_game.save_now()
	_game.new_game(1)
	await _load_room()
	_expect(_shown(_board()).is_empty(), "A new slot shows its own empty board")
	_expect(_game.load_slot(0), "The first slot loads")
	await _load_room()
	_expect(_shown(_board()) == ["Egypt Fractal", "Roman Flow", "The Brothers", "Workshop"], "Reloading the first slot restores its pieces")
	_expect(_game.load_slot(1), "Switching back loads the empty slot")
	await _load_room()
	_expect(_shown(_board()).is_empty(), "Switching slots shows that slot's actual progress")
	_room.queue_free()
	await process_frame
	_game.autosave = false
	_erase_slots()
	SaveGame.slot_prefix = SaveGame.DEFAULT_PREFIX
	print("Easter egg board: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _assets() -> void:
	var sizes: Array[Vector3] = []
	for kind: String in Pieces.KINDS:
		var piece: Node3D = Pieces.build(kind)
		root.add_child(piece)
		var meshes := piece.find_children("*", "MeshInstance3D", true, false)
		var bounds := AABB()
		for mesh: MeshInstance3D in meshes:
			var box := mesh.get_aabb()
			box.position += mesh.position
			bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
		_expect(meshes.size() >= 2, "The %s piece is built from several parts" % kind)
		_expect(bounds.size.y > .08 and bounds.size.y < .25 and bounds.size.x < .2, "The %s piece is board-sized (%s)" % [kind, bounds.size])
		_expect(piece.find_children("*", "CollisionObject3D", true, false).is_empty(), "The %s piece is decoration only" % kind)
		sizes.append(bounds.size.snapped(Vector3.ONE * .005))
		piece.free()
	var unique: Array[Vector3] = []
	for size in sizes:
		if size not in unique:
			unique.append(size)
	_expect(unique.size() == sizes.size(), "Every piece has its own silhouette")
	var mapped: Array = []
	for entry: Dictionary in Board.STAGES:
		mapped.append(entry.piece)
	_expect(mapped.size() == 6 and "phone" not in mapped, "Six stage pieces are mapped, apart from the phone")
	var source := FileAccess.get_file_as_string("res://scenes/escape/egg_board.gd")
	_expect("AI AGENT IMPLEMENTING A FUTURE STAGE: Connect this stage's genuine success condition" in source,
		"The future-stage note sits beside the mapping")


func _visible_from_arrival() -> void:
	var secret: Node3D = _room.get_node("SecretRoom")
	var eye: Vector3 = secret.room.to_global(Vector3(0, 1.62, 1.5))
	var space := (_room as Node3D).get_world_3d().direct_space_state
	var targets := [secret.exit.get_focus_position()]
	for label: Label3D in secret.room.find_children("*", "Label3D", true, false):
		if label.text in ["You found an Easter Egg!", "This room should be developed by other developers."]:
			targets.append(label.global_position)
	for target: Vector3 in targets:
		var ray := PhysicsRayQueryParameters3D.create(eye, target)
		var hit := space.intersect_ray(ray)
		_expect(hit.is_empty() or not _board().is_ancestor_of(hit.collider), "The board does not block the view to %s" % target)


func _egypt_win() -> void:
	var puzzle: Node = await _open("newton")
	_key_l()
	await process_frame
	_expect(puzzle._solved, "Egypt is solved through its playtest skip")
	_action("interact")
	await _until_returned()
	_expect(_result.get("won", false) and _game.completed_minigames.has("newton"), "Egypt's win is recorded normally")
	for frame in 400:  # Let the hall's reward reveal finish.
		if not _room.reward_reveal.active:
			break
		await process_frame


func _roman_win() -> void:
	var puzzle: Node = await _open("turing")
	puzzle._solved = true  # As pause_menu_test does: a solved puzzle leaves with its win.
	_action("back")
	await _until_returned()
	_expect(_result.get("won", false) and _game.completed_minigames.has("turing"), "Roman Flow's win is recorded normally")


## The Workshop through the game's own result path: its story emits `won` at the end.
func _workshop(win: bool) -> void:
	var game: Node = await _open("workshop")
	if win:
		game._story.won.emit()
	else:
		game.finish({"won": false, "quit": true})
	await _until_returned()
	_expect(_game.completed_minigames.has("workshop") == win, "The Workshop's result is recorded normally")


## A card match through the game's own result path: "Back to room" after a won match
## (or after none) reports finish({"won": _ever_won}).
func _cards(win: bool, id: String) -> void:
	var game: Node = await _open(id)
	game._ever_won = win
	game.finish({"won": win, "quit": not win})
	await _until_returned()
	_expect(_result.get("won", false) == win, "%s reports %s" % [id, "a win" if win else "no win"])


func _open(id: String) -> Node:
	_returned = false
	_result = {}
	_launch.call_deferred(id)
	for frame in 600:
		if _games.current != null:
			await process_frame
			return _games.current
		await process_frame
	_expect(false, "%s opens through the normal launcher" % id)
	return null


func _launch(id: String) -> void:
	_result = await _games.play(id)
	_returned = true


func _until_returned() -> void:
	for frame in 600:
		if _returned:
			break
		await process_frame
	await process_frame


func _load_room() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
		await process_frame
	_game.set_flag("room_visited")
	_room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	await _physics(3)


func _board() -> Node3D:
	return _room.get_node("SecretRoom").board


func _shown(board: Node3D) -> Array:
	var names: Array = []
	for entry: Dictionary in Board.STAGES:
		if (board.pieces[entry.stage] as Node3D).visible:
			names.append(entry.stage)
	return names


func _key_l() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_L
		event.physical_keycode = KEY_L
		event.shift_pressed = true
		event.pressed = pressed
		Input.parse_input_event(event)


func _action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _erase_slots() -> void:
	for slot in 4:
		SaveGame.erase(SaveGame.slot_path(slot))


func _physics(count: int) -> void:
	for tick in count:
		await physics_frame


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
