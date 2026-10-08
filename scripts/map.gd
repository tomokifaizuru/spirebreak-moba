@tool
class_name ArenaMap
extends Node2D
## One-Lane Compact map (draft A). Everything is drawn in code from the Marker2D points:
##  - drag the points under "Lane" or "River" to reshape them (the ground redraws in the editor),
##  - move the towers / Heartspires under "Structures" (pick their stats resource in the Inspector),
##  - DawnFountain / DuskFountain are the spawn + healing points, "Shrine" is the healing shrine,
##  - "Camps" holds the jungle camp positions.

@export var map_size := Vector2(5100, 5100)
@export var lane_width := 315.0
@export var river_width := 190.0
@export var base_radius := 470.0
## Change to get a different tree layout.
@export var tree_seed := 11
@export_range(0.0, 2.0, 0.05) var tree_density := 1.0
@export var grass_color := Color("4c8a38")
@export var lane_color := Color("d8b98a")
@export var river_color := Color("3d9be0")

var _trees: Array = []
var _sig := ""


func _ready() -> void:
	_rebuild()


func _process(_d: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	var s := str(markers("Lane")) + str(markers("River")) + str(tree_seed) + str(tree_density) + str(lane_width) + str(river_width)
	if s != _sig:
		_rebuild()


func _rebuild() -> void:
	_sig = str(markers("Lane")) + str(markers("River")) + str(tree_seed) + str(tree_density) + str(lane_width) + str(river_width)
	_build_trees()
	queue_redraw()


func markers(group: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := get_node_or_null(group)
	if n == null:
		return out
	for c in n.get_children():
		if c is Node2D:
			out.append((c as Node2D).position)
	return out


static func smooth(pts: PackedVector2Array, seg := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	if n < 2:
		return pts
	for i in n - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		for s in seg:
			var t := float(s) / seg
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out


func get_lane() -> PackedVector2Array:
	return smooth(markers("Lane"), 12)


func get_river() -> PackedVector2Array:
	return smooth(markers("River"), 10)


func get_structures() -> Array:
	var out: Array = []
	var n := get_node_or_null("Structures")
	if n != null:
		for c in n.get_children():
			if c is Structure:
				out.append(c)
	return out


func fountain_pos(team: int) -> Vector2:
	var n := get_node_or_null("DawnFountain" if team == 0 else "DuskFountain") as Node2D
	return n.position if n != null else Vector2.ZERO


func base_center(team: int) -> Vector2:
	var lane := markers("Lane")
	if lane.is_empty():
		return fountain_pos(team)
	var end := lane[0] if team == 0 else lane[lane.size() - 1]
	return fountain_pos(team).lerp(end, 0.5)


func shrine_pos() -> Vector2:
	var n := get_node_or_null("Shrine") as Node2D
	return n.position if n != null else map_size * 0.5


func camp_positions() -> PackedVector2Array:
	return markers("Camps")


## A camp is "big" when its marker's gizmo_extents is 70 or more (set in the map scene).
func is_big_camp(index: int) -> bool:
	var n := get_node_or_null("Camps")
	if n == null or index >= n.get_child_count():
		return false
	var m := n.get_child(index) as Marker2D
	return m != null and m.gizmo_extents >= 70.0


static func dist_to_poly(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[i + 1])
		best = minf(best, p.distance_to(q))
	return best


func _coarse(poly: PackedVector2Array, step := 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, poly.size(), step):
		out.append(poly[i])
	if poly.size() > 0:
		out.append(poly[poly.size() - 1])
	return out


func _blocked(p: Vector2, r: float, lane: PackedVector2Array, river: PackedVector2Array) -> bool:
	if p.x < 60 or p.y < 60 or p.x > map_size.x - 60 or p.y > map_size.y - 60:
		return true
	if dist_to_poly(p, lane) < lane_width * 0.5 + r + 120.0:
		return true
	if dist_to_poly(p, river) < river_width * 0.5 + r + 30.0:
		return true
	for t in [0, 1]:
		if p.distance_to(base_center(t)) < base_radius + r + 60.0:
			return true
		if p.distance_to(fountain_pos(t)) < 380.0 + r:
			return true
	if p.distance_to(shrine_pos()) < 230.0 + r:
		return true
	for c in camp_positions():
		if p.distance_to(c) < 170.0 + r:
			return true
	return false


func _build_trees() -> void:
	_trees.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var lane := _coarse(get_lane(), 3)
	var river := _coarse(get_river(), 3)
	if lane.size() < 2 or river.size() < 2:
		return
	var target := int(150 * tree_density)
	var tries := 0
	var placed := 0
	while placed < target and tries < 1500:
		tries += 1
		var p := Vector2(rng.randf_range(60, map_size.x - 60), rng.randf_range(60, map_size.y - 60))
		if p.y < p.x:
			p = Vector2(p.y, p.x)
		var cluster := rng.randi_range(1, 3)
		for k in cluster:
			var r := rng.randf_range(42.0, 70.0)
			var q := p + Vector2.from_angle(rng.randf() * TAU) * (k * 70.0)
			var m := Vector2(q.y, q.x)
			if _blocked(q, r, lane, river) or _blocked(m, r, lane, river):
				continue
			var overlap := false
			for t in _trees:
				if q.distance_to(t[0]) < (r + t[1]) * 0.75:
					overlap = true
					break
			if overlap:
				continue
			_trees.append([q, r])
			_trees.append([m, r])
			placed += 1


func _draw() -> void:
	var lane := get_lane()
	var river := get_river()
	draw_rect(Rect2(Vector2(-600, -600), map_size + Vector2(1200, 1200)), Color("1f3a1c"))
	draw_rect(Rect2(Vector2.ZERO, map_size), grass_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed + 99
	for i in 140:
		var p := Vector2(rng.randf_range(0, map_size.x), rng.randf_range(0, map_size.y))
		draw_circle(p, rng.randf_range(80, 220), Color(grass_color.lightened(0.06), 0.35) if i % 2 == 0 else Color(grass_color.darkened(0.08), 0.35))
	# Bases
	for t in [0, 1]:
		var bc := base_center(t)
		draw_circle(bc, base_radius + 26.0, Color(0, 0, 0, 0.12))
		draw_circle(bc, base_radius, Color("bdb39b"))
		draw_circle(bc, base_radius * 0.82, Color("c9c0a8"))
		var tc := Color("3d9bff") if t == 0 else Color("ff4d5e")
		for k in 36:
			if k % 2 == 0:
				draw_arc(bc, base_radius + 12.0, k * TAU / 36.0, (k + 1) * TAU / 36.0, 4, Color(tc, 0.75), 6.0, true)
		var fp := fountain_pos(t)
		draw_circle(fp, 150.0, Color(tc, 0.18))
		draw_circle(fp, 90.0, Color(tc.lightened(0.4), 0.85))
		draw_circle(fp, 60.0, Color(0.85, 0.97, 1.0))
		draw_arc(fp, 150.0, 0, TAU, 48, Color(tc, 0.6), 3.0, true)
	# River
	if river.size() >= 2:
		draw_polyline(river, Color("2a6fa8"), river_width + 26.0, true)
		draw_polyline(river, river_color, river_width, true)
		draw_polyline(river, Color(1, 1, 1, 0.12), river_width * 0.45, true)
		for i in range(0, river.size(), 7):
			draw_circle(river[i] + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40)), rng.randf_range(6, 14), Color(1, 1, 1, 0.15))
	# Shrine island
	var sp := shrine_pos()
	draw_circle(sp, 150.0, Color("8f8a74"))
	draw_circle(sp, 130.0, Color("a8d08a"))
	draw_circle(sp, 70.0, Color(0.5, 1.0, 0.6, 0.35))
	draw_rect(Rect2(sp + Vector2(-12, -40), Vector2(24, 80)), Color("e9fff0"))
	draw_rect(Rect2(sp + Vector2(-40, -12), Vector2(80, 24)), Color("e9fff0"))
	# Jungle camps
	for c in camp_positions():
		draw_circle(c, 120.0, Color("5e9a46"))
		draw_arc(c, 120.0, 0, TAU, 40, Color(1, 0.95, 0.5, 0.45), 3.0, true)
	# Lane
	if lane.size() >= 2:
		draw_polyline(lane, Color("a88c62"), lane_width + 24.0, true)
		for i in range(0, lane.size(), 3):
			draw_circle(lane[i], (lane_width + 24.0) * 0.5, Color("a88c62"))
		draw_polyline(lane, lane_color, lane_width, true)
		for i in range(0, lane.size(), 3):
			draw_circle(lane[i], lane_width * 0.5, lane_color)
		for i in range(0, lane.size(), 2):
			draw_circle(lane[i] + Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60)), rng.randf_range(4, 10), Color(0.6, 0.48, 0.32, 0.25))
		# Direction chevrons (team colours)
		var total := lane.size()
		for i in range(14, total - 14, 14):
			var d := (lane[i + 1] - lane[i - 1]).normalized()
			var dawn_half := i < total / 2
			var dir := d if dawn_half else -d
			var col := Color(0.24, 0.6, 1.0, 0.45) if dawn_half else Color(1.0, 0.3, 0.37, 0.45)
			var c0 := lane[i]
			draw_polyline(PackedVector2Array([c0 - dir * 14.0 + dir.orthogonal() * 18.0, c0 + dir * 8.0, c0 - dir * 14.0 - dir.orthogonal() * 18.0]), col, 6.0, true)
		# Bridge where lane meets river
		var hit = _intersection(lane, river)
		if hit != null:
			var bp: Vector2 = hit[0]
			var bd: Vector2 = hit[1]
			var nrm := bd.orthogonal()
			var half_len := river_width * 0.5 + 70.0
			var half_w := lane_width * 0.5 + 16.0
			var quad := PackedVector2Array([bp - bd * half_len - nrm * half_w, bp + bd * half_len - nrm * half_w, bp + bd * half_len + nrm * half_w, bp - bd * half_len + nrm * half_w])
			draw_colored_polygon(quad, Color("6b4a2b"))
			var inner := PackedVector2Array([bp - bd * half_len - nrm * (half_w - 12), bp + bd * half_len - nrm * (half_w - 12), bp + bd * half_len + nrm * (half_w - 12), bp - bd * half_len + nrm * (half_w - 12)])
			draw_colored_polygon(inner, Color("8d6a43"))
			var steps := 12
			for k in steps + 1:
				var o := bp + bd * lerpf(-half_len, half_len, float(k) / steps)
				draw_line(o - nrm * (half_w - 12), o + nrm * (half_w - 12), Color("6b4a2b"), 3.0)
	# Trees
	for t in _trees:
		var p: Vector2 = t[0]
		var r: float = t[1]
		draw_circle(p + Vector2(r * 0.15, r * 0.3), r, Color(0, 0, 0, 0.22))
		draw_circle(p, r, Color("24582a"))
		draw_circle(p + Vector2(-r * 0.12, -r * 0.12), r * 0.78, Color("2f6d31"))
		draw_circle(p + Vector2(-r * 0.3, -r * 0.32), r * 0.35, Color("3e8540"))
	# Editor-only: show structure positions
	if Engine.is_editor_hint():
		var n := get_node_or_null("Structures")
		if n != null:
			for c in n.get_children():
				var tier = c.get("tier")
				var team = c.get("team_id")
				if tier == null or team == null:
					continue
				if int(tier) == 2:
					Art.draw_heartspire(self, (c as Node2D).position, 70.0, int(team))
				else:
					Art.draw_tower(self, (c as Node2D).position, 44.0, int(team))


func _intersection(a: PackedVector2Array, b: PackedVector2Array):
	for i in a.size() - 1:
		for j in b.size() - 1:
			var p = Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[j], b[j + 1])
			if p != null:
				return [p, (a[i + 1] - a[i]).normalized()]
	return null
