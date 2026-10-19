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
## "floor.<id>" and "roof.<id>" entries: "file", and "tiles": how many tiles across the picture is.
## "wall.<object id>" entries: "top" and "face" (the wall's top seen from above, and its south face),
## and "tiles".

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
	var chosen := str(files[mini(floori(ObjectArt.hash01(cell.x, cell.y, 977) * files.size()), files.size() - 1)])
	if entry.has("stages"):  # crops: a picture for each stage of the year
		chosen = str((entry["stages"] as Array)[clampi(ObjectArt.crop_stage(), 0, (entry["stages"] as Array).size() - 1)])
	var texture_here := texture(chosen)
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


## Draws an object's picture shrunk to fit `box` (for the build palette), or returns false when it has none.
static func draw_object_icon(ci: CanvasItem, def_id: String, box: Rect2) -> bool:
	var entry := object_entry(def_id)
	if entry.is_empty() or (entry["files"] as Array).is_empty():
		return false
	var picture := texture(str(entry["files"][0]))
	if picture == null:
		return false
	var size := picture.get_size()
	var scale := minf(box.size.x / size.x, box.size.y / size.y)
	var drawn := size * scale
	ci.draw_texture_rect(picture, Rect2(box.position + (box.size - drawn) * 0.5, drawn), false)
	return true


## Which piece of a floor picture belongs to `cell`: { "x", "y" (whether this repeat is turned about its
## edge), "region" (the piece, in the picture of that turning) }. The picture repeats mirrored so that it never
## shows a seam where one repeat meets the next.
static func floor_piece(picture_size: Vector2, tiles: int, cell: Vector2i) -> Dictionary:
	var piece := picture_size / float(tiles)
	var column := posmod(cell.x, tiles)
	var row := posmod(cell.y, tiles)
	var turned_x := posmod(floori(float(cell.x) / float(tiles)), 2) == 1
	var turned_y := posmod(floori(float(cell.y) / float(tiles)), 2) == 1
	# A turned repeat reads the picture backwards, which is the same as reading the turned picture forwards.
	return { "x": turned_x, "y": turned_y, "region": Rect2(Vector2(column, row) * piece, piece) }


## A picture turned about its vertical and/or horizontal middle (made once, then kept).
static func turned_texture(name: String, flip_x: bool, flip_y: bool) -> Texture2D:
	if not flip_x and not flip_y:
		return texture(name)
	var key := "%s|%s%s" % [name, "x" if flip_x else "", "y" if flip_y else ""]
	if _textures.has(key):
		return _textures[key]
	var original := texture(name)
	var made: Texture2D = null
	if original != null:
		var image := original.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			if flip_x:
				image.flip_x()
			if flip_y:
				image.flip_y()
			image.generate_mipmaps()
			made = ImageTexture.create_from_image(image)
	_textures[key] = made
	return made


## Draws a floor tile from its texture, taking the piece of the picture that belongs to `cell` so that
## neighbours join up. Returns false when there is none.
static func draw_floor(ci: CanvasItem, floor_id: String, rect: Rect2, cell: Vector2i) -> bool:
	return draw_surface(ci, "floor." + floor_id, "file", rect, cell)


## Draws a roof tile from its texture, like a floor ("roof.<id>": "file", "tiles"). False when there is none.
static func draw_roof(ci: CanvasItem, roof_id: String, rect: Rect2, cell: Vector2i) -> bool:
	return draw_surface(ci, "roof." + roof_id, "file", rect, cell)


## Whether a wall has painted textures ("wall.<object id>": "top", "face", "tiles").
static func has_wall(def_id: String) -> bool:
	if not enabled():
		return false
	var entry := DataRegistry.get_def("sprites", "wall." + def_id)
	return not entry.is_empty() and texture(str(entry.get("top", ""))) != null and texture(str(entry.get("face", ""))) != null


## Draws part of a surface's texture: `key` names the picture in the sprites entry `id`, `rect` is the
## whole tile and `part` the share of it to fill (0..1 across and down), so a wall's top and its face can
## each take their own strip of a tile. `turned` lays the picture a quarter round, its rows running down
## the map. `tint` shades it. Returns false, drawing nothing, when there is no picture.
static func draw_surface(ci: CanvasItem, id: String, key: String, rect: Rect2, cell: Vector2i,
		part: Rect2 = Rect2(0, 0, 1, 1), tint: Color = Color.WHITE, turned: bool = false) -> bool:
	if not enabled():
		return false
	var entry := DataRegistry.get_def("sprites", id)
	if entry.is_empty():
		return false
	var picture := texture(str(entry.get(key, "")))
	if picture == null:
		return false
	var tiles := maxi(1, int(entry.get("tiles", 4)))
	var along := Vector2i(cell.y, cell.x) if turned else cell  # the picture's own across and down
	var column := posmod(along.x, tiles)
	var row := posmod(along.y, tiles)
	var turned_x := posmod(floori(float(along.x) / float(tiles)), 2) == 1
	var turned_y := posmod(floori(float(along.y) / float(tiles)), 2) == 1
	var corner := Vector2(tiles - 1 - column if turned_x else column, tiles - 1 - row if turned_y else row)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for share in [part.position, Vector2(part.end.x, part.position.y), part.end, Vector2(part.position.x, part.end.y)]:
		points.append(rect.position + share * rect.size)
		var inside: Vector2 = Vector2(share.y, share.x) if turned else share
		if turned_x:  # a mirrored repeat, so no seam shows where repeats meet
			inside.x = 1.0 - inside.x
		if turned_y:
			inside.y = 1.0 - inside.y
		uvs.append((corner + inside) / float(tiles))
	ci.draw_polygon(points, PackedColorArray([tint, tint, tint, tint]), uvs, picture)
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
static func draw_person(ci: CanvasItem, look: Dictionary, facing: Vector2i, u: float, phase: float, lying: bool, outfit: Dictionary, breath: float) -> bool:
	if not people_enabled():
		return false
	var stage := str(outfit.get("stage", "adult"))
	if stage == "baby":
		return false
	var seed_value := int(outfit.get("seed", 0))
	if draw_layered_person(ci, look, facing, u, phase, lying, outfit, breath, stage, seed_value):
		return true
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


## The set of layered pictures for someone of this stage and sex (body and outfit layers that stack), or {}.
static func person_set(stage: String, gender: String) -> Dictionary:
	for entry in DataRegistry.get_list("sprites"):
		if str(entry["id"]).begins_with("people.") and str(entry["stage"]) == stage and str(entry["gender"]) in [gender, "any"]:
			return entry
	return {}


## The body look in a set that is closest to a person's hair and skin.
static func pick_look(entry: Dictionary, look: Dictionary) -> Dictionary:
	var hair := Color(str(look.get("hair", "#4a3220")))
	var skin := Color(str(look.get("skin", "#e0ac80")))
	var best: Dictionary = (entry["looks"] as Array)[0]
	var best_score := INF
	for candidate: Dictionary in entry["looks"]:
		var h := Color(str(candidate["hair"]))
		var k := Color(str(candidate["skin"]))
		var score := _gap(hair, h) + 0.7 * _gap(skin, k)
		if score < best_score:
			best_score = score
			best = candidate
	return best


static func _gap(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## The garment this set has for what is asked: itself, or the same slot of a likeness (work clothes for a set
## with only everyday ones), or "".
static func garment_in(entry: Dictionary, garment_id: String, slot: String) -> String:
	if garment_id == "":
		return ""
	var have: Array = entry.get("garments", [])
	if garment_id in have:
		return garment_id
	var outfit_id := garment_id.trim_suffix("_" + slot)
	for alternative in OUTFIT_FALLBACKS.get(outfit_id, []):
		if "%s_%s" % [alternative, slot] in have:
			return "%s_%s" % [alternative, slot]
	return ""


## The layer worn for an outfit in a set: the outfit itself, a likeness, or "" (the bare body: underclothes).
static func layer_for(entry: Dictionary, outfit_id: String) -> String:
	if outfit_id in ["undergarments", "swim"]:
		return ""
	var order: Array = [outfit_id]
	order.append_array(OUTFIT_FALLBACKS.get(outfit_id, []))
	for candidate in order:
		if str(candidate) in entry["outfits"]:
			return str(candidate)
	return "casual" if "casual" in entry["outfits"] else ""


## The hair styles a set of people can wear: [{ "id", "name" }], each a picture of the hair on its own (grey, to be
## tinted any colour), or [] for a set whose bodies are painted with their hair (see tools/split_hair.py).
static func hair_styles(set_id: String) -> Array:
	var entry := DataRegistry.get_def("hairstyles", "hair." + set_id.trim_prefix("people."))
	return entry.get("styles", []) if not entry.is_empty() else []


## The folder the hair pictures of a set are in: its own, or another set's whose heads are in the same place (maternity
## pictures wear the women's hair).
static func hair_folder(entry: Dictionary) -> String:
	var data := DataRegistry.get_def("hairstyles", "hair." + str(entry.get("id", "")).trim_prefix("people."))
	return str(data.get("hair_dir", entry.get("dir", "")))


## The hair style someone wears: the one chosen (`look["hairdo"]`, "none" for none), else one that goes with who they
## are: the styles made for their sex (data/hairstyles.json says "for": "female" of long hair for the girls) and one
## of those picked by who the person is.
static func hairdo_for(styles: Array, look: Dictionary, gender: String, seed_value: int) -> String:
	var wanted := str(look.get("hairdo", ""))
	if wanted == "none":
		return ""
	for style: Dictionary in styles:
		if str(style["id"]) == wanted:
			return wanted
	var fitting: Array[String] = []
	for style: Dictionary in styles:
		if str(style.get("for", gender)) == gender:
			fitting.append(str(style["id"]))
	if fitting.is_empty():
		return str(styles[0]["id"])
	return fitting[posmod(seed_value >> 3, fitting.size())]


## The body in a set that is closest to a person's skin (the hair is chosen apart from it).
static func pick_body(entry: Dictionary, look: Dictionary) -> Dictionary:
	var skin := Color(str(look.get("skin", "#e0ac80")))
	var best: Dictionary = (entry["looks"] as Array)[0]
	var best_score := INF
	for candidate: Dictionary in entry["looks"]:
		var score := _gap(skin, Color(str(candidate["skin"])))
		if score < best_score:
			best_score = score
			best = candidate
	return best


## Draws a person from layers: the body (its skin tinted toward theirs), their hair (behind the head and over it, tinted
## to their hair colour) and the clothes, each a picture of its own, so any of them can change without the others.
## Walks and works in parts (see PersonRig); in bed shows head and shoulders over the blanket. False when there is no
## set for them.
static func draw_layered_person(ci: CanvasItem, look: Dictionary, facing: Vector2i, u: float, phase: float, lying: bool, outfit: Dictionary, breath: float, stage: String, seed_value: int) -> bool:
	var entry := {}
	if float(outfit.get("bump", 0.0)) > 0.3 and str(outfit.get("gender", "")) == "female":  # heavy with child: maternity pictures
		entry = person_set(stage, "pregnant")
	if entry.is_empty():
		entry = person_set(stage, str(outfit.get("gender", "male")))
	if entry.is_empty():
		return false
	var styles := hair_styles(str(entry["id"]))
	var layered := not styles.is_empty()
	var kind := PawnArt.facing_kind(facing)
	var side := "back" if kind == PawnArt.NORTH and not lying else "front"
	var folder := "%s/" % str(entry["dir"])
	var chosen_look := pick_body(entry, look) if layered else pick_look(entry, look)
	var body := texture(folder + ("bare_" + str(chosen_look["id"]) if layered else str(chosen_look["body"])) + "_" + side)
	if body == null and layered:  # no bare picture yet: the body as painted, hair and all
		layered = false
		chosen_look = pick_look(entry, look)
		body = texture(folder + str(chosen_look["body"]) + "_" + side)
	if body == null:
		return false
	var hair_over: Texture2D = null
	var hair_behind: Texture2D = null
	if layered:
		var hairdo := hairdo_for(styles, look, str(outfit.get("gender", "")), seed_value)
		if hairdo != "":
			var hair_dir := hair_folder(entry) + "/"
			hair_over = texture(hair_dir + "hair_" + hairdo + "_" + side)
			hair_behind = texture(hair_dir + "hairb_" + hairdo + "_" + side)
	else:
		hair_over = girl_hair(entry, outfit, side)
	var rig := PersonRig.rig_for(str(entry["id"]))
	var cloths: Array = []  # { "tex", "name" }, the lower ones first so the top lies over them
	var hair_under := false  # under a garment that covers the head (a nightcap), else over the clothes
	if outfit.has("pieces") and entry.has("garments"):
		for slot in ["bottom", "feet", "top"]:
			var garment_id := garment_in(entry, str((outfit["pieces"] as Dictionary).get(slot, "")), slot)
			if garment_id != "":
				var piece := texture(folder + "g_" + garment_id + "_" + side)
				if piece != null:
					cloths.append({ "tex": piece, "name": garment_id, "slot": slot })
					hair_under = hair_under or garment_id in entry.get("hair_under", [])
	else:
		var layer_id := layer_for(entry, str(outfit.get("clothes", "casual")))
		var whole: Texture2D = texture(folder + layer_id + "_" + side) if layer_id != "" else null
		if whole != null:
			cloths.append({ "tex": whole, "name": layer_id, "slot": "" })
	var fallen := bool(outfit.get("fallen", false))
	var swing := sin(phase) if phase != 0.0 and not lying else 0.0
	var squash := 1.0 + 0.045 * absf(swing) if phase != 0.0 else 1.0 + 0.012 * sin(breath)
	var height := PERSON_HEIGHT * u * squash
	var width := body.get_width() * PERSON_HEIGHT * u / body.get_height()
	var tilt := kind == PawnArt.EAST or kind == PawnArt.WEST
	if tilt:
		width *= 0.9
	var flip := -1.0 if kind == PawnArt.WEST else 1.0
	var skin := Color(str(look.get("skin", "#e0ac80")))
	var base_skin := Color(str(chosen_look.get("skin", "#f0b890")))
	var body_tint := Color(clampf(skin.r / base_skin.r, 0.4, 1.25), clampf(skin.g / base_skin.g, 0.4, 1.25), clampf(skin.b / base_skin.b, 0.4, 1.25))
	var shade := 1.0 - 0.06 * ObjectArt.hash01(seed_value, 3, 71)
	var tint := Color(shade, shade, shade)
	if outfit.get("ill", false):
		tint = tint.lerp(PawnArt.ILL_TINT, 0.30)
	var hair_tint: Color
	if layered:  # their own colour, going grey and then white with the years
		hair_tint = Color(str(look.get("hair", "#4a3220"))).lerp(Color(0.88, 0.88, 0.88), float(outfit.get("grey", 0.0))) * tint
	else:
		hair_tint = Color(str(chosen_look.get("hair", "#4a3220"))) * body_tint * tint  # as the body's own hair is drawn
	var layers: Array = []
	if hair_behind != null:
		layers.append({ "tex": hair_behind, "tint": hair_tint, "mode": "upper" })
	layers.append({ "tex": body, "tint": body_tint * tint, "mode": "full" })
	if hair_over != null and hair_under:
		layers.append({ "tex": hair_over, "tint": hair_tint, "mode": "upper" })
	for cloth: Dictionary in cloths:
		# a top hangs below the hip and a skirt goes in one piece between the legs: neither is split with them
		layers.append({ "tex": cloth["tex"], "tint": tint, "mode": "skirt" if str(cloth["slot"]) == "top" or PersonRig.is_skirt(rig, str(cloth["name"])) else "full" })
	if hair_over != null and not hair_under:
		layers.append({ "tex": hair_over, "tint": hair_tint, "mode": "upper" })
	var feet := 14.0 * u - absf(swing) * 1.6 * u
	var sway := swing * 1.1 * u
	ci.draw_colored_polygon(PawnArt._ellipse_points(Vector2(2.0 * u, 13.0 * u), Vector2(12.0 * u, 5.0 * u)), SHADOW)
	var top := feet - height
	var rect := Rect2(Vector2(-width * 0.5 * flip + sway, top), Vector2(width * flip, height))
	if lying and not fallen:  # in bed: head and shoulders over the blanket
		var shown := 0.58
		rect = Rect2(-width * 0.5, -25.0 * u, width, height * shown)
		for layer: Dictionary in layers:
			var picture: Texture2D = layer["tex"]
			ci.draw_texture_rect_region(picture, rect, Rect2(Vector2.ZERO, Vector2(picture.get_width(), picture.get_height() * shown)), layer["tint"])
		return true
	var act := str(outfit.get("act", ""))
	if not rig.is_empty() and not fallen and not bool(outfit.get("mounted", false)) and (phase != 0.0 or act != ""):
		var base := Transform2D(Vector2(flip, 0.0), Vector2(0.0, 1.0), Vector2(sway, 0.0))
		PersonRig.draw(ci, layers, rig, base, Rect2(Vector2(-width * 0.5, top), Vector2(width, height)), PersonRig.motion(phase, act, float(outfit.get("clock", 0.0)), u))
		return true
	for layer: Dictionary in layers:
		ci.draw_texture_rect(layer["tex"], rect, false, layer["tint"])
	return true


## The long hair a girl wears over a set's body when the set is shared with boys (children and youths), or null.
## It is grey, to be tinted with the look's hair.
static func girl_hair(entry: Dictionary, outfit: Dictionary, side: String) -> Texture2D:
	if str(outfit.get("gender", "")) != "female" or not entry.has("girl_hair"):
		return null
	return texture("%s/%s_%s" % [str(entry["dir"]), str(entry["girl_hair"]), side])


## Draws an animal as a picture (drawn side-on, facing right, turned to face west), bobbing as it walks.
## `origin` is where its middle is. False when there is none.
static func draw_animal(ci: CanvasItem, kind: String, facing: Vector2i, u: float, phase: float, origin: Vector2) -> bool:
	if not enabled():
		return false
	var entry := DataRegistry.get_def("sprites", "animal." + kind)
	if entry.is_empty():
		return false
	var picture := texture(str(entry["file"]))
	if picture == null:
		return false
	var length := float((DataRegistry.get_def("animals", kind).get("art", {}).get("body", [20, 10]) as Array)[0])
	var width := (length + 12.0) * u * 1.15
	var height := width * picture.get_height() / picture.get_width()
	var swing := sin(phase) if phase != 0.0 else 0.0
	var flip := -1.0 if facing.x < 0 else 1.0
	ci.draw_set_transform(origin, 0.0, Vector2.ONE)
	ci.draw_colored_polygon(PawnArt._ellipse_points(Vector2(0.0, 3.0 * u), Vector2(width * 0.38, 3.5 * u)), SHADOW)
	ci.draw_texture_rect(picture, Rect2(Vector2(-width * 0.5 * flip, 4.0 * u - height - absf(swing) * 1.4 * u), Vector2(width * flip, height)), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
