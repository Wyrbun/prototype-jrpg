extends Control
## The title screen: Continue (when a Boss Rush save exists), Boss Rush,
## Tutorial, Round Select, Controls, Change Keys, Forget Arts (once any Art
## has been discovered), Quit.
##
## Keyboard: W / S (or arrows) to choose, J (or Enter) to select, K (or Esc)
## to go back (or whatever keys the player has set). The mouse works too.

enum Page { MAIN, ROUNDS, CONTROLS, KEYS }

const GOLD := Color(0.95, 0.78, 0.35)
const ROW_HEIGHT := 44.0
const MAIN_NOTES := {"Boss Rush": "All 12 rounds, from the start", "Tutorial": "Learn every mechanic in a guided fight",
		"Round Select": "Jump straight to any round", "Controls": "Every key at a glance",
		"Change Keys": "Set your own keys", "Quit": ""}
const FORGET_ROW := "Forget Arts"
const RESET_ROW := "Reset all keys to default"
## Key names in {braces} are filled in with the player's current keys.
const CONTROLS := [
	["Between turns", "{move} / arrows", "Move the party member you're steering"],
	["Between turns", "{swap}", "Switch to the next party member"],
	["Camera", "{cam_l} / {cam_r}, right-drag", "Rotate (wheel: zoom, {cam_reset}: reset)"],
	["Your turn", "{up} / {down}, {confirm} / {cancel}", "Choose, select, go back"],
	["Any time", "Enter / Backspace", "Same as {confirm} / {cancel}"],
	["Combo bar", "{confirm} / {cancel}, {begin}", "Add a move / remove the last one, begin"],
	["Combo playing", "{confirm}", "Timed hit: press inside the box for a Perfect"],
	["Choosing a target", "{up} / {down} (Jump: {move})", "Pick who or where"],
	["Enemy strike", "{parry}", "Parry when the ring turns gold"],
	["Enemy strike", "{defend}", "Defend (costs 10 AP)"],
	["After a fight", "{restart} / {next} / O", "Retry / next round / open play-test reports"],
	["In a fight", "Esc", "Pause: resume, restart or quit"],
]

var page: int = Page.MAIN
var index := 0
var _rounds: Array[String] = []
## First row shown when a list is longer than the screen (Round Select).
var _scroll := 0
var _style: StyleBoxFlat
## Change Keys: the row waiting for a key press (-1 when not waiting).
var _capturing := -1
## Change Keys: a short message under the list ("Swapped with Parry").
var _key_message := ""
## Forget Arts: true after the first press; a second press confirms.
var _forget_armed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Keybinds.apply_saved()
	var rush: BossRush = load("res://data/boss_rush.tres")
	for i in rush.rounds.size():
		var encounter: Encounter = rush.rounds[i]
		# Boss rounds let you choose the party (1 to 4) before the fight.
		var who := "Your pick (1-4)" if i >= BattleArena.PICK_PARTY_FROM else _scene_names(encounter.party)
		_rounds.append("%s:  %s  vs  %s" % [encounter.title, who, _scene_names(encounter.enemies)])
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
		Page.KEYS:
			var rows := []
			for entry in Keybinds.ACTIONS:
				rows.append(entry[1])
			rows.append(RESET_ROW)
			return rows
	return _main_items()


## Continue only shows up when there's a Boss Rush save.
func _main_items() -> Array:
	var list := ["Boss Rush", "Tutorial", "Round Select", "Controls", "Change Keys"]
	if ArtsBook.count() > 0:
		list.append(FORGET_ROW)
	list.append("Quit")
	if SaveGame.has_save():
		list.push_front("Continue")
	return list


func _main_note(item: String) -> String:
	if item == "Boss Rush" and SaveGame.has_save():
		return "From Round 1 (replaces your saved progress)"
	if item == "Continue":
		var saved := SaveGame.saved_round()
		var title: String = load("res://data/boss_rush.tres").rounds[clampi(saved, 0, _rounds.size() - 1)].title
		return "Boss Rush from the start of %s" % title
	if item == FORGET_ROW:
		var n := ArtsBook.count()
		if _forget_armed:
			return "Press again to forget %d Art%s" % [n, "" if n == 1 else "s"]
		return "Hide the %d discovered Art%s again" % [n, "" if n == 1 else "s"]
	return MAIN_NOTES.get(item, "")


func _unhandled_input(event: InputEvent) -> void:
	if _capturing >= 0:
		_capture_key(event)
		return
	var up := event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up")
	var down := event.is_action_pressed("move_back") or event.is_action_pressed("ui_down")
	var select := event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept")
	var back := event.is_action_pressed("cancel") or event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")
	var count := _items().size()
	if event is InputEventMouseMotion:
		var hovered := _row_at(event.position)
		if hovered >= 0:
			if hovered != index:
				_forget_armed = false
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
	if up or down or back:
		_forget_armed = false
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
		var opener: String = {Page.ROUNDS: "Round Select", Page.CONTROLS: "Controls", Page.KEYS: "Change Keys"}[page]
		index = _main_items().find(opener)  # back onto the item that opened this page
		_key_message = ""
		page = Page.MAIN
		_scroll = 0  # the main menu always shows from the top
	else:
		return
	get_viewport().set_input_as_handled()


func _select() -> void:
	match page:
		Page.MAIN:
			match _main_items()[index]:
				"Continue":
					BattleArena.start(get_tree(), clampi(SaveGame.saved_round(), 0, _rounds.size() - 1), false, true, true)
				"Boss Rush":
					BattleArena.start(get_tree(), 0, false, true)
				"Tutorial":
					BattleArena.start(get_tree(), 0, true)
				"Round Select":
					page = Page.ROUNDS
					index = 0
					_scroll = 0
				"Controls":
					page = Page.CONTROLS
				"Change Keys":
					page = Page.KEYS
					index = 0
					_scroll = 0
					_key_message = ""
				FORGET_ROW:
					if not _forget_armed:
						_forget_armed = true
					else:
						ArtsBook.reset()
						_forget_armed = false
						index = _main_items().find("Change Keys")  # the row is gone now
				"Quit":
					get_tree().quit()
		Page.ROUNDS:
			BattleArena.start(get_tree(), index, false)
		Page.CONTROLS:
			page = Page.MAIN
			index = _main_items().find("Controls")
			_scroll = 0
		Page.KEYS:
			if index >= Keybinds.ACTIONS.size():
				Keybinds.reset_defaults()
				_key_message = "All keys are back to their defaults"
			else:
				_capturing = index
				_key_message = ""


## Change Keys: the next key pressed becomes the row's new key. Esc cancels.
func _capture_key(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_capturing = -1  # a click cancels
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var entry: Array = Keybinds.ACTIONS[_capturing]
	if code == KEY_ESCAPE:
		_key_message = "Kept %s" % Keybinds.label(entry[0])
	elif Keybinds.reserved(code):
		_key_message = "%s is taken (it opens the play-test reports after a fight)" % OS.get_keycode_string(code)
		return  # still waiting for a key
	else:
		var swapped := Keybinds.rebind(entry[0], code)
		_key_message = "%s: %s" % [entry[1], Keybinds.label(entry[0])]
		if swapped != "":
			_key_message += "   (swapped: %s is now %s)" % [swapped, Keybinds.label(_action_of(swapped))]
	_capturing = -1


func _action_of(row_label: String) -> String:
	for entry in Keybinds.ACTIONS:
		if entry[1] == row_label:
			return entry[0]
	return ""


func _row_height() -> float:
	if page == Page.KEYS:
		return 34.0
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
	var width := 760.0 if page == Page.ROUNDS or page == Page.KEYS else 600.0
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
	HudStyle.draw_header(self, Vector2((size.x - HudStyle.header_width("PROTOTYPE JRPG", 60)) / 2.0, 120.0), "PROTOTYPE JRPG", 60, GOLD)
	_centered(font, "A battle system prototype", 165.0, 20, Color(0.7, 0.72, 0.8))
	# The build's version (Project Settings > Application > Config > Version),
	# so play-testers can say which build they played.
	var version := "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	var version_width := font.get_string_size(version, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(font, Vector2(size.x - version_width - 14.0, size.y - 12.0), version, 15, Color(0.55, 0.57, 0.65))

	if page == Page.CONTROLS:
		# Rows shrink on short windows so the whole table and the hint fit.
		var row_height := clampf((size.y - 215.0 - 36.0 - 50.0) / CONTROLS.size(), 22.0, 34.0)
		var panel := Rect2((size.x - 900.0) / 2.0, 215.0, 900.0, 36.0 + CONTROLS.size() * row_height)
		HudStyle.draw_panel(self, panel, 0.94)
		for i in CONTROLS.size():
			var row: Array = CONTROLS[i]
			var y := panel.position.y + 36.0 + i * row_height
			_text(font, Vector2(panel.position.x + 24, y), row[0], 17, Color(0.65, 0.67, 0.75))
			_text(font, Vector2(panel.position.x + 230, y), Keybinds.fill(row[1]), 17, GOLD)
			_text(font, Vector2(panel.position.x + 450, y), Keybinds.fill(row[2]), 17, Color.WHITE)
		_centered(font, Keybinds.fill("{cancel} / Backspace / Esc: back     (Change Keys sets your own)"),
				panel.end.y + 36.0, 16, Color(0.6, 0.6, 0.65))
		return

	var list := _list_rect()
	HudStyle.draw_panel(self, list, 0.94)
	var items := _items()
	var shown := _visible_rows()
	_scroll = clampi(_scroll, 0, maxi(items.size() - shown, 0))  # never scrolled past what exists
	var baseline := _row_height() * 0.65
	for slot in shown:
		var i := _scroll + slot
		var row := _row_rect(slot)
		var selected := i == index
		if selected:
			HudStyle.draw_selection(self, row, GOLD)
			_text(font, row.position + Vector2(10, baseline), ">", 22, GOLD)
		var font_size := 22 if page == Page.MAIN else 17
		_text(font, row.position + Vector2(36, baseline), items[i], font_size, Color.WHITE if selected else Color(0.85, 0.85, 0.9))
		if page == Page.KEYS and i < Keybinds.ACTIONS.size():
			var action: String = Keybinds.ACTIONS[i][0]
			var key_text := "press a key..." if i == _capturing else Keybinds.label(action)
			var key_color := Color(0.5, 0.95, 0.55) if i == _capturing else GOLD
			_text(font, row.position + Vector2(400, baseline), key_text, 17, key_color)
			var extras := _extra_keys(action)
			if extras != "" and i != _capturing:
				_text(font, row.position + Vector2(540, baseline), extras, 14, Color(0.55, 0.57, 0.65))
		if page == Page.MAIN and _main_note(items[i]) != "":
			var note_color := Color(1.0, 0.6, 0.45) if items[i] == FORGET_ROW and _forget_armed else Color(0.6, 0.62, 0.7)
			_text(font, row.position + Vector2(220, 27), _main_note(items[i]), 15, note_color)
	# Arrows on the right edge when there are more rows above or below.
	var arrow_x := list.end.x - 26.0
	if _scroll > 0:
		var y := list.position.y + 10.0
		draw_colored_polygon(PackedVector2Array([Vector2(arrow_x, y + 10), Vector2(arrow_x + 14, y + 10), Vector2(arrow_x + 7, y)]), GOLD)
	if _scroll + shown < items.size():
		var y := list.end.y - 20.0
		draw_colored_polygon(PackedVector2Array([Vector2(arrow_x, y), Vector2(arrow_x + 14, y), Vector2(arrow_x + 7, y + 10)]), GOLD)
	var hint := Keybinds.fill("{up} / {down}: choose     {confirm} / Enter: select")
	if page != Page.MAIN:
		hint += Keybinds.fill("     {cancel} / Backspace / Esc: back")
	if page == Page.KEYS and _capturing >= 0:
		hint = "Press the new key     Esc: keep the old one"
	_centered(font, hint, list.end.y + 30.0, 16, Color(0.6, 0.6, 0.65))
	if page == Page.KEYS and _key_message != "":
		_centered(font, _key_message, list.end.y + 54.0, 16, Color(0.5, 0.95, 0.55))


## The other keys an action keeps (arrows, Enter...), shown faintly.
func _extra_keys(action: String) -> String:
	var names: PackedStringArray = []
	var first := true
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			if first:
				first = false
				continue
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			names.append(OS.get_keycode_string(code))
	return ("also " + ", ".join(names)) if not names.is_empty() else ""


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
