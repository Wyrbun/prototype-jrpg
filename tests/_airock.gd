extends SceneTree
# Party AI: a ranged ally whose shot is blocked by a fallen rock walks round
# it during the Windup grace and attacks, instead of TOO FAR.
var a
var t := 0.0
var step := 0
var fails := 0
var ar
var g
var misses0 := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.windup_override = 1
	BattleArena.party_ai_override = 1
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			for c in a.combatants: c.hold = true
			g = a.enemies[0]; ar = a.party[1]
			a.party[0].global_position = g.global_position + Vector3(9, 0, -6)
			var dir := Vector3(0, 0, 1)
			var gap: float = minf(ar.reach() * 0.75, 7.0)
			ar.global_position = g.global_position + dir * (g.body_radius + ar.body_radius + gap)
			var rock := ArenaObstacle.new()
			rock.kind = ArenaObstacle.Kind.ROCK
			rock.radius = 1.2
			a.arena.add_child(rock)
			rock.global_position = Vector3(g.global_position.x, 0.0, g.global_position.z) + dir * (g.body_radius + 0.4 + gap * 0.5)
			check(ar.gap_to(g) <= ar.reach() and not a._windup_reaches(ar, g), "in range but the rock blocks the shot")
			misses0 = int(a.stats.get("windup_misses", 0))
			ar.set_meta("windup_target", g); ar.set_meta("windup_grace", 0.0)
			ar.timeline_pos = a.TIMELINE_LENGTH
			ar.hold = false
			step = 1; t = 0
		1:
			if not ar.has_meta("windup_target") or t > 10.0:
				check(int(a.stats.get("windup_misses", 0)) == misses0 and int(a.stats.get("ai_attacks_archer", 0)) == 1, "walked round the rock and attacked (%.1f s)" % t)
				print("FAILS: %d" % fails)
				return true
	return false
