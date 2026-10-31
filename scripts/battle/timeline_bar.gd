class_name TimelineBar
extends Control
## Draws the turn-order bar at the top of the screen.
##
## This script only draws. The battle script moves everyone along the
## timeline, and this bar shows where each fighter currently is.
## Party icons sit above the bar and enemy icons below, like Grandia.
##
## The orange stretch at the end is the casting zone. An enemy in it is
## preparing a skill: a grey ring and "???" at first, then the skill's color
## and name once it's revealed near the end of the bar.

const BAR_HEIGHT := 12.0
const ICON_RADIUS := 15.0

var combatants: Array[Combatant] = []
var length: float = 100.0
## Where the casting zone begins, in timeline units.
var cast_zone_start: float = 75.0
var active: Combatant = null


func _process(_delta: float) -> void:
	queue_redraw()  # redraw every frame so the icons slide smoothly


func _draw() -> void:
	var mid_y := size.y / 2.0
	var bar := Rect2(0, mid_y - BAR_HEIGHT / 2.0, size.x, BAR_HEIGHT)
	draw_rect(bar, Color(0.18, 0.19, 0.25))
	var cast_x := size.x * cast_zone_start / length
	draw_rect(Rect2(cast_x, bar.position.y, size.x - cast_x, BAR_HEIGHT), Color(0.95, 0.5, 0.15, 0.9))
	draw_rect(Rect2(size.x - 6.0, bar.position.y, 6.0, BAR_HEIGHT), Color(1.0, 0.92, 0.5))
	draw_rect(bar, Color(0.8, 0.8, 0.9), false, 2.0)

	var font := ThemeDB.fallback_font
	for c in combatants:
		if c.is_down:
			continue  # knocked-out fighters take no turns, so they leave the bar
		var x := clampf(c.timeline_pos / length, 0.0, 1.0) * size.x
		var direction := -1.0 if c.team == Combatant.Team.PARTY else 1.0
		var icon := Vector2(x, mid_y + direction * (BAR_HEIGHT / 2.0 + ICON_RADIUS + 6.0))
		var radius := ICON_RADIUS * (1.3 if c == active else 1.0)

		draw_line(Vector2(x, mid_y), icon, Color(0.9, 0.9, 0.95), 2.0)
		if c.loaded_skill != Skills.NONE:
			# Preparing: grey "???" until the skill is revealed.
			var skill := Skills.info(c.loaded_skill)
			var skill_color: Color = skill["color"] if c.skill_revealed else Color(0.6, 0.6, 0.65)
			draw_circle(icon, radius + 7.0, skill_color)
			var skill_name := String(skill["name"]).to_upper() if c.skill_revealed else "???"
			if c.skill_revealed and not c.loaded_shape.is_empty() and c.loaded_shape["label"] != "":
				skill_name += " (%s)" % c.loaded_shape["label"]
			var name_size := font.get_string_size(skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			var name_pos := icon + Vector2(-name_size.x / 2.0, direction * (radius + 22.0) + 5.0)
			draw_string_outline(font, name_pos, skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
			draw_string(font, name_pos, skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, skill_color)
		draw_circle(icon, radius + 2.5, Color.WHITE if c == active else Color(0.05, 0.05, 0.08))
		draw_circle(icon, radius, c.color)

		var letter := c.display_name.left(1)
		var font_size := 18
		var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_pos := icon + Vector2(-text_size.x / 2.0, font_size * 0.35)
		draw_string_outline(font, text_pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
		draw_string(font, text_pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
