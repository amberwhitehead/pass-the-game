extends RefCounted
## The cabinet's high score, kept on this machine (user://chrono_raider.json), separate
## from save slots. A missing or damaged file just means a fresh table.

const DEFAULT_PATH := "user://chrono_raider.json"
const DEFAULT_HIGH := 20000

static var path := DEFAULT_PATH


static func load_high() -> int:
	if not FileAccess.file_exists(path):
		return DEFAULT_HIGH
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and (data.get("high") is float or data.get("high") is int):
		return maxi(DEFAULT_HIGH, int(data.high))
	return DEFAULT_HIGH


static func save_high(score: int) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"high": score}))
