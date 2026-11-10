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
