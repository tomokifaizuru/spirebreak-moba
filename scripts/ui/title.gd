extends Control
## Title screen: game name (from Project Settings), version, Play and How to Play.

var how_panel: Control
var t := 0.0
var font: Font
var config: MatchConfig


var diorama: Node3D
var cam: Camera3D
var heroes3d: Array[HeroModel] = []
var hero_timers: Array[float] = []
var crystals: Array[MeshInstance3D] = []


func _ready() -> void:
	font = ThemeDB.fallback_font
	config = load("res://data/match_config.tres")
	_build_diorama()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(root)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 330)
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
	Game.goto_hero_select()


func _process(delta: float) -> void:
	t += delta
	if cam != null:
		cam.position = Vector3(sin(t * 0.15) * 1.2, 4.0, 9.0)
		cam.look_at(Vector3(sin(t * 0.15) * 0.4, 1.1, 0), Vector3.UP)
	for i in heroes3d.size():
		hero_timers[i] -= delta
		if hero_timers[i] <= 0.0:
			hero_timers[i] = randf_range(2.5, 5.0)
			if randf() < 0.5:
				heroes3d[i].trigger_attack()
			else:
				heroes3d[i].trigger_cast()
		heroes3d[i].animate(delta, 0.0)
	for c in crystals:
		c.rotation.y += delta * 1.2
		c.position.y = 2.75 + sin(t * 1.8) * 0.08
	queue_redraw()


## Little floating island: lane, river, a tower for each team and the six heroes idling.
func _build_diorama() -> void:
	diorama = Node3D.new()
	add_child(diorama)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("101626")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c9d8ff")
	e.ambient_light_energy = 0.6
	env.environment = e
	diorama.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.0
	diorama.add_child(sun)
	var b := MeshKit.Builder.new(21)
	b.add(MeshKit.cyl(6.3, 4.8, 1.4, 11), Color("6b5a44"), MeshKit.xf(Vector3(0, -0.86, 0)), 0.06)
	b.add(MeshKit.cone(4.6, 2.6, 9), Color("5a4a38"), MeshKit.xf(Vector3(0, -2.6, 0), Vector3(180, 0, 0)), 0.15)
	b.add(MeshKit.cyl(6.45, 6.4, 0.14, 11), Color("62a845"), MeshKit.xf(Vector3(0, -0.02, 0)))
	# river across the back, lane across the front
	b.add(MeshKit.box(13.0, 0.05, 1.2), Color("3d9be0"), MeshKit.xf(Vector3(0, 0.07, -2.6), Vector3(0, 8, 0)))
	b.add(MeshKit.box(11.0, 0.04, 1.9), Color("dcc092"), MeshKit.xf(Vector3(0, 0.08, 0.9), Vector3(0, -4, 0)))
	MeshKit.inst(diorama, b.commit())
	for side in [0, 1]:
		var x := -4.3 if side == 0 else 4.3
		var tower := MeshKit.inst(diorama, ModelLib.tower_body(side), MeshKit.xf(Vector3(x, 0.05, -0.6)))
		tower.scale = Vector3.ONE * 1.1
		var cm := StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.albedo_color = Art.team_color(side).lightened(0.25)
		var cr := MeshKit.inst(diorama, ModelLib.crystal(), MeshKit.xf(Vector3(x, 2.75, -0.6), Vector3.ZERO, Vector3.ONE * 0.46), cm)
		crystals.append(cr)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in 16:
		var a := deg_to_rad(200.0 + i * 9.0 + rng.randf_range(-3, 3))
		var r := rng.randf_range(4.6, 6.0)
		var s := rng.randf_range(0.9, 1.5)
		MeshKit.inst(diorama, ModelLib.tree() if i % 4 != 0 else ModelLib.bush_tree(), MeshKit.xf(Vector3(cos(a) * r, 0.0, sin(a) * r), Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * s))
	for i in 14:
		var p := Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(1.8, 4.5))
		MeshKit.inst(diorama, ModelLib.flower() if i % 2 == 0 else ModelLib.tuft(), MeshKit.xf(Vector3(p.x, 0.05, p.y), Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * 1.4))
	var roster: Array = config.roster if config != null else []
	for i in roster.size():
		var d: HeroData = roster[i]
		var team := 0 if i < 3 else 1
		var m := HeroModel.new().build(d, team)
		m.scale *= 1.25
		var x2 := (i - (roster.size() - 1) * 0.5) * 1.25
		m.position = Vector3(x2, 0.1, 1.0 + absf(x2) * -0.08)
		m.rotation.y = -x2 * 0.08
		diorama.add_child(m)
		heroes3d.append(m)
		hero_timers.append(randf_range(0.5, 3.0))
		var sh := MeshKit.decal(Color(0, 0, 0, 0.35), 1.0, 0.0, 1)
		sh.position = m.position + Vector3(0, 0.02, 0)
		sh.scale = Vector3.ONE * 0.55
		diorama.add_child(sh)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.5
	cam.far = 60.0
	diorama.add_child(cam)
	cam.current = true


func _draw() -> void:
	var s := size
	# soft dark band behind the title so it reads over the 3D scene
	draw_rect(Rect2(0, 0, s.x, s.y * 0.36), Color(0.04, 0.05, 0.09, 0.35))
	var title := Game.title.to_upper()
	var tsz := 96
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	var tp := Vector2(s.x * 0.5 - tw * 0.5, s.y * 0.2)
	draw_string_outline(font, tp + Vector2(0, 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 22, Color(0, 0, 0, 0.5))
	draw_string_outline(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 16, Color("1b2236"))
	var half := title.length() / 2
	var left := title.substr(0, half)
	var lw := font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, tp, left, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color("7cc0ff"))
	draw_string(font, tp + Vector2(lw, 0), title.substr(half), HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color("ff7d8a"))
	var ver := "v" + Game.version
	var vw := font.get_string_size(ver, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var vr := Rect2(tp.x + tw + 10.0, tp.y - 78.0, vw + 22.0, 36.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f08a2c")
	sb.set_corner_radius_all(10)
	draw_style_box(sb, vr)
	draw_string(font, vr.position + Vector2(11, 27), ver, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	var sub := "3v3 hero brawls  ·  one lane  ·  6 heroes  ·  Team Dawn vs Team Dusk"
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string_outline(font, Vector2(s.x * 0.5 - sw * 0.5, s.y * 0.2 + 40.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(s.x * 0.5 - sw * 0.5, s.y * 0.2 + 40.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.85))
