class_name Shop
extends RefCounted
## Buying and combining items (used by the shop panel and by bots).
## Rules: you can buy at your base (within MatchConfig.shop_radius of your fountain) or while
## dead. Each item can be owned once. Upgrades consume the components you own; components you
## lack are bought on the spot at their own price, so price = recipe cost + missing parts.

static func can_shop_here(h: Hero) -> bool:
	if h == null or h.arena == null:
		return false
	if not h.alive:
		return true
	return h.position.distance_to(h.fountain) <= h.arena.config.shop_radius


static func owns(h: Hero, it: ItemData) -> bool:
	for x in h.items:
		if x == it or x.id == it.id:
			return true
	return false


## The owned items an upgrade would consume (recursively through sub-recipes).
static func _consumed(h: Hero, it: ItemData, pool: Array, used: Array) -> int:
	# Returns the gold still to pay for `it` given the items left in `pool`.
	var pay := it.cost
	for cr in it.components:
		var c := cr as ItemData
		if c == null:
			continue
		var found := -1
		for i in pool.size():
			if (pool[i] as ItemData).id == c.id:
				found = i
				break
		if found >= 0:
			used.append(pool[found])
			pool.remove_at(found)
		else:
			pay += _consumed(h, c, pool, used)
	return pay


## Gold needed to get `it` right now, taking owned components into account.
static func price_for(h: Hero, it: ItemData) -> int:
	var pool: Array = h.items.duplicate()
	return _consumed(h, it, pool, [])


## "" if the hero can buy `it`, else the reason ("Owned", "Not enough gold", ...).
static func block_reason(h: Hero, it: ItemData, check_location := true) -> String:
	if it == null:
		return "?"
	if owns(h, it):
		return "Owned"
	if check_location and not can_shop_here(h):
		return "Return to base to buy"
	var used: Array = []
	var pool: Array = h.items.duplicate()
	var price := _consumed(h, it, pool, used)
	if h.items.size() - used.size() + 1 > h.arena.config.item_slots:
		return "Inventory full"
	if h.gold < price:
		return "Need %d more gold" % (price - h.gold)
	return ""


static func can_buy(h: Hero, it: ItemData) -> bool:
	return block_reason(h, it) == ""


## Buys (or combines into) `it`. Returns true on success.
static func buy(h: Hero, it: ItemData) -> bool:
	if not can_buy(h, it):
		return false
	var used: Array = []
	var pool: Array = h.items.duplicate()
	var price := _consumed(h, it, pool, used)
	for u in used:
		h.items.erase(u)
	h.gold -= price
	h.items.append(it)
	h.items_changed()
	if h.arena != null:
		h.arena.on_item_bought(h, it, price)
	return true


## Which owned items `it` would consume (for the shop tooltip).
static func consumed_items(h: Hero, it: ItemData) -> Array:
	var used: Array = []
	_consumed(h, it, h.items.duplicate(), used)
	return used


## True when the hero owns the item or an upgrade that was built from it (e.g. boots -> treads).
static func has_or_built(h: Hero, it: ItemData) -> bool:
	for x in h.items:
		if _contains(x, it):
			return true
	return false


static func _contains(root: ItemData, it: ItemData) -> bool:
	if root == null:
		return false
	if root.id == it.id:
		return true
	for c in root.components:
		if c != null and _contains(c as ItemData, it):
			return true
	return false
