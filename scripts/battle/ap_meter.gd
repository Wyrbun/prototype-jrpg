class_name APMeter
extends Control
## The party's AP bar, drawn in code like a fighting-game super meter.
##
## - Every 100 AP of max AP is one segment, in its own colour (blue, teal,
##   gold, orange, then a shifting rainbow). Dim, outlined slots show how far
##   max AP can still grow.
## - Raising max AP sweeps the new space open with a flash and a "+5";
##   a reset cracks the extra segments off with a red flash.
## - While a combo is being built, the AP it will spend shows as a dark
##   "ghost" section; AP gained at turn start fills in with a bright tick.
## - The fill flows faster the faster AP recharges, and each tier adds an
##   effect: a passing shine (2), a pulsing glow (3), embers (4), and a
##   cycling rainbow with a bigger gold number (5).
##
## BattleArena sets value / max_value / ceiling / flow_speed / ghost_cost
## every frame and calls gain() when AP is added in one go.

const SEGMENT := 100.0
const MAX_PX_PER_AP := 1.25
const BAR_HEIGHT := 26.0
const TIER_COLORS: Array[Color] = [
	Color(0.25, 0.6, 1.0),    # 0-100 blue
	Color(0.2, 0.85, 0.8),    # 100-200 teal
	Color(1.0, 0.8, 0.25),    # 200-300 gold
	Color(1.0, 0.5, 0.15),    # 300-400 orange
	Color(1.0, 0.3, 0.6),     # 400-500 rainbow (base; it cycles)
]

## Current party AP.
var value := 0.0
## Current max AP.
var max_value := 100.0
## The most max AP can grow to this fight (empty slots are drawn up to it).
var ceiling := 200.0
## How fast the fill's texture flows (the recharge multiplier, 1 to 2).
var flow_speed := 1.0
## AP the combo being built will spend (0 when not building one).
var ghost_cost := 0.0
## Someone stands where a strike would cost max AP: the top segment pulses red.
var at_risk := false
## Seconds of Concentrate left (AP recharges twice as fast): while above 0,
## bright chevrons race along the fill, the frame pulses violet, and an
## "x2" tag with the time left sits above the bar's right end.
var boost_left := 0.0
## Shown when the next drop in max AP shatters segments.
var loss_text := "MAX AP LOST"

var _time := 0.0
var _shown_value := 0.0
var _shown_max := 100.0
var _last_max := 100.0
var _flash := 0.0          # white flash over newly opened space
var _flash_from := 0.0
var _red := 0.0            # red flash after a reset
var _shake := 0.0
var _gain_glow := 0.0      # bright tick over AP just gained
var _gain_from := 0.0
var _gain_to := 0.0
var _popups: Array[Dictionary] = []   # {"text", "x", "age", "color"}
var _shards: Array[Dictionary] = []   # {"rect", "vel", "rot", "spin", "age", "color"}
var _embers: Array[Dictionary] = []   # {"pos", "vel", "age", "life"}
var _next_shine := 2.0
var _shine := -1.0         # 0..1 progress of a passing shine, -1 = none


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown_value = value
	_shown_max = max_value
	_last_max = max_value


## AP added in one go (turn start): the gained part lights up briefly.
func gain(amount: float) -> void:
	if amount <= 0.0:
		return
	_gain_from = minf(value - amount, max_value)
	_gain_to = value
	_gain_glow = 1.0
	_popups.append({"text": "+%d" % roundi(amount), "x": _x_of(value), "age": 0.0, "color": Color(0.6, 1.0, 0.7)})


func tier() -> int:
	return clampi(ceili(max_value / SEGMENT - 0.001), 1, TIER_COLORS.size())


func _process(delta: float) -> void:
	_time += delta
	# Max AP changes: grow with a sweep and a flash, or shatter on a reset.
	if max_value > _last_max + 0.01:
		_flash_from = _last_max
		_flash = 1.0
		_popups.append({"text": "+%d" % roundi(max_value - _last_max), "x": _x_of(max_value), "age": 0.0,
				"color": _segment_color(int((max_value - 0.01) / SEGMENT), 0.0)})
	elif max_value < _last_max - 0.01:
		_shatter(max_value, _last_max)
		_shown_max = max_value
	_last_max = max_value
	_shown_max = move_toward(_shown_max, max_value, delta * 220.0)
	# The fill eases toward the real value: quick drops, a visible climb.
	if value < _shown_value:
		_shown_value = value
	else:
		_shown_value = move_toward(_shown_value, value, delta * maxf(60.0, (value - _shown_value) * 6.0))
	_flash = maxf(_flash - delta * 1.8, 0.0)
	_red = maxf(_red - delta * 1.5, 0.0)
	_shake = maxf(_shake - delta * 2.5, 0.0)
	_gain_glow = maxf(_gain_glow - delta * 1.6, 0.0)
	for popup in _popups:
		popup["age"] += delta
	_popups = _popups.filter(func(p): return p["age"] < 1.1)
	for shard in _shards:
		shard["age"] += delta
		shard["vel"] += Vector2(0, 520.0) * delta
		var rect: Rect2 = shard["rect"]
		rect.position += shard["vel"] * delta
		shard["rect"] = rect
		shard["rot"] += shard["spin"] * delta
	_shards = _shards.filter(func(s): return s["age"] < 0.9)
	_update_tier_effects(delta)
	queue_redraw()


func _update_tier_effects(delta: float) -> void:
	var t := tier()
	# Tier 2+: a shine passes along the fill every few seconds.
	if t >= 2:
		if _shine >= 0.0:
			_shine += delta / 0.9
			if _shine > 1.0:
				_shine = -1.0
		else:
			_next_shine -= delta
			if _next_shine <= 0.0:
				_shine = 0.0
				_next_shine = randf_range(2.5, 4.0) / (1.0 + 0.25 * (t - 2))
	else:
		_shine = -1.0
	# Tier 4+: embers drift up off the filled part.
	if t >= 4 and _shown_value > 1.0:
		var rate := 14.0 if t == 4 else 26.0
		if randf() < rate * delta:
			var x := lerpf(_bar_rect().position.x, _x_of(_shown_value), randf())
			_embers.append({"pos": Vector2(x, _bar_rect().position.y + 4.0), "vel": Vector2(randf_range(-12, 12), randf_range(-45, -25)),
					"age": 0.0, "life": randf_range(0.7, 1.3)})
	for ember in _embers:
		ember["age"] += delta
		ember["pos"] += ember["vel"] * delta
	_embers = _embers.filter(func(e): return e["age"] < e["life"])


# --- Layout -------------------------------------------------------------------

## The whole bar (up to the ceiling), centered in this control.
func _bar_rect() -> Rect2:
	var width := ceiling * _px()
	var shake := Vector2(sin(_time * 70.0) * 4.0 * _shake, 0.0)
	return Rect2(Vector2((size.x - width) / 2.0, size.y - BAR_HEIGHT - 4.0) + shake, Vector2(width, BAR_HEIGHT))


## Pixels per AP: 1.25, shrinking when the full bar would get too wide
## (four party members: 500 AP in at most 460 px).
func _px() -> float:
	# Never wider than the gap between the party and enemy HP panels (each
	# up to ~440 px from its edge), so big parties don't run into them.
	var room := clampf(size.x - 880.0, 220.0, 460.0)
	return minf(MAX_PX_PER_AP, minf(size.x * 0.36, room) / maxf(ceiling, 1.0))


func _x_of(ap: float) -> float:
	return _bar_rect().position.x + clampf(ap, 0.0, ceiling) * _px()


func _segment_rect(index: int) -> Rect2:
	var bar := _bar_rect()
	return Rect2(bar.position.x + index * SEGMENT * _px() + 1.0, bar.position.y, SEGMENT * _px() - 2.0, bar.size.y)


func _segment_color(index: int, x: float) -> Color:
	index = clampi(index, 0, TIER_COLORS.size() - 1)
	if index == TIER_COLORS.size() - 1:
		return Color.from_hsv(fmod(_time * 0.25 + x * 0.002, 1.0), 0.65, 1.0)  # rainbow
	return TIER_COLORS[index]


# --- Drawing --------------------------------------------------------------------

func _draw() -> void:
	var bar := _bar_rect()
	var segments := ceili(ceiling / SEGMENT - 0.001)
	var t := tier()

	# Tier 3+: a soft glow behind the filled part, pulsing harder when full.
	if t >= 3 and _shown_value > 0.0:
		var full := value >= max_value - 0.5
		var pulse := 0.5 + 0.5 * sin(_time * (5.0 if full else 2.5))
		var glow_color := _segment_color(t - 1, 0.0)
		for i in 3:
			var grow := 3.0 + i * 3.0
			var glow := Rect2(bar.position - Vector2(grow, grow), Vector2(_x_of(_shown_value) - bar.position.x + grow * 2.0, bar.size.y + grow * 2.0))
			glow_color.a = (0.10 + 0.12 * pulse * (1.6 if full else 1.0)) / (i + 1)
			draw_rect(glow, glow_color)

	# Slots: unlocked segments get a dark tinted background, locked ones are dim outlines.
	for i in segments:
		var rect := _segment_rect(i)
		var start := i * SEGMENT
		if start < _shown_max - 0.01:
			var open_part := rect
			open_part.size.x = minf(rect.size.x, (_shown_max - start) * _px() - 2.0)
			draw_rect(open_part, _segment_color(i, rect.position.x).darkened(0.8))
			if open_part.size.x < rect.size.x:
				var rest := Rect2(rect.position.x + open_part.size.x, rect.position.y, rect.size.x - open_part.size.x, rect.size.y)
				draw_rect(rest, Color(0.08, 0.08, 0.1, 0.5))
				draw_rect(rest, Color(1, 1, 1, 0.12), false, 1.0)
		else:
			draw_rect(rect, Color(0.08, 0.08, 0.1, 0.5))
			draw_rect(rect, Color(1, 1, 1, 0.12), false, 1.0)

	# The fill: each segment in its colour, with a flowing stripe texture.
	var fill_end := _x_of(minf(_shown_value, _shown_max))
	for i in segments:
		var rect := _segment_rect(i)
		var right := minf(rect.end.x, fill_end)
		if right <= rect.position.x:
			continue
		var part := Rect2(rect.position, Vector2(right - rect.position.x, rect.size.y))
		draw_rect(part, _segment_color(i, rect.position.x))
		draw_rect(Rect2(part.position, Vector2(part.size.x, part.size.y * 0.35)), Color(1, 1, 1, 0.18))  # top sheen
		var offset := fmod(_time * 22.0 * flow_speed, 18.0)
		var x := part.position.x - 18.0 + offset
		while x < part.end.x:
			var a := maxf(x, part.position.x)
			var b := minf(x + 7.0, part.end.x)
			if b > a:
				draw_rect(Rect2(a, part.position.y, b - a, part.size.y), Color(1, 1, 1, 0.09))
			x += 18.0

	# Tier 2+: a shine passing along the fill.
	if _shine >= 0.0 and fill_end > bar.position.x:
		var sx := lerpf(bar.position.x - 30.0, fill_end + 30.0, _shine)
		for k in 6:
			var w := 6.0
			var a := maxf(sx + (k - 3) * w, bar.position.x)
			var b := minf(sx + (k - 2) * w, fill_end)
			if b > a:
				draw_rect(Rect2(a, bar.position.y, b - a, bar.size.y), Color(1, 1, 1, 0.35 * (1.0 - absf(k - 2.5) / 3.0)))

	# Ghost: what the combo being built will spend.
	if ghost_cost > 0.0:
		var g0 := _x_of(maxf(value - ghost_cost, 0.0))
		var g1 := _x_of(value)
		if g1 > g0:
			var ghost := Rect2(g0, bar.position.y, g1 - g0, bar.size.y)
			draw_rect(ghost, Color(0.05, 0.05, 0.08, 0.6))
			var x := g0 - fmod(_time * 10.0, 8.0)
			while x < g1:
				var a := maxf(x, g0)
				var b := minf(x + 3.0, g1)
				if b > a:
					draw_rect(Rect2(a, bar.position.y, b - a, bar.size.y), Color(1, 1, 1, 0.08))
				x += 8.0
			draw_rect(ghost, Color(1, 1, 1, 0.55), false, 1.5)
			_text("-%d" % roundi(ghost_cost), Vector2((g0 + g1) / 2.0, bar.position.y - 6.0), 14, Color(1, 0.75, 0.6), true)

	# Turn-start gain: the new part lights up.
	if _gain_glow > 0.0:
		var a0 := _x_of(_gain_from)
		var a1 := _x_of(minf(_gain_to, _shown_value))
		if a1 > a0:
			draw_rect(Rect2(a0, bar.position.y, a1 - a0, bar.size.y), Color(1, 1, 1, 0.45 * _gain_glow))

	# Newly opened max AP flashes white.
	if _flash > 0.0:
		var f0 := _x_of(_flash_from)
		var f1 := _x_of(_shown_max)
		if f1 > f0:
			draw_rect(Rect2(f0 - 2.0, bar.position.y - 2.0, f1 - f0 + 4.0, bar.size.y + 4.0), Color(1, 1, 1, 0.8 * _flash))

	# Warning: the segment an avoidable hit would crack off pulses red.
	if at_risk and max_value > SEGMENT + 0.5:
		var r0 := _x_of(maxf(max_value - SEGMENT, SEGMENT))
		var r1 := _x_of(max_value)
		var pulse := 0.5 + 0.5 * sin(_time * 10.0)
		draw_rect(Rect2(r0, bar.position.y, r1 - r0, bar.size.y), Color(1.0, 0.1, 0.05, 0.25 + 0.35 * pulse))
		draw_rect(Rect2(r0, bar.position.y - 2.0, r1 - r0, bar.size.y + 4.0), Color(1.0, 0.2, 0.1, 0.6 + 0.4 * pulse), false, 2.0)
		_text("!", Vector2((r0 + r1) / 2.0, bar.position.y - 6.0), 18, Color(1.0, 0.3, 0.2, 0.6 + 0.4 * pulse), true)

	# Concentrate: chevrons racing right over the fill and a pulsing frame.
	if boost_left > 0.0:
		var violet := Color(0.75, 0.55, 1.0)
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		var fill_right := maxf(fill_end, bar.position.x)
		var spacing := 22.0
		var shift := fmod(_time * 90.0, spacing)
		var x := bar.position.x - spacing + shift
		while x < fill_right:
			var tip := x + 8.0
			if x > bar.position.x and tip < fill_right:
				var mid := bar.position.y + bar.size.y / 2.0
				var top := bar.position.y + 5.0
				var bottom := bar.end.y - 5.0
				draw_polyline(PackedVector2Array([Vector2(x, top), Vector2(tip, mid), Vector2(x, bottom)]),
						Color(1, 1, 1, 0.55), 2.5)
			x += spacing
		draw_rect(bar.grow(3.0 + 2.0 * pulse), Color(violet, 0.35 + 0.4 * pulse), false, 2.0)
		var tag := "x2 AP  %ds" % ceili(boost_left)
		_text(tag, Vector2(bar.end.x - 34.0, bar.position.y - 8.0), 15, Color(violet.lightened(0.3), 0.85 + 0.15 * pulse), true)

	# Segment dividers and the outer frame.
	for i in range(1, segments):
		var x := bar.position.x + i * SEGMENT * _px()
		draw_line(Vector2(x, bar.position.y - 2.0), Vector2(x, bar.end.y + 2.0), Color(0, 0, 0, 0.85), 2.0)
	draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.9), false, 2.0)
	if _red > 0.0:
		draw_rect(bar.grow(3.0), Color(1.0, 0.15, 0.1, _red), false, 3.0)
		draw_rect(bar, Color(1.0, 0.1, 0.05, 0.35 * _red))

	# Shards of a reset flying off.
	for shard in _shards:
		var rect: Rect2 = shard["rect"]
		var color: Color = shard["color"]
		color.a = 1.0 - shard["age"] / 0.9
		draw_set_transform(rect.get_center(), shard["rot"], Vector2.ONE)
		draw_rect(Rect2(-rect.size / 2.0, rect.size), color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Embers.
	for ember in _embers:
		var k: float = ember["age"] / ember["life"]
		var color := _segment_color(t - 1, ember["pos"].x).lerp(Color(1, 0.9, 0.6), 0.4)
		color.a = 1.0 - k
		draw_circle(ember["pos"], 2.2 * (1.0 - k * 0.5), color)

	# Label: bigger and gold at the top tier.
	var label := "Party AP  %d / %d" % [floori(value), int(max_value)]
	var big := t >= 5
	_text(label, Vector2(size.x / 2.0, bar.position.y + bar.size.y * 0.5 + (8.0 if big else 6.0)),
			22 if big else 17, Color(1.0, 0.85, 0.35) if big else Color.WHITE, true)

	# "+5" / "+30" popups float up and fade.
	for popup in _popups:
		var age: float = popup["age"]
		var color: Color = popup["color"]
		color.a = 1.0 - age / 1.1
		_text(popup["text"], Vector2(popup["x"], bar.position.y - 10.0 - age * 26.0), 16, color, true)


## A reset: the lost segments break into shards and fall away.
func _shatter(from_ap: float, to_ap: float) -> void:
	var bar := _bar_rect()
	_red = 1.0
	_shake = 1.0
	var x0 := _x_of(from_ap)
	var x1 := _x_of(to_ap)
	var pieces := clampi(int((x1 - x0) / 10.0), 4, 40)
	for i in pieces:
		var w := (x1 - x0) / pieces
		var x := x0 + i * w
		for row in 2:
			var rect := Rect2(x, bar.position.y + row * bar.size.y / 2.0, w - 1.0, bar.size.y / 2.0 - 1.0)
			var segment := int((x - bar.position.x) / (SEGMENT * _px()))
			_shards.append({"rect": rect, "vel": Vector2(randf_range(-80, 80), randf_range(-220, -80)),
					"rot": 0.0, "spin": randf_range(-8, 8), "age": 0.0,
					"color": _segment_color(segment, x).lerp(Color(1, 0.2, 0.15), 0.35)})
	_popups.append({"text": loss_text, "x": (x0 + x1) / 2.0, "age": 0.0, "color": Color(1, 0.35, 0.3)})
	loss_text = "MAX AP LOST"


func _text(text: String, pos: Vector2, font_size: int, color: Color, centered: bool) -> void:
	var font := ThemeDB.fallback_font
	if centered:
		pos.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, color.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
