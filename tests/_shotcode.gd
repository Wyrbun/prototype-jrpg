extends SceneTree
# Screenshot: the Mage casting a combo with spell codes on the bar (Ice +
# Fire = Steam Burst, then Lightning), one arrow typed; Focus 3 on the HUD,
# Enchant on the Knight, the AP meter's Focus boost. MODE=list: the move list.
var a
var t := 0.0
var mg
var step := 0
func _initialize():
	BattleArena._round_index = 4
	BattleArena.chosen_for_round = 4
	BattleArena.chosen_party.assign(["res://scenes/characters/mage.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func idx(n):
	for i in a._moves.size():
		if a._moves[i]["name"] == n: return i
func _process(d):
	t += d
	if t < 1.0: return false
	if step == 0:
		step = 1
		for c in a.combatants: c.hold = true
		ArtsBook.discover("mage", "Steam Burst")
		mg = a.party.filter(func(p): return p.class_id == "mage")[0]
		var kn = a.party.filter(func(p): return p.class_id == "knight")[0]
		var e1 = a.enemies[0]
		mg.global_position = e1.global_position + Vector3(0, 0, 4.0)
		mg.set_focus(3)
		kn.add_status("enchant_fire", 2, mg)
		a._set_controlled(mg); a.active = mg; a._command_phase = false
		a.current_max_ap = 200; a.ap = 200
		a._open_combo_bar(e1)
		for n in ["Ice", "Fire", "Lightning"]: a._add_to_combo(idx(n))
		if OS.get_environment("MODE") == "list":
			return false
		a._execute_combo()
		a._exec_lead_in = 0.0
		a._exec_time = a._plan[0]["duration"] * 0.3
		a._judge_code("down")
		return false
	if OS.get_environment("MODE") != "list":
		a._exec_time = a._plan[0]["duration"] * 0.3
	if t < 1.6: return false
	root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
	return true
