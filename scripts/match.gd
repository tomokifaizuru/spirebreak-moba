class_name Arena
extends Node2D
## The match: spawns heroes and creep waves, runs every unit each tick, gold / XP, win check.
## Global numbers live in data/match_config.tres (the `config` field in the Inspector).

signal match_over(winner: int)
signal feed(text: String, team: int)

@export var config: MatchConfig
## Camera zoom (bigger = closer).
@export var camera_zoom := 1.0
## Debug fast-forward: simulation ticks per frame. Keep at 1 for normal play.
@export var sim_substeps := 1

@onready var map: ArenaMap = $Map
@onready var units_root: Node2D = $Units
@onready var ground_root: Node2D = $Ground
@onready var air_root: Node2D = $Air
@onready var fx: FxLayer = $Fx
@onready var cam: Camera2D = $Camera
@onready var hud = $HUD

var headless := false
var time := 0.0
var units: Array[Unit] = []
var heroes: Array[Hero] = []
var structures: Array[Structure] = []
var neutrals: Array[NeutralMob] = []
var fx_nodes: Array = []
var walls: Array = []
var player: Hero
var kills := [0, 0]
var destroyed := [0, 0]
var wave_t := 0.0
var wave_count := 0
var over := false
var winner := -1
var end_reason := ""
var sudden_death := false
var lane_pts := PackedVector2Array()
var lane_cum := PackedFloat32Array()
var lane_len := 0.0
var creep_path := [PackedVector2Array(), PackedVector2Array()]
var fronts := [-1.0, -1.0]
var front_t := 0.0
var backdoor_t := 0.0
var shrine_cd := 0.0
var shrine_pos := Vector2.ZERO
var camps: Array = []
var gold_acc := 0.0
var joy_vector := Vector2.ZERO
var look_override := Vector2.INF
var structure_progress := {}
## Debug stats for the headless test.
var dbg := {"struct_dmg_hero": 0.0, "struct_dmg_creep": 0.0, "hero_deaths_tower": 0, "hero_deaths_hero": 0, "hero_deaths_other": 0}


func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	if config == null:
		config = load("res://data/match_config.tres")
	_build_lane()
	for s in map.get_structures():
		s.arena = self
		units.append(s)
		structures.append(s)
	shrine_pos = map.shrine_pos()
	for p in map.camp_positions():
		camps.append({"pos": p, "respawn_t": 0.0, "index": camps.size()})
	var dawn: Array[HeroData] = [config.player_hero]
	dawn.append_array(config.dawn_bots)
	for i in dawn.size():
		_spawn_hero(dawn[i], 0, i == 0, i)
	for i in config.dusk_bots.size():
		_spawn_hero(config.dusk_bots[i], 1, false, i)
	_update_structure_locks()
	wave_t = config.first_wave_time
	cam.zoom = Vector2(camera_zoom, camera_zoom)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(map.map_size.x)
	cam.limit_bottom = int(map.map_size.y)
	cam.position = player.position
	cam.reset_smoothing()
	var game := get_node_or_null("/root/Game")
	if game != null:
		if game.debug_args.has("autopilot"):
			player.autopilot = true
		if game.debug_args.has("speed"):
			sim_substeps = maxi(1, int(game.debug_args["speed"]))
	if hud != null and hud.has_method("setup") and not headless:
		hud.setup(self)


func _build_lane() -> void:
	lane_pts = map.get_lane()
	lane_cum.resize(lane_pts.size())
	lane_cum[0] = 0.0
	for i in range(1, lane_pts.size()):
		lane_cum[i] = lane_cum[i - 1] + lane_pts[i].distance_to(lane_pts[i - 1])
	lane_len = lane_cum[lane_pts.size() - 1]
	var path := PackedVector2Array()
	var d := 140.0
	while d < lane_len:
		path.append(lane_point_at(d))
		d += 90.0
	path.append(lane_pts[lane_pts.size() - 1])
	creep_path[0] = path
	var rev := path.duplicate()
	rev.reverse()
	var path1 := PackedVector2Array()
	var d1 := 140.0
	while d1 < lane_len:
		path1.append(lane_point_at(lane_len - d1))
		d1 += 90.0
	path1.append(lane_pts[0])
	creep_path[1] = path1
	# Keep creep waypoints out of tower / Heartspire bodies so creeps walk around them.
	for k in 2:
		var cp: PackedVector2Array = creep_path[k]
		for i in range(1, cp.size() - 1):
			for s in map.get_structures():
				var off: Vector2 = cp[i] - (s as Node2D).position
				var need: float = (s.stats.radius if s.stats != null else 44.0) + 36.0
				if off.length() < need:
					var tangent := (cp[i + 1] - cp[i - 1]).normalized()
					var side := tangent.orthogonal()
					if off.dot(side) < 0.0:
						side = -side
					cp[i] = (s as Node2D).position + side * need
		creep_path[k] = cp


func _spawn_hero(d: HeroData, team: int, is_player: bool, idx: int) -> void:
	var h := Hero.new()
	h.setup(d, team, self, is_player)
	h.position = map.fountain_pos(team) + Vector2.from_angle(idx * 2.1 + 0.4) * 70.0
	h.name = ("Player_" if is_player else "Bot_") + str(d.id) + "_" + str(team) + "_" + str(idx)
	units_root.add_child(h)
	units.append(h)
	heroes.append(h)
	if is_player:
		player = h


# ---------------- main loop ----------------

func _physics_process(delta: float) -> void:
	if over:
		return
	for i in sim_substeps:
		if over:
			break
		_step(delta)


func _process(delta: float) -> void:
	if player == null:
		return
	var target := player.position if player.alive else cam.position
	if look_override != Vector2.INF:
		target = look_override
	var k := 1.0 - exp(-10.0 * delta)
	if look_override != Vector2.INF:
		k = 1.0 - exp(-18.0 * delta)
	cam.position = cam.position.lerp(target, k)


func _step(dt: float) -> void:
	time += dt
	wave_t -= dt
	if wave_t <= 0.0:
		wave_t += config.wave_interval
		_spawn_wave()
	gold_acc += dt
	if gold_acc >= 1.0:
		gold_acc -= 1.0
		for h in heroes:
			h.gold += int(config.passive_gold_per_sec)
			if h.alive:
				h.add_xp(config.passive_xp_per_sec)
	if not sudden_death and time >= config.sudden_death_time:
		sudden_death = true
		feed.emit("SUDDEN DEATH! Buildings are weaker, creeps are stronger.", -1)
	_fountains(dt)
	_shrine(dt)
	_camps(dt)
	for u in units.duplicate():
		if u.alive or u is Hero:
			u.step(dt)
	for f in fx_nodes.duplicate():
		f.step(dt)
	_separate()
	front_t -= dt
	if front_t <= 0.0:
		front_t = 0.25
		_compute_fronts()
	backdoor_t -= dt
	if backdoor_t <= 0.0:
		backdoor_t = 0.25
		_update_backdoor()
	if not over and time >= config.tiebreak_time:
		_tiebreak()


func _spawn_wave() -> void:
	wave_count += 1
	var pm := config.sudden_death_creep_mult if sudden_death else 1.0
	for team in [0, 1]:
		var path: PackedVector2Array = creep_path[team]
		var tm: float = pm * (1.0 + config.creep_mult_per_building_destroyed * destroyed[team])
		var list: Array = []
		for i in config.melee_per_wave:
			list.append([config.creep_melee, false])
		for i in config.ranged_per_wave:
			list.append([config.creep_ranged, false])
		if config.siege_every_n_waves > 0 and wave_count % config.siege_every_n_waves == 0:
			list.append([config.creep_siege, true])
		var dir := (path[1] - path[0]).normalized()
		for i in list.size():
			var c := Creep.new()
			c.setup(list[i][0], team, self, path, tm, list[i][1])
			c.position = path[0] - dir * (i * 34.0) + dir.orthogonal() * randf_range(-20, 20)
			c.offset = dir.orthogonal() * randf_range(-40.0, 40.0)
			c.wp = 1
			units_root.add_child(c)
			units.append(c)


func _fountains(dt: float) -> void:
	for h in heroes:
		if not h.alive:
			continue
		if h.position.distance_to(map.fountain_pos(h.team)) <= config.fountain_radius:
			h.heal(h.max_hp * config.fountain_heal_pct * dt)
			h.mana = minf(h.max_mana, h.mana + h.max_mana * config.fountain_heal_pct * dt)
		if h.position.distance_to(map.fountain_pos(1 - h.team)) <= config.fountain_radius:
			h.take_damage(config.fountain_damage * dt, null, true, false)


func shrine_ready() -> bool:
	return shrine_cd <= 0.0


func _shrine(dt: float) -> void:
	shrine_cd -= dt
	if shrine_cd > 0.0:
		return
	for h in heroes:
		if h.alive and h.hp_frac() < 0.9 and h.position.distance_to(shrine_pos) <= config.shrine_radius + h.radius:
			h.heal(h.max_hp * config.shrine_heal_pct)
			h.mana = minf(h.max_mana, h.mana + h.max_mana * config.shrine_heal_pct)
			shrine_cd = config.shrine_cooldown
			fx_ring(shrine_pos, 20.0, 160.0, Color(0.5, 1.0, 0.6), 0.6, 6.0)
			fx_text(h.position + Vector2(0, -50), "+HEAL", Color(0.5, 1.0, 0.6), 18)
			sfx_at("heal", shrine_pos)
			break


func _camps(dt: float) -> void:
	if config.camp_monster == null:
		return
	for camp in camps:
		var alive_n := 0
		for m in neutrals:
			if m.alive and m.camp_index == camp["index"]:
				alive_n += 1
		if alive_n > 0:
			continue
		camp["respawn_t"] -= dt
		if camp["respawn_t"] <= 0.0:
			camp["respawn_t"] = config.camp_respawn
			for i in config.monsters_per_camp:
				var m := NeutralMob.new()
				var off := Vector2.from_angle(i * TAU / maxf(config.monsters_per_camp, 1) + 0.6) * 34.0
				m.setup(config.camp_monster, self, camp["pos"] + off)
				m.camp_index = camp["index"]
				units_root.add_child(m)
				units.append(m)
				neutrals.append(m)


func _separate() -> void:
	var movers: Array[Unit] = []
	for u in units:
		if not u.alive or u.kind == Unit.Kind.STRUCTURE:
			continue
		if u is Hero and not (u as Hero).dash.is_empty():
			continue
		movers.append(u)
	var n := movers.size()
	for i in n:
		var a := movers[i]
		var ah := a.kind == Unit.Kind.HERO
		for j in range(i + 1, n):
			var b := movers[j]
			var d := b.position - a.position
			var min_d := a.radius + b.radius
			var l2 := d.length_squared()
			if l2 >= min_d * min_d:
				continue
			var l := sqrt(l2)
			var nrm := d / l if l > 0.01 else Vector2.from_angle(randf() * TAU)
			var push := (min_d - l) * 0.5
			var bh := b.kind == Unit.Kind.HERO
			var wa := 0.5
			if ah and not bh:
				wa = 0.2
			elif bh and not ah:
				wa = 0.8
			a.position -= nrm * push * wa
			b.position += nrm * push * (1.0 - wa)
	for s in structures:
		if not s.alive:
			continue
		for u in movers:
			var d2 := u.position - s.position
			var md := s.radius + u.radius
			if d2.length_squared() < md * md:
				var l3 := d2.length()
				u.position = s.position + (d2 / l3 if l3 > 0.01 else Vector2.RIGHT) * md
	for w in walls:
		for p in w.wall_points:
			for u in movers:
				if u.team == w.team:
					continue
				var d3: Vector2 = u.position - p
				var md2: float = w.wall_r + u.radius
				if d3.length_squared() < md2 * md2:
					var l4 := d3.length()
					u.position = p + (d3 / l4 if l4 > 0.01 else Vector2.RIGHT) * md2
	for u in movers:
		clamp_pos(u)


func _compute_fronts() -> void:
	fronts = [-1.0, -1.0]
	for u in units:
		if u.alive and u.kind == Unit.Kind.CREEP:
			var p := team_progress(u.team, u.position)
			if p > fronts[u.team]:
				fronts[u.team] = p


func _update_backdoor() -> void:
	for s in structures:
		if not s.alive:
			continue
		var protected := true
		for u in units:
			if u.alive and u.kind == Unit.Kind.CREEP and u.team != s.team \
					and u.position.distance_to(s.position) <= config.backdoor_radius:
				protected = false
				break
		var m := (1.0 - config.backdoor_reduction) if protected else 1.0
		if sudden_death:
			m *= config.sudden_death_structure_damage_mult
		s.damage_taken_mult = m


func _update_structure_locks() -> void:
	for team in [0, 1]:
		var outer := false
		var inner := false
		for s in structures:
			if s.team == team and s.alive:
				if s.tier == 0:
					outer = true
				elif s.tier == 1:
					inner = true
		for s in structures:
			if s.team == team:
				s.invulnerable = (s.tier == 1 and outer) or (s.tier == 2 and (outer or inner))


func _tiebreak() -> void:
	var w := -1
	var reason := ""
	if destroyed[0] != destroyed[1]:
		w = 0 if destroyed[0] > destroyed[1] else 1
		reason = "Time! More buildings destroyed"
	else:
		var hpsum := [0.0, 0.0]
		for s in structures:
			if s.alive:
				hpsum[s.team] += s.hp_frac()
		if absf(hpsum[0] - hpsum[1]) > 0.001:
			w = 0 if hpsum[0] > hpsum[1] else 1
			reason = "Time! Healthier buildings"
		else:
			w = 0 if kills[0] >= kills[1] else 1
			reason = "Time! More hero kills"
	_end_match(w, reason)


func _end_match(w: int, reason: String) -> void:
	if over:
		return
	over = true
	winner = w
	end_reason = reason
	for h in heroes:
		h.command_stop()
	if player != null:
		sfx_at("victory" if w == player.team else "defeat", player.position, 0.0, true)
	match_over.emit(w)


# ---------------- events from units ----------------

func on_damage(u: Unit, src: Unit, dealt: float, show: bool) -> void:
	if u.kind == Unit.Kind.STRUCTURE and src != null:
		if src.kind == Unit.Kind.HERO:
			dbg["struct_dmg_hero"] += dealt
		else:
			dbg["struct_dmg_creep"] += dealt
	if src != null and src.kind == Unit.Kind.HERO and u.kind == Unit.Kind.HERO and src.team != u.team:
		_hero_hits_hero(src, u)
	if headless or player == null or not show:
		return
	if src == player:
		var big := dealt >= 150.0
		fx.text(u.position + Vector2(0, -u.radius), str(int(dealt)) + ("!" if big else ""), Color("ffd84a") if big else Color.WHITE, 22 if big else 17)
	elif u == player and dealt >= 1.0:
		fx.text(u.position + Vector2(0, -u.radius), "-" + str(int(dealt)), Color("ff6b6b"), 17)
	elif src != null and src.kind == Unit.Kind.HERO and u.kind == Unit.Kind.HERO and dealt >= 40.0:
		fx.text(u.position + Vector2(0, -u.radius), str(int(dealt)), Color(1, 1, 1, 0.75), 14)


func _hero_hits_hero(attacker: Unit, victim: Unit) -> void:
	for s in structures:
		if s.alive and s.team == victim.team and victim.position.distance_to(s.position) <= s.attack_range + s.radius + 120.0:
			s.set_aggro(attacker, config.tower_aggro_time)
	for u in units:
		if u.alive and u.kind == Unit.Kind.CREEP and u.team == victim.team and u.position.distance_to(attacker.position) < 420.0:
			(u as Creep).force_target(attacker, 2.0)


func _credit(u: Unit, killer: Unit) -> Hero:
	if killer != null and killer is Hero and killer.team != u.team:
		return killer
	var best: Hero = null
	var bt := -INF
	for k in u.recent_attackers:
		if is_instance_valid(k) and k is Hero and k.team != u.team and time - u.recent_attackers[k] <= 10.0:
			if u.recent_attackers[k] > bt:
				bt = u.recent_attackers[k]
				best = k
	return best


func _share_xp(u: Unit, amount: float, enemy_of: int) -> void:
	var list: Array[Hero] = []
	for h in heroes:
		if h.alive and h.team != enemy_of and h.team != Unit.NEUTRAL_TEAM and h.position.distance_to(u.position) <= config.xp_share_radius:
			list.append(h)
	if list.is_empty():
		return
	var each := amount * (1.0 + 0.25 * (list.size() - 1)) / list.size()
	for h in list:
		h.add_xp(each)


func on_unit_died(u: Unit, killer: Unit) -> void:
	var kh := _credit(u, killer)
	match u.kind:
		Unit.Kind.CREEP, Unit.Kind.NEUTRAL:
			if kh != null:
				kh.gold += u.bounty_gold
				kh.last_hits += 1
				if kh == player and not headless:
					fx.text(u.position + Vector2(0, -30), "+%dg" % u.bounty_gold, Art.GOLD, 16)
					sfx_at("coin", u.position, -8.0)
			if u.kind == Unit.Kind.NEUTRAL:
				if kh != null:
					_share_xp(u, u.bounty_xp, 1 - kh.team)
			else:
				_share_xp(u, u.bounty_xp, u.team)
			units.erase(u)
			if u is NeutralMob:
				neutrals.erase(u)
			u.queue_free()
		Unit.Kind.HERO:
			var v: Hero = u
			kills[1 - v.team] += 1
			if killer != null and killer.kind == Unit.Kind.STRUCTURE:
				dbg["hero_deaths_tower"] += 1
			elif killer != null and killer.kind == Unit.Kind.HERO:
				dbg["hero_deaths_hero"] += 1
			else:
				dbg["hero_deaths_other"] += 1
			var assist_names: Array[String] = []
			if kh != null:
				kh.kills += 1
				kh.streak += 1
				kh.gold += config.gold_hero_kill + config.gold_streak_bonus * mini(v.last_streak, 5)
			for k in v.recent_attackers:
				if is_instance_valid(k) and k is Hero and k != kh and k.team != v.team and time - v.recent_attackers[k] <= 10.0:
					(k as Hero).assists += 1
					(k as Hero).gold += config.gold_assist
					assist_names.append(k.display_name)
			_share_xp(v, config.hero_kill_xp_base + config.hero_kill_xp_per_level * v.level, v.team)
			var vn := "You" if v == player else v.display_name
			var txt := ""
			if kh != null:
				var kn := "You" if kh == player else kh.display_name
				txt = "%s defeated %s" % [kn, vn]
			else:
				txt = "%s fell" % vn
			feed.emit(txt, 1 - v.team)
			sfx_at("death", v.position)
			if not headless:
				fx_ring(v.position, 10.0, 90.0, Art.team_color(v.team), 0.5, 6.0)
		Unit.Kind.STRUCTURE:
			var s: Structure = u
			destroyed[1 - s.team] += 1
			for h in heroes:
				if h.team != s.team:
					h.gold += config.gold_tower_team
			_share_xp(s, s.bounty_xp, s.team)
			var tname: String = ["Outer Tower", "Inner Tower", "Heartspire"][s.tier]
			feed.emit("%s %s destroyed!" % ["Dawn" if s.team == 0 else "Dusk", tname], 1 - s.team)
			sfx_at("boom", s.position, 0.0, true)
			if not headless:
				fx_ring(s.position, 20.0, 220.0, Color(1, 0.8, 0.4), 0.7, 10.0)
			_update_structure_locks()
			if s.is_heartspire():
				_end_match(1 - s.team, "%s Heartspire destroyed" % ("Dawn" if s.team == 0 else "Dusk"))
	u.recent_attackers.clear()


func on_level_up(h: Hero) -> void:
	if h == player and not headless:
		fx.text(h.position + Vector2(0, -70), "LEVEL %d" % h.level, Color("8fe8ff"), 22, 1.2)
		play_sfx("levelup", -4.0)
		if h.level == 4:
			feed.emit("Ultimate unlocked!", h.team)


func on_respawn(_h: Hero) -> void:
	pass


func on_cast(h: Hero, _ab: AbilityData) -> void:
	sfx_at("cast", h.position, -6.0)


# ---------------- spawning helpers ----------------

func spawn_homing(src: Unit, target: Unit, dmg: float, speed: float, style: String, offset := Vector2.ZERO, on_hit := Callable()) -> Projectile:
	var p := Projectile.new()
	p.arena = self
	p.source = src
	p.team = src.team
	p.target = target
	p.homing = true
	p.speed = speed
	p.damage = dmg
	p.style = style
	p.on_hit = on_hit
	p.position = src.position + offset
	_add_fx(p, air_root)
	return p


func spawn_line(src: Unit, from: Vector2, dir: Vector2, dist: float, speed: float, width: float, dmg: float, style: String, pierce: bool, on_hit := Callable()) -> Projectile:
	var p := Projectile.new()
	p.arena = self
	p.source = src
	p.team = src.team
	p.homing = false
	p.dir = dir.normalized()
	p.max_dist = dist
	p.speed = speed
	p.width = width
	p.damage = dmg
	p.style = style
	p.pierce = pierce
	p.on_hit = on_hit
	p.position = from
	_add_fx(p, air_root)
	return p


func spawn_area(src: Unit, kind: String, pos: Vector2, radius: float, opts: Dictionary) -> AreaFx:
	var f := AreaFx.new()
	f.arena = self
	f.source = src
	f.team = src.team
	f.kind = kind
	f.radius = radius
	f.position = pos
	f.duration = opts.get("duration", 1.0)
	f.delay = opts.get("delay", 0.0)
	f.tick = opts.get("tick", 0.5)
	f.dmg = opts.get("dmg", 0.0)
	f.slow = opts.get("slow", 0.0)
	f.root_dur = opts.get("root", 0.0)
	_add_fx(f, ground_root)
	return f


func spawn_wall(src: Unit, center: Vector2, along: Vector2, duration: float) -> void:
	var f := AreaFx.new()
	f.arena = self
	f.source = src
	f.team = src.team
	f.kind = "wall"
	f.duration = duration
	f.position = center
	var pts := PackedVector2Array()
	for i in range(-2, 3):
		pts.append(center + along.normalized() * i * 56.0)
	f.wall_points = pts
	_add_fx(f, ground_root)
	walls.append(f)


func _add_fx(n: Node2D, parent: Node2D) -> void:
	fx_nodes.append(n)
	if headless:
		n.set_process(false)
	parent.add_child(n)


func remove_fx(n: Node) -> void:
	fx_nodes.erase(n)
	walls.erase(n)
	n.queue_free()


func fx_text(pos: Vector2, s: String, col: Color, size := 18) -> void:
	if not headless:
		fx.text(pos, s, col, size)


func fx_ring(pos: Vector2, r0: float, r1: float, col: Color, life := 0.35, width := 4.0) -> void:
	if not headless:
		fx.ring(pos, r0, r1, col, life, width)


func fx_slash(pos: Vector2, dir: Vector2, r: float, col: Color) -> void:
	if not headless:
		fx.slash(pos, dir, r, col)


func fx_beam(a: Vector2, b: Vector2, col: Color, width := 6.0) -> void:
	if not headless:
		fx.beam(a, b, col, width)


func sfx_at(sound: String, pos: Vector2, vol := 0.0, always := false) -> void:
	if headless:
		return
	if not always and cam.get_screen_center_position().distance_to(pos) > 950.0:
		return
	play_sfx(sound, vol)


func play_sfx(sound: String, vol := 0.0) -> void:
	var s := get_node_or_null("/root/Sfx")
	if s != null:
		s.play(sound, vol)


# ---------------- queries ----------------

func clamp_pos(u: Node2D) -> void:
	u.position = u.position.clamp(Vector2(40, 40), map.map_size - Vector2(40, 40))


func enemies_in_radius(team: int, pos: Vector2, r: float, include_structures := true) -> Array:
	var out: Array = []
	for u in units:
		if not u.alive or u.team == team:
			continue
		if not include_structures and u.kind == Unit.Kind.STRUCTURE:
			continue
		if not u.is_targetable_by(team):
			continue
		if pos.distance_to(u.position) <= r + u.radius:
			out.append(u)
	return out


## Heroes near `pos`. enemies=true -> heroes NOT on `team` (targetable ones), else allies of `team`.
func heroes_near(pos: Vector2, r: float, team: int, enemies: bool) -> Array:
	var out: Array = []
	for h in heroes:
		if not h.alive:
			continue
		if enemies:
			if h.team == team or not h.is_targetable_by(team):
				continue
		elif h.team != team:
			continue
		if pos.distance_to(h.position) <= r:
			out.append(h)
	return out


func alive_heroes(team: int) -> int:
	var n := 0
	for h in heroes:
		if h.alive and h.team == team:
			n += 1
	return n


func count_creeps_near(pos: Vector2, r: float, team: int) -> int:
	var n := 0
	for u in units:
		if u.alive and u.kind == Unit.Kind.CREEP and u.team == team and pos.distance_to(u.position) <= r:
			n += 1
	return n


## An enemy building (that can shoot) whose range covers hero `h` (plus margin).
func enemy_tower_threatening(h: Hero, margin: float) -> Structure:
	for s in structures:
		if s.alive and s.team != h.team and s.stats != null and s.stats.damage > 0.0:
			if h.position.distance_to(s.position) <= s.attack_range + s.radius + h.radius + margin:
				return s
	return null


func enemy_tower_covering(team: int, pos: Vector2, margin := 0.0) -> Structure:
	for s in structures:
		if s.alive and s.team != team and s.stats != null and s.stats.damage > 0.0:
			if pos.distance_to(s.position) <= s.attack_range + s.radius + margin:
				return s
	return null


func own_tower_covering(team: int, pos: Vector2) -> Structure:
	for s in structures:
		if s.alive and s.team == team and s.stats != null and s.stats.damage > 0.0:
			if pos.distance_to(s.position) <= s.attack_range + s.radius:
				return s
	return null


func attackable_structure_near(h: Hero, r: float) -> Structure:
	var best: Structure = null
	var bd := INF
	for s in structures:
		if s.alive and s.team != h.team and not s.invulnerable:
			var d := h.position.distance_to(s.position) - s.radius
			if d <= r and d < bd:
				bd = d
				best = s
	return best


func outermost_tower_progress(team: int) -> float:
	var best := 300.0
	for s in structures:
		if s.alive and s.team == team:
			best = maxf(best, team_progress(team, s.position))
	return best


## Distance along the lane from the Dawn end to the closest lane point.
func progress_of(pos: Vector2) -> float:
	var best := INF
	var bp := 0.0
	var n := lane_pts.size()
	var i := 0
	while i < n - 1:
		var a := lane_pts[i]
		var b := lane_pts[i + 1]
		var ab := b - a
		var t := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var q := a + ab * t
		var d := pos.distance_squared_to(q)
		if d < best:
			best = d
			bp = lane_cum[i] + (lane_cum[i + 1] - lane_cum[i]) * t
		i += 1
	return bp


## Progress measured from `team`'s own base.
func team_progress(team: int, pos: Vector2) -> float:
	var p := progress_of(pos)
	return p if team == 0 else lane_len - p


func lane_point_at(d: float) -> Vector2:
	d = clampf(d, 0.0, lane_len)
	var lo := 0
	var hi := lane_cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if lane_cum[mid] < d:
			lo = mid
		else:
			hi = mid
	var seg := lane_cum[hi] - lane_cum[lo]
	var t := (d - lane_cum[lo]) / seg if seg > 0.0 else 0.0
	return lane_pts[lo].lerp(lane_pts[hi], t)


func lane_point(team: int, p: float) -> Vector2:
	return lane_point_at(p if team == 0 else lane_len - p)
