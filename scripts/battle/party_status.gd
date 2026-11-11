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

const ROW_HEIGHT := 34.0
## Party rows get a second line under the HP bar for effect tags (BRACE 2,
## BAR 80 RUSH...), so they never run into the AP meter beside the panel.
const TAG_ROW_HEIGHT := 50.0
## Rows that fit at full height (the control is sized for six).
const MAX_ROWS := 6
## Where bars start at the least; pushed right for long names.
const BAR_X := 96.0
const BAR_WIDTH := 210.0
const BAR_HEIGHT := 16.0

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
		bar_x = maxf(bar_x, font.get_string_size(c.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 12.0)
	var row_height := ROW_HEIGHT if party.size() <= MAX_ROWS else size.y / party.size()
	if not tags_on_left and party.size() * TAG_ROW_HEIGHT <= size.y:
		row_height = TAG_ROW_HEIGHT
	var top := size.y - party.size() * row_height
	for i in party.size():
		var c := party[i]
		var y := top + i * row_height
		var name_color := Color(0.5, 0.5, 0.5) if c.is_down else (Color(1.0, 0.82, 0.2) if c == controlled else Color.WHITE)
		_text(font, Vector2(0, y + 19), c.display_name, 19, name_color)

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

		var stagger := c.stagger_view() if c.team == Combatant.Team.ENEMY else {}
		if not stagger.is_empty():
			_stagger_bar(Rect2(bar.position.x, bar.end.y + 3, BAR_WIDTH, 6), stagger)

		var hp_text := "DOWN" if c.is_down else "%d / %d" % [c.hp, c.max_hp]
		_text(font, Vector2(bar.end.x + 10, y + 19), hp_text, 17, name_color)
		var tags := "" if c.is_down else c.status_text()
		if tags != "" and tags_on_left:
			var width := font.get_string_size(tags, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			_text(font, Vector2(-width - 10, y + 19), tags, 15, Color(1.0, 0.6, 0.45))
		elif tags != "":
			# Under the bar, inside the panel: smaller type for a long line,
			# then cut with an ellipsis rather than spill over the AP meter.
			var room := size.x - bar.position.x
			var tag_size := 14
			while tag_size > 11 and font.get_string_size(tags, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x > room:
				tag_size -= 1
			while tags.length() > 4 and font.get_string_size(tags, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x > room:
				tags = tags.substr(0, tags.length() - 2) + "…"
			_text(font, Vector2(bar.position.x, y + 39), tags, tag_size, Color(0.6, 0.85, 1.0))


## The Stagger bar under an enemy's HP: gold, flashing when nearly full;
## split into pips when it counts hits (Healing Ritual).
func _stagger_bar(rect: Rect2, view: Dictionary) -> void:
	draw_stagger_bar(self, rect, view, Time.get_ticks_msec() / 1000.0)


## Shared with the timeline bar.
static func draw_stagger_bar(canvas: CanvasItem, rect: Rect2, view: Dictionary, now: float) -> void:
	var share := clampf(float(view["fill"]) / maxf(float(view["max"]), 1.0), 0.0, 1.0)
	var gold := Color(1.0, 0.78, 0.25)
	if share >= 0.75 and share < 1.0:
		gold = gold.lerp(Color.WHITE, 0.5 + 0.5 * sin(now * 14.0))  # nearly there
	canvas.draw_rect(rect, Color(0.08, 0.07, 0.04, 0.9))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * share, rect.size.y)), gold)
	if view.get("hits", false):
		var pips := int(view["max"])
		for k in range(1, pips):
			var x := rect.position.x + rect.size.x * k / pips
			canvas.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color.BLACK, 2.0)
	canvas.draw_rect(rect, Color(1.0, 0.85, 0.4), false, 1.0)


func _text(font: Font, pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
