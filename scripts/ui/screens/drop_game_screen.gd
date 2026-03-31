## drop_game_screen.gd
## Game screen for Drop mode - Tetris meets 2048.
## Implements: design/gdd/drop_mode.md
## Features: 2-piece next preview (task 3), continue-via-ad (task 2),
##            drop-specific stats (task 4), max-chain tracking (task 4).
extends BaseScreen

const DROP_BOARD_SCENE: PackedScene = preload("res://scenes/game/drop_board.tscn")

var _drop_board: Control
var _score_value_label: Label
var _best_value_label: Label
var _logo_button: Button
var _new_game_button: Button
var _page_bg: ColorRect
var _score_box: PanelContainer
var _best_box: PanelContainer
var _next_label: Label
var _moves_label: Label
var _time_label: Label
var _powerup_bar: Control

var _best_score: int = 0
var _game_start_time: float = 0.0

## Task 2: tracks whether the player has already used the continue-via-ad option this game.
var _continue_used: bool = false

## Task 4: tracks the highest chain combo achieved in the current session.
var _max_chain: int = 0
var _session_game_over_count: int = 0  ## Interstitial ad after 3+ game overs


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

	# If returning from Settings overlay — just refresh theme, don't reset
	if data.is_empty() and _drop_board and _drop_board.get_logic() and _drop_board.get_logic().move_count > 0:
		GameManager.set_state(GameManager.GameState.PLAYING)
		return

	_game_start_time = Time.get_ticks_msec() / 1000.0
	_best_score = int(SaveManager.get_value("stats", "best_score_drop", 0))
	_best_value_label.text = str(_best_score)

	GameManager.start_game(GameManager.GameMode.DROP, 5)

	if data.get("resume", false):
		var saved: Dictionary = SaveManager.get_section("current_game")
		if not saved.is_empty() and saved.get("type", "") == "drop":
			_drop_board.restore_from_dict(saved)
			_update_score_display(_drop_board.get_score())
			_update_next_preview()
			return

	_start_new_game()

	# Task 6: Show tutorial on first play
	if not bool(SaveManager.get_value("settings", "drop_tutorial_shown", false)):
		ScreenManager.show_popup("res://scenes/popups/drop_tutorial_popup.tscn")


func exit() -> void:
	if _drop_board and _drop_board.get_logic():
		SaveManager.set_section("current_game", _drop_board.get_logic().to_dict())

	# Disconnect signals to prevent handler accumulation
	if ThemeManager.theme_changed.is_connected(_on_theme_changed):
		ThemeManager.theme_changed.disconnect(_on_theme_changed)
	_disconnect_board_signals()


func _build_ui() -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())

	_page_bg = ColorRect.new()
	_page_bg.name = "PageBg"
	add_child(_page_bg)
	_page_bg.color = ui["page_bg"]

	var vbox := VBoxContainer.new()
	vbox.name = "MainLayout"
	add_child(vbox)

	# Header: Logo + Scores
	var header := HBoxContainer.new()
	vbox.add_child(header)

	_logo_button = Button.new()
	_logo_button.text = ""
	_logo_button.custom_minimum_size = Vector2(200, 120)
	var logo_style := StyleBoxFlat.new()
	logo_style.bg_color = ui["logo_bg"]
	logo_style.corner_radius_top_left = 12
	logo_style.corner_radius_top_right = 12
	logo_style.corner_radius_bottom_left = 12
	logo_style.corner_radius_bottom_right = 12
	_logo_button.add_theme_stylebox_override("normal", logo_style)
	_logo_button.add_theme_stylebox_override("hover", logo_style)
	_logo_button.add_theme_stylebox_override("pressed", logo_style)
	_logo_button.pressed.connect(_on_back_pressed)
	header.add_child(_logo_button)

	var logo_inner := VBoxContainer.new()
	logo_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_inner.anchor_right = 1.0
	logo_inner.anchor_bottom = 1.0
	logo_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_button.add_child(logo_inner)

	var logo_title := Label.new()
	logo_title.text = "DROP"
	logo_title.add_theme_font_size_override("font_size", 56)
	logo_title.add_theme_color_override("font_color", ui["button_text"])
	logo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_inner.add_child(logo_title)

	var logo_hint := Label.new()
	logo_hint.text = "tap to pause"
	logo_hint.add_theme_font_size_override("font_size", 26)
	logo_hint.add_theme_color_override("font_color", ui["button_text"])
	logo_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_inner.add_child(logo_hint)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var score_vbox := VBoxContainer.new()
	header.add_child(score_vbox)

	_score_box = _create_score_box("SCORE", "0", ui)
	score_vbox.add_child(_score_box)
	_score_value_label = _score_box.find_child("Value", true, false)

	var score_gap := Control.new()
	score_gap.custom_minimum_size = Vector2(0, 8)
	score_vbox.add_child(score_gap)

	_best_box = _create_score_box("BEST", "0", ui)
	score_vbox.add_child(_best_box)
	_best_value_label = _best_box.find_child("Value", true, false)

	# New Game button
	var action_spacer := Control.new()
	action_spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(action_spacer)

	var action_bar := HBoxContainer.new()
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(action_bar)

	_new_game_button = _create_button("NEW GAME", ui["accent_primary"], ui["button_text"])
	_new_game_button.custom_minimum_size = Vector2(300, 60)
	_new_game_button.pressed.connect(_on_new_game)
	action_bar.add_child(_new_game_button)

	# Task 3: Next tile preview - shows 2-piece lookahead e.g. "NEXT: 2 -> 4"
	var next_spacer := Control.new()
	next_spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(next_spacer)

	_next_label = Label.new()
	_next_label.text = "NEXT: 2 -> 4"
	_next_label.add_theme_font_size_override("font_size", 32)
	_next_label.add_theme_color_override("font_color", ui["header_text"])
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_next_label)

	# Grid spacer
	var grid_spacer := Control.new()
	grid_spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(grid_spacer)

	# Drop Board
	var grid_container := CenterContainer.new()
	grid_container.name = "GridContainer"
	vbox.add_child(grid_container)

	_drop_board = DROP_BOARD_SCENE.instantiate()
	grid_container.add_child(_drop_board)

	# Info bar
	var info_spacer := Control.new()
	info_spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(info_spacer)

	var info_bar := HBoxContainer.new()
	vbox.add_child(info_bar)

	_moves_label = Label.new()
	_moves_label.text = "0 drops"
	_moves_label.add_theme_font_size_override("font_size", 26)
	_moves_label.add_theme_color_override("font_color", ui["info_text"])
	_moves_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_bar.add_child(_moves_label)

	_time_label = Label.new()
	_time_label.text = "0:00"
	_time_label.add_theme_font_size_override("font_size", 26)
	_time_label.add_theme_color_override("font_color", ui["info_text"])
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_bar.add_child(_time_label)

	# Powerup bar
	var pu_spacer := Control.new()
	pu_spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(pu_spacer)

	var PowerupBarScript = load("res://scripts/ui/components/powerup_bar.gd")
	_powerup_bar = PowerupBarScript.new()
	_powerup_bar.name = "PowerupBar"
	vbox.add_child(_powerup_bar)

	# Task 7: Column Shift buttons
	var shift_spacer := Control.new()
	shift_spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(shift_spacer)

	var shift_row := HBoxContainer.new()
	shift_row.name = "ShiftRow"
	shift_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(shift_row)

	var shift_left_btn := _create_icon_button("res://assets/icons/shift_left.png", "SHIFT", ui)
	shift_left_btn.custom_minimum_size = Vector2(220, 50)
	shift_left_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click")
		if _drop_board:
			var col: int = _drop_board.get_selected_col()
			_drop_board.apply_column_shift(col, -1)
			_update_score_display(_drop_board.get_score())
	)
	shift_row.add_child(shift_left_btn)

	var shift_gap := Control.new()
	shift_gap.custom_minimum_size = Vector2(20, 0)
	shift_row.add_child(shift_gap)

	var shift_right_btn := _create_icon_button("res://assets/icons/shift_right.png", "SHIFT", ui)
	shift_right_btn.custom_minimum_size = Vector2(220, 50)
	shift_right_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button_click")
		if _drop_board:
			var col: int = _drop_board.get_selected_col()
			_drop_board.apply_column_shift(col, 1)
			_update_score_display(_drop_board.get_score())
	)
	shift_row.add_child(shift_right_btn)

	# Bottom spacer
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(bottom_spacer)

	_apply_layout()


func _apply_layout() -> void:
	_page_bg.size = get_viewport_rect().size
	var v: VBoxContainer = get_node("MainLayout")
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 40
	v.offset_top = 20
	v.offset_right = -40
	v.offset_bottom = -80


func _create_score_box(label_text: String, value_text: String, ui: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 55)
	var style := StyleBoxFlat.new()
	style.bg_color = ui["score_box_bg"]
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)
	var label := Label.new()
	label.name = "Title"
	label.text = label_text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", ui["score_label"])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	var value := Label.new()
	value.name = "Value"
	value.text = value_text
	value.add_theme_font_size_override("font_size", 32)
	value.add_theme_color_override("font_color", ui["score_value"])
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value)
	return panel


func _create_button(text: String, bg_color: Color, text_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	return btn


func _create_icon_button(icon_path: String, label_text: String, ui: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = ""
	var style := StyleBoxFlat.new()
	style.bg_color = ui["button_bg"]
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

	var inner := HBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 8)
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(inner)

	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", ui["button_text"])
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(lbl)

	return btn


func _disconnect_board_signals() -> void:
	if not _drop_board:
		return
	if _drop_board.move_completed.is_connected(_on_move_completed):
		_drop_board.move_completed.disconnect(_on_move_completed)
	if _drop_board.board_game_over.is_connected(_on_game_over):
		_drop_board.board_game_over.disconnect(_on_game_over)
	if _drop_board.board_game_won.is_connected(_on_game_won):
		_drop_board.board_game_won.disconnect(_on_game_won)
	var logic: DropLogic = _drop_board.get_logic()
	if logic and logic.chain_completed.is_connected(_on_chain_completed):
		logic.chain_completed.disconnect(_on_chain_completed)


func _start_new_game() -> void:
	var board_width := get_viewport_rect().size.x * 0.92

	# Disconnect old signals before reconnecting
	_disconnect_board_signals()

	_drop_board.initialize(board_width)
	_drop_board.move_completed.connect(_on_move_completed)
	_drop_board.board_game_over.connect(_on_game_over)
	_drop_board.board_game_won.connect(_on_game_won)
	var logic: DropLogic = _drop_board.get_logic()
	if logic:
		logic.chain_completed.connect(_on_chain_completed)
	_update_score_display(0)
	_update_next_preview()
	_moves_label.text = "0 drops"
	_continue_used = false
	_max_chain = 0


func _process(delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		var elapsed := (Time.get_ticks_msec() / 1000.0) - _game_start_time
		_time_label.text = "%d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]


func _update_score_display(new_score: int) -> void:
	_score_value_label.text = str(new_score)
	if new_score > _best_score:
		_best_score = new_score
		_best_value_label.text = str(_best_score)


## Task 3: Shows "NEXT: A -> B" using the 2-piece lookahead queue.
func _update_next_preview() -> void:
	if not _drop_board or not _drop_board.get_logic():
		return
	var logic: DropLogic = _drop_board.get_logic()
	var queue: Array[int] = logic.get_next_values()
	if queue.size() >= 2:
		_next_label.text = "NEXT: %d -> %d" % [queue[0], queue[1]]
	elif queue.size() == 1:
		_next_label.text = "NEXT: %d" % queue[0]
	else:
		_next_label.text = "NEXT: %d" % logic.next_value


## Task 4: Track max chain; update score display and next preview each move.
func _on_move_completed(score_gained: int) -> void:
	_update_score_display(_drop_board.get_score())
	_moves_label.text = "%d drops" % _drop_board.get_move_count()
	_update_next_preview()

	# Task 4: record highest combo chain this session via the logic signal
	# The chain count comes through the board's move_completed, but chains are
	# emitted before move_completed. We read it via a deferred approach:
	# Instead, we track max_chain by connecting chain_completed in _start_new_game.
	SaveManager.set_section("current_game", _drop_board.get_logic().to_dict())


## Task 2 & 4: Game-over handler with continue-via-ad support and extended stats.
func _on_game_over() -> void:
	AudioManager.play_sfx("game_over")
	GameManager.set_state(GameManager.GameState.GAME_OVER)
	var play_time: float = (Time.get_ticks_msec() / 1000.0) - _game_start_time

	# Task 4: save drop-specific stats
	var stats: Dictionary = SaveManager.get_section("stats")
	stats["total_games"] = stats.get("total_games", 0) + 1
	stats["drop_total_games"] = stats.get("drop_total_games", 0) + 1

	var current_score: int = _drop_board.get_score()
	if current_score > int(stats.get("best_score_drop", 0)):
		stats["best_score_drop"] = current_score
		stats["drop_best_score"] = current_score
	if _max_chain > int(stats.get("drop_max_chain", 0)):
		stats["drop_max_chain"] = _max_chain
	var highest: int = _drop_board.get_highest_tile()
	if highest > int(stats.get("drop_highest_tile", 0)):
		stats["drop_highest_tile"] = highest

	SaveManager.set_section("stats", stats)
	SaveManager.set_section("current_game", {})
	GameManager.session_games_completed += 1

	# Award coins based on highest tile (same formula as classic mode)
	var coin_reward: int = CoinManager.calc_game_reward(highest)
	if coin_reward > 0:
		CoinManager.add_coins(coin_reward)

	# Interstitial ad: show after 3rd game over in this session
	_session_game_over_count += 1
	if _session_game_over_count >= 3:
		AdManager.interstitial_ad_closed.connect(
			func() -> void:
				_show_game_over_popup(current_score, highest, play_time, coin_reward),
			CONNECT_ONE_SHOT
		)
		if not AdManager.try_show_interstitial():
			_show_game_over_popup(current_score, highest, play_time, coin_reward)
	else:
		_show_game_over_popup(current_score, highest, play_time, coin_reward)


func _show_game_over_popup(current_score: int, highest: int, play_time: float, coin_reward: int = 0) -> void:
	ScreenManager.show_popup("res://scenes/popups/game_over_popup.tscn", {
		"score": current_score,
		"best_score": _best_score,
		"highest_tile": highest,
		"move_count": _drop_board.get_move_count(),
		"play_time": play_time,
		"can_continue": not _continue_used,
		"coin_reward": coin_reward,
		"on_continue": _on_continue_game,
	})


## Task 2: Callback passed to the game-over popup's continue button.
func _on_continue_game() -> void:
	_continue_used = true
	GameManager.set_state(GameManager.GameState.PLAYING)
	_drop_board.continue_game()
	_update_next_preview()


## Task 4: Connect this in _start_new_game to track the max chain this session.
func _on_chain_completed(chain_count: int) -> void:
	if chain_count > _max_chain:
		_max_chain = chain_count


func _on_game_won() -> void:
	AudioManager.play_sfx("win")


func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_click")
	ScreenManager.show_popup("res://scenes/popups/pause_popup.tscn")


func _on_new_game() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.start_game(GameManager.GameMode.DROP, 5)

	# Disconnect old logic signals before new_game recreates logic
	_disconnect_board_signals()

	_drop_board.new_game()

	# Reconnect signals for new logic instance
	_drop_board.move_completed.connect(_on_move_completed)
	_drop_board.board_game_over.connect(_on_game_over)
	_drop_board.board_game_won.connect(_on_game_won)
	var logic: DropLogic = _drop_board.get_logic()
	if logic:
		logic.chain_completed.connect(_on_chain_completed)

	_update_score_display(0)
	_update_next_preview()
	_moves_label.text = "0 drops"
	_game_start_time = Time.get_ticks_msec() / 1000.0
	_continue_used = false
	_max_chain = 0
	SaveManager.set_section("current_game", {})


func _on_theme_changed(_theme_id: String) -> void:
	var ui: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
	_page_bg.color = ui["page_bg"]
	var logo_style: StyleBoxFlat = _logo_button.get_theme_stylebox("normal") as StyleBoxFlat
	if logo_style:
		logo_style.bg_color = ui["logo_bg"]
	for box: PanelContainer in [_score_box, _best_box]:
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
	_next_label.add_theme_color_override("font_color", ui["header_text"])
	_moves_label.add_theme_color_override("font_color", ui["info_text"])
	_time_label.add_theme_color_override("font_color", ui["info_text"])
	if _drop_board:
		_drop_board.refresh_theme()
	if _powerup_bar and _powerup_bar.has_method("refresh_theme"):
		_powerup_bar.refresh_theme()
