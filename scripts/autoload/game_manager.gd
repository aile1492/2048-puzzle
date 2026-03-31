## game_manager.gd
## Manages game state, current mode, and game flow.
extends Node

signal state_changed(new_state: StringName)

enum GameState { IDLE, PLAYING, PAUSED, GAME_OVER, WIN, CONTINUE }
enum GameMode { CLASSIC, BOARD_SIZES, TIME_ATTACK, MOVE_LIMIT, DAILY_CHALLENGE, ZEN, DROP }

var current_state: int = GameState.IDLE
var current_mode: int = GameMode.CLASSIC
var current_grid_size: int = 4
var undo_remaining: int = 3
var continue_used: bool = false
var games_played_since_interstitial: int = 0

## Session-based consecutive game counter (resets on app restart)
var session_games_completed: int = 0


func set_state(new_state: int) -> void:
	current_state = new_state
	state_changed.emit(GameState.keys()[new_state])


func start_game(mode: int = GameMode.CLASSIC, grid_size: int = 4) -> void:
	current_mode = mode
	current_grid_size = grid_size
	undo_remaining = 3
	continue_used = false
	set_state(GameState.PLAYING)


func request_undo() -> bool:
	if current_mode == GameMode.ZEN:
		return true
	if undo_remaining > 0:
		undo_remaining -= 1
		return true
	return false


func request_continue() -> bool:
	if continue_used:
		return false
	continue_used = true
	return true
