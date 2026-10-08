class_name ModelLib
extends RefCounted
## Every non-hero 3D model (trees, rocks, towers, Heartspire, creeps, jungle monster, projectiles),
## built from primitives at runtime and cached. Sizes are in metres (1 m = 100 world pixels).
## Change colours/proportions here.

const STONE := Color("8e95a6")
const STONE_DARK := Color("5d6373")
const STONE_LIGHT := Color("b7bdcb")
const WOOD := Color("7a5232")
const LEAF := Color("3f8f3f")
const LEAF_DARK := Color("2f6f34")
const GOLD := Color("ffcf4a")

static var _cache := {}


static func _cached(key: String, f: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = f.call()
	return _cache[key]


## Pine tree, 1 m tall-ish (scaled per instance). Three stacked cones like the art-style draft.
static func tree() -> Mesh:
	return _cached("tree", func() -> Mesh:
		var b := MeshKit.Builder.new(3)
		b.jitter = 0.06
		b.add(MeshKit.cyl(0.08, 0.11, 0.34, 6), WOOD, MeshKit.xf(Vector3(0, 0.17, 0)))
		b.add(MeshKit.cone(0.62, 0.62, 7), LEAF_DARK, MeshKit.xf(Vector3(0, 0.6, 0)))
		b.add(MeshKit.cone(0.48, 0.56, 7), LEAF, MeshKit.xf(Vector3(0, 0.95, 0), Vector3(0, 25, 0)))
		b.add(MeshKit.cone(0.3, 0.48, 7), LEAF.lightened(0.12), MeshKit.xf(Vector3(0, 1.28, 0), Vector3(0, 50, 0)))
		return b.commit())


## Round broadleaf tree for variety.
static func bush_tree() -> Mesh:
	return _cached("bush_tree", func() -> Mesh:
		var b := MeshKit.Builder.new(5)
		b.jitter = 0.07
		b.add(MeshKit.cyl(0.07, 0.1, 0.45, 6), WOOD, MeshKit.xf(Vector3(0, 0.22, 0)))
		b.add(MeshKit.sphere(0.45, 7, 4), Color("4d9a3e"), MeshKit.xf(Vector3(0, 0.78, 0)), 0.06)
		b.add(MeshKit.sphere(0.3, 6, 4), Color("5aab48"), MeshKit.xf(Vector3(0.18, 1.0, 0.1)), 0.05)
		return b.commit())


static func rock() -> Mesh:
	return _cached("rock", func() -> Mesh:
		var b := MeshKit.Builder.new(11)
		b.jitter = 0.08
		b.add(MeshKit.sphere(0.5, 6, 4, 0.7), Color("8d8b86"), MeshKit.xf(Vector3(0, 0.2, 0)), 0.1)
		return b.commit())


## Small grass tuft / flower patch for ground decoration.
static func tuft() -> Mesh:
	return _cached("tuft", func() -> Mesh:
		var b := MeshKit.Builder.new(13)
		b.jitter = 0.1
		for i in 4:
			var a := i * 90.0 + 20.0
			b.add(MeshKit.cone(0.05, 0.22, 3), Color("6fbf4a"), MeshKit.xf(Vector3(cos(deg_to_rad(a)) * 0.06, 0.1, sin(deg_to_rad(a)) * 0.06), Vector3(10 * cos(a), a, 10 * sin(a))))
		return b.commit())


static func flower() -> Mesh:
	return _cached("flower", func() -> Mesh:
		var b := MeshKit.Builder.new(17)
		b.add(MeshKit.cyl(0.01, 0.01, 0.16, 3), Color("4f9a3a"), MeshKit.xf(Vector3(0, 0.08, 0)))
		b.octa(Vector3(0, 0.18, 0), 0.05, 0.03, 0.03, Color.WHITE)
		return b.commit())


# ---------------- buildings ----------------

## Tower body without the crystal (crystal is separate so it can spin and glow).
static func tower_body(team: int) -> Mesh:
	return _cached("tower%d" % team, func() -> Mesh:
		var tc := Art.team_color(team)
		var b := MeshKit.Builder.new(21 + team)
		b.add(MeshKit.cyl(0.62, 0.7, 0.22, 8), STONE_DARK, MeshKit.xf(Vector3(0, 0.11, 0)))
		b.add(MeshKit.cyl(0.42, 0.5, 0.3, 8), STONE, MeshKit.xf(Vector3(0, 0.37, 0)))
		b.add(MeshKit.cyl(0.3, 0.4, 1.35, 8), STONE_LIGHT, MeshKit.xf(Vector3(0, 1.2, 0)))
		b.add(MeshKit.cyl(0.41, 0.41, 0.12, 8), tc, MeshKit.xf(Vector3(0, 0.95, 0)))
		b.add(MeshKit.cyl(0.46, 0.34, 0.22, 8), STONE, MeshKit.xf(Vector3(0, 1.98, 0)))
		for i in 4:
			var a := deg_to_rad(45.0 + i * 90.0)
			b.add(MeshKit.box(0.14, 0.2, 0.14), STONE_LIGHT, MeshKit.xf(Vector3(cos(a) * 0.36, 2.18, sin(a) * 0.36), Vector3(0, -rad_to_deg(a), 0)))
			b.add(MeshKit.prism(0.16, 0.34, 0.03), tc, MeshKit.xf(Vector3(cos(a) * 0.46, 1.55, sin(a) * 0.46), Vector3(180, -rad_to_deg(a) + 90.0, 0)))
		return b.commit())


static func tower_rubble(team: int) -> Mesh:
	return _cached("rubble%d" % team, func() -> Mesh:
		var b := MeshKit.Builder.new(31 + team)
		b.add(MeshKit.cyl(0.62, 0.7, 0.22, 8), STONE_DARK, MeshKit.xf(Vector3(0, 0.11, 0)))
		b.add(MeshKit.cyl(0.34, 0.45, 0.42, 8), STONE, MeshKit.xf(Vector3(0, 0.4, 0)), 0.04)
		for i in 7:
			var a := i * 0.9
			b.add(MeshKit.box(0.22, 0.14, 0.18), STONE_LIGHT if i % 2 == 0 else STONE, MeshKit.xf(Vector3(cos(a) * 0.65, 0.07, sin(a) * 0.6), Vector3(i * 13, i * 40, i * 7)))
		return b.commit())


static func heartspire_body(team: int) -> Mesh:
	return _cached("heart%d" % team, func() -> Mesh:
		var tc := Art.team_color(team)
		var b := MeshKit.Builder.new(41 + team)
		b.add(MeshKit.cyl(1.0, 1.1, 0.25, 6), STONE_DARK, MeshKit.xf(Vector3(0, 0.12, 0)))
		b.add(MeshKit.cyl(0.78, 0.9, 0.3, 6), STONE, MeshKit.xf(Vector3(0, 0.4, 0), Vector3(0, 30, 0)))
		b.add(MeshKit.cyl(0.55, 0.65, 0.3, 6), STONE_LIGHT, MeshKit.xf(Vector3(0, 0.7, 0)))
		b.add(MeshKit.cyl(0.66, 0.66, 0.08, 6), tc, MeshKit.xf(Vector3(0, 0.56, 0), Vector3(0, 30, 0)))
		for i in 6:
			var a := deg_to_rad(i * 60.0)
			b.add(MeshKit.cyl(0.05, 0.09, 1.4, 5), STONE_LIGHT, MeshKit.xf(Vector3(cos(a) * 0.72, 1.1, sin(a) * 0.72), Vector3(cos(a) * -12.0, 0, sin(a) * 12.0)))
			b.octa(Vector3(cos(a) * 0.72, 1.85, sin(a) * 0.72), 0.07, 0.14, 0.08, tc.lightened(0.3))
		return b.commit())


static func heartspire_rubble(team: int) -> Mesh:
	return _cached("heart_rubble%d" % team, func() -> Mesh:
		var tc := Art.team_color(team).darkened(0.45)
		var b := MeshKit.Builder.new(51 + team)
		b.add(MeshKit.cyl(1.0, 1.1, 0.25, 6), STONE_DARK, MeshKit.xf(Vector3(0, 0.12, 0)))
		b.add(MeshKit.cyl(0.6, 0.85, 0.35, 6), STONE, MeshKit.xf(Vector3(0, 0.42, 0)), 0.05)
		for i in 9:
			var a := i * 0.7
			b.octa(Vector3(cos(a) * (0.5 + 0.08 * (i % 3)), 0.55, sin(a) * 0.55), 0.12, 0.25, 0.08, tc)
		return b.commit())


## Big crystal (tower top / Heartspire core). Unit size, scaled by the visual.
static func crystal() -> Mesh:
	return _cached("crystal", func() -> Mesh:
		var b := MeshKit.Builder.new(61)
		b.jitter = 0.0
		b.octa(Vector3.ZERO, 0.5, 1.0, 0.7, Color.WHITE)
		return b.commit())


# ---------------- creeps & monsters ----------------

## Crystal creep: melee (sword), ranged (floating, orb) or siege (cart with cannon).
static func creep(kind: String, team: int) -> Mesh:
	return _cached("creep_%s_%d" % [kind, team], func() -> Mesh:
		var tc := Art.team_color(team)
		var dk := Art.team_dark(team)
		var b := MeshKit.Builder.new(71 + team)
		match kind:
			"melee":
				b.add(MeshKit.box(0.07, 0.12, 0.08), dk, MeshKit.xf(Vector3(-0.07, 0.06, 0)))
				b.add(MeshKit.box(0.07, 0.12, 0.08), dk, MeshKit.xf(Vector3(0.07, 0.06, 0)))
				b.octa(Vector3(0, 0.3, 0), 0.17, 0.24, 0.18, tc)
				b.add(MeshKit.box(0.045, 0.045, 0.02), Color.WHITE, MeshKit.xf(Vector3(-0.055, 0.33, 0.125)))
				b.add(MeshKit.box(0.045, 0.045, 0.02), Color.WHITE, MeshKit.xf(Vector3(0.055, 0.33, 0.125)))
				b.add(MeshKit.box(0.03, 0.26, 0.05), Color("e6e9f0"), MeshKit.xf(Vector3(0.2, 0.33, 0.08), Vector3(25, 0, 0)))
				b.add(MeshKit.box(0.1, 0.03, 0.05), GOLD, MeshKit.xf(Vector3(0.2, 0.22, 0.04), Vector3(25, 0, 0)))
			"ranged":
				b.octa(Vector3(0, 0.42, 0), 0.13, 0.2, 0.22, tc)
				b.add(MeshKit.box(0.04, 0.04, 0.02), Color.WHITE, MeshKit.xf(Vector3(-0.045, 0.45, 0.095)))
				b.add(MeshKit.box(0.04, 0.04, 0.02), Color.WHITE, MeshKit.xf(Vector3(0.045, 0.45, 0.095)))
				b.octa(Vector3(0.18, 0.6, 0.05), 0.05, 0.07, 0.07, tc.lightened(0.5))
				b.octa(Vector3(-0.18, 0.6, 0.05), 0.05, 0.07, 0.07, tc.lightened(0.5))
			_:
				b.add(MeshKit.box(0.42, 0.18, 0.56), dk, MeshKit.xf(Vector3(0, 0.22, 0)))
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						b.add(MeshKit.cyl(0.11, 0.11, 0.06, 8), Color("3b3a3f"), MeshKit.xf(Vector3(sx * 0.24, 0.11, sz * 0.18), Vector3(0, 0, 90)))
				b.add(MeshKit.cyl(0.07, 0.09, 0.42, 8), STONE_DARK, MeshKit.xf(Vector3(0, 0.38, 0.22), Vector3(80, 0, 0)))
				b.octa(Vector3(0, 0.48, -0.08), 0.13, 0.22, 0.1, tc)
		return b.commit())


## Thornling: mossy jungle monster.
static func thornling() -> Mesh:
	return _cached("thornling", func() -> Mesh:
		var b := MeshKit.Builder.new(81)
		b.add(MeshKit.sphere(0.24, 7, 5, 0.38), Color("5e9e3c"), MeshKit.xf(Vector3(0, 0.22, 0)), 0.03)
		for i in 7:
			var a := deg_to_rad(i * 51.0)
			b.add(MeshKit.cone(0.05, 0.16, 4), Color("2f6a2a"), MeshKit.xf(Vector3(cos(a) * 0.17, 0.33, sin(a) * 0.17), Vector3(sin(a) * 50.0, 0, -cos(a) * 50.0)))
		b.add(MeshKit.box(0.06, 0.05, 0.02), Color("ffe066"), MeshKit.xf(Vector3(-0.07, 0.27, 0.22)))
		b.add(MeshKit.box(0.06, 0.05, 0.02), Color("ffe066"), MeshKit.xf(Vector3(0.07, 0.27, 0.22)))
		b.add(MeshKit.box(0.08, 0.08, 0.08), Color("4a3a24"), MeshKit.xf(Vector3(-0.1, 0.04, 0)))
		b.add(MeshKit.box(0.08, 0.08, 0.08), Color("4a3a24"), MeshKit.xf(Vector3(0.1, 0.04, 0)))
		return b.commit())


## Brambleback: the big camp monster (bark-brown body, stone horns, glowing eyes).
static func brambleback() -> Mesh:
	return _cached("brambleback", func() -> Mesh:
		var b := MeshKit.Builder.new(83)
		b.add(MeshKit.sphere(0.26, 8, 5, 0.42), Color("7a5232"), MeshKit.xf(Vector3(0, 0.24, 0), Vector3.ZERO, Vector3(1.1, 0.9, 1.0)), 0.03)
		b.add(MeshKit.sphere(0.2, 7, 4, 0.4), Color("4f8a34"), MeshKit.xf(Vector3(0, 0.36, -0.06), Vector3.ZERO, Vector3(1.0, 0.6, 1.0)), 0.03)
		for i in 9:
			var a := deg_to_rad(i * 40.0)
			b.add(MeshKit.cone(0.05, 0.18, 4), Color("2f6a2a"), MeshKit.xf(Vector3(cos(a) * 0.18, 0.4, sin(a) * 0.18 - 0.05), Vector3(sin(a) * 50.0, 0, -cos(a) * 50.0)))
		b.add(MeshKit.cone(0.05, 0.2, 5), Color("d9d2bf"), MeshKit.xf(Vector3(-0.13, 0.42, 0.16), Vector3(30, 0, 35)))
		b.add(MeshKit.cone(0.05, 0.2, 5), Color("d9d2bf"), MeshKit.xf(Vector3(0.13, 0.42, 0.16), Vector3(30, 0, -35)))
		b.add(MeshKit.box(0.07, 0.05, 0.02), Color("ff8a3a"), MeshKit.xf(Vector3(-0.08, 0.3, 0.25)))
		b.add(MeshKit.box(0.07, 0.05, 0.02), Color("ff8a3a"), MeshKit.xf(Vector3(0.08, 0.3, 0.25)))
		for x in [-0.14, 0.14]:
			for z in [-0.1, 0.1]:
				b.add(MeshKit.box(0.09, 0.1, 0.09), Color("3d2e1c"), MeshKit.xf(Vector3(x, 0.05, z)))
		return b.commit())


# ---------------- projectiles ----------------

## Projectile mesh pointing along +Z.
static func projectile(style: String, team: int) -> Mesh:
	return _cached("proj_%s_%d" % [style, team], func() -> Mesh:
		var b := MeshKit.Builder.new(91)
		b.jitter = 0.0
		var tc := Art.team_color(team)
		match style:
			"arrow":
				b.add(MeshKit.box(0.025, 0.025, 0.42), Color("8a5a2b"), MeshKit.xf(Vector3(0, 0, -0.05)))
				b.add(MeshKit.cone(0.045, 0.1, 4), Color("e8e8f0"), MeshKit.xf(Vector3(0, 0, 0.2), Vector3(90, 0, 0)))
				b.add(MeshKit.box(0.08, 0.005, 0.08), Color("ff6f5e"), MeshKit.xf(Vector3(0, 0, -0.24)))
			"bolt":
				b.octa(Vector3.ZERO, 0.09, 0.09, 0.09, Color("fff2c0"), 0.42)
			"siege":
				b.add(MeshKit.sphere(0.1, 6, 4), Color("2c2c33"))
			"note":
				b.add(MeshKit.sphere(0.07, 6, 4), Color("ffb3e0"), MeshKit.xf(Vector3(0, 0, 0), Vector3.ZERO, Vector3(1.3, 1, 1)))
				b.add(MeshKit.box(0.025, 0.22, 0.025), Color("ffe0f2"), MeshKit.xf(Vector3(0.07, 0.11, 0)))
				b.add(MeshKit.box(0.1, 0.03, 0.025), Color("ffe0f2"), MeshKit.xf(Vector3(0.11, 0.21, 0), Vector3(0, 0, -20)))
			"petal":
				b.octa(Vector3.ZERO, 0.08, 0.04, 0.04, Color("ff9ad4"), 0.13)
			"wisp":
				b.add(MeshKit.sphere(0.13, 7, 5), Color("bff6ff"))
			"orb":
				b.add(MeshKit.sphere(0.09, 6, 4), Color("d9c8ff"))
			"tower":
				b.octa(Vector3.ZERO, 0.11, 0.15, 0.15, tc.lightened(0.45))
			"fountain":
				b.add(MeshKit.sphere(0.2, 8, 6), tc.lightened(0.6))
				b.add(MeshKit.sphere(0.12, 6, 4), Color.WHITE)
				b.octa(Vector3.ZERO, 0.08, 0.34, 0.08, Color.WHITE)
			_:
				b.octa(Vector3.ZERO, 0.06, 0.08, 0.08, tc.lightened(0.4))
		return b.commit(MeshKit.mat_glow_vc() if style in ["bolt", "wisp", "orb", "tower", "note", "petal", "fountain"] else null))
