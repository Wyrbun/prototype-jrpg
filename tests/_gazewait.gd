extends SceneTree
# Doom Gaze: an out-of-reach windup waits in cover instead of becoming a Wait.
# Also: the Living Armor's Shadowflare phase at 50% HP, and boss round speeds.
var a
var t := 0.0
var step := 0
var fails := 0
var k
var g
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.windup_override = 1
	BattleArena.chosen_for_round = 8
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/mage.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func skill(e, nm):
	for s in e.skills:
		if s.skill_name == nm: return s
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			g = a.enemies[0]
			check(g.display_name == "Living Armor", "round 9 is the Living Armor")
			var rush = load("res://data/boss_rush.tres")
			check(is_equal_approx(rush.rounds[7].enemy_speed_mult, 1.7) and is_equal_approx(rush.rounds[8].enemy_speed_mult, 1.5) and is_equal_approx(rush.rounds[9].enemy_speed_mult, 1.5) and is_equal_approx(rush.rounds[10].enemy_speed_mult, 1.5), "boss rounds: Golem x1.7, others x1.5")
			check(a._sure_hp_skill(g, g.skills) == null, "full HP: no forced pick")
			g.hp = int(g.max_hp * 0.49)
			var sure = a._sure_hp_skill(g, g.skills)
			check(sure != null and sure.skill_name == "Shadowflare", "at 49%%: the Shadowflare phase (%s)" % [sure.skill_name if sure else "none"])
			g.hp = g.max_hp
			# Doom Gaze being prepared; the Knight's windup ends far away.
			for c in a.combatants: c.hold = true
			g.forced_skill = skill(g, "Doom Gaze")
			g.timeline_pos = a.cast_zone_start
			a._begin_cast(g)
			check(a._lethal_pending(), "Doom Gaze is pending")
			k = a.party[0]
			k.global_position = g.global_position + Vector3(0, 0, 9.0)
			k.set_meta("windup_target", g); k.set_meta("windup_grace", 0.0)
			k.timeline_pos = a.TIMELINE_LENGTH
			k.hold = false
			a._steer_before_turn = null
			a._set_controlled(a.party[1])
			step = 1; t = 0
		1:
			k.global_position = g.global_position + Vector3(0, 0, 9.0)  # stays in cover
			if t > 4.0:
				check(k.has_meta("windup_target"), "after %.1f s in cover: still winding up (no Wait)" % t)
				check(k.has_meta("windup_sheltering"), "  WAITS IN COVER shown")
				a._finish_enemy_skill(g, false)
				check(not a._lethal_pending(), "gaze over")
				step = 2; t = 0
		2:
			k.global_position = g.global_position + Vector3(0, 0, 9.0)
			if not k.has_meta("windup_target") or t > 6.0:
				check(not k.has_meta("windup_target"), "gaze over, still out of reach: the grace runs out as before")
				print("FAILS: %d" % fails)
				return true
	return false
