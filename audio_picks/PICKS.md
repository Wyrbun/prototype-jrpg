# Pick your sounds

Listen to each folder in `audio_picks/sounds`, then reply with your picks, e.g. `01: 3, 02: 1, ...` (or "none" for a slot you don't want). One per slot, or a few if you'd like them to vary.

- **01 Sword and dagger hits**: Knight's sword, Assassin's daggers landing (9 options)
- **02 Blunt hits**: Cleric's staff, Monk's punches and kicks, enemy clubs (6 options)
- **03 Heavy hits**: Smash, finishers, big enemy blows (6 options)
- **04 Swings**: a whoosh as an attack starts (5 options)
- **05 Bow shot**: the Archer's arrows and the Kobold's (5 options)
- **06 Spell cast**: Mage and Cleric magic, enemy spells (6 options)
- **07 Fire spell**: fire Arts, Fireball, burns (7 options)
- **08 Parry**: a clean clang when you Parry (6 options)
- **09 Perfect timing**: a bright ding for a Perfect (7 options)
- **10 Knockdown and falls**: a body hitting the ground (ragdolls) (5 options)
- **11 Heal and buff**: Healing, Shielding, Haste, potions (6 options)
- **12 Menu move**: moving the highlight in menus (6 options)
- **13 Menu confirm**: choosing something (6 options)
- **14 Menu back**: going back, cancelling (6 options)
- **15 Enemy hurt**: grunts when enemies take a hit (7 options)
- **16 Enemy defeated**: an enemy's last cry (5 options)
- **17 Boss roar**: a big monster's roar (Golem, Dragon, Gale Maw) (6 options)
- **18 Victory and defeat jingles**: 85 short stings in five styles (8-bit, Hit, Pizzicato, Sax, Steel). Pick one for winning, one for losing (file names).

# Pick your music

All the tracks are in `audio_picks/music`. Pick one (or more, to rotate) for each:

- **Title screen**
- **Tutorial**
- **Regular battles**: one for all rounds, or one per arena (Town Plaza, Forest Clearing, Mountain Pass, Crystal Cave, Sky Ruins, Windswept Cliff, Red Canyon)
- **Boss battles** (Rounds 8 to 13, the Special Match)
- **Results screen** (or just the jingle)

Everything here is CC0 (public domain): Kenney (Impact Sounds, Interface Sounds, RPG Audio, Music Jingles), rubberduck (80 CC0 RPG SFX), artisticdude (RPG Sound Pack), Juhani Junkala (JRPG Music Packs #1, #2, #4, #5; Epic Boss Battle), cynicmusic (Battle Theme A, Town Theme), Wolfgang_ (Battle).

This folder has a `.gdignore`, so Godot ignores it; once you've picked, only the chosen files move into the game and this folder can be deleted.

# Chosen so far

Music (Thiago, Nov 18):
- Regular battles: Battle Theme A (cynicmusic)
- Bosses: Battle (Wolfgang_)
- Living Armor: Action1 - Encounter With The Witches
- Gale Maw: Epic Boss Battle
- The rest of the music stays in `music/` for later.

Sounds (Thiago, Nov 18):
- 01 Sword and dagger: 1-4 hits, 5-9 unsheathe; mix as fits.
- 02 Blunt, 03 Heavy, 04 Swings, 05 Bow shot: all, varied.
- 06 Spell cast: 1 Energy, 2 Fire, 3 Teleport, 4 Ice, 5 Lightning, 6 Focus activates.
- 07 Fire spell: all, mixed across Fire and fire-adjacent attacks and Arts.
- 08 Parry: 2 then 1 for multi-step parries, 3 for a full Perfect parry, 4 for a failed Parry; 5 and 6 unused.
- 09 Perfect: 1 Healing spells, 2 a full attack bar with 0 misses, 6 every timing hit.
- 10 Knockdown: 1 a knocked-down character landing (light), 2 thrown far and knocked down, 4 a defeated enemy landing, 5 an enemy vanishing.
- 11 Heal/buff: 1-3 item use, 6 when the recovered HP number shows (also Ethers).
- 12 Menu move: 1. 13 Menu confirm: 1; 2 for Revive.
- 14 Menu back: 2 backing out, 3 removing an attack from the timeline.
- 15 Enemy hurt: 1, 2, 3 normal enemies hit; 4 normal enemies dying; 5 the Ogre dying; 6 Dragon Hatchling dying; 7 Gale Maw.
- 16 Enemy defeated: 1 the Stone Golem.
- 17 Boss roar: none picked.
- 18 Jingles: NES12 victory, NES00 defeat.
