class_name FigureAnim
extends Node
## Animates a figure (Figure for the party, EnemyFigure for the enemies) by
## turning its joints: Head, ArmL, ArmR, LegL, LegR and Tail under the Body
## (four-legged figures add LegBL, LegBR and WingL, WingR; a held weapon
## can turn at the wrist: WeapR, WeapL), plus a lean and a step of the Body
## itself. All in code, smooth, no rig.
##
## The figure's style (meta "figure_style") changes the idle and the moves:
## "biped", "quad" (walks on four legs, flaps its wings, bites), "float"
## (bobs in the air, darts at you) and "wall" (Gale Maw: breathes, leans).
## Enemies also wind up while they prepare a skill, or raise a guard while
## they hold a Defense or Counter stance.
##
## Always on: breathing (idle) and a walk cycle that follows how fast the
## fighter actually moves. On top, one action at a time, started with
## play(): "attack" (each hit; the class decides the swing, the move can
## make it a kick), "hit" / "hit_heavy", "defend", "parry", "cast",
## "item", "victory" (held until something else plays).
##
## Poses are joint offsets in degrees ({"ArmR": Vector3(-80, 0, 0)}), plus
## "lean" (the Body's turn, degrees) and "step" (the Body moved, metres;
## -Z is forward). X turns: negative swings an arm or leg forward and up,
## and tips a head or the body back; positive tips them forward.

var fighter: Combatant
var body: Node3D
var joints := {}
var rest := {}
var body_rest := Vector3.ZERO

var _time := 0.0
var _walk_phase := 0.0
var _walk := 0.0
var _last_pos := Vector3.ZERO
var _action := ""
var _action_t := 0.0
var _action_len := 0.0
var _wind := {}
var _strike := {}
var _side := 1.0  # alternates for two-handed classes (Assassin, Monk)
var _style := "biped"
var _ready_w := 0.0  # enemies: how far into the wind-up / guard pose
var _fly_from := Vector3.ZERO  # fly_in(): where it came from (world)
var _fly_t := -1.0
const FLY_SECONDS := 0.6

# Move sequences (MoveAnims): the one playing, where it is, the pose it
# started from, whether it waits at the impact for the hit (anticipation),
# and what's queued after it (AI turns land every hit at once).
var _seq := {}
var _seq_key := ""
var _seq_t := 0.0
var _seq_from := {}
var _seq_hold := false
var _seq_hold_left := 0.0
var _seq_pose_now := {}
var _queue: Array = []
var _gap := 0.0  # metres to the target's edge, for dashes
var _seq_speed := 1.0  # >1: a follow-through squeezed to fit before the next hit
var _built := false  # started early: the build-up pose comes first
var _build_from := -0.3  # where the build-up began (negative sequence time)
var _pending: Array = []  # [seq, key, gap, seconds until its hit]
var _trails: Array[WeaponTrail] = []
var _ghost_left := 0.0
# Enchant: a few faint motes in the element's colour at each weapon tip.
var _enchant_motes: Array[CPUParticles3D] = []
var _enchant_element := ""
const GHOST_EVERY := 0.05
## Rapid punches on top of whatever else plays (Tortoise Special's taps):
## each arm's punch time, -1 when it's back in guard.
var _flurry := {"ArmL": -1.0, "ArmR": -1.0}
var _flurry_next := "ArmR"
const FLURRY_PUNCH := 0.13


## Sets up the animator on a fighter whose figure was built.
static func attach(c: Combatant) -> FigureAnim:
	var anim := FigureAnim.new()
	anim.name = "FigureAnim"
	anim.fighter = c
	anim.body = c.get_node("Body")
	for j in ["Head", "ArmL", "ArmR", "LegL", "LegR", "Tail", "LegBL", "LegBR", "WingL", "WingR", "WeapR", "WeapL"]:
		var node := anim.body.find_child(j, true, false) as Node3D
		if node:
			anim.joints[j] = node
			anim.rest[j] = node.rotation_degrees
	anim.body_rest = anim.body.position
	c.add_child(anim)
	# Weapon trails, where the figure marks a weapon's base and tip.
	for pair in [["TrailBase", "TrailTip"], ["TrailBase2", "TrailTip2"]]:
		var b := anim.body.find_child(pair[0], true, false) as Node3D
		var t := anim.body.find_child(pair[1], true, false) as Node3D
		if b and t:
			var trail := WeaponTrail.make(b, t, c.color.lightened(0.55))
			c.add_child(trail)
			anim._trails.append(trail)
	return anim


func _ready() -> void:
	_style = String(fighter.get_meta("figure_style", "biped"))
	_last_pos = fighter.global_position
	_time = randf() * 10.0  # not everyone breathes in step


## One hit of a party attack or Art with its own sequence (MoveAnims).
## Returns false if the move has none (the caller plays the basic swing).
## queued: after whatever is playing (an AI turn lands all hits at once).
## If the same hit was anticipated, the held wind-up is let go.
func play_move(move: Dictionary, hit: int, target: Node3D, queued := false) -> bool:
	var seq := MoveAnims.sequence(fighter.class_id, String(move.get("name", "")), hit)
	if seq.is_empty():
		return false
	var key := "%s#%d" % [move.get("name", ""), hit]
	if queued and not _seq.is_empty():
		_queue.append([seq, key, _gap_to(target)])
		return true
	if key == _seq_key and _seq_hold:
		_seq_hold = false
		_seq_t = maxf(_seq_t, float(seq["impact"]))
		return true
	_pending = []
	_start_seq(seq, key, _gap_to(target), maxf(float(seq["impact"]) - 0.07, 0.0))
	return true


## The build-up of a hit that lands in `until` seconds (the combo bar's
## block): the figure coils into the move's build-up pose and holds it, then
## winds up and waits at the impact for play_move() of that hit. A long
## block shows a long build-up. If the previous hit's follow-through is
## still playing, it's sped up to end within half the time left, and the
## build-up takes the rest, so every move fits its block.
func anticipate(move: Dictionary, hit: int, target: Node3D, until: float) -> void:
	var seq := MoveAnims.sequence(fighter.class_id, String(move.get("name", "")), hit)
	if seq.is_empty() or fighter.is_down:
		return
	var key := "%s#%d" % [move.get("name", ""), hit]
	if key == _seq_key and _seq_hold:
		return
	var gap := _gap_to(target)
	if not _seq.is_empty() and not _seq_hold and _seq_t > float(_seq["impact"]):
		var left := float(_seq["len"]) - _seq_t
		var follow := minf(left, until * 0.45)
		if follow > 0.03:
			_seq_speed = left / follow
			_pending = [seq, key, gap, until]
			return
	_begin_build(seq, key, gap, until)


func _begin_build(seq: Dictionary, key: String, gap: float, until: float) -> void:
	var impact := float(seq["impact"])
	_start_seq(seq, key, gap, impact - until)  # negative: before the move's own keys
	_built = until > impact
	_build_from = _seq_t
	_seq_hold = true
	_seq_hold_left = until + 0.5  # never stuck waiting


func _start_seq(seq: Dictionary, key: String, gap: float, at: float) -> void:
	_seq_from = _seq_pose_now.duplicate()
	_seq = seq
	_seq_key = key
	_seq_t = at
	_seq_hold = false
	_seq_speed = 1.0
	_built = false
	_gap = gap
	if _action == "attack":
		_action = ""


## The pose a build-up coils into and holds: the sequence's "build" pose, or
## its first key.
func _build_pose() -> Dictionary:
	if _seq.has("build"):
		return _seq["build"]
	return (_seq["keys"] as Array)[0][1]


func _gap_to(target: Node3D) -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	var off := target.global_position - fighter.global_position
	off.y = 0.0
	var r := (target as Combatant).body_radius if target is Combatant else 0.5
	return clampf(off.length() - fighter.body_radius - r - 0.25, 0.0, 4.0)


## The sequence's pose at time t: eased between its keys, starting from
## the pose it began in and ending at rest (spins end facing forward).
func _seq_pose(t: float) -> Dictionary:
	if _built and t < 0.0:
		# The build-up: into the coiled pose within 0.3 s, then held.
		var w := _ease((t - _build_from) / minf(0.3, -_build_from))
		return _mix(_seq_from, _build_pose(), w)
	var keys: Array = [[0.0, _build_pose() if _built else _seq_from]] + (_seq["keys"] as Array)
	var last: Dictionary = keys[keys.size() - 1][1]
	var end := {}
	for k in last:
		# Full turns stay turned (a spin, a twirl): it ends where it started.
		if k != "dash" and k != "step":
			var v := Vector3(last[k])
			end[k] = Vector3(roundf(v.x / 360.0), roundf(v.y / 360.0), roundf(v.z / 360.0)) * 360.0
	keys.append([float(_seq["len"]), end])
	var i := 0
	while i < keys.size() - 2 and t >= float(keys[i + 1][0]):
		i += 1
	var span := maxf(float(keys[i + 1][0]) - float(keys[i][0]), 0.0001)
	return _mix(keys[i][1], keys[i + 1][1], _ease((t - float(keys[i][0])) / span))


func _mix(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var out := {}
	for k in a.keys() + b.keys():
		if out.has(k):
			continue
		if k == "dash":
			out[k] = lerpf(float(a.get(k, 0.0)), float(b.get(k, 0.0)), w)
		else:
			out[k] = Vector3(a.get(k, Vector3.ZERO)).lerp(Vector3(b.get(k, Vector3.ZERO)), w)
	return out


func _tick_seq(delta: float) -> void:
	if _seq.is_empty():
		_seq_pose_now = {}
		return
	var impact := float(_seq["impact"])
	if _seq_hold and _seq_t >= impact:
		_seq_t = impact
		_seq_hold_left -= delta
		if _seq_hold_left <= 0.0:
			_seq_hold = false
	else:
		_seq_t += delta * _seq_speed
	if not _pending.is_empty():
		_pending[3] = float(_pending[3]) - delta
	# A queued hit starts once this one has landed (AI turns).
	var next_ready := not _queue.is_empty() and _seq_t > impact + 0.1
	if _seq_t >= float(_seq["len"]) or next_ready:
		if not _pending.is_empty():
			var p: Array = _pending
			_pending = []
			_seq_pose_now = _seq_pose(float(_seq["len"]))
			_begin_build(p[0], p[1], p[2], maxf(float(p[3]), 0.0))
			_seq_pose_now = _seq_pose(_seq_t)
			return
		if _queue.is_empty():
			_seq = {}
			_seq_key = ""
			_seq_pose_now = {}
			return
		var q: Array = _queue.pop_front()
		_seq_pose_now = _seq_pose(minf(_seq_t, float(_seq["len"])))
		_start_seq(q[0], q[1], q[2], maxf(float(q[0]["impact"]) - 0.08, 0.0))
	_seq_pose_now = _seq_pose(_seq_t)
	# Afterimages (dashes).
	if _seq.get("ghost", false):
		_ghost_left -= delta
		if _ghost_left <= 0.0:
			_ghost_left = GHOST_EVERY
			_spawn_ghost()


## While an Enchant is on (statuses "enchant_<element>"), its colour drifts
## off the weapon tips (TrailTip / TrailTip2; else the hands), very lightly.
func _tick_enchant() -> void:
	var element := ""
	if not fighter.is_down:
		for e in ["fire", "ice", "lightning", "energy"]:
			if fighter.statuses.has("enchant_" + e):
				element = e
				break
	if element == _enchant_element:
		return
	_enchant_element = element
	if _enchant_motes.is_empty() and element != "":
		var anchors: Array[Node3D] = []
		for name in ["TrailTip", "TrailTip2"]:
			var tip := body.find_child(name, true, false) as Node3D
			if tip:
				anchors.append(tip)
		if anchors.is_empty():
			for arm in ["ArmR", "ArmL"]:
				if joints.has(arm):
					var hand := Node3D.new()
					hand.position = Vector3(0, -0.45, -0.05)
					(joints[arm] as Node3D).add_child(hand)
					anchors.append(hand)
		for anchor in anchors:
			var motes := CPUParticles3D.new()
			motes.amount = 10
			motes.lifetime = 0.7
			motes.local_coords = false  # they trail behind a swing
			motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			motes.emission_sphere_radius = 0.08
			motes.direction = Vector3.UP
			motes.spread = 60.0
			motes.initial_velocity_min = 0.1
			motes.initial_velocity_max = 0.3
			motes.gravity = Vector3(0, 0.25, 0)
			motes.scale_amount_min = 0.6
			motes.scale_amount_max = 1.0
			var quad := QuadMesh.new()
			quad.size = Vector2(0.1, 0.1)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.vertex_color_use_as_albedo = true
			quad.material = mat
			motes.mesh = quad
			var fade := Gradient.new()
			fade.set_color(0, Color(1, 1, 1, 0.75))
			fade.set_color(1, Color(1, 1, 1, 0.0))
			motes.color_ramp = fade
			anchor.add_child(motes)
			_enchant_motes.append(motes)
	var colors := {"fire": SpellFx.FIRE, "ice": SpellFx.ICE, "lightning": SpellFx.LIGHTNING, "energy": SpellFx.ENERGY}
	for motes in _enchant_motes:
		motes.emitting = element != ""
		if element != "":
			motes.color = Color(colors[element]).lightened(0.25)


## A fading see-through copy of the figure where it is now.
func _spawn_ghost() -> void:
	var holder := fighter.get_parent()
	if holder == null:
		return
	var ghost := body.duplicate() as Node3D
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(fighter.color.lightened(0.3), 0.45)
	for node in [ghost] + ghost.find_children("*", "MeshInstance3D", true, false):
		if node is MeshInstance3D:
			(node as MeshInstance3D).material_override = mat
			(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ghost)
	ghost.global_transform = body.global_transform
	var fade := ghost.create_tween()
	fade.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	fade.tween_callback(ghost.queue_free)


## One rapid punch (a tap of Tortoise Special), the other arm from the last.
## Once the sequence passes its build-up into the wind-up, the winding arm
## ("windup_hand") is drawing back for the last blow: the other one punches.
func flurry_punch() -> void:
	var winding := String(_seq.get("windup_hand", "")) if _seq_t >= 0.0 else ""
	if _flurry_next == winding:
		_flurry_next = "ArmL" if winding == "ArmR" else "ArmR"
	_flurry[_flurry_next] = 0.0
	if winding == "":
		_flurry_next = "ArmL" if _flurry_next == "ArmR" else "ArmR"


## Starts an action. `move` is the attack's move (a kick, a spell).
func play(action: String, move: Dictionary = {}) -> void:
	_action = action
	_action_t = 0.0
	_wind = {}
	_strike = {}
	match action:
		"attack":
			_attack_poses(move)
			_action_len = 0.38
		"hit":
			_strike = {"Head": Vector3(-14, 0, 0), "ArmL": Vector3(18, 0, -14), "ArmR": Vector3(18, 0, 14), "lean": Vector3(-10, 0, 0), "step": Vector3(0, 0, 0.08)}
			_action_len = 0.32
		"hit_heavy":
			_strike = {"Head": Vector3(-25, 0, 0), "ArmL": Vector3(35, 0, -35), "ArmR": Vector3(35, 0, 35), "LegL": Vector3(-15, 0, 0), "lean": Vector3(-22, 0, 0), "step": Vector3(0, -0.04, 0.2)}
			_action_len = 0.55
		"defend":
			if fighter.class_id == "knight":
				_strike = {"ArmL": Vector3(-80, 35, 10), "ArmR": Vector3(-20, 0, 0), "lean": Vector3(6, 0, 0)}
			else:
				_strike = {"ArmL": Vector3(-95, 0, 35), "ArmR": Vector3(-95, 0, -35), "Head": Vector3(10, 0, 0), "lean": Vector3(8, 0, 0)}
			_action_len = 0.6
		"parry":
			_wind = {"ArmR": Vector3(20, 0, 20)}
			_strike = {"ArmR": Vector3(-110, 0, -45), "lean": Vector3(0, -18, 0), "step": Vector3(0, 0, -0.08)}
			_action_len = 0.4
		"cast":
			var own := MoveAnims.ability(fighter.class_id, String(move.get("name", "")))
			if not own.is_empty():
				_action = ""
				_pending = []
				_queue.clear()
				_start_seq(own, "ability", _gap_to(move.get("_target")), 0.0)
				return
			_wind = {"ArmR": Vector3(-60, 0, 0)}
			_strike = {"ArmR": Vector3(-165, 0, 0), "ArmL": Vector3(-40, 0, -20), "Head": Vector3(-12, 0, 0), "lean": Vector3(-6, 0, 0)}
			_action_len = 0.8
		"item":
			_strike = {"ArmR": Vector3(-125, 0, 30), "Head": Vector3(-25, 0, 0), "lean": Vector3(-4, 0, 0)}
			_action_len = 0.8
		"throw":
			# Gale Maw flinging a Gust Sprite with the paw on that side.
			var paw := "ArmL" if float(move.get("side", 1.0)) < 0.0 else "ArmR"
			_wind = {paw: Vector3(-45, 0, 0)}
			_strike = {paw: Vector3(35, 0, 0), "step": Vector3(0, 0, -0.2)}
			_action_len = 0.7
		"getup":
			# Back up after a knockdown: from a crouch on one knee to standing.
			_action = ""
			_pending = []
			_queue.clear()
			_start_seq({"len": 0.55, "impact": 0.0, "keys": [
				[0.0, {"step": Vector3(0, -0.55, 0), "lean": Vector3(30, 0, 0), "LegL": Vector3(-85, 0, 0), "LegR": Vector3(35, 0, 0), "ArmL": Vector3(-25, 0, -25), "ArmR": Vector3(-25, 0, 25), "Head": Vector3(15, 0, 0)}],
				[0.3, {"step": Vector3(0, -0.15, 0), "lean": Vector3(10, 0, 0), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(10, 0, 0)}],
			]}, "getup", 0.0, 0.0)
			return
		"victory":
			_strike = {"ArmR": Vector3(-170, 0, -10), "ArmL": Vector3(-20, 0, -25), "Head": Vector3(-10, 0, 0)}
			_action_len = -1.0  # held
		_:
			_action = ""


func _attack_poses(move: Dictionary) -> void:
	var name := String(move.get("name", ""))
	_side = -_side
	var r := "ArmR" if _side > 0.0 else "ArmL"
	if fighter.team == Combatant.Team.ENEMY:
		_enemy_attack()
		return
	match fighter.class_id:
		"knight":
			# a slash: sword back over the shoulder, then across and down
			_wind = {"ArmR": Vector3(60, 0, 35), "lean": Vector3(0, 22, 0)}
			_strike = {"ArmR": Vector3(-85, 0, -20), "lean": Vector3(6, -22, 0), "step": Vector3(0, 0, -0.25)}
		"archer":
			# draw to the cheek, loose
			_wind = {"ArmL": Vector3(-85, 0, 0), "ArmR": Vector3(-85, 35, 0)}
			_strike = {"ArmL": Vector3(-88, 0, 0), "ArmR": Vector3(-55, 60, 35), "lean": Vector3(-4, 0, 0)}
		"mage":
			# the staff thrust at the target, the other hand forward
			_wind = {"ArmR": Vector3(-140, 0, 0), "lean": Vector3(-6, 0, 0)}
			_strike = {"ArmR": Vector3(-85, 0, 0), "ArmL": Vector3(-60, 0, 0), "lean": Vector3(8, 0, 0), "step": Vector3(0, 0, -0.1)}
		"cleric":
			# a staff swing
			_wind = {"ArmR": Vector3(-150, 0, 20), "lean": Vector3(0, 15, 0)}
			_strike = {"ArmR": Vector3(-50, 0, -25), "lean": Vector3(8, -15, 0), "step": Vector3(0, 0, -0.15)}
		"assassin":
			# a stab, one hand then the other
			_wind = {r: Vector3(35, 0, 0), "lean": Vector3(0, 15 * _side, 0)}
			_strike = {r: Vector3(-60, 0, 0), "lean": Vector3(10, -15 * _side, 0), "step": Vector3(0, 0, -0.3)}
		"monk":
			if name.contains("Kick") or name.contains("Knee"):
				var leg := "LegR" if _side > 0.0 else "LegL"
				_wind = {leg: Vector3(-30, 0, 0), "lean": Vector3(-6, 0, 0)}
				_strike = {leg: Vector3(-95, 0, 0), "ArmL": Vector3(-30, 0, -20), "ArmR": Vector3(-30, 0, 20), "lean": Vector3(-14, 20 * _side, 0), "step": Vector3(0, 0.05, -0.2)}
			elif name.contains("Headbutt"):
				_wind = {"lean": Vector3(-18, 0, 0), "Head": Vector3(-20, 0, 0)}
				_strike = {"lean": Vector3(22, 0, 0), "Head": Vector3(25, 0, 0), "step": Vector3(0, 0, -0.3)}
			else:
				_wind = {r: Vector3(45, 0, 0), "lean": Vector3(0, 18 * _side, 0)}
				_strike = {r: Vector3(-90, 0, 0), "lean": Vector3(4, -22 * _side, 0), "step": Vector3(0, 0, -0.25)}
		_:
			_strike = {"step": Vector3(0, 0, -0.45)}


## An enemy's strike landing, by style.
func _enemy_attack() -> void:
	match _style:
		"quad":
			_wind = {"Head": Vector3(-25, 0, 0), "lean": Vector3(-8, 0, 0)}
			_strike = {"Head": Vector3(30, 0, 0), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(-30, 0, 0), "WingL": Vector3(0, 0, 35), "WingR": Vector3(0, 0, -35), "lean": Vector3(8, 0, 0), "step": Vector3(0, 0, -0.4)}
		"float":
			_strike = {"Tail": Vector3(30, 0, 0), "lean": Vector3(25, 0, 0), "step": Vector3(0, -0.1, -0.5)}
		"wall":
			# the paws come down on the arena
			_wind = {"ArmL": Vector3(-25, 0, 0), "ArmR": Vector3(-25, 0, 0)}
			_strike = {"ArmL": Vector3(18, 10, 0), "ArmR": Vector3(18, -10, 0), "lean": Vector3(4, 0, 0), "step": Vector3(0, -0.1, -0.3), "Tail": Vector3(0, 15, 0)}
		_:
			# an overhead blow with the weapon arm, the other arm in
			_wind = {"ArmR": Vector3(-150, 0, 10), "ArmL": Vector3(-50, 0, 0), "lean": Vector3(-8, 0, 0)}
			_strike = {"ArmR": Vector3(-40, 0, -10), "ArmL": Vector3(-30, 0, 0), "Head": Vector3(10, 0, 0), "lean": Vector3(14, 0, 0), "step": Vector3(0, 0, -0.3)}
	_action_len = 0.5


## Enemies: the pose held while preparing a skill (a wind-up), or while a
## Defense or Counter stance is up (a guard).
func _ready_pose() -> Dictionary:
	var guard := fighter.loaded_def != null and (fighter.loaded_def.kind == Skills.Kind.DEFENSE or fighter.loaded_def.kind == Skills.Kind.COUNTER)
	match _style:
		"quad":
			return {"Head": Vector3(-20, 0, 0), "WingL": Vector3(0, 0, 25), "WingR": Vector3(0, 0, -25), "lean": Vector3(-6, 0, 0), "Tail": Vector3(-15, 0, 0)}
		"float":
			return {"step": Vector3(0, 0.15, 0.15), "lean": Vector3(-12, 0, 0)}
		"wall":
			return {"ArmL": Vector3(-30, 15, 0), "ArmR": Vector3(-30, -15, 0), "step": Vector3(0, 0.15, 0.1), "lean": Vector3(-3, 0, 0)}
	if guard:
		return {"ArmL": Vector3(-95, 0, 35), "ArmR": Vector3(-95, 0, -35), "Head": Vector3(10, 0, 0), "lean": Vector3(6, 0, 0)}
	return {"ArmR": Vector3(-130, 0, 15), "ArmL": Vector3(-35, 0, -10), "lean": Vector3(-6, 0, 0)}


func _process(delta: float) -> void:
	_tick_enchant()
	if fighter.is_down or fighter.get_node_or_null("Limp") != null:
		_action = ""
		_seq = {}
		_queue.clear()
		_seq_pose_now = {}
		for trail in _trails:
			trail.emitting = false
		_last_pos = fighter.global_position
		return
	_time += delta
	if _fly_t >= 0.0:
		_fly_t += delta
		_last_pos = fighter.global_position  # the flight isn't walking
	# Walking: how fast the fighter is really moving (steered, AI or pushed).
	var moved := fighter.global_position - _last_pos
	moved.y = 0.0
	_last_pos = fighter.global_position
	var speed := moved.length() / maxf(delta, 0.0001)
	var target := clampf(speed / 4.0, 0.0, 1.0) if speed > 0.3 and speed < 30.0 else 0.0
	_walk = move_toward(_walk, target, delta * 6.0)
	_walk_phase += moved.length() * 4.5
	var pose := _base_pose()
	# A move's sequence.
	_tick_seq(delta)
	for key in _seq_pose_now:
		if key == "dash":
			var step := Vector3(pose.get("step", Vector3.ZERO))
			step.z -= float(_seq_pose_now[key]) * _gap / maxf(body.scale.z, 0.01)
			pose["step"] = step
		else:
			pose[key] = Vector3(pose.get(key, Vector3.ZERO)) + Vector3(_seq_pose_now[key])
	for trail in _trails:
		trail.emitting = not _seq.is_empty() and _seq.get("trail", false)
	# Enemies preparing a skill: the wind-up (or guard) pose, eased in.
	if fighter.team == Combatant.Team.ENEMY:
		var preparing := fighter.loaded_skill != Skills.NONE and fighter.loaded_def != null
		_ready_w = move_toward(_ready_w, 1.0 if preparing else 0.0, delta * 3.0)
		if _ready_w > 0.0:
			var rp := _ready_pose()
			var w := _ease(_ready_w)
			for key in rp:
				pose[key] = Vector3(pose.get(key, Vector3.ZERO)) + Vector3(rp[key]) * w
	# Rapid punches (one per tap), arms taking turns.
	for arm in _flurry:
		if float(_flurry[arm]) < 0.0:
			continue
		if arm == String(_seq.get("windup_hand", "-")) and _seq_t >= 0.0:
			_flurry[arm] = -1.0  # it's drawing back for the last blow
			continue
		_flurry[arm] = float(_flurry[arm]) + delta
		var k := float(_flurry[arm]) / FLURRY_PUNCH
		if k >= 1.0:
			_flurry[arm] = -1.0
			continue
		var w := sin(k * PI)
		var side := -1.0 if arm == "ArmL" else 1.0
		pose[arm] = Vector3(pose.get(arm, Vector3.ZERO)).lerp(Vector3(-95, 0, 6 * side), w)
		pose["lean"] = Vector3(pose.get("lean", Vector3.ZERO)) + Vector3(3, -16 * side, 0) * w
	# The action on top.
	if _action != "":
		_action_t += delta
		var w := _weights()
		if w.x < 0.0:
			_action = ""
		else:
			for key in _wind.keys() + _strike.keys():
				var v := Vector3(_wind.get(key, Vector3.ZERO)) * w.x + Vector3(_strike.get(key, Vector3.ZERO)) * w.y
				pose[key] = Vector3(pose.get(key, Vector3.ZERO)) + v
	_apply(pose)


## Wind-up and strike weights for the action's time (x, y); x < 0: done.
func _weights() -> Vector2:
	var t := _action_t
	if _action_len < 0.0:
		return Vector2(0.0, _ease(minf(t / 0.25, 1.0)))  # held (victory)
	if t >= _action_len:
		return Vector2(-1.0, 0.0)
	var wind_end := 0.06 if not _wind.is_empty() else 0.0
	var hit_at := wind_end + 0.07
	if t < wind_end:
		return Vector2(_ease(t / wind_end), 0.0)
	if t < hit_at:
		var k := _ease((t - wind_end) / (hit_at - wind_end))
		return Vector2(1.0 - k if wind_end > 0.0 else 0.0, k)
	var hold := hit_at + (_action_len - hit_at) * 0.35
	if t < hold:
		return Vector2(0.0, 1.0)
	return Vector2(0.0, 1.0 - _ease((t - hold) / (_action_len - hold)))


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Breathing, the walk cycle, ears and tail sway.
func _base_pose() -> Dictionary:
	var breathe := sin(_time * 2.0)
	var stride := sin(_walk_phase) * _walk
	var bob := absf(cos(_walk_phase)) * _walk
	match _style:
		"float":
			return {
				"Tail": Vector3(sin(_time * 3.0) * 15.0, sin(_time * 2.2) * 25.0, 0),
				"lean": Vector3(8.0 * _walk + sin(_time * 1.3) * 4.0, 0, sin(_time * 1.7) * 6.0),
				"step": Vector3(0, sin(_time * 2.6) * 0.12, 0),
			}
		"wall":
			# Gale Maw: a slow breath; its paws drift and bob on their own.
			return {
				"Tail": Vector3(0, sin(_time * 0.6) * 4.0, sin(_time * 0.9) * 3.0),
				"ArmL": Vector3(sin(_time * 0.8) * 4.0, sin(_time * 0.5) * 5.0, sin(_time * 1.1) * 3.0),
				"ArmR": Vector3(sin(_time * 0.9 + 1.5) * 4.0, sin(_time * 0.6 + 1.0) * 5.0, sin(_time * 1.0 + 2.0) * 3.0),
				"lean": Vector3(breathe * 0.6, 0, 0),
				"step": Vector3(0, breathe * 0.04, 0),
			}
		"quad":
			return {
				"Head": Vector3(breathe * 3.0 + bob * 5.0, sin(_time * 0.7) * 10.0 * (1.0 - _walk), 0),
				"LegL": Vector3(-stride * 30.0, 0, 0),
				"LegR": Vector3(stride * 30.0, 0, 0),
				"LegBL": Vector3(stride * 30.0, 0, 0),
				"LegBR": Vector3(-stride * 30.0, 0, 0),
				"WingL": Vector3(0, 0, sin(_time * 3.0) * 8.0 + bob * 20.0),
				"WingR": Vector3(0, 0, -sin(_time * 3.0) * 8.0 - bob * 20.0),
				"Tail": Vector3(sin(_time * 1.3) * 4.0, sin(_time * 1.8) * 12.0 + stride * 15.0, 0),
				"step": Vector3(0, breathe * 0.02 + bob * 0.06, 0),
			}
	return {
		"Head": Vector3(breathe * 1.5 + bob * 4.0, sin(_time * 0.7) * 4.0 * (1.0 - _walk), 0),
		"ArmL": Vector3(stride * 28.0, 0, -2.0 - breathe * 1.5),
		"ArmR": Vector3(-stride * 28.0, 0, 2.0 + breathe * 1.5),
		"LegL": Vector3(-stride * 34.0, 0, 0),
		"LegR": Vector3(stride * 34.0, 0, 0),
		"Tail": Vector3(sin(_time * 1.6) * 5.0, sin(_time * 2.3 + 1.0) * 10.0 + stride * 18.0, 0),
		"lean": Vector3(6.0 * _walk, 0, 0),
		"step": Vector3(0, breathe * 0.008 + bob * 0.05, 0),
	}


func _apply(pose: Dictionary) -> void:
	# Poses read "negative X = forward" (arms and legs swing forward; a
	# head or the whole body tips back): Godot's X turn is the other way.
	var flip := Vector3(-1, 1, 1)
	for j in joints:
		(joints[j] as Node3D).rotation_degrees = Vector3(rest[j]) + Vector3(pose.get(j, Vector3.ZERO)) * flip
	var lean := Vector3(pose.get("lean", Vector3.ZERO)) * flip
	var step := Vector3(pose.get("step", Vector3.ZERO))
	body.rotation_degrees = lean
	# Lean about the feet, not the middle: the feet stay where they were.
	var feet := Vector3(0, -body_rest.y, 0)
	body.position = body_rest + feet - body.basis.orthonormalized() * feet + step * body.scale.x
	if _fly_t >= 0.0:
		var k := minf(_fly_t / FLY_SECONDS, 1.0)
		var start := fighter.to_local(_fly_from) - body_rest
		body.position += start * (1.0 - _ease(k)) + Vector3(0, sin(k * PI) * 2.0, 0)
		body.rotation_degrees.x += (1.0 - k) * 720.0  # tumbling as it flies
		if k >= 1.0:
			_fly_t = -1.0


## Looks only: the figure flies in from `from` (world) to where the fighter
## already stands, in an arc (a Gust Sprite flung by the Gale Maw's paw).
func fly_in(from: Vector3) -> void:
	_fly_from = from
	_fly_t = 0.0


## Back to standing still (revive).
func reset() -> void:
	_action = ""
	_seq = {}
	_queue.clear()
	_pending = []
	_last_pos = fighter.global_position
