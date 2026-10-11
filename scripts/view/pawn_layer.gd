class_name PawnLayer
extends Node2D
## Shows every pawn of the household and turns mouse clicks into orders.
##
## Controls: left-click a person to switch to them; right-click anywhere to ask for the
## menu of things the selected person can do there (walk, stop, later sleep, eat and so on).
## The layer draws the planned route of the selected pawn underneath the pawns.

## A person was clicked in the world.
signal pawn_selected(id: int)
## The player right-clicked: show the action menu for this tile. `screen_position` is where
## to put it, in the same coordinates as the HUD.
signal context_menu_requested(screen_position: Vector2, tile: Vector2i)

const PICK_RADIUS := 0.55    # in tiles, around the middle of a pawn
const HIDE_NAMES_BELOW := 0.5  # camera zoom

var sim: Simulation

var _views: Dictionary = {}  # pawn id -> PawnView
var _overlay_was_drawn := false


func _ready() -> void:
	y_sort_enabled = true  # pawns lower on the screen are drawn over those above them


func bind(new_sim: Simulation) -> void:
	sim = new_sim
	for view in _views.values():
		view.queue_free()
	_views.clear()
	_sync_views()
	queue_redraw()


## Where a pawn is drawn right now, in world pixels.
func visual_position(id: int) -> Vector2:
	if _views.has(id):
		return _views[id].position
	var pawn := sim.household.get_pawn(id) if sim != null else null
	if pawn != null:
		return (Vector2(pawn.tile) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE
	return Vector2.ZERO


func _process(_delta: float) -> void:
	if sim == null:
		return
	if _views.size() != sim.household.pawns.size():
		_sync_views()
	var camera := get_viewport().get_camera_2d()
	var names_visible := camera == null or camera.zoom.x >= HIDE_NAMES_BELOW
	for id in _views:
		var view: PawnView = _views[id]
		view.selected = (id == sim.household.selected_id)
		view.show_name = names_visible
		view.label_scale = 1.0 / camera.zoom.x if camera != null else 1.0
	var chosen := sim.household.selected()
	var overlay_needed := chosen != null and chosen.has_orders()
	if overlay_needed or _overlay_was_drawn:
		queue_redraw()
	_overlay_was_drawn = overlay_needed


func _sync_views() -> void:
	var wanted := {}
	for pawn in sim.household.pawns:
		wanted[pawn.id] = true
		if not _views.has(pawn.id):
			var view := PawnView.new()
			add_child(view)
			view.setup(pawn)
			_views[pawn.id] = view
	for id in _views.keys():
		if not wanted.has(id):
			_views[id].queue_free()
			_views.erase(id)


func _draw() -> void:
	if sim == null:
		return
	var chosen := sim.household.selected()
	if chosen == null or not chosen.has_orders():
		return
	var route := PackedVector2Array()
	route.append(visual_position(chosen.id))
	if chosen.is_moving():
		route.append(_tile_center(chosen.step_to))
	for cell in chosen.path:
		route.append(_tile_center(cell))
	if route.size() >= 2:
		draw_polyline(route, Color(1, 1, 1, 0.35), 2.0)
	var goal := _tile_center(chosen.goal_tile())
	var mark := Color(1.0, 0.95, 0.6, 0.9)
	draw_arc(goal, 12.0, 0.0, TAU, 24, mark, 2.0)
	draw_line(goal + Vector2(-5, -5), goal + Vector2(5, 5), mark, 2.0)
	draw_line(goal + Vector2(-5, 5), goal + Vector2(5, -5), mark, 2.0)


func _tile_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE


func _unhandled_input(event: InputEvent) -> void:
	if sim == null or not (event is InputEventMouseButton and event.pressed):
		return
	var world_point: Vector2 = (make_input_local(event) as InputEventMouseButton).position  # world pixels
	if event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _pawn_at(world_point)
		if clicked != null and sim.household.select(clicked.id):
			pawn_selected.emit(clicked.id)
			get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if sim.household.selected() != null:
			var tile := Vector2i(floori(world_point.x / MapView.TILE_SIZE), floori(world_point.y / MapView.TILE_SIZE))
			context_menu_requested.emit(event.position, tile)
			get_viewport().set_input_as_handled()


func _pawn_at(world_point: Vector2) -> Pawn:
	var best: Pawn = null
	var best_distance := PICK_RADIUS * MapView.TILE_SIZE
	for pawn in sim.household.pawns:
		var distance := visual_position(pawn.id).distance_to(world_point)
		if distance < best_distance:
			best_distance = distance
			best = pawn
	return best
