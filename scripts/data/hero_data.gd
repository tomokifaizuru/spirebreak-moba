class_name HeroData
extends Resource
## A playable hero: base stats, growth per level, look and its 4 skills.
## Open data/heroes/<name>.tres in Godot and change the numbers in the Inspector.

@export var id: StringName = &""
@export var display_name := "Hero"
@export var title := ""
@export_enum("Tank", "Mage", "Marksman", "Assassin", "Support", "Fighter") var role := 0
## One short line shown on the hero select card.
@export var tagline := ""
## 1 = easy, 2 = medium, 3 = hard (difficulty dots on the hero select card).
@export_range(1, 3) var difficulty := 1

const ROLE_NAMES := ["Tank", "Mage", "Marksman", "Assassin", "Support", "Fighter"]
const ROLE_COLORS := [Color("5fbf6a"), Color("9a7bff"), Color("ffc44a"), Color("ff5a7a"), Color("ff8fd0"), Color("ff9a3c")]

@export_group("Look")
## Hero colours used by the 3D model and the portrait (the outfit uses the team colour).
@export var body_color := Color.WHITE
@export var accent_color := Color.GRAY
@export var detail_color := Color.BLACK
## Size of the 3D model (1 = normal chibi).
@export var model_scale := 1.0

@export_group("Health and mana")
@export var max_hp := 600.0
@export var hp_per_level := 70.0
## HP regenerated per second.
@export var hp_regen := 2.0
@export var max_mana := 400.0
@export var mana_per_level := 35.0
## Mana regenerated per second.
@export var mana_regen := 3.0
## Damage reduction: damage taken x 100 / (100 + armor).
@export var armor := 8.0
@export var armor_per_level := 1.2

@export_group("Attack and movement")
## World pixels per second.
@export var move_speed := 300.0
@export var attack_damage := 50.0
@export var attack_damage_per_level := 4.0
## Extra attack speed per level above 1, as a fraction of base attack speed (0.035 = +3.5% per level).
## Adds to item attack speed.
@export var attack_speed_per_level := 0.0
## Extra attack damage per level above 1, as a fraction of base attack damage (0.035 = +3.5% per level).
## Applied on top of attack_damage_per_level.
@export var attack_damage_pct_per_level := 0.0
## From this hero level on, all damage dealt to creeps (lane creeps and jungle monsters) is multiplied
## by 1 + creep_damage_bonus. 0 = off.
@export var creep_damage_bonus := 0.0
@export var creep_bonus_level := 6
## Distance between the two units' edges. Melee heroes use ~70.
@export var attack_range := 400.0
## Seconds between basic attacks.
@export var attack_interval := 0.9
## True = basic attacks fire a projectile, false = melee hit.
@export var ranged_attack := true
@export var projectile_speed := 1100.0
## Look of the basic-attack projectile: arrow, orb or petal.
@export_enum("orb", "arrow", "petal") var projectile_style := "orb"
## Body size (collision and drawing).
@export var radius := 28.0

@export_group("Skills")
## Skill 1, Skill 2, Skill 3, Ultimate (in this order).
@export var abilities: Array[AbilityData] = []
## Order in which basic skills (0, 1, 2) get their level-up points. The ultimate is always taken at 4 / 8 / 12.
@export var skill_priority: PackedInt32Array = PackedInt32Array([0, 1, 2])

@export_group("Bot behaviour")
## Bots go home below this HP fraction.
@export_range(0.05, 0.9, 0.01) var bot_retreat_hp := 0.3
## Higher = bots fight more eagerly with this hero.
@export_range(0.3, 2.0, 0.05) var bot_aggression := 1.0


func role_name() -> String:
	return ROLE_NAMES[clampi(role, 0, ROLE_NAMES.size() - 1)]


func role_color() -> Color:
	return ROLE_COLORS[clampi(role, 0, ROLE_COLORS.size() - 1)]


## Tank or Fighter: can stand in front and soak tower shots.
func is_frontline() -> bool:
	return role == 0 or role == 5
