# Data files and mods

Everything in the game that can be a list lives in `data/` as JSON. Each file is an array of entries, the file name is the kind of content, and every entry has a unique `id`:

```json
[ { "id": "grass", "name": "Grass", "color": "#6b9a45", "style": "grass", "priority": 2, "walkable": true, "move_cost": 1.0 } ]
```

## Mods

A mod is a folder in `mods/` (or `user://mods/` in an exported game) with the same kinds of files, and an optional `mod.json` (`name`, `enabled`, `load_order`).

- A new `id` adds an entry; an existing `id` replaces the whole base entry, so repeat all its fields.
- `{ "id": "water", "_remove": true }` deletes an entry.
- A file with a new name adds a whole new kind of content.
- Problems (bad JSON, missing ids) are shown on screen and printed as warnings.

`mods/example_mod` turns grass bright green; set `"enabled": true` to try it. In an exported game, add `*.json` under **Resources > Filters to export non-resource files**.

## The world

| File | What it holds |
| --- | --- |
| `tiles.json` | `color`, `style` (`flat`, `grass`, `dirt`, `water`, `stone`, `forest`, `cobble`, `bridge`, `bridge_h`: picks the shader texture), `priority` (higher tiles bleed over lower ones' edges), `walkable`, `move_cost` |
| `seasons.json` | `days`, `foliage_tint`, `snow` (0 to 1), `rain_chance`, `cloud_chance`, `fireflies`, `need_drain_multipliers`. A season looks like itself for two thirds of its length, then eases toward the next |
| `worldgen.json` | `region` (map `width` and `height`, and the `settlements`: a `profile`, where (`at`, as fractions of the map) and `home: true` for the player's town), then one profile per kind of settlement (below) |
| `buildings.json` | Templates drawn in characters: `#` timber wall, `S` stone wall, `+` door, `.` floor, space for nothing, and a letter for an object (b bed, p pot, h hearth, w basin, c chamber pot, l lute, t table, k counter, s shelf, r barrel, n bench, W well, m tavern table, a ale barrel, f bread shelf, B notice board, A altar, P pew, H sickbed). Door in the bottom wall; the generator mirrors and turns it to face the street. `kind` (a `house` is filled with a family, one person per bed), `floor`, `public`, `class` (`gentry` for grand houses) |
| `floors.json` | Floors the player can lay: `color`, `line`, `pattern` (`planks`, `flags`, `straw`), `cost` per tile |
| `resources.json` | The things folk gather: `name`, `price` (what the shop sells it for; it pays `sell_percent` of that, from `economy.json`) |
| `names.json` | `given_female`, `given_male`, `family` and `town` name lists |
| `appearance.json` | Skin, hair and clothing colours |

A settlement profile has `kind` (`town`, `village`, `hamlet`), `npc_count`, `buildings` (how many of each kind: `tavern`, `shop`, `clinic`, `chapel`, `park`, `house`, `vacant`), the clearing's `half_width`, `half_height_up` and `half_height_down`, `streets` (`ns` and `ew` offsets of side streets from the centre), `plaza` (a paved square with a well and stalls), `lake` (a pond and pier), and for the player's town `home_lot_size`. `vacant_lot_size` sizes the empty lots.

## Things and people

| File | What it holds |
| --- | --- |
| `objects.json` | What can stand on the map. `cost` (to build), `price` (per use), `category` (build tab: `furniture`, `structure`, `business`, `decor`), `buildable: false`, `blocks_walking`, `use_position` (`on` or `beside`), `pose`, `action` and `doing` (menu entry and activity), `satisfies` (points restored per hour), `max_use_minutes`, `autonomous: false` (only used on your order), `cures`, `offers_work` (`town` or `lot`), `light` (`color`, `radius` in tiles, `energy`, `shadow`), `smoke`, `connects` and `drag` (walls), `defense`, `flammable` (0 to 1: how readily it burns), `fire_source` (can throw a spark), `accident` (`chance_per_hour`, `death_share`, `text`, `death_cause`: the risk of working at it), `materials` (what it takes to build, by resource id: held materials stand in for their price in coin), and for work sites `gathers` (what a use brings in), `gather_seasons`, `heavy` (not for elders), `drains` (needs lost per hour of work). An object with no drawing in `object_art.gd` shows as a crate |
| `needs.json` | `drain_per_hour`, `optional`, `slows_when_empty`, `fatal_after_hours` with a `death_cause`, `seek_below`. A need is only in play while some object or interaction satisfies it |
| `traits.json` | `need_drain_multipliers`, `thought_multipliers`, `group: "orientation"` with `attracted_to` (`opposite`, `same`, `both`, `none`). Everyone gets one orientation and two other traits |
| `thoughts.json` | State thoughts have a `when` (`need` with `below` or `above`, `idle`, `alone`, `pregnant`, `heavy`, `in_labour`, `partner`) and hold while it is true; thoughts in one `group` do not stack. Event thoughts have `on` (`used:<object>`, `interaction:<id>`, or an event name) and `hours`. `only_for` and `never_for` take trait ids; `{name}` in the text is the person it is about |
| `interactions.json` | Things two people do: `satisfies`, `max_use_minutes`, `pose` (`talk` or `close`), `opinion` (`gain`, `backfire`, `loss`), `romance` (the same), `min_opinion`, `min_romance`, `adults_only`, `requires_attraction`, `romantic` (family and the taken are out), `begins_dating`, `willing_below` with an `unwilling` reason, `autonomous`, `conception_chance` |
| `life_stages.json` | `from_age`, `walk_multiplier`, `need_drain_multipliers`, `heavy_work: false`, and for the last `dies_between` |
| `lifespans.json` | `days_per_year`: how many game days make a year of life |
| `jobs.json` | `workplace` (a building kind, or a work site: `farm`, `woodlot`, `quarry`, `herb_garden`, `jetty`), `positions`, `wage` per hour, `from` and `to` hours, `station` (the object a worker stands beside), `min_age`, `heavy`, `not_for` (classes) |
| `economy.json` | `symbol`, `start_coins`, `npc_start_coins`, `refund_percent`, and prices |

## Systems

| File | What it holds |
| --- | --- |
| `pregnancy.json` | `duration_years` (of life), trimester and `announce_at` points (as a share of the pregnancy), `labour_hours`, `recovery_years`, `max_mother_age`, `need_drain_multipliers`, `morning_sickness_chance`, `craving_chance`, `twins_chance`, `triplets_chance`, the `complication_*` chances (worse in bed or at the clinic, better with a midwife), `town_conception_chance`, and `baby_care` (the needs a baby has, `tend_below`, `cry_below`, `neglect_hours`, the cradle's hours) |
| `relationships.json` | `ask_out_romance` and `ask_out_opinion` needed, `move_in_romance`, `move_in_dating_days`, `daily_decay`, the date (`date_minutes`, hours, `date_venues`), `breakup_opinion`, and how fast the town's own people pair up and move in |
| `death.json` | When Death appears, arrives and takes, plea chances and what pleading is worth, what the spared get back, who he never spares, how often souls are restless and ghosts walk, and what makes people mourn or gloat |
| `illness.json` | Sicknesses and injuries: `chance_per_day` (0 for injuries, which only accidents cause), `season_multipliers`, `dirty_below` and `dirty_multiplier`, `recovery_per_day`, `rested_bonus`, `herb_bonus`, `fatal_after_days` with a `death_cause`, `need_drain_multipliers`; `contagious` with `spread_per_hour` and `spread_radius`, and `immunity_days` after recovering. An object lists what it heals under `cures` |
| `accidents.json` | `fire`: `spark_chance_per_day` per fire kept (a hearth), how long things `burn_minutes` (more per point of flammability), how often and how readily it spreads, how far folk flee and come to fight it, how much each takes off a fire a minute, and how long standing in it burns and kills. Floors have `flammable` too |
| `conflicts.json` | Raids: `chance_per_day`, `warning_days`, `strength`, announcement texts, plunder, casualties, standing changes. Defence is counted as `realm.json` says |
| `events.json` | `chance` per day (rolled from the seed), `seasons`, `cooldown_days`, `start_hour`, `duration_hours`, `need_drain_multipliers`, `price_multipliers`, `gather` (a building kind) with `restore`. `decree: true` makes a decree, proclaimed only on quarter day |
| `starts.json` | The ways to begin: `title`, `class`, `coins`, `house` (a template already standing), `camp` |
| `titles.json`, `classes.json`, `guilds.json`, `realm.json` | Land: tax and prices per tile; class rank and tax; guild fee, dues and grants; quarter-day length, death duty, eviction, decrees |
