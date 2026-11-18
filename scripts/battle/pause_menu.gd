class_name PauseMenu
extends Control
## Esc during a fight: the whole fight freezes and this menu opens.
## Resume (or Esc / K again), Command List, Options (the screen filter and
## play settings: the same page as on the title screen), Change Keys (as on
## the title screen), Restart fight, or Quit to title. Pressing Esc
## by accident can't throw a fight away any more: quitting has to be chosen.
## (Boss Rush progress saves itself at the start of every fight.)

signal restart_requested
signal quit_requested
## An option changed (the fight re-applies the screen filter).
signal options_changed

const OPTIONS_BACK := "Back"
const RESET_KEYS := "Reset all keys to default"
## Row height on the Change Keys page (many short rows).
const KEY_ROW := 28.0

const GOLD := Color(0.95, 0.78, 0.35)

var index := 0
## True in a Boss Rush: quitting keeps your progress (Continue restarts
## this fight), and the menu says so.
var progress_saved := false
## A line under the title.
var message := ""
var _style: StyleBoxFlat
## The Command List (set up by the fight) and who's in the party.
var command_list: CommandList = null
var party: Array = []
## Showing the Options page instead of the main list.
var in_options := false
## Showing the Change Keys page; _capturing: the row waiting for its new key.
var in_keys := false
var _capturing := -1
var _key_message := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working while the fight is paused
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.06, 0.07, 0.11, 0.95)
	_style.border_color = GOLD
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(6)


func items() -> Array:
	if in_keys:
		var keys: Array = []
		for entry in Keybinds.ACTIONS:
			keys.append(entry[1])
		keys.append_array([RESET_KEYS, OPTIONS_BACK])
		return keys
	if in_options:
		var rows: Array = Settings.option_rows()
		rows.append(OPTIONS_BACK)
		return rows
	return ["Resume", "Command List", "Options", "Change Keys", "Restart fight", "Quit to title"]


func _note(row: int, item: String) -> String:
	if in_options:
		return "Back to the pause menu" if item == OPTIONS_BACK else Settings.option_note(row)
	match item:
		"Resume":
			return "Back to the fight"
		"Command List":
			return "Attacks, Abilities and found Arts, with a preview"
		"Options":
			return "Screen filter, play settings, music and sound volume"
		"Change Keys":
			return "Set your own keys"
		"Restart fight":
			return "Start this fight over"
		"Quit to title":
			return "Progress is saved: Continue starts this fight over" if progress_saved else "Leave the fight (it's lost)"
	return ""


func open() -> void:
	index = 0
	in_options = false
	in_keys = false
	_capturing = -1
	_key_message = ""
	message = ""
	visible = true
	get_tree().paused = true
	Sfx.duck(true)


func close() -> void:
	visible = false
	get_tree().paused = false
	Sfx.duck(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _capturing >= 0:
		_capture_key(event)
		return
	Sfx.menu_keys(event)
	var handled := true
	if event is InputEventMouseMotion:
		var hovered := _row_at(event.position)
		if hovered >= 0:
			index = hovered
		handled = false
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _row_at(event.position)
		if clicked >= 0:
			index = clicked
			_select()
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		index = (index - 1 + items().size()) % items().size()
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		index = (index + 1) % items().size()
	elif event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept"):
		_select()
	elif event.is_action_pressed("menu") or event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		if in_options or in_keys:
			_leave_options()
		else:
			close()
	elif event is InputEventKey:
		pass  # swallow other keys while paused
	else:
		handled = false
	# Choosing Quit / Restart / Start can switch scenes: by then this menu
	# has left the tree and has no viewport.
	if handled and is_inside_tree():
		get_viewport().set_input_as_handled()


func _select() -> void:
	if in_keys:
		var item: String = items()[index]
		if item == OPTIONS_BACK:
			_leave_options()
		elif item == RESET_KEYS:
			Keybinds.reset_defaults()
			_key_message = "All keys are back to their defaults"
		else:
			_capturing = index
			_key_message = ""
		return
	if in_options:
		if items()[index] == OPTIONS_BACK:
			_leave_options()
		else:
			Settings.change_option(index)
			options_changed.emit()
		return
	match items()[index]:
		"Resume":
			close()
		"Command List":
			if command_list:
				visible = false  # the fight stays paused underneath
				command_list.open(party)
		"Options":
			in_options = true
			index = 0
		"Change Keys":
			in_keys = true
			index = 0
			_key_message = ""
		"Restart fight":
			get_tree().paused = false
			Sfx.duck(false)
			restart_requested.emit()
		"Quit to title":
			get_tree().paused = false
			Sfx.duck(false)
			quit_requested.emit()


func _leave_options() -> void:
	var was_keys := in_keys
	in_options = false
	in_keys = false
	_capturing = -1
	index = items().find("Change Keys" if was_keys else "Options")


## Change Keys: the next key pressed becomes the row's new key (a pad
## button: its new pad button). Esc (or the pad's Menu) keeps the old one.
func _capture_key(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_capturing = -1  # a click cancels
		get_viewport().set_input_as_handled()
		return
	var entry: Array = Keybinds.ACTIONS[_capturing]
	if event is InputEventJoypadButton and event.pressed:
		# A pad button: the action's new pad button. Menu keeps the old one.
		get_viewport().set_input_as_handled()
		if Keybinds.reserved_pad(event.button_index):
			_key_message = "Kept %s" % Keybinds.pad_label(entry[0])
		else:
			var swapped_pad := Keybinds.rebind_pad(entry[0], event.button_index)
			_key_message = "%s: %s on the pad" % [entry[1], Keybinds.pad_label(entry[0])]
			if swapped_pad != "":
				_key_message += "   (swapped: %s)" % swapped_pad
		_capturing = -1
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code == KEY_ESCAPE:
		_key_message = "Kept %s" % Keybinds.key_label(entry[0])
	elif Keybinds.reserved(code):
		_key_message = "%s is taken (it opens the play-test reports after a fight)" % OS.get_keycode_string(code)
		return  # still waiting for a key
	else:
		var swapped := Keybinds.rebind(entry[0], code)
		_key_message = "%s: %s" % [entry[1], Keybinds.key_label(entry[0])]
		if swapped != "":
			_key_message += "   (swapped: %s)" % swapped
		Sfx.play("menu_confirm")
	_capturing = -1


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _row_step() -> float:
	return KEY_ROW if in_keys else 52.0


func _panel() -> Rect2:
	var width := 640.0 if in_keys else 560.0
	var height := 96.0 + items().size() * _row_step() + (64.0 if in_keys else 40.0)
	return Rect2((size.x - width) / 2.0, maxf((size.y - height) / 2.0, 4.0), width, height)


func _row(i: int) -> Rect2:
	var panel := _panel()
	return Rect2(panel.position.x + 16.0, panel.position.y + 80.0 + i * _row_step(), panel.size.x - 32.0, _row_step() - 6.0)


func _row_at(point: Vector2) -> int:
	for i in items().size():
		if _row(i).has_point(point):
			return i
	return -1


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var font := ThemeDB.fallback_font
	var panel := _panel()
	HudStyle.draw_panel(self, panel, 0.96)
	var title := "KEYS" if in_keys else ("OPTIONS" if in_options else "PAUSED")
	HudStyle.draw_header(self, Vector2(panel.get_center().x - HudStyle.header_width(title, 36) / 2.0, panel.position.y + 46.0), title, 36, GOLD)
	if message != "":
		_text(font, message, Vector2(panel.get_center().x, panel.position.y + 70.0), 15, Color(0.5, 0.95, 0.55), true)
	var list := items()
	for i in list.size():
		var row := _row(i)
		var selected := i == index
		if selected:
			HudStyle.draw_selection(self, row, GOLD)
		if in_keys:
			if selected:
				_text(font, ">", row.position + Vector2(12, 17), 17, GOLD, false)
			_text(font, list[i], row.position + Vector2(36, 17), 16, Color.WHITE if selected else Color(0.85, 0.85, 0.9), false)
			if i < Keybinds.ACTIONS.size():
				var waiting := i == _capturing
				var action: String = Keybinds.ACTIONS[i][0]
				if waiting:
					_text(font, "press a key or button...", row.position + Vector2(row.size.x - 220.0, 17), 16, Color(0.5, 0.95, 0.55), false)
				else:
					_text(font, Keybinds.key_label(action), row.position + Vector2(row.size.x - 220.0, 17), 16, GOLD, false)
					var pad := Keybinds.pad_label(action)
					_text(font, pad if pad != "" else "-", row.position + Vector2(row.size.x - 110.0, 17), 16, Color(0.6, 0.85, 1.0), false)
			continue
		if selected:
			_text(font, ">", row.position + Vector2(12, 31), 22, GOLD, false)
		_text(font, list[i], row.position + Vector2(40, 22), 22, Color.WHITE if selected else Color(0.85, 0.85, 0.9), false)
		_text(font, _note(i, list[i]), row.position + Vector2(40, 41), 14, Color(0.6, 0.62, 0.7), false)
	var sub := in_options or in_keys
	var hint := Keybinds.fill("{up} / {down}: choose     {confirm} / Enter: %s     Esc / {cancel}: %s" % ["change" if sub else "select", "back" if sub else "resume"])
	if _capturing >= 0:
		hint = "Press the new key or pad button     Esc / Menu: keep the old one"
	_text(font, hint, Vector2(panel.get_center().x, panel.end.y - 16.0), 15, Color(0.6, 0.6, 0.65), true)
	if in_keys and _key_message != "":
		_text(font, _key_message, Vector2(panel.get_center().x, panel.end.y - 40.0), 15, Color(0.5, 0.95, 0.55), true)


func _text(font: Font, text: String, pos: Vector2, font_size: int, color: Color, centered: bool) -> void:
	if centered:
		pos.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
