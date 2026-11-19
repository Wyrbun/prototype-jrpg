class_name FieldTransition
extends Control
## The short battle transition, in the spirit of older games (an original
## take): a white flash, then black bands slide across the screen from
## alternate sides until it's covered. It gives the music time to change.

signal finished

var seconds := 0.9
const BANDS := 9
const FLASH := 0.12
var _t := 0.0
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= seconds and not _done:
		_done = true
		finished.emit()


func _draw() -> void:
	# The flash, fading.
	if _t < FLASH * 2.0:
		var a := 1.0 - absf(_t - FLASH) / FLASH
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.97, 0.9, clampf(a, 0.0, 1.0) * 0.8))
	var slide := clampf((_t - FLASH) / maxf(seconds - FLASH, 0.01), 0.0, 1.0)
	var h := size.y / BANDS
	for i in BANDS:
		# Each band starts a little after the one before.
		var k := clampf(slide * 1.4 - i * 0.4 / BANDS, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		var w := size.x * k
		var x := 0.0 if i % 2 == 0 else size.x - w
		draw_rect(Rect2(x, i * h, w, h + 1.0), Color(0.02, 0.02, 0.03))
