class_name ObjectLayer
extends Node2D
## Shows every object in the world. It sits under the people so they walk over beds and
## stand in front of pots. Follows the world as things are built, moved and removed.

var sim: Simulation

var _views: Dictionary = {}  # object id -> ObjectView
var _watched: WorldState
var _dirty := false


func _ready() -> void:
	y_sort_enabled = true


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
	for placed in sim.world.objects:
		present[placed.id] = true
		var view: ObjectView = _views.get(placed.id)
		if view == null:
			view = ObjectView.new()
			add_child(view)
			view.setup(placed)
			_views[placed.id] = view
		view.refresh()
		var group := str(placed.def().get("connects", ""))
		view.connections = sim.world.connection_mask(placed.tile, group) if group != "" else 0
	for id in _views.keys():
		if not present.has(id):
			_views[id].queue_free()
			_views.erase(id)


func _process(_delta: float) -> void:
	if sim == null:
		return
	if _dirty:
		_sync()
	for placed in sim.world.objects:
		var user := sim.household.get_pawn(placed.user_id) if placed.user_id != 0 else null
		if _views.has(placed.id):
			_views[placed.id].occupied = user != null and user.job_stage == "using" and user.pose == "lie"
