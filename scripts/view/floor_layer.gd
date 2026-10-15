class_name FloorLayer
extends Node2D
## Draws the floors the player has laid, between the ground and everything standing on it.

var _watched: WorldState


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	Settings.changed.connect(func(key: String) -> void:
		if key == "illustrated_art":
			queue_redraw())


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
	var size := float(MapView.TILE_SIZE)
	for cell in _watched.floors:
		FloorArt.draw(self, str(_watched.floors[cell]), Rect2(Vector2(cell) * size, Vector2(size, size)), cell)
