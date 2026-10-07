class_name Terrain3D
extends Node3D
## Builds the static 3D world from the 2D map markers: faceted ground with a carved river,
## the lane ribbon, bridge, base platforms, fountains, shrine island, jungle clearings, and
## trees/rocks/flowers as chunked MultiMeshes (one draw call per chunk). All procedural.

const CELL := 0.5          ## ground grid size in metres (smaller = smoother & more triangles)
const MARGIN := 9.0        ## world drawn past the playable square (metres)
const CHUNKS := 4          ## ground/tree chunks per side (for frustum culling)
const RIVER_DEPTH := 0.42
const WATER_Y := -0.13
const GRASS := Color("62a845")
const GRASS_DARK := Color("4b8d37")
const GRASS_LIGHT := Color("7cbd55")
const HILL := Color("3f7a33")
const SAND := Color("d2bb85")
const BED := Color("4f7f86")
const LANE := Color("dcc092")
const LANE_EDGE := Color("b4946a")

var map: ArenaMap
var size := 51.0
var river := PackedVector2Array()   # metres, coarse
var lane := PackedVector2Array()    # metres, smooth
var shrine := Vector2.ZERO
var camps: Array[Vector2] = []
var bases: Array[Vector2] = []
var fountains: Array[Vector2] = []
var base_r := 4.7
var rw := 1.9
var lw := 2.1
var bridge_pos := Vector2.INF
var bridge_dir := Vector2.RIGHT
var noise := FastNoiseLite.new()


func build(m: ArenaMap) -> Terrain3D:
	map = m
	name = "Terrain"
	var S := MeshKit.S
	size = m.map_size.x * S
	rw = m.river_width * S
	lw = m.lane_width * S
	base_r = m.base_radius * S
	var rv := m.get_river()
	for i in range(0, rv.size(), 3):
		river.append(rv[i] * S)
	river.append(rv[rv.size() - 1] * S)
	for p in m.get_lane():
		lane.append(p * S)
	shrine = m.shrine_pos() * S
	for c in m.camp_positions():
		camps.append(c * S)
	for t in [0, 1]:
		bases.append(m.base_center(t) * S)
		fountains.append(m.fountain_pos(t) * S)
	var hit = m._intersection(m.get_lane(), m.get_river())
	if hit != null:
		bridge_pos = hit[0] * S
		bridge_dir = hit[1]
	noise.seed = 7
	noise.frequency = 0.08
	_ground()
	_water()
	_lane()
	_bridge()
	_bases()
	_shrine_and_camps()
	_flora()
	return self


static func _dist_poly(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[i + 1])
		best = minf(best, p.distance_squared_to(q))
	return sqrt(best)


func _river_carve(p: Vector2) -> float:
	var d := _dist_poly(p, river)
	var k := 1.0 - smoothstep(rw * 0.5 - 0.15, rw * 0.5 + 0.45, d)
	k *= smoothstep(1.35, 1.75, p.distance_to(shrine))
	return k


## Ground height (metres) at a point in metres, without the river.
func _height_dry(p: Vector2) -> float:
	var out := maxf(maxf(-p.x, p.x - size), maxf(-p.y, p.y - size))
	var h := 0.0
	if out > -1.5:
		h += clampf((out + 1.5) * 0.32, 0.0, 2.2)
	var n := noise.get_noise_2dv(p)
	h += n * (0.1 + clampf(out + 1.5, 0.0, 4.0) * 0.12)
	# keep play areas flat
	var flat := 1.0
	for b in bases:
		flat = minf(flat, smoothstep(base_r + 0.3, base_r + 1.6, p.distance_to(b)))
	if out < 0.0:
		flat = minf(flat, smoothstep(lw * 0.5 + 0.2, lw * 0.5 + 1.5, _dist_poly(p, lane)) * 0.6 + 0.4)
	return h * flat if h > 0.0 else h * flat * 0.6


## Height a unit stands at (heroes wade in the river, stand on the bridge).
func walk_height(p_px: Vector2) -> float:
	var p := p_px * MeshKit.S
	if bridge_pos != Vector2.INF:
		var rel := p - bridge_pos
		if absf(rel.dot(bridge_dir)) < rw * 0.5 + 0.75 and absf(rel.dot(bridge_dir.orthogonal())) < lw * 0.5 + 0.2:
			return 0.1
	var k := _river_carve(p)
	return lerpf(0.0, WATER_Y + 0.03, k)


func _ground() -> void:
	var lo := -MARGIN
	var n := int(ceil((size + MARGIN * 2.0) / CELL))
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	var cols := PackedColorArray()
	cols.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var p := Vector2(lo + i * CELL, lo + j * CELL)
			var k := _river_carve(p)
			var h := _height_dry(p) * (1.0 - k) - RIVER_DEPTH * k
			hs[j * (n + 1) + i] = h
			var gn := noise.get_noise_2d(p.x * 2.3 + 40.0, p.y * 2.3)
			var col := GRASS.lerp(GRASS_LIGHT if gn > 0.0 else GRASS_DARK, absf(gn) * 1.4)
			var out := maxf(maxf(-p.x, p.x - size), maxf(-p.y, p.y - size))
			if out > 0.0:
				col = col.lerp(HILL, clampf(out / 3.0, 0.0, 0.8))
			for c in camps:
				var dc := p.distance_to(c)
				if dc < 1.6:
					col = col.lerp(Color("6f9a45"), 0.6 * (1.0 - dc / 1.6))
			if k > 0.05:
				col = col.lerp(SAND, smoothstep(0.05, 0.4, k)).lerp(BED, smoothstep(0.55, 0.95, k))
			cols[j * (n + 1) + i] = col
	var per := int(ceil(float(n) / CHUNKS))
	for cy in CHUNKS:
		for cx in CHUNKS:
			var b := MeshKit.Builder.new(100 + cy * CHUNKS + cx)
			b.jitter = 0.035
			for j in range(cy * per, mini((cy + 1) * per, n)):
				for i in range(cx * per, mini((cx + 1) * per, n)):
					var i00 := j * (n + 1) + i
					var i10 := i00 + 1
					var i01 := i00 + n + 1
					var i11 := i01 + 1
					var p00 := Vector3(lo + i * CELL, hs[i00], lo + j * CELL)
					var p10 := Vector3(lo + (i + 1) * CELL, hs[i10], lo + j * CELL)
					var p01 := Vector3(lo + i * CELL, hs[i01], lo + (j + 1) * CELL)
					var p11 := Vector3(lo + (i + 1) * CELL, hs[i11], lo + (j + 1) * CELL)
					if (i + j) % 2 == 0:
						b.tri(p00, p10, p11, (cols[i00] + cols[i10] + cols[i11]) / 3.0, Vector3.UP)
						b.tri(p00, p11, p01, (cols[i00] + cols[i11] + cols[i01]) / 3.0, Vector3.UP)
					else:
						b.tri(p00, p10, p01, (cols[i00] + cols[i10] + cols[i01]) / 3.0, Vector3.UP)
						b.tri(p10, p11, p01, (cols[i10] + cols[i11] + cols[i01]) / 3.0, Vector3.UP)
			if not b.is_empty():
				MeshKit.inst(self, b.commit())


## Ribbon along a polyline (UV.x across 0..1). Returns the ArrayMesh.
static func ribbon(pts: PackedVector2Array, width: float, y: float, col := Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cw := MeshKit.front_is_cw()
	for i in pts.size() - 1:
		var d0 := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var d1 := (pts[mini(i + 2, pts.size() - 1)] - pts[i]).normalized()
		var n0 := d0.orthogonal() * width * 0.5
		var n1 := d1.orthogonal() * width * 0.5
		var a := Vector3(pts[i].x + n0.x, y, pts[i].y + n0.y)
		var b := Vector3(pts[i].x - n0.x, y, pts[i].y - n0.y)
		var c := Vector3(pts[i + 1].x + n1.x, y, pts[i + 1].y + n1.y)
		var d := Vector3(pts[i + 1].x - n1.x, y, pts[i + 1].y - n1.y)
		var quad := [[a, 0.0], [b, 1.0], [c, 0.0], [b, 1.0], [d, 1.0], [c, 0.0]]
		for t in 2:
			var tri: Array = quad.slice(t * 3, t * 3 + 3)
			var cr: Vector3 = (tri[1][0] - tri[0][0]).cross(tri[2][0] - tri[0][0])
			if (cr.y < 0.0) != cw:
				tri = [tri[0], tri[2], tri[1]]
			for v in tri:
				st.set_normal(Vector3.UP)
				st.set_color(col)
				st.set_uv(Vector2(v[1], 0.0))
				st.add_vertex(v[0])
	return st.commit()


func _water() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	var pts := PackedVector2Array()
	var rv := map.get_river()
	for p in rv:
		pts.append(p * MeshKit.S)
	# extend past the map so the ends never show
	pts.insert(0, pts[0] + (pts[0] - pts[1]).normalized() * 8.0)
	pts.append(pts[pts.size() - 1] + (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized() * 8.0)
	MeshKit.inst(self, ribbon(pts, rw + 1.0, WATER_Y), Transform3D.IDENTITY, mat)


func _lane() -> void:
	# Skip the part that crosses the river (the bridge covers it).
	var parts: Array[PackedVector2Array] = [PackedVector2Array()]
	for p in lane:
		if _dist_poly(p, river) < rw * 0.5 + 0.5:
			if parts[parts.size() - 1].size() > 0:
				parts.append(PackedVector2Array())
			continue
		parts[parts.size() - 1].append(p)
	for part in parts:
		if part.size() < 2:
			continue
		MeshKit.inst(self, ribbon(part, lw + 0.3, 0.012, LANE_EDGE), Transform3D.IDENTITY, MeshKit.mat_vc())
		MeshKit.inst(self, ribbon(part, lw, 0.022, LANE), Transform3D.IDENTITY, MeshKit.mat_vc())
	# pebbles and team chevrons
	var b := MeshKit.Builder.new(201)
	b.jitter = 0.04
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(0, lane.size(), 2):
		if _dist_poly(lane[i], river) < rw * 0.5 + 0.6:
			continue
		var off := Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
		var q := lane[i] + off
		var r := rng.randf_range(0.04, 0.09)
		b.flat_poly(PackedVector2Array([q + Vector2(r, 0), q + Vector2(0, r), q + Vector2(-r, 0), q + Vector2(0, -r)]), 0.026, LANE_EDGE.lightened(0.1))
	var total := lane.size()
	for i in range(14, total - 14, 14):
		if _dist_poly(lane[i], river) < rw * 0.5 + 0.6:
			continue
		var d := (lane[i + 1] - lane[i - 1]).normalized()
		var dawn := i < total / 2
		var dir := d if dawn else -d
		var col := LANE.lerp(Art.team_color(0 if dawn else 1), 0.45)
		var c0 := lane[i]
		var o := dir.orthogonal()
		for side in [-1.0, 1.0]:
			var tip: Vector2 = c0 + dir * 0.1
			var wing: Vector2 = c0 - dir * 0.14 + o * 0.2 * side
			var wing2: Vector2 = wing + dir * 0.08
			var tip2: Vector2 = tip - dir * 0.0 + o * 0.0
			b.flat_poly(PackedVector2Array([tip2 - dir * 0.08, wing, wing2, tip2]), 0.027, col)
	MeshKit.inst(self, b.commit())


func _bridge() -> void:
	if bridge_pos == Vector2.INF:
		return
	var b := MeshKit.Builder.new(211)
	b.jitter = 0.07
	var half_len := rw * 0.5 + 0.75
	var half_w := lw * 0.5 + 0.18
	var ang := -bridge_dir.angle()
	var dark := Color("6b4a2b")
	var wood := Color("9a7044")
	var basis := Basis(Vector3.UP, ang)
	var at := func(along: float, across: float, y: float) -> Vector3:
		var p := bridge_pos + bridge_dir * along + bridge_dir.orthogonal() * across
		return Vector3(p.x, y, p.y)
	b.add(MeshKit.box(half_len * 2.0, 0.1, half_w * 2.0), dark, Transform3D(basis, at.call(0.0, 0.0, 0.03)))
	var planks := 14
	for k in planks:
		var along := lerpf(-half_len + 0.12, half_len - 0.12, (k + 0.5) / planks)
		b.add(MeshKit.box(half_len * 2.0 / planks * 0.85, 0.05, half_w * 2.0 - 0.15), wood, Transform3D(basis, at.call(along, 0.0, 0.1)))
	for side in [-1.0, 1.0]:
		b.add(MeshKit.box(half_len * 2.0, 0.06, 0.08), dark, Transform3D(basis, at.call(0.0, side * (half_w - 0.04), 0.33)))
		for k in 5:
			var along2 := lerpf(-half_len + 0.05, half_len - 0.05, k / 4.0)
			b.add(MeshKit.box(0.09, 0.32, 0.09), dark, Transform3D(basis, at.call(along2, side * (half_w - 0.04), 0.2)))
	MeshKit.inst(self, b.commit())


func _bases() -> void:
	for t in [0, 1]:
		var tc := Art.team_color(t)
		var b := MeshKit.Builder.new(221 + t)
		b.jitter = 0.03
		var bc: Vector2 = bases[t]
		var c3 := Vector3(bc.x, 0, bc.y)
		b.add(MeshKit.cyl(base_r + 0.25, base_r + 0.4, 0.1, 28), Color("8f8775"), MeshKit.xf(c3 + Vector3(0, 0.0, 0)))
		b.add(MeshKit.cyl(base_r, base_r + 0.05, 0.1, 28), Color("cfc6ad"), MeshKit.xf(c3 + Vector3(0, 0.04, 0)))
		b.add(MeshKit.cyl(base_r * 0.8, base_r * 0.8, 0.1, 24), Color("d9d0b7"), MeshKit.xf(c3 + Vector3(0, 0.045, 0)))
		for k in 18:
			var a := k * TAU / 18.0
			b.add(MeshKit.box(0.5, 0.08, 0.16), tc.darkened(0.1), MeshKit.xf(c3 + Vector3(cos(a) * (base_r + 0.12), 0.08, sin(a) * (base_r + 0.12)), Vector3(0, -rad_to_deg(a) + 90.0, 0)))
		# Fountain pool
		var fp: Vector2 = fountains[t]
		var f3 := Vector3(fp.x, 0, fp.y)
		b.add(MeshKit.cyl(1.55, 1.65, 0.12, 20), Color("a8a08c"), MeshKit.xf(f3 + Vector3(0, 0.03, 0)))
		b.add(MeshKit.cyl(1.25, 1.25, 0.14, 20), tc.lightened(0.35), MeshKit.xf(f3 + Vector3(0, 0.04, 0)))
		b.add(MeshKit.cyl(0.42, 0.55, 0.3, 8), ModelLib.STONE, MeshKit.xf(f3 + Vector3(0, 0.15, 0)))
		for k in 6:
			var a2 := k * TAU / 6.0
			b.add(MeshKit.cyl(0.07, 0.1, 0.55, 6), ModelLib.STONE_LIGHT, MeshKit.xf(f3 + Vector3(cos(a2) * 1.45, 0.3, sin(a2) * 1.45)))
			b.octa(f3 + Vector3(cos(a2) * 1.45, 0.66, sin(a2) * 1.45), 0.06, 0.12, 0.06, tc.lightened(0.2))
		MeshKit.inst(self, b.commit())


func _shrine_and_camps() -> void:
	var b := MeshKit.Builder.new(231)
	b.jitter = 0.06
	var s3 := Vector3(shrine.x, 0, shrine.y)
	b.add(MeshKit.cyl(1.25, 1.45, 0.16, 12), Color("8f8a74"), MeshKit.xf(s3 + Vector3(0, -0.04, 0)), 0.03)
	b.add(MeshKit.cyl(1.05, 1.1, 0.1, 12), Color("a6cf86"), MeshKit.xf(s3 + Vector3(0, 0.02, 0)))
	b.add(MeshKit.cyl(0.32, 0.42, 0.22, 6), ModelLib.STONE_LIGHT, MeshKit.xf(s3 + Vector3(0, 0.12, 0)))
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		b.add(MeshKit.box(0.16, 0.5, 0.16), ModelLib.STONE_LIGHT, MeshKit.xf(s3 + Vector3(cos(a) * 0.85, 0.25, sin(a) * 0.85), Vector3(0, k * 30, 4)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for c in camps:
		for k in 6:
			var a2 := k * TAU / 6.0 + rng.randf() * 0.4
			var p := c + Vector2.from_angle(a2) * rng.randf_range(1.35, 1.6)
			b.add(MeshKit.sphere(0.16, 5, 3, 0.2), Color("8d8b86"), MeshKit.xf(Vector3(p.x, 0.04, p.y), Vector3(0, rng.randf() * 360.0, 0)), 0.04)
	MeshKit.inst(self, b.commit())


## Trees from the 2D map (exact blockers), an outer forest ring, rocks and flowers.
func _flora() -> void:
	var chunk := func(p: Vector2) -> int:
		var span := (size + MARGIN * 2.0) / CHUNKS
		var cx := clampi(int((p.x + MARGIN) / span), 0, CHUNKS - 1)
		var cy := clampi(int((p.y + MARGIN) / span), 0, CHUNKS - 1)
		return cy * CHUNKS + cx
	var sets := {"tree": {}, "bush_tree": {}, "rock": {}, "tuft": {}, "flower": {}}
	var add := func(kind: String, p: Vector2, s: Vector3, yaw: float, col := Color.WHITE) -> void:
		var ci: int = chunk.call(p)
		var d: Dictionary = sets[kind]
		if not d.has(ci):
			d[ci] = []
		var y := _height_dry(p) * (1.0 - _river_carve(p))
		d[ci].append([Transform3D(Basis(Vector3.UP, yaw).scaled(s), Vector3(p.x, y - 0.02, p.y)), col])
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for t in map._trees:
		var p: Vector2 = t[0] * MeshKit.S
		var r: float = t[1] * MeshKit.S
		var k := r / 0.55
		if rng.randf() < 0.22:
			add.call("bush_tree", p, Vector3(k, k * rng.randf_range(0.9, 1.1), k), rng.randf() * TAU)
		else:
			add.call("tree", p, Vector3(k, k * rng.randf_range(0.95, 1.3), k), rng.randf() * TAU)
	# outer forest
	var step := 1.25
	var y0 := -MARGIN + 0.5
	while y0 < size + MARGIN:
		var x0 := -MARGIN + 0.5
		while x0 < size + MARGIN:
			var p2 := Vector2(x0, y0) + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
			var out := maxf(maxf(-p2.x, p2.x - size), maxf(-p2.y, p2.y - size))
			if out > -0.4 and _river_carve(p2) < 0.01 and _dist_poly(p2, river) > rw * 0.5 + 0.6:
				var k2 := rng.randf_range(0.9, 1.5)
				add.call("tree" if rng.randf() < 0.8 else "bush_tree", p2, Vector3(k2, k2 * rng.randf_range(0.9, 1.3), k2), rng.randf() * TAU)
			x0 += step
		y0 += step
	# rocks, grass tufts and flowers on open ground
	var flower_cols := [Color("fff3b0"), Color("ffb3d9"), Color("ffffff"), Color("b9d4ff")]
	for i in 900:
		var p3 := Vector2(rng.randf_range(0.3, size - 0.3), rng.randf_range(0.3, size - 0.3))
		if _dist_poly(p3, lane) < lw * 0.5 + 0.25 or _river_carve(p3) > 0.02:
			continue
		var in_base := false
		for bc in bases:
			if p3.distance_to(bc) < base_r + 0.4:
				in_base = true
		if in_base:
			continue
		var roll := rng.randf()
		if roll < 0.1:
			var k3 := rng.randf_range(0.14, 0.34)
			add.call("rock", p3, Vector3(k3, k3 * rng.randf_range(0.6, 1.0), k3), rng.randf() * TAU)
		elif roll < 0.62:
			add.call("tuft", p3, Vector3.ONE * rng.randf_range(0.8, 1.4), rng.randf() * TAU)
		else:
			add.call("flower", p3, Vector3.ONE * rng.randf_range(0.8, 1.3), rng.randf() * TAU, flower_cols[rng.randi() % flower_cols.size()])
	for kind in sets:
		var mesh: Mesh = Callable(ModelLib, kind).call()
		var use_col: bool = kind == "flower"
		for ci in sets[kind]:
			var items: Array = sets[kind][ci]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = use_col
			mm.mesh = mesh
			mm.instance_count = items.size()
			for i2 in items.size():
				mm.set_instance_transform(i2, items[i2][0])
				if use_col:
					mm.set_instance_color(i2, items[i2][1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
