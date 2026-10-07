extends Node
## Autoload "Sfx": tiny pooled sound player on the "SFX" bus. Sounds live in audio/sfx/.

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
