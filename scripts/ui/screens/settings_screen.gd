## settings_screen.gd
## Settings screen with theme, sound volume, and animation speed options.
extends BaseScreen

const _AdConfig = preload("res://scripts/autoload/ad_config.gd")

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
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 40
	vbox.offset_top = 30
	vbox.offset_right = -40
	vbox.offset_bottom = -40
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
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", ui["header_text"])
	top_bar.add_child(title)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer2)

	_add_spacer(vbox, 40)

	# Theme selection
	_add_section_label(vbox, "Theme", ui)
	var theme_row := HBoxContainer.new()
	theme_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(theme_row)

	var themes: Array = [
		{"id": "light", "name": "Light", "color": Color("FAF8EF")},
		{"id": "dark", "name": "Dark", "color": Color("1A1A2E")},
	]
	for t: Dictionary in themes:
		var btn := Button.new()
		btn.text = t["name"]
		btn.custom_minimum_size = Vector2(200, 70)
		var style := StyleBoxFlat.new()
		style.bg_color = t["color"]
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		var is_selected: bool = ThemeManager.current_theme == t["id"]
		style.border_width_left = 3 if is_selected else 0
		style.border_width_right = 3 if is_selected else 0
		style.border_width_top = 3 if is_selected else 0
		style.border_width_bottom = 3 if is_selected else 0
		style.border_color = Color("EDC22E")
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_font_size_override("font_size", 28)
		var text_color: Color = Color("776E65") if t["id"] == "light" else Color("EEE4DA")
		btn.add_theme_color_override("font_color", text_color)
		btn.add_theme_color_override("font_hover_color", text_color)
		btn.add_theme_color_override("font_pressed_color", text_color)
		var theme_id: String = t["id"]
		btn.pressed.connect(func() -> void:
			ThemeManager.set_theme(theme_id)
			_rebuild()
		)
		theme_row.add_child(btn)
		var s := Control.new()
		s.custom_minimum_size = Vector2(15, 0)
		theme_row.add_child(s)

	_add_spacer(vbox, 40)

	# Sound Volume (0-100 slider)
	_add_section_label(vbox, "Sound", ui)
	var volume_row := HBoxContainer.new()
	volume_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(volume_row)

	var vol_icon := Label.new()
	vol_icon.text = "🔇"
	vol_icon.add_theme_font_size_override("font_size", 32)
	volume_row.add_child(vol_icon)

	var vol_spacer1 := Control.new()
	vol_spacer1.custom_minimum_size = Vector2(15, 0)
	volume_row.add_child(vol_spacer1)

	var current_vol: int = AudioManager.get_volume()
	var vol_slider := HSlider.new()
	vol_slider.min_value = 0
	vol_slider.max_value = 100
	vol_slider.step = 1
	vol_slider.value = current_vol
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.custom_minimum_size = Vector2(0, 40)

	# Style the slider
	var slider_style := StyleBoxFlat.new()
	slider_style.bg_color = ui["empty_cell"]
	slider_style.corner_radius_top_left = 4
	slider_style.corner_radius_top_right = 4
	slider_style.corner_radius_bottom_left = 4
	slider_style.corner_radius_bottom_right = 4
	slider_style.content_margin_top = 14
	slider_style.content_margin_bottom = 14
	vol_slider.add_theme_stylebox_override("slider", slider_style)

	var grabber_style := StyleBoxFlat.new()
	grabber_style.bg_color = ui["button_bg"]
	grabber_style.corner_radius_top_left = 4
	grabber_style.corner_radius_top_right = 4
	grabber_style.corner_radius_bottom_left = 4
	grabber_style.corner_radius_bottom_right = 4
	grabber_style.content_margin_top = 14
	grabber_style.content_margin_bottom = 14
	vol_slider.add_theme_stylebox_override("grabber_area", grabber_style)
	vol_slider.add_theme_stylebox_override("grabber_area_highlight", grabber_style)

	volume_row.add_child(vol_slider)

	var vol_spacer2 := Control.new()
	vol_spacer2.custom_minimum_size = Vector2(15, 0)
	volume_row.add_child(vol_spacer2)

	var vol_icon_high := Label.new()
	vol_icon_high.text = "🔊"
	vol_icon_high.add_theme_font_size_override("font_size", 32)
	volume_row.add_child(vol_icon_high)

	_add_spacer(vbox, 5)

	var vol_label := Label.new()
	vol_label.text = "%d%%" % current_vol
	vol_label.add_theme_font_size_override("font_size", 28)
	vol_label.add_theme_color_override("font_color", ui["header_text"])
	vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(vol_label)

	vol_slider.value_changed.connect(func(val: float) -> void:
		var v: int = int(val)
		AudioManager.set_volume(v)
		vol_label.text = "%d%%" % v
		if v > 0:
			vol_icon.text = "🔇"
			vol_icon_high.text = "🔊"
		else:
			vol_icon.text = "🔇"
			vol_icon_high.text = "🔊"
	)

	_add_spacer(vbox, 40)

	# Animation speed
	_add_section_label(vbox, "Animation Speed", ui)
	var anim_speed: float = float(SaveManager.get_value("settings", "animation_speed", 1.0))
	var speed_row := HBoxContainer.new()
	speed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(speed_row)
	for speed_info: Dictionary in [{"label": "Slow", "val": 0.5}, {"label": "Normal", "val": 1.0}, {"label": "Fast", "val": 1.5}]:
		var btn := Button.new()
		btn.text = speed_info["label"]
		btn.custom_minimum_size = Vector2(200, 60)
		var style := StyleBoxFlat.new()
		style.bg_color = ui["button_bg"] if abs(float(speed_info["val"]) - anim_speed) < 0.1 else ui["empty_cell"]
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", ui["button_text"])
		btn.add_theme_color_override("font_hover_color", ui["button_text"])
		btn.add_theme_color_override("font_pressed_color", ui["button_text"])
		var sv: float = speed_info["val"]
		btn.pressed.connect(func() -> void:
			SaveManager.set_value("settings", "animation_speed", sv)
			_rebuild()
		)
		speed_row.add_child(btn)
		var s := Control.new()
		s.custom_minimum_size = Vector2(10, 0)
		speed_row.add_child(s)

	# ===== About / Legal Section =====
	_add_spacer(vbox, 60)
	_add_section_label(vbox, "About", ui)

	# Privacy Policy button
	var privacy_btn := Button.new()
	privacy_btn.text = "Privacy Policy"
	privacy_btn.custom_minimum_size = Vector2(0, 70)
	privacy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var privacy_style := StyleBoxFlat.new()
	privacy_style.bg_color = ui["score_box_bg"]
	privacy_style.set_corner_radius_all(8)
	privacy_btn.add_theme_stylebox_override("normal", privacy_style)
	privacy_btn.add_theme_stylebox_override("hover", privacy_style)
	privacy_btn.add_theme_stylebox_override("pressed", privacy_style)
	privacy_btn.add_theme_font_size_override("font_size", 28)
	privacy_btn.add_theme_color_override("font_color", ui["header_text"])
	privacy_btn.add_theme_color_override("font_hover_color", ui["header_text"])
	privacy_btn.add_theme_color_override("font_pressed_color", ui["header_text"])
	privacy_btn.pressed.connect(func():
		AudioManager.play_sfx("button_click")
		OS.shell_open(_AdConfig.PRIVACY_POLICY_URL)
	)
	vbox.add_child(privacy_btn)

	_add_spacer(vbox, 10)

	# Terms of Service button
	var terms_btn := Button.new()
	terms_btn.text = "Terms of Service"
	terms_btn.custom_minimum_size = Vector2(0, 70)
	terms_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var terms_style := StyleBoxFlat.new()
	terms_style.bg_color = ui["score_box_bg"]
	terms_style.set_corner_radius_all(8)
	terms_btn.add_theme_stylebox_override("normal", terms_style)
	terms_btn.add_theme_stylebox_override("hover", terms_style)
	terms_btn.add_theme_stylebox_override("pressed", terms_style)
	terms_btn.add_theme_font_size_override("font_size", 28)
	terms_btn.add_theme_color_override("font_color", ui["header_text"])
	terms_btn.add_theme_color_override("font_hover_color", ui["header_text"])
	terms_btn.add_theme_color_override("font_pressed_color", ui["header_text"])
	terms_btn.pressed.connect(func():
		AudioManager.play_sfx("button_click")
		OS.shell_open(_AdConfig.TERMS_OF_SERVICE_URL)
	)
	vbox.add_child(terms_btn)

	_add_spacer(vbox, 20)

	# Version label
	var version_label := Label.new()
	version_label.text = "2048 Puzzle v1.0.0"
	version_label.add_theme_font_size_override("font_size", 22)
	version_label.add_theme_color_override("font_color", ui["info_text"])
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(version_label)

	# ===== Debug section (only in debug builds) =====
	if not OS.is_debug_build():
		return
	_add_spacer(vbox, 40)
	_add_section_label(vbox, "Debug", ui)

	var unlimited_btn := Button.new()
	var is_unlimited: bool = PowerUpManager.debug_unlimited if has_node("/root/PowerUpManager") else false
	unlimited_btn.text = "Unlimited Powerups: %s" % ("ON" if is_unlimited else "OFF")
	unlimited_btn.custom_minimum_size = Vector2(400, 70)
	unlimited_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var unlim_style := StyleBoxFlat.new()
	unlim_style.bg_color = Color("FF9800") if is_unlimited else ui["button_bg"]
	unlim_style.set_corner_radius_all(8)
	unlimited_btn.add_theme_stylebox_override("normal", unlim_style)
	unlimited_btn.add_theme_stylebox_override("hover", unlim_style)
	unlimited_btn.add_theme_stylebox_override("pressed", unlim_style)
	unlimited_btn.add_theme_font_size_override("font_size", 26)
	unlimited_btn.add_theme_color_override("font_color", Color.WHITE)
	unlimited_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	unlimited_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	unlimited_btn.pressed.connect(func():
		AudioManager.play_sfx("button_click")
		if has_node("/root/PowerUpManager"):
			PowerUpManager.debug_unlimited = not PowerUpManager.debug_unlimited
		_rebuild()
	)
	vbox.add_child(unlimited_btn)

	_add_spacer(vbox, 15)

	var reset_btn := _create_debug_button("Reset All Save Data", Color("F44336"))
	reset_btn.pressed.connect(func():
		AudioManager.play_sfx("button_click")
		DirAccess.remove_absolute("user://save_data.json")
		DirAccess.remove_absolute("user://save_data.backup.json")
		SaveManager._data = {}
		SaveManager._ensure_defaults()
		reset_btn.text = "Reset Complete!"
		reset_btn.disabled = true
	)
	vbox.add_child(reset_btn)


func _add_section_label(parent: VBoxContainer, text: String, ui: Dictionary) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", ui["header_text"])
	parent.add_child(label)
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 10)
	parent.add_child(s)


func _add_spacer(parent: VBoxContainer, height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)


func _create_debug_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(400, 70)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	return btn


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	call_deferred("_build_ui")
