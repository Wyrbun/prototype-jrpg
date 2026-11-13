extends SceneTree
var a
var t := 0.0
var done := false
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = int(OS.get_environment("R")) if OS.get_environment("R") != "" else 13
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func m(id):
	for x in a.party:
		if x.class_id == id: return x
func en(n):
	for e in a.enemies:
		if e.display_name == n: return e
func reset():
	for c in a.combatants:
		c.hp = c.max_hp; c.is_down = false; c.shield = 0; c.statuses.clear(); c.hold = true; c.timeline_pos = 10
		c.riposte_left = 0
		if c.team == 1: a._finish_enemy_skill(c, false)
	for h in a._hazards.duplicate(): a._remove_hazard(h)
	a._strike = null; a.active = null
	for e in a.enemies: e.global_position = Vector3(-9 + a.enemies.find(e) * 9, 0, -7)
	for p in a.party: p.global_position = Vector3(-10 + a.party.find(p) * 5.5, 0, 8)
func skill(e, n):
	for s in e.skills:
		if s.skill_name == n: return s
func cast(e, n, reveal := true):
	e.forced_skill = skill(e, n)
	e.timeline_pos = a.cast_zone_start
	a._begin_cast(e)
	if reveal: a._reveal_skill(e)
func strike(e, reaction := 0):
	a._enemy_unleash(e, false)
	var guard := 0
	while a._strike != null and guard < 10:
		a._strike.reaction = reaction
		a._strike.time_left = 0.0
		a._update_strike(0.0)
		guard += 1
func face(e, p): e.look_at(Vector3(p.global_position.x, 0, p.global_position.z), Vector3.UP); e.rotate_y(PI)
func _process(d):
	t += d
	if t < 0.3 or done: return false
	done = true
	a.set_process(false)
	if OS.get_environment("R") == "8":
		var sh = en("Orc Shaman"); var k = m("knight"); var ar = m("archer"); var mg = m("mage"); var cl = m("cleric")
		var gob = en("Goblin Fighter A")
		reset(); sh.global_position = Vector3(0, 0, 0); gob.global_position = Vector3(3, 0, 0)
		for x in 200: sh.last_skill = null; var pick = a._choose_enemy_skill(sh); check(pick.skill_name != "Healing Ritual", "") if x == 0 else null
		var heals := 0
		for x in 300:
			sh.last_skill = null
			if a._choose_enemy_skill(sh).skill_name == "Healing Ritual": heals += 1
		check(heals == 0, "nobody hurt: Healing Ritual never picked (%d / 300)" % heals)
		gob.hp = 100; sh.hp = 120; heals = 0
		for x in 300:
			sh.last_skill = null
			if a._choose_enemy_skill(sh).skill_name == "Healing Ritual": heals += 1
		check(heals > 150, "two allies hurt: Healing Ritual is favored (%d / 300)" % heals)
		cast(sh, "Healing Ritual"); strike(sh)
		check(gob.hp == 145 and sh.hp == 170, "Healing Ritual heals 20%% (Goblin %d, Shaman %d)" % [gob.hp, sh.hp])
		# interrupt with 3 close hits (Knight double slash + slash)
		reset(); sh.global_position = Vector3(0, 0, 0); gob.hp = 100; k.global_position = Vector3(0, 0, 1.4)
		cast(sh, "Healing Ritual")
		a._combo_target = sh
		var mv = Moves.attacks("knight")
		a._resolve_combo_hit(k, sh, mv[0], 1.0); a._resolve_combo_hit(k, sh, mv[0], 1.0)
		check(sh.loaded_def != null and sh.interrupt_count == 2, "2 close hits: still casting (2/3)")
		a._resolve_combo_hit(k, sh, mv[0], 1.0)
		check(sh.loaded_def == null, "3rd close hit interrupts the ritual")
		# ranged hits don't count
		reset(); sh.global_position = Vector3(0, 0, 0); ar.global_position = Vector3(0, 0, 6)
		cast(sh, "Healing Ritual")
		for x in 3: a._resolve_combo_hit(ar, sh, Moves.attacks("archer")[0], 1.0)
		check(sh.loaded_def != null, "far-away Archer hits don't interrupt it")
		# Curse: lines to each, overlap double + unblockable
		reset(); sh.global_position = Vector3(0, 0, 0)
		k.global_position = Vector3(0, 0, 3); ar.global_position = Vector3(0, 0, 5)  # same line
		mg.global_position = Vector3(5, 0, 0); cl.global_position = Vector3(-5, 0, 0)
		cast(sh, "Curse", false)
		check(sh.extra_areas.size() == 4, "Curse: a line to each party member")
		a._reveal_skill(sh)
		check(sh.get_meta("telegraphs", []).size() == 4, "spread telegraph spheres for Curse")
		strike(sh, 2)  # everyone tries to Defend
		check(k.hp == 200 - 42, "Knight in 2 lines: double damage, can't be blocked (%d)" % k.hp)
		check(mg.hp > 100 - 21, "Mage in 1 line takes the hit (%d)" % mg.hp)
		print("FAILS: ", fails)
		return true
	var dr = en("Dragon Hatchling"); var la = en("Living Armor"); var k = m("knight"); var ar = m("archer"); var mg = m("mage"); var cl = m("cleric")
	# Breath: alone vs stacked
	reset(); dr.global_position = Vector3(0, 0, 0); k.global_position = Vector3(0, 0, 3)
	dr.look_at(Vector3(0, 0, 3)); cast(dr, "Breath"); strike(dr)
	check(k.hp == 200 - 46, "Breath alone: full 46 (Knight %d)" % k.hp)
	check(a.get_meta("x", 0) == 0, "")
	reset(); dr.global_position = Vector3(0, 0, 0); dr.look_at(Vector3(0, 0, 3))
	k.global_position = Vector3(0, 0, 3); ar.global_position = Vector3(0.9, 0, 3.2); mg.global_position = Vector3(-0.9, 0, 3.2)
	cast(dr, "Breath")
	var arrows = dr.get_meta("telegraphs", [])
	check(arrows.size() == 7 and a._telegraph_arrows.size() == 7, "Breath reveal shows 7 inward arrows")
	strike(dr)
	check(k.hp == 200 - 23 and ar.hp == 150 - 23, "Breath on 3 stacked: 23 each (K %d, A %d)" % [k.hp, ar.hp])
	check(a._telegraph_arrows.is_empty(), "arrows removed after the strike")
	# Fire Wave trail
	reset(); dr.global_position = Vector3(0, 0, -4); dr.look_at(Vector3(0, 0, 3)); k.global_position = Vector3(0, 0, 3)
	cast(dr, "Fire Wave"); strike(dr)
	check(a._hazards.size() == 1, "Fire Wave leaves a burning trail")
	var hp0 = k.hp
	for i in 120: a._tick_hazards(1.0 / 60.0)
	check(k.hp < hp0, "standing in the trail burns (%d -> %d)" % [hp0, k.hp])
	a._start_turn(dr); a._end_turn(); a._start_turn(dr); a._end_turn()
	check(a._hazards.size() == 1, "trail still burning after 2 Dragon turns")
	a._start_turn(dr); a._end_turn()
	check(a._hazards.is_empty(), "trail gone at the 3rd Dragon turn")
	# Burning Spike: stacked -> 1 HP, spread -> damage
	reset(); k.global_position = Vector3(0, 0, 3); ar.global_position = Vector3(1.0, 0, 3)
	cast(dr, "Burning Spike", false)
	check(dr.extra_areas.size() == 4, "Burning Spike: one circle per party member (%d)" % dr.extra_areas.size())
	a._reveal_skill(dr)
	var spheres = dr.get_meta("telegraphs", [])
	check(spheres.size() == 4 and spheres[0].get_parent() is Combatant, "spread telegraph: red sphere over each head")
	strike(dr)
	check(k.hp == 1 and ar.hp == 1, "stacked Knight & Archer drop to 1 HP (K %d, A %d)" % [k.hp, ar.hp])
	check(mg.hp == 100 - 26, "Mage alone takes normal 26 (%d)" % mg.hp)
	# Living Armor combo: 3 hits + launch
	reset(); la.global_position = Vector3(0, 0, 0); la.look_at(Vector3(0, 0, 3)); k.global_position = Vector3(0, 0, 1.9)
	cast(la, "Combo"); var p0 = k.global_position; strike(la)
	check(k.hp == 200 - 48, "Combo: 3 hits of 16 (Knight %d)" % k.hp)
	check(k.global_position.distance_to(p0) > 3.0, "last hit launches the Knight %.1f m" % k.global_position.distance_to(p0))
	reset(); la.global_position = Vector3(0, 0, 0); la.look_at(Vector3(0, 0, 3)); k.global_position = Vector3(0, 0, 1.9)
	cast(la, "Combo"); a._enemy_unleash(la, false); a._strike.time_left = 0; a._update_strike(0)  # hit 1 lands
	a._strike.reaction = 1; a._strike.time_left = 0; a._update_strike(0)  # parry hit 2
	check(k.hp == 200 - 16, "Parry on hit 2: no damage from it (Knight %d)" % k.hp)
	# Dark Bolt overlap double
	reset(); k.global_position = Vector3(0, 0, 3); ar.global_position = Vector3(1.2, 0, 3)
	cast(la, "Dark Bolt"); strike(la)
	check(k.hp == 200 - 36 and mg.hp == 100 - 18, "Dark Bolt: overlap 36, alone 18 (K %d, M %d)" % [k.hp, mg.hp])
	# Shadowflare grows / contained
	reset(); la.global_position = Vector3(0, 0, 0); cast(la, "Shadowflare", false)
	var r0 = la.attack_range.radius
	la.timeline_pos = 95; a._update_cast_areas()
	check(la.attack_range.radius > r0 + 4.0, "Shadowflare grows (%.1f -> %.1f)" % [r0, la.attack_range.radius])
	reset(); la.global_position = Vector3(0, 0, 0); cast(la, "Shadowflare", false)
	la.timeline_pos = a.cast_zone_start + 5; a._update_cast_areas(); la.take_damage(90, false); a._update_cast_areas()
	check(not la.contained, "damage to the Armor no longer contains it (the Shadow Sprites do)")
	for sprite in la.get_meta("orbiters", []):
		sprite.take_damage(1, false)
	a._update_cast_areas()
	var rc = la.attack_range.radius; la.timeline_pos = 99; a._update_cast_areas()
	check(la.contained and absf(la.attack_range.radius - rc) < 0.01, "hitting all 3 Shadow Sprites contains it: stops at %.1f m" % rc)
	print("FAILS: ", fails)
	return true
