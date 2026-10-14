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
## lists the jobs with a vacancy, and a way to quit the one you have.

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
	var placed := sim.world.object_at(tile)
	if placed != null and placed.def().has("action"):  # walls and doors offer nothing to use
		var blocker := sim.use_blocker(pawn, placed)
		var spirit := Mortality.spirit_at(sim.world, placed.tile)
		var label := str(placed.def().get("action", "Use")).replace("{name}", str(spirit.get("name", "the dead")))
		var price := sim.price_of(placed.def_id)
		if price > 0:
			label += " (%s)" % Economy.format(price)
		actions.append(_entry(USE_PREFIX + str(placed.id), label, blocker == "", blocker))
	if placed != null and placed.def().has("offers_work"):
		actions.append_array(_work_entries(sim, pawn, placed))
	if placed != null and str(placed.def().get("offers_work", "")) == "town":
		actions.append_array(_guild_entries(sim))
		for amount in FUND_STEPS:
			var short: bool = amount > sim.household.coins
			actions.append(_entry(FUND_PREFIX + str(amount), "Give %s to the town's defense fund (now %s)" % [Economy.format(amount), Economy.format(sim.realm.fund)], not short, "you only have %s" % Economy.format(sim.household.coins) if short else ""))
	actions.append_array(_land_entries(sim, tile))
	actions.append(_walk_entry(sim, pawn, tile))
	if pawn.is_busy():
		actions.append(_entry(STOP, "Stop"))
	for other in sim.people():
		if other.id == pawn.id or other.tile != tile or other.is_infant():
			continue
		if other.is_dying():
			var plead_blocker := Mortality.plead_blocker(sim, pawn, other)
			actions.append(_entry(PLEAD_PREFIX + str(other.id), "Plead with Death for %s" % other.display_name.get_slice(" ", 0), plead_blocker == "", plead_blocker))
			continue
		for interaction in DataRegistry.get_list("interactions"):
			var blocker := sim.interaction_blocker(pawn, other, str(interaction["id"]))
			var label := str(interaction.get("action", "Interact with {name}")).replace("{name}", other.display_name.get_slice(" ", 0))
			actions.append(_entry(INTERACT_PREFIX + "%s:%d" % [interaction["id"], other.id], label, blocker == "", blocker))
	return actions


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
	for opening in sim.open_positions(lot_id):
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
