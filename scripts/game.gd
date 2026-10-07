extends Node
## Autoload "Game": title/version, saved settings, scene changes, debug flags.
## The game title comes from Project Settings > Application > Config > Name ("Spirebreak"),
## so renaming the game only needs that one setting.

const SETTINGS_PATH := "user://settings.cfg"
const TITLE_SCENE := "res://scenes/title.tscn"
const MATCH_SCENE := "res://scenes/match.tscn"

var title := "Spirebreak"
var version := "0.1"
var sfx_volume := 0.8
## Debug flags from the command line (-- autopilot speed=4) or the web URL (#autopilot&speed=4).
var debug_args := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = str(ProjectSettings.get_setting("application/config/name", "Spirebreak"))
	version = str(ProjectSettings.get_setting("application/config/version", "0.1"))
	_read_debug_args()
	_load_settings()
	_apply_volume()


func _read_debug_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		debug_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if OS.has_feature("web"):
		var h = JavaScriptBridge.eval("window.location.hash", true)
		if typeof(h) == TYPE_STRING and (h as String).length() > 1:
			for part in (h as String).substr(1).split("&"):
				var kv2 := part.split("=", true, 1)
				debug_args[kv2[0]] = kv2[1] if kv2.size() > 1 else "1"


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS_PATH)


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	_save_settings()


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("SFX")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(sfx_volume, 0.0001)))
		AudioServer.set_bus_mute(bus, sfx_volume <= 0.001)


func goto_title() -> void:
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", TITLE_SCENE)


func goto_match() -> void:
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", MATCH_SCENE)
