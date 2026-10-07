class_name FxLayer
extends Node2D
## Short-lived visuals: floating damage numbers, gold pop-ups, slashes, rings and beams.

var items: Array = []
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	z_index = 20


func text(pos: Vector2, s: String, col: Color, size := 18, life := 0.8) -> void:
	items.append({"type": "text", "pos": pos + Vector2(randf_range(-10, 10), 0), "s": s, "col": col, "size": size, "t": 0.0, "life": life})


func ring(pos: Vector2, r0: float, r1: float, col: Color, life := 0.35, width := 4.0) -> void:
	items.append({"type": "ring", "pos": pos, "r0": r0, "r1": r1, "col": col, "t": 0.0, "life": life, "w": width})


func slash(pos: Vector2, dir: Vector2, r: float, col: Color, life := 0.18) -> void:
	items.append({"type": "slash", "pos": pos, "dir": dir, "r": r, "col": col, "t": 0.0, "life": life})


func beam(a: Vector2, b: Vector2, col: Color, width := 6.0, life := 0.25) -> void:
	items.append({"type": "beam", "a": a, "b": b, "col": col, "w": width, "t": 0.0, "life": life})


func _process(delta: float) -> void:
	var keep: Array = []
	for it in items:
		it["t"] += delta
		if it["t"] < it["life"]:
			keep.append(it)
	items = keep
	queue_redraw()


func _draw() -> void:
	for it in items:
		var k: float = it["t"] / it["life"]
		var col: Color = it["col"]
		match it["type"]:
			"text":
				var p: Vector2 = it["pos"] + Vector2(0, -40.0 * k - 10.0)
				var c := Color(col, 1.0 - maxf(0.0, k - 0.6) / 0.4)
				var sz: int = it["size"]
				p.x -= 120.0
				draw_string_outline(font, p, it["s"], HORIZONTAL_ALIGNMENT_CENTER, 240, sz, 5, Color(0.05, 0.05, 0.08, c.a))
				draw_string(font, p, it["s"], HORIZONTAL_ALIGNMENT_CENTER, 240, sz, c)
			"ring":
				var r: float = lerpf(it["r0"], it["r1"], k)
				draw_arc(it["pos"], r, 0, TAU, 48, Color(col, 1.0 - k), it["w"], true)
			"slash":
				var d: Vector2 = it["dir"]
				var a := d.angle()
				draw_arc(it["pos"], it["r"], a - 1.1, a + 1.1, 16, Color(col, 1.0 - k), 8.0 * (1.0 - k) + 2.0, true)
			"beam":
				draw_line(it["a"], it["b"], Color(col, 1.0 - k), it["w"] * (1.0 - k * 0.5), true)
