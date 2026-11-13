extends SceneTree
var a
var t := 0.0
var step := 0
var fails := 0
var p0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena.tutorial_mode = false
	BattleArena._round_index = 7  # round 7: full party
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func m(id):
	for x in a.party:
		if x.class_id == id: return x
func _process(d):
	t += d
	if step == 0 and t > 0.3:
		step = 1
		for c in a.combatants: c.timeline_pos = 0; c.hold = true
		# rotate camera 90 degrees with C held
		Input.action_press("camera_right")
	elif step == 1 and t > 0.3 + 0.9:
		Input.action_release("camera_right")
		check(abs(a._cam_yaw + 90.0) < 5.0, "C rotates camera (yaw %.0f)" % a._cam_yaw)
		p0 = a.controlled.global_position
		Input.action_press("move_forward")
		step = 2
	elif step == 2 and t > 1.7:
		Input.action_release("move_forward")
		var moved = a.controlled.global_position - p0
		var fwd = -a.camera.global_basis.z; fwd.y = 0; fwd = fwd.normalized()
		check(moved.normalized().dot(fwd) > 0.95, "W moves away from the camera (dot %.2f, moved %s)" % [moved.normalized().dot(fwd), moved])
		# zoom + reset
		var ev = InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_WHEEL_UP; ev.pressed = true
		Input.parse_input_event(ev)
		step = 3
	elif step == 3 and t > 1.9:
		check(a._cam_distance < 12.0, "wheel zooms in (%.1f)" % a._cam_distance)
		var ev = InputEventAction.new(); ev.action = "camera_reset"; ev.pressed = true
		Input.parse_input_event(ev)
		step = 4
	elif step == 4 and t > 2.1:
		check(abs(a._cam_yaw) < 0.01 and abs(a._cam_distance - 12.0) < 0.01, "V resets camera")
		# handback: steer archer, mage's turn then wait
		a._set_controlled(m("archer"))
		for c in a.combatants: c.hold = false
		a.active = null
		a._start_turn(m("mage"))
		check(a.controlled == m("mage"), "Mage's turn takes control")
		a._wait_command()
		check(a.controlled == m("archer"), "after Mage's turn, back to Archer (%s)" % a.controlled.display_name)
		# back to back: archer steered, cleric then knight turns
		a._start_turn(m("cleric")); a._wait_command(); a._start_turn(m("knight"))
		a.active = m("knight")
		check(a.controlled == m("knight"), "Knight's turn")
		a._wait_command()
		check(a.controlled == m("archer"), "after back-to-back turns, back to Archer (%s)" % a.controlled.display_name)
		# the steered member's own turn keeps control on them
		a._start_turn(m("archer")); a._wait_command()
		check(a.controlled == m("archer"), "own turn: stays on Archer")
		print("FAILS: ", fails)
		return true
	return false
