class_name HeroModel
extends Node3D
## Low-poly chibi hero built from primitives: big head, small body, stubby limbs.
## The outfit uses the TEAM colour (Dawn blue / Dusk red); hair, hats and weapons use the hero's own
## colours from HeroData (body_color / accent_color / detail_color).
## Animations are procedural: idle bob, walk cycle, attack swing, cast, leap and death.

const SKIN := Color("ffd9bd")

var id: StringName
var team := 0
var data: HeroData
var hip: Node3D
var body: MeshInstance3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var glow_parts: Array[MeshInstance3D] = []
var meshes: Array[MeshInstance3D] = []

# animation state
var walk := 0.0
var phase := 0.0
var t := 0.0
var atk_t := 0.0
var cast_t := 0.0
var hurt_t := 0.0
var dead_t := -1.0
var lift := 0.0
## Ranged heroes pull a bow / thrust a staff instead of swinging.
var attack_style := "swing"


func build(d: HeroData, team_id: int) -> HeroModel:
	data = d
	id = d.id
	team = team_id
	var tc := Art.team_color(team_id)
	var dk := Art.team_dark(team_id)
	var hair := d.body_color
	var acc := d.accent_color
	var det := d.detail_color
	var robe := id == &"lumi" or id == &"calla"
	attack_style = "bow" if id in [&"kestrel", &"nova"] else ("staff" if id in [&"lumi", &"calla"] else "swing")
	hip = Node3D.new()
	hip.position = Vector3(0, 0.2, 0)
	add_child(hip)
	# ---------- legs ----------
	leg_l = _pivot(self, Vector3(-0.075, 0.2, 0))
	leg_r = _pivot(self, Vector3(0.075, 0.2, 0))
	for leg in [leg_l, leg_r]:
		var lb := MeshKit.Builder.new(3)
		lb.add(MeshKit.box(0.09, 0.17, 0.1), dk, MeshKit.xf(Vector3(0, -0.1, 0)))
		lb.add(MeshKit.box(0.1, 0.05, 0.13), Color("3a2c22"), MeshKit.xf(Vector3(0, -0.18, 0.015)))
		_mesh(leg, lb)
	# ---------- body ----------
	var bb := MeshKit.Builder.new(5)
	if robe:
		bb.add(MeshKit.cyl(0.12, 0.23, 0.38, 8), tc, MeshKit.xf(Vector3(0, 0.05, 0)))
		bb.add(MeshKit.cyl(0.235, 0.235, 0.04, 8), acc if id == &"calla" else det, MeshKit.xf(Vector3(0, -0.13, 0)))
	else:
		bb.add(MeshKit.cyl(0.13, 0.165, 0.3, 8), tc, MeshKit.xf(Vector3(0, 0.1, 0)))
		bb.add(MeshKit.cyl(0.17, 0.17, 0.045, 8), Color("4a3424"), MeshKit.xf(Vector3(0, -0.02, 0)))
		bb.add(MeshKit.box(0.05, 0.04, 0.02), Art.GOLD, MeshKit.xf(Vector3(0, -0.02, 0.17)))
	match id:
		&"kestrel":
			bb.add(MeshKit.cyl(0.15, 0.17, 0.07, 8), acc, MeshKit.xf(Vector3(0, 0.25, 0)))
			bb.add(MeshKit.box(0.07, 0.2, 0.03), acc, MeshKit.xf(Vector3(0.06, 0.13, -0.16), Vector3(-10, 0, 8)))
			bb.add(MeshKit.cyl(0.05, 0.05, 0.3, 6), Color("7a4a24"), MeshKit.xf(Vector3(-0.06, 0.2, -0.16), Vector3(-15, 0, 25)))
			for k in 3:
				bb.add(MeshKit.box(0.02, 0.06, 0.02), Color("f0e8d0"), MeshKit.xf(Vector3(-0.13 + k * 0.025, 0.37 + k * 0.01, -0.18), Vector3(-15, 0, 25)))
		&"morrow":
			bb.add(MeshKit.sphere(0.26, 8, 5), Color("6d5a37"), MeshKit.xf(Vector3(0, 0.15, -0.14), Vector3.ZERO, Vector3(1.0, 1.05, 0.62)))
			for k in 5:
				var a := deg_to_rad(-60.0 + k * 30.0)
				bb.add(MeshKit.cyl(0.07, 0.07, 0.03, 6), Color("8a7347"), MeshKit.xf(Vector3(sin(a) * 0.17, 0.15 + (k % 2) * 0.08, -0.27 - cos(a) * 0.03), Vector3(90 - k * 3, rad_to_deg(a), 0)))
			bb.add(MeshKit.sphere(0.06, 6, 4), Color("4f8f3a"), MeshKit.xf(Vector3(0.1, 0.33, -0.2)))
		&"sable":
			bb.add(MeshKit.cyl(0.145, 0.17, 0.08, 8), acc, MeshKit.xf(Vector3(0, 0.26, 0)))
			bb.add(MeshKit.box(0.08, 0.2, 0.03), acc, MeshKit.xf(Vector3(-0.07, 0.15, -0.16), Vector3(-15, 0, -10)))
			bb.add(MeshKit.sphere(0.09, 6, 4), hair, MeshKit.xf(Vector3(0, 0.0, -0.3), Vector3(-35, 0, 0), Vector3(1, 1, 2.6)))
			bb.add(MeshKit.sphere(0.06, 6, 4), det, MeshKit.xf(Vector3(0, 0.12, -0.5)))
		&"calla":
			for k in 8:
				var a2 := deg_to_rad(k * 45.0)
				bb.add(MeshKit.sphere(0.06, 5, 3), acc.lightened(0.15 * (k % 2)), MeshKit.xf(Vector3(cos(a2) * 0.22, -0.15, sin(a2) * 0.22), Vector3.ZERO, Vector3(1.2, 0.5, 1.2)))
			bb.add(MeshKit.sphere(0.05, 5, 3), hair, MeshKit.xf(Vector3(0, 0.2, 0.12)))
		&"rook":
			bb.add(MeshKit.box(0.24, 0.2, 0.06), ModelLib.STONE_LIGHT, MeshKit.xf(Vector3(0, 0.13, 0.14)))
			bb.add(MeshKit.box(0.06, 0.06, 0.02), acc, MeshKit.xf(Vector3(0, 0.15, 0.175)))
			bb.add(MeshKit.box(0.26, 0.28, 0.03), acc.darkened(0.2), MeshKit.xf(Vector3(0, 0.1, -0.16), Vector3(-8, 0, 0)))
		&"lumi":
			bb.add(MeshKit.cyl(0.13, 0.13, 0.05, 8), det, MeshKit.xf(Vector3(0, 0.22, 0)))
		&"brakka":
			# sailor collar + rope belt + life-ring on the back
			bb.add(MeshKit.box(0.3, 0.04, 0.18), acc, MeshKit.xf(Vector3(0, 0.25, -0.03)))
			bb.add(MeshKit.box(0.04, 0.1, 0.02), det, MeshKit.xf(Vector3(0, 0.2, 0.16)))
			bb.add(MeshKit.cyl(0.17, 0.17, 0.035, 8), Color("e8d9a8"), MeshKit.xf(Vector3(0, -0.02, 0)))
			bb.add(MeshKit.cyl(0.15, 0.15, 0.06, 10), Color("f05a3c"), MeshKit.xf(Vector3(0, 0.12, -0.18), Vector3(90, 0, 0)))
			bb.add(MeshKit.cyl(0.08, 0.08, 0.065, 10), acc, MeshKit.xf(Vector3(0, 0.12, -0.185), Vector3(90, 0, 0)))
		&"nova":
			# long coat tails + star brooch + shoulder cape
			bb.add(MeshKit.box(0.26, 0.2, 0.03), acc, MeshKit.xf(Vector3(0, -0.08, -0.15), Vector3(12, 0, 0)))
			bb.add(MeshKit.cyl(0.15, 0.18, 0.07, 8), acc, MeshKit.xf(Vector3(0, 0.25, 0)))
			bb.octa(Vector3(0.07, 0.16, 0.16), 0.035, 0.04, 0.02, det)
	body = _mesh(hip, bb)
	# ---------- head ----------
	head = _pivot(hip, Vector3(0, 0.47, 0))
	var hb := MeshKit.Builder.new(9)
	var skin := Color("6fb04f") if id == &"morrow" else SKIN
	hb.add(MeshKit.sphere(0.21, 9, 6), skin)
	for sx in [-1.0, 1.0]:
		hb.add(MeshKit.box(0.04, 0.065, 0.02), Color("1d1a24"), MeshKit.xf(Vector3(sx * 0.075, -0.01, 0.198)))
		hb.add(MeshKit.box(0.015, 0.02, 0.01), Color.WHITE, MeshKit.xf(Vector3(sx * 0.075 + 0.008, 0.01, 0.209)))
	match id:
		&"kestrel":
			hb.add(MeshKit.sphere(0.225, 9, 6), hair, MeshKit.xf(Vector3(0, 0.05, -0.04), Vector3(-10, 0, 0), Vector3(1.0, 0.92, 1.0)))
			hb.add(MeshKit.box(0.34, 0.035, 0.03), Color("4a3020"), MeshKit.xf(Vector3(0, 0.1, 0.18)))
			for sx2 in [-1.0, 1.0]:
				hb.add(MeshKit.cyl(0.055, 0.055, 0.05, 8), acc, MeshKit.xf(Vector3(sx2 * 0.075, 0.11, 0.19), Vector3(90, 0, 0)))
				hb.add(MeshKit.cyl(0.038, 0.038, 0.055, 8), det, MeshKit.xf(Vector3(sx2 * 0.075, 0.11, 0.195), Vector3(90, 0, 0)))
		&"morrow":
			hb.add(MeshKit.sphere(0.235, 9, 5, 0.3), acc, MeshKit.xf(Vector3(0, 0.1, -0.02)))
			hb.add(MeshKit.box(0.04, 0.12, 0.04), acc.darkened(0.2), MeshKit.xf(Vector3(0, 0.25, 0.0)))
			hb.add(MeshKit.box(0.1, 0.02, 0.02), Color("2f5f22"), MeshKit.xf(Vector3(0, -0.09, 0.195)))
		&"lumi":
			hb.add(MeshKit.sphere(0.235, 9, 6), acc, MeshKit.xf(Vector3(0, 0.0, -0.05), Vector3.ZERO, Vector3(1.0, 1.0, 1.0)))
			hb.add(MeshKit.cyl(0.32, 0.32, 0.03, 10), Color("3a2a8f"), MeshKit.xf(Vector3(0, 0.15, 0)))
			hb.add(MeshKit.cone(0.18, 0.46, 8), Color("3a2a8f"), MeshKit.xf(Vector3(0, 0.38, -0.03), Vector3(-14, 0, 0)))
			hb.octa(Vector3(0, 0.3, 0.13), 0.05, 0.06, 0.06, det)
		&"sable":
			hb.add(MeshKit.sphere(0.235, 9, 6), hair, MeshKit.xf(Vector3(0, 0.03, -0.05)))
			hb.add(MeshKit.sphere(0.16, 8, 5), det, MeshKit.xf(Vector3(0, -0.03, 0.12), Vector3.ZERO, Vector3(1.05, 0.85, 0.55)))
			for sx3 in [-1.0, 1.0]:
				hb.add(MeshKit.cone(0.075, 0.18, 4), hair, MeshKit.xf(Vector3(sx3 * 0.12, 0.23, -0.02), Vector3(0, 45, sx3 * -15.0)))
				hb.add(MeshKit.cone(0.04, 0.11, 4), acc, MeshKit.xf(Vector3(sx3 * 0.12, 0.22, 0.02), Vector3(0, 45, sx3 * -15.0)))
				hb.add(MeshKit.box(0.07, 0.018, 0.01), acc, MeshKit.xf(Vector3(sx3 * 0.08, 0.04, 0.205), Vector3(0, 0, sx3 * 15.0)))
		&"calla":
			hb.add(MeshKit.sphere(0.23, 9, 6), hair, MeshKit.xf(Vector3(0, 0.02, -0.05)))
			hb.add(MeshKit.sphere(0.07, 6, 4), hair, MeshKit.xf(Vector3(-0.17, -0.12, -0.08)))
			hb.add(MeshKit.sphere(0.07, 6, 4), hair, MeshKit.xf(Vector3(0.17, -0.12, -0.08)))
			for k in 6:
				var a3 := deg_to_rad(k * 60.0)
				hb.add(MeshKit.sphere(0.065, 5, 3), acc, MeshKit.xf(Vector3(cos(a3) * 0.13, 0.2, sin(a3) * 0.13 - 0.02), Vector3(0, -rad_to_deg(a3), 25), Vector3(1.4, 0.45, 0.9)))
			hb.add(MeshKit.sphere(0.05, 6, 4), det, MeshKit.xf(Vector3(0, 0.22, -0.02)))
		&"rook":
			hb.add(MeshKit.cyl(0.215, 0.225, 0.3, 8), ModelLib.STONE_LIGHT, MeshKit.xf(Vector3(0, 0.03, 0)))
			hb.add(MeshKit.sphere(0.215, 8, 4, 0.2), ModelLib.STONE_LIGHT, MeshKit.xf(Vector3(0, 0.18, 0)))
			hb.add(MeshKit.box(0.3, 0.045, 0.04), Color("1d1a24"), MeshKit.xf(Vector3(0, 0.0, 0.205)))
			hb.add(MeshKit.box(0.05, 0.02, 0.01), det, MeshKit.xf(Vector3(-0.07, 0.0, 0.228)))
			hb.add(MeshKit.box(0.05, 0.02, 0.01), det, MeshKit.xf(Vector3(0.07, 0.0, 0.228)))
			hb.add(MeshKit.sphere(0.07, 6, 4), acc, MeshKit.xf(Vector3(0, 0.27, -0.04), Vector3.ZERO, Vector3(0.6, 1.0, 3.2)))
	match id:
		&"brakka":
			# teal shaggy hair, sailor cap, beard stubble
			hb.add(MeshKit.sphere(0.225, 9, 6), hair, MeshKit.xf(Vector3(0, 0.03, -0.05)))
			hb.add(MeshKit.cyl(0.2, 0.22, 0.09, 10), Color("f4f1e8"), MeshKit.xf(Vector3(0, 0.19, 0)))
			hb.add(MeshKit.cyl(0.23, 0.23, 0.025, 10), acc, MeshKit.xf(Vector3(0, 0.15, 0)))
			hb.add(MeshKit.box(0.16, 0.02, 0.09), acc, MeshKit.xf(Vector3(0, 0.15, 0.2)))
			hb.add(MeshKit.box(0.2, 0.06, 0.04), hair.darkened(0.25), MeshKit.xf(Vector3(0, -0.12, 0.17)))
			hb.add(MeshKit.box(0.08, 0.025, 0.01), Color("1d1a24"), MeshKit.xf(Vector3(-0.075, 0.05, 0.205), Vector3(0, 0, -10)))
		&"nova":
			# silver bob hair, tricorn-ish hat with star, monocle scope
			hb.add(MeshKit.sphere(0.23, 9, 6), hair, MeshKit.xf(Vector3(0, 0.02, -0.04), Vector3.ZERO, Vector3(1.05, 1.0, 1.0)))
			hb.add(MeshKit.cyl(0.3, 0.3, 0.03, 10), acc.darkened(0.2), MeshKit.xf(Vector3(0, 0.17, 0)))
			hb.add(MeshKit.cyl(0.15, 0.19, 0.14, 8), acc.darkened(0.2), MeshKit.xf(Vector3(0, 0.25, -0.01)))
			hb.octa(Vector3(0, 0.27, 0.17), 0.04, 0.05, 0.02, det)
			hb.add(MeshKit.cyl(0.05, 0.05, 0.04, 8), det, MeshKit.xf(Vector3(0.075, -0.01, 0.2), Vector3(90, 0, 0)))
			hb.add(MeshKit.cyl(0.034, 0.034, 0.045, 8), Color("8fd0ff"), MeshKit.xf(Vector3(0.075, -0.01, 0.205), Vector3(90, 0, 0)))
	_mesh(head, hb)
	# ---------- arms ----------
	arm_l = _pivot(hip, Vector3(-0.185, 0.27, 0))
	arm_r = _pivot(hip, Vector3(0.185, 0.27, 0))
	for side in [arm_l, arm_r]:
		var ab := MeshKit.Builder.new(11)
		var right: bool = side == arm_r
		var sleeve := tc
		if id == &"rook":
			ab.add(MeshKit.sphere(0.09, 6, 4), ModelLib.STONE_LIGHT, MeshKit.xf(Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.2, 0.9, 1.2)))
		ab.add(MeshKit.box(0.07, 0.18, 0.075), sleeve, MeshKit.xf(Vector3(0, -0.08, 0)))
		ab.add(MeshKit.sphere(0.045, 6, 4), skin, MeshKit.xf(Vector3(0, -0.19, 0)))
		_weapon(ab, right, acc, det, hair)
		_weapon_v06(ab, right, acc, det)
		_mesh(side, ab)
	if id == &"lumi" or id == &"calla":
		var glow := MeshKit.Builder.new(13)
		glow.jitter = 0.0
		if id == &"lumi":
			glow.octa(Vector3(0, 0.0, 0), 0.06, 0.08, 0.08, Color("8ff4ff"))
		else:
			glow.add(MeshKit.cyl(0.03, 0.07, 0.09, 8), Art.GOLD)
		var gm := MeshKit.inst(arm_r, glow.commit(MeshKit.mat_glow_vc()), MeshKit.xf(Vector3(0, -0.19 + 0.62 if id == &"lumi" else -0.19 + 0.5, 0.05)))
		glow_parts.append(gm)
		meshes.append(gm)
	scale = Vector3.ONE * d.model_scale
	return self


func _weapon(ab: MeshKit.Builder, right: bool, acc: Color, det: Color, hair: Color) -> void:
	var hand := Vector3(0, -0.19, 0)
	match id:
		&"kestrel":
			if not right:
				for k in 5:
					var a := deg_to_rad(-60.0 + k * 30.0)
					ab.add(MeshKit.box(0.03, 0.12, 0.03), Color("6b3b1a"), MeshKit.xf(hand + Vector3(0, sin(a) * 0.24, 0.06 + cos(a) * 0.1), Vector3(-rad_to_deg(a) * 0.6, 0, 0)))
				ab.add(MeshKit.box(0.006, 0.44, 0.006), Color(1, 1, 1, 1), MeshKit.xf(hand + Vector3(0, 0, 0.0)))
		&"morrow":
			if right:
				ab.add(MeshKit.cyl(0.025, 0.03, 0.22, 6), ModelLib.WOOD, MeshKit.xf(hand + Vector3(0, 0, 0.08), Vector3(90, 0, 0)))
				ab.add(MeshKit.sphere(0.075, 6, 4), ModelLib.STONE, MeshKit.xf(hand + Vector3(0, 0, 0.21)), 0.01)
			else:
				ab.add(MeshKit.cyl(0.17, 0.17, 0.04, 8), det, MeshKit.xf(hand + Vector3(-0.04, 0.05, 0.03), Vector3(0, 0, 90)))
				ab.add(MeshKit.box(0.045, 0.02, 0.24), Color("4f8f3a"), MeshKit.xf(hand + Vector3(-0.065, 0.05, 0.03)))
		&"lumi":
			if right:
				ab.add(MeshKit.cyl(0.018, 0.022, 0.78, 6), ModelLib.WOOD, MeshKit.xf(hand + Vector3(0, 0.22, 0.05)))
				ab.add(MeshKit.box(0.1, 0.02, 0.1), Color("c9a24a"), MeshKit.xf(hand + Vector3(0, 0.56, 0.05)))
		&"sable":
			ab.add(MeshKit.box(0.025, 0.035, 0.24), Color("e8ecf4"), MeshKit.xf(hand + Vector3(0, 0, 0.14)))
			ab.add(MeshKit.box(0.08, 0.03, 0.03), acc, MeshKit.xf(hand + Vector3(0, 0, 0.03)))
		&"calla":
			if right:
				ab.add(MeshKit.cyl(0.018, 0.02, 0.66, 6), Color("c9a86a"), MeshKit.xf(hand + Vector3(0, 0.18, 0.05)))
				ab.add(MeshKit.box(0.12, 0.025, 0.025), Color("c9a86a"), MeshKit.xf(hand + Vector3(0.05, 0.5, 0.05), Vector3(0, 0, -25)))
				ab.add(MeshKit.sphere(0.05, 6, 4), acc, MeshKit.xf(hand + Vector3(-0.02, 0.53, 0.05), Vector3.ZERO, Vector3(1.3, 0.6, 1.3)))
		&"rook":
			if right:
				ab.add(MeshKit.cyl(0.025, 0.025, 0.6, 6), ModelLib.WOOD, MeshKit.xf(hand + Vector3(0, 0.12, 0.06), Vector3(15, 0, 0)))
				ab.add(MeshKit.box(0.24, 0.14, 0.14), ModelLib.STONE, MeshKit.xf(hand + Vector3(0, 0.42, 0.14), Vector3(15, 0, 0)))
				ab.add(MeshKit.box(0.04, 0.15, 0.15), Art.GOLD, MeshKit.xf(hand + Vector3(0.08, 0.42, 0.14), Vector3(15, 0, 0)))
				ab.add(MeshKit.box(0.04, 0.15, 0.15), Art.GOLD, MeshKit.xf(hand + Vector3(-0.08, 0.42, 0.14), Vector3(15, 0, 0)))


func _weapon_v06(ab: MeshKit.Builder, right: bool, acc: Color, det: Color) -> void:
	var hand := Vector3(0, -0.19, 0)
	match id:
		&"brakka":
			if right:
				# big ship anchor
				ab.add(MeshKit.cyl(0.025, 0.025, 0.55, 6), Color("5f6b78"), MeshKit.xf(hand + Vector3(0, 0.12, 0.06), Vector3(15, 0, 0)))
				ab.add(MeshKit.box(0.26, 0.05, 0.05), Color("5f6b78"), MeshKit.xf(hand + Vector3(0, 0.3, 0.1), Vector3(15, 0, 0)))
				ab.add(MeshKit.cyl(0.05, 0.05, 0.03, 8), Color("5f6b78"), MeshKit.xf(hand + Vector3(0, 0.41, 0.13), Vector3(105, 0, 0)))
				ab.add(MeshKit.box(0.32, 0.06, 0.06), Color("4c5662"), MeshKit.xf(hand + Vector3(0, -0.12, 0.0), Vector3(15, 0, 0)))
				ab.add(MeshKit.cone(0.05, 0.1, 4), Color("4c5662"), MeshKit.xf(hand + Vector3(0.17, -0.07, 0.0), Vector3(15, 0, 0)))
				ab.add(MeshKit.cone(0.05, 0.1, 4), Color("4c5662"), MeshKit.xf(hand + Vector3(-0.17, -0.07, 0.0), Vector3(15, 0, 0)))
		&"nova":
			if right:
				# star rifle
				ab.add(MeshKit.box(0.05, 0.07, 0.42), acc.darkened(0.3), MeshKit.xf(hand + Vector3(0, 0.02, 0.16)))
				ab.add(MeshKit.cyl(0.022, 0.022, 0.24, 6), Color("c8ccd8"), MeshKit.xf(hand + Vector3(0, 0.04, 0.46), Vector3(90, 0, 0)))
				ab.add(MeshKit.box(0.04, 0.1, 0.06), ModelLib.WOOD, MeshKit.xf(hand + Vector3(0, -0.05, 0.0)))
				ab.add(MeshKit.box(0.03, 0.03, 0.12), det, MeshKit.xf(hand + Vector3(0, 0.08, 0.18)))


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _mesh(parent: Node3D, b: MeshKit.Builder) -> MeshInstance3D:
	var mi := MeshKit.inst(parent, b.commit())
	meshes.append(mi)
	return mi


## See-through amount for every part (stealth / untargetable). 0 = solid.
func set_fade(a: float) -> void:
	for m in meshes:
		m.transparency = a


func trigger_attack() -> void:
	atk_t = 0.3


func trigger_cast() -> void:
	cast_t = 0.35


func trigger_hurt() -> void:
	hurt_t = 0.15


func start_death() -> void:
	dead_t = 0.0


func revive() -> void:
	dead_t = -1.0
	rotation = Vector3.ZERO
	position.y = 0.0
	visible = true


## Advances the procedural animation. speed = metres per second moved, dashing / stunned flags.
func animate(delta: float, speed: float, dashing := false, stunned := false, leap_h := 0.0) -> void:
	t += delta
	if dead_t >= 0.0:
		dead_t += delta
		var k := clampf(dead_t / 0.35, 0.0, 1.0)
		hip.rotation.x = -1.35 * k
		hip.position.y = 0.2 - 0.12 * k
		leg_l.rotation.x = 0.6 * k
		leg_r.rotation.x = 0.4 * k
		arm_l.rotation.z = -1.0 * k
		arm_r.rotation.z = 1.0 * k
		position.y = -0.5 * clampf((dead_t - 0.6) / 0.9, 0.0, 1.0)
		if dead_t > 1.6:
			visible = false
		return
	walk = move_toward(walk, clampf(speed / 2.6, 0.0, 1.0), delta * 6.0)
	phase += delta * (4.0 + speed * 3.2)
	var sw := sin(phase) * walk
	var bob := absf(sin(phase)) * 0.05 * walk + sin(t * 2.4) * 0.012 * (1.0 - walk)
	hip.position.y = 0.2 + bob
	hip.rotation.x = 0.14 * walk + (0.4 if dashing else 0.0)
	leg_l.rotation.x = sw * 0.8
	leg_r.rotation.x = -sw * 0.8
	var al := -sw * 0.6
	var ar := sw * 0.6
	var al_z := 0.0
	var ar_z := 0.0
	if atk_t > 0.0:
		atk_t -= delta
		var k2 := 1.0 - atk_t / 0.3
		match attack_style:
			"bow":
				al = -1.5
				ar = -1.4 + 0.4 * sin(k2 * PI)
				ar_z = 0.5
			"staff":
				ar = -0.4 - 1.3 * sin(k2 * PI)
			_:
				ar = lerpf(-2.4, 0.7, ease(k2, 0.4))
				if id == &"sable":
					al = lerpf(0.7, -2.2, ease(k2, 0.4))
	if cast_t > 0.0:
		cast_t -= delta
		var k3 := sin((1.0 - cast_t / 0.35) * PI)
		al = lerpf(al, -2.6, k3)
		ar = lerpf(ar, -2.6, k3)
		al_z = -0.3 * k3
		ar_z = 0.3 * k3
		hip.position.y += 0.06 * k3
	arm_l.rotation = Vector3(al, 0, al_z)
	arm_r.rotation = Vector3(ar, 0, ar_z)
	head.rotation.z = sin(t * 9.0) * 0.25 if stunned else 0.0
	head.rotation.x = -0.05 * walk
	var s := 1.0
	if hurt_t > 0.0:
		hurt_t -= delta
		s = 1.0 + 0.08 * (hurt_t / 0.15)
	hip.scale = Vector3(s, 1.0 / s, s)
	position.y = leap_h
	for g in glow_parts:
		g.scale = Vector3.ONE * (1.0 + 0.15 * sin(t * 5.0))
