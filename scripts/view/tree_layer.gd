class_name TreeLayer
extends Node2D
## Painted trees over the forest tiles, drawn where the camera is close enough to see them (further out the terrain
## shader's own little trees do the job, and take over again). Oaks turn orange in autumn and bare in winter, birches
## likewise, pines stay green. It draws only what is on screen, from north to south so southern trees overlap northern ones.

const MIN_ZOOM := 0.75
const TREE_HEIGHT := 1.9   # tiles
const MARGIN := 3          # tiles beyond the screen to draw, since trees are taller than a tile

var _world: WorldState
var _camera: Camera2D
var _map: MapView
var _forest: Dictionary = {}
var _last_rect := Rect2i()
var _last_season := ""
var _painted := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	Settings.changed.connect(func(key: String) -> void:
		if key == "illustrated_art":
			_last_rect = Rect2i())


func bind(world: WorldState, camera: Camera2D, map: MapView) -> void:
	_world = world
	_camera = camera
	_map = map
	_forest.clear()
	for tile in DataRegistry.get_list("tiles"):
		if str(tile.get("style", "")) == "forest":
			_forest[str(tile["id"])] = true
	_last_rect = Rect2i()


func _process(_delta: float) -> void:
	if _world == null or _camera == null:
		return
	var on := Settings.illustrated_art and _camera.zoom.x >= MIN_ZOOM and SpriteBank.texture("trees/oak") != null
	if on != _painted:
		_painted = on
		_map.set_painted_trees(on)
		_last_rect = Rect2i()
		if not on:
			queue_redraw()
	if not on:
		return
	var rect := _visible_tiles()
	var season := _season_id()
	if rect != _last_rect or season != _last_season:
		_last_rect = rect
		_last_season = season
		queue_redraw()


func _visible_tiles() -> Rect2i:
	var size := get_viewport_rect().size / _camera.zoom.x
	var tile := float(MapView.TILE_SIZE)
	var from := Vector2i(floori((_camera.global_position.x - size.x * 0.5) / tile) - MARGIN, floori((_camera.global_position.y - size.y * 0.5) / tile) - MARGIN)
	var span := Vector2i(ceili(size.x / tile) + MARGIN * 2 + 1, ceili(size.y / tile) + MARGIN * 2 + 1)
	return Rect2i(from, span).intersection(Rect2i(0, 0, _world.width, _world.height))


func _season_id() -> String:
	var seasons: Array = DataRegistry.get_list("seasons")
	if seasons.is_empty():
		return "summer"
	return str(seasons[GameClock.get_season_position()["index"]].get("id", "summer"))


func _draw() -> void:
	if not _painted or _world == null:
		return
	var season := _season_id()
	var tile := float(MapView.TILE_SIZE)
	for y in range(_last_rect.position.y, _last_rect.end.y):
		for x in range(_last_rect.position.x, _last_rect.end.x):
			if not _forest.has(_world.get_tile_id(x, y)):
				continue
			var kind := ObjectArt.hash01(x, y, 1301)
			var name := "pine" if kind < 0.35 else ("oak" if kind < 0.75 else "birch")
			if name == "oak":
				name = "autumn" if season == "autumn" else ("bare" if season == "winter" else "oak")
			elif name == "birch" and season == "winter":
				name = "bare_b"
			var picture := SpriteBank.texture("trees/" + name)
			if picture == null:
				continue
			var height := TREE_HEIGHT * tile * (0.9 + 0.25 * ObjectArt.hash01(x, y, 1303))
			var width := picture.get_width() * height / picture.get_height()
			var center := Vector2(x + 0.5 + (ObjectArt.hash01(x, y, 1307) - 0.5) * 0.5, y + 0.5 + 0.35) * tile
			draw_colored_polygon(PawnArt._ellipse_points(center + Vector2(0.0, -2.0), Vector2(width * 0.30, 5.0)), Color(0, 0, 0, 0.22))
			draw_texture_rect(picture, Rect2(center.x - width * 0.5, center.y - height, width, height), false)
