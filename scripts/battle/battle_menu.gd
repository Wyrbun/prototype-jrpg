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
## While a hidden Art reveals itself mid-combo: its name and the banner's
## progress (0 -> 1).
var reveal_name := ""
var reveal_progress := 0.0

var _panel_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = PANEL_BG
	_panel_style.border_color = GOLD
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(6)


func _process(_delta: float) -> void:
	queue_redraw()


func combo_cost() -> float:
	var total := 0.0
	for entry in plan:
		total += float(entry["cost"])
	return total


func _draw() -> void:
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
		var panel := Rect2((size.x - 520) / 2.0, size.y - 250, 520, 62)
		draw_style_box(_panel_style, panel)
		_text(font, panel.position + Vector2(16, 27), target_prompt, 19, GOLD)
		_text(font, panel.position + Vector2(16, 50), Keybinds.fill("{confirm} / Enter: confirm     {cancel} / Backspace: back"), 15, Color(0.75, 0.75, 0.8))


# --- Command menu ----------------------------------------------------------

func _draw_commands(font: Font) -> void:
	var panel := Rect2(40, 200, 280, 40 + commands.size() * 38)
	var dimmed := mode != Mode.COMMANDS
	_text(font, panel.position + Vector2(4, -12), fighter_name, 22, GOLD)
	# Reaction reminders, only for what this class can do (stacked upward).
	var reminder_y := -10.0
	if show_parry:
		_text(font, panel.position + Vector2(panel.size.x - 110, reminder_y), Keybinds.fill("Parry: {parry}"), 15, Color(1.0, 0.85, 0.3))
		reminder_y -= 20.0
	if show_defend:
		_text(font, panel.position + Vector2(panel.size.x - 110, reminder_y), Keybinds.fill("Defend: {defend}"), 15, Color(0.6, 0.8, 1.0))
	draw_style_box(_panel_style, panel)

	for i in commands.size():
		var row := Rect2(panel.position + Vector2(10, 18 + i * 38), Vector2(panel.size.x - 20, 32))
		var selected := i == command_index
		if selected and not dimmed:
			draw_rect(row, Color(GOLD, 0.22))
			_text(font, row.position + Vector2(6, 23), ">", 20, GOLD)
		var color := Color.WHITE if command_enabled[i] else Color(0.5, 0.5, 0.55)
		if dimmed and not selected:
			color = color.darkened(0.4)
		_text(font, row.position + Vector2(28, 23), commands[i], 20, color)
		if command_notes[i] != "":
			_text(font, row.position + Vector2(140, 22), command_notes[i], 13, Color(0.6, 0.6, 0.65))


# --- Combo builder ---------------------------------------------------------

func _draw_move_list(font: Font) -> void:
	var width := 560.0
	var row_height := 30.0
	width = 600.0
	var top := size.y - 400 if mode == Mode.COMBO else size.y - 340
	var panel := Rect2((size.x - width) / 2.0, top, width, 16 + moves.size() * row_height)
	draw_style_box(_panel_style, panel)
	var room := minf(combo_limit, ap_available) - (combo_cost() if mode == Mode.COMBO else 0.0)
	for i in moves.size():
		var move := moves[i]
		var row := Rect2(panel.position + Vector2(8, 8 + i * row_height), Vector2(width - 16, row_height - 2))
		var usable := i >= move_usable.size() or move_usable[i]
		var fits := float(move["cost"]) <= room and usable
		if i == move_index and not (mode == Mode.COMBO and arts_focus):
			draw_rect(row, Color(GOLD, 0.22))
			_text(font, row.position + Vector2(6, 21), ">", 18, GOLD)
		var color := Color.WHITE if fits else Color(0.5, 0.5, 0.55)
		draw_rect(Rect2(row.position + Vector2(24, 8), Vector2(12, 12)), move["color"] if fits else Color(0.35, 0.35, 0.4))
		_text(font, row.position + Vector2(44, 21), move["name"], 17, color)
		_text(font, row.position + Vector2(200, 21), "%d AP" % move["cost"], 17, GOLD if fits else color)
		var desc: String = move["desc"]
		if not usable and i < move_notes.size() and move_notes[i] != "":
			desc = move_notes[i]
		_text(font, row.position + Vector2(270, 21), desc, 15, color.darkened(0.15))
		_timing_badge(font, move, Vector2(row.end.x - 6, row.position.y + row.size.y / 2.0), not fits)
	if mode == Mode.COMBO and (not arts.is_empty() or arts_hidden > 0):
		_draw_arts(font, panel)


## The Arts panel, right of the move list: known Arts with their recipes,
## unknown ones as "???" with only the first move. Arts the moves at the end
## of the bar are heading towards glow gold and say which move comes next.
func _draw_arts(font: Font, beside: Rect2) -> void:
	var row_height := 34.0
	var x := beside.end.x + 12.0
	var width := minf(340.0, size.x - x - 8.0)
	if width < 220.0:
		return  # no room on a narrow window
	var extra := 22.0 if arts_hidden > 0 else 0.0
	var panel := Rect2(x, beside.position.y, width, 34.0 + arts.size() * row_height + extra)
	draw_style_box(_panel_style, panel)
	_text(font, panel.position + Vector2(12, 24), "ARTS", 16, GOLD)
	var tip := "choose one to add it whole" if arts_focus else "moves in this order merge"
	_text(font, panel.position + Vector2(64, 24), tip, 12, Color(0.6, 0.62, 0.7))
	for i in arts.size():
		var art: Dictionary = arts[i]
		var row := Rect2(panel.position + Vector2(6, 32 + i * row_height), Vector2(width - 12, row_height - 2))
		var heading: bool = art["next"] != ""
		if heading:
			draw_rect(row, Color(GOLD, 0.18))
		if arts_focus and i == arts_index:
			draw_rect(row, Color(GOLD, 0.35))
			draw_rect(row, GOLD, false, 2.0)
		var name_color: Color = art["color"] if art["known"] else Color(0.55, 0.55, 0.6)
		_text(font, row.position + Vector2(8, 14), art["name"], 15, name_color)
		if art["finisher"]:
			var name_w := font.get_string_size(art["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			_text(font, row.position + Vector2(14 + name_w, 14), "FINISHER", 10, GOLD)
		_text(font, row.position + Vector2(8, 29), art["recipe"], 12, Color(0.75, 0.77, 0.85))
		if heading:
			var hint: String = "next: " + art["next"]
			var hint_w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			_text(font, Vector2(row.end.x - hint_w - 6, row.position.y + 14), hint, 12, GOLD)
	if arts_hidden > 0:
		var line := ("Hidden: " if not arts.is_empty() else "To discover: ") + _hidden_by_length()
		_text(font, Vector2(panel.position.x + 12, panel.end.y - 9), line, 12, Color(0.6, 0.62, 0.7))


## "2 two-move, 1 four-move": how many hidden Arts of each length.
func _hidden_by_length() -> String:
	if arts_hidden_sizes.is_empty():
		return "%d Arts" % arts_hidden
	var words := {2: "two", 3: "three", 4: "four", 5: "five"}
	var lengths := arts_hidden_sizes.keys()
	lengths.sort()
	var parts: PackedStringArray = []
	for length in lengths:
		parts.append("%d %s-move" % [arts_hidden_sizes[length], words.get(length, str(length))])
	return ", ".join(parts)


func _draw_combo_bar(font: Font) -> void:
	var bar_width := combo_limit * PX_PER_AP
	# While building, the bar sits under the move list; while the combo plays,
	# it drops to the bottom edge of the screen.
	var bar_y := size.y - 52 if mode == Mode.EXECUTING else size.y - 232
	var bar_x := (size.x - bar_width) / 2.0
	if mode == Mode.EXECUTING:
		bar_x += LEAD_IN_PX / 2.0  # keep lead-in + strip centered together
	var bar := Rect2(bar_x, bar_y, bar_width, 34)
	var used := combo_cost()
	var affordable := minf(combo_limit, ap_available)

	# "25 / 45 AP" above the bar, like the AP readout in Legaia.
	var header := "%d / %d AP" % [used, affordable]
	if affordable < combo_limit:
		header += "   (limit %d)" % combo_limit
	if target_name != "":
		header = "Target: %s     %s" % [target_name, header]
	var header_size := font.get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	if mode != Mode.EXECUTING:  # the AP bar already says this during the combo
		_text(font, Vector2(bar.position.x + (bar_width - header_size.x) / 2.0, bar.position.y - 8), header, 17, GOLD)

	draw_rect(bar, Color(0.08, 0.09, 0.13, 0.92))
	# The part of the bar you can't afford right now.
	if affordable < combo_limit:
		var locked := Rect2(bar.position.x + affordable * PX_PER_AP, bar.position.y, (combo_limit - affordable) * PX_PER_AP, bar.size.y)
		draw_rect(locked, Color(0.35, 0.12, 0.12, 0.8))
		var x := locked.position.x + 4.0
		while x < locked.end.x:
			draw_line(Vector2(x, locked.position.y), Vector2(minf(x + 10.0, locked.end.x), locked.end.y), Color(0.55, 0.2, 0.2), 1.5)
			x += 10.0

	var cursor := bar.position.x
	for slot in plan.size():
		var move := plan[slot]
		var segment := Rect2(cursor, bar.position.y, float(move["cost"]) * PX_PER_AP, bar.size.y)
		var color: Color = move["color"]
		if mode == Mode.EXECUTING and slot < executing_slot:
			color = color.darkened(0.5)
		draw_rect(segment.grow(-2), color)
		if mode == Mode.EXECUTING and slot == executing_slot:
			draw_rect(segment.grow(-1), Color.WHITE, false, 3.0)
		# One timing box per hit, ending where that hit lands (the last one at
		# the end of the block): press J while the playhead is inside it.
		var times: Array = move["times"]
		var box_width := segment.size.x * float(move["window"])
		var timing: int = int(move.get("timing", 0))
		var playing := mode == Mode.EXECUTING and slot == executing_slot
		for hit in times.size():
			var hit_x := segment.position.x + segment.size.x * float(times[hit])
			var box := Rect2(hit_x - box_width, segment.position.y - 3, box_width, segment.size.y + 6)
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
		while label_size > 8 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x > segment.size.x - 8:
			label_size -= 1
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		_text(font, Vector2(segment.position.x + (segment.size.x - label_width) / 2.0, segment.position.y + 22), label, label_size, Color.WHITE)
		cursor = segment.end.x
	draw_rect(bar, GOLD, false, 2.0)

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
			var start := bar.position.x
			for slot in executing_slot:
				start += float(plan[slot]["cost"]) * PX_PER_AP
			var width := float(plan[executing_slot]["cost"]) * PX_PER_AP
			x = start + width * slot_progress
		draw_line(Vector2(x, bar.position.y - 5), Vector2(x, bar.end.y + 5), Color(1, 1, 1, 0.35), 7.0)
		draw_line(Vector2(x, bar.position.y - 5), Vector2(x, bar.end.y + 5), Color.WHITE, 3.0)


## A hidden Art revealing itself: its block flashes white, and a "NEW ART!"
## banner with the Art's name pops up over the field, then fades.
func _draw_reveal(font: Font, bar: Rect2) -> void:
	var t := reveal_progress
	var start := bar.position.x
	for slot in executing_slot:
		start += float(plan[slot]["cost"]) * PX_PER_AP
	if executing_slot < plan.size():
		var seg := Rect2(start, bar.position.y - 4, float(plan[executing_slot]["cost"]) * PX_PER_AP, bar.size.y + 8)
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
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + (30.0 if timing == 2 else 18.0)
	var rect := Rect2(right.x - width, right.y - 9, width, 18)
	if timing == 1:
		_pill(rect, Color(color, 0.3), color, 2.0)
		_text(font, rect.position + Vector2(9, 14), text, 13, Color.WHITE)
	else:
		draw_rect(rect, Color(color, 0.25))
		_dashed_rect(rect, color)
		_diamond(rect.position + Vector2(11, 9), 4.5, color, Color.WHITE)
		_text(font, rect.position + Vector2(20, 14), text, 13, Color.WHITE)


func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
