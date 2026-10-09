extends SceneTree
## Renders the app-icon layers from the in-game 3D models (needs a display, e.g. xvfb-run):
##   godot --path . -s tools/make_icons.gd -- out=icon-drafts/layers
## Writes transparent PNGs: <variant>_heroes.png (1024) and spire_<team>.png; tools/compose_icons.py
## turns them into the final icons, adaptive layers and the comparison sheet.

var opts := {"out": "icon-drafts/layers", "size": "1024"}
var jobs: Array = []
var frame := 0
var cur: Dictionary = {}
var vp: SubViewport


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + opts["out"]))
	var px := int(opts["size"])
	# Each job: heroes = [[id, team, pos, yaw, pose]], camera pos + target + fov.
	jobs = [
		{"name": "A_heroes", "px": px, "heroes": [
			["morrow", 0, Vector3(-0.5, 0, -0.4), 28.0, "idle"],
			["sable", 0, Vector3(0.52, 0, -0.38), -30.0, "cast"],
			["kestrel", 0, Vector3(0.0, 0, 0.18), -8.0, "attack"]],
			"cam": Vector3(0, 0.6, 3.0), "look": Vector3(0, 0.47, -0.1), "fov": 33.0},
		{"name": "B_heroes", "px": px, "heroes": [
			["kestrel", 0, Vector3(0, 0, 0), -22.0, "attack"]],
			"cam": Vector3(0.05, 0.84, 1.72), "look": Vector3(0, 0.6, 0), "fov": 34.0},
		{"name": "C_heroes", "px": px, "heroes": [
			["sable", 1, Vector3(0.36, 0, 0), -55.0, "cast"],
			["morrow", 0, Vector3(-0.38, 0, 0.05), 52.0, "attack"]],
			"cam": Vector3(0, 0.56, 2.95), "look": Vector3(0, 0.45, 0), "fov": 33.0},
		{"name": "spire_0", "px": px, "spire": 0, "cam": Vector3(0, 1.8, 8.6), "look": Vector3(0, 1.65, 0), "fov": 34.0},
		{"name": "spire_1", "px": px, "spire": 1, "cam": Vector3(0, 1.8, 8.6), "look": Vector3(0, 1.65, 0), "fov": 34.0},
	]


func _hero(id: String) -> HeroData:
	var cfg: MatchConfig = load("res://data/match_config.tres")
	for h in cfg.roster:
		if String(h.id) == id:
			return h
	return null


func _setup(job: Dictionary) -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(job["px"], job["px"])
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var r := Node3D.new()
	vp.add_child(r)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("dfe6ff")
	e.ambient_light_energy = 0.75
	env.environment = e
	r.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_energy = 1.05
	r.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 160, 0)
	rim.light_energy = 0.45
	rim.light_color = Color("ffd9a8")
	r.add_child(rim)
	if job.has("heroes"):
		for hd in job["heroes"]:
			var m := HeroModel.new().build(_hero(hd[0]), hd[1])
			m.position = hd[2]
			m.rotation_degrees.y = hd[3]
			r.add_child(m)
			match String(hd[4]):
				"attack":
					m.trigger_attack()
				"cast":
					m.trigger_cast()
			m.animate(0.12, 0.0)
	else:
		var sp := MeshInstance3D.new()
		sp.mesh = ModelLib.heartspire_body(job["spire"])
		sp.scale = Vector3.ONE * 1.25
		r.add_child(sp)
		var cr := MeshInstance3D.new()
		cr.mesh = ModelLib.crystal()
		cr.position = Vector3(0, 3.0, 0)
		cr.scale = Vector3.ONE * 1.0
		r.add_child(cr)
	var cam := Camera3D.new()
	cam.fov = job["fov"]
	cam.position = job["cam"]
	r.add_child(cam)
	cam.look_at(job["look"], Vector3.UP)
	cam.current = true


func _process(_d: float) -> bool:
	frame += 1
	if cur.is_empty():
		if jobs.is_empty():
			quit()
			return false
		cur = jobs.pop_front()
		_setup(cur)
		frame = 0
		return false
	if frame == 6:
		var img := vp.get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://%s/%s.png" % [opts["out"], cur["name"]])
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
		vp.queue_free()
		cur = {}
	return false
