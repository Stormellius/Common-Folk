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
	if pawn.treated_until > GameClock.tick:  # herbs help
		chance += float(illness.get("herb_bonus", 0.12))
	return chance


## Whether this person cannot catch it now: they had it not long ago.
static func is_immune(pawn: Pawn, illness_id: String) -> bool:
	return int(pawn.immune.get(illness_id, 0)) > GameClock.tick


## Every few minutes, a contagious illness passes from the ill to those close by: more readily
## when they are filthy. Returns the people who caught it.
static func spread(sim: Simulation, rng: RandomNumberGenerator, minutes: int) -> Array[Pawn]:
	var caught: Array[Pawn] = []
	var everyone := sim.people()
	for sick in everyone:
		var illness := def(sick.illness)
		if sick.illness == "" or not bool(illness.get("contagious", false)) or sick.is_dying():
			continue
		var radius := int(illness.get("spread_radius", 3))
		var chance := float(illness.get("spread_per_hour", 0.1)) * float(minutes) / 60.0
		for other in everyone:
			if other.id == sick.id or other.illness != "" or other.is_dying() or is_immune(other, sick.illness):
				continue
			if absi(other.tile.x - sick.tile.x) > radius or absi(other.tile.y - sick.tile.y) > radius:
				continue
			var factor := 1.0
			if float(other.needs.get("hygiene", 100.0)) < float(illness.get("dirty_below", 0.0)):
				factor = float(illness.get("dirty_multiplier", 1.0))
			if rng.randf() < chance * factor:
				other.illness = sick.illness
				other.ill_since = GameClock.tick
				caught.append(other)
	return caught


## `season_multipliers` with this person's illness effects multiplied in.
static func drain_multipliers(pawn: Pawn, season_multipliers: Dictionary) -> Dictionary:
	if pawn.illness == "":
		return season_multipliers
	var merged := season_multipliers.duplicate()
	var extra: Dictionary = def(pawn.illness).get("need_drain_multipliers", {})
	for need_id in extra:
		merged[need_id] = float(merged.get(need_id, 1.0)) * float(extra[need_id])
	return merged
