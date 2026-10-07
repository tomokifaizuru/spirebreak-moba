extends SceneTree
## Screenshot helper (needs a display, e.g. xvfb-run):
##   godot --path . --resolution 1600x740 -s tools/shots.gd -- shot=teamfight out=/tmp/a.png
## shot = title | teamfight | hud | victory
var opts := {"shot": "title", "out": "/tmp/shot.png", "seed": "3", "tries": "5"}
var arena: Arena
var frames := 0
var phase := 0
var wait := 0
var tries := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	seed(int(opts["seed"]))


func _start_match() -> void:
	if arena != null:
		arena.queue_free()
	tries += 1
	seed(int(opts["seed"]) + tries * 17)
	arena = load("res://scenes/match.tscn").instantiate()
	root.add_child(arena)
	arena.player.autopilot = true
	arena.sim_substeps = 10
	var h = arena.get_node_or_null("HUD")
	if h != null and h.canvas != null:
		h.canvas.show_autopilot_label = false


func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		if opts["shot"] == "title":
			change_scene_to_file("res://scenes/title.tscn")
			wait = 40
			phase = 9
		else:
			_start_match()
			phase = 1
		return false
	if phase == 9:
		wait -= 1
		if wait <= 0:
			_capture()
		return false
	if arena == null or phase == 0:
		return false
	var p := arena.player
	match opts["shot"]:
		"teamfight":
			if phase == 1 and arena.time > 140.0 and p.alive and p.hp_frac() > 0.5:
				var ens := arena.heroes_near(p.position, 520.0, p.team, true)
				var al := arena.heroes_near(p.position, 520.0, p.team, false).size()
				var healthy := 0
				for e in ens:
					if e.hp_frac() > 0.45:
						healthy += 1
				if ens.size() >= 2 and healthy >= 2 and al >= 2 and p.brain.state == "fight":
					arena.sim_substeps = 1
					phase = 2
					wait = 8
		"hud":
			if phase == 1 and arena.time > 60.0 and p.alive:
				for s in arena.structures:
					if s.alive and s.team != p.team and not s.invulnerable and s.hp_frac() < 0.9 \
							and p.position.distance_to(s.position) < 520.0 and arena.count_creeps_near(s.position, 500.0, p.team) >= 2:
						arena.sim_substeps = 1
						phase = 2
						wait = 30
						break
		"victory":
			if phase == 1:
				arena.sim_substeps = 30
				if arena.over:
					if arena.winner == p.team or tries >= int(opts["tries"]):
						phase = 2
						wait = 200
					else:
						print("Dusk won, retrying")
						_start_match()
	if phase == 2:
		wait -= 1
		if wait <= 0:
			_capture()
	return false


func _capture() -> void:
	phase = 3
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(opts["out"])
	print("saved ", opts["out"], " ", img.get_size(), " t=", (arena.time if arena != null else 0.0))
	quit()
