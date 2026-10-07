class_name MatchConfig
extends Resource
## Global match tuning: teams, creep waves, gold, XP, respawn, structures, sudden death.
## Edit data/match_config.tres in the Inspector.

@export_group("Teams")
## The hero you play (Team Dawn, blue).
@export var player_hero: HeroData
## Your two bot teammates.
@export var dawn_bots: Array[HeroData] = []
## The three enemy bots (Team Dusk, red).
@export var dusk_bots: Array[HeroData] = []
## 0 Easy, 1 Normal, 2 Hard. Changes how fast bots react and how often they use skills.
@export_range(0, 2) var bot_difficulty := 1

@export_group("Creep waves")
@export var creep_melee: UnitStats
@export var creep_ranged: UnitStats
@export var creep_siege: UnitStats
## Seconds before the first wave leaves each base.
@export var first_wave_time := 4.0
## Seconds between waves.
@export var wave_interval := 25.0
@export var melee_per_wave := 3
@export var ranged_per_wave := 1
## Every Nth wave brings a siege creep (0 = never).
@export var siege_every_n_waves := 2
## Empowered creeps: each enemy building your team has destroyed makes your new creeps
## this much stronger (HP and damage). 0.2 = +20% per building. Helps games close out.
@export var creep_mult_per_building_destroyed := 0.3

@export_group("Jungle")
@export var camp_monster: UnitStats
## Monsters per camp.
@export var monsters_per_camp := 2
## Seconds before a cleared camp comes back.
@export var camp_respawn := 60.0

@export_group("Gold")
@export var passive_gold_per_sec := 2.0
@export var starting_gold := 0
@export var gold_hero_kill := 150
## Extra gold per kill on the victim's current streak.
@export var gold_streak_bonus := 30
@export var gold_assist := 50
## Every hero on the team gets this when an enemy tower falls.
@export var gold_tower_team := 120

@export_group("XP and levels")
@export var max_level := 12
## XP needed for level 2.
@export var xp_level_base := 100.0
## Extra XP needed for each level after that.
@export var xp_level_growth := 60.0
@export var passive_xp_per_sec := 1.0
## Heroes within this distance share XP from a kill.
@export var xp_share_radius := 1100.0
@export var hero_kill_xp_base := 100.0
@export var hero_kill_xp_per_level := 20.0

@export_group("Respawn, base and spells")
@export var respawn_base := 5.0
@export var respawn_per_level := 1.25
## Extra respawn seconds per minute of match time (late deaths hurt more, so games end).
@export var respawn_per_minute := 1.5
@export var respawn_max := 32.0
## Fountain heals this fraction of max HP / mana per second.
@export var fountain_heal_pct := 0.15
@export var fountain_radius := 300.0
## Fountain damage per second to enemy heroes inside it.
@export var fountain_damage := 600.0
## Healing shrine (river island): heals this fraction of max HP and mana once, then recharges.
@export var shrine_heal_pct := 0.4
@export var shrine_cooldown := 45.0
@export var shrine_radius := 110.0
## Recall (B): seconds of channeling before teleporting home.
@export var recall_time := 4.0
## Heal spell (H): heals this fraction of max HP + flat amount.
@export var heal_spell_pct := 0.25
@export var heal_spell_flat := 80.0
@export var heal_spell_cooldown := 60.0

@export_group("Towers and Heartspire")
## Each shot in a row at the same hero does this much more damage (0.25 = +25%).
@export var tower_hero_ramp := 0.25
@export var tower_hero_ramp_max_stacks := 4
## Seconds a tower stays locked on a hero who attacked an allied hero under it.
@export var tower_aggro_time := 2.5
## Buildings take this much LESS damage when no enemy creeps are near (stops hero-only rushes).
@export_range(0.0, 0.95, 0.05) var backdoor_reduction := 0.3
@export var backdoor_radius := 800.0

@export_group("Match end")
## From this time buildings take more damage and new creeps are stronger.
@export var sudden_death_time := 540.0
@export var sudden_death_structure_damage_mult := 2.5
@export var sudden_death_creep_mult := 1.6
## If both Heartspires still stand: the team that destroyed more buildings wins.
@export var tiebreak_time := 900.0


func xp_for_level(level: int) -> float:
	return xp_level_base + xp_level_growth * float(level - 1)


func respawn_time(level: int, match_time := 0.0) -> float:
	return minf(respawn_max, respawn_base + respawn_per_level * float(level) + respawn_per_minute * match_time / 60.0)
