extends SceneTree
## v0.4: writes the Brambleback big-camp monster (data/units/camp_monster_big.tres) and links it
## into match_config.tres without regenerating the rest of the data.
##   godot --headless --path . -s tools/make_v04_data.gd

func _initialize() -> void:
	var base: UnitStats = load("res://data/units/camp_monster.tres")
	var nb: UnitStats = base.duplicate()
	nb.display_name = "Brambleback"
	nb.max_hp = 1100.0
	nb.armor = 9.0
	nb.damage = 42.0
	nb.attack_range = 70.0
	nb.attack_interval = 1.3
	nb.move_speed = 230.0
	nb.radius = 30.0
	nb.gold_bounty = 55
	nb.xp_bounty = 95
	ResourceSaver.save(nb, "res://data/units/camp_monster_big.tres")
	var cfg: MatchConfig = load("res://data/match_config.tres")
	cfg.camp_monster_big = load("res://data/units/camp_monster_big.tres")
	ResourceSaver.save(cfg, "res://data/match_config.tres")
	print("big camp monster linked")
	quit()
