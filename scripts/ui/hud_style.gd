class_name HudStyle
extends RefCounted
## The HUD's shared look, matching the timeline bar: deep navy panels with a
## blue sheen and a pale blue-white frame, bold slanted lettering for titles,
## and glossy gradient gauges with segment ticks.
##
## Everything here is static: call HudStyle.draw_panel(self, rect) from any
## Control's _draw().

const NAVY := Color(0.04, 0.08, 0.24)
const NAVY_DEEP := Color(0.02, 0.04, 0.12)
const BLUE := Color(0.2, 0.45, 0.95)
const EDGE := Color(0.82, 0.9, 1.0)
const OUTLINE := Color(0.02, 0.05, 0.18)
const GOLD := Color(1.0, 0.85, 0.4)

static var _header_font: FontVariation = null
static var _bold_font: FontVariation = null
## How far titles lean (x shift per pixel of height, up is negative y).
const SLANT := -0.22
## Titles this size and up get the bold slanted look; smaller text stays plain.
const SLANT_FROM := 24
static var _panel_style: StyleBoxFlat = null


## Bold, slanted lettering (WAIT / CAST / ACT, titles, names).
static func header_font() -> FontVariation:
	if _header_font == null:
		_header_font = FontVariation.new()
		_header_font.base_font = ThemeDB.fallback_font
		_header_font.variation_embolden = 0.9
		_header_font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.22, 1.0), Vector2.ZERO)
	return _header_font


## A panel: navy, brighter at the top, a gloss band, a blue accent line along
## the top edge and a pale frame. alpha: how see-through the body is.
static func draw_panel(canvas: CanvasItem, rect: Rect2, alpha := 0.92) -> void:
	if _panel_style == null:
		_panel_style = StyleBoxFlat.new()
		_panel_style.set_corner_radius_all(4)
		_panel_style.shadow_color = Color(0, 0, 0, 0.35)
		_panel_style.shadow_size = 6
		_panel_style.anti_aliasing = true
	_panel_style.bg_color = Color(NAVY_DEEP, alpha)
	canvas.draw_style_box(_panel_style, rect)
	var inner := rect.grow(-2.0)
	var top := Color(NAVY.lightened(0.12), alpha)
	var bottom := Color(NAVY_DEEP, alpha)
	canvas.draw_polygon(_corners(inner), PackedColorArray([top, top, bottom, bottom]))
	# Gloss on the upper part, fading out.
	var gloss := Rect2(inner.position, Vector2(inner.size.x, minf(inner.size.y * 0.4, 46.0)))
	var g0 := Color(1, 1, 1, 0.09 * alpha)
	var g1 := Color(1, 1, 1, 0.0)
	canvas.draw_polygon(_corners(gloss), PackedColorArray([g0, g0, g1, g1]))
	# Accent line along the top: bright blue fading to the right.
	var accent := Rect2(inner.position, Vector2(inner.size.x, 3.0))
	canvas.draw_polygon(_corners(accent), PackedColorArray([BLUE.lightened(0.25), Color(BLUE, 0.15), Color(BLUE, 0.15), BLUE.lightened(0.25)]))
	canvas.draw_rect(rect, Color(OUTLINE, 0.9), false, 4.0)
	canvas.draw_rect(rect, EDGE, false, 1.5)


## The highlighted row of a list: a gold wash fading to the right, with a
## bright edge on the left.
static func draw_selection(canvas: CanvasItem, rect: Rect2, color := GOLD) -> void:
	var a := Color(color, 0.42)
	var b := Color(color, 0.0)
	canvas.draw_polygon(_corners(rect), PackedColorArray([a, b, b, a]))
	canvas.draw_rect(Rect2(rect.position, Vector2(4.0, rect.size.y)), color)


## A gauge (HP and the like): dark trough, gradient fill in the colour, gloss
## on top, small ticks every 10%, a pale frame.
static func draw_gauge(canvas: CanvasItem, rect: Rect2, share: float, color: Color, ticks := 10) -> void:
	canvas.draw_rect(rect.grow(2.0), Color(OUTLINE, 0.85))
	canvas.draw_rect(rect, Color(0.03, 0.05, 0.12, 0.9))
	var fill := Rect2(rect.position, Vector2(rect.size.x * clampf(share, 0.0, 1.0), rect.size.y))
	if fill.size.x > 0.0:
		var dark := color.darkened(0.2)
		var bright := color.lightened(0.25)
		canvas.draw_polygon(_corners(fill), PackedColorArray([dark, bright, bright.darkened(0.15), dark.darkened(0.15)]))
		canvas.draw_rect(Rect2(fill.position + Vector2(0, 1), Vector2(fill.size.x, fill.size.y * 0.38)), Color(1, 1, 1, 0.25))
	for k in range(1, ticks):
		var x := rect.position.x + rect.size.x * k / ticks
		canvas.draw_line(Vector2(x, rect.position.y + 2.0), Vector2(x, rect.end.y - 2.0), Color(0, 0, 0.1, 0.25), 1.0)
	canvas.draw_rect(rect, EDGE, false, 1.0)


## Title text: bold, slanted by a skew of the drawing itself (so it slants
## at any size), with a thick navy outline. pos is the baseline start.
## Smaller text (under SLANT_FROM) stays upright in the plain font: bold and
## slanted lettering gets wavy and hard to read at small sizes.
static func draw_header(canvas: CanvasItem, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	if font_size < SLANT_FROM:
		var plain := ThemeDB.fallback_font
		canvas.draw_string_outline(plain, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, OUTLINE)
		canvas.draw_string(plain, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		return
	var font := bold_font()
	canvas.draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(SLANT, 1.0), pos))
	canvas.draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(6, font_size / 5), OUTLINE)
	canvas.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


static func header_width(text: String, font_size: int) -> float:
	if font_size < SLANT_FROM:
		return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return bold_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Bold lettering without the slant (draw_header slants it itself).
static func bold_font() -> FontVariation:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = ThemeDB.fallback_font
		_bold_font.variation_embolden = 0.9
	return _bold_font


## Gives a Label the HUD's navy outline (the font stays plain and readable).
static func style_label(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", OUTLINE)


static func _corners(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
