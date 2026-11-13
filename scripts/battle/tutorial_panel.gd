class_name TutorialPanel
extends Control
## The tutorial's note box, top right: lesson title, explanation, and either
## the current goal or "J / Enter / Space: continue". Key names in
## {braces} are filled in with the player's keys (see Keybinds).

const GOLD := Color(0.95, 0.78, 0.35)
const WIDTH := 430.0
const PAD := 16.0

var lesson := ""
var body := ""
var goal := ""
var goal_done := false
## Lesson number and total, for "3 / 9".
var lesson_number := 0
var lesson_total := 0
## While a combo bar or menu is open, only the title and goal show, so the
## panel stays clear of the move list and the Arts panel below it.
var compact := false

var _style: StyleBoxFlat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.06, 0.07, 0.11, 0.92)
	_style.border_color = GOLD
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(6)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if body == "":
		return
	var font := ThemeDB.fallback_font
	var inner := WIDTH - PAD * 2.0
	var text := Keybinds.fill(body)
	var goal_text := Keybinds.fill(goal)
	if compact and goal_text != "":
		text = ""
	var body_size := Vector2.ZERO if text == "" else font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner, 16)
	var footer := "GOAL: " + goal_text if goal_text != "" else Keybinds.fill("{confirm} / Enter / {begin}: continue")
	var footer_size := font.get_multiline_string_size(footer, HORIZONTAL_ALIGNMENT_LEFT, inner - 24.0, 17)
	var height := PAD + 22.0 + 12.0 + body_size.y + 16.0 + footer_size.y + PAD
	if text == "":
		height -= 12.0
	var box := Rect2(size.x - WIDTH - 20.0, 96.0, WIDTH, height)
	HudStyle.draw_panel(self, box, 0.94)

	var x := box.position.x + PAD
	var title_baseline := box.position.y + PAD + 18.0
	HudStyle.draw_header(self, Vector2(x, title_baseline), lesson, 21, GOLD)
	if lesson_total > 0:
		var count := "%d / %d" % [lesson_number, lesson_total]
		var count_width := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_line(font, Vector2(box.end.x - PAD - count_width, title_baseline), count, 14, Color(0.6, 0.6, 0.65))
	var body_top := title_baseline + (16.0 if text != "" else 4.0)
	if text != "":
		draw_multiline_string(font, Vector2(x, body_top + font.get_ascent(16)), text, HORIZONTAL_ALIGNMENT_LEFT, inner, 16, -1, Color(0.92, 0.92, 0.95))
	var y := body_top + body_size.y + 8.0
	draw_line(Vector2(x, y), Vector2(box.end.x - PAD, y), Color(HudStyle.EDGE, 0.35), 1.0)
	y += 6.0
	var color := Color(0.6, 0.6, 0.65)
	if goal_text != "":
		color = Color(0.5, 0.95, 0.55) if goal_done else Color(1.0, 0.9, 0.55)
		var mark := Rect2(x, y + 5.0, 14.0, 14.0)
		draw_rect(mark, color, goal_done)
		if not goal_done:
			draw_rect(mark, color, false, 2.0)
	var footer_x := x + (24.0 if goal_text != "" else 0.0)
	draw_multiline_string_outline(font, Vector2(footer_x, y + font.get_ascent(17)), footer, HORIZONTAL_ALIGNMENT_LEFT, inner - 24.0, 17, -1, 4, Color.BLACK)
	draw_multiline_string(font, Vector2(footer_x, y + font.get_ascent(17)), footer, HORIZONTAL_ALIGNMENT_LEFT, inner - 24.0, 17, -1, color)


func _line(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
