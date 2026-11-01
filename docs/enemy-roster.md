# Enemy roster (design draft)

Thiago's enemy designs, plus the building blocks each one needs. Status
column: **have** = the battle system already supports it, **new** = needs to
be built.

## Decisions

- **Parries don't deal damage** (for now). The Goblin's "double damage from
  Parry" is set aside until that changes.
- **Hazard durations count the caster's own turns**: "Rock Spikes last 2
  Stone Golem turns" means they vanish after the Golem has acted twice more.
- **Encounters:** a **10-fight boss rush** with different party lineups, to
  test combinations of enemies and party members (mockup coming). Mixed enemy
  groups are expected, so multi-enemy fights are needed early.

## What's in the game now

Each enemy is a scene in `scenes/characters/` with the skills that existing
building blocks allow. Numbers are first guesses (enemy HP was raised 2.5x and
enemy damage 1.3x after playtesting; after the first full play-test the three
bosses got +20% HP and twice the speed, casting at half speed).

| Enemy | HP | In game now | Waiting on |
|---|---|---|---|
| Goblin Fighter | 225 | Attack (short line, 2 hits), Smash (wide cone, can't be blocked), Defend (lets 40% of a hit through) | |
| Kobold Archer | 175 | Ranged Attack (donut 2.5-12 m: safe only right next to it), Power Shot (unavoidable on its target unless a rock blocks, aims exactly; slow cast, 58 damage; long line, can't be parried, 2 s wind-up; rocks block it), Counter | |
| Bandit Arcanist | 188 | Ranged Attack (half-circle), Wind Slash (line; stops at the first one hit), Fireball (unavoidable, no Parry or Defend: circle on its target; hits everyone inside, so stand alone) | |
| Ogre Warrior | 450 | Attack (short cone, 2 hits), Shield Bash (line; snaps to its target on reveal, then holds aim; stops at the first one hit; can't be parried), Shout (4 m circle; pushes everyone out), then Sword Spin 2 s later (donut 3.5-6 m; always hits everyone Shout pushed, others can dodge into the middle; can't be parried) | |
| Orc Shaman | 250 | Attack (long line), Healing Ritual (heals allies 15% in a 9 m circle; 3 hits from within 1.5 m interrupt it), Curse (unavoidable: a line to each party member, rocks block; in 2+ lines: double damage, can't be blocked) | |
| Stone Golem | 960 | Heavy Attack, Crush, Rock Stomp, Rock Spikes (unavoidable: circle on its target, then 4 spikes that hurt anyone walking into them for 2 Golem turns) | |
| Living Armor | 900 | Combo (3 hits in a 4.5 m cone; the last throws you 5 m; a Parry stops it), Dark Bolt (a circle on each party member; always hits everyone for 18, overlaps take double), Shadowflare (hits everyone inside its circle; grows from 2 to 11 m over a slow cast; dealing 10% of its HP during the cast contains it, so you can step out) | |
| Dragon Hatchling | 960 | Breath (unavoidable on its target, tracks it exactly; massive cone; damage shrinks the more people it hits: stack up; slow cast, 60% speed), Fire Wave (huge line; leaves fire for 3 Dragon turns), Burning Spike (unavoidable: a circle on each party member; anyone in an overlap drops to 1 HP; each circle keeps burning for 3 Dragon turns, 8 HP/s) | |

## Normal enemies

### Goblin Fighter
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Normal attack | Attack | Short line | 2 hits |
| Smash | Smash | Wide cone | Ignores Defense (double damage from Parry: on hold, Parries deal no damage) |
| Defend | Defense | Self | Reduces damage from normal attacks (not a full block) |

### Kobold Archer
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Ranged attack | Attack | Donut (safe close up and far away) | 1 hit |
| Power Shot | Smash | Narrow, long line | Defend blocks it; cannot be Parried; long wind-up; terrain blocks it entirely |
| Counter | Counter | Self | Retaliates against normal attacks and Smash |

### Bandit Arcanist
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Ranged attack | Attack | Large half-circle | 1 hit |
| Fireball | Special | Circle centered on a marked character | Damages everyone inside; unavoidable (no Parry or Defend), so the target should stand alone |
| Wind Slash | Attack | Line | Stops at the first character hit; can be Parried |

### Ogre Warrior
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Normal attack | Attack | Short cone | 2 hits |
| Shield Bash | Smash | Line that snaps to a target | Stops at the first character hit; Defend blocks it; cannot be Parried |
| Shout | Special | Large circle around itself | Pushes everyone inside out of it |
| Sword Spin | Smash | Donut | Follows Shout immediately; anyone hit by Shout is guaranteed to be hit; cannot be Parried |

### Orc Shaman
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Normal attack | Attack | Long line | 1 hit |
| Healing Ritual | Special | Very large circle | Heals all enemies inside; interrupted by 3 close-range hits |
| Curse | Special | One line toward each party member | Where lines overlap: double damage and unblockable; can be Parried |

## Bosses

### Stone Golem
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Heavy attack | Smash | Cone | 1 hit, Smash properties (built) |
| Crush | Smash | Long, thin line | built |
| Rock Stomp | Attack | Short circle around itself | built |
| Rock Spikes | Special | Targeted circle | Leaves 4 rock spikes that damage anyone walking into them; last 2 of the Golem's turns |

### Living Armor
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Combo | Attack | (melee) | 3 hits; the last one launches the target far away |
| Dark Bolt | Special | Circle on every party member, explodes | Overlapping circles deal double damage; can be Parried |
| Shadowflare | Special | Expanding circle | Grows until enough damage is dealt to the Armor, then explodes a few seconds later |

### Dragon Hatchling
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Breath | Attack | Massive cone | Damage is reduced when several characters are hit together |
| Fire Wave | Special | Massive line in a direction | Leaves a burning trail for 3 turns |
| Burning Spike | Special | Fire circle on every party member | Anyone caught where circles overlap drops to 1 HP |

## Building blocks

| Building block | Used by | Status |
|---|---|---|
| Cone, circle around self, half-circle (180° cone) | Golem, Arcanist, most enemies | have |
| **Enemy template** (skills edited in the Inspector) | all | have |
| Hidden intent, casting zone, Parry / Defend | all | have |
| Defense / Counter stances | Goblin, Kobold | have (partial guard: let_through) |
| **Line** (rectangle) shape | Goblin, Kobold, Arcanist, Ogre, Shaman, Golem, Dragon | have |
| **Donut** shape | Kobold, Ogre | have |
| **Multi-hit enemy attacks** (one ring per hit) | Goblin, Ogre, Living Armor | have (Living Armor uses it) |
| **Cannot be parried / cannot be blocked** flags | Goblin, Kobold, Ogre, Shaman | have |
| **Shape placed on a character** (marked target) | Arcanist, Golem, Living Armor, Dragon | have (on one: Fireball, Rock Spikes; on every member: Dark Bolt, Burning Spike) |
| **One shape per party member** + **overlap rules** | Shaman, Living Armor, Dragon | have |
| **Stops at first hit** / **snaps to a target** | Arcanist, Ogre | have |
| **Forced movement** (push out, launch) | Ogre, Living Armor | have |
| **Combo skills** (one skill triggers another) | Ogre (Shout then Sword Spin) | have (follow_up) |
| **Interruptible casts** (hit count or damage threshold) | Shaman, Living Armor | have |
| **Lingering hazards** that last several turns | Golem, Dragon | have (fire trail, rock spikes) |
| **Terrain** that blocks attacks | Kobold | have (rocks block sight and attacks) |
| **Damage scaling by group size** | Dragon | have |
| **Multi-enemy fights** | rounds 2-5, 8, 9, Special | have |
| **Healing enemies** | Shaman | have |
