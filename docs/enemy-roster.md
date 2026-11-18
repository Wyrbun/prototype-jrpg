# Enemy roster (design draft)

Thiago's enemy designs, plus the building blocks each one needs. Status
column: **have** = the battle system already supports it, **new** = needs to
be built.

## Decisions

- **Parries don't deal damage** (for now). The Ratkin's "double damage from
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
bosses got +20% HP and twice the speed, casting at half speed). In the
**solo boss rounds** (8-11) every boss also gets **x1.2 HP and x1.5 speed**
(x1.7 for the Stone Golem) (`Encounter.enemy_hp_mult` / `enemy_speed_mult`).
At x1.25 (x1.4) a full party got about four turns per boss action and a
whole 0.5.0 Boss Rush took almost no damage, so the speed went up. (It was x1.5 HP at first:
the Golem took 10 minutes.) The HP column is the base, used in the mixed rounds.
**Bosses hit 15% harder** (`BattleArena.boss_damage_mult` 1.15, for every
enemy with `boss` on): their skills, falling rocks, rock blasts and the Counter
stance. Summoned sprites and leftover hazards (rock spikes, fire) don't count.
**Melee tracking:** short cones and lines (Golem Heavy Attack, Living Armor
Combo, Ogre Attack, Ratkin Attack and Smash, Gust, the Training Golem's Attack
and Smash) keep turning fast to the end of the cast at a target in melee
range, and the enemy steps after it (`BattleArena.melee_track_*`; details in
`battle-design.md`).
**Boss threat:** bosses lock onto whoever hurt them most lately (weighed
against distance), not just the nearest (`BattleArena.threat_*`).

| Enemy | HP | In game now | Waiting on |
|---|---|---|---|
| Ratkin Fighter (no positionals) | 225 | Attack (short line, 2 hits), Smash (wide cone, can't be blocked), Defend (lets 40% of a hit through) | |
| Kobold Archer (no positionals) | 175 | Ranged Attack (donut 2.5-12 m: safe only right next to it), Power Shot (unavoidable on its target unless a rock blocks, aims exactly; slow cast, 46 damage; long line, can't be parried, 2 s wind-up; rocks block it), Counter. **Team tactics** when there are two: they fan out (about 8 m apart), while one prepares a Power Shot the other leans toward Ranged Attack, two Power Shots at once are rare, and only the first one uses Counter. A Ranged Attack paired with a Power Shot waits to land 2.5 s after it (grey, tagged NEXT, until the Power Shot is done) | |
| Bandit Arcanist | 188 | Ranged Attack (half-circle), Wind Slash (line; stops at the first one hit and throws them 3 m), Fireball (unavoidable, no Parry or Defend: circle on its target; hits everyone inside, so stand alone) | |
| Ogre Warrior | 450 | Attack (short cone, 2 hits), Shield Bash (line; snaps to its target on reveal, then holds aim; stops at the first one hit; can't be parried), Shout (4 m circle; pushes everyone out), then Sword Spin 2 s later (donut 3.5-6 m; always hits everyone Shout pushed, others can dodge into the middle; can't be parried) | |
| Desert Shaman | 250 | Attack (long line), Healing Ritual (heals allies 15% in a 9 m circle, at most 60 HP each; 3 hits from within 1.5 m interrupt it), Curse (unavoidable, no Parry or Defend: a line to each party member, rocks block; in 2+ lines: double damage) | |
| Stone Golem | 960 | Heavy Attack, Crush, Rock Stomp, Right/Left Golem Smash (half the room, it can't turn), Ceiling Burst (falling circles that leave rocks that stay; only its first 2 bursts leave rocks; if none has fallen yet, it always casts one when it first drops to 75% HP), Golem Smash blows up the rocks in its half (circles that hurt), Right + Left / Left + Right Golem Smash (one side, then the other 2 s later: every rock in the arena blows up), the two combined, Rock Spikes (unavoidable: circle on its target, then 4 spikes that hurt anyone walking into them for 2 Golem turns), Stone Guard (Defense stance, lets 30% through) | |
| Living Armor | 900 | Doom Gaze (arena-wide instant death: hide behind the rock it drops), Combo (3 hits in a 4.5 m cone; the last throws you 5 m unless you Parry it; each hit can be Parried), Dark Bolt (a circle on each party member; always hits everyone for 18, overlaps take double), Shadowflare (hits everyone inside its circle; grows slowly from 2 m to the arena's corners (from the middle); 3 Shadow Sprites circle its edge: hit each once and it stops growing; or run to the far side when the Armor is off to one side; a phase at 50% and 20% HP: the first cast after each is a Shadowflare, with about 12 s to stop it), Parry Stance (Counter stance) | |
| Dragon Hatchling | 960 | **Closes in** (`closes_in`): while none of its aimed skills reaches anyone it walks 2.5x faster, so keeping away doesn't leave it casting only Burning Spike. Breath (unavoidable on its target, tracks it exactly; massive cone; damage shrinks the more people it hits: stack up; slow cast, 60% speed), Fire Wave (huge line; leaves fire for 3 Dragon turns), Burning Spike (unavoidable: 20 damage, a circle on each party member; cast least often; anyone in an overlap drops to 1 HP; each circle keeps burning for 3 Dragon turns, 5 under half HP, 8 HP/s). Fire Wave (as often as Breath; fire 5 turns, 20 HP/s + 15 to step in, at most 3 lines), Scorch and Breathe (Fire Wave then Breath), and at half HP once Wings of Fire (four lasting fire lines along the arena, two on its edges: three lanes) | |
| Gale Maw (wall boss, no positionals) | 1,200 | Set into the north wall of the Cliff; never moves. Inhale (whole arena, pulls 4 m toward the wall), Exhale (whole arena, pushes 7 m toward the drop), Maw Bite (80, its whole front out to 8 m: back off or Parry / Defend), Deep Breath (Inhale, then Maw Bite 1.5 s later), Gale Lanes (3 lanes across the arena, gaps between are safe; push 5 m), Breaker (everything 7+ m from the wall; push 4 m), Wall Sweep (a strip along the wall; push 4 m), Undertow (a line to each party member, pulls 3 m, double where lines cross, lines run 3.5 m past you, two lines on an Off-Balance fighter), Gale Burst (Exhale, then Gale Lanes 1 s later). **Under half HP:** Gale Lanes becomes Double Gale Lanes (the 2 gaps first, leaving the 3 lanes safe, then those 3 lanes 2.5 s later), and only now does it combine push / pull with lanes: Gale Burst (Exhale, then Double Gale Lanes) and Gale Draw (Inhale, then Double Gale Lanes). Rocks between you and the wall shelter you, but its blasts crack them (2 cracks and a rock shatters, growing back after 3 of its actions). At half HP the cliff edge crumbles 2.5 m closer. Anyone it pushes or pulls is Winded (12 back on the timeline). Every 4th action it flings a Gust Sprite with one of its paws (if none is up; 60 HP, unkillable, takes 20% damage; Lightweight: every hit knocks it back, walls bounce it, a hole or the ledge drops it; explodes (Detonate, 4 m, 45) after a 25 s fuse; a small cone that knocks back 2 m) that go down with it. Defend halves pushes and pulls. **Only Maw Bite can be Parried**: everything else must be dodged or Defended. **Stagger bars** (hit it head-on): Inhale 70, Deep Breath 70, Undertow 80, Exhale 90 (turns into Broken Exhale), Gale Draw and Gale Burst 120. **Feed it a sprite:** a Gust Sprite knocked into its body while it pulls (Inhale, Deep Breath, Gale Draw: its mouth is open) makes it choke: the sprite's Detonate goes off inside (3x: 135) and it is Staggered (`_check_choke`, `choke_damage_mult`). While its mouth is open, a **black mouth** shows on its front (`_update_mouths`). Otherwise its body bounces sprites off. **Telegraphs:** pulls are teal (pushes pink); a combo's follow-up shows faintly under its first part once revealed; during its whole-arena breaths the floor each rock shelters is drawn clear | |

## Normal enemies

### Ratkin Fighter
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

### Desert Shaman
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
| Desert Shaman | Curse | 35 | Breaks |
| Desert Shaman | Healing Ritual | 3 close hits (its own rule, shown as a bar) | Interrupted |
| Living Armor | Dark Bolt | 70 | Breaks |
| Living Armor | Shadowflare | Hit each of its 3 Shadow Sprites once (shown as 3 pips) | Stops growing |
| Dragon Hatchling | Breath | 90 | Breaks |
| Dragon Hatchling | Burning Spike | 100 | Breaks |
| Gale Maw | Inhale | 70 | Breaks |
| Gale Maw | Exhale | 90 | Becomes Broken Exhale: a ring, safe within 8 m of the Maw, push 5 m |
| Gale Maw | Undertow | 80 | Breaks |
| Gale Maw | Gale Burst | 120 | Breaks (no lanes after) |

## Bosses

### Stone Golem
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Heavy attack | Smash | Cone | 1 hit, Smash properties (built) |
| Crush | Smash | Long, thin line (11 m) | Keeps turning at 160°/s in its last second (`final_turn_speed`). **Goes for someone far:** locks onto a random party member more than 6 m away (`targets_far`, `BattleArena.far_target_min_distance`), unless a Knight's Taunt holds the Golem; nobody far, the usual target. 52 damage |
| Rock Stomp | Attack | Short circle around itself | built |
| Rock Spikes | Special | Targeted circle | Leaves 4 rock spikes that damage anyone walking into them; last 2 of the Golem's turns |
| Right / Left Golem Smash | Smash | Half the room (a 180° cone to its right or left, out to the arena's edges) | Locks its facing for the whole cast, so whoever it faced can step out; can't be Parried, but Defend (either key) softens it; 48 damage. **Hides its side** (single Smashes and Smash + Ceiling Burst, not the doubles): while grey, the area covers the whole room (`hides_side`); which half it hits shows only at the reveal (about 1.3 s before the strike at Round 8 speed), so you dodge on reaction, not in advance. Every fallen rock inside its half gets an orange circle (2.5 m) from the reveal ("ROCKS EXPLODE"); when the Smash lands, those rocks blow up: 30 damage to anyone in a circle, and the rocks are gone. Rocks that fall during a Smash + Ceiling Burst count too. Uncancellable |
| Right + Left / Left + Right Golem Smash | Smash | Half the room, then the other half | One Golem Smash, then a second one on the other side 2 s later (a follow-up: revealed as the first lands; was 1.5 s). Unlike the single Smashes, its first side shows in grey from the start (no `hides_side`). Both blow up the rocks in their half, so the whole arena's rocks go. Move across as soon as the first lands. Likelier the more rocks have lain on the floor for 12 s (+0.3 weight each), half as likely with no rocks. Uncancellable |
| Ceiling Burst | Special | 10 circles all over the arena | Grey when the cast starts; from the reveal they fall in a random order, 0.5 s apart (a ring shrinks onto each in its last second). One always lands near each party member. None land on the Golem (or another enemy): circles keep clear of them, and if the Golem walks into one, no rock is left under it, so its own skill never shoves it aside. 28 damage each; each leaves a rock (blocks movement and sight) that stays until a Golem Smash blows it up. Only the first 2 bursts of a fight (Ceiling Burst or the Smash combos) leave rocks (`Combatant.max_rock_bursts`); later ones still drop their circles. The Golem waits at the end of the bar until the last one falls. Sure at 75% HP: the first cast after the Golem drops to 75% is a Ceiling Burst, unless it already dropped rocks (`sure_below_hp` 0.75) |
| Right / Left Smash + Ceiling Burst | Special | Both at once | 8 circles fall only on the safe half, then the smash lands: stay out of its half and dodge the rocks. Casts at 80%, like the plain Smash; as a Special it can't be interrupted |
| Stone Guard | Defense | Self | Blocks 70% of each hit (lets 30% through); piercing moves go through it, breaking moves end it |

### Living Armor
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Combo | Attack | (melee) | 3 hits; the last one launches the target far away |
| Dark Bolt | Special | Circle on every party member, explodes | Unavoidable (no Parry or Defend); overlapping circles deal double damage |
| Shadowflare | Special | Expanding circle | Calls 3 Shadow Sprites (1 HP, not on the timeline) that circle along its edge at 2 m/s. **A phase, not a random pick:** cast at the Armor's next cast after it drops to 50% HP, and again at 20% (`phase_at_hp`; weight 0). About 12 s to hit all 3 Shadow Sprites (cast speed 0.12); once they're all hit it stops growing, and so it does at full size: either way the rest of the cast gives the slowest party member time to walk out of it from its middle (radius / their speed + `flare_run_out_extra` 0.8 s of battle time; `_settle_growing`). Stopped while still grey, it's revealed at once. 100 damage; can't be Parried (Defend still softens it) up to the distance from the arena's middle to its corners: cast from the middle it covers everything, cast off to one side the far side stays safe. Hitting all 3 sprites stops it growing; then step out. Uncancellable |
| Parry Stance | Counter | Self | Punishes attacks while it lasts: wait it out or use Abilities |
| Doom Gaze | Special | The whole arena, with white skulls | Slow cast (30% speed). Its area is pinned to the arena's centre, square with the arena (`arena_aligned`), so it never turns with the Armor. When it starts, a rock crashes down 5 m away at a compass point (always with room behind it; in a corner, diagonally or towards the middle). Anyone the Armor can see when it lands is struck down outright, through barriers and Brace; hiding behind the rock means no damage. The rock goes afterwards |

### Gale Maw (wall boss)
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Inhale | Special | Whole arena | 8 damage, pulls 4 m straight toward the wall; no Parry or Defend for the damage, Defend halves the pull |
| Exhale | Special | Whole arena | 12 damage, pushes 7 m straight toward the far side (the drop); Defend halves the push |
| Maw Bite | Smash | 180° (its whole front), 8 m from its centre (4 m beyond its face) | 80 damage; no stepping round it: back out of reach, or Parry / Defend. High risk for melee, high reward. 3 Attack-type hits interrupt it |
| Deep Breath | Special | Inhale, then Maw Bite 1.5 s later | The pull sets up the bite (as likely as its other skills) |
| Gale Lanes | Attack | 3 lanes across the arena, equal gaps | 40 damage, push 5 m; the gaps are safe; can't be Parried (Defend still works) |
| Breaker | Smash | Everything 7+ m from the wall | 52 damage, push 4 m; hug the wall at its sides |
| Wall Sweep | Attack | A strip 5.5 m deep along the wall | 46 damage, push 4 m; can't be Parried (Defend still works) |
| Undertow | Special | A line to each party member, running 3.5 m past them | 18 damage, pulls 3 m along the line, double where lines cross (so standing behind an ally doubles it); an Off-Balance fighter gets two lines; a rock in the line blocks it |
| Double Gale Lanes | Attack | Under half HP, instead of Gale Lanes: the 2 gaps between the lanes (`lanes_in_gaps`), then Gale Lanes on the 3 lanes 2.5 s later | 40 damage each, push 5 m; stand in a lane, then step into a gap |
| Gale Burst | Special | Under half HP: Exhale, then Double Gale Lanes 1 s later | The push lands you somewhere new, then the lanes come |
| Gale Draw | Special | Under half HP: Inhale, then Double Gale Lanes 1 s later | The pull drags you toward the wall, then the lanes come |

Also: Exhale, Gale Burst and Breaker **crack rocks** in their area (2 cracks shatter one; it grows back after 3 Maw actions). At **half HP** the south edge **crumbles** 2.5 m (once; anyone standing there teeters). Every push or pull **Winds** the party member (12 back on the timeline). Every 4th action: a **Gust Sprite** (one at a time).

### Gust Sprite (summoned by the Gale Maw)
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Gust | Attack | 100° cone, 2.2 m | 6 damage, knocks back 2 m. 60 HP, **stationary** (`move_speed` 0: it never walks back after a push); downed when the Maw falls. **Unkillable** (`unkillable`: damage stops at 1 HP; it only leaves by falling) and takes 20% damage (`damage_taken_share` 0.2), but **Lightweight** (`lightweight`; tag LIGHTWEIGHT): **every hit knocks it back** (at least 1.5 m, `lightweight_push`), and pushes send it 1.5x as far (`knockback_taken`). Walls, corners and rocks **bounce** it off (it never sticks; `_knock_lightweight`), and the moment any part of its body touches or crosses a hole or the ledge, it falls and is gone (`_touches_drop`). The move list tags every move PUSHES on it |
| Detonate | Attack (self-destruct) | circle 4 m round it | **Fuse:** 25 s of battle time after it appears (tag "FUSE 12s"; a "5 s!" warning). Then it drops what it was preparing and casts Detonate at once (slow cast, telegraphed): 45 damage, launches 3 m, can't be Parried (Defend works). It blows itself up when it lands, hit or miss (`self_destruct`). Knock it off the edge during the cast to stop it; an interrupt only delays it |

### Dragon Hatchling
| Skill | Kind | Shape | Rules |
|---|---|---|---|
| Breath | Attack | Massive cone | Damage is reduced when several characters are hit together |
| Fire Wave | Smash | Long line (14 m x 2.4 m) | As often as Breath. Leaves fire for 5 Dragon turns: 20 HP/s, and 15 damage for stepping in (`trail_touch_damage`; not for anyone already standing there). At most 3 fire lines; a 4th puts out the oldest (`trail_cap`, `trail_group`) |
| Scorch and Breathe | Smash, then Attack | Fire Wave's line, then Breath | Fire Wave, then Breath 1.5 s later at its usual target: stack in the space the fire leaves (its follow-up shows faintly once revealed) |
| Burning Spike | Special | Fire circle on every party member | Anyone caught where circles overlap drops to 1 HP. Circles burn 3 Dragon turns, 5 under half HP (`trail_turns_below_half`) |
| Wings of Fire | Special (phase, at half HP, once) | Four fire lines along the arena, two of them on its edges (`arena_aligned`: on the arena, not on the Dragon) | 30 damage on the lines as it lands, then fire for the rest of the fight (20 HP/s, 15 to step in): three 3.4 m lanes left to fight in |

## Building blocks

| Building block | Used by | Status |
|---|---|---|
| Cone, circle around self, half-circle (180° cone) | Golem, Arcanist, most enemies | have |
| **Enemy template** (skills edited in the Inspector) | all | have |
| Hidden intent, casting zone, Parry / Defend | all | have |
| Defense / Counter stances | Ratkin, Kobold | have (partial guard: let_through) |
| **Line** (rectangle) shape | Ratkin, Kobold, Arcanist, Ogre, Shaman, Golem, Dragon | have |
| **Donut** shape | Kobold, Ogre | have |
| **Multi-hit enemy attacks** (one ring per hit) | Ratkin, Ogre, Living Armor | have (Living Armor uses it) |
| **Cannot be parried / cannot be blocked** flags | Ratkin, Kobold, Ogre, Shaman | have |
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
