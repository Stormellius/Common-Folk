class_name CampGenerator
extends RefCounted
## Sets out the household's starting belongings near the crossroads: a bed for each person
## and one each of the shared things. Until the player can build, this is what gives people
## something to use. It skips any object that a mod has removed from data/objects.json.

const SHARED := [
	["cooking_pot", Vector2i(3, -3)],
	["hearth", Vector2i(5, -3)],
	["wash_basin", Vector2i(3, 3)],
	["chamber_pot", Vector2i(6, 3)],
	["lute", Vector2i(-4, 3)],
]
const BED_ROW_START := Vector2i(-6, -3)
const SEARCH_RADIUS := 8


static func place(world: WorldState, household: Household) -> void:
	var center := Vector2i(world.width / 2, world.height / 2)
	var inside := Rect2i()
	if world.lot.size != Vector2i.ZERO:
		center = world.lot.get_center()  # set out on the home lot, when there is one
		inside = world.lot
	for i in household.pawns.size():
		_put(world, "bed", center, BED_ROW_START + Vector2i(2 * i, 0), inside)
	for entry in SHARED:
		_put(world, str(entry[0]), center, entry[1], inside)


## Puts the object at the wanted spot, or the nearest free tile if that one is taken.
## With `inside` set, stays within that rectangle; without, keeps the two roads through the middle clear.
static func _put(world: WorldState, def_id: String, center: Vector2i, offset: Vector2i, inside: Rect2i = Rect2i()) -> void:
	if not DataRegistry.has_def("objects", def_id):
		return
	var wanted := center + offset
	for radius in SEARCH_RADIUS + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var tile := wanted + Vector2i(dx, dy)
				if inside.size != Vector2i.ZERO:
					if not inside.has_point(tile):
						continue
				elif tile.x == center.x or tile.y == center.y:
					continue
				if world.add_object(def_id, tile) != null:
					return
