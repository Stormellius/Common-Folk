class_name ShadowLayer
extends Node2D
## Soft shadows that walls throw on the ground and the floors around them, drawn between the
## floors and the objects. Light comes from the top-left (as in the terrain shader), so the
## ground east and south of a wall lies in a deep shadow, and the other sides get only a faint
## one where the wall meets the ground. Doors count as wall, so a doorway does not break it.

const CAST := 0.42           # darkness right against a wall to the west or north
const CAST_REACH := 0.48     # how far that shadow reaches, in tiles
const CONTACT := 0.18        # the faint shadow against a wall to the east or south
const CONTACT_REACH := 0.16

var _watched: WorldState


func _ready() -> void:
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # plain shade; firelight need not work it out
	material = unlit


func bind(world: WorldState) -> void:
	if _watched != null and _watched.tile_changed.is_connected(_on_tile_changed):
		_watched.tile_changed.disconnect(_on_tile_changed)
	_watched = world
	_watched.tile_changed.connect(_on_tile_changed)
	queue_redraw()


func _on_tile_changed(_tile: Vector2i) -> void:
	queue_redraw()  # redraws once per frame however many tiles changed


func _draw() -> void:
	if _watched == null:
		return
	var walls := {}
	for placed in _watched.objects:
		if str(placed.def().get("connects", "")) == "wall":
			walls[placed.tile] = true
	var done := {}
	for tile in walls:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var spot: Vector2i = tile + Vector2i(dx, dy)
				if not walls.has(spot) and not done.has(spot):
					done[spot] = true
					_shade(spot, walls)


## Shades one open tile for the walls around it.
func _shade(spot: Vector2i, walls: Dictionary) -> void:
	var size := float(MapView.TILE_SIZE)
	var rect := Rect2(Vector2(spot) * size, Vector2(size, size))
	var west := walls.has(spot + Vector2i(-1, 0))
	var north := walls.has(spot + Vector2i(0, -1))
	if west:
		_fade(rect, SIDE_LEFT, CAST, CAST_REACH * size)
	if north:
		_fade(rect, SIDE_TOP, CAST, CAST_REACH * size)
	if walls.has(spot + Vector2i(1, 0)):
		_fade(rect, SIDE_RIGHT, CONTACT, CONTACT_REACH * size)
	if walls.has(spot + Vector2i(0, 1)):
		_fade(rect, SIDE_BOTTOM, CONTACT, CONTACT_REACH * size)
	if not west and not north and walls.has(spot + Vector2i(-1, -1)):
		# the corner of a wall to the north-west throws a little wedge of shadow
		var reach := CAST_REACH * size
		var dark := Color(0, 0, 0, CAST)
		var clear := Color(0, 0, 0, 0)
		draw_polygon(PackedVector2Array([rect.position, rect.position + Vector2(reach, 0), rect.position + Vector2(reach, reach), rect.position + Vector2(0, reach)]),
			PackedColorArray([dark, clear, clear, clear]))


## A band along one side of `rect`, `strength` dark at that side and fading out over `reach`.
func _fade(rect: Rect2, side: Side, strength: float, reach: float) -> void:
	var dark := Color(0, 0, 0, strength)
	var clear := Color(0, 0, 0, 0)
	var band: Rect2
	var colors: PackedColorArray
	match side:
		SIDE_LEFT:
			band = Rect2(rect.position, Vector2(reach, rect.size.y))
			colors = PackedColorArray([dark, clear, clear, dark])
		SIDE_TOP:
			band = Rect2(rect.position, Vector2(rect.size.x, reach))
			colors = PackedColorArray([dark, dark, clear, clear])
		SIDE_RIGHT:
			band = Rect2(Vector2(rect.end.x - reach, rect.position.y), Vector2(reach, rect.size.y))
			colors = PackedColorArray([clear, dark, dark, clear])
		_:
			band = Rect2(Vector2(rect.position.x, rect.end.y - reach), Vector2(rect.size.x, reach))
			colors = PackedColorArray([clear, clear, dark, dark])
	draw_polygon(PackedVector2Array([band.position, Vector2(band.end.x, band.position.y), band.end, Vector2(band.position.x, band.end.y)]), colors)
