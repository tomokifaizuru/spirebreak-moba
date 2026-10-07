extends Control
## Title screen: game name (from Project Settings), version, Play and How to Play.

var how_panel: Control
var t := 0.0
var font: Font
var config: MatchConfig


func _ready() -> void:
	font = ThemeDB.fallback_font
	config = load("res://data/match_config.tres")
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(root)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 150)
	root.add_child(spacer)
	var play := MatchHud.make_button("PLAY", Color("f08a2c"), 320.0)
	play.custom_minimum_size = Vector2(320, 78)
	play.add_theme_font_size_override("font_size", 38)
	play.pressed.connect(_on_play)
	root.add_child(play)
	var how := MatchHud.make_button("How to Play", Color("3d4a6b"), 320.0)
	how.pressed.connect(func() -> void:
		Sfx.play("click", -6.0)
		how_panel.visible = true)
	root.add_child(how)
	var ver := MatchHud.make_label("v" + Game.version + "  ·  prototype  ·  original IP", 16, Color(1, 1, 1, 0.55))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(18, -34)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(ver)
	_build_how()


func _build_how() -> void:
	how_panel = Control.new()
	how_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	how_panel.visible = false
	add_child(how_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	how_panel.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	how_panel.add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	cc.add_child(box)
	box.add_child(MatchHud.make_label("How to Play", 40, Art.GOLD))
	var lines := [
		"Destroy the enemy Heartspire. Towers fall in order: Outer, Inner, then the Heartspire.",
		"Push with your creep waves: buildings take half damage when no allied creeps are near.",
		"Last-hit creeps for gold, stay near kills for XP. Ultimate unlocks at level 4 (max level 12).",
		"",
		"PHONE:  left thumb = joystick anywhere on the left half",
		"ATTACK = auto-targets (hold to keep attacking)  ·  skills: tap = auto-aim, drag = aim, drag back = cancel",
		"Minimap: hold to look around  ·  RECALL = go home  ·  HEAL = instant heal (60 s)",
		"",
		"PC:  WASD / arrows move  ·  Space or J attack  ·  1 2 3 (or Q E F) skills  ·  R or 4 ultimate",
		"B recall  ·  H heal  ·  Esc pause  ·  right-click to walk  ·  skills aim at the mouse",
	]
	for l in lines:
		var lab := MatchHud.make_label(l, 18, Color(1, 1, 1, 0.9))
		box.add_child(lab)
	var close := MatchHud.make_button("Got it", Color("2f9d5a"), 220.0)
	close.pressed.connect(func() -> void: how_panel.visible = false)
	var row := CenterContainer.new()
	row.add_child(close)
	box.add_child(row)


func _on_play() -> void:
	Sfx.play("click", -4.0)
	Game.goto_match()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color("0f1320"))
	# Diagonal map silhouette: river and lane
	var k := s.y / 5100.0
	var o := Vector2(s.x * 0.5 - 2550.0 * k, 0)
	draw_line(o + Vector2(-300, -300) * k, o + Vector2(5400, 5400) * k, Color(0.24, 0.6, 0.88, 0.16), 120.0 * k * 1.8)
	var lane := PackedVector2Array()
	for p in [Vector2(640, 4460), Vector2(1120, 4120), Vector2(1650, 3870), Vector2(1950, 3380), Vector2(2230, 2880), Vector2(2550, 2550), Vector2(2880, 2230), Vector2(3380, 1950), Vector2(3870, 1650), Vector2(4120, 1120), Vector2(4460, 640)]:
		lane.append(o + p * k)
	draw_polyline(ArenaMap.smooth(lane, 8), Color(0.85, 0.72, 0.54, 0.16), 260.0 * k, true)
	# Glows behind the two Heartspires
	var dawn := Vector2(s.x * 0.16, s.y * 0.72)
	var dusk := Vector2(s.x * 0.84, s.y * 0.30)
	for i in 6:
		draw_circle(dawn, 150.0 - i * 20.0, Color(0.24, 0.6, 1.0, 0.04))
		draw_circle(dusk, 150.0 - i * 20.0, Color(1.0, 0.3, 0.37, 0.04))
	var pulse := sin(t * 2.0)
	Art.draw_heartspire(self, dawn, 62.0, 0, true, pulse)
	Art.draw_heartspire(self, dusk, 62.0, 1, true, -pulse)
	# Title
	var title := Game.title.to_upper()
	var tsz := 96
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	var tp := Vector2(s.x * 0.5 - tw * 0.5, s.y * 0.25)
	draw_string_outline(font, tp + Vector2(0, 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 22, Color(0, 0, 0, 0.5))
	draw_string_outline(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 16, Color("1b2236"))
	var half := title.length() / 2
	var left := title.substr(0, half)
	var lw := font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, tp, left, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color("7cc0ff"))
	draw_string(font, tp + Vector2(lw, 0), title.substr(half), HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color("ff7d8a"))
	var sub := "3v3 hero brawls  ·  one lane  ·  Team Dawn vs Team Dusk"
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, Vector2(s.x * 0.5 - sw * 0.5, s.y * 0.25 + 40.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.75))
	# Team line-up
	if config != null:
		var dawn_team: Array = [config.player_hero] + config.dawn_bots
		_draw_lineup(dawn_team, Vector2(s.x * 0.5 - 330.0, s.y * 0.86), 0)
		_draw_lineup(config.dusk_bots, Vector2(s.x * 0.5 + 330.0, s.y * 0.86), 1)
		var vs := "VS"
		draw_string_outline(font, Vector2(s.x * 0.5 - 18.0, s.y * 0.86 + 12.0), vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 8, Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(s.x * 0.5 - 18.0, s.y * 0.86 + 12.0), vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Art.GOLD)


func _draw_lineup(list: Array, center: Vector2, team: int) -> void:
	var n := list.size()
	for i in n:
		var d: HeroData = list[i]
		var c := center + Vector2((i - (n - 1) * 0.5) * 96.0, 0)
		var bob := sin(t * 2.2 + i + team * 2.0) * 3.0
		draw_circle(c + Vector2(0, bob), 38.0, Color(Art.team_color(team), 0.25))
		var ring := Art.PLAYER if (team == 0 and i == 0) else Art.team_color(team)
		draw_arc(c + Vector2(0, bob), 38.0, 0, TAU, 40, ring, 3.0, true)
		Art.draw_hero(self, d.id, c + Vector2(0, bob), 28.0, Vector2(0, 0.6))
		var nm := ("You: " if team == 0 and i == 0 else "") + d.display_name
		var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string_outline(font, c + Vector2(-w * 0.5, 58.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.7))
		draw_string(font, c + Vector2(-w * 0.5, 58.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
