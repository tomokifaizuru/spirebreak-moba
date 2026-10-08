extends Node
## Autoload "Game": title/version, saved settings, scene changes, debug flags.
## The game title comes from Project Settings > Application > Config > Name ("Spirebreak"),
## so renaming the game only needs that one setting.

const SETTINGS_PATH := "user://settings.cfg"
const TITLE_SCENE := "res://scenes/title.tscn"
const MATCH_SCENE := "res://scenes/match.tscn"
const SELECT_SCENE := "res://scenes/hero_select.tscn"
const CONFIG_PATH := "res://data/match_config.tres"

var title := "Spirebreak"
var version := "0.4"
var sfx_volume := 1.0
## Fresh installs start the music at 25% (slider position); a saved setting always wins.
var music_volume := 0.25
## Debug flags from the command line (-- autopilot speed=4) or the web URL (#autopilot&speed=4).
var debug_args := {}
## The hero picked on the hero select screen (null until you pick one).
var selected_hero: HeroData = null
## Teams for the next match, built by start_match(). Empty = use match_config.tres defaults.
var next_lineup := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = str(ProjectSettings.get_setting("application/config/name", "Spirebreak"))
	version = str(ProjectSettings.get_setting("application/config/version", "0.4"))
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
		music_volume = float(cfg.get_value("audio", "music", music_volume))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.save(SETTINGS_PATH)


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	_save_settings()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	_save_settings()


func _apply_volume() -> void:
	for pair in [["SFX", sfx_volume], ["Music", music_volume]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus < 0:
			# the bus layout is missing (e.g. edited away): create the bus so volume still works
			AudioServer.add_bus()
			bus = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus, pair[0])
			AudioServer.set_bus_send(bus, &"Master")
		var v: float = pair[1]
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(bus, v <= 0.001)


func goto_title() -> void:
	get_tree().paused = false
	_stop_music()
	get_tree().call_deferred("change_scene_to_file", TITLE_SCENE)


func goto_hero_select() -> void:
	get_tree().paused = false
	_stop_music()
	get_tree().call_deferred("change_scene_to_file", SELECT_SCENE)


func _stop_music() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.stop_music()


func roster() -> Array:
	var cfg: MatchConfig = load(CONFIG_PATH)
	return cfg.roster


## Builds fresh random bot teams around `hero` and loads the match.
func start_match(hero: HeroData) -> void:
	selected_hero = hero
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	next_lineup = Lineup.build(hero, roster(), rng)
	goto_match()


## Play Again: same hero, new bot teams.
func restart_match() -> void:
	if selected_hero != null:
		start_match(selected_hero)
	else:
		goto_match()


func goto_match() -> void:
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", MATCH_SCENE)
