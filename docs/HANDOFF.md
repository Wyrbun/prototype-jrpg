# Handoff notes

Where the project stands, for picking it up in a new chat. Read this first,
then the top of `CHANGELOG.md` (newest first), `battle-design.md` and
`prologue-design.md`.
Last updated: 18 Nov 2026, after Prologue Stage 3 (fights in the room).

## The project

- A Godot 4.7 JRPG prototype. So far it is a battle system: a boss rush of
  13 rounds plus a Special Match, a tutorial and Round Select. Fights are
  real time with pause, with timed hits, Parry / Defend and combos.
  PS1 look (vertex snapping, a retro screen filter), furry art style.
- **The Prologue** (New Game) is being built in stages: a short story demo
  with exploring, field enemies, fights in the room, menus, saving,
  cutscenes and a boss. Design and build order: `prologue-design.md`.
- **Version 1.0.0** is the current release (`project.godot`
  `config/version`, `export_presets.cfg`, the README and `RELEASES.md`).
  Versions follow MAJOR.MINOR.PATCH (see `RELEASES.md`).
- Thiago's PC: the project is at `C:\Users\thiag\Documents\prototype-jrpg`;
  builds go to `D:\Prototype JRPG Playable Builds`; play-test reports are
  written to `%APPDATA%\Godot\app_userdata\Prototype JRPG\playtests` after
  every fight.
- Repo: <https://github.com/Wyrbun/prototype-jrpg>. Release files are
  named `PrototypeJRPG-<version>-windows.zip` and `-linux.tar.gz`.

## Working preferences (Thiago)

- Thiago commits and pushes (GitHub Desktop) and publishes GitHub Releases
  himself. Give him the commit summary / description and the release text.
- Ask design and story questions in chat; don't assume.
- Keep all files inside the project folder. Ask before downloading
  anything (a Godot 4.7.2 in Claude's own workspace, for the tests, is OK).
- Pronouns: Knight they/them (always "they", even if Thiago says "him"
  or "he": it's a slip from Portuguese), Archer she, Mage she, Assassin he,
  Cleric she, Monk he. The Knight is **Wyr**, the Prologue's lead.
- No 1:1 copies of other games (Nintendo etc.): inspired-by only.
- Look: PS1-style low poly, furry characters, smooth (not stepped)
  animation, muted colours that are easy on the eyes.
- Every change gets a CHANGELOG entry, and tests where it can be tested.

## Tests

- `tests/_*.gd`, run headless one by one:
  `godot --path . --headless --audio-driver Dummy --fixed-fps 60 -s tests/_x.gd`.
  Each prints `FAILS: n` (the tutorial run, `_tut.gd`, prints "Tutorial
  complete!" instead). Run `godot --import` first after adding new classes
  or audio files.
- Files named `_shot*`, `_gif*`, `_cam*` (but `_camspeed` is a test),
  `*sim` are recorders, not tests. `_shot*` need a window (in Claude's
  workspace: `xvfb-run`, which falls back to OpenGL).
- Known flaky: `_aidodge` under CPU load (passes on a rerun); `_steer`
  times its hold with the real clock, so it can fail on a fast machine
  (not a game bug).

## The cast

- Party (shortest to tallest): Cleric (squirrel lady, crusader armour,
  robes and helmet), Knight (Wyr; beige lop-eared rabbit), Mage (goat
  lady, purple hair), Assassin (grey wolf, scar, red eyes), Archer (tall
  brown bear lady, green clothes), Monk (tall snapping turtle).
- Prologue only: two unnamed soldiers, a Mage (male, he) and a Cleric
  (female, she); on the field they use the party's Mage and Cleric figures
  as placeholders for now. Aurora (an AI). The Haywire Automaton (boss).
- Enemies: Ratkin Fighter (rat), Kobold Archer (lizard), Ogre Warrior
  (boar), Desert Shaman (hyena), Bandit Arcanist (raccoon); monsters:
  golems, Living Armor, Dragon Hatchling, Gust and Shadow Sprites, the Gale
  Maw (an original ram spirit in the cliff wall).

## Where things are

- Battle: `scripts/battle/battle_arena.gd` (the fight, party AI, camera,
  the finale), `combatant.gd`, `ragdoll.gd`, `arena_scenery.gd` (each
  arena's setting), `pause_menu.gd` (also the field's pause menu,
  `field_mode`), `end_screen.gd`, `tutorial.gd`.
- Field (Prologue): `scripts/field/` (`field_scene.gd` the field and room
  changes, the swing and fight starts, `field_walker.gd` leader and
  followers, `field_camera.gd`, `field_room.gd` how to build a room,
  `field_door.gd`, `field_enemy.gd` patrols, sight, chases,
  `field_state.gd` the Prologue's progress, `field_fight.gd` +
  `field_fight_director.gd` a fight on the field inside the battle scene
  (`BattleArena.field_fight`), `field_result_panel.gd` Victory / defeat,
  `field_rewards.gd`, `field_transition.gd`);
  `scenes/field/field.tscn`, rooms in `scenes/field/rooms/`.
- Figures and animation: `figure.gd`, `enemy_figure.gd`, `figure_anim.gd`,
  `move_anims.gd`.
- Sound: `scripts/sfx.gd` (`Sfx`: sounds, music, volume, the menu duck),
  `scripts/battle/battle_sounds.gd`; files in `audio/` (all CC0, credited
  in `audio/CREDITS.md`). Unused candidates are in `audio_picks/` (about
  88 MB, not meant for the repo; `PICKS.md` lists them).
- Input: `scripts/keybinds.gd` (keys and pad buttons, rebinding,
  device-aware hint text), `scripts/pad.gd` (controller, Xbox layout).
- Options: `scripts/settings.gd` (screen filter, Move details, Command
  timing, Party AI, master / music / sound volume, camera speed, mouse
  sensitivity, Invert camera X / Y / both).
- Title screen: `scripts/ui/title_menu.gd` (New Game and its page, the
  controller notice at start-up), `scripts/ui/title_backdrop.gd` (a random
  arena turning behind the menu).
- Data: `data/boss_rush.tres` (the rounds) and the other `data/` files.

## Done recently (see CHANGELOG)

- Prologue Stage 3: fights start where you meet the enemy (battle
  transition, the room as the arena, every enemy joins, ambush / normal /
  caught), escaping to a door, the Victory screen (experience, items),
  losing sends you to the entrance, HP / pouch carry over, beaten enemies
  stay gone until a save point. Flat floor only.
- Prologue Stage 2: field enemies (patrols / guards, sight cones and
  circles, moving at the leader's pace, chases that give up), the Sneak
  key, the field swing (ambush / normal / caught; a placeholder message
  until Stage 3).
- Prologue Stage 1: New Game on the title screen (with its "this is a
  story" page), the field: leader and followers, the room camera with a
  set angle per room, cutaway walls, doors between rooms, stairs, the
  field's pause menu. Two grey-box test rooms.
- v1.0.0: the PS1 look for everyone and every arena, an animation for
  every move, knockdowns and ragdolls, sound and music, full controller
  support, Change Keys in the pause menu, camera and volume options, the
  slow-motion finale on the last enemy, a living title screen, a gorge
  past the Gale Maw's drop.
- After 1.0.0 (not in the 1.0.0 builds): AI allies no longer run on the
  spot (Round 4's pit arena; test `_aijog.gd`). README: new animated
  WebPs, a new title image (`title-v1.png`) and a controller column in
  Controls.

## Open / next

- **Prologue next:** Stage 3b (height in fights) or Stage 4
  (interactables: chests, switches, NPCs, save points; set fights). See
  `prologue-design.md` for the order and the open questions (field music
  and the field battle theme, experience / levels, the field menu
  reference, the Automaton, the three sentries).
- Balance: Rounds 1-6 play easy (play-tests); waiting for Thiago's reports
  for Rounds 7-13 before a balance pass.
- From the play-test logs: "ai ledge steps" jitter in Round 5 (it also
  made the Mage lose Focus); the Round 4 report files counter damage
  under "Counter stance".
- Music is still silent after a defeat and after finishing the Boss Rush.
  Thiago wants 8-bit menu versions of tracks later (`Sfx.duck` already
  swaps to `<track>_8bit` if the file exists).
- A Windows build exported outside Godot on Thiago's PC lacks the exe's
  version details (no rcedit); exporting on his PC fixes it.
- Backlog: Command List previews showing the real figures; Mage 2-element
  Art effects; Dragon AI positioning; Living Armor may be too easy;
  Lifeline use in sims; Mage Arts' own gameplay effects; Arcane Barrier /
  Teleport rework; a narrower dodge for Archer / Assassin; Shadowflare
  spike damage.
