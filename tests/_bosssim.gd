extends SceneTree
# Sim (not pass/fail): a boss round played by a full AI party (nobody
# steered), Knight / Archer / Mage / Cleric. R = round index (7 Golem,
# 8 Living Armor, 9 Dragon, 10 Gale Maw), S = seed. Saves the usual
# play-test report and prints its path, plus a one-line BOSSSIM summary.
var a
var t := 0.0
var step := 0
func _initialize():
	var r := int(OS.get_environment("R"))
	BattleArena._round_index = r
	BattleArena.chosen_for_round = r
	BattleArena.party_ai_override = 1
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	match step:
		0:
			if t < 0.6: return false
			seed(int(OS.get_environment("S")))
			Engine.time_scale = 4.0
			a.controlled = null
			# Optional switches: GREY=0, FLANK=0, REACT=<seconds>.
			if OS.get_environment("GREY") == "0": a.ally_avoid_grey = false
			if OS.get_environment("FLANK") == "0": a.ally_fragile_flank = false
			if OS.get_environment("REACT") != "":
				a.ally_react_seconds = float(OS.get_environment("REACT"))
				a.ally_react_unanswerable_seconds = minf(a.ally_react_unanswerable_seconds, a.ally_react_seconds)
			step = 1; t = 0
		1:
			var party_up = a.party.filter(func(m): return not m.is_down).size()
			var boss = a.enemies[0]
			if party_up == 0 or boss.is_down or (a.playtest != null and a.playtest.saved) or t > 900.0:
				if a.playtest != null and not a.playtest.saved:
					a._save_playtest("Victory" if boss.is_down else ("Defeat" if party_up == 0 else "Timeout"))
				print("BOSSSIM r=%s s=%s t=%.0f boss=%d/%d up=%d downs=%s" % [OS.get_environment("R"), OS.get_environment("S"), t, boss.hp, boss.max_hp, party_up, a.party.map(func(m): return "%s:%d" % [m.class_id, m.hp])])
				return true
	return false
