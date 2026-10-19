extends Node
## A play-through of build mode in the real game, with real mouse and key events (not calls into the
## code), saving a picture at each step. Needs a window, so under xvfb on a machine without a screen:
##   BUILD_PLAY_SHOTS=/some/dir xvfb-run -a godot --path . res://tests/build_play.tscn
## Without BUILD_PLAY_SHOTS it takes no pictures. It prints ALL CHECKS PASSED, or what failed.

var _failures := 0
var _shots := ""
var _step := 0
var main: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_shots = OS.get_environment("BUILD_PLAY_SHOTS")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(2)
	main.menus.new_game_requested.emit(4242, "arrived", "short")
	main.menus.land_confirmed.emit("home")
	await _frames(3)
	var hud: Hud = main.hud
	var build: BuildController = main.build
	var sim: Simulation = main.sim
	var world: WorldState = main.world
	GameClock.set_speed(0)
	sim.household.coins = 5000  # this is about the hand and the mouse, not the price
	var area := _clear_area(world, sim)
	main.camera.zoom = Vector2(0.8, 0.8)
	# keep the work clear of the panel at the top left and, with the catalog folded, of the one at the bottom
	main.camera.position = (Vector2(area.position) + Vector2(area.size) * 0.5) * MapView.TILE_SIZE + Vector2(0, 87)
	await _frames(4)
	_check(build.active and str(build.tool["kind"]) == "select" and hud._build_tool_buttons["select"].button_pressed, "the game opens in build mode with the hand in hand")
	await _shot("start")

	# Choose a floor from the catalog with real clicks, and draw a box of it.
	await _click_control(hud._build_tab_buttons["Floors"])
	await _click_control(_item(hud, "floor", "planks"))
	_check(str(build.tool["kind"]) == "floor" and str(build.tool["id"]) == "planks" and not hud._build_tool_buttons["select"].button_pressed, "clicking planks in the catalog puts them in hand")
	await _click_control(hud._build_shape_buttons["box"])
	await _click_control(hud._fold_button)  # fold the catalog away to see the ground
	var corner := area.position + Vector2i(1, 1)
	var far := area.position + Vector2i(6, 4)
	await _drag(corner, far)
	var planned := 0
	for site in world.sites:
		planned += 1 if site.kind == "floor" else 0
	_check(planned == 6 * 4, "dragging a box lays out a floor plan over all of it (%d of 24 tiles)" % planned)
	await _shot("floor_planned")
	_complete_plans(sim)
	await _frames(3)
	var laid := 0
	for cell in BuildEditor.box_tiles(corner, far, false):
		laid += 1 if world.floor_at(cell) == "planks" else 0
	_check(laid == 24, "built, the floor is all there (%d of 24)" % laid)
	await _shot("floor_built")

	# A wall round it, Box again, then the hand.
	await _click_control(hud._fold_button)
	await _click_control(hud._build_tab_buttons["Structure"])
	await _click_control(_item(hud, "place", "wall"))
	await _click_control(hud._fold_button)
	_check(str(build.tool["kind"]) == "place" and str(build.tool["id"]) == "wall" and build.shape == "box", "the timber wall is in hand, with the box shape")
	await _drag(corner - Vector2i(1, 1), far + Vector2i(1, 1))
	var walls := 0
	for cell in BuildEditor.box_tiles(corner - Vector2i(1, 1), far + Vector2i(1, 1), true):
		walls += 1 if world.site_at(cell, "object") != null else 0
	_check(walls == 8 * 6 - 6 * 4, "a box of walls goes round the edge (%d of 24)" % walls)
	_complete_plans(sim)
	await _click_control(hud._build_shape_buttons["free"])
	await _click_control(hud._build_tool_buttons["select"])
	await _frames(2)
	await _shot("walls_built")

	# The hand: select a floor tile, drag it out of the room, put it back with Ctrl+Z.
	var inside := corner + Vector2i(2, 1)
	var outside := far + Vector2i(4, 2)
	await _click_tile(inside)
	_check(build.selection.size() == 1 and str(build.selection[0]["type"]) == "floor", "a click with the hand selects the floor tile")
	await _shot("floor_selected")
	await _drag(inside, outside)
	_check(world.floor_at(inside) == "" and world.floor_at(outside) == "planks", "dragging it moves it")
	await _shot("floor_moved")
	await _key(KEY_Z, true)
	_check(world.floor_at(inside) == "planks" and world.floor_at(outside) == "", "Ctrl+Z puts it back")

	# Right-click a wall: the build menu opens, and not the people's.
	var wall_tile := corner - Vector2i(1, 0)
	await _click_tile(wall_tile, MOUSE_BUTTON_RIGHT)
	_check(hud._build_menu.visible and not hud._action_menu.visible, "right-clicking a wall opens the build menu and not the people's")
	await _shot("menu")
	var take_down: Button = null
	for button in hud._build_menu.buttons:
		if button.text.begins_with("Take down"):
			take_down = button
	await _click_control(take_down)
	_check(world.object_at(wall_tile) == null and not hud._build_menu.visible, "choosing Take down takes it down")
	await _key(KEY_Z, true)
	_check(world.object_at(wall_tile) != null, "and Ctrl+Z builds it back")

	# Right-click on one of your folk, and on bare ground: still no menu for the people.
	var person: Pawn = sim.household.selected()
	await _click_tile(person.tile, MOUSE_BUTTON_RIGHT)
	_check(not hud._action_menu.visible, "right-clicking a person in build mode gives no orders")
	await _click_tile(area.position + Vector2i(area.size.x - 1, 0), MOUSE_BUTTON_RIGHT)
	_check(not hud._action_menu.visible and str(build.tool["kind"]) == "select", "nor does bare ground")

	# An area: drag over the room to pick it all, take it all down with Delete, bring it all back.
	await _drag(corner - Vector2i(2, 2), far + Vector2i(2, 2))
	var picked := build.selection.size()
	_check(picked >= 24 + 20, "dragging over the ground picks out everything in the area (%d things)" % picked)
	await _shot("area_selected")
	await _key(KEY_DELETE)
	_check(world.floor_at(inside) == "" and world.object_at(wall_tile) == null, "Delete takes it all down")
	await _key(KEY_Z, true)
	_check(world.floor_at(inside) == "planks" and world.object_at(wall_tile) != null, "and one Ctrl+Z puts it all back")
	await _shot("area_restored")

	# Esc steps back out.
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_check(not build.active, "Esc lets go and then leaves build mode")
	await _shot("left")

	print("")
	print("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Bare ground near the middle of the lot, cleared of anything standing on it. Returns the rectangle.
func _clear_area(world: WorldState, sim: Simulation) -> Rect2i:
	var middle := world.lot.position + world.lot.size / 2
	var area := Rect2i(middle - Vector2i(5, 3), Vector2i(11, 7))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			for target in BuildEditor.targets_at(sim, Vector2i(x, y)):
				BuildEditor.remove(sim, target)
	sim.build_history.clear()
	return area


func _item(hud: Hud, kind: String, id: String) -> Button:
	for button in hud._build_items:
		if str(button.get_meta("kind", "")) == kind and str(button.get_meta("id", "")) == id and button.is_visible_in_tree():
			return button
	return null


func _complete_plans(sim: Simulation) -> void:
	var builder: Pawn = sim.household.selected()
	for site in sim.world.sites.duplicate():
		site.progress = 1.0
		Construction.finish(sim, builder, site, _rng)
	sim.build_history.end()


func _screen_of(tile: Vector2i) -> Vector2:
	return main.get_viewport().get_canvas_transform() * ((Vector2(tile) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _move_to(screen: Vector2) -> void:
	Input.warp_mouse(screen)  # the pointer itself goes there too, as the game reads it each frame
	var event := InputEventMouseMotion.new()
	event.position = screen
	event.global_position = screen
	Input.parse_input_event(event)
	await _frames(1)


func _press(screen: Vector2, index: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = screen
	event.global_position = screen
	event.button_index = index
	event.pressed = pressed
	event.button_mask = (1 << (index - 1)) if pressed else 0
	Input.parse_input_event(event)
	await _frames(1)


func _click_at(screen: Vector2, index: int = MOUSE_BUTTON_LEFT) -> void:
	await _move_to(screen)
	await _press(screen, index, true)
	await _press(screen, index, false)


func _click_tile(tile: Vector2i, index: int = MOUSE_BUTTON_LEFT) -> void:
	await _click_at(_screen_of(tile), index)


func _click_control(control: Control) -> void:
	if control == null:
		_check(false, "a button to click was there")
		return
	await _click_at(control.get_global_rect().get_center())


## Press on one tile, move across the ones between, and let go on the last.
func _drag(from: Vector2i, to: Vector2i) -> void:
	var start := _screen_of(from)
	var finish := _screen_of(to)
	await _move_to(start)
	await _press(start, MOUSE_BUTTON_LEFT, true)
	for step in 1 + 6:
		await _move_to(start.lerp(finish, float(step) / 6.0))
	await _press(finish, MOUSE_BUTTON_LEFT, false)


func _key(code: Key, ctrl: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		event.ctrl_pressed = ctrl
		Input.parse_input_event(event)
		await _frames(1)


func _shot(name: String) -> void:
	await _frames(2)
	if _shots == "":
		return
	_step += 1
	DirAccess.make_dir_recursive_absolute(_shots)
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [_shots, _step, name])


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
