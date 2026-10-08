class_name ItemData
extends Resource
## One shop item (data/items/*.tres). Basic items have no components; upgraded items are a
## Dota-style recipe: own the components (or buy them on the spot) + pay `cost` to combine.
## Every item can be owned once. Edit the numbers in the Inspector.

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
## Icon key drawn in code (see Art.draw_item_icon).
@export var icon := ""
## Icon tint.
@export var color := Color(0.85, 0.85, 0.9)
## 1 = basic, 2 = upgraded.
@export_range(1, 2) var tier := 1
## Gold price for a basic item; the recipe (combine) cost for an upgraded item.
@export var cost := 300
## Items (ItemData .tres) consumed by the upgrade. Missing ones are bought automatically at
## their price. (Typed as Resource only to avoid a script self-reference.)
@export var components: Array[Resource] = []

@export_group("Stats")
@export var bonus_damage := 0.0
## 0.2 = +20% attack speed.
@export var bonus_attack_speed := 0.0
@export var bonus_move_speed := 0.0
@export var bonus_hp := 0.0
@export var bonus_hp_regen := 0.0
@export var bonus_armor := 0.0
@export var bonus_mana := 0.0
@export var bonus_mana_regen := 0.0
## 0.15 = skill cooldowns 15% shorter (total capped at 40%).
@export_range(0.0, 0.5) var cooldown_reduction := 0.0
## Fraction of basic-attack damage healed back (works for ranged attacks too).
@export_range(0.0, 1.0) var lifesteal := 0.0

@export_group("Active")
## "none" = passive item, "blink" = short-range teleport (item button in the HUD).
@export_enum("none", "blink") var active := "none"
@export var active_cooldown := 15.0
## Blink: max teleport distance in pixels (100 px = 1 m).
@export var active_range := 450.0


## Full price when bought from scratch (recipe + every component).
func total_cost() -> int:
	var t := cost
	for c in components:
		if c != null:
			t += int(c.call("total_cost"))
	return t


## Short stat lines for the shop and the README, e.g. ["+14 damage", "+18% attack speed"].
func stat_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if bonus_damage != 0.0:
		out.append("+%d damage" % int(bonus_damage))
	if bonus_attack_speed != 0.0:
		out.append("+%d%% attack speed" % roundi(bonus_attack_speed * 100.0))
	if bonus_move_speed != 0.0:
		out.append("+%d move speed" % int(bonus_move_speed))
	if bonus_hp != 0.0:
		out.append("+%d max HP" % int(bonus_hp))
	if bonus_hp_regen != 0.0:
		out.append("+%.1f HP regen" % bonus_hp_regen)
	if bonus_armor != 0.0:
		out.append("+%d armor" % int(bonus_armor))
	if bonus_mana != 0.0:
		out.append("+%d max mana" % int(bonus_mana))
	if bonus_mana_regen != 0.0:
		out.append("+%.1f mana regen" % bonus_mana_regen)
	if cooldown_reduction != 0.0:
		out.append("-%d%% skill cooldowns" % roundi(cooldown_reduction * 100.0))
	if lifesteal != 0.0:
		out.append("%d%% lifesteal" % roundi(lifesteal * 100.0))
	if active == "blink":
		out.append("Active: blink %.1f m (%ds cd)" % [active_range / 100.0, int(active_cooldown)])
	return out
