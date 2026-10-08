class_name ItemCatalog
extends Resource
## Every item the shop sells (data/items/catalog.tres) + the order bots buy them in per role.

## Basic items, in shop order.
@export var basic: Array[ItemData] = []
## Upgraded (combined) items, in shop order.
@export var upgraded: Array[ItemData] = []
@export_group("Bot builds (buy order per role)")
@export var build_tank: Array[ItemData] = []
@export var build_fighter: Array[ItemData] = []
@export var build_assassin: Array[ItemData] = []
@export var build_mage: Array[ItemData] = []
@export var build_marksman: Array[ItemData] = []
@export var build_support: Array[ItemData] = []


func all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	out.append_array(basic)
	out.append_array(upgraded)
	return out


## role: HeroData.role (0 Tank, 1 Mage, 2 Marksman, 3 Assassin, 4 Support, 5 Fighter).
func build_for(role: int) -> Array[ItemData]:
	match role:
		0:
			return build_tank
		1:
			return build_mage
		2:
			return build_marksman
		3:
			return build_assassin
		5:
			return build_fighter
	return build_support
