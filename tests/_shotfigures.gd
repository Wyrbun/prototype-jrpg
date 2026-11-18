extends SceneTree
# Screenshot: all six class figures in a row, from the front (they face
# the enemy behind the camera) and from behind. OUT = folder.
var a
var t := 0.0
var step := 0
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
	match step:
		0:
			if t < 1.2: return false
			for c in a.combatants: c.hold = true
			a.enemies[0].global_position = Vector3(0, 0, -9)
			for i in a.party.size():
				var m = a.party[i]
				m.global_position = Vector3(-3.75 + i * 1.5, 0, 2)
				m.face_toward(Vector3(0, 0, 1), 1.0, 100000.0)
			cam = Camera3D.new(); root.add_child(cam)
			cam.global_position = Vector3(0, 2.0, -3.4)
			cam.look_at(Vector3(0, 0.9, 2), Vector3.UP)
			cam.make_current()
			step = 1; t = 0
		1:
			if t < 0.3: return false
			root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/figures_front.png")
			cam.global_position = Vector3(2.5, 2.0, 7.0)
			cam.look_at(Vector3(0, 0.9, 2), Vector3.UP)
			step = 2; t = 0
		2:
			if t < 0.3: return false
			root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/figures_back.png")
			quit(); return true
	return false
