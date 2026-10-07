class_name NeutralMob
extends Unit
## Jungle camp monster. Stays home until attacked, chases a short way, then walks back and heals.

var stats: UnitStats
var home := Vector2.ZERO
var target: Unit = null
var attack_cd := 0.0
var returning := false
var leash := 480.0
var camp_index := -1


func setup(s: UnitStats, a: Arena, pos: Vector2) -> void:
	stats = s
	arena = a
	team = NEUTRAL_TEAM
	kind = Kind.NEUTRAL
	display_name = s.display_name
	max_hp = s.max_hp
	hp = max_hp
	armor = s.armor
	radius = s.radius
	bounty_gold = s.gold_bounty
	bounty_xp = s.xp_bounty
	home = pos
	position = pos


func _on_damaged(src: Unit, _amount: float) -> void:
	if src != null and src.kind == Kind.HERO and not returning:
		target = src
		# Camp-mates join in.
		for u in arena.neutrals:
			if u != self and u.alive and u.camp_index == camp_index and u.target == null:
				u.target = src


func step(dt: float) -> void:
	tick_status(dt)
	attack_cd -= dt
	if stun_t > 0.0:
		return
	if returning:
		_move_to(home, dt, 1.4)
		heal(max_hp * 0.2 * dt)
		if position.distance_to(home) < 10.0:
			returning = false
		return
	if valid(target) and target.is_targetable_by(team):
		if position.distance_to(home) > leash:
			target = null
			returning = true
			return
		var reach := stats.attack_range + radius + target.radius
		if position.distance_to(target.position) <= reach:
			if attack_cd <= 0.0:
				attack_cd = stats.attack_interval
				target.take_damage(stats.damage, self, false, true)
		else:
			_move_to(target.position, dt)
	else:
		target = null
		if position.distance_to(home) > 12.0:
			returning = true


func _move_to(p: Vector2, dt: float, mult := 1.0) -> void:
	if root_t > 0.0:
		return
	var v := p - position
	var l := v.length()
	if l < 1.0:
		return
	position += v / l * minf(l, stats.move_speed * speed_mult() * mult * dt)


func _draw() -> void:
	draw_colored_polygon(Art.ellipse_pts(Vector2(0, radius * 0.6), radius * 1.1, radius * 0.5, 16), Color(0, 0, 0, 0.22))
	var col := Color("b5c94a") if hit_flash <= 0.0 else Color("f0ffb0")
	draw_circle(Vector2.ZERO, radius, Color("5f6b22"))
	draw_circle(Vector2.ZERO, radius - 3, col)
	draw_circle(Vector2(-radius * 0.35, -radius * 0.15), radius * 0.2, Color.WHITE)
	draw_circle(Vector2(radius * 0.35, -radius * 0.15), radius * 0.2, Color.WHITE)
	draw_circle(Vector2(-radius * 0.32, -radius * 0.1), radius * 0.1, Color.BLACK)
	draw_circle(Vector2(radius * 0.38, -radius * 0.1), radius * 0.1, Color.BLACK)
	draw_colored_polygon(PackedVector2Array([Vector2(-radius * 0.7, -radius * 0.6), Vector2(-radius * 0.4, -radius * 1.3), Vector2(-radius * 0.15, -radius * 0.75)]), Color("5f6b22"))
	draw_colored_polygon(PackedVector2Array([Vector2(radius * 0.7, -radius * 0.6), Vector2(radius * 0.4, -radius * 1.3), Vector2(radius * 0.15, -radius * 0.75)]), Color("5f6b22"))
	if hp < max_hp:
		draw_hp_bar(-radius - 14, radius * 2.4, 5, Color("e0c83a"))
	draw_status(radius)
