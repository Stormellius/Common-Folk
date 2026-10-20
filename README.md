# Common Folk

A medieval life sim sandbox with a RimWorld look, made in Godot 4.4. You play one of your **folk** at a time in a generated region of towns that carries on without you. They work, court, raise children, grow old and die, and the family goes on.

Milestones 1 to 25 are done; the plan from here is in [ROADMAP.md](ROADMAP.md). The data files and how to mod them are in [docs/DATA.md](docs/DATA.md).

## Run it

1. Install Godot 4.4 or newer (on Nobara: `flatpak install flathub org.godotengine.Godot`, or the `godot` package from dnf).
2. Open Godot, click **Import**, pick `project.godot`, press **F5**.
3. The first time, Godot builds its class cache. If you see "identifier not found" errors, close and reopen the project once.

## Playing

You control one of your folk. Left-click a person (or their portrait, or press Tab) to switch to them; right-click anywhere for what they can do there. The others carry on with whatever they were doing. A game day lasts **one real hour** at normal speed (speeds are 1x, 3x, 10x and 30x), so there is time to watch a life and a fast-forward when you want to see a childhood go by.

| Key | Action |
| --- | --- |
| Left-click | Select a person |
| Right-click | Menu of what the selected person can do there: walk, use things, work, talk, flirt, date, tend a baby |
| WASD / arrows, Shift | Move the camera, faster |
| Wheel, middle drag | Zoom, pan |
| Tab / Shift+Tab | Next / previous of your folk |
| C, Home | Centre on the selected person, on your home town |
| T, M | Visit the next town, show the whole map |
| Space, 1 to 4 | Pause, speed |
| B | Build mode: a hand to select and move things, plus walls, floors, roofs and furniture (see below) |
| R | Roofs: by the zoom, always shown, hidden |
| G, H | Grid, list of keys |
| F5 / F9 | Quick save / load the newest save |
| F11 | Window or borderless full screen |
| N, Esc | New game, menu |

**Build mode** (B) works like the Sims': the hand is in your hand to begin with. Click a thing, a floor tile or a plan to select it, drag it to move it (nothing costs anything to move), drag over bare ground to select an area and move or take down all of it at once, and press Delete to take it down. Right-click a thing for a little menu (move, take down, copy its style, take the roof off), and right-click or Esc with a tool in hand puts it back; right-click never gives your folk orders while you build. The row above the catalog has the hand, **Remove**, **Pick** (the eyedropper), **Unroof**, the shapes **Free** (drag a trail), **Box** (a rectangle: walls round the edge, floor all over; Shift-drag does the same) and **Fill** (floor a whole closed room in one click), and **Undo** / **Redo** (Ctrl+Z, Ctrl+Y) for everything you plan, move or take down. The catalog has a search box and folds away with **Catalog** to show more of the map. Placing still only makes plans: leave build mode and have someone build them.

## What is in the game

**The world.** A 480 by 320 tile map of forest, lakes and rock with five settlements: your own town in the middle (cobbled streets crossing at a market square with a well and stalls, side streets of houses, inns, shops, a clinic, chapels, a green, lanterns and gardens) and a market town, two villages (one by a lake with a pier) and a hamlet a long walk away. The larger ones have a smithy, and the towns a carpenter too. Earth roads join them, going round water or crossing it on plank bridges. Every settlement has a name and its own people, who live and work there. The same seed always gives the same world.

**Your folk.** Names, looks and traits come from the seed. Needs (hunger, rest, warmth, hygiene, toilet, social, fun, faith, libido) drain over time and feed a mood built from timed thoughts; an empty need slows a person down and some kill. Three ways to begin: bought land, an inherited cottage, or arriving with nothing.

**Life and death.** Everyone is a baby, toddler, child, youth, adult or elder, drawn differently at each age. A lifespan setting (short to epic, or the calendar) decides how many days make a year. Elders slow down and die of old age between 62 and 80. Dying is not instant: **Death**, a hooded figure with a scythe, walks up and waits; family can plead with him, and he relents more readily the more they were loved. The dead are buried, mourned by name, and some walk as ghosts until someone prays at the grave.

**Pregnancy and babies.** Pregnancy runs in three trimesters on the lifespan clock: morning sickness, cravings, a belly that shows, a heavy last stretch. Labour begins on its own and she goes to bed or the clinic's sickbed; someone staying with her is a midwife, and a hard birth can leave her weak or, rarely, kill her. There can be twins or triplets, and you name each baby. Babies sleep in a cradle and need feeding, soothing and washing; neglect one too long and the parish takes it. The town's couples have children too.

**Love.** Flirt, kiss and ask out someone you are drawn to (orientation is a trait; family and people already taken are out of reach). Dating couples go on dates to the green, the tavern or the chapel. A partner can move in with you, or you can move in with them, and a break-up sends whoever moved in back home. When you are ready, buy or forge a **ring** and propose; once engaged, hold the **wedding** at the chapel, with your household and friends as guests. The couple then share a home and a name, and stay married until death. The town's own people pair up, move in, marry and have children without you.

**Work, resources and money.** A shared purse, jobs at the shop, tavern, clinic and green with shifts and wages, and **work sites** at the edge of every town: fields (grain ripens in summer and autumn), a woodlot, a quarry, an herb garden and, by the lake, a jetty. Take a job there, or right-click a chopping block, a field or a quarry face to gather for your own stockpile. What you gather can be sold at a shop counter (more on market day) or used in building: a bed takes wood, a stone wall stone, and what you lack is bought at the shop's price. Besides that, quarter-day tax on land, titles (freehold or leasehold), the Merchants' Guild and business lots of your own, decrees, and eviction if you cannot pay.

**Skills and tools.** Fourteen skills (woodcutting, mining, farming, fishing, herbalism, cooking, healing, carpentry, smithing, music, trading, hunting, husbandry, masonry) grow with practice, to ten levels, and make a person better at the work: bigger hauls, fewer accidents, faster crafting. The young learn quickly, folk with a talent quicker, and an apprentice beside a master twice as fast. Trades pass down families (children inherit talents and the family's trade) and anyone can ask a better hand for a lesson. Work needs the right tool in hand: an axe, a pickaxe, a sickle, a fishing rod and so on, taken from the household's stockpile, worn by use and put back after. Buy them at a shop's tool rack, or forge and carve them at a smithy or workshop's forge and bench.

**Animals.** Rabbits, deer, boar and wolves live in the forest and run from people. With a bow, right-click one to hunt it: the hunter creeps up and shoots, and brings home meat and hides to sell, but a wounded boar turns on its hunter and wolves come for people out alone at night. Buy horses, donkeys, oxen, dogs and cats at a stable's hitching post, or take in a stray. Ride a horse across the map in a third of the time, lead a donkey or ox to a work site to bring home a bigger load, take a dog hunting, and make a fuss of your pets. Your animals eat from the stockpile and wander off if they go hungry.

**Trade.** Goods can be made as well as gathered: a quern grinds grain to flour, a bread oven bakes it (bakeries in the towns), a vat brews ale, a tanning rack makes leather from hides and a forge smelts iron (rings take iron now). What a good fetches depends on where you sell it: fish are cheap at the lake and dear at the market, a hamlet pays well for iron and wine, and a practised trader gets a little more everywhere. **Caravans** travel the roads between the towns with a driver on each side of the ox, camp on the market square for two days, and trade: buy cloth, salt, wine and spice from them, sell them what they are looking for at far better than the shop pays (up to what they need), or pay a fare to ride along to their next stop.

**Ambitions and wishes.** From youth on, each person has an **ambition** for a whole life: to be a master craftsman, to be loved by the whole town, to marry and raise a family, to grow rich, to live a saintly life, to see every town, to be a mighty hunter, a healer, a troubadour, a master builder, and so on (sixteen in all). It comes in steps, each a goal you can see in the panel ("become a Journeyman at a skill", "make five friends") and each reached step lifts the mood; the last fulfils the ambition, which keeps their spirits up for good, and a few days later they dream of something new. What they pick leans on who they are: the pious on a saintly life, the greedy on fortune, a gift for music on being a troubadour. They also have two small **wishes** at a time that come and go: play the lute, sit by the fire, have a chat, say a prayer, make a fuss of an animal. A wish lapses after a day or two; doing the thing grants it and lifts the mood, whether you sent them or they went on their own, which idle folk do now and then (the town's people too).

**Other families.** Every house in the towns holds a family, and any of them can be yours: press **F** (or Menu, Town Families) to see them by town and take one up. Your household and that family trade places: your old folk become the town's (the goods are sold and the money shared among them), the family you chose lives in their own house, which is now your home lot, and the Crown starts afresh with them. If your line dies out you can carry on as another family instead of starting over. You can also **move house** with the same folk into any empty house, in this town or another, leaving the old one for whoever comes next. Meanwhile the towns carry on without you: when someone dies their coin goes to their husband or wife, or their grown children, or their parents; children left with no grown-up are taken in by kin or neighbours; empty houses are taken by families arriving from elsewhere, or by families from another town with no work who hear that there is some. What happens is written in a chronicle on the same screen.

**Sound and music.** There are no recorded sounds: everything is worked out by arithmetic when the game starts (a few quiet seconds on a worker thread), the way the pictures are drawn in code. The ambience follows the camera and the clock: wind, rain and the hush of snow, birds by day and crickets on summer nights, the murmur of a town when you are in one and close, fires crackling and water lapping near you. The music is composed, not recorded: pieces in the modes of old tunes (a bright morning on the lute, a wistful evening on the flute, a slow night on the harp, a quick jig with a drum for a festival, a sad piece when someone is dying or has just died) that change with the hour and what is happening. People at a chopping block, a quarry, a forge, a bench or a building site make the sound of their work when they are near; the chapel bell rings for a service, a death is tolled, a baby cries, coins chink, a chime tells you a wish has come true, and every button clicks. A person at a **lute, harp or drum** plays a tune you can hear, quicker and surer the more they know; the harp and drum can be built (they stand in the chapels and taverns too). Volume, music, ambience and effects each have a slider in Settings.

**Town life.** Festivals, market days, cold snaps and services; the chapel and faith; raids worked out off-screen against the town's defence. People chat and quarrel and remember it.

**Danger.** A hearth can throw a spark, and fire spreads through timber, beds, straw and planks (stone does not burn). Folk run from flames and grown-ups nearby beat them out; anyone caught in them is burned, and burns kill. Work at the woodlot, quarry and jetty has its accidents: a falling tree, a rockfall, a fall into the water. Fevers come with the cold and the plague, rare and deadly, passes between people who stand close, worse among the filthy; the recovered are immune for a while. The clinic's sickbeds heal injuries and fevers, and herbs from the garden nurse the sick through. A fallen person can still be pleaded for.

**Building.** On your own lot: furniture, timber and stone walls, doors, floors, business fittings and garden decor. Building is work now: you **plan** what you want and pay for it (what you hold of the materials is set aside, what you lack is bought), and then someone has to build it. A builder with a hammer fetches materials from the pile (by your storage crates, or the gate of the lot), hauls them to each plan and works until it stands, learning carpentry or masonry as they go; hire a builder for the day at a carpenter's counter if your folk are busy. A room closed in by walls and a door can be **roofed** (thatch or tile); under a roof people lose warmth more slowly and sleep properly, while a bed in the open gives less rest. The towns' buildings are roofed from the start, and zoomed out the roofs show as a town (R cycles roofs: by the zoom, always, hidden).

**Painted art and clothes.** The art is a mix: pictures made with SpriteCook (beds, fireplaces, wells, barrels, tables, crates, bushes, wooden and stone floors, and some new decor to build) over everything still drawn by code; Settings can switch to the code-drawn look, and has a preview of painted people. People dress for what they are doing and the weather: nightclothes in bed, underclothes at the wash basin, good clothes for weddings and church, a coat and fur cap in winter, warm clothes in autumn, work clothes at a job; a coat keeps more warmth in. Painted people are layers, so skin, hair (a style and a colour, each chosen on its own on the family screen) and each piece of clothing change independently, and they walk, work and talk in moving parts (legs that step, arms that swing and lift). The HUD keeps to the corners: the fine print (tools, the realm, traits) waits for the Details button. How to add pictures is in [docs/ART.md](docs/ART.md).

**Look and feel.** Terrain drawn by a GPU shader, walls with depth and shadows, firelight and lantern light at night, seasons, weather, cloud shadows, and everything else drawn by code. Menus are dark carved wood and parchment in IM Fell English and Alegreya. A title screen, named save slots, quick save, an autosave each midnight, and settings (window mode, size, interface scale, vsync).

## Command line

An ordinary launch opens the title screen. Options go after `--`, and any of them skips straight into a game:

```
godot --path . -- --seed=1234 --day=50 --hour=12 --zoom=0.5 --look=240,160 --speed=0
```

| Option | Does |
| --- | --- |
| `seed`, `start`, `lifespan` | The world (a number), how to begin (`bought`, `inherited`, `arrived`), how fast people age |
| `day`, `hour`, `speed` | The date (day 0 is the first), the hour, the speed 0 to 4 |
| `zoom`, `look` | Camera zoom and the tile to centre on |
| `walk`, `menu`, `needs` | Send the selected person to a tile, open the right-click menu on a tile, set needs (`--needs=rest:10`) |
| `weather` | `clear`, `cloudy`, `rain` or `snow` |
| `load=1`, `title=1`, `screen` | Load the newest save, show the title anyway, open a menu (`pause`, `save`, `load`, `settings`, `new`, `name`, `game_over`) |
| `build`, `select`, `demohouse`, `together` | Start in build mode (`select`, `place:wall`, `floor:planks`, `remove`, `pick`), select tiles of the demo house with the hand (`--select=2,2;5,2`), build a small room, start a two-person interaction |
| `fall`, `ghost`, `dying`, `fire` | See Death come, a ghost walk, someone starving, something alight |
| `shot=path.png` | Save a screenshot a moment after starting and quit |

## How it is organised

The simulation never touches the screen and the screen only reads the simulation, so pause, speed, saving and off-screen simulation stay easy.

```
data/            All content as JSON, one file per kind of thing (see docs/DATA.md)
mods/            Mods, one folder each
fonts/           IM Fell English and Alegreya (SIL Open Font License)
shaders/         Terrain and cloud shadows
scenes/main.tscn The only scene
scripts/
  autoload/      DataRegistry (loads data and mods), GameClock (ticks, speed, calendar), Settings
  sim/           Game state and rules; no drawing
  view/          Drawing and input for the map: terrain, objects, people, lights, weather, camera
  ui/            Theme, HUD, menus
  main.gd        Wires it together
tests/           Headless checks and tools
```

Most of the rules live in `sim/`: `simulation.gd` ticks the world and takes the commands the views may give; `pawn.gd` is one person; `needs`, `mood`, `relations`, `romance`, `pregnancy`, `babies`, `life`, `mortality`, `illness`, `economy`, `realm`, `conflict` and `event_director` are the systems; `region_generator.gd`, `town_generator.gd` and `npc_generator.gd` build the world; `save_game.gd` and `save_slots.gd` write it down.

Time: one tick is one game minute, 2.5 real seconds at 1x. People take their steps on finer motion ticks between the minutes (`GameClock.SUBSTEPS_PER_MINUTE`), so a walk across town takes seconds. Change `DAY_SECONDS` in `game_clock.gd` to tune the pace.

## Tests and tools

```
godot --headless --path . res://tests/smoke_test.tscn     # the whole rule set, about a minute
godot --headless --path . res://tests/main_flow.tscn      # the real game from the title screen: start, pause, save, load
godot --headless --path . res://tests/balance_check.tscn  # plays days with nobody giving orders; prints deaths, mood, needs
godot --headless --path . res://tests/perf_check.tscn     # times a day of the whole region
godot --headless --path . res://tests/town_dump.tscn -- --seed=7 --town=1   # the map and one town in characters
godot --path . res://tests/pawn_gallery.tscn -- --stages=1 --shot=stages.png # people of every age, with a window
```

Run the tests as scenes; they need the autoloads, which `--script` mode does not provide.

## Credits

Type: IM Fell English by Igino Marini and Alegreya by Huerta Tipografica, under the SIL Open Font License (licenses in `fonts/`). Everything else is drawn by code.
