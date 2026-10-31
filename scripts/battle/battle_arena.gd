class_name BattleArena
extends Node3D
## The battle scene's main script.
##
## How a battle flows (see docs/battle-design.md for the reasoning):
##
## Timeline: everyone slides along the bar at their own speed. Reaching the
## end means it's your turn and time stops. In the orange casting zone near
## the end, enemies stand still (turning slowly) and prepare a skill:
## Attack, Smash, Defense or Counter. It stays hidden ("...") until late in
## the zone (reveal_at), then shows on the bar and as a live area on the
## floor. Defense and Counter are active for the whole zone and drop at the
## end of the bar.
##
## Between turns (timeline running): you steer one party member in real
## time with WASD; enemies and AI allies move in real time too. Moving is
## free and earns no AP; AP recharges over time. Tab switches which party
## member you steer, so you can position each of them.
##
## Party turns: the fighter whose turn it is is locked in place and the
## command menu opens: Attack (needs an enemy in reach), Wait (no AP; their
## bar restarts a third of the way along), Abilities, Items. If several
## party members are ready at once, their turns come up back to back.
##
## Max AP: starts at max_ap (100). Every successful Parry or Perfect raises
## it for the rest of the fight; missing either one resets it to max_ap.
## AP is also earned faster the higher max AP is (current / starting), so a
## big bank refills quickly, and it's all on the line with each timed press.
## Letting a combo hit pass without pressing costs a little of the extra.
##
## Strikes: touching a live Attack/Smash area, or an enemy reaching the end
## of the bar, starts a strike. A ring shrinks onto each target in real time.
##   E (Parry)  while the ring is gold: no damage, enemy staggered.
##              Too early: full damage, turn pushed back, half your AP lost.
##   Q (Defend) any time: costs AP, you take part of the damage, and that
##              part comes back at your next turn if you aren't hit again.
##   Nothing:   full damage.
##
## Attacks: J opens the command menu (Attack / Abilities / Items). Attack
## opens the combo bar (Legend of Legaia-style): pick moves to fill a bar as
## long as the fighter's combo limit, paid from party AP, then Space plays
## the combo hit by hit and the turn ends. The skill triangle applies to every
## hit: a Counter stance punishes you and stops the combo, Defense blocks
## normal hits (Thrust pierces it, Overhead Smash breaks it), and an
## Attack-type hit interrupts an enemy preparing Smash.

signal strike_finished

## How many timeline units fill the bar. A fighter acts on reaching it.
const TIMELINE_LENGTH := 100.0
## Fighters can't walk further than this from the center of the arena.

enum Reaction { NONE, PARRY, PARRY_MISSED, DEFEND }

## Multiplies everyone's speed. Raise it to make the whole battle faster.
## The rounds to play (data/boss_rush.tres). Each round sets the arena,
## the party lineup and the enemies.
@export var boss_rush: BossRush
## Which round to start on when you press F5 (1 = the first).
@export var start_round: int = 1

@export var time_scale: float = 3.0
## Overall battle pace between turns: slows the timeline, enemy and ally
## movement, and AP recharge together (1.0 = the original pace, 0.7 = 30%
## slower). The fighter you steer, strike rings and combo timing aren't affected.
@export_range(0.1, 2.0) var battle_speed: float = 0.7
## How long an enemy turn stays on screen after it acts, in seconds.
@export var enemy_turn_seconds: float = 0.8
## Where the casting zone starts on the timeline (the bar is 100 long).
@export_range(0.0, 100.0) var cast_zone_start: float = 75.0
## Where an enemy's prepared skill is revealed. Closer to 100 means less
## time to see it coming.
@export_range(0.0, 100.0) var reveal_at: float = 90.0

@export_group("AP")
## The most AP the party can hold at the start of the fight. Parries and
## Perfects raise it; missing one resets it back to this.
@export var max_ap: float = 100.0
## Max AP can't grow beyond this.
@export var max_ap_ceiling: float = 200.0
## Max AP gained per successful Parry / per Perfect combo hit.
@export var parry_max_ap_gain: float = 10.0
@export var perfect_max_ap_gain: float = 5.0
## Extra max AP lost for each combo hit you let pass without pressing J
## (never drops below max_ap).
@export var skipped_hit_max_ap_loss: float = 5.0
## AP the party starts the battle with.
@export var starting_ap: float = 50.0
## AP gained per second while the timeline is running (between turns).
## Moving is free and earns nothing, so this is the main AP source.
@export var ap_regen_per_second: float = 6.0

@export_group("Reactions")
## How long before impact a Parry still counts, in seconds.
@export var parry_window: float = 0.25
## How far back on the timeline a missed Parry pushes the fighter.
@export var parry_miss_push: float = 30.0
## How far back on the timeline a successful Parry knocks the enemy.
@export var stagger_push: float = 25.0
## AP spent to Defend.
@export var defend_cost: float = 10.0
## Share of the damage you still take when defending against an Attack.
@export_range(0.0, 1.0) var defend_share_vs_attack: float = 0.25
## Share of the damage you still take when defending against a Smash
## (Smash breaks the guard, so it's higher).
@export_range(0.0, 1.0) var defend_share_vs_smash: float = 0.6

@export_group("Attacks")
## When a party turn starts, AP is topped up to at least this much
## (enough for three Slashes).
@export var turn_start_ap: float = 30.0
## Seconds of "READY" lead-in before the combo's first move starts.
@export var combo_lead_in: float = 1.0
## Perfect timing (J in a block's timing box): extra damage on that hit.
@export var perfect_damage_bonus: float = 0.5
## Damage you take when you attack into a Counter stance.
@export var counter_stance_damage: int = 33
## How far an interrupted or guard-broken enemy is knocked back on the timeline.
@export var interrupt_push: float = 30.0
## Seconds a Defense/Counter stance stays up after the enemy's turn
## (counted while the timeline runs), so it's more likely to catch someone.
@export var stance_linger: float = 3.0

## Where on the timeline a fighter restarts after choosing Wait (a third
## of the way along, so the next turn comes sooner).
@export_range(0.0, 99.0) var wait_head_start: float = 33.0

@export_group("Movement phase")
## AI allies try to stand at this share of their attack reach from the
## nearest enemy: close to the edge of their range, but inside it.
@export_range(0.3, 1.0) var ally_range_share: float = 0.8
## Extra space allies keep from dangerous enemy areas, in meters.
@export var ally_danger_margin: float = 0.3
## How quickly the camera catches up with the fighter you control.
@export var camera_follow_speed: float = 4.0
## How far the camera sits from the action, in meters.
@export var camera_distance: float = 12.0
## Camera controls: Z / C or right-drag to rotate, mouse wheel to zoom, V to reset.
@export var camera_turn_degrees_per_second: float = 100.0
@export var camera_mouse_sensitivity: float = 0.3
@export var camera_min_distance: float = 7.0
@export var camera_max_distance: float = 24.0
@export var camera_min_pitch: float = 20.0
@export var camera_max_pitch: float = 75.0
## When a turn comes up, the camera pans to that fighter before the turn
## begins (and back afterwards). Longer distances take longer, up to this.
@export var turn_pan_max_seconds: float = 0.8


## One enemy skill on its way to landing.
class Strike:
	var enemy: Combatant
	var skill: int
	var def: EnemySkill
	var targets: Array[Combatant] = []
	var windup: float = 1.0
	var time_left: float = 1.0
	var reaction: int = 0  # a Reaction value
	## Send the enemy back to the start of the bar when this resolves
	## (true when it strikes during your turn instead of on its own turn).
	var reset_timeline := false
	var rings: Array[MeshInstance3D] = []
	var markers: Array[MeshInstance3D] = []


## The round being played, kept across scene reloads (0-based; -1 = not
## chosen yet, so start_round is used).
static var _round_index := -1
## True when the title screen started the tutorial instead of a round.
static var tutorial_mode := false

## The tutorial's fight (data/tutorial.tres).
@export var tutorial_encounter: Encounter
## The tutorial's guide, when tutorial_mode is on.
var tutorial: TutorialDirector = null
## The tutorial pauses the whole fight while it explains something.
var tutorial_pause := false
## Counts of things the player has done this fight ("parries", "perfects",
## "combos_mage"...). The tutorial checks its goals against these.
var stats := {}

var arena: Arena = null
var encounter: Encounter = null
var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var combatants: Array[Combatant] = []
## Whose turn it is. null means the timeline is running.
var active: Combatant = null
## The party member you're steering. Tab changes it between turns; on a
## party turn it's always the fighter whose turn it is.
var controlled: Combatant = null
## The party's shared AP. Carries over from turn to turn.
var ap: float = 0.0
## The party's AP cap right now (grows with Parries and Perfects).
var current_max_ap: float = 100.0
## The strike currently playing, or null.
var _strike: Strike = null
## True once the battle is decided (victory or defeat).
var _game_over := false
var _result_text := ""

## The command menu / combo bar state (see BattleMenu.Mode).
var _menu_mode: int = BattleMenu.Mode.HIDDEN
## The controlled fighter's attacks (combo bar) or skills (Abilities).
var _moves: Array[Dictionary] = []
var _skills: Array[Dictionary] = []
## What each combo slot will do (see BattleMenu.plan); also holds "move",
## "hits" and "duration" for playback.
var _plan: Array[Dictionary] = []
## Seconds of Concentrate left (doubles AP recharge).
var _concentrate_left := 0.0
## Abilities: the skill waiting for a target, the choices, and the marker.
var _pending_skill: Dictionary = {}
var _target_choices: Array[Combatant] = []
var _target_index := 0
var _target_marker: MeshInstance3D = null
## The enemy the combo will hit, locked when the combo bar opens.
var _combo_target: Combatant = null
## Party AP just before the combo was paid, so the bar keeps showing it.
var _ap_before_combo := 0.0

# Combo playback (runs in _process while the menu is EXECUTING).
enum Timing { NONE, PERFECT, MISS }
var _exec_attacker: Combatant = null
var _exec_slot := 0
var _exec_time := 0.0
var _exec_hits_done := 0
## Timing result for each hit of the current move.
var _exec_timings: Array[int] = []
## Counts down after the last move before the turn ends.
var _exec_outro := -1.0
## Counts down the lead-in before the first move starts.
var _exec_lead_in := 0.0

## True on frames where you moved (so the world moved with you).
var _world_moved := false
var _camera_offset: Vector3
## Camera angle around the fighter (yaw), tilt (pitch, degrees down) and zoom.
var _cam_yaw := 0.0
var _cam_pitch := 35.0
var _cam_distance := 12.0
var _cam_start_pitch := 35.0
## The point the camera follows, smoothed so rotating stays steady.
var _cam_focus := Vector3.ZERO
## The party member you were steering before an ally's turn took over;
## control goes back to them when that turn ends.
var _steer_before_turn: Combatant = null
## A smooth camera pan in progress: where it started, its length, and time so far.
var _pan_start := Vector3.ZERO
var _pan_duration := 0.0
var _pan_time := 0.0
## Seconds left before the active fighter's turn actually begins (the camera
## is panning over to them).
var _turn_intro_left := 0.0
var _flash_message := ""
var _flash_time_left := 0.0

@onready var camera: Camera3D = $Camera3D
@onready var timeline_bar: TimelineBar = $UI/TimelineBar
@onready var turn_label: Label = $UI/TurnLabel
@onready var warning_label: Label = $UI/WarningLabel
@onready var ap_bar: ProgressBar = $UI/APBar
@onready var ap_label: Label = $UI/APBar/APLabel
@onready var controls_label: Label = $UI/ControlsLabel
@onready var party_status: PartyStatus = $UI/PartyStatus
@onready var enemy_status: PartyStatus = $UI/EnemyStatus
@onready var battle_menu: BattleMenu = $UI/BattleMenu


func _ready() -> void:
	_load_round()
	combatants.append_array(party)
	combatants.append_array(enemies)

	timeline_bar.combatants = combatants
	timeline_bar.length = TIMELINE_LENGTH
	timeline_bar.cast_zone_start = cast_zone_start
	party_status.party = party
	enemy_status.party = enemies
	enemy_status.tags_on_left = true  # keeps the right edge tidy
	battle_menu.commands = PackedStringArray(["Attack", "Abilities", "Wait", "Items"])
	var enabled: Array[bool] = [true, true, true, false]
	battle_menu.command_enabled = enabled
	battle_menu.command_notes = PackedStringArray(["", "", "", "coming later"])
	controlled = party[0]
	controlled.set_highlighted(true)
	ap = starting_ap
	current_max_ap = max_ap
	# The camera keeps its angle from the scene and backs away along its
	# own view direction (+Z is "behind" a camera in Godot).
	_cam_pitch = -camera.global_rotation_degrees.x
	_cam_start_pitch = _cam_pitch
	_cam_yaw = camera.global_rotation_degrees.y
	_cam_distance = camera_distance
	_cam_focus = _camera_focus()
	_place_camera()
	print("%s! Party: %s  vs  Enemies: %s" % [encounter.title, _names(party), _names(enemies)])
	if tutorial_mode:
		for c in combatants:
			c.cannot_fall = true
		tutorial = TutorialDirector.new()
		tutorial.battle = self
		add_child(tutorial)
	else:
		_flash("%s: %s  vs  %s" % [encounter.title, _names(party), _names(enemies)])


## Builds the current round: its arena, then the party and the enemies
## at their starting spots.
func _load_round() -> void:
	var count := boss_rush.rounds.size()
	if _round_index < 0:
		_round_index = clampi(start_round - 1, 0, count - 1)
	_round_index = posmod(_round_index, count)
	encounter = tutorial_encounter if tutorial_mode else boss_rush.rounds[_round_index]
	arena = encounter.arena.instantiate() as Arena
	add_child(arena)
	party = _spawn(encounter.party, $Party, false)
	enemies = _spawn(encounter.enemies, $Enemies, true)


func _spawn(scenes: Array[PackedScene], holder: Node3D, enemy_side: bool) -> Array[Combatant]:
	var spots := arena.spawn_points(enemy_side, scenes.size())
	var spawned: Array[Combatant] = []
	var used_names := {}
	for i in scenes.size():
		var fighter := scenes[i].instantiate() as Combatant
		# Two of the same enemy get a letter: Kobold Archer A, Kobold Archer B.
		var copies := 0
		for other in scenes:
			if other == scenes[i]:
				copies += 1
		if copies > 1:
			var n: int = used_names.get(fighter.display_name, 0)
			used_names[fighter.display_name] = n + 1
			fighter.display_name += " " + "ABCD"[n]
		fighter.transform = spots[i]
		holder.add_child(fighter)
		spawned.append(fighter)
	return spawned


## Starts a round (0-based) or the tutorial. Used by the title screen.
static func start(tree: SceneTree, round_index: int, tutorial: bool) -> void:
	_round_index = round_index
	tutorial_mode = tutorial
	tree.change_scene_to_file("res://scenes/battle/battle_arena.tscn")


func _count(key: String) -> void:
	stats[key] = int(stats.get(key, 0)) + 1


## Adds a party member mid-fight (the tutorial's new arrivals), next to the
## party's starting spot.
func add_party_member(scene: PackedScene) -> Combatant:
	var fighter := scene.instantiate() as Combatant
	var spot := arena.spawn_points(false, 1)[0]
	spot.origin += Vector3(2.0 * (party.size() - 2), 0, 1.5)
	fighter.transform = spot
	$Party.add_child(fighter)
	party.append(fighter)
	combatants.append(fighter)
	fighter.cannot_fall = tutorial_mode
	fighter.timeline_pos = randf_range(10.0, 40.0)
	_keep_in_arena(fighter)
	return fighter


## N / P: jump to the next or previous round (restarts the scene).
func _change_round(step: int) -> void:
	_round_index += step
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	_world_moved = false
	if not _game_over and not tutorial_pause:
		if _strike != null:
			_update_strike(delta)  # everything else waits while a strike plays
		elif active == null:
			var world_delta := delta * battle_speed
			var concentrate := 2.0 if _concentrate_left > 0.0 else 1.0
			ap = minf(ap + ap_regen_per_second * _ap_gain_multiplier() * concentrate * world_delta, current_max_ap)
			_concentrate_left = maxf(_concentrate_left - world_delta, 0.0)
			for member in party:
				member.riposte_left = maxf(member.riposte_left - world_delta, 0.0)
			_free_roam(delta, world_delta)
			_tick_stances(world_delta)
			_advance_timeline(world_delta)
		elif _turn_intro_left > 0.0:
			_turn_intro_left -= delta
			if _turn_intro_left <= 0.0:
				_begin_active_turn()
		elif _party_turn() and _menu_mode == BattleMenu.Mode.EXECUTING:
			_update_combo(delta)
		elif _party_turn() and _menu_mode == BattleMenu.Mode.TARGET:
			_update_target_marker(delta)
		# On a party turn the fighter is locked in place until a command is chosen.
	# Checked again: the strike above may have just knocked out the last fighter.
	if not _game_over:
		_update_attack_ranges()
	_update_camera(delta)
	_update_ui(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _camera_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")
		return
	if tutorial != null and tutorial.wants_input(event):
		get_viewport().set_input_as_handled()
		return
	if tutorial_mode and (event.is_action_pressed("next_round") or event.is_action_pressed("previous_round")):
		return
	if event.is_action_pressed("next_round") or event.is_action_pressed("previous_round"):
		get_viewport().set_input_as_handled()
		_change_round(1 if event.is_action_pressed("next_round") else -1)
		return
	if _game_over:
		if event.is_action_pressed("restart"):
			get_viewport().set_input_as_handled()
			get_tree().reload_current_scene()  # start the battle over
		return
	if _strike != null:
		if event.is_action_pressed("parry"):
			get_viewport().set_input_as_handled()
			_try_parry()
		elif event.is_action_pressed("defend"):
			get_viewport().set_input_as_handled()
			_try_defend()
		return
	if _party_turn():
		_menu_input(event)
	elif active == null and event.is_action_pressed("swap_character"):
		get_viewport().set_input_as_handled()
		_cycle_control()



# --- Timeline -------------------------------------------------------------

## Moves everyone except the current turn owner along the bar by
## "seconds" worth of timeline time. Used both between turns (real time)
## and during your turn (time paid for by walking).
func _advance_timeline(seconds: float) -> void:
	var during_party_turn := active != null
	var next: Combatant = null
	for c in combatants:
		if c == active or c.is_down or c.hold:
			continue
		var before := c.timeline_pos
		c.timeline_pos += c.speed * time_scale * seconds

		if c.team == Combatant.Team.ENEMY:
			if before < cast_zone_start and c.timeline_pos >= cast_zone_start:
				_begin_cast(c)
			if c.loaded_skill != Skills.NONE and not c.skill_revealed and c.timeline_pos >= reveal_at:
				_reveal_skill(c)
			if c.hold_at >= 0.0 and c.timeline_pos >= c.hold_at:
				c.hold = true  # the tutorial keeps it here, skill revealed, without striking

		if c.timeline_pos < TIMELINE_LENGTH:
			continue
		if not during_party_turn:
			# If several cross the end in the same frame, whoever got
			# furthest goes first; the rest go right after.
			if next == null or c.timeline_pos > next.timeline_pos:
				next = c
		elif c.team == Combatant.Team.ENEMY and _strike == null:
			# You walked long enough for this enemy's turn to arrive.
			_enemy_unleash(c, true)
		else:
			# Waits at the end: a party member until your turn is over,
			# an enemy until the current strike is done.
			c.timeline_pos = TIMELINE_LENGTH

	if next != null:
		_start_turn(next)


func _start_turn(fighter: Combatant) -> void:
	active = fighter
	fighter.timeline_pos = TIMELINE_LENGTH
	_flash_time_left = 0.0  # don't carry old messages into a new turn
	timeline_bar.active = fighter
	print("%s's turn" % fighter.display_name)
	# Effects cast by this fighter count down one of their turns.
	var ended: PackedStringArray = []
	for c in combatants:
		for status_name in c.tick_statuses(fighter):
			ended.append("%s's %s" % [c.display_name, String(status_name).replace("_", " ")])
	if not ended.is_empty():
		_flash("Wore off: " + ", ".join(ended))

	if fighter.team == Combatant.Team.PARTY:
		if _steer_before_turn == null:
			_steer_before_turn = controlled  # remembered, to hand control back afterwards
		_set_controlled(fighter)  # locked onto the fighter whose turn it is
	else:
		fighter.set_highlighted(true)
	# The camera pans over to whoever's turn it is; the turn begins when it arrives.
	_turn_intro_left = _begin_pan()
	if _turn_intro_left <= 0.0:
		_begin_active_turn()


## The camera has arrived: the turn really starts now.
func _begin_active_turn() -> void:
	_turn_intro_left = 0.0
	var fighter := active
	if fighter == null:
		return
	if fighter.team == Combatant.Team.PARTY:
		var recovered := fighter.recover_hp()
		if recovered > 0:
			_flash("%s recovers %d HP" % [fighter.display_name, recovered])
		# Every turn starts with enough AP for a few attacks.
		ap = minf(maxf(ap, turn_start_ap), current_max_ap)
		_open_commands()
	else:
		_run_enemy_turn(fighter)


func _run_enemy_turn(fighter: Combatant) -> void:
	if fighter.loaded_skill == Skills.NONE:
		_begin_cast(fighter)
	_enemy_unleash(fighter, false)
	if _strike != null:
		await strike_finished
	if _game_over:
		return
	# "await" pauses this function until the timer finishes,
	# without freezing the rest of the game.
	await get_tree().create_timer(enemy_turn_seconds).timeout
	_end_turn()


func _end_turn() -> void:
	if active == null:
		return
	if active != controlled:
		active.set_highlighted(false)
	_send_to_start(active)
	var was_party := active.team == Combatant.Team.PARTY
	active = null
	# After an ally's turn, go back to whoever you were steering before it.
	if was_party and _steer_before_turn != null:
		if not _steer_before_turn.is_down and _steer_before_turn != controlled:
			_set_controlled(_steer_before_turn)
		_steer_before_turn = null
	_begin_pan()  # glide back to whoever you're steering
	timeline_bar.active = null
	_menu_mode = BattleMenu.Mode.HIDDEN
	_combo_target = null


## Back to the start of the bar, minus any pending penalty.
func _send_to_start(fighter: Combatant) -> void:
	fighter.timeline_pos = -fighter.timeline_penalty
	fighter.timeline_penalty = 0.0


## Pushes a fighter back on the timeline. If they're about to return to
## the start anyway (it's their turn), the push is saved for that moment.
func _push_back(fighter: Combatant, amount: float) -> void:
	if fighter == active:
		fighter.timeline_penalty += amount
	else:
		fighter.timeline_pos -= amount


# --- Free roam (between turns) ---------------------------------------------

func _party_turn() -> bool:
	return active != null and active.team == Combatant.Team.PARTY


## While the timeline runs: you steer one party member, and enemies and
## AI allies move in real time. Moving is free (no AP either way).
func _free_roam(delta: float, world_delta: float) -> void:
	# get_vector turns four keys into one direction. Forward is -Z in
	# Godot, so "move_forward" maps to the negative Y of this vector.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if controlled != null and not controlled.is_down and input != Vector2.ZERO:
		controlled.step(_camera_relative(input), delta)
		_keep_in_arena(controlled)
	for enemy in enemies:
		_enemy_step(enemy, world_delta)
	for ally in party:
		if ally != controlled and not ally.is_down:
			_ally_step(ally, world_delta)
	_resolve_overlaps()
	_world_moved = true


## Tab (between turns): steer the next standing party member.
func _cycle_control() -> void:
	var standing := _standing(party)
	if standing.size() < 2:
		return
	var index := standing.find(controlled)
	_set_controlled(standing[(index + 1) % standing.size()])
	_begin_pan()


func _set_controlled(fighter: Combatant) -> void:
	if controlled != null:
		controlled.set_highlighted(false)
	controlled = fighter
	controlled.set_highlighted(true)


## Enemy behavior: turn toward the nearest party member and walk forward.
## Enemies only walk when roughly facing their target, so a slow-turning
## enemy can be outmaneuvered. While preparing a skill they stand still and
## can only turn slowly.
func _enemy_step(enemy: Combatant, delta: float) -> void:
	var target := _enemy_target(enemy)
	if target == null:
		return
	if enemy.hold:
		var to := target.global_position - enemy.global_position
		enemy.face_toward(to, delta, enemy.cast_turn_speed_degrees)
		return
	var to_target := target.global_position - enemy.global_position
	to_target.y = 0.0
	if enemy.is_down:
		return
	if enemy.loaded_skill != Skills.NONE or enemy.stance != Skills.NONE:
		# Preparing a skill or holding a stance: stand still, turn slowly.
		enemy.face_toward(to_target, delta, enemy.cast_turn_speed_degrees)
		return
	var stop_distance := enemy.body_radius + target.body_radius + enemy.preferred_gap
	var wants_closer := to_target.length() > stop_distance or not _can_see(enemy, target)
	# Walk around rocks and pits on the way.
	var heading := arena.steer(enemy.global_position, to_target, enemy.body_radius) if wants_closer else to_target
	enemy.face_toward(heading, delta)
	var facing_target := enemy.flat_forward().angle_to(heading) < deg_to_rad(45.0)
	if wants_closer and facing_target:
		enemy.global_position += enemy.flat_forward() * enemy.move_speed * delta
		_keep_in_arena(enemy)


## Who an enemy goes after: whoever taunted it, otherwise the nearest.
func _enemy_target(enemy: Combatant) -> Combatant:
	if enemy.statuses.has("taunt"):
		var taunter: Combatant = enemy.statuses["taunt"]["caster"]
		if taunter != null and not taunter.is_down:
			return taunter
	return _nearest(enemy, _standing(party))


## Ally AI, in priority order:
##   1. Stay out of danger: leave any enemy area that could hit, never walk into one.
##   2. Stand near the edge of its own attack range from the nearest enemy
##      (ally_range_share of its reach): close in if too far, back off if
##      much closer than needed, going around danger either way.
func _ally_step(ally: Combatant, delta: float) -> void:
	var margin := ally.body_radius + ally_danger_margin
	var away := Vector3.ZERO
	for enemy in enemies:
		if _is_danger(enemy) and enemy.attack_range.contains(ally.global_position, margin):
			var from_enemy := ally.global_position - enemy.global_position
			from_enemy.y = 0.0
			away += from_enemy.normalized()
	if away != Vector3.ZERO:
		ally.step(away, delta)
		_keep_in_arena(ally)
		return

	var threat := _nearest(ally, _standing(enemies))
	if threat == null:
		return
	var to_threat := threat.global_position - ally.global_position
	var gap := ally.gap_to(threat)
	var ideal := ally.reach() * ally_range_share
	if gap > ideal + 0.15:
		if _safe_step(ally, to_threat, delta):
			return
	elif gap < ideal - 1.0:
		if _safe_step(ally, -to_threat, delta):
			return
	ally.face_toward(to_threat, delta)


## Takes one step toward a direction, or the closest detour (up to 90° off)
## that doesn't enter a dangerous area. Returns false if every option is unsafe.
func _safe_step(fighter: Combatant, direction: Vector3, delta: float) -> bool:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return false
	direction = arena.steer(fighter.global_position, direction.normalized(), fighter.body_radius)
	var margin := fighter.body_radius + ally_danger_margin
	for degrees in [0.0, 35.0, -35.0, 70.0, -70.0, 90.0, -90.0]:
		var dir := direction.rotated(Vector3.UP, deg_to_rad(degrees))
		var next := fighter.global_position + dir * fighter.move_speed * delta
		if not _in_danger(next, margin):
			fighter.step(dir, delta)
			_keep_in_arena(fighter)
			return true
	return false


## An enemy area worth avoiding: a revealed Attack/Smash, or anything still
## being prepared (allies can't know a hidden skill is harmless).
func _is_danger(enemy: Combatant) -> bool:
	if enemy.attack_range == null or enemy.is_down or enemy.loaded_skill == Skills.NONE:
		return false
	return not enemy.skill_revealed or Skills.is_offensive(enemy.loaded_skill)


func _in_danger(point: Vector3, extra_radius: float) -> bool:
	for enemy in enemies:
		if _is_danger(enemy) and enemy.attack_range.contains(point, extra_radius):
			return true
	return false


## Pushes apart any two fighters standing inside each other.
## Enemies are heavy: party members get pushed, enemies don't.
func _resolve_overlaps() -> void:
	for i in combatants.size():
		for j in range(i + 1, combatants.size()):
			var a := combatants[i]
			var b := combatants[j]
			var offset := b.global_position - a.global_position
			offset.y = 0.0
			var min_distance := a.body_radius + b.body_radius
			var distance := offset.length()
			if distance >= min_distance:
				continue
			var push_dir := offset.normalized() if distance > 0.001 else Vector3.RIGHT
			var overlap := min_distance - distance
			if a.team == Combatant.Team.ENEMY and b.team == Combatant.Team.PARTY:
				b.global_position += push_dir * overlap
			elif b.team == Combatant.Team.ENEMY and a.team == Combatant.Team.PARTY:
				a.global_position -= push_dir * overlap
			else:
				a.global_position -= push_dir * overlap / 2.0
				b.global_position += push_dir * overlap / 2.0
	for c in combatants:
		_keep_in_arena(c)


## Keeps a fighter inside the arena's edges and out of rocks and pits.
func _keep_in_arena(fighter: Combatant) -> void:
	arena.keep_inside(fighter, fighter.body_radius)


## True if nothing (a rock) stands between two fighters.
func _can_see(a: Combatant, b: Combatant) -> bool:
	return arena.has_line_of_sight(a.global_position, b.global_position)


# --- Enemy skills ---------------------------------------------------------

## An enemy entered the casting zone: it starts preparing a skill, but
## you only see that it's preparing something, not what.
## Defense and Counter take effect right away (still hidden).
func _begin_cast(enemy: Combatant) -> void:
	enemy.loaded_def = enemy.pick_skill()
	enemy.loaded_skill = enemy.loaded_def.kind
	enemy.skill_revealed = false
	enemy.stance_time_left = 0.0
	enemy.stance = Skills.NONE if Skills.is_offensive(enemy.loaded_skill) else enemy.loaded_skill
	enemy.show_skill_text("...", Color(0.75, 0.75, 0.8))
	print("%s is preparing %s (hidden)" % [enemy.display_name, enemy.loaded_def.skill_name])


## Late in the casting zone the prepared skill becomes visible: on the
## bar, above the enemy, and as a live area on the floor.
func _reveal_skill(enemy: Combatant) -> void:
	enemy.skill_revealed = true
	var def := enemy.loaded_def
	var text := def.skill_name.to_upper()
	if enemy.attack_range:
		enemy.attack_range.show_skill(def)
	if not def.is_offensive():
		text += " STANCE"
	enemy.show_skill_text(text, def.color())
	print("%s reveals %s" % [enemy.display_name, def.skill_name])


## The enemy reached the end of the bar (or was triggered). Attack and
## Smash start a strike on whoever is in the area; a Defense or Counter
## stance ends. reset_timeline sends it back to the start of the bar
## afterwards (used when it acts during your turn; on its own turn,
## _end_turn does that).
func _enemy_unleash(enemy: Combatant, reset_timeline: bool) -> void:
	if not enemy.skill_revealed:
		_reveal_skill(enemy)
	var skill_name := enemy.loaded_def.skill_name
	if enemy.loaded_def.is_offensive():
		var targets: Array[Combatant] = []
		var shielded := false
		for member in _standing(party):
			if enemy.attack_range and enemy.attack_range.contains(member.global_position, member.body_radius):
				if _can_see(enemy, member):
					targets.append(member)
				else:
					shielded = true  # in the area, but a rock was in the way
		if shielded:
			_count("rock_saves")
		if targets.is_empty():
			_count("misses")
			_flash("%s's %s misses!" % [enemy.display_name, skill_name])
			_finish_enemy_skill(enemy, reset_timeline)
		else:
			_begin_strike(enemy, targets, reset_timeline)
		return

	# Defense/Counter: the stance lingers a few seconds after the turn.
	enemy.loaded_skill = Skills.NONE
	enemy.skill_revealed = false
	enemy.stance_time_left = stance_linger
	_flash("%s holds its %s stance!" % [enemy.display_name, skill_name])
	if reset_timeline:
		_send_to_start(enemy)


## Clean-up after an Attack or Smash, hit or miss.
func _finish_enemy_skill(enemy: Combatant, reset_timeline: bool) -> void:
	if enemy.attack_range:
		enemy.attack_range.go_dormant()
	enemy.show_skill_text("")
	enemy.loaded_skill = Skills.NONE
	enemy.skill_revealed = false
	enemy.stance = Skills.NONE
	enemy.stance_time_left = 0.0
	enemy.loaded_def = null
	if reset_timeline:
		_send_to_start(enemy)


## Counts down lingering Defense/Counter stances; drops them at zero.
func _tick_stances(delta: float) -> void:
	for enemy in enemies:
		if enemy.stance == Skills.NONE or enemy.loaded_skill != Skills.NONE or enemy.stance_time_left <= 0.0:
			continue
		enemy.stance_time_left -= delta
		var skill_name: String = enemy.loaded_def.skill_name if enemy.loaded_def else Skills.info(enemy.stance)["name"]
		if enemy.stance_time_left <= 0.0:
			_flash("%s's %s stance ends" % [enemy.display_name, skill_name])
			_finish_enemy_skill(enemy, false)
		else:
			enemy.show_skill_text("%s STANCE %.0fs" % [skill_name.to_upper(), ceilf(enemy.stance_time_left)],
					Skills.info(enemy.stance)["color"])


## Brightens live areas that have someone in them, and during your turn
## makes the enemy strike if you moved into its Attack or Smash area.
func _update_attack_ranges() -> void:
	var warnings: PackedStringArray = []
	for enemy in enemies:
		if enemy.attack_range == null:
			continue
		var targets: PackedStringArray = []
		if _is_live_threat(enemy):
			for member in _standing(party):
				if enemy.attack_range.contains(member.global_position, member.body_radius) and _can_see(enemy, member):
					targets.append(member.display_name)
		enemy.attack_range.set_alert(not targets.is_empty())
		if targets.is_empty():
			continue
		if _world_moved and active == null and _strike == null and not enemy.hold:
			_enemy_unleash(enemy, true)  # someone touched it: it strikes now
		else:
			var skill_name := enemy.loaded_def.skill_name
			warnings.append("%s's %s will hit: %s" % [enemy.display_name, skill_name, ", ".join(targets)])
	warning_label.text = "\n".join(warnings)


## True if a point is inside any enemy's live Attack/Smash area.
func _in_any_attack_range(point: Vector3, extra_radius: float) -> bool:
	for enemy in enemies:
		if _is_live_threat(enemy) and enemy.attack_range.contains(point, extra_radius):
			return true
	return false


## An enemy whose revealed Attack or Smash area can hurt you right now.
func _is_live_threat(enemy: Combatant) -> bool:
	return enemy.attack_range != null and enemy.skill_revealed and Skills.is_offensive(enemy.loaded_skill)


# --- Strikes, Parry and Defend --------------------------------------------

func _begin_strike(enemy: Combatant, targets: Array[Combatant], reset_timeline: bool) -> void:
	var s := Strike.new()
	s.enemy = enemy
	s.skill = enemy.loaded_skill
	s.def = enemy.loaded_def
	s.targets = targets
	s.windup = s.def.windup
	s.time_left = s.windup
	s.reset_timeline = reset_timeline
	for target in targets:
		# A fixed white marker shows where the ring will land; the ring
		# shrinks onto it and turns gold when it's time to parry.
		var ring_radius := target.body_radius + 0.3
		var marker := _make_ring(ring_radius, 0.06, Color(1, 1, 1, 0.7))
		var ring := _make_ring(ring_radius, 0.1, Color.WHITE)
		target.add_child(marker)
		target.add_child(ring)
		s.markers.append(marker)
		s.rings.append(ring)
	_strike = s
	print("%s's %s strikes at %s" % [enemy.display_name, s.def.skill_name, _names(targets)])


func _update_strike(delta: float) -> void:
	_strike.time_left -= delta
	var progress := maxf(_strike.time_left, 0.0) / _strike.windup  # 1 at start, 0 at impact
	var color := Color.WHITE
	match _strike.reaction:
		Reaction.PARRY_MISSED:
			color = Color(1.0, 0.25, 0.2)
		Reaction.DEFEND:
			color = Color(0.35, 0.65, 1.0)
		Reaction.PARRY:
			color = Color(1.0, 0.85, 0.2)
		_:
			if _strike.time_left <= parry_window:
				color = Color(1.0, 0.85, 0.2)
	for ring in _strike.rings:
		var scale_factor := 1.0 + 2.0 * progress
		ring.scale = Vector3(scale_factor, 1.0, scale_factor)
		(ring.material_override as StandardMaterial3D).albedo_color = color
	if _strike.time_left <= 0.0:
		_resolve_strike()


## E: a Parry. Only one try per strike.
func _try_parry() -> void:
	if _strike.reaction != Reaction.NONE:
		return
	if _strike.def.cannot_be_parried:
		_flash("%s can't be parried!" % _strike.def.skill_name)
		return
	if not _strike_targets_can("parry"):
		_flash("%s can't parry" % _names(_strike.targets))
		return
	if _strike.time_left <= parry_window:
		_strike.reaction = Reaction.PARRY
	else:
		_strike.reaction = Reaction.PARRY_MISSED


## Q: Defend. Costs AP, can't be combined with a parry attempt.
func _try_defend() -> void:
	if _strike.reaction != Reaction.NONE:
		return
	if _strike.def.cannot_be_blocked:
		_flash("%s can't be blocked!" % _strike.def.skill_name)
		return
	if not _strike_targets_can("block"):
		_flash("%s can't block" % _names(_strike.targets))
		return
	if ap < defend_cost:
		_flash("Not enough AP to defend (%d needed)" % defend_cost)
		return
	ap -= defend_cost
	_strike.reaction = Reaction.DEFEND


func _resolve_strike() -> void:
	var s := _strike
	_strike = null
	for node in s.rings + s.markers:
		node.queue_free()

	var skill_name := s.def.skill_name
	var damage := s.def.damage
	var lines: PackedStringArray = []
	var parried := false
	var parry_missed := false

	# One Parry/Defend input covers everyone hit, but only those whose class
	# can parry/block get the benefit; the rest take the full hit.
	for target in s.targets:
		if target.riposte_left > 0.0:
			_riposte(target, s.enemy, lines)
			continue
		var can_parry := target.can_parry and not s.def.cannot_be_parried
		var can_block := target.can_block and not s.def.cannot_be_blocked
		if s.reaction == Reaction.PARRY and can_parry:
			parried = true
			_popup(target, "PARRY!", Color(1.0, 0.85, 0.2))
			lines.append("%s parried %s's %s!" % [target.display_name, s.enemy.display_name, skill_name])
		elif s.reaction == Reaction.DEFEND and can_block:
			_count("defends")
			var share := defend_share_vs_smash if s.skill == Skills.Kind.SMASH else defend_share_vs_attack
			var taken := target.take_damage(ceili(damage * share), true)
			_popup(target, str(taken), Color(0.6, 0.8, 1.0))
			var guard_note := " Guard broken!" if s.skill == Skills.Kind.SMASH else ""
			lines.append("%s defended:%s -%d HP (recoverable)" % [target.display_name, guard_note, taken])
		else:
			var taken := target.take_damage(damage, false)
			_popup(target, str(taken), Color(1.0, 0.4, 0.3))
			if s.reaction == Reaction.PARRY_MISSED and can_parry:
				parry_missed = true
				_push_back(target, parry_miss_push)
			lines.append("%s's %s hits %s for %d!%s" % [s.enemy.display_name, skill_name, target.display_name, taken,
					_absorb_note(damage, taken)])

	if parried:
		_count("parries")
		s.enemy.timeline_penalty += stagger_push
		lines.append("%s is staggered" % s.enemy.display_name)
		lines.append(_grow_max_ap(parry_max_ap_gain, s.targets[0]))
	if parry_missed:
		ap *= 0.5
		lines.append("Parry too early! Turn delayed, AP halved")
		var reset_note := _reset_max_ap()
		if reset_note != "":
			lines.append(reset_note)

	for target in s.targets:
		if target.is_down:
			lines.append("%s is down!" % target.display_name)

	_finish_enemy_skill(s.enemy, s.reset_timeline)
	_flash("\n".join(lines))
	print(" / ".join(lines))
	_check_party()
	_check_enemies()
	strike_finished.emit()


## Handles knocked-out fighters: hands control back if needed, and ends
## the battle if nobody is left standing.
## True if anyone caught in the strike can "parry" or "block" it.
func _strike_targets_can(reaction: String) -> bool:
	for target in _strike.targets:
		if (target.can_parry if reaction == "parry" else target.can_block):
			return true
	return false


## " (Brace / shield soaked 12)" when less HP was lost than the hit dealt.
func _absorb_note(damage: int, taken: int) -> String:
	return " (%d soaked)" % (damage - taken) if taken < damage else ""


## Archer's Riposte: the hit is countered, the enemy hurt and pushed away.
func _riposte(archer: Combatant, enemy: Combatant, lines: PackedStringArray) -> void:
	var damage := ceili(archer.attack_power * 2.0)
	enemy.take_damage(damage, false)
	_popup(archer, "RIPOSTE!", Color(1.0, 0.85, 0.2))
	_popup(enemy, str(damage), Color.WHITE)
	_knock_away(enemy, archer.global_position, 3.0)
	lines.append("%s ripostes! %s takes %d and is pushed back" % [archer.display_name, enemy.display_name, damage])


## Shoves a fighter straight away from a point, stopping at walls and rocks.
func _knock_away(fighter: Combatant, from: Vector3, meters: float) -> void:
	var away := fighter.global_position - from
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = -fighter.flat_forward()
	var steps := 8
	for i in steps:
		fighter.global_position += away.normalized() * meters / steps
		_keep_in_arena(fighter)


func _check_party() -> void:
	if _standing(party).is_empty():
		_game_over = true  # _update_ui shows the game-over text from now on
		_result_text = "The party has fallen..."
		print("Game over")
		return
	if active != null and active.team == Combatant.Team.PARTY and active.is_down:
		_end_turn()
	if controlled != null and controlled.is_down:
		_set_controlled(_standing(party)[0])


## Ends the battle in victory once every enemy is down.
func _check_enemies() -> void:
	if _game_over:
		return
	for enemy in enemies:
		if enemy.is_down and enemy.attack_range and enemy.attack_range.visible:
			_finish_enemy_skill(enemy, false)
			enemy.attack_range.visible = false
	if _standing(enemies).is_empty():
		_game_over = true
		_result_text = "Tutorial complete!" if tutorial_mode else "Victory!"
		print("Victory")


# --- Party attacks --------------------------------------------------------

## A party turn starts: the command menu opens. Attack needs an enemy that
## at least one of the fighter's attacks can reach.
func _open_commands() -> void:
	_menu_mode = BattleMenu.Mode.COMMANDS
	var can_attack := _attack_target() != null
	battle_menu.command_index = 0 if can_attack else 2  # start on Wait if out of reach
	battle_menu.command_enabled[0] = can_attack
	battle_menu.command_notes[0] = "" if can_attack else "no enemy in reach"


## Keys while a menu is open. W/S move the cursor, J confirms, K goes back,
## and in the combo bar Space starts the combo.
func _menu_input(event: InputEvent) -> void:
	if _menu_mode == BattleMenu.Mode.EXECUTING:
		if event.is_action_pressed("confirm"):
			get_viewport().set_input_as_handled()
			_judge_timing()
		return
	var up := event.is_action_pressed("move_forward")
	var down := event.is_action_pressed("move_back")
	var confirm := event.is_action_pressed("confirm")
	var cancel := event.is_action_pressed("cancel")
	var begin := event.is_action_pressed("end_turn")
	if not (up or down or confirm or cancel or begin):
		return
	get_viewport().set_input_as_handled()

	match _menu_mode:
		BattleMenu.Mode.COMMANDS:
			var count := battle_menu.commands.size()
			if up:
				battle_menu.command_index = (battle_menu.command_index - 1 + count) % count
			elif down:
				battle_menu.command_index = (battle_menu.command_index + 1) % count
			elif confirm:
				var index := battle_menu.command_index
				if not battle_menu.command_enabled[index]:
					_flash("%s: %s" % [battle_menu.commands[index], battle_menu.command_notes[index]])
				elif index == 0:
					_open_combo_bar()
				elif index == 1:
					_open_skills()
				elif index == 2:
					_wait_command()
		BattleMenu.Mode.SKILLS:
			if up or down:
				var n := _skills.size()
				battle_menu.move_index = (battle_menu.move_index + (1 if down else -1) + n) % n
			elif confirm:
				_choose_skill(battle_menu.move_index)
			elif cancel:
				_menu_mode = BattleMenu.Mode.COMMANDS
		BattleMenu.Mode.TARGET:
			var by_point: bool = _pending_skill["target"] == Moves.Target.POINT
			if (up or down) and not by_point and not _target_choices.is_empty():
				var n := _target_choices.size()
				_target_index = (_target_index + (1 if down else -1) + n) % n
			elif confirm:
				_confirm_target()
			elif cancel:
				_clear_target_marker()
				_menu_mode = BattleMenu.Mode.SKILLS
		BattleMenu.Mode.COMBO:
			if up:
				battle_menu.move_index = (battle_menu.move_index - 1 + _moves.size()) % _moves.size()
			elif down:
				battle_menu.move_index = (battle_menu.move_index + 1) % _moves.size()
			elif confirm:
				_add_to_combo(battle_menu.move_index)
			elif cancel:
				if _plan.is_empty():
					_menu_mode = BattleMenu.Mode.COMMANDS
				else:
					_plan.pop_back()
					battle_menu.combo.pop_back()
			elif begin:
				if _plan.is_empty():
					_flash("Add at least one move first (J)")
				else:
					_execute_combo()


## Wait: end the turn without spending AP. The fighter's bar restarts a
## third of the way along, so their next turn comes sooner.
func _wait_command() -> void:
	var fighter := active
	_end_turn()
	fighter.timeline_pos += wait_head_start
	_flash("%s waits" % fighter.display_name)
	_count("waits")
	for enemy in _standing(enemies):
		if enemy.stance == Skills.Kind.COUNTER:
			_count("counter_waits")
			break


func _open_combo_bar() -> void:
	_combo_target = _attack_target()
	_moves = Moves.attacks(controlled.class_id)
	var doubled := controlled.statuses.has("arcane_cost")
	var usable: Array[bool] = []
	var notes: PackedStringArray = []
	for move in _moves:
		if doubled:
			move["cost"] = int(move["cost"]) * 2
		var reaches := _can_target(controlled, _combo_target, move)
		usable.append(reaches)
		notes.append("" if reaches else "%s is out of its reach" % _combo_target.display_name)
	_menu_mode = BattleMenu.Mode.COMBO
	_plan.clear()
	battle_menu.moves = _moves
	battle_menu.move_usable = usable
	battle_menu.move_notes = notes
	battle_menu.plan = _plan
	battle_menu.combo.clear()
	battle_menu.move_index = 0
	battle_menu.executing_slot = -1
	battle_menu.slot_results.clear()
	if doubled:
		_flash("Arcane Barrier: attacks cost double this turn")


## Adds a move to the bar if it fits both the fighter's combo limit and
## the party's AP. The slot's exact hits and timings are worked out now.
func _add_to_combo(index: int) -> void:
	if not battle_menu.move_usable[index]:
		_flash(battle_menu.move_notes[index])
		return
	var entry := _plan_slot(_moves[index])
	var cost := float(entry["cost"])
	var used := battle_menu.combo_cost()
	if used + cost > controlled.combo_limit:
		_flash("%s's combo bar is full" % controlled.display_name)
	elif used + cost > ap:
		_flash("Not enough AP (%d left)" % floori(ap - used))
	else:
		_plan.append(entry)
		battle_menu.combo.append(index)


## What one combo slot will do: its hits, where each lands (as a fraction of
## the block), and its timing box. Handles Bash's growing hits, Agility's
## extra hit, and delayed or random timings.
func _plan_slot(move: Dictionary) -> Dictionary:
	var hits: Array = (move["hits"] as Array).duplicate()
	var times: Array = (move.get("times", []) as Array).duplicate()
	var duration: float = move["duration"]
	if move["escalating"]:
		var count := 1
		for entry in _plan:
			if entry["name"] == move["name"]:
				count += 1
		hits = []
		for i in count:
			hits.append(move["hits"][0])
		duration = 0.3 + 0.22 * count
		if count > 3:
			# From the fourth Bash on, the hits land at random moments.
			var spacing := 1.0 / count
			for i in count - 1:
				times.append(spacing * (i + 1) + randf_range(-0.35, 0.35) * spacing)
			times.append(1.0)
	if controlled.statuses.has("agility"):
		if times.is_empty():
			duration *= float(hits.size() + 1) / hits.size()
			hits.append(hits[0])
		else:
			var last: float = times[-1]
			var before: float = times[-2] if times.size() > 1 else 0.0
			hits.insert(hits.size() - 1, hits[0])
			times.insert(times.size() - 1, (before + last) / 2.0)
	if times.is_empty():
		for i in hits.size():
			times.append(float(i + 1) / hits.size())
	return {
		"move": move, "name": move["name"], "color": move["color"], "cost": move["cost"],
		"hits": hits, "times": times, "duration": duration,
		"window": float(move["window"]) / duration,
	}


## Starts playing the combo. _update_combo then runs it frame by frame.
func _execute_combo() -> void:
	_menu_mode = BattleMenu.Mode.EXECUTING
	_exec_attacker = controlled
	_ap_before_combo = ap
	ap -= battle_menu.combo_cost()
	_exec_attacker.statuses.erase("arcane_cost")  # Arcane Barrier's cost lasts until the next attack
	_count("combos")
	_count("combos_" + _exec_attacker.class_id)
	_exec_attacker.face_toward(_combo_target.global_position - _exec_attacker.global_position, 1.0, 100000.0)
	battle_menu.slot_results.clear()
	for entry in _plan:
		var per_hit: Array[int] = []
		per_hit.resize((entry["hits"] as Array).size())
		per_hit.fill(Timing.NONE)
		battle_menu.slot_results.append(per_hit)
	_exec_outro = -1.0
	_start_combo_slot(0)
	# A short lead-in so the player can get ready for the timing.
	_exec_lead_in = combo_lead_in
	battle_menu.lead_in_progress = 0.0


func _start_combo_slot(slot: int) -> void:
	_exec_slot = slot
	_exec_time = 0.0
	_exec_hits_done = 0
	_exec_timings.clear()
	_exec_timings.resize((_plan[slot]["hits"] as Array).size())
	_exec_timings.fill(Timing.NONE)
	battle_menu.executing_slot = slot
	battle_menu.slot_progress = 0.0


## Moves the playhead through the current block at that move's own speed,
## landing its hits at their planned moments.
func _update_combo(delta: float) -> void:
	if _exec_lead_in > 0.0:
		_exec_lead_in -= delta
		battle_menu.lead_in_progress = clampf(1.0 - _exec_lead_in / combo_lead_in, 0.0, 1.0)
		if _exec_lead_in <= 0.0:
			battle_menu.lead_in_progress = -1.0
		return
	if _exec_outro >= 0.0:
		_exec_outro -= delta
		if _exec_outro < 0.0:
			_menu_mode = BattleMenu.Mode.HIDDEN
			if active != null and not _game_over:
				_end_turn()
		return

	var entry := _plan[_exec_slot]
	var duration: float = entry["duration"]
	var hits: Array = entry["hits"]
	var times: Array = entry["times"]
	_exec_time += delta
	battle_menu.slot_progress = clampf(_exec_time / duration, 0.0, 1.0)

	while _exec_hits_done < hits.size() and _exec_time >= duration * float(times[_exec_hits_done]):
		var multiplier: float = hits[_exec_hits_done]
		var perfect := _exec_timings[_exec_hits_done] == Timing.PERFECT
		if _exec_timings[_exec_hits_done] == Timing.NONE:
			_shrink_max_ap(skipped_hit_max_ap_loss, _exec_attacker)  # opted out of the timing
		if perfect:
			multiplier *= 1.0 + perfect_damage_bonus
		_exec_attacker.play_lunge()
		var keep_going := _land_hit(_exec_attacker, entry["move"], multiplier, _exec_hits_done == 0)
		_exec_hits_done += 1
		if perfect:
			_popup(_exec_attacker, "PERFECT!", Color(1.0, 0.85, 0.2))
			_count("perfects")
			_flash(_grow_max_ap(perfect_max_ap_gain, _exec_attacker))
		if not keep_going or _game_over:
			_stop_combo()
			return

	if _exec_hits_done >= hits.size():
		if _exec_slot + 1 < _plan.size():
			_start_combo_slot(_exec_slot + 1)
		else:
			battle_menu.executing_slot = _plan.size()  # playhead to the end
			_exec_outro = 0.4


## J during the combo: inside the next hit's timing box = Perfect;
## anywhere else = miss, and the chain ends right there. One try per hit.
func _judge_timing() -> void:
	if _exec_outro >= 0.0 or _exec_lead_in > 0.0:  # presses during the lead-in are ignored
		return
	var entry := _plan[_exec_slot]
	var duration: float = entry["duration"]
	var window: float = float(entry["window"]) * duration
	var hit := _exec_hits_done
	if hit >= _exec_timings.size() or _exec_timings[hit] != Timing.NONE:
		return  # one try per hit
	var hit_time := duration * float(entry["times"][hit])
	if _exec_time >= hit_time - window:
		_exec_timings[hit] = Timing.PERFECT
		battle_menu.slot_results[_exec_slot][hit] = Timing.PERFECT
	else:
		_exec_timings[hit] = Timing.MISS
		battle_menu.slot_results[_exec_slot][hit] = Timing.MISS
		_popup(_exec_attacker, "MISS", Color(1.0, 0.35, 0.3))
		_flash("Missed the timing! The chain ends. " + _reset_max_ap())
		_stop_combo()


## Raises the party's max AP for the rest of the fight. Returns a message.
func _grow_max_ap(amount: float, at: Combatant) -> String:
	var before := current_max_ap
	current_max_ap = minf(current_max_ap + amount, max_ap_ceiling)
	var gained := current_max_ap - before
	if gained <= 0.0:
		return "Max AP is already at its limit (%d)" % int(max_ap_ceiling)
	_popup(at, "+%d MAX AP" % roundi(gained), Color(0.45, 0.85, 1.0))
	return "Max AP +%d (now %d)" % [roundi(gained), int(current_max_ap)]


## AP gain scales with how far max AP has grown: 1.0 at the starting cap,
## 1.5 at 150, 2.0 at 200.
func _ap_gain_multiplier() -> float:
	return current_max_ap / max_ap


## A skipped timed hit: lose a little of the extra max AP (not below max_ap).
func _shrink_max_ap(amount: float, at: Combatant) -> void:
	if current_max_ap <= max_ap:
		return
	var before := current_max_ap
	current_max_ap = maxf(current_max_ap - amount, max_ap)
	ap = minf(ap, current_max_ap)
	_popup(at, "-%d MAX AP" % roundi(before - current_max_ap), Color(0.6, 0.6, 0.7))


## A missed Parry or Perfect: max AP drops back to its starting value,
## and any AP above that is lost. Returns a message.
func _reset_max_ap() -> String:
	if current_max_ap <= max_ap:
		return ""
	current_max_ap = max_ap
	ap = minf(ap, current_max_ap)
	return "Max AP reset to %d" % int(max_ap)


## Ends the combo early: the playhead freezes where it is.
func _stop_combo() -> void:
	_exec_outro = 0.7


## One hit of a move lands: works out everyone it reaches (by the move's
## area), applies it to each, and handles barriers. Returns false if the
## combo should stop (countered, attacker down, nobody left to hit).
func _land_hit(attacker: Combatant, move: Dictionary, multiplier: float, first_hit: bool) -> bool:
	if attacker.is_down:
		return false
	if first_hit and float(move["barrier"]) > 0.0:
		_give_barrier(attacker, move)
	var keep_going := true
	for victim in _hit_victims(attacker, move):
		var enemy: Combatant = victim[0]
		if not _resolve_combo_hit(attacker, enemy, move, multiplier * float(victim[1])):
			keep_going = false
			break
	_check_enemies()
	if _game_over or not keep_going:
		return false
	if _combo_target.is_down:
		# The target fell: carry on against the nearest enemy still in reach.
		_combo_target = _attack_target()
		if _combo_target == null:
			return false
		_flash("%s turns to %s" % [attacker.display_name, _combo_target.display_name])
	return true


## Everyone one hit reaches, each with a damage share: [[enemy, share], ...].
func _hit_victims(attacker: Combatant, move: Dictionary) -> Array:
	var result := []
	var size: float = move["area_size"]
	match move["area"]:
		Moves.Area.TARGET_CIRCLE:
			for enemy in _standing(enemies):
				var d := enemy.global_position.distance_to(_combo_target.global_position) - enemy.body_radius
				if enemy == _combo_target or d <= size:
					result.append([enemy, 1.0])
		Moves.Area.LINE:
			# From the attacker through the target and beyond: full damage on
			# the first enemy, falloff on everyone behind.
			var dir := _combo_target.global_position - attacker.global_position
			dir.y = 0.0
			var length := dir.length() + 6.0
			dir = dir.normalized()
			var in_line := []
			for enemy in _standing(enemies):
				var offset := enemy.global_position - attacker.global_position
				offset.y = 0.0
				var along := offset.dot(dir)
				var side := (offset - dir * along).length()
				if along >= 0.0 and along <= length and side <= size / 2.0 + enemy.body_radius and _can_see(attacker, enemy):
					in_line.append([enemy, along])
			in_line.sort_custom(func(a, b): return a[1] < b[1])
			for i in in_line.size():
				result.append([in_line[i][0], 1.0 if i == 0 else float(move["falloff"])])
		Moves.Area.SELF_CIRCLE:
			for enemy in _standing(enemies):
				if attacker.gap_to(enemy) <= size:
					result.append([enemy, 1.0])
		Moves.Area.ALL:
			for enemy in _standing(enemies):
				result.append([enemy, 1.0])
		_:
			result.append([_combo_target, 1.0])
	return result


## Cleric's Divine Barrier: allies near the user get barrier HP.
func _give_barrier(user: Combatant, move: Dictionary) -> void:
	for ally in _standing(party):
		if ally.global_position.distance_to(user.global_position) <= float(move["barrier_radius"]):
			var gained := ally.add_shield(ceili(ally.max_hp * float(move["barrier"])))
			if gained > 0:
				_popup(ally, "+%d BARRIER" % gained, Color(0.55, 0.8, 1.0))


## Applies the skill triangle to one hit on one enemy, then the move's extra
## effects (stun, knockback). Returns false only if a Counter stance
## punished the attacker (the combo stops).
func _resolve_combo_hit(attacker: Combatant, target: Combatant, move: Dictionary, multiplier: float) -> bool:
	if attacker.is_down or target.is_down:
		return true
	var move_name: String = move["name"]

	if target.stance == Skills.Kind.COUNTER:
		# Counter beats every attack: the enemy punishes you, combo over.
		var taken := attacker.take_damage(counter_stance_damage, false)
		_popup(target, "COUNTER!", Skills.info(Skills.Kind.COUNTER)["color"])
		_popup(attacker, str(taken), Color(1.0, 0.4, 0.3))
		_flash("%s's Counter stance punishes the %s! Combo stopped" % [target.display_name, move_name])
		_check_party()
		return false

	var note := ""
	if target.stance == Skills.Kind.DEFENSE:
		match move["effect"]:
			Moves.Effect.BREAK:
				note = "Guard broken!"
				_count("guard_breaks")
				_cancel_enemy_skill(target)
			Moves.Effect.PIERCE:
				note = "Pierce!"
				_count("guard_breaks")
			_:
				_popup(target, "BLOCKED", Skills.info(Skills.Kind.DEFENSE)["color"])
				_flash("%s's Defense blocks the %s. Piercing or breaking moves get through!" % [target.display_name, move_name])
				return true
	elif target.loaded_skill == Skills.Kind.SMASH and move["kind"] == Skills.Kind.ATTACK:
		note = "Smash interrupted!"
		_count("interrupts")
		_cancel_enemy_skill(target)

	var damage := ceili(attacker.attack_power * multiplier)
	target.take_damage(damage, false)
	var is_smash: bool = move["kind"] == Skills.Kind.SMASH
	_popup(target, str(damage), Color(1.0, 0.7, 0.3) if is_smash else Color.WHITE)

	if move["stun"] and not target.is_down and target.loaded_skill != Skills.NONE \
			and Skills.is_offensive(target.loaded_skill):
		# Stunning Arrow: an enemy about to strike loses its turn.
		_finish_enemy_skill(target, false)
		target.timeline_pos = 0.0
		note = "Stunned! Turn cancelled"
	if float(move["knockback"]) > 0.0 and not target.is_down:
		_knock_away(target, attacker.global_position, move["knockback"])

	if note != "":
		_popup(target, note.to_upper(), Color(1.0, 0.85, 0.2))
		_flash(note)
	if target.is_down:
		_flash("%s is defeated!" % target.display_name)
	return true


## The enemy loses its prepared skill (and stance) and is knocked back
## out of the casting zone, so it has to prepare again.
func _cancel_enemy_skill(enemy: Combatant) -> void:
	_finish_enemy_skill(enemy, false)
	enemy.timeline_pos = minf(enemy.timeline_pos - interrupt_push, cast_zone_start - 1.0)


## Pushes an enemy back on the timeline; if that takes it out of the
## casting zone, it loses the skill it was preparing.
func _knock_back_enemy(enemy: Combatant, amount: float) -> void:
	enemy.timeline_pos -= amount
	if enemy.loaded_skill != Skills.NONE and enemy.timeline_pos < cast_zone_start:
		_finish_enemy_skill(enemy, false)


## How far a move reaches for this fighter (its own reach, or the fighter's;
## True Sight extends both).
func _move_reach(fighter: Combatant, move: Dictionary) -> float:
	var own: float = move["reach"]
	if own >= Moves.UNLIMITED:
		return INF
	var sight := fighter.reach() / fighter.attack_reach if fighter.attack_reach > 0.0 else 1.0
	return own * sight if own >= 0.0 else fighter.reach()


func _can_target(fighter: Combatant, enemy: Combatant, move: Dictionary) -> bool:
	var move_reach := _move_reach(fighter, move)
	if fighter.gap_to(enemy) > move_reach:
		return false
	return move_reach == INF or _can_see(fighter, enemy)


## The enemy the controlled fighter's attacks go after: the nearest one in
## its normal reach, or else the nearest one a long-range attack (Holy Light,
## Meteor Strike) can reach.
func _attack_target() -> Combatant:
	var attacks := Moves.attacks(controlled.class_id)
	var normal: Array[Dictionary] = attacks.filter(func(m): return float(m["reach"]) < 0.0)
	for pool in [normal, attacks]:
		var best: Combatant = null
		var best_gap := INF
		for enemy in _standing(enemies):
			var gap := controlled.gap_to(enemy)
			if gap >= best_gap:
				continue
			for move in pool:
				if _can_target(controlled, enemy, move):
					best = enemy
					best_gap = gap
					break
		if best != null:
			return best
	return null


# --- Skills (Abilities) ----------------------------------------------------

func _open_skills() -> void:
	_skills = Moves.skills(controlled.class_id)
	var usable: Array[bool] = []
	var notes: PackedStringArray = []
	for skill in _skills:
		var note := ""
		if int(skill["cost"]) > ap:
			note = "Not enough AP"
		elif int(skill["cost"]) > controlled.combo_limit:
			note = "Costs more than %s's AP limit" % controlled.display_name
		elif skill["target"] == Moves.Target.ENEMY and _skill_choices(skill).is_empty():
			note = "No enemy in range"
		elif skill["target"] == Moves.Target.OTHER_ALLY and _skill_choices(skill).is_empty():
			note = "No ally to choose"
		usable.append(note == "")
		notes.append(note)
	if _skills.is_empty():
		_flash("%s has no skills" % controlled.display_name)
		return
	_menu_mode = BattleMenu.Mode.SKILLS
	battle_menu.moves = _skills
	battle_menu.move_usable = usable
	battle_menu.move_notes = notes
	battle_menu.move_index = 0


## Who a skill can be used on, nearest first.
func _skill_choices(skill: Dictionary) -> Array[Combatant]:
	var choices: Array[Combatant] = []
	match skill["target"]:
		Moves.Target.ALLY:
			choices = _standing(party)
			choices.erase(controlled)
			choices.push_front(controlled)
		Moves.Target.OTHER_ALLY:
			choices = _standing(party)
			choices.erase(controlled)
		Moves.Target.ENEMY:
			for enemy in _standing(enemies):
				if controlled.gap_to(enemy) <= float(skill["range"]) and _can_see(controlled, enemy):
					choices.append(enemy)
			choices.sort_custom(func(a, b): return controlled.gap_to(a) < controlled.gap_to(b))
	return choices


func _choose_skill(index: int) -> void:
	var skill := _skills[index]
	if not battle_menu.move_usable[index]:
		_flash("%s: %s" % [skill["name"], battle_menu.move_notes[index]])
		return
	match skill["target"]:
		Moves.Target.SELF, Moves.Target.NONE:
			_use_skill(skill, controlled, controlled.global_position)
		Moves.Target.POINT:
			_begin_targeting(skill, "%s: move the marker with WASD" % skill["name"])
			_target_marker.global_position = controlled.global_position + controlled.flat_forward() * 3.0
			_keep_marker_in_range()
		_:
			_target_choices = _skill_choices(skill)
			_target_index = 0
			var what := "an enemy" if skill["target"] == Moves.Target.ENEMY else "an ally"
			_begin_targeting(skill, "%s: choose %s (W / S)" % [skill["name"], what])


func _begin_targeting(skill: Dictionary, prompt: String) -> void:
	_pending_skill = skill
	_menu_mode = BattleMenu.Mode.TARGET
	battle_menu.target_prompt = prompt
	_clear_target_marker()
	_target_marker = _make_ring(0.75, 0.12, Color(1.0, 0.85, 0.3))
	add_child(_target_marker)
	_update_target_marker(0.0)


## Keeps the marker on the chosen fighter, or moves it with WASD for Jump.
func _update_target_marker(delta: float) -> void:
	if _target_marker == null:
		return
	if _pending_skill["target"] == Moves.Target.POINT:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		_target_marker.global_position += _camera_relative(input) * 7.0 * delta
		_keep_marker_in_range()
	elif not _target_choices.is_empty():
		var chosen := _target_choices[_target_index]
		_target_marker.global_position = chosen.global_position + Vector3(0, 0.05, 0)
		var label := "%s: %s" % [_pending_skill["name"], chosen.display_name]
		battle_menu.target_prompt = label + "   (W / S to change)"


func _keep_marker_in_range() -> void:
	var from := controlled.global_position
	var offset := _target_marker.global_position - from
	offset.y = 0.0
	var limit: float = _pending_skill["range"]
	if offset.length() > limit:
		offset = offset.normalized() * limit
	_target_marker.global_position = from + offset
	arena.keep_inside(_target_marker, controlled.body_radius)
	_target_marker.global_position.y = 0.05


func _confirm_target() -> void:
	var point := _target_marker.global_position
	var chosen: Combatant = null
	if not _target_choices.is_empty() and _pending_skill["target"] != Moves.Target.POINT:
		chosen = _target_choices[_target_index]
	_clear_target_marker()
	_use_skill(_pending_skill, chosen, point)


func _clear_target_marker() -> void:
	if _target_marker != null:
		_target_marker.queue_free()
		_target_marker = null


## Carries out a skill, then the turn ends.
func _use_skill(skill: Dictionary, target: Combatant, point: Vector3) -> void:
	var user := controlled
	ap -= float(skill["cost"])
	_count("skills")
	_count("skills_" + user.class_id)
	var turns := int(skill["turns"])
	var message := "%s uses %s" % [user.display_name, skill["name"]]
	var head_start := 0.0
	match skill["name"]:
		"Light Heal", "Healing", "Full Cure":
			var who := target if target != null else user
			var healed := who.heal(ceili(who.max_hp * float(skill["heal"])))
			_popup(who, "+%d" % healed, Color(0.45, 0.95, 0.5))
			message += ": %s recovers %d HP" % [who.display_name, healed]
		"Brace", "Agility":
			user.add_status(String(skill["name"]).to_lower(), turns, user)
			_popup(user, String(skill["name"]).to_upper(), skill["color"])
		"Shield Bash":
			var dir := target.global_position - user.global_position
			dir.y = 0.0
			user.global_position = target.global_position - dir.normalized() * (target.body_radius + user.body_radius + 0.15)
			_keep_in_arena(user)
			user.face_toward(dir, 1.0, 100000.0)
			head_start = wait_head_start
			message += " on %s: next turn comes sooner" % target.display_name
		"Taunt":
			var taunted: Array[Combatant] = []
			for enemy in _standing(enemies):
				if user.gap_to(enemy) <= float(skill["radius"]):
					enemy.add_status("taunt", turns, user)
					taunted.append(enemy)
					_popup(enemy, "TAUNTED", skill["color"])
			message += ": " + (_names(taunted) + " now target " + user.display_name if not taunted.is_empty() else "nobody is close enough")
		"Jump":
			user.global_position = Vector3(point.x, user.global_position.y, point.z)
			_keep_in_arena(user)
		"Riposte":
			user.riposte_left = float(skill["seconds"])
			_popup(user, "RIPOSTE", skill["color"])
		"True Sight":
			for ally in _standing(party):
				ally.add_status("true_sight", turns, user)
			message += ": everyone's reach +25%"
		"Arcane Barrier":
			user.add_status("arcane_barrier", 0, user)
			user.add_status("arcane_cost", 0, user)
			_popup(user, "BARRIER", skill["color"])
		"Concentrate":
			_concentrate_left = float(skill["seconds"])
			message += ": AP recharges twice as fast"
		"Teleport":
			user.global_position = _spot_next_to(target, user)
			message += " next to %s" % target.display_name
		"Shielding":
			for ally in _standing(party):
				var gained := ally.add_shield(ceili(ally.max_hp * float(skill["shield"])))
				_popup(ally, "+%d SHIELD" % gained, Color(0.55, 0.8, 1.0))
		"Haste":
			target.add_status("haste", turns, user)
			_popup(target, "HASTE", skill["color"])
			message += " on %s" % target.display_name
	_flash(message)
	print(message)
	_menu_mode = BattleMenu.Mode.HIDDEN
	_end_turn()
	user.timeline_pos += head_start


## A free spot right beside a fighter (for Teleport).
func _spot_next_to(fighter: Combatant, mover: Combatant) -> Vector3:
	var distance := fighter.body_radius + mover.body_radius + 0.2
	for i in 8:
		var spot := fighter.global_position + Vector3.BACK.rotated(Vector3.UP, TAU * i / 8.0) * distance
		var free := true
		for c in combatants:
			if c != mover and not c.is_down and c.global_position.distance_to(spot) < c.body_radius + mover.body_radius:
				free = false
				break
		if free:
			mover.global_position = spot
			_keep_in_arena(mover)
			if mover.global_position.distance_to(spot) < 0.05:
				return spot
	return fighter.global_position + Vector3.BACK * distance


## A floating number or word that rises and fades above a fighter.
func _popup(at: Node3D, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 80
	label.outline_size = 20
	label.modulate = color
	add_child(label)
	label.global_position = at.global_position + Vector3(randf_range(-0.3, 0.3), 2.0, 0.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


func _make_ring(radius: float, width: float, color: Color) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var segments := 48
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var in0 := Vector3(cos(a0), 0, sin(a0)) * (radius - width)
		var out0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var in1 := Vector3(cos(a1), 0, sin(a1)) * (radius - width)
		var out1 := Vector3(cos(a1), 0, sin(a1)) * radius
		vertices.append_array([in0, out0, out1, in0, out1, in1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var ring_mesh := ArrayMesh.new()
	ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color

	var node := MeshInstance3D.new()
	node.mesh = ring_mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position.y = 0.06
	return node


# --- Camera and UI --------------------------------------------------------

func _update_camera(delta: float) -> void:
	var turn := Input.get_axis("camera_left", "camera_right")
	_cam_yaw -= turn * camera_turn_degrees_per_second * delta
	if _pan_time < _pan_duration:
		# A pan: ease in and out from where the camera was to its new subject.
		_pan_time += delta
		var t := clampf(_pan_time / _pan_duration, 0.0, 1.0)
		_cam_focus = _pan_start.lerp(_camera_focus(), t * t * (3.0 - 2.0 * t))
	else:
		# This "1 - exp(...)" form makes the smoothing feel the same at any frame rate.
		var weight := 1.0 - exp(-camera_follow_speed * delta)
		_cam_focus = _cam_focus.lerp(_camera_focus(), weight)
	_place_camera()


## Starts a smooth pan from the current view to the camera's new subject.
## Returns how long it takes (0 when it's already there).
func _begin_pan() -> float:
	_pan_start = _cam_focus
	var distance := _pan_start.distance_to(_camera_focus())
	_pan_time = 0.0
	_pan_duration = 0.0 if distance < 0.6 else clampf(0.3 + distance * 0.04, 0.3, turn_pan_max_seconds)
	return _pan_duration


func _place_camera() -> void:
	camera.global_rotation_degrees = Vector3(-_cam_pitch, _cam_yaw, 0.0)
	_camera_offset = camera.global_basis.z * _cam_distance
	camera.global_position = _cam_focus + _camera_offset


## Mouse: hold the right button and drag to rotate and tilt, wheel to zoom.
## V puts the camera back to its starting angle.
func _camera_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		_cam_yaw -= event.relative.x * camera_mouse_sensitivity
		_cam_pitch = clampf(_cam_pitch + event.relative.y * camera_mouse_sensitivity, camera_min_pitch, camera_max_pitch)
		return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = maxf(_cam_distance * 0.9, camera_min_distance)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = minf(_cam_distance * 1.1, camera_max_distance)
			return true
	if event.is_action_pressed("camera_reset"):
		_cam_yaw = 0.0
		_cam_pitch = _cam_start_pitch
		_cam_distance = camera_distance
		return true
	return false


## Turns WASD into a direction on the floor relative to the camera, so W
## always moves away from the screen, whichever way the camera faces.
func _camera_relative(input: Vector2) -> Vector3:
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return right.normalized() * input.x - forward.normalized() * input.y


## The point the camera looks at: the fighter whose turn it is (or, between
## turns, the one you steer), a bit of the way toward the nearest opponent so
## both stay on screen.
func _camera_focus() -> Vector3:
	# During anyone's turn the camera is on them; otherwise on who you steer.
	var subject := active if active != null else controlled
	var anchor := subject.global_position if subject != null else _party_center()
	var others := enemies if subject == null or subject.team == Combatant.Team.PARTY else _standing(party)
	var threat := _nearest_to_point(anchor, others)
	return anchor.lerp(threat.global_position, 0.35) if threat != null else anchor


func _update_ui(delta: float) -> void:
	party_status.controlled = controlled
	for member in party:
		var in_reach := false
		for enemy in _standing(enemies):
			if member.gap_to(enemy) <= member.reach() and _can_see(member, enemy):
				in_reach = true
				break
		member.update_reach_ring(member == controlled, in_reach)
	battle_menu.mode = _menu_mode if _party_turn() and not _game_over else BattleMenu.Mode.HIDDEN
	if controlled != null:
		battle_menu.fighter_name = controlled.display_name
		battle_menu.show_defend = controlled.can_block
		battle_menu.show_parry = controlled.can_parry
		battle_menu.combo_limit = controlled.combo_limit
		battle_menu.ap_available = _ap_before_combo if _menu_mode == BattleMenu.Mode.EXECUTING else ap
	if _game_over:
		# Placeholder end screen (a proper one is milestone 8).
		# The last message stays on screen so you can see what happened.
		turn_label.text = _result_text
		warning_label.text = _flash_message
		controls_label.visible = true
		var won := _result_text == "Victory!"
		if tutorial_mode:
			controls_label.text = "Esc: back to the menu     R: play the tutorial again"
		else:
			controls_label.text = ("N: next round     R: play again     Esc: menu" if won else "R: retry     N / P: next / previous round     Esc: menu")
		return
	var party_turn := _party_turn()
	controls_label.visible = (active == null or party_turn) and _strike == null and _menu_mode != BattleMenu.Mode.EXECUTING
	controls_label.text = _controls_hint()

	if _strike != null:
		var skill_name := _strike.def.skill_name
		turn_label.text = "%s: %s!" % [_strike.enemy.display_name, skill_name.to_upper()]
		warning_label.text = _strike_prompt()
	elif active == null:
		turn_label.text = "Positioning: %s" % controlled.display_name if controlled != null else ""
	elif _menu_mode == BattleMenu.Mode.EXECUTING:
		turn_label.text = "%s attacks!" % controlled.display_name
		if _flash_time_left <= 0.0:
			warning_label.text = "J when the playhead hits the box: Perfect!  (a wrong press ends the chain)"
	elif party_turn:
		turn_label.text = "%s's turn" % active.display_name
	else:
		turn_label.text = "%s acts!" % active.display_name

	ap_bar.max_value = current_max_ap
	ap_bar.value = ap
	ap_label.text = "Party AP  %d / %d" % [floori(ap), int(current_max_ap)]

	if _flash_time_left > 0.0:
		_flash_time_left -= delta
		if _strike == null:
			warning_label.text = _flash_message + ("\n" + warning_label.text if warning_label.text else "")


func _strike_prompt() -> String:
	match _strike.reaction:
		Reaction.PARRY:
			return "Parry!"
		Reaction.PARRY_MISSED:
			return "Too early!"
		Reaction.DEFEND:
			return "Defending..."
	var parry_hint := "E: can't Parry this" if _strike.def.cannot_be_parried else "E: Parry when the ring turns gold"
	var defend_hint := "Q: can't Defend this" if _strike.def.cannot_be_blocked else "Q: Defend (%d AP)" % defend_cost
	if not _strike_targets_can("parry"):
		parry_hint = "E: %s can't parry" % _names(_strike.targets)
	if not _strike_targets_can("block"):
		defend_hint = "Q: %s can't block" % _names(_strike.targets)
	var prompt := parry_hint + "     " + defend_hint
	if _flash_time_left > 0.0:
		prompt = _flash_message + "\n" + prompt
	return prompt


func _controls_hint() -> String:
	if _turn_intro_left > 0.0:
		return ""  # the camera is still panning to the fighter
	match _menu_mode:
		BattleMenu.Mode.COMMANDS:
			return "W / S: choose     J / Enter: select"
		BattleMenu.Mode.COMBO:
			return "W / S: choose move     J / Enter: add     K / Backspace: remove last     Space: begin"
		BattleMenu.Mode.SKILLS:
			return "W / S: choose skill     J / Enter: use (ends the turn)     K / Backspace: back"
		BattleMenu.Mode.TARGET:
			return ""
	var standing := _standing(party)
	var next_name := ""
	if standing.size() > 1 and controlled != null:
		next_name = standing[(standing.find(controlled) + 1) % standing.size()].display_name
	var tab_part := "     Tab: switch to %s" % next_name if next_name != "" else ""
	return "WASD: move %s (free)%s     Z / C or right-drag: camera     Esc: menu" % [controlled.display_name if controlled else "", tab_part]


## Shows a short message under the turn label for a moment.
func _flash(message: String) -> void:
	_flash_message = message
	_flash_time_left = 2.5


# --- Helpers --------------------------------------------------------------

## The fighters in a list who aren't knocked out.
func _standing(list: Array[Combatant]) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for c in list:
		if not c.is_down:
			result.append(c)
	return result


func _nearest(from: Combatant, candidates: Array[Combatant]) -> Combatant:
	return _nearest_to_point(from.global_position, candidates)


func _nearest_to_point(point: Vector3, candidates: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	var best_distance := INF
	for c in candidates:
		var d := point.distance_to(c.global_position)
		if d < best_distance:
			best = c
			best_distance = d
	return best


func _party_center() -> Vector3:
	var sum := Vector3.ZERO
	for member in party:
		sum += member.global_position
	return sum / maxf(party.size(), 1)


func _names(list: Array[Combatant]) -> String:
	return ", ".join(list.map(func(c: Combatant) -> String: return c.display_name))
