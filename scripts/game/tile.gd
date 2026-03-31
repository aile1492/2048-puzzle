## tile.gd
## Visual representation of a single 2048 tile.
## Handles colors, font sizes, and animations (spawn, merge).
extends Control

var value: int = 0
var _tile_size: float = 0.0
var _bg: ColorRect
var _label: Label


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.name = "Background"
	add_child(_bg)

	_label = Label.new()
	_label.name = "ValueLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


func setup(val: int, tile_size: float, grid_size: int = 4) -> void:
	_tile_size = tile_size
	custom_minimum_size = Vector2(tile_size, tile_size)
	size = Vector2(tile_size, tile_size)

	_bg.size = Vector2(tile_size, tile_size)
	_bg.position = Vector2.ZERO

	# Round corners via a shader or just use flat design
	_label.size = Vector2(tile_size, tile_size)
	_label.position = Vector2.ZERO

	set_value(val, grid_size)


func set_value(val: int, grid_size: int = 4) -> void:
	value = val
	if _label == null:
		return

	if val == 0:
		_label.text = ""
	else:
		_label.text = str(val)

	var style: Dictionary = TileColors.get_tile_style(val, ThemeManager.is_dark())
	_bg.color = style["bg"]

	# Font size scaled for non-4x4 grids
	var base_font_size: int = style["font_size"]
	var scale_factor: float = 1.0
	match grid_size:
		3: scale_factor = 1.15
		5: scale_factor = 0.8
		6: scale_factor = 0.65
	var final_size: int = int(base_font_size * scale_factor)

	_label.add_theme_font_size_override("font_size", final_size)
	_label.add_theme_color_override("font_color", style["text"])


func _get_speed() -> float:
	var s: float = float(SaveManager.get_value("settings", "animation_speed", 1.0))
	return s if s > 0.1 else 1.0


func animate_spawn() -> void:
	pivot_offset = size / 2.0
	scale = Vector2.ZERO
	var spd: float = _get_speed()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.1 / spd).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func animate_merge() -> void:
	pivot_offset = size / 2.0
	var spd: float = _get_speed()
	var tween := create_tween()
	# Pop scale
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.08 / spd).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1 / spd).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Brief white flash
	var flash_tween := create_tween()
	flash_tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.06 / spd)
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.12 / spd)
