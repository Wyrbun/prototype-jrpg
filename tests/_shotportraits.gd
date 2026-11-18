extends SceneTree
# Screenshots: each class figure close up, front (three-quarter) and back.
# OUT = folder; files portrait_<class>_front/back.png. RETRO=0: no filter.
var a
var t := 0.0
var i := 0
var side := 0
var cam: Camera3D
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn", "res://scenes/characters/assassin.tscn", "res://scenes/characters/monk.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 1.2: return false
	if cam == null:
		for c in a.combatants: c.hold = true
		if OS.get_environment("RETRO") == "0": a.retro_screen.visible = false
		a.enemies[0].global_position = Vector3(0, 0, -9)
		for k in a.party.size():
			a.party[k].global_position = Vector3(-12 + k * 4.0, 0, 3)
		cam = Camera3D.new(); root.add_child(cam); cam.make_current()
		a.controlled = null
		t = 1.2
	if i >= a.party.size():
		quit(); return true
	var m = a.party[i]
	a.get_node("UI").visible = false
	for k in a.party.size():
		a.party[k].visible = (k == i)
	a.enemies[0].visible = false
	m.face_toward(Vector3(0, 0, -1), 1.0, 100000.0)
	var h = 1.9 * Figure.HEIGHTS.get(m.class_id, 1.0)
	var off = Vector3(0.9, 0.0, -1.7) if side == 0 else Vector3(-1.0, 0.1, 1.7)
	cam.global_position = m.global_position + off * (h / 1.9) + Vector3(0, h * 0.55, 0)
	cam.look_at(m.global_position + Vector3(0, h * 0.5, 0), Vector3.UP)
	if t < 1.5: return false
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/portrait_%s_%s.png" % [m.class_id, "front" if side == 0 else "back"])
	t = 1.2
	side += 1
	if side > 1:
		side = 0; i += 1
	return false
