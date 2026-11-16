extends SceneTree
# Gale Maw's Gust Sprites: very tough (20% damage) but Lightweight: every hit
# knocks them back (1.5x as far), walls bounce them, a hole or the ledge drops them.
var a
var t := 0.0
var done := false
var fails := 0
func check(c, l):
	print(("ok   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 10
	BattleArena.chosen_for_round = 10
	BattleArena.chosen_party.assign(["res://scenes/characters/mage.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.6 or done: return false
	done = true
	for c in a.combatants: c.hold = true
	var maw = a.enemies[0]
	print("round: ", maw.display_name, " lethal sides ", a.arena.lethal_sides)
	a._summon(maw)
	var sprites: Array = maw.get_meta("summons", [])
	check(sprites.size() > 0, "Gust Sprites summoned (%d)" % sprites.size())
	var s = sprites[0]
	var hp0: int = s.hp
	s.take_damage(100, false)
	check(hp0 - s.hp == 20, "takes 20%% damage (100 -> %d)" % (hp0 - s.hp))
	# Stationary: it never walks back from where it was knocked.
	s.hold = false
	var spot = s.global_position
	for i in 30: a._enemy_step(s, 0.1)
	check(Vector2(s.global_position.x - spot.x, s.global_position.z - spot.z).length() < 0.01, "stationary: it doesn't walk back")
	s.hold = true
	s.take_damage(5000, false)
	check(not s.is_down and s.hp == 1, "unkillable: damage stops at 1 HP (%d)" % s.hp)
	check(s.has_meta("fuse_left") and float(s.get_meta("fuse_left")) == 25.0, "a 25 s fuse starts")
	check(s.status_text().contains("FUSE 25s"), "the fuse shows: %s" % s.status_text())
	# The fuse runs out: Detonate is forced and cast at once.
	s.set_meta("fuse_left", 0.05)
	a._tick_fuses(0.1)
	check(s.forced_skill != null and s.forced_skill.self_destruct and s.timeline_pos >= a.cast_zone_start - 0.02, "fuse out: Detonate comes next (%s)" % [s.forced_skill.skill_name if s.forced_skill else "none"])
	a._begin_cast(s)
	check(s.loaded_def != null and s.loaded_def.skill_name == "Detonate" and s.loaded_def.radius == 4.0, "Detonate: a 4 m circle")
	# It lands (hit or miss): the sprite is gone.
	s.set_meta("detonating", true)
	a._finish_enemy_skill(s, true)
	check(s.is_down and not s.get_meta("fell", false), "it blew itself up")
	a._summon(maw)
	s = maw.get_meta("summons", []).filter(func(x): return not x.is_down)[0]
	hp0 = s.hp
	var mg = a.party[0]
	a._set_controlled(mg)
	var gust; var fire
	for m in Moves.attacks("mage"):
		if m["name"] == "Energy Blast": gust = m
		if m["name"] == "Fire": fire = m
	check(a._move_answer(gust, s)[0] == "PUSHES", "Energy Blast is tagged PUSHES (%s)" % [a._move_answer(gust, s)[0]])
	check(a._move_answer(fire, s)[0] == "PUSHES", "Lightweight: Fire is tagged PUSHES too")
	# Lightweight: any hit knocks it back.
	s.global_position = Vector3(0, s.global_position.y, 0)
	mg.global_position = Vector3(0, mg.global_position.y, 3.0)
	a._combo_target = s; a._exec_attacker = mg
	var fire_hit = fire.duplicate(true)
	fire_hit["burn"] = 0.0
	a._land_hit(mg, fire_hit, 1.0, true, true)
	check(s.global_position.z < -2.0, "Lightweight: a Fire hit knocks it back %.1f m" % -s.global_position.z)
	# Bounces off a wall (not a ledge) instead of sticking to it.
	var bb: Array = a.arena._bounds()
	var wall_side: int = 1 if not (a.arena.lethal_sides & 1) else 2
	if wall_side == 1:
		s.global_position = Vector3(0, s.global_position.y, bb[2] + 1.0)
		a._knock_away(s, s.global_position + Vector3(0.6, 0, 1), 3.0)  # angled into the north wall
		check(not s.is_down and s.global_position.z > bb[2] + 0.5 and s.global_position.x < -1.0,
				"bounces off the wall (%.1f m from it, slid %.1f m along)" % [s.global_position.z - bb[2], -s.global_position.x])
	# Touching a hole: it falls at once.
	var hole := ArenaObstacle.new()
	hole.kind = ArenaObstacle.Kind.HOLE
	hole.radius = 0.8
	a.arena.add_child(hole)
	hole.global_position = Vector3(0, 0, -2.0)
	s.global_position = Vector3(0, s.global_position.y, 0.0)
	a._knock_away(s, Vector3(0, 0, 1.0), 0.6)  # 0.9 m: the rim touches the hole, the middle doesn't reach it
	check(s.is_down and s.get_meta("fell", false), "its rim touches a hole: it falls")
	a.arena.remove_child(hole); hole.free()
	a._summon(maw)
	sprites = maw.get_meta("summons", []).filter(func(x): return not x.is_down)
	s = sprites[0]
	# pushed 1.5x as far
	s.global_position = Vector3(0, s.global_position.y, 0)
	a._knock_away(s, Vector3(-1, 0, 0), 2.0)  # sideways: clear of the Maw's body
	check(absf(s.global_position.x - 3.0) < 0.2, "a 2 m push moves it 3 m (%.1f)" % s.global_position.x)
	# off the ledge
	var side: int = a.arena.lethal_sides
	var b: Array = a.arena._bounds()
	var edge := Vector3.ZERO; var out := Vector3.ZERO
	if side & 1: edge = Vector3(0, 0, b[2] + 1.0); out = Vector3(0, 0, -1)
	elif side & 2: edge = Vector3(b[1] - 1.0, 0, 0); out = Vector3(1, 0, 0)
	elif side & 4: edge = Vector3(0, 0, b[3] - 1.0); out = Vector3(0, 0, 1)
	elif side & 8: edge = Vector3(b[0] + 1.0, 0, 0); out = Vector3(-1, 0, 0)
	check(side != 0, "the Maw's arena has a ledge")
	s.global_position = Vector3(edge.x, s.global_position.y, edge.z)
	a._knock_away(s, s.global_position - out, 3.0)
	check(s.is_down and s.get_meta("fell", false), "pushed off the ledge: gone")
	# Lightweight: no "push it off" recipe box any more (every hit pushes).
	ArtsBook.reset()  # (the test machine's Arts book)
	a._summon(maw)  # the first one fell: a new one
	a._set_controlled(a.party[1])  # the Knight: Smash / Crusader's Edge are Arts
	a._update_arts_list()
	check(a.battle_menu.arts_urgent == "", "no push-recipe box (Lightweight makes it redundant)")
	# Mage has Gust as a basic move: never needs the hint
	check(a._push_recipe(a.party[0]) == "", "the Mage has Gust: no hint needed")
	# every class has a way to push
	for c in ["knight", "archer", "mage", "assassin", "cleric", "monk"]:
		var pushers := []
		for m in Moves.attacks(c) + Moves.arts(c) + Moves.skills(c):
			if float(m.get("knockback", 0.0)) > 0.0: pushers.append(m["name"])
		check(not pushers.is_empty(), "%s can push: %s" % [c, pushers])
	print("FAILS: %d" % fails)
	quit()
	return true
