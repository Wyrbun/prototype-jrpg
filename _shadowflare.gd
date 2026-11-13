extends SceneTree
# Living Armor's Shadowflare: 3 Shadow Sprites circle the growing circle's
# edge; hit each once and it stops growing. Its biggest size reaches the
# arena's corners from the middle, so it can be outrun only when the Armor
# is off to one side.
var a
var t := 0.0
var step := 0
var fails := 0
var g
var k
func check(c, l):
	print(("ok   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func cast():
	for s in g.skills:
		if s.skill_name == "Shadowflare": g.forced_skill = s
	g.timeline_pos = a.cast_zone_start + 1.0
	a._begin_cast(g)
func _process(d):
	t += d
	match step:
		0: if t > 0.6:
			g = a.enemies[0]; k = a.party[0]
			for c in a.combatants: c.hold = true
			g.global_position = Vector3(0, g.global_position.y, 0)
			cast()
			var sprites: Array = g.get_meta("orbiters", [])
			check(sprites.size() == 3, "3 Shadow Sprites")
			check(sprites.all(func(s): return s in a.enemies and s.has_meta("no_timeline")), "they're enemies you can hit, but not on the timeline")
			var r: float = a._cast_radius(g)
			check(sprites.all(func(s): return absf(Vector2(s.global_position.x, s.global_position.z).length() - r) < 0.3), "on the circle's edge (r %.1f)" % r)
			set_meta("a0", sprites[0].get_meta("orbit_angle"))
			step = 1; t = 0
		1: if t > 1.0:
			var sprites: Array = g.get_meta("orbiters", [])
			check(float(sprites[0].get_meta("orbit_angle")) > float(get_meta("a0")), "they circle")
			# growth: max reaches the corners from the middle
			var corner := Vector2(a.arena.size.x / 2.0, a.arena.size.y / 2.0).length()
			var big: float = a._growing_max(g.loaded_def)
			check(absf(big - corner) < 0.01, "biggest size: middle to corner (%.1f m)" % big)
			check(big < a.arena.size.y, "cast from a side's middle, the far edge is out of reach (%.1f < %.1f)" % [big, a.arena.size.y])
			# hit each sprite once
			var slash = Moves.attacks("knight")[0]
			for i in 2:
				a._resolve_combo_hit(k, sprites[i], slash, 1.0)
			a._update_cast_areas()
			check(not g.contained, "two of three hit: still growing")
			a._resolve_combo_hit(k, sprites[2], slash, 1.0)
			check(sprites.all(func(s): return s.is_down), "one hit each puts them down")
			var r0: float = a._cast_radius(g)
			a._update_cast_areas()
			check(g.contained, "all three hit: contained")
			g.timeline_pos += 10.0
			check(absf(a._cast_radius(g) - a._cast_radius(g)) < 0.01 and a._cast_radius(g) <= r0 + 0.3, "and it stops growing")
			a._finish_enemy_skill(g, false)
			check(not sprites.any(func(s): return s in a.enemies), "they leave when it ends")
			print("FAILS: %d" % fails); quit()
	return false
