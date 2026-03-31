## drop_tutorial_popup.gd
## Interactive tutorial for Drop mode shown on first play.
## 4 steps: tap to drop, merge explanation, chain combos, danger line.
extends BaseScreen

var _step: int = 0
var _steps: Array[Dictionary] = []
var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _desc_label: Label
var _step_indicator: Label
var _next_button: Button
var _grid_visual: Control  ## Mini grid visualization


func enter(data: Dictionary = {}) -> void:
	_steps = [
		{
			"title": "Tap a Column",
			"desc": "Tap any column to\ndrop a tile down.",
			"grid": _make_grid_step1(),
		},
		{
			"title": "Same Numbers Merge!",
			"desc": "Adjacent same numbers\nautomatically combine.",
			"grid": _make_grid_step2(),
		},
		{
			"title": "Chain Combos",
			"desc": "Multiple merges from one drop\ngive combo bonus!",
			"grid": _make_grid_step3(),
		},
		{
			"title": "Watch the Top!",
			"desc": "If tiles reach the top row,\nit's game over!",
			"grid": _make_grid_step4(),
		},
	]
	_build_ui()
	_show_step(0)


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	# Overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(700, 0)
	_panel.z_index = 10
	add_child(_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ui["page_bg"]
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.content_margin_left = 40
	panel_style.content_margin_right = 40
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	# Step indicator
	_step_indicator = Label.new()
	_step_indicator.add_theme_font_size_override("font_size", 22)
	_step_indicator.add_theme_color_override("font_color", ui["info_text"])
	_step_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_step_indicator)

	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(sp1)

	# Title
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 44)
	_title_label.add_theme_color_override("font_color", ui["header_text"])
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(sp2)

	# Description
	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 28)
	_desc_label.add_theme_color_override("font_color", ui["header_text"])
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_desc_label)

	var sp3 := Control.new()
	sp3.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(sp3)

	# Grid visualization area (compact 3 rows)
	_grid_visual = Control.new()
	_grid_visual.custom_minimum_size = Vector2(400, 190)
	_grid_visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_grid_visual)

	var sp4 := Control.new()
	sp4.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(sp4)

	# Next button
	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(300, 70)
	_next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = ui["accent_primary"]
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	_next_button.add_theme_stylebox_override("normal", btn_style)
	_next_button.add_theme_stylebox_override("hover", btn_style)
	_next_button.add_theme_stylebox_override("pressed", btn_style)
	_next_button.add_theme_font_size_override("font_size", 30)
	_next_button.add_theme_color_override("font_color", Color("F9F6F2"))
	_next_button.add_theme_color_override("font_hover_color", Color("F9F6F2"))
	_next_button.add_theme_color_override("font_pressed_color", Color("F9F6F2"))
	_next_button.pressed.connect(_on_next)
	vbox.add_child(_next_button)

	# Center panel
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.offset_left = -350
	_panel.offset_top = -300
	_panel.offset_right = 350
	_panel.offset_bottom = 300


func _show_step(idx: int) -> void:
	_step = idx
	var data: Dictionary = _steps[idx]
	_step_indicator.text = "%d / %d" % [idx + 1, _steps.size()]
	_title_label.text = data["title"]
	_desc_label.text = data["desc"]

	if idx == _steps.size() - 1:
		_next_button.text = "Start!"
	else:
		_next_button.text = "Next"

	# Clear and rebuild grid visual
	for child in _grid_visual.get_children():
		child.queue_free()

	var grid_data: Array = data["grid"]
	_draw_mini_grid(grid_data)


func _on_next() -> void:
	AudioManager.play_sfx("button_click")
	if _step >= _steps.size() - 1:
		# Tutorial complete
		SaveManager.set_value("settings", "drop_tutorial_shown", true)
		ScreenManager.close_popup(self)
	else:
		_show_step(_step + 1)


func _draw_mini_grid(grid_data: Array) -> void:
	var cols: int = 5
	var rows: int = grid_data.size()
	var cell_size: float = 56.0
	var gap: float = 5.0
	var total_w: float = cols * cell_size + (cols + 1) * gap
	var total_h: float = rows * cell_size + (rows + 1) * gap
	var offset_x: float = (_grid_visual.custom_minimum_size.x - total_w) / 2.0
	var offset_y: float = 0.0

	var is_dark: bool = ThemeManager.is_dark()
	var ui: Dictionary = TileColors.get_ui_colors(is_dark)

	# Background
	var bg := ColorRect.new()
	bg.color = ui["grid_bg"]
	bg.size = Vector2(total_w, total_h)
	bg.position = Vector2(offset_x, offset_y)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_visual.add_child(bg)

	for r in rows:
		for c in cols:
			var x: float = offset_x + gap + c * (cell_size + gap)
			var y: float = offset_y + gap + r * (cell_size + gap)

			var cell := ColorRect.new()
			cell.size = Vector2(cell_size, cell_size)
			cell.position = Vector2(x, y)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var val: int = 0
			if r < grid_data.size() and c < grid_data[r].size():
				val = grid_data[r][c]

			if val > 0:
				var style: Dictionary = TileColors.get_tile_style(val, is_dark)
				cell.color = style["bg"]
				_grid_visual.add_child(cell)

				var lbl := Label.new()
				lbl.text = str(val)
				lbl.size = Vector2(cell_size, cell_size)
				lbl.position = Vector2(x, y)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.add_theme_font_size_override("font_size", 30)
				lbl.add_theme_color_override("font_color", style["text"])
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_grid_visual.add_child(lbl)
			else:
				cell.color = ui["empty_cell"]
				_grid_visual.add_child(cell)


# Step grid data generators
func _make_grid_step1() -> Array:
	return [
		[0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0],
		[0, 0, 2, 0, 0],
	]

func _make_grid_step2() -> Array:
	return [
		[0, 0, 0, 0, 0],
		[0, 0, 2, 0, 0],
		[0, 0, 2, 0, 0],
	]

func _make_grid_step3() -> Array:
	return [
		[0, 0, 4, 0, 0],
		[0, 2, 2, 0, 0],
		[4, 8, 4, 2, 0],
	]

func _make_grid_step4() -> Array:
	return [
		[2, 8, 4, 2, 4],
		[4, 2, 16, 8, 2],
		[8, 4, 2, 4, 8],
	]
