class_name BotBrain
extends RefCounted
## Bot AI shared by every bot hero (and your hero on autopilot). Each "think" picks one of:
##   RETREAT  low HP -> escape skills, heal, recall or walk to the fountain/shrine
##   ESCAPE   standing under an enemy tower without creeps to tank -> step back along the lane
##   FIGHT    an enemy hero in reach and the fight looks winnable -> skills + attacks
##   FARM     enemy creeps nearby -> last-hit / clear the wave
##   PUSH     a vulnerable enemy building and creeps tanking it -> hit the building
##   LANE     otherwise walk to a spot just behind the allied creep wave

var hero: Hero
var think_t := 0.0
var retreating := false
var fight_target: Hero = null
var fight_lock_t := 0.0
var lane_bias := 0.0
var state := "lane"
## True while the team has the upper hand: bots march on the next enemy building.
var pushing := false
## Seconds between decisions (lower = sharper bot).
var react := 0.25
## Chance to use a skill when it would make sense.
var skill_chance := 0.8


func _init(h: Hero) -> void:
	hero = h
	lane_bias = randf_range(-70.0, 70.0)


func setup_difficulty(d: int) -> void:
	var dd := clampi(d, 0, 2)
	react = [0.45, 0.25, 0.14][dd]
	skill_chance = [0.45, 0.8, 1.0][dd]


func think(dt: float) -> void:
	think_t -= dt
	fight_lock_t -= dt
	if think_t > 0.0:
		return
	think_t = react * randf_range(0.7, 1.3)
	_decide()


func _arena() -> Arena:
	return hero.arena


func _decide() -> void:
	var h := hero
	var a := _arena()
	h.input_move = Vector2.ZERO
	var hpf := h.hp_frac()
	var enemies := a.heroes_near(h.position, 950.0, h.team, true)
	var allies := a.heroes_near(h.position, 950.0, h.team, false)
	if h.recall_t > 0.0:
		if a.enemies_in_radius(h.team, h.position, 650.0, false).is_empty():
			return
		h.cancel_recall()
	if hpf < 0.3 and h.heal_cd <= 0.0 and not enemies.is_empty():
		h.cast_heal()
		hpf = h.hp_frac()
	var at_base := h.position.distance_to(h.fountain) < a.config.fountain_radius * 0.8
	var enemies_alive := a.alive_heroes(1 - h.team)
	var advantage := a.alive_heroes(h.team) - enemies_alive
	if retreating:
		# Enemy team wiped (or outnumbered by 2): turn around and finish the push instead.
		if advantage >= 2 and hpf > 0.4 and a.enemy_tower_threatening(h, 0.0) == null:
			retreating = false
		elif (hpf >= 0.92 and h.mana >= h.max_mana * 0.45) or (at_base and hpf >= 0.97):
			retreating = false
	else:
		var threat := _threat(enemies, allies)
		var retreat_hp := h.data.bot_retreat_hp * (0.6 if advantage >= 2 else 1.0)
		if hpf < retreat_hp or (hpf < 0.5 and threat > 1.5) \
				or (h.mana < h.max_mana * 0.1 and hpf < 0.55 and not enemies.is_empty()):
			retreating = true
	if retreating:
		state = "retreat"
		_retreat(enemies)
		return
	pushing = _should_push(allies)
	var tower := a.enemy_tower_threatening(h, 50.0)
	if tower != null and not _tower_safe(tower):
		state = "escape"
		_step_back()
		return
	var t := _pick_fight_target(enemies, allies)
	if t != null:
		state = "fight"
		_use_skills(t)
		h.command_attack(t)
		return
	if pushing:
		var s2 := a.attackable_structure_near(h, h.attack_range + 900.0)
		if s2 != null and _structure_safe(s2):
			state = "push"
			h.command_attack(s2)
			return
	var c := _pick_creep()
	if c != null:
		state = "farm"
		_use_wave_skills(c)
		h.command_attack(c)
		return
	var s := a.attackable_structure_near(h, h.attack_range + (900.0 if pushing else 420.0))
	if s != null and _structure_safe(s):
		state = "push"
		h.command_attack(s)
		return
	state = "lane"
	h.command_move(_lane_spot())


func _power(list: Array) -> float:
	var p := 0.0
	for x in list:
		var u: Hero = x
		p += u.hp + u.attack_damage * 8.0 + u.level * 40.0
	return p


func _threat(enemies: Array, allies: Array) -> float:
	if enemies.is_empty():
		return 0.0
	var mine := _power(allies) + _power([hero])
	return _power(enemies) / maxf(mine, 1.0)


func _should_push(allies: Array) -> bool:
	var a := _arena()
	var mine := a.alive_heroes(hero.team)
	var theirs := a.alive_heroes(1 - hero.team)
	if theirs == 0:
		return true
	if mine - theirs >= 2:
		return true
	if mine - theirs >= 1 and a.time > 300.0:
		return true
	# Late game: group up and go when healthy.
	return a.time > 480.0 and mine >= theirs and hero.hp_frac() > 0.6 and allies.size() >= 1


func _tower_safe(s: Structure) -> bool:
	if s.target == hero:
		if pushing and hero.data.role == 0 and hero.hp_frac() > 0.55:
			return true
		return s.hp_frac() < 0.1 and hero.hp_frac() > 0.55
	if pushing and hero.hp_frac() > 0.45:
		return true
	var a := _arena()
	var n := a.count_creeps_near(s.position, s.attack_range + s.radius, hero.team)
	if n >= 2:
		return true
	return n >= 1 and s.target != null and s.target.kind == Unit.Kind.CREEP


func _structure_safe(s: Structure) -> bool:
	if s.stats == null or s.stats.damage <= 0.0:
		return true
	return _tower_safe(s)


func _step_back() -> void:
	var a := _arena()
	var p := a.team_progress(hero.team, hero.position)
	hero.command_move(a.lane_point(hero.team, p - 380.0))


func _pick_fight_target(enemies: Array, allies: Array) -> Hero:
	if enemies.is_empty():
		return null
	var h := hero
	var a := _arena()
	var engage := maxf(h.attack_reach(enemies[0]) + 230.0, 520.0)
	var t: Hero = null
	if fight_lock_t > 0.0 and fight_target != null and fight_target.alive and fight_target.is_targetable_by(h.team) \
			and h.position.distance_to(fight_target.position) <= engage + 120.0:
		t = fight_target
	else:
		var best := INF
		for x in enemies:
			var e: Hero = x
			var d := h.position.distance_to(e.position)
			if d > engage:
				continue
			var score := e.hp_frac() * 600.0 + d
			if score < best:
				best = score
				t = e
	if t == null:
		return null
	var mine := _power(a.heroes_near(t.position, 900.0, h.team, false)) + _power([h])
	var theirs := _power(a.heroes_near(t.position, 900.0, h.team, true))
	var own_tower := a.own_tower_covering(h.team, t.position)
	if own_tower != null:
		mine += 1500.0
	var ok := mine * h.data.bot_aggression >= theirs * 0.85 or t.hp < _burst(t) or t.hp_frac() < 0.22
	var tw := a.enemy_tower_covering(h.team, t.position, 40.0)
	if tw != null and not _tower_safe(tw):
		var dive := t.hp_frac() < 0.25 and h.hp_frac() > 0.6
		if not dive:
			ok = ok and h.position.distance_to(t.position) <= h.attack_reach(t) and a.enemy_tower_threatening(h, 30.0) == null
	if not ok:
		return null
	fight_target = t
	fight_lock_t = 1.2
	return t


func _burst(t: Unit) -> float:
	var b := hero.attack_damage * 3.0
	for i in 4:
		if hero.can_cast(i) and i < hero.data.abilities.size():
			b += hero.data.abilities[i].dmg_at(hero.ranks[i])
	return b * 100.0 / (100.0 + t.armor)


func _pick_creep() -> Unit:
	var h := hero
	var a := _arena()
	var reach := h.attack_range + h.radius + 320.0
	var best: Unit = null
	var best_score := INF
	for u in a.units:
		if not u.alive or u.team == h.team or u.kind != Unit.Kind.CREEP or not u.is_targetable_by(h.team):
			continue
		var d := h.position.distance_to(u.position) - u.radius
		if d > reach:
			continue
		var tw := a.enemy_tower_covering(h.team, u.position, h.attack_range * 0.5)
		if tw != null and not _tower_safe(tw):
			continue
		var score := u.hp + d * 0.4
		if u.hp <= h.attack_damage * 1.05:
			score -= 2000.0
		if score < best_score:
			best_score = score
			best = u
	return best


func _cast_on(slot: int, t: Unit) -> bool:
	return hero.cast(slot, {"target": t})


func _use_skills(t: Hero) -> void:
	var h := hero
	var a := _arena()
	var d := h.position.distance_to(t.position)
	for slot in [3, 0, 1, 2]:
		if not h.can_cast(slot) or randf() > skill_chance:
			continue
		var ab: AbilityData = h.data.abilities[slot]
		var used := false
		match ab.id:
			&"barkskin":
				if h.hp_frac() < 0.85 and a.time - h.last_hurt_time < 1.5:
					used = h.cast(slot)
			&"tumble":
				if d < 230.0:
					used = h.cast(slot, {"dir": (h.position - t.position).normalized().rotated(randf_range(-0.7, 0.7))})
				elif d > h.attack_reach(t) and d < h.attack_reach(t) + 200.0 and t.hp_frac() < 0.4:
					used = h.cast(slot, {"dir": (t.position - h.position).normalized()})
			&"lantern_hop":
				if h.hp_frac() < 0.5 and d < 320.0:
					used = h.cast(slot, {"dir": (h.position - t.position).normalized()})
			&"smoke_veil":
				if (h.hp_frac() < 0.35 and d < 400.0) or (d > 260.0 and d < 560.0 and t.hp_frac() < 0.5):
					used = h.cast(slot)
			&"rootcall_roar":
				if d < ab.radius * 0.85:
					used = h.cast(slot)
			&"twin_fang":
				if d < ab.radius + t.radius:
					used = _cast_on(slot, t)
			&"hundred_petals":
				var near := a.heroes_near(h.position, ab.radius, h.team, true).size()
				if d < ab.radius and (t.hp_frac() < 0.6 or near >= 2):
					used = h.cast(slot)
			&"landslide", &"night_bloom", &"sky_volley":
				var crowd := a.heroes_near(t.position, ab.radius + 60.0, h.team, true).size()
				if d < ab.cast_range and (t.hp_frac() < 0.65 or crowd >= 2):
					used = _cast_on(slot, t)
			&"hawk_mark":
				if d < ab.cast_range:
					used = _cast_on(slot, t)
			_:
				if d < ab.cast_range + t.radius:
					used = _cast_on(slot, t)
		if used:
			return


func _use_wave_skills(c: Unit) -> void:
	var h := hero
	if h.mana < h.max_mana * 0.55 or randf() > skill_chance * 0.5:
		return
	var a := _arena()
	if a.count_creeps_near(c.position, 260.0, 1 - h.team) < 3:
		return
	for slot in [0, 1, 2]:
		if not h.can_cast(slot):
			continue
		var id: StringName = h.data.abilities[slot].id
		if id in [&"piercing_bolt", &"wisp_bolt", &"star_snare", &"twin_fang"]:
			if h.position.distance_to(c.position) <= h.data.abilities[slot].cast_range:
				if _cast_on(slot, c):
					return


func _retreat(enemies: Array) -> void:
	var h := hero
	var a := _arena()
	var closest: Hero = null
	var cd := INF
	for x in enemies:
		var e: Hero = x
		var d := h.position.distance_to(e.position)
		if d < cd:
			cd = d
			closest = e
	var home_dir := (h.fountain - h.position).normalized()
	if closest != null and cd < 480.0:
		var away := ((h.position - closest.position).normalized() + home_dir).normalized()
		for slot in [0, 1, 2]:
			if not h.can_cast(slot):
				continue
			var id: StringName = h.data.abilities[slot].id
			if id == &"tumble" or id == &"lantern_hop":
				if h.cast(slot, {"dir": away}):
					break
			elif id == &"smoke_veil" or id == &"barkskin":
				if h.cast(slot):
					break
	var danger := not a.enemies_in_radius(h.team, h.position, 700.0, false).is_empty() \
			or a.enemy_tower_threatening(h, 150.0) != null
	if not danger and h.position.distance_to(h.fountain) > 1600.0:
		h.start_recall()
		return
	var sp := a.shrine_pos
	if a.shrine_ready() and h.position.distance_to(sp) < h.position.distance_to(h.fountain) * 0.5 \
			and h.position.distance_to(sp) < 1300.0:
		h.command_move(sp)
	else:
		h.command_move(h.fountain)


func _lane_spot() -> Vector2:
	var h := hero
	var a := _arena()
	var ranged := h.data.ranged_attack
	var front: float = a.fronts[h.team]
	var spot := 0.0
	if front >= 0.0:
		spot = front - (190.0 if ranged else 70.0)
	else:
		spot = a.outermost_tower_progress(h.team) - 180.0
	if pushing:
		# March to just outside the next enemy building and wait for the wave there.
		var target_p := a.lane_len - a.outermost_tower_progress(1 - h.team) - 520.0
		spot = maxf(spot, target_p)
	spot = clampf(spot, 250.0, a.lane_len - 250.0)
	var p := a.lane_point(h.team, spot)
	var tangent := a.lane_point(h.team, spot + 20.0) - p
	return p + tangent.normalized().orthogonal() * lane_bias
