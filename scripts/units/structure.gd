class_name Structure
extends Unit
## Tower or Heartspire. Place these in scenes/maps/one_lane.tscn and pick the stats resource.
## Buildings must fall in order: Outer Tower -> Inner Tower -> Heartspire.
## Towers shoot creeps first, but lock onto an enemy hero who attacks an allied hero nearby.
## Consecutive shots at the same hero double each time (1x, 2x, 4x, 8x cap), see MatchConfig.

@export_enum("Dawn", "Dusk") var team_id := 0
@export_enum("Outer Tower", "Inner Tower", "Heartspire") var tier := 0
@export var stats: UnitStats

var target: Unit = null
var attack_cd := 0.0
var ramp_stacks := 0
var aggro_hero: Unit = null
var aggro_t := 0.0
var attack_range := 400.0
var pulse_t := 0.0


func _ready() -> void:
	team = team_id
	kind = Kind.STRUCTURE
	if stats != null:
		display_name = stats.display_name
		max_hp = stats.max_hp
		hp = max_hp
		armor = stats.armor
		radius = stats.radius
		attack_range = stats.attack_range
		bounty_gold = stats.gold_bounty
		bounty_xp = stats.xp_bounty


func is_heartspire() -> bool:
	return tier == 2


func set_aggro(h: Unit, t: float) -> void:
	if not alive or stats == null or stats.damage <= 0.0:
		return
	if valid(h) and h.is_targetable_by(team) and position.distance_to(h.position) <= attack_range + radius + h.radius + 40.0:
		aggro_hero = h
		aggro_t = t


## Damage multiplier for the n-th consecutive shot (0-based) at the same hero: 1, 2, 4, 8 (capped).
func ramp_mult(n: int) -> float:
	var cfg := arena.config
	return minf(pow(cfg.tower_hero_ramp_factor, n), cfg.tower_hero_ramp_cap)


func _in_range(u: Unit) -> bool:
	return position.distance_to(u.position) <= attack_range + radius + u.radius


func step(dt: float) -> void:
	tick_status(dt)
	pulse_t += dt
	if not alive or stats == null or stats.damage <= 0.0:
		return
	attack_cd -= dt
	aggro_t -= dt
	if target != null and not (valid(target) and target.is_targetable_by(team) and _in_range(target)):
		target = null
		ramp_stacks = 0
	if aggro_t > 0.0 and valid(aggro_hero) and aggro_hero.is_targetable_by(team) and _in_range(aggro_hero):
		if target != aggro_hero:
			ramp_stacks = 0
		target = aggro_hero
	if target == null:
		var best: Unit = null
		var bd := INF
		var best_hero: Unit = null
		var bdh := INF
		for u in arena.units:
			if not u.alive or u.team == team or u.kind == Kind.NEUTRAL or u.kind == Kind.STRUCTURE:
				continue
			if not u.is_targetable_by(team) or not _in_range(u):
				continue
			var d := position.distance_squared_to(u.position)
			if u.kind == Kind.HERO:
				if d < bdh:
					bdh = d
					best_hero = u
			elif d < bd:
				bd = d
				best = u
		target = best if best != null else best_hero
		ramp_stacks = 0
	if target != null and attack_cd <= 0.0:
		attack_cd = stats.attack_interval
		var dmg := stats.damage
		if target.kind == Kind.HERO:
			var mult := ramp_mult(ramp_stacks)
			dmg *= mult
			arena.note_tower_hit(pow(arena.config.tower_hero_ramp_factor, ramp_stacks))
			ramp_stacks += 1
			var tid := target.get_instance_id()
			var hit := func(u: Unit, pr: Projectile) -> void:
				# Only counts if the shot lands on the hero it was fired at.
				var dealt := u.take_damage(pr.damage, self, false, false)
				if dealt > 0.0 and u.get_instance_id() == tid:
					arena.tower_hit_text(u, dealt, mult)
				if not u.alive:
					arena.tower_hero_kills += 1
			arena.spawn_homing(self, target, dmg, stats.projectile_speed, "tower", Vector2(0, -radius * 0.6), hit)
		else:
			arena.spawn_homing(self, target, dmg, stats.projectile_speed, "tower", Vector2(0, -radius * 0.6))
		arena.sfx_at("tower", position, -6.0)


func _draw() -> void:
	if arena == null:
		return
	if tier == 2:
		Art.draw_heartspire(self, Vector2.ZERO, radius, team, alive, sin(pulse_t * 2.5))
	else:
		Art.draw_tower(self, Vector2.ZERO, radius, team, alive)
	if not alive:
		return
	if hit_flash > 0.0:
		draw_circle(Vector2.ZERO, radius * 0.9, Color(1, 1, 1, 0.25))
	if invulnerable:
		draw_arc(Vector2.ZERO, radius + 10, 0, TAU, 48, Color(0.8, 0.9, 1.0, 0.55), 3.0, true)
	# Show the danger range when the player is close.
	var p: Hero = arena.player
	if p != null and p.alive and p.team != team and stats != null and stats.damage > 0.0:
		var d := position.distance_to(p.position)
		if d < attack_range + radius + 260.0:
			var a := 0.55 if target == p else 0.22
			draw_arc(Vector2.ZERO, attack_range + radius, 0, TAU, 96, Color(1, 0.25, 0.25, a), 4.0, true)
	if target != null and valid(target) and target.kind == Kind.HERO:
		draw_line(Vector2(0, -radius * 0.6), target.position - position, Color(1, 0.3, 0.3, 0.35), 2.0)
	var w := radius * 2.4
	draw_hp_bar(-radius - 26, w, 8, Art.team_color(team), false)
