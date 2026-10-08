class_name ItemIcons
extends RefCounted
## Item icons drawn in code (no image files). `s` is the half-size of the icon box.

static func _p(c: Vector2, s: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(c + (q as Vector2) * s)
	return out


static func _poly(ci: CanvasItem, c: Vector2, s: float, pts: Array, col: Color, outline := true) -> void:
	var pp := _p(c, s, pts)
	ci.draw_colored_polygon(pp, col)
	if outline:
		var loop := pp.duplicate()
		loop.append(pp[0])
		ci.draw_polyline(loop, Color(0, 0, 0, 0.55 * col.a), maxf(1.0, s * 0.07), true)


static func _sword(ci: CanvasItem, c: Vector2, s: float, blade: Color, a: float) -> void:
	# diagonal sword, tip top-right
	_poly(ci, c, s, [Vector2(-0.38, 0.22), Vector2(0.62, -0.78), Vector2(0.78, -0.62), Vector2(-0.22, 0.38)], Color(blade, a))
	ci.draw_line(c + Vector2(-0.56, 0.04) * s, c + Vector2(-0.04, 0.56) * s, Color(0.85, 0.68, 0.28, a), s * 0.16, true)
	ci.draw_line(c + Vector2(-0.3, 0.3) * s, c + Vector2(-0.72, 0.72) * s, Color(0.35, 0.22, 0.12, a), s * 0.16, true)
	ci.draw_circle(c + Vector2(-0.76, 0.76) * s, s * 0.11, Color(0.9, 0.75, 0.3, a))


static func _boot(ci: CanvasItem, c: Vector2, s: float, col: Color, a: float) -> void:
	_poly(ci, c, s, [Vector2(-0.35, -0.75), Vector2(0.15, -0.75), Vector2(0.15, 0.15), Vector2(0.7, 0.3), Vector2(0.75, 0.62),
			Vector2(-0.4, 0.62), Vector2(-0.4, -0.2)], Color(col, a))
	ci.draw_line(c + Vector2(-0.42, 0.58) * s, c + Vector2(0.76, 0.58) * s, Color(col.darkened(0.5), a), s * 0.14, true)
	ci.draw_line(c + Vector2(-0.38, -0.55) * s, c + Vector2(0.15, -0.55) * s, Color(col.lightened(0.35), a), s * 0.1, true)


static func _glove(ci: CanvasItem, c: Vector2, s: float, col: Color, a: float) -> void:
	for i in 4:
		var x := -0.42 + i * 0.26
		ci.draw_rect(Rect2(c + Vector2(x, -0.78 + absf(i - 1.5) * 0.08) * s, Vector2(0.2, 0.62) * s), Color(col, a))
	_poly(ci, c, s, [Vector2(-0.5, -0.25), Vector2(0.55, -0.25), Vector2(0.5, 0.45), Vector2(-0.45, 0.45)], Color(col, a))
	_poly(ci, c, s, [Vector2(-0.5, -0.1), Vector2(-0.85, -0.35), Vector2(-0.95, -0.2), Vector2(-0.55, 0.2)], Color(col, a))
	ci.draw_rect(Rect2(c + Vector2(-0.5, 0.45) * s, Vector2(1.0, 0.32) * s), Color(col.darkened(0.35), a))


static func _sparkle(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := i * TAU / 8.0 - PI / 2.0
		pts.append(c + Vector2.from_angle(ang) * (r if i % 2 == 0 else r * 0.3))
	ci.draw_colored_polygon(pts, col)


static func draw(ci: CanvasItem, icon: String, c: Vector2, s: float, col: Color, alpha := 1.0) -> void:
	var a := alpha
	match icon:
		"boots":
			_boot(ci, c, s, col, a)
		"treads":
			_boot(ci, c + Vector2(0.1, 0) * s, s * 0.9, col, a)
			for i in 3:
				var y := -0.5 + i * 0.35
				ci.draw_line(c + Vector2(-1.0, y) * s, c + Vector2(-0.55, y) * s, Color(1, 1, 1, 0.85 * a), s * 0.1, true)
			_poly(ci, c, s, [Vector2(0.2, -0.55), Vector2(0.85, -0.95), Vector2(0.7, -0.45), Vector2(0.95, -0.35), Vector2(0.25, -0.2)],
					Color(1, 1, 1, 0.9 * a))
		"blade":
			_sword(ci, c, s, col, a)
		"storm":
			_sword(ci, c, s, col, a)
			_poly(ci, c, s, [Vector2(-0.1, -0.95), Vector2(-0.55, -0.3), Vector2(-0.3, -0.3), Vector2(-0.6, 0.2), Vector2(0.0, -0.45),
					Vector2(-0.25, -0.45)], Color(1, 0.93, 0.35, a))
		"glove":
			_glove(ci, c, s, col, a)
		"gauntlets":
			_glove(ci, c, s, col, a)
			for i in 3:
				var x := -0.35 + i * 0.35
				_poly(ci, c, s, [Vector2(x - 0.1, 0.45), Vector2(x, 0.95), Vector2(x + 0.1, 0.45)], Color(0.95, 0.95, 1, a), false)
			ci.draw_circle(c + Vector2(0.0, 0.1) * s, s * 0.16, Color(1, 0.35, 0.2, a))
		"heart":
			ci.draw_circle(c + Vector2(-0.3, -0.2) * s, s * 0.38, Color(col, a))
			ci.draw_circle(c + Vector2(0.3, -0.2) * s, s * 0.38, Color(col, a))
			_poly(ci, c, s, [Vector2(-0.66, -0.05), Vector2(0.66, -0.05), Vector2(0.0, 0.75)], Color(col, a), false)
			_poly(ci, c, s, [Vector2(0.05, -0.55), Vector2(0.45, -0.95), Vector2(0.6, -0.6), Vector2(0.2, -0.4)], Color(0.45, 0.8, 0.35, a))
			ci.draw_circle(c + Vector2(-0.32, -0.3) * s, s * 0.1, Color(1, 1, 1, 0.5 * a))
		"plate":
			_poly(ci, c, s, [Vector2(-0.45, -0.7), Vector2(0.45, -0.7), Vector2(0.55, 0.2), Vector2(0.0, 0.8), Vector2(-0.55, 0.2)], Color(col, a))
			ci.draw_circle(c + Vector2(-0.62, -0.55) * s, s * 0.28, Color(col.darkened(0.2), a))
			ci.draw_circle(c + Vector2(0.62, -0.55) * s, s * 0.28, Color(col.darkened(0.2), a))
			ci.draw_line(c + Vector2(0, -0.6) * s, c + Vector2(0, 0.65) * s, Color(col.darkened(0.45), a), s * 0.1, true)
			ci.draw_line(c + Vector2(-0.4, -0.15) * s, c + Vector2(0.4, -0.15) * s, Color(col.darkened(0.45), a), s * 0.08, true)
			ci.draw_circle(c + Vector2(0, -0.35) * s, s * 0.13, Color(1, 0.8, 0.3, a))
		"buckler":
			ci.draw_circle(c, s * 0.82, Color(col.darkened(0.35), a))
			ci.draw_circle(c, s * 0.66, Color(col, a))
			ci.draw_circle(c, s * 0.24, Color(col.lightened(0.4), a))
			for i in 6:
				ci.draw_circle(c + Vector2.from_angle(i * TAU / 6.0) * s * 0.74, s * 0.06, Color(0.25, 0.25, 0.28, a))
		"pendant":
			ci.draw_arc(c + Vector2(0, -0.35) * s, s * 0.55, PI * 1.05, PI * 1.95, 16, Color(0.9, 0.85, 0.6, a), s * 0.08, true)
			ci.draw_circle(c + Vector2(0, 0.25) * s, s * 0.45, Color(col, a))
			ci.draw_circle(c + Vector2(0.18, 0.12) * s, s * 0.36, Color(0.08, 0.1, 0.2, a))
			ci.draw_arc(c + Vector2(0, 0.25) * s, s * 0.45, 0, TAU, 24, Color(0.9, 0.85, 0.6, a), s * 0.08, true)
		"crown":
			_poly(ci, c, s, [Vector2(-0.8, 0.5), Vector2(-0.8, -0.4), Vector2(-0.4, 0.0), Vector2(0.0, -0.75), Vector2(0.4, 0.0),
					Vector2(0.8, -0.4), Vector2(0.8, 0.5)], Color(col, a))
			ci.draw_rect(Rect2(c + Vector2(-0.8, 0.35) * s, Vector2(1.6, 0.25) * s), Color(col.darkened(0.25), a))
			ci.draw_circle(c + Vector2(0, 0.1) * s, s * 0.14, Color(0.35, 0.6, 1, a))
			ci.draw_circle(c + Vector2(-0.48, 0.2) * s, s * 0.1, Color(1, 0.35, 0.4, a))
			ci.draw_circle(c + Vector2(0.48, 0.2) * s, s * 0.1, Color(0.4, 1, 0.6, a))
		"fang":
			_poly(ci, c, s, [Vector2(-0.45, -0.75), Vector2(0.45, -0.75), Vector2(0.3, -0.2), Vector2(0.05, 0.55), Vector2(-0.15, 0.85),
					Vector2(-0.2, 0.2)], Color(0.95, 0.92, 0.82, a))
			ci.draw_circle(c + Vector2(0.4, 0.55) * s, s * 0.17, Color(col, a))
			_poly(ci, c, s, [Vector2(0.4, 0.2), Vector2(0.28, 0.5), Vector2(0.52, 0.5)], Color(col, a), false)
		"cleaver":
			_poly(ci, c, s, [Vector2(-0.6, -0.75), Vector2(0.6, -0.75), Vector2(0.6, 0.15), Vector2(-0.5, 0.15)], Color(0.85, 0.87, 0.92, a))
			ci.draw_line(c + Vector2(-0.6, 0.1) * s, c + Vector2(0.6, 0.1) * s, Color(col, a), s * 0.14, true)
			ci.draw_line(c + Vector2(0.4, 0.15) * s, c + Vector2(0.4, 0.85) * s, Color(0.4, 0.25, 0.15, a), s * 0.2, true)
			ci.draw_circle(c + Vector2(-0.3, -0.45) * s, s * 0.1, Color(0.2, 0.2, 0.25, a))
			ci.draw_circle(c + Vector2(-0.35, 0.5) * s, s * 0.16, Color(col, a))
		"blink":
			ci.draw_arc(c, s * 0.8, 0, TAU, 28, Color(col, 0.6 * a), s * 0.08, true)
			_sparkle(ci, c, s * 0.75, Color(col.lightened(0.3), a))
			ci.draw_circle(c, s * 0.14, Color(1, 1, 1, a))
		"phase":
			ci.draw_arc(c, s * 0.85, 0, TAU, 28, Color(col, 0.7 * a), s * 0.1, true)
			_sparkle(ci, c + Vector2(-0.22, 0.1) * s, s * 0.6, Color(col.darkened(0.15), a))
			_sparkle(ci, c + Vector2(0.28, -0.2) * s, s * 0.55, Color(col.lightened(0.35), a))
			ci.draw_circle(c + Vector2(0.28, -0.2) * s, s * 0.11, Color(1, 1, 1, a))
		_:
			ci.draw_circle(c, s * 0.6, Color(col, a))
