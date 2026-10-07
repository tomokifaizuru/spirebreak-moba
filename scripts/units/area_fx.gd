class_name AreaFx
extends Node2D
## Ground effects from skills: Sky Volley rain, Star Snare, Night Bloom, Lantern glow, rock walls.

var arena: Arena
var source: Unit
var team := 0
var kind := "volley"
var radius := 100.0
var duration := 1.0
var delay := 0.0
var t := 0.0
var tick := 0.5
var tick_t := 0.0
var dmg := 0.0
var slow := 0.0
var root_dur := 0.0
## Spring Chorus: heal per tick for allied heroes inside.
var heal_amt := 0.0
## The area moves with this unit (Spring Chorus follows Calla).
var follow: Unit = null
var triggered := false
var wall_points: PackedVector2Array = PackedVector2Array()
var wall_r := 36.0
var done := false


func src() -> Unit:
	return source if (source != null and is_instance_valid(source)) else null


func _enemies() -> Array:
	return arena.enemies_in_radius(team, position, radius, false)


func step(dt: float) -> void:
	if done:
		return
	t += dt
	if follow != null:
		if is_instance_valid(follow) and follow.alive:
			position = follow.position
		else:
			finish()
			return
	match kind:
		"chorus":
			tick_t -= dt
			if tick_t <= 0.0:
				tick_t += tick
				for h in arena.heroes:
					if h.alive and h.team == team and h.position.distance_to(position) <= radius + h.radius:
						h.heal(heal_amt)
				for e in _enemies():
					e.apply_slow(slow, tick + 0.2)
			if t >= duration:
				finish()
		"volley":
			tick_t -= dt
			if tick_t <= 0.0:
				tick_t += tick
				for e in _enemies():
					e.take_damage(dmg, src())
					e.apply_slow(slow, tick + 0.2)
			if t >= duration:
				finish()
		"glow":
			tick_t -= dt
			if tick_t <= 0.0:
				tick_t += 0.2
				for e in _enemies():
					e.apply_slow(slow, 0.4)
			if t >= duration:
				finish()
		"snare", "bloom":
			if not triggered and t >= delay:
				triggered = true
				for e in _enemies():
					e.take_damage(dmg, src())
					if root_dur > 0.0:
						e.apply_root(root_dur)
				arena.sfx_at("boom" if kind == "bloom" else "snare", position)
			if t >= delay + 0.35:
				finish()
		"wall":
			if t >= duration:
				finish()


func finish() -> void:
	done = true
	arena.remove_fx(self)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / maxf(delay, 0.01), 0.0, 1.0)
	match kind:
		"volley":
			var fade := clampf((duration - t) * 3.0, 0.0, 1.0)
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.75, 0.3, 0.16 * fade))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1.0, 0.8, 0.4, 0.7 * fade), 3.0, true)
			var rng := RandomNumberGenerator.new()
			rng.seed = int(t * 12.0)
			for i in 9:
				var p := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius
				draw_line(p + Vector2(-8, -26), p, Color(1, 0.95, 0.8, 0.9 * fade), 2.5)
				draw_circle(p, 3.0, Color(1, 0.9, 0.6, fade))
		"glow":
			var fade2 := clampf((duration - t) * 2.0, 0.0, 1.0)
			draw_circle(Vector2.ZERO, radius, Color(0.6, 0.9, 1.0, 0.18 * fade2))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(0.7, 0.95, 1.0, 0.5 * fade2), 2.0, true)
		"snare":
			if not triggered:
				draw_circle(Vector2.ZERO, radius, Color(1.0, 0.9, 0.3, 0.12))
				draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(1, 0.9, 0.3, 0.8), 2.5, true)
				draw_arc(Vector2.ZERO, radius * k, 0, TAU, 48, Color(1, 0.95, 0.5, 0.6), 2.0, true)
				draw_colored_polygon(Art.star_pts(Vector2.ZERO, radius * 0.35, radius * 0.15, 5, t * 3.0), Color(1, 0.9, 0.35, 0.5))
			else:
				var f := 1.0 - (t - delay) / 0.35
				draw_circle(Vector2.ZERO, radius, Color(1.0, 0.95, 0.5, 0.4 * f))
		"bloom":
			if not triggered:
				draw_circle(Vector2.ZERO, radius, Color(1.0, 0.5, 0.9, 0.1 + 0.1 * k))
				draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1, 0.6, 0.95, 0.85), 3.0, true)
				for i in 6:
					var d := Vector2.from_angle(i * TAU / 6.0 + t)
					draw_colored_polygon(Art.ellipse_pts(d * radius * 0.35 * k, radius * 0.28 * k + 2.0, radius * 0.12 * k + 1.0), Color(1, 0.75, 0.95, 0.6))
				draw_circle(Vector2.ZERO, radius * 0.12 + 6.0, Color(1, 0.95, 0.6, 0.9))
			else:
				var f2 := 1.0 - (t - delay) / 0.35
				draw_circle(Vector2.ZERO, radius * (1.0 + 0.1 * (1.0 - f2)), Color(1.0, 0.85, 1.0, 0.55 * f2))
		"wall":
			for p in wall_points:
				draw_circle(p - position + Vector2(0, 8), wall_r, Color(0, 0, 0, 0.25))
				draw_circle(p - position, wall_r, Color("7a6a55"))
				draw_circle(p - position + Vector2(-8, -8), wall_r * 0.55, Color("9a8a70"))
