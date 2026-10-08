extends SceneTree
## Prints every hero's effective stats and skill damage per rank (balance helper):
##   godot --headless --path . -s tools/print_stats.gd

func _initialize() -> void:
	var cfg: MatchConfig = load("res://data/match_config.tres")
	for h in cfg.roster:
		var d: HeroData = h
		print("%-8s hp %d+%d arm %.0f+%.1f dmg %.0f+%.1f int %.2f rng %d ms %d mana %d+%d" % [d.id, d.max_hp, d.hp_per_level, d.armor, d.armor_per_level,
			d.attack_damage, d.attack_damage_per_level, d.attack_interval, d.attack_range, d.move_speed, d.max_mana, d.mana_per_level])
		for ab in d.abilities:
			var a: AbilityData = ab
			print("    %-16s dmg %.0f +%.0f/rank  cd %.1f%+.1f  val %.2f%+.2f v2 %.2f dur %.2f rad %.0f" % [a.id, a.damage, a.damage_per_rank, a.cooldown, a.cooldown_per_rank, a.value, a.value_per_rank, a.value2, a.duration, a.radius])
	quit()
