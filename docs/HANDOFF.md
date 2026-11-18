# Handoff notes

Where the project stands, for picking it up in a new chat. Read this first,
then `CHANGELOG.md` (newest at the top) and `battle-design.md`.

## The project

- A Godot 4.7 JRPG prototype: a boss-rush of real-time-with-pause fights.
  PS1 look (vertex snapping, a retro screen filter), furry art style.
- Repo: <https://github.com/Wyrbun/prototype-jrpg>. Playable builds go to
  `D:\Prototype JRPG Playable Builds`; playtest logs to
  `%APPDATA%\Godot\app_userdata\Prototype JRPG\playtests`.
- Tests: `tests/_*.gd`, run headless one by one
  (`godot --path . --headless -s tests/_x.gd`), each prints `FAILS: n`
  (the tutorial run, `_tut.gd`, prints "Tutorial complete!" instead).
  `_aidodge` is timing-sensitive under CPU load; it passes on a rerun.
  Files named `_shot*`, `_gif*`, `_cam*` and `*sim` are recorders, not tests.

## Working preferences (Thiago)

- Thiago commits, pushes and publishes GitHub Releases himself, unless he
  asks Claude to.
- Design questions get asked, not assumed.
- Keep the files in the project folder.
- Pronouns: Knight they/them, Archer she, Mage she, Assassin he, Cleric
  she, Monk he.
- No 1:1 copies of other games' designs (Nintendo etc.): inspired-by only.
- PS1 aesthetic, smooth (not stepped) animation, muted colours that are
  easy on the eyes.

## The cast

- Party (shortest to tallest): Cleric (squirrel lady, crusader armour,
  robes and helmet), Knight (beige lop-eared rabbit), Mage (goat lady,
  purple hair), Assassin (grey wolf, scar, red eyes), Archer (tall brown
  bear lady, green clothes), Monk (tall snapping turtle).
- Enemies: Ratkin Fighter (rat), Kobold Archer (lizard), Ogre Warrior
  (boar), Desert Shaman (hyena), Bandit Arcanist (raccoon); monsters:
  golems, Living Armor, Dragon Hatchling, Gust and Shadow Sprites, the Gale
  Maw (an original ram spirit in a wall).

## Done recently (see CHANGELOG)

- Code-built low-poly figures for everyone (`figure.gd`,
  `enemy_figure.gd`), animated by `figure_anim.gd`; every party move, Art
  and Ability has its own keyed animation (`move_anims.gd`), with weapon
  trails, afterimages, hit-stop, anticipation timed to the combo bar.
- Knockdowns and physics ragdolls (`ragdoll.gd`); small enemies ragdoll
  when beaten.
- Sound and music (`sfx.gd`, `battle_sounds.gd`, `audio/`).
- Controller support, Xbox layout (`pad.gd`, `Keybinds.PAD_DEFAULTS`),
  pad prompts and pad rebinding; Change Keys also in the pause menu.
- The last enemy falls in slow motion with the camera on it (the finale).
- Every arena is a place (`arena_scenery.gd`, `Arena.setting`), with
  natural-looking rocks, pits and holes.

## Open / next

- **Sound and music:** in (see CHANGELOG). Still open (silent for now):
  music after a defeat, and for finishing the Boss Rush; Thiago wants 8-bit menu versions of tracks later (`Sfx.duck`
  already swaps to `<track>_8bit` if one exists). Unpicked candidates stay
  in `audio_picks/` for later.
- The Command List preview could show the real figures doing each move.
- Mage 2-element Arts could get their own combined effects (3- and
  4-element ones have them).
- Backlog: Dragon AI positioning; Living Armor may be too easy; Lifeline
  use in sims; Mage Arts' own gameplay effects; Arcane Barrier / Teleport
  rework; a narrower dodge for Archer / Assassin; Shadowflare spike damage.
- Next big area: design outside of combat (Thiago's next topic).
