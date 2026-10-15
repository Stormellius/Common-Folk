class_name PawnActions
extends RefCounted
## What the selected person can be told to do at a spot on the map. The right-click menu
## shows whatever list_for() returns, and perform() carries out the one that was chosen.
##
## That is walking, stopping and, on an object, whatever the object offers ("Sleep",
## "Eat a meal"; its "action" in data/objects.json). Switching who you control is not here:
## left-click a person (or their portrait, or Tab). An entry that cannot be used right now is
## still listed, switched off, with the reason. Right-clicking another person lists the
## two-person interactions from data/interactions.json (one needs both to be willing). Something
## that costs coin shows its price. A notice board or a counter ("offers_work" in objects.json)
## lists the jobs with a vacancy, and a way to quit the one you have. A baby of your household
## lists what it needs (feeding, soothing, washing), and a woman in labour lets you stay with her.

const WALK := "walk"
const STOP := "stop"
const USE_PREFIX := "use:"
const INTERACT_PREFIX := "interact:"  # "interact:<interaction id>:<other person's id>"
const HIRE_PREFIX := "hire:"          # "hire:<lot id>:<job id>"
const QUIT_JOB := "quit_job"
const LOT_PREFIX := "lot:"           # "lot:<lease|buy|buyout>:<lot id>"
const GUILD_PREFIX := "guild:"       # "guild:<guild id>"
const FUND_PREFIX := "fund:"         # "fund:<amount>"
const PLEAD_PREFIX := "plead:"       # "plead:<dying person's id>"
const TEND_PREFIX := "tend:"         # "tend:<care id>:<baby's id>"
const ATTEND_PREFIX := "attend:"     # "attend:<mother's id>"
const DATE_PREFIX := "date:"         # "date:<partner's id>"
const MOVE_PREFIX := "move:"         # "move:invite:<id>" (they move in with you) or "move:join:<id>" (you move in with them)
const BREAKUP_PREFIX := "breakup:"   # "breakup:<partner's id>"
const MOVE_HOME := "move_home"
const SELL_PREFIX := "sell:"         # "sell:<resource id>"
const FIRE_ACTION := "fight_fire"
const TREAT_PREFIX := "treat:"       # "treat:<patient's id>"
const CRAFT_PREFIX := "craft:"       # "craft:<recipe id>:<object id>"
const WEAR_PREFIX := "wear:"         # "wear:<outfit id or auto>:<object id>"
const BUY_PREFIX := "buy:"           # "buy:<tool or good id>"
const HUNT_PREFIX := "hunt:"         # "hunt:<animal id>"
const PET_PREFIX := "pet:"           # "pet:<animal id>"
const RIDE_PREFIX := "ride:"         # "ride:<animal id>"
const LEAD_PREFIX := "lead:"         # "lead:<animal id>"
const WAIT_PREFIX := "wait:"         # "wait:<animal id>": stop leading it
const ADOPT_PREFIX := "adopt:"       # "adopt:<animal id>"
const BUYANIMAL_PREFIX := "buyanimal:"  # "buyanimal:<kind>:<hitching post id>"
const BUILD_PREFIX := "build:"       # "build:<site id>" or "build:all": work on what is planned
const UNPLAN_PREFIX := "unplan:"     # "unplan:<site id>": call a plan off
const ROOF_PREFIX := "roof:"         # "roof:<roof id>": roof the room that was clicked in
const HIRE_CREW := "hire_crew"
const CBUY_PREFIX := "cbuy:"         # "cbuy:<caravan id>:<good>"
const CSELL_PREFIX := "csell:"       # "csell:<caravan id>:<good>"
const CRIDE_PREFIX := "cride:"       # "cride:<caravan id>"
const CGET_OFF := "cget_off"
const DISMOUNT := "dismount"
const WED_PREFIX := "wed:"           # "wed:<fiancé(e)'s id>"
const FUND_STEPS := [10, 50]


## One entry: { "id": String, "label": String, "enabled": bool, "reason": String }.
static func _entry(id: String, label: String, enabled: bool = true, reason: String = "") -> Dictionary:
	return { "id": id, "label": label, "enabled": enabled, "reason": reason }


## The menu for `pawn` when the player right-clicks `tile`. Empty outside the map.
static func list_for(sim: Simulation, pawn: Pawn, tile: Vector2i) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not sim.world.in_bounds(tile.x, tile.y):
		return actions
	if pawn.is_dying():
		actions.append(_entry("none", "%s is dying" % pawn.display_name.get_slice(" ", 0), false, "nothing to be done but plead with Death"))
		return actions
	if Pregnancy.in_labour(pawn):
		actions.append(_entry("none", "%s is in labour" % pawn.display_name.get_slice(" ", 0), false, "the baby is coming"))
		return actions
	if pawn.caravan != 0:  # a rider can only wait or get down
		var cart_blocker := Caravans.get_off_blocker(sim, pawn)
		actions.append(_entry(CGET_OFF, "Get off the cart", cart_blocker == "", cart_blocker))
		return actions
	var placed := sim.world.object_at(tile)
	if placed != null and placed.def().has("action"):  # walls and doors offer nothing to use
		var blocker := sim.use_blocker(pawn, placed)
		var spirit := Mortality.spirit_at(sim.world, placed.tile)
		var label := str(placed.def().get("action", "Use")).replace("{name}", str(spirit.get("name", "the dead")))
		var price := sim.price_of(placed.def_id)
		if price > 0:
			label += " (%s)" % Economy.format(price)
		if placed.def().has("gathers"):
			label += " (+%s)" % Economy.stock_text(placed.def()["gathers"])
		actions.append(_entry(USE_PREFIX + str(placed.id), label, blocker == "", blocker))
	if placed != null and placed.def().has("offers_work"):
		actions.append_array(_work_entries(sim, pawn, placed))
	if placed != null and placed.def_id == "counter" and str(sim.world.lot_at(placed.tile).get("kind", "")) == "shop":
		actions.append_array(_sell_entries(sim, pawn))
	if placed != null and bool(placed.def().get("recipes", false)):
		actions.append_array(_recipe_entries(sim, pawn, placed))
	if placed != null and bool(placed.def().get("wardrobe", false)) and sim.household.get_pawn(pawn.id) != null:
		actions.append_array(_wardrobe_entries(sim, pawn, placed))
	if placed != null and bool(placed.def().get("sells_tools", false)):
		actions.append_array(_tool_entries(sim, pawn))
	if placed != null and str(placed.def().get("offers_work", "")) == "town":
		actions.append_array(_guild_entries(sim))
		for amount in FUND_STEPS:
			var short: bool = amount > sim.household.coins
			actions.append(_entry(FUND_PREFIX + str(amount), "Give %s to the town's defense fund (now %s)" % [Economy.format(amount), Economy.format(sim.realm.fund)], not short, "you only have %s" % Economy.format(sim.household.coins) if short else ""))
	if placed != null and placed.def_id == "counter" and str(sim.world.lot_at(placed.tile).get("kind", "")) == "workshop":
		var crew_blocker := Construction.hire_blocker(sim, pawn)
		actions.append(_entry(HIRE_CREW, "Hire a builder for the day (%s an hour)" % Economy.format(int(DataRegistry.get_def("jobs", "carpenter").get("wage", 5))), crew_blocker == "", crew_blocker))
	actions.append_array(_building_entries(sim, pawn, tile))
	if placed != null and bool(placed.def().get("sells_animals", false)):
		actions.append_array(_animal_market_entries(sim, pawn, placed))
	for animal in sim.world.animals_at(tile):
		actions.append_array(_animal_entries(sim, pawn, animal))
	for cart in sim.world.caravans:
		if cart.tile == tile or (cart.is_moving() and cart.step_to == tile):
			actions.append_array(_caravan_entries(sim, pawn, cart))
	if pawn.mount != 0:
		var steed := sim.world.get_animal(pawn.mount)
		actions.append(_entry(DISMOUNT, "Get down from %s" % steed.title() if steed != null else "Get down"))
	if sim.world.fires.has(tile):
		var fire_blocker := sim.extinguish_blocker(pawn, tile)
		actions.append(_entry(FIRE_ACTION, "Beat out the flames", fire_blocker == "", fire_blocker))
	actions.append_array(_land_entries(sim, tile))
	actions.append(_walk_entry(sim, pawn, tile))
	if sim.household.get_pawn(pawn.id) != null and pawn.home_lot != WorldState.HOME_LOT:
		var home_blocker := Romance.move_home_blocker(sim, pawn)
		actions.append(_entry(MOVE_HOME, "Move back to your own lot", home_blocker == "", home_blocker))
	if pawn.is_busy():
		actions.append(_entry(STOP, "Stop"))
	for other in sim.people():
		if other.id == pawn.id or other.tile != tile:
			continue
		if other.is_infant():
			actions.append_array(_baby_entries(sim, pawn, other))
			continue
		if Pregnancy.in_labour(other):
			var attend_blocker := sim.attend_blocker(pawn, other)
			actions.append(_entry(ATTEND_PREFIX + str(other.id), "Stay with %s for the birth" % other.display_name.get_slice(" ", 0), attend_blocker == "", attend_blocker))
			continue
		if other.is_dying():
			var plead_blocker := Mortality.plead_blocker(sim, pawn, other)
			actions.append(_entry(PLEAD_PREFIX + str(other.id), "Plead with Death for %s" % other.display_name.get_slice(" ", 0), plead_blocker == "", plead_blocker))
			continue
		if other.illness != "" and sim.household.get_pawn(pawn.id) != null:
			var treat_blocker := sim.treat_blocker(pawn, other)
			actions.append(_entry(TREAT_PREFIX + str(other.id), "Nurse %s with herbs" % other.display_name.get_slice(" ", 0), treat_blocker == "", treat_blocker))
		actions.append_array(_romance_entries(sim, pawn, other))
		for interaction in DataRegistry.get_list("interactions"):
			var blocker := sim.interaction_blocker(pawn, other, str(interaction["id"]))
			var label := str(interaction.get("action", "Interact with {name}")).replace("{name}", other.display_name.get_slice(" ", 0))
			actions.append(_entry(INTERACT_PREFIX + "%s:%d" % [interaction["id"], other.id], label, blocker == "", blocker))
	return actions


## What a couple can do beyond talking: go on a date, move in together, part.
static func _romance_entries(sim: Simulation, pawn: Pawn, other: Pawn) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not Romance.together(pawn, other):
		return entries
	var name := other.display_name.get_slice(" ", 0)
	var date_blocker := Romance.date_blocker(sim, pawn, other)
	entries.append(_entry(DATE_PREFIX + str(other.id), "Go on a date with %s" % name, date_blocker == "", date_blocker))
	if sim.household.get_pawn(pawn.id) != null and sim.household.get_pawn(other.id) == null:
		var invite_blocker := Romance.invite_blocker(sim, pawn, other)
		entries.append(_entry(MOVE_PREFIX + "invite:%d" % other.id, "Ask %s to move in" % name, invite_blocker == "", invite_blocker))
		var join_blocker := Romance.join_blocker(sim, pawn, other)
		entries.append(_entry(MOVE_PREFIX + "join:%d" % other.id, "Move in with %s" % name, join_blocker == "", join_blocker))
	if Romance.is_engaged(pawn, other):
		var wedding_blocker := Romance.wedding_blocker(sim, pawn, other)
		entries.append(_entry(WED_PREFIX + str(other.id), "Marry %s at the chapel" % name, wedding_blocker == "", wedding_blocker))
	if not Romance.is_married(pawn, other):
		entries.append(_entry(BREAKUP_PREFIX + str(other.id), ("Break off the engagement with %s" if Romance.is_engaged(pawn, other) else "Break up with %s") % name))
	return entries


## Feeding, soothing and washing one of your household's babies, each with how it is now.
static func _baby_entries(sim: Simulation, pawn: Pawn, baby: Pawn) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sim.household.get_pawn(baby.id) == null:
		return entries
	var blocker := Babies.tend_blocker(sim, pawn, baby)
	for def in Babies.care_defs():
		var care_id := str(def["id"])
		var label := str(def.get("action", "See to {name}")).replace("{name}", baby.display_name.get_slice(" ", 0))
		label += " (%d%%)" % roundi(float(baby.care.get(care_id, Needs.FULL)) / Needs.FULL * 100.0)
		entries.append(_entry(TEND_PREFIX + "%s:%d" % [care_id, baby.id], label, blocker == "", blocker))
	return entries


## Selling what the household has gathered, at a shop counter: one entry for each resource held.
static func _sell_entries(sim: Simulation, pawn: Pawn) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for resource_id in Economy.resource_ids():
		var amount := sim.household.stock_of(resource_id)
		if amount > 0:
			var here := Economy.region_multiplier(sim.world, pawn.tile, resource_id)
			var note := "" if absf(here - 1.0) < 0.05 else " (prices here: %s)" % ("high" if here > 1.0 else "low")
			entries.append(_entry(SELL_PREFIX + resource_id, "Sell your %d %s (%s)%s" % [amount, Economy.resource_name(resource_id).to_lower(), Economy.format(sim.sale_price(resource_id, pawn)), note]))
	if entries.is_empty():
		entries.append(_entry("none", "Sell goods", false, "you have nothing gathered to sell"))
	for item_id in Economy.stocked_ids():
		var price := Economy.shop_price(item_id)
		var short := price > sim.coins_of(pawn)
		var reason := "only your own folk buy for the household" if sim.household.get_pawn(pawn.id) == null else ("can't afford it" if short else "")
		entries.append(_entry(BUY_PREFIX + item_id, "Buy %s (%s)" % [Economy.item_phrase(item_id), Economy.format(price)], reason == "", reason))
	return entries


## Planned building on the tile (work on it, call it off), the building work in general, and roofing
## the closed room the tile is in.
static func _building_entries(sim: Simulation, pawn: Pawn, tile: Vector2i) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not sim.world.can_build_at(tile):
		return entries
	var plans_here: Array[BuildSite] = []
	for site in sim.world.sites:
		if site.tile == tile:
			plans_here.append(site)
	var blocker := Construction.build_blocker(sim, pawn)
	for site in plans_here:
		entries.append(_entry(UNPLAN_PREFIX + str(site.id), "Call off the %s (materials come back)" % Construction.site_name(site)))
	if not sim.world.sites.is_empty():
		var label := "Work on the building (%d planned)" % sim.world.sites.size()
		entries.append(_entry(BUILD_PREFIX + "all", label, blocker == "", blocker))
	var plan := Construction.roof_plan(sim, tile)
	if str(plan["reason"]) == "" and not (plan["tiles"] as Array).is_empty():
		for roof_def in DataRegistry.get_list("roofs"):
			var roof_id := str(roof_def["id"])
			var price := Construction.roof_price(sim, roof_id, (plan["tiles"] as Array).size())
			var cost := Economy.stock_text(price["needs"])
			var label := "Roof this room: %s (%d tiles: %s)" % [str(roof_def.get("name", roof_id)).to_lower(), (plan["tiles"] as Array).size(), cost]
			var short := int(price["coins"]) > sim.household.coins
			entries.append(_entry(ROOF_PREFIX + roof_id, label, not short, "you need %s more coin" % Economy.format(int(price["coins"]) - sim.household.coins) if short else ""))
	return entries


## Buying from the caravan, selling to it, and riding with it.
static func _caravan_entries(sim: Simulation, pawn: Pawn, cart: Caravan) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var blocker := Caravans.trade_blocker(sim, pawn, cart)
	if cart.state != "camped":
		entries.append(_entry("none", "%s are on the road to %s" % [cart.name, str(sim.world.get_town(cart.to_town).get("name", "town"))], false, "they are not trading"))
		return entries
	for good in cart.stock:
		if int(cart.stock[good]) > 0:
			var price := Caravans.buy_price(sim, cart, str(good))
			entries.append(_entry(CBUY_PREFIX + "%d:%s" % [cart.id, good], "Buy %s (%s, %d left)" % [Economy.item_phrase(str(good)), Economy.format(price), int(cart.stock[good])], blocker == "" and price <= sim.coins_of(pawn), blocker if blocker != "" else "can't afford it"))
	var selling := 0
	for good in Economy.resource_ids():
		var amount := mini(sim.household.stock_of(good), int(cart.demand.get(good, 0)))
		if amount > 0:
			selling += 1
			var wanted := " (they are looking for it)" if good in cart.wants else ""
			entries.append(_entry(CSELL_PREFIX + "%d:%s" % [cart.id, good], "Sell them %d %s (%s)%s" % [amount, Economy.resource_name(good).to_lower(), Economy.format(Caravans.sell_price(sim, cart, pawn, good, amount)), wanted], blocker == "", blocker))
	if selling == 0:
		entries.append(_entry("none", "Sell them goods", false, "you have nothing they want"))
	var ride_blocker := Caravans.ride_blocker(sim, pawn, cart)
	entries.append(_entry(CRIDE_PREFIX + str(cart.id), "Ride with them to %s (%s)" % [str(sim.world.get_town(cart.next_town).get("name", "the next town")), Economy.format(int(Caravans.config().get("fare", 12)))], ride_blocker == "", ride_blocker))
	return entries


## What can be done about an animal on the tile: hunt it, pet it, ride it, lead it, take it in.
static func _animal_entries(sim: Simulation, pawn: Pawn, animal: Animal) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var def := animal.def()
	var title := animal.title()
	if animal.is_wild():
		var yields: Dictionary = def.get("yields", {})
		if not yields.is_empty():
			var blocker := Fauna.hunt_blocker(sim, pawn, animal)
			var danger := " (dangerous)" if def.has("fights_back") or def.has("hostile") else ""
			entries.append(_entry(HUNT_PREFIX + str(animal.id), "Hunt %s (+%s)%s" % [title, Economy.stock_text(yields), danger], blocker == "", blocker))
		return entries
	var pet_blocker := Fauna.pet_blocker(sim, pawn, animal)
	entries.append(_entry(PET_PREFIX + str(animal.id), "Make a fuss of %s" % title, pet_blocker == "", pet_blocker))
	if animal.owner == "":
		var adopt_blocker := Fauna.adopt_blocker(sim, pawn, animal)
		entries.append(_entry(ADOPT_PREFIX + str(animal.id), "Take in %s" % title, adopt_blocker == "", adopt_blocker))
	if animal.owner == "household":
		if float(def.get("ride", 0.0)) > 0.0:
			var ride_blocker := Fauna.ride_blocker(sim, pawn, animal)
			entries.append(_entry(RIDE_PREFIX + str(animal.id), "Ride %s" % title, ride_blocker == "", ride_blocker))
		var lead_blocker := Fauna.lead_blocker(sim, pawn, animal)
		if animal.leader == pawn.id:
			entries.append(_entry(WAIT_PREFIX + str(animal.id), "Tell %s to wait here" % title, lead_blocker == "", lead_blocker))
		else:
			entries.append(_entry(LEAD_PREFIX + str(animal.id), "Lead %s" % title if not animal.is_pet() else "Call %s to follow" % title, lead_blocker == "", lead_blocker))
	return entries


## Animals for sale at a hitching post, each with its price.
static func _animal_market_entries(sim: Simulation, pawn: Pawn, post: PlacedObject) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for kind in Fauna.kinds("domestic"):
		var price := int(Fauna.def_of(kind).get("price", 0))
		if price <= 0:
			continue
		var blocker := Fauna.buy_blocker(sim, pawn, kind)
		entries.append(_entry(BUYANIMAL_PREFIX + "%s:%d" % [kind, post.id], "Buy %s %s (%s)" % ["an" if str(Fauna.def_of(kind).get("name", kind)).substr(0, 1) in ["A", "E", "I", "O", "U"] else "a", str(Fauna.def_of(kind).get("name", kind)).to_lower(), Economy.format(price)], blocker == "", blocker))
	return entries


## What can be made at a forge or workbench: one entry for each recipe, with what it takes.
static func _recipe_entries(sim: Simulation, pawn: Pawn, placed: PlacedObject) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for recipe in Skills.recipes_for(placed.def_id):
		var blocker := sim.craft_blocker(pawn, placed, recipe)
		var label := "%s (%s)" % [str(recipe.get("name", recipe["id"])), Skills.inputs_text(recipe)]
		entries.append(_entry(CRAFT_PREFIX + "%s:%d" % [recipe["id"], placed.id], label, blocker == "", blocker))
	return entries


## Tools for sale on a shop's rack, each with its price.
static func _wardrobe_entries(sim: Simulation, pawn: Pawn, placed: PlacedObject) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var blocker := sim.use_blocker(pawn, placed)
	for outfit_id in Clothing.choices():
		var label := "Wear: %s" % Clothing.name_of(outfit_id).to_lower()
		if pawn.outfit_choice == outfit_id:
			label += " (now)"
		entries.append(_entry(WEAR_PREFIX + "%s:%d" % [outfit_id, placed.id], label, blocker == "", blocker))
	entries.append(_entry(WEAR_PREFIX + "auto:%d" % placed.id, "Wear: whatever suits the weather and work" + (" (now)" if pawn.outfit_choice == "" else ""), blocker == "", blocker))
	return entries


static func _tool_entries(sim: Simulation, pawn: Pawn) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var yours := sim.household.get_pawn(pawn.id) != null
	for tool_id in Skills.tool_ids():
		var price := Skills.tool_price(tool_id)
		var short := price > sim.coins_of(pawn)
		var reason := "only your own folk buy for the household" if not yours else ("can't afford it" if short else "")
		entries.append(_entry(BUY_PREFIX + tool_id, "Buy %s (%s)" % [Skills.tool_phrase(tool_id), Economy.format(price)], reason == "", reason))
	return entries


## Joining a guild, from the notice board.
static func _guild_entries(sim: Simulation) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for guild in DataRegistry.get_list("guilds"):
		if sim.realm.guild == str(guild["id"]):
			continue
		var blocker := sim.realm.join_blocker(sim, str(guild["id"]))
		entries.append(_entry(GUILD_PREFIX + str(guild["id"]), "Join the %s (%s)" % [guild.get("name", guild["id"]), Economy.format(int(guild.get("join_fee", 0)))], blocker == "", blocker))
	return entries


## Taking an empty lot on lease or for good, or buying out a lease, when the tile is on such land.
static func _land_entries(sim: Simulation, tile: Vector2i) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var lot := sim.world.lot_at(tile)
	if lot.is_empty():
		return entries
	var lot_id := str(lot["id"])
	if lot_id == WorldState.HOME_LOT:
		if sim.world.home_lost:
			var home_blocker := sim.realm.lot_blocker(sim, lot_id, "lease")
			entries.append(_entry(LOT_PREFIX + "lease:" + lot_id, "Lease your old plot again (%s)" % Economy.format(sim.realm.lot_price(sim.world, lot_id, "lease")), home_blocker == "", home_blocker))
		elif str(sim.world.titles.get(lot_id, "")) == "leasehold":
			var buy_blocker := sim.realm.lot_blocker(sim, lot_id, "buyout")
			entries.append(_entry(LOT_PREFIX + "buyout:" + lot_id, "Buy out the lease (%s)" % Economy.format(sim.realm.lot_price(sim.world, lot_id, "buyout")), buy_blocker == "", buy_blocker))
		return entries
	if str(lot.get("kind", "")) == "vacant" and not sim.world.titles.has(lot_id):
		var lease_title := DataRegistry.get_def("titles", "leasehold")
		var rent := roundi(sim.world.lot_area(lot_id) * float(lease_title.get("tax_per_tile", 0.0)))
		for how in ["lease", "buy"]:
			var blocker := sim.realm.lot_blocker(sim, lot_id, how)
			var price := Economy.format(sim.realm.lot_price(sim.world, lot_id, how))
			var label := "Lease this lot (%s, then about %s a quarter)" % [price, Economy.format(rent)] if how == "lease" else "Buy this lot (%s)" % price
			entries.append(_entry(LOT_PREFIX + "%s:%s" % [how, lot_id], label, blocker == "", blocker))
	elif str(sim.world.titles.get(lot_id, "")) == "leasehold":
		var blocker := sim.realm.lot_blocker(sim, lot_id, "buyout")
		entries.append(_entry(LOT_PREFIX + "buyout:" + lot_id, "Buy out the lease (%s)" % Economy.format(sim.realm.lot_price(sim.world, lot_id, "buyout")), blocker == "", blocker))
	return entries


## The job entries for a notice board (every vacancy in town) or a counter (that business's own).
static func _work_entries(sim: Simulation, pawn: Pawn, placed: PlacedObject) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var lot_id := "" if str(placed.def()["offers_work"]) == "town" else str(sim.world.lot_at(placed.tile).get("id", "none"))
	var board_town := "" if lot_id != "" else str(sim.world.town_at(placed.tile).get("id", ""))
	for opening in sim.open_positions(lot_id, board_town):
		var job: Dictionary = opening["job"]
		var lot: Dictionary = opening["lot"]
		var blocker := sim.hire_blocker(pawn, str(lot["id"]), str(job["id"]))
		var label := "Take the job: %s at the %s (%s an hour)" % [str(job["name"]).to_lower(), str(lot["name"]).to_lower(), Economy.format(int(job.get("wage", 0)))]
		entries.append(_entry(HIRE_PREFIX + "%s:%s" % [lot["id"], job["id"]], label, blocker == "", blocker))
	if pawn.work_job != "":
		entries.append(_entry(QUIT_JOB, "Quit your job as a %s" % str(DataRegistry.get_def("jobs", pawn.work_job).get("name", "worker")).to_lower()))
	if entries.is_empty():
		entries.append(_entry("none", "No work to be had here", false, "no vacancies"))
	return entries


## Carries out a chosen entry. Returns { "ok": bool, "message": String }. A person who was
## working and is given some other order stays off their shift for the rest of the day.
static func perform(sim: Simulation, pawn: Pawn, action_id: String, tile: Vector2i) -> Dictionary:
	var was_working := pawn.job_kind == "work"
	var result := _perform(sim, pawn, action_id, tile)
	if result["ok"] and was_working and not action_id.begins_with(HIRE_PREFIX) and action_id != QUIT_JOB:
		sim.note_player_order(pawn, true)
	return result


static func _perform(sim: Simulation, pawn: Pawn, action_id: String, tile: Vector2i) -> Dictionary:
	if action_id.begins_with(LOT_PREFIX):
		var lot_parts := action_id.trim_prefix(LOT_PREFIX).split(":")
		return sim.realm.acquire_lot(sim, lot_parts[1], lot_parts[0]) if lot_parts.size() == 2 else { "ok": false, "message": "Unknown lot" }
	if action_id.begins_with(FUND_PREFIX):
		return sim.realm.give_to_fund(sim, int(action_id.trim_prefix(FUND_PREFIX)))
	if action_id.begins_with(GUILD_PREFIX):
		return sim.realm.join_guild(sim, action_id.trim_prefix(GUILD_PREFIX))
	if action_id.begins_with(HIRE_PREFIX):
		var parts := action_id.trim_prefix(HIRE_PREFIX).split(":")
		return sim.hire(pawn, parts[0], parts[1]) if parts.size() == 2 else { "ok": false, "message": "Unknown job" }
	if action_id == QUIT_JOB:
		sim.quit_job(pawn)
		return { "ok": true, "message": "%s quit their job" % pawn.display_name.get_slice(" ", 0) }
	if action_id == WALK:
		return sim.order_move(pawn, tile)
	if action_id == STOP:
		sim.order_stop(pawn)
		return { "ok": true, "message": "" }
	if action_id.begins_with(USE_PREFIX):
		var placed := sim.world.get_object(int(action_id.trim_prefix(USE_PREFIX)))
		if placed == null:
			return { "ok": false, "message": "That is gone" }
		return sim.order_use(pawn, placed)
	if action_id.begins_with(PLEAD_PREFIX):
		var dying := sim.person(int(action_id.trim_prefix(PLEAD_PREFIX)))
		if dying == null:
			return { "ok": false, "message": "Death has already taken them" }
		return sim.order_plead(pawn, dying)
	if action_id == FIRE_ACTION:
		return sim.order_extinguish(pawn, tile)
	if action_id.begins_with(TREAT_PREFIX):
		var patient := sim.person(int(action_id.trim_prefix(TREAT_PREFIX)))
		if patient == null:
			return { "ok": false, "message": "They are not here" }
		var nursed := sim.treat(pawn, patient)
		if nursed["ok"]:
			sim.health_notice.emit(str(nursed["message"]))
		return nursed
	if action_id.begins_with(SELL_PREFIX):
		return sim.sell_stock(action_id.trim_prefix(SELL_PREFIX), pawn)
	if action_id.begins_with(BUY_PREFIX):
		return sim.buy_item(pawn, action_id.trim_prefix(BUY_PREFIX))
	if action_id.begins_with(WEAR_PREFIX):
		var wear_parts := action_id.trim_prefix(WEAR_PREFIX).split(":")
		var wardrobe := sim.world.get_object(int(wear_parts[1])) if wear_parts.size() == 2 else null
		if wardrobe == null:
			return { "ok": false, "message": "That is gone" }
		return sim.order_dress(pawn, wardrobe, wear_parts[0])
	if action_id.begins_with(CRAFT_PREFIX):
		var craft_parts := action_id.trim_prefix(CRAFT_PREFIX).split(":")
		var bench := sim.world.get_object(int(craft_parts[1])) if craft_parts.size() == 2 else null
		if bench == null:
			return { "ok": false, "message": "That is gone" }
		return sim.order_craft(pawn, bench, craft_parts[0])
	if action_id == MOVE_HOME:
		var home_blocker := Romance.move_home_blocker(sim, pawn)
		if home_blocker != "":
			return { "ok": false, "message": "Can't move back: %s" % home_blocker }
		sim.health_notice.emit(Romance.move_home(sim, pawn))
		return { "ok": true, "message": "" }
	if action_id == CGET_OFF:
		var off_blocker := Caravans.get_off_blocker(sim, pawn)
		if off_blocker != "":
			return { "ok": false, "message": "Can't get off: %s" % off_blocker }
		Caravans.get_off(sim, pawn)
		return { "ok": true, "message": "" }
	if action_id.begins_with(CBUY_PREFIX) or action_id.begins_with(CSELL_PREFIX):
		var trade_parts := action_id.get_slice(":", 1) + ":" + action_id.get_slice(":", 2)
		var cart := sim.world.get_caravan(int(trade_parts.get_slice(":", 0)))
		if cart == null:
			return { "ok": false, "message": "The caravan has gone" }
		var traded := Caravans.buy(sim, pawn, cart, trade_parts.get_slice(":", 1)) if action_id.begins_with(CBUY_PREFIX) else Caravans.sell(sim, pawn, cart, trade_parts.get_slice(":", 1))
		return traded
	if action_id.begins_with(CRIDE_PREFIX):
		var ride_cart := sim.world.get_caravan(int(action_id.trim_prefix(CRIDE_PREFIX)))
		if ride_cart == null:
			return { "ok": false, "message": "The caravan has gone" }
		var boarded := Caravans.board(sim, pawn, ride_cart)
		if boarded["ok"]:
			sim.health_notice.emit(str(boarded["message"]))
		return { "ok": boarded["ok"], "message": "" if boarded["ok"] else boarded["message"] }
	if action_id == HIRE_CREW:
		var hired := Construction.hire(sim, pawn)
		if hired["ok"]:
			sim.health_notice.emit(str(hired["message"]))
		return { "ok": hired["ok"], "message": "" if hired["ok"] else hired["message"] }
	if action_id == BUILD_PREFIX + "all":
		return Construction.order_build(sim, pawn)
	if action_id.begins_with(UNPLAN_PREFIX):
		var plan := sim.world.get_site(int(action_id.trim_prefix(UNPLAN_PREFIX)))
		if plan == null:
			return { "ok": false, "message": "That plan is gone" }
		Construction.cancel(sim, plan)
		return { "ok": true, "message": "" }
	if action_id.begins_with(ROOF_PREFIX):
		return Construction.plan_room_roof(sim, action_id.trim_prefix(ROOF_PREFIX), tile)
	if action_id == DISMOUNT:
		Fauna.dismount(sim, pawn)
		return { "ok": true, "message": "" }
	if action_id.begins_with(HUNT_PREFIX) or action_id.begins_with(PET_PREFIX) or action_id.begins_with(RIDE_PREFIX) \
			or action_id.begins_with(LEAD_PREFIX) or action_id.begins_with(WAIT_PREFIX) or action_id.begins_with(ADOPT_PREFIX):
		return _animal_action(sim, pawn, action_id)
	if action_id.begins_with(BUYANIMAL_PREFIX):
		var buy_parts := action_id.trim_prefix(BUYANIMAL_PREFIX).split(":")
		var post := sim.world.get_object(int(buy_parts[1])) if buy_parts.size() == 2 else null
		if post == null:
			return { "ok": false, "message": "That is gone" }
		return Fauna.buy(sim, pawn, post, buy_parts[0], sim.rng())
	if action_id.begins_with(WED_PREFIX):
		var betrothed := sim.person(int(action_id.trim_prefix(WED_PREFIX)))
		return Romance.order_wedding(sim, pawn, betrothed) if betrothed != null else { "ok": false, "message": "They are not here" }
	if action_id.begins_with(DATE_PREFIX):
		var date_partner := sim.person(int(action_id.trim_prefix(DATE_PREFIX)))
		return Romance.order_date(sim, pawn, date_partner) if date_partner != null else { "ok": false, "message": "They are not here" }
	if action_id.begins_with(MOVE_PREFIX):
		var move_parts := action_id.trim_prefix(MOVE_PREFIX).split(":")
		var lover := sim.person(int(move_parts[1])) if move_parts.size() == 2 else null
		if lover == null:
			return { "ok": false, "message": "They are not here" }
		var move_blocker := Romance.invite_blocker(sim, pawn, lover) if move_parts[0] == "invite" else Romance.join_blocker(sim, pawn, lover)
		if move_blocker != "":
			return { "ok": false, "message": "Can't move in: %s" % move_blocker }
		var told := Romance.invite(sim, pawn, lover) if move_parts[0] == "invite" else Romance.join(sim, pawn, lover)
		sim.health_notice.emit(told)
		return { "ok": true, "message": "" }
	if action_id.begins_with(BREAKUP_PREFIX):
		var ex := sim.person(int(action_id.trim_prefix(BREAKUP_PREFIX)))
		if ex == null or not Romance.together(pawn, ex):
			return { "ok": false, "message": "You are not together" }
		sim.health_notice.emit(Romance.break_up(sim, pawn, ex))
		return { "ok": true, "message": "" }
	if action_id.begins_with(TEND_PREFIX):
		var tend_parts := action_id.trim_prefix(TEND_PREFIX).split(":")
		var baby := sim.person(int(tend_parts[1])) if tend_parts.size() == 2 else null
		if baby == null:
			return { "ok": false, "message": "The baby is not here" }
		return sim.order_tend(pawn, baby, tend_parts[0])
	if action_id.begins_with(ATTEND_PREFIX):
		var mother := sim.person(int(action_id.trim_prefix(ATTEND_PREFIX)))
		if mother == null:
			return { "ok": false, "message": "She is not here" }
		return sim.order_attend(pawn, mother)
	if action_id.begins_with(INTERACT_PREFIX):
		var parts := action_id.trim_prefix(INTERACT_PREFIX).split(":")
		var other := sim.person(int(parts[1])) if parts.size() == 2 else null
		if other == null:
			return { "ok": false, "message": "That person is not here" }
		return sim.order_interact(pawn, other, parts[0])
	return { "ok": false, "message": "Unknown action" }


static func _animal_action(sim: Simulation, pawn: Pawn, action_id: String) -> Dictionary:
	var verb := action_id.get_slice(":", 0) + ":"
	var animal := sim.world.get_animal(int(action_id.get_slice(":", 1)))
	if animal == null:
		return { "ok": false, "message": "It has gone" }
	match verb:
		HUNT_PREFIX:
			return Fauna.order_hunt(sim, pawn, animal)
		PET_PREFIX:
			return Fauna.order_pet(sim, pawn, animal)
		RIDE_PREFIX:
			return Fauna.order_ride(sim, pawn, animal)
		LEAD_PREFIX:
			var lead_blocker := Fauna.lead_blocker(sim, pawn, animal)
			if lead_blocker != "":
				return { "ok": false, "message": "Can't lead it: %s" % lead_blocker }
			Fauna.lead(animal, pawn)
			return { "ok": true, "message": "%s follows %s." % [animal.display_name(), pawn.display_name.get_slice(" ", 0)] }
		WAIT_PREFIX:
			Fauna.release(animal)
			return { "ok": true, "message": "%s will wait here." % animal.display_name() }
		ADOPT_PREFIX:
			var adopt_blocker := Fauna.adopt_blocker(sim, pawn, animal)
			if adopt_blocker != "":
				return { "ok": false, "message": "Can't take it in: %s" % adopt_blocker }
			return { "ok": true, "message": Fauna.adopt(sim, pawn, animal, sim.rng()) }
	return { "ok": false, "message": "Unknown action" }


static func _walk_entry(sim: Simulation, pawn: Pawn, tile: Vector2i) -> Dictionary:
	var blocker := sim.world.object_at(tile)
	if blocker != null and blocker.blocks_walking():
		return _entry(WALK, "Walk here", false, "blocked by the %s" % blocker.display_name().to_lower())
	if not sim.world.is_walkable(tile.x, tile.y):
		var tile_id := sim.world.get_tile_id(tile.x, tile.y)
		var tile_name := str(DataRegistry.get_def("tiles", tile_id).get("name", tile_id))
		return _entry(WALK, "Walk here", false, "can't walk on %s" % tile_name.to_lower())
	var origin := pawn.committed_tile()
	if tile == origin:
		return _entry(WALK, "Walk here", false, "already there")
	if sim.pathfinder.find_path(origin, tile).is_empty():
		return _entry(WALK, "Walk here", false, "no way to get there")
	return _entry(WALK, "Walk here")
