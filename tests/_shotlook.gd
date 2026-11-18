extends SceneTree
# Screenshots of the PS1 look: the Knight figure close up and the battle
# view. OUT = folder. RETRO=0 turns the screen filter off.
var a
var t := 0.0
var step := 0
var cam: Camera3D
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
	match step:
		0:
			if t < 1.2: return false
			for c in a.combatants: c.hold = true
			if OS.get_environment("RETRO") == "0": a.retro_screen.visible = false
			var kn = a.party[0]
			kn.global_position = Vector3(0, 0, 2)
			kn.face_toward(Vector3(1, 0, 1), 1.0, 100000.0)
			shot("look_battle")
			cam = Camera3D.new(); root.add_child(cam)
			cam.global_position = kn.global_position + Vector3(-1.2, 1.5, -2.6)
			cam.look_at(kn.global_position + Vector3(0, 0.9, 0), Vector3.UP)
			cam.make_current()
			step = 1; t = 0
		1:
			if t < 0.3: return false
			shot("look_knight")
			var kn = a.party[0]
			cam.global_position = kn.global_position + Vector3(2.2, 1.3, 1.6)
			cam.look_at(kn.global_position + Vector3(0, 0.9, 0), Vector3.UP)
			step = 2; t = 0
		2:
			if t < 0.3: return false
			shot("look_knight_back")
			quit(); return true
	return false
