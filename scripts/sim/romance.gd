class_name Romance
extends RefCounted
## Courtship (data/relationships.json). Two adults who are drawn to each other (an orientation
## trait: see Simulation.attracted) can flirt, which warms their romance (a number kept apart from
## friendship: Pawn.romance). Once it is warm enough on both sides one can ask the other out, and
## they are dating. Dating couples go on dates (a walk to the green, the tavern or the chapel
## together). A couple who are ready can live together: one moves into the other's home (the
## player's folk can ask a partner to move in, or move in with theirs), and they are partners.
## Couples can break up too, and then whoever moved in goes home. Blood relations keep apart, and
## nobody flirts with someone who is taken.
##
## Among the town's people it happens by itself, a little each midnight: couples under one roof
## become partners, singles of one town take to each other and in time move in together.

static func config() -> Dictionary:
	return DataRegistry.get_def("relationships", "romance")


static func _number(key: String, fallback: float) -> float:
	return float(config().get(key, fallback))


static func _first(pawn: Pawn) -> String:
	return pawn.display_name.get_slice(" ", 0)


## The two are seeing each other (and both know it).
static func together(a: Pawn, b: Pawn) -> bool:
	return a.partner_id == b.id and b.partner_id == a.id


## "Partner", "Dating" or "" for how `a` stands with `b`.
static func tie_name(a: Pawn, b: Pawn) -> String:
	if not together(a, b):
		return ""
	return "Partner" if a.partner_status == "partners" else "Dating"


static func is_grown(pawn: Pawn) -> bool:
	return pawn.age >= int(_number("min_age", 18)) and not pawn.is_infant() and not pawn.is_dying()


## How many people live on a lot, and how many beds it has: the room to take someone in.
static func residents(sim: Simulation, lot_id: String) -> int:
	var count := 0
	for pawn in sim.people():
		count += 1 if pawn.home_lot == lot_id and not pawn.is_infant() else 0
	return count


static func beds_on(sim: Simulation, lot_id: String) -> int:
	var lot := sim.world.get_lot(lot_id)
	if lot.is_empty():
		return 0
	var rect: Rect2i = lot["rect"]
	var count := 0
	for placed in sim.world.objects:
		count += 1 if placed.def_id == "bed" and rect.has_point(placed.tile) else 0
	return count


static func spare_beds(sim: Simulation, lot_id: String) -> int:
	return beds_on(sim, lot_id) - residents(sim, lot_id)


# --- asking out, breaking up -------------------------------------------------------------

## They are a couple now: both are glad of it.
static func begin_dating(sim: Simulation, a: Pawn, b: Pawn, status: String = "dating") -> void:
	for pair in [[a, b], [b, a]]:
		var one: Pawn = pair[0]
		var other: Pawn = pair[1]
		one.partner_id = other.id
		one.partner_status = status
		one.partner_since = GameClock.tick
		one.romance[other.id] = maxf(one.romance_for(other.id), _number("ask_out_romance", 25.0))
		Mood.add_event(one, "new_romance", GameClock.tick, _first(other))


## They part. The one who ended it grieves a little, the other a lot. Whoever had moved in with
## the other goes home.
static func break_up(sim: Simulation, leaver: Pawn, left: Pawn) -> String:
	for pawn in [leaver, left]:
		pawn.partner_id = 0
		pawn.partner_status = ""
	leaver.romance.erase(left.id)
	left.romance.erase(leaver.id)
	leaver.add_opinion(left.id, _number("breakup_opinion", -45.0))
	left.add_opinion(leaver.id, _number("breakup_opinion", -45.0))
	Mood.add_event(leaver, "broke_up", GameClock.tick, _first(left))
	Mood.add_event(left, "heartbroken", GameClock.tick, _first(leaver))
	var moved := ""
	for pawn in [leaver, left]:
		var other: Pawn = left if pawn == leaver else leaver
		if pawn.origin_lot != "" and pawn.home_lot == other.home_lot:
			moved = _send_home(sim, pawn)
	return "%s and %s have parted.%s" % [_first(leaver), _first(left), (" " + moved) if moved != "" else ""]


## Someone who moved in with a partner goes back where they came from.
static func _send_home(sim: Simulation, pawn: Pawn) -> String:
	var home := pawn.origin_lot
	pawn.origin_lot = ""
	var came_to_household := sim.household.get_pawn(pawn.id) != null and pawn.home_lot == WorldState.HOME_LOT and home != WorldState.HOME_LOT
	pawn.home_lot = home
	if came_to_household:  # a townsperson who had moved in with your folk goes back to the town
		sim.household.remove_pawn(pawn.id)
		sim.town.adopt(pawn)
		sim.order_stop(pawn)
		var spot := _free_spot_in(sim, home)
		if spot != Vector2i(-1, -1):
			pawn.tile = spot
			pawn.step_to = spot
		sim.household_changed.emit()
		return "%s goes back to the town." % _first(pawn)
	return "%s goes back home." % _first(pawn)


static func _free_spot_in(sim: Simulation, lot_id: String) -> Vector2i:
	var lot := sim.world.get_lot(lot_id)
	if lot.is_empty():
		return Vector2i(-1, -1)
	var rect: Rect2i = lot["rect"]
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if sim.world.floor_at(Vector2i(x, y)) != "" and sim.world.is_walkable(x, y) and sim.world.object_at(Vector2i(x, y)) == null:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Someone died: their partner is on their own now.
static func on_death(sim: Simulation, dead: Pawn) -> void:
	if dead.partner_id == 0:
		return
	var survivor := sim.person(dead.partner_id)
	if survivor != null and survivor.partner_id == dead.id:
		survivor.partner_id = 0
		survivor.partner_status = ""
		Mood.add_event(survivor, "widowed", GameClock.tick, _first(dead))
	dead.partner_id = 0


# --- dates -----------------------------------------------------------------------------------

## Why `a` and `b` cannot go on a date now, or "".
static func date_blocker(sim: Simulation, a: Pawn, b: Pawn) -> String:
	if not together(a, b):
		return "not seeing each other"
	if not (is_grown(a) and is_grown(b)):
		return "only grown-ups can"
	if Pregnancy.in_labour(a) or Pregnancy.in_labour(b):
		return "the baby is coming"
	if b.is_busy():
		return "%s is busy" % _first(b)
	var hour := GameClock.get_minute_of_day() / 60
	if hour < int(_number("date_from_hour", 9.0)) or hour >= int(_number("date_until_hour", 22.0)):
		return "not at this hour"
	if _venue(sim, a, b).is_empty():
		return "nowhere to go nearby"
	return ""


## The place for a date and where each of the two stands: { "lot": id, "tiles": [Vector2i, Vector2i] }.
static func _venue(sim: Simulation, a: Pawn, b: Pawn) -> Dictionary:
	var kinds: Array = config().get("date_venues", ["park"])
	var town := sim.world.town_of_lot(a.home_lot)
	var best := {}
	var best_distance := INF
	for entry in sim.world.lots:
		if str(entry["kind"]) not in kinds or not bool(entry["public"]):
			continue
		if not town.is_empty() and str(entry.get("town", "")) != str(town["id"]):
			continue
		var rect: Rect2i = entry["rect"]
		var distance := Vector2(rect.get_center()).distance_to(Vector2(a.tile))
		if distance > 70.0 or distance >= best_distance:
			continue
		var tiles := _two_tiles(sim, rect)
		if tiles.size() == 2:
			best = { "lot": str(entry["id"]), "tiles": tiles }
			best_distance = distance
	return best


## Two free open tiles side by side in a lot, near its middle.
static func _two_tiles(sim: Simulation, rect: Rect2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var middle := rect.get_center()
	for radius in 8:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var tile := middle + Vector2i(dx, dy)
				var beside := tile + Vector2i(1, 0)
				if rect.has_point(tile) and rect.has_point(beside) and _open(sim, tile) and _open(sim, beside):
					found.append(tile)
					found.append(beside)
					return found
	return found


static func _open(sim: Simulation, tile: Vector2i) -> bool:
	return sim.world.is_walkable(tile.x, tile.y) and sim.world.object_at(tile) == null


## Both people head for the place, then spend an hour together.
static func order_date(sim: Simulation, asker: Pawn, other: Pawn) -> Dictionary:
	var blocker := date_blocker(sim, asker, other)
	if blocker != "":
		return { "ok": false, "message": "Not now: %s" % blocker }
	var venue := _venue(sim, asker, other)
	var tiles: Array[Vector2i] = venue["tiles"]
	var from_asker := sim.pathfinder.find_path(asker.committed_tile(), tiles[0]) if asker.committed_tile() != tiles[0] else ([] as Array[Vector2i])
	var from_other := sim.pathfinder.find_path(other.committed_tile(), tiles[1]) if other.committed_tile() != tiles[1] else ([] as Array[Vector2i])
	if (from_asker.is_empty() and asker.committed_tile() != tiles[0]) or (from_other.is_empty() and other.committed_tile() != tiles[1]):
		return { "ok": false, "message": "Not now: can't get there" }
	sim.begin_date(asker, other, tiles[0], from_asker)
	sim.begin_date(other, asker, tiles[1], from_other)
	return { "ok": true, "message": "" }


## The date is over: they are closer, and happier.
static func finish_date(a: Pawn, b: Pawn) -> void:
	for pair in [[a, b], [b, a]]:
		var one: Pawn = pair[0]
		var other: Pawn = pair[1]
		one.add_romance(other.id, _number("date_romance", 14.0))
		one.add_opinion(other.id, _number("date_opinion", 6.0))
		Mood.add_event(one, "had_date", GameClock.tick, _first(other))


# --- living together -------------------------------------------------------------------------

## Why `host` (one of your folk) cannot ask `guest` to move in, or "".
static func invite_blocker(sim: Simulation, host: Pawn, guest: Pawn) -> String:
	if sim.household.get_pawn(host.id) == null or sim.household.get_pawn(guest.id) != null:
		return "not possible"
	var ready := _ready_to_live_together(host, guest)
	if ready != "":
		return ready
	if host.home_lot != WorldState.HOME_LOT and host.home_lot != "":
		return "%s lives elsewhere" % _first(host)
	if spare_beds(sim, host.home_lot) < 1:
		return "there is no spare bed at home"
	return ""


## Why `mover` (one of your folk) cannot move in with `host`, or "".
static func join_blocker(sim: Simulation, mover: Pawn, host: Pawn) -> String:
	if sim.household.get_pawn(mover.id) == null or sim.household.get_pawn(host.id) != null:
		return "not possible"
	var ready := _ready_to_live_together(mover, host)
	if ready != "":
		return ready
	if host.home_lot == mover.home_lot:
		return "already under one roof"
	if sim.world.get_lot(host.home_lot).is_empty() or spare_beds(sim, host.home_lot) < 1:
		return "there is no spare bed there"
	return ""


static func _ready_to_live_together(a: Pawn, b: Pawn) -> String:
	if not together(a, b):
		return "not seeing each other"
	if not (is_grown(a) and is_grown(b)):
		return "only grown-ups can"
	if a.romance_for(b.id) < _number("move_in_romance", 40.0) or b.romance_for(a.id) < _number("move_in_romance", 40.0):
		return "not ready to share a home yet"
	if GameClock.tick - a.partner_since < int(_number("move_in_dating_days", 1.0)) * GameClock.MINUTES_PER_DAY:
		return "they have not been together long enough"
	return ""


## `guest` joins `host`'s household and home.
static func invite(sim: Simulation, host: Pawn, guest: Pawn) -> String:
	var former := _housemates(sim, guest)
	if sim.town.get_pawn(guest.id) != null:
		sim.town.remove_pawn(guest.id)
	_end_work_if_far(sim, guest, host.home_lot)
	guest.origin_lot = guest.home_lot if guest.home_lot != host.home_lot else ""
	guest.home_lot = host.home_lot
	sim.household.adopt(guest)
	sim.order_stop(guest)
	var spot := _free_spot_in(sim, host.home_lot)
	if spot == Vector2i(-1, -1):
		spot = host.tile
	guest.tile = spot
	guest.step_to = spot
	_moved_in(sim, host, guest, former)
	sim.household_changed.emit()
	return "%s has moved in with %s and joins your household." % [_first(guest), _first(host)]


## `mover` goes to live in `host`'s family home (and stays one of your folk).
static func join(sim: Simulation, mover: Pawn, host: Pawn) -> String:
	var former := _housemates(sim, mover)
	_end_work_if_far(sim, mover, host.home_lot)
	mover.origin_lot = mover.home_lot
	mover.home_lot = host.home_lot
	sim.order_stop(mover)
	_moved_in(sim, host, mover, former)
	for family_member in _housemates(sim, mover):
		family_member.set_opinion(mover.id, maxf(family_member.opinion_of(mover.id), Relations.FAMILY_START))
		mover.set_opinion(family_member.id, maxf(mover.opinion_of(family_member.id), Relations.FAMILY_START))
	return "%s has moved in with %s." % [_first(mover), _first(host)]


## `pawn` (one of your folk, living at a partner's) goes back to their own home.
static func move_home_blocker(sim: Simulation, pawn: Pawn) -> String:
	if sim.household.get_pawn(pawn.id) == null or pawn.home_lot == WorldState.HOME_LOT:
		return "already at home"
	if spare_beds(sim, WorldState.HOME_LOT) < 1:
		return "there is no spare bed at home"
	return ""


static func move_home(sim: Simulation, pawn: Pawn) -> String:
	var former := _housemates(sim, pawn)
	pawn.home_lot = WorldState.HOME_LOT
	pawn.origin_lot = ""
	if pawn.partner_status == "partners":
		pawn.partner_status = "dating"
		var partner := sim.person(pawn.partner_id)
		if partner != null:
			partner.partner_status = "dating"
	for housemate in former:
		Mood.add_event(housemate, "moved_away", GameClock.tick, _first(pawn))
	sim.order_stop(pawn)
	return "%s has moved back to your lot." % _first(pawn)


static func _housemates(sim: Simulation, pawn: Pawn) -> Array[Pawn]:
	var found: Array[Pawn] = []
	for other in sim.people():
		if other.id != pawn.id and other.home_lot == pawn.home_lot and not other.is_infant():
			found.append(other)
	return found


static func _moved_in(_sim: Simulation, host: Pawn, mover: Pawn, former_housemates: Array[Pawn]) -> void:
	host.partner_status = "partners"
	mover.partner_status = "partners"
	Mood.add_event(mover, "moved_in", GameClock.tick, _first(host))
	Mood.add_event(host, "moved_in", GameClock.tick, _first(mover))
	for housemate in former_housemates:
		Mood.add_event(housemate, "moved_away", GameClock.tick, _first(mover))


## A job in another town cannot be kept from a new home.
static func _end_work_if_far(sim: Simulation, pawn: Pawn, new_home: String) -> void:
	if pawn.work_lot == "":
		return
	var workplace := sim.world.town_of_lot(pawn.work_lot)
	var home := sim.world.town_of_lot(new_home)
	if not workplace.is_empty() and not home.is_empty() and workplace["id"] != home["id"]:
		sim.quit_job(pawn)


# --- the passing days ----------------------------------------------------------------------------

## Midnight: romance cools unless it is kept up, couples are glad of each other, and among the
## town's people couples form and move in together. Returns notices for the player.
static func new_day(sim: Simulation, rng: RandomNumberGenerator) -> Array[String]:
	var notices: Array[String] = []
	var everyone := sim.people()
	for pawn in everyone:
		for other_id in pawn.romance.keys():
			var change := -_number("daily_decay", 0.6)
			if other_id == pawn.partner_id:
				change = _number("partner_daily_gain", 0.5)
			pawn.add_romance(int(other_id), change)
		if pawn.partner_id != 0 and sim.person(pawn.partner_id) == null:
			pawn.partner_id = 0  # the other has left the world
			pawn.partner_status = ""
	_pair_housemates(sim, rng)
	_pair_singles(sim, rng)
	_move_in_couples(sim, rng)
	return notices


## Two grown-ups of the town under one roof, drawn to each other, become partners.
static func _pair_housemates(sim: Simulation, rng: RandomNumberGenerator) -> void:
	var by_home := {}
	for pawn in sim.town.pawns:
		if pawn.partner_id == 0 and is_grown(pawn):
			if not by_home.has(pawn.home_lot):
				by_home[pawn.home_lot] = []
			by_home[pawn.home_lot].append(pawn)
	for home in by_home:
		var singles: Array = by_home[home]
		for i in singles.size():
			for j in range(i + 1, singles.size()):
				var a: Pawn = singles[i]
				var b: Pawn = singles[j]
				if a.partner_id == 0 and b.partner_id == 0 and sim.attracted(a, b) and sim.attracted(b, a) and not Relations.are_kin(a, b) \
						and rng.randf() < _number("household_pair_chance", 0.3):
					begin_dating(sim, a, b, "partners")
					a.romance[b.id] = 60.0
					b.romance[a.id] = 60.0


## Singles of one town take a liking to each other now and then.
static func _pair_singles(sim: Simulation, rng: RandomNumberGenerator) -> void:
	var chance := _number("town_pair_chance", 0.012)
	var singles: Array[Pawn] = []
	for pawn in sim.town.pawns:
		if pawn.partner_id == 0 and is_grown(pawn):
			singles.append(pawn)
	for pawn in singles:
		if pawn.partner_id != 0 or rng.randf() >= chance:
			continue
		var town_id := str(sim.world.town_of_lot(pawn.home_lot).get("id", ""))
		var options: Array[Pawn] = []
		for other in singles:
			if other.id != pawn.id and other.partner_id == 0 and other.home_lot != pawn.home_lot \
					and str(sim.world.town_of_lot(other.home_lot).get("id", "")) == town_id \
					and sim.attracted(pawn, other) and sim.attracted(other, pawn) and not Relations.are_kin(pawn, other) \
					and absi(pawn.age - other.age) <= 20:
				options.append(other)
		if options.is_empty():
			continue
		var chosen: Pawn = options[rng.randi() % options.size()]
		begin_dating(sim, pawn, chosen)
		pawn.add_opinion(chosen.id, 12.0)
		chosen.add_opinion(pawn.id, 12.0)
		pawn.romance[chosen.id] = 35.0
		chosen.romance[pawn.id] = 35.0


## Townsfolk couples who have been together long enough move under one roof, if there is room.
static func _move_in_couples(sim: Simulation, rng: RandomNumberGenerator) -> void:
	for pawn in sim.town.pawns:
		if pawn.partner_status != "dating" or pawn.partner_id < pawn.id:
			continue  # each couple once
		var partner := sim.town.get_pawn(pawn.partner_id)
		if partner == null or not together(pawn, partner) or pawn.home_lot == partner.home_lot:
			continue
		if GameClock.tick - pawn.partner_since < int(_number("move_in_dating_days", 1.0)) * GameClock.MINUTES_PER_DAY:
			continue
		if rng.randf() >= _number("town_move_in_chance", 0.3):
			continue
		var mover := pawn if residents(sim, pawn.home_lot) <= residents(sim, partner.home_lot) else partner
		var host := partner if mover == pawn else pawn
		if spare_beds(sim, host.home_lot) < 1:  # no room there: try it the other way round
			mover = partner if mover == pawn else pawn
			host = partner if mover == pawn else pawn
			if spare_beds(sim, host.home_lot) < 1:
				continue
		var former := _housemates(sim, mover)
		_end_work_if_far(sim, mover, host.home_lot)
		mover.origin_lot = mover.home_lot
		mover.home_lot = host.home_lot
		mover.class_id = host.class_id
		var spot := _free_spot_in(sim, host.home_lot)
		if spot != Vector2i(-1, -1):
			mover.tile = spot
			mover.step_to = spot
			mover.path.clear()
		_moved_in(sim, host, mover, former)
		for family_member in _housemates(sim, mover):
			family_member.set_opinion(mover.id, maxf(family_member.opinion_of(mover.id), Relations.FAMILY_START))
			mover.set_opinion(family_member.id, maxf(mover.opinion_of(family_member.id), Relations.FAMILY_START))
