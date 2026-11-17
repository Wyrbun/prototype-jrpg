extends SceneTree
# Not a test: records frames of a full-AI boss fight for README GIFs.
# R = round, S = seed, SKIP = seconds fast-forwarded first, DUR = seconds
# recorded, FPS = frames per second saved, FRAMES = folder. HPF = the
# boss's starting HP as a fraction (to reach a phase sooner).
var a
var t := 0.0
var step := 0
var n := 0
var steer := false
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
			a.controlled = null
			if OS.get_environment("HPF") != "":
				a.enemies[0].hp = int(a.enemies[0].max_hp * float(OS.get_environment("HPF")))
			Engine.time_scale = 4.0
			step = 1; t = 0
		1:
			if t < float(OS.get_environment("SKIP")): return false
			Engine.time_scale = 1.0
			step = 2; t = 0
		2:
			var fps := float(OS.get_environment("FPS"))
			if int(t * fps) != int((t - d) * fps):
				root.get_texture().get_image().save_jpg(OS.get_environment("FRAMES") + "/f%04d.jpg" % n, 0.9)
				if n % 12 == 0: print("FRAME %d t=%.1f" % [n, t])
				n += 1
			if t > float(OS.get_environment("DUR")):
				quit(); return true
	return false
