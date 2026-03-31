## haptics.gd
## Haptic feedback utility. Uses Input.vibrate_handheld on mobile.
class_name Haptics


static func _is_enabled() -> bool:
	return bool(SaveManager.get_value("settings", "vibration", true))


static func light() -> void:
	if not _is_enabled():
		return
	Input.vibrate_handheld(20)


static func medium() -> void:
	if not _is_enabled():
		return
	Input.vibrate_handheld(40)


static func heavy() -> void:
	if not _is_enabled():
		return
	Input.vibrate_handheld(80)


static func success() -> void:
	if not _is_enabled():
		return
	Input.vibrate_handheld(150)
