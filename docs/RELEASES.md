# Release notes

Player-facing notes for each public build (Windows and Linux). The full development history is
in [`CHANGELOG.md`](CHANGELOG.md).

**Versions:** `0.MINOR.PATCH` while the game is a prototype. MINOR goes up
for new content or design changes, PATCH for fixes and tuning only. The
version shows in the bottom-right corner of the title screen and at the top
of every play-test report.

**Making a release:**

1. Bump `application/config/version` in Project Settings (and the Windows
   preset's file/product version in the export settings).
2. Export both presets (Project > Export > Export All): Windows Desktop and Linux.
3. Pack them:
   - Windows: zip the .exe as `PrototypeJRPG-<version>-windows.zip`
   - Linux: `tar -czf PrototypeJRPG-<version>-linux.tar.gz "Prototype JRPG.x86_64"`
     (Windows 10 and 11 have `tar` built in: run it from a terminal in the builds folder)
4. Add a section below, then publish a GitHub Release tagged `v<version>`
   (a pre-release while under 1.0) with both files attached.
5. Point the README's "Current build" line and its two download links at
   the new version.

---

## 0.9.0: Items, end screens, ragdolls

- **Items:** every fight starts with a pouch of 3 Potions, 2 Ethers and 1 Revive, shared by the party and shown above the AP bar. Using one takes the turn's Ability slot: one Ability or one item, and you can still Attack or Wait
    - Potion: an ally (or you) heals 35% of their max HP, at any distance
    - Ether: the party gets back 40% of its max AP
    - Revive: a downed ally gets back up with half their HP; whatever an enemy is preparing right then can't hit them
- **AI allies use items too:** the Revive on a downed ally, and a Potion when they're low and no Cleric can heal them. Never Ethers
- **Victory screen:** a rank from S to C (Health, Timing, Reading and Pace, 25 points each) with your best rank per round, and a Fight summary page showing where the rank came from
- **Defeat screen:** Retry first, and a What went wrong page: the enemy's HP left, what hurt most (avoidable ones marked), who went down to what, and a tip
- **Both screens:** Next round, Retry, Change party (from Round 8), Open play-test report and Back to the menu, over the frozen battle while the camera circles the arena
- **Ragdolls:** a party member who goes down is thrown across the arena by a strong blow (a push, a Smash, a big hit, an instant kill), or flops over where they stand otherwise. Revive stands them back up
- **Smarter allies:** AI allies no longer push an enemy while it prepares an attack whose area moves with it (no more Golem Smashes shoved onto the party), and they back off when their target raises a Counter stance instead of attacking into it
- **Tutorial:** a new Items lesson (use a Potion, Revive the Archer)
- **Fixes:** the Counter lesson no longer gets stuck if you attack into the stance; the Assassin lessons no longer error if a turn is still playing when they start; the old knocked-out pose no longer leaves the nose floating in the air

## 0.8.0: Mage rework, Command List, smarter allies

- **Mage rework:** four elements you type as codes while the spell casts: Fire (W), Ice (S), Lightning (A), Energy (D). Any two or three on the bar, in any order, make one of 19 Arts. Ice makes Fire cheaper. Her spells reach 5 m
- **Focus:** the Mage's bar starts at 50 AP. Standing still builds Focus (+10 AP of bar each, up to 5) and makes the party's AP refill 50% faster. Walking loses it, attacking spends it
- **Enchant** (Mage): pick an element with a direction and every other ally carries it for 2 of her turns: Fire burns, Ice chills, Lightning fills Stagger bars faster, Energy pushes
- **Attack effects for everyone:** every class's attacks and Arts have effects timed to the bar, with extra flair on a Perfect. Enemy hits, Parries, Defends, Staggers, heals and shields show too
- **Timing ring on the target:** each timed hit draws a ring that closes in on the enemy, with a gold band for the timing box, so you can watch the fight instead of the bar
- **Combos fast-forward** once there's nothing left to press
- **Command List** (pause menu): every character's Attacks, found Arts and Abilities, with a live preview of each. **Practice** any attack at real battle size and speed, and toggle a **Counter drill** (Tab) to practise counter-parries
- **Archer: Siphon Shot** replaces Riposte: Siphon an enemy, and her hits on it heal her
- **Cleric: Lifeline** (new): dash to an ally within 8 m, out of whatever you stood in, and both of you heal 15% of max HP
- **Gale Maw review:** Deep Breath, a black mouth while it inhales (knock a Gust Sprite into it to make it choke), pulls in teal, a preview of a combo's second half, and the floor each rock shelters drawn clear. Maw Bite covers its whole front out to 8 m and is the only move you can Parry. Under half HP: Double Gale Lanes, Gale Burst and Gale Draw
- **Gust Sprites** are Lightweight: every hit knocks them back, walls bounce them, and a drop finishes them. They can't be killed otherwise, stand still, and explode after 25 s
- **Dragon Hatchling review:** hotter fire that lasts 5 turns (3 lines at most), a new Scorch and Breathe combo, and Wings of Fire at half HP: four lines of fire across the arena that stay. Burning Spike hits for less, comes up less often and is easier to break, but its fire lasts longer below half HP
- **Living Armor:** Shadowflare is a phase at 50% and 20% HP. Once its sprites are hit or it reaches full size, it waits long enough for anyone inside to walk out. Doom Gaze sits still on the arena and always drops a rock to hide behind, even in a corner
- **Stone Golem:** its Smashes can be Defended (still no Parry), and Crush turns faster at the end
- **Tighter Parry timing:** the gold window is 0.15 s
- **Party AI:** allies dodge revealed attacks much sooner, don't walk into grey areas, keep away from ledges while a push is coming, split up to hit Shadowflare's sprites, and the Mage and Cleric keep off a boss's front. The Cleric heals sooner and puts heals first
- **Fixes:** an Enchant (or any effect) no longer lasts forever when its caster goes down. The tutorial's Counter lesson no longer gets stuck if you attack into the stance. AI allies heading in to attack hide from Doom Gaze first. The AP bar no longer runs over the enemy's name when it's very long

## 0.7.0: Party AI, enemies that land their hits

- **Party AI (new, optional):** turn it on in the pause menu and everyone you aren't steering plays their own turns instantly: they attack with the Arts you've found (and the ones you haven't, without revealing them), heal, shield and buff, and leave enough AP for your turns. Their hits deal 80% damage. Tab still takes any of them over; the party list marks them **AUTO**
- **Play style, asked once:** the first time you start Continue, Boss Rush or Round Select, a page asks for Windup or Classic turns and Party AI on or off, with a short explanation. Both can be changed later in the pause menu
- **Windup: a pick out of reach isn't wasted.** If the enemy you chose is still out of reach after the grace, the fighter attacks the nearest enemy in reach instead ("SWITCHES TARGET")
- **Short attacks are hard to dodge up close:** regular Attacks and Smashes keep turning toward a target in melee range right up to the hit, and the enemy steps after you if you back off. Up close, Parry or Defend. Rock Stomp follows you too
- **Lines keep tracking:** long lines (Crush, Power Shot, Wind Slash, Fire Wave...) keep turning in their last second, so you can't simply outrun them sideways. Use a rock, get out of range, or Parry / Defend
- **Bosses go after whoever hurts them most** (weighed against distance), not just whoever is nearest
- **Stone Golem:** a single Golem Smash only shows which half it hits at the reveal; the double Smash shows its first side early and gives 2 s to cross for the second. Crush locks onto someone far away unless a Knight's Taunt holds the Golem
- **Parry rings only where they work:** only fighters who can Parry a strike get the shrinking gold ring. The others get a mark: blue if they can Defend, red if nothing works
- **AI allies dodge like a player:** they react after a skill is revealed instead of leaving its grey area at once, and the Knight and Monk stand their ground against short melee attacks, letting your Parry or Defend cover them

## 0.6.0: Hold Tab, Monk fixes, tougher bosses

- **Hold Tab to choose who to steer:** between turns, holding Tab stops time and opens a **STEER WHO?** panel with everyone's HP. Pick with A/D, the arrows, the mouse wheel or 1-4 (the camera follows), and let go of Tab to take control. A quick tap still switches to the next party member
- **Monk: timing boxes count everywhere they're drawn.** His half-speed playhead made the real timing window narrower than the box on screen, so presses in the left part of a box (Triple Rush, Mountain Crusher) were misses. Now anything inside the box counts
- **Monk: the bar stays put.** Earning a step or a token mid-combo no longer shrinks the bar and slides the next timing box under the playhead
- **Tortoise Special is a tap frenzy:** after its two opening presses, tap as fast as you can, with no limit. Every tap adds damage, and 30 taps is a Perfect
- **Bosses are tougher:** they hit 15% harder, and the solo boss rounds run 20% faster (bosses act more often)
- **Living Armor always uses Shadowflare** once it drops to 70% HP
- **The round's opening tip stays up** long enough to read (up to 18 s), instead of vanishing at the first turn or message
- **No more lost turns during Doom Gaze:** a fighter hiding behind the rock now waits in cover, then walks in and attacks once the gaze is over, instead of the turn becoming a Wait

## 0.5.0: Windup turns and boss mechanics

- **Windup turns, now the default:** you choose a fighter's move at the gold **command point**, then time runs while they wind up toward **ACT**. Attack picks any enemy, so steer into reach before the turn lands (out of reach, it becomes a Wait). The old way is still there: *Command timing: Classic* in the pause menu. The tutorial is rewritten for it
- **One Ability per turn, and you can still attack after it.** The Ability you used shows as a chip in the menu and a badge on the timeline
- **Counter-parry:** hit an enemy in Counter stance and the combo stops; press the hit key on the beat to parry it, break the stance and power up the rest of the combo. You can also back out at ACT when your target is in Counter
- **Stagger bars:** skills you can't dodge, Parry or Defend fill a gold bar with your hits (head-on, while the enemy prepares). Fill it to break the skill and knock the enemy back
- **Bosses resist being cancelled:** after one of their skills is stopped they shrug off the next cancels for a while, and their biggest moves can't be stopped at all
- **Stone Golem:** fallen rocks stay (it drops them twice per fight, always once by 75% HP) and its Golem Smashes blow up the rocks in their half. New double Smashes hit one side, then the other, clearing the whole arena
- **Living Armor:** Shadowflare now calls 3 Shadow Sprites that circle the growing ring; hit each one once to stop it. It grows slower but can reach almost the whole arena
- **Gale Maw:** Gust Sprites are very tough but light: push them off the ledge. **Every class can now push** (the Assassin's Ambush, the Cleric's Smite and the Monk's Flash Kick do), and if you don't know a push Art yet, the game shows you its recipe
- **New look:** the timeline, menus, panels and title screen share one style; big titles in a slanted font, easier-to-read text everywhere else
- **Arts:** every Art takes on the effects of the moves it's made of; partial hints for hidden Arts ("??? Thrust + Thrust + ?  (2 of 3)"); the combo bar zooms in for small moves
- **Monk:** Punch and Kick need no timing, his playhead runs at half speed, and his build bar no longer overlaps the AP preview
- **Fairer timing:** a press just after a hit lands shows LATE instead of breaking the combo; skipping a timed hit no longer costs max AP; getting hit by an avoidable attack no longer costs max AP
- **Balance:** solo bosses have more HP and speed, the Archer is toned down, the Mage hits 10% harder, Triple Shot is retuned, shields wear off after 2 of their caster's turns, and the Assassin gets one Execute per bar
- **Smarter allies:** AI party members dodge falling rocks and blasts by taking the shortest clear way out
- **Fixes:** a softlock at ACT when no move could reach the target, controls no longer jump to another party member (only Tab switches), Art descriptions no longer cut off, the party comes out in the order you picked it

## 0.4.0: the Gale Maw

- **New boss: the Gale Maw** (Round 11, after the Dragon, on the new Cliff arena). A stone face set into the wall: it never moves, and every attack pushes or pulls you. Inhale drags you toward its mouth, Exhale blows you toward the drop
  - Rocks between you and the wall shelter you from its breath, but its blasts crack them: two cracks and a rock shatters (it grows back later)
  - At half HP the cliff edge crumbles closer
  - Being pushed or pulled leaves you **Winded**: your next turn comes later
  - Every few actions it spits out a **Gust Sprite** that knocks you around
  - Gale Burst (a blast, then lanes of wind), and Undertow lines that run past you into whoever stands behind
- **Defend braces you:** against any push or pull, Defend (for classes that can Block) halves how far you're moved, even when the damage can't be blocked
- **Edge saves on pushes too:** pushed or pulled over a drop, Parry to catch yourself. After a save you're **Off-Balance** for 3 turns: go over again then and you fall
- **Enemy review:** fixes and tuning across the regular enemies and bosses (Kobold Power Shot, Shaman healing cap, Golem Stone Guard, Living Armor Parry Stance and more)
- **Round order:** the Gale Maw is the last solo boss; the mixed boss rounds are now 12 and 13

## 0.3.0: class review, move details

- **Every class rebalanced.** Each class got a full pass on its attacks, Arts and Abilities. Highlights:
  - **Knight:** shield blows now briefly stop an enemy's timeline instead of pushing it back, and draw its aggro. New Art Shield Wall (Guard Strike + Guard Strike) hits all around them, draws every enemy's aggro and shields nearby allies. Less damage overall; Smash now knocks enemies back
  - **Archer:** Exposing Shot replaces Pinning Shot (the target takes +15% damage from everyone). Agility's extra hit is half strength. Riposte is cheaper and she hops back after countering; True Sight reveals enemy attacks early
  - **Mage:** Fire sets enemies burning. New spell Arcane Surge: tap as fast as you can, every tap adds damage. Meteor Strike and Steam Burst hit harder; Teleport is cheaper and can target any spot
  - **Cleric:** Bash builds a flurry (each Bash in a row hits harder) and grows the party's max AP. Haste makes an ally's turns come sooner. Sanctuary is a real barrier now
  - **Assassin:** Execute grows with every Mark it spends; Backstab is cheaper, Phantom Rush hits harder from behind
  - **Monk:** his climb Arts hit harder
- **No more stun locks.** An enemy can be stopped or stunned once per action of its own
- **Move details.** While choosing, a box explains the highlighted move or Ability in full. Turn it off in the pause menu
- **Answer tags.** Moves that work against what the enemy is doing glow green (INTERRUPTS, PIERCES, STUNS, COUNTERS IT...); ones that would backfire glow red (BLOCKED, COUNTERED)
- **Stone Golem:** Ceiling Burst no longer drops rocks on the Golem itself

## 0.2.0: the Monk, arenas with drops, a bigger screen

- **A sixth class, the Monk.** Weak alone, he climbs his combo bar from 30 to 100 AP in steps through his climb Arts (Knee Smash, Triple Rush, Mountain Crusher), then cashes it all out with Tortoise Special. All-Perfect Arts leave tokens for the next one; mistakes cost him a step. Pick him in the party picker before boss rounds; the tutorial has a Monk lesson
- **Arenas with drops.** Holes and edges lined with skulls: knock regular enemies off them, mind what's behind you, and catch yourself with a Parry-timed save if you walk off (once per fight). Round 5 now takes place on a platform with holes
- **The Knight is the tank:** Taunt is cheaper (40 AP) and, while it lasts, allies near them share their Block and Parry
- **Bigger window and UI:** the game opens at 1600x900, with larger menus and text; Tab in the combo bar shows an Art's details
- Fixes: Arts picked from the Arts list now still form bigger Arts; HUD effects no longer cover the AP meter

## 0.1.0 (first public build)

- A 12-round **Boss Rush** with auto-save, plus Round Select
- A guided **Tutorial** that teaches every mechanic, one class at a time
- **Five classes**: Knight, Archer, Mage, Cleric and Assassin, each with its own attacks, Abilities and reactions
- **Arts**: secret named combos for every class, revealed mid-combo the first time you find them
- **Timed hits**: Press, Hold and Tap timings on the combo bar
- **Enemies with readable skills**: from simple cones to half-room cleaves, falling rocks and instant-death gazes you hide from
- **Play-test reports** after every fight (press O on the end screen); please send them along with your impressions!

Known rough edges: placeholder art throughout, no victory/defeat screens
beyond the basics, and balance is still being tuned.
