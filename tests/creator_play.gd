extends Node
## Plays the family creator in the real game: every age and gender, every look, saving the picture of the
## person each time and checking that something is drawn. Needs a window:
##   CREATOR_PLAY_SHOTS=/some/dir xvfb-run -a godot --path . res://tests/creator_play.tscn

var _failures := 0
var _shots := ""
var main: Node


func _ready() -> void:
	_shots = OS.get_environment("CREATOR_PLAY_SHOTS")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(2)
	main.menus.open_new_game()
	main.menus.open_create()
	await _frames(3)
	var creator: FamilyCreator = main.menus._creator
	var ages := FamilyDesign.AGES
	var cells: Array[Image] = []
	for gender in ["female", "male"]:
		for age_index in ages.size():
			var member: Dictionary = creator._member()
			member["gender"] = gender
			member["age"] = int(ages[age_index][1])
			creator._refresh()
			await _frames(2)
			var looks := creator._look_row.get_child_count() - 1
			for look_index in maxi(looks, 1):
				if looks > 0:
					var button: Button = creator._look_row.get_child(1 + look_index)
					await _click(button.get_global_rect().get_center())
					await _frames(3)
				var picture := await _portrait_picture(creator)
				var drawn := _opaque_share(picture)
				_check(drawn > 0.01, "%s, %s, look %d: the person is drawn (%.0f%% of the frame)" % [gender, ages[age_index][0], look_index + 1, drawn * 100.0])
				cells.append(picture)
	# Then a long run of random choices, looking for the moment the person goes missing.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var trail: Array[String] = []
	var lost := 0
	for step in 220:
		var done := await _random_action(creator, rng)
		trail.append(done)
		if trail.size() > 6:
			trail.pop_front()
		await _frames(2)
		var share := _opaque_share(await _portrait_picture(creator))
		if share < 0.01:
			lost += 1
			print("  FAIL  the person vanished after: ", " / ".join(trail), " (%.1f%%)" % (share * 100.0))
			_failures += 1
			if _shots != "":
				var shot := get_viewport().get_texture().get_image()
				DirAccess.make_dir_recursive_absolute(_shots)
				shot.save_png("%s/vanished_%d.png" % [_shots, lost])
			if lost >= 4:
				break
	_check(lost == 0, "through %d random choices the person never vanished" % 220)
	if _shots != "":
		_sheet(cells, 3 * 0 + 6)
	print("")
	print("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## One random click in the creator; says what it was.
func _random_action(creator: FamilyCreator, rng: RandomNumberGenerator) -> String:
	var roll := rng.randi_range(0, 9)
	var button: Control = null
	var what := ""
	if roll <= 2 and creator._look_row.get_child_count() > 1:
		var index := rng.randi_range(1, creator._look_row.get_child_count() - 1)
		button = creator._look_row.get_child(index)
		what = "look %d" % index
	elif roll == 3:
		var swatches := creator._skin_row.get_child_count() - 1
		var index := rng.randi_range(1, swatches)
		button = creator._skin_row.get_child(index)
		what = "skin %d" % index
	elif roll == 4:
		var index := rng.randi_range(0, creator._tabs.get_child_count() - 1)
		button = creator._tabs.get_child(index)
		what = "person %d" % (index + 1)
	elif roll == 5:
		var gender: String = ["female", "male"][rng.randi_range(0, 1)]
		button = creator._gender_buttons[gender]
		what = gender
	elif roll == 6:
		creator._age_option.select(rng.randi_range(0, FamilyDesign.AGES.size() - 1))
		creator._age_option.item_selected.emit(creator._age_option.selected)
		what = "age %d" % creator._age_option.selected
	elif roll == 7:
		button = creator._add_button if rng.randf() < 0.5 else creator._remove_button
		what = "add/remove"
	elif roll == 8 and creator._look_row.get_child_count() <= 1:
		var index := rng.randi_range(1, maxi(1, creator._hair_row.get_child_count() - 1))
		if creator._hair_row.get_child_count() > 1:
			button = creator._hair_row.get_child(index)
		what = "hair %d" % index
	else:
		var index := rng.randi_range(1, maxi(1, creator._style_row.get_child_count() - 1))
		if creator._style_row.get_child_count() > 1:
			button = creator._style_row.get_child(index)
		what = "style %d" % index
	if button != null and button is Button and not (button as Button).disabled:
		await _click(button.get_global_rect().get_center())
	return what


## The picture of the portrait frame.
func _portrait_picture(creator: FamilyCreator) -> Image:
	await _frames(2)
	var frame: Control = creator._portrait.get_parent()
	var rect := frame.get_global_rect()
	var image := get_viewport().get_texture().get_image()
	return image.get_region(Rect2i(rect.position, rect.size).intersection(Rect2i(Vector2i.ZERO, image.get_size())))


## The share of the frame that is the dark outline of a drawn person (the frame itself is light olive).
func _opaque_share(picture: Image) -> float:
	var dark := 0
	var total := 0
	for y in range(8, picture.get_height() - 8):
		for x in range(8, picture.get_width() - 8):
			total += 1
			var pixel := picture.get_pixel(x, y)
			if pixel.r + pixel.g + pixel.b < 0.9:
				dark += 1
	return float(dark) / float(maxi(total, 1))


func _click(screen: Vector2) -> void:
	for pressed in [false, true, false]:
		if pressed == false and screen == Vector2.ZERO:
			continue
		var motion := InputEventMouseMotion.new()
		motion.position = screen
		motion.global_position = screen
		Input.warp_mouse(screen)
		Input.parse_input_event(motion)
		await _frames(1)
		break
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = screen
		event.global_position = screen
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = 1 if pressed else 0
		Input.parse_input_event(event)
		await _frames(1)


func _sheet(cells: Array[Image], columns: int) -> void:
	if cells.is_empty():
		return
	var cell := cells[0].get_size()
	var rows := ceili(float(cells.size()) / columns)
	var sheet := Image.create(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8)
	for index in cells.size():
		sheet.blit_rect(cells[index], Rect2i(Vector2i.ZERO, cell), Vector2i((index % columns) * cell.x, (index / columns) * cell.y))
	DirAccess.make_dir_recursive_absolute(_shots)
	sheet.save_png("%s/creator_looks.png" % _shots)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
