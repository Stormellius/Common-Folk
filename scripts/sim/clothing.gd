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
	merged["warmth"] = float(merged.get("warmth", 1.0)) * warmth_of(worn(sim, pawn))
	return merged
