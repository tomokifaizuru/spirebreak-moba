extends SceneTree
## Writes the shop items (data/items/*.tres + data/items/catalog.tres) and links the catalog
## into data/match_config.tres. Run once:
##   godot --headless --path . -s tools/make_items.gd
## After that the .tres files are the source of truth (edit them in the Inspector). Re-running
## this script overwrites Inspector edits to items.

func item(id: String, name: String, desc: String, icon: String, col: Color, cost: int, comps: Array, stats: Dictionary) -> ItemData:
	var it := ItemData.new()
	it.id = StringName(id)
	it.display_name = name
	it.description = desc
	it.icon = icon
	it.color = col
	it.cost = cost
	var c: Array[Resource] = []
	for x in comps:
		c.append(x)
	it.components = c
	it.tier = 2 if not c.is_empty() else 1
	for k in stats:
		it.set(k, stats[k])
	var path := "res://data/items/%s.tres" % id
	ResourceSaver.save(it, path)
	return load(path)


func arr(list: Array) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for x in list:
		out.append(x)
	return out


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/items")
	# ---- basic items ----
	var boots := item("swift_boots", "Swift Boots", "Light boots for getting around the lane.", "boots", Color("d9a066"), 300, [],
			{"bonus_move_speed": 35.0})
	var blade := item("iron_blade", "Iron Blade", "A plain, honest sword.", "blade", Color("c9d2de"), 400, [],
			{"bonus_damage": 12.0})
	var glove := item("quickstring_glove", "Quickstring Glove", "Swing and shoot faster.", "glove", Color("f2c94c"), 400, [],
			{"bonus_attack_speed": 0.18})
	var heart := item("oakheart_charm", "Oakheart Charm", "A carved heart of living oak.", "heart", Color("e05a5a"), 400, [],
			{"bonus_hp": 200.0, "bonus_hp_regen": 1.5})
	var buckler := item("stoneskin_buckler", "Stoneskin Buckler", "Shrugs off creeps and towers alike.", "buckler", Color("9aa3ad"), 350, [],
			{"bonus_armor": 6.0})
	var pendant := item("moonwell_pendant", "Moonwell Pendant", "More mana, refilled faster.", "pendant", Color("6fa8ff"), 350, [],
			{"bonus_mana": 160.0, "bonus_mana_regen": 1.5})
	var fang := item("leech_fang", "Leech Fang", "Basic attacks heal you.", "fang", Color("c0392b"), 450, [],
			{"lifesteal": 0.12})
	var blink := item("blink_charm", "Blink Charm", "Active: teleport a short distance in the aimed direction.", "blink", Color("b388ff"), 500, [],
			{"active": "blink", "active_cooldown": 15.0, "active_range": 450.0})
	# ---- upgraded items (components + recipe cost) ----
	var treads := item("gale_treads", "Gale Treads", "Boots that ride the wind.", "treads", Color("7fe0c8"), 400, [boots],
			{"bonus_move_speed": 65.0, "bonus_attack_speed": 0.12})
	var storm := item("storm_edge", "Storm Edge", "A crackling blade that strikes fast and hard.", "storm", Color("8ecbff"), 500, [blade, glove],
			{"bonus_damage": 30.0, "bonus_attack_speed": 0.25})
	var frenzy := item("frenzy_gauntlets", "Frenzy Gauntlets", "Attack speed, and lots of it.", "gauntlets", Color("ff9f43"), 450, [glove],
			{"bonus_attack_speed": 0.45, "bonus_damage": 6.0})
	var plate := item("titan_plate", "Titan Plate", "Huge HP and armor for the front line.", "plate", Color("b0b8c8"), 450, [heart, buckler],
			{"bonus_hp": 400.0, "bonus_hp_regen": 3.0, "bonus_armor": 12.0})
	var crown := item("sage_crown", "Sage Crown", "Big mana and shorter skill cooldowns.", "crown", Color("ffd36b"), 500, [pendant],
			{"bonus_mana": 320.0, "bonus_mana_regen": 3.0, "cooldown_reduction": 0.2})
	var cleaver := item("bloodfang_cleaver", "Bloodfang Cleaver", "Damage plus strong lifesteal.", "cleaver", Color("e74c3c"), 400, [fang, blade],
			{"bonus_damage": 24.0, "lifesteal": 0.2})
	var phase := item("phase_charm", "Phase Charm", "Active: a longer blink with a shorter cooldown.", "phase", Color("e0b3ff"), 550, [blink],
			{"active": "blink", "active_cooldown": 9.0, "active_range": 700.0})

	var cat := ItemCatalog.new()
	cat.basic = arr([boots, blade, glove, heart, buckler, pendant, fang, blink])
	cat.upgraded = arr([treads, storm, frenzy, plate, crown, cleaver, phase])
	cat.build_tank = arr([boots, heart, buckler, treads, plate, blink, phase])
	cat.build_fighter = arr([boots, heart, buckler, treads, plate, fang, blade, cleaver])
	cat.build_assassin = arr([blade, boots, blink, treads, glove, storm, phase])
	cat.build_mage = arr([pendant, boots, crown, treads, heart, blink, phase])
	cat.build_marksman = arr([glove, boots, blade, storm, treads, fang, frenzy])
	cat.build_support = arr([pendant, boots, crown, treads, heart, buckler, plate])
	ResourceSaver.save(cat, "res://data/items/catalog.tres")
	var mc: MatchConfig = load("res://data/match_config.tres")
	mc.item_catalog = load("res://data/items/catalog.tres")
	mc.starting_gold = 300
	# v0.3 gold tuning: more steady income, smaller kill bounties (less snowball with items)
	mc.passive_gold_per_sec = 2.6
	mc.gold_hero_kill = 120
	mc.gold_assist = 40
	ResourceSaver.save(mc, "res://data/match_config.tres")
	print("items written: ", cat.all_items().size())
	quit()
