class_name UnitStats
extends Resource
## Stats for creeps, jungle monsters, towers and Heartspires (data/units/*.tres).

@export var display_name := "Unit"
@export var max_hp := 300.0
## Damage reduction: damage taken x 100 / (100 + armor).
@export var armor := 0.0
@export var damage := 20.0
## Distance between unit edges.
@export var attack_range := 50.0
## Seconds between attacks.
@export var attack_interval := 1.0
## 0 = doesn't move (towers).
@export var move_speed := 200.0
## How close an enemy must be before this unit goes after it.
@export var aggro_range := 380.0
@export var radius := 15.0
## Gold for the hero who lands the killing blow (towers: gold for every hero on the team).
@export var gold_bounty := 20
## XP shared by nearby enemy heroes.
@export var xp_bounty := 40
## True = shoots projectiles.
@export var ranged := false
@export var projectile_speed := 800.0
## Damage multiplier against towers / Heartspires (siege creeps hit buildings hard).
@export var structure_damage_mult := 1.0
## Creeps get tougher over time: +this fraction of HP per minute of match time.
@export var hp_growth_per_min := 0.0
## +this fraction of damage per minute of match time.
@export var damage_growth_per_min := 0.0
