class_name SteerPicker
extends Control
## Hold Tab between turns: time stops and this panel lets you pick who to
## steer. A/D (or the arrows, the mouse wheel, 1-6) moves the pick; letting
## go of Tab takes control. Party members who are down are greyed out and
## skipped.

const CARD_W := 190.0
const CARD_H := 92.0
const GAP := 12.0

var party: Array[Combatant] = []
var selected: Combatant = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if party.is_empty():
		return
	var font := ThemeDB.fallback_font
	var count := party.size()
	var inner_w := count * CARD_W + (count - 1) * GAP
	var panel := Rect2((size.x - inner_w) / 2.0 - 20.0, size.y * 0.3, inner_w + 40.0, CARD_H + 104.0)
	HudStyle.draw_panel(self, panel)
	var title := "STEER WHO?"
	HudStyle.draw_header(self, Vector2(panel.position.x + (panel.size.x - HudStyle.header_width(title, 26)) / 2.0, panel.position.y + 38), title, 26, HudStyle.GOLD)
	for i in count:
		var c := party[i]
		var card := Rect2(panel.position.x + 20.0 + i * (CARD_W + GAP), panel.position.y + 54.0, CARD_W, CARD_H)
		draw_rect(card, Color(0, 0, 0, 0.25))
		if c == selected:
			HudStyle.draw_selection(self, card)
			draw_rect(card, HudStyle.GOLD, false, 2.0)
		else:
			draw_rect(card, Color(HudStyle.EDGE, 0.35), false, 1.0)
		var dim := c.is_down
		var name_color := Color(0.5, 0.5, 0.5) if dim else (HudStyle.GOLD if c == selected else Color.WHITE)
		_text(font, card.position + Vector2(12, 22), "%d" % (i + 1), 14, Color(name_color, 0.7))
		HudStyle.draw_header(self, card.position + Vector2(32, 24), c.display_name, 19, name_color)
		var role := c.class_id.capitalize()
		if role != "" and role != c.display_name:
			_text(font, card.position + Vector2(12, 46), role, 14, Color(0.75, 0.8, 0.9) if not dim else Color(0.45, 0.45, 0.45))
		var share := 0.0 if c.max_hp <= 0 else float(c.hp) / c.max_hp
		var gauge := Rect2(card.position + Vector2(12, 58), Vector2(CARD_W - 24, 10))
		HudStyle.draw_gauge(self, gauge, share, Color(0.35, 0.85, 0.4) if share > 0.3 else Color(0.95, 0.35, 0.25))
		_text(font, card.position + Vector2(12, 84), "DOWN" if dim else "%d / %d" % [c.hp, c.max_hp], 13, name_color)
	var hint := Keybinds.fill("{move_left_key} / {move_right_key} or 1-%d to choose  ·  let go of {swap} to steer" % count)
	hint = hint.replace("{move_left_key}", Keybinds.label("move_left")).replace("{move_right_key}", Keybinds.label("move_right"))
	var hint_w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(font, Vector2(panel.position.x + (panel.size.x - hint_w) / 2.0, panel.end.y - 16), hint, 15, Color(0.85, 0.9, 1.0))


func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(HudStyle.OUTLINE, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
