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

const BAR_HEIGHT := 20.0
const ICON_RADIUS := 16.0
## Icons hang a little to the left of their spot, on a slanted pin.
const PIN_SLANT := 12.0
## Bar colours: deep navy at the start brightening toward the casting zone,
## which glows orange to red; a gold cap marks where turns happen.
const NAVY := Color(0.05, 0.1, 0.32)
const BLUE := Color(0.2, 0.45, 0.95)
const CAST_FROM := Color(0.95, 0.45, 0.12)
const CAST_TO := Color(0.85, 0.12, 0.1)
const CAP := Color(1.0, 0.9, 0.5)

var combatants: Array[Combatant] = []
var length: float = 100.0
## Where the casting zone begins, in timeline units.
var cast_zone_start: float = 75.0
## Windup command timing: where party members choose (-1 = classic, none).
var party_command_at: float = -1.0
var active: Combatant = null
## The fighter the player is aiming at, if any.
var target: Combatant = null
## Others the move being previewed would hit.
var also_hit: Array[Combatant] = []
var _time := 0.0
var _label_font: FontVariation = null


func _ready() -> void:
	# Bold, slanted lettering for WAIT / CAST / ACT.
	_label_font = FontVariation.new()
	_label_font.base_font = ThemeDB.fallback_font
	_label_font.variation_embolden = 1.0
	_label_font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.25, 1.0), Vector2.ZERO)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()  # redraw every frame so the icons slide smoothly


func _draw() -> void:
	var mid_y := size.y / 2.0
	var bar := Rect2(0, mid_y - BAR_HEIGHT / 2.0, size.x, BAR_HEIGHT)
	var cast_x := size.x * cast_zone_start / length
	_draw_bar_body(bar, cast_x)
	if party_command_at >= 0.0:
		# The party's command point: a gold notch on the party's side.
		var cmd_x := size.x * party_command_at / length
		var committed := false
		for c in combatants:
			if c.team == Combatant.Team.PARTY and c.has_meta("windup_target"):
				committed = true
		if committed:
			draw_rect(Rect2(cmd_x, bar.position.y, size.x - cmd_x, 4.0), Color(1.0, 0.85, 0.3, 0.8))
		_draw_divider(cmd_x, bar, Color(1.0, 0.85, 0.3))
		_draw_zone_label("COM", Vector2(cmd_x - 6.0, mid_y), Color(1.0, 0.9, 0.45), true)
	_draw_divider(cast_x, bar, Color(1.0, 0.75, 0.45))
	_draw_zone_label("WAIT", Vector2(8.0, mid_y), Color(0.85, 0.93, 1.0), false)
	_draw_zone_label("CAST", Vector2(cast_x + 8.0, mid_y), Color(1.0, 0.82, 0.6), false)
	_draw_zone_label("ACT", Vector2(size.x - 14.0, mid_y), Color(1.0, 0.95, 0.7), true)

	var font := ThemeDB.fallback_font
	for c in combatants:
		if c.is_down or c.has_meta("no_timeline"):
			continue  # knocked-out fighters (and Shadow Sprites) take no turns
		var x := clampf(c.timeline_pos / length, 0.0, 1.0) * size.x
		var direction := -1.0 if c.team == Combatant.Team.PARTY else 1.0
		var icon := Vector2(x - PIN_SLANT, mid_y + direction * (BAR_HEIGHT / 2.0 + ICON_RADIUS + 10.0))
		var radius := ICON_RADIUS * (1.3 if c == active else 1.0)

		# A slanted pin from the bar to the icon, with a small pointer on the bar.
		var edge_y := mid_y + direction * BAR_HEIGHT / 2.0
		var pin_color := Color.WHITE if c == active else Color(0.88, 0.92, 1.0)
		draw_line(Vector2(x, edge_y), icon, Color(0.02, 0.05, 0.15, 0.8), 4.0, true)
		draw_line(Vector2(x, edge_y), icon, pin_color, 2.0, true)
		var pin_tip := Vector2(x, mid_y + direction * (BAR_HEIGHT / 2.0 - 4.0))
		var pointer := PackedVector2Array([pin_tip, Vector2(x - 5.0, edge_y + direction * 5.0), Vector2(x + 5.0, edge_y + direction * 5.0)])
		draw_colored_polygon(pointer, pin_color)
		draw_polyline(PackedVector2Array([pointer[0], pointer[1], pointer[2], pointer[0]]), Color(0.02, 0.05, 0.15), 1.0, true)
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
			var stagger := c.stagger_view()
			if not stagger.is_empty():
				# Its Stagger bar, just past the skill name.
				var bar_y := icon.y + direction * (radius + 30.0) - (0.0 if direction > 0 else 5.0)
				PartyStatus.draw_stagger_bar(self, Rect2(icon.x - 24.0, bar_y, 48.0, 5.0), stagger, _time)
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
		# Monk's climb: small gold pips in a row right of the icon, one per step climbed.
		if c.climbs():
			var steps := c.bar_steps.size() - 1
			for k in steps:
				var spot := icon + Vector2(radius + 9.0 + k * 10.0, 0.0)  # in a row right of the icon
				draw_circle(spot, 4.5, Color.BLACK)
				draw_circle(spot, 3.5, Color(1.0, 0.78, 0.35) if c.bar_step() > k else Color(0.25, 0.25, 0.3))
		if c.has_meta("ability_badge"):
			_draw_ability_badge(c.get_meta("ability_badge"), icon + Vector2(-radius - 13.0, 0.0), font)
		var badge := _twin_letter(c)
		if badge != "":
			var spot := icon + Vector2(radius * 0.8, radius * 0.75)
			draw_circle(spot, 9.0, Color(0.05, 0.05, 0.08))
			draw_circle(spot, 7.5, Color(1.0, 0.85, 0.3) if c == target else Color(0.9, 0.9, 0.95))
			var badge_size := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			draw_string(font, spot + Vector2(-badge_size.x / 2.0, 4.5), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)


## The bar itself: a glossy gradient, small segment ticks across the waiting
## stretch, tall ticks every 10, and a glowing casting zone.
func _draw_bar_body(bar: Rect2, cast_x: float) -> void:
	# Soft dark shadow behind it, so it reads over a bright arena.
	draw_rect(bar.grow(4.0), Color(0.0, 0.02, 0.1, 0.45))
	_gradient_rect(Rect2(bar.position, Vector2(cast_x, bar.size.y)), NAVY, BLUE)
	_gradient_rect(Rect2(Vector2(cast_x, bar.position.y), Vector2(bar.size.x - cast_x, bar.size.y)), CAST_FROM, CAST_TO)
	# Segment ticks: the waiting stretch looks like a gauge.
	var unit := bar.size.x / length
	var inner := bar.grow_individual(0, -3.0, 0, -3.0)
	var k := 1
	while k < int(length):
		var x := unit * k
		if k % 10 == 0:
			var tall := Color(1, 1, 1, 0.85) if x < cast_x else Color(1, 0.9, 0.7, 0.8)
			draw_line(Vector2(x, bar.position.y - 4.0), Vector2(x, bar.end.y), tall, 2.0)
		elif x < cast_x:
			draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(0.02, 0.06, 0.2, 0.55), 1.0)
		k += 1
	# Gloss on the upper half and a pulsing glow over the casting zone.
	draw_rect(Rect2(bar.position + Vector2(0, 1), Vector2(bar.size.x, bar.size.y * 0.35)), Color(1, 1, 1, 0.22))
	var glow := 0.12 + 0.08 * sin(_time * 3.0)
	draw_rect(Rect2(Vector2(cast_x, bar.position.y), Vector2(bar.size.x - cast_x, bar.size.y)), Color(1, 0.8, 0.4, glow))
	# The cap at the end: where turns happen.
	draw_rect(Rect2(bar.end.x - 8.0, bar.position.y - 3.0, 8.0, bar.size.y + 6.0), CAP)
	draw_rect(bar, Color(0.9, 0.95, 1.0), false, 2.0)


## A rect shaded left to right from one colour to another.
func _gradient_rect(r: Rect2, from: Color, to: Color) -> void:
	if r.size.x <= 0.0:
		return
	var points := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(points, PackedColorArray([from, to, to.darkened(0.25), from.darkened(0.25)]))


## A zone boundary: a tall line with a glow, rising above the bar.
func _draw_divider(x: float, bar: Rect2, color: Color) -> void:
	draw_line(Vector2(x, bar.position.y - 9.0), Vector2(x, bar.end.y + 5.0), Color(color, 0.35), 7.0)
	draw_line(Vector2(x, bar.position.y - 9.0), Vector2(x, bar.end.y + 5.0), color, 2.0)


## Slanted bold zone name (WAIT / COM / CAST / ACT) over the bar, centred
## on pos.y, with a dark outline. right_aligned: it ends at pos.x.
func _draw_zone_label(text: String, pos: Vector2, color: Color, right_aligned: bool) -> void:
	var font_size := 26
	var w := _label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := pos + Vector2(-w if right_aligned else 0.0, font_size * 0.36)
	draw_string_outline(_label_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 7, Color(0.02, 0.05, 0.18))
	draw_string(_label_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## The Ability this fighter used this turn: a small diamond in its colour
## with the Ability's initial, riding on the icon until the turn ends.
func _draw_ability_badge(ability: Dictionary, spot: Vector2, font: Font) -> void:
	var tint: Color = ability.get("color", Color(1.0, 0.85, 0.3))
	var r := 12.0
	var outer := PackedVector2Array([spot + Vector2(0, -r - 2), spot + Vector2(r + 2, 0), spot + Vector2(0, r + 2), spot + Vector2(-r - 2, 0)])
	var inner := PackedVector2Array([spot + Vector2(0, -r), spot + Vector2(r, 0), spot + Vector2(0, r), spot + Vector2(-r, 0)])
	draw_colored_polygon(outer, Color(0.02, 0.05, 0.15))
	draw_colored_polygon(inner, tint)
	var letter := String(ability.get("name", "?")).left(1)
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string_outline(font, spot + Vector2(-w / 2.0, 5.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color.BLACK)
	draw_string(font, spot + Vector2(-w / 2.0, 5.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


## "A" for "Kobold Archer A": the letter that tells twins apart, or "".
func _twin_letter(c: Combatant) -> String:
	var parts := c.display_name.split(" ")
	if parts.size() < 2:
		return ""
	var last := parts[parts.size() - 1]
	if last.length() == 1 and last == last.to_upper() and last != last.to_lower():
		return last
	return ""
