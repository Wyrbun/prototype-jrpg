# Enemy roster (design draft)

Thiago's enemy designs, plus the building blocks each one needs. Status
column: **have** = the battle system already supports it, **new** = needs to
be built.

## Decisions

- **Parries don't deal damage** (for now). The Goblin's "double damage from
  Parry" is set aside until that changes.
- **Hazard durations count the caster's own turns**: "Rock Spikes last 2
  Stone Golem turns" means they vanish after the Golem has acted twice more.
- **Encounters:** a **12-fight boss rush** (plus a Special Match) with different party lineups, to
  test combinations of enemies and party members (mockup coming). Mixed enemy
  groups are expected, so multi-enemy fights are needed early.

## What's in the game now

Each enemy is a scene in `scenes/characters/` with the skills that existing
building blocks allow. Numbers are first guesses (enemy HP was raised 2.5x and
enemy damage 1.3x after playtesting; after the first full play-test the three
bosses got +20% HP and twice the speed, casting at half speed).

| Enemy | HP | In game now | Waiting on |
|---|---|---|---|
| Goblin Fighter (no positionals) | 225 | Attack (short line, 2 hits), Smash (wide cone, can't be blocked), Defend (lets 40% of a hit through) | |
| Kobold Archer (no positionals) | 175 | Ranged Attack (donut 2.5-12 m: safe only right next to it), Power Shot (unavoidable on its target unless a rock blocks, aims exactly; slow cast, 46 damage; long line, can't be parried, 2 s wind-up; rocks block it), Counter. **Team tactics** when there are two: they fan out (about 8 m apart), while one prepares a Power Shot the other leans toward Ranged Attack, two Power Shots at once are rare, and only the first one uses Counter. A Ranged Attack paired with a Power Shot waits to land 2.5 s after it (grey, tagged NEXT, until the Power Shot is done) | |
| Bandit Arcanist | 188 | Ranged Attack (half-circle), Wind Slash (line; stops at the first one hit and throws them 3 m), Fireball (unavoidable, no Parry or Defend: circle on its target; hits everyone inside, so stand alone) | |
| Ogre Warrior | 450 | Attack (short cone, 2 hits), Shield Bash (line; snaps to its target on reveal, then holds aim; stops at the first one hit; can't be parried), Shout (4 m circle; pushes everyone out), then Sword Spin 2 s later (donut 3.5-6 m; always hits everyone Shout pushed, others can dodge into the middle; can't be parried) | |
| Orc Shaman | 250 | Attack (long line), Healing Ritual (heals allies 15% in a 9 m circle, at most 60 HP each; 3 hits from within 1.5 m interrupt it), Curse (unavoidable, no Parry or Defend: a line to each party member, rocks block; in 2+ lines: double damage) | |
| Stone Golem | 960 | Heavy Attack, Crush, Rock Stomp, Right/Left Golem Smash (half the room, it can't turn), Ceiling Burst (falling circles that leave rocks for ~10 s), the two combined, Rock Spikes (unavoidable: circle on its target, then 4 spikes that hurt anyone walking into them for 2 Golem turns), Stone Guard (Defense stance, lets 30% through) | |
| Living Armor | 900 | Doom Gaze (arena-wide instant death: hide behind the rock it drops), Combo (3 hits in a 4.5 m cone; the last throws you 5 m unless you Parry it; each hit can be Parried), Dark Bolt (a circle on each party member; always hits everyone for 18, overlaps take double), Shadowflare (hits everyone inside its circle; grows from 2 to 11 m over a slow cast; dealing 10% of its HP during the cast contains it, so you can step out), Parry Stance (Counter stance) | |
| Dragon Hatchling | 960 | **Closes in** (`closes_in`): while none of its aimed skills reaches anyone it walks 2.5x faster, so keeping away doesn't leave it casting only Burning Spike. Breath (unavoidable on its target, tracks it exactly; massive cone; damage shrinks the more people it hits: stack up; slow cast, 60% speed), Fire Wave (huge line; leaves fire for 3 Dragon turns), Burning Spike (unavoidable: a circle on each party member; anyone in an overlap drops to 1 HP; each circle keeps burning for 3 Dragon turns, 8 HP/s) | |
| Gale Maw (wall boss, no positionals) | 1,200 | Set into the north wall of the Cliff; never moves. Inhale (whole arena, pulls 4 m toward the wall), Exhale (whole arena, pushes 7 m toward the drop), Maw Bite (80, cone in front of its mouth), Deep Breath (Inhale, then Maw Bite 1.5 s later), Gale Lanes (3 lanes across the arena, gaps between are safe; push 5 m), Breaker (everything 7+ m from the wall; push 4 m), Wall Sweep (a strip along the wall; push 4 m), Undertow (a line to each party member, pulls 3 m, double where lines cross, lines run 3.5 m past you, two lines on an Off-Balance fighter), Gale Burst (Exhale, then Gale Lanes 1 s later). Rocks between you and the wall shelter you, but its blasts crack them (2 cracks and a rock shatters, growing back after 3 of its actions). At half HP the cliff edge crumbles 2.5 m closer. Anyone it pushes or pulls is Winded (12 back on the timeline). Every 4th action it spits out a Gust Sprite (if none is up; 60 HP, a small cone that knocks back 2 m) that go down with it. Defend halves pushes and pulls | |

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
| Power Shot | Smash | Narrow, long line | Unavoidable on its target: no Defend, no Parry; long wind-up; a rock in the way blocks it entirely; Attack-type hits interrupt the wind-up |
| Counter | Counter | Self | Retaliates against normal attacks and Smash |

### Bandit Arcanist
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Ranged attack | Attack | Large half-circle | 1 hit |
| Fireball | Special | Circle centered on a marked character | Damages everyone inside; unavoidable (no Parry or Defend), so the target should stand alone |
| Wind Slash | Attack | Line | Stops at the first character hit and throws them 3 m (not on a Parry); can be Parried |

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
| Healing Ritual | Special | Very large circle | Heals all enemies inside 15% of their max HP, at most 60 each; interrupted by 3 close-range hits |
| Curse | Special | One line toward each party member | Unavoidable (no Parry or Defend); where lines overlap: double damage; a rock blocks a line |

## Stagger bars

Unavoidable skills have a Stagger bar (damage dealt head-on while it
prepares; heavy moves 1.5x). A full bar breaks the skill, sends the enemy
back to the start of the timeline and leaves it taking +25% damage until
its next turn. Skills with a bar cast at half speed in the casting zone.
Rules in `battle-design.md`.

| Enemy | Skill | Bar | When full |
|---|---|---|---|
| Kobold Archer | Power Shot | 30 | Breaks |
| Bandit Arcanist | Fireball | 30 | Breaks |
| Orc Shaman | Curse | 35 | Breaks |
| Orc Shaman | Healing Ritual | 3 close hits (its own rule, shown as a bar) | Interrupted |
| Living Armor | Dark Bolt | 70 | Breaks |
| Living Armor | Shadowflare | 10% of its HP (its own rule, shown as a bar) | Stops growing |
| Dragon Hatchling | Breath | 90 | Breaks |
| Dragon Hatchling | Burning Spike | 120 | Breaks |
| Gale Maw | Inhale | 70 | Breaks |
| Gale Maw | Exhale | 90 | Becomes Broken Exhale: a ring, safe within 8 m of the Maw, push 5 m |
| Gale Maw | Undertow | 80 | Breaks |
| Gale Maw | Gale Burst | 120 | Breaks (no lanes after) |

## Bosses

### Stone Golem
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Heavy attack | Smash | Cone | 1 hit, Smash properties (built) |
| Crush | Smash | Long, thin line | built |
| Rock Stomp | Attack | Short circle around itself | built |
| Rock Spikes | Special | Targeted circle | Leaves 4 rock spikes that damage anyone walking into them; last 2 of the Golem's turns |
| Right / Left Golem Smash | Smash | Half the room (a 180° cone to its right or left, out to the arena's edges) | Locks its facing for the whole cast, so whoever it faced can step out; can't be Parried or Defended; 48 damage |
| Ceiling Burst | Special | 10 circles all over the arena | Grey when the cast starts; from the reveal they fall in a random order, 0.5 s apart (a ring shrinks onto each in its last second). One always lands near each party member. None land on the Golem (or another enemy): circles keep clear of them, and if the Golem walks into one, no rock is left under it, so its own skill never shoves it aside. 28 damage each; each leaves a rock (blocks movement and sight) for ~10 s. The Golem waits at the end of the bar until the last one falls |
| Right / Left Smash + Ceiling Burst | Special | Both at once | 8 circles fall only on the safe half, then the smash lands: stay out of its half and dodge the rocks. Casts at 80%, like the plain Smash; as a Special it can't be interrupted |
| Stone Guard | Defense | Self | Blocks 70% of each hit (lets 30% through); piercing moves go through it, breaking moves end it |

### Living Armor
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Combo | Attack | (melee) | 3 hits; the last one launches the target far away |
| Dark Bolt | Special | Circle on every party member, explodes | Unavoidable (no Parry or Defend); overlapping circles deal double damage |
| Shadowflare | Special | Expanding circle | Grows until enough damage is dealt to the Armor, then explodes a few seconds later |
| Parry Stance | Counter | Self | Punishes attacks while it lasts: wait it out or use Abilities |
| Doom Gaze | Special | The whole arena, with white skulls | Slow cast (30% speed). When it starts, a rock crashes down 5 m away at a compass point (always with room behind it). Anyone the Armor can see when it lands is struck down outright, through barriers and Brace; hiding behind the rock means no damage. The rock goes afterwards |

### Gale Maw (wall boss)
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Inhale | Special | Whole arena | 8 damage, pulls 4 m straight toward the wall; no Parry or Defend for the damage, Defend halves the pull |
| Exhale | Special | Whole arena | 12 damage, pushes 7 m straight toward the far side (the drop); Defend halves the push |
| Maw Bite | Smash | 100° cone, 8 m from its centre (4 m beyond its face) | 80 damage; 3 Attack-type hits interrupt it |
| Deep Breath | Special | Inhale, then Maw Bite 1.5 s later | The pull sets up the bite (as likely as its other skills) |
| Gale Lanes | Attack | 3 lanes across the arena, equal gaps | 40 damage, push 5 m; the gaps are safe; can be Parried |
| Breaker | Smash | Everything 7+ m from the wall | 52 damage, push 4 m; hug the wall at its sides |
| Wall Sweep | Attack | A strip 5.5 m deep along the wall | 46 damage, push 4 m; can be Parried |
| Undertow | Special | A line to each party member, running 3.5 m past them | 18 damage, pulls 3 m along the line, double where lines cross (so standing behind an ally doubles it); an Off-Balance fighter gets two lines; a rock in the line blocks it |
| Gale Burst | Special | Exhale, then Gale Lanes 1 s later | The push lands you somewhere new, then the lanes come |

Also: Exhale, Gale Burst and Breaker **crack rocks** in their area (2 cracks shatter one; it grows back after 3 Maw actions). At **half HP** the south edge **crumbles** 2.5 m (once; anyone standing there teeters). Every push or pull **Winds** the party member (12 back on the timeline). Every 4th action: a **Gust Sprite** (one at a time).

### Gust Sprite (summoned by the Gale Maw)
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Gust | Attack | 100° cone, 2.2 m | 6 damage, knocks back 2 m. 60 HP, fast (speed 14); downed when the Maw falls |

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
| **Forced movement** (push out, launch, pull) | Ogre, Living Armor; pull for future bosses | have (pull: the `pull` field drags those hit towards the enemy; over a drop they fall) |
| **Combo skills** (one skill triggers another) | Ogre (Shout then Sword Spin) | have (follow_up) |
| **Interruptible casts** (hit count or damage threshold) | Shaman, Living Armor | have |
| **Lingering hazards** that last several turns | Golem, Dragon | have (fire trail, rock spikes) |
| **Terrain** that blocks attacks | Kobold | have (rocks block sight and attacks) |
| **Damage scaling by group size** | Dragon | have |
| **Multi-enemy fights** | rounds 2-5, 8, 9, Special | have |
| **Healing enemies** | Shaman | have |
