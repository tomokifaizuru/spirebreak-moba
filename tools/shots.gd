extends SceneTree
## Screenshot helper (needs a display, e.g. xvfb-run):
##   godot --path . --resolution 1600x740 -s tools/shots.gd -- shot=teamfight out=/tmp/a.png
## shot = title | heroselect (pick=<hero id>) | early (at=<seconds>) | teamfight | tower | hud | victory
##        | shop | teamicons (2+ heroes dead) | camdrag (real touch-drag through the HUD)
##        | scoreboard (tab=1 for the build tab) | recommend (popup at base) | jungle (a hero farming a camp)
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
			wait = 60
			phase = 9
		elif opts["shot"] == "heroselect":
			change_scene_to_file("res://scenes/hero_select.tscn")
			wait = 50
			phase = 8
		else:
			_start_match()
			phase = 1
		return false
	if phase == 8:
		wait -= 1
		if wait == 30 and opts.has("pick"):
			var sel = current_scene
			for d in sel.roster:
				if String(d.id) == opts["pick"]:
					sel._select(d, false)
		if wait <= 0:
			_capture()
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
		"early":
			if phase == 1 and arena.time > float(opts.get("at", "25")):
				arena.sim_substeps = 1
				phase = 2
				wait = 10
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
					var cen := p.position
					for e in ens:
						cen += e.position
					cen /= float(ens.size() + 1)
					# nudge left/down a bit: the skill buttons cover the right side of the screen
					arena.look_override = cen + Vector2(110, 40)
					phase = 2
					wait = 14
		"hud", "tower":
			if phase == 1 and arena.time > 60.0 and p.alive:
				for s in arena.structures:
					if s.alive and s.team != p.team and not s.invulnerable and s.hp_frac() < 0.92 and s.hp_frac() > 0.3 \
							and p.position.distance_to(s.position) < 470.0 and arena.count_creeps_near(s.position, 500.0, p.team) >= 2:
						arena.sim_substeps = 1
						if opts["shot"] == "tower":
							arena.look_override = p.position.lerp(s.position, 0.5) + Vector2(0, 60)
						phase = 2
						wait = 30
						break
		"shop":
			if phase == 1 and arena.time > 90.0 and p.alive:
				arena.sim_substeps = 1
				p.autopilot = false
				p.command_stop()
				p.position = p.fountain + Vector2(140, -60)
				p.items.clear()
				p.items_changed()
				var cat: ItemCatalog = arena.config.item_catalog
				p.gold = 2000
				for id in ["swift_boots", "iron_blade", "oakheart_charm"]:
					for it in cat.all_items():
						if String(it.id) == id:
							Shop.buy(p, it)
				p.gold = 1140
				var cv: HudCanvas = arena.hud.canvas
				cv.shop.open()
				for it in cat.upgraded:
					if it.id == &"storm_edge":
						cv.shop.selected = it
				phase = 2
				wait = 25
		"scoreboard":
			if phase == 1 and arena.time > float(opts.get("at", "300")):
				arena.sim_substeps = 1
				var cvb: HudCanvas = arena.hud.canvas
				cvb.board.tab = int(opts.get("tab", "0"))
				cvb.toggle_board()
				phase = 2
				wait = 20
		"recommend":
			if phase == 1 and arena.time > 75.0 and p.alive:
				arena.sim_substeps = 1
				p.autopilot = false
				p.command_stop()
				p.position = p.fountain + Vector2(160, -80)
				p.items.clear()
				p.items_changed()
				var cvr: HudCanvas = arena.hud.canvas
				p.gold = 2000
				var b0: BuildData = null
				for b in arena.config.recommended_builds:
					if b.hero == p.data:
						b0 = b
				Shop.buy(p, b0.items[0])
				p.gold = Shop.price_for(p, b0.items[1]) + 35
				cvr.rec_cd = 0.0
				phase = 2
				wait = 30
		"jungle":
			if phase == 1 and arena.time > 150.0:
				for h in arena.heroes:
					if h.alive and h.brain != null and h.brain.state == "jungle" and h.attack_target != null \
							and h.attack_target.kind == Unit.Kind.NEUTRAL and h.position.distance_to(h.attack_target.position) < 200.0 \
							and (arena.time > 400.0 or h.attack_target.max_hp > 800.0):
						arena.sim_substeps = 1
						arena.look_override = h.position.lerp(h.attack_target.position, 0.5) + Vector2(60, 30)
						phase = 2
						wait = 12
						break
		"teamicons":
			if phase == 1 and arena.time > 100.0 and p.alive:
				var dead := [0, 0]
				for h in arena.heroes:
					if not h.alive and h.respawn_t > 2.0:
						dead[h.team] += 1
				if dead[0] + dead[1] >= 2:
					arena.sim_substeps = 1
					phase = 2
					wait = 3
		"camdrag":
			if phase == 1 and arena.time > 70.0 and p.alive:
				arena.sim_substeps = 1
				var cv2: HudCanvas = arena.hud.canvas
				var a0 := Vector2(cv2.size.x * 0.62, cv2.size.y * 0.42)
				cv2._press(7, a0)
				cv2._drag(7, a0 + Vector2(-120, 80))
				cv2._drag(7, a0 + Vector2(-330, 230))
				phase = 2
				wait = 40
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
	if opts.has("debug") and arena != null and arena.view != null:
		var stack: Array = [arena.view.dyn]
		while stack:
			var n = stack.pop_back()
			stack.append_array(n.get_children())
			if n is GeometryInstance3D and n.is_visible_in_tree():
				var ab: AABB = n.global_transform * n.get_aabb()
				if ab.size.x > 2.5 or ab.size.z > 2.5:
					print("BIG ", n.get_path(), " ", ab.size, " parent=", n.get_parent().get_class(), " ", n.get_parent().get_script().get_global_name() if n.get_parent().get_script() else "")
	if opts.has("perf"):
		var vp_rid := root.get_viewport_rid()
		print("PERF draw_calls=", RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			" primitives=", RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
			" objects=", RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
			" fps=", Engine.get_frames_per_second(), " video_mem=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576, "MB")
	var img := root.get_texture().get_image()
	img.save_png(opts["out"])
	print("saved ", opts["out"], " ", img.get_size(), " t=", (arena.time if arena != null else 0.0))
	quit()
