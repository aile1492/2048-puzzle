## home_screen.gd
## Main menu screen with Play button and sub-menu buttons.
extends BaseScreen

var _best_label: Label
var _coin_label: Label
var _page_bg: ColorRect


func _ready() -> void:
	_build_ui()


func enter(data: Dictionary = {}) -> void:
	var best: int = int(SaveManager.get_value("stats", "best_score_4x4", 0))
	_best_label.text = "BEST: %d" % best
	_coin_label.text = "Coins: %s" % str(CoinManager.get_coins())

	# Play BGM if not already playing
	if not AudioManager.is_bgm_playing():
		AudioManager.play_bgm("main_bgm")

	# Refresh theme colors
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	_page_bg.color = ui["page_bg"]
	_best_label.add_theme_color_override("font_color", ui["header_text"])
	_coin_label.add_theme_color_override("font_color", ui["info_text"])


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	# Background
	_page_bg = ColorRect.new()
	add_child(_page_bg)
	_page_bg.color = ui["page_bg"]

	# Main layout
	var vbox := VBoxContainer.new()
	vbox.name = "MainLayout"
	add_child(vbox)

	# Top flexible spacer (pushes content toward center)
	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_top.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer_top)

	# Title "2048" — bigger logo
	var title := Label.new()
	title.text = "2048"
	title.add_theme_font_size_override("font_size", 180)
	title.add_theme_color_override("font_color", ui["header_text"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Best score
	_best_label = Label.new()
	_best_label.text = "BEST: 0"
	_best_label.add_theme_font_size_override("font_size", 40)
	_best_label.add_theme_color_override("font_color", ui["header_text"])
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_best_label)

	# Coin display — right below BEST
	_coin_label = Label.new()
	_coin_label.text = "Coins: 0"
	_coin_label.add_theme_font_size_override("font_size", 32)
	_coin_label.add_theme_color_override("font_color", ui["info_text"])
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_coin_label)

	# Spacer before Play
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(spacer2)

	# Play button (large, gold, full width)
	var play_btn := _create_main_button("PLAY", ui, ui["logo_bg"])
	play_btn.custom_minimum_size = Vector2(0, 130)
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(play_btn)

	# Spacer before sub-buttons
	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer3)

	# Sub-buttons row 1: Daily / Modes
	var row1 := _create_button_row(["Daily", "Modes"], ui)
	vbox.add_child(row1)

	# Small gap between rows
	var row_gap := Control.new()
	row_gap.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(row_gap)

	# Sub-buttons row 2: Stats / Settings
	var row2 := _create_button_row(["Stats", "Settings"], ui)
	vbox.add_child(row2)

	# Bottom flexible spacer
	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_bottom.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer_bottom)

	# Apply layout
	call_deferred("_apply_layout")


func _apply_layout() -> void:
	var viewport_size := get_viewport_rect().size
	_page_bg.size = viewport_size

	var vbox: VBoxContainer = get_node("MainLayout")
	vbox.anchor_left = 0
	vbox.anchor_top = 0
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.offset_left = 60
	vbox.offset_right = -60


func _create_main_button(text: String, ui: Dictionary, override_color: Color = Color.TRANSPARENT) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 130)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = override_color if override_color != Color.TRANSPARENT else ui["button_bg"]
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	hover_style.bg_color = ui["button_bg"].lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_font_size_override("font_size", 48)
	btn.add_theme_color_override("font_color", ui["button_text"])
	btn.add_theme_color_override("font_hover_color", ui["button_text"])
	btn.add_theme_color_override("font_pressed_color", ui["button_text"])
	return btn


func _create_button_row(labels: Array, ui: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	for i in labels.size():
		var btn := Button.new()
		btn.text = labels[i]
		btn.custom_minimum_size = Vector2(0, 100)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		# Color-code specific buttons
		match labels[i]:
			"Daily":
				style.bg_color = ui["accent_primary"]
			"Modes":
				style.bg_color = ui["accent_secondary"]
			_:
				style.bg_color = ui["button_bg"]
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style)
		var hover_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
		hover_style.bg_color = ui["button_bg"].lightened(0.1)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_font_size_override("font_size", 36)
		btn.add_theme_color_override("font_color", ui["button_text"])
		btn.add_theme_color_override("font_hover_color", ui["button_text"])
		btn.add_theme_color_override("font_pressed_color", ui["button_text"])

		# Connect buttons
		match labels[i]:
			"Daily":
				btn.pressed.connect(func():
					AudioManager.play_sfx("button_click")
					ScreenManager.show_popup("res://scenes/popups/daily_challenge_popup.tscn")
				)
			"Stats":
				btn.pressed.connect(func():
					AudioManager.play_sfx("button_click")
					ScreenManager.push_screen("res://scenes/screens/stats_screen.tscn")
				)
			"Theme":
				btn.pressed.connect(func():
					AudioManager.play_sfx("button_click")
					ScreenManager.push_screen("res://scenes/screens/settings_screen.tscn")
				)
			"Settings":
				btn.pressed.connect(func():
					AudioManager.play_sfx("button_click")
					ScreenManager.push_screen("res://scenes/screens/settings_screen.tscn")
				)
			"Modes":
				btn.pressed.connect(func():
					AudioManager.play_sfx("button_click")
					ScreenManager.push_screen("res://scenes/screens/mode_select_screen.tscn")
				)

		row.add_child(btn)

		if i < labels.size() - 1:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(12, 0)
			row.add_child(spacer)

	return row


func _on_play_pressed() -> void:
	AudioManager.play_sfx("button_click")
	# Check if there's a saved game to resume — verify grid has actual tiles
	var saved: Dictionary = SaveManager.get_section("current_game")
	var grid_data: Array = saved.get("grid", [])
	var has_tiles: bool = false
	for row: Variant in grid_data:
		if row is Array:
			for val: Variant in row:
				if int(val) > 0:
					has_tiles = true
					break
		if has_tiles:
			break
	var has_save: bool = not saved.is_empty() and has_tiles
	var saved_type: String = saved.get("type", "")

	if has_save and saved_type != "drop":
		# Resume saved classic/zen/time-attack game
		var grid_size: int = saved.get("grid_size", 4)
		ScreenManager.push_screen("res://scenes/screens/game_screen.tscn", {
			"mode": GameManager.GameMode.CLASSIC,
			"grid_size": grid_size,
			"resume": true,
		})
	else:
		# No saved game — start fresh
		ScreenManager.push_screen("res://scenes/screens/game_screen.tscn", {
			"mode": GameManager.GameMode.CLASSIC,
			"grid_size": 4,
		})
