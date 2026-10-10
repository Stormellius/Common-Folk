# Medieval Sim

A medieval life sim sandbox with RimWorld-style looks: you live one person's life at a time in a randomly generated town that keeps running without you. The full plan is in the design document; this project is at **milestone 2 (One pawn)**.

## What works now

- Seeded random terrain (grass, forest, water, stone, dirt) with a flat clearing and crossroads in the middle for the future town
- Terrain drawn by a GPU shader in a gritty RimWorld-like style: muted earthy colors, grain, grass tufts, pebbly dirt, shallow-to-deep animated water, plated rock with a lit bevel and a cast shadow, and oak and pine trees with shadows. No art files needed yet
- Day and night light (blue nights, warm dawn and dusk) and seasons (green spring, golden summer, brown autumn, snowy winter) that follow the game clock
- Camera: pan, zoom toward the cursor, middle-mouse drag
- Game clock with pause and 1x / 2x / 3x speed, a calendar with seasons, and a clock panel
- A household of three people (names and looks from the world seed) drawn in RimWorld-style top-down art made by code. Control one at a time Sims style: click a tile to walk there, click a person (or their portrait at the bottom, or press Tab) to switch. The others keep walking if they have orders
- Pathfinding around water and rock with A* (forest is slower to cross, diagonals never cut corners), walking at one step per clock tick so pause and speed control apply
- Hover a tile to see what it is and whether it is walkable
- Save and load (F5 / F9), new world (N)
- All content (tiles, seasons, needs, traits) comes from JSON files in `data/`, and mods can add or replace it

## Run it

1. Install Godot 4.4 or newer. On Nobara: `flatpak install flathub org.godotengine.Godot`, or install the `godot` package with dnf.
2. Open Godot, click **Import**, choose this folder's `project.godot`, then press **F5** (or the play button).
3. The first time, Godot builds its class cache. If you see "identifier not found" errors for `WorldState`, `MapView` and similar, close and reopen the project once.

Options go after `--` on the command line, which is handy for testing and screenshots:

```
godot --path . -- --seed=1234 --day=50 --hour=12 --zoom=0.5 --look=70,30 --speed=0
```

`seed` is the world, `day` and `hour` set the date (day 0 is the first day, 15 days per season), `zoom` the camera zoom, `look` the tile to center on, and `speed` 0 to 3, and `walk` a tile (such as `--walk=70,50`) to send the selected person to.

## Controls

| Key | Action |
| --- | --- |
| WASD / arrow keys | Move the camera (hold Shift for faster) |
| Left-click a tile | Selected person walks there |
| Left-click a person | Switch to that person |
| Right-click | Selected person stops |
| Tab / Shift+Tab | Next / previous person (camera jumps to them) |
| C | Center the camera on the selected person |
| Mouse wheel | Zoom |
| Middle mouse drag | Pan |
| Space | Pause / resume |
| 1, 2, 3 | Set speed |
| G | Toggle grid |
| Home | Recenter camera |
| F5 / F9 | Save / load (`user://savegame.json`) |
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
    pawn.gd              One person: position, walking path, one step per tick
    household.gd         The people you control and who is selected
    household_generator.gd  Seed -> starting family (names, looks, where they stand)
    path_finder.gd       A* over the tile map
    simulation.gd        Ticks the world; the commands views may give (order_move, order_stop)
    save_game.gd         Writes and reads the save file
  view/                Drawing and input for the map
    map_view.gd          Feeds the world and season look to the terrain shader
    day_night.gd         Tints the map by time of day
    tile_cursor.gd       Hover highlight and grid
    pawn_art.gd          Draws a person with code (swap for sprites later)
    pawn_view.gd         One pawn on screen, gliding between tiles
    pawn_layer.gd        All pawns, route overlay and mouse orders
    camera_controller.gd Pan and zoom
  ui/hud.gd            Flat dark panels: clock and speed buttons, household bar, tile info, help, messages
  ui/pawn_portrait.gd  Small person picture for the household bar
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

`names.json` (given names and family names) and `appearance.json` (skin, hair and clothing colors) feed the household generator, so a mod can change who your people are. `needs.json` and `traits.json` are starter content for milestones 3 and 7; nothing reads them yet.

If you export the game, add `*.json` under **Resources > Filters to export non-resource files** so the data files are included.

## Tests

```
godot --headless --path . res://tests/smoke_test.tscn
```

This checks data loading, mods, the clock and calendar, world generation (same seed, same world), pathfinding, pawn movement, the household and the save round trip. Run it as a scene as shown; it needs the autoloads, which `--script` mode does not provide.

## Graphics notes

The terrain is procedural, so changing how it looks means editing `shaders/terrain.gdshader`. The `terrain()` function holds one block per style, `tree_shape()` and `tree_outline()` define the oak and pine silhouettes, and light always comes from the top-left (`LIGHT_DIR`). Tiles are 48 pixels at zoom 1 (`TILE_SIZE` in `map_view.gd`; change it there and everything else follows). Colors come from `data/tiles.json`, so a mod can re-tint the whole world. The shader uses only features of Godot's Compatibility renderer, so it runs on modest GPUs.

This is a procedural approximation of the RimWorld look. The real thing relies on hand-painted textures and sprites, so when characters, furniture and buildings arrive they will be sprites drawn on top (made in Krita or Aseprite, or from a free pack); the day and night tint (a `CanvasModulate` node) will apply to them automatically. To stop the dark nights, set the night colors in `day_night.gd` closer to white. The HUD colors are constants at the top of `scripts/ui/hud.gd`.

## Known limits

Pawns can walk through each other and are drawn over tree canopies. Neither matters until there are buildings and more people; both get revisited with milestones 3 and 4.

## Next: milestone 3, needs

Hunger, energy and the other needs from `needs.json` that fall over time, and a person who walks to food or a bed and uses it on their own when you are not giving orders.
