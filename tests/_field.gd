extends SceneTree
# The field (Prologue Stage 1): the leader walks relative to the camera,
# followers keep to the trail behind, walls stop the party, the camera
# turns and resets to the room's angle, doors change rooms (both ways, the
# camera snapping to the new room's angle, the party at the entry), stairs
# take the party up a level, and Esc opens the field's pause menu.
var f: FieldScene
var t := 0.0
var step := 0
var fails := 0
var mark := Vector3.ZERO
var rooms := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	FieldScene.fights_on = false  # movement only (enemies can't start fights here)
	FieldScene.start_room = FieldScene.PROLOGUE_ROOM
	FieldScene.start_entry = FieldScene.PROLOGUE_ENTRY
	FieldScene.start_party = FieldScene.PROLOGUE_PARTY
	f = load(FieldScene.SCENE).instantiate()
	root.add_child(f)
func release_all():
	for a in ["move_forward", "move_back", "move_left", "move_right", "camera_right"]:
		Input.action_release(a)
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
			check(f.room.name == "TestHall", "the Prologue starts in the test hall (%s)" % f.room.name)
			check(f.party.size() == 3 and f.leader.figure.class_id == "knight", "Wyr (Knight) leads, two followers")
			check(f.leader.global_position.distance_to(Vector3(0, 0, 2.2)) < 0.2, "the leader stands on the start entry (%s)" % f.leader.global_position)
			check(f.party[1].global_position.distance_to(Vector3(0, 0, 3.6)) < 0.1 and f.party[2].global_position.distance_to(Vector3(0, 0, 5.0)) < 0.1 and f.party[2].global_position.z > f.party[1].global_position.z, "followers line up behind (%.2f, %.2f)" % [f.party[1].global_position.z, f.party[2].global_position.z])
			check(is_equal_approx(f.camera.yaw, 0.0) and is_equal_approx(f.camera.pitch, 45.0), "the camera is at the room's angle")
			check(not f.leader.figure.get_node("NameLabel").visible, "no floating name on the field")
			check(not f.room.get_node("Geometry/Wall_S0").visible and f.room.get_node("Geometry/Wall_N0").visible, "cutaway: the wall on the camera's side is hidden, the far wall shows")
			mark = f.leader.global_position
			Input.action_press("move_forward")
		1:
			if wait(1.0): return false
			var moved := f.leader.global_position - mark
			check(moved.z < -2.5 and absf(moved.x) < 0.3, "forward walks away from the camera (%s)" % moved)
			check(absf(wrapf(f.leader.facing, -PI, PI)) < 0.2, "the leader faces where it walks (%.2f)" % f.leader.facing)
			var gap: float = f.party[1].global_position.distance_to(f.leader.global_position)
			check(gap > 1.1 and gap < 1.7, "the first follower keeps up, about 1.4 m back (%.2f)" % gap)
			check(f.leader.figure.anim._walk > 0.5, "the walk cycle plays (%.2f)" % f.leader.figure.anim._walk)
			release_all()
			Input.action_press("move_left")
		2:
			if wait(3.0): return false
			check(f.leader.global_position.x > -8.0 and f.leader.global_position.x < -7.0, "the west wall stops the leader (x %.2f)" % f.leader.global_position.x)
			release_all()
			f.party[2].global_position = Vector3(0, -20, 0)
			Input.action_press("camera_right")
		3:
			if wait(0.4): return false
			release_all()
			check(f.party[2].global_position.distance_to(f.leader.global_position) < 2.0, "someone who falls out of the room is put back by the leader")
			check(absf(f.camera.yaw) > 10.0, "the camera turns (yaw %.1f)" % f.camera.yaw)
			var ev := InputEventAction.new()
			ev.action = "camera_reset"
			ev.pressed = true
			Input.parse_input_event(ev)
		4:
			if wait(0.1): return false
			check(is_equal_approx(f.camera.yaw, 0.0), "the reset key goes back to the room's angle")
			f.leader.place(Vector3(0, 0, -4.6), 0.0)
			Input.action_press("move_forward")
		5:
			if f.room.name != "TestSteps" and t < 3.0: return false
			release_all()
			check(f.room.name == "TestSteps", "the north door leads to the test steps")
			t = 0.0
			step += 1
		6:
			if wait(0.6): return false
			check(f.rooms_entered == 2 and not f.changing, "one room change, finished")
			check(is_equal_approx(f.camera.yaw, 25.0) and is_equal_approx(f.camera.pitch, 38.0), "the camera snaps to the new room's angle (%.1f, %.1f)" % [f.camera.yaw, f.camera.pitch])
			check(f.leader.global_position.distance_to(Vector3(0, 0, 6.8)) < 0.3, "the leader arrives on the door's entry (%s)" % f.leader.global_position)
			check(f.party[1].global_position.z > 7.0, "followers arrive behind the leader (%.2f)" % f.party[1].global_position.z)
			check(f.camera.global_position.distance_to(f.camera.focus) > 10.0, "the wall behind the party doesn't pull the camera in (%.1f m)" % f.camera.global_position.distance_to(f.camera.focus))
			check(f.room.get_node("Geometry/StairRamp").visible == false, "the stairs' ramp is invisible")
			f.camera.yaw = 0.0
			f.leader.place(Vector3(-1.75, 0, 1.5), 0.0)
			Input.action_press("move_forward")
		7:
			if wait(2.2): return false
			release_all()
			check(f.leader.global_position.y > 1.3, "the stairs take the party up to the platform (y %.2f)" % f.leader.global_position.y)
			var follower_y: float = f.party[1].global_position.y
			check(follower_y > 0.4, "the first follower climbs too (y %.2f)" % follower_y)
			f.leader.place(Vector3(0, 0, 7.4), PI)
			Input.action_press("move_back")
		8:
			if f.room.name != "TestHall" and t < 3.0: return false
			release_all()
			check(f.room.name == "TestHall", "the south door leads back to the hall")
			t = 0.0
			step += 1
		9:
			if wait(1.5): return false
			check(f.rooms_entered == 3, "arriving doesn't bounce straight back (%d rooms)" % f.rooms_entered)
			check(f.leader.global_position.distance_to(Vector3(0, 0, -4.2)) < 0.3, "the leader arrives inside the north door")
			check(is_equal_approx(f.camera.yaw, 0.0), "the hall's angle again")
			var ev := InputEventAction.new()
			ev.action = "menu"
			ev.pressed = true
			Input.parse_input_event(ev)
		10:
			if wait(0.1): return false
			check(f.pause_menu.visible and paused, "Esc opens the pause menu and pauses")
			check(f.pause_menu.items() == ["Resume", "Options", "Change Keys", "Quit to title"], "the field's rows: %s" % [f.pause_menu.items()])
			f.pause_menu.close()
			check(not paused, "Resume unpauses")
			print("FAILS: ", fails)
			quit()
			return true
	return false
