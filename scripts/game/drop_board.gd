## drop_board.gd
## Visual board for Drop mode - tiles drop from top into columns.
## Implements: design/gdd/drop_mode.md
## Features: floating score labels + combo overlay (task 1),
##            continue_game() via clear_top_rows (task 2),
##            ghost tile uses next_queue[0] (task 3).
extends Control

signal move_completed(score_gained: int)
signal board_game_over
signal board_game_won

const TILE_SCENE: PackedScene = preload("res://scenes/game/tile.tscn")

var _logic: DropLogic
var _tiles: Dictionary = {}  ## Key: Vector2i(row,col), Value: Tile node
var _cols: int = 5
var _rows: int = 8
var _tile_size: float = 0.0
var _padding: float = 0.0
var _board_width: float = 0.0
var _board_height: float = 0.0
var _is_animating: bool = false
var _selected_col: int = 2  ## Currently highlighted column (default: center)

var _grid_bg: ColorRect
var _empty_cells: Array[ColorRect] = []
var _col_highlight: ColorRect  ## Semi-transparent highlight on selected column
var _next_preview: Control  ## Preview of next tile above the grid
var _danger_line: ColorRect  ## Red line at top row
var _ghost_tile: Control  ## Ghost preview showing where tile will land


func _ready() -> void:
	_grid_bg = ColorRect.new()
	_grid_bg.name = "GridBackground"
	_grid_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid_bg)
	_grid_bg.show_behind_parent = true


func initialize(board_width: float = 950.0) -> void:
	_board_width = board_width
	_cols = 5
	_rows = 8

	_padding = board_width * 0.02
	_tile_size = (board_width - _padding * (_cols + 1)) / _cols
	_board_height = _tile_size * _rows + _padding * (_rows + 1)

	custom_minimum_size = Vector2(board_width, _board_height)
	size = Vector2(board_width, _board_height)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var ui_colors: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	_grid_bg.size = Vector2(board_width, _board_height)
	_grid_bg.position = Vector2.ZERO
	_grid_bg.color = ui_colors["grid_bg"]

	_create_empty_cells()
	_create_column_highlight()
	_create_danger_line()

	# Clean up old logic signals if reinitializing
	if _logic:
		if _logic.game_over.is_connected(_on_game_over):
			_logic.game_over.disconnect(_on_game_over)
		if _logic.game_won.is_connected(_on_game_won):
			_logic.game_won.disconnect(_on_game_won)

	_logic = DropLogic.new()
	_logic.game_over.connect(_on_game_over)
	_logic.game_won.connect(_on_game_won)
	_logic.initialize(_cols, _rows)
	_update_ghost_tile()


func _create_empty_cells() -> void:
	for cell: ColorRect in _empty_cells:
		cell.queue_free()
	_empty_cells.clear()

	var ui_colors: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	for r in _rows:
		for c in _cols:
			var cell := ColorRect.new()
			cell.size = Vector2(_tile_size, _tile_size)
			cell.position = _calculate_position(r, c)
			cell.color = ui_colors["empty_cell"]
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(cell)
			cell.show_behind_parent = false
			_empty_cells.append(cell)


func _create_column_highlight() -> void:
	if _col_highlight:
		_col_highlight.queue_free()
	_col_highlight = ColorRect.new()
	_col_highlight.name = "ColumnHighlight"
	_col_highlight.color = Color(1, 1, 1, 0.08)
	_col_highlight.size = Vector2(_tile_size + _padding, _board_height)
	_col_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_column_highlight()
	add_child(_col_highlight)


func _create_danger_line() -> void:
	if _danger_line:
		_danger_line.queue_free()
	_danger_line = ColorRect.new()
	_danger_line.name = "DangerLine"
	_danger_line.color = Color("F65E3B", 0.3)
	_danger_line.size = Vector2(_board_width, 3)
	_danger_line.position = Vector2(0, _padding + _tile_size + _padding / 2 - 1.5)
	_danger_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger_line)


func _update_column_highlight() -> void:
	if _col_highlight:
		var x: float = _padding / 2 + _selected_col * (_tile_size + _padding)
		_col_highlight.position = Vector2(x, 0)
	_update_ghost_tile()


func _update_ghost_tile() -> void:
	if not _logic:
		return
	# Remove old ghost
	if _ghost_tile:
		_ghost_tile.queue_free()
		_ghost_tile = null

	var landing_row: int = _logic.get_landing_row(_selected_col)
	if landing_row < 0:
		return

	# Task 3: use next_queue[0] so the ghost matches what will actually drop
	var ghost_value: int = _logic.next_queue[0] if _logic.next_queue.size() > 0 else _logic.next_value

	# Create ghost tile at landing position
	_ghost_tile = TILE_SCENE.instantiate()
	add_child(_ghost_tile)
	_ghost_tile.position = _calculate_position(landing_row, _selected_col)
	_ghost_tile.setup(ghost_value, _tile_size, _cols)
	_ghost_tile.modulate = Color(1, 1, 1, 0.3)  ## 30% opacity ghost
	_ghost_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _calculate_position(row: int, col: int) -> Vector2:
	var x := _padding + col * (_tile_size + _padding)
	var y := _padding + row * (_tile_size + _padding)
	return Vector2(x, y)


func _create_tile(row: int, col: int, value: int) -> Control:
	var tile: Control = TILE_SCENE.instantiate()
	add_child(tile)
	tile.position = _calculate_position(row, col)
	tile.setup(value, _tile_size, _cols)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tiles[Vector2i(row, col)] = tile
	return tile


## Task 1: Shows a floating "+score" label at the board position of pos (row,col).
## If chain >= 2, also shows a centered "COMBO xN!" overlay.
func _show_floating_score(pos: Vector2i, score: int, chain: int) -> void:
	if score <= 0:
		return

	# --- floating "+score" label ---
	var float_label := Label.new()
	float_label.text = "+%d" % score
	float_label.add_theme_font_size_override("font_size", 28)
	float_label.add_theme_color_override("font_color", Color("EDE0D4"))
	float_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(float_label)

	var start_pos: Vector2 = _calculate_position(pos.x, pos.y)
	# Center the label over the tile
	float_label.position = start_pos + Vector2(_tile_size * 0.5 - 24.0, 0.0)

	var float_tween: Tween = create_tween()
	float_tween.set_parallel(true)
	float_tween.tween_property(float_label, "position:y", float_label.position.y - _tile_size, 0.6)
	float_tween.tween_property(float_label, "modulate:a", 0.0, 0.6)
	float_tween.chain().tween_callback(float_label.queue_free)

	if chain < 2:
		return

	# --- centered combo overlay ---
	var combo_label := Label.new()
	combo_label.text = "COMBO x%d!" % chain
	combo_label.add_theme_font_size_override("font_size", 54)
	combo_label.add_theme_color_override("font_color", Color("F65E3B"))
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(combo_label)

	# Size and center on board
	combo_label.size = Vector2(_board_width, 80.0)
	combo_label.position = Vector2(0.0, _board_height * 0.5 - 40.0)

	var combo_tween: Tween = create_tween()
	combo_tween.set_parallel(true)
	combo_tween.tween_property(combo_label, "scale", Vector2(1.2, 1.2), 0.15)
	combo_tween.tween_property(combo_label, "position:y", combo_label.position.y - 20.0, 0.15)
	var combo_tween2: Tween = create_tween()
	combo_tween2.tween_interval(0.25)
	combo_tween2.tween_callback(func() -> void:
		var fade: Tween = create_tween()
		fade.tween_property(combo_label, "modulate:a", 0.0, 0.35)
		fade.tween_callback(combo_label.queue_free)
	)


func get_logic() -> DropLogic:
	return _logic


func get_score() -> int:
	return _logic.score


func get_move_count() -> int:
	return _logic.move_count


func get_highest_tile() -> int:
	return _logic.highest_tile


func get_next_value() -> int:
	return _logic.next_value


func get_selected_col() -> int:
	return _selected_col


func select_column(col: int) -> void:
	_selected_col = clampi(col, 0, _cols - 1)
	_update_column_highlight()


func move_selection(direction: int) -> void:
	# -1 = left, +1 = right
	select_column(_selected_col + direction)


## Task 7: Shift selected column's tiles to adjacent column
func apply_column_shift(col: int, direction: int) -> bool:
	if not _logic.shift_column(col, direction):
		return false
	_rebuild_tiles()
	_update_ghost_tile()
	AudioManager.play_sfx("tile_slide")
	return true


func drop_current() -> void:
	if _is_animating:
		return

	var result: Dictionary = _logic.drop_tile(_selected_col)
	if not result.get("landed", false):
		return

	_is_animating = true

	var merges: Array = result.get("merges", [])
	var chain: int = result.get("chains", 0)
	var score_gained: int = result.get("score_gained", 0)
	var land_row: int = result["row"]
	var dropped_value: int = result.get("dropped_value", 2)

	# --- Phase 1: Drop fall animation using a TEMPORARY tile ---
	# Don't rebuild yet — show the falling tile first
	var start_pos: Vector2 = _calculate_position(0, _selected_col)
	var land_pos: Vector2 = _calculate_position(land_row, _selected_col)
	var fall_duration: float = 0.08 + land_row * 0.03

	var fall_tile: Control = TILE_SCENE.instantiate()
	add_child(fall_tile)
	fall_tile.position = start_pos
	fall_tile.setup(dropped_value, _tile_size, _cols)
	fall_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fall_tween := create_tween()
	fall_tween.tween_property(fall_tile, "position", land_pos, fall_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Small bounce at landing
	fall_tween.tween_property(fall_tile, "position:y", land_pos.y - 8.0, 0.05).set_ease(Tween.EASE_OUT)
	fall_tween.tween_property(fall_tile, "position:y", land_pos.y, 0.05).set_ease(Tween.EASE_IN)

	AudioManager.play_sfx("tile_spawn")

	# --- Phase 2: After fall, remove temp tile, rebuild final state, play merges ---
	var sequence := create_tween()
	sequence.tween_interval(fall_duration + 0.12)

	sequence.tween_callback(func() -> void:
		fall_tile.queue_free()
		_rebuild_tiles()
	)

	if not merges.is_empty():
		sequence.tween_interval(0.05)  # Brief pause before merge animation
		sequence.tween_callback(_animate_merges.bind(merges, chain, score_gained))
		sequence.tween_interval(0.45)
		sequence.tween_callback(func() -> void:
			_is_animating = false
			_update_ghost_tile()
			move_completed.emit(score_gained)
		)
	else:
		sequence.tween_callback(func() -> void:
			_is_animating = false
			_update_ghost_tile()
			move_completed.emit(score_gained)
		)


func _animate_merges(merges: Array, chain: int, score_gained: int) -> void:
	for m: Dictionary in merges:
		var result_pos: Vector2i = m["pos"]
		var from_positions: Array = m.get("from_positions", [])

		# Create temporary ghost tiles at each source position, animate them
		# flying into the result position, then pop the result tile
		for src: Vector2i in from_positions:
			if src == result_pos:
				continue  # The result tile stays in place

			# Create a temporary visual tile at source position
			var temp_tile: Control = TILE_SCENE.instantiate()
			add_child(temp_tile)
			var old_value: int = m.get("new_value", 2) / 2  # Approximate original value
			temp_tile.position = _calculate_position(src.x, src.y)
			temp_tile.setup(old_value, _tile_size, _cols)
			temp_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE

			# Animate: slide to result position + shrink + fade (0.35s)
			var target_pos: Vector2 = _calculate_position(result_pos.x, result_pos.y)
			var fly_tween := create_tween().set_parallel(true)
			fly_tween.tween_property(temp_tile, "position", target_pos, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
			fly_tween.tween_property(temp_tile, "scale", Vector2(0.4, 0.4), 0.35).set_ease(Tween.EASE_IN)
			fly_tween.tween_property(temp_tile, "modulate:a", 0.3, 0.35)
			fly_tween.chain().tween_callback(temp_tile.queue_free)

		# Pop animation on the result tile
		if _tiles.has(result_pos):
			var result_tile: Control = _tiles[result_pos]
			result_tile.animate_merge()

	# Sound
	if chain >= 3:
		AudioManager.play_sfx("merge_large")
	elif chain >= 2:
		AudioManager.play_sfx("merge_medium")
	elif chain >= 1:
		AudioManager.play_sfx("merge_small")

	# Floating score
	if score_gained > 0:
		var anchor_pos: Vector2i = merges[0].get("pos", Vector2i(0, 0))
		_show_floating_score(anchor_pos, score_gained, chain)


## Task 2: Clears the top 2 rows to give the player more room after watching an ad.
func continue_game() -> void:
	_logic.clear_top_rows(2)
	_rebuild_tiles()
	_update_ghost_tile()


func _rebuild_tiles() -> void:
	for pos: Vector2i in _tiles:
		_tiles[pos].queue_free()
	_tiles.clear()

	for r in _rows:
		for c in _cols:
			if _logic.grid[r][c] != 0:
				_create_tile(r, c, _logic.grid[r][c])


func _on_game_over() -> void:
	board_game_over.emit()


func _on_game_won() -> void:
	board_game_won.emit()


func new_game() -> void:
	for pos: Vector2i in _tiles:
		_tiles[pos].queue_free()
	_tiles.clear()
	_is_animating = false

	# Clean up old logic signals
	if _logic:
		if _logic.game_over.is_connected(_on_game_over):
			_logic.game_over.disconnect(_on_game_over)
		if _logic.game_won.is_connected(_on_game_won):
			_logic.game_won.disconnect(_on_game_won)

	_logic = DropLogic.new()
	_logic.game_over.connect(_on_game_over)
	_logic.game_won.connect(_on_game_won)
	_logic.initialize(_cols, _rows)
	_selected_col = 2
	_update_column_highlight()
	_update_ghost_tile()


func refresh_theme() -> void:
	var ui_colors: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	_grid_bg.color = ui_colors["grid_bg"]
	for cell: ColorRect in _empty_cells:
		cell.color = ui_colors["empty_cell"]
	for pos: Vector2i in _tiles:
		_tiles[pos].set_value(_tiles[pos].value, _cols)


func restore_from_dict(data: Dictionary) -> void:
	for pos: Vector2i in _tiles:
		_tiles[pos].queue_free()
	_tiles.clear()

	_logic = DropLogic.new()
	_logic.game_over.connect(_on_game_over)
	_logic.game_won.connect(_on_game_won)
	_logic.from_dict(data)

	_cols = _logic.cols
	_rows = _logic.rows

	for r in _rows:
		for c in _cols:
			if _logic.grid[r][c] != 0:
				_create_tile(r, c, _logic.grid[r][c])


func _input(event: InputEvent) -> void:
	if _is_animating:
		return
	# Block input when popups are open
	if ScreenManager.has_popups():
		return
	# Block input when game is paused/over
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	var screen_pos: Vector2 = Vector2.ZERO
	var is_press: bool = false
	var is_hover: bool = false

	if event is InputEventScreenTouch and event.pressed:
		screen_pos = event.position
		is_press = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		screen_pos = event.position
		is_press = true
	elif event is InputEventMouseMotion:
		screen_pos = event.position
		is_hover = true

	if not is_press and not is_hover:
		return

	# Convert screen position to board-local position
	var local_pos: Vector2 = screen_pos - global_position
	# Check if within board area
	if local_pos.x < 0 or local_pos.x > _board_width or local_pos.y < 0 or local_pos.y > _board_height:
		return

	var col: int = int((local_pos.x - _padding) / (_tile_size + _padding))
	col = clampi(col, 0, _cols - 1)

	if is_hover:
		# Just update column highlight and ghost on hover
		if col != _selected_col:
			select_column(col)
		return

	select_column(col)
	drop_current()
	get_viewport().set_input_as_handled()
