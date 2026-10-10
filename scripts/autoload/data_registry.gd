extends Node
## Loads all game content from JSON files and serves it to the rest of the game.
##
## Every file in res://data/ is a JSON array of entries. The file name is the
## "kind" of content (tiles.json -> "tiles") and every entry needs a unique "id".
##
## Mods are folders inside res://mods/ (during development) or user://mods/
## (in a built game). A mod folder can hold the same kinds of JSON files, plus an
## optional mod.json. Mod entries are matched by id: a new id adds content, an
## existing id replaces the base entry, and {"id": "x", "_remove": true} deletes it.
## A mod can also add a brand new kind just by shipping a new <kind>.json file.
##
## mod.json (all fields optional):
##   { "name": "My Mod", "enabled": true, "load_order": 0 }

const BASE_DATA_DIR := "res://data"
const MOD_DIRS: Array[String] = ["res://mods", "user://mods"]

## Names of the mods that were loaded, in load order.
var loaded_mods: Array[String] = []
## Human readable problems found while loading (bad JSON, missing ids...).
var load_errors: Array[String] = []

var _defs: Dictionary = {}   # kind -> { id -> entry }
var _order: Dictionary = {}  # kind -> [ids in load order]


func _ready() -> void:
	reload()


## Clears everything and loads base data, then every enabled mod.
func reload() -> void:
	_defs.clear()
	_order.clear()
	loaded_mods.clear()
	load_errors.clear()

	_load_folder(BASE_DATA_DIR, "base game")
	for mod in _discover_mods():
		_load_folder(mod["path"], "mod '%s'" % mod["name"])
		loaded_mods.append(mod["name"])

	for message in load_errors:
		push_warning("DataRegistry: " + message)


func get_kinds() -> Array:
	return _defs.keys()


func has_def(kind: String, id: String) -> bool:
	return _defs.has(kind) and _defs[kind].has(id)


## Returns the entry, or an empty Dictionary if it does not exist.
func get_def(kind: String, id: String) -> Dictionary:
	if not has_def(kind, id):
		return {}
	return _defs[kind][id]


## All entries of a kind, in load order.
func get_list(kind: String) -> Array:
	var result: Array = []
	for id in get_ids(kind):
		result.append(_defs[kind][id])
	return result


func get_ids(kind: String) -> Array:
	if not _order.has(kind):
		return []
	return _order[kind]


func count(kind: String) -> int:
	return get_ids(kind).size()


# --- loading -----------------------------------------------------------------

func _discover_mods() -> Array:
	var found: Array = []
	for root in MOD_DIRS:
		if not DirAccess.dir_exists_absolute(root):
			continue
		for folder in DirAccess.get_directories_at(root):
			var path := root.path_join(folder)
			var info: Dictionary = {}
			var parsed: Variant = _read_json(path.path_join("mod.json"))
			if parsed is Dictionary:
				info = parsed
			if not bool(info.get("enabled", true)):
				continue
			found.append({
				"name": String(info.get("name", folder)),
				"path": path,
				"order": int(info.get("load_order", 0)),
			})
	found.sort_custom(func(a, b):
		if a["order"] != b["order"]:
			return a["order"] < b["order"]
		return a["name"] < b["name"])
	return found


func _load_folder(dir_path: String, source: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	for file_name in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".json") or file_name == "mod.json":
			continue
		var kind := file_name.get_basename()
		var parsed: Variant = _read_json(dir_path.path_join(file_name))
		if not (parsed is Array):
			load_errors.append("%s: %s must contain a JSON array" % [source, file_name])
			continue
		_merge_entries(kind, parsed, source, file_name)


func _merge_entries(kind: String, entries: Array, source: String, file_name: String) -> void:
	if not _defs.has(kind):
		_defs[kind] = {}
		_order[kind] = []
	for entry in entries:
		if not (entry is Dictionary) or not entry.has("id"):
			load_errors.append("%s: an entry in %s has no \"id\"" % [source, file_name])
			continue
		var id := String(entry["id"])
		if entry.get("_remove", false):
			_defs[kind].erase(id)
			_order[kind].erase(id)
			continue
		if not _defs[kind].has(id):
			_order[kind].append(id)
		_defs[kind][id] = entry


## Returns the parsed JSON, or null if the file is missing or invalid.
func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	var err := json.parse(FileAccess.get_file_as_string(path))
	if err != OK:
		load_errors.append("%s (line %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
