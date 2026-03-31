## mode_select_screen.gd
## Mode selection screen with grid of mode cards.
extends BaseScreen

const MODE_DATA: Array = [
	{"id": "classic", "name": "Classic", "desc": "Classic 4x4", "mode": GameManager.GameMode.CLASSIC, "grid_size": 4, "always_unlocked": true},
	{"id": "3x3", "name": "3x3", "desc": "Tiny board", "mode": GameManager.GameMode.BOARD_SIZES, "grid_size": 3, "unlock": "1 win"},
	{"id": "5x5", "name": "5x5", "desc": "Bigger board", "mode": GameManager.GameMode.BOARD_SIZES, "grid_size": 5, "unlock": "1 win"},
	{"id": "6x6", "name": "6x6", "desc": "Huge board", "mode": GameManager.GameMode.BOARD_SIZES, "grid_size": 6, "unlock": "1 win"},
	{"id": "time_attack", "name": "Time Attack", "desc": "Beat the clock!", "mode": GameManager.GameMode.TIME_ATTACK, "grid_size": 4, "unlock": "Level 5"},
	{"id": "zen", "name": "Zen", "desc": "No game over", "mode": GameManager.GameMode.ZEN, "grid_size": 4, "unlock": "Level 15"},
	{"id": "drop", "name": "Drop", "desc": "Tetris meets 2048!", "mode": GameManager.GameMode.DROP, "grid_size": 5, "always_unlocked": true},
]

var _page_bg: ColorRect


func _ready() -> void:
	pass


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

	# Top bar: Back (left) + Title (center)
	var top_bar := HBoxContainer.new()
	vbox.add_child(top_bar)

	var back_btn := Button.new()
	back_btn.text = ""
	back_btn.custom_minimum_size = Vector2(160, 50)
	var back_inner := HBoxContainer.new()
	back_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	back_inner.add_theme_constant_override("separation", 6)
	back_inner.anchor_right = 1.0
	back_inner.anchor_bottom = 1.0
	back_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_btn.add_child(back_inner)
	var back_icon := TextureRect.new()
	back_icon.texture = preload("res://assets/icons/back_arrow.png")
	back_icon.custom_minimum_size = Vector2(28, 28)
	back_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	back_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	back_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_inner.add_child(back_icon)
	var back_label := Label.new()
	back_label.text = "Back"
	back_label.add_theme_font_size_override("font_size", 32)
	back_label.add_theme_color_override("font_color", ui["header_text"])
	back_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_inner.add_child(back_label)
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

	var title := Label.new()
	title.text = "Game Modes"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", ui["header_text"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	# Invisible spacer same width as Back button to keep title centered
	var right_spacer := Control.new()
	right_spacer.custom_minimum_size = Vector2(160, 0)
	top_bar.add_child(right_spacer)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(pad)

	# Scroll container for mode cards
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var cards_vbox := VBoxContainer.new()
	cards_vbox.name = "CardsVBox"
	cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(cards_vbox)

	var games_won: int = int(SaveManager.get_value("stats", "games_won", 0))
	var level: int = int(SaveManager.get_value("progress", "level", 1))

	# Row 1: Classic (full width, hero card)
	var classic_info: Dictionary = MODE_DATA[0]
	var classic_card := _create_mode_card(classic_info, true, ui, true)
	cards_vbox.add_child(classic_card)

	# Row 2-4: pairs in HBoxContainer
	var pairs: Array = [
		[MODE_DATA[1], MODE_DATA[2]],   # 3x3, 5x5
		[MODE_DATA[3], MODE_DATA[4]],   # 6x6, Time Attack
		[MODE_DATA[5], MODE_DATA[6]],   # Zen, Drop
	]
	for pair: Array in pairs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		cards_vbox.add_child(row)
		for mode_info: Dictionary in pair:
			var unlocked: bool = mode_info.get("always_unlocked", false)
			if not unlocked:
				if mode_info["id"] in ["3x3", "5x5", "6x6"]:
					unlocked = games_won >= 1
				elif mode_info["id"] == "time_attack":
					unlocked = level >= 5
				elif mode_info["id"] == "zen":
					unlocked = level >= 15
			if OS.is_debug_build():
				unlocked = true
			var card := _create_mode_card(mode_info, unlocked, ui, false)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(card)

	# Apply layout
	call_deferred("_apply_layout")


func _apply_layout() -> void:
	var vbox: VBoxContainer = get_node("Layout")
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 40
	vbox.offset_top = 30
	vbox.offset_right = -40
	vbox.offset_bottom = -40


func _create_mode_card(mode_info: Dictionary, unlocked: bool, ui: Dictionary, is_hero: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 308 if is_hero else 252)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	if is_hero:
		style.bg_color = ui["logo_bg"]
	elif unlocked:
		style.bg_color = ui["score_box_bg"]
	else:
		style.bg_color = ui["empty_cell"]
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vbox.add_child(name_row)

	var name_label := Label.new()
	name_label.text = mode_info["name"]
	name_label.add_theme_font_size_override("font_size", 56 if is_hero else 44)
	name_label.add_theme_color_override("font_color", ui["button_text"] if is_hero else ui["header_text"])
	name_row.add_child(name_label)

	if not unlocked:
		var lock_icon := TextureRect.new()
		lock_icon.texture = preload("res://assets/icons/lock.png")
		lock_icon.custom_minimum_size = Vector2(32, 32)
		lock_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_child(lock_icon)

	var desc_label := Label.new()
	desc_label.text = mode_info["desc"] if unlocked else mode_info.get("unlock", "Locked")
	desc_label.add_theme_font_size_override("font_size", 34 if is_hero else 30)
	desc_label.add_theme_color_override("font_color", Color(ui["button_text"], 0.8) if is_hero else ui["info_text"])
	vbox.add_child(desc_label)

	if unlocked:
		var btn := Button.new()
		btn.text = "Play"
		btn.custom_minimum_size = Vector2(0, 80 if is_hero else 70)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = ui["button_text"] if is_hero else ui["button_bg"]
		btn_style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_style)
		btn.add_theme_stylebox_override("pressed", btn_style)
		btn.add_theme_font_size_override("font_size", 38 if is_hero else 34)
		var btn_text_color: Color = ui["logo_bg"] if is_hero else ui["button_text"]
		btn.add_theme_color_override("font_color", btn_text_color)
		btn.add_theme_color_override("font_hover_color", btn_text_color)
		btn.add_theme_color_override("font_pressed_color", btn_text_color)
		var mode: int = mode_info["mode"]
		var gs: int = mode_info["grid_size"]
		btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("button_click")
			if mode == GameManager.GameMode.DROP:
				ScreenManager.push_screen("res://scenes/screens/drop_game_screen.tscn")
			else:
				ScreenManager.push_screen("res://scenes/screens/game_screen.tscn", {
					"mode": mode,
					"grid_size": gs,
				})
		)
		vbox.add_child(btn)

	return panel
