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
const NEED_REACH := 70            # how far someone goes to fill a need that is not pressing, tiles
const NEED_DESPERATE := 20.0      # below this a need is pressing and no distance is too far
const SOCIAL_RADIUS := 50         # how far someone lonely will go to find a person to talk to (towns are big)
const GATHER_CHANCE := 0.04       # per minute, for an idle townsperson while an event draws a crowd
const EVENT_EVERY := 10           # minutes between giving event thoughts and company
const WORK_BREAK_BELOW := 15.0    # a need this low sends a worker off their shift to see to it
const MOOD_EVERY := 5             # minutes between mood checks for townspeople
const VISIT_CHANCE := 0.04   # of the walks to a public place, how many go to another settlement
const ROAM_CHANCE := 0.012        # per minute, for an idle townsperson in the daytime
const ROAM_FROM_MINUTE := 7 * 60
const ROAM_UNTIL_MINUTE := 20 * 60
const RICH_COINS := 100           # someone with this much does not mind paying for a meal out
const ROAM_RADIUS := 14           # how far from the crossroads they wander along the roads
const GRAVEYARD_REACH := 4        # the chapel yard runs this many tiles round the chapel's lot
const GRAVE_SEARCH := 10          # how far from where someone fell to look for open ground

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
## Something happened that has a sound (see SoundBank): its id and where, or (-1, -1) for a sound the
## player should hear wherever the camera is (a chime, a coin).
signal sound_made(sound_id: String, tile: Vector2i)
## The player took up another family of the town, or moved house (see Families); `name` is the family's.
signal family_changed(name: String)
## Who is in the household changed without a death: a baby was born, or grew old enough to be controlled.
signal household_changed
## Babies were born into your household (their ids): the view may ask what to call them.
signal babies_born(ids: Array[int])
## Ids of the needs in play; see Needs.
var active_needs: Array[String] = []
var _announced := {}  # contagious illnesses the player has been told about
var _fillers_by_need := {}  # need id -> the objects that can fill it
var _fillers_dirty := true
var _object_kinds := {}  # def id -> true for every kind of object standing in the world
var _object_kinds_dirty := true
var _wish_every := 40    # how often (minutes) an idle person with a wish looks into acting on it
var _wish_from := 420    # and between which minutes of the day
var _wish_until := 1260
var _wish_reach := 36    # how far they will go for it
var _wish_retry := 90    # and how long they leave a wish alone after nothing came of it
var _has_infants := true  # whether anyone is a baby, worked out each minute; babies are carried along as people walk
## The dead Death has just led away, for the view to show their going: { "tile", "tick", "name",
## "death_at" (where Death stood, in tiles, or null) }. Kept an hour or so, never saved.
var departures: Array[Dictionary] = []


var _rng := RandomNumberGenerator.new()  # for townspeople's wandering (not part of the world seed's output)


func _init(p_world: WorldState, p_household: Household, p_town: Household = null, p_realm: Realm = null) -> void:
	world = p_world
	household = p_household
	if p_realm != null:
		realm = p_realm
	town = p_town if p_town != null else Household.new(NpcGenerator.FIRST_ID)
	_rng.seed = world.world_seed + 4242
	pathfinder = PathFinder.new(world)
	world.tile_changed.connect(_on_world_changed)
	active_needs = Needs.active_ids()
	_repair_after_load()
	var dreams := Ambitions.rules()
	_wish_every = maxi(1, int(dreams.get("pursue_every", _wish_every)))
	_wish_from = int(dreams.get("pursue_from_minute", _wish_from))
	_wish_until = int(dreams.get("pursue_until_minute", _wish_until))
	_wish_reach = int(dreams.get("pursue_reach", _wish_reach))
	_wish_retry = int(dreams.get("pursue_retry", _wish_retry))
	Ambitions.start(self)


## People take their steps (a fraction of a game minute: see GameClock.SUBSTEPS_PER_MINUTE). The
## clock's `motion_ticked` signal calls this; thinking, needs and everything else wait for `step`.
func step_motion() -> void:
	for pawn in household.pawns:
		if (pawn.step_ticks_total > 0 or not pawn.path.is_empty()) and not pawn.is_infant() and not pawn.is_dying():
			pawn.tick(world)
	for pawn in town.pawns:
		if (pawn.step_ticks_total > 0 or not pawn.path.is_empty()) and not pawn.is_infant() and not pawn.is_dying():
			pawn.tick(world)
	if _has_infants:
		Pregnancy.carry_infants(self)
	Fauna.step_motion(self)
	Caravans.step_motion(self)


## One game minute passes. Called from the clock's `ticked` signal. `motion_steps` is how many
## motion steps to take first: the live game takes them as the clock hands them out, so it passes
## 0; a test or tool stepping by hand gets one, so a person moves a little with each minute.
func step(motion_steps: int = 1) -> void:
	for i in motion_steps:
		step_motion()
	for change in events.update(world.world_seed):
		var event_def := DataRegistry.get_def("events", str(change["id"]))
		var event_name := str(event_def.get("name", change["id"]))
		if change["kind"] == "started":
			event_started.emit(event_name, str(event_def.get("announce", event_name)))
		else:
			event_ended.emit(event_name)
	var season_multipliers := _season_multipliers()
	var minute := GameClock.get_minute_of_day()
	_has_infants = false
	for pawn in household.pawns:
		_has_infants = _has_infants or pawn.is_infant()
	for pawn in town.pawns:
		_has_infants = _has_infants or pawn.is_infant()
	Pregnancy.carry_infants(self)
	Mortality.step(self)
	for notice in Pregnancy.step(self, _rng):
		health_notice.emit(notice)
	for notice in Babies.step(self):
		health_notice.emit(notice)
	for notice in Fire.step(self, _rng):
		health_notice.emit(notice)
	Fauna.step(self, _rng)
	Caravans.step(self, _rng)
	if minute % 10 == 0:
		for caught in Illness.spread(self, _rng, 10):
			_announce_illness(caught)
	if not world.fires.is_empty():
		for pawn in people():
			_react_to_fire(pawn)
	var everyone := people()
	if minute == 0:
		Relations.drift(everyone)
		for notice in Life.new_day(self, _rng):
			health_notice.emit(notice)
		for notice in Pregnancy.new_day(self, _rng):
			health_notice.emit(notice)
		for notice in Romance.new_day(self, _rng):
			health_notice.emit(notice)
		Skills.find_work(self, _rng)
		Ambitions.new_day(self)
		for notice in Families.new_day(self):
			health_notice.emit(notice)
		for notice in Fauna.new_day(self, _rng):
			health_notice.emit(notice)
		Caravans.new_day(self, _rng)
		for notice in realm.new_day(self):
			realm_notice.emit(notice)
		_roll_illness(everyone)
	if minute % EVENT_EVERY == 0:
		_apply_events(everyone)
	for pawn in everyone:
		if pawn.is_infant() or pawn.is_dying():
			continue  # carried by the household, or lying still until Death comes
		var cause := _drain_needs(pawn, Clothing.drain_multipliers(self, pawn, Shelter.drain_multipliers(world, pawn, Life.drain_multipliers(pawn, Pregnancy.drain_multipliers(pawn, Illness.drain_multipliers(pawn, season_multipliers))))))
		if cause != "":
			Mortality.fall(self, pawn, cause)
			continue
		if household.get_pawn(pawn.id) != null or (GameClock.tick + pawn.id) % MOOD_EVERY == 0:
			_update_mood(pawn, everyone)  # the town's mood changes slowly, so it is looked at less often
		if (GameClock.tick + pawn.id) % 10 == 0:
			Ambitions.step(self, pawn)
		_step_job(pawn)
		if pawn.think_cooldown > 0:
			pawn.think_cooldown -= 1
		elif not pawn.is_busy():
			if not _think(pawn, minute) and not _try_work(pawn, minute) and not _pursue_wish(pawn, minute) and town.get_pawn(pawn.id) != null:
				_roam(pawn, minute)
	for pawn in household.pawns:  # wishes granted, ambitions furthered
		if not pawn.news.is_empty():
			for line in pawn.news:
				health_notice.emit(line)
			pawn.news.clear()
			sound_made.emit("chime", Vector2i(-1, -1))


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

## The random numbers for things that need not follow from the world seed (wandering, pleas).
func rng() -> RandomNumberGenerator:
	return _rng


## Sends a pawn to a tile. Returns { "ok": bool, "message": String }; the message
## says why not when the order cannot be carried out.
func order_move(pawn: Pawn, target: Vector2i) -> Dictionary:
	if pawn.is_dying():
		return { "ok": false, "message": "%s is dying" % _first_name(pawn) }
	if Pregnancy.in_labour(pawn):
		return { "ok": false, "message": "%s is in labour" % _first_name(pawn) }
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
	if pawn.is_dying():
		return "%s is dying" % _first_name(pawn)
	if Pregnancy.in_labour(pawn):
		return "%s is in labour" % _first_name(pawn)
	if placed.user_id != 0 and placed.user_id != pawn.id:
		var other := person(placed.user_id)
		return "%s is using it" % (_first_name(other) if other != null else "someone")
	var lot := world.lot_at(placed.tile)
	if not lot.is_empty() and not bool(lot["public"]) and str(lot["id"]) != pawn.home_lot:
		return "it belongs to someone else"
	var price := price_of(placed.def_id)
	if price > coins_of(pawn):
		return "can't afford it (%s)" % Economy.format(price)
	var gather := gather_blocker(pawn, placed)
	if gather != "":
		return gather
	var tool_issue := Skills.tool_blocker(self, pawn, placed.def())
	if tool_issue != "":
		return tool_issue
	if _plan_use(pawn, placed).is_empty():
		return "can't get there"
	return ""


## Why `pawn` cannot gather from `placed` now (a chopping block, a field...), or "".
func gather_blocker(pawn: Pawn, placed: PlacedObject) -> String:
	var def := placed.def()
	if not def.has("gathers"):
		return ""
	if household.get_pawn(pawn.id) == null:
		return "only your own folk gather for the household"
	if bool(def.get("heavy", false)) and not Life.may_do_heavy_work(pawn):
		return "too heavy for %s" % _first_name(pawn)
	if pawn.age < 12:
		return "too young"
	var seasons: Array = def.get("gather_seasons", [])
	if not seasons.is_empty():
		var now := str(GameClock.get_date().get("season_id", ""))
		if now not in seasons:
			var names: Array[String] = []
			for season_id in seasons:
				names.append(str(DataRegistry.get_def("seasons", str(season_id)).get("name", season_id)).to_lower())
			return "nothing to gather until %s" % " or ".join(names)
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


## Why `pawn` cannot make `recipe` at `placed` (a forge, a workbench) now, or "".
func craft_blocker(pawn: Pawn, placed: PlacedObject, recipe: Dictionary) -> String:
	if recipe.is_empty() or str(recipe.get("station", "")) != placed.def_id:
		return "that can't be made here"
	if household.get_pawn(pawn.id) == null:
		return "only your own folk make things for the household"
	if bool(placed.def().get("heavy", false)) and not Life.may_do_heavy_work(pawn):
		return "too heavy for %s" % _first_name(pawn)
	if pawn.age < 12:
		return "too young"
	var recipe_issue := Skills.recipe_blocker(self, pawn, recipe)
	if recipe_issue != "":
		return recipe_issue
	return use_blocker(pawn, placed)


## Sends a pawn to make something at a forge or bench: walk there, then work until it is done.
func order_craft(pawn: Pawn, placed: PlacedObject, recipe_id: String) -> Dictionary:
	var recipe := DataRegistry.get_def("recipes", recipe_id)
	var blocker := craft_blocker(pawn, placed, recipe)
	if blocker != "":
		return { "ok": false, "message": "Can't make that: %s" % blocker }
	var result := order_use(pawn, placed)
	if result["ok"]:
		pawn.job_recipe = recipe_id
	return result


## Buys a tool from a shop's rack, or a stocked good (a ring) from its counter, with the household's money.
func buy_item(pawn: Pawn, item_id: String) -> Dictionary:
	var price := Economy.shop_price(item_id)
	if household.get_pawn(pawn.id) == null or price <= 0:
		return { "ok": false, "message": "Can't buy that" }
	if price > coins_of(pawn):
		return { "ok": false, "message": "Can't afford it (%s)" % Economy.format(price) }
	spend(pawn, price)
	household.add_stock(item_id, 1)
	sound_made.emit("coin", Vector2i(-1, -1))
	return { "ok": true, "message": "%s bought %s for %s." % [_first_name(pawn), Economy.item_phrase(item_id), Economy.format(price)] }


## Why `pawn` cannot do the interaction with `other` right now, or "" if they can. Both people
## must be willing: that is how consent works here. Someone who isn't in the mood says no,
## and the menu shows the entry switched off with that reason.
## `eager` is for a person acting on a wish: they do not wait to be in the mood.
func interaction_blocker(pawn: Pawn, other: Pawn, interaction_id: String, eager: bool = false) -> String:
	var interaction := DataRegistry.get_def("interactions", interaction_id)
	if interaction.is_empty() or pawn.id == other.id:
		return "not possible"
	var other_name := _first_name(other)
	if pawn.is_infant() or other.is_infant():
		return "a baby cannot"
	if pawn.is_dying() or other.is_dying():
		return "%s is dying" % (_first_name(pawn) if pawn.is_dying() else other_name)
	if Pregnancy.in_labour(pawn) or Pregnancy.in_labour(other):
		return "%s is in labour" % (_first_name(pawn) if Pregnancy.in_labour(pawn) else other_name)
	if bool(interaction.get("adults_only", false)) and not (pawn.adult and other.adult):
		return "only adults can"
	if other.is_busy():
		return "%s is busy" % other_name
	if bool(interaction.get("requires_attraction", false)):
		if not _attracted_to(other, pawn):
			return "%s isn't interested" % other_name
		if not _attracted_to(pawn, other):
			return "%s isn't interested" % _first_name(pawn)
	if bool(interaction.get("lesson", false)):
		var lesson_issue := Skills.lesson_blocker(pawn, other)
		if lesson_issue != "":
			return lesson_issue
	if bool(interaction.get("romantic", false)):
		var romantic_blocker := _romance_blocker(pawn, other, interaction)
		if romantic_blocker != "":
			return romantic_blocker
	var min_opinion := float(interaction.get("min_opinion", -1000.0))
	if other.opinion_of(pawn.id) < min_opinion:
		return "%s isn't close enough to you yet" % other_name
	if pawn.opinion_of(other.id) < min_opinion:
		return "%s isn't close enough to %s yet" % [_first_name(pawn), other_name]
	var limits: Dictionary = {} if eager else interaction.get("willing_below", {})
	var unwilling := str(interaction.get("unwilling", "isn't willing"))
	for need_id in limits:
		if float(other.needs.get(need_id, 0.0)) >= float(limits[need_id]):
			return "%s %s" % [other_name, unwilling]
		if float(pawn.needs.get(need_id, 0.0)) >= float(limits[need_id]):
			return "%s %s" % [_first_name(pawn), unwilling]
	if _plan_beside(pawn, other.tile).is_empty():
		return "can't get there"
	return ""


## What stands in the way of a romantic interaction (flirting, a kiss, asking out): family, someone
## else's partner, or not being close enough yet. "" if nothing does.
func _romance_blocker(pawn: Pawn, other: Pawn, interaction: Dictionary) -> String:
	var other_name := _first_name(other)
	if Relations.are_kin(pawn, other):
		return "%s is family" % other_name
	if pawn.partner_id != 0 and pawn.partner_id != other.id:
		return "%s is already seeing someone" % _first_name(pawn)
	if other.partner_id != 0 and other.partner_id != pawn.id:
		return "%s is already seeing someone" % other_name
	if bool(interaction.get("begins_dating", false)) and Romance.together(pawn, other):
		return "already together"
	if bool(interaction.get("proposes", false)):
		var proposal := Romance.proposal_blocker(self, pawn, other)
		if proposal != "":
			return proposal
	var needed := float(interaction.get("min_romance", 0.0))
	if needed > 0.0:
		if other.romance_for(pawn.id) < needed:
			return "%s isn't ready for that" % other_name
		if pawn.romance_for(other.id) < needed:
			return "%s isn't ready for that yet" % _first_name(pawn)
	return ""


## Whether `person` is attracted to `other`, from an orientation trait ("attracted_to" in
## data/traits.json: opposite, same, both or none). Someone with no such trait is open to anyone.
func attracted(person: Pawn, other: Pawn) -> bool:
	return _attracted_to(person, other)


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
func order_interact(pawn: Pawn, other: Pawn, interaction_id: String, eager: bool = false) -> Dictionary:
	var blocker := interaction_blocker(pawn, other, interaction_id, eager)
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


## Sends `pawn` to kneel beside someone who is dying and plead with Death for them (see Mortality).
func order_plead(pawn: Pawn, dying: Pawn) -> Dictionary:
	var blocker := Mortality.plead_blocker(self, pawn, dying)
	if blocker != "":
		return { "ok": false, "message": "Can't plead now: %s" % blocker }
	var plan := _plan_beside(pawn, dying.tile)
	_end_job(pawn)
	pawn.path = plan["route"]
	pawn.job_kind = "plead"
	pawn.job_stage = "walking"
	pawn.job_tile = plan["tile"]
	pawn.job_partner = dying.id
	pawn.job_minutes = 0
	return { "ok": true, "message": "" }


func _step_plead(pawn: Pawn) -> void:
	var dying := person(pawn.job_partner)
	if dying == null or not dying.is_dying():
		_end_job(pawn)
		return
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		if _distance(pawn.tile, dying.tile) != 1:
			_end_job(pawn)  # the route was blocked or cancelled
			return
		pawn.job_stage = "using"
		pawn.job_minutes = 0
		pawn.pose = "talk"
		pawn.facing = dying.tile - pawn.tile
		return
	pawn.job_minutes += 1
	if pawn.job_minutes >= int(Mortality.config().get("plead_minutes", 30)):
		var message := Mortality.resolve_plea(self, pawn, dying, _rng)
		_end_job(pawn)
		if message != "" and (household.get_pawn(pawn.id) != null or household.get_pawn(dying.id) != null):
			health_notice.emit(message)


# --- birth and babies ---------------------------------------------------------------

## Labour has begun: she makes for the best bed she can, the clinic's sickbed if she can afford it
## and it is not much further, otherwise one of her own. With no bed to reach she lies down where
## she is. See Pregnancy.
func begin_labour(mother: Pawn) -> void:
	var choice: PlacedObject = null
	var best := INF
	for placed in world.objects:
		if not placed.def_id in ["bed", "sickbed"] or (placed.user_id != 0 and placed.user_id != mother.id):
			continue
		if not _may_use(mother, placed) or price_of(placed.def_id) > coins_of(mother):
			continue
		var plan := _plan_use(mother, placed)
		if plan.is_empty():
			continue
		var effort := float(plan["route"].size()) - (30.0 if placed.def_id == "sickbed" else 0.0)
		if effort < best:
			best = effort
			choice = placed
	order_labour(mother, choice)


## Sends `mother` to lie down in `bed` for the birth (or, with no bed, right where she is).
func order_labour(mother: Pawn, bed: PlacedObject) -> Dictionary:
	_end_job(mother)
	mother.path.clear()
	mother.job_kind = "labour"
	mother.job_minutes = 0
	if bed == null or _plan_use(mother, bed).is_empty():
		mother.job_stage = "using"
		mother.job_object = 0
		mother.pose = "lie"
		return { "ok": true, "message": "" }
	var plan := _plan_use(mother, bed)
	mother.path = plan["route"]
	mother.job_stage = "walking"
	mother.job_object = bed.id
	mother.job_tile = plan["tile"]
	bed.user_id = mother.id
	return { "ok": true, "message": "" }


## The birth is over: she gets up and whoever stayed with her goes about their day.
func end_labour(mother: Pawn) -> void:
	if mother.job_kind == "labour":
		_end_job(mother)
	for other in people():
		if other.job_kind == "attend" and other.job_partner == mother.id:
			_end_job(other)


func _step_labour(pawn: Pawn) -> void:
	if pawn.job_stage != "walking":
		return
	if pawn.is_moving() or not pawn.path.is_empty():
		return
	var bed := world.get_object(pawn.job_object)
	if bed != null and pawn.tile == pawn.job_tile:
		var price := price_of(bed.def_id)
		if price <= 0 or spend(pawn, price):
			_credit_owner(pawn, bed, price)
			pawn.job_stage = "using"
			pawn.pose = "lie"
			return
	if bed != null and bed.user_id == pawn.id:
		bed.user_id = 0
	pawn.job_object = 0  # the bed could not be had: she lies down where she is
	pawn.job_stage = "using"
	pawn.pose = "lie"


## Why `helper` cannot stay with `mother` through her labour, or "".
func attend_blocker(helper: Pawn, mother: Pawn) -> String:
	if not Pregnancy.in_labour(mother):
		return "%s is not in labour" % _first_name(mother)
	if helper.id == mother.id or helper.is_infant() or helper.is_dying() or not helper.adult:
		return "only a grown-up can"
	if _plan_beside(helper, mother.committed_tile()).is_empty():
		return "can't get there"
	return ""


## Sends `helper` to stay at `mother`'s side until the baby comes: a midwife makes a birth safer.
func order_attend(helper: Pawn, mother: Pawn) -> Dictionary:
	var blocker := attend_blocker(helper, mother)
	if blocker != "":
		return { "ok": false, "message": "Can't stay with her: %s" % blocker }
	var plan := _plan_beside(helper, mother.committed_tile())
	_end_job(helper)
	helper.path = plan["route"]
	helper.job_kind = "attend"
	helper.job_stage = "walking"
	helper.job_tile = plan["tile"]
	helper.job_partner = mother.id
	helper.job_minutes = 0
	return { "ok": true, "message": "" }


func _step_attend(pawn: Pawn) -> void:
	var mother := person(pawn.job_partner)
	if mother == null or not Pregnancy.in_labour(mother):
		_end_job(pawn)
		return
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		var spot := mother.committed_tile()
		if _distance(pawn.tile, spot) > 1:
			var plan := _plan_beside(pawn, spot)  # she has moved since: follow her
			if plan.is_empty():
				_end_job(pawn)
				return
			pawn.path = plan["route"]
			return
		pawn.job_stage = "using"
		pawn.pose = "talk"
		pawn.facing = spot - pawn.tile if spot != pawn.tile else pawn.facing
		return
	if _distance(pawn.tile, mother.committed_tile()) > 1:
		pawn.job_stage = "walking"  # she moved: catch up
		pawn.pose = ""


## Sends `carer` to see to one of a baby's needs (an id from "baby_care": fed, comfort, clean).
func order_tend(carer: Pawn, baby: Pawn, care_id: String) -> Dictionary:
	var blocker := Babies.tend_blocker(self, carer, baby)
	if blocker != "":
		return { "ok": false, "message": "Can't now: %s" % blocker }
	_end_job(carer)
	carer.job_kind = "tend"
	carer.job_partner = baby.id
	carer.job_interaction = care_id
	carer.job_minutes = 0
	if carer.tile == baby.tile or _distance(carer.tile, baby.tile) == 1:
		carer.path.clear()
		carer.job_stage = "using"
		carer.pose = "talk"
		return { "ok": true, "message": "" }
	var plan := _plan_beside(carer, baby.tile)
	carer.path = plan["route"]
	carer.job_stage = "walking"
	carer.job_tile = plan["tile"]
	return { "ok": true, "message": "" }


func _step_tend(pawn: Pawn) -> void:
	var baby := person(pawn.job_partner)
	if baby == null or not baby.is_infant():
		_end_job(pawn)
		return
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		if _distance(pawn.tile, baby.tile) > 1:
			_end_job(pawn)  # the baby was carried off, or the way was blocked
			return
		pawn.job_stage = "using"
		pawn.pose = "talk"
		if baby.tile != pawn.tile:
			pawn.facing = baby.tile - pawn.tile
		return
	pawn.job_minutes += 1
	var care_id := pawn.job_interaction
	baby.care[care_id] = minf(Needs.FULL, float(baby.care.get(care_id, 0.0)) + Needs.FULL / float(Pregnancy.config().get("tend_minutes", 25)))
	if float(baby.care[care_id]) >= Needs.FULL:
		Mood.add_event(pawn, "tended_baby", GameClock.tick)
		_end_job(pawn)


## One of your folk with nothing pressing goes to stay with a woman of the household in labour, if
## nobody is with her yet.
func _attend_births(pawn: Pawn) -> bool:
	if household.get_pawn(pawn.id) == null or not pawn.adult:
		return false
	for mother in household.pawns:
		if mother.id == pawn.id or not Pregnancy.in_labour(mother) or mother.is_dying():
			continue
		var attended := false
		for other in people():
			attended = attended or (other.job_kind == "attend" and other.job_partner == mother.id)
		if not attended and order_attend(pawn, mother)["ok"]:
			return true
	return false


## Changes a person's given name (a baby being named), keeping the family name. Returns
## { "ok", "message" }.
func rename(pawn: Pawn, given: String) -> Dictionary:
	var clean := given.strip_edges().replace(" ", "")
	if clean == "":
		return { "ok": false, "message": "A name cannot be empty" }
	clean = clean.substr(0, 1).to_upper() + clean.substr(1, 19)
	var family := pawn.display_name.get_slice(" ", 1)
	pawn.display_name = "%s %s" % [clean, family] if family != "" else clean
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
func open_positions(lot_id: String = "", town_id: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for lot in world.lots:
		if lot_id != "" and str(lot["id"]) != lot_id:
			continue
		if town_id != "" and str(lot.get("town", "")) != town_id:
			continue  # a notice board lists the jobs of its own town
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
	if bool(job.get("heavy", false)) and not Life.may_do_heavy_work(pawn):
		return "too old for heavy work"
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


## True when some need is bad enough that work (or a baby) can wait.
func needs_break(pawn: Pawn) -> bool:
	return _needs_break(pawn)


func _needs_break(pawn: Pawn) -> bool:
	if pawn.illness != "" or Pregnancy.needs_rest_from_work(pawn):
		return true
	for need_id in active_needs:
		if Needs.slows_when_empty(need_id) and float(pawn.needs.get(need_id, Needs.FULL)) < WORK_BREAK_BELOW:
			return true
	return false


## An idle person with a job goes to work when their shift starts (unless the player took them
## off it today). Returns true if they set off.
func _try_work(pawn: Pawn, minute: int) -> bool:
	if pawn.contract_until > 0 and town.get_pawn(pawn.id) != null and not _needs_break(pawn) and Construction.try_contract(self, pawn):
		return true  # hired to build for the player
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
		Skills.equip(self, pawn, Skills.tool_needed(DataRegistry.get_def("objects", str(job.get("station", "")))), true)  # the employer lends the tool
		for step in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var there := world.object_at(pawn.tile + step)
			if there != null and there.def_id == str(job.get("station", "")):
				pawn.facing = step
		return
	pawn.job_minutes += 1
	var work_skill := Skills.job_skill(job)
	if work_skill != "":
		Skills.practice(self, pawn, work_skill)
	var station := DataRegistry.get_def("objects", str(job.get("station", "")))
	if station.has("accident"):
		var accident := Accidents.roll(self, pawn, station, _rng)
		if accident != "":
			health_notice.emit(accident)


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
	var price := Economy.build_price(def_id, household.stock) if ignoring == 0 else { "coins": 0, "uses": {} }  # moving is free
	if int(price["coins"]) > household.coins:
		var uses := Economy.stock_text(price["uses"])
		return "it costs %s%s and you have %s" % [Economy.format(int(price["coins"])), (" and " + uses) if uses != "" else "", Economy.format(household.coins)]
	return ""


func build_place(def_id: String, tile: Vector2i) -> Dictionary:
	var blocker := build_blocker(def_id, tile)
	if blocker != "":
		return { "ok": false, "message": "Can't build here: %s" % blocker }
	var price := Economy.build_price(def_id, household.stock)
	household.coins -= int(price["coins"])
	for resource_id in price["uses"]:
		household.add_stock(str(resource_id), -int(price["uses"][resource_id]))
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
	if Construction.cancel_at(self, tile) > 0:
		return { "ok": true, "message": "" }  # a plan that was never built is simply called off
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
	elif pawn.job_kind == "extinguish":
		text = "Beating out a fire" if pawn.job_stage == "using" else "Running to put out a fire"
	elif pawn.job_kind == "date":
		var date_partner := person(pawn.job_partner)
		var date_name := _first_name(date_partner) if date_partner != null else "someone"
		text = "On a date with %s" % date_name if pawn.job_stage == "using" else "Going on a date with %s" % date_name
	elif pawn.job_kind == "cart":
		var cart := world.get_caravan(pawn.caravan)
		var destination := str(world.get_town(cart.to_town if cart != null and cart.to_town != "" else (cart.next_town if cart != null else "")).get("name", "the next town"))
		text = "Riding with the caravan to %s" % destination if cart != null and cart.state == "travelling" else "Waiting on the cart for the caravan to leave"
	elif pawn.job_kind == "build":
		var plan := world.get_site(pawn.job_site)
		var plan_name := Construction.site_name(plan) if plan != null else "the building work"
		text = "Building the %s" % plan_name if pawn.job_stage == "working" else ("Hauling materials to the %s" % plan_name if pawn.job_stage == "site" else "Fetching materials")
	elif pawn.job_kind == "hunt":
		var game := world.get_animal(pawn.job_animal)
		text = ("Taking aim at %s" if pawn.job_stage == "using" else "Stalking %s") % (game.title() if game != null else "game")
	elif pawn.job_kind == "pet":
		var friend := world.get_animal(pawn.job_animal)
		text = ("Making a fuss of %s" if pawn.job_stage == "using" else "Going to %s") % (friend.title() if friend != null else "an animal")
	elif pawn.job_kind == "mount":
		var steed := world.get_animal(pawn.job_animal)
		text = "Going to %s" % (steed.title() if steed != null else "the horse")
	elif pawn.job_kind == "wed":
		var spouse := person(pawn.job_partner)
		var spouse_name := _first_name(spouse) if spouse != null else "someone"
		text = "Marrying %s" % spouse_name if pawn.job_stage == "using" else "Going to be married to %s" % spouse_name
	elif pawn.job_kind == "guest":
		var bride := person(pawn.job_partner)
		text = "At %s's wedding" % (_first_name(bride) if bride != null else "a") if pawn.job_stage == "waiting" else "Going to the wedding"
	elif pawn.job_kind == "labour":
		text = "In labour" if pawn.job_stage == "using" else "In labour, making for a bed"
	elif pawn.job_kind == "attend":
		var labouring := person(pawn.job_partner)
		text = "Staying with %s for the birth" % (_first_name(labouring) if labouring != null else "her")
	elif pawn.job_kind == "tend":
		text = str(Babies.care_def(pawn.job_interaction).get("doing", "Seeing to the baby")) if pawn.job_stage == "using" else "Going to the baby"
	elif pawn.job_kind == "plead":
		var dying := person(pawn.job_partner)
		var dying_name := _first_name(dying) if dying != null else "someone"
		text = "Pleading with Death for %s" % dying_name if pawn.job_stage == "using" else "Hurrying to %s" % dying_name
	elif pawn.has_orders():
		text = "Riding" if pawn.mount != 0 else "Walking"
	if pawn.is_infant():
		return "Being carried"
	if pawn.is_dying():
		return "Dying. Death is here" if Mortality.death_has_come(pawn) else "Dying"
	if pawn.slowed:
		text += " (exhausted)"
	if Pregnancy.is_known(pawn) and not Pregnancy.in_labour(pawn):
		text += " (expecting twins)" if pawn.babies_due == 2 and Pregnancy.trimester(pawn) == 3 else " (expecting)"
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
		for rect in _gather_rects(def):
			for pawn in everyone:
				if not rect.has_point(pawn.tile):
					continue
				var restore: Dictionary = def.get("restore", {})
				for need_id in restore:
					if pawn.needs.has(need_id):
						pawn.needs[need_id] = minf(Needs.FULL, float(pawn.needs[need_id]) + float(restore[need_id]) * EVENT_EVERY / 60.0)
				if def.has("thought"):
					Mood.add_event(pawn, str(def["thought"]), GameClock.tick)


## Every lot an event draws people to ("gather": a kind of building), one in each settlement.
func _gather_rects(def: Dictionary) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var kind := str(def.get("gather", ""))
	if kind != "":
		for entry in world.lots:
			if str(entry["kind"]) == kind:
				rects.append(entry["rect"])
	return rects


## The lot an event draws `pawn` to: the one in their own settlement, or an empty rect.
func _gather_rect(def: Dictionary, pawn: Pawn) -> Rect2i:
	var kind := str(def.get("gather", ""))
	var home_town := str(world.town_of_lot(pawn.home_lot).get("id", ""))
	var fallback := Rect2i()
	if kind != "":
		for entry in world.lots:
			if str(entry["kind"]) == kind:
				if str(entry.get("town", "")) == home_town:
					return entry["rect"]
				if fallback.size == Vector2i.ZERO:
					fallback = entry["rect"]
	return fallback if home_town == "" else Rect2i()


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


## Someone dies (Death takes them; see Mortality): whatever they were doing stops, a grave is dug
## in the chapel yard (or where they fell), those who knew them mourn, and control passes to the
## next person in the household. With nobody left the playthrough is over.
func die(pawn: Pawn, cause: String) -> void:
	_end_job(pawn)
	if household.get_pawn(pawn.id) == null:
		Families.settle_estate(self, pawn)  # what they earned last included, and before the marriage ends with the death
	Romance.on_death(self, pawn)
	pawn.path.clear()
	var spot := pawn.committed_tile()
	var figure := Mortality.death_figure(pawn)
	departures.append({ "tile": spot, "tick": GameClock.tick, "name": pawn.display_name, "death_at": figure.get("to") if figure["visible"] else null })
	var grave := _place_grave(spot)
	if household.get_pawn(pawn.id) == null:  # someone from the town
		town.dead.append({ "name": pawn.display_name, "cause": cause, "day": GameClock.get_day_number() })
		sound_made.emit("toll", spot)
		town.remove_pawn(pawn.id)
		Mortality.after_death(self, pawn, cause, grave, _rng, false)
		town_death.emit(pawn.display_name, cause)
		return
	household.dead.append({ "name": pawn.display_name, "cause": cause, "day": GameClock.get_day_number() })
	sound_made.emit("toll", Vector2i(-1, -1))
	household.remove_pawn(pawn.id)
	Mortality.after_death(self, pawn, cause, grave, _rng, true)
	var successor := household.selected()
	pawn_died.emit(pawn.display_name, cause, successor.display_name if successor != null else "")
	for notice in realm.on_death(self, pawn):
		realm_notice.emit(notice)


func is_game_over() -> bool:
	return household.playable().is_empty()


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


## Digs a grave: in the chapel yard if there is room, otherwise on the nearest open grass to where
## the person fell (never inside a house). Returns its tile, or (-1, -1) if none could be dug.
func _place_grave(spot: Vector2i) -> Vector2i:
	if not DataRegistry.has_def("objects", "grave"):
		return Vector2i(-1, -1)
	var yard := _graveyard_plot()
	if yard.x >= 0 and world.add_object("grave", yard) != null:
		return yard
	for radius in GRAVE_SEARCH:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var plot := spot + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == radius and _grave_ground(plot) and world.add_object("grave", plot) != null:
					return plot
	return Vector2i(-1, -1)


## The next free plot of the chapel yard: open grass on the chapel's own lot first, then round
## about it, in rows with a gap between graves. (-1, -1) if there is no chapel or no room left.
func _graveyard_plot() -> Vector2i:
	for entry in world.lots:
		if str(entry["kind"]) != "chapel":
			continue
		for reach in [0, GRAVEYARD_REACH]:
			var rect: Rect2i = (entry["rect"] as Rect2i).grow(reach)
			for y in range(rect.position.y, rect.end.y, 2):
				for x in range(rect.position.x, rect.end.x, 2):
					var plot := Vector2i(x, y)
					var lot := world.lot_at(plot)
					if (lot.is_empty() or lot["id"] == entry["id"]) and _grave_ground(plot):
						return plot
	return Vector2i(-1, -1)


## Open grass with nothing on it and no wall or floor beside it: somewhere a grave can be dug.
func _grave_ground(plot: Vector2i) -> bool:
	if not world.in_bounds(plot.x, plot.y) or world.object_at(plot) != null or world.floor_at(plot) != "":
		return false
	var ground := DataRegistry.get_def("tiles", world.get_tile_id(plot.x, plot.y))
	return world.is_ground_walkable(plot.x, plot.y) and str(ground.get("style", "")) == "grass" and _open_around(plot)


## No wall or building right next to `tile`, so a grave there stands in the open.
func _open_around(tile: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near := world.object_at(tile + Vector2i(dx, dy))
			if (near != null and near.blocks_walking()) or world.floor_at(tile + Vector2i(dx, dy)) != "":
				return false
	return true


func _step_job(pawn: Pawn) -> void:
	if pawn.mount != 0 and pawn.job_kind != "" and pawn.job_kind != "mount" and not pawn.has_orders():
		Fauna.dismount(self, pawn)  # at the door or the workplace the rider gets down
	if pawn.job_kind == "interact":
		_step_interaction(pawn)
		return
	if pawn.job_kind == "plead":
		_step_plead(pawn)
		return
	if pawn.job_kind == "extinguish":
		_step_extinguish(pawn)
		return
	if pawn.job_kind == "date":
		_step_date(pawn)
		return
	if pawn.job_kind == "cart":
		Caravans.step_ride(self, pawn)
		return
	if pawn.job_kind == "build":
		Construction.step_build(self, pawn, _rng)
		return
	if pawn.job_kind == "hunt":
		Fauna.step_hunt(self, pawn, _rng)
		return
	if pawn.job_kind == "pet":
		Fauna.step_pet(self, pawn)
		return
	if pawn.job_kind == "mount":
		Fauna.step_mount(self, pawn)
		return
	if pawn.job_kind == "wed":
		_step_wedding(pawn)
		return
	if pawn.job_kind == "guest":
		_step_guest(pawn)
		return
	if pawn.job_kind == "labour":
		_step_labour(pawn)
		return
	if pawn.job_kind == "attend":
		_step_attend(pawn)
		return
	if pawn.job_kind == "tend":
		_step_tend(pawn)
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
		var tool_id := Skills.tool_needed(placed.def())
		if tool_id != "" and not Skills.equip(self, pawn, tool_id):
			if household.get_pawn(pawn.id) != null:
				health_notice.emit("%s has no %s to work with." % [_first_name(pawn), Skills.tool_name(tool_id).to_lower()])
			_end_job(pawn)
			return
		var recipe := DataRegistry.get_def("recipes", pawn.job_recipe) if pawn.job_recipe != "" else {}
		if not recipe.is_empty() and Skills.recipe_blocker(self, pawn, recipe) != "":
			health_notice.emit("%s hasn't the materials for that now." % _first_name(pawn))
			_end_job(pawn)
			return
		var price := price_of(placed.def_id)
		if price > 0 and not spend(pawn, price):
			_end_job(pawn)  # somebody spent the money on the way
			return
		_credit_owner(pawn, placed, price)
		if not recipe.is_empty():
			Skills.consume_inputs(self, pawn, recipe, _rng)
		pawn.job_stage = "using"
		pawn.job_minutes = 0
		pawn.pose = str(placed.def().get("pose", ""))
		if placed.tile != pawn.tile:
			pawn.facing = placed.tile - pawn.tile
		return
	# Using it: refill the needs it satisfies until they are all full or time is up.
	var object_def := placed.def()
	var satisfies: Dictionary = object_def.get("satisfies", {})
	var recipe := DataRegistry.get_def("recipes", pawn.job_recipe) if pawn.job_recipe != "" else {}
	var all_full := not object_def.has("gathers") and recipe.is_empty()  # gathering and making go on until the time is up
	var skill_id := str(object_def.get("skill", ""))
	var boost := Skills.boost(pawn, skill_id) if skill_id != "" else 1.0
	var open_sky := Shelter.rest_factor(world, placed, object_def)  # a bed with no roof over it gives less rest
	for need_id in satisfies:
		if not pawn.needs.has(need_id):
			continue
		var value := minf(Needs.FULL, float(pawn.needs[need_id]) + float(satisfies[need_id]) * boost * (open_sky if need_id == "rest" else 1.0) / 60.0)
		pawn.needs[need_id] = value
		if value < Needs.FULL:
			all_full = false
	var drains: Dictionary = object_def.get("drains", {})
	for need_id in drains:  # hard work tires and soils a person
		if pawn.needs.has(need_id):
			pawn.needs[need_id] = maxf(0.0, float(pawn.needs[need_id]) - float(drains[need_id]) / 60.0)
	if object_def.has("accident"):
		var accident := Accidents.roll(self, pawn, object_def, _rng)
		if accident != "":
			health_notice.emit(accident)
		if pawn.job_kind == "" or pawn.is_dying():
			return
	pawn.job_minutes += 1
	if skill_id != "":
		Skills.practice(self, pawn, skill_id)
	var broken := Skills.wear(self, pawn)
	if broken != "":
		if household.get_pawn(pawn.id) != null:
			health_notice.emit(broken)
		_end_job(pawn)
		return
	if pawn.illness != "" and pawn.illness in object_def.get("cures", []) and pawn.job_minutes >= int(object_def.get("cure_minutes", 60)):
		_recover(pawn)
		Mood.add_event(pawn, "treated", GameClock.tick)
	var minutes_needed := Skills.recipe_minutes(pawn, recipe) if not recipe.is_empty() else int(object_def.get("max_use_minutes", 60))
	if all_full or pawn.job_minutes >= minutes_needed:
		Mood.add_event(pawn, "used:%s" % placed.def_id, GameClock.tick)
		if open_sky < 1.0:
			Mood.add_event(pawn, "slept_rough", GameClock.tick)
		if not recipe.is_empty():
			_finish_craft(pawn, recipe)
		if satisfies.has("hunger"):
			Pregnancy.after_eating(pawn)
		if object_def.has("gathers"):
			_collect(pawn, object_def)
		if placed.def_id == "grave":
			var rested := Mortality.lay_to_rest(self, placed.tile, pawn)
			if rested != "" and household.get_pawn(pawn.id) != null:
				health_notice.emit(rested)
		_end_job(pawn)


## A gatherer finishes: what they brought in goes on the household's stockpile.
func _collect(pawn: Pawn, object_def: Dictionary) -> void:
	if household.get_pawn(pawn.id) == null:
		return
	var gathers: Dictionary = object_def.get("gathers", {})
	var brought: Dictionary = {}
	var skill_id := str(object_def.get("skill", ""))
	for resource_id in gathers:
		var amount := int(gathers[resource_id])
		if pawn.traits.has("lazy"):
			amount = maxi(1, amount - 1)
		if skill_id != "":
			amount = Skills.yield_amount(pawn, skill_id, amount, _rng)
		var packed := Fauna.pack_bonus(self, pawn)
		if packed > 0.0:  # a pack animal carries the rest
			var exact := float(amount) * (1.0 + packed)
			amount = floori(exact) + (1 if _rng.randf() < exact - floorf(exact) else 0)
		if amount <= 0:
			continue
		household.add_stock(str(resource_id), amount)
		brought[str(resource_id)] = amount
	Mood.add_event(pawn, "gathered", GameClock.tick)
	health_notice.emit("%s gathered %s." % [_first_name(pawn), Economy.stock_text(brought)])


## Something was made at a forge or bench: what came out goes on the household's stock.
func _finish_craft(pawn: Pawn, recipe: Dictionary) -> void:
	var made: Dictionary = recipe.get("outputs", {})
	for item_id in made:
		household.add_stock(str(item_id), int(made[item_id]))
	Mood.add_event(pawn, "crafted", GameClock.tick)
	health_notice.emit("%s made %s." % [_first_name(pawn), Economy.goods_text(made)])


## Why `nurse` cannot treat `patient` with herbs now, or "".
func treat_blocker(nurse: Pawn, patient: Pawn) -> String:
	if patient.illness == "":
		return "%s is not ill" % _first_name(patient)
	if household.get_pawn(nurse.id) == null:
		return "not possible"
	if household.stock_of("herbs") < 1:
		return "you have no herbs"
	if household.stock_of("healers_satchel") < 1:
		return "needs a healer's satchel (a shop sells them)"
	if patient.treated_until > GameClock.tick:
		return "already nursed"
	if nurse.age < 12 or nurse.is_dying() or nurse.id == patient.id and patient.is_dying():
		return "not possible"
	if _distance(nurse.tile, patient.tile) > 3:
		return "too far away"
	return ""


## Uses a herb to help someone recover for a few days. Returns { "ok", "message" }.
func treat(nurse: Pawn, patient: Pawn) -> Dictionary:
	var blocker := treat_blocker(nurse, patient)
	if blocker != "":
		return { "ok": false, "message": "Can't nurse them: %s" % blocker }
	household.add_stock("herbs", -1)
	var days := 3.0 * (1.0 + Skills.effect(nurse, "healing", "cure"))
	patient.treated_until = GameClock.tick + roundi(days * GameClock.MINUTES_PER_DAY)
	Skills.practice(self, nurse, "healing", 40.0)
	Mood.add_event(patient, "cared_for", GameClock.tick)
	Ambitions.note(nurse, "healed")
	return { "ok": true, "message": "%s nurses %s with herbs." % [_first_name(nurse), _first_name(patient)] }


## What the shop would pay for all of one resource in the stockpile (0 if there is none).
func sale_price(resource_id: String, seller: Pawn = null) -> int:
	return Economy.sell_price(resource_id, household.stock_of(resource_id), events.sell_multiplier() * _haggling(resource_id, seller))


## What the place and the seller's way with a bargain do to the price of a good: dearer where it is
## scarce, and a practised trader gets a little more.
func _haggling(resource_id: String, seller: Pawn) -> float:
	if seller == null:
		return 1.0
	return Economy.region_multiplier(world, seller.tile, resource_id) * (1.0 + Skills.effect(seller, "trading", "price"))


## Sells everything of a resource at the shop counter. Returns { "ok", "message" }.
func sell_stock(resource_id: String, seller: Pawn = null) -> Dictionary:
	var amount := household.stock_of(resource_id)
	if amount <= 0:
		return { "ok": false, "message": "You have no %s to sell" % Economy.resource_name(resource_id).to_lower() }
	var earned := sale_price(resource_id, seller)
	household.add_stock(resource_id, -amount)
	household.coins += earned
	if seller != null:
		Skills.practice(self, seller, "trading", 10.0)
	sound_made.emit("coin", Vector2i(-1, -1))
	return { "ok": true, "message": "Sold %d %s for %s" % [amount, Economy.resource_name(resource_id).to_lower(), Economy.format(earned)] }


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
	if bool(interaction.get("lesson", false)) and not flopped:
		var taught := Skills.give_lesson(self, pawn, partner)
		if taught != "" and (household.get_pawn(pawn.id) != null or household.get_pawn(partner.id) != null):
			health_notice.emit(taught)
	var romance_rule: Dictionary = interaction.get("romance", {})
	if not romance_rule.is_empty():
		var warmth := float(romance_rule.get("gain", 0.0))
		if not flopped and romance_rule.has("backfire") and _rng.randf() < float(romance_rule["backfire"]):
			warmth = -float(romance_rule.get("loss", 0.0))
			flopped = true
			Mood.add_event(pawn, "flirt_flop", GameClock.tick)
		pawn.add_romance(partner.id, warmth)
		partner.add_romance(pawn.id, warmth)
		if bool(interaction.get("begins_dating", false)) and not flopped:
			Romance.begin_dating(self, pawn, partner)
			if household.get_pawn(pawn.id) != null or household.get_pawn(partner.id) != null:
				health_notice.emit("%s and %s are courting." % [_first_name(pawn), _first_name(partner)])
	if bool(interaction.get("proposes", false)) and not flopped:
		var engaged := Romance.engage(self, pawn, partner)
		if household.get_pawn(pawn.id) != null or household.get_pawn(partner.id) != null:
			health_notice.emit(engaged)
	var conception := float(interaction.get("conception_chance", 0.0))
	if conception > 0.0 and not flopped:
		Pregnancy.try_conceive(self, pawn, partner, conception, _rng)


## Lines for the panel: who `pawn` knows best (or least well), as { "name", "label", "opinion" }.
## Their partner comes first.
func relationship_lines(pawn: Pawn, limit: int = 5) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for other_id in pawn.relations:
		var other := person(int(other_id))
		if other != null and absf(float(pawn.relations[other_id])) >= 5.0 and int(other_id) != pawn.partner_id:
			lines.append({ "name": other.display_name, "label": Relations.label(float(pawn.relations[other_id])), "opinion": float(pawn.relations[other_id]) })
	lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(a["opinion"]) > absf(b["opinion"]))
	var partner := person(pawn.partner_id) if pawn.partner_id != 0 else null
	if partner != null:
		var label := Romance.tie_name(pawn, partner)
		lines.push_front({ "name": partner.display_name, "label": label if label != "" else "Partner", "opinion": maxf(pawn.opinion_of(partner.id), 1.0) })
	return lines.slice(0, limit)


## A date: both people head for `tile` (by `route`) and then spend time together there.
func begin_date(pawn: Pawn, partner: Pawn, tile: Vector2i, route: Array[Vector2i]) -> void:
	_end_job(pawn)
	pawn.path = route
	pawn.job_kind = "date"
	pawn.job_stage = "walking"
	pawn.job_tile = tile
	pawn.job_partner = partner.id
	pawn.job_minutes = 0


func _step_date(pawn: Pawn) -> void:
	var partner := person(pawn.job_partner)
	if partner == null or partner.job_kind != "date" or partner.job_partner != pawn.id:
		_end_job(pawn)
		return
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		pawn.job_stage = "waiting"
	if pawn.job_stage == "waiting":
		if partner.job_stage == "waiting" or partner.job_stage == "using":
			if _distance(pawn.tile, partner.tile) <= 2:
				pawn.job_stage = "using"
				pawn.job_minutes = 0
				pawn.pose = "close"
				pawn.facing = partner.tile - pawn.tile if partner.tile != pawn.tile else pawn.facing
		return
	for need_id in ["social", "fun", "libido"]:
		if pawn.needs.has(need_id):
			pawn.needs[need_id] = minf(Needs.FULL, float(pawn.needs[need_id]) + 2.0)
	pawn.job_minutes += 1
	if pawn.job_minutes >= int(Romance.config().get("date_minutes", 60)):
		Romance.finish_date(pawn, partner)  # ending it ends the other's too, so this is only done once
		if household.get_pawn(pawn.id) != null or household.get_pawn(partner.id) != null:
			health_notice.emit("%s and %s had a lovely time together." % [_first_name(pawn), _first_name(partner)])
		_end_job(pawn)


## A wedding: the bride and groom (`pawn` and `partner`) each make for their place by the altar.
func begin_wedding(pawn: Pawn, partner: Pawn, tile: Vector2i, route: Array[Vector2i]) -> void:
	_end_job(pawn)
	pawn.path = route
	pawn.job_kind = "wed"
	pawn.job_stage = "walking"
	pawn.job_tile = tile
	pawn.job_partner = partner.id
	pawn.job_minutes = 0


## A guest (of the wedding of `lead_id`) goes to stand in the chapel.
func begin_guest(pawn: Pawn, lead_id: int, tile: Vector2i, route: Array[Vector2i]) -> void:
	_end_job(pawn)
	pawn.path = route
	pawn.job_kind = "guest"
	pawn.job_stage = "walking"
	pawn.job_tile = tile
	pawn.job_partner = lead_id
	pawn.job_minutes = 0


func _step_wedding(pawn: Pawn) -> void:
	var partner := person(pawn.job_partner)
	if partner == null or partner.job_kind != "wed" or partner.job_partner != pawn.id or Romance.wedding_blocker_in_progress(pawn, partner):
		_end_job(pawn)
		return
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		pawn.job_stage = "waiting"
	if pawn.job_stage == "waiting":
		if partner.job_stage in ["waiting", "using"] and _distance(pawn.tile, partner.tile) <= 2:
			pawn.job_stage = "using"
			pawn.job_minutes = 0
			pawn.pose = "close"
			pawn.facing = partner.tile - pawn.tile if partner.tile != pawn.tile else pawn.facing
		return
	pawn.job_minutes += 1
	for need_id in ["social", "fun"]:
		if pawn.needs.has(need_id):
			pawn.needs[need_id] = minf(Needs.FULL, float(pawn.needs[need_id]) + 2.0)
	if pawn.job_minutes >= int(Romance.config().get("wedding_minutes", 30)):
		var wed := Romance.marry(self, pawn, partner)  # ending it ends the other's job too, so this is only done once
		if household.get_pawn(pawn.id) != null or household.get_pawn(partner.id) != null:
			health_notice.emit(wed)
		_end_job(pawn)


func _step_guest(pawn: Pawn) -> void:
	var lead := person(pawn.job_partner)
	if lead == null or lead.job_kind != "wed":  # the ceremony is over, or was called off
		if lead != null and lead.bond == "married" and lead.wed_until > GameClock.tick:
			Mood.add_event(pawn, "at_wedding", GameClock.tick)
			for need_id in ["social", "fun"]:
				if pawn.needs.has(need_id):
					pawn.needs[need_id] = minf(Needs.FULL, float(pawn.needs[need_id]) + 25.0)
		_end_job(pawn)
		return
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		pawn.job_stage = "waiting"
		pawn.job_minutes = 0
		pawn.facing = lead.tile - pawn.tile if lead.tile != pawn.tile else pawn.facing
		return
	pawn.job_minutes += 1
	if pawn.job_minutes >= int(Romance.config().get("wedding_guest_wait_minutes", 90)):
		_end_job(pawn)


func _end_job(pawn: Pawn) -> void:
	if pawn.job_kind == "work":
		if pawn.job_stage == "using":
			_pay_shift(pawn)
		else:
			pawn.path.clear()  # still on the way to work: the walk is off too
	var placed := world.get_object(pawn.job_object)
	if placed != null and placed.user_id == pawn.id:
		placed.user_id = 0
	Skills.unequip(self, pawn)
	pawn.job_recipe = ""
	if pawn.job_kind == "build":
		Construction.release(self, pawn)
	if pawn.caravan != 0:
		Caravans.leave(self, pawn)
	if pawn.job_animal != 0:
		pawn.job_animal = 0
		Fauna.refresh_pace(self, pawn)  # no more creeping after game
	var partner: Pawn = person(pawn.job_partner) if pawn.job_kind in ["interact", "date", "wed"] else null
	var partner_kind := pawn.job_kind
	pawn.job_kind = ""
	pawn.job_object = 0
	pawn.job_stage = ""
	pawn.job_minutes = 0
	pawn.job_partner = 0
	pawn.job_interaction = ""
	pawn.pose = ""
	if pawn.pace > 1.0 or pawn.mount != 0:
		Fauna.refresh_pace(self, pawn)
	# An interaction has two people: when one stops, so does the other.
	if partner != null and partner.job_kind == partner_kind and partner.job_partner == pawn.id:
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
func plan_beside(pawn: Pawn, target: Vector2i) -> Dictionary:
	return _plan_beside(pawn, target)


func _plan_beside(pawn: Pawn, target: Vector2i) -> Dictionary:
	var candidates: Array[Vector2i] = []
	for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		candidates.append(target + step)
	return _plan_best(pawn, candidates)


func _plan_best(pawn: Pawn, candidates: Array[Vector2i]) -> Dictionary:
	var origin := pawn.committed_tile()
	var best := {}
	for candidate in candidates:
		if not world.is_walkable(candidate.x, candidate.y) or (candidate != origin and _boxed_in(candidate)):
			continue
		var route: Array[Vector2i] = []
		if candidate != origin:
			route = pathfinder.find_path(origin, candidate)
			if route.is_empty():
				continue
		if best.is_empty() or route.size() < best["route"].size():
			best = { "tile": candidate, "route": route }
	return best


## Whether every side of a tile is blocked, so nobody can get to it (looking for a way in would search the whole map).
func _boxed_in(tile: Vector2i) -> bool:
	for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var next: Vector2i = tile + step
		if world.is_walkable(next.x, next.y):
			return false
	return true


func _first_name(pawn: Pawn) -> String:
	return pawn.display_name.get_slice(" ", 0)


## An idle person with a low need goes to the nearest free thing that fills it.
func _think(pawn: Pawn, minute: int) -> bool:
	if pawn.illness != "" and _seek_treatment(pawn):
		return true
	if not _needs_break(pawn) and _attend_births(pawn):
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
		var reach := NEED_REACH if float(want[0]) > NEED_DESPERATE else 100000  # nobody crosses the country for a lute, but they will for a meal
		for placed in _fillers(str(want[1])):
			if placed.user_id == 0 and _distance(pawn.tile, placed.tile) <= reach and _may_use(pawn, placed) and price_of(placed.def_id) <= coins_of(pawn) and bool(placed.def().get("autonomous", true)):
				options.append(placed)
		options.sort_custom(func(a: PlacedObject, b: PlacedObject) -> bool:
			return _effort(pawn, a) < _effort(pawn, b))
		for placed in options.slice(0, OPTIONS_PER_NEED):
			if order_use(pawn, placed)["ok"]:
				return true
	pawn.think_cooldown = THINK_COOLDOWN_TICKS  # nothing within reach; try again later
	return false


## Whether an object of this kind stands anywhere in the world (a list kept until something is built, moved or removed).
func has_object_kind(def_id: String) -> bool:
	if _object_kinds_dirty:
		_object_kinds.clear()
		for placed in world.objects:
			_object_kinds[placed.def_id] = true
		_object_kinds_dirty = false
	return _object_kinds.has(def_id)


## An idle person sets about one of their wishes now and then, in waking hours: to the lute, to someone
## for a chat. (A wish granted some other way, say the player sent them, counts all the same.)
func _pursue_wish(pawn: Pawn, minute: int) -> bool:
	if pawn.wishes.is_empty() or (GameClock.tick + pawn.id * 7) % _wish_every != 0 or minute < _wish_from or minute >= _wish_until:
		return false
	var yours := household.get_pawn(pawn.id) != null
	for wish in pawn.wishes:
		var action: Dictionary = DataRegistry.get_def("wishes", str(wish["id"])).get("do", {})
		if action.is_empty() or (yours and bool(action.get("npc_only", false))) or int(wish.get("retry", 0)) > GameClock.tick:
			continue
		if _do_wish(pawn, action):
			return true
		wish["retry"] = GameClock.tick + _wish_retry  # nothing came of it; not again for a while
	return false


func _do_wish(pawn: Pawn, action: Dictionary) -> bool:
	if action.has("use"):
		var options: Array[PlacedObject] = []
		for placed in world.objects:
			if placed.def_id == str(action["use"]) and placed.user_id == 0 and _distance(pawn.tile, placed.tile) <= _wish_reach and _may_use(pawn, placed) and price_of(placed.def_id) <= coins_of(pawn):
				options.append(placed)
		options.sort_custom(func(a: PlacedObject, b: PlacedObject) -> bool:
			return _effort(pawn, a) < _effort(pawn, b))
		for placed in options.slice(0, OPTIONS_PER_NEED):
			if order_use(pawn, placed)["ok"]:
				return true
		return false
	if action.has("interact"):
		var candidates: Array[Pawn] = []
		if str(action.get("with", "")) == "partner":
			var partner := person(pawn.partner_id)
			if partner != null:
				candidates.append(partner)
		else:
			for other in (town.pawns if town.get_pawn(pawn.id) != null else people()):
				if other.id != pawn.id and not other.is_infant() and _distance(pawn.tile, other.tile) <= SOCIAL_RADIUS and not other.is_busy():
					candidates.append(other)
			candidates.sort_custom(func(a: Pawn, b: Pawn) -> bool:
				return _distance(pawn.tile, a.tile) - 0.3 * pawn.opinion_of(a.id) < _distance(pawn.tile, b.tile) - 0.3 * pawn.opinion_of(b.id))
		for other in candidates.slice(0, 4):
			if interaction_blocker(pawn, other, str(action["interact"]), true) == "" and order_interact(pawn, other, str(action["interact"]), true)["ok"]:
				return true
		return false
	if action.has("pet"):
		var best: Animal = null
		for animal in world.animals:
			if _distance(pawn.tile, animal.tile) <= 14 and (best == null or _distance(pawn.tile, animal.tile) < _distance(pawn.tile, best.tile)) and Fauna.pet_blocker(self, pawn, animal) == "":
				best = animal
		return best != null and bool(Fauna.order_pet(self, pawn, best)["ok"])
	if action.has("visit"):
		return _visit_other_town(pawn)
	return false


## Heads for a public place in a town the person has not been to (or any other, if they have seen them all).
func _visit_other_town(pawn: Pawn) -> bool:
	var here := str(world.town_at(pawn.tile, 2).get("id", ""))
	var fresh: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	for entry in world.lots:
		var town_id := str(entry.get("town", ""))
		if bool(entry["public"]) and town_id != "" and town_id != here:
			others.append(entry)
			if town_id not in pawn.visited:
				fresh.append(entry)
	var pool := fresh if not fresh.is_empty() else others
	if pool.is_empty():
		return false
	var rect: Rect2i = pool[(GameClock.tick / 30 + pawn.id) % pool.size()]["rect"]
	var middle := rect.get_center()
	for radius in 5:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var goal := middle + Vector2i(dx, dy)
				if world.is_walkable(goal.x, goal.y) and world.object_at(goal) == null:
					return bool(order_move(pawn, goal)["ok"])
	return false


## Every object that can fill a need, from a list kept until something is built, moved or removed.
func _fillers(need_id: String) -> Array:
	if _fillers_dirty:
		_fillers_by_need.clear()
		for placed in world.objects:
			for filled in placed.def().get("satisfies", {}):
				if not _fillers_by_need.has(filled):
					_fillers_by_need[filled] = []
				_fillers_by_need[filled].append(placed)
		_fillers_dirty = false
	return _fillers_by_need.get(need_id, [])


func _on_world_changed(_tile: Vector2i) -> void:
	_object_kinds_dirty = true
	_fillers_dirty = true


# --- fire ---------------------------------------------------------------------------

## Every minute while something burns: those close to the flames run from them, and an idle adult
## within reach goes to beat them out.
func _react_to_fire(pawn: Pawn) -> void:
	if pawn.is_dying() or (pawn.is_infant() and pawn.carried_by != 0) or pawn.job_kind == "labour":
		return
	var standing := world.fires.has(pawn.tile) or world.fires.has(pawn.committed_tile())
	if pawn.job_kind == "extinguish" and not standing:
		if Fire.count_near(world, pawn.tile, 5) > int(Fire.config().get("max_fightable", 10)):  # too big to fight
			_end_job(pawn)
			_flee(pawn, pawn.job_target)
		return
	var danger := Fire.nearest(world, pawn.tile, int(Fire.config().get("flee_radius", 3)))
	if danger.x >= 0 or standing:
		if pawn.job_kind != "" or pawn.has_orders():
			_end_job(pawn)
		_flee(pawn, danger if danger.x >= 0 else pawn.tile)
		Mood.add_event(pawn, "saw_fire", GameClock.tick)
		return
	if pawn.adult and not pawn.is_busy() and not _needs_break(pawn) and pawn.age >= 14:
		var near := Fire.nearest(world, pawn.tile, int(Fire.config().get("fight_radius", 12)))
		if near.x >= 0 and Fire.count_near(world, near, 5) <= int(Fire.config().get("max_fightable", 10)):
			order_extinguish(pawn, near)


## Runs from a fire to open ground a few tiles away from every flame.
func _flee(pawn: Pawn, from_fire: Vector2i) -> void:
	var origin := pawn.committed_tile()
	var best := Vector2i(-1, -1)
	var best_cost := INF
	for radius in range(4, 9):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var tile := origin + Vector2i(dx, dy)
				if not world.is_walkable(tile.x, tile.y) or Fire.nearest(world, tile, 4).x >= 0:
					continue
				var cost := Vector2(tile - from_fire).length() * -1.0 + Vector2(dx, dy).length() * 0.5
				if cost < best_cost:
					best_cost = cost
					best = tile
		if best.x >= 0:
			break
	if best.x >= 0:
		order_move(pawn, best)


## Why `pawn` cannot go and put out a fire, or "".
func extinguish_blocker(pawn: Pawn, fire_tile: Vector2i) -> String:
	if pawn.is_dying() or pawn.is_infant():
		return "not possible"
	if pawn.age < 12:
		return "too young"
	if Pregnancy.in_labour(pawn):
		return "%s is in labour" % _first_name(pawn)
	if not world.fires.has(fire_tile):
		return "nothing is burning there"
	if _plan_fire_stand(pawn, fire_tile).is_empty():
		return "can't get close"
	return ""


## Where to stand to fight a fire: beside it, on something that will not burn if there is such a place.
func _plan_fire_stand(pawn: Pawn, fire_tile: Vector2i) -> Dictionary:
	var safe: Array[Vector2i] = []
	var other: Array[Vector2i] = []
	for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var tile: Vector2i = fire_tile + step
		if world.fires.has(tile):
			continue
		(safe if Fire.flammability(world, tile) <= 0.0 else other).append(tile)
	var plan := _plan_best(pawn, safe)
	return plan if not plan.is_empty() else _plan_best(pawn, other)


## Sends `pawn` to beat out the fire at `fire_tile`.
func order_extinguish(pawn: Pawn, fire_tile: Vector2i) -> Dictionary:
	var blocker := extinguish_blocker(pawn, fire_tile)
	if blocker != "":
		return { "ok": false, "message": "Can't fight the fire: %s" % blocker }
	var plan := _plan_fire_stand(pawn, fire_tile)
	_end_job(pawn)
	pawn.path = plan["route"]
	pawn.job_kind = "extinguish"
	pawn.job_stage = "walking"
	pawn.job_tile = plan["tile"]
	pawn.job_target = fire_tile
	pawn.job_minutes = 0
	return { "ok": true, "message": "" }


func _step_extinguish(pawn: Pawn) -> void:
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		pawn.job_stage = "using"
		pawn.pose = ""
	if not world.fires.has(pawn.job_target):
		var next := Fire.nearest(world, pawn.tile, 2)  # one down; is another alight beside them?
		if next.x < 0:
			if pawn.job_minutes >= 2:
				Mood.add_event(pawn, "fought_fire", GameClock.tick)
			_end_job(pawn)
			return
		pawn.job_target = next
	if _distance(pawn.tile, pawn.job_target) > 2:
		pawn.job_stage = "walking"  # it has spread: follow it
		var plan := _plan_fire_stand(pawn, pawn.job_target)
		if plan.is_empty():
			_end_job(pawn)
		else:
			pawn.path = plan["route"]
		return
	pawn.facing = (pawn.job_target - pawn.tile).sign() if pawn.job_target != pawn.tile else pawn.facing
	pawn.job_minutes += 1
	var burning: Dictionary = world.fires[pawn.job_target]
	burning["fuel"] = int(burning["fuel"]) - int(Fire.config().get("extinguish_per_minute", 6))
	if int(burning["fuel"]) <= 0:
		world.fires.erase(pawn.job_target)


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
		if pawn.is_infant():
			continue
		if pawn.illness != "":
			var current := Illness.def(pawn.illness)
			var days_ill := (GameClock.tick - pawn.ill_since) / GameClock.MINUTES_PER_DAY
			if pawn.is_dying():
				continue
			var grace := 3 if pawn.treated_until > GameClock.tick else 0  # herbs buy time
			if current.is_empty() or _rng.randf() < Illness.recovery_chance(current, pawn):
				_recover(pawn)
			elif days_ill >= int(current.get("fatal_after_days", 9999)) + grace:
				Mortality.fall(self, pawn, str(current.get("death_cause", "died")))
			continue
		for illness in DataRegistry.get_list("illness"):
			if Illness.is_immune(pawn, str(illness["id"])):
				continue
			if _rng.randf() < Illness.catch_chance(illness, pawn, season_id, event_factor):
				pawn.illness = str(illness["id"])
				pawn.ill_since = GameClock.tick
				_announce_illness(pawn)
				break


## Tells the player when one of their folk falls ill, and when the plague is first about.
func _announce_illness(pawn: Pawn) -> void:
	var illness := Illness.def(pawn.illness)
	if household.get_pawn(pawn.id) != null:
		health_notice.emit("%s %s." % [pawn.display_name, str(illness.get("caught", "is ill"))])
	elif bool(illness.get("contagious", false)) and not _announced.has(pawn.illness):
		_announced[pawn.illness] = true
		var town := world.town_of_lot(pawn.home_lot)
		health_notice.emit("Word comes of %s in %s." % [str(illness.get("name", "sickness")).to_lower(), str(town.get("name", "the country"))])


func _recover(pawn: Pawn) -> void:
	var immunity := int(Illness.def(pawn.illness).get("immunity_days", 0))
	if immunity > 0:
		pawn.immune[pawn.illness] = GameClock.tick + immunity * GameClock.MINUTES_PER_DAY
	pawn.treated_until = 0
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
		if other.id != pawn.id and not other.is_infant() and _distance(pawn.tile, other.tile) <= SOCIAL_RADIUS and not other.is_busy():
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
		var crowd := _gather_rect(def, pawn)
		if crowd.size != Vector2i.ZERO and not crowd.has_point(pawn.tile) and _rng.randf() < GATHER_CHANCE:
			var spot := crowd.position + Vector2i(_rng.randi() % crowd.size.x, _rng.randi() % crowd.size.y)
			if world.is_walkable(spot.x, spot.y) and world.object_at(spot) == null:
				order_move(pawn, spot)
				return
	if minute < ROAM_FROM_MINUTE or minute >= ROAM_UNTIL_MINUTE or _rng.randf() > ROAM_CHANCE:
		return
	var rect := Rect2i()
	var roll := _rng.randf()
	var home_town := world.town_of_lot(pawn.home_lot)
	if roll < 0.5:
		var public_lots: Array[Dictionary] = []
		var visiting := _rng.randf() < VISIT_CHANCE  # now and then, a trip to another settlement
		for entry in world.lots:
			if bool(entry["public"]) and (home_town.is_empty() or visiting != (str(entry.get("town", "")) == str(home_town["id"]))):
				public_lots.append(entry)
		if not public_lots.is_empty():
			rect = public_lots[_rng.randi() % public_lots.size()]["rect"]
	elif roll < 0.8:
		var center: Vector2i = home_town["center"] if not home_town.is_empty() else Vector2i(world.width / 2, world.height / 2)
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
	if world.needs_roofing:  # a save from before roofs: its buildings are roofed now
		world.needs_roofing = false
		for lot in world.lots:
			Rooms.auto_roof(world, lot["rect"])
		Rooms.auto_roof(world, world.lot)
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
		if pawn.partner_id != 0 and person(pawn.partner_id) == null:
			pawn.partner_id = 0  # their partner is no longer in the world
			pawn.partner_status = ""
		for need_id in active_needs:
			if not pawn.needs.has(need_id):
				pawn.needs[need_id] = 80.0
		if pawn.job_kind == "" and pawn.tool != "":
			Skills.unequip(self, pawn)  # a tool left in hand by an old save goes back on the shelf
		if pawn.mount != 0 and (world.get_animal(pawn.mount) == null or world.get_animal(pawn.mount).rider != pawn.id):
			pawn.mount = 0  # the horse is gone
		Fauna.refresh_pace(self, pawn)
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
