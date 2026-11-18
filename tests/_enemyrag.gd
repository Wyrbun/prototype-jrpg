extends SceneTree
# Small enemies ragdoll when beaten: thrown away from the last blow, then
# they sink and are hidden. Bosses keep the old fade. FRAMES=folder saves
# GIF frames.
var a
var t := 0.0
var step := 0
var fails := 0
var ogre
var bandit
var p0
var cam
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 4
	BattleArena.chosen_for_round = 4
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/cleric.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func frame(d):
	if OS.get_environment("FRAMES") != "" and int(t / 0.05) != int((t - d) / 0.05):
		root.get_texture().get_image().save_png(OS.get_environment("FRAMES") + "/%d%04d.png" % [step, int(t / 0.05)])
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			for c in a.combatants: c.hold = true
			ogre = a.enemies.filter(func(e): return e.display_name.begins_with("Ogre"))[0]
			bandit = a.enemies.filter(func(e): return e.display_name.begins_with("Bandit"))[0]
			var kn = a.party[0]
			kn.global_position = Vector3(-1.5, 0, 0)
			ogre.global_position = Vector3(0.2, 0, 0)
			bandit.global_position = Vector3(1.5, 0, 2.5)
			p0 = ogre.global_position
			if OS.get_environment("FRAMES") != "":
				cam = Camera3D.new(); root.add_child(cam); cam.make_current()
				cam.global_position = Vector3(1.5, 3.0, 7.5)
				cam.look_at(Vector3(1.5, 0.6, 0.5), Vector3.UP)
			step = 1; t = 0
		1:
			frame(d)
			if t < 0.4: return false
			# A Smite-strength finisher from the Knight's side
			var kn = a.party[0]
			ogre.set_meta("hit_from", kn.global_position)
			ogre.set_meta("hit_power", 6.0)
			ogre.take_damage(99999, false)
			check(ogre.is_down and ogre.get_node_or_null("Limp") is Ragdoll, "the Ogre goes limp (ragdoll)")
			bandit.take_damage(99999, false)
			check(bandit.get_node_or_null("Limp") is Ragdoll, "the Bandit too (no blow: it crumples)")
			step = 2; t = 0
		2:
			frame(d)
			if t > 0.25 and t - d <= 0.25:
				check(ogre.get_node("Limp").torso.global_position.y > 1.2, "the Ogre is thrown up (%.1f m)" % ogre.get_node("Limp").torso.global_position.y)
			if t < 2.5: return false
			var tp = ogre.get_node("Limp").torso.global_position
			check(tp.x - p0.x > 2.0, "landed %.1f m away from the Knight's blow" % (tp.x - p0.x))
			check(ogre.visible, "still there, lying")
			step = 3; t = 0
		3:
			frame(d)
			if t < 2.0: return false
			check(not ogre.visible and not bandit.visible, "then sunk and hidden")
			print("FAILS: %d" % fails)
			quit()
			return true
	return false
