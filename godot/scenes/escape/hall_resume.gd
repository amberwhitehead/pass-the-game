extends Node
## Puts the player back where they were: the spot and facing in the hall, and, if the
## page was closed or reloaded inside a room, back into that room.
##
## The spot is saved every few seconds while the player moves (flag HALL_SPOT_FLAG).
## MiniGames records the room being played (MiniGames.RESUME_FLAG) and clears it when the
## player leaves it, so only an interrupted visit reopens the room on Continue.
## Nothing is written while autosave is off (tests, the save editor's unsaved play).

const HALL_SPOT_FLAG := "hall_spot"
const SAVE_EVERY := 3.0     ## Seconds between checks while in the hall.
const MIN_MOVE := 0.25      ## Metres (or radians of turn) that count as having moved.

var _player: Node3D
var _since := 0.0


func configure(player: Node3D) -> void:
	_player = player


## Moves the player to the saved spot, if there is one. Returns true if it did.
func restore_spot() -> bool:
	var spot: Variant = Game.get_flag(HALL_SPOT_FLAG, {})
	if not spot is Dictionary or not (spot.get("position") is Vector3):
		return false
	_player.position = spot.position
	_player.rotation.y = float(spot.get("yaw", _player.rotation.y))
	_player.camera.rotation.x = float(spot.get("pitch", 0.0))
	return true


## Reopens the room the player was in when the page closed, through its station in the
## hall so everything that normally follows a visit still happens.
func resume_minigame(stations: Array[Node]) -> void:
	var id := str(Game.get_flag(MiniGames.RESUME_FLAG, ""))
	if id == "":
		return
	for station in stations:
		if station is Interactable and station.minigame_id == id and station.is_inside_tree():
			station.interact(_player)
			return
	Game.set_flag(MiniGames.RESUME_FLAG, "")  # The room is gone; start in the hall.


func _process(delta: float) -> void:
	if _player == null or not Game.autosave or MiniGames.is_running():
		return
	_since += delta
	if _since < SAVE_EVERY:
		return
	_since = 0.0
	save_spot()


func save_spot() -> void:
	var spot := {"position": _player.position, "yaw": _player.rotation.y, "pitch": _player.camera.rotation.x}
	var old: Variant = Game.get_flag(HALL_SPOT_FLAG, {})
	if old is Dictionary and old.get("position") is Vector3 \
			and (old.position as Vector3).distance_to(spot.position) < MIN_MOVE \
			and absf(float(old.get("yaw", 0.0)) - spot.yaw) < MIN_MOVE \
			and absf(float(old.get("pitch", 0.0)) - spot.pitch) < MIN_MOVE:
		return
	Game.set_flag(HALL_SPOT_FLAG, spot)
