class_name Mortality
extends RefCounted
## Dying, Death, mourning and the restless dead (data/death.json).
##
## Nobody drops dead on the spot (except far away, in a raid). Someone whose time has come falls
## where they stand and lies dying. A little later Death appears nearby, walks up and waits beside
## them; after a few hours he takes them, and a grave is dug in the chapel yard if there is room,
## or where they fell. While he waits, any of your folk can plead with him: the more they loved
## the dying person, the likelier he relents, and then they get up again, shaken. One plea is all
## he hears, and he never spares those whose time is old age.
##
## Everyone who knew the dead mourns them, as hard as they were close (a rival is glad). Some of
## the dead do not rest: on some nights their ghost walks near the grave and frightens whoever
## sees it, until somebody prays at the grave and lays the soul to rest.

## Where Death is when he first appears: this many tiles from the one he comes for.
const APPROACH_TILES := 4.0
const WITNESS_RADIUS := 8


static func config() -> Dictionary:
	return DataRegistry.get_def("death", "death")


static func _minutes(key: String, fallback: int) -> int:
	return int(config().get(key, fallback))


# --- dying -----------------------------------------------------------------------------

## Someone's time has come: they fall where they stand and lie dying, and Death is on his way.
static func fall(sim: Simulation, pawn: Pawn, cause: String) -> void:
	if pawn.is_dying():
		return
	sim.order_stop(pawn)
	Fauna.dismount(sim, pawn)
	pawn.dying_cause = cause
	pawn.dying_since = GameClock.tick
	pawn.pleaded = false
	pawn.pose = "fallen"
	pawn.slowed = false
	var angle := TAU * ObjectArt.hash01(pawn.id, GameClock.tick, 17)
	pawn.death_from = pawn.tile + Vector2i(roundi(cos(angle) * APPROACH_TILES), roundi(sin(angle) * APPROACH_TILES))
	if sim.household.get_pawn(pawn.id) != null:
		var first := _first(pawn)
		var hope := "Death will come for %s soon." % first if cause in config().get("never_spares", []) \
			else "Right-click %s to plead with Death before he takes them." % first
		sim.health_notice.emit("%s has fallen and is dying. %s" % [pawn.display_name, hope])


## Minutes since the person fell.
static func minutes_dying(pawn: Pawn) -> int:
	return GameClock.tick - pawn.dying_since if pawn.is_dying() else 0


## Whether Death has reached the dying person and is waiting beside them.
static func death_has_come(pawn: Pawn) -> bool:
	return pawn.is_dying() and minutes_dying(pawn) >= _minutes("arrives_after_minutes", 60)


## Where Death is for the view: { "visible": bool, "from": Vector2i, "to": Vector2 (tile units, the
## middle of the tile beside the dying), "progress": 0 to 1 along the way, "fade": 0 to 1 }.
static func death_figure(pawn: Pawn) -> Dictionary:
	var elapsed := minutes_dying(pawn)
	var appears := _minutes("appears_after_minutes", 20)
	var arrives := maxi(appears + 1, _minutes("arrives_after_minutes", 60))
	var takes := _minutes("takes_after_minutes", 240)
	if not pawn.is_dying() or elapsed < appears:
		return { "visible": false }
	var side := 1.0 if pawn.death_from.x >= pawn.tile.x else -1.0  # he waits at their side, on the side he came from
	var beside := Vector2(pawn.tile) + Vector2(0.5 + side * 0.95, 0.6)
	var progress := clampf(float(elapsed - appears) / float(arrives - appears), 0.0, 1.0)
	var fade := minf(clampf(float(elapsed - appears) / 10.0, 0.0, 1.0), clampf(float(takes - elapsed) / 5.0, 0.0, 1.0))
	return { "visible": true, "from": Vector2(pawn.death_from) + Vector2(0.5, 0.5), "to": beside, "progress": progress, "fade": fade }


## Every minute: Death arrives (those nearby see him), and takes those whose time is up. Also
## sees to the ghosts.
static func step(sim: Simulation) -> void:
	var now := GameClock.tick
	var arrives := _minutes("arrives_after_minutes", 60)
	var takes := _minutes("takes_after_minutes", 240)
	for pawn in sim.people():
		if not pawn.is_dying():
			continue
		var elapsed := now - pawn.dying_since
		if elapsed == arrives:
			for other in sim.people():
				if other.id != pawn.id and not other.is_dying() and not other.is_infant() and other.pose != "lie" \
						and absi(other.tile.x - pawn.tile.x) + absi(other.tile.y - pawn.tile.y) <= WITNESS_RADIUS:
					Mood.add_event(other, "saw_death", now, _first(pawn))
			if sim.household.get_pawn(pawn.id) != null:
				sim.health_notice.emit("Death has come for %s." % pawn.display_name)
		if elapsed >= takes:
			sim.die(pawn, pawn.dying_cause)
	for i in range(sim.departures.size() - 1, -1, -1):
		if now - int(sim.departures[i]["tick"]) > 90:
			sim.departures.remove_at(i)
	_haunt(sim, now)


## Why `pleader` cannot plead with Death for `dying` right now, or "".
static func plead_blocker(sim: Simulation, pleader: Pawn, dying: Pawn) -> String:
	var name := _first(dying)
	if not dying.is_dying():
		return "%s is not dying" % name
	if pleader.id == dying.id or pleader.is_dying() or pleader.is_infant():
		return "not possible"
	if dying.dying_cause in config().get("never_spares", []):
		return "it is %s's time" % name
	if dying.pleaded:
		return "Death has heard a plea for %s already" % name
	if sim.plan_beside(pleader, dying.tile).is_empty():
		return "can't get there"
	return ""


## The chance that Death relents when `pleader` asks for `dying`: better the more they loved them.
static func plead_chance(pleader: Pawn, dying: Pawn) -> float:
	var settings := config()
	var chance := float(settings.get("plead_chance", 0.2)) + float(settings.get("plead_chance_per_opinion", 0.004)) * maxf(0.0, pleader.opinion_of(dying.id))
	var bonuses: Dictionary = settings.get("plead_bonus", {})
	for trait_id in pleader.traits:
		chance += float(bonuses.get(trait_id, 0.0))
	return clampf(chance, 0.0, 0.95)


## A plea has been made (the pleader knelt beside the dying for long enough). Returns the message.
static func resolve_plea(sim: Simulation, pleader: Pawn, dying: Pawn, rng: RandomNumberGenerator) -> String:
	dying.pleaded = true
	if not dying.is_dying():
		return ""
	if rng.randf() < plead_chance(pleader, dying):
		spare(dying)
		Mood.add_event(pleader, "pleaded_won", GameClock.tick, _first(dying))
		return "Death has spared %s. %s talked him out of it." % [dying.display_name, _first(pleader)]
	Mood.add_event(pleader, "pleaded_lost", GameClock.tick)
	return "Death would not listen to %s." % _first(pleader)


## Death relents: the dying get up again, weak but alive, and whatever was killing them lets go.
static func spare(pawn: Pawn) -> void:
	var floor_value := float(config().get("spared_needs", 35))
	for need_id in pawn.needs:
		pawn.needs[need_id] = maxf(float(pawn.needs[need_id]), floor_value)
	pawn.deprivation.clear()
	pawn.illness = ""
	pawn.dying_cause = ""
	pawn.dying_since = 0
	pawn.pose = ""
	Mood.add_event(pawn, "spared", GameClock.tick)


# --- after a death ---------------------------------------------------------------------

## Called by Simulation.die once the dead have left the world (`yours`: they were one of your
## folk): the mourning, and the spirit that stays with the grave (restless or not).
static func after_death(sim: Simulation, dead: Pawn, cause: String, grave: Vector2i, rng: RandomNumberGenerator, yours: bool) -> void:
	mourn(sim, dead, yours)
	if grave.x < 0:
		return
	var settings := config()
	var chance := float(settings.get("restless_chance_old_age", 0.1)) if cause in settings.get("never_spares", []) else float(settings.get("restless_chance", 0.3))
	sim.world.spirits.append({
		"name": dead.display_name,
		"look": dead.look.duplicate(),
		"grave": [grave.x, grave.y],
		"restless": rng.randf() < chance,
		"haunt_until": -1,
	})


## Everyone who knew the dead takes it as hard as they were close: a loved one, or anyone fond who
## shared their home, is a great loss, the rest of the household and friends mourn, and a rival
## is glad.
static func mourn(sim: Simulation, dead: Pawn, yours: bool) -> void:
	var settings := config()
	var now := GameClock.tick
	for other in sim.people():
		if other.id == dead.id or other.is_infant() or other.is_dying():
			continue
		var opinion := other.opinion_of(dead.id)
		var housemate := (sim.household.get_pawn(other.id) != null) == yours and other.home_lot == dead.home_lot
		if opinion <= float(settings.get("glad_below", -40)):
			Mood.add_event(other, "rival_died", now, dead.display_name)
		elif opinion >= float(settings.get("mourn_close_from", 50)) or (housemate and opinion >= Relations.FAMILY_FLOOR):
			Mood.add_event(other, "lost_loved_one", now, dead.display_name)
		elif opinion >= float(settings.get("mourn_from", 15)) or housemate:
			Mood.add_event(other, "mourning", now, dead.display_name)


# --- the restless dead ------------------------------------------------------------------

## The spirit whose grave is on `tile`, or an empty Dictionary.
static func spirit_at(world: WorldState, tile: Vector2i) -> Dictionary:
	for spirit in world.spirits:
		if int(spirit["grave"][0]) == tile.x and int(spirit["grave"][1]) == tile.y:
			return spirit
	return {}


## Ghosts walking right now.
static func haunting(world: WorldState, now: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for spirit in world.spirits:
		if int(spirit.get("haunt_until", -1)) > now:
			found.append(spirit)
	return found


## Where a ghost drifts, in tiles: slow loops about its grave, the same for everyone watching.
static func ghost_position(spirit: Dictionary, now: float) -> Vector2:
	var grave := Vector2(float(spirit["grave"][0]), float(spirit["grave"][1])) + Vector2(0.5, 0.5)
	var seed := ObjectArt.hash01(hash(str(spirit["name"])), 0, 23) * 50.0
	var hours := now / 60.0
	return grave + Vector2(sin(hours * 0.9 + seed) * 1.8, cos(hours * 0.7 + seed * 1.3) * 1.3)


## Late at night a restless spirit may walk; every ten minutes anyone awake near a ghost sees it.
static func _haunt(sim: Simulation, now: int) -> void:
	var settings := config()
	var minute := posmod(now, GameClock.MINUTES_PER_DAY)
	if minute == int(settings.get("haunt_from_hour", 23)) * 60:
		var until_hour := int(settings.get("haunt_until_hour", 4))
		var hours := posmod(until_hour * 60 - minute, GameClock.MINUTES_PER_DAY)
		for spirit in sim.world.spirits:
			var grave := Vector2i(int(spirit["grave"][0]), int(spirit["grave"][1]))
			var marker := sim.world.object_at(grave)
			if bool(spirit["restless"]) and marker != null and marker.def_id == "grave" and sim.rng().randf() < float(settings.get("haunt_chance", 0.35)):
				spirit["haunt_until"] = now + hours
	if minute % 10 != 0:
		return
	var radius := float(settings.get("ghost_scare_radius", 6))
	for spirit in haunting(sim.world, now):
		var where := ghost_position(spirit, now)
		for pawn in sim.people():
			if pawn.is_dying() or pawn.is_infant() or pawn.pose == "lie":
				continue
			if (Vector2(pawn.tile) + Vector2(0.5, 0.5)).distance_to(where) <= radius:
				Mood.add_event(pawn, "saw_ghost", now, str(spirit["name"]))


## Someone prayed at the grave on `tile`: its spirit is at rest for good. Returns a message for
## the player if a restless soul was laid to rest, or "".
static func lay_to_rest(sim: Simulation, tile: Vector2i, by: Pawn) -> String:
	var spirit := spirit_at(sim.world, tile)
	if spirit.is_empty():
		return ""
	var was_restless := bool(spirit["restless"])
	spirit["restless"] = false
	spirit["haunt_until"] = -1
	Mood.add_event(by, "laid_to_rest", GameClock.tick, str(spirit["name"]))
	return "%s has laid the soul of %s to rest." % [_first(by), str(spirit["name"])] if was_restless else ""


static func _first(pawn: Pawn) -> String:
	return pawn.display_name.get_slice(" ", 0)
