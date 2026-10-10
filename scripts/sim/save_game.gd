class_name SaveGame
extends RefCounted
## Saves and loads the whole game as one JSON file.
##
## Because the simulation state is plain data (WorldState and GameClock both turn
## into Dictionaries), a save is just those dictionaries written out. As new
## systems are added (people, needs, relationships) each one adds its own section.

const FORMAT_VERSION := 1


## Writes the save file. Returns OK or a Godot error code.
static func save(path: String, world: WorldState) -> Error:
	var data := {
		"format": FORMAT_VERSION,
		"world": world.to_dict(),
		"clock": GameClock.to_dict(),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.close()
	return OK


## Loads a save and restores the clock. Returns { "ok": bool, "error": String, "world": WorldState }.
static func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { "ok": false, "error": "No save file found" }
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return { "ok": false, "error": "Save file is damaged" }
	if int(parsed.get("format", 0)) != FORMAT_VERSION:
		return { "ok": false, "error": "Save file is from a different version" }
	var world := WorldState.from_dict(parsed.get("world", {}))
	GameClock.from_dict(parsed.get("clock", {}))
	return { "ok": true, "world": world }
