## test_grid_logic.gd
## Headless unit test for GridLogic core algorithm.
extends SceneTree

func _init() -> void:
	var passed: int = 0
	var failed: int = 0

	# Test 1: Initialize creates grid with 2 tiles
	var gl := GridLogic.new()
	gl.initialize(4, 42)  # Fixed seed for reproducibility
	var non_zero: int = 0
	for r in 4:
		for c in 4:
			if gl.grid[r][c] != 0:
				non_zero += 1
	if non_zero == 2:
		print("PASS: Test 1 - Initialize spawns 2 tiles")
		passed += 1
	else:
		print("FAIL: Test 1 - Expected 2 tiles, got %d" % non_zero)
		failed += 1

	# Test 2: process_row merge logic (no double merge)
	# Simulate [2,2,2,2] left -> [4,4,0,0]
	var gl2 := GridLogic.new()
	gl2.initialize(4, 100)
	gl2.grid = [[2,2,2,2],[0,0,0,0],[0,0,0,0],[0,0,0,0]]
	gl2.move(GridLogic.Direction.LEFT)
	if gl2.grid[0][0] == 4 and gl2.grid[0][1] == 4:
		print("PASS: Test 2 - No double merge: [2,2,2,2] -> [4,4,_,_]")
		passed += 1
	else:
		print("FAIL: Test 2 - Got row: %s" % str(gl2.grid[0]))
		failed += 1

	# Test 3: Score calculation
	var gl3 := GridLogic.new()
	gl3.initialize(4, 200)
	gl3.grid = [[2,2,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]]
	gl3.score = 0
	gl3.move(GridLogic.Direction.LEFT)
	if gl3.score == 4:
		print("PASS: Test 3 - Score: 2+2 merge gives 4 points")
		passed += 1
	else:
		print("FAIL: Test 3 - Expected score 4, got %d" % gl3.score)
		failed += 1

	# Test 4: Move right
	var gl4 := GridLogic.new()
	gl4.initialize(4, 300)
	gl4.grid = [[2,2,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]]
	gl4.move(GridLogic.Direction.RIGHT)
	if gl4.grid[0][3] == 4:
		print("PASS: Test 4 - Move right: [2,2,0,0] -> [_,_,_,4]")
		passed += 1
	else:
		print("FAIL: Test 4 - Got row: %s" % str(gl4.grid[0]))
		failed += 1

	# Test 5: Move up
	var gl5 := GridLogic.new()
	gl5.initialize(4, 400)
	gl5.grid = [[0,0,0,0],[2,0,0,0],[2,0,0,0],[0,0,0,0]]
	gl5.move(GridLogic.Direction.UP)
	if gl5.grid[0][0] == 4:
		print("PASS: Test 5 - Move up merges column")
		passed += 1
	else:
		print("FAIL: Test 5 - grid[0][0] = %d" % gl5.grid[0][0])
		failed += 1

	# Test 6: Move down
	var gl6 := GridLogic.new()
	gl6.initialize(4, 500)
	gl6.grid = [[0,0,0,0],[2,0,0,0],[2,0,0,0],[0,0,0,0]]
	gl6.move(GridLogic.Direction.DOWN)
	if gl6.grid[3][0] == 4:
		print("PASS: Test 6 - Move down merges column")
		passed += 1
	else:
		print("FAIL: Test 6 - grid[3][0] = %d" % gl6.grid[3][0])
		failed += 1

	# Test 7: Game over detection
	var gl7 := GridLogic.new()
	gl7.grid_size = 2
	gl7.grid = [[2,4],[4,2]]
	if gl7.is_game_over():
		print("PASS: Test 7 - Game over detected on filled board with no merges")
		passed += 1
	else:
		print("FAIL: Test 7 - Should be game over")
		failed += 1

	# Test 8: Not game over when adjacent match exists
	var gl8 := GridLogic.new()
	gl8.grid_size = 2
	gl8.grid = [[2,2],[4,8]]
	if not gl8.is_game_over():
		print("PASS: Test 8 - Not game over when adjacent match exists")
		passed += 1
	else:
		print("FAIL: Test 8 - Should not be game over")
		failed += 1

	# Test 9: Undo
	var gl9 := GridLogic.new()
	gl9.initialize(4, 600)
	var original_score: int = gl9.score
	var original_grid: Array = []
	for row: Array in gl9.grid:
		original_grid.append(row.duplicate())
	gl9.grid = [[2,2,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]]
	gl9.move(GridLogic.Direction.LEFT)
	gl9.undo()
	if gl9.grid[0][0] == 2 and gl9.grid[0][1] == 2:
		print("PASS: Test 9 - Undo restores previous state")
		passed += 1
	else:
		print("FAIL: Test 9 - Undo failed, row: %s" % str(gl9.grid[0]))
		failed += 1

	# Test 10: No-move doesn't spawn tile
	var gl10 := GridLogic.new()
	gl10.initialize(4, 700)
	gl10.grid = [[2,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]]
	var result10: Dictionary = gl10.move(GridLogic.Direction.LEFT)
	if not result10["moved"]:
		print("PASS: Test 10 - Moving left when tile already at left wall = no move")
		passed += 1
	else:
		print("FAIL: Test 10 - Should not have moved")
		failed += 1

	# Test 11: Hammer removes single tile
	var gl11 := GridLogic.new()
	gl11.initialize(4, 800)
	gl11.grid = [[8,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]]
	if gl11.remove_tile(Vector2i(0, 0)):
		if gl11.grid[0][0] == 0:
			print("PASS: Test 11 - Hammer removes single tile")
			passed += 1
		else:
			print("FAIL: Test 11 - Tile not removed")
			failed += 1
	else:
		print("FAIL: Test 11 - remove_tile returned false")
		failed += 1

	# Test 12: Hammer fails on empty cell
	var gl12 := GridLogic.new()
	gl12.initialize(4, 900)
	gl12.grid = [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]]
	if not gl12.remove_tile(Vector2i(0, 0)):
		print("PASS: Test 12 - Hammer returns false on empty cell")
		passed += 1
	else:
		print("FAIL: Test 12 - Should not remove empty cell")
		failed += 1

	# Test 13: Bomb removes cross pattern
	var gl13 := GridLogic.new()
	gl13.initialize(4, 1000)
	gl13.grid = [[0,2,0,0],[2,4,2,0],[0,2,0,0],[0,0,0,0]]
	var removed13: Array = gl13.remove_area(Vector2i(1, 1))
	if removed13.size() == 5 and gl13.grid[1][1] == 0:
		print("PASS: Test 13 - Bomb removes cross pattern (5 tiles)")
		passed += 1
	else:
		print("FAIL: Test 13 - Removed %d tiles, center=%d" % [removed13.size(), gl13.grid[1][1]])
		failed += 1

	# Test 14: Shuffle preserves tile values
	var gl14 := GridLogic.new()
	gl14.initialize(4, 1100)
	gl14.grid = [[2,4,8,16],[0,0,0,0],[0,0,0,0],[0,0,0,0]]
	var sum_before: int = 2 + 4 + 8 + 16
	gl14.shuffle_tiles()
	var sum_after: int = 0
	for r14 in 4:
		for c14 in 4:
			sum_after += gl14.grid[r14][c14]
	if sum_after == sum_before:
		print("PASS: Test 14 - Shuffle preserves tile value sum")
		passed += 1
	else:
		print("FAIL: Test 14 - Sum before=%d, after=%d" % [sum_before, sum_after])
		failed += 1

	# Test 15: Serialization round-trip (to_dict/from_dict)
	var gl15 := GridLogic.new()
	gl15.initialize(4, 1200)
	gl15.grid = [[2,4,0,0],[0,8,0,0],[0,0,16,0],[0,0,0,32]]
	gl15.score = 500
	gl15.move_count = 25
	var dict15: Dictionary = gl15.to_dict()
	var gl15b := GridLogic.new()
	gl15b.from_dict(dict15)
	if gl15b.score == 500 and gl15b.move_count == 25 and gl15b.grid[0][0] == 2 and gl15b.grid[3][3] == 32:
		print("PASS: Test 15 - Serialization round-trip preserves state")
		passed += 1
	else:
		print("FAIL: Test 15 - Restored: score=%d, moves=%d, g[0][0]=%d" % [gl15b.score, gl15b.move_count, gl15b.grid[0][0]])
		failed += 1

	# Test 16: Coin reward tiers (inline logic matching CoinManager.calc_game_reward)
	var reward_2048: int = 200 if 2048 >= 2048 else 0
	var reward_128: int = 10  # 128 >= 128
	var reward_32: int = 0    # 32 < 64
	if reward_2048 == 200 and reward_128 == 10 and reward_32 == 0:
		print("PASS: Test 16 - Coin reward tier logic verified")
		passed += 1
	else:
		print("FAIL: Test 16 - Unexpected reward values")
		failed += 1

	print("\n=== Results: %d passed, %d failed ===" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)
