extends SceneTree
# Doom Gaze vs Windup: an AI ally heading for its Windup target still runs
# to cover first (a log: the Mage and Assassin walked in and both died).
var a
var t := 0.0
var step := 0
var fails := 0
var g
var mg
var asn
var d0 := 0.0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.party_ai_override = 1
	BattleArena.windup_override = 1
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/assassin.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			g = a.enemies[0]; mg = a.party[1]; asn = a.party[2]
			for c in a.combatants:
				c.hold = true
				c.timeline_pos = 10
			for s in g.skills:
				if s.skill_name == "Doom Gaze": g.forced_skill = s
			g.timeline_pos = a.cast_zone_start
			a._begin_cast(g)
			a._reveal_skill(g)
			for m in [mg, asn]:
				m.set_meta("windup_target", g); m.set_meta("windup_grace", 0.0)
			check(a._hide_point(mg) != null, "Doom Gaze: there's a hide point behind the rock")
			d0 = mg.global_position.distance_to(a._hide_point(mg))
			step = 1; t = 0
		1:
			g.timeline_pos = a.cast_zone_start + 1.0  # keep it casting
			if t < 8.0: return false
			for m in [mg, asn]:
				var hp = a._hide_point(m)
				var dist = m.global_position.distance_to(hp)
				check(dist < 1.0, "%s (Windup on the Armor) ran to cover: %.2f m from the hide point" % [m.display_name, dist])
			print("FAILS: %d" % fails)
			return true
	return false
