extends SceneTree
## Bootstrap: writes every tweakable .tres in data/. Run once:
##   godot --headless --path . -s tools/make_data.gd
## After that the .tres files are the source of truth (edit them in the Inspector).

func ab(file: String, id: String, name: String, desc: String, icon: String, ult: bool, cd: float, cdr: float, mana: float,
		dmg: float, dmgr: float, rng: float, rad: float, dur: float, val: float, valr: float, delay := 0.0, speed := 1000.0) -> AbilityData:
	var a := AbilityData.new()
	a.id = StringName(id)
	a.display_name = name
	a.description = desc
	a.icon = icon
	a.is_ultimate = ult
	a.cooldown = cd
	a.cooldown_per_rank = cdr
	a.mana_cost = mana
	a.damage = dmg
	a.damage_per_rank = dmgr
	a.cast_range = rng
	a.radius = rad
	a.duration = dur
	a.value = val
	a.value_per_rank = valr
	a.delay = delay
	a.projectile_speed = speed
	var path := "res://data/abilities/%s.tres" % file
	ResourceSaver.save(a, path)
	return load(path)


func us(file: String, name: String, hp: float, armor: float, dmg: float, rng: float, interval: float, speed: float, aggro: float,
		radius: float, gold: int, xp: int, ranged: bool, pspeed: float, smult := 1.0, hpg := 0.0, dmgg := 0.0) -> UnitStats:
	var s := UnitStats.new()
	s.display_name = name
	s.max_hp = hp
	s.armor = armor
	s.damage = dmg
	s.attack_range = rng
	s.attack_interval = interval
	s.move_speed = speed
	s.aggro_range = aggro
	s.radius = radius
	s.gold_bounty = gold
	s.xp_bounty = xp
	s.ranged = ranged
	s.projectile_speed = pspeed
	s.structure_damage_mult = smult
	s.hp_growth_per_min = hpg
	s.damage_growth_per_min = dmgg
	var path := "res://data/units/%s.tres" % file
	ResourceSaver.save(s, path)
	return load(path)


func hero(file: String, id: String, name: String, title: String, role: int, body: Color, accent: Color, detail: Color,
		hp: float, hpl: float, hpr: float, mp: float, mpl: float, mpr: float, armor: float, arml: float,
		speed: float, dmg: float, dmgl: float, rng: float, interval: float, ranged: bool, pspeed: float,
		abilities: Array, retreat: float, aggro: float) -> HeroData:
	var h := HeroData.new()
	h.id = StringName(id)
	h.display_name = name
	h.title = title
	h.role = role
	h.body_color = body
	h.accent_color = accent
	h.detail_color = detail
	h.max_hp = hp
	h.hp_per_level = hpl
	h.hp_regen = hpr
	h.max_mana = mp
	h.mana_per_level = mpl
	h.mana_regen = mpr
	h.armor = armor
	h.armor_per_level = arml
	h.move_speed = speed
	h.attack_damage = dmg
	h.attack_damage_per_level = dmgl
	h.attack_range = rng
	h.attack_interval = interval
	h.ranged_attack = ranged
	h.projectile_speed = pspeed
	var arr: Array[AbilityData] = []
	for a in abilities:
		arr.append(a)
	h.abilities = arr
	h.bot_retreat_hp = retreat
	h.bot_aggression = aggro
	var path := "res://data/heroes/%s.tres" % file
	ResourceSaver.save(h, path)
	return load(path)


func _initialize() -> void:
	# ---------- Abilities ----------
	# file, id, name, description, icon, ult, cd, cd/rank, mana, dmg, dmg/rank, range, radius, duration, value, value/rank, delay, speed
	var k1 := ab("kestrel_piercing_bolt", "piercing_bolt", "Piercing Bolt", "Long shot that passes through every enemy in a line.", "bolt", false, 7.0, -0.5, 55, 95, 40, 760, 34, 0, 0, 0, 0, 1500)
	var k2 := ab("kestrel_tumble", "tumble", "Tumble", "Quick roll; your next basic attack deals +50% damage.", "tumble", false, 8.0, -0.75, 35, 0, 0, 230, 0, 0, 0.5, 0.1, 0, 1300)
	var k3 := ab("kestrel_hawk_mark", "hawk_mark", "Hawk Mark", "Mark a target: revealed and takes +15% damage for 4 s.", "mark", false, 12.0, -1.0, 40, 0, 0, 700, 0, 4.0, 0.15, 0.03)
	var k4 := ab("kestrel_sky_volley", "sky_volley", "Sky Volley", "Rain arrows on a large area for 3 s, slowing everything inside.", "volley", true, 50.0, -6.0, 110, 55, 30, 720, 230, 3.0, 0.35, 0.05)
	var m1 := ab("morrow_shell_bash", "shell_bash", "Shell Bash", "Dash forward; the first enemy hit is stunned for 1 s.", "bash", false, 9.0, -0.5, 50, 75, 35, 290, 0, 1.0, 0, 0, 0, 1250)
	var m2 := ab("morrow_barkskin", "barkskin", "Barkskin", "Gain a shield worth 15% max HP for 3 s.", "shield", false, 12.0, -0.75, 45, 0, 0, 0, 0, 3.0, 0.15, 0.03)
	var m3 := ab("morrow_rootcall_roar", "rootcall_roar", "Rootcall Roar", "Nearby enemies are forced to attack you for 1.5 s.", "roar", false, 14.0, -1.0, 60, 45, 25, 0, 290, 1.5, 0, 0)
	var m4 := ab("morrow_landslide", "landslide", "Landslide", "Charge in a line, knocking enemies up and leaving a rock wall behind.", "landslide", true, 50.0, -6.0, 100, 160, 80, 470, 46, 1.0, 4.0, 0.5, 0, 1100)
	var l1 := ab("lumi_wisp_bolt", "wisp_bolt", "Wisp Bolt", "Fire a homing wisp that bursts on the first enemy.", "wisp", false, 5.0, -0.3, 50, 95, 40, 650, 110, 0, 0, 0, 0, 820)
	var l2 := ab("lumi_star_snare", "star_snare", "Star Snare", "Mark a circle; after 0.6 s enemies inside are rooted.", "snare", false, 10.0, -0.5, 70, 70, 35, 620, 145, 1.25, 0, 0, 0.6)
	var l3 := ab("lumi_lantern_hop", "lantern_hop", "Lantern Hop", "Short blink that leaves a slowing glow behind.", "hop", false, 12.0, -1.0, 60, 0, 0, 270, 135, 2.5, 0.4, 0.05)
	var l4 := ab("lumi_night_bloom", "night_bloom", "Night Bloom", "A giant flower of light opens, then explodes after 1 s for huge area damage.", "bloom", true, 55.0, -6.0, 120, 270, 120, 640, 260, 0, 0, 0, 1.0)
	var s1 := ab("sable_ember_dash", "ember_dash", "Ember Dash", "Dash through an enemy; resets if it gets the kill.", "ember", false, 8.0, -0.5, 45, 85, 40, 400, 0, 0, 0, 0, 0, 1500)
	var s2 := ab("sable_twin_fang", "twin_fang", "Twin Fang", "Two quick slashes; the second one heals you.", "fang", false, 6.0, -0.4, 40, 55, 25, 170, 170, 0, 0.35, 0.05)
	var s3 := ab("sable_smoke_veil", "smoke_veil", "Smoke Veil", "Turn invisible and move 30% faster for 2 s.", "smoke", false, 15.0, -1.0, 50, 0, 0, 0, 0, 2.0, 0.3, 0.05)
	var s4 := ab("sable_hundred_petals", "hundred_petals", "Hundred Petals", "Become untargetable and blink-strike up to 5 nearby enemies.", "petals", true, 50.0, -6.0, 100, 105, 55, 0, 460, 0, 5.0, 0.0)
	# ---------- Units ----------
	# file, name, hp, armor, dmg, range, interval, speed, aggro, radius, gold, xp, ranged, proj speed, structure mult, hp growth/min, dmg growth/min
	var cm := us("creep_melee", "Melee Creep", 330, 0, 21, 45, 1.0, 215, 380, 15, 20, 30, false, 0, 1.0, 0.06, 0.05)
	var cr := us("creep_ranged", "Ranged Creep", 240, 0, 27, 300, 1.1, 215, 400, 14, 22, 35, true, 760, 1.0, 0.06, 0.05)
	var cs := us("creep_siege", "Siege Creep", 720, 10, 42, 330, 1.6, 195, 420, 21, 45, 70, true, 600, 3.0, 0.06, 0.05)
	var nm := us("camp_monster", "Thornling", 430, 5, 24, 55, 1.1, 260, 0, 18, 20, 45, false, 0)
	us("tower_outer", "Outer Tower", 1750, 28, 125, 420, 1.0, 0, 0, 44, 120, 150, true, 950)
	us("tower_inner", "Inner Tower", 2050, 32, 145, 420, 1.0, 0, 0, 44, 120, 180, true, 950)
	us("heartspire", "Heartspire", 2500, 34, 115, 400, 1.2, 0, 0, 70, 0, 0, true, 950)
	# ---------- Heroes ----------
	var kes := hero("kestrel", "kestrel", "Kestrel", "the Dune Ranger", 2, Color("d0661f"), Color("1f7f7a"), Color("8ff0e6"),
		600, 70, 1.8, 380, 35, 3.0, 8, 1.2, 305, 50, 4.0, 400, 0.85, true, 1150, [k1, k2, k3, k4], 0.32, 1.0)
	kes.skill_priority = PackedInt32Array([0, 1, 2])
	ResourceSaver.save(kes, kes.resource_path)
	var mor := hero("morrow", "morrow", "Morrow", "the Mossback Warden", 0, Color("5aa346"), Color("9aa3ad"), Color("ffd75e"),
		920, 95, 3.0, 300, 30, 2.0, 18, 1.5, 290, 46, 3.5, 75, 1.05, false, 0, [m1, m2, m3, m4], 0.25, 1.15)
	var lum := hero("lumi", "lumi", "Lumi Vesper", "the Lantern Witch", 1, Color("5b3fd0"), Color("bfeeff"), Color("ffd84a"),
		560, 65, 1.6, 520, 45, 4.5, 6, 1.0, 300, 40, 3.0, 370, 1.0, true, 900, [l1, l2, l3, l4], 0.35, 0.9)
	var sab := hero("sable", "sable", "Sable", "the Ember Fox", 3, Color("2a2531"), Color("d8263f"), Color("f4efe9"),
		760, 85, 2.6, 320, 30, 2.6, 12, 1.5, 325, 62, 5.0, 75, 0.88, false, 0, [s1, s2, s3, s4], 0.3, 1.1)
	# ---------- Match ----------
	var mc := MatchConfig.new()
	mc.player_hero = kes
	var db: Array[HeroData] = [mor, lum]
	mc.dawn_bots = db
	var ub: Array[HeroData] = [mor, sab, lum]
	mc.dusk_bots = ub
	mc.creep_melee = cm
	mc.creep_ranged = cr
	mc.creep_siege = cs
	mc.camp_monster = nm
	ResourceSaver.save(mc, "res://data/match_config.tres")
	print("data written")
	quit()
