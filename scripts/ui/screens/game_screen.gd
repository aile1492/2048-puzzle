## game_screen.gd
## Main game screen — v2 layout renewal.
## Header (logo + score/best), action bar, grid, stat row, powerup bar.
extends BaseScreen

const GRID_BOARD_SCENE: PackedScene = preload("res://scenes/game/grid_board.tscn")

var _grid_board: Control
var _input_handler: InputHandler
var _score_value_label: Label
var _best_value_label: Label
var _undo_button: Button
var _new_game_button: Button
var _logo_button: Button
var _page_bg: ColorRect
var _score_box: PanelContainer
var _best_box: PanelContainer
var _moves_label: Label
var _time_label: Label
var _powerup_bar: Control
var _selection_hint: Label
var _action_bar: HBoxContainer
var _moves_box: PanelContainer
var _time_box: PanelContainer
var _coin_box: PanelContainer
var _logo_box: PanelContainer
var _coin_label: Label

var _header_grid: GridContainer
var _header_vbox: VBoxContainer
var _grid_spacer: Control
var _powerup_gap: Control
var _main_vbox: VBoxContainer

var _current_mode: int = GameManager.GameMode.CLASSIC
var _session_game_over_count: int = 0  ## Interstitial ad after 3+ game overs
var _current_grid_size: int = 4
var _best_score: int = 0
var _game_start_time: float = 0.0
var _elapsed_paused: float = 0.0  ## Total time spent paused
var _pause_start_time: float = 0.0  ## When current pause began
var _is_paused: bool = false
var _best_flashed: bool = false

# Time Attack mode
var _time_limit: float = 120.0
var _time_remaining: float = 120.0
var _timer_active: bool = false
var _time_pulse_tween: Tween = null
var _active_floaters: Array[Label] = []  ## Track score floaters for cleanup


func _ready() -> void:
	_build_ui()
	if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
		ThemeManager.theme_changed.connect(_on_theme_changed)


func enter(data: Dictionary = {}) -> void:
	# Reconnect theme signal (disconnected in exit())
	if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
		ThemeManager.theme_changed.connect(_on_theme_changed)

	# Apply current theme (may have changed while on settings screen)
	_on_theme_changed(ThemeManager.current_theme)

	# If returning from Settings overlay (no data, game already running) — just refresh, don't reset
	if data.is_empty() and _grid_board and _grid_board.get_logic() and _grid_board.get_logic().move_count > 0:
		GameManager.set_state(GameManager.GameState.PLAYING)
		return

	_current_mode = data.get("mode", GameManager.GameMode.CLASSIC)
	_current_grid_size = data.get("grid_size", 4)
	_game_start_time = Time.get_ticks_msec() / 1000.0
	_elapsed_paused = 0.0
	_is_paused = false
	_best_flashed = false

	# Load best score (Zen mode uses separate key)
	var mode_suffix: String = "_zen" if _current_mode == GameManager.GameMode.ZEN else ""
	var best_key := "best_score_%dx%d%s" % [_current_grid_size, _current_grid_size, mode_suffix]
	_best_score = int(SaveManager.get_value("stats", best_key, 0))
	_best_value_label.text = str(_best_score)

	GameManager.start_game(_current_mode, _current_grid_size)

	# Mode-specific UI adjustments
	_apply_mode_ui()

	if data.get("resume", false):
		var saved: Dictionary = SaveManager.get_section("current_game")
		var grid_data: Array = saved.get("grid", [])
		# Verify grid has actual tiles (not all zeros)
		var has_tiles: bool = false
		for row: Array in grid_data:
			for val: int in row:
				if val > 0:
					has_tiles = true
					break
			if has_tiles:
				break
		if not saved.is_empty() and grid_data.size() > 0 and has_tiles:
			var board_width := get_viewport_rect().size.x - 40
			_disconnect_grid_signals()  # Prevent handler accumulation on resume
			_grid_board.initialize(_current_grid_size, board_width, _input_handler)
			_grid_board.move_completed.connect(_on_move_completed)
			_grid_board.board_game_over.connect(_on_game_over)
			_grid_board.board_game_won.connect(_on_game_won)
			_grid_board.tile_selected.connect(_on_tile_selected)
			_grid_board.restore_from_dict(saved)
			_update_score_display(_grid_board.get_score())
			_moves_label.text = str(_grid_board.get_move_count())
			# Restore undo count and continue state
			GameManager.undo_remaining = int(saved.get("undo_remaining", 3))
			GameManager.continue_used = bool(saved.get("continue_used", false))
			_undo_button.text = "UNDO (%d)" % GameManager.undo_remaining
			# Restore elapsed time — adjust _game_start_time so timer continues
			var saved_elapsed: float = float(saved.get("elapsed_time", 0.0))
			_game_start_time = (Time.get_ticks_msec() / 1000.0) - saved_elapsed
			_elapsed_paused = 0.0
			# Restore Time Attack remaining
			if _timer_active and saved.has("time_remaining"):
				_time_remaining = float(saved["time_remaining"])
			return
		else:
			# Invalid save data — clear and start fresh
			SaveManager.set_section("current_game", {})

	_start_new_game()

	# Show Classic tutorial on first play
	if _current_mode == GameManager.GameMode.CLASSIC:
		if not bool(SaveManager.get_value("ftue", "classic_tutorial_done", false)):
			ScreenManager.show_popup("res://scenes/popups/classic_tutorial_popup.tscn")

	# Show banner ad
	AdManager.show_banner()

	AnalyticsManager.log_game_start(
		GameManager.GameMode.keys()[_current_mode],
		_current_grid_size
	)


func exit() -> void:
	_save_current_game()

	# Always accumulate play time on exit (even without game over)
	var play_time := (Time.get_ticks_msec() / 1000.0) - _game_start_time - _elapsed_paused
	if play_time > 1.0:  # Only save if played for at least 1 second
		var stats: Dictionary = SaveManager.get_section("stats")
		stats["total_play_time"] = stats.get("total_play_time", 0.0) + play_time
		SaveManager.set_section("stats", stats)

	# Disconnect signals to prevent handler accumulation (#1)
	if ThemeManager.theme_changed.is_connected(_on_theme_changed):
		ThemeManager.theme_changed.disconnect(_on_theme_changed)

	# Disconnect grid_board signals (#2)
	_disconnect_grid_signals()

	# Kill active tweens (#7)
	_stop_time_pulse()

	# Clean up orphaned floaters
	for floater: Label in _active_floaters:
		if is_instance_valid(floater):
			floater.queue_free()
	_active_floaters.clear()


func _apply_mode_ui() -> void:
	## Adjust UI elements based on game mode.
	var is_zen: bool = _current_mode == GameManager.GameMode.ZEN

	# Zen mode: hide powerup bar, hide timer box
	if _powerup_bar:
		_powerup_bar.visible = not is_zen
	if _time_box:
		_time_box.visible = not is_zen

	if is_zen:
		_undo_button.text = "UNDO ∞"

	# Daily Challenge: show TARGET instead of BEST
	if _current_mode == GameManager.GameMode.DAILY_CHALLENGE:
		var title_lbl: Label = _best_box.find_child("Title", true, false)
		if title_lbl:
			title_lbl.text = "TARGET"
		var target: int = DailySeed.get_daily_target_score()
		_best_value_label.text = str(target)


# =============================================================================
# BUILD UI
# =============================================================================

func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	# Full screen background
	_page_bg = ColorRect.new()
	_page_bg.name = "PageBg"
	add_child(_page_bg)
	_page_bg.color = ui["page_bg"]

	# Main VBox layout
	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainLayout"
	add_child(_main_vbox)
	var vbox: VBoxContainer = _main_vbox

	# ===== HEADER BLOCK: GridContainer(3col) + Button Row =====
	# GridContainer ensures columns are perfectly aligned across rows
	_header_vbox = VBoxContainer.new()
	_header_vbox.name = "HeaderVBox"
	_header_vbox.add_theme_constant_override("separation", 22)
	vbox.add_child(_header_vbox)

	_header_grid = GridContainer.new()
	_header_grid.name = "HeaderGrid"
	_header_grid.columns = 3
	_header_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_grid.add_theme_constant_override("h_separation", 25)
	_header_grid.add_theme_constant_override("v_separation", 22)
	_header_vbox.add_child(_header_grid)

	# --- Row 1: [2048] [SCORE] [BEST] (primary, 72px) ---
	_logo_box = _create_logo_box(ui)
	_logo_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_grid.add_child(_logo_box)

	_score_box = _create_stat_box("SCORE", "0", ui, true)
	_score_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_grid.add_child(_score_box)
	_score_value_label = _score_box.find_child("Value", true, false)

	_best_box = _create_stat_box("BEST", "0", ui, true)
	_best_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_grid.add_child(_best_box)
	_best_value_label = _best_box.find_child("Value", true, false)

	# --- Row 2: [MOVES] [TIME] [COIN] (secondary, 48px) ---
	_moves_box = _create_stat_box("MOVES", "0", ui, false)
	_moves_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_grid.add_child(_moves_box)
	_moves_label = _moves_box.find_child("Value", true, false)

	_time_box = _create_stat_box("TIME", "0:00", ui, false)
	_time_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_grid.add_child(_time_box)
	_time_label = _time_box.find_child("Value", true, false)

	_coin_box = _create_stat_box("COIN", str(CoinManager.get_coins()), ui, false)
	_coin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_grid.add_child(_coin_box)
	_coin_label = _coin_box.find_child("Value", true, false)

	# --- Row 3: [NEW] [UNDO] buttons (same 8px gap) ---
	_action_bar = HBoxContainer.new()
	_action_bar.name = "ActionBar"
	_action_bar.add_theme_constant_override("separation", 25)
	_header_vbox.add_child(_action_bar)

	_new_game_button = _create_button("NEW", ui["accent_primary"], ui["button_text"])
	_new_game_button.custom_minimum_size = Vector2(0, 90)
	_new_game_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_action_bar.add_child(_new_game_button)

	_undo_button = _create_button("UNDO", ui["button_bg"], ui["button_text"])
	_undo_button.custom_minimum_size = Vector2(0, 90)
	_undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_button.pressed.connect(_on_undo_pressed)
	_action_bar.add_child(_undo_button)

	# ===== BREATHING ROOM (header → grid, 24px = 3 units) =====
	_grid_spacer = Control.new()
	_grid_spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(_grid_spacer)

	# ===== GRID =====
	var grid_container := CenterContainer.new()
	grid_container.name = "GridContainer"
	vbox.add_child(grid_container)

	_grid_board = GRID_BOARD_SCENE.instantiate()
	grid_container.add_child(_grid_board)

	# ===== POWER-UP BAR (attached below grid, 16px = 2 units) =====
	_powerup_gap = Control.new()
	_powerup_gap.custom_minimum_size = Vector2(0, 16)
	var powerup_gap: Control = _powerup_gap
	vbox.add_child(powerup_gap)

	var PowerupBarScript = load("res://scripts/ui/components/powerup_bar.gd")
	_powerup_bar = PowerupBarScript.new()
	_powerup_bar.name = "PowerupBar"
	vbox.add_child(_powerup_bar)
	_powerup_bar.powerup_requested.connect(_on_powerup_requested)

	# Selection mode hint (hidden by default)
	_selection_hint = Label.new()
	_selection_hint.name = "SelectionHint"
	_selection_hint.text = ""
	_selection_hint.add_theme_font_size_override("font_size", 26)
	_selection_hint.add_theme_color_override("font_color", ui["accent_primary"])
	_selection_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_hint.visible = false
	vbox.add_child(_selection_hint)

	# ===== FLEXIBLE SPACER (absorbs remaining space above ad) =====
	var flex_spacer := Control.new()
	flex_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(flex_spacer)

	# ===== ADMOB BANNER SPACE (320x50dp = ~80px at Godot scale) =====
	var ad_placeholder := ColorRect.new()
	ad_placeholder.name = "AdBannerSpace"
	ad_placeholder.custom_minimum_size = Vector2(0, 80)
	ad_placeholder.color = Color(1, 1, 1, 0.03) if ThemeManager.is_dark() else Color(0, 0, 0, 0.04)
	vbox.add_child(ad_placeholder)

	# ===== INPUT HANDLER =====
	_input_handler = InputHandler.new()
	_input_handler.name = "InputHandler"
	add_child(_input_handler)

	_apply_layout()


func _apply_layout() -> void:
	var viewport_size := get_viewport_rect().size
	_page_bg.size = viewport_size

	var vbox: VBoxContainer = get_node("MainLayout")
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 20
	vbox.offset_top = 40
	vbox.offset_right = -20
	vbox.offset_bottom = 0



## Create the 2048 logo box (gold, tall, with tap-to-pause).
func _create_logo_box(ui: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "LogoBox"
	panel.custom_minimum_size = Vector2(0, 120)

	var style := StyleBoxFlat.new()
	style.bg_color = ui["logo_bg"]
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(inner)

	var title := Label.new()
	title.name = "Value"
	title.text = "2048"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", ui["button_text"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)

	var hint := Label.new()
	hint.name = "LogoHint"
	hint.text = "tap to pause"
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", ui["button_text"])
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(hint)

	# Transparent overlay button for tap-to-pause
	_logo_button = Button.new()
	_logo_button.text = ""
	var empty_style := StyleBoxEmpty.new()
	_logo_button.add_theme_stylebox_override("normal", empty_style)
	_logo_button.add_theme_stylebox_override("hover", empty_style)
	_logo_button.add_theme_stylebox_override("pressed", empty_style)
	_logo_button.anchor_right = 1.0
	_logo_button.anchor_bottom = 1.0
	_logo_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_logo_button.pressed.connect(_on_back_pressed)
	panel.add_child(_logo_button)

	return panel


## Create a stat box for header. is_primary = Row1 (larger), else Row2 (smaller).
func _create_stat_box(label_text: String, value_text: String, ui: Dictionary, is_primary: bool = true) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 120)

	var style := StyleBoxFlat.new()
	style.bg_color = ui["score_box_bg"]
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(inner)

	var label := Label.new()
	label.name = "Title"
	label.text = label_text
	label.add_theme_font_size_override("font_size", 22 if is_primary else 20)
	label.add_theme_color_override("font_color", ui["score_label"])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(label)

	var value := Label.new()
	value.name = "Value"
	value.text = value_text
	value.add_theme_font_size_override("font_size", 40 if is_primary else 36)
	value.add_theme_color_override("font_color", ui["score_value"])
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(value)

	return panel


func _create_score_box(label_text: String, value_text: String, ui: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 44)

	var style := StyleBoxFlat.new()
	style.bg_color = ui["score_box_bg"]
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	var label := Label.new()
	label.name = "Title"
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", ui["score_label"])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var value := Label.new()
	value.name = "Value"
	value.text = value_text
	value.add_theme_font_size_override("font_size", 36)
	value.add_theme_color_override("font_color", ui["score_value"])
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(value)

	return panel


## Slim stat display: "LABEL: value" in a single line, no background box
func _create_slim_stat(label_text: String, value_text: String, ui: Dictionary) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.custom_minimum_size = Vector2(0, 30)

	var label := Label.new()
	label.name = "Title"
	label.text = label_text + ": "
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", ui["info_text"])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)

	var value := Label.new()
	value.name = "Value"
	value.text = value_text
	value.add_theme_font_size_override("font_size", 26)
	value.add_theme_color_override("font_color", ui["header_text"])
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(value)

	return hbox


func _create_button(text: String, bg_color: Color, text_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	# Pressed: slightly darker
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = bg_color.darkened(0.15)
	pressed_style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	return btn


# =============================================================================
# GAME LOOP
# =============================================================================

func _process(delta: float) -> void:
	if not _grid_board or not _grid_board.get_logic():
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Update elapsed time display (non-Time Attack modes), excluding paused time
	if not _timer_active and _time_label and _time_box and _time_box.visible:
		var elapsed := (Time.get_ticks_msec() / 1000.0) - _game_start_time - _elapsed_paused
		_time_label.text = "%d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]

	# Time Attack countdown
	if _timer_active and _time_remaining > 0:
		_time_remaining -= delta
		if _time_remaining <= 0:
			_time_remaining = 0
			_timer_active = false
			_on_game_over()
		_time_label.text = "%d:%02d" % [int(_time_remaining) / 60, int(_time_remaining) % 60]
		var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
		if _time_remaining < 10:
			_time_label.add_theme_color_override("font_color", ui["urgency_red"])
			_start_time_pulse()
		else:
			_time_label.add_theme_color_override("font_color", ui["score_value"])


func _disconnect_grid_signals() -> void:
	## Safely disconnect all grid_board signals to prevent handler accumulation.
	if not _grid_board:
		return
	if _grid_board.move_completed.is_connected(_on_move_completed):
		_grid_board.move_completed.disconnect(_on_move_completed)
	if _grid_board.board_game_over.is_connected(_on_game_over):
		_grid_board.board_game_over.disconnect(_on_game_over)
	if _grid_board.board_game_won.is_connected(_on_game_won):
		_grid_board.board_game_won.disconnect(_on_game_won)
	if _grid_board.tile_selected.is_connected(_on_tile_selected):
		_grid_board.tile_selected.disconnect(_on_tile_selected)


func _start_new_game() -> void:
	var board_width := get_viewport_rect().size.x - 40

	var seed_val: int = -1
	if _current_mode == GameManager.GameMode.DAILY_CHALLENGE:
		seed_val = DailySeed.get_today_seed()

	# Disconnect old signals before reconnecting (#2)
	_disconnect_grid_signals()

	_grid_board.initialize(_current_grid_size, board_width, _input_handler, seed_val)
	_grid_board.move_completed.connect(_on_move_completed)
	_grid_board.board_game_over.connect(_on_game_over)
	_grid_board.board_game_won.connect(_on_game_won)
	_grid_board.tile_selected.connect(_on_tile_selected)
	_update_score_display(0)
	_moves_label.text = "0"
	_undo_button.text = "UNDO (%d)" % GameManager.undo_remaining

	_timer_active = false
	if _current_mode == GameManager.GameMode.TIME_ATTACK:
		_time_limit = 120.0
		_time_remaining = _time_limit
		_timer_active = true
		_time_label.text = "2:00"
		var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
		_time_label.add_theme_color_override("font_color", ui["score_value"])
		_stop_time_pulse()


func _update_score_display(new_score: int) -> void:
	_score_value_label.text = str(new_score)
	if new_score > _best_score:
		_best_score = new_score
		_best_value_label.text = str(_best_score)
		if not _best_flashed:
			_best_flashed = true
			_flash_best_score()


# =============================================================================
# ANIMATIONS
# =============================================================================

func _show_score_floater(score_gained: int) -> void:
	## Show +N floating text above the score box.
	if score_gained < 4:
		return
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	var floater := Label.new()
	floater.text = "+%d" % score_gained
	floater.add_theme_font_size_override("font_size", 28)
	floater.add_theme_color_override("font_color", ui["accent_primary"])
	floater.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floater.z_index = 50
	add_child(floater)

	# Position above score box
	var score_pos: Vector2 = _score_box.global_position
	floater.position = Vector2(score_pos.x, score_pos.y - 8)
	floater.size = Vector2(_score_box.size.x, 40)

	_active_floaters.append(floater)
	var tween := create_tween()
	tween.tween_property(floater, "position:y", score_pos.y - 48, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(floater, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN).set_delay(0.4)
	tween.tween_callback(func() -> void:
		_active_floaters.erase(floater)
		floater.queue_free()
	)


func _flash_best_score() -> void:
	## Flash best score box gold when new record is set.
	var style: StyleBoxFlat = _best_box.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	var original_color: Color = ui["score_box_bg"]
	var flash_color: Color = ui["logo_bg"]

	var tween := create_tween()
	tween.tween_property(style, "bg_color", flash_color, 0.3)
	tween.tween_interval(0.4)
	tween.tween_property(style, "bg_color", original_color, 0.5)


func _start_time_pulse() -> void:
	## Pulse time label when time is running low.
	if _time_pulse_tween and _time_pulse_tween.is_running():
		return
	_time_label.pivot_offset = _time_label.size / 2.0
	_time_pulse_tween = create_tween().set_loops()
	_time_pulse_tween.tween_property(_time_label, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_SINE)
	_time_pulse_tween.tween_property(_time_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


func _stop_time_pulse() -> void:
	if _time_pulse_tween:
		_time_pulse_tween.kill()
		_time_pulse_tween = null
	_time_label.scale = Vector2.ONE


# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_move_completed(score_gained: int) -> void:
	var current_score: int = _grid_board.get_score()
	_update_score_display(current_score)
	_show_score_floater(score_gained)
	_undo_button.text = "UNDO (%d)" % GameManager.undo_remaining
	_moves_label.text = str(_grid_board.get_move_count())

	# FTUE: Introduce power-ups when board gets tight (first time only)
	_check_powerup_intro()

	_save_current_game()


func _on_game_over() -> void:
	# Zen mode: no game over — auto-clear lowest tiles to make space
	if _current_mode == GameManager.GameMode.ZEN:
		_zen_auto_clear()
		return

	AudioManager.play_sfx("game_over")
	GameManager.set_state(GameManager.GameState.GAME_OVER)
	_stop_time_pulse()
	var play_time := (Time.get_ticks_msec() / 1000.0) - _game_start_time - _elapsed_paused

	_update_stats_on_game_end(play_time, false)
	SaveManager.set_section("current_game", {})
	GameManager.session_games_completed += 1

	# Award coins based on highest tile
	var coin_reward: int = CoinManager.calc_game_reward(_grid_board.get_highest_tile())
	if coin_reward > 0:
		CoinManager.add_coins(coin_reward)
		# Update coin display in header
		if _coin_label:
			_coin_label.text = str(CoinManager.get_coins())

	# Daily challenge: show daily result popup
	if _current_mode == GameManager.GameMode.DAILY_CHALLENGE:
		var target: int = DailySeed.get_daily_target_score()
		var final_score: int = _grid_board.get_score()
		ScreenManager.show_popup("res://scenes/popups/daily_result_popup.tscn", {
			"score": final_score,
			"target": target,
			"won": final_score >= target,
		})
		return

	# Interstitial ad after 3rd game over in session
	_session_game_over_count += 1
	if _session_game_over_count >= 3:
		AdManager.interstitial_ad_closed.connect(
			func() -> void:
				_show_classic_game_over(play_time, coin_reward),
			CONNECT_ONE_SHOT
		)
		if not AdManager.try_show_interstitial():
			_show_classic_game_over(play_time, coin_reward)
	else:
		_show_classic_game_over(play_time, coin_reward)


func _show_classic_game_over(play_time: float, coin_reward: int) -> void:
	ScreenManager.show_popup("res://scenes/popups/game_over_popup.tscn", {
		"score": _grid_board.get_score(),
		"best_score": _best_score,
		"highest_tile": _grid_board.get_highest_tile(),
		"move_count": _grid_board.get_move_count(),
		"play_time": play_time,
		"can_continue": not GameManager.continue_used,
		"coin_reward": coin_reward,
		"on_continue": _do_continue,
	})


func _on_game_won() -> void:
	AudioManager.play_sfx("win")
	GameManager.set_state(GameManager.GameState.WIN)
	ScreenManager.show_popup("res://scenes/popups/win_popup.tscn", {
		"score": _grid_board.get_score(),
		"on_keep_going": _do_continue_after_win,
	})


func _do_continue_after_win() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.continue_used = true
	_grid_board.continue_after_win()


func _do_continue() -> void:
	## Continue after game over — remove lowest 4 tiles to free space.
	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.continue_used = true
	var logic: GridLogic = _grid_board.get_logic()
	if not logic:
		return
	# Collect all non-empty positions with values, sorted ascending
	var tile_list: Array = []
	for r in logic.grid_size:
		for c in logic.grid_size:
			if logic.grid[r][c] > 0:
				tile_list.append({"pos": Vector2i(r, c), "val": logic.grid[r][c]})
	tile_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["val"] < b["val"])
	# Remove lowest 4 tiles
	var remove_count: int = mini(4, tile_list.size())
	for i in remove_count:
		var pos: Vector2i = tile_list[i]["pos"]
		logic.grid[pos.x][pos.y] = 0
	_grid_board._rebuild_tiles()
	_save_current_game()


func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_click")
	# Record pause start time
	_is_paused = true
	_pause_start_time = Time.get_ticks_msec() / 1000.0
	GameManager.set_state(GameManager.GameState.PAUSED)
	ScreenManager.show_popup("res://scenes/popups/pause_popup.tscn")


func resume_from_pause() -> void:
	## Called when returning from pause popup or settings.
	if _is_paused:
		_elapsed_paused += (Time.get_ticks_msec() / 1000.0) - _pause_start_time
		_is_paused = false
	GameManager.set_state(GameManager.GameState.PLAYING)


func _on_new_game_pressed() -> void:
	AudioManager.play_sfx("button_click")

	# Confirmation dialog if game is in progress
	var current_score: int = 0
	if _grid_board and _grid_board.get_logic():
		current_score = _grid_board.get_score()

	if current_score > 0 or (_grid_board and _grid_board.get_move_count() > 0):
		ScreenManager.show_popup("res://scenes/popups/confirm_popup.tscn", {
			"title": "New Game",
			"message": "Current progress will be lost.",
			"confirm_text": "New Game",
			"on_confirm": _do_new_game,
		})
		return

	_do_new_game()


func _do_new_game() -> void:
	_best_flashed = false
	GameManager.start_game(_current_mode, _current_grid_size)
	_grid_board.new_game(_current_grid_size)
	_update_score_display(0)
	_moves_label.text = "0"
	_undo_button.text = "UNDO (%d)" % GameManager.undo_remaining
	_game_start_time = Time.get_ticks_msec() / 1000.0
	_elapsed_paused = 0.0
	_is_paused = false
	SaveManager.set_section("current_game", {})
	_stop_time_pulse()

	if _current_mode == GameManager.GameMode.TIME_ATTACK:
		_time_limit = 120.0
		_time_remaining = _time_limit
		_timer_active = true
		_time_label.text = "2:00"
		var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
		_time_label.add_theme_color_override("font_color", ui["info_text"])


func _on_undo_pressed() -> void:
	# Check if undo is actually possible BEFORE consuming undo count
	if not _grid_board or not _grid_board.get_logic():
		return
	if _grid_board.get_logic().history.is_empty():
		return  # Nothing to undo — don't waste undo count

	if GameManager.request_undo():
		if not _grid_board.undo():
			# Undo failed at board level — refund the count
			GameManager.undo_remaining += 1
			return
		_update_score_display(_grid_board.get_score())
		_undo_button.text = "UNDO (%d)" % GameManager.undo_remaining
		_moves_label.text = str(_grid_board.get_move_count())


func _on_powerup_requested(type: String) -> void:
	if not has_node("/root/PowerUpManager"):
		return
	if _current_mode == GameManager.GameMode.ZEN:
		return

	var count: int = PowerUpManager.get_count(type)
	if count <= 0:
		ScreenManager.show_popup("res://scenes/popups/powerup_purchase_popup.tscn", {"type": type})
		return

	if type == "shuffle":
		if not _grid_board.apply_shuffle():
			_show_powerup_blocked_hint()
			return
		PowerUpManager.use_powerup("shuffle")
		AudioManager.play_sfx("tile_slide")
		return

	# Pre-check: enough tiles to use hammer/bomb?
	var grid_logic: GridLogic = _grid_board.get_logic()
	if grid_logic:
		var occupied: int = grid_logic.count_occupied()
		if type == "hammer" and occupied <= GridLogic.MIN_TILES_AFTER_POWERUP:
			_show_powerup_blocked_hint()
			return
		# Bomb could remove up to 5; check worst case (all 5 occupied around any tile)
		if type == "bomb" and occupied <= GridLogic.MIN_TILES_AFTER_POWERUP:
			_show_powerup_blocked_hint()
			return

	# Hammer or Bomb: enter selection mode
	_grid_board.enter_selection_mode(type)
	_input_handler.set_process_input(false)
	_selection_hint.text = "Select a tile to use %s" % type.capitalize()
	_selection_hint.visible = true


func _on_tile_selected(pos: Vector2i) -> void:
	if not _grid_board.is_in_selection_mode():
		return

	var mode: String = _grid_board._selection_mode
	if not has_node("/root/PowerUpManager"):
		_grid_board.exit_selection_mode()
		return

	# Don't waste powerup on empty cells
	var grid_logic: GridLogic = _grid_board.get_logic()
	if grid_logic.grid[pos.x][pos.y] == 0:
		return

	var success: bool = false
	if mode == "hammer":
		success = _grid_board.apply_hammer(pos)
	elif mode == "bomb":
		var removed: Array = _grid_board.apply_bomb(pos)
		success = not removed.is_empty()

	# Logic layer returned false → minimum tile guard triggered
	if not success:
		_show_powerup_blocked_hint()
		_grid_board.exit_selection_mode()
		_input_handler.set_process_input(true)
		return

	if success:
		PowerUpManager.use_powerup(mode)
		AudioManager.play_sfx("button_click")

	_grid_board.exit_selection_mode()
	_input_handler.set_process_input(true)
	_selection_hint.visible = false

	if success:
		_save_current_game()


func _check_powerup_intro() -> void:
	## FTUE: When board has few empty cells, give a free hammer and show a hint.
	if bool(SaveManager.get_value("ftue", "powerup_intro_done", false)):
		return
	if _current_mode == GameManager.GameMode.ZEN:
		return
	var logic: GridLogic = _grid_board.get_logic()
	if not logic:
		return
	var empty_count: int = logic.get_empty_cells().size()
	var threshold: int = 4 if _current_grid_size == 4 else 2
	if empty_count > threshold:
		return

	# Trigger! Give free hammer + show hint
	SaveManager.set_value("ftue", "powerup_intro_done", true)
	if has_node("/root/PowerUpManager"):
		PowerUpManager.add_powerup("hammer", 1)
	_selection_hint.text = "Free Hammer! Tap a tile to remove it"
	_selection_hint.visible = true
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		_selection_hint.visible = false
	, CONNECT_ONE_SHOT)


func _zen_auto_clear() -> void:
	## Zen mode: remove the 4 lowest-value tiles to free space, then continue.
	var logic: GridLogic = _grid_board.get_logic()
	if not logic:
		return
	var tile_list: Array = []
	for r: int in logic.grid_size:
		for c: int in logic.grid_size:
			if logic.grid[r][c] > 0:
				tile_list.append({"pos": Vector2i(r, c), "val": logic.grid[r][c]})
	tile_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["val"] < b["val"])

	var remove_count: int = mini(4, tile_list.size() - GridLogic.MIN_TILES_AFTER_POWERUP)
	if remove_count <= 0:
		return
	for i: int in remove_count:
		var pos: Vector2i = tile_list[i]["pos"]
		logic.grid[pos.x][pos.y] = 0
	_grid_board._rebuild_tiles()
	AudioManager.play_sfx("tile_slide")
	_save_current_game()

	# Brief hint to tell user what happened
	_selection_hint.text = "Space cleared!"
	_selection_hint.visible = true
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		_selection_hint.visible = false
	, CONNECT_ONE_SHOT)


func _show_powerup_blocked_hint() -> void:
	_selection_hint.text = "Not enough tiles to use this power-up"
	_selection_hint.visible = true
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		_selection_hint.visible = false
	, CONNECT_ONE_SHOT)


# =============================================================================
# THEME
# =============================================================================

func _on_theme_changed(_theme_id: String) -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	_page_bg.color = ui["page_bg"]

	# Logo box — gold bg
	if _logo_box:
		var logo_style: StyleBoxFlat = _logo_box.get_theme_stylebox("panel") as StyleBoxFlat
		if logo_style:
			logo_style.bg_color = ui["logo_bg"]
		var logo_val: Label = _logo_box.find_child("Value", true, false)
		if logo_val:
			logo_val.add_theme_color_override("font_color", ui["button_text"])
		var logo_hint: Label = _logo_box.find_child("LogoHint", true, false)
		if logo_hint:
			logo_hint.add_theme_color_override("font_color", ui["button_text"])

	# All stat boxes (SCORE, BEST, MOVES, TIME, COIN)
	for box: PanelContainer in [_score_box, _best_box, _moves_box, _time_box, _coin_box]:
		if box:
			var style: StyleBoxFlat = box.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				style.bg_color = ui["score_box_bg"]
			var lbl: Label = box.find_child("Title", true, false)
			if lbl:
				lbl.add_theme_color_override("font_color", ui["score_label"])
			var val: Label = box.find_child("Value", true, false)
			if val:
				val.add_theme_color_override("font_color", ui["score_value"])

	# Buttons
	var ng_style: StyleBoxFlat = _new_game_button.get_theme_stylebox("normal") as StyleBoxFlat
	if ng_style:
		ng_style.bg_color = ui["accent_primary"]
	_new_game_button.add_theme_color_override("font_color", ui["button_text"])

	var undo_style: StyleBoxFlat = _undo_button.get_theme_stylebox("normal") as StyleBoxFlat
	if undo_style:
		undo_style.bg_color = ui["button_bg"]
	_undo_button.add_theme_color_override("font_color", ui["button_text"])

	# Powerup bar
	if _powerup_bar and _powerup_bar.has_method("refresh_theme"):
		_powerup_bar.refresh_theme()

	# Grid board
	if _grid_board:
		_grid_board.refresh_theme()


# =============================================================================
# STATS
# =============================================================================

func _update_stats_on_game_end(play_time: float, won: bool) -> void:
	var stats: Dictionary = SaveManager.get_section("stats")
	stats["total_games"] = stats.get("total_games", 0) + 1
	stats["total_score"] = stats.get("total_score", 0) + _grid_board.get_score()
	stats["total_moves"] = stats.get("total_moves", 0) + _grid_board.get_move_count()
	# Note: total_play_time is accumulated in exit(), not here, to avoid double-counting
	if won:
		stats["games_won"] = stats.get("games_won", 0) + 1

	var ht: int = _grid_board.get_highest_tile()
	if ht > stats.get("highest_tile", 0):
		stats["highest_tile"] = ht

	var mode_sfx: String = "_zen" if _current_mode == GameManager.GameMode.ZEN else ""
	var best_key := "best_score_%dx%d%s" % [_current_grid_size, _current_grid_size, mode_sfx]
	if _grid_board.get_score() > stats.get(best_key, 0):
		stats[best_key] = _grid_board.get_score()

	SaveManager.set_section("stats", stats)

	AnalyticsManager.log_game_over(
		_grid_board.get_score(),
		_grid_board.get_highest_tile(),
		_grid_board.get_move_count(),
		play_time
	)


## Save current game state including undo count.
func _save_current_game() -> void:
	if not _grid_board or not _grid_board.get_logic():
		return
	var data: Dictionary = _grid_board.get_logic().to_dict()
	data["undo_remaining"] = GameManager.undo_remaining
	data["continue_used"] = GameManager.continue_used
	# Save elapsed time so timer resumes correctly on reload
	var elapsed := (Time.get_ticks_msec() / 1000.0) - _game_start_time - _elapsed_paused
	data["elapsed_time"] = elapsed
	# Time Attack: save remaining time
	if _timer_active:
		data["time_remaining"] = _time_remaining
	SaveManager.set_section("current_game", data)
