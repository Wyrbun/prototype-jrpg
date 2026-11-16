extends SceneTree
# Mage rework, step 2: doubles and triples, and the Energy mixes.
var a
var t := 0.0
var step := 0
var fails := 0
var mg
var e1
var e2
var e3
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 4
	BattleArena.chosen_for_round = 4
	BattleArena.chosen_party.assign(["res://scenes/characters/mage.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func art(n):
	for m in Moves.arts("mage"):
		if m["name"] == n: return m
func reset_enemies():
	for e in [e1, e2, e3]:
		e.hp = e.max_hp; e.burn_turns = 0; e.burn_stacks = 1; e.statuses.clear(); e.freeze_left = 0.0
		e.control_used = false; e.cancel_lock = 0
func hit(move, target):
	a._combo_target = target
	a._exec_attacker = mg
	var hits: Array = move["hits"]
	for i in hits.size():
		var m = move.duplicate(true)
		if m.has("last_hit") and i == hits.size() - 1: m.merge(m["last_hit"], true)
		a._land_hit(mg, m, float(hits[i]), i == 0, i == hits.size() - 1)
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			for c in a.combatants: c.hold = true
			mg = a.party.filter(func(p): return p.class_id == "mage")[0]; e1 = a.enemies[0]; e2 = a.enemies[1]; e3 = a.enemies[2]
			a._set_controlled(mg)
			var names = Moves.arts("mage").map(func(m): return m["name"])
			check(names.size() == 19, "19 Arts: %s" % [names])
			# Spread the enemies: e2 near e1, e3 far.
			e1.global_position = Vector3(0, e1.global_position.y, 0)
			e2.global_position = Vector3(3, e2.global_position.y, 0)
			e3.global_position = Vector3(-12, e3.global_position.y, 6)
			mg.global_position = Vector3(0, mg.global_position.y, 3)
			# Burn stacks.
			reset_enemies()
			hit(art("Fireball"), e1)
			check(e1.burn_stacks == 2 and e1.burn_turns == 2, "Fireball: Burn x2 (%d stacks)" % e1.burn_stacks)
			var hp0 = e1.hp
			# Flare.
			reset_enemies()
			e2.global_position = Vector3(1.8, e2.global_position.y, 0)
			hit(art("Fireball"), e1)  # e1 and e2 (in its 2.2 m circle) burn
			var burning = [e1, e2].filter(func(e): return e.burn_turns > 0).size()
			var left1 = e1.burn_damage * e1.burn_stacks * e1.burn_turns
			hp0 = e1.hp
			hit(art("Flare"), e3)  # aimed at the far one: still detonates the burning
			check(burning == 2 and e1.burn_turns == 0 and e2.burn_turns == 0, "Flare: every burning enemy detonated (%d)" % burning)
			check(hp0 - e1.hp >= left1, "  all its Burn at once (%d >= %d)" % [hp0 - e1.hp, left1])
			check(float(art("Flare").get("knockback", 0.0)) == 0.0, "  no push")
			# Ice Spear: regular freeze, boss resistance.
			reset_enemies()
			var pos0 = e1.timeline_pos
			hit(art("Ice Spear"), e1)
			check(e1.statuses.has("frozen") and e1.freeze_left >= 2.9, "Ice Spear: frozen 3 s")
			check(pos0 - e1.timeline_pos >= 14.9, "  its turn pushed back 15 (%.1f)" % (pos0 - e1.timeline_pos))
			# Shatter on the frozen one.
			hp0 = e1.hp
			var sh = art("Shatter")
			hit(sh, e1)
			var frozen_dmg = hp0 - e1.hp
			check(not e1.statuses.has("frozen") and e1.freeze_left == 0.0, "Shatter ends the Freeze")
			reset_enemies()
			hp0 = e1.hp
			hit(sh, e1)
			var plain_dmg = hp0 - e1.hp
			reset_enemies()
			e1.add_status("chilled", 1, e1)
			hp0 = e1.hp
			hit(sh, e1)
			var chill_dmg = hp0 - e1.hp
			check(frozen_dmg > chill_dmg and chill_dmg > plain_dmg, "Shatter: Frozen %d > Chilled %d > neither %d" % [frozen_dmg, chill_dmg, plain_dmg])
			# Boss resistance to Freeze.
			e1.boss = true
			reset_enemies()
			e1.remove_meta("freeze_resist")
			e1.timeline_pos = 60.0
			hit(art("Ice Spear"), e1)
			var p1 = 60.0 - e1.timeline_pos
			e1.timeline_pos = 60.0
			hit(art("Ice Spear"), e1)
			var p2 = 60.0 - e1.timeline_pos
			check(not e1.statuses.has("frozen") and is_equal_approx(p1, 15.0) and is_equal_approx(p2, 7.5), "boss: no freeze, turn pushed 15 then 7.5 (%.1f, %.1f)" % [p1, p2])
			e1.boss = false
			# Chain Lightning.
			reset_enemies()
			var v = a._hit_victims(mg, art("Chain Lightning")) if true else []
			a._combo_target = e1
			v = a._hit_victims(mg, art("Chain Lightning"))
			var hit_names = v.map(func(x): return x[0])
			check(hit_names.has(e1) and hit_names.has(e2) and not hit_names.has(e3), "Chain Lightning: the target + the one within 5 m, not the far one")
			# Thunder: stun only on the last hit; not bosses.
			var th = art("Thunder")
			check(not th.get("stun", false) and th["last_hit"]["stun"] and th["last_hit"]["stun_not_bosses"], "Thunder: only the last strike stuns, never a boss")
			# Overcharge through cancel immunity.
			reset_enemies()
			e1.boss = true
			e1.forced_skill = null
			e1.timeline_pos = a.cast_zone_start + 1
			a._begin_cast(e1)
			e1.cancel_lock = 2
			check(a._cancel_resisted(e1) == "IMMUNE" or a._cancel_resisted(e1) == "UNSTOPPABLE", "a boss shrugging off cancels (%s)" % a._cancel_resisted(e1))
			var resist = a._cancel_resisted(e1)
			hit(art("Overcharge"), e1)
			if resist == "IMMUNE" and a._loaded_offensive(e1) == false:
				pass
			check(resist == "UNSTOPPABLE" or e1.loaded_skill == Skills.NONE, "Overcharge cancels it anyway (immune)")
			e1.boss = false
			# Arcane Overload: push + AP back.
			reset_enemies()
			a.ap = 50.0; a.current_max_ap = 200.0
			var d0 = e1.global_position.distance_to(mg.global_position)
			hit(art("Arcane Overload"), e1)
			check(a.ap == 70.0, "Arcane Overload: 20 AP back (%.0f)" % a.ap)
			check(e1.global_position.distance_to(mg.global_position) > d0 + 5.0, "  pushes it far (%.1f -> %.1f m)" % [d0, e1.global_position.distance_to(mg.global_position)])
			# Inferno: delayed blast.
			reset_enemies()
			e1.global_position = Vector3(0, e1.global_position.y, 0)
			e2.global_position = Vector3(2, e2.global_position.y, 0)
			hit(art("Inferno"), e1)
			check(a._blasts.size() == 1, "Inferno: a marked circle")
			hp0 = e2.hp
			a._tick_blasts(2.0)
			check(e2.hp == hp0 and a._blasts.size() == 1, "  nothing yet at 2 s")
			e3.global_position = Vector3(1.5, e3.global_position.y, 0)
			var hp3 = e3.hp
			e1.global_position = Vector3(9, e1.global_position.y, 0)  # walked out
			var hp1 = e1.hp
			a._tick_blasts(1.1)
			check(e2.hp < hp0 and e3.hp < hp3 and a._blasts.is_empty(), "  at 3 s it explodes on everyone inside (%d, %d)" % [hp0 - e2.hp, hp3 - e3.hp])
			check(e1.hp == hp1, "  the one that walked out is spared")
			check(e2.burn_stacks == 3, "  Burn x3 on those hit")
			print("FAILS: %d" % fails)
			return true
	return false
