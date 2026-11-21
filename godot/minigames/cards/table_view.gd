extends Control
## Seated first-person table. Cards and the turn bell are physical raycast targets.
signal hand_chosen(index: int)
signal lane_chosen(side: String, lane: int)
signal end_requested
signal rules_requested
signal restart_requested
const Style := preload("res://ui/game_style.gd")
const World := preload("res://minigames/cards/table_world.gd")
const Actor := preload("res://minigames/cards/card_actor.gd")
const Accessories := preload("res://minigames/cards/table_accessories.gd")
const Attention := preload("res://minigames/cards/table_attention.gd")
const Bell := preload("res://minigames/cards/table_button.gd")
const HUD := preload("res://minigames/cards/table_hud.gd")
const Effects := preload("res://minigames/cards/table_effects.gd")
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const Hand := preload("res://minigames/cards/table_hand.gd")
const IntentGlow := preload("res://minigames/cards/lane_intent.gd")
const Layout := preload("res://minigames/cards/table_layout.gd")
const Preview := preload("res://minigames/cards/table_preview.gd")
var opponent_id := "little_brother"
var lane_count := 3
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var hud: Control
var player_slots: Array = []
var enemy_slots: Array = []
var hand_cards: Array = []
var hand: Node3D
var intent_glow: Node3D
var end_button: Node3D
var score_marker: MeshInstance3D
var banter: Label
var hint: Label
var history: RichTextLabel
var locked := true
## True while a controller drives the focus (table_pad.gd); moving the mouse clears it.
var pad_active := false
var _accessories: Node3D
var _attention: Node3D
var _preview: Node3D
var _swap_source := -1
var _hand_ids: Array = []
var _hovered: Node3D
var _selected := -1
var _state: Dictionary = {}
var _pointer := Vector2(-1, -1)

func _ready() -> void:
	lane_count = 4 if opponent_id == "older_brother" else 3
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Rendering lifetime is independent of presentation visibility. A hidden
	# SubViewportContainer disables its child viewport, which breaks live portals.
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	resized.connect(_resize_viewport)
	_resize_viewport()
	var surface := TextureRect.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	surface.stretch_mode = TextureRect.STRETCH_SCALE
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.texture = viewport.get_texture()
	add_child(surface)
	world = World.new()
	world.lane_count = lane_count
	world.opponent_id = opponent_id
	viewport.add_child(world)
	camera = Camera3D.new()
	fit_camera()
	camera.position = Vector3(0, 4.85, 3.9) if lane_count == 4 else Vector3(0, 4.6, 3.65)
	world.add_child(camera)
	camera.look_at(Vector3(0, 0, -0.65))
	camera.current = true
	_build_cards()
	_build_accessories()
	_preview = Preview.new()
	world.add_child(_preview)
	hand = Hand.new()
	camera.add_child(hand)
	hand_cards = hand.cards
	hand.chosen.connect(func(index: int): hand_chosen.emit(index))
	hud = HUD.new()
	add_child(hud)
	banter = hud.banter
	hint = hud.hint
	history = hud.history
	hud.rules_requested.connect(func(): rules_requested.emit())
	hud.restart_requested.connect(func(): restart_requested.emit())

func _resize_viewport() -> void:
	viewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	fit_camera()

func fit_camera() -> void:
	if camera != null:
		camera.fov = Layout.camera_fov(lane_count, Vector2(viewport.size))

func _build_cards() -> void:
	for side in ["enemy", "player"]:
		for lane in lane_count:
			var card := Actor.new()
			world.add_child(card)
			card.position = lane_position(side, lane)
			card.pressed.connect(func(): lane_chosen.emit(side, lane))
			if side == "player":
				player_slots.append(card)
			else:
				enemy_slots.append(card)

func _build_accessories() -> void:
	var extension := Layout.side_extension(lane_count)
	end_button = Bell.new()
	world.add_child(end_button)
	end_button.position = Vector3(2.65 + extension, 0.04, 0.65)
	end_button.pressed.connect(func(): end_requested.emit())
	intent_glow = IntentGlow.new()
	intent_glow.lane_count = lane_count
	world.add_child(intent_glow)
	_accessories = Accessories.new()
	world.add_child(_accessories)
	_accessories.position.x = -extension
	score_marker = _accessories.marker
	_attention = Attention.new()
	world.add_child(_attention)
	_attention.position.x += extension

func lane_position(side: String, lane: int) -> Vector3:
	return Layout.lane_position(side, lane, lane_count)

func draw_position() -> Vector3:
	return _accessories.position + Accessories.DRAW_CENTER + Vector3.UP * .3

func render(state: Dictionary, selected: int, blocked: bool, swap_source := -1) -> void:
	_state = state
	_selected = selected
	_swap_source = swap_source
	locked = blocked
	hud.render(state, locked)
	_accessories.render(state.balance, state.deck_count, int(state.get("goal", 10)), int(state.get("enemy_deck_count", -1)))
	_attention.render(state.energy, state.max_energy)
	intent_glow.set_intents(state.intent)
	for side in ["player", "enemy"]:
		for lane in lane_count:
			var card: Node3D = slot(side, lane)
			var unit: Dictionary = state[side][lane]
			if unit.is_empty():
				card.set_empty("Lane %d" % (lane + 1), side)
			else:
				card.configure(unit, true)
			var eligible := _eligible(side, lane)
			card.set_selected(eligible)
			# Mark every place the selected card can go: red to hit, gold to place or heal.
			card.set_cue((Actor.Cue.HOSTILE if side == "enemy" else Actor.Cue.TARGET) if eligible else Actor.Cue.NONE)
			card.disabled = locked
	if _hand_ids != state.hand:
		_set_hover(null)
		_hand_ids = state.hand.duplicate()
	hand.render(state.hand, state.energy, selected, locked)
	end_button.disabled = locked
	# With nothing selected, the cards you can afford pulse; with none, the bell does.
	var playable := false
	for id in state.hand:
		if int(Catalog.get_card(id).cost) <= int(state.energy):
			playable = true
	end_button.set_cue(not locked and selected < 0 and not playable)
	if locked:
		_set_hover(null)
	elif selected >= 0:
		hud.show_card(Catalog.get_card(state.hand[selected]))
	_update_preview()

func _eligible(side: String, lane: int) -> bool:
	if locked or _selected < 0 or _selected >= _state.hand.size():
		return false
	var card: Dictionary = Catalog.get_card(_state.hand[_selected])
	var unit: Dictionary = _state[side][lane]
	if card.cost > _state.energy:
		return false
	match card.kind:
		"unit": return side == "player" and unit.is_empty()
		"damage": return side == "enemy" and not unit.is_empty()
		"heal": return side == "player" and not unit.is_empty() and unit.hp < unit.max_hp
		"swap":
			if side != "player" or unit.is_empty():
				return false
			if _swap_source >= 0:
				return lane == _swap_source or absi(lane - _swap_source) == 1
			for neighbor in [lane - 1, lane + 1]:
				if neighbor >= 0 and neighbor < lane_count and not _state.player[neighbor].is_empty():
					return true
	return false

func slot(side: String, lane: int) -> Node3D:
	if lane < 0 or lane >= lane_count:
		return null
	return player_slots[lane] if side == "player" else enemy_slots[lane]

func pick_actor(screen_position: Vector2) -> Node3D:
	if size.x <= 0 or size.y <= 0:
		return null
	var point := screen_position * Vector2(viewport.size) / size
	var origin := camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * 30, 1)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider.get_meta("card_actor", null) if not hit.is_empty() else null

func activate_at(screen_position: Vector2) -> void:
	if locked or Sound.settings_open:
		return
	activate(pick_actor(screen_position))

## Presses a target as a click on it would: from the pointer, or the controller's focus.
func activate(actor: Node3D) -> void:
	if locked or Sound.settings_open:
		return
	if actor != null and not actor.disabled:
		if actor == end_button:
			end_button.press_animation()
		actor.pressed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if Sound.settings_open:
		return
	if event is InputEventMouseMotion and event.device != -1 and not locked:
		if pad_active and event.relative.length() < 4.0:
			return  # A nudged mouse or trackpad doesn't take the table back from the controller.
		pad_active = false
		_pointer = event.position - global_position
		hand.pointer_at(_pointer, size)
		_set_hover(pick_actor(_pointer))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.device != -1:
		activate_at(event.position - global_position)
	elif event is InputEventScreenTouch and event.pressed and event.device != -1:
		# Mouse-to-touch emulation emits a second event; only handle real fingers here.
		var point: Vector2 = event.position - global_position
		var actor := pick_actor(point)
		if (actor == null or actor in hand_cards) and hand.reveal_touch(point, size):
			return
		activate_at(point)

func _process(_delta: float) -> void:
	# Re-pick a stationary pointer while the hand moves under it.
	if not locked and not pad_active and _pointer.x >= 0 and not hand.is_settled():
		_set_hover(pick_actor(_pointer))

func _set_hover(actor: Node3D) -> void:
	if is_instance_valid(_hovered) and _hovered != actor:
		_hovered.set_hovered(false)
	_hovered = actor
	var data: Dictionary = {}
	if is_instance_valid(actor):
		actor.set_hovered(true)
		if actor != end_button:
			data = actor.card_data
	if data.is_empty() and not locked and _selected >= 0 and _selected < _state.get("hand", []).size():
		data = Catalog.get_card(_state.hand[_selected])
	if hud != null:
		hud.show_card(data)
	_update_preview()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if actor != null else Control.CURSOR_ARROW

func _update_preview() -> void:
	if _preview == null:
		return
	if locked or not is_instance_valid(_hovered):
		_preview.clear()
		return
	var side := "player" if _hovered in player_slots else "enemy"
	var slots: Array = player_slots if side == "player" else enemy_slots
	var lane := slots.find(_hovered)
	if lane < 0:
		_preview.clear()
		return
	var card: Dictionary = _hovered.card_data
	if card.is_empty() and side == "player" and _selected >= 0 and _selected < _state.get("hand", []).size():
		card = Catalog.get_card(_state.hand[_selected])
	_preview.show_paths(self, side, lane, card, _state)

func animate_before(event: Dictionary) -> void:
	preload("res://audio/card_sound.gd").before(self, event)
	await Effects.before(self, event)

func animate_after(event: Dictionary) -> void:
	await Effects.after(self, event)
	if not is_inside_tree():
		return
	preload("res://audio/card_sound.gd").after(self, event)
