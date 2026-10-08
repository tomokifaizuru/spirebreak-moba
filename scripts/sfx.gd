extends Node
## Autoload "Sfx": tiny pooled sound player on the "SFX" bus. Sounds live in audio/sfx/.
## Also owns the looping background music player on the "Music" bus (play_music / stop_music).

const SOUNDS := {
	"shoot": "res://audio/sfx/shoot.wav",
	"hit": "res://audio/sfx/hit.wav",
	"cast": "res://audio/sfx/cast.wav",
	"boom": "res://audio/sfx/boom.wav",
	"snare": "res://audio/sfx/snare.wav",
	"tower": "res://audio/sfx/tower.wav",
	"coin": "res://audio/sfx/coin.wav",
	"levelup": "res://audio/sfx/levelup.wav",
	"death": "res://audio/sfx/death.wav",
	"heal": "res://audio/sfx/heal.wav",
	"click": "res://audio/sfx/click.wav",
	"victory": "res://audio/sfx/victory.wav",
	"defeat": "res://audio/sfx/defeat.wav",
}

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next := 0
var last_play := {}
var enabled := true
var music: AudioStreamPlayer
var music_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		return
	for k in SOUNDS:
		if ResourceLoader.exists(SOUNDS[k]):
			streams[k] = load(SOUNDS[k])
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.bus = &"Music"
	music.name = "Music"
	add_child(music)


## Starts looping `path` on the Music bus. Does nothing (silently) if the file is not there yet,
## so the game works before the track exists. Calling it again with the same track keeps playing.
func play_music(path: String, vol_db := -4.0) -> void:
	if not enabled or music == null or path == "":
		return
	if music_path == path and music.playing:
		return
	if not ResourceLoader.exists(path):
		return
	var st = load(path)
	if not (st is AudioStream):
		return
	if "loop" in st:
		st.loop = true
	music_path = path
	music.stream = st
	music.volume_db = vol_db
	music.play()


func stop_music() -> void:
	if music != null:
		music.stop()
	music_path = ""


func play(sound: String, vol_db := 0.0, pitch_var := 0.08) -> void:
	if not enabled or not streams.has(sound):
		return
	var t := Time.get_ticks_msec()
	if t - int(last_play.get(sound, -1000)) < 45:
		return
	last_play[sound] = t
	var p := players[next]
	next = (next + 1) % players.size()
	p.stream = streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
