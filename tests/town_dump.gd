extends Node
## Prints an ASCII picture of a generated town: godot --headless --path . res://tests/town_dump.tscn -- --seed=7

func _ready() -> void:
	var world_seed := 7
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			world_seed = int(arg.trim_prefix("--seed="))
	var world := MapGenerator.generate(world_seed, 128, 96)
	var report := TownGenerator.generate(world)
	var household := HouseholdGenerator.create(world)
	CampGenerator.place(world, household)
	var town := NpcGenerator.create(world)
	print(report)
	for entry in world.lots:
		print("%s %s %s %s facing %s" % [entry["id"], entry["kind"], entry["template"], entry["rect"], entry["facing"]])
	print("npcs: %d" % town.pawns.size())
	var marks := {}
	for pawn in town.pawns:
		marks[pawn.tile] = "n" if pawn.adult else "c"
	for pawn in household.pawns:
		marks[pawn.tile] = "@"
	var center := Vector2i(world.width / 2, world.height / 2)
	for y in range(center.y - 28, center.y + 30):
		var line := ""
		for x in range(center.x - 46, center.x + 47):
			var tile := Vector2i(x, y)
			var ch := "."
			match world.get_tile_id(x, y):
				"dirt": ch = ":"
				"water": ch = "~"
				"forest": ch = "f"
				"stone": ch = "^"
			var placed := world.object_at(tile)
			if world.floor_at(tile) != "":
				ch = ","
			if placed != null:
				ch = {"wall": "#", "stone_wall": "S", "door": "+", "bed": "b", "grave": "x"}.get(placed.def_id, "o")
			if world.lot.has_point(tile) and ch == ".":
				ch = "_"
			if marks.has(tile):
				ch = marks[tile]
			line += ch
		print(line)
	get_tree().quit()
