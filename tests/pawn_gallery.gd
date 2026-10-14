extends Node2D
## Draws one person of each kind (class, sex, age, work, illness) from all four sides, for
## checking the code-drawn art at a glance. Needs a window (not --headless):
##   godot --path . res://tests/pawn_gallery.tscn -- --shot=gallery.png
## With --shot it saves the picture and quits; without it, it stays open.

const SCALE := 2.4
const CELL := Vector2(140, 150)
const FACINGS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

var _people: Array[Pawn] = []


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
	if shot != "":
		for frame in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for n in _people.size():
		var pawn := _people[n]
		var column := n % 4
		var row := n / 4
		var origin := Vector2(30 + column * CELL.x * 2.2, 40 + row * CELL.y * 0.62)
		var outfit := PawnArt.outfit_for(pawn)
		for f in FACINGS.size():
			draw_set_transform(origin + Vector2(30 + f * 70, 40), 0.0, Vector2.ONE * SCALE * (1.0 if pawn.adult else PawnView.CHILD_SCALE))
			PawnArt.draw(self, pawn.look, FACINGS[f], 1.0, 0.0, false, outfit)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var label := "%s %s %s" % [pawn.class_id, pawn.gender, str(outfit["headwear"]) if outfit["headwear"] != "" else "bare"]
		draw_string(font, origin + Vector2(0, 82), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))
