## input_handler.gd
## Detects swipe gestures across the full screen area.
## Supports input buffering during animations.
class_name InputHandler
extends Node

signal swipe_detected(direction: int)

## Minimum distance in pixels for a valid swipe
var min_swipe_distance: float = 30.0

## Set to true while animations are playing to enable buffering
var is_animating: bool = false

var _touch_start: Vector2 = Vector2.ZERO
var _is_touching: bool = false
var _input_buffer: int = -1  ## Buffered direction (-1 = empty)
var _touch_id: int = -1      ## Track first touch only


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if not _is_touching:
				_is_touching = true
				_touch_start = touch.position
				_touch_id = touch.index
		else:
			if _is_touching and touch.index == _touch_id:
				_handle_swipe_end(touch.position)
				_is_touching = false
				_touch_id = -1

	elif event is InputEventScreenDrag:
		# We handle swipe on touch end, not during drag
		pass


func _handle_swipe_end(end_pos: Vector2) -> void:
	var delta := end_pos - _touch_start
	var distance := delta.length()

	if distance < min_swipe_distance:
		return  ## Too short — treat as tap

	var direction: int = -1
	if absf(delta.x) > absf(delta.y):
		# Horizontal swipe
		direction = GridLogic.Direction.RIGHT if delta.x > 0 else GridLogic.Direction.LEFT
	else:
		# Vertical swipe
		direction = GridLogic.Direction.DOWN if delta.y > 0 else GridLogic.Direction.UP

	if is_animating:
		_input_buffer = direction
	else:
		swipe_detected.emit(direction)


func buffer_input(direction: int) -> void:
	## Public API for buffering input from external callers (#10 - encapsulation).
	_input_buffer = direction


func pop_buffered_input() -> int:
	var buffered := _input_buffer
	_input_buffer = -1
	return buffered


func set_sensitivity(multiplier: float) -> void:
	## multiplier: 0.5 (low) to 1.5 (high)
	min_swipe_distance = 30.0 / multiplier
