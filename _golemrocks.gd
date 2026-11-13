extends SceneTree
# Stone Golem: fallen rocks stay; only 2 Ceiling Bursts leave rocks; Golem
# Smash blows up the rocks inside its area (blast circles that hurt).
var a
var t := 0.0
var done := false
var fails := 0
var g
func check(c, l):
	print(("ok   " if c else "FAIL ") + l)
	if not c: fails += 1
func skill(n):
	for s in g.skills:
		if s.skill_name == n: return s
func cast(n):
	a._finish_enemy_skill(g, false)
	g.forced_skill = skill(n)
	g.timeline_pos = a.cast_zone_start + 1.0
	a._begin_cast(g)
	g.timeline_pos = a.cast_zone_start + 20.0
	a._reveal_skill(g)
func share() -> float:
	var n := 0
	for i in 2000:
		var sk = a._choose_enemy_skill(g)
		if sk.skill_name.contains(" + ") and sk.skill_name.contains("Golem Smash"): n += 1
	return n / 2000.0
func burst():
	cast("Ceiling Burst")
	for i in 400:
		a._tick_falls(0.05)
		if not a._falls_pending(g): break
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.6 or done: return false
	done = true
	g = a.enemies[0]
	for c in a.combatants: c.hold = true
	for c in a.party: c.global_position = Vector3(0, 0, 50)  # out of the way (clamped to the edge)
	for c in a.party: a._keep_in_arena(c)
	check(g.max_rock_bursts == 2, "Golem: rocks from 2 bursts at most")
	burst()
	var after1: int = a._debris.size()
	check(after1 > 0, "first burst leaves rocks (%d)" % after1)
	for i in 60: a._tick_falls(1.0)
	check(a._debris.size() == after1, "they stay after a minute (%d)" % a._debris.size())
	burst()
	var after2: int = a._debris.size()
	check(after2 > after1, "second burst adds more (%d)" % after2)
	burst()
	check(a._debris.size() == after2, "third burst: circles fall, no new rocks (%d)" % a._debris.size())
	# Golem Smash: rocks in its half blow up
	cast("Left Golem Smash")
	var blasts: Array = g.get_meta("rock_blasts", [])
	var inside := 0
	for p in a._debris:
		var r: Node3D = p["rock"]
		if g.attack_range.contains(Vector3(r.global_position.x, 0, r.global_position.z), 0.0): inside += 1
	check(blasts.size() == inside and inside > 0, "a blast circle on each rock in its area (%d of %d rocks)" % [blasts.size(), a._debris.size()])
	var cl = a.party[1]
	check(a._ally_dangers(cl).any(func(dd): return dd["area"] == blasts[0]["area"]), "AI allies avoid the blast circles")
	cl.global_position = blasts[0]["area"].global_position + Vector3(0.3, 0, 0)
	cl.hp = cl.max_hp  # the bursts above may have hit it
	var hp0: int = cl.hp
	a._enemy_unleash(g, true)
	check(hp0 - cl.hp >= 30, "standing in a blast: hurt (%d)" % (hp0 - cl.hp))
	check(a._debris.size() == after2 - inside, "the rocks it hit are gone, the rest stay (%d)" % a._debris.size())
	check(g.get_meta("rock_blasts", []).is_empty(), "blast circles cleared")
	# Right + Left Golem Smash: one side, then 1.5 s later the other: every rock goes
	for piece in a._debris.duplicate(): pass
	g.rock_bursts = 0
	burst(); burst()
	var before: int = a._debris.size()
	cl.global_position = Vector3(0, 0, 50); a._keep_in_arena(cl)
	cast("Right + Left Golem Smash")
	check(g.loaded_def.follow_up != null and is_equal_approx(g.loaded_def.follow_up_delay, 1.5), "Right + Left: a Left Golem Smash follows 1.5 s later")
	a._enemy_unleash(g, true)
	for i in 400:
		if a._strike == null: break
		a._update_strike(0.05)
	check(g.loaded_def.skill_name == "Left Golem Smash" and g.skill_revealed, "then the Left Smash is revealed (%s)" % g.loaded_def.skill_name)
	check(is_equal_approx(g.attack_range.rotation.y, deg_to_rad(90.0)), "aimed at the other side")
	var after_first: int = a._debris.size()
	check(after_first < before and g.get_meta("rock_blasts", []).size() == after_first, "first Smash cleared its half (%d -> %d); the rest are marked" % [before, after_first])
	a._enemy_unleash(g, true)
	for i in 400:
		if a._strike == null: break
		a._update_strike(0.05)
	check(a._debris.size() == 0, "after both: no rocks left (%d)" % a._debris.size())
	var names := []
	for sk in g.skills: names.append(sk.skill_name)
	check("Left + Right Golem Smash" in names and "Right + Left Golem Smash" in names, "both orders are in its skill list")
	# Likelier with lots of settled rocks; fresh rocks don't count yet
	a._finish_enemy_skill(g, false); g.forced_skill = null; g.last_skill = null
	cl.global_position = g.global_position + Vector3(0, 0, 3)
	var none := share()
	g.rock_bursts = 0; burst(); burst()
	a._finish_enemy_skill(g, false); g.forced_skill = null; g.last_skill = null
	var fresh := share()
	for piece in a._debris: piece["age"] = 20.0
	var settled := share()
	print("double Smash chance: no rocks %.0f%%, %d fresh rocks %.0f%%, settled %.0f%%" % [none * 100, a._debris.size(), fresh * 100, settled * 100])
	check(settled > fresh * 1.5 and settled > 0.3, "lots of settled rocks: much likelier")
	check(fresh < 0.25, "fresh rocks don't count yet: they get to hinder you first")
	print("FAILS: %d" % fails)
	quit()
	return true
