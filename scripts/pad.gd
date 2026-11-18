class_name Pad
extends Node
## Gamepad (Xbox layout) support that every screen shares. One Pad node sits
## under the tree's root (Keybinds.apply_saved puts it there) and sees input
## before anything else does:
## - It notes whether the pad or the keyboard was used last (Pad.active), so
##   on-screen hints name the right buttons (Keybinds.label / fill).
## - The sticks are read as held directions (walking, turning the camera:
##   the actions' strengths). Menus, which react to presses, would see a
##   stream of them while a stick is held, so stick movements don't reach
##   them; instead each push of the left stick past STICK_PRESS counts as one
##   press of that direction, like a D-pad press.

## How far the left stick must be pushed to count as a press, and let back
## (below STICK_RELEASE) before it counts again.
const STICK_PRESS := 0.6
const STICK_RELEASE := 0.35
## Left stick: [axis, direction, action].
const STICK_ACTIONS := [
	[JOY_AXIS_LEFT_Y, -1.0, "move_forward"],
	[JOY_AXIS_LEFT_Y, 1.0, "move_back"],
	[JOY_AXIS_LEFT_X, -1.0, "move_left"],
	[JOY_AXIS_LEFT_X, 1.0, "move_right"],
]

## True while the pad was the last thing used (keyboard or mouse clicks
## switch it back).
static var active := false
static var _node: Pad

var _pushed := {}  # action -> held past STICK_PRESS


## Puts the Pad node in the tree (once per run).
static func ensure() -> void:
	if is_instance_valid(_node):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_node = Pad.new()
	_node.name = "Pad"
	tree.root.add_child.call_deferred(_node)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.pressed:
			active = true
		return
	if event is InputEventKey or (event is InputEventMouseButton and event.pressed):
		active = false
		return
	if not event is InputEventJoypadMotion:
		return
	var motion := event as InputEventJoypadMotion
	if absf(motion.axis_value) >= STICK_PRESS:
		active = true
	# The stick still steers (the actions' strengths are already updated);
	# the menus get presses instead of the raw movement.
	get_viewport().set_input_as_handled()
	for entry in STICK_ACTIONS:
		if motion.axis != entry[0]:
			continue
		var amount: float = motion.axis_value * float(entry[1])
		var action: String = entry[2]
		if amount >= STICK_PRESS and not _pushed.get(action, false):
			_pushed[action] = true
			_send(action)
		elif amount < STICK_RELEASE:
			_pushed[action] = false


## One press of `action`, for whoever reacts to presses.
func _send(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	get_viewport().push_input.call_deferred(press)


# --- Button names (Xbox) -------------------------------------------------------

const BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_GUIDE: "Xbox", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_STICK: "LS click", JOY_BUTTON_RIGHT_STICK: "RS click",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Up", JOY_BUTTON_DPAD_DOWN: "Down",
	JOY_BUTTON_DPAD_LEFT: "Left", JOY_BUTTON_DPAD_RIGHT: "Right",
	JOY_BUTTON_MISC1: "Share",
}


static func button_name(button: int) -> String:
	return BUTTON_NAMES.get(button, "Button %d" % button)


static func axis_name(axis: int, direction: float) -> String:
	match axis:
		JOY_AXIS_LEFT_X:
			return "LS left" if direction < 0.0 else "LS right"
		JOY_AXIS_LEFT_Y:
			return "LS up" if direction < 0.0 else "LS down"
		JOY_AXIS_RIGHT_X:
			return "RS left" if direction < 0.0 else "RS right"
		JOY_AXIS_RIGHT_Y:
			return "RS up" if direction < 0.0 else "RS down"
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
	return "Axis %d" % axis
