## stats_screen.gd
## Statistics screen showing aggregate play data.
extends BaseScreen

var _page_bg: ColorRect


func enter(data: Dictionary = {}) -> void:
	_build_ui()


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	_page_bg = ColorRect.new()
	add_child(_page_bg)
	_page_bg.color = ui["page_bg"]
	_page_bg.anchor_right = 1.0
	_page_bg.anchor_bottom = 1.0

	var vbox := VBoxContainer.new()
	vbox.name = "Layout"
	add_child(vbox)

	# Top bar
	var top_bar := HBoxContainer.new()
	vbox.add_child(top_bar)

	var back_btn := Button.new()
	back_btn.text = ""
	back_btn.custom_minimum_size = Vector2(160, 50)
	var _back_inner := HBoxContainer.new()
	_back_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	_back_inner.add_theme_constant_override("separation", 6)
	_back_inner.anchor_right = 1.0
	_back_inner.anchor_bottom = 1.0
	_back_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_btn.add_child(_back_inner)
	var _back_icon := TextureRect.new()
	_back_icon.texture = preload("res://assets/icons/back_arrow.png")
	_back_icon.custom_minimum_size = Vector2(28, 28)
	_back_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_back_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_back_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_inner.add_child(_back_icon)
	var _back_lbl := Label.new()
	_back_lbl.text = "Back"
	_back_lbl.add_theme_font_size_override("font_size", 32)
	_back_lbl.add_theme_color_override("font_color", ui["header_text"])
	_back_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_inner.add_child(_back_lbl)
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click")
		ScreenManager.pop_screen()
	)
	back_btn.add_theme_font_size_override("font_size", 32)
	back_btn.add_theme_color_override("font_color", ui["header_text"])
	back_btn.add_theme_color_override("font_hover_color", ui["header_text"])
	back_btn.add_theme_color_override("font_pressed_color", ui["header_text"])
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color.TRANSPARENT
	back_btn.add_theme_stylebox_override("normal", back_style)
	back_btn.add_theme_stylebox_override("hover", back_style)
	back_btn.add_theme_stylebox_override("pressed", back_style)
	top_bar.add_child(back_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var title := Label.new()
	title.text = "Statistics"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", ui["header_text"])
	top_bar.add_child(title)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer2)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(pad)

	# Stats data
	var stats: Dictionary = SaveManager.get_section("stats")

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var stats_vbox := VBoxContainer.new()
	scroll.add_child(stats_vbox)

	_add_stat_row(stats_vbox, "Total Games", str(int(stats.get("total_games", 0))), ui)
	_add_stat_row(stats_vbox, "Games Won", str(int(stats.get("games_won", 0))), ui)

	var total_games: int = int(stats.get("total_games", 0))
	var games_won: int = int(stats.get("games_won", 0))
	var win_rate: String = "0%"
	if total_games > 0:
		win_rate = "%d%%" % (games_won * 100 / total_games)
	_add_stat_row(stats_vbox, "Win Rate", win_rate, ui)

	_add_stat_row(stats_vbox, "Highest Tile", str(int(stats.get("highest_tile", 0))), ui)
	_add_stat_row(stats_vbox, "Total Score", str(int(stats.get("total_score", 0))), ui)

	_add_spacer(stats_vbox, 20)
	_add_section_label(stats_vbox, "Best Scores", ui)
	_add_stat_row(stats_vbox, "3x3 Best", str(int(stats.get("best_score_3x3", 0))), ui)
	_add_stat_row(stats_vbox, "4x4 Best", str(int(stats.get("best_score_4x4", 0))), ui)
	_add_stat_row(stats_vbox, "5x5 Best", str(int(stats.get("best_score_5x5", 0))), ui)
	_add_stat_row(stats_vbox, "6x6 Best", str(int(stats.get("best_score_6x6", 0))), ui)

	_add_spacer(stats_vbox, 20)
	_add_section_label(stats_vbox, "Activity", ui)
	_add_stat_row(stats_vbox, "Total Moves", str(int(stats.get("total_moves", 0))), ui)

	_add_stat_row(stats_vbox, "Current Streak", "%d days" % int(stats.get("current_streak", 0)), ui)
	_add_stat_row(stats_vbox, "Best Streak", "%d days" % int(stats.get("best_streak", 0)), ui)

	call_deferred("_apply_layout")


func _apply_layout() -> void:
	var vbox: VBoxContainer = get_node("Layout")
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 40
	vbox.offset_top = 30
	vbox.offset_right = -40
	vbox.offset_bottom = -40


func _add_stat_row(parent: VBoxContainer, label_text: String, value_text: String, ui: Dictionary) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", ui["info_text"])
	label.custom_minimum_size = Vector2(300, 0)
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 36)
	value.add_theme_color_override("font_color", ui["header_text"])
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)

	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 8)
	parent.add_child(s)


func _add_section_label(parent: VBoxContainer, text: String, ui: Dictionary) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color("EDC22E"))
	parent.add_child(label)
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 10)
	parent.add_child(s)


func _add_spacer(parent: VBoxContainer, height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)
