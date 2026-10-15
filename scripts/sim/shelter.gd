class_name Shelter
extends RefCounted
## What a roof is worth (data/shelter.json): indoors, people lose warmth more slowly; a bed under the
## open sky gives less rest, and sleeping in it is a hardship.


static func config() -> Dictionary:
	return DataRegistry.get_def("shelter", "shelter")


static func is_indoors(world: WorldState, tile: Vector2i) -> bool:
	return world.roofs.has(tile)


## `multipliers` with the roof's effect on need drain multiplied in, for someone standing indoors.
static func drain_multipliers(world: WorldState, pawn: Pawn, multipliers: Dictionary) -> Dictionary:
	if not world.roofs.has(pawn.tile):
		return multipliers
	var extra: Dictionary = config().get("roofed_drain_multipliers", {})
	if extra.is_empty():
		return multipliers
	var merged := multipliers.duplicate()
	for need_id in extra:
		merged[need_id] = float(merged.get(need_id, 1.0)) * float(extra[need_id])
	return merged


## How much of its rest a bed gives where it stands: less under the open sky.
static func rest_factor(world: WorldState, placed: PlacedObject, object_def: Dictionary) -> float:
	if str(object_def.get("pose", "")) == "lie" and not world.roofs.has(placed.tile):
		return float(config().get("open_sleep_rest", 0.75))
	return 1.0
