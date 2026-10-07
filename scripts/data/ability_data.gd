class_name AbilityData
extends Resource
## One hero skill (3 per hero + 1 ultimate).
## The code decides WHAT a skill does from its `id` (see hero.gd -> _do_ability).
## Every number below is safe to tweak in the Inspector.

## Internal id used by the code. Don't rename it unless you also change hero.gd.
@export var id: StringName = &""
@export var display_name := "Skill"
@export_multiline var description := ""
## Icon drawn on the skill button (see art.gd -> draw_icon).
@export var icon := "bolt"
## Ultimates unlock at hero level 4 and rank up at 8 and 12.
@export var is_ultimate := false
## How the aim indicator looks while you drag the button:
## line = skillshot, area = circle at the aimed point, self = circle around you,
## dash = movement arrow, target = enemy unit, ally = friendly hero.
@export_enum("line", "area", "self", "dash", "target", "ally") var aim := "line"

@export_group("Cost and cooldown")
## Seconds between casts at rank 1.
@export var cooldown := 8.0
## Cooldown change for every rank above 1 (negative = shorter).
@export var cooldown_per_rank := -0.5
## Mana spent per cast.
@export var mana_cost := 50.0

@export_group("Numbers")
## Damage at rank 1 (for Sky Volley: per tick; Twin Fang: per slash; Hundred Petals: per strike).
@export var damage := 80.0
## Extra damage per rank above 1.
@export var damage_per_rank := 35.0
## How far the skill reaches (world pixels). For dashes/blinks: the travel distance.
@export var cast_range := 600.0
## Area radius (circles) or hit width (lines / dashes).
@export var radius := 100.0
## How long the effect lasts in seconds (stun, root, taunt, shield, stealth, area...).
@export var duration := 1.0
## Extra number; meaning depends on the skill (slow %, shield % of max HP, damage-taken bonus, heal %, strikes...).
@export var value := 0.0
## Change of `value` per rank above 1.
@export var value_per_rank := 0.0
## A second number for skills with two effects (Bloom Ward haste, Battle Hunger lifesteal, Spring Chorus slow).
@export var value2 := 0.0
## Wind-up before an area goes off (Star Snare, Night Bloom).
@export var delay := 0.0
## Projectile speed for skills that fire one; dash speed for dashes.
@export var projectile_speed := 1000.0


func cd_at(rank: int) -> float:
	return maxf(0.5, cooldown + cooldown_per_rank * float(maxi(rank, 1) - 1))


func dmg_at(rank: int) -> float:
	return damage + damage_per_rank * float(maxi(rank, 1) - 1)


func val_at(rank: int) -> float:
	return value + value_per_rank * float(maxi(rank, 1) - 1)
