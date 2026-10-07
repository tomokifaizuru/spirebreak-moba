extends SceneTree
## Headless match test: every hero (yours too) is a bot. Prints progress and a summary.
##   godot --headless --path . -s tools/sim_match.gd -- seed=3 limit=1000 substeps=4
var arena: Arena
var frames := 0
var opts := {"seed": "1", "limit": "1100", "substeps": "4", "log": "60"}
var last_log := 0.0
var last_pos := {}
var stuck := {}
var max_creeps := 0
var old_creeps := 0
var wall_start := 0
var hist := [{}, {}]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	seed(int(opts["seed"]))


func _physics_process(_d: float) -> bool:
	frames += 1
	if frames == 1:
		arena = load("res://scenes/match.tscn").instantiate()
		arena.sim_substeps = int(opts["substeps"])
		root.add_child(arena)
		arena.player.autopilot = true
		wall_start = Time.get_ticks_msec()
		return false
	if arena == null:
		return false
	var t: float = arena.time
	var creeps := 0
	for u in arena.units:
		if u.alive and u.kind == Unit.Kind.CREEP:
			creeps += 1
			if u.age > 200.0:
				old_creeps += 1
	max_creeps = maxi(max_creeps, creeps)
	for h in arena.heroes:
		var k: String = "dead" if not h.alive else (h.brain.state + ("+P" if h.brain.pushing else ""))
		hist[h.team][k] = hist[h.team].get(k, 0) + 1
	if t - last_log >= float(opts["log"]):
		last_log = t
		var s := "t=%3d  K %d-%d  bld D%d/U%d %s creeps %d |" % [int(t), arena.kills[0], arena.kills[1], _alive(0), _alive(1), _hp(), creeps]
		for h in arena.heroes:
			s += " %s%d L%d %s %d/%d/%d hp%d%% |" % ["D" if h.team == 0 else "U", arena.heroes.find(h), h.level, h.brain.state, h.kills, h.deaths, h.assists, int(h.hp_frac() * 100)]
			# stuck check: alive the whole interval, away from the fountain, and walked < 40 px in total
			var key: String = str(h.name)
			if h.alive:
				var moved: float = h.distance_moved
				if last_pos.has(key) and last_pos[key][1] == h.deaths and moved - last_pos[key][0] < 40.0 \
						and h.position.distance_to(h.fountain) > 500.0:
					stuck[key] = stuck.get(key, 0) + 1
					print("  STUCK? ", key, " at ", h.position, " state ", h.brain.state)
				last_pos[key] = [moved, h.deaths]
			else:
				last_pos.erase(key)
		print(s)
	if arena.over or t > float(opts["limit"]):
		var wall := (Time.get_ticks_msec() - wall_start) / 1000.0
		print("RESULT seed=%s winner=%s reason=\"%s\" time=%.0fs (%d:%02d) kills=%d-%d buildings_destroyed=%d-%d waves=%d max_creeps=%d old_creep_samples=%d stuck=%s wall=%.1fs" % [
			opts["seed"], ("DAWN" if arena.winner == 0 else ("DUSK" if arena.winner == 1 else "NONE")), arena.end_reason, t, int(t) / 60, int(t) % 60,
			arena.kills[0], arena.kills[1], arena.destroyed[0], arena.destroyed[1], arena.wave_count, max_creeps, old_creeps, str(stuck), wall])
		print("  dbg ", arena.dbg)
		for tm in [0, 1]:
			var tot := 0
			for k in hist[tm]:
				tot += hist[tm][k]
			var o := "  states %s:" % ["DAWN", "DUSK"][tm]
			for k in hist[tm]:
				o += " %s=%d%%" % [k, int(100.0 * hist[tm][k] / tot)]
			print(o)
		for h in arena.heroes:
			print("  %s %-12s L%2d K/D/A %d/%d/%d LH %d gold %d moved %d" % ["DAWN" if h.team == 0 else "DUSK", h.display_name, h.level, h.kills, h.deaths, h.assists, h.last_hits, h.gold, int(h.distance_moved)])
		quit()
	return false


func _hp() -> String:
	var o := ""
	for st in arena.structures:
		if st.alive:
			o += "%s%d:%d " % ["D" if st.team == 0 else "U", st.tier, int(st.hp_frac() * 100)]
	return o


func _alive(team: int) -> int:
	var n := 0
	for s in arena.structures:
		if s.team == team and s.alive:
			n += 1
	return n
