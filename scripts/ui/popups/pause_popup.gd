## pause_popup.gd
## Pause menu shown when back button is pressed during game.
extends BaseScreen


func enter(data: Dictionary = {}) -> void:
	GameManager.set_state(GameManager.GameState.PAUSED)
	_build_ui()


func exit() -> void:
	if GameManager.current_state == GameManager.GameState.PAUSED:
		GameManager.set_state(GameManager.GameState.PLAYING)


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	# Overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	add_child(overlay)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0

	# Panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	panel.z_index = 10
	add_child(panel)

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

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", ui["header_text"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	var buttons := ["Resume", "New Game", "Settings", "Home"]
	for btn_text: String in buttons:
		var btn := Button.new()
		btn.text = btn_text
		btn.custom_minimum_size = Vector2(400, 80)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = ui["accent_primary"] if btn_text == "Resume" else ui["button_bg"]
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_font_size_override("font_size", 32)
		btn.add_theme_color_override("font_color", ui["button_text"])
		btn.add_theme_color_override("font_hover_color", ui["button_text"])
		btn.add_theme_color_override("font_pressed_color", ui["button_text"])

		match btn_text:
			"Resume":
				btn.pressed.connect(_on_resume)
			"New Game":
				btn.pressed.connect(_on_new_game)
			"Settings":
				btn.pressed.connect(_on_settings)
			"Home":
				btn.pressed.connect(_on_home)

		vbox.add_child(btn)

		var btn_spacer := Control.new()
		btn_spacer.custom_minimum_size = Vector2(0, 10)
		vbox.add_child(btn_spacer)

	# Center panel
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = -300
	panel.offset_top = -250
	panel.offset_right = 300
	panel.offset_bottom = 250


func _on_resume() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_popup(self)
	# Notify game screen to resume timer
	var game_screen: Node = ScreenManager._push_stack.back() if not ScreenManager._push_stack.is_empty() else null
	if game_screen and game_screen.has_method("resume_from_pause"):
		game_screen.resume_from_pause()


func _on_new_game() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_popup(self)
	ScreenManager.replace_screen("res://scenes/screens/game_screen.tscn", {
		"mode": GameManager.current_mode,
		"grid_size": GameManager.current_grid_size,
	})


func _on_settings() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.push_screen("res://scenes/screens/settings_screen.tscn")
	ScreenManager.close_popup(self)


func _on_home() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_all_popups()
	ScreenManager.clear_push_stack()
