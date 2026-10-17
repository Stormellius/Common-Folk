class_name SaveSlots
extends RefCounted
## Where saves live and what each one is: any number of named saves in user://saves/, plus the
## quick save (F5) and the last few autosaves. Next to every save is a small ".meta" file (whose
## family, the date in the game, when it was saved) so the load list can be shown without reading
## whole saves, and, once it has been saved over, the copy it replaced (see SaveGame.BACKUP).

const DIR := "user://saves"
const QUICK := "user://savegame.json"
## The autosaves, newest first: each morning's pushes the others down and the oldest is dropped,
## so a bad day (or a damaged file) still leaves the days before it to go back to.
const AUTOS: Array[String] = ["user://autosave.json", "user://autosave_2.json", "user://autosave_3.json"]
const AUTO := "user://autosave.json"  # the newest of them


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
	if FileAccess.file_exists(QUICK):
		found.append(_entry(QUICK, "quick"))
	for path in AUTOS:
		if FileAccess.file_exists(path):
			found.append(_entry(path, "auto"))
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


## Makes room for a new autosave: each one moves down a place, and the oldest is dropped.
static func shift_autosaves(paths: Array[String] = AUTOS) -> void:
	remove(paths[-1])
	for i in range(paths.size() - 1, 0, -1):
		for suffix in ["", ".meta"]:
			if FileAccess.file_exists(paths[i - 1] + suffix):
				DirAccess.rename_absolute(paths[i - 1] + suffix, paths[i] + suffix)
	remove(paths[0])  # a stale backup of the newest would only bring back an older day


static func remove(save_path: String) -> void:
	for suffix in ["", ".meta", SaveGame.BACKUP]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)


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
