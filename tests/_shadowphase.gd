extends SceneTree
# Shadowflare is a phase: cast at the Living Armor's next cast after it
# drops to 50% and to 20% HP (once each), never otherwise; about 20 s long.
var a
var t := 0.0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func name_of(s):
	return s.skill_name if s != null else "none"
func _process(d):
	t += d
	if t < 0.8: return false
	var g = a.enemies[0]
	for c in a.combatants: c.hold = true
	var picks := {}
	for i in 300: picks[a._choose_enemy_skill(g).skill_name] = true
	check(not picks.has("Shadowflare"), "full HP: never picked at random")
	g.hp = int(g.max_hp * 0.6)
	check(a._sure_hp_skill(g, g.skills) == null or a._sure_hp_skill(g, g.skills).skill_name != "Shadowflare", "60%: not yet")
	g.hp = int(g.max_hp * 0.5)
	check(name_of(a._sure_hp_skill(g, g.skills)) == "Shadowflare", "50%: Shadowflare")
	check(name_of(a._sure_hp_skill(g, g.skills)) != "Shadowflare", "  only once for that threshold")
	g.hp = int(g.max_hp * 0.2)
	check(name_of(a._sure_hp_skill(g, g.skills)) == "Shadowflare", "20%: Shadowflare again")
	check(name_of(a._sure_hp_skill(g, g.skills)) != "Shadowflare", "  and that's the last")
	g.remove_meta("sure_done")
	g.hp = int(g.max_hp * 0.1)
	check(name_of(a._sure_hp_skill(g, g.skills)) == "Shadowflare", "60% -> 10% in one go: one Shadowflare")
	check(name_of(a._sure_hp_skill(g, g.skills)) != "Shadowflare", "  spends both thresholds")
	var sf
	for s in g.skills:
		if s.skill_name == "Shadowflare": sf = s
	var units = a.TIMELINE_LENGTH - a.cast_zone_start
	var secs = units / (g.speed * a.time_scale * a.battle_speed * sf.cast_speed * g.cast_zone_speed)
	check(secs > 10.5 and secs < 13.5, "cast lasts about 12 s (%.1f s)" % secs)
	g.forced_skill = sf
	g.timeline_pos = a.cast_zone_start
	a._begin_cast(g)
	g.timeline_pos = a.cast_zone_start + 1.0
	# Contained (or full size): it stops, and the rest of the cast gives the
	# slowest party member time to walk out from its middle.
	var slowest = INF
	for m in a.party: slowest = minf(slowest, m.current_move_speed())
	for at in [a.cast_zone_start + 3.0, 97.0]:
		g.timeline_pos = at
		var r = a._cast_radius(g)
		a._settle_growing(g)
		check(is_equal_approx(a._cast_radius(g), r), "stops at its size (%.1f m)" % r)
		var world_secs = a._seconds_until_turn(g) * a.battle_speed
		check(absf(world_secs - (r / slowest + a.flare_run_out_extra)) < 0.05 and world_secs * slowest >= r, "  strikes %.1f s later: time to walk %.1f m out at %.1f m/s" % [world_secs, r, slowest])
		g.timeline_pos += 1.0
		check(is_equal_approx(a._cast_radius(g), r), "  and stays that size")
		g.remove_meta("settled_radius"); g.remove_meta("settle_speed")
	# Grown to full size on its own: it settles before the strike.
	g.timeline_pos = a.TIMELINE_LENGTH - 0.3
	a._update_cast_areas()
	check(g.has_meta("settle_speed"), "full size: it stops and waits for the run-out too")
	print("FAILS: %d" % fails)
	return true
