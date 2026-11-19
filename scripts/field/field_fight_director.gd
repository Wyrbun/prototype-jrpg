class_name FieldFightDirector
extends Node
## Runs a fight that started on the field (BattleArena.field_fight), inside
## the battle scene: builds the arena from the room (its floor, its walls
## cut away as on the field, pillars and crates as obstacles), puts everyone
## where they stood, applies how the fight started, lets the party escape
## towards a door, and afterwards shows the Victory (experience, items
## found) or the defeat, then hands back to the field.
##
## How it started:
## - Ambush (hit from behind, unseen): the party starts with 50 AP.
## - Normal: the party starts with 0 AP.
## - Caught (touched): 0 AP, everyone in the party knocked down, the
##   enemies ahead on the timeline, and the party's AP doesn't recharge
##   until they're all back up.
##
## Escaping (when the fight allows it): steer towards a door and keep going
## for ESCAPE_SECONDS; the room resets around the party, standing inside
## that door. Set fights can't be escaped.

const AMBUSH_AP := 50.0
const ESCAPE_SECONDS := 2.0
## Steering within this many degrees of a door counts as heading for it.
const ESCAPE_ANGLE := 35.0
## Enemies' timeline start when the party was caught (out of 100).
const CAUGHT_ENEMY_START := Vector2(55.0, 70.0)
## The field fights' own theme (audio/music/<name>.ogg or .mp3); the
## battle theme until it's chosen.
const MUSIC := "field_battle"
const MUSIC_FALLBACK := "battle"
const FADE_IN := 0.45

var battle: BattleArena
var fight: FieldFight
var room: FieldRoom
## Seconds of steering towards the current exit, and which one.
var escape_time := 0.0
var escape_exit := -1
var escaped := false
var _stall_ap := false
var _first_frame := true
var _ui: Control
var _escape_bar: ProgressBar
var _escape_label: Label
var _fade: ColorRect
var _panel: FieldResultPanel = null
var _finished := false
var _rng := RandomNumberGenerator.new()


## Called by the battle instead of loading a Boss Rush round.
func build(b: BattleArena, f: FieldFight) -> void:
	battle = b
	fight = f
	name = "FieldFight"
	var center := Vector3(f.area.get_center().x, 0.0, f.area.get_center().y)
	var encounter := Encounter.new()
	encounter.title = "Battle"
	for m in f.party:
		encounter.party.append(load(m["scene"]))
	for e in f.enemies:
		encounter.enemies.append(load(e["scene"]))
	battle.encounter = encounter
	# The arena: the fight's part of the room's floor, centred on the
	# battle's origin (the room moves by -center).
	var arena := Arena.new()
	arena.name = "Arena"
	arena.shape = Arena.Shape.RECTANGLE
	arena.size = f.area.size
	arena.setting = "none"
	for o in f.obstacles:
		var rock := ArenaObstacle.new()
		rock.kind = ArenaObstacle.Kind.ROCK
		rock.radius = float(o[1])
		rock.position = Vector3(o[0]) - center
		rock.position.y = 0.0
		arena.add_child(rock)
	battle.arena = arena
	battle.add_child(arena)
	var floor_mesh := arena.get_floor_mesh()
	if floor_mesh:
		floor_mesh.visible = false
	for rock in arena.obstacles():
		rock.visible = false  # the room's own pillar or crate shows instead
	room = (load(f.room_path) as PackedScene).instantiate() as FieldRoom
	room.position = -center
	var enemies_node := room.get_node_or_null("Enemies")
	if enemies_node:
		room.remove_child(enemies_node)
		enemies_node.free()  # the fighters stand in for them
	battle.add_child(room)
	var env: Environment = battle.get_node("WorldEnvironment").environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = room.background
	env.ambient_light_color = room.ambient
	env.ambient_light_energy = room.ambient_energy
	# Everyone where they stood (on the flat floor, inside the area).
	battle.party = battle._spawn(encounter.party, battle.get_node("Party"), false)
	battle.enemies = battle._spawn(encounter.enemies, battle.get_node("Enemies"), true)
	for i in battle.party.size():
		_place(battle.party[i], f.party[i], center)
	for i in battle.enemies.size():
		_place(battle.enemies[i], f.enemies[i], center)
		battle.enemies[i].set_meta("field_name", f.enemies[i]["name"])
	battle.add_child(self)
	Sfx.duck(false)
	Sfx.music(MUSIC if _has_music(MUSIC) else MUSIC_FALLBACK)


func _place(c: Combatant, data: Dictionary, center: Vector3) -> void:
	var p: Vector3 = Vector3(data["pos"]) - center
	p.y = 0.0
	c.global_position = p
	c.rotation = Vector3(0.0, float(data["facing"]), 0.0)
	battle.arena.keep_inside(c, c.body_radius)


static func _has_music(track: String) -> bool:
	for ext in ["ogg", "mp3", "wav"]:
		if ResourceLoader.exists("res://audio/music/%s.%s" % [track, ext]):
			return true
	return false


## After the battle's own set-up: HP, the pouch, AP, the camera.
func after_ready() -> void:
	for i in battle.party.size():
		var hp := int(fight.party[i].get("hp", -1))
		if hp >= 0:
			battle.party[i].hp = clampi(hp, 1, battle.party[i].max_hp)
	battle.pouch = fight.pouch.duplicate()
	battle.ap = AMBUSH_AP if fight.how == FieldFight.AMBUSH else 0.0
	battle._cam_yaw = fight.camera_yaw
	battle._cam_pitch = clampf(fight.camera_pitch, battle.camera_min_pitch, battle.camera_max_pitch)
	match fight.how:
		FieldFight.AMBUSH:
			battle._intro_message = "Ambush!  The party starts with %d AP." % int(AMBUSH_AP)
		FieldFight.CAUGHT:
			battle._intro_message = "Caught!  The party is knocked down."
			_stall_ap = true  # from the first frame
			for e in battle.enemies:
				e.timeline_pos = randf_range(CAUGHT_ENEMY_START.x, CAUGHT_ENEMY_START.y)
			for m in battle.party:
				m.timeline_pos = 0.0
		_:
			battle._intro_message = ""
	if fight.can_escape and not fight.exits.is_empty():
		battle._intro_message += ("\n" if battle._intro_message != "" else "") + "To escape, keep heading for a door."
	battle._intro_left = 4.0 if battle._intro_message != "" else 0.0
	if battle.playtest:
		battle.playtest.mode = "Prologue (%s)" % fight.how
	_build_ui()


func _build_ui() -> void:
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.get_node("UI").add_child(_ui)
	_escape_label = Label.new()
	_escape_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_escape_label.position.y += 140.0
	_escape_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_escape_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escape_label.add_theme_font_size_override("font_size", 22)
	_escape_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_escape_label.add_theme_constant_override("outline_size", 6)
	_escape_label.text = "Escaping..."
	_escape_label.visible = false
	_ui.add_child(_escape_label)
	_escape_bar = ProgressBar.new()
	_escape_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_escape_bar.custom_minimum_size = Vector2(260, 14)
	_escape_bar.position += Vector2(-130, 175)
	_escape_bar.show_percentage = false
	_escape_bar.max_value = ESCAPE_SECONDS
	_escape_bar.visible = false
	_ui.add_child(_escape_bar)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 1)
	layer.add_child(_fade)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, FADE_IN)


func _process(delta: float) -> void:
	if room and battle.camera:
		room.cut_away(battle.camera.global_position)
	if _first_frame:
		_first_frame = false
		if fight.how == FieldFight.CAUGHT:
			var catcher: Combatant = battle.enemies[fight.catcher] if fight.catcher >= 0 and fight.catcher < battle.enemies.size() else null
			for m in battle.party:
				battle._knock_down(m, catcher)
	if _stall_ap:
		var any_down := false
		for m in battle.party:
			if m.has_meta("knocked"):
				any_down = true
		_stall_ap = any_down
	if escape_time > 0.0 and not _is_heading_out():
		escape_time = maxf(escape_time - delta * 2.0, 0.0)
	_escape_bar.visible = escape_time > 0.0 and not escaped
	_escape_label.visible = _escape_bar.visible
	_escape_bar.value = escape_time
	if escape_exit >= 0 and escape_exit < fight.exits.size():
		_escape_label.text = "Escaping %s..." % String(fight.exits[escape_exit].get("label", "through the door"))


var _heading := false


func _is_heading_out() -> bool:
	return _heading


## The party may not switch to the soldiers yet.
func steering_locked() -> bool:
	return fight.lock_steering


## False while a caught party is still getting up.
func ap_regen_allowed() -> bool:
	return not _stall_ap


## From the battle's free roam: the steered fighter heading for a door.
func tick_escape(input: Vector2, delta: float) -> void:
	_heading = false
	if escaped or not fight.can_escape or fight.exits.is_empty() or battle._game_over:
		return
	var who := battle.controlled
	if who == null or who.is_down or who.has_meta("knocked") or input.length() < 0.3:
		return
	var dir := battle._camera_relative(input)
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var center := Vector3(fight.area.get_center().x, 0.0, fight.area.get_center().y)
	var best := -1
	var best_dot := cos(deg_to_rad(ESCAPE_ANGLE))
	for i in fight.exits.size():
		var to: Vector3 = Vector3(fight.exits[i]["pos"]) - center - who.global_position
		to.y = 0.0
		if to.length() < 0.01:
			continue
		var d := dir.dot(to.normalized())
		if d >= best_dot:
			best_dot = d
			best = i
	if best < 0:
		return
	_heading = true
	if best != escape_exit:
		escape_exit = best
		escape_time = 0.0
	escape_time += delta
	if escape_time >= ESCAPE_SECONDS:
		_escape()


func _escape() -> void:
	escaped = true
	Sfx.play("teleport")
	fight.outcome = "escaped"
	fight.exit_index = escape_exit
	_finish_and_return()


## The battle's end wait is over: the Victory or the defeat panel.
func show_result() -> void:
	if _finished or _panel != null:
		return
	var won := battle._won()
	fight.outcome = "victory" if won else "defeat"
	if won:
		_rng.randomize()
		for e in battle.enemies:
			fight.experience += FieldRewards.experience(e.display_name)
			fight.drops.append_array(FieldRewards.roll_drops(e.display_name, _rng))
	_panel = FieldResultPanel.new()
	_panel.won = won
	_panel.experience = fight.experience
	_panel.total_experience = FieldState.experience + fight.experience
	_panel.drops = fight.drops
	_panel.respawn_note = "Back to the last save point." if FieldState.respawn_room != "" else ""
	battle.get_node("UI").add_child(_panel)
	_panel.closed.connect(_finish_and_return)
	if won:
		Sfx.stop_music()
		Sfx.play("victory")
	else:
		Sfx.stop_music()
		Sfx.play("defeat")


## Writes how it went into the fight and goes back to the field.
func _finish_and_return() -> void:
	if _finished:
		return
	_finished = true
	var center := Vector3(fight.area.get_center().x, 0.0, fight.area.get_center().y)
	fight.party_hp = []
	for m in battle.party:
		fight.party_hp.append(m.hp)
	fight.pouch = battle.pouch.duplicate()
	for item in fight.drops:
		fight.pouch[item] = int(fight.pouch.get(item, 0)) + 1
	fight.beaten = []
	for e in battle.enemies:
		if e.is_down or e.hp <= 0:
			fight.beaten.append(String(e.get_meta("field_name", e.name)))
	var lead: Combatant = battle.party[0]
	fight.leader_pos = lead.global_position + center
	fight.leader_pos.y = 0.0
	fight.leader_facing = lead.rotation.y
	FieldState.returning = fight
	BattleArena.field_fight = null
	battle.get_tree().paused = false
	battle.get_tree().change_scene_to_file.call_deferred(FieldScene.SCENE)
