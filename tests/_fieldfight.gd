extends SceneTree
# Fights on the field (Prologue Stage 3): engaging starts a fight in the
# room (every enemy in it joins, everyone where they stood, the room's
# pillars as obstacles); an ambush starts with 50 AP; winning shows the
# Victory (experience, items) and goes back to the field with the beaten
# enemies gone (until a save point) and HP / the pouch carried over;
# caught: knocked down, enemies ahead, no AP until up; escaping towards a
# door puts the party inside it with the room reset; losing sends the party
# back to the entrance, healed. Soldiers can't be steered yet.
var t := 0.0
var step := 0
var fails := 0
var b: BattleArena
var f: FieldScene
var ap_mark := -1.0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	FieldScene.fights_on = true
	FieldState.new_game(FieldScene.PROLOGUE_PARTY, FieldScene.PROLOGUE_ROOM, FieldScene.PROLOGUE_ENTRY)
	FieldScene.start_room = FieldScene.PROLOGUE_ROOM
	FieldScene.start_entry = FieldScene.PROLOGUE_ENTRY
	change_scene_to_file(FieldScene.SCENE)
func find(type) -> Node:
	for c in root.get_children():
		if is_instance_of(c, type): return c
	return null
func enemy(n: String) -> FieldEnemy:
	for e in f.enemies:
		if e.name == n: return e
	return null
func next():
	step += 1
	t = 0.0
func beat_all(list: Array):
	for c in list:
		if not c.is_down:
			c.take_damage(c.max_hp * 3, false)
	b._check_party()
	b._check_enemies()
func _process(d) -> bool:
	t += d
	if t > 25.0:
		check(false, "step %d timed out" % step)
		print("FAILS: ", fails)
		quit()
		return true
	match step:
		0:
			f = find(FieldScene)
			if f == null or t < 0.6: return false
			var rat := enemy("Ratkin")
			f.leader.place(Vector3(-7.3, 0, -3.8), -PI / 2.0)
			f.swing()
			next()
		1:
			b = find(BattleArena)
			if b == null or t < 0.5: return false
			check(b.field_director != null, "the swing from behind starts a fight (a battle in field mode)")
			check(b.arena.size == Vector2(16, 12) and b.arena.obstacles().size() == 3, "the arena is the hall's floor, its pillars and crate as obstacles")
			check(b.party.size() == 3 and b.enemies.size() == 2, "Wyr and both soldiers vs every enemy in the room (%d)" % b.enemies.size())
			var rat_spot: Vector3 = b.enemies[0].global_position
			check(Vector2(rat_spot.x, rat_spot.z).distance_to(Vector2(-6, -3.8)) < 0.6, "everyone where they stood (Ratkin at %s)" % rat_spot)
			check(is_equal_approx(b.ap, 50.0) or b.ap >= 50.0, "an ambush starts with 50 AP (%.0f)" % b.ap)
			check(b.field_director.room != null and b.field_director.room.get_node_or_null("Enemies") == null, "the room shows round the fight (its own enemies replaced by the fighters)")
			check(not b.pause_menu.items().has("Restart fight"), "no Restart in the pause menu")
			check(b._party_ai_on() and b._steer_locked(), "the soldiers fight on their own and can't be steered yet")
			beat_all(b.enemies)
			next()
		2:
			if b.field_director._panel == null: return false
			var panel: FieldResultPanel = b.field_director._panel
			check(panel.won and panel.experience == 26, "Victory: experience for the Ratkin and the Kobold (%d)" % panel.experience)
			check(panel.drops_text() != "", "items found: %s" % panel.drops_text())
			panel.close()
			next()
		3:
			f = find(FieldScene)
			if f == null or t < 0.6: return false
			check(f.last_fight != null and f.last_fight.outcome == "victory", "back on the field after the win")
			check(f.enemies.is_empty() and FieldState.is_beaten(FieldScene.PROLOGUE_ROOM, "Ratkin"), "the beaten enemies are gone")
			check(FieldState.experience == 26, "experience kept (%d)" % FieldState.experience)
			check(f.room.name == "TestHall", "in the same room")
			f.go_to("res://scenes/field/rooms/test_steps.tscn", "from_hall")
			next()
		4:
			if t < 1.2: return false
			f.go_to(FieldScene.PROLOGUE_ROOM, "from_steps")
			next()
		5:
			if t < 1.2: return false
			check(f.enemies.is_empty(), "leaving and coming back: still gone")
			FieldState.rest(FieldScene.PROLOGUE_ROOM, FieldScene.PROLOGUE_ENTRY)
			f.go_to(FieldScene.PROLOGUE_ROOM, "start")
			next()
		6:
			if t < 1.2: return false
			check(f.enemies.size() == 2, "a save point brings everyone back")
			f.go_to("res://scenes/field/rooms/test_steps.tscn", "from_hall")
			next()
		7:
			if t < 1.2: return false
			# Walk into the Living Armor: caught.
			var armor := enemy("LivingArmor")
			f.leader.place(armor.global_position + Vector3(0.6, 0, 0), 0.0)
			next()
		8:
			b = find(BattleArena)
			if b == null or t < 0.3: return false
			check(b.field_director.fight.how == FieldFight.CAUGHT, "touched: caught")
			check(b.ap == 0.0, "the party starts with 0 AP")
			var ahead := true
			for e in b.enemies:
				if e.timeline_pos < 50.0: ahead = false
			check(ahead, "the enemies start ahead on the timeline")
			next()
		9:
			if t < 0.5: return false
			var knocked := 0
			for m in b.party:
				if m.has_meta("knocked"): knocked += 1
			check(knocked == 3, "everyone in the party is knocked down (%d)" % knocked)
			check(b.ap == 0.0 and not b.field_director.ap_regen_allowed(), "no AP while they're down (%.1f)" % b.ap)
			# Up again (fast-forward), then head for the south door.
			for m in b.party:
				m.set_meta("knocked", 0.01)
			b._cam_yaw = 0.0
			b._place_camera()
			next()
		10:
			if t < 0.2: return false
			check(b.field_director.ap_regen_allowed(), "back up: AP recharges again")
			for i in 21:
				b.field_director.tick_escape(Vector2(0, 1), 0.1)
			check(b.field_director.escaped, "heading for the door for 2 s: escaped")
			next()
		11:
			f = find(FieldScene)
			if f == null or t < 0.6: return false
			check(f.last_fight.outcome == "escaped", "back on the field after escaping")
			check(f.leader.global_position.distance_to(Vector3(0, 0, 7.55)) < 0.4, "the party stands just inside the south door (%s)" % f.leader.global_position)
			check(f.enemies.size() == 2 and f.enemies[0].calm_left > 0.0, "the room reset (both enemies back), calm for a moment")
			var arc := enemy("BanditArcanist")
			check(arc.global_position.distance_to(Vector3(1, 0, 4)) < 0.3, "enemies back where they started")
			# A normal start, then a loss.
			for i in FieldState.hp.size():
				FieldState.hp[i] = 40
			f.engage(arc, FieldFight.NORMAL)
			next()
		12:
			b = find(BattleArena)
			if b == null or t < 0.3: return false
			check(b.ap == 0.0, "a normal start: 0 AP")
			check(b.party[0].hp == 40, "HP carries over into the fight (%d)" % b.party[0].hp)
			beat_all(b.party)
			next()
		13:
			if b.field_director._panel == null: return false
			check(not b.field_director._panel.won, "losing shows the defeat")
			b.field_director._panel.close()
			next()
		14:
			f = find(FieldScene)
			if f == null or t < 0.6: return false
			check(f.room.name == "TestHall" and f.leader.global_position.distance_to(Vector3(0, 0, 2.2)) < 0.3, "back at the dungeon's entrance (no save point yet)")
			check(FieldState.hp.all(func(h): return h == -1), "healed")
			print("FAILS: ", fails)
			quit()
			return true
	return false
