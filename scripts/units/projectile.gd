class_name Projectile
extends Node2D
## Homing shot (basic attacks, towers, Wisp Bolt) or straight line shot (Piercing Bolt).

var arena: Arena
var source: Unit
var team := 0
var target: Unit = null
var homing := true
var dir := Vector2.RIGHT
var speed := 900.0
var damage := 0.0
var max_dist := 600.0
var traveled := 0.0
var width := 24.0
var pierce := false
var hits := {}
var style := "creep"
var on_hit: Callable
var done := false
var trail: Array[Vector2] = []


func src() -> Unit:
	return source if (source != null and is_instance_valid(source)) else null


func step(dt: float) -> void:
	if done:
		return
	if homing:
		if target == null or not is_instance_valid(target) or not target.alive:
			finish()
			return
		var to := target.position - position
		var l := to.length()
		var mv := speed * dt
		dir = to / maxf(l, 0.001)
		if l <= mv + target.radius * 0.5:
			position = target.position
			_hit(target)
			finish()
			return
		position += dir * mv
	else:
		var mv2 := speed * dt
		position += dir * mv2
		traveled += mv2
		for u in arena.units:
			if not u.alive or u.team == team or u.kind == Unit.Kind.STRUCTURE or hits.has(u):
				continue
			if not u.is_targetable_by(team):
				continue
			if position.distance_to(u.position) <= width + u.radius:
				hits[u] = true
				_hit(u)
				if not pierce:
					finish()
					return
		if traveled >= max_dist:
			finish()
	if not arena.headless:
		trail.push_front(position)
		if trail.size() > 6:
			trail.pop_back()


func _hit(u: Unit) -> void:
	if on_hit.is_valid():
		on_hit.call(u, self)
	else:
		u.take_damage(damage, src(), false, true)


func finish() -> void:
	done = true
	arena.remove_fx(self)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var tc := Art.team_color(team)
	var back := -dir
	match style:
		"arrow":
			draw_line(back * 26.0, Vector2.ZERO, Color("6b3b1a"), 3.0)
			draw_colored_polygon(PackedVector2Array([dir * 8.0, dir.orthogonal() * 5.0 - dir * 4.0, -dir.orthogonal() * 5.0 - dir * 4.0]), Color("ffe2a0"))
		"bolt":
			draw_line(back * 60.0, Vector2.ZERO, Color(1.0, 0.85, 0.4, 0.45), 14.0)
			draw_line(back * 50.0, Vector2.ZERO, Color("fff2c0"), 5.0)
			draw_colored_polygon(PackedVector2Array([dir * 16.0, dir.orthogonal() * 9.0 - dir * 6.0, -dir.orthogonal() * 9.0 - dir * 6.0]), Color.WHITE)
		"orb":
			draw_circle(Vector2.ZERO, 11.0, Color(0.7, 0.5, 1.0, 0.35))
			draw_circle(Vector2.ZERO, 6.0, Color("d9c8ff"))
		"wisp":
			for i in trail.size():
				draw_circle(trail[i] - position, 10.0 - i * 1.3, Color(0.55, 0.95, 1.0, 0.35 - i * 0.05))
			draw_circle(Vector2.ZERO, 13.0, Color(0.55, 0.95, 1.0, 0.45))
			draw_circle(Vector2.ZERO, 7.0, Color.WHITE)
		"tower":
			for i in trail.size():
				draw_circle(trail[i] - position, 9.0 - i, Color(tc, 0.3 - i * 0.04))
			draw_circle(Vector2.ZERO, 11.0, Color(tc, 0.5))
			draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
		"siege":
			draw_circle(Vector2.ZERO, 9.0, Color(0.15, 0.15, 0.2))
			draw_circle(Vector2.ZERO, 5.0, tc)
		_:
			draw_circle(Vector2.ZERO, 5.0, tc.lightened(0.4))
			draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
