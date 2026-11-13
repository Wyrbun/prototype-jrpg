class_name Encounter
extends Resource
## One fight: where it happens, who fights, and who they face.

## Shown at the top of the screen when the fight starts.
@export var title: String = "Round"
@export var arena: PackedScene
## Party members, in order (the first one starts under your control).
@export var party: Array[PackedScene] = []
@export var enemies: Array[PackedScene] = []
## (Optional) a tip shown for a few seconds when the fight starts, e.g. how a
## class that joins in this round plays.
@export_multiline var tip: String = ""
## Scales every enemy in this fight (solo boss rounds: a full party gets
## about four turns per boss action, so bosses get more HP and speed here
## without changing them in the mixed rounds).
@export var enemy_hp_mult: float = 1.0
@export var enemy_speed_mult: float = 1.0
