class_name ObjectLayer
extends Node2D
## Shows every object in the world. It sits under the people so they walk over beds and
## stand in front of pots.

var sim: Simulation

var _views: Dictionary = {}  # object id -> ObjectView


func _ready() -> void:
	y_sort_enabled = true


func bind(new_sim: Simulation) -> void:
	sim = new_sim
	for view in _views.values():
		view.queue_free()
	_views.clear()
	for placed in sim.world.objects:
		var view := ObjectView.new()
		add_child(view)
		view.setup(placed)
		_views[placed.id] = view


func _process(_delta: float) -> void:
	if sim == null:
		return
	for placed in sim.world.objects:
		var user := sim.household.get_pawn(placed.user_id) if placed.user_id != 0 else null
		if _views.has(placed.id):
			_views[placed.id].occupied = user != null and user.job_stage == "using" and user.pose == "lie"
