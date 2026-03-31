## coin_manager.gd
## Manages coin economy: earning, spending, and balance tracking.
extends Node

signal coins_changed(new_amount: int)

var _coins: int = 0


func _ready() -> void:
	_coins = SaveManager.get_value("progress", "coins", 0)


func get_coins() -> int:
	return _coins


func add_coins(amount: int) -> void:
	if amount <= 0:
		push_warning("CoinManager: add_coins called with non-positive amount: %d" % amount)
		return
	_coins += amount
	SaveManager.set_value("progress", "coins", _coins)
	coins_changed.emit(_coins)


func spend_coins(amount: int) -> bool:
	if _coins < amount:
		return false
	_coins -= amount
	SaveManager.set_value("progress", "coins", _coins)
	coins_changed.emit(_coins)
	return true


## Calculate coin reward based on highest tile achieved in a game.
## Includes first-game bonus and consecutive play bonus.
static func calc_game_reward(highest_tile: int) -> int:
	var base: int = 0
	if highest_tile >= 2048:
		base = 200
	elif highest_tile >= 1024:
		base = 100
	elif highest_tile >= 512:
		base = 50
	elif highest_tile >= 256:
		base = 20
	elif highest_tile >= 128:
		base = 10
	elif highest_tile >= 64:
		base = 5

	# First game ever bonus: +100 coins
	var is_first_game: bool = not bool(SaveManager.get_value("flags", "first_game_completed", false))
	if is_first_game and base > 0:
		SaveManager.set_value("flags", "first_game_completed", true)
		base += 100

	# Consecutive play bonus: +20% after 3+ games in session
	if GameManager.session_games_completed >= 3:
		base = int(base * 1.2)

	return base
