extends SceneTree
# Every move, Ability and Art details box must fit on screen (below the
# timeline bar, full width) at 1600x858. Run with xvfb at that resolution.
var a
var t := 0.0
var fails := 0
var queue: Array = []  # [label, Callable setting the menu up]
var pending := ""
var batch := 0
var checked := 0
var planned := false
const BATCHES := [["knight", "archer", "mage"], ["assassin", "cleric", "monk"]]
func check(c, l):
	if not c: print("FAIL " + l); fails += 1
func _initialize():
	Settings.set_move_details(true)
	_load(0)
func _load(b):
	batch = b
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	var paths: Array[String] = []
	for id in BATCHES[b]: paths.append("res://scenes/characters/%s.tscn" % id)
	BattleArena.chosen_party.assign(paths)
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
	t = 0.0; queue.clear(); planned = false
func _plan():
	for c in a.combatants: c.hold = true
	var g = a.enemies[0]
	for m in a.party:
		for art in Moves.arts(m.class_id): ArtsBook.discover(m.class_id, art["name"])
		queue.append(["", func():
			a._menu_mode = BattleMenu.Mode.HIDDEN
			m.global_position = g.global_position + Vector3(0, 0, 1.5)
			a._set_controlled(m); a.active = m; a.ap = 300; a.current_max_ap = 300
			a._open_combo_bar(g)])
		for i in Moves.attacks(m.class_id).size():
			queue.append(["%s move %d" % [m.class_id, i], func():
				a.battle_menu.arts_focus = false; a.battle_menu.move_index = i])
		for i in Moves.arts(m.class_id).size():
			queue.append(["%s Art %s" % [m.class_id, Moves.arts(m.class_id)[i]["name"]], func():
				if a.battle_menu.arts.size() <= i: return
				a.battle_menu.arts_focus = true; a.battle_menu.arts_index = i])
		queue.append(["", func():
			a.battle_menu.arts_focus = false
			a._menu_mode = BattleMenu.Mode.COMMANDS; a._open_skills()])
		for i in Moves.skills(m.class_id).size():
			queue.append(["%s Ability %s" % [m.class_id, Moves.skills(m.class_id)[i]["name"]], func():
				a.battle_menu.move_index = i])
func _process(d):
	t += d
	if t < 0.6: return false
	if queue.is_empty() and pending == "":
		if not planned: planned = true; _plan(); return false
		if batch + 1 < BATCHES.size():
			a.queue_free(); _load(batch + 1); return false
		print("checked %d boxes" % checked); print("FAILS: %d" % fails); return true
	var bm = a.battle_menu
	if pending != "":
		var r: Rect2 = bm.details_rect
		var vp = root.get_visible_rect().size
		var ok: bool = bm.details_fits and r.position.y >= BattleMenu.ART_DETAILS_TOP - 0.5 and r.position.x >= 0 and r.end.x <= vp.x and r.end.y <= vp.y
		check(ok, "%s cut off (box %s, text %d)" % [pending, r, bm.details_body_size])
		checked += 1
		if ok and bm.details_body_size < 16: print("note: %s shrinks to %d" % [pending, bm.details_body_size])
		pending = ""
	if queue.is_empty(): return false
	var item = queue.pop_front()
	bm.details_rect = Rect2(); bm.details_fits = false
	item[1].call()
	bm.queue_redraw()
	pending = item[0]
	return false
