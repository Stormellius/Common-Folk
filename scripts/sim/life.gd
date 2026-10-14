class_name Life
extends RefCounted
## Growing up and growing old (data/life_stages.json and data/lifespans.json).
##
## A person's age goes up on their birthday, once a "year of life". How many days that is
## depends on the game's lifespan (WorldState.lifespan): four on Normal, so that a whole life
## fits a game, or sixty "by the calendar", when nobody grows old in a normal game.
##
## The stages are baby, toddler, child, youth, adult and elder. An elder walks slower, tires
## sooner and keeps clear of heavy work, and dies of old age at an age between the stage's
## "dies_between" numbers. Which age is fixed for each person (from their name), so it needs no
## saving and nobody can tell it in advance.

const DEFAULT_DAYS_PER_YEAR := 60


static var _stage_of_age := {}  # age -> its stage, remembered until the data is loaded again
static var _stages_revision := -1


## Days to a year of life in this game.
static func days_per_year(world: WorldState) -> int:
	var lifespan := DataRegistry.get_def("lifespans", world.lifespan if world != null else "calendar")
	return maxi(1, int(lifespan.get("days_per_year", DEFAULT_DAYS_PER_YEAR)))


## The stage a person of this age is at: an entry of data/life_stages.json (empty if none).
static func stage_at(age: int) -> Dictionary:
	if _stages_revision != DataRegistry.revision:
		_stage_of_age.clear()
		_stages_revision = DataRegistry.revision
	var cached: Variant = _stage_of_age.get(age)
	if cached == null:
		var found := {}
		for stage in DataRegistry.get_list("life_stages"):
			if age >= int(stage.get("from_age", 0)):
				found = stage
		_stage_of_age[age] = found
		cached = found
	return cached


static func stage_of(pawn: Pawn) -> Dictionary:
	return stage_at(pawn.age)


static func stage_id(pawn: Pawn) -> String:
	return str(stage_of(pawn).get("id", ""))


## The age a stage starts at, or `fallback` if there is no such stage.
static func stage_start(stage: String, fallback: int) -> int:
	return int(DataRegistry.get_def("life_stages", stage).get("from_age", fallback))


static func is_elder(pawn: Pawn) -> bool:
	return stage_id(pawn) == "elder"


## "Adult, 34" for the panel.
static func describe_age(pawn: Pawn) -> String:
	return "%s, %d" % [str(stage_of(pawn).get("name", "")), pawn.age]


## The day of the year of life a person has their birthday (0 to days_per_year - 1). Someone born
## in the game remembers the day; anyone else's is worked out from their id.
static func birthday_of(pawn: Pawn, world: WorldState) -> int:
	return posmod(pawn.birthday if pawn.birthday >= 0 else pawn.id, days_per_year(world))


## The age at which this person dies of old age: somewhere in the elder stage's "dies_between",
## the same every time for the same person.
static func death_age(pawn: Pawn) -> int:
	var span: Array = DataRegistry.get_def("life_stages", "elder").get("dies_between", [])
	if span.size() < 2:
		return 9999
	var fate := ObjectArt.hash01(hash(pawn.display_name), pawn.id, 131)
	return roundi(lerpf(float(span[0]), float(span[1]), fate))


## How much slower the person walks at their stage (1 for most).
static func walk_multiplier(pawn: Pawn) -> float:
	return float(stage_of(pawn).get("walk_multiplier", 1.0))


## `multipliers` with the stage's own need drain multiplied in (an elder tires sooner).
static func drain_multipliers(pawn: Pawn, multipliers: Dictionary) -> Dictionary:
	var extra: Dictionary = stage_of(pawn).get("need_drain_multipliers", {})
	if extra.is_empty():
		return multipliers
	var merged := multipliers.duplicate()
	for need_id in extra:
		merged[need_id] = float(merged.get(need_id, 1.0)) * float(extra[need_id])
	return merged


## Whether a person at this stage may take a job marked "heavy" in data/jobs.json.
static func may_do_heavy_work(pawn: Pawn) -> bool:
	return bool(stage_of(pawn).get("heavy_work", true))


## Midnight: birthdays. Children come of age, adults grow old, and elders whose time has come
## lie down for the last time (Death comes for them). Returns messages for the player about
## your own folk; anything that changes who you can control is reported by
## `sim.household_changed`.
static func new_day(sim: Simulation, rng: RandomNumberGenerator) -> Array[String]:
	var messages: Array[String] = []
	var day := GameClock.get_day_number()
	if day <= 0:
		return messages
	var per_year := days_per_year(sim.world)
	var changed := false
	for pawn in sim.people():
		if pawn.is_dying():
			continue
		var yours := sim.household.get_pawn(pawn.id) != null
		if day % per_year == birthday_of(pawn, sim.world):
			var before := stage_id(pawn)
			pawn.age += 1
			var after := stage_id(pawn)
			if not pawn.adult and pawn.age >= stage_start("adult", 18):
				pawn.adult = true
				PersonFactory.give_orientation(pawn, rng)
				Mood.add_event(pawn, "came_of_age", GameClock.tick)
				if yours:
					messages.append("%s has come of age." % pawn.display_name)
			elif yours and pawn.age == Pregnancy.infant_age():
				messages.append("%s is old enough to run about on their own." % pawn.display_name)
				changed = true
			elif after == "elder" and before != "elder":
				Mood.add_event(pawn, "grew_old", GameClock.tick)
				if yours:
					messages.append("%s is growing old." % pawn.display_name)
		if pawn.age >= death_age(pawn):
			Mortality.fall(sim, pawn, "died of old age")
	if changed:
		sim.household_changed.emit()
	return messages
