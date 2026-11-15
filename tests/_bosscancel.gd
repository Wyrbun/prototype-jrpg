extends SceneTree
# Bosses resist cancels: once every 2 of their actions (growing), and their
# signature skills can't be cancelled at all.
var a
var t := 0.0
var done := false
var fails := 0
func check(c, l):
	print(("ok   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func skill(e, n):
	for s in e.skills:
		if s.skill_name == n: return s
func load_skill(e, n):
	e.forced_skill = skill(e, n); e.timeline_pos = a.cast_zone_start + 5; a._begin_cast(e); a._reveal_skill(e)
func _process(d):
	t += d
	if t < 0.6 or done: return false
	done = true
	for c in a.combatants: c.hold = true
	var g = a.enemies[0]
	check(g.cancel_every == 2, "Stone Golem: cancel_every 2")
	load_skill(g, "Rock Stomp")
	check(a._try_cancel(g) and g.loaded_skill == Skills.NONE, "first cancel works")
	check(g.cancel_lock == 1, "then immune for 1 action (%d)" % g.cancel_lock)
	load_skill(g, "Rock Stomp")
	check(not a._try_cancel(g) and g.loaded_skill != Skills.NONE, "IMMUNE right after")
	var stun_move = a._art_named("Crusader's Edge")
	a._set_controlled(a.party[0])
	check(a._move_answer(stun_move, g)[0] == "IMMUNE", "answer tag: IMMUNE (%s)" % [a._move_answer(stun_move, g)[0]])
	a._enemy_unleash(g, true)
	check(g.cancel_lock == 0, "after it acts, cancellable again")
	load_skill(g, "Rock Stomp")
	check(a._try_cancel(g), "second cancel works")
	check(g.cancel_lock == 2, "second cancel: immune for 2 actions (%d)" % g.cancel_lock)
	g.cancel_lock = 0
	load_skill(g, "Right Golem Smash")
	check(not a._try_cancel(g) and g.loaded_skill != Skills.NONE, "Golem Smash: UNSTOPPABLE")
	check(a._move_answer(stun_move, g)[0] == "UNSTOPPABLE", "answer tag: UNSTOPPABLE")
	# Stone Guard: breaking a stance still works
	a._finish_enemy_skill(g, false)
	g.cancel_lock = 3
	load_skill(g, "Stone Guard")
	var k = a.party[0]
	k.global_position = g.global_position + Vector3(0, 0, g.body_radius + 1.0)
	a._resolve_combo_hit(k, g, a._art_named("Smash"), 1.0)
	check(g.stance != Skills.Kind.DEFENSE, "guard break still works while IMMUNE")
	# Training Golem: no limit
	var tg = load("res://scenes/characters/training_golem.tscn").instantiate()
	check(tg.cancel_every == 0, "Training Golem has no cancel limit")
	tg.free()
	print("FAILS: %d" % fails)
	quit()
	return true
