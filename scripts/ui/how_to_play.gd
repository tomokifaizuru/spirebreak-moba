class_name HowToPlay
extends Control
## Picture-book "How to Play": a few swipeable cards with drawings and very short captions.
## Swipe left/right (or the big Back / Next buttons / arrow keys) to change page. PC keys live on the last,
## optional card. Everything is drawn in code, so there are no image files to keep in sync.

signal closed

const PAGES := ["goal", "controls", "danger", "farm", "shop", "pc"]
const TITLES := {
	"goal": "1  ·  The Goal",
	"controls": "2  ·  Phone Controls",
	"danger": "3  ·  Watch Out!",
	"farm": "4  ·  Get Gold & Levels",
	"shop": "5  ·  Shop & Items",
	"pc": "Extra  ·  Playing on PC",
}

var page := 0
var t := 0.0
var font: Font
var canvas: Control
var back_btn: Button
var next_btn: Button
var swipe_from := Vector2.INF


func _ready() -> void:
	font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_page)
	add_child(canvas)
	back_btn = MatchHud.make_button("<  Back", Color("3d4a6b"), 190.0)
	back_btn.custom_minimum_size = Vector2(190, 76)
	back_btn.add_theme_font_size_override("font_size", 28)
	back_btn.pressed.connect(func() -> void: go(page - 1))
	add_child(back_btn)
	next_btn = MatchHud.make_button("Next  >", Color("2f9d5a"), 190.0)
	next_btn.custom_minimum_size = Vector2(190, 76)
	next_btn.add_theme_font_size_override("font_size", 28)
	next_btn.pressed.connect(func() -> void:
		if page >= PAGES.size() - 2:
			if page == PAGES.size() - 2:
				close()
			else:
				go(0)
		else:
			go(page + 1))
	add_child(next_btn)
	var x := MatchHud.make_button("X", Color("6b3d4a"), 64.0)
	x.custom_minimum_size = Vector2(64, 64)
	x.add_theme_font_size_override("font_size", 30)
	x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	x.position = Vector2(-84, 18)
	x.pressed.connect(close)
	add_child(x)
	resized.connect(_layout)
	_layout()
	_refresh()


func open() -> void:
	page = 0
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


func go(p: int) -> void:
	page = clampi(p, 0, PAGES.size() - 1)
	Sfx.play("click", -8.0)
	_refresh()


func _refresh() -> void:
	back_btn.disabled = page == 0
	back_btn.modulate.a = 0.35 if page == 0 else 1.0
	if page == PAGES.size() - 2:
		next_btn.text = "Play!"
	elif page == PAGES.size() - 1:
		next_btn.text = "Start over"
	else:
		next_btn.text = "Next  >"
	canvas.queue_redraw()


func _layout() -> void:
	var s := size
	back_btn.position = Vector2(s.x * 0.5 - 230 - 95, s.y - 96)
	next_btn.position = Vector2(s.x * 0.5 + 230 - 95, s.y - 96)


func _process(d: float) -> void:
	if visible:
		t += d
		canvas.queue_redraw()


func _gui_input(e: InputEvent) -> void:
	var pressed := false
	var pos := Vector2.ZERO
	if e is InputEventScreenTouch:
		pressed = e.pressed
		pos = e.position
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pressed = e.pressed
		pos = e.position
	else:
		return
	if pressed:
		swipe_from = pos
	elif swipe_from != Vector2.INF:
		var dx := pos.x - swipe_from.x
		swipe_from = Vector2.INF
		if absf(dx) > 70.0:
			go(page + (1 if dx < 0.0 else -1))
		elif _pc_chip_rect().has_point(pos):
			go(PAGES.size() - 1)


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not e.is_pressed():
		return
	if e.is_action("ui_right"):
		go(page + 1)
	elif e.is_action("ui_left"):
		go(page - 1)
	elif e.is_action("ui_cancel"):
		close()
	get_viewport().set_input_as_handled()


func _pc_chip_rect() -> Rect2:
	return Rect2(Vector2(size.x - 196, size.y - 150), Vector2(176, 44))


# ---------------------------------------------------------------- drawing

func _txt(p: Vector2, s: String, sz: int, col := Color.WHITE, w := 600.0) -> void:
	var x := p.x - w * 0.5
	canvas.draw_string_outline(font, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_CENTER, w, sz, maxi(4, sz / 5), Color(0, 0, 0, 0.75))
	canvas.draw_string(font, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_CENTER, w, sz, col)


func _panel(r: Rect2, col := Color(0.11, 0.13, 0.2, 0.95), rad := 22) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(rad)
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.set_border_width_all(2)
	canvas.draw_style_box(sb, r)


func _arrow(a: Vector2, b: Vector2, col: Color, w := 6.0) -> void:
	var d := (b - a).normalized()
	canvas.draw_line(a, b - d * 14.0, col, w, true)
	canvas.draw_colored_polygon(PackedVector2Array([b, b - d * 22.0 + d.orthogonal() * 13.0, b - d * 22.0 - d.orthogonal() * 13.0]), col)


func _round_btn(c: Vector2, r: float, col: Color, icon := "", label := "") -> void:
	canvas.draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.35))
	canvas.draw_circle(c, r, col)
	canvas.draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.55), 3.0, true)
	if icon != "":
		Art.draw_icon(canvas, icon, c, r * 0.55, Color.WHITE)
	if label != "":
		_txt(c + Vector2(0, 7), label, int(r * 0.42), Color.WHITE, r * 2.4)


func _tag(p: Vector2, s: String, col: Color, sz := 22) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 26.0
	_panel(Rect2(p - Vector2(w * 0.5, sz * 0.95), Vector2(w, sz * 1.5)), Color(col, 0.92), 12)
	_txt(p + Vector2(0, sz * 0.12), s, sz, Color.WHITE, w + 40.0)


func _keycap(c: Vector2, k: String, w := 46.0) -> void:
	var r := Rect2(c - Vector2(w * 0.5, 22), Vector2(w, 44))
	_panel(Rect2(r.position + Vector2(0, 4), r.size), Color(0.02, 0.02, 0.04, 0.9), 8)
	_panel(r, Color("e8ecf4"), 8)
	canvas.draw_string(font, Vector2(r.position.x, c.y + 8), k, HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color("1d2130"))


func _creep(c: Vector2, team: int, s := 1.0) -> void:
	canvas.draw_circle(c, 15.0 * s, Art.team_color(team))
	canvas.draw_circle(c + Vector2(-5, -3) * s, 3.5 * s, Color.WHITE)
	canvas.draw_circle(c + Vector2(5, -3) * s, 3.5 * s, Color.WHITE)
	canvas.draw_arc(c, 15.0 * s, 0, TAU, 20, Color(0, 0, 0, 0.6), 2.0, true)


func _coin(c: Vector2, r := 14.0) -> void:
	canvas.draw_circle(c, r, Art.GOLD)
	canvas.draw_arc(c, r * 0.7, 0, TAU, 20, Color("c08a1a"), 2.0, true)
	canvas.draw_arc(c, r, 0, TAU, 24, Color("8a5a10"), 2.0, true)


func _draw_page() -> void:
	var s := canvas.size
	var key: String = PAGES[page]
	_txt(Vector2(s.x * 0.5, 62), TITLES[key], 40, Art.GOLD, s.x)
	var card := Rect2(Vector2(s.x * 0.5 - 500, 88), Vector2(1000, s.y - 88 - 120))
	_panel(card)
	var c := card.get_center()
	match key:
		"goal":
			_page_goal(card, c)
		"controls":
			_page_controls(card, c)
		"danger":
			_page_danger(card, c)
		"farm":
			_page_farm(card, c)
		"shop":
			_page_shop(card, c)
		"pc":
			_page_pc(card, c)
	# page dots
	var n := PAGES.size() - 1
	for i in n:
		var dc := Vector2(s.x * 0.5 + (i - (n - 1) * 0.5) * 30.0, s.y - 58)
		canvas.draw_circle(dc, 9.0 if i == page else 6.0, Art.GOLD if i == page else Color(1, 1, 1, 0.35))
	if page < n:
		_panel(_pc_chip_rect(), Color(0.2, 0.24, 0.34, 0.95), 12)
		_txt(_pc_chip_rect().get_center() + Vector2(0, 7), "PC keys", 20, Color(1, 1, 1, 0.85), 176)


func _page_goal(card: Rect2, c: Vector2) -> void:
	var y := c.y - 30
	var lx := card.position.x + 110
	var rx := card.end.x - 110
	canvas.draw_rect(Rect2(Vector2(lx, y - 34), Vector2(rx - lx, 68)), Color("8a7a5a"))
	canvas.draw_rect(Rect2(Vector2(lx, y - 34), Vector2(rx - lx, 6)), Color("a8977a"))
	Art.draw_heartspire(canvas, Vector2(lx, y), 46.0, 0, true, t)
	Art.draw_heartspire(canvas, Vector2(rx, y), 46.0, 1, true, t)
	Art.draw_tower(canvas, Vector2(lx + 190, y), 30.0, 0)
	Art.draw_tower(canvas, Vector2(lx + 330, y), 30.0, 0)
	Art.draw_tower(canvas, Vector2(rx - 330, y), 30.0, 1)
	Art.draw_tower(canvas, Vector2(rx - 190, y), 30.0, 1)
	var k := fmod(t * 0.35, 1.0)
	Art.draw_hero(canvas, &"morrow", Vector2(lerpf(lx + 380, rx - 380, k), y - 4), 24.0, Vector2(1, 0))
	_tag(Vector2(lx, y + 92), "YOU", Art.DAWN_DARK)
	_tag(Vector2(rx, y + 92), "ENEMY", Art.DUSK_DARK)
	_tag(Vector2(rx - 260, y - 78), "2 towers each", Art.DUSK_DARK, 20)
	_arrow(Vector2(lx + 400, y + 70), Vector2(rx - 120, y + 70), Art.GOLD)
	_txt(Vector2(c.x, card.end.y - 70), "Break the 2 enemy towers,", 32)
	_txt(Vector2(c.x, card.end.y - 30), "then smash their Heartspire to win!", 32, Art.GOLD)


func _page_controls(card: Rect2, c: Vector2) -> void:
	# a phone in landscape
	var ph := Rect2(Vector2(c.x - 330, card.position.y + 30), Vector2(660, 250))
	_panel(Rect2(ph.position - Vector2(12, 12), ph.size + Vector2(24, 24)), Color("10131c"), 30)
	_panel(ph, Color("3c5a3a"), 14)
	Art.draw_hero(canvas, &"kestrel", ph.get_center() + Vector2(-20, 10), 24.0, Vector2(1, 0.2))
	# joystick
	var jc := ph.position + Vector2(105, 165)
	var wob := Vector2(cos(t * 2.0), sin(t * 2.0)) * 20.0
	canvas.draw_circle(jc, 54.0, Color(1, 1, 1, 0.15))
	canvas.draw_arc(jc, 54.0, 0, TAU, 40, Color(1, 1, 1, 0.5), 3.0, true)
	canvas.draw_circle(jc + wob, 24.0, Color(1, 1, 1, 0.75))
	# attack + skills
	var ac := ph.end - Vector2(80, 70)
	_round_btn(ac, 44.0, Color("d0662a"), "attack_bow")
	_round_btn(ac + Vector2(-96, 12), 26.0, Color("4a64b0"), "bolt")
	_round_btn(ac + Vector2(-74, -62), 26.0, Color("4a64b0"), "tumble")
	_round_btn(ac + Vector2(0, -96), 26.0, Color("4a64b0"), "mark")
	_round_btn(ac + Vector2(-150, -70), 28.0, Color("8a4ac0"), "volley")
	_round_btn(ph.position + Vector2(ph.size.x - 46, 36), 19.0, Color("2f8a5a"), "heal")
	_round_btn(ph.position + Vector2(ph.size.x - 92, 36), 19.0, Color("3d4a6b"), "recall")
	# captions with pointers
	var cy := ph.end.y + 50
	_tag(Vector2(c.x - 330, cy), "MOVE: drag left side", Color("2f6f9d"), 19)
	_tag(Vector2(c.x, cy), "SKILLS: tap = auto, drag = aim", Color("3a4f94"), 19)
	_tag(Vector2(c.x + 330, cy), "ATTACK: hold", Color("b0561f"), 19)
	_arrow(Vector2(c.x - 330, cy - 22), jc + Vector2(0, 58), Color(1, 1, 1, 0.8), 4.0)
	_arrow(Vector2(c.x + 300, cy - 22), ac + Vector2(-6, 48), Color(1, 1, 1, 0.8), 4.0)
	_arrow(Vector2(c.x + 20, cy - 22), ac + Vector2(-100, 40), Color(1, 1, 1, 0.8), 4.0)
	_txt(Vector2(c.x, card.end.y - 16), "Purple = Ultimate (level 4+)  ·  Green = Heal  ·  House = Go home", 19, Color(1, 1, 1, 0.85), 960)


func _page_danger(card: Rect2, c: Vector2) -> void:
	var left := Vector2(card.position.x + 260, c.y - 40)
	Art.draw_tower(canvas, left + Vector2(-110, 0), 40.0, 1)
	var hp := left + Vector2(110, 10)
	Art.draw_hero(canvas, &"sable", hp, 26.0, Vector2(-1, 0))
	for i in 3:
		var k := fmod(t * 1.2 + i / 3.0, 1.0)
		canvas.draw_circle((left + Vector2(-100, -30)).lerp(hp, k), 7.0, Color("ff6a5a"))
	_tag(hp + Vector2(0, -66), "x2  x4  x8 !", Color("b0302a"), 24)
	canvas.draw_line(hp + Vector2(-38, -38), hp + Vector2(38, 38), Color(1, 0.2, 0.2, 0.9), 8.0, true)
	canvas.draw_line(hp + Vector2(38, -38), hp + Vector2(-38, 38), Color(1, 0.2, 0.2, 0.9), 8.0, true)
	_txt(left + Vector2(0, 110), "Towers hit harder every shot.", 26)
	_txt(left + Vector2(0, 144), "Let YOUR creeps walk in first.", 26, Art.GOLD)
	for i in 3:
		_creep(left + Vector2(-60 + i * 34, 54), 0, 0.9)
	var right := Vector2(card.end.x - 250, c.y - 40)
	canvas.draw_circle(right, 76.0, Color(1, 0.3, 0.35, 0.18 + 0.06 * sin(t * 4.0)))
	canvas.draw_arc(right, 76.0, 0, TAU, 48, Color("ff4d5e"), 4.0, true)
	Art.draw_heartspire(canvas, right, 34.0, 1, true, t)
	_round_btn(right + Vector2(92, -66), 30.0, Color("c0303a"), "", "NO")
	_txt(right + Vector2(0, 110), "Enemy fountain shoots back.", 26)
	_txt(right + Vector2(0, 144), "Never walk in there!", 26, Color("ff7a7a"))


func _page_farm(card: Rect2, c: Vector2) -> void:
	var cols := [card.position.x + 180, c.x, card.end.x - 180]
	var y := c.y - 60
	# last hit
	_creep(Vector2(cols[0], y), 1, 1.6)
	canvas.draw_line(Vector2(cols[0] - 30, y - 40), Vector2(cols[0] + 30, y - 40), Color(0.2, 0.2, 0.2), 8.0)
	canvas.draw_line(Vector2(cols[0] - 30, y - 40), Vector2(cols[0] - 22, y - 40), Color("ff4d5e"), 8.0)
	_coin(Vector2(cols[0] + 34, y - 64 - 8.0 * absf(sin(t * 3.0))))
	_txt(Vector2(cols[0], y + 90), "Last hit creeps", 26)
	_txt(Vector2(cols[0], y + 122), "= gold", 26, Art.GOLD)
	# jungle
	canvas.draw_circle(Vector2(cols[1], y), 40.0, Color("7a5a3a"))
	canvas.draw_circle(Vector2(cols[1] - 13, y - 8), 7.0, Color("ffe06a"))
	canvas.draw_circle(Vector2(cols[1] + 13, y - 8), 7.0, Color("ffe06a"))
	for i in 5:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(cols[1] - 34 + i * 17, y - 30), Vector2(cols[1] - 26 + i * 17, y - 58), Vector2(cols[1] - 18 + i * 17, y - 30)]), Color("4f8f3a"))
	for i in 3:
		_coin(Vector2(cols[1] + 50 + i * 10, y - 60 - i * 12), 12.0)
	_txt(Vector2(cols[1], y + 90), "Jungle monsters", 26)
	_txt(Vector2(cols[1], y + 122), "pay more every minute", 26, Art.GOLD)
	# levels
	canvas.draw_colored_polygon(Art.star_pts(Vector2(cols[2], y), 52.0, 24.0, 5, -PI / 2 + sin(t) * 0.1), Art.GOLD)
	_txt(Vector2(cols[2], y + 12), "Lv 4", 26, Color("3a2a10"), 120)
	_round_btn(Vector2(cols[2] + 62, y - 50), 24.0, Color("8a4ac0"), "volley")
	_txt(Vector2(cols[2], y + 90), "Level 4 unlocks", 26)
	_txt(Vector2(cols[2], y + 122), "your ULTIMATE", 26, Color("c9a0ff"))
	_txt(Vector2(c.x, card.end.y - 30), "Stay near fights for XP  ·  Go home (house button) to heal up & shop", 22, Color(1, 1, 1, 0.8), 960)


func _page_shop(card: Rect2, c: Vector2) -> void:
	var y := c.y - 50
	var box := func(p: Vector2, icon: String, col: Color, label: String, tier2 := false) -> void:
		_panel(Rect2(p - Vector2(56, 56), Vector2(112, 112)), Color(0.18, 0.2, 0.3) if not tier2 else Color(0.32, 0.22, 0.12), 18)
		ItemIcons.draw(canvas, icon, p, 38.0, col)
		_txt(p + Vector2(0, 88), label, 20, Color.WHITE, 220)
	box.call(Vector2(c.x - 330, y), "fang", Color(0.75, 0.22, 0.17), "Leech Fang")
	_txt(Vector2(c.x - 215, y + 16), "+", 60, Art.GOLD, 80)
	box.call(Vector2(c.x - 100, y), "blade", Color(0.8, 0.82, 0.9), "Iron Blade")
	_txt(Vector2(c.x + 10, y + 16), "+", 60, Art.GOLD, 80)
	_coin(Vector2(c.x + 90, y))
	_txt(Vector2(c.x + 90, y + 56), "gold", 20, Art.GOLD, 100)
	_arrow(Vector2(c.x + 150, y), Vector2(c.x + 240, y), Art.GOLD)
	box.call(Vector2(c.x + 330, y), "cleaver", Color(0.9, 0.3, 0.24), "Bloodfang Cleaver", true)
	_txt(Vector2(c.x, card.end.y - 96), "Shop at your base. Two items + gold = a stronger item!", 28, Color.WHITE, 960)
	_tag(Vector2(c.x - 170, card.end.y - 42), "gold popup = what to buy next", Color("9a7a1a"), 22)
	_tag(Vector2(c.x + 230, card.end.y - 42), "SCORE = K/D/A & items", Color("3d4a6b"), 22)


func _page_pc(card: Rect2, c: Vector2) -> void:
	var rows := [
		[["W", "A", "S", "D"], "move  (or right-click to walk)"],
		[["Space"], "attack"],
		[["1", "2", "3"], "skills  (aim with the mouse)"],
		[["R"], "ultimate"],
		[["Tab"], "shop      O  scoreboard"],
		[["B"], "go home      H  heal      G  blink"],
		[["C"], "center camera  ·  right-drag to look around"],
	]
	var y := card.position.y + 56
	for r in rows:
		var keys: Array = r[0]
		var x := c.x - 300
		for k in keys:
			var w := 46.0 if (k as String).length() <= 1 else 96.0
			_keycap(Vector2(x + w * 0.5, y), k, w)
			x += w + 8.0
		canvas.draw_string(font, Vector2(c.x - 40, y + 9), r[1], HORIZONTAL_ALIGNMENT_LEFT, 560, 24, Color.WHITE)
		y += 56
