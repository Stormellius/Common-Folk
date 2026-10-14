class_name BuildController
extends Node2D
## Build mode: shades everything outside the player's lot, shows a preview of what is about
## to be placed, and turns mouse clicks into the simulation's build commands.
##
## The tool is one of:
##   { "kind": "place", "id": object id }   put a thing or wall down (drag to run a wall)
##   { "kind": "floor", "id": floor id }    lay a floor (drag to cover an area)
##   { "kind": "roof", "id": roof id }      plan a roof over the closed room clicked in
##   { "kind": "remove" }                   take down the object on a tile, or else its floor (or call off a plan)
##   { "kind": "move" }                     click a thing to pick it up, then click where it goes
## Placing and laying only make plans (see Construction): someone has to build them.
## Left-click uses the tool; right-click or Esc puts it away (and a second Esc leaves build
## mode). With no tool chosen, clicks go to the people as usual.

signal mode_changed(active: bool)
## The tool was put away from here (right-click, Esc, leaving build mode): the palette should clear.
signal tool_cleared
signal message(text: String)

const SHADE := Color(0.0, 0.0, 0.0, 0.30)
const LOT_LINE := Color(0.95, 0.80, 0.35, 0.95)

var sim: Simulation
var active := false
var tool: Dictionary = {}

var _ghost := BuildGhost.new()
var _carrying := 0           # id of the object picked up by the move tool
var _painting := false
var _stroke_tiles := 0       # how many tiles this click-and-drag has covered
var _stroke_complained := false
var _last_tile := Vector2i(-9999, -9999)
var _hover := Vector2i(-1, -1)
var _hover_reason := ""
var _roof_tiles: Array[Vector2i] = []  # the room the roof tool would cover under the mouse
var _hinted := false


func _ready() -> void:
	add_child(_ghost)
	_ghost.visible = false
	set_process(false)


func bind(new_sim: Simulation) -> void:
	sim = new_sim
	set_active(false)
	clear_tool()


func toggle() -> void:
	set_active(not active)


func set_active(on: bool) -> void:
	if on == active or (on and sim == null):
		return
	active = on
	if not on:
		clear_tool()
	set_process(on)
	_ghost.visible = false
	queue_redraw()
	mode_changed.emit(active)


func set_tool(kind: String, id: String = "") -> void:
	_carrying = 0
	_painting = false
	if kind == "" or kind == "none":
		tool = {}
	else:
		tool = { "kind": kind, "id": id }
	_refresh_preview()


## Puts the tool away. Returns true if there was one.
func clear_tool() -> bool:
	var had := not tool.is_empty() or _carrying != 0
	tool = {}
	_carrying = 0
	_painting = false
	_refresh_preview()
	if had:
		tool_cleared.emit()
	return had


func _process(_delta: float) -> void:
	if _painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_painting = false  # released over the interface, where we never saw it
	var mouse := get_global_mouse_position()
	var tile := _tile_at(mouse)
	if tile != _hover:
		_hover = tile
		_refresh_preview()


func _tile_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / MapView.TILE_SIZE), floori(point.y / MapView.TILE_SIZE))


## What the preview and the cursor should show for the tile under the mouse.
func _refresh_preview() -> void:
	_hover_reason = ""
	_roof_tiles = []
	_ghost.visible = false
	if active and sim != null and sim.world.in_bounds(_hover.x, _hover.y):
		var kind := str(tool.get("kind", ""))
		var id := str(tool.get("id", ""))
		if kind == "move" and _carrying != 0:
			var carried := sim.world.get_object(_carrying)
			if carried != null:
				kind = "place"
				id = carried.def_id
				_hover_reason = sim.build_blocker(id, _hover, _carrying)
				_show_ghost(kind, id, _hover_reason == "")
		elif kind == "place":
			_hover_reason = sim.build_blocker(id, _hover)
			_show_ghost(kind, id, _hover_reason == "")
		elif kind == "floor":
			if not sim.world.can_build_at(_hover):
				_hover_reason = "outside your land"
			elif not sim.world.is_ground_walkable(_hover.x, _hover.y):
				_hover_reason = "not solid ground"
			_show_ghost(kind, id, _hover_reason == "")
		elif kind == "roof":
			var plan := Construction.roof_plan(sim, _hover)
			_hover_reason = str(plan["reason"])
			_roof_tiles = plan["tiles"] if _hover_reason == "" else ([] as Array[Vector2i])
		elif kind == "remove" or kind == "move":
			if not sim.world.can_build_at(_hover):
				_hover_reason = "outside your land"
	queue_redraw()


func _show_ghost(kind: String, id: String, valid: bool) -> void:
	_ghost.kind = kind
	_ghost.def_id = id
	var group := str(DataRegistry.get_def("objects", id).get("connects", "")) if kind == "place" else ""
	_ghost.connections = sim.world.connection_mask(_hover, group) if group != "" else 0
	_ghost.show_at(_hover, valid)


func _unhandled_input(event: InputEvent) -> void:
	if not active or sim == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if not clear_tool():
			set_active(false)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var tile := _tile_at(make_input_local(button).position)
		if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and not tool.is_empty():
			clear_tool()
			get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_LEFT and not tool.is_empty():
			if button.pressed:
				_painting = true
				_stroke_tiles = 0
				_stroke_complained = false
				_last_tile = tile
				_apply(tile)
			else:
				_painting = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _painting:
		var tile := _tile_at(make_input_local(event).position)
		if tile != _last_tile:
			for cell in _line(_last_tile, tile):
				_apply(cell)
			_last_tile = tile
			get_viewport().set_input_as_handled()


## Every tile on the way from `a` (not included) to `b`, so a fast drag leaves no gaps.
static func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := b - a
	var steps := maxi(absi(delta.x), absi(delta.y))
	for i in range(1, steps + 1):
		cells.append(a + Vector2i(roundi(delta.x * float(i) / steps), roundi(delta.y * float(i) / steps)))
	return cells


func _apply(tile: Vector2i) -> void:
	var first := _stroke_tiles == 0
	_stroke_tiles += 1
	var result := { "ok": true, "message": "" }
	var kind := str(tool.get("kind", ""))
	var id := str(tool.get("id", ""))
	match kind:
		"place":
			# furniture goes down one per click; walls can be dragged out in a line
			if not first and not bool(DataRegistry.get_def("objects", id).get("drag", false)):
				return
			result = Construction.plan_object(sim, id, tile)
		"floor":
			result = Construction.plan_floor(sim, id, tile)
		"roof":
			if not first:
				return
			result = Construction.plan_room_roof(sim, id, tile)
		"remove":
			result = sim.build_remove(tile)
		"move":
			if not first:
				return
			if _carrying == 0:
				var placed := sim.world.object_at(tile)
				if placed == null or not sim.world.can_build_at(tile) or not bool(placed.def().get("buildable", true)):
					result = { "ok": false, "message": "Nothing there to move" }
				else:
					_carrying = placed.id
			else:
				result = sim.build_move(_carrying, tile)
				if result["ok"]:
					_carrying = 0
	if bool(result["ok"]) and not _hinted and kind in ["place", "floor", "roof"]:
		_hinted = true
		message.emit("Planned. Right-click and choose \"Work on the building\" to have someone build it.")
	if not result["ok"] and str(result["message"]) != "" and not _stroke_complained:
		_stroke_complained = true  # one complaint per drag is enough
		message.emit(str(result["message"]))
	_refresh_preview()


func _draw() -> void:
	if not active or sim == null:
		return
	var size := float(MapView.TILE_SIZE)
	var world_rect := Rect2(Vector2.ZERO, Vector2(sim.world.width, sim.world.height) * size)
	# shade everything outside the land you hold: the whole map, then the held lots are cut out
	var held: Array[Rect2i] = sim.world.held_rects()
	var strips: Array[Rect2] = [world_rect]
	for rect in held:
		var hole := Rect2(Vector2(rect.position) * size, Vector2(rect.size) * size)
		var next: Array[Rect2] = []
		for strip in strips:
			if not strip.intersects(hole):
				next.append(strip)
				continue
			if hole.position.y > strip.position.y:
				next.append(Rect2(strip.position, Vector2(strip.size.x, hole.position.y - strip.position.y)))
			if hole.end.y < strip.end.y:
				next.append(Rect2(Vector2(strip.position.x, hole.end.y), Vector2(strip.size.x, strip.end.y - hole.end.y)))
			var top := maxf(strip.position.y, hole.position.y)
			var bottom := minf(strip.end.y, hole.end.y)
			if hole.position.x > strip.position.x:
				next.append(Rect2(Vector2(strip.position.x, top), Vector2(hole.position.x - strip.position.x, bottom - top)))
			if hole.end.x < strip.end.x:
				next.append(Rect2(Vector2(hole.end.x, top), Vector2(strip.end.x - hole.end.x, bottom - top)))
		strips = next
	for strip in strips:
		draw_rect(strip, SHADE)
	for rect in held:
		var lot := Rect2(Vector2(rect.position) * size, Vector2(rect.size) * size)
		for x in range(rect.position.x, rect.end.x + 1):
			draw_line(Vector2(x * size, lot.position.y), Vector2(x * size, lot.end.y), Color(1, 1, 1, 0.10))
		for y in range(rect.position.y, rect.end.y + 1):
			draw_line(Vector2(lot.position.x, y * size), Vector2(lot.end.x, y * size), Color(1, 1, 1, 0.10))
		draw_rect(lot, LOT_LINE, false, 3.0)

	if not sim.world.in_bounds(_hover.x, _hover.y) or tool.is_empty():
		return
	var cell := Rect2(Vector2(_hover) * size, Vector2(size, size))
	var kind := str(tool.get("kind", ""))
	if kind == "roof":
		for roof_tile in _roof_tiles:
			draw_rect(Rect2(Vector2(roof_tile) * size, Vector2(size, size)), Color(0.55, 0.85, 0.50, 0.35))
		if _roof_tiles.is_empty():
			draw_rect(cell, Color(0.95, 0.35, 0.30, 0.30))
		return
	if kind == "remove" or (kind == "move" and _carrying == 0):
		var target := sim.world.object_at(_hover) != null or (kind == "remove" and sim.world.floor_at(_hover) != "")
		var usable := target and sim.world.can_build_at(_hover)
		var color := Color(0.95, 0.35, 0.30) if kind == "remove" else Color(0.95, 0.85, 0.40)
		draw_rect(cell, Color(color.r, color.g, color.b, 0.28 if usable else 0.08))
		draw_rect(cell, Color(color.r, color.g, color.b, 0.95 if usable else 0.35), false, 2.0)
	if _hover_reason != "":
		var camera := get_viewport().get_camera_2d()
		var inverse := 1.0 / camera.zoom.x if camera != null else 1.0
		draw_set_transform(cell.position + Vector2(size * 0.5, size + 14.0 * inverse), 0.0, Vector2(inverse, inverse))
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-80, 0), _hover_reason, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 13, 4, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(-80, 0), _hover_reason, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 13, Color(1.0, 0.75, 0.70))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
