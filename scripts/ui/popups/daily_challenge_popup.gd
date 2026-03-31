## daily_challenge_popup.gd
## Pre-game popup for Daily Challenge mode showing streak, calendar, and rewards.
extends BaseScreen

const STREAK_REWARDS: Array = [
	{"coins": 50, "powerup": ""},
	{"coins": 75, "powerup": ""},
	{"coins": 100, "powerup": "Hammer x1"},
	{"coins": 100, "powerup": ""},
	{"coins": 150, "powerup": "Shuffle x1"},
	{"coins": 150, "powerup": ""},
	{"coins": 300, "powerup": "Bomb x1"},
]


func enter(data: Dictionary = {}) -> void:
	_build_ui()


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	var daily_last: String = SaveManager.get_value("progress", "daily_last_completed", "")
	var streak: int = SaveManager.get_value("progress", "daily_streak", 0)
	var already_completed: bool = DailySeed.is_same_day(daily_last)
	var target_score: int = DailySeed.get_daily_target_score()
	var cycle_day: int = streak % 7  # 0-6 index into STREAK_REWARDS

	# Overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	add_child(overlay)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0

	# Panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
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

	# Title
	var title := Label.new()
	title.text = "Daily Challenge"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", ui["header_text"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_spacer(vbox, 10)

	# Target score
	var target_label := Label.new()
	target_label.text = "Target Score: %d" % target_score
	target_label.add_theme_font_size_override("font_size", 34)
	target_label.add_theme_color_override("font_color", Color("EDC22E"))
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(target_label)

	_add_spacer(vbox, 20)

	# 7-day calendar row
	var calendar_hbox := HBoxContainer.new()
	calendar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	calendar_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(calendar_hbox)

	for i: int in range(7):
		var day_label := Label.new()
		day_label.add_theme_font_size_override("font_size", 32)
		day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_label.custom_minimum_size = Vector2(50, 50)

		if i < cycle_day:
			# Completed days
			day_label.text = "✓"
			day_label.add_theme_color_override("font_color", Color("4CAF50"))
		elif i == cycle_day:
			# Today
			day_label.text = "☆"
			day_label.add_theme_color_override("font_color", Color("EDC22E"))
		else:
			# Upcoming
			day_label.text = "○"
			day_label.add_theme_color_override("font_color", ui["info_text"])

		calendar_hbox.add_child(day_label)

	_add_spacer(vbox, 16)

	# Streak count
	var streak_label := Label.new()
	streak_label.text = "%d Day Streak!" % streak
	streak_label.add_theme_font_size_override("font_size", 36)
	streak_label.add_theme_color_override("font_color", Color("EDC22E"))
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(streak_label)

	_add_spacer(vbox, 16)

	# Today's reward preview
	var reward: Dictionary = STREAK_REWARDS[cycle_day]
	var reward_text: String = "Today's Reward: %d coins" % reward["coins"]
	if reward["powerup"] != "":
		reward_text += " + %s" % reward["powerup"]

	var reward_label := Label.new()
	reward_label.text = reward_text
	reward_label.add_theme_font_size_override("font_size", 28)
	reward_label.add_theme_color_override("font_color", ui["header_text"])
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reward_label)

	_add_spacer(vbox, 30)

	if already_completed:
		# Already completed today
		var done_label := Label.new()
		done_label.text = "✓ Completed Today!"
		done_label.add_theme_font_size_override("font_size", 36)
		done_label.add_theme_color_override("font_color", Color("4CAF50"))
		done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(done_label)

		_add_spacer(vbox, 10)

		var tomorrow_label := Label.new()
		tomorrow_label.text = "Come back tomorrow!"
		tomorrow_label.add_theme_font_size_override("font_size", 26)
		tomorrow_label.add_theme_color_override("font_color", ui["info_text"])
		tomorrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(tomorrow_label)

		_add_spacer(vbox, 20)

		# Close button
		var close_btn := _create_button("Close", ui["button_bg"], ui["button_text"], ui, 400)
		close_btn.pressed.connect(_on_close)
		vbox.add_child(close_btn)
	else:
		# Play button (gold color)
		var play_btn := _create_button("PLAY", ui["logo_bg"], Color("F9F6F2"), ui, 400)
		play_btn.add_theme_font_size_override("font_size", 40)
		play_btn.pressed.connect(_on_play)
		vbox.add_child(play_btn)

		_add_spacer(vbox, 12)

		# Close / Back button
		var close_btn := _create_button("Back", ui["button_bg"], ui["button_text"], ui, 400)
		close_btn.pressed.connect(_on_close)
		vbox.add_child(close_btn)

	# Center panel
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = -350
	panel.offset_top = -300
	panel.offset_right = 350


func _add_spacer(parent: Control, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)


func _create_button(text: String, bg_color: Color, text_color: Color, ui: Dictionary, width: float) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(width, 80)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	return btn


func _on_play() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_popup(self)
	ScreenManager.push_screen("res://scenes/screens/game_screen.tscn", {
		"mode": GameManager.GameMode.DAILY_CHALLENGE,
		"grid_size": 4,
	})


func _on_close() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_popup(self)
