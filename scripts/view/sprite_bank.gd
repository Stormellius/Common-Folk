class_name SpriteBank
extends RefCounted
## Painted pictures (made with SpriteCook, cut from the sheets in assets/source by tools/build_art.py)
## that stand in for the code-drawn art. data/sprites.json says which picture or pictures an object
## or a floor uses; anything it does not mention is still drawn by code, and so is everything when the
## player chooses the code-drawn look in Settings, or a picture file is missing.
##
## "object.<id>" entries: "files" (a picture is chosen from the list by the tile it stands on),
## "fit" (the box in tiles it is scaled to fit), "base" (where its bottom edge sits, in tiles below
## the tile's middle), "flip" (may be turned round), "shadow" (false for flat things).
## "floor.<id>" entries: "file", and "tiles": how many tiles across the picture is.

const SHADOW := Color(0, 0, 0, 0.20)

static var _textures: Dictionary = {}


## Whether painted art is in use at all (the player's choice in Settings).
static func enabled() -> bool:
	return Settings.illustrated_art


## A picture by its name under assets/art (no extension), or null if there is no such file.
static func texture(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	var path := "res://assets/art/%s.png" % name
	var loaded: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_textures[name] = loaded
	return loaded


static func object_entry(def_id: String) -> Dictionary:
	return DataRegistry.get_def("sprites", "object." + def_id) if enabled() else {}


## Whether this kind of object has a painted picture to draw.
static func has_object(def_id: String) -> bool:
	var entry := object_entry(def_id)
	return not entry.is_empty() and not (entry["files"] as Array).is_empty() and texture(str((entry["files"] as Array)[0])) != null


## Draws an object's picture centred on the tile (`u` is tile size over 48). Returns false, and
## draws nothing, when it has none (the caller then draws it with code).
static func draw_object(ci: CanvasItem, def_id: String, u: float, cell: Vector2i) -> bool:
	var entry := object_entry(def_id)
	if entry.is_empty():
		return false
	var files: Array = entry["files"]
	if files.is_empty():
		return false
	var texture_here := texture(str(files[mini(floori(ObjectArt.hash01(cell.x, cell.y, 977) * files.size()), files.size() - 1)]))
	if texture_here == null:
		return false
	var tile := 48.0 * u
	var fit: Array = entry.get("fit", [1.0, 1.0])
	var size := texture_here.get_size()
	var scale := minf(float(fit[0]) * tile / size.x, float(fit[1]) * tile / size.y)
	var drawn := size * scale
	var bottom := float(entry.get("base", 0.5)) * tile
	var flipped := bool(entry.get("flip", false)) and ObjectArt.hash01(cell.x, cell.y, 983) < 0.5
	if bool(entry.get("shadow", true)):
		ci.draw_colored_polygon(PawnArt._ellipse_points(Vector2(0.0, bottom - 2.5 * u), Vector2(drawn.x * 0.42, 3.4 * u)), SHADOW)
	if flipped:
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	ci.draw_texture_rect(texture_here, Rect2(-drawn.x * 0.5, bottom - drawn.y, drawn.x, drawn.y), false)
	if flipped:
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


## Draws a floor tile from its texture, taking the piece of the picture that belongs to `cell` so that
## neighbours join up. The picture repeats mirrored (each repeat turned about its edge), so that it
## never shows a seam where one repeat meets the next. Returns false when there is none.
static func draw_floor(ci: CanvasItem, floor_id: String, rect: Rect2, cell: Vector2i) -> bool:
	if not enabled():
		return false
	var entry := DataRegistry.get_def("sprites", "floor." + floor_id)
	if entry.is_empty():
		return false
	var picture := texture(str(entry["file"]))
	if picture == null:
		return false
	var tiles := maxi(1, int(entry.get("tiles", 4)))
	var piece := picture.get_size() / float(tiles)
	var column := posmod(cell.x, tiles)
	var row := posmod(cell.y, tiles)
	var turned_x := posmod(floori(float(cell.x) / float(tiles)), 2) == 1
	var turned_y := posmod(floori(float(cell.y) / float(tiles)), 2) == 1
	var source := Rect2(Vector2(tiles - 1 - column if turned_x else column, tiles - 1 - row if turned_y else row) * piece, piece)
	var target := rect
	if turned_x:
		target = Rect2(Vector2(target.end.x, target.position.y), Vector2(-target.size.x, target.size.y))
	if turned_y:
		target = Rect2(Vector2(target.position.x, target.end.y), Vector2(target.size.x, -target.size.y))
	ci.draw_texture_rect_region(picture, target, source)
	return true


# --- people ----------------------------------------------------------------------------------

## What to wear instead, in order, when there is no picture of someone in an outfit at their age.
const OUTFIT_FALLBACKS := {
	"casual": ["worker"],
	"worker": ["casual"],
	"warm": ["winter", "casual", "worker"],
	"winter": ["warm", "casual", "worker"],
	"sleepwear": ["undergarments"],
	"swim": ["undergarments"],
}
const PERSON_HEIGHT := 46.0  # a grown person, in units of 48 to the tile


## Whether painted people are in use (a preview, off unless the player turns it on).
static func people_enabled() -> bool:
	return enabled() and Settings.painted_characters


## The picture set for someone of this stage in these clothes: { "front", "back" (maybe) }, or empty when
## there is none (babies, and a stage with no picture in any outfit that will do, are drawn by code).
static func person_variant(stage: String, outfit_id: String, seed_value: int) -> Dictionary:
	var order: Array = [outfit_id]
	order.append_array(OUTFIT_FALLBACKS.get(outfit_id, []))
	for candidate in order:
		var entry := DataRegistry.get_def("sprites", "pawn.%s.%s" % [stage, candidate])
		if not entry.is_empty() and not (entry["variants"] as Array).is_empty():
			var variants: Array = entry["variants"]
			return variants[posmod(seed_value >> 3, variants.size())]
	return {}


## Draws a person as a picture, walking with a bounce and squash (`phase`) and breathing when still, and
## in bed showing only head and shoulders. Returns false (drawing nothing) when there is no picture, or
## painted people are not in use, and the caller then draws them with code.
static func draw_person(ci: CanvasItem, facing: Vector2i, u: float, phase: float, lying: bool, outfit: Dictionary, breath: float) -> bool:
	if not people_enabled():
		return false
	var stage := str(outfit.get("stage", "adult"))
	if stage == "baby":
		return false
	var seed_value := int(outfit.get("seed", 0))
	var variant := person_variant(stage, str(outfit.get("clothes", "casual")), seed_value)
	if variant.is_empty():
		return false
	var kind := PawnArt.facing_kind(facing)
	var behind := kind == PawnArt.NORTH and not lying
	var file := str(variant["back"]) if behind and variant.has("back") else str(variant["front"])
	var picture := texture(file)
	if picture == null:
		return false
	var fallen := bool(outfit.get("fallen", false))
	var swing := sin(phase) if phase != 0.0 and not lying else 0.0
	var squash := 1.0 + 0.045 * absf(swing) if phase != 0.0 else 1.0 + 0.012 * sin(breath)
	var height := PERSON_HEIGHT * u * squash
	var width := picture.get_width() * PERSON_HEIGHT * u / picture.get_height()
	var side := kind == PawnArt.EAST or kind == PawnArt.WEST
	if side:
		width *= 0.9
	var flip := -1.0 if kind == PawnArt.WEST else 1.0
	var tint := Color.WHITE.darkened(0.04 - 0.10 * ObjectArt.hash01(seed_value, 3, 71))
	if outfit.get("ill", false):
		tint = tint.lerp(PawnArt.ILL_TINT, 0.30)
	var feet := 14.0 * u - absf(swing) * 1.6 * u
	var sway := swing * 1.1 * u
	ci.draw_colored_polygon(PawnArt._ellipse_points(Vector2(2.0 * u, 13.0 * u), Vector2(12.0 * u, 5.0 * u)), SHADOW)
	if lying and not fallen:  # tucked up in bed: head and shoulders over the blanket
		var shown := 0.58
		ci.draw_texture_rect_region(picture, Rect2(-width * 0.5, -25.0 * u, width, height * shown), Rect2(Vector2.ZERO, Vector2(picture.get_width(), picture.get_height() * shown)), tint)
		return true
	ci.draw_texture_rect(picture, Rect2(Vector2(-width * 0.5 * flip + sway, feet - height), Vector2(width * flip, height)), false, tint)
	return true
