## powerup_manager.gd
## Manages power-up inventory, purchasing, and ad-based acquisition.
## Balance: ad limit is TOTAL 5/day (not per-type), costs adjusted per economy report.
extends Node

signal powerup_used(type: String)
signal powerup_count_changed(type: String, count: int)

## Balanced costs (economy report 2026-03-23)
const COSTS: Dictionary = {
	"hammer": 80,
	"shuffle": 60,
	"bomb": 110,
	"column_shift": 100,
}

## Inventory caps to prevent infinite hoarding
const MAX_INVENTORY: Dictionary = {
	"hammer": 10,
	"shuffle": 10,
	"bomb": 5,
	"column_shift": 5,
}

## Total ad watches per day (all types combined)
const AD_LIMIT_PER_DAY: int = 5

var debug_unlimited: bool = false  ## Only usable in debug builds; forced false in release
var _inventory: Dictionary = {"hammer": 0, "shuffle": 0, "bomb": 0, "column_shift": 0}
var _total_ads_today: int = 0
var _ad_reset_date: String = ""


func _ready() -> void:
	# Force debug_unlimited off in release builds
	if not OS.is_debug_build():
		debug_unlimited = false
	_load()
	AdManager.rewarded_ad_completed.connect(_on_rewarded_ad_completed)


func _load() -> void:
	var data: Dictionary = SaveManager.get_section("powerups")
	if data.is_empty():
		# First time — grant starter pack
		_inventory = {"hammer": 3, "shuffle": 2, "bomb": 1, "column_shift": 0}
		_total_ads_today = 0
		_ad_reset_date = DailySeed.get_today_string()
		_save()
		return

	_inventory["hammer"] = int(data.get("hammer", 0))
	_inventory["shuffle"] = int(data.get("shuffle", 0))
	_inventory["bomb"] = int(data.get("bomb", 0))
	_inventory["column_shift"] = int(data.get("column_shift", 0))
	_total_ads_today = int(data.get("total_ads_today", 0))
	_ad_reset_date = data.get("ad_reset_date", "")

	# Migrate old per-type ad counts to total (backward compat)
	if data.has("ad_hammer"):
		var old_total: int = int(data.get("ad_hammer", 0)) + int(data.get("ad_shuffle", 0)) + int(data.get("ad_bomb", 0))
		_total_ads_today = maxi(_total_ads_today, old_total)

	# Reset ad counter if new day
	if _ad_reset_date != DailySeed.get_today_string():
		_total_ads_today = 0
		_ad_reset_date = DailySeed.get_today_string()
		_save()


func _save() -> void:
	SaveManager.set_section("powerups", {
		"hammer": _inventory["hammer"],
		"shuffle": _inventory["shuffle"],
		"bomb": _inventory["bomb"],
		"column_shift": _inventory["column_shift"],
		"total_ads_today": _total_ads_today,
		"ad_reset_date": _ad_reset_date,
	})


func get_count(type: String) -> int:
	if debug_unlimited:
		return 99
	return _inventory.get(type, 0)


func use_powerup(type: String) -> bool:
	if debug_unlimited:
		powerup_used.emit(type)
		return true
	if _inventory.get(type, 0) <= 0:
		return false
	_inventory[type] -= 1
	_save()
	powerup_used.emit(type)
	powerup_count_changed.emit(type, _inventory[type])
	return true


func add_powerup(type: String, amount: int = 1) -> void:
	var cap: int = MAX_INVENTORY.get(type, 99)
	_inventory[type] = mini(_inventory.get(type, 0) + amount, cap)
	_save()
	powerup_count_changed.emit(type, _inventory[type])


func purchase_with_coins(type: String) -> bool:
	var cost: int = COSTS.get(type, 999)
	if not CoinManager.spend_coins(cost):
		return false
	add_powerup(type, 1)
	return true


## Ad watch limit is now TOTAL across all types
func can_watch_ad(_type: String = "") -> bool:
	if _total_ads_today >= AD_LIMIT_PER_DAY:
		return false
	# Also block if at inventory cap
	if _type != "" and _inventory.get(_type, 0) >= MAX_INVENTORY.get(_type, 99):
		return false
	return true


func request_ad_powerup(type: String) -> void:
	if not can_watch_ad(type):
		return
	set_meta("pending_ad_type", type)
	AdManager.show_rewarded_ad("powerup_" + type)


func _on_rewarded_ad_completed(ad_type: String) -> void:
	if not ad_type.begins_with("powerup_"):
		return
	var type: String = ad_type.replace("powerup_", "")
	if not _inventory.has(type):
		return
	_total_ads_today += 1
	add_powerup(type, 1)
	_save()


func get_cost(type: String) -> int:
	return COSTS.get(type, 0)


func get_ad_uses_remaining(_type: String = "") -> int:
	return AD_LIMIT_PER_DAY - _total_ads_today


func get_max_inventory(type: String) -> int:
	return MAX_INVENTORY.get(type, 99)


func is_at_cap(type: String) -> bool:
	return _inventory.get(type, 0) >= MAX_INVENTORY.get(type, 99)
