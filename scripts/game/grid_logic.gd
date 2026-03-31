## grid_logic.gd
## Pure data class implementing the core 2048 game logic.
## No Node dependency — can be unit-tested independently.
class_name GridLogic
extends RefCounted

signal tiles_moved(movements: Array)
signal tile_spawned(pos: Vector2i, value: int)
signal score_changed(new_score: int, gained: int)
signal game_over
signal game_won

enum Direction { LEFT, RIGHT, UP, DOWN }

var grid: Array = []        ## 2D array [row][col]
var grid_size: int = 4
var score: int = 0
var move_count: int = 0
var highest_tile: int = 0
var history: Array = []     ## Stack of {grid, score, move_count, highest_tile}

var _won: bool = false
var _continue_after_win: bool = false
var _rng: RandomNumberGenerator


func initialize(size: int = 4, seed_value: int = -1) -> void:
	grid_size = size
	score = 0
	move_count = 0
	highest_tile = 0
	history = []
	_won = false
	_continue_after_win = false

	if seed_value >= 0:
		_rng = RandomNumberGenerator.new()
		_rng.seed = seed_value
	else:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()

	# Create empty grid
	grid = []
	for r in grid_size:
		var row: Array = []
		for c in grid_size:
			row.append(0)
		grid.append(row)

	# Spawn 2 initial tiles
	spawn_tile()
	spawn_tile()


func move(direction: int) -> Dictionary:
	## Execute a move in the given direction.
	## Returns {moved, movements, score_gained, spawned_pos, spawned_value}
	var result: Dictionary = {
		"moved": false,
		"movements": [] as Array,
		"score_gained": 0,
		"spawned_pos": Vector2i(-1, -1),
		"spawned_value": 0,
	}

	# Save state for undo
	_push_history()

	var movements: Array = []
	var total_gained: int = 0

	match direction:
		Direction.LEFT:
			for r in grid_size:
				var row_result: Dictionary = _process_row_with_tracking(r, direction)
				movements.append_array(row_result["movements"])
				total_gained += row_result["score"]
		Direction.RIGHT:
			for r in grid_size:
				var row_result: Dictionary = _process_row_with_tracking(r, direction)
				movements.append_array(row_result["movements"])
				total_gained += row_result["score"]
		Direction.UP:
			for c in grid_size:
				var col_result: Dictionary = _process_col_with_tracking(c, direction)
				movements.append_array(col_result["movements"])
				total_gained += col_result["score"]
		Direction.DOWN:
			for c in grid_size:
				var col_result: Dictionary = _process_col_with_tracking(c, direction)
				movements.append_array(col_result["movements"])
				total_gained += col_result["score"]

	# Check if anything actually moved
	var moved: bool = false
	for m: TileMovement in movements:
		if m.from_pos != m.to_pos or m.merged:
			moved = true
			break

	if not moved:
		# Nothing moved, pop the history we just pushed
		history.pop_back()
		return result

	score += total_gained
	move_count += 1

	# Update highest tile
	for r in grid_size:
		for c in grid_size:
			if grid[r][c] > highest_tile:
				highest_tile = grid[r][c]

	result["moved"] = true
	result["movements"] = movements
	result["score_gained"] = total_gained

	score_changed.emit(score, total_gained)
	tiles_moved.emit(movements)

	# Spawn new tile
	var spawn_pos := spawn_tile()
	if spawn_pos != Vector2i(-1, -1):
		result["spawned_pos"] = spawn_pos
		result["spawned_value"] = grid[spawn_pos.x][spawn_pos.y]

	# Check win
	if not _won and highest_tile >= 2048:
		_won = true
		if not _continue_after_win:
			game_won.emit()

	# Check game over
	if is_game_over():
		game_over.emit()

	return result


func _process_row_with_tracking(row: int, direction: int) -> Dictionary:
	var line: Array = []
	var positions: Array = []  ## Original positions of non-zero elements

	if direction == Direction.LEFT:
		for c in grid_size:
			if grid[row][c] != 0:
				line.append(grid[row][c])
				positions.append(Vector2i(row, c))
	else:  ## RIGHT
		for c in range(grid_size - 1, -1, -1):
			if grid[row][c] != 0:
				line.append(grid[row][c])
				positions.append(Vector2i(row, c))

	var merge_result: Dictionary = _merge_line(line)
	var merged_line: Array = merge_result["line"]
	var merge_info: Array = merge_result["merge_info"]

	var movements: Array = []
	var score_gained: int = 0

	# Pad to grid_size
	while merged_line.size() < grid_size:
		merged_line.append(0)

	# Write back to grid and create movement records
	var src_idx: int = 0
	for i in merged_line.size():
		var target_col: int
		if direction == Direction.LEFT:
			target_col = i
		else:
			target_col = grid_size - 1 - i

		if direction == Direction.LEFT:
			grid[row][i] = merged_line[i]
		else:
			grid[row][grid_size - 1 - i] = merged_line[i]

	# Build movement tracking from merge_info
	for info: Dictionary in merge_info:
		if info["type"] == "move":
			var from: Vector2i = positions[info["src"]]
			var target_col: int
			if direction == Direction.LEFT:
				target_col = info["dest"]
			else:
				target_col = grid_size - 1 - info["dest"]
			var to := Vector2i(row, target_col)
			movements.append(TileMovement.create(from, to, info["value"]))
		elif info["type"] == "merge":
			var from1: Vector2i = positions[info["src1"]]
			var from2: Vector2i = positions[info["src2"]]
			var target_col: int
			if direction == Direction.LEFT:
				target_col = info["dest"]
			else:
				target_col = grid_size - 1 - info["dest"]
			var to := Vector2i(row, target_col)
			movements.append(TileMovement.create(from1, to, info["value1"]))
			movements.append(TileMovement.create(from2, to, info["value2"], true, info["merged_value"]))
			score_gained += info["merged_value"]

	return {"movements": movements, "score": score_gained}


func _process_col_with_tracking(col: int, direction: int) -> Dictionary:
	var line: Array = []
	var positions: Array = []

	if direction == Direction.UP:
		for r in grid_size:
			if grid[r][col] != 0:
				line.append(grid[r][col])
				positions.append(Vector2i(r, col))
	else:  ## DOWN
		for r in range(grid_size - 1, -1, -1):
			if grid[r][col] != 0:
				line.append(grid[r][col])
				positions.append(Vector2i(r, col))

	var merge_result: Dictionary = _merge_line(line)
	var merged_line: Array = merge_result["line"]
	var merge_info: Array = merge_result["merge_info"]

	var movements: Array = []
	var score_gained: int = 0

	while merged_line.size() < grid_size:
		merged_line.append(0)

	# Write back to grid
	for i in merged_line.size():
		if direction == Direction.UP:
			grid[i][col] = merged_line[i]
		else:
			grid[grid_size - 1 - i][col] = merged_line[i]

	# Build movement tracking
	for info: Dictionary in merge_info:
		if info["type"] == "move":
			var from: Vector2i = positions[info["src"]]
			var target_row: int
			if direction == Direction.UP:
				target_row = info["dest"]
			else:
				target_row = grid_size - 1 - info["dest"]
			var to := Vector2i(target_row, col)
			movements.append(TileMovement.create(from, to, info["value"]))
		elif info["type"] == "merge":
			var from1: Vector2i = positions[info["src1"]]
			var from2: Vector2i = positions[info["src2"]]
			var target_row: int
			if direction == Direction.UP:
				target_row = info["dest"]
			else:
				target_row = grid_size - 1 - info["dest"]
			var to := Vector2i(target_row, col)
			movements.append(TileMovement.create(from1, to, info["value1"]))
			movements.append(TileMovement.create(from2, to, info["value2"], true, info["merged_value"]))
			score_gained += info["merged_value"]

	return {"movements": movements, "score": score_gained}


func _merge_line(line: Array) -> Dictionary:
	## Process a compressed line (no zeros): merge adjacent equal values.
	## Returns {line: Array, merge_info: Array} with tracking data.
	var result: Array = []
	var merge_info: Array = []
	var dest_idx: int = 0
	var src_idx: int = 0

	while src_idx < line.size():
		if src_idx + 1 < line.size() and line[src_idx] == line[src_idx + 1]:
			# Merge
			var merged_val: int = line[src_idx] * 2
			result.append(merged_val)
			merge_info.append({
				"type": "merge",
				"src1": src_idx,
				"src2": src_idx + 1,
				"dest": dest_idx,
				"value1": line[src_idx],
				"value2": line[src_idx + 1],
				"merged_value": merged_val,
			})
			src_idx += 2
		else:
			# Move only
			result.append(line[src_idx])
			merge_info.append({
				"type": "move",
				"src": src_idx,
				"dest": dest_idx,
				"value": line[src_idx],
			})
			src_idx += 1
		dest_idx += 1

	return {"line": result, "merge_info": merge_info}


func spawn_tile() -> Vector2i:
	var empty := get_empty_cells()
	if empty.is_empty():
		return Vector2i(-1, -1)

	var idx: int = _rng.randi() % empty.size()
	var pos: Vector2i = empty[idx]
	var value: int = 2 if _rng.randf() < 0.9 else 4
	grid[pos.x][pos.y] = value
	tile_spawned.emit(pos, value)
	return pos


func is_game_over() -> bool:
	if not get_empty_cells().is_empty():
		return false
	for r in grid_size:
		for c in grid_size:
			if c < grid_size - 1 and grid[r][c] == grid[r][c + 1]:
				return false
			if r < grid_size - 1 and grid[r][c] == grid[r + 1][c]:
				return false
	return true


func has_won() -> bool:
	return _won and not _continue_after_win


func continue_after_win() -> void:
	_continue_after_win = true


func undo() -> bool:
	if history.is_empty():
		return false
	var state: Dictionary = history.pop_back()
	grid = state["grid"]
	score = state["score"]
	move_count = state["move_count"]
	highest_tile = state["highest_tile"]
	score_changed.emit(score, 0)
	return true


func get_empty_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for r in grid_size:
		for c in grid_size:
			if grid[r][c] == 0:
				cells.append(Vector2i(r, c))
	return cells


func reset(size: int = 4) -> void:
	initialize(size)


func _push_history() -> void:
	var grid_copy: Array = []
	for row: Array in grid:
		grid_copy.append(row.duplicate())
	history.append({
		"grid": grid_copy,
		"score": score,
		"move_count": move_count,
		"highest_tile": highest_tile,
	})
	# Limit history depth to 20 to save memory
	if history.size() > 20:
		history.pop_front()


func to_dict() -> Dictionary:
	var grid_copy: Array = []
	for row: Array in grid:
		grid_copy.append(row.duplicate())
	# Serialize history for save/load
	var history_copy: Array = []
	for h: Dictionary in history:
		var h_grid: Array = []
		for row: Array in h["grid"]:
			h_grid.append(row.duplicate())
		history_copy.append({
			"grid": h_grid,
			"score": h["score"],
			"move_count": h["move_count"],
			"highest_tile": h["highest_tile"],
		})

	return {
		"grid": grid_copy,
		"grid_size": grid_size,
		"score": score,
		"move_count": move_count,
		"highest_tile": highest_tile,
		"won": _won,
		"continue_after_win": _continue_after_win,
		"history": history_copy,
	}


func from_dict(data: Dictionary) -> void:
	grid_size = data.get("grid_size", 4)
	grid = []
	var saved_grid: Array = data.get("grid", [])
	for row: Array in saved_grid:
		grid.append(row.duplicate())
	score = data.get("score", 0)
	move_count = data.get("move_count", 0)
	highest_tile = data.get("highest_tile", 0)
	_won = data.get("won", false)
	_continue_after_win = data.get("continue_after_win", false)

	# Restore history from save data
	history = []
	var saved_history: Array = data.get("history", [])
	for h: Dictionary in saved_history:
		var h_grid: Array = []
		for row: Array in h.get("grid", []):
			h_grid.append(row.duplicate() if row is Array else [])
		history.append({
			"grid": h_grid,
			"score": h.get("score", 0),
			"move_count": h.get("move_count", 0),
			"highest_tile": h.get("highest_tile", 0),
		})

	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()


## Power-up: Remove a single tile at the given position.
## Minimum tiles that must remain on the board after any powerup removal.
## With < 2 tiles, the board enters a silent deadlock (no valid moves, no game_over).
const MIN_TILES_AFTER_POWERUP: int = 2

## Shared bomb offset pattern — single source of truth for both prediction and execution.
const BOMB_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(0, -1), Vector2i(0, 1),
]


## Count total non-empty tiles on the board.
func count_occupied() -> int:
	var count: int = 0
	for r: int in grid_size:
		for c: int in grid_size:
			if grid[r][c] > 0:
				count += 1
	return count


## Predict how many tiles a bomb at pos would remove (without actually removing).
func predict_bomb_removal(pos: Vector2i) -> int:
	var count: int = 0
	for offset: Vector2i in BOMB_OFFSETS:
		var r: int = pos.x + offset.x
		var c: int = pos.y + offset.y
		if r >= 0 and r < grid_size and c >= 0 and c < grid_size:
			if grid[r][c] > 0:
				count += 1
	return count


func remove_tile(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= grid_size or pos.y < 0 or pos.y >= grid_size:
		return false
	if grid[pos.x][pos.y] == 0:
		return false
	# Guard: ensure minimum tiles remain after removal
	if count_occupied() - 1 < MIN_TILES_AFTER_POWERUP:
		return false
	_push_history()
	grid[pos.x][pos.y] = 0
	return true


## Power-up: Remove tile at pos + adjacent cross pattern. Returns removed positions.
func remove_area(pos: Vector2i) -> Array[Vector2i]:
	if pos.x < 0 or pos.x >= grid_size or pos.y < 0 or pos.y >= grid_size:
		return []
	# Guard: ensure minimum tiles remain after removal
	var would_remove: int = predict_bomb_removal(pos)
	if count_occupied() - would_remove < MIN_TILES_AFTER_POWERUP:
		return []
	_push_history()
	var removed: Array[Vector2i] = []
	for offset: Vector2i in BOMB_OFFSETS:
		var r: int = pos.x + offset.x
		var c: int = pos.y + offset.y
		if r >= 0 and r < grid_size and c >= 0 and c < grid_size:
			if grid[r][c] != 0:
				grid[r][c] = 0
				removed.append(Vector2i(r, c))
	return removed


## Power-up: Randomly shuffle all non-empty tile values.
## Blocked if tile count <= 1 (shuffle would be a no-op).
func shuffle_tiles() -> bool:
	var occupied: int = count_occupied()
	if occupied <= 1:
		return false
	_push_history()
	var values: Array[int] = []
	var positions: Array[Vector2i] = []
	for r in grid_size:
		for c in grid_size:
			if grid[r][c] != 0:
				values.append(grid[r][c])
				positions.append(Vector2i(r, c))
	# Fisher-Yates shuffle
	for i in range(values.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: int = values[i]
		values[i] = values[j]
		values[j] = tmp
	# Reassign
	for i in values.size():
		grid[positions[i].x][positions[i].y] = values[i]
	return true
