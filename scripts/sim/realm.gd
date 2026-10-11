class_name Realm
extends RefCounted
## The Crown, the land and the guilds: what the household owes and what it is allowed to do.
##
## * Land: every lot the player holds has a title (data/titles.json): freehold or leasehold.
##   WorldState.titles records which. A vacant lot can be leased or bought to run a business on,
##   but only by a guild member, and only one (realm.json: max_business_lots).
## * Quarter day (every `tax_every_days`): the tax collector takes land tax or rent for each lot
##   (scaled by social class and any decree), the guild dues, and a share of what the business took in.
##   What the purse cannot cover becomes arrears, and the collector takes furnishings to cover it.
##   Paying in full raises the household's reputation, defaulting lowers it.
## * Decrees: on quarter day the Crown may proclaim something (data/events.json, "decree": true)
##   that changes taxes and prices for the coming quarter.
## * Succession: when the head of the household dies the eldest adult takes over, and the Crown takes
##   a death duty from the purse.
##
## The state here is plain data and is saved with the game.

var start_id := ""
## The guild the household belongs to ("" for none).
var guild := ""
## The person who heads the household (a pawn id).
var head_id := 0
## Standing with the Crown and the town, -100 to 100.
var reputation := 0.0
## Trade income since the last quarter day, which the trade tax is taken from.
var takings := 0
## Tax left unpaid.
var arrears := 0
## What the last decree does to this quarter's land tax.
var levy_multiplier := 1.0
var last_tax_day := 0
## What the tax collector did last time, for the panel.
var last_report := ""
## Coin given to the town's defense fund (see Conflict).
var fund := 0
## The threat on its way: { "id", "due_day", "strength" }, or empty.
var threat: Dictionary = {}
## When each kind of conflict last came, by conflict id.
var last_conflict_days: Dictionary = {}


static func config() -> Dictionary:
	return DataRegistry.get_def("realm", "realm")


static func class_name_of(class_id: String) -> String:
	return str(DataRegistry.get_def("classes", class_id).get("name", class_id.capitalize()))


static func class_rank(class_id: String) -> int:
	return int(DataRegistry.get_def("classes", class_id).get("rank", 0))


## The household's standing: its highest-ranking member.
static func household_class(household: Household) -> String:
	var best := "peasant"
	var best_rank := -1
	for pawn in household.pawns:
		if class_rank(pawn.class_id) > best_rank:
			best_rank = class_rank(pawn.class_id)
			best = pawn.class_id
	return best


func guild_def() -> Dictionary:
	return DataRegistry.get_def("guilds", guild) if guild != "" else {}


## Whether the guild the household belongs to grants this right ("business_lot").
func has_right(right: String) -> bool:
	return right in guild_def().get("grants", [])


# --- land ---------------------------------------------------------------------------

## Lots held besides the home lot.
func business_lot_ids(world: WorldState) -> Array[String]:
	var found: Array[String] = []
	for lot_id in world.titles:
		if str(lot_id) != WorldState.HOME_LOT:
			found.append(str(lot_id))
	return found


## What it costs to take a lot: "lease" (the entry fee), "buy" (the freehold price of a vacant
## lot) or "buyout" (the freehold price of a lot already rented).
func lot_price(world: WorldState, lot_id: String, how: String) -> int:
	var area := world.lot_area(lot_id)
	match how:
		"lease":
			return roundi(area * float(DataRegistry.get_def("titles", "leasehold").get("entry_per_tile", 0.0)))
		"buy", "buyout":
			return roundi(area * float(DataRegistry.get_def("titles", "freehold").get("price_per_tile", 0.0)))
	return 0


## Why this cannot be done right now, or "" if it can.
func lot_blocker(sim: Simulation, lot_id: String, how: String) -> String:
	var world := sim.world
	var lot := world.get_lot(lot_id)
	if lot.is_empty():
		return "there is no such lot"
	var price := lot_price(world, lot_id, how)
	if how == "buyout":
		if str(world.titles.get(lot_id, "")) != "leasehold":
			return "it is not rented"
	else:
		if world.titles.has(lot_id) or str(lot.get("kind", "")) != "vacant":
			return "it is not for taking"
		if not has_right("business_lot"):
			return "only guild members may hold a business lot"
		if business_lot_ids(world).size() >= int(config().get("max_business_lots", 1)):
			return "you already hold a business lot"
	if price > sim.household.coins:
		return "it costs %s and you have %s" % [Economy.format(price), Economy.format(sim.household.coins)]
	return ""


## Takes (or buys out) the lot. Returns { "ok", "message" }.
func acquire_lot(sim: Simulation, lot_id: String, how: String) -> Dictionary:
	var blocker := lot_blocker(sim, lot_id, how)
	if blocker != "":
		return { "ok": false, "message": "Can't do that: %s" % blocker }
	var price := lot_price(sim.world, lot_id, how)
	sim.household.coins -= price
	var lot := sim.world.get_lot(lot_id)
	if how == "buyout":
		sim.world.titles[lot_id] = "freehold"
		return { "ok": true, "message": "%s is now yours outright (%s)" % [str(lot.get("name", "The lot")), Economy.format(price)] }
	sim.world.titles[lot_id] = "leasehold" if how == "lease" else "freehold"
	for entry in sim.world.lots:
		if entry["id"] == lot_id:
			entry["kind"] = "business"
			entry["name"] = "Your business"
			entry["public"] = true   # customers come and go
			entry["owner"] = "player"
	return { "ok": true, "message": "You %s the lot for %s. Build a tavern table, ale barrel or bread shelf to open for business." % ["lease" if how == "lease" else "have bought", Economy.format(price)] }


# --- guild ---------------------------------------------------------------------------

func join_blocker(sim: Simulation, guild_id: String) -> String:
	var def := DataRegistry.get_def("guilds", guild_id)
	if def.is_empty():
		return "there is no such guild"
	if guild == guild_id:
		return "already a member"
	if guild != "":
		return "already in another guild"
	var fee := int(def.get("join_fee", 0))
	if fee > sim.household.coins:
		return "it costs %s and you have %s" % [Economy.format(fee), Economy.format(sim.household.coins)]
	return ""


## The whole household joins and ranks as the guild says (a burgher, say).
func join_guild(sim: Simulation, guild_id: String) -> Dictionary:
	var blocker := join_blocker(sim, guild_id)
	if blocker != "":
		return { "ok": false, "message": "Can't join: %s" % blocker }
	var def := DataRegistry.get_def("guilds", guild_id)
	sim.household.coins -= int(def.get("join_fee", 0))
	guild = guild_id
	var makes := str(def.get("makes", ""))
	if makes != "":
		for pawn in sim.household.pawns:
			if class_rank(pawn.class_id) < class_rank(makes):
				pawn.class_id = makes
	return { "ok": true, "message": "The household joins the %s" % str(def.get("name", guild_id)) }


# --- defense ------------------------------------------------------------------------

## Puts coin into the town's defense fund (see Conflict).
func give_to_fund(sim: Simulation, amount: int) -> Dictionary:
	if amount <= 0 or amount > sim.household.coins:
		return { "ok": false, "message": "You do not have %s to give" % Economy.format(amount) }
	sim.household.coins -= amount
	fund += amount
	return { "ok": true, "message": "%s goes into the defense fund (now %s)" % [Economy.format(amount), Economy.format(fund)] }


# --- taxes ---------------------------------------------------------------------------

func tax_every() -> int:
	return maxi(1, int(config().get("tax_every_days", 15)))


func days_until_tax() -> int:
	return tax_every() - GameClock.get_day_number() % tax_every()


## What the next quarter day will ask for: [{ "label", "amount" }].
func quarter_lines(sim: Simulation) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var class_factor := float(DataRegistry.get_def("classes", household_class(sim.household)).get("tax_multiplier", 1.0))
	for lot_id in sim.world.titles:
		var title := DataRegistry.get_def("titles", str(sim.world.titles[lot_id]))
		var amount := roundi(sim.world.lot_area(str(lot_id)) * float(title.get("tax_per_tile", 0.0)) * class_factor * levy_multiplier)
		var lot_name := "home" if str(lot_id) == WorldState.HOME_LOT else "business lot"
		lines.append({ "label": "%s (%s)" % [str(title.get("charge", "Land tax")), lot_name], "amount": amount })
	if guild != "":
		lines.append({ "label": "Guild dues", "amount": int(guild_def().get("dues", 0)) })
	if takings > 0:
		var percent := int(guild_def().get("business_tax_percent", config().get("business_tax_percent", 20)))
		lines.append({ "label": "Trade tax on %s" % Economy.format(takings), "amount": roundi(takings * percent / 100.0) })
	return lines


func total_due(sim: Simulation) -> int:
	var total := arrears
	for line in quarter_lines(sim):
		total += int(line["amount"])
	return total


## Called at midnight. On a quarter day, collects what is owed and may proclaim a decree.
## Returns messages for the player.
func new_day(sim: Simulation) -> Array[String]:
	var day := GameClock.get_day_number()
	var messages: Array[String] = []
	messages.append_array(Conflict.new_day(sim, day))
	if day <= 0 or day % tax_every() != 0 or day == last_tax_day:
		return messages
	last_tax_day = day
	messages.append_array(collect(sim))
	var decree := _proclaim(sim, day)
	if decree != "":
		messages.append(decree)
	return messages


func collect(sim: Simulation) -> Array[String]:
	var messages: Array[String] = []
	var owed := total_due(sim)
	if owed <= 0 and arrears <= 0:
		last_report = "Quarter day: nothing owed."
		messages.append(last_report)
		takings = 0
		levy_multiplier = 1.0
		return messages
	var paid := mini(owed, sim.household.coins)
	sim.household.coins -= paid
	var remaining := owed - paid
	var seized_names: Array[String] = []
	if remaining > 0:
		remaining -= _distrain(sim, remaining, seized_names)
	arrears = maxi(0, remaining)
	var rep_min := float(config().get("reputation_min", -100))
	var rep_max := float(config().get("reputation_max", 100))
	if paid >= owed:
		reputation = clampf(reputation + float(config().get("reputation_on_time", 4)), rep_min, rep_max)
		last_report = "Quarter day: you paid %s in tax." % Economy.format(owed)
	else:
		reputation = clampf(reputation + float(config().get("reputation_default", -12)), rep_min, rep_max)
		last_report = "Quarter day: you paid %s of the %s owed." % [Economy.format(paid), Economy.format(owed)]
		if not seized_names.is_empty():
			last_report += " The collector took your %s." % ", ".join(seized_names)
		if arrears > 0:
			last_report += " %s is still owing." % Economy.format(arrears)
	messages.append(last_report)
	takings = 0
	levy_multiplier = 1.0
	return messages


## Takes furnishings (dearest first, but never the beds, cooking pot or hearth: realm.json "distraint_exempt") from the land the household holds until `amount` is covered.
## Returns the value taken; the names go in `names`. Any surplus is paid back in coin.
func _distrain(sim: Simulation, amount: int, names: Array[String]) -> int:
	var goods: Array[PlacedObject] = []
	for placed in sim.world.objects:
		if str(placed.def().get("category", "furniture")) == "structure" or not bool(placed.def().get("buildable", true)):
			continue
		if Economy.object_cost(placed.def_id) <= 0 or placed.def_id in config().get("distraint_exempt", []):
			continue
		for rect in sim.world.held_rects():
			if rect.has_point(placed.tile):
				goods.append(placed)
				break
	goods.sort_custom(func(a: PlacedObject, b: PlacedObject) -> bool:
		return Economy.object_cost(a.def_id) > Economy.object_cost(b.def_id))
	var taken := 0
	for placed in goods:
		if taken >= amount:
			break
		taken += Economy.object_cost(placed.def_id)
		names.append(placed.display_name().to_lower())
		sim.seize(placed)
	if taken > amount:
		sim.household.coins += taken - amount  # the collector gives change
		return amount
	return taken


## May proclaim a decree for the coming quarter. Returns its announcement, or "".
func _proclaim(sim: Simulation, day: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.world.world_seed, day, 77])
	var roll := rng.randf()
	var decrees: Array[Dictionary] = []
	for def in DataRegistry.get_list("events"):
		if bool(def.get("decree", false)):
			decrees.append(def)
	if decrees.is_empty() or roll >= float(config().get("decree_chance", 0.6)):
		return ""
	var chosen := decrees[rng.randi() % decrees.size()]
	sim.events.start(str(chosen["id"]))
	levy_multiplier = float(chosen.get("tax_multiplier", 1.0))
	return ""  # the event announces itself


# --- succession ----------------------------------------------------------------------

## Who heads the household now: the eldest adult. Fills in head_id if it is missing.
func choose_head(household: Household) -> void:
	var best: Pawn = null
	for pawn in household.pawns:
		if pawn.adult and (best == null or pawn.age > best.age):
			best = pawn
	if best == null and not household.pawns.is_empty():
		best = household.pawns[0]
	head_id = best.id if best != null else 0


## A member of the household died. If it was the head, the eldest adult takes over and the Crown
## takes its death duty. Returns messages.
func on_death(sim: Simulation, dead_pawn: Pawn) -> Array[String]:
	var messages: Array[String] = []
	if dead_pawn.id != head_id:
		return messages
	var duty := sim.household.coins * int(config().get("death_duty_percent", 0)) / 100
	if duty > 0:
		sim.household.coins -= duty
		messages.append("The Crown takes a death duty of %s." % Economy.format(duty))
	choose_head(sim.household)
	var heir := sim.household.get_pawn(head_id)
	if heir != null:
		messages.append("%s now heads the household." % heir.display_name)
	return messages


# --- text ----------------------------------------------------------------------------

## A line for the panel: standing, title and the next quarter day.
func summary(sim: Simulation) -> String:
	var held := "Landless"
	if sim.world.titles.has(WorldState.HOME_LOT):
		held = str(DataRegistry.get_def("titles", str(sim.world.titles[WorldState.HOME_LOT])).get("name", "Freehold"))
	var text := "%s, %s\nTax day in %d days (about %s)" % [Realm.class_name_of(Realm.household_class(sim.household)), held, days_until_tax(), Economy.format(total_due(sim))]
	if guild != "":
		text += "\n" + str(guild_def().get("name", guild))
	if arrears > 0:
		text += "\nOwing %s" % Economy.format(arrears)
	if not threat.is_empty():
		var days_left := maxi(0, int(threat["due_day"]) - GameClock.get_day_number())
		text += "\n%s in %d days: strength %d, defense %d" % [str(DataRegistry.get_def("conflicts", str(threat["id"])).get("name", "Trouble")), days_left, int(threat["strength"]), roundi(float(Conflict.defense(sim)["total"]))]
	return text


# --- saving --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"start": start_id, "guild": guild, "head": head_id, "reputation": snappedf(reputation, 0.01),
		"fund": fund, "threat": threat.duplicate(), "conflicts": last_conflict_days.duplicate(),
		"takings": takings, "arrears": arrears, "levy": levy_multiplier, "last_tax_day": last_tax_day, "report": last_report,
	}


static func from_dict(data: Dictionary) -> Realm:
	var realm := Realm.new()
	realm.start_id = str(data.get("start", ""))
	realm.guild = str(data.get("guild", "")) if DataRegistry.has_def("guilds", str(data.get("guild", ""))) else ""
	realm.head_id = int(data.get("head", 0))
	realm.reputation = float(data.get("reputation", 0.0))
	realm.takings = int(data.get("takings", 0))
	realm.arrears = int(data.get("arrears", 0))
	realm.levy_multiplier = float(data.get("levy", 1.0))
	realm.last_tax_day = int(data.get("last_tax_day", 0))
	realm.last_report = str(data.get("report", ""))
	realm.fund = int(data.get("fund", 0))
	var saved_threat: Variant = data.get("threat", {})
	if saved_threat is Dictionary and DataRegistry.has_def("conflicts", str(saved_threat.get("id", ""))):
		realm.threat = { "id": str(saved_threat["id"]), "due_day": int(saved_threat.get("due_day", 0)), "strength": int(saved_threat.get("strength", 0)) }
	var saved_days: Variant = data.get("conflicts", {})
	if saved_days is Dictionary:
		for conflict_id in saved_days:
			realm.last_conflict_days[str(conflict_id)] = int(saved_days[conflict_id])
	return realm
