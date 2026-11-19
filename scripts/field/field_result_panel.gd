class_name FieldResultPanel
extends Control
## After a fight on the field: VICTORY with the experience earned and the
## items found (enemies don't drop Credits), or the defeat. Confirm (or a
## click) goes back to exploring.

signal closed

var won := true
var experience := 0
var total_experience := 0
var drops: Array = []
## Defeat: where the party is sent (shown under the banner).
var respawn_note := ""
## A short moment before Confirm works (no skipping it by accident).
var _guard := 0.6

const GOLD := Color(0.95, 0.78, 0.35)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_guard = maxf(_guard - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _guard > 0.0:
		return
	var go: bool = event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if go:
		get_viewport().set_input_as_handled()
		Sfx.play("menu_confirm")
		close()


func close() -> void:
	closed.emit()
	queue_free()


## Items found, counted: "Potion x2, Ether".
func drops_text() -> String:
	if drops.is_empty():
		return "None"
	var counts := {}
	var order: Array = []
	for d in drops:
		if not counts.has(d):
			order.append(d)
		counts[d] = int(counts.get(d, 0)) + 1
	var parts: PackedStringArray = []
	for d in order:
		parts.append(d if counts[d] == 1 else "%s x%d" % [d, counts[d]])
	return ", ".join(parts)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var panel := Rect2((size.x - 560.0) / 2.0, size.y * 0.3, 560.0, 220.0 if won else 170.0)
	HudStyle.draw_panel(self, panel, 0.95)
	var title := "VICTORY" if won else "DEFEATED"
	HudStyle.draw_header(self, Vector2(panel.get_center().x - HudStyle.header_width(title, 40) / 2.0, panel.position.y + 56.0), title, 40, GOLD if won else Color(0.9, 0.45, 0.4))
	var x := panel.position.x + 48.0
	if won:
		_text(font, Vector2(x, panel.position.y + 106.0), "Experience", 20, Color(0.75, 0.77, 0.85))
		_text(font, Vector2(x + 200.0, panel.position.y + 106.0), "+%d   (total %d)" % [experience, total_experience], 20, Color.WHITE)
		_text(font, Vector2(x, panel.position.y + 142.0), "Items found", 20, Color(0.75, 0.77, 0.85))
		_text(font, Vector2(x + 200.0, panel.position.y + 142.0), drops_text(), 20, Color.WHITE)
	else:
		_text(font, Vector2(x, panel.position.y + 106.0), "The party has fallen.  " + respawn_note, 18, Color.WHITE)
	if _guard <= 0.0:
		var hint := Keybinds.fill("{confirm}: continue")
		var w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_text(font, Vector2(panel.get_center().x - w / 2.0, panel.end.y - 20.0), hint, 16, Color(0.6, 0.62, 0.7))


func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
