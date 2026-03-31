## theme_manager.gd
## Manages current theme and provides color access.
## Full implementation in Phase 4.
extends Node

signal theme_changed(theme_id: String)

var current_theme: String = "light"


func _ready() -> void:
	current_theme = SaveManager.get_value("settings", "theme", "light")


func set_theme(theme_id: String) -> void:
	current_theme = theme_id
	SaveManager.set_value("settings", "theme", theme_id)
	theme_changed.emit(theme_id)


func is_dark() -> bool:
	return current_theme != "light"
