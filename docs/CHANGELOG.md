# Development history

How the battle system evolved, including ideas that were tried and changed.
Newest first. Detailed current rules live in `battle-design.md`.
Player-facing notes per public build are in `RELEASES.md`.

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
