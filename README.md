# Prototype JRPG

A 3D JRPG battle system prototype built in **Godot 4.7**. It blends four
classic battle systems into one hybrid:

- **Grandia 2**: a shared timeline that decides who acts next, with a casting
  zone where enemies prepare their moves.
- **Valkyrie Profile 2**: real-time positioning on a 3D battlefield, and
  attacking enemies from the right angle.
- **Mabinogi**: a rock-paper-scissors skill triangle (Attack, Smash, Defense,
  Counter) and reading what the enemy has loaded.
- **Legend of Legaia**: building combos in an AP bar and playing them with
  timed button presses.

Everything is still placeholder art: capsules for the party, a cube for the
enemy. The goal of this stage is a fun core loop, not visuals.

## How a battle works

**The timeline.** Every fighter slides along a bar at the top of the screen at
their own speed. Reaching the end means it's their turn. The orange stretch
near the end is the **casting zone**: enemies there are preparing a skill.
At first you only see "???", and the skill is revealed late, so reading it is
part of the challenge.

**Positioning (between turns).** While the timeline runs, you steer one party
member in real time and press **Tab** to switch between them. Enemies and the
AI-controlled allies move too. Each enemy shows its threat area on the floor:
faint while harmless, colored once its skill is revealed. Step into a live
area and the enemy strikes immediately. The Golem cycles its Attack between a
wide cone, a circle around itself, and a long narrow cone.

**Your turn.** The fighter whose turn it is is locked in place, and a menu
opens: **Attack** (needs an enemy within the gold reach ring around the
fighter) or **Wait** (spends no AP and brings the next turn sooner).

**Combos.** Attack opens a Legaia-style combo bar. Pick moves (Slash, Thrust,
Double Slash, Overhead Smash) to fill the bar with party AP, then watch a
playhead sweep across it. Every hit has a timing box: press **J** inside it for
a **Perfect** hit.

**Enemy strikes.** When an enemy attacks, a ring shrinks onto the target.
Press **E** as it turns gold to **Parry**, or **Q** to **Defend** (costs AP;
the damage you take comes back if you aren't hit again before your next turn).

**The skill triangle.** Attack beats Smash, Smash breaks Defense, Defense
blocks Attack, and Counter punishes anything that hits it. It applies both to
what enemies throw at you and to what you throw at them.

**AP and risk.** AP is one shared party pool that recharges over time. Every
Parry and Perfect hit raises the party's **max AP** for the rest of the fight,
and a bigger max AP also recharges faster. Missing a Parry or a timed hit
resets max AP to 100, so the better you play, the more you have to lose.

## Controls

| When | Key | Action |
|---|---|---|
| Between turns | WASD / arrows | Move the party member you're steering |
| Between turns | Tab | Switch to the next party member |
| Your turn | W / S, J | Choose and select in the menu |
| Combo bar | J / K | Add a move / remove the last one (or go back) |
| Combo bar | Space | Begin the combo |
| Combo playing | J | Timed hit: press inside the box for a Perfect |
| Enemy strike | E | Parry (when the ring turns gold) |
| Enemy strike | Q | Defend (costs AP) |
| Battle over | R | Restart |

Keys can be changed in **Project > Project Settings > Input Map**.

## Running it

1. Install **Godot 4.7** (standard version, not .NET) from godotengine.org.
2. Open Godot, click **Import**, and select this folder's `project.godot`.
3. Press **F5** to play.

## Project layout

```
scenes/battle/battle_arena.tscn   the battle scene (main scene)
scripts/battle/battle_arena.gd    the battle flow: timeline, turns, strikes, combos, AI
scripts/battle/combatant.gd       shared by every fighter: stats, HP, timeline, enemy skill setup
scripts/battle/skills.gd          the skill triangle: names, colors, areas, damage, wind-up
scripts/battle/moves.gd           the party's combo moves: AP cost, hits, timing, effects
scripts/battle/attack_range.gd    an enemy's threat area drawn on the floor
scripts/battle/timeline_bar.gd    the turn-order bar
scripts/battle/battle_menu.gd     the command menu and combo bar
scripts/battle/party_status.gd    HP bars
docs/battle-design.md             detailed design notes and open questions
docs/CHANGELOG.md                 how the system evolved, milestone by milestone
backups/                          zipped snapshots from before version control
```

Most tuning numbers are exposed in Godot's **Inspector**: select the
BattleArena node for battle-wide settings (AP, timing windows, battle speed),
or a fighter for its own stats (HP, speed, attack power, reach, combo limit).

## Roadmap

- [x] Arena, timeline and turn order
- [x] Real-time positioning, enemy threat areas, AI allies
- [x] Hidden enemy intent, revealed late in the casting zone
- [x] Enemy strikes with Parry and Defend; HP and knockouts
- [x] Command menu and Legaia-style combo bar with timed hits
- [x] Max AP that grows with skill and resets on mistakes
- [x] Positioning between turns, Wait command (current test setup)
- [ ] Enemy template: design new enemies in the Inspector without code
- [ ] Stagger gauge and knockdown (push away, disable or reshape enemy areas)
- [ ] Complete fight: proper victory and defeat screens, balance pass
- [ ] Abilities and Items

See [`docs/battle-design.md`](docs/battle-design.md) for the full design
reasoning and [`docs/CHANGELOG.md`](docs/CHANGELOG.md) for the history.
