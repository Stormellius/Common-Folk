class_name EventDirector
extends RefCounted
## Things that happen to the whole town, from data/events.json: a festival on the green, market
## day, a cold snap. Each morning the director rolls for each event in the file (its "chance" that
## day, only in its "seasons", and not again within "cooldown_days"); one that comes up is
## scheduled for its "start_hour" and lasts "duration_hours". The roll is seeded by the world and
## the day, so the same world has the same events whether or not you saved and loaded.
##
## What an event does is data too:
##   need_drain_multipliers   needs drain faster or slower while it lasts
##   price_multipliers        objects cost more or less to use
##   gather                   a kind of building (park, shop...) the townspeople go to
##   restore / thought        needs filled and a thought given to those who are there

var scheduled: Array[Dictionary] = []   # { "id", "start", "until" } in clock ticks
var active: Array[Dictionary] = []
var history: Array[Dictionary] = []     # { "id", "day" } of each one that has started
var last_roll_day := -1


## Call every tick. Returns what changed: [{ "kind": "started" or "ended", "id": event id }].
func update(world_seed: int) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	var now := GameClock.tick
	var day := GameClock.get_day_number()
	if day != last_roll_day:
		last_roll_day = day
		_roll(world_seed, day, now)
	for entry in scheduled.duplicate():
		if now >= int(entry["start"]):
			scheduled.erase(entry)
			active.append(entry)
			history.append({ "id": entry["id"], "day": day })
			changes.append({ "kind": "started", "id": entry["id"] })
	for entry in active.duplicate():
		if now >= int(entry["until"]):
			active.erase(entry)
			changes.append({ "kind": "ended", "id": entry["id"] })
	return changes


func _roll(world_seed: int, day: int, now: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, day])
	var season_id := str(GameClock.get_date().get("season_id", ""))
	for def in DataRegistry.get_list("events"):
		var id := str(def["id"])
		var seasons: Array = def.get("seasons", [])
		var roll := rng.randf()  # always drawn, so that the day's outcome does not depend on what is already going on
		if (not seasons.is_empty() and season_id not in seasons) or is_going(id) or roll >= float(def.get("chance", 0.0)):
			continue
		if _days_since(id, day) < int(def.get("cooldown_days", 0)):
			continue
		var start := maxi(now, day * GameClock.MINUTES_PER_DAY + int(def.get("start_hour", 8)) * 60)
		scheduled.append({ "id": id, "start": start, "until": start + int(def.get("duration_hours", 8)) * 60 })
		return  # one new event a day is plenty


## Proclaims an event right now (a decree), lasting as long as its definition says. It begins on the next tick.
func start(id: String) -> void:
	var def := DataRegistry.get_def("events", id)
	if def.is_empty() or is_going(id):
		return
	var now := GameClock.tick
	scheduled.append({ "id": id, "start": now, "until": now + int(def.get("duration_hours", 8)) * 60 })


func _days_since(id: String, day: int) -> int:
	var latest := -1000000
	for entry in history:
		if entry["id"] == id:
			latest = maxi(latest, int(entry["day"]))
	return day - latest


func is_going(id: String) -> bool:
	for entry in active + scheduled:
		if entry["id"] == id:
			return true
	return false


## The definitions of the events going on right now.
func active_defs() -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	for entry in active:
		var def := DataRegistry.get_def("events", str(entry["id"]))
		if not def.is_empty():
			defs.append(def)
	return defs


func names() -> Array[String]:
	var found: Array[String] = []
	for def in active_defs():
		found.append(str(def.get("name", def["id"])))
	return found


## All the need multipliers of the events going on, multiplied together.
func drain_multipliers() -> Dictionary:
	var combined := {}
	for def in active_defs():
		var multipliers: Dictionary = def.get("need_drain_multipliers", {})
		for need_id in multipliers:
			combined[need_id] = float(combined.get(need_id, 1.0)) * float(multipliers[need_id])
	return combined


## How much the events going on raise the chance of falling ill.
func illness_multiplier() -> float:
	var factor := 1.0
	for def in active_defs():
		factor *= float(def.get("illness_multiplier", 1.0))
	return factor


func price_multiplier(object_def_id: String) -> float:
	var factor := 1.0
	for def in active_defs():
		factor *= float(def.get("price_multipliers", {}).get(object_def_id, 1.0))
	return factor


## What the shop pays for goods now: more on a market day.
func sell_multiplier() -> float:
	var factor := 1.0
	for def in active_defs():
		factor *= float(def.get("sell_multiplier", 1.0))
	return factor


func to_dict() -> Dictionary:
	return { "scheduled": scheduled.duplicate(true), "active": active.duplicate(true), "history": history.duplicate(true), "last_roll_day": last_roll_day }


func load_dict(data: Dictionary) -> void:
	scheduled.clear()
	active.clear()
	history.clear()
	for key in ["scheduled", "active"]:
		for entry in data.get(key, []):
			if entry is Dictionary and DataRegistry.has_def("events", str(entry.get("id", ""))):
				(scheduled if key == "scheduled" else active).append({ "id": str(entry["id"]), "start": int(entry.get("start", 0)), "until": int(entry.get("until", 0)) })
	for entry in data.get("history", []):
		if entry is Dictionary:
			history.append({ "id": str(entry.get("id", "")), "day": int(entry.get("day", 0)) })
	last_roll_day = int(data.get("last_roll_day", -1))
