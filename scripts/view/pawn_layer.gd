class_name PawnLayer
extends Node2D
## Shows every person in the world (the household and the townspeople) and turns mouse clicks into orders.
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
var _animal_views: Dictionary = {}  # animal id -> AnimalView
var _caravan_views: Dictionary = {}  # caravan id -> CaravanView
var _overlay_was_drawn := false


func _ready() -> void:
	y_sort_enabled = true  # pawns lower on the screen are drawn over those above them


func bind(new_sim: Simulation) -> void:
	sim = new_sim
	for view in _views.values():
		view.queue_free()
	_views.clear()
	for view in _animal_views.values():
		view.queue_free()
	_animal_views.clear()
	for view in _caravan_views.values():
		view.queue_free()
	_caravan_views.clear()
	_sync_views()
	queue_redraw()


## Where a pawn is drawn right now, in world pixels.
func visual_position(id: int) -> Vector2:
	if _views.has(id):
		return _views[id].position
	var pawn := sim.person(id) if sim != null else null
	if pawn != null:
		return Levels.pixel(pawn.tile)
	return Vector2.ZERO


func _process(_delta: float) -> void:
	if sim == null:
		return
	if _views.size() != sim.household.pawns.size() + sim.town.pawns.size():
		_sync_views()
	_sync_animal_views()
	_sync_caravan_views()
	var camera := get_viewport().get_camera_2d()
	var names_visible := camera == null or camera.zoom.x >= HIDE_NAMES_BELOW
	for caravan_id in _caravan_views:
		var caravan_view: CaravanView = _caravan_views[caravan_id]
		caravan_view.show_name = names_visible
		caravan_view.label_scale = 1.0 / camera.zoom.x if camera != null else 1.0
	for animal_id in _animal_views:
		var animal_view: AnimalView = _animal_views[animal_id]
		animal_view.show_name = names_visible and animal_view.animal.owner == "household"
		animal_view.label_scale = 1.0 / camera.zoom.x if camera != null else 1.0
	for id in _views:
		var view: PawnView = _views[id]
		view.selected = (id == sim.household.selected_id)
		view.show_name = names_visible
		view.label_scale = 1.0 / camera.zoom.x if camera != null else 1.0
		view.townsfolk = sim.household.get_pawn(id) == null
		view.clothes = Clothing.worn(sim, view.pawn)
		view.pieces = Clothing.pieces(sim, view.pawn)
		view.visible = view.pawn.caravan == 0 and Levels.of(_level_tile(view.pawn)) == Levels.view  # a rider is drawn on the cart; the floor not on screen is not shown
	if names_visible:
		_stack_labels(camera.zoom.x if camera != null else 1.0)
	var chosen := sim.household.selected()
	var overlay_needed := chosen != null and chosen.has_orders()
	if overlay_needed or _overlay_was_drawn:
		queue_redraw()
	_overlay_was_drawn = overlay_needed


## Where two names would overlap, pushes the lower one down under the other, so a crowd at
## the tavern stays readable. Works in screen pixels, since names keep their size on screen.
func _stack_labels(zoom: float) -> void:
	var font := ThemeDB.fallback_font
	var named: Array = _views.values().filter(func(view: PawnView) -> bool: return not view.pawn.is_infant())
	named.sort_custom(func(a: PawnView, b: PawnView) -> bool: return a.label_anchor().y < b.label_anchor().y)
	var taken: Array[Rect2] = []
	for view: PawnView in named:
		var width := font.get_string_size(view.pawn.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 4.0
		var rect := Rect2(view.label_anchor() * zoom + Vector2(-width * 0.5, -12.0), Vector2(width, 16.0))
		var drop := 0.0
		var moved := true
		while moved:
			moved = false
			for other in taken:
				if other.intersects(rect):
					drop += other.end.y - rect.position.y
					rect.position.y = other.end.y
					moved = true
		taken.append(rect)
		view.label_drop = drop


## Keeps one picture for every animal in the world; a ridden one follows its rider's.
func _sync_animal_views() -> void:
	var seen := {}
	for animal in sim.world.animals:
		seen[animal.id] = true
		var view: AnimalView = _animal_views.get(animal.id)
		if view == null:
			view = AnimalView.new()
			add_child(view)
			view.setup(animal)
			_animal_views[animal.id] = view
		view.follow = _views.get(animal.rider) if animal.rider != 0 else null
	if _animal_views.size() != seen.size():
		for id in _animal_views.keys():
			if not seen.has(id):
				_animal_views[id].queue_free()
				_animal_views.erase(id)


## Keeps one picture for every caravan on the roads.
func _sync_caravan_views() -> void:
	var seen := {}
	for caravan in sim.world.caravans:
		seen[caravan.id] = true
		if not _caravan_views.has(caravan.id):
			var view := CaravanView.new()
			add_child(view)
			view.setup(caravan, sim)
			_caravan_views[caravan.id] = view
	if _caravan_views.size() != seen.size():
		for id in _caravan_views.keys():
			if not seen.has(id):
				_caravan_views[id].queue_free()
				_caravan_views.erase(id)


func _sync_views() -> void:
	var wanted := {}
	for pawn in sim.people():
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
	return Levels.pixel(cell)


## The tile that says which floor somebody is on: halfway up or down a flight of stairs they have changed floors.
func _level_tile(pawn: Pawn) -> Vector2i:
	return pawn.step_to if pawn.is_moving() and pawn.step_progress() > 0.5 else pawn.tile


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
			var tile := Levels.lift(Vector2i(floori(world_point.x / MapView.TILE_SIZE), floori(world_point.y / MapView.TILE_SIZE)), Levels.view)
			context_menu_requested.emit(event.position, tile)
			get_viewport().set_input_as_handled()


func _pawn_at(world_point: Vector2) -> Pawn:
	var best: Pawn = null
	var best_distance := PICK_RADIUS * MapView.TILE_SIZE
	for pawn in sim.household.pawns:
		if pawn.is_infant() or (_views.has(pawn.id) and not _views[pawn.id].visible):
			continue
		var distance := visual_position(pawn.id).distance_to(world_point)
		if distance < best_distance:
			best_distance = distance
			best = pawn
	return best
