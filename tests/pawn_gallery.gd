extends Node2D
## Draws one person of each kind (class, sex, age, work, illness) from all four sides, for
## checking the code-drawn art at a glance. Needs a window (not --headless):
##   godot --path . res://tests/pawn_gallery.tscn -- --shot=gallery.png
## With --shot it saves the picture and quits; without it, it stays open. With --stages=1 it shows
## the stages of life instead (baby to elder, men and women, and an expecting mother). With
## --outfits=1 it shows each outfit (see Clothing), and --painted=1 uses the painted people.

const SCALE := 2.4
const CELL := Vector2(140, 150)
const FACINGS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
const STAGE_AGES := [["baby", 0], ["toddler", 3], ["child", 8], ["youth", 15], ["adult", 30], ["adult", 48], ["elder", 63], ["elder", 76]]

var _people: Array[Pawn] = []
var _stages := false
var _outfits := false
var _anim := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#5d7a3e"))
	var looks := [
		{ "skin": "#e0ac80", "hair": "#4a3220", "top": "#8a4a3a", "bottom": "#4a3d32", "hair_style": 0 },
		{ "skin": "#f0c8a0", "hair": "#b8893f", "top": "#4a6a8a", "bottom": "#3a4048", "hair_style": 1 },
		{ "skin": "#9a6a46", "hair": "#2b2118", "top": "#6a7a4a", "bottom": "#5a4a3a", "hair_style": 3 },
		{ "skin": "#c68e63", "hair": "#8a3a22", "top": "#6a4a7a", "bottom": "#44483a", "hair_style": 2 },
	]
	var i := 0
	for class_id in ["peasant", "burgher", "gentry"]:
		for gender in ["male", "female"]:
			for variant in 4:
				var pawn := Pawn.new()
				pawn.id = i + 1
				pawn.gender = gender
				pawn.class_id = class_id
				pawn.display_name = "%s %s %d" % [class_id, gender, variant]
				pawn.look = looks[(i + variant) % looks.size()].duplicate()
				pawn.adult = variant != 3 or class_id != "peasant"
				pawn.work_job = "tavern_hand" if variant == 2 and class_id != "gentry" else ""
				pawn.illness = "fever" if variant == 1 and class_id == "peasant" and gender == "male" else ""
				_people.append(pawn)
				i += 1
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
		elif arg == "--stages=1":
			_stages = true
		elif arg == "--outfits=1":
			_outfits = true
		elif arg == "--anim=1":
			_anim = true
		elif arg == "--painted=1":
			Settings.painted_characters = true
	if _stages:
		_people.clear()
		for gender in ["male", "female"]:
			for n in STAGE_AGES.size():
				var pawn := Pawn.new()
				pawn.id = _people.size() + 1
				pawn.gender = gender
				pawn.age = STAGE_AGES[n][1]
				pawn.adult = pawn.age >= 18
				pawn.class_id = "peasant"
				pawn.display_name = "%s %s %d" % [gender, STAGE_AGES[n][0], pawn.age]
				pawn.look = looks[(n + (1 if gender == "female" else 0)) % looks.size()].duplicate()
				_people.append(pawn)
		for n in 4:  # an expecting mother, further along each time
			var mother := Pawn.new()
			mother.id = 100 + n
			mother.gender = "female"
			mother.age = 26
			mother.adult = true
			mother.class_id = "peasant"
			mother.display_name = "mother %d" % n
			mother.look = looks[1].duplicate()
			mother.pregnant_since = 0
			mother.pregnancy_minutes = 1000
			_people.append(mother)
	if _anim:
		_people.clear()
		for spec in [["male", 30], ["female", 30], ["male", 15], ["female", 8], ["female", 68]]:
			var pawn := Pawn.new()
			pawn.id = _people.size() + 1
			pawn.gender = spec[0]
			pawn.age = spec[1]
			pawn.adult = pawn.age >= 18
			pawn.class_id = "peasant"
			pawn.display_name = "%s %d" % [spec[0], spec[1]]
			pawn.look = looks[_people.size() % looks.size()].duplicate()
			_people.append(pawn)
	if _outfits:
		_people.clear()
		for spec in [["male", 30, "peasant"], ["female", 30, "burgher"], ["male", 15, "peasant"], ["female", 8, "peasant"], ["male", 70, "peasant"], ["female", 68, "gentry"]]:
			var pawn := Pawn.new()
			pawn.id = _people.size() + 1
			pawn.gender = spec[0]
			pawn.age = spec[1]
			pawn.adult = pawn.age >= 18
			pawn.class_id = spec[2]
			pawn.display_name = "%s %d" % [spec[0], spec[1]]
			pawn.look = looks[(_people.size()) % looks.size()].duplicate()
			_people.append(pawn)
	if shot != "":
		for frame in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if _stages:
		_draw_stages(font)
		return
	if _outfits:
		_draw_outfits(font)
		return
	if _anim:
		_draw_anim(font)
		return
	for n in _people.size():
		var pawn := _people[n]
		var column := n % 4
		var row := n / 4
		var origin := Vector2(30 + column * CELL.x * 2.2, 40 + row * CELL.y * 0.62)
		var outfit := PawnArt.outfit_for(pawn)
		for f in FACINGS.size():
			draw_set_transform(origin + Vector2(30 + f * 70, 40), 0.0, Vector2.ONE * SCALE * PawnArt.stage_scale(str(outfit["stage"])))
			PawnArt.draw(self, pawn.look, FACINGS[f], 1.0, 0.0, false, outfit)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var label := "%s %s %s" % [pawn.class_id, pawn.gender, str(outfit["headwear"]) if outfit["headwear"] != "" else "bare"]
		draw_string(font, origin + Vector2(0, 82), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))


func _draw_stages(font: Font) -> void:
	for n in _people.size():
		var pawn := _people[n]
		var row := 0 if n < 8 else (1 if n < 16 else 2)
		var column := n % 8 if n < 16 else n - 16
		var origin := Vector2(14 + column * 156, 30 + row * 220)
		var outfit := PawnArt.outfit_for(pawn)
		if n >= 16:
			var bump_progress: float = [0.40, 0.6, 0.85, 1.0][n - 16]
			outfit["bump"] = Pregnancy.bump_at(bump_progress)
			outfit["belt"] = bump_progress < 0.5
		var scale := SCALE * 1.1 * PawnArt.stage_scale(str(outfit["stage"]))
		for f in 2:
			draw_set_transform(origin + Vector2(34 + f * 64, 80), 0.0, Vector2.ONE * scale)
			PawnArt.draw(self, pawn.look, FACINGS[f], 1.0, 0.0, false, outfit)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string(font, origin + Vector2(0, 140), pawn.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))


## One row for each outfit (data/clothing.json), a person of each stage across.
func _draw_outfits(font: Font) -> void:
	var row := 0
	for outfit_id in Clothing.outfit_ids():
		draw_string(font, Vector2(8, 46 + row * 82), outfit_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95))
		for n in _people.size():
			var pawn := _people[n]
			var outfit := PawnArt.outfit_for(pawn, outfit_id)
			var scale := SCALE * 0.8 * PawnArt.stage_scale(str(outfit["stage"]))
			for f in 2:
				draw_set_transform(Vector2(110 + n * 150 + f * 60, 46 + row * 82), 0.0, Vector2.ONE * scale)
				PawnArt.draw(self, pawn.look, FACINGS[f * 2], 1.0, 0.0, false, outfit)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		row += 1


## Each person walking (eight steps of the cycle, seen from the front) and then at work, talking and standing.
func _draw_anim(font: Font) -> void:
	for n in _people.size():
		var pawn := _people[n]
		var outfit := PawnArt.outfit_for(pawn)
		var scale := SCALE * 0.9 * PawnArt.stage_scale(str(outfit["stage"]))
		var y := 70.0 + n * 150.0
		for step in 8:
			draw_set_transform(Vector2(40.0 + step * 74.0, y), 0.0, Vector2.ONE * scale)
			PawnArt.draw(self, pawn.look, Vector2i(0, 1), 1.0, TAU * step / 8.0 + 0.2, false, outfit)
		for step in 4:
			var working := outfit.duplicate()
			working["act"] = "work"
			working["clock"] = step * 0.22
			draw_set_transform(Vector2(660.0 + step * 74.0, y), 0.0, Vector2.ONE * scale)
			PawnArt.draw(self, pawn.look, Vector2i(0, 1), 1.0, 0.0, false, working, 0.0)
		for step in 2:
			var talking := outfit.duplicate()
			talking["act"] = "talk"
			talking["clock"] = 0.5 + step * 0.9
			draw_set_transform(Vector2(980.0 + step * 74.0, y), 0.0, Vector2.ONE * scale)
			PawnArt.draw(self, pawn.look, Vector2i(0, 1), 1.0, 0.0, false, talking, 0.0)
		draw_set_transform(Vector2(1160.0, y), 0.0, Vector2.ONE * scale)
		PawnArt.draw(self, pawn.look, Vector2i(0, 1), 1.0, 0.0, false, outfit, 0.0)
		draw_set_transform(Vector2(1240.0, y), 0.0, Vector2.ONE * scale)
		PawnArt.draw(self, pawn.look, Vector2i(0, -1), 1.0, 1.1, false, outfit, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string(font, Vector2(8, y + 62), pawn.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))
