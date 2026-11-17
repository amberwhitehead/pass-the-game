extends Node
## Scene-owned animation transaction. Leaving the table also releases its await.
signal finished
var cancelled := false
var _completed := false
var _tween: Tween
var _cleanup := Callable()

func play(duration: float, update: Callable, cleanup: Callable) -> void:
	_cleanup = cleanup
	update.call(0.0)
	_tween = create_tween()
	_tween.tween_method(update, 0.0, 1.0, duration)
	_tween.finished.connect(_finish)

func _finish() -> void:
	if _completed:
		return
	_completed = true
	if _cleanup.is_valid():
		_cleanup.call()
	finished.emit()
	queue_free()

func _exit_tree() -> void:
	if _completed:
		return
	cancelled = true
	_completed = true
	if _tween:
		_tween.kill()
	if _cleanup.is_valid():
		_cleanup.call()
	finished.emit()
