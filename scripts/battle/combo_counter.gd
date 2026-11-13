class_name ComboCounter
extends Control
## A fighting-game style combo counter, on the right side of the screen
## while a party combo plays: the hit count, the running damage total, and
## each hit's damage popping in (gold for a Perfect). When the combo ends the
## total stays up for a moment, then fades.
##
## BattleArena calls begin() when a combo starts, hit() for every hit that
## lands, damage() for the HP each hit takes off, and finish() at the end.

const GOLD := Color(1.0, 0.85, 0.3)

var hits := 0
var total := 0
var perfects := 0
var attacker_name := ""

var _shown := false
var _fade := 0.0          # 1 = fully visible
var _hold := 0.0          # seconds the final total stays before fading
var _bounce := 0.0        # pop on each hit
var _pops: Array[Dictionary] = []   # {"text", "age", "color", "x"}
var _hit_damage := 0
var _hit_perfect := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func begin(who: String) -> void:
	hits = 0
	total = 0
	perfects = 0
	attacker_name = who
	_pops.clear()
	_shown = true
	_hold = 0.0
	_fade = 1.0


## A hit landed (perfect = timed J). Its damage comes in through damage().
func hit(perfect: bool) -> void:
	if not _shown:
		return
	hits += 1
	if perfect:
		perfects += 1
	_bounce = 1.0
	_hit_perfect = perfect
	if _hit_damage > 0:
		_pops.append({"text": str(_hit_damage), "age": 0.0, "color": GOLD if perfect else Color.WHITE,
				"x": randf_range(-30.0, 30.0)})
	_hit_damage = 0


## HP a hit took off an enemy (called before hit(), once per enemy struck).
func damage(amount: int) -> void:
	if not _shown or amount <= 0:
		return
	total += amount
	_hit_damage += amount


## The combo is over: keep the total up for a moment, then fade it out.
func finish() -> void:
	if _shown:
		_hold = 1.6


func _process(delta: float) -> void:
	_bounce = maxf(_bounce - delta * 5.0, 0.0)
	for pop in _pops:
		pop["age"] += delta
	_pops = _pops.filter(func(p): return p["age"] < 0.9)
	if _shown and _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0:
			_shown = false
	if not _shown:
		_fade = maxf(_fade - delta * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	if _fade <= 0.0 or (hits == 0 and total == 0):
		return
	var font := ThemeDB.fallback_font
	var anchor := Vector2(size.x * 0.82, size.y * 0.40)
	var all_perfect := hits > 0 and perfects == hits
	var count_color := GOLD if all_perfect else Color.WHITE
	count_color.a = _fade
	var big := 52 + int(14.0 * _bounce)
	_text(font, "%d" % hits, anchor + Vector2(0, 0), big, count_color)
	var label_color := Color(0.85, 0.85, 0.9, _fade)
	_text(font, "HIT" if hits == 1 else "HITS", anchor + Vector2(0, 30), 20, label_color)
	var total_color := Color(1.0, 0.6, 0.35, _fade)
	_text(font, "%d DAMAGE" % total, anchor + Vector2(0, 66), 26, total_color)
	if perfects > 0:
		_text(font, "%d PERFECT" % perfects, anchor + Vector2(0, 94), 16, Color(GOLD, _fade))
	if _hold > 0.0:
		_text(font, attacker_name.to_upper() + "'S COMBO", anchor + Vector2(0, -52), 16, label_color)
	for pop in _pops:
		var age: float = pop["age"]
		var color: Color = pop["color"]
		color.a = (1.0 - age / 0.9) * _fade
		_text(font, pop["text"], anchor + Vector2(90.0 + pop["x"], -10.0 - age * 50.0), 24, color)


func _text(_font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font := HudStyle.bold_font()  # bold but upright: easy to read mid-combo
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(center.x - width / 2.0, center.y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 7, Color(HudStyle.OUTLINE, color.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
