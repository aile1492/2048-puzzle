## grid_board.gd
## Visual grid board for the 2048 game.
## Receives GridLogic signals and animates tile movements.
extends Control

signal move_completed(score_gained: int)
signal board_game_over
signal board_game_won
signal animation_started
signal animation_finished
signal tile_selected(pos: Vector2i)

const TILE_SCENE: PackedScene = preload("res://scenes/game/tile.tscn")
const GRID_CORNER_RADIUS: float = 12.0
const BASE_SLIDE_DURATION: float = 0.12
const BASE_SPAWN_DURATION: float = 0.1


## Returns animation duration adjusted by user's animation speed setting.
## Slow(0.5) = 2x slower, Normal(1.0) = base, Fast(1.5) = 1.5x faster.
static func _anim_duration(base: float) -> float:
	var speed: float = float(SaveManager.get_value("settings", "animation_speed", 1.0))
	if speed <= 0.1:
		speed = 1.0
	return base / speed

var _grid_logic: GridLogic
var _tiles: Dictionary = {}  ## Key: Vector2i, Value: Tile node
var _grid_size: int = 4
var _tile_size: float = 0.0
var _padding: float = 0.0
var _board_size: float = 0.0
var _is_animating: bool = false
var _input_handler: InputHandler

var _grid_bg: ColorRect
var _empty_cells: Array[ColorRect] = []
var _selection_mode: String = ""  # "", "hammer", "bomb"
var _selection_input_blocked: bool = false  ## Block input for 1 frame after popup closes


func _ready() -> void:
	_grid_bg = ColorRect.new()
	_grid_bg.name = "GridBackground"
	_grid_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid_bg)
	_grid_bg.show_behind_parent = true


func initialize(grid_size: int = 4, board_width: float = 950.0, input_handler: InputHandler = null, seed_value: int = -1) -> void:
	_grid_size = grid_size
	_input_handler = input_handler
	_board_size = board_width

	# Calculate tile size and padding
	# padding = board_width * 0.025 (gap between tiles)
	_padding = board_width * 0.025
	_tile_size = (board_width - _padding * (_grid_size + 1)) / _grid_size

	# Set board size
	custom_minimum_size = Vector2(board_width, board_width)
	size = Vector2(board_width, board_width)

	# Background
	_grid_bg.size = Vector2(board_width, board_width)
	_grid_bg.position = Vector2.ZERO
	var ui_colors: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	_grid_bg.color = ui_colors["grid_bg"]

	# Create empty cell backgrounds
	_create_empty_cells()

	# Initialize game logic
	_grid_logic = GridLogic.new()
	_grid_logic.game_over.connect(_on_game_over)
	_grid_logic.game_won.connect(_on_game_won)
	_grid_logic.initialize(grid_size, seed_value)

	# Create initial tiles
	for r in grid_size:
		for c in grid_size:
			if _grid_logic.grid[r][c] != 0:
				_create_tile(Vector2i(r, c), _grid_logic.grid[r][c])

	# Connect input handler
	if _input_handler:
		_input_handler.swipe_detected.connect(_on_swipe)


func _create_empty_cells() -> void:
	for cell: ColorRect in _empty_cells:
		cell.queue_free()
	_empty_cells.clear()

	var ui_colors: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	for r in _grid_size:
		for c in _grid_size:
			var cell := ColorRect.new()
			cell.size = Vector2(_tile_size, _tile_size)
			cell.position = _calculate_position(r, c)
			cell.color = ui_colors["empty_cell"]
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(cell)
			cell.show_behind_parent = false
			_empty_cells.append(cell)


func _calculate_position(row: int, col: int) -> Vector2:
	var x := _padding + col * (_tile_size + _padding)
	var y := _padding + row * (_tile_size + _padding)
	return Vector2(x, y)


func _create_tile(pos: Vector2i, value: int) -> Control:
	var tile: Control = TILE_SCENE.instantiate()
	add_child(tile)
	tile.position = _calculate_position(pos.x, pos.y)
	tile.setup(value, _tile_size, _grid_size)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tiles[pos] = tile
	return tile


func _on_swipe(direction: int) -> void:
	if _is_animating:
		return
	execute_move(direction)


func execute_move(direction: int) -> void:
	if _is_animating:
		if _input_handler and _input_handler.has_method("buffer_input"):
			_input_handler.buffer_input(direction)
		return

	var result: Dictionary = _grid_logic.move(direction)
	if not result["moved"]:
		return

	_is_animating = true
	if _input_handler:
		_input_handler.is_animating = true
	animation_started.emit()

	# Animate all movements simultaneously
	var movements: Array = result["movements"]
	var tween := create_tween().set_parallel(true)
	var merge_tiles: Array = []  ## Tiles that need merge animation after slide
	var tiles_to_remove: Array = []  ## Old tile positions to clean up

	# Collect movements and animate slides
	var new_tile_map: Dictionary = {}

	for m: TileMovement in movements:
		if not _tiles.has(m.from_pos):
			continue

		var tile: Control = _tiles[m.from_pos]
		var target_pos := _calculate_position(m.to_pos.x, m.to_pos.y)

		tween.tween_property(tile, "position", target_pos, _anim_duration(BASE_SLIDE_DURATION)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		if m.merged:
			# This tile will be removed after slide
			tiles_to_remove.append({"tile": tile, "pos": m.to_pos, "merge_value": m.merge_value})
		else:
			# Regular move
			new_tile_map[m.to_pos] = tile

	# Play slide sound
	AudioManager.play_sfx("tile_slide")
	Haptics.light()

	tween.finished.connect(_on_slide_complete.bind(result, new_tile_map, tiles_to_remove, merge_tiles))


func _on_slide_complete(result: Dictionary, new_tile_map: Dictionary, tiles_to_remove: Array, _merge_tiles: Array) -> void:
	# Remove all old tile references
	_tiles.clear()

	# Register moved tiles
	for pos: Vector2i in new_tile_map:
		_tiles[pos] = new_tile_map[pos]

	# Handle merges: remove secondary tiles, update primary tile value
	var max_merge_value: int = 0
	for info: Dictionary in tiles_to_remove:
		var tile: Control = info["tile"]
		var merge_pos: Vector2i = info["pos"]
		var merge_value: int = info["merge_value"]

		# Remove the secondary merged tile
		tile.queue_free()

		# Update the primary tile at the merge position
		if _tiles.has(merge_pos):
			_tiles[merge_pos].set_value(merge_value, _grid_size)
			_tiles[merge_pos].animate_merge()

		if merge_value > max_merge_value:
			max_merge_value = merge_value

	# Play merge sound based on highest merge value
	if max_merge_value > 0:
		if max_merge_value >= 1024:
			AudioManager.play_sfx("merge_large", 1.0 + (max_merge_value / 4096.0) * 0.3)
			Haptics.heavy()
		elif max_merge_value >= 128:
			AudioManager.play_sfx("merge_medium")
			Haptics.medium()
		else:
			AudioManager.play_sfx("merge_small")
			Haptics.medium()

	# Spawn new tile
	var spawn_pos: Vector2i = result["spawned_pos"]
	var spawn_value: int = result["spawned_value"]
	if spawn_pos != Vector2i(-1, -1):
		var new_tile := _create_tile(spawn_pos, spawn_value)
		new_tile.animate_spawn()
		AudioManager.play_sfx("tile_spawn")

	move_completed.emit(result["score_gained"])

	_is_animating = false
	if _input_handler:
		_input_handler.is_animating = false
	animation_finished.emit()

	# Process buffered input
	if _input_handler:
		var buffered := _input_handler.pop_buffered_input()
		if buffered >= 0:
			call_deferred("execute_move", buffered)


func _on_game_over() -> void:
	board_game_over.emit()


func _on_game_won() -> void:
	board_game_won.emit()


func new_game(grid_size: int = 4, seed_value: int = -1) -> void:
	# Clear existing tiles
	for pos: Vector2i in _tiles:
		_tiles[pos].queue_free()
	_tiles.clear()
	_is_animating = false

	# Reinitialize
	_grid_size = grid_size
	_padding = _board_size * 0.025
	_tile_size = (_board_size - _padding * (_grid_size + 1)) / _grid_size

	_create_empty_cells()

	_grid_logic.initialize(grid_size, seed_value)

	for r in grid_size:
		for c in grid_size:
			if _grid_logic.grid[r][c] != 0:
				_create_tile(Vector2i(r, c), _grid_logic.grid[r][c])


func undo() -> bool:
	if _is_animating:
		return false
	if not _grid_logic.undo():
		return false
	_rebuild_tiles()
	AudioManager.play_sfx("undo")
	return true


func continue_after_win() -> void:
	_grid_logic.continue_after_win()


func _rebuild_tiles() -> void:
	for pos: Vector2i in _tiles:
		_tiles[pos].queue_free()
	_tiles.clear()

	for r in _grid_size:
		for c in _grid_size:
			if _grid_logic.grid[r][c] != 0:
				_create_tile(Vector2i(r, c), _grid_logic.grid[r][c])


func get_logic() -> GridLogic:
	return _grid_logic


func restore_from_dict(data: Dictionary) -> void:
	for pos: Vector2i in _tiles:
		_tiles[pos].queue_free()
	_tiles.clear()

	_grid_size = data.get("grid_size", 4)
	_padding = _board_size * 0.025
	_tile_size = (_board_size - _padding * (_grid_size + 1)) / _grid_size

	_create_empty_cells()

	_grid_logic = GridLogic.new()
	_grid_logic.game_over.connect(_on_game_over)
	_grid_logic.game_won.connect(_on_game_won)
	_grid_logic.from_dict(data)

	for r in _grid_size:
		for c in _grid_size:
			if _grid_logic.grid[r][c] != 0:
				_create_tile(Vector2i(r, c), _grid_logic.grid[r][c])


func get_score() -> int:
	return _grid_logic.score


func get_highest_tile() -> int:
	return _grid_logic.highest_tile


func get_move_count() -> int:
	return _grid_logic.move_count


func refresh_theme() -> void:
	var ui_colors: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	_grid_bg.color = ui_colors["grid_bg"]
	for cell: ColorRect in _empty_cells:
		cell.color = ui_colors["empty_cell"]
	for pos: Vector2i in _tiles:
		_tiles[pos].set_value(_tiles[pos].value, _grid_size)


## Power-up: Enter tile selection mode (hammer/bomb)
func enter_selection_mode(type: String) -> void:
	_selection_mode = type
	mouse_filter = Control.MOUSE_FILTER_STOP
	for pos: Vector2i in _tiles:
		_tiles[pos].modulate = Color(1, 1, 1, 0.8)


func exit_selection_mode() -> void:
	_selection_mode = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pos: Vector2i in _tiles:
		_tiles[pos].modulate = Color.WHITE


func is_in_selection_mode() -> bool:
	return _selection_mode != ""


func _input(event: InputEvent) -> void:
	if _selection_mode == "" or _is_animating:
		return
	if ScreenManager.has_popups():
		# A popup just opened or is open — block and set guard for when it closes
		_selection_input_blocked = true
		return
	if _selection_input_blocked:
		# Popup just closed this frame — skip this input, unblock next frame
		_selection_input_blocked = false
		get_viewport().set_input_as_handled()
		return

	var screen_pos: Vector2 = Vector2.ZERO
	var is_press: bool = false

	if event is InputEventScreenTouch and event.pressed:
		screen_pos = event.position
		is_press = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		screen_pos = event.position
		is_press = true

	if not is_press:
		return

	# Convert screen position to grid-local position
	var local_pos: Vector2 = screen_pos - global_position
	var col: int = int((local_pos.x - _padding) / (_tile_size + _padding))
	var row: int = int((local_pos.y - _padding) / (_tile_size + _padding))
	if row >= 0 and row < _grid_size and col >= 0 and col < _grid_size:
		tile_selected.emit(Vector2i(row, col))
		get_viewport().set_input_as_handled()


## Power-up: Apply hammer (remove single tile)
func apply_hammer(pos: Vector2i) -> bool:
	if not _grid_logic.remove_tile(pos):
		return false
	_animate_remove([pos])
	return true


## Power-up: Apply bomb (remove tile + adjacent)
func apply_bomb(pos: Vector2i) -> Array[Vector2i]:
	var removed: Array[Vector2i] = _grid_logic.remove_area(pos)
	if removed.is_empty():
		return removed
	_animate_remove(removed)
	return removed


## Power-up: Apply shuffle. Returns false if blocked (too few tiles).
func apply_shuffle() -> bool:
	if not _grid_logic.shuffle_tiles():
		return false
	_rebuild_tiles()
	return true


func _animate_remove(positions: Array) -> void:
	for pos in positions:
		if _tiles.has(pos):
			var tile: Control = _tiles[pos]
			tile.pivot_offset = tile.size / 2.0
			var tween := create_tween()
			tween.tween_property(tile, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
			tween.tween_callback(tile.queue_free)
			_tiles.erase(pos)
