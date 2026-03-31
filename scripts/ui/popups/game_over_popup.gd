## game_over_popup.gd
## Game over overlay shown on top of the game board.
extends BaseScreen

var _score: int = 0
var _best_score: int = 0
var _highest_tile: int = 0
var _move_count: int = 0
var _play_time: float = 0.0
var _can_continue: bool = false
var _coin_reward: int = 0
var _coin_doubled: bool = false
var _on_continue_callback: Callable


func enter(data: Dictionary = {}) -> void:
	_score = data.get("score", 0)
	_best_score = data.get("best_score", 0)
	_highest_tile = data.get("highest_tile", 0)
	_move_count = data.get("move_count", 0)
	_play_time = data.get("play_time", 0.0)
	_can_continue = data.get("can_continue", false)
	_coin_reward = data.get("coin_reward", 0)
	if data.has("on_continue"):
		_on_continue_callback = data["on_continue"]
	_build_ui()


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	# Overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	add_child(overlay)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0

	overlay.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(overlay, "modulate:a", 1.0, 0.5)

	# Panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(800, 0)
	panel.z_index = 10
	add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ui["page_bg"]
	panel_style.set_corner_radius_all(20)
	panel_style.content_margin_left = 40
	panel_style.content_margin_right = 40
	panel_style.content_margin_top = 40
	panel_style.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Game Over"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", ui["header_text"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_spacer(vbox, 24)

	# Score info
	_add_info_row(vbox, "SCORE", str(_score), ui)
	_add_info_row(vbox, "BEST", str(_best_score), ui)
	_add_info_row(vbox, "HIGHEST TILE", str(_highest_tile), ui)

	_add_spacer(vbox, 8)

	var time_str := "%d:%02d" % [int(_play_time) / 60, int(_play_time) % 60]
	_add_info_row(vbox, "PLAY TIME", time_str, ui)
	_add_info_row(vbox, "MOVES", str(_move_count), ui)

	# New best
	if _score >= _best_score and _score > 0:
		_add_spacer(vbox, 8)
		var new_best := Label.new()
		new_best.text = "New Best!"
		new_best.add_theme_font_size_override("font_size", 48)
		new_best.add_theme_color_override("font_color", ui["logo_bg"])
		new_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(new_best)
		new_best.pivot_offset = new_best.size / 2.0
		var bounce := create_tween().set_loops(3)
		bounce.tween_property(new_best, "scale", Vector2(1.1, 1.1), 0.3)
		bounce.tween_property(new_best, "scale", Vector2.ONE, 0.3)

	# Coin reward
	if _coin_reward > 0:
		_add_spacer(vbox, 8)
		var reward_label := Label.new()
		reward_label.text = "+%d Coins" % _coin_reward
		reward_label.add_theme_font_size_override("font_size", 36)
		reward_label.add_theme_color_override("font_color", ui["logo_bg"])
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(reward_label)

	_add_spacer(vbox, 24)

	# Continue button (watch ad)
	if _can_continue:
		var continue_btn := _create_button("Continue (Watch Ad)", ui, true, ui["accent_primary"])
		continue_btn.pressed.connect(_on_continue_pressed)
		vbox.add_child(continue_btn)
		_add_spacer(vbox, 12)

	# x2 Coins button (watch ad for double reward)
	if _coin_reward > 0:
		var double_btn := _create_button("x2 Coins (Watch Ad)", ui, true, ui["logo_bg"])
		double_btn.pressed.connect(_on_double_coins_pressed.bind(double_btn))
		vbox.add_child(double_btn)
		_add_spacer(vbox, 12)

	# Play Again
	var play_again_btn := _create_button("Play Again", ui, true, ui["button_bg"])
	play_again_btn.pressed.connect(_on_play_again_pressed)
	vbox.add_child(play_again_btn)

	_add_spacer(vbox, 12)

	# Home
	var home_btn := _create_button("Home", ui, false, ui["score_box_bg"])
	home_btn.pressed.connect(_on_home_pressed)
	vbox.add_child(home_btn)

	# Center panel
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = -400
	panel.offset_top = -350
	panel.offset_right = 400
	panel.offset_bottom = 350


func _add_info_row(parent: VBoxContainer, label_text: String, value_text: String, ui: Dictionary) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", ui["header_text"])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 34)
	value.add_theme_color_override("font_color", ui["header_text"])
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)


func _add_spacer(parent: VBoxContainer, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)


func _create_button(text: String, ui: Dictionary, large: bool, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(500 if large else 300, 80 if large else 60)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = bg_color.darkened(0.15)
	pressed_style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_font_size_override("font_size", 32 if large else 26)
	btn.add_theme_color_override("font_color", ui["button_text"])
	btn.add_theme_color_override("font_hover_color", ui["button_text"])
	btn.add_theme_color_override("font_pressed_color", ui["button_text"])
	return btn


func _on_continue_pressed() -> void:
	AudioManager.play_sfx("button_click")
	# Show rewarded ad, then continue on reward
	AdManager.rewarded_ad_completed.connect(_on_rewarded_continue, CONNECT_ONE_SHOT)
	AdManager.show_rewarded_ad("continue")


func _on_rewarded_continue(_type: String) -> void:
	ScreenManager.close_popup(self)
	if _on_continue_callback.is_valid():
		_on_continue_callback.call()
	else:
		push_warning("GameOverPopup: on_continue callback not set, returning to game screen")
		ScreenManager.replace_screen("res://scenes/screens/game_screen.tscn", {
			"mode": GameManager.current_mode,
			"grid_size": GameManager.current_grid_size,
		})


func _on_double_coins_pressed(btn: Button) -> void:
	if _coin_doubled:
		return
	AudioManager.play_sfx("button_click")
	AdManager.rewarded_ad_completed.connect(_on_double_coins_rewarded.bind(btn), CONNECT_ONE_SHOT)
	AdManager.show_rewarded_ad("double_coins")


func _on_double_coins_rewarded(_type: String, btn: Button) -> void:
	if _coin_doubled:
		return
	_coin_doubled = true
	# Grant the same amount again (doubling total)
	CoinManager.add_coins(_coin_reward)
	# Update button to show it's been used
	btn.text = "x2 Applied! +%d" % _coin_reward
	btn.disabled = true
	btn.modulate = Color(1, 1, 1, 0.5)


func _on_play_again_pressed() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_popup(self)
	ScreenManager.replace_screen("res://scenes/screens/game_screen.tscn", {
		"mode": GameManager.current_mode,
		"grid_size": GameManager.current_grid_size,
	})


func _on_home_pressed() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_all_popups()
	ScreenManager.clear_push_stack()
