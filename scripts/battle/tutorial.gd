class_name TutorialDirector
extends Node
## Runs the tutorial: one guided fight against the Training Golem.
## It teaches Windup command timing (the default): choose at the COM mark,
## get in reach, act at ACT. The old Classic version is kept in
## archive/tutorial_classic.gd.
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
const MONK := preload("res://scenes/characters/monk.tscn")

## "Soon": a moment before the COM mark (party_command_at, 65).
const SOON_AT := 59.0

var battle: BattleArena
var panel: TutorialPanel
var golem: Combatant
var knight: Combatant
var assassin: Combatant
var monk: Combatant
var steps: Array[Dictionary] = []
var index := -1

## Meters the Knight has walked (for the first goal).
var _walked := 0.0
var _last_knight_position := Vector3.ZERO
## Counts down after a goal is met, before the next step.
var _done_timer := -1.0
## Who's in the fight: each class lesson features only that class.
## Party members by class_id, and the lineup waiting to be applied.
var _members := {}
var _pending_party: Array = []
## Combos played before the Arts list step (it needs a new one).
var _combos_before_list := 0
## Free practice: the Golem fights normally and can be defeated.
var _practice := false


func _ready() -> void:
	golem = battle.enemies[0]
	knight = battle.party[0]
	_members["knight"] = knight
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

	_apply_party()
	var step := steps[index]
	var menu: int = battle._menu_mode
	panel.compact = battle._party_turn() and menu != BattleMenu.Mode.HIDDEN and menu != BattleMenu.Mode.COMMANDS
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
	if battle.active != knight and not knight.has_meta("windup_target") and knight.timeline_pos < SOON_AT:
		knight.timeline_pos = SOON_AT


func _top_up_ap(amount: float) -> void:
	battle.ap = maxf(battle.ap, minf(amount, battle.current_max_ap))


## Sets who's in the fight (class ids). Applied at once, or as soon as no
## turn is being played.
func _set_party(ids: Array) -> void:
	_pending_party = ids
	_apply_party()


func _apply_party() -> void:
	if _pending_party.is_empty() or battle._strike != null:
		return
	if battle.active != null:
		if battle.active.team == Combatant.Team.PARTY and not _pending_party.has(battle.active.class_id) \
				and battle._menu_mode == BattleMenu.Mode.COMMANDS:
			battle._menu_mode = BattleMenu.Mode.HIDDEN
			battle._end_turn()  # its lesson is over: the turn passes quietly
		if battle.active != null:
			return
	var scenes := {"knight": null, "archer": ARCHER, "mage": MAGE, "cleric": CLERIC, "assassin": ASSASSIN, "monk": MONK}
	for member in battle.party.duplicate():
		if not _pending_party.has(member.class_id):
			battle.bench_member(member)
	for id in _pending_party:
		if _members.has(id):
			battle.unbench_member(_members[id])
		else:
			_members[id] = battle.add_party_member(scenes[id])
	if id_member(String(_pending_party[0])) != null and (battle.controlled == null or not battle.party.has(battle.controlled)):
		battle._set_controlled(id_member(String(_pending_party[0])))
	if _members.has("assassin"):
		assassin = _members["assassin"]
	if _members.has("monk"):
		monk = _members["monk"]
	_pending_party = []


func id_member(id: String) -> Combatant:
	return _members.get(id, null)


## Brings a party member's next turn close.
func _soon(id: String) -> void:
	var member := id_member(id)
	if member != null and battle.active != member and not member.has_meta("windup_target") and member.timeline_pos < SOON_AT:
		member.timeline_pos = SOON_AT


# --- The lessons ------------------------------------------------------------

func _build_steps() -> void:
	# 1. Welcome and moving
	_note(1, "Welcome",
		"This tutorial teaches every mechanic in one guided fight against a Training Golem. You can't lose: HP never drops below 1 here.\n\nRead each note, then press {confirm}, Enter or {begin} to continue. Esc pauses at any time; quit to the menu from there.",
		func():
			knight.hold = true
			_golem_rest())
	_goal(1, "Moving",
		"Between turns you steer one party member in real time. The fight doesn't wait for you: enemies walk and the timeline keeps running whether you move or stand still, so where you stand matters.\n\n{cam_l} / {cam_r} or a right-drag turns the camera, the mouse wheel zooms, and {cam_reset} resets it. {up} always walks away from the camera.",
		"Walk around with {move}",
		func(): return _walked > 5.0,
		func(): _walked = 0.0)

	# 2. The timeline
	_note(2, "The timeline",
		"The bar at the top is the timeline. Every fighter's icon slides right at their own speed. Party icons sit above the bar, enemies below.\n\nA party member's turn comes in two parts:\n- COM (the gold mark): you choose what to do, and the fight pauses while you do\n- ACT (the end of the bar): the attack you chose happens\n\nThe orange stretch, CAST, is where enemies prepare their skills. They strike when they reach ACT.")
	_goal(2, "The timeline",
		"The gold ring around the Knight shows its reach: an enemy touching the ring can be attacked.",
		"Walk up until the Training Golem is inside your gold ring",
		func(): return knight.gap_to(golem) <= knight.reach())
	_goal(2, "The timeline",
		"Now let the Knight's icon reach the gold COM mark.",
		"Wait for the Knight's command (COM)",
		func(): return battle.active == knight,
		func():
			knight.hold = false
			knight.timeline_pos = maxf(knight.timeline_pos, SOON_AT))

	# 3. Your turn
	_note(3, "Your turn",
		"At COM the command menu opens:\n- Attack: choose who to go after. You don't need to be in reach yet\n- Abilities: use one Ability (a class's special actions) right away. Then you can still Attack or Wait\n- Wait: skip the turn, and the next one comes sooner\n\nEvery turn adds 30 AP to the party's pool. Use {up} / {down} to choose, {confirm} (or Enter) to select, and {cancel} (or Backspace) to go back.",
		func():
			# Out of reach on purpose: the next lesson is getting there.
			knight.hold = true
			var away := knight.global_position - golem.global_position
			away.y = 0.0
			if away.length() < 0.1:
				away = Vector3(0, 0, 1)
			knight.global_position = golem.global_position + away.normalized() * (golem.body_radius + 5.5)
			battle._keep_in_arena(knight))
	_goal(3, "Go after it",
		"The Knight is out of reach now. That's fine: choose Attack anyway, and the Golem as the target.\n\nThe fight runs again, and the Knight's icon heads from COM to ACT.",
		"Choose Attack at COM",
		func(): return _stat("windups") >= 1,
		func():
			knight.hold = false
			_knight_soon()
			_top_up_ap(60.0))
	_goal(3, "Get in reach",
		"Walk ({move}) until the Golem is inside your gold ring before the Knight's icon reaches ACT. A short grace at the end still counts.\n\nToo far when it ends, and the turn becomes a Wait (TOO FAR): choose Attack again on the next one.",
		"Get in reach before ACT",
		func(): return battle.active == knight and battle._menu_mode == BattleMenu.Mode.COMBO,
		func(): pass)
	steps[-1]["tick"] = func():
		# Missed it: bring the next command around for another try.
		if battle.active == null and not knight.has_meta("windup_target"):
			_knight_soon()
	_goal(3, "Combos",
		"At ACT the combo bar opens on your target. Each move fills part of the bar with its AP cost, and the bar's length is the most this class can spend in a turn. The AP the combo will spend shows as a dark section on the AP meter.\n\n{confirm} (or Enter) adds the selected move, {cancel} (or Backspace) removes the last one, and {begin} begins. You chose Attack at COM, so there's no going back to the menu now.",
		"Build a combo and press {begin}",
		func(): return _stat("combos") >= 1,
		func(): _top_up_ap(60.0))
	steps[-1]["tick"] = func():
		if battle.active == null and not knight.has_meta("windup_target"):
			_knight_soon()
	_note(3, "Timed hits",
		"While the combo plays, a white playhead sweeps across the bar after a short READY lead-in. Every hit has a small box: press {confirm} (or Enter) as the playhead enters it for a Perfect (+50% damage). The hit count and damage add up on the right of the screen.\n\nPress at the wrong moment and the chain ends, and the party loses all its AP.\n\nTimed hits are optional: if you can't hit one, just don't press. The hit still lands at normal damage.")
	_goal(3, "Timed hits",
		"Try it on this combo or on the Knight's next one (Attack at COM, then get in reach). Remember: when in doubt, don't press. A skipped timing is a normal hit, a wrong press ends the combo.",
		"Land a Perfect hit",
		func(): return _stat("perfects") >= 1,
		func():
			_knight_soon()
			_top_up_ap(60.0))
	_goal(3, "Waiting",
		"Wait spends no AP. The Knight's icon goes back a third of the way along the bar instead of to the beginning, so the next COM comes sooner.",
		"Choose Wait at the Knight's next COM",
		func(): return _stat("waits") >= 1,
		func(): _knight_soon())
	_note(3, "Arts",
		"Some moves in the right order form ARTS: named attacks that hit harder than their parts, and the longer ones add effects. Every class has its own.\n\nThey're secret until you find one. Put moves in an order that hides an Art and start the combo: when the playhead reaches those moves, they merge into the Art with a NEW ART! banner. From then on they merge on the bar as you build them.\n\nThe ARTS panel beside the moves lists the Arts you've found, with their recipes, and how many are still hidden, by length (\"Hidden: 4 two-move, 1 four-move\"). The long ones are finishers, worth hunting for.")
	_goal(3, "Your first Art",
		"Put Slash on the bar, then Slash again, and press {begin}. Watch the bar when the playhead reaches them.\n\n(If you've found it before, the two Slashes already merge as you build them.)",
		"Play Slash + Slash",
		func(): return _stat("art_double_slash") >= 1,
		func():
			_knight_soon()
			_top_up_ap(60.0))
	_goal(3, "The Arts list",
		"Known Arts can also go on the bar in one go. In the combo bar, press {swap} to move into the ARTS panel, choose an Art with {up} / {down}, and {confirm} adds its whole recipe. {swap} or {cancel} goes back to the moves.\n\nAn Art picked from the list stays itself even after other moves, and the chosen Art's details (its cost, timing and what it does) show left of the moves.",
		"Add an Art from the list ({swap}) and play it",
		func(): return _stat("arts_picked") >= 1 and _stat("combos") > _combos_before_list,
		func():
			_combos_before_list = _stat("combos")
			_knight_soon()
			_top_up_ap(60.0))

	# 4. Reading the enemy
	_note(4, "Reading the enemy",
		"Enemies prepare skills in the casting zone. As soon as one enters it, you see where the skill will land: its area appears on the floor in grey, marked \"???\". Later in the zone the skill is revealed: its name, and its area in color. It strikes when its icon reaches ACT, hitting anyone still inside the area.\n\nWhile preparing, the enemy turns to follow whoever it locked onto, and only slows down in the last second. That's your moment to slip out of the area. A line at the top of the screen names anyone who would be hit.",
		func():
			knight.hold = true
			_golem_repeat("Attack"))
	_goal(4, "Reading the enemy",
		"The Golem will keep preparing Attack. Watch for the reveal and stay out of the area.",
		"Make the Golem's Attack miss",
		func(): return _stat("misses") >= 1)

	# 5. Parry and Defend
	_note(5, "Parry",
		"You don't always have to dodge. When a strike comes, a ring shrinks onto whoever it targets. Press {parry} as the ring turns gold to Parry: no damage, the enemy is knocked back on the timeline, and your max AP grows. Attacks that hit several times show a ring for each hit, and each one can be Parried.\n\nPress too early and you take the full hit, your next turn is delayed, and the party loses all its AP.")
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
		"Every skill has a place in a triangle:\n- Attack beats Smash (it interrupts it)\n- Smash breaks Defense\n- Defense blocks Attack\n- Counter catches anything that hits it and swings back\n\nIt works both ways: what the enemy prepares changes which of your moves work.\n\nWhile you pick moves, the ones that answer what the enemy is doing get a green tag (INTERRUPTS, PIERCES, STUNS...), and the ones that would backfire get a red one (BLOCKED). A yellow one is a risk you can take (COUNTER: PARRY IT).",
		func(): knight.hold = false)
	_goal(6, "Defense",
		"The Golem raises its Defense stance, and basic moves like Slash bounce off. Thrust ignores Defense, and so does Lunge (the Art Slash + Thrust).",
		"Hit through the Defense with Thrust or Lunge",
		func(): return _stat("guard_breaks") >= 1,
		func():
			_golem_show("Defense")
			_knight_soon()
			_top_up_ap(60.0))
	_goal(6, "Counter",
		"Now it holds Counter. Your first hit is caught and it swings back: the playhead stops and a red line closes in. Press {confirm} as it reaches the red box to parry it: the stance breaks and the rest of your combo hits harder. Miss and you're countered: damage, and the combo stops.\n\nThe safe answer is patience: Wait and let the stance run out. If it goes into Counter after you chose Attack, {cancel} at ACT backs off (your turn becomes a Wait).",
		"Choose Wait at COM while the Counter stance is up",
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
	_note(7, "The Archer",
		"Each class has its own attacks, Abilities and reactions. Meet them one at a time, starting with the Archer.\n\nThe Archer can't Block or Parry, but her Riposte Ability counters a strike instead.\n\nSome Archer moves are HOLD moves (a blue HOLD badge; rounded blue boxes on the bar): press {confirm} in the first box, keep holding, and let go in the last box for a Perfect. A bad let-go only loses the Perfect.",
		func():
			_golem_rest()
			_set_party(["archer"]))
	_goal(7, "Abilities",
		"Abilities lists a class's special actions. Some ask for a target: {up} / {down} picks an ally or enemy, and Jump lets you place a marker with {move}. You can use one Ability per turn: after it, Abilities shows the one you used and you can still Attack or Wait.",
		"Use an Ability with the Archer",
		func(): return _stat("skills_archer") >= 1,
		func():
			_soon("archer")
			_top_up_ap(80.0))
	_note(7, "The Mage",
		"The Mage's spells hit areas: Fire runs through a line and sets enemies burning (they take damage each time they act, twice), Frost chills a small circle (enemies walk at half speed until their next turn), and Gust pushes away everyone around the Mage.\n\nFire and Frost are TAP moves (a pink TAP badge; a dashed pink stretch with one diamond per tap): tap {confirm} that many times before the hit. Each tap adds damage and all of them make a Perfect, but stop there: one tap too many is a miss, like a wrong press.\n\nArcane Surge is the exception, her single-target spell: tap as fast as you can, every tap adds damage and extra taps are fine.\n\nHer Concentrate Ability doubles AP recharge for a while (the AP meter shows it).",
		func(): _set_party(["mage"]))
	_goal(7, "The Mage",
		"Choose Attack at the Mage's COM, then walk her into range ({move}) before ACT: Fire reaches 4.5 m, the other spells 3 m.",
		"Attack with the Mage",
		func(): return _stat("combos_mage") >= 1,
		func():
			_soon("mage")
			_top_up_ap(80.0))
	_note(7, "The Cleric",
		"The Cleric keeps the party alive with Healing, Shielding and Full Cure, and Haste makes an ally's turns come sooner.\n\nShe can still fight up close: Bash costs 10 AP, every Bash that lands raises the party's max AP, and each Bash in a row hits a little harder.\n\nHer Divine Barrier is a HOLD move too: a Perfect let-go gives a bigger barrier over a wider circle.",
		func(): _set_party(["cleric"]))
	_goal(7, "The Cleric",
		"Healing, Shielding, Haste or Full Cure: any of them counts.",
		"Use one of the Cleric's Abilities",
		func(): return _stat("skills_cleric") >= 1,
		func():
			_soon("cleric")
			_top_up_ap(80.0))

	# 8. Max AP
	_note(8, "Max AP",
		"AP is shared by the whole party and recharges over time. Every Perfect and every Parry raises max AP for the rest of the fight, up to 100 per party member plus 100, and never past 500. The meter grows a new coloured segment for every 100, and a bigger max recharges faster (up to twice as fast).\n\nMiss a timed hit or a Parry and the party loses all its AP, and max AP drops back to 100. Skipping a timed hit is safe: it just lands as a normal hit.",
		func(): _set_party(["knight"]))
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
		# Keep the Golem on the Knight: using Taunt yourself here would
		# otherwise swap in a 3-turn Taunt, and when it ran out the Golem
		# turned to someone else and the lesson could never finish.
		if not golem.statuses.has("taunt") or golem.statuses["taunt"]["caster"] != knight \
				or int(golem.statuses["taunt"]["turns"]) < 50:
			golem.add_status("taunt", 99, knight)
		# If its cast was lost (it was stunned or hit out of it), show it again.
		if golem.loaded_def == null and not golem.hold and golem.timeline_pos < battle.cast_zone_start - 2.0:
			_golem_show("Long Strike")
		# Once the Knight is in the line but hidden, let the Golem strike.
		if golem.hold and golem.skill_revealed and golem.attack_range.contains(knight.global_position, knight.body_radius) \
				and not battle._can_see(golem, knight):
			golem.hold = false
			golem.hold_at = -1.0

	# 10. Special enemy skills (later enemies; the Training Golem doesn't use them)
	_note(10, "Special skills",
		"Later enemies have skills marked UNAVOIDABLE. Those can't be dodged, Parried or Defended: their circles and lines follow their targets until they land, and they just deal their damage. What matters is answering them:\n- Red sphere over everyone: spread out, so circles don't overlap\n- Arrows pointing inward: stack up, to share the damage\n- A circle on one person: they should stand alone\n\nGetting the answer wrong means taking more damage than you had to.")
	_note(10, "Stagger",
		"Most of them can be broken, though. A skill marked STAGGER IT shows a gold Stagger bar under the enemy's HP and on the timeline. Damage you deal from in front of it fills the bar (Smash-type moves, breaking moves and Arts count 1.5x).\n\nFill it and the enemy is STAGGERED: the skill breaks (a few change into something weaker instead), it goes back to the start of the timeline, and it takes +25% damage until its next turn.\n\nMoves that fill the bar are tagged STAGGER or STAGGERS in the menu. Healing Ritual and growing circles show their own rules as the same bar.")
	_note(10, "Special skills",
		"Some other things to watch for:\n- Some skills leave fire or spikes on the ground for a few turns\n- Growing circles get bigger over the cast: hit the sprites circling their edge (one hit each) to stop them, or run to the side it can't reach\n- A healing enemy can be interrupted with three hits from up close\n- An orange sphere means a follow-up will hit you for sure\n\nThe Boss Rush introduces them one at a time.")
	_note(10, "Drops",
		"Some arenas have drops: holes and edges marked by a glowing red line lined with skulls. Regular enemies knocked or pulled over one fall out of the fight. Red arrows on an enemy's area show which way it will throw or drag you, so mind what's behind you.\n\nIt works on enemies too: knock a regular enemy into a hole to end the fight sooner (bosses hold on).\n\nGo over a drop yourself (walking, pushed or pulled) and you teeter: {parry} as the ring turns gold to catch yourself. After a save you're Off-Balance for 3 turns: going over again in that time is a fall.\n\nPushed or pulled by an enemy? {defend} as it strikes to brace: the move is half as long (for classes that can Block).")

	# 11. The Assassin: positioning and Marks
	_note(11, "The Assassin",
		"One more class: the Assassin. He can't Block or Parry, and most of his damage depends on WHERE he stands: behind an enemy means within 60 degrees of its back (the side away from its nose).\n\nSmall enemies like Goblins and Kobolds have no back to find: their ring is a full violet circle, and every hit counts as from behind.\n\nEnemies turn to face whoever they're after. The Golem is Taunted by the Knight now, so it keeps facing the Knight and leaves its back open. In real fights, the Knight's Taunt does exactly this for the Assassin.",
		func():
			_golem_rest()
			_set_party(["knight", "assassin"])  # the Knight's Taunt keeps the Golem's back turned
			if assassin != null and battle.party.has(assassin):
				assassin.global_position = knight.global_position + Vector3(2.5, 0.0, 0.0)
				battle._keep_in_arena(assassin)
				battle._set_controlled(assassin)
			golem.add_status("taunt", 99, knight))
	_goal(11, "Get behind",
		"Choose Attack at the Assassin's COM, then walk round to the Golem's back before ACT. While you steer the Assassin, every enemy has a ring on the floor: the arrow is its front, and the violet arc is its back, glowing when you stand in it. Stab deals 1.5x from behind, and FROM BEHIND pops up when it counts.",
		"Hit the Golem from behind",
		func(): return _stat("behind_hits") >= 1,
		func():
			_top_up_ap(100.0)
			golem.add_status("taunt", 99, knight)
			if assassin.timeline_pos < 55.0:
				assassin.timeline_pos = 55.0)
	_goal(11, "Shadowstep",
		"Walking round takes time, and ACT doesn't wait. Shadowstep teleports the Assassin behind its target, then strikes, and deals 1.5x if it started in FRONT. Moves after it on the combo bar land from behind. Its timings are random, but the first move of a combo always comes in the middle or late part of its box.",
		"Use Shadowstep",
		func(): return _stat("shadowsteps") >= 1,
		func():
			_top_up_ap(100.0)
			if assassin.timeline_pos < 55.0:
				assassin.timeline_pos = 55.0)
	_note(11, "Assassin's Marks",
		"Marks sit on enemies (up to 4): you see MARK x3 over the enemy and violet diamonds by its timeline icon. Ways to add them:\n- Backstab from behind: 2x damage and a Mark (from the front it always misses)\n- Death Sentence (Abilities): 3 Marks at once\n- Every 3rd Stab on a Marked enemy adds one")
	_goal(11, "Assassin's Marks",
		"Build up Marks on the Golem.",
		"Put 4 Marks on the Golem",
		func(): return golem.marks >= 4,
		func():
			_top_up_ap(100.0)
			if assassin.timeline_pos < 55.0:
				assassin.timeline_pos = 55.0)
	_note(11, "Spending Marks",
		"Marks are what the Assassin spends:\n- Execute: 4x from behind, +15% per Mark it spends, and 15 AP cheaper per Mark on its target (it fits the Assassin's bar from 4 Marks). It uses them all up\n- Auto-parry: while any Mark is out, the Assassin parries strikes by himself, spending one\n- Hook stops an enemy's move (and uses its Marks); Shadow Cloak turns them into a shield\n\nVanish makes enemies lose track of the Assassin until he attacks.")
	_goal(11, "Execute",
		"Finish the job: Execute the Golem from behind: 4x damage, more for every Mark it spends.",
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

	# 12. The Monk: build the bar, then cash out
	_note(12, "The Monk",
		"The last class: the Monk. Weak alone, he builds his bar up over a fight, then spends it all at once.\n\nHis bar starts at 30 AP and climbs in steps: 50, 80, 100. Every CLIMB Art (Knee Smash, Triple Rush, Mountain Crusher) raises it one step, whichever step he's on. On his turn, pips over his head show the steps he's climbed, and the same pips sit by his timeline icon. He spends party AP like everyone else.\n\nPunch and Kick have no timing: their hits land by themselves (the small ticks on the bar). His heavy moves and Arts are where the timing is.",
		func():
			_golem_rest()
			golem.statuses.erase("taunt")
			golem.set_marks(0)
			_set_party(["monk"])
			if monk != null:
				monk.global_position = golem.global_position + Vector3(0.0, 0.0, golem.body_radius + monk.body_radius + 0.5)
				battle._keep_in_arena(monk))
	_goal(12, "Climb a step",
		"At 30, only Knee Smash fits: Kick + Heavy Kick (a HOLD move). Play it, Perfect or not: the step comes either way, and a \"STEP 1\" banner shows it.",
		"Climb a step with Knee Smash",
		func(): return monk != null and monk.combo_limit >= 50,
		func():
			_soon("monk")
			_top_up_ap(100.0))
	_note(12, "Tokens",
		"Played with EVERY timing Perfect, an Art also leaves a TOKEN for later: Knee Smash leaves Rush, Palm Strike (Punch + Punch) Triple, Flash Kick (Kick + Kick) Mountain. Tokens stay until an Art uses them up, and each one used up adds 10% damage.\n\nUnder the bar, a preview tells you what the Art at the end does: the tokens it uses, the step it climbs to, and what a Perfect adds. Once a timing isn't Perfect, that last part greys out.\n\nThe bar also shows the steps still to climb, past its end.")
	_goal(12, "Climb to the top",
		"From 50, pick the climb Art that fits the turn:\n- Triple Rush (Palm Strike + Knee Smash): ignores Defense, uses Triple and Rush\n- Mountain Crusher (Heavy Punch + Flash Kick + Knee Smash): hits everyone around the target\n- Knee Smash: the cheapest",
		"Climb to bar 100",
		func(): return monk != null and monk.combo_limit >= 100,
		func():
			_soon("monk")
			_top_up_ap(100.0))
	steps[-1]["tick"] = func():
		if battle.active == null:
			_soon("monk")
			_top_up_ap(100.0)
	_note(12, "Cash out",
		"At the top, a climb Art played all Perfect earns CROWD CHEER. With it, Tortoise Special (Heavy Punch + Heavy Kick + Headbutt) cashes out the whole climb: 1.5x damage at bar 80, 2.5x at 100. Then the bar drops back to 30 and the climb starts over.\n\nIt ends in a Headbutt, and moves after a Headbutt go on a fresh bar, after a short READY.\n\nThe crowd is on your side today: the Monk has Crowd Cheer.",
		func():
			if monk != null:
				monk.tokens["Crowd Cheer"] = 1
				monk.combo_limit = maxf(monk.combo_limit, 100.0))
	_goal(12, "Cash out",
		"Heavy Punch, Heavy Kick, Headbutt: watch the bar drop back to 30 when it lands.",
		"Cash out with Tortoise Special",
		func(): return _stat("monk_cashouts") >= 1,
		func():
			if monk != null:
				monk.tokens["Crowd Cheer"] = 1
				monk.combo_limit = maxf(monk.combo_limit, 80.0)
			_soon("monk")
			_top_up_ap(100.0))
	_note(12, "Risks and tanking",
		"Mistakes cost the Monk: an avoidable hit or a Parry pressed too early drops his bar a step and takes his newest token (Crowd Cheer last). A missed timing only takes the token: the climb holds. Deep Breath heals him and gives a lost step back.\n\nHe can tank ONE enemy for a while: Provoke makes it come for him, and each Parry meanwhile gives Rush; a Suplex counter gives Mountain. The Knight is still the better tank: their Taunt holds every enemy nearby, and while it lasts, allies close to them share their Block and Parry.")

	# 13. Free practice
	_note(13, "Free practice",
		"That's everything! For the final test, the Knight, Archer, Mage and Cleric fight the Training Golem together, and it can be defeated.\n\nWith a full party, {swap} switches who you steer; only {swap} changes it. A member whose COM comes up takes over for the menu, then control goes back to whoever you were steering. The others move on their own: they stay out of danger, stand near their attack range, stack up or spread out when an enemy skill calls for it, and after you choose Attack for them, walk to their target by themselves.\n\nEsc pauses; quit to the menu from there, where the Boss Rush is waiting.",
		func():
			_set_party(["knight", "archer", "mage", "cleric"])
			_practice = true
			golem.statuses.erase("taunt")
			golem.forced_skill = null
			golem.hold = false
			golem.hold_at = -1.0
			golem.cannot_fall = false
			golem.hp = golem.max_hp)
	_goal(13, "Free practice",
		"Everything you've learned works here. The Golem picks its skills at random again.",
		"Defeat the Training Golem (optional)",
		func(): return golem.is_down)
