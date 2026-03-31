## screen_manager.gd
## 3-layer navigation system: TabLayer (home), PushLayer (screens), PopupLayer (popups).
## Adapted from Word Bloom ScreenManager (simplified: no bottom tab bar).
extends Node

var _tab_layer: CanvasLayer
var _push_layer: CanvasLayer
var _popup_layer: CanvasLayer

var _push_stack: Array[BaseScreen] = []
var _popup_stack: Array[BaseScreen] = []
var _home_screen: BaseScreen


func initialize(tab_layer: CanvasLayer, push_layer: CanvasLayer, popup_layer: CanvasLayer) -> void:
	_tab_layer = tab_layer
	_push_layer = push_layer
	_popup_layer = popup_layer

	# Find the home screen in TabLayer
	for child in _tab_layer.get_children():
		if child is BaseScreen:
			_home_screen = child
			break

	if _home_screen:
		_home_screen.visible = true
		_home_screen.enter()


func push_screen(scene_path: String, data: Dictionary = {}) -> void:
	# Hide home screen when push stack has content
	if _home_screen and _push_stack.is_empty():
		_home_screen.exit()
		_home_screen.visible = false

	# Hide current push screen
	if not _push_stack.is_empty():
		_push_stack.back().exit()
		_push_stack.back().visible = false

	var scene := load(scene_path) as PackedScene
	if not scene:
		push_error("ScreenManager: Failed to load scene: " + scene_path)
		return
	var screen := scene.instantiate() as BaseScreen
	_push_layer.add_child(screen)
	_push_stack.append(screen)
	screen.enter(data)
	# Fade in
	screen.modulate.a = 0.0
	var tween := screen.create_tween()
	tween.tween_property(screen, "modulate:a", 1.0, 0.2)


func pop_screen() -> void:
	if _push_stack.is_empty():
		return

	var screen := _push_stack.pop_back() as BaseScreen
	screen.exit()
	screen.queue_free()

	if not _push_stack.is_empty():
		_push_stack.back().visible = true
		_push_stack.back().enter()
	elif _home_screen:
		_home_screen.visible = true
		_home_screen.enter()


func replace_screen(scene_path: String, data: Dictionary = {}) -> void:
	if not _push_stack.is_empty():
		var screen := _push_stack.pop_back() as BaseScreen
		screen.exit()
		screen.queue_free()
	push_screen(scene_path, data)


func clear_push_stack() -> void:
	while not _push_stack.is_empty():
		var screen := _push_stack.pop_back() as BaseScreen
		screen.exit()
		screen.queue_free()

	if _home_screen:
		_home_screen.visible = true
		_home_screen.enter()


func show_popup(scene_path: String, data: Dictionary = {}) -> BaseScreen:
	var scene := load(scene_path) as PackedScene
	if not scene:
		push_error("ScreenManager: Failed to load popup: " + scene_path)
		return null
	var popup := scene.instantiate() as BaseScreen
	_popup_layer.add_child(popup)
	_popup_stack.append(popup)
	popup.enter(data)
	return popup


func close_popup(popup: BaseScreen = null) -> void:
	if _popup_stack.is_empty():
		return

	if popup == null:
		popup = _popup_stack.pop_back()
	else:
		if not _popup_stack.has(popup):
			return  # Already closed — prevent double-close crash (#6)
		_popup_stack.erase(popup)

	if not is_instance_valid(popup):
		return  # Already freed — prevent crash on rapid double-click
	popup.exit()
	popup.queue_free()


func close_all_popups() -> void:
	while not _popup_stack.is_empty():
		var popup := _popup_stack.pop_back() as BaseScreen
		popup.exit()
		popup.queue_free()


func has_push_screens() -> bool:
	return not _push_stack.is_empty()


func has_popups() -> bool:
	return not _popup_stack.is_empty()
