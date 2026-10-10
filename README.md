# Medieval Sim

A medieval life sim sandbox with RimWorld-style looks: you live one person's life at a time in a randomly generated town that keeps running without you. The full plan is in the design document; this project is **milestone 1 (Foundation)**.

## What works now

- Seeded random terrain (grass, forest, water, stone, dirt) with a flat clearing and crossroads in the middle for the future town
- Camera: pan, zoom toward the cursor, middle-mouse drag
- Game clock with pause and 1x / 2x / 3x speed, a calendar with seasons, and a clock panel
- Hover a tile to see what it is and whether it is walkable
- Save and load (F5 / F9), new world (N)
- All content (tiles, seasons, needs, traits) comes from JSON files in `data/`, and mods can add or replace it

## Run it

1. Install Godot 4.4 or newer. On Nobara: `flatpak install flathub org.godotengine.Godot`, or install the `godot` package with dnf.
2. Open Godot, click **Import**, choose this folder's `project.godot`, then press **F5** (or the play button).
3. The first time, Godot builds its class cache. If you see "identifier not found" errors for `WorldState`, `MapView` and similar, close and reopen the project once.

To play a specific world: `godot --path . -- --seed=1234`

## Controls

| Key | Action |
| --- | --- |
| WASD / arrow keys | Move the camera (hold Shift for faster) |
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
scripts/
  autoload/            Global singletons
    data_registry.gd     Loads data/ and mods, answers "what is tile X?"
    game_clock.gd        Fixed ticks, speed, calendar
  sim/                 Game state and rules (no drawing here)
    world_state.gd       The map as plain data, turns into a Dictionary
    map_generator.gd     Seed -> terrain
    save_game.gd         Writes and reads the save file
  view/                Drawing and input for the map
    map_view.gd          Draws the tiles
    tile_cursor.gd       Hover highlight and grid
    camera_controller.gd Pan and zoom
  ui/hud.gd            Clock panel, speed buttons, messages
  main.gd              Wires it together and handles shortcuts
tests/                 Headless checks
```

One tick is one game minute. At 1x a tick takes 0.1 real seconds, so a game day lasts 144 seconds (48 at 3x). Change `TICK_SECONDS` in `game_clock.gd` to tune that.

## Data and mods

Each file in `data/` is a JSON array, and the file name is the kind of content. Every entry needs a unique `id`:

```json
[
  { "id": "grass", "name": "Grass", "color": "#6b9a45", "walkable": true, "move_cost": 1.0 }
]
```

A mod is a folder in `mods/` (or `user://mods/` in a built game) with the same kinds of files:

- A new `id` adds content.
- An existing `id` replaces the base entry.
- `{ "id": "water", "_remove": true }` deletes an entry.
- A file with a new name (say `recipes.json`) adds a whole new kind of content.
- An optional `mod.json` holds `name`, `enabled` and `load_order`.

To try it, set `"enabled": true` in `mods/example_mod/mod.json` and restart. Grass turns bright green. Problems in data files (bad JSON, missing ids) are shown on screen and printed as warnings.

`needs.json` and `traits.json` are starter content for milestones 3 and 7; nothing reads them yet.

If you export the game, add `*.json` under **Resources > Filters to export non-resource files** so the data files are included.

## Tests

```
godot --headless --path . res://tests/smoke_test.tscn
```

This checks data loading, mods, the clock and calendar, world generation (same seed, same world) and the save round trip. Run it as a scene as shown; it needs the autoloads, which `--script` mode does not provide.

## Next: milestone 2, one pawn

A character that you click to send to a tile, with pathfinding around water and stone (Godot's `AStarGrid2D` fits the tile map), moving one step per tick so it respects pause and speed.
