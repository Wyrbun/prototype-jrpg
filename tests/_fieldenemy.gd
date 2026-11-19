extends SceneTree
# Field enemies (Prologue Stage 2): unaware enemies move only while the
# leader moves, at its pace (Sneak: half); they see in a cone (walls block
# it), notice, chase, touch (caught), give up when outrun and walk back;
# circle enemies only notice running; the field swing gives an ambush from
# behind an unaware enemy, a normal start otherwise; re-entering a room
# brings its enemies back.
var f: FieldScene
var t := 0.0
var step := 0
var fails := 0
var rat: FieldEnemy
var kob: FieldEnemy
var mark := Vector3.ZERO
var mark_face := 0.0
var moved_sneak := 0.0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	FieldScene.fights_on = false  # how fights would start; _fieldfight.gd plays them
	FieldScene.start_room = FieldScene.PROLOGUE_ROOM
	FieldScene.start_entry = FieldScene.PROLOGUE_ENTRY
	FieldScene.start_party = FieldScene.PROLOGUE_PARTY
	f = load(FieldScene.SCENE).instantiate()
	root.add_child(f)
func release_all():
	for a in ["move_forward", "move_back", "move_left", "move_right", "sneak"]:
		Input.action_release(a)
func enemy(n: String) -> FieldEnemy:
	for e in f.enemies:
		if e.name == n: return e
	return null
func wait(seconds: float) -> bool:
	if t < seconds: return true
	t = 0.0
	step += 1
	return false
func _process(d) -> bool:
	t += d
	match step:
		0:
			if wait(0.8): return false
			rat = enemy("Ratkin")
			kob = enemy("KoboldArcher")
			check(rat != null and kob != null and f.enemies.size() == 2, "the hall has a Ratkin and a Kobold Archer")
			check(rat.figure.display_name == "Ratkin Fighter" and not rat.figure.get_node("NameLabel").visible, "they use the fight's figures, no floating names")
			check(rat._points.size() == 2 and rat._points[1].distance_to(Vector3(6, 0, -3.8)) < 0.1, "the Ratkin's patrol points are in room coordinates")
			check(not rat._clear_line(Vector3(-6, 0, -9)), "walls block sight")
			rat._wait = 0.0
			rat._point_i = 1  # on its way to the far end
			kob.look_seconds = 0.5
			mark = rat.global_position
			mark_face = kob.facing
		1:
			if wait(1.0): return false
			check(rat.global_position.distance_to(mark) < 0.01 and is_equal_approx(kob.facing, mark_face), "standing still: unaware enemies freeze")
			f.leader.place(Vector3(-6.5, 0, 4.5), 0.0)
			f.camera.yaw = 0.0
			Input.action_press("sneak")
			Input.action_press("move_right")
		2:
			if t < 0.3: return false  # up to speed
			if step == 2 and mark != Vector3.INF:
				mark = rat.global_position
				mark_face = f.leader.pace
				step = 3
				t = 0.0
		3:
			if wait(1.0): return false
			moved_sneak = rat.global_position.distance_to(mark)
			check(absf(mark_face - 0.5) < 0.08, "Sneak walks at half speed (pace %.2f)" % mark_face)
			Input.action_release("sneak")
		4:
			if t < 0.3: return false
			mark = rat.global_position
			mark_face = f.leader.pace
			step = 5
			t = 0.0
		5:
			if wait(1.0): return false
			release_all()
			var moved_full := rat.global_position.distance_to(mark)
			check(mark_face > 0.95, "full speed: pace 1 (%.2f)" % mark_face)
			check(moved_full > 1.3 and absf(moved_sneak / moved_full - 0.5) < 0.12, "the patrol keeps the leader's pace (%.2f m sneaking, %.2f m walking)" % [moved_sneak, moved_full])
			check(rat.state == FieldEnemy.State.UNAWARE and kob.state == FieldEnemy.State.UNAWARE, "out of sight: nobody noticed")
			check(not is_equal_approx(kob.facing, PI), "the guard looks about while the leader moves (%.2f)" % kob.facing)
			# In front of the Kobold, standing still: seen.
			f.room.reset_enemies()
			f.leader.place(Vector3(6.5, 0, 0.0), 0.0)
		6:
			if t < 0.2: return false
			check(kob.is_aware(), "standing in its cone gets you noticed (even standing still)")
			check(kob._alert.visible, "a \"!\" over it")
			check(rat.state == FieldEnemy.State.UNAWARE, "the other one hasn't seen you")
			step = 7
			t = 0.0
		7:
			if f.last_engagement.is_empty() and t < 4.0: return false
			check(not f.last_engagement.is_empty() and f.last_engagement[0] == kob and f.last_engagement[1] == FieldScene.CAUGHT, "it chases and touches you: caught")
			check(kob.gone, "(until Stage 3) the enemy leaves the room")
			check(f._message.text.contains("knocked down"), "the message says how the fight would start")
			# Seen by the Ratkin, then out of range: it gives up and walks back.
			rat.reset()
			rat.chase_speed = 0.0  # the leader has outrun it
			f.leader.place(Vector3(-1.5, 0, -3.8), 0.0)
			step = 8
			t = 0.0
		8:
			if t < 0.8: return false
			check(rat.state == FieldEnemy.State.CHASE, "the Ratkin chases")
			f.leader.place(Vector3(6.5, 0, 5.0), 0.0)
			step = 9
			t = 0.0
		9:
			if rat.state != FieldEnemy.State.RETURN and t < 4.0: return false
			check(rat.state == FieldEnemy.State.RETURN and t > 2.3, "out of sight for %.1f s: it gives up" % t)
			check(not rat._alert.visible, "the \"!\" goes")
			rat.chase_speed = 4.0
			rat.global_position = Vector3(-3, 0, -3.8)
			Input.action_press("move_left")
			step = 10
			t = 0.0
		10:
			if t > 0.8 and Input.is_action_pressed("move_left"):
				Input.action_release("move_left")
				Input.action_press("move_right")
			elif t > 1.6 and Input.is_action_pressed("move_right"):
				Input.action_release("move_right")
				Input.action_press("move_left")
				t = 0.0
			if rat.state != FieldEnemy.State.UNAWARE and step == 10 and _total(d): return false
			release_all()
			check(rat.state == FieldEnemy.State.UNAWARE and rat.global_position.distance_to(Vector3(-6, 0, -3.8)) < 0.4, "walking back home (at the leader's pace), then on patrol again")
			# Behind the unaware Ratkin: an ambush.
			rat.reset()
			f.leader.place(Vector3(-7.3, 0, -3.8), -PI / 2.0)
			f.swing()
			step = 11
			t = 0.0
		11:
			if wait(0.5): return false
			check(f.last_engagement.size() == 2 and f.last_engagement[0] == rat and f.last_engagement[1] == FieldScene.AMBUSH, "a swing from behind an unaware enemy: an ambush")
			check(f._message.text.contains("50 AP"), "the message says the party would start with 50 AP")
			# Re-entering the room: both are back.
			f.go_to(FieldScene.PROLOGUE_ROOM, "start")
		12:
			if wait(1.2): return false
			check(f.enemies.size() == 2 and not f.enemies[0].gone and not f.enemies[1].gone, "entering the room again brings its enemies back")
			kob = enemy("KoboldArcher")
			# At the Kobold's side, unaware: a normal start.
			f.leader.place(Vector3(5.2, 0, -4.8), -PI / 2.0)
			f.swing()
		13:
			if wait(0.5): return false
			check(f.last_engagement.size() == 2 and f.last_engagement[0] == kob and f.last_engagement[1] == FieldScene.NORMAL, "a swing from the side: a normal start")
			# A swing at nothing does nothing.
			f.last_engagement = []
			f.leader.place(Vector3(0, 0, 2.0), 0.0)
			f.swing()
		14:
			if wait(0.6): return false
			check(f.last_engagement.is_empty(), "a swing at nothing starts nothing")
			f.go_to("res://scenes/field/rooms/test_steps.tscn", "from_hall")
		15:
			if wait(1.2): return false
			var armor := enemy("LivingArmor")
			check(armor != null and armor.sense == FieldEnemy.Sense.CIRCLE, "the Living Armor senses all round")
			f.camera.yaw = 0.0
			f.leader.place(Vector3(-1.6, 0, 6.6), 0.0)
			Input.action_press("sneak")
			Input.action_press("move_forward")
		16:
			if wait(0.8): return false
			var armor := enemy("LivingArmor")
			var dist: float = Vector2(f.leader.global_position.x - armor.global_position.x, f.leader.global_position.z - armor.global_position.z).length()
			check(dist < 3.5 and not armor.is_aware(), "sneaking inside its circle: not noticed (%.1f m)" % dist)
			Input.action_release("sneak")
		17:
			if wait(0.3): return false
			release_all()
			check(enemy("LivingArmor").is_aware() or not f.last_engagement.is_empty(), "running inside it: noticed")
			print("FAILS: ", fails)
			quit()
			return true
	return false
var _waited := 0.0
func _total(d) -> bool:
	_waited += d
	return _waited < 12.0
