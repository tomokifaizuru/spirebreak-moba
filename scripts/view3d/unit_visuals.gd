class_name UnitVisuals
extends RefCounted
## 3D stand-ins for simulation units. The 2D sim (Unit nodes) stays the source of truth; every frame
## WorldView calls sync() and each visual copies position/state and plays procedural animation.

## Display size of units relative to their sim footprint (chibi heroes read better a bit large).
const HERO_SCALE := 1.45
const CREEP_SCALE := 1.45

static var _flash_mat: StandardMaterial3D


static func flash_mat() -> StandardMaterial3D:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_mat.albedo_color = Color(1, 1, 1, 0.3)
	return _flash_mat


class Base extends Node3D:
	var unit: Unit
	var view: WorldView
	var shadow: MeshInstance3D
	var last_pos := Vector2.ZERO
	var yaw := 0.0
	var speed := 0.0
	var gone := false   # unit freed: play out death then remove
	var gone_t := 0.0
	var flash_meshes: Array[MeshInstance3D] = []
	var flashing := false

	func setup(u: Unit, v: WorldView) -> void:
		unit = u
		view = v
		last_pos = u.position
		position = MeshKit.v3(u.position, 0.0)
		shadow = MeshKit.decal(Color(0, 0, 0, 0.38), 1.0, 0.0, 1)
		shadow.position.y = 0.035
		add_child(shadow)

	func set_shadow(r: float) -> void:
		shadow.scale = Vector3(r, 1, r)

	func ground_y(p: Vector2) -> float:
		return view.terrain.walk_height(p)

	## Turns smoothly toward a 2D direction (screen-down = +z faces the camera).
	func face(dir: Vector2, delta: float, rate := 12.0) -> void:
		if dir.length_squared() < 0.0001:
			return
		var target := atan2(dir.x, dir.y)
		yaw = lerp_angle(yaw, target, 1.0 - exp(-rate * delta))

	func move_from_unit(delta: float) -> Vector2:
		var p := unit.position
		var moved := p - last_pos
		last_pos = p
		speed = lerpf(speed, moved.length() * MeshKit.S / maxf(delta, 0.001), 1.0 - exp(-12.0 * delta))
		position = Vector3(p.x * MeshKit.S, ground_y(p), p.y * MeshKit.S)
		return moved

	func set_flash(on: bool) -> void:
		if on == flashing:
			return
		flashing = on
		for m in flash_meshes:
			m.material_overlay = UnitVisuals.flash_mat() if on else null

	func collect_meshes(n: Node) -> void:
		for c in n.get_children():
			if c is MeshInstance3D and c != shadow and not c.has_meta("no_flash"):
				flash_meshes.append(c)
			collect_meshes(c)

	## Returns false when the visual should be deleted.
	func sync(_delta: float) -> bool:
		return true

	## Where to draw the health bar (world position) and how wide (pixels).
	func bar_anchor() -> Vector3:
		return global_position + Vector3(0, 1.0, 0)


# ------------------------------------------------------------------ heroes
class HeroVis extends Base:
	var model: HeroModel
	var ring: MeshInstance3D
	var prev_anim := 0.0
	var prev_cds: Array[float] = [0, 0, 0, 0]
	var prev_flash := 0.0
	var was_alive := true
	var aura: MeshInstance3D
	var stun_fx: Node3D
	var recall_fx: MeshInstance3D
	var fade := 0.0

	func setup(u: Unit, v: WorldView) -> void:
		super.setup(u, v)
		var h := u as Hero
		model = HeroModel.new().build(h.data, h.team)
		model.scale *= UnitVisuals.HERO_SCALE
		add_child(model)
		var hs := h.data.model_scale * UnitVisuals.HERO_SCALE
		set_shadow(0.42 * hs)
		var col := Art.team_color(h.team)
		if h.is_player:
			col = Color("ffe066")
		ring = MeshKit.decal(Color(col, 0.9), 0.0, 0.16, 0, 1)
		ring.position.y = 0.04
		ring.scale = Vector3.ONE * 0.48 * hs
		add_child(ring)
		aura = MeshKit.inst(self, MeshKit.sphere(0.62 * hs, 10, 6), MeshKit.xf(Vector3(0, 0.5 * hs, 0)), MeshKit.mat_alpha(Color(0.55, 0.85, 1.0, 0.12), true))
		aura.visible = false
		stun_fx = Node3D.new()
		stun_fx.position.y = 1.15 * hs
		add_child(stun_fx)
		for i in 3:
			var star := MeshKit.inst(stun_fx, ModelLib.crystal(), MeshKit.xf(Vector3(cos(i * TAU / 3.0) * 0.22, 0, sin(i * TAU / 3.0) * 0.22), Vector3.ZERO, Vector3.ONE * 0.12), MeshKit.mat_glow(Color("ffe066")))
			star.set_meta("no_flash", true)
		stun_fx.visible = false
		recall_fx = MeshKit.inst(self, MeshKit.cyl(0.45, 0.45, 2.4, 12), MeshKit.xf(Vector3(0, 1.2, 0)), MeshKit.mat_alpha(Color(0.5, 0.8, 1.0, 0.25), true))
		recall_fx.visible = false
		for n in [aura, recall_fx]:
			n.set_meta("no_flash", true)
		collect_meshes(model)
		yaw = atan2(h.facing.x, h.facing.y)
		prev_cds = h.cds.duplicate()

	func sync(delta: float) -> bool:
		var h := unit as Hero
		if not is_instance_valid(h):
			return false
		var moved := move_from_unit(delta)
		var dashing := not h.dash.is_empty()
		var leap_h := 0.0
		if dashing:
			var opts: Dictionary = h.dash.get("opts", {})
			if opts.get("leap", false):
				var tot: float = maxf(h.dash.get("total", 1.0), 1.0)
				var k: float = 1.0 - h.dash.get("left", 0.0) / tot
				leap_h = sin(k * PI) * (1.8 if opts.get("high", false) else 0.9)
		if h.alive and not was_alive:
			model.revive()
		if not h.alive and was_alive:
			model.start_death()
		was_alive = h.alive
		# events
		if h.anim_t > prev_anim + 0.05:
			model.trigger_attack()
			if h.attack_target != null and is_instance_valid(h.attack_target):
				face(h.attack_target.position - h.position, 1.0, 1000.0)
		prev_anim = h.anim_t
		for i in 4:
			if h.cds[i] > prev_cds[i] + 0.5:
				model.trigger_cast()
			prev_cds[i] = h.cds[i]
		if h.hit_flash > prev_flash + 0.01:
			model.trigger_hurt()
		prev_flash = h.hit_flash
		if h.alive:
			if moved.length_squared() > 1.0:
				face(moved, delta)
			else:
				face(h.facing, delta, 6.0)
		rotation.y = yaw
		model.animate(delta, 0.0 if dashing else speed, dashing, h.stun_t > 0.0, leap_h)
		# visibility / fading
		var viewer := view.viewer_team()
		var hidden := h.alive and h.stealth_t > 0.0 and h.team != viewer and h.mark_t <= 0.0
		visible = not hidden and (h.alive or model.dead_t < 1.6)
		var want := 0.0
		if h.alive and h.stealth_t > 0.0:
			want = 0.55
		elif h.untargetable_t > 0.0:
			want = 0.4
		if absf(want - fade) > 0.01:
			fade = want
			model.set_fade(fade)
		set_flash(h.hit_flash > 0.0 and h.alive)
		ring.visible = h.alive
		shadow.visible = h.alive
		shadow.position.y = 0.035 - leap_h
		ring.position.y = 0.04 - leap_h
		aura.visible = h.alive and h.shield > 0.0
		stun_fx.visible = h.alive and h.stun_t > 0.0
		if stun_fx.visible:
			stun_fx.rotation.y += delta * 6.0
		recall_fx.visible = h.alive and h.recall_t > 0.0
		if recall_fx.visible:
			recall_fx.scale = Vector3(1.0 + 0.1 * sin(model.t * 8.0), 1, 1.0 + 0.1 * sin(model.t * 8.0))
		return true

	func bar_anchor() -> Vector3:
		return model.global_position + Vector3(0, 1.08 * (unit as Hero).data.model_scale * UnitVisuals.HERO_SCALE, 0)


# ------------------------------------------------------------------ creeps
class CreepVis extends Base:
	var body: MeshInstance3D
	var prev_cd := 0.0
	var t := 0.0
	var atk := 0.0
	var dead := false
	var kind := "melee"

	func setup(u: Unit, v: WorldView) -> void:
		super.setup(u, v)
		var c := u as Creep
		kind = "siege" if c.is_siege else ("ranged" if c.is_ranged else "melee")
		body = MeshKit.inst(self, ModelLib.creep(kind, c.team))
		scale = Vector3.ONE * UnitVisuals.CREEP_SCALE
		set_shadow(0.3 if kind != "siege" else 0.42)
		collect_meshes(self)
		t = float(u.get_instance_id() % 1000) * 0.01
		var dir := c.lane[mini(c.wp, c.lane.size() - 1)] - c.position if c.lane.size() > 0 else Vector2.DOWN
		yaw = atan2(dir.x, dir.y)

	func sync(delta: float) -> bool:
		t += delta
		if gone or not is_instance_valid(unit) or not unit.alive:
			if not dead:
				dead = true
				gone = true
			gone_t += delta
			# shatter: spin, shrink, sink
			body.scale = Vector3.ONE * maxf(0.0, 1.0 - gone_t * 2.2)
			body.rotation.y += delta * 10.0
			body.position.y = gone_t * 0.6
			shadow.visible = false
			return gone_t < 0.45
		var c := unit as Creep
		var moved := move_from_unit(delta)
		if c.attack_cd > prev_cd + 0.05:
			atk = 0.25
			if c.target != null and is_instance_valid(c.target):
				face(c.target.position - c.position, 1.0, 1000.0)
		prev_cd = c.attack_cd
		if moved.length_squared() > 0.5:
			face(moved, delta, 8.0)
		rotation.y = yaw
		var bob := 0.0
		var tilt := 0.0
		match kind:
			"melee":
				bob = absf(sin(t * 9.0)) * 0.04 * clampf(speed, 0.0, 1.0)
				tilt = sin(t * 9.0) * 0.12 * clampf(speed, 0.0, 1.0)
			"ranged":
				bob = sin(t * 3.0) * 0.05
			_:
				tilt = sin(t * 14.0) * 0.02 * clampf(speed, 0.0, 1.0)
		var lunge := 0.0
		if atk > 0.0:
			atk -= delta
			lunge = sin((1.0 - atk / 0.25) * PI) * (0.12 if kind == "melee" else -0.05)
		body.position = Vector3(0, bob, lunge)
		body.rotation = Vector3(0, 0, tilt)
		set_flash(c.hit_flash > 0.0)
		return true

	func bar_anchor() -> Vector3:
		return global_position + Vector3(0, (0.75 if kind != "siege" else 0.85) * UnitVisuals.CREEP_SCALE, 0)


# ------------------------------------------------------------------ towers & Heartspire
class StructVis extends Base:
	var body: MeshInstance3D
	var crystal: MeshInstance3D
	var bubble: MeshInstance3D
	var range_ring: MeshInstance3D
	var rubble: MeshInstance3D
	var crystal_mat: StandardMaterial3D
	var shards: Array[MeshInstance3D] = []
	var t := 0.0
	var heart := false
	var crystal_y := 2.75
	var prev_cd := 0.0
	var pulse := 0.0
	var destroyed := false
	var fall_t := -1.0

	func setup(u: Unit, v: WorldView) -> void:
		super.setup(u, v)
		var s := u as Structure
		heart = s.is_heartspire()
		var tc := Art.team_color(s.team)
		body = MeshKit.inst(self, ModelLib.heartspire_body(s.team) if heart else ModelLib.tower_body(s.team))
		crystal_mat = StandardMaterial3D.new()
		crystal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		crystal_mat.albedo_color = tc.lightened(0.25)
		crystal_y = 1.75 if heart else 2.75
		var cs := Vector3(0.95, 1.0, 0.95) if heart else Vector3(0.42, 0.42, 0.42)
		crystal = MeshKit.inst(self, ModelLib.crystal(), MeshKit.xf(Vector3(0, crystal_y, 0), Vector3.ZERO, cs), crystal_mat)
		if heart:
			for i in 4:
				var sh := MeshKit.inst(self, ModelLib.crystal(), MeshKit.xf(Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 0.18), crystal_mat)
				shards.append(sh)
		set_shadow(1.25 if heart else 0.85)
		bubble = MeshKit.inst(self, MeshKit.sphere(1.6 if heart else 1.15, 14, 8), MeshKit.xf(Vector3(0, 0.9, 0)), MeshKit.mat_alpha(Color(tc.lightened(0.5), 0.13), true))
		bubble.set_meta("no_flash", true)
		range_ring = MeshKit.decal(Color(1, 0.3, 0.3, 0.7), 0.04, 0.012, 0, 2)
		range_ring.position.y = 0.05
		var r := s.attack_range * MeshKit.S
		range_ring.scale = Vector3(r, 1, r)
		range_ring.visible = false
		add_child(range_ring)
		rubble = MeshKit.inst(self, ModelLib.heartspire_rubble(s.team) if heart else ModelLib.tower_rubble(s.team))
		rubble.visible = false
		collect_meshes(self)
		position.y = 0.0

	func sync(delta: float) -> bool:
		t += delta
		var s := unit as Structure
		if not is_instance_valid(s):
			return false
		position = MeshKit.v3(s.position, 0.0)
		if not s.alive:
			if not destroyed:
				destroyed = true
				fall_t = 0.0
			if fall_t >= 0.0:
				fall_t += delta
				var k := clampf(fall_t / 0.6, 0.0, 1.0)
				body.position.y = -k * 1.6
				body.rotation.z = k * 0.25
				crystal.position.y = crystal_y - k * 2.2
				crystal.scale = Vector3.ONE * (1.0 - k) * (0.95 if heart else 0.42)
				if k >= 1.0:
					fall_t = -1.0
					body.visible = false
					crystal.visible = false
					for sh in shards:
						sh.visible = false
					rubble.visible = true
			bubble.visible = false
			range_ring.visible = false
			shadow.visible = false
			set_flash(false)
			return true
		if s.attack_cd > prev_cd + 0.05:
			pulse = 0.25
		prev_cd = s.attack_cd
		pulse = maxf(0.0, pulse - delta)
		var hp := s.hp_frac()
		crystal.position.y = crystal_y + sin(t * 1.8) * 0.08
		crystal.rotation.y = t * (0.6 if heart else 1.2)
		var base_s := 0.95 if heart else 0.42
		crystal.scale = Vector3.ONE * base_s * (1.0 + pulse * 0.6)
		var tc := Art.team_color(s.team)
		crystal_mat.albedo_color = tc.lightened(0.15 + 0.35 * pulse).lerp(Color(0.35, 0.35, 0.4), (1.0 - hp) * 0.45)
		for i in shards.size():
			var a := t * 0.9 + i * TAU / shards.size()
			shards[i].position = Vector3(cos(a) * 1.15, 2.0 + sin(t * 2.0 + i) * 0.15, sin(a) * 1.15)
			shards[i].rotation.y = -a
		bubble.visible = s.invulnerable
		var p := view.player_hero()
		range_ring.visible = p != null and p.alive and s.team != p.team and p.position.distance_to(s.position) < s.attack_range + 260.0
		if range_ring.visible:
			var danger := s.target == p
			MeshKit.decal_set(range_ring, "color", Color(1, 0.25, 0.25, 0.9) if danger else Color(1, 0.6, 0.4, 0.55))
		set_flash(s.hit_flash > 0.0)
		return true

	func bar_anchor() -> Vector3:
		return global_position + Vector3(0, 2.75 if heart else 3.35, 0)


# ------------------------------------------------------------------ jungle monster
class NeutralVis extends Base:
	var body: MeshInstance3D
	var big := false
	var sc := 1.6
	var t := 0.0
	var prev_cd := 0.0
	var atk := 0.0

	func setup(u: Unit, v: WorldView) -> void:
		super.setup(u, v)
		big = u.radius > 24.0
		sc = 2.5 if big else 1.6
		body = MeshKit.inst(self, ModelLib.brambleback() if big else ModelLib.thornling(), MeshKit.xf(Vector3.ZERO, Vector3.ZERO, Vector3.ONE * sc))
		set_shadow(0.7 if big else 0.5)
		collect_meshes(self)
		t = float(u.get_instance_id() % 500) * 0.01

	func sync(delta: float) -> bool:
		t += delta
		if gone or not is_instance_valid(unit) or not unit.alive:
			gone = true
			gone_t += delta
			body.scale = Vector3(sc + gone_t * 2.0, maxf(0.0, sc - gone_t * 4.0), sc + gone_t * 2.0)
			shadow.visible = false
			return gone_t < 0.4
		var n := unit as NeutralMob
		var moved := move_from_unit(delta)
		if n.attack_cd > prev_cd + 0.05:
			atk = 0.3
		prev_cd = n.attack_cd
		if n.target != null and is_instance_valid(n.target):
			face(n.target.position - n.position, delta, 8.0)
		elif moved.length_squared() > 0.5:
			face(moved, delta, 8.0)
		rotation.y = yaw
		var sq := 1.0 + sin(t * 3.0) * 0.04
		if atk > 0.0:
			atk -= delta
			sq += sin((1.0 - atk / 0.3) * PI) * 0.18
		body.scale = Vector3(sc * sq, sc / sq, sc * sq)
		set_flash(n.hit_flash > 0.0)
		return true

	func bar_anchor() -> Vector3:
		return global_position + Vector3(0, 0.85, 0)
