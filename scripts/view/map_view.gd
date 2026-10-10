class_name MapView
extends Node2D
## Draws the terrain of a WorldState with the terrain shader.
##
## This node only reads the world; it never changes it. The map is handed to the GPU
## as two small textures (one pixel per tile, plus a palette built from data/tiles.json)
## and the shader paints it. A tile type chooses its look with two fields in tiles.json:
##   "style":    flat, grass, dirt, water, stone or forest
##   "priority": higher-priority tiles bleed over the edges of lower-priority ones
## The season look (foliage color, snow) comes from data/seasons.json.

const TILE_SIZE := 32
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const STYLES := { "flat": 0, "grass": 1, "dirt": 2, "water": 3, "stone": 4, "forest": 5 }
const MAX_TILE_TYPES := 256

var world: WorldState

var _material := ShaderMaterial.new()
var _last_detail := -1.0


func _ready() -> void:
	_material.shader = TERRAIN_SHADER
	_material.set_shader_parameter("tile_px", float(TILE_SIZE))
	material = _material
	GameClock.ticked.connect(_on_clock_ticked)
	GameClock.time_set.connect(_update_season_look)
	_update_season_look()


func set_world(new_world: WorldState) -> void:
	world = new_world
	_upload_world()
	queue_redraw()


func _process(_delta: float) -> void:
	# Fine texture (blades of grass, pebbles, ripples) fades out as the camera zooms away.
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var detail := smoothstep(0.35, 0.8, camera.zoom.x)
	if absf(detail - _last_detail) > 0.01:
		_last_detail = detail
		_material.set_shader_parameter("detail", detail)


func _draw() -> void:
	if world == null:
		return
	# One rectangle covers the whole map; the shader decides every pixel's color.
	draw_rect(Rect2(0, 0, world.width * TILE_SIZE, world.height * TILE_SIZE), Color.WHITE)


func _upload_world() -> void:
	if world.palette.size() > MAX_TILE_TYPES:
		push_error("MapView: a world can use at most %d tile types" % MAX_TILE_TYPES)
		return

	var cells := PackedByteArray()
	cells.resize(world.width * world.height)
	for i in cells.size():
		cells[i] = world.tiles[i]
	var tile_image := Image.create_from_data(world.width, world.height, false, Image.FORMAT_R8, cells)

	var palette_image := Image.create(world.palette.size(), 2, false, Image.FORMAT_RGBA8)
	for i in world.palette.size():
		var def := DataRegistry.get_def("tiles", world.palette[i])
		var color := Color(str(def.get("color", "#ff00ff")))  # magenta = unknown tile
		var style: int = STYLES.get(str(def.get("style", "flat")), 0)
		var priority := clampi(int(def.get("priority", 0)), 0, 255)
		palette_image.set_pixel(i, 0, Color(color.r, color.g, color.b, 1.0))
		palette_image.set_pixel(i, 1, Color(style / 255.0, priority / 255.0, 0.0, 1.0))

	_material.set_shader_parameter("tile_data", ImageTexture.create_from_image(tile_image))
	_material.set_shader_parameter("palette", ImageTexture.create_from_image(palette_image))
	_material.set_shader_parameter("map_size", Vector2i(world.width, world.height))


# --- seasons ---------------------------------------------------------------------

func _on_clock_ticked(tick: int) -> void:
	if tick % 30 == 0:
		_update_season_look()


## Foliage color and snow follow the calendar. A season looks exactly like itself for its
## first two thirds, then eases toward the next one, so snow builds up and melts gradually
## and the next season has already arrived by the time it starts.
func _update_season_look() -> void:
	var seasons: Array = DataRegistry.get_list("seasons")
	var tint := Color.WHITE
	var snow := 0.0
	if not seasons.is_empty():
		var position := GameClock.get_season_position()
		var current: Dictionary = seasons[position["index"]]
		var upcoming: Dictionary = seasons[(position["index"] + 1) % seasons.size()]
		var blend := smoothstep(0.65, 1.0, float(position["progress"]))
		tint = _season_tint(current).lerp(_season_tint(upcoming), blend)
		snow = lerpf(float(current.get("snow", 0.0)), float(upcoming.get("snow", 0.0)), blend)
	_material.set_shader_parameter("foliage_tint", Vector3(tint.r, tint.g, tint.b))
	_material.set_shader_parameter("snow", clampf(snow, 0.0, 1.0))


func _season_tint(season: Dictionary) -> Color:
	return Color(str(season.get("foliage_tint", "#ffffff")))
