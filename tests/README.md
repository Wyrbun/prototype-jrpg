# Tests

Headless checks for the battle system. Each script runs one scenario and
prints `OK` / `FAIL` lines, then `FAILS: n` (0 = all good). Run one from the
project folder:

```
godot --headless --path . -s tests/_monk.gd
```

Scripts named `_shot*` take screenshots instead, so they need a window
(drop `--headless`). The tests aren't part of the exported game
(`exclude_filter` in `export_presets.cfg`).

Known flaky: `_aidodge.gd` sometimes fails its first two checks because the
AI Cleric attacks on the very first frame (a setup timing issue in the test,
not the game). Run it again; it passes most of the time.
