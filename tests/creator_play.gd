extends Node
## Plays the family creator in the real game: every age and gender, every look, saving the picture of the
## person each time and checking that something is drawn. Needs a window:
##   CREATOR_PLAY_SHOTS=/some/dir CREATOR_PLAY_STEPS=220 xvfb-run -a godot --path . res://tests/creator_play.tscn
## (Godot 4.4 under xvfb now and then dies at start or mid-run with "Index p_index = 1 is out of bounds": an engine crash, not a failure here; run it again.)

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
	await _sections(creator)
	# Then a long run of random choices, looking for the moment the person goes missing.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var trail: Array[String] = []
	var lost := 0
	var steps := int(OS.get_environment("CREATOR_PLAY_STEPS")) if OS.get_environment("CREATOR_PLAY_STEPS") != "" else 220
	for step in steps:
		var done := await _random_action(creator, rng)
		trail.append(done)
		if trail.size() > 6:
			trail.pop_front()
		await _frames(2)
		if not creator._portrait.is_visible_in_tree():  # the Family tree takes the picture's room: look from another section
			await _open(creator, "looks")
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
	_check(lost == 0, "through %d random choices the person never vanished" % steps)
	if _shots != "":
		_sheet(cells, 3 * 0 + 6)
	print("")
	print("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## The sections of the creator, one by one with real clicks: looks, clothes, traits and the family tree.
func _sections(creator: FamilyCreator) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var make := func(given: String, gender: String, age: int) -> Dictionary:
		var member := FamilyDesign.random_member(rng, "Thatcher", [], age)
		member["given"] = given
		member["gender"] = gender
		member["traits"] = ["bisexual", "neat"] if age >= 18 else ["neat"]
		return member
	creator.design = { "family": "Thatcher", "members": [make.call("Maud", "female", 42), make.call("Wat", "male", 45), make.call("Ann", "female", 15), make.call("Tom", "male", 8)] }
	creator._selected = 0
	creator._refresh()
	await _frames(3)
	for entry in FamilyCreator.SECTIONS:
		await _click((creator._section_buttons[entry[0]] as Button).get_global_rect().get_center())
		await _frames(2)
		var showing := 0
		for id in creator._sections:
			showing += 1 if (creator._sections[id] as Control).visible else 0
		_check(creator._section == entry[0] and (creator._sections[entry[0]] as Control).visible and showing == 1, "%s opens on its own" % entry[1])
		_shot("section_%s" % entry[0])
	# Looks: a swatch, a hair style, a colour from the picker.
	await _open(creator, "looks")
	var before := str(creator._member()["skin"])
	await _click((creator._skin_row.get_child(creator._skin_row.get_child_count() - 1) as Control).get_global_rect().get_center())
	await _frames(3)
	_check(str(creator._member()["skin"]) == FamilyCreator.SKIN_COLORS[FamilyCreator.SKIN_COLORS.size() - 1] and str(creator._member()["skin"]) != before, "clicking the last skin swatch gives the darkest skin")
	_check(creator._skin_picker.color.is_equal_approx(Color(FamilyCreator.SKIN_COLORS[FamilyCreator.SKIN_COLORS.size() - 1])), "and the colour button shows it")
	creator._hair_picker.color = Color("#336699")
	creator._hair_picker.color_changed.emit(Color("#336699"))
	await _frames(3)
	_check(str(creator._member()["hair"]) == "#336699" and _opaque_share(await _portrait_picture(creator)) > 0.01, "any other colour can be picked for the hair, and the person is still drawn")
	if creator._look_row.get_child_count() > 2:
		var second: Button = creator._look_row.get_child(2)
		await _click(second.get_global_rect().get_center())
		await _frames(3)
		_check(str(creator._member().get("hairdo", "")) != "", "a hair style is chosen with a click")
	# Clothes: an outfit to keep to and a piece of their own, and the picture follows.
	await _open(creator, "clothes")
	var formal := -1
	for index in creator._outfit_option.item_count:
		if str(creator._outfit_option.get_item_metadata(index)) == "formal":
			formal = index
	creator._outfit_option.select(formal)
	creator._outfit_option.item_selected.emit(formal)
	await _frames(3)
	_check(formal > 0 and str(creator._member()["outfit"]) == "formal" and str(creator._portrait.outfit.get("clothes", "")) == "formal", "an outfit is chosen and the person is shown in it")
	var top: OptionButton = creator._slot_options["top"]
	var winter := -1
	for index in top.item_count:
		if str(top.get_item_metadata(index)) == "winter_top":
			winter = index
	top.select(winter)
	top.item_selected.emit(winter)
	await _frames(3)
	_check(winter > 0 and str(creator._member()["garments"].get("top", "")) == "winter_top" and str((creator._portrait.outfit["pieces"] as Dictionary).get("top", "")) == "winter_top", "a top of their own replaces the outfit's, in the picture too")
	_check(_opaque_share(await _portrait_picture(creator)) > 0.01, "and the person is drawn")
	_shot("clothes_winter")
	# Traits stay where they were.
	await _open(creator, "traits")
	_check(creator._trait_row.get_child_count() > 3 and creator._orientation_option.get_parent().visible, "the traits and what they are drawn to are in their own section")
	# The family tree: a couple, a child, a click on a card.
	await _open(creator, "family")
	var wat := -1
	for index in creator._partner_option.item_count:
		if int(creator._partner_option.get_item_metadata(index)) == 1:
			wat = index
	creator._partner_option.select(wat)
	creator._partner_option.item_selected.emit(wat)
	await _frames(3)
	_check(FamilyDesign.partner_of(creator.design, 0) == 1 and FamilyDesign.is_married(creator.design, 1) and creator._married_check.button_pressed, "Maud is made Wat's wife")
	var rects := creator._tree.card_rects()
	await _click(creator._tree.get_global_rect().position + rects[2].get_center())
	await _frames(3)
	_check(creator._selected == 2 and creator._tabs.get_child(2).button_pressed, "clicking Ann's card in the tree picks Ann")
	var tom_blocked := false
	for index in creator._parent_options[0].item_count:
		if int(creator._parent_options[0].get_item_metadata(index)) == 3:
			tom_blocked = creator._parent_options[0].is_item_disabled(index)
	_check(tom_blocked, "and Tom, eight, cannot be offered as her parent")
	var maud := -1
	for index in creator._parent_options[0].item_count:
		if int(creator._parent_options[0].get_item_metadata(index)) == 0:
			maud = index
	creator._parent_options[0].select(maud)
	creator._parent_options[0].item_selected.emit(maud)
	await _frames(3)
	_check(FamilyDesign.parents_of(creator.design, 2).size() == 1 and FamilyDesign.parents_of(creator.design, 2)[0] == 0 and "Maud" in creator._parent_options[0].get_item_text(creator._parent_options[0].selected), "Maud is made her mother")
	await _click(creator._suggest_button.get_global_rect().get_center())
	await _frames(3)
	_check(FamilyDesign.tree_problem(creator.design) == "" and FamilyDesign.parents_of(creator.design, 3).size() == 2 and creator.problem() == "", "Suggest a tree gives the children both parents")
	_shot("section_family_suggested")
	creator._select_member_for_test(2)
	creator._member()["age"] = 30
	creator._refresh()
	await _frames(3)
	_check("too young" in creator.problem() and main.menus._create_begin.disabled and "too young" in creator._note.text, "a tree that does not fit stops Begin and says why")
	await _click(creator._clear_button.get_global_rect().get_center())
	await _frames(3)
	_check(creator.problem() == "" and not main.menus._create_begin.disabled and FamilyDesign.parents_of(creator.design, 2).is_empty(), "making them unrelated puts it right")
	# And into the game: the family drawn, with its tree, is the household.
	creator._member()["age"] = 15
	FamilyDesign.suggest_tree(creator.design)
	creator._refresh()
	await _frames(3)
	await _click(main.menus._create_begin.get_global_rect().get_center())
	await _frames(6)
	var household: Household = main.sim.household
	var wife: Pawn = household.pawns[0]
	var daughter: Pawn = household.pawns[2]
	_check(household.pawns.size() == 4 and wife.partner_id == household.pawns[1].id and wife.bond == "married" and wife.id in daughter.parents and household.pawns[1].id in daughter.parents, "Begin makes the household with the family tree: the couple are married, and the children have them for parents")
	main.menus.back_to_create()
	await _frames(2)


func _shot(label: String) -> void:
	if _shots == "":
		return
	DirAccess.make_dir_recursive_absolute(_shots)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots, label])


## Opens a section of the creator with a real click, unless it is open.
func _open(creator: FamilyCreator, id: String) -> void:
	if creator._section != id:
		await _click((creator._section_buttons[id] as Button).get_global_rect().get_center())
		await _frames(2)


## One random click in the creator; says what it was.
func _random_action(creator: FamilyCreator, rng: RandomNumberGenerator) -> String:
	var roll := rng.randi_range(0, 17)
	var button: Control = null
	var what := ""
	if roll <= 1 and creator._look_row.get_child_count() > 1:
		await _open(creator, "looks")
		var index := rng.randi_range(1, creator._look_row.get_child_count() - 1)
		button = creator._look_row.get_child(index)
		what = "hair style %d" % index
	elif roll == 2:
		await _open(creator, "looks")
		var index := rng.randi_range(0, creator._skin_row.get_child_count() - 1)
		button = creator._skin_row.get_child(index)
		what = "skin %d" % index
	elif roll == 3:
		var index := rng.randi_range(0, creator._tabs.get_child_count() - 1)
		button = creator._tabs.get_child(index)
		what = "person %d" % (index + 1)
	elif roll == 4:
		var gender: String = ["female", "male"][rng.randi_range(0, 1)]
		button = creator._gender_buttons[gender]
		what = gender
	elif roll == 5:
		creator._age_option.select(rng.randi_range(0, FamilyDesign.AGES.size() - 1))
		creator._age_option.item_selected.emit(creator._age_option.selected)
		what = "age stage %d" % creator._age_option.selected
	elif roll == 6:
		creator._age_spin.value = rng.randi_range(FamilyDesign.MIN_AGE, FamilyDesign.MAX_AGE)
		what = "age %d" % int(creator._age_spin.value)
	elif roll == 7:
		button = creator._add_button if rng.randf() < 0.5 else creator._remove_button
		what = "add/remove"
	elif roll == 8:
		await _open(creator, "looks")
		var color := Color.from_hsv(rng.randf(), rng.randf(), rng.randf_range(0.2, 1.0))
		var picker: ColorPickerButton = creator._skin_picker if rng.randf() < 0.5 else creator._hair_picker
		picker.color = color
		picker.color_changed.emit(color)
		what = "custom colour"
	elif roll == 9 and creator._hair_row.get_child_count() > 0:
		await _open(creator, "looks")
		var index := rng.randi_range(0, creator._hair_row.get_child_count() - 1)
		button = creator._hair_row.get_child(index)
		what = "hair %d" % index
	elif roll == 10:
		await _open(creator, "looks")
		if creator._style_row.visible and creator._style_row.get_child_count() > 1:
			button = creator._style_row.get_child(rng.randi_range(1, creator._style_row.get_child_count() - 1))
		what = "drawn style"
	elif roll == 11:
		await _open(creator, "clothes")
		var option: OptionButton = creator._outfit_option if rng.randf() < 0.4 else creator._slot_options[Clothing.SLOTS[rng.randi_range(0, 2)]]
		option.select(rng.randi_range(0, option.item_count - 1))
		option.item_selected.emit(option.selected)
		what = "clothes"
	elif roll == 12:
		await _open(creator, "family")
		var option: OptionButton = creator._partner_option if rng.randf() < 0.4 else creator._parent_options[rng.randi_range(0, 1)]
		var index := rng.randi_range(0, option.item_count - 1)
		if not option.is_item_disabled(index):
			option.select(index)
			option.item_selected.emit(index)
		what = "relation"
	elif roll == 13:
		await _open(creator, "family")
		var rects := creator._tree.card_rects()
		if not rects.is_empty():
			await _click(creator._tree.get_global_rect().position + rects[rng.randi_range(0, rects.size() - 1)].get_center())
		what = "tree card"
	elif roll == 14:
		await _open(creator, "family")
		button = creator._suggest_button if rng.randf() < 0.5 else creator._clear_button
		what = "suggest/clear"
	elif roll == 15:
		await _open(creator, ["looks", "clothes", "traits", "family"][rng.randi_range(0, 3)])
		what = "section"
	elif roll == 16:
		await _open(creator, "family")
		creator._married_check.button_pressed = not creator._married_check.button_pressed
		what = "married"
	else:
		await _open(creator, "traits")
		if creator._trait_row.get_child_count() > 0:
			button = creator._trait_row.get_child(rng.randi_range(0, creator._trait_row.get_child_count() - 1))
		what = "trait"
	if button != null and button is Button and not (button as Button).disabled and button.is_visible_in_tree():
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
