class_name BattleMenu
extends Control
## Draws the command menu and the combo bar. The battle script owns all the
## logic and just tells this node what to show.
##
## Command menu: the fighter's name, Attack / Abilities / Items, and a
## reminder of the reaction keys.
## Combo builder (Legend of Legaia-style): a list of moves on top, and below
## it a bar as long as the fighter's combo limit. Each move fills part of the
## bar according to its AP cost. The part of the bar the party can't afford
## right now is shown locked.
## Abilities: the class's skills in the same list style; choosing one may ask
## for a target (TARGET mode shows the prompt).

enum Mode { HIDDEN, COMMANDS, COMBO, EXECUTING, SKILLS, TARGET }

## Pixels of bar per AP, so a bigger combo limit means a longer bar.
const PX_PER_AP := 8.0
## Width of the "READY" lead-in block in front of the strip during a combo.
const LEAD_IN_PX := 70.0
## The bar never grows wider than the move list above it (long bars, like the
## Monk's, shrink to fit instead of running under the Arts panel and HUD).
const MAX_BAR_PX := 720.0
## While a combo plays, small blocks (the Monk's 5 AP Punch and Kick) zoom in
## so the smallest one is at least this wide; the bar then scrolls with the
## playhead inside a window of at most PLAY_VIEW_PX.
const MIN_PLAY_BLOCK_PX := 72.0
const PLAY_MAX_PX_PER_AP := 16.0
const PLAY_VIEW_PX := 900.0
## Timing boxes are drawn at least this wide (the window to press in doesn't
## change, only how easy it is to see).
const MIN_BOX_PX := 14.0
const GOLD := Color(0.95, 0.78, 0.35)
## Timing types: Press boxes are white squares, Hold is blue and rounded,
## Tap is pink with diamonds.
const HOLD_COLOR := Color(0.35, 0.75, 1.0)
const TAP_COLOR := Color(1.0, 0.45, 0.85)
const PANEL_BG := Color(0.06, 0.07, 0.11, 0.9)

var mode: int = Mode.HIDDEN
var fighter_name := ""
var commands: PackedStringArray = ["Attack", "Abilities", "Items"]
var command_enabled: Array[bool] = [true, false, false]
## Shown next to a disabled command, e.g. "no enemy in reach".
var command_notes: PackedStringArray = ["", "coming later", "coming later"]
var command_index := 0
## Which reaction reminders to show above the menu (depends on the class).
var show_defend := true
var show_parry := true

## The list on screen: the fighter's attacks (COMBO) or skills (SKILLS).
## Each entry's "cost" is what it costs right now.
var moves: Array[Dictionary] = []
## Per entry: false = greyed out, with the reason in move_notes.
var move_usable: Array[bool] = []
var move_notes: PackedStringArray = []
## Per row of the move / Ability list: [] or [tag, -1/0/1, explanation]
## (BattleArena._move_answer): what it does against the enemy right now.
var move_tags: Array = []
var move_index := 0
## Indices into moves, in the order they'll be performed.
var combo: Array[int] = []
## One entry per combo slot: what that slot will actually do, worked out when
## it was added: "name", "color", "cost", "times" (where each hit lands, as a
## fraction of the block) and "window" (timing box size as a fraction).
var plan: Array[Dictionary] = []
## The enemy the combo will hit, shown above the combo bar.
var target_name := ""
## TARGET mode: what to show, e.g. "Healing: choose an ally".
var target_prompt := ""
var combo_limit: float = 50.0
var ap_available: float = 0.0
## During execution: which combo slot is playing (-1 = none yet).
var executing_slot := -1

## How far the playhead is through the current block (0..1).
var slot_progress := 0.0
## Progress through the 1 s lead-in before the first move (0..1);
## negative when there's no lead-in running.
var lead_in_progress := -1.0
## Per combo slot, one entry per hit: 0 = not judged yet, 1 = Perfect, 2 = Miss.
var slot_results: Array = []
## The playing slot's Hold / Tap state (set by the battle while it plays).
var exec_holding := false
var exec_taps := 0
## The Arts panel beside the move list while building a combo: one row per
## Art, {name, recipe, known, next, color, finisher} (set by the battle).
var arts: Array = []
## Tab in the combo bar: the cursor is in the Arts list instead of the moves.
var arts_focus := false
var arts_index := 0
## How many Arts are still undiscovered (counted, never named).
var arts_hidden := 0
## Hidden Arts by recipe length ({2: 3, 4: 1}): the only hint about them.
var arts_hidden_sizes := {}
## Partial hints for hidden Arts ("Thrust + Thrust + ?  (2 of 3)").
var arts_hints: PackedStringArray = []
## While a hidden Art reveals itself mid-combo: its name and the banner's
## progress (0 -> 1).
var reveal_name := ""
var reveal_progress := 0.0
## Monk's Headbutt restarts: AP of bar before the current fresh part, what
## that part can spend, and the slots the bar restarts after.
var segment_start := 0.0
var segment_available := 0.0
var reset_slots: Array[int] = []
## Monk while a combo plays: blocks already used up by an Art that gave a
## buff. They vanish and the rest of the bar slides left, so it stays short.
var consumed_slots := 0
## Pixels per AP for the current bar (shrinks when a long bar must fit).
var _px := PX_PER_AP
## Where slot 0 starts on screen (left of the bar once blocks are used up).
var _origin := 0.0
## Monk: the bar lengths still to climb (shown past the bar's end while
## building), what the Art at the end of the bar does with his climb, what
## a Perfect adds, and whether that Perfect is still on (greyed once lost).
var step_marks: Array[float] = []
var preview_main := ""
var preview_perfect := ""
var preview_perfect_on := true
## A banner over the field when the Monk's climb moves ("STEP 2 · BAR 80",
## "STEP LOST"), shown even while the menus are hidden.
const BANNER_SECONDS := 1.6
## The preview stays clear of the HP panels at the screen's sides.
const PREVIEW_MARGIN := 450.0
var banner_text := ""
var banner_color := Color.WHITE
var banner_left := 0.0

var _panel_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = PANEL_BG
	_panel_style.border_color = GOLD
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(6)


func _process(delta: float) -> void:
	banner_left = maxf(banner_left - delta, 0.0)
	queue_redraw()


func combo_cost() -> float:
	var total := 0.0
	for entry in plan:
		total += float(entry["cost"])
	return total


func _draw() -> void:
	if banner_left > 0.0:
		_draw_banner(ThemeDB.fallback_font)
	if mode == Mode.HIDDEN:
		return
	var font := ThemeDB.fallback_font
	if mode == Mode.EXECUTING:
		# Inputs are locked in: get the menus out of the way so the action
		# is visible, and keep only the bar as a slim progress strip.
		_draw_combo_bar(font)
		return
	if mode == Mode.COMBO:
		# Picking moves: the command menu steps aside and the move list turns
		# see-through, so the highlighted move's area on the floor (and the
		# enemies it would hit) stay visible behind it.
		var solid := _panel_style.bg_color
		_panel_style.bg_color = Color(solid, 0.45)
		_draw_move_list(font)
		_panel_style.bg_color = solid
		_draw_combo_bar(font)
		return
	_draw_commands(font)
	if mode == Mode.COMBO:
		_draw_move_list(font)
		_draw_combo_bar(font)
	elif mode == Mode.SKILLS:
		_draw_move_list(font)
	elif mode == Mode.TARGET:
		var panel := Rect2((size.x - 640) / 2.0, size.y - 270, 640, 72)
		draw_style_box(_panel_style, panel)
		_text(font, panel.position + Vector2(18, 31), target_prompt, 22, GOLD)
		_text(font, panel.position + Vector2(18, 58), Keybinds.fill("{confirm} / Enter: confirm     {cancel} / Backspace: back"), 17, Color(0.75, 0.75, 0.8))


# --- Command menu ----------------------------------------------------------

func _draw_commands(font: Font) -> void:
	var panel := Rect2(40, 220, 340, 40 + commands.size() * 44)
	var dimmed := mode != Mode.COMMANDS
	_text(font, panel.position + Vector2(4, -12), fighter_name, 25, GOLD)
	# Reaction reminders, only for what this class can do (stacked upward).
	var reminder_y := -10.0
	if show_parry:
		_text(font, panel.position + Vector2(panel.size.x - 124, reminder_y), Keybinds.fill("Parry: {parry}"), 17, Color(1.0, 0.85, 0.3))
		reminder_y -= 22.0
	if show_defend:
		_text(font, panel.position + Vector2(panel.size.x - 124, reminder_y), Keybinds.fill("Defend: {defend}"), 17, Color(0.6, 0.8, 1.0))
	draw_style_box(_panel_style, panel)

	for i in commands.size():
		var row := Rect2(panel.position + Vector2(10, 18 + i * 44), Vector2(panel.size.x - 20, 38))
		var selected := i == command_index
		if selected and not dimmed:
			draw_rect(row, Color(GOLD, 0.22))
			_text(font, row.position + Vector2(6, 27), ">", 23, GOLD)
		var color := Color.WHITE if command_enabled[i] else Color(0.5, 0.5, 0.55)
		if dimmed and not selected:
			color = color.darkened(0.4)
		_text(font, row.position + Vector2(30, 27), commands[i], 23, color)
		if command_notes[i] != "":
			_text(font, row.position + Vector2(160, 26), command_notes[i], 15, Color(0.6, 0.6, 0.65))


# --- Combo builder ---------------------------------------------------------

func _draw_move_list(font: Font) -> void:
	var width := 720.0
	var row_height := 36.0
	var height := 16 + moves.size() * row_height
	# In the combo bar, the list ends just above the bar's header line.
	var top := size.y - 264 - height if mode == Mode.COMBO else size.y - 340
	var panel := Rect2((size.x - width) / 2.0, top, width, height)
	draw_style_box(_panel_style, panel)
	var room := minf(combo_limit, segment_available) - (combo_cost() - segment_start if mode == Mode.COMBO else 0.0)
	for i in moves.size():
		var move := moves[i]
		var row := Rect2(panel.position + Vector2(8, 8 + i * row_height), Vector2(width - 16, row_height - 2))
		var usable := i >= move_usable.size() or move_usable[i]
		var shown_cost := float(move.get("shown_cost", move["cost"]))  # Bash: its cost if added next
		var fits := shown_cost <= room and usable
		if i == move_index and not (mode == Mode.COMBO and arts_focus):
			draw_rect(row, Color(GOLD, 0.22))
			_text(font, row.position + Vector2(6, 25), ">", 20, GOLD)
		var color := Color.WHITE if fits else Color(0.5, 0.5, 0.55)
		draw_rect(Rect2(row.position + Vector2(24, 10), Vector2(14, 14)), move["color"] if fits else Color(0.35, 0.35, 0.4))
		_text(font, row.position + Vector2(46, 25), move["name"], 20, color)
		_text(font, row.position + Vector2(232, 25), "%d AP" % shown_cost, 20, GOLD if fits else color)
		var desc: String = move["desc"]
		if not usable and i < move_notes.size() and move_notes[i] != "":
			desc = move_notes[i]
		var tag: Array = move_tags[i] if i < move_tags.size() and usable else []
		var tag_w := 0.0
		if not tag.is_empty():
			tag_w = _answer_tag(font, tag, Vector2(row.end.x - 100, row.position.y + row.size.y / 2.0), row)
		# The description fits between the cost and the tag / timing badge.
		var desc_size := 17
		var desc_room := row.size.x - 312 - 100 - tag_w
		while desc_size > 12 and font.get_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, -1, desc_size).x > desc_room:
			desc_size -= 1
		while desc.length() > 4 and font.get_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, -1, desc_size).x > desc_room:
			desc = desc.left(desc.length() - 2) + "…"  # the tag needs the room; the details box has it all
		_text(font, row.position + Vector2(312, 25), desc, desc_size, color.darkened(0.15))
		_timing_badge(font, move, Vector2(row.end.x - 6, row.position.y + row.size.y / 2.0), not fits)
	if mode == Mode.COMBO and (not arts.is_empty() or arts_hidden > 0):
		_draw_arts(font, panel)
	if Settings.move_details() and not (mode == Mode.COMBO and arts_focus) \
			and move_index >= 0 and move_index < moves.size():
		_draw_move_details(font, moves[move_index], panel)


## The Arts panel, right of the move list: known Arts with their recipes,
## unknown ones as "???" with only the first move. Arts the moves at the end
## of the bar are heading towards glow gold and say which move comes next.
func _draw_arts(font: Font, beside: Rect2) -> void:
	var row_height := 42.0
	var x := beside.end.x + 12.0
	var width := minf(420.0, size.x - x - 8.0)
	if width < 220.0:
		return  # no room on a narrow window
	var hidden_line := ""
	var hidden_size := Vector2.ZERO
	if arts_hidden > 0:
		hidden_line = ("Hidden: " if not arts.is_empty() else "To discover: ") + _hidden_by_length()
		for h in arts_hints:
			hidden_line += "\n??? " + h
		hidden_size = font.get_multiline_string_size(hidden_line, HORIZONTAL_ALIGNMENT_LEFT, width - 24.0, 14)
	var extra := hidden_size.y + 10.0 if arts_hidden > 0 else 0.0  # wraps on a narrow panel
	# Bottom-aligned with the move list, growing upward: it never reaches
	# down into the combo bar, however many Arts the class has.
	var panel_height := 38.0 + arts.size() * row_height + extra
	var panel := Rect2(x, beside.end.y - panel_height, width, panel_height)
	draw_style_box(_panel_style, panel)
	_text(font, panel.position + Vector2(12, 27), "ARTS", 19, GOLD)
	var tip := "choose one to add it whole" if arts_focus else "moves in this order merge  ·  Tab: details"
	_text(font, panel.position + Vector2(74, 27), tip, 14, Color(0.6, 0.62, 0.7))
	for i in arts.size():
		var art: Dictionary = arts[i]
		var row := Rect2(panel.position + Vector2(6, 36 + i * row_height), Vector2(width - 12, row_height - 2))
		var heading: bool = art["next"] != ""
		if heading:
			draw_rect(row, Color(GOLD, 0.18))
		if arts_focus and i == arts_index:
			draw_rect(row, Color(GOLD, 0.35))
			draw_rect(row, GOLD, false, 2.0)
		var name_color: Color = art["color"] if art["known"] else Color(0.55, 0.55, 0.6)
		_text(font, row.position + Vector2(8, 17), art["name"], 18, name_color)
		var art_tag: Array = art.get("tag", [])
		if not art_tag.is_empty() and not heading:
			_answer_tag(font, art_tag, Vector2(row.end.x - 4, row.position.y + 12), row)
		if art["finisher"]:
			var name_w := font.get_string_size(art["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			_text(font, row.position + Vector2(14 + name_w, 17), "FINISHER", 12, GOLD)
		var recipe_size := 15
		while recipe_size > 10 and font.get_string_size(art["recipe"], HORIZONTAL_ALIGNMENT_LEFT, -1, recipe_size).x > row.size.x - 14:
			recipe_size -= 1
		_text(font, row.position + Vector2(8, 35), art["recipe"], recipe_size, Color(0.75, 0.77, 0.85))
		if heading:
			var hint: String = "next: " + art["next"]
			var hint_w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			_text(font, Vector2(row.end.x - hint_w - 6, row.position.y + 17), hint, 14, GOLD)
	if arts_hidden > 0:
		var top := panel.end.y - hidden_size.y - 6.0
		draw_multiline_string_outline(font, Vector2(panel.position.x + 12, top + font.get_ascent(14)), hidden_line,
				HORIZONTAL_ALIGNMENT_LEFT, width - 24.0, 14, -1, 4, Color.BLACK)
		draw_multiline_string(font, Vector2(panel.position.x + 12, top + font.get_ascent(14)), hidden_line,
				HORIZONTAL_ALIGNMENT_LEFT, width - 24.0, 14, -1, Color(0.6, 0.62, 0.7))
	if arts_focus and arts_index >= 0 and arts_index < arts.size():
		_draw_art_details(font, arts[arts_index], panel)


## Tab in the combo bar: the chosen Art's details in a box above the Arts
## panel: its recipe, cost and timing, and everything it does.
func _draw_art_details(font: Font, art: Dictionary, below: Rect2) -> void:
	var width := below.size.x
	var lines: Array = []  # [text, size, color]
	lines.append([art["recipe"], 15, Color(0.8, 0.82, 0.9)])
	var facts: PackedStringArray = ["%d AP" % int(art.get("cost", 0))]
	if String(art.get("timing", "")) != "":
		facts.append(String(art["timing"]))
	if art.get("finisher", false):
		facts.append("Finisher")
	lines.append(["  ·  ".join(facts), 15, GOLD])
	var desc: String = art.get("desc", "")
	var effects: PackedStringArray = art.get("effects", PackedStringArray())
	if not effects.is_empty():
		desc = "\n".join(_bullets(effects))  # the full details replace the one-liner
	var desc_h := font.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 16).y if desc != "" else 0.0
	var height := 44.0 + lines.size() * 22.0 + desc_h + 12.0
	var box := Rect2(below.position.x, below.position.y - height - 8.0, width, height)
	draw_style_box(_panel_style, box)
	_text(font, box.position + Vector2(14, 30), art["name"], 21, art["color"])
	var y := box.position.y + 56.0
	for line in lines:
		_text(font, Vector2(box.position.x + 14, y), line[0], line[1], line[2])
		y += 22.0
	if desc != "":
		var pos := Vector2(box.position.x + 14, y - 4 + font.get_ascent(16))
		draw_multiline_string_outline(font, pos, desc, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 16, -1, 4, Color.BLACK)
		draw_multiline_string(font, pos, desc, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 16, -1, Color(0.92, 0.92, 0.95))


## The highlighted move or Ability, explained: a box left of the list with
## its cost and timing and everything it does (MoveInfo). Toggled in the
## pause menu (Settings.move_details).
func _draw_move_details(font: Font, move: Dictionary, beside: Rect2) -> void:
	var width := minf(420.0, beside.position.x - 20.0)
	if width < 220.0:
		return  # no room on a narrow window
	var lines := MoveInfo.lines(move)
	var tag: Array = move_tags[move_index] if move_index < move_tags.size() else []
	if not tag.is_empty():
		lines.insert(0, "NOW: " + String(tag[2]))
	var text := "\n".join(_bullets(lines))
	var body_size := 16
	var body_h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, body_size).y
	var height := 70.0 + body_h + 34.0
	# Bottom-aligned with the list, growing upward, but never down over the
	# party's HP bars in the bottom-left corner.
	var bottom := minf(beside.end.y, size.y - 268.0)
	var box := Rect2(beside.position.x - width - 12.0, bottom - height, width, height)
	draw_style_box(_panel_style, box)
	_text(font, box.position + Vector2(14, 30), move["name"], 21, move["color"])
	_text(font, box.position + Vector2(14, 54), MoveInfo.summary(move), 15, GOLD)
	var pos := Vector2(box.position.x + 14, box.position.y + 70.0 + font.get_ascent(body_size))
	draw_multiline_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, body_size, -1, 4, Color.BLACK)
	draw_multiline_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, body_size, -1, Color(0.92, 0.92, 0.95))
	_text(font, Vector2(box.position.x + 14, box.end.y - 12), "Esc: turn these details off", 13, Color(0.55, 0.57, 0.65))


## A coloured pill right-aligned at "right" (green: it works now, amber:
## partly, red: it backfires), and a matching outline on the row. Returns
## the width it took.
func _answer_tag(font: Font, tag: Array, right: Vector2, row: Rect2) -> float:
	var color: Color = {1: Color(0.35, 0.9, 0.45), 0: Color(1.0, 0.75, 0.3), -1: Color(1.0, 0.4, 0.35)}.get(int(tag[1]), Color.WHITE)
	var text: String = tag[0]
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0
	var pill := Rect2(right.x - w, right.y - 10.0, w, 20.0)
	_pill(pill, Color(color, 0.25), color, 1.5)
	_text(font, pill.position + Vector2(7, 15), text, 13, color)
	draw_rect(row.grow(-1.0), Color(color, 0.8), false, 2.0)
	return w + 8.0


static func _bullets(lines: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for line in lines:
		out.append("• " + line)
	return out


## "2 two-move, 1 four-move": how many hidden Arts of each length.
func _hidden_by_length() -> String:
	if arts_hidden_sizes.is_empty():
		return "%d Arts" % arts_hidden
	var words := {2: "two", 3: "three", 4: "four", 5: "five", 6: "six", 7: "seven", 8: "eight", 9: "nine"}
	var lengths := arts_hidden_sizes.keys()
	lengths.sort()
	var parts: PackedStringArray = []
	for length in lengths:
		parts.append("%d %s-move" % [arts_hidden_sizes[length], words.get(length, str(length))])
	return ", ".join(parts)


func _draw_combo_bar(font: Font) -> void:
	# One scale for the whole combo: the combo limit fits the move list's width.
	# (Monk while building: the steps still to climb share that width.)
	var span := combo_limit
	if mode == Mode.COMBO and not step_marks.is_empty():
		span = maxf(span, step_marks[-1])
	_px = minf(PX_PER_AP, minf(MAX_BAR_PX, size.x - LEAD_IN_PX - 60.0) / maxf(span, 1.0))
	if mode == Mode.EXECUTING:
		# Zoom: the smallest block gets room for its name and timing box.
		var smallest := INF
		for entry in plan:
			if float(entry["cost"]) > 0.0:
				smallest = minf(smallest, float(entry["cost"]))
		if smallest < INF and smallest * _px < MIN_PLAY_BLOCK_PX:
			_px = maxf(_px, minf(MIN_PLAY_BLOCK_PX / smallest, PLAY_MAX_PX_PER_AP))
	# Which slots are on the bar. Building: the part before a Headbutt restart
	# folds into a small "+70 AP" tag, so the bar shows the fresh part. Playing:
	# blocks used up by a buff (or before a restart) are gone, and what comes
	# after the next restart shows up once the Headbutt lands.
	var first_visible := 0
	var last_visible := plan.size() - 1
	if mode == Mode.EXECUTING:
		first_visible = mini(consumed_slots, plan.size())
		for r in reset_slots:
			if r >= first_visible:
				last_visible = r
				break
	elif not reset_slots.is_empty():
		first_visible = reset_slots[-1] + 1
	var hidden_ap := 0.0
	for slot in mini(first_visible, plan.size()):
		hidden_ap += float(plan[slot]["cost"])
	var capacity := combo_limit
	if mode == Mode.EXECUTING:
		var shown := 0.0
		for slot in range(first_visible, last_visible + 1):
			shown += float(plan[slot]["cost"])
		capacity = maxf(shown, 10.0)  # only what's left to play in this bar
	var bar_width := capacity * _px
	# Playing a bar longer than the view: it scrolls, keeping the playhead
	# about a third of the way in.
	var scroll := 0.0
	if mode == Mode.EXECUTING:
		var view_w := minf(PLAY_VIEW_PX, size.x - LEAD_IN_PX - 80.0)
		if bar_width > view_w:
			var played := 0.0
			for slot in range(first_visible, mini(executing_slot, plan.size())):
				played += float(plan[slot]["cost"])
			if executing_slot >= 0 and executing_slot < plan.size():
				played += float(plan[executing_slot]["cost"]) * maxf(slot_progress, 0.0)
			scroll = clampf(played * _px - view_w * 0.35, 0.0, bar_width - view_w)
			bar_width = view_w
	# While building, the bar sits under the move list; while the combo plays,
	# it drops to the bottom edge of the screen.
	var bar_y := size.y - 52 if mode == Mode.EXECUTING else size.y - 232
	# Monk while building: the steps still to climb continue past the bar.
	var future := 0.0
	if mode == Mode.COMBO and not step_marks.is_empty():
		future = (step_marks[-1] - combo_limit) * _px
	var bar_x := (size.x - bar_width - future) / 2.0
	if mode == Mode.EXECUTING:
		bar_x += LEAD_IN_PX / 2.0  # keep lead-in + strip centered together
	var bar := Rect2(bar_x, bar_y, bar_width, 34)
	_origin = bar.position.x - hidden_ap * _px - scroll  # where slot 0 would start
	var origin := _origin
	var used := combo_cost() - segment_start
	var affordable := minf(combo_limit, segment_available)

	# "25 / 45 AP" above the bar, like the AP readout in Legaia.
	var header := "%d / %d AP" % [used, affordable]
	if affordable < combo_limit:
		header += "   (limit %d)" % combo_limit
	if segment_start > 0.0:
		header = "Fresh bar: " + header
	if target_name != "":
		header = "Target: %s     %s" % [target_name, header]
	var header_size := font.get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
	if mode != Mode.EXECUTING:  # the AP bar already says this during the combo
		_text(font, Vector2(bar.position.x + (bar_width - header_size.x) / 2.0, bar.position.y - 8), header, 19, GOLD)

	draw_rect(bar, Color(0.08, 0.09, 0.13, 0.92))
	# The part of the bar you can't afford right now.
	if affordable < combo_limit:
		var locked := Rect2(origin + (segment_start + affordable) * _px, bar.position.y, (combo_limit - affordable) * _px, bar.size.y)
		locked = locked.intersection(bar)
		if locked.size.x < 1.0:
			locked = Rect2(bar.end.x, bar.position.y, 0.0, bar.size.y)
		draw_rect(locked, Color(0.35, 0.12, 0.12, 0.8))
		var x := locked.position.x + 4.0
		while x < locked.end.x:
			draw_line(Vector2(x, locked.position.y), Vector2(minf(x + 10.0, locked.end.x), locked.end.y), Color(0.55, 0.2, 0.2), 1.5)
			x += 10.0

	if mode != Mode.EXECUTING and first_visible > 0:
		# Building after a Headbutt: what came before it, folded up.
		var tag := Rect2(bar.position.x - 96.0, bar.position.y, 88.0, bar.size.y)
		draw_rect(tag, Color(0.15, 0.13, 0.08, 0.95))
		draw_rect(tag, GOLD, false, 2.0)
		var tag_text := "+%d AP" % roundi(hidden_ap)
		var tag_w := font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_text(font, Vector2(tag.position.x + (tag.size.x - tag_w) / 2.0, tag.position.y + 23), tag_text, 15, GOLD)
		_text(font, Vector2(tag.position.x + 4, tag.end.y + 16), "before the Headbutt", 11, GOLD)
	var cursor := origin
	for slot in plan.size():
		var move := plan[slot]
		var segment := Rect2(cursor, bar.position.y, float(move["cost"]) * _px, bar.size.y)
		if slot < first_visible or slot > last_visible:
			cursor = segment.end.x  # folded away / not on this bar yet
			continue
		# Scrolling: only the part inside the bar's window is drawn.
		var shown := Rect2(maxf(segment.position.x, bar.position.x), segment.position.y,
				minf(segment.end.x, bar.end.x) - maxf(segment.position.x, bar.position.x), segment.size.y)
		if shown.size.x <= 1.0:
			cursor = segment.end.x
			continue
		var color: Color = move["color"]
		if mode == Mode.EXECUTING and slot < executing_slot:
			color = color.darkened(0.5)
		draw_rect(shown.grow(-2), color)
		if mode == Mode.EXECUTING and slot == executing_slot:
			draw_rect(shown.grow(-1), Color.WHITE, false, 3.0)
		# One timing box per hit, ending where that hit lands (the last one at
		# the end of the block): press J while the playhead is inside it.
		var times: Array = move["times"]
		var box_width := minf(maxf(segment.size.x * float(move["window"]), MIN_BOX_PX), segment.size.x)
		var timing: int = int(move.get("timing", 0))
		var playing := mode == Mode.EXECUTING and slot == executing_slot
		var untimed: Array = move.get("untimed", [])
		for hit in times.size():
			var hit_x := segment.position.x + segment.size.x * float(times[hit])
			if hit < untimed.size() and untimed[hit]:
				# Lands by itself (Monk's Punch / Kick): a small tick, no box.
				draw_line(Vector2(hit_x, segment.position.y + 4), Vector2(hit_x, segment.end.y - 4), Color(1, 1, 1, 0.55), 2.0)
				continue
			var box := Rect2(hit_x - box_width, segment.position.y - 3, box_width, segment.size.y + 6)
			if hit_x < bar.position.x + 1.0 or hit_x - segment.size.x * 0.75 > bar.end.x:
				continue  # scrolled out of the window
			var result := 0
			if slot < slot_results.size() and hit < (slot_results[slot] as Array).size():
				result = slot_results[slot][hit]
			var fill := _result_fill(result)
			var special := timing != 0 and hit == times.size() - 1
			if special and timing == 1:
				# HOLD (blue, rounded): a press pill, a tail to hold through,
				# and a release pill at the hit.
				var start_x := segment.position.x + segment.size.x * float(move.get("hold_start", 0.35))
				var start_box := Rect2(start_x - box_width, box.position.y, box_width, box.size.y)
				var tail := Rect2(start_x - 2.0, segment.position.y + 11, maxf(box.position.x - start_x + 4.0, 0.0), segment.size.y - 22)
				var held := playing and exec_holding
				_pill(tail, Color(HOLD_COLOR, 0.9) if held else Color(HOLD_COLOR, 0.3), HOLD_COLOR, 1.5)
				var start_fill := Color(1.0, 0.85, 0.2, 0.9) if held or result == 1 else (fill if result != 0 else Color(HOLD_COLOR, 0.35))
				_pill(start_box, start_fill, HOLD_COLOR, 3.0)
				_pill(box, fill if result != 0 else Color(HOLD_COLOR, 0.35), HOLD_COLOR, 3.0)
				_arrow(start_box.get_center(), true)   # press down
				_arrow(box.get_center(), false)        # let go
				_small_tag(font, start_box, "HOLD", HOLD_COLOR)
				_small_tag(font, box, "LET GO", HOLD_COLOR)
				continue
			elif special and timing == 2:
				# TAP (pink, diamonds): a dashed stretch where every tap counts,
				# one diamond per tap.
				var needed: int = maxi(int(move.get("taps", 1)), 1)
				var tap_x := segment.position.x + segment.size.x * float(move.get("tap_start", 0.12))
				var stretch := Rect2(tap_x, box.position.y, hit_x - tap_x, box.size.y)
				var done := exec_taps if playing else (needed if result == 1 else 0)
				draw_rect(stretch, fill if result != 0 else Color(TAP_COLOR, 0.16))
				_dashed_rect(stretch, TAP_COLOR)
				var pip_gap := stretch.size.x / (needed + 1)
				for pip in needed:
					var centre := Vector2(stretch.position.x + pip_gap * (pip + 1), stretch.end.y - 8)
					_diamond(centre, 5.0, TAP_COLOR if pip < done else Color(0.1, 0.1, 0.14), Color.WHITE)
				_small_tag(font, stretch, ("TAP %d/%d" % [done, needed]) if playing else ("TAP x%d" % needed), TAP_COLOR)
				continue
			draw_rect(box, fill)
			draw_rect(box, Color.WHITE, false, 1.5)
		# The move's name goes on top of its timing marks so it stays readable.
		var label := String(move["name"]).to_upper()
		var label_size := 14
		while label_size > 8 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x > shown.size.x - 8:
			label_size -= 1
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		if label_width <= shown.size.x - 4:
			_text(font, Vector2(shown.position.x + (shown.size.x - label_width) / 2.0, segment.position.y + 22), label, label_size, Color.WHITE)
		cursor = segment.end.x
		if reset_slots.has(slot) and slot < plan.size() - 1 and cursor <= bar.end.x:
			# Headbutt: a fresh bar comes after it.
			_text(font, Vector2(cursor - 64, bar.end.y + 30), "FRESH BAR >", 12, GOLD)
	draw_rect(bar, GOLD, false, 2.0)
	if scroll > 0.5:
		_text(font, Vector2(bar.position.x + 4, bar.position.y + 23), "◀", 16, GOLD)
	if scroll < capacity * _px - bar.size.x - 0.5:
		_text(font, Vector2(bar.end.x - 18, bar.position.y + 23), "▶", 16, GOLD)
	if future > 0.0:
		# The rest of the climb: a dim extension with a notch at each step.
		var ext := Rect2(bar.end.x + 2.0, bar.position.y + 4.0, future - 2.0, bar.size.y - 8.0)
		draw_rect(ext, Color(0.1, 0.1, 0.14, 0.75))
		_dashed_rect(ext, Color(GOLD, 0.55))
		for length in step_marks:
			var nx := bar.end.x + (length - combo_limit) * _px
			draw_line(Vector2(nx, bar.position.y), Vector2(nx, bar.end.y), Color(GOLD, 0.8), 2.0)
			var mark := str(int(length))
			var mark_w := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			_text(font, Vector2(nx - mark_w - 4, ext.end.y - 4), mark, 11, Color(GOLD, 0.85))
		var hint := "next step: a climb Art"
		var hint_size := 13
		while hint_size > 10 and font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x > ext.size.x - 40:
			hint_size -= 1
		if font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x <= ext.size.x - 40:
			_text(font, Vector2(ext.position.x + 6, ext.position.y + ext.size.y / 2.0 + 4), hint, hint_size, Color(0.75, 0.72, 0.6))
	if preview_main != "" or preview_perfect != "":
		# What this Art does with the Monk's climb; the Perfect part greys out
		# once a timing in it wasn't Perfect.
		var gap := "    " if preview_main != "" and preview_perfect != "" else ""
		var full := preview_main + gap + preview_perfect
		# Playing: above the party AP meter (the bar sits under it).
		var py := size.y - 130.0 if mode == Mode.EXECUTING else bar.end.y + 50.0
		# Kept in the gap between the two HP panels (party left, enemies right).
		var fs := 14
		while fs > 10 and font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 2.0 * PREVIEW_MARGIN:
			fs -= 1
		var pw := font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var px := (size.x - pw) / 2.0
		_text(font, Vector2(px, py), preview_main + gap, fs, Color(0.9, 0.88, 0.8))
		if preview_perfect != "":
			var pre_w := font.get_string_size(preview_main + gap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var perfect_color := Color(1.0, 0.85, 0.3) if preview_perfect_on else Color(0.5, 0.5, 0.55)
			_text(font, Vector2(px + pre_w, py), preview_perfect, fs, perfect_color)
			if not preview_perfect_on:
				var pp_w := font.get_string_size(preview_perfect, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_line(Vector2(px + pre_w, py - 5), Vector2(px + pre_w + pp_w, py - 5), perfect_color, 2.0)

	if mode == Mode.EXECUTING:
		# "READY" lead-in: the playhead crosses it first, so you can see it
		# coming before the first move starts.
		var lead := Rect2(bar.position.x - LEAD_IN_PX - 4.0, bar.position.y, LEAD_IN_PX, bar.size.y)
		var in_lead := lead_in_progress >= 0.0
		draw_rect(lead, Color(0.15, 0.16, 0.22, 0.95) if in_lead else Color(0.1, 0.1, 0.14, 0.7))
		draw_rect(lead, GOLD if in_lead else Color(GOLD, 0.4), false, 2.0)
		var ready_width := font.get_string_size("READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_text(font, Vector2(lead.position.x + (lead.size.x - ready_width) / 2.0, lead.position.y + 22), "READY", 14,
				Color.WHITE if in_lead else Color(0.6, 0.6, 0.65))
		if in_lead:
			var lx := lead.position.x + lead.size.x * lead_in_progress
			draw_line(Vector2(lx, lead.position.y - 5), Vector2(lx, lead.end.y + 5), Color(1, 1, 1, 0.35), 7.0)
			draw_line(Vector2(lx, lead.position.y - 5), Vector2(lx, lead.end.y + 5), Color.WHITE, 3.0)

	if mode == Mode.EXECUTING and reveal_name != "":
		_draw_reveal(font, bar)
	if mode == Mode.EXECUTING and executing_slot >= 0 and lead_in_progress < 0.0:
		# Playhead: where in the combo we are right now.
		var x := cursor  # past the last move = finished
		if executing_slot < plan.size():
			var start := origin
			for slot in executing_slot:
				start += float(plan[slot]["cost"]) * _px
			var width := float(plan[executing_slot]["cost"]) * _px
			x = start + width * slot_progress
		draw_line(Vector2(x, bar.position.y - 5), Vector2(x, bar.end.y + 5), Color(1, 1, 1, 0.35), 7.0)
		draw_line(Vector2(x, bar.position.y - 5), Vector2(x, bar.end.y + 5), Color.WHITE, 3.0)


## A hidden Art revealing itself: its block flashes white, and a "NEW ART!"
## banner with the Art's name pops up over the field, then fades.
func _draw_reveal(font: Font, bar: Rect2) -> void:
	var t := reveal_progress
	var start := _origin
	for slot in executing_slot:
		start += float(plan[slot]["cost"]) * _px
	if executing_slot < plan.size():
		var seg := Rect2(start, bar.position.y - 4, float(plan[executing_slot]["cost"]) * _px, bar.size.y + 8)
		var flash := 1.0 - t
		draw_rect(seg, Color(1, 1, 1, 0.75 * flash))
		draw_rect(seg.grow(4.0 * flash), Color(1.0, 0.9, 0.5, flash), false, 3.0)
	var appear := clampf(t / 0.15, 0.0, 1.0)
	var fade := clampf((1.0 - t) / 0.2, 0.0, 1.0)
	var alpha := minf(appear, fade)
	var y := size.y * 0.3
	var band := Rect2(0, y - 58, size.x, 92)
	draw_rect(band, Color(0, 0, 0, 0.55 * alpha))
	draw_line(Vector2(0, band.position.y), Vector2(size.x, band.position.y), Color(GOLD, alpha), 2.0)
	draw_line(Vector2(0, band.end.y), Vector2(size.x, band.end.y), Color(GOLD, alpha), 2.0)
	var small := "NEW ART!"
	var small_w := font.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_text(font, Vector2((size.x - small_w) / 2.0, y - 30), small, 20, Color(GOLD, alpha))
	var big_size := int(lerpf(30.0, 46.0, appear))
	var big_w := font.get_string_size(reveal_name, HORIZONTAL_ALIGNMENT_LEFT, -1, big_size).x
	_text(font, Vector2((size.x - big_w) / 2.0, y + 18), reveal_name, big_size, Color(1, 1, 1, alpha))


## The Monk's step banner: big words across the upper field, fading out.
func _draw_banner(font: Font) -> void:
	var t := banner_left / BANNER_SECONDS
	var alpha := clampf(minf(t / 0.25, (1.0 - t) / 0.1), 0.0, 1.0)
	var y := size.y * 0.36
	var band := Rect2(0, y - 40, size.x, 58)
	draw_rect(band, Color(0, 0, 0, 0.45 * alpha))
	var w := font.get_string_size(banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	_text(font, Vector2((size.x - w) / 2.0, y + 2), banner_text, 34, Color(banner_color, alpha))


func _result_fill(result: int) -> Color:
	match result:
		1:
			return Color(1.0, 0.85, 0.2, 0.85)  # Perfect
		2:
			return Color(1.0, 0.25, 0.2, 0.85)  # miss
		3:
			return Color(0.75, 0.7, 0.55, 0.7)  # partial (Hold / Tap without the Perfect)
	return Color(1, 1, 1, 0.25)


## A tiny label just under a timing box ("HOLD", "LET GO", "TAP 2/5"); the
## AP meter sits right above the bar while a combo plays.
func _small_tag(font: Font, box: Rect2, text: String, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_text(font, Vector2(box.get_center().x - width / 2.0, box.end.y + 13), text, 12, color.lightened(0.25))


## A rounded box (Hold timings).
func _pill(rect: Rect2, fill: Color, outline: Color, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(int(width))
	style.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) / 2.0))
	style.anti_aliasing = true
	draw_style_box(style, rect)


## A small triangle: pointing down (press) or up (let go).
func _arrow(centre: Vector2, down: bool) -> void:
	var d := 1.0 if down else -1.0
	var points := PackedVector2Array([centre + Vector2(-5, -3 * d), centre + Vector2(5, -3 * d), centre + Vector2(0, 4 * d)])
	draw_colored_polygon(points, Color.WHITE)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(0, 0, 0, 0.8), 1.0)


## A diamond (Tap timings).
func _diamond(centre: Vector2, r: float, fill: Color, outline: Color) -> void:
	var points := PackedVector2Array([centre + Vector2(0, -r), centre + Vector2(r, 0), centre + Vector2(0, r), centre + Vector2(-r, 0)])
	draw_colored_polygon(points, fill)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), outline, 1.2)


func _dashed_rect(rect: Rect2, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for k in 4:
		draw_dashed_line(corners[k], corners[(k + 1) % 4], color, 2.0, 5.0)


## The badge on a move's row in the list: HOLD (blue pill) or TAP 5 (pink,
## with a diamond). Press moves have none.
func _timing_badge(font: Font, move: Dictionary, right: Vector2, dim: bool) -> void:
	var timing: int = int(move.get("timing", 0))
	if timing == 0:
		return
	var text := "HOLD" if timing == 1 else "TAP %d" % int(move.get("taps", 0))
	var color := HOLD_COLOR if timing == 1 else TAP_COLOR
	if dim:
		color = color.darkened(0.45)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + (32.0 if timing == 2 else 20.0)
	var rect := Rect2(right.x - width, right.y - 11, width, 22)
	if timing == 1:
		_pill(rect, Color(color, 0.3), color, 2.0)
		_text(font, rect.position + Vector2(10, 16), text, 15, Color.WHITE)
	else:
		draw_rect(rect, Color(color, 0.25))
		_dashed_rect(rect, color)
		_diamond(rect.position + Vector2(12, 11), 5.0, color, Color.WHITE)
		_text(font, rect.position + Vector2(22, 16), text, 15, Color.WHITE)


func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
