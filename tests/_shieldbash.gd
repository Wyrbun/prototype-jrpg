extends SceneTree
# Knight's Shield Bash is a real charge: a short wind-up, then the Knight
# runs the gap and ends beside the enemy. It used to teleport them there
# in one frame while the animation lunged the body ~4 m further, through
# the enemy, and slid it back.
var a
var t := 0.0
var fails := 0
var kn
var g
var used := false
var start_x := 0.0
var last_x := 0.0
var biggest_jump := 0.0
var run_frames := 0
var backwards := false
var biggest_lead := 0.0
var moved_early := false
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 0
	BattleArena.chosen_for_round = 0
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if not used:
		if t < 1.0: return false
		for c in a.combatants: c.hold = true
		kn = a.party.filter(func(p): return p.class_id == "knight")[0]
		g = a.enemies[0]
		for e in a.enemies: if e != g: e.global_position += Vector3(30, 0, 0)
		g.global_position = Vector3(2.5, g.global_position.y, -3)
		kn.global_position = Vector3(-4.5, kn.global_position.y, -3)
		a._set_controlled(kn)
		var skill = Moves.skills("knight").filter(func(s): return s["name"] == "Shield Bash")[0]
		a.ap = 100.0
		a._use_skill(skill, g, kn.global_position)
		start_x = kn.global_position.x
		last_x = start_x
		check(is_equal_approx(kn.global_position.x, -4.5), "no teleport: still at the start right after the command")
		used = true
		t = 0.0
		return false
	var x: float = kn.global_position.x
	biggest_jump = maxf(biggest_jump, absf(x - last_x))
	if x - last_x > 0.01:
		run_frames += 1
	if x - last_x < -0.01:
		backwards = true
	last_x = x
	if t < a.SHIELD_BASH_WINDUP - 0.02 and absf(x - start_x) > 0.01:
		moved_early = true
	var body: Node3D = kn.get_node("Body")
	biggest_lead = maxf(biggest_lead, body.global_position.x - x)
	if t > 1.0:
		check(not moved_early, "the wind-up happens on the spot")
		var gap: float = kn.global_position.distance_to(g.global_position) - kn.body_radius - g.body_radius
		check(gap > 0.0 and gap < 0.4, "ends beside the enemy (%.2f m)" % gap)
		# 7 m in 0.22 s is fast, but it's a run, not a jump: many frames,
		# all forward (before: the whole way in one frame).
		check(run_frames >= 10 and not backwards and biggest_jump < 1.0, "a run over %d frames, always forward (biggest step %.2f m)" % [run_frames, biggest_jump])
		check(biggest_lead < 0.6, "the body stays with the Knight (leads by %.2f m at most; it went through the enemy before)" % biggest_lead)
		print("FAILS: ", fails)
		quit()
		return true
	return false
