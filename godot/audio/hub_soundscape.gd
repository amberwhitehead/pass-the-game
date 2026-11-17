extends Node
## A quiet continuous bed; steps measure actual displacement, including collisions.
var _player: Player
var _bed: AudioStreamPlayer
var _previous := Vector3.ZERO
var _distance := 0.0
var _bed_gain := -22.0

func configure(player: Player) -> void:
	_player = player
	_previous = player.global_position

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var definition: Dictionary = Sound.Bank.CUES["server_hum"]
	_bed_gain = float(definition.db)
	var original := Sound.stream(definition.files[0])
	if original != null:
		var loop := original.duplicate() as AudioStreamOggVorbis
		loop.loop = true
		_bed = AudioStreamPlayer.new()
		_bed.stream = loop
		_bed.bus = "Ambience"
		_bed.volume_db = -60
		add_child(_bed)
		_bed.play()

func _process(delta: float) -> void:
	if _bed != null:
		# The hall recedes during a table encounter, then returns smoothly.
		var target := _bed_gain - 12.0 if MiniGames.is_running() else _bed_gain
		_bed.volume_db = move_toward(_bed.volume_db, target, delta * 24)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var current := _player.global_position
	var travelled := Vector2(current.x - _previous.x, current.z - _previous.z).length()
	_previous = current
	if _player._frozen() or travelled > .5 or travelled < .001:
		_distance = 0
		return
	_distance += travelled
	if _distance >= 1.65:
		_distance = fmod(_distance, 1.65)
		Sound.play("step", self)
