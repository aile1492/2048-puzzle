## audio_manager.gd
## Manages SFX and BGM playback.
extends Node

const SFX_BASE: String = "res://assets/audio/sfx/"
const BGM_BASE: String = "res://assets/audio/bgm/"
const SFX_POOL_SIZE: int = 8

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _bgm_player: AudioStreamPlayer
var _sound_enabled: bool = true
var _volume: int = 100  ## 0-100
var _bgm_volume_ratio: float = 0.4  ## BGM is quieter than SFX


func _ready() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

	# BGM player
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	add_child(_bgm_player)

	# Load saved volume
	_volume = int(SaveManager.get_value("settings", "sound_volume", 100))
	_sound_enabled = _volume > 0
	_apply_volume()


func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	if not _sound_enabled or _volume <= 0:
		return
	var path := SFX_BASE + sfx_name + ".wav"
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream:
		var player := _sfx_players[_sfx_index]
		player.stream = stream
		player.pitch_scale = pitch
		player.play()
		_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE


func set_volume(value: int) -> void:
	_volume = clampi(value, 0, 100)
	_sound_enabled = _volume > 0
	_apply_volume()
	SaveManager.set_value("settings", "sound_volume", _volume)


func get_volume() -> int:
	return _volume


func set_sound_enabled(enabled: bool) -> void:
	_sound_enabled = enabled


func is_sound_enabled() -> bool:
	return _sound_enabled


func _apply_volume() -> void:
	var db: float = linear_to_db(_volume / 100.0) if _volume > 0 else -80.0
	var bus_idx: int = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
	# BGM volume (quieter than SFX)
	if _bgm_player:
		var bgm_db: float = linear_to_db(_volume / 100.0 * _bgm_volume_ratio) if _volume > 0 else -80.0
		_bgm_player.volume_db = bgm_db


func play_bgm(bgm_name: String) -> void:
	if not _sound_enabled:
		return
	var path := BGM_BASE + bgm_name + ".wav"
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream:
		_bgm_player.stream = stream
		_bgm_player.volume_db = linear_to_db(_volume / 100.0 * _bgm_volume_ratio) if _volume > 0 else -80.0
		_bgm_player.play()


func stop_bgm() -> void:
	if _bgm_player:
		_bgm_player.stop()


func is_bgm_playing() -> bool:
	return _bgm_player and _bgm_player.playing
