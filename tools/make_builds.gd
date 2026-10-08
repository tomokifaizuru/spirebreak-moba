extends SceneTree
## Writes the recommended builds (data/builds/*.tres) and links them into match_config.tres.
##   godot --headless --path . -s tools/make_builds.gd
## Re-running overwrites Inspector edits to the builds.

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/builds")
	var cat: ItemCatalog = load("res://data/items/catalog.tres")
	var by_id := {}
	for it in cat.all_items():
		by_id[String(it.id)] = it
	var cfg: MatchConfig = load("res://data/match_config.tres")
	var plans := {
		"morrow": ["swift_boots", "oakheart_charm", "stoneskin_buckler", "gale_treads", "titan_plate"],
		"rook": ["swift_boots", "oakheart_charm", "gale_treads", "iron_blade", "bloodfang_cleaver"],
		"sable": ["iron_blade", "swift_boots", "blink_charm", "gale_treads", "storm_edge"],
		"lumi": ["moonwell_pendant", "swift_boots", "sage_crown", "oakheart_charm", "gale_treads"],
		"kestrel": ["quickstring_glove", "swift_boots", "gale_treads", "iron_blade", "storm_edge"],
		"calla": ["moonwell_pendant", "swift_boots", "sage_crown", "oakheart_charm", "gale_treads"],
	}
	var builds: Array[BuildData] = []
	for h in cfg.roster:
		var b := BuildData.new()
		b.hero = h
		var arr: Array[ItemData] = []
		for id in plans[String(h.id)]:
			arr.append(by_id[id])
		b.items = arr
		ResourceSaver.save(b, "res://data/builds/%s.tres" % String(h.id))
		builds.append(load("res://data/builds/%s.tres" % String(h.id)))
	cfg.recommended_builds = builds
	ResourceSaver.save(cfg, "res://data/match_config.tres")
	print("builds written: ", builds.size())
	quit()
