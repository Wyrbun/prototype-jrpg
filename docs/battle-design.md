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
- The last stretch of the bar (from 73) is the **casting zone**. An enemy
  entering it **prepares a skill**. This is the Mabinogi "visible skill
  loading", told the Grandia way.
  - **Where, then what:** as soon as the enemy enters the zone its area
    appears on the floor **in grey** ("..." above it, "???" on the bar): you
    see where it will land, not what it is. The skill is **revealed** at
    `reveal_at` (88): its name, and the area in color (live: it glows and
    warns whoever is inside).
  - While preparing, the enemy **stands still** and **tracks the party
    member it locked onto** when the cast began (or whoever taunted it) at
    its full turning speed. In the last `cast_slow_seconds` (1 s) it slows
    to `cast_turn_speed_degrees` (40°/s): that's the window to slip out.
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
- When a party turn ends, control goes back to whoever you were steering
  before it (after back-to-back turns, to whoever you steered before the
  first of them).
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
     into one. Danger = a revealed Attack/Smash, anything still being
     prepared ("..."), fire trails and rock spikes. A circle or line that
     follows this ally while hidden is ignored until revealed (it can't be
     outrun). Circles that punish overlaps (Dark Bolt, Burning Spike) keep
     allies a full circle apart: they spread out.
  3. **Stand near the edge of their attack range** from their focus enemy
     (`ally_range_share`, 80% of reach): close in if too far, back off if much
     too close, detouring around danger. Focus = an enemy casting Healing
     Ritual (they close within its interrupt range, so your hits break it),
     then the caster of a growing circle not yet contained, otherwise the
     nearest enemy.

## Play-test reports (built)

Every fight outside the tutorial saves a report when it ends (or when you
leave it with N, P or Esc after at least one turn), in the game's user data
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
- Enemies and allies **steer around** obstacles; an enemy without a clear
  view of its target keeps walking until it has one.
- Rounds 6-9 use the Round 10 arena for now (no mockup yet).

## Title screen and tutorial (built)

- The game opens on the **title screen** (`scenes/ui/title_menu.tscn`):
  Boss Rush, Tutorial, Round Select, Controls, Quit. Keyboard (W/S, J/Enter,
  K/Esc) or mouse. **Esc** in a fight returns here.
- The **tutorial** (`scripts/battle/tutorial.gd`) is one continuous guided
  fight: Knight vs Training Golem in a small arena with one rock
  (`data/tutorial.tres`). It's a list of steps:
  - **Notes** pause the whole fight until J / Space.
  - **Goals** let the fight run until done (checked against counters the
    battle keeps: parries, perfects, waits, guard breaks...).
  - Each step can set up the fight first: hold a fighter on the timeline,
    make the Golem repeat a skill, or have it prepare one and freeze the
    moment it's revealed (a held enemy doesn't strike or walk).
- Lessons: 1 Moving, 2 The timeline (reach ring, your turn), 3 Combos, timed
  hits and Wait, 4 Reading the enemy (dodge a revealed Attack), 5 Parry and
  Defend, 6 The skill triangle (Thrust/Smash through Defense, Wait out
  Counter, interrupt Smash), 7 Abilities (Archer joins, then Mage and
  Cleric), 8 Max AP, 9 Rocks (the Golem waits with Long Strike revealed and
  strikes once you're hidden behind the rock), 10 Free practice (the Golem
  fights normally and can be defeated).
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
  `contain_share` of its max HP during the cast stops it (Shadowflare).
- **Heal allies:** heals enemies in a circle; `interrupt_hits` party hits
  from within `interrupt_range` break it (Healing Ritual).
- **On marked:** one circle on the party member the enemy locked onto
  (follows while hidden, locks on reveal). Hits everyone inside; can only be
  Parried if the target is alone in it (Fireball, Rock Spikes).
- Also per skill: **hits** (multi-hit, a ring per hit, a Parry stops the
  rest), **launch** (last hit throws targets), **shared damage** (100%,
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
  (2 s: the enemy waits near the end of the bar). Everyone pushed gets an
  orange sphere and is hit wherever they go; anyone else can still dodge it
  (Shout, then Sword Spin: run into its safe middle).
- **Mechanic skills (UNAVOIDABLE):** they can't be dodged, only answered.
  Revealed with "UNAVOIDABLE" above the enemy and "(unavoidable)" in the
  warning line.
  - `always_hits` (placed circles and lines): everyone it was placed on is
    hit wherever they stand; a rock still blocks a line (Dark Bolt, Burning
    Spike, Curse, Fireball, Rock Spikes).
  - `always_hits_target`: the locked target is hit however far it runs,
    unless a rock blocks the enemy's view (Breath, Power Shot).
  - `hits_everyone` (growing circles): the explosion hits the whole party
    for damage scaled by its final size, at least 25% (Shadowflare: contain
    it early).
- **Avoidable hits cost max AP:** when a strike lands on someone who didn't
  Parry or Defend, and it could have been avoided, the party loses one
  segment (100) of bonus max AP, once per strike (`avoidable_hit_max_ap_loss`).
  Dodgeable skills always count; mechanic skills only when the answer was
  missed: caught in an overlap, taking a stack skill alone, not alone under a
  marked circle, or a growing circle never contained. Fire and spikes don't
  count. While anyone stands where a revealed strike would cost max AP, that
  segment of the meter pulses red with a "!". Reports count them per skill.
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
  this share of its speed (Shadowflare 0.6: more time to contain it;
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
can't reach anyone x0.2; area hits on several people boost it a little;
placed circles/lines up to x2 when the party is bunched (they punish it);
Healing Ritual only when an ally in range is under 75% HP (more likely the
more are hurt); Defense/Counter x1.6 with a party member close, x0.5
otherwise; the last skill used x0.35 per repeat in a row.

**Stone Golem** (960 HP, speed 20, casts at half speed), following the roster:

| Skill | Kind | Area | Damage | Wind-up | Weight |
|---|---|---|---|---|---|
| Heavy Attack | Smash | cone 70°, 4.2 m | 46 | 1.4 s | 3 |
| Crush | Smash | line 8 m x 1.4 m | 52 | 1.6 s | 2 |
| Rock Stomp | Attack | circle 2.6 m | 26 | 1.0 s | 3 |
| Rock Spikes | Special | circle 2.8 m on its target, then 4 spikes (16 each) for 2 Golem turns | 26 | 1.2 s | 2 |

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
  the fight** (up to 100 per party member plus 100: 200 solo, 500 with
  four; `max_ap_ceiling_per_member`). **Missing a Parry or a Perfect
  resets max AP to 100**, and any AP above 100 is lost.
- **AP gain scales with max AP:** the recharge is multiplied by current max AP / 100 (1.5x at 150, 2x at 200), capped at 2x (`ap_regen_max_multiplier`) even when max AP goes higher. A big bank
  refills fast, but one missed timing drops it all back to 100.
- **The AP meter** (`scripts/battle/ap_meter.gd`, drawn in code): one
  segment per 100 AP, coloured by tier (blue, teal, gold, orange, rainbow),
  with dim slots up to the max AP limit. Raising max AP sweeps the new space
  open with a flash and a "+5"; a reset shatters the extra segments with a
  red flash and "MAX AP LOST". While building a combo its cost shows as a
  dark ghost section; the turn-start +30 lights up as it fills. The fill
  flows faster with the recharge rate. Tier effects: a passing shine (2),
  a pulsing glow (3), embers (4), a cycling rainbow and a big gold number (5).
- **Skipping a timed hit** (no J on a hit's box) costs **5 of the extra max
  AP** (`skipped_hit_max_ap_loss`), never going below 100. Opting out is
  safe but slowly drains the bonus.

Numbers (BattleArena node): `max_ap` 100 (starting cap), `starting_ap` 50,
`ap_regen_per_second` 6, `parry_max_ap_gain` 10, `perfect_max_ap_gain` 5,
`skipped_hit_max_ap_loss` 5, `max_ap_ceiling_per_member` 100, `turn_start_ap` 30. Enemies turn slowly toward
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

- **The command menu opens on each party turn**: Attack / Abilities / Wait /
  Items (placeholder), with Defend: Q / Parry: E as reminders. W/S choose,
  J (or Enter) select, K back.
- **Attack opens the combo bar** (inspired by Legend of Legaia) with the
  class's own attacks. J adds the selected move, K removes the last one,
  **Space begins**. The bar is as long as the **class's AP** (Knight 60,
  Archer 70, Mage 90, Cleric 60); moves are **paid from party AP**, and the
  part you can't afford right now is shown locked (red hatching).
- **Target:** if more than one enemy is in reach, Attack first asks which
  one (W / S cycles, a gold ring marks it, J confirms, K goes back); the
  default is the nearest in the fighter's normal reach, otherwise the nearest
  a long-range attack can reach (Holy Light, Meteor Strike). With only one
  choice it goes straight to the combo bar, which shows the target's name. Moves that can't reach the target are greyed out. If the target
  falls mid-combo, the rest goes to the nearest enemy still in reach.
- The combo plays hit by hit, then **the turn ends**. While it plays, the
  menus hide and the bar drops to a strip at the bottom with a **white
  playhead**, after a 1 s **READY** lead-in.
- **Timing boxes:** every hit has its own box ending where it lands.
  J inside = **Perfect** (+50% damage, max AP +5). J outside = the chain
  ends and max AP resets. No press = a normal hit (costs 5 of the extra
  max AP).
- **Skill triangle, per hit and per enemy hit:** a **Counter** stance
  punishes the attacker (33 damage) and stops the combo; **Defense** blocks
  basic attacks, piercing moves ignore it, breaking moves break it; an
  **Attack-type hit on an enemy preparing Smash** interrupts it.
- At the start of each party turn the party **gains 30 AP** on top of what
  it has (up to max AP). (Was: topped up to 30.)
- **Attack is greyed out** unless some attack can reach an enemy *and* fits
  the party's AP and the class's bar ("not enough AP" vs "no enemy in
  reach"); Meteor Strike reaches anyone but costs 90.
- **Knocked-out fighters** no longer push anyone; defeated enemies sink away
  after 2 seconds.

## Classes (built)

All numbers are in `scripts/battle/moves.gd`. Damage = the fighter's
attack_power x the hit's multiplier.

### Knight (200 HP, 60 AP, can Block and Parry)
| Attack | AP | Hits | Notes |
|---|---|---|---|
| Slash | 10 | 1.0 | basic |
| Thrust | 20 | 1.2 | ignores Defense |
| Double Slash | 15 | 0.7 x2 | basic |
| Smash | 30 | 2.2 | Smash-type, breaks Defense |

| Skill | AP | Effect |
|---|---|---|
| Light Heal | 25 | heals 20% of max HP |
| Brace | 20 | takes 50% less damage, 3 Knight turns |
| Shield Bash | 30 | rushes next to an enemy within 9 m (in sight); next turn starts a third of the way along, like Wait |
| Taunt | 60 | enemies within 6 m go after the Knight for 3 Knight turns |

### Archer (150 HP, 70 AP, cannot Block or Parry)
| Attack | AP | Hits | Notes |
|---|---|---|---|
| Shoot | 10 | 1.0 | basic |
| Triple Shot | 25 | 0.6, 0.6, 0.7 | lands at 20%, 40% and 100% of the block (last one delayed) |
| Stunning Arrow | 40 | 1.0 | an enemy preparing an attack loses it and goes back to the start of the bar |
| Gale Shot | 45 | 1.6 | breaks Defense, pushes the enemy 4 m away |

| Skill | AP | Effect |
|---|---|---|
| Jump | 30 | move a marker with WASD (up to 8 m) and leap there |
| Riposte | 40 | counter stance for 4 s: a strike on the Archer is countered (2x attack power) and the enemy is pushed 3 m away |
| True Sight | 50 | every ally's reach +25% (moves with their own reach too), 3 Archer turns |
| Agility | 70 | the Archer's attacks get one extra hit, 5 Archer turns |

### Mage (100 HP, 90 AP, can Parry, cannot Block)
| Attack | AP | Hits | Notes |
|---|---|---|---|
| Energy Blast | 15 | 1.0 | everyone within 1.8 m of the target |
| Firebolt | 30 | 1.6 | a line from the Mage through the target and 6 m beyond: 100% on the first enemy, 75% behind it; rocks block it |
| Tempest | 45 | 1.2 | everyone within 3.5 m of the Mage, pushed 6 m away |
| Meteor Strike | 90 | 1.8 | every enemy, anywhere; breaks Defense |

| Skill | AP | Effect |
|---|---|---|
| Arcane Barrier | 20 | the next hit on the Mage does nothing; the Mage's next combo costs double |
| Concentrate | 40 | AP recharges twice as fast for 10 s |
| Teleport | 60 | appear next to a chosen ally |

### Cleric (130 HP, 60 AP, can Block, cannot Parry)
| Attack | AP | Hits | Notes |
|---|---|---|---|
| Bash | 10 | 0.8 per hit, x0.75 per earlier Bash | the 1st Bash has 1 hit, the 2nd 2 hits, and so on, but each hit is weaker (0.8, 0.6, 0.45, 0.34...): six Bashes deal 7.1x attack in 21 timed hits (was 16.8x); from the 4th Bash the hits land at random moments |
| Divine Barrier | 25 | 1.0 | also gives allies within 4 m a barrier of 10% of their max HP |
| Holy Light | 30 | 1.4 | reach 9 m; breaks Defense |

| Skill | AP | Effect |
|---|---|---|
| Healing | 25 | an ally (or self) heals 25% of their max HP |
| Shielding | 40 | every ally gets a shield of 30% of their max HP |
| Haste | 50 | an ally runs 20% faster, 3 Cleric turns |
| Full Cure | 60 | an ally is fully healed |

### Shared rules
- **Durations count the caster's turns**: "3 turns" runs out when the
  caster's third turn after using it begins. Riposte and Concentrate run on
  seconds instead, counted while the timeline runs.
- **Barriers and shields** soak up damage before HP and stack, up to half
  of max HP. Shown as a light-blue strip on the HP bar.
- **Damage order on a party member:** Arcane Barrier (ignores the hit) ->
  Brace (halves it) -> shields -> HP.
- **Block / Parry per class:** one E or Q press still covers everyone caught
  in a strike, but only those whose class can parry/block benefit; the rest
  take the full hit. A missed Parry only penalizes classes that can parry.
- **"Pushes back"** (Gale Shot, Tempest, Riposte) is a physical shove across
  the arena, stopped by walls and rocks.
- Effects show as tags next to the HP bars (BRACE 2, SHIELD 26, RIPOSTE 3s...).

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
