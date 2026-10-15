class_name Families
extends RefCounted
## The town's families: playing as one of them, moving house, and how they carry on without you.
##
## A FAMILY is whoever lives on one house lot (Pawn.home_lot). The player's own household lives on the
## home lot ("home"), and every other house is the town's.
##
## * PLAY a family: the player's household and the chosen family trade places. The household becomes
##   the town's (whoever has no work is left to find some), their goods are sold and the money shared out,
##   and the chosen family becomes the household, living in their house, which is now the home lot.
##   The two lots swap their ids, so everything that points at a lot (who lives there, whose animals)
##   follows. The old land titles go, and the new family holds their house as rent or freehold by class.
##   The Crown starts over with them (standing, guild, arrears) but the quarter days carry on as they were.
## * MOVE house: the household takes an empty house, in this town or another, leaving the old one for whoever
##   comes next, and keeps its goods, titles and standing.
## * CARRY ON: when someone of the town dies their coin goes to their heirs; children left with no grown-up
##   are taken in by kin or neighbours; empty houses are taken by families arriving from elsewhere, or by
##   families from another town with no work who hear there is some. All of it is written in the chronicle.


static func config() -> Dictionary:
	return DataRegistry.get_def("families", "families")


static func _number(key: String, fallback: float) -> float:
	return float(config().get(key, fallback))


# --- who lives where --------------------------------------------------------------------------

## Everyone (the household, the town, babies too) who lives on the lot.
static func residents_of(sim: Simulation, lot_id: String) -> Array[Pawn]:
	var found: Array[Pawn] = []
	for pawn in sim.people():
		if pawn.home_lot == lot_id:
			found.append(pawn)
	return found


## The one who heads a family: the eldest grown-up, or failing that the eldest.
static func head_of(members: Array[Pawn]) -> Pawn:
	var best: Pawn = null
	for pawn in members:
		if best == null or (pawn.adult and not best.adult) or (pawn.adult == best.adult and pawn.age > best.age):
			best = pawn
	return best


## "Cooper": the family's name, from whoever heads it.
static func family_name(members: Array[Pawn]) -> String:
	var head := head_of(members)
	return head.surname() if head != null else ""


## The town's families, one for each house with people of the town living in it:
## { "lot": id, "members": Array[Pawn], "head": Pawn, "name", "town": id, "town_name", "class": id }.
static func list(sim: Simulation) -> Array[Dictionary]:
	var by_lot := {}
	for pawn in sim.town.pawns:
		if pawn.home_lot == WorldState.HOME_LOT or pawn.home_lot == "":
			continue
		if not by_lot.has(pawn.home_lot):
			by_lot[pawn.home_lot] = [] as Array[Pawn]
		(by_lot[pawn.home_lot] as Array[Pawn]).append(pawn)
	var found: Array[Dictionary] = []
	for lot_id in by_lot:
		var entry := sim.world.get_lot(str(lot_id))
		if entry.is_empty() or str(entry.get("kind", "")) != "house":
			continue
		var members: Array[Pawn] = by_lot[lot_id]
		var town := sim.world.get_town(str(entry.get("town", "")))
		var best_class := "peasant"
		for pawn in members:
			if Realm.class_rank(pawn.class_id) > Realm.class_rank(best_class):
				best_class = pawn.class_id
		found.append({ "lot": str(lot_id), "members": members, "head": head_of(members), "name": family_name(members),
			"town": str(entry.get("town", "")), "town_name": str(town.get("name", "")), "class": best_class })
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["town"] != b["town"]:
			return a["town_name"] < b["town_name"]
		return a["name"] < b["name"])
	return found


## The houses nobody lives in: the town's lots of kind "house" with no one at home (and a bed to sleep in).
static func vacant_houses(sim: Simulation) -> Array[Dictionary]:
	var lived_in := {}
	for pawn in sim.people():
		lived_in[pawn.home_lot] = true
	var beds := {}
	for placed in sim.world.objects:
		if placed.def_id == "bed":
			var here := sim.world.lot_at(placed.tile)
			if not here.is_empty():
				beds[str(here["id"])] = int(beds.get(str(here["id"]), 0)) + 1
	var found: Array[Dictionary] = []
	for entry in sim.world.lots:
		var lot_id := str(entry["id"])
		if str(entry.get("kind", "")) == "house" and not lived_in.has(lot_id) and int(beds.get(lot_id, 0)) > 0:
			found.append(entry)
	return found


## What the screen lists: { "lot", "title", "who", "town", "class", "here" (in the home town), "blocker" }.
static func rows(sim: Simulation) -> Array[Dictionary]:
	var home_id := str(sim.world.home_town().get("id", ""))
	var shown: Array[Dictionary] = []
	for family in list(sim):
		var who: Array[String] = []
		for pawn in (family["members"] as Array[Pawn]).slice(0, 6):
			who.append("%s %d" % [pawn.given_name(), pawn.age])
		shown.append({ "lot": family["lot"], "title": "The %s family" % family["name"], "who": ", ".join(who) + (" ..." if (family["members"] as Array).size() > 6 else ""),
			"town": family["town_name"], "class": Realm.class_name_of(str(family["class"])), "here": family["town"] == home_id, "blocker": play_blocker(sim, str(family["lot"])) })
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["here"] != b["here"]:
			return bool(a["here"])
		return str(a["town"]) < str(b["town"]))
	return shown


## The empty houses a household could move into: { "lot", "title", "town", "beds", "here", "blocker" }.
static func empty_rows(sim: Simulation) -> Array[Dictionary]:
	var home_id := str(sim.world.home_town().get("id", ""))
	var shown: Array[Dictionary] = []
	for entry in vacant_houses(sim):
		var town := sim.world.get_town(str(entry.get("town", "")))
		var beds := 0
		for placed in sim.world.objects:
			if placed.def_id == "bed" and (entry["rect"] as Rect2i).has_point(placed.tile):
				beds += 1
		shown.append({ "lot": str(entry["id"]), "title": str(entry.get("name", "An empty house")), "town": str(town.get("name", "")), "beds": beds,
			"here": str(entry.get("town", "")) == home_id, "blocker": move_blocker(sim, str(entry["id"])) })
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["here"] != b["here"]:
			return bool(a["here"])
		return str(a["town"]) < str(b["town"]))
	return shown


# --- the chronicle ----------------------------------------------------------------------------

## Writes something down for the player to read later.
static func record(sim: Simulation, text: String) -> void:
	sim.world.chronicle.append({ "day": GameClock.get_day_number(), "text": text })
	var limit := int(_number("chronicle_limit", 40.0))
	while sim.world.chronicle.size() > limit:
		sim.world.chronicle.pop_front()


## The chronicle, newest first, as lines like "Day 12: the Coopers moved...".
static func chronicle_lines(sim: Simulation) -> Array[String]:
	var lines: Array[String] = []
	for index in range(sim.world.chronicle.size() - 1, -1, -1):
		var entry: Dictionary = sim.world.chronicle[index]
		lines.append("Day %d: %s" % [int(entry["day"]) + 1, str(entry["text"])])
	return lines


# --- playing another family -------------------------------------------------------------------

## Why the player cannot take up this family now, or "".
static func play_blocker(sim: Simulation, lot_id: String) -> String:
	if lot_id == WorldState.HOME_LOT:
		return "that is your own family"
	var entry := sim.world.get_lot(lot_id)
	if entry.is_empty() or str(entry.get("kind", "")) != "house":
		return "there is no such family"
	var chosen: Array[Pawn] = []
	for pawn in sim.town.pawns:
		if pawn.home_lot == lot_id:
			chosen.append(pawn)
	var playable := 0
	for pawn in chosen:
		playable += 0 if pawn.is_infant() else 1
	if playable == 0:
		return "nobody there can be played"
	for pawn in sim.household.pawns:
		if pawn.is_dying():
			return "%s is dying" % pawn.given_name()
		if Pregnancy.in_labour(pawn):
			return "%s is in labour" % pawn.given_name()
	for pawn in chosen:
		if pawn.is_dying():
			return "%s is dying" % pawn.given_name()
	return ""


## The household and the family on `lot_id` trade places. Returns { "ok", "message" }.
static func play(sim: Simulation, lot_id: String) -> Dictionary:
	var blocker := play_blocker(sim, lot_id)
	if blocker != "":
		return { "ok": false, "message": "Can't take up that family: %s" % blocker }
	var world := sim.world
	var entry := world.get_lot(lot_id)
	var incoming: Array[Pawn] = []
	for pawn in sim.people():
		if pawn.home_lot == lot_id:
			incoming.append(pawn)
	var outgoing: Array[Pawn] = []
	for pawn in sim.household.pawns:
		if pawn not in incoming:
			outgoing.append(pawn)
	var old_name := family_name(outgoing) if not outgoing.is_empty() else ""
	var new_name := family_name(incoming)
	var new_town := world.get_town(str(entry.get("town", "")))

	# The old household winds up its affairs.
	for pawn in sim.household.pawns:
		_stop(sim, pawn)
	for pawn in incoming:
		_stop(sim, pawn)
	_cancel_plans(sim)
	var purse := _wind_up(sim)
	var adults: Array[Pawn] = []
	for pawn in outgoing:
		if pawn.adult:
			adults.append(pawn)
	var sharers: Array[Pawn] = adults if not adults.is_empty() else outgoing
	if not sharers.is_empty():
		var share := purse / sharers.size()
		for pawn in sharers:
			pawn.coins += share
		sharers[0].coins += purse - share * sharers.size()

	# People change sides.
	var keep_selected := -1
	for pawn in outgoing:
		sim.household.remove_pawn(pawn.id)
		sim.town.adopt(pawn)
	for pawn in incoming:
		if sim.household.get_pawn(pawn.id) == null:
			sim.town.remove_pawn(pawn.id)
			sim.household.adopt(pawn)
		sim.household.coins += pawn.coins  # what they had in their pockets is the household's purse now
		pawn.coins = 0
	var head := head_of(incoming)
	if head != null and not head.is_infant():
		keep_selected = head.id
	else:
		for pawn in incoming:
			if not pawn.is_infant():
				keep_selected = pawn.id
				break
	sim.household.selected_id = keep_selected
	sim.household.dead.clear()
	sim.household.stock.clear()
	sim.household.tool_wear.clear()

	_swap_lots(sim, entry, old_name)
	_swap_animals(sim, lot_id)
	world.titles.clear()
	var best_class := Realm.household_class(sim.household)
	world.titles[WorldState.HOME_LOT] = "freehold" if Realm.class_rank(best_class) >= Realm.class_rank("burgher") else "leasehold"
	world.home_lost = false
	_new_realm(sim)
	var text := "The household of the %s family has moved on, and you now follow the %s family of %s." % [old_name, new_name, str(new_town.get("name", "the town"))] if old_name != "" else "You now follow the %s family of %s." % [new_name, str(new_town.get("name", "the town"))]
	record(sim, text)
	sim.household_changed.emit()
	sim.family_changed.emit(new_name)
	return { "ok": true, "message": text }


## Everyone stops what they are doing, and gives back what they carry.
static func _stop(sim: Simulation, pawn: Pawn) -> void:
	if pawn.mount != 0:
		Fauna.dismount(sim, pawn)
	sim.order_stop(pawn)
	if pawn.tool != "" and sim.household.get_pawn(pawn.id) != null:
		Skills.unequip(sim, pawn)
	pawn.tool = ""
	pawn.tool_lent = false
	pawn.carrying.clear()
	pawn.contract_until = 0
	pawn.job_recipe = ""


## What the household has planned and not yet had built is called off (the coin half comes back).
static func _cancel_plans(sim: Simulation) -> void:
	for site in sim.world.sites.duplicate():
		Construction.cancel(sim, site)


## The household's goods are sold for what they would fetch; its purse and that money come back as one sum.
static func _wind_up(sim: Simulation) -> int:
	var total := sim.household.coins
	for item_id in sim.household.stock:
		var amount := int(sim.household.stock[item_id])
		if Economy.resource_ids().has(str(item_id)):
			total += Economy.sell_price(str(item_id), amount)
		elif Skills.is_tool_id(str(item_id)):
			total += roundi(float(Skills.tool_price(str(item_id)) * amount) * _number("tool_sale_percent", 50.0) / 100.0)
	sim.household.coins = 0
	return total


## The home lot and `entry` trade ids and ground. Whatever stands on either stays where it is; whoever
## lived on one now lives on the other, in everything that points at a lot.
static func _swap_lots(sim: Simulation, entry: Dictionary, old_name: String) -> void:
	var lot_id := str(entry["id"])
	_trade_ground(sim.world, entry, old_name)
	for pawn in sim.people():
		pawn.home_lot = _swapped(pawn.home_lot, lot_id)
		pawn.origin_lot = _swapped(pawn.origin_lot, lot_id)


## The home lot takes the ground of `entry`, and `entry` (a house of the town) the old home's. The
## town that holds the home lot is the home town now.
static func _trade_ground(world: WorldState, entry: Dictionary, old_name: String) -> void:
	var old_town := world.home_town()
	var new_town := world.get_town(str(entry.get("town", "")))
	var old_rect := world.lot
	world.lot = entry["rect"]
	entry["rect"] = old_rect
	entry["town"] = str(old_town.get("id", ""))
	entry["name"] = "The %s house" % old_name if old_name != "" else "An empty house"
	entry["template"] = ""
	entry["kind"] = "house"
	entry["public"] = false
	entry["settled"] = GameClock.get_day_number()  # whoever lives in the old home has just settled there
	if not new_town.is_empty():
		for town in world.towns:
			town["home"] = str(town["id"]) == str(new_town["id"])


static func _swapped(id: String, lot_id: String) -> String:
	if id == WorldState.HOME_LOT:
		return lot_id
	if id == lot_id:
		return WorldState.HOME_LOT
	return id


## The animals of the old household are the town's now, and the new family's are the household's.
static func _swap_animals(sim: Simulation, lot_id: String) -> void:
	for animal in sim.world.animals:
		if animal.owner == "household":
			animal.owner = "town"
			animal.home_lot = lot_id
			animal.leader = 0
			animal.rider = 0
		elif animal.owner == "town" and animal.home_lot == lot_id:
			animal.owner = "household"
			animal.home_lot = WorldState.HOME_LOT


## A new family means a new standing with the Crown, but the quarter days, the decree and the
## threat to the town carry on as they were.
static func _new_realm(sim: Simulation) -> void:
	var old := sim.realm
	var fresh := Realm.new()
	fresh.start_id = "family"
	fresh.levy_multiplier = old.levy_multiplier
	fresh.last_tax_day = old.last_tax_day
	fresh.threat = old.threat.duplicate()
	fresh.last_conflict_days = old.last_conflict_days.duplicate()
	fresh.choose_head(sim.household)
	sim.realm = fresh


# --- moving house -----------------------------------------------------------------------------

## Why the household cannot move into this house, or "".
static func move_blocker(sim: Simulation, lot_id: String) -> String:
	if sim.household.pawns.is_empty():
		return "there is nobody to move"
	var entry := sim.world.get_lot(lot_id)
	if entry.is_empty() or str(entry.get("kind", "")) != "house" or lot_id == WorldState.HOME_LOT:
		return "that is not a house"
	for pawn in sim.people():
		if pawn.home_lot == lot_id:
			return "somebody lives there"
	var beds := 0
	for placed in sim.world.objects:
		if placed.def_id == "bed" and (entry["rect"] as Rect2i).has_point(placed.tile):
			beds += 1
	if beds == 0:
		return "it has no beds"
	for pawn in sim.household.pawns:
		if pawn.is_dying():
			return "%s is dying" % pawn.given_name()
		if Pregnancy.in_labour(pawn):
			return "%s is in labour" % pawn.given_name()
	return ""


## The household moves, people and animals and all, to an empty house, leaving the old home for whoever
## comes next. The furniture of each stays where it is; goods, titles and standing come along.
static func move(sim: Simulation, lot_id: String) -> Dictionary:
	var blocker := move_blocker(sim, lot_id)
	if blocker != "":
		return { "ok": false, "message": "Can't move there: %s" % blocker }
	var world := sim.world
	var entry := world.get_lot(lot_id)
	var old_name := family_name(sim.household.pawns)
	var old_town := world.home_town()
	var new_town := world.get_town(str(entry.get("town", "")))
	for pawn in sim.household.pawns:
		_stop(sim, pawn)
	_cancel_plans(sim)
	# Whoever lives at home goes with the household; anyone staying on another lot stays there.
	_trade_ground(world, entry, old_name)
	var rect := world.lot
	var spots := _open_spots(sim, rect)
	var index := 0
	for pawn in sim.household.pawns:
		if pawn.home_lot == WorldState.HOME_LOT and not spots.is_empty():
			pawn.tile = spots[index % spots.size()]
			pawn.step_to = pawn.tile
			pawn.path.clear()
			index += 1
	for animal in Fauna.kept_by(sim):
		if not spots.is_empty():
			animal.tile = spots[index % spots.size()]
			animal.step_to = animal.tile
			animal.path.clear()
			animal.leader = 0
			index += 1
	var text := "The %s family has moved from %s to %s." % [old_name, str(old_town.get("name", "the old house")), str(new_town.get("name", "the new house"))]
	record(sim, text)
	sim.household_changed.emit()
	sim.family_changed.emit(old_name)
	return { "ok": true, "message": text }


## Open tiles inside a lot, indoors first.
static func _open_spots(sim: Simulation, rect: Rect2i) -> Array[Vector2i]:
	var indoors: Array[Vector2i] = []
	var outdoors: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var tile := Vector2i(x, y)
			if sim.world.is_walkable(x, y) and sim.world.object_at(tile) == null:
				(indoors if sim.world.floor_at(tile) != "" else outdoors).append(tile)
	indoors.append_array(outdoors)
	return indoors


# --- carrying on without you ------------------------------------------------------------------

## The town's people die and their coin goes to their heirs: the husband or wife, else the grown
## children, else the parents, else the grown-ups of the house. Written in the chronicle if it was someone of the
## player's own town.
static func settle_estate(sim: Simulation, dead: Pawn) -> void:
	var heirs := heirs_of(sim, dead)
	var from_here := str(sim.world.town_of_lot(dead.home_lot).get("id", "")) == str(sim.world.home_town().get("id", ""))
	var coins := dead.coins
	dead.coins = 0
	if heirs.is_empty():
		if from_here:
			record(sim, "%s died, and left nobody." % dead.display_name)
		return
	if coins > 0:
		var share := coins / heirs.size()
		for heir in heirs:
			heir.coins += share
		heirs[0].coins += coins - share * heirs.size()
	if from_here:
		var names: Array[String] = []
		for heir in heirs.slice(0, 3):
			names.append(heir.given_name())
		record(sim, "%s died. %s %s%s." % [dead.display_name, " and ".join(names), "inherit" if heirs.size() > 1 else "inherits", " %s" % Economy.format(coins) if coins > 0 else ""])


static func heirs_of(sim: Simulation, dead: Pawn) -> Array[Pawn]:
	var spouse := sim.person(dead.partner_id) if dead.partner_id != 0 else null
	if spouse != null and spouse.id != dead.id and not spouse.is_dying() and spouse.bond == "married":
		return [spouse] as Array[Pawn]
	var children: Array[Pawn] = []
	var parents: Array[Pawn] = []
	var housemates: Array[Pawn] = []
	for other in sim.people():
		if other.id == dead.id or other.is_dying() or sim.household.get_pawn(other.id) != null:
			continue
		if dead.id in other.parents and other.adult:
			children.append(other)
		elif other.id in dead.parents:
			parents.append(other)
		elif other.home_lot == dead.home_lot and other.adult:
			housemates.append(other)
	if not children.is_empty():
		return children
	if not parents.is_empty():
		return parents
	return housemates


## Midnight: orphans are taken in, empty houses are taken by new families. Returns notices (only
## about the player's own town).
static func new_day(sim: Simulation) -> Array[String]:
	var rng := RandomNumberGenerator.new()  # its own, so the town's comings and goings leave the rest of the game's chances alone
	rng.seed = sim.world.world_seed * 911 + GameClock.get_day_number()
	var notices: Array[String] = []
	_take_in_orphans(sim, notices)
	_fill_empty_houses(sim, rng, notices)
	return notices


## Children with no grown-up at home go to kin, or to a family nearby that has a bed.
static func _take_in_orphans(sim: Simulation, notices: Array[String]) -> void:
	var by_lot := {}
	for pawn in sim.town.pawns:
		if pawn.home_lot == "" or pawn.home_lot == WorldState.HOME_LOT:
			continue
		if not by_lot.has(pawn.home_lot):
			by_lot[pawn.home_lot] = [] as Array[Pawn]
		(by_lot[pawn.home_lot] as Array[Pawn]).append(pawn)
	var home_id := str(sim.world.home_town().get("id", ""))
	for lot_id in by_lot:
		var members: Array[Pawn] = by_lot[lot_id]
		var children: Array[Pawn] = []
		var grown := false
		for pawn in members:
			if pawn.adult:
				grown = true
			elif not pawn.is_infant():
				children.append(pawn)
		if grown or children.is_empty():
			continue
		var host := _host_for(sim, str(lot_id), children)
		if host.is_empty():
			continue
		var names: Array[String] = []
		for child in children:
			if Romance.spare_beds(sim, str(host["id"])) < 1:
				break
			child.home_lot = str(host["id"])
			child.origin_lot = ""
			sim.order_stop(child)
			var spot := Romance._free_spot_in(sim, str(host["id"]))
			if spot != Vector2i(-1, -1):
				child.tile = spot
				child.step_to = spot
			names.append(child.given_name())
		if names.is_empty():
			continue
		var hosts := residents_of(sim, str(host["id"]))
		var carers := family_name(hosts)
		var text := "%s %s, left without a grown-up, %s taken in by the %s family." % [" and ".join(names), children[0].surname(), "was" if names.size() == 1 else "were", carers]
		record(sim, text)
		if str(sim.world.get_lot(str(lot_id)).get("town", "")) == home_id:
			notices.append(text)


## The house that would take orphans from `lot_id`: kin first, then the same town, nearest.
static func _host_for(sim: Simulation, lot_id: String, children: Array[Pawn]) -> Dictionary:
	var from := sim.world.get_lot(lot_id)
	var best := {}
	var best_score := INF
	var surname := children[0].surname()
	for entry in sim.world.lots:
		var id := str(entry["id"])
		if id == lot_id or str(entry.get("kind", "")) != "house" or Romance.spare_beds(sim, id) < 1:
			continue
		var carers := residents_of(sim, id).filter(func(pawn: Pawn) -> bool: return pawn.adult and not pawn.is_dying())
		if carers.is_empty():
			continue
		var kin := false
		for carer: Pawn in carers:
			for child in children:
				kin = kin or Relations.are_kin(carer, child) or carer.surname() == surname
		var score := (Vector2((entry["rect"] as Rect2i).get_center()) - Vector2((from["rect"] as Rect2i).get_center())).length()
		if str(entry.get("town", "")) != str(from.get("town", "")):
			score += 1000.0
		if not kin:
			score += 500.0
		if score < best_score:
			best_score = score
			best = entry
	return best


## A house nobody lives in may be taken by a family from another town with no work, who hear there is some,
## or by one arriving from elsewhere.
static func _fill_empty_houses(sim: Simulation, rng: RandomNumberGenerator, notices: Array[String]) -> void:
	var home_id := str(sim.world.home_town().get("id", ""))
	var filled_towns := {}
	for entry in vacant_houses(sim):
		var town_id := str(entry.get("town", ""))
		if filled_towns.has(town_id):
			continue  # one a day for a town
		var roll := rng.randf()
		var text := ""
		if roll < _number("move_chance", 0.25) and not sim.open_positions("", town_id).is_empty():
			text = _move_family_in(sim, entry, rng)
		if text == "" and roll < _number("arrive_chance", 0.06):
			text = _arrive(sim, entry, rng)
		if text != "":
			filled_towns[town_id] = true
			record(sim, text)
			if town_id == home_id or text.contains(str(sim.world.get_town(home_id).get("name", "~"))):
				notices.append(text)


## Newcomers settle in: a couple (or one) and children, with a name not yet in the region.
static func _arrive(sim: Simulation, entry: Dictionary, rng: RandomNumberGenerator) -> String:
	var beds := 0
	for placed in sim.world.objects:
		if placed.def_id == "bed" and (entry["rect"] as Rect2i).has_point(placed.tile):
			beds += 1
	var ages: Array[int] = []
	var adult_ages: Array = config().get("adult_ages", [19, 52])
	var adults := 2 if rng.randf() < _number("couple_chance", 0.7) and beds >= 2 else 1
	for i in adults:
		ages.append(rng.randi_range(int(adult_ages[0]), int(adult_ages[1])))
	var kids_range: Array = config().get("kids", [0, 3])
	var kid_ages: Array = config().get("kid_ages", [2, 15])
	for i in mini(rng.randi_range(int(kids_range[0]), int(kids_range[1])), beds - adults):
		ages.append(rng.randi_range(int(kid_ages[0]), int(kid_ages[1])))
	var used := {}
	for pawn in sim.people():
		used[pawn.surname()] = true
	var names: Array = DataRegistry.get_def("names", "family").get("list", ["Smith"])
	var free: Array[String] = []
	for name in names:
		if not used.has(str(name)):
			free.append(str(name))
	var family := free[rng.randi() % free.size()] if not free.is_empty() else str(names[rng.randi() % names.size()])
	var made := NpcGenerator.settle(sim.world, sim.town, rng, entry, family, ages)
	if made.is_empty():
		return ""
	entry["settled"] = GameClock.get_day_number()
	var town := sim.world.get_town(str(entry.get("town", "")))
	return "The %s family has come to %s and taken the empty house." % [family, str(town.get("name", "town"))]


## A family from another town with no work moves to this house, in a town that is hiring.
static func _move_family_in(sim: Simulation, entry: Dictionary, rng: RandomNumberGenerator) -> String:
	var town_id := str(entry.get("town", ""))
	var beds := 0
	for placed in sim.world.objects:
		if placed.def_id == "bed" and (entry["rect"] as Rect2i).has_point(placed.tile):
			beds += 1
	var movers: Array[Dictionary] = []
	for family in list(sim):
		if str(family["town"]) == town_id or (family["members"] as Array).size() > beds:
			continue
		var home := sim.world.get_lot(str(family["lot"]))
		if GameClock.get_day_number() - int(home.get("settled", -1000)) >= int(_number("settle_days", 15.0)) and _may_move(sim, family["members"]):
			movers.append(family)
	if movers.is_empty():
		return ""
	var chosen: Dictionary = movers[rng.randi() % movers.size()]
	var from_town := sim.world.get_town(str(chosen["town"]))
	var to_town := sim.world.get_town(town_id)
	var members: Array[Pawn] = chosen["members"]
	var spots := _open_spots(sim, entry["rect"])
	var index := 0
	for pawn in members:
		sim.order_stop(pawn)
		if pawn.work_lot != "":
			sim.quit_job(pawn)  # the job stays in the old town
		pawn.home_lot = str(entry["id"])
		pawn.origin_lot = ""
		if not spots.is_empty():
			pawn.tile = spots[index % spots.size()]
			pawn.step_to = pawn.tile
			pawn.path.clear()
			index += 1
	for animal in sim.world.animals:
		if animal.owner == "town" and animal.home_lot == str(chosen["lot"]) and not spots.is_empty():
			animal.home_lot = str(entry["id"])
			animal.tile = spots[index % spots.size()]
			animal.step_to = animal.tile
			animal.path.clear()
			index += 1
	entry["settled"] = GameClock.get_day_number()
	return "The %s family has left %s for %s, where there is work." % [str(chosen["name"]), str(from_town.get("name", "the town")), str(to_town.get("name", "the town"))]


## A family that may be moved: nobody in work, nobody tied to your folk, nobody dying, with child or on the way.
static func _may_move(sim: Simulation, members: Array[Pawn]) -> bool:
	for pawn in members:
		if pawn.work_job != "" or pawn.is_dying() or pawn.is_infant() or pawn.is_pregnant() or Pregnancy.in_labour(pawn):
			return false
		if pawn.partner_id != 0 and sim.household.get_pawn(pawn.partner_id) != null:
			return false
		if pawn.job_kind != "":
			return false
	return not members.is_empty()
