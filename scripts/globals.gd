extends Node
## Global game state shared across scenes.

var hero: String = "emmy"   # "emmy" or "isla"

# currency + store upgrades (session-persistent; save file later)
# GOLD (Emmy's decision): earned by defeating enemies + finding chests
var gold: int = 0
var presents: int = 0
var atk_bonus: int = 0      # added to attack-card power
var heal_bonus: int = 0     # added to heal-card power
var sword_level: int = 1

# audio settings (0-10, persisted). Music/SFX buses are created here at runtime
# so the default bus layout stays untouched; players opt in via .bus = "Music"/"SFX".
const SETTINGS_PATH := "user://settings.cfg"
var music_volume: int = 8
var sfx_volume: int = 8
var _sfx_cache: Dictionary = {}


## Fire-and-forget one-shot on the SFX bus (delivered files: sfx_<name>.ogg).
func play_sfx(sfx: String) -> void:
	var path := "res://assets/audio/sfx_%s.ogg" % sfx
	if not _sfx_cache.has(path):
		if not ResourceLoader.exists(path):
			return
		_sfx_cache[path] = load(path)
	var p := AudioStreamPlayer.new()
	p.stream = _sfx_cache[path]
	p.bus = "SFX"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _ready() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	_load_settings()
	_apply_volumes()


func set_music_volume(v: int) -> void:
	music_volume = clampi(v, 0, 10)
	_apply_volumes()
	_save_settings()


func set_sfx_volume(v: int) -> void:
	sfx_volume = clampi(v, 0, 10)
	_apply_volumes()
	_save_settings()


func _apply_volumes() -> void:
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


func _set_bus(bus_name: String, v: int) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, v == 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v / 10.0, 0.001)))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_volume = clampi(int(cfg.get_value("audio", "music", music_volume)), 0, 10)
		sfx_volume = clampi(int(cfg.get_value("audio", "sfx", sfx_volume)), 0, 10)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS_PATH)
