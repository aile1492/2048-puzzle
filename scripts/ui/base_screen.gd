## base_screen.gd
## Abstract base class for all screen scripts.
## ScreenManager uses this interface to manage the screen lifecycle.
class_name BaseScreen
extends Control


## Called when the screen becomes active.
## data: parameter dictionary passed from the previous screen.
@warning_ignore("unused_parameter")
func enter(data: Dictionary = {}) -> void:
	pass


## Called when the screen becomes inactive.
func exit() -> void:
	pass
