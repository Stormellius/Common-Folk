# Common Folk: roadmap

Milestones 1 to 25 are done. This file keeps the plan for 12 to 25 as it was built, and what is left after them. Each milestone ended with the game playable, the smoke test passing and older saves still loading.

## What the people are called

The people you play are your **folk**: "your folk", "select one of your folk", "a household of four folk". One person is a villager, a townsman or townswoman, or simply by name. The people of the town who are not yours are **townsfolk**.

## Milestone 12: Interface (done)

The game gets a proper front door and menus that look like they belong in it.

- A medieval look for every menu and panel: dark carved wood with a gilt edge, parchment headings and a book-face serif font, all drawn by code like the rest of the art
- A title screen over a living town at dusk: Continue, New Game, Load Game, Settings, Quit
- New Game asks how you begin (the three starts), lets you type or roll a seed, and pick a lifespan (from milestone 13)
- Saving to named slots, as many as you like, next to the quick save and the autosave. The load list shows the family, the date in the game and when it was saved, and can delete a save
- Esc opens a pause menu: Resume, Save, Load, Settings, Main Menu, Quit
- Settings, kept between runs in `user://settings.cfg`: windowed, fullscreen or borderless, the window size, vsync, interface scale, autosave on or off
- The words in the interface use "folk"

## Milestone 13: Life and death (done)

Folk are born, grow up, grow old and die, as in the Sims, with a medieval face on it.

- Life stages: baby, toddler, child, youth, adult, elder. The age shows in the panel
- A lifespan setting (short, normal, long, epic, or by the calendar) sets how many days make a year of someone's life, so a whole life fits a game. Normal is four days a year: a baby is a toddler in four days and an adult turns elder in about five months of game time
- Elders walk slower, tire sooner, stop heavy work, and each has a hidden span: they die of old age somewhere between about 62 and 80
- Dying is no longer instant. Someone who dies collapses, and a little later **Death** comes for them: a tall hooded figure with a scythe who walks up, waits, and leads the soul away. A family member can **plead with Death**; the better they loved the dying person, the likelier Death relents (they live, shaken, with a "brush with death" thought). Death always takes the old in the end
- A grave is dug where they fell (or in the chapel yard if there is room), the household and friends mourn in proportion to how close they were, and the heir takes over as now
- **Ghosts**: some of the dead do not rest. On some nights a ghost walks near its grave, pale and drifting; anyone who sees one is frightened. Praying at the grave lays it to rest for good
- All of it is data: `life_stages.json`, `lifespans.json` and the thoughts

## Milestone 14: Pregnancy and babies (done)

- Pregnancy runs on the lifespan clock (three quarters of a year of life), in three trimesters
- A belly that shows from the second trimester and grows; morning sickness in the first, cravings in the second (a meal satisfies one), heavy in the third
- **Labour** starts on its own near the end: she makes for a bed, or the clinic's sickbed if she can get there. A midwife (whoever is on duty at the clinic, or any adult who stays with her) makes it safer. There is a small chance of complications, which leave the mother weak for a while and can, rarely, kill her; the baby always lives
- **Twins** (and rarely triplets)
- You **name the baby** in a pop-up when it is born (with a suggestion and a button for another)
- **Babies need care**: a cradle to sleep in, and needs of their own (hunger, comfort, cleanliness) that parents see to: feeding, rocking, washing. A baby that is neglected for too long is taken in by the parish. Toddlers run about and need watching too
- Townsfolk couples have children as well, so the town grows and changes

## Milestone 15: A wider world and closer ties (done)

- **A day is an hour.** One game day takes one real hour at normal speed, with 3x, 10x and 30x for fast-forwarding. Walking runs on finer motion ticks, so people still cross the street in seconds. Lifespans were halved to suit
- **A face for each age**: swaddled babies, toddlers with a curl and a bib, children with big heads, lanky youths, greying and stooped elders with wrinkles, sticks and bald heads
- **A bigger map** (480 by 320) with a proper town in the middle: cobbled streets, a market square with a well and stalls, side streets of houses, inns, shops, a clinic, chapels, lanterns, flower beds and woodpiles
- **More towns**: a market town, two villages (one by a lake with a pier) and a hamlet, each with a name and its own people and jobs, joined by earth roads with plank bridges. T visits the next town, M shows the whole map, and names show when zoomed out
- **Courtship**: flirt, kiss, ask out, go on dates, move in with a partner (or have them move in with you), break up. Family and the taken are out of reach. Townsfolk pair up, move in together and have children on their own
- A leaner README, with the data reference in `docs/DATA.md`

## Milestone 16: Work sites and resources (done)

- Five resources: wood, stone, grain, fish and herbs (`resources.json`: name, price)
- Work sites at the edge of every town: a **woodlot** by the forest, a **quarry** at the rocks, **fields** outside the walls, an **herb garden**, and a **jetty** at the end of the fishing village's pier. Each is a public lot with places to work: a chopping block, a quarry face, field plots, herb beds, a jetty
- Folk can take a job at a site (a wage, as before), or gather on their own: right-click and "Chop wood" puts what they gather in your household's stockpile. Hard work tires and soils; elders and children keep clear of the heavy jobs
- Fields follow the seasons: bare in winter, sown in spring, growing through summer, ripe in late summer and autumn, stubble after. You can only harvest what is ripe
- The stockpile shows under the purse. Building takes materials as well as coin (a timber wall takes wood, a stone wall stone): what you hold stands in for coin, and anything you are short of is bought at the shop's price, shown before you build
- Surplus sells at a shop counter, at a better price on market day
- Traders from other towns who buy and sell on the roads came later (milestone 22)

## Milestone 17: Accidents (done)

- **Fire**: a hearth can throw a spark. Fire spreads to what burns (timber walls, beds, straw, plank floors; each says how much), folk run from it and grown-ups nearby beat it out on their own, and anyone caught in it is burned and can die. Stone does not burn. Right-click a flame to fight it
- **Work accidents**, rare: a falling tree at the woodlot, a rockfall at the quarry, which injure or kill
- **Drowning**, very rare, while fishing
- **Plague**: an illness that spreads from person to person when they are close, worse among the filthy; the recovered are immune for a while, herbs nurse the sick through, and the sickbeds heal injuries. Rare, and deadly

## Milestone 18: Skills and tools (done)

- **Eleven skills** that grow with practice: woodcutting, mining, farming, fishing, herbalism, cooking, healing, carpentry, smithing, music and trading. Each has ten levels (novice to master) and its own effects: more wood, stone, grain, fish or herbs from every trip, fewer accidents, bigger meals, livelier tunes, faster and thriftier crafting, longer nursing
- Skills grow from the work itself: a shift, a gathering trip, a meal cooked, a tune played. The young learn faster (children and youths), elders slower, and someone with a **talent** for a skill faster still; beside a **master** (three levels ahead) an apprentice learns twice as fast
- **Trades pass on**: children inherit talents from their parents and the family's best trade; a youth is shown the basics of it when they come of age; anyone can ask a better-skilled person for a **lesson**. Townsfolk without work take a vacancy in town, and follow their family's trade first
- **Tools in hand**: chopping needs an axe, quarrying a pickaxe, reaping a sickle, fishing a rod, herb picking a knife, nursing a healer's satchel, forging a smith's hammer and carpentry a hammer. The household's tools sit in its stockpile; whoever sets to work takes one, it wears with use and breaks in the end, and it goes back when they stop. The employer's tool is lent to anyone on a wage job
- Tools are **bought** at the tool rack of any shop, smithy or workshop, or **made** at a forge or workbench from wood and stone (recipes are data: `recipes.json`). Towns now have a smithy and, in the bigger ones, a carpenter's workshop with jobs for a smith and a carpenter
- The panel shows a person's skills with a bar to the next level, the tool in their hand, their talents and family trade; the tool in hand is drawn

## Milestone 19: Marriage and weddings (done)

- **Rings**: bought at a shop counter, or forged by a smith of some skill. Proposing needs one
- **Engagement**: a couple who have been together a while and trust each other can be asked; the ring is spent, both are glad of it, and they are fiancé and fiancée until the wedding. An engagement can be broken off
- **A wedding at the chapel**: choose "Marry {name} at the chapel" (mornings and afternoons, a day after the proposal). The couple walk to the altar in wedding clothes with a flower garland, the household and the friends and kin who are free come and stand in the chapel, the vows are said, and everyone leaves happier (and the guests a little less lonely)
- **A married household**: the couple share a home (the one with a spare bed takes the other in, and a townsperson who marries one of your folk joins your household), the wife takes her husband's surname (a rule in the data; the name she was born with is kept and shows as "née"), and a marriage lasts until one of them dies, when the other is a widow or widower and free to marry again
- The town's own couples who share a home marry by themselves, and you hear of it if you know them

## Milestone 20: Animals (done)

- **Wild game**: rabbits, deer, boar and wolves live in the forest, graze, and run from people who come near (more so once startled). The wilds are stocked when a world is made and thin out and fill again over the days
- **Hunting**: with a bow (bought, or carved at a workbench) right-click an animal to hunt it. The hunter creeps up, shoots when in range (skill, distance and the animal's quickness decide the hit; a dog of the household helps) and brings home meat and hides. A wounded **boar** turns on its hunter; **wolves** come for people out alone in the dark. Hunting is a skill (more from each kill, fewer injuries)
- **Mounts**: a horse (or donkey) can be ridden: the rider travels at more than twice the pace, sits above the animal, and gets down when they reach a bed or a job or have stood about a while. Animal care makes a better rider
- **Pack animals**: lead a donkey or ox and it follows; at a work site it carries a share of the load again, so a gatherer brings home half as much again (an ox, twice as much)
- **Pets and strays**: dogs and cats, owned by many of the town's households, and strays in every street. Make a fuss of one (a lift to the spirits), take a stray in
- **Stables** in the larger settlements, with a hitching post that sells horses, donkeys, oxen, dogs and cats, and a stablehand's job
- Your animals have names, eat from the stockpile (grain for the beasts, meat or fish for pets) and go off to fend for themselves if they are left hungry for days. They are listed under the stockpile

## Milestone 21: Builders, rooms and roofs (done)

- **Building is work**: placing furniture, walls, doors and floors makes a *plan*, drawn as a see-through picture with a dashed outline, a progress bar and a square for each unit of material that has arrived. Planning pays for it: the materials you hold are set aside and the rest bought at the shop's price. Calling a plan off (or using the remove tool on it) brings the materials back and half the coin
- **Hauling**: a builder with a hammer takes materials from the pile (beside the storage crates, or the gate of the lot), carries up to four at a time (more with a led pack animal), delivers them to the plan, then works until it is done. Carpentry for timber, masonry for stone and tiles; both are skills now. Several can work at once, and a wall waits for anyone standing where it goes
- **Hired builders**: a carpenter's workshop counter hires a townsperson to build for the day, paid by the hour they work
- **Rooms and roofs**: walls and doors close in rooms; right-click inside a closed room (or use the Roofs tab) to plan a thatched or tiled roof over all of it. The towns' own buildings are roofed when generated, and an older save's buildings are roofed on loading. Zoomed in the roofs fade so you can see inside; zoomed out they make a town. R cycles them
- **Shelter**: indoors, under a roof, warmth drains far more slowly; a bed in the open gives less rest and a bad night's sleep (the tent camp is a start, a house is better)

## Milestone 22: Traders, caravans and goods (done)

- **More goods to make**: a quern (grain to flour), a bread oven (flour to bread), a brewing vat (ale), a tanning rack (hides to leather) and iron smelted at the forge. Bakeries in the towns, a brewing vat in the taverns and a tanning rack at the stables; a baker's job. Rings are forged from iron now
- **Regional prices**: each kind of settlement pays more or less for each good (`prices` in the worldgen profiles): fish are cheap at the lake, iron dear in the hamlet. The counter says when prices are high or low; a practised trader gets more
- **Caravans**: every few days a caravan (an ox cart with two drivers) sets out along the roads from one town to another, camps on the market square for two days and moves on. It follows the roads, and is drawn on the map
- **Trading with a caravan**: it sells cloth, salt, wine, spice and a little iron and leather; it buys what the region makes, paying far better than the shop for the three goods it is looking for (up to what it needs)
- **Riding along**: pay a fare and climb on; the caravan leaves within the hour and you step down at its next stop

## Milestone 23: Ambitions and wishes (done)

- **Ambitions** (`data/ambitions.json`): from youth on everyone has a lifetime goal in three or four steps, such as Master Craftsman, Friend to All, True Love, Hearth and Home, Fortune Seeker, A Saintly Life, The Wanderer, Mighty Hunter, Healer of the Folk, Troubadour, Master Builder, Teacher of the Young, Friend of Animals, Master of the Kitchen, Provider, A Contented Life, Jack of All Trades and Dreamer. Each step is a measurable goal (a skill level, friends, coin, towns visited, a deed done so many times, an engagement or marriage); a step reached lifts the mood for a day, a fulfilled ambition for five and leaves a lasting lift; a few days later they take up another
- **Who picks what**: each ambition has `weights` for traits, talents, skills, family trade, stage of life and whether they have a partner, so the pious lean saintly, the greedy rich and the gifted toward their gift; some are never picked by those they do not suit
- **Deeds**: every event that gives a thought now also counts as a deed on the person (`used:lute`, `hunted`, `interaction:chat`, `built`, `child`, `healed`...), which is what ambitions and wishes are measured from, so new content can be wished for without new code
- **Wishes** (`data/wishes.json`): two small wishes at a time (one for a child), rolled hourly from what suits them and what the world has (no wish for a lute where there is none), each lapsing after a day or two. Granting one, by doing the thing however it came about, lifts the mood (more for harder wishes). Idle folk, the town's included, act on their wishes now and then in waking hours: they go to the lute, the hearth, the pew, someone to talk to, an animal, or another town (the town's people only)
- **The panel** shows the ambition, its step and how far along, the wishes with their hours left, and what they have fulfilled; the player is told when a step is reached, an ambition fulfilled or a wish comes true. The panel shrinks to fit a short window
- The rules (how many wishes, how often they come, how long before a new dream, how far folk will go) are in `data/dreams.json`. Saves are format 13; older ones load and everyone is given an ambition

## Milestone 24: Other families (done)

- **Playing another family**: the Town Families screen (F, or the pause menu, or at the end of a line) lists every family of the towns with who is in it and their class, and any can be taken up. The household and that family swap places: the old household becomes the town's (their stockpile and tools are sold, the purse and the money shared among the grown-ups), the chosen family becomes the household, and the two houses swap ids and ground so that the family's house is the home lot, with everything that points at a lot (who lives there, whose animals) following. Old land titles go; the new house is freehold for a burgher or better and rented otherwise; the Crown starts afresh with them but the quarter days and the threat to the town carry on. The dog that was yours stays with the family that was yours
- **Moving house**: the household can move, people and pets, into any empty house in this town or another; goods, titles and standing come along, the furniture of each house stays, and the old home is an empty house for whoever comes next. The town you move to is your home town
- **Inheritance**: when someone of the town dies their coin goes to their husband or wife, else their grown children (shared), else their parents, else the grown-ups of the house
- **Orphans**: children left with no grown-up are taken in by kin or the nearest family with a bed to spare
- **Arrivals and moves**: an empty house is taken, with some chance each day, by a family from another town with no work, if its town is hiring (they leave their jobs and sell nothing: they just go), or by newcomers with a name not yet in the region. Families that have just settled stay put for a while
- **The chronicle** (the last forty things that happened: deaths and who inherits, orphans, families coming and going, and which family you took up) is on the Town Families screen and in the save. Saves are format 14

## Milestone 25: Sound and music (done)

- **Made by arithmetic** (`Synth`, `SoundBank`, `Composer`): no recorded audio. Noise filtered into wind, rain, snow hush and water; chirps, crickets, a crackling fire, a crowd's murmur; bells, a cry, a coin, an axe, a hammer; plucked strings by the Karplus-Strong method, a breathy pipe, a pad. What each sound is (a recipe and its numbers) is data in `data/sounds.json`. A worker thread makes them all at start, so the first seconds are quiet; it skips the work with no sound output
- **Ambience** (`Soundscape`): eight looping layers whose levels come from the hour, season, weather, whether the camera is in a town, how near people, fires (hearths, forges, ovens, houses alight) and water are, and how close it is zoomed; a paused game is quieter. Plain functions of a context, so they are tested without a speaker
- **Music** (`Composer`, `data/music.json`): pieces in a mode (ionian, dorian, phrygian, mixolydian, aeolian) with a tempo and a chord progression, built from phrases that walk the scale, land on the chord on strong beats and end held on the home note, over a bass, a pad and (for a festival) a drum. Five moods: day, evening, night, festival, sorrow; the music crossfades as the hour or the news changes. Each piece loops without a seam
- **Work and instruments**: objects can say `ambient` and `work_sound`; people at a chopping block, quarry face, forge, workbench or building site make that sound when near the camera and the game is running at a walking pace. An object with an `instrument` (lute, harp, drum) is played by whoever uses it: a made-up tune, quicker and with fewer sour notes the better their music skill. The harp and drum are new objects (buildable, in the chapels and taverns)
- **One-shots**: the chapel bell for a service, a toll for a death, a baby's cry, coins, a chime for a granted wish or a step toward an ambition, thunder in a heavy rain, a click on every button
- **Settings**: volume, music, wind and town, work and effects, each a slider, kept between runs. Audio buses: Music, Ambience, Effects under Master

## Painted art and clothing (done, and growing)

- **Painted pictures** (see [docs/ART.md](docs/ART.md)): sheets made with SpriteCook are kept in `assets/source`, cut into sprites by `tools/build_art.py` and used wherever `data/sprites.json` names one: beds, hearths, ovens, wells, barrels, tables, crates, bushes, plank and flagstone floors, and seven new decor objects (chair, chest, crates, sacks, clay jar, rug, tall grass). Everything else, and everything with the code-drawn look chosen in Settings, is still drawn by code
- **Painted people (preview)**: every life stage in underclothes and the sheet's outfits, front and back; off by default until there are more looks
- **Clothing** (`data/clothing.json`, `data/wardrobe.json`): eight outfits chosen by what a person is doing and how cold it is (nightclothes in bed, underclothes washing, good clothes for a wedding or church, a winter coat or warm clothes in the cold, work clothes at a job); each keeps a share of their warmth. The code-drawn people change to match, and the panel says what they wear. Swimwear is ready for when there is swimming

## Later

- More painted art, one sheet at a time: everything in the "What is missing" table of [docs/ART.md](docs/ART.md), and a full set of people (both sexes, several looks, side views, a walk cycle)
