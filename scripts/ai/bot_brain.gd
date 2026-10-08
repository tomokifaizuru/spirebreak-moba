class_name BotBrain
extends RefCounted
## Bot AI shared by every bot hero (and your hero on autopilot). Each "think" picks one of:
##   RETREAT  low HP -> escape skills, heal, recall or walk to the fountain/shrine
##   ESCAPE   standing under an enemy tower without creeps to tank -> step back along the lane
##   FIGHT    an enemy hero in reach and the fight looks winnable -> skills + attacks
##   FARM     enemy creeps nearby -> last-hit / clear the wave
##   PUSH     a vulnerable enemy building and creeps tanking it -> hit the building
##   LANE     otherwise walk to a spot just behind the allied creep wave
## Supports (Calla) also heal / shield hurt allies first and follow a teammate instead of the wave.

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
## Match time of the last "go home to shop" recall.
var last_shop_trip := -999.0


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
	try_shop()
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
	if _support_actions():
		return
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
		_try_blink_engage(t)
		_use_skills(t)
		h.command_attack(t)
		return
	if enemies.is_empty() and _want_shop_trip(hpf):
		last_shop_trip = a.time
		state = "shop"
		h.start_recall()
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
	var camp := _pick_camp()
	if camp != null:
		state = "jungle"
		h.command_attack(camp)
		return
	var s := a.attackable_structure_near(h, h.attack_range + (900.0 if pushing else 420.0))
	if s != null and _structure_safe(s):
		state = "push"
		h.command_attack(s)
		return
	state = "lane"
	h.command_move(_lane_spot())


# ---------------- items ----------------

## True if `it` (or an upgrade built from it) is already in the inventory.
func _has_or_built(it: ItemData) -> bool:
	for x in hero.items:
		if _contains(x, it):
			return true
	return false


func _contains(root: ItemData, it: ItemData) -> bool:
	if root.id == it.id:
		return true
	for c in root.components:
		if c != null and _contains(c as ItemData, it):
			return true
	return false


## Next item: the hero's recommended build (data/builds) first, then the role build order.
func next_item() -> ItemData:
	var cat: ItemCatalog = hero.arena.config.item_catalog
	if cat == null:
		return null
	var order: Array[ItemData] = []
	for b in hero.arena.config.recommended_builds:
		if b != null and b.hero == hero.data:
			order.append_array(b.items)
	order.append_array(cat.build_for(hero.data.role))
	for it in order:
		if it == null or _has_or_built(it):
			continue
		if Shop.block_reason(hero, it, false) == "Inventory full":
			continue
		return it
	return null


## Buys as much of the build as the hero can afford (only works at base / while dead).
func try_shop() -> void:
	var h := hero
	if not Shop.can_shop_here(h):
		return
	for i in 4:
		var it := next_item()
		if it == null or not Shop.buy(h, it):
			return


## Go home to spend a big pile of gold (only when the lane is quiet).
func _want_shop_trip(hpf: float) -> bool:
	var h := hero
	var a := _arena()
	if a.time - last_shop_trip < 50.0 or h.position.distance_to(h.fountain) < 1800.0:
		return false
	var it := next_item()
	if it == null:
		return false
	var price := Shop.price_for(h, it)
	if price < 600 or h.gold < price:
		return false
	return hpf < 0.85 or h.gold >= price + 500


## Melee divers blink onto a fight target that is just out of reach.
func _try_blink_engage(t: Hero) -> void:
	var h := hero
	if not h.can_use_item() or randf() > skill_chance:
		return
	var it := h.active_item()
	var role := h.data.role
	if role != 0 and role != 3 and role != 5:
		return
	var d := h.position.distance_to(t.position)
	if d < h.attack_range + 220.0 or d > it.active_range + h.attack_range:
		return
	if h.hp_frac() < 0.5 or (role != 0 and t.hp_frac() > 0.7):
		return
	var dest := t.position - (t.position - h.position).normalized() * maxf(h.attack_range * 0.6, 40.0)
	if _arena().enemy_tower_covering(h.team, dest, 60.0) != null:
		return
	h.use_item({"point": dest})


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
		if pushing and hero.data.is_frontline() and hero.hp_frac() > 0.55:
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


## A jungle camp worth taking: the lane wave is not here, the camp is on our half (or the river
## camps once we are pushing), and nothing dangerous is standing on it.
func _pick_camp() -> Unit:
	var h := hero
	var a := _arena()
	if h.data.role == 4:
		return null  # the support stays with the team
	var front: float = a.fronts[h.team]
	var our_p := a.team_progress(h.team, h.position)
	# Only wander off when the wave is pushed past us (or there is no wave yet).
	if front >= 0.0 and front < our_p + 500.0:
		return null
	var best: Unit = null
	var bd := INF
	for u in a.neutrals:
		if not u.alive:
			continue
		var d := h.position.distance_to(u.position)
		if d > 1500.0 or d >= bd:
			continue
		var camp_p := a.team_progress(h.team, u.position)
		# Stay on our side of the map unless we are already pushing their towers.
		if camp_p > a.lane_len * 0.55 and not pushing:
			continue
		if a.enemy_tower_covering(h.team, u.position, 60.0) != null:
			continue
		if not a.heroes_near(u.position, 750.0, h.team, true).is_empty():
			continue
		if u.max_hp > 800.0 and (h.level < 5 or h.hp_frac() < 0.7):
			continue  # the big camp needs a few levels
		if u.target == null and h.hp_frac() < 0.55:
			continue
		bd = d
		best = u
	return best


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
			&"petal_mend", &"bloom_ward":
				pass  # handled by _support_actions()
			&"spring_chorus":
				var hurt := 0
				for x in a.heroes_near(h.position, ab.radius, h.team, false):
					if (x as Hero).hp_frac() < 0.7:
						hurt += 1
				var foes := a.heroes_near(h.position, ab.radius, h.team, true).size()
				if hurt >= 2 or (hurt >= 1 and foes >= 2):
					used = h.cast(slot)
			&"quake_swing":
				if d < ab.radius + t.radius:
					used = _cast_on(slot, t)
			&"iron_leap":
				if (d > h.attack_reach(t) + 40.0 and d < ab.cast_range + 40.0) or (t.hp_frac() < 0.3 and d < ab.cast_range):
					used = _cast_on(slot, t)
			&"battle_hunger":
				if d < h.attack_reach(t) + 80.0:
					used = h.cast(slot)
			&"anvil_fall":
				var crowd2 := a.heroes_near(t.position, ab.radius + 40.0, h.team, true).size()
				if d < ab.cast_range and (t.hp_frac() < 0.55 or crowd2 >= 2):
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
		if id in [&"piercing_bolt", &"wisp_bolt", &"star_snare", &"twin_fang", &"lullaby", &"quake_swing"]:
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
			if id == &"tumble" or id == &"lantern_hop" or id == &"iron_leap":
				if h.cast(slot, {"dir": away}):
					break
			elif id == &"lullaby" and closest != null:
				if h.cast(slot, {"target": closest}):
					break
			elif id == &"smoke_veil" or id == &"barkskin":
				if h.cast(slot):
					break
	if closest != null and cd < 420.0 and h.hp_frac() < 0.4 and h.can_use_item():
		h.use_item({"dir": home_dir if cd > 250.0 else ((h.position - closest.position).normalized() + home_dir).normalized()})
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


## Support only: heal / shield a hurt ally (or yourself). Returns true if a skill was used.
func _support_actions() -> bool:
	var h := hero
	if h.data.role != 4:
		return false
	for slot in [0, 1, 2]:
		if not h.can_cast(slot) or randf() > skill_chance + 0.1:
			continue
		var ab: AbilityData = h.data.abilities[slot]
		if ab.id == &"petal_mend":
			var t := _hurt_ally(ab.cast_range, 0.62, false)
			if t != null and h.cast(slot, {"target": t}):
				return true
		elif ab.id == &"bloom_ward":
			var t2 := _hurt_ally(ab.cast_range, 0.8, true)
			if t2 != null and h.cast(slot, {"target": t2}):
				return true
	return false


## Most wounded allied hero (you included) in range below `below` HP. under_fire = hit in the last 1.2 s.
func _hurt_ally(rng: float, below: float, under_fire: bool) -> Hero:
	var a := _arena()
	var best: Hero = null
	var bf := below
	for x in a.heroes_near(hero.position, rng, hero.team, false):
		var u: Hero = x
		if under_fire and a.time - u.last_hurt_time > 1.2:
			continue
		if u.hp_frac() < bf:
			bf = u.hp_frac()
			best = u
	return best


## Support only: the teammate to stay with (alive, not going home), else null.
func _buddy() -> Hero:
	var a := _arena()
	var best: Hero = null
	var bd := 2600.0
	for x in a.heroes:
		var u: Hero = x
		if u == hero or not u.alive or u.team != hero.team or u.brain.retreating:
			continue
		var d := hero.position.distance_to(u.position)
		if u.brain.state == "fight":
			d -= 800.0
		if d < bd:
			bd = d
			best = u
	return best


func _lane_spot() -> Vector2:
	var h := hero
	var a := _arena()
	if h.data.role == 4:
		var b := _buddy()
		if b != null:
			# Stand a little behind the teammate (towards our base).
			var bp := a.team_progress(h.team, b.position)
			return a.lane_point(h.team, bp - 140.0) + (b.position - a.lane_point(h.team, bp)) * 0.5
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
