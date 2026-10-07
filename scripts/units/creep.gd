class_name Creep
extends Unit
## Lane creep: walks the lane toward the enemy base and fights whatever enemy is closest.
## Prefers creeps and buildings; switches to an enemy hero who attacks an allied hero nearby.

var stats: UnitStats
var lane: PackedVector2Array
var wp := 1
var offset := Vector2.ZERO
var target: Unit = null
var forced_t := 0.0
var attack_cd := 0.0
var retarget_t := 0.0
var damage := 20.0
var attack_range := 50.0
var attack_interval := 1.0
var move_speed := 200.0
var aggro_range := 380.0
var is_siege := false
var is_ranged := false
var lunge_t := 0.0
var blocked_t := 0.0


func setup(s: UnitStats, t: int, a: Arena, lane_pts: PackedVector2Array, power_mult: float, siege := false) -> void:
	stats = s
	team = t
	arena = a
	kind = Kind.CREEP
	display_name = s.display_name
	var minutes := a.time / 60.0
	max_hp = s.max_hp * (1.0 + s.hp_growth_per_min * minutes) * power_mult
	hp = max_hp
	armor = s.armor
	radius = s.radius
	damage = s.damage * (1.0 + s.damage_growth_per_min * minutes) * power_mult
	attack_range = s.attack_range
	attack_interval = s.attack_interval
	move_speed = s.move_speed
	aggro_range = s.aggro_range
	bounty_gold = s.gold_bounty
	bounty_xp = s.xp_bounty
	is_ranged = s.ranged
	is_siege = siege
	lane = lane_pts
	wp = 1
	attack_cd = randf() * 0.3


func force_target(u: Unit, t: float) -> void:
	if valid(u) and u.is_targetable_by(team):
		target = u
		forced_t = t


func step(dt: float) -> void:
	tick_status(dt)
	attack_cd -= dt
	retarget_t -= dt
	forced_t -= dt
	lunge_t = maxf(0.0, lunge_t - dt)
	if stun_t > 0.0:
		return
	if taunt_t > 0.0 and valid(taunt_src):
		target = taunt_src
	elif retarget_t <= 0.0:
		retarget_t = 0.25 + randf() * 0.1
		_acquire()
	if valid(target) and target.is_targetable_by(team):
		var d := position.distance_to(target.position)
		var reach := attack_range + radius + target.radius
		if d <= reach:
			if attack_cd <= 0.0:
				_attack(target)
		elif d > aggro_range * 1.7 and taunt_t <= 0.0:
			_drop_target()
		else:
			_move_to(target.position, dt)
	else:
		if target != null:
			_drop_target()
		_follow_lane(dt)


func _drop_target() -> void:
	target = null
	# Resume the lane from the nearest waypoint ahead.
	var best := wp
	var bd := INF
	for i in range(maxi(1, wp - 2), mini(lane.size(), wp + 6)):
		var d := position.distance_squared_to(lane[i])
		if d < bd:
			bd = d
			best = i
	wp = clampi(best, 1, lane.size() - 1)


func _acquire() -> void:
	if forced_t > 0.0 and valid(target) and target.is_targetable_by(team):
		return
	if valid(target) and target.is_targetable_by(team) and target.kind != Kind.HERO \
			and position.distance_to(target.position) < aggro_range * 1.2:
		return
	var best: Unit = null
	var best_score := INF
	for u in arena.units:
		if not u.alive or u.team == team or u.kind == Kind.NEUTRAL:
			continue
		if not u.is_targetable_by(team):
			continue
		var d := position.distance_to(u.position) - u.radius
		if d > aggro_range:
			continue
		var score := d
		if u.kind == Kind.HERO:
			score += 260.0
		elif u.kind == Kind.STRUCTURE:
			score += 60.0
		if score < best_score:
			best_score = score
			best = u
	target = best


func _attack(t: Unit) -> void:
	attack_cd = attack_interval
	lunge_t = 0.15
	var dmg := damage
	if t.kind == Kind.STRUCTURE:
		dmg *= stats.structure_damage_mult
	if is_ranged:
		arena.spawn_homing(self, t, dmg, stats.projectile_speed, "siege" if is_siege else "creep")
	else:
		t.take_damage(dmg, self, false, false)


func _move_to(p: Vector2, dt: float) -> void:
	if root_t > 0.0:
		return
	var v := p - position
	var l := v.length()
	if l < 1.0:
		return
	position += v / l * minf(l, move_speed * speed_mult() * dt)


func _follow_lane(dt: float) -> void:
	if wp >= lane.size():
		return
	var goal := lane[wp] + offset
	if position.distance_to(goal) < 45.0 or (wp < lane.size() - 1 and position.distance_to(lane[wp + 1]) < lane[wp].distance_to(lane[wp + 1])):
		if wp < lane.size() - 1:
			wp += 1
			goal = lane[wp] + offset
		else:
			return
	var before := position
	_move_to(goal, dt)
	# Blocked (crowd / building)? Skip ahead to the next waypoint.
	if position.distance_to(before) < move_speed * dt * 0.2 and root_t <= 0.0 and slow_amt < 0.6:
		blocked_t += dt
		if blocked_t > 0.6 and wp < lane.size() - 1:
			wp += 1
			blocked_t = 0.0
	else:
		blocked_t = 0.0


func _on_death(_killer: Unit) -> void:
	pass


func _draw() -> void:
	var tc := Art.team_color(team)
	var dark := Art.team_dark(team)
	var lunge := Vector2.ZERO
	if lunge_t > 0.0 and valid(target):
		lunge = (target.position - position).normalized() * 5.0 * (lunge_t / 0.15)
	draw_colored_polygon(Art.ellipse_pts(Vector2(0, radius * 0.6), radius * 1.0, radius * 0.45, 16), Color(0, 0, 0, 0.22))
	var col := tc.lerp(Color.WHITE, 0.6) if hit_flash > 0.0 else tc
	if is_siege:
		var r := radius
		draw_rect(Rect2(lunge + Vector2(-r, -r), Vector2(r * 2, r * 2)), dark)
		draw_rect(Rect2(lunge + Vector2(-r + 4, -r + 4), Vector2(r * 2 - 8, r * 2 - 8)), col)
		draw_circle(lunge, r * 0.38, Color(1, 1, 1, 0.9))
	else:
		draw_circle(lunge, radius, dark)
		draw_circle(lunge, radius - 2.5, col)
		draw_circle(lunge + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.3, Color(1, 1, 1, 0.45))
		if is_ranged:
			draw_circle(lunge, radius * 0.35, Color(1, 1, 1, 0.95))
	if hp < max_hp:
		draw_hp_bar(-radius - 10, radius * 2.2, 4, tc.lightened(0.1) if team == 0 else tc)
	draw_status(radius)
