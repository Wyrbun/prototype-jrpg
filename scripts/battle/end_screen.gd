class_name EndScreen
extends Control
## The end of a fight: a small panel over the frozen battle (VICTORY with its
## rank, DEFEAT, or the tutorial's end), a list of choices, and one page
## behind a choice: the fight summary after a win, what went wrong after a
## loss. W / S choose, Confirm picks, Cancel goes back from a page.
##
## The arena fills `data` (see BattleArena._end_screen_data) and listens for
## `chosen(id)`; ids: "next", "summary", "wrong", "retry", "party",
## "report", "menu", "title".

signal chosen(id: String)

const GOLD := Color(1.0, 0.85, 0.4)
const RED := Color(1.0, 0.38, 0.32)
const DIM := Color(0.72, 0.74, 0.82)
const RANK_COLORS := {"S": Color(1.0, 0.82, 0.3), "A": Color(0.55, 0.9, 1.0), "B": Color(0.6, 0.95, 0.6), "C": Color(0.8, 0.8, 0.85)}

var data := {}
var index := 0
var page := ""  # "" = the panel; "summary" / "wrong" = a page
var _age := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(info: Dictionary) -> void:
	data = info
	index = 0
	page = ""
	_age = 0.0
	queue_redraw()


func choices() -> Array:
	return data.get("choices", [])


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


## True if this key does something here (checked before handle()).
func wants(event: InputEvent) -> bool:
	if page != "":
		return event.is_action_pressed("cancel") or event.is_action_pressed("confirm")
	return not choices().is_empty() and (event.is_action_pressed("move_forward") or event.is_action_pressed("move_back") \
			or event.is_action_pressed("confirm"))


## Keys from the arena. Returns true if the event was used.
func handle(event: InputEvent) -> bool:
	Sfx.menu_keys(event)
	if page != "":
		if event.is_action_pressed("cancel") or event.is_action_pressed("confirm"):
			page = ""
			return true
		return false
	var n := choices().size()
	if n == 0:
		return false
	if event.is_action_pressed("move_forward"):
		index = (index - 1 + n) % n
	elif event.is_action_pressed("move_back"):
		index = (index + 1) % n
	elif event.is_action_pressed("confirm"):
		pick(String(choices()[index][0]))
	else:
		return false
	return true


func pick(id: String) -> void:
	if id == "summary" or id == "wrong":
		page = id
		return
	chosen.emit(id)


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	var fade := clampf(_age / 0.4, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.05, 0.45 * fade))
	if page == "summary":
		_draw_summary()
	elif page == "wrong":
		_draw_wrong()
	else:
		_draw_panel()


func _font() -> Font:
	return get_theme_default_font()


func _text(pos: Vector2, text: String, font_size: int, color: Color, centered := false) -> void:
	var font := _font()
	if centered:
		pos.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Text no wider than `width`: a smaller size (down to 13), then cut with "…".
func _text_fit(pos: Vector2, text: String, font_size: int, color: Color, width: float) -> void:
	var font := _font()
	var fs := font_size
	while fs > 13 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	while text.length() > 1 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		text = text.substr(0, text.length() - 2) + "…"
	_text(pos, text, fs, color)


func _draw_panel() -> void:
	var result := String(data.get("result", "victory"))
	var width := 460.0
	var rows := choices().size()
	var height := 190.0 + rows * 40.0
	var panel := Rect2((size.x - width) / 2.0, (size.y - height) / 2.0 - 30.0, width, height)
	HudStyle.draw_panel(self, panel)
	var banner: String = {"victory": "VICTORY", "defeat": "DEFEAT", "tutorial": "TUTORIAL COMPLETE"}.get(result, "")
	var color := RED if result == "defeat" else GOLD
	var rank := String(data.get("rank_letter", ""))
	var banner_size := 44 if result != "tutorial" else 34
	var bx := panel.position.x + 28.0
	HudStyle.draw_header(self, Vector2(bx, panel.position.y + 62.0), banner, banner_size, color)
	# Title and subtitle stop short of the rank box (long names shrink).
	var room := (panel.end.x - 130.0 if rank != "" else panel.end.x - 20.0) - bx
	_text_fit(Vector2(bx, panel.position.y + 96.0), String(data.get("title", "")), 19, Color.WHITE, room)
	_text_fit(Vector2(bx, panel.position.y + 122.0), String(data.get("subtitle", "")), 17, DIM, room)
	if rank != "":
		# The rank: one big letter on the right, the best so far under it.
		var box := Rect2(panel.end.x - 118.0, panel.position.y + 20.0, 92.0, 92.0)
		var rc: Color = RANK_COLORS.get(rank, Color.WHITE)
		draw_rect(box, Color(rc, 0.12))
		draw_rect(box, Color(rc, 0.9), false, 3.0)
		_text(Vector2(box.get_center().x, box.end.y - 18.0), rank, 64, rc, true)
		_text(Vector2(box.get_center().x, box.end.y + 22.0), "RANK", 14, DIM, true)
		var best := String(data.get("best_rank", ""))
		if best != "":
			_text(Vector2(box.get_center().x, box.end.y + 42.0), "Best: " + best, 15, DIM, true)
	var top := panel.position.y + 160.0
	for i in rows:
		var row := Rect2(panel.position.x + 18.0, top + i * 40.0, width - 36.0, 36.0)
		if i == index:
			HudStyle.draw_selection(self, row, GOLD)
			_text(row.position + Vector2(8, 25), ">", 20, GOLD)
		_text(row.position + Vector2(30, 25), String(choices()[i][1]), 21, Color.WHITE if i == index else DIM)
	var hint := String(data.get("keys", ""))
	if hint != "":
		_text(Vector2(size.x / 2.0, panel.end.y + 30.0), hint, 15, DIM, true)


func _page_rect(height: float) -> Rect2:
	var width := minf(900.0, size.x - 80.0)
	return Rect2((size.x - width) / 2.0, maxf((size.y - height) / 2.0 - 20.0, 20.0), width, height)


func _draw_summary() -> void:
	var s: Dictionary = data.get("summary", {})
	var party: Array = s.get("party", [])
	var lines: Array = s.get("totals", [])
	var p := _page_rect(250.0 + party.size() * 30.0 + 26.0 * ceili(lines.size() / 2.0))
	HudStyle.draw_panel(self, p)
	HudStyle.draw_header(self, p.position + Vector2(26, 46), "FIGHT SUMMARY", 30, GOLD)
	var rank := String(data.get("rank_letter", ""))
	_text(p.position + Vector2(p.size.x - 200, 44), "Rank %s  ·  %d / 100" % [rank, int(data.get("rank_total", 0))], 20, RANK_COLORS.get(rank, Color.WHITE))
	# The four scores as bars out of 25.
	var parts: Array = s.get("parts", [])
	var y := p.position.y + 82.0
	var col_w := (p.size.x - 52.0) / 2.0
	for i in parts.size():
		var part: Array = parts[i]
		var x := p.position.x + 26.0 + (i % 2) * col_w
		var yy := y + floorf(i / 2.0) * 46.0
		_text(Vector2(x, yy + 14), "%s  %d / 25" % [part[0], int(round(float(part[1])))], 17, Color.WHITE)
		_text(Vector2(x + 160, yy + 14), String(part[2]), 14, DIM)
		HudStyle.draw_gauge(self, Rect2(x, yy + 22, col_w - 30.0, 10), clampf(float(part[1]) / 25.0, 0.0, 1.0), GOLD, 5)
	y += 104.0
	# Party table.
	var cols := [["Member", 0.0], ["HP", 170.0], ["Dealt", 300.0], ["Taken", 400.0], ["Turns", 500.0], ["", 590.0]]
	for c in cols:
		_text(Vector2(p.position.x + 26.0 + float(c[1]), y), String(c[0]), 15, GOLD.darkened(0.1))
	y += 8.0
	for row in party:
		y += 30.0
		var values := [row[0], row[1], str(row[2]), str(row[3]), str(row[4]), row[5]]
		for k in values.size():
			_text(Vector2(p.position.x + 26.0 + float(cols[k][1]), y), String(values[k]), 17, RED if k == 5 else Color.WHITE)
	y += 24.0
	for i in lines.size():
		var x := p.position.x + 26.0 + (i % 2) * col_w
		_text(Vector2(x, y + 22.0 + floorf(i / 2.0) * 26.0), String(lines[i]), 16, DIM.lightened(0.15))
	_text(Vector2(p.get_center().x, p.end.y + 28.0), Keybinds.fill("{cancel}: back"), 15, DIM, true)


func _draw_wrong() -> void:
	var w: Dictionary = data.get("wrong", {})
	var foes: Array = w.get("enemies", [])
	var top: Array = w.get("top", [])
	var downs: Array = w.get("downs", [])
	var tip := String(w.get("tip", ""))
	var p := _page_rect(175.0 + foes.size() * 34.0 + top.size() * 28.0 + downs.size() * 26.0 + (70.0 if tip != "" else 0.0))
	HudStyle.draw_panel(self, p)
	HudStyle.draw_header(self, p.position + Vector2(26, 46), "WHAT WENT WRONG", 30, RED)
	var y := p.position.y + 80.0
	for foe in foes:
		_text(Vector2(p.position.x + 26, y + 14), "%s  %d / %d" % [foe[0], int(foe[1]), int(foe[2])], 17, Color.WHITE)
		HudStyle.draw_gauge(self, Rect2(p.position.x + 330, y + 2, p.size.x - 360, 14), float(foe[1]) / maxf(float(foe[2]), 1.0), RED, 10)
		y += 34.0
	y += 12.0
	_text(Vector2(p.position.x + 26, y), "What hurt most", 16, GOLD.darkened(0.1))
	for entry in top:
		y += 28.0
		_text(Vector2(p.position.x + 40, y), String(entry[0]), 17, Color.WHITE)
		_text(Vector2(p.position.x + 470, y), "%d damage" % int(entry[1]), 17, DIM)
		if entry[2]:
			_text(Vector2(p.position.x + 620, y), "AVOIDABLE", 15, Color(1.0, 0.6, 0.35))
	y += 40.0
	_text(Vector2(p.position.x + 26, y), "Who went down", 16, GOLD.darkened(0.1))
	for entry in downs:
		y += 26.0
		_text(Vector2(p.position.x + 40, y), "%s: %s" % [entry[0], entry[1]], 17, Color.WHITE)
	if tip != "":
		y += 44.0
		_text(Vector2(p.position.x + 26, y), "TIP", 16, GOLD)
		_text(Vector2(p.position.x + 70, y), tip, 17, Color(0.85, 1.0, 0.85))
	_text(Vector2(p.get_center().x, p.end.y + 28.0), Keybinds.fill("{cancel}: back"), 15, DIM, true)
