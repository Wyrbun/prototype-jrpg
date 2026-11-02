class_name PartyStatus
extends Control
## Draws the party's HP bars in the bottom-left corner (the enemy panel
## uses it too, bottom-right).
##
## Rows stack up from the bottom edge, so 1 to 6 fighters all sit right
## above the AP meter; with more than MAX_ROWS the rows squeeze together.
##
## Green is current HP. The pale chunk right after it is recoverable HP:
## damage taken while defending, which comes back at that fighter's next
## turn if they don't get hit again first.

const ROW_HEIGHT := 30.0
## Rows that fit at full height (the control is sized for six).
const MAX_ROWS := 6
## Where bars start at the least; pushed right for long names.
const BAR_X := 84.0
const BAR_WIDTH := 170.0
const BAR_HEIGHT := 14.0

var party: Array[Combatant] = []
var controlled: Combatant = null
## Effect tags (BRACE 2, SHIELD 26...) go after the HP numbers, or to the
## left of the name for the enemy panel on the right edge.
var tags_on_left := false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Bars start after the longest name, so names like "Stone Golem" fit.
	var bar_x := BAR_X
	for c in party:
		bar_x = maxf(bar_x, font.get_string_size(c.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 12.0)
	var row_height := ROW_HEIGHT if party.size() <= MAX_ROWS else size.y / party.size()
	var top := size.y - party.size() * row_height
	for i in party.size():
		var c := party[i]
		var y := top + i * row_height
		var name_color := Color(0.5, 0.5, 0.5) if c.is_down else (Color(1.0, 0.82, 0.2) if c == controlled else Color.WHITE)
		_text(font, Vector2(0, y + 17), c.display_name, 17, name_color)

		var bar := Rect2(bar_x, y + 5, BAR_WIDTH, BAR_HEIGHT)
		draw_rect(bar, Color(0.08, 0.09, 0.13, 0.85))
		var hp_width := BAR_WIDTH * float(c.hp) / c.max_hp
		var recoverable_width := BAR_WIDTH * float(c.recoverable) / c.max_hp
		var hp_color := Color(0.35, 0.85, 0.4) if float(c.hp) / c.max_hp > 0.3 else Color(0.95, 0.35, 0.25)
		draw_rect(Rect2(bar.position, Vector2(hp_width, BAR_HEIGHT)), hp_color)
		draw_rect(Rect2(bar.position + Vector2(hp_width, 0), Vector2(recoverable_width, BAR_HEIGHT)), Color(1, 1, 1, 0.45))
		draw_rect(bar, Color(0.8, 0.8, 0.9), false, 1.5)

		if c.shield > 0 and not c.is_down:
			# Barrier/shield: a light-blue strip along the top of the bar.
			var shield_width := minf(BAR_WIDTH * float(c.shield) / c.max_hp, BAR_WIDTH)
			draw_rect(Rect2(bar.position, Vector2(shield_width, 4)), Color(0.55, 0.8, 1.0))

		var hp_text := "DOWN" if c.is_down else "%d / %d" % [c.hp, c.max_hp]
		_text(font, Vector2(bar.end.x + 10, y + 17), hp_text, 15, name_color)
		var tags := "" if c.is_down else c.status_text()
		if tags != "" and tags_on_left:
			var width := font.get_string_size(tags, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			_text(font, Vector2(-width - 10, y + 17), tags, 13, Color(1.0, 0.6, 0.45))
		elif tags != "":
			_text(font, Vector2(bar.end.x + 92, y + 17), tags, 13, Color(0.6, 0.85, 1.0))


func _text(font: Font, pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
