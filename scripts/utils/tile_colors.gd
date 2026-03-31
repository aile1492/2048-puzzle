## tile_colors.gd
## Original 2048 color definitions for tiles and UI elements.
## Colors verified against original CSS at classic.play2048.co
class_name TileColors


## Light mode tile colors (original Gabriele Cirulli CSS exact values)
const LIGHT_TILE_COLORS: Dictionary = {
	0:     {"bg": Color("CDC1B4"), "text": Color("776E65")},
	2:     {"bg": Color("EEE4DA"), "text": Color("776E65")},
	4:     {"bg": Color("EEE1C9"), "text": Color("776E65")},
	8:     {"bg": Color("F3B27A"), "text": Color("F9F6F2")},
	16:    {"bg": Color("F69664"), "text": Color("F9F6F2")},
	32:    {"bg": Color("F77C5F"), "text": Color("F9F6F2")},
	64:    {"bg": Color("F75F3B"), "text": Color("F9F6F2")},
	128:   {"bg": Color("EDD073"), "text": Color("F9F6F2")},
	256:   {"bg": Color("EDCC62"), "text": Color("F9F6F2")},
	512:   {"bg": Color("EDC950"), "text": Color("F9F6F2")},
	1024:  {"bg": Color("EDC53F"), "text": Color("F9F6F2")},
	2048:  {"bg": Color("EDC22E"), "text": Color("F9F6F2")},
}

## Dark mode tile colors — use same bright originals (only surrounding UI is dark)
const DARK_TILE_COLORS: Dictionary = {
	0:     {"bg": Color("CDC1B4"), "text": Color("776E65")},
	2:     {"bg": Color("EEE4DA"), "text": Color("776E65")},
	4:     {"bg": Color("EEE1C9"), "text": Color("776E65")},
	8:     {"bg": Color("F3B27A"), "text": Color("F9F6F2")},
	16:    {"bg": Color("F69664"), "text": Color("F9F6F2")},
	32:    {"bg": Color("F77C5F"), "text": Color("F9F6F2")},
	64:    {"bg": Color("F75F3B"), "text": Color("F9F6F2")},
	128:   {"bg": Color("EDD073"), "text": Color("F9F6F2")},
	256:   {"bg": Color("EDCC62"), "text": Color("F9F6F2")},
	512:   {"bg": Color("EDC950"), "text": Color("F9F6F2")},
	1024:  {"bg": Color("EDC53F"), "text": Color("F9F6F2")},
	2048:  {"bg": Color("EDC22E"), "text": Color("F9F6F2")},
}

## Super tile (4096+) color
const SUPER_TILE: Dictionary = {"bg": Color("3C3A33"), "text": Color("F9F6F2")}
const SUPER_TILE_DARK: Dictionary = {"bg": Color("3C3A33"), "text": Color("F9F6F2")}

## UI colors — Light mode
const LIGHT_UI: Dictionary = {
	"page_bg": Color("FAF8EF"),
	"grid_bg": Color("BBADA0"),
	"empty_cell": Color("CDC1B4"),
	"header_text": Color("776E65"),
	"score_box_bg": Color("BBADA0"),
	"score_label": Color("EEE4DA"),
	"score_value": Color("FFFFFF"),
	"button_bg": Color("8F7A66"),
	"button_text": Color("F9F6F2"),
	"accent_primary": Color("E8825A"),
	"accent_secondary": Color("7CB9B0"),
	"logo_bg": Color("EDC22E"),
	"info_text": Color("999999"),
	"urgency_red": Color("F65E3B"),
	"powerup_text": Color("776E65"),       ## Dark brown on light bg — contrast 4.8:1
	"powerup_hint": Color("8F7A66"),       ## Muted brown for hint text
}

## UI colors — Dark mode (neutral gray, classic tan grid preserved)
const DARK_UI: Dictionary = {
	"page_bg": Color("1E1E1E"),
	"grid_bg": Color("BBADA0"),
	"empty_cell": Color("CDC1B4"),
	"header_text": Color("EEEEEE"),
	"score_box_bg": Color("585858"),
	"score_label": Color("D4D4D4"),
	"score_value": Color("FFFFFF"),
	"button_bg": Color("8F7A66"),
	"button_text": Color("F9F6F2"),
	"accent_primary": Color("E8825A"),
	"accent_secondary": Color("7CB9B0"),
	"logo_bg": Color("EDC22E"),
	"info_text": Color("888888"),
	"urgency_red": Color("F65E3B"),
	"powerup_text": Color("FFFFFF"),       ## White on dark bg — contrast 5.5:1
	"powerup_hint": Color("BBBBBB"),       ## Light gray for hint text
}


static func get_tile_style(value: int, is_dark: bool = false) -> Dictionary:
	var colors: Dictionary = DARK_TILE_COLORS if is_dark else LIGHT_TILE_COLORS
	if colors.has(value):
		var style: Dictionary = colors[value].duplicate()
		style["font_size"] = _get_font_size(value)
		return style

	var super_style: Dictionary = (SUPER_TILE_DARK if is_dark else SUPER_TILE).duplicate()
	super_style["font_size"] = _get_font_size(value)
	return super_style


static func get_ui_colors(is_dark: bool = false) -> Dictionary:
	return DARK_UI if is_dark else LIGHT_UI


static func _get_font_size(value: int) -> int:
	if value < 10:
		return 55
	elif value < 100:
		return 50
	elif value < 1000:
		return 45
	elif value < 10000:
		return 35
	else:
		return 30
