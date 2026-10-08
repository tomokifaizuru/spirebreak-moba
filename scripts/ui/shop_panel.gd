class_name ShopPanel
extends Control
## The in-match shop (opened from the SHOP button / Tab). Drawn in code like the rest of the HUD;
## HudCanvas forwards touches to press() while it is open. The match keeps running.
## Tap an item to see its stats and recipe, then BUY. Upgrades show their components; the ones
## you already own are consumed, missing ones are bought along with the recipe.

var canvas: HudCanvas
var arena: Arena
var font: Font
var selected: ItemData = null
var rects := {}
var flash_t := 0.0
var flash_msg := ""
var flash_ok := true


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func catalog() -> ItemCatalog:
	return arena.config.item_catalog if arena != null else null


func open() -> void:
	if catalog() == null:
		return
	visible = true
	if selected == null:
		var nx := arena.player.brain.next_item()
		selected = nx if nx != null else catalog().basic[0]
	queue_redraw()


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		flash_t -= delta
		queue_redraw()


func _panel_rect() -> Rect2:
	var w := minf(size.x - 40.0, 1000.0)
	var h := minf(size.y - 80.0, 500.0)
	return Rect2(size.x * 0.5 - w * 0.5, maxf(56.0, size.y * 0.5 - h * 0.5 - 10.0), w, h)


## Returns true (always consumes the touch while open).
func press(pos: Vector2) -> bool:
	var pr := _panel_rect()
	if not pr.has_point(pos) or (rects.get("close", Rect2()) as Rect2).grow(8).has_point(pos):
		close()
		return true
	for k in rects:
		if k is ItemData and (rects[k] as Rect2).has_point(pos):
			selected = k
			_click()
			return true
	if (rects.get("buy", Rect2()) as Rect2).has_point(pos) and selected != null:
		_try_buy()
		return true
	for i in 6:
		var key := "slot%d" % i
		if rects.has(key) and (rects[key] as Rect2).has_point(pos) and i < arena.player.items.size():
			selected = arena.player.items[i]
			_click()
			return true
	return true


func _click() -> void:
	var s := get_node_or_null("/root/Sfx")
	if s != null:
		s.play("click", -8.0)


func _try_buy() -> void:
	var p := arena.player
	var why := Shop.block_reason(p, selected)
	if why == "" and Shop.buy(p, selected):
		flash_msg = "Bought %s!" % selected.display_name
		flash_ok = true
	else:
		flash_msg = why
		flash_ok = false
	flash_t = 1.6


# ---------------- drawing ----------------

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
	if arena == null or arena.player == null or catalog() == null:
		return
	rects.clear()
	var p := arena.player
	var at_base := Shop.can_shop_here(p)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.45))
	var pr := _panel_rect()
	_box(pr, Color(0.07, 0.08, 0.12, 0.96), Color(0.95, 0.78, 0.35, 0.55), 16, 3)
	# header
	_text(pr.position + Vector2(22, 38), "SHOP", 28, Color("ffd36b"), 0, 4)
	var gx := pr.position.x + 120.0
	Art.draw_icon(self, "coin", Vector2(gx + 10, pr.position.y + 28), 12.0)
	_text(Vector2(gx + 28, pr.position.y + 36), str(p.gold), 22, Art.GOLD)
	var status := "At base: buying enabled" if at_base else "Return to base to buy (Recall: B)"
	var scol := Color("7fe08a") if at_base else Color("ff8a6a")
	var sw := font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 26.0
	var sr := Rect2(pr.get_center().x - sw * 0.5 + 40.0, pr.position.y + 14, sw, 30)
	_box(sr, Color(scol, 0.14), Color(scol, 0.7), 14, 2)
	_text(Vector2(sr.get_center().x, sr.position.y + 21), status, 15, scol, 1)
	var cr := Rect2(pr.end.x - 54.0, pr.position.y + 10.0, 42.0, 38.0)
	rects["close"] = cr
	_box(cr, Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.3), 10, 2)
	draw_line(cr.get_center() + Vector2(-9, -9), cr.get_center() + Vector2(9, 9), Color.WHITE, 3.0, true)
	draw_line(cr.get_center() + Vector2(9, -9), cr.get_center() + Vector2(-9, 9), Color.WHITE, 3.0, true)
	# item grids
	var left_w := pr.size.x * 0.62
	var gx0 := pr.position.x + 18.0
	var y := pr.position.y + 64.0
	var cols := 4
	var tw := (left_w - 18.0 - (cols - 1) * 8.0) / cols
	var th := minf(74.0, (pr.size.y - 64.0 - 2 * 24.0 - 3 * 8.0 - 60.0) / 4.0)
	for group in [["BASIC ITEMS", catalog().basic], ["UPGRADES  (components + recipe)", catalog().upgraded]]:
		_text(Vector2(gx0, y + 14), group[0], 14, Color(1, 1, 1, 0.6))
		y += 22.0
		var list: Array = group[1]
		for i in list.size():
			var it: ItemData = list[i]
			var r := Rect2(gx0 + (i % cols) * (tw + 8.0), y + (i / cols) * (th + 8.0), tw, th)
			rects[it] = r
			_draw_tile(r, it, p)
		y += ceili(list.size() / float(cols)) * (th + 8.0) + 4.0
	# recommended path for your hero
	_draw_recommended(Rect2(gx0, pr.end.y - 50.0, left_w - 18.0, 40.0), p)
	# detail pane
	var dr := Rect2(pr.position.x + left_w + 10.0, pr.position.y + 60.0, pr.size.x - left_w - 28.0, pr.size.y - 74.0)
	_box(dr, Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.12), 12, 1)
	if selected != null:
		_draw_detail(dr, selected, p, at_base)


func _draw_recommended(r: Rect2, p: Hero) -> void:
	var build: BuildData = null
	for b in arena.config.recommended_builds:
		if b != null and b.hero == p.data:
			build = b
	if build == null:
		return
	_box(r, Color(1, 0.85, 0.4, 0.07), Color(1, 0.85, 0.4, 0.35), 10, 1)
	_text(r.position + Vector2(10, 25), "RECOMMENDED", 12, Color("ffd36b"))
	var x := r.position.x + 108.0
	for i in build.items.size():
		var it: ItemData = build.items[i]
		var c := Vector2(x + 16, r.get_center().y)
		var owned := Shop.has_or_built(p, it)
		draw_circle(c, 15.0, Color(it.color.darkened(0.7), 0.95))
		draw_arc(c, 15.0, 0, TAU, 20, Color("7fe08a") if owned else Color(1, 1, 1, 0.25), 2.0, true)
		ItemIcons.draw(self, it.icon, c, 11.0, it.color)
		rects[it] = Rect2(c - Vector2(16, 16), Vector2(32, 32)) if not rects.has(it) else rects[it]
		x += 40.0
		if i < build.items.size() - 1:
			_text(Vector2(x + 2, r.get_center().y + 5), ">", 14, Color(1, 1, 1, 0.5), 1)
			x += 14.0


func _draw_tile(r: Rect2, it: ItemData, p: Hero) -> void:
	var owned := Shop.owns(p, it)
	var price := Shop.price_for(p, it)
	var afford := p.gold >= price
	var sel := it == selected
	var border := Color("ffd36b") if sel else (Color("7fe08a", 0.8) if owned else Color(1, 1, 1, 0.16))
	_box(r, Color(1, 1, 1, 0.1 if sel else 0.05), border, 10, 3 if sel else 2)
	var ic := r.position + Vector2(30, r.size.y * 0.5)
	draw_circle(ic, 23.0, Color(it.color.darkened(0.7), 0.9))
	ItemIcons.draw(self, it.icon, ic, 18.0, it.color, 1.0 if (afford or owned) else 0.55)
	var nm := it.display_name
	var maxw := r.size.x - 62.0 - (16.0 if it.tier == 2 else 0.0)
	var sz := 13
	while sz > 10 and font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > maxw:
		sz -= 1
	_text(r.position + Vector2(58, 26), nm, sz, Color.WHITE)
	if owned:
		_text(r.position + Vector2(58, r.size.y - 16), "OWNED", 13, Color("7fe08a"))
	else:
		Art.draw_icon(self, "coin", r.position + Vector2(65, r.size.y - 21), 7.0)
		_text(r.position + Vector2(76, r.size.y - 16), str(price), 15, Art.GOLD if afford else Color("ff7a6a"))
	if it.tier == 2 and not owned and price < it.total_cost():
		# you own part of the recipe: cyan "combine" badge
		var bc := Vector2(r.end.x - 13.0, r.position.y + 13.0)
		draw_circle(bc, 8.0, Color("1c6f86"))
		draw_arc(bc, 8.0, 0, TAU, 16, Color("8fe8ff"), 1.5, true)
		draw_colored_polygon(PackedVector2Array([bc + Vector2(0, -5), bc + Vector2(4, 0), bc + Vector2(-4, 0)]), Color.WHITE)
		draw_line(bc + Vector2(0, 0), bc + Vector2(0, 4), Color.WHITE, 2.0)


func _draw_detail(dr: Rect2, it: ItemData, p: Hero, at_base: bool) -> void:
	var x := dr.position.x + 14.0
	var y := dr.position.y + 14.0
	var ic := Vector2(x + 30, y + 30)
	draw_circle(ic, 30.0, Color(it.color.darkened(0.7), 0.95))
	draw_arc(ic, 30.0, 0, TAU, 32, Color(it.color, 0.8), 2.0, true)
	ItemIcons.draw(self, it.icon, ic, 23.0, it.color)
	_text(Vector2(x + 72, y + 24), it.display_name, 19, Color.WHITE, 0, 3)
	_text(Vector2(x + 72, y + 46), "Upgraded item" if it.tier == 2 else "Basic item", 13, Color("8fe8ff") if it.tier == 2 else Color(1, 1, 1, 0.55))
	y += 76.0
	for line in it.stat_lines():
		_text(Vector2(x, y), "• " + line, 15, Color("ffe9a8"))
		y += 21.0
	draw_multiline_string(font, Vector2(x, y + 2), it.description, HORIZONTAL_ALIGNMENT_LEFT, dr.size.x - 28.0, 13, 2, Color(1, 1, 1, 0.65))
	y += 26.0 if font.get_string_size(it.description, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x < dr.size.x - 28.0 else 42.0
	if it.tier == 2:
		_text(Vector2(x, y), "Recipe:", 14, Color(1, 1, 1, 0.75))
		y += 8.0
		var cx := x
		var used := Shop.consumed_items(p, it)
		for cr in it.components:
			var c := cr as ItemData
			if c == null:
				continue
			var have := false
			for u in used:
				if (u as ItemData).id == c.id:
					have = true
			var cc := Vector2(cx + 18, y + 22)
			draw_circle(cc, 17.0, Color(c.color.darkened(0.7), 0.95))
			draw_arc(cc, 17.0, 0, TAU, 24, Color("7fe08a") if have else Color(1, 1, 1, 0.25), 2.0, true)
			ItemIcons.draw(self, c.icon, cc, 13.0, c.color)
			_text(cc + Vector2(0, 32), "owned" if have else str(c.total_cost()), 11, Color("7fe08a") if have else Art.GOLD, 1)
			cx += 44.0
			_text(Vector2(cx - 4, y + 28), "+", 18, Color(1, 1, 1, 0.6), 1)
			cx += 8.0
		_text(Vector2(cx + 4, y + 22), "recipe", 11, Color(1, 1, 1, 0.6))
		_text(Vector2(cx + 4, y + 40), str(it.cost), 14, Art.GOLD)
		y += 60.0
	else:
		var ups: Array = []
		for u2 in catalog().upgraded:
			for c2 in u2.components:
				if c2 != null and c2.id == it.id:
					ups.append(u2.display_name)
		if not ups.is_empty():
			_text(Vector2(x, y), "Builds into: " + ", ".join(ups), 13, Color("8fe8ff"))
			y += 22.0
	# your items
	var sy := dr.end.y - 136.0
	_text(Vector2(x, sy), "Your items (%d/%d)" % [p.items.size(), arena.config.item_slots], 13, Color(1, 1, 1, 0.6))
	for i in 6:
		var r := Rect2(x + i * 44.0, sy + 8.0, 38.0, 38.0)
		rects["slot%d" % i] = r
		_box(r, Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.18), 8, 1)
		if i < p.items.size():
			var o: ItemData = p.items[i]
			ItemIcons.draw(self, o.icon, r.get_center(), 15.0, o.color)
	# buy button
	var br := Rect2(x, dr.end.y - 58.0, dr.size.x - 28.0, 46.0)
	rects["buy"] = br
	var why := Shop.block_reason(p, it)
	var price := Shop.price_for(p, it)
	var ok := why == ""
	var label := ""
	if Shop.owns(p, it):
		label = "OWNED"
	elif not at_base:
		label = "RETURN TO BASE"
	elif ok:
		label = ("COMBINE  %d" if it.tier == 2 and price < it.total_cost() else "BUY  %d") % price
	else:
		label = why.to_upper()
	_box(br, Color("2f9d5a") if ok else Color(0.3, 0.32, 0.38, 0.9), Color(1, 1, 1, 0.5 if ok else 0.2), 12, 2)
	_text(Vector2(br.get_center().x, br.position.y + 30), label, 18, Color.WHITE if ok else Color(1, 1, 1, 0.6), 1, 3)
	if flash_t > 0.0 and flash_msg != "":
		var a := clampf(flash_t * 2.0, 0.0, 1.0)
		_text(Vector2(br.get_center().x, br.position.y - 10), flash_msg, 15, Color(Color("7fe08a") if flash_ok else Color("ff8a6a"), a), 1, 3)
