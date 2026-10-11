class_name SaveGame
extends RefCounted
## Saves and loads the whole game as one JSON file.
##
## Because the simulation state is plain data (WorldState, Household and GameClock all
## turn into Dictionaries), a save is just those dictionaries written out. As new
## systems are added (needs, relationships) each one adds its own section.
##
## Older saves still load: format 1 had no household (the caller makes one), and formats 1 and 2
## had no objects or needs (the caller places a camp, and the simulation fills in the needs).

const FORMAT_VERSION := 3


## Writes the save file. Returns OK or a Godot error code.
static func save(path: String, world: WorldState, household: Household = null) -> Error:
	var data := {
		"format": FORMAT_VERSION,
		"world": world.to_dict(),
		"clock": GameClock.to_dict(),
	}
	if household != null:
		data["household"] = household.to_dict()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.close()
	return OK


## Loads a save and restores the clock. Returns
## { "ok": bool, "error": String, "world": WorldState, "household": Household or null }.
static func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { "ok": false, "error": "No save file found" }
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return { "ok": false, "error": "Save file is damaged" }
	var format := int(parsed.get("format", 0))
	if format < 1 or format > FORMAT_VERSION:
		return { "ok": false, "error": "Save file is from a different version" }
	var world := WorldState.from_dict(parsed.get("world", {}))
	GameClock.from_dict(parsed.get("clock", {}))
	var household: Household = null
	if parsed.get("household") is Dictionary:
		household = Household.from_dict(parsed["household"])
	return { "ok": true, "world": world, "household": household }
