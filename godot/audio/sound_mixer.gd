extends RefCounted
## Persistent mix preferences; QA's ?muted=1 always wins over saved settings.
signal changed
const SETTINGS := "user://sound.cfg"
var levels := {"Master": .75, "Effects": .85, "Ambience": .65}
var muted := false
var forced_mute := false

func setup() -> void:
	forced_mute = AudioServer.is_bus_mute(0)
	for bus in ["Effects", "Ambience"]:
		if AudioServer.get_bus_index(bus) < 0:
			# Godot 4.7.2 Web's add_bus(-1) reorders the sample buses and can
			# disconnect Master. Growing the count preserves native/Web ordering.
			# https://github.com/godotengine/godot/issues/119026
			AudioServer.bus_count += 1
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var config := ConfigFile.new()
	if config.load(SETTINGS) == OK:
		for bus: String in levels:
			levels[bus] = clampf(float(config.get_value("levels", bus, levels[bus])), 0, 1)
		muted = bool(config.get_value("levels", "muted", false))
	apply()

func set_level(bus: String, value: float) -> void:
	if not levels.has(bus):
		return
	levels[bus] = clampf(value, 0, 1)
	apply()

func set_muted(value: bool) -> void:
	muted = value
	apply()

func apply() -> void:
	for bus: String in levels:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(.0001, levels[bus])))
	AudioServer.set_bus_mute(0, muted or forced_mute)
	changed.emit()

func save() -> void:
	# A forced-silent test run must never overwrite the player's preferences.
	if forced_mute or DisplayServer.get_name() == "headless":
		return
	var config := ConfigFile.new()
	for bus: String in levels:
		config.set_value("levels", bus, levels[bus])
	config.set_value("levels", "muted", muted)
	config.save(SETTINGS)
