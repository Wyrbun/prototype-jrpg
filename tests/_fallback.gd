extends SceneTree
# Windup: when the grace runs out and the chosen enemy is still out of reach,
# the nearest enemy in reach gets the attack instead (you and AI allies).
var a
var t := 0.0
var step := 0
var fails := 0
var k
var cl
var far_e
var near_e
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 4
	BattleArena.chosen_for_round = 4
	BattleArena.windup_override = 1
	BattleArena.party_ai_override = 1
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func setup(fighter, pos_near):
	for c in a.combatants: c.hold = true
	for e in a.enemies: e.timeline_pos = 0.0
	fighter.set_meta("windup_target", far_e); fighter.set_meta("windup_grace", 0.0)
	fighter.timeline_pos = a.TIMELINE_LENGTH
	fighter.hold = false
	if pos_near: fighter.global_position = near_e.global_position + Vector3(0, 0, near_e.body_radius + 0.9)
	else: fighter.global_position = Vector3(0, fighter.global_position.y, 0) + (far_e.global_position - near_e.global_position).normalized() * -0.0
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			k = a.party[0]; cl = a.party[1]
			var es = a._standing(a.enemies)
			es.sort_custom(func(x, y): return x.global_position.x < y.global_position.x)
			near_e = es[0]; far_e = es[es.size() - 1]
			for e in a.enemies:
				e.stance = Skills.NONE
			far_e.global_position = near_e.global_position + Vector3(14, 0, 0)
			a._keep_in_arena(far_e)
			a._set_controlled(k)
			setup(k, true)
			k.global_position = near_e.global_position + Vector3(0, 0, near_e.body_radius + 0.9)
			step = 1; t = 0
		1:
			k.global_position = near_e.global_position + Vector3(0, 0, near_e.body_radius + 0.9)
			if a._party_turn() or t > 8.0:
				check(a.active == k and a._combo_target == near_e and a._menu_mode == BattleMenu.Mode.COMBO, "you: grace over, far pick out of reach -> combo bar on the nearest in reach (%s)" % [a._combo_target.display_name if a._combo_target else "none"])
				check(a._flash_message.contains("instead"), "  says so: %s" % a._flash_message)
				a._wait_command()
				# AI ally (Cleric): same rule, it attacks the near one at once.
				var hp0 = near_e.hp
				setup(cl, true)
				cl.global_position = near_e.global_position + Vector3(0, 0, -(near_e.body_radius + 0.9))
				a.ap = 150
				step = 2; t = 0
				set_meta("hp0", hp0)
		2:
			cl.global_position = near_e.global_position + Vector3(0, 0, -(near_e.body_radius + 0.9))
			if not cl.has_meta("windup_target") or t > 8.0:
				check(near_e.hp < int(get_meta("hp0")), "AI ally: attacked the nearest in reach (%d -> %d)" % [get_meta("hp0"), near_e.hp])
				# Nobody in reach: still a Wait (TOO FAR).
				setup(k, false)
				k.global_position = near_e.global_position + Vector3(0, 0, 12)
				a._keep_in_arena(k)
				var w = a.stats.get("windup_misses", 0)
				set_meta("w0", w)
				step = 3; t = 0
		3:
			k.global_position = near_e.global_position + Vector3(0, 0, 12)
			if not k.has_meta("windup_target") or t > 8.0:
				check(int(a.stats.get("windup_misses", 0)) == int(get_meta("w0")) + 1 and not a._party_turn(), "nobody in reach: the turn becomes a Wait, as before")
				print("FAILS: %d" % fails)
				return true
	return false
