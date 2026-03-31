## powerup_info_popup.gd
## Shows power-up info card with name, description, and visual range diagram.
extends BaseScreen

var _type: String = ""


func enter(data: Dictionary = {}) -> void:
	_type = data.get("type", "hammer")
	_build_ui()


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	# Semi-transparent overlay (tap to dismiss)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close()
		elif event is InputEventScreenTouch and event.pressed:
			_close()
	)

	# Card panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ui["page_bg"]
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.content_margin_left = 40
	panel_style.content_margin_right = 40
	panel_style.content_margin_top = 40
	panel_style.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.z_index = 10
	add_child(panel)

	# Center panel
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = -270
	panel.offset_top = -260
	panel.offset_right = 270

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Power-up info data
	var info: Dictionary = _get_powerup_info()

	# Icon + Name row
	var title_label := Label.new()
	title_label.text = "%s  %s" % [info["icon"], info["name"]]
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", info["color"])
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	_add_spacer(vbox, 20)

	# Description
	var desc := Label.new()
	desc.text = info["description"]
	desc.add_theme_font_size_override("font_size", 30)
	desc.add_theme_color_override("font_color", ui["header_text"])
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	_add_spacer(vbox, 30)

	# Range visualization grid (3x3)
	var grid_center := CenterContainer.new()
	vbox.add_child(grid_center)

	var grid := _build_range_grid(info, ui)
	grid_center.add_child(grid)

	_add_spacer(vbox, 30)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(200, 70)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = info["color"]
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_stylebox_override("hover", btn_style)
	close_btn.add_theme_stylebox_override("pressed", btn_style)
	close_btn.add_theme_font_size_override("font_size", 30)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	close_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)


func _build_range_grid(info: Dictionary, ui: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	var cell_size := 100

	var pattern: Array = info["pattern"]  # 3x3 array of strings: "", "target", "effect"

	for row: int in 3:
		for col: int in 3:
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(cell_size, cell_size)

			var cell_type: String = pattern[row * 3 + col]

			if cell_type == "target":
				cell.color = info["color"]
			elif cell_type == "effect":
				cell.color = Color(info["color"], 0.4)
			else:
				cell.color = ui["empty_cell"]

			# Add border via margin container
			var margin := MarginContainer.new()
			margin.custom_minimum_size = Vector2(cell_size + 6, cell_size + 6)
			margin.add_theme_constant_override("margin_left", 3)
			margin.add_theme_constant_override("margin_right", 3)
			margin.add_theme_constant_override("margin_top", 3)
			margin.add_theme_constant_override("margin_bottom", 3)
			margin.add_child(cell)
			grid.add_child(margin)

			# Add icon label on target/effect cells
			if cell_type == "target" or cell_type == "effect":
				var icon := Label.new()
				if cell_type == "target":
					icon.text = info["icon"]
				else:
					icon.text = "✕"
				icon.add_theme_font_size_override("font_size", 36)
				icon.add_theme_color_override("font_color", Color.WHITE)
				icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				icon.anchor_right = 1.0
				icon.anchor_bottom = 1.0
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cell.add_child(icon)

	return grid


func _get_powerup_info() -> Dictionary:
	match _type:
		"hammer":
			return {
				"icon": "H",
				"name": "Hammer",
				"description": "Remove 1 selected tile",
				"color": Color("E8825A"),
				"pattern": [
					"", "", "",
					"", "target", "",
					"", "", "",
				],
			}
		"bomb":
			return {
				"icon": "B",
				"name": "Bomb",
				"description": "Remove selected tile and\nadjacent tiles (cross pattern)",
				"color": Color("F44336"),
				"pattern": [
					"", "effect", "",
					"effect", "target", "effect",
					"", "effect", "",
				],
			}
		"shuffle":
			return {
				"icon": "S",
				"name": "Shuffle",
				"description": "Randomly rearrange\nall tiles on the board",
				"color": Color("7CB9B0"),
				"pattern": [
					"effect", "effect", "effect",
					"effect", "target", "effect",
					"effect", "effect", "effect",
				],
			}
		_:
			return {
				"icon": "?",
				"name": "Unknown",
				"description": "",
				"color": Color.GRAY,
				"pattern": ["", "", "", "", "", "", "", "", ""],
			}


func _add_spacer(parent: VBoxContainer, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)


func _close() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_popup(self)
