class_name PartyPicker
extends Control
## Before a boss round (Round 6 onward): choose who fights, 1 to 4 of the
## six classes. Going solo is allowed. The fight is paused behind it.
##
## Keys: up / down to move, Confirm to tick a class or start, Cancel / Esc to
## go back to the title screen. The mouse works too.

signal chosen(scene_paths: Array[String])
signal back_requested

const GOLD := Color(0.95, 0.78, 0.35)
const MAX_PARTY := 4
## [scene path, one-line role] for every class, in menu order.
const CLASSES := [
	["res://scenes/characters/knight.tscn", "The tank: Taunt guards allies near them, Brace, most HP"],
	["res://scenes/characters/archer.tscn", "Ranged: Power Draw (Hold), Exposing Shot, Riposte"],
	["res://scenes/characters/mage.tscn", "Fire, Frost, Gust area spells (Tap), Concentrate"],
	["res://scenes/characters/cleric.tscn", "Healer: Healing, Shielding, Full Cure, Bash"],
	["res://scenes/characters/assassin.tscn", "Strikes from behind, Marks, auto-parry with Marks"],
	["res://scenes/characters/monk.tscn", "Climbs his bar with Arts, then cashes out; tanks with Provoke"],
]

var round_title := ""
var index := 0
var picked: Array[bool] = []
## Ticked classes in the order they were ticked: the party comes out in this
## order (the first one starts under your control).
var order: Array[int] = []
var _names: Array[String] = []
var _hp: Array[int] = []
var _colors: Array[Color] = []
var _message := ""
var _style: StyleBoxFlat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS  # works while the fight is paused
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.06, 0.07, 0.11, 0.95)
	_style.border_color = GOLD
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(6)
	for entry in CLASSES:
		var fighter := (load(entry[0]) as PackedScene).instantiate() as Combatant
		_names.append(fighter.display_name)
		_hp.append(fighter.max_hp)
		var body := fighter.get_node_or_null("Body") as MeshInstance3D
		var colour := Color.GRAY
		if body and body.get_surface_override_material(0) is StandardMaterial3D:
			colour = (body.get_surface_override_material(0) as StandardMaterial3D).albedo_color
		_colors.append(colour)
		fighter.free()


## Opens with these classes ticked (scene paths: the round's usual party, or
## the last pick).
func open(title: String, ticked: Array) -> void:
	round_title = title
	picked.clear()
	order.clear()
	for entry in CLASSES:
		picked.append(ticked.has(entry[0]))
	for path in ticked:  # keep the last pick's order
		for i in CLASSES.size():
			if CLASSES[i][0] == path and not order.has(i):
				order.append(i)
	index = 0
	_message = ""
	visible = true
	get_tree().paused = true


func _rows() -> int:
	return CLASSES.size() + 1  # the classes, then "Start the fight"


func _count() -> int:
	return picked.count(true)


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
		index = (index - 1 + _rows()) % _rows()
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		index = (index + 1) % _rows()
	elif event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept"):
		_select()
	elif event.is_action_pressed("menu") or event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		get_tree().paused = false
		back_requested.emit()
	elif event is InputEventKey:
		pass  # swallow other keys while choosing
	else:
		handled = false
	# Choosing Quit / Restart / Start can switch scenes: by then this menu
	# has left the tree and has no viewport.
	if handled and is_inside_tree():
		get_viewport().set_input_as_handled()


func _select() -> void:
	if index < CLASSES.size():
		if not picked[index] and _count() >= MAX_PARTY:
			_message = "A party holds up to %d: untick someone first" % MAX_PARTY
			return
		picked[index] = not picked[index]
		if picked[index]:
			order.append(index)
		else:
			order.erase(index)
		_message = ""
		return
	if _count() == 0:
		_message = "Pick at least one fighter"
		return
	var paths: Array[String] = []
	for i in order:
		paths.append(CLASSES[i][0])
	get_tree().paused = false
	chosen.emit(paths)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _panel() -> Rect2:
	var width := 720.0
	var height := 110.0 + _rows() * 50.0 + 60.0
	return Rect2((size.x - width) / 2.0, (size.y - height) / 2.0, width, height)


func _row(i: int) -> Rect2:
	var panel := _panel()
	return Rect2(panel.position.x + 16.0, panel.position.y + 92.0 + i * 50.0, panel.size.x - 32.0, 44.0)


func _row_at(point: Vector2) -> int:
	for i in _rows():
		if _row(i).has_point(point):
			return i
	return -1


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var font := ThemeDB.fallback_font
	var panel := _panel()
	HudStyle.draw_panel(self, panel, 0.96)
	_text(font, "CHOOSE YOUR PARTY", Vector2(panel.get_center().x, panel.position.y + 42.0), 30, GOLD, true)
	var sub := "%s  -  pick 1 to %d in turn order: the first starts in control (solo is allowed)   %d chosen" % [round_title, MAX_PARTY, _count()]
	_text(font, sub, Vector2(panel.get_center().x, panel.position.y + 70.0), 15, Color(0.7, 0.72, 0.8), true)
	for i in _rows():
		var row := _row(i)
		var selected := i == index
		if selected:
			HudStyle.draw_selection(self, row, GOLD)
		if i < CLASSES.size():
			var box := Rect2(row.position + Vector2(12, 12), Vector2(20, 20))
			draw_rect(box, Color(0.1, 0.1, 0.14))
			draw_rect(box, GOLD if selected else Color(0.7, 0.7, 0.75), false, 2.0)
			if picked[i]:
				draw_rect(box.grow(-2), GOLD)
				_text(font, str(order.find(i) + 1), box.get_center() + Vector2(0, 6), 15, Color.WHITE, true)
			draw_circle(row.position + Vector2(56, 22), 11.0, _colors[i])
			var full := picked[i] or _count() < MAX_PARTY
			_text(font, _names[i], row.position + Vector2(78, 22), 20, Color.WHITE if full else Color(0.55, 0.55, 0.6), false)
			_text(font, "%d HP" % _hp[i], row.position + Vector2(200, 22), 16, GOLD, false)
			_text(font, CLASSES[i][1], row.position + Vector2(270, 22), 14, Color(0.68, 0.7, 0.78), false)
		else:
			var can_start := _count() > 0
			var label := "Start the fight (solo)" if _count() == 1 else "Start the fight"
			_text(font, ("> " if selected else "  ") + label, row.position + Vector2(12, 29), 22,
					GOLD if can_start else Color(0.5, 0.5, 0.55), false)
	if _message != "":
		_text(font, _message, Vector2(panel.get_center().x, panel.end.y - 40.0), 15, Color(1.0, 0.55, 0.45), true)
	_text(font, Keybinds.fill("{up} / {down}: choose     {confirm} / Enter: tick or start     Esc / {cancel}: title screen"),
			Vector2(panel.get_center().x, panel.end.y - 16.0), 14, Color(0.6, 0.6, 0.65), true)


func _text(font: Font, text: String, pos: Vector2, font_size: int, color: Color, centered: bool) -> void:
	if centered:
		pos.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
