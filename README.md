# Prototype JRPG

A 3D JRPG battle system prototype built in **Godot 4.7**. It blends four
classic battle systems into one hybrid:

- **Grandia 2**: a shared timeline that decides who acts next, with a casting
  zone where enemies prepare their moves.
- **Valkyrie Profile 2**: real-time positioning on a 3D battlefield, and
  attacking enemies from the right angle (the Assassin hits hardest from
  behind).
- **Mabinogi**: a rock-paper-scissors skill triangle (Attack, Smash, Defense,
  Counter) and reading what the enemy has loaded.
- **Legend of Legaia**: building combos in an AP bar and playing them with
  timed button presses.

Everything is still placeholder art: capsules for the party, boxes for the
enemies. The goal of this stage is a fun core loop, not visuals.

## Boss rush

The game plays as a **12-fight boss rush** (`data/boss_rush.tres`), with a
different party lineup and arena each round, to test how enemies and party
members combine. The title screen also has **Round Select**, and **N / P**
still jump between rounds during a fight.

**Saving is automatic in the Boss Rush:** every fight saves as it starts (and
a win saves the next round). **Continue** on the title screen starts the
saved fight from the beginning; beating the last round clears the save.
Round Select and the tutorial don't save.

**From Round 7 (the boss rounds) you choose the party:** any 1 to 4 of the
five classes, solo included. Retrying keeps your pick; the next round asks
again. Round 6 introduces the fifth class, the Assassin.

**Esc pauses** any fight: Resume, Restart fight or Quit to title.

## Tutorial

**Tutorial** on the title screen is one guided fight against a Training
Golem that teaches every mechanic in 12 lessons: moving and the camera, the
timeline, combos and timed hits, Wait, reading enemy skills, Parry and Defend,
the skill triangle, Abilities (the Archer, Mage and Cleric join along the
way, with their Hold and Tap timings), max AP, rocks, the special skills
later enemies use, and the Assassin (getting behind enemies, Shadowstep,
Marks, Execute, auto-parry). It ends with free practice. Notes pause the
fight until you press J; goals run until you've done them. Nobody can fall,
so it can't be lost.

| Round | Party | Enemies | Arena |
|---|---|---|---|
| 1 | Knight | Goblin Fighter | square |
| 2 | Knight, Archer | 2 Kobold Archers | circle with 3 rocks |
| 3 | Knight, Mage | Goblin Fighter, Bandit Arcanist | long rectangle |
| 4 | Knight, Cleric | Kobold Archer, Orc Shaman | circle around a pit |
| 5 | Knight, Archer, Mage | Ogre Warrior, Bandit Arcanist, Orc Shaman | rectangle with 4 rocks |
| 6 | Assassin, Knight | Ogre Warrior, Goblin Fighter | square (introduces the Assassin) |
| 7 | your pick (1-4) | Stone Golem | large arena |
| 8 | your pick | Living Armor | large arena |
| 9 | your pick | Stone Golem, Kobold Archer, Ogre Warrior | large arena |
| 10 | your pick | Living Armor, Orc Shaman, 2 Goblin Fighters | large arena |
| 11 | your pick | Dragon Hatchling | large arena |
| Special | your pick | Stone Golem, Living Armor, Dragon Hatchling | large arena |

Rocks block movement and line of sight (no attacks through them, either
way). The pit blocks movement only.

![The arenas](docs/arenas.png)

## How a battle works

**The timeline.** Every fighter slides along a bar at the top of the screen at
their own speed. Reaching the end means it's their turn. The orange stretch
near the end is the **casting zone**: enemies there are preparing a skill.
Their area appears on the floor in grey right away ("???"), and the skill's
name and color are revealed later. While casting, an enemy turns to follow
whoever it locked onto, and only slows down in the last second: that's when
to slip out.

**Positioning (between turns).** While the timeline runs, you steer one party
member in real time and press **Tab** to switch between them. The fight
doesn't wait: enemies and the AI-controlled allies keep moving whether you
move or not. Allies dodge enemy areas, spread out or stack
up when a skill calls for it, and close in on a healing enemy so you can
interrupt it. Each enemy shows its threat area on the floor:
faint while harmless, colored once its skill is revealed. When the enemy's
icon reaches the end of the bar, anyone inside its area is hit. Each enemy
has its own skills and area shapes: cones, circles, lines and donuts. Some
skills are **unavoidable** and are answered by spreading out, stacking up or
standing alone instead. Enemies that share a name (Kobold Archer A / B) carry
their letter on the timeline, and the enemy you're aiming at gets a gold
ring there.

**Your turn.** The fighter whose turn it is is locked in place, and a menu
opens: **Attack** (needs an enemy in reach), **Abilities** (one skill per
turn; afterwards Abilities greys out and you can still Attack or Wait), or **Wait** (spends no AP and brings the next turn sooner).

**Combos.** Attack asks which enemy to hit when more than one is in reach
(W / S, then J), then opens a Legaia-style combo bar with the class's own
attacks. The highlighted move shows on the floor what it would hit. Fill the
bar with party AP (the bar is as long as the class's AP), then watch a
playhead sweep across it. Every hit has a timing, and nailing it is a
**Perfect** (+50% damage, more max AP). Timings are optional: no press is a
normal hit. There are three kinds:

- **Press** (white square boxes): press **J** inside the box. A press at the
  wrong moment ends the combo.
- **Hold** (blue, rounded; Archer, Cleric): press in the first box, hold, let go in
  the last. A bad let-go only loses the Perfect.
- **Tap** (pink, diamonds; Mage): tap **J** exactly the shown number of
  times. One tap too many is a miss.

The Assassin's hits land at random moments in their boxes.

**Arts (Knight, so far).** Basic moves in the right order merge into a named
Art on the bar, Legend of Legaia style: Slash + Slash becomes Double Slash,
Thrust + Thrust + Slash becomes Smash, and four moves make the finisher
Crusader's Edge. Arts hit harder than their parts, and longer ones add
effects. Arts you haven't found are secret: put moves in an order that hides
one, and when the combo reaches it the blocks merge on a **NEW ART!** banner.
After that it merges as you build it and appears in the Arts panel, which
also tells you the next move for any known Art you're on the way to. **Tab**
in the combo bar opens the list: pick a known Art and its whole recipe goes
on the bar as that Art. **Forget Arts** on the title screen makes them all
secret again.

**Enemy strikes.** When an enemy attacks, a ring shrinks onto the target
(one ring per hit for multi-hit attacks), and the floor areas hide so the
ring is all you need to watch. Press **E** as it turns gold to **Parry**, or
**Q** to **Defend** (costs AP; the damage you take comes back if you aren't
hit again before your next turn). Not every class can do both (see below);
the Assassin parries automatically while it has Marks out.

## Classes

| Class | HP | AP | Block / Parry | Attacks | Skills |
|---|---|---|---|---|---|
| Knight | 200 | 60 | both | Slash, Thrust (ignores Defense), Guard Strike (delays its turn), and Arts made from them: Double Slash, Lunge, Shield Rush, Smash, Crusader's Edge | Light Heal, Brace, Shield Bash, Taunt |
| Archer | 150 | 70 | neither | Shoot, Triple Shot, Stunning Arrow (Hold), Gale Shot (Hold) | Jump, Riposte, True Sight, Agility |
| Mage | 100 | 90 | Parry only | Energy Blast (Tap 3), Firebolt (Tap 5), Tempest, Meteor Strike (Tap 8) | Arcane Barrier, Concentrate, Teleport |
| Cleric | 130 | 60 | Block only | Bash (more hits each time, each weaker), Divine Barrier (Hold: Perfect = bigger barrier), Holy Light | Healing, Shielding, Haste, Full Cure |
| Assassin | 170 | 50 | auto-parry with Marks | Stab, Shadowstep, Backstab, Execute (all stronger from behind) | Hook, Death Sentence, Shadow Cloak, Vanish |

**The Assassin** puts **Assassin's Marks** on enemies (Backstab from behind,
Death Sentence, every 3rd Stab on a Marked enemy) and spends them: Execute
gets 15 AP cheaper per Mark, auto-parry uses one, Hook and Shadow Cloak use
a target's Marks. While you steer it, a ring under each enemy shows its front
(arrow) and back (violet arc); small enemies like Goblins and Kobolds have a
full violet ring, meaning any side counts as behind.

A class's **AP** is the most it can spend in one turn, on a combo or a skill;
the AP itself comes from the shared party pool. Effects that last "3 turns"
count the caster's turns. Every number lives in `scripts/battle/moves.gd`.

**The skill triangle.** Attack beats Smash, Smash breaks Defense, Defense
blocks Attack, and Counter punishes anything that hits it. It applies both to
what enemies throw at you and to what you throw at them.

**AP and risk.** AP is one shared party pool that recharges over time. Every
Parry and Perfect hit raises the party's **max AP** for the rest of the fight
(100 per member plus 100, at most 500), and a bigger max AP also recharges faster. Missing a Parry or a timed hit
drops AP to 0 and resets max AP to 100, so the better you play, the more you
have to lose.

## Controls

| When | Key | Action |
|---|---|---|
| Between turns | WASD / arrows | Move the party member you're steering |
| Between turns | Tab | Switch to the next party member |
| Your turn | W / S, J or Enter | Choose and select in the menu |
| Combo bar | J / K (or Enter / Backspace) | Add a move / remove the last one (or go back) |
| Abilities | W / S, J / K | Choose a skill, use it / go back |
| Choosing a target | W / S (Jump: WASD), J / K | Pick who or where, confirm / go back |
| Combo bar | Space | Begin the combo |
| Combo playing | J or Enter | Timed hit: press in the box, hold through a Hold bar, or tap the shown count |
| Enemy strike | E | Parry (when the ring turns gold) |
| Enemy strike | Q | Defend (costs AP) |
| Any time | Z / C, or right-drag | Rotate the camera (movement follows it) |
| Any time | Mouse wheel / V | Zoom / reset the camera |
| In a fight | Esc | Pause menu: Resume, Restart fight, Quit to title |
| Before a boss round | W / S, J | Tick 1 to 4 party members, then start |
| Any time (not in the tutorial) | N / P | Next / previous round |
| Battle over | R | Restart the round |

These are the default keys. **Change Keys** on the title screen sets your
own (saved in `user://keybinds.cfg`), and every hint in the game follows
them. Esc (pause) and O (open reports) stay fixed.

## Running it

1. Install **Godot 4.7** (standard version, not .NET) from godotengine.org.
2. Open Godot, click **Import**, and select this folder's `project.godot`.
3. Press **F5** to play. The game opens on the title screen.

## Project layout

```
scenes/ui/title_menu.tscn         the title screen (main scene): Continue, Boss Rush, Tutorial, Round Select, Controls, Change Keys, Forget Arts
scenes/battle/battle_arena.tscn   the battle scene; loads the current round or the tutorial
scripts/keybinds.gd               rebindable keys: saving them and filling key names into hints
scripts/save_game.gd              Boss Rush auto-save (Continue)
scripts/battle/tutorial.gd        the tutorial's lessons: text, goals, how each one sets up the fight
scripts/battle/tutorial_panel.gd  the tutorial's note / goal panel
data/tutorial.tres                the tutorial's fight: training arena, Knight, Training Golem
scenes/arenas/                    one scene per arena: floor shape, rocks, pit, start spots
scenes/characters/                one scene per party member and enemy (stats and skills)
data/boss_rush.tres               the rounds: arena, party lineup, enemies
scripts/battle/arena.gd           arena edges, obstacles, steering, line of sight
scripts/battle/arena_obstacle.gd  a rock (blocks sight) or pit (doesn't)
scripts/battle/encounter.gd       one round's data; boss_rush.gd holds the list
scripts/battle/battle_arena.gd    the battle flow: timeline, turns, strikes, combos, AI
scripts/battle/combatant.gd       shared by every fighter: stats, HP, timeline, enemy skill setup
scripts/battle/skills.gd          the skill triangle: names, colors, default areas
scripts/battle/enemy_skill.gd     one enemy skill: shape, damage, wind-up, rules (edited in the Inspector)
scripts/battle/moves.gd           every class's attacks and skills: AP cost, hits, timing, areas, effects
scripts/battle/attack_range.gd    an enemy's threat area drawn on the floor
scripts/battle/positional_ring.gd the front / back ring under enemies (Assassin)
scripts/battle/timeline_bar.gd    the turn-order bar
scripts/battle/battle_menu.gd     the command menu and combo bar (Press / Hold / Tap timings)
scripts/battle/ap_meter.gd        the party AP meter
scripts/battle/combo_counter.gd   hits, damage and Perfects shown during a combo
scripts/battle/pause_menu.gd      the Esc pause menu
scripts/battle/party_picker.gd    choosing the party before boss rounds
scripts/battle/playtest_log.gd    the play-test report written after every fight
scripts/battle/party_status.gd    HP bars
docs/battle-design.md             detailed design notes and open questions
docs/CHANGELOG.md                 how the system evolved, milestone by milestone
backups/                          zipped snapshots from before version control
```

Most tuning numbers are exposed in Godot's **Inspector**: select the
BattleArena node for battle-wide settings (AP, timing windows, battle speed,
which round F5 starts on). Open a character scene in `scenes/characters/` to
change its stats (HP, speed, attack power, reach, combo limit), or an arena
scene in `scenes/arenas/` to move rocks and start spots.

**Designing an enemy:** open its scene and look at **Combat > Skills** in the
Inspector. Each skill has a name, a triangle kind (Attack, Smash, Defense,
Counter), a weight (how often it's picked), an area (cone, circle, line or
donut, with its size), damage, wind-up, and the rules "cannot be parried" and
"cannot be blocked".

## Roadmap

- [x] Arena, timeline and turn order
- [x] Real-time positioning, enemy threat areas, AI allies
- [x] Hidden enemy intent, revealed late in the casting zone
- [x] Enemy strikes with Parry and Defend; HP and knockouts
- [x] Command menu and Legaia-style combo bar with timed hits
- [x] Max AP that grows with skill and resets on mistakes
- [x] Positioning between turns, Wait command (current test setup)
- [x] Enemy template: design enemy skills in the Inspector without code
- [x] Boss rush: 12 rounds, arenas with rocks and a pit, multi-enemy fights
- [x] Classes: Knight, Archer, Mage, Cleric, Assassin, each with attacks and skills
- [x] Timing types: Press, Hold and Release, Tap; positionals and Marks (Assassin)
- [x] Title screen and a guided tutorial
- [x] Pause menu, Boss Rush auto-save, rebindable keys, party picker for boss rounds
- [x] Roster building blocks: multi-hit attacks, marked targets, hazards, healing
- [x] Play-test reports after every fight (O on the end screen opens them)
- [ ] Stagger gauge and knockdown (push away, disable or reshape enemy areas)
- [ ] Complete fight: proper victory and defeat screens, balance pass
- [ ] Items (the menu entry is there, marked "coming later")

See [`docs/battle-design.md`](docs/battle-design.md) for the full design
reasoning and [`docs/CHANGELOG.md`](docs/CHANGELOG.md) for the history.
