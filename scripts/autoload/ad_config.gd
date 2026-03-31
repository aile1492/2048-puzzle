## ad_config.gd
## Pure-data class holding all ad-related constants and unit IDs.
## NOT an autoload — imported by AdManager via class_name.
class_name AdConfig


# ============================================================
# Policy thresholds
# ============================================================

## Interstitial shows after N game overs in a session.
const INTERSTITIAL_AFTER_GAME_OVERS: int = 3

## Minimum seconds between two interstitials.
const INTERSTITIAL_COOLDOWN: float = 90.0

## Seconds to wait before retrying a failed ad load.
const AD_RELOAD_DELAY: float = 30.0

## Banner start level (not used in 2048 — always show)
const BANNER_START_LEVEL: int = 0

## Ad-free levels (not used in 2048)
const AD_FREE_LEVELS: int = 0

## Interstitial interval (for compatibility — not used in 2048)
const INTERSTITIAL_INTERVAL: int = 3


# ============================================================
# Ad Unit IDs — Test (Google official sample IDs)
# ============================================================

const TEST_BANNER_ANDROID: String      = "ca-app-pub-3940256099942544/6300978111"
const TEST_BANNER_IOS: String          = "ca-app-pub-3940256099942544/2435281174"
const TEST_INTERSTITIAL_ANDROID: String = "ca-app-pub-3940256099942544/1033173712"
const TEST_INTERSTITIAL_IOS: String    = "ca-app-pub-3940256099942544/4411468910"
const TEST_REWARDED_ANDROID: String    = "ca-app-pub-3940256099942544/5224354917"
const TEST_REWARDED_IOS: String        = "ca-app-pub-3940256099942544/1712485313"


# ============================================================
# Ad Unit IDs — Production (replace before release)
# ============================================================

## *** AdMob Console → Apps → 2048 Puzzle (com.puzzle2048.game) ***
## 1. admob.google.com → Add App → Android → com.puzzle2048.game
## 2. Create ad units: Banner, Interstitial, Rewarded
## 3. Paste IDs below and set USE_TEST_ADS = false
const PROD_BANNER_ANDROID: String      = ""  ## admob.google.com → Ad units → Banner
const PROD_BANNER_IOS: String          = ""
const PROD_INTERSTITIAL_ANDROID: String = ""  ## admob.google.com → Ad units → Interstitial
const PROD_INTERSTITIAL_IOS: String    = ""
const PROD_REWARDED_ANDROID: String    = ""  ## admob.google.com → Ad units → Rewarded
const PROD_REWARDED_IOS: String        = ""


# ============================================================
# Toggle
# ============================================================

## Set to false before release to use production IDs.
const USE_TEST_ADS: bool = true


# ============================================================
# Ad Content Rating / Compliance
# ============================================================

const MAX_AD_CONTENT_RATING: String = "G"
const TAG_FOR_CHILD_DIRECTED: bool = false
const TAG_FOR_UNDER_AGE_OF_CONSENT: bool = false

## Privacy Policy URL (update before release)
const PRIVACY_POLICY_URL: String = "https://aile1492.github.io/word-bloom-policy/2048.html#privacy"
const TERMS_OF_SERVICE_URL: String = "https://aile1492.github.io/word-bloom-policy/2048.html#terms"


# ============================================================
# Helper
# ============================================================

static func get_unit_id(ad_type: StringName) -> String:
	var is_ios: bool = OS.get_name() == "iOS"

	if USE_TEST_ADS:
		match ad_type:
			&"banner":
				return TEST_BANNER_IOS if is_ios else TEST_BANNER_ANDROID
			&"interstitial":
				return TEST_INTERSTITIAL_IOS if is_ios else TEST_INTERSTITIAL_ANDROID
			&"rewarded":
				return TEST_REWARDED_IOS if is_ios else TEST_REWARDED_ANDROID
	else:
		match ad_type:
			&"banner":
				return PROD_BANNER_IOS if is_ios else PROD_BANNER_ANDROID
			&"interstitial":
				return PROD_INTERSTITIAL_IOS if is_ios else PROD_INTERSTITIAL_ANDROID
			&"rewarded":
				return PROD_REWARDED_IOS if is_ios else PROD_REWARDED_ANDROID

	push_error("AdConfig: Unknown ad_type '%s'" % ad_type)
	return ""
