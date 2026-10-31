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
| Fireball | Special | Circle centered on a marked character | Damages everyone inside; can only be Parried if the target is alone |
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
| Defense / Counter stances | Goblin, Kobold | have (Goblin's Defend needs partial reduction) |
| **Line** (rectangle) shape | Goblin, Kobold, Arcanist, Ogre, Shaman, Golem, Dragon | have |
| **Donut** shape | Kobold, Ogre | have |
| **Multi-hit enemy attacks** (one ring per hit) | Goblin, Ogre, Living Armor | new |
| **Cannot be parried / cannot be blocked** flags | Goblin, Kobold, Ogre, Shaman | have |
| **Shape placed on a character** (marked target) | Arcanist, Golem, Living Armor, Dragon | new |
| **One shape per party member** + **overlap rules** | Shaman, Living Armor, Dragon | new |
| **Stops at first hit** / **snaps to a target** | Arcanist, Ogre | new |
| **Forced movement** (push out, launch) | Ogre, Living Armor | new |
| **Combo skills** (one skill triggers another) | Ogre (Shout then Sword Spin) | new |
| **Interruptible casts** (hit count or damage threshold) | Shaman, Living Armor | new; overlaps with the stagger milestone |
| **Lingering hazards** that last several turns | Golem, Dragon | new |
| **Terrain** that blocks attacks | Kobold | new: the arena has no obstacles yet |
| **Damage scaling by group size** | Dragon | new |
| **Healing enemies** + **multi-enemy fights** | Shaman | new: only single-enemy fights tested so far |
