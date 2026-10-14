class_name Needs
extends RefCounted
## Rules about needs that do not belong to one person: which needs are in play, how fast
## they drain, and when someone starts looking for a way to fix one. The values themselves
## live on each Pawn (`pawn.needs`, 0 = empty, 100 = full).
##
## A need is only in play while something in the world can fill it: that is, some object in
## data/objects.json, or some two-person interaction in data/interactions.json, lists it under
## "satisfies". So adding a chapel object with { "satisfies": { "faith": 20 } } switches Faith
## on, and until then it stays dormant. Needs marked "optional" in needs.json are not given to
## anyone yet. A need with "slows_when_empty": false (Libido) never drags a person's feet.

const FULL := 100.0
const DEFAULT_SEEK_BELOW := 35.0
const NIGHT_REST_SEEK_BELOW := 60.0  # people go to bed earlier in the dark
const NIGHT_START_MINUTE := 21 * 60
const NIGHT_END_MINUTE := 6 * 60


## The ids of the needs in play, in the order of needs.json.
static func active_ids() -> Array[String]:
	var fillable := {}
	for kind in ["objects", "interactions"]:
		for source in DataRegistry.get_list(kind):
			for need_id in source.get("satisfies", {}):
				fillable[str(need_id)] = true
	var ids: Array[String] = []
	for need_def in DataRegistry.get_list("needs"):
		var need_id := str(need_def.get("id", ""))
		if need_id != "" and not bool(need_def.get("optional", false)) and fillable.has(need_id):
			ids.append(need_id)
	return ids


## What is worked out from the data once and kept, until the data is loaded again.
static var _need_info := {}   # need id -> { "per_hour", "slows", "fatal" }
static var _trait_drain := {} # trait id -> its need_drain_multipliers
static var _info_revision := -1


static func _info(need_id: String) -> Dictionary:
	if _info_revision != DataRegistry.revision:
		_need_info.clear()
		_trait_drain.clear()
		_info_revision = DataRegistry.revision
	var info: Variant = _need_info.get(need_id)
	if info == null:
		var def := DataRegistry.get_def("needs", need_id)
		info = { "per_hour": float(def.get("drain_per_hour", 0.0)), "slows": bool(def.get("slows_when_empty", true)), "fatal": float(def.get("fatal_after_hours", 0.0)) }
		_need_info[need_id] = info
	return info


## Points lost per game minute (one tick) by one person, given the season's multipliers.
static func drain_per_tick(need_id: String, traits: Array[String], season_multipliers: Dictionary) -> float:
	var factor := float(season_multipliers.get(need_id, 1.0)) if not season_multipliers.is_empty() else 1.0
	for trait_id in traits:
		var multipliers: Variant = _trait_drain.get(trait_id)
		if multipliers == null:
			multipliers = DataRegistry.get_def("traits", trait_id).get("need_drain_multipliers", {})
			_trait_drain[trait_id] = multipliers
		if not multipliers.is_empty():
			factor *= float(multipliers.get(need_id, 1.0))
	return float(_info(need_id)["per_hour"]) / 60.0 * factor


## False for needs that may sit at zero without slowing the person down.
static func slows_when_empty(need_id: String) -> bool:
	return bool(_info(need_id)["slows"])


## How many hours a need may stay empty before it kills, or 0 if it never does.
static func fatal_after_hours(need_id: String) -> float:
	return float(_info(need_id)["fatal"])


## Below this value an idle person starts looking for a fix.
static func seek_below(need_id: String, minute_of_day: int) -> float:
	var override: Variant = DataRegistry.get_def("needs", need_id).get("seek_below")
	if override != null:
		return float(override)
	if need_id == "rest" and (minute_of_day >= NIGHT_START_MINUTE or minute_of_day < NIGHT_END_MINUTE):
		return NIGHT_REST_SEEK_BELOW
	return DEFAULT_SEEK_BELOW


## "good", "low" or "critical", for coloring bars.
static func band(value: float) -> String:
	if value <= 15.0:
		return "critical"
	if value <= 40.0:
		return "low"
	return "good"
