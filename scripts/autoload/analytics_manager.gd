## analytics_manager.gd
## Tracks game events. Stub for desktop, Firebase on mobile.
extends Node


func log_event(event_name: String, params: Dictionary = {}) -> void:
	if OS.is_debug_build():
		print("[Analytics] %s: %s" % [event_name, str(params)])


func log_game_start(mode: String, grid_size: int) -> void:
	log_event("game_start", {"mode": mode, "grid_size": grid_size})


func log_game_over(score: int, highest_tile: int, moves: int, duration: float) -> void:
	log_event("game_over", {"score": score, "highest_tile": highest_tile, "moves": moves, "duration": duration})


func log_game_win(score: int, moves: int, duration: float) -> void:
	log_event("game_win", {"score": score, "moves": moves, "duration": duration})
