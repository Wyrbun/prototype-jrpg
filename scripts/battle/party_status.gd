class_name PartyStatus
extends Control
## Draws the party's HP bars in the bottom-left corner.
##
## Green is current HP. The pale chunk right after it is recoverable HP:
## damage taken while defending, which comes back at that fighter's next
## turn if they don't get hit again first.

const ROW_HEIGHT := 30.0
const BAR_X := 84.0
const BAR_WIDTH := 170.0
const BAR_HEIGHT := 14.0

var party: Array[Combatant] = []
var controlled: Combatant = null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in party.size():
		var c := party[i]
		var y := i * ROW_HEIGHT
		var name_color := Color(0.5, 0.5, 0.5) if c.is_down else (Color(1.0, 0.82, 0.2) if c == controlled else Color.WHITE)
		_text(font, Vector2(0, y + 17), c.display_name, 17, name_color)

		var bar := Rect2(BAR_X, y + 5, BAR_WIDTH, BAR_HEIGHT)
		draw_rect(bar, Color(0.08, 0.09, 0.13, 0.85))
		var hp_width := BAR_WIDTH * float(c.hp) / c.max_hp
		var recoverable_width := BAR_WIDTH * float(c.recoverable) / c.max_hp
		var hp_color := Color(0.35, 0.85, 0.4) if float(c.hp) / c.max_hp > 0.3 else Color(0.95, 0.35, 0.25)
		draw_rect(Rect2(bar.position, Vector2(hp_width, BAR_HEIGHT)), hp_color)
		draw_rect(Rect2(bar.position + Vector2(hp_width, 0), Vector2(recoverable_width, BAR_HEIGHT)), Color(1, 1, 1, 0.45))
		draw_rect(bar, Color(0.8, 0.8, 0.9), false, 1.5)

		var hp_text := "DOWN" if c.is_down else "%d / %d" % [c.hp, c.max_hp]
		_text(font, Vector2(bar.end.x + 10, y + 17), hp_text, 15, name_color)


func _text(font: Font, pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
