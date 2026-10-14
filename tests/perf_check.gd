extends Node
## Times one game day of the whole town: godot --headless --path . res://tests/perf_check.tscn

func _ready() -> void:
	GameClock.reset()
	GameClock.set_time(0, 6)
	var world := RegionGenerator.generate(7)
	var household := HouseholdGenerator.create(world)
	CampGenerator.place(world, household)
	var sim := Simulation.new(world, household, NpcGenerator.create(world))
	var started := Time.get_ticks_msec()
	for minute in GameClock.MINUTES_PER_DAY:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
	var elapsed := Time.get_ticks_msec() - started
	print("one day, %d people: %d ms (%.2f ms per tick)" % [sim.people().size(), elapsed, float(elapsed) / GameClock.MINUTES_PER_DAY])
	get_tree().quit()
