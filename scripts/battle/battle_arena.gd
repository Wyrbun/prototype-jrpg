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

## How fast icons move along the timeline (times each fighter's speed).
## Lower = more time between turns. Walking, AP recharge and combos aren't affected.
@export var time_scale: float = 1.8
## Overall battle pace between turns: slows the timeline, enemy and ally
## movement, and AP recharge together (1.0 = the original pace, 0.7 = 30%
## slower). The fighter you steer, strike rings and combo timing aren't affected.
@export_range(0.1, 2.0) var battle_speed: float = 0.7
## How long an enemy turn stays on screen after it acts, in seconds.
@export var enemy_turn_seconds: float = 0.8
## Where the casting zone starts on the timeline (the bar is 100 long).
@export_range(0.0, 100.0) var cast_zone_start: float = 73.0
## Where an enemy's prepared skill is revealed. Closer to 100 means less
## time to see it coming.
@export_range(0.0, 100.0) var reveal_at: float = 88.0
## Paired enemies (team_tactics): when one readies a Power Shot (a Smash)
## and its partner a normal attack, the normal attack lands this many seconds
## after the Power Shot, so there's time to hide behind a rock and then run
## back in. Counted in real seconds of free movement.
@export var bait_gap_seconds: float = 2.5

@export_group("AP")
## The most AP the party can hold at the start of the fight. Parries and
## Perfects raise it; missing one resets it back to this.
@export var max_ap: float = 100.0
## Max AP can't grow beyond this much per party member, plus one more
## share (100 x (party size + 1): 200 solo, 500 with four).
@export var max_ap_ceiling_per_member: float = 100.0
## Unavoidable strikes skip the Parry/Defend ring: they land after this
## short beat.
@export var unavoidable_impact_seconds: float = 0.45
## Bonus max AP lost when an enemy strike lands that could have been
## avoided (dodgeable skills, or a mechanic answered wrong); once per strike.
@export var avoidable_hit_max_ap_loss: float = 100.0
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
## Recharge speeds up with max AP (x1.5 at 150...), but never beyond this.
@export var ap_regen_max_multiplier: float = 2.0

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
## AP added when a party member's turn starts, on top of what's there.
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
## While preparing an attack, an enemy tracks the party member it locked onto
## at full turning speed, and only slows to its casting turn speed this many
## seconds before it strikes: that's the window to get out of the way.
@export var cast_slow_seconds: float = 1.0


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
## When an enemy strike catches someone off screen, the camera eases out
## (and over) so everyone hit is in view, up to this distance.
@export var strike_frame_max_distance: float = 34.0


## One enemy skill on its way to landing.
class Strike:
	var enemy: Combatant
	var skill: int
	var def: EnemySkill
	## Per target: {"mult": damage multiplier, "unblockable": bool, "one_hp": bool}.
	var mods := {}
	## Hits still to come after this one (multi-hit skills).
	var hits_left := 0
	var targets: Array[Combatant] = []
	var windup: float = 1.0
	var time_left: float = 1.0
	var reaction: int = 0  # a Reaction value
	## Send the enemy back to the start of the bar when this resolves
	## (true when it strikes during your turn instead of on its own turn).
	var reset_timeline := false
	var rings: Array[MeshInstance3D] = []
	var markers: Array[MeshInstance3D] = []
	## Multi-hit skills: one fainter ring per hit still to come, each closing
	## in so it reaches the marker exactly when its own hit lands.
	var future_rings: Array[MeshInstance3D] = []
	## Wind-up of each later hit (shorter than the first).
	var follow_windup := 0.55


## The round being played, kept across scene reloads (0-based; -1 = not
## chosen yet, so start_round is used).
static var _round_index := -1
## True when the title screen started the tutorial instead of a round.
static var tutorial_mode := false
## True in a Boss Rush (from the title screen's Boss Rush or Continue), where
## fights can be saved; false for Round Select and the tutorial.
static var boss_rush_mode := false
## True when this Boss Rush was resumed with Continue (for the reports).
static var continued := false
## Boss rounds (from Round 7, index PICK_PARTY_FROM) let the player choose
## the party: the chosen class scenes, and the round they were chosen for.
## Retrying the same round keeps the pick; a new round asks again.
const PICK_PARTY_FROM := 6
static var chosen_party: Array[String] = []
static var chosen_for_round := -1

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
## Lingering hazards (fire trails): {"area", "owner", "turns", "dps", "acc"}.
var _hazards: Array[Dictionary] = []
## Telegraph arrows being animated: {"node", "base", "dir"}.
var _telegraph_arrows: Array[Dictionary] = []
var _telegraph_time := 0.0

## True while picking which enemy a combo will hit (TARGET mode for Attack).
var _choosing_attack_target := false
## The enemy the combo will hit, locked when the combo bar opens.
var _combo_target: Combatant = null
## Party AP just before the combo was paid, so the bar keeps showing it.
var _ap_before_combo := 0.0

# Combo playback (runs in _process while the menu is EXECUTING).
## PARTIAL: the player went for a Hold or Tap timing but didn't nail it
## (early/late release, too few taps): no Perfect, but no penalty either.
enum Timing { NONE, PERFECT, MISS, PARTIAL }
var _exec_attacker: Combatant = null
var _exec_slot := 0
var _exec_time := 0.0
var _exec_hits_done := 0
## Timing result for each hit of the current move.
var _exec_timings: Array[int] = []
## Hold timings: holding Confirm after a good press in the first box.
var _exec_holding := false
## Tap timings: taps counted so far for the current slot's last hit.
var _exec_taps := 0
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
## 0..1: how far the camera has eased into framing a strike's targets.
var _strike_view := 0.0
var _strike_framing := false
var _strike_focus := Vector3.ZERO
var _strike_distance := 12.0
## Seconds left before the active fighter's turn actually begins (the camera
## is panning over to them).
var _turn_intro_left := 0.0
var _flash_message := ""
## This fight's play-test report (not kept for the tutorial).
var playtest: PlaytestLog = null
var _flash_time_left := 0.0

@onready var camera: Camera3D = $Camera3D
@onready var timeline_bar: TimelineBar = $UI/TimelineBar
@onready var turn_label: Label = $UI/TurnLabel
@onready var warning_label: Label = $UI/WarningLabel
@onready var ap_bar: ProgressBar = $UI/APBar
@onready var ap_label: Label = $UI/APBar/APLabel
## The segmented AP meter drawn in code (replaces the plain APBar on screen).
var ap_meter: APMeter = null
## Hit count and damage total on the right while a combo plays.
var combo_counter: ComboCounter = null
## Esc during a fight: Resume / Restart fight / Quit to title.
var pause_menu: PauseMenu = null
## While choosing moves for a combo: the highlighted move's area on the
## floor, and a ring under every enemy it would hit.
var _preview_area: AttackRange = null
var _preview_barrier: AttackRange = null
var _preview_marks: Array[MeshInstance3D] = []
## Who the previewed move would hit (also marked on the timeline).
var _preview_hits: Array[Combatant] = []
## The enemy whose floating name is lit up as the target.
var _named_target: Combatant = null
## While the Assassin is steered: each enemy's positional ring (enemy ->
## PositionalRing): front arrow, violet rear arc, or a full ring for enemies
## without positionals.
var _behind_cones := {}
var _preview_key := ""
@onready var controls_label: Label = $UI/ControlsLabel
@onready var party_status: PartyStatus = $UI/PartyStatus
@onready var enemy_status: PartyStatus = $UI/EnemyStatus
@onready var battle_menu: BattleMenu = $UI/BattleMenu


func _ready() -> void:
	Keybinds.apply_saved()  # the player's own keys (Change Keys on the title screen)
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
	ap_meter = APMeter.new()
	$UI.add_child(ap_meter)
	ap_meter.anchor_left = 0.0
	ap_meter.anchor_right = 1.0
	ap_meter.anchor_top = 1.0
	ap_meter.anchor_bottom = 1.0
	ap_meter.offset_top = -120.0
	ap_meter.offset_bottom = -58.0
	ap_meter.value = ap
	ap_meter.max_value = current_max_ap
	ap_meter.ceiling = max_ap_ceiling()
	ap_bar.visible = false
	combo_counter = ComboCounter.new()
	$UI.add_child(combo_counter)
	pause_menu = PauseMenu.new()
	$UI.add_child(pause_menu)
	pause_menu.restart_requested.connect(func():
		_save_playtest("Left early")
		get_tree().reload_current_scene())
	pause_menu.progress_saved = boss_rush_mode
	if boss_rush_mode:
		SaveGame.save_round(_round_index)  # auto-save: Continue starts this fight over
	pause_menu.quit_requested.connect(func():
		_save_playtest("Left early")
		get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn"))
	# The camera keeps its angle from the scene and backs away along its
	# own view direction (+Z is "behind" a camera in Godot).
	_cam_pitch = -camera.global_rotation_degrees.x
	_cam_start_pitch = _cam_pitch
	_cam_yaw = camera.global_rotation_degrees.y
	_cam_distance = camera_distance
	_cam_focus = _camera_focus()
	_place_camera()
	if _picks_party() and chosen_for_round != _round_index:
		# A new boss round: choose the party first (the fight waits, paused).
		var picker := PartyPicker.new()
		$UI.add_child(picker)
		var ticked: Array = chosen_party.duplicate() if not chosen_party.is_empty() \
				else encounter.party.map(func(scene): return scene.resource_path)
		picker.open(encounter.title, ticked)
		picker.chosen.connect(func(paths: Array[String]):
			chosen_party = paths
			chosen_for_round = _round_index
			get_tree().reload_current_scene())
		picker.back_requested.connect(func():
			get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn"))
		return
	print("%s! Party: %s  vs  Enemies: %s" % [encounter.title, _names(party), _names(enemies)])
	if tutorial_mode:
		for c in combatants:
			c.cannot_fall = true
		tutorial = TutorialDirector.new()
		tutorial.battle = self
		add_child(tutorial)
	else:
		_flash("%s: %s  vs  %s" % [encounter.title, _names(party), _names(enemies)])
		if encounter.tip != "":
			_flash(encounter.tip, 9.0)
		playtest = PlaytestLog.new(encounter.title, party, enemies)
		if boss_rush_mode:
			playtest.mode = "Boss Rush (continued from a save)" if continued else "Boss Rush"
		else:
			playtest.mode = "Round Select"


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
	var party_scenes: Array[PackedScene] = encounter.party
	if _picks_party() and chosen_for_round == _round_index and not chosen_party.is_empty():
		party_scenes = []
		for path in chosen_party:
			party_scenes.append(load(path))
	party = _spawn(party_scenes, $Party, false)
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


## True for rounds where the player chooses the party (boss rounds).
func _picks_party() -> bool:
	return not tutorial_mode and _round_index >= PICK_PARTY_FROM


## Starts a round (0-based) or the tutorial. Used by the title screen.
static func start(tree: SceneTree, round_index: int, tutorial: bool, boss_rush: bool = false,
		from_save: bool = false) -> void:
	_round_index = round_index
	tutorial_mode = tutorial
	boss_rush_mode = boss_rush and not tutorial
	continued = from_save and boss_rush_mode
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
	_save_playtest("Left early")
	continued = false  # later rounds are plain Boss Rush again
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
			_tick_hazards(world_delta)
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
	_update_cast_areas()
	_update_move_preview()
	_update_timeline_targets()
	_update_behind_cones()
	_animate_telegraphs(delta)
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
		if _game_over:
			get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")  # the fight is over anyway
		else:
			pause_menu.open()  # nothing is lost by accident: quitting is a menu choice
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
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_O \
				and playtest != null:
			get_viewport().set_input_as_handled()
			DirAccess.make_dir_recursive_absolute(PlaytestLog.FOLDER)
			OS.shell_open(ProjectSettings.globalize_path(PlaytestLog.FOLDER))
			return
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
		c.timeline_pos += c.speed * time_scale * seconds * _cast_speed(c)

		if c.team == Combatant.Team.ENEMY:
			if before < cast_zone_start and c.timeline_pos >= cast_zone_start:
				_begin_cast(c)
			_tick_bait(c, seconds)
			if c.loaded_skill != Skills.NONE and not c.skill_revealed and c.timeline_pos >= reveal_at and not _bait_waiting(c):
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
	if playtest:
		playtest.turn(fighter)
	# Effects cast by this fighter count down one of their turns.
	var ended: PackedStringArray = []
	for c in combatants:
		for status_name in c.tick_statuses(fighter):
			ended.append("%s's %s" % [c.display_name, String(status_name).replace("_", " ")])
	if not ended.is_empty():
		_flash("Wore off: " + ", ".join(ended))
	for hazard in _hazards.duplicate():
		if hazard["owner"] == fighter:
			hazard["turns"] = int(hazard["turns"]) - 1
			if hazard["turns"] <= 0:
				_remove_hazard(hazard)

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
		var before := ap
		ap = minf(ap + turn_start_ap, current_max_ap)
		if ap_meter:
			ap_meter.gain(ap - before)
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
	if _choosing_attack_target:
		_choosing_attack_target = false
		_clear_target_marker()
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
	if fighter.has_meta("follow_up_at"):
		# A follow-up (Sword Spin) waits near the end of the bar instead.
		fighter.timeline_pos = fighter.get_meta("follow_up_at")
		fighter.remove_meta("follow_up_at")
		return
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
		# Preparing a skill: stand still and track the party member it locked
		# onto at full speed, slowing down only near the end of the cast.
		# A stance held after its turn just turns slowly.
		var locked := target
		if enemy.cast_target != null and not enemy.cast_target.is_down and not enemy.statuses.has("taunt"):
			locked = enemy.cast_target
		var to_locked := locked.global_position - enemy.global_position
		var turn_speed := enemy.cast_turn_speed_degrees
		if enemy.loaded_skill != Skills.NONE and _seconds_until_turn(enemy) > cast_slow_seconds:
			turn_speed = enemy.turn_speed_degrees
		if enemy.loaded_def != null and enemy.loaded_def.aims_exactly() and enemy.loaded_skill != Skills.NONE:
			enemy.face_toward(to_locked, 1.0, 1000000.0)  # locked on exactly (Breath)
		elif not enemy.get_meta("aim_locked", false):  # snapped skills hold their aim
			enemy.face_toward(to_locked, delta, turn_speed)
		return
	var stop_distance := enemy.body_radius + target.body_radius + enemy.preferred_gap
	var wants_closer := to_target.length() > stop_distance or not _can_see(enemy, target)
	# Walk around rocks and pits on the way.
	var heading := arena.steer(enemy.global_position, to_target, enemy.body_radius) if wants_closer else to_target
	# Partners (team_tactics) fan out so the party can't stand safe from both.
	var spread := _tactics_spread(enemy)
	if spread != Vector3.ZERO:
		heading = (heading.normalized() * (1.0 if wants_closer else 0.0) + spread * 1.5)
		wants_closer = true
	enemy.face_toward(heading, delta)
	var facing_target := enemy.flat_forward().angle_to(heading) < deg_to_rad(45.0)
	if wants_closer and facing_target:
		enemy.global_position += enemy.flat_forward() * enemy.move_speed * delta
		_keep_in_arena(enemy)


## Slow casts (Shadowflare, Breath) and fast bosses (cast_zone_speed) move
## through the casting zone at a share of the enemy's speed.
func _cast_speed(fighter: Combatant) -> float:
	var bait := _bait_speed(fighter)
	if bait >= 0.0:
		return bait
	if fighter.loaded_def != null and fighter.loaded_skill != Skills.NONE and fighter.timeline_pos >= cast_zone_start:
		return fighter.loaded_def.cast_speed * fighter.cast_zone_speed
	return 1.0


## Real seconds until a fighter reaches the end of the timeline.
func _seconds_until_turn(fighter: Combatant) -> float:
	var rate := fighter.speed * time_scale * battle_speed * _cast_speed(fighter)
	return maxf(TIMELINE_LENGTH - fighter.timeline_pos, 0.0) / rate if rate > 0.0 else INF


## Who an enemy goes after: whoever taunted it, otherwise the nearest.
func _enemy_target(enemy: Combatant) -> Combatant:
	if enemy.statuses.has("taunt"):
		var taunter: Combatant = enemy.statuses["taunt"]["caster"]
		if taunter != null and not taunter.is_down:
			return taunter
	# Vanish: enemies lose track of a hidden Assassin while anyone else stands.
	var seen := _standing(party).filter(func(m): return not m.statuses.has("vanish"))
	return _nearest(enemy, seen if not seen.is_empty() else _standing(party))


## Ally AI, in priority order:
##   1. Stack up: for a revealed shared-damage skill (Breath), gather on the
##      party member it's aimed at, so the damage is split.
##   2. Stay out of danger: leave any enemy area that could hit, never walk
##      into one. A circle or line that follows this ally while hidden can't
##      be outrun, so it's ignored until revealed; circles that punish
##      overlaps keep allies a full circle apart (spread out).
##   3. Stand near the edge of its own attack range from its focus enemy
##      (ally_range_share of its reach): a healer mid-ritual first (close
##      enough to interrupt it), then a growing circle's caster (so it gets
##      contained), otherwise the nearest enemy.
func _ally_step(ally: Combatant, delta: float) -> void:
	var dangers := _ally_dangers(ally)
	var stack_at: Variant = _stack_point(ally)
	if stack_at != null:
		var to_stack: Vector3 = stack_at - ally.global_position
		to_stack.y = 0.0
		if to_stack.length() > ally.body_radius + 0.9:
			_safe_step(ally, to_stack, delta, dangers)
		return

	var away := Vector3.ZERO
	for danger in dangers:
		var area: AttackRange = danger["area"]
		if area.contains(ally.global_position, danger["margin"]):
			var from_area := ally.global_position - area.global_position
			from_area.y = 0.0
			var out := from_area.normalized() if from_area.length() > 0.05 else Vector3.RIGHT
			if area.shape == EnemySkill.Shape.DONUT \
					and from_area.length() - area.inner_radius < area.radius - from_area.length():
				out = -out  # a ring: its safe middle is closer than its outer edge
			away += out
	if away != Vector3.ZERO:
		ally.step(away, delta)
		_keep_in_arena(ally)
		return

	var threat := _ally_focus(ally)
	if threat == null:
		return
	var to_threat := threat.global_position - ally.global_position
	if ally.flanks and not threat.no_positionals:
		# Assassin: circle round to the enemy's back, within striking reach.
		var spot := threat.global_position - threat.flat_forward() * (threat.body_radius + ally.body_radius + ally.reach() * 0.6)
		var to_spot := spot - ally.global_position
		to_spot.y = 0.0
		if to_spot.length() > 0.35:
			if to_spot.length() > 1.5 and not threat.is_behind(ally.global_position):
				# Go round the side rather than straight through the front.
				var side := to_threat.cross(Vector3.UP).normalized()
				if side.dot(to_spot) < 0.0:
					side = -side
				to_spot = to_spot.normalized() + side * 0.8
			if _safe_step(ally, to_spot, delta, dangers):
				return
		ally.face_toward(to_threat, delta)
		return
	var gap := ally.gap_to(threat)
	var ideal := ally.reach() * ally_range_share
	var ritual := threat.loaded_def
	if ritual != null and ritual.special == EnemySkill.Special.HEAL_ALLIES:
		ideal = minf(ideal, ritual.interrupt_range * 0.8)  # close enough that hits interrupt it
	if gap > ideal + 0.15:
		if _safe_step(ally, to_threat, delta, dangers):
			return
	elif gap < ideal - 1.0:
		if _safe_step(ally, -to_threat, delta, dangers):
			return
	ally.face_toward(to_threat, delta)


## The areas an AI ally avoids right now, each with how far to keep from it:
## [{"area": AttackRange, "margin": meters}].
func _ally_dangers(ally: Combatant) -> Array[Dictionary]:
	var base := ally.body_radius + ally_danger_margin
	var list: Array[Dictionary] = []
	for enemy in enemies:
		if not _is_danger(enemy):
			continue
		var def := enemy.loaded_def
		if def.special == EnemySkill.Special.HEAL_ALLIES:
			continue  # a healing ritual can't hurt anyone: go and break it instead
		if enemy.skill_revealed and def.shared_damage and _stack_target(enemy) != null:
			continue  # stacking in it is the answer, not running
		for area in _enemy_areas(enemy):
			var margin := base
			if area.has_meta("follow") and (not enemy.skill_revealed or def.keeps_following()):
				if area.get_meta("follow") == ally:
					continue  # it follows this ally: moving can't escape it
				if def.special == EnemySkill.Special.ON_EACH_TARGET and def.overlap != EnemySkill.Overlap.NORMAL:
					margin += area.radius  # keep my own circle from overlapping this one
			list.append({"area": area, "margin": margin})
	for hazard in _hazards:
		list.append({"area": hazard["area"], "margin": base})
	return list


## Where allies gather for a revealed shared-damage skill, or null.
func _stack_point(ally: Combatant) -> Variant:
	for enemy in enemies:
		if enemy.is_down or enemy.loaded_def == null or not enemy.skill_revealed:
			continue
		if not enemy.loaded_def.shared_damage:
			continue
		var target := _stack_target(enemy)
		if target != null and target != ally:
			return target.global_position
		if target == ally:
			return ally.global_position  # the others come to it; it holds still
	return null


## Who the party should stack on for a shared-damage skill: its locked
## target if that one is inside the area, otherwise whoever inside is
## closest to the enemy. Null if nobody is in it (then it's just avoided).
func _stack_target(enemy: Combatant) -> Combatant:
	var area := enemy.attack_range
	if area == null:
		return null
	var target := enemy.cast_target
	if target != null and not target.is_down and area.contains(target.global_position, target.body_radius):
		return target
	var best: Combatant = null
	for member in _standing(party):
		if area.contains(member.global_position, member.body_radius) \
				and (best == null or enemy.gap_to(member) < enemy.gap_to(best)):
			best = member
	return best


## The enemy an ally positions itself around: a healer mid-ritual, then the
## caster of a growing circle not yet contained, otherwise the nearest.
func _ally_focus(ally: Combatant) -> Combatant:
	var standing := _standing(enemies)
	var healers: Array[Combatant] = []
	var growers: Array[Combatant] = []
	for enemy in standing:
		var def := enemy.loaded_def
		if def == null:
			continue
		if def.special == EnemySkill.Special.HEAL_ALLIES:
			healers.append(enemy)
		elif def.special == EnemySkill.Special.GROWING and not enemy.contained:
			growers.append(enemy)
	if not healers.is_empty():
		return _nearest(ally, healers)
	if not growers.is_empty():
		return _nearest(ally, growers)
	return _nearest(ally, standing)


## Takes one step toward a direction, or the closest detour (up to 90° off)
## that doesn't enter a dangerous area. Returns false if every option is unsafe.
func _safe_step(fighter: Combatant, direction: Vector3, delta: float, dangers: Array[Dictionary]) -> bool:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return false
	direction = arena.steer(fighter.global_position, direction.normalized(), fighter.body_radius)
	for degrees in [0.0, 35.0, -35.0, 70.0, -70.0, 90.0, -90.0]:
		var dir := direction.rotated(Vector3.UP, deg_to_rad(degrees))
		var next := fighter.global_position + dir * fighter.current_move_speed() * delta
		var safe := true
		for danger in dangers:
			if (danger["area"] as AttackRange).contains(next, danger["margin"]):
				safe = false
				break
		if safe:
			fighter.step(dir, delta)
			_keep_in_arena(fighter)
			return true
	return false


## An enemy area worth avoiding: a revealed Attack/Smash, or anything still
## being prepared (allies can't know a hidden skill is harmless).
func _is_danger(enemy: Combatant) -> bool:
	if enemy.attack_range == null or enemy.is_down or enemy.loaded_def == null:
		return false
	return not enemy.skill_revealed or enemy.loaded_def.is_offensive()


## Every area an AI ally should stay out of: enemy areas being prepared or
## revealed as offensive, placed circles and lines, and fire trails.
func _danger_areas() -> Array[AttackRange]:
	var areas: Array[AttackRange] = []
	for enemy in enemies:
		if _is_danger(enemy):
			areas.append_array(_enemy_areas(enemy))
	for hazard in _hazards:
		areas.append(hazard["area"])
	return areas


## The areas a prepared skill will hit: the enemy's own area, or the circles
## and lines it placed on the party.
func _enemy_areas(enemy: Combatant) -> Array[AttackRange]:
	var areas: Array[AttackRange] = []
	if enemy.loaded_def != null and enemy.loaded_def.placed_on_party():
		areas.append_array(enemy.extra_areas)
	elif enemy.attack_range != null:
		areas.append(enemy.attack_range)
	return areas


func _loaded_offensive(enemy: Combatant) -> bool:
	return enemy.loaded_def != null and enemy.loaded_def.is_offensive()


## Pushes apart any two fighters standing inside each other.
## Enemies are heavy: party members get pushed, enemies don't.
func _resolve_overlaps() -> void:
	for i in combatants.size():
		for j in range(i + 1, combatants.size()):
			var a := combatants[i]
			var b := combatants[j]
			if a.is_down or b.is_down:
				continue  # knocked-out bodies don't block anyone
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
			elif a == controlled:
				b.global_position += push_dir * overlap  # allies never shove the one you steer
			elif b == controlled:
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
	enemy.loaded_def = _choose_enemy_skill(enemy)
	enemy.loaded_skill = enemy.loaded_def.kind
	var streak: int = enemy.get_meta("repeat_streak", 0)
	enemy.set_meta("repeat_streak", streak + 1 if enemy.loaded_def == enemy.last_skill else 1)
	enemy.last_skill = enemy.loaded_def
	enemy.cast_target = _enemy_target(enemy)  # locked on for the whole cast
	enemy.skill_revealed = false
	enemy.stance_time_left = 0.0
	var kind := enemy.loaded_def.kind
	enemy.stance = kind if kind == Skills.Kind.DEFENSE or kind == Skills.Kind.COUNTER else Skills.NONE
	enemy.cast_damage_taken = 0
	enemy.interrupt_count = 0
	enemy.set_meta("smash_hits", 0)
	enemy.contained = false
	enemy.show_skill_text("...", Color(0.75, 0.75, 0.8))
	# Its area shows up right away, in grey: where it will land, not what it is.
	_build_cast_areas(enemy)
	_link_bait(enemy)
	print("%s is preparing %s (hidden)" % [enemy.display_name, enemy.loaded_def.skill_name])


## Late in the casting zone the prepared skill becomes visible: on the
## bar, above the enemy, and as a live area on the floor.
func _reveal_skill(enemy: Combatant) -> void:
	enemy.skill_revealed = true
	var def := enemy.loaded_def
	var text := def.skill_name.to_upper()
	if def.placed_on_party():
		for area in enemy.extra_areas:
			area.show_skill(def, false, area.radius)  # colored, and locked where it is now
	elif enemy.attack_range:
		enemy.attack_range.show_skill(def, false, _cast_radius(enemy))
	if def.snaps_to_target and enemy.cast_target != null and not enemy.cast_target.is_down:
		# Turns at once to face its target, then holds that aim: step aside!
		enemy.face_toward(enemy.cast_target.global_position - enemy.global_position, 1.0, 1000000.0)
		enemy.set_meta("aim_locked", true)
	if def.kind == Skills.Kind.DEFENSE or def.kind == Skills.Kind.COUNTER:
		text += " STANCE"
	if def.is_mechanic():
		text += "  -  UNAVOIDABLE"
	if def.follow_up != null:
		text += "  >  " + def.follow_up.skill_name.to_upper()
	if enemy.contained:
		text += " (CONTAINED)"
	_add_telegraphs(enemy)
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
	if playtest:
		playtest.cast(enemy, skill_name)
	if enemy.loaded_def.special == EnemySkill.Special.HEAL_ALLIES:
		_heal_allies(enemy)
		_finish_enemy_skill(enemy, reset_timeline)
		return
	if enemy.loaded_def.push_out:
		_push_out(enemy, reset_timeline)
		return
	if enemy.loaded_def.is_offensive():
		if enemy.loaded_def.aims_exactly() and enemy.cast_target != null and not enemy.cast_target.is_down:
			enemy.face_toward(enemy.cast_target.global_position - enemy.global_position, 1.0, 1000000.0)
		var mods := _strike_targets(enemy)
		if mods.is_empty():
			_count("misses")
			if playtest:
				playtest.miss(enemy, skill_name)
			_flash("%s's %s misses!" % [enemy.display_name, skill_name])
			_leave_hazards(enemy)
			_finish_enemy_skill(enemy, reset_timeline)
		else:
			_begin_strike(enemy, mods, reset_timeline)
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
	_clear_cast_extras(enemy)
	enemy.show_skill_text("")
	enemy.cast_target = null
	enemy.set_meta("aim_locked", false)
	enemy.set_meta("forced_targets", [])
	enemy.set_meta("ap_penalty_done", false)
	enemy.loaded_skill = Skills.NONE
	enemy.skill_revealed = false
	enemy.stance = Skills.NONE
	enemy.stance_time_left = 0.0
	enemy.loaded_def = null
	enemy.remove_meta("bait_for")
	enemy.remove_meta("bait_left")
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
			for area in _enemy_areas(enemy):
				var inside := false
				for member in _standing(party):
					if area.contains(member.global_position, member.body_radius) \
							and (enemy.loaded_def.placed_on_party() or _can_see(enemy, member)):
						inside = true
						if not targets.has(member.display_name):
							targets.append(member.display_name)
				area.set_alert(inside)
		else:
			enemy.attack_range.set_alert(false)
		if targets.is_empty():
			continue
		# Strikes always land when the enemy's icon reaches the end of the bar;
		# until then the area just glows and warns who's standing in it.
		var skill_name := enemy.loaded_def.skill_name
		if enemy.loaded_def.is_mechanic():
			skill_name += " (unavoidable)"
		var verb := "will push back" if enemy.loaded_def.push_out else "will hit"
		warnings.append("%s's %s %s: %s" % [enemy.display_name, skill_name, verb, ", ".join(targets)])
	warning_label.text = "\n".join(warnings)


## True if a point is inside any enemy's live Attack/Smash area.
func _in_any_attack_range(point: Vector3, extra_radius: float) -> bool:
	for enemy in enemies:
		if _is_live_threat(enemy):
			for area in _enemy_areas(enemy):
				if area.contains(point, extra_radius):
					return true
	return false


## An enemy whose revealed Attack or Smash area can hurt you right now.
func _is_live_threat(enemy: Combatant) -> bool:
	return enemy.attack_range != null and enemy.skill_revealed and _loaded_offensive(enemy)


# --- Special enemy skills ----------------------------------------------------

## Shows a new cast's area(s) in grey: the enemy's own area, or one circle /
## line per party member for skills placed on the party.
func _build_cast_areas(enemy: Combatant) -> void:
	_clear_cast_extras(enemy)
	var def := enemy.loaded_def
	if def.placed_on_party():
		var marked: Array[Combatant] = []
		if def.special == EnemySkill.Special.ON_MARKED:
			if enemy.cast_target != null:
				marked.append(enemy.cast_target)
		else:
			marked = _standing(party)
		for member in marked:
			var area := AttackRange.new()
			add_child(area)
			area.set_meta("follow", member)
			enemy.extra_areas.append(area)
		_place_party_areas(enemy, true)
	elif enemy.attack_range:
		enemy.attack_range.show_skill(def, true, _cast_radius(enemy))


## Moves placed areas onto their party members (circles) or aims them at
## them (lines). Only while the skill is still hidden; once revealed they stay.
func _place_party_areas(enemy: Combatant, hidden: bool) -> void:
	var def := enemy.loaded_def
	for area in enemy.extra_areas:
		var member: Combatant = area.get_meta("follow")
		if member == null or not is_instance_valid(member):
			continue
		if def.special == EnemySkill.Special.ON_EACH_TARGET or def.special == EnemySkill.Special.ON_MARKED:
			area.global_position = Vector3(member.global_position.x, 0.03, member.global_position.z)
			area.show_skill(def, hidden)
		else:
			var from := Vector3(enemy.global_position.x, 0.03, enemy.global_position.z)
			var to := Vector3(member.global_position.x, 0.03, member.global_position.z)
			area.global_position = from
			if from.distance_to(to) > 0.05:
				area.look_at(to, Vector3.UP)
			area.show_skill(def, hidden, from.distance_to(to) + 1.0)


## How big the prepared skill's own area is right now (growing circles
## grow over the cast, unless contained).
func _cast_radius(enemy: Combatant) -> float:
	var def := enemy.loaded_def
	if def == null or def.special != EnemySkill.Special.GROWING:
		return -1.0
	if enemy.contained:
		return enemy.get_meta("contained_radius", def.radius)
	var progress := clampf((enemy.timeline_pos - cast_zone_start) / (TIMELINE_LENGTH - cast_zone_start), 0.0, 1.0)
	return lerpf(def.radius, def.max_radius, progress)


## Every frame: placed areas follow the party until revealed, and growing
## circles grow (or get contained by damage dealt to the caster).
func _update_cast_areas() -> void:
	for enemy in enemies:
		var def := enemy.loaded_def
		if def == null or enemy.is_down:
			continue
		if def.placed_on_party() and (not enemy.skill_revealed or def.keeps_following()):
			_place_party_areas(enemy, not enemy.skill_revealed)  # unavoidable ones follow to the end
		elif def.special == EnemySkill.Special.GROWING:
			if not enemy.contained and enemy.cast_damage_taken >= ceili(enemy.max_hp * def.contain_share):
				enemy.set_meta("contained_radius", _cast_radius(enemy))
				enemy.contained = true
				_count("contained")
				_popup(enemy, "CONTAINED", Color(0.6, 0.9, 1.0))
				_flash("%s's %s is contained: it stops growing" % [enemy.display_name, def.skill_name])
				if enemy.skill_revealed:
					enemy.show_skill_text(def.skill_name.to_upper() + " (CONTAINED)", def.color())
			var radius := _cast_radius(enemy)
			if enemy.attack_range and absf(enemy.attack_range.radius - radius) > 0.05:
				enemy.attack_range.show_skill(def, not enemy.skill_revealed, radius)


func _clear_cast_extras(enemy: Combatant) -> void:
	for area in enemy.extra_areas:
		if is_instance_valid(area):
			area.queue_free()
	enemy.extra_areas.clear()
	_clear_telegraphs(enemy)


## Who a prepared skill hits, and how: {party member: {"mult", "unblockable", "one_hp"}}.
## preview: just looking (the warning pulse), so nothing is counted.
func _strike_targets(enemy: Combatant, preview: bool = false) -> Dictionary:
	var def := enemy.loaded_def
	var result := {}
	if def.placed_on_party():
		for member in _standing(party):
			var count := 0
			for area in enemy.extra_areas:
				if not area.contains(member.global_position, member.body_radius):
					continue
				if def.special == EnemySkill.Special.LINE_TO_EACH and not _can_see(enemy, member):
					continue  # a rock blocks the line
				count += 1
			if def.always_hits and count == 0:
				for area in enemy.extra_areas:
					if area.get_meta("follow", null) == member:
						if def.special == EnemySkill.Special.LINE_TO_EACH and not _can_see(enemy, member):
							continue  # hiding behind a rock still blocks a line
						count = 1  # its own circle / line finds it wherever it stands
			if count == 0:
				continue
			var mod := {"mult": 1.0, "unblockable": false, "one_hp": false}
			if count >= 2:
				if def.overlap == EnemySkill.Overlap.DOUBLE:
					mod["mult"] = 2.0
				elif def.overlap == EnemySkill.Overlap.ONE_HP:
					mod["one_hp"] = true
				if def.overlap_unblockable:
					mod["unblockable"] = true
			result[member] = mod
	else:
		var shielded := false
		for member in _standing(party):
			if enemy.attack_range and enemy.attack_range.contains(member.global_position, member.body_radius):
				if _can_see(enemy, member):
					result[member] = {"mult": 1.0, "unblockable": false, "one_hp": false}
				else:
					shielded = true  # in the area, but a rock was in the way
		if shielded and not preview:
			_count("rock_saves")
		if def.hits_everyone:
			# The whole party is caught; damage depends on how big it grew.
			var size_share := clampf(_cast_radius(enemy) / maxf(def.max_radius, 0.1), 0.25, 1.0) \
					if def.special == EnemySkill.Special.GROWING else 1.0
			result = {}
			for member in _standing(party):
				result[member] = {"mult": size_share, "unblockable": false, "one_hp": false}
		var locked := enemy.cast_target
		if def.always_hits_target and locked != null and not locked.is_down and not result.has(locked) \
				and _can_see(enemy, locked):
			result[locked] = {"mult": 1.0, "unblockable": false, "one_hp": false}  # it never loses its target
		if def.stops_at_first_hit and result.size() > 1:
			# Only the first one in the way is hit; they shield the rest.
			var first: Combatant = null
			for member in result:
				if first == null or enemy.gap_to(member) < enemy.gap_to(first):
					first = member
			result = {first: result[first]}
	for member in enemy.get_meta("forced_targets", []):
		if is_instance_valid(member) and not member.is_down and not result.has(member):
			result[member] = {"mult": 1.0, "unblockable": false, "one_hp": false}  # caught by Shout
	if def.shared_damage and result.size() > 1:
		# Stacking up spreads the damage: 100%, 67%, 50%, 40%...
		var share := 1.0 / (1.0 + 0.5 * (result.size() - 1))
		for mod in result.values():
			mod["mult"] = float(mod["mult"]) * share
	return result


## Healing Ritual: every enemy within the circle (the caster too) heals.
func _heal_allies(caster: Combatant) -> void:
	var def := caster.loaded_def
	var healed: PackedStringArray = []
	for ally in _standing(enemies):
		var distance := ally.global_position.distance_to(caster.global_position) - ally.body_radius
		if ally == caster or distance <= def.radius:
			var amount := ally.heal(ceili(ally.max_hp * def.heal_share))
			if amount > 0:
				_popup(ally, "+%d" % amount, Color(0.45, 0.95, 0.5))
				healed.append("%s +%d" % [ally.display_name, amount])
	if healed.is_empty():
		_flash("%s's %s: nobody needed healing" % [caster.display_name, def.skill_name])
	else:
		_flash("%s's %s heals: %s" % [caster.display_name, def.skill_name, ", ".join(healed)])


## Fire Wave / Burning Spike: the skill's area keeps burning for a few of
## the caster's turns (each placed circle burns on its own).
func _spawn_trail(enemy: Combatant) -> void:
	var def := enemy.loaded_def
	var sources: Array[AttackRange] = []
	if def.placed_on_party():
		for placed in enemy.extra_areas:
			if is_instance_valid(placed):
				sources.append(placed)
	elif enemy.attack_range != null:
		sources.append(enemy.attack_range)
	for source in sources:
		var area := AttackRange.new()
		add_child(area)
		area.global_transform = source.global_transform
		area.show_hazard(def, Color(1.0, 0.45, 0.1))
		_hazards.append({"area": area, "owner": enemy, "turns": def.trail_turns,
				"dps": def.trail_damage_per_second, "acc": {}, "name": def.skill_name})
	if not sources.is_empty():
		_flash("The ground keeps burning!")


## Rock Spikes: spikes rise inside the skill's circle and hurt anyone who
## walks into one, for a few of the caster's turns.
func _spawn_spikes(enemy: Combatant) -> void:
	var def := enemy.loaded_def
	var center := enemy.global_position
	if not enemy.extra_areas.is_empty() and is_instance_valid(enemy.extra_areas[0]):
		center = enemy.extra_areas[0].global_position
	var spike_def := EnemySkill.make(def.skill_name, Skills.Kind.SPECIAL, EnemySkill.Shape.CIRCLE, 0.5, 360.0, 0, 0.0, 0)
	var turn := randf() * TAU
	for i in def.spikes:
		var a := turn + TAU * i / def.spikes
		var spot := center + Vector3(sin(a), 0.0, cos(a)) * def.radius * 0.55
		spot.y = 0.04
		var area := AttackRange.new()
		add_child(area)
		area.global_position = spot
		area.show_hazard(spike_def, Color(0.75, 0.6, 0.45))
		var spike := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 0.32
		mesh.height = 1.0
		spike.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.5, 0.45, 0.4)
		spike.material_override = material
		area.add_child(spike)
		spike.position = Vector3(0, 0.5, 0)
		# Whoever is already standing there isn't hurt until they walk back in.
		var inside := {}
		for member in _standing(party):
			inside[member] = area.contains(member.global_position, member.body_radius * 0.6)
		_hazards.append({"area": area, "owner": enemy, "turns": def.trail_turns, "dps": 0.0, "acc": {},
				"name": def.skill_name, "touch": def.spike_damage, "inside": inside})
	_flash("Rock spikes burst from the ground!")


## Fire trails and spikes stay behind whether the skill hit anyone or not.
func _leave_hazards(enemy: Combatant) -> void:
	var def := enemy.loaded_def
	if def == null:
		return
	if def.spikes > 0:
		_spawn_spikes(enemy)
	elif def.trail_turns > 0:
		_spawn_trail(enemy)


## Shout: everyone inside is pushed out past the edge, then the follow-up
## (Sword Spin) comes at once and hits everyone who was pushed, wherever
## they landed, plus anyone else standing in its own area.
func _push_out(enemy: Combatant, reset_timeline: bool) -> void:
	var def := enemy.loaded_def
	var caught: Array[Combatant] = []
	for member in _standing(party):
		if enemy.attack_range and enemy.attack_range.contains(member.global_position, member.body_radius):
			caught.append(member)
	for member in caught:
		var offset := member.global_position - enemy.global_position
		offset.y = 0.0
		var needed := def.radius + member.body_radius + 0.4 - offset.length()
		if needed > 0.0:
			_knock_away(member, enemy.global_position, needed)
		_popup(member, "PUSHED", Color(1.0, 0.6, 0.3))
	if caught.is_empty():
		_flash("%s's %s: nobody was close" % [enemy.display_name, def.skill_name])
	else:
		_flash("%s's %s pushes back %s!" % [enemy.display_name, def.skill_name, _names(caught)])
	var next := def.follow_up
	if next == null or enemy.attack_range == null:
		_finish_enemy_skill(enemy, reset_timeline)
		return
	# The follow-up is revealed now and strikes follow_up_delay seconds later:
	# whoever was pushed is marked and will be hit wherever they go; anyone
	# else has that long to get out (into Sword Spin's safe middle).
	_clear_telegraphs(enemy)
	enemy.loaded_def = next
	enemy.loaded_skill = next.kind
	enemy.skill_revealed = true
	enemy.last_skill = def
	enemy.attack_range.show_skill(next)
	enemy.show_skill_text(next.skill_name.to_upper(), next.color())
	var marked: Array = []
	for member in caught:
		if not member.is_down:
			marked.append(member)
	enemy.set_meta("forced_targets", marked)
	_mark_forced(enemy, marked)
	var rate := enemy.speed * time_scale * battle_speed
	# (never back before the casting zone, or it would start a new cast)
	enemy.set_meta("follow_up_at", maxf(TIMELINE_LENGTH - def.follow_up_delay * rate, cast_zone_start + 0.01))
	if reset_timeline:
		_send_to_start(enemy)  # on its own turn, _end_turn does this


## Orange spheres over everyone a follow-up will hit no matter what.
func _mark_forced(enemy: Combatant, marked: Array) -> void:
	var nodes: Array[Node3D] = []
	for member in marked:
		var sphere := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.2
		mesh.height = 0.4
		sphere.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.6, 0.1)
		sphere.material_override = material
		member.add_child(sphere)
		sphere.position = Vector3(0, 2.85, 0)
		sphere.set_meta("bob", true)
		nodes.append(sphere)
	enemy.set_meta("telegraphs", nodes)


## Anyone standing in a fire trail keeps losing HP (in small chunks);
## anyone walking into a spike takes its damage once per step in.
func _tick_hazards(world_delta: float) -> void:
	for hazard in _hazards:
		var area: AttackRange = hazard["area"]
		var acc: Dictionary = hazard["acc"]
		if hazard.has("touch"):
			var inside: Dictionary = hazard["inside"]
			for member in _standing(party):
				var now := area.contains(member.global_position, member.body_radius * 0.6)
				if now and not inside.get(member, false):
					var taken := _hurt(member, int(hazard["touch"]), false, "Rock spike")
					_popup(member, str(taken), Color(0.85, 0.7, 0.5))
					_flash("%s walks into a rock spike!" % member.display_name)
					if member.is_down:
						_check_party()
				inside[member] = now
			continue
		for member in _standing(party):
			if not area.contains(member.global_position, member.body_radius * 0.5):
				continue
			acc[member] = float(acc.get(member, 0.0)) + float(hazard["dps"]) * world_delta
			if acc[member] >= 4.0:
				var chunk := floori(acc[member])
				acc[member] -= chunk
				var taken := _hurt(member, chunk, false, "%s fire" % hazard["name"])
				_popup(member, str(taken), Color(1.0, 0.55, 0.2))
				if member.is_down:
					_flash("%s burns down in the fire!" % member.display_name)
					_check_party()


func _remove_hazard(hazard: Dictionary) -> void:
	var area: AttackRange = hazard["area"]
	if is_instance_valid(area):
		area.queue_free()
	_hazards.erase(hazard)


# --- Telegraphs -------------------------------------------------------------

## Revealed skills that need a specific answer say so on the field:
## - spread out (circles or lines placed on everyone): a red sphere bobs
##   above each party member's head;
## - stack up (damage shared between those hit): arrows around the area's
##   edge point inward.
func _add_telegraphs(enemy: Combatant) -> void:
	_clear_telegraphs(enemy)
	var def := enemy.loaded_def
	var nodes: Array[Node3D] = []
	var marked: Array[Combatant] = []
	if def.special == EnemySkill.Special.ON_MARKED:
		if enemy.cast_target != null and not enemy.cast_target.is_down:
			marked.append(enemy.cast_target)  # keep away from the marked one
	elif def.placed_on_party() and def.overlap != EnemySkill.Overlap.NORMAL:
		marked = _standing(party)
	if not marked.is_empty():
		for member in marked:
			var sphere := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.2
			mesh.height = 0.4
			sphere.mesh = mesh
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color(1.0, 0.15, 0.1)
			sphere.material_override = material
			member.add_child(sphere)
			sphere.position = Vector3(0, 2.85, 0)
			sphere.set_meta("bob", true)
			nodes.append(sphere)
	elif def.shared_damage and enemy.attack_range:
		var area := enemy.attack_range
		var count := 7
		var half := deg_to_rad(area.angle_degrees) / 2.0
		var center := Vector3(0, 0.06, -area.radius * 0.45) if area.angle_degrees < 360.0 else Vector3(0, 0.06, 0)
		for i in count:
			var t := (i + 0.5) / count
			var a := -half + 2.0 * half * t if area.angle_degrees < 360.0 else TAU * t
			var edge := Vector3(sin(a), 0.0, -cos(a)) * area.radius * 0.95
			edge.y = 0.06
			var inward := (center - edge)
			inward.y = 0.0
			inward = inward.normalized()
			var arrow := _make_arrow()
			area.add_child(arrow)
			arrow.position = edge
			arrow.look_at(area.to_global(edge + inward), Vector3.UP)
			_telegraph_arrows.append({"node": arrow, "base": edge, "dir": inward})
			nodes.append(arrow)
	enemy.set_meta("telegraphs", nodes)


func _clear_telegraphs(enemy: Combatant) -> void:
	for node in enemy.get_meta("telegraphs", []):
		if is_instance_valid(node):
			for entry in _telegraph_arrows.duplicate():
				if entry["node"] == node:
					_telegraph_arrows.erase(entry)
			node.queue_free()
	enemy.set_meta("telegraphs", [])


## A flat gold chevron pointing forward (-Z), lying on the floor.
func _make_arrow() -> MeshInstance3D:
	var v := PackedVector3Array([
		Vector3(0, 0, -0.45), Vector3(0.38, 0, 0.1), Vector3(0.18, 0, 0.1),
		Vector3(0, 0, -0.45), Vector3(0.18, 0, 0.1), Vector3(0, 0, -0.15),
		Vector3(0, 0, -0.45), Vector3(-0.18, 0, 0.1), Vector3(-0.38, 0, 0.1),
		Vector3(0, 0, -0.45), Vector3(0, 0, -0.15), Vector3(-0.18, 0, 0.1),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 0.9, 0.4, 0.9)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Arrows slide inward and fade, over and over; spheres bob up and down.
func _animate_telegraphs(delta: float) -> void:
	_telegraph_time += delta
	var cycle := fmod(_telegraph_time * 1.3, 1.0)
	for entry in _telegraph_arrows:
		var arrow: MeshInstance3D = entry["node"]
		if not is_instance_valid(arrow):
			continue
		arrow.position = entry["base"] + (entry["dir"] as Vector3) * cycle * 0.9
		(arrow.material_override as StandardMaterial3D).albedo_color.a = 0.95 * (1.0 - cycle * 0.8)
	for enemy in enemies:
		for node in enemy.get_meta("telegraphs", []):
			if is_instance_valid(node) and node.has_meta("bob"):
				node.position.y = 2.85 + sin(_telegraph_time * 5.0) * 0.08


# --- Enemy skill choice -----------------------------------------------------

## Picks the skill to prepare. Each skill starts from its weight, then the
## situation adjusts it: skills that can't reach anyone are unlikely, area
## skills placed on the party like a bunched-up party, healing needs hurt
## allies, Defense / Counter like someone standing close, and the skill used
## last time is less likely, so enemies mix their kit up. Partners with
## team_tactics pick something different from each other (see below).
func _choose_enemy_skill(enemy: Combatant) -> EnemySkill:
	if enemy.forced_skill != null:
		return enemy.forced_skill
	var pool: Array[EnemySkill] = enemy.skills if not enemy.skills.is_empty() else Combatant._basic_skills()
	var target := _enemy_target(enemy)
	var members := _standing(party)
	var scores: Array[float] = []
	var total := 0.0
	for skill in pool:
		var score := float(skill.weight)
		match skill.special:
			EnemySkill.Special.HEAL_ALLIES:
				var hurt := 0
				for ally in _standing(enemies):
					if ally.hp < ally.max_hp * 0.75 and ally.global_position.distance_to(enemy.global_position) <= skill.radius + ally.body_radius:
						hurt += 1
				score = 0.0 if hurt == 0 else score * (1.0 + 0.5 * hurt)
			EnemySkill.Special.ON_EACH_TARGET:
				score *= 1.0 + 0.35 * mini(_close_pairs(members, skill.radius * 2.0), 3)
			EnemySkill.Special.LINE_TO_EACH:
				score *= 1.0 + 0.35 * mini(_lined_up_pairs(enemy, members), 3)
			EnemySkill.Special.ON_MARKED:
				# Better when others stand near its target.
				var near := 0
				for member in members:
					if target != null and member != target and member.global_position.distance_to(target.global_position) < skill.radius + member.body_radius:
						near += 1
				score *= 1.0 + 0.5 * mini(near, 3)
			EnemySkill.Special.GROWING:
				pass
			_:
				if skill.kind == Skills.Kind.DEFENSE or skill.kind == Skills.Kind.COUNTER:
					var close := false
					for member in members:
						if enemy.gap_to(member) <= 1.5:
							close = true
					score *= 1.6 if close else 0.5
				elif target != null:
					var reached := 0
					for member in members:
						if _skill_reaches(enemy, skill, member):
							reached += 1
					if not _skill_reaches(enemy, skill, target) and reached == 0:
						score *= 0.05  # can't reach anyone: almost never worth preparing
					elif not skill.shared_damage:
						score *= 1.0 + 0.25 * maxi(reached - 1, 0)
		score *= _tactics_factor(enemy, skill)
		if skill == enemy.last_skill:
			# Repeats get less likely the longer the streak runs.
			score *= pow(0.35, enemy.get_meta("repeat_streak", 1))
		scores.append(score)
		total += score
	if total <= 0.0:
		return pool[randi() % pool.size()]
	var roll := randf() * total
	for i in pool.size():
		roll -= scores[i]
		if roll <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


## Partners: other standing enemies of the same kind with team_tactics.
func _tactics_partners(enemy: Combatant) -> Array[Combatant]:
	var partners: Array[Combatant] = []
	if not enemy.team_tactics:
		return partners
	for ally in _standing(enemies):
		if ally != enemy and ally.team_tactics and ally.scene_file_path == enemy.scene_file_path:
			partners.append(ally)
	return partners


## team_tactics skill choice. Only the first partner in the fight uses
## Defense / Counter (the others almost never do), and never while another
## partner already holds a stance. While a partner prepares a Power Shot, the
## others favour Ranged Attack (safe only right next to the Kobold), so
## running in to dodge it can leave you in the open for the Power Shot unless
## you use a rock. A second Power Shot at the same time is unlikely, and the
## same Ranged Attack a little less likely, so they mix their threats.
func _tactics_factor(enemy: Combatant, skill: EnemySkill) -> float:
	var factor := 1.0
	var stance_skill := skill.kind == Skills.Kind.DEFENSE or skill.kind == Skills.Kind.COUNTER
	var partners := _tactics_partners(enemy)
	if stance_skill and not partners.is_empty() and enemies.find(partners[0]) < enemies.find(enemy):
		factor *= 0.1  # only the first of the partners uses stances
	for partner in partners:
		if partner.stance != Skills.NONE:
			if stance_skill:
				factor *= 0.1
			continue
		if partner.loaded_def == null or partner.loaded_skill == Skills.NONE:
			continue
		if partner.loaded_def == skill or partner.loaded_def.skill_name == skill.skill_name:
			# Two Power Shots at once would be brutal; two Ranged Attacks are fine.
			factor *= 0.25 if skill.kind == Skills.Kind.SMASH else 0.7
		elif not stance_skill and skill.kind != Skills.Kind.SMASH:
			factor *= 1.6  # partner has a Power Shot coming: add the other threat
	# Power Shots never become more common than usual (Round 2 should stay
	# approachable); the pairing comes from the others leaning away from them.
	return factor


## team_tactics timing: a normal attack prepared alongside a partner's Power
## Shot (either one may have been picked first) waits for it. While the Power
## Shot is still coming, the attack stays grey with a "NEXT" tag and its cast
## slows so it lands bait_gap_seconds after the Power Shot; once the Power
## Shot is done, it's revealed and the gap counts down.
func _link_bait(enemy: Combatant) -> void:
	if not enemy.team_tactics or enemy.loaded_def == null:
		return
	for partner in _tactics_partners(enemy):
		if not _still_casting(partner):
			continue
		if _is_bait_skill(enemy.loaded_def) and partner.loaded_def.kind == Skills.Kind.SMASH:
			_make_bait(enemy, partner)
			return
		if enemy.loaded_def.kind == Skills.Kind.SMASH and _is_bait_skill(partner.loaded_def) \
				and not partner.has_meta("bait_for"):
			_make_bait(partner, enemy)
			return


func _is_bait_skill(def: EnemySkill) -> bool:
	return def != null and def.kind == Skills.Kind.ATTACK and not def.is_mechanic()


func _make_bait(waiter: Combatant, shooter: Combatant) -> void:
	waiter.set_meta("bait_for", shooter)
	if waiter.has_meta("bait_left"):
		waiter.remove_meta("bait_left")
	var text := waiter.loaded_def.skill_name.to_upper() + "  -  NEXT"
	waiter.show_skill_text(text, Color(0.75, 0.75, 0.8) if not waiter.skill_revealed else waiter.loaded_def.color())


## Preparing a skill and not yet striking with it.
func _still_casting(enemy) -> bool:
	if not is_instance_valid(enemy) or enemy.is_down or enemy.loaded_def == null or enemy.loaded_skill == Skills.NONE:
		return false
	return not (_strike != null and _strike.enemy == enemy)


## True while a bait's partner still has its Power Shot coming.
func _bait_waiting(enemy: Combatant) -> bool:
	return enemy.has_meta("bait_for") and not enemy.has_meta("bait_left")


## Moves a bait from "waiting for the Power Shot" to "counting down the gap",
## and drops the link once the gap is over.
func _tick_bait(enemy: Combatant, seconds: float) -> void:
	if not enemy.has_meta("bait_for"):
		return
	if enemy.loaded_def == null or enemy.loaded_skill == Skills.NONE:
		enemy.remove_meta("bait_for")
		enemy.remove_meta("bait_left")
		return
	if not enemy.has_meta("bait_left"):
		if _still_casting(enemy.get_meta("bait_for")):
			return
		# The Power Shot is done (or was stopped): now the gap.
		enemy.set_meta("bait_left", bait_gap_seconds * battle_speed)
		if enemy.timeline_pos >= reveal_at and not enemy.skill_revealed:
			_reveal_skill(enemy)
		elif enemy.skill_revealed:
			enemy.show_skill_text(enemy.loaded_def.skill_name.to_upper(), enemy.loaded_def.color())
		return
	enemy.set_meta("bait_left", float(enemy.get_meta("bait_left")) - seconds)


## Cast speed for a bait so it reaches the end of the bar on schedule (never
## faster than it would normally go). -1 when the enemy isn't a bait.
func _bait_speed(enemy: Combatant) -> float:
	if not enemy.has_meta("bait_for") or enemy.loaded_def == null:
		return -1.0
	var normal := 1.0
	if enemy.timeline_pos >= cast_zone_start:
		normal = enemy.loaded_def.cast_speed * enemy.cast_zone_speed
	var left: float  # world seconds until it should reach the end
	if enemy.has_meta("bait_left"):
		left = float(enemy.get_meta("bait_left"))
	else:
		var shooter = enemy.get_meta("bait_for")
		if not _still_casting(shooter):
			return normal
		var shooter_rate: float = shooter.speed * time_scale * _cast_speed(shooter)
		left = maxf(TIMELINE_LENGTH - shooter.timeline_pos, 0.0) / maxf(shooter_rate, 0.001) + bait_gap_seconds * battle_speed
	var units := maxf(TIMELINE_LENGTH - enemy.timeline_pos, 0.0)
	var needed := units / maxf(left, 0.05) / maxf(enemy.speed * time_scale, 0.001)
	return clampf(needed, 0.02, normal)


## team_tactics movement: a push away from partners closer than
## tactics_spread (zero when none are that close).
func _tactics_spread(enemy: Combatant) -> Vector3:
	var push := Vector3.ZERO
	for partner in _tactics_partners(enemy):
		var away := enemy.global_position - partner.global_position
		away.y = 0.0
		var d := away.length()
		if d < enemy.tactics_spread:
			push += (away / maxf(d, 0.01)) * (1.0 - d / enemy.tactics_spread)
	return push


## Roughly whether a skill aimed at this member could reach them (the enemy
## turns toward its target while casting, so only distance matters).
func _skill_reaches(enemy: Combatant, skill: EnemySkill, member: Combatant) -> bool:
	var offset := member.global_position - enemy.global_position
	offset.y = 0.0
	var d := offset.length()
	match skill.shape:
		EnemySkill.Shape.DONUT:
			return d >= skill.inner_radius - member.body_radius and d <= skill.radius + member.body_radius
		EnemySkill.Shape.LINE:
			return d <= skill.radius
	var reach := skill.max_radius if skill.special == EnemySkill.Special.GROWING else skill.radius
	return d <= reach + member.body_radius * 0.5


## Pairs of party members standing within `distance` of each other.
func _close_pairs(members: Array[Combatant], distance: float) -> int:
	var pairs := 0
	for i in members.size():
		for j in range(i + 1, members.size()):
			if members[i].global_position.distance_to(members[j].global_position) < distance:
				pairs += 1
	return pairs


## Pairs of party members in nearly the same direction from the enemy.
func _lined_up_pairs(enemy: Combatant, members: Array[Combatant]) -> int:
	var pairs := 0
	for i in members.size():
		for j in range(i + 1, members.size()):
			var a := members[i].global_position - enemy.global_position
			var b := members[j].global_position - enemy.global_position
			a.y = 0.0
			b.y = 0.0
			if a.length() > 0.1 and b.length() > 0.1 and rad_to_deg(a.angle_to(b)) < 15.0:
				pairs += 1
	return pairs


# --- Strikes, Parry and Defend --------------------------------------------

## mods: who is hit and how (see Strike.mods). windup < 0 uses the skill's.
func _begin_strike(enemy: Combatant, mods: Dictionary, reset_timeline: bool, windup: float = -1.0,
		hits_left: int = -1) -> void:
	var s := Strike.new()
	s.enemy = enemy
	s.skill = enemy.loaded_skill
	s.def = enemy.loaded_def
	s.mods = mods
	var targets: Array[Combatant] = []
	for target in mods:
		targets.append(target)
	s.targets = targets
	s.hits_left = (s.def.hits - 1) if hits_left < 0 else hits_left
	s.windup = s.def.windup if windup < 0.0 else windup
	if s.def.is_mechanic():
		s.windup = minf(s.windup, unavoidable_impact_seconds)  # nothing to react to: a short beat, then it lands
	s.time_left = s.windup
	s.reset_timeline = reset_timeline
	s.follow_windup = s.def.windup * 0.55
	for target in targets:
		if s.def.is_mechanic():
			# Unavoidable: no timing ring to react to, just a red mark on
			# everyone about to be hit.
			var mark := _make_ring(target.body_radius + 0.3, 0.12, Color(1.0, 0.2, 0.15, 0.85))
			target.add_child(mark)
			s.markers.append(mark)
			continue
		# A fixed white marker shows where the ring will land; the ring
		# shrinks onto it and turns gold when it's time to parry.
		var ring_radius := target.body_radius + 0.3
		var marker := _make_ring(ring_radius, 0.06, Color(1, 1, 1, 0.7))
		var ring := _make_ring(ring_radius, 0.1, Color.WHITE)
		target.add_child(marker)
		target.add_child(ring)
		s.markers.append(marker)
		s.rings.append(ring)
		for k in range(1, s.hits_left + 1):
			var later := _make_ring(ring_radius, 0.07, Color(1, 1, 1, 0.45))
			later.set_meta("hit", k)
			later.visible = false
			target.add_child(later)
			s.future_rings.append(later)
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
	# Later hits: each ring shrinks at the speed of its own wind-up, so it
	# lands on the marker exactly when that hit does (rings appear from the
	# outside as they get close).
	for ring in _strike.future_rings:
		var k: int = ring.get_meta("hit")
		var time_to_hit := maxf(_strike.time_left, 0.0) + k * _strike.follow_windup
		var scale_factor := 1.0 + 2.0 * time_to_hit / _strike.follow_windup
		ring.visible = scale_factor <= 5.5
		ring.scale = Vector3(scale_factor, 1.0, scale_factor)
		var later_color := Color(0.35, 0.65, 1.0) if _strike.reaction == Reaction.DEFEND else Color.WHITE
		later_color.a = 0.5 if k == 1 else 0.3
		(ring.material_override as StandardMaterial3D).albedo_color = later_color
	if _strike.time_left <= 0.0:
		_resolve_strike()


## E: a Parry. Only one try per strike.
func _try_parry() -> void:
	if _strike.reaction != Reaction.NONE or _strike.def.is_mechanic():
		return  # unavoidable hits don't ask for a reaction
	if not _strike.def.parryable():
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
	if _strike.reaction != Reaction.NONE or _strike.def.is_mechanic():
		return
	if not _strike.def.blockable():
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
	for node in s.rings + s.markers + s.future_rings:
		node.queue_free()

	var skill_name := s.def.skill_name
	var base_damage := s.def.damage
	var lines: PackedStringArray = []
	var parried := false
	var parry_missed := false
	var final_hit := s.hits_left <= 0
	var thrown: Array[Combatant] = []
	var avoidable: Array[Combatant] = []  # took a hit they could have avoided
	if s.def.hits > 1:
		lines.append("%s %d/%d" % [skill_name, s.def.hits - s.hits_left, s.def.hits])

	# One Parry/Defend input covers everyone hit, but only those whose class
	# can parry/block get the benefit; the rest take the full hit.
	for target in s.targets:
		var mod: Dictionary = s.mods.get(target, {})
		var damage := ceili(base_damage * float(mod.get("mult", 1.0)))
		var one_hp: bool = mod.get("one_hp", false)
		if target.riposte_left > 0.0 and s.def.parryable():
			_riposte(target, s.enemy, lines)
			continue
		if target.auto_parry_with_marks and s.def.parryable() and _marks_out() > 0:
			# Assassin: a Mark is spent and the strike is parried for it.
			_spend_mark(s.enemy)
			parried = true
			_count("auto_parries")
			if playtest:
				playtest.parried(s.enemy, skill_name)
			_popup(target, "AUTO-PARRY!", Color(0.78, 0.45, 1.0))
			lines.append("%s auto-parries %s's %s (a Mark is spent)" % [target.display_name, s.enemy.display_name, skill_name])
			continue
		var can_parry := target.can_parry and s.def.parryable()
		var can_block: bool = target.can_block and s.def.blockable() and not mod.get("unblockable", false)
		if s.reaction == Reaction.PARRY and can_parry:
			parried = true
			if playtest:
				playtest.parried(s.enemy, skill_name)
			_popup(target, "PARRY!", Color(1.0, 0.85, 0.2))
			lines.append("%s parried %s's %s!" % [target.display_name, s.enemy.display_name, skill_name])
			continue
		if one_hp:
			# Caught where the circles overlap: down to 1 HP (Arcane Barrier still saves).
			if target.statuses.has("arcane_barrier"):
				target.statuses.erase("arcane_barrier")
				lines.append("%s's barrier absorbs it" % target.display_name)
			else:
				target.recoverable = 0
				if playtest and target.hp > 1:
					playtest.hurt(target, target.hp - 1, "%s: %s" % [s.enemy.display_name, skill_name], s.enemy, skill_name)
				target.hp = mini(target.hp, 1)
				if _avoidable_hit(s.enemy, s.def, s.mods, target, s.targets):
					avoidable.append(target)
				_popup(target, "1 HP!", Color(1.0, 0.3, 0.2))
				lines.append("%s is caught in the overlap: down to 1 HP!" % target.display_name)
		elif s.reaction == Reaction.DEFEND and can_block:
			_count("defends")
			var share := defend_share_vs_smash if s.skill == Skills.Kind.SMASH else defend_share_vs_attack
			var taken := _hurt(target, ceili(damage * share), true, "%s: %s" % [s.enemy.display_name, skill_name], s.enemy, skill_name)
			if playtest:
				playtest.defended(s.enemy, skill_name)
			_popup(target, str(taken), Color(0.6, 0.8, 1.0))
			var guard_note := " Guard broken!" if s.skill == Skills.Kind.SMASH else ""
			lines.append("%s defended:%s -%d HP (recoverable)" % [target.display_name, guard_note, taken])
		else:
			var taken := _hurt(target, damage, false, "%s: %s" % [s.enemy.display_name, skill_name], s.enemy, skill_name)
			_popup(target, str(taken), Color(1.0, 0.4, 0.3))
			if _avoidable_hit(s.enemy, s.def, s.mods, target, s.targets):
				avoidable.append(target)
			if s.reaction == Reaction.PARRY_MISSED and can_parry:
				parry_missed = true
				_count("parries_too_early")
				_push_back(target, parry_miss_push)
			var extra := ""
			if float(mod.get("mult", 1.0)) > 1.0:
				extra = " (overlap: double damage)"
			elif float(mod.get("mult", 1.0)) < 1.0:
				extra = " (shared)"
			lines.append("%s's %s hits %s for %d!%s%s" % [s.enemy.display_name, skill_name, target.display_name, taken,
					extra, _absorb_note(damage, taken)])
		if final_hit and s.def.launch > 0.0 and not target.is_down:
			thrown.append(target)

	for target in thrown:
		_knock_away(target, s.enemy.global_position, s.def.launch)
		_popup(target, "LAUNCHED", Color(1.0, 0.6, 0.3))

	if parried:
		_count("parries")
		s.enemy.timeline_penalty += stagger_push
		lines.append("%s is staggered" % s.enemy.display_name)
		lines.append(_grow_max_ap(parry_max_ap_gain, s.targets[0]))
	if parry_missed:
		ap = 0.0
		lines.append("Parry too early! Turn delayed, AP lost")
		var reset_note := _reset_max_ap()
		if reset_note != "":
			lines.append(reset_note)

	if not avoidable.is_empty() and not parry_missed and not s.enemy.get_meta("ap_penalty_done", false):
		# Once per strike (a 3-hit Combo costs one segment, not three).
		s.enemy.set_meta("ap_penalty_done", true)
		var note := _lose_max_ap_for_hit(avoidable)
		if note != "":
			lines.append(note)
		if playtest:
			playtest.avoidable(s.enemy, skill_name)

	for target in s.targets:
		if target.is_down:
			lines.append("%s is down!" % target.display_name)

	# Multi-hit skills: the next hit follows quickly, unless it was parried.
	if s.hits_left > 0 and not parried and not s.enemy.is_down:
		var next_mods := {}
		for target in s.targets:
			if not target.is_down:
				next_mods[target] = s.mods.get(target, {})
		if not next_mods.is_empty() and not _standing(party).is_empty():
			_flash("\n".join(lines))
			_check_party()
			_begin_strike(s.enemy, next_mods, s.reset_timeline, s.follow_windup, s.hits_left - 1)
			if s.reaction == Reaction.DEFEND:
				_strike.reaction = Reaction.DEFEND  # one Defend (one AP payment) guards the whole chain
			return
	_leave_hazards(s.enemy)
	_finish_enemy_skill(s.enemy, s.reset_timeline)
	_flash("\n".join(lines))
	print(" / ".join(lines))
	_check_party()
	_check_enemies()
	strike_finished.emit()


## Would taking this hit (no Parry, no Defend) have been avoidable?
## Dodgeable skills: always. Mechanic skills: only if the answer was missed
## (caught in an overlap, not stacked, not alone, not contained).
func _avoidable_hit(enemy: Combatant, def: EnemySkill, mods: Dictionary, target: Combatant, targets: Array) -> bool:
	if not def.is_mechanic():
		return true
	var mod: Dictionary = mods.get(target, {})
	if float(mod.get("mult", 1.0)) > 1.0 or mod.get("one_hp", false):
		return true  # overlap
	if def.shared_damage and targets.size() == 1 and _standing(party).size() > 1:
		return true  # took a stack mechanic alone
	if def.special == EnemySkill.Special.ON_MARKED and targets.size() > 1:
		return true  # the marked one wasn't alone
	if def.hits_everyone and not enemy.contained:
		return true  # never contained
	return false


## An avoidable hit landed: one segment (100) of bonus max AP cracks off.
## Returns a message ("" if there was no bonus to lose).
func _lose_max_ap_for_hit(who: Array) -> String:
	_count("avoidable_hits")
	if current_max_ap <= max_ap:
		return ""
	var before := current_max_ap
	if ap_meter:
		ap_meter.loss_text = "AVOIDABLE HIT"
	current_max_ap = maxf(current_max_ap - avoidable_hit_max_ap_loss, max_ap)
	ap = minf(ap, current_max_ap)
	var names: PackedStringArray = []
	for member in who:
		names.append(member.display_name)
	return "Avoidable hit on %s: max AP -%d (now %d)" % [", ".join(names), roundi(before - current_max_ap), int(current_max_ap)]


## True while someone stands where a revealed strike would cost max AP
## (the meter's top segment pulses red as a warning).
func _max_ap_at_risk() -> bool:
	if current_max_ap <= max_ap:
		return false
	for enemy in enemies:
		if enemy.is_down or not _is_live_threat(enemy):
			continue
		var mods := _strike_targets(enemy, true)
		var targets := mods.keys()
		for target in targets:
			if _avoidable_hit(enemy, enemy.loaded_def, mods, target, targets):
				return true
	return false


## A party member loses HP, recorded for the play-test report.
## Returns the HP actually lost (after barriers and shields).
func _hurt(member: Combatant, amount: int, recoverable: bool, source: String,
		enemy: Combatant = null, skill_name: String = "") -> int:
	var was_down := member.is_down
	var taken := member.take_damage(amount, recoverable)
	if playtest:
		playtest.hurt(member, taken, source, enemy, skill_name)
		if member.is_down and not was_down:
			playtest.down(member)
	return taken


## Saves the play-test report once per fight (not in the tutorial).
func _save_playtest(result: String) -> void:
	if playtest == null or playtest.saved:
		return
	if result == "Left early" and playtest.turns.is_empty():
		playtest.saved = true  # left before anything happened: nothing to report
		return
	var path: String = playtest.save(result, stats, party, enemies)
	if path != "":
		print("Play-test report: %s" % path)


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
	var dealt := enemy.take_damage(damage, false)
	if playtest:
		playtest.deal(archer, dealt)
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
		_save_playtest("Defeat")
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
			for hazard in _hazards.duplicate():
				if hazard["owner"] == enemy:
					_remove_hazard(hazard)
	if _standing(enemies).is_empty():
		_game_over = true
		_result_text = "Tutorial complete!" if tutorial_mode else "Victory!"
		_save_playtest("Victory")
		if boss_rush_mode:
			# Won: Continue picks up at the next round; after the last one the
			# Boss Rush is done and the save is cleared.
			if _round_index + 1 < boss_rush.rounds.size():
				SaveGame.save_round(_round_index + 1)
			else:
				SaveGame.clear()
		print("Victory")


# --- Party attacks --------------------------------------------------------

## A party turn starts: the command menu opens. Attack needs an enemy that
## at least one of the fighter's attacks can reach.
func _open_commands() -> void:
	_menu_mode = BattleMenu.Mode.COMMANDS
	var can_attack := _attack_target() != null
	battle_menu.command_index = 0 if can_attack else 2  # start on Wait if out of reach
	battle_menu.command_enabled[0] = can_attack
	var note := ""
	if not can_attack:
		# Something in reach but every attack that reaches it costs too much
		# (Meteor Strike reaches anyone, but costs 90 AP)?
		var reachable := false
		for enemy in _standing(enemies):
			for move in Moves.attacks(controlled.class_id):
				if _can_target(controlled, enemy, move):
					reachable = true
		note = "not enough AP" if reachable else "no enemy in reach"
	battle_menu.command_notes[0] = note


## Keys while a menu is open. W/S move the cursor, J confirms, K goes back,
## and in the combo bar Space starts the combo.
func _menu_input(event: InputEvent) -> void:
	if _menu_mode == BattleMenu.Mode.EXECUTING:
		if event.is_action_pressed("confirm"):
			get_viewport().set_input_as_handled()
			_judge_timing()
		elif event.is_action_released("confirm"):
			get_viewport().set_input_as_handled()
			_judge_release()
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
					_choose_attack_target()
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
				if _choosing_attack_target:
					_choosing_attack_target = false
					_menu_mode = BattleMenu.Mode.COMMANDS
				else:
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
					_refresh_combo_reach()
			elif begin:
				if _plan.is_empty():
					_flash(Keybinds.fill("Add at least one move first ({confirm})"))
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


## Attack: if more than one enemy is in reach, pick which one the combo hits
## (W / S, nearest first); with only one, go straight to the combo bar.
func _choose_attack_target() -> void:
	var first := _attack_target()
	var choices: Array[Combatant] = []
	for enemy in _standing(enemies):
		for move in Moves.attacks(controlled.class_id).filter(_affordable):
			if _can_target(controlled, enemy, move):
				choices.append(enemy)
				break
	choices.sort_custom(func(a, b): return controlled.gap_to(a) < controlled.gap_to(b))
	if first != null:
		choices.erase(first)
		choices.push_front(first)  # the default pick: nearest in normal reach
	if choices.size() <= 1:
		_open_combo_bar(first)
		return
	_target_choices = choices
	_target_index = 0
	_choosing_attack_target = true
	_begin_targeting({"name": "Attack", "target": Moves.Target.ENEMY, "range": 0.0}, Keybinds.fill("Attack: choose an enemy ({up} / {down})"))


func _open_combo_bar(target: Combatant = null) -> void:
	_combo_target = target if target != null else _attack_target()
	_moves = Moves.attacks(controlled.class_id)
	var doubled := controlled.statuses.has("arcane_cost")
	var usable: Array[bool] = []
	var notes: PackedStringArray = []
	for move in _moves:
		if int(move.get("mark_discount", 0)) > 0:
			# Execute: cheaper for every Mark on the target.
			var full := int(move["cost"])
			move["cost"] = maxi(int(move["min_cost"]), full - int(move["mark_discount"]) * _combo_target.marks)
			if _combo_target.marks > 0:
				move["desc"] = "4x from behind; %d Marks: %d AP (not %d)" % [_combo_target.marks, move["cost"], full]
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
		_refresh_combo_reach()


## After a Shadowstep on the bar, everything after it reaches the target
## (the Assassin will be standing right behind it).
func _refresh_combo_reach() -> void:
	var stepped := false
	for entry in _plan:
		if entry["move"].get("teleport_behind", false):
			stepped = true
	for i in _moves.size():
		var reaches := stepped or _can_target(controlled, _combo_target, _moves[i])
		battle_menu.move_usable[i] = reaches
		battle_menu.move_notes[i] = "" if reaches else "%s is out of its reach" % _combo_target.display_name


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
		# Each Bash in a row has one more hit, but every hit of it is weaker
		# (escalate_falloff per earlier Bash): more timed hits, so more
		# Perfects and max AP, without the damage running away.
		var per_hit: float = float(move["hits"][0]) * pow(float(move.get("escalate_falloff", 1.0)), count - 1)
		hits = []
		for i in count:
			hits.append(per_hit)
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
	if move.get("random_timing", false) and hits.size() == 1:
		# Assassin: the hit comes at a random moment. The first move of a
		# combo always lands in the middle or late part, so the opener is
		# never a surprise.
		var earliest := maxf(float(move["window"]) / duration + 0.05, 0.25)
		times = [randf_range(0.5 if _plan.is_empty() else earliest, 0.95)]
	if times.is_empty():
		for i in hits.size():
			times.append(float(i + 1) / hits.size())
	return {
		"move": move, "name": move["name"], "color": move["color"], "cost": move["cost"],
		"hits": hits, "times": times, "duration": duration,
		"window": float(move["window"]) / duration,
		"timing": int(move.get("timing", Moves.TimingType.PRESS)),
		"hold_start": float(move.get("hold_start", 0.35)),
		"taps": int(move.get("taps", 0)), "tap_start": float(move.get("tap_start", 0.12)),
	}


## Starts playing the combo. _update_combo then runs it frame by frame.
func _execute_combo() -> void:
	_menu_mode = BattleMenu.Mode.EXECUTING
	_exec_attacker = controlled
	_ap_before_combo = ap
	ap -= battle_menu.combo_cost()
	if combo_counter:
		combo_counter.begin(controlled.display_name)
	_exec_attacker.statuses.erase("arcane_cost")  # Arcane Barrier's cost lasts until the next attack
	if _exec_attacker.statuses.has("vanish"):
		_exec_attacker.statuses.erase("vanish")  # attacking gives a hidden Assassin away
		_popup(_exec_attacker, "REVEALED", Color(0.7, 0.7, 0.8))
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
	_exec_holding = false
	_exec_taps = 0
	battle_menu.exec_holding = false
	battle_menu.exec_taps = 0
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
		multiplier *= 1.0 + _settle_special_timing(entry, _exec_hits_done)
		var perfect := _exec_timings[_exec_hits_done] == Timing.PERFECT
		if _exec_timings[_exec_hits_done] == Timing.NONE:
			_shrink_max_ap(skipped_hit_max_ap_loss, _exec_attacker)  # opted out of the timing
		if perfect:
			multiplier *= 1.0 + perfect_damage_bonus
		_exec_attacker.play_lunge()
		var keep_going := _land_hit(_exec_attacker, entry["move"], multiplier, _exec_hits_done == 0)
		if combo_counter:
			combo_counter.hit(perfect)
		_exec_hits_done += 1
		if perfect:
			_popup(_exec_attacker, "PERFECT!", Color(1.0, 0.85, 0.2))
			_count("perfects")
			var kind_name: String = {Moves.TimingType.HOLD: "perfects_hold", Moves.TimingType.TAP: "perfects_tap"}.get(
					entry["timing"] if _special_hit(entry, _exec_hits_done - 1) else -1, "")
			if kind_name != "":
				_count(kind_name)
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
			if combo_counter:
				combo_counter.finish()


## The hint under the bar while a combo plays, for the current move's timing.
func _timing_prompt() -> String:
	if _exec_slot < _plan.size() and _exec_lead_in <= 0.0:
		var entry := _plan[_exec_slot]
		if _special_hit(entry, _exec_hits_done):
			if int(entry["timing"]) == Moves.TimingType.HOLD:
				return Keybinds.fill("HOLD {confirm} in the first box, LET GO in the last one: Perfect!  (a bad let-go only loses the Perfect)")
			return Keybinds.fill("TAP {confirm} %d times before the hit: Perfect!  (taps can't miss)" % int(entry["taps"]))
	return Keybinds.fill("{confirm} when the playhead hits the box: Perfect!  (a wrong press ends the chain)")


## True for the hit that uses the move's Hold or Tap timing (its last hit;
## any earlier hits, like Agility's extra one, are normal presses).
func _special_hit(entry: Dictionary, hit: int) -> bool:
	return int(entry["timing"]) != Moves.TimingType.PRESS and hit == (entry["hits"] as Array).size() - 1


## Called as a Hold / Tap hit lands: settles its result and returns its
## extra damage share (on top of the Perfect bonus, used for partial taps).
func _settle_special_timing(entry: Dictionary, hit: int) -> float:
	if not _special_hit(entry, hit):
		return 0.0
	match int(entry["timing"]):
		Moves.TimingType.HOLD:
			if _exec_holding:
				# Still holding when the arrow flies: let go too late.
				_exec_holding = false
				battle_menu.exec_holding = false
				_mark_timing(hit, Timing.PARTIAL)
				_popup(_exec_attacker, "LATE", Color(0.85, 0.8, 0.6))
		Moves.TimingType.TAP:
			var needed: int = maxi(int(entry["taps"]), 1)
			if _exec_taps >= needed:
				_mark_timing(hit, Timing.PERFECT)
			elif _exec_taps > 0:
				_mark_timing(hit, Timing.PARTIAL)
				_popup(_exec_attacker, "%d / %d" % [_exec_taps, needed], Color(0.85, 0.8, 0.6))
				return perfect_damage_bonus * float(_exec_taps) / needed
	return 0.0


func _mark_timing(hit: int, result: int) -> void:
	_exec_timings[hit] = result
	battle_menu.slot_results[_exec_slot][hit] = result


## Confirm let go during the combo: ends a Hold. Inside the release box =
## Perfect; too early = no Perfect (the hit still lands, nothing lost).
func _judge_release() -> void:
	if not _exec_holding or _exec_outro >= 0.0:
		return
	_exec_holding = false
	battle_menu.exec_holding = false
	var entry := _plan[_exec_slot]
	var hit := _exec_hits_done
	if not _special_hit(entry, hit):
		return
	var duration: float = entry["duration"]
	var window: float = float(entry["window"]) * duration
	var hit_time := duration * float(entry["times"][hit])
	if _exec_time >= hit_time - window:
		_mark_timing(hit, Timing.PERFECT)
	else:
		_mark_timing(hit, Timing.PARTIAL)
		_popup(_exec_attacker, "EARLY", Color(0.85, 0.8, 0.6))


## J during the combo: inside the next hit's timing box = Perfect;
## anywhere else = miss, and the chain ends right there. One try per hit.
## Hold hits: the press goes in the first box, then _judge_release judges
## the let-go. Tap hits: every press inside the tap stretch counts, and
## presses outside it are simply ignored.
func _judge_timing() -> void:
	if _exec_outro >= 0.0 or _exec_lead_in > 0.0:  # presses during the lead-in are ignored
		return
	var entry := _plan[_exec_slot]
	var duration: float = entry["duration"]
	var window: float = float(entry["window"]) * duration
	var hit := _exec_hits_done
	if hit < _exec_timings.size() and _special_hit(entry, hit):
		if int(entry["timing"]) == Moves.TimingType.TAP:
			if _exec_time >= duration * float(entry["tap_start"]) and _exec_taps < int(entry["taps"]):
				_exec_taps += 1
				battle_menu.exec_taps = _exec_taps
				if _exec_taps >= int(entry["taps"]):
					_mark_timing(hit, Timing.PERFECT)
			return
		# Hold: the press must start in the first box.
		if _exec_timings[hit] != Timing.NONE or _exec_holding:
			return
		var start_time := duration * float(entry["hold_start"])
		if _exec_time >= start_time - window and _exec_time <= start_time:
			_exec_holding = true
			battle_menu.exec_holding = true
			return
		if _exec_time > start_time:
			# Started late: no Perfect this time, but no harm done.
			_mark_timing(hit, Timing.PARTIAL)
			_popup(_exec_attacker, "LATE", Color(0.85, 0.8, 0.6))
			return
		# Too early: a normal miss (below).
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
		var reset_note := _reset_max_ap()
		ap = 0.0  # a missed timing costs all the party's AP
		_flash("Missed the timing! The chain ends, AP lost. " + reset_note)
		_stop_combo()


## The highest max AP can grow to: 100 per party member, plus 100.
func max_ap_ceiling() -> float:
	return max_ap_ceiling_per_member * (party.size() + 1)


## Raises the party's max AP for the rest of the fight. Returns a message.
func _grow_max_ap(amount: float, at: Combatant) -> String:
	var before := current_max_ap
	current_max_ap = minf(current_max_ap + amount, max_ap_ceiling())
	var gained := current_max_ap - before
	if gained <= 0.0:
		return "Max AP is already at its limit (%d)" % int(max_ap_ceiling())
	_popup(at, "+%d MAX AP" % roundi(gained), Color(0.45, 0.85, 1.0))
	return "Max AP +%d (now %d)" % [roundi(gained), int(current_max_ap)]


## AP gain scales with how far max AP has grown: 1.0 at the starting cap,
## 1.5 at 150, 2.0 at 200.
func _ap_gain_multiplier() -> float:
	return minf(current_max_ap / max_ap, ap_regen_max_multiplier)


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
	if combo_counter:
		combo_counter.finish()


## One hit of a move lands: works out everyone it reaches (by the move's
## area), applies it to each, and handles barriers. Returns false if the
## combo should stop (countered, attacker down, nobody left to hit).
func _land_hit(attacker: Combatant, move: Dictionary, multiplier: float, first_hit: bool) -> bool:
	if attacker.is_down:
		return false
	if first_hit and float(move["barrier"]) > 0.0:
		_give_barrier(attacker, move)
	if first_hit and move.get("teleport_behind", false) and _combo_target != null and not _combo_target.is_down:
		# Shadowstep: 1.5x if it started in front, then appear behind.
		if _combo_target.no_positionals or not _combo_target.is_behind(attacker.global_position):
			multiplier *= float(move.get("front_mult", 1.0))  # no positionals: every bonus applies
		_step_behind(attacker, _combo_target)
		_count("shadowsteps")
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
		_combo_target = _attack_target(false)
		if _combo_target == null:
			return false
		_flash("%s turns to %s" % [attacker.display_name, _combo_target.display_name])
	return true


## Puts a fighter right behind an enemy, facing it (Shadowstep).
func _step_behind(mover: Combatant, enemy: Combatant) -> void:
	var back := -enemy.flat_forward()
	mover.global_position = enemy.global_position + back * (enemy.body_radius + mover.body_radius + 0.25)
	_keep_in_arena(mover)
	mover.face_toward(enemy.global_position - mover.global_position, 1.0, 100000.0)
	_popup(mover, "SHADOWSTEP", Color(0.78, 0.45, 1.0))


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


## While building a combo, shows what the highlighted move would hit: its
## area on the floor (a circle on the target, a line through it, a circle
## around the attacker) in the move's colour, and a ring under each enemy it
## reaches (fainter for reduced-damage hits). Divine Barrier also shows who
## gets the barrier. Rebuilt only when the highlighted move changes.
func _update_move_preview() -> void:
	var showing := _menu_mode == BattleMenu.Mode.COMBO and _party_turn() and controlled != null \
			and _combo_target != null and not _moves.is_empty()
	var key := ""
	if showing:
		key = "%d|%s|%s" % [battle_menu.move_index, controlled.get_instance_id(), _combo_target.get_instance_id()]
	if key == _preview_key:
		return
	_preview_key = key
	_clear_move_preview()
	if not showing:
		return
	var move: Dictionary = _moves[clampi(battle_menu.move_index, 0, _moves.size() - 1)]
	var color: Color = move["color"]
	var usable := battle_menu.move_index < battle_menu.move_usable.size() and battle_menu.move_usable[battle_menu.move_index]
	var size: float = move["area_size"]
	var shape_def: EnemySkill = null
	var place := Vector3.ZERO
	var aim := Vector3.ZERO
	match move["area"]:
		Moves.Area.TARGET_CIRCLE:
			shape_def = EnemySkill.make("", Skills.Kind.ATTACK, EnemySkill.Shape.CIRCLE, size + _combo_target.body_radius, 360.0, 0, 0.0, 0)
			place = _combo_target.global_position
		Moves.Area.SELF_CIRCLE:
			shape_def = EnemySkill.make("", Skills.Kind.ATTACK, EnemySkill.Shape.CIRCLE, size + controlled.body_radius, 360.0, 0, 0.0, 0)
			place = controlled.global_position
		Moves.Area.LINE:
			var dir := _combo_target.global_position - controlled.global_position
			dir.y = 0.0
			shape_def = EnemySkill.make("", Skills.Kind.ATTACK, EnemySkill.Shape.LINE, dir.length() + 6.0, 0.0, 0, 0.0, 0)
			shape_def.width = size
			place = controlled.global_position
			aim = _combo_target.global_position
	if shape_def != null:
		_preview_area = AttackRange.new()
		add_child(_preview_area)
		_preview_area.global_position = Vector3(place.x, 0.05, place.z)
		if aim != Vector3.ZERO and Vector2(aim.x - place.x, aim.z - place.z).length() > 0.05:
			_preview_area.look_at(Vector3(aim.x, 0.05, aim.z), Vector3.UP)
		_preview_area.show_hazard(shape_def, color if usable else Color(0.6, 0.6, 0.65))
		_preview_area.set_alert(usable)  # brighter, so it reads through the menu
	if float(move["barrier_radius"]) > 0.0:
		var barrier_def := EnemySkill.make("", Skills.Kind.ATTACK, EnemySkill.Shape.CIRCLE, float(move["barrier_radius"]), 360.0, 0, 0.0, 0)
		_preview_barrier = AttackRange.new()
		add_child(_preview_barrier)
		_preview_barrier.global_position = Vector3(controlled.global_position.x, 0.04, controlled.global_position.z)
		_preview_barrier.show_hazard(barrier_def, Color(0.55, 0.8, 1.0))
		for ally in _standing(party):
			if ally.global_position.distance_to(controlled.global_position) <= float(move["barrier_radius"]):
				_add_preview_mark(ally, Color(0.55, 0.8, 1.0, 0.9))
	if not usable:
		return
	for victim in _hit_victims(controlled, move):
		var enemy: Combatant = victim[0]
		var share: float = victim[1]
		var mark_color := color.lightened(0.3)
		mark_color.a = 0.95 if share >= 1.0 else 0.5
		_add_preview_mark(enemy, mark_color)


func _add_preview_mark(fighter: Combatant, color: Color) -> void:
	var mark := _make_ring(fighter.body_radius + 0.45, 0.12, color)
	fighter.add_child(mark)
	mark.position.y = 0.08
	_preview_marks.append(mark)
	_preview_hits.append(fighter)


## Shows each enemy's positional ring (see PositionalRing) while a fighter
## that strikes from behind (flanks: the Assassin) is steered, so the player
## can see where to stand. Hidden for everyone else.
func _update_behind_cones() -> void:
	var show := controlled != null and controlled.flanks and not controlled.is_down and not _game_over
	for enemy in enemies:
		var ring: PositionalRing = _behind_cones.get(enemy)
		var wanted := show and not enemy.is_down
		if not wanted:
			if ring != null:
				ring.visible = false
			continue
		if ring == null:
			ring = PositionalRing.new()
			enemy.add_child(ring)
			ring.build(enemy.body_radius + 0.9, enemy.no_positionals)
			_behind_cones[enemy] = ring
		ring.visible = true
		ring.set_lit(enemy.is_behind(controlled.global_position))  # brighter when you're in it


## Tells the timeline who the player is aiming at (the chosen target while
## picking one, the combo's target while building or playing a combo) and
## who the previewed move would also hit, so twins like Kobold Archer A and
## B can be told apart on the bar.
func _update_timeline_targets() -> void:
	var target: Combatant = null
	if _party_turn():
		if _menu_mode == BattleMenu.Mode.TARGET and _pending_skill.get("target", -1) != Moves.Target.POINT \
				and not _target_choices.is_empty():
			target = _target_choices[clampi(_target_index, 0, _target_choices.size() - 1)]
		elif (_menu_mode == BattleMenu.Mode.COMBO or _menu_mode == BattleMenu.Mode.EXECUTING) and _combo_target != null:
			target = _combo_target
	timeline_bar.target = target
	timeline_bar.also_hit = _preview_hits
	# The targeted enemy's floating name turns gold too, to match the bar.
	var named: Combatant = target if target != null and target.team == Combatant.Team.ENEMY else null
	if named != _named_target:
		if is_instance_valid(_named_target):
			_named_target.set_highlighted(false)
		if named != null:
			named.set_highlighted(true)
		_named_target = named


func _clear_move_preview() -> void:
	for node in [_preview_area, _preview_barrier]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_preview_area = null
	_preview_barrier = null
	for mark in _preview_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_preview_marks.clear()
	_preview_hits.clear()


## Cleric's Divine Barrier: allies near the user get barrier HP.
func _give_barrier(user: Combatant, move: Dictionary) -> void:
	for ally in _standing(party):
		if ally.global_position.distance_to(user.global_position) <= float(move["barrier_radius"]):
			var gained := ally.add_shield(ceili(ally.max_hp * float(move["barrier"])))
			if gained > 0:
				_popup(ally, "+%d BARRIER" % gained, Color(0.55, 0.8, 1.0))


## Assassin's Marks from one hit: Backstab from behind adds one, every 3rd
## Stab on a Marked enemy adds one, Execute uses them all up.
func _apply_mark_effects(attacker: Combatant, target: Combatant, move: Dictionary, behind: bool) -> void:
	if target.is_down:
		return
	if int(move.get("marks_from_behind", 0)) > 0 and behind:
		_add_marks(target, int(move["marks_from_behind"]))
	if move.get("stab_marks", false) and target.marks > 0:
		var stabs: int = target.get_meta("marked_stabs", 0) + 1
		target.set_meta("marked_stabs", stabs)
		if stabs % 3 == 0:
			_add_marks(target, 1)
	if move.get("consume_marks", false) and target.marks > 0:
		_count("executes")
		target.set_marks(0)
		_popup(target, "MARKS SPENT", Color(0.78, 0.45, 1.0))


func _add_marks(target: Combatant, count: int) -> void:
	var before := target.marks
	var now := target.set_marks(target.marks + count)
	if now > before:
		_popup(target, "+%d MARK" % (now - before), Color(0.78, 0.45, 1.0))
		_count("marks")


## Marks on all standing enemies (the Assassin's auto-parry needs one).
func _marks_out() -> int:
	var total := 0
	for enemy in _standing(enemies):
		total += enemy.marks
	return total


## Spends one Mark for an auto-parry: from the attacking enemy if it has
## one, otherwise from the enemy with the most.
func _spend_mark(prefer: Combatant) -> void:
	var source: Combatant = prefer if prefer != null and prefer.marks > 0 else null
	if source == null:
		for enemy in _standing(enemies):
			if source == null or enemy.marks > source.marks:
				source = enemy
	if source != null and source.marks > 0:
		source.set_marks(source.marks - 1)


## Applies the skill triangle to one hit on one enemy, then the move's extra
## effects (stun, knockback). Returns false only if a Counter stance
## punished the attacker (the combo stops).
func _resolve_combo_hit(attacker: Combatant, target: Combatant, move: Dictionary, multiplier: float) -> bool:
	if attacker.is_down or target.is_down:
		return true
	var move_name: String = move["name"]

	if target.stance == Skills.Kind.COUNTER:
		# Counter beats every attack: the enemy punishes you, combo over.
		var taken := _hurt(attacker, counter_stance_damage, false, "%s: Counter stance" % target.display_name)
		_popup(target, "COUNTER!", Skills.info(Skills.Kind.COUNTER)["color"])
		_popup(attacker, str(taken), Color(1.0, 0.4, 0.3))
		_flash("%s's Counter stance punishes the %s! Combo stopped" % [target.display_name, move_name])
		_check_party()
		return false

	var note := ""
	# Assassin: where the attacker stands matters.
	var behind := target.is_behind(attacker.global_position)
	if move.get("front_miss", false) and not behind:
		_popup(target, "MISS", Color(0.7, 0.7, 0.75))
		_flash("%s misses: it only works from behind" % move_name)
		return true
	if behind and float(move.get("behind_mult", 1.0)) > 1.0:
		multiplier *= float(move["behind_mult"])
		_popup(attacker, "FROM BEHIND", Color(0.78, 0.45, 1.0))
		_count("behind_hits")
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
				var guard := target.loaded_def
				if guard != null and guard.let_through > 0.0:
					# A partial guard: the hit lands, softened.
					multiplier *= guard.let_through
					note = "Guarded: %d%% gets through" % roundi(guard.let_through * 100.0)
				else:
					_popup(target, "BLOCKED", Skills.info(Skills.Kind.DEFENSE)["color"])
					_flash("%s's Defense blocks the %s. Piercing or breaking moves get through!" % [target.display_name, move_name])
					return true
	elif target.loaded_skill == Skills.Kind.SMASH and (move["kind"] == Skills.Kind.ATTACK \
			or (move["effect"] == Moves.Effect.BREAK and target.interrupt_resist > 1)):
		# Bosses shrug off single hits: it takes interrupt_resist Attack-type
		# hits (or one breaking move) to stop their Smash.
		var needed := 1 if move["effect"] == Moves.Effect.BREAK else target.interrupt_resist
		var hits: int = target.get_meta("smash_hits", 0) + 1
		target.set_meta("smash_hits", hits)
		if hits >= needed:
			note = "Smash interrupted!"
			_count("interrupts")
			_cancel_enemy_skill(target)
		else:
			_popup(target, "%d / %d" % [hits, needed], Color(1.0, 0.75, 0.4))

	var damage := ceili(attacker.attack_power * multiplier)
	var dealt := target.take_damage(damage, false)
	if playtest:
		playtest.deal(attacker, dealt)
	if combo_counter and _menu_mode == BattleMenu.Mode.EXECUTING and attacker == _exec_attacker:
		combo_counter.damage(dealt)
	var is_smash: bool = move["kind"] == Skills.Kind.SMASH
	_popup(target, str(damage), Color(1.0, 0.7, 0.3) if is_smash else Color.WHITE)
	_apply_mark_effects(attacker, target, move, behind)

	var ritual := target.loaded_def
	if ritual != null and ritual.special == EnemySkill.Special.HEAL_ALLIES and not target.is_down \
			and attacker.gap_to(target) <= ritual.interrupt_range:
		# Close-range hits break a healing ritual.
		target.interrupt_count += 1
		if target.interrupt_count >= ritual.interrupt_hits:
			_cancel_enemy_skill(target)
			_count("interrupts")
			note = "%s interrupted!" % ritual.skill_name
		else:
			_popup(target, "%d / %d" % [target.interrupt_count, ritual.interrupt_hits], Color(0.5, 1.0, 0.6))
	if move["stun"] and not target.is_down and _loaded_offensive(target):
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
	if move.get("marked_any_range", false) and enemy.marks > 0:
		return true  # Shadowstep reaches any Marked enemy
	var move_reach := _move_reach(fighter, move)
	if fighter.gap_to(enemy) > move_reach:
		return false
	return move_reach == INF or _can_see(fighter, enemy)


## The enemy the controlled fighter's attacks go after: the nearest one in
## its normal reach, or else the nearest one a long-range attack (Holy Light,
## Meteor Strike) can reach.
## check_cost: only count attacks the party can pay for right now (off
## mid-combo, when the moves are already paid).
func _attack_target(check_cost: bool = true) -> Combatant:
	var attacks: Array[Dictionary] = Moves.attacks(controlled.class_id)
	if check_cost:
		attacks = attacks.filter(_affordable)
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


## True if the controlled fighter could put this attack on the bar now
## (its cost fits both the party's AP and the class's combo bar).
func _affordable(move: Dictionary) -> bool:
	var cost := float(move["cost"]) * (2.0 if controlled.statuses.has("arcane_cost") else 1.0)
	return cost <= minf(ap, controlled.combo_limit)


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
			note = "No enemy has a Mark" if skill.get("needs_marks", false) else "No enemy in range"
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
				if skill.get("needs_marks", false):
					if enemy.marks > 0:
						choices.append(enemy)  # any Marked enemy, however far
				elif controlled.gap_to(enemy) <= float(skill["range"]) and _can_see(controlled, enemy):
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
			_begin_targeting(skill, Keybinds.fill("%s: move the marker with {move}" % skill["name"]))
			_target_marker.global_position = controlled.global_position + controlled.flat_forward() * 3.0
			_keep_marker_in_range()
		_:
			_target_choices = _skill_choices(skill)
			_target_index = 0
			var what := "an enemy" if skill["target"] == Moves.Target.ENEMY else "an ally"
			_begin_targeting(skill, Keybinds.fill("%s: choose %s ({up} / {down})" % [skill["name"], what]))


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
		battle_menu.target_prompt = label + Keybinds.fill("   ({up} / {down} to change)")


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
	if _choosing_attack_target:
		_choosing_attack_target = false
		_open_combo_bar(chosen)
		return
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
		"Hook":
			if _loaded_offensive(target) or target.stance != Skills.NONE:
				_cancel_enemy_skill(target)  # stops its attack and breaks a Defense / Counter
				message += ": %s's move is stopped" % target.display_name
			else:
				message += " on %s" % target.display_name
			var dir := user.global_position - target.global_position
			dir.y = 0.0
			var room := maxf(dir.length() - user.body_radius - target.body_radius - 0.2, 0.0)
			if room > 0.0:
				target.global_position += dir.normalized() * minf(float(skill["pull"]), room)
				_keep_in_arena(target)
			if target.marks > 0:
				target.set_marks(0)
				message += " (its Marks are used up)"
			_popup(target, "HOOKED", skill["color"])
		"Death Sentence":
			_add_marks(target, int(skill["marks"]))
			message += ": %s has %d Marks" % [target.display_name, target.marks]
		"Shadow Cloak":
			var count := target.marks
			target.set_marks(0)
			var gained := user.add_shield(ceili(user.max_hp * float(skill["shield"]) * count))
			_popup(user, "+%d SHIELD" % gained, Color(0.55, 0.8, 1.0))
			message += ": %d Marks become a %d shield" % [count, gained]
		"Vanish":
			user.add_status("vanish", turns, user)
			for enemy in _standing(enemies):
				if enemy.cast_target == user:
					enemy.cast_target = _enemy_target(enemy)  # it loses its lock
			_popup(user, "VANISH", skill["color"])
			message += ": enemies lose track of %s" % user.display_name
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
	# Strikes that catch someone off screen: ease out so they're all in view.
	if _strike != null and not _strike_framing:
		_start_strike_framing()
	elif _strike == null:
		_strike_framing = false
	_strike_view = move_toward(_strike_view, 1.0 if _strike_framing else 0.0, delta * 3.0)
	_place_camera()


## Decides whether the current strike needs the camera to pull out, and
## where to: the middle of the enemy and everyone it hits, far enough back
## to fit them all.
func _start_strike_framing() -> void:
	var points: Array[Vector3] = [_strike.enemy.global_position]
	for target in _strike.targets:
		points.append(target.global_position)
	var all_seen := true
	for point in points:
		for height in [0.2, 1.6]:
			if not camera.is_position_in_frustum(point + Vector3(0, height, 0)):
				all_seen = false
	if all_seen:
		return
	var center := Vector3.ZERO
	for point in points:
		center += point
	center /= points.size()
	var spread := 0.0
	for point in points:
		spread = maxf(spread, Vector2(point.x - center.x, point.z - center.z).length())
	var half_fov := deg_to_rad(camera.fov) * 0.5
	_strike_focus = center
	_strike_distance = clampf((spread + 2.5) / tan(half_fov) * 1.1, _cam_distance, strike_frame_max_distance)
	_strike_framing = true


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
	var t := _strike_view * _strike_view * (3.0 - 2.0 * _strike_view)  # smooth in and out
	var focus := _cam_focus.lerp(_strike_focus, t)
	var distance := lerpf(_cam_distance, _strike_distance, t)
	_camera_offset = camera.global_basis.z * distance
	camera.global_position = focus + _camera_offset


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
	if _menu_mode == BattleMenu.Mode.COMBO and _party_turn() and active != null and _combo_target != null:
		# Building a combo: frame the attacker and the target, nudged so they
		# sit above the move list (which covers the middle of the screen).
		var center := active.global_position.lerp(_combo_target.global_position, 0.5)
		var toward_camera := camera.global_basis.z
		toward_camera.y = 0.0
		return center + toward_camera.normalized() * _cam_distance * 0.18
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
		battle_menu.target_name = _combo_target.display_name if _combo_target != null else ""
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
			controls_label.text = Keybinds.fill("Esc: back to the menu     {restart}: play the tutorial again")
		else:
			controls_label.text = Keybinds.fill("{next}: next round     {restart}: play again     Esc: menu" if won else "{restart}: retry     {next} / {prev}: next / previous round     Esc: menu")
			if playtest != null and playtest.saved:
				controls_label.text += "\nPlay-test report saved     O: open the reports folder"
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
			warning_label.text = _timing_prompt()
	elif party_turn:
		turn_label.text = "%s's turn" % active.display_name
	else:
		turn_label.text = "%s acts!" % active.display_name

	ap_bar.max_value = current_max_ap
	ap_bar.value = ap
	ap_label.text = "Party AP  %d / %d" % [floori(ap), int(current_max_ap)]
	if ap_meter:
		ap_meter.value = ap
		ap_meter.max_value = current_max_ap
		ap_meter.ceiling = max_ap_ceiling()
		ap_meter.flow_speed = _ap_gain_multiplier() * (2.0 if _concentrate_left > 0.0 else 1.0)
		ap_meter.boost_left = _concentrate_left
		ap_meter.ghost_cost = battle_menu.combo_cost() if _menu_mode == BattleMenu.Mode.COMBO and _party_turn() else 0.0
		ap_meter.at_risk = _max_ap_at_risk()

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
	var parry_hint := Keybinds.fill("{parry}: Parry when the ring turns gold" if _strike.def.parryable() else "{parry}: can't Parry this")
	var defend_hint := Keybinds.fill("{defend}: Defend (%d AP)" % defend_cost if _strike.def.blockable() else "{defend}: can't Defend this")
	if not _strike_targets_can("parry"):
		parry_hint = Keybinds.fill("{parry}: ") + "%s can't parry" % _names(_strike.targets)
	var auto := _strike.targets.filter(func(t): return t.auto_parry_with_marks)
	if not auto.is_empty() and _strike.def.parryable():
		parry_hint = ("%s auto-parries (a Mark is spent)" % _names(auto)) if _marks_out() > 0 \
				else ("%s: no Marks out, can't parry" % _names(auto))
	if not _strike_targets_can("block"):
		defend_hint = Keybinds.fill("{defend}: ") + "%s can't block" % _names(_strike.targets)
	if _strike.def.is_mechanic():
		# No prompt: there's nothing to press.
		return _flash_message if _flash_time_left > 0.0 else ""
	var prompt := parry_hint + "     " + defend_hint
	if _flash_time_left > 0.0:
		prompt = _flash_message + "\n" + prompt
	return prompt


func _controls_hint() -> String:
	if _turn_intro_left > 0.0:
		return ""  # the camera is still panning to the fighter
	match _menu_mode:
		BattleMenu.Mode.COMMANDS:
			return Keybinds.fill("{up} / {down}: choose     {confirm} / Enter: select")
		BattleMenu.Mode.COMBO:
			return Keybinds.fill("{up} / {down}: choose move     {confirm} / Enter: add     {cancel} / Backspace: remove last     {begin}: begin")
		BattleMenu.Mode.SKILLS:
			return Keybinds.fill("{up} / {down}: choose skill     {confirm} / Enter: use (ends the turn)     {cancel} / Backspace: back")
		BattleMenu.Mode.TARGET:
			return ""
	var standing := _standing(party)
	var next_name := ""
	if standing.size() > 1 and controlled != null:
		next_name = standing[(standing.find(controlled) + 1) % standing.size()].display_name
	var tab_part := Keybinds.fill("     {swap}: switch to ") + next_name if next_name != "" else ""
	return Keybinds.fill("{move}: move %s (free)%s     {cam_l} / {cam_r} or right-drag: camera     Esc: pause") % [controlled.display_name if controlled else "", tab_part]


## Shows a short message under the turn label for a moment.
func _flash(message: String, seconds: float = 2.5) -> void:
	_flash_message = message
	_flash_time_left = seconds


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
