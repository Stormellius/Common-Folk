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
const BUY_PREFIX := "buy:"           # "buy:<tool or good id>"
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
	if placed != null and bool(placed.def().get("sells_tools", false)):
		actions.append_array(_tool_entries(sim, pawn))
	if placed != null and str(placed.def().get("offers_work", "")) == "town":
		actions.append_array(_guild_entries(sim))
		for amount in FUND_STEPS:
			var short: bool = amount > sim.household.coins
			actions.append(_entry(FUND_PREFIX + str(amount), "Give %s to the town's defense fund (now %s)" % [Economy.format(amount), Economy.format(sim.realm.fund)], not short, "you only have %s" % Economy.format(sim.household.coins) if short else ""))
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
			entries.append(_entry(SELL_PREFIX + resource_id, "Sell your %d %s (%s)" % [amount, Economy.resource_name(resource_id).to_lower(), Economy.format(sim.sale_price(resource_id))]))
	if entries.is_empty():
		entries.append(_entry("none", "Sell goods", false, "you have nothing gathered to sell"))
	for item_id in Economy.stocked_ids():
		var price := Economy.shop_price(item_id)
		var short := price > sim.coins_of(pawn)
		var reason := "only your own folk buy for the household" if sim.household.get_pawn(pawn.id) == null else ("can't afford it" if short else "")
		entries.append(_entry(BUY_PREFIX + item_id, "Buy %s (%s)" % [Economy.item_phrase(item_id), Economy.format(price)], reason == "", reason))
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
		return sim.sell_stock(action_id.trim_prefix(SELL_PREFIX))
	if action_id.begins_with(BUY_PREFIX):
		return sim.buy_item(pawn, action_id.trim_prefix(BUY_PREFIX))
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
