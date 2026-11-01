# Development history

How the battle system evolved, including ideas that were tried and changed.
Newest first. Detailed current rules live in `battle-design.md`.

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
