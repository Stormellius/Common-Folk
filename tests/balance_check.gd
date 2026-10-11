extends Node
## Not a pass/fail test: plays 15 game days on a few seeds with nobody giving orders and prints
## how the people did (deaths, mood, the lowest each need got). Run it after changing needs,
## thoughts or the starting camp to see whether the balance still holds:
##   godot --headless --path . res://tests/balance_check.tscn

const SEEDS := [7, 42, 99]
const START_DAYS := [0, 45]  # the first day of spring, and the middle of winter
const DAYS := 15


func _ready() -> void:
	for start_day in START_DAYS:
		for world_seed in SEEDS:
			_play(world_seed, start_day)
	get_tree().quit()


func _play(world_seed: int, start_day: int) -> void:
	for once in 1:
		GameClock.reset()
		GameClock.set_time(start_day, 6)
		var world := MapGenerator.generate(world_seed, 128, 96)
		TownGenerator.generate(world)
		var household := HouseholdGenerator.create(world)
		CampGenerator.place(world, household)
		var sim := Simulation.new(world, household, NpcGenerator.create(world))
		var deaths := [0]
		var town_deaths := [0]
		sim.pawn_died.connect(func(_person: String, _cause: String, _next: String) -> void: deaths[0] += 1)
		sim.town_death.connect(func(_person: String, _cause: String) -> void: town_deaths[0] += 1)
		var coins_at_start := 0
		for villager in sim.town.pawns:
			coins_at_start += villager.coins
		var lowest := {}
		var total := 0.0
		var samples := 0
		var worst_mood := 100.0
		for minute in DAYS * GameClock.MINUTES_PER_DAY:
			GameClock.advance_one_tick()
			sim.step()
			if minute % 60 == 0:
				for pawn in sim.people():
					total += pawn.mood
					samples += 1
					worst_mood = minf(worst_mood, pawn.mood)
					for need_id in pawn.needs:
						lowest[need_id] = minf(float(lowest.get(need_id, 100.0)), float(pawn.needs[need_id]))
		var rounded := {}
		for need_id in lowest:
			rounded[need_id] = snappedf(lowest[need_id], 0.1)
		var coins_at_end := 0
		var employed := 0
		for villager in sim.town.pawns:
			coins_at_end += villager.coins
			employed += 1 if villager.work_job != "" else 0
		print("seed %d, day %d: %d deaths (%d in town), %d people, average mood %.1f, worst mood %.1f, lowest needs %s" % [world_seed, start_day, deaths[0], town_deaths[0], sim.people().size(), total / maxf(1.0, samples), worst_mood, rounded])
		print("    town: %d in work, pockets %d -> %d coin; household purse %d" % [employed, coins_at_start, coins_at_end, household.coins])
