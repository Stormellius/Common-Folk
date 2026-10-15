class_name BuildSite
extends RefCounted
## One thing the player has planned to build and nobody has finished yet: an object, a floor or a
## roof tile on a tile of their land (see Construction). It says what it needs, how much of that has
## been carried to it, and how far the work has got.

var id := 0
## "object", "floor" or "roof".
var kind := "object"
## The object, floor or roof id (data/objects.json, floors.json, roofs.json).
var def_id := ""
var tile := Vector2i.ZERO
## Materials it takes, and what has been carried to it so far.
var needs: Dictionary = {}
var delivered: Dictionary = {}
## How many game minutes of work it takes an unskilled builder, and how far it has got, 0 to 1.
var minutes := 20
var progress := 0.0
## The person working on it (0 for nobody), and the coin paid for it (half comes back if it is cancelled).
var builder := 0
var paid := 0
## A finished object that someone is standing in the way of waits until this tick.
var wait_until := 0


## The materials still to be carried here.
func missing() -> Dictionary:
	var lacking := {}
	for resource_id in needs:
		var short := int(needs[resource_id]) - int(delivered.get(resource_id, 0))
		if short > 0:
			lacking[str(resource_id)] = short
	return lacking


func materials_ready() -> bool:
	return missing().is_empty()


func to_dict() -> Dictionary:
	return {
		"id": id, "kind": kind, "def": def_id, "tile": [tile.x, tile.y], "needs": needs.duplicate(), "delivered": delivered.duplicate(),
		"minutes": minutes, "progress": snappedf(progress, 0.001), "builder": builder, "paid": paid, "wait_until": wait_until,
	}


static func from_dict(data: Dictionary) -> BuildSite:
	var site := BuildSite.new()
	site.id = int(data.get("id", 0))
	site.kind = str(data.get("kind", "object"))
	site.def_id = str(data.get("def", ""))
	var saved_tile: Variant = data.get("tile", [0, 0])
	site.tile = Vector2i(int(saved_tile[0]), int(saved_tile[1])) if saved_tile is Array and saved_tile.size() >= 2 else Vector2i.ZERO
	for key in ["needs", "delivered"]:
		var saved: Variant = data.get(key, {})
		if saved is Dictionary:
			for resource_id in saved:
				(site.needs if key == "needs" else site.delivered)[str(resource_id)] = int(saved[resource_id])
	site.minutes = int(data.get("minutes", 20))
	site.progress = float(data.get("progress", 0.0))
	site.builder = int(data.get("builder", 0))
	site.paid = int(data.get("paid", 0))
	site.wait_until = int(data.get("wait_until", 0))
	return site
