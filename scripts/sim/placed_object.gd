class_name PlacedObject
extends RefCounted
## One thing standing in the world (a bed, a cooking pot). What it is and does comes from
## its definition in data/objects.json; this is just the instance: which one, and where.

var id := 0
var def_id := ""
var tile := Vector2i.ZERO
## The pawn who is using it or on the way to use it; 0 when free. Only one at a time.
var user_id := 0


func def() -> Dictionary:
	return DataRegistry.get_def("objects", def_id)


func display_name() -> String:
	return str(def().get("name", def_id))


func blocks_walking() -> bool:
	return bool(def().get("blocks_walking", true))


func to_dict() -> Dictionary:
	return { "id": id, "def": def_id, "tile": [tile.x, tile.y], "user": user_id }


static func from_dict(data: Dictionary) -> PlacedObject:
	var placed := PlacedObject.new()
	placed.id = int(data.get("id", 0))
	placed.def_id = str(data.get("def", ""))
	var saved_tile: Variant = data.get("tile", [0, 0])
	if saved_tile is Array and saved_tile.size() >= 2:
		placed.tile = Vector2i(int(saved_tile[0]), int(saved_tile[1]))  # JSON numbers load as floats
	placed.user_id = int(data.get("user", 0))
	return placed
