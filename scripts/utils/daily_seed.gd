## daily_seed.gd
## Generates date-based seeds for Daily Challenge mode.
class_name DailySeed


static func get_today_seed() -> int:
	var date: Dictionary = Time.get_date_dict_from_system()
	return date["year"] * 10000 + date["month"] * 100 + date["day"]


static func get_today_string() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]


static func get_daily_target_score() -> int:
	## Target score varies by day of week.
	## Godot weekday: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
	## Mon=easiest (~256 tile), Sat=hardest (~512 tile), Sun=medium
	var date: Dictionary = Time.get_date_dict_from_system()
	var weekday: int = date.get("weekday", 0)
	var base_targets: Array = [10000, 5000, 6000, 7000, 8000, 10000, 15000]
	if weekday < base_targets.size():
		return base_targets[weekday]
	return 8000


static func is_same_day(date_string: String) -> bool:
	return date_string == get_today_string()
