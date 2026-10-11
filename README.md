# Common Folk

**Common Folk** is a medieval life sim sandbox with RimWorld-style looks: you live one person's life at a time in a randomly generated town that keeps running without you. The full plan is in the design document; this project is at **milestone 9 (Jobs and economy)**.

## What works now

- Seeded random terrain (grass, forest, water, stone, dirt), and on top of it a generated town: a rounded clearing, two dirt roads crossing in the middle, your own lot (16 by 13, south-west of the crossing), and along the roads a tavern, shop, clinic, village green, five houses and two empty lots, all from templates in `data/buildings.json` with the door turned to face the road. The same seed always gives the same town
- Twelve townspeople live in the houses in families (shared surname, two adults and the children the beds allow). They have needs, traits and moods like your household, sleep, eat and wash at home, use the tavern's lute and the clinic's basin, and wander the roads, the green and their own yard by day. Children are drawn smaller and have only two traits. Things on a private lot can only be used by the people who live there; the tavern, shop, clinic and green are open to all. Deaths in town leave a grave and a message
- Terrain drawn by a GPU shader in a gritty RimWorld-like style: muted earthy colors, grain, grass tufts, pebbly dirt, shallow-to-deep animated water, plated rock with a lit bevel and a cast shadow, and oak and pine trees with shadows. No art files needed yet
- Day and night light (blue nights, warm dawn and dusk) and seasons (green spring, golden summer, brown autumn, snowy winter) that follow the game clock
- Camera: pan, zoom toward the cursor, middle-mouse drag
- Game clock with pause and 1x / 2x / 3x speed, a calendar with seasons, and a clock panel
- A household of three people (names and looks from the world seed) drawn in RimWorld-style top-down art made by code. Control one at a time: click a person (or their portrait at the bottom, or press Tab) to select them, then right-click anywhere for a menu of what they can do there (walk, stop, sleep, eat, wash, and with another adult, spend time together). The others keep walking if they have orders
- Pathfinding around water and rock with A* (forest is slower to cross, diagonals never cut corners), walking at one step per clock tick so pause and speed control apply
- Needs: hunger, rest, warmth, hygiene, toilet and fun fall over time (faster or slower with traits, and warmth faster in winter). A starter camp on your lot has a bed for everyone plus a cooking pot, hearth, wash basin, chamber pot and lute. When nobody is giving orders, a person with a low need walks to the nearest free thing that fixes it and uses it until the need is full; people head to bed earlier after dark. Your orders always win, and an empty need slows a person down
- A panel on the left shows the selected person's needs and what they are doing; right-click an object for its action (Sleep, Eat a meal, Wash...)
- Build mode (B): on your home lot, place furniture, timber and stone walls (drag to run a wall; they join up at corners), doors and three kinds of floor; move things; take them down. Routes update as you build, anyone heading for something you move or remove stops, and a walk that gets cut off finds another way. A shaded edge and a gold outline show where the lot ends
- People can die: a need with `fatal_after_hours` in `needs.json` (hunger 72 hours, warmth 48) kills after being empty that long, and any meal or fire starts the clock over. A grave is left where they fell, control passes to the next person, and when the last one dies the playthrough ends with a message (N for a new world, F9 to load). The household bar shows a green, amber or red strip for each person's worst need, so you can see who is in trouble while you control someone else
- Thoughts and mood: each person has timed thoughts ("Slept in a bed +5", "Hungry -6", "Someone in the household died -15") and a mood from 0 to 100 that the panel shows with the reasons. Traits change how strongly things land (a lazy person enjoys a bed more, a neat one hates being dirty, a greedy one cares less for comfort) and a few thoughts belong to one trait only. A miserable person (mood under 20) drags their feet
- Coin and work: your household shares a purse (shown under the clock, 120d to start). Right-click the notice board on the village green, or a counter in the shop, tavern or clinic, to take a job from the open vacancies; right-click again to quit. Each job has a shift and a wage: an idle worker walks to a free spot beside the business's counter when the shift starts, is paid by the hour on leaving, and goes home early if a need gets critical. Giving a worker any other order takes them off their shift for the day. The tavern sells meals and ale, the shop sells bread (the price shows in the menu); building now costs coin and taking something down gives half back. Some of the townspeople work too (each business keeps a vacancy for you), and they earn and spend by the same rules
- Hover a tile to see what it is and whether it is walkable
- Save and load (F5 / F9) with an autosave every midnight (`user://autosave.json`). Saves are written to a temporary file first and moved into place, a damaged or cut-off file is refused without changing anything, older saves (formats 1 to 6) still load, and the camera position and zoom come back. New world (N)
- All content (tiles, seasons, needs, traits, buildings, the town's makeup) comes from JSON files in `data/`, and mods can add or replace it

## Run it

1. Install Godot 4.4 or newer. On Nobara: `flatpak install flathub org.godotengine.Godot`, or install the `godot` package with dnf.
2. Open Godot, click **Import**, choose this folder's `project.godot`, then press **F5** (or the play button).
3. The first time, Godot builds its class cache. If you see "identifier not found" errors for `WorldState`, `MapView` and similar, close and reopen the project once.

Options go after `--` on the command line, which is handy for testing and screenshots:

```
godot --path . -- --seed=1234 --day=50 --hour=12 --zoom=0.5 --look=70,30 --speed=0
```

`seed` is the world, `day` and `hour` set the date (day 0 is the first day, 15 days per season), `zoom` the camera zoom, `look` the tile to center on, and `speed` 0 to 3, `walk` a tile (such as `--walk=70,50`) to send the selected person to, and `menu` a tile to open the right-click menu on, `load=1` to load the newest save at start, `shot=path.png` to save a screenshot a moment after starting and quit, `dying=1` to put the selected person minutes from starving, `needs` values for the selected person (such as `--needs=rest:10,hunger:30`), `build` to start in build mode with a tool (`--build=place:wall`, `floor:planks`, `remove`, `move`), `demohouse=1` to build a small room with the real build commands, and `together=1` to start the two-person interaction.

## Controls

| Key | Action |
| --- | --- |
| WASD / arrow keys | Move the camera (hold Shift for faster) |
| Left-click a person | Select that person |
| Right-click | Menu of actions for the selected person at that spot (Walk here, Stop, object actions, and interactions when you click another person). Left-click a person to switch to them |
| B | Build mode: pick a tool in the palette, left-click or drag to build, right-click or Esc to put it away |
| Escape | Close the menu; in build mode, put the tool away, then leave build mode |
| Tab / Shift+Tab | Next / previous person (camera jumps to them) |
| C | Center the camera on the selected person |
| Mouse wheel | Zoom |
| Middle mouse drag | Pan |
| Space | Pause / resume |
| 1, 2, 3 | Set speed |
| G | Toggle grid |
| Home | Recenter camera |
| F5 / F9 | Quick save (`user://savegame.json`) / load the newest of the quick save and the autosave |
| N | New random world |

## How it is organized

The simulation never touches the screen, and the screen only reads the simulation. Keep it that way and pause, speed control, saving and off-screen simulation all stay easy.

```
data/                  Base content as JSON (one file per kind of thing)
mods/                  Mods, one folder each (example_mod is disabled by default)
scenes/main.tscn       The only scene
shaders/
  terrain.gdshader     Paints the whole map on the GPU
scripts/
  autoload/            Global singletons
    data_registry.gd     Loads data/ and mods, answers "what is tile X?"
    game_clock.gd        Fixed ticks, speed, calendar
  sim/                 Game state and rules (no drawing here)
    world_state.gd       The map as plain data, turns into a Dictionary
    map_generator.gd     Seed -> terrain
    town_generator.gd    Terrain -> roads, your lot and the buildings (from templates), with a reachability check
    npc_generator.gd     The town's families, living in the houses
    person_factory.gd    One random person: name, looks, traits, needs (household and town share it)
    pawn.gd              One person: position, walking path, one step per tick
    pawn_actions.gd      What a person can do at a spot (the right-click menu's entries)
    needs.gd             Which needs are in play, drain rates, when to look for a fix
    mood.gd              Thoughts and mood from data/thoughts.json
    placed_object.gd     One bed, pot, wall... standing on the map
    camp_generator.gd    Sets out the starting camp
    household.gd         A group of people: yours (selected, died) or the town's
    economy.gd           Currency, prices and building costs from data/economy.json
    household_generator.gd  Seed -> starting family (names, looks, where they stand)
    path_finder.gd       A* over the tile map
    simulation.gd        Ticks the world; the commands views may give (order_move, order_use, build_place...)
    save_game.gd         Writes and reads the save file
  view/                Drawing and input for the map
    map_view.gd          Feeds the world and season look to the terrain shader
    day_night.gd         Tints the map by time of day
    tile_cursor.gd       Hover highlight and grid
    pawn_art.gd          Draws a person with code (swap for sprites later)
    object_art.gd        Draws beds, pots, walls, doors... with code
    floor_art.gd         Draws planks, flagstone and straw
    floor_layer.gd       The floors, between the ground and the objects
    build_controller.gd  Build mode: lot shading, preview and mouse tools
    build_ghost.gd       The green/red preview under the mouse
    object_view.gd       One object on screen
    object_layer.gd      All objects, drawn under the people
    pawn_view.gd         One pawn on screen, gliding between tiles
    pawn_layer.gd        All pawns, route overlay and mouse orders
    camera_controller.gd Pan and zoom
  ui/hud.gd            Flat dark panels: clock and speed buttons, household bar, tile info, help, messages
  ui/pawn_portrait.gd  Small person picture for the household bar
  ui/build_icon.gd     Palette pictures for the build mode buttons
  ui/action_menu.gd    The right-click pop-up list
  main.gd              Wires it together and handles shortcuts
tests/                 Headless checks
```

One tick is one game minute. At 1x a tick takes 0.1 real seconds, so a game day lasts 144 seconds (48 at 3x). Change `TICK_SECONDS` in `game_clock.gd` to tune that.

## Data and mods

Each file in `data/` is a JSON array, and the file name is the kind of content. Every entry needs a unique `id`:

```json
[
  { "id": "grass", "name": "Grass", "color": "#6b9a45", "style": "grass", "priority": 2, "walkable": true, "move_cost": 1.0 }
]
```

A tile's look comes from three fields: `color` (its base color), `style` (`flat`, `grass`, `dirt`, `water`, `stone` or `forest`, which picks the texture in the shader) and `priority` (higher-priority tiles bleed over the edges of lower ones, so grass overlaps dirt and stone overlaps grass). Seasons in `seasons.json` add `foliage_tint` (multiplied into grass and leaves) and `snow` (0 to 1). A season looks exactly like itself for its first two thirds, then eases toward the next one.

A mod is a folder in `mods/` (or `user://mods/` in a built game) with the same kinds of files:

- A new `id` adds content.
- An existing `id` replaces the whole base entry, so include all of its fields.
- `{ "id": "water", "_remove": true }` deletes an entry.
- A file with a new name (say `recipes.json`) adds a whole new kind of content.
- An optional `mod.json` holds `name`, `enabled` and `load_order`.

To try it, set `"enabled": true` in `mods/example_mod/mod.json` and restart. Grass turns bright green. Problems in data files (bad JSON, missing ids) are shown on screen and printed as warnings.

`names.json` (given names and family names) and `appearance.json` (skin, hair and clothing colors) feed the household generator, so a mod can change who your people are. `needs.json` lists the needs (`drain_per_hour`, `optional: true` for ones nobody has yet, `slows_when_empty: false` for ones that can sit at zero harmlessly, like Libido, and `fatal_after_hours` with a `death_cause` for ones that can kill); `traits.json` changes drain rates and, with `thought_multipliers`, how strongly thoughts land (a trait with `"group": "orientation"` is an orientation: every new person gets exactly one of those plus two other, different traits); both are used now, and traits will matter more in milestone 7. Seasons in `seasons.json` can carry `need_drain_multipliers` (winter makes warmth drain 2.5 times faster).

`objects.json` describes the things people use:

```json
{ "id": "bed", "name": "Straw bed", "action": "Sleep", "doing": "Sleeping",
  "blocks_walking": false, "use_position": "on", "pose": "lie",
  "satisfies": { "rest": 14.0 }, "max_use_minutes": 600 }
```

`category` (default `furniture`) picks the build palette tab, `buildable: false` keeps something out of it, `connects` makes walls and doors join their neighbors, and `drag: true` lets the tool run a row. `satisfies` is points restored per hour of use; a person stops when every need it fills is full or after `max_use_minutes`. `use_position` is `on` (stand on the tile) or `beside`. `action` is the right-click menu entry and `doing` the activity shown in the panel. A need is only in play while some object satisfies it, so adding an object with `"satisfies": { "faith": 20 }` switches Faith on (it also needs `optional` to be false). Objects with no drawing in `object_art.gd` appear as a crate.

`thoughts.json` lists the thoughts. A state thought has a `when` (`need` with `below` or `above`, `idle`, or `alone`) and holds while that is true; thoughts sharing a `group` do not stack, the strongest wins. An event thought has `on` (`used:<object id>`, `interaction:<id>`, `death`) and `hours` it lasts. `only_for` and `never_for` take trait ids.

`economy.json` has one entry: the currency's `symbol`, the `start_coins` of a household, a `npc_start_coins` range for townspeople and the `refund_percent` when something is taken down. An object's `cost` is what building it costs, its `price` is what each use costs (the tavern table is 4d), and `offers_work` (`"town"` for the notice board, `"lot"` for a counter) makes it list vacancies. A floor's `cost` is per tile.

`jobs.json` lists jobs: `workplace` (the kind of building: `tavern`, `shop`, `clinic`, `park`), `positions`, `wage` per hour, the shift's `from` and `to` hours, the `station` object a worker stands beside and `min_age`. The town fills all but one position of each business with townspeople at the start. Wages are the only money coming in and prices and building the only money going out for now; taxes and rent come with the medieval layer.

`worldgen.json` has one entry, `town`: `npc_count`, how many `buildings` of each kind (`tavern`, `shop`, `clinic`, `park`, `house`, `vacant`; a mod can add kinds), the clearing's `half_width`, `half_height_up` and `half_height_down`, the `home_lot_size` and the `vacant_lot_size`.

`buildings.json` holds the templates, each a picture in characters, one per tile: `#` timber wall, `S` stone wall, `+` door, `.` floor, a space for nothing, and a letter for an object (b bed, p cooking pot, h hearth, w wash basin, c chamber pot, l lute, t table, k counter, s shelf, r barrel, n bench, W well). Draw the door in the bottom wall; the generator mirrors the template at random and turns it to face the road. `kind` says what it is (a `house` is filled with a family, one person per bed), `floor` is a floor id from `floors.json` laid inside, and `"public": true` lets anyone use what is in it.

`floors.json` lists the floors the player can lay (`color`, `line`, and a `pattern` of `planks`, `flags` or `straw`).

`interactions.json` describes things two people do together. Libido is filled this way: right-click another adult and pick the entry.

```json
{ "id": "intimacy", "action": "Be intimate with {name}", "doing": "Spending private time together",
  "satisfies": { "libido": 200 }, "max_use_minutes": 30, "adults_only": true,
  "requires_attraction": true, "willing_below": { "libido": 85 }, "unwilling": "isn't in the mood" }
```

Both people must be adults, attracted to each other (`requires_attraction` reads the orientation traits in `traits.json`: `attracted_to` is `opposite`, `same`, `both` or `none`; someone with none of them is open to anyone) and willing (`willing_below`: each need listed must be under that number, otherwise the entry is greyed out with the `unwilling` reason), and the other person must not be busy. The asker walks over, both stand still side by side with hearts over their heads, both needs fill, and the panel says only what `doing` says. Nothing explicit is shown, and the people never do this on their own: only the player starts it. Ordering either person elsewhere ends it for both.

If you export the game, add `*.json` under **Resources > Filters to export non-resource files** so the data files are included.

## Tests

```
godot --headless --path . res://tests/smoke_test.tscn
```

This checks data loading, mods, the clock and calendar, world generation (same seed, same world), the town (lots keep apart, everything is reachable, houses are equipped, people live in families, private things stay private, a day in town, a death in town, saving it), pathfinding, pawn movement, the household, the right-click actions, needs and objects, coin and work (prices, build costs, shifts, wages, hiring, quitting), building, coin and work (prices, build costs, hiring, shifts, wages, quitting), death, thoughts and mood, and the save round trip. Run it as a scene as shown; it needs the autoloads, which `--script` mode does not provide.

```
godot --headless --path . res://tests/balance_check.tscn
```

This is not a pass/fail test. It plays 15 days in spring and in winter on three seeds with nobody giving orders and prints deaths (yours and the town's), mood and the lowest each need got, so you can see whether a change to needs, thoughts or the camp broke the balance.

Two more helpers: `res://tests/town_dump.tscn -- --seed=7` prints a picture of a generated town in characters, and `res://tests/perf_check.tscn` times one game day with the whole town (about 1.5 ms per tick).

## Graphics notes

The terrain is procedural, so changing how it looks means editing `shaders/terrain.gdshader`. The `terrain()` function holds one block per style, `tree_shape()` and `tree_outline()` define the oak and pine silhouettes, and light always comes from the top-left (`LIGHT_DIR`). Tiles are 48 pixels at zoom 1 (`TILE_SIZE` in `map_view.gd`; change it there and everything else follows). Colors come from `data/tiles.json`, so a mod can re-tint the whole world. The shader uses only features of Godot's Compatibility renderer, so it runs on modest GPUs.

This is a procedural approximation of the RimWorld look. The real thing relies on hand-painted textures and sprites, so when characters, furniture and buildings arrive they will be sprites drawn on top (made in Krita or Aseprite, or from a free pack); the day and night tint (a `CanvasModulate` node) will apply to them automatically. To stop the dark nights, set the night colors in `day_night.gd` closer to white. The HUD colors are constants at the top of `scripts/ui/hud.gd`.

## Known limits

The lot may include water or rocks you cannot build on. Pawns can walk through each other and are drawn over tree canopies. Social and Faith wait for things that can satisfy them. Townspeople's wages come from nowhere and pile up (nothing for them to buy but meals), and there is no business income or trade yet. Townspeople do not talk to each other or to you yet, and are not clickable; they only work, live, wander and die. Nobody lives in the tavern, shop or clinic, and the shop sells only bread.

## Next

Building is instant, with no builders, materials or roofs: a house is just walls, a door and a floor, paid for in coin. Your lot is given to you; a later milestone replaces that with the three ways of getting land (buy, inherit, arrive with nothing), and the two empty lots are there for a business. Rooms, roofs, materials and builders come after the economy exists.
