## drop_logic.gd
## Pure data class implementing Drop mode 2048 logic.
## Tiles drop from top into columns, merge when same numbers touch.
## Implements: design/gdd/drop_mode.md
## Features: chain combo multiplier (task 5), next-queue 2 pieces (task 3),
##            clear_top_rows for continue-via-ad (task 2).
class_name DropLogic
extends RefCounted

signal tile_dropped(col: int, row: int, value: int)
signal tiles_merged(merges: Array)
signal chain_completed(chain_count: int)
signal game_over
signal game_won

var grid: Array = []        ## [row][col], row 0 = top
var cols: int = 5
var rows: int = 8
var score: int = 0
var move_count: int = 0
var highest_tile: int = 0
var next_value: int = 2     ## Kept for backward-compatibility; mirrors next_queue[0]
var next_queue: Array[int] = []  ## Task 3: 2-piece lookahead queue
var _won: bool = false
var _continue_after_win: bool = false
var _rng: RandomNumberGenerator


func initialize(num_cols: int = 5, num_rows: int = 8) -> void:
	cols = num_cols
	rows = num_rows
	score = 0
	move_count = 0
	highest_tile = 0
	_won = false
	_continue_after_win = false
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	grid = []
	for r in rows:
		var row_arr: Array = []
		for c in cols:
			row_arr.append(0)
		grid.append(row_arr)

	# Task 3: fill the 2-piece queue
	next_queue.clear()
	next_queue.append(_generate_next())
	next_queue.append(_generate_next())
	next_value = next_queue[0]


## Returns the row where a tile would land in the given column, or -1 if full.
func get_landing_row(col: int) -> int:
	if col < 0 or col >= cols:
		return -1
	for r in range(rows - 1, -1, -1):
		if grid[r][col] == 0:
			return r
	return -1


## Task 3: Returns a copy of the current lookahead queue (2 values).
func get_next_values() -> Array[int]:
	var result: Array[int] = []
	for v: int in next_queue:
		result.append(v)
	return result


func drop_tile(col: int) -> Dictionary:
	if col < 0 or col >= cols:
		return {"landed": false}

	# Find lowest empty row in this column
	var land_row: int = -1
	for r in range(rows - 1, -1, -1):
		if grid[r][col] == 0:
			land_row = r
			break

	if land_row < 0:
		return {"landed": false}

	# Task 3: consume the front of the queue
	var drop_value: int = next_queue[0]
	next_queue.remove_at(0)
	next_queue.append(_generate_next())
	next_value = next_queue[0]  # keep backward-compat property in sync

	# Place tile
	grid[land_row][col] = drop_value
	move_count += 1
	tile_dropped.emit(col, land_row, drop_value)

	# Process merges with chain combos
	var total_score: int = 0
	var total_merges: Array = []
	var chain_count: int = 0

	while true:
		var merges: Array = _find_and_execute_merges()
		if merges.is_empty():
			break
		chain_count += 1

		# Task 5: combo score multiplier per chain depth
		var multiplier: float = _chain_multiplier(chain_count)

		for m: Dictionary in merges:
			var chain_score: int = int(m["new_value"] * multiplier)
			total_score += chain_score
			if m["new_value"] > highest_tile:
				highest_tile = m["new_value"]
		total_merges.append_array(merges)
		tiles_merged.emit(merges)
		_apply_gravity()

	score += total_score

	if chain_count > 0:
		chain_completed.emit(chain_count)

	# Check win
	if highest_tile >= 2048 and not _won:
		_won = true
		game_won.emit()

	# Check game over
	if is_game_over():
		game_over.emit()

	return {
		"landed": true,
		"row": land_row,
		"dropped_value": drop_value,
		"score_gained": total_score,
		"merges": total_merges,
		"chains": chain_count,
	}


## Task 5: Returns the score multiplier for a given chain depth.
## chain 1 = 1.0x, chain 2 = 1.5x, chain 3 = 2.0x, chain 4+ = 3.0x
func _chain_multiplier(chain: int) -> float:
	match chain:
		1:
			return 1.0
		2:
			return 1.5
		3:
			return 2.0
		_:
			return 3.0


## Task 2: Clears the top N rows and applies gravity so tiles settle down.
## Used by continue_game() after a rewarded ad to give the player more space.
func clear_top_rows(num_rows: int = 2) -> void:
	var clear_count: int = clampi(num_rows, 1, rows)
	for r in clear_count:
		for c in cols:
			grid[r][c] = 0
	_apply_gravity()


func _find_and_execute_merges() -> Array:
	var visited: Dictionary = {}
	var all_merges: Array = []

	for r in rows:
		for c in cols:
			if grid[r][c] == 0:
				continue
			var pos := Vector2i(r, c)
			if visited.has(pos):
				continue

			# Find connected group of same value
			var value: int = grid[r][c]
			var group: Array[Vector2i] = []
			var queue: Array[Vector2i] = [pos]

			while not queue.is_empty():
				var current: Vector2i = queue.pop_front()
				if visited.has(current):
					continue
				if current.x < 0 or current.x >= rows or current.y < 0 or current.y >= cols:
					continue
				if grid[current.x][current.y] != value:
					continue
				visited[current] = true
				group.append(current)
				queue.append(Vector2i(current.x - 1, current.y))
				queue.append(Vector2i(current.x + 1, current.y))
				queue.append(Vector2i(current.x, current.y - 1))
				queue.append(Vector2i(current.x, current.y + 1))

			if group.size() >= 2:
				# Merge: keep the lowest position, double value for each pair
				# For N tiles of value V: result = V * 2^(floor(log2(N)))
				# Simpler: merge pairs sequentially
				var result_value: int = value
				var merge_count: int = group.size()
				while merge_count > 1:
					result_value *= 2
					merge_count = (merge_count + 1) / 2  # ceiling division

				# Clear all positions except the lowest one
				var keep_pos: Vector2i = group[0]
				for p: Vector2i in group:
					if p.x > keep_pos.x or (p.x == keep_pos.x and p.y < keep_pos.y):
						keep_pos = p

				for p: Vector2i in group:
					grid[p.x][p.y] = 0

				grid[keep_pos.x][keep_pos.y] = result_value
				all_merges.append({
					"pos": keep_pos,
					"new_value": result_value,
					"merged_count": group.size(),
					"from_positions": group,
				})

	return all_merges


func _apply_gravity() -> void:
	for c in cols:
		# Collect non-zero values from bottom to top
		var values: Array[int] = []
		for r in range(rows - 1, -1, -1):
			if grid[r][c] != 0:
				values.append(grid[r][c])

		# Fill column from bottom
		for r in range(rows - 1, -1, -1):
			var idx: int = rows - 1 - r
			if idx < values.size():
				grid[r][c] = values[idx]
			else:
				grid[r][c] = 0


func _generate_next() -> int:
	var roll: float = _rng.randf()
	if roll < 0.70:
		return 2
	elif roll < 0.95:
		return 4
	else:
		return 8


func is_game_over() -> bool:
	# Game over if top row has any non-zero tile
	for c in cols:
		if grid[0][c] != 0:
			return true
	return false


func continue_after_win() -> void:
	_continue_after_win = true


## Task 7: Shift all tiles in src_col into dst_col direction.
## Returns true if shift was performed.
func shift_column(col: int, direction: int) -> bool:
	var dst_col: int = col + direction  # -1=left, +1=right
	if dst_col < 0 or dst_col >= cols:
		return false

	# Check if destination column can receive tiles (at least one empty spot)
	var src_values: Array[int] = []
	for r in rows:
		if grid[r][col] != 0:
			src_values.append(grid[r][col])
			grid[r][col] = 0

	if src_values.is_empty():
		return false

	# Stack source tiles on top of existing destination tiles
	# First collect existing dst values
	var dst_values: Array[int] = []
	for r in range(rows - 1, -1, -1):
		if grid[r][dst_col] != 0:
			dst_values.append(grid[r][dst_col])

	# Add src values on top
	dst_values.append_array(src_values)

	# Check if combined fits
	if dst_values.size() > rows:
		# Doesn't fit — restore source column
		var idx: int = 0
		for r in range(rows - 1, -1, -1):
			if idx < src_values.size():
				grid[r][col] = src_values[src_values.size() - 1 - idx]
				idx += 1
		return false

	# Clear dst column and fill from bottom
	for r in rows:
		grid[r][dst_col] = 0
	for i in dst_values.size():
		grid[rows - 1 - i][dst_col] = dst_values[i]

	# Apply gravity and check for merges
	_apply_gravity()

	var total_score: int = 0
	var chain_count: int = 0
	while true:
		var merges: Array = _find_and_execute_merges()
		if merges.is_empty():
			break
		chain_count += 1
		var multiplier: float = _chain_multiplier(chain_count)
		for m: Dictionary in merges:
			total_score += int(m["new_value"] * multiplier)
			if m["new_value"] > highest_tile:
				highest_tile = m["new_value"]
		_apply_gravity()

	score += total_score
	return true


func to_dict() -> Dictionary:
	return {
		"type": "drop",
		"cols": cols,
		"rows": rows,
		"grid": grid.duplicate(true),
		"score": score,
		"move_count": move_count,
		"highest_tile": highest_tile,
		"next_value": next_value,
		"next_queue": next_queue.duplicate(),
		"won": _won,
		"continue_after_win": _continue_after_win,
	}


func from_dict(data: Dictionary) -> void:
	cols = data.get("cols", 5)
	rows = data.get("rows", 8)
	grid = []
	for row: Array in data.get("grid", []):
		grid.append(row.duplicate())
	score = data.get("score", 0)
	move_count = data.get("move_count", 0)
	highest_tile = data.get("highest_tile", 0)
	next_value = data.get("next_value", 2)
	_won = data.get("won", false)
	_continue_after_win = data.get("continue_after_win", false)
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()

	# Task 3: restore or reconstruct the queue
	var saved_queue: Array = data.get("next_queue", [])
	next_queue.clear()
	if saved_queue.size() >= 2:
		next_queue.append(int(saved_queue[0]))
		next_queue.append(int(saved_queue[1]))
	else:
		next_queue.append(next_value)
		next_queue.append(_generate_next())
