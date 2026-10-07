class_name MeshKit
extends RefCounted
## Low-poly mesh helpers for the 3D view. Every model in the game is built here from code
## (boxes, cylinders, cones, spheres) - no model files. Meshes are flat shaded with one colour
## per triangle (vertex colours), so a whole multi-coloured model is a single draw call.

## World pixels (gameplay units) -> 3D metres. The simulation is still 2D; y in 2D is z in 3D.
const S := 0.01

static var _vc_mat: StandardMaterial3D
static var _vc_glow: StandardMaterial3D
static var _glow := {}
static var _alpha := {}
static var _decal_shader: Shader
static var _cw := 0


static func v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x * S, y, p.y * S)


static func v2(p: Vector3) -> Vector2:
	return Vector2(p.x / S, p.z / S)


static func xf(pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl)
	return Transform3D(b, pos)


# ---------------- materials ----------------

## Shared material for all vertex-coloured meshes.
static func mat_vc() -> StandardMaterial3D:
	if _vc_mat == null:
		_vc_mat = StandardMaterial3D.new()
		_vc_mat.vertex_color_use_as_albedo = true
		_vc_mat.roughness = 1.0
		_vc_mat.metallic_specular = 0.2
		_vc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return _vc_mat


## Unshaded vertex-colour material (glowing multi-colour meshes like projectiles).
static func mat_glow_vc() -> StandardMaterial3D:
	if _vc_glow == null:
		_vc_glow = StandardMaterial3D.new()
		_vc_glow.vertex_color_use_as_albedo = true
		_vc_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _vc_glow


## Bright unshaded colour (crystals, lanterns, projectiles).
static func mat_glow(col: Color) -> StandardMaterial3D:
	var k := col.to_html()
	if not _glow.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		_glow[k] = m
	return _glow[k]


## See-through unshaded colour (shield bubbles, light columns). additive = glowy blend.
static func mat_alpha(col: Color, additive := false) -> StandardMaterial3D:
	var k := col.to_html() + ("a" if additive else "")
	if not _alpha.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = col
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		if additive:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_alpha[k] = m
	return _alpha[k]


# ---------------- ground decals (rings, discs, blob shadows, aim lines) ----------------

static func decal_shader() -> Shader:
	if _decal_shader == null:
		_decal_shader = load("res://shaders/ground_decal.gdshader")
	return _decal_shader


## A flat circle/rectangle lying on the ground. Returns the MeshInstance3D (unit size: radius 1).
## mode 0 = circle (fill + ring), 1 = soft blob, 2 = rectangle (aim line), 3 = pie (aim cone).
static func decal(col: Color, fill := 0.15, ring := 0.1, mode := 0, priority := 0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = decal_shader()
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("fill", fill)
	m.set_shader_parameter("ring", ring)
	m.set_shader_parameter("mode", mode)
	m.render_priority = priority
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func decal_set(mi: MeshInstance3D, param: String, v) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter(param, v)


# ---------------- primitive shortcuts ----------------

static func box(w: float, h: float, d: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(w, h, d)
	return m


static func cyl(r_top: float, r_bottom: float, h: float, sides := 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = sides
	m.rings = 0
	return m


static func cone(r: float, h: float, sides := 7) -> CylinderMesh:
	return cyl(0.0, r, h, sides)


static func sphere(r: float, radial := 8, rings := 5, h := -1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 if h < 0.0 else h
	m.radial_segments = radial
	m.rings = rings
	return m


static func prism(w: float, h: float, d: float) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = Vector3(w, h, d)
	return m


static func torus(inner: float, outer: float, sides := 12, ring_sides := 4) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = sides
	m.ring_segments = ring_sides
	return m


# ---------------- builder ----------------

## True when Godot treats clockwise triangles as front faces (checked once from a BoxMesh).
static func front_is_cw() -> bool:
	if _cw == 0:
		var arr := BoxMesh.new().get_mesh_arrays()
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var cr := (vv[ii[1]] - vv[ii[0]]).cross(vv[ii[2]] - vv[ii[0]])
		_cw = 1 if cr.dot(nn[ii[0]]) < 0.0 else 2
	return _cw == 1


## Collects coloured, flat-shaded triangles from several parts, then commit() -> one ArrayMesh.
class Builder:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	## Random brightness change per triangle (0.04 = +-4%) for the faceted look.
	var jitter := 0.05
	var rng := RandomNumberGenerator.new()

	func _init(seed_value := 7) -> void:
		rng.seed = seed_value

	## Adds a primitive mesh with one colour, moved by `t`.
	func add(m: PrimitiveMesh, col: Color, t := Transform3D.IDENTITY, warp := 0.0) -> Builder:
		var arr := m.get_mesh_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if warp > 0.0:
			# Jitter shared vertices the same way (keeps the mesh closed): rocks, bushes.
			var moved := {}
			for i in verts.size():
				var key := Vector3i((verts[i] * 1000.0).round())
				if not moved.has(key):
					moved[key] = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * warp
				verts[i] += moved[key]
		var nb := t.basis.inverse().transposed()
		if idx.is_empty():
			for i in range(0, verts.size(), 3):
				tri(t * verts[i], t * verts[i + 1], t * verts[i + 2], col, nb * (norms[i] + norms[i + 1] + norms[i + 2]), true)
		else:
			for i in range(0, idx.size(), 3):
				var a := idx[i]
				var b := idx[i + 1]
				var d := idx[i + 2]
				tri(t * verts[a], t * verts[b], t * verts[d], col, nb * (norms[a] + norms[b] + norms[d]), true)
		return self

	## One triangle. `out` = which way it should face. keep_order = trust the given winding.
	func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, out := Vector3.ZERO, keep_order := false) -> void:
		var fn := (b - a).cross(d - a)
		if fn.length_squared() < 1e-14:
			return
		fn = fn.normalized()
		if out != Vector3.ZERO and fn.dot(out) < 0.0:
			fn = -fn
			if not keep_order:
				var tmp := b
				b = d
				d = tmp
		elif not keep_order:
			# Make the winding match Godot's front-face rule for normal fn.
			pass
		if not keep_order:
			var cr := (b - a).cross(d - a)
			var want_neg := MeshKit.front_is_cw()
			if (cr.dot(fn) < 0.0) != want_neg:
				var tmp2 := b
				b = d
				d = tmp2
		var cc := col
		if jitter > 0.0:
			var j := rng.randf_range(-jitter, jitter)
			cc = col.lightened(j) if j > 0.0 else col.darkened(-j)
		v.append(a)
		v.append(b)
		v.append(d)
		for k in 3:
			n.append(fn)
			c.append(cc)

	## Diamond / crystal shape: 4 sides, separate top and bottom heights.
	func octa(center: Vector3, rx: float, top: float, bottom: float, col: Color, rz := -1.0) -> Builder:
		var r2 := rx if rz < 0.0 else rz
		var up := center + Vector3(0, top, 0)
		var dn := center - Vector3(0, bottom, 0)
		var ring := [center + Vector3(rx, 0, 0), center + Vector3(0, 0, r2), center + Vector3(-rx, 0, 0), center + Vector3(0, 0, -r2)]
		for i in 4:
			var p: Vector3 = ring[i]
			var q: Vector3 = ring[(i + 1) % 4]
			var mid := (p + q) * 0.5 - center
			tri(up, p, q, col, mid + Vector3(0, top * 0.5, 0))
			tri(dn, q, p, col, mid - Vector3(0, bottom * 0.5, 0))
		return self

	## Flat polygon facing up (y = height), from 2D points in metres.
	func flat_poly(pts: PackedVector2Array, y: float, col: Color) -> Builder:
		for i in range(1, pts.size() - 1):
			tri(Vector3(pts[0].x, y, pts[0].y), Vector3(pts[i].x, y, pts[i].y), Vector3(pts[i + 1].x, y, pts[i + 1].y), col, Vector3.UP)
		return self

	func is_empty() -> bool:
		return v.is_empty()

	func commit(mat: Material = null) -> ArrayMesh:
		var m := ArrayMesh.new()
		if v.is_empty():
			return m
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(0, mat if mat != null else MeshKit.mat_vc())
		return m


## A MeshInstance3D child with `mesh`, no shadows.
static func inst(parent: Node, mesh: Mesh, t := Transform3D.IDENTITY, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = t
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mat != null:
		mi.material_override = mat
	parent.add_child(mi)
	return mi
