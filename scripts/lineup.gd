class_name Lineup
extends RefCounted
## Builds the two teams for a match: you take one hero, the bots fill the other 5 slots from the
## remaining roster (2 allies, 3 enemies). Every split is scored so both teams get a sensible mix
## (someone in front, someone dealing damage from range), then one of the best splits is picked at random.


## Returns {"dawn": [player, ally, ally], "dusk": [enemy, enemy, enemy]} (Array[HeroData] each).
static func build(player: HeroData, roster: Array, rng: RandomNumberGenerator) -> Dictionary:
	var others: Array = []
	for h in roster:
		if h != null and h != player:
			others.append(h)
	# Shuffle first so ties are broken randomly.
	for i in range(others.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = others[i]
		others[i] = others[j]
		others[j] = tmp
	var best_score := -INF
	var best: Array = []
	var n := others.size()
	for i in n:
		for j in range(i + 1, n):
			var allies: Array = [player, others[i], others[j]]
			var enemies: Array = []
			for k in n:
				if k != i and k != j:
					enemies.append(others[k])
			var a := team_score(allies)
			var b := team_score(enemies)
			# Fair first (weakest team as good as possible), then balanced, then a little randomness.
			var score := minf(a, b) * 10.0 - absf(a - b) * 2.0 + rng.randf() * 3.0
			if score > best_score:
				best_score = score
				best = [allies, enemies]
	var dawn: Array[HeroData] = []
	var dusk: Array[HeroData] = []
	if best.is_empty():
		dawn.append(player)
		return {"dawn": dawn, "dusk": dusk}
	for h in best[0]:
		dawn.append(h)
	for h in best[1]:
		dusk.append(h)
	return {"dawn": dawn, "dusk": dusk}


## Higher = better-rounded team.
static func team_score(team: Array) -> float:
	var front := 0
	var ranged := 0
	var roles := {}
	for x in team:
		var h: HeroData = x
		if h.is_frontline():
			front += 1
		if h.ranged_attack:
			ranged += 1
		roles[h.role] = true
	var s := float(roles.size())
	if front >= 1:
		s += 3.0
	if front >= 2:
		s -= 1.5
	if ranged >= 1:
		s += 2.0
	if ranged == team.size():
		s -= 1.0
	return s
