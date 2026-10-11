class_name SaveGame
extends RefCounted
## Saves and loads the whole game as one JSON file.
##
## Because the simulation state is plain data (WorldState, Household and GameClock all
## turn into Dictionaries), a save is just those dictionaries written out. As new
## systems are added (needs, relationships) each one adds its own section.
##
## Older saves still load: format 1 had no household (the caller makes one), and formats 1 and 2
## had no objects or needs (the caller places a camp, and the simulation fills in the needs), and
## formats 1 to 3 had no lot or floors (the world gives a centered lot and no floors), and formats
## 1 to 4 had no town (no other lots and nobody living in them).

const FORMAT_VERSION := 5


## Writes the save file. Returns OK or a Godot error code. `view` is anything the screen wants
## remembered (the camera), handed back by load_from. The file is written next to the real one
## and moved into place, so a crash in the middle never leaves a half-written save.
static func save(path: String, world: WorldState, household: Household = null, view: Dictionary = {}, town: Household = null) -> Error:
	var data := {
		"format": FORMAT_VERSION,
		"world": world.to_dict(),
		"clock": GameClock.to_dict(),
		"view": view,
	}
	if household != null:
		data["household"] = household.to_dict()
	if town != null:
		data["town"] = town.to_dict()
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.close()
	return DirAccess.rename_absolute(temp_path, path)


## Of these save files, the one written most recently, or "" if none exists.
static func newest(paths: Array[String]) -> String:
	var best := ""
	var best_time := -1
	for path in paths:
		if FileAccess.file_exists(path):
			var modified := int(FileAccess.get_modified_time(path))
			if modified > best_time:
				best_time = modified
				best = path
	return best


## Loads a save and restores the clock. Returns
## { "ok": bool, "error": String, "world": WorldState, "household": Household or null, "town": Household or null, "view": Dictionary }.
## The clock is only touched once the whole file has proved readable.
static func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { "ok": false, "error": "No save file found" }
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return { "ok": false, "error": "Save file is damaged" }
	var parsed: Dictionary = json.data
	var format := int(parsed.get("format", 0))
	if format < 1 or format > FORMAT_VERSION:
		return { "ok": false, "error": "Save file is from a different version" }
	var saved_world: Variant = parsed.get("world")
	if not (saved_world is Dictionary) or int(saved_world.get("width", 0)) <= 0 or int(saved_world.get("height", 0)) <= 0:
		return { "ok": false, "error": "Save file is damaged" }
	var world := WorldState.from_dict(saved_world)
	GameClock.from_dict(parsed.get("clock", {}))
	var household: Household = null
	if parsed.get("household") is Dictionary:
		household = Household.from_dict(parsed["household"])
	var town: Household = null
	if parsed.get("town") is Dictionary:
		town = Household.from_dict(parsed["town"], NpcGenerator.FIRST_ID)
	var view: Variant = parsed.get("view", {})
	return { "ok": true, "world": world, "household": household, "town": town, "view": view if view is Dictionary else {} }
