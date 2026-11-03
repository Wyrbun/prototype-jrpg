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

---

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
