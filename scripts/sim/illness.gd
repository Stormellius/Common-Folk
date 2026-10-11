class_name Illness
extends RefCounted
## Sickness (data/illness.json). Each midnight a healthy person may catch something, more likely in
## cold seasons and when filthy; an ill person may recover (more likely if rested) or, if it drags
## on too long, die. A sickbed at the clinic cures it (`cures` and `cure_minutes` on the object).
## While ill someone feels low, tires faster, and stays off work.


static func def(id: String) -> Dictionary:
	return DataRegistry.get_def("illness", id)


## The chance that this healthy person falls ill today, for the first kind of illness that rolls.
static func catch_chance(illness: Dictionary, pawn: Pawn, season_id: String, event_multiplier: float) -> float:
	var chance := float(illness.get("chance_per_day", 0.0))
	chance *= float(illness.get("season_multipliers", {}).get(season_id, 1.0)) * event_multiplier
	if pawn.needs.has("hygiene") and float(pawn.needs["hygiene"]) < float(illness.get("dirty_below", 0.0)):
		chance *= float(illness.get("dirty_multiplier", 1.0))
	return chance


static func recovery_chance(illness: Dictionary, pawn: Pawn) -> float:
	var chance := float(illness.get("recovery_per_day", 0.0))
	if float(pawn.needs.get("rest", 0.0)) >= 60.0:
		chance += float(illness.get("rested_bonus", 0.0))
	return chance


## `season_multipliers` with this person's illness effects multiplied in.
static func drain_multipliers(pawn: Pawn, season_multipliers: Dictionary) -> Dictionary:
	if pawn.illness == "":
		return season_multipliers
	var merged := season_multipliers.duplicate()
	var extra: Dictionary = def(pawn.illness).get("need_drain_multipliers", {})
	for need_id in extra:
		merged[need_id] = float(merged.get(need_id, 1.0)) * float(extra[need_id])
	return merged
