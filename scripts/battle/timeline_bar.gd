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
##
## Twins ("Kobold Archer A" / "B") get their letter on a small badge, and
## the fighter the player is aiming at gets a pulsing gold ring and arrow
## (anyone else the previewed move would hit gets a thin ring).

const BAR_HEIGHT := 12.0
const ICON_RADIUS := 15.0

var combatants: Array[Combatant] = []
var length: float = 100.0
## Where the casting zone begins, in timeline units.
var cast_zone_start: float = 75.0
var active: Combatant = null
## The fighter the player is aiming at, if any.
var target: Combatant = null
## Others the move being previewed would hit.
var also_hit: Array[Combatant] = []
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
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
			var def := c.loaded_def
			var skill_color: Color = def.color() if c.skill_revealed and def else Color(0.6, 0.6, 0.65)
			draw_circle(icon, radius + 7.0, skill_color)
			var skill_name := def.skill_name.to_upper() if c.skill_revealed and def else "???"
			var name_size := font.get_string_size(skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			var name_pos := icon + Vector2(-name_size.x / 2.0, direction * (radius + 22.0) + 5.0)
			draw_string_outline(font, name_pos, skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
			draw_string(font, name_pos, skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, skill_color)
		if c == target:
			var pulse := 0.5 + 0.5 * sin(_time * 6.0)
			var gold := Color(1.0, 0.85, 0.3)
			draw_arc(icon, radius + 11.0 + pulse * 2.0, 0.0, TAU, 40, gold, 3.0, true)
			# A small arrow on the far side from the bar points at the icon.
			var tip := icon + Vector2(-(radius + 14.0), 0.0)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-10, -7), tip + Vector2(-10, 7)]), gold)
		elif also_hit.has(c):
			draw_arc(icon, radius + 10.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.3, 0.55), 2.0, true)
		draw_circle(icon, radius + 2.5, Color.WHITE if c == active else Color(0.05, 0.05, 0.08))
		draw_circle(icon, radius, c.color)

		var letter := c.icon_letter if c.icon_letter != "" else c.display_name.left(1)
		var font_size := 18
		var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_pos := icon + Vector2(-text_size.x / 2.0, font_size * 0.35)
		draw_string_outline(font, text_pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
		draw_string(font, text_pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		# Assassin's Marks: small violet diamonds beside the icon.
		for k in c.marks:
			var spot := icon + Vector2(radius + 8.0 + k * 9.0, -radius * 0.55 * direction)
			var points := PackedVector2Array([spot + Vector2(0, -4.5), spot + Vector2(4, 0), spot + Vector2(0, 4.5), spot + Vector2(-4, 0)])
			draw_colored_polygon(points, Color(0.78, 0.45, 1.0))
			draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color.BLACK, 1.0)
		var badge := _twin_letter(c)
		if badge != "":
			var spot := icon + Vector2(radius * 0.8, radius * 0.75)
			draw_circle(spot, 9.0, Color(0.05, 0.05, 0.08))
			draw_circle(spot, 7.5, Color(1.0, 0.85, 0.3) if c == target else Color(0.9, 0.9, 0.95))
			var badge_size := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			draw_string(font, spot + Vector2(-badge_size.x / 2.0, 4.5), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)


## "A" for "Kobold Archer A": the letter that tells twins apart, or "".
func _twin_letter(c: Combatant) -> String:
	var parts := c.display_name.split(" ")
	if parts.size() < 2:
		return ""
	var last := parts[parts.size() - 1]
	if last.length() == 1 and last == last.to_upper() and last != last.to_lower():
		return last
	return ""
