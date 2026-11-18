extends SceneTree
# Frames of Enchant's motes on the party's weapons (fire, then lightning),
# with the Knight swinging so they trail. FRAMES = folder, FPS = per second.
var a
var t := 0.0
var n := 0
var cam: Camera3D
var started := false
var did := {}
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func once(k):
	if did.has(k): return false
	did[k] = true
	return true
func _process(d):
	t += d
	if t < 1.0: return false
	var at := t - 1.0
	if not started:
		started = true
		for c in a.combatants: c.hold = true
		a.get_node("UI").visible = false
		a.enemies[0].global_position = Vector3(0, 0, -6)
		for i in a.party.size():
			a.party[i].global_position = Vector3(-2.25 + i * 1.5, 0, 2)
		cam = Camera3D.new(); root.add_child(cam); cam.make_current()
		cam.global_position = Vector3(0.6, 2.0, -2.6)
		cam.look_at(Vector3(0, 1.0, 2.0), Vector3.UP)
	for i in a.party.size():
		a.party[i].global_position = Vector3(-2.25 + i * 1.5, 0, 2)  # pinned
		a.party[i].face_toward(Vector3(0, 0, -1), 1.0, 100000.0)
	var mage = a.party[2]
	if at > 0.3 and once("fire"): a._enchant(mage, "fire", 3)
	if at > 1.5 and once("swing"): a.party[0].play_lunge(Moves.attacks("knight")[0], 0, a.enemies[0])
	if at > 2.6 and once("light"): a._enchant(mage, "lightning", 3)
	if at > 3.6 and once("swing2"): a.party[0].play_lunge(Moves.attacks("knight")[0], 0, a.enemies[0])
	if at > 4.6 and once("off"):
		for m in a.party:
			for e in ["fire", "ice", "lightning", "energy"]: m.statuses.erase("enchant_" + e)
	if at > 5.6:
		quit(); return true
	var fps := float(OS.get_environment("FPS"))
	if int(at * fps) != int((at - d) * fps):
		root.get_texture().get_image().save_png(OS.get_environment("FRAMES") + "/f%04d.png" % n)
		n += 1
	return false
