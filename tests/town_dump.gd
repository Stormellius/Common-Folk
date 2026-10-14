extends Node
## Prints ASCII pictures of a generated map: the whole region from far away, then one town close up.
##   godot --headless --path . res://tests/town_dump.tscn -- --seed=7 --town=1
## `town` is the number of the settlement to show (1 is the player's).

func _ready() -> void:
	var world_seed := 7
	var shown := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			world_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--town="):
			shown = int(arg.trim_prefix("--town="))
	var started := Time.get_ticks_msec()
	var world := RegionGenerator.generate(world_seed)
	print("generated %dx%d in %d ms" % [world.width, world.height, Time.get_ticks_msec() - started])
	var household := HouseholdGenerator.create(world)
	CampGenerator.place(world, household)
	var town := NpcGenerator.create(world)
	print("%d objects, %d lots, %d people" % [world.objects.size(), world.lots.size(), town.pawns.size()])
	for entry in world.towns:
		var lots := 0
		var people := 0
		for lot in world.lots:
			lots += 1 if lot.get("town", "") == entry["id"] else 0
		for pawn in town.pawns:
			people += 1 if world.town_of_lot(pawn.home_lot).get("id", "") == entry["id"] else 0
		print("%s %s (%s) at %s: %d lots, %d people%s" % [entry["id"], entry["name"], entry["kind"], entry["center"], lots, people, " - home" if entry["home"] else ""])

	# The whole map, one character for each 4 by 4 tiles.
	for y in range(0, world.height, 4):
		var line := ""
		for x in range(0, world.width, 4):
			var counts := {}
			for dy in 4:
				for dx in 4:
					var id := world.get_tile_id(x + dx, y + dy)
					counts[id] = int(counts.get(id, 0)) + 1
			var ch := "."
			var best := 0
			for id in counts:
				if int(counts[id]) > best:
					best = int(counts[id])
					ch = {"water": "~", "forest": "f", "stone": "^", "dirt": ":", "cobble": "=", "bridge": "H", "bridge_h": "H"}.get(id, ".")
			if not world.town_at(Vector2i(x + 2, y + 2), 0).is_empty() and ch != "~":
				ch = "T"
			line += ch
		print(line)

	var marks := {}
	for pawn in town.pawns:
		marks[pawn.tile] = "n" if pawn.adult else "c"
	for pawn in household.pawns:
		marks[pawn.tile] = "@"
	var chosen: Dictionary = world.towns[clampi(shown - 1, 0, world.towns.size() - 1)]
	var rect: Rect2i = chosen["rect"]
	print("%s, %s" % [chosen["name"], rect])
	for y in range(rect.position.y, rect.end.y):
		var line := ""
		for x in range(rect.position.x, rect.end.x):
			var tile := Vector2i(x, y)
			var ch := "."
			match world.get_tile_id(x, y):
				"dirt": ch = ":"
				"water": ch = "~"
				"forest": ch = "f"
				"stone": ch = "^"
				"cobble": ch = "="
				"bridge", "bridge_h": ch = "H"
			var placed := world.object_at(tile)
			if world.floor_at(tile) != "":
				ch = ","
			if placed != null:
				ch = {"wall": "#", "stone_wall": "S", "door": "+", "bed": "b", "grave": "x", "lantern_post": "i", "flower_bed": "*", "bush": "%", "market_stall": "m", "well": "O"}.get(placed.def_id, "o")
			if world.lot.has_point(tile) and ch == ".":
				ch = "_"
			if marks.has(tile):
				ch = marks[tile]
			line += ch
		print(line)
	get_tree().quit()
