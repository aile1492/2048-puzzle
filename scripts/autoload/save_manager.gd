## save_manager.gd
## Handles JSON save/load with backup for game data persistence.
extends Node

signal data_loaded
signal data_saved

const SAVE_PATH: String = "user://save_data.json"
const BACKUP_PATH: String = "user://save_data.backup.json"
const SAVE_VERSION: int = 1

var _data: Dictionary = {}
var _save_pending: bool = false  ## Debounce: coalesce multiple saves per frame


func _ready() -> void:
	_load_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_save()  # Force immediate save on focus-out/quit


func get_data() -> Dictionary:
	return _data


func set_value(section: String, key: String, value: Variant) -> void:
	if not _data.has(section):
		_data[section] = {}
	_data[section][key] = value
	_request_save()


func get_value(section: String, key: String, default: Variant = null) -> Variant:
	if _data.has(section) and _data[section].has(key):
		return _data[section][key]
	return default


func get_section(section: String) -> Dictionary:
	return _data.get(section, {})


func set_section(section: String, value: Dictionary) -> void:
	_data[section] = value
	_request_save()


## Debounced save — coalesces multiple saves in the same frame (#7).
func _request_save() -> void:
	if _save_pending:
		return
	_save_pending = true
	call_deferred("_flush_save")


## Force immediate write to disk.
func _flush_save() -> void:
	_save_pending = false
	_save_data()


func _save_data() -> void:
	# Backup current file first
	if FileAccess.file_exists(SAVE_PATH):
		var current := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if current:
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup:
				backup.store_string(current.get_as_text())

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		_data["version"] = SAVE_VERSION
		file.store_string(JSON.stringify(_data, "\t"))
		data_saved.emit()


func _load_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				_data = json.data
				_ensure_defaults()
				data_loaded.emit()
				return

	# Try backup — validate JSON integrity before using (#8)
	if FileAccess.file_exists(BACKUP_PATH):
		var file := FileAccess.open(BACKUP_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			var backup_text := file.get_as_text()
			if json.parse(backup_text) == OK and json.data is Dictionary:
				_data = json.data
				_ensure_defaults()
				push_warning("SaveManager: Primary save corrupted, restored from backup")
				data_loaded.emit()
				return
			else:
				push_warning("SaveManager: Backup also corrupted, starting fresh")

	# Fresh start
	_data = {}
	_ensure_defaults()
	data_loaded.emit()


func _ensure_defaults() -> void:
	if not _data.has("settings"):
		_data["settings"] = {
			"theme": "light",
			"sound": true,
			"vibration": true,
			"animation_speed": 1.0,
			"swipe_sensitivity": 1.0,
			"language": "en",
		}
	if not _data.has("stats"):
		_data["stats"] = {
			"total_games": 0,
			"total_score": 0,
			"best_score_3x3": 0,
			"best_score_4x4": 0,
			"best_score_5x5": 0,
			"best_score_6x6": 0,
			"highest_tile": 0,
			"total_moves": 0,
			"total_merges": 0,
			"total_play_time": 0,
			"games_won": 0,
			"current_streak": 0,
			"best_streak": 0,
		}
	if not _data.has("progress"):
		_data["progress"] = {
			"level": 1,
			"coins": 0,
			"unlocked_themes": ["light", "dark"],
			"unlocked_modes": ["classic"],
			"daily_last_completed": "",
			"daily_streak": 0,
		}
	if not _data.has("current_game"):
		_data["current_game"] = {}
	if not _data.has("powerups"):
		_data["powerups"] = {
			"hammer": 3,
			"shuffle": 1,
			"bomb": 1,
			"ad_hammer": 0,
			"ad_shuffle": 0,
			"ad_bomb": 0,
			"ad_reset_date": "",
		}
	if not _data.has("ad_state"):
		_data["ad_state"] = {
			"games_since_interstitial": 0,
			"continue_used_this_game": false,
			"rewarded_undo_count_this_game": 0,
		}
