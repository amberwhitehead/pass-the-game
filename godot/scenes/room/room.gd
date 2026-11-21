extends Node3D
## Hub composition only. Architecture, optics, carrying and cinematics are separate modules.

const Architecture := preload("res://scenes/escape/hub_architecture.gd")
const Inventory := preload("res://scenes/escape/carry_inventory.gd")
const HeldVisual := preload("res://scenes/escape/carry_visual.gd")
const Optics := preload("res://scenes/escape/optics_controller.gd")
const Reward := preload("res://scenes/escape/reward_pedestal.gd")
const Reveal := preload("res://scenes/escape/reward_reveal.gd")
const HUD := preload("res://scenes/escape/hub_hud.gd")
const Soundscape := preload("res://audio/hub_soundscape.gd")
const CardCache := preload("res://scenes/escape/card_cache.gd")
const SecretRoom := preload("res://scenes/escape/secret_room.gd")
const Revisits := preload("res://scenes/escape/revisits.gd")
const HallResume := preload("res://scenes/escape/hall_resume.gd")

@onready var _player: Player = $Player
var inventory: Node
var optics: Node3D
var reward_pedestal: Node3D
var reward_reveal: Node
var architecture: Dictionary
var hud: CanvasLayer
var revisits: Node3D
var resume: Node  ## HallResume: the saved spot, and reopening an interrupted room.
var _reward_pending := false


func _ready() -> void:
	TouchControls.set_enabled(true)
	var old_floor := $HexFloor
	remove_child(old_floor)
	old_floor.queue_free()
	$DoorEast.queue_free()
	architecture = Architecture.build(self)
	_move_stations()
	inventory = Inventory.new()
	inventory.name = "CarryInventory"
	add_child(inventory)
	hud = HUD.new()
	hud.name = "HubHUD"
	hud.configure(_player, inventory)
	add_child(hud)
	var cards := CardCache.new()
	cards.name = "FoundCards"
	cards.message.connect(hud.notify)
	add_child(cards)
	optics = Optics.new()
	optics.name = "Optics"
	optics.configure(inventory, _player)
	optics.aiming_changed.connect(hud.set_aiming)
	optics.solved.connect(_on_prism_solved)
	optics.message.connect(hud.notify)
	add_child(optics)
	_create_rewards()
	# Changes in the hall after other rooms are won; see docs/INTERCONNECTION.md.
	revisits = Revisits.new()
	add_child(revisits)
	revisits.configure(inventory, $Challenge1, $Egyptian, $Engineer)
	revisits.message.connect(hud.notify)
	optics.sun_restored.connect(revisits.refresh)
	var secret := SecretRoom.new()
	secret.configure(_player)
	add_child(secret)
	var held := HeldVisual.new()
	held.configure(inventory, _player.camera)
	if held.get_parent() == null:
		_player.camera.add_child(held)
	MiniGames.ended.connect(_on_minigame_ended)
	if Game.get_flag("escape_prism_solved"):
		architecture.locked_door.unlock(false)
	_start_at_entrance()
	resume = HallResume.new()
	resume.name = "HallResume"
	resume.configure(_player)
	add_child(resume)
	resume.restore_spot()
	var soundscape := Soundscape.new()
	soundscape.name = "HubSoundscape"
	add_child(soundscape)
	soundscape.configure(_player)
	if Game.completed_minigames.has("newton") and not Game.get_flag("escape_rewards_revealed"):
		_on_minigame_ended.call_deferred("newton", {"won": true})
	else:
		resume.resume_minigame.call_deferred(get_tree().get_nodes_in_group("interactable"))


func _move_stations() -> void:
	for node_name: String in architecture.stations:
		var station := get_node(node_name) as Node3D
		var placement: Dictionary = architecture.stations[node_name]
		station.position = placement.position
		station.rotation.y = placement.rotation_y
	$Major.position = Vector3(-10.1, 0, -2.6)
	$Colonel.position = Vector3(-10.1, 0, 2.6)
	$Major.rotation.y = PI / 2
	$Colonel.rotation.y = PI / 2
	$MetricB.position = Vector3(8.7, 0, -6.7)
	$MetricB.rotation.y = PI
	$Egyptian.lines.assign(["The amber room is yours. Solve the pyramid, and I will give you two prisms for the hall."])
	$Egyptian.lines_repeat.assign(["The reward appears beside the doorway. The light in the hall needs it."])
	$Colonel.lines_repeat.assign(["Start with Egypt. The green light will get you into Rome. I don't make the rules."])
	$Major.lines.assign(["Each room holds a test. The machines out here connect them. Start in the amber room."])
	$DoorWest.position = Vector3(-11, 0, 0)
	$DoorWest.rotation.y = PI / 2
	$DoorWest.locked_message = "The exit is sealed. The amber room is a better place to start."


func _create_rewards() -> void:
	reward_pedestal = Reward.new()
	reward_pedestal.name = "PrismReward"
	reward_pedestal.position = Vector3(-4.4, 0, -10.0)
	reward_pedestal.rotation.y = -PI / 2
	reward_pedestal.configure(inventory)
	add_child(reward_pedestal)
	reward_reveal = Reveal.new()
	reward_reveal.name = "RewardReveal"
	reward_reveal.configure(_player, reward_pedestal, $Egyptian)
	reward_reveal.caption.connect(func(text: String): hud.notify(text, 6.0))
	reward_reveal.finished.connect(func(): hud.refresh_objective())
	add_child(reward_reveal)
	if Game.get_flag("escape_rewards_revealed"):
		reward_pedestal.reveal(false)
	for slot: Node in reward_pedestal.slots:
		slot.message.connect(hud.notify)


func _start_at_entrance() -> void:
	_player.position = Vector3(-9.5, 0, .4)
	_player.rotation.y = -PI / 2
	$DoorWest.set_open(false, false)
	Game.set_flag("room_visited")


func _on_minigame_ended(id: String, result: Dictionary) -> void:
	if id != "newton" or not result.get("won", false):
		return
	if _reward_pending or Game.get_flag("escape_rewards_revealed"):
		return
	_reward_pending = true
	await get_tree().process_frame
	if not is_inside_tree():
		return
	Game.set_flag("escape_rewards_revealed")
	hud.refresh_objective()
	reward_reveal.play()
	$Egyptian.lines_repeat.assign(["Two prisms, one pair of hands. Take them to the hall, one at a time. The lenses can move too."])


## Children (wheel aiming, the reward reveal) see back first; the menu gets what's left.
func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("back") or event.is_action_pressed("pause")) and not event.is_echo() and not Sound.settings_open:
		get_viewport().set_input_as_handled()
		PauseMenu.open_hall()


func _on_prism_solved() -> void:
	Game.set_flag("escape_prism_solved")
	architecture.locked_door.unlock()
	hud.refresh_objective()
	hud.notify("The green receiver catches. Room 2 is open.", 6.0)
