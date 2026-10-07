class_name Hero
extends Unit
## A hero: yours or a bot. Bots use BotBrain, which presses the same "buttons" you do
## (move, attack, cast skill 0-3, recall, heal). Stats come from a HeroData resource.

signal leveled_up(level: int)

var data: HeroData
var is_player := false
## When true your hero is driven by the bot AI (F8 on desktop, used by the headless test).
var autopilot := false
var brain: BotBrain = null
var level := 1
var xp := 0.0
var gold := 0
var mana := 0.0
var max_mana := 0.0
var hp_regen := 0.0
var mana_regen := 0.0
var attack_damage := 0.0
var attack_range := 0.0
var attack_interval := 1.0
var move_speed := 300.0
var ranks: Array[int] = [0, 0, 0, 0]
var cds: Array[float] = [0.0, 0.0, 0.0, 0.0]
var skill_points := 0
var attack_cd := 0.0
var heal_cd := 0.0
var kills := 0
var deaths := 0
var assists := 0
var last_hits := 0
var streak := 0
var last_streak := 0
var respawn_t := 0.0
var input_move := Vector2.ZERO
var attack_target: Unit = null
var attack_command := false
var attack_held := false
var has_move_point := false
var move_point := Vector2.ZERO
var facing := Vector2.DOWN
var empowered := 0.0
var recall_t := 0.0
var haste_t := 0.0
var haste_amt := 0.0
var dash := {}
var timers: Array = []
var anim_t := 0.0
var last_hurt_time := -99.0
## Set by the HUD while you drag a skill button: {"slot", "dir", "mag"}.
var aim_preview := {}
var fountain := Vector2.ZERO
var distance_moved := 0.0
var font: Font


func setup(d: HeroData, t: int, a: Arena, player := false) -> void:
	data = d
	team = t
	arena = a
	is_player = player
	kind = Kind.HERO
	display_name = d.display_name
	radius = d.radius
	level = 1
	_recalc_stats()
	hp = max_hp
	mana = max_mana
	skill_points = 1
	_auto_spend()
	gold = a.config.starting_gold
	fountain = a.map.fountain_pos(t)
	brain = BotBrain.new(self)
	brain.setup_difficulty(a.config.bot_difficulty)
	font = ThemeDB.fallback_font


func is_bot_controlled() -> bool:
	return (not is_player) or autopilot


func _recalc_stats() -> void:
	var l := float(level - 1)
	max_hp = data.max_hp + data.hp_per_level * l
	max_mana = data.max_mana + data.mana_per_level * l
	hp_regen = data.hp_regen * (1.0 + 0.08 * l)
	mana_regen = data.mana_regen * (1.0 + 0.08 * l)
	armor = data.armor + data.armor_per_level * l
	attack_damage = data.attack_damage + data.attack_damage_per_level * l
	attack_range = data.attack_range
	attack_interval = data.attack_interval * pow(0.98, l)
	move_speed = data.move_speed


func xp_needed() -> float:
	return arena.config.xp_for_level(level)


func add_xp(v: float) -> void:
	if not alive and v <= 0.0:
		return
	if level >= arena.config.max_level:
		xp = 0.0
		return
	xp += v
	while level < arena.config.max_level and xp >= xp_needed():
		xp -= xp_needed()
		_level_up()
	if level >= arena.config.max_level:
		xp = 0.0


func _level_up() -> void:
	var oh := max_hp
	var om := max_mana
	level += 1
	_recalc_stats()
	if alive:
		hp += max_hp - oh
		mana += max_mana - om
	skill_points += 1
	_auto_spend()
	leveled_up.emit(level)
	arena.on_level_up(self)


func max_rank(slot: int) -> int:
	if slot == 3:
		if level >= 12:
			return 3
		if level >= 8:
			return 2
		return 1 if level >= 4 else 0
	return mini(4, int((level + 1) / 2.0))


## Skill points are spent automatically: ultimate at 4/8/12, otherwise the hero's skill_priority.
func _auto_spend() -> void:
	while skill_points > 0:
		var pick := -1
		if ranks[3] < max_rank(3):
			pick = 3
		else:
			for s in data.skill_priority:
				if ranks[s] == 0 and ranks[s] < max_rank(s):
					pick = s
					break
			if pick < 0:
				for s in data.skill_priority:
					if ranks[s] < max_rank(s):
						pick = s
						break
		if pick < 0:
			break
		ranks[pick] += 1
		skill_points -= 1


func attack_reach(u: Unit) -> float:
	return attack_range + radius + u.radius


func cur_speed() -> float:
	var s := move_speed * speed_mult()
	if haste_t > 0.0:
		s *= 1.0 + haste_amt
	return s


# ---------------- commands (used by the HUD and by bots) ----------------

func command_move(p: Vector2) -> void:
	move_point = p
	has_move_point = true
	attack_command = false


func command_attack(u: Unit) -> void:
	if valid(u) and u.is_targetable_by(team):
		attack_target = u
		attack_command = true
		has_move_point = false


func command_stop() -> void:
	attack_command = false
	has_move_point = false
	input_move = Vector2.ZERO


## Attack button pressed: lock the best target nearby.
func press_attack() -> void:
	if not alive:
		return
	var t := find_attack_target()
	if t != null:
		command_attack(t)


func find_attack_target(extra := 320.0) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in arena.units:
		if not u.alive or u.team == team or not u.is_targetable_by(team):
			continue
		var d := position.distance_to(u.position) - u.radius
		if d > attack_range + radius + extra:
			continue
		var score := d
		if u.kind == Kind.HERO and d <= attack_range + radius:
			score -= 2000.0
		elif u.kind == Kind.STRUCTURE:
			score += 120.0
		if score < bd:
			bd = score
			best = u
	return best


func start_recall() -> void:
	if not alive or recall_t > 0.0 or not dash.is_empty():
		return
	recall_t = arena.config.recall_time
	command_stop()


func cancel_recall() -> void:
	recall_t = 0.0


func _finish_recall() -> void:
	recall_t = 0.0
	arena.fx_ring(position, 20.0, 80.0, Color(0.6, 0.85, 1.0))
	position = fountain + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	command_stop()
	arena.fx_ring(position, 20.0, 80.0, Color(0.6, 0.85, 1.0))


func cast_heal() -> bool:
	if not alive or heal_cd > 0.0:
		return false
	heal(max_hp * arena.config.heal_spell_pct + arena.config.heal_spell_flat)
	heal_cd = arena.config.heal_spell_cooldown
	arena.fx_ring(position, 10.0, 70.0, Color(0.5, 1.0, 0.6))
	arena.sfx_at("heal", position)
	return true


# ---------------- per-tick update ----------------

func step(dt: float) -> void:
	if not alive:
		respawn_t -= dt
		if respawn_t <= 0.0:
			respawn()
		return
	tick_status(dt)
	heal(hp_regen * dt)
	mana = minf(max_mana, mana + mana_regen * dt)
	for i in 4:
		cds[i] = maxf(0.0, cds[i] - dt)
	attack_cd -= dt
	heal_cd -= dt
	anim_t = maxf(0.0, anim_t - dt)
	haste_t -= dt
	_tick_timers(dt)
	if not alive:
		return
	if not dash.is_empty():
		_step_dash(dt)
		return
	if stun_t > 0.0:
		return
	if is_bot_controlled():
		brain.think(dt)
	else:
		_read_player_input()
	if recall_t > 0.0:
		if input_move != Vector2.ZERO or attack_command or has_move_point:
			cancel_recall()
		else:
			recall_t -= dt
			if recall_t <= 0.0:
				_finish_recall()
			return
	if taunt_t > 0.0 and valid(taunt_src) and taunt_src.is_targetable_by(team):
		attack_target = taunt_src
		attack_command = true
		input_move = Vector2.ZERO
		has_move_point = false
	if attack_command and not (valid(attack_target) and attack_target.is_targetable_by(team)):
		attack_command = false
		attack_target = null
	var before := position
	if input_move != Vector2.ZERO:
		_move_dir(input_move, dt)
	elif attack_command:
		var d := position.distance_to(attack_target.position)
		if d <= attack_reach(attack_target):
			facing = (attack_target.position - position).normalized()
			if attack_cd <= 0.0:
				_do_attack(attack_target)
		else:
			_move_toward(attack_target.position, dt)
	elif has_move_point:
		if position.distance_to(move_point) < 10.0:
			has_move_point = false
		else:
			_move_toward(move_point, dt)
	distance_moved += position.distance_to(before)


func _read_player_input() -> void:
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var v := arena.joy_vector + kb
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < 0.2:
		v = Vector2.ZERO
	input_move = v
	if v != Vector2.ZERO:
		has_move_point = false
		attack_command = false
	var holding := attack_held or Input.is_action_pressed("attack")
	if holding and v == Vector2.ZERO:
		var keep := valid(attack_target) and attack_target.is_targetable_by(team) \
				and position.distance_to(attack_target.position) <= attack_reach(attack_target) + 320.0
		if not keep:
			attack_target = find_attack_target()
		if attack_target != null:
			attack_command = true
			has_move_point = false


func _move_dir(v: Vector2, dt: float) -> void:
	if root_t > 0.0:
		return
	var d := v.normalized()
	position += d * cur_speed() * dt
	facing = d
	arena.clamp_pos(self)


func _move_toward(p: Vector2, dt: float) -> void:
	if root_t > 0.0:
		return
	var v := p - position
	var l := v.length()
	if l < 1.0:
		return
	facing = v / l
	position += facing * minf(l, cur_speed() * dt)
	arena.clamp_pos(self)


func _do_attack(t: Unit) -> void:
	attack_cd = attack_interval
	anim_t = 0.15
	stealth_t = 0.0
	var dmg := attack_damage
	var big := false
	if empowered > 0.0:
		dmg *= 1.0 + empowered
		empowered = 0.0
		big = true
	if data.ranged_attack:
		var style := "arrow" if data.id == &"kestrel" else "orb"
		var p := arena.spawn_homing(self, t, dmg, data.projectile_speed, style, facing * radius)
		if big:
			p.style = "bolt"
		arena.sfx_at("shoot", position, -4.0)
	else:
		t.take_damage(dmg, self)
		arena.fx_slash(t.position, facing, t.radius + 14.0, Color(1, 0.6, 0.6) if data.id == &"sable" else Color(1, 1, 0.8))
		arena.sfx_at("hit", position, -4.0)


func respawn() -> void:
	alive = true
	visible = true
	hp = max_hp
	mana = max_mana
	stun_t = 0.0
	root_t = 0.0
	slow_t = 0.0
	taunt_t = 0.0
	mark_t = 0.0
	stealth_t = 0.0
	untargetable_t = 0.0
	shield = 0.0
	position = fountain + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	command_stop()
	attack_target = null
	dash = {}
	recall_t = 0.0
	recent_attackers.clear()
	arena.on_respawn(self)


func _on_death(_killer: Unit) -> void:
	deaths += 1
	last_streak = streak
	streak = 0
	respawn_t = arena.config.respawn_time(level, arena.time)
	visible = false
	dash = {}
	timers.clear()
	recall_t = 0.0
	command_stop()
	aim_preview = {}


func _on_damaged(src: Unit, _amount: float) -> void:
	last_hurt_time = arena.time
	if recall_t > 0.0 and src != null:
		cancel_recall()


func _tick_timers(dt: float) -> void:
	if timers.is_empty():
		return
	var due: Array = []
	for tm in timers:
		tm["t"] -= dt
		if tm["t"] <= 0.0:
			due.append(tm)
	for tm in due:
		timers.erase(tm)
		if alive:
			(tm["f"] as Callable).call()


# ---------------- skills ----------------

func can_cast(slot: int) -> bool:
	if not alive or stun_t > 0.0 or not dash.is_empty():
		return false
	if slot < 0 or slot > 3 or slot >= data.abilities.size():
		return false
	if ranks[slot] <= 0 or cds[slot] > 0.0:
		return false
	return mana >= data.abilities[slot].mana_cost


## Cast skill `slot` (0-2 skills, 3 ultimate). `aim` may hold "dir" (+ "mag" 0..1) for manual
## aiming, "target" (a Unit) or "point". Empty = auto-aim at the best target.
func cast(slot: int, aim := {}) -> bool:
	if not can_cast(slot):
		return false
	var ab: AbilityData = data.abilities[slot]
	var r := ranks[slot]
	var a := _resolve_aim(ab, aim)
	if not _do_ability(ab, r, a, slot):
		return false
	cds[slot] = ab.cd_at(r)
	mana -= ab.mana_cost
	if ab.id != &"smoke_veil":
		stealth_t = 0.0
	recall_t = 0.0
	arena.on_cast(self, ab)
	return true


func best_skill_target(rng: float) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in arena.units:
		if not u.alive or u.team == team or u.kind == Kind.STRUCTURE or not u.is_targetable_by(team):
			continue
		var d := position.distance_to(u.position) - u.radius
		if d > rng:
			continue
		var score := d - (5000.0 if u.kind == Kind.HERO else 0.0)
		if score < bd:
			bd = score
			best = u
	return best


func _target_near_line(dir: Vector2, rng: float) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in arena.units:
		if not u.alive or u.team == team or u.kind == Kind.STRUCTURE or not u.is_targetable_by(team):
			continue
		var rel := u.position - position
		var along := rel.dot(dir)
		if along < 0.0 or along > rng + u.radius:
			continue
		var perp := absf(rel.cross(dir))
		if perp > 140.0:
			continue
		var score := along + perp * 2.0 - (1000.0 if u.kind == Kind.HERO else 0.0)
		if score < bd:
			bd = score
			best = u
	return best


func _resolve_aim(ab: AbilityData, aim: Dictionary) -> Dictionary:
	var res := {"manual": false}
	var rng := ab.cast_range
	var tgt: Unit = null
	if aim.has("target") and valid(aim["target"]):
		tgt = aim["target"]
	if aim.has("dir") and (aim["dir"] as Vector2) != Vector2.ZERO:
		var d: Vector2 = (aim["dir"] as Vector2).normalized()
		var mag: float = clampf(float(aim.get("mag", 1.0)), 0.12, 1.0)
		res["manual"] = true
		res["dir"] = d
		res["point"] = position + d * rng * mag
		if tgt == null:
			tgt = _target_near_line(d, rng)
	elif aim.has("point"):
		var to: Vector2 = (aim["point"] as Vector2) - position
		res["manual"] = true
		res["dir"] = to.normalized() if to.length() > 1.0 else facing
		res["point"] = position + to.limit_length(rng)
		if tgt == null:
			tgt = _target_near_line(res["dir"], rng)
	else:
		if tgt == null:
			tgt = best_skill_target(rng + 40.0)
		if tgt != null:
			var to2 := tgt.position - position
			res["dir"] = to2.normalized() if to2.length() > 1.0 else facing
			res["point"] = position + to2.limit_length(rng)
		else:
			res["dir"] = input_move.normalized() if input_move != Vector2.ZERO else facing
			res["point"] = position + (res["dir"] as Vector2) * rng * 0.6
	res["target"] = tgt
	return res


func _mobility_dir(a: Dictionary) -> Vector2:
	if a["manual"]:
		return a["dir"]
	if input_move != Vector2.ZERO:
		return input_move.normalized()
	return facing


func _do_ability(ab: AbilityData, r: int, a: Dictionary, slot: int) -> bool:
	var dmg := ab.dmg_at(r)
	var tgt: Unit = a["target"]
	var dir: Vector2 = a["dir"]
	var point: Vector2 = a["point"]
	if dir != Vector2.ZERO:
		facing = dir
	match ab.id:
		# ---- Kestrel, the Dune Ranger ----
		&"piercing_bolt":
			arena.spawn_line(self, position + dir * radius, dir, ab.cast_range, ab.projectile_speed, ab.radius, dmg, "bolt", true)
		&"tumble":
			if root_t > 0.0:
				return false
			var d := _mobility_dir(a)
			_start_dash(d, ab.cast_range, ab.projectile_speed, {})
			empowered = ab.val_at(r)
			attack_cd = minf(attack_cd, 0.1)
		&"hawk_mark":
			if tgt == null or position.distance_to(tgt.position) > ab.cast_range + tgt.radius + 40.0:
				return false
			tgt.apply_mark(ab.duration, ab.val_at(r))
			arena.fx_beam(position, tgt.position, Color(1, 0.3, 0.3), 4.0)
			if is_player and not attack_command:
				command_attack(tgt)
		&"sky_volley":
			arena.spawn_area(self, "volley", point, ab.radius, {"duration": ab.duration, "tick": 0.5, "dmg": dmg, "slow": ab.val_at(r)})
		# ---- Morrow, the Mossback Warden ----
		&"shell_bash":
			if root_t > 0.0:
				return false
			var stun := ab.duration
			var bash_hit := func(u: Unit) -> void:
				u.take_damage(dmg, self)
				u.apply_stun(stun)
				arena.fx_ring(u.position, 10.0, 60.0, Color(1, 0.9, 0.4))
			_start_dash(dir, ab.cast_range, ab.projectile_speed, {"stop_on_hit": true, "on_hit": bash_hit})
		&"barkskin":
			add_shield(max_hp * ab.val_at(r), ab.duration)
			arena.fx_ring(position, radius, radius + 30.0, Color(0.6, 1.0, 0.5))
		&"rootcall_roar":
			for e in arena.enemies_in_radius(team, position, ab.radius, false):
				e.take_damage(dmg, self)
				e.apply_taunt(self, ab.duration)
			arena.fx_ring(position, 20.0, ab.radius, Color(1, 0.7, 0.3), 0.45, 6.0)
		&"landslide":
			if root_t > 0.0:
				return false
			var stun2 := ab.duration
			var wall_t := ab.val_at(r)
			var slide_hit := func(u: Unit) -> void:
				u.take_damage(dmg, self)
				u.apply_stun(stun2)
				arena.fx_ring(u.position, 10.0, 70.0, Color(0.9, 0.8, 0.6))
			var slide_end := func() -> void:
				arena.spawn_wall(self, position + facing * 70.0, facing.orthogonal(), wall_t)
			_start_dash(dir, ab.cast_range, ab.projectile_speed, {"width": ab.radius, "on_hit": slide_hit, "on_end": slide_end})
		# ---- Lumi Vesper, the Lantern Witch ----
		&"wisp_bolt":
			var rad := ab.radius
			var burst := func(u: Unit, _p: Projectile) -> void:
				for e in arena.enemies_in_radius(team, u.position, rad, false):
					e.take_damage(dmg, self)
				arena.fx_ring(u.position, 10.0, rad, Color(0.6, 0.95, 1.0))
			if tgt != null and position.distance_to(tgt.position) <= ab.cast_range + 60.0:
				arena.spawn_homing(self, tgt, 0.0, ab.projectile_speed, "wisp", dir * radius, burst)
			else:
				arena.spawn_line(self, position + dir * radius, dir, ab.cast_range, ab.projectile_speed, 26.0, 0.0, "wisp", false, burst)
		&"star_snare":
			arena.spawn_area(self, "snare", point, ab.radius, {"delay": ab.delay, "dmg": dmg, "root": ab.duration})
		&"lantern_hop":
			if root_t > 0.0:
				return false
			var d2 := _mobility_dir(a)
			var origin := position
			position += d2 * ab.cast_range
			arena.clamp_pos(self)
			facing = d2
			arena.spawn_area(self, "glow", origin, ab.radius, {"duration": ab.duration, "slow": ab.val_at(r)})
			arena.fx_ring(position, 10.0, 50.0, Color(0.7, 0.95, 1.0))
		&"night_bloom":
			arena.spawn_area(self, "bloom", point, ab.radius, {"delay": ab.delay, "dmg": dmg})
		# ---- Sable, the Ember Fox ----
		&"ember_dash":
			if root_t > 0.0:
				return false
			var d3 := dir
			var dist := ab.cast_range
			if tgt != null and position.distance_to(tgt.position) <= ab.cast_range + tgt.radius + 30.0:
				d3 = (tgt.position - position).normalized()
				dist = position.distance_to(tgt.position) + tgt.radius + 50.0
			elif not a["manual"]:
				return false
			var ember_hit := func(u: Unit) -> void:
				u.take_damage(dmg, self)
				arena.fx_slash(u.position, d3, u.radius + 16.0, Color(1, 0.5, 0.2))
				if not u.alive and u.kind == Kind.HERO:
					cds[slot] = 0.0
			_start_dash(d3, dist, ab.projectile_speed, {"on_hit": ember_hit})
		&"twin_fang":
			var rad2 := ab.radius
			var heal_pct := ab.val_at(r)
			_slash(dir, rad2, dmg, 0.0)
			var second := func() -> void:
				var t2 := best_skill_target(rad2)
				var d4 := (t2.position - position).normalized() if t2 != null else facing
				_slash(d4, rad2, dmg, heal_pct)
			timers.append({"t": 0.25, "f": second})
		&"smoke_veil":
			stealth_t = ab.duration
			haste_t = ab.duration
			haste_amt = ab.val_at(r)
			arena.fx_ring(position, 10.0, 90.0, Color(0.7, 0.7, 0.75), 0.5, 10.0)
		&"hundred_petals":
			var list: Array = arena.enemies_in_radius(team, position, ab.radius, false)
			if list.is_empty():
				return false
			var by_priority := func(x: Unit, y: Unit) -> bool:
				var sx := position.distance_to(x.position) - (3000.0 if x.kind == Kind.HERO else 0.0)
				var sy := position.distance_to(y.position) - (3000.0 if y.kind == Kind.HERO else 0.0)
				return sx < sy
			list.sort_custom(by_priority)
			var n := mini(list.size(), int(ab.val_at(r)))
			untargetable_t = 0.22 * n + 0.3
			for i in n:
				var uid: int = (list[i] as Unit).get_instance_id()
				var strike := func() -> void:
					var u2 = instance_from_id(uid)
					if valid(u2):
						var side := Vector2.from_angle(randf() * TAU)
						position = u2.position + side * (u2.radius + radius + 6.0)
						arena.clamp_pos(self)
						facing = -side
						u2.take_damage(dmg, self)
						arena.fx_slash(u2.position, -side, u2.radius + 18.0, Color(1, 0.6, 0.8))
						arena.sfx_at("hit", position)
				timers.append({"t": 0.08 + i * 0.22, "f": strike})
		_:
			push_warning("Unknown ability id: %s" % ab.id)
			return false
	return true


func _slash(d: Vector2, rad: float, dmg: float, heal_pct: float) -> void:
	var total := 0.0
	for e in arena.enemies_in_radius(team, position, rad, false):
		var rel: Vector2 = e.position - position
		if rel.length() < radius + e.radius + 12.0 or rel.normalized().dot(d) > 0.2:
			total += e.take_damage(dmg, self)
	if heal_pct > 0.0 and total > 0.0:
		heal(total * heal_pct)
		arena.fx_text(position + Vector2(0, -radius), "+%d" % int(total * heal_pct), Color(0.5, 1.0, 0.5), 15)
	arena.fx_slash(position + d * radius, d, rad * 0.7, Color(1, 0.45, 0.5))
	facing = d


func _start_dash(d: Vector2, dist: float, speed: float, opts: Dictionary) -> void:
	if d == Vector2.ZERO:
		d = facing
	dash = {"dir": d.normalized(), "left": dist, "speed": maxf(speed, 300.0), "hits": {}, "opts": opts}
	facing = d.normalized()
	has_move_point = false
	recall_t = 0.0


func _step_dash(dt: float) -> void:
	var dir: Vector2 = dash["dir"]
	var mv := minf(dash["left"], dash["speed"] * dt)
	var want := position + dir * mv
	position = want
	arena.clamp_pos(self)
	dash["left"] -= mv
	var stop := position.distance_to(want) > 1.0
	var opts: Dictionary = dash["opts"]
	if opts.has("on_hit"):
		var w: float = opts.get("width", radius)
		for u in arena.enemies_in_radius(team, position, w + 10.0, false):
			if dash["hits"].has(u):
				continue
			dash["hits"][u] = true
			(opts["on_hit"] as Callable).call(u)
			if opts.get("stop_on_hit", false):
				stop = true
				break
	if dash.is_empty():
		return
	if dash["left"] <= 0.5 or stop:
		var end_cb = opts.get("on_end")
		dash = {}
		if end_cb is Callable and (end_cb as Callable).is_valid():
			(end_cb as Callable).call()


# ---------------- drawing ----------------

func _draw() -> void:
	if not alive or arena == null:
		return
	var a := 1.0
	if stealth_t > 0.0:
		if arena.player == null or arena.player.team == team:
			a = 0.45
		else:
			a = 0.5 if mark_t > 0.0 else 0.0
	if untargetable_t > 0.0:
		a = minf(a, 0.55)
	if a <= 0.01:
		return
	if is_player and not aim_preview.is_empty():
		_draw_aim()
	var off := facing * 7.0 * (anim_t / 0.15) if anim_t > 0.0 else Vector2.ZERO
	draw_colored_polygon(Art.ellipse_pts(Vector2(0, radius * 0.75), radius * 1.05, radius * 0.42), Color(0, 0, 0, 0.25 * a))
	var ring_col := Art.PLAYER if is_player else Art.team_color(team)
	var ring := Art.ellipse_pts(Vector2(0, radius * 0.45), radius * 1.18, radius * 0.62, 28)
	ring.append(ring[0])
	draw_polyline(ring, Color(ring_col, 0.95 * a), 4.0, true)
	Art.draw_hero(self, data.id, off, radius, facing, a)
	if hit_flash > 0.0:
		draw_circle(off, radius, Color(1, 1, 1, 0.3 * a))
	if shield > 0.0:
		draw_arc(Vector2.ZERO, radius + 6.0, 0, TAU, 36, Color(1, 1, 1, 0.85 * a), 3.0, true)
	if recall_t > 0.0:
		var k := 1.0 - recall_t / arena.config.recall_time
		draw_arc(Vector2.ZERO, radius + 12.0, -PI / 2, -PI / 2 + TAU * k, 40, Color(0.5, 0.8, 1.0), 4.0, true)
	if empowered > 0.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU, 32, Color(1, 0.85, 0.3, 0.9), 2.5, true)
	draw_status(radius)
	var bw := 72.0
	var y := -radius - 24.0
	draw_hp_bar(y, bw, 8.0, ring_col)
	draw_rect(Rect2(-bw * 0.5, y + 10.0, bw, 3.0), Color(0.06, 0.07, 0.1, 0.9))
	draw_rect(Rect2(-bw * 0.5, y + 10.0, bw * mana / maxf(max_mana, 1.0), 3.0), Color("58a6ff"))
	var lc := Vector2(-bw * 0.5 - 11.0, y + 5.0)
	draw_circle(lc, 10.0, Color(0.08, 0.09, 0.13))
	draw_arc(lc, 10.0, 0, TAU, 20, ring_col, 2.0, true)
	draw_string(font, lc + Vector2(-10, 5), str(level), HORIZONTAL_ALIGNMENT_CENTER, 20, 13, Color.WHITE)
	var nm := "You" if is_player else display_name
	draw_string_outline(font, Vector2(-80, y - 6.0), nm, HORIZONTAL_ALIGNMENT_CENTER, 160, 14, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-80, y - 6.0), nm, HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color.WHITE)


func _draw_aim() -> void:
	var slot: int = aim_preview.get("slot", -1)
	if slot < 0 or slot >= data.abilities.size():
		return
	var ab: AbilityData = data.abilities[slot]
	var d: Vector2 = aim_preview.get("dir", Vector2.ZERO)
	var mag: float = aim_preview.get("mag", 1.0)
	var col := Color(1, 1, 1, 0.5) if not aim_preview.get("cancel", false) else Color(1, 0.3, 0.3, 0.5)
	draw_arc(Vector2.ZERO, ab.cast_range, 0, TAU, 72, Color(1, 1, 1, 0.18), 3.0, true)
	if d == Vector2.ZERO:
		return
	match ab.id:
		&"sky_volley", &"star_snare", &"night_bloom":
			var p := d * ab.cast_range * clampf(mag, 0.12, 1.0)
			draw_circle(p, ab.radius, Color(col, 0.18))
			draw_arc(p, ab.radius, 0, TAU, 48, col, 3.0, true)
		&"rootcall_roar", &"hundred_petals", &"barkskin", &"smoke_veil":
			draw_circle(Vector2.ZERO, ab.radius if ab.radius > 0.0 else radius + 20.0, Color(col, 0.15))
		_:
			var w := maxf(ab.radius, 22.0) if ab.id == &"piercing_bolt" or ab.id == &"landslide" else 22.0
			var e := d * ab.cast_range
			draw_line(d * radius, e, Color(col, 0.25), w * 2.0)
			draw_line(d * radius, e, col, 3.0)
			draw_colored_polygon(PackedVector2Array([e + d * 18.0, e + d.orthogonal() * 14.0, e - d.orthogonal() * 14.0]), col)
