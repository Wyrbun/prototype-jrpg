# Prototype JRPG

A 3D JRPG battle system prototype built in **Godot 4.7**, mixing four classic
battle systems:

- **Grandia 2**: a shared timeline, with a casting zone where enemies prepare their moves
- **Valkyrie Profile 2**: real-time positioning, and angles that matter
- **Mabinogi**: a skill triangle (Attack, Smash, Defense, Counter) and reading the enemy
- **Legend of Legaia**: combos built in an AP bar, timed button presses, and secret Arts

Placeholder art throughout (capsules and boxes): this stage is about a fun core loop.

![The arenas](docs/arenas.png)

## What's in it

- **A 12-round boss rush** with auto-save, Round Select, and a party picker for the boss rounds (1 to 4 fighters, solo allowed)
- **A guided tutorial** that teaches every mechanic, step by step
- **Five classes**: Knight, Archer, Mage, Cleric and Assassin, each with its own attacks, skills, reactions and secret **Arts**
- **Enemies with readable skills**: cones, lines, donuts, half-room cleaves, falling rocks, instant-death gazes you hide from, and more
- **Play-test reports** written after every fight (press O on the end screen)

## How a fight works

Everyone slides along the **timeline** at the top; reaching the end is a turn.
Between turns you **steer** a party member in real time (Tab switches) while
enemies prepare skills, shown on the floor in grey, then revealed late.
Get out of the area before it lands, or **Parry** (E) / **Defend** (Q) the strike.

On your turn, **Attack** opens a combo bar: fill it with moves, then hit each
timing as the playhead passes (Press, Hold or Tap) for a **Perfect**. Moves in
the right order merge into **Arts**, secret until you find them mid-combo.
Perfects and Parries grow the party's max AP; mistakes reset it.

## How to play

**Download (Windows):** grab the latest `PrototypeJRPG-<version>-windows.zip`
from the [Releases](../../releases) page, unzip it and run the `.exe`. No
install needed. Windows may warn about an unknown app the first time: choose
*More info > Run anyway*.

**Download (Linux, x86_64):** grab `PrototypeJRPG-<version>-linux.tar.gz`
from the same page, then:

```
tar -xzf PrototypeJRPG-<version>-linux.tar.gz
chmod +x "Prototype JRPG.x86_64"   # only if it won't start
./"Prototype JRPG.x86_64"
```

The version is shown on the title screen; what changed in each one is in
[`docs/RELEASES.md`](docs/RELEASES.md).

**From source (any platform):** install **Godot 4.7** (standard, not .NET),
click **Import**, pick this folder's `project.godot`, and press **F5**.

**First steps:**

1. Start with **Tutorial** on the title screen. It teaches everything in about 15 minutes, and you can't lose.
2. Then play **Boss Rush**: 12 rounds that get harder, with auto-save (**Continue** picks up where you left off).
3. Stuck on a round? **Round Select** jumps to any of them.

**Feedback is very welcome!** After every fight the game writes a short
report; press **O** on the end screen to open the folder (on Windows,
`%APPDATA%\Godot\app_userdata\Prototype JRPG\playtests`). Attach a few to an
[issue](../../issues) along with what felt fun, confusing or unfair.

## Controls (defaults)

| Key | Action |
|---|---|
| WASD | Move (between turns) / choose in menus |
| Tab | Switch party member / open the Arts list in the combo bar |
| J / K (Enter / Backspace) | Confirm / back; J is also the timed-hit key |
| Space | Begin the combo |
| E / Q | Parry / Defend an enemy strike |
| Z / C, right-drag, wheel | Camera |
| Esc | Pause |

**Change Keys** on the title screen rebinds them.

## Learn more

- [`docs/battle-design.md`](docs/battle-design.md): every rule and number in detail
- [`docs/enemy-roster.md`](docs/enemy-roster.md): enemies and their skills
- [`docs/CHANGELOG.md`](docs/CHANGELOG.md): how the system evolved

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
- [x] Arts: secret named combos for every class, revealed mid-combo
- [x] Title screen and a guided tutorial
- [x] Pause menu, Boss Rush auto-save, rebindable keys, party picker for boss rounds
- [x] Roster building blocks: multi-hit attacks, marked targets, hazards, healing
- [x] Play-test reports after every fight (O on the end screen opens them)
- [ ] Stagger gauge and knockdown (push away, disable or reshape enemy areas)
- [ ] Complete fight: proper victory and defeat screens, balance pass
- [ ] Items (the menu entry is there, marked "coming later")
