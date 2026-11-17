extends SceneTree
# Screenshots of the end screens. DEFEAT=1 for the defeat side. OUT = folder.
var a
var t := 0.0
var step := 0
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func shot(n):
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/" + n + ".png")
func _process(d):
	t += d
	var defeat = OS.get_environment("DEFEAT") == "1"
	match step:
		0:
			if t < 1.0: return false
			for c in a.combatants: c.hold = true
			var g = a.enemies[0]
			a.stats = {"perfects": 17, "timed_hits": 22, "timing_misses": 1, "avoidable_hits": 2, "parries": 2, "max_ap_peak": 260, "arts_found": 1, "items_potion": 2}
			for m in a.party:
				a.playtest.turns[m.display_name] = 8
				a.playtest.dealt[m.display_name] = 300
			if defeat:
				var src = [["Stone Golem: Left Golem Smash", "Left Golem Smash", 112], ["Stone Golem: Crush", "Crush", 60], ["Stone Golem: Rock Stomp", "Rock Stomp", 30]]
				for m in a.party:
					for s in src:
						a.playtest.hurt(m, s[2], s[0], g, s[1])
					a.playtest.avoidable(g, "Left Golem Smash")
					m.hp = 0; m._go_down(); a.playtest.down(m)
				g.hp = 431
				a._check_party()
			else:
				a.playtest.hurt(a.party[3], 126, "Stone Golem: Crush", g, "Crush")
				a.party[3].hp -= 126
				g.hp = 0; g._go_down()
				a._check_enemies()
			step = 1; t = 0
		1:
			if a.end_screen == null or t < 2.0: return false
			shot("end_defeat" if defeat else "end_victory")
			a.end_screen.pick("wrong" if defeat else "summary")
			step = 2; t = 0
		2:
			if t < 0.5: return false
			shot("end_wrong" if defeat else "end_summary")
			quit()
			return true
	return false
