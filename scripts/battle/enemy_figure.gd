class_name EnemyFigure
extends RefCounted
## Low-poly figures for the enemies (see Figure for the party's): animal
## folk for the humanoid foes, and the monsters. Picked by the enemy's scene
## file. Looks only: body size and reach in the fight don't change.
##
## Animal folk are drawn like the party (the Body's centre 0.9 m up on a
## 1.9 m figure, then scaled; joints sorted by Figure._rig). Monsters are
## drawn at their own size, around the Body's centre where the scene put it,
## with their joints given by hand. The figure faces -Z.
##
## Each figure sets the meta "figure_style" for FigureAnim: "biped",
## "quad" (four legs and wings), "float" (sprites) or "wall" (Gale Maw).

const F := preload("res://scripts/battle/figure.gd")

const STEEL := Color(0.5, 0.53, 0.6)
const DARK_STEEL := Color(0.27, 0.29, 0.34)
const LEATHER := Color(0.42, 0.27, 0.16)
const WOOD := Color(0.45, 0.3, 0.18)
const BLACK := Color(0.06, 0.06, 0.08)
const WHITE := Color(0.9, 0.9, 0.93)
const BONE := Color(0.88, 0.84, 0.72)
const RUST := Color(0.55, 0.38, 0.28)


static func build(c: Combatant) -> bool:
	var body := c.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return false
	var id := c.scene_file_path.get_file().get_basename()
	var main := c.color
	var parts: Array = []
	var torso: Array = []
	var scale := Vector3.ONE
	var top := 0.0  # the figure's top, metres above the floor (name label)
	var animal := true
	var style := "biped"
	match id:
		"goblin_fighter":
			# A rat in a ragged green tunic: short rusty sword, a round shield.
			var fur := Color(0.5, 0.45, 0.42)
			var pink := Color(0.93, 0.66, 0.68)
			torso = ["cyl", 0.27, 0.24, 0.58, 6, Vector3(0, 0.12, 0)]
			parts = F._head(fur, Color(0.72, 0.66, 0.64), "rat") + [
				["box", Vector3(0.13, 0.5, 0.15), Vector3(-0.11, -0.6, 0), Vector3.ZERO, fur],
				["box", Vector3(0.13, 0.5, 0.15), Vector3(0.11, -0.6, 0), Vector3.ZERO, fur],
				["box", Vector3(0.14, 0.07, 0.26), Vector3(-0.11, -0.86, -0.05), Vector3.ZERO, pink],
				["box", Vector3(0.14, 0.07, 0.26), Vector3(0.11, -0.86, -0.05), Vector3.ZERO, pink],
				["cyl", 0.25, 0.32, 0.24, 5, Vector3(0, -0.28, 0), Vector3(0, 20, 0), main.darkened(0.2)],
				["cyl", 0.25, 0.25, 0.06, 6, Vector3(0, -0.15, 0), Vector3.ZERO, LEATHER],
				["box", Vector3(0.11, 0.44, 0.12), Vector3(-0.32, 0.08, -0.04), Vector3(-15, 0, -6), fur],
				["box", Vector3(0.11, 0.44, 0.12), Vector3(0.32, 0.08, -0.04), Vector3(-25, 0, 6), fur],
				["ball", 0.065, 6, Vector3(-0.34, -0.16, -0.12), Vector3.ZERO, pink],
				["ball", 0.065, 6, Vector3(0.34, -0.16, -0.14), Vector3.ZERO, pink],
				["sub", Vector3(-0.44, 0.0, -0.14), Vector3(0, 0, 90), [
					["cyl", 0.24, 0.24, 0.05, 8, Vector3.ZERO, Vector3.ZERO, WOOD],
					["cyl", 0.07, 0.07, 0.07, 6, Vector3.ZERO, Vector3.ZERO, DARK_STEEL],
				]],
				["sub", Vector3(0.36, -0.17, -0.16), Vector3(-60, 0, 0), [
					["box", Vector3(0.06, 0.16, 0.06), Vector3.ZERO, Vector3.ZERO, LEATHER],
					["box", Vector3(0.2, 0.04, 0.06), Vector3(0, 0.09, 0), Vector3.ZERO, RUST],
					["box", Vector3(0.07, 0.5, 0.02), Vector3(0, 0.36, 0), Vector3.ZERO, RUST],
				]],
				["joint", "Tail", Vector3(0, -0.3, 0.22), [
					["cyl", 0.035, 0.05, 0.5, 5, Vector3(0, -0.45, 0.4), Vector3(-60, 0, 0), pink],
					["cyl", 0.012, 0.035, 0.45, 5, Vector3(0, -0.62, 0.82), Vector3(-90, 0, 0), pink],
				]],
			]
			scale = Vector3.ONE * 0.7
		"kobold_archer":
			# A lizard in a leather harness, short bow and quiver, a long tail.
			var scales := main
			torso = ["cyl", 0.25, 0.22, 0.58, 6, Vector3(0, 0.12, 0)]
			parts = F._head(scales, Color(0.92, 0.82, 0.6), "lizard") + [
				["box", Vector3(0.13, 0.5, 0.16), Vector3(-0.11, -0.6, 0), Vector3.ZERO, scales.darkened(0.15)],
				["box", Vector3(0.13, 0.5, 0.16), Vector3(0.11, -0.6, 0), Vector3.ZERO, scales.darkened(0.15)],
				["box", Vector3(0.15, 0.07, 0.28), Vector3(-0.11, -0.86, -0.06), Vector3.ZERO, scales.darkened(0.3)],
				["box", Vector3(0.15, 0.07, 0.28), Vector3(0.11, -0.86, -0.06), Vector3.ZERO, scales.darkened(0.3)],
				["box", Vector3(0.4, 0.45, 0.06), Vector3(0, 0.12, -0.22), Vector3.ZERO, Color(0.92, 0.82, 0.6)],
				["box", Vector3(0.07, 0.62, 0.5), Vector3(0, 0.12, 0), Vector3(0, 0, 35), LEATHER],
				["cyl", 0.23, 0.28, 0.2, 6, Vector3(0, -0.26, 0), Vector3.ZERO, LEATHER],
				["box", Vector3(0.1, 0.44, 0.11), Vector3(-0.31, 0.08, -0.04), Vector3(-20, 0, -6), scales],
				["box", Vector3(0.1, 0.44, 0.11), Vector3(0.31, 0.08, 0), Vector3(0, 0, 6), scales],
				["ball", 0.06, 6, Vector3(-0.33, -0.15, -0.13), Vector3.ZERO, scales.darkened(0.2)],
				["ball", 0.06, 6, Vector3(0.33, -0.17, 0), Vector3.ZERO, scales.darkened(0.2)],
				["sub", Vector3(0.12, 0.12, 0.27), Vector3(0, 0, -20), [
					["cyl", 0.07, 0.06, 0.48, 6, Vector3.ZERO, Vector3.ZERO, LEATHER],
					["box", Vector3(0.03, 0.14, 0.03), Vector3(-0.025, 0.3, 0), Vector3.ZERO, WHITE],
					["box", Vector3(0.03, 0.16, 0.03), Vector3(0.025, 0.31, 0.02), Vector3.ZERO, WHITE],
				]],
				["sub", Vector3(-0.38, -0.12, -0.24), Vector3(0, 0, 8), [
					["box", Vector3(0.05, 0.13, 0.06), Vector3.ZERO, Vector3.ZERO, LEATHER],
					["box", Vector3(0.04, 0.36, 0.045), Vector3(0, 0.2, 0.05), Vector3(25, 0, 0), WOOD],
					["box", Vector3(0.04, 0.36, 0.045), Vector3(0, -0.2, 0.05), Vector3(-25, 0, 0), WOOD],
					["box", Vector3(0.01, 0.68, 0.01), Vector3(0, 0, 0.12), Vector3.ZERO, WHITE],
				]],
				["joint", "Tail", Vector3(0, -0.3, 0.2), [
					["cyl", 0.04, 0.13, 0.9, 6, Vector3(0, -0.55, 0.55), Vector3(-70, 0, 0), scales],
				]],
			]
			scale = Vector3.ONE * 0.68
		"ogre_warrior":
			# A huge boar: tusks, a bristly mane, hide armour, a spiked club.
			var fur := Color(0.42, 0.33, 0.27)
			torso = ["cyl", 0.33, 0.28, 0.62, 6, Vector3(0, 0.12, 0)]
			parts = F._head(fur, Color(0.78, 0.6, 0.58), "boar") + [
				["box", Vector3(0.19, 0.5, 0.21), Vector3(-0.13, -0.6, 0), Vector3.ZERO, fur.darkened(0.2)],
				["box", Vector3(0.19, 0.5, 0.21), Vector3(0.13, -0.6, 0), Vector3.ZERO, fur.darkened(0.2)],
				["box", Vector3(0.2, 0.1, 0.24), Vector3(-0.13, -0.86, -0.03), Vector3.ZERO, BLACK],
				["box", Vector3(0.2, 0.1, 0.24), Vector3(0.13, -0.86, -0.03), Vector3.ZERO, BLACK],
				["cyl", 0.3, 0.34, 0.26, 6, Vector3(0, -0.27, 0), Vector3.ZERO, LEATHER],
				["cyl", 0.31, 0.31, 0.08, 6, Vector3(0, -0.16, 0), Vector3.ZERO, DARK_STEEL],
				["box", Vector3(0.05, 0.6, 0.06), Vector3(0, 0.15, -0.3), Vector3(0, 0, 30), LEATHER],
				["ball", 0.2, 6, Vector3(-0.38, 0.38, 0), Vector3.ZERO, DARK_STEEL],
				["cyl", 0.0, 0.06, 0.16, 4, Vector3(-0.42, 0.56, 0), Vector3.ZERO, WHITE],
				["box", Vector3(0.16, 0.46, 0.17), Vector3(-0.4, 0.08, 0), Vector3(0, 0, -6), fur],
				["box", Vector3(0.16, 0.46, 0.17), Vector3(0.4, 0.08, -0.04), Vector3(-25, 0, 6), fur],
				["ball", 0.1, 6, Vector3(-0.42, -0.18, 0), Vector3.ZERO, fur.darkened(0.2)],
				["ball", 0.1, 6, Vector3(0.42, -0.16, -0.14), Vector3.ZERO, fur.darkened(0.2)],
				["sub", Vector3(0.42, -0.16, -0.16), Vector3(-40, 0, 0), [
					["cyl", 0.05, 0.05, 0.25, 6, Vector3.ZERO, Vector3.ZERO, LEATHER],
					["cyl", 0.15, 0.07, 0.8, 6, Vector3(0, 0.5, 0), Vector3.ZERO, WOOD],
					["cyl", 0.0, 0.04, 0.12, 4, Vector3(0.14, 0.7, 0), Vector3(0, 0, -90), DARK_STEEL],
					["cyl", 0.0, 0.04, 0.12, 4, Vector3(-0.14, 0.62, 0), Vector3(0, 0, 90), DARK_STEEL],
					["cyl", 0.0, 0.04, 0.12, 4, Vector3(0, 0.8, -0.14), Vector3(-90, 0, 0), DARK_STEEL],
				]],
				["joint", "Tail", Vector3(0, -0.3, 0.26), [
					["cyl", 0.015, 0.03, 0.22, 4, Vector3(0, -0.35, 0.34), Vector3(-60, 0, 0), fur],
				]],
			]
			scale = Vector3(1.45, 1.3, 1.4)
		"orc_shaman":
			# A spotted hyena in a teal robe: bone necklace, a skull staff.
			var fur := Color(0.72, 0.6, 0.4)
			torso = ["cyl", 0.25, 0.27, 0.55, 6, Vector3(0, 0.15, 0)]
			parts = F._head(fur, Color(0.85, 0.75, 0.55), "hyena") + [
				["cyl", 0.27, 0.42, 0.78, 6, Vector3(0, -0.5, 0), Vector3.ZERO, main],
				["cyl", 0.425, 0.425, 0.05, 6, Vector3(0, -0.865, 0), Vector3.ZERO, main.darkened(0.4)],
				["cyl", 0.275, 0.275, 0.07, 6, Vector3(0, -0.12, 0), Vector3.ZERO, LEATHER],
				["cyl", 0.07, 0.13, 0.45, 6, Vector3(-0.32, 0.08, 0), Vector3(0, 0, -8), main],
				["cyl", 0.07, 0.13, 0.45, 6, Vector3(0.33, 0.06, -0.06), Vector3(-25, 0, 8), main],
				["ball", 0.07, 6, Vector3(-0.35, -0.18, 0), Vector3.ZERO, fur],
				["ball", 0.07, 6, Vector3(0.38, -0.12, -0.16), Vector3.ZERO, fur],
				["box", Vector3(0.06, 0.08, 0.03), Vector3(-0.12, 0.3, -0.25), Vector3(0, 0, 20), BONE],
				["box", Vector3(0.06, 0.08, 0.03), Vector3(0, 0.27, -0.27), Vector3.ZERO, BONE],
				["box", Vector3(0.06, 0.08, 0.03), Vector3(0.12, 0.3, -0.25), Vector3(0, 0, -20), BONE],
				["sub", Vector3(0.38, -0.12, -0.16), Vector3(-8, 0, 0), [
					["cyl", 0.03, 0.03, 1.45, 5, Vector3(0, 0.25, 0), Vector3.ZERO, BONE],
					["box", Vector3(0.18, 0.15, 0.17), Vector3(0, 1.03, 0), Vector3.ZERO, BONE],
					["box", Vector3(0.04, 0.04, 0.02), Vector3(-0.045, 1.04, -0.086), Vector3.ZERO, Color(0.3, 1.0, 0.6)],
					["box", Vector3(0.04, 0.04, 0.02), Vector3(0.045, 1.04, -0.086), Vector3.ZERO, Color(0.3, 1.0, 0.6)],
					["cyl", 0.0, 0.03, 0.15, 4, Vector3(-0.09, 1.15, 0), Vector3(0, 0, 30), BONE],
					["cyl", 0.0, 0.03, 0.15, 4, Vector3(0.09, 1.15, 0), Vector3(0, 0, -30), BONE],
				]],
			]
			scale = Vector3.ONE
		"bandit_arcanist":
			# A raccoon in a purple hooded cloak (hood down): a glowing tome,
			# a ringed tail.
			var fur := Color(0.55, 0.55, 0.57)
			var dark := Color(0.15, 0.15, 0.17)
			torso = ["cyl", 0.25, 0.22, 0.58, 6, Vector3(0, 0.12, 0)]
			parts = F._head(fur, Color(0.88, 0.88, 0.88), "raccoon") + [
				["box", Vector3(0.14, 0.5, 0.16), Vector3(-0.1, -0.6, 0), Vector3.ZERO, Color(0.2, 0.18, 0.22)],
				["box", Vector3(0.14, 0.5, 0.16), Vector3(0.1, -0.6, 0), Vector3.ZERO, Color(0.2, 0.18, 0.22)],
				["box", Vector3(0.16, 0.12, 0.25), Vector3(-0.1, -0.84, -0.03), Vector3.ZERO, LEATHER],
				["box", Vector3(0.16, 0.12, 0.25), Vector3(0.1, -0.84, -0.03), Vector3.ZERO, LEATHER],
				["cyl", 0.24, 0.36, 0.45, 6, Vector3(0, -0.38, 0.06), Vector3.ZERO, main],
				["box", Vector3(0.52, 0.85, 0.05), Vector3(0, -0.05, 0.27), Vector3(6, 0, 0), main.darkened(0.2)],
				["cyl", 0.25, 0.3, 0.12, 6, Vector3(0, 0.44, 0.02), Vector3.ZERO, main.darkened(0.2)],
				["box", Vector3(0.11, 0.44, 0.12), Vector3(-0.32, 0.08, -0.04), Vector3(-30, 0, -6), main],
				["box", Vector3(0.11, 0.44, 0.12), Vector3(0.32, 0.08, -0.04), Vector3(-30, 0, 6), main],
				["ball", 0.065, 6, Vector3(-0.34, -0.12, -0.18), Vector3.ZERO, dark],
				["ball", 0.065, 6, Vector3(0.34, -0.12, -0.18), Vector3.ZERO, dark],
				["sub", Vector3(-0.36, -0.08, -0.26), Vector3(-20, 0, 0), [
					["box", Vector3(0.24, 0.05, 0.18), Vector3.ZERO, Vector3.ZERO, Color(0.35, 0.15, 0.4)],
					["box", Vector3(0.21, 0.02, 0.15), Vector3(0, 0.035, 0), Vector3.ZERO, Color(0.75, 0.55, 1.0)],
				]],
				["sub", Vector3(0.36, -0.12, -0.2), Vector3(-60, 0, 0), [
					["cyl", 0.015, 0.02, 0.32, 5, Vector3(0, 0.12, 0), Vector3.ZERO, BLACK],
					["ball", 0.045, 6, Vector3(0, 0.3, 0), Vector3.ZERO, Color(0.8, 0.5, 1.0)],
				]],
				["joint", "Tail", Vector3(0, -0.3, 0.22), _ringed_tail(fur, dark)],
			]
			scale = Vector3.ONE * 0.82
		"training_golem":
			# A wooden practice construct: a banded barrel with a target, log
			# arms, a bucket head.
			animal = false
			var wood := main
			torso = ["cyl", 0.58, 0.62, 1.0, 8, Vector3(0, 0.25, 0)]
			parts = [
				["cyl", 0.6, 0.6, 0.06, 8, Vector3(0, 0.62, 0), Vector3.ZERO, DARK_STEEL],
				["cyl", 0.64, 0.64, 0.06, 8, Vector3(0, -0.12, 0), Vector3.ZERO, DARK_STEEL],
				["cyl", 0.32, 0.32, 0.03, 8, Vector3(0, 0.27, -0.6), Vector3(90, 0, 0), WHITE],
				["cyl", 0.22, 0.22, 0.035, 8, Vector3(0, 0.27, -0.61), Vector3(90, 0, 0), Color(0.8, 0.2, 0.15)],
				["cyl", 0.11, 0.11, 0.04, 8, Vector3(0, 0.27, -0.62), Vector3(90, 0, 0), WHITE],
				["joint", "Head", Vector3(0, 0.75, 0), [
					["cyl", 0.28, 0.24, 0.38, 8, Vector3(0, 0.95, 0), Vector3.ZERO, DARK_STEEL],
					["box", Vector3(0.08, 0.06, 0.04), Vector3(-0.1, 0.98, -0.25), Vector3.ZERO, Color(1.0, 0.85, 0.3)],
					["box", Vector3(0.08, 0.06, 0.04), Vector3(0.1, 0.98, -0.25), Vector3.ZERO, Color(1.0, 0.85, 0.3)],
				]],
				["joint", "ArmL", Vector3(-0.62, 0.5, 0), [
					["cyl", 0.13, 0.13, 0.8, 6, Vector3(-0.72, 0.1, 0), Vector3(0, 0, -10), wood.darkened(0.15)],
					["ball", 0.18, 6, Vector3(-0.78, -0.32, 0), Vector3.ZERO, wood.darkened(0.25)],
				]],
				["joint", "ArmR", Vector3(0.62, 0.5, 0), [
					["cyl", 0.13, 0.13, 0.8, 6, Vector3(0.72, 0.1, 0), Vector3(0, 0, 10), wood.darkened(0.15)],
					["ball", 0.18, 6, Vector3(0.78, -0.32, 0), Vector3.ZERO, wood.darkened(0.25)],
				]],
				["joint", "LegL", Vector3(-0.3, -0.2, 0), [
					["cyl", 0.17, 0.2, 0.55, 6, Vector3(-0.3, -0.48, 0), Vector3.ZERO, wood.darkened(0.15)],
				]],
				["joint", "LegR", Vector3(0.3, -0.2, 0), [
					["cyl", 0.17, 0.2, 0.55, 6, Vector3(0.3, -0.48, 0), Vector3.ZERO, wood.darkened(0.15)],
				]],
			]
			top = 2.0
		"stone_golem":
			# A rock giant: boulder chest, small head with glowing eyes, huge
			# fists, moss and crystals.
			animal = false
			var rock := main
			var moss := Color(0.35, 0.5, 0.25)
			var glow := Color(0.45, 0.95, 1.0)
			torso = ["oval", Vector3(0.82, 0.72, 0.62), 7, Vector3(0, 0.55, 0)]
			parts = [
				["oval", Vector3(0.6, 0.35, 0.5), 6, Vector3(0, -0.02, 0.02), Vector3.ZERO, rock.darkened(0.15)],
				["box", Vector3(0.7, 0.08, 0.5), Vector3(0, 1.2, 0.05), Vector3(0, 10, 0), moss],
				["cyl", 0.0, 0.12, 0.4, 4, Vector3(-0.25, 1.15, 0.45), Vector3(-30, 0, -15), glow],
				["cyl", 0.0, 0.09, 0.3, 4, Vector3(0.15, 1.1, 0.5), Vector3(-35, 0, 10), glow],
				["joint", "Head", Vector3(0, 1.15, -0.2), [
					["box", Vector3(0.46, 0.38, 0.42), Vector3(0, 1.32, -0.42), Vector3(0, 0, 0), rock],
					["box", Vector3(0.5, 0.1, 0.12), Vector3(0, 1.42, -0.62), Vector3.ZERO, rock.darkened(0.25)],
					["box", Vector3(0.1, 0.05, 0.03), Vector3(-0.11, 1.34, -0.635), Vector3.ZERO, glow],
					["box", Vector3(0.1, 0.05, 0.03), Vector3(0.11, 1.34, -0.635), Vector3.ZERO, glow],
					["box", Vector3(0.3, 0.06, 0.2), Vector3(0.05, 1.52, -0.4), Vector3.ZERO, moss],
				]],
				["joint", "ArmL", Vector3(-0.85, 0.95, 0), [
					["oval", Vector3(0.42, 0.36, 0.42), 6, Vector3(-0.92, 1.0, 0), Vector3.ZERO, rock],
					["box", Vector3(0.36, 0.6, 0.36), Vector3(-1.0, 0.45, 0), Vector3(0, 0, -8), rock.darkened(0.1)],
					["box", Vector3(0.55, 0.5, 0.55), Vector3(-1.05, -0.05, -0.05), Vector3(0, 15, 0), rock],
					["box", Vector3(0.35, 0.06, 0.3), Vector3(-0.92, 1.33, 0), Vector3.ZERO, moss],
				]],
				["joint", "ArmR", Vector3(0.85, 0.95, 0), [
					["oval", Vector3(0.42, 0.36, 0.42), 6, Vector3(0.92, 1.0, 0), Vector3.ZERO, rock],
					["box", Vector3(0.36, 0.6, 0.36), Vector3(1.0, 0.45, 0), Vector3(0, 0, 8), rock.darkened(0.1)],
					["box", Vector3(0.55, 0.5, 0.55), Vector3(1.05, -0.05, -0.05), Vector3(0, -15, 0), rock],
				]],
				["joint", "LegL", Vector3(-0.4, -0.15, 0), [
					["box", Vector3(0.45, 0.6, 0.5), Vector3(-0.42, -0.5, 0), Vector3.ZERO, rock.darkened(0.1)],
				]],
				["joint", "LegR", Vector3(0.4, -0.15, 0), [
					["box", Vector3(0.45, 0.6, 0.5), Vector3(0.42, -0.5, 0), Vector3.ZERO, rock.darkened(0.1)],
				]],
			]
			top = 2.55
		"living_armor":
			# An empty suit of dark plate: purple eyes in the visor, spiked
			# pauldrons, a tattered cape, a greatsword.
			animal = false
			var plate := main
			var glow := Color(0.8, 0.45, 1.0)
			torso = ["cyl", 0.46, 0.36, 0.8, 6, Vector3(0, 0.42, 0)]
			parts = [
				["cyl", 0.38, 0.46, 0.32, 6, Vector3(0, -0.12, 0), Vector3.ZERO, plate.darkened(0.2)],
				["box", Vector3(0.12, 0.6, 0.06), Vector3(0, 0.45, -0.42), Vector3.ZERO, plate.lightened(0.25)],
				["box", Vector3(0.8, 1.3, 0.05), Vector3(0, 0.1, 0.42), Vector3(6, 0, 0), Color(0.28, 0.1, 0.32)],
				["box", Vector3(0.2, 0.25, 0.05), Vector3(-0.22, -0.65, 0.5), Vector3(6, 0, 0), Color(0.28, 0.1, 0.32)],
				["box", Vector3(0.24, 0.2, 0.05), Vector3(0.18, -0.62, 0.5), Vector3(6, 0, 0), Color(0.28, 0.1, 0.32)],
				["joint", "Head", Vector3(0, 0.85, 0), [
					["cyl", 0.24, 0.26, 0.44, 8, Vector3(0, 1.1, 0), Vector3.ZERO, plate],
					["oval", Vector3(0.245, 0.12, 0.255), 8, Vector3(0, 1.32, 0), Vector3.ZERO, plate],
					["box", Vector3(0.34, 0.06, 0.06), Vector3(0, 1.12, -0.24), Vector3.ZERO, BLACK],
					["box", Vector3(0.06, 0.2, 0.06), Vector3(0, 1.02, -0.245), Vector3.ZERO, BLACK],
					["box", Vector3(0.06, 0.035, 0.03), Vector3(-0.09, 1.12, -0.27), Vector3.ZERO, glow],
					["box", Vector3(0.06, 0.035, 0.03), Vector3(0.09, 1.12, -0.27), Vector3.ZERO, glow],
					["box", Vector3(0.05, 0.22, 0.4), Vector3(0, 1.45, 0.02), Vector3.ZERO, plate.lightened(0.15)],
				]],
				["joint", "ArmL", Vector3(-0.5, 0.75, 0), [
					["oval", Vector3(0.28, 0.22, 0.3), 6, Vector3(-0.52, 0.82, 0), Vector3.ZERO, plate.lightened(0.1)],
					["cyl", 0.0, 0.06, 0.25, 4, Vector3(-0.6, 1.05, 0), Vector3(0, 0, 20), STEEL],
					["box", Vector3(0.18, 0.72, 0.2), Vector3(-0.58, 0.3, 0), Vector3(0, 0, -5), plate],
					["box", Vector3(0.2, 0.18, 0.22), Vector3(-0.6, -0.12, 0), Vector3.ZERO, plate.darkened(0.2)],
				]],
				["joint", "ArmR", Vector3(0.5, 0.75, 0), [
					["oval", Vector3(0.28, 0.22, 0.3), 6, Vector3(0.52, 0.82, 0), Vector3.ZERO, plate.lightened(0.1)],
					["cyl", 0.0, 0.06, 0.25, 4, Vector3(0.6, 1.05, 0), Vector3(0, 0, -20), STEEL],
					["box", Vector3(0.18, 0.72, 0.2), Vector3(0.58, 0.3, -0.05), Vector3(-15, 0, 5), plate],
					["box", Vector3(0.2, 0.18, 0.22), Vector3(0.6, -0.1, -0.15), Vector3.ZERO, plate.darkened(0.2)],
					["sub", Vector3(0.6, -0.12, -0.2), Vector3(-70, 0, 0), [
						["box", Vector3(0.07, 0.3, 0.07), Vector3.ZERO, Vector3.ZERO, LEATHER],
						["box", Vector3(0.42, 0.07, 0.09), Vector3(0, 0.17, 0), Vector3.ZERO, DARK_STEEL],
						["box", Vector3(0.14, 1.3, 0.035), Vector3(0, 0.85, 0), Vector3.ZERO, STEEL],
						["box", Vector3(0.03, 1.1, 0.04), Vector3(0, 0.8, 0), Vector3.ZERO, glow],
					]],
				]],
				["joint", "LegL", Vector3(-0.2, -0.3, 0), [
					["box", Vector3(0.22, 0.65, 0.24), Vector3(-0.22, -0.6, 0), Vector3.ZERO, plate.darkened(0.1)],
					["box", Vector3(0.24, 0.12, 0.36), Vector3(-0.22, -0.94, -0.06), Vector3.ZERO, plate.darkened(0.3)],
				]],
				["joint", "LegR", Vector3(0.2, -0.3, 0), [
					["box", Vector3(0.22, 0.65, 0.24), Vector3(0.22, -0.6, 0), Vector3.ZERO, plate.darkened(0.1)],
					["box", Vector3(0.24, 0.12, 0.36), Vector3(0.22, -0.94, -0.06), Vector3.ZERO, plate.darkened(0.3)],
				]],
			]
			top = 2.6
		"dragon_hatchling":
			# A chunky baby dragon on four legs: horns, little wings, a long
			# spiked tail, a cream belly.
			animal = false
			style = "quad"
			var hide := main
			var belly := Color(0.95, 0.8, 0.5)
			var horn := Color(0.95, 0.9, 0.75)
			torso = ["oval", Vector3(0.75, 0.55, 1.0), 8, Vector3(0, 0.15, 0.05)]
			parts = [
				["oval", Vector3(0.6, 0.4, 0.8), 8, Vector3(0, 0.02, -0.02), Vector3.ZERO, belly],
				["cyl", 0.0, 0.1, 0.22, 4, Vector3(0, 0.72, -0.2), Vector3(-20, 0, 0), horn],
				["cyl", 0.0, 0.1, 0.22, 4, Vector3(0, 0.72, 0.25), Vector3(-25, 0, 0), horn],
				["cyl", 0.0, 0.08, 0.18, 4, Vector3(0, 0.6, 0.65), Vector3(-35, 0, 0), horn],
				["joint", "Head", Vector3(0, 0.5, -0.8), [
					["cyl", 0.3, 0.38, 0.6, 7, Vector3(0, 0.62, -0.95), Vector3(55, 0, 0), hide],
					["box", Vector3(0.62, 0.48, 0.58), Vector3(0, 0.95, -1.25), Vector3.ZERO, hide],
					["box", Vector3(0.44, 0.28, 0.4), Vector3(0, 0.86, -1.68), Vector3.ZERO, hide],
					["box", Vector3(0.4, 0.1, 0.38), Vector3(0, 0.71, -1.6), Vector3.ZERO, belly],
					["box", Vector3(0.05, 0.05, 0.03), Vector3(-0.1, 0.94, -1.89), Vector3.ZERO, BLACK],
					["box", Vector3(0.05, 0.05, 0.03), Vector3(0.1, 0.94, -1.89), Vector3.ZERO, BLACK],
					["box", Vector3(0.1, 0.08, 0.03), Vector3(-0.2, 1.05, -1.545), Vector3.ZERO, Color(1.0, 0.85, 0.2)],
					["box", Vector3(0.1, 0.08, 0.03), Vector3(0.2, 1.05, -1.545), Vector3.ZERO, Color(1.0, 0.85, 0.2)],
					["box", Vector3(0.04, 0.06, 0.03), Vector3(-0.2, 1.05, -1.56), Vector3.ZERO, BLACK],
					["box", Vector3(0.04, 0.06, 0.03), Vector3(0.2, 1.05, -1.56), Vector3.ZERO, BLACK],
					["cyl", 0.0, 0.08, 0.45, 5, Vector3(-0.2, 1.3, -1.05), Vector3(-60, 0, -15), horn],
					["cyl", 0.0, 0.08, 0.45, 5, Vector3(0.2, 1.3, -1.05), Vector3(-60, 0, 15), horn],
					["cyl", 0.0, 0.03, 0.08, 4, Vector3(-0.15, 0.7, -1.8), Vector3(180, 0, 0), WHITE],
					["cyl", 0.0, 0.03, 0.08, 4, Vector3(0.15, 0.7, -1.8), Vector3(180, 0, 0), WHITE],
				]],
				["joint", "WingL", Vector3(-0.45, 0.55, -0.1), [
					["box", Vector3(0.8, 0.06, 0.08), Vector3(-0.85, 0.85, -0.1), Vector3(0, 0, 35), hide.darkened(0.2)],
					["box", Vector3(0.75, 0.03, 0.55), Vector3(-0.85, 0.75, 0.15), Vector3(0, 0, 35), hide.darkened(0.35)],
				]],
				["joint", "WingR", Vector3(0.45, 0.55, -0.1), [
					["box", Vector3(0.8, 0.06, 0.08), Vector3(0.85, 0.85, -0.1), Vector3(0, 0, -35), hide.darkened(0.2)],
					["box", Vector3(0.75, 0.03, 0.55), Vector3(0.85, 0.75, 0.15), Vector3(0, 0, -35), hide.darkened(0.35)],
				]],
				["joint", "LegL", Vector3(-0.45, -0.1, -0.55), _dragon_leg(-0.5, -0.6, hide, horn)],
				["joint", "LegR", Vector3(0.45, -0.1, -0.55), _dragon_leg(0.5, -0.6, hide, horn)],
				["joint", "LegBL", Vector3(-0.5, -0.1, 0.6), _dragon_leg(-0.55, 0.6, hide, horn)],
				["joint", "LegBR", Vector3(0.5, -0.1, 0.6), _dragon_leg(0.55, 0.6, hide, horn)],
				["joint", "Tail", Vector3(0, 0.1, 0.95), [
					["cyl", 0.12, 0.3, 0.9, 6, Vector3(0, -0.05, 1.35), Vector3(-80, 0, 0), hide],
					["cyl", 0.04, 0.12, 0.8, 6, Vector3(0, -0.2, 2.1), Vector3(-85, 0, 0), hide],
					["cyl", 0.0, 0.07, 0.15, 4, Vector3(0, 0.15, 1.4), Vector3(-20, 0, 0), horn],
					["cyl", 0.0, 0.06, 0.13, 4, Vector3(0, 0.0, 1.9), Vector3(-25, 0, 0), horn],
					["box", Vector3(0.28, 0.04, 0.22), Vector3(0, -0.24, 2.55), Vector3(0, 45, 0), hide.darkened(0.3)],
				]],
			]
			top = 2.4
		"gale_maw":
			# A colossal wind-spirit ram: long muzzle (Deep Breath's black mouth
			# opens at its front), curling horns, glowing eyes, a cloud mane,
			# and two great clawed paws that hover either side of it.
			animal = false
			style = "wall"
			var fur := main
			var light := main.lightened(0.35)
			var glow := Color(0.75, 1.0, 1.0)
			var cloud := Color(0.88, 0.93, 0.97)
			var horn := Color(0.82, 0.78, 0.68)
			torso = ["oval", Vector3(2.6, 2.3, 2.6), 10, Vector3(0, 0.4, 0.6)]
			parts = [
				# the muzzle reaching forward to the mouth, a pale snout
				["oval", Vector3(1.7, 1.35, 1.9), 10, Vector3(0, -0.05, -2.2), Vector3.ZERO, fur],
				["oval", Vector3(1.4, 0.9, 0.9), 8, Vector3(0, -0.15, -3.3), Vector3.ZERO, light],
				["box", Vector3(0.35, 0.18, 0.1), Vector3(-0.45, 0.45, -3.95), Vector3(0, 0, 20), Color(0.25, 0.3, 0.38)],
				["box", Vector3(0.35, 0.18, 0.1), Vector3(0.45, 0.45, -3.95), Vector3(0, 0, -20), Color(0.25, 0.3, 0.38)],
				# brow and glowing eyes
				["box", Vector3(3.6, 0.45, 0.8), Vector3(0, 1.55, -1.6), Vector3(-10, 0, 0), fur.darkened(0.25)],
				["oval", Vector3(0.45, 0.3, 0.25), 8, Vector3(-1.15, 1.15, -2.0), Vector3(0, 25, 0), glow],
				["oval", Vector3(0.45, 0.3, 0.25), 8, Vector3(1.15, 1.15, -2.0), Vector3(0, -25, 0), glow],
				# long ears drooping out to the sides
				["oval", Vector3(1.1, 0.25, 0.5), 6, Vector3(-2.6, 1.2, -0.4), Vector3(0, 10, 25), fur],
				["oval", Vector3(1.1, 0.25, 0.5), 6, Vector3(2.6, 1.2, -0.4), Vector3(0, -10, -25), fur],
				["sub", Vector3(-1.5, 2.1, 0.0), Vector3(0, 0, 0), _ram_horn(horn, -1.0)],
				["sub", Vector3(1.5, 2.1, 0.0), Vector3(0, 0, 0), _ram_horn(horn, 1.0)],
				["joint", "Tail", Vector3(0, 0.8, 1.8), _cloud_mane(cloud)],
				["joint", "ArmL", Vector3(-4.4, 0.6, -2.4), _paw(-4.4, fur, light, horn, cloud)],
				["joint", "ArmR", Vector3(4.4, 0.6, -2.4), _paw(4.4, fur, light, horn, cloud)],
			]
			top = 5.2
		"gust_sprite":
			# A puff of cloud with a face and a curl of wind for a tail.
			animal = false
			style = "float"
			torso = ["ball", 0.36, 8, Vector3.ZERO]
			parts = [
				["ball", 0.2, 6, Vector3(-0.28, 0.08, 0.05), Vector3.ZERO, main.lightened(0.3)],
				["ball", 0.22, 6, Vector3(0.27, 0.1, 0.04), Vector3.ZERO, main.lightened(0.3)],
				["ball", 0.2, 6, Vector3(0.0, 0.3, 0.06), Vector3.ZERO, main.lightened(0.3)],
				["box", Vector3(0.06, 0.09, 0.03), Vector3(-0.1, 0.06, -0.345), Vector3.ZERO, BLACK],
				["box", Vector3(0.06, 0.09, 0.03), Vector3(0.1, 0.06, -0.345), Vector3.ZERO, BLACK],
				["cyl", 0.045, 0.045, 0.03, 6, Vector3(0, -0.1, -0.35), Vector3(90, 0, 0), Color(0.2, 0.3, 0.45)],
				["joint", "Tail", Vector3(0, 0, 0.3), [
					["cyl", 0.0, 0.12, 0.5, 6, Vector3(0, 0.0, 0.55), Vector3(-80, 0, 0), main.lightened(0.15)],
					["cyl", 0.0, 0.06, 0.3, 6, Vector3(0.12, 0.12, 0.75), Vector3(-30, 0, -40), main.lightened(0.15)],
				]],
			]
			top = 1.5
		"shadow_sprite":
			# A wisp of shadow: a dark flame with glowing eyes.
			animal = false
			style = "float"
			var glow := Color(1.0, 0.75, 1.0)
			torso = ["ball", 0.32, 8, Vector3.ZERO]
			parts = [
				["cyl", 0.0, 0.26, 0.5, 6, Vector3(0, 0.38, 0.08), Vector3(-15, 0, 0), main.darkened(0.25)],
				["cyl", 0.0, 0.14, 0.3, 5, Vector3(-0.17, 0.26, 0.1), Vector3(-10, 0, 25), main.darkened(0.15)],
				["cyl", 0.0, 0.14, 0.3, 5, Vector3(0.17, 0.26, 0.1), Vector3(-10, 0, -25), main.darkened(0.15)],
				["box", Vector3(0.08, 0.05, 0.03), Vector3(-0.1, 0.05, -0.31), Vector3(0, 0, -15), glow],
				["box", Vector3(0.08, 0.05, 0.03), Vector3(0.1, 0.05, -0.31), Vector3(0, 0, 15), glow],
				["joint", "Tail", Vector3(0, -0.15, 0.2), [
					["cyl", 0.0, 0.16, 0.55, 5, Vector3(0, -0.35, 0.35), Vector3(-130, 0, 0), main.darkened(0.35)],
				]],
			]
			top = 1.5
		_:
			return false
	body.mesh = F._shape(torso, Transform3D(Basis.from_scale(torso[1]) if torso[0] == "oval" else Basis(), torso[torso.size() - 1]))
	body.material_override = F.material(main)
	if animal:
		F._add_parts(body, F._rig(parts))
		body.scale = scale
		body.position.y = 0.9 * scale.y
		top = 1.95 * scale.y
	else:
		F._add_parts(body, parts)
	c.set_meta("figure_style", style)
	var nose := c.get_node_or_null("Nose") as Node3D
	if nose:
		nose.visible = false
		nose.set_meta("figure", true)  # the face shows where it looks
	var label := c.get_node_or_null("NameLabel") as Node3D
	if label:
		label.position.y = maxf(label.position.y, top + 0.35)
	return true


static func _ringed_tail(fur: Color, dark: Color) -> Array:
	var out := []
	for i in 5:
		var z := 0.36 + i * 0.12
		var y := -0.42 - i * 0.07
		out.append(["oval", Vector3(0.1, 0.1, 0.075), 6, Vector3(0, y, z), Vector3(-60, 0, 0), dark if i % 2 == 1 else fur])
	return out


static func _dragon_leg(x: float, z: float, hide: Color, claw: Color) -> Array:
	return [
		["cyl", 0.16, 0.2, 0.45, 6, Vector3(x, -0.35, z), Vector3.ZERO, hide],
		["box", Vector3(0.3, 0.12, 0.34), Vector3(x, -0.63, z - 0.05), Vector3.ZERO, hide.darkened(0.15)],
		["box", Vector3(0.24, 0.05, 0.06), Vector3(x, -0.66, z - 0.24), Vector3.ZERO, claw],
	]


## Gale Maw's mane: puffs of cloud round the back of its head.
static func _cloud_mane(cloud: Color) -> Array:
	var out := []
	for i in 9:
		var a := deg_to_rad(-100.0 + i * 25.0)
		out.append(["ball", 0.75 + 0.2 * (i % 2), 6, Vector3(sin(a) * 2.7, 1.2 + cos(a) * 1.6, 2.1), Vector3.ZERO, cloud])
	return out


## A ram's horn curling out and back down beside the head; side -1 left.
static func _ram_horn(horn: Color, side: float) -> Array:
	var out := []
	var r := 0.95
	for i in 9:
		var a := deg_to_rad(-30.0 + i * 40.0)  # round from the top, out, down, forward
		var size := 0.55 - i * 0.04
		var at := Vector3(side * (0.5 + r * sin(a) * 0.9), r * cos(a), 0.2 + i * 0.05)
		out.append(["box", Vector3(size, size, size * 1.2), at, Vector3(0, 0, -side * rad_to_deg(a)), horn.darkened(0.06 * (i % 2))])
	return out


## A huge hovering paw, pads down, claws toward the arena (-Z), a puff of
## cloud at the wrist. x: which side it hovers on.
static func _paw(x: float, fur: Color, light: Color, claw: Color, cloud: Color) -> Array:
	var y := 0.6
	var z := -2.4
	var out := [
		["oval", Vector3(1.0, 0.45, 1.1), 8, Vector3(x, y, z), Vector3.ZERO, fur],
		["oval", Vector3(0.8, 0.2, 0.85), 8, Vector3(x, y - 0.32, z + 0.05), Vector3.ZERO, light],
		["ball", 0.65, 6, Vector3(x, y + 0.15, z + 1.05), Vector3.ZERO, cloud],
	]
	for i in 4:
		var dx := (-0.6 + i * 0.4)
		out.append(["oval", Vector3(0.24, 0.24, 0.32), 6, Vector3(x + dx, y - 0.05, z - 1.0), Vector3.ZERO, fur])
		out.append(["cyl", 0.0, 0.09, 0.35, 4, Vector3(x + dx, y - 0.12, z - 1.4), Vector3(-80, 0, 0), claw])
	return out
