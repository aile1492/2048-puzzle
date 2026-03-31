## classic_tutorial_popup.gd
## Interactive FTUE tutorial for Classic 2048 mode.
## 4 steps with mini-grid visuals:
##   1. Swipe to move tiles
##   2. Same numbers merge
##   3. Reach 2048 to win
##   4. Use power-ups when stuck
## Shown once on first Classic game. Tap button to advance, skip anytime.
extends BaseScreen

var _step: int = 0
var _steps: Array[Dictionary] = []
var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _desc_label: Label
var _step_indicator: Label
var _next_button: Button
var _skip_button: Button
var _grid_visual: Control
var _active_tweens: Array[Tween] = []  ## Track tweens for cleanup between steps


func enter(data: Dictionary = {}) -> void:
	_steps = [
		{
			"title": "Swipe to Move!",
			"desc": "Swipe in any direction\nto slide all tiles.",
			"grid": _make_grid_swipe(),
			"arrow": "right",
		},
		{
			"title": "Match = Merge!",
			"desc": "When two same numbers meet,\nthey merge into one!",
			"grid": _make_grid_merge(),
			"arrow": "right",
		},
		{
			"title": "Reach 2048!",
			"desc": "Keep merging to reach 2048!\nCan you go even higher?",
			"grid": _make_grid_goal(),
			"arrow": "right",
		},
		{
			"title": "Use Power-ups",
			"desc": "",
			"grid": [],
			"arrow": "",
			"powerup_icons": true,
		},
	]
	_build_ui()
	_show_step(0)


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	# Overlay (blocks input to game behind)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.65)
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Fade in
	_overlay.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_overlay, "modulate:a", 1.0, 0.3)

	# Panel (z_index above overlay to ensure clicks reach buttons on web)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(750, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.z_index = 10
	add_child(_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ui["page_bg"]
	panel_style.set_corner_radius_all(20)
	panel_style.content_margin_left = 40
	panel_style.content_margin_right = 40
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	# Step indicator "1 / 4"
	_step_indicator = Label.new()
	_step_indicator.add_theme_font_size_override("font_size", 22)
	_step_indicator.add_theme_color_override("font_color", ui["info_text"])
	_step_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_step_indicator)

	_add_spacer(vbox, 10)

	# Title
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", ui["header_text"])
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_add_spacer(vbox, 12)

	# Description
	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 28)
	_desc_label.add_theme_color_override("font_color", ui["header_text"])
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_desc_label)

	_add_spacer(vbox, 16)

	# Grid visualization area
	_grid_visual = Control.new()
	_grid_visual.custom_minimum_size = Vector2(400, 200)
	_grid_visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_grid_visual)

	_add_spacer(vbox, 16)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	# Skip button
	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.custom_minimum_size = Vector2(180, 60)
	var skip_style := StyleBoxFlat.new()
	skip_style.bg_color = ui["score_box_bg"]
	skip_style.set_corner_radius_all(10)
	_skip_button.add_theme_stylebox_override("normal", skip_style)
	_skip_button.add_theme_stylebox_override("hover", skip_style)
	_skip_button.add_theme_stylebox_override("pressed", skip_style)
	_skip_button.add_theme_font_size_override("font_size", 26)
	_skip_button.add_theme_color_override("font_color", ui["info_text"])
	_skip_button.add_theme_color_override("font_hover_color", ui["info_text"])
	_skip_button.add_theme_color_override("font_pressed_color", ui["info_text"])
	_skip_button.pressed.connect(_on_skip)
	btn_row.add_child(_skip_button)

	var btn_gap := Control.new()
	btn_gap.custom_minimum_size = Vector2(20, 0)
	btn_row.add_child(btn_gap)

	# Next button
	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(250, 60)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = ui["accent_primary"]
	btn_style.set_corner_radius_all(10)
	_next_button.add_theme_stylebox_override("normal", btn_style)
	_next_button.add_theme_stylebox_override("hover", btn_style)
	_next_button.add_theme_stylebox_override("pressed", btn_style)
	_next_button.add_theme_font_size_override("font_size", 30)
	_next_button.add_theme_color_override("font_color", ui["button_text"])
	_next_button.add_theme_color_override("font_hover_color", ui["button_text"])
	_next_button.add_theme_color_override("font_pressed_color", ui["button_text"])
	_next_button.pressed.connect(_on_next)
	btn_row.add_child(_next_button)

	# Center panel
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.offset_left = -375
	_panel.offset_top = -320
	_panel.offset_right = 375
	_panel.offset_bottom = 320


func _show_step(idx: int) -> void:
	_step = idx
	var data: Dictionary = _steps[idx]
	_step_indicator.text = "%d / %d" % [idx + 1, _steps.size()]
	_title_label.text = data["title"]
	_desc_label.text = data["desc"]

	if idx == _steps.size() - 1:
		_next_button.text = "Start!"
		_skip_button.visible = false
	else:
		_next_button.text = "Next"
		_skip_button.visible = true

	# Kill any active tweens from previous step
	for tw: Tween in _active_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_active_tweens.clear()

	# Clear and rebuild grid visual
	for child in _grid_visual.get_children():
		child.queue_free()

	# Powerup icons step (4/4)
	if data.get("powerup_icons", false):
		_draw_powerup_icons()
	else:
		var grid_data: Array = data.get("grid", [])
		if not grid_data.is_empty():
			_draw_mini_grid(grid_data, data.get("arrow", ""))


func _on_next() -> void:
	AudioManager.play_sfx("button_click")
	if _step >= _steps.size() - 1:
		_complete_tutorial()
	else:
		_show_step(_step + 1)


func _on_skip() -> void:
	AudioManager.play_sfx("button_click")
	_complete_tutorial()


func _complete_tutorial() -> void:
	SaveManager.set_value("ftue", "classic_tutorial_done", true)
	ScreenManager.close_popup(self)


func _draw_mini_grid(grid_data: Array, arrow: String) -> void:
	var cols: int = 4
	var grid_rows: int = grid_data.size()
	var cell_size: float = 52.0
	var gap: float = 5.0
	var total_w: float = cols * cell_size + (cols + 1) * gap
	var total_h: float = grid_rows * cell_size + (grid_rows + 1) * gap
	var offset_x: float = (_grid_visual.custom_minimum_size.x - total_w) / 2.0
	var offset_y: float = (_grid_visual.custom_minimum_size.y - total_h) / 2.0

	var is_dark: bool = ThemeManager.is_dark()
	var ui: Dictionary = TileColors.get_ui_colors(is_dark)

	# Background
	var bg := ColorRect.new()
	bg.color = ui["grid_bg"]
	bg.size = Vector2(total_w, total_h)
	bg.position = Vector2(offset_x, offset_y)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_visual.add_child(bg)

	for r in grid_rows:
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
				lbl.add_theme_font_size_override("font_size", 26 if val < 100 else 20)
				lbl.add_theme_color_override("font_color", style["text"])
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_grid_visual.add_child(lbl)
			else:
				cell.color = ui["empty_cell"]
				_grid_visual.add_child(cell)

	# Arrow indicator (image-based for web compatibility)
	if arrow == "right":
		var arrow_size: float = 96.0
		# Use a fixed-size Control container to prevent texture from expanding
		var arrow_container := Control.new()
		arrow_container.custom_minimum_size = Vector2(arrow_size, arrow_size)
		arrow_container.size = Vector2(arrow_size, arrow_size)
		arrow_container.clip_contents = true
		var arrow_x: float = offset_x + total_w + 6
		var arrow_y: float = offset_y + (total_h - arrow_size) / 2.0
		arrow_container.position = Vector2(arrow_x, arrow_y)
		arrow_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid_visual.add_child(arrow_container)

		var arrow_img := TextureRect.new()
		arrow_img.texture = preload("res://assets/icons/arrow_right.png")
		arrow_img.anchor_right = 1.0
		arrow_img.anchor_bottom = 1.0
		arrow_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arrow_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow_container.add_child(arrow_img)

		var arrow_tween := create_tween().set_loops()
		arrow_tween.tween_property(arrow_container, "position:x", arrow_x + 8, 0.5).set_ease(Tween.EASE_IN_OUT)
		arrow_tween.tween_property(arrow_container, "position:x", arrow_x, 0.5).set_ease(Tween.EASE_IN_OUT)
		_active_tweens.append(arrow_tween)


func _draw_powerup_icons() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	var powerups: Array = [
		{"icon": "res://assets/icons/hammer.png", "name": "Hammer", "desc": "Remove 1 tile"},
		{"icon": "res://assets/icons/shuffle.png", "name": "Shuffle", "desc": "Mix all tiles"},
		{"icon": "res://assets/icons/boom.png", "name": "Bomb", "desc": "Clear nearby tiles"},
	]

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.position = Vector2(20, 0)
	vbox.size = Vector2(_grid_visual.custom_minimum_size.x - 40, _grid_visual.custom_minimum_size.y)
	_grid_visual.add_child(vbox)

	for p: Dictionary in powerups:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(row)

		# Icon in a fixed container
		var icon_container := Control.new()
		icon_container.custom_minimum_size = Vector2(52, 52)
		icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_container)

		var icon := TextureRect.new()
		icon.texture = load(p["icon"])
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(icon)

		# Text: "Name — desc"
		var lbl := Label.new()
		lbl.text = "%s  -  %s" % [p["name"], p["desc"]]
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", ui["header_text"])
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)


func _add_spacer(parent: VBoxContainer, height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)


# ============================================================
# Mini-grid data for each tutorial step
# ============================================================

## Step 1: Swipe — show 2 tiles that will slide right
func _make_grid_swipe() -> Array:
	return [
		[2, 0, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 4, 0],
		[0, 0, 0, 0],
	]

## Step 2: Merge — show 2+2 about to merge
func _make_grid_merge() -> Array:
	return [
		[0, 0, 0, 0],
		[0, 2, 2, 0],
		[0, 0, 0, 0],
		[0, 0, 4, 4],
	]

## Step 3: Goal — show high tiles approaching 2048
func _make_grid_goal() -> Array:
	return [
		[256, 128, 64, 32],
		[512, 0, 0, 16],
		[1024, 0, 0, 0],
		[2048, 0, 0, 0],
	]
