extends RefCounted
## Lane combat resolves by stable creature identities, with immutable event snapshots.

static func phase(game: RefCounted, side: String, events: Array[Dictionary]) -> void:
	var target_side := "enemy" if side == "player" else "player"
	var defenders: Array = game._enemy if side == "player" else game._player
	var refreshed := false
	for unit: Dictionary in defenders:
		if unit.get("ability", "") == "intercept" and not unit.get("intercept_ready", true):
			unit.intercept_ready = true
			refreshed = true
	if refreshed:
		game._record(events, "ready", "", target_side)
	var board: Array = game._player if side == "player" else game._enemy
	var schedule: Array[int] = []
	for unit: Dictionary in board:
		if not unit.is_empty():
			schedule.append(int(unit.uid))
	for uid in schedule:
		if game._winner != "":
			return
		var lane := _find(board, uid)
		if lane >= 0:
			strike(game, side, lane, events)

static func strike(game: RefCounted, side: String, lane: int, events: Array[Dictionary]) -> void:
	var board: Array = game._player if side == "player" else game._enemy
	if board[lane].is_empty() or int(board[lane].power) <= 0:
		return
	var uid: int = board[lane].uid
	var targets: Array[int] = [lane]
	if board[lane].get("ability", "") == "diagonal":
		targets = []
		for target in [lane - 1, lane + 1]:
			if target >= 0 and target < game.lane_count:
				targets.append(target)
	for target in targets:
		if game._winner != "":
			return
		var current_lane := _find(board, uid)
		if current_lane < 0:
			return
		_hit(game, side, current_lane, target, events)

static func _hit(game: RefCounted, side: String, lane: int, target_lane: int, events: Array[Dictionary]) -> void:
	var board: Array = game._player if side == "player" else game._enemy
	var defenders: Array = game._enemy if side == "player" else game._player
	var target_side := "enemy" if side == "player" else "player"
	var attacker: Dictionary = board[lane]
	if defenders[target_lane].is_empty():
		_intercept(game, target_side, target_lane, events)
	var power: int = attacker.power
	var direct: bool = defenders[target_lane].is_empty()
	var message := ""
	if direct:
		game._balance = clampi(game._balance + (power if side == "player" else -power), -game.goal, game.goal)
		message = "%s hits lane %d directly for %d." % [attacker.name, target_lane + 1, power]
	else:
		defenders[target_lane].hp = maxi(0, int(defenders[target_lane].hp) - power)
		message = "%s hits %s for %d." % [attacker.name, defenders[target_lane].name, power]
	game._record(events, "attack", message, side, lane, target_side, target_lane, power, attacker.id)
	events.back()["direct"] = direct
	if direct:
		game._check_victory(events)
	else:
		game._remove_dead(target_side, target_lane, events)

static func _intercept(game: RefCounted, side: String, target: int, events: Array[Dictionary]) -> void:
	var board: Array = game._player if side == "player" else game._enemy
	# Ascending lane priority makes multiple eligible guards deterministic.
	for source in [target - 1, target + 1]:
		if source < 0 or source >= board.size():
			continue
		var guard: Dictionary = board[source]
		if guard.get("ability", "") != "intercept" or not guard.get("intercept_ready", false):
			continue
		guard.intercept_ready = false
		board[target] = guard
		board[source] = {}
		game._record(events, "intercept", "%s moves from lane %d to block lane %d." % [guard.name, source + 1, target + 1], side, source, side, target, 0, guard.id)
		return

static func _find(board: Array, uid: int) -> int:
	for lane in board.size():
		if board[lane].get("uid", -1) == uid:
			return lane
	return -1
