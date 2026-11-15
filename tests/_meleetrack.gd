extends SceneTree
# Melee tracking: a short cone (Golem Heavy Attack) keeps turning fast at a
# target in melee range through the end of its cast, and steps after it;
# a target far away gets the old slow final turn.
var a
var t := 0.0
var step := 0
var fails := 0
var g
var k
var start_pos
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.windup_override = 1
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func skill(e, nm):
	for s in e.skills:
		if s.skill_name == nm: return s
func setup(dist):
	for c in a.combatants: c.hold = true
	g.hold = false
	g.forced_skill = skill(g, "Heavy Attack")
	g.timeline_pos = a.cast_zone_start
	a._begin_cast(g)
	a._reveal_skill(g)
	g.cast_target = k
	var fwd = g.flat_forward()
	k.global_position = g.global_position + fwd * dist
	k.global_position.y = g.global_position.y
	start_pos = g.global_position
func angle_off():
	var to = k.global_position - g.global_position
	to.y = 0
	return rad_to_deg(g.flat_forward().angle_to(to))
func _process(d):
	t += d
	if g != null and step >= 1:
		g.timeline_pos = a.cast_zone_start  # keep it mid-cast
	match step:
		0:
			if t < 0.8: return false
			g = a.enemies[0]; k = a.party[0]
			a.cast_slow_seconds = 1000.0  # the whole cast counts as its final second
			setup(4.5)
			check(a._melee_tracking(g, k), "Heavy Attack at 4.5 m tracks")
			step = 1; t = 0
		1:
			if t < 0.05: return false
			# Sidestep 90 degrees around the Golem.
			var side = g.flat_forward().cross(Vector3.UP).normalized()
			k.global_position = g.global_position + side * 4.5
			k.global_position.y = g.global_position.y
			step = 2; t = 0
		2:
			if t < 0.5: return false
			check(g.loaded_skill != Skills.NONE, "  still casting")
			check(angle_off() < 15.0, "  0.5 s after a 90° sidestep it faces the target again (%.0f° off)" % angle_off())
			# Back off to the cone's edge: it steps after.
			var away = (k.global_position - g.global_position).normalized()
			k.global_position = g.global_position + away * 5.8
			start_pos = g.global_position
			step = 3; t = 0
		3:
			if t < 0.5: return false
			var moved = (g.global_position - start_pos).length()
			check(moved > 0.5, "  it steps after a target backing off (%.2f m)" % moved)
			a._finish_enemy_skill(g, false)
			g.global_position = Vector3(0, g.global_position.y, 0)
			setup(9.0)
			check(not a._melee_tracking(g, k), "at 9 m: no melee tracking")
			step = 4; t = 0
		4:
			if t < 0.05: return false
			var side = g.flat_forward().cross(Vector3.UP).normalized()
			k.global_position = g.global_position + side * 9.0
			k.global_position.y = g.global_position.y
			start_pos = g.global_position
			step = 5; t = 0
		5:
			if t < 0.5: return false
			check(g.loaded_skill != Skills.NONE, "  still casting")
			check(angle_off() > 60.0, "  far away it still turns slowly (%.0f° off)" % angle_off())
			check((g.global_position - start_pos).length() < 0.01, "  and stands still")
			print("FAILS: %d" % fails)
			return true
	return false
