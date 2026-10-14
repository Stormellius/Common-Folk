# Common Folk

**Common Folk** is a medieval life sim sandbox with RimWorld-style looks: you live one person's life at a time in a randomly generated town that keeps running without you. The people you play are your **folk**. The plan from here is in [ROADMAP.md](ROADMAP.md); this project is at **milestone 13 (Life and death)**.

## What works now

- Seeded random terrain (grass, forest, water, stone, dirt), and on top of it a generated town: a rounded clearing, two dirt roads crossing in the middle, your own lot (16 by 13, south-west of the crossing), and along the roads a tavern, shop, clinic, village green, five houses and two empty lots, all from templates in `data/buildings.json` with the door turned to face the road. The same seed always gives the same town
- Twelve townspeople live in the houses in families (shared surname, two adults and the children the beds allow). They have needs, traits and moods like your household, sleep, eat and wash at home, use the tavern's lute and the clinic's basin, and wander the roads, the green and their own yard by day. Children are drawn smaller and have only two traits. Things on a private lot can only be used by the people who live there; the tavern, shop, clinic and green are open to all. Deaths in town leave a grave and a message
- Terrain drawn by a GPU shader in a gritty RimWorld-like style: muted earthy colors, grain, grass tufts, pebbly dirt, shallow-to-deep animated water, plated rock with a lit bevel and a cast shadow, and oak and pine trees with shadows. No art files needed yet
- Day and night light (blue nights, warm dawn and dusk) and seasons (green spring, golden summer, brown autumn, snowy winter) that follow the game clock
- Buildings with depth: a wall fills its tile and joins its neighbors, with a lit top, a shaded face where it ends to the south and stonework or planking that runs on from tile to tile, and walls throw soft shadows on the ground and floors east and south of them (light comes from the top-left everywhere). Floors are seamless boards, flagstones and strewn straw
- Firelight: after dark, hearths, cooking fires, the watch post's lantern and the altar's candles light up what is around them and flicker. Walls stop the light (a doorway lets the glow out), so a lit room stays inside its walls. Smoke rises from hearths and drifts off on the wind
- Weather, as a look only (needs and work do not notice it yet): each day is clear, cloudy or wet, rolled from the world seed with chances per season. Rain streaks down (snow in winter), heavy cloud dims and cools the day, cloud shadows drift across the town, and fireflies come out on summer nights
- People dress for who they are: hoods and straw hats for peasants, felt caps for burghers, feathered hats, circlets and a gold trim for the gentry, linen coifs for many women, an apron for anyone who works a counter, belts, and beards for some men. The ill look pale, everyone breathes while standing, and names that would overlap stack under each other
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
- Talking and opinions: everyone has an opinion (-100 to 100) of the people they know, shown with a label (Friend, Rival...) in the panel. Family starts fond of each other, strangers at zero, and opinions drift back toward neutral over the days. Right-click another person to chat, joke or argue (adults can also be intimate once they like each other enough). Chatting fills Social and warms the opinion, a joke can fall flat, an argument sours it. People also chat on their own when lonely: villagers talk to villagers, your household talks to anyone nearby. Speech bubbles show who is talking
- Town events: a seeded roll each morning can bring a festival (people gather on the green and feel less lonely), a market day (food is half price) or a cold snap (winter only; warmth drains faster for three days). A message appears when one starts and ends
- Three ways to begin (a start screen on a new world; `--start=bought|inherited|arrived` skips it): **bought land** (freehold, a camp, 90d, burghers), an **inherited cottage** (freehold, a standing house, 100d, gentry who will not do menial work and pay more tax) or **arrived with nothing** (the Crown lets you camp on the plot as a leaseholder for rent, 12d, peasants)
- Land and the Crown: every lot you hold has a title, freehold or leasehold. Every fifteen days is a quarter day: the tax collector takes land tax (rent for a leasehold), guild dues and a share of your business's takings from the purse, scaled by your class. A short purse means he takes your dearest furnishing instead, and your standing falls; debts he cannot cover carry over, with a warning. Miss a second quarter day in a row and you are **evicted**: every lot you hold goes, your furnishings are taken (the house's walls stay), a business lot is empty again, the debt is wiped, your standing falls by 20 and everyone is miserable about it. You can lease your old plot again from the right-click menu (the entry fee) and start over. Decrees proclaimed on quarter days change the next quarter (a jubilee halves the tax, a war levy raises it and bread costs more, fair prices cut food costs). A leasehold can be bought out. The panel under the purse shows your class, title, the next tax day and what it will ask
- A business lot: join the Merchants' Guild at the notice board (25d; the household becomes burghers, pays less trade tax and may hold a business lot), then right-click an empty lot to lease or buy it. Build tavern tables, ale barrels and bread shelves there (the Business tab in build mode) and townspeople who are hungry or bored will pay to use them; the coin goes to your purse
- Faith and the chapel: the town has a chapel with an altar and pews, and Faith is now a need (it never slows anyone, and the Pious trait makes it drain faster). People pray when it runs low, a service is held about every week (the chapel fills and Faith and Social are restored), and you can build pews and an altar of your own
- Illness: each midnight someone may catch a fever (likelier in autumn and winter, when filthy and in a cold snap). The ill feel low, tire faster and stay off work; most recover in a few days, resting helps, and a fever that drags past nine days kills. The clinic's sickbeds (10d) cure it, and ill people with the coin go there on their own
- Raids and war, off-screen: from day 10, word now and then arrives of bandits or a warband with a strength and a number of days. You never fight. The outcome is the town's defense (food in the town, able adults, your standing, the defense fund and any watch posts you build) against that strength plus a little luck. Give coin to the fund at the notice board and build watch posts to tip it. A victory raises your standing; a defeat costs a share of your purse, some townspeople's lives and perhaps a member of your household
- When the head of the household dies the eldest adult takes over and the Crown takes a tenth of the purse as death duty
- Growing up and growing old: every game has a lifespan (chosen on New Game: short, normal, long, epic, or by the calendar), which says how many days make a year of someone's life. On Normal it is four, so a whole life fits a game. The stages are baby, toddler, child, youth, adult and elder, and the panel shows the stage and the age. At sixty folk grow old: they walk slower, tire sooner and keep clear of heavy work, and each has their own age, between 62 and 80, at which they die of old age
- Dying, as in the Sims: nobody drops dead any more. Someone whose time has come (starving, freezing, a fever that will not break, old age) falls where they stand and lies dying. A little later **Death** appears, a tall hooded figure with a scythe, glides up and waits at their side, and after a few hours he takes them. While he waits, any of your folk can right-click the dying and **plead with Death**: the more they loved them the likelier he relents (they get up again, weak and shaken), but he hears one plea only and never spares the old. Anyone nearby when he comes is shaken too
- The dead are buried in the chapel yard (or on the nearest open grass) and everyone who knew them mourns them by name, as hard as they were close: "Lost Ben Marsh" for family, "Mourning..." for friends, and a rival is glad. Some of the dead are restless: on some nights their **ghost** walks near the grave, glowing pale in the dark, and anyone who sees it is frightened. Right-click the grave to pray for that soul and lay it to rest
- Children: being intimate with a man gives a woman of the household a chance of conceiving. After 12 days everyone knows she is expecting (she eats and tires more and her mood lifts), in the last weeks she is heavy and stays off work, and after 45 days a baby is born into the household (a message names it; everyone is glad). She needs 15 days to recover before she can conceive again. A baby is carried by the household, cannot be selected or talked to and needs nothing, until it turns two. A year is 60 days, and everyone has a birthday: at 18 a child becomes an adult and finds their orientation. If only babies are left, the playthrough ends. Townswomen never conceive
- Hover a tile to see what it is and whether it is walkable
- A title screen over a living town at dusk (Continue, New Game, Load Game, Settings, Quit). New Game picks how you begin and takes a seed: a number, any word (the same word always makes the same town), or nothing for a new one
- Menus in the game's own look: carved wood panels with a gilt edge, parchment dialogs and book type (IM Fell English for headings, Alegreya for text). Esc opens the pause menu (Resume, Save, Load, Settings, Main Menu, Quit), H the list of keys, and the Menu button does the same as Esc
- Save to named saves, as many as you like (`user://saves/`), as well as the quick save (F5) and the autosave every midnight. The load list shows each save's family, how many folk, the date in the game and when it was saved, and can delete one. Saves are written to a temporary file first and moved into place, a damaged or cut-off file is refused without changing anything, older saves (formats 1 to 8) still load, and the camera position and zoom come back
- Settings, kept between runs in `user://settings.cfg`: windowed, fullscreen or borderless window (F11 switches), the window size, interface size, vsync, and the morning autosave
- All content (tiles, seasons, needs, traits, buildings, the town's makeup) comes from JSON files in `data/`, and mods can add or replace it

## Run it

1. Install Godot 4.4 or newer. On Nobara: `flatpak install flathub org.godotengine.Godot`, or install the `godot` package with dnf.
2. Open Godot, click **Import**, choose this folder's `project.godot`, then press **F5** (or the play button).
3. The first time, Godot builds its class cache. If you see "identifier not found" errors for `WorldState`, `MapView` and similar, close and reopen the project once.

An ordinary launch opens the title screen. Options go after `--` on the command line, which is handy for testing and screenshots; any of them goes straight into a game, and leaves the window as the command line made it (the window settings are not applied):

```
godot --path . -- --seed=1234 --day=50 --hour=12 --zoom=0.5 --look=70,30 --speed=0
```

`seed` is the world, `day` and `hour` set the date (day 0 is the first day, 15 days per season), `zoom` the camera zoom, `look` the tile to center on, and `speed` 0 to 3, `walk` a tile (such as `--walk=70,50`) to send the selected person to, and `menu` a tile to open the right-click menu on, `load=1` to load the newest save at start, `shot=path.png` to save a screenshot a moment after starting and quit, `weather` (`clear`, `cloudy`, `rain` or `snow`) to override the day's weather, `screen` to open a menu at the start (`pause`, `save`, `load`, `settings`, `new` or `game_over`), `title=1` to show the title screen anyway, `lifespan` for a new game's lifespan (`normal` if not given), `fall=90` to have the selected person fall that many minutes ago (to see Death come), `ghost=1` to have a townsperson die and their ghost walk tonight, `dying=1` to put the selected person minutes from starving, `needs` values for the selected person (such as `--needs=rest:10,hunger:30`), `build` to start in build mode with a tool (`--build=place:wall`, `floor:planks`, `remove`, `move`), `demohouse=1` to build a small room with the real build commands, and `together=1` to start the two-person interaction.

## Controls

| Key | Action |
| --- | --- |
| WASD / arrow keys | Move the camera (hold Shift for faster) |
| Left-click a person | Select that person |
| Right-click | Menu of actions for the selected person at that spot (Walk here, Stop, object actions, and interactions when you click another person). Left-click a person to switch to them |
| B | Build mode: pick a tool in the palette, left-click or drag to build, right-click or Esc to put it away |
| Escape | Close the right-click menu; in build mode, put the tool away, then leave build mode; otherwise open the pause menu |
| H | Show or hide the list of keys |
| F11 | Switch between the window and a borderless full screen |
| Tab / Shift+Tab | Next / previous person (camera jumps to them) |
| C | Center the camera on the selected person |
| Mouse wheel | Zoom |
| Middle mouse drag | Pan |
| Space | Pause / resume |
| 1, 2, 3 | Set speed |
| G | Toggle grid |
| Home | Recenter camera |
| F5 / F9 | Quick save (`user://savegame.json`) / load the newest save of any kind |
| N | A new game (opens New Game) |

## How it is organized

The simulation never touches the screen, and the screen only reads the simulation. Keep it that way and pause, speed control, saving and off-screen simulation all stay easy.

```
data/                  Base content as JSON (one file per kind of thing)
fonts/                 IM Fell English and Alegreya, with their licenses (SIL Open Font License)
mods/                  Mods, one folder each (example_mod is disabled by default)
scenes/main.tscn       The only scene
shaders/
  terrain.gdshader     Paints the whole map on the GPU
  clouds.gdshader      Drifting cloud shadows
scripts/
  autoload/            Global singletons
    data_registry.gd     Loads data/ and mods, answers "what is tile X?"
    game_clock.gd        Fixed ticks, speed, calendar
    settings.gd          Player settings in user://settings.cfg: window, interface size, autosave
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
    relations.gd         Opinion labels, family starting opinions, daily drift
    realm.gd             The Crown: land titles, lots for sale, guild, quarter-day tax, decrees, succession
    starts.gd            The three ways of beginning (data/starts.json)
    illness.gd           Catching and recovering from sickness (data/illness.json)
    life.gd              Life stages, the lifespan, birthdays, elders and old age (data/life_stages.json, lifespans.json)
    mortality.gd         Dying, Death and pleading with him, mourning, graves and ghosts (data/death.json)
    pregnancy.gd         Conception, pregnancy, birth, carried babies and growing up (data/pregnancy.json)
    conflict.gd          Raids and war, worked out off-screen from the town's defense (data/conflicts.json)
    event_director.gd    Rolls and runs town events from data/events.json
    household_generator.gd  Seed -> starting family (names, looks, where they stand)
    path_finder.gd       A* over the tile map
    simulation.gd        Ticks the world; the commands views may give (order_move, order_use, build_place...)
    save_game.gd         Writes and reads the save file
    save_slots.gd        Where saves live: named saves, the quick save, the autosave and what each one is
  view/                Drawing and input for the map
    map_view.gd          Feeds the world and season look to the terrain shader (drawn in chunks)
    day_night.gd         Tints the map by time of day and cloud; says how dark it is
    tile_cursor.gd       Hover highlight and grid
    pawn_art.gd          Draws a person with code, and works out what they wear (swap for sprites later)
    object_art.gd        Draws beds, pots, walls, doors... with code
    floor_art.gd         Draws planks, flagstone and straw
    floor_layer.gd       The floors, between the ground and the objects
    shadow_layer.gd      Soft shadows walls throw on the ground and floors
    build_controller.gd  Build mode: lot shading, preview and mouse tools
    build_ghost.gd       The green/red preview under the mouse
    object_view.gd       One object on screen, with its firelight and, for a wall, what blocks the light
    object_layer.gd      All objects, drawn under the people
    pawn_view.gd         One pawn on screen, gliding between tiles
    pawn_layer.gd        All pawns, route overlay, name stacking and mouse orders
    death_layer.gd       Death coming for the dying, the soul he leads away, and the ghosts
    smoke_layer.gd       Smoke rising from hearths
    cloud_shadows.gd     Cloud shadows over the whole map
    weather.gd           The day's weather; rain, snow and fireflies drawn over the screen
    camera_controller.gd Pan and zoom
  ui/ui_theme.gd       The look of every menu: drawn wood, parchment and gilt, and the fonts
  ui/ui_root.gd        The root of a screen of interface: carries the theme, scales by the interface size
  ui/hud.gd            While playing: clock and speed buttons, your folk, the panel about the one you control, tile info, help, messages
  ui/menus.gd          Title screen, new game, load, save, settings, pause menu and the end of a playthrough
  ui/season_glyph.gd   The little season picture beside the date
  ui/pawn_portrait.gd  Small person picture for the household bar
  ui/build_icon.gd     Palette pictures for the build mode buttons
  ui/action_menu.gd    The right-click pop-up list
  main.gd              Wires it together: the title screen, starting and loading games, the menus, shortcuts
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

`names.json` (given names and family names) and `appearance.json` (skin, hair and clothing colors) feed the household generator, so a mod can change who your people are. `needs.json` lists the needs (`drain_per_hour`, `optional: true` for ones nobody has yet, `slows_when_empty: false` for ones that can sit at zero harmlessly, like Libido, and `fatal_after_hours` with a `death_cause` for ones that can kill); `traits.json` changes drain rates and, with `thought_multipliers`, how strongly thoughts land (a trait with `"group": "orientation"` is an orientation: every new person gets exactly one of those plus two other, different traits); both are used now, and traits will matter more in milestone 7. Seasons in `seasons.json` can carry `need_drain_multipliers` (winter makes warmth drain 2.5 times faster), and the weather: `rain_chance` and `cloud_chance` per day (a wet day snows when the season's `snow` is 0.5 or more) and `fireflies: true`.

`objects.json` describes the things people use:

```json
{ "id": "bed", "name": "Straw bed", "action": "Sleep", "doing": "Sleeping",
  "blocks_walking": false, "use_position": "on", "pose": "lie",
  "satisfies": { "rest": 14.0 }, "max_use_minutes": 600 }
```

`light` makes a thing glow after dark: `{ "color": "#ff9040", "radius": 4.5, "energy": 1.0 }` (radius in tiles; walls block it). `smoke: true` sends smoke up from it. `category` (default `furniture`) picks the build palette tab, `buildable: false` keeps something out of it, `connects` makes walls and doors join their neighbors, and `drag: true` lets the tool run a row. `satisfies` is points restored per hour of use; a person stops when every need it fills is full or after `max_use_minutes`. `use_position` is `on` (stand on the tile) or `beside`. `action` is the right-click menu entry and `doing` the activity shown in the panel. A need is only in play while some object satisfies it, so adding an object with `"satisfies": { "faith": 20 }` switches Faith on (it also needs `optional` to be false). Objects with no drawing in `object_art.gd` appear as a crate.

`thoughts.json` lists the thoughts. A state thought has a `when` (`need` with `below` or `above`, `idle`, or `alone`) and holds while that is true; thoughts sharing a `group` do not stack, the strongest wins. An event thought has `on` (`used:<object id>`, `interaction:<id>`, `death`) and `hours` it lasts. `only_for` and `never_for` take trait ids.

`economy.json` has one entry: the currency's `symbol`, the `start_coins` of a household, a `npc_start_coins` range for townspeople and the `refund_percent` when something is taken down. An object's `cost` is what building it costs, its `price` is what each use costs (the tavern table is 4d), and `offers_work` (`"town"` for the notice board, `"lot"` for a counter) makes it list vacancies. A floor's `cost` is per tile.

`jobs.json` lists jobs: `workplace` (the kind of building: `tavern`, `shop`, `clinic`, `park`), `positions`, `wage` per hour, the shift's `from` and `to` hours, the `station` object a worker stands beside and `min_age`. The town fills all but one position of each business with townspeople at the start. Wages are the only money coming in and prices and building the only money going out for now; taxes and rent come with the medieval layer.

`worldgen.json` has one entry, `town`: `npc_count`, how many `buildings` of each kind (`tavern`, `shop`, `clinic`, `park`, `house`, `vacant`; a mod can add kinds), the clearing's `half_width`, `half_height_up` and `half_height_down`, the `home_lot_size` and the `vacant_lot_size`.

`buildings.json` holds the templates, each a picture in characters, one per tile: `#` timber wall, `S` stone wall, `+` door, `.` floor, a space for nothing, and a letter for an object (b bed, p cooking pot, h hearth, w wash basin, c chamber pot, l lute, t table, k counter, s shelf, r barrel, n bench, W well, m tavern table, a ale barrel, f bread shelf, B notice board, A altar, P pew, H sickbed). Draw the door in the bottom wall; the generator mirrors the template at random and turns it to face the road. `kind` says what it is (a `house` is filled with a family, one person per bed), `floor` is a floor id from `floors.json` laid inside, and `"public": true` lets anyone use what is in it.

`floors.json` lists the floors the player can lay (`color`, `line`, and a `pattern` of `planks`, `flags` or `straw`).

`illness.json` lists illnesses: `chance_per_day`, `season_multipliers`, `dirty_below` and `dirty_multiplier`, `recovery_per_day` (plus `rested_bonus` when well rested), `fatal_after_days` with a `death_cause`, and `need_drain_multipliers` while ill. An object that lists the illness in `cures` (with `cure_minutes`) heals whoever uses it; an event can set `illness_multiplier`. `conflicts.json` lists threats: `chance_per_day`, `cooldown_days`, `warning_days`, a `strength` range, the `announce`, `victory` and `defeat` texts with `{days}`, `{strength}` and `{defense}`, `plunder_percent`, `casualties` (a range), `household_death_chance` and the standing changes. How defense is counted is in `realm.json` under `defense`, and an object's own `defense` value is what a watch post adds. `distraint_exempt` in `realm.json` lists what the tax collector will not take.

`starts.json` lists the ways of beginning: `title` (an id from `titles.json`), `class`, `coins`, `house` (a template from `buildings.json` already standing on the lot, or empty) and `camp` (the shared things set out, left out for all of them). `titles.json` has `tax_per_tile` per quarter, `price_per_tile` for buying and `entry_per_tile` for taking a lease. `classes.json` has a `rank` and a `tax_multiplier`; a job in `jobs.json` can list classes in `not_for`. `guilds.json` has the `join_fee`, `dues`, the class it `makes` its members, what it `grants` (`business_lot`) and its `business_tax_percent`. `realm.json` has `tax_every_days`, `business_tax_percent`, `death_duty_percent`, `max_business_lots`, `eviction_after_quarters` (consecutive unpaid quarter days before eviction) and `eviction_standing`, `decree_chance` and the standing changes. `pregnancy.json` has `duration_days`, `announce_after_days`, `heavy_after_days`, `recovery_days`, `max_mother_age`, `need_drain_multipliers` for an expecting mother and `heavy_work_break` (`infant_until_age` is only used if `life_stages.json` has no toddler stage); the chance of conceiving is `conception_chance` on the intimacy interaction in `interactions.json`.

`life_stages.json` lists the stages with the age each starts at (`from_age`); a stage can set a `walk_multiplier`, `need_drain_multipliers`, `heavy_work: false` (no job marked `"heavy": true` in `jobs.json`) and, for the last one, `dies_between` (the range of ages at which people die of old age). Babies are carried until the toddler stage. `lifespans.json` lists the lifespans a new game can have, with `days_per_year`. `death.json` has one entry: when Death `appears_after_minutes`, `arrives_after_minutes` and `takes_after_minutes` after someone falls, how long a plea takes (`plead_minutes`), its chance (`plead_chance`, plus `plead_chance_per_opinion` and a `plead_bonus` per trait), the needs the spared get back (`spared_needs`), the causes he `never_spares`, the chance a soul is restless (`restless_chance`, `restless_chance_old_age`), the chance a restless one walks on a night (`haunt_chance`) and between which hours, how near a ghost frightens people, and the opinions behind mourning (`mourn_close_from`, `mourn_from`) and gladness (`glad_below`). A thought's text can say `{name}`: the person it is about ("Mourning {name}"). An object with `"autonomous": false` (the grave) is only used when you say so.

A decree is an event with `"decree": true` and a `tax_multiplier`; it is never rolled with the others, only proclaimed on quarter day.

`events.json` lists town events: `chance` per day (rolled from the world seed and the day number, so a seed always has the same events), `seasons` it can happen in, `cooldown_days`, `start_hour`, `duration_hours`, and effects: `need_drain_multipliers`, `price_multipliers` (by object id), `gather` (a kind of building where people gather) with `restore` (need points given while there) and a `thought` id.

`interactions.json` describes things two people do together. Each can set `satisfies`, `max_use_minutes`, `pose` (`talk` or `close`), `opinion` (`gain`, plus `backfire` chance and `loss` for jokes that flop), `min_opinion` (needed to offer it) and `autonomous` (people do it on their own when a need is low). Chat, joke and argue are in the file as examples. Libido is filled this way too: right-click another adult and pick the entry.

```json
{ "id": "intimacy", "action": "Be intimate with {name}", "doing": "Spending private time together",
  "satisfies": { "libido": 200 }, "max_use_minutes": 30, "adults_only": true,
  "requires_attraction": true, "willing_below": { "libido": 85 }, "unwilling": "isn't in the mood" }
```

Both people must be adults, attracted to each other (`requires_attraction` reads the orientation traits in `traits.json`: `attracted_to` is `opposite`, `same`, `both` or `none`; someone with none of them is open to anyone) and willing (`willing_below`: each need listed must be under that number, otherwise the entry is greyed out with the `unwilling` reason), and the other person must not be busy. The asker walks over, both stand still side by side with hearts over their heads, both needs fill, and the panel says only what `doing` says. Nothing explicit is shown, and the people never do this on their own: only the player starts it (it needs a liking of at least 25). Ordering either person elsewhere ends it for both.

If you export the game, add `*.json` under **Resources > Filters to export non-resource files** so the data files are included.

## Tests

```
godot --headless --path . res://tests/smoke_test.tscn
```

This checks data loading, mods, the clock and calendar, world generation (same seed, same world), the town (lots keep apart, everything is reachable, houses are equipped, people live in families, private things stay private, a day in town, a death in town, saving it), pathfinding, pawn movement, the household, the right-click actions, needs and objects, coin and work (prices, build costs, shifts, wages, hiring, quitting), chatting and opinions, town events, starts, land, the guild, tax and succession, the chapel and Faith, illness and cures, raids, building, death, thoughts and mood, and the save round trip. Run it as a scene as shown; it needs the autoloads, which `--script` mode does not provide.

```
godot --headless --path . res://tests/main_flow.tscn
```

This runs the real game from the title screen the way a player would: a new game, the pause menu, saving to a named save, back to the title screen and loading it again.

```
godot --headless --path . res://tests/balance_check.tscn
```

This is not a pass/fail test. It plays 15 days in spring and in winter on three seeds with nobody giving orders and prints deaths (yours and the town's), mood and the lowest each need got, so you can see whether a change to needs, thoughts or the camp broke the balance.

Two more helpers: `res://tests/town_dump.tscn -- --seed=7` prints a picture of a generated town in characters, and `res://tests/perf_check.tscn` times one game day with the whole town (about 1.5 ms per tick). For the art, `godot --path . res://tests/pawn_gallery.tscn` shows one person of each class, sex and outfit from all four sides (add `-- --shot=gallery.png` to save it and quit; it needs a window, not `--headless`).

## Graphics notes

The terrain is procedural, so changing how it looks means editing `shaders/terrain.gdshader`. The `terrain()` function holds one block per style, `tree_shape()` and `tree_outline()` define the oak and pine silhouettes, and light always comes from the top-left (`LIGHT_DIR`). Tiles are 48 pixels at zoom 1 (`TILE_SIZE` in `map_view.gd`; change it there and everything else follows). Colors come from `data/tiles.json`, so a mod can re-tint the whole world. The shader uses only features of Godot's Compatibility renderer, so it runs on modest GPUs.

Everything else is drawn by code too, in one style: dark outlines, a soft drop shadow, light from the top-left. Walls fill their tile; `WALL_FACE`, `TIMBER` and `STONE` at the top of `object_art.gd` set how tall their south face looks and their colors, and `shadow_layer.gd` sets how dark and wide their shadows are. Floors keep their colors in `data/floors.json`. People's outfits are chosen in `PawnArt.outfit_for()` from their class, sex, age, job and a hash of their name, so nothing extra is saved and the same person always looks the same; the hats, hoods and coifs are drawn by the functions under it.

Firelight is a `PointLight2D` on each object with a `light` in `objects.json`, brighter the darker it is (`DayNight.darkness`), and every wall but a door carries a thin `LightOccluder2D` along its middle, so the inner face of a wall is lit and the light stops there. The terrain is drawn in 16 by 16 tile chunks (`CHUNK_TILES` in `map_view.gd`) so each light only has to be worked out where it reaches. Weather, smoke and fireflies run on a clock that stops while the game is paused; cloud cover and wind come from `Weather`'s static values, and `DayNight` dims the day by `Weather.gloom`.

This is a procedural approximation of the RimWorld look. The real thing relies on hand-painted textures and sprites, so characters, furniture and buildings can later become sprites drawn on top (made in Krita or Aseprite, or from a free pack): replace `PawnArt.draw()`, `ObjectArt.draw()` or `FloorArt.draw()` and leave the rest alone. The day and night tint (a `CanvasModulate` node) and the firelight will apply to sprites automatically. To stop the dark nights, set the night colors in `day_night.gd` closer to white.

The menus get their look from `scripts/ui/ui_theme.gd`: the colors are constants at the top, and the wood, parchment, button and check-box textures are drawn by the functions at the bottom. Labels and panels pick a look by type variation (`HeaderLabel`, `CapsLabel`, `InkLabel`, `ParchmentPanel`...). The fonts are IM Fell English by Igino Marini and Alegreya by Huerta Tipográfica, both under the SIL Open Font License (the license files are in `fonts/`); the book face is also used for the names over people's heads.

## Known limits

Weather is only a look: rain does not make anyone wet or cold, and the weather does not change what people do. Only walls stop firelight, not furniture or people, and there are no roofs, so a house is always open to the sky. The lot may include water or rocks you cannot build on. Pawns can walk through each other and are drawn over tree canopies. Townspeople's wages come from nowhere and pile up, and the only trade is what customers spend at the tables, barrels and shelves on your business lot (nobody staffs it, and there is no stock). Townspeople are not clickable, and only chat, work, live, wander and die. Nobody lives in the tavern, shop or clinic, and the shop sells only bread. Illness does not spread from person to person. Births have no complications, a pregnancy cannot be ended or prevented, and there are no twins (milestone 14). The town starts with nobody old, so on Normal it takes a long while before its first elders die. Only the player's household has children: townspeople never conceive (they do have birthdays, and their children come of age).

## Next

Milestones 14 to 16 are planned in [ROADMAP.md](ROADMAP.md): pregnancy and babies, work sites and resources, and accidents. What the first eleven left out, roughly in the order it would matter: building is instant, with no builders, materials, rooms or roofs (a house is walls, a door and a floor, paid for in coin); you can hold one business lot and nobody works it; there is no marriage, and a baby cannot be played until it is two; townspeople cannot be clicked or controlled; and art is still drawn by code, to be swapped for sprites.
