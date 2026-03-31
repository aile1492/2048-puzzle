## powerup_bar.gd
## Horizontal bar of power-up buttons displayed below the game grid.
## Supports long-press to show info card popup, and pulse animation for first-time users.
extends VBoxContainer

signal powerup_requested(type: String)

var _buttons: Dictionary = {}  # type -> Button
var _hint_label: Label
var _is_first_time: bool = false

const LONG_PRESS_DURATION: float = 0.4  # seconds to trigger long press
var _press_timers: Dictionary = {}  # type -> {timer: SceneTreeTimer, pressed: bool}


func _ready() -> void:
	# Check first-time flag BEFORE building UI (so hint label visibility is correct)
	_is_first_time = not bool(SaveManager.get_value("flags", "powerup_intro_seen", false))

	_build()

	if has_node("/root/PowerUpManager"):
		PowerUpManager.powerup_count_changed.connect(_on_count_changed)

	if _is_first_time:
		call_deferred("_start_pulse_animation")


func _build() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	# Button row (fills width, small side margins)
	var hbox := HBoxContainer.new()
	hbox.name = "ButtonRow"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.anchor_right = 1.0
	add_child(hbox)

	var types: Array = [
		{"type": "hammer", "icon_path": "res://assets/icons/hammer.png", "label": "Hammer"},
		{"type": "shuffle", "icon_path": "res://assets/icons/shuffle.png", "label": "Shuffle"},
		{"type": "bomb", "icon_path": "res://assets/icons/boom.png", "label": "Bomb"},
	]

	# Bold font for count labels
	var bold_font := SystemFont.new()
	bold_font.font_weight = 700

	for info: Dictionary in types:
		var btn := Button.new()
		btn.name = info["type"]
		btn.text = ""
		btn.custom_minimum_size = Vector2(0, 76)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style := StyleBoxFlat.new()
		style.bg_color = ui["score_box_bg"]
		style.set_corner_radius_all(8)
		style.content_margin_left = 8
		style.content_margin_right = 8
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		var pressed_style := style.duplicate() as StyleBoxFlat
		pressed_style.bg_color = ui["score_box_bg"].darkened(0.1)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		# HBox inside button: [icon] [x0]
		var inner := HBoxContainer.new()
		inner.name = "Inner"
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 6)
		inner.anchor_right = 1.0
		inner.anchor_bottom = 1.0
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(inner)

		# Icon texture
		var icon_tex := TextureRect.new()
		icon_tex.name = "Icon"
		icon_tex.texture = load(info["icon_path"])
		icon_tex.custom_minimum_size = Vector2(40, 40)
		icon_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon_tex)

		# Count label
		var count: int = 0
		if has_node("/root/PowerUpManager"):
			count = PowerUpManager.get_count(info["type"])
		var lbl := Label.new()
		lbl.name = "Label"
		lbl.text = "x%d" % count
		lbl.add_theme_font_override("font", bold_font)
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.add_theme_color_override("font_color", ui["powerup_text"])
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(lbl)

		# Use button_down/button_up for long-press detection
		var type_str: String = info["type"]
		btn.button_down.connect(_on_button_down.bind(type_str))
		btn.button_up.connect(_on_button_up.bind(type_str))

		hbox.add_child(btn)
		_buttons[info["type"]] = btn

		# Spacer between buttons
		if info["type"] != "bomb":
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(8, 0)
			hbox.add_child(spacer)

	_update_all_counts()

	# Hint label BELOW buttons (always visible)
	var spacer_bottom := Control.new()
	spacer_bottom.custom_minimum_size = Vector2(0, 6)
	add_child(spacer_bottom)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.text = "Hold for info"
	_hint_label.add_theme_font_size_override("font_size", 28)
	_hint_label.add_theme_color_override("font_color", ui["powerup_hint"])
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Auto-hide after 3 completed games
	var games_played: int = int(SaveManager.get_value("stats", "total_games", 0))
	_hint_label.visible = games_played < 3
	add_child(_hint_label)


func _on_button_down(type: String) -> void:
	# Start long-press timer
	var timer := get_tree().create_timer(LONG_PRESS_DURATION)
	_press_timers[type] = {"timer": timer, "long_pressed": false}
	timer.timeout.connect(_on_long_press_timeout.bind(type))


func _on_long_press_timeout(type: String) -> void:
	if _press_timers.has(type):
		_press_timers[type]["long_pressed"] = true
		_show_info_popup(type)


func _on_button_up(type: String) -> void:
	if not _press_timers.has(type):
		# No press data — fallback to normal press
		_on_powerup_pressed(type)
		return

	var data: Dictionary = _press_timers[type]
	_press_timers.erase(type)

	if data["long_pressed"]:
		# Long press already handled — mark first-time as seen
		if _is_first_time:
			_is_first_time = false
			SaveManager.set_value("flags", "powerup_intro_seen", true)
			_stop_pulse_animation()
		return

	# Short press — normal powerup use
	_on_powerup_pressed(type)


func _show_info_popup(type: String) -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.show_popup("res://scenes/popups/powerup_info_popup.tscn", {"type": type})


func _on_powerup_pressed(type: String) -> void:
	AudioManager.play_sfx("button_click")
	powerup_requested.emit(type)


func _on_count_changed(type: String, count: int) -> void:
	_update_button(type, count)


func _update_all_counts() -> void:
	if not has_node("/root/PowerUpManager"):
		return
	for type: String in _buttons:
		_update_button(type, PowerUpManager.get_count(type))


func _update_button(type: String, count: int) -> void:
	if not _buttons.has(type):
		return
	# Update count Label child
	var lbl: Label = _buttons[type].find_child("Label", true, false)
	if lbl:
		lbl.text = "x%d" % count

	# Dim icon + text when count is 0
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	if lbl:
		if count <= 0:
			lbl.add_theme_color_override("font_color", ui["powerup_hint"])
		else:
			lbl.add_theme_color_override("font_color", ui["powerup_text"])
	var icon: TextureRect = _buttons[type].find_child("Icon", true, false)
	if icon:
		icon.modulate = Color(1, 1, 1, 0.4) if count <= 0 else Color.WHITE


func _start_pulse_animation() -> void:
	for type: String in _buttons:
		var btn: Button = _buttons[type]
		var tween := create_tween().set_loops()
		tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		btn.pivot_offset = btn.size / 2.0
		btn.set_meta("pulse_tween", tween)


func _stop_pulse_animation() -> void:
	for type: String in _buttons:
		var btn: Button = _buttons[type]
		if btn.has_meta("pulse_tween"):
			var tween: Tween = btn.get_meta("pulse_tween")
			tween.kill()
			btn.remove_meta("pulse_tween")
			btn.scale = Vector2.ONE


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Cleanup tween references (#3)
		_stop_pulse_animation()
		# Disconnect PowerUpManager signal (#4)
		if has_node("/root/PowerUpManager"):
			if PowerUpManager.powerup_count_changed.is_connected(_on_count_changed):
				PowerUpManager.powerup_count_changed.disconnect(_on_count_changed)


func refresh_theme() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	for type: String in _buttons:
		var btn: Button = _buttons[type]
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if style:
			style.bg_color = ui["score_box_bg"]
		# Update Label child color
		var lbl: Label = btn.find_child("Label", true, false)
		if lbl:
			lbl.add_theme_color_override("font_color", ui["powerup_text"])
	if _hint_label:
		_hint_label.add_theme_color_override("font_color", ui["powerup_hint"])
