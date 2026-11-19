class_name FieldScene
extends Node3D
## Exploring: the party walks through rooms (loading areas). One room is
## loaded at a time; walking into a door fades out, loads the next room,
## puts the party at the door's entry with the camera back at that room's
## set angle, and fades in.
##
## Started from the title screen (New Game) with FieldScene.start().
## Esc: the pause menu (Resume, Options, Change Keys, Quit to title) until
## the field menu is built.
##
## Enemies (FieldEnemy) stand in the rooms. Hold Sneak (or half-push the
## stick) to walk at half speed: unaware enemies slow down with you, and
## sneaking doesn't make noise. Confirm swings Wyr's sword: hitting an
## enemy from behind before it has noticed you is an ambush (the party
## starts with 50 AP), any other hit a normal fight; being touched is
## getting caught (knocked down, the enemies ahead). engage() starts the
## fight right there, in the room (a short battle transition, then the
## battle scene in field mode: FieldFight, FieldFightDirector); every
## enemy in the room joins. Afterwards the field picks up where it was
## (FieldState.returning): beaten enemies stay gone until a save point,
## HP and the item pouch carry over; escaping leaves the party inside the
## door it ran for, the room reset; losing sends the party to the last
## save point (or the dungeon's entrance).

const SCENE := "res://scenes/field/field.tscn"
## The Prologue's first room and entry (the grey-box test rooms for now).
const PROLOGUE_ROOM := "res://scenes/field/rooms/test_hall.tscn"
const PROLOGUE_ENTRY := "start"
## Wyr (the Knight) and the two soldiers (placeholders: the party's Mage
## and Cleric figures until the soldiers get their own).
const PROLOGUE_PARTY := [
	"res://scenes/characters/knight.tscn",
	"res://scenes/characters/mage.tscn",
	"res://scenes/characters/cleric.tscn",
]
## Seconds to fade out (and in) between rooms.
const FADE := 0.3
## Metres between party members on the trail.
const SPACING := 1.4
## Holding Sneak: this share of full speed.
const SNEAK_SHARE := 0.5
## Faster than this share of full speed counts as running (noisy).
const RUN_SHARE := 0.6
## The field swing: how long it lasts, when it lands, how far it reaches
## past the two bodies' edges, and how wide (the dot of the leader's
## facing and the direction to the enemy).
const SWING_SECONDS := 0.38
const SWING_LANDS := 0.13
const SWING_REACH := 1.0
const SWING_ARC_DOT := 0.3
## How a fight starts.
const AMBUSH := "ambush"
const NORMAL := "normal"
const CAUGHT := "caught"

## The battle transition: seconds before the fight loads.
const TRANSITION := 0.9
## Off in tests that only check how fights would start: engage() then
## shows a message and takes the enemy out instead of starting the fight.
static var fights_on := true

## Where start() sends the next field scene.
static var start_room := PROLOGUE_ROOM
static var start_entry := PROLOGUE_ENTRY
static var start_party: Array = PROLOGUE_PARTY

var room: FieldRoom = null
var room_path := ""
var leader: FieldWalker = null
var party: Array[FieldWalker] = []
var camera: FieldCamera = null
var pause_menu: PauseMenu = null
## True between rooms (no steering, doors ignored).
var changing := false
## Rooms entered so far this visit (tests and, later, the play-test log).
var rooms_entered := 0
## The room's enemies (FieldEnemy).
var enemies: Array[FieldEnemy] = []
## The last fight start: [enemy, AMBUSH / NORMAL / CAUGHT] (tests; Stage 3
## starts the fight from it).
var last_engagement: Array = []
var _message: Label
var _message_left := 0.0
var _swing_pending := -1.0

var _env: Environment
var _sun: DirectionalLight3D
var _fade: ColorRect
var _screen: ColorRect
var _banner: Label
var _banner_left := 0.0
## Doors only work once the leader has stepped clear of them after arriving.
var _doors_armed := false
var _last_entry := ""

signal room_changed(path: String)
## A fight would start here (Stage 3 starts it).
signal engaged(enemy: FieldEnemy, how: String)


## New Game (and tests): opens the field at a room's entry.
static func start(tree: SceneTree, room := PROLOGUE_ROOM, entry := PROLOGUE_ENTRY, members: Array = PROLOGUE_PARTY) -> void:
	start_room = room
	start_entry = entry
	start_party = members
	FieldState.new_game(members, room, entry)
	tree.change_scene_to_file(SCENE)


func _ready() -> void:
	Keybinds.apply_saved()
	Pad.ensure()
	Sfx.stop_music()  # no exploration track yet
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var world := WorldEnvironment.new()
	world.environment = _env
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_sun.light_energy = 0.8
	_sun.shadow_enabled = true
	add_child(_sun)
	camera = FieldCamera.new()
	add_child(camera)
	camera.make_current()
	if FieldState.party.is_empty():
		FieldState.new_game(start_party, start_room, start_entry)
	for i in FieldState.party.size():
		var walker := FieldWalker.make(load(FieldState.party[i]), i == 0)
		add_child(walker)
		party.append(walker)
	leader = party[0]
	for i in range(1, party.size()):
		party[i].leader = leader
		party[i].follow_distance = SPACING * i
	camera.target = leader
	_build_ui()
	if FieldState.returning != null:
		_resume(FieldState.returning)
		FieldState.returning = null
	else:
		_load_room(start_room, start_entry)
	_fade.color.a = 1.0
	_fade_to(0.0)


func _build_ui() -> void:
	var filter_layer := CanvasLayer.new()
	filter_layer.layer = 0
	add_child(filter_layer)
	_screen = ColorRect.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ps1_screen.gdshader")
	_screen.material = mat
	filter_layer.add_child(_screen)
	apply_screen_filter()
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	_banner = Label.new()
	_banner.position = Vector2(40, 36)
	_banner.add_theme_font_size_override("font_size", 26)
	_banner.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.07))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	ui.add_child(_banner)
	_message = Label.new()
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.position.y = 120.0
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.add_theme_font_size_override("font_size", 28)
	_message.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	_message.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.07))
	_message.add_theme_constant_override("outline_size", 8)
	_message.modulate.a = 0.0
	ui.add_child(_message)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 8
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	fade_layer.add_child(_fade)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	pause_menu = PauseMenu.new()
	pause_menu.field_mode = true
	menu_layer.add_child(pause_menu)
	pause_menu.options_changed.connect(apply_screen_filter)
	pause_menu.quit_requested.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn"))


## The PS1 screen filter (Options), as in a fight.
func apply_screen_filter() -> void:
	var look: Dictionary = Settings.SCREEN_FILTER_LOOKS[Settings.screen_filter()]
	Figure.set_snap_lines(float(look["snap"]))
	_screen.visible = Settings.screen_filter() != "off"
	var mat := _screen.material as ShaderMaterial
	mat.set_shader_parameter("lines", float(look["lines"]))
	mat.set_shader_parameter("levels", float(look["levels"]))
	mat.set_shader_parameter("dither_strength", float(look["dither"]))
	mat.set_shader_parameter("smooth_pixels", bool(look["smooth"]))


## Below this height, a walker has fallen out of the room: it's put back
## by the leader (the leader: on its last entry).
const FALL_LIMIT := -10.0


func _physics_process(_delta: float) -> void:
	if room == null:
		return
	for walker in party:
		if walker.global_position.y < FALL_LIMIT:
			if walker == leader:
				var spot := room.entry(_last_entry)
				walker.place(spot.global_position if spot else Vector3.ZERO, walker.facing)
			else:
				walker.place(leader.global_position + Vector3(0, 0.05, 0), leader.facing)
	var input := Vector2.ZERO
	if not changing and not get_tree().paused:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if InputMap.has_action("sneak") and Input.is_action_pressed("sneak"):
			input *= SNEAK_SHARE
	leader.steer = camera.relative(input)
	var running := leader.pace > RUN_SHARE
	for enemy in enemies:
		enemy.leader = leader
		enemy.pace = leader.pace
		enemy.leader_running = running
	if _swing_pending >= 0.0:
		_swing_pending -= _delta
		if _swing_pending < 0.0:
			_swing_lands()
	if not _doors_armed and not changing:
		_doors_armed = true
		for door in room.doors():
			if door.overlaps_body(leader):
				_doors_armed = false


func _process(delta: float) -> void:
	if room:
		room.cut_away(camera.global_position)
	if _message_left > 0.0:
		_message_left -= delta
		_message.modulate.a = clampf(_message_left / 0.5, 0.0, 1.0)
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.modulate.a = clampf(_banner_left / 0.6, 0.0, 1.0) if _banner_left < 0.6 else minf(_banner.modulate.a + delta * 3.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not changing and not pause_menu.visible:
		pause_menu.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm") and not changing and not get_tree().paused:
		swing()
		get_viewport().set_input_as_handled()


## Wyr swings: the blow lands a moment later (see _swing_lands).
func swing() -> void:
	if leader.swing_left > 0.0 or changing:
		return
	leader.swing_left = SWING_SECONDS
	leader.figure.animate("attack")
	Sfx.play("swing")
	_swing_pending = SWING_LANDS


## The nearest enemy in front, in reach, is hit: an ambush if it hadn't
## noticed the party and the blow came from behind it.
func _swing_lands() -> void:
	var best: FieldEnemy = null
	var best_d := INF
	for enemy in enemies:
		if enemy.gone:
			continue
		var to := enemy.global_position - leader.global_position
		to.y = 0.0
		var d := to.length()
		if d > enemy.body_radius + 0.35 + SWING_REACH or absf(enemy.global_position.y - leader.global_position.y) > 1.2:
			continue
		if d > 0.01 and leader.flat_forward().dot(to / d) < SWING_ARC_DOT:
			continue
		if d < best_d:
			best = enemy
			best_d = d
	if best == null:
		return
	Sfx.play("hit_blade")
	var how := AMBUSH if not best.is_aware() and best.is_behind(leader.global_position) else NORMAL
	engage(best, how)


## A fight starts with this enemy (and every other one in the room). With
## fights_on false (tests): a message, and the enemy leaves the room.
func engage(enemy: FieldEnemy, how: String) -> void:
	if enemy.gone or changing:
		return
	last_engagement = [enemy, how]
	engaged.emit(enemy, how)
	if fights_on:
		_start_fight(enemy, how)
		return
	enemy.remove()
	var who := enemy.figure.display_name if enemy.figure else "an enemy"
	match how:
		AMBUSH:
			show_message("Ambush on %s!  The party would start with 50 AP." % who)
		CAUGHT:
			Sfx.play("parry_fail")
			show_message("Caught by %s!  The party would start knocked down." % who)
		_:
			show_message("A fight with %s would start." % who)


func show_message(text: String, seconds := 2.5) -> void:
	_message.text = text
	_message_left = seconds
	_message.modulate.a = 1.0


## Walks through a door: fade out, swap rooms, fade in.
func go_to(path: String, entry_name: String) -> void:
	if changing:
		return
	changing = true
	_set_frozen(true)
	await _fade_to(1.0)
	_load_room(path, entry_name)
	await _fade_to(0.0)
	_set_frozen(false)


func _load_room(path: String, entry_name: String) -> void:
	if room:
		remove_child(room)
		room.queue_free()
	room = (load(path) as PackedScene).instantiate() as FieldRoom
	room_path = path
	add_child(room)
	_env.background_color = room.background
	_env.ambient_light_color = room.ambient
	_env.ambient_light_energy = room.ambient_energy
	for door in room.doors():
		door.entered_by_leader.connect(_on_door)
	enemies = []
	for enemy in room.enemies():
		if FieldState.is_beaten(path, enemy.name):
			enemy.remove()  # beaten: gone until a save point
		else:
			enemies.append(enemy)
	for enemy in enemies:
		enemy.leader = leader
		enemy.touched.connect(func(e: FieldEnemy): engage(e, CAUGHT))
		enemy.spotted.connect(func(_e: FieldEnemy): Sfx.play("counter_ready"))
	_last_entry = entry_name
	var spot := room.entry(entry_name)
	var at := spot.global_position if spot else Vector3.ZERO
	var face := spot.global_rotation.y if spot else 0.0
	place_party(at, face)
	camera.set_home(room.camera_yaw, room.camera_pitch, room.camera_distance)
	_doors_armed = false
	rooms_entered += 1
	if room.room_name != "":
		_banner.text = room.room_name
		_banner_left = 2.5
	room_changed.emit(path)


## The leader here, the followers lined up behind.
func place_party(at: Vector3, face: float) -> void:
	leader.place(at, face)
	leader.lay_trail_behind(SPACING * party.size() + 1.0)
	for i in range(1, party.size()):
		var behind := FieldWalker.trail_point(leader, SPACING * i)
		party[i].place(behind + Vector3(0, 0.05, 0), face)


func _on_door(door: FieldDoor) -> void:
	if changing or not _doors_armed or door.to_room == "":
		return
	go_to(door.to_room, door.to_entry)


func _set_frozen(on: bool) -> void:
	changing = on
	camera.locked = on
	for walker in party:
		walker.frozen = on


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE)
	await tween.finished


# --- Fights ----------------------------------------------------------------

## Everything the battle needs, a short transition, then the battle scene.
func _start_fight(enemy: FieldEnemy, how: String) -> void:
	_set_frozen(true)
	for e in enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	var f := FieldFight.new()
	f.room_path = room_path
	f.area = room.battle_area
	f.obstacles = room.battle_obstacles()
	f.how = how
	for i in party.size():
		f.party.append({"scene": FieldState.party[i], "pos": party[i].global_position, "facing": party[i].facing,
				"hp": int(FieldState.hp[i]) if i < FieldState.hp.size() else -1})
	for e in enemies:
		if e.gone or e.fighter_scene == null:
			continue
		if e == enemy and how == CAUGHT:
			f.catcher = f.enemies.size()
		f.enemies.append({"scene": e.fighter_scene.resource_path, "pos": e.global_position, "facing": e.facing, "name": String(e.name)})
	f.pouch = FieldState.pouch.duplicate()
	f.exits = room.exits()
	f.lock_steering = not FieldState.steer_unlocked
	f.camera_yaw = camera.yaw
	f.camera_pitch = camera.pitch
	Sfx.stop_music()
	Sfx.play("draw_blade")
	var transition := FieldTransition.new()
	transition.seconds = TRANSITION
	_fade.get_parent().add_child(transition)
	await transition.finished
	BattleArena.field_fight = f
	BattleArena.tutorial_mode = false
	BattleArena.boss_rush_mode = false
	get_tree().change_scene_to_file("res://scenes/battle/battle_arena.tscn")


## Back from a fight: the party's HP and pouch, the beaten enemies, and
## where the party stands now.
func _resume(f: FieldFight) -> void:
	for n in f.beaten:
		FieldState.beaten[FieldState.enemy_id(f.room_path, n)] = true
	FieldState.pouch = f.pouch.duplicate()
	FieldState.experience += f.experience
	for i in mini(f.party_hp.size(), FieldState.hp.size()):
		var hp := int(f.party_hp[i])
		FieldState.hp[i] = maxi(hp, 1)  # a downed member comes round after the fight
	match f.outcome:
		"defeat":
			for i in FieldState.hp.size():
				FieldState.hp[i] = -1
			_load_room(FieldState.respawn_room, FieldState.respawn_entry)
			show_message("The party comes to, back at the entrance." if FieldState.respawn_room == start_room else "The party comes to at the save point.")
		"escaped":
			_load_room(f.room_path, "")
			var exit: Dictionary = f.exits[clampi(f.exit_index, 0, f.exits.size() - 1)] if not f.exits.is_empty() else {}
			if not exit.is_empty():
				place_party(Vector3(exit["inside"]), float(exit["facing"]))
			for e in enemies:
				e.calm_left = ESCAPE_CALM
			show_message("Escaped!")
		_:
			_load_room(f.room_path, "")
			place_party(f.leader_pos, f.leader_facing)
	last_fight = f


## After escaping: seconds the room's enemies can't notice the party.
const ESCAPE_CALM := 2.0
## The fight that just ended (tests).
var last_fight: FieldFight = null
