## daily_result_popup.gd
## Post-game popup for Daily Challenge showing results, streak update, and rewards.
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

var _coins_earned: int = 0
var _powerup_earned: String = ""


func enter(data: Dictionary = {}) -> void:
	var score: int = data.get("score", 0)
	var target: int = data.get("target", 0)
	var won: bool = data.get("won", false)

	# Read current progress
	var daily_last: String = SaveManager.get_value("progress", "daily_last_completed", "")
	var old_streak: int = SaveManager.get_value("progress", "daily_streak", 0)

	# Calculate new streak
	var new_streak: int = _calculate_new_streak(daily_last, old_streak)

	# Calculate reward day (1-indexed cycle: streak % 7, if 0 then day 7)
	var reward_index: int = (new_streak % 7) - 1
	if reward_index < 0:
		reward_index = 6  # Day 7

	var reward: Dictionary = STREAK_REWARDS[reward_index]

	if won:
		_coins_earned = reward["coins"]
		_powerup_earned = reward["powerup"]
	else:
		_coins_earned = int(reward["coins"] / 2)
		_powerup_earned = ""

	# Save updated progress
	SaveManager.set_value("progress", "daily_last_completed", DailySeed.get_today_string())
	SaveManager.set_value("progress", "daily_streak", new_streak)

	# Grant rewards
	CoinManager.add_coins(_coins_earned)

	if _powerup_earned != "" and has_node("/root/PowerUpManager"):
		var powerup_name: String = _powerup_earned.split(" x")[0]
		get_node("/root/PowerUpManager").add_powerup(powerup_name)

	_build_ui(score, target, won, old_streak, new_streak)


func _calculate_new_streak(daily_last: String, old_streak: int) -> int:
	if DailySeed.is_same_day(daily_last):
		# Already played today — shouldn't normally happen, keep same streak
		return old_streak

	if daily_last == "" or _is_yesterday(daily_last):
		return old_streak + 1

	# Streak broken — reset to 1
	return 1


func _is_yesterday(date_string: String) -> bool:
	# Parse the stored date and compare to yesterday
	var parts: PackedStringArray = date_string.split("-")
	if parts.size() != 3:
		return false

	var stored_unix: int = Time.get_unix_time_from_datetime_dict({
		"year": parts[0].to_int(),
		"month": parts[1].to_int(),
		"day": parts[2].to_int(),
		"hour": 0, "minute": 0, "second": 0,
	})

	var today: Dictionary = Time.get_date_dict_from_system()
	var today_unix: int = Time.get_unix_time_from_datetime_dict({
		"year": today["year"],
		"month": today["month"],
		"day": today["day"],
		"hour": 0, "minute": 0, "second": 0,
	})

	var diff: int = today_unix - stored_unix
	return diff >= 86400 and diff < 172800  # Between 1 and 2 days


func _build_ui(score: int, target: int, won: bool, old_streak: int, new_streak: int) -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

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

	_add_spacer(vbox, 20)

	# Score vs Target
	var score_label := Label.new()
	score_label.text = "Score: %d / %d" % [score, target]
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", ui["header_text"])
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_label)

	_add_spacer(vbox, 16)

	# Success / Fail indicator
	var status_label := Label.new()
	if won:
		status_label.text = "Target Reached!"
		status_label.add_theme_color_override("font_color", Color("4CAF50"))
	else:
		status_label.text = "Target Missed"
		status_label.add_theme_color_override("font_color", Color("F44336"))
	status_label.add_theme_font_size_override("font_size", 42)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)

	_add_spacer(vbox, 20)

	# Streak update
	var streak_label := Label.new()
	streak_label.text = "Streak: %d > %d!" % [old_streak, new_streak]
	streak_label.add_theme_font_size_override("font_size", 34)
	streak_label.add_theme_color_override("font_color", Color("EDC22E"))
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(streak_label)

	_add_spacer(vbox, 20)

	# Reward earned
	var reward_title := Label.new()
	reward_title.text = "Rewards Earned"
	reward_title.add_theme_font_size_override("font_size", 30)
	reward_title.add_theme_color_override("font_color", ui["header_text"])
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reward_title)

	_add_spacer(vbox, 8)

	var coins_label := Label.new()
	coins_label.text = "+%d coins" % _coins_earned
	coins_label.add_theme_font_size_override("font_size", 32)
	coins_label.add_theme_color_override("font_color", Color("EDC22E"))
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(coins_label)

	if _powerup_earned != "":
		_add_spacer(vbox, 4)
		var powerup_label := Label.new()
		powerup_label.text = "+%s" % _powerup_earned
		powerup_label.add_theme_font_size_override("font_size", 28)
		powerup_label.add_theme_color_override("font_color", Color("4CAF50"))
		powerup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(powerup_label)

	if not won:
		_add_spacer(vbox, 4)
		var half_label := Label.new()
		half_label.text = "(50% reward for attempt)"
		half_label.add_theme_font_size_override("font_size", 24)
		half_label.add_theme_color_override("font_color", ui["info_text"])
		half_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(half_label)

	_add_spacer(vbox, 30)

	# Collect button
	var collect_btn := _create_button("Collect", ui["logo_bg"], Color("F9F6F2"), ui, 400)
	collect_btn.add_theme_font_size_override("font_size", 38)
	collect_btn.pressed.connect(_on_collect)
	vbox.add_child(collect_btn)

	# Center panel
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = -350
	panel.offset_top = -350
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


func _on_collect() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_popup(self)
	ScreenManager.clear_push_stack()
