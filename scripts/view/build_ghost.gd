class_name BuildGhost
extends Node2D
## The see-through preview that follows the mouse in build mode: green where the thing can
## go, red where it cannot. Set `kind` ("place" or "floor"), `def_id` and `connections`.

var kind := ""
var def_id := ""
var connections := 0
var cell := Vector2i.ZERO


func show_at(new_cell: Vector2i, valid: bool) -> void:
	cell = new_cell
	position = (Vector2(cell) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE
	modulate = Color(0.75, 1.0, 0.75, 0.7) if valid else Color(1.0, 0.45, 0.45, 0.7)
	visible = true
	queue_redraw()


func _draw() -> void:
	var size := float(MapView.TILE_SIZE)
	if kind == "floor":
		FloorArt.draw(self, def_id, Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size)), cell)
	elif kind == "place":
		ObjectArt.draw(self, def_id, size / 48.0, 0.0, false, connections, cell)
