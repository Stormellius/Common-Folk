class_name Clothing
extends RefCounted
## What people wear (data/clothing.json), and why (data/wardrobe.json). Everyone has clothes for every
## occasion, so nothing is owned or saved: what a person wears now is worked out from what they are doing
## and how cold it is.
##
## * in bed: nightclothes; at the wash basin: underclothes (and, when there is swimming, swimwear)
## * a wedding, or at a pew or the altar: good clothes
## * the cold decides the rest. How cold it is to someone is the warmth the season (and a cold snap)
##   takes from people, made less indoors under a roof and worse at night. At the winter figure they wear a
##   winter coat, at the warm figure warm clothes
## * at work (a shift, building, hunting, or at a chopping block or the like), if they are old enough: work clothes
## * otherwise everyday clothes
##
## Each outfit has a "warmth": what it does to how fast warmth drains, so a coat in winter helps. See
## PawnArt for how each looks (and SpriteBank for painted versions).

static var _tick := -1
static var _owner := 0
static var _base_chill := 1.0
static var _night := false


static func rules() -> Dictionary:
	return DataRegistry.get_def("wardrobe", "wardrobe")


static func outfit_ids() -> Array[String]:
	var found: Array[String] = []
	for def in DataRegistry.get_list("clothing"):
		found.append(str(def["id"]))
	return found


static func name_of(outfit_id: String) -> String:
	return str(DataRegistry.get_def("clothing", outfit_id).get("name", outfit_id))


## The outfits a person can be told to wear (data/wardrobe.json "choices").
static func choices() -> Array[String]:
	var found: Array[String] = []
	for outfit_id in rules().get("choices", []):
		found.append(str(outfit_id))
	return found


## --- garments: the pieces an outfit is made of (data/garments.json), one for each slot -------------------

const SLOTS: Array[String] = ["top", "bottom", "feet"]


static func garment(garment_id: String) -> Dictionary:
	return DataRegistry.get_def("garments", garment_id)


## Every garment that can be worn in a slot.
static func garments_in(slot: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for def in DataRegistry.get_list("garments"):
		if str(def.get("slot", "")) == slot:
			found.append(def)
	return found


## The pieces an outfit is made of: { slot: garment id } (nothing at all for underclothes and swimwear: the body).
static func recipe(outfit_id: String) -> Dictionary:
	var made: Dictionary = {}
	var def := DataRegistry.get_def("clothing", outfit_id)
	var parts: Dictionary = def.get("garments", {})
	for slot in SLOTS:
		if parts.has(slot):
			made[slot] = str(parts[slot])
	return made


## An outfit's pieces with the ones somebody has chosen for themselves put in place of its own.
static func pieces_with(outfit_id: String, chosen: Dictionary) -> Dictionary:
	var made := recipe(outfit_id)
	if outfit_id in ["undergarments", "swim"]:
		return made  # at the basin they wear what is under it all
	for slot in SLOTS:
		var wanted := str(chosen.get(slot, ""))
		if wanted != "" and str(garment(wanted).get("slot", "")) == slot:
			made[slot] = wanted
	return made


## Whether what they wear is settled by what they are doing (in bed, at the basin, at a wedding or a service), whatever they chose.
static func is_fixed(sim: Simulation, pawn: Pawn) -> bool:
	var outfit := worn(sim, pawn)
	return outfit in ["sleepwear", "undergarments", "swim"] or (outfit == "formal" and (pawn.wed_until > GameClock.tick or pawn.job_kind in ["wed", "guest", "use"]))


## What this person has on now: { slot: garment id }.
static func pieces(sim: Simulation, pawn: Pawn) -> Dictionary:
	var outfit := worn(sim, pawn)
	return recipe(outfit) if pawn.garments.is_empty() or is_fixed(sim, pawn) else pieces_with(outfit, pawn.garments)


## The garments of a slot that this person's pictures have (the painted people come in sets that do not all have every garment).
static func available(pawn: Pawn, slot: String) -> Array[Dictionary]:
	var stage := Life.stage_id(pawn)
	if stage == "":
		stage = "adult" if pawn.adult else "child"
	var entry := SpriteBank.person_set(stage, pawn.gender)
	var found: Array[Dictionary] = []
	for def in garments_in(slot):
		if entry.is_empty() or str(def["id"]) in entry.get("garments", []):
			found.append(def)
	return found


## What a set of pieces does to the drain of warmth: each garment keeps some of it in.
static func warmth_of_pieces(made: Dictionary) -> float:
	var kept := 0.0
	for slot in made:
		kept += float(garment(str(made[slot])).get("warm", 0.0))
	return clampf(1.0 - kept, 0.5, 1.15)


## What an outfit does to the drain of warmth (1 for no help, under 1 for a better coat).
static func warmth_of(outfit_id: String) -> float:
	return float(DataRegistry.get_def("clothing", outfit_id).get("warmth", 1.0))


## Looks at the weather and the hour once for everyone (called as each minute is worked out).
static func refresh(sim: Simulation) -> void:
	if _tick == GameClock.tick and _owner == sim.get_instance_id():
		return
	_tick = GameClock.tick
	_owner = sim.get_instance_id()
	_base_chill = float(sim._season_multipliers().get("warmth", 1.0))
	var hour := float(GameClock.get_minute_of_day()) / 60.0
	_night = hour >= float(rules().get("night_from_hour", 21)) or hour < float(rules().get("night_to_hour", 6))


## How cold it is to this person now: the warmth the season takes (see data/seasons.json), less under a roof,
## more at night. About 1 in spring, 0.3 in summer and 2.5 in winter.
static func chill(sim: Simulation, pawn: Pawn) -> float:
	refresh(sim)
	var value := _base_chill
	if sim.world.roofs.has(pawn.tile):
		value *= float(Shelter.config().get("roofed_drain_multipliers", {}).get("warmth", 1.0))
	if _night:
		value *= float(rules().get("night_chill", 1.0))
	return value


## The outfit this person is wearing now (an id of data/clothing.json).
static func worn(sim: Simulation, pawn: Pawn) -> String:
	if pawn.is_infant() or pawn.pose == "lie":
		return "sleepwear"
	if pawn.wed_until > GameClock.tick or pawn.job_kind == "wed" or pawn.job_kind == "guest":
		return "formal"
	var placed: PlacedObject = null
	if pawn.job_kind == "use" and pawn.job_stage == "using":
		placed = sim.world.get_object(pawn.job_object)
	if placed != null:
		if placed.def_id in rules().get("wash_objects", []):
			return "undergarments"
		if placed.def_id in rules().get("formal_objects", []):
			return "formal"
	if pawn.outfit_choice != "" and DataRegistry.has_def("clothing", pawn.outfit_choice):  # as the player chose, at a wardrobe
		return pawn.outfit_choice
	var cold := chill(sim, pawn)
	if cold >= float(rules().get("winter_from", 2.0)):
		return "winter"
	if cold >= float(rules().get("warm_from", 1.15)):
		return "warm"
	var at_work: bool = pawn.job_kind in rules().get("work_jobs", []) or (placed != null and (placed.def().has("drains") or placed.def().has("gathers")))
	if at_work and pawn.age >= Life.stage_start(str(rules().get("work_min_stage", "youth")), 13):
		return "worker"
	return "casual"


## `multipliers` with what the person's clothes do to the drain of warmth multiplied in.
static func drain_multipliers(sim: Simulation, pawn: Pawn, multipliers: Dictionary) -> Dictionary:
	var merged := multipliers.duplicate()
	var covered := warmth_of(worn(sim, pawn)) if pawn.garments.is_empty() else warmth_of_pieces(pieces(sim, pawn))
	merged["warmth"] = float(merged.get("warmth", 1.0)) * covered * (1.0 - outer_warmth(sim, pawn))
	return merged


## What the household's tailored outer wear (data/wardrobe.json "outer_wear": a cloak, boots) keeps in
## when it is cold enough for warm clothes: one of each piece in the stockpile goes to each person, in
## the household's order, so three cloaks cover the first three. Nothing for the town's own folk.
static func outer_warmth(sim: Simulation, pawn: Pawn) -> float:
	var wear: Dictionary = rules().get("outer_wear", {})
	if wear.is_empty() or chill(sim, pawn) < float(rules().get("warm_from", 1.15)):
		return 0.0
	var place := sim.household.pawns.find(pawn)
	if place < 0:
		return 0.0
	var kept := 0.0
	for item_id in wear:
		if sim.household.stock_of(str(item_id)) > place:
			kept += float(wear[item_id])
	return kept
