class_name MatchHud
extends CanvasLayer
## In-match HUD: the touch-control canvas (hud_canvas.gd), pause menu and result screen.

var arena: Arena
var canvas: HudCanvas
var overlay: Control
var pause_box: VBoxContainer
var result_box: VBoxContainer


func _game() -> Node:
	return get_node("/root/Game")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10


func setup(a: Arena) -> void:
	arena = a
	canvas = HudCanvas.new()
	canvas.hud = self
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.setup(a)
	a.match_over.connect(_on_over)
	_build_overlay()


static func make_button(text: String, col: Color, min_w := 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 62)
	b.add_theme_font_size_override("font_size", 26)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if st == "normal" or st == "focus" else (col.lightened(0.12) if st == "hover" else col.darkened(0.2))
		sb.set_corner_radius_all(14)
		sb.border_color = Color(1, 1, 1, 0.35)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 4
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	return b


static func make_label(text: String, sz: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", maxi(4, sz / 6))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var holder := VBoxContainer.new()
	center.add_child(holder)
	# Pause menu
	pause_box = VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 14)
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_child(pause_box)
	pause_box.add_child(make_label("Paused", 46))
	pause_box.add_child(OptionsMenu.make_rows())
	var resume := make_button("Resume", Color("2f9d5a"))
	resume.pressed.connect(toggle_pause)
	pause_box.add_child(resume)
	var restart := make_button("Restart", Color("3d6fd0"))
	restart.pressed.connect(func() -> void: _game().goto_match())
	pause_box.add_child(restart)
	var menu := make_button("Main Menu", Color("4a4f63"))
	menu.pressed.connect(func() -> void: _game().goto_title())
	pause_box.add_child(menu)
	# Result screen (filled in _on_over)
	result_box = VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 10)
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.visible = false
	holder.add_child(result_box)


func toggle_pause() -> void:
	if arena == null or arena.over:
		return
	var p := not get_tree().paused
	get_tree().paused = p
	overlay.visible = p
	pause_box.visible = p
	result_box.visible = false
	canvas.release_all()
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("click", -6.0)


func _on_over(winner: int) -> void:
	canvas.release_all()
	await get_tree().create_timer(1.6).timeout
	_show_result(winner)


func _show_result(winner: int) -> void:
	for c in result_box.get_children():
		c.queue_free()
	var won := winner == arena.player.team
	var title := make_label("VICTORY" if won else "DEFEAT", 76, Art.GOLD if won else Color("ff5a6a"))
	result_box.add_child(title)
	var t := int(arena.time)
	result_box.add_child(make_label("%s  ·  %02d:%02d" % [arena.end_reason, t / 60, t % 60], 20, Color(1, 1, 1, 0.8)))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 4)
	for h in ["", "Hero", "Role", "Lv", "K / D / A", "Last hits", "Gold"]:
		grid.add_child(make_label(h, 16, Color(1, 1, 1, 0.55)))
	for team in [0, 1]:
		for hero in arena.heroes:
			if hero.team != team:
				continue
			var tc := Art.team_color(team)
			grid.add_child(make_label("DAWN" if team == 0 else "DUSK", 15, tc))
			grid.add_child(make_label(("You · " if hero.is_player else "") + hero.display_name, 18, Art.PLAYER if hero.is_player else Color.WHITE))
			grid.add_child(make_label(hero.data.role_name(), 15, hero.data.role_color()))
			grid.add_child(make_label(str(hero.level), 18))
			grid.add_child(make_label("%d / %d / %d" % [hero.kills, hero.deaths, hero.assists], 18))
			grid.add_child(make_label(str(hero.last_hits), 18))
			grid.add_child(make_label(str(hero.gold), 18, Art.GOLD))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12, 0.9)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(grid)
	result_box.add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var again := make_button("Play Again", Color("2f9d5a"), 240.0)
	again.pressed.connect(func() -> void: _game().restart_match())
	row.add_child(again)
	var menu := make_button("Main Menu", Color("4a4f63"), 240.0)
	menu.pressed.connect(func() -> void: _game().goto_title())
	row.add_child(menu)
	result_box.add_child(row)
	pause_box.visible = false
	result_box.visible = true
	overlay.visible = true
