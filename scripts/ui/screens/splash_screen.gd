## splash_screen.gd
## Splash screen shown on app launch.
## Routes to game (resume) or stays on HomeScreen.
extends BaseScreen


func enter(data: Dictionary = {}) -> void:
	_build_ui()

	# Check for saved game after brief splash
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(_route)


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	var bg := ColorRect.new()
	bg.color = ui["page_bg"]
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var title := Label.new()
	title.text = "2048"
	title.add_theme_font_size_override("font_size", 180)
	title.add_theme_color_override("font_color", Color("EDC22E"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchor_left = 0
	title.anchor_top = 0
	title.anchor_right = 1.0
	title.anchor_bottom = 1.0
	add_child(title)

	# Fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func _route() -> void:
	var saved: Dictionary = SaveManager.get_section("current_game")
	var can_resume: bool = false

	if not saved.is_empty() and saved.has("grid"):
		# Validate save data integrity
		var grid_data: Array = saved.get("grid", [])
		if grid_data.size() > 0 and grid_data[0] is Array and grid_data[0].size() > 0:
			can_resume = true
		else:
			# Corrupted save — clear it
			SaveManager.set_section("current_game", {})

	if can_resume:
		ScreenManager.pop_screen()
		ScreenManager.push_screen("res://scenes/screens/game_screen.tscn", {
			"resume": true,
		})
	else:
		ScreenManager.pop_screen()
