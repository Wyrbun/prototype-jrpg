class_name TutorialDirector
extends Node
## Runs the tutorial: one guided fight against the Training Golem.
##
## The tutorial is a list of steps. A step is either a note (the fight pauses
## until J / Enter / Space) or a goal (the fight runs until the goal is met). Each
## step can set the fight up first: hold fighters on the timeline, make the
## Golem prepare a specific skill, add a party member.
##
## Nobody can fall here (every fighter has cannot_fall), so the player can't
## lose; a failed goal just comes around again.
##
## To change the wording, edit the texts in _build_steps().

const ARCHER := preload("res://scenes/characters/archer.tscn")
const MAGE := preload("res://scenes/characters/mage.tscn")
const CLERIC := preload("res://scenes/characters/cleric.tscn")
const ASSASSIN := preload("res://scenes/characters/assassin.tscn")

var battle: BattleArena
var panel: TutorialPanel
var golem: Combatant
var knight: Combatant
var assassin: Combatant
var steps: Array[Dictionary] = []
var index := -1

## Meters the Knight has walked (for the first goal).
var _walked := 0.0
var _last_knight_position := Vector3.ZERO
## Counts down after a goal is met, before the next step.
var _done_timer := -1.0
## Free practice: the Golem fights normally and can be defeated.
var _practice := false


func _ready() -> void:
	golem = battle.enemies[0]
	knight = battle.party[0]
	_last_knight_position = knight.global_position
	panel = TutorialPanel.new()
	battle.get_node("UI").add_child(panel)
	_build_steps()
	_next()


func _process(delta: float) -> void:
	if index < 0 or index >= steps.size():
		return
	if not battle.tutorial_pause:
		_walked += knight.global_position.distance_to(_last_knight_position)
	_last_knight_position = knight.global_position
	if not _practice and golem.hp < golem.max_hp * 0.3:
		golem.hp = golem.max_hp  # the Golem never falls before free practice

	var step := steps[index]
	if step.has("tick") and not battle.tutorial_pause:
		(step["tick"] as Callable).call()
	if step["goal"] != "" and _done_timer < 0.0 and (step["done"] as Callable).call():
		_done_timer = 1.3
		panel.goal_done = true
	if _done_timer >= 0.0:
		_done_timer -= delta
		if _done_timer < 0.0:
			_next()


## While a note is up, J / Enter / Space moves on and every other key is ignored.
func wants_input(event: InputEvent) -> bool:
	if index < 0 or index >= steps.size() or steps[index]["goal"] != "":
		return false
	if event.is_action_pressed("confirm") or event.is_action_pressed("end_turn"):
		_next()
		return true
	return event is InputEventKey or event is InputEventAction


func _next() -> void:
	index += 1
	_done_timer = -1.0
	if index >= steps.size():
		battle.tutorial_pause = false
		panel.body = ""
		return
	var step := steps[index]
	if step.has("start"):
		(step["start"] as Callable).call()
	for member in battle.party:
		member.hp = maxi(member.hp, ceili(member.max_hp * 0.6))
	panel.lesson = step["lesson"]
	panel.body = step["text"]
	panel.goal = step["goal"]
	panel.goal_done = false
	panel.lesson_number = step["number"]
	panel.lesson_total = steps[-1]["number"]
	battle.tutorial_pause = step["goal"] == ""


func _note(number: int, lesson: String, text: String, start: Callable = Callable()) -> void:
	var step := {"number": number, "lesson": "%d. %s" % [number, lesson], "text": text, "goal": ""}
	if start.is_valid():
		step["start"] = start
	steps.append(step)


func _goal(number: int, lesson: String, text: String, goal: String, done: Callable, start: Callable = Callable()) -> void:
	var step := {"number": number, "lesson": "%d. %s" % [number, lesson], "text": text, "goal": goal, "done": done}
	if start.is_valid():
		step["start"] = start
	steps.append(step)


func _stat(key: String) -> int:
	return int(battle.stats.get(key, 0))


# --- Setting up the fight ---------------------------------------------------

func _golem_skill(skill_name: String) -> EnemySkill:
	for skill in golem.skills:
		if skill.skill_name == skill_name:
			return skill
	return null


## The Golem keeps preparing the same skill, turn after turn.
func _golem_repeat(skill_name: String) -> void:
	battle._finish_enemy_skill(golem, false)
	golem.forced_skill = _golem_skill(skill_name)
	golem.hold = false
	golem.hold_at = -1.0
	golem.timeline_pos = minf(golem.timeline_pos, battle.cast_zone_start - 10.0)


## The Golem prepares one skill and then stays frozen with it revealed
## (a held enemy doesn't strike).
func _golem_show(skill_name: String) -> void:
	battle._finish_enemy_skill(golem, false)
	golem.forced_skill = _golem_skill(skill_name)
	golem.hold = false
	golem.timeline_pos = battle.cast_zone_start - 1.0  # starts casting at once, revealed before the Knight acts
	golem.hold_at = battle.reveal_at  # stops the moment its skill is revealed


func _golem_rest() -> void:
	battle._finish_enemy_skill(golem, false)
	golem.forced_skill = null
	golem.hold = true
	golem.hold_at = -1.0


## Brings the Knight's next turn close.
func _knight_soon() -> void:
	if battle.active != knight and knight.timeline_pos < 70.0:
		knight.timeline_pos = 70.0


func _top_up_ap(amount: float) -> void:
	battle.ap = maxf(battle.ap, minf(amount, battle.current_max_ap))


# --- The lessons ------------------------------------------------------------

func _build_steps() -> void:
	# 1. Welcome and moving
	_note(1, "Welcome",
		"This tutorial teaches every mechanic in one guided fight against a Training Golem. You can't lose: HP never drops below 1 here.\n\nRead each note, then press {confirm}, Enter or {begin} to continue. Esc pauses at any time; quit to the menu from there.",
		func():
			knight.hold = true
			_golem_rest())
	_goal(1, "Moving",
		"Between turns you steer one party member in real time. Enemies move at the same time, so where you stand matters.\n\n{cam_l} / {cam_r} or a right-drag turns the camera, the mouse wheel zooms, and {cam_reset} resets it. {up} always walks away from the camera.",
		"Walk around with {move}",
		func(): return _walked > 5.0,
		func(): _walked = 0.0)

	# 2. The timeline
	_note(2, "The timeline",
		"The bar at the top is the timeline. Every fighter's icon slides right at their own speed, and reaching the right end starts their turn. Party icons sit above the bar, enemies below.\n\nThe orange stretch at the end is the casting zone, where enemies prepare their skills.")
	_goal(2, "The timeline",
		"The gold ring around the Knight shows its reach: an enemy touching the ring can be attacked.",
		"Walk up until the Training Golem is inside your gold ring",
		func(): return knight.gap_to(golem) <= knight.reach())
	_goal(2, "The timeline",
		"Now let the Knight's icon reach the end of the bar.",
		"Wait for the Knight's turn",
		func(): return battle.active == knight,
		func():
			knight.hold = false
			knight.timeline_pos = maxf(knight.timeline_pos, 75.0))

	# 3. Your turn
	_note(3, "Your turn",
		"On a turn, the fighter is locked in place and the command menu opens:\n- Attack: build a combo (greyed out when no enemy is in reach, or the party can't afford a move that reaches one)\n- Abilities: use one skill\n- Wait: skip the turn, and the next one comes sooner\n\nEvery turn adds 30 AP to the party's pool. Use {up} / {down} to choose, {confirm} (or Enter) to select, and {cancel} (or Backspace) to go back.")
	_goal(3, "Combos",
		"Attack opens the combo bar. Each move fills part of the bar with its AP cost, and the bar's length is the most this class can spend in a turn. The AP the combo will spend shows as a dark section on the AP meter.\n\n{confirm} (or Enter) adds the selected move, {cancel} (or Backspace) removes the last one, and {begin} begins.",
		"Build a combo and press {begin}",
		func(): return _stat("combos") >= 1,
		func(): _top_up_ap(60.0))
	_note(3, "Timed hits",
		"While the combo plays, a white playhead sweeps across the bar after a short READY lead-in. Every hit has a small box: press {confirm} (or Enter) as the playhead enters it for a Perfect (+50% damage). The hit count and damage add up on the right of the screen.\n\nPress at the wrong moment and the chain ends, and the party loses all its AP.\n\nTimed hits are optional: if you can't hit one, just don't press. The hit still lands at normal damage.")
	_goal(3, "Timed hits",
		"Try it on this combo or on the Knight's next turn. Remember: when in doubt, don't press. A skipped timing is a normal hit, a wrong press ends the combo.",
		"Land a Perfect hit",
		func(): return _stat("perfects") >= 1,
		func():
			_knight_soon()
			_top_up_ap(60.0))
	_goal(3, "Waiting",
		"Wait spends no AP. The Knight's next turn starts a third of the way along the bar instead of at the beginning.",
		"Choose Wait on the Knight's next turn",
		func(): return _stat("waits") >= 1,
		func(): _knight_soon())

	# 4. Reading the enemy
	_note(4, "Reading the enemy",
		"Enemies prepare skills in the casting zone. As soon as one enters it, you see where the skill will land: its area appears on the floor in grey, marked \"???\". Later in the zone the skill is revealed: its name, and its area in color. It strikes when its icon reaches the end of the bar, hitting anyone still inside the area.\n\nWhile preparing, the enemy turns to follow whoever it locked onto, and only slows down in the last second. That's your moment to slip out of the area. A line at the top of the screen names anyone who would be hit.",
		func():
			knight.hold = true
			_golem_repeat("Attack"))
	_goal(4, "Reading the enemy",
		"The Golem will keep preparing Attack. Watch for the reveal and stay out of the area.",
		"Make the Golem's Attack miss",
		func(): return _stat("misses") >= 1)

	# 5. Parry and Defend
	_note(5, "Parry",
		"You don't always have to dodge. When a strike comes, a ring shrinks onto whoever it targets. Press {parry} as the ring turns gold to Parry: no damage, the enemy is staggered, and your max AP grows. Attacks that hit several times show a ring for each hit, and each one can be Parried.\n\nPress too early and you take the full hit, your next turn is delayed, and the party loses all its AP.")
	_goal(5, "Parry",
		"Stand inside the revealed area and wait for the ring.",
		"Parry a strike ({parry} when the ring turns gold)",
		func(): return _stat("parries") >= 1,
		func(): _golem_repeat("Attack"))
	_goal(5, "Defend",
		"{defend} Defends instead: it costs 10 AP and you still take some damage, but that damage comes back at your next turn if you aren't hit again. One Defend covers every hit of a multi-hit attack. Against a Smash, Defend lets more through, so Parry or dodge those.",
		"Defend against a strike ({defend})",
		func(): return _stat("defends") >= 1,
		func(): _top_up_ap(40.0))

	# 6. The skill triangle
	_note(6, "The skill triangle",
		"Every skill has a place in a triangle:\n- Attack beats Smash (it interrupts it)\n- Smash breaks Defense\n- Defense blocks Attack\n- Counter punishes anything that hits it\n\nIt works both ways: what the enemy prepares changes which of your moves work.",
		func(): knight.hold = false)
	_goal(6, "Defense",
		"The Golem raises its Defense stance, and basic moves like Slash bounce off. Thrust ignores Defense, and Smash breaks it.",
		"Hit through the Defense with Thrust or Smash",
		func(): return _stat("guard_breaks") >= 1,
		func():
			_golem_show("Defense")
			_knight_soon()
			_top_up_ap(60.0))
	_goal(6, "Counter",
		"Now it holds Counter. Anything that hits it gets punished, and your combo stops. The answer is patience: let the stance run out.",
		"Choose Wait while the Counter stance is up",
		func(): return _stat("counter_waits") >= 1,
		func():
			_golem_show("Counter")
			_knight_soon())
	_goal(6, "Smash",
		"It's preparing a Smash: a heavy hit that Defend handles badly. Attack-type moves (Slash, Thrust, Double Slash) interrupt it and knock it out of the casting zone. Bosses shrug off the first two: it takes three hits, or one breaking move like Smash.",
		"Interrupt the Smash with an Attack-type move",
		func(): return _stat("interrupts") >= 1,
		func():
			_golem_show("Smash")
			_knight_soon()
			_top_up_ap(60.0))

	# 7. More party members and Abilities
	_note(7, "The Archer joins",
		"Between turns, {swap} switches who you steer. The others move on their own: they stay out of danger, stand near their attack range, and stack up or spread out when an enemy skill calls for it.\n\nEach class has its own attacks, skills and reactions. The Archer can't Block or Parry, but its Riposte skill counters a strike instead.\n\nSome Archer moves are HOLD moves (a blue HOLD badge; rounded blue boxes on the bar): press {confirm} in the first box, keep holding, and let go in the last box for a Perfect. A bad let-go only loses the Perfect.",
		func():
			_golem_rest()
			battle.add_party_member(ARCHER))
	_goal(7, "Abilities",
		"Abilities lists a class's skills. Some ask for a target: {up} / {down} picks an ally or enemy, and Jump lets you place a marker with {move}. Using a skill ends the turn.",
		"Use an Ability with anyone",
		func(): return _stat("skills") >= 1,
		func(): _top_up_ap(80.0))
	_note(7, "The Mage and the Cleric",
		"Two more join.\n\nThe Mage's attacks hit areas: Energy Blast catches enemies near the target, Firebolt runs through a line, and Meteor Strike hits every enemy. These are TAP moves (a pink TAP badge; a dashed pink stretch with one diamond per tap): tap {confirm} that many times before the hit. Each tap adds damage, all of them make a Perfect, and taps can never miss. Its Concentrate skill doubles AP recharge for a while (the AP meter shows it).\n\nThe Cleric keeps the party alive with Healing, Shielding and Full Cure, and can still fight up close: each Bash in a row adds a hit, though each hit is weaker.",
		func():
			battle.add_party_member(MAGE)
			battle.add_party_member(CLERIC))
	_goal(7, "The Mage",
		"Steer the Mage into range between turns ({swap}), then attack on its turn.",
		"Attack with the Mage",
		func(): return _stat("combos_mage") >= 1,
		func(): _top_up_ap(80.0))
	_goal(7, "The Cleric",
		"Healing, Shielding, Haste or Full Cure: any of them counts.",
		"Use one of the Cleric's skills",
		func(): return _stat("skills_cleric") >= 1,
		func(): _top_up_ap(80.0))

	# 8. Max AP
	_note(8, "Max AP",
		"AP is shared by the whole party and recharges over time. Every Perfect and every Parry raises max AP for the rest of the fight, up to 100 per party member plus 100. The meter grows a new coloured segment for every 100, and a bigger max recharges faster (up to twice as fast).\n\nMiss a timed hit or a Parry and the party loses all its AP, and max AP drops back to 100. Taking a hit you could have avoided costs one segment: the meter pulses red while someone stands in harm's way. Skipping timed hits slowly drains the bonus too.")
	_goal(8, "Max AP",
		"Land Perfect hits or Parry the Golem's strikes. It's attacking again.",
		"Raise max AP above 100",
		func(): return battle.current_max_ap > battle.max_ap,
		func(): _golem_repeat("Attack"))

	# 9. Rocks
	_note(9, "Rocks",
		"Rocks block movement and attacks, in both directions: an enemy's area doesn't reach anyone hidden behind a rock, and you can't attack through one either. Pits, in later arenas, only block movement.",
		func(): _golem_rest())
	_goal(9, "Rocks",
		"The Golem has revealed Long Strike, a long, straight line, and is waiting for you. Steer the Knight behind the rock: once you're hidden, it finishes its cast and strikes.",
		"Let the rock block a Long Strike",
		func(): return _stat("rock_saves") >= 1,
		func():
			if battle.controlled != knight and battle.active == null:
				battle._set_controlled(knight)
			golem.global_position = Vector3(1.5, 0.0, -1.5)
			golem.add_status("taunt", 99, knight)  # it tracks the Knight, not the nearest ally
			_golem_show("Long Strike"))
	steps[-1]["tick"] = func():
		# Once the Knight is in the line but hidden, let the Golem strike.
		if golem.hold and golem.skill_revealed and golem.attack_range.contains(knight.global_position, knight.body_radius) \
				and not battle._can_see(golem, knight):
			golem.hold = false
			golem.hold_at = -1.0

	# 10. Special enemy skills (later enemies; the Training Golem doesn't use them)
	_note(10, "Special skills",
		"Later enemies have skills marked UNAVOIDABLE. Those can't be dodged, Parried or Defended: their circles and lines follow their targets until they land, and they just deal their damage. What matters is answering them:\n- Red sphere over everyone: spread out, so circles don't overlap\n- Arrows pointing inward: stack up, to share the damage\n- A circle on one person: they should stand alone\n\nGetting the answer wrong costs a max AP segment, like any avoidable hit.")
	_note(10, "Special skills",
		"Some other things to watch for:\n- Some skills leave fire or spikes on the ground for a few turns\n- Growing circles get bigger over the cast: hit the caster hard to stop them, then step out\n- A healing enemy can be interrupted with three hits from up close\n- An orange sphere means a follow-up will hit you for sure\n\nThe Boss Rush introduces them one at a time.")

	# 11. The Assassin: positioning and Marks
	_note(11, "The Assassin",
		"One more class: the Assassin. It can't Block or Parry, and most of its damage depends on WHERE it stands: behind an enemy means within 60 degrees of its back (the side away from its nose).\n\nSmall enemies like Goblins and Kobolds have no back to find: their ring is a full violet circle, and every hit counts as from behind.\n\nEnemies turn to face whoever they're after. The Golem is Taunted by the Knight now, so it keeps facing the Knight and leaves its back open. In real fights, the Knight's Taunt does exactly this for the Assassin.",
		func():
			_golem_rest()
			assassin = battle.add_party_member(ASSASSIN)
			assassin.global_position = knight.global_position + Vector3(2.5, 0.0, 0.0)
			battle._keep_in_arena(assassin)
			golem.add_status("taunt", 99, knight))
	_goal(11, "Get behind",
		"Between turns, switch to the Assassin ({swap}) and walk round to the Golem's back. While you steer the Assassin, every enemy has a ring on the floor: the arrow is its front, and the violet arc is its back, glowing when you stand in it. On the Assassin's turn, attack: Stab deals 1.5x from behind, and FROM BEHIND pops up when it counts.",
		"Hit the Golem from behind",
		func(): return _stat("behind_hits") >= 1,
		func():
			_top_up_ap(100.0)
			golem.add_status("taunt", 99, knight)
			if assassin.timeline_pos < 55.0:
				assassin.timeline_pos = 55.0)
	_goal(11, "Shadowstep",
		"Walking round takes time. Shadowstep teleports the Assassin behind its target, then strikes, and deals 1.5x if it started in FRONT. Moves after it on the combo bar land from behind. Its timings are random, but the first move of a combo always comes in the middle or late part of its box.",
		"Use Shadowstep",
		func(): return _stat("shadowsteps") >= 1,
		func():
			_top_up_ap(100.0)
			if assassin.timeline_pos < 55.0:
				assassin.timeline_pos = 55.0)
	_note(11, "Assassin's Marks",
		"Marks sit on enemies (up to 5): you see MARK x3 over the enemy and violet diamonds by its timeline icon. Ways to add them:\n- Backstab from behind: 2x damage and a Mark (from the front it always misses)\n- Death Sentence (Abilities): 3 Marks at once\n- Every 3rd Stab on a Marked enemy adds one")
	_goal(11, "Assassin's Marks",
		"Build up Marks on the Golem.",
		"Put 4 Marks on the Golem",
		func(): return golem.marks >= 4,
		func():
			_top_up_ap(100.0)
			if assassin.timeline_pos < 55.0:
				assassin.timeline_pos = 55.0)
	_note(11, "Spending Marks",
		"Marks are what the Assassin spends:\n- Execute: 4x from behind, and 15 AP cheaper per Mark on its target (it fits the Assassin's bar from 4 Marks). It uses them all up\n- Auto-parry: while any Mark is out, the Assassin parries strikes by itself, spending one\n- Hook stops an enemy's move (and uses its Marks); Shadow Cloak turns them into a shield\n\nVanish makes enemies lose track of the Assassin until it attacks.")
	_goal(11, "Execute",
		"Finish the job: Execute the Golem, from behind for 4x damage.",
		"Use Execute on a Marked Golem",
		func(): return _stat("executes") >= 1,
		func():
			_top_up_ap(100.0)
			golem.set_marks(maxi(golem.marks, 4))
			if assassin.timeline_pos < 55.0:
				assassin.timeline_pos = 55.0)
	_goal(11, "Auto-parry",
		"The Golem has 2 Marks again and is coming for the Assassin. Stand in FRONT of it (its Attack is a short line ahead of it) and don't press anything: when the strike lands, the Assassin parries it by itself.",
		"Auto-parry a strike",
		func(): return _stat("auto_parries") >= 1,
		func():
			golem.set_marks(maxi(golem.marks, 2))
			golem.add_status("taunt", 99, assassin)
			if battle.controlled != assassin and battle.active == null:
				battle._set_controlled(assassin)
			_golem_repeat("Attack"))

	# 12. Free practice
	_note(12, "Free practice",
		"That's everything! The Training Golem now fights freely and can be defeated. Experiment as long as you like.\n\nEsc pauses; quit to the menu from there, where the Boss Rush is waiting.",
		func():
			_practice = true
			golem.statuses.erase("taunt")
			golem.forced_skill = null
			golem.hold = false
			golem.hold_at = -1.0
			golem.cannot_fall = false
			golem.hp = golem.max_hp)
	_goal(12, "Free practice",
		"Everything you've learned works here. The Golem picks its skills at random again.",
		"Defeat the Training Golem (optional)",
		func(): return golem.is_down)
