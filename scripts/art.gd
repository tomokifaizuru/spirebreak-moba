@tool
class_name Art
extends RefCounted
## Clean vector art drawn in code (no image files). Used by units, HUD portraits and the title screen.

const DAWN := Color("3d9bff")
const DAWN_DARK := Color("1d5ea8")
const DUSK := Color("ff4d5e")
const DUSK_DARK := Color("a3243a")
const PLAYER := Color("5fe07c")
const GOLD := Color("ffcf4a")
const INK := Color("161924")
const PANEL := Color(0.07, 0.08, 0.12, 0.86)


static func team_color(team: int) -> Color:
	if team == 0:
		return DAWN
	if team == 1:
		return DUSK
	return Color("d9c25a")


static func team_dark(team: int) -> Color:
	if team == 0:
		return DAWN_DARK
	if team == 1:
		return DUSK_DARK
	return Color("7a6a2a")


static func circle_pts(c: Vector2, r: float, n := 24) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		p.append(c + Vector2.from_angle(i * TAU / n) * r)
	return p


static func ellipse_pts(c: Vector2, rx: float, ry: float, n := 24) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


static func pie_pts(c: Vector2, r: float, from_a: float, to_a: float, n := 32) -> PackedVector2Array:
	var p := PackedVector2Array([c])
	var steps := maxi(2, int(n * absf(to_a - from_a) / TAU) + 2)
	for i in steps + 1:
		p.append(c + Vector2.from_angle(lerpf(from_a, to_a, float(i) / steps)) * r)
	return p


static func star_pts(c: Vector2, r_out: float, r_in: float, points := 5, rot := -PI / 2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in points * 2:
		var r := r_out if i % 2 == 0 else r_in
		p.append(c + Vector2.from_angle(rot + i * PI / points) * r)
	return p


static func outline_circle(ci: CanvasItem, c: Vector2, r: float, col: Color, w := 2.5) -> void:
	ci.draw_arc(c, r, 0, TAU, 40, col, w, true)


## Draws a hero face/body. `f` = facing direction (the face leans that way).
static func draw_hero(ci: CanvasItem, id: StringName, c: Vector2, r: float, f := Vector2(0, 1), alpha := 1.0) -> void:
	var a := alpha
	var lean := f.normalized() * r * 0.12 if f != Vector2.ZERO else Vector2.ZERO
	match id:
		&"morrow":
			# Mossback Warden: turtle with a stone shell, grey helmet and leaf shield.
			ci.draw_circle(c, r, Color("6d5a37", a))
			for i in 6:
				ci.draw_circle(c + Vector2.from_angle(i * TAU / 6.0 + 0.5) * r * 0.62, r * 0.22, Color("8a7347", a))
			ci.draw_circle(c, r * 0.24, Color("8a7347", a))
			var hc := c + lean * 2.4
			ci.draw_circle(hc, r * 0.58, Color("5aa346", a))
			ci.draw_colored_polygon(pie_pts(hc, r * 0.6, PI * 1.05, PI * 1.95), Color("9aa3ad", a))
			ci.draw_circle(hc + Vector2(-r * 0.22, r * 0.08), r * 0.13, Color(1, 1, 1, a))
			ci.draw_circle(hc + Vector2(r * 0.22, r * 0.08), r * 0.13, Color(1, 1, 1, a))
			ci.draw_circle(hc + Vector2(-r * 0.2, r * 0.11), r * 0.07, Color(0.08, 0.1, 0.1, a))
			ci.draw_circle(hc + Vector2(r * 0.24, r * 0.11), r * 0.07, Color(0.08, 0.1, 0.1, a))
			ci.draw_arc(hc + Vector2(0, r * 0.24), r * 0.15, 0.3, PI - 0.3, 8, Color(0.1, 0.25, 0.1, a), 2.0)
			var sc := c + Vector2(r * 0.85, r * 0.25)
			ci.draw_colored_polygon(PackedVector2Array([sc + Vector2(0, -r * 0.45), sc + Vector2(r * 0.3, -r * 0.2), sc + Vector2(r * 0.22, r * 0.3), sc + Vector2(0, r * 0.45), sc + Vector2(-r * 0.22, r * 0.3), sc + Vector2(-r * 0.3, -r * 0.2)]), Color("ffd75e", a))
			ci.draw_line(sc + Vector2(0, -r * 0.3), sc + Vector2(0, r * 0.3), Color("4f8f3a", a), 2.0)
		&"lumi":
			# Lantern Witch: violet robe, pointed hat with a star, ice-blue hair, glowing staff.
			ci.draw_circle(c, r, Color("5b3fd0", a))
			var fc := c + lean * 1.5 + Vector2(0, r * 0.18)
			ci.draw_circle(fc, r * 0.55, Color("bfeeff", a))
			ci.draw_circle(fc + Vector2(0, r * 0.08), r * 0.42, Color("ffe4d4", a))
			ci.draw_circle(fc + Vector2(-r * 0.16, r * 0.1), r * 0.07, Color(0.15, 0.15, 0.35, a))
			ci.draw_circle(fc + Vector2(r * 0.16, r * 0.1), r * 0.07, Color(0.15, 0.15, 0.35, a))
			ci.draw_colored_polygon(ellipse_pts(fc + Vector2(0, -r * 0.28), r * 0.78, r * 0.26), Color("3a2a8f", a))
			ci.draw_colored_polygon(PackedVector2Array([fc + Vector2(-r * 0.42, -r * 0.3), fc + Vector2(r * 0.42, -r * 0.3), fc + Vector2(r * 0.25, -r * 1.2)]), Color("3a2a8f", a))
			ci.draw_colored_polygon(star_pts(fc + Vector2(0, -r * 0.62), r * 0.2, r * 0.09), Color("ffd84a", a))
			var st := c + Vector2(-r * 0.95, -r * 0.1)
			ci.draw_line(st + Vector2(0, r * 0.7), st + Vector2(0, -r * 0.5), Color("8a6a3a", a), 3.0)
			ci.draw_circle(st + Vector2(0, -r * 0.6), r * 0.2, Color("8ff4ff", a))
			ci.draw_circle(st + Vector2(0, -r * 0.6), r * 0.32, Color(0.6, 0.95, 1.0, 0.3 * a))
		&"kestrel":
			# Dune Ranger: rust tunic, teal scarf, auburn hair, aviator goggles, bow.
			ci.draw_circle(c, r, Color("d0661f", a))
			ci.draw_colored_polygon(pie_pts(c, r, PI * 0.15, PI * 0.85), Color("1f7f7a", a))
			var hc2 := c + lean * 1.8
			ci.draw_circle(hc2, r * 0.6, Color("ffd9bd", a))
			ci.draw_colored_polygon(pie_pts(hc2, r * 0.64, PI * 0.95, PI * 2.05), Color("8a4019", a))
			ci.draw_circle(hc2 + Vector2(-r * 0.24, -r * 0.24), r * 0.17, Color("1f6f6a", a))
			ci.draw_circle(hc2 + Vector2(r * 0.24, -r * 0.24), r * 0.17, Color("1f6f6a", a))
			ci.draw_circle(hc2 + Vector2(-r * 0.24, -r * 0.24), r * 0.1, Color("8ff0e6", a))
			ci.draw_circle(hc2 + Vector2(r * 0.24, -r * 0.24), r * 0.1, Color("8ff0e6", a))
			ci.draw_circle(hc2 + Vector2(-r * 0.2, r * 0.12), r * 0.06, Color(0.2, 0.1, 0.05, a))
			ci.draw_circle(hc2 + Vector2(r * 0.2, r * 0.12), r * 0.06, Color(0.2, 0.1, 0.05, a))
			ci.draw_arc(hc2 + Vector2(0, r * 0.26), r * 0.13, 0.4, PI - 0.4, 8, Color(0.5, 0.2, 0.1, a), 2.0)
			var bc := c + Vector2(r * 0.95, 0)
			ci.draw_arc(bc + Vector2(-r * 0.4, 0), r * 0.75, -1.1, 1.1, 12, Color("6b3b1a", a), 3.0)
			ci.draw_line(bc + Vector2(-r * 0.4, 0) + Vector2.from_angle(-1.1) * r * 0.75, bc + Vector2(-r * 0.4, 0) + Vector2.from_angle(1.1) * r * 0.75, Color(1, 1, 1, 0.8 * a), 1.0)
		&"sable":
			# Ember Fox: dark hood, white fox mask with red marks, crimson scarf.
			ci.draw_circle(c, r, Color("2a2531", a))
			ci.draw_arc(c, r * 0.8, PI * 0.1, PI * 0.9, 14, Color("d8263f", a), r * 0.25)
			var hc3 := c + lean * 1.6 - Vector2(0, r * 0.05)
			ci.draw_colored_polygon(PackedVector2Array([hc3 + Vector2(-r * 0.6, -r * 0.1), hc3 + Vector2(-r * 0.55, -r * 0.95), hc3 + Vector2(-r * 0.12, -r * 0.45)]), Color("1a161f", a))
			ci.draw_colored_polygon(PackedVector2Array([hc3 + Vector2(r * 0.6, -r * 0.1), hc3 + Vector2(r * 0.55, -r * 0.95), hc3 + Vector2(r * 0.12, -r * 0.45)]), Color("1a161f", a))
			ci.draw_colored_polygon(PackedVector2Array([hc3 + Vector2(-r * 0.5, -r * 0.2), hc3 + Vector2(-r * 0.47, -r * 0.7), hc3 + Vector2(-r * 0.2, -r * 0.4)]), Color("d8263f", a))
			ci.draw_colored_polygon(PackedVector2Array([hc3 + Vector2(r * 0.5, -r * 0.2), hc3 + Vector2(r * 0.47, -r * 0.7), hc3 + Vector2(r * 0.2, -r * 0.4)]), Color("d8263f", a))
			ci.draw_colored_polygon(PackedVector2Array([hc3 + Vector2(-r * 0.52, -r * 0.3), hc3 + Vector2(r * 0.52, -r * 0.3), hc3 + Vector2(r * 0.3, r * 0.25), hc3 + Vector2(0, r * 0.55), hc3 + Vector2(-r * 0.3, r * 0.25)]), Color("f4efe9", a))
			ci.draw_line(hc3 + Vector2(-r * 0.35, -r * 0.05), hc3 + Vector2(-r * 0.12, 0.0), Color("d8263f", a), 3.0)
			ci.draw_line(hc3 + Vector2(r * 0.35, -r * 0.05), hc3 + Vector2(r * 0.12, 0.0), Color("d8263f", a), 3.0)
			ci.draw_circle(hc3 + Vector2(0, r * 0.45), r * 0.07, Color(0.1, 0.1, 0.1, a))
		&"calla":
			# Bloom Singer: mint hair, pink petal crown, golden bell staff.
			ci.draw_circle(c, r, Color("ff8fc8", a))
			for i in 8:
				ci.draw_circle(c + Vector2.from_angle(i * TAU / 8.0) * r * 0.82, r * 0.22, Color("ffb3dc", a))
			var hc4 := c + lean * 1.6 + Vector2(0, r * 0.1)
			ci.draw_circle(hc4, r * 0.6, Color("6fd08c", a))
			ci.draw_circle(hc4 + Vector2(0, r * 0.1), r * 0.44, Color("ffe4d4", a))
			ci.draw_circle(hc4 + Vector2(-r * 0.16, r * 0.1), r * 0.075, Color(0.15, 0.12, 0.2, a))
			ci.draw_circle(hc4 + Vector2(r * 0.16, r * 0.1), r * 0.075, Color(0.15, 0.12, 0.2, a))
			ci.draw_arc(hc4 + Vector2(0, r * 0.26), r * 0.1, 0.4, PI - 0.4, 8, Color(0.75, 0.3, 0.4, a), 2.0)
			for i in 5:
				ci.draw_colored_polygon(ellipse_pts(hc4 + Vector2((i - 2) * r * 0.2, -r * 0.48 - absf(i - 2) * -r * 0.04), r * 0.12, r * 0.2), Color("ff6fb8", a))
			ci.draw_circle(hc4 + Vector2(0, -r * 0.5), r * 0.1, Color("ffd84a", a))
			var bs := c + Vector2(r * 0.95, -r * 0.05)
			ci.draw_line(bs + Vector2(0, r * 0.7), bs + Vector2(0, -r * 0.45), Color("c9a86a", a), 3.0)
			ci.draw_colored_polygon(pie_pts(bs + Vector2(0, -r * 0.4), r * 0.24, PI, TAU), Color("ffd84a", a))
		&"rook":
			# Hammer Knight: grey helm with visor slit and orange plume, big hammer.
			ci.draw_circle(c, r, Color("ff9a3c", a))
			var hc5 := c + lean * 1.5
			ci.draw_circle(hc5, r * 0.66, Color("b7bdcb", a))
			ci.draw_colored_polygon(pie_pts(hc5, r * 0.66, PI, TAU), Color("cfd4de", a))
			ci.draw_rect(Rect2(hc5 + Vector2(-r * 0.46, -r * 0.02), Vector2(r * 0.92, r * 0.16)), Color(0.1, 0.1, 0.13, a))
			ci.draw_circle(hc5 + Vector2(-r * 0.18, r * 0.06), r * 0.05, Color("ffe08a", a))
			ci.draw_circle(hc5 + Vector2(r * 0.18, r * 0.06), r * 0.05, Color("ffe08a", a))
			ci.draw_colored_polygon(ellipse_pts(hc5 + Vector2(0, -r * 0.72), r * 0.16, r * 0.3), Color("ff7a1c", a))
			var hm := c + Vector2(r * 0.9, -r * 0.3)
			ci.draw_line(hm + Vector2(-r * 0.2, r * 0.9), hm, Color("7a5232", a), 3.0)
			ci.draw_rect(Rect2(hm + Vector2(-r * 0.3, -r * 0.22), Vector2(r * 0.6, r * 0.36)), Color("8e95a6", a))
			ci.draw_rect(Rect2(hm + Vector2(-r * 0.3, -r * 0.22), Vector2(r * 0.1, r * 0.36)), Color("ffcf4a", a))
		_:
			ci.draw_circle(c, r, Color(0.8, 0.8, 0.8, a))
	outline_circle(ci, c, r, Color(0.07, 0.08, 0.1, 0.9 * a), 2.0)


## Simple vector icons for skill / HUD buttons.
static func draw_icon(ci: CanvasItem, icon: String, c: Vector2, s: float, col := Color.WHITE) -> void:
	var w := maxf(2.0, s * 0.13)
	match icon:
		"bolt":
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.55, -s * 0.55), col, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.75, -s * 0.75), c + Vector2(s * 0.2, -s * 0.55), c + Vector2(s * 0.55, -s * 0.2)]), col)
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(-s * 0.85, s * 0.35), col, w * 0.7)
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(-s * 0.35, s * 0.85), col, w * 0.7)
		"tumble":
			ci.draw_arc(c, s * 0.6, PI * 0.8, PI * 2.1, 16, col, w)
			var e := c + Vector2.from_angle(PI * 2.1) * s * 0.6
			ci.draw_colored_polygon(PackedVector2Array([e + Vector2(s * 0.3, -s * 0.05), e + Vector2(-s * 0.2, -s * 0.25), e + Vector2(-s * 0.05, s * 0.3)]), col)
			ci.draw_circle(c, s * 0.18, col)
		"mark":
			ci.draw_arc(c, s * 0.62, 0, TAU, 24, col, w)
			ci.draw_arc(c, s * 0.3, 0, TAU, 16, col, w)
			for i in 4:
				var d := Vector2.from_angle(i * PI * 0.5)
				ci.draw_line(c + d * s * 0.45, c + d * s * 0.9, col, w)
		"volley":
			for i in 3:
				var x := (i - 1) * s * 0.45
				var top := c + Vector2(x - s * 0.15, -s * 0.75)
				var tip := c + Vector2(x + s * 0.1, s * 0.45)
				ci.draw_line(top, tip, col, w * 0.8)
				ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(0.06, 1) * s * 0.3, tip + Vector2(-s * 0.18, -s * 0.12), tip + Vector2(s * 0.2, -s * 0.06)]), col)
		"bash":
			ci.draw_circle(c + Vector2(s * 0.2, 0), s * 0.5, col)
			for i in 3:
				var y := (i - 1) * s * 0.35
				ci.draw_line(c + Vector2(-s * 0.9, y), c + Vector2(-s * 0.45, y), col, w * 0.8)
		"shield":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.8), c + Vector2(s * 0.65, -s * 0.5), c + Vector2(s * 0.5, s * 0.35), c + Vector2(0, s * 0.85), c + Vector2(-s * 0.5, s * 0.35), c + Vector2(-s * 0.65, -s * 0.5)]), col)
		"roar":
			ci.draw_circle(c + Vector2(-s * 0.45, 0), s * 0.22, col)
			for i in 3:
				ci.draw_arc(c + Vector2(-s * 0.45, 0), s * (0.45 + i * 0.28), -0.9, 0.9, 10, col, w * 0.8)
		"landslide":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.85, s * 0.6), c + Vector2(-s * 0.35, -s * 0.5), c + Vector2(s * 0.1, s * 0.6)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.15, s * 0.6), c + Vector2(s * 0.35, -s * 0.8), c + Vector2(s * 0.85, s * 0.6)]), col)
		"wisp":
			ci.draw_circle(c + Vector2(s * 0.3, -s * 0.3), s * 0.38, col)
			ci.draw_line(c + Vector2(s * 0.05, -s * 0.05), c + Vector2(-s * 0.75, s * 0.75), Color(col, 0.7), w * 1.4)
		"snare":
			ci.draw_colored_polygon(star_pts(c, s * 0.85, s * 0.38), col)
		"hop":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.8), c + Vector2(s * 0.45, 0), c + Vector2(0, s * 0.8), c + Vector2(-s * 0.45, 0)]), col)
			ci.draw_circle(c + Vector2(-s * 0.75, -s * 0.55), s * 0.12, col)
			ci.draw_circle(c + Vector2(s * 0.75, s * 0.5), s * 0.1, col)
		"bloom":
			for i in 5:
				ci.draw_circle(c + Vector2.from_angle(i * TAU / 5.0 - PI / 2) * s * 0.45, s * 0.3, col)
			ci.draw_circle(c, s * 0.22, Color(1, 0.9, 0.4))
		"ember":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.9), c + Vector2(s * 0.5, -s * 0.1), c + Vector2(s * 0.4, s * 0.5), c + Vector2(0, s * 0.8), c + Vector2(-s * 0.4, s * 0.5), c + Vector2(-s * 0.5, -s * 0.1), c + Vector2(-s * 0.15, -s * 0.3)]), col)
		"fang":
			ci.draw_line(c + Vector2(-s * 0.7, -s * 0.6), c + Vector2(s * 0.3, s * 0.8), col, w * 1.2)
			ci.draw_line(c + Vector2(-s * 0.2, -s * 0.8), c + Vector2(s * 0.75, s * 0.5), col, w * 1.2)
		"smoke":
			ci.draw_circle(c + Vector2(-s * 0.35, s * 0.15), s * 0.4, col)
			ci.draw_circle(c + Vector2(s * 0.3, s * 0.2), s * 0.38, col)
			ci.draw_circle(c + Vector2(0, -s * 0.3), s * 0.42, col)
		"petals":
			for i in 5:
				var d := Vector2.from_angle(i * TAU / 5.0)
				ci.draw_colored_polygon(ellipse_pts(c + d * s * 0.42, s * 0.36, s * 0.16), col)
			ci.draw_circle(c, s * 0.18, col)
		"mend":
			ci.draw_colored_polygon(ellipse_pts(c + Vector2(-s * 0.25, s * 0.1), s * 0.3, s * 0.55), col)
			ci.draw_colored_polygon(ellipse_pts(c + Vector2(s * 0.25, s * 0.1), s * 0.3, s * 0.55), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.85), Vector2(s * 0.16, s * 0.5)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.25, -s * 0.68), Vector2(s * 0.5, s * 0.16)), col)
		"ward":
			ci.draw_arc(c, s * 0.75, 0, TAU, 24, col, w)
			for i in 4:
				ci.draw_circle(c + Vector2.from_angle(i * PI * 0.5 + PI * 0.25) * s * 0.28, s * 0.22, col)
		"lullaby":
			ci.draw_circle(c + Vector2(-s * 0.35, s * 0.45), s * 0.25, col)
			ci.draw_circle(c + Vector2(s * 0.45, s * 0.3), s * 0.25, col)
			ci.draw_line(c + Vector2(-s * 0.12, s * 0.45), c + Vector2(-s * 0.12, -s * 0.6), col, w)
			ci.draw_line(c + Vector2(s * 0.68, s * 0.3), c + Vector2(s * 0.68, -s * 0.75), col, w)
			ci.draw_line(c + Vector2(-s * 0.12, -s * 0.6), c + Vector2(s * 0.68, -s * 0.75), col, w * 1.4)
		"chorus":
			ci.draw_arc(c, s * 0.8, 0, TAU, 24, col, w * 0.8)
			ci.draw_circle(c + Vector2(-s * 0.1, s * 0.25), s * 0.22, col)
			ci.draw_line(c + Vector2(s * 0.1, s * 0.25), c + Vector2(s * 0.1, -s * 0.5), col, w)
			ci.draw_line(c + Vector2(s * 0.1, -s * 0.5), c + Vector2(s * 0.4, -s * 0.3), col, w)
		"quake":
			ci.draw_arc(c + Vector2(0, s * 0.3), s * 0.8, PI * 1.1, PI * 1.9, 14, col, w * 1.3)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.15), Vector2(s * 0.6, s * 0.35)), col)
			ci.draw_line(c + Vector2(0, s * 0.2), c + Vector2(0, s * 0.85), col, w)
		"leap":
			ci.draw_arc(c + Vector2(0, s * 0.6), s * 0.75, PI * 1.05, PI * 1.95, 14, col, w)
			var e2 := c + Vector2(s * 0.72, s * 0.45)
			ci.draw_colored_polygon(PackedVector2Array([e2 + Vector2(s * 0.1, s * 0.3), e2 + Vector2(-s * 0.28, 0), e2 + Vector2(s * 0.22, -s * 0.1)]), col)
			ci.draw_line(c + Vector2(-s * 0.8, s * 0.8), c + Vector2(s * 0.8, s * 0.8), col, w * 0.8)
		"hunger":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.8), c + Vector2(-s * 0.7, -s * 0.05), c + Vector2(-s * 0.4, -s * 0.6), c + Vector2(0, -s * 0.3), c + Vector2(s * 0.4, -s * 0.6), c + Vector2(s * 0.7, -s * 0.05)]), col)
			ci.draw_line(c + Vector2(-s * 0.2, -s * 0.1), c + Vector2(s * 0.15, s * 0.2), Color(0, 0, 0, 0.5), w)
		"anvil":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.45), c + Vector2(s * 0.8, -s * 0.45), c + Vector2(s * 0.5, -s * 0.1), c + Vector2(s * 0.25, -s * 0.1), c + Vector2(s * 0.35, s * 0.3), c + Vector2(-s * 0.35, s * 0.3), c + Vector2(-s * 0.25, -s * 0.1), c + Vector2(-s * 0.5, -s * 0.1)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.5, s * 0.35), Vector2(s * 1.0, s * 0.2)), col)
			for i in 3:
				ci.draw_line(c + Vector2((i - 1) * s * 0.4, -s * 0.95), c + Vector2((i - 1) * s * 0.4, -s * 0.6), col, w * 0.7)
		"attack_bow":
			ci.draw_arc(c + Vector2(-s * 0.2, 0), s * 0.8, -1.2, 1.2, 14, col, w)
			ci.draw_line(c + Vector2(-s * 0.2, 0) + Vector2.from_angle(-1.2) * s * 0.8, c + Vector2(-s * 0.2, 0) + Vector2.from_angle(1.2) * s * 0.8, col, 1.5)
			ci.draw_line(c + Vector2(-s * 0.9, 0), c + Vector2(s * 0.8, 0), col, w * 0.8)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.95, 0), c + Vector2(s * 0.6, -s * 0.2), c + Vector2(s * 0.6, s * 0.2)]), col)
		"attack_sword":
			ci.draw_line(c + Vector2(-s * 0.6, s * 0.6), c + Vector2(s * 0.7, -s * 0.7), col, w * 1.3)
			ci.draw_line(c + Vector2(-s * 0.55, s * 0.15), c + Vector2(-s * 0.15, s * 0.55), col, w * 1.1)
		"recall":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.8), c + Vector2(s * 0.8, -s * 0.05), c + Vector2(s * 0.55, -s * 0.05), c + Vector2(s * 0.55, s * 0.7), c + Vector2(-s * 0.55, s * 0.7), c + Vector2(-s * 0.55, -s * 0.05), c + Vector2(-s * 0.8, -s * 0.05)]), col)
		"heal":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, -s * 0.7), Vector2(s * 0.4, s * 1.4)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.2), Vector2(s * 1.4, s * 0.4)), col)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.5, -s * 0.6), Vector2(s * 0.35, s * 1.2)), col)
			ci.draw_rect(Rect2(c + Vector2(s * 0.15, -s * 0.6), Vector2(s * 0.35, s * 1.2)), col)
		"coin":
			ci.draw_circle(c, s * 0.7, Color("e0a422"))
			ci.draw_circle(c, s * 0.52, GOLD)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.3), Vector2(s * 0.2, s * 0.6)), Color("e0a422"))
		_:
			ci.draw_circle(c, s * 0.5, col)


## Tower: dark round base, team ring, white diamond core.
static func draw_tower(ci: CanvasItem, c: Vector2, r: float, team: int, alive := true) -> void:
	if not alive:
		for i in 7:
			ci.draw_circle(c + Vector2.from_angle(i * 1.7) * r * 0.5, r * (0.22 + 0.05 * (i % 3)), Color(0.35, 0.33, 0.32))
		return
	ci.draw_colored_polygon(ellipse_pts(c + Vector2(0, r * 0.35), r * 1.05, r * 0.6), Color(0, 0, 0, 0.25))
	ci.draw_circle(c, r, Color("262b38"))
	ci.draw_arc(c, r - 4, 0, TAU, 40, team_color(team), 7.0, true)
	var d := r * 0.5
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), Color(1, 1, 1))
	var d2 := r * 0.24
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d2), c + Vector2(d2, 0), c + Vector2(0, d2), c + Vector2(-d2, 0)]), team_color(team))


## Heartspire: big crystal on a stone pad.
static func draw_heartspire(ci: CanvasItem, c: Vector2, r: float, team: int, alive := true, pulse := 0.0) -> void:
	if not alive:
		for i in 9:
			ci.draw_circle(c + Vector2.from_angle(i * 1.3) * r * 0.55, r * (0.15 + 0.06 * (i % 3)), Color(0.4, 0.38, 0.4))
		return
	var tc := team_color(team)
	ci.draw_colored_polygon(ellipse_pts(c + Vector2(0, r * 0.45), r * 1.1, r * 0.55), Color(0, 0, 0, 0.3))
	ci.draw_circle(c, r * (1.15 + 0.05 * pulse), Color(tc, 0.18))
	var pts := PackedVector2Array()
	for i in 5:
		pts.append(c + Vector2.from_angle(-PI / 2 + i * TAU / 5.0) * r * 0.85)
	ci.draw_colored_polygon(pts, tc)
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c]), tc.lightened(0.35))
	ci.draw_colored_polygon(PackedVector2Array([pts[0], c, pts[4]]), tc.lightened(0.15))
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.9), 3.0, true)
	ci.draw_circle(c, r * 0.18, Color(1, 1, 1, 0.9))
