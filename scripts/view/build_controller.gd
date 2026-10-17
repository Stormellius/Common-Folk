class_name BuildController
extends Node2D
## Build mode: shades everything outside the player's lots, shows what the tool in hand is about to do,
## and turns the mouse and keys into the building commands (see BuildEditor and Construction).
##
## The tool is one of:
##   { "kind": "select" }                   the hand, which is what you start with: click a thing to select it, drag
##                                           it to move it, drag over the ground to select an area, Del to take it down
##   { "kind": "place", "id": object id }   put a thing or wall down (drag to run a wall)
##   { "kind": "floor", "id": floor id }    lay a floor (drag to cover an area)
##   { "kind": "roof", "id": roof id }      plan a roof over the closed room clicked in
##   { "kind": "unroof" }                   take the roof off the room clicked in
##   { "kind": "remove" }                   take down what is on a tile (or call off a plan)
##   { "kind": "pick" }                     click a thing to take up its style (the eyedropper)
##   { "kind": "move" }                     click a thing to pick it up, then click where it goes
## and the shape for drawing walls, floors and taking down is "free" (drag a trail), "box" (drag a
## rectangle: walls round the edge, floors all over) or "fill" (a floor over a whole room). Shift gives a box.
## Placing and laying only make plans: someone has to build them. Everything done here can be undone.
## Right-click or Esc put the tool back in the hand; with the hand in hand, right-click opens a little
## menu for what is under it. The people are never given orders from here.

signal mode_changed(active: bool)
## The tool was put away from here (right-click, Esc, leaving build mode): the palette should clear.
signal tool_cleared
signal tool_changed(kind: String)
signal shape_changed(shape: String)
signal hint_changed(text: String)
signal history_changed(can_undo: bool, can_redo: bool)
signal message(text: String)
## The eyedropper took up the style of something: the palette should show it.
signal picked_style(kind: String, id: String)
## The hand was right-clicked on something: a menu of what can be done with it.
signal menu_requested(screen_position: Vector2, title: String, actions: Array[Dictionary])

const SELECT := "select"
const SHADE := Color(0.0, 0.0, 0.0, 0.30)
const LOT_LINE := Color(0.95, 0.80, 0.35, 0.95)
const PICKED := Color(1.0, 0.86, 0.35)
const GOOD := Color(0.55, 0.85, 0.50)
const BAD := Color(0.95, 0.35, 0.30)
const BOX_LIMIT := 900   # no rectangle is made bigger than this many tiles

var sim: Simulation
var active := false
var tool: Dictionary = { "kind": SELECT, "id": "" }
var shape := "free"
## What the hand has picked out: targets (see BuildEditor).
var selection: Array[Dictionary] = []

var _ghost := BuildGhost.new()
var _carrying: Array[Dictionary] = []   # picked up with Move: it follows the mouse until set down
var _anchor := Vector2i.ZERO            # the tile it was picked up by
var _press_tile := Vector2i.ZERO        # where the left button went down
var _grab := false                      # the button is down on the selection: a drag moves it
var _dragging := false
var _marquee := false                   # the button is down on bare ground: an area is being picked
var _painting := false                  # the button is down with a tool that draws
var _boxing := false                    # ... and it is a rectangle
var _stroke_tiles := 0                  # how many tiles this click-and-drag has covered
var _stroke_complained := false
var _last_tile := Vector2i(-9999, -9999)
var _hover := Vector2i(-1, -1)
var _hover_reason := ""
var _hover_target: Dictionary = {}
var _roof_tiles: Array[Vector2i] = []   # the room the roof tool would cover under the mouse
var _shape_cells: Array[Vector2i] = []  # what a box or a fill would do
var _move_cells: Array[Vector2i] = []   # where what is being moved would land
var _menu_items: Array[Dictionary] = []
var _menu_tile := Vector2i.ZERO
var _hinted := false
var _seen_view := 0


func _ready() -> void:
	add_child(_ghost)
	_ghost.visible = false
	set_process(false)


func bind(new_sim: Simulation) -> void:
	sim = new_sim
	set_active(false)
	_reset_tool()


func toggle() -> void:
	set_active(not active)


func set_active(on: bool) -> void:
	if on == active or (on and sim == null):
		return
	active = on
	if not on:
		_cancel_gesture()
		_reset_tool()
		if sim != null:
			sim.build_history.end()
	set_process(on)
	_ghost.visible = false
	queue_redraw()
	mode_changed.emit(active)
	if on:
		_announce()


## Chooses what is in hand. "none" or "" is the hand.
func set_tool(kind: String, id: String = "") -> void:
	_cancel_gesture()
	if kind == "" or kind == "none":
		kind = SELECT
	tool = { "kind": kind, "id": id }
	if kind != SELECT:
		selection.clear()
	_announce()
	_refresh_preview()


## Puts the tool away (back to the hand). Returns true if there was one, or something was picked up.
func clear_tool() -> bool:
	var had := str(tool["kind"]) != SELECT or not _carrying.is_empty()
	_cancel_gesture()
	tool = { "kind": SELECT, "id": "" }
	_announce()
	_refresh_preview()
	if had:
		tool_cleared.emit()
	return had


func set_shape(new_shape: String) -> void:
	shape = new_shape if new_shape in ["free", "box", "fill"] else "free"
	shape_changed.emit(shape)
	_announce()
	_refresh_preview()


func _reset_tool() -> void:
	tool = { "kind": SELECT, "id": "" }
	selection.clear()
	_carrying.clear()
	_hover_target = {}
	_announce()
	if sim != null:
		history_changed.emit(sim.build_history.can_undo(), sim.build_history.can_redo())


func _announce() -> void:
	tool_changed.emit(str(tool["kind"]))
	hint_changed.emit(_hint())


func _hint() -> String:
	if not _carrying.is_empty():
		return "Click to set it down    Right-click or Esc: put it back"
	match str(tool["kind"]):
		"place":
			var drags := bool(DataRegistry.get_def("objects", str(tool["id"])).get("drag", false))
			return "Click to place%s    Right-click or Esc: back to the hand    Ctrl+Z: undo" % ("  (drag to run a line, Shift-drag for a box)" if drags else "")
		"floor":
			return "Click or drag to lay a floor (Shift-drag: a box, Fill: a whole room)    Right-click or Esc: back to the hand    Ctrl+Z: undo"
		"roof":
			return "Click inside a closed room to roof it    Right-click or Esc: back to the hand"
		"unroof":
			return "Click a roofed room to take its roof off    Right-click or Esc: back to the hand"
		"remove":
			return "Click or drag to take things down    Right-click or Esc: back to the hand    Ctrl+Z: undo"
		"pick":
			return "Click a thing to take up its style    Right-click or Esc: back to the hand"
		"move":
			return "Click a thing to pick it up, then click where it goes    Right-click or Esc: back to the hand"
	if selection.is_empty():
		return "Click a thing to select it, drag it to move it, drag over the ground to select an area    Right-click: more    Ctrl+Z: undo"
	return "Drag to move    Del: take down    Right-click: more    Ctrl+Z: undo    Esc: let go"


func _process(_delta: float) -> void:
	if _seen_view != Levels.serial:  # the other floor is on screen now
		_seen_view = Levels.serial
		_hover = Vector2i(-1, -1)
		selection.clear()
		_cancel_gesture()
	if (_painting or _grab or _marquee) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_left_release(_hover)  # let go over the interface, where we never saw it
	var tile := _tile_at(get_global_mouse_position())
	if tile != _hover:
		_hover = tile
		_refresh_preview()
	if not selection.is_empty():
		_prune_selection()


func _tile_at(point: Vector2) -> Vector2i:
	return Levels.lift(Vector2i(floori(point.x / MapView.TILE_SIZE), floori(point.y / MapView.TILE_SIZE)), Levels.view)


## Drops whatever has been built, taken down or moved away from under the selection.
func _prune_selection() -> void:
	var keep: Array[Dictionary] = []
	for item in selection:
		var present := false
		match str(item["type"]):
			"object":
				var placed := sim.world.get_object(int(item["id"]))
				present = placed != null and placed.tile == item["tile"]
			"floor":
				present = sim.world.floor_at(item["tile"]) == str(item["def"])
			"plan":
				var site := sim.world.get_site(int(item["id"]))
				present = site != null and site.tile == item["tile"]
		if present:
			keep.append(item)
	if keep.size() != selection.size():
		selection = keep
		_announce()
		queue_redraw()


## What the preview and the cursor should show for the tile under the mouse.
func _refresh_preview() -> void:
	_hover_reason = ""
	_hover_target = {}
	_roof_tiles = []
	_shape_cells = []
	_move_cells = []
	_ghost.visible = false
	if active and sim != null and sim.world.in_bounds(_hover.x, _hover.y):
		var kind := str(tool["kind"])
		var id := str(tool["id"])
		if not _carrying.is_empty() or _dragging:
			_preview_move()
		elif _boxing:
			_preview_box(kind)
		elif kind == "place":
			_hover_reason = sim.build_blocker(id, _hover)
			_show_ghost("place", id, _hover_reason == "")
		elif kind == "floor":
			_hover_reason = _floor_blocker(_hover)
			if shape == "fill" and _hover_reason == "":
				var fill := BuildEditor.fill_tiles(sim, _hover)
				_hover_reason = str(fill["reason"])
				_shape_cells.assign(fill["tiles"])
			else:
				_show_ghost("floor", id, _hover_reason == "")
		elif kind == "roof":
			var plan := Construction.roof_plan(sim, _hover)
			_hover_reason = str(plan["reason"])
			_roof_tiles = plan["tiles"] if _hover_reason == "" else ([] as Array[Vector2i])
		elif kind == "unroof":
			var held := sim.world.can_build_at(_hover)
			_roof_tiles = BuildEditor.roof_tiles(sim, _hover) if held else ([] as Array[Vector2i])
			if _roof_tiles.is_empty():
				_hover_reason = "no roof there" if held else "outside your land"
		elif kind in [SELECT, "remove", "pick", "move"]:
			if sim.world.can_build_at(_hover):
				_hover_target = BuildEditor.target_at(sim, _hover)
			elif kind != SELECT:
				_hover_reason = "outside your land"
	queue_redraw()


func _floor_blocker(tile: Vector2i) -> String:
	if not sim.world.can_build_at(tile):
		return "outside your land"
	if Levels.of(tile) == 1:
		return Levels.floor_blocker(sim.world, tile) if sim.world.floor_at(tile) == "" else ""
	if not sim.world.is_ground_walkable(tile.x, tile.y):
		return "not solid ground"
	return ""


func _show_ghost(kind: String, id: String, valid: bool) -> void:
	_ghost.kind = kind
	_ghost.def_id = id
	var group := str(DataRegistry.get_def("objects", id).get("connects", "")) if kind == "place" else ""
	_ghost.connections = sim.world.connection_mask(_hover, group) if group != "" else 0
	_ghost.show_at(_hover, valid)


## Where what is being carried or dragged would land.
func _preview_move() -> void:
	var items := _carrying if not _carrying.is_empty() else selection
	var anchor := _anchor if not _carrying.is_empty() else _press_tile
	var delta := _hover - anchor
	if delta != Vector2i.ZERO:
		_hover_reason = BuildEditor.move_blocker(sim, items, delta)
	for item in items:
		_move_cells.append((item["tile"] as Vector2i) + delta)
	if items.size() == 1 and delta != Vector2i.ZERO:
		var item := items[0]
		var kind := str(item["kind"]) if str(item["type"]) == "plan" else str(item["type"])
		if kind in ["object", "floor"]:
			_ghost.kind = "place" if kind == "object" else "floor"
			_ghost.def_id = str(item["def"])
			var group := str(DataRegistry.get_def("objects", _ghost.def_id).get("connects", "")) if kind == "object" else ""
			_ghost.connections = sim.world.connection_mask(_hover, group) if group != "" else 0
			_ghost.show_at(_hover, _hover_reason == "")


## The rectangle being dragged out.
func _preview_box(kind: String) -> void:
	_shape_cells = BuildEditor.box_tiles(_press_tile, _hover, kind == "place")
	if _shape_cells.size() > BOX_LIMIT:
		_shape_cells = []
		_hover_reason = "that is a lot of ground"


func _unhandled_input(event: InputEvent) -> void:
	if not active or sim == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _key(event as InputEventKey):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			get_viewport().gui_release_focus()  # a click that got this far was not on the interface: the search box lets go of the keys
		var tile := _tile_at(make_input_local(button).position)
		if button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed:
				_hover = tile
				_right_click(button.position, tile)
			get_viewport().set_input_as_handled()  # never an order for the people from here
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_hover = tile
			if button.pressed:
				_left_press(tile, button.shift_pressed or Input.is_key_pressed(KEY_SHIFT))
			else:
				_left_release(tile)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var tile := _tile_at(make_input_local(event).position)
		if tile == _hover and not (_painting or _grab or _marquee):
			return
		_hover = tile
		if _painting and not _boxing:
			if tile != _last_tile:
				for cell in _line(_last_tile, tile):
					_apply(cell)
				_last_tile = tile
				get_viewport().set_input_as_handled()
		elif _grab and not _dragging and tile != _press_tile:
			_dragging = true
		_refresh_preview()


## Keys in build mode. Returns true if one was used.
func _key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_ESCAPE:
			if _cancel_gesture():
				return true
			if not selection.is_empty():
				selection.clear()
				_announce()
				queue_redraw()
				return true
			if not clear_tool():
				set_active(false)
			return true
		KEY_DELETE, KEY_BACKSPACE:
			if str(tool["kind"]) == SELECT and not selection.is_empty():
				remove_selection()
				return true
		KEY_Z:
			if event.is_command_or_control_pressed():
				if event.shift_pressed:
					redo()
				else:
					undo()
				return true
		KEY_Y:
			if event.is_command_or_control_pressed():
				redo()
				return true
	return false


## Every tile on the way from `a` (not included) to `b`, so a fast drag leaves no gaps.
static func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := b - a
	var steps := maxi(absi(delta.x), absi(delta.y))
	for i in range(1, steps + 1):
		cells.append(a + Vector2i(roundi(delta.x * float(i) / steps), roundi(delta.y * float(i) / steps)))
	return cells


# --- the mouse ----------------------------------------------------------------------------------

func _left_press(tile: Vector2i, shift: bool) -> void:
	_press_tile = tile
	if not _carrying.is_empty():
		_set_down(tile)
		return
	var kind := str(tool["kind"])
	match kind:
		SELECT:
			_select_press(tile, shift)
		"move":
			_pick_up(tile)
		"pick":
			_take_style(tile)
		"unroof":
			sim.build_history.begin()
			var result := BuildEditor.unroof(sim, tile)
			sim.build_history.end()
			_report(result)
			_changed()
		_:
			_begin_stroke(tile, kind, shift)
	_refresh_preview()


func _select_press(tile: Vector2i, shift: bool) -> void:
	var held := sim.world.can_build_at(tile)
	if held and _selected_index(tile) >= 0:
		_grab = true  # a drag from something already picked out moves everything picked out
		return
	var target := BuildEditor.target_at(sim, tile) if held else {}
	if not target.is_empty():
		if not shift:
			selection.clear()
		selection.append(target)
		_grab = true
		_announce()
	else:
		if not shift:
			selection.clear()
			_announce()
		_marquee = true


func _left_release(tile: Vector2i) -> void:
	if _painting:
		if _boxing:
			_finish_box()
		_painting = false
		_boxing = false
		sim.build_history.end()
		_changed()
	elif _dragging:
		_drop_drag(tile)
	elif _grab:
		_grab = false
		if selection.size() > 1 and not Input.is_key_pressed(KEY_SHIFT):
			var clicked := BuildEditor.target_at(sim, tile)  # a plain click on one of several picks just that one
			if not clicked.is_empty():
				selection.assign([clicked])
				_announce()
	elif _marquee:
		_marquee = false
		var low := Vector2i(mini(_press_tile.x, tile.x), mini(_press_tile.y, tile.y))
		var high := Vector2i(maxi(_press_tile.x, tile.x), maxi(_press_tile.y, tile.y))
		var count := (high.x - low.x + 1) * (high.y - low.y + 1)
		if count > 1 and count <= BOX_LIMIT:
			for item in BuildEditor.movables_in(sim, Rect2i(low, high - low + Vector2i.ONE)):
				if _selected_index(item["tile"], str(item["type"])) < 0:
					selection.append(item)
			_announce()
	_refresh_preview()


## Starts a click-and-drag with a tool that draws, plans or takes down.
func _begin_stroke(tile: Vector2i, kind: String, shift: bool) -> void:
	_stroke_tiles = 0
	_stroke_complained = false
	_last_tile = tile
	sim.build_history.begin()
	if shape == "fill" and kind == "floor":
		_apply_fill(tile)
		sim.build_history.end()
		_changed()
		return
	_painting = true
	_boxing = false
	var drags := kind in ["floor", "remove"] or (kind == "place" and bool(DataRegistry.get_def("objects", str(tool["id"])).get("drag", false)))
	if drags and (shape == "box" or shift):
		_boxing = true  # the rectangle is made when the button comes up
		return
	_apply(tile)


func _finish_box() -> void:
	var tiles := BuildEditor.box_tiles(_press_tile, _hover, str(tool["kind"]) == "place")
	if tiles.size() > BOX_LIMIT:
		message.emit("That is a lot of ground; try a smaller box")
		return
	for cell in tiles:
		_apply(cell)


func _apply_fill(tile: Vector2i) -> void:
	var fill := BuildEditor.fill_tiles(sim, tile)
	if str(fill["reason"]) != "":
		message.emit("Can't fill it: %s" % str(fill["reason"]))
		return
	var placed := 0
	for cell in fill["tiles"]:
		if bool(BuildEditor.plan(sim, "floor", str(tool["id"]), cell)["ok"]):
			placed += 1
	_after_planning(placed > 0, "floor")
	if placed == 0:
		message.emit("It already has that floor")


func _apply(tile: Vector2i) -> void:
	var first := _stroke_tiles == 0
	_stroke_tiles += 1
	var result := { "ok": true, "message": "" }
	var kind := str(tool["kind"])
	var id := str(tool["id"])
	match kind:
		"place":
			# furniture goes down one per click; walls can be dragged out in a line
			if not first and not bool(DataRegistry.get_def("objects", id).get("drag", false)):
				return
			result = BuildEditor.plan(sim, "object", id, tile)
		"floor":
			result = BuildEditor.plan(sim, "floor", id, tile)
		"roof":
			if not first:
				return
			result = BuildEditor.plan(sim, "roof", id, tile)
		"remove":
			result = BuildEditor.remove_tile(sim, tile)
	_after_planning(bool(result["ok"]), kind)
	if not result["ok"] and str(result["message"]) != "" and not _stroke_complained:
		_stroke_complained = true  # one complaint per drag is enough
		message.emit(str(result["message"]))
	_refresh_preview()


func _after_planning(done: bool, kind: String) -> void:
	if done and not _hinted and kind in ["place", "floor", "roof"]:
		_hinted = true
		message.emit("Planned. Someone has to build it: leave build mode (B), then right-click one of your folk and choose \"Work on the building\".")


## Picks up the thing under the mouse with the Move tool.
func _pick_up(tile: Vector2i) -> void:
	var target := BuildEditor.target_at(sim, tile) if sim.world.can_build_at(tile) else {}
	if target.is_empty():
		message.emit("Nothing there to move")
		return
	var refusal := BuildEditor.move_refusal(target)
	if refusal != "":
		message.emit("Can't move it: %s" % refusal)
		return
	_carrying.assign([target])
	_anchor = tile
	_announce()


func _set_down(tile: Vector2i) -> void:
	var delta := tile - _anchor
	if delta == Vector2i.ZERO:
		_carrying.clear()  # set it back where it was
		_announce()
		return
	var result := _move(_carrying, delta)
	if bool(result["ok"]):
		selection.assign(_carrying)
		_carrying.clear()
		_announce()
	_report(result)
	_refresh_preview()


## The button came up after dragging the selection.
func _drop_drag(tile: Vector2i) -> void:
	var delta := tile - _press_tile
	_dragging = false
	_grab = false
	if delta != Vector2i.ZERO:
		_report(_move(selection, delta))
	_refresh_preview()


## Moves items (and, if that worked, the items themselves know where they are now).
func _move(items: Array[Dictionary], delta: Vector2i) -> Dictionary:
	sim.build_history.begin()
	var result := BuildEditor.move(sim, items, delta)
	sim.build_history.end()
	if bool(result["ok"]):
		for item in items:
			item["tile"] = (item["tile"] as Vector2i) + delta
		_changed()
	return result


## Takes up the style of what is under the mouse: the tool becomes that thing.
func _take_style(tile: Vector2i) -> void:
	var target := BuildEditor.target_at(sim, tile, true) if sim.world.can_build_at(tile) else {}
	var chosen := BuildEditor.pick(target)
	if chosen.is_empty():
		message.emit("Nothing there to copy")
		return
	set_tool(str(chosen["kind"]), str(chosen["id"]))
	picked_style.emit(str(chosen["kind"]), str(chosen["id"]))


func _report(result: Dictionary) -> void:
	if str(result.get("message", "")) != "":
		message.emit(str(result["message"]))


func _changed() -> void:
	history_changed.emit(sim.build_history.can_undo(), sim.build_history.can_redo())


## Puts an end to any gesture in progress (a drag, a box, something picked up). Returns true if there was one.
func _cancel_gesture() -> bool:
	var had := _painting or _grab or _dragging or _marquee or not _carrying.is_empty()
	if _painting and sim != null:
		sim.build_history.end()
	_painting = false
	_boxing = false
	_grab = false
	_dragging = false
	_marquee = false
	if not _carrying.is_empty():
		_carrying.clear()
		_announce()
	if had:
		_refresh_preview()
	return had


func _selected_index(tile: Vector2i, type: String = "") -> int:
	for index in selection.size():
		if selection[index]["tile"] == tile and (type == "" or str(selection[index]["type"]) == type):
			return index
	return -1


# --- right-click and the menu -------------------------------------------------------------------

func _right_click(screen_position: Vector2, tile: Vector2i) -> void:
	if _cancel_gesture():
		return
	if str(tool["kind"]) != SELECT:
		clear_tool()
		return
	var target := BuildEditor.target_at(sim, tile, true) if sim.world.can_build_at(tile) else {}
	if target.is_empty():
		selection.clear()
		_announce()
		queue_redraw()
		return
	var items: Array[Dictionary] = []
	if _selected_index(tile) >= 0:
		items.assign(selection)
	else:
		items.assign([target])
		selection.assign(items)
		_announce()
	_menu_items = items
	_menu_tile = tile
	menu_requested.emit(screen_position, _menu_title(items), _menu_actions(items, tile))
	queue_redraw()


func _menu_title(items: Array[Dictionary]) -> String:
	if items.size() == 1:
		return BuildEditor.describe(sim, items[0])
	return "%d things" % items.size()


func _menu_actions(items: Array[Dictionary], tile: Vector2i) -> Array[Dictionary]:
	var many := items.size() > 1
	var actions: Array[Dictionary] = []
	var cannot_move := ""
	var cannot_remove := ""
	for item in items:
		if cannot_move == "":
			cannot_move = BuildEditor.move_refusal(item)
		if cannot_remove == "":
			cannot_remove = BuildEditor.remove_refusal(item)
	var move_action := { "id": "move", "label": "Move all %d" % items.size() if many else "Move", "enabled": cannot_move == "" }
	if cannot_move != "":
		move_action["reason"] = cannot_move
	actions.append(move_action)
	var removal := "Take down all %d" % items.size() if many else "Take down"
	if not many:
		match str(items[0]["type"]):
			"plan":
				removal = "Call off the plan"
			"floor":
				removal = "Take up the floor"
	var remove_action := { "id": "remove", "label": removal, "enabled": cannot_remove == "" }
	if cannot_remove != "":
		remove_action["reason"] = cannot_remove
	actions.append(remove_action)
	if not many:
		var chosen := BuildEditor.pick(items[0])
		actions.append({ "id": "pick", "label": "Copy its style", "enabled": not chosen.is_empty(), "reason": "nothing to copy" })
	if sim.world.roof_at(tile) != "":
		actions.append({ "id": "unroof", "label": "Take the roof off this room", "enabled": true })
	return actions


## A choice from the menu.
func perform(action_id: String) -> void:
	if not active or sim == null or _menu_items.is_empty():
		return
	var items: Array[Dictionary] = []
	items.assign(_menu_items)
	match action_id:
		"move":
			_carrying.assign(items)
			_anchor = _menu_tile
			_announce()
		"remove":
			selection.assign(items)
			remove_selection()
		"pick":
			var chosen := BuildEditor.pick(items[0])
			if not chosen.is_empty():
				set_tool(str(chosen["kind"]), str(chosen["id"]))
				picked_style.emit(str(chosen["kind"]), str(chosen["id"]))
		"unroof":
			sim.build_history.begin()
			_report(BuildEditor.unroof(sim, _menu_tile))
			sim.build_history.end()
			_changed()
	_menu_items = []
	_refresh_preview()


# --- the selection, undo and redo ---------------------------------------------------------------

## Takes down everything selected, as one step that Ctrl+Z puts back.
func remove_selection() -> void:
	if sim == null or selection.is_empty():
		return
	var complaint := ""
	sim.build_history.begin()
	for item in selection:
		var result := BuildEditor.remove(sim, item)
		if not bool(result["ok"]) and complaint == "":
			complaint = str(result["message"])
	sim.build_history.end()
	selection.clear()
	if complaint != "":
		message.emit(complaint)
	_announce()
	_changed()
	_refresh_preview()


## Selects what is topmost on a tile (as a click with the hand does); `add` keeps what was selected already.
func select_tile(tile: Vector2i, add: bool = false) -> void:
	if sim == null or not sim.world.can_build_at(tile):
		return
	var target := BuildEditor.target_at(sim, tile)
	if target.is_empty():
		return
	if not add:
		selection.clear()
	selection.append(target)
	_announce()
	queue_redraw()


func undo() -> void:
	if sim == null:
		return
	_cancel_gesture()
	selection.clear()
	_report(BuildEditor.undo(sim))
	_announce()
	_changed()
	_refresh_preview()


func redo() -> void:
	if sim == null:
		return
	_cancel_gesture()
	selection.clear()
	_report(BuildEditor.redo(sim))
	_announce()
	_changed()
	_refresh_preview()


# --- drawing ------------------------------------------------------------------------------------

func _cell_rect(tile: Vector2i) -> Rect2:
	var size := float(MapView.TILE_SIZE)
	return Rect2(Vector2(Levels.ground(tile)) * size, Vector2(size, size))


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

	# what is picked out
	for item in selection:
		if Levels.shown(item["tile"]):
			var box := _cell_rect(item["tile"])
			draw_rect(box, Color(PICKED.r, PICKED.g, PICKED.b, 0.16))
			draw_rect(box.grow(-1.0), PICKED, false, 2.0)
	for item in _carrying:
		if Levels.shown(item["tile"]):
			draw_rect(_cell_rect(item["tile"]), Color(PICKED.r, PICKED.g, PICKED.b, 0.10))
	if _marquee:
		var low := Vector2i(mini(_press_tile.x, _hover.x), mini(_press_tile.y, _hover.y))
		var high := Vector2i(maxi(_press_tile.x, _hover.x), maxi(_press_tile.y, _hover.y))
		var area := Rect2(Vector2(Levels.ground(low)) * size, Vector2(high - low + Vector2i.ONE) * size)
		draw_rect(area, Color(PICKED.r, PICKED.g, PICKED.b, 0.12))
		draw_rect(area, PICKED, false, 2.0)

	if not sim.world.in_bounds(_hover.x, _hover.y):
		return
	var cell := _cell_rect(_hover)
	var kind := str(tool["kind"])
	for roof_tile in _roof_tiles:
		draw_rect(_cell_rect(roof_tile), Color(0.55, 0.85, 0.50, 0.35) if kind == "roof" else Color(0.95, 0.55, 0.30, 0.35))
	for shape_tile in _shape_cells:
		var tint := BAD if kind == "remove" else GOOD
		draw_rect(_cell_rect(shape_tile), Color(tint.r, tint.g, tint.b, 0.28))
	var move_color := GOOD if _hover_reason == "" else BAD
	for move_tile in _move_cells:
		var landing := _cell_rect(move_tile)
		draw_rect(landing, Color(move_color.r, move_color.g, move_color.b, 0.22))
		draw_rect(landing.grow(-1.0), move_color, false, 2.0)
	if (kind == "roof" or kind == "unroof") and _roof_tiles.is_empty():
		draw_rect(cell, Color(BAD.r, BAD.g, BAD.b, 0.30))
	if not _hover_target.is_empty() and _move_cells.is_empty():
		var color := PICKED
		match kind:
			"remove":
				color = BAD
			"pick":
				color = Color(0.45, 0.80, 0.95)
			SELECT:
				color = Color(1, 1, 1)
		var usable := sim.world.can_build_at(_hover)
		draw_rect(cell, Color(color.r, color.g, color.b, 0.22 if usable else 0.06))
		draw_rect(cell.grow(-1.0), Color(color.r, color.g, color.b, 0.95 if usable else 0.35), false, 2.0)
	var words := _hover_reason
	var words_color := Color(1.0, 0.75, 0.70)
	if words == "" and not _hover_target.is_empty() and _move_cells.is_empty():
		words = BuildEditor.describe(sim, _hover_target)
		words_color = Color(1, 1, 1, 0.95)
	if words != "":
		var camera := get_viewport().get_camera_2d()
		var inverse := 1.0 / camera.zoom.x if camera != null else 1.0
		draw_set_transform(cell.position + Vector2(size * 0.5, size + 14.0 * inverse), 0.0, Vector2(inverse, inverse))
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-110, 0), words, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 13, 4, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(-110, 0), words, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 13, words_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
