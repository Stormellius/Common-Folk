class_name RoofLayer
extends Node2D
## Draws the roofs of every roofed room, above the people. Zoomed in you see into the buildings (the
## roofs fade away), zoomed out you see a town of roofs. R cycles: by the zoom, always shown, hidden.

const SHOW_BELOW := 0.50  # camera zoom at which roofs are fully there
const HIDE_ABOVE := 0.90  # and at which they have faded away

var mode := 0  # 0 by the zoom, 1 always shown, 2 hidden
var _watched: WorldState
var _alpha := -1.0


func bind(world: WorldState) -> void:
	if _watched != null and _watched.roofs_changed.is_connected(_on_roofs_changed):
		_watched.roofs_changed.disconnect(_on_roofs_changed)
	_watched = world
	_watched.roofs_changed.connect(_on_roofs_changed)
	queue_redraw()


## Switches between the modes; returns what the new one is called.
func cycle() -> String:
	mode = (mode + 1) % 3
	_alpha = -1.0
	return ["Roofs: by the zoom", "Roofs: always shown", "Roofs: hidden"][mode]


func _on_roofs_changed() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	var zoom := camera.zoom.x if camera != null else 1.0
	var wanted := 1.0
	match mode:
		0:
			wanted = 1.0 - smoothstep(SHOW_BELOW, HIDE_ABOVE, zoom)
		2:
			wanted = 0.0
	if absf(wanted - _alpha) > 0.01:
		_alpha = wanted
		modulate.a = wanted
		visible = wanted > 0.01


func _draw() -> void:
	if _watched == null:
		return
	var size := float(MapView.TILE_SIZE)
	for cell: Vector2i in _watched.roofs:
		var edges := 0
		if not _watched.roofs.has(cell + Vector2i(0, -1)):
			edges |= 1
		if not _watched.roofs.has(cell + Vector2i(1, 0)):
			edges |= 2
		if not _watched.roofs.has(cell + Vector2i(0, 1)):
			edges |= 4
		if not _watched.roofs.has(cell + Vector2i(-1, 0)):
			edges |= 8
		RoofArt.draw(self, str(_watched.roofs[cell]), Rect2(Vector2(cell) * size, Vector2(size, size)), cell, edges)
