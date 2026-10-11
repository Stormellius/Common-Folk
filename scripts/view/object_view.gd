class_name ObjectView
extends Node2D
## Draws one placed object. Only things that move (flames, steam) redraw every frame.

var placed: PlacedObject
var occupied := false:
	set(value):
		if value != occupied:
			occupied = value
			queue_redraw()


func setup(new_placed: PlacedObject) -> void:
	placed = new_placed
	position = (Vector2(placed.tile) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE
	queue_redraw()


func _process(_delta: float) -> void:
	if placed != null and ObjectArt.is_animated(placed.def_id):
		queue_redraw()


func _draw() -> void:
	if placed != null:
		ObjectArt.draw(self, placed.def_id, MapView.TILE_SIZE / 48.0, Time.get_ticks_msec() / 1000.0, occupied)
