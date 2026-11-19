class_name MoveAnims
extends RefCounted
## One animation per party attack and Art, played by FigureAnim on every
## hit. A sequence is a list of key poses over time:
##
##   {"len": seconds, "impact": seconds the blow lands, "keys": [[t, pose], ...],
##    "trail": true (weapon trail), "ghost": true (afterimages),
##    "build": pose (optional: the coiled pose held while a long block
##    builds up to the hit; otherwise the first key)}
##
## A pose holds joint turns in degrees (Head, ArmL, ArmR, LegL, LegR, Tail,
## and WeapR / WeapL: a held weapon turned at the wrist),
## "lean" (the whole body's turn), "step" (the body moved, metres, -Z is
## forward) and "dash" (0-1: that share of the way to the target, for
## dashes; it comes back by the end). Arms and legs: negative X swings them
## forward and up; Head and lean: positive X tips forward. Lean Y spins (a
## full -360 is a spin that ends facing forward). The sequence starts from
## the pose the fighter was in and ends at rest.
##
## A move with several hits can give one sequence per hit: {"hits": [seq,
## seq, ...]} (the last one repeats). Moves without an entry use the class's
## basic swing (FigureAnim._attack_poses).

const DATA := {
	"monk": {
		# Fists, feet, head and shell; his guard stays up between blows.
		"Punch": {"hits": [
			{"len": 0.22, "impact": 0.08,
				"keys": [
				# jab
				[0.04, {"ArmL": Vector3(-40, 0, 10), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(0, 10, 0)}],
				[0.08, {"ArmL": Vector3(-92, 0, -5), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(4, 15, 0), "step": Vector3(0, 0, -0.1)}],
			]},
			{"len": 0.22, "impact": 0.08,
				"keys": [
				# cross
				[0.04, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-30, 0, -10), "lean": Vector3(0, -10, 0)}],
				[0.08, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-92, 0, 5), "lean": Vector3(6, -22, 0), "step": Vector3(0, 0, -0.15), "LegR": Vector3(15, 0, 0), "LegL": Vector3(-15, 0, 0)}],
			]},
			{"len": 0.3, "impact": 0.08,
				"keys": [
				# jab
				[0.04, {"ArmL": Vector3(-40, 0, 10), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(0, 10, 0)}],
				[0.08, {"ArmL": Vector3(-92, 0, -5), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(4, 15, 0), "step": Vector3(0, 0, -0.1)}],
				[0.16, {"ArmL": Vector3(-92, 0, -5), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(4, 15, 0), "step": Vector3(0, 0, -0.1)}],
			]},
		]},
		"Kick": {"hits": [
			{"len": 0.32, "impact": 0.12,
				"keys": [
				# front kick
				[0.06, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "LegR": Vector3(-60, 0, 0), "lean": Vector3(-6, 0, 0)}],
				[0.12, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "LegR": Vector3(-95, 0, 0), "lean": Vector3(-12, 0, 0), "step": Vector3(0, 0, -0.1)}],
			]},
			{"len": 0.42, "impact": 0.14,
				"keys": [
				# roundhouse
				[0.07, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-4, 30, 0), "LegL": Vector3(-40, 0, -30)}],
				[0.14, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-10, -40, 0), "LegL": Vector3(-90, 0, -55), "step": Vector3(0, 0, -0.05)}],
				[0.24, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-10, -40, 0), "LegL": Vector3(-90, 0, -55), "step": Vector3(0, 0, -0.05)}],
			]},
		]},
		"Heavy Punch": {"len": 0.6, "impact": 0.24,
			"build": {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(45, 0, 10), "lean": Vector3(-6, 35, 0), "step": Vector3(0, -0.05, 0.08), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)},
			"keys": [
			# the fist drawn back to the hip, then driven through
			[0.12, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(45, 0, 10), "lean": Vector3(-6, 35, 0), "step": Vector3(0, -0.05, 0.08), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)}],
			[0.24, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-95, 0, 0), "lean": Vector3(12, -30, 0), "step": Vector3(0, -0.05, -0.3), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}],
			[0.38, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-95, 0, 0), "lean": Vector3(12, -30, 0), "step": Vector3(0, -0.05, -0.3), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}],
		]},
		"Heavy Kick": {"len": 0.75, "impact": 0.3,
			"build": {"ArmL": Vector3(-40, 0, 40), "ArmR": Vector3(-40, 0, -40), "LegR": Vector3(-155, 0, 0), "lean": Vector3(-18, 0, 0)},
			"keys": [
			# an axe kick: the heel high, brought down
			[0.15, {"ArmL": Vector3(-40, 0, 40), "ArmR": Vector3(-40, 0, -40), "LegR": Vector3(-155, 0, 0), "lean": Vector3(-18, 0, 0)}],
			[0.3, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "LegR": Vector3(-35, 0, 0), "lean": Vector3(16, 0, 0), "step": Vector3(0, -0.1, -0.2)}],
			[0.48, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "LegR": Vector3(-35, 0, 0), "lean": Vector3(16, 0, 0), "step": Vector3(0, -0.1, -0.2)}],
		]},
		"Headbutt": {"len": 0.7, "impact": 0.28, "ghost": true,
			"build": {"ArmL": Vector3(40, 0, 20), "ArmR": Vector3(40, 0, -20), "lean": Vector3(-25, 0, 0), "Head": Vector3(-20, 0, 0), "step": Vector3(0, 0, 0.12)},
			"keys": [
			# reared back, then the whole shell behind his head
			[0.14, {"ArmL": Vector3(40, 0, 20), "ArmR": Vector3(40, 0, -20), "lean": Vector3(-25, 0, 0), "Head": Vector3(-20, 0, 0), "step": Vector3(0, 0, 0.12)}],
			[0.28, {"ArmL": Vector3(50, 0, 20), "ArmR": Vector3(50, 0, -20), "lean": Vector3(35, 0, 0), "Head": Vector3(25, 0, 0), "step": Vector3(0, -0.1, -0.35), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(30, 0, 0)}],
			[0.45, {"ArmL": Vector3(50, 0, 20), "ArmR": Vector3(50, 0, -20), "lean": Vector3(35, 0, 0), "Head": Vector3(25, 0, 0), "step": Vector3(0, -0.1, -0.35), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(30, 0, 0)}],
		]},
		"Palm Strike": {"len": 0.7, "impact": 0.26,
			"build": {"ArmL": Vector3(30, 0, 25), "ArmR": Vector3(30, 0, -25), "lean": Vector3(-6, 0, 0), "step": Vector3(0, -0.2, 0.08), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(25, 0, 0)},
			"keys": [
			# both palms gathered at the hips, then thrust out together
			[0.14, {"ArmL": Vector3(30, 0, 25), "ArmR": Vector3(30, 0, -25), "lean": Vector3(-6, 0, 0), "step": Vector3(0, -0.2, 0.08), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(25, 0, 0)}],
			[0.26, {"ArmL": Vector3(-92, 0, 12), "ArmR": Vector3(-92, 0, -12), "lean": Vector3(10, 0, 0), "step": Vector3(0, -0.1, -0.3), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(30, 0, 0)}],
			[0.45, {"ArmL": Vector3(-92, 0, 12), "ArmR": Vector3(-92, 0, -12), "lean": Vector3(10, 0, 0), "step": Vector3(0, -0.1, -0.3), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(30, 0, 0)}],
		]},
		"Flash Kick": {"len": 0.75, "impact": 0.3, "ghost": true,
			"build": {"ArmL": Vector3(20, 0, 30), "ArmR": Vector3(20, 0, -30), "step": Vector3(0, -0.3, 0), "lean": Vector3(15, 0, 0), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-40, 0, 0)},
			"keys": [
			# a crouch, then a backflip that kicks it away
			[0.15, {"ArmL": Vector3(20, 0, 30), "ArmR": Vector3(20, 0, -30), "step": Vector3(0, -0.3, 0), "lean": Vector3(15, 0, 0), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-40, 0, 0)}],
			[0.3, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-200, 0, 0), "step": Vector3(0, 0.7, 0.1), "LegR": Vector3(-160, 0, 0), "LegL": Vector3(-30, 0, 0)}],
			[0.45, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-360, 0, 0), "step": Vector3(0, 0.25, 0.2), "LegL": Vector3(-20, 0, 0), "LegR": Vector3(-20, 0, 0)}],
			[0.6, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-360, 0, 0)}],
		]},
		"Knee Smash": {"len": 0.7, "impact": 0.28,
			"build": {"ArmL": Vector3(-115, 0, -10), "ArmR": Vector3(-115, 0, 10), "step": Vector3(0, 0, -0.1), "lean": Vector3(4, 0, 0)},
			"keys": [
			# it's grabbed and pulled down onto a rising knee
			[0.14, {"ArmL": Vector3(-115, 0, -10), "ArmR": Vector3(-115, 0, 10), "step": Vector3(0, 0, -0.1), "lean": Vector3(4, 0, 0)}],
			[0.28, {"ArmL": Vector3(-60, 0, -10), "ArmR": Vector3(-60, 0, 10), "LegR": Vector3(-115, 0, 0), "lean": Vector3(15, 0, 0), "step": Vector3(0, 0.12, -0.2)}],
			[0.45, {"ArmL": Vector3(-60, 0, -10), "ArmR": Vector3(-60, 0, 10), "LegR": Vector3(-115, 0, 0), "lean": Vector3(15, 0, 0), "step": Vector3(0, 0.12, -0.2)}],
		]},
		"Triple Rush": {"hits": [
			{"len": 0.22, "impact": 0.08,
				"keys": [
				# jab
				[0.04, {"ArmL": Vector3(-40, 0, 10), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(0, 10, 0)}],
				[0.08, {"ArmL": Vector3(-92, 0, -5), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(4, 15, 0), "step": Vector3(0, 0, -0.1)}],
			]},
			{"len": 0.22, "impact": 0.08,
				"keys": [
				# cross
				[0.04, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-30, 0, -10), "lean": Vector3(0, -10, 0)}],
				[0.08, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-92, 0, 5), "lean": Vector3(6, -22, 0), "step": Vector3(0, 0, -0.15), "LegR": Vector3(15, 0, 0), "LegL": Vector3(-15, 0, 0)}],
			]},
			{"len": 0.75, "impact": 0.3, "ghost": true,
				"keys": [
				# a flying kick
				[0.15, {"ArmL": Vector3(20, 0, 30), "ArmR": Vector3(20, 0, -30), "step": Vector3(0, -0.3, 0), "lean": Vector3(15, 0, 0), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-40, 0, 0)}],
				[0.3, {"ArmL": Vector3(-40, 0, 50), "ArmR": Vector3(-40, 0, -50), "step": Vector3(0, 0.6, -0.5), "LegR": Vector3(-90, 0, 0), "LegL": Vector3(10, 0, 0), "lean": Vector3(-10, 0, 0)}],
				[0.5, {"ArmL": Vector3(-40, 0, 50), "ArmR": Vector3(-40, 0, -50), "step": Vector3(0, 0.6, -0.5), "LegR": Vector3(-90, 0, 0), "LegL": Vector3(10, 0, 0), "lean": Vector3(-10, 0, 0)}],
			]},
		]},
		"Mountain Crusher": {"hits": [
			{"len": 0.5, "impact": 0.2,
				"keys": [
				# a heavy punch
				[0.1, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(45, 0, 10), "lean": Vector3(-6, 35, 0), "step": Vector3(0, -0.05, 0.08), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)}],
				[0.2, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-95, 0, 0), "lean": Vector3(12, -30, 0), "step": Vector3(0, -0.05, -0.3), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}],
			]},
			{"len": 0.3, "impact": 0.12,
				"keys": [
				# a kick
				[0.06, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "LegR": Vector3(-60, 0, 0), "lean": Vector3(-6, 0, 0)}],
				[0.12, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "LegR": Vector3(-95, 0, 0), "lean": Vector3(-12, 0, 0), "step": Vector3(0, 0, -0.1)}],
			]},
			{"len": 0.42, "impact": 0.14,
				"keys": [
				# a roundhouse
				[0.07, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-4, 30, 0), "LegL": Vector3(-40, 0, -30)}],
				[0.14, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-10, -40, 0), "LegL": Vector3(-90, 0, -55), "step": Vector3(0, 0, -0.05)}],
			]},
			{"len": 1, "impact": 0.4, "ghost": true,
				"keys": [
				# a leap, both fists brought down into the ground
				[0.15, {"ArmL": Vector3(20, 0, 30), "ArmR": Vector3(20, 0, -30), "step": Vector3(0, -0.3, 0), "lean": Vector3(15, 0, 0), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-40, 0, 0)}],
				[0.3, {"ArmL": Vector3(-170, 0, 20), "ArmR": Vector3(-170, 0, -20), "step": Vector3(0, 0.75, -0.1), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-40, 0, 0), "lean": Vector3(-8, 0, 0)}],
				[0.4, {"ArmL": Vector3(-40, 0, 10), "ArmR": Vector3(-40, 0, -10), "step": Vector3(0, -0.35, -0.2), "lean": Vector3(40, 0, 0), "LegL": Vector3(-60, 0, 0), "LegR": Vector3(40, 0, 0), "Head": Vector3(20, 0, 0)}],
				[0.7, {"ArmL": Vector3(-40, 0, 10), "ArmR": Vector3(-40, 0, -10), "step": Vector3(0, -0.35, -0.2), "lean": Vector3(40, 0, 0), "LegL": Vector3(-60, 0, 0), "LegR": Vector3(40, 0, 0), "Head": Vector3(20, 0, 0)}],
			]},
		]},
		"Tortoise Special": {"hits": [
			{"len": 0.5, "impact": 0.2,
				"keys": [
				# a heavy punch
				[0.1, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(45, 0, 10), "lean": Vector3(-6, 35, 0), "step": Vector3(0, -0.05, 0.08), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)}],
				[0.2, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-95, 0, 0), "lean": Vector3(12, -30, 0), "step": Vector3(0, -0.05, -0.3), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}],
			]},
			{"len": 0.6, "impact": 0.24,
				"keys": [
				# an axe kick
				[0.12, {"ArmL": Vector3(-40, 0, 40), "ArmR": Vector3(-40, 0, -40), "LegR": Vector3(-155, 0, 0), "lean": Vector3(-18, 0, 0)}],
				[0.24, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-60, 0, -15), "LegR": Vector3(-35, 0, 0), "lean": Vector3(16, 0, 0), "step": Vector3(0, -0.1, -0.2)}],
			]},
			{"len": 1.25, "impact": 0.6, "windup_hand": "ArmR",
				"build": {"ArmL": Vector3(-75, 0, 12), "ArmR": Vector3(-75, 0, -12), "step": Vector3(0, -0.15, -0.05), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(25, 0, 0), "lean": Vector3(12, 0, 0)},
				"keys": [
				# the flurry (a punch per tap, on top), the right fist drawn slowly back, the last big punch, then he rolls back in his shell
				[0.5, {"ArmL": Vector3(-80, 0, 12), "ArmR": Vector3(60, 0, 15), "lean": Vector3(-8, 45, 0), "step": Vector3(0, -0.15, 0.1), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}],
				[0.6, {"ArmL": Vector3(-70, 0, 15), "ArmR": Vector3(-100, 0, 0), "lean": Vector3(16, -35, 0), "step": Vector3(0, -0.05, -0.35), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(30, 0, 0)}],
				[0.8, {"ArmL": Vector3(-20, 0, 40), "ArmR": Vector3(-20, 0, -40), "step": Vector3(0, -0.3, 0.35), "Head": Vector3(30, 0, 0), "lean": Vector3(30, -360, 0), "LegL": Vector3(-60, 0, 0), "LegR": Vector3(-60, 0, 0)}],
				[1.05, {"ArmL": Vector3(-20, 0, 40), "ArmR": Vector3(-20, 0, -40), "step": Vector3(0, -0.3, 0.5), "Head": Vector3(30, 0, 0), "lean": Vector3(30, -720, 0), "LegL": Vector3(-60, 0, 0), "LegR": Vector3(-60, 0, 0)}],
			]},
		]},
	},
	"assassin": {
		# A dagger in each hand, each turning at the wrist (WeapR / WeapL);
		# Shadowstep moves sink into a crouch and come out behind the target.
		"Stab": {"len": 0.5, "impact": 0.2, "trail": true,
			"build": {"ArmR": Vector3(25, 0, 0), "WeapR": Vector3(-25, 0, 0), "ArmL": Vector3(-50, 0, 20), "WeapL": Vector3(50, 0, 0), "lean": Vector3(-4, 20, 0), "step": Vector3(0, 0, 0.06)},
			"keys": [
			# a quick thrust with the right dagger
			[0.1, {"ArmR": Vector3(25, 0, 0), "WeapR": Vector3(-25, 0, 0), "ArmL": Vector3(-50, 0, 20), "WeapL": Vector3(50, 0, 0), "lean": Vector3(-4, 20, 0), "step": Vector3(0, 0, 0.06)}],
			[0.2, {"ArmR": Vector3(-90, 0, 5), "WeapR": Vector3(90, 0, 0), "ArmL": Vector3(-30, 0, 20), "WeapL": Vector3(30, 0, 0), "lean": Vector3(10, -15, 0), "step": Vector3(0, -0.05, -0.25), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)}],
			[0.32, {"ArmR": Vector3(-90, 0, 5), "WeapR": Vector3(90, 0, 0), "ArmL": Vector3(-30, 0, 20), "WeapL": Vector3(30, 0, 0), "lean": Vector3(10, -15, 0), "step": Vector3(0, -0.05, -0.25), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)}],
		]},
		"Shadowstep": {"len": 0.7, "impact": 0.3, "trail": true, "ghost": true,
			"build": {"ArmR": Vector3(-40, 0, -40), "WeapR": Vector3(40, 0, 0), "ArmL": Vector3(-40, 0, 40), "WeapL": Vector3(40, 0, 0), "step": Vector3(0, -0.3, 0.05), "lean": Vector3(25, 0, 0), "Head": Vector3(10, 0, 0)},
			"keys": [
			# he sinks into the shadows and comes out behind it, slashing
			[0.15, {"ArmR": Vector3(-40, 0, -40), "WeapR": Vector3(40, 0, 0), "ArmL": Vector3(-40, 0, 40), "WeapL": Vector3(40, 0, 0), "step": Vector3(0, -0.3, 0.05), "lean": Vector3(25, 0, 0), "Head": Vector3(10, 0, 0)}],
			[0.3, {"ArmR": Vector3(-85, 0, -60), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-30, 0, 30), "WeapL": Vector3(30, 0, 0), "lean": Vector3(10, -30, 0), "step": Vector3(0, -0.1, -0.15)}],
			[0.45, {"ArmR": Vector3(-85, 0, -60), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-30, 0, 30), "WeapL": Vector3(30, 0, 0), "lean": Vector3(10, -30, 0), "step": Vector3(0, -0.1, -0.15)}],
		]},
		"Backstab": {"len": 0.65, "impact": 0.26, "trail": true,
			"build": {"ArmR": Vector3(-160, 0, 0), "WeapR": Vector3(250, 0, 0), "ArmL": Vector3(-40, 0, 30), "WeapL": Vector3(40, 0, 0), "lean": Vector3(-6, 10, 0), "step": Vector3(0, 0.1, 0), "Head": Vector3(-10, 0, 0)},
			"keys": [
			# the dagger raised point-down, plunged in
			[0.14, {"ArmR": Vector3(-160, 0, 0), "WeapR": Vector3(250, 0, 0), "ArmL": Vector3(-40, 0, 30), "WeapL": Vector3(40, 0, 0), "lean": Vector3(-6, 10, 0), "step": Vector3(0, 0.1, 0), "Head": Vector3(-10, 0, 0)}],
			[0.26, {"ArmR": Vector3(-70, 0, 0), "WeapR": Vector3(160, 0, 0), "ArmL": Vector3(-30, 0, 30), "WeapL": Vector3(30, 0, 0), "lean": Vector3(20, -5, 0), "step": Vector3(0, -0.15, -0.2), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}],
			[0.42, {"ArmR": Vector3(-70, 0, 0), "WeapR": Vector3(160, 0, 0), "ArmL": Vector3(-30, 0, 30), "WeapL": Vector3(30, 0, 0), "lean": Vector3(20, -5, 0), "step": Vector3(0, -0.15, -0.2), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}],
		]},
		"Execute": {"len": 0.95, "impact": 0.36, "trail": true, "ghost": true,
			"build": {"ArmR": Vector3(-170, 0, 15), "WeapR": Vector3(260, 0, 0), "ArmL": Vector3(-170, 0, -15), "WeapL": Vector3(260, 0, 0), "step": Vector3(0, -0.2, 0.05), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-40, 0, 0), "Head": Vector3(-15, 0, 0)},
			"keys": [
			# both daggers high, a leap, both plunged in
			[0.2, {"ArmR": Vector3(-170, 0, 15), "WeapR": Vector3(260, 0, 0), "ArmL": Vector3(-170, 0, -15), "WeapL": Vector3(260, 0, 0), "step": Vector3(0, -0.2, 0.05), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-40, 0, 0), "Head": Vector3(-15, 0, 0)}],
			[0.28, {"ArmR": Vector3(-170, 0, 15), "WeapR": Vector3(260, 0, 0), "ArmL": Vector3(-170, 0, -15), "WeapL": Vector3(260, 0, 0), "step": Vector3(0, 0.6, -0.2), "lean": Vector3(-8, 0, 0), "LegL": Vector3(-60, 0, 0), "LegR": Vector3(-20, 0, 0)}],
			[0.36, {"ArmR": Vector3(-60, 0, 0), "WeapR": Vector3(150, 0, 0), "ArmL": Vector3(-60, 0, 0), "WeapL": Vector3(150, 0, 0), "lean": Vector3(25, 0, 0), "step": Vector3(0, -0.2, -0.35), "LegL": Vector3(-50, 0, 0), "LegR": Vector3(40, 0, 0)}],
			[0.62, {"ArmR": Vector3(-60, 0, 0), "WeapR": Vector3(150, 0, 0), "ArmL": Vector3(-60, 0, 0), "WeapL": Vector3(150, 0, 0), "lean": Vector3(25, 0, 0), "step": Vector3(0, -0.2, -0.35), "LegL": Vector3(-50, 0, 0), "LegR": Vector3(40, 0, 0)}],
		]},
		"Ambush": {"len": 0.8, "impact": 0.34, "trail": true, "ghost": true,
			"build": {"ArmR": Vector3(-40, 0, -40), "WeapR": Vector3(40, 0, 0), "ArmL": Vector3(-40, 0, 40), "WeapL": Vector3(40, 0, 0), "step": Vector3(0, -0.3, 0.05), "lean": Vector3(25, 0, 0), "Head": Vector3(10, 0, 0)},
			"keys": [
			# out of the shadows behind it: a slash, then a kick that sends it flying
			[0.15, {"ArmR": Vector3(-40, 0, -40), "WeapR": Vector3(40, 0, 0), "ArmL": Vector3(-40, 0, 40), "WeapL": Vector3(40, 0, 0), "step": Vector3(0, -0.3, 0.05), "lean": Vector3(25, 0, 0), "Head": Vector3(10, 0, 0)}],
			[0.24, {"ArmR": Vector3(-85, 0, -60), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-30, 0, 30), "WeapL": Vector3(30, 0, 0), "lean": Vector3(10, -30, 0), "step": Vector3(0, -0.1, -0.15)}],
			[0.34, {"ArmR": Vector3(-40, 0, 0), "WeapR": Vector3(40, 0, 0), "ArmL": Vector3(-30, 0, 30), "WeapL": Vector3(30, 0, 0), "LegR": Vector3(-95, 0, 0), "LegL": Vector3(10, 0, 0), "lean": Vector3(-15, 0, 0), "step": Vector3(0, 0, -0.1)}],
			[0.55, {"ArmR": Vector3(-40, 0, 0), "WeapR": Vector3(40, 0, 0), "ArmL": Vector3(-30, 0, 30), "WeapL": Vector3(30, 0, 0), "LegR": Vector3(-95, 0, 0), "LegL": Vector3(10, 0, 0), "lean": Vector3(-15, 0, 0), "step": Vector3(0, 0, -0.1)}],
		]},
		"Twin Fangs": {"hits": [
			{"len": 0.45, "impact": 0.18, "trail": true,
				"keys": [
				# right fang
				[0.09, {"ArmR": Vector3(25, 0, 0), "WeapR": Vector3(-25, 0, 0), "ArmL": Vector3(-50, 0, 20), "WeapL": Vector3(50, 0, 0), "lean": Vector3(-4, 20, 0), "step": Vector3(0, 0, 0.06)}],
				[0.18, {"ArmR": Vector3(-90, 0, 5), "WeapR": Vector3(90, 0, 0), "ArmL": Vector3(-30, 0, 20), "WeapL": Vector3(30, 0, 0), "lean": Vector3(10, -15, 0), "step": Vector3(0, -0.05, -0.25), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)}],
			]},
			{"len": 0.45, "impact": 0.18, "trail": true,
				"keys": [
				# left fang
				[0.09, {"ArmL": Vector3(25, 0, 0), "WeapL": Vector3(-25, 0, 0), "ArmR": Vector3(-50, 0, -20), "WeapR": Vector3(50, 0, 0), "lean": Vector3(-4, -20, 0), "step": Vector3(0, 0, 0.06)}],
				[0.18, {"ArmL": Vector3(-90, 0, -5), "WeapL": Vector3(90, 0, 0), "ArmR": Vector3(-30, 0, -20), "WeapR": Vector3(30, 0, 0), "lean": Vector3(10, 15, 0), "step": Vector3(0, -0.05, -0.25), "LegL": Vector3(20, 0, 0), "LegR": Vector3(-30, 0, 0)}],
			]},
		]},
		"Phantom Rush": {"hits": [
			{"len": 0.6, "impact": 0.28, "trail": true, "ghost": true,
				"keys": [
				# out of the shadows: a slash
				[0.14, {"ArmR": Vector3(-40, 0, -40), "WeapR": Vector3(40, 0, 0), "ArmL": Vector3(-40, 0, 40), "WeapL": Vector3(40, 0, 0), "step": Vector3(0, -0.3, 0.05), "lean": Vector3(25, 0, 0), "Head": Vector3(10, 0, 0)}],
				[0.28, {"ArmR": Vector3(-85, 0, -60), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-30, 0, 30), "WeapL": Vector3(30, 0, 0), "lean": Vector3(10, -30, 0), "step": Vector3(0, -0.1, -0.15)}],
			]},
			{"len": 0.6, "impact": 0.25, "trail": true, "ghost": true,
				"keys": [
				# a full spin, both blades out
				[0.1, {"ArmR": Vector3(-85, 0, 55), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-30, 0, 30), "WeapL": Vector3(30, 0, 0), "lean": Vector3(10, 35, 0), "step": Vector3(0, -0.1, -0.1)}],
				[0.25, {"ArmR": Vector3(-85, 0, -60), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-85, 0, 60), "WeapL": Vector3(85, 0, 0), "lean": Vector3(10, -360, 0), "step": Vector3(0, -0.1, -0.1)}],
				[0.4, {"ArmR": Vector3(-85, 0, -60), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-85, 0, 60), "WeapL": Vector3(85, 0, 0), "lean": Vector3(10, -360, 0), "step": Vector3(0, -0.1, -0.1)}],
			]},
		]},
		"Cutthroat": {"hits": [
			{"len": 0.5, "impact": 0.2, "trail": true,
				"keys": [
				# a low stab to the side
				[0.1, {"ArmL": Vector3(25, 0, 0), "WeapL": Vector3(-25, 0, 0), "ArmR": Vector3(-50, 0, -20), "WeapR": Vector3(50, 0, 0), "lean": Vector3(-4, -20, 0), "step": Vector3(0, 0, 0.06)}],
				[0.2, {"ArmL": Vector3(-60, 0, -10), "WeapL": Vector3(60, 0, 0), "ArmR": Vector3(-20, 0, -20), "WeapR": Vector3(20, 0, 0), "lean": Vector3(20, 15, 0), "step": Vector3(0, -0.2, -0.2), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(30, 0, 0)}],
			]},
			{"len": 0.55, "impact": 0.22, "trail": true,
				"keys": [
				# a cut across the throat
				[0.12, {"ArmR": Vector3(-100, 0, 60), "WeapR": Vector3(100, 0, 0), "ArmL": Vector3(-30, 0, 0), "WeapL": Vector3(30, 0, 0), "lean": Vector3(4, 30, 0), "step": Vector3(0, 0.05, -0.1)}],
				[0.22, {"ArmR": Vector3(-100, 0, -65), "WeapR": Vector3(100, 0, 0), "ArmL": Vector3(-30, 0, 0), "WeapL": Vector3(30, 0, 0), "lean": Vector3(8, -35, 0), "step": Vector3(0, 0.05, -0.15)}],
				[0.38, {"ArmR": Vector3(-100, 0, -65), "WeapR": Vector3(100, 0, 0), "ArmL": Vector3(-30, 0, 0), "WeapL": Vector3(30, 0, 0), "lean": Vector3(8, -35, 0), "step": Vector3(0, 0.05, -0.15)}],
			]},
		]},
		"Thousand Cuts": {"hits": [
			{"len": 0.32, "impact": 0.12, "trail": true, "ghost": true,
				"keys": [
				# cut 1
				[0.06, {"ArmR": Vector3(-85, 0, 55), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-40, 0, 0), "WeapL": Vector3(40, 0, 0), "lean": Vector3(8, 25, 0), "step": Vector3(0, -0.08, -0.1)}],
				[0.12, {"ArmR": Vector3(-85, 0, -60), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-40, 0, 0), "WeapL": Vector3(40, 0, 0), "lean": Vector3(10, -25, 0), "step": Vector3(0, -0.08, -0.2)}],
			]},
			{"len": 0.32, "impact": 0.12, "trail": true, "ghost": true,
				"keys": [
				[0.06, {"ArmL": Vector3(-85, 0, -55), "WeapL": Vector3(85, 0, 0), "ArmR": Vector3(-40, 0, 0), "WeapR": Vector3(40, 0, 0), "lean": Vector3(8, -25, 0), "step": Vector3(0, -0.08, -0.1)}],
				[0.12, {"ArmL": Vector3(-85, 0, 60), "WeapL": Vector3(85, 0, 0), "ArmR": Vector3(-40, 0, 0), "WeapR": Vector3(40, 0, 0), "lean": Vector3(10, 25, 0), "step": Vector3(0, -0.08, -0.2)}],
			]},
			{"len": 0.32, "impact": 0.12, "trail": true, "ghost": true,
				"keys": [
				[0.06, {"ArmR": Vector3(-85, 0, 55), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-40, 0, 0), "WeapL": Vector3(40, 0, 0), "lean": Vector3(8, 25, 0), "step": Vector3(0, -0.08, -0.1)}],
				[0.12, {"ArmR": Vector3(-85, 0, -60), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-40, 0, 0), "WeapL": Vector3(40, 0, 0), "lean": Vector3(10, -25, 0), "step": Vector3(0, -0.08, -0.2)}],
			]},
			{"len": 0.32, "impact": 0.12, "trail": true, "ghost": true,
				"keys": [
				[0.06, {"ArmL": Vector3(-85, 0, -55), "WeapL": Vector3(85, 0, 0), "ArmR": Vector3(-40, 0, 0), "WeapR": Vector3(40, 0, 0), "lean": Vector3(8, -25, 0), "step": Vector3(0, -0.08, -0.1)}],
				[0.12, {"ArmL": Vector3(-85, 0, 60), "WeapL": Vector3(85, 0, 0), "ArmR": Vector3(-40, 0, 0), "WeapR": Vector3(40, 0, 0), "lean": Vector3(10, 25, 0), "step": Vector3(0, -0.08, -0.2)}],
			]},
			{"len": 0.32, "impact": 0.12, "trail": true, "ghost": true,
				"keys": [
				[0.06, {"ArmR": Vector3(-85, 0, 55), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-40, 0, 0), "WeapL": Vector3(40, 0, 0), "lean": Vector3(8, 25, 0), "step": Vector3(0, -0.08, -0.1)}],
				[0.12, {"ArmR": Vector3(-85, 0, -60), "WeapR": Vector3(85, 0, 0), "ArmL": Vector3(-40, 0, 0), "WeapL": Vector3(40, 0, 0), "lean": Vector3(10, -25, 0), "step": Vector3(0, -0.08, -0.2)}],
			]},
			{"len": 0.7, "impact": 0.24, "trail": true, "ghost": true,
				"keys": [
				# the last: both blades crossed down through it
				[0.12, {"ArmR": Vector3(-150, 0, 40), "WeapR": Vector3(150, 0, 0), "ArmL": Vector3(-150, 0, -40), "WeapL": Vector3(150, 0, 0), "lean": Vector3(-8, 0, 0), "step": Vector3(0, 0.1, 0.05)}],
				[0.24, {"ArmR": Vector3(-60, 0, -45), "WeapR": Vector3(60, 0, 0), "ArmL": Vector3(-60, 0, 45), "WeapL": Vector3(60, 0, 0), "lean": Vector3(18, 0, 0), "step": Vector3(0, -0.2, -0.3), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(30, 0, 0)}],
				[0.45, {"ArmR": Vector3(-60, 0, -45), "WeapR": Vector3(60, 0, 0), "ArmL": Vector3(-60, 0, 45), "WeapL": Vector3(60, 0, 0), "lean": Vector3(18, 0, 0), "step": Vector3(0, -0.2, -0.3), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(30, 0, 0)}],
			]},
		]},
	},
	"cleric": {
		# The staff in her right hand turns at the wrist (WeapR) like the Mage's:
		# her blows are bonks and swings, her light comes from the sun disc on
		# top or from the sky.
		"Bash": {"len": 0.5, "impact": 0.2, "trail": true,
			"build": {"ArmR": Vector3(-150, 0, 0), "WeapR": Vector3(120, 0, 0), "ArmL": Vector3(-30, 0, -20), "lean": Vector3(-6, 15, 0), "step": Vector3(0, 0, 0.05)},
			"keys": [
			# the staff over her head, brought down on the target
			[0.1, {"ArmR": Vector3(-150, 0, 0), "WeapR": Vector3(120, 0, 0), "ArmL": Vector3(-30, 0, -20), "lean": Vector3(-6, 15, 0), "step": Vector3(0, 0, 0.05)}],
			[0.2, {"ArmR": Vector3(-55, 0, 0), "WeapR": Vector3(180, 0, 0), "ArmL": Vector3(-20, 0, 0), "lean": Vector3(14, -10, 0), "step": Vector3(0, -0.05, -0.15), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(15, 0, 0)}],
			[0.32, {"ArmR": Vector3(-55, 0, 0), "WeapR": Vector3(180, 0, 0), "ArmL": Vector3(-20, 0, 0), "lean": Vector3(14, -10, 0), "step": Vector3(0, -0.05, -0.15), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(15, 0, 0)}],
		]},
		"Holy Light": {"len": 0.8, "impact": 0.3,
			"build": {"ArmR": Vector3(-55, 0, 0), "WeapR": Vector3(55, 0, 0), "ArmL": Vector3(-75, 0, 40), "Head": Vector3(15, 0, 0), "lean": Vector3(4, 0, 0)},
			"keys": [
			# a prayer, then the sun disc raised at the target: the beam
			[0.15, {"ArmR": Vector3(-55, 0, 0), "WeapR": Vector3(55, 0, 0), "ArmL": Vector3(-75, 0, 40), "Head": Vector3(15, 0, 0), "lean": Vector3(4, 0, 0)}],
			[0.3, {"ArmR": Vector3(-135, 0, 0), "WeapR": Vector3(190, 0, 0), "ArmL": Vector3(-100, 0, -25), "Head": Vector3(-10, 0, 0), "lean": Vector3(-4, 0, 0), "step": Vector3(0, 0, -0.05)}],
			[0.48, {"ArmR": Vector3(-135, 0, 0), "WeapR": Vector3(190, 0, 0), "ArmL": Vector3(-100, 0, -25), "Head": Vector3(-10, 0, 0), "lean": Vector3(-4, 0, 0), "step": Vector3(0, 0, -0.05)}],
		]},
		"Divine Barrier": {"len": 0.95, "impact": 0.35,
			"build": {"ArmR": Vector3(-120, 0, 0), "WeapR": Vector3(120, 0, 0), "ArmL": Vector3(-60, 0, 30), "step": Vector3(0, 0.08, 0), "Head": Vector3(-10, 0, 0)},
			"keys": [
			# the staff lifted and planted, a hand raised: the barrier
			[0.2, {"ArmR": Vector3(-120, 0, 0), "WeapR": Vector3(120, 0, 0), "ArmL": Vector3(-60, 0, 30), "step": Vector3(0, 0.08, 0), "Head": Vector3(-10, 0, 0)}],
			[0.35, {"ArmR": Vector3(-35, 0, 0), "WeapR": Vector3(35, 0, 0), "ArmL": Vector3(-140, 0, -45), "step": Vector3(0, -0.15, 0), "LegL": Vector3(-20, 0, 0), "LegR": Vector3(15, 0, 0), "Head": Vector3(-15, 0, 0), "lean": Vector3(4, 0, 0)}],
			[0.6, {"ArmR": Vector3(-35, 0, 0), "WeapR": Vector3(35, 0, 0), "ArmL": Vector3(-140, 0, -45), "step": Vector3(0, -0.15, 0), "LegL": Vector3(-20, 0, 0), "LegR": Vector3(15, 0, 0), "Head": Vector3(-15, 0, 0), "lean": Vector3(4, 0, 0)}],
		]},
		"Smite": {"len": 0.85, "impact": 0.32, "trail": true, "ghost": true,
			"build": {"ArmR": Vector3(-170, 0, 0), "WeapR": Vector3(150, 0, 0), "ArmL": Vector3(-170, 0, -10), "lean": Vector3(-12, 0, 0), "step": Vector3(0, -0.15, 0.1), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)},
			"keys": [
			# two hands over her head, a hop, a crushing blow
			[0.15, {"ArmR": Vector3(-170, 0, 0), "WeapR": Vector3(150, 0, 0), "ArmL": Vector3(-170, 0, -10), "lean": Vector3(-12, 0, 0), "step": Vector3(0, -0.15, 0.1), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(20, 0, 0)}],
			[0.24, {"ArmR": Vector3(-160, 0, 0), "WeapR": Vector3(170, 0, 0), "ArmL": Vector3(-160, 0, -10), "lean": Vector3(-4, 0, 0), "step": Vector3(0, 0.35, -0.15), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-10, 0, 0)}],
			[0.32, {"ArmR": Vector3(-60, 0, 0), "WeapR": Vector3(195, 0, 0), "ArmL": Vector3(-60, 0, 10), "lean": Vector3(20, 0, 0), "step": Vector3(0, -0.1, -0.35), "LegL": Vector3(-50, 0, 0), "LegR": Vector3(35, 0, 0)}],
			[0.5, {"ArmR": Vector3(-60, 0, 0), "WeapR": Vector3(195, 0, 0), "ArmL": Vector3(-60, 0, 10), "lean": Vector3(20, 0, 0), "step": Vector3(0, -0.1, -0.35), "LegL": Vector3(-50, 0, 0), "LegR": Vector3(35, 0, 0)}],
		]},
		"Judgment": {"len": 1.05, "impact": 0.38,
			"build": {"ArmR": Vector3(-170, 0, 0), "WeapR": Vector3(170, 0, 0), "ArmL": Vector3(-170, 0, -20), "Head": Vector3(-25, 0, 0), "lean": Vector3(-8, 0, 0)},
			"keys": [
			# both arms to the sky, then the staff planted and a finger at the target
			[0.2, {"ArmR": Vector3(-170, 0, 0), "WeapR": Vector3(170, 0, 0), "ArmL": Vector3(-170, 0, -20), "Head": Vector3(-25, 0, 0), "lean": Vector3(-8, 0, 0)}],
			[0.38, {"ArmR": Vector3(-40, 0, 0), "WeapR": Vector3(40, 0, 0), "ArmL": Vector3(-95, 0, 0), "lean": Vector3(10, 0, 0), "step": Vector3(0, -0.12, -0.05)}],
			[0.62, {"ArmR": Vector3(-40, 0, 0), "WeapR": Vector3(40, 0, 0), "ArmL": Vector3(-95, 0, 0), "lean": Vector3(10, 0, 0), "step": Vector3(0, -0.12, -0.05)}],
		]},
		"Blessed Strike": {"len": 0.95, "impact": 0.36, "trail": true,
			"build": {"ArmR": Vector3(30, 0, 10), "WeapR": Vector3(130, 0, 0), "ArmL": Vector3(-40, 0, 0), "lean": Vector3(12, 30, 0), "step": Vector3(0, -0.2, 0.08), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)},
			"keys": [
			# low, the staff trailing, then an upswing that lifts her
			[0.2, {"ArmR": Vector3(30, 0, 10), "WeapR": Vector3(130, 0, 0), "ArmL": Vector3(-40, 0, 0), "lean": Vector3(12, 30, 0), "step": Vector3(0, -0.2, 0.08), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}],
			[0.36, {"ArmR": Vector3(-165, 0, 0), "WeapR": Vector3(185, 0, 0), "ArmL": Vector3(-120, 0, -30), "lean": Vector3(-10, -20, 0), "step": Vector3(0, 0.12, -0.2), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(10, 0, 0)}],
			[0.6, {"ArmR": Vector3(-165, 0, 0), "WeapR": Vector3(185, 0, 0), "ArmL": Vector3(-120, 0, -30), "lean": Vector3(-10, -20, 0), "step": Vector3(0, 0.12, -0.2), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(10, 0, 0)}],
		]},
		"Sanctuary": {"len": 1.1, "impact": 0.42,
			"build": {"ArmR": Vector3(-100, 0, 0), "WeapR": Vector3(100, 0, 0), "ArmL": Vector3(-95, 0, 35), "Head": Vector3(20, 0, 0), "step": Vector3(0, -0.3, 0), "LegL": Vector3(-85, 0, 0), "LegR": Vector3(40, 0, 0), "lean": Vector3(6, 0, 0)},
			"keys": [
			# kneeling in prayer, then the staff planted and a hand raised
			[0.25, {"ArmR": Vector3(-100, 0, 0), "WeapR": Vector3(100, 0, 0), "ArmL": Vector3(-95, 0, 35), "Head": Vector3(20, 0, 0), "step": Vector3(0, -0.3, 0), "LegL": Vector3(-85, 0, 0), "LegR": Vector3(40, 0, 0), "lean": Vector3(6, 0, 0)}],
			[0.42, {"ArmR": Vector3(-45, 0, 0), "WeapR": Vector3(45, 0, 0), "ArmL": Vector3(-160, 0, -45), "Head": Vector3(-20, 0, 0), "step": Vector3(0, -0.3, 0), "LegL": Vector3(-85, 0, 0), "LegR": Vector3(40, 0, 0), "lean": Vector3(-6, 0, 0)}],
			[0.75, {"ArmR": Vector3(-45, 0, 0), "WeapR": Vector3(45, 0, 0), "ArmL": Vector3(-160, 0, -45), "Head": Vector3(-20, 0, 0), "step": Vector3(0, -0.3, 0), "LegL": Vector3(-85, 0, 0), "LegR": Vector3(40, 0, 0), "lean": Vector3(-6, 0, 0)}],
		]},
		"Divine Judgment": {"hits": [
			{"len": 0.4, "impact": 0.15, "trail": true,
				"keys": [
				# a forehand bonk
				[0.08, {"ArmR": Vector3(-150, 0, 0), "WeapR": Vector3(120, 0, 0), "ArmL": Vector3(-30, 0, -20), "lean": Vector3(-6, 15, 0), "step": Vector3(0, 0, 0.05)}],
				[0.15, {"ArmR": Vector3(-55, 0, 0), "WeapR": Vector3(180, 0, 0), "ArmL": Vector3(-20, 0, 0), "lean": Vector3(14, -10, 0), "step": Vector3(0, -0.05, -0.15), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(15, 0, 0)}],
			]},
			{"len": 0.4, "impact": 0.15, "trail": true,
				"keys": [
				# a backhand sweep
				[0.08, {"ArmR": Vector3(-100, 0, -40), "WeapR": Vector3(190, 0, 0), "lean": Vector3(6, 40, 0), "ArmL": Vector3(-20, 0, 0)}],
				[0.15, {"ArmR": Vector3(-80, 0, 40), "WeapR": Vector3(170, 0, 0), "lean": Vector3(10, -45, 0), "ArmL": Vector3(-20, 0, 0), "step": Vector3(0, 0, -0.1)}],
			]},
			{"len": 1, "impact": 0.4, "trail": true, "ghost": true,
				"keys": [
				# a leap, the staff high, and the slam that calls the light
				[0.15, {"ArmR": Vector3(-170, 0, 0), "WeapR": Vector3(170, 0, 0), "ArmL": Vector3(-170, 0, -15), "step": Vector3(0, -0.25, 0), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-40, 0, 0)}],
				[0.3, {"ArmR": Vector3(-175, 0, 0), "WeapR": Vector3(155, 0, 0), "ArmL": Vector3(-170, 0, -15), "lean": Vector3(-10, 0, 0), "step": Vector3(0, 0.8, -0.3), "LegL": Vector3(-60, 0, 0), "LegR": Vector3(-20, 0, 0)}],
				[0.4, {"ArmR": Vector3(-50, 0, 0), "WeapR": Vector3(190, 0, 0), "ArmL": Vector3(-50, 0, 10), "lean": Vector3(25, 0, 0), "step": Vector3(0, -0.2, -0.4), "LegL": Vector3(-50, 0, 0), "LegR": Vector3(40, 0, 0)}],
				[0.65, {"ArmR": Vector3(-50, 0, 0), "WeapR": Vector3(190, 0, 0), "ArmL": Vector3(-50, 0, 10), "lean": Vector3(25, 0, 0), "step": Vector3(0, -0.2, -0.4), "LegL": Vector3(-50, 0, 0), "LegR": Vector3(40, 0, 0)}],
			]},
		]},
	},
	"mage": {
		# The staff in her right hand turns at the wrist (WeapR) to point at
		# the target or the sky; the left hand casts. Each element has its
		# gesture (Fire a palm thrust, Ice a low sweep, Lightning the staff to
		# the sky and then at the target, Energy a two-handed push); the Arts
		# build on them.
		"Fire": {"len": 0.55, "impact": 0.2, "keys": [
			# Fire: a palm thrust
			[0.12, {"ArmL": Vector3(30, 0, -10), "lean": Vector3(0, 15, 0)}],
			[0.2, {"ArmL": Vector3(-95, 0, 10), "lean": Vector3(8, -15, 0), "step": Vector3(0, 0, -0.12)}],
			[0.32, {"ArmL": Vector3(-95, 0, 10), "lean": Vector3(8, -15, 0), "step": Vector3(0, 0, -0.12)}],
		]},
		"Ice": {"len": 0.6, "impact": 0.22, "keys": [
			# Ice: a low sweeping arc
			[0.12, {"ArmL": Vector3(-40, 0, -70), "lean": Vector3(4, 35, 0), "step": Vector3(0, -0.1, 0)}],
			[0.22, {"ArmL": Vector3(-60, 0, 50), "lean": Vector3(10, -30, 0), "step": Vector3(0, -0.1, -0.1)}],
			[0.34, {"ArmL": Vector3(-60, 0, 50), "lean": Vector3(10, -30, 0), "step": Vector3(0, -0.1, -0.1)}],
		]},
		"Lightning": {"len": 0.6, "impact": 0.22, "trail": true, "keys": [
			# Lightning: the staff to the sky, then pointed at the target
			[0.12, {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "Head": Vector3(-15, 0, 0)}],
			[0.22, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "lean": Vector3(8, 0, 0), "step": Vector3(0, 0, -0.1)}],
			[0.36, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "lean": Vector3(8, 0, 0), "step": Vector3(0, 0, -0.1)}],
		]},
		"Energy Blast": {"len": 0.55, "impact": 0.2, "keys": [
			# Energy: a two-handed push
			[0.12, {"ArmL": Vector3(10, 0, 0), "ArmR": Vector3(10, 0, 0), "lean": Vector3(-6, 0, 0), "step": Vector3(0, 0, 0.08)}],
			[0.2, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-88, 0, 15), "lean": Vector3(10, 0, 0), "step": Vector3(0, 0, -0.15)}],
			[0.32, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-88, 0, 15), "lean": Vector3(10, 0, 0), "step": Vector3(0, 0, -0.15)}],
		]},
		"Fireball": {"len": 0.75, "impact": 0.26,
			"build": {"ArmL": Vector3(10, 0, 30), "ArmR": Vector3(-20, 0, 10), "lean": Vector3(-4, 25, 0), "step": Vector3(0, -0.08, 0.05)},
			"keys": [
			# a ball of fire cupped at her hip, then hurled
			[0.15, {"ArmL": Vector3(10, 0, 30), "ArmR": Vector3(-20, 0, 10), "lean": Vector3(-4, 25, 0), "step": Vector3(0, -0.08, 0.05)}],
			[0.26, {"ArmL": Vector3(-110, 0, 0), "lean": Vector3(12, -20, 0), "step": Vector3(0, 0, -0.2), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(15, 0, 0)}],
			[0.4, {"ArmL": Vector3(-110, 0, 0), "lean": Vector3(12, -20, 0), "step": Vector3(0, 0, -0.2), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(15, 0, 0)}],
		]},
		"Inferno": {"len": 1, "impact": 0.35, "trail": true,
			"build": {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "ArmL": Vector3(-150, 0, -45), "lean": Vector3(-10, 0, 0), "Head": Vector3(-20, 0, 0)},
			"keys": [
			# both arms raised wide, then swept down at the target
			[0.2, {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "ArmL": Vector3(-150, 0, -45), "lean": Vector3(-10, 0, 0), "Head": Vector3(-20, 0, 0)}],
			[0.35, {"ArmR": Vector3(-45, 0, 0), "WeapR": Vector3(172, 0, 0), "ArmL": Vector3(-60, 0, 20), "lean": Vector3(18, 0, 0), "step": Vector3(0, -0.1, -0.15)}],
			[0.55, {"ArmR": Vector3(-45, 0, 0), "WeapR": Vector3(172, 0, 0), "ArmL": Vector3(-60, 0, 20), "lean": Vector3(18, 0, 0), "step": Vector3(0, -0.1, -0.15)}],
		]},
		"Blizzard": {"len": 0.85, "impact": 0.28, "trail": true,
			"build": {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "ArmL": Vector3(-150, 0, -30), "lean": Vector3(-8, 0, 0), "Head": Vector3(-15, 0, 0)},
			"keys": [
			# the staff high, then slammed into the ground
			[0.15, {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "ArmL": Vector3(-150, 0, -30), "lean": Vector3(-8, 0, 0), "Head": Vector3(-15, 0, 0)}],
			[0.28, {"ArmR": Vector3(-45, 0, 0), "WeapR": Vector3(172, 0, 0), "ArmL": Vector3(-40, 0, -20), "lean": Vector3(20, 0, 0), "step": Vector3(0, -0.2, -0.1), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(30, 0, 0)}],
			[0.45, {"ArmR": Vector3(-45, 0, 0), "WeapR": Vector3(172, 0, 0), "ArmL": Vector3(-40, 0, -20), "lean": Vector3(20, 0, 0), "step": Vector3(0, -0.2, -0.1), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(30, 0, 0)}],
		]},
		"Ice Spear": {"len": 0.8, "impact": 0.26,
			"build": {"ArmL": Vector3(50, 0, -10), "lean": Vector3(-6, 40, 0), "step": Vector3(0, -0.05, 0.12), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(25, 0, 0)},
			"keys": [
			# drawn back like a javelin, then thrown
			[0.15, {"ArmL": Vector3(50, 0, -10), "lean": Vector3(-6, 40, 0), "step": Vector3(0, -0.05, 0.12), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(25, 0, 0)}],
			[0.26, {"ArmL": Vector3(-115, 0, 5), "lean": Vector3(12, -25, 0), "step": Vector3(0, 0, -0.25), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(30, 0, 0)}],
			[0.42, {"ArmL": Vector3(-115, 0, 5), "lean": Vector3(12, -25, 0), "step": Vector3(0, 0, -0.25), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(30, 0, 0)}],
		]},
		"Chain Lightning": {"len": 0.8, "impact": 0.25, "trail": true,
			"build": {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "Head": Vector3(-15, 0, 0)},
			"keys": [
			# the staff to the sky, then swept across the target
			[0.15, {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "Head": Vector3(-15, 0, 0)}],
			[0.25, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "lean": Vector3(6, 25, 0)}],
			[0.35, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "lean": Vector3(6, -25, 0)}],
			[0.5, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "lean": Vector3(6, -25, 0)}],
		]},
		"Thunder": {"hits": [
			{"len": 0.45, "impact": 0.2, "trail": true, "keys": [
				[0.12, {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "Head": Vector3(-20, 0, 0), "lean": Vector3(-6, 0, 0)}],
				[0.2, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "lean": Vector3(8, 10, 0)}],
			]},
			{"len": 0.4, "impact": 0.16, "trail": true, "keys": [
				[0.08, {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "Head": Vector3(-20, 0, 0), "lean": Vector3(-6, 0, 0)}],
				[0.16, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "lean": Vector3(8, -10, 0)}],
			]},
			{"len": 0.75, "impact": 0.25, "trail": true, "keys": [
				# the third bolt: the staff brought down
				[0.12, {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "ArmL": Vector3(-160, 0, -30), "lean": Vector3(-10, 0, 0), "Head": Vector3(-25, 0, 0)}],
				[0.25, {"ArmR": Vector3(-45, 0, 0), "WeapR": Vector3(172, 0, 0), "ArmL": Vector3(-60, 0, 0), "lean": Vector3(18, 0, 0), "step": Vector3(0, -0.15, -0.1)}],
				[0.4, {"ArmR": Vector3(-45, 0, 0), "WeapR": Vector3(172, 0, 0), "ArmL": Vector3(-60, 0, 0), "lean": Vector3(18, 0, 0), "step": Vector3(0, -0.15, -0.1)}],
			]},
		]},
		"Arcane Barrage": {"len": 0.6, "impact": 0.24, "keys": [
			# left, right, both: a flurry of pushes
			[0.08, {"ArmL": Vector3(-90, 0, 10), "lean": Vector3(4, -12, 0)}],
			[0.16, {"ArmR": Vector3(-90, 0, -10), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-30, 0, 0), "lean": Vector3(4, 12, 0)}],
			[0.24, {"ArmR": Vector3(-95, 0, -10), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-95, 0, 10), "lean": Vector3(10, 0, 0), "step": Vector3(0, 0, -0.15)}],
			[0.36, {"ArmR": Vector3(-95, 0, -10), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-95, 0, 10), "lean": Vector3(10, 0, 0), "step": Vector3(0, 0, -0.15)}],
		]},
		"Arcane Overload": {"len": 1, "impact": 0.32,
			"build": {"ArmL": Vector3(-60, 0, 35), "ArmR": Vector3(-60, 0, -25), "lean": Vector3(-10, 0, 0), "step": Vector3(0, -0.1, 0.1), "Head": Vector3(10, 0, 0)},
			"keys": [
			# power gathered at her chest, a huge push, the recoil
			[0.2, {"ArmL": Vector3(-60, 0, 35), "ArmR": Vector3(-60, 0, -25), "lean": Vector3(-10, 0, 0), "step": Vector3(0, -0.1, 0.1), "Head": Vector3(10, 0, 0)}],
			[0.32, {"ArmR": Vector3(-95, 0, -10), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-95, 0, 10), "lean": Vector3(14, 0, 0), "step": Vector3(0, 0, -0.15)}],
			[0.5, {"ArmR": Vector3(-95, 0, -10), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-95, 0, 10), "lean": Vector3(-12, 0, 0), "step": Vector3(0, 0, 0.35)}],
		]},
		"Flare": {"len": 0.65, "impact": 0.24,
			"build": {"ArmL": Vector3(-120, 0, 0), "lean": Vector3(-4, 0, 0), "Head": Vector3(-10, 0, 0)},
			"keys": [
			# a palm raised, then opened in a burst
			[0.15, {"ArmL": Vector3(-120, 0, 0), "lean": Vector3(-4, 0, 0), "Head": Vector3(-10, 0, 0)}],
			[0.24, {"ArmL": Vector3(-95, 0, 40), "lean": Vector3(8, -10, 0), "step": Vector3(0, 0, -0.08)}],
			[0.36, {"ArmL": Vector3(-95, 0, 40), "lean": Vector3(8, -10, 0), "step": Vector3(0, 0, -0.08)}],
		]},
		"Shatter": {"len": 0.7, "impact": 0.24,
			"build": {"ArmL": Vector3(-80, 0, 0), "lean": Vector3(4, 0, 0)},
			"keys": [
			# a hand reaching out, clenched, then a punch that shatters
			[0.15, {"ArmL": Vector3(-60, 0, -20), "lean": Vector3(-6, 20, 0)}],
			[0.24, {"ArmL": Vector3(-100, 0, 10), "lean": Vector3(12, -20, 0), "step": Vector3(0, 0, -0.15)}],
			[0.38, {"ArmL": Vector3(-100, 0, 10), "lean": Vector3(12, -20, 0), "step": Vector3(0, 0, -0.15)}],
		]},
		"Overcharge": {"len": 0.8, "impact": 0.3, "trail": true,
			"build": {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "lean": Vector3(-6, 0, 0), "Head": Vector3(-15, 0, 0)},
			"keys": [
			# the staff pumped high, then its butt slammed into the ground
			[0.12, {"ArmR": Vector3(-150, 0, 0), "WeapR": Vector3(150, 0, 0)}],
			[0.2, {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "lean": Vector3(-6, 0, 0), "Head": Vector3(-15, 0, 0)}],
			[0.3, {"ArmR": Vector3(-30, 0, 0), "WeapR": Vector3(22, 0, 0), "step": Vector3(0, -0.15, 0), "lean": Vector3(12, 0, 0), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(30, 0, 0)}],
			[0.45, {"ArmR": Vector3(-30, 0, 0), "WeapR": Vector3(22, 0, 0), "step": Vector3(0, -0.15, 0), "lean": Vector3(12, 0, 0), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(30, 0, 0)}],
		]},
		"Steam Burst": {"len": 0.6, "impact": 0.2,
			"build": {"ArmL": Vector3(-60, 0, 30), "ArmR": Vector3(-40, 0, 0), "lean": Vector3(-4, 0, 0)},
			"keys": [
			# both palms forward, up close
			[0.12, {"ArmL": Vector3(-60, 0, 30), "ArmR": Vector3(-40, 0, 0), "lean": Vector3(-4, 0, 0)}],
			[0.2, {"ArmR": Vector3(-95, 0, -10), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-95, 0, 10), "step": Vector3(0, 0, -0.2), "lean": Vector3(14, 0, 0)}],
			[0.32, {"ArmR": Vector3(-95, 0, -10), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-95, 0, 10), "step": Vector3(0, 0, -0.2), "lean": Vector3(14, 0, 0)}],
		]},
		"Plasma": {"len": 0.7, "impact": 0.24,
			"build": {"ArmL": Vector3(-70, 0, -30), "ArmR": Vector3(-70, 0, 30), "WeapR": Vector3(150, 0, 0), "lean": Vector3(-4, 0, 0), "Head": Vector3(6, 0, 0)},
			"keys": [
			# hands together, charged, pushed
			[0.15, {"ArmL": Vector3(-70, 0, -30), "ArmR": Vector3(-70, 0, 30), "WeapR": Vector3(150, 0, 0), "lean": Vector3(-4, 0, 0), "Head": Vector3(6, 0, 0)}],
			[0.24, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-95, 0, 0), "lean": Vector3(10, 0, 0), "step": Vector3(0, 0, -0.15)}],
			[0.38, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-95, 0, 0), "lean": Vector3(10, 0, 0), "step": Vector3(0, 0, -0.15)}],
		]},
		"Static Frost": {"len": 0.7, "impact": 0.24, "trail": true, "keys": [
			# the staff twirled, then pointed
			[0.1, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 180), "ArmL": Vector3(-40, 0, 0)}],
			[0.18, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 360), "ArmL": Vector3(-40, 0, 0)}],
			[0.24, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 360), "ArmL": Vector3(-80, 0, 20), "lean": Vector3(8, 0, 0), "step": Vector3(0, 0, -0.1)}],
			[0.38, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 360), "ArmL": Vector3(-80, 0, 20), "lean": Vector3(8, 0, 0), "step": Vector3(0, 0, -0.1)}],
		]},
		"Tri-Disaster": {"len": 1, "impact": 0.42, "trail": true,
			"build": {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "ArmL": Vector3(-150, 0, -30), "lean": Vector3(-8, 0, 0), "Head": Vector3(-20, 0, 0)},
			"keys": [
			# the staff raised, a full spin, all three loosed at once
			[0.15, {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "ArmL": Vector3(-150, 0, -30), "lean": Vector3(-8, 0, 0), "Head": Vector3(-20, 0, 0)}],
			[0.3, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-60, 0, -40), "lean": Vector3(6, -200, 0)}],
			[0.42, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-80, 0, 10), "lean": Vector3(10, -360, 0), "step": Vector3(0, 0, -0.1)}],
			[0.6, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-80, 0, 10), "lean": Vector3(10, -360, 0), "step": Vector3(0, 0, -0.1)}],
		]},
		"Thermal Shock": {"len": 0.75, "impact": 0.25,
			"build": {"ArmR": Vector3(-90, 0, 60), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-90, 0, -60), "lean": Vector3(-6, 0, 0)},
			"keys": [
			# arms wide, then clapped together toward the target
			[0.15, {"ArmR": Vector3(-90, 0, 60), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-90, 0, -60), "lean": Vector3(-6, 0, 0)}],
			[0.25, {"ArmR": Vector3(-95, 0, -10), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-95, 0, 10), "lean": Vector3(12, 0, 0), "step": Vector3(0, 0, -0.12)}],
			[0.4, {"ArmR": Vector3(-95, 0, -10), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-95, 0, 10), "lean": Vector3(12, 0, 0), "step": Vector3(0, 0, -0.12)}],
		]},
		"Nova": {"len": 0.95, "impact": 0.28,
			"build": {"ArmL": Vector3(-60, 0, 40), "ArmR": Vector3(-60, 0, -40), "step": Vector3(0, -0.25, 0), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(40, 0, 0), "lean": Vector3(16, 0, 0), "Head": Vector3(15, 0, 0)},
			"keys": [
			# crouched with arms crossed, then flung wide as she rises
			[0.15, {"ArmL": Vector3(-60, 0, 40), "ArmR": Vector3(-60, 0, -40), "step": Vector3(0, -0.25, 0), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(40, 0, 0), "lean": Vector3(16, 0, 0), "Head": Vector3(15, 0, 0)}],
			[0.28, {"ArmL": Vector3(-150, 0, -70), "ArmR": Vector3(-150, 0, 70), "WeapR": Vector3(150, 0, 0), "step": Vector3(0, 0.25, 0), "lean": Vector3(-12, 0, 0), "Head": Vector3(-20, 0, 0)}],
			[0.5, {"ArmL": Vector3(-150, 0, -70), "ArmR": Vector3(-150, 0, 70), "WeapR": Vector3(150, 0, 0), "step": Vector3(0, 0.25, 0), "lean": Vector3(-12, 0, 0), "Head": Vector3(-20, 0, 0)}],
		]},
		"Stasis": {"len": 1, "impact": 0.32,
			"build": {"ArmR": Vector3(-60, 0, 0), "WeapR": Vector3(52, 0, 0), "ArmL": Vector3(-70, 0, 30), "Head": Vector3(20, 0, 0), "lean": Vector3(4, 0, 0)},
			"keys": [
			# head bowed over the staff, then the staff raised: time stops
			[0.2, {"ArmR": Vector3(-60, 0, 0), "WeapR": Vector3(52, 0, 0), "ArmL": Vector3(-70, 0, 30), "Head": Vector3(20, 0, 0), "lean": Vector3(4, 0, 0)}],
			[0.32, {"ArmR": Vector3(-120, 0, 0), "WeapR": Vector3(160, 0, 0), "ArmL": Vector3(-110, 0, -20), "Head": Vector3(-10, 0, 0), "lean": Vector3(-4, 0, 0)}],
			[0.6, {"ArmR": Vector3(-120, 0, 0), "WeapR": Vector3(160, 0, 0), "ArmL": Vector3(-110, 0, -20), "Head": Vector3(-10, 0, 0), "lean": Vector3(-4, 0, 0)}],
		]},
		"Meteor": {"len": 1.1, "impact": 0.38, "trail": true,
			"build": {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "ArmL": Vector3(-165, 0, -20), "lean": Vector3(-14, 0, 0), "Head": Vector3(-30, 0, 0), "step": Vector3(0, 0.05, 0)},
			"keys": [
			# both arms to the sky, calling it down, then a slam
			[0.2, {"ArmR": Vector3(-170, 0, 5), "WeapR": Vector3(162, 0, 0), "ArmL": Vector3(-165, 0, -20), "lean": Vector3(-14, 0, 0), "Head": Vector3(-30, 0, 0), "step": Vector3(0, 0.05, 0)}],
			[0.38, {"ArmR": Vector3(-45, 0, 0), "WeapR": Vector3(172, 0, 0), "ArmL": Vector3(-40, 0, -20), "lean": Vector3(24, 0, 0), "step": Vector3(0, -0.25, -0.1), "LegL": Vector3(-45, 0, 0), "LegR": Vector3(35, 0, 0), "Head": Vector3(10, 0, 0)}],
			[0.6, {"ArmR": Vector3(-45, 0, 0), "WeapR": Vector3(172, 0, 0), "ArmL": Vector3(-40, 0, -20), "lean": Vector3(24, 0, 0), "step": Vector3(0, -0.25, -0.1), "LegL": Vector3(-45, 0, 0), "LegR": Vector3(35, 0, 0), "Head": Vector3(10, 0, 0)}],
		]},
	},
	"archer": {
		# Bow up in the left hand (WeapL keeps it upright), the right hand
		# draws to the cheek and lets go; she turns her left side to the target.
		"Shoot": {"len": 0.5, "impact": 0.2, "keys": [
			[0.12, {"ArmL": Vector3(-85, 0, 0), "WeapL": Vector3(85, 0, 0), "ArmR": Vector3(-82, 0, -48), "lean": Vector3(0, -22, 0), "Head": Vector3(4, -8, 0)}],
			[0.2, {"ArmL": Vector3(-86, 0, 0), "WeapL": Vector3(86, 0, 0), "ArmR": Vector3(-55, 0, 35), "lean": Vector3(-4, -18, 0), "Head": Vector3(0, -8, 0)}],
			[0.3, {"ArmL": Vector3(-86, 0, 0), "WeapL": Vector3(86, 0, 0), "ArmR": Vector3(-55, 0, 35), "lean": Vector3(-4, -18, 0), "Head": Vector3(0, -8, 0)}],
		]},
		"Power Draw": {"len": 0.75, "impact": 0.25,
			"build": {"ArmL": Vector3(-88, 0, 0), "WeapL": Vector3(88, 0, 0), "ArmR": Vector3(-70, 0, -70), "lean": Vector3(-8, -35, 0), "step": Vector3(0, -0.06, 0.08), "LegL": Vector3(-20, 0, 0), "LegR": Vector3(20, 0, 0), "Head": Vector3(6, -12, 0)},
			"keys": [
			[0.15, {"ArmL": Vector3(-88, 0, 0), "WeapL": Vector3(88, 0, 0), "ArmR": Vector3(-70, 0, -70), "lean": Vector3(-8, -35, 0), "step": Vector3(0, -0.06, 0.08), "LegL": Vector3(-20, 0, 0), "LegR": Vector3(20, 0, 0)}],
			[0.25, {"ArmL": Vector3(-80, 0, 0), "WeapL": Vector3(80, 0, 0), "ArmR": Vector3(-40, 0, 55), "lean": Vector3(-12, -20, 0), "step": Vector3(0, -0.04, 0.2), "LegL": Vector3(-20, 0, 0), "LegR": Vector3(20, 0, 0)}],
			[0.42, {"ArmL": Vector3(-80, 0, 0), "WeapL": Vector3(80, 0, 0), "ArmR": Vector3(-40, 0, 55), "lean": Vector3(-12, -20, 0), "step": Vector3(0, -0.04, 0.2)}],
		]},
		"Exposing Shot": {"len": 0.55, "impact": 0.22, "keys": [
			# aimed low, at the legs
			[0.14, {"ArmL": Vector3(-55, 0, 0), "WeapL": Vector3(55, 0, 0), "ArmR": Vector3(-55, 0, -45), "lean": Vector3(14, -22, 0), "Head": Vector3(18, -8, 0), "step": Vector3(0, -0.08, 0)}],
			[0.22, {"ArmL": Vector3(-56, 0, 0), "WeapL": Vector3(56, 0, 0), "ArmR": Vector3(-35, 0, 35), "lean": Vector3(10, -18, 0), "Head": Vector3(15, -8, 0), "step": Vector3(0, -0.08, 0)}],
			[0.34, {"ArmL": Vector3(-56, 0, 0), "WeapL": Vector3(56, 0, 0), "ArmR": Vector3(-35, 0, 35), "lean": Vector3(10, -18, 0), "Head": Vector3(15, -8, 0), "step": Vector3(0, -0.08, 0)}],
		]},
		"Double Shot": {"hits": [
			{"len": 0.4, "impact": 0.18, "keys": [[0.1, {"ArmL": Vector3(-85, 0, 0), "WeapL": Vector3(85, 0, 0), "ArmR": Vector3(-82, 0, -48), "lean": Vector3(0, -22, 0), "Head": Vector3(4, -8, 0)}], [0.18, {"ArmL": Vector3(-86, 0, 0), "WeapL": Vector3(86, 0, 0), "ArmR": Vector3(-55, 0, 35), "lean": Vector3(-4, -18, 0), "Head": Vector3(0, -8, 0)}]]},
			{"len": 0.6, "impact": 0.24, "keys": [
				# a second arrow snatched from the quiver, nocked and loosed
				[0.08, {"ArmL": Vector3(-60, 0, 0), "WeapL": Vector3(60, 0, 0), "ArmR": Vector3(-170, 0, 20), "lean": Vector3(-6, -10, 0), "step": Vector3(0, 0.25, 0.3), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(-10, 0, 0)}],
				[0.17, {"ArmL": Vector3(-85, 0, 0), "WeapL": Vector3(85, 0, 0), "ArmR": Vector3(-82, 0, -48), "lean": Vector3(0, -22, 0), "Head": Vector3(4, -8, 0), "step": Vector3(0, 0, 0.35)}],
				[0.24, {"ArmL": Vector3(-86, 0, 0), "WeapL": Vector3(86, 0, 0), "ArmR": Vector3(-55, 0, 35), "lean": Vector3(-4, -18, 0), "Head": Vector3(0, -8, 0), "step": Vector3(0, 0, 0.35)}],
				[0.36, {"ArmL": Vector3(-86, 0, 0), "WeapL": Vector3(86, 0, 0), "ArmR": Vector3(-55, 0, 35), "lean": Vector3(-4, -18, 0), "Head": Vector3(0, -8, 0), "step": Vector3(0, 0, 0.35)}],
			]},
		]},
		"Triple Shot": {"hits": [
			{"len": 0.35, "impact": 0.15, "keys": [[0.08, {"ArmL": Vector3(-85, 0, 0), "WeapL": Vector3(85, 0, 0), "ArmR": Vector3(-82, 0, -48), "lean": Vector3(0, -38, 0), "Head": Vector3(4, -8, 0)}], [0.15, {"ArmL": Vector3(-86, 0, 0), "WeapL": Vector3(86, 0, 0), "ArmR": Vector3(-55, 0, 35), "lean": Vector3(-4, -36, 0), "Head": Vector3(0, -8, 0)}]]},
			{"len": 0.4, "impact": 0.2, "keys": [[0.07, {"ArmL": Vector3(-60, 0, 0), "WeapL": Vector3(60, 0, 0), "ArmR": Vector3(-170, 0, 20), "lean": Vector3(0, -10, 0)}], [0.14, {"ArmL": Vector3(-85, 0, 0), "WeapL": Vector3(85, 0, 0), "ArmR": Vector3(-82, 0, -48), "lean": Vector3(0, -22, 0), "Head": Vector3(4, -8, 0)}], [0.2, {"ArmL": Vector3(-86, 0, 0), "WeapL": Vector3(86, 0, 0), "ArmR": Vector3(-55, 0, 35), "lean": Vector3(-4, -18, 0), "Head": Vector3(0, -8, 0)}]]},
			{"len": 0.75, "impact": 0.3, "keys": [
				# down on one knee for the piercing last arrow
				[0.1, {"ArmL": Vector3(-60, 0, 0), "WeapL": Vector3(60, 0, 0), "ArmR": Vector3(-170, 0, 20), "lean": Vector3(0, -10, 0)}],
				[0.22, {"ArmL": Vector3(-85, 0, 0), "WeapL": Vector3(85, 0, 0), "ArmR": Vector3(-78, 0, -55), "lean": Vector3(4, -8, 0), "step": Vector3(0, -0.35, 0), "LegL": Vector3(-85, 0, 0), "LegR": Vector3(50, 0, 0)}],
				[0.3, {"ArmL": Vector3(-86, 0, 0), "WeapL": Vector3(86, 0, 0), "ArmR": Vector3(-45, 0, 45), "lean": Vector3(-2, -2, 0), "step": Vector3(0, -0.35, 0.05), "LegL": Vector3(-85, 0, 0), "LegR": Vector3(50, 0, 0)}],
				[0.5, {"ArmL": Vector3(-86, 0, 0), "WeapL": Vector3(86, 0, 0), "ArmR": Vector3(-45, 0, 45), "lean": Vector3(-2, -2, 0), "step": Vector3(0, -0.35, 0.05), "LegL": Vector3(-85, 0, 0), "LegR": Vector3(50, 0, 0)}],
			]},
		]},
		"Piercing Arrow": {"len": 0.85, "impact": 0.3,
			"build": {"ArmL": Vector3(-90, 0, 0), "WeapL": Vector3(90, 0, 0), "ArmR": Vector3(-72, 0, -75), "lean": Vector3(-14, -45, 0), "step": Vector3(0, -0.1, 0.12), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(30, 0, 0), "Head": Vector3(8, -18, 0)},
			"keys": [
			[0.18, {"ArmL": Vector3(-90, 0, 0), "WeapL": Vector3(90, 0, 0), "ArmR": Vector3(-72, 0, -75), "lean": Vector3(-14, -45, 0), "step": Vector3(0, -0.1, 0.12), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(30, 0, 0)}],
			[0.3, {"ArmL": Vector3(-88, 0, 0), "WeapL": Vector3(88, 0, 0), "ArmR": Vector3(-30, 0, 70), "lean": Vector3(10, -10, 0), "step": Vector3(0, -0.06, -0.18), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}],
			[0.5, {"ArmL": Vector3(-88, 0, 0), "WeapL": Vector3(88, 0, 0), "ArmR": Vector3(-30, 0, 70), "lean": Vector3(10, -10, 0), "step": Vector3(0, -0.06, -0.18), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(25, 0, 0)}],
		]},
		"Stunning Arrow": {"len": 0.8, "impact": 0.36, "keys": [
			# a twirl of the bow in her hand, then a sharp flick: aimed a little
			# high, loosed with a twist
			[0.1, {"ArmL": Vector3(-70, 0, 0), "WeapL": Vector3(70, 0, 180), "ArmR": Vector3(-20, 0, 20), "lean": Vector3(-2, -10, 0)}],
			[0.2, {"ArmL": Vector3(-80, 0, 0), "WeapL": Vector3(80, 0, 360), "ArmR": Vector3(-60, 0, -20), "lean": Vector3(-4, -18, 0)}],
			[0.28, {"ArmL": Vector3(-100, 0, 0), "WeapL": Vector3(100, 0, 360), "ArmR": Vector3(-95, 0, -45), "lean": Vector3(-6, -25, 0), "Head": Vector3(-6, -8, 0)}],
			[0.36, {"ArmL": Vector3(-95, 0, 0), "WeapL": Vector3(95, 0, 360), "ArmR": Vector3(-70, 0, 40), "lean": Vector3(4, 10, 0)}],
			[0.5, {"ArmL": Vector3(-95, 0, 0), "WeapL": Vector3(95, 0, 360), "ArmR": Vector3(-70, 0, 40), "lean": Vector3(4, 10, 0)}],
		]},
		"Gale Shot": {"len": 0.95, "impact": 0.42, "keys": [
			# a spin to wind up, then a leaping shot that blasts the target back
			[0.15, {"ArmL": Vector3(-60, 0, 0), "WeapL": Vector3(60, 0, 0), "ArmR": Vector3(-30, 0, 30), "lean": Vector3(6, 60, 0), "step": Vector3(0, -0.15, 0), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(30, 0, 0)}],
			[0.32, {"ArmL": Vector3(-88, 0, 0), "WeapL": Vector3(88, 0, 0), "ArmR": Vector3(-80, 0, -55), "lean": Vector3(-4, -290, 0), "step": Vector3(0, 0.35, 0), "LegL": Vector3(-50, 0, 0), "LegR": Vector3(-20, 0, 0)}],
			[0.42, {"ArmL": Vector3(-88, 0, 0), "WeapL": Vector3(88, 0, 0), "ArmR": Vector3(-35, 0, 60), "lean": Vector3(-14, -340, 0), "step": Vector3(0, 0.3, 0.2), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-10, 0, 0)}],
			[0.62, {"ArmL": Vector3(-80, 0, 0), "WeapL": Vector3(80, 0, 0), "ArmR": Vector3(-35, 0, 55), "lean": Vector3(-6, -360, 0), "step": Vector3(0, -0.05, 0.35), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(20, 0, 0)}],
		]},
		"Arrow Rain": {"hits": [
			# arrows loosed high into the sky; the last one with her whole back
			{"len": 0.45, "impact": 0.2, "keys": [
				[0.12, {"ArmL": Vector3(-150, 0, 0), "WeapL": Vector3(150, 0, 0), "ArmR": Vector3(-150, 0, -40), "lean": Vector3(-14, -15, 0), "Head": Vector3(-25, 0, 0)}],
				[0.2, {"ArmL": Vector3(-150, 0, 0), "WeapL": Vector3(150, 0, 0), "ArmR": Vector3(-110, 0, 40), "lean": Vector3(-16, -10, 0), "Head": Vector3(-25, 0, 0)}],
			]},
			{"len": 0.45, "impact": 0.2, "keys": [
				[0.06, {"ArmL": Vector3(-150, 0, 0), "WeapL": Vector3(150, 0, 0), "ArmR": Vector3(-170, 0, 20), "lean": Vector3(-14, -10, 0), "Head": Vector3(-25, 0, 0)}],
				[0.13, {"ArmL": Vector3(-150, 0, 0), "WeapL": Vector3(150, 0, 0), "ArmR": Vector3(-150, 0, -40), "lean": Vector3(-14, -15, 0), "Head": Vector3(-25, 0, 0)}],
				[0.2, {"ArmL": Vector3(-150, 0, 0), "WeapL": Vector3(150, 0, 0), "ArmR": Vector3(-110, 0, 40), "lean": Vector3(-16, -10, 0), "Head": Vector3(-25, 0, 0)}],
			]},
			{"len": 0.8, "impact": 0.3, "keys": [
				[0.08, {"ArmL": Vector3(-150, 0, 0), "WeapL": Vector3(150, 0, 0), "ArmR": Vector3(-170, 0, 20), "lean": Vector3(-14, -10, 0), "Head": Vector3(-25, 0, 0)}],
				[0.2, {"ArmL": Vector3(-160, 0, 0), "WeapL": Vector3(160, 0, 0), "ArmR": Vector3(-160, 0, -45), "lean": Vector3(-24, -20, 0), "Head": Vector3(-30, 0, 0), "step": Vector3(0, -0.12, 0.05), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(25, 0, 0)}],
				[0.3, {"ArmL": Vector3(-160, 0, 0), "WeapL": Vector3(160, 0, 0), "ArmR": Vector3(-100, 0, 55), "lean": Vector3(-26, -5, 0), "Head": Vector3(-30, 0, 0), "step": Vector3(0, -0.08, 0.1)}],
				[0.5, {"ArmL": Vector3(-160, 0, 0), "WeapL": Vector3(160, 0, 0), "ArmR": Vector3(-100, 0, 55), "lean": Vector3(-26, -5, 0), "Head": Vector3(-30, 0, 0), "step": Vector3(0, -0.08, 0.1)}],
			]},
		]},
	},
	"knight": {
		"Slash": {"len": 0.5, "impact": 0.22, "trail": true, "keys": [
			[0.14, {"ArmR": Vector3(-160, 0, 45), "lean": Vector3(-4, 25, 0)}],
			[0.22, {"ArmR": Vector3(-35, 0, -35), "lean": Vector3(10, -25, 0), "step": Vector3(0, 0, -0.15)}],
			[0.32, {"ArmR": Vector3(-30, 0, -38), "lean": Vector3(10, -28, 0), "step": Vector3(0, 0, -0.15)}],
		]},
		"Thrust": {"len": 0.45, "impact": 0.17, "trail": true, "keys": [
			# a straight stab: the sword drawn back to the hip, then driven
			# straight ahead at chest height, the wrist turning it level
			[0.1, {"ArmR": Vector3(40, 0, 8), "WeapR": Vector3(0, 0, 0), "lean": Vector3(-4, 8, 0), "step": Vector3(0, 0, 0.08)}],
			[0.17, {"ArmR": Vector3(-80, 0, -4), "WeapR": Vector3(115, 0, 0), "lean": Vector3(12, -4, 0), "step": Vector3(0, -0.04, -0.25), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(15, 0, 0)}],
			[0.28, {"ArmR": Vector3(-80, 0, -4), "WeapR": Vector3(115, 0, 0), "lean": Vector3(12, -4, 0), "step": Vector3(0, -0.04, -0.25), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(15, 0, 0)}],
		]},
		"Guard Strike": {"len": 0.45, "impact": 0.18, "keys": [
			[0.1, {"ArmL": Vector3(-20, 0, -15), "lean": Vector3(0, -25, 0)}],
			[0.18, {"ArmL": Vector3(-90, 25, 15), "lean": Vector3(10, 20, 0), "dash": 0.3}],
			[0.3, {"ArmL": Vector3(-90, 25, 15), "lean": Vector3(10, 20, 0), "dash": 0.3}],
		]},
		"Double Slash": {"hits": [
			{"len": 0.4, "impact": 0.2, "trail": true, "keys": [
				[0.12, {"ArmR": Vector3(-160, 0, 45), "lean": Vector3(-4, 30, 0)}],
				[0.2, {"ArmR": Vector3(-40, 0, -40), "lean": Vector3(10, -30, 0), "step": Vector3(0, 0, -0.15)}],
			]},
			{"len": 0.45, "impact": 0.18, "trail": true, "keys": [
				[0.1, {"ArmR": Vector3(-150, 0, -30), "lean": Vector3(-4, -30, 0), "step": Vector3(0, 0, -0.15)}],
				[0.18, {"ArmR": Vector3(-40, 0, 50), "lean": Vector3(10, 32, 0), "step": Vector3(0, 0, -0.25)}],
				[0.28, {"ArmR": Vector3(-38, 0, 52), "lean": Vector3(10, 34, 0), "step": Vector3(0, 0, -0.25)}],
			]},
		]},
		"Lunge": {"len": 0.8, "impact": 0.32, "trail": true, "keys": [
			[0.18, {"ArmR": Vector3(20, 0, 10), "lean": Vector3(18, 0, 0), "step": Vector3(0, -0.12, 0.1), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(30, 0, 0)}],
			[0.32, {"ArmR": Vector3(-95, 0, 0), "lean": Vector3(25, 0, 0), "dash": 1.0, "LegL": Vector3(-50, 0, 0), "LegR": Vector3(40, 0, 0)}],
			[0.5, {"ArmR": Vector3(-95, 0, 0), "lean": Vector3(22, 0, 0), "dash": 1.0, "LegL": Vector3(-50, 0, 0), "LegR": Vector3(40, 0, 0)}],
		]},
		"Shield Rush": {"hits": [
			{"len": 0.45, "impact": 0.25, "keys": [
				[0.12, {"ArmL": Vector3(-80, 35, 10), "lean": Vector3(15, 0, 0), "step": Vector3(0, -0.05, 0)}],
				[0.25, {"ArmL": Vector3(-85, 35, 10), "lean": Vector3(18, 0, 0), "dash": 0.9, "LegL": Vector3(-40, 0, 0), "LegR": Vector3(30, 0, 0)}],
			]},
			{"len": 0.55, "impact": 0.15, "keys": [
				[0.08, {"ArmL": Vector3(-60, 35, 10), "lean": Vector3(10, 0, 0), "dash": 0.8}],
				[0.15, {"ArmL": Vector3(-100, 25, 10), "lean": Vector3(14, 0, 0), "dash": 1.0, "LegL": Vector3(-30, 0, 0), "LegR": Vector3(35, 0, 0)}],
				[0.3, {"ArmL": Vector3(-100, 25, 10), "lean": Vector3(14, 0, 0), "dash": 1.0, "LegL": Vector3(-30, 0, 0), "LegR": Vector3(35, 0, 0)}],
			]},
		]},
		"Shield Wall": {"len": 0.8, "impact": 0.25, "keys": [
			[0.15, {"ArmL": Vector3(-85, 40, 10), "ArmR": Vector3(-30, 0, 10), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(20, 0, 0), "lean": Vector3(5, 0, 0), "step": Vector3(0, -0.1, 0)}],
			[0.25, {"ArmL": Vector3(-90, 30, 10), "ArmR": Vector3(-30, 0, 10), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(20, 0, 0), "lean": Vector3(10, 0, 0), "step": Vector3(0, -0.1, 0), "dash": 0.25}],
			[0.55, {"ArmL": Vector3(-90, 30, 10), "ArmR": Vector3(-30, 0, 10), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(20, 0, 0), "lean": Vector3(10, 0, 0), "step": Vector3(0, -0.1, 0), "dash": 0.25}],
		]},
		"Smash": {"len": 1.45, "impact": 0.3, "trail": true,
			"build": {"ArmR": Vector3(45, 0, 12), "WeapR": Vector3(0, 0, 0), "ArmL": Vector3(-55, 0, 15), "lean": Vector3(-4, 28, 0), "step": Vector3(0, -0.1, 0.12), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(25, 0, 0), "Head": Vector3(8, 0, 0)},
			"keys": [
			# drives the sword deep into the enemy...
			[0.16, {"ArmR": Vector3(40, 0, 10), "WeapR": Vector3(0, 0, 0), "ArmL": Vector3(-30, 0, 0), "lean": Vector3(-6, 20, 0), "step": Vector3(0, -0.06, 0.12), "LegL": Vector3(-20, 0, 0), "LegR": Vector3(20, 0, 0)}],
			[0.3, {"ArmR": Vector3(-82, 0, -6), "WeapR": Vector3(115, 0, 0), "ArmL": Vector3(-60, 0, 10), "lean": Vector3(20, -8, 0), "dash": 0.95, "LegL": Vector3(-45, 0, 0), "LegR": Vector3(35, 0, 0)}],
			[0.45, {"ArmR": Vector3(-84, 0, -6), "WeapR": Vector3(115, 0, 0), "ArmL": Vector3(-60, 0, 10), "lean": Vector3(22, -8, 0), "dash": 1.0, "LegL": Vector3(-45, 0, 0), "LegR": Vector3(35, 0, 0)}],
			# ...plants a foot on it and kicks off, wrenching the blade free...
			[0.62, {"ArmR": Vector3(-72, 0, 0), "WeapR": Vector3(110, 0, 0), "ArmL": Vector3(-30, 0, -10), "lean": Vector3(-14, 0, 0), "dash": 0.85, "LegL": Vector3(-100, 0, 0), "LegR": Vector3(10, 0, 0)}],
			[0.78, {"ArmR": Vector3(40, 0, 20), "WeapR": Vector3(20, 0, 0), "ArmL": Vector3(-20, 0, -30), "lean": Vector3(-18, 0, 0), "dash": 0.35, "LegL": Vector3(-60, 0, 0), "Head": Vector3(-12, 0, 0)}],
			# ...and stumbles back from the recoil before catching its balance.
			[0.98, {"ArmR": Vector3(10, 0, 40), "ArmL": Vector3(-40, 0, -45), "lean": Vector3(-20, 10, -6), "step": Vector3(0, -0.04, 0.35), "LegL": Vector3(20, 0, 0), "LegR": Vector3(-30, 0, 0), "Head": Vector3(-15, 0, 0)}],
			[1.15, {"ArmR": Vector3(-20, 0, 15), "ArmL": Vector3(-25, 0, -15), "lean": Vector3(-6, 0, 4), "step": Vector3(0, -0.02, 0.4), "LegL": Vector3(-15, 0, 0), "LegR": Vector3(10, 0, 0)}],
		]},
		"Crusader's Edge": {"hits": [
			{"len": 0.5, "impact": 0.25, "trail": true, "keys": [
				[0.12, {"ArmR": Vector3(-90, 0, 70), "lean": Vector3(0, 70, 0)}],
				[0.25, {"ArmR": Vector3(-90, 0, -10), "lean": Vector3(5, -220, 0), "dash": 0.3}],
				[0.38, {"ArmR": Vector3(-90, 0, -10), "lean": Vector3(0, -360, 0), "dash": 0.3}],
			]},
			{"len": 0.4, "impact": 0.2, "trail": true, "keys": [
				[0.1, {"ArmR": Vector3(-20, 0, 20), "lean": Vector3(-5, 30, 0), "step": Vector3(0, -0.1, 0), "dash": 0.3}],
				[0.2, {"ArmR": Vector3(-172, 0, 10), "lean": Vector3(-10, -10, 0), "step": Vector3(0, 0.15, 0), "dash": 0.45}],
			]},
			{"len": 0.85, "impact": 0.45, "trail": true, "keys": [
				[0.25, {"ArmR": Vector3(-180, 0, 0), "ArmL": Vector3(-150, 0, -10), "lean": Vector3(-15, 0, 0), "step": Vector3(0, 0.7, 0), "dash": 0.5, "LegL": Vector3(-60, 0, 0), "LegR": Vector3(-20, 0, 0)}],
				[0.45, {"ArmR": Vector3(-20, 0, 0), "ArmL": Vector3(-30, 0, 0), "lean": Vector3(25, 0, 0), "step": Vector3(0, -0.15, 0), "dash": 0.9}],
				[0.62, {"ArmR": Vector3(-20, 0, 0), "ArmL": Vector3(-30, 0, 0), "lean": Vector3(25, 0, 0), "step": Vector3(0, -0.15, 0), "dash": 0.9}],
			]},
		]},
	},
}


## Abilities with their own animation (played when used; FigureAnim
## "cast"), by class. Same format as DATA; "dash" goes toward the target.
const ABILITIES := {
	"monk": {
		"Provoke": {"len": 1.3, "impact": 0.3,
			"keys": [
			# chest out, a hand beckoning: come on, then
			[0.2, {"ArmL": Vector3(-90, 0, -20), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-8, 0, 0), "Head": Vector3(-10, 0, 0)}],
			[0.35, {"ArmL": Vector3(-120, 0, -20), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-8, 0, 0), "Head": Vector3(-10, 0, 0)}],
			[0.5, {"ArmL": Vector3(-90, 0, -20), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-8, 0, 0), "Head": Vector3(-10, 0, 0)}],
			[0.65, {"ArmL": Vector3(-120, 0, -20), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-8, 0, 0), "Head": Vector3(-10, 0, 0)}],
			[0.8, {"ArmL": Vector3(-90, 0, -20), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-8, 0, 0), "Head": Vector3(-10, 0, 0)}],
			[1.05, {"ArmL": Vector3(-90, 0, -20), "ArmR": Vector3(-60, 0, -15), "lean": Vector3(-8, 0, 0), "Head": Vector3(-10, 0, 0)}],
		]},
		"Suplex": {"len": 1.3, "impact": 0.25,
			"keys": [
			# a low, wide wrestler's stance, waiting to grab
			[0.2, {"ArmL": Vector3(-60, 0, 55), "ArmR": Vector3(-60, 0, -55), "step": Vector3(0, -0.22, 0), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(30, 0, 0), "lean": Vector3(15, 0, 0), "Head": Vector3(5, 0, 0)}],
			[1, {"ArmL": Vector3(-60, 0, 55), "ArmR": Vector3(-60, 0, -55), "step": Vector3(0, -0.22, 0), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(30, 0, 0), "lean": Vector3(15, 0, 0), "Head": Vector3(5, 0, 0)}],
		]},
		"Deep Breath": {"len": 1.5, "impact": 0.75,
			"keys": [
			# arms raised as he breathes in, lowered as he breathes out
			[0.45, {"ArmL": Vector3(-165, 0, 35), "ArmR": Vector3(-165, 0, -35), "Head": Vector3(-15, 0, 0), "lean": Vector3(-6, 0, 0), "step": Vector3(0, 0.08, 0)}],
			[0.6, {"ArmL": Vector3(-165, 0, 35), "ArmR": Vector3(-165, 0, -35), "Head": Vector3(-15, 0, 0), "lean": Vector3(-6, 0, 0), "step": Vector3(0, 0.08, 0)}],
			[1.05, {"ArmL": Vector3(-25, 0, 25), "ArmR": Vector3(-25, 0, -25), "Head": Vector3(10, 0, 0), "lean": Vector3(6, 0, 0), "step": Vector3(0, -0.15, 0), "LegL": Vector3(-15, 0, 0), "LegR": Vector3(15, 0, 0)}],
			[1.25, {"ArmL": Vector3(-25, 0, 25), "ArmR": Vector3(-25, 0, -25), "Head": Vector3(10, 0, 0), "lean": Vector3(6, 0, 0), "step": Vector3(0, -0.15, 0), "LegL": Vector3(-15, 0, 0), "LegR": Vector3(15, 0, 0)}],
		]},
	},
	"assassin": {
		"Hook": {"len": 1, "impact": 0.3,
			"keys": [
			# the chain swung back, thrown, then yanked in
			[0.15, {"ArmR": Vector3(40, 0, 0), "WeapR": Vector3(-130, 0, 0), "lean": Vector3(-6, 25, 0), "step": Vector3(0, 0, 0.05)}],
			[0.3, {"ArmR": Vector3(-100, 0, 0), "WeapR": Vector3(100, 0, 0), "ArmL": Vector3(-40, 0, 20), "WeapL": Vector3(40, 0, 0), "lean": Vector3(10, -10, 0), "step": Vector3(0, 0, -0.15), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(15, 0, 0)}],
			[0.5, {"ArmR": Vector3(20, 0, 0), "WeapR": Vector3(-110, 0, 0), "ArmL": Vector3(10, 0, 0), "WeapL": Vector3(-10, 0, 0), "lean": Vector3(-15, 10, 0), "step": Vector3(0, -0.05, 0.2), "LegL": Vector3(15, 0, 0), "LegR": Vector3(-25, 0, 0)}],
			[0.75, {"ArmR": Vector3(20, 0, 0), "WeapR": Vector3(-110, 0, 0), "ArmL": Vector3(10, 0, 0), "WeapL": Vector3(-10, 0, 0), "lean": Vector3(-15, 10, 0), "step": Vector3(0, -0.05, 0.2), "LegL": Vector3(15, 0, 0), "LegR": Vector3(-25, 0, 0)}],
		]},
		"Death Sentence": {"len": 1.3, "impact": 0.4,
			"keys": [
			# a dagger pointed at it: three Marks
			[0.25, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(95, 0, 0), "ArmL": Vector3(-110, 0, 35), "WeapL": Vector3(110, 0, 0), "Head": Vector3(5, -10, 0), "lean": Vector3(0, -15, 0)}],
			[0.4, {"ArmR": Vector3(-100, 0, 0), "WeapR": Vector3(95, 0, 0), "ArmL": Vector3(-110, 0, 35), "WeapL": Vector3(110, 0, 0), "Head": Vector3(5, -10, 0), "lean": Vector3(0, -15, 0)}],
			[0.9, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(95, 0, 0), "ArmL": Vector3(-110, 0, 35), "WeapL": Vector3(110, 0, 0), "Head": Vector3(5, -10, 0), "lean": Vector3(0, -15, 0)}],
		]},
		"Shadow Cloak": {"len": 1.2, "impact": 0.45,
			"keys": [
			# arms wrapped round himself, then thrown open: the shield
			[0.25, {"ArmR": Vector3(-60, 0, -55), "WeapR": Vector3(60, 0, 0), "ArmL": Vector3(-60, 0, 55), "WeapL": Vector3(60, 0, 0), "Head": Vector3(15, 0, 0), "step": Vector3(0, -0.15, 0), "lean": Vector3(12, 0, 0)}],
			[0.45, {"ArmR": Vector3(-30, 0, 40), "WeapR": Vector3(30, 0, 0), "ArmL": Vector3(-30, 0, -40), "WeapL": Vector3(30, 0, 0), "Head": Vector3(-10, 0, 0), "lean": Vector3(-6, 0, 0)}],
			[0.85, {"ArmR": Vector3(-30, 0, 40), "WeapR": Vector3(30, 0, 0), "ArmL": Vector3(-30, 0, -40), "WeapL": Vector3(30, 0, 0), "Head": Vector3(-10, 0, 0), "lean": Vector3(-6, 0, 0)}],
		]},
		"Vanish": {"len": 0.9, "impact": 0.3,
			"keys": [
			# the hood pulled over his face, a step back into the smoke
			[0.15, {"ArmL": Vector3(-120, 0, 50), "WeapL": Vector3(120, 0, 0), "ArmR": Vector3(-30, 0, -30), "WeapR": Vector3(30, 0, 0), "step": Vector3(0, -0.2, 0.25), "lean": Vector3(15, 0, 0), "Head": Vector3(15, 0, 0)}],
			[0.3, {"ArmL": Vector3(-120, 0, 50), "WeapL": Vector3(120, 0, 0), "ArmR": Vector3(-30, 0, -30), "WeapR": Vector3(30, 0, 0), "step": Vector3(0, -0.25, 0.4), "lean": Vector3(15, 0, 0), "Head": Vector3(15, 0, 0)}],
			[0.6, {"ArmL": Vector3(-120, 0, 50), "WeapL": Vector3(120, 0, 0), "ArmR": Vector3(-30, 0, -30), "WeapR": Vector3(30, 0, 0), "step": Vector3(0, -0.25, 0.4), "lean": Vector3(15, 0, 0), "Head": Vector3(15, 0, 0)}],
		]},
	},
	"cleric": {
		"Healing": {"len": 1.2, "impact": 0.45,
			"keys": [
			# a prayer, then the sun disc held out to the ally
			[0.2, {"ArmR": Vector3(-55, 0, 0), "WeapR": Vector3(55, 0, 0), "ArmL": Vector3(-75, 0, 40), "Head": Vector3(15, 0, 0), "lean": Vector3(4, 0, 0)}],
			[0.45, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(155, 0, 0), "ArmL": Vector3(-90, 0, -20), "Head": Vector3(-5, 0, 0)}],
			[0.85, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(155, 0, 0), "ArmL": Vector3(-90, 0, -20), "Head": Vector3(-5, 0, 0)}],
		]},
		"Shielding": {"len": 1.2, "impact": 0.35,
			"keys": [
			# the staff planted, an arm swept across the party
			[0.2, {"ArmR": Vector3(-120, 0, 0), "WeapR": Vector3(120, 0, 0), "ArmL": Vector3(-60, 0, 30), "step": Vector3(0, 0.08, 0), "Head": Vector3(-10, 0, 0)}],
			[0.35, {"ArmR": Vector3(-35, 0, 0), "WeapR": Vector3(35, 0, 0), "ArmL": Vector3(-90, 0, -70), "step": Vector3(0, -0.15, 0), "LegL": Vector3(-20, 0, 0), "LegR": Vector3(15, 0, 0), "Head": Vector3(-15, 0, 0), "lean": Vector3(4, 0, 0)}],
			[0.7, {"ArmR": Vector3(-35, 0, 0), "WeapR": Vector3(35, 0, 0), "ArmL": Vector3(-90, 0, 50), "step": Vector3(0, -0.15, 0), "LegL": Vector3(-20, 0, 0), "LegR": Vector3(15, 0, 0), "Head": Vector3(-15, 0, 0), "lean": Vector3(4, 0, 0)}],
			[0.9, {"ArmR": Vector3(-35, 0, 0), "WeapR": Vector3(35, 0, 0), "ArmL": Vector3(-90, 0, 50), "step": Vector3(0, -0.15, 0), "LegL": Vector3(-20, 0, 0), "LegR": Vector3(15, 0, 0), "Head": Vector3(-15, 0, 0), "lean": Vector3(4, 0, 0)}],
		]},
		"Haste": {"len": 1, "impact": 0.45,
			"keys": [
			# the staff twirled over her head, then pointed at the ally
			[0.15, {"ArmR": Vector3(-150, 0, 0), "WeapR": Vector3(240, 0, 0), "Head": Vector3(-10, 0, 0)}],
			[0.4, {"ArmR": Vector3(-150, 0, 0), "WeapR": Vector3(600, 0, 0), "Head": Vector3(-10, 0, 0)}],
			[0.55, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(155, 0, 0), "ArmL": Vector3(-30, 0, 0)}],
			[0.8, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(155, 0, 0), "ArmL": Vector3(-30, 0, 0)}],
		]},
		"Full Cure": {"len": 1.5, "impact": 0.7,
			"keys": [
			# kneeling in prayer, then rising with the staff held high
			[0.3, {"ArmR": Vector3(-100, 0, 0), "WeapR": Vector3(100, 0, 0), "ArmL": Vector3(-75, 0, 40), "Head": Vector3(25, 0, 0), "step": Vector3(0, -0.3, 0), "LegL": Vector3(-85, 0, 0), "LegR": Vector3(40, 0, 0), "lean": Vector3(6, 0, 0)}],
			[0.55, {"ArmR": Vector3(-100, 0, 0), "WeapR": Vector3(100, 0, 0), "ArmL": Vector3(-75, 0, 40), "Head": Vector3(25, 0, 0), "step": Vector3(0, -0.3, 0), "LegL": Vector3(-85, 0, 0), "LegR": Vector3(40, 0, 0), "lean": Vector3(6, 0, 0)}],
			[0.7, {"ArmR": Vector3(-170, 0, 0), "WeapR": Vector3(170, 0, 0), "ArmL": Vector3(-160, 0, -40), "Head": Vector3(-25, 0, 0), "step": Vector3(0, -0.2, 0), "LegL": Vector3(-60, 0, 0), "LegR": Vector3(30, 0, 0)}],
			[1.1, {"ArmR": Vector3(-170, 0, 0), "WeapR": Vector3(170, 0, 0), "ArmL": Vector3(-160, 0, -40), "Head": Vector3(-25, 0, 0), "step": Vector3(0, -0.2, 0), "LegL": Vector3(-60, 0, 0), "LegR": Vector3(30, 0, 0)}],
		]},
		"Lifeline": {"len": 0.7, "impact": 0.2, "ghost": true,
			"keys": [
			# a crouch and a sprint (she's already beside the ally)
			[0.1, {"step": Vector3(0, -0.15, 0.1), "lean": Vector3(20, 0, 0), "ArmL": Vector3(40, 0, 0), "ArmR": Vector3(40, 0, 0), "WeapR": Vector3(-40, 0, 0), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(30, 0, 0)}],
			[0.2, {"lean": Vector3(25, 0, 0), "step": Vector3(0, 0, -0.3), "ArmL": Vector3(50, 0, 0), "ArmR": Vector3(50, 0, 0), "WeapR": Vector3(-50, 0, 0), "LegL": Vector3(-60, 0, 0), "LegR": Vector3(40, 0, 0)}],
			[0.45, {"lean": Vector3(5, 0, 0), "ArmL": Vector3(-40, 0, -30)}],
		]},
	},
	"mage": {
		"Arcane Barrier": {"len": 1.3, "impact": 0.25, "keys": [
			# the staff planted, a hand raised: the dome
			[0.25, {"ArmR": Vector3(-30, 0, 0), "WeapR": Vector3(22, 0, 0), "step": Vector3(0, -0.1, 0), "ArmL": Vector3(-150, 0, -20), "Head": Vector3(-10, 0, 0)}],
			[1, {"ArmR": Vector3(-30, 0, 0), "WeapR": Vector3(22, 0, 0), "step": Vector3(0, -0.1, 0), "ArmL": Vector3(-150, 0, -20), "Head": Vector3(-10, 0, 0)}],
		]},
		"Enchant": {"len": 1.2, "impact": 0.25, "keys": [
			# a hand weaving over the staff
			[0.25, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-100, 0, 30), "Head": Vector3(5, 0, 0)}],
			[0.5, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-100, 0, -20), "Head": Vector3(5, 0, 0)}],
			[0.75, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-100, 0, 30), "Head": Vector3(5, 0, 0)}],
			[0.9, {"ArmR": Vector3(-95, 0, 0), "WeapR": Vector3(177, 0, 0), "ArmL": Vector3(-100, 0, 0), "Head": Vector3(5, 0, 0)}],
		]},
		"Teleport": {"len": 0.9, "impact": 0.15, "keys": [
			# a crouch, a spin up into the blink
			[0.15, {"step": Vector3(0, -0.2, 0), "lean": Vector3(10, 0, 0), "ArmL": Vector3(-40, 0, 40), "ArmR": Vector3(-40, 0, -40)}],
			[0.4, {"lean": Vector3(0, -360, 0), "step": Vector3(0, 0.2, 0), "ArmL": Vector3(-150, 0, -30), "ArmR": Vector3(-150, 0, 30), "WeapR": Vector3(150, 0, 0)}],
			[0.6, {"lean": Vector3(0, -360, 0)}],
		]},
	},
	"archer": {
		"Jump": {"len": 1.0, "impact": 0.3, "keys": [
			# a crouch, a tucked leap, a landing that bends the knees
			[0.15, {"step": Vector3(0, -0.25, 0), "LegL": Vector3(-40, 0, 0), "LegR": Vector3(-40, 0, 0), "lean": Vector3(14, 0, 0), "ArmL": Vector3(20, 0, -10), "ArmR": Vector3(20, 0, 10)}],
			[0.4, {"step": Vector3(0, 1.0, 0), "LegL": Vector3(-80, 0, 0), "LegR": Vector3(-70, 0, 0), "lean": Vector3(-8, 0, 0), "ArmL": Vector3(-120, 0, -30), "ArmR": Vector3(-120, 0, 30)}],
			[0.7, {"step": Vector3(0, -0.2, 0), "LegL": Vector3(-35, 0, 0), "LegR": Vector3(-35, 0, 0), "lean": Vector3(12, 0, 0), "ArmL": Vector3(-30, 0, -30), "ArmR": Vector3(-30, 0, 30)}],
		]},
		"Siphon Shot": {"len": 1.0, "impact": 0.45, "keys": [
			# a slow, steady draw, then the arrow that drains the target
			[0.35, {"ArmL": Vector3(-85, 0, 0), "WeapL": Vector3(85, 0, 0), "ArmR": Vector3(-82, 0, -48), "lean": Vector3(0, -22, 0), "Head": Vector3(4, -8, 0)}],
			[0.45, {"ArmL": Vector3(-86, 0, 0), "WeapL": Vector3(86, 0, 0), "ArmR": Vector3(-55, 0, 35), "lean": Vector3(-4, -18, 0), "Head": Vector3(0, -8, 0)}],
			[0.7, {"ArmL": Vector3(-86, 0, 0), "WeapL": Vector3(86, 0, 0), "ArmR": Vector3(-55, 0, 35), "lean": Vector3(-4, -18, 0), "Head": Vector3(0, -8, 0)}],
		]},
		"True Sight": {"len": 1.4, "impact": 0.4, "keys": [
			# a hand shading her eyes, scanning left to right
			[0.25, {"ArmR": Vector3(-130, 0, -55), "Head": Vector3(-8, 25, 0), "lean": Vector3(-3, 10, 0)}],
			[0.7, {"ArmR": Vector3(-130, 0, -55), "Head": Vector3(-8, -25, 0), "lean": Vector3(-3, -10, 0)}],
			[1.0, {"ArmR": Vector3(-130, 0, -55), "Head": Vector3(-8, 0, 0), "lean": Vector3(-3, 0, 0)}],
		]},
		"Agility": {"len": 1.0, "impact": 0.3, "keys": [
			# two quick hops on her toes, arms loose
			[0.15, {"step": Vector3(0, 0.25, 0), "LegL": Vector3(-20, 0, 0), "LegR": Vector3(10, 0, 0), "ArmL": Vector3(-30, 0, -20), "ArmR": Vector3(-20, 0, 20)}],
			[0.3, {"step": Vector3(0, -0.06, 0), "LegL": Vector3(10, 0, 0), "LegR": Vector3(-20, 0, 0)}],
			[0.45, {"step": Vector3(0, 0.25, 0), "LegL": Vector3(10, 0, 0), "LegR": Vector3(-20, 0, 0), "ArmL": Vector3(-20, 0, -20), "ArmR": Vector3(-30, 0, 20)}],
			[0.6, {"step": Vector3(0, -0.06, 0)}],
		]},
	},
	"knight": {
		"Light Heal": {"len": 1.3, "impact": 0.5, "keys": [
			# a hand to the heart, head bowed, then the arm opens out
			[0.3, {"ArmL": Vector3(-75, 0, 35), "ArmR": Vector3(-15, 0, 10), "Head": Vector3(18, 0, 0), "lean": Vector3(5, 0, 0)}],
			[0.75, {"ArmL": Vector3(-78, 0, 38), "ArmR": Vector3(-15, 0, 10), "Head": Vector3(20, 0, 0), "lean": Vector3(6, 0, 0)}],
			[1.0, {"ArmL": Vector3(-70, 0, -45), "ArmR": Vector3(-20, 0, 20), "Head": Vector3(-10, 0, 0), "lean": Vector3(-3, 0, 0)}],
		]},
		"Brace": {"len": 1.2, "impact": 0.25, "keys": [
			# feet wide, low, shield up and sword tucked behind it
			[0.2, {"LegL": Vector3(-30, 0, -10), "LegR": Vector3(30, 0, 10), "step": Vector3(0, -0.15, 0), "ArmL": Vector3(-80, 35, 10), "ArmR": Vector3(-35, 0, 25), "lean": Vector3(10, 0, 0), "Head": Vector3(8, 0, 0)}],
			[0.85, {"LegL": Vector3(-30, 0, -10), "LegR": Vector3(30, 0, 10), "step": Vector3(0, -0.15, 0), "ArmL": Vector3(-82, 35, 10), "ArmR": Vector3(-35, 0, 25), "lean": Vector3(10, 0, 0), "Head": Vector3(8, 0, 0)}],
		]},
		"Shield Bash": {"len": 0.85, "impact": 0.34, "charge": true, "keys": [
			# Timed to the charge (battle_arena: 0.12 s wind-up, 0.22 s run):
			# crouch behind the shield, lean into the run, the shield
			# shoved out on arrival, then settle.
			[0.12, {"ArmL": Vector3(-45, 20, -10), "ArmR": Vector3(-20, 0, 20), "lean": Vector3(4, -20, 0), "step": Vector3(0, -0.1, 0.06), "LegL": Vector3(-25, 0, 0), "LegR": Vector3(20, 0, 0), "Head": Vector3(10, 0, 0)}],
			[0.24, {"ArmL": Vector3(-80, 30, 5), "ArmR": Vector3(-25, 0, 25), "lean": Vector3(20, 5, 0), "step": Vector3(0, -0.05, 0), "LegL": Vector3(-50, 0, 0), "LegR": Vector3(35, 0, 0), "Head": Vector3(5, 0, 0)}],
			[0.34, {"ArmL": Vector3(-100, 25, 25), "ArmR": Vector3(-25, 0, 25), "lean": Vector3(22, 25, 0), "step": Vector3(0, -0.04, -0.15), "LegL": Vector3(-45, 0, 0), "LegR": Vector3(40, 0, 0), "Head": Vector3(0, 0, 0)}],
			[0.5, {"ArmL": Vector3(-95, 25, 20), "ArmR": Vector3(-20, 0, 20), "lean": Vector3(14, 20, 0), "step": Vector3(0, -0.04, -0.1), "LegL": Vector3(-30, 0, 0), "LegR": Vector3(25, 0, 0)}],
		]},
		"Taunt": {"len": 1.3, "impact": 0.3, "keys": [
			# sword banged on the shield twice, then pointed at the enemy
			[0.15, {"ArmR": Vector3(-80, 0, -45), "ArmL": Vector3(-70, 30, 10)}],
			[0.25, {"ArmR": Vector3(-60, 0, -65), "ArmL": Vector3(-70, 30, 10)}],
			[0.38, {"ArmR": Vector3(-85, 0, -40), "ArmL": Vector3(-70, 30, 10)}],
			[0.48, {"ArmR": Vector3(-60, 0, -65), "ArmL": Vector3(-70, 30, 10)}],
			[0.75, {"ArmR": Vector3(-95, 0, 10), "WeapR": Vector3(60, 0, 0), "ArmL": Vector3(-30, 0, 0), "Head": Vector3(-10, 0, 0), "lean": Vector3(-6, 0, 0)}],
			[1.05, {"ArmR": Vector3(-95, 0, 10), "WeapR": Vector3(60, 0, 0), "ArmL": Vector3(-30, 0, 0), "Head": Vector3(-10, 0, 0), "lean": Vector3(-6, 0, 0)}],
		]},
	},
}


## An Ability's own animation, or {} (the generic cast).
static func ability(class_id: String, skill_name: String) -> Dictionary:
	return (ABILITIES.get(class_id, {}) as Dictionary).get(skill_name, {})


## The sequence for this hit of this move, or {} (the class's basic swing).
static func sequence(class_id: String, move_name: String, hit: int) -> Dictionary:
	var by_class: Dictionary = DATA.get(class_id, {})
	if not by_class.has(move_name):
		return {}
	var entry: Dictionary = by_class[move_name]
	if entry.has("hits"):
		var list: Array = entry["hits"]
		return list[mini(hit, list.size() - 1)]
	return entry
