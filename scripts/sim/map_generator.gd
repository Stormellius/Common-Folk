class_name MapGenerator
extends RefCounted
## Builds a terrain map from a seed. The same seed always gives the same world.
##
## This is the first layer of world generation (terrain only). Roads, lots,
## building templates and NPCs come later and will be added as further steps
## that read and write the same WorldState.

const CLEARING_RADIUS := 12  # flat area kept free in the middle for the future town


static func generate(world_seed: int, width: int, height: int) -> WorldState:
	var world := WorldState.new(width, height, world_seed)

	var elevation := FastNoiseLite.new()
	elevation.seed = world_seed
	elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation.frequency = 0.035
	elevation.fractal_octaves = 3

	var trees := FastNoiseLite.new()
	trees.seed = world_seed + 1337
	trees.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	trees.frequency = 0.09

	var center := Vector2(width / 2.0, height / 2.0)
	for y in height:
		for x in width:
			var e := elevation.get_noise_2d(x, y)
			var t := trees.get_noise_2d(x, y)
			var tile_id := "grass"
			if e < -0.30:
				tile_id = "water"
			elif e < -0.22:
				tile_id = "dirt"  # muddy shoreline
			elif e > 0.38:
				tile_id = "stone"
			elif t > 0.20:
				tile_id = "forest"
			if Vector2(x, y).distance_to(center) < CLEARING_RADIUS:
				tile_id = "grass"
			world.set_tile(x, y, tile_id)

	# A simple crossroads through the clearing, a placeholder for the future town roads.
	var cx := floori(width / 2.0)
	var cy := floori(height / 2.0)
	for i in range(-CLEARING_RADIUS, CLEARING_RADIUS + 1):
		world.set_tile(cx + i, cy, "dirt")
		world.set_tile(cx, cy + i, "dirt")

	return world
