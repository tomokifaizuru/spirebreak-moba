class_name WorldView
extends Node3D
## The 3D presentation of a match. The 2D simulation in Arena is unchanged (it also runs headless for
## bot sims); this node mirrors it every frame: units, projectiles, skill areas and effects.
## Created by Arena only when there is a screen.

## Camera pitch in degrees (90 = straight down).
@export var pitch := 56.0
## Distance from the camera to the followed point (metres). Bigger = see more of the map.
@export var distance := 10.5
## Vertical field of view in degrees.
@export var fov := 38.0

var arena: Arena
var cam: Camera3D
var terrain: Terrain3D
var sun: DirectionalLight3D
var visuals := {}   # instance id -> UnitVisuals.Base
var fx := {}        # instance id -> ProjVis / AreaVis
var oneshots: Array = []
var dyn: Node3D     # parent of all dynamic things
var shrine_crystal: MeshInstance3D
var shrine_mat: StandardMaterial3D
var fountain_cols: Array[MeshInstance3D] = []
var aim_range: MeshInstance3D
var aim_shape: MeshInstance3D
var focus := Vector3.ZERO
var t := 0.0
var _burst_pool: Array[CPUParticles3D] = []
var _burst_i := 0


func setup(a: Arena) -> void:
	arena = a
	name = "WorldView"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2a4d2a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c9dcff")
	e.ambient_light_energy = 0.62
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -38, 0)
	sun.light_energy = 0.95
	sun.light_color = Color("fff3dc")
	sun.shadow_enabled = false
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = fov
	cam.near = 0.5
	cam.far = 80.0
	add_child(cam)
	cam.current = true
	terrain = Terrain3D.new().build(a.map)
	add_child(terrain)
	dyn = Node3D.new()
	dyn.name = "Dynamic"
	add_child(dyn)
	_shrine()
	_fountains()
	aim_range = MeshKit.decal(Color(1, 1, 1, 0.55), 0.04, 0.02, 0, 5)
	aim_range.position.y = 0.07
	aim_range.visible = false
	add_child(aim_range)
	aim_shape = MeshKit.decal(Color(1, 1, 1, 0.75), 0.22, 0.12, 0, 6)
	aim_shape.position.y = 0.08
	aim_shape.visible = false
	add_child(aim_shape)
	for i in 10:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 24
		p.lifetime = 0.6
		p.direction = Vector3.UP
		p.spread = 70.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 3.2
		p.gravity = Vector3(0, -6.0, 0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.0
		var pm := MeshKit.Builder.new(1)
		pm.jitter = 0.0
		pm.octa(Vector3.ZERO, 0.05, 0.06, 0.06, Color.WHITE)
		p.mesh = pm.commit(_particle_mat())
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0))
		p.scale_amount_curve = curve
		add_child(p)
		_burst_pool.append(p)
	if a.player != null:
		focus = MeshKit.v3(a.player.position)
	_place_camera()
	sync_all(0.0)


static var _pmat: StandardMaterial3D


static func _particle_mat() -> StandardMaterial3D:
	if _pmat == null:
		_pmat = StandardMaterial3D.new()
		_pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pmat.vertex_color_use_as_albedo = true
	return _pmat


func _shrine() -> void:
	var sp := terrain.shrine
	shrine_mat = StandardMaterial3D.new()
	shrine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shrine_mat.albedo_color = Color("7dffb0")
	shrine_crystal = MeshKit.inst(self, ModelLib.crystal(), MeshKit.xf(Vector3(sp.x, 0.85, sp.y), Vector3.ZERO, Vector3.ONE * 0.38), shrine_mat)


func _fountains() -> void:
	for tm in [0, 1]:
		var fp: Vector2 = terrain.fountains[tm]
		var tc := Art.team_color(tm)
		var col := MeshKit.inst(self, MeshKit.cyl(0.55, 0.75, 3.2, 12), MeshKit.xf(Vector3(fp.x, 1.6, fp.y)), MeshKit.mat_alpha(Color(tc.lightened(0.4), 0.16), true))
		fountain_cols.append(col)
		var c := StandardMaterial3D.new()
		c.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		c.albedo_color = tc.lightened(0.35)
		var cr := MeshKit.inst(self, ModelLib.crystal(), MeshKit.xf(Vector3(fp.x, 0.95, fp.y), Vector3.ZERO, Vector3.ONE * 0.36), c)
		fountain_cols.append(cr)


func viewer_team() -> int:
	return arena.player.team if arena.player != null else 0


func player_hero() -> Hero:
	return arena.player


func _place_camera() -> void:
	var p := deg_to_rad(pitch)
	cam.fov = fov
	cam.position = focus + Vector3(0, sin(p), cos(p)) * distance
	cam.look_at(focus, Vector3.UP)


func _process(delta: float) -> void:
	t += delta
	var target := MeshKit.v3(arena.cam_focus)
	focus = target
	_place_camera()
	sync_all(delta)
	# shrine and fountain idle motion
	var ready := arena.shrine_ready()
	shrine_crystal.rotation.y += delta * (1.5 if ready else 0.3)
	shrine_crystal.position.y = 0.85 + sin(t * 2.0) * 0.08
	shrine_mat.albedo_color = Color("7dffb0") if ready else Color("5d6f66")
	for i in fountain_cols.size():
		if i % 2 == 1:
			fountain_cols[i].rotation.y += delta
			fountain_cols[i].position.y = 0.95 + sin(t * 1.7 + i) * 0.06
	_update_aim()


func sync_all(delta: float) -> void:
	for u in arena.units:
		if not is_instance_valid(u):
			continue
		var id := u.get_instance_id()
		if not visuals.has(id):
			var v: UnitVisuals.Base
			if u is Hero:
				v = UnitVisuals.HeroVis.new()
			elif u is Creep:
				v = UnitVisuals.CreepVis.new()
			elif u is Structure:
				v = UnitVisuals.StructVis.new()
			elif u is NeutralMob:
				v = UnitVisuals.NeutralVis.new()
			else:
				continue
			dyn.add_child(v)
			v.setup(u, self)
			visuals[id] = v
	for id in visuals.keys():
		var v2: UnitVisuals.Base = visuals[id]
		if not v2.sync(delta):
			v2.queue_free()
			visuals.erase(id)
	for n in arena.fx_nodes:
		if not is_instance_valid(n):
			continue
		var fid: int = n.get_instance_id()
		if fx.has(fid):
			continue
		var f: Node3D
		if n is Projectile:
			f = FxVisuals.ProjVis.new()
		elif n is AreaFx:
			f = FxVisuals.AreaVis.new()
		else:
			continue
		dyn.add_child(f)
		f.setup(n, self)
		fx[fid] = f
	for fid in fx.keys():
		var f2: Node3D = fx[fid]
		if not f2.sync(delta):
			f2.queue_free()
			fx.erase(fid)
	var keep: Array = []
	for o in oneshots:
		if o.sync(delta):
			keep.append(o)
		else:
			o.queue_free()
	oneshots = keep


## Health-bar anchors for the 2D overlay: [[unit, world_pos], ...] for visible units.
func bar_targets() -> Array:
	var out: Array = []
	for id in visuals:
		var v: UnitVisuals.Base = visuals[id]
		if v.gone or not v.visible or not is_instance_valid(v.unit) or not v.unit.alive:
			continue
		out.append([v.unit, v.bar_anchor()])
	return out


## Screen position -> 2D world position (pixels) on the ground plane.
func screen_to_world(screen: Vector2) -> Vector2:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 1e-4:
		return arena.cam_focus
	var k := -o.y / d.y
	var hit := o + d * k
	return Vector2(hit.x, hit.z) / MeshKit.S


func world_to_screen(p: Vector2, h := 0.0) -> Vector2:
	return cam.unproject_position(MeshKit.v3(p, h))


## The four ground corners of the view (2D pixels) for the minimap.
func view_quad() -> PackedVector2Array:
	var s := get_viewport().get_visible_rect().size
	return PackedVector2Array([screen_to_world(Vector2(0, 0)), screen_to_world(Vector2(s.x, 0)), screen_to_world(s), screen_to_world(Vector2(0, s.y))])


# ---------------- one-shot effects (called through Arena.fx_* helpers) ----------------

func ring_fx(pos: Vector2, r0: float, r1: float, col: Color, life := 0.35, width := 0.09) -> void:
	var o := FxVisuals.OneShot.new()
	o.kind = "ring"
	o.r0 = maxf(r0 * MeshKit.S, 0.05)
	o.r1 = maxf(r1 * MeshKit.S, 0.06)
	o.col = col
	o.life = life
	o.width = width
	o.position = MeshKit.v3(pos, 0.09)
	o.mi = MeshKit.decal(col, 0.0, 0.1, 0, 7)
	o.add_child(o.mi)
	dyn.add_child(o)
	oneshots.append(o)
	o.sync(0.0)
	if r1 > 120.0:
		burst(MeshKit.v3(pos, 0.2), col, 14, r1 * MeshKit.S * 0.6)


func slash_fx(pos: Vector2, dir: Vector2, r: float, col: Color) -> void:
	var o := FxVisuals.OneShot.new()
	o.kind = "slash"
	o.life = 0.2
	o.col = col
	o.r1 = r * MeshKit.S
	o.position = MeshKit.v3(pos, 0.3)
	o.rotation.y = atan2(-dir.x, -dir.y)
	o.mi = MeshKit.decal(col, 0.55, 0.3, 3, 7)
	MeshKit.decal_set(o.mi, "half_angle", 1.1)
	o.add_child(o.mi)
	dyn.add_child(o)
	oneshots.append(o)
	o.sync(0.0)


func beam_fx(a: Vector2, b: Vector2, col: Color, width := 6.0) -> void:
	var o := FxVisuals.OneShot.new()
	o.kind = "beam"
	o.life = 0.25
	o.col = col
	var a3 := MeshKit.v3(a, 0.5)
	var b3 := MeshKit.v3(b, 0.5)
	o.position = (a3 + b3) * 0.5
	var len := a3.distance_to(b3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	var w := maxf(width * MeshKit.S, 0.05)
	o.mi = MeshKit.inst(o, MeshKit.box(w, w, maxf(len, 0.01)), Transform3D.IDENTITY, m)
	dyn.add_child(o)
	if len > 0.01:
		o.look_at(b3, Vector3.UP)
	oneshots.append(o)


## Particle burst (crystal shards) at a 3D point.
func burst(at: Vector3, col: Color, amount := 18, spread_m := 0.4) -> void:
	var p := _burst_pool[_burst_i]
	_burst_i = (_burst_i + 1) % _burst_pool.size()
	p.global_position = at
	p.amount = clampi(amount, 4, 32)
	p.color = col
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(spread_m * 0.5, 0.05)
	p.restart()
	p.emitting = true


func unit_died(u: Unit) -> void:
	var col := Art.team_color(u.team) if u.team < 2 else Color("b5c94a")
	var h := 0.4
	if u is Structure:
		h = 1.5
		burst(MeshKit.v3(u.position, 2.0), col.lightened(0.3), 32, 1.5)
		burst(MeshKit.v3(u.position, 0.8), Color("9a9aa6"), 28, 1.2)
		return
	burst(MeshKit.v3(u.position, h), col.lightened(0.3), 20 if u is Hero else 10, 0.3)


# ---------------- aim preview ----------------

func _update_aim() -> void:
	var p := arena.player
	if p == null or p.aim_preview.is_empty() or not p.alive:
		aim_range.visible = false
		aim_shape.visible = false
		return
	var slot: int = p.aim_preview.get("slot", -1)
	if slot < 0 or slot >= p.data.abilities.size():
		aim_range.visible = false
		aim_shape.visible = false
		return
	var ab: AbilityData = p.data.abilities[slot]
	var d: Vector2 = p.aim_preview.get("dir", Vector2.ZERO)
	var mag: float = p.aim_preview.get("mag", 1.0)
	var cancel: bool = p.aim_preview.get("cancel", false)
	var col := Color(1, 0.3, 0.3, 0.8) if cancel else Color(1, 1, 1, 0.8)
	var origin := MeshKit.v3(p.position, 0.07)
	var rr := ab.cast_range * MeshKit.S
	aim_range.visible = ab.aim != "self"
	aim_range.position = origin
	aim_range.scale = Vector3(rr, 1, rr)
	FxVisuals.decal_ring_width(aim_range, rr, 0.05)
	aim_shape.visible = true
	MeshKit.decal_set(aim_shape, "color", col)
	aim_shape.rotation = Vector3.ZERO
	match ab.aim:
		"self":
			var r := (ab.radius if ab.radius > 0.0 else p.radius + 30.0) * MeshKit.S
			MeshKit.decal_set(aim_shape, "mode", 0)
			aim_shape.position = origin + Vector3(0, 0.01, 0)
			aim_shape.scale = Vector3(r, 1, r)
			FxVisuals.decal_ring_width(aim_shape, r, 0.07)
		"area":
			var r2 := maxf(ab.radius, 60.0) * MeshKit.S
			var pt := p.position + d * ab.cast_range * clampf(mag, 0.12, 1.0)
			MeshKit.decal_set(aim_shape, "mode", 0)
			aim_shape.position = MeshKit.v3(pt, 0.08)
			aim_shape.scale = Vector3(r2, 1, r2)
			FxVisuals.decal_ring_width(aim_shape, r2, 0.07)
			aim_shape.visible = d != Vector2.ZERO
		_:
			if d == Vector2.ZERO:
				aim_shape.visible = false
				return
			var w := 0.22
			if ab.aim == "line" and ab.radius > 0.0 and ab.id in [&"piercing_bolt", &"landslide", &"lullaby"]:
				w = maxf(ab.radius, 22.0) * MeshKit.S
			var length := rr
			MeshKit.decal_set(aim_shape, "mode", 2)
			MeshKit.decal_set(aim_shape, "ring", 0.25)
			aim_shape.rotation.y = atan2(-d.x, -d.y)
			aim_shape.scale = Vector3(w, 1, length * 0.5)
			aim_shape.position = origin + Vector3(d.x, 0, d.y) * length * 0.5 + Vector3(0, 0.01, 0)
