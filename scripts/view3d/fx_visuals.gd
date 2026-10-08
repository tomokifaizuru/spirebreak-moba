class_name FxVisuals
extends RefCounted
## 3D visuals for projectiles and lingering skill areas (they mirror Projectile / AreaFx sim nodes),
## plus short one-shot effects (expanding rings, slashes, beams, particle bursts).


static func decal_ring_width(mi: MeshInstance3D, radius_m: float, width_m: float) -> void:
	MeshKit.decal_set(mi, "ring", clampf(width_m / maxf(radius_m, 0.01), 0.01, 1.0))


# ------------------------------------------------------------------ projectiles
class ProjVis extends Node3D:
	var proj: Projectile
	var view: WorldView
	var mesh: MeshInstance3D
	var trail: Array[MeshInstance3D] = []
	var hist: Array[Vector3] = []
	var start_h := 0.6
	var start_pos := Vector2.ZERO
	var t := 0.0
	var dead_t := -1.0
	var style := ""

	func setup(p: Projectile, v: WorldView) -> void:
		proj = p
		view = v
		style = p.style
		start_pos = p.position
		var src := p.src()
		if src is Structure:
			start_h = 2.7 if not (src as Structure).is_heartspire() else 1.8
		elif src is Creep:
			start_h = 0.45
		elif style == "fountain":
			start_h = 1.5
		else:
			start_h = 0.6
		mesh = MeshKit.inst(self, ModelLib.projectile(style, p.team))
		if style in ["wisp", "tower", "bolt", "petal", "note", "orb", "fountain"]:
			var col := Color(0.6, 0.95, 1.0, 0.5)
			match style:
				"tower": col = Color(Art.team_color(p.team).lightened(0.3), 0.5)
				"fountain": col = Color(Art.team_color(p.team).lightened(0.55), 0.65)
				"bolt": col = Color(1.0, 0.85, 0.45, 0.5)
				"petal", "note": col = Color(1.0, 0.6, 0.85, 0.5)
				"orb": col = Color(0.75, 0.6, 1.0, 0.5)
			var tr_k := 2.2 if style == "fountain" else 1.0
			for i in 4:
				var tm := MeshKit.inst(self, MeshKit.sphere((0.07 - i * 0.012) * tr_k, 6, 4), Transform3D.IDENTITY, MeshKit.mat_alpha(col, true))
				tm.top_level = true
				trail.append(tm)
		if style == "note":
			mesh.scale = Vector3.ONE * 1.6
		position = _pos3()

	func _pos3() -> Vector3:
		var p := proj.position
		var h := 0.6
		var total := 1.0
		var done := 0.0
		if proj.homing and is_instance_valid(proj.target):
			done = start_pos.distance_to(p)
			total = done + p.distance_to(proj.target.position)
		else:
			done = proj.traveled
			total = maxf(proj.max_dist, 1.0)
		var k := clampf(done / maxf(total, 1.0), 0.0, 1.0)
		h = lerpf(start_h, 0.5, k)
		if style == "siege":
			h += sin(k * PI) * 1.2
		return Vector3(p.x * MeshKit.S, h, p.y * MeshKit.S)

	func sync(delta: float) -> bool:
		t += delta
		if dead_t >= 0.0 or not is_instance_valid(proj) or proj.done:
			if dead_t < 0.0:
				dead_t = 0.0
				mesh.visible = false
			dead_t += delta
			for i in trail.size():
				trail[i].scale = Vector3.ONE * maxf(0.0, 1.0 - dead_t * 5.0)
			return dead_t < 0.2
		var np := _pos3()
		var vel := np - position
		position = np
		if vel.length_squared() > 1e-6:
			var fwd := vel.normalized()
			if absf(fwd.dot(Vector3.UP)) < 0.99:
				mesh.basis = Basis.looking_at(-fwd, Vector3.UP)
		if style in ["wisp", "orb", "tower", "fountain"]:
			mesh.scale = Vector3.ONE * (1.0 + 0.15 * sin(t * 20.0))
		elif style == "petal":
			mesh.rotate_object_local(Vector3.FORWARD, delta * 14.0)
		hist.push_front(np)
		if hist.size() > trail.size() * 2 + 1:
			hist.pop_back()
		for i in trail.size():
			trail[i].global_position = hist[mini(i * 2 + 1, hist.size() - 1)]
		return true


# ------------------------------------------------------------------ areas
class AreaVis extends Node3D:
	var area: AreaFx
	var view: WorldView
	var disc: MeshInstance3D
	var inner: MeshInstance3D
	var bits: Array[MeshInstance3D] = []
	var t := 0.0
	var fade_t := -1.0
	var kind := ""
	var r := 1.0
	var flashed := false

	func setup(a: AreaFx, v: WorldView) -> void:
		area = a
		view = v
		kind = a.kind
		r = a.radius * MeshKit.S
		position = MeshKit.v3(a.position, 0.0)
		var col := Color(1.0, 0.8, 0.4, 0.8)
		match kind:
			"glow": col = Color(0.6, 0.95, 1.0, 0.7)
			"snare": col = Color(1.0, 0.9, 0.3, 0.9)
			"bloom": col = Color(1.0, 0.55, 0.92, 0.9)
			"chorus": col = Color(0.5, 1.0, 0.6, 0.85)
		if kind != "wall":
			disc = MeshKit.decal(col, 0.16, 0.06, 0, 3)
			disc.position.y = 0.06
			disc.scale = Vector3(r, 1, r)
			add_child(disc)
			FxVisuals.decal_ring_width(disc, r, 0.07)
		match kind:
			"volley":
				for i in 10:
					var m := MeshKit.inst(self, ModelLib.projectile("arrow", a.team), Transform3D.IDENTITY)
					m.rotation = Vector3(PI * 0.5, 0, 0)
					bits.append(m)
			"glow":
				for i in 5:
					bits.append(MeshKit.inst(self, MeshKit.sphere(0.06, 6, 4), Transform3D.IDENTITY, MeshKit.mat_alpha(Color(0.7, 1.0, 1.0, 0.7), true)))
			"snare":
				inner = MeshKit.decal(Color(1, 0.95, 0.55, 0.8), 0.0, 0.08, 0, 4)
				inner.position.y = 0.07
				add_child(inner)
				for i in 5:
					var star := MeshKit.inst(self, ModelLib.crystal(), Transform3D.IDENTITY, MeshKit.mat_glow(Color("ffe066")))
					bits.append(star)
			"bloom":
				for i in 6:
					var pm := MeshKit.Builder.new(300 + i)
					pm.jitter = 0.0
					pm.add(MeshKit.sphere(0.5, 8, 4), Color("ffb3ec"), MeshKit.xf(Vector3(0, 0, 0.5), Vector3.ZERO, Vector3(0.45, 0.12, 1.0)))
					bits.append(MeshKit.inst(self, pm.commit(MeshKit.mat_glow_vc())))
				var core := MeshKit.inst(self, MeshKit.sphere(0.2, 8, 5), MeshKit.xf(Vector3(0, 0.25, 0)), MeshKit.mat_glow(Color("fff0a0")))
				bits.append(core)
			"chorus":
				for i in 6:
					var nm := MeshKit.inst(self, ModelLib.projectile("note", a.team))
					bits.append(nm)
			"wall":
				var rb := MeshKit.Builder.new(400)
				rb.jitter = 0.08
				for p in a.wall_points:
					var lp := (p - a.position) * MeshKit.S
					rb.add(MeshKit.sphere(0.36, 6, 4, 0.75), Color("8d7a60"), MeshKit.xf(Vector3(lp.x, 0.2, lp.y)), 0.06)
					rb.add(MeshKit.cone(0.16, 0.45, 5), Color("a39070"), MeshKit.xf(Vector3(lp.x + 0.08, 0.5, lp.y - 0.05), Vector3(8, 0, -6)))
				var wm := MeshKit.inst(self, rb.commit())
				bits.append(wm)
				wm.position.y = -0.8

	func sync(delta: float) -> bool:
		t += delta
		if fade_t >= 0.0 or not is_instance_valid(area) or area.done:
			if fade_t < 0.0:
				fade_t = 0.0
			fade_t += delta
			var k := 1.0 - fade_t / 0.3
			if kind == "wall" and bits.size() > 0:
				bits[0].position.y = -0.8 * (1.0 - k)
			if disc != null:
				disc.scale = Vector3(r, 1, r) * (1.0 + (1.0 - k) * 0.15)
				MeshKit.decal_set(disc, "fill", 0.16 * k)
			if kind == "bloom" or kind == "snare":
				for b in bits:
					b.scale = Vector3.ONE * maxf(0.0, k)
			return fade_t < 0.3
		if area.follow != null and is_instance_valid(area.follow):
			position = MeshKit.v3(area.position, 0.0)
		var delay := maxf(area.delay, 0.01)
		var k2 := clampf(area.t / delay, 0.0, 1.0)
		match kind:
			"volley":
				var rng := RandomNumberGenerator.new()
				for i in bits.size():
					rng.seed = i * 31 + int((t + i * 0.13) / 0.45) * 7
					var ph := fmod(t + i * 0.13, 0.45) / 0.45
					var p := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r
					bits[i].position = Vector3(p.x, lerpf(2.6, 0.05, ph), p.y)
					bits[i].visible = ph < 0.98
			"glow":
				for i in bits.size():
					var ph2 := fmod(t * 0.7 + i * 0.2, 1.0)
					var a := i * 2.4 + t
					bits[i].position = Vector3(cos(a) * r * 0.6, ph2 * 0.9, sin(a) * r * 0.6)
					bits[i].scale = Vector3.ONE * (1.0 - ph2)
			"snare":
				if not area.triggered:
					inner.scale = Vector3(r * k2, 1, r * k2)
					for i in bits.size():
						var a2 := i * TAU / bits.size() + t * 2.0
						bits[i].position = Vector3(cos(a2) * r * 0.45, 0.25 + 0.05 * sin(t * 6.0 + i), sin(a2) * r * 0.45)
						bits[i].scale = Vector3.ONE * 0.1
				else:
					if not flashed:
						flashed = true
						view.burst(global_position, Color("ffe066"), 18, r)
						view.ring_fx(area.position, area.radius * 0.6, area.radius * 1.1, Color(1, 0.95, 0.5), 0.35)
					inner.visible = false
					for i in bits.size():
						var a3 := i * TAU / bits.size()
						bits[i].position = Vector3(cos(a3) * r * 0.5, 0.15, sin(a3) * r * 0.5)
						bits[i].scale = Vector3(0.12, 0.6, 0.12)
			"bloom":
				if not area.triggered:
					for i in 6:
						var a4 := i * TAU / 6.0 + t * 0.8
						bits[i].position = Vector3(0, 0.12, 0)
						bits[i].rotation = Vector3(-0.5 * k2, -a4 + PI * 0.5, 0)
						bits[i].scale = Vector3.ONE * (r * 0.75 * k2 + 0.05)
					bits[6].scale = Vector3.ONE * (0.6 + 0.4 * sin(t * 10.0)) * (0.5 + k2)
				else:
					if not flashed:
						flashed = true
						view.burst(global_position + Vector3(0, 0.3, 0), Color("ffb3ec"), 30, r)
						view.ring_fx(area.position, area.radius * 0.3, area.radius * 1.15, Color(1, 0.7, 0.95), 0.45, 0.18)
			"chorus":
				for i in bits.size():
					var ph3 := fmod(t * 0.6 + i / 6.0, 1.0)
					var a5 := i * TAU / 6.0 + t * 0.7
					bits[i].position = Vector3(cos(a5) * r * 0.7, 0.3 + ph3 * 1.2, sin(a5) * r * 0.7)
					bits[i].scale = Vector3.ONE * 1.4 * (1.0 - ph3 * 0.6)
				if disc != null:
					MeshKit.decal_set(disc, "fill", 0.12 + 0.06 * sin(t * 6.0))
			"wall":
				bits[0].position.y = lerpf(bits[0].position.y, 0.0, 1.0 - exp(-14.0 * delta))
		return true


# ------------------------------------------------------------------ one-shot effects
class OneShot extends Node3D:
	var life := 0.35
	var t := 0.0
	var kind := "ring"
	var mi: MeshInstance3D
	var r0 := 0.0
	var r1 := 1.0
	var col := Color.WHITE
	var width := 0.08

	func sync(delta: float) -> bool:
		t += delta
		var k := clampf(t / life, 0.0, 1.0)
		match kind:
			"ring":
				var r := lerpf(r0, r1, k)
				mi.scale = Vector3(r, 1, r)
				FxVisuals.decal_ring_width(mi, r, width)
				MeshKit.decal_set(mi, "color", Color(col, (1.0 - k) * 0.9))
			"slash":
				MeshKit.decal_set(mi, "color", Color(col, (1.0 - k) * 0.85))
				mi.scale = Vector3.ONE * r1 * (0.8 + 0.3 * k)
			"beam":
				var m := mi.material_override as StandardMaterial3D
				m.albedo_color = Color(col, (1.0 - k) * 0.85)
				mi.scale.x = 1.0 - k * 0.6
				mi.scale.y = 1.0 - k * 0.6
			"burst":
				pass
		return t < life
