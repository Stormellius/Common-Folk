class_name ObjectLayer
extends Node2D
## Shows every object in the world. It sits under the people so they walk over beds and
## stand in front of pots. Follows the world as things are built, moved and removed.

var sim: Simulation

var _views: Dictionary = {}  # object id -> ObjectView
var _beds: Array[PlacedObject] = []  # what people lie in, so the sleepers can be shown
var _watched: WorldState
var _dirty := false
var _seen_view := -1


func _ready() -> void:
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # painted pictures are scaled down smoothly
	Settings.changed.connect(_on_setting_changed)


func _on_setting_changed(key: String) -> void:
	if key == "illustrated_art":
		for view in _views.values():
			view.queue_redraw()


func bind(new_sim: Simulation) -> void:
	if _watched != null and _watched.tile_changed.is_connected(_on_tile_changed):
		_watched.tile_changed.disconnect(_on_tile_changed)
	sim = new_sim
	_watched = sim.world
	_watched.tile_changed.connect(_on_tile_changed)
	for view in _views.values():
		view.queue_free()
	_views.clear()
	_sync()


func _on_tile_changed(_tile: Vector2i) -> void:
	_dirty = true  # several changes in one frame (painting a wall) are handled together


func _sync() -> void:
	_dirty = false
	var present := {}
	_beds.clear()
	for placed in sim.world.objects:
		present[placed.id] = true
		if placed.def().has("pose"):
			_beds.append(placed)
		var view: ObjectView = _views.get(placed.id)
		if view == null:
			view = ObjectView.new()
			add_child(view)
			view.setup(placed)
			_views[placed.id] = view
		view.refresh()
		_show_for_level(view, placed)
		var group := str(placed.def().get("connects", ""))
		view.connections = sim.world.connection_mask(placed.tile, group) if group != "" else 0
	for id in _views.keys():
		if not present.has(id):
			_views[id].queue_free()
			_views.erase(id)


## What is on screen: the floor being looked at in full, and the floor below it, where nothing is built
## over it, dimmed.
func _show_for_level(view: ObjectView, placed: PlacedObject) -> void:
	var level := Levels.of(placed.tile)
	if level == Levels.view:
		view.visible = true
		view.modulate = Color.WHITE
	elif level == 0 and Levels.view == 1:
		view.visible = not sim.world.floors.has(Levels.lift(placed.tile, 1))
		view.modulate = Color(0.62, 0.66, 0.78)
	else:
		view.visible = false


func _process(_delta: float) -> void:
	if sim == null:
		return
	if _seen_view != Levels.serial:
		_seen_view = Levels.serial
		_dirty = true
	if _dirty:
		_sync()
	for placed in _beds:
		var user := sim.person(placed.user_id) if placed.user_id != 0 else null
		if _views.has(placed.id):
			_views[placed.id].occupied = user != null and user.job_stage == "using" and user.pose == "lie"
