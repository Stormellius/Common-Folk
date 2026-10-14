class_name SaveSlots
extends RefCounted
## Where saves live and what each one is: any number of named saves in user://saves/, plus the
## quick save (F5) and the autosave. Next to every save is a small ".meta" file (whose family, the
## date in the game, when it was saved) so the load list can be shown without reading whole saves.

const DIR := "user://saves"
const QUICK := "user://savegame.json"
const AUTO := "user://autosave.json"


## The file for a save called `slot_name`: the name with anything but letters, digits, spaces and
## dashes taken out, so any name the player types makes a safe file name.
static func slot_path(slot_name: String) -> String:
	var clean := ""
	for character in slot_name.strip_edges():
		clean += character if (character.is_valid_identifier() or character.is_valid_int() or character in " -") else "_"
	clean = clean.strip_edges().replace(" ", "_")
	return "%s/%s.json" % [DIR, clean if clean != "" else "save"]


## Every save there is, newest first: { "path", "kind" ("slot", "quick" or "auto"), "title", "meta",
## "modified" (unix time) }.
static func all() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for path in [QUICK, AUTO]:
		if FileAccess.file_exists(path):
			found.append(_entry(path, "quick" if path == QUICK else "auto"))
	var dir := DirAccess.open(DIR)
	if dir != null:
		for file_name in dir.get_files():
			if file_name.ends_with(".json"):
				found.append(_entry("%s/%s" % [DIR, file_name], "slot"))
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["modified"]) > int(b["modified"]))
	return found


## The newest save of any kind, or "".
static func newest() -> String:
	var saves := all()
	return str(saves[0]["path"]) if not saves.is_empty() else ""


static func read_meta(save_path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(save_path + ".meta")
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed if parsed is Dictionary else {}


static func write_meta(save_path: String, meta: Dictionary) -> Error:
	var file := FileAccess.open(save_path + ".meta", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(meta))
	file.close()
	return OK


## Makes sure the folder for named saves exists.
static func make_dir() -> Error:
	return DirAccess.make_dir_recursive_absolute(DIR)


static func remove(save_path: String) -> void:
	DirAccess.remove_absolute(save_path)
	if FileAccess.file_exists(save_path + ".meta"):
		DirAccess.remove_absolute(save_path + ".meta")


static func _entry(path: String, kind: String) -> Dictionary:
	var meta := read_meta(path)
	var title := str(meta.get("name", ""))
	if kind == "quick":
		title = "Quick save"
	elif kind == "auto":
		title = "Autosave"
	elif title == "":
		title = path.get_file().get_basename().replace("_", " ")
	return { "path": path, "kind": kind, "title": title, "meta": meta, "modified": int(FileAccess.get_modified_time(path)) }
