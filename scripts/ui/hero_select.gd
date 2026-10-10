extends Node3D
## Hero select: pick one of the six heroes (cards show role, a short line and difficulty), see the
## hero turn on a pedestal with their kit listed, then PLAY. Bots fill the other five slots
## (Lineup.build makes a sensible random mix).

var roster: Array = []
var selected: HeroData
var model: HeroModel
var model_root: Node3D
var cam: Camera3D
var ui: Control
var cards: Array = []
var info: InfoPanel
var play_btn: Button
var portraits := {}
var t := 0.0
var anim_t := 2.0


func _ready() -> void:
	roster = Game.roster()
	selected = Game.selected_hero
	if selected == null:
		var cfg: MatchConfig = load(Game.CONFIG_PATH)
		selected = cfg.player_hero if cfg.player_hero != null else roster[0]
	_build_world()
	_build_ui()
	_select(selected, false)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("141b2d")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c9d8ff")
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.0
	add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.5, 2.0, -1.5)
	rim.light_color = Color("7cc0ff")
	rim.light_energy = 1.4
	rim.omni_range = 5.0
	add_child(rim)
	# pedestal on a little grass island with trees
	var b := MeshKit.Builder.new(9)
	b.add(MeshKit.cyl(2.6, 2.2, 0.5, 9), Color("6b5a44"), MeshKit.xf(Vector3(0, -0.3, 0)), 0.05)
	b.add(MeshKit.cyl(2.65, 2.6, 0.12, 9), Color("62a845"), MeshKit.xf(Vector3(0, -0.03, 0)))
	b.add(MeshKit.cyl(0.85, 0.95, 0.18, 10), ModelLib.STONE, MeshKit.xf(Vector3(0, 0.07, 0)))
	b.add(MeshKit.cyl(0.78, 0.78, 0.04, 10), ModelLib.STONE_LIGHT, MeshKit.xf(Vector3(0, 0.17, 0)))
	MeshKit.inst(self, b.commit())
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	# trees only behind the hero (negative z is away from the camera)
	for i in 7:
		var a := deg_to_rad(15.0 + i * 25.0 + rng.randf_range(-6, 6))
		var r := rng.randf_range(1.8, 2.4)
		var s := rng.randf_range(0.8, 1.2)
		MeshKit.inst(self, ModelLib.tree() if i % 3 != 1 else ModelLib.bush_tree(), MeshKit.xf(Vector3(cos(a) * r, 0.02, -sin(a) * r), Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * s))
	for i in 3:
		var a2 := deg_to_rad(-15.0 - i * 28.0)
		MeshKit.inst(self, ModelLib.rock(), MeshKit.xf(Vector3(cos(a2) * 2.2, 0.0, -sin(a2) * 2.2), Vector3(0, i * 70, 0), Vector3.ONE * 0.4))
	for i in 10:
		var a3 := rng.randf() * TAU
		var r3 := rng.randf_range(1.0, 2.4)
		MeshKit.inst(self, ModelLib.flower() if i % 2 == 0 else ModelLib.tuft(), MeshKit.xf(Vector3(cos(a3) * r3, 0.03, sin(a3) * r3), Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * 1.3))
	var ring := MeshKit.decal(Color(1, 0.9, 0.5, 0.8), 0.08, 0.1, 0, 1)
	ring.position.y = 0.2
	ring.scale = Vector3.ONE * 0.8
	add_child(ring)
	model_root = Node3D.new()
	model_root.position.y = 0.19
	add_child(model_root)
	cam = Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.3
	cam.far = 40.0
	add_child(cam)
	cam.current = true
	get_viewport().size_changed.connect(_place_camera)
	_place_camera()


## Keeps the hero standing in the free space right of the cards, whatever the screen shape.
func _place_camera() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(vs.y, 1.0)
	var target := Vector3(0, 0.6, 0)
	cam.position = Vector3(0, 1.75, 6.3)
	cam.look_at(target, Vector3.UP)
	# shift the view so the hero appears right of the cards (x ~ 74%) and above the info panel (y ~ 30%)
	var dist := cam.position.distance_to(target)
	var half_h := tan(deg_to_rad(cam.fov) * 0.5) * dist
	cam.h_offset = -(0.74 - 0.5) * 2.0 * half_h * aspect
	cam.v_offset = -(0.5 - 0.33) * 2.0 * half_h


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var header := MatchHud.make_label("CHOOSE YOUR HERO", 34, Art.GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.position = Vector2(118, 16)
	ui.add_child(header)
	var sub := MatchHud.make_label("Bots fill the other 5 slots with a random balanced mix.", 15, Color(1, 1, 1, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub.position = Vector2(120, 58)
	ui.add_child(sub)
	var back := MatchHud.make_button("<", Color("3d4a6b"), 76.0)
	back.custom_minimum_size = Vector2(76, 62)
	back.position = Vector2(22, 16)
	back.pressed.connect(func() -> void:
		Sfx.play("click", -6.0)
		Game.goto_title())
	ui.add_child(back)
	var grid := GridContainer.new()
	grid.columns = 3 if roster.size() <= 6 else 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.position = Vector2(22, 92)
	ui.add_child(grid)
	var holder := Node.new()
	add_child(holder)
	for d in roster:
		var tex := Portraits.make(holder, d, 0, 160)
		portraits[d.id] = tex
		var c := HeroCard.new()
		c.data = d
		c.tex = tex
		c.custom_minimum_size = Vector2(196, 258) if roster.size() <= 6 else Vector2(150, 258)
		c.tapped.connect(_select.bind(true))
		grid.add_child(c)
		cards.append(c)
	info = InfoPanel.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info.offset_left = -470
	info.offset_top = -346
	info.offset_right = -18
	info.offset_bottom = -96
	ui.add_child(info)
	play_btn = MatchHud.make_button("PLAY", Color("f08a2c"), 452.0)
	play_btn.custom_minimum_size = Vector2(452, 68)
	play_btn.add_theme_font_size_override("font_size", 30)
	play_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	play_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	play_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	play_btn.offset_left = -470
	play_btn.offset_top = -86
	play_btn.offset_right = -18
	play_btn.offset_bottom = -18
	play_btn.pressed.connect(_on_play)
	ui.add_child(play_btn)


func _select(d: HeroData, sound := true) -> void:
	selected = d
	if sound:
		Sfx.play("click", -6.0)
	for c in cards:
		c.selected = c.data == d
		c.queue_redraw()
	if model != null:
		model.queue_free()
	model = HeroModel.new().build(d, 0)
	model.scale *= 1.25
	model.rotation_degrees.y = -20.0
	model_root.add_child(model)
	model.trigger_cast()
	anim_t = 1.2
	info.data = d
	info.queue_redraw()
	play_btn.text = "PLAY AS %s" % d.display_name.to_upper()


func _on_play() -> void:
	Sfx.play("click", -4.0)
	play_btn.disabled = true
	Game.start_match(selected)


func _process(delta: float) -> void:
	t += delta
	if model != null:
		model_root.rotation.y = sin(t * 0.5) * 0.5
		anim_t -= delta
		if anim_t <= 0.0:
			anim_t = randf_range(2.0, 3.5)
			if randf() < 0.6:
				model.trigger_attack()
			else:
				model.trigger_cast()
		model.animate(delta, 0.0)


# ------------------------------------------------------------------ card
class HeroCard extends Control:
	signal tapped(d: HeroData)
	var data: HeroData
	var tex: Texture2D
	var selected := false
	var font: Font

	func _ready() -> void:
		font = ThemeDB.fallback_font
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			tapped.emit(data)
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.11, 0.17, 0.93) if not selected else Color(0.16, 0.15, 0.1, 0.96)
		sb.border_color = Art.GOLD if selected else Color(1, 1, 1, 0.12)
		sb.set_border_width_all(4 if selected else 2)
		sb.set_corner_radius_all(14)
		draw_style_box(sb, r)
		var rc := data.role_color()
		# portrait on a role-tinted disc
		var pc := Vector2(size.x * 0.5, 74)
		draw_circle(pc, 60, Color(rc, 0.22))
		draw_arc(pc, 60, 0, TAU, 40, Color(rc, 0.8), 2.5, true)
		if tex != null:
			draw_texture_rect(tex, Rect2(pc - Vector2(64, 64), Vector2(128, 128)), false)
		# name
		_center(data.display_name, 140 + 10, 21, Color.WHITE, 4)
		# role badge
		var role := data.role_name().to_upper()
		var rw := font.get_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22.0
		var br := Rect2(size.x * 0.5 - rw * 0.5, 160, rw, 22)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = rc.darkened(0.3)
		bsb.border_color = rc.lightened(0.2)
		bsb.set_border_width_all(1)
		bsb.set_corner_radius_all(11)
		draw_style_box(bsb, br)
		_center(role, 176, 13, Color.WHITE, 0)
		# tagline (wrapped)
		draw_multiline_string(font, Vector2(10, 202), data.tagline, HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 12, 3, Color(1, 1, 1, 0.72))
		# difficulty dots
		var dy := size.y - 14.0
		for i in 3:
			var dc := Vector2(size.x * 0.5 + (i - 1) * 16.0, dy)
			draw_circle(dc, 5.0, Art.GOLD if i < data.difficulty else Color(1, 1, 1, 0.18))

	func _center(s: String, y: float, sz: int, col: Color, outline: int) -> void:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var p := Vector2(size.x * 0.5 - w * 0.5, y)
		if outline > 0:
			draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, outline, Color(0, 0, 0, 0.7))
		draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


# ------------------------------------------------------------------ details of the selected hero
class InfoPanel extends Control:
	var data: HeroData
	var font: Font

	func _ready() -> void:
		font = ThemeDB.fallback_font
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if data == null:
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.09, 0.14, 0.9)
		sb.border_color = Color(data.role_color(), 0.6)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		draw_string_outline(font, Vector2(18, 36), data.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 5, Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(18, 36), data.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		var nw := font.get_string_size(data.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(font, Vector2(26 + nw, 35), data.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))
		var role := data.role_name().to_upper()
		var rw := font.get_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22.0
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = data.role_color().darkened(0.3)
		bsb.border_color = data.role_color().lightened(0.2)
		bsb.set_border_width_all(1)
		bsb.set_corner_radius_all(11)
		draw_style_box(bsb, Rect2(size.x - rw - 16, 16, rw, 22))
		draw_string(font, Vector2(size.x - rw - 5, 32), role, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		var y := 52.0
		for i in data.abilities.size():
			var ab: AbilityData = data.abilities[i]
			var ic := Vector2(36, y + 18)
			draw_circle(ic, 17, Color("3a2030") if ab.is_ultimate else Color("1d2a40"))
			draw_arc(ic, 17, 0, TAU, 24, Art.GOLD if ab.is_ultimate else Color(1, 1, 1, 0.3), 2.0, true)
			Art.draw_icon(self, ab.icon, ic, 10.0, Color.WHITE)
			var nm := ab.display_name + ("  (ULT)" if ab.is_ultimate else "")
			draw_string(font, Vector2(64, y + 14), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Art.GOLD if ab.is_ultimate else Color.WHITE)
			draw_multiline_string(font, Vector2(64, y + 29), ab.description, HORIZONTAL_ALIGNMENT_LEFT, size.x - 76, 12, 2, Color(1, 1, 1, 0.68))
			y += 45.0
