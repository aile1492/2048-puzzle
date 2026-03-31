## win_popup.gd
## Victory popup shown when 2048 tile is achieved.
extends BaseScreen

var _score: int = 0
var _on_keep_going_callback: Callable


func enter(data: Dictionary = {}) -> void:
	_score = data.get("score", 0)
	if data.has("on_keep_going"):
		_on_keep_going_callback = data["on_keep_going"]
	_build_ui()


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	# Semi-transparent overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	add_child(overlay)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0

	overlay.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(overlay, "modulate:a", 1.0, 0.3)

	# Content panel
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
	panel_style.content_margin_top = 50
	panel_style.content_margin_bottom = 50
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "You Win!"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color("EDC22E"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	var subtitle := Label.new()
	subtitle.text = "2048 Tile Achieved!"
	subtitle.add_theme_font_size_override("font_size", 36)
	subtitle.add_theme_color_override("font_color", ui["header_text"])
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var score_label := Label.new()
	score_label.text = "SCORE: %s" % str(_score)
	score_label.add_theme_font_size_override("font_size", 40)
	score_label.add_theme_color_override("font_color", ui["header_text"])
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_label)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer2)

	var reward := Label.new()
	reward.text = "+200 Coins!"
	reward.add_theme_font_size_override("font_size", 36)
	reward.add_theme_color_override("font_color", Color("EDC22E"))
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reward)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer3)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var keep_btn := Button.new()
	keep_btn.text = "Keep Going"
	keep_btn.custom_minimum_size = Vector2(280, 80)
	var keep_style := StyleBoxFlat.new()
	keep_style.bg_color = ui["button_bg"]
	keep_style.corner_radius_top_left = 10
	keep_style.corner_radius_top_right = 10
	keep_style.corner_radius_bottom_left = 10
	keep_style.corner_radius_bottom_right = 10
	keep_btn.add_theme_stylebox_override("normal", keep_style)
	keep_btn.add_theme_stylebox_override("hover", keep_style)
	keep_btn.add_theme_stylebox_override("pressed", keep_style)
	keep_btn.add_theme_font_size_override("font_size", 32)
	keep_btn.add_theme_color_override("font_color", ui["button_text"])
	keep_btn.add_theme_color_override("font_hover_color", ui["button_text"])
	keep_btn.add_theme_color_override("font_pressed_color", ui["button_text"])
	keep_btn.pressed.connect(_on_keep_going)
	btn_row.add_child(keep_btn)

	var spacer_btn := Control.new()
	spacer_btn.custom_minimum_size = Vector2(20, 0)
	btn_row.add_child(spacer_btn)

	var home_btn := Button.new()
	home_btn.text = "Home"
	home_btn.custom_minimum_size = Vector2(200, 80)
	var home_style: StyleBoxFlat = keep_style.duplicate() as StyleBoxFlat
	home_style.bg_color = ui["score_box_bg"]
	home_btn.add_theme_stylebox_override("normal", home_style)
	home_btn.add_theme_stylebox_override("hover", home_style)
	home_btn.add_theme_stylebox_override("pressed", home_style)
	home_btn.add_theme_font_size_override("font_size", 32)
	home_btn.add_theme_color_override("font_color", ui["button_text"])
	home_btn.add_theme_color_override("font_hover_color", ui["button_text"])
	home_btn.add_theme_color_override("font_pressed_color", ui["button_text"])
	home_btn.pressed.connect(_on_home)
	btn_row.add_child(home_btn)

	# Center panel
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = -350
	panel.offset_top = -250
	panel.offset_right = 350


func _on_keep_going() -> void:
	AudioManager.play_sfx("button_click")
	CoinManager.add_coins(200)
	ScreenManager.close_popup(self)
	if _on_keep_going_callback.is_valid():
		_on_keep_going_callback.call()


func _on_home() -> void:
	AudioManager.play_sfx("button_click")
	CoinManager.add_coins(200)
	ScreenManager.close_all_popups()
	ScreenManager.clear_push_stack()
