extends Control
## The title screen: Boss Rush, Tutorial, Round Select, Controls, Quit.
##
## Keyboard: W / S (or arrows) to choose, J (or Enter) to select, K (or Esc)
## to go back. The mouse works too.

enum Page { MAIN, ROUNDS, CONTROLS }

const GOLD := Color(0.95, 0.78, 0.35)
const ROW_HEIGHT := 44.0
const MAIN_ITEMS := ["Boss Rush", "Tutorial", "Round Select", "Controls", "Quit"]
const MAIN_NOTES := ["All 11 rounds, from the start", "Learn every mechanic in a guided fight",
		"Jump straight to any round", "Every key at a glance", ""]
const CONTROLS := [
	["Between turns", "WASD / arrows", "Move the party member you're steering"],
	["Between turns", "Tab", "Switch to the next party member"],
	["Camera", "Z / C, right-drag", "Rotate (wheel: zoom, V: reset)"],
	["Your turn", "W / S, J / K", "Choose, select, go back"],
	["Any time", "Enter / Backspace", "Same as J / K"],
	["Combo bar", "J / K, Space", "Add a move / remove the last one, begin"],
	["Combo playing", "J", "Timed hit: press inside the box for a Perfect"],
	["Choosing a target", "W / S (Jump: WASD)", "Pick who or where"],
	["Enemy strike", "E", "Parry when the ring turns gold"],
	["Enemy strike", "Q", "Defend (costs 10 AP)"],
	["After a fight", "R / N", "Retry / next round"],
	["Any time", "Esc", "Back to this menu"],
]

var page: int = Page.MAIN
var index := 0
var _rounds: Array[String] = []
## First row shown when a list is longer than the screen (Round Select).
var _scroll := 0
var _style: StyleBoxFlat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rush: BossRush = load("res://data/boss_rush.tres")
	for encounter in rush.rounds:
		_rounds.append("%s:  %s  vs  %s" % [encounter.title, _scene_names(encounter.party), _scene_names(encounter.enemies)])
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.06, 0.07, 0.11, 0.92)
	_style.border_color = GOLD
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(6)


func _process(_delta: float) -> void:
	queue_redraw()


func _items() -> Array:
	match page:
		Page.ROUNDS:
			return _rounds
		Page.CONTROLS:
			return []
	return MAIN_ITEMS


func _unhandled_input(event: InputEvent) -> void:
	var up := event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up")
	var down := event.is_action_pressed("move_back") or event.is_action_pressed("ui_down")
	var select := event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept")
	var back := event.is_action_pressed("cancel") or event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")
	var count := _items().size()
	if event is InputEventMouseMotion:
		var hovered := _row_at(event.position)
		if hovered >= 0:
			index = hovered
		return
	if event is InputEventMouseButton and event.pressed and count > 0 \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		# Wheel scrolls a long list; the highlight stays on a row you can see.
		var step := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		_scroll = clampi(_scroll + step, 0, maxi(count - _visible_rows(), 0))
		index = clampi(index, _scroll, _scroll + _visible_rows() - 1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _row_at(event.position)
		if clicked >= 0:
			index = clicked
			select = true
		elif page == Page.CONTROLS:
			back = true
	if up and count > 0:
		index = (index - 1 + count) % count
		_keep_visible()
	elif down and count > 0:
		index = (index + 1) % count
		_keep_visible()
	elif select:
		# Marked as handled first: _select may switch scenes, after which this
		# menu is no longer in the tree and has no viewport.
		get_viewport().set_input_as_handled()
		_select()
		return
	elif back and page != Page.MAIN:
		index = 1 + page  # back onto the item that opened this page
		page = Page.MAIN
		_scroll = 0  # the main menu always shows from the top
	else:
		return
	get_viewport().set_input_as_handled()


func _select() -> void:
	match page:
		Page.MAIN:
			match index:
				0:
					BattleArena.start(get_tree(), 0, false)
				1:
					BattleArena.start(get_tree(), 0, true)
				2:
					page = Page.ROUNDS
					index = 0
					_scroll = 0
				3:
					page = Page.CONTROLS
				4:
					get_tree().quit()
		Page.ROUNDS:
			BattleArena.start(get_tree(), index, false)
		Page.CONTROLS:
			page = Page.MAIN
			index = 3
			_scroll = 0


func _row_height() -> float:
	return ROW_HEIGHT if page == Page.MAIN else 38.0


func _list_top() -> float:
	return 250.0 if page == Page.MAIN else 215.0


## How many rows fit between the list's top and the hint line at the bottom.
func _visible_rows() -> int:
	var room := size.y - _list_top() - 24.0 - 64.0
	var fits := maxi(int(room / _row_height()), 3)
	return mini(_items().size(), fits)


## Scrolls so the highlighted row is on screen.
func _keep_visible() -> void:
	var shown := _visible_rows()
	if index < _scroll:
		_scroll = index
	elif index >= _scroll + shown:
		_scroll = index - shown + 1
	_scroll = clampi(_scroll, 0, maxi(_items().size() - shown, 0))


func _list_rect() -> Rect2:
	var width := 760.0 if page == Page.ROUNDS else 600.0
	return Rect2((size.x - width) / 2.0, _list_top(), width, 24.0 + _visible_rows() * _row_height())


func _row_rect(slot: int) -> Rect2:
	var list := _list_rect()
	return Rect2(list.position + Vector2(12, 12 + slot * _row_height()), Vector2(list.size.x - 24, _row_height() - 4))


func _row_at(point: Vector2) -> int:
	for slot in _visible_rows():
		if _row_rect(slot).has_point(point):
			return _scroll + slot
	return -1


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.1, 0.15))
	var font := ThemeDB.fallback_font
	_centered(font, "PROTOTYPE JRPG", 120.0, 56, GOLD)
	_centered(font, "A battle system prototype", 165.0, 20, Color(0.7, 0.72, 0.8))

	if page == Page.CONTROLS:
		# Rows shrink on short windows so the whole table and the hint fit.
		var row_height := clampf((size.y - 215.0 - 36.0 - 50.0) / CONTROLS.size(), 22.0, 34.0)
		var panel := Rect2((size.x - 900.0) / 2.0, 215.0, 900.0, 36.0 + CONTROLS.size() * row_height)
		draw_style_box(_style, panel)
		for i in CONTROLS.size():
			var row: Array = CONTROLS[i]
			var y := panel.position.y + 36.0 + i * row_height
			_text(font, Vector2(panel.position.x + 24, y), row[0], 17, Color(0.65, 0.67, 0.75))
			_text(font, Vector2(panel.position.x + 230, y), row[1], 17, GOLD)
			_text(font, Vector2(panel.position.x + 450, y), row[2], 17, Color.WHITE)
		_centered(font, "K / Backspace / Esc: back", panel.end.y + 36.0, 16, Color(0.6, 0.6, 0.65))
		return

	var list := _list_rect()
	draw_style_box(_style, list)
	var items := _items()
	var shown := _visible_rows()
	_scroll = clampi(_scroll, 0, maxi(items.size() - shown, 0))  # never scrolled past what exists
	var baseline := _row_height() * 0.65
	for slot in shown:
		var i := _scroll + slot
		var row := _row_rect(slot)
		var selected := i == index
		if selected:
			draw_rect(row, Color(GOLD, 0.22))
			_text(font, row.position + Vector2(10, baseline), ">", 22, GOLD)
		var font_size := 22 if page == Page.MAIN else 17
		_text(font, row.position + Vector2(36, baseline), items[i], font_size, Color.WHITE if selected else Color(0.85, 0.85, 0.9))
		if page == Page.MAIN and MAIN_NOTES[i] != "":
			_text(font, row.position + Vector2(220, 27), MAIN_NOTES[i], 15, Color(0.6, 0.62, 0.7))
	# Arrows on the right edge when there are more rows above or below.
	var arrow_x := list.end.x - 26.0
	if _scroll > 0:
		var y := list.position.y + 10.0
		draw_colored_polygon(PackedVector2Array([Vector2(arrow_x, y + 10), Vector2(arrow_x + 14, y + 10), Vector2(arrow_x + 7, y)]), GOLD)
	if _scroll + shown < items.size():
		var y := list.end.y - 20.0
		draw_colored_polygon(PackedVector2Array([Vector2(arrow_x, y), Vector2(arrow_x + 14, y), Vector2(arrow_x + 7, y + 10)]), GOLD)
	var hint := "W / S: choose     J / Enter: select"
	if page != Page.MAIN:
		hint += "     K / Backspace / Esc: back"
	_centered(font, hint, list.end.y + 36.0, 16, Color(0.6, 0.6, 0.65))


func _scene_names(scenes: Array[PackedScene]) -> String:
	var counts := {}
	var order: Array[String] = []
	for scene in scenes:
		var scene_name := scene.resource_path.get_file().get_basename().capitalize()
		if not counts.has(scene_name):
			order.append(scene_name)
		counts[scene_name] = int(counts.get(scene_name, 0)) + 1
	var parts: PackedStringArray = []
	for scene_name in order:
		parts.append(("%d %ss" % [counts[scene_name], scene_name]) if counts[scene_name] > 1 else scene_name)
	if parts.size() == 4 and scenes.size() == 4 and order.has("Knight") and order.has("Cleric"):
		return "Full party"
	return ", ".join(parts)


func _centered(font: Font, text: String, y: float, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(font, Vector2((size.x - width) / 2.0, y), text, font_size, color)


func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
