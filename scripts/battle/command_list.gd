class_name CommandList
extends Control
## Pause menu > Command List: every party member's Attacks, Abilities and
## the Arts they've found (hidden Arts stay hidden), with the move's details
## and a live preview playing it on a loop: the character, a target, the
## move's timing bar and its effects (SpellFx), timed like the real thing.
## The fight stays paused underneath.

signal closed

const GOLD := Color(0.95, 0.78, 0.35)
const ROW_H := 30.0

## A stand-in body for the preview (SpellFx reads class_id and body_radius).
class PreviewBody extends MeshInstance3D:
	var class_id := ""
	var body_radius := 0.4

## The fight (for its move timing: BattleArena._plan_slot).
var arena: BattleArena = null
var members: Array = []
var member_index := 0
## Rows of the list: {"header": text} or {"move": dict, "kind": "attack"/"art"/"ability"}.
var rows: Array = []
var index := 0
var _scroll := 0

var _container: SubViewportContainer
var _overlay: Control
var _view: SubViewport
var _world: Node3D
var _caster: PreviewBody
var _target: PreviewBody
var _ally: PreviewBody
var _floor: MeshInstance3D
## The move playing in the preview, as the fight would plan it.
var _entry: Dictionary = {}
var _loop_t := 0.0
var _fired: Dictionary = {}
var _flash_left := 0.0

## Practice: the selected attack waits for your input, judged like in a
## fight (J to press / hold / tap, WASD for the Mage's codes). A miss just
## counts as one; nothing is lost.
var practice := false
const PRACTICE_LEAD := 1.0  ## seconds before the block starts each round
## Each hit's result this round: 0 not yet, 1 Perfect, 2 miss, 3 late/early.
var _res: Array = []
var _taps := 0
var _holding := false
var _code_i := 0
var _rounds := 0
var _perfect_rounds := 0
var _feedback := ""
var _feedback_color := Color.WHITE
var _feedback_left := 0.0
var _bar_w := 600.0
## This round's timing rings (hit -> node).
var _rings: Dictionary = {}
## Counter drill (Tab): in practice, the target is sometimes in a Counter
## stance (half the rounds, at random). Your first hit is caught and its
## counter-swing comes back: press J as it lands to break it, as in a fight.
var counter_drill := false
var _stance := false
var _counter_left := -INF
var _counter_recover := 0.0
var _counter_done := false
var _round_failed := false
var _counters := 0
var _counters_broken := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS  # runs while the fight is paused
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_preview()


func open(party: Array) -> void:
	members = party.duplicate()
	member_index = clampi(member_index, 0, maxi(members.size() - 1, 0))
	visible = true
	_container.visible = true
	_fill_rows()


func close() -> void:
	visible = false
	_container.visible = false
	_clear_fx()
	closed.emit()


# --- The list -----------------------------------------------------------------

func _member() -> Combatant:
	return members[member_index] if member_index < members.size() else null


func _fill_rows() -> void:
	rows.clear()
	var m := _member()
	if m == null:
		return
	rows.append({"header": "ATTACKS"})
	for move in Moves.attacks(m.class_id):
		rows.append({"move": move, "kind": "attack"})
	var found: Array = Moves.arts(m.class_id).filter(func(art): return ArtsBook.known(m.class_id, art["name"]))
	# An Art costs what its moves cost.
	var attack_costs := {}
	for move in Moves.attacks(m.class_id):
		attack_costs[move["name"]] = int(move["cost"])
	for k in found.size():
		var art: Dictionary = found[k].duplicate()
		var cost := 0
		for part in art["recipe"]:
			cost += int(attack_costs.get(part, 0))
		art["cost"] = cost
		found[k] = art
	var total := Moves.arts(m.class_id).size()
	rows.append({"header": "ARTS  (%d of %d found)" % [found.size(), total]})
	for art in found:
		rows.append({"move": art, "kind": "art"})
	rows.append({"header": "ABILITIES"})
	for skill in Moves.skills(m.class_id):
		rows.append({"move": skill, "kind": "ability"})
	index = 0
	_scroll = 0
	_step(1)
	_play_selected()


## Moves the selection, skipping headers.
func _step(direction: int) -> void:
	if rows.is_empty():
		return
	var i := index
	for _n in rows.size():
		i = (i + direction + rows.size()) % rows.size()
		if rows[i].has("move"):
			index = i
			break
	var visible_rows := _visible_rows()
	if index < _scroll:
		_scroll = index
	elif index >= _scroll + visible_rows:
		_scroll = index - visible_rows + 1
	_scroll = clampi(_scroll, 0, maxi(rows.size() - visible_rows, 0))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("swap_character"):
		counter_drill = not counter_drill
		if practice:
			_new_practice_round()
		get_viewport().set_input_as_handled()
		return
	if practice:
		_practice_input(event)
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept")) and not _entry.is_empty():
		_set_practice(true)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.is_echo() and not (event.is_action("move_forward") or event.is_action("move_back")):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_step(-1)
		_play_selected()
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_step(1)
		_play_selected()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		member_index = (member_index - 1 + members.size()) % maxi(members.size(), 1)
		_fill_rows()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		member_index = (member_index + 1) % maxi(members.size(), 1)
		_fill_rows()
	elif event.is_action_pressed("menu") or event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		close()
	elif not (event is InputEventKey):
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()


# --- Layout -------------------------------------------------------------------

func _panel() -> Rect2:
	return Rect2(40, 36, size.x - 80, size.y - 72)


func _list_rect() -> Rect2:
	var p := _panel()
	return Rect2(p.position.x + 18, p.position.y + 104, 400, p.size.y - 140)


func _preview_rect() -> Rect2:
	var p := _panel()
	var x := p.position.x + 440
	var w := p.end.x - x - 18
	var h := minf(w * 9.0 / 16.0, p.size.y * 0.52)
	return Rect2(x, p.position.y + 104, w, h)


func _visible_rows() -> int:
	return maxi(int(_list_rect().size.y / ROW_H), 1)


func _process(delta: float) -> void:
	if not visible:
		return
	var r := _preview_rect()
	_container.position = r.position
	_container.size = r.size
	_tick_preview(delta)
	_flash_left = maxf(_flash_left - delta, 0.0)
	queue_redraw()
	_overlay.queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var p := _panel()
	HudStyle.draw_panel(self, p, 0.97)
	HudStyle.draw_header(self, p.position + Vector2(20, 42), "COMMAND LIST", 32, GOLD)
	# Party tabs.
	var x := p.position.x + 20.0
	for i in members.size():
		var name: String = members[i].display_name
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 24.0
		var tab := Rect2(x, p.position.y + 58, w, 30)
		if i == member_index:
			HudStyle.draw_selection(self, tab, GOLD)
		_text(font, name, tab.position + Vector2(12, 21), 18, Color.WHITE if i == member_index else Color(0.65, 0.67, 0.75))
		x += w + 6.0
	_text(font, Keybinds.fill("{left} / {right}: character"), Vector2(x + 14, p.position.y + 79), 14, Color(0.6, 0.62, 0.7))
	# The list.
	var list := _list_rect()
	for k in range(_scroll, mini(rows.size(), _scroll + _visible_rows())):
		var row: Dictionary = rows[k]
		var at := Vector2(list.position.x, list.position.y + (k - _scroll) * ROW_H)
		if row.has("header"):
			_text(font, row["header"], at + Vector2(4, 21), 14, GOLD.darkened(0.15))
			continue
		var move: Dictionary = row["move"]
		var line := Rect2(at, Vector2(list.size.x, ROW_H - 2))
		if k == index:
			HudStyle.draw_selection(self, line, GOLD)
		draw_rect(Rect2(at + Vector2(10, 9), Vector2(10, 10)), move.get("color", Color.WHITE))
		_text(font, move["name"], at + Vector2(28, 20), 17, Color.WHITE if k == index else Color(0.82, 0.83, 0.88))
		var cost := "%d AP" % int(move.get("cost", 0))
		_text(font, cost, Vector2(line.end.x - font.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x - 10, at.y + 20), 15, Color(0.6, 0.85, 1.0))
	if _scroll > 0:
		_text(font, "^", list.position + Vector2(list.size.x / 2.0, -6), 16, GOLD)
	if _scroll + _visible_rows() < rows.size():
		_text(font, "v", Vector2(list.get_center().x, list.end.y + 14), 16, GOLD)
	# Preview frame, its timing bar, the details.
	var pr := _preview_rect()
	draw_rect(pr.grow(2), GOLD.darkened(0.3), false, 2.0)
	var y := pr.end.y + 12.0
	if not _entry.is_empty():
		_draw_timing_bar(font, Rect2(pr.position.x, y, pr.size.x, 34))
		y += 48.0
	if index < rows.size() and rows[index].has("move"):
		var move: Dictionary = rows[index]["move"]
		_text(font, "%s  ·  %s" % [move["name"], MoveInfo.summary(move)], Vector2(pr.position.x, y + 14), 19, GOLD)
		y += 26.0
		for detail in MoveInfo.lines(move):
			for wrapped in _wrap(font, detail, pr.size.x, 15):
				if y > p.end.y - 34:
					break
				_text(font, wrapped, Vector2(pr.position.x, y + 14), 15, Color(0.85, 0.86, 0.9))
				y += 19.0
	var drill := "Tab: Counter drill %s" % ("ON" if counter_drill else "off")
	var hint := "{up} / {down}: move     {left} / {right}: character     {confirm}: practice an attack     " + drill + "     Esc / {cancel}: back"
	if practice:
		hint = "PRACTICE: {confirm} to press / hold / tap like in a fight" + ("   WASD: type the code" if not _entry.is_empty() and int(_entry["timing"]) == Moves.TimingType.CODE else "") + "     " + drill + "     Esc / {cancel}: stop practising"
	_text(font, Keybinds.fill(hint), Vector2(p.position.x + 20, p.end.y - 12), 15, Color(0.6, 0.6, 0.65) if not practice else Color(0.5, 0.95, 0.55))


## The preview's timing bar: the block, its timing boxes / code / Hold, the
## hits, and the playhead looping with the preview.
func _draw_timing_bar(font: Font, r: Rect2) -> void:
	var duration: float = _entry["duration"]
	draw_rect(r, Color(0.08, 0.1, 0.16))
	# The block is as wide as in a fight (the battle bar's own scale), so the
	# playhead crosses it at the same speed and the box is the same size.
	var block := Rect2(r.position + Vector2(BattleMenu.LEAD_IN_PX, 6), Vector2(_block_px(), r.size.y - 12))
	draw_rect(block, Color(_entry["color"], 0.35))
	draw_rect(block, _entry["color"], false, 1.5)
	var timing := int(_entry["timing"])
	var hits: Array = _entry["hits"]
	var times: Array = _entry["times"]
	for h in hits.size():
		var hx: float = block.position.x + block.size.x * float(times[h])
		var timed: bool = not _entry["untimed"][h]
		if timed and timing == Moves.TimingType.PRESS:
			var w := minf(maxf(block.size.x * float(_entry["window"]), BattleMenu.MIN_BOX_PX), block.size.x)
			draw_rect(Rect2(hx - w, r.position.y + 2, w, r.size.y - 4), Color(1.0, 0.85, 0.3, 0.45))
		draw_line(Vector2(hx, r.position.y), Vector2(hx, r.end.y), Color.WHITE if timed else Color(0.6, 0.6, 0.65), 2.0)
	var tag := ""
	match timing:
		Moves.TimingType.HOLD:
			tag = "HOLD, let go on the hit"
		Moves.TimingType.TAP:
			tag = "TAP"
		Moves.TimingType.CODE:
			tag = "CODE " + BattleArena.code_text(_entry["code"])
		_:
			tag = "PRESS in the box"
	_bar_w = block.size.x
	if practice and timing == Moves.TimingType.CODE:
		tag += "   (%d/%d typed)" % [_code_i, (_entry["code"] as Array).size()]
	if practice and timing == Moves.TimingType.TAP:
		tag += "   %d/%d" % [_taps, int(_entry["taps"])]
	if practice and _holding:
		tag += "   HOLDING..."
	_text(font, tag, Vector2(block.end.x + 14, block.end.y - 4), 15, Color.WHITE)  # beside the block
	if practice:
		# Each timed hit's result so far.
		for h in _res.size():
			if int(_res[h]) == 0:
				continue
			var hx2: float = block.position.x + block.size.x * float(times[h])
			var c: Color = {1: Color(1.0, 0.85, 0.25), 2: Color(1.0, 0.3, 0.25), 3: Color(0.85, 0.8, 0.6)}[int(_res[h])]
			draw_circle(Vector2(hx2, r.position.y - 6), 6.0, c)
	if timing == Moves.TimingType.HOLD:
		var hs: float = block.position.x + block.size.x * float(_entry["hold_start"])
		var w2 := minf(maxf(block.size.x * float(_entry["window"]), BattleMenu.MIN_BOX_PX), block.size.x)
		draw_rect(Rect2(hs - w2, r.position.y + 2, w2, r.size.y - 4), Color(0.4, 0.8, 1.0, 0.45))
	var share := clampf(_loop_t / maxf(duration, 0.01), 0.0, 1.0)
	var px := block.position.x + block.size.x * share
	draw_line(Vector2(px, r.position.y - 2), Vector2(px, r.end.y + 2), GOLD, 3.0)
	if practice and _counter_left > -INF:
		# As in a fight: a red line closes on the playhead; press as it arrives.
		var red := Color(1.0, 0.25, 0.2)
		var progress := clampf(1.0 - _counter_left / arena.counter_parry_lead, 0.0, 1.0)
		draw_rect(Rect2(px - 11, r.position.y - 8, 22, r.size.y + 16), Color(red, 0.35 + 0.25 * progress))
		draw_rect(Rect2(px - 11, r.position.y - 8, 22, r.size.y + 16), red, false, 2.0)
		# From the right, or from the left when the playhead is at the bar's end.
		var side := 1.0 if px + 160.0 <= r.end.x else -1.0
		var lx := px + side * 160.0 * (1.0 - progress)
		draw_line(Vector2(lx, r.position.y - 8), Vector2(lx, r.end.y + 8), red.lightened(0.3), 3.0)
		var label := "! COUNTER !  press {confirm} as the line arrives"
		label = Keybinds.fill(label)
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var lx0 := px - lw - 24.0 if side > 0.0 else px - lw - 190.0
		_text(font, label, Vector2(maxf(lx0, r.position.x + 4), r.end.y + 20), 15, red)



## Text over the 3D preview (drawn on a layer above it).
func _draw_overlay() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	var pr0 := _preview_rect()
	if practice:
		_otext(font, "PRACTICE", pr0.position + Vector2(14, 30), 22, Color(0.5, 0.95, 0.55))
		_otext(font, "Perfect rounds: %d / %d" % [_perfect_rounds, _rounds], pr0.position + Vector2(14, 54), 16, Color.WHITE)
		if counter_drill:
			_otext(font, "Counters broken: %d / %d" % [_counters_broken, _counters], pr0.position + Vector2(14, 76), 16, Color(1.0, 0.6, 0.55))
		if _stance:
			_otext(font, "COUNTER STANCE", pr0.position + Vector2(pr0.size.x - 200, 30), 20, Color(1.0, 0.3, 0.25))
		if _loop_t < 0.0:
			_otext(font, "Get ready...", pr0.position + Vector2(14, 100), 16, Color(0.8, 0.8, 0.85))
		if _feedback_left > 0.0:
			var w := font.get_string_size(_feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			_otext(font, _feedback, pr0.get_center() - Vector2(w / 2.0, 50), 30, Color(_feedback_color, minf(_feedback_left / 0.3, 1.0)))
	elif _flash_left > 0.0:
		_otext(font, "PERFECT!", pr0.position + Vector2(pr0.size.x - 130, 32), 22, Color(1.0, 0.85, 0.25, _flash_left / 0.4))


func _otext(font: Font, text: String, pos: Vector2, font_size: int, color: Color) -> void:
	_overlay.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, color.a))
	_overlay.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# --- The preview ----------------------------------------------------------------

func _build_preview() -> void:
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.visible = false
	add_child(_container)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_container.add_child(_view)
	add_child(_overlay)  # above the preview
	_world = Node3D.new()
	_view.add_child(_world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.08, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.environment = environment
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	_world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 9)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.45, 0.5, 0.62)
	floor_mesh.material_override = floor_mat
	_world.add_child(floor_mesh)
	_floor = floor_mesh
	var cam := Camera3D.new()
	_world.add_child(cam)
	cam.position = Vector3(0.4, 3.4, 4.6)
	cam.look_at(Vector3(0.4, 0.6, -0.4), Vector3.UP)
	cam.current = true
	_caster = _body(Color.WHITE, false)
	_target = _body(Color(1.0, 0.55, 0.2), true)
	_ally = _body(Color(0.7, 0.72, 0.8), false)


func _body(color: Color, box: bool) -> PreviewBody:
	var b := PreviewBody.new()
	if box:
		var m := BoxMesh.new()
		m.size = Vector3(1.3, 1.3, 1.3)
		b.mesh = m
		b.body_radius = 0.7
	else:
		var c := CapsuleMesh.new()
		c.radius = 0.32
		c.height = 1.5
		b.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	b.material_override = mat
	_world.add_child(b)
	return b


func _play_selected() -> void:
	practice = false
	_stance = false
	_counter_left = -INF
	_counter_recover = 0.0
	if _target:
		_tint_target()
	_clear_fx()
	_entry = {}
	_loop_t = 0.0
	_fired.clear()
	_rings.clear()
	var m := _member()
	if m == null or index >= rows.size() or not rows[index].has("move"):
		return
	var move: Dictionary = rows[index]["move"]
	_caster.class_id = m.class_id
	(_caster.material_override as StandardMaterial3D).albedo_color = _member_color(m)
	# Stand where the move reaches from.
	var reach := clampf(float(move.get("reach", m.reach())) if float(move.get("reach", -1.0)) > 0.0 else m.reach(), 0.4, 5.0)
	_target.position = Vector3(2.2, 0.65, -0.8)
	var away := Vector3(-1.0, 0.0, 0.45).normalized()
	_caster.position = Vector3(_target.position.x, 0.75, _target.position.z) + away * (reach + _target.body_radius + _caster.body_radius)
	_caster.look_at(Vector3(_target.position.x, 0.75, _target.position.z), Vector3.UP)
	_ally.position = _caster.position + Vector3(-0.4, 0, -1.6)
	_ally.visible = rows[index]["kind"] == "ability"
	if rows[index]["kind"] != "ability" and arena != null:
		# The fight's own timing for this member (block length, hits, boxes).
		var saved := arena.controlled
		arena.controlled = m
		_entry = arena._plan_slot(move)
		arena.controlled = saved


func _member_color(m: Combatant) -> Color:
	var body := m.get_node_or_null("Body") as MeshInstance3D
	if body:
		var mat := body.material_override as StandardMaterial3D
		if mat == null and body.get_surface_override_material_count() > 0:
			mat = body.get_surface_override_material(0) as StandardMaterial3D
		if mat == null and body.mesh and body.mesh.get_surface_count() > 0:
			mat = body.mesh.surface_get_material(0) as StandardMaterial3D
		if mat:
			return mat.albedo_color
	return SpellFx.CLASS_COLORS.get(m.class_id, Color.WHITE)


func _tick_preview(delta: float) -> void:
	if index >= rows.size() or not rows[index].has("move"):
		return
	var move: Dictionary = rows[index]["move"]
	if practice and _counter_left > -INF:
		# The counter-swing comes; the playhead waits.
		_counter_left -= delta
		_feedback_left = maxf(_feedback_left - delta, 0.0)
		if _counter_left <= -arena.counter_parry_window:
			_counter_result(false, "TOO LATE: COUNTERED!")
		return
	if practice and _counter_recover > 0.0:
		_counter_recover -= delta  # the breather after breaking it
		_feedback_left = maxf(_feedback_left - delta, 0.0)
		return
	_loop_t += delta
	if _entry.is_empty():
		# An Ability: its effect every 2 s.
		if _loop_t >= 2.0 or not _fired.has("used"):
			if _loop_t >= 2.0:
				_loop_t = 0.0
			_fired["used"] = true
			_ability_fx(move)
		return
	var duration: float = _entry["duration"]
	var hits: Array = _entry["hits"]
	var times: Array = _entry["times"]
	_feedback_left = maxf(_feedback_left - delta, 0.0)
	for h in hits.size():
		var hit_t: float = duration * float(times[h])
		# The timing ring on the target, as in a fight.
		if arena != null and not bool(_entry["untimed"][h]) and not arena._special_hit(_entry, h) \
				and not _fired.has("r%d" % h) and _loop_t >= hit_t - arena.timing_ring_lead and _loop_t < hit_t:
			_fired["r%d" % h] = true
			_rings[h] = SpellFx.timing_ring(_world, _target, hit_t - _loop_t, _window(), arena.timing_ring_lead)
		var lead := SpellFx.approach_lead(_caster, move)
		if lead > 0.0 and not _fired.has("a%d" % h) and _loop_t >= hit_t - lead:
			_fired["a%d" % h] = true
			SpellFx.approach(_world, _caster, _target, move, maxf(hit_t - _loop_t, 0.04))
		if not _fired.has("i%d" % h) and _loop_t >= hit_t:
			_fired["i%d" % h] = true
			var perfect: bool = not _entry["untimed"][h]
			if practice and _stance and not _counter_done:
				# Caught by the Counter stance: its swing comes back at you.
				_counter_done = true
				_counter_left = arena.counter_parry_lead
				_counters += 1
				_say("COUNTER!", Color(1.0, 0.3, 0.25))
				SpellFx.ring(_world, Vector3(_target.position.x, 0, _target.position.z), Color(1.0, 0.25, 0.2), 1.6)
				return
			if practice:
				perfect = _land_practice_hit(h)
			elif perfect and _rings.has(h):
				SpellFx.timing_ring_done(_rings[h], true)
			SpellFx.impact(_world, _caster, _target, move, perfect)
			if perfect:
				_flash_left = 0.4
	if _loop_t >= duration + 1.0:
		if practice:
			_end_practice_round()
		_loop_t = -PRACTICE_LEAD if practice else 0.0
		_fired.clear()
		_rings.clear()


## A rough look for each Ability: heals, shields, moves, buffs.
func _ability_fx(skill: Dictionary) -> void:
	var text := ("%s %s" % [skill["name"], skill.get("desc", "")]).to_lower()
	var color: Color = skill.get("color", GOLD)
	if text.contains("heal") or text.contains("cure") or text.contains("hp"):
		SpellFx.heal(_world, _ally)
		SpellFx.heal(_world, _caster)
	elif text.contains("shield") or text.contains("barrier") or text.contains("cloak") or text.contains("guard"):
		SpellFx.shield(_world, _caster)
	elif text.contains("teleport") or text.contains("step") or text.contains("dash") or text.contains("vanish"):
		var from := _caster.position
		SpellFx.burst(_world, from, color, 0.6)
		SpellFx.dust(_world, _caster, Vector3(1, 0, -0.3).normalized(), 2.0)
	elif skill.get("choose_element", false):
		SpellFx.ring(_world, Vector3(_ally.position.x, 0, _ally.position.z), SpellFx.FIRE, 1.4)
		SpellFx.burst(_world, _ally.position + Vector3(0, 0.3, 0), SpellFx.FIRE, 0.5)
	else:
		SpellFx.ring(_world, Vector3(_caster.position.x, 0, _caster.position.z), color, 1.8)
		SpellFx.sparks(_world, _caster.position + Vector3(0, 0.5, 0), color, 16)


## Effects still flying from the last move go when the selection changes.
func _clear_fx() -> void:
	if _world == null:
		return
	for child in _world.get_children():
		if child is PreviewBody or child is Camera3D or child is DirectionalLight3D or child is WorldEnvironment or child == _floor:
			continue
		child.queue_free()


func _wrap(font: Font, text: String, width: float, font_size: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = next
	if line != "":
		out.append(line)
	return out


func _text(font: Font, text: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# --- Practice -----------------------------------------------------------------

func _set_practice(on: bool) -> void:
	_play_selected()  # fresh loop (and practice off)
	practice = on and not _entry.is_empty()
	_rounds = 0
	_perfect_rounds = 0
	_counters = 0
	_counters_broken = 0
	if practice:
		_loop_t = -PRACTICE_LEAD
		_new_practice_round()


## The counter-swing judged: broken (the round goes on, stance gone) or
## countered (the round ends there).
func _counter_result(broken: bool, text: String) -> void:
	_counter_left = -INF
	var ground := Vector3(_target.position.x, 0, _target.position.z)
	if broken:
		_counters_broken += 1
		_stance = false
		_tint_target()
		_counter_recover = arena.counter_recover_seconds
		_say(text, Color(1.0, 0.85, 0.25))
		SpellFx.ring(_world, ground, SpellFx.PERFECT, 2.4)
		SpellFx.sparks(_world, _target.position + Vector3(0, 0.4, 0), SpellFx.PERFECT, 24)
	else:
		_round_failed = true
		_say(text, Color(1.0, 0.3, 0.25))
		SpellFx.burst(_world, _caster.position + Vector3(0, 0.4, 0), Color(1.0, 0.25, 0.2), 0.7)
		_loop_t = float(_entry["duration"])  # the combo stops: on to the next round
		for k in (_entry["hits"] as Array).size():
			_fired["a%d" % k] = true
			_fired["i%d" % k] = true


func _tint_target() -> void:
	(_target.material_override as StandardMaterial3D).albedo_color = Color(0.85, 0.15, 0.2) if _stance else Color(1.0, 0.55, 0.2)


func _new_practice_round() -> void:
	_stance = practice and counter_drill and randf() < 0.5
	_counter_left = -INF
	_counter_recover = 0.0
	_counter_done = false
	_round_failed = false
	_tint_target()
	_res.clear()
	_res.resize((_entry["hits"] as Array).size())
	_res.fill(0)
	_taps = 0
	_holding = false
	_code_i = 0


func _say(text: String, color: Color) -> void:
	_feedback = text
	_feedback_color = color
	_feedback_left = 0.7


## The next timed hit still waiting for its input (-1: none).
func _next_practice_hit() -> int:
	for h in _res.size():
		if not bool(_entry["untimed"][h]) and int(_res[h]) == 0:
			return h
	return -1


func _window() -> float:
	# What the bar shows is what counts (never thinner than the fight's minimum box).
	return minf(maxf(float(_entry["window"]), BattleMenu.MIN_BOX_PX / maxf(_bar_w, 1.0)), 1.0) * float(_entry["duration"])


## The block's width in pixels, as the battle bar would draw this move
## alone during a combo (BattleMenu._draw_combo_bar's scale and zoom).
func _block_px() -> float:
	var m := _member()
	var cost := maxf(float(_entry.get("cost", 0.0)), 1.0)
	var screen_w := size.x
	if arena != null and arena.battle_menu != null and arena.battle_menu.size.x > 0.0:
		screen_w = arena.battle_menu.size.x
	var limit := maxf(m.combo_limit if m != null else 100.0, 1.0)
	var px := minf(BattleMenu.PX_PER_AP, minf(BattleMenu.MAX_BAR_PX, screen_w - BattleMenu.LEAD_IN_PX - 60.0) / limit)
	if cost * px < BattleMenu.MIN_PLAY_BLOCK_PX:
		px = maxf(px, minf(BattleMenu.MIN_PLAY_BLOCK_PX / cost, BattleMenu.PLAY_MAX_PX_PER_AP))
	return cost * px


func _practice_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_echo():
		return
	if event.is_action_pressed("menu") or event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		_set_practice(false)
		return
	if event.is_action_pressed("confirm"):
		_practice_press()
	elif event.is_action_released("confirm"):
		_practice_release()
	else:
		for dir in BattleArena.CODE_KEYS:
			if event.is_action_pressed(BattleArena.CODE_KEYS[dir]):
				_practice_code(dir)
				return


func _practice_press() -> void:
	if _counter_left > -INF:
		if absf(_counter_left) <= arena.counter_parry_window:
			_counter_result(true, "COUNTER BROKEN!")
		else:
			_counter_result(false, "TOO EARLY: COUNTERED!")
		return
	if _counter_recover > 0.0:
		return  # the breather: ignored
	if _loop_t < 0.0:
		return  # the lead-in: ignored, as in a fight
	var h := _next_practice_hit()
	if h < 0:
		return
	var duration: float = _entry["duration"]
	var timing := int(_entry["timing"])
	var special := arena._special_hit(_entry, h)
	if special and timing == Moves.TimingType.CODE:
		var surge := float(_entry["move"].get("surge", 0.0)) > 0.0
		if surge and _code_i >= (_entry["code"] as Array).size() and _taps < int(_entry["taps"]):
			_taps += 1  # Energy: free taps after the code
		return
	if special and timing == Moves.TimingType.TAP:
		if _loop_t < duration * float(_entry["tap_start"]):
			return
		var uncapped: bool = _entry["move"].get("surge_uncapped", false)
		if _taps >= int(_entry["taps"]) and not uncapped:
			if float(_entry["move"].get("surge", 0.0)) <= 0.0:
				_res[h] = 2
				_say("TOO MANY TAPS", Color(1.0, 0.35, 0.3))
			return
		_taps += 1
		if _taps == int(_entry["taps"]):
			_res[h] = 1
		return
	if special and timing == Moves.TimingType.HOLD:
		if _holding:
			return
		var start := duration * float(_entry["hold_start"])
		if _loop_t >= start - _window() and _loop_t <= start:
			_holding = true
			return
		if _loop_t > start:
			_res[h] = 3
			_say("LATE START", Color(0.85, 0.8, 0.6))
			return
		_res[h] = 2
		_say("TOO EARLY", Color(1.0, 0.35, 0.3))
		return
	var hit_time := duration * float(_entry["times"][h])
	if _loop_t >= hit_time - _window():
		_res[h] = 1
		if _rings.has(h):
			SpellFx.timing_ring_done(_rings[h], true)
	else:
		_res[h] = 2
		_say("TOO EARLY", Color(1.0, 0.35, 0.3))
		if _rings.has(h):
			SpellFx.timing_ring_done(_rings[h], false)


func _practice_release() -> void:
	if not _holding:
		return
	_holding = false
	var h := _next_practice_hit()
	if h < 0:
		return
	var hit_time := float(_entry["duration"]) * float(_entry["times"][h])
	if _loop_t >= hit_time - _window():
		_res[h] = 1
	else:
		_res[h] = 3
		_say("LET GO EARLY", Color(0.85, 0.8, 0.6))


func _practice_code(dir: String) -> void:
	if _loop_t < 0.0 or int(_entry["timing"]) != Moves.TimingType.CODE:
		return
	var code: Array = _entry["code"]
	var h := (_entry["hits"] as Array).size() - 1
	if int(_res[h]) != 0 or _code_i >= code.size():
		return
	if _loop_t < float(_entry["duration"]) * float(_entry["code_start"]):
		return
	if String(code[_code_i]) == dir:
		_code_i += 1
		if _code_i >= code.size():
			_res[h] = 1
	else:
		_code_i = 0
		_say("RESTART", Color(0.85, 0.8, 0.6))


## A hit lands in practice: Perfect if its input was right. Returns that.
func _land_practice_hit(h: int) -> bool:
	if bool(_entry["untimed"][h]):
		return false
	if _holding and arena._special_hit(_entry, h):
		_holding = false
		_res[h] = 3
		_say("HELD TOO LONG", Color(0.85, 0.8, 0.6))
		return false
	if int(_res[h]) == 0:
		var timing := int(_entry["timing"])
		_res[h] = 3
		_say("NO CODE: NORMAL HIT" if timing == Moves.TimingType.CODE else "NO PRESS", Color(0.85, 0.8, 0.6))
		return false
	if int(_res[h]) == 1:
		_say("PERFECT!", Color(1.0, 0.85, 0.25))
		return true
	return false


func _end_practice_round() -> void:
	_rounds += 1
	var timed := 0
	var perfect := 0
	for h in _res.size():
		if not bool(_entry["untimed"][h]):
			timed += 1
			if int(_res[h]) == 1:
				perfect += 1
	if timed > 0 and perfect == timed and not _round_failed:
		_perfect_rounds += 1
	_new_practice_round()

