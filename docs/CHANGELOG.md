# Development history

How the battle system evolved, including ideas that were tried and changed.
Newest first. Detailed current rules live in `battle-design.md`.

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
