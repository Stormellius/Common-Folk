extends Node2D
## Draws one person of each kind (class, sex, age, work, illness) from all four sides, for
## checking the code-drawn art at a glance. Needs a window (not --headless):
##   godot --path . res://tests/pawn_gallery.tscn -- --shot=gallery.png
## With --shot it saves the picture and quits; without it, it stays open. With --stages=1 it shows
## the stages of life instead (baby to elder, men and women, and an expecting mother).

const SCALE := 2.4
const CELL := Vector2(140, 150)
const FACINGS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
const STAGE_AGES := [["baby", 0], ["toddler", 3], ["child", 8], ["youth", 15], ["adult", 30], ["adult", 48], ["elder", 63], ["elder", 76]]

var _people: Array[Pawn] = []
var _stages := false


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
