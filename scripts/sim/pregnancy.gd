class_name Pregnancy
extends RefCounted
## Children (data/pregnancy.json). Intimacy between a woman of the household and a man may start a
## pregnancy ("conception_chance" on the interaction). It stays a private matter for a while, then
## she is known to be expecting: she eats and tires more, and in the last weeks stays off work. At
## the end a baby is born into the household. Babies are carried by the household, cannot be
## controlled, and grow up a year at a time (a year is `year_days` days). Townspeople never
## conceive: only the player's household grows.


static func config() -> Dictionary:
	return DataRegistry.get_def("pregnancy", "pregnancy")


static func infant_age() -> int:
	return int(config().get("infant_until_age", 2))


static func days_pregnant(pawn: Pawn) -> int:
	return GameClock.get_day_number() - pawn.pregnant_since if pawn.is_pregnant() else 0


## Pregnant and far enough along for everyone to know.
static func is_known(pawn: Pawn) -> bool:
	return pawn.is_pregnant() and days_pregnant(pawn) >= int(config().get("announce_after_days", 12))


static func is_heavy(pawn: Pawn) -> bool:
	return pawn.is_pregnant() and days_pregnant(pawn) >= int(config().get("heavy_after_days", 33))


## Whether `mother` could conceive right now.
static func can_conceive(mother: Pawn) -> bool:
	return mother.gender == "female" and mother.adult and not mother.is_pregnant() \
		and GameClock.get_day_number() >= mother.recovered_on and mother.age <= int(config().get("max_mother_age", 45))


## Called when an intimate interaction ends. Returns true if a pregnancy began.
static func try_conceive(sim: Simulation, a: Pawn, b: Pawn, chance: float, rng: RandomNumberGenerator) -> bool:
	if a.gender == b.gender or not (a.adult and b.adult):
		return false
	var mother := a if a.gender == "female" else b
	var father := b if mother == a else a
	if sim.household.get_pawn(mother.id) == null or not can_conceive(mother):
		return false
	if rng.randf() >= chance:
		return false
	mother.pregnant_since = GameClock.get_day_number()
	mother.pregnancy_father = father.id
	return true


## `multipliers` with an expecting mother's extra hunger and tiredness multiplied in.
static func drain_multipliers(pawn: Pawn, multipliers: Dictionary) -> Dictionary:
	if not is_known(pawn):
		return multipliers
	var merged := multipliers.duplicate()
	var extra: Dictionary = config().get("need_drain_multipliers", {})
	for need_id in extra:
		merged[need_id] = float(merged.get(need_id, 1.0)) * float(extra[need_id])
	return merged


## Heavily pregnant women stay home from work.
static func needs_rest_from_work(pawn: Pawn) -> bool:
	return bool(config().get("heavy_work_break", true)) and is_heavy(pawn)


static func birthday_of(pawn: Pawn) -> int:
	return pawn.birthday if pawn.birthday >= 0 else pawn.id % int(config().get("year_days", 60))


## Keeps every infant on the arms of someone in the household, moving with them.
static func carry_infants(sim: Simulation) -> void:
	for baby in sim.household.pawns:
		if not baby.is_infant():
			continue
		var carer := sim.household.get_pawn(baby.carried_by)
		if carer == null or carer.is_infant():
			carer = null
			for candidate in sim.household.pawns:
				if not candidate.is_infant() and (carer == null or (candidate.adult and not carer.adult)):
					carer = candidate
			baby.carried_by = carer.id if carer != null else 0
		if carer == null:
			continue
		baby.tile = carer.tile
		baby.step_to = carer.step_to
		baby.step_ticks_total = carer.step_ticks_total
		baby.step_ticks_done = carer.step_ticks_done
		baby.facing = carer.facing
		baby.path.clear()


## Midnight: birthdays, announcements and births. Returns messages for the player. Anything that
## changes who is in the household is reported by `sim.household_changed`.
static func new_day(sim: Simulation, rng: RandomNumberGenerator) -> Array[String]:
	var messages: Array[String] = []
	var day := GameClock.get_day_number()
	var settings := config()
	var changed := false
	for pawn in sim.people():
		var yours := sim.household.get_pawn(pawn.id) != null
		if day > 0 and day % int(settings.get("year_days", 60)) == birthday_of(pawn):
			pawn.age += 1
			if not pawn.adult and pawn.age >= 18:
				pawn.adult = true
				PersonFactory.give_orientation(pawn, rng)
				if yours:
					messages.append("%s has come of age." % pawn.display_name)
			elif yours and pawn.age == infant_age():
				messages.append("%s is old enough to run about on their own." % pawn.display_name)
				changed = true
		if not yours or not pawn.is_pregnant():
			continue
		var days := days_pregnant(pawn)
		if days == int(settings.get("announce_after_days", 12)):
			messages.append("%s is expecting a baby." % pawn.display_name)
		elif days >= int(settings.get("duration_days", 45)):
			messages.append(_give_birth(sim, pawn))
			changed = true
	if changed:
		sim.household_changed.emit()
	return messages


static func _give_birth(sim: Simulation, mother: Pawn) -> String:
	var day := GameClock.get_day_number()
	var rng := RandomNumberGenerator.new()
	rng.seed = sim.world.world_seed * 31 + day * 977 + mother.id
	var used: Array[String] = []
	for relative in sim.household.pawns:
		used.append(relative.display_name.get_slice(" ", 0))
	var family := mother.display_name.get_slice(" ", 1)
	var baby := PersonFactory.make(rng, family if family != "" else "Smith", used, 0)
	var father := sim.person(mother.pregnancy_father)
	var parent_skins: Array[String] = [str(mother.look.get("skin", ""))]
	if father != null:
		parent_skins.append(str(father.look.get("skin", "")))
	if parent_skins[rng.randi() % parent_skins.size()] != "":
		baby.look["skin"] = parent_skins[rng.randi() % parent_skins.size()]
	baby.home_lot = mother.home_lot
	baby.class_id = mother.class_id
	baby.birthday = day % int(config().get("year_days", 60))
	baby.carried_by = mother.id
	baby.tile = mother.committed_tile()
	baby.step_to = baby.tile
	var family_members: Array[Pawn] = []
	for relative in sim.household.pawns:
		family_members.append(relative)
	sim.household.add_pawn(baby)
	family_members.append(baby)
	Relations.make_family(family_members)
	mother.pregnant_since = -1
	mother.recovered_on = day + int(config().get("recovery_days", 15))
	for relative in sim.household.pawns:
		Mood.add_event(relative, "birth", GameClock.tick)
	var who := "a healthy baby %s" % ("girl" if baby.gender == "female" else "boy")
	return "%s gave birth to %s, named %s." % [mother.display_name, who, baby.display_name.get_slice(" ", 0)]
