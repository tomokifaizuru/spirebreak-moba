class_name OptionsMenu
extends Control
## Options popup (title screen and pause menu): Music and SFX volume, saved to
## user://settings.cfg by the Game autoload.

signal closed


static func volume_row(label: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var lab := MatchHud.make_label(label, 22)
	lab.custom_minimum_size = Vector2(90, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(lab)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(260, 40)
	var pct := MatchHud.make_label("%d%%" % roundi(value * 100.0), 18, Color(1, 1, 1, 0.7))
	pct.custom_minimum_size = Vector2(56, 0)
	slider.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % roundi(v * 100.0)
		on_change.call(v))
	row.add_child(slider)
	row.add_child(pct)
	return row


## Both volume rows in a VBox (used inline by the pause menu too).
static func make_rows() -> VBoxContainer:
	var game: Node = (Engine.get_main_loop() as SceneTree).root.get_node("/root/Game")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(volume_row("Music", game.music_volume, func(v: float) -> void: game.set_music_volume(v)))
	box.add_child(volume_row("SFX", game.sfx_volume, func(v: float) -> void: game.set_sfx_volume(v)))
	return box


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	cc.add_child(box)
	box.add_child(MatchHud.make_label("Options", 40, Art.GOLD))
	box.add_child(make_rows())
	var hint := MatchHud.make_label("Settings are saved on this device.", 14, Color(1, 1, 1, 0.5))
	box.add_child(hint)
	var close := MatchHud.make_button("Done", Color("2f9d5a"), 220.0)
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	var row := CenterContainer.new()
	row.add_child(close)
	box.add_child(row)
