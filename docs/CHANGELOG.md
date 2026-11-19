# Development history

How the battle system evolved, including ideas that were tried and changed.
Newest first. Detailed current rules live in `battle-design.md`.
Player-facing notes per public build are in `RELEASES.md`.

## 1.0.1 additions: play-test requests and a crash option

From Thiago's and Coryn's play-tests (19 Nov). All in the 1.0.1 builds.

- **Mouse buttons as keys** (`keybinds.gd`, both Change Keys pages): the
  middle button and the two side buttons (Mouse 4 / Mouse 5) can be a
  key's main binding, saved like keys (codes from `Keybinds.MOUSE_BASE`
  up). Left click (menus) and right click (camera drag) can't be taken; a
  left / right click while waiting for a key still cancels.
- **Jump's reach** (`battle_arena.gd`, `_show_range_ring`): aiming Jump
  (and Teleport) draws a teal ring at the move's reach (8 m) around the
  fighter, gone when the aiming ends.
- **Energy spells: tap after the code** (`battle_menu.gd`,
  `battle_arena.gd`): before the code, the prompt reads "1) TYPE ...
  2) then TAP ..." and the code stretch shows the tap pips faintly
  ("CODE, THEN TAP"). Once the code is in: a "CODE IN! TAP J!" popup over
  the Mage, the stretch turns pink and pulses, the pips fill per tap, a
  big "< TAP J!" sits beside the bar, and the prompt counts the taps.
- **Single Target / Area icons** (`battle_menu.gd`, `Moves.hits_many`):
  attacks in the combo menu and known Arts in the Arts panel show a
  crosshair (one enemy) or an orange ring with three dots (an area of any
  shape, or Chain Lightning's chain).
- **Shout stuns into Sword Spin** (`_push_out`): everyone Shout pushes is
  stunned (can't walk; a turn that comes up waits) until the follow-up has
  really struck: the stun is held while the Ogre's Sword Spin is still
  pending (`stunned_by`), so a party turn stopping the clock can't let them
  walk out. `push_out_stun_extra` 0.25 s after it.
- **Golem Smash arms** (`figure_anim.gd`, `_smash_side`): the Right / Left
  Golem Smash wind-up raises the arm on that side (by
  `aim_offset_degrees`), and the blow comes down with that arm. It used to
  always raise the right arm.
- **Renderer option (Windows)** (`settings.gd`): Options > Renderer:
  Vulkan (default) or Direct3D 12, applied at the next start. Coryn's game
  closed without an error mid-fight (the log stops mid-line at 32 KB, in
  Round 11), the kind of crash a graphics driver causes; the project
  forced Direct3D 12 on Windows (`rendering_device/driver.windows`), which
  is removed: the base driver (Vulkan, falling back to D3D12 by itself)
  is used, and choosing Direct3D 12 writes `user://renderer.cfg`, which
  `application/config/project_settings_override` loads at start-up.
- Tests: `_mousekeys.gd`, `_v101fight.gd`.

## Version 1.0.1

- A patch release from the 1.0.0 code: the play-test requests above,
  Shield Bash's charge and AI allies running on the spot (below). The 1.0.1
  builds don't include the Prologue work above (New Game and the field):
  they were exported from 1.0.0 plus these two fixes. `RELEASES.md` has
  the player-facing notes; README points at 1.0.1.

## Shield Bash is a real charge

- Shield Bash used to teleport the Knight beside the enemy in one frame,
  while its animation lunged their body about 4 m further, through the
  enemy, and slid it back. Now (`battle_arena.gd`, `_shield_bash_charge`):
  a 0.12 s wind-up on the spot (crouched behind the shield), then they run
  the gap in 0.22 s, speeding up, with a swing sound and a dust trail, and
  the shield slams in on arrival (a blunt hit sound). Where they end up is
  unchanged (beside the enemy, kept inside the arena), and so is the
  sooner next turn.
- `move_anims.gd`: a new Shield Bash animation keyed to that charge (no
  "dash" key: the Knight really moves now). `figure_anim.gd`: a move
  marked `"charge"` doesn't play the walk cycle on top of its own legs.
- Test: `_shieldbash.gd` (no teleport, the wind-up on the spot, a run over
  many frames, the body stays with the Knight, ends beside the enemy).

## Prologue, Stage 3: fights in the room

- **Engaging an enemy on the field starts the fight right there**: a short
  battle transition (a flash, then black bands slide across: an original
  take on the old-school kind, time for the music to change), then the
  battle in field mode (`BattleArena.field_fight`, run by
  `FieldFightDirector`). The arena is the room's `battle_area` (flat
  floor only for now), the room itself shows round the fight (walls cut
  away as on the field), and pillars and crates (the "obstacle" group)
  are round obstacles. **Every enemy in the room joins**, and everyone
  starts where they stood. The camera starts from the field's angle.
- How it started:
  - **Ambush** (a swing from behind, unseen): the party starts with 50 AP.
  - **Normal**: 0 AP (field fights always start from 0).
  - **Caught**: 0 AP, the whole party knocked down, the enemies ahead on
    the timeline (55-70), and no AP recharge until everyone is up.
- **Escaping**: steer towards a door (within 35 degrees) for 2 s; a bar
  shows it filling. The room resets (enemies back where they started,
  calm for 2 s) with the party just inside that door. Set fights will be
  able to forbid it (`FieldFight.can_escape`).
- **After a win**: the Victory panel (experience earned, items found;
  enemies don't drop Credits), Confirm to go back to exploring. HP and
  the item pouch carry over (downed members come round with 1 HP); the
  found items go into the pouch. Experience adds up (no levels yet).
  Placeholder numbers: `scripts/field/field_rewards.gd`.
- **Beaten enemies stay gone** (leaving and coming back too) until a save
  point (`FieldState.rest`, used by save points in Stage 4).
- **Losing**: the defeat panel, then the party wakes up healed at the last
  save point, or the dungeon's entrance before one. Everything beaten
  stays beaten. (Boss retries come with the boss.)
- `FieldState`: the Prologue's party, HP, pouch, experience, beaten
  enemies and respawn point, shared by the field and the battle.
- In field fights the soldiers fight on their own and can't be switched to
  yet (`FieldState.steer_unlocked`), the Tab hint is hidden, the pause menu
  has no Restart, and the Boss Rush's end hints and round keys are off.
- Music: field fights play `audio/music/field_battle` once it exists (its
  own theme, to be picked); the battle theme until then.
- Test rooms: fight areas set, the hall's pillars and crate are obstacles,
  the Living Armor guards the steps room's floor (not the platform), the
  doors name themselves for escaping ("through the north door").
- Tests: `_fieldfight.gd` (`_field.gd` and `_fieldenemy.gd` now keep fights
  off: `FieldScene.fights_on`). Screenshots: `_shotfieldfight.gd`.

## Prologue design: the first rooms

- `prologue-design.md`: the dungeon room by room, from the Outskirts
  through the mine (Entrance, Lobby, Mines West, the Secret Path) to the
  Ruins Lobby (first draft).

## Prologue, Stage 2: field enemies

- **Enemies on the field** (`FieldEnemy`, `scripts/field/field_enemy.gd`):
  placed in a room under "Enemies", each with its fight figure (no names
  or attack areas shown out here). Each is set up on its own:
  - Patrolling: a "Patrol" child with Marker3D points, walked round and
    round or there and back, pausing at each. Or standing guard, turning
    between look angles.
  - Sight, drawn on the floor: a cone (7 m, 70 degrees; walls cut it
    short and block it), plus a 2.5 m all-round radius that only hears
    running. Or a full circle (the Living Armor in the test steps) that
    only notices running inside it, never walking or sneaking.
  - **They move at your pace while unaware:** standing still freezes them;
    sneaking (or a half-pushed stick) slows them to match.
  - Seen: a "!" and a short start, the sight turns red, then a chase in
    real time (4 m/s: faster than a patrol, a little slower than you).
    Out of its sight (or 1.4x its range) for 2.5 s, it gives up and walks
    back to where it started, at your pace, still watching.
- **Sneak** (new action: Shift, the left trigger; in Change Keys and the
  Controls page): half speed, and quiet.
- **The field swing** (Confirm): Wyr swings the sword. Hitting an enemy
  from behind before it has noticed the party is an **ambush** (the party
  will start with 50 AP); any other hit starts a **normal** fight; being
  touched is getting **caught** (knocked down, enemies ahead). Until
  fights in the room exist (Stage 3) a message says which start it would
  be and the enemy leaves the room; entering the room again brings it
  back. `FieldScene.engage()` / `engaged` is where Stage 3 hooks in;
  `FieldRoom.reset_enemies()` puts everyone back (for escaping).
- Test rooms: a Ratkin patrols past the hall's north door and a Kobold
  Archer stands guard in its corner; a Bandit Arcanist walks a loop in
  the test steps and a Living Armor guards the platform (full circle).
- Tests: `_fieldenemy.gd`. Screenshots: `_shotfieldenemy.gd`.

## Prologue, Stage 1: exploring (the field)

- **New Game** on the title screen (above Boss Rush) starts the Prologue.
  It opens a page first: the Prologue is a short story set piece, and Boss
  Rush and Round Select are the places to test the combat system (Start
  the Prologue / Back). Boss Rush, Tutorial and Round Select are unchanged.
- **The field** (`scenes/field/field.tscn`, `scripts/field/`): the party
  walks through rooms (loading areas), one loaded at a time.
  - `FieldWalker`: Wyr (the Knight) leads, steered with the move keys or
    the left stick, relative to the camera (4.5 m/s, smooth starts and
    stops, turns to face the way it walks). The two soldiers follow along
    the leader's trail, 1.4 m apart, catching up when they fall behind
    (placeholders: the party's Mage and Cleric figures). Same figures and
    walk cycle as in a fight, without the floating names and reach rings.
    Walls and ledges stop the party; the party doesn't bump into itself.
    Anyone who falls out of a room is put back by the leader.
  - `FieldCamera`: free, with the fight's controls and Options (camera
    keys, right stick, right-drag, wheel, Camera speed, Mouse sensitivity,
    Invert), but every room has its own set angle (camera_yaw / pitch /
    distance): entering a room snaps back to it, and the reset key returns
    to it.
  - `FieldRoom`: rooms are built in the editor from CSG shapes with
    collision; plain coloured materials become the PS1 material at
    start-up. Walls in the "wall" group are cut away while they're on the
    camera's side (they still block the way). Stairs: steps without
    collision under an invisible ramp ("ramp" group). Entries are
    Marker3Ds under "Entries". The room's name shows at the top left on
    entering.
  - `FieldDoor`: walking the leader into one fades out, loads the target
    room, puts the party at the named entry (followers lined up behind) and
    fades in. Doors only work once the leader has stepped clear of them,
    so arriving never bounces you straight back.
  - Two grey-box test rooms: Test Hall (pillars, a crate) and Test Steps (a
    raised platform up a flight of stairs), joined by a door.
  - Esc: the pause menu in a field version (Resume, Options, Change Keys,
    Quit to title) until the field menu is built. The PS1 screen filter
    and the Options apply as in a fight. No field music yet.
- `docs/prologue-design.md`: the Prologue's design (the world, the story,
  exploring, field enemies and how fights start, fights in the room,
  saving, cutscenes, the build order), with Thiago's answers.
- Tests: `_field.gd`, `_newgame.gd`. Screenshots: `_shotfield.gd`.

## AI allies no longer run on the spot

- Play-test (Round 4, the pit arena): the AI Cleric ran on the spot by the
  pit, escaping an area. Three causes, all fixed in `battle_arena.gd`:
  - Boxed in (the pit, the arena's rim or a fighter on every short way
    out), the escape kept stepping "away" into the pit's edge. It now
    takes the open direction that heads out the most, or stands still.
  - With two ways out about as short (either side of a line), it picked
    one, then the other from its new spot. The way it was already
    escaping now counts for 0.9 m (ESCAPE_KEEP_GOING).
  - Walking in for a Windup turn: once in reach, the range-keeping backed
    it out of reach and the Windup walked it back in. In reach, it now
    holds (out of danger first). Walking steps also keep 0.25 m further
    from danger than the escape line (SAFE_STEP_SLACK), so a growing area
    doesn't make it step out and back in.
- In 3 full-AI Round 4 fights: 326 / 111 frames jogging on the spot
  (Knight / Cleric) before, 16 / 9 after. New play-test count: "ai escape
  boxed". Test: `_aijog.gd`.
- README: new GIFs of the PS1 look (animated WebP, about half the size of
  the old GIFs), and the Controls table has a controller column.

## Version 1.0.0

- Project Settings, the Windows preset and the README say 1.0.0 (the
  README's download links too). The README describes the new look, sound
  and music, controller support and Options, and points Party AI and
  Command timing at Options. `RELEASES.md` has the 1.0.0 notes, and its
  version rule now reads MAJOR.MINOR.PATCH.

## AI Mage: no Enchant that leaves her nothing to cast

- Play-test (Round 5, steering the Knight): the AI Mage spent two turns on
  Enchant (30 AP) and Waited the other two, dealing no damage of her own;
  the Knight's spending left too little in the shared AP for a spell at
  her act. She now Enchants only if what's left after it, less what's kept
  for you, still covers her cheapest spell (20 AP); otherwise she casts.
- New play-test counts: "ai no ap" (an AI ally would have attacked but the
  party's AP was spent), per class. Test: `_aimageap.gd`.

## A controller notice at start-up

- Once per launch, before the title menu: "Controller support: this game
  also has controller support" over the screen, with a small gamepad
  drawing. It fades after 4 seconds, or at any key, button or click (which
  does nothing else). `title_menu.gd` NOTICE_SECONDS.

## Camera options

- Options (title and Esc): Camera speed (the right stick and the camera
  keys) and Mouse sensitivity (right-drag), each 50% to 200% (100% by
  default), and Invert camera: Off, X (left / right), Y (up / down) or
  both, for the stick, keys and mouse alike. The right stick also tilts
  the camera. Saved under `[camera]` in settings.cfg. Test: `_camspeed.gd`.
- Master volume (Options, above Music and Sounds): scales both.

## Controller support (Xbox layout)

- Every action has pad buttons (added at start-up, `Keybinds.PAD_DEFAULTS`):
  left stick / D-pad move and choose, A confirm and timed hits, B back,
  X begin the combo, Y switch party member (hold: choose), RB Parry,
  LB Defend, right stick turns and tilts the camera (tilt: up looks up,
  as with the mouse; camera_tilt_degrees_per_second), a right-stick click resets it, Menu
  pauses, View retries after a fight. The Mage's spell codes: D-pad or
  left-stick flicks.
- `Pad` (scripts/pad.gd), one node under the root: notes whether the pad
  or the keyboard was used last (`Pad.active`) and keeps raw stick motion
  away from the menus: each push of the left stick past 0.6 (let back
  under 0.35) is one press, so menus step once per push while the stick
  still walks and turns the camera smoothly.
- Hints switch to pad buttons while the pad is in use (`Keybinds.label` /
  `fill`; "Esc" reads "Menu", Enter/Backspace/right-drag mentions drop).
- Change Keys (title and pause) shows each action's pad button beside its
  key; pressing a pad button on a row rebinds it (swapping with whoever
  had it), Menu keeps the old one, Reset restores the pad too. Saved with
  the keys (`[pad]` in keybinds.cfg). Test: `_pad.gd`.

## Change Keys in the pause menu

- Esc > Change Keys: the same rebinding as on the title screen (a row
  waits for a key, Esc keeps the old one, Reset puts every key back), so
  keys can be changed mid-fight. Test: `_pausekeys.gd`.

## The last enemy's fall, and a victory theme

- When the last enemy of a fight goes down: the camera locks on it and
  comes in a little, the game slows to about a third for 2 seconds while it
  falls (a regular enemy is thrown, a boss now crumples as a ragdoll too),
  the camera stays on the body until it lies still (1.2 s at most), pans
  back to the party, then the Victory panel shows. Exports on the battle
  scene: victory_slowmo_scale / _seconds, finale_zoom,
  finale_settle_seconds, finale_pause. Skipped when the game runs faster
  (sims).
- After a win, a second after the victory jingle, the victory theme plays
  (Town3 - Sunshine Coast) until you leave the results (victory_theme_gap).


- Past the Gale Maw arena's drop there's now a gorge: a jagged rock face
  going down from the floor's edge into the dark, another rising on the
  far side, where the land carries on (`"chasm"` in the cliff's scenery,
  `ArenaScenery._chasm()`). The walls and the gorge's floor ignore the fog
  so the depths stay dark, and a few wisps of mist hang down in it. It
  follows the edge when it crumbles at half HP.

## A living title screen

- The title screen shows one of the arenas, empty, the camera slowly
  circling it (about two and a half minutes a lap) through the screen
  filter, under a dim veil so the menu reads (`TitleBackdrop`,
  `title_menu.gd` BACKDROP_VEIL). Which arena is picked at random once per
  launch.

## Sound and music

- All CC0 (public domain): Kenney's Impact, Interface, RPG Audio and Music
  Jingles packs, rubberduck's 80 CC0 RPG SFX, artisticdude's RPG Sound
  Pack, Juhani Junkala's JRPG music, cynicmusic and Wolfgang_. Thiago picked
  every sound from a listening folder (`audio_picks/`, ignored by Godot);
  only the picks are in `audio/sfx` and `audio/music`, each file's source
  in `audio/CREDITS.md`.
- `Sfx` (scripts/sfx.gd): `Sfx.play("name")` picks one of `name_1`,
  `name_2`... at random with a slight pitch wobble; the same sound isn't
  started twice within 45 ms. `Sfx.music("track")` loops and crossfades.
  It keeps playing while the game is paused. `BattleSounds` decides which
  sound goes with what in a fight.
- Fights: swings just before a melee hit lands (the Knight and Assassin
  sometimes draw the blade instead), sword/dagger, blunt and heavy (Smash)
  hits, the bow, the Mage's spells per element (Fire whooshes on the cast,
  burns on landing), fire on burning enemy skills, a chime on every timing
  hit, a bigger one when a whole bar is played with no misses, Parry
  clangs (two notes taking turns along a multi-hit chain, a Perfect Parry
  for the last of a fully parried chain, a dull clunk for a Parry too
  early), knockdown landings (light, or heavier when thrown far: the
  ragdoll's torso hitting the floor), enemies hurt (normal enemies), dying
  (their own cries for the Ogre, Dragon Hatchling, Stone Golem, Gale Maw)
  and landing and vanishing, healing spells and the HP number popping up,
  items, Revive, Teleport, Focus switching on.
- A guard's clank when an enemy's Defense blocks (or softens) a hit, and a
  blade drawn when an enemy readies a Counter.
- A whiff when the very first timing of an attack is missed (the attack
  misses entirely).
- Menus: cursor, confirm (half volume), back; taking a move off the timeline has its own.
- Music: the battle theme; the boss theme; the Living Armor and the Gale
  Maw have their own when they're the only boss; title and Round Select
  themes; the tutorial's own theme; victory and defeat jingles on the
  results screen (a victory theme after a win, quiet after a loss). The pause menu lowers the music, and a track's menu
  version (`<track>_8bit`, none yet) would play instead, at the same point.
- Options: Music and Sounds volume (100/80/60/40/20/Off), both 20% by
  default. Test: `_sfx.gd`.

## AI allies near drops

- Play-test (Round 5, Sky Ruins): AI allies backed off the holes 306 times
  in under two minutes: a jittery shuffle on the safety line. Now an ally
  backing off goes 0.6 m past the line before it stops
  (`ledge_hysteresis`), and an ally walking in to attack, with no push
  coming, may go right up to a drop (`ally_ledge_close`, 0.4 m: walking
  steers round holes anyway) instead of walking in and backing off over and
  over when its target stands by one. Sim: `tests/_ledgesim.gd`.

## Options: the screen filter, and a home for the settings

- An Options page, on the title screen (new "Options" row) and in the pause
  menu (Esc > Options): the same rows in both, saved in
  `user://settings.cfg` (`Settings.option_rows()` / `change_option()`).
- Screen filter: Normal (the PS1 look as it was: 360 lines, 48 colour
  levels, dither, full vertex wobble), Light (540 lines, smooth pixels, 96
  levels, light dither, a gentle wobble) or Off (no filter, no wobble).
  It applies at once, mid-fight too.
- The pause menu is shorter: Resume, Command List, Options, Restart fight,
  Quit to title. Move details, Command timing and Party AI moved to
  Options. The panel is wider, so the notes fit. Test: `_options.gd`.
- Ground textures: the mortar and grout lines are softer and the ground
  uses anisotropic mipmaps, so lines far away and at low angles don't
  flicker (the Town Plaza's cobbles were the worst).

## Arenas: a place for every fight

- Every arena is a place now (`Arena.setting`, built by
  `scripts/battle/arena_scenery.gd`): Town Plaza (rounds 1, 6, 7), Forest
  Clearing (2), Mountain Pass (3), Crystal Cave (4), Sky Ruins (5), Grand
  Colosseum (8-10, 13, Special), Windswept Cliff (11), Red Canyon (12),
  Training Yard (tutorial). Each has a textured floor (chunky 64-pixel
  textures made in code, no image files), the ground running out to the
  horizon (none past a drop: the land far below and clouds instead), props
  past the edges (houses, stalls, trees, crags, crystals and torches,
  pillars and arches, mesas and cacti, fences and dummies), mountains on
  the horizon, its own sky, fog and light. Short props sit near the edges,
  tall ones further out; tall ones hide when the camera gets up close.
  Looks only: nothing out there can be reached or blocks sight.
- Muted: every colour out there goes 30% toward grey and 18% darker (the
  sky 15% more), and the sun and ambient light are at 85%
  (`ArenaScenery.MUTE_GREY`, `MUTE_DIM`, `MUTE_LIGHT`), so it's easy on the
  eyes and the fighters and effects stand out against it.
- The colosseum's stands are full: a furry crowd (one multimesh, cheap)
  that bobs, and jumps when someone earns a Crowd Cheer.
- Rocks, pits and holes look natural: rocks are lumpy faceted boulders
  (their shape comes from where they stand) with smaller stones at their
  feet; pits are dark hollows with a broken stone rim; holes are black
  drops glowing deep red far down, embers rising, bones on the rim (no
  more skull rings). Lethal edges: a broken stone lip and a thin, dimmer
  red glow (no more drifting skulls). All recoloured to fit the place.

## Move animations, knockdowns

- Every party move and Art has its own animation (`scripts/battle/move_anims.gd`):
  a keyed sequence per hit, timed to its block on the combo bar (the
  build-up fills the block, the follow-through is squeezed into what's
  left). All six classes, with their Abilities.
    - Knight: Thrust is a straight forward stab; Smash drives the sword in
      deep, kicks off the enemy to pull it free and stumbles from the recoil.
    - Weapons turn on a wrist joint (WeapR / WeapL) so blades and staffs
      point where the move needs.
- Anticipation: the next move's coil starts as its block comes up on the
  bar and holds until it's played. Hit-stop: a Perfect freezes the action
  for a moment. Weapon trails (`scripts/battle/weapon_trail.gd`) and
  afterimages on dashing moves.
- A melee attacker with hits still queued follows a target that was pushed
  away, so the rest of the combo connects (it stops at a drop). The timing
  rings follow the target too.
- Tap moves grow a charge orb as you tap, up to the Perfect count, and
  their hit effect grows with it (up to 1.8x).
- Cleric: her staff turns at the wrist too. Bash is an overhead bonk, Holy
  Light a prayer and then a beam from the staff's sun disc, Divine Barrier
  the staff planted and a dome; Smite a hop into a crushing blow with a
  cross of light, Judgment a pillar of light from the sky onto the circle,
  Blessed Strike an upswing ringed in green, Sanctuary a kneeling prayer
  and a big dome, Divine Judgment a forehand, a backhand and a leaping slam
  that calls the pillar. Abilities: Healing (a green beam to the ally),
  Shielding (a dome), Haste (the staff twirled, teal rings rising round the
  ally), Full Cure (kneeling, then a pillar of light), Lifeline (a sprint
  and a streak of light along the dash).
- Assassin: each dagger turns at the wrist, with its own trail. Stab a
  quick thrust, Backstab a point-down plunge (red), Shadowstep and its Arts
  sink into a crouch and come out behind the target in a puff of shadow
  smoke (where he leaves and where he lands), Execute a leap and both
  daggers plunged in with a red X. Arts: Twin Fangs (right, then left),
  Ambush (a slash, then a kick that sends it flying), Phantom Rush (a slash,
  then a full spin), Cutthroat (a low stab, then a cut across the throat),
  Thousand Cuts (alternating cuts with afterimages, then a crossed slash
  down through it). Abilities: Hook (a chain thrown and yanked), Death
  Sentence (three Marks flare over the target), Shadow Cloak (arms
  wrapped, then thrown open; violet rings), Vanish (a step back into the
  smoke).
- Monk: fists, feet, head and shell, his guard up between blows; orange
  shockwaves, bigger the heavier the blow. Punch (jab, cross, jab), Kick (a
  front kick, a roundhouse), Heavy Punch (drawn back to the hip, driven
  through), Heavy Kick (an axe kick), Headbutt (stars round its head).
  Arts: Palm Strike (both palms), Flash Kick (a backflip kick), Knee Smash
  (grabbed and pulled onto a knee), Triple Rush (jab, cross, a flying
  kick), Mountain Crusher (a punch, two kicks, then a leap and both fists
  into the ground: rock and dust all round), Tortoise Special (a heavy
  punch, an axe kick, then a punch for every tap for as long as you keep
  tapping, arms taking turns, a small shockwave on each; then the right
  fist drawn slowly back while the left keeps going, a last big punch, a
  gold burst, and he rolls back in his shell). Abilities:
  Provoke (a beckoning hand; a red flare over the enemy), Suplex (a low
  wrestler's stance), Deep Breath (arms raised and lowered; rings rise).
- Enchant: light motes on each party member's weapon for as long as it lasts.
- The Mage's biggest Arts mix their elements into one effect, with an
  earlier lead-up: Meteor (lightning strikes, then a frost-crusted rock
  falls from the sky trailing fire), Tri-Disaster, Thermal Shock, Nova,
  Stasis (a cage of rings).
- Knockdowns: a living party member hit by a crushing blow (a Smash or 40+
  damage) or pushed 2.5 m or more is knocked down for 1.4 s
  (`knockdown_seconds`), then sits up and gets up. Pushed, it flies to
  where the push put it in an arc (higher the further it goes) instead of
  sliding there, and lies down for the full time after landing. It can't walk meanwhile, but its timeline runs on: a turn that comes
  up waits until it's up, and an attack it was winding up gets 1.5 s
  (`knockdown_grace`) extra grace to walk back in. A wall boss's breath
  (Inhale, Exhale) never knocks down. A Parry avoids both the blow and the
  throw, and a Defend keeps you on your feet (the push is still braced to
  half), so knockdowns punish a mistimed or missing reaction and bad
  positioning.
- Physics ragdolls (`scripts/battle/ragdoll.gd`): knocked down or knocked
  out, a figure's torso, head, arms and legs become rigid bodies joined at
  the neck, shoulders and hips (cone-twist joints, Jolt), thrown by the
  blow. They flail, tumble and land in a heap; ragdolls bump into each
  other. Visual only: the fight goes by the fighter's own position (a
  knocked-out member's follows its torso, for Revive). Knocked down, the
  body flies to where the push put it and, for the last 0.4 s
  (`knockdown_rise`), eases back onto its feet. Replaces the scripted
  tumble.
- Small enemies (not bosses) ragdoll when beaten: thrown away from the
  blow that beat them, harder for pushes and finishers (a burn or a stray
  hit just crumples them); after 3 s they sink through the floor. Bosses
  keep the old fade. Test: `_enemyrag.gd`. Tests: `_knockdown.gd`, `_knocklaunch.gd`, `_maw.gd`.

## PS1 look: furry figures for party and enemies, animations, a retro screen

- The look aims at a PS1 game with a furry cast. Party members are
  low-poly animal figures instead of capsules (`scripts/battle/figure.gd`),
  built from boxes, 4-8 sided cylinders, spheres and ovals under the Body
  node, so lunges, the knocked-out pose and ragdolls move the whole
  figure. The Body is the torso and keeps its class-colour material (the
  HUD reads it); the Nose is hidden, since faces and weapons show where a
  fighter looks.
    - Knight: a rabbit, beige fur, lop ears out from under an open-faced
      helm with a plume, tabard, kite shield with a gold cross, sword, a
      cotton tail.
    - Archer: a tall brown bear, tan muzzle, round ears, hood down, short
      cape, quiver, long bow.
    - Mage: a goat, cream fur, horns swept back under a pointed hat, long
      purple hair, robe, staff with an orb.
    - Cleric: a red squirrel, nasal helm with her ear tufts through it,
      mail and a white surcoat with a gold cross over her robe, staff with
      a sun disc, a big curled tail.
    - Assassin: a grey wolf, red eyes, a scar over his left eye, ears up
      through the hood, a dagger in each hand, a bushy tail.
    - Monk: a snapping turtle, hooked beak, a ridged shell over his gi,
      sash, wrapped fists, headband, prayer beads, a spiky tail.
- Heights (`Figure.HEIGHTS`), shortest to tallest: Cleric, Knight, Mage,
  Assassin, Archer, Monk. The whole figure scales with its feet on the
  floor and the name label moves up with it; reach and body size in the
  fight are unchanged.
- Animations (`scripts/battle/figure_anim.gd`), smooth, all in code: the
  figures have joints (Head, ArmL, ArmR, LegL, LegR, Tail; `Figure._rig`
  sorts the parts onto them, tails are wrapped by hand). Always on:
  breathing, a head that looks around, tail and ear sway, and a walk cycle
  that follows how fast the fighter really moves (steered, AI or pushed).
  On top, one action at a time:
    - attack, on every hit (`play_lunge(move)`): the Knight slashes, the
      Archer draws and looses, the Mage thrusts her staff, the Cleric
      swings hers, the Assassin stabs with one hand then the other, the
      Monk punches left and right, kicks on Kick and Knee moves and
      headbutts on Headbutt;
    - a hit flinch, or a stagger back on a heavy one (20% of max HP, or a
      strong blow), from `_hurt`;
    - Defend (the Knight's shield up, the others' arms crossed) and Parry;
    - casting an Ability, using an item, and a victory pose (held) when
      the end screen shows after a win.
  Combatant.animate(action) starts one; enemies (no figure) ignore it and
  keep the old body jab.

- Enemy figures (`scripts/battle/enemy_figure.gd`), picked by scene file.
  Animal folk: the Goblin Fighter is a rat (ragged tunic, rusty sword,
  round shield, pink tail), the Kobold Archer a lizard (harness, short
  bow, quiver, long tail), the Ogre Warrior a huge boar (tusks, bristly
  mane, hide armour, spiked club), the Orc Shaman a spotted hyena (teal
  robe, bone necklace, skull staff), the Bandit Arcanist a raccoon (mask,
  purple cloak, glowing tome and wand, ringed tail). Monsters: the
  Training Golem a banded wooden barrel with a target and a bucket head,
  the Stone Golem a rock giant (glowing eyes, huge fists, moss, crystals),
  the Living Armor an empty suit of dark plate (purple eyes, spiked
  pauldrons, tattered cape, greatsword), the Dragon Hatchling a four-legged
  baby dragon (horns, wings, spiked tail), the Gale Maw a colossal
  wind-spirit ram (a long muzzle where Deep Breath's black mouth opens,
  curling horns, glowing eyes, a cloud mane) with two great clawed paws
  hovering either side: they drift while idle, rise in its wind-up and
  come down when a skill lands, the Gust Sprite a cloud puff with a face, the
  Shadow Sprite a dark flame with glowing eyes. The Nose is hidden (meta
  "figure"; the open-mouth code leaves it alone).
- Enemy animations: the same animator with a style per figure (biped,
  quad, float, wall). Enemies ease into a wind-up while they prepare a
  skill (a guard for Defense and Counter stances), strike when it lands
  (`_resolve_strike`), and flinch when hit (any damage taken, party too).
  The dragon walks on four legs and flaps its wings; sprites bob and dart.
- The Gale Maw's paws fling its Gust Sprites: the paw on that side winds
  up and throws, and the sprite tumbles in an arc from the paw to where
  it already stands (`FigureAnim.fly_in`, looks only: it's in place for
  the fight at once). The message says it "flings" them.
- The Goblin Fighter is now the **Ratkin Fighter** (it's a rat); the
  tutorial and the Round 6 tip say Ratkin, and "the side away from its
  nose" is now "its face" (enemies' noses are hidden by their figures).
  The scene file keeps its name (`goblin_fighter.tscn`).
- The Orc Shaman is now the **Desert Shaman** (a hyena); scene file
  `orc_shaman.tscn` as before.
- End screen: a long round title (two enemies with long names) shrinks to
  fit beside the rank box, and is cut with "…" past 13 pt.

- `shaders/ps1.gdshader` (the figures' material): vertices snap to a
  320-line screen grid (the wobble; the PS1 drew at 240), lighting per vertex, affine texture
  mapping without filtering (ready for textures).
- `shaders/ps1_screen.gdshader`: the 3D view at 360 lines, 48 levels per
  colour channel, a 4x4 ordered dither at 60% (first tried at 270 lines,
  the PS1's 15-bit colour and a full dither: too coarse), on a layer under the HUD. Floating text
  (names, damage numbers, skill names) stays sharp: every Label3D goes on
  render layer 20, which the view's cameras skip and a second camera
  (same world, same view) draws over the low-res picture.
- Screenshots: `tests/_shotlook.gd`, `tests/_shotfigures.gd`,
  `tests/_shotportraits.gd` (each figure close up, front and back),
  `tests/_shotanim.gd` (frames of every animation, all six classes),
  `tests/_shotenemies.gd` (every enemy close up, front and back).

## Version 0.9.0

- Project Settings, the Windows preset and the README links say 0.9.0;
  the roadmap's last item (Complete fight) is ticked. `RELEASES.md` has
  the notes.

## Rank tuned from a full Boss Rush; AI backs off a Counter stance

- A Boss Rush, Rounds 1-11, all won: the party took more than its whole
  max HP in three of four boss fights (heals keep it going), so Health
  scored 0 however well it went, and Reading counted the AI allies'
  avoidable hits (10 in Round 11). Health now uses the HP still missing
  at the end (minus 10 per member who went down); Reading counts only
  hits on the fighter you steer (`avoidable_hits_you`), early Parries and
  missed timings. Estimated ranks of that run: A / B / B / C.
- Par times trimmed (every boss was beaten 55-92 s under par): Golem
  2:30, Living Armor 3:00, Dragon 3:15, Gale Maw 3:15.
- Windup: an AI ally whose target raised a Counter stance after it chose
  now backs off (a Wait) instead of attacking into it (the Mage took 38
  from the Living Armor's). Test `tests/_aicounter.gd`.
- `ai_ledge_steps` counts each time an ally backs away from a drop, not
  every frame of it (750 and 1,326 in the logs).
- Tutorial: the Assassin lessons no longer error if a turn is still in
  progress when they start (the Assassin joins after it).

## Fix: end-panel choices froze the game

- Next round (and Retry, Change party, Back to the menu) on the new end
  panel stopped on "Cannot call method 'set_input_as_handled' on a null
  value": the choice loaded the next scene while the key press was still
  being handled, and the old battle was no longer in the tree to mark it
  as used. The key is now marked first (`EndScreen.wants`), and the
  choice runs after the press (deferred signal). Test `tests/_endnext.gd`.

## Ragdolls for downed allies

- A downed party member goes limp instead of the old stiff tip-over (the
  nose used to float in the air). Strong blows (pushes, Smashes, 40+
  damage, instant kills) send the body flying away from the enemy: a
  tumbling arc about 1.4 m high and 6 m long, a bounce, a slide, then
  flat on its back. Anything else makes it flop over where it stands.
  Bodies never fly over an edge. Revive stands them back up.
- `Combatant.make_limp` / `unlimp`, `BattleArena._start_ragdoll` /
  `_tick_ragdolls`, exports `ragdoll_fly_speed`, `ragdoll_fly_up`. Test
  `tests/_ragdoll.gd` (FRAMES / SHOTS for pictures).

## Victory and Defeat screens

- Design: the Victory and Defeat Screens doc, settled in chat.
- A panel over the frozen battle 1.2 s after the last blow, the camera
  turning slowly behind it (`scripts/battle/end_screen.gd`). The old
  placeholder text and key line are gone; the old keys still work.
- **Victory:** banner, round and enemies, time, turns, and an S / A / B / C
  rank (Health, Timing, Reading, Pace, 25 points each; S 85, A 70, B 50)
  with the best rank per round saved. A Fight summary page shows where
  the rank came from, the party and the fight's totals.
- **Defeat:** banner and the enemies' HP left, Retry first. A What went
  wrong page: enemy HP bars, the 3 sources that hurt most (AVOIDABLE
  tagged), who went down to what, and a tip.
- New: `Encounter.par_seconds` (rounds 8-11 set), `EnemySkill.tip` (set
  on the bosses' trickier skills, worked out from the rules otherwise),
  `Settings.best_rank` / `record_rank`, the report keeps the last hit
  before each down, counts `timed_hits`, `timing_misses`, `arts_found`,
  `max_ap_peak`. Choices include Change party and Back to the menu.
- Tests `tests/_endscreen.gd`; screenshots `tests/_shotend.gd`.

## AI allies don't push a casting enemy's area onto the party

- A Round 8 log: an AI ally's push moved the Golem mid Right + Left Golem
  Smash, and the second half landed on the side everyone had crossed to
  (224 damage, all four hit). AI hits no longer push an enemy preparing a
  strike whose area moves with it (`_carries_area`: not placed on the
  party, not arena-aligned); Gust Sprites (Lightweight) still get pushed.
  Your own pushes still work, so it stays a trick you can use. Counts
  `ai_pushes_held`. Test `tests/_aipush.gd`.
- `tests/_tut.gd` walks round an enemy only in the rock and Assassin
  lessons (the detour put the Knight into the Golem's area in the dodge
  lesson).

## Items: Potion, Ether, Revive

- Design: the Items Design doc (pouch, numbers, AI rules), settled in chat.
- **A pouch per fight:** 3 Potions, 2 Ethers, 1 Revive (`pouch_potions`,
  `pouch_ethers`, `pouch_revives`), refilled every round, shared by the
  party, shown under the AP bar. The tutorial starts empty.
- **Items** in the command menu (no longer "coming later"): a list like
  Abilities with counts instead of AP. One Ability or one item per turn;
  Attack and Wait stay open. Potion 35% HP to any ally; Ether 40% of max AP;
  Revive brings a downed ally back at 50% HP (at the party's start after a
  fall), safe from whatever enemies are casting right then.
- **AI allies** use the Revive on a downed ally and a Potion on themselves
  under 35% HP when no Cleric can heal them; never Ethers.
- `Combatant.revive()`, `Moves.Target.DOWNED_ALLY`, `scripts/battle/items.gd`.
- Command List: an Items group. Move details describe each item.
- Tutorial, lesson 7: an Items note, then use a Potion on the hurt Knight
  and Revive the Archer.
- Test `tests/_items.gd`; screenshot `tests/_shotitems.gd`.

## Cleric: Lifeline; version 0.8.0

- **Lifeline** (Cleric, 30 AP, another ally within 8 m): she dashes beside
  the ally, out of whatever area she stood in, and both heal 15% of their
  max HP. An escape that heals, for damage she can't Parry. AI Cleric
  (`_ai_lifeline_target`): after Full Cure, when she stands in a revealed
  area and an ally in reach stands clear of it, or when both are under
  60% HP. Abilities on another ally with a `range` now only list allies in
  range. Tutorial text and the move info mention it. Test
  `tests/_lifeline.gd`.
- Version 0.8.0 (Project Settings, Windows preset, README links);
  `RELEASES.md` has the notes.

## Shadowflare: time to run out; effects outlive a downed caster

- **Shadowflare** (any growing circle) stops either when contained (all 3
  sprites hit) or at full size, and then waits long enough for the slowest
  party member to walk out of it from its middle: its radius at their speed
  plus `flare_run_out_extra` (0.8 s battle time). Before, a contained one ran
  6x faster (`contained_cast_speedup`, removed) and a full-size one struck the
  moment it got there. Stopped while grey, it's revealed at once.
  `tests/_shadowphase.gd`. AI-only Living Armor fights: 5/10 -> 10/10 wins,
  Shadowflare damage 3,156 -> 1,019.
- **Effects outlive their caster:** a status counts down on its caster's
  turns; with the caster down (or gone) it now counts down on its holder's
  own turns instead (`Combatant._ticker`). A downed Mage's Enchant never ran
  out before; same for Shields, Siphon, Taunt and the rest. `tests/_mage4.gd`.

## AI allies: dodging, positioning, ledges, Shadowflare; Lesson 6 fix

- Four play-test logs (Rounds 8-11) and new AI-only boss sims
  (`tests/_bosssim.gd`, now with GREY=0 / FLANK=0 / REACT=s switches)
  showed the cause of most AI deaths: a skill lands about 0.45 s of battle
  time after its reveal, and allies waited 0.4 s before dodging (0.2 s for
  strikes that can't be Parried), so they almost never got out. About half
  their damage from dodgeable strikes would have missed with a prompt dodge.
- **Reaction:** `ally_react_seconds` 0.1 s, `ally_react_unanswerable_seconds`
  0.05 s.
- **Grey areas:** while positioning, AI allies don't walk into an area still
  grey (they still don't leave one early). Not Shadowflare or healing
  rituals. Switch: `ally_avoid_grey`.
- **Ledges:** AI allies keep `ally_ledge_min` (1.5 m) from a lethal edge or
  hole; while an enemy prepares a push (grey or revealed, follow-ups
  included), its push plus `ally_ledge_margin` (1 m). Counts
  `ai_ledge_steps`.
- **Mage and Cleric vs. bosses:** the edge of their reach, and
  `fragile_flank_degrees` (70°) off the boss's front (not wall bosses, not
  when it's locked on to them). Switch: `ally_fragile_flank`.
- **Shadowflare:** each AI ally goes for a different sprite; one that chose
  the Armor (or a sprite someone else hit) switches. Counts
  `ai_sprite_retargets`.
- **Doom Gaze in a corner** dropped no rock (no room at the four compass
  points), so everyone was struck down (3 of 12 sims, old AI too). It now
  tries the diagonals, then towards the middle. `tests/_doomgaze.gd`.
- Old vs new AI, 10 AI-only fights each: Golem 10/10 both; Gale Maw 0 -> 5;
  Dragon 0 -> 1; Living Armor 5 -> 5 (after the Doom Gaze fix; Shadowflare
  is now contained sometimes, but often too late).
- **Tutorial, Lesson 6 (Counter):** attacking into the stance broke it and
  left the Golem frozen with nothing up, so Wait could never count. The
  Golem now raises Counter again after that turn. `tests/_tut.gd` with
  COUNTER_ATTACK=1 attacks into it once first.
- `tests/_aireact.gd` updated for the new reaction times.

## Timing ring on the target; Doom Gaze pinned; Gust Sprite stands still

- **Timing ring on the enemy** (`SpellFx.timing_ring`): every timed press
  hit of a party attack or Art draws a white ring on the floor round its
  target that closes in, plus a gold ring and band for the timing box. It
  appears `timing_ring_lead` (0.9 s) before the hit and shrinks at a steady
  rate, so the ring reaching the gold band is the box opening: you can
  watch the enemy instead of the AP bar. A Perfect flashes it gold, a miss
  red. Melee classes lost their old approach effect (the ring replaces it).
  The Command List preview and Practice show the same ring.
- **Doom Gaze** is `arena_aligned`: its area sits on the arena's centre,
  square with the arena, covering the whole floor; it no longer turns with
  the Living Armor. Test `tests/_doomgaze.gd`.
- **Gust Sprite is stationary** (`move_speed` 0): it no longer walks back
  and undoes a push. In 4 AI-only sims the party knocked it off the ledge
  in 11-15 s, 2 hits each.
- New sim `tests/_bosssim.gd` (R = round index, S = seed): a boss round
  played by a full AI party; saves the usual play-test report.

## Archer: Siphon Shot replaces Riposte

- She had no answer to damage she can't dodge (no Block, no Parry, no heal).
  **Siphon Shot** (30 AP, one enemy within 6 m): Siphoned for 3 of her
  turns; each of her own hits on it heals her 3% of her max HP (6% on a
  Perfect). AI Archer casts it under 70% HP. Tutorial text updated.
- Test `tests/_siphon.gd`.

## Command List (Pause menu)

- **Pause > Command List** (`scripts/battle/command_list.gd`): every party
  member's Attacks, the Arts they've found (hidden ones stay hidden; the
  header counts them) and Abilities, with costs and the move's details. A
  live preview plays the selected move on a loop in a small 3D window: the
  character (in its colours), a target, the move's own timing bar (block
  length, hits, timing box / code / Hold, playhead) and its effects, timed
  like the real thing (Perfect on the timed hits). Abilities show their
  heal / shield / move / buff effect. A/D: character, W/S: move, Esc: back
  to the pause menu. The fight stays paused.
- **Practice:** J on an attack or Art starts practising it: the preview
  waits for your input each round (a 1 s lead-in), judged like a fight: J
  in the timing box, Holds started in their box and let go on the hit, Taps,
  WASD for the Mage's codes (and Energy's taps after). Each hit shows its
  result (PERFECT / TOO EARLY / NO PRESS / RESTART...), a Perfect plays the
  Perfect impact, and a counter shows Perfect rounds. Misses cost nothing.
  Esc stops practising.
- **Counter drill** (Tab, in the Command List): while practising, half the
  rounds (at random) the target is in a Counter stance (red, "COUNTER
  STANCE"). Your first hit is caught and the playhead waits while its
  counter-swing comes (the fight's own lead and window): press J as the red
  line reaches the playhead to break it (the round goes on), or you're
  countered (the round ends). Counts "Counters broken".
- The practice bar is drawn at the battle bar's own scale (a block as wide
  as in a fight, the same minimum box), and plays at the fight's speed.
- Screenshot test `tests/_shotcommands.gd` (with checks; `--fixed-fps 60`).

## Combos fast-forward once nothing is left to press

- When a combo has no input left anywhere (every timing box done or past, no
  Hold to let go, no code to type, no taps still adding damage), the rest of
  it plays 5x faster (`exec_fast_forward`, `_inputs_left`). Hits, effects
  and their timing stay in step. Test in `tests/_mage4.gd`.

## Dragon Hatchling review: it takes floor away

- **Fire Wave** as often as Breath; its fire lasts 5 Dragon turns (was 3),
  burns 20 HP/s (was 10) and costs 15 to step into; at most 3 lines, a 4th
  puts out the oldest. New EnemySkill fields `trail_touch_damage`,
  `trail_cap`, `trail_group`, `trail_turns_below_half`, `arena_aligned`.
- **Scorch and Breathe:** Fire Wave, then Breath 1.5 s later: stack in what
  the fire leaves.
- **Wings of Fire** (half HP, once): four fire lines along the arena, two
  on its edges (laid on the arena, not the Dragon), lasting the rest of the
  fight: three 3.4 m lanes, over half the floor on fire.
  Burning Spike's circles then last 5 turns.
- Tests `tests/_dragon.gd`, `_specials` (5-turn fire); screenshots
  `tests/_shotdragon.gd`.

## Attack effects for the whole party, and enemy hits

- `SpellFx` now covers every party class, in two parts timed to the combo
  bar: an **approach** that starts just before each hit and arrives exactly
  as the playhead lands it (`approach_lead`, launched by
  `_launch_approaches`): the Mage's fireball / violet ball in flight, ice
  shards rising, lightning gathering above; the Archer's arrow; a ring
  closing on the target for the melee classes. Then the **impact**: Knight a
  blade arc (a ground ring on pushes), Assassin a quick X of two slashes,
  Cleric a golden flash, Monk a punch shockwave, the Mage's elements as
  before. A **Perfect** hit gets a bigger impact plus a gold ring and
  sparks. Multi-hit moves time each hit; Arts and finishers are bigger. AI
  combos (played at once) show the impacts.
- **Enemy hits:** a burst on whoever is hit (bigger for heavy blows), a
  blue guard flash on a Defend, a gold flash and slash on a Parry; heavy
  blows (40+ damage or Smash, circles and cones) send a shockwave from the
  enemy; a broken Stagger bar bursts gold.
- **Heals, shields, pushes:** green motes rising on every heal (Healing,
  Full Cure, Light Heal, Deep Breath, Art heals, an enemy's Healing Ritual),
  a pale blue bubble on every shield, and puffs of dust along the path of
  anyone knocked back or pulled.
- Screenshot tests `tests/_shotparty.gd`, `tests/_shotenemyfx.gd` (run with
  `--fixed-fps 60`).

## Enchant: one Ability with an element menu

- The four "Enchant: ..." Abilities are one **Enchant**. Choosing it opens a
  small menu (only while the player is picking): Fire up, Ice down,
  Lightning left, Energy right, as in her spell codes (WASD or the arrow
  keys); back closes it and the Abilities list stays. The AI picks its
  element directly. Screenshot test `tests/_shotenchant.gd`.

## Spell effects: the Mage's four elements

- New `scripts/battle/spell_fx.gd` (`SpellFx`): simple effects built from
  shapes and particles in code, no art files. Building blocks: a flying ball
  with a trail, a burst, a ground ring, a spark puff, a lightning bolt,
  rising shards. Looks only: damage still lands on the combo's timing.
- The Mage's hits play them (`_land_hit`): Fire a fireball that bursts and
  carries on along its line, Ice shards rising round the target then
  shattering into frost, Lightning a jagged bolt from above, Energy Blast a
  violet ball and a shockwave ring. Arts play their elements together,
  bigger, until they get their own.
- Screenshot test `tests/_shotfx.gd` (OUT=folder; KIND=art for four Arts).

## Gale Maw review

- **Deep Breath** gets a Stagger bar (70), like Inhale. (The review found the
  other bars and the damage on its push/pull attacks were already in place;
  they stay as they were.)
- **Feed it a Gust Sprite:** knocked into its body while it pulls (Inhale,
  Deep Breath, Gale Draw), the sprite makes it choke: its Detonate goes off
  inside (3x, 135) and the Maw is Staggered. With its mouth closed, its body
  bounces sprites off. The AI still pushes sprites off the ledge.
- While its mouth is open (a pull being cast), a black mouth shows on its
  front, so you can see when a sprite will choke it.
- **Readability:** pull areas are teal (`EnemySkill.PULL_COLOR`) with teal
  arrows; pushes stay pink. A combo's follow-up shows faintly under its first
  part once revealed (`AttackRange.preview`). During its whole-arena breaths
  the floor each rock shelters is drawn clear (`_shelter_marks`).
- Test `tests/_mawreview.gd`; screenshots `tests/_shotmaw.gd` (OUT=folder).

## Mage rework, Parts 7-8: Focus, Enchant, spell codes; Lightweight Gust Sprites

- **Focus** replaces Concentrate: the Mage's bar is 50 AP, +10 per Focus
  charge (up to 5, so 100). Charges build from the start of every fight
  while she stands still (one per 2 s), walking 2 m loses one, attacking
  spends them all. While she stands still the party's AP refills 50% faster
  (the AP meter's violet chevrons now mean Focus). HUD: "FOCUS 3  BAR 80".
- **Reach 5 m** for every Mage spell and her own reach (the Archer keeps 6).
- **Enchant: Fire / Ice / Lightning / Energy** (30 AP, in Concentrate's
  slot): every ally but her carries the element for 2 of her turns: a 1-turn
  Burn, a Chill, 1.5x Stagger fill, or a 1 m push on their hits.
- **Spell codes** (new CODE timing) replace the Mage's taps and presses: Fire
  W, Ice S, Lightning A, Energy D, typed while the spell casts; an Art's code
  is its elements in bar order. Done before the hit = Perfect; a wrong arrow
  restarts it; unfinished = a normal hit, no penalty. Energy: code, then
  free taps. Arrows drawn on the bar and as badges in the move list.
- **AI Mage** stands still in reach to build Focus and casts Enchant
  (Lightning on a Stagger bar, Ice against 3+, else Fire).
- **Gust Sprites are Lightweight:** every hit knocks them back (at least
  1.5 m, x1.5), walls and corners bounce them off, and touching a hole or the
  ledge drops them at once. The "PUSH IT OFF THE LEDGE!" box with a push
  Art's recipe is gone (redundant now), and so is the push recipe in the
  summon message (`_push_needed` removed).
  AI allies now attack Gust Sprites with any move (real pushes still
  valued 3x).
- **Gust Sprites must be pushed off:** unkillable (damage stops at 1 HP),
  and a 25 s fuse (battle time) after which they cast **Detonate** (4 m
  circle, 45 damage, launch 3 m, not parryable) and blow up. The AI goes for
  them first and lines up each hit from the far side of the nearest drop.
  Sim `tests/_spritesim.gd` (S=seed): 8 of 8 fights, the AI party knocked
  the sprite off the ledge in 14-39 s (game time), before the fuse ran out
  (it used to be 1 of 8, the rest beaten down by damage).
- Tests `tests/_mage4.gd`, `tests/_gustsprite.gd` (Lightweight), `_aimage`
  (Enchant); screenshot test `tests/_shotcode.gd` (MODE=list).

## Mage rework, step 3: all 19 Arts, the AI Mage, a compact Arts list

- The last six Arts: Plasma (Fire + Lightning: Burn + interrupt), Static
  Frost (Ice + Lightning: Chill + interrupt; freezes the already Chilled),
  Tri-Disaster (Fire + Ice + Lightning: all three on a 2.5 m circle),
  Thermal Shock (Fire + Ice + Energy: the heavy Defense-breaker), Nova
  (Fire + Lightning + Energy: everything within 4 m of the Mage), Stasis
  (Ice + Lightning + Energy: every enemy's timeline stops 3 s; bosses lose
  8 turn time, halving). Steam Burst 3.4 -> 2.8 (it leaves Burn and Chill).
- **AI Mage** values her setups (`_ai_mage_value`): areas by enemies hit,
  Flare by Burn to detonate, Shatter on Frozen / Chilled, Overcharge on an
  immune boss cast, Ice Spear / Stasis on an enemy preparing an attack.
- **Arts list:** pages turned with A/D when the Arts don't fit (19 did not:
  the list ran off the top of the screen); it shows the page of the Art the
  bar is heading for. "Fire x3" recipes, "moves in any order merge", and
  hidden Arts summed by length past 6. Screenshot
  test `tests/_shotarts.gd` (KNOWN=all|few). Test `tests/_mage3.gd`.

## Mage rework, step 2: doubles, triples and the Energy mixes

- New Arts (13 in all now): Inferno (Fire x3: a circle that explodes 3 s
  later, Burn x3), Ice Spear (Ice x3: Freeze 3 s and turn pushed back;
  bosses only lose turn time, halving), Chain Lightning (Lightning x2: jumps
  to 2 more), Thunder (Lightning x3: 3 strikes, the last stuns; on bosses a
  3x Stagger fill), Arcane Barrage (Energy x2), Arcane Overload (Energy x3:
  biggest hit, 8 m push, 20 AP back), Flare (Fire + Energy: detonates every
  burning enemy), Shatter (Ice + Energy: Frozen 2.5x / Chilled 1.6x / else
  0.6x), Overcharge (Lightning + Energy: cancels through boss immunity).
- Fireball now leaves Burn x2. New move fields: `burn_stacks`,
  `delayed_blast`, `deep_freeze` + `turn_push`, `chain`, `stun_not_bosses`,
  `stagger_mult`, `ap_refund`, `detonate_burns`, `shatter`,
  `ignore_cancel_lock`. Frozen enemies don't move.
- Reports count `deep_freezes`, `boss_freezes`, `shatters`, `flares`,
  `blasts_hit` / `blasts_missed`, `ap_refunds`, `overcharge_cancels`.
  Test `tests/_mage2.gd`.

## Mage rework, step 1: four elements, order-free Arts, Ice makes Fire cheaper

Design: the "Mage Rework: Elements and Arts" doc (six parts, settled).

- **Four elements** replace Fire / Frost / Gust / Arcane Surge: Fire (line,
  Burn), Ice (Chill), Lightning (single target, interrupts), Energy Blast
  (Arcane Surge's open Tap, plus Gust's 3 m push).
- **Order-free Arts** (`any_order`, every Mage Art): Fire + Ice = Ice + Fire.
  The next-move hint in the Arts list follows suit.
- **Ice discount:** 20% off each Fire after an Ice (and in the same Art), up
  to 40%; a combo with Ice takes 20% off next turn's Fire too; 50% at most.
- **Biggest bar:** 90 -> 110 AP.
- Arts carried over: Fireball, Blizzard, Steam Burst (now leaves Burn and
  Chill from its parts) and Meteor (all four elements; `no_inherit` keeps
  the push and interrupt out). Firestorm and Tempest are gone with Gust.
- Reports count `ice_carries` and `ice_discount_ap`. Test `tests/_mage1.gd`.

## Shadowflare: 12 s, and quick once contained

- A Round 9 log: both Shadowflare phases were stopped, the party took 18
  damage in all, and the Armor got 4 turns in 2:39: 20 s casts left it idle.
  Cast speed 0.072 -> 0.12 (about 12 s). Once all three Shadow Sprites are
  hit, the rest of a contained cast runs 6x faster (`contained_cast_speedup`,
  any growing circle).

## AI Cleric heals sooner and first

- "Is the Cleric healing at all?" In a Round 9 log she cast Haste twice and
  never healed while three allies went down: one Shadowflare took them from
  healthy to dead in one hit, and Healing only started under 55% HP. Heals
  were also skipped when they would dip into the AP held for your turn.
- Now: Healing under 70% (`ai_heal_below`), Full Cure under 35%
  (`ai_full_cure_below`); heals ignore the AP reserve; no AP for Full Cure
  means Healing instead. Reports count `hp_healed` (every skill and Art
  heal) and `ai_heal_no_ap`. Test `tests/_aicleric.gd`.

## Shadowflare is a phase: at 50% and 20% HP, 20 s to stop it

- A Round 9 log: one Shadowflare dealt 361 and took down the Archer, Mage
  and Cleric; at about 8 s there still wasn't time to get to all three
  Shadow Sprites.
- It's now a phase (`EnemySkill.phase_at_hp`): the Armor casts it at its
  next cast after dropping to 50% HP, and again at 20%, and never at
  random (weight 0; it used to be a random pick, forced once at 70%). A
  big hit that crosses both thresholds spends both on one cast. Reports
  count `phase_casts`.
- Cast speed 0.17 -> 0.072: about 20 s at Round 9 speed to hit the
  sprites. Test `tests/_shadowphase.gd`.

## Golem Smashes can be Defended

- A Golem log: the Cleric went down to two half-room Smashes (56 each) she
  couldn't Defend, so the new Parry-key Defend saved her almost nothing.
  All eight Golem Smash skills drop `cannot_be_blocked`: still no Parry
  (dodge them), but Defend (either key for the Cleric) takes 56 down to 34.
  AI allies still react 0.2 s after the reveal: that shorter reaction now
  applies to any strike that can't be Parried.


- A fighter who can't Parry a strike but can block it (the Cleric, blue
  mark) now Defends when you press Parry: alone it's a plain Defend (same
  AP cost); in a group with a Knight, the Knight parries and the Cleric
  Defends (one Defend's AP, kept for the rest of a multi-hit chain). The
  prompt reads "E / Q: Defend" when only blockers are hit. Test
  `tests/_parrydefend.gd`.

## Fix: AI allies with a Windup target walked into Doom Gaze

- A Round 9 log: the Mage and Assassin (Party AI) both died to one Doom
  Gaze. An ally heading for its Windup target kept walking at the Armor
  instead of hiding: the Windup approach came before the hide check. Now
  hiding comes first; the turn waits in cover and walks in after the gaze.
  Test `tests/_gazewindup.gd` (failed before the fix: 17 m from cover).

## Tighter Parry timing; Shadowflare slow but deadly

- `parry_window` 0.25 -> 0.15 s (real time), with Expedition 33's parry as
  the reference: read the swing, press once, on the hit. An early press
  was already a committed miss. Edge saves (Off-Balance at a ledge) keep
  0.25 s (`edge_save_window`); the counter-parry is unchanged (0.12 s).
- **Shadowflare** was still too fast to stop: cast speed 0.25 -> 0.17
  (about 8.4 s at Round 9 speed), damage 52 -> 100, and it can't be
  Parried any more (Defend still halves it). Stop it with the Shadow
  Sprites, or get out.

## Dragon: Burning Spike toned down

- A Round 10 log: Burning Spike dealt 386 of the party's 684 damage taken
  (4 casts, 16 hits; it can't be dodged, only broken). Damage 26 -> 20,
  weight 2 -> 1 (now half as likely as Fire Wave, a third as likely as
  Breath), Stagger bar 120 -> 100 (easier to break).

## Gale Maw under half HP: Double Gale Lanes, push / pull + lanes; real follow-up delays

- **Double Gale Lanes** (under half HP, replacing Gale Lanes): the 2 gaps
  between the lanes first (`EnemySkill.lanes_in_gaps`), leaving 3 safe
  lanes, then Gale Lanes on those 3 lanes 2.5 s later.
- **Push / pull + lanes only under half HP:** Gale Burst (Exhale) and the
  new Gale Draw (Inhale) are followed by Double Gale Lanes 1 s later.
  Skills can now be limited by HP: `only_below_hp` / `only_above_hp`.
- **Follow-up delays are real seconds now.** A fast boss's bar couldn't fit
  the delay before the end, so it was cut short: the Golem's double Smash
  gave ~1.3 s, not 2. The follow-up now starts at the casting zone's edge
  and its bar runs slower (`follow_up_slow`) when needed. Tests check the
  real delay (`_follow_up_seconds`).

## Shadowflare slower, Crush faster, Maw Bite covers its front, AP bar fix

- **Shadowflare** cast in about 4.1 s at Round 9 speed, too short to get a
  turn in and hit its Shadow Sprites. Cast speed 0.35 -> 0.25: about 5.7 s
  (and the circle grows that much slower).
- **Crush** turns at 160°/s in its last second (was 80).
- **Gale Maw's Maw Bite** covers its whole front (180°, was 100°) out to
  8 m: no sidestepping round it, only backing out of reach (or Parry /
  Defend). Fighting up close is high risk, high reward.
- **Gale Maw: only Maw Bite can be Parried.** Gale Lanes, Breaker, Wall
  Sweep and Undertow join Inhale, Exhale, Deep Breath and Gale Burst as
  `cannot_be_parried` (Defend still works where it did). Its biggest hit
  is the one you answer with timing.
- **AP bar:** with a high ceiling it ran over the enemy's status tags and
  name. The HP panels now report how wide they drew (tags on the left
  included) and the AP meter shrinks and shifts to stay between them. Test
  screenshot `tests/_shotap.gd`.

## AI reaction to Smashes: 0.2 s

- At 0.4 s the AI allies couldn't escape the half-room Smashes (Archer and
  Mage down); reacting at the reveal itself, they escaped all five. Strikes
  that can't be Parried or Defended now use `ally_react_unanswerable_seconds`
  (0.2 s), between the two. Tunable on the BattleArena node.

## Crush goes for the back line; lines keep tracking; Rock Stomp steps in

Goal: simple, short skills should at least have a chance to hit.

- **Crush** (`targets_far`): locks onto a random party member more than
  6 m away unless a Knight's Taunt holds the Golem, and keeps turning at
  80°/s in its last second (`EnemySkill.final_turn_speed`). Reports count
  `far_targets`.
- **All lines** (Attack / Smash, not snapping or placed) turn at least
  `line_final_turn_speed` (80°/s) in their last second instead of 40°/s:
  Crush, Power Shot, Wind Slash, the Orc Shaman's Attack, Fire Wave, Long
  Strike. Past ~3.5 m nobody outruns it sideways; rocks, range, Parry and
  Defend are the answers.
- **Rock Stomp** and other short circles round the enemy count for melee
  tracking: the Golem steps after a target at the circle's edge.
- In a Monk run (built before these) the party took 37 damage in total: all
  five Smashes missed (AI allies now move at the reveal), Crush missed
  twice and was parried once, Heavy Attack parried twice. Threat worked:
  4 casts went for the Archer.
- Test `tests/_crush.gd`.

## Parry rings only for those who can Parry; AI dodges Smashes at the reveal

- A Golem log: the Archer and Mage went down to the half-room Smashes
  (418 of 498 damage), the Knight took 0. With the 0.4 s reaction delay
  the AI allies lost a third of the ~1.3 s window on strikes they can't
  Parry or Defend. Those now count from the reveal itself; the delay stays
  for strikes your Parry / Defend can answer. (No `threat_targets` in that
  run: the Knight dealt the most and stood nearest, so it was both.)
- Strike rings: the shrinking Parry ring now shows only on targets who can
  Parry that strike. Others get a plain mark, blue if they can Defend it,
  red if not (the Archer always; everyone under a Golem Smash). Test
  `tests/_parryring.gd`.

## Double Golem Smash: side shown early, 2 s to cross; threat count

- A Golem log after the changes below: 521 damage taken (from 56-112),
  everyone hit, nobody down, but Left + Right Golem Smash dealt 392 of it
  (two casts, 7 hits of 56: the Archer, Mage and Cleric took both halves).
  The doubles now show their first side in grey from the start again (no
  `hides_side`; the single Smashes keep it), and the second half comes 2 s
  after the first instead of 1.5 s.
- Play-test reports count `threat_targets` / `threat_targets_<class>`: a
  boss cast locked onto someone other than the nearest because of threat.

## AI allies dodge late, melee holds ground, hidden Golem Smash side, boss threat

More ways enemy damage lands, after runs where whole fights dealt nothing:

- **AI allies react after the reveal.** They used to leave an area the
  moment its grey "..." shape appeared, so they were out before anyone knew
  what it was. Now an Attack/Smash counts only `ally_react_seconds` (0.4 s)
  after its reveal. Mechanics (spread, stack, overlap circles), falling
  rocks, blasts and hazards still count at once.
- **Knight and Monk hold their ground** (`Combatant.holds_ground`) in a
  short melee attack that can be Parried or Defended: your one Parry /
  Defend press covers everyone hit, so it's your timing, not their
  footwork.
- **Golem Smash hides its side** (`EnemySkill.hides_side`): grey, it covers
  the whole room; the reveal shows which half (about 1.3 s before the
  strike starts at Round 8 speed). All eight half-room Smash skills.
- **Boss threat:** bosses lock onto whoever hurt them most lately, weighed
  against distance (share of threat minus distance / 15 m; threat halves
  each cast), instead of always the nearest. Spreads the danger beyond
  whoever stands in front.
- Test `tests/_aireact.gd`. `_aidodge.gd` now sets its Smash as revealed
  long enough ago, picks its spot deterministically and holds the Golem's
  facing (a held Golem still turned and moved its Smash away).

## Melee tracking: short attacks are hard to dodge up close

- Some fights ended with most of the party taking no damage at all: a
  regular Attack only slowed to 40°/s in its last second, so a single
  sidestep took you out of it, even standing right next to the enemy.
- Short cones and lines (Attacks and Smashes up to 5.5 m, cones under 180°)
  now keep turning at 300°/s through the end of the cast when their target
  is within the area's length + 1.5 m, and the enemy steps after a target
  backing off past 75% of that length. Farther away nothing changes: the
  last second still turns slowly. Half-room Smashes, placed circles, long
  lines and the Dragon's Breath are untouched.
- The tutorial's "Reading the enemy" note says so (leave early, or Parry
  and Defend up close). Test `tests/_meleetrack.gd`.

## Party AI: ranged allies walk round rocks; Shielding not recast

- From a Golem run with Party AI: the AI Archer lost 3 of her 8 turns to
  TOO FAR. A fallen Ceiling Burst rock stood between her and the Golem: in
  range, but no clear shot, and walking straight at the target only pushed
  her into the rock. With a Windup target and no line of sight, an AI ally
  now heads round the rock's side first (like hiding from a Doom Gaze).
  Test `tests/_airock.gd` (in range behind a rock: attacks in 0.5 s).
- The AI Cleric cast Shielding 4 times (160 AP) because two allies stayed
  under 75% HP. It now needs two hurt allies *without* a shield.

## Party AI: the Cleric hastes you when nobody needs healing

- With everyone above 55% HP (and fewer than two below 75%), an AI Cleric
  casts **Haste** on the fighter you steer (turns 25% sooner for 2 of their
  turns, 40 AP), once until it wears off, with the usual AP reserve. In a
  Golem run she'd dealt 54 damage in 4 turns and cast nothing. Test
  `tests/_aicleric.gd`.

## Party AI: the Mage casts Concentrate

- An AI Mage now casts **Concentrate** (AP recharge x2 for 10 s) whenever the
  party can afford it and none is running; Arcane Barrier still comes first
  when an attack is aimed at her. In the all-AI Golem test that meant 26 AI
  attacks instead of 20. (Concentrate is due a rethink in the Mage rework.)
  Test `tests/_aimage.gd`.

## Play style, asked once

- The first time you start Boss Rush, Continue or Round Select, a **Play
  style** page asks for **Command timing** (Windup / Classic) and **Party
  AI** (On / Off), each with a short explanation that changes with the
  choice, and a reminder that both live in the pause menu (Esc during a
  fight). Start saves both and carries on; it never asks again
  (`Settings.style_chosen`). A/D or Enter flip a choice, W/S move, Esc goes
  back. Test `tests/_style.gd`.

## Party AI: dodging doesn't cost the turn; AI hits 20% weaker

- From a Golem run (Monk steered): the AI Archer and Mage each lost a turn
  to TOO FAR while escaping Ceiling Burst circles. An AI ally's Windup grace
  now waits while it's inside a danger area ("DODGING"), and starts once it's
  out; your own fighter keeps the normal rule.
- AI hits deal 80% of a normal hit (`ai_damage_mult` 0.8, on top of having no
  Perfect bonus): with Party AI and the Monk the Golem only got 4 actions and
  dealt no damage. Test `tests/_aidodge.gd`.

## Party AI: Agility only with AP to spare; who did what, in the report

- From a Golem run with Party AI (2:06, 64% of the damage by the steered
  Knight): the AI Archer dealt 94 in 6 turns after casting Agility twice
  (120 of the party's AP). It now casts it only if, after paying, it still
  has half its bar for this turn's attack and leaves yours alone.
- Play-test reports now count per member: `windup misses <class>` (who
  couldn't reach anyone), `ai attacks <class>`, `ai waits <class>` and
  `ai ability <name>`.

## Windup: a missed pick falls back to the nearest enemy in reach

- At ACT, when the 1.5 s grace runs out and the chosen enemy is still out of
  reach, the attack now goes to the nearest enemy that *is* in reach
  ("SWITCHES TARGET", with a line saying who), for you and AI allies alike,
  instead of becoming a Wait. You still get the whole grace to reach your
  pick first. Never an enemy in Counter stance (and AI allies skip tough Gust
  Sprites they can't push). Nobody in reach: a Wait, as before. Test
  `tests/_fallback.gd`.

## Party AI

- **New toggle: Party AI** (pause menu, off by default, saved). With it on,
  every party member you aren't steering plays its own turns, instantly: no
  menus, no combo bar, the timeline never stops; you only see the hits, the
  damage and a line like "Cleric: Judgment on Stone Golem (36 damage)".
  Tab (or hold Tab) takes any of them over, as usual; the party list tags the
  others **AUTO**.
- **What it does on a turn:** maybe one Ability (the Cleric heals the lowest
  ally below 55%, Full Cure below 30%, Shielding when 2+ are hurt; Knight
  Light Heal / Brace, Mage Arcane Barrier when an attack is aimed at them,
  Monk Deep Breath, Assassin Vanish, Archer Agility when AP is plentiful),
  then an attack: the target allies already focus (a healer mid-ritual,
  Shadowflare's sprites) or the nearest, never one in Counter stance, never a
  tough Gust Sprite without a push. Its combo is picked greedily by damage
  per AP from single moves and **every Art of its class, found or not** (an
  ally you never steer still uses its whole kit), weighed by the answer
  tags. Arts you haven't found stay hidden: never added to your Arts list,
  and shown as "a hidden Art" in its messages. A Defense stance needs a
  breaking or piercing move first, a Gust Sprite a push. With Windup it
  chooses at COM and walks into reach like any ally; in Classic it attacks
  whoever is in reach.
- **AP:** it spends up to 75% of its own combo bar (`ai_spend_share`) but
  keeps 60% of your fighter's bar (`ai_reserve_share`), minus what recharges
  before your turn; if that leaves too little, a smaller attack that still
  keeps you half of it.
- **Max AP:** its hits land without timing (no Perfect bonus), never reset
  max AP, and every timed hit adds 1.5 (`ai_max_ap_per_hit`; a Perfect adds
  5).
- Off in the tutorial. Enemy strikes on AI allies still prompt you to Parry
  or Defend, as before. Tests `tests/_partyai.gd` (whole fights with only the
  AI attacking: it beat the Stone Golem alone in Windup and Classic; your
  fighter had 37-71 AP at every turn; with `HIDDEN=1`, nothing found: 20
  hidden Arts used, none revealed or named) and `tests/_shotai.gd`.

## The fight's opening text stays up

- The round name and its tip shared one message slot with everything else:
  the first turn, or any other message ("A rock crashes down!", "Knight goes
  for..."), wiped the tip after a few seconds. Now they have their own slot
  (`_intro_message`) above the other messages, shown for 4 s + 0.05 s per
  character (6 to 18 s; the Gale Maw's four-line tip gets 18), counting down
  only while it's on screen (not during strikes or combos). Test `_intro.gd`.

## Monk: the bar stays put after a step; Tortoise Special is a tap frenzy

- **Tortoise Special: tap as fast as you can, no limit.** After its two
  opening presses, the rest of the block (from 40% on, about 5.6 s at the
  Monk's speed) is an open tap: every tap adds 4% to the finishing hit and
  there's no ceiling (30 taps is a Perfect). Hits 0.8 / 0.8 / 1.25 (was
  2.4), so about 30 taps matches the old damage and faster tapping beats it.
  At bar 100 (2.5x): 10 taps 183, 30 taps 288, 60 taps 387, 90 taps 486.
  The bar shows a fill toward the Perfect and the running count
  (`surge_uncapped`; test `_tortoise.gd`).
- Earning a step or a token mid-combo (Knee Smash, Palm Strike...) used to
  take the played blocks off the bar right away, so the rest of the bar
  shrank and slid under the playhead: the next timing box was suddenly
  somewhere else. Played blocks now stay on the bar, dimmed like any played
  block, and the bar keeps its size and scale for the whole combo (a
  Headbutt's fresh bar still starts over after its READY lead-in). Test
  `_monkbar.gd`.

## Bosses act more often; no turns lost to Doom Gaze

From a full 0.5.0 Boss Rush log (rounds 1-11 won first try, the bosses dealt
0 / 0 / 131 / 38 damage, about one boss action per four party turns):

- **Boss rounds are faster:** `enemy_speed_mult` 1.25 -> **1.5** (Living Armor,
  Dragon Hatchling, Gale Maw) and 1.4 -> **1.7** (Stone Golem), so bosses act
  about 20% more often.
- **Living Armor: Shadowflare for sure at 70% HP** (`sure_below_hp` 0.7). In 7
  actions it had only used Combo and Doom Gaze, so its signature skill never
  showed up.
- **Windups wait in cover during a Doom Gaze.** Everyone hides behind the
  cover rock (about 8 m away), out of reach of everyone but the Archer, so
  the grace ran out and attacks became Waits: 6 lost turns and a Mage with 0
  damage in that fight. While an enemy prepares a lethal skill the grace now
  doesn't run ("WAITS IN COVER"); it starts once the gaze is over. Test
  `_gazewait.gd`.

## Hold Tab to choose, Monk timing boxes, bosses hit harder

- **Hold Tab to choose who to steer.** Between turns, holding Tab for 0.3 s
  stops time and opens a **STEER WHO?** panel with each party member's HP:
  A/D (arrows, mouse wheel, or 1-6) picks, the camera follows the pick, and
  letting go of Tab steers that one. Downed members are greyed out and
  skipped. A tap still switches to the next one. The bottom hint and the
  title screen's controls list say so (`SteerPicker`, test `_steer.gd`).
- **Monk: timing boxes now count everywhere they're drawn.** Boxes are drawn
  at least 14 px wide, but presses were judged against the move's real
  window, which could be much narrower on screen. The Monk's half-speed
  playhead halves it: in a bar of only Arts (Triple Rush, Mountain
  Crusher) the window was 8.6 px inside a 14 px box, so pressing in the
  left 40% of the box was a miss. Presses are now judged with the drawn
  width (`BattleMenu.box_fraction`); other classes' boxes (19-26 px) were
  already accurate. Test `_monkbox.gd`.
- **Bosses hit 15% harder** (`boss_damage_mult` 1.15): every hit from a boss's
  skills, rocks, blasts and Counter stance. Counter stance damage is now
  recorded under the enemy's skills in play-test reports. Test `_bossdmg.gd`.

## Stone Golem: rocks always fall

- A playtest went 5 Golem actions without a single Ceiling Burst (about a
  1-in-3 chance), so the rock phase never happened. Now the first cast
  after the Golem drops to **75% HP** is a **Ceiling Burst** for sure,
  unless it already dropped rocks by chance. After that it picks at random
  as before.
- New, for any enemy skill: `EnemySkill.sure_below_hp` (0 = off), once per
  fight. Test `_golemsure.gd`.

## Gale Maw: Gust Sprites go over the edge

- **Gust Sprites are very tough** (`Combatant.damage_taken_share` 0.2: they
  take 20% of any damage, so 60 HP plays like 300) **but light**
  (`knockback_taken` 1.5: every push sends them 1.5x as far). Push one off
  the ledge and it falls, gone at once.
- The move list tags pushing moves **PUSHES** (green, with how far) against
  them, and everything else **TOUGH** (yellow). Pushers: Mage Gust /
  Firestorm / Tempest, Archer Gale Shot, Knight Smash (unguarded) /
  Crusader's Edge and the rest with knockback.
- **Every class can now push** (so any party can deal with Gust Sprites):
  the Assassin's **Ambush** kicks its target 3 m away, the Cleric's
  **Smite** pushes 3 m, and the Monk's **Flash Kick** pushes 3 m with the
  Monk following, like Crusader's Edge, so his combo stays in reach. All
  three are single-hit Arts; against a Gust Sprite that's 4.5 m.
- **Push Arts are spelled out when a Gust Sprite is up.** If a party member
  knows no push yet, they get the hidden Art's full recipe: in the summon
  message ("Monk can push with Kick + Kick"), on the TOUGH move details
  ("Try Kick + Kick: a hidden Art that pushes") and in an orange
  **PUSH IT OFF THE LEDGE!** box above the Arts list. All of it goes away
  once that character knows a push (`_push_needed`, `_push_recipe`,
  `BattleMenu.arts_urgent`).
- Test `_gustsprite.gd` (also checks every class has a push).

## Living Armor: Shadowflare's Shadow Sprites

- **Shadowflare** no longer stops growing from damage to the Armor. When
  the cast starts, it calls **3 Shadow Sprites** that circle along the edge
  of the growing circle (2 m/s, so they're catchable even when it's big).
  Hit each one once (they have 1 HP) and the circle stops growing. The
  Armor's bar shows 3 pips for them. They aren't on the timeline and leave
  when the skill ends. AI allies position around the nearest sprite.
- **It grows much slower** (cast speed 0.6 -> 0.35), but much bigger: up to
  the distance from the arena's middle to its corners (17 m in its arena,
  was 11). Cast from the middle, nowhere is safe; cast from off to one
  side, the far side stays out of reach.
- Tutorial line updated. Test `_shadowflare.gd`; `_specials.gd` updated.

## Stone Golem: lasting rocks, exploding rocks

- **Fallen rocks stay** (Ceiling Burst and the Smash combos:
  `ceiling_rock_seconds` 0 = until broken).
- **Only 2 bursts leave rocks** (`Combatant.max_rock_bursts` = 2 on the
  Golem). Later bursts still drop their damaging circles, but no new rocks,
  so the arena doesn't fill up.
- **Golem Smash blows up the rocks in its half** (`EnemySkill.
  smash_blasts_rocks`, on both Smashes and both combos): from the reveal,
  each rock inside the Smash's area gets an orange circle (2.5 m), the skill
  name adds "ROCKS EXPLODE", and AI allies avoid the circles. When the Smash
  lands, those rocks explode (30 damage to anyone in a circle) and are gone.
  Rocks that fall during a Smash + Ceiling Burst are marked as they land.
  Test `_golemrocks.gd`.
- **Right + Left / Left + Right Golem Smash** (two new Golem skills): it
  smashes one side, then the other side 1.5 s later (`follow_up`,
  `follow_up_delay` 1.5), blowing up every rock in the arena. Follow-ups now
  take their own aim (`aim_offset_degrees`) and mark rock blasts when
  they're revealed.
- **The double Smash comes when rocks pile up, but not right away.** Each
  rock that has lain on the floor for 12 s adds weight to both double
  Smashes (`EnemySkill.rock_clear_weight` 0.3 per rock,
  `rock_settle_seconds` 12); with no rocks they're half as likely. Measured
  chance of picking one: about 10% with no rocks, 10-18% right after two
  bursts (20 fresh rocks: they get to block the party first), 45-60% once
  those 20 have settled.

## Counter-parry; backing out of a Counter at ACT

- **Counter-parry:** hitting an enemy in Counter stance mid-combo no longer
  ends the combo at once. The hit is caught, the playhead stops, and a red
  line closes in on it ("! COUNTER !"): press the hit key as it arrives
  (within 0.12 s of the swing, 0.6 s after the hit) and the stance breaks
  ("COUNTER BROKEN!"), the rest of the combo deals +25%, and after a 0.6 s
  breather (a gold ring shrinks around the playhead, "BROKEN! READY...";
  presses meanwhile are ignored) the playhead moves on. Too early or too late: you're countered (33 damage) and the
  combo stops, as before. The move list tags it "COUNTER: PARRY IT" (yellow)
  instead of COUNTERED (red). Stats: `counter_parry_tries`,
  `counter_parries`.
- **AI allies dodge falling rocks properly.** You steered only the Monk,
  so the Mage and Cleric were the AI's. Two causes, both reproduced in a
  simulation (3 of 6 bursts hit someone when older rocks were on the floor):
  - Escaping a circle, they pushed straight away from its centre; a fallen
    rock or another fighter in the way kept them inside. Now they take the
    shortest *clear* way out (rocks, the arena edge and other fighters
    block directions; other danger isn't walked into).
  - They only avoided circles about to land (last 1.6 s), so they walked
    into ones landing a moment later. Now every pending circle is avoided.
  - Walking to a committed target (Windup) now steps out of danger first.
  Simulation after the fix: 1 hit in 12 bursts. Tests `_fallwindup.gd`,
  `_fallsim.gd`.
- **No more max AP penalty for avoidable hits** (for now):
  `avoidable_hit_max_ap_loss` 100 -> 0. Taking a hit you could have avoided
  just costs the damage; the red "!" warning on the AP meter is off with it.
  They're still counted in the fight reports, and the Monk still loses a
  step. Tutorial text updated.
- **Windup timing, more room to get in reach:** the command point (COM)
  moves from 70 to 65 on the timeline, and the grace at ACT goes from 1 s
  to 1.5 s. (Round 9 run: 13 Waits and 4 TOO FAR in 32 party turns.)
- **Fixed: a slightly late press could end the chain.** A press just after
  a timed hit landed was judged against the *next* box as too early: a miss
  that ends the chain and costs all AP. With close boxes (Triple Rush: two
  presses, then the Hold) that happened a lot. Now a press within 0.2 s of
  a timed hit landing counts as that hit's late press ("LATE": no Perfect,
  nothing lost). `late_press_grace`; test `_latepress.gd`.
- **Monk's build bar no longer covers the party HP list:** when the centred
  bar (with his climb steps) would reach the list, it starts right of it
  (`LEFT_HUD_CLEAR`, 430 px) and squeezes slightly if needed to fit.
- **Fixed a softlock (Windup):** at ACT, if the party can't afford any move
  that reaches the target (others spent the AP; the Cleric had 19 AP, Holy
  Light costs 20 and Bash / Divine Barrier didn't reach), the turn now
  becomes a Wait instead of opening a combo bar you couldn't use or leave.
  Backing out at ACT uses the same check.
- **Windup:** if the target went into Counter stance after you committed,
  backing out at ACT is allowed again and the turn becomes a Wait.
- From a Round 9 run: Counter stance dealt 262 of the 512 damage taken
  (the Cleric went down to it), and the fight ran 14 minutes.
- Tutorial lesson 6 (Counter) explains both.

## Bosses resist being cancelled

- **Boss cancel resistance** (`Combatant.cancel_every`, set to 2 on the Stone
  Golem, Living Armor, Dragon Hatchling and Gale Maw): an interrupt, stun or
  Hook can cancel a boss's skill only once every 2 of its actions. Each
  cancel this fight adds one more action of immunity, up to 3. A resisted
  cancel pops "IMMUNE", and the move list tags it IMMUNE (yellow) instead of
  STUNS / INTERRUPTS. Breaking a Defense or Counter stance always works.
  The Training Golem has no limit.
- **Signature moves can't be cancelled** (`EnemySkill.uncancellable`,
  "UNSTOPPABLE"): Golem Smash (both sides), Ceiling Burst and the two Smash +
  Ceiling Burst combos; Shadowflare; Breath; Exhale and Gale Burst. Halts
  (freeze) and Stagger still work on them.
- From a Round 8 run where the Golem's 5 actions were all stopped or
  answered (4 interrupts, 3 freezes): 0 damage taken all fight.

## HUD restyle to match the timeline bar

- New shared look (`scripts/ui/hud_style.gd`, `HudStyle`): deep navy panels
  brightening toward the top, a gloss band, a blue accent line along the top
  edge and a pale blue-white frame; bold slanted titles with a navy outline;
  glossy gradient gauges with ticks every 10%; selected rows get a gold wash
  fading to the right.
- Applied to the command menu, move list, Arts panel, move/Art details,
  target prompt, combo bar (header and trough), HP bars and names, AP meter
  frame, combo counter, tutorial box, pause menu, party picker and title
  screen.
- Readability pass: only big titles (24 px and up: fighter name over the
  menu, PAUSED, the game title, WAIT / CAST / ACT) use the bold slanted
  lettering. Smaller text (names, headers, labels, the combo counter) stays
  in the plain font, which read wavy when bolded and slanted.

## Balance after a Windup run; Windup on by default

- **Windup timing is now the default and no longer a prototype.** Classic
  stays as a toggle in the pause menu.
- **The tutorial teaches Windup** and always runs with it. Lesson 2 explains
  WAIT / COM / CAST / ACT; lesson 3 moves the Knight out of reach and walks
  you through choosing Attack at COM, getting in reach before ACT, and
  building the combo at ACT. The Mage, Assassin and free-practice texts
  follow the same flow. The Classic tutorial is kept in
  `archive/tutorial_classic.gd`.
- **Solo bosses (rounds 8-11):** HP boost x1.5 -> x1.2. The Stone Golem's
  speed boost x1.25 -> x1.4 (it acted 8 times in a 10-minute fight).
- **Archer:** Triple Shot 1.0 + 1.0 + 1.6 -> 0.95 + 0.95 + 1.5 (3.6 -> 3.4,
  still above Double Shot + Shoot). She dealt 41% of the damage.
- **Mage** up about 10%: Fire 1.1 -> 1.2, Frost 0.9 -> 1.0, Arcane Surge
  0.8 -> 0.9, Fireball 3.0 -> 3.3, Blizzard 2.4 -> 2.6.
- **Monk:** a missed timing in his own combo no longer drops a step, only his
  newest token ("-1 TOKEN"); his climb holds. Avoidable hits and early
  Parries still cost a step. (He climbed 3 steps and lost all 3 to misses.)

## Used-Ability chip and badge; no backing out at ACT

- Still one Ability per turn, then Attack or Wait (briefly tried: an Ability
  ending the turn; reverted). The used Ability now shows as a coloured chip
  with a tick on the Abilities row, and as a diamond badge on the fighter's
  timeline icon until the turn ends (with Windup: until the attack at ACT).
- The chosen Art's details (Tab in the combo bar) now show left of the move
  list, where a move's details go, instead of above the Arts panel: long
  Arts like Crusader's Edge and Thousand Cuts were cut off at the top of the
  screen. Move and Ability details also never reach into the timeline bar
  (their text shrinks a little if needed). `_cutoff.gd` checks every move,
  Ability and Art of all six classes.
- Windup timing: when the committed attack reaches ACT, the combo bar can't
  be backed out of to Attack / Ability / Wait any more. If no move is
  affordable, backing out ends the turn.

## Timeline bar restyle

- The turn bar is a glossy gauge: navy-to-blue across the waiting stretch
  with small segment ticks and tall ones every 10, an orange-to-red glowing
  casting zone, and a gold cap at the end.
- Slanted bold zone names sit on the bar: WAIT, CAST, ACT (and COM at the
  party's command point when windup timing is on). Zone edges are glowing
  dividers.
- Icons hang on slanted pins with a small pointer on the bar.

## Smash breaks Defense; Crusader's Edge follows; control stays put

- **Smash** (Knight Art) breaks Defense again. It knocks the enemy 4 m back
  only when it wasn't defending (breaking the guard takes the push).
- Once a breaking move is on the bar against a defending enemy, the moves
  and Arts after it no longer show BLOCKED / PARTLY BLOCKED.
- **Crusader's Edge:** the Knight follows the enemy as it's knocked back,
  so it stays in reach.
- Movement control only changes with Tab: after a party turn, and now also
  after committing at COM (Windup), it goes back to whoever you were
  steering (briefly tried: staying on whoever just acted; reverted).

## Command timing: windup (prototype)

- New setting in the pause menu, **Command timing: Classic / Windup** (off by
  default; takes effect on the next fight or a restart). With Windup, a party
  member chooses at a command point (70% of the timeline, a gold notch):
  Attack picks any enemy, then time runs and you have until your icon
  reaches the end to get in reach. A 1 s grace still lets you act the moment
  you arrive; after that the turn becomes a Wait. AI allies walk to their
  own targets. Classic mode is unchanged.

## Party in pick order

- The party picker keeps the order you tick classes in (shown as numbers in
  the boxes); the party comes out in that order and the first one starts
  under your control. The next round's picker remembers it.

## One Execute per bar; Thousand Cuts needs Marks

- An enemy carries at most **4 Marks** (was 5), and Execute costs at least
  40 AP (was 25). At 5 Marks it cost 25, so two fit in the Assassin's
  50 AP bar.
- Thousand Cuts only forms on a target with 2+ Marks and spends 2 as it
  starts (it used to add 2), so it can't be repeated freely. Its cuts count
  as Stabs, which is why the Marks go first: otherwise they'd grow back.
  The Arts list shows "needs 2 Marks on the target" while it's hidden.

## Easier to find Arts (mostly for the Monk)

- 2-move Arts get partial hints too: 1 move right, with the pair inside the
  bar ("??? Kick + ?  (1 of 2)").
- The Arts panel lists each hidden Art's length and AP, and what still
  blocks it: "four-move, 35 AP (needs bar 50)", "needs Crowd Cheer".
- An Art made of Arts you already know shows as those Arts: "??? Palm
  Strike + Knee Smash  (Arts you know)".

## Shields expire

- Every barrier or shield is now its own stack that runs out after 2 of its
  caster's turns (`Combatant.shield_stacks`). Giving more adds a new stack
  with its own countdown; older ones aren't refreshed. Damage uses up the
  oldest first; the half-max-HP cap stays. "Wore off: ...'s shield" shows
  when one runs out.

## Solo bosses get more HP and speed; Monk at half speed

- Playtest: in the solo boss rounds the boss acted 2-4 times per fight
  while the party took 11-19 turns. Rounds 8-11 now give their boss x1.5
  HP and x1.25 speed (`Encounter.enemy_hp_mult` / `enemy_speed_mult`);
  the mixed rounds are unchanged. Gale Burst's lanes follow a little sooner
  with the faster Maw.
- The Monk's timings were squeezed (Flash Kick's Hold took 0.33 s, Palm
  Strike's 3 taps 0.59 s): his combo playhead now runs at half speed
  (`Combatant.playhead_speed`), so a 5 AP move lasts as long as a 10 AP
  move does for everyone else. Bigger blocks too: at least 60 px while
  building and 96 px while playing for the smallest move.

## Punch and Kick without timing

- The Monk's Punch and Kick no longer have a timed hit: every hit lands by
  itself and presses during them are ignored. His heavy moves, Headbutt and
  all his Arts keep their timings.

## Skipped timings are free

- Skipping a timed hit (not pressing) no longer costs max AP; it's just a
  normal hit (`skipped_hit_max_ap_loss` 5 -> 0). A wrong press still ends
  the combo and resets max AP.

## Agility during a Hold; minimum window undone

- Agility's extra arrow on a Hold move (Power Draw, Piercing Arrow,
  Stunning Arrow, Gale Shot) asked for a press in the middle of the Hold.
  It now flies by itself; on Press moves it's still a press.
- The "75 ms minimum timing window" is undone: windows are in seconds, not
  a share of the move, so the Monk's Punch and Kick already had 120 ms, and
  the change had raised them to 250 ms. Back to 120 ms. Every class's
  playhead moves at the same 15 AP per second; the Monk feels faster
  because Punch and Kick are 5 AP, a press every third of a second.

## Monk's bar while building

- Punch and Kick overlapped while building a combo (about 35 px each): the
  build bar now widens for classes with small moves, so the smallest is at
  least 48 px. Captions under the bar (HOLD, LET GO, TAP) skip themselves
  if they'd print over the previous one.

## One reveal per new Art

- Playing a hidden Art twice in one bar used to show "NEW ART!" twice. Now
  the first one reveals it; the second just forms, with its name popping up
  like any known Art.

## Archer toned down

The same playtest had the Archer at about twice everyone's damage per turn
(82-147, against 19-110). Her moves alone weren't the cause; speed, reach,
a bigger bar and Piercing Arrow stacked up.

- Speed 13 -> 12; combo limit 70 -> 60.
- Triple Shot 1.1 + 1.1 + 1.8 -> 1.0 + 1.0 + 1.6; Double Shot 1.25 x2 ->
  1.15 x2 (keeps four Shoots as good as two Double Shots).
- Piercing Arrow: full damage to the first enemy, 75% to the rest.
- Agility 70 -> 60 AP (an Ability can't cost more than the combo limit).

## Stagger, toned down after a full playtest

- A playtest run (all 13 rounds won first try) showed Stagger locking
  bosses out of their turns: the Dragon died without acting (2 Staggers),
  the Gale Maw acted 3 times in 3 minutes and dealt no damage.
- A Stagger now knocks the enemy back to 25 before the casting zone,
  instead of to the start of the timeline: it loses the skill, not a lap.
- **Stagger resistance:** each Stagger makes that enemy's bars 50% bigger
  (of their base size) for the rest of the fight.

## Art hints and a bigger combo bar while playing

- **Partial hints for hidden Arts:** when a bar you play gets at least 2
  moves of a hidden Art's recipe right, in the right places (3+ move Arts),
  the Arts list shows them under the hidden count, never the name:
  "??? Thrust + Thrust + ?  (2 of 3)". Hints add up across bars and are
  saved with the discovered Arts; a flash says "Close to a hidden Art".
- **Zoomed combo bar while playing:** small blocks (the Monk's 5 AP Punch
  and Kick) zoom in so the smallest block is about 72 px wide; a long bar
  scrolls with the playhead (kept a third of the way in), with arrows at
  the edges. Classes whose blocks are already big enough look the same.
- **Bigger timing boxes:** at least 14 px wide on the bar. The time you
  have to press doesn't change.

## Arts inherit their moves

- Every Art now takes on the on-hit effects of the moves it's made of
  (`Moves._inherit`): the strongest effect wins (Break over Pierce), numbers
  take the larger value (halt, expose, burn, knockback, rally, front
  bonus), flags add up (stun, draws aggro, chill, Stab marks), and a
  barrier comes along (with its Perfect when the Art has the same timing).
  Shape, reach, timing and class mechanics stay the Art's own.
- What changed:
  - Knight: Shield Wall halts 0.5 s; Smash ignores Defense; Crusader's Edge
    halts 0.5 s.
  - Archer: Stunning Arrow and Arrow Rain expose (+15% damage taken).
  - Mage: Fireball, Steam Burst, Firestorm and Meteor Strike burn; Steam
    Burst and Meteor Strike chill; Meteor Strike pushes 3 m.
  - Cleric: Smite, Blessed Strike and Divine Judgment rally (+5 max AP);
    Blessed Strike also gives a 10% barrier within 4 m (Perfect 15%,
    5.5 m).
  - Assassin: Ambush, Cutthroat and Thousand Cuts add Stab marks; Ambush,
    Phantom Rush and Thousand Cuts get Shadowstep's 1.5x from the front.
  - Monk: Knee Smash, Triple Rush and Mountain Crusher break Defense;
    Mountain Crusher and Tortoise Special stun.

## Stagger

- **Stagger bars** on unavoidable skills (Power Shot, Fireball, Curse, Dark
  Bolt, Breath, Burning Spike, and the Gale Maw's Inhale, Exhale, Undertow
  and Gale Burst). Damage dealt head-on while the enemy prepares fills it;
  Smash-type moves, breaking moves and Arts count 1.5x. A full bar
  **Staggers** it: the skill breaks, the enemy goes back to the start of the
  timeline and takes +25% damage until its next turn. The Maw's Exhale
  turns into Broken Exhale instead (a ring with a safe middle by the Maw).
- Healing Ritual and Shadowflare show their own rules (3 close hits; the
  damage that contains it) as the same bar.
- Gold bar under the enemy's HP and on its timeline marker; answer tags
  STAGGERS, STAGGER +N%, NOT HEAD-ON; "Heavy" line in the move details; a
  new tutorial note.
- Parry's timeline push is now called **knocked back**.
- Tuning: the first bars (40 to 200) filled only 0-20% before the skill
  landed in bot fights, because the party gets about half a turn while an
  enemy crosses the casting zone. Skills with a bar now cast at half speed
  there, and bars are smaller (30 to 120). With a bot that steps in front
  of casters, it breaks about half of them. Living Armor went from mostly
  lost to won (2 of 2), and the Gale Maw from ~450 HP left to 39-74 HP
  left. The Dragon is still lost in every bot fight, with or without
  Stagger.

## The Gale Maw gets meaner

Six additions, each measured alone with the bot (standard party, 3 seeds,
the bot always catches edge saves). Without them the bot wins or nearly
wins every fight (Maw at 0 to 52 HP).

- **Gust Sprites** (biggest effect): every 4th action the Maw spits out
  up to 2 sprites (60 HP, a 2.2 m gust that knocks back 2 m). They go
  down with the Maw. Alone, they left the Maw at ~480-510 HP in all 3 fights.
- **Stronger Undertow**: the lines run 3.5 m past each target, so standing
  behind an ally means a double hit, and an Off-Balance fighter gets two
  lines. Alone: 2 wins, 1 timeout at 155.
- **Gale Burst**: Exhale, then Gale Lanes 1 s later. Alone: 2 wins, 1
  timeout at 200.
- **Breakable rocks**: Exhale, Gale Burst and Breaker crack rocks in their
  area; 2 cracks shatter one, and it grows back after 3 of the Maw's
  actions. Alone: 3 wins, but the most damage taken (up to 464, 2-3 down).
- **Winded**: anyone the Maw pushes or pulls loses 12 on the timeline.
  Alone: 2 wins, 1 timeout at 45.
- **The cliff crumbles** at half HP: the south edge breaks away 2.5 m
  (once); anyone on that strip teeters. Alone: 2 wins, 1 timeout at 86.
- All six together: the Maw survives every bot fight with 365-786 HP left,
  so it's toned down to **1 sprite every 4th action** (if none is up).
  Bot fights then end with the Maw at 308-380 HP (standard party) and
  500-687 (Monk, Knight, Cleric); 2 sprites every 5th action was
  harsher (519-769).
- Testing: `BattleArena.maw_off` (env `MAW_OFF` in the soak bot) switches
  features off for comparisons.

## The Gale Maw, a wall boss

- **New boss: the Gale Maw** (Round 11, after the Dragon, on the new Cliff
  arena). A stone face set into the north wall: it never moves, has no
  front or back, and every attack pushes or pulls. Inhale drags you toward
  its mouth, Exhale blows you toward the drop behind you; Maw Bite, Deep
  Breath, Gale Lanes, Breaker, Wall Sweep and Undertow move the safe spot
  around. Rocks between you and the wall shelter you. 1,200 HP; Maw Bite
  80, Breaker 52, Gale Lanes 40, Wall Sweep 46 (tuned up after bot fights
  showed it far easier than the Dragon).
- **Defend braces against pushes and pulls:** for classes that can Block
  (or a guarding Knight covers), the move is half as long, even when the
  damage can't be blocked. Works against every boss (the Living Armor's
  throw too).
- **Edge saves now come back:** the Parry save works when you're pushed or
  pulled over a drop, not only when you walk off. A caught save leaves you
  Off-Balance for 3 of your turns (going over again then is a fall); after
  that you can save again. Several fighters pushed over at once each get
  their save in turn.
- Wall boss support: anchored enemies, strip and lane areas (BAND), pushes
  and pulls straight across the arena, follow-up skills after any strike.
- Rounds: the mixed boss rounds are now 12 and 13.

## Enemy review

- **Kobold Power Shot** 58 -> 46: still the hit to answer, no longer bigger
  than a boss's.
- **Orc Shaman Healing Ritual** heals at most 60 HP per ally (15% of a
  boss was 135).
- **Bandit Arcanist Wind Slash** throws whoever it hits 3 m (not on a Parry).
- **Stone Golem** gains Stone Guard (Defense stance, lets 30% through);
  Smash + Ceiling Burst casts at 80% like the plain Smash.
- **Living Armor** gains Parry Stance (Counter stance).
- **Rounds:** new Round 7 introduces the Monk (Monk + Cleric vs Goblin +
  Ogre, with a tip). Solo bosses now come first (Golem, Living Armor,
  Dragon), then the two mixed rounds, then the Special Match. Golem + Kobold
  + Ogre moves to the Rock Field. Old saves past Round 6 continue at the
  round with the same number, which is now a different fight.
- **Roster fixed** to match the game: Power Shot, Curse and Dark Bolt are
  unavoidable (no Parry, no Defend). A Stagger bar will answer them later.

## Ceiling Burst keeps off the Golem

- Falling-rock circles no longer land on the Golem or other enemies, so a
  rock can't shove the Golem aside. If it walks into one of its own circles,
  that circle still hits but leaves no rock under it. Only party members are
  pushed out from under a fallen rock.

## Answer tags

- While picking moves, the ones that answer what the enemy is doing glow:
  green for INTERRUPTS, PIERCES, BREAKS GUARD, STUNS, HALTS, FROM BEHIND;
  red for BLOCKED, COUNTERED, MISSES. Arts in the Arts panel too.
- Abilities glow when they answer a strike coming at you (Riposte and
  Suplex: COUNTERS IT; Brace, Arcane Barrier, Vanish), an enemy preparing
  an attack (Hook) or one aimed at an ally (Taunt, Provoke).
- The details box explains the tag in a "NOW:" line. The skill-triangle
  tutorial lesson mentions the tags.

## Move details box

- While choosing moves or Abilities, a box beside the list explains the
  highlighted one: cost, timing and every effect in plain words. The Arts
  panel's Tab details show the same list.
- Toggle it in the pause menu (Move details: On/Off); the choice is saved.

## Class review: the Monk

- **Climb Arts hit harder,** so his steady damage tops the Knight's: Knee
  Smash 2.2 -> 2.5, Triple Rush 3.8 -> 4.4, Mountain Crusher 5.7 -> 6.3.
- **Palm Strike and Flash Kick** 0.9 -> 1.0, now above their parts like
  every other Art.

## Class review: the Assassin

- **Twin Fangs** 1.25 -> 1.1 per hit: still his best cheap Art, no longer
  above his finisher.
- **Execute** gains 15% per Mark it spends (4 Marks: 6.4x from behind,
  5 Marks: 7.0x), so the Mark build-up pays off.
- **Backstab** costs 25 (was 35); Cutthroat drops to 35.
- **Phantom Rush** now hits 1.5x from behind, like Ambush.
- Auto-parry keeps growing max AP: Marks are his Parry.

## Class review: the Cleric

- **Bash flurry:** each Bash in a row hits 0.1 harder (0.5 up to 0.9),
  still 10 AP each and still raising max AP. Six Bashes deal 4.4.
- **Sanctuary** hits 2.4 (was 1.5) and gives a 20% barrier within 6 m
  (Perfect 28% within 7.5 m); it used to be worse than two Divine Barriers.
- **Shielding** gives 15% (was 30%), so her barriers have a reason to exist.
- **Haste** costs 40 (was 50): the ally's turns come 25% sooner and they run
  20% faster, for 2 of their turns.
- The tutorial's Cleric lesson no longer describes the old escalating Bash.

## Playtest feedback: flavour on single moves

- **Fire burns:** enemies it hits take 35% of the Mage's attack each time
  they act, for their next 2 actions.
- **Arcane Surge** (new Mage move, 25 AP): a single-target open Tap. Every
  tap adds 10% damage, up to 10; extra taps are fine.
- **Exposing Shot** replaces Pinning Shot: the enemy takes +15% damage from
  everyone until its next turn. Only Arrow Rain pins now. Stunning Arrow
  and Arrow Rain keep their recipes with Exposing Shot in place of Pinning
  Shot.

## Class review: the Mage

- **Meteor Strike** 4.8 -> 6.0: the 75 AP finisher now clearly beats
  playing the same spells as smaller Arts.
- **Steam Burst** 2.8 -> 3.4 on a smaller circle (1.2 m): her focused spell
  for bosses and Defense.
- **Arcane Barrier** costs 30 (was 20) and no longer doubles her next combo.
- **Tempest** pushes 5 m (was 7), so a group near the middle survives it.
- **Teleport** costs 30 (was 60): a spot within 8 m, or Tab to appear next
  to any ally.

## Class review: the Archer

- **Agility's** extra hit deals half of the move's first hit (it used to
  copy it, doubling every single-hit move for 5 turns).
- **One rule for turn control:** an enemy can be halted or stunned once per
  action of its own. Stunning Arrow and Crusader's Edge now cancel the attack
  and drop the enemy to just before the casting zone, not to the start.
- **Power Draw** 1.4 -> 1.8, so the Hold is worth playing alone. Its Arts
  went up to stay ahead of their parts: Piercing Arrow 3.0 -> 3.3, Stunning
  Arrow 2.6 -> 3.1, Gale Shot 3.4 -> 4.2.
- **Arrow Rain** 1.4 + 1.4 + 2.2 -> 1.6 + 1.6 + 2.6.
- **Riposte** costs 25 (was 40), and the Archer hops 3 m back after
  countering.
- **True Sight** costs 40 (was 50) and also reveals enemy attacks as soon as
  they start preparing.

## Class review: the Knight

- **Shield blows halt instead of pushing back.** Guard Strike stops the
  enemy's timeline for 0.5 s, Shield Rush for 1 s. It keeps its place and
  its cast, and it can only be halted once per action of its own, so a
  string of shield blows can't stall it forever.
- **Shield Wall** (new Art, Guard Strike + Guard Strike, 30 AP): a 3 m sweep
  around the Knight that draws the aggro of every enemy it hits and gives
  nearby allies a 10% barrier. Their first area move.
- **Less damage, still able to fight alone:** attack 18 -> 15; Thrust
  1.1 -> 1.4 so their Defense answer stays worth using.
- **Smash** no longer breaks Defense; it knocks the enemy 4 m back instead.
  Thrust and Lunge are their way through Defense.
- **Brace** lasts 2 Knight turns (was 3).

## Bash rallies, the Knight draws aggro

- **Cleric's Bash** is now a flat 10 AP, low-damage hit (0.5) that grows the
  party's max AP: +5 per Bash that lands (+10 with a Perfect), up to the
  usual ceiling. The 10/20/30 escalating chain is gone.
- **Knight's shield blows draw aggro:** Guard Strike, Shield Rush and
  Crusader's Edge make the enemy target them for one of their turns; each more
  one adds a turn, up to 3. Taunt stays the area option.

## Monk, round 2: seeing the climb, and choices

- **Any climb Art climbs one step** (Knee Smash, Triple Rush, Mountain
  Crusher), so he picks the one that fits the turn.
- **Shorter recipes:** Triple Rush = Palm Strike + Knee Smash (35 AP);
  Mountain Crusher = Heavy Punch + Flash Kick + Knee Smash (55 AP), and a
  Perfect one gives Triple. Bigger climb Arts hit harder per AP.
- **Crowd Cheer** from any all-Perfect climb Art at the top.
- **Visible climb:** pips over the Monk on his turn and beside his timeline
  icon, step notches past the bar's end, a preview of what the Art uses and
  gives (Perfect part struck out once lost), and a STEP banner.
- HUD: party effect tags moved under the HP bars, inside the panel.
- The fresh bar after a Headbutt (or Tortoise Special) waits for the same
  1 s "READY" lead-in a combo starts with.
- The game now opens at **1600x900** (was Godot's default 1152x648): the
  same text sizes with more room for the field and the menus.
- **Tutorial: the Monk** (lesson 12, before free practice): climb a step
  with Knee Smash, tokens and the preview, climb to bar 100, cash out with
  Tortoise Special, and a note on his risks and tanking (and why the Knight
  is still the better tank). The Arts list step mentions the details box.
- **Bigger battle UI** to use that room: larger text and panels for the
  command menu, move list, Arts panel, target prompt and HP panels.
- **Art details:** Tab into the Arts list and the chosen Art shows a box
  above the panel with its recipe, AP cost, timing and full description.
  The Arts panel now grows upward from the move list's bottom, so it never
  covers the combo bar.

## Monk rework: build, then cash out

- The Monk pays from **party AP**; only his bar length is his own, climbing
  in steps 30 / 50 / 80 / 100 (no private pool, no refill).
- **Tortoise Special** needs Crowd Cheer and spends the whole climb: 1.5x at
  bar 80, 2.5x at 100, then back to 30.
- **Three outcomes** per Art: all Perfect = step + tokens; sloppy = step
  only; a miss = nothing and a lost step.
- **Mistakes cost a step** (a miss, an avoidable hit, an early Parry) and
  the newest token, Crowd Cheer last. Deep Breath gives the step back.
- **Tanking feeds the climb:** a Parry while Provoking gives Rush, a Suplex
  counter gives Mountain.
- The fresh bar after a Headbutt is paid from party AP. The hit chain is cut.
- **The Knight stays the better tank:** Taunt costs 40 (was 60) and makes
  them guard allies within 3 m (they share the Knight's Block and Parry). The Monk
  drops to 160 HP, Provoke costs 20 and lasts 1 turn, and Deep Breath no
  longer cuts damage.

## The Monk (sixth class)

- A combo class with **its own AP pool**: max AP starts at 30 and grows by
  finishing Arts (up to 100), refilled every turn, reset only by a
  knockout. Tortoise Special with Crowd Cheer hits 2x.
- **Token ladder:** Palm Strike, Flash Kick, Knee Smash, Triple Rush,
  Mountain Crusher and Tortoise Special build on each other; bigger Arts
  contain the smaller ones and use up the tokens they leave (+10% damage per
  token). First use of "Arts inside Arts".
- **Hit chain:** +5% per Perfect in a row (up to +50%).
- **Headbutt** restarts the combo bar (a fresh bar, once per combo).
- The combo bar is capped at the move list's width. Before a Headbutt, the
  bar folds into a "+70 AP" tag; during a Monk combo, blocks used up by a
  buff-giving Art leave the bar. The move list sits above the bar however
  many moves a class has; long Arts recipes shrink or shorten to fit.
- Punch and Kick have **one timed hit** each (new `timed` field); heavy
  punches are Taps, heavy kicks Holds.
- Abilities: Provoke (single-target taunt; Parries grow its max AP),
  Suplex (counter stance), Deep Breath (heal + 25% less damage).
- Available in the party picker before boss rounds. Not in the tutorial yet.
- Fix: Arts picked from the Arts list now still form (and reveal) bigger
  Arts that contain them whole; a picked Art is still never cut in half.
- Arena skulls: smaller; they circle the holes and drift along lethal edges.

## Drops: lethal holes and edges, knockback and pulls

- Arenas can have **holes** and **lethal edges**, marked by a glowing red
  death wall lined with skulls. Being knocked, launched, pushed or pulled
  over one means falling out of the fight. Regular enemies can be knocked in
  too (bosses can't).
- Walking into a drop pauses on a Parry-like **save ring**: catch yourself in
  time or fall. One save per character per fight.
- Enemy skills get `pull` (drag those hit towards the enemy); push and pull
  skills show red arrows on their area. Pulls drag into fire and holes alike.
- New **Platform** arena (east edge lethal, two holes, a rock), used by
  Round 5. The tutorial's notes gain a "Drops" page.

## Versions: 0.1.0, the first public build

- `application/config/version` (0.1.0) is the one place to bump; it shows
  in the title screen's corner and in every play-test report (and a
  `version` column in playtests.csv). The Windows export carries it too.
- `docs/RELEASES.md` holds short notes for each release.
- The Linux export preset is back (embedded .pck, x86_64), so each release
  can ship a `linux.tar.gz` next to the Windows zip.

## Tutorial, combo bar and parry feedback

- **Tutorial:** each class lesson now features only that class (Archer,
  Mage, Cleric alone; the Mage and Cleric lessons are split into their own
  notes); Max AP and Rocks go back to the Knight alone; the Assassin lesson
  has only the Knight (whose Taunt keeps the Golem's back turned) and the
  Assassin. Free practice brings the Knight, Archer, Mage and Cleric together,
  and that's where switching who you steer is explained. Party members step
  out between lessons instead of piling up.
- Tutorial text says Abilities (not skills) for the party's special actions.
- **Combo bar:** the playhead always crosses the whole block, even when the
  last hit lands early (Hold moves at 85%, the Assassin's random hits); it
  used to jump to the next block. And it moves at one speed for every move
  (`playhead_ap_per_second`, 15 AP of bar per second): a block lasts as long
  as it is wide.
- **Bash costs more in a row:** each Bash in a row adds a hit and costs 10 AP
  more (10, 20, 30), so a chain can't grow forever; three fill the Cleric's
  bar. Each hit loses 10% per earlier Bash (was 25%). The list shows what the
  next Bash would cost. Divine Judgment's recipe is now Bash, Holy Light,
  Bash, Divine Barrier, so it still fits the bar before you've found it.
- **Parry:** pressing too early shows MISS over the fighter's head at once.
- Fix: choosing Attack after the only enemy in reach moved away (while the
  menu was open) crashed opening the combo bar; now it says so and goes back.

## Tutorial panel out of the way of the Arts list

- While the combo bar (or any turn menu after the commands) is open, the
  tutorial panel shrinks to its title and goal, so it no longer covers the
  move list and the Arts panel.
- The Arts panel's "Hidden: ..." line wraps instead of running off the edge.

## Fix: areas flickering over the pit

- The pit's surface sat at the same height as enemy areas (3 cm), so where
  a cone or line crossed it they z-fought (jagged black spikes). The pit is
  now a thin disc just above the floor, under every area.

## New boss skills: Golem Smash, Ceiling Burst, Doom Gaze

- **Stone Golem: Right / Left Golem Smash.** Half the room, out to the
  arena's edges; the Golem can't turn while casting it, so whoever it faced
  steps out. Dodge only.
- **Stone Golem: Ceiling Burst.** 10 circles fall one by one, 0.5 s apart,
  in a random order (one near each party member); each leaves a rock that
  blocks the way for ~10 s.
- **Stone Golem: Smash + Ceiling Burst.** The circles fall only on the safe
  half, then the smash lands.
- **Living Armor: Doom Gaze.** A slow, arena-wide instant-death circle full
  of skulls. A rock crashes down at a compass point when the cast starts:
  hide behind it. AI allies run behind it too.
- New skill fields: `aim_offset_degrees`, `locks_facing`, `fills_arena`
  (areas drawn and reaching up to the arena's edges), `ceiling_*`,
  `lethal`, `cover_rock*`. AI allies step out of half-room cones towards
  their back edge, and avoid circles about to fall.

## Tutorial: Arts lesson

- Lesson 3 gains an Arts note and two goals: play Slash + Slash (the first
  NEW ART! moment, on purpose instead of by luck), then add an Art from the
  list with Tab and play it. The Combos goal's text no longer explains Arts.
- Reports count `arts_picked` (Arts added from the list).

## After a full Boss Rush play-test

- **Finisher hint:** the Arts panel now counts hidden Arts by recipe length
  ("Hidden: 2 two-move, 1 four-move"), so the four-move finishers are known
  to exist without giving away their recipe. No finisher was found in the
  full run.
- **Fire reaches 4.5 m** (and Fireball with it). The Mage dealt 41 damage in
  4 turns in Round 10 after Meteor Strike stopped reaching anyone; the Archer
  still has the longest reach (6 m).
- **The Dragon closes in:** while none of its aimed skills (Breath, Fire
  Wave) reaches anyone, it walks 2.5x faster (`closes_in`,
  `close_in_speed`). Kiting it had left it casting Burning Spike 4 times in
  a row; bot runs now see Breath, Fire Wave and Burning Spike mixed.
- Play-test reports: "Where the party's damage came from" is now "Damage
  taken, by source", and left out when nothing got through.

## Multi-hit strikes: every hit can be Parried

- Fix: a Parry used to end a multi-hit strike, so the later rings never
  got their chance. Now the chain goes on and each hit is parried in its
  own window. Every Parry grows max AP; the enemy is staggered once per
  strike (not once per hit).

## Assassin Arts (every class now has Arts)

- Five secret Arts from Stab, Shadowstep and Backstab: Twin Fangs, Ambush,
  Phantom Rush, Cutthroat and the finisher **Thousand Cuts** (teleport
  behind, six cuts, +2 Marks). Execute stays its own move.
- Multi-hit Assassin Arts keep random timings: one hit per stretch of the
  block, so the boxes never overlap.
- New `last_hit` field for changes on a move's last hit only (Triple Shot's
  piercing arrow uses it too), and `add_marks`.

## Cleric Arts

- Holy Light 30 -> 20 AP (1.4x -> 1.2x) and Divine Barrier 25 -> 20 AP, so
  the four-move finisher fits the 60 AP bar.
- Five secret Arts: Smite, Judgment, Blessed Strike (heals allies near the
  Cleric, more on a Perfect), Sanctuary (big barrier) and the finisher
  **Divine Judgment** (heals the whole party 15% and shields everyone 10%).
- Bash chains stay Bash: no Art is Bash + Bash alone.
- Barriers (and the new Art heals) now come with a move's last hit instead
  of its first; the same for single-hit moves like Divine Barrier.

## Mage Arts (three elements)

- The Mage's list is now Fire (Tap 4, line), Frost (Tap 3, small circle,
  **chills**: half walking speed until its next turn) and Gust (circle on
  self, pushes 3 m).
- Six secret Arts from mixing them: Fireball, Blizzard (chills a group),
  Steam Burst (breaks Defense), Firestorm, Tempest (now an Art, pushes 7 m)
  and the finisher **Meteor Strike** (Fire, Frost, Fire, Gust: 75 AP, 4.8x
  to every enemy). Meteor is no longer a 90 AP move you can pick from the
  start, and the Mage loses its "reach anyone" option until it's built.

## Archer Arts

- The Archer's list is now three basics: Shoot, **Power Draw** (Hold, 20 AP)
  and **Pinning Shot** (15 AP: the enemy can't walk until its next turn).
- Six Arts, secret until found like the Knight's: Double Shot, Triple Shot,
  Piercing Arrow (Hold, goes through a whole line), Stunning Arrow and Gale
  Shot (now built, still Hold), and the finisher **Arrow Rain** (three volleys
  on a circle that break Defense and pin everyone hit).
- Numbers nudged from the first plan so every Art beats its parts: Piercing
  Arrow 3.0, Stunning Arrow 2.6, Arrow Rain 1.4 + 1.4 + 2.2.
- **Triple Shot reworked:** it was weaker than Double Shot + Shoot (3.1 vs
  3.5), and three Shoots always merge into it. Now 1.1 + 1.1 + 1.8 = 4.0,
  and the delayed last arrow ignores Defense.
- The Arts panel's "next:" hint (all classes) only shows when adding that
  move really would end the bar on that Art: after a merged Double Shot it
  no longer suggests another Shoot for Double Shot.

## Arts stay secret until found (Legend of Legaia style)

- Undiscovered Arts no longer show anywhere: no "???" rows, no recipe hints,
  and they don't merge while you build. The Arts panel lists the Arts you've
  found plus how many are still hidden.
- **Discovery happens mid-combo:** when the playhead reaches moves that spell
  a hidden Art, their blocks merge with a flash, the combo pauses on a
  **NEW ART!** banner with the Art's name, and then the Art plays. From then
  on it merges on the bar and can be picked from the list.
- This works even when a hidden Art contains one you already know (Crusader's
  Edge starts with Double Slash).
- **Forget Arts** on the title screen (shown once any Art is found; press
  twice to confirm) hides every discovered Art again, to replay the reveals
  or hand the game to a friend.

## Arts list picking; one Ability per turn

- **Tab in the combo bar opens the Arts list:** pick any known Art and its
  whole recipe goes on the bar at once, as that Art (moves before it can't
  steal part of it). Building it move by move still works and merges the
  same way.
- **Abilities no longer end the turn.** One Ability per turn: after it, the
  command menu comes back with Abilities greyed out, and you can still
  Attack or Wait. Shield Bash's sooner next turn still applies.

## Arts: the combo bar becomes a combo system (Knight first)

- The Knight's menu now has three **basic moves**: Slash, Thrust (15 AP,
  pierces) and the new Guard Strike (pushes the enemy back on the timeline).
- In the right order they merge into **Arts**: Double Slash (Slash, Slash),
  Lunge (Slash, Thrust), Shield Rush (Guard Strike, Slash), Smash (Thrust,
  Thrust, Slash) and the finisher Crusader's Edge (Slash, Slash, Thrust,
  Guard Strike). An Art costs what its moves cost but hits 25-50% harder,
  and longer ones add effects (pierce, break, delay, stun, knockback). The
  bar takes the longest recipe it can, and splits back if you remove a move.
- **Discovery:** an **Arts panel** beside the move list shows known recipes;
  unknown ones read "???" with only the first move, and the panel says which
  move comes next for any Art you're on the way to. Performing one the first
  time pops "NEW ART" and reveals it for good (`user://arts.cfg`).
- The tutorial's combo lesson explains Arts. Other classes keep their
  current moves for now.

## Cleric: Divine Barrier is a Hold move

- **Divine Barrier** now uses Hold and Release (1.5 s, the same feel as the
  Archer's Hold moves). A Perfect let-go gives a **bigger barrier**: 15% of
  max HP instead of 10%, to allies within 5.5 m instead of 4 m. Missing the
  timing still gives the normal barrier. The combo preview shows the normal
  circle plus a faint outer ring for the Perfect reach.
- Every class now has its own timing flavour: Knight presses, Archer and
  Cleric hold, Mage taps, Assassin reacts to random timings.

## Max AP capped at 500

- Max AP still grows to 100 per party member plus 100 (200 solo, 300 for
  two, 400 for three, 500 for four), but now never past **500**, so parties
  of five or six stop at 500 too (they would have reached 600 / 700).
  `max_ap_limit` sets the cap, and `max_ap_limit_bonus` is ready for skills
  or items that raise it later.

## HP panels fit up to six

- The party and enemy HP panels now stack up from the bottom and have room
  for six rows, so the tutorial's five-member party (and any party of 4 to
  6) sits neatly above the AP meter instead of running off the bottom.
- The AP meter never grows wider than the gap between the two panels, so a
  big party's longer meter no longer runs into the enemy names.

## Fixes and timing tweaks

- **Quit to title no longer crashes** (pause menu, and Esc on the party
  picker): the menu marked the key as handled after the scene had already
  changed, when it no longer had a viewport.
- **Tutorial lesson 9 (Rocks) can't get stuck any more.** Using the Knight's
  own Taunt there replaced the lesson's Taunt with a 3-turn one; when it ran
  out, the Golem aimed its Long Strike at someone else and the goal could
  never be met. The lesson now keeps the Golem on the Knight, and re-shows
  Long Strike if the cast is lost.
- **Enemy areas and the party's gold reach rings hide while a strike's
  rings close in** (Parry / Defend moments), so the strike's rings are the
  only thing to read; they come back right after. Unavoidable strikes keep
  their areas.
- **Tap moves: one tap too many is a miss** (chain ends, AP to 0, max AP
  resets), like a wrong press. Taps before the stretch are still ignored.
- **Slower Assassin combos:** Stab 0.8 s (was 0.55), Shadowstep 1.1 s
  (0.8), Backstab 1.2 s (0.9), Execute 1.6 s (1.2), with slightly wider
  boxes, since its random timings need a moment to spot.
- **Slower Hold moves:** Stunning Arrow 1.5 s (was 0.9), Gale Shot 1.8 s
  (was 1.2), slightly wider boxes, and the arrow flies at 85% of the block,
  so there's a moment after letting go before the next move's timing.

## Tutorial wording: the fight doesn't wait

- Lesson 1 said enemies "move at the same time", which could read as if
  they only move when you do. It now says the fight keeps going (enemies
  walk, the timeline runs) whether you move or stand still.

## Positional rings (after Final Fantasy XIV)

- The "behind" wedge became a **ring under each enemy** while you steer the
  Assassin (`scripts/battle/positional_ring.gd`): an arrow at its front, a
  thin white arc round the front and sides, and a thick violet **rear arc**
  (60° either side of its back) that glows while the Assassin stands in it.
- **No positionals:** Goblin Fighters and Kobold Archers get a plain full
  violet ring instead. Every hit on them counts as "from behind" from any
  side (Backstab always lands, Shadowstep's front bonus always applies).
  Bosses and the Ogre keep their positionals.
- Round 6's tip and the tutorial explain the rings; the tip is now split
  over three lines so it fits the screen.

## Assassin tutorial

- New tutorial lesson 11, **The Assassin**: it joins, the Golem is Taunted
  by the Knight (so its back stays open, as Taunt does in real fights), and
  the goals walk through hitting from behind, Shadowstep, putting 4 Marks
  on the Golem, Execute, and an auto-parry. Free practice is now lesson 12.
- **"Behind" wedge:** while you steer the Assassin, a faint violet wedge
  marks every enemy's back on the floor and glows when you stand in it.

## The Assassin, party picker, new Round 6

- **New class: the Assassin** (170 HP, 50 AP). It can't Block or Parry, but
  while any enemy carries an **Assassin's Mark** it auto-parries, spending
  a Mark. Attacks: Stab, Shadowstep, Backstab, Execute (all care about
  being behind the enemy; random timings, the opener always mid-to-late).
  Skills: Hook, Death Sentence, Shadow Cloak, Vanish. Details in
  `battle-design.md`. Timeline icon "As" (the Archer has "A", the Stone
  Golem "S").
- **New Round 6:** Assassin + Knight vs Ogre Warrior + Goblin Fighter in
  the square arena, with a tip on how the Assassin plays. The old Rounds
  6-10 are now 7-11; the Boss Rush has 12 fights. (An old save pointing at
  the old Round 6 now continues from this new one.)
- **Choose your party from Round 7** (the boss rounds): 1 to 4 of the five
  classes, solo allowed. Retrying keeps the pick; a new round asks again.
- Encounters can carry a start-of-fight **tip**.

## Timing types: colours and shapes

- Each timing type has its own look on the combo bar: **Press** = white
  square boxes (as before); **Hold** = blue rounded pills (a ▼ press pill,
  a blue tail that lights up while you hold, a ▲ let-go pill); **Tap** = a
  dashed pink stretch with one diamond per tap that fills as you tap.
- The move list shows a matching badge (blue HOLD pill, pink ◆ TAP 5) in
  place of "(Hold)" / "(Tap 5)" in the description; the HOLD / LET GO /
  TAP labels under the bar use the same colours.
- Move names on the bar are drawn on top of the timing marks so they stay
  readable.

## Hold and Tap timings

- **Hold and Release** (Archer: Stunning Arrow, Gale Shot): press in the
  first box, keep holding, let go in the last box for a Perfect. A bad
  let-go (or a late start) only loses the Perfect; the hit lands and no AP
  is lost. Pressing far too early is still a miss.
- **Tap X times** (Mage: Energy Blast 3, Firebolt 5, Meteor Strike 8): tap
  the key that many times before the hit. Each tap adds damage, all of them
  make a Perfect, and taps can never miss.
- The Mage's tap moves got a little longer so the taps fit (Energy Blast
  0.9 s, Firebolt 1.3 s, Meteor Strike 1.8 s), and Gale Shot 1.2 s.
- The combo bar shows HOLD / LET GO and TAP 3/5 under the boxes, the hint
  line explains the current move's timing, move descriptions say "(Hold)"
  or "(Tap 5)", and the tutorial mentions both when the Archer and Mage
  join. Reports count Perfects per type.

## Telling twins apart on the timeline

- Enemies that share a name ("Kobold Archer A" / "B") show their letter on
  a small badge on their timeline icon.
- Whoever you're aiming at (while choosing a target, building a combo or
  playing it) gets a pulsing gold ring and an arrow on the timeline, and
  that enemy's floating name turns gold. Anyone else the highlighted move
  would hit gets a thin gold ring on the timeline.

## Kobold bait timing

- When one Kobold readies a Power Shot and its partner a Ranged Attack,
  the Ranged Attack now waits: it lands **2.5 seconds after the Power Shot**
  (seconds you can move in; `bait_gap_seconds` on the battle). Hide behind
  a rock for the Power Shot, then run back in next to the Kobold.
- Until the Power Shot is done, the waiting attack's area stays grey and
  its label reads "RANGED ATTACK - NEXT"; then it lights up as usual.
- Works whichever of the two picked first (the Ranged Attack is the one
  that waits).

## Kobold team tactics (Round 2)

- A friend's play-test stalled on Round 2: both Kobolds kept a Counter up,
  so the Knight spent turns waiting and did no damage.
- **Only one Kobold uses Counter now** (the first one), and never while
  another enemy of its pair already holds a stance.
- **The pair baits you:** while one Kobold prepares a Power Shot, the other
  leans toward Ranged Attack (safe only right next to it), so running in to
  dodge it can leave you in the line of the Power Shot unless you use a
  rock. Two Power Shots at once are rare, and Power Shots are never more
  common than before, so the round doesn't get deadlier. The pair also fans
  out to about 8 m apart, so one spot can't be safe from both.
- Bot test fights (16 per version, a bot that never uses rocks): wins went
  from 4 to 5, Counter use halved, Power Shot damage about the same.
- Built as a general `team_tactics` flag on enemies (Combatant), so other
  enemy pairs can use it later. Round 4's single Kobold is unchanged.

## Attack area preview, Change Keys

- **Attack area preview:** while you browse moves and skills, the area the
  highlighted one would hit is drawn on the ground (a circle on the target,
  a circle around the attacker, or a line toward the target), with a ring
  under everyone it would hit (fainter where damage falls off). Divine
  Barrier shows its circle and the allies it would cover. The area is
  bright when the move can be used, dim when it can't. While building a
  combo the command panel hides, the move list goes see-through, and the
  camera centres between the attacker and the target so the preview isn't
  covered.
- **Change Keys** on the title screen: pick an action, press the new key.
  If another action already uses that key, the two swap. Each action keeps
  its extra keys (arrows, Enter, Backspace); Esc (pause) and O (reports
  folder) can't be taken. **Reset all keys to default** undoes everything.
  Keys are saved in `user://keybinds.cfg` and apply in every mode.
- Every on-screen hint (menus, strike prompts, the Controls page, the pause
  menu, the end-of-fight lines and the tutorial notes) now shows the keys
  you actually set.

## Boss Rush save and Continue

- **Auto-save in the Boss Rush:** every fight saves as it starts, and a win
  saves the next round; **Continue** on the title screen starts the saved
  fight over from its beginning. Beating the last round clears the save.
  Round Select and the tutorial don't save. (A Save button in the pause
  menu was tried first and replaced: auto-save is less confusing and
  survives closing the window.)
- Play-test reports now say how the fight was started (Boss Rush, continued
  from a save, or Round Select). The CSV is unchanged.

## Tutorial pass, pause menu

- **Esc pauses the fight** instead of quitting: Resume, Restart fight or
  Quit to title. Esc or K again resumes.
- **Tutorial brought up to date:** it now covers the camera, why Attack can
  be greyed out, the +30 AP per turn, the combo counter and cost preview,
  losing all AP on a missed timing or early Parry (it still said "half"),
  rings for multi-hit attacks and one Defend covering them, bosses needing
  three hits to interrupt, allies stacking and spreading, Concentrate on the
  meter, Bash's weaker repeats, max AP segments and the avoidable-hit
  warning. A reminder that **timed hits are optional**: skipping one is a
  normal hit, a wrong press ends the combo.
- **New lesson 10, Special skills:** UNAVOIDABLE skills (spread, stack,
  stand alone), lingering fire and spikes, growing circles, healing
  enemies, and the orange follow-up sphere. Free practice is now lesson 11.

## Concentrate on the AP meter, no prompt for unavoidable hits

- **Concentrate shows on the AP meter:** chevrons racing along the fill, a
  pulsing violet frame, and an "x2 AP" countdown above the bar.
- **Unavoidable hits don't prompt any more:** no timing ring and no
  Parry/Defend line (there was nothing to press). Everyone about to be hit
  gets a red mark, and the hit lands after a short beat (0.45 s).

## Balance pass 2 (from the second full play-test)

Results before this pass: every round won first try; party HP left was
Round 5 58%, 6 100%, 7 81%, 8 89%, 9 49% (one KO), 10 87%. The bosses' own
attacks rarely landed: the Golem's 7 turns dealt 0 damage (Rock Stomp missed
4 times out of 4) and the Living Armor's Combo missed 8 times out of 8, since
the party could easily stay out of their short melee range.
- **Stone Golem:** Rock Stomp reaches 4.5 m (was 2.6) and deals 32 (was 26),
  Heavy Attack 5 m (was 4.2), Crush 11 m long (was 8), walks faster (3.5,
  was 2.5).
- **Living Armor:** Combo reaches 4.5 m (was 3), walks faster (4, was 3).
- **Dragon Hatchling:** 960 HP (was 1080). Its fight ran 7.5 minutes;
  Burning Spike and Breath now hit harder anyway, since unavoidable skills
  can't be Defended any more (they were Defended 12 times that fight).
- **Enemy AI:** a skill that can't reach anyone is picked 4x less often
  (x0.05, was x0.2), so enemies stop wasting turns on melee nobody's in.

## Unavoidable means no Parry or Defend

- Unavoidable skills (Breath, Burning Spike, Dark Bolt, Curse, Fireball,
  Rock Spikes, Power Shot) can't be Parried, Defended or Riposted: they just
  deal their normal damage, and the strike prompt says so. Fireball no
  longer has its "Parry only if alone" rule.

## Shadowflare is dodgeable again

- **Shadowflare only hits those inside its circle** (full damage), like
  before the unavoidable pass. Rush in and deal 10% of the Living Armor's HP
  to stop it growing, then get out before it explodes; left alone it grows
  to 11 m and covers most of the arena. Being caught counts as an avoidable
  hit (max AP).

## Combo counter

- While a combo plays, a **combo counter** on the right of the screen shows
  the hit count (gold while every hit is Perfect), the running damage total,
  the number of Perfects, and each hit's damage popping in (gold for a
  Perfect). The final total stays up for a moment after the combo.

## Missed timings cost all AP

- Pressing J at the wrong moment in a combo, or parrying too early, now
  drops the party's AP to 0 (on top of max AP going back to 100). Before, a
  missed combo timing kept your AP and an early Parry halved it.

## Tracking, Power Shot, Ranged Attack

- **Unavoidable skills track properly:** Power Shot and Breath keep aiming
  exactly at their target until they fire, and unavoidable circles and lines
  (Fireball, Rock Spikes, Burning Spike, Dark Bolt, Curse) keep following
  their party member after the reveal, so what you see is what hits.
- **Power Shot** casts 40% slower (3.0 s in the casting zone, 1.3 s from
  reveal to strike) so there's time to get behind a rock, and deals 58
  instead of 46.
- **Kobold's Ranged Attack** reaches 12 m (was 6.5): the safe spot is right
  next to the Kobold. Allies now step into a ring's safe middle when it's
  closer than its outer edge.
- **Allies no longer run from a Healing Ritual** while it's still hidden
  (they treated its grey circle as an attack); they close in to interrupt it
  from the moment the Shaman starts casting.

## Multi-hit rings

- Multi-hit strikes show **one ring per hit still to come**, each closing in
  to land on its own beat, so the rhythm of a Combo is readable up front.
- **One Defend now guards the whole chain** (one 10 AP payment). Before,
  the Defend wore off after the first hit and you had to press Q again
  within half a second, paying again.
- Checked: timing (1.0 s, then 0.55 s per hit), damage per hit, Parry on a
  later hit stopping the rest, launch only on the last hit, max AP lost once
  per chain, and a target going down mid-chain.

## Unavoidable mechanics, max AP for avoidable hits, strike camera

- **Mechanic skills can't be dodged, only answered** (revealed with
  UNAVOIDABLE): Breath always hits its target (stack up), Burning Spike and
  Dark Bolt hit everyone (spread out), Curse hits everyone unless a rock
  blocks the line, Fireball and Rock Spikes always hit the marked one,
  Power Shot always hits its target unless a rock is in the way, and
  Shadowflare hits the whole party for damage scaled by how big it grew.
- **Avoidable hits cost max AP:** a dodgeable strike, or a mechanic answered
  wrong, that lands without a Parry or Defend costs one 100-AP segment of
  bonus max AP (once per strike). The segment at risk pulses red on the
  meter while anyone stands where it would happen. Fire and spikes don't
  count. Reports get an "Avoidable hits" column.
- **Bosses resist interrupts:** three Attack-type hits (or one breaking move)
  to stop a boss's Smash. The Golem was being locked down by single hits.
- **Camera:** when a strike catches someone off screen, the camera eases out
  until everyone hit is in view, then back.

## Bash and ally pushing

- **Bash has diminishing returns:** each Bash in a row still adds a hit, but
  every hit is 25% weaker per earlier Bash. Six Bashes deal 7.1x attack
  instead of 16.8x, while still giving 21 timed hits for Perfects and max AP.
- **Allies no longer shove the character you're steering** when they bump
  into you (they step aside instead).

## AP meter

- The plain AP bar is now a **segmented meter**: one segment per 100 AP,
  each tier in its own colour (blue, teal, gold, orange, rainbow), with dim
  slots showing how far max AP can still grow.
- **Feedback:** a flash and "+5" when max AP grows; the extra segments
  shatter with a red flash when a missed timing resets it; a dark "ghost"
  shows what the combo you're building will spend; the turn-start +30
  lights up as it fills; the fill flows faster as recharge speeds up.
- **Tier effects:** a passing shine from 200 max AP, a pulsing glow from
  300, embers from 400, and a cycling rainbow with a bigger gold number at
  the top.

## Balance pass 1 (from the first full play-test)

All ten rounds were cleared on the first try. Solo bosses were the weak
spot: they got 4-5 turns to the party's 20-24 and dealt 13-26 damage in
total (Rounds 6, 7, 10).
- **Bosses act about twice as often:** speed 20 (was 9-10), but half speed
  while casting (new `cast_zone_speed`), so reveals stay as readable as
  before. +20% HP: Stone Golem 960, Living Armor 900, Dragon 1080.
- **Breath tracks its target exactly** for the whole cast (new
  `tracks_target`): turning away at the last second no longer dodges it.
- **AP recharge boost capped at 2x** (`ap_regen_max_multiplier`), so max AP
  up to 500 means longer combos, not 5x recharge.

## Play-test feedback round

- **Attack greyed out** for the Mage (and anyone) when no attack that can
  reach an enemy is affordable. Meteor Strike reaches anyone, so Attack used
  to stay lit even at low AP.
- **Shout, then Sword Spin 2 s later:** the pushed are marked with orange
  spheres and always hit; anyone else has time to run into Sword Spin's
  safe middle. (Was: Sword Spin struck at once.)
- **Max AP limit** is 100 per party member plus 100 (200 solo, 500 with
  four). (Was: 200.)
- **+30 AP** at the start of each party turn, on top of what's there.
  (Was: topped up to 30.)
- **Dark Bolt** always hits everyone, for 18; spreading out avoids the
  double damage. (Was: 26, and stepping out of your circle dodged it.)
- **Shadowflare** casts 40% slower and can grow to 11 m. (Was: 9 m.)
- **Defeated enemies** sink away after 2 seconds, and knocked-out bodies no
  longer block anyone.
- **Breath** casts 40% slower (about 4 s through the casting zone instead
  of 2.4, 1.8 s from reveal to strike instead of 1.1), so the party has
  time to stack up.
- **Burning Spike** leaves each circle burning where it landed for 3 Dragon
  turns (8 HP/s), so where you drop them matters.

## Smarter allies, play-test reports

- **Allies understand the enemy mechanics:** they stack on the target of a
  shared-damage skill (Breath) instead of running from it, spread a full
  circle apart for overlap-punishing circles (Dark Bolt, Burning Spike),
  stop trying to outrun circles that follow them while hidden (they used to
  walk off sideways), close in on a Shaman's Healing Ritual so your hits can
  interrupt it, and focus a growing Shadowflare's caster.
- **Play-test reports:** every fight saves a report (Markdown) and a line in
  `playtests.csv` in the game's user data folder. O on the end screen opens
  the folder. Used for the coming balance pass.

## Full kits for the rest of the roster

- **Goblin Fighter:** Attack is 2 hits (13 each). Defend no longer blocks
  everything: 40% of a hit gets through (piercing and breaking moves still
  ignore it).
- **Bandit Arcanist:** Wind Slash stops at the first one it hits. New
  **Fireball**: a circle on its target (red sphere over their head) that
  hits everyone inside, and can only be Parried if the target is alone.
- **Ogre Warrior:** Attack is 2 hits (18 each). **Shield Bash** snaps to face
  its target when revealed, then holds that aim (step out of the line), and
  stops at the first one hit. New **Shout** pushes everyone near it out,
  then **Sword Spin** comes at once and hits everyone pushed. Sword Spin is
  no longer used on its own.
- **Stone Golem:** new **Rock Spikes**: a circle on its target, then 4 spikes
  that hurt anyone walking into them (16) for 2 Golem turns.
- Kobold Archer was already complete.
- Fire trails (and spikes) now stay behind even when the skill misses.

## Enemy AI pass

- **Full kits** for the three enemies that had a single skill:
  - Dragon Hatchling: Breath (shared damage), Fire Wave (leaves a fire
    trail for 3 turns), Burning Spike (circles on everyone; overlaps drop to
    1 HP).
  - Living Armor: Combo (3 hits, last one launches), Dark Bolt (circles on
    everyone; overlaps take double), Shadowflare (grows unless contained by
    damage).
  - Orc Shaman: Attack, Healing Ritual (heals allies; 3 close hits interrupt
    it), Curse (lines to everyone; overlaps take double, unblockable).
- **Telegraphs:** red spheres over heads mean spread out; inward arrows mean
  stack up.
- **Smarter skill choice** for every enemy: skips skills that can't reach
  anyone, uses spread punishers when the party is bunched, heals only when
  allies are hurt, raises Defense/Counter when someone is close, and avoids
  repeating itself.

## Strikes follow the timeline, shorter casting zone

- Enemies no longer strike early when someone stands in their revealed
  area: every strike lands exactly when the enemy's icon reaches the end of
  the bar. (With tracking, the old "touch it and it strikes" rule made
  enemies act ahead of the timeline.)
- The orange casting zone is 40% shorter: it starts at 73 (was 55), and
  skills are revealed at 88 (was 80). Casts last about 1.8–2.7 s.

## Combo target selection

- When more than one enemy is in reach, **Attack asks which one to hit**:
  W / S cycles (nearest first, marked with a gold ring), J confirms, K goes
  back. With a single choice it skips straight to the combo bar.
- The combo bar shows "Target: <enemy>" above it.

## Readable enemy casts

- The **casting zone** (orange) now starts at 55 instead of 75, and the
  **timeline runs 40% slower** (`time_scale` 3.0 -> 1.8), so a cast lasts
  about 3–4.5 s instead of ~1.3 s.
- An enemy's area **appears in grey the moment it starts casting**: you see
  where it will land, not what it is. Its color and name are revealed at 80
  (was 90).
- While casting, an enemy **locks onto** the nearest party member and tracks
  them at full turning speed, slowing down only in the last second, so
  running behind it no longer dodges everything.

## Menu order and Enter key

- The command menu is now Attack / Abilities / Wait / Items.
- **Enter** (and keypad Enter) works everywhere J does: menus, the combo bar
  and timed hits. **Backspace** works everywhere K does (back, remove the
  last move).

## Fix: Round Select fits the window

- Round Select shows as many rounds as fit and scrolls (W / S or the mouse
  wheel), with arrows when more are above or below. The Controls page
  shrinks its rows on short windows.
- Going back from a scrolled Round Select no longer leaves the main menu
  scrolled (it was hiding Boss Rush and Tutorial).

## Reaction reminders per class

- The command menu only shows the reaction keys the current class can use:
  Knight both, Mage "Parry: E", Cleric "Defend: Q", Archer neither.

## Fix: title screen error

- Choosing an option on the title screen raised a script error right after
  switching scenes (the menu marked the key press as handled after it had
  already left the scene). In the editor this paused the game, which looked
  like a crash. Fixed for Tutorial, Boss Rush and Round Select.

## Enemy balance pass

- Every roster enemy has **2.5x HP** and deals **1.3x damage** (rounded),
  including the Counter stance punish (25 -> 33). The Training Golem is
  unchanged. Example: Stone Golem 320 -> 800 HP, Crush 40 -> 52.

## Camera controls and control handback

- **Camera:** Z / C or right-drag rotates around the action (drag up and
  down to tilt), the mouse wheel zooms, V resets. WASD now moves relative
  to the camera, so W always heads away from the screen.
- **Control handback:** when an ally's turn ends, control returns to the
  party member you were steering before it, instead of staying on the ally.
- **Turn pans:** when anyone's turn comes up (ally or enemy), the camera
  glides over to them first and the turn begins once it arrives; afterwards
  it glides back to whoever you're steering. Tab switches glide too.

## Title screen and tutorial

- The game opens on a **title screen**: Boss Rush, Tutorial, Round Select,
  Controls, Quit. Esc goes back to it from a fight.
- A **guided tutorial** (from a friend's playtest feedback): one continuous
  fight against a Training Golem, 10 lessons covering every mechanic, the
  Knight first and the other classes joining along the way. Notes pause the
  fight, goals wait for you to do the thing, and nobody can fall.
- Battle additions for it: fighters can be held on the timeline, enemies can
  be made to prepare a specific skill, party members can join mid-fight, and
  the battle counts what the player does.

## Classes

- **Knight, Archer, Mage and Cleric** each have their own HP, AP, attacks and
  skills (Thiago's class sheet). All numbers are in `scripts/battle/moves.gd`.
- A class's AP is the length of its combo bar and the most it can spend in
  a turn; AP still comes from the shared party pool.
- **Abilities** menu: pick a skill, choose a target if it needs one (an
  ally, an enemy, or a spot for Jump), and the turn ends.
- New attack mechanics: area hits (circle on the target, line with falloff,
  circle on self, all enemies), per-move reach, knockback, stun, Bash's
  growing hits with random timing, delayed last hits, barriers.
- New effects: Brace, Taunt, True Sight, Agility, Haste, Arcane Barrier,
  Concentrate, Riposte, shields and barriers. Durations count the caster's
  turns.
- Block and Parry now depend on the class (the Archer can do neither).
- Targeting prefers enemies in normal reach; long-range moves cover the rest.

## Boss rush and arenas

- The battle scene now loads a **round** from `data/boss_rush.tres`: arena,
  party lineup and enemies. 11 rounds following Thiago's mockup; **N / P**
  change round, and after a win N goes to the next one.
- **Six arenas** (`scenes/arenas/`): square, circle with 3 rocks, long
  rectangle, circle around a pit, rectangle with 4 rocks, and a large arena.
  Rounds 6-9 use the large arena until they get their own.
  Layouts were then tidied: rocks evenly spaced (Round 2's three rocks
  120° apart; Round 5's an equal distance from both walls), start spots
  centered, and Round 1 and the large arena made truly square.
- **Rocks** block movement and line of sight: enemy areas don't hit through
  them, and party members can't attack through them. The **pit** blocks
  movement only. Enemies and allies steer around both.
- Every fighter is its own scene (`scenes/characters/`). **Fighter is now the
  Knight**, and the **Cleric** joins (placeholder stats, no healing yet).
- All 8 roster enemies exist with the skills that current building blocks
  allow; the rest are listed in `enemy-roster.md`. Ranged enemies keep their
  distance (`preferred_gap`).
- HP panels fit four rows and longer names.

## Enemy template and Stone Golem

- **Enemy skills are now data:** each enemy has a Skills list in the
  Inspector. A skill sets its name, triangle kind, weight, area, damage,
  wind-up, and whether it can be parried or blocked.
- **New area shapes:** **line** (a rectangle in front of the enemy) and
  **donut** (safe close up and far away). Half-circles are 180° cones.
- **Golem is now the Stone Golem:** Heavy Attack (Smash cone), Crush (Smash
  line, 8 m) and Rock Stomp (Attack circle). Rock Spikes waits for hazards.
  It dropped the old Attack shape cycle and the Defense/Counter stances.
- The strike prompt says when a skill can't be parried or blocked.
- HP panels make room for longer names.

## Positioning test and Golem update

- **New turn flow (test):** positioning now happens *between* turns. While
  the timeline runs you steer one party member in real time and switch with
  Tab; enemies and AI allies move in real time too. When a party member's
  turn comes up they're locked in place and the menu opens automatically.
- **Wait command:** ends the turn without spending AP; the fighter's bar
  restarts a third of the way along. Space no longer ends a turn.
- Moving is now free and **no longer earns AP**; the passive AP recharge was
  raised from 4 to 6 per second to compensate.
- **Battle speed 0.7:** battles run 30% slower (timeline, enemy and ally
  movement, AP recharge). The steered fighter, strike rings and combo timing
  keep full speed.
- **Ally AI** now stands near the edge of its attack range from the nearest
  enemy while staying out of danger.
- **Golem:** Attack range raised to 3.7 m, and its Attack cycles through
  three shapes: cone, short-range circle, and a long narrow cone at double
  reach. Defense and Counter stances now linger 3 seconds after its turn.
- The previous flow is saved in `backups/before-positioning-test.zip`.

## Max AP economy

- Parry and Perfect hits no longer refund AP. Instead they raise the party's
  **max AP** for the rest of the fight (+10 per Parry, +5 per Perfect, up to
  200). Missing either one resets max AP to 100.
- AP recharge scales with max AP (1.5x at 150, 2x at 200): a big bank refills
  fast, and one mistake costs it all.
- Skipping a timed hit costs 5 of the extra max AP; it never goes below 100.
- Tab swapping during a turn was removed (later brought back between turns).
  Party members who are ready at the same time now act back to back.

## Timed combo hits

- The combo playhead became a timeline: each move has its own animation
  duration, so the playhead speeds up and slows down per block.
- A **timing box** sits before each hit (Double Slash has two). J inside the
  box = Perfect (+50% damage); J outside it ends the chain; no press = a
  normal hit.
- A 1-second **READY** lead-in before the first move.
- Menus hide while a combo plays; the bar shrinks to a strip at the bottom.

## Command menu and combo bar (Legend of Legaia-style)

- **J opens a command menu**: Attack / Abilities / Items (the last two are
  placeholders), with Defend Q / Parry E reminders.
- **Attack opens a combo bar**: Slash 10 AP, Thrust 15 (pierces Defense),
  Double Slash 15 (two hits), Overhead Smash 30 (breaks Defense). Each
  character's bar has its own length (Fighter 60, Archer 50, Mage 45),
  paid from party AP.
- The combo plays out, then the turn ends.
- Replaced an earlier design (now parked in the notes): free attacking on an
  action timer, pausing to bait the enemy, and climbing AP costs per attack.
- Gold reach rings around each party member show their attack range.

## Party attacks (milestone 6)

- J / K attacked with Attack / Smash for AP; an action timer that hits
  extended; pausing in the enemy's area baited it into striking, and a Parry
  countered for bonus time. Later limited (baits per enemy per turn) and
  then replaced by the combo bar.
- The skill triangle applied to party attacks: Counter punishes, Defense
  blocks Attack but breaks to Smash, Attack interrupts a prepared Smash.
- Enemy HP, damage popups, and a Victory screen. AP top-up to 30 at the start
  of each party turn.

## Strikes and reactions (milestone 5)

- Enemy attacks became **strikes** played in real time (an early idea of
  slowing time down was dropped in favor of reading the animation; a
  slowdown may return as an item).
- A shrinking ring shows when the hit lands. **Parry (E)** on the gold ring:
  no damage, enemy staggered. Too early: full damage, delayed turn, half AP.
- **Defend (Q)**: costs AP; part of the damage is taken but comes back at
  the fighter's next turn if they aren't hit again.
- HP bars, knockouts, game over, and R to restart.

## Hidden intent and the skill triangle (milestone 4)

- The **casting zone** at the end of the timeline: enemies prepare a skill
  there, standing still and turning slowly.
- The **skill triangle** from Mabinogi: Attack, Smash, Defense, Counter,
  each with its own area shape on the floor.
- Intent is hidden ("???") and revealed late, so it can't be prepared for
  too easily. Defense/Counter stances last through the casting zone.
- Walking pushed the timeline forward (removed later with the positioning
  test).

## AP decisions

- Two AP models were compared: Valkyrie Profile 2 (walking earns AP, attacks
  spend it) and Breath of Fire: Dragon Quarter (per-character AP for moving
  and attacking). The VP2 approach won, with walking advancing the timeline
  so AP-farming had a cost.
- AP became one shared party pool that carries over between turns.

## Movement phase (milestone 3)

- WASD moved one fighter; the world only moved while you did
  (VP2-style). Enemies turned slowly toward the party, with a visible threat
  cone. AI allies followed and stepped out of danger. Tab swapped control
  to an ally for AP.

## Timeline (milestone 2)

- A Grandia-style turn-order bar: icons slide along at each fighter's speed,
  and reaching the end starts their turn.

## Arena (milestone 1)

- The project began: Godot 4.7, a floor, a camera, three party capsules
  (Fighter, Mage, Archer) and one enemy cube (Golem).
