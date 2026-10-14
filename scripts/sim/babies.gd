class_name Babies
extends RefCounted
## What a baby of your household needs ("baby_care" in data/pregnancy.json): to be fed, comforted
## and kept clean. Each runs down by the hour, comfort faster when the baby is left alone. When one
## runs low, someone of the household goes to see to it on their own (a parent first), or you can
## send someone: right-click the baby. A baby with an empty need cries, and the household hears
## it; one left neglected too long is taken in by the parish.
##
## At night a baby sleeps in a cradle on its home lot, if there is one; by day it is carried.
## The town's babies are looked after by their families without any of this.

const CHECK_EVERY := 10  # minutes between looking for someone to tend a baby


static func care_defs() -> Array:
	return Pregnancy.config().get("baby_care", [])


static func care_def(care_id: String) -> Dictionary:
	for def in care_defs():
		if str(def["id"]) == care_id:
			return def
	return {}


## A newborn starts out fed, comfortable and clean.
static func reset_care(baby: Pawn) -> void:
	baby.care = {}
	for def in care_defs():
		baby.care[str(def["id"])] = Needs.FULL
	baby.neglected_since = -1


## The lowest of a baby's care values (full if it has none).
static func worst_care(baby: Pawn) -> float:
	var worst := Needs.FULL
	for care_id in baby.care:
		worst = minf(worst, float(baby.care[care_id]))
	return worst


## The care a baby most needs now, if any is below `below`, or "".
static func most_needed(baby: Pawn, below: float) -> String:
	var found := ""
	var lowest := below
	for care_id in baby.care:
		if float(baby.care[care_id]) < lowest:
			lowest = float(baby.care[care_id])
			found = str(care_id)
	return found


static func is_crying(baby: Pawn) -> bool:
	return baby.is_infant() and not baby.care.is_empty() and worst_care(baby) < float(Pregnancy.config().get("cry_below", 25))


## The cradle a baby sleeps in tonight: a free cradle on its home lot, at night. Null by day, or
## if there is none.
static func cradle_for(sim: Simulation, baby: Pawn) -> PlacedObject:
	var hour := GameClock.get_minute_of_day() / 60
	var from := int(Pregnancy.config().get("cradle_from_hour", 21))
	var until := int(Pregnancy.config().get("cradle_until_hour", 6))
	if not (hour >= from or hour < until):
		return null
	var home: Rect2i = sim.world.lot if baby.home_lot == WorldState.HOME_LOT else sim.world.get_lot(baby.home_lot).get("rect", Rect2i())
	var taken := {}
	for other in sim.people():
		if other.id != baby.id and other.is_infant():
			taken[other.tile] = true
	for placed in sim.world.objects:
		if placed.def_id == "cradle" and home.has_point(placed.tile) and (not taken.has(placed.tile) or placed.tile == baby.tile):
			return placed
	return null


## Every minute: your household's babies get hungrier, lonelier and dirtier; a crying baby upsets
## the house; someone goes to see to a baby that needs it; and a baby neglected too long is taken
## away. Returns messages for the player.
static func step(sim: Simulation) -> Array[String]:
	var messages: Array[String] = []
	var now := GameClock.tick
	for baby in sim.household.pawns.duplicate():
		if not baby.is_infant():
			continue
		if baby.care.is_empty():
			reset_care(baby)
		var alone := cradle_for(sim, baby) != null and not _anyone_near(sim, baby)
		for def in care_defs():
			var care_id := str(def["id"])
			var rate := float(def.get("drain_alone", def.get("drain_per_hour", 5.0))) if alone else float(def.get("drain_per_hour", 5.0))
			baby.care[care_id] = maxf(0.0, float(baby.care.get(care_id, Needs.FULL)) - rate / 60.0)
		if worst_care(baby) <= 0.0:
			if baby.neglected_since < 0:
				baby.neglected_since = now
			elif now - baby.neglected_since >= int(Pregnancy.config().get("neglect_hours", 12)) * 60:
				messages.append(_taken_away(sim, baby))
				continue
		else:
			baby.neglected_since = -1
		if now % 30 == 0 and is_crying(baby):
			for other in sim.household.pawns:
				if not other.is_infant() and other.pose != "lie" and absi(other.tile.x - baby.tile.x) + absi(other.tile.y - baby.tile.y) <= 10:
					Mood.add_event(other, "baby_crying", now)
		if now % CHECK_EVERY == 0:
			_send_someone(sim, baby)
	return messages


static func _anyone_near(sim: Simulation, baby: Pawn) -> bool:
	for other in sim.household.pawns:
		if not other.is_infant() and absi(other.tile.x - baby.tile.x) + absi(other.tile.y - baby.tile.y) <= 2:
			return true
	return false


## When the baby needs something, the best person free to see to it goes: a parent before anyone
## else, whoever is nearer before whoever is further. Nobody leaves a need of their own that is
## critical, and nobody goes while someone else is already on the way.
static func _send_someone(sim: Simulation, baby: Pawn) -> void:
	var care_id := most_needed(baby, float(Pregnancy.config().get("tend_below", 45)))
	if care_id == "":
		return
	for other in sim.household.pawns:
		if other.job_kind == "tend" and other.job_partner == baby.id:
			return
	var best: Pawn = null
	var best_score := INF
	for other in sim.household.pawns:
		if tend_blocker(sim, other, baby) != "" or (other.is_busy() and other.job_kind != "") or other.has_orders():
			continue
		if sim.needs_break(other):
			continue
		var score := float(absi(other.tile.x - baby.tile.x) + absi(other.tile.y - baby.tile.y))
		if baby.opinion_of(other.id) >= Relations.FAMILY_START and other.adult:
			score -= 20.0
		if other.id == baby.carried_by:
			score -= 30.0
		if score < best_score:
			best_score = score
			best = other
	if best != null:
		sim.order_tend(best, baby, care_id)


## Why `carer` cannot see to `baby` now, or "".
static func tend_blocker(sim: Simulation, carer: Pawn, baby: Pawn) -> String:
	if not baby.is_infant():
		return "not a baby"
	if carer.is_infant() or carer.is_dying() or carer.age < Life.stage_start("youth", 13):
		return "too young" if not carer.is_dying() else "%s is dying" % carer.display_name.get_slice(" ", 0)
	if sim.household.get_pawn(carer.id) == null:
		return "not their baby"
	if carer.id != baby.carried_by and sim.plan_beside(carer, baby.tile).is_empty() and carer.tile != baby.tile:
		return "can't get there"
	return ""


## The parish takes a neglected baby away; the household is shamed and grieves.
static func _taken_away(sim: Simulation, baby: Pawn) -> String:
	sim.household.remove_pawn(baby.id)
	for other in sim.household.pawns:
		Mood.add_event(other, "baby_taken", GameClock.tick)
	sim.household_changed.emit()
	return "The parish has taken %s away: the baby was left uncared for too long." % baby.display_name
