# Common Folk: roadmap

Milestones 1 to 17 are done. This file keeps the plan for 12 to 17 as it was built, and what comes next (18 to 25). Each milestone ended with the game playable, the smoke test passing and older saves still loading.

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

## The plan from here

Eight milestones, in the order that lets each one build on the last. Each ends with the game playable, the smoke test passing and older saves still loading.

- **18 Skills and tools** (next): skills that grow with practice (woodcutting, mining, farming, fishing, herbs, cooking, healing, smithing, carpentry, music) and pass on as a trade from parent or master to child or apprentice. Work needs the right tool in hand, and tools are made, bought, wear out and are carried
- **19 Marriage and weddings**: engagements and rings, a wedding at the chapel with guests, a married household and a married name
- **20 Animals**: wild game to hunt, draught and pack animals and mounts that carry goods and people, pets and livestock
- **21 Builders and rooms**: building as a job, with materials hauled to the site; rooms, roofs and the indoor/outdoor difference
- **22 Traders and goods**: caravans on the roads, a wider list of goods made at workshops (flour and bread, planks, tools, cloth, iron) and sold
- **23 Ambitions**: a lifetime aspiration for each of your folk and small wishes that come and go
- **24 Other families**: play any family in the town, inheritance of land and goods, the town's families carrying on without you, moving between towns
- **25 Sound and music**: ambient sound, music, instruments to play

## Later

- Sprites drawn by hand to replace the code-drawn art, one piece at a time
