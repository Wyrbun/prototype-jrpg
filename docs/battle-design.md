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
- After acting, the fighter goes back to the start of the bar.
- The last stretch of the bar (from 75) is the **casting zone**. An enemy
  entering it **prepares a skill**. This is the Mabinogi "visible skill
  loading", told the Grandia way.
  - **Intent is hidden at first** ("..." above it, grey "???" on the bar),
    so you can't prepare too easily. The skill is **revealed late**, at
    `reveal_at` (90), on the bar, above the enemy, and as a live area.
  - While preparing, the enemy **stands still** and can only **turn slowly**
    (`cast_turn_speed_degrees`, 40°/s), so its area sweeps toward you.
  - **Defense/Counter** stances are active for the **whole casting zone**
    (from 75, even while hidden) and **linger for `stance_linger` (3 s)
    after the enemy's turn**, counted while the timeline runs. The enemy holds
    its ground (turning slowly) while a stance is up.
  - **Which skill** is picked from the enemy's own skill list, by weight
    (see "Enemy skills" below). Its name and area show only on reveal.
  - Attack/Smash fire at the end of the bar, or early if you touch the
    revealed area.
  - **Idea (later): per-character reveal.** Each character could see hidden
    skills earlier depending on type: some read **defensive** skills
    (Defense/Counter) early, others read **offensive** ones (Attack/Smash)
    early. Who you control (or swap to) then changes how much you know.
    Likely implementation: a per-character reveal threshold for each skill
    type, used in place of the global `reveal_at` for the fighter you control.
- Planned: hits from behind or well-timed counters knock enemies back on the bar
  (the Grandia "cancel").

## Positioning and turns (current test setup)

> Testing a new flow. The previous version is saved in
> `backups/before-positioning-test.zip`.

- **Between turns** (timeline running): you steer one party member in real
  time with WASD. Enemies and AI allies also move in real time.
  **Moving is free** and earns no AP. **Tab** switches which party member
  you steer (free), so you can position each of them.
- **On a party turn**, time freezes and that fighter is **locked in place**.
  The command menu opens automatically: **Attack** (needs an enemy in reach),
  **Wait**, Abilities, Items (placeholders).
- **Wait** ends the turn without spending AP; the fighter's bar restarts at
  `wait_head_start` (33) instead of 0, so the next turn comes sooner.
- If several party members are ready at once, their turns come up back to back.
- **Battle speed** (`battle_speed`, 0.7 = 30% slower) slows the timeline,
  enemy and ally movement, and AP recharge together. The fighter you steer,
  strike rings and combo timing aren't slowed.
- Every enemy shows its area on the floor: **dormant** (faint, harmless)
  most of the time, including while the skill is hidden, and **live** once
  revealed. A party member touching a live Attack/Smash area (by walking in,
  or the enemy turning onto them) makes it strike right away, which also
  spends the enemy's turn.
- **Ally AI** (party members you aren't steering), in priority order:
  1. **Stay out of danger:** leave any enemy area that could hit, never step
     into one. Danger = a revealed Attack/Smash, or anything still being
     prepared ("...").
  2. **Stand near the edge of their attack range** from the nearest enemy
     (`ally_range_share`, 80% of reach): close in if too far, back off if much
     too close, detouring around danger.

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

**Stone Golem** (240 HP), following the roster:

| Skill | Kind | Area | Damage | Wind-up | Weight |
|---|---|---|---|---|---|
| Heavy Attack | Smash | cone 70°, 4.2 m | 35 | 1.4 s | 3 |
| Crush | Smash | line 8 m x 1.4 m | 40 | 1.6 s | 2 |
| Rock Stomp | Attack | circle 2.6 m | 20 | 1.0 s | 3 |
| Rock Spikes | Special | targeted hazard | | | later |

The Golem no longer uses Defense/Counter stances (not in its roster entry).
Stances still work for any enemy that lists them.

## Strikes and reactions (milestone 5, built)

- An Attack/Smash that catches someone becomes a **strike**. It plays in
  **real time** (no slow-motion; a slowdown could be an item later). The
  world is paused while it plays.
- Until there are real attack animations, a **ring shrinks onto each target**.
  It turns gold for the last `parry_window` (0.25 s). Windup: Attack 1.0 s,
  Smash 1.4 s (heavier, slower to land).
- **Parry (E)**: pressed while the ring is gold, no damage, the enemy is
  **staggered** (pushed back 25 on the timeline), and the party's **max AP
  rises by 10** for the rest of the fight. Pressed too early: full damage,
  the target's turn is **pushed back 30** on the timeline, the party **loses
  half its AP**, and **max AP resets to 100**. One try per strike.
- **Defend (Q)**: any time before impact, costs 10 AP. You still take damage
  (25% vs Attack, 60% vs Smash because it breaks the guard), but it is
  **recoverable**: it comes back at that fighter's next turn, unless they're
  hit again first (a new hit locks the old damage in). Defending at low HP
  can still knock you out.
- **No reaction**: full damage (Attack 20, Smash 35).
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
  the fight** (up to `max_ap_ceiling`, 200). **Missing a Parry or a Perfect
  resets max AP to 100**, and any AP above 100 is lost.
- **AP gain scales with max AP:** the recharge is multiplied by current max AP / 100 (1.5x at 150, 2x at 200). A big bank
  refills fast, but one missed timing drops it all back to 100.
- **Skipping a timed hit** (no J on a hit's box) costs **5 of the extra max
  AP** (`skipped_hit_max_ap_loss`), never going below 100. Opting out is
  safe but slowly drains the bonus.

Numbers (BattleArena node): `max_ap` 100 (starting cap), `starting_ap` 50,
`ap_regen_per_second` 6, `parry_max_ap_gain` 10, `perfect_max_ap_gain` 5,
`skipped_hit_max_ap_loss` 5, `max_ap_ceiling` 200. Enemies turn slowly toward
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

## Knockdown (ideas)

Hits build a stagger gauge (Mabinogi-style). A full gauge knocks the enemy
down, which can:
- push it, and its area, away from the party,
- disable its area for a while,
- or change its area to a different shape.

## Party attacks (milestone 6, built; reworked)

- **J opens the command menu** (fighter name, Attack / Abilities / Items,
  with Defend: Q / Parry: E as reminders). W/S choose, J select, K close.
  Abilities and Items are placeholders. Attack needs an enemy within the
  fighter's `attack_reach` (Fighter 0.8 m, Mage 3 m, Archer 6 m; shown by
  the gold ring around each fighter).
- **Attack opens the combo bar** (inspired by Legend of Legaia): a move list
  on top and a bar below. J adds the selected move, K removes the last one,
  **Space begins** the combo. Moves (`scripts/battle/moves.gd`):

  | Move           | AP | Hits        | Effect                         |
  |----------------|----|-------------|--------------------------------|
  | Slash          | 10 | 1 x 1.0     | single hit                     |
  | Thrust         | 15 | 1 x 1.1     | pierces Defense                |
  | Double Slash   | 15 | 2 x 0.7     | two hits                       |
  | Overhead Smash | 30 | 1 x 2.2     | Smash-type, breaks Defense     |

- **Bar length = the fighter's `combo_limit`** (Fighter 60, Archer 50,
  Mage 45), so the bar grows for characters with longer combos. Moves are
  **paid from party AP**; the part of the bar you can't afford right now is
  shown locked (red hatching).
- The combo plays hit by hit, then **the turn ends**. While it plays, the
  menus hide and the bar drops to a strip at the bottom with a **white
  playhead** sweeping through it.
- A **1 s "READY" lead-in** (`combo_lead_in`) sits in front of the strip;
  the playhead crosses it before the first move starts, so the player can
  get ready. J presses during the lead-in are ignored.
- **Each move has its own animation timing** (`duration`: Slash 0.55 s,
  Thrust 0.7 s, Double Slash 0.9 s, Overhead Smash 1.2 s), so the playhead
  speeds up and slows down per block. Hits land along the block, the last one
  at its end. Players can time off the playhead or (later) the animations.
- **Timing boxes:** every **hit** has its own box (`window`, ~0.15 s) ending
  where that hit lands, so Double Slash has two (middle and end of its block).
  - **J inside a box = Perfect** for that hit: +50% damage on it, and
    **max AP rises by 5** for the rest of the fight. Box turns gold.
  - **J outside the next hit's box = miss:** box turns red, **the chain ends
    immediately** (AP already spent stays spent), and **max AP resets to 100**.
  - **No press:** normal hit, chain continues (confirmed). Timing is an
    optional risk, like Legend of Legaia.
- **Skill triangle, per hit:** a **Counter** stance punishes the first hit
  (25 damage) and stops the combo; **Defense** blocks normal hits, Thrust
  pierces it, Overhead Smash breaks it (cancels the stance, knocks the enemy
  back 30); an **Attack-type hit on an enemy preparing Smash** interrupts it.
- At the start of each party turn **AP is topped up to 30**.

### Parked for later (from the earlier attack design)

- **Action timer:** attacking freely on a timer that each hit extends.
- **Bait and counter:** pausing mid-attack so the enemy strikes, parrying it
  for extra time; limited per enemy (`baits_per_turn`, 1-3 by enemy type).
- **Climbing AP costs:** the 4th+ attack in a turn costing 15, 20, 25...
  These could come back as their own mode or ability.

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
