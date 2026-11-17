extends SceneTree
# Items: a pouch of 3 Potions, 2 Ethers and 1 Revive every fight; one item
# OR one Ability per turn (the Attack / Wait stay open); Potion 35% HP,
# Ether 40% of max AP, Revive back up at 50% (safe from the cast in
# progress); AI allies use the Revive and Potions by rules, never Ethers.
var a
var t := 0.0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.windup_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func idx(n):
	for i in a._skills.size():
		if a._skills[i]["name"] == n: return i
	return -1
func turn_for(m):
	a._set_controlled(m); a.active = m; a._command_phase = false; a._skill_used = false
	a._open_commands()
func _process(d):
	t += d
	if t < 0.6: return false
	for c in a.combatants: c.hold = true
	var kn = a.party.filter(func(p): return p.class_id == "knight")[0]
	var ar = a.party.filter(func(p): return p.class_id == "archer")[0]
	var mg = a.party.filter(func(p): return p.class_id == "mage")[0]
	var g = a.enemies[0]
	g.global_position = Vector3(0, 0, -5)
	check(a.pouch == {"Potion": 3, "Ether": 2, "Revive": 1}, "the pouch: 3 Potions, 2 Ethers, 1 Revive (%s)" % [a.pouch])
	turn_for(kn)
	check(a.battle_menu.commands[3] == "Items" and a.battle_menu.command_enabled[3], "Items is open in the command menu")
	a._open_items()
	check(a._menu_mode == BattleMenu.Mode.SKILLS and a._skills.size() == 3, "Items opens the pouch list")
	check(not a.battle_menu.move_usable[idx("Potion")] and not a.battle_menu.move_usable[idx("Revive")], "everyone full, nobody down: Potion and Revive greyed out")
	check(a._skills[idx("Potion")]["cost_text"] == "x3", "counts shown instead of AP (x3)")
	# Potion
	ar.hp = 50
	a._open_items()
	check(a.battle_menu.move_usable[idx("Potion")], "someone hurt: Potion usable")
	a._choose_skill(idx("Potion"))
	check(a._menu_mode == BattleMenu.Mode.TARGET, "Potion asks for a target")
	a._use_skill(a._skills[idx("Potion")], ar, kn.global_position)
	check(ar.hp == 50 + ceili(ar.max_hp * 0.35), "Potion heals 35%% of max HP (%d)" % ar.hp)
	check(a.pouch["Potion"] == 2, "one less in the pouch")
	check(a._menu_mode == BattleMenu.Mode.COMMANDS and not a.battle_menu.command_enabled[1] and not a.battle_menu.command_enabled[3], "then Abilities and Items are both used up this turn")
	check(a.battle_menu.command_enabled[2], "Wait still open")
	# Ether
	turn_for(mg)
	a.current_max_ap = 200.0; a.ap = 50.0
	a._open_items()
	a._choose_skill(idx("Ether"))
	check(is_equal_approx(a.ap, 130.0) and a.pouch["Ether"] == 1, "Ether: +40%% of max AP, no target (%.0f)" % a.ap)
	turn_for(mg)
	a.ap = 190.0
	a._open_items(); a._choose_skill(idx("Ether"))
	check(is_equal_approx(a.ap, 200.0), "never past max AP")
	turn_for(mg)
	a._open_items()
	check(not a.battle_menu.move_usable[idx("Ether")], "none left: greyed out")
	# Revive, with a cast in progress
	var stomp = g.skills.filter(func(s): return s.skill_name == "Rock Stomp")[0]
	g.forced_skill = stomp
	g.timeline_pos = a.cast_zone_start + 1.0
	a._begin_cast(g)
	a._reveal_skill(g)
	ar.global_position = g.global_position + Vector3(0, 0, 2.0)
	ar.hp = 0; ar._go_down()
	turn_for(kn)
	a._open_items()
	check(a.battle_menu.move_usable[idx("Revive")], "someone down: Revive usable")
	a._choose_skill(idx("Revive"))
	check(a._target_choices == [ar], "Revive's only choice is the downed Archer")
	a._use_skill(a._skills[idx("Revive")], ar, kn.global_position)
	check(not ar.is_down and ar.hp == ceili(ar.max_hp * 0.5), "back up with 50%% HP (%d)" % ar.hp)
	check(g.attack_range.contains(ar.global_position, ar.body_radius) and not a._strike_targets(g).has(ar), "inside the Stomp, but safe from the cast in progress")
	a._finish_enemy_skill(g, false)
	check(not ar.has_meta("revive_safe"), "that cast over: the next one can hit her")
	check(a.pouch["Revive"] == 0, "the only Revive is spent")
	# A fall: back at the party's start
	a.pouch["Revive"] = 1
	mg.global_position = Vector3(0, 0, 6)
	a._fall(mg)
	turn_for(kn)
	a._use_skill(Items.info("Revive"), mg, kn.global_position)
	check(not mg.is_down and a.arena.walkable(mg.global_position, mg.body_radius) and absf(mg.global_position.y) < 0.01 and mg.visible, "fell off: revived standing on the arena (%s)" % mg.global_position)
	# AI rules
	a.pouch["Revive"] = 1
	ar.hp = 0; ar._go_down()
	a._skill_used = false
	check(a._ai_item(mg) and not ar.is_down, "AI: a downed ally gets the Revive")
	mg.hp = 20
	a.pouch["Potion"] = 2
	check(a._ai_item(mg) and mg.hp > 20 and a.pouch["Potion"] == 1, "AI: under 35% HP and no Cleric: a Potion")
	mg.hp = 60
	check(not a._ai_item(mg), "AI: not low: no item (and never an Ether)")
	print("FAILS: %d" % fails)
	quit()
	return true
