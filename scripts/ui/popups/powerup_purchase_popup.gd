## powerup_purchase_popup.gd
## Popup shown when player tries to use a power-up with 0 remaining.
extends BaseScreen

var _type: String = ""


func enter(data: Dictionary = {}) -> void:
	_type = data.get("type", "hammer")
	_build_ui()


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	var icons: Dictionary = {"hammer": "H", "shuffle": "S", "bomb": "B"}
	var names: Dictionary = {"hammer": "Hammer", "shuffle": "Shuffle", "bomb": "Bomb"}

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
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Icon
	var icon_label := Label.new()
	icon_label.text = icons.get(_type, "?")
	icon_label.add_theme_font_size_override("font_size", 72)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	# Title
	var title := Label.new()
	title.text = "Get %s" % names.get(_type, _type)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", ui["header_text"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	# Buy with coins button
	var cost: int = 0
	if has_node("/root/PowerUpManager"):
		cost = PowerUpManager.get_cost(_type)
	var buy_btn := Button.new()
	buy_btn.text = "Buy (%d coins)" % cost
	buy_btn.custom_minimum_size = Vector2(400, 70)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var buy_style := StyleBoxFlat.new()
	buy_style.bg_color = ui["accent_primary"]
	buy_style.corner_radius_top_left = 8
	buy_style.corner_radius_top_right = 8
	buy_style.corner_radius_bottom_left = 8
	buy_style.corner_radius_bottom_right = 8
	buy_btn.add_theme_stylebox_override("normal", buy_style)
	buy_btn.add_theme_stylebox_override("hover", buy_style)
	buy_btn.add_theme_stylebox_override("pressed", buy_style)
	buy_btn.add_theme_font_size_override("font_size", 28)
	buy_btn.add_theme_color_override("font_color", ui["button_text"])
	buy_btn.add_theme_color_override("font_hover_color", ui["button_text"])
	buy_btn.add_theme_color_override("font_pressed_color", ui["button_text"])
	buy_btn.pressed.connect(_on_buy)
	vbox.add_child(buy_btn)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)

	# Watch ad button
	var ad_remaining: int = 0
	if has_node("/root/PowerUpManager"):
		ad_remaining = PowerUpManager.get_ad_uses_remaining(_type)
	var ad_btn := Button.new()
	ad_btn.text = "Watch Ad (free, %d left today)" % ad_remaining
	ad_btn.custom_minimum_size = Vector2(400, 70)
	ad_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ad_style := StyleBoxFlat.new()
	ad_style.bg_color = ui["accent_secondary"]
	ad_style.corner_radius_top_left = 8
	ad_style.corner_radius_top_right = 8
	ad_style.corner_radius_bottom_left = 8
	ad_style.corner_radius_bottom_right = 8
	ad_btn.add_theme_stylebox_override("normal", ad_style)
	ad_btn.add_theme_stylebox_override("hover", ad_style)
	ad_btn.add_theme_stylebox_override("pressed", ad_style)
	ad_btn.add_theme_font_size_override("font_size", 26)
	ad_btn.add_theme_color_override("font_color", ui["button_text"])
	ad_btn.add_theme_color_override("font_hover_color", ui["button_text"])
	ad_btn.add_theme_color_override("font_pressed_color", ui["button_text"])
	ad_btn.pressed.connect(_on_watch_ad)
	if ad_remaining <= 0:
		ad_btn.modulate = Color(1, 1, 1, 0.4)
		ad_btn.disabled = true
	vbox.add_child(ad_btn)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer3)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(400, 60)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = ui["button_bg"]
	cancel_style.corner_radius_top_left = 8
	cancel_style.corner_radius_top_right = 8
	cancel_style.corner_radius_bottom_left = 8
	cancel_style.corner_radius_bottom_right = 8
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.add_theme_stylebox_override("hover", cancel_style)
	cancel_btn.add_theme_stylebox_override("pressed", cancel_style)
	cancel_btn.add_theme_font_size_override("font_size", 26)
	cancel_btn.add_theme_color_override("font_color", ui["button_text"])
	cancel_btn.add_theme_color_override("font_hover_color", ui["button_text"])
	cancel_btn.add_theme_color_override("font_pressed_color", ui["button_text"])
	cancel_btn.pressed.connect(_on_cancel)
	vbox.add_child(cancel_btn)

	# Center panel
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = -300
	panel.offset_top = -220
	panel.offset_right = 300


func _on_buy() -> void:
	AudioManager.play_sfx("button_click")
	if has_node("/root/PowerUpManager"):
		if PowerUpManager.purchase_with_coins(_type):
			ScreenManager.close_popup(self)
		# else: not enough coins — could show message


func _on_watch_ad() -> void:
	AudioManager.play_sfx("button_click")
	if has_node("/root/PowerUpManager"):
		PowerUpManager.request_ad_powerup(_type)
		ScreenManager.close_popup(self)


func _on_cancel() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.close_popup(self)
