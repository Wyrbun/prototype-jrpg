# Prologue design notes

The Prologue is a short, playable demo of the whole game: cutscenes,
exploring a dungeon, fights that start on the field, menus, saving and a
boss. Answers from Thiago, 18 Nov 2026. Stages 1 to 3 (exploring, field
enemies, fights in the room) are built; see the build order. The **Open questions** are at the bottom.

## The world

- A great war ended modern civilization; humanity was wiped out within
  five days. Some hid in underground **Bunkers** (none survived; the old
  Bunkers now draw treasure hunters, and some are guarded by the kingdoms
  that grew up around their riches). Others uploaded their minds to
  underground and underwater **datacenters**, hoping to be found one day.
- An unknown number of years later, Earth is **Haidran**: radiation-mutated
  flora and fauna, lands that shift, sink and rise, and anthropomorphic
  animals in humanity's place.
- Society is roughly medieval. Finds of **Ancient** technology cause
  sudden jumps, but overall technology barely moves.

## The Prologue's story

- **Wyr** (the Knight; *they*), child of engineers, has enlisted in the
  **Morath Empire's** army. Wyr and two unnamed soldiers are sent to look
  into clandestine treasure hunters raiding a nearby **coal mine**.
- The mine hides an **Ancient Ruin** beneath it, guarded by constructs,
  with a malfunctioning golem-like automaton, the **Haywire Automaton**,
  guarding its main chamber.
- Inside rests **Aurora**, a working AI that once lived with and assisted
  humans. Wyr takes her for a Goddess, and she adapts herself to that. Parts
  of her memory are missing; she urges Wyr to travel to other Ruins to find
  clues about the past.
- **The demo ends** when Wyr leaves the Ruins and meets the other two
  outside.
- **After the demo (Chapter 1 proper):** Wyr reports to the captain, who
  takes them to the King and Queen. Aurora shows herself, calls Wyr her
  "Chosen Warrior" and says her memory holds "answers for everything". The
  King and Queen bless an expedition to find the rest of her memory.

## Cast in the Prologue

- **Wyr** (Knight class): the lead. Mostly silent; picks answers when
  prompted, and other characters remark on Wyr's silence.
- **Two unnamed soldiers**: a Mage (male, *he*) and a Cleric (female,
  *she*). They fight alongside Wyr in some parts of the dungeon and leave
  the party before the Automaton. They are AI only until the game explains
  that you can steer them yourself (optional from then on).
- Wyr is always *they*. If Thiago's notes say "he" for Wyr, it's a slip
  (Portuguese bleeding through): write *they* anyway.
- **Aurora**: the AI.
- **The Haywire Automaton**: a new boss with simple mechanics and a
  cutscene in the middle of the fight (designed later, with Thiago).
- **Enemies:** treasure hunters in the mine (Ratkin Fighter, Kobold Archer,
  Bandit Arcanist); constructs in the Ruins: the **Defective Sentry** (a
  smaller Living Armor), the **Heavy Sentry** (a smaller golem) and the
  **round sentry** (a sphere with a red eye, plates missing round the eye,
  wires showing; a very simple design), all with much simpler mechanics
  (to be decided). Until then the field uses the Living Armor and golem
  figures. The treasure hunters' Ratkin Fighters are called **Ratkin
  bandits** in the story (same enemy, renamed).

## The dungeon

- About 30% coal mine, then abandoned Ruins for the rest.
- Has chests, simple switch / key puzzles, NPCs to talk to and save points.
- Room by room (loading areas), like older games.

## The dungeon, room by room (first draft, Thiago 18 Nov)

Coal mine:

1. **Outskirts:** a square, grassy map; the mine's entrance is to the
   north. The opening cutscene plays here: Wyr and the soldiers arrive in
   their vehicle (a bus on tank treads), their caravan camps here, and
   soldiers guard the mine's entrance.
2. **Mine Entrance:** a long, winding tunnel leading down. Train tracks
   on the ground, cobwebs and hanging lamps on the ceiling lighting the
   way ahead.
3. **Mine Lobby:** a square space with paths east and west.
   - East: a dead end with a cave-in, an abandoned backpack, and a
     treasure hunter's body under the rubble (only his hand shows). The
     backpack holds items and a note: the treasure hunters' plan to break
     into a rumoured ruin inside the mine.
4. **Mines West:** a large tunnel with many side paths to coal veins. A
   dug path ahead leads to a square room whose floor looks very different
   from the rest of the mine. A treasure hunter lies knocked out by a
   wall, and two Ratkin bandits attack the party (a set fight, no
   escape). Afterwards the treasure hunter hints there's something in
   this room. The side paths to the coal veins hold treasure, and more
   bandits in empty, round areas.
5. **Secret Path:** examining the tunnel wall opens a staircase down; the
   rock gives way to metal and concrete.

Ancient Ruins:

6. **Ruins Lobby:** a big square room with broken metal doors and exposed
   wires, lit by emergency lights. Touching a wall panel turns some
   lights on and opens some doors. Two round sentries attack the party
   (a set fight, no escape). The soldiers fight here, and the game
   explains that you can steer them (optional from then on).

(More rooms to come, up to the Haywire Automaton's chamber.)

## Exploring (the field)

- **Camera:** free, like in battle (same options), but it snaps back to
  a set angle for each room or loading area on entering it.
- **Followers:** the party walks behind the leader on the field.
- **Field menu:** Item, Equipment, Attacks / Arts (greyed out for now),
  Status, Save (greyed out away from save points), Load, Options. The party
  stands on the right with their 3D models. *Thiago will send a reference
  before this is built.*

## Enemies on the field and how fights start

- Enemies stand on the field with their **line of sight shown**. Each is
  set up on its own, room by room: patrolling a route, or standing guard
  and looking about.
- **Sight:** usually a cone (about 7 m, 70 degrees) plus a short
  all-round radius that only hears running. Some enemies have a full
  detection circle instead: walking or sneaking inside it is fine, only
  running (or touching them) gets you noticed. Cones don't get shorter in
  dark places.
- Enemies that **haven't seen you yet only move when you move, at your
  pace**: standing still freezes them, sneaking slows them.
- **Sneak:** hold the Sneak key (Shift / left trigger) or half-push the
  stick to walk at half speed.
- **The field attack** (Confirm): Wyr swings the sword. Hitting an enemy
  **from behind** before it has noticed you gives the advantage: the party
  starts the fight with 50 AP. A hit from the front or side starts a
  normal fight. (Later the swing also breaks crates and hits switches.)
- **Seen:** the enemy chases you, faster than its patrol. If you outrun it
  for a bit, it gives up and goes back to its patrol area. **Touched:**
  the fight starts with the party knocked down, the enemies ahead on the
  timeline, and the party's AP not recharging until they're back up.
- **Every enemy in the room joins the fight.** Dungeon rooms are small
  enough for this. (Open fields, later: a battle area is drawn around the
  fight and catches every enemy inside it.)
- **Fights happen where you meet the enemy**, in the room itself, after a
  short battle transition (time to change the music: field fights have
  their own battle theme). Rooms will bring elevation later (stairs and
  ledges to climb to reach enemies); for now fights are on flat ground
  and Thiago keeps fights away from height.
- **Escaping:** run towards a door or a set exit for a couple of seconds.
  The room resets (enemies go back to their places).

## Between fights

- HP carries over. AP always starts at 0 (50 after a hit from behind).
- **The item pouch** (Potions, Ethers, Revives) carries over between
  fights instead of refilling every fight.
- **Save points:** heal the party and refill the item pouch, but every
  enemy comes back. Until then, beaten enemies stay beaten, even if you
  leave the room and come back.
- **After a win:** a Victory screen with the experience earned and the
  items found (enemies don't drop Credits, the currency).
- **Losing:** back to the last save point, or the dungeon's entrance if
  you haven't reached one, healed. Everything you beat stays beaten.
  Bosses allow several retries when the party is defeated.

## Cutscenes

- In-engine, with the 3D figures and text boxes (no portraits).
- Each character has their own voice "blip" while their text appears.
- Dialogue choices for Wyr where prompted.

## Title screen

- A new **New Game** row starts the Prologue. Choosing it first warns that
  it starts a short story set piece, and that Boss Rush and Round Select
  are the places to test the combat system. Boss Rush, Round Select and
  the Tutorial stay as they are.

## Saving

- Save at save points.
- **Quick Save** anywhere for a break; it is deleted when it's loaded.

## Build order (proposed)

1. **Field movement** (built, see CHANGELOG): two test rooms, walking, the
   room camera with its reset angle, cutaway walls, followers, doors
   between rooms, stairs, New Game on the title screen.
2. **Field enemies** (built): patrols and guards, sight cones and circles,
   moving at your pace, Sneak, chases that give up, the field swing
   (ambush / normal / caught; for now a message, the fight is Stage 3).
3. **Fights in the room** (built): the room becomes the arena (flat
   floor), every enemy joins, ambush / normal / caught starts, escaping,
   the room reset, the Victory screen (experience, items), losing, HP
   and the pouch carrying over, beaten enemies staying gone.
3b. **Height in fights:** stairs and ledges in the battle system.
4. **Interactables:** chests, switches and keys, NPCs, save points.
5. **Menus and saving:** the field menu (after Thiago's reference), save
   points, Quick Save, Load.
6. **Cutscenes:** text boxes, blips, choices, camera shots, figures walking
   and acting.
7. **The dungeon:** the mine and the Ruins, room by room, with the
   story and the companions joining and leaving.
8. **The Haywire Automaton** and the ending.

## Open questions

- Field music: no exploration track yet (the Prologue is silent on the
  field for now), and the field fights' own battle theme (the regular
  battle theme plays until it's picked).
- Experience: what it does (levels?), and the real numbers per enemy and
  drop chances (placeholders in `field_rewards.gd`).
- The Haywire Automaton's mechanics and mid-fight cutscene.
- The Defective Sentry's and Heavy Sentry's mechanics.
- The field menu's look (Thiago will send a reference).
