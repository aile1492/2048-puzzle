## tile_movement.gd
## Data class describing a single tile's movement during a move operation.
class_name TileMovement
extends RefCounted

var from_pos: Vector2i
var to_pos: Vector2i
var value: int
var merged: bool
var merge_value: int  ## Value after merge (only valid when merged == true)


static func create(from: Vector2i, to: Vector2i, val: int, is_merged: bool = false, merged_val: int = 0) -> TileMovement:
	var tm := TileMovement.new()
	tm.from_pos = from
	tm.to_pos = to
	tm.value = val
	tm.merged = is_merged
	tm.merge_value = merged_val
	return tm
