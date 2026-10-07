class_name Unit
extends Node2D
## Base class for everything with HP and a team: heroes, creeps, buildings, jungle monsters.
## The Arena (match.gd) calls step(dt) on every unit each physics tick.

enum Kind { HERO, CREEP, STRUCTURE, NEUTRAL }
const DAWN := 0
const DUSK := 1
const NEUTRAL_TEAM := 2

var team := DAWN
var kind := Kind.CREEP
var arena: Arena
var display_name := ""
var max_hp := 100.0
var hp := 100.0
var armor := 0.0
var radius := 16.0
var alive := true
var invulnerable := false
## Extra multiplier on all damage taken (buildings during sudden death / backdoor protection).
var damage_taken_mult := 1.0
var bounty_gold := 0
var bounty_xp := 0

# Status effects (seconds left)
var stun_t := 0.0
var root_t := 0.0
var slow_t := 0.0
var slow_amt := 0.0
var taunt_t := 0.0
var taunt_src: Unit = null
var mark_t := 0.0
var mark_amp := 0.0
var shield := 0.0
var shield_t := 0.0
var untargetable_t := 0.0
var stealth_t := 0.0
var hit_flash := 0.0
var age := 0.0
## Hero -> match time of their last hit on this unit (for assists).
var recent_attackers := {}


func hp_frac() -> float:
	return clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)


func is_enemy_of(other_team: int) -> bool:
	return other_team != team


## Can a unit of `viewer_team` pick this unit as a target?
func is_targetable_by(viewer_team: int) -> bool:
	if not alive or invulnerable or untargetable_t > 0.0:
		return false
	if stealth_t > 0.0 and mark_t <= 0.0 and viewer_team != team:
		return false
	return true


func valid(u) -> bool:
	return u != null and is_instance_valid(u) and u.alive


func tick_status(dt: float) -> void:
	age += dt
	stun_t = maxf(0.0, stun_t - dt)
	root_t = maxf(0.0, root_t - dt)
	slow_t = maxf(0.0, slow_t - dt)
	if slow_t <= 0.0:
		slow_amt = 0.0
	taunt_t = maxf(0.0, taunt_t - dt)
	mark_t = maxf(0.0, mark_t - dt)
	untargetable_t = maxf(0.0, untargetable_t - dt)
	stealth_t = maxf(0.0, stealth_t - dt)
	hit_flash = maxf(0.0, hit_flash - dt)
	if shield_t > 0.0:
		shield_t -= dt
		if shield_t <= 0.0:
			shield = 0.0


func apply_stun(t: float) -> void:
	if kind == Kind.STRUCTURE or not alive:
		return
	stun_t = maxf(stun_t, t)


func apply_root(t: float) -> void:
	if kind == Kind.STRUCTURE or not alive:
		return
	root_t = maxf(root_t, t)


func apply_slow(amount: float, t: float) -> void:
	if kind == Kind.STRUCTURE or not alive:
		return
	slow_amt = maxf(slow_amt if slow_t > 0.0 else 0.0, amount)
	slow_t = maxf(slow_t, t)


func apply_taunt(src: Unit, t: float) -> void:
	if kind == Kind.STRUCTURE or not alive:
		return
	taunt_src = src
	taunt_t = maxf(taunt_t, t)


func apply_mark(t: float, amp: float) -> void:
	if not alive:
		return
	mark_t = maxf(mark_t, t)
	mark_amp = maxf(mark_amp if mark_t > 0.0 else 0.0, amp)


func add_shield(amount: float, t: float) -> void:
	shield = maxf(shield, amount)
	shield_t = maxf(shield_t, t)


func speed_mult() -> float:
	return 1.0 - (slow_amt if slow_t > 0.0 else 0.0)


## Deals damage after armor, marks and shields. Returns the damage actually dealt.
func take_damage(amount: float, source: Unit, true_damage := false, show_number := true) -> float:
	if not alive or invulnerable or untargetable_t > 0.0 or amount <= 0.0:
		return 0.0
	var dmg := amount
	if not true_damage:
		dmg *= 100.0 / (100.0 + maxf(armor, -50.0))
	if mark_t > 0.0:
		dmg *= 1.0 + mark_amp
	dmg *= damage_taken_mult
	var dealt := dmg
	if shield > 0.0:
		var absorbed := minf(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
	hp -= dmg
	hit_flash = 0.12
	var src: Unit = source if (source != null and is_instance_valid(source)) else null
	if src != null and src is Hero:
		recent_attackers[src] = arena.time
	if arena != null:
		arena.on_damage(self, src, dealt, show_number)
	_on_damaged(src, dealt)
	if hp <= 0.0:
		hp = 0.0
		die(src)
	return dealt


func heal(amount: float) -> void:
	if not alive:
		return
	hp = minf(max_hp, hp + amount)


func _on_damaged(_src: Unit, _amount: float) -> void:
	pass


func die(killer: Unit) -> void:
	if not alive:
		return
	alive = false
	_on_death(killer)
	if arena != null:
		arena.on_unit_died(self, killer)


func _on_death(_killer: Unit) -> void:
	pass


func step(_dt: float) -> void:
	pass


func _process(_delta: float) -> void:
	if arena != null and not arena.headless:
		queue_redraw()


# ---------- shared drawing helpers ----------

func draw_hp_bar(center_y: float, width: float, height: float, fill: Color, show_shield := true) -> void:
	var x := -width * 0.5
	draw_rect(Rect2(x - 1.5, center_y - 1.5, width + 3.0, height + 3.0), Color(0.06, 0.07, 0.1, 0.9))
	var total := maxf(max_hp, hp + shield)
	var w_hp := width * hp / total
	draw_rect(Rect2(x, center_y, w_hp, height), fill)
	if show_shield and shield > 0.0:
		draw_rect(Rect2(x + w_hp, center_y, width * shield / total, height), Color(0.95, 0.95, 1.0, 0.95))


func draw_status(r: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if stun_t > 0.0:
		for i in 3:
			var a := t * 5.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * r * 0.7, -r - 8 + sin(a) * 4.0), 4.0, Color("ffe066"))
	if root_t > 0.0:
		draw_arc(Vector2.ZERO, r + 6, 0, TAU, 24, Color("8fe06a"), 3.0)
		for i in 6:
			var a2 := i * TAU / 6.0
			draw_line(Vector2(cos(a2), sin(a2)) * (r + 2), Vector2(cos(a2), sin(a2)) * (r + 12), Color("5fb84a"), 3.0)
	if slow_t > 0.0 and slow_amt > 0.0:
		draw_arc(Vector2.ZERO, r + 3, 0, TAU, 24, Color(0.5, 0.8, 1.0, 0.8), 2.0)
	if mark_t > 0.0:
		var c := Color("ff4747")
		draw_arc(Vector2.ZERO, r + 10, 0, TAU, 28, c, 2.0)
		for i in 4:
			var d := Vector2.from_angle(i * PI * 0.5 + t)
			draw_line(d * (r + 4), d * (r + 16), c, 2.5)
	if taunt_t > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(-5, -r - 20), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ff7a3d"))
