class_name PauseMenu
extends Control
## Esc during a fight: the whole fight freezes and this menu opens.
## Resume (or Esc / K again), Restart fight, or Quit to title. Pressing Esc
## by accident can't throw a fight away any more: quitting has to be chosen.
## (Boss Rush progress saves itself at the start of every fight.)

signal restart_requested
signal quit_requested

const GOLD := Color(0.95, 0.78, 0.35)

var index := 0
## True in a Boss Rush: quitting keeps your progress (Continue restarts
## this fight), and the menu says so.
var progress_saved := false
## A line under the title.
var message := ""
var _style: StyleBoxFlat


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
	return ["Resume", "Restart fight", "Quit to title"]


func _note(item: String) -> String:
	match item:
		"Resume":
			return "Back to the fight"
		"Restart fight":
			return "Start this fight over"
		"Quit to title":
			return "Progress is saved: Continue starts this fight over" if progress_saved else "Leave the fight (it's lost)"
	return ""


func open() -> void:
	index = 0
	message = ""
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
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
		close()
	elif event is InputEventKey:
		pass  # swallow other keys while paused
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _select() -> void:
	match items()[index]:
		"Resume":
			close()
		"Restart fight":
			get_tree().paused = false
			restart_requested.emit()
		"Quit to title":
			get_tree().paused = false
			quit_requested.emit()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _panel() -> Rect2:
	var width := 460.0
	var height := 96.0 + items().size() * 52.0 + 40.0
	return Rect2((size.x - width) / 2.0, (size.y - height) / 2.0, width, height)


func _row(i: int) -> Rect2:
	var panel := _panel()
	return Rect2(panel.position.x + 16.0, panel.position.y + 80.0 + i * 52.0, panel.size.x - 32.0, 46.0)


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
	draw_style_box(_style, panel)
	_text(font, "PAUSED", Vector2(panel.get_center().x, panel.position.y + 46.0), 34, GOLD, true)
	if message != "":
		_text(font, message, Vector2(panel.get_center().x, panel.position.y + 70.0), 15, Color(0.5, 0.95, 0.55), true)
	var list := items()
	for i in list.size():
		var row := _row(i)
		var selected := i == index
		if selected:
			draw_rect(row, Color(GOLD, 0.22))
			_text(font, ">", row.position + Vector2(12, 31), 22, GOLD, false)
		_text(font, list[i], row.position + Vector2(40, 22), 22, Color.WHITE if selected else Color(0.85, 0.85, 0.9), false)
		_text(font, _note(list[i]), row.position + Vector2(40, 41), 14, Color(0.6, 0.62, 0.7), false)
	_text(font, Keybinds.fill("{up} / {down}: choose     {confirm} / Enter: select     Esc / {cancel}: resume"),
			Vector2(panel.get_center().x, panel.end.y - 16.0), 15, Color(0.6, 0.6, 0.65), true)


func _text(font: Font, text: String, pos: Vector2, font_size: int, color: Color, centered: bool) -> void:
	if centered:
		pos.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
