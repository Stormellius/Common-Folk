class_name Simulation
extends RefCounted
## Everything that changes as the game clock ticks: the world, the household and the
## rules that connect them. Views and input only call the commands here (order_move,
## order_stop, order_use) and read the state; they never change pawns directly.
##
## Each tick, every person: loses a little of each need, takes a step of any walk,
## carries on with the object they are using, and, if they have nothing to do and some
## need is low, goes off to fix it on their own.

const THINK_COOLDOWN_TICKS := 30  # wait this long after finding nothing to fix a need with
const OPTIONS_PER_NEED := 3       # how many nearest objects to try
const SOCIAL_RADIUS := 30         # how far someone lonely will go to find a person to talk to
const GATHER_CHANCE := 0.04       # per minute, for an idle townsperson while an event draws a crowd
const EVENT_EVERY := 10           # minutes between giving event thoughts and company
const WORK_BREAK_BELOW := 15.0    # a need this low sends a worker off their shift to see to it
const MOOD_EVERY := 5             # minutes between mood checks for townspeople
const ROAM_CHANCE := 0.012        # per minute, for an idle townsperson in the daytime
const ROAM_FROM_MINUTE := 7 * 60
const ROAM_UNTIL_MINUTE := 20 * 60
const RICH_COINS := 100           # someone with this much does not mind paying for a meal out
const ROAM_RADIUS := 14           # how far from the crossroads they wander along the roads

var world: WorldState
var household: Household
## The people of the town (not the player's): see NpcGenerator. They live by the same rules.
var town: Household
var pathfinder: PathFinder
## What happens to the whole town: festivals, market days, cold snaps (data/events.json).
var events := EventDirector.new()
## The Crown, land titles, guild and taxes (see Realm).
var realm := Realm.new()
## Someone died: their name, what killed them and the name of whoever you now control ("" if
## nobody is left, which ends the playthrough).
signal pawn_died(person: String, cause: String, successor: String)
## Someone in the town died (the player's own deaths come through pawn_died).
signal town_death(person: String, cause: String)
## A town event (see EventDirector) began or ended. `text` is the announcement.
signal event_started(event_name: String, text: String)
signal event_ended(event_name: String)
## Something the player should be told about the realm: the tax collector came, an heir took over.
signal realm_notice(text: String)
## Someone in the household fell ill, or got better.
signal health_notice(text: String)
## Ids of the needs in play; see Needs.
var active_needs: Array[String] = []


var _rng := RandomNumberGenerator.new()  # for townspeople's wandering (not part of the world seed's output)


func _init(p_world: WorldState, p_household: Household, p_town: Household = null, p_realm: Realm = null) -> void:
	world = p_world
	household = p_household
	if p_realm != null:
		realm = p_realm
	town = p_town if p_town != null else Household.new(NpcGenerator.FIRST_ID)
	_rng.seed = world.world_seed + 4242
	pathfinder = PathFinder.new(world)
	active_needs = Needs.active_ids()
	_repair_after_load()


## One game minute passes. Called from the clock's `ticked` signal.
func step() -> void:
	for change in events.update(world.world_seed):
		var event_def := DataRegistry.get_def("events", str(change["id"]))
		var event_name := str(event_def.get("name", change["id"]))
		if change["kind"] == "started":
			event_started.emit(event_name, str(event_def.get("announce", event_name)))
		else:
			event_ended.emit(event_name)
	var season_multipliers := _season_multipliers()
	var minute := GameClock.get_minute_of_day()
	var everyone := people()
	if minute == 0:
		Relations.drift(everyone)
		for notice in realm.new_day(self):
			realm_notice.emit(notice)
		_roll_illness(everyone)
	if minute % EVENT_EVERY == 0:
		_apply_events(everyone)
	for pawn in everyone:
		var cause := _drain_needs(pawn, Illness.drain_multipliers(pawn, season_multipliers))
		if cause != "":
			die(pawn, cause)
			continue
		if household.get_pawn(pawn.id) != null or (GameClock.tick + pawn.id) % MOOD_EVERY == 0:
			_update_mood(pawn, everyone)  # the town's mood changes slowly, so it is looked at less often
		pawn.tick(world)
		_step_job(pawn)
		if pawn.think_cooldown > 0:
			pawn.think_cooldown -= 1
		elif not pawn.is_busy():
			if not _think(pawn, minute) and not _try_work(pawn, minute) and town.get_pawn(pawn.id) != null:
				_roam(pawn, minute)


## Everyone in the world: the player's household first, then the town.
func people() -> Array[Pawn]:
	var everyone: Array[Pawn] = household.pawns.duplicate()
	everyone.append_array(town.pawns)
	return everyone


## Anyone, by id (the household uses small ids, the town 1000 and up), or null.
func person(id: int) -> Pawn:
	var found := household.get_pawn(id)
	return found if found != null else town.get_pawn(id)


# --- orders ----------------------------------------------------------------------

## Sends a pawn to a tile. Returns { "ok": bool, "message": String }; the message
## says why not when the order cannot be carried out.
func order_move(pawn: Pawn, target: Vector2i) -> Dictionary:
	if not world.in_bounds(target.x, target.y):
		return { "ok": false, "message": "That is outside the map" }
	if not world.is_walkable(target.x, target.y):
		return { "ok": false, "message": "Can't walk there" }
	var origin := pawn.committed_tile()
	var route := pathfinder.find_path(origin, target)
	if route.is_empty() and origin != target:
		return { "ok": false, "message": "There is no way to get there" }
	_end_job(pawn)
	pawn.path = route
	return { "ok": true, "message": "" }


## Stops a pawn once it has finished the step it is on, and puts down whatever it was using.
func order_stop(pawn: Pawn) -> void:
	_end_job(pawn)
	pawn.path.clear()


## Why `pawn` cannot use `placed` right now, or "" if it can.
func use_blocker(pawn: Pawn, placed: PlacedObject) -> String:
	if placed.user_id != 0 and placed.user_id != pawn.id:
		var other := person(placed.user_id)
		return "%s is using it" % (_first_name(other) if other != null else "someone")
	var lot := world.lot_at(placed.tile)
	if not lot.is_empty() and not bool(lot["public"]) and str(lot["id"]) != pawn.home_lot:
		return "it belongs to someone else"
	var price := price_of(placed.def_id)
	if price > coins_of(pawn):
		return "can't afford it (%s)" % Economy.format(price)
	if _plan_use(pawn, placed).is_empty():
		return "can't get there"
	return ""


## Sends a pawn to use an object: walk there, then carry on until the need is full.
func order_use(pawn: Pawn, placed: PlacedObject) -> Dictionary:
	var blocker := use_blocker(pawn, placed)
	if blocker != "":
		return { "ok": false, "message": "Can't use the %s: %s" % [placed.display_name().to_lower(), blocker] }
	var plan := _plan_use(pawn, placed)
	_end_job(pawn)
	pawn.path = plan["route"]
	pawn.job_kind = "use"
	pawn.job_object = placed.id
	pawn.job_stage = "walking"
	pawn.job_tile = plan["tile"]
	pawn.job_minutes = 0
	placed.user_id = pawn.id
	return { "ok": true, "message": "" }


## Why `pawn` cannot do the interaction with `other` right now, or "" if they can. Both people
## must be willing: that is how consent works here. Someone who isn't in the mood says no,
## and the menu shows the entry switched off with that reason.
func interaction_blocker(pawn: Pawn, other: Pawn, interaction_id: String) -> String:
	var interaction := DataRegistry.get_def("interactions", interaction_id)
	if interaction.is_empty() or pawn.id == other.id:
		return "not possible"
	var other_name := _first_name(other)
	if bool(interaction.get("adults_only", false)) and not (pawn.adult and other.adult):
		return "only adults can"
	if other.is_busy():
		return "%s is busy" % other_name
	if bool(interaction.get("requires_attraction", false)):
		if not _attracted_to(other, pawn):
			return "%s isn't interested" % other_name
		if not _attracted_to(pawn, other):
			return "%s isn't interested" % _first_name(pawn)
	var min_opinion := float(interaction.get("min_opinion", -1000.0))
	if other.opinion_of(pawn.id) < min_opinion:
		return "%s isn't close enough to you yet" % other_name
	if pawn.opinion_of(other.id) < min_opinion:
		return "%s isn't close enough to %s yet" % [_first_name(pawn), other_name]
	var limits: Dictionary = interaction.get("willing_below", {})
	var unwilling := str(interaction.get("unwilling", "isn't willing"))
	for need_id in limits:
		if float(other.needs.get(need_id, 0.0)) >= float(limits[need_id]):
			return "%s %s" % [other_name, unwilling]
		if float(pawn.needs.get(need_id, 0.0)) >= float(limits[need_id]):
			return "%s %s" % [_first_name(pawn), unwilling]
	if _plan_beside(pawn, other.tile).is_empty():
		return "can't get there"
	return ""


## Whether `person` is attracted to `other`, from an orientation trait ("attracted_to" in
## data/traits.json: opposite, same, both or none). Someone with no such trait is open to anyone.
func _attracted_to(person: Pawn, other: Pawn) -> bool:
	for trait_id in person.traits:
		match str(DataRegistry.get_def("traits", trait_id).get("attracted_to", "")):
			"both":
				return true
			"none":
				return false
			"same":
				return person.gender == other.gender
			"opposite":
				return person.gender != other.gender
	return true


## Sends `pawn` to stand beside `other` and start an interaction from data/interactions.json.
## `other` waits where they are until it is over.
func order_interact(pawn: Pawn, other: Pawn, interaction_id: String) -> Dictionary:
	var blocker := interaction_blocker(pawn, other, interaction_id)
	if blocker != "":
		return { "ok": false, "message": "Not now: %s" % blocker }
	var plan := _plan_beside(pawn, other.tile)
	_end_job(pawn)
	_end_job(other)
	pawn.path = plan["route"]
	pawn.job_kind = "interact"
	pawn.job_stage = "walking"
	pawn.job_tile = plan["tile"]
	pawn.job_partner = other.id
	pawn.job_interaction = interaction_id
	pawn.job_minutes = 0
	other.job_kind = "interact"
	other.job_stage = "partner"
	other.job_partner = pawn.id
	other.job_interaction = interaction_id
	return { "ok": true, "message": "" }


# --- coin and work -----------------------------------------------------------------

## The player's household shares a purse; everyone in town carries their own.
func coins_of(pawn: Pawn) -> int:
	return household.coins if household.get_pawn(pawn.id) != null else pawn.coins


## Adds wages. Fractions are carried over until they make a whole coin.
func earn(pawn: Pawn, amount: float) -> void:
	pawn.pay_carry += amount
	var whole := floori(pawn.pay_carry)
	pawn.pay_carry -= whole
	if household.get_pawn(pawn.id) != null:
		household.coins += whole
	else:
		pawn.coins += whole


## Pays out of the household purse or the person's pocket. False (and nothing paid) if there is not enough.
func spend(pawn: Pawn, amount: int) -> bool:
	if amount > coins_of(pawn):
		return false
	if household.get_pawn(pawn.id) != null:
		household.coins -= amount
	else:
		pawn.coins -= amount
	return true


## How many people hold this job at this business.
func staff_count(lot_id: String, job_id: String) -> int:
	var count := 0
	for pawn in people():
		if pawn.work_lot == lot_id and pawn.work_job == job_id:
			count += 1
	return count


## Jobs with a vacancy: [{ "lot": lot entry, "job": job def, "open": how many }]. With a lot id,
## only that business (the counter offers its own work; the notice board lists the whole town's).
func open_positions(lot_id: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for lot in world.lots:
		if lot_id != "" and str(lot["id"]) != lot_id:
			continue
		for job in DataRegistry.get_list("jobs"):
			if str(job.get("workplace", "")) != str(lot["kind"]):
				continue
			var vacancies := int(job.get("positions", 1)) - staff_count(str(lot["id"]), str(job["id"]))
			if vacancies > 0:
				found.append({ "lot": lot, "job": job, "open": vacancies })
	return found


## Why `pawn` cannot take this job, or "".
func hire_blocker(pawn: Pawn, lot_id: String, job_id: String) -> String:
	var job := DataRegistry.get_def("jobs", job_id)
	var lot := world.get_lot(lot_id)
	if job.is_empty() or lot.is_empty() or str(job.get("workplace", "")) != str(lot["kind"]):
		return "there is no such job"
	if pawn.work_lot == lot_id and pawn.work_job == job_id:
		return "already works there"
	if pawn.age < int(job.get("min_age", 16)):
		return "must be %d or older" % int(job.get("min_age", 16))
	if pawn.class_id in job.get("not_for", []):
		return "beneath a %s" % Realm.class_name_of(pawn.class_id).to_lower()
	if staff_count(lot_id, job_id) >= int(job.get("positions", 1)):
		return "no vacancy"
	return ""


## Gives `pawn` the job (leaving any other one). Returns { "ok", "message" }.
func hire(pawn: Pawn, lot_id: String, job_id: String) -> Dictionary:
	var blocker := hire_blocker(pawn, lot_id, job_id)
	if blocker != "":
		return { "ok": false, "message": "Can't take that job: %s" % blocker }
	quit_job(pawn)
	pawn.work_lot = lot_id
	pawn.work_job = job_id
	pawn.skip_work_day = -1
	var job := DataRegistry.get_def("jobs", job_id)
	return { "ok": true, "message": "%s is now a %s at the %s" % [_first_name(pawn), str(job["name"]).to_lower(), str(world.get_lot(lot_id)["name"]).to_lower()] }


func quit_job(pawn: Pawn) -> void:
	if pawn.job_kind == "work":
		_end_job(pawn)  # paid for the hours so far
	pawn.work_lot = ""
	pawn.work_job = ""


## "Tavern hand at the tavern, 4d an hour, 12:00 to 20:00", or "" for someone out of work.
func job_text(pawn: Pawn) -> String:
	var job := DataRegistry.get_def("jobs", pawn.work_job)
	if job.is_empty():
		return ""
	var lot := world.get_lot(pawn.work_lot)
	return "%s at the %s: %s an hour, %d:00 to %d:00" % [str(job["name"]), str(lot.get("name", "town")).to_lower(), Economy.format(int(job.get("wage", 0))), int(job["from"]), int(job["to"])]


## Called when the player gives an order: a person taken off their shift stays off it today.
func note_player_order(pawn: Pawn, was_working: bool) -> void:
	if was_working:
		pawn.skip_work_day = GameClock.get_day_number()


func _on_shift(job: Dictionary, minute: int) -> bool:
	return minute >= int(job["from"]) * 60 and minute < int(job["to"]) * 60


## True when some need is bad enough that work can wait.
func _needs_break(pawn: Pawn) -> bool:
	if pawn.illness != "":
		return true
	for need_id in active_needs:
		if Needs.slows_when_empty(need_id) and float(pawn.needs.get(need_id, Needs.FULL)) < WORK_BREAK_BELOW:
			return true
	return false


## An idle person with a job goes to work when their shift starts (unless the player took them
## off it today). Returns true if they set off.
func _try_work(pawn: Pawn, minute: int) -> bool:
	if pawn.work_job == "" or pawn.skip_work_day == GameClock.get_day_number() or _needs_break(pawn):
		return false
	var job := DataRegistry.get_def("jobs", pawn.work_job)
	if job.is_empty() or not _on_shift(job, minute):
		return false
	var plan := _plan_work(pawn, job)
	if plan.is_empty():
		pawn.think_cooldown = THINK_COOLDOWN_TICKS
		return false
	pawn.path = plan["route"]
	pawn.job_kind = "work"
	pawn.job_stage = "walking"
	pawn.job_tile = plan["tile"]
	pawn.job_minutes = 0
	return true


## Where to stand for the shift: a free tile beside one of the business's stations.
func _plan_work(pawn: Pawn, job: Dictionary) -> Dictionary:
	var lot := world.get_lot(pawn.work_lot)
	if lot.is_empty():
		return {}
	var rect: Rect2i = lot["rect"]
	var taken := {}
	for other in people():
		if other.id != pawn.id and other.job_kind == "work":
			taken[other.job_tile] = true
	var candidates: Array[Vector2i] = []
	for placed in world.objects:
		if placed.def_id != str(job.get("station", "")) or not rect.has_point(placed.tile):
			continue
		for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			var spot: Vector2i = placed.tile + step
			if rect.has_point(spot) and not taken.has(spot) and spot not in candidates:
				candidates.append(spot)
	return _plan_best(pawn, candidates)


func _step_work(pawn: Pawn) -> void:
	var job := DataRegistry.get_def("jobs", pawn.work_job)
	if job.is_empty() or not _on_shift(job, GameClock.get_minute_of_day()) or _needs_break(pawn):
		_end_job(pawn)
		return
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		if pawn.tile != pawn.job_tile:
			_end_job(pawn)  # the route was blocked or cancelled
			return
		pawn.job_stage = "using"
		pawn.job_minutes = 0
		for step in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var there := world.object_at(pawn.tile + step)
			if there != null and there.def_id == str(job.get("station", "")):
				pawn.facing = step
		return
	pawn.job_minutes += 1


## Wages for the minutes worked, and a good feeling if it was at least an hour.
func _pay_shift(pawn: Pawn) -> void:
	var job := DataRegistry.get_def("jobs", pawn.work_job)
	if job.is_empty() or pawn.job_minutes <= 0:
		return
	earn(pawn, float(job.get("wage", 0)) * pawn.job_minutes / 60.0)
	if pawn.job_minutes >= 60:
		Mood.add_event(pawn, "worked", GameClock.tick)
		Mood.add_event(pawn, "paid", GameClock.tick)


# --- building ----------------------------------------------------------------------
# The player builds on the home lot only. Each command returns { "ok", "message" }; the
# message says why not. Nothing costs anything yet: materials come with the economy.

## Why `def_id` cannot go on `tile` right now, or "" if it can. `ignoring` is an object that is
## being moved and so does not count as being in the way.
func build_blocker(def_id: String, tile: Vector2i, ignoring: int = 0) -> String:
	var def := DataRegistry.get_def("objects", def_id)
	if def.is_empty() or not bool(def.get("buildable", true)):
		return "that can't be built"
	if not world.can_build_at(tile):
		return "outside your land"
	var there := world.object_at(tile)
	if there != null and there.id != ignoring:
		return "the %s is in the way" % there.display_name().to_lower()
	if not world.is_ground_walkable(tile.x, tile.y):
		var tile_id := world.get_tile_id(tile.x, tile.y)
		return "can't build on %s" % str(DataRegistry.get_def("tiles", tile_id).get("name", tile_id)).to_lower()
	if bool(def.get("blocks_walking", true)):
		for pawn in people():
			if tile == pawn.tile or tile == pawn.committed_tile():
				return "%s is standing there" % _first_name(pawn)
	var cost := Economy.object_cost(def_id) if ignoring == 0 else 0  # moving is free
	if cost > household.coins:
		return "it costs %s and you have %s" % [Economy.format(cost), Economy.format(household.coins)]
	return ""


func build_place(def_id: String, tile: Vector2i) -> Dictionary:
	var blocker := build_blocker(def_id, tile)
	if blocker != "":
		return { "ok": false, "message": "Can't build here: %s" % blocker }
	household.coins -= Economy.object_cost(def_id)
	world.add_object(def_id, tile)
	_reroute_blocked_walks()
	return { "ok": true, "message": "" }


## Picks up the object at `from_tile` and sets it down on `to_tile`. Whoever was using it stops.
func build_move(object_id: int, to_tile: Vector2i) -> Dictionary:
	var placed := world.get_object(object_id)
	if placed == null:
		return { "ok": false, "message": "That is gone" }
	var blocker := build_blocker(placed.def_id, to_tile, placed.id)
	if blocker != "":
		return { "ok": false, "message": "Can't move it here: %s" % blocker }
	_release_user(placed)
	world.move_object(object_id, to_tile)
	_reroute_blocked_walks()
	return { "ok": true, "message": "" }


## Takes down whatever is on the tile: the object if there is one, otherwise the floor.
func build_remove(tile: Vector2i) -> Dictionary:
	if not world.can_build_at(tile):
		return { "ok": false, "message": "Outside your land" }
	var placed := world.object_at(tile)
	if placed != null and not bool(placed.def().get("buildable", true)):
		return { "ok": false, "message": "The %s can't be taken down" % placed.display_name().to_lower() }
	if placed != null:
		_release_user(placed)
		household.coins += Economy.refund(Economy.object_cost(placed.def_id))
		world.remove_object(placed.id)
		_reroute_blocked_walks()
		return { "ok": true, "message": "" }
	var old_floor := world.floor_at(tile)
	if world.set_floor(tile, ""):
		household.coins += Economy.refund(Economy.floor_cost(old_floor))
		return { "ok": true, "message": "" }
	return { "ok": false, "message": "" }  # nothing there; not worth a message


func build_floor(floor_id: String, tile: Vector2i) -> Dictionary:
	if not DataRegistry.has_def("floors", floor_id):
		return { "ok": false, "message": "That floor doesn't exist" }
	if not world.can_build_at(tile):
		return { "ok": false, "message": "Can't build here: outside your land" }
	if not world.is_ground_walkable(tile.x, tile.y):
		return { "ok": false, "message": "Can't build here: not solid ground" }
	var cost := Economy.floor_cost(floor_id)
	if cost > household.coins:
		return { "ok": false, "message": "Can't build here: it costs %s and you have %s" % [Economy.format(cost), Economy.format(household.coins)] }
	var old_floor := world.floor_at(tile)
	if not world.set_floor(tile, floor_id):
		return { "ok": false, "message": "" }
	household.coins += Economy.refund(Economy.floor_cost(old_floor)) - cost
	return { "ok": true, "message": "" }


## Whoever is using or heading for an object stops before it goes away or moves.
func _release_user(placed: PlacedObject) -> void:
	var user := person(placed.user_id) if placed.user_id != 0 else null
	if user != null:
		if user.job_stage == "walking":
			user.path.clear()  # they were on their way there; no point finishing the walk
		_end_job(user)
	placed.user_id = 0


## After a wall goes up, anyone whose planned route now runs into it finds another way
## to the same goal (or gives up if there is none).
func _reroute_blocked_walks() -> void:
	for pawn in people():
		var blocked := false
		for cell in pawn.path:
			blocked = blocked or not world.is_walkable(cell.x, cell.y)
		if not blocked:
			continue
		var goal := pawn.goal_tile()
		var route := pathfinder.find_path(pawn.committed_tile(), goal)
		if route.is_empty():
			pawn.path.clear()
			if pawn.job_kind != "":
				_end_job(pawn)
		else:
			pawn.path = route


## A short description of what a person is doing, for the interface.
func describe_activity(pawn: Pawn) -> String:
	var text := "Idle"
	var placed := world.get_object(pawn.job_object) if pawn.job_kind == "use" else null
	var partner := person(pawn.job_partner) if pawn.job_kind == "interact" else null
	if pawn.job_kind == "work":
		var job_name := str(DataRegistry.get_def("jobs", pawn.work_job).get("name", "work")).to_lower()
		text = "Working as a %s" % job_name if pawn.job_stage == "using" else "Heading to work"
	elif partner != null:
		var interaction := DataRegistry.get_def("interactions", pawn.job_interaction)
		if pawn.pose == "close":
			text = str(interaction.get("doing", "Busy"))
		elif pawn.job_stage == "partner":
			text = "Waiting for %s" % _first_name(partner)
		else:
			text = "Going to %s" % _first_name(partner)
	elif placed != null and pawn.job_stage == "using":
		text = str(placed.def().get("doing", "Busy"))
	elif placed != null:
		text = "Heading to the %s" % placed.display_name().to_lower()
	elif pawn.has_orders():
		text = "Walking"
	if pawn.slowed:
		text += " (exhausted)"
	if pawn.illness != "":
		text = "%s (%s)" % [text, str(Illness.def(pawn.illness).get("name", "ill")).to_lower()]
	return text


# --- needs and jobs --------------------------------------------------------------

## The season's multipliers on need drain, with those of any event going on multiplied in.
func _season_multipliers() -> Dictionary:
	var season_id := str(GameClock.get_date().get("season_id", ""))
	var multipliers: Dictionary = DataRegistry.get_def("seasons", season_id).get("need_drain_multipliers", {}).duplicate()
	var from_events := events.drain_multipliers()
	for need_id in from_events:
		multipliers[need_id] = float(multipliers.get(need_id, 1.0)) * float(from_events[need_id])
	return multipliers


## What the events going on do to people who are in the place that draws them: fill needs, give
## a thought. Called every EVENT_EVERY minutes.
func _apply_events(everyone: Array[Pawn]) -> void:
	for def in events.active_defs():
		var rect := _gather_rect(def)
		if rect.size == Vector2i.ZERO:
			continue
		for pawn in everyone:
			if not rect.has_point(pawn.tile):
				continue
			var restore: Dictionary = def.get("restore", {})
			for need_id in restore:
				if pawn.needs.has(need_id):
					pawn.needs[need_id] = minf(Needs.FULL, float(pawn.needs[need_id]) + float(restore[need_id]) * EVENT_EVERY / 60.0)
			if def.has("thought"):
				Mood.add_event(pawn, str(def["thought"]), GameClock.tick)


## The lot an event draws people to ("gather": a kind of building), or an empty rect.
func _gather_rect(def: Dictionary) -> Rect2i:
	var kind := str(def.get("gather", ""))
	if kind != "":
		for entry in world.lots:
			if str(entry["kind"]) == kind:
				return entry["rect"]
	return Rect2i()


## What using this object costs right now: its price, changed by any event (market day).
func price_of(def_id: String) -> int:
	var base := Economy.price(def_id)
	if base <= 0:
		return 0
	return maxi(1, roundi(base * events.price_multiplier(def_id)))


## Fades old thoughts and works out mood. A miserable person drags their feet, like one with an
## empty need.
func _update_mood(pawn: Pawn, everyone: Array[Pawn]) -> void:
	var now := GameClock.tick
	Mood.prune(pawn, now)
	var result := Mood.evaluate(pawn, everyone, now)
	pawn.mood = result["value"]
	pawn.mood_parts = result["parts"]
	if pawn.mood < Mood.LOW_BELOW:
		pawn.slowed = true


## Drains the needs a little. Returns what killed the person ("starved"...) or "".
func _drain_needs(pawn: Pawn, season_multipliers: Dictionary) -> String:
	var empty := false
	var cause := ""
	for need_id in active_needs:
		var value := float(pawn.needs.get(need_id, Needs.FULL))
		value = maxf(0.0, value - Needs.drain_per_tick(need_id, pawn.traits, season_multipliers))
		pawn.needs[need_id] = value
		if value <= 0.0 and Needs.slows_when_empty(need_id):
			empty = true
		var limit := Needs.fatal_after_hours(need_id)
		if limit > 0.0:
			if value <= 0.0:
				pawn.deprivation[need_id] = int(pawn.deprivation.get(need_id, 0)) + 1
				if pawn.deprivation[need_id] >= limit * 60.0:
					cause = str(DataRegistry.get_def("needs", need_id).get("death_cause", "died"))
			elif pawn.deprivation.has(need_id):
				pawn.deprivation.erase(need_id)  # relief: the clock starts over
	pawn.slowed = empty
	return cause


## Someone dies: whatever they were doing stops, a grave is left where they fell, and control
## passes to the next person in the household. With nobody left the playthrough is over.
func die(pawn: Pawn, cause: String) -> void:
	_end_job(pawn)
	pawn.path.clear()
	var spot := pawn.committed_tile()
	if household.get_pawn(pawn.id) == null:  # someone from the town
		town.dead.append({ "name": pawn.display_name, "cause": cause, "day": GameClock.get_day_number() })
		town.remove_pawn(pawn.id)
		_place_grave(spot)
		town_death.emit(pawn.display_name, cause)
		return
	household.dead.append({ "name": pawn.display_name, "cause": cause, "day": GameClock.get_day_number() })
	household.remove_pawn(pawn.id)
	for survivor in household.pawns:
		Mood.add_event(survivor, "death", GameClock.tick)
	_place_grave(spot)
	var successor := household.selected()
	pawn_died.emit(pawn.display_name, cause, successor.display_name if successor != null else "")
	for notice in realm.on_death(self, pawn):
		realm_notice.emit(notice)


func is_game_over() -> bool:
	return household.pawns.is_empty()


## What a customer pays for using something on the player's business lot goes into the household
## purse, and counts toward the trade tax.
func _credit_owner(payer: Pawn, placed: PlacedObject, price: int) -> void:
	if price <= 0 or household.get_pawn(payer.id) != null:
		return
	var lot_id := str(world.lot_at(placed.tile).get("id", ""))
	if lot_id != WorldState.HOME_LOT and world.titles.has(lot_id):
		household.coins += price
		realm.takings += price


## The tax collector takes something away: whoever was using it stops.
func seize(placed: PlacedObject) -> void:
	_release_user(placed)
	world.remove_object(placed.id)
	_reroute_blocked_walks()


func _place_grave(spot: Vector2i) -> void:
	if not DataRegistry.has_def("objects", "grave"):
		return
	for radius in 3:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) == radius and world.add_object("grave", spot + Vector2i(dx, dy)) != null:
					return


func _step_job(pawn: Pawn) -> void:
	if pawn.job_kind == "interact":
		_step_interaction(pawn)
		return
	if pawn.job_kind == "work":
		_step_work(pawn)
		return
	if pawn.job_kind != "use":
		return
	var placed := world.get_object(pawn.job_object)
	if placed == null:
		_end_job(pawn)
		return
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		if pawn.tile != pawn.job_tile:
			_end_job(pawn)  # the route was blocked or cancelled
			return
		var price := price_of(placed.def_id)
		if price > 0 and not spend(pawn, price):
			_end_job(pawn)  # somebody spent the money on the way
			return
		_credit_owner(pawn, placed, price)
		pawn.job_stage = "using"
		pawn.job_minutes = 0
		pawn.pose = str(placed.def().get("pose", ""))
		if placed.tile != pawn.tile:
			pawn.facing = placed.tile - pawn.tile
		return
	# Using it: refill the needs it satisfies until they are all full or time is up.
	var object_def := placed.def()
	var satisfies: Dictionary = object_def.get("satisfies", {})
	var all_full := true
	for need_id in satisfies:
		if not pawn.needs.has(need_id):
			continue
		var value := minf(Needs.FULL, float(pawn.needs[need_id]) + float(satisfies[need_id]) / 60.0)
		pawn.needs[need_id] = value
		if value < Needs.FULL:
			all_full = false
	pawn.job_minutes += 1
	if pawn.illness != "" and pawn.illness in object_def.get("cures", []) and pawn.job_minutes >= int(object_def.get("cure_minutes", 60)):
		_recover(pawn)
		Mood.add_event(pawn, "treated", GameClock.tick)
	if all_full or pawn.job_minutes >= int(object_def.get("max_use_minutes", 60)):
		Mood.add_event(pawn, "used:%s" % placed.def_id, GameClock.tick)
		_end_job(pawn)


## Walk up to the other person, then spend time together; the one who asked drives it for both.
func _step_interaction(pawn: Pawn) -> void:
	var partner := person(pawn.job_partner)
	var interaction := DataRegistry.get_def("interactions", pawn.job_interaction)
	if partner == null or interaction.is_empty() or partner.job_kind != "interact" or partner.job_partner != pawn.id:
		_end_job(pawn)
		return
	if pawn.job_stage == "partner":
		return  # waiting; the other person decides when it starts and ends
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		if _distance(pawn.tile, partner.tile) != 1:
			_end_job(pawn)  # the route was blocked or cancelled
			return
		pawn.job_stage = "using"
		pawn.job_minutes = 0
		pawn.pose = str(interaction.get("pose", "close"))
		partner.pose = pawn.pose
		pawn.facing = partner.tile - pawn.tile
		partner.facing = pawn.tile - partner.tile
		return
	var satisfies: Dictionary = interaction.get("satisfies", {})
	var all_full := true
	for who in [pawn, partner]:
		for need_id in satisfies:
			if not who.needs.has(need_id):
				continue
			var value := minf(Needs.FULL, float(who.needs[need_id]) + float(satisfies[need_id]) / 60.0)
			who.needs[need_id] = value
			if value < Needs.FULL:
				all_full = false
	pawn.job_minutes += 1
	if all_full or pawn.job_minutes >= int(interaction.get("max_use_minutes", 30)):
		_finish_interaction(pawn, partner, interaction)
		_end_job(pawn)


## An interaction ran its course: both people think about it, and their opinions of each other
## change (a joke can fall flat, which only the one who told it minds).
func _finish_interaction(pawn: Pawn, partner: Pawn, interaction: Dictionary) -> void:
	var rule: Dictionary = interaction.get("opinion", {})
	var delta := float(rule.get("gain", 0.0))
	var flopped := rule.has("backfire") and _rng.randf() < float(rule["backfire"])
	if flopped:
		delta = -float(rule.get("loss", 0.0))
		Mood.add_event(pawn, "flop", GameClock.tick)
	else:
		Mood.add_event(pawn, "interaction:%s" % pawn.job_interaction, GameClock.tick)
		Mood.add_event(partner, "interaction:%s" % pawn.job_interaction, GameClock.tick)
	pawn.add_opinion(partner.id, delta)
	partner.add_opinion(pawn.id, delta)


## Lines for the panel: who `pawn` knows best (or least well), as { "name", "label", "opinion" }.
func relationship_lines(pawn: Pawn, limit: int = 5) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for other_id in pawn.relations:
		var other := person(int(other_id))
		if other != null and absf(float(pawn.relations[other_id])) >= 5.0:
			lines.append({ "name": other.display_name, "label": Relations.label(float(pawn.relations[other_id])), "opinion": float(pawn.relations[other_id]) })
	lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(a["opinion"]) > absf(b["opinion"]))
	return lines.slice(0, limit)


func _end_job(pawn: Pawn) -> void:
	if pawn.job_kind == "work":
		if pawn.job_stage == "using":
			_pay_shift(pawn)
		else:
			pawn.path.clear()  # still on the way to work: the walk is off too
	var placed := world.get_object(pawn.job_object)
	if placed != null and placed.user_id == pawn.id:
		placed.user_id = 0
	var partner: Pawn = person(pawn.job_partner) if pawn.job_kind == "interact" else null
	pawn.job_kind = ""
	pawn.job_object = 0
	pawn.job_stage = ""
	pawn.job_minutes = 0
	pawn.job_partner = 0
	pawn.job_interaction = ""
	pawn.pose = ""
	# An interaction has two people: when one stops, so does the other.
	if partner != null and partner.job_kind == "interact" and partner.job_partner == pawn.id:
		_end_job(partner)


## Finds where to stand and how to get there. { "tile", "route" }, or empty if unreachable.
func _plan_use(pawn: Pawn, placed: PlacedObject) -> Dictionary:
	var candidates: Array[Vector2i] = []
	if str(placed.def().get("use_position", "beside")) == "on":
		candidates.append(placed.tile)
	else:
		for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			candidates.append(placed.tile + step)
	return _plan_best(pawn, candidates)


## Where to stand next to a person (or any tile), and how to get there. { "tile", "route" }, or empty.
func _plan_beside(pawn: Pawn, target: Vector2i) -> Dictionary:
	var candidates: Array[Vector2i] = []
	for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		candidates.append(target + step)
	return _plan_best(pawn, candidates)


func _plan_best(pawn: Pawn, candidates: Array[Vector2i]) -> Dictionary:
	var origin := pawn.committed_tile()
	var best := {}
	for candidate in candidates:
		if not world.is_walkable(candidate.x, candidate.y):
			continue
		var route: Array[Vector2i] = []
		if candidate != origin:
			route = pathfinder.find_path(origin, candidate)
			if route.is_empty():
				continue
		if best.is_empty() or route.size() < best["route"].size():
			best = { "tile": candidate, "route": route }
	return best


func _first_name(pawn: Pawn) -> String:
	return pawn.display_name.get_slice(" ", 0)


## An idle person with a low need goes to the nearest free thing that fills it.
func _think(pawn: Pawn, minute: int) -> bool:
	if pawn.illness != "" and _seek_treatment(pawn):
		return true
	var wants: Array = []
	for need_id in active_needs:
		var value := float(pawn.needs.get(need_id, Needs.FULL))
		if value < Needs.seek_below(need_id, minute):
			wants.append([value, need_id])
	if wants.is_empty():
		return false
	wants.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for want in wants:
		if str(want[1]) == "social":
			if _seek_company(pawn):
				return true
			continue
		var options: Array[PlacedObject] = []
		for placed in world.objects:
			if placed.user_id == 0 and placed.def().get("satisfies", {}).has(want[1]) and _may_use(pawn, placed) \
					and price_of(placed.def_id) <= coins_of(pawn):
				options.append(placed)
		options.sort_custom(func(a: PlacedObject, b: PlacedObject) -> bool:
			return _effort(pawn, a) < _effort(pawn, b))
		for placed in options.slice(0, OPTIONS_PER_NEED):
			if order_use(pawn, placed)["ok"]:
				return true
	pawn.think_cooldown = THINK_COOLDOWN_TICKS  # nothing within reach; try again later
	return false


## Someone ill with the means goes to the nearest free thing that cures them (a sickbed).
func _seek_treatment(pawn: Pawn) -> bool:
	var options: Array[PlacedObject] = []
	for placed in world.objects:
		if placed.user_id == 0 and pawn.illness in placed.def().get("cures", []) and _may_use(pawn, placed) \
				and price_of(placed.def_id) <= coins_of(pawn):
			options.append(placed)
	options.sort_custom(func(a: PlacedObject, b: PlacedObject) -> bool:
		return _effort(pawn, a) < _effort(pawn, b))
	for placed in options.slice(0, OPTIONS_PER_NEED):
		if order_use(pawn, placed)["ok"]:
			return true
	return false


## Midnight: the healthy may fall ill, the ill may recover, and an illness that has gone on too
## long kills.
func _roll_illness(everyone: Array[Pawn]) -> void:
	var season_id := str(GameClock.get_date().get("season_id", ""))
	var event_factor := events.illness_multiplier()
	for pawn in everyone:
		if pawn.illness != "":
			var current := Illness.def(pawn.illness)
			var days_ill := (GameClock.tick - pawn.ill_since) / GameClock.MINUTES_PER_DAY
			if current.is_empty() or _rng.randf() < Illness.recovery_chance(current, pawn):
				_recover(pawn)
			elif days_ill >= int(current.get("fatal_after_days", 9999)):
				die(pawn, str(current.get("death_cause", "died")))
			continue
		for illness in DataRegistry.get_list("illness"):
			if _rng.randf() < Illness.catch_chance(illness, pawn, season_id, event_factor):
				pawn.illness = str(illness["id"])
				pawn.ill_since = GameClock.tick
				if household.get_pawn(pawn.id) != null:
					health_notice.emit("%s %s." % [pawn.display_name, str(illness.get("caught", "is ill"))])
				break


func _recover(pawn: Pawn) -> void:
	pawn.illness = ""
	if household.get_pawn(pawn.id) != null:
		health_notice.emit("%s is well again." % pawn.display_name)


## A lonely person walks up to someone nearby for a chat (any interaction marked "autonomous" in
## data/interactions.json that fills Social). People from the town only talk to each other; the
## household's people will talk to anyone, so they meet the neighbors. Prefers the closest, and
## the better liked.
func _seek_company(pawn: Pawn) -> bool:
	var candidates: Array[Pawn] = []
	for other in (town.pawns if town.get_pawn(pawn.id) != null else people()):
		if other.id != pawn.id and _distance(pawn.tile, other.tile) <= SOCIAL_RADIUS and not other.is_busy():
			candidates.append(other)
	candidates.sort_custom(func(a: Pawn, b: Pawn) -> bool:
		return _distance(pawn.tile, a.tile) - 0.3 * pawn.opinion_of(a.id) < _distance(pawn.tile, b.tile) - 0.3 * pawn.opinion_of(b.id))
	for interaction in DataRegistry.get_list("interactions"):
		if not bool(interaction.get("autonomous", false)) or not interaction.get("satisfies", {}).has("social"):
			continue
		for other in candidates.slice(0, 4):
			if interaction_blocker(pawn, other, str(interaction["id"])) == "" and order_interact(pawn, other, str(interaction["id"]))["ok"]:
				return true
	return false


## Whether the thing stands on land `pawn` may use it on: their own lot, a public lot or open land.
func _may_use(pawn: Pawn, placed: PlacedObject) -> bool:
	var lot := world.lot_at(placed.tile)
	return lot.is_empty() or bool(lot["public"]) or str(lot["id"]) == pawn.home_lot


## A townsperson with nothing to do sometimes takes a walk by day: to a public place, along the
## road, or round their own lot.
func _roam(pawn: Pawn, minute: int) -> void:
	for def in events.active_defs():  # a festival or a market draws a crowd, whatever the hour
		var crowd := _gather_rect(def)
		if crowd.size != Vector2i.ZERO and not crowd.has_point(pawn.tile) and _rng.randf() < GATHER_CHANCE:
			var spot := crowd.position + Vector2i(_rng.randi() % crowd.size.x, _rng.randi() % crowd.size.y)
			if world.is_walkable(spot.x, spot.y) and world.object_at(spot) == null:
				order_move(pawn, spot)
				return
	if minute < ROAM_FROM_MINUTE or minute >= ROAM_UNTIL_MINUTE or _rng.randf() > ROAM_CHANCE:
		return
	var rect := Rect2i()
	var roll := _rng.randf()
	if roll < 0.5:
		var public_lots: Array[Dictionary] = []
		for entry in world.lots:
			if bool(entry["public"]):
				public_lots.append(entry)
		if not public_lots.is_empty():
			rect = public_lots[_rng.randi() % public_lots.size()]["rect"]
	elif roll < 0.8:
		var center := Vector2i(world.width / 2, world.height / 2)
		rect = Rect2i(center - Vector2i(ROAM_RADIUS, 1), Vector2i(ROAM_RADIUS * 2 + 1, 3))
	else:
		rect = world.get_lot(pawn.home_lot).get("rect", Rect2i())
	if rect.size == Vector2i.ZERO:
		return
	for attempt in 6:
		var goal := rect.position + Vector2i(_rng.randi() % rect.size.x, _rng.randi() % rect.size.y)
		if world.is_walkable(goal.x, goal.y) and goal != pawn.tile and world.object_at(goal) == null:
			order_move(pawn, goal)
			return


## How much trouble an object is to use: how far away, and a little more if it costs money, so
## that free things at home win over a paid meal when both are near.
func _effort(pawn: Pawn, placed: PlacedObject) -> int:
	return _distance(pawn.tile, placed.tile) + (12 if price_of(placed.def_id) > 0 and coins_of(pawn) < RICH_COINS else 0)


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## A loaded save may predate needs or objects, or name things that are gone: make it consistent.
func _repair_after_load() -> void:
	if household.get_pawn(realm.head_id) == null:
		realm.choose_head(household)
	var anyone_knows_anyone := false
	for pawn in people():
		anyone_knows_anyone = anyone_knows_anyone or not pawn.relations.is_empty()
	if not anyone_knows_anyone:  # a save from before opinions: families start out fond of each other
		var homes := {}
		for pawn in people():
			if not homes.has(pawn.home_lot):
				homes[pawn.home_lot] = [] as Array[Pawn]
			homes[pawn.home_lot].append(pawn)
		for members in homes.values():
			Relations.make_family(members)
	for pawn in people():
		for need_id in active_needs:
			if not pawn.needs.has(need_id):
				pawn.needs[need_id] = 80.0
		if pawn.job_kind == "use":
			var placed := world.get_object(pawn.job_object)
			if placed == null or (placed.user_id != 0 and placed.user_id != pawn.id):
				pawn.job_kind = ""
				pawn.job_object = 0
				pawn.job_stage = ""
				pawn.pose = ""
			else:
				placed.user_id = pawn.id
		elif pawn.job_kind == "work":
			if DataRegistry.get_def("jobs", pawn.work_job).is_empty() or world.get_lot(pawn.work_lot).is_empty():
				pawn.job_minutes = 0
				_end_job(pawn)
				pawn.work_lot = ""
				pawn.work_job = ""
		elif pawn.job_kind == "interact":
			var partner := person(pawn.job_partner)
			if partner == null or partner.job_kind != "interact" or partner.job_partner != pawn.id \
					or not DataRegistry.has_def("interactions", pawn.job_interaction):
				_end_job(pawn)
	for placed in world.objects:
		var user := person(placed.user_id)
		if user == null or user.job_object != placed.id:
			placed.user_id = 0
