# Art

The game draws everything with code, and now also with painted pictures made with
[SpriteCook](https://spritecook.ai). A painted picture is used wherever there is one; anything without
one is still drawn by code, so the game is always complete and the painted art can grow a piece at a time.
(Settings has **Painted art**, to switch the pictures off, and **Painted people (preview)**.)

## How a picture gets into the game

1. Make a sheet in SpriteCook (a transparent background, many items on it, a gap between them), with the
   asset pack as the style reference (`style_asset_ids`, see `assets/spritecook-assets.json`).
2. Keep the sheet in `assets/source/` (that folder is never imported by Godot: it holds a `.gdignore`).
3. `python3 tools/build_art.py --detect assets/source/<sheet>` prints the box of every item on the sheet and
   writes `<sheet>.boxes.png` with each one numbered. Add the boxes you want, with names, to
   `tools/art_sheets.json` (`crops`; or `textures` for opaque squares; `"clean": true` on a sheet whose items
   touch, so slivers of neighbours are cleared), and run `python3 tools/build_art.py`. The pictures are written to
   `assets/art/<name>.png`. (Needs Pillow and numpy.)
4. Say who uses each picture in `data/sprites.json` and run Godot once (`godot --headless --import`) so it
   imports the new files:
   * `object.<object id>`: `files` (a picture is chosen by the tile it stands on), `fit` (the box in tiles it is
     scaled to), `base` (where its bottom edge sits, in tiles below the tile's middle), `flip`, `shadow`
   * `floor.<floor id>`: `file`, `tiles` (how many tiles across the picture is; it repeats mirrored, so no seam shows)
   * `pawn.<life stage>.<outfit id>`: `variants`, each `{ "front", "back" }`
5. `godot --headless --path . res://tests/smoke_test.tscn -- --only=art` checks that every file exists, is a sensible
   size and belongs to something real.

Textures are imported with mipmaps (`[importer_defaults]` in `project.godot`) and drawn with smooth filtering, so a
picture scaled down to a 48-pixel tile stays clean.

## What is painted now

Objects: bed, hearth, oven, well, barrel, ale barrel, table, meal table, storage crates, bush, and the new decor (chair,
chest, crates, sacks, clay jar, rug, tall grass). Floors: wood planks and flagstone. People (a preview, off by default):
every life stage from toddler to elder in underclothes, and children, youths, adults and elders in the outfits of the
sheet, front and back, two looks for each.
Also cut but not used yet (`assets/art/items`, `assets/art/characters`, more `props`): tools, a low wall and fences, plates and
cups, villagers.

## What is missing

Painted pictures for all of these would finish the look. Each line is one SpriteCook sheet (about 12 credits at 1K).
Size: items should come out 48 to 130 pixels across on the sheet (a tile is 48), seen from the same three-quarter
view as the pack, with the same thick dark outline.

| Sheet | Contents | For |
| --- | --- | --- |
| Home and kitchen | cooking pot on a tripod over a fire, wash basin, chamber pot, cradle, bench, shelf (with jars), counter | `cooking_pot`, `wash_basin`, `chamber_pot`, `cradle`, `bench`, `shelf`, `counter` |
| Workshop | forge with anvil, workbench with tools, tool rack, quern, brewing vat, tanning rack, chopping block with an axe | `forge`, `workbench`, `tool_rack`, `quern`, `brew_vat`, `tanning_rack`, `chopping_block` |
| Shop and market | market stall (striped awning), food shelf with bread, notice board, hitching post, cart, haystack, woodpile | `market_stall`, `food_shelf`, `notice_board`, `hitching_post`, `cart`, `haystack`, `woodpile` |
| Chapel and clinic | altar with candles, pew, grave (mound with a cross), sickbed, lantern post, watch post | `altar`, `pew`, `grave`, `sickbed`, `lantern_post`, `watch_post` |
| Music and garden | lute on a rug, harp on a rug, drum on a rug, flower bed, herb bed, field plot at five stages of a crop | `lute`, `harp`, `drum`, `flower_bed`, `herb_bed`, `field_plot` |
| Work sites | quarry face, jetty planks over water, a young tree and a felled one | `quarry_face`, `fishing_spot` |
| Walls and doors | timber and stone walls (a 15-piece autotile each: use SpriteCook's tileset tool), doors open and shut, thatch and tile roofs (tileset) | `wall`, `stone_wall`, `door`, roofs |
| Terrain | grass, dirt, cobble, forest floor, stone, water, with edges (tileset) | `data/tiles.json` (today a shader) |
| Trees and rocks | pine, oak, birch, dead tree, boulders, flowers | terrain decoration |
| Animals | rabbit, deer, boar, wolf, horse, donkey, ox, dog, cat, each walking in four directions (animation) | `data/animals.json` |
| Goods and tools | one icon each: wood, stone, grain, fish, herbs, ring, meat, hide, flour, bread, ale, iron, leather, cloth, salt, wine, spice; and the nine tools | the stockpile and the shop |
| People | see below | everyone |

## Clothing

Clothes are decided by `data/wardrobe.json` and `data/clothing.json` (see `scripts/sim/clothing.gd`): nightclothes in bed,
underclothes at the wash basin, good clothes for a wedding or at a pew, a winter coat or warm clothes when it is
cold (colder under the open sky and at night, warmer indoors), work clothes at a job, everyday clothes otherwise.
Each outfit keeps a share of a person's warmth, so a coat in winter really helps, and there is a swimwear outfit waiting
for the day there is swimming. The code-drawn people change what they wear (caps, scarves, fur collars, mittens, collars,
nightcaps); painted people use the sheet's pictures, falling back to a likeness in other clothes
(`OUTFIT_FALLBACKS` in `sprite_bank.gd`) and to code when there is none.

Painted people need more pictures before they can be the default: the sheet has two looks per outfit, and
nobody has the other sex's clothes. A grown-up in each of the eight outfits, for each sex, with three or four looks
(skin and hair) would be 2 sexes x 8 outfits x 4 looks, front and back: 64 pictures, about 16 sheets of four. A child,
youth and elder add about twice that again. Walking is a bounce and a squash of one picture (see `SpriteBank.draw_person`),
and the sides use the front picture turned; side views and a real walk cycle (SpriteCook's character animation tools)
would be the next step up.


## Update: layered people, animals and more

* **People are layers now** (`tools/make_layers.py`, `tools/people_sets.json`, `assets/art/people/<set>/`): a body sheet (front and back) and
  dressed copies made with SpriteCook's edit tool, which keeps the figures in place; each outfit layer is what the clothes
  changed, so any outfit stacks on any body, and a person's skin tints the body. Sets: adult man and woman, elder man and woman,
  youth, child; outfits casual, worker, formal, winter, sleepwear (warm uses winter; underclothes are the bare body).
  Babies and toddlers are still drawn by code. More looks (hair, skin tones) mean more body sheets and their five edits.
* **Animals** (`animal.<kind>` in `data/sprites.json`): all nine, side-on, turned for west.
* Cut but not wired yet: goods icons (`assets/art/goods`), trees, rocks and a log (`assets/art/trees`), tools and fences.

* **Body looks**: a set can have several bodies (`body_b_front.png`...), recoloured edits of the first, so every outfit layer fits all of them
  (`make_layers.py --look`). A person gets the look nearest to their hair and skin; adults have 3, the youth 3, elders and the child 2.
* **Maternity**: `people.adult_female_pregnant` is a heavily pregnant body with casual, work, formal, winter and sleepwear layers; it is used
  once a woman's bump shows (earlier months use the normal set, with the code-drawn bump when painted people are off).
* **Wardrobe**: a buildable object; right-click it to send someone there to change into an outfit (or back to dressing for the weather).
  Their outfit stays until they change again, except in bed, and their body look is never touched.
* **Trees**: `TreeLayer` draws painted pines, oaks and birches over forest tiles when the camera is zoomed in (zoom >= 0.75); the terrain
  shader's own trees take over when zoomed out. Oaks and birches turn autumn orange and bare in winter.
* **Goods icons**: the stockpile in the HUD shows a painted icon and count for each good with `goods/<id>` art; tools stay as words.

## HUD, sound and the family screen
* **HUD** follows The Sims: a bottom panel with the selected person's picture and mood plumbob, name, doings and the needs in a grid; your folk
  at the bottom left; build at the bottom right; the clock, purse and speed buttons top right; a top bar with the menu, Details (I: dreams,
  skills, thoughts and friends down the left) and the tile under the cursor. Panels are `_sims_panel` in `hud.gd`.
* **Sound**: the title screen plays only music; rain and snow fade in only once it is really falling; work and instrument sounds are heard only
  for people on screen.
* **Family screen**: after "How do you begin?" you draw up your family (`FamilyCreator`, `FamilyDesign`): up to five people with name, gender,
  age, skin, hair, hair style and traits. Painted people pick the body look nearest to the chosen skin and hair.
* The painted-people setting is saved as `painted_people` so an old saved "off" no longer hides the new art.
