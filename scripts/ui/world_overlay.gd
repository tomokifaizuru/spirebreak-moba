class_name WorldOverlay
extends Control
## Draws 2D things that float over the 3D world: health/mana bars, hero names and levels,
## status marks and floating damage/gold text. Positions come from Camera3D.unproject_position.

var arena: Arena
var view: WorldView
var font: Font


func setup(a: Arena, v: WorldView) -> void:
	arena = a
	view = v
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_d: float) -> void:
	queue_redraw()


func _bar(c: Vector2, width: float, height: float, u: Unit, fill: Color, show_shield := true) -> void:
	var x := c.x - width * 0.5
	draw_rect(Rect2(x - 1.5, c.y - 1.5, width + 3.0, height + 3.0), Color(0.06, 0.07, 0.1, 0.9))
	var total := maxf(u.max_hp, u.hp + u.shield)
	var w_hp := width * u.hp / total
	draw_rect(Rect2(x, c.y, w_hp, height), fill)
	if show_shield and u.shield > 0.0:
		draw_rect(Rect2(x + w_hp, c.y, width * u.shield / total, height), Color(0.95, 0.95, 1.0, 0.95))


func _draw() -> void:
	if view == null or view.cam == null:
		return
	var cam := view.cam
	var vs := get_viewport_rect().size
	var tm := Time.get_ticks_msec() / 1000.0
	for pair in view.bar_targets():
		var u: Unit = pair[0]
		var wp: Vector3 = pair[1]
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		if sp.x < -100 or sp.y < -60 or sp.x > vs.x + 100 or sp.y > vs.y + 60:
			continue
		if u is Hero:
			var h := u as Hero
			var col := Art.PLAYER if h.is_player else Art.team_color(h.team)
			var bw := 70.0
			_bar(sp, bw, 8.0, h, col)
			draw_rect(Rect2(sp.x - bw * 0.5, sp.y + 10.0, bw, 3.0), Color(0.06, 0.07, 0.1, 0.9))
			draw_rect(Rect2(sp.x - bw * 0.5, sp.y + 10.0, bw * h.mana / maxf(h.max_mana, 1.0), 3.0), Color("58a6ff"))
			var lc := Vector2(sp.x - bw * 0.5 - 11.0, sp.y + 5.0)
			draw_circle(lc, 10.0, Color(0.08, 0.09, 0.13))
			draw_arc(lc, 10.0, 0, TAU, 20, col, 2.0, true)
			draw_string(font, lc + Vector2(-10, 5), str(h.level), HORIZONTAL_ALIGNMENT_CENTER, 20, 13, Color.WHITE)
			var nm := "You" if h.is_player else h.display_name
			draw_string_outline(font, sp + Vector2(-80, -6.0), nm, HORIZONTAL_ALIGNMENT_CENTER, 160, 14, 4, Color(0, 0, 0, 0.8))
			draw_string(font, sp + Vector2(-80, -6.0), nm, HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color.WHITE)
			if h.recall_t > 0.0:
				var k := 1.0 - h.recall_t / arena.config.recall_time
				draw_arc(sp + Vector2(0, 30), 9.0, -PI / 2, -PI / 2 + TAU * k, 24, Color(0.5, 0.8, 1.0), 3.0, true)
			_status(h, sp + Vector2(bw * 0.5 + 10.0, 4.0), tm)
		elif u is Structure:
			var s := u as Structure
			var w := 110.0 if s.is_heartspire() else 84.0
			_bar(sp, w, 8.0, s, Art.team_color(s.team), false)
			if s.invulnerable:
				draw_string_outline(font, sp + Vector2(-60, -5), "PROTECTED", HORIZONTAL_ALIGNMENT_CENTER, 120, 11, 3, Color(0, 0, 0, 0.8))
				draw_string(font, sp + Vector2(-60, -5), "PROTECTED", HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(0.85, 0.92, 1.0))
		elif u is NeutralMob:
			_bar(sp, 50.0, 5.0, u, Color("e0c83a"))
		else:
			if u.hp < u.max_hp:
				var tc := Art.team_color(u.team)
				_bar(sp, 34.0, 4.0, u, tc.lightened(0.1) if u.team == 0 else tc)
	# floating text from the FxLayer (damage numbers, gold, level up...)
	if arena.fx != null:
		for it in arena.fx.items:
			if it["type"] != "text":
				continue
			var k2: float = it["t"] / it["life"]
			var col2: Color = it["col"]
			var p3 := MeshKit.v3(it["pos"], 1.3)
			if cam.is_position_behind(p3):
				continue
			var p := cam.unproject_position(p3) + Vector2(0, -40.0 * k2 - 10.0)
			var c := Color(col2, 1.0 - maxf(0.0, k2 - 0.6) / 0.4)
			var sz: int = it["size"]
			p.x -= 120.0
			draw_string_outline(font, p, it["s"], HORIZONTAL_ALIGNMENT_CENTER, 240, sz, 5, Color(0.05, 0.05, 0.08, c.a))
			draw_string(font, p, it["s"], HORIZONTAL_ALIGNMENT_CENTER, 240, sz, c)


func _status(u: Unit, at: Vector2, _t: float) -> void:
	var x := at.x
	var marks: Array = []
	if u.root_t > 0.0:
		marks.append([Color("8fe06a"), "R"])
	if u.slow_t > 0.0 and u.slow_amt > 0.0:
		marks.append([Color(0.5, 0.8, 1.0), "S"])
	if u.mark_t > 0.0:
		marks.append([Color("ff4747"), "M"])
	if u.taunt_t > 0.0:
		marks.append([Color("ff7a3d"), "!"])
	for m in marks:
		draw_circle(Vector2(x, at.y), 7.0, Color(0.08, 0.09, 0.13, 0.9))
		draw_arc(Vector2(x, at.y), 7.0, 0, TAU, 14, m[0], 2.0, true)
		draw_string(font, Vector2(x - 7, at.y + 4), m[1], HORIZONTAL_ALIGNMENT_CENTER, 14, 10, m[0])
		x += 16.0
