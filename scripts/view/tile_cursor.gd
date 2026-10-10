class_name TileCursor
extends Node2D
## Highlights the tile under the mouse and can show a grid overlay.
## Kept separate from MapView so moving the mouse never redraws the whole map.

## Emitted when the hovered tile changes. (-1, -1) means the mouse is off the map.
signal hovered_changed(tile: Vector2i)

var world: WorldState
var show_grid := false
var hovered := Vector2i(-1, -1)


func set_world(new_world: WorldState) -> void:
	world = new_world
	hovered = Vector2i(-1, -1)
	queue_redraw()


func toggle_grid() -> void:
	show_grid = not show_grid
	queue_redraw()


func _process(_delta: float) -> void:
	if world == null:
		return
	var mouse := get_global_mouse_position()
	var tile := Vector2i(floori(mouse.x / MapView.TILE_SIZE), floori(mouse.y / MapView.TILE_SIZE))
	if not world.in_bounds(tile.x, tile.y):
		tile = Vector2i(-1, -1)
	if tile != hovered:
		hovered = tile
		hovered_changed.emit(tile)
		queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var size := float(MapView.TILE_SIZE)
	if show_grid:
		var grid_color := Color(0, 0, 0, 0.2)
		for x in world.width + 1:
			draw_line(Vector2(x * size, 0), Vector2(x * size, world.height * size), grid_color)
		for y in world.height + 1:
			draw_line(Vector2(0, y * size), Vector2(world.width * size, y * size), grid_color)
	if hovered.x >= 0:
		var rect := Rect2(Vector2(hovered) * size, Vector2(size, size))
		draw_rect(rect, Color(1, 1, 1, 0.18))
		draw_rect(rect, Color(1, 1, 1, 0.9), false, 2.0)
