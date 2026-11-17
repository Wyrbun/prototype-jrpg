# Battle system design notes

Inspirations: Grandia 2 (timeline, casting, cancels), Valkyrie Profile 2
(real-time positioning, AP from movement, combos), Mabinogi (skill triangle,
visible skill loading, knockdown rhythm).

Living notes on how the battle system should work. Update as decisions are made.

## Core idea

Grandia 2's shared timeline decides *when* someone acts. Valkyrie Profile 2's
real-time arena decides *what happens* during a turn: positioning, enemy
threat ranges, and chained attacks.

## Timeline (milestone 2, built)

- Every fighter slides along one bar at their own `speed`.
- Reaching the end of the bar starts that fighter's turn and freezes the timeline.
- **Reading the bar:** twins ("Kobold Archer A" / "B") carry their letter on
  a badge; the fighter you're aiming at (target choice, combo bar, combo
  playing) gets a pulsing gold ring and arrow, its floating name turns gold
  (enemies), and others the highlighted move would hit get a thin ring.
- After acting, the fighter goes back to the start of the bar.
- The last stretch of the bar (from 73) is the **casting zone**. An enemy
  entering it **prepares a skill**. This is the Mabinogi "visible skill
  loading", told the Grandia way.
  - **Where, then what:** as soon as the enemy enters the zone its area
    appears on the floor **in grey** ("..." above it, "???" on the bar): you
    see where it will land, not what it is (except skills with `hides_side`,
    the single Golem Smashes: grey over the whole room until the reveal). The skill is **revealed** at
    `reveal_at` (88): its name, and the area in color (live: it glows and
    warns whoever is inside).
  - While preparing, the enemy **stands still** and **tracks the party
    member it locked onto** when the cast began (or whoever taunted it) at
    its full turning speed. In the last `cast_slow_seconds` (1 s) it slows
    to `cast_turn_speed_degrees` (40°/s): that's the window to slip out.
  - **Lines keep tracking:** a line (Attack / Smash; not one that snaps to
    its target or is placed on the party) turns at least
    `line_final_turn_speed` (80°/s) in its last second instead of 40°/s, so
    it keeps up with anyone more than ~3.5 m away; a skill's own
    `final_turn_speed` wins. Rocks, range and Parry / Defend are the answers.
  - **Melee tracking:** not up close, though. A short cone or line (an
    Attack or Smash up to `melee_track_radius` 5.5 m long; cones under
    180°) whose locked target stands within its length +
    `melee_track_margin` (1.5 m) keeps turning at `melee_track_turn_speed`
    (300°/s) to the very end, and while the target is past
    `melee_chase_share` (75%) of its length the enemy **steps after it**
    (not when pinned or frozen). In melee, Parry or Defend; dodging means
    leaving early. Covers Golem Heavy Attack, Living Armor Combo, Ogre
    Attack, Goblin Attack and Smash, Gust Sprite Gust and the Training
    Golem's Attack and Smash; not half-room Smashes, placed circles, long
    lines, skills that snap and hold their aim (Shield Bash) or Breath
    (which already aims exactly). A short circle round the enemy itself
    (Rock Stomp) counts too: it steps after a target at its edge.
  - The **timeline speed** (`time_scale` 1.8, 40% slower than before) makes
    a cast last about 1.8–2.7 s depending on the enemy's speed.
  - **Defense/Counter** stances are active for the **whole casting zone**
    (from 73, even while hidden) and **linger for `stance_linger` (3 s)
    after the enemy's turn**, counted while the timeline runs. The enemy holds
    its ground (turning slowly) while a stance is up.
  - **Which skill** is picked from the enemy's own skill list, by weight
    (see "Enemy skills" below). Its name and area show only on reveal.
  - Attack/Smash fire when the icon reaches the end of the bar, never
    earlier, hitting everyone inside the area at that moment.
  - **Idea (later): per-character reveal.** Each character could see hidden
    skills earlier depending on type: some read **defensive** skills
    (Defense/Counter) early, others read **offensive** ones (Attack/Smash)
    early. Who you control (or swap to) then changes how much you know.
    Likely implementation: a per-character reveal threshold for each skill
    type, used in place of the global `reveal_at` for the fighter you control.
- Planned: hits from behind or well-timed counters knock enemies back on the bar
  (the Grandia "cancel").


### Command timing: Windup (the default; Classic is a toggle)

A setting (pause menu: "Command timing: Classic / Windup", `Settings.command_windup`,
read when a fight starts; the tutorial always uses Windup) that moves the party's
decision earlier, Grandia-style:

- A party member's turn comes at the **command point** (`party_command_at`,
  65, was 70; a gold notch on the timeline). Time stops; Abilities and Wait work as
  usual (Wait: the turn ends, next one sooner), and Attack picks **any
  enemy**, in reach or not.
- After choosing, time runs again while that fighter's icon goes from the
  command point to the end (a gold strip on the bar). You steer them into
  reach; AI allies walk to their own target.
- **At the end:** in reach of the chosen enemy (any of its attacks), the
  combo bar opens on it and plays as usual. Out of reach: a **grace**
  (`windup_grace_seconds`, 1.5 s, was 1) where it still acts the moment it gets in
  reach; after that, if **another enemy is in reach**, the attack goes to
  the nearest one instead ("SWITCHES TARGET": "Knight can't reach Ogre
  Warrior: attacks Orc Shaman instead"; never one in Counter stance, and an
  AI ally skips tough enemies without a push, though Lightweight Gust
  Sprites are fair game since any hit pushes them; `_windup_fallback`).
  Nobody in reach: the turn **becomes a Wait** ("TOO FAR"). If the target
  went down, the menu opens again.
- **Waits in cover:** while any enemy prepares a lethal skill (Doom Gaze),
  the grace doesn't run: everyone may be hiding behind the cover rock, out
  of reach ("WAITS IN COVER"). Once the gaze is over, the grace starts and
  the fighter walks in. (In 0.5.0 a Living Armor fight had 6 turns lost to
  this, and the Mage dealt no damage.)
- Turn-start AP, effects counting down and the report's turn count happen
  once, at the command point. Reports count `windups` and `windup_misses`.

## Positioning and turns (current test setup)

> Testing a new flow. The previous version is saved in
> `backups/before-positioning-test.zip`.

- **Between turns** (timeline running): you steer one party member in real
  time with WASD. Enemies and AI allies also move in real time.
  **Moving is free** and earns no AP. **Tab** switches which party member
  you steer (free), so you can position each of them. **Holding Tab**
  (`steer_hold_seconds`, 0.3 s) stops time and opens a picker (`SteerPicker`):
  A/D, the arrows, the mouse wheel or 1-6 choose (the camera follows the
  pick; downed members are greyed out and skipped), and letting go of Tab
  steers the one picked. A tap still just switches to the next one.
- **On a party turn**, time freezes and that fighter is **locked in place**.
  The command menu opens automatically: **Attack** (needs an enemy in reach),
  **Wait**, Abilities, Items.
- **Wait** ends the turn without spending AP; the fighter's bar restarts at
  `wait_head_start` (33) instead of 0, so the next turn comes sooner.
- If several party members are ready at once, their turns come up back to back.
- Movement control only changes when you press Tab. A party turn takes it
  for its menus; when the turn ends (or, with Windup timing, once you commit
  at COM), it goes back to whoever you were steering before it (after
  back-to-back turns, to whoever you steered before the first). A committed
  ally you aren't steering walks to its target on its own. (Planned: make
  this an option.)
- **Camera:** follows the steered fighter, leaning toward the nearest enemy.
  Z / C or right-drag rotates it, dragging up and down tilts it (20-75°),
  the wheel zooms (7-24 m), V resets. Movement is camera-relative.
- **Turn pans:** when a turn comes up, the camera eases over to that fighter
  (ally or enemy) and the turn starts when it arrives: the menu opens, or
  the enemy acts. The pan takes 0.3 s plus a little per meter, up to
  `turn_pan_max_seconds` (0.8 s); no pan if the camera is already there.
  After the turn it eases back to whoever you steer. Tab switches ease too.
- **Battle speed** (`battle_speed`, 0.7 = 30% slower) slows the timeline,
  enemy and ally movement, and AP recharge together. The fighter you steer,
  strike rings and combo timing aren't slowed.
- Every enemy shows its area on the floor: **dormant** (faint, harmless)
  most of the time, including while the skill is hidden, and **live** once
  revealed. The strike lands when the enemy's turn comes, on whoever is
  inside the area then (an earlier "touch it and it strikes at once" rule
  was removed: with tracking enemies it made them act ahead of the bar).
- **Ally AI** (party members you aren't steering), in priority order:
  1. **Stack up** for a revealed shared-damage skill (Breath): gather on the
     party member it's aimed at (or whoever inside is nearest the enemy) so
     the damage is split. That area isn't treated as danger.
  2. **Stay out of danger:** leave any enemy area that could hit, never step
     into one. Danger = an Attack/Smash revealed at least
     `ally_react_seconds` (0.1 s) ago, or `ally_react_unanswerable_seconds`
     (0.05 s) for strikes that can't be Parried (Golem Smash: dodging is
     the real answer, Defend only softens it) (a human-like reaction: the grey "..."
     area alone no longer sends them away, since that made them almost
     never get hit), mechanic skills and overlap-punishing circles from the
     start (spreading out takes time), fire trails, rock spikes, falling
     rocks and rock blasts. **Holding ground:** fighters with `holds_ground`
     (Knight, Monk) don't run from a short melee attack (see melee tracking)
     that can be Parried or Defended: your Parry / Defend press covers
     everyone the strike hits. A circle or line that
     follows this ally while hidden is ignored until revealed (it can't be
     outrun). Circles that punish overlaps (Dark Bolt, Burning Spike) keep
     allies a full circle apart: they spread out. Inside a ring (donut)
     they head for whichever edge is closer, usually the safe middle.
  3. **Stand near the edge of their attack range** from their focus enemy
     (`ally_range_share`, 80% of reach): close in if too far, back off if much
     too close, detouring around danger. Focus = an enemy casting Healing
     Ritual (they close within its interrupt range, so your hits break it;
     its circle is never treated as danger, even while hidden),
     then the caster of a growing circle not yet contained, otherwise the
     nearest enemy.

## Party AI (built, a toggle)

Pause menu "Party AI: On / Off" (`Settings.party_ai`, off by default, applies
at once; always off in the tutorial). With it on, every party member except
the one you steer plays its own turns **instantly**: no menus, no combo bar,
the timeline never stops (`_ai_turn`, called where `_start_turn` would be).
Tab / hold Tab takes one over. The party list tags them **AUTO**.

- **Turn:** turn upkeep and the turn's AP, as usual; maybe one Ability
  (`_ai_ability`: heals (the Cleric: Healing on the most hurt ally under `ai_heal_below` 70%, Full Cure under `ai_full_cure_below` 35%, or Healing when Full Cure is unaffordable; heals ignore the AP held for your turn), Brace / Arcane Barrier when an attack is aimed at it, the Mage's Enchant when none is running, the Cleric's Haste on your fighter when nobody needs healing,
  Agility only if it still has half its bar to attack with after paying); then a target (`_ai_pick_target`: the allies'
  focus or the nearest; never in Counter stance; a tough enemy only
  with a push, except Lightweight Gust Sprites, which any hit pushes). A
  Lightweight enemy comes first (`_ally_focus`), and the AI lines up its hit
  first: it walks round to the far side of it from the nearest drop
  (`_line_up_push`, `_drop_direction`: lethal edges and holes), so the push
  sends it over. Windup: chosen at COM, it walks into reach, plays at ACT
  (out of reach after the grace: the nearest enemy in reach, else TOO FAR;
  the grace waits while it's escaping a danger area: "DODGING"). Classic: attacks
  whoever is in reach, else Waits. With a target but no clear shot (a rock
  in between), it walks round the rock's side first.
- **Combo** (`_ai_choose_moves`): greedy by value per AP over single moves
  and every Art of its class, found or not (`_ai_building` lets
  `_rebuild_plan` merge them all). Unfound Arts work normally but stay
  hidden: never discovered, renamed "hidden Art" while they play (messages,
  popups). Value = sum of hits, x1.5 for a GOOD answer tag, 0 for BAD; a
  Defense stance makes everything but breaking / piercing moves worth 0
  until a break is chosen; against a tough sprite pushes are x3, the rest
  x0.1.
- **AP budget:** up to `ai_spend_share` (0.75) of its own bar, keeping
  `ai_reserve_share` (0.6) of the steered fighter's bar minus the recharge
  before their turn; if that's less than its cheapest move, half as much,
  keeping half the reserve.
- **Playing it** (`_ai_play_plan`): every hit lands in order with the same
  effects as a played combo (Arts, Marks, Monk tokens and steps), but no
  timing: no Perfect bonus, `ai_damage_mult` (0.8) of a normal hit, max AP never reset, +`ai_max_ap_per_hit` (1.5)
  per timed hit. A flash line sums it up ("Cleric: Judgment on Stone Golem
  (36 damage)").
- Strikes aimed at AI allies still ask you to Parry / Defend.
- They dodge like a player would: only after a skill is revealed (+0.1 s;
  a skill lands about 0.45 s of battle time after its reveal),
  and they don't walk into a grey area while positioning (Shadowflare and
  healing rituals excepted: those they go into). They keep away from a
  lethal edge or hole: `ally_ledge_min` (1.5 m), or while an enemy prepares
  a push, the push plus `ally_ledge_margin` (1 m). Against a boss, the Mage
  and Cleric stand at the edge of their reach, `fragile_flank_degrees`
  (70°) off its front (not wall bosses, not when it's locked on to them).
  In a Shadowflare each AI ally goes for a different sprite, and one that
  chose the Armor before the sprites appeared switches to one. An AI ally
  whose Windup target raised a Counter stance since backs off (a Wait,
  `ai_counter_backoffs`) instead of attacking into it. AI allies
  don't push an enemy that is preparing a strike whose area moves with it
  (`_carries_area`; not Lightweight sprites): a pushed Golem Smash landed
  on the side the party had run to. Your own pushes still work.
  and the Knight and Monk hold their ground in short melee attacks (see
  Ally AI above).

## Play-test reports (built)

Every fight outside the tutorial saves a report when it ends (or when you
leave it with N, P, Restart or Quit after at least one turn), in the game's user data
folder: `%APPDATA%\Godot\app_userdata\Prototype JRPG\playtests` on
Windows, from the editor and exported builds alike. Press **O** on the
end-of-fight screen to open the folder.

- One `.md` file per fight: round, attempt number, result, length and turns;
  per party member HP left, damage dealt and taken, times downed; enemy HP
  left; each enemy skill's uses, misses, people hit, damage, parries and
  defends; where each member's damage came from; counts (parries, early
  parries, defends, perfects, interrupts, guard breaks, contained casts...).
- `playtests.csv`: one line per fight, for comparing attempts in a
  spreadsheet.
- Code: `scripts/battle/playtest_log.gd`; the battle reports damage through
  `_hurt()` so every source is counted.

## Boss rush, arenas and sight (built)

- `data/boss_rush.tres` lists the rounds. Each is an `Encounter`: title,
  arena scene, party scenes (the first starts under control), enemy scenes.
  Duplicates get letters (Kobold Archer A / B). `start_round` on BattleArena
  picks where a round starts when the scene is run directly; the title
  screen's Round Select picks it otherwise. N / P change round mid-fight.
- **Arenas** are scenes with an `Arena` root (rectangle or circle, size,
  floor color), `PartySpawn` / `EnemySpawn` markers (fighters stand side by
  side there, facing the other side), and `ArenaObstacle` children:
  - **Rock**: blocks movement and **line of sight**. An enemy's area doesn't
    hit anyone behind a rock from the enemy's point of view, and a party
    member can't attack an enemy behind one (the reach ring stays dim).
    Grazing the edge doesn't block (85% of the rock counts).
  - **Pit**: blocks movement only.
  - **Hole**: a lethal drop (black, a glowing red ring, skulls around it).
- **Lethal edges** (`lethal_sides` on rectangles, `lethal_rim` on circles):
  marked by a thin glowing red death wall lined with skulls; other edges are
  walls. Rules for drops (holes and lethal edges):
  - **Forced moves** (knockback, launch, push out, Hook, enemy `pull`) carry
    fighters over a drop: they **fall out of the fight** (counted as down).
    Party moves can knock regular enemies in to end fights sooner. Enemies
    with `boss` (Stone Golem, Living Armor, Dragon Hatchling, Training Golem)
    can't fall: they stop at the brink.
  - **Walking**: AI allies and enemies steer around drops and never step
    in. The steered fighter can walk to the very edge; when its middle goes
    over, the fight pauses on a **save ring** (like a Parry, `edge_save_seconds`
    1.0, window = `edge_save_window`, 0.25 s): Parry as it turns gold to be put back on
    solid ground, otherwise it falls. The same save applies when a party
    member is **pushed or pulled** over (several at once queue up, one save
    at a time). A caught save leaves the fighter **Off-Balance** for
    `off_balance_turns` (3) of their own turns: going over an edge again in
    that time is a fall, no save. Then saves work again.
  - **Bracing:** Defend (`defend_cost` AP) during a strike that pushes or
    pulls (launch, pull) makes the move `defend_move_share` (half) as long
    for fighters who can Block (or a guarding Knight covers), even when the
    damage itself can't be blocked (Inhale, Exhale). Popup: BRACED.
  - Enemy skills with `launch` (throw away) or `pull` (drag towards the
    enemy, on the last hit) show **red arrows** on their area, sliding the
    way you'll be moved. Pulls drag through anything: holes, edges, fire.
  - Reports count `falls`, `enemy_falls` and `edge_saves`.
- **Round 5** uses the **Platform** arena (`arena_platform.tscn`): 19 x 16,
  the east edge lethal, two holes in the middle and one rock.
- Enemies and allies **steer around** obstacles; an enemy without a clear
  view of its target keeps walking until it has one.
- Rounds 8-10, 13 and the Special Match use the Grand arena; Round 11 (the Gale Maw) the **Cliff** (`arena_cliff.tscn`: 22 x 14, the south edge lethal, two rocks 7 m out from the wall); Round 12 (Golem + Kobold + Ogre) the Rock Field.
- **Wall bosses** (`anchored`): placed with their centre on the middle of
  the far wall at the start (`_anchor_to_wall`), half the body in the wall,
  facing into the arena. They never walk or turn, can't be moved (knockback,
  Hook, throws), and their pushes and pulls run straight across the arena
  (perpendicular to the wall; Undertow's lines pull along the line). Rocks
  shelter you when they stand between you and the wall straight ahead
  (`_strike_reaches`). Shadowstep lands at their side; Hook pulls the
  Assassin to them instead. New area shape **BAND**: a strip across the
  arena from `inner_radius` to `radius`, `width` wide, optionally split into
  `lanes` with equal gaps. A strike can now have a generic `follow_up` (Deep
  Breath: Inhale, then Maw Bite `follow_up_delay` s later).
  Wall-boss extras (exports on `Combatant`): `crumble_at_share` /
  `crumble_meters` (the arena's lethal sides move in once, `Arena.crumble`),
  `rock_regrow_turns` / `rock_crack_limit` (skills with `breaks_rocks`
  crack `ArenaObstacle` rocks in their area; broken rocks drop out of
  `obstacles()` until they regrow), `winded_timeline` (timeline push on
  everyone it moves), `summon_scene` / `summon_every` / `summon_count`
  (summons join `enemies` and `combatants` mid-fight and go down with
  their summoner). `EnemySkill.line_extend` sets how far LINE_TO_EACH lines
  run past their target; `double_on_off_balance` gives Off-Balance fighters
  a second line.
- **Party picker** (`scripts/battle/party_picker.gd`): from Round 8
  (`PICK_PARTY_FROM` = index 7) the fight opens paused behind a "Choose your
  party" panel: tick 1 to 4 of the six classes (solo allowed), then start;
  the scene reloads with that party (`chosen_party`, `chosen_for_round`),
  **in the order they were ticked** (numbers in the boxes; the first starts
  under your control).
  Retrying keeps the pick, a new round asks again, Esc goes to the title.
- An `Encounter` can have a `tip`, shown for 9 s when the fight starts
  (Round 6 explains the Assassin, Round 7 the Monk).

## Counter-parry (built)

- A combo hit on a Counter stance (`_resolve_combo_hit`, while EXECUTING):
  the hit is caught (no damage), the playhead stops, and `_counter_left`
  counts down from `counter_parry_lead` (0.6 s). The hit key within
  `counter_parry_window` (0.12 s) of zero calls `_counter_parried`: the
  stance breaks (`_cancel_enemy_skill`), `_counter_bonus`
  (`counter_broken_bonus`, +25%) applies to the rest of the combo, and the
  playhead resumes after `counter_recover_seconds` (0.6 s; presses ignored,
  `recover_progress` draws a shrinking gold ring). Early or late: `_counter_failed`: `counter_stance_damage`
  to the attacker and the combo stops.
- The bar draws a red box around the stopped playhead, a red line closing in
  from the right (`counter_progress`), and a "! COUNTER !" tag left of it.
- Answer tag: COUNTER: PARRY IT (warn).
- Windup: at ACT, cancel on an empty bar is allowed when the target is in
  Counter stance; the turn becomes a Wait (counts `counter_waits`).

## Boss cancel resistance (built)

- `Combatant.cancel_every` (bosses: 2): after one of its skills is cancelled
  (Smash interrupt, healing-ritual interrupt, stun, Hook), the boss resists
  cancels for `cancel_every - 1` of its actions, plus one more for each
  cancel it already took this fight, up to `MAX_CANCEL_LOCK` (3). Counted in
  `_enemy_unleash`. Resisted: "IMMUNE" popup, `cancels_resisted` stat, and
  the answer tag IMMUNE (warn) instead of STUNS / INTERRUPTS / STOPS IT.
- `EnemySkill.uncancellable`: a signature move that can't be cancelled at all
  ("UNSTOPPABLE"); halts and Stagger still work. Set on Golem Smash, Ceiling
  Burst (and the combos), Shadowflare, Breath, Exhale, Gale Burst.
- Breaking a Defense / Counter stance is not a cancel: it always works.
- Gate: `_try_cancel(enemy)` / `_cancel_resisted(enemy)` in battle_arena.gd.

## HUD look (built)

All HUD pieces share one style, `HudStyle` (`scripts/ui/hud_style.gd`),
matching the timeline bar: navy panels with a blue sheen, a blue accent line
on top and a pale frame (`draw_panel`); bold slanted titles with a navy
outline (`draw_header`, 24 px and up; smaller text stays in the plain font
for readability); glossy gradient gauges with 10% ticks (`draw_gauge`,
the HP bars); a gold wash for the selected row (`draw_selection`). New HUD
pieces should use these rather than their own StyleBoxes.

## Title screen and tutorial (built)

- The game opens on the **title screen** (`scenes/ui/title_menu.tscn`):
  Boss Rush, Tutorial, Round Select, Controls, Change Keys, Quit. Keyboard
  (W/S, J/Enter, K/Esc) or mouse.
- **Play style** (asked once): the first Boss Rush / Continue / Round Select
  opens a page with Command timing (Windup / Classic) and Party AI (On /
  Off), each explained, plus where to change them later (pause menu). Start
  saves both (`Settings.style_chosen`) and carries on.
- **Change Keys** (`scripts/keybinds.gd`): every action except Esc can get a
  new main key; its extra keys (arrows, Enter, Backspace, keypad Enter)
  stay. Taking a key another action uses swaps the two; a key that's only
  another action's extra moves over. O is reserved (open reports). Saved to
  `user://keybinds.cfg` (every key of every action), applied at startup by
  the title screen and the battle. Hint texts use tokens like `{confirm}`,
  `{parry}` or `{move}` and go through `Keybinds.fill()`, so the Controls
  page, menus, strike prompts, pause menu and tutorial notes always name
  the current keys.
- **Esc in a fight pauses** (`scripts/battle/pause_menu.gd`): the fight
  freezes and a menu offers Resume, Restart fight and Quit to title. Esc or
  K again resumes, so an accidental Esc never throws a fight away. After a
  fight is over, Esc goes straight to the title screen.
- **Auto-save (Boss Rush only):** every Boss Rush fight saves its round as
  it starts, and a win saves the next round (`scripts/save_game.gd`,
  `user://save.cfg`); beating the last round clears the save. **Continue**
  appears at the top of the title screen when a save exists and starts that
  fight from its beginning, in Boss Rush mode. Starting a new Boss Rush
  replaces the save (the title screen says so). Round Select fights and the
  tutorial don't save; in a Boss Rush the pause menu's Quit says progress is
  kept. Play-test reports note the mode ("Boss Rush", "Boss Rush
  (continued from a save)" or "Round Select").
- The **tutorial** (`scripts/battle/tutorial.gd`) is one continuous guided
  fight: Knight vs Training Golem in a small arena with one rock
  (`data/tutorial.tres`). It teaches Windup command timing and always runs
  with it, whatever the setting. The earlier Classic version is kept in
  `archive/tutorial_classic.gd` (the folder has a `.gdignore`, so Godot skips
  it; copy it back over `tutorial.gd` to restore). It's a list of steps:
  - **Notes** pause the whole fight until J / Space.
  - **Goals** let the fight run until done (checked against counters the
    battle keeps: parries, perfects, waits, guard breaks...).
  - Each step can set up the fight first: hold a fighter on the timeline,
    make the Golem repeat a skill, or have it prepare one and freeze the
    moment it's revealed (a held enemy doesn't strike or walk).
- Lessons: 1 Moving, 2 The timeline (WAIT / COM / CAST / ACT, reach ring,
  reach COM), 3 Your turn (moved out of reach: choose Attack at COM, get in
  reach before ACT, build the combo there), timed hits, Wait and Arts (find Double Slash, then add an Art from the list), 4 Reading the enemy (dodge a revealed Attack), 5 Parry and
  Defend, 6 The skill triangle (Thrust/Lunge through Defense, Wait out
  Counter, interrupt Smash), 7 The classes, one at a time and alone
  (Archer: Hold moves and Abilities; Mage: spell codes; Cleric: heals), 8 Max AP
  (the Knight alone again), 9 Rocks (the Golem waits with Long Strike revealed and
  strikes once you're hidden behind the rock), 10 Special skills (notes),
  11 The Assassin (with only the Knight; the Golem is Taunted by the Knight so its back
  stays open: hit it from behind, use Shadowstep, put 4 Marks on it,
  Execute, then let the Golem's Attack be auto-parried), 12 The Monk (alone:
  climb a step with Knee Smash, notes on tokens and the preview, climb to bar
  100 with any climb Arts, then cash out with Tortoise Special, given Crowd
  Cheer for the lesson; a note on risks and tanking), 13 Free practice
  (Knight, Archer, Mage and Cleric together; switching who you steer is
  explained here)
  (the Golem fights normally and can be defeated).
- **Positional rings** (`PositionalRing`, a child of each enemy so it turns
  with it): shown while a `flanks` fighter (the Assassin) is steered. Front
  arrow, thin white front/side arc, thick violet rear arc (±60° off the
  back), glowing while the Assassin is in it. Enemies with
  `no_positionals` (Goblin Fighter, Kobold Archer) get a full violet ring:
  `is_behind()` is always true for them, and Shadowstep's front bonus
  applies too.
- **Can't be lost:** every fighter has `cannot_fall` (HP stops at 1), party
  HP is topped up to 60% at each step, the Golem refills before free
  practice, and AP is topped up where a lesson needs it.

## Enemy skills (built)

Every enemy has a **Skills** list (Inspector, Combat group). Each entry is an
`EnemySkill` (`scripts/battle/enemy_skill.gd`):

| Field | Meaning |
|---|---|
| skill_name | shown on reveal, above the enemy and on the timeline |
| kind | Attack / Smash / Defense / Counter: its place in the skill triangle |
| weight | how often it's picked compared to the others |
| shape | **Cone** (angle; 180 = half-circle), **Circle** around itself, **Line** (length = radius, plus width), **Donut** (radius plus a safe inner_radius) |
| damage, windup | hit damage, and seconds until it lands |
| cannot_be_parried | E does nothing ("can't be parried") |
| cannot_be_blocked | Q does nothing ("can't be blocked") |

An enemy with an empty list uses the basic triangle set from `skills.gd`.

**Special skills** (EnemySkill "Special" group; kind SPECIAL sits outside
the triangle):
- **On each target:** a circle dropped on every party member (follows them
  while hidden, locks on reveal). Overlap rule: double damage (Dark Bolt) or
  drop to 1 HP (Burning Spike).
- **Line to each:** a line from the enemy to every party member, aimed while
  hidden. Overlaps: double damage and can't be blocked (Curse). Rocks block
  lines.
- **Growing:** a circle around the enemy growing over the cast; dealing
  `contain_share` of its max HP during the cast stops it. With
  `orbit_sprites` (Shadowflare: 3) it's sprites instead: `orbit_scene`
  enemies (1 HP, off the timeline) circle along the edge at `orbit_speed`
  m/s; it stops growing once each has been hit. `max_radius_fits_arena`:
  its biggest size reaches from the arena's middle to the corners, so it
  can only be outrun when the caster is off to one side.
- **Heal allies:** heals enemies in a circle; `interrupt_hits` party hits
  from within `interrupt_range` break it (Healing Ritual).
- **On marked:** one circle on the party member the enemy locked onto
  (follows while hidden; unavoidable ones keep following). Hits everyone
  inside, so the target should stand alone (Fireball, Rock Spikes).
- Also per skill: **hits** (multi-hit, a ring per hit, each hit can be
  Parried), **launch** (last hit throws targets), **shared damage** (100%,
  67%, 50%, 40%... for 1, 2, 3, 4 targets), **trail** (leaves the area
  burning for N of the enemy's turns, damage per second; for circles placed
  on the party, each circle burns where it landed: Burning Spike).
- **stops_at_first_hit:** only the party member closest to the enemy is hit;
  they shield whoever is behind (Wind Slash, Shield Bash).
- **snaps_to_target:** on reveal the enemy turns at once to face its target,
  then holds that aim until it strikes, so you can step out of the line
  (Shield Bash).
- **let_through** (Defense stances): share of a hit that still gets through
  instead of a full block (Goblin's Defend lets 40% through).
- **push_out + follow_up:** pushes everyone inside out past the edge. The
  follow-up is revealed at once and strikes `follow_up_delay` seconds later
  (real seconds: when a fast boss's bar can't fit that before the end, the
  follow-up starts at the casting zone's edge and its bar runs slower,
  `follow_up_slow`, so the delay still holds)
  (2 s: the enemy waits near the end of the bar). Everyone pushed gets an
  orange sphere and is hit wherever they go; anyone else can still dodge it
  (Shout, then Sword Spin: run into its safe middle).
- **Mechanic skills (UNAVOIDABLE):** they can't be dodged, only answered.
  Revealed with "UNAVOIDABLE" above the enemy and "(unavoidable)" in the
  warning line.
  - **No Parry or Defend** (and no Riposte): they just deal their damage.
    No timing ring and no prompt: everyone about to be hit gets a red mark,
    and it lands after a short beat (`unavoidable_impact_seconds` 0.45).
  - `always_hits` (placed circles and lines): everyone it was placed on is
    hit wherever they stand; a rock still blocks a line (Dark Bolt, Burning
    Spike, Curse, Fireball, Rock Spikes).
  - `always_hits_target`: the locked target is hit however far it runs,
    unless a rock blocks the enemy's view (Breath, Power Shot). The enemy
    also keeps facing it exactly to the end, so the area you see is the one
    that hits.
  - Unavoidable circles and lines keep following their party member after
    the reveal (avoidable ones lock in place), so overlaps, who stands near
    a Fireball, and where Burning Spike leaves its fire are decided by where
    everyone is when it lands.
  - `hits_everyone` (growing circles): the explosion hits the whole party
    for damage scaled by its final size, at least 25% (not used right now:
    Shadowflare only hits those inside its circle).
- **Avoidable hits (AP penalty off for now):** when a strike lands on someone
  who didn't Parry or Defend, and it could have been avoided, it's counted as
  an avoidable hit. It used to cost one segment (100) of bonus max AP, once
  per strike; `avoidable_hit_max_ap_loss` is 0 for now, so it only costs the
  damage (and the Monk still loses a step).
  Dodgeable skills always count; mechanic skills only when the answer was
  missed: caught in an overlap, taking a stack skill alone, not alone under a
  marked circle, or a growing circle never contained. Fire and spikes don't
  count. With the penalty on, the meter's top segment pulses red with a "!"
  while anyone stands where a revealed strike would cost max AP (off with
  it). Reports count them per skill either way.
- **Bosses resist interrupts** (`interrupt_resist` 3): it takes three
  Attack-type hits to stop a boss's Smash (a counter pops up), or one
  breaking move. Normal enemies still lose a Smash to one Attack hit.
- **Camera framing:** when a strike catches anyone off screen, the camera
  eases out and over until the enemy and everyone hit are in view
  (`strike_frame_max_distance` 34 m), then eases back.
- **Bosses** (Stone Golem, Living Armor, Dragon Hatchling) have speed 20,
  about twice a party member's, so a solo boss acts roughly once every 2-3
  party turns instead of every 5. Their `cast_zone_speed` 0.5 (Combatant,
  Combat group) halves their speed inside the casting zone, so casts and
  reveals stay as readable as a normal enemy's.
- **cast_speed:** while casting this skill the enemy moves along the bar at
  this share of its speed (Shadowflare 0.35: it grows slowly;
  Breath 0.6: more time to stack up).
- **spikes:** leaves that many spikes in the area; walking into one costs
  `spike_damage` (once per step in; standing there when they rise is safe).
  They last `trail_turns` of the enemy's turns. Spikes and fire trails stay
  even if the skill missed (Rock Spikes).

**Telegraphs** on reveal: a **red sphere** over every party member's head
for spread skills (placed circles/lines with an overlap rule; for a marked
circle, over the marked one only), and gold
**arrows sliding inward** around the area for shared-damage skills
(stack up).

**Skill choice (AI):** each skill starts from its weight, then: skills that
can't reach anyone x0.05; area hits on several people boost it a little;
placed circles/lines up to x2 when the party is bunched (they punish it);
Healing Ritual only when an ally in range is under 75% HP (more likely the
more are hurt); Defense/Counter x1.6 with a party member close, x0.5
otherwise; the last skill used x0.35 per repeat in a row.

**Sure skills by HP** (`EnemySkill.sure_below_hp`): the first time the
enemy's HP is at or below that share when it starts a cast, it prepares that
skill, no roll. Once per fight, and skipped if it has already used the skill
(for a Ceiling Burst, if it has already dropped rocks). The Stone Golem's
Ceiling Burst has 0.75, so every Golem fight gets rocks.

**Team tactics** (`team_tactics` on an enemy, on for the Kobold Archer):
partners are other enemies of the same scene with the flag. Only the first
partner in the fight uses Defense/Counter (others x0.1), and none adds a
stance while a partner holds one (x0.1). While a partner prepares an
attack: the same Power Shot x0.25, the same Ranged Attack x0.7, and a
different non-Smash attack x1.6 (Smash skills are never boosted, so Power
Shots stay as common as before). The pair ends up readying Power Shot +
Ranged Attack together. Partners closer than
`tactics_spread` (8 m) walk away from each other between casts.
**Bait timing:** a normal attack prepared while a partner prepares a Smash
(Power Shot), whichever came first, gets `bait_for`: its cast slows so it
reaches the end of the bar `bait_gap_seconds` (2.5 s of free movement,
default) after the Smash. While the Smash is still coming it isn't revealed
(grey area, "NAME - NEXT" label); once the Smash is done it's revealed and
the gap counts down in world time (`bait_gap_seconds * battle_speed`). It
never casts faster than normal, and the timeline freezes during strikes and
party turns, so the gap is pure moving time.

**Stone Golem** (960 HP, speed 20, casts at half speed), following the roster:

| Skill | Kind | Area | Damage | Wind-up | Weight |
|---|---|---|---|---|---|
| Heavy Attack | Smash | cone 70°, 5 m | 46 | 1.4 s | 3 |
| Crush | Smash | line 11 m x 1.4 m | 52 | 1.6 s | 2 |
| Rock Stomp | Attack | circle 4.5 m | 32 | 1.0 s | 3 |
| Rock Spikes | Special | circle 2.8 m on its target, then 4 spikes (16 each) for 2 Golem turns | 26 | 1.2 s | 2 |

The Golem no longer uses Defense/Counter stances (not in its roster entry).
Stances still work for any enemy that lists them.

## Timing ring on your target

- Every timed press hit of a party attack or Art also shows on the floor
  round its target: a white ring closes in at a steady rate from
  `timing_ring_lead` (0.9 s) before the hit, and a gold ring with a faint
  band marks the timing box. Press when the white ring is inside the band.
  A Perfect flashes it gold, a miss red. Same in the Command List.

## Strikes and reactions (milestone 5, built)

- An Attack/Smash that catches someone becomes a **strike**. It plays in
  **real time** (no slow-motion; a slowdown could be an item later). The
  world is paused while it plays.
- Until there are real attack animations, a **ring shrinks onto each target**.
  It turns gold for the last `parry_window` (0.15 s real time; was 0.25). A press before that is a committed miss: no second try (Expedition 33-style: read the swing, press once). Windup: Attack 1.0 s,
  Smash 1.4 s (heavier, slower to land). Only targets who can **Parry
  this strike** (their class, or a guarding Knight nearby, and a parryable
  skill) get the timing ring; the others get a plain mark: **blue** if
  Defend works for them, **red** if neither does. **The Parry key Defends
  for blue-marked fighters** (the Cleric): alone, it's a plain Defend (same
  AP); next to a Knight, one press parries for the Knight and Defends for
  the Cleric (one Defend's AP, once per multi-hit chain).
- **Parry (E)**: pressed while the ring is gold, no damage, the enemy is
  **knocked back** (pushed back 25 on the timeline), and the party's **max AP
  rises by 10** for the rest of the fight. Pressed too early: full damage,
  the target's turn is **pushed back 30** on the timeline, the party **loses
  all its AP**, and **max AP resets to 100**. One try per strike.
- **Defend (Q)**: any time before impact, costs 10 AP. You still take damage
  (25% vs Attack, 60% vs Smash because it breaks the guard), but it is
  **recoverable**: it comes back at that fighter's next turn, unless they're
  hit again first (a new hit locks the old damage in). Defending at low HP
  can still knock you out.
- **No reaction**: full damage (Attack 20, Smash 35).
- **Multi-hit strikes** (Goblin and Ogre Attack: 2 hits, Living Armor
  Combo: 3): every hit still to come shows its own fainter ring, closing in
  so it reaches the marker exactly when that hit lands (later hits come
  every 0.55 x the wind-up). Each hit can be Parried in its own window and
  the chain goes on: every Parry grows max AP, the enemy is knocked back once
  per strike. **One Defend guards the whole chain** for a single
  10 AP. Launch only happens on the last hit; max AP is lost once per chain.
- Assumption: one Parry/Defend input covers **everyone** caught in the strike.
- At 0 HP a fighter is **down** (lies on the floor, takes no turns). If the
  whole party is down, the battle ends.

## AP (decided)

- **AP is one shared party pool** that carries over between turns (VP2-style).
- **AP recharges between turns** while the timeline runs (6/s at 100 max AP,
  times battle speed). Moving no longer earns AP.
- **Attacks spend AP** (milestone 6). Swapping and Defend cost AP too.
- **Max AP grows with skill:** every successful **Parry (+10)** or
  **Perfect combo hit (+5)** raises the party's max AP **for the rest of
  the fight** (up to 100 per party member plus 100: 200 solo, 300 for two,
  400 for three, 500 for four; `max_ap_ceiling_per_member`), never past
  500 (`max_ap_limit`), so five or six also stop at 500.
  `max_ap_limit_bonus` is there for future skills or items that raise it. **Missing a Parry or a Perfect
  drops AP to 0 and resets max AP to 100**.
- **AP gain scales with max AP:** the recharge is multiplied by current max AP / 100 (1.5x at 150, 2x at 200), capped at 2x (`ap_regen_max_multiplier`) even when max AP goes higher. A big bank
  refills fast, but one missed timing drops it all back to 100.
- **Focus on the meter:** while the Mage stands still (Focus, AP +50%),
  bright chevrons race along the AP fill, the frame pulses violet, and a
  "FOCUS +50% AP" tag sits above the bar.
- **Combo counter** (`scripts/battle/combo_counter.gd`): on the right while
  a combo plays: hits, total damage, Perfects, and each hit's damage popping
  in; the total stays up for 1.6 s afterwards.
- **The AP meter** (`scripts/battle/ap_meter.gd`, drawn in code): one
  segment per 100 AP, coloured by tier (blue, teal, gold, orange, rainbow),
  with dim slots up to the max AP limit. Raising max AP sweeps the new space
  open with a flash and a "+5"; a reset shatters the extra segments with a
  red flash and "MAX AP LOST". While building a combo its cost shows as a
  dark ghost section; the turn-start +30 lights up as it fills. The fill
  flows faster with the recharge rate. Tier effects: a passing shine (2),
  a pulsing glow (3), embers (4), a cycling rainbow and a big gold number (5).
- **Skipping a timed hit** (no J on a hit's box) is just a normal hit: no
  max AP lost (`skipped_hit_max_ap_loss` 0 for now; it was 5, which felt
  too punishing).

**Boss threat:** a boss (`boss` on) locks onto whoever hurt it most lately,
not just the nearest: every party member scores its share of the boss's
threat (damage dealt to it, 0-1 against the top) minus its distance /
`threat_distance_scale` (15 m), and the best score is the target (and whom
it walks toward). Threat halves (`threat_decay` 0.5) each time the boss
starts a cast. Play-test reports count `threat_targets` (and per class)
when a cast locks onto someone other than the nearest. Before anyone has hurt it, and for regular enemies, it's the
nearest. Taunt and Vanish still come first.

Numbers (BattleArena node): `max_ap` 100 (starting cap), `starting_ap` 50,
`ap_regen_per_second` 6, `parry_max_ap_gain` 10, `perfect_max_ap_gain` 5,
`skipped_hit_max_ap_loss` 0, `max_ap_ceiling_per_member` 100, `max_ap_limit` 500, `turn_start_ap` 30. Enemies turn slowly toward
the nearest party member and only walk when roughly facing them; their base
area is a 120-degree cone in front, so the back is the safe side.

## Skill triangle (confirmed)

The skill triangle is the base of the combat flow and can grow from there.
Each skill has its own area shape so it can be read from the floor:

| Skill   | Area                    | Beats                            | Loses to                     |
|---------|-------------------------|----------------------------------|------------------------------|
| Attack  | wide cone (120°, 3.7 m) by default; each enemy sets its own | Smash (interrupts its wind-up) | Defense, Counter       |
| Smash   | narrow cone, long (50°, 4.4 m) | Defense (breaks guard), knocks down | Attack, Counter    |
| Defense | small circle (stance)   | Attack (blocked)                 | Smash                        |
| Counter | circle (stance)         | Attack and Smash, if timed       | waiting it out, (later) ranged/magic |

How the party reacts when struck:
- **Defend** = the Defense skill. Safe against Attack, fails against Smash.
- **Parry** = a timed Counter. Beats both, but a mistimed parry takes the full hit.
- Reading the enemy's loaded skill on the bar is what makes this a real choice:
  vs Attack, Defend is safe; vs Smash, you must Parry, or stay out of the area.

When the party attacks (milestone 6), enemy stances matter: attacking into
Defense is blocked unless you Smash, and attacking into Counter gets punished.

## Stagger (built)

Unavoidable enemy skills get a **Stagger bar**: the answer to a skill you
can't dodge, Parry or Defend.

- **Which skills:** only unavoidable ones (`EnemySkill.stagger_bar` > 0):
  Kobold Power Shot 30, Arcanist Fireball 30, Shaman Curse 35, Living Armor
  Dark Bolt 70, Dragon Breath 90 and Burning Spike 120, Gale Maw Inhale 70,
  Exhale 90, Undertow 80, Gale Burst 120. The size is set per skill, by how
  dangerous it is.
- **Resistance:** each Stagger makes that enemy's bars 50% (of their base
  size) bigger for the rest of the fight (`Combatant.staggers_taken`,
  `stagger_need`): the first break is easy, chaining them gets hard.
- **Slower casts:** a skill with a bar moves through the casting zone at
  half its usual speed (`stagger_cast_speed` 0.5), so the party gets about
  a turn to answer it. At full speed the party got about half a turn per
  cast and bot fights filled bars only 0-20%.
- **Filling:** damage dealt to the caster from the moment it starts
  preparing (the bar shows once the skill is revealed). Only hits from in
  front of it count (its front half; any side of a boss without
  positionals); a hit from behind pops NOT HEAD-ON. **Heavy moves** (Smash
  type, breaking moves, Arts) count 1.5x (`stagger_heavy_mult`). Burns and
  Ripostes don't fill it.
- **A full bar: STAGGERED.** The skill breaks (follow-ups included), the
  enemy is knocked back to 25 before the casting zone (`stagger_knockback`:
  it loses the skill, not a whole lap), and it takes **+25% damage**
  (`staggered_bonus`) until its next turn. Some skills change instead of
  breaking (`stagger_into`): the Gale Maw's Exhale becomes **Broken
  Exhale**, a ring with a safe middle by the Maw (8 m), push 5 m. Then the
  enemy keeps its place on the timeline.
- **Shown:** a gold bar under the enemy's HP and under its timeline marker,
  flashing past 75%. The skill label reads "STAGGER IT", the warning line
  "(stagger it head-on)". Healing Ritual (3 close hits, as pips) and
  Shadowflare (the damage that contains it) show their own rules as the
  same bar (`Combatant.stagger_view`).
- **Answer tags:** STAGGERS (this move should fill it), STAGGER +N% (how
  much it adds), NOT HEAD-ON (warning). The move details box says "Heavy:
  fills Stagger bars 1.5x faster".
- Parry's timeline push is now called **knocked back**, so "Stagger" only
  means the bar.

## Knockdown (done through other systems)

The original idea: hits build a stagger gauge (Mabinogi-style), and a full
gauge knocks the enemy down, which can push it and its area away, disable
its area for a while, or change its area's shape. All three now exist in
other forms, so this milestone is closed:
- **Push away:** knockback moves (Energy Blast, Enchant: Energy, the
  Knight's and Monk's pushes), Lightweight enemies, edge falls.
- **Disable:** interrupts and stuns (Attack beats Smash, Lightning,
  Stunning Arrow, Crusader's Edge, Hook), Stagger bars that break
  unavoidable casts, Shadowflare containment.
- **Reshape:** a full Stagger bar turns a cast into a weaker one
  (`stagger_into`: Exhale -> Broken Exhale).

## Ragdolls (built)

A party member who goes down goes limp: their body parts (not the name
label) move under a pivot at their feet (`Combatant.make_limp`) and the
arena animates it (`_tick_ragdolls`).

- **Sent flying** by a strong blow (`_strong_blow`: a push, a Smash, 40+
  damage, an instant kill): thrown away from the enemy
  (`ragdoll_fly_speed` 7.5 m/s, `ragdoll_fly_up` 8 m/s; about 1.4 m high
  and 6 m far), tumbling, one bounce, a short slide, then flat on its
  back. Walls, rocks and edges stop the slide; it never goes over a drop.
- **Flops** to anything else (small hits, burns, hazards): tips over where
  it stands, away from the hit, with a small bounce.
- A fall off the arena keeps its own drop. Revive stands the body back up
  (`Combatant.unlimp`). Reports count `ragdolls_flying` / `ragdolls_flop`.
  Test `tests/_ragdoll.gd`.

## End screens (built)

A fight ends with a short pause (`end_screen_delay`, 1.2 s), then a panel
over the frozen, dimmed battle while the camera turns slowly round the
arena (`scripts/battle/end_screen.gd`). W / S choose, J picks, K backs out
of a page; the old keys (next / previous round, Retry, O, Esc) still work.

- **Victory:** VICTORY, the round and its enemies, time and turns, and the
  rank (S / A / B / C) with the best rank so far on that round (saved in
  `settings.cfg`, section `ranks`). Choices: Next round (Back to the title
  after the last), Fight summary, Retry, Change party (party-pick rounds),
  Open play-test report, Back to the menu.
- **Rank:** four scores of 25. Health: 25 x (1 - HP missing at the end /
  the party's max HP), minus 10 per member who went down (heals count:
  total damage taken ran past the whole party's HP in most boss fights).
  Timing: 25 x Perfects / timed hits (a missed timing counts as a
  chance). Reading: 25 minus 3 per mistake of yours (avoidable hits on
  the fighter you steer, `avoidable_hits_you`; early Parries; missed
  timings); AI allies' hits don't count. Pace: full at or under the
  round's `Encounter.par_seconds` (Golem 150, Living Armor 180, Dragon
  195, Gale Maw 195; 180 elsewhere), zero at twice it. S 85+, A 70+, B
  50+, else C.
- **Fight summary:** the four scores as bars with what set them, a row per
  member (HP, damage dealt and taken, turns, went down / revived), then
  time and turns, Perfects, Parries, highest max AP, Arts found, items used.
- **Defeat:** DEFEAT, the enemies' HP left. Choices: Retry, What went
  wrong, Change party, Open play-test report, Back to the menu. **What
  went wrong:** each enemy's HP bar, the 3 sources that did the most
  damage (AVOIDABLE where the report counted avoidable strikes; falls
  count), who went down to what (the report's last hit before each
  down), and one tip on the worst avoidable source: the skill's own
  `EnemySkill.tip`, otherwise one from its rules (lethal, shared damage,
  growing, pushes, can't be Parried, can be Parried).
- **Change party** opens the party picker for this round (after a loss) or
  the next (after a win). **Tutorial:** TUTORIAL COMPLETE with Back to the
  title and Play again.
- Reports count `timed_hits`, `timing_misses`, `arts_found`, `max_ap_peak`.
  Tests `tests/_endscreen.gd` (DEFEAT=1 for the loss), screenshots
  `tests/_shotend.gd`.

## Items (built)

Every fight starts with a pouch (`pouch_potions` 3, `pouch_ethers` 2,
`pouch_revives` 1 on the BattleArena node), refilled each round; nothing
carries over. The tutorial starts empty until its Items lesson. Items are
shared by the whole party and shown under the AP bar.

| Item | Target | Effect |
|---|---|---|
| Potion | an ally or yourself, any distance | heals 35% of the target's max HP |
| Ether | the party | restores 40% of current max AP, never past it |
| Revive | a downed ally | back up with 50% of max HP, timeline from 0; after a fall off the arena, at the party's start |

- **One per turn, in the Ability slot:** Items opens a list like Abilities
  (counts instead of AP; greyed out with none left or nothing to use it
  on). Using one closes both Abilities and Items for the turn; Attack and
  Wait stay open. No AP cost. Data: `scripts/battle/items.gd`.
- **Revive is safe from the cast in progress:** enemies preparing a skill
  when someone is revived can't hit them with it (`revive_safe`, cleared
  when that enemy's skill ends). What was lost on going down (Marks, the
  Monk's climb, Focus, statuses) stays lost.
- **AI allies** (`_ai_item`, before their Ability; never Ethers): the Revive
  on a downed ally; a Potion on themselves under `ai_potion_below` (35%) HP
  when no Cleric is standing with 25 AP for Healing.
- Command List: an Items group with the counts left. Reports count
  `items`, `items_potion`, `items_ether`, `items_revive`, `revives`,
  `ai_items`. Test `tests/_items.gd`.

## Party attacks (milestone 6, built; reworked)

- **The command menu opens on each party turn**: Attack / Abilities / Wait /
  Items, with Defend: Q / Parry: E as reminders. W/S choose,
  J (or Enter) select, K back.
- **Attack opens the combo bar** (inspired by Legend of Legaia) with the
  class's own attacks. J adds the selected move, K removes the last one,
  **Space begins**. The bar is as long as the **class's AP** (Knight 60,
  Archer 70, Mage 50 + Focus, Cleric 60); moves are **paid from party AP**, and the
  part you can't afford right now is shown locked (red hatching).
- **Target:** if more than one enemy is in reach, Attack first asks which
  one (W / S cycles, a gold ring marks it, J confirms, K goes back); the
  default is the nearest in the fighter's normal reach, otherwise the nearest
  a long-range attack can reach (Holy Light). With only one
  choice it goes straight to the combo bar, which shows the target's name. Moves that can't reach the target are greyed out. If the target
  falls mid-combo, the rest goes to the nearest enemy still in reach.
- The combo plays hit by hit, then **the turn ends**. While it plays, the
  menus hide and the bar drops to a strip at the bottom with a **white
  playhead**, after a 1 s **READY** lead-in.
- **Timing boxes:** every hit has its own box ending where it lands.
  J inside = **Perfect** (+50% damage, max AP +5). J outside = the chain
  ends and max AP resets. No press = a normal hit (no max AP lost).
- **Timing types** (`timing` in `moves.gd`, applied to a move's last hit):
  - **Press** (default): the box above.
  - **Hold** (Archer: Power Draw and its Hold Arts; Cleric: Divine Barrier): press in the first box
    (ending at `hold_start` of the block), keep holding through the tail,
    let go in the box at the hit = Perfect. Let go early, still holding at
    the hit, or a late start = **partial**: no Perfect, no penalty, normal
    damage. Pressing before the first box is a normal miss.
  - **Code** (the Mage's spells: WASD arrows, see the Mage).
  - **Fast-forward:** once nothing is left to press anywhere in the combo
    (every box done or past, no Hold, code or useful taps left), the rest
    plays 5x faster (`exec_fast_forward`).
  - **Tap** (the Monk's Tap Arts, Tortoise Special's open Tap): tap J
    `taps` times between `tap_start` and the hit. All taps = Perfect; some
    = partial with +50% x taps/needed damage (no max AP); none = a normal
    skipped hit. Taps before the stretch are ignored; **one tap past the
    count is a miss** (chain ends, AP 0, max AP resets).
  - Hold moves land at 85% of their block (`times`), leaving a gap after
    the let-go before the next move.
  - Look: Press = white square boxes; Hold = blue (`HOLD_COLOR`) rounded
    pills with ▼ / ▲ and a tail that lights up while held; Tap = pink
    (`TAP_COLOR`) dashed stretch with one diamond per tap. Gold still means
    Perfect and red a miss. The move list shows a matching HOLD / TAP n
    badge. Reports count `perfects_hold` and `perfects_tap`.
- **Skill triangle, per hit and per enemy hit:** a **Counter** stance
  punishes the attacker (33 damage) and stops the combo; **Defense** blocks
  basic attacks, piercing moves ignore it, breaking moves break it; an
  **Attack-type hit on an enemy preparing Smash** interrupts it.
- At the start of each party turn the party **gains 30 AP** on top of what
  it has (up to max AP). (Was: topped up to 30.)
- **Attack is greyed out** unless some attack can reach an enemy *and* fits
  the party's AP and the class's bar ("not enough AP" vs "no enemy in
  reach"); Holy Light reaches 9 m but costs 30.
- **Attack area preview:** the highlighted move or skill draws the area it
  would hit (target circle, self circle or line, the same shapes the hit
  uses) and a ring under each fighter it would hit, fainter for falloff
  damage; bright when usable, dim when not. Divine Barrier shows its circle
  and the allies inside. In the combo bar the command panel hides, the move
  list is see-through, and the camera centres between attacker and target.
- **Knocked-out fighters** no longer push anyone; defeated enemies sink away
  after 2 seconds.

## Classes (built)

- **One Ability per turn:** using a skill doesn't end the turn. The command
  menu comes back with the used Ability shown as a chip in its colour with a
  tick ("Brace ✓"), so you can still Attack or Wait. The fighter's timeline
  icon carries a small diamond badge with the Ability's initial until the turn
  ends (with Windup timing: until its committed attack at ACT is done). A turn
  head start an Ability gives (Shield Bash) is applied when the turn ends.
- **Windup timing:** once a committed attack reaches ACT and the combo bar
  opens, it can't be backed out of to the command menu (only if no move is
  affordable does backing out end the turn).

Pronouns (they become full characters later): Knight they/them, Archer she, Mage she, Assassin he, Cleric she, Monk he.

All numbers are in `scripts/battle/moves.gd`. Damage = the fighter's
attack_power x the hit's multiplier.

### Knight (200 HP, attack 15, 60 AP, can Block and Parry)
Basic moves (the only ones in the menu):

| Attack | AP | Hits | Notes |
|---|---|---|---|
| Slash | 10 | 1.0 | basic |
| Thrust | 15 | 1.4 | ignores Defense |
| Guard Strike | 15 | 0.9 | **halts** the enemy: its timeline stops for 0.5 s (`freeze`; it keeps its place and its cast). Once per enemy action: until it acts again, more shield blows don't halt it ("NO HALT"), so it can't be locked. **Draws its aggro**: it targets the Knight for one of their turns, each more shield blow adds a turn (up to 3, `aggro_max_turns`; once per move, however many hits; their own Taunt is never shortened) |

**Arts** (`Moves.arts()`): when the moves on the bar spell a recipe, they
merge into the Art. The bar reads left to right and takes the longest
recipe that fits; an Art costs what its moves cost but hits harder, and the
longer ones add effects. Each plays as one block with its own hits and
timing boxes.

**Timing boxes are what you see:** a box is the move's `window` (seconds
before the hit), but drawn at least `BattleMenu.MIN_BOX_PX` (14 px) wide,
and presses are judged with that same drawn width
(`BattleMenu.box_fraction`). This matters most for the Monk: his
half-speed playhead draws the same window half as wide, so a bar of only
Arts (Triple Rush, Mountain Crusher) had 8.6 px windows inside 14 px boxes
until this was fixed.

| Recipe | Art | AP | Hits (parts) | Effect |
|---|---|---|---|---|
| Slash + Slash | Double Slash | 20 | 1.25 x2 = 2.5 (2.0) | basic |
| Slash + Thrust | Lunge | 25 | 2.6 (2.4) | ignores Defense |
| Guard Strike + Slash | Shield Rush | 25 | 1.2 x2 = 2.4 (1.9) | halts it 1 s (same once-per-action rule); draws its aggro |
| Guard Strike + Guard Strike | Shield Wall | 30 | 1.5 (1.8) | sweep around the Knight (3 m circle): stops every enemy hit 0.5 s (from Guard Strike) and draws its aggro; 10% max HP barrier to allies within 3 m |
| Thrust + Thrust + Slash | Smash | 40 | 4.2 (3.8) | Smash type, breaks Defense; knocks it 4 m back only if it wasn't defending |
| Slash + Slash + Thrust + Guard Strike | Crusader's Edge (finisher) | 50 | 1.4 + 1.4 + 3.2 = 6.0 (4.3) | breaks Defense, cancels its attack (a stun, once per enemy action), knocks it 3 m back and the Knight follows (stays in reach); draws its aggro |

**Discovery** (`scripts/arts_book.gd`, `user://arts.cfg`): undiscovered Arts
are a surprise. They don't merge while building and aren't named anywhere;
the **Arts panel** lists only discovered Arts (recipe, and "next: X" when the
end of the bar is heading towards one) plus each hidden one's length, AP and
what still blocks it ("four-move, 35 AP (needs bar 50)", "needs Crowd
Cheer"). **Hints**, never the name: a played bar that gets moves of a hidden
recipe right in place adds them ("??? Thrust + Thrust + ?  (2 of 3)"; 2 right
for 3+ move Arts, 1 right for 2-move Arts with the pair inside the bar;
hints add up across bars, saved in `arts.cfg`). An Art made of Arts you
already know shows as those Arts ("??? Palm Strike + Knee Smash  (Arts you
know)", from `recipe_text`). When a combo plays, the bar is also read with the hidden recipes
(`_find_hidden_arts`); when the playhead reaches the first block of one, its
blocks merge with a white flash, the combo pauses (`art_reveal_seconds`,
1.4 s) on a **NEW ART!** banner with the Art's name, then the Art plays. From
then on it merges while building and appears in the list. Reports count
`arts` and `art_<name>`.
**Move details** (`scripts/battle/move_info.gd`, drawn by
`BattleMenu._draw_move_details`): while choosing moves or Abilities, a box
left of the list explains the highlighted one: cost and timing, then every
effect in plain words (damage, how to time it, area, Defense, control,
support, Marks, tokens). Attacks and Arts are described from their fields,
so a new field needs one line in `MoveInfo._attack_lines`; Abilities have
written text in `MoveInfo.SKILL_TEXT`. The Arts panel's Tab details use the
same lines. On by default; the pause menu's "Move details: On/Off" toggles
it, saved in `user://settings.cfg` (`scripts/settings.gd`).
**Answer tags** (`BattleArena._update_answer_tags`, every frame while picking
moves or Abilities): moves that answer what the target is doing right now get
a coloured pill and row outline. Green: INTERRUPTS (an Attack-type hit on a
revealed Smash; "INTERRUPT 1/3" on bosses), BREAKS GUARD / PIERCES (vs
Defense), STUNS, HALTS, FROM BEHIND. Amber: PARTLY BLOCKED, NO STUN / NO HALT
(already used since it last acted). Red: BLOCKED, COUNTERED (Counter stance),
MISSES (Backstab-type moves from the front). Once a breaking move is on the bar against a
defending target, the rest are no longer tagged BLOCKED / PARTLY BLOCKED
(the guard will be down by the time they land). Abilities are read against the
strikes the warning shows: COUNTERS IT (Riposte, Suplex), BLOCKS IT (Arcane
Barrier), HALVES IT (Brace), SHAKES IT (Vanish) when one is coming at the
steered fighter; STOPS IT (Hook) on an enemy preparing an attack in range;
DRAWS IT (Taunt, Provoke) when one is aimed at an ally in range. Only
revealed skills count. The details box opens with a "NOW:" line explaining
the tag. Arts in the Arts panel get the same tags.
**Picking from the list:** Tab (`swap_character`) in the combo bar moves the
cursor into the Arts panel (known Arts only); Confirm adds the whole recipe
at once, locked as that Art (`_combo_locks`), so moves before it can't
steal part of it. Removing one of its moves unlocks it.
Every class has Arts now.

| Skill | AP | Effect |
|---|---|---|
| Light Heal | 25 | heals 20% of max HP |
| Brace | 20 | takes 50% less damage, 2 Knight turns |
| Shield Bash | 30 | rushes next to an enemy within 9 m (in sight); next turn starts a third of the way along, like Wait |
| Taunt | 40 | enemies within 6 m go after the Knight for 3 Knight turns; meanwhile they **guard**: allies within 3 m (`guard_radius`) are covered by Block and Parry even if their class can't do them |

### Archer (150 HP, 60 AP, speed 12, cannot Block or Parry)
| Attack | AP | Hits | Notes |
|---|---|---|---|
| Shoot | 10 | 1.0 | basic |
| Power Draw | 20 | 1.8 | Hold; 1.2 s, the arrow flies at 85% of the block |
| Exposing Shot | 15 | 0.9 | **exposes** the enemy: every party hit on it deals +15% (`exposed_bonus`) until its own next turn starts (status `exposed`, shown as EXPOSED). Named so it isn't confused with the Assassin's Marks. (It was Pinning Shot; pinning now comes only from Arrow Rain.) |

**Arts:**

| Recipe | Art | AP | Hits (parts) | Effect |
|---|---|---|---|---|
| Shoot + Shoot | Double Shot | 20 | 1.15 x2 = 2.3 (2.0) | basic |
| Shoot x3 | Triple Shot | 30 | 0.95 + 0.95 + 1.5 = 3.4 (3.0) | last arrow delayed (20%, 40%, 100%) and ignores Defense (`last_hit`) |
| Shoot + Power Draw | Piercing Arrow | 30 | 3.3 (2.8) | Hold (1.5 s); LINE 1.2 m wide, full damage to the first enemy and 75% to the rest (`falloff`), ignores Defense |
| Exposing Shot + Power Draw | Stunning Arrow | 35 | 3.1 (2.7) | Hold (1.5 s); an enemy preparing an attack loses it and drops back to just before the casting zone (like an interrupt). Once per enemy action (see turn control) |
| Power Draw + Power Draw | Gale Shot | 40 | 4.2 (3.6) | Hold (1.8 s); breaks Defense, pushes 4 m away |
| Exposing Shot + Shoot + Shoot + Power Draw | Arrow Rain (finisher) | 55 | 1.6 + 1.6 + 2.6 = 5.8 (4.7) | three volleys on a 2.5 m circle at the target; breaks Defense, **pins** everyone hit: they can turn but not walk until their own next turn starts (status `pinned`) |

Shoot chains only get better as they grow: Triple Shot (3.4) beats Double
Shot + Shoot (3.3), and Double Shot x2 (4.6) beats four Shoots read as
Triple Shot + Shoot (4.4). When adding Arts, check them against other Arts made from the same
moves, not only against their plain parts.

| Skill | AP | Effect |
|---|---|---|
| Jump | 30 | move a marker with WASD (up to 8 m) and leap there |
| Siphon Shot | 30 | (replaced Riposte) one enemy within 6 m is **Siphoned** for 3 of her turns: each of **her** hits on it heals her 3% of her max HP, 6% on a Perfect (`_siphon`). Her answer to damage she can't dodge: she has no Block or Parry. AI Archer: casts it when under 70% HP |
| True Sight | 40 | every ally's reach +25% (moves with their own reach too), and enemy attacks are revealed as soon as they start preparing (at the casting zone, not at `reveal_at`), 3 Archer turns |
| Agility | 60 | the Archer's attacks get one extra hit at half the first hit's strength (`agility_hit_share`), 5 Archer turns |

### Mage (100 HP, 50 AP + Focus, can Parry, cannot Block)

The elemental caster (design in the "Mage Rework" doc). Four elements; any two
to four of them on the bar, **in any order** (`any_order`), make an Art. Every
spell reaches **5 m** (her own reach too; the Archer keeps the longest, 6).

**Focus** (`focus_max` 5 and `focus_bar_per` 10 on the Mage; `focus_*` on
BattleArena; `_tick_focus`): her bar starts at **50 AP**. From the start of
every fight, standing still builds a charge every 2 s of battle time (up to
5), each +10 AP of bar for her next combo (up to 100). Walking 2 m loses one
(no Windup exemption); teleports and pushes don't count as walking.
Attacking (her combo, or the AI's) spends them all (`_spend_focus`: the bar
played keeps its size), and they rebuild. **While she stands still, the
party's AP refills 50% faster** (`focus_ap_bonus`; the AP meter shows violet
chevrons and "FOCUS +50% AP"). Her HUD tag reads "FOCUS 3  BAR 80".

**Spell codes** (CODE timing, Helldivers-style; `_judge_code`): each element
is a WASD direction: **Fire W (up), Ice S (down), Lightning A (left), Energy
D (right)**. While a spell casts, type its code (arrows on its block) before
the hit = **Perfect**. The code is the spell's elements in **bar order** (Ice
then Fire = S W; `_parse_combo` sets it). A wrong direction **starts the code
over**; an unfinished code is a normal hit with **no penalty** (no miss, no
max AP lost); the confirm key does nothing. Multi-hit Arts (Thunder) have one
code, due before the last hit (earlier hits land by themselves). The window
is the block, so its length comes from the cost. **Energy** (Energy Blast,
Arcane Barrage, Arcane Overload): type the code, then tap J freely: every tap
adds its share (`surge`) up to the cap; the code is the Perfect. Reports
count `perfects_code` and `code_restarts`.

| Attack | AP | Hits | Notes |
|---|---|---|---|
| Fire | 20 | 1.2 | Code W. **Burns** every enemy hit: 35% of the Mage's attack (5) each time it acts, for its next 2 actions (refreshed, not stacked; `burn`, `burn_turns`; ticks in `_enemy_unleash`). A line from the Mage through the target and 6 m beyond: 100% on the first enemy, 75% behind it; rocks block it |
| Ice | 20 | 1.0 | Code S. Everyone within 1.8 m of the target; **chills** them: half walking speed until their own next turn (status `chilled`). **Makes Fire cheaper** (below) |
| Lightning | 20 | 1.0 | Code A. Single target; **interrupts** the attack it's preparing (`stun`) |
| Energy Blast | 25 | 0.9, +10% per tap | Code D, then free taps: every tap adds 10% (`surge`), up to 10; taps past the cap are ignored. Single target, **pushed 3 m** |

**Ice discount** (`ice_discount_*` on BattleArena): every Ice on the bar takes
20% off each Fire after it (and the Fire in the same Art: Steam Burst's Ice
discounts its own Fire), up to 40%. A combo with any Ice also takes 20% off her
Fire on her next turn (`ice_carry`). Never more than 50% in all. The bar, the
AP cost and the move list's prices all show the discounted cost.

**Arts** (19, the most in the party; any order):

| Recipe | Art | AP | Hits | Effect |
|---|---|---|---|---|
| Fire x2 | Fireball | 40 | 3.3 | everyone within 2.2 m of the target; **Burn x2** (`burn_stacks`: each tick hits twice over) |
| Fire x3 | Inferno | 60 | 0.6 now, 6.0 later | marks a 3 m circle at the target that **explodes 3 s later** (running time; `delayed_blast`, `_blasts`): everyone still inside takes 6.0 and Burn x3; enemies can walk out |
| Ice x2 | Blizzard | 40 | 2.6 | everyone within 3 m of the target, all chilled |
| Ice x3 | Ice Spear | 60 | 3.6 | **Freeze** (`deep_freeze`): a regular enemy can't move and its timeline stops for 3 s, and its turn is pushed back 15. **Bosses** only lose turn time: 15, then half as much each time (`freeze_resist`) |
| Lightning x2 | Chain Lightning | 40 | 2.4 | jumps to the 2 nearest other enemies within 5 m of the target at 75% (`chain`); interrupts each |
| Lightning x3 | Thunder | 60 | 0.9 + 0.9 + 2.0 | the last strike stuns a regular enemy (`stun_not_bosses`) and fills Stagger 3x (`stagger_mult`) |
| Energy x2 | Arcane Barrage | 50 | 1.5, +12% per tap | code, then free taps (up to 12); pushes 4 m |
| Energy x3 | Arcane Overload | 75 | 2.8, +12% per tap | code, then free taps (up to 15): her biggest single hit; pushes 8 m; **20 AP back** (`ap_refund`) |
| Fire + Energy | Flare | 45 | 1.8 | **detonates every burning enemy**: all its Burn left (damage x stacks x turns) at once, Burn ends (`detonate_burns`). No push |
| Ice + Energy | Shatter | 45 | 2.0 | **Frozen: 2.5x** and the Freeze ends; **Chilled: 1.6x**; otherwise 0.6x (`shatter`). No push |
| Lightning + Energy | Overcharge | 45 | 2.0 | interrupts even a boss immune to cancels right now (not UNSTOPPABLE moves; `ignore_cancel_lock`); 3x Stagger fill. No push |
| Fire + Ice | Steam Burst | 36 | 2.8 | within 1.2 m of the target (her focused spell), breaks Defense; burns and chills |
| Fire + Lightning | Plasma | 40 | 2.6 | burns it and interrupts its attack |
| Ice + Lightning | Static Frost | 40 | 2.2 | chills and interrupts; a target **already Chilled freezes** (2 s, turn pushed 10; bosses only lose turn time, as Ice Spear; `freeze_if_chilled`) |
| Fire + Ice + Lightning | Tri-Disaster | 56 | 3.6 | Burn, Chill and an interrupt on everyone within 2.5 m of the target |
| Fire + Ice + Energy | Thermal Shock | 61 | 5.0 | breaks Defense: the heavy Defense-breaker. No push |
| Fire + Lightning + Energy | Nova | 65 | 3.4 | everything within 4 m of the Mage: burns and interrupts it all, her escape. No push |
| Ice + Lightning + Energy | Stasis | 65 | 1.0 | every enemy: a regular one's timeline stops 3 s; a boss only loses 8 turn time, halved each time (`stasis`, `stasis_resist`). No interrupt, no push |
| Fire + Ice + Lightning + Energy Blast | Meteor (finisher) | 81 | 6.0 | every enemy anywhere, breaks Defense, Smash type; doesn't take the push or the interrupt from its parts (`no_inherit`) |

Energy mixes and Meteor drop the push their Energy Blast would give
(`no_inherit`). Costs above already count the Ice discount on their own Fire (Steam Burst,
Tri-Disaster, Thermal Shock, Meteor); an Ice earlier in the combo takes more off.

**Arts list:** recipes read "Fire x3" when they repeat one element, and the
header says "moves in any order merge". When the Arts don't all fit (the
Mage's 19), the list splits into **pages turned with A/D** (page number top
right; W/S in the focused list moves through pages too, and the list jumps to
the page of the Art the bar is heading for). More than 6 hidden Arts are
summed up by length.

**Party AI Mage** stands still in reach to build Focus (she walks only when the
enemy is out of her reach or right on top of her), and casts Enchant when none
is running (`_ai_enchant_pick`: Lightning while a Stagger bar is up, Ice
against 3+ enemies, Fire otherwise). `_ai_mage_value`: her Arts are valued by how many enemies
they'd hit (areas, Chain Lightning, Inferno's circle), Flare by the Burn it
would detonate, Shatter by Frozen / Chilled, Overcharge double on a boss cast
that's immune to cancels, Ice Spear and Stasis higher on an enemy preparing
an attack.

| Skill | AP | Effect |
|---|---|---|
| Arcane Barrier | 30 | the next hit on the Mage does nothing |
| Enchant | 30 | choosing it opens a small **element menu** (only then): a direction picks the element, as in her spell codes: Fire up (W), Ice down (S), Lightning left (A), Energy right (D); back closes it. Every ally **but her** carries the element for 2 of her turns (statuses `enchant_*`, tag "ENCHANT FIRE"); one at a time, a new one replaces it (`_enchant`, `_enchanted`). Their hits add a light effect: Fire a 1-turn Burn (20% of their attack; `enchant_burn`), Ice a Chill, Lightning 1.5x Stagger fill (`enchant_stagger_mult`), Energy a 1 m push (`enchant_push`). Replaced Concentrate |
| Teleport | 30 | blink to a spot within 8 m (marker, like Jump), or press Tab to snap the marker to an ally at any distance and appear next to them |

### Cleric (130 HP, 60 AP, can Block, cannot Parry)
| Attack | AP | Hits | Notes |
|---|---|---|---|
| Bash | 10 | 0.5 (flurry) | **Flurry:** each Bash right after another in the same combo hits 0.1 harder (0.5, 0.6, 0.7, 0.8, then 0.9 for the rest; `flurry`, `flurry_max`, `_apply_flurry`); any other move in between restarts it. **Rally:** each Bash that lands raises the party's max AP by +5 (a Perfect adds its usual +5: +10 in all), up to the usual ceiling; a mistake resets it like any growth. The only move that grows max AP on purpose. Arts made with Bash don't rally |
| Holy Light | 20 | 1.2 | reach 9 m; breaks Defense |
| Divine Barrier | 20 | 1.0 | Hold (1.5 s): gives allies within 4 m a barrier of 10% of their max HP; a Perfect let-go makes it 15% within 5.5 m (the preview shows both circles) |

**Arts** (no Art is Bash + Bash alone, so a row of Bashes stays Bashes,
each one rallying; support effects come with the Art's last hit):

| Recipe | Art | AP | Hits (parts) | Effect |
|---|---|---|---|---|
| Bash + Holy Light | Smite | 30 | 2.4 (1.7) | breaks Defense; pushes 3 m |
| Holy Light + Holy Light | Judgment | 40 | 3.2 (2.4) | reach 9 m, everyone within 2 m of the target, breaks Defense |
| Bash + Divine Barrier | Blessed Strike | 30 | 2.2 (1.5) | Hold; heals allies within 4 m by 8% of max HP (Perfect 12%) |
| Divine Barrier + Divine Barrier | Sanctuary | 40 | 2.4 (2.0) | Hold; barrier 20% within 6 m (Perfect 28% within 7.5 m) |
| Bash + Holy Light + Bash + Divine Barrier | Divine Judgment (finisher) | 60 | 1.2 + 1.2 + 2.6 = 5.0 (other reading: Smite + Blessed Strike = 4.6) | breaks Defense; heals the whole party 15% and gives everyone a 10% barrier |

| Skill | AP | Effect |
|---|---|---|
| Healing | 25 | an ally (or self) heals 25% of their max HP |
| Shielding | 40 | every ally gets a shield of 15% of their max HP |
| Haste | 40 | an ally moves along the timeline 25% faster (`haste_timeline_bonus`: their turns come sooner) and runs 20% faster, for 2 of **their** turns |
| Full Cure | 60 | an ally is fully healed |
| Lifeline | 30 | dash beside another ally within 8 m (out of whatever she stood in); she and that ally each heal 15% of their max HP. AI: when she stands in a revealed area and an ally in reach stands clear, or both are under 60% HP |

### Assassin (170 HP, 50 AP, cannot Block or Parry: auto-parries with Marks)
Fast (speed 14), melee reach, timeline icon "As". **Behind** = within 60°
of the enemy's back (a 120° cone). **Assassin's Marks** sit on enemies (up
to 5, "MARK x3" over the enemy, violet diamonds by its timeline icon) and go
when it falls. While any Mark is out, a strike that can be parried is
**auto-parried** (a normal Parry: knocks back, max AP up), spending one Mark
(from the attacker if it has one, else the enemy with the most). All its
attacks have **random timings**; the first move of a combo always lands
between 50% and 95% of its block. Its moves play slower than the Knight's
(Stab 0.8 s, Shadowstep 1.1 s, Backstab 1.2 s, Execute 1.6 s) so the boxes
are easier to spot. When not steered it walks round behind
its focus enemy (`flanks`).

| Attack | AP | Notes |
|---|---|---|
| Stab | 10 | 1.0; 1.5x from behind; every 3rd Stab hit on a Marked enemy adds a Mark |
| Shadowstep | 20 | teleports behind the target, then hits: 1.5x if it started in front; reaches any Marked enemy at any range, and moves after it on the bar count as in reach |
| Backstab | 25 | 2x from behind and adds a Mark; misses from the front |
| Execute | 100 | 4x from behind, and +15% per Mark it spends (`mark_bonus`: 4 Marks 6.4x); -15 AP per Mark on the target (min 40: fits the 50 AP bar at 4 Marks, the most an enemy can carry, so only one per bar); spends all the target's Marks |

**Arts** (Execute is never part of a recipe, so its Mark discount stays its
own). Multi-hit Arts keep random timings: the block is cut into one stretch
per hit and each hit lands somewhere in its own stretch, so boxes never
overlap; as an opener the first stretch starts at 35%. Marks marked "+N" are
added by the last hit (`last_hit: {"add_marks": N}`).

| Recipe | Art | AP | Hits | Effect |
|---|---|---|---|---|
| Stab + Stab | Twin Fangs | 20 | 1.1 x2 (1.5x each from behind) | both count as Stab hits for growing Marks |
| Shadowstep + Stab | Ambush | 30 | 2.4 x1.5 = 3.6 | teleports behind first; +1 Mark; reaches Marked enemies anywhere; kicks it 3 m away |
| Shadowstep + Shadowstep | Phantom Rush | 40 | 1.8 x2, 1.5x from behind = 5.4 | teleports behind; +1 Mark; reaches Marked enemies anywhere |
| Stab + Backstab | Cutthroat | 35 | 1.3 x2, x2 from behind = 5.2 | a Mark per hit from behind (+2); misses from the front |
| Stab + Shadowstep + Stab | Thousand Cuts (finisher) | 40 | 0.8 x6, x1.5 from behind = 7.2 (other reading: Stab + Ambush = 5.1) | only forms on a target with **2+ Marks** (`needs_marks`) and spends 2 as it starts (`spend_marks`), so its cuts can't grow them back; teleports behind |

| Skill | AP | Effect |
|---|---|---|
| Hook | 20 | enemy within 6 m: stops what it's preparing (or its stance), pulls it 2 m closer, spends its Marks |
| Death Sentence | 40 | enemy within 6 m: 3 Marks |
| Shadow Cloak | 50 | any Marked enemy: its Marks become a shield of 10% max HP each (17 per Mark) |
| Vanish | 25 | enemies stop targeting the Assassin (while anyone else stands) until it attacks or 2 of its turns pass |

### Monk (160 HP, a bar that climbs 30 / 50 / 80 / 100, can Block and Parry)

**Half-speed playhead** (`Combatant.playhead_speed` 0.5): his moves are cheap,
so at the usual 15 AP per second Flash Kick's whole Hold took 0.33 s and
Palm Strike's 3 taps 0.59 s. At half speed a 5 AP move lasts as long as a
10 AP move does for anyone else.
A combo class built on **build, then cash out**. Every move is weak on its
own; the Monk climbs his bar through three Arts, then spends the whole climb
at once with Tortoise Special and starts again. Sturdy enough to tank, and
tanking feeds the climb. (Design write-up: "Monk Rework: Build and Cash
Out".)

**Party AP, his own bar.** He pays from party AP like everyone; what's his
own is his **bar length** (combo limit), which steps 30 -> 50 -> 80 -> 100.
Every **climb Art** (Knee Smash, Triple Rush, Mountain Crusher) raises it
one step, whichever step he's on; mistakes drop it a step; Tortoise Special
spends it back to 30; a knockout resets it and his tokens.

**Seeing the climb.** On his own turn, pips over his head (one per step,
lit when climbed) with his tokens under them; small pips beside his
timeline icon; while building, the bar continues past its end with notches
at the steps still to climb ("next step: a climb Art"); a preview under the
bar for the Art at its end ("Uses Triple, Rush (+30%) · Step: bar 80 ·
Perfect: +Crusher"), shown above the AP meter while it plays, with the
Perfect part struck out once a timing wasn't Perfect; and a banner, "STEP 2 ·
BAR 80" or "STEP LOST". HP panel: "BAR 80  RUSH".

**Three outcomes per Art.**

| How the Art went | The Monk gets |
|---|---|
| Every timing Perfect | its step **and** its tokens (inner Arts' tokens too) |
| Sloppy but no miss (late let-go, a tap short, a skipped press) | its step only; it still uses up the tokens it consumes |
| A miss (wrong press, the chain ends) | nothing, and he loses his newest token (the climb holds) |

**Losing a step** (an avoidable hit he takes, a Parry pressed too early):
the bar drops one step and he loses his newest token, Crowd Cheer last
("-1 STEP"). A miss in his own combo only costs the newest token ("-1
TOKEN"): the climb holds. Deep Breath gives the last lost step back.

**Tokens** stay between turns until an Art uses them up; each one used up
adds **+10%** to that Art's damage. Sources: Arts played all Perfect, a
Parry while Provoke is active (+1 Rush), a Suplex counter (+1 Mountain).
**Crowd Cheer** comes from any climb Art played all Perfect that reaches the
top (or is played there); sloppy at the top means bar 100 but no cash-out
yet.

**Timed hits.** Punch (3 hits) and Kick (2 hits) have **no timing**
(`timed: "none"`): every hit lands by itself (a small tick on the bar, no
box), and presses during them are ignored. They used to have one timed hit
each, which at 5 AP meant a press every third of a second. Heavy punches use
Tap, heavy kicks Hold & Release; the Arts keep their timings.

**Headbutt restarts the bar.** When more moves follow a Headbutt (or
Tortoise Special, which ends in one), a fresh bar of his full length
follows it, paid from party AP like the rest. Once per combo
(`bar_resets_per_combo`). While building, everything before the Headbutt
folds into a small "+70 AP" tag; while the combo plays, an Art that gives a
buff takes its blocks off the bar, and the fresh bar's moves appear once
the Headbutt lands. The bar keeps its scale for the whole combo.

| Attack | AP | Notes |
|---|---|---|
| Punch | 5 | 0.15 x3; no timing |
| Kick | 5 | 0.25 + 0.2; no timing |
| Heavy Punch | 20 | 1.5; Tap x4; cancels a turn about to strike (stun) |
| Heavy Kick | 20 | 1.5; Hold; breaks Defense |
| Headbutt | 30 | 2.6; restarts the bar when more moves follow |

**Arts.** Each is built out of the smaller ones (the Legaia "Arts inside
Arts" idea, see below). Only the Art actually played raises the bar, not the
smaller ones inside it. The Arts list writes a recipe as its smaller Arts
once they're all known ("Heavy Punch + Flash Kick + Triple Rush"), else as
moves, shortened to initials when long ("P P P P K HK").

| Recipe | Art | AP | Timing | Uses up | Perfect: gives | Climbs |
|---|---|---|---|---|---|---|
| P P | Palm Strike | 10 | Tap x3 | | Triple | |
| K K | Flash Kick | 10 | Hold | | Mountain | pushes 3 m, the Monk follows (stays in reach) |
| K HK | Knee Smash | 25 | Hold | | Rush | one step |
| Palm Strike + Knee Smash (P P K HK) | Triple Rush | 35 | 2 presses + Hold; ignores Defense | Triple, Rush | Crusher | one step |
| Heavy Punch + Flash Kick + Knee Smash (HP K K K HK) | Mountain Crusher | 55 | 3 presses + Tap x6; 2.5 m circle | Mountain, Crusher | Triple | one step |

Hits: Palm Strike 1.0, Flash Kick 1.0, Knee Smash 2.5, Triple Rush 0.6 + 0.6 + 3.2 = 4.4, Mountain Crusher 0.9 + 0.5 + 0.5 + 4.4 = 6.3 (raised in the class review so his climb Arts out-damage the Knight's; Palm Strike and Flash Kick now beat their parts).
| HP HK Headbutt | Tortoise Special (finisher) | 70 | 2 presses, then an **open tap with no limit** (from 40% of the block to the hit; +4% damage per tap, 30 taps is a Perfect; `surge_uncapped`); breaks Defense; restarts the bar | Crowd Cheer, the whole climb | | back to 30 |

At bar 30 only Knee Smash fits, so every climb opens the same way; from bar
50 he picks the climb Art that fits the turn. The three feed each other:
Knee Smash leaves Rush for Triple Rush, Triple Rush leaves Crusher for
Mountain Crusher, Mountain Crusher leaves Triple for Triple Rush. Bigger
climb Arts hit harder per AP (measured, perfect, attack 16: Knee Smash 2.1
per AP, Triple Rush 3.2, Mountain Crusher 2.8 on one target, more on a
group).

**Tortoise Special** only forms (and can only be played) while he holds
Crowd Cheer, so from bar 80 up. Its cash-out grows steeply: **1.5x at bar
80, 2.5x at bar 100**.

Measured with perfect timing (attack 16, vs a Knight's perfect Crusader's
Edge at 163): Tortoise at 100 + Knee Smash on the fresh bar ~320; a late
turn of Tortoise at 100 + Mountain Crusher on the fresh bar (125 AP of
party AP) ~420. Tunable in moves.gd (hits, `cashout`) and
`token_damage_bonus`.

| Skill | AP | Effect |
|---|---|---|
| Provoke | 20 | one enemy within 6 m targets the Monk until his next turn; each Parry meanwhile gives +1 Rush |
| Suplex | 20 | counter stance for 4 s: the attacker takes 2x attack and is thrown 3 m; +1 Mountain |
| Deep Breath | 30 | heal 20% of max HP; gives back the last step he lost |

### Shared rules
- **Durations count the caster's turns**: "3 turns" runs out when the
  caster's third turn after using it begins. Riposte runs on
  seconds instead, counted while the timeline runs.
- **Barriers and shields** soak up damage before HP and stack, up to half
  of max HP. Shown as a light-blue strip on the HP bar. **Each one is its
  own stack that lasts 2 of its caster's turns** (`Combatant.SHIELD_TURNS`,
  counted like other effects); a new shield adds a stack and never
  refreshes older ones. Damage uses up the oldest stack first.
- **Damage order on a party member:** Arcane Barrier (ignores the hit) ->
  Brace (halves it) -> shields -> HP.
- **The Knight is the tank:** most HP (200), Brace for damage, Taunt for the
  room, and their guard while Taunt lasts. The Monk (160 HP) tanks one enemy
  at a time and for himself; he out-damages the Knight instead.
- **Block / Parry per class:** one E or Q press still covers everyone caught
  in a strike, but only those whose class can parry/block benefit; the rest
  take the full hit. A missed Parry only penalizes classes that can parry.
- **Turn control is once per enemy action.** Halts (Guard Strike, Shield
  Rush) and stuns (Stunning Arrow, Crusader's Edge) set the enemy's
  `control_used`; until it acts again (`_enemy_unleash` clears it), more of
  them do nothing ("NO HALT", "NO STUN"), so no class can lock an enemy. A
  stun cancels the attack and drops it to just before the casting zone
  (`_cancel_enemy_skill`). The skill triangle's interrupts (an Attack-type
  hit on a Smash wind-up) are not limited this way.
- **"Pushes back"** (Gale Shot, Tempest, Riposte) is a physical shove across
  the arena, stopped by walls and rocks.
- Effects show as tags next to the HP bars (BRACE 2, SHIELD 26, RIPOSTE 3s...).

### Parked for later (from the earlier attack design)

- **Action timer:** attacking freely on a timer that each hit extends.
- **Bait and counter:** pausing mid-attack so the enemy strikes, parrying it
  for extra time; limited per enemy (`baits_per_turn`, 1-3 by enemy type).
- **Climbing AP costs:** the 4th+ attack in a turn costing 15, 20, 25...
  These could come back as their own mode or ability.

### Parked for later: Arts inside Arts (Legend of Legaia "tech")

In Legaia, if one Art's inputs fit inside part of another combo, that Art
still counts there. Today the bar takes one reading (longest known recipe
first, left to right), so an Art that overlaps a bigger one is swallowed by
it. Keep this in mind when designing more Arts: recipes that nest inside
each other could become a deliberate trick (and a whole can of worms for
how the bar merges, costs and reveals them).

**First step (Monk):** an Art can list the smaller Arts inside it
(`contains`). The bar still reads one way, but when the big Art plays, the
tokens of the Arts inside it are given first, so they still "count". Full
nesting (several readings, costs) is still parked.

## Open questions

- Should AI allies ever attack on their own, or only the fighter you control?
- Should each character have their own move list (Mage spells, Archer shots)?
- Balance: random test play wins most fights. The Golem (240 HP) may need
  more HP, damage, or a second enemy once the full fight is in.
- Should a successful Parry also deal damage back, or refund AP?
- Should each party member react separately when several are caught in one
  strike, instead of one input covering everyone?
- Can downed fighters be revived (item, skill), or are they out for the battle?
- Should the party see a hint while an enemy's skill is hidden (for
  example, Attack vs. Smash wind-up looking different), or stay fully blind?
- Do party members load skills in the casting zone too (Grandia-style
  commands), or do they act directly?
