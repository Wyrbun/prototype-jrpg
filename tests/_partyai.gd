extends SceneTree
# Party AI: allies you don't steer play their turns instantly (attacks with
# known Arts, Abilities, Waits), keep AP for the steered fighter, raise max
# AP a little and never reset it. ROUND (default 7) and MODE=classic env.
var a
var t := 0.0
var fails := 0
var min_ap_at_my_turn := INF
var my_turns := 0
var max_ap_seen := 0.0
var ap_dropped_to_100 := false
var round_i := 7
var hidden_test := OS.get_environment("HIDDEN") != ""
var leaked := ""
var art_names: Array = []
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	var r := OS.get_environment("ROUND")
	round_i = int(r) if r != "" else 7
	BattleArena._round_index = round_i
	BattleArena.chosen_for_round = round_i
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	BattleArena.party_ai_override = 1
	BattleArena.windup_override = 0 if OS.get_environment("MODE") == "classic" else 1
	ArtsBook.reset()
	for cls in ["knight", "archer", "mage", "cleric"]:
		for art in Moves.arts(cls): art_names.append(art["name"])
	for n in ([] if hidden_test else ["Double Slash", "Triple Shot", "Fireball", "Judgment"]):
		ArtsBook.discover({"Double Slash": "knight", "Triple Shot": "archer", "Fireball": "mage", "Judgment": "cleric"}[n], n)
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
	Engine.time_scale = 4.0
func _process(d):
	t += d
	if t < 0.5: return false
	max_ap_seen = maxf(max_ap_seen, a.current_max_ap)
	if hidden_test and leaked == "":
		for n in art_names:
			# (an Art named like an enemy skill, the Knight's Smash vs Golem
			# Smash, can't be told apart in text: skip those)
			var clash := false
			for e in a.enemies:
				for sk in e.skills:
					if String(sk.skill_name).contains(n): clash = true
			if not clash and a._flash_message.contains(n):
				leaked = "%s in: %s" % [n, a._flash_message]
	if a.current_max_ap < max_ap_seen - 0.5:
		ap_dropped_to_100 = true
	# The steered Knight: just Wait on its turns (or skip strikes).
	if a._party_turn() and a.active == a.controlled:
		if a._menu_mode == BattleMenu.Mode.COMMANDS:
			my_turns += 1
			min_ap_at_my_turn = minf(min_ap_at_my_turn, a.ap)
			a._wait_command()
		elif a._menu_mode == BattleMenu.Mode.COMBO:
			a._wait_command()  # took over an ally mid-Windup: just let it go
	var done = a._game_over or t > 160.0
	if done:
		Engine.time_scale = 1.0
		var c = a.stats
		print("result: %s | %.0f s | enemies %s | party %s" % [a._result_text if a._game_over else "running", t, a.enemies.map(func(m): return m.hp), a.party.map(func(m): return "%s %d" % [m.class_id, m.hp])])
		print("counts: ai_turns %s, ai_attacks %s, ai_abilities %s, ai_waits %s, arts %s, my turns %d, lowest AP at my turn %.0f, max AP %.0f" % [c.get("ai_turns", 0), c.get("ai_attacks", 0), c.get("ai_abilities", 0), c.get("ai_waits", 0), c.get("arts", 0), my_turns, min_ap_at_my_turn, a.current_max_ap])
		check(int(c.get("ai_attacks", 0)) >= 3, "AI allies attacked")
		var dealt := 0
		for e in a.enemies: dealt += e.max_hp - e.hp
		check(dealt > 0, "enemies took damage (%d)" % dealt)
		check(a.current_max_ap > a.max_ap, "max AP grew (%.0f)" % a.current_max_ap)
		check(my_turns > 0, "the steered Knight still got turns")
		if hidden_test:
			var known := 0
			for cls in ["knight", "archer", "mage", "cleric"]:
				for art in Moves.arts(cls):
					if ArtsBook.known(cls, art["name"]): known += 1
			check(int(c.get("ai_hidden_arts", 0)) > 0, "AI used Arts nobody has found (%d)" % int(c.get("ai_hidden_arts", 0)))
			check(known == 0, "none of them got revealed (%d known)" % known)
			check(leaked == "", "no Art names in messages %s" % leaked)
		print("FAILS: %d" % fails)
		return true
	return false
