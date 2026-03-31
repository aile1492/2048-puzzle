## main_scene.gd
## Root scene script. Initializes ScreenManager with 3-layer navigation.
extends Node

@onready var tab_layer: CanvasLayer = $TabLayer
@onready var push_layer: CanvasLayer = $PushLayer
@onready var popup_layer: CanvasLayer = $PopupLayer


func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	ScreenManager.initialize(tab_layer, push_layer, popup_layer)

	# Show splash screen which routes to saved game or stays on home
	call_deferred("_show_splash")


func _show_splash() -> void:
	ScreenManager.push_screen("res://scenes/screens/splash_screen.tscn")
