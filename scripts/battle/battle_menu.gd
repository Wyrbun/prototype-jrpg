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
		_text(font, panel.position + Vector2(16, 50), "J / Enter: confirm     K / Backspace: back", 15, Color(0.75, 0.75, 0.8))


# --- Command menu ----------------------------------------------------------

func _draw_commands(font: Font) -> void:
	var panel := Rect2(40, 200, 280, 40 + commands.size() * 38)
	var dimmed := mode != Mode.COMMANDS
	_text(font, panel.position + Vector2(4, -12), fighter_name, 22, GOLD)
	# Reaction reminders, only for what this class can do (stacked upward).
	var reminder_y := -10.0
	if show_parry:
		_text(font, panel.position + Vector2(panel.size.x - 110, reminder_y), "Parry: E", 15, Color(1.0, 0.85, 0.3))
		reminder_y -= 20.0
	if show_defend:
		_text(font, panel.position + Vector2(panel.size.x - 110, reminder_y), "Defend: Q", 15, Color(0.6, 0.8, 1.0))
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
		if i == move_index:
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
		var label := String(move["name"]).to_upper()
		var label_size := 14
		while label_size > 8 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x > segment.size.x - 8:
			label_size -= 1
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		_text(font, Vector2(segment.position.x + (segment.size.x - label_width) / 2.0, segment.position.y + 22), label, label_size, Color.WHITE)
		# One timing box per hit, ending where that hit lands (the last one at
		# the end of the block): press J while the playhead is inside it.
		var times: Array = move["times"]
		var box_width := segment.size.x * float(move["window"])
		for hit in times.size():
			var hit_x := segment.position.x + segment.size.x * float(times[hit])
			var box := Rect2(hit_x - box_width, segment.position.y - 3, box_width, segment.size.y + 6)
			var result := 0
			if slot < slot_results.size() and hit < (slot_results[slot] as Array).size():
				result = slot_results[slot][hit]
			var fill := Color(1, 1, 1, 0.25)
			if result == 1:
				fill = Color(1.0, 0.85, 0.2, 0.85)
			elif result == 2:
				fill = Color(1.0, 0.25, 0.2, 0.85)
			draw_rect(box, fill)
			draw_rect(box, Color.WHITE, false, 1.5)
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


func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
