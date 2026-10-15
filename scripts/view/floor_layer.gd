class_name FloorLayer
extends Node2D
## Draws the floors the player has laid, between the ground and everything standing on it.

## 0 draws the floors on the ground; 1 the floors upstairs, over them, when upstairs is on screen.
var level := 0

var _watched: WorldState
var _seen_view := -1


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


func _process(_delta: float) -> void:
	if _seen_view != Levels.serial:
		_seen_view = Levels.serial
		visible = level == 0 or Levels.view == 1
		modulate = Color(0.62, 0.66, 0.78) if level == 0 and Levels.view == 1 else Color.WHITE


func _draw() -> void:
	if _watched == null:
		return
	var size := float(MapView.TILE_SIZE)
	for cell: Vector2i in _watched.floors:
		if Levels.of(cell) == level:
			FloorArt.draw(self, str(_watched.floors[cell]), Rect2(Vector2(Levels.ground(cell)) * size, Vector2(size, size)), cell)
