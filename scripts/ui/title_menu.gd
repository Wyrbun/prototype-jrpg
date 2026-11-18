extends Control
## The title screen: Continue (when a Boss Rush save exists), Boss Rush,
## Tutorial, Round Select, Options (the screen filter and play settings: the
## same page as the pause menu's), Controls, Change Keys, Forget Arts (once
## any Art has been discovered), Quit.
##
## Keyboard: W / S (or arrows) to choose, J (or Enter) to select, K (or Esc)
## to go back (or whatever keys the player has set). The mouse works too.

enum Page { MAIN, ROUNDS, CONTROLS, KEYS, STYLE, OPTIONS }

var backdrop: TitleBackdrop

## The notice shown once per launch before the menu: the game also plays
## with a gamepad. It goes by itself after NOTICE_SECONDS, or at any key,
## button or click.
const NOTICE_SECONDS := 4.0
const NOTICE_FADE := 0.5
static var _notice_shown := false
var _notice_left := 0.0

const GOLD := Color(0.95, 0.78, 0.35)
## How much the dark veil hides the slowly turning arena behind the menu.
const BACKDROP_VEIL := 0.5
const ROW_HEIGHT := 44.0
const MAIN_NOTES := {"Boss Rush": "All 13 rounds and a Special Match", "Tutorial": "Learn every mechanic in a guided fight",
		"Round Select": "Jump straight to any round", "Options": "Screen filter and play settings",
		"Controls": "Every key at a glance",
		"Change Keys": "Set your own keys", "Quit": ""}
const FORGET_ROW := "Forget Arts"
const RESET_ROW := "Reset all keys to default"
const BACK_ROW := "Back"
## Key names in {braces} are filled in with the player's current keys.
const CONTROLS := [
	["Between turns", "{move} / arrows", "Move the party member you're steering"],
	["Between turns", "{swap}", "Switch to the next party member (hold: stop time and choose)"],
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
## Play style page (first Boss Rush / Round Select only): the choices so far,
## the highlighted row (0 timing, 1 Party AI, 2 Start), and what to open after.
var _style_windup := true
var _style_ai := false
var _style_row := 2
var _style_then := ""
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
	_sync_music()
	if not _notice_shown:
		_notice_shown = true
		_notice_left = NOTICE_SECONDS
	backdrop = TitleBackdrop.new()
	add_child(backdrop)
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


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left = maxf(_notice_left - delta, 0.0)
	queue_redraw()


## Any key, pad button or click skips the notice (and does nothing else).
func _skip_notice(event: InputEvent) -> bool:
	if _notice_left <= 0.0:
		return false
	var press: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventAction and event.pressed)
	if press:
		_notice_left = minf(_notice_left, NOTICE_FADE)  # fades out
	get_viewport().set_input_as_handled()
	return true


## The main menu's theme; Round Select has its own.
func _sync_music() -> void:
	Sfx.duck(false)
	Sfx.music("round_select" if page == Page.ROUNDS else "title")


func _items() -> Array:
	match page:
		Page.ROUNDS:
			return _rounds
		Page.CONTROLS:
			return []
		Page.OPTIONS:
			var rows: Array = Settings.option_rows()
			rows.append(BACK_ROW)
			return rows
		Page.KEYS:
			var rows := []
			for entry in Keybinds.ACTIONS:
				rows.append(entry[1])
			rows.append(RESET_ROW)
			return rows
	return _main_items()


## Continue only shows up when there's a Boss Rush save.
func _main_items() -> Array:
	var list := ["Boss Rush", "Tutorial", "Round Select", "Options", "Controls", "Change Keys"]
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
	if _skip_notice(event):
		return
	if _capturing >= 0:
		_capture_key(event)
		return
	Sfx.menu_keys(event)
	_sync_music.call_deferred()
	if page == Page.STYLE:
		_style_input(event)
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
		var opener: String = {Page.ROUNDS: "Round Select", Page.CONTROLS: "Controls", Page.KEYS: "Change Keys", Page.OPTIONS: "Options"}[page]
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
					if _ask_style("Continue"):
						return
					BattleArena.start(get_tree(), clampi(SaveGame.saved_round(), 0, _rounds.size() - 1), false, true, true)
				"Boss Rush":
					if _ask_style("Boss Rush"):
						return
					BattleArena.start(get_tree(), 0, false, true)
				"Tutorial":
					BattleArena.start(get_tree(), 0, true)
				"Round Select":
					if _ask_style("Round Select"):
						return
					page = Page.ROUNDS
					index = 0
					_scroll = 0
				"Options":
					page = Page.OPTIONS
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
		Page.OPTIONS:
			if _items()[index] == BACK_ROW:
				page = Page.MAIN
				index = _main_items().find("Options")
				_scroll = 0
			else:
				Settings.change_option(index)
				if backdrop:
					backdrop.apply_screen_filter()
		Page.KEYS:
			if index >= Keybinds.ACTIONS.size():
				Keybinds.reset_defaults()
				_key_message = "All keys are back to their defaults"
			else:
				_capturing = index
				_key_message = ""


# --- Play style (asked once) ------------------------------------------------

## The first time a Boss Rush or Round Select starts: ask for the play style.
## True if the page opened (the choice continues to "then" afterwards).
func _ask_style(then: String) -> bool:
	if Settings.style_chosen():
		return false
	_style_windup = Settings.command_windup()
	_style_ai = Settings.party_ai()
	_style_row = 2
	_style_then = then
	page = Page.STYLE
	return true


func _style_input(event: InputEvent) -> void:
	var handled := true
	if event is InputEventMouseMotion:
		for i in 3:
			if _style_rect(i).has_point(event.position):
				_style_row = i
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in 3:
			if _style_rect(i).has_point(event.position):
				_style_row = i
				_style_pick()
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_style_row = (_style_row + 2) % 3
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_style_row = (_style_row + 1) % 3
	elif (event.is_action_pressed("move_left") or event.is_action_pressed("move_right")
			or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")) and _style_row < 2:
		_style_toggle()
	elif event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_style_pick()
		return
	elif event.is_action_pressed("cancel") or event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		page = Page.MAIN
		index = maxi(_main_items().find(_style_then), 0)
	else:
		handled = false
	if handled and is_inside_tree():
		get_viewport().set_input_as_handled()


func _style_toggle() -> void:
	if _style_row == 0:
		_style_windup = not _style_windup
	elif _style_row == 1:
		_style_ai = not _style_ai


## Enter / click: a choice row flips, Start saves both and carries on.
func _style_pick() -> void:
	if _style_row < 2:
		_style_toggle()
		return
	Settings.set_command_windup(_style_windup)
	Settings.set_party_ai(_style_ai)
	Settings.set_style_chosen(true)
	page = Page.MAIN
	index = maxi(_main_items().find(_style_then), 0)
	_select()  # what was chosen in the first place, now with a style


func _style_panel() -> Rect2:
	var width := minf(980.0, size.x - 40.0)
	return Rect2((size.x - width) / 2.0, 200.0, width, minf(500.0, size.y - 230.0))


func _style_rect(row: int) -> Rect2:
	var panel := _style_panel()
	var tops := [64.0, 196.0, 336.0]
	var height := 120.0 if row < 2 else 46.0
	return Rect2(panel.position.x + 20.0, panel.position.y + tops[row], panel.size.x - 40.0, height)


func _draw_style(font: Font) -> void:
	var panel := _style_panel()
	HudStyle.draw_panel(self, panel, 0.95)
	_centered(font, "Choose how you'd like to play", panel.position.y + 40.0, 24, GOLD)
	var rows := [
		["Command timing", "WINDUP" if _style_windup else "CLASSIC",
			"Choose a fighter's move at the gold COM mark, then time keeps running while they get in reach of their target before ACT. More movement, more planning ahead." if _style_windup
			else "Time stops when a fighter reaches the end of the timeline: choose a move and attack right there. Simpler, slower-paced."],
		["Party AI", "ON" if _style_ai else "OFF",
			"Only the fighter you steer is yours: the others play their own turns instantly (moves, Arts, healing), leaving you AP. Tab takes any of them over." if _style_ai
			else "You choose every party member's turn yourself. The full experience: every Perfect is yours."],
	]
	for i in 2:
		var rect := _style_rect(i)
		if _style_row == i:
			HudStyle.draw_selection(self, rect, GOLD)
		var row: Array = rows[i]
		_text(font, rect.position + Vector2(18, 32), row[0], 22, Color.WHITE)
		var value := "<  %s  >" % row[1]
		var value_w := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		_text(font, Vector2(rect.end.x - value_w - 18.0, rect.position.y + 32), value, 22, GOLD)
		var lines := _wrap(font, row[2], rect.size.x - 36.0, 16)
		for j in lines.size():
			_text(font, rect.position + Vector2(18, 62 + j * 22), lines[j], 16, Color(0.8, 0.82, 0.9))
	var start := _style_rect(2)
	if _style_row == 2:
		HudStyle.draw_selection(self, start, GOLD)
	var label := "Start " + ("Round Select" if _style_then == "Round Select" else "Boss Rush")
	var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	_text(font, Vector2(start.position.x + (start.size.x - label_w) / 2.0, start.position.y + 31), label, 22, Color.WHITE if _style_row == 2 else Color(0.85, 0.85, 0.9))
	_centered(font, "You can change both any time: press Esc during a fight to open the pause menu.", panel.end.y - 52.0, 16, Color(0.55, 0.85, 1.0))
	_centered(font, "(A new Command timing starts with the next fight.)", panel.end.y - 28.0, 14, Color(0.6, 0.62, 0.7))
	_centered(font, Keybinds.fill("{up} / {down}: choose     {left} / {right} or {confirm}: change     Esc: back"), panel.end.y + 30.0, 16, Color(0.6, 0.6, 0.65))


func _wrap(font: Font, text: String, width: float, font_size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var attempt := word if line == "" else line + " " + word
		if font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and line != "":
			lines.append(line)
			line = word
		else:
			line = attempt
	if line != "":
		lines.append(line)
	return lines


## Change Keys: the next key pressed becomes the row's new key (a pad
## button: its new pad button). Esc (or the pad's Menu) cancels.
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
			_key_message += "   (swapped: %s is now %s)" % [swapped, Keybinds.key_label(_action_of(swapped))]
	_capturing = -1


func _action_of(row_label: String) -> String:
	for entry in Keybinds.ACTIONS:
		if entry[1] == row_label:
			return entry[0]
	return ""


func _row_height() -> float:
	if page == Page.KEYS:
		return 34.0
	if page == Page.OPTIONS:
		return 56.0  # a second line: what the option does
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
	var width := 760.0 if page == Page.ROUNDS or page == Page.KEYS or page == Page.OPTIONS else 600.0
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
	# A dim veil over the arena behind (TitleBackdrop), so the menu reads.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.1, 0.15, BACKDROP_VEIL))
	var font := ThemeDB.fallback_font
	HudStyle.draw_header(self, Vector2((size.x - HudStyle.header_width("PROTOTYPE JRPG", 60)) / 2.0, 120.0), "PROTOTYPE JRPG", 60, GOLD)
	_centered(font, "A battle system prototype", 165.0, 20, Color(0.7, 0.72, 0.8))
	# The build's version (Project Settings > Application > Config > Version),
	# so play-testers can say which build they played.
	var version := "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	var version_width := font.get_string_size(version, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(font, Vector2(size.x - version_width - 14.0, size.y - 12.0), version, 15, Color(0.55, 0.57, 0.65))

	if page == Page.STYLE:
		_draw_style(font)
		return

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
		if page == Page.OPTIONS:
			_text(font, row.position + Vector2(36, 24), items[i], 20, Color.WHITE if selected else Color(0.85, 0.85, 0.9))
			var note := "Back to the title menu" if items[i] == BACK_ROW else Settings.option_note(i)
			_text(font, row.position + Vector2(36, 45), note, 14, Color(0.6, 0.62, 0.7))
		else:
			_text(font, row.position + Vector2(36, baseline), items[i], font_size, Color.WHITE if selected else Color(0.85, 0.85, 0.9))
		if page == Page.KEYS and i < Keybinds.ACTIONS.size():
			var action: String = Keybinds.ACTIONS[i][0]
			var key_text := "press a key or button..." if i == _capturing else Keybinds.key_label(action)
			var key_color := Color(0.5, 0.95, 0.55) if i == _capturing else GOLD
			_text(font, row.position + Vector2(340, baseline), key_text, 17, key_color)
			if i != _capturing:
				var pad := Keybinds.pad_label(action)
				_text(font, row.position + Vector2(440, baseline), pad if pad != "" else "-", 17, Color(0.6, 0.85, 1.0))
				var extras := _extra_keys(action)
				if extras != "":
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
	var hint := Keybinds.fill("{up} / {down}: choose     {confirm} / Enter: %s" % ("change" if page == Page.OPTIONS else "select"))
	if page != Page.MAIN:
		hint += Keybinds.fill("     {cancel} / Backspace / Esc: back")
	if page == Page.KEYS and _capturing >= 0:
		hint = "Press the new key or pad button     Esc / Menu: keep the old one"
	_centered(font, hint, list.end.y + 30.0, 16, Color(0.6, 0.6, 0.65))
	if page == Page.KEYS and _key_message != "":
		_centered(font, _key_message, list.end.y + 54.0, 16, Color(0.5, 0.95, 0.55))
	_draw_notice(font)


## A gamepad outline: a rounded body with a grip on each side, a D-pad
## cross on the left and four round buttons in a diamond on the right.
const GAMEPAD_OUTLINE := [
	Vector2(-48, -50), Vector2(0, -43), Vector2(48, -50), Vector2(76, -40), Vector2(90, -5),
	Vector2(98, 38), Vector2(88, 60), Vector2(66, 58), Vector2(46, 28), Vector2(0, 20),
	Vector2(-46, 28), Vector2(-66, 58), Vector2(-88, 60), Vector2(-98, 38), Vector2(-90, -5),
	Vector2(-76, -40),
]


func _draw_gamepad(center: Vector2, line: Color, fill: Color) -> void:
	# A smooth closed curve through the outline's points.
	var curve := Curve2D.new()
	var n := GAMEPAD_OUTLINE.size()
	for i in n + 1:
		var p: Vector2 = GAMEPAD_OUTLINE[i % n]
		var tangent: Vector2 = (GAMEPAD_OUTLINE[(i + 1) % n] - GAMEPAD_OUTLINE[(i - 1 + n) % n]) * 0.22
		curve.add_point(center + p, -tangent, tangent)
	var shape := curve.tessellate(5, 3.0)
	draw_colored_polygon(shape, fill)
	draw_polyline(shape, line, 5.0, true)
	# The D-pad: a cross, drawn as its outline.
	var arm := 7.0
	var reach := 19.0
	var dpad := center + Vector2(-47, -8)
	var cross := PackedVector2Array()
	for corner in [Vector2(-arm, -reach), Vector2(arm, -reach), Vector2(arm, -arm), Vector2(reach, -arm),
			Vector2(reach, arm), Vector2(arm, arm), Vector2(arm, reach), Vector2(-arm, reach),
			Vector2(-arm, arm), Vector2(-reach, arm), Vector2(-reach, -arm), Vector2(-arm, -arm), Vector2(-arm, -reach)]:
		cross.append(dpad + corner)
	draw_polyline(cross, line, 4.0, true)
	# The face buttons: four rings in a diamond.
	var buttons := center + Vector2(47, -8)
	for offset in [Vector2(0, -17), Vector2(17, 0), Vector2(0, 17), Vector2(-17, 0)]:
		draw_arc(buttons + offset, 6.5, 0.0, TAU, 20, line, 4.0, true)


## The controller notice over everything, fading out at the end.
func _draw_notice(font: Font) -> void:
	if _notice_left <= 0.0:
		return
	var alpha := clampf(_notice_left / NOTICE_FADE, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.1, alpha))
	var mid := size / 2.0
	_draw_gamepad(Vector2(mid.x, mid.y - 138.0), Color(GOLD, alpha), Color(0.16, 0.18, 0.26, alpha))
	var title := "CONTROLLER SUPPORT"
	HudStyle.draw_header(self, Vector2(mid.x - HudStyle.header_width(title, 40) / 2.0, mid.y - 20.0), title, 40, Color(GOLD, alpha))
	_centered(font, "This game also has controller support: plug in a gamepad (Xbox layout) and play.", mid.y + 30.0, 20, Color(0.9, 0.9, 0.95, alpha))
	_centered(font, "Any key or button: continue", mid.y + 80.0, 16, Color(0.6, 0.62, 0.7, alpha))


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
