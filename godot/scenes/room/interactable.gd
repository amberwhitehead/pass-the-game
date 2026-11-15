class_name Interactable
extends Area3D
## Base for anything the player can walk up to and press A on.
## Set `minigame_id` (see autoload/minigames.gd) to open a mini-game.

signal interacted

@export var prompt := "Use"
@export var minigame_id := ""

var focused := false


func _ready() -> void:
	add_to_group("interactable")


func interact(_player: Node3D) -> void:
	if minigame_id != "":
		await MiniGames.play(minigame_id)
	interacted.emit()


func set_focused(value: bool) -> void:
	focused = value
	_on_focus_changed(value)


func _on_focus_changed(_value: bool) -> void:
	pass
