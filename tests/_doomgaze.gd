extends SceneTree
# Doom Gaze's area sits on the arena (centred, not turning with the Living
# Armor) and covers all of it; it goes back onto the Armor afterwards.
# Its cover rock drops even when the Armor stands in a corner.
var a
var t := 0.0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.6: return false
	for c in a.combatants: c.hold = true
	var la = a.enemies[0]
	check(la.display_name == "Living Armor", "round: %s" % la.display_name)
	la.global_position = Vector3(4, la.global_position.y, -3)
	la.rotation_degrees.y = 33.0
	var gaze = la.skills.filter(func(s): return s.skill_name == "Doom Gaze")[0]
	la.forced_skill = gaze
	la.timeline_pos = a.cast_zone_start + 1.0
	a._begin_cast(la)
	var r: AttackRange = la.attack_range
	var c: Vector3 = a.arena.global_position
	check(Vector2(r.global_position.x - c.x, r.global_position.z - c.z).length() < 0.01, "centred on the arena")
	la.rotation_degrees.y = 120.0
	check(absf(r.global_rotation.y) < 0.001, "doesn't turn with the Armor")
	var h: Vector2 = a.arena.size / 2.0 - Vector2(0.3, 0.3)
	var corners = [Vector3(h.x, 0, h.y), Vector3(-h.x, 0, h.y), Vector3(h.x, 0, -h.y), Vector3(-h.x, 0, -h.y)].map(func(p): return r.contains(c + p))
	check(corners.all(func(x): return x), "covers every corner of the arena %s" % [corners])
	a._finish_enemy_skill(la, false)
	check(not r.top_level, "back on the Armor afterwards")
	# In a corner there's still a rock to hide behind, with room behind it.
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var half: Vector2 = a.arena.size / 2.0 - Vector2(1.5, 1.5)
		la.global_position = Vector3(c.x + corner.x * half.x, la.global_position.y, c.z + corner.y * half.y)
		la.forced_skill = gaze
		la.timeline_pos = a.cast_zone_start + 1.0
		a._begin_cast(la)
		var rock = la.get_meta("cover_rock") if la.has_meta("cover_rock") else null
		check(rock != null, "Armor in the corner %s: a rock still drops" % corner)
		if rock != null:
			var away: Vector3 = rock.get_meta("hide_dir")
			var hide: Vector3 = rock.global_position + away * (rock.radius + 1.0)
			check(a._inside_arena(Vector3(hide.x, 0, hide.z), 0.5), "  with room to hide behind it")
		a._finish_enemy_skill(la, false)
	print("FAILS: %d" % fails)
	quit()
	return true
