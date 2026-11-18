extends SceneTree
# The Gale Maw (wall boss), Defend vs forced movement, Off-Balance edge saves.
var a
var t := 0.0
var done := false
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 10
	BattleArena.chosen_for_round = 10
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
	a.boss_damage_mult = 1.0  # exact skill damage here; _bossdmg.gd tests the boss bonus
func m(id):
	for x in a.party:
		if x.class_id == id: return x
func skill(e, n):
	for s in e.skills:
		if s.skill_name == n: return s
func reset():
	a._edge_save = {}; a._edge_queue.clear()
	for c in a.combatants:
		c.hp = c.max_hp; c.is_down = false; c.shield = 0; c.statuses.clear(); c.hold = true; c.timeline_pos = 10; c.visible = true
		if c.team == 1: a._finish_enemy_skill(c, false)
	a._strike = null; a.active = null
	for r in a.arena.get_children():
		if r is ArenaObstacle and r.kind == ArenaObstacle.Kind.ROCK: r.regrow()
	var i = 0
	for p in a.party:
		p.global_position = Vector3(-8 + i * 1.5, 0, -2); i += 1
func cast(e, n):
	e.forced_skill = skill(e, n); e.timeline_pos = a.cast_zone_start; a._begin_cast(e); a._reveal_skill(e)
func strike(e, reaction := 0):
	a._enemy_unleash(e, false)
	var g = 0
	while a._strike != null and g < 10:
		if reaction != 0: a._strike.reaction = reaction
		a._strike.time_left = 0.0; a._update_strike(0.0); g += 1
func save(result_ok: bool):
	# resolve the pending edge save: Parry in the gold window or not at all
	if a._edge_save.is_empty(): return false
	if result_ok:
		a._edge_save["time_left"] = a.edge_save_window * 0.5; a._edge_save_press()
	a._update_edge_save(2.0)
	return true
func _process(d):
	t += d
	if t < 0.4 or done: return false
	done = true
	var g = a.enemies[0]; var k = m("knight"); var ar = m("archer"); var mg = m("mage")
	# Anchored
	check(is_equal_approx(g.global_position.z, -7.0) and g.flat_forward().dot(Vector3(0, 0, 1)) > 0.99, "Maw on the north wall, facing in (%s)" % g.global_position)
	var p0 = g.global_position
	reset(); g.hold = false
	for i in 30: a._enemy_step(g, 1.0 / 30.0)
	a._knock_away(g, Vector3(0, 0, 5), 4.0)
	check(g.global_position.distance_to(p0) < 0.001 and g.flat_forward().dot(Vector3(0, 0, 1)) > 0.99, "it never moves or turns")
	check(g.is_behind(k.global_position), "no positionals: every side is behind")
	# Exhale: straight away from the wall
	reset(); k.global_position = Vector3(-6, 0, -2); ar.global_position = Vector3(4.4, 0, 2.5)  # Archer behind the east rock
	cast(g, "Exhale"); strike(g)
	check(is_equal_approx(k.global_position.x, -6.0) and absf(k.global_position.z - 5.0) < 0.05, "Exhale pushes the Knight 7 m straight back (%s)" % k.global_position)
	check(ar.hp == ar.max_hp and absf(ar.global_position.z - 2.5) < 0.01, "behind a rock: sheltered (Archer %d)" % ar.hp)
	check(not k.has_meta("knocked") and k.get_node_or_null("Limp") == null, "a 7 m Exhale push doesn't knock the Knight down")
	# Defend halves it (Block class)
	reset(); k.global_position = Vector3(-6, 0, -2); mg.global_position = Vector3(6, 0, -2)
	a.ap = 100; cast(g, "Exhale"); a._enemy_unleash(g, false); a._try_defend()
	check(a._strike != null and a._strike.reaction == 3, "Defend is allowed against an unblockable push")
	a._strike.time_left = 0.0; a._update_strike(0.0)
	check(absf(k.global_position.z - 1.5) < 0.05, "Knight braced: pushed 3.5 m (%s)" % k.global_position)
	check(absf(mg.global_position.z - 5.0) < 0.05, "Mage can't Block: full 7 m (%s)" % mg.global_position)
	# Inhale: straight toward the wall, stopping at its body
	reset(); k.global_position = Vector3(0, 0, -0.5); ar.global_position = Vector3(-8, 0, 2)
	cast(g, "Inhale"); strike(g)
	check(k.gap_to(g) <= 0.25 and k.gap_to(g) >= -0.05, "Inhale drags the Knight up to its face (gap %.2f)" % k.gap_to(g))
	check(is_equal_approx(ar.global_position.x, -8.0) and absf(ar.global_position.z + 2.0) < 0.05, "Archer pulled 4 m straight in (%s)" % ar.global_position)
	check(not k.has_meta("knocked") and not ar.has_meta("knocked"), "Inhale knocks nobody down")
	# Deep Breath: Inhale, then the bite is loaded and shown
	reset(); k.global_position = Vector3(0, 0, 2)
	cast(g, "Deep Breath"); strike(g)
	check(g.loaded_def != null and g.loaded_def.skill_name == "Maw Bite" and g.skill_revealed, "Deep Breath: Maw Bite comes next")
	# Lanes: gaps are safe
	reset(); k.global_position = Vector3(0, 0, 2); ar.global_position = Vector3(-4.4, 0, -1.5)
	cast(g, "Gale Lanes"); strike(g)
	check(k.hp < k.max_hp and ar.hp == ar.max_hp, "Gale Lanes: middle lane hits (K %d), the gap doesn't (A %d)" % [k.hp, ar.hp])
	# Under half HP: Double Gale Lanes hits the gaps first, then the lanes
	reset(); k.global_position = Vector3(0, 0, 2); ar.global_position = Vector3(-4.4, 0, -1.5)
	cast(g, "Double Gale Lanes"); strike(g)
	check(k.hp == k.max_hp and ar.hp < ar.max_hp, "Double Gale Lanes: first the gaps (A hit %d), the middle lane safe (K %d)" % [ar.hp, k.hp])
	check(g.loaded_def != null and g.loaded_def.skill_name == "Gale Lanes" and g.has_meta("follow_up_at"), "  then Gale Lanes on the 3 lanes that were safe")
	check(absf(a._follow_up_seconds(g) - 2.5) < 0.05, "  2.5 s later (%.2f s, even on a fast boss)" % a._follow_up_seconds(g))
	var hp_k = k.hp
	strike(g)
	check(k.hp < hp_k, "  the second wave hits the middle lane (K %d)" % k.hp)
	var lanes1 = skill(g, "Gale Lanes"); var lanes2 = skill(g, "Double Gale Lanes")
	check(lanes1.allowed_at_hp(0.6) and not lanes1.allowed_at_hp(0.4), "Gale Lanes: only at half HP or more")
	check(lanes2.allowed_at_hp(0.4) and not lanes2.allowed_at_hp(0.6), "Double Gale Lanes: only under half HP")
	check(skill(g, "Gale Burst").allowed_at_hp(0.4) and not skill(g, "Gale Burst").allowed_at_hp(0.6) \
			and skill(g, "Gale Draw").allowed_at_hp(0.4) and not skill(g, "Gale Draw").allowed_at_hp(0.6), "Gale Burst / Gale Draw (push or pull + lanes): only under half HP")
	g.forced_skill = null
	g.hp = int(g.max_hp * 0.4)
	var picked := {}
	for i in 200: picked[a._choose_enemy_skill(g).skill_name] = true
	check(not picked.has("Gale Lanes") and picked.has("Double Gale Lanes"), "  under half HP it never picks plain Gale Lanes")
	g.hp = g.max_hp
	for i in 200: picked[a._choose_enemy_skill(g).skill_name] = true
	reset(); cast(g, "Gale Draw"); strike(g)
	check(g.loaded_def != null and g.loaded_def.skill_name == "Double Gale Lanes", "Gale Draw: Inhale, then Double Gale Lanes")
	# Breaker: hugging the wall is safe
	reset(); k.global_position = Vector3(-7, 0, -5); ar.global_position = Vector3(-7, 0, 2)
	cast(g, "Breaker"); strike(g)
	check(k.hp == k.max_hp and ar.hp < ar.max_hp, "Breaker: wall-hugger safe (K %d), far one hit (A %d)" % [k.hp, ar.hp])
	# Wall Sweep: hugging the wall is not
	reset(); k.global_position = Vector3(-7, 0, -5); ar.global_position = Vector3(-7, 0, 2)
	cast(g, "Wall Sweep"); strike(g)
	check(k.hp < k.max_hp and ar.hp == ar.max_hp, "Wall Sweep: wall-hugger hit (K %d)" % k.hp)
	# Edge: pushed over -> save; Off-Balance; next time a fall
	reset(); k.global_position = Vector3(-6, 0, 4); ar.global_position = Vector3(6, 0, 4)
	cast(g, "Exhale"); strike(g)
	check(not a._edge_save.is_empty() and a._edge_queue.size() == 1, "two pushed over: one save at a time, one queued")
	check(save(true) and not k.is_down and k.statuses.has("off_balance"), "first one saved, Off-Balance")
	check(not a._edge_save.is_empty() and a._edge_save["fighter"] == ar, "then the queued one teeters")
	save(false)
	check(ar.is_down, "a missed save is a fall")
	k.global_position = Vector3(-6, 0, 4); k.hold = true; mg.global_position = Vector3(5, 0, -5)
	cast(g, "Exhale"); strike(g)
	check(k.is_down and a._edge_save.is_empty(), "Off-Balance: over the edge again = instant fall")
	# Off-Balance wears off after 3 of their turns, then saves work again
	reset(); k.add_status("off_balance", 3, k)
	for i in 3: k.tick_statuses(k)
	check(not k.statuses.has("off_balance"), "Off-Balance ends after 3 turns")
	k.global_position = Vector3(-6, 0, 4); cast(g, "Exhale"); strike(g)
	check(not a._edge_save.is_empty() and a._edge_save["fighter"] == k, "and the next fall can be saved again")
	save(true)
	# Shadowstep "behind" a wall boss lands at its side, inside the arena
	reset(); ar.global_position = Vector3(3, 0, 0); a._step_behind(ar, g)
	check(ar.global_position.z > -7.0 + 0.1 and absf(ar.global_position.x) > 3.9, "Shadowstep: appears at its side (%s)" % ar.global_position)
	# --- Stronger Maw ---
	# Gale Burst: Exhale, then Double Gale Lanes 1 s later
	reset(); k.global_position = Vector3(0, 0, -2)
	cast(g, "Gale Burst"); strike(g)
	check(g.loaded_def != null and g.loaded_def.skill_name == "Double Gale Lanes" and g.has_meta("follow_up_at"), "Gale Burst: Double Gale Lanes comes next")
	var fu = float(g.get_meta("follow_up_at"))
	check(fu >= a.cast_zone_start and absf(a._follow_up_seconds(g) - 1.0) < 0.05, "1 s later (%.2f s)" % a._follow_up_seconds(g))
	# Breakable rocks
	reset(); ar.global_position = Vector3(4.4, 0, 2.5)
	var rock = null
	for r in a.arena.obstacles():
		if r.global_position.x > 0: rock = r
	cast(g, "Exhale"); strike(g)
	check(ar.hp == ar.max_hp and rock.cracks == 1 and not rock.broken, "first blast: sheltered, the rock cracks")
	ar.global_position = Vector3(4.4, 0, 2.5); cast(g, "Exhale"); strike(g)
	check(ar.hp == ar.max_hp and rock.broken and not a.arena.obstacles().has(rock), "second blast: still sheltered, then the rock shatters")
	ar.global_position = Vector3(4.4, 0, 2.5); ar.hp = ar.max_hp; g.forced_skill = skill(g, "Exhale"); g.timeline_pos = a.cast_zone_start; a._begin_cast(g); a._reveal_skill(g)
	strike(g)
	check(ar.hp < ar.max_hp, "with the rock gone, the blast hits (%d)" % ar.hp)
	a._wall_boss_acts(g)
	check(rock.broken, "still broken after 2 of its actions")
	a._wall_boss_acts(g)
	check(not rock.broken and rock.cracks == 0 and a.arena.obstacles().has(rock), "it grows back after 3 Maw actions")
	# Winded
	reset(); k.global_position = Vector3(-6, 0, -2); k.timeline_pos = 50.0
	cast(g, "Exhale"); strike(g)
	check(absf(k.timeline_pos - 38.0) < 0.01, "pushed: Winded, 12 back on the timeline (%.1f)" % k.timeline_pos)
	reset(); k.global_position = Vector3(-6, 0, 2); k.timeline_pos = 50.0
	cast(g, "Inhale"); strike(g)
	check(absf(k.timeline_pos - 38.0) < 0.01, "pulled: Winded too")
	# Undertow: lines run 3.5 m past; Off-Balance gets two
	reset(); k.global_position = Vector3(0, 0, -1); ar.global_position = Vector3(0, 0, 2); mg.global_position = Vector3(-8, 0, 0)
	cast(g, "Undertow"); strike(g)
	check(ar.hp == ar.max_hp - 36, "a line runs past the Knight into the Archer behind: double (%d)" % (ar.max_hp - ar.hp))
	reset(); mg.global_position = Vector3(-8, 0, 0); k.global_position = Vector3(8, 0, 0); ar.global_position = Vector3(0, 0, 3)
	mg.add_status("off_balance", 3, mg)
	cast(g, "Undertow")
	check(g.extra_areas.size() == 4, "Off-Balance Mage gets two lines (%d lines)" % g.extra_areas.size())
	strike(g)
	check(mg.max_hp - mg.hp == 36 and k.max_hp - k.hp == 18, "two lines: double damage (M %d, K %d)" % [mg.max_hp - mg.hp, k.max_hp - k.hp])
	# Stagger: Exhale becomes Broken Exhale (a ring, safe by the Maw)
	reset(); k.global_position = Vector3(0, 0, -2); ar.global_position = Vector3(-8, 0, 3); mg.global_position = Vector3(8, 0, 3)
	cast(g, "Exhale")
	check(g.stagger_view()["max"] == 90.0, "Exhale: a 90 Stagger bar")
	var smash_art = null
	for x in Moves.arts("knight"):
		if x["name"] == "Smash": smash_art = x
	var hp_before = g.hp
	a._resolve_combo_hit(k, g, smash_art, 7.0)  # 105 x 1.5
	check(g.loaded_def != null and g.loaded_def.skill_name == "Broken Exhale" and g.skill_revealed, "full bar: Exhale becomes Broken Exhale (%s)" % (g.loaded_def.skill_name if g.loaded_def else "none"))
	check(g.statuses.has("staggered") and g.timeline_pos >= a.cast_zone_start, "Staggered, but it still casts (pos %.0f)" % g.timeline_pos)
	g.statuses.clear(); var kz0 = k.global_position.z
	strike(g)
	check(k.hp == k.max_hp and absf(k.global_position.z - kz0) < 0.01, "the Knight by the Maw is in the safe middle")
	check(ar.hp < ar.max_hp and ar.global_position.z > 3.5, "the Archer farther out is still blown back (%s)" % ar.global_position)
	reset(); cast(g, "Gale Burst"); k.global_position = Vector3(0, 0, -2)
	a._resolve_combo_hit(k, g, smash_art, 9.0)
	check(g.loaded_def == null and not g.has_meta("follow_up_at"), "a Staggered Gale Burst breaks outright, no lanes after")
	g.statuses.clear()
	# Crumble at half HP
	reset(); k.global_position = Vector3(0, 0, 5.5); ar.global_position = Vector3(-5, 0, 0)
	check(not a.arena.lethal_at(Vector3(0, 0, 5.5)), "before: solid ground at z 5.5")
	g.hp = g.max_hp / 2; a._check_enemies()
	check(a.arena.lethal_at(Vector3(0, 0, 5.5)) and not a.arena.lethal_at(Vector3(0, 0, 4.3)), "at half HP the south edge crumbles 2.5 m")
	check(not a._edge_save.is_empty() and a._edge_save["fighter"] == k, "the Knight, on the crumbled strip, teeters")
	save(true)
	check(not k.is_down and k.global_position.z < 4.5, "caught: back on solid ground (%s)" % k.global_position)
	g.hp = 10; a._check_enemies()
	check(int(a.stats.get("crumbles", 0)) == 1, "it crumbles only once")
	# Gust Sprites
	reset(); check(g.summon_count == 1, "the Maw calls 1 sprite at a time")
	g.summon_count = 2  # two, to test the top-up
	g.set_meta("acts", 3); a._wall_boss_acts(g)
	var sprites = a.enemies.filter(func(e): return e.display_name == "Gust Sprite")
	check(sprites.size() == 2 and a.combatants.has(sprites[0]), "every 4th action: 2 Gust Sprites join the fight")
	sprites[0].hp = 0; sprites[0]._go_down()
	g.set_meta("acts", 7); a._wall_boss_acts(g)
	var alive = a.enemies.filter(func(e): return e.display_name == "Gust Sprite" and not e.is_down)
	check(alive.size() == 2 and a.enemies.size() == 3, "next summon tops up to 2; the dead one leaves the lists (%d enemies)" % a.enemies.size())
	var sp = alive[0]; sp.global_position = Vector3(0, 0, 0); sp.look_at(Vector3(0, 0, 3)); k.global_position = Vector3(0, 0, 1.5)
	var kz = k.global_position.z
	sp.forced_skill = sp.skills[0]; sp.timeline_pos = a.cast_zone_start; a._begin_cast(sp); a._reveal_skill(sp); strike(sp)
	check(k.global_position.z - kz > 1.9, "Gust knocks back 2 m (%.2f)" % (k.global_position.z - kz))
	g.hp = 0; g._go_down(); a._check_enemies()
	check(a._standing(a.enemies).is_empty() and a._game_over, "the Maw falls: its sprites go with it, victory")
	print("FAILS: %d" % fails); quit(); return true
