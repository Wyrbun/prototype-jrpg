class_name SpellFx
extends RefCounted
## Attack effects built from shapes and particles in code (no art files).
## Fire-and-forget: each effect frees itself, and none of them changes the
## fight (damage lands on the combo's own timing).
##
## Every party hit has two parts, timed to the combo bar:
## - approach(): starts approach_lead() seconds before the hit and ARRIVES
##   exactly when it lands (a fireball in flight, an arrow, a ring closing
##   on the target for melee). battle_arena launches it from the playhead.
## - impact(): the moment the hit lands. A Perfect hit gets a bigger impact
##   with a gold flash, so a well-timed press looks (and feels) better.
## The AI plays its combos at once: impact only.

const FIRE := Color(1.0, 0.45, 0.12)
const ICE := Color(0.55, 0.85, 1.0)
const LIGHTNING := Color(1.0, 0.95, 0.55)
const ENERGY := Color(0.72, 0.45, 1.0)
const PERFECT := Color(1.0, 0.85, 0.25)

## Class colours for the melee and the Archer.
const CLASS_COLORS := {"knight": Color(0.7, 0.85, 1.0), "archer": Color(0.55, 1.0, 0.6), "assassin": Color(0.75, 0.4, 1.0),
		"cleric": Color(1.0, 0.88, 0.45), "monk": Color(1.0, 0.65, 0.3)}
const ELEMENT_OF := {"Fire": "fire", "Ice": "ice", "Lightning": "lightning", "Energy Blast": "energy"}


# --- Timing ------------------------------------------------------------------

## Seconds before the hit its approach starts (0 = none).
static func approach_lead(attacker: Node3D, move: Dictionary) -> float:
	match String(attacker.get("class_id")):
		"mage":
			return 0.28
		"archer":
			return 0.16
		"knight", "assassin", "monk", "cleric":
			return 0.0  # melee: the timing ring on the target is their approach
	return 0.0


## The part before the hit; it arrives `seconds` from now, as the hit lands.
static func approach(parent: Node3D, attacker: Node3D, target: Node3D, move: Dictionary, seconds: float) -> void:
	if not _ok(parent, attacker, target):
		return
	var cls := String(attacker.get("class_id"))
	var from := attacker.global_position + Vector3(0, 1.2, 0)
	var to := _contact(attacker, target)
	var size := _size(move)
	match cls:
		"mage":
			for e in _elements(move):
				match e:
					"fire":
						projectile(parent, from, to, FIRE, 0.28 * size, seconds)
					"energy":
						projectile(parent, from, to, ENERGY, 0.32 * size, seconds)
					"ice":
						shards_rise(parent, target.global_position, size, seconds)
					"lightning":
						charge(parent, Vector3(target.global_position.x, 5.0, target.global_position.z), LIGHTNING, size, seconds)
		"archer":
			arrow(parent, from, to, CLASS_COLORS["archer"], size, seconds)
		_:
			closing_ring(parent, target.global_position, CLASS_COLORS.get(cls, Color.WHITE), 1.6 * size, seconds)


## The moment a party hit lands. perfect: bigger, with a gold flash.
static func impact(parent: Node3D, attacker: Node3D, target: Node3D, move: Dictionary, perfect: bool) -> void:
	if not _ok(parent, attacker, target):
		return
	var cls := String(attacker.get("class_id"))
	var from := attacker.global_position + Vector3(0, 1.2, 0)
	var to := _contact(attacker, target)
	var ground := Vector3(target.global_position.x, 0.0, target.global_position.z)
	var size := _size(move) * (1.35 if perfect else 1.0)
	var facing := to - from
	facing.y = 0.0
	match cls:
		"mage":
			for e in _elements(move):
				match e:
					"fire":
						burst(parent, to, FIRE, 0.75 * size)
						sparks(parent, to, FIRE, 18)
						var dir := facing.normalized()
						for i in 3:
							var at := to + dir * (1.4 * (i + 1))
							_after(parent, 0.06 * (i + 1), func(): burst(parent, at, FIRE.lerp(Color(1, 0.8, 0.3), 0.3), 0.4 * size))
					"energy":
						burst(parent, to, ENERGY, 0.6 * size)
						ring(parent, ground, ENERGY, 2.0 * size)
						sparks(parent, to, ENERGY, 14)
					"ice":
						sparks(parent, ground + Vector3(0, 0.5, 0), ICE, 22)
						ring(parent, ground, ICE, 1.2 * size)
						burst(parent, to, ICE, 0.45 * size)
					"lightning":
						bolt(parent, target.global_position, size)
		"archer":
			burst(parent, to, CLASS_COLORS["archer"], 0.35 * size)
			sparks(parent, to, CLASS_COLORS["archer"], 10)
		"knight":
			slash(parent, to, facing, CLASS_COLORS["knight"], 1.1 * size, -35.0)
			sparks(parent, to, Color.WHITE, 10)
			if float(move.get("knockback", 0.0)) > 0.0:
				ring(parent, ground, CLASS_COLORS["knight"], 2.2 * size)
		"assassin":
			slash(parent, to, facing, CLASS_COLORS["assassin"], 0.9 * size, -45.0)
			_after(parent, 0.05, func(): slash(parent, to, facing, CLASS_COLORS["assassin"], 0.9 * size, 45.0))
		"cleric":
			burst(parent, to, CLASS_COLORS["cleric"], 0.5 * size)
			ring(parent, ground, CLASS_COLORS["cleric"], 1.4 * size)
		"monk":
			punch_wave(parent, to, facing, CLASS_COLORS["monk"], size)
			sparks(parent, to, CLASS_COLORS["monk"], 12)
	if perfect:
		ring(parent, ground, PERFECT, 2.6 * size)
		sparks(parent, to + Vector3(0, 0.3, 0), PERFECT, 20)
		burst(parent, to, PERFECT, 0.35 * size)


# --- Timing rings ----------------------------------------------------------------

## A press hit's timing ring on its target: a fixed gold ring (the timing
## box) and a white ring closing in on the body at a steady speed, reaching
## the gold one as the box opens and the body as the hit lands. `until`:
## seconds to the hit; `window`: the box's length; `lead`: the full approach.
static func timing_ring(parent: Node3D, target: Node3D, until: float, window: float, lead: float) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = Vector3(target.global_position.x, 0.14, target.global_position.z)
	var base := (float(target.get("body_radius")) if target.get("body_radius") != null else 0.5) + 0.2
	var per_second := 3.2 / maxf(lead, 0.1)
	var box_r := base + per_second * window
	var box := _thin_ring(box_r, Color(1.0, 0.85, 0.3, 0.85), 0.07)
	holder.add_child(box)
	# The box as a gold band on the floor (body to box ring): press while
	# the closing ring is over it.
	var band := _thin_ring((base + box_r) / 2.0, Color(1.0, 0.8, 0.25, 0.28), maxf((box_r - base) / 2.0, 0.08))
	holder.add_child(band)
	var closing := _thin_ring(base + per_second * until, Color(1.0, 1.0, 1.0, 0.9), 0.06)
	holder.add_child(closing)
	holder.set_meta("closing", closing)
	var torus: TorusMesh = closing.mesh
	var t := holder.create_tween()
	t.tween_method(func(r: float):
		torus.inner_radius = maxf(r - 0.06, 0.01)
		torus.outer_radius = r + 0.06, base + per_second * until, base, until)
	t.tween_callback(holder.queue_free)
	return holder


## The press was judged: the rings flash gold (Perfect) or red, then go.
static func timing_ring_done(holder, perfect: bool) -> void:
	if not is_instance_valid(holder):
		return  # (already gone: the hit landed)
	var color := PERFECT if perfect else Color(1.0, 0.3, 0.25)
	for child in holder.get_children():
		var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
		mat.albedo_color = Color(color, 1.0)
	var t: Tween = holder.create_tween()
	t.tween_property(holder, "scale", Vector3(1.15, 1.0, 1.15), 0.12)
	t.tween_callback(holder.queue_free)


static func _thin_ring(radius: float, color: Color, half_width: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - half_width, 0.01)
	torus.outer_radius = radius + half_width
	torus.rings = 48
	node.mesh = torus
	node.material_override = _glow(color, color.a)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.scale = Vector3(1.0, 0.25, 1.0)
	return node


# --- Enemy hits ----------------------------------------------------------------

## An enemy strike lands on a party member (at the strike's own moment):
## result "hit" (a burst in the skill's colour, bigger for heavy blows),
## "parry" (a gold flash: the satisfying one) or "defend" (a blue guard flash).
static func enemy_hit(parent: Node3D, enemy: Node3D, target: Node3D, color: Color, heavy: bool, result: String) -> void:
	if not _ok(parent, enemy, target):
		return
	var at := _contact(enemy, target)
	var ground := Vector3(target.global_position.x, 0.0, target.global_position.z)
	match result:
		"parry":
			burst(parent, at, PERFECT, 0.5)
			sparks(parent, at, PERFECT, 26)
			ring(parent, ground, PERFECT, 2.2)
			var facing := target.global_position - enemy.global_position
			facing.y = 0.0
			slash(parent, at, facing, PERFECT, 0.8, 90.0)
		"defend":
			burst(parent, at, Color(0.55, 0.8, 1.0), 0.55)
			ring(parent, ground, Color(0.55, 0.8, 1.0), 1.2)
			sparks(parent, at, Color(0.8, 0.9, 1.0), 10)
		_:
			var size := 1.5 if heavy else 1.0
			burst(parent, at, color.lerp(Color(1, 0.3, 0.2), 0.4), 0.45 * size)
			sparks(parent, at, Color(1.0, 0.85, 0.75), 12 if heavy else 8)
			if heavy:
				ring(parent, ground, color, 1.6)


## A big enemy blow lands: a shockwave on the ground round the enemy
## (Rock Stomp, Maw Bite, Smashes), once per strike.
static func enemy_blow(parent: Node3D, enemy: Node3D, color: Color, radius: float) -> void:
	if parent == null or not is_instance_valid(enemy):
		return
	var ground := Vector3(enemy.global_position.x, 0.0, enemy.global_position.z)
	ring(parent, ground, color, radius)
	_after(parent, 0.08, func(): ring(parent, ground, color.lerp(Color.WHITE, 0.4), radius * 0.6))


## Its Stagger bar broke: a gold burst on the enemy.
static func stagger(parent: Node3D, enemy: Node3D) -> void:
	if parent == null or not is_instance_valid(enemy):
		return
	var radius := float(enemy.get("body_radius")) if enemy.get("body_radius") != null else 0.6
	var at := enemy.global_position + Vector3(0, 1.2, 0)
	burst(parent, at, PERFECT, radius + 0.6)
	sparks(parent, at, PERFECT, 30)
	ring(parent, Vector3(at.x, 0.0, at.z), PERFECT, radius + 2.5)


# --- Heals, shields, pushes ------------------------------------------------------

## Healed: green motes rising round the fighter and a soft glow.
static func heal(parent: Node3D, who: Node3D) -> void:
	if parent == null or not is_instance_valid(who) or not parent.is_inside_tree():
		return
	var green := Color(0.45, 1.0, 0.55)
	var at := who.global_position
	ring(parent, Vector3(at.x, 0.0, at.z), green, 1.3)
	burst(parent, at + Vector3(0, 1.0, 0), green, 0.6)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 18
	p.lifetime = 0.9
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_radius = 0.6
	p.emission_ring_inner_radius = 0.3
	p.emission_ring_height = 0.1
	p.emission_ring_axis = Vector3.UP
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 2.5
	p.gravity = Vector3.ZERO
	var bit := SphereMesh.new()
	bit.radius = 0.07
	bit.height = 0.14
	bit.material = _glow(green.lerp(Color.WHITE, 0.3), 1.0)
	p.mesh = bit
	parent.add_child(p)
	p.global_position = at + Vector3(0, 0.2, 0)
	p.emitting = true
	_after(parent, 1.4, p.queue_free)


## Shielded: a pale blue bubble that pops up round the fighter and fades.
static func shield(parent: Node3D, who: Node3D) -> void:
	if parent == null or not is_instance_valid(who) or not parent.is_inside_tree():
		return
	var blue := Color(0.55, 0.8, 1.0)
	var mat := _glow(blue, 0.45)
	var bubble := _sphere(1.0, mat)
	parent.add_child(bubble)
	bubble.global_position = who.global_position + Vector3(0, 1.0, 0)
	bubble.scale = Vector3.ONE * 0.4
	var t := bubble.create_tween().set_parallel(true)
	t.tween_property(bubble, "scale", Vector3.ONE * 1.1, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.5).set_delay(0.2)
	t.chain().tween_callback(bubble.queue_free)


## Knocked back or pulled: puffs of dust along the way it's sent.
static func dust(parent: Node3D, who: Node3D, dir: Vector3, meters: float) -> void:
	if parent == null or not is_instance_valid(who) or not parent.is_inside_tree() or meters <= 0.2:
		return
	var start := Vector3(who.global_position.x, 0.15, who.global_position.z)
	var puffs := clampi(roundi(meters / 0.8), 2, 8)
	for i in puffs:
		var at := start + dir * (meters * float(i) / puffs)
		_after(parent, 0.04 * i, func(): _puff(parent, at))


static func _puff(parent: Node3D, at: Vector3) -> void:
	var mat := _glow(Color(0.8, 0.76, 0.68), 0.55)
	var ball := _sphere(0.35, mat)
	parent.add_child(ball)
	ball.global_position = at
	ball.scale = Vector3(0.5, 0.35, 0.5)
	var t := ball.create_tween().set_parallel(true)
	t.tween_property(ball, "scale", Vector3(1.1, 0.6, 1.1), 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(ball, "global_position:y", 0.45, 0.35)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	t.chain().tween_callback(ball.queue_free)


static func _ok(parent: Node3D, attacker: Node3D, target: Node3D) -> bool:
	return parent != null and is_instance_valid(attacker) and is_instance_valid(target) and parent.is_inside_tree()


## Where a hit meets the target: its near side, at chest height (bursts in
## its middle would hide inside the body).
static func _contact(attacker: Node3D, target: Node3D) -> Vector3:
	var from := attacker.global_position + Vector3(0, 1.2, 0)
	var to := target.global_position + Vector3(0, 0.9, 0)
	var toward := from - to
	toward.y = 0.0
	if toward.length() > 0.01 and target.get("body_radius") != null:
		to += toward.normalized() * minf(float(target.get("body_radius")) * 0.9, toward.length() * 0.5)
	return to


## Arts and finishers look bigger than single moves.
static func _size(move: Dictionary) -> float:
	if move.get("finisher", false):
		return 2.2
	return 1.6 if move.has("recipe") else 1.2


## The Mage's elements in a move: its own, or each one in an Art's recipe.
static func _elements(move: Dictionary) -> Array:
	var out: Array = []
	if move.has("recipe"):
		for part in move["recipe"]:
			var e: String = ELEMENT_OF.get(part, "")
			if e != "" and not out.has(e):
				out.append(e)
	elif move.has("element"):
		out.append(String(move["element"]))
	return out


# --- Building blocks --------------------------------------------------------

## A glowing ball from one point to another, arriving in `seconds`.
static func projectile(parent: Node3D, from: Vector3, to: Vector3, color: Color, radius: float, seconds: float) -> void:
	var ball := _sphere(radius, _glow(color, 1.0))
	parent.add_child(ball)
	ball.global_position = from
	ball.add_child(_trail(color))
	var t := ball.create_tween()
	t.tween_property(ball, "global_position", to, seconds)
	t.tween_callback(ball.queue_free)


## An arrow (a thin glowing shaft) flying to the target in `seconds`.
static func arrow(parent: Node3D, from: Vector3, to: Vector3, color: Color, size: float, seconds: float) -> void:
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.06, 0.9) * size
	shaft.mesh = box
	shaft.material_override = _glow(color.lerp(Color.WHITE, 0.4), 1.0)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shaft)
	shaft.global_position = from
	if from.distance_to(to) > 0.01:
		shaft.look_at(to, Vector3.UP)
	shaft.add_child(_trail(color))
	var t := shaft.create_tween()
	t.tween_property(shaft, "global_position", to, seconds)
	t.tween_callback(shaft.queue_free)


## A ring on the ground closing in on the target, gone as the hit lands:
## melee timing at a glance.
static func closing_ring(parent: Node3D, at: Vector3, color: Color, radius: float, seconds: float) -> void:
	var node := _torus(_glow(color, 0.75))
	parent.add_child(node)
	node.global_position = Vector3(at.x, 0.1, at.z)
	node.scale = Vector3(radius, 0.12, radius)
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector3(0.35, 0.12, 0.35), seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(node.queue_free)


## Ice shards rising round a point, peaking as the hit lands, then shattering.
static func shards_rise(parent: Node3D, at: Vector3, size: float, seconds: float) -> void:
	var ground := Vector3(at.x, 0.0, at.z)
	var count := 7
	for i in count:
		var angle := TAU * i / count + randf() * 0.3
		var spot := ground + Vector3(cos(angle), 0.0, sin(angle)) * 0.8 * size
		var shard := MeshInstance3D.new()
		var prism := CylinderMesh.new()
		prism.top_radius = 0.0
		prism.bottom_radius = 0.13 * size
		prism.height = 0.9 * size
		prism.radial_segments = 4
		shard.mesh = prism
		shard.material_override = _glow(ICE, 0.95)
		parent.add_child(shard)
		shard.global_position = spot + Vector3(0, -0.5 * size, 0)
		shard.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
		var t := shard.create_tween()
		t.tween_property(shard, "global_position:y", 0.4 * size, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(shard, "scale", Vector3(1.6, 0.1, 1.6), 0.12)
		t.tween_callback(shard.queue_free)


## A glow gathering at a point (lightning above its target), full as the hit lands.
static func charge(parent: Node3D, at: Vector3, color: Color, size: float, seconds: float) -> void:
	var ball := _sphere(0.45 * size, _glow(color, 0.8))
	parent.add_child(ball)
	ball.global_position = at
	ball.scale = Vector3.ONE * 0.1
	var t := ball.create_tween()
	t.tween_property(ball, "scale", Vector3.ONE, seconds).set_ease(Tween.EASE_IN)
	t.tween_callback(ball.queue_free)


## A jagged bolt dropping from above onto a point, with a flash.
static func bolt(parent: Node3D, at: Vector3, size: float) -> void:
	var top := Vector3(at.x, 9.0, at.z)
	var bottom := Vector3(at.x, 0.1, at.z)
	var points: Array[Vector3] = [top]
	var steps := 7
	for i in range(1, steps):
		var p := top.lerp(bottom, float(i) / steps)
		points.append(p + Vector3(randf_range(-0.55, 0.55), 0.0, randf_range(-0.55, 0.55)))
	points.append(bottom)
	var node := Node3D.new()
	parent.add_child(node)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.1 * size, 0.1 * size, a.distance_to(b))
		seg.mesh = box
		seg.material_override = _glow(Color.WHITE.lerp(LIGHTNING, 0.4), 1.0)
		node.add_child(seg)
		seg.global_position = (a + b) / 2.0
		seg.look_at(b, Vector3.RIGHT if absf((b - a).normalized().y) > 0.99 else Vector3.UP)
	var t := node.create_tween()
	t.tween_interval(0.12)
	t.tween_property(node, "scale", Vector3(0.2, 1.0, 0.2), 0.12)
	t.tween_callback(node.queue_free)
	burst(parent, bottom + Vector3(0, 0.6, 0), LIGHTNING, 0.7 * size)
	sparks(parent, bottom + Vector3(0, 0.4, 0), LIGHTNING, 16)


## A blade arc sweeping across a point, facing along `facing`; tilt rolls it
## (degrees): -35 a rising slash, +45 the other diagonal.
static func slash(parent: Node3D, at: Vector3, facing: Vector3, color: Color, size: float, tilt: float) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _arc_mesh(0.9, 0.12, 140.0)
	var mat := _glow(color.lerp(Color.WHITE, 0.3), 0.95)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.global_position = at
	if facing.length() > 0.01:
		node.look_at(at + facing.normalized(), Vector3.UP)
	node.rotate_object_local(Vector3.FORWARD, deg_to_rad(tilt))
	node.scale = Vector3.ONE * size
	var start := node.rotation
	node.rotate_object_local(Vector3.FORWARD, deg_to_rad(-60.0))
	var t := node.create_tween().set_parallel(true)
	t.tween_property(node, "rotation", start, 0.1)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.22).set_delay(0.06)
	t.chain().tween_callback(node.queue_free)


## A punch: a ring facing the target that bursts outward from the hit.
static func punch_wave(parent: Node3D, at: Vector3, facing: Vector3, color: Color, size: float) -> void:
	var node := _torus(_glow(color, 0.9))
	parent.add_child(node)
	node.global_position = at
	if facing.length() > 0.01:
		node.look_at(at + facing.normalized(), Vector3.UP)
	node.rotate_object_local(Vector3.RIGHT, PI / 2.0)  # the ring stands facing the target
	node.scale = Vector3(0.2, 0.2, 0.2)
	var mat: StandardMaterial3D = node.material_override
	var t := node.create_tween().set_parallel(true)
	t.tween_property(node, "scale", Vector3(0.9, 0.2, 0.9) * size, 0.18).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	t.chain().tween_callback(node.queue_free)
	burst(parent, at, color, 0.3 * size)


## A bright ball that swells and fades.
static func burst(parent: Node3D, at: Vector3, color: Color, radius: float) -> void:
	var mat := _glow(color, 0.85)
	var ball := _sphere(radius, mat)
	parent.add_child(ball)
	ball.global_position = at
	ball.scale = Vector3.ONE * 0.3
	var t := ball.create_tween().set_parallel(true)
	t.tween_property(ball, "scale", Vector3.ONE, 0.22).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	t.chain().tween_callback(ball.queue_free)


## A flat ring on the ground that spreads out and fades (shockwave, frost).
static func ring(parent: Node3D, at: Vector3, color: Color, radius: float) -> void:
	var mat := _glow(color, 0.9)
	var node := _torus(mat)
	parent.add_child(node)
	node.global_position = at + Vector3(0, 0.12, 0)
	node.scale = Vector3(0.2, 0.15, 0.2)
	var t := node.create_tween().set_parallel(true)
	t.tween_property(node, "scale", Vector3(radius, 0.15, radius), 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	t.chain().tween_callback(node.queue_free)


## A one-shot puff of small glowing bits.
static func sparks(parent: Node3D, at: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var bit := SphereMesh.new()
	bit.radius = 0.06
	bit.height = 0.12
	bit.material = _glow(color, 1.0)
	p.mesh = bit
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	_after(parent, 1.0, p.queue_free)


static func _sphere(radius: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	node.mesh = sphere
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _torus(mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	node.mesh = torus
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## A flat curved band (a blade's swing) in the local XY plane, facing -Z.
static func _arc_mesh(radius: float, width: float, degrees: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 16
	var half := deg_to_rad(degrees) / 2.0
	for i in steps:
		var a0 := -half + 2.0 * half * i / steps
		var a1 := -half + 2.0 * half * (i + 1) / steps
		# Thinner at the tips, like a blade's trail.
		var w0 := width * sin(PI * float(i) / steps)
		var w1 := width * sin(PI * float(i + 1) / steps)
		var o0 := Vector3(sin(a0), cos(a0), 0) * (radius + w0)
		var i0 := Vector3(sin(a0), cos(a0), 0) * radius
		var o1 := Vector3(sin(a1), cos(a1), 0) * (radius + w1)
		var i1 := Vector3(sin(a1), cos(a1), 0) * radius
		for v in [i0, o0, o1, i0, o1, i1]:
			st.add_vertex(v - Vector3(0, radius * 0.5, 0))
	return st.commit()


static func _trail(color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.25
	p.local_coords = false
	p.direction = Vector3.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.4
	p.gravity = Vector3.ZERO
	var bit := SphereMesh.new()
	bit.radius = 0.08
	bit.height = 0.16
	bit.material = _glow(color, 0.7)
	p.mesh = bit
	return p


static func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var c := color
	c.a = alpha
	mat.albedo_color = c
	return mat


## Runs a function after a delay, on the parent's tree.
static func _after(parent: Node3D, seconds: float, fn: Callable) -> void:
	if not parent.is_inside_tree():
		return
	parent.get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(parent) and fn.is_valid():  # (its node may be gone already)
			fn.call())
