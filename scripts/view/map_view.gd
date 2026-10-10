class_name MapView
extends Node2D
## Draws the terrain of a WorldState as flat colored tiles (RimWorld-style).
##
## This node only reads the world; it never changes it. Colors come from
## data/tiles.json, so a mod that changes a tile color changes the look with no code.
## The map is drawn once and redrawn only when a new world is set.

const TILE_SIZE := 32

var world: WorldState


func set_world(new_world: WorldState) -> void:
	world = new_world
	queue_redraw()


func _draw() -> void:
	if world == null:
		return

	var colors: Array[Color] = []
	for tile_id in world.palette:
		var def := DataRegistry.get_def("tiles", tile_id)
		colors.append(Color(str(def.get("color", "#ff00ff"))))  # magenta = unknown tile

	for y in world.height:
		for x in world.width:
			var color := colors[world.tiles[world.index_of(x, y)]]
			# A tiny fixed brightness change per tile so large flat areas have some texture.
			var shade := (float(((x * 73856093) ^ (y * 19349663)) & 7) - 3.5) * 0.012
			color = Color(color.r + shade, color.g + shade, color.b + shade)
			draw_rect(Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE), color)
