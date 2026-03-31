## ad_manager.gd
## AdMob integration via Poing Studios godot-admob-plugin.
## Dynamically loads plugin API classes at runtime.
## Falls back to stub mode on desktop or when plugin is absent.
extends Node

const _AdConfig = preload("res://scripts/autoload/ad_config.gd")

# ============================================================
# Signals (public API — consumed by game screens)
# ============================================================

signal rewarded_ad_completed(type: String)
signal interstitial_ad_closed
signal banner_visibility_changed(visible: bool)
signal rewarded_ad_failed


# ============================================================
# Dynamically loaded Poing plugin scripts
# ============================================================

var _S_MobileAds: Variant = null
var _S_AdView: Variant = null
var _S_AdSize: Variant = null
var _S_AdPosition: Variant = null
var _S_AdRequest: Variant = null
var _S_AdListener: Variant = null
var _S_InterstitialAdLoader: Variant = null
var _S_InterstitialAdLoadCallback: Variant = null
var _S_RewardedAdLoader: Variant = null
var _S_RewardedAdLoadCallback: Variant = null
var _S_FullScreenContentCallback: Variant = null
var _S_OnUserEarnedRewardListener: Variant = null

# UMP (consent)
var _S_UserMessagingPlatform: Variant = null
var _S_ConsentRequestParameters: Variant = null
var _S_RequestConfiguration: Variant = null


# ============================================================
# State
# ============================================================

var _ads_removed: bool = false
var _plugin_available: bool = false
var _initialized: bool = false

## Banner
var _ad_view: Variant = null
var _banner_visible: bool = false

## Interstitial
var _interstitial_ad: Variant = null
var _interstitial_loaded: bool = false
var _last_interstitial_time: float = -999.0

## Rewarded
var _rewarded_ad: Variant = null
var _rewarded_loaded: bool = false
var _rewarded_loading: bool = false
var _pending_reward_type: String = ""


# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	_ads_removed = bool(SaveManager.get_value("settings", "ads_removed", false))
	_try_load_plugin_classes()

	if _plugin_available:
		print("[AdManager] Poing AdMob plugin detected — initializing.")
		_initialize_sdk()
	else:
		print("[AdManager] Plugin not available — stub mode.")


# ============================================================
# Plugin Loading (Poing Studios pattern)
# ============================================================

func _try_load_plugin_classes() -> void:
	var base: String = "res://addons/admob/src/"
	var paths: Dictionary = {
		"MobileAds":                  base + "api/MobileAds.gd",
		"AdView":                     base + "api/AdView.gd",
		"AdSize":                     base + "api/core/AdSize.gd",
		"AdPosition":                 base + "api/core/AdPosition.gd",
		"AdRequest":                  base + "api/core/AdRequest.gd",
		"AdListener":                 base + "api/listeners/AdListener.gd",
		"InterstitialAdLoader":       base + "api/InterstitialAdLoader.gd",
		"InterstitialAdLoadCallback": base + "api/listeners/InterstitialAdLoadCallback.gd",
		"RewardedAdLoader":           base + "api/RewardedAdLoader.gd",
		"RewardedAdLoadCallback":     base + "api/listeners/RewardedAdLoadCallback.gd",
		"FullScreenContentCallback":  base + "api/listeners/FullScreenContentCallback.gd",
		"OnUserEarnedRewardListener": base + "api/listeners/OnUserEarnedRewardListener.gd",
	}

	# Check native backend first — no point loading scripts if not on device
	if not Engine.has_singleton("PoingGodotAdMob"):
		_plugin_available = false
		return

	# Check all required scripts exist
	for key: String in paths:
		if not ResourceLoader.exists(paths[key]):
			_plugin_available = false
			return

	# Load all scripts
	var scripts: Dictionary = {}
	for key: String in paths:
		var res: Variant = load(paths[key])
		if res == null:
			_plugin_available = false
			return
		scripts[key] = res

	_S_MobileAds                  = scripts["MobileAds"]
	_S_AdView                     = scripts["AdView"]
	_S_AdSize                     = scripts["AdSize"]
	_S_AdPosition                 = scripts["AdPosition"]
	_S_AdRequest                  = scripts["AdRequest"]
	_S_AdListener                 = scripts["AdListener"]
	_S_InterstitialAdLoader       = scripts["InterstitialAdLoader"]
	_S_InterstitialAdLoadCallback = scripts["InterstitialAdLoadCallback"]
	_S_RewardedAdLoader           = scripts["RewardedAdLoader"]
	_S_RewardedAdLoadCallback     = scripts["RewardedAdLoadCallback"]
	_S_FullScreenContentCallback  = scripts["FullScreenContentCallback"]
	_S_OnUserEarnedRewardListener = scripts["OnUserEarnedRewardListener"]

	# UMP scripts (optional)
	var ump_paths: Dictionary = {
		"UserMessagingPlatform":  base + "ump/api/UserMessagingPlatform.gd",
		"ConsentRequestParameters": base + "ump/core/ConsentRequestParameters.gd",
		"RequestConfiguration":  base + "api/core/RequestConfiguration.gd",
	}
	for key: String in ump_paths:
		if ResourceLoader.exists(ump_paths[key]):
			var res: Variant = load(ump_paths[key])
			if key == "UserMessagingPlatform":
				_S_UserMessagingPlatform = res
			elif key == "ConsentRequestParameters":
				_S_ConsentRequestParameters = res
			elif key == "RequestConfiguration":
				_S_RequestConfiguration = res

	_plugin_available = true


# ============================================================
# SDK Initialization
# ============================================================

func _initialize_sdk() -> void:
	if not _plugin_available or _initialized:
		return

	# Apply content rating settings
	if _S_RequestConfiguration != null:
		var config: Variant = _S_RequestConfiguration.new()
		config.max_ad_content_rating = _AdConfig.MAX_AD_CONTENT_RATING
		if not _AdConfig.TAG_FOR_CHILD_DIRECTED:
			config.tag_for_child_directed_treatment = 0
		if not _AdConfig.TAG_FOR_UNDER_AGE_OF_CONSENT:
			config.tag_for_under_age_of_consent = 0
		_S_MobileAds.set_request_configuration(config)

	_S_MobileAds.initialize()
	_initialized = true
	print("[AdManager] MobileAds.initialize() called.")

	# Preload ads after short delay
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		_preload_interstitial()
		_preload_rewarded()
	)


# ============================================================
# Banner Ads
# ============================================================

func show_banner() -> void:
	if _ads_removed:
		return
	if not _plugin_available:
		_banner_visible = true
		banner_visibility_changed.emit(true)
		return
	if not _initialized:
		return
	if _ad_view != null and _banner_visible:
		return
	if _ad_view != null:
		_ad_view.destroy()
		_ad_view = null

	var unit_id: String = _AdConfig.get_unit_id(&"banner")
	var ad_size: Variant = _S_AdSize.BANNER
	var ad_pos: int = _S_AdPosition.Values.BOTTOM
	_ad_view = _S_AdView.new(unit_id, ad_size, ad_pos)

	var listener: Variant = _S_AdListener.new()
	listener.on_ad_loaded = func() -> void:
		_banner_visible = true
		banner_visibility_changed.emit(true)
	listener.on_ad_failed_to_load = func(_error: Variant) -> void:
		_banner_visible = false
		banner_visibility_changed.emit(false)
	_ad_view.ad_listener = listener
	_ad_view.load_ad(_S_AdRequest.new())


func hide_banner() -> void:
	if not _plugin_available:
		if _banner_visible:
			_banner_visible = false
			banner_visibility_changed.emit(false)
		return
	if _ad_view != null:
		_ad_view.destroy()
		_ad_view = null
	_banner_visible = false
	banner_visibility_changed.emit(false)


func is_banner_visible() -> bool:
	return _banner_visible


# ============================================================
# Interstitial Ads
# ============================================================

func try_show_interstitial() -> bool:
	if _ads_removed:
		return false

	var now: float = Time.get_ticks_msec() / 1000.0
	if (now - _last_interstitial_time) < _AdConfig.INTERSTITIAL_COOLDOWN:
		return false

	if not _plugin_available:
		_last_interstitial_time = now
		call_deferred("emit_signal", "interstitial_ad_closed")
		return true

	if not _initialized or _interstitial_ad == null:
		return false

	var callback: Variant = _S_FullScreenContentCallback.new()
	callback.on_ad_dismissed_full_screen_content = func() -> void:
		_interstitial_ad = null
		_interstitial_loaded = false
		_last_interstitial_time = Time.get_ticks_msec() / 1000.0
		interstitial_ad_closed.emit()
		_preload_interstitial()
	callback.on_ad_failed_to_show_full_screen_content = func(_error: Variant) -> void:
		_interstitial_ad = null
		_interstitial_loaded = false
		interstitial_ad_closed.emit()
		_preload_interstitial()

	_interstitial_ad.full_screen_content_callback = callback
	_interstitial_ad.show()
	return true


func _preload_interstitial() -> void:
	if not _plugin_available or not _initialized:
		return
	if _interstitial_loaded or _interstitial_ad != null:
		return

	var unit_id: String = _AdConfig.get_unit_id(&"interstitial")
	var load_cb: Variant = _S_InterstitialAdLoadCallback.new()
	load_cb.on_ad_loaded = func(ad: Variant) -> void:
		_interstitial_ad = ad
		_interstitial_loaded = true
	load_cb.on_ad_failed_to_load = func(_error: Variant) -> void:
		_interstitial_loaded = false
		get_tree().create_timer(_AdConfig.AD_RELOAD_DELAY).timeout.connect(
			_preload_interstitial, CONNECT_ONE_SHOT
		)
	_S_InterstitialAdLoader.new().load(unit_id, _S_AdRequest.new(), load_cb)


# ============================================================
# Rewarded Ads
# ============================================================

func show_rewarded_ad(type: String = "") -> void:
	_pending_reward_type = type

	if not _plugin_available:
		# Stub: grant reward after 1s delay (simulates watching an ad)
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			rewarded_ad_completed.emit(type)
		)
		return

	if not _initialized or _rewarded_ad == null:
		rewarded_ad_failed.emit()
		_preload_rewarded()
		return

	var callback: Variant = _S_FullScreenContentCallback.new()
	callback.on_ad_dismissed_full_screen_content = func() -> void:
		_rewarded_ad = null
		_rewarded_loaded = false
		_preload_rewarded()
	callback.on_ad_failed_to_show_full_screen_content = func(_error: Variant) -> void:
		_rewarded_ad = null
		_rewarded_loaded = false
		rewarded_ad_failed.emit()
		_preload_rewarded()

	_rewarded_ad.full_screen_content_callback = callback

	var reward_listener: Variant = _S_OnUserEarnedRewardListener.new()
	reward_listener.on_user_earned_reward = func(_reward_item: Variant) -> void:
		rewarded_ad_completed.emit(_pending_reward_type)

	_rewarded_ad.show(reward_listener)


func is_rewarded_ready() -> bool:
	if not _plugin_available:
		return true
	return _rewarded_ad != null


func _preload_rewarded() -> void:
	if not _plugin_available or not _initialized:
		return
	if _rewarded_loaded or _rewarded_ad != null or _rewarded_loading:
		return

	_rewarded_loading = true
	var unit_id: String = _AdConfig.get_unit_id(&"rewarded")
	var load_cb: Variant = _S_RewardedAdLoadCallback.new()
	load_cb.on_ad_loaded = func(ad: Variant) -> void:
		_rewarded_ad = ad
		_rewarded_loaded = true
		_rewarded_loading = false
	load_cb.on_ad_failed_to_load = func(_error: Variant) -> void:
		_rewarded_loaded = false
		_rewarded_loading = false
		get_tree().create_timer(_AdConfig.AD_RELOAD_DELAY).timeout.connect(
			_preload_rewarded, CONNECT_ONE_SHOT
		)
	_S_RewardedAdLoader.new().load(unit_id, _S_AdRequest.new(), load_cb)


# ============================================================
# Ad Removal
# ============================================================

func remove_ads() -> void:
	_ads_removed = true
	SaveManager.set_value("settings", "ads_removed", true)
	hide_banner()
	if _interstitial_ad != null and _plugin_available:
		_interstitial_ad = null
		_interstitial_loaded = false


func are_ads_removed() -> bool:
	return _ads_removed


func is_plugin_available() -> bool:
	return _plugin_available
