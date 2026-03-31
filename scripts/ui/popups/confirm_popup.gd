## confirm_popup.gd
## Generic confirmation dialog popup.
extends BaseScreen

var _on_confirm: Callable


func enter(data: Dictionary = {}) -> void:
	var title_text: String = data.get("title", "Confirm")
	var message_text: String = data.get("message", "Are you sure?")
	var confirm_text: String = data.get("confirm_text", "OK")
	if data.has("on_confirm"):
		_on_confirm = data["on_confirm"]
	_build_ui(title_text, message_text, confirm_text)


func _build_ui(title_text: String, message_text: String, confirm_text: String) -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	# Overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0

	# Panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	panel.z_index = 10
	add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ui["page_bg"]
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 40
	panel_style.content_margin_right = 40
	panel_style.content_margin_top = 32
	panel_style.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", ui["header_text"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer1)

	# Message
	var msg := Label.new()
	msg.text = message_text
	msg.add_theme_font_size_override("font_size", 28)
	msg.add_theme_color_override("font_color", ui["info_text"])
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer2)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(180, 60)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = ui["button_bg"]
	cancel_style.set_corner_radius_all(8)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.add_theme_stylebox_override("hover", cancel_style)
	cancel_btn.add_theme_stylebox_override("pressed", cancel_style)
	cancel_btn.add_theme_font_size_override("font_size", 26)
	cancel_btn.add_theme_color_override("font_color", ui["button_text"])
	cancel_btn.pressed.connect(_on_cancel)
	btn_row.add_child(cancel_btn)

	var btn_gap := Control.new()
	btn_gap.custom_minimum_size = Vector2(16, 0)
	btn_row.add_child(btn_gap)

	var confirm_btn := Button.new()
	confirm_btn.text = confirm_text
	confirm_btn.custom_minimum_size = Vector2(180, 60)
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = ui["accent_primary"]
	confirm_style.set_corner_radius_all(8)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.add_theme_stylebox_override("hover", confirm_style)
	confirm_btn.add_theme_stylebox_override("pressed", confirm_style)
	confirm_btn.add_theme_font_size_override("font_size", 26)
	confirm_btn.add_theme_color_override("font_color", ui["button_text"])
	confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(confirm_btn)

	# Center panel
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = -250
	panel.offset_top = -120
	panel.offset_right = 250


func _on_cancel() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_popup(self)


func _on_confirm_pressed() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_popup(self)
	if _on_confirm.is_valid():
		_on_confirm.call()
