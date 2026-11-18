class_name Figure
extends RefCounted
## Low-poly class figures (PS1 style) built from simple shapes, so each class
## reads at a glance: the Knight's helmet and shield, and so on. The parts go
## under the fighter's Body node, so everything that moves the Body (lunges,
## the knocked-out pose, ragdolls) moves the whole figure. The Body keeps its
## class-colour material (read for the HUD); it's drawn as the torso.
##
## Coordinates are the Body's: its centre is 0.9 m up, the feet at y -0.9,
## the figure faces -Z, its right hand is +X.

const PS1_SHADER := preload("res://shaders/ps1.gdshader")

const STEEL := Color(0.5, 0.53, 0.6)
const DARK_STEEL := Color(0.27, 0.29, 0.34)
const LEATHER := Color(0.42, 0.27, 0.16)
const GOLD := Color(0.92, 0.74, 0.3)
const BLACK := Color(0.06, 0.06, 0.08)
const SKIN := Color(0.93, 0.75, 0.6)
const WOOD := Color(0.45, 0.3, 0.18)
const WHITE := Color(0.9, 0.9, 0.93)
const CLOTH_DARK := Color(0.15, 0.14, 0.2)
const RED := Color(0.75, 0.18, 0.14)
const BOOT := Color(0.26, 0.17, 0.1)

static var _materials := {}


## The wobble of every PS1 material (the screen filter sets it: 0 is none).
static var _snap_lines := 320.0


static func set_snap_lines(lines: float) -> void:
	_snap_lines = lines
	for m in _materials.values():
		(m as ShaderMaterial).set_shader_parameter("snap_lines", lines)


## A shared PS1 material for one colour.
static func material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = PS1_SHADER
		m.set_shader_parameter("albedo", color)
		m.set_shader_parameter("snap_lines", _snap_lines)
		_materials[key] = m
	return _materials[key]


## Height of each class, as a scale of the 1.9 m base figure: shortest to
## tallest, Cleric, Knight, Mage, Assassin, Archer, Monk. Looks only: reach
## and body size in the fight don't change.
const HEIGHTS := {"cleric": 0.78, "knight": 0.86, "mage": 0.95, "assassin": 1.0, "archer": 1.07, "monk": 1.15}


## Gives this fighter its class figure (the party classes). Returns false if
## the class has none (it keeps its capsule).
static func build(c: Combatant) -> bool:
	var body := c.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return false
	var main := c.color
	var parts: Array = []
	var torso: Array = []
	match c.class_id:
		"knight":
			# Rabbit, beige fur, lop ears out from under an open-faced helm.
			var fur := Color(0.86, 0.74, 0.56)
			torso = ["cyl", 0.3, 0.25, 0.62, 6, Vector3(0, 0.12, 0)]
			parts = _head(fur, Color(0.97, 0.92, 0.82), "rabbit") + [
				# legs and boots
				["box", Vector3(0.17, 0.5, 0.19), Vector3(-0.12, -0.6, 0), Vector3.ZERO, DARK_STEEL],
				["box", Vector3(0.17, 0.5, 0.19), Vector3(0.12, -0.6, 0), Vector3.ZERO, DARK_STEEL],
				["box", Vector3(0.19, 0.12, 0.3), Vector3(-0.12, -0.84, -0.05), Vector3.ZERO, BLACK],
				["box", Vector3(0.19, 0.12, 0.3), Vector3(0.12, -0.84, -0.05), Vector3.ZERO, BLACK],
				# skirt of mail, belt, a gold trim down the tabard, a cotton tail
				["cyl", 0.27, 0.3, 0.2, 6, Vector3(0, -0.27, 0), Vector3.ZERO, STEEL],
				["cyl", 0.27, 0.27, 0.07, 6, Vector3(0, -0.17, 0), Vector3.ZERO, LEATHER],
				["box", Vector3(0.07, 0.5, 0.05), Vector3(0, 0.1, -0.27), Vector3.ZERO, GOLD],
				["joint", "Tail", Vector3(0, -0.3, 0.24), [
					["ball", 0.11, 6, Vector3(0, -0.3, 0.3), Vector3.ZERO, Color(0.98, 0.96, 0.92)],
				]],
				# arms and pauldrons
				["box", Vector3(0.13, 0.46, 0.14), Vector3(-0.36, 0.08, 0), Vector3(0, 0, -6), DARK_STEEL],
				["box", Vector3(0.13, 0.46, 0.14), Vector3(0.36, 0.08, -0.04), Vector3(-25, 0, 6), DARK_STEEL],
				["ball", 0.16, 6, Vector3(-0.34, 0.38, 0), Vector3.ZERO, STEEL],
				["ball", 0.16, 6, Vector3(0.34, 0.38, 0), Vector3.ZERO, STEEL],
				# open-faced helm: a dome cap, a nose guard, the plume
				["oval", Vector3(0.2, 0.14, 0.21), 8, Vector3(0, 0.8, 0.01), Vector3.ZERO, STEEL],
				["cyl", 0.205, 0.205, 0.05, 8, Vector3(0, 0.765, 0.01), Vector3.ZERO, DARK_STEEL],
				["box", Vector3(0.07, 0.14, 0.18), Vector3(0, 0.98, 0.04), Vector3.ZERO, main],
				# kite shield on the left arm, in the class colour with a gold cross
				["box", Vector3(0.07, 0.62, 0.44), Vector3(-0.5, 0.0, -0.12), Vector3(0, -12, 0), main],
				["box", Vector3(0.08, 0.5, 0.07), Vector3(-0.51, 0.02, -0.13), Vector3(0, -12, 0), GOLD],
				["box", Vector3(0.08, 0.07, 0.34), Vector3(-0.51, 0.1, -0.13), Vector3(0, -12, 0), GOLD],
				# sword in the right hand, held up and forward (WeapR: the wrist)
				["subj", "WeapR", Vector3(0.38, -0.16, -0.12), Vector3(-55, 0, 0), [
					["box", Vector3(0.07, 0.2, 0.07), Vector3(0, 0, 0), Vector3.ZERO, LEATHER],
					["box", Vector3(0.28, 0.05, 0.07), Vector3(0, 0.12, 0), Vector3.ZERO, GOLD],
					["box", Vector3(0.06, 0.72, 0.025), Vector3(0, 0.5, 0), Vector3.ZERO, STEEL],
					["mark", "TrailBase", Vector3(0, 0.2, 0)],
					["mark", "TrailTip", Vector3(0, 0.86, 0)],
				]],
			]
		"archer":
			# Bear, brown fur, a tan muzzle; tall and sturdy, hood down.
			var fur := Color(0.47, 0.3, 0.17)
			var hood := main.darkened(0.3)
			torso = ["cyl", 0.3, 0.26, 0.6, 6, Vector3(0, 0.12, 0)]
			parts = _head(fur, Color(0.76, 0.6, 0.42), "bear") + [
				["box", Vector3(0.17, 0.5, 0.19), Vector3(-0.12, -0.6, 0), Vector3.ZERO, LEATHER],
				["box", Vector3(0.17, 0.5, 0.19), Vector3(0.12, -0.6, 0), Vector3.ZERO, LEATHER],
				["box", Vector3(0.19, 0.18, 0.28), Vector3(-0.12, -0.81, -0.03), Vector3.ZERO, BOOT],
				["box", Vector3(0.19, 0.18, 0.28), Vector3(0.12, -0.81, -0.03), Vector3.ZERO, BOOT],
				["cyl", 0.28, 0.33, 0.22, 6, Vector3(0, -0.27, 0), Vector3.ZERO, main],
				["cyl", 0.275, 0.275, 0.06, 6, Vector3(0, -0.15, 0), Vector3.ZERO, LEATHER],
				["box", Vector3(0.13, 0.44, 0.14), Vector3(-0.36, 0.08, -0.04), Vector3(-20, 0, -6), main],
				["box", Vector3(0.13, 0.44, 0.14), Vector3(0.36, 0.08, 0), Vector3(0, 0, 6), main],
				["ball", 0.085, 6, Vector3(-0.38, -0.15, -0.14), Vector3.ZERO, fur],
				["ball", 0.085, 6, Vector3(0.38, -0.17, 0), Vector3.ZERO, fur],
				# hood down around the shoulders, and a short cape
				["cyl", 0.25, 0.3, 0.12, 6, Vector3(0, 0.44, 0.02), Vector3.ZERO, hood],
				["box", Vector3(0.36, 0.2, 0.14), Vector3(0, 0.44, 0.24), Vector3(-15, 0, 0), hood],
				["box", Vector3(0.5, 0.62, 0.05), Vector3(0, 0.05, 0.3), Vector3(8, 0, 0), hood],
				# quiver on the back, red-feathered arrows
				["sub", Vector3(0.16, 0.12, 0.34), Vector3(0, 0, -20), [
					["cyl", 0.08, 0.07, 0.55, 6, Vector3.ZERO, Vector3.ZERO, LEATHER],
					["box", Vector3(0.035, 0.16, 0.035), Vector3(-0.03, 0.33, 0), Vector3.ZERO, RED],
					["box", Vector3(0.035, 0.18, 0.035), Vector3(0.03, 0.34, 0.02), Vector3.ZERO, RED],
					["box", Vector3(0.035, 0.14, 0.035), Vector3(0.0, 0.32, -0.03), Vector3.ZERO, WHITE],
				]],
				# long bow in the left hand, tips curving back toward her
				["subj", "WeapL", Vector3(-0.42, -0.12, -0.26), Vector3(0, 0, 8), [
					["box", Vector3(0.06, 0.15, 0.07), Vector3.ZERO, Vector3.ZERO, LEATHER],
					["box", Vector3(0.045, 0.52, 0.05), Vector3(0, 0.3, 0.05), Vector3(20, 0, 0), WOOD],
					["box", Vector3(0.045, 0.52, 0.05), Vector3(0, -0.3, 0.05), Vector3(-20, 0, 0), WOOD],
					["box", Vector3(0.012, 1.08, 0.012), Vector3(0, 0, 0.14), Vector3.ZERO, WHITE],
				]],
			]
		"mage":
			# Goat, cream fur, horns swept back, long purple hair.
			var fur := Color(0.92, 0.89, 0.83)
			var hair := Color(0.72, 0.42, 0.86)
			var hat := main.darkened(0.35)
			torso = ["cyl", 0.24, 0.27, 0.55, 6, Vector3(0, 0.15, 0)]
			parts = _head(fur, Color(0.98, 0.96, 0.92), "goat") + [
				["cyl", 0.27, 0.44, 0.78, 8, Vector3(0, -0.5, 0), Vector3.ZERO, main],
				["cyl", 0.445, 0.445, 0.05, 8, Vector3(0, -0.865, 0), Vector3.ZERO, GOLD],
				["cyl", 0.275, 0.275, 0.06, 6, Vector3(0, -0.12, 0), Vector3.ZERO, GOLD],
				["cyl", 0.07, 0.13, 0.45, 6, Vector3(-0.32, 0.08, 0), Vector3(0, 0, -8), main],
				["cyl", 0.07, 0.13, 0.45, 6, Vector3(0.33, 0.06, -0.06), Vector3(-25, 0, 8), main],
				["ball", 0.07, 6, Vector3(-0.35, -0.18, 0), Vector3.ZERO, fur],
				["ball", 0.07, 6, Vector3(0.38, -0.12, -0.16), Vector3.ZERO, fur],
				# long purple hair: down the back, a fringe at the front
				["box", Vector3(0.38, 0.56, 0.13), Vector3(0, 0.48, 0.13), Vector3.ZERO, hair],
				["box", Vector3(0.34, 0.07, 0.06), Vector3(0, 0.74, -0.15), Vector3.ZERO, hair],
				# horns sweeping back from under the brim
				["sub", Vector3(-0.15, 0.78, -0.04), Vector3(0, -30, 40), _horn()],
				["sub", Vector3(0.15, 0.78, -0.04), Vector3(0, 30, -40), _horn()],
				# pointed hat with a gold band, its tip flopping back
				["cyl", 0.37, 0.37, 0.035, 8, Vector3(0, 0.81, 0), Vector3.ZERO, hat],
				["cyl", 0.195, 0.2, 0.06, 8, Vector3(0, 0.85, 0), Vector3.ZERO, GOLD],
				["cyl", 0.0, 0.19, 0.55, 8, Vector3(0, 1.12, 0.06), Vector3(14, 0, 0), hat],
				# staff with a glowing orb (WeapR: turns at the wrist)
				["subj", "WeapR", Vector3(0.38, -0.12, -0.16), Vector3(-8, 0, 0), [
					["cyl", 0.03, 0.03, 1.5, 6, Vector3(0, 0.25, 0), Vector3.ZERO, WOOD],
					["cyl", 0.08, 0.03, 0.14, 6, Vector3(0, 0.98, 0), Vector3.ZERO, GOLD],
					["ball", 0.1, 6, Vector3(0, 1.1, 0), Vector3.ZERO, Color(0.55, 0.92, 1.0)],
					["mark", "TrailBase", Vector3(0, 0.75, 0)],
					["mark", "TrailTip", Vector3(0, 1.15, 0)],
				]],
			]
		"cleric":
			# Squirrel, red-brown fur, crusader mail and surcoat over her robe,
			# a nasal helm with her ear tufts poking out, a big curled tail.
			var fur := Color(0.78, 0.42, 0.18)
			torso = ["cyl", 0.25, 0.27, 0.55, 6, Vector3(0, 0.15, 0)]
			parts = _head(fur, Color(0.97, 0.9, 0.78), "squirrel") + [
				["cyl", 0.27, 0.4, 0.78, 8, Vector3(0, -0.5, 0), Vector3.ZERO, WHITE],
				["cyl", 0.405, 0.405, 0.05, 8, Vector3(0, -0.865, 0), Vector3.ZERO, GOLD],
				["cyl", 0.275, 0.275, 0.06, 6, Vector3(0, -0.12, 0), Vector3.ZERO, LEATHER],
				# mail at the shoulders and arms, a white surcoat with a gold cross
				["cyl", 0.2, 0.3, 0.14, 6, Vector3(0, 0.4, 0), Vector3.ZERO, STEEL],
				["box", Vector3(0.4, 0.5, 0.05), Vector3(0, 0.12, -0.25), Vector3.ZERO, WHITE],
				["box", Vector3(0.07, 0.36, 0.06), Vector3(0, 0.12, -0.27), Vector3.ZERO, GOLD],
				["box", Vector3(0.26, 0.07, 0.06), Vector3(0, 0.2, -0.27), Vector3.ZERO, GOLD],
				["cyl", 0.07, 0.11, 0.45, 6, Vector3(-0.32, 0.08, 0), Vector3(0, 0, -8), STEEL],
				["cyl", 0.07, 0.11, 0.45, 6, Vector3(0.33, 0.06, -0.06), Vector3(-25, 0, 8), STEEL],
				["ball", 0.07, 6, Vector3(-0.35, -0.18, 0), Vector3.ZERO, fur],
				["ball", 0.07, 6, Vector3(0.38, -0.12, -0.16), Vector3.ZERO, fur],
				# nasal helm
				["oval", Vector3(0.195, 0.15, 0.2), 8, Vector3(0, 0.8, 0.01), Vector3.ZERO, STEEL],
				["cyl", 0.2, 0.2, 0.045, 8, Vector3(0, 0.76, 0.01), Vector3.ZERO, GOLD],
				["box", Vector3(0.04, 0.13, 0.04), Vector3(0, 0.7, -0.2), Vector3.ZERO, STEEL],
				# the tail: a big fluffy curl up her back
				["joint", "Tail", Vector3(0, -0.5, 0.28), [
					["oval", Vector3(0.15, 0.2, 0.15), 6, Vector3(0, -0.55, 0.38), Vector3(-40, 0, 0), fur],
					["oval", Vector3(0.19, 0.24, 0.19), 6, Vector3(0, -0.3, 0.52), Vector3(-15, 0, 0), fur],
					["oval", Vector3(0.21, 0.25, 0.2), 6, Vector3(0, -0.02, 0.58), Vector3.ZERO, fur],
					["oval", Vector3(0.2, 0.23, 0.19), 6, Vector3(0, 0.25, 0.56), Vector3(15, 0, 0), fur],
					["oval", Vector3(0.17, 0.18, 0.16), 6, Vector3(0, 0.48, 0.47), Vector3(40, 0, 0), fur],
					["oval", Vector3(0.12, 0.12, 0.12), 6, Vector3(0, 0.62, 0.36), Vector3.ZERO, Color(0.97, 0.9, 0.78)],
				]],
				# staff topped with a sun disc (WeapR: turns at the wrist)
				["subj", "WeapR", Vector3(0.38, -0.12, -0.16), Vector3(-8, 0, 0), [
					["cyl", 0.03, 0.03, 1.45, 6, Vector3(0, 0.25, 0), Vector3.ZERO, WHITE],
					["cyl", 0.15, 0.15, 0.04, 8, Vector3(0, 1.05, 0), Vector3(90, 0, 0), GOLD],
					["cyl", 0.07, 0.07, 0.05, 6, Vector3(0, 1.05, -0.01), Vector3(90, 0, 0), main],
					["mark", "TrailBase", Vector3(0, 0.7, 0)],
					["mark", "TrailTip", Vector3(0, 1.1, 0)],
				]],
			]
		"assassin":
			# Grey wolf, red eyes, a scar over one eye, ears up through the
			# hood, a bushy tail.
			var fur := Color(0.45, 0.46, 0.5)
			var hood := main.darkened(0.45)
			torso = ["cyl", 0.25, 0.21, 0.58, 6, Vector3(0, 0.12, 0)]
			parts = _head(fur, Color(0.8, 0.8, 0.82), "wolf") + [
				["box", Vector3(0.14, 0.52, 0.16), Vector3(-0.1, -0.6, 0), Vector3.ZERO, CLOTH_DARK],
				["box", Vector3(0.14, 0.52, 0.16), Vector3(0.1, -0.6, 0), Vector3.ZERO, CLOTH_DARK],
				["box", Vector3(0.16, 0.14, 0.25), Vector3(-0.1, -0.83, -0.03), Vector3.ZERO, BLACK],
				["box", Vector3(0.16, 0.14, 0.25), Vector3(0.1, -0.83, -0.03), Vector3.ZERO, BLACK],
				["cyl", 0.22, 0.22, 0.06, 6, Vector3(0, -0.17, 0), Vector3.ZERO, LEATHER],
				["box", Vector3(0.08, 0.36, 0.03), Vector3(0.12, -0.36, 0.23), Vector3(12, 0, 0), main],
				# bushy tail, pale at the tip
				["joint", "Tail", Vector3(0, -0.25, 0.22), [
					["cyl", 0.07, 0.13, 0.5, 6, Vector3(0, -0.42, 0.36), Vector3(-50, 0, 0), fur],
					["ball", 0.075, 6, Vector3(0, -0.6, 0.57), Vector3.ZERO, Color(0.8, 0.8, 0.82)],
				]],
				# arms forward, a dagger in each hand
				["box", Vector3(0.11, 0.44, 0.12), Vector3(-0.3, 0.06, -0.08), Vector3(-32, 0, -4), CLOTH_DARK],
				["box", Vector3(0.11, 0.44, 0.12), Vector3(0.3, 0.06, -0.08), Vector3(-32, 0, 4), CLOTH_DARK],
				["ball", 0.07, 6, Vector3(-0.31, -0.13, -0.2), Vector3.ZERO, BLACK],
				["ball", 0.07, 6, Vector3(0.31, -0.13, -0.2), Vector3.ZERO, BLACK],
				# (WeapL / WeapR: each dagger turns at the wrist)
				["subj", "WeapL", Vector3(-0.31, -0.14, -0.22), Vector3(-80, 0, 0), _dagger() + [
					["mark", "TrailBase2", Vector3(0, 0.1, 0)],
					["mark", "TrailTip2", Vector3(0, 0.37, 0)],
				]],
				["subj", "WeapR", Vector3(0.31, -0.14, -0.22), Vector3(-80, 0, 0), _dagger() + [
					["mark", "TrailBase", Vector3(0, 0.1, 0)],
					["mark", "TrailTip", Vector3(0, 0.37, 0)],
				]],
				# hood (the back of it) and a scarf tail
				["box", Vector3(0.4, 0.42, 0.2), Vector3(0, 0.63, 0.1), Vector3.ZERO, hood],
				["box", Vector3(0.38, 0.06, 0.32), Vector3(0, 0.83, 0.02), Vector3.ZERO, hood],
				["box", Vector3(0.12, 0.55, 0.03), Vector3(0.1, 0.22, 0.26), Vector3(25, 0, 8), main],
			]
		"monk":
			# Snapping turtle: green skin, a hooked beak, a ridged shell on his
			# back over the gi, a spiky tail, clawed feet.
			var skin := Color(0.42, 0.5, 0.3)
			var shell := Color(0.3, 0.27, 0.17)
			var pants := main.darkened(0.2)
			torso = ["cyl", 0.31, 0.25, 0.6, 6, Vector3(0, 0.13, 0)]
			parts = _head(skin, Color(0.75, 0.68, 0.42), "turtle") + [
				# the gi's open neck shows the plastron; a dark red sash
				["box", Vector3(0.16, 0.16, 0.03), Vector3(0, 0.36, -0.27), Vector3(0, 0, 45), Color(0.75, 0.68, 0.42)],
				["cyl", 0.27, 0.27, 0.08, 6, Vector3(0, -0.16, 0), Vector3.ZERO, Color(0.5, 0.12, 0.1)],
				["box", Vector3(0.07, 0.3, 0.03), Vector3(0.18, -0.3, -0.22), Vector3(0, 0, 10), Color(0.5, 0.12, 0.1)],
				# the shell, with a ridge of spikes down the middle
				["oval", Vector3(0.4, 0.46, 0.2), 8, Vector3(0, 0.1, 0.34), Vector3.ZERO, shell],
				["oval", Vector3(0.42, 0.48, 0.08), 8, Vector3(0, 0.1, 0.24), Vector3.ZERO, Color(0.75, 0.68, 0.42)],
				["cyl", 0.0, 0.05, 0.1, 4, Vector3(0, 0.3, 0.52), Vector3(70, 0, 0), shell.darkened(0.3)],
				["cyl", 0.0, 0.05, 0.1, 4, Vector3(0, 0.1, 0.55), Vector3(80, 0, 0), shell.darkened(0.3)],
				["cyl", 0.0, 0.05, 0.1, 4, Vector3(0, -0.1, 0.52), Vector3(95, 0, 0), shell.darkened(0.3)],
				["joint", "Tail", Vector3(0, -0.3, 0.22), [
					["cyl", 0.0, 0.07, 0.4, 5, Vector3(0, -0.45, 0.3), Vector3(120, 0, 0), skin],
				]],
				# baggy trousers, wrapped ankles, clawed feet
				["cyl", 0.12, 0.15, 0.55, 6, Vector3(-0.13, -0.5, 0), Vector3.ZERO, pants],
				["cyl", 0.12, 0.15, 0.55, 6, Vector3(0.13, -0.5, 0), Vector3.ZERO, pants],
				["cyl", 0.1, 0.1, 0.1, 6, Vector3(-0.13, -0.8, 0), Vector3.ZERO, WHITE],
				["cyl", 0.1, 0.1, 0.1, 6, Vector3(0.13, -0.8, 0), Vector3.ZERO, WHITE],
				["box", Vector3(0.16, 0.08, 0.26), Vector3(-0.13, -0.86, -0.05), Vector3.ZERO, skin],
				["box", Vector3(0.16, 0.08, 0.26), Vector3(0.13, -0.86, -0.05), Vector3.ZERO, skin],
				["box", Vector3(0.14, 0.04, 0.05), Vector3(-0.13, -0.88, -0.2), Vector3.ZERO, BLACK],
				["box", Vector3(0.14, 0.04, 0.05), Vector3(0.13, -0.88, -0.2), Vector3.ZERO, BLACK],
				# bare arms, short sleeves, wrapped fists raised
				["box", Vector3(0.17, 0.17, 0.18), Vector3(-0.38, 0.33, 0), Vector3.ZERO, main],
				["box", Vector3(0.17, 0.17, 0.18), Vector3(0.38, 0.33, 0), Vector3.ZERO, main],
				["box", Vector3(0.14, 0.42, 0.15), Vector3(-0.39, 0.08, -0.08), Vector3(-30, 0, 0), skin],
				["box", Vector3(0.14, 0.42, 0.15), Vector3(0.39, 0.08, -0.08), Vector3(-30, 0, 0), skin],
				["box", Vector3(0.16, 0.14, 0.16), Vector3(-0.39, -0.1, -0.2), Vector3.ZERO, WHITE],
				["box", Vector3(0.16, 0.14, 0.16), Vector3(0.39, -0.1, -0.2), Vector3.ZERO, WHITE],
				# headband, prayer beads
				["cyl", 0.172, 0.172, 0.05, 8, Vector3(0, 0.7, 0), Vector3.ZERO, RED],
				["box", Vector3(0.05, 0.18, 0.02), Vector3(0.04, 0.62, 0.18), Vector3(15, 0, 20), RED],
			] + _beads()
		_:
			return false
	body.mesh = _shape(torso, Transform3D(Basis(), torso[torso.size() - 1]))
	body.material_override = material(main)
	_add_parts(body, _rig(parts))
	var nose := c.get_node_or_null("Nose") as Node3D
	if nose:
		nose.visible = false  # the figure's face and weapon show where it faces
	# Height: the whole figure scales, feet staying on the floor.
	var k: float = HEIGHTS.get(c.class_id, 1.0)
	body.scale = Vector3(k, k, k)
	body.position.y *= k
	var label := c.get_node_or_null("NameLabel") as Node3D
	if label:
		label.position.y = 1.95 * k + 0.35
	return true


## Where each joint turns, in the Body's coordinates.
const PIVOTS := {
	"Head": Vector3(0, 0.45, 0),
	"ArmL": Vector3(-0.34, 0.38, 0), "ArmR": Vector3(0.34, 0.38, 0),
	"LegL": Vector3(-0.12, -0.35, 0), "LegR": Vector3(0.12, -0.35, 0),
}


## Sorts the parts onto joints (FigureAnim turns them): the head and what
## sits on it, each arm with what it holds, each leg; the rest stays on the
## torso. Tails come already wrapped in a "Tail" joint. A joint's parts
## keep the Body's coordinates here; _add_parts makes them the joint's.
static func _rig(parts: Array) -> Array:
	var groups := {}
	var out := []
	for p in parts:
		var kind := String(p[0])
		if kind == "joint":
			out.append(p)
			continue
		var at: Vector3 = p[1] if kind == "sub" else (p[2] if kind in ["mark", "subj"] else p[p.size() - 3])
		var joint := ""
		if at.y >= 0.5 and absf(at.x) < 0.3:
			joint = "Head"
		elif absf(at.x) >= 0.28 and at.y >= -0.3 and at.y <= 0.45:
			joint = "ArmL" if at.x < 0.0 else "ArmR"
		elif absf(at.x) >= 0.08 and at.y <= -0.45:
			joint = "LegL" if at.x < 0.0 else "LegR"
		if joint == "":
			out.append(p)
		else:
			if not groups.has(joint):
				groups[joint] = []
			groups[joint].append(p)
	for joint in groups:
		out.append(["joint", joint, PIVOTS[joint], groups[joint]])
	return out


## An animal head: the skull in fur, a muzzle in a lighter colour, the
## eyes, and each species' own ears, nose and the rest. Faces -Z.
static func _head(fur: Color, light: Color, kind: String) -> Array:
	var eye := BLACK
	var parts := [["cyl", 0.16, 0.17, 0.3, 8, Vector3(0, 0.62, 0), Vector3.ZERO, fur],
			["ball", 0.165, 8, Vector3(0, 0.75, 0), Vector3.ZERO, fur]]
	match kind:
		"rabbit":
			parts += [
				["box", Vector3(0.16, 0.11, 0.08), Vector3(0, 0.57, -0.17), Vector3.ZERO, light],
				["box", Vector3(0.05, 0.035, 0.03), Vector3(0, 0.615, -0.215), Vector3.ZERO, Color(0.95, 0.55, 0.6)],
				["box", Vector3(0.025, 0.05, 0.02), Vector3(0, 0.53, -0.212), Vector3.ZERO, WHITE],
				# lop ears, hanging past the cheeks, pink inside
				["sub", Vector3(-0.21, 0.74, -0.02), Vector3(0, 0, -16), [
					["box", Vector3(0.06, 0.42, 0.13), Vector3(0, -0.17, 0), Vector3.ZERO, fur],
					["box", Vector3(0.02, 0.32, 0.08), Vector3(0.03, -0.17, 0), Vector3.ZERO, Color(0.95, 0.7, 0.72)],
				]],
				["sub", Vector3(0.21, 0.74, -0.02), Vector3(0, 0, 16), [
					["box", Vector3(0.06, 0.42, 0.13), Vector3(0, -0.17, 0), Vector3.ZERO, fur],
					["box", Vector3(0.02, 0.32, 0.08), Vector3(-0.03, -0.17, 0), Vector3.ZERO, Color(0.95, 0.7, 0.72)],
				]],
			]
		"bear":
			parts += [
				["box", Vector3(0.17, 0.12, 0.12), Vector3(0, 0.57, -0.19), Vector3.ZERO, light],
				["box", Vector3(0.08, 0.05, 0.04), Vector3(0, 0.6, -0.255), Vector3.ZERO, BLACK],
				["cyl", 0.075, 0.075, 0.05, 8, Vector3(-0.13, 0.84, 0), Vector3(90, 0, 0), fur],
				["cyl", 0.075, 0.075, 0.05, 8, Vector3(0.13, 0.84, 0), Vector3(90, 0, 0), fur],
				["cyl", 0.04, 0.04, 0.02, 8, Vector3(-0.13, 0.84, -0.03), Vector3(90, 0, 0), light],
				["cyl", 0.04, 0.04, 0.02, 8, Vector3(0.13, 0.84, -0.03), Vector3(90, 0, 0), light],
			]
		"goat":
			parts += [
				["box", Vector3(0.13, 0.13, 0.15), Vector3(0, 0.56, -0.2), Vector3(12, 0, 0), light],
				["box", Vector3(0.07, 0.035, 0.03), Vector3(0, 0.59, -0.28), Vector3.ZERO, Color(0.35, 0.3, 0.3)],
				# floppy ears out to the sides
				["box", Vector3(0.17, 0.05, 0.09), Vector3(-0.22, 0.66, 0), Vector3(0, 0, 25), fur],
				["box", Vector3(0.17, 0.05, 0.09), Vector3(0.22, 0.66, 0), Vector3(0, 0, -25), fur],
			]
		"squirrel":
			parts += [
				["box", Vector3(0.14, 0.1, 0.08), Vector3(0, 0.57, -0.17), Vector3.ZERO, light],
				["box", Vector3(0.05, 0.035, 0.03), Vector3(0, 0.61, -0.215), Vector3.ZERO, Color(0.25, 0.15, 0.1)],
				# tufted ears poking up through the helm
				["cyl", 0.0, 0.05, 0.16, 4, Vector3(-0.1, 0.92, 0), Vector3(0, 0, 12), fur],
				["cyl", 0.0, 0.05, 0.16, 4, Vector3(0.1, 0.92, 0), Vector3(0, 0, -12), fur],
				["cyl", 0.0, 0.025, 0.08, 4, Vector3(-0.115, 1.02, 0), Vector3(0, 0, 12), Color(0.45, 0.2, 0.08)],
				["cyl", 0.0, 0.025, 0.08, 4, Vector3(0.115, 1.02, 0), Vector3(0, 0, -12), Color(0.45, 0.2, 0.08)],
			]
		"wolf":
			eye = Color(1.0, 0.12, 0.08)
			parts += [
				# long snout, black nose, the scar over his left eye
				["box", Vector3(0.13, 0.11, 0.22), Vector3(0, 0.56, -0.22), Vector3.ZERO, light],
				["box", Vector3(0.06, 0.05, 0.04), Vector3(0, 0.6, -0.34), Vector3.ZERO, BLACK],
				["box", Vector3(0.03, 0.2, 0.02), Vector3(0.07, 0.66, -0.17), Vector3(0, 0, -28), Color(1.0, 0.78, 0.76)],
				# pointed ears up through the hood
				["cyl", 0.0, 0.065, 0.2, 4, Vector3(-0.1, 0.93, 0.0), Vector3(0, 0, 10), fur],
				["cyl", 0.0, 0.065, 0.2, 4, Vector3(0.1, 0.93, 0.0), Vector3(0, 0, -10), fur],
			]
		"turtle":
			parts += [
				# a hooked beak
				["box", Vector3(0.16, 0.1, 0.1), Vector3(0, 0.57, -0.18), Vector3.ZERO, Color(0.3, 0.3, 0.2)],
				["box", Vector3(0.08, 0.08, 0.06), Vector3(0, 0.53, -0.24), Vector3(30, 0, 0), Color(0.3, 0.3, 0.2)],
				["box", Vector3(0.14, 0.025, 0.02), Vector3(0, 0.555, -0.232), Vector3.ZERO, light],
			]
		"rat":
			parts += [
				["box", Vector3(0.1, 0.09, 0.2), Vector3(0, 0.56, -0.22), Vector3(8, 0, 0), light],
				["box", Vector3(0.05, 0.04, 0.03), Vector3(0, 0.56, -0.33), Vector3.ZERO, Color(0.95, 0.6, 0.65)],
				["cyl", 0.1, 0.1, 0.03, 8, Vector3(-0.15, 0.83, 0.02), Vector3(90, 0, 0), fur],
				["cyl", 0.1, 0.1, 0.03, 8, Vector3(0.15, 0.83, 0.02), Vector3(90, 0, 0), fur],
				["cyl", 0.065, 0.065, 0.02, 8, Vector3(-0.15, 0.83, 0.0), Vector3(90, 0, 0), Color(0.95, 0.65, 0.68)],
				["cyl", 0.065, 0.065, 0.02, 8, Vector3(0.15, 0.83, 0.0), Vector3(90, 0, 0), Color(0.95, 0.65, 0.68)],
			]
		"lizard":
			eye = Color(1.0, 0.85, 0.2)
			parts += [
				["box", Vector3(0.16, 0.09, 0.24), Vector3(0, 0.57, -0.23), Vector3.ZERO, fur],
				["box", Vector3(0.14, 0.03, 0.2), Vector3(0, 0.52, -0.22), Vector3.ZERO, light],
				["cyl", 0.0, 0.04, 0.16, 4, Vector3(-0.09, 0.84, 0.1), Vector3(-50, 0, 0), light],
				["cyl", 0.0, 0.04, 0.16, 4, Vector3(0.09, 0.84, 0.1), Vector3(-50, 0, 0), light],
				["cyl", 0.0, 0.035, 0.12, 4, Vector3(0, 0.8, 0.15), Vector3(-60, 0, 0), light],
			]
		"boar":
			parts += [
				["box", Vector3(0.2, 0.16, 0.16), Vector3(0, 0.56, -0.2), Vector3.ZERO, fur],
				["cyl", 0.085, 0.085, 0.04, 8, Vector3(0, 0.56, -0.29), Vector3(90, 0, 0), light],
				["box", Vector3(0.025, 0.04, 0.02), Vector3(-0.03, 0.56, -0.31), Vector3.ZERO, BLACK],
				["box", Vector3(0.025, 0.04, 0.02), Vector3(0.03, 0.56, -0.31), Vector3.ZERO, BLACK],
				["cyl", 0.0, 0.03, 0.14, 4, Vector3(-0.1, 0.55, -0.27), Vector3(0, 0, -15), WHITE],
				["cyl", 0.0, 0.03, 0.14, 4, Vector3(0.1, 0.55, -0.27), Vector3(0, 0, 15), WHITE],
				["cyl", 0.0, 0.06, 0.14, 4, Vector3(-0.13, 0.82, 0.02), Vector3(0, 0, 25), fur],
				["cyl", 0.0, 0.06, 0.14, 4, Vector3(0.13, 0.82, 0.02), Vector3(0, 0, -25), fur],
				["box", Vector3(0.06, 0.12, 0.36), Vector3(0, 0.86, 0.06), Vector3.ZERO, Color(0.2, 0.15, 0.12)],
			]
		"hyena":
			parts += [
				["box", Vector3(0.14, 0.11, 0.16), Vector3(0, 0.56, -0.2), Vector3.ZERO, Color(0.3, 0.22, 0.15)],
				["box", Vector3(0.06, 0.04, 0.03), Vector3(0, 0.59, -0.285), Vector3.ZERO, BLACK],
				["cyl", 0.08, 0.08, 0.04, 8, Vector3(-0.14, 0.86, 0.01), Vector3(90, 0, 0), fur],
				["cyl", 0.08, 0.08, 0.04, 8, Vector3(0.14, 0.86, 0.01), Vector3(90, 0, 0), fur],
				["box", Vector3(0.05, 0.14, 0.35), Vector3(0, 0.8, 0.12), Vector3(-20, 0, 0), Color(0.3, 0.22, 0.15)],
				["ball", 0.035, 4, Vector3(-0.1, 0.72, -0.13), Vector3.ZERO, Color(0.35, 0.25, 0.15)],
				["ball", 0.035, 4, Vector3(0.12, 0.6, -0.15), Vector3.ZERO, Color(0.35, 0.25, 0.15)],
			]
		"raccoon":
			eye = WHITE
			parts += [
				["box", Vector3(0.14, 0.1, 0.12), Vector3(0, 0.56, -0.19), Vector3.ZERO, light],
				["box", Vector3(0.05, 0.04, 0.03), Vector3(0, 0.6, -0.255), Vector3.ZERO, BLACK],
				# the mask across the eyes
				["box", Vector3(0.3, 0.09, 0.03), Vector3(0, 0.66, -0.157), Vector3.ZERO, Color(0.12, 0.12, 0.14)],
				["cyl", 0.0, 0.06, 0.13, 4, Vector3(-0.12, 0.85, 0.01), Vector3(0, 0, 18), fur],
				["cyl", 0.0, 0.06, 0.13, 4, Vector3(0.12, 0.85, 0.01), Vector3(0, 0, -18), fur],
			]
	parts += [
		["box", Vector3(0.05, 0.05, 0.02), Vector3(-0.07, 0.66, -0.165), Vector3.ZERO, eye],
		["box", Vector3(0.05, 0.05, 0.02), Vector3(0.07, 0.66, -0.165), Vector3.ZERO, eye],
	]
	return parts


## A goat horn: three segments curving up and back.
static func _horn() -> Array:
	var horn := Color(0.55, 0.48, 0.38)
	return [
		["box", Vector3(0.075, 0.18, 0.075), Vector3(0, 0.08, 0.02), Vector3(25, 0, 0), horn],
		["box", Vector3(0.065, 0.17, 0.065), Vector3(0, 0.17, 0.14), Vector3(75, 0, 0), horn],
		["box", Vector3(0.05, 0.15, 0.05), Vector3(0, 0.12, 0.28), Vector3(130, 0, 0), horn],
		["box", Vector3(0.04, 0.1, 0.04), Vector3(0, 0.02, 0.33), Vector3(170, 0, 0), horn],
	]


static func _dagger() -> Array:
	return [
		["box", Vector3(0.04, 0.1, 0.04), Vector3.ZERO, Vector3.ZERO, LEATHER],
		["box", Vector3(0.12, 0.03, 0.04), Vector3(0, 0.06, 0), Vector3.ZERO, STEEL],
		["box", Vector3(0.04, 0.3, 0.015), Vector3(0, 0.22, 0), Vector3.ZERO, STEEL],
	]


## The Monk's prayer beads, an arc across the chest.
static func _beads() -> Array:
	var out := []
	for i in 7:
		var a := deg_to_rad(-60.0 + i * 20.0)
		out.append(["ball", 0.04, 4, Vector3(sin(a) * 0.27, 0.32 - cos(a) * 0.06, -cos(a) * 0.27), Vector3.ZERO, Color(0.35, 0.2, 0.12)])
	return out


## Parts under a node. ["sub", position, rotation, [parts]] groups parts
## that turn together (a sword held at an angle); ["subj", name, position,
## rotation, [parts]] is the same with a name FigureAnim can turn (WeapR,
## WeapL: a weapon at the wrist); `origin` is subtracted
## from the positions given (a joint's pivot).
## ["joint", name, pivot, [parts]] makes a named joint at the pivot; its
## parts are given in the parent's coordinates. ["mark", name, position]
## is an empty named point (TrailBase / TrailTip: where a weapon trail runs;
## a second weapon uses TrailBase2 / TrailTip2).
static func _add_parts(parent: Node3D, parts: Array, origin := Vector3.ZERO) -> void:
	for p in parts:
		if String(p[0]) == "joint":
			var joint := Node3D.new()
			joint.name = p[1]
			joint.position = p[2] - origin
			parent.add_child(joint)
			_add_parts(joint, p[3], p[2])
			continue
		if String(p[0]) == "mark":
			# A named point (a weapon's base and tip, for its trail).
			var mark := Node3D.new()
			mark.name = p[1]
			mark.position = p[2] - origin
			parent.add_child(mark)
			continue
		if String(p[0]) == "sub":
			var group := Node3D.new()
			group.position = p[1] - origin
			group.rotation_degrees = p[2]
			parent.add_child(group)
			_add_parts(group, p[3])
			continue
		if String(p[0]) == "subj":
			# A group that FigureAnim can turn too (a held weapon's wrist).
			var wrist := Node3D.new()
			wrist.name = p[1]
			wrist.position = p[2] - origin
			wrist.rotation_degrees = p[3]
			parent.add_child(wrist)
			_add_parts(wrist, p[4])
			continue
		var mi := MeshInstance3D.new()
		var n: int = p.size()
		mi.mesh = _shape(p, Transform3D.IDENTITY)
		mi.position = p[n - 3] - origin
		mi.rotation_degrees = p[n - 2]
		mi.material_override = material(p[n - 1])
		parent.add_child(mi)


## One part's mesh: ["box", size], ["cyl", top_r, bottom_r, height, sides],
## ["ball", radius, sides] or ["oval", radii, sides], baked with an offset (for the torso, whose node
## can't move off the Body's centre).
static func _shape(p: Array, offset: Transform3D) -> Mesh:
	var prim: PrimitiveMesh
	match String(p[0]):
		"box":
			var b := BoxMesh.new()
			b.size = p[1]
			prim = b
		"cyl":
			var cy := CylinderMesh.new()
			cy.top_radius = p[1]
			cy.bottom_radius = p[2]
			cy.height = p[3]
			cy.radial_segments = p[4]
			cy.rings = 1
			prim = cy
		"oval":
			var o := SphereMesh.new()
			o.radius = 1.0
			o.height = 2.0
			o.radial_segments = p[2]
			o.rings = maxi(int(p[2]) / 2, 3)
			if offset == Transform3D.IDENTITY:
				offset = Transform3D(Basis.from_scale(p[1]), Vector3.ZERO)
			prim = o
		"ball":
			var s := SphereMesh.new()
			s.radius = p[1]
			s.height = float(p[1]) * 2.0
			s.radial_segments = p[2]
			s.rings = maxi(int(p[2]) / 2, 3)
			prim = s
	if offset == Transform3D.IDENTITY:
		return prim
	var st := SurfaceTool.new()
	st.create_from(prim, 0)
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] = offset * verts[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
