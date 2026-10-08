class_name Scoreboard
extends Control
## Full scoreboard (opened by tapping the score/timer or the SCORE button). Lists all 6 heroes
## grouped by team: portrait, name, role, K/D/A, gold and the items they own, plus your hero's
## recommended build path. Drawn in code; HudCanvas forwards taps to press() while it is open.

var arena: Arena
var font: Font
var rects := {}
var tab := 0  # 0 = score, 1 = recommended build


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func open() -> void:
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func press(pos: Vector2) -> bool:
	var pr := _panel()
	if not pr.has_point(pos) or (rects.get("close", Rect2()) as Rect2).grow(8).has_point(pos):
		close()
		return true
	for i in 2:
		if (rects.get("tab%d" % i, Rect2()) as Rect2).has_point(pos):
			tab = i
			_click()
			return true
	return true


func _click() -> void:
	var s := get_node_or_null("/root/Sfx")
	if s != null:
		s.play("click", -8.0)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _panel() -> Rect2:
	var w := minf(size.x - 28.0, 1040.0)
	var h := minf(size.y - 40.0, 560.0)
	return Rect2(size.x * 0.5 - w * 0.5, maxf(20.0, size.y * 0.5 - h * 0.5), w, h)


func _text(pos: Vector2, s: String, sz: int, col: Color, align := 0, outline := 0) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var x := pos.x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	if outline > 0:
		draw_string_outline(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, outline, Color(0, 0, 0, 0.75 * col.a))
	draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _box(r: Rect2, bg: Color, border: Color, radius := 10, bw := 2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)


func _draw() -> void:
	if arena == null or arena.player == null:
		return
	rects.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.5))
	var pr := _panel()
	_box(pr, Color(0.07, 0.08, 0.12, 0.97), Color(1, 1, 1, 0.25), 16, 3)
	_text(pr.position + Vector2(20, 36), "SCOREBOARD", 24, Color.WHITE, 0, 4)
	var cr := Rect2(pr.end.x - 52.0, pr.position.y + 10.0, 40.0, 36.0)
	rects["close"] = cr
	_box(cr, Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.3), 10, 2)
	draw_line(cr.get_center() + Vector2(-8, -8), cr.get_center() + Vector2(8, 8), Color.WHITE, 3.0, true)
	draw_line(cr.get_center() + Vector2(8, -8), cr.get_center() + Vector2(-8, 8), Color.WHITE, 3.0, true)
	var tabs := ["MATCH", "RECOMMENDED BUILD"]
	var tx := pr.position.x + 230.0
	for i in 2:
		var tw := font.get_string_size(tabs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 30.0
		var tr := Rect2(tx, pr.position.y + 12.0, tw, 30.0)
		rects["tab%d" % i] = tr
		_box(tr, Color(1, 1, 1, 0.14 if tab == i else 0.05), Color("ffd36b") if tab == i else Color(1, 1, 1, 0.2), 14, 2)
		_text(Vector2(tr.get_center().x, tr.position.y + 21), tabs[i], 15, Color.WHITE, 1)
		tx += tw + 10.0
	if tab == 0:
		_draw_teams(pr)
	else:
		_draw_build(pr)


func _draw_teams(pr: Rect2) -> void:
	var col_w := (pr.size.x - 36.0) * 0.5
	for t in 2:
		var x0 := pr.position.x + 14.0 + t * (col_w + 8.0)
		var y := pr.position.y + 62.0
		var head := Rect2(x0, y, col_w - 6.0, 28.0)
		_box(head, Color(Art.team_color(t), 0.25), Color(Art.team_color(t), 0.8), 8, 2)
		_text(Vector2(x0 + 12, y + 20), "DAWN" if t == 0 else "DUSK", 16, Art.team_color(t).lightened(0.3), 0, 3)
		_text(Vector2(head.end.x - 10, y + 20), str(arena.kills[t]), 18, Color.WHITE, 2, 3)
		y += 34.0
		var list: Array = []
		for h in arena.heroes:
			if h.team == t:
				list.append(h)
		var row_h := minf(118.0, (pr.end.y - y - 12.0) / maxf(list.size(), 1))
		for h in list:
			_draw_row(Rect2(x0, y, col_w - 6.0, row_h - 6.0), h)
			y += row_h


func _draw_row(r: Rect2, h: Hero) -> void:
	var mine := h == arena.player
	_box(r, Color(1, 1, 1, 0.09 if mine else 0.04), Art.PLAYER if mine else Color(1, 1, 1, 0.12), 10, 2 if mine else 1)
	var d: Dictionary = {}
	var canvas := get_parent() as HudCanvas
	if canvas != null:
		d = canvas.team_icons.get(h, {})
	var tex: Texture2D = d.get("tex", null)
	var pc := r.position + Vector2(30, r.size.y * 0.42)
	draw_circle(pc, 22.0, Color(h.data.body_color.darkened(0.4), 0.9))
	if tex != null:
		draw_texture_rect(tex, Rect2(pc - Vector2(22, 23), Vector2(44, 44)), false, Color(1, 1, 1, 1.0 if h.alive else 0.45))
	draw_arc(pc, 22.0, 0, TAU, 28, Art.team_color(h.team) if h.alive else Color(0.5, 0.5, 0.5), 2.0, true)
	if not h.alive:
		_text(pc + Vector2(0, 6), str(ceili(h.respawn_t)), 15, Color.WHITE, 1, 3)
	var x := r.position.x + 60.0
	_text(Vector2(x, r.position.y + 22), h.data.display_name + ("  (you)" if mine else ""), 16, Color.WHITE, 0, 3)
	_text(Vector2(x, r.position.y + 40), "Lv%d  %s" % [h.level, h.data.role_name()], 13, h.data.role_color().lightened(0.2))
	_text(Vector2(r.end.x - 12, r.position.y + 24), "%d / %d / %d" % [h.kills, h.deaths, h.assists], 16, Color.WHITE, 2, 3)
	_text(Vector2(r.end.x - 12, r.position.y + 42), "K/D/A", 11, Color(1, 1, 1, 0.5), 2)
	Art.draw_icon(self, "coin", Vector2(x + 8, r.position.y + 60), 8.0)
	_text(Vector2(x + 20, r.position.y + 65), str(h.gold), 14, Art.GOLD)
	var ix := x + 90.0
	for i in 6:
		var ir := Rect2(ix + i * 38.0, r.position.y + 47.0, 34.0, 30.0)
		_box(ir, Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.14), 6, 1)
		if i < h.items.size():
			var it: ItemData = h.items[i]
			ItemIcons.draw(self, it.icon, ir.get_center(), 13.0, it.color)


func _draw_build(pr: Rect2) -> void:
	var p := arena.player
	var build: BuildData = null
	for b in arena.config.recommended_builds:
		if b != null and b.hero == p.data:
			build = b
	var y := pr.position.y + 72.0
	_text(Vector2(pr.position.x + 22, y), "Recommended for %s (%s)" % [p.data.display_name, p.data.role_name()], 18, Color("ffd36b"), 0, 3)
	y += 16.0
	if build == null:
		_text(Vector2(pr.position.x + 22, y + 30), "No recommended build set for this hero.", 16, Color.WHITE)
		return
	var x := pr.position.x + 22.0
	var card_w := minf(150.0, (pr.size.x - 44.0 - (build.items.size() - 1) * 28.0) / build.items.size())
	for i in build.items.size():
		var it: ItemData = build.items[i]
		var owned := Shop.has_or_built(p, it)
		var r := Rect2(x, y + 14.0, card_w, minf(250.0, pr.end.y - y - 80.0))
		_box(r, Color(1, 1, 1, 0.06), Color("7fe08a") if owned else Color(1, 1, 1, 0.16), 12, 2)
		_text(Vector2(r.get_center().x, r.position.y + 24), "%d" % (i + 1), 14, Color(1, 1, 1, 0.6), 1)
		var ic := Vector2(r.get_center().x, r.position.y + 64)
		draw_circle(ic, 26.0, Color(it.color.darkened(0.7), 0.95))
		ItemIcons.draw(self, it.icon, ic, 20.0, it.color)
		_text(Vector2(r.get_center().x, ic.y + 46), it.display_name, 14, Color.WHITE, 1)
		var price := Shop.price_for(p, it)
		if owned:
			_text(Vector2(r.get_center().x, ic.y + 68), "OWNED", 13, Color("7fe08a"), 1)
		else:
			Art.draw_icon(self, "coin", Vector2(r.get_center().x - 22, ic.y + 64), 7.0)
			_text(Vector2(r.get_center().x - 8, ic.y + 68), str(price), 14, Art.GOLD if p.gold >= price else Color("ff7a6a"))
		var ly := ic.y + 92.0
		for line in it.stat_lines():
			_text(Vector2(r.position.x + 10, ly), line, 12, Color("ffe9a8"))
			ly += 16.0
		x += card_w + 28.0
		if i < build.items.size() - 1:
			_text(Vector2(x - 16, r.position.y + r.size.y * 0.5), ">", 22, Color(1, 1, 1, 0.5), 1)
	var hy := minf(y + 14.0 + 250.0, pr.end.y - 66.0) + 34.0
	_text(Vector2(pr.position.x + 22, hy), "A gold popup by the SHOP button offers the next item when you can afford it (buy at your fountain).", 14, Color(1, 1, 1, 0.7))
	_text(Vector2(pr.position.x + 22, hy + 22), "Bots follow these builds too. Edit them in data/builds/%s.tres." % String(p.data.id), 14, Color(1, 1, 1, 0.5))
