extends SceneTree
# End screens: the rank (Health / Timing / Reading / Pace, 25 each; S 85,
# A 70, B 50), the Victory panel and its summary page, the Defeat panel and
# its "What went wrong" page with a tip. DEFEAT=1 runs the defeat half.
var a
var t := 0.0
var step := 0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func ids():
	return a.end_screen.choices().map(func(c): return c[0])
func _process(d):
	t += d
	match step:
		0:
			if t < 0.6: return false
			for c in a.combatants: c.hold = true
			var g = a.enemies[0]
			check(is_equal_approx(a.encounter.par_seconds, 150.0), "Round 8's par time: 2:30")
			# The rank's math.
			a.stats = {"perfects": 10, "timed_hits": 20, "timing_misses": 0, "avoidable_hits": 9, "avoidable_hits_you": 2, "parries_too_early": 1}
			var r = a._fight_rank(150.0)
			check(is_equal_approx(r["health"], 25.0) and is_equal_approx(r["timing"], 12.5) and is_equal_approx(r["reading"], 16.0) and is_equal_approx(r["pace"], 25.0), "scores: no damage 25, half Perfects 12.5, 3 of your mistakes 16 (the AI's 7 don't count), on par 25 (%s)" % [r])
			check(r["total"] == 79 and r["letter"] == "A", "79: an A")
			r = a._fight_rank(300.0)
			check(is_equal_approx(r["pace"], 0.0), "twice the par time: no Pace points")
			a.playtest.party["Knight"]["downs"] = 1
			r = a._fight_rank(180.0)
			check(is_equal_approx(r["health"], 15.0), "someone went down: -10 Health")
			a.playtest.party["Knight"]["downs"] = 0
			# Health: HP missing at the end, not all damage taken (heals count).
			a.playtest.party["Knight"]["taken"] = 2000
			var kn0 = a.party[0]
			kn0.hp = kn0.max_hp - 58  # 58 of the party's 580 missing: 10%
			r = a._fight_rank(150.0)
			check(is_equal_approx(r["health"], 22.5), "2,000 damage taken but healed back to 10%% missing: Health 22.5 (%.1f)" % r["health"])
			kn0.hp = kn0.max_hp
			a.playtest.party["Knight"]["taken"] = 0
			a.stats = {"perfects": 20, "timed_hits": 20}
			check(a._fight_rank(170.0)["letter"] == "S", "clean, all Perfects, on time: S")
			if OS.get_environment("DEFEAT") == "1":
				for m in a.party:
					a.playtest.hurt(m, 60, "Stone Golem: Left Golem Smash", g, "Left Golem Smash")
					a.playtest.avoidable(g, "Left Golem Smash")
					m.hp = 0; m._go_down(); a.playtest.down(m)
				a._check_party()
			else:
				g.hp = 0; g._go_down()
				a._check_enemies()
			step = 1; t = 0
		1:
			if a.end_screen == null:
				if t > 5.0:
					check(false, "the end panel shows"); step = 9
				return false
			check(t >= a.end_screen_delay * 0.9, "the panel waits %.1f s after the last blow" % a.end_screen_delay)
			var data = a.end_screen.data
			if OS.get_environment("DEFEAT") == "1":
				check(data["result"] == "defeat" and ids()[0] == "retry", "Defeat: Retry comes first")
				check(ids() == ["retry", "wrong", "party", "report", "menu"], "choices: %s" % [ids()])
				check(not data.has("rank_letter"), "no rank on a defeat")
				var w = data["wrong"]
				check(w["top"][0][0] == "Stone Golem: Left Golem Smash" and w["top"][0][1] == 240 and w["top"][0][2], "what hurt most: Left Golem Smash, 240, AVOIDABLE")
				check(w["downs"].size() == 4 and w["downs"][0][1] == "Stone Golem: Left Golem Smash", "who went down to what")
				check(w["tip"] == "The reveal shows which half: cross to the other side, or Defend.", "the skill's own tip: %s" % w["tip"])
				var g = a.enemies[0]
				check(a._tip_for("Stone Golem: Rock Stomp").contains("Parried"), "no tip of its own: one from its rules (%s)" % a._tip_for("Stone Golem: Rock Stomp"))
				check(a._tip_for("Fell off the arena").contains("edge"), "falls get their own tip")
				check(w["enemies"][0][0] == "Stone Golem", "the Golem's HP left")
				a.end_screen.pick("wrong")
				check(a.end_screen.page == "wrong", "What went wrong opens its page")
			else:
				check(data["result"] == "victory" and ["S", "A", "B", "C"].has(data["rank_letter"]), "Victory with a rank (%s, %d)" % [data["rank_letter"], data["rank_total"]])
				check(ids() == ["next", "summary", "retry", "party", "report", "menu"], "choices: %s" % [ids()])
				check(data["best_rank"] != "", "best rank recorded (%s)" % data["best_rank"])
				check(data["summary"]["party"].size() == 4 and data["summary"]["parts"].size() == 4, "summary: 4 scores, 4 members")
				a.end_screen.pick("summary")
				check(a.end_screen.page == "summary", "Fight summary opens its page")
			var back = InputEventAction.new(); back.action = "cancel"; back.pressed = true
			a.end_screen.handle(back)
			check(a.end_screen.page == "", "back to the panel")
			var down = InputEventAction.new(); down.action = "move_back"; down.pressed = true
			a.end_screen.handle(down)
			check(a.end_screen.index == 1, "S moves the cursor")
			step = 9
		9:
			print("FAILS: %d" % fails)
			quit()
			return true
	return false
