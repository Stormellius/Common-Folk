class_name PawnArt
extends RefCounted
## Draws a person with code, in the top-down RimWorld manner: a round head over wide
## shoulders, dark outlines, a soft shadow. It is a placeholder that needs no art files.
## To use real sprites later, replace PawnArt.draw() and leave everything else alone.
##
## Everything is measured in "units" where one tile is 48 units wide; `u` scales it to
## the real tile size. Drawing is centered on the pawn's middle, y pointing down.
##
## Besides the colors in `look`, a person wears an `outfit` (see outfit_for): headwear, an
## apron, a belt, a beard, a trim. It is worked out from who they are, so it needs no saving
## and the same person always looks the same.

const HAIR_STYLES := 4  # 0 short, 1 long, 2 shaved, 3 bun
const OUTLINE := Color(0.06, 0.05, 0.05, 0.85)
const EYE := Color(0.10, 0.08, 0.07)
const LINEN := Color(0.86, 0.83, 0.74)
const LEATHER := Color(0.33, 0.22, 0.13)
const GOLD := Color(0.86, 0.69, 0.27)
const STRAW := Color(0.85, 0.72, 0.42)
const HOOD_COLORS := [Color("#6b5a43"), Color("#4f5b3c"), Color("#5e3b33"), Color("#55585c"), Color("#3f4a5c")]
const CAP_COLORS := [Color("#7a2a2a"), Color("#2f3f6a"), Color("#2f4a32"), Color("#2a2624"), Color("#6a4a1e")]
const HAT_COLORS := [Color("#1f1c1c"), Color("#4a1f2a"), Color("#1f2a44")]
const FEATHER_COLORS := [Color("#f0ede4"), Color("#b33a32"), Color("#d8b24a")]
const ILL_TINT := Color(0.74, 0.80, 0.60)
const GREY_HAIR := Color("#d2d0cb")
const WOOD := Color(0.42, 0.29, 0.17)
const CHEEK := Color(0.93, 0.45, 0.42, 0.38)
# What the outfits (data/clothing.json, see Clothing) change.
const NIGHTSHIRT := Color(0.80, 0.84, 0.92)
const UNDER_BOTTOM := Color(0.66, 0.62, 0.54)
const FORMAL_DARK := Color(0.16, 0.15, 0.17)
const COAT := Color(0.36, 0.34, 0.26)
const FUR := Color(0.88, 0.84, 0.76)
const FUR_BROWN := Color(0.40, 0.30, 0.22)
const GLOVE := Color(0.46, 0.46, 0.48)
const SCARF_COLORS := [Color("#a8432f"), Color("#3e5f8a"), Color("#6f7d3c"), Color("#8a6a2f"), Color("#7a3f6a")]

## How each stage of life is built (see data/life_stages.json): the head's radius, how wide the
## body is, and how big the whole figure is drawn. Children have big heads on small bodies.
const BUILDS := {
	"baby":    { "head": 8.6, "torso": 0.70, "scale": 0.74 },
	"toddler": { "head": 10.0, "torso": 0.78, "scale": 0.66 },
	"child":   { "head": 9.4, "torso": 0.88, "scale": 0.80 },
	"youth":   { "head": 8.8, "torso": 0.95, "scale": 0.93 },
	"adult":   { "head": 8.6, "torso": 1.00, "scale": 1.00 },
	"elder":   { "head": 8.4, "torso": 0.97, "scale": 0.97 },
}

const SOUTH := 0
const EAST := 1
const NORTH := 2
const WEST := 3


## How big a person of this stage is drawn, 1 for a grown man or woman.
static func stage_scale(stage: String) -> float:
	return float(BUILDS.get(stage, BUILDS["adult"])["scale"])


## Which of the four views to draw for a walking direction.
static func facing_kind(facing: Vector2i) -> int:
	if facing.x != 0 and absi(facing.x) >= absi(facing.y):
		return EAST if facing.x > 0 else WEST
	return NORTH if facing.y < 0 else SOUTH


## What a person wears besides their colors. Headwear goes by class and sex (a hood or a straw
## hat for peasants, a felt cap for burghers, a feathered hat or a circlet for the gentry, a
## linen coif for many women), counter work brings an apron, and some men are bearded.
static func outfit_for(pawn: Pawn, clothes: String = "casual") -> Dictionary:
	var seed := hash(pawn.seed_name())
	var roll := func(salt: int) -> float: return ObjectArt.hash01(seed, salt, 211)
	var stage := Life.stage_id(pawn)
	if stage == "":
		stage = "adult" if pawn.adult else "child"
	var outfit := { "wedding": pawn.wed_until > GameClock.tick or pawn.job_kind == "wed", "headwear": "", "apron": false, "belt": stage in ["youth", "adult", "elder"], "beard": 0, "trim": false, "pouch": false,
		"ill": pawn.illness != "", "stage": stage, "grey": 0.0, "balding": false, "stick": false, "crying": false }
	if pawn.is_infant():
		outfit["crying"] = Babies.is_crying(pawn)
		return outfit
	var r: float = roll.call(1)
	var female := pawn.gender == "female"
	if stage == "toddler":
		outfit["headwear"] = "coif" if r < 0.45 else ""  # a little linen bonnet
	elif not pawn.adult:
		outfit["headwear"] = "hood" if r < 0.15 else ""
	elif pawn.class_id == "gentry":
		outfit["trim"] = true
		outfit["headwear"] = ("circlet" if r < 0.5 else "coif") if female else ("feather_hat" if r < 0.6 else "")
	elif pawn.class_id == "burgher":
		outfit["pouch"] = true
		outfit["headwear"] = ("coif" if r < 0.55 else ("hood" if r < 0.7 else "")) if female else ("cap" if r < 0.45 else ("hood" if r < 0.6 else ""))
	else:
		outfit["headwear"] = ("coif" if r < 0.45 else ("hood" if r < 0.65 else ("straw_hat" if r < 0.75 else ""))) if female \
			else ("hood" if r < 0.3 else ("straw_hat" if r < 0.55 else ""))
	outfit["apron"] = pawn.work_job in ["tavern_hand", "shop_clerk", "clinic_orderly", "smith", "carpenter"] or (female and pawn.class_id == "peasant" and pawn.adult and roll.call(2) < 0.3)
	if pawn.adult and not female and roll.call(3) < (0.45 if stage != "elder" else 0.7):
		outfit["beard"] = 1 if roll.call(4) < (0.6 if stage != "elder" else 0.3) else 2  # 1 short, 2 full
	outfit["grey"] = clampf((pawn.age - 38) / 30.0, 0.0, 0.92)  # hair goes grey, then white, with the years
	if stage == "elder":
		outfit["stick"] = roll.call(9) < 0.65
		outfit["balding"] = not female and roll.call(10) < 0.5
		var h: float = roll.call(11)
		outfit["headwear"] = ("coif" if h < 0.6 else ("hood" if h < 0.8 else "")) if female \
			else ("cap" if h < 0.35 else ("straw_hat" if h < 0.55 and pawn.class_id == "peasant" else ""))
	outfit["hood_color"] = HOOD_COLORS[int(roll.call(5) * HOOD_COLORS.size()) % HOOD_COLORS.size()]
	outfit["cap_color"] = CAP_COLORS[int(roll.call(6) * CAP_COLORS.size()) % CAP_COLORS.size()]
	outfit["hat_color"] = HAT_COLORS[int(roll.call(7) * HAT_COLORS.size()) % HAT_COLORS.size()]
	outfit["feather"] = FEATHER_COLORS[int(roll.call(8) * FEATHER_COLORS.size()) % FEATHER_COLORS.size()]
	outfit["bump"] = Pregnancy.bump(pawn)
	if float(outfit["bump"]) > 0.3:
		outfit["belt"] = false  # the belt comes off as the belly grows
	outfit["clothes"] = clothes
	outfit["seed"] = seed
	outfit["scarf"] = SCARF_COLORS[int(roll.call(13) * SCARF_COLORS.size()) % SCARF_COLORS.size()]
	match clothes:
		"undergarments", "sleepwear", "swim":
			outfit["apron"] = false
			outfit["belt"] = false
			outfit["trim"] = false
			outfit["pouch"] = false
			outfit["headwear"] = "nightcap" if clothes == "sleepwear" and stage != "toddler" and roll.call(12) < 0.6 else ""
		"formal":
			outfit["apron"] = false
			outfit["belt"] = false
			outfit["trim"] = true
		"winter":
			if outfit["headwear"] in ["", "straw_hat", "cap"] and roll.call(14) < 0.65:
				outfit["headwear"] = "fur_cap"
			outfit["apron"] = false
	return outfit


## Draws one pawn on a CanvasItem (call this from its _draw). `phase` is the walk cycle:
## feet and hands swing with sin(phase); pass 0 to stand still. `breath` is a slow clock for
## the idle rise and fall of the shoulders.
static func draw(ci: CanvasItem, look: Dictionary, facing: Vector2i, u: float, phase: float, lying: bool = false, outfit: Dictionary = {}, breath: float = 0.0) -> void:
	var skin := Color(str(look.get("skin", "#e0ac80")))
	var hair := Color(str(look.get("hair", "#4a3220")))
	var top := Color(str(look.get("top", "#6a7a4a")))
	var bottom := Color(str(look.get("bottom", "#4a3d32")))
	var style := int(look.get("hair_style", 0)) % HAIR_STYLES
	var stage := str(outfit.get("stage", "adult"))
	if SpriteBank.draw_person(ci, facing, u, phase, lying, outfit, breath):
		return
	var clothes := str(outfit.get("clothes", "casual"))
	match clothes:
		"undergarments", "swim":
			top = LINEN.lerp(top, 0.10)
			bottom = UNDER_BOTTOM
		"sleepwear":
			top = NIGHTSHIRT.lerp(top, 0.12)
			bottom = top.darkened(0.06)
		"formal":
			top = top.lerp(FORMAL_DARK, 0.6)
			bottom = bottom.lerp(FORMAL_DARK, 0.55)
		"worker", "warm":
			top = top.darkened(0.10)
		"winter":
			top = top.lerp(COAT, 0.55)
			bottom = bottom.darkened(0.2)
	var bare_feet := clothes in ["undergarments", "sleepwear", "swim"]
	var wedding := bool(outfit.get("wedding", false))
	if wedding:  # wedding clothes: pale linen
		top = top.lerp(Color(0.96, 0.94, 0.88), 0.78)
		bottom = bottom.lerp(Color(0.90, 0.88, 0.82), 0.5)
	var build: Dictionary = BUILDS.get(stage, BUILDS["adult"])
	var body := float(build["torso"])
	var elder := stage == "elder"
	var balding := bool(outfit.get("balding", false))
	hair = hair.lerp(GREY_HAIR, float(outfit.get("grey", 0.0)))
	if outfit.get("ill", false):
		skin = skin.lerp(ILL_TINT, 0.30)
	var headwear := str(outfit.get("headwear", ""))
	var kind := SOUTH if lying else facing_kind(facing)  # in bed: head up, face to the ceiling
	var side := kind == EAST or kind == WEST
	var sx := 1.0 if kind == EAST else (-1.0 if kind == WEST else 0.0)
	var walking := not lying and phase != 0.0
	var swing := (sin(phase) if walking else 0.0) * (0.75 if elder else 1.0)  # the old shuffle
	var rise := 0.0 if walking or lying else sin(breath)
	var bob := -absf(swing) * 1.3 - rise * 0.35
	var sway := 0.0 if side else swing * 0.7  # shoulders roll a little from side to side

	if stage == "baby":
		_swaddled(ci, u, kind, sx, lying, outfit, skin, hair, top)
		return
	_ellipse(ci, Vector2(3.0, 7.0) * u, Vector2(12.0, 6.5) * u, Color(0, 0, 0, 0.22))

	# Feet swing back and forth while walking (a blanket hides them in bed).
	for s in [] if lying else [-1.0, 1.0]:
		var foot := Vector2(swing * s * 4.5, 11.0) if side else Vector2(s * 4.5, 10.5 + swing * s * 3.0)
		_ellipse_outlined(ci, foot * u, Vector2(3.2, 2.8) * u, skin.darkened(0.06) if bare_feet else bottom.darkened(0.25), u)

	# Shoulders, with what is worn over them.
	var torso_center := Vector2(sway, 3.0 + (0.8 if elder and not lying else 0.0))
	var torso_radius := (Vector2(7.6, 7.2) if side else Vector2(11.0, 7.4)) * body * (1.0 + 0.025 * rise) * (Vector2(1.12, 1.1) if clothes == "winter" else Vector2.ONE)
	_ellipse_outlined(ci, torso_center * u, torso_radius * u, top, 1.1 * u)
	_ellipse(ci, (torso_center + Vector2(-1.5, -1.8)) * u, torso_radius * 0.55 * u, Color(1, 1, 1, 0.12))
	_ellipse(ci, (torso_center + Vector2(1.5, 2.6)) * u, torso_radius * Vector2(0.8, 0.45) * u, Color(0, 0, 0, 0.10))  # shade under the arms
	if outfit.get("apron", false):
		_apron(ci, u, kind, sx, torso_center, torso_radius)
	if stage == "toddler" and kind == SOUTH:  # a bib
		_ellipse_outlined(ci, (torso_center + Vector2(0.0, 2.2)) * u, Vector2(3.4, 3.8) * u, LINEN, 0.8 * u)
	if float(outfit.get("bump", 0.0)) > 0.02 and kind != NORTH:
		_bump(ci, u, kind, sx, torso_center, float(outfit["bump"]), top)
	if outfit.get("trim", false):
		var arc_from := 0.15 * PI if kind != NORTH else 0.2 * PI
		ci.draw_arc(torso_center * u, (torso_radius.x - 1.0) * u, arc_from, PI - arc_from, 12, GOLD, maxf(1.0, 1.4 * u))
	if outfit.get("belt", false):
		_belt(ci, u, kind, sx, torso_center, torso_radius, outfit)
	if headwear == "hood":  # the hood's cowl lies over the shoulders
		_ellipse_outlined(ci, (torso_center + Vector2(sx * -1.0, -1.5)) * u, Vector2(8.5 if side else 10.5, 6.0) * u, outfit.get("hood_color", HOOD_COLORS[0]), 0.9 * u)
	match clothes:
		"worker":  # a leather waistcoat
			if not outfit.get("apron", false) and kind != NORTH:
				_ellipse(ci, (torso_center + Vector2(0.0, 1.0)) * u, torso_radius * Vector2(0.66, 0.8) * u, Color(LEATHER, 0.85))
		"formal":  # a white shirt front and collar under a dark waistcoat
			if kind == SOUTH:
				ci.draw_colored_polygon(_scaled(PackedVector2Array([Vector2(-3.2, -3.4) + torso_center, Vector2(3.2, -3.4) + torso_center, Vector2(0.0, 4.2) + torso_center]), u), LINEN)
				ci.draw_polyline(_scaled(PackedVector2Array([Vector2(-3.2, -3.4) + torso_center, Vector2(0.0, 4.2) + torso_center, Vector2(3.2, -3.4) + torso_center]), u), OUTLINE, maxf(1.0, 0.8 * u))
		"warm":  # a scarf round the neck
			_ellipse_outlined(ci, (torso_center + Vector2(sx * -1.0, -1.2)) * u, Vector2(7.4 if side else 9.0, 2.8) * u, outfit.get("scarf", SCARF_COLORS[0]), 0.9 * u)
			if kind == SOUTH:  # the ends hang down the front
				_ellipse_outlined(ci, (torso_center + Vector2(3.6, 1.8)) * u, Vector2(2.0, 3.6) * u, outfit.get("scarf", SCARF_COLORS[0]), 0.8 * u)
		"winter":  # a fur collar
			_ellipse_outlined(ci, (torso_center + Vector2(sx * -1.0, -1.4)) * u, Vector2(8.6 if side else 10.8, 3.4) * u, FUR, 0.9 * u)
	if outfit.get("apron", false):
		_apron(ci, u, kind, sx, torso_center, torso_radius)
	if stage == "toddler" and kind == SOUTH:  # a bib
		_ellipse_outlined(ci, (torso_center + Vector2(0.0, 2.2)) * u, Vector2(3.4, 3.8) * u, LINEN, 0.8 * u)
	if float(outfit.get("bump", 0.0)) > 0.02 and kind != NORTH:
		_bump(ci, u, kind, sx, torso_center, float(outfit["bump"]), top)
	if outfit.get("trim", false):
		var arc_from := 0.15 * PI if kind != NORTH else 0.2 * PI
		ci.draw_arc(torso_center * u, (torso_radius.x - 1.0) * u, arc_from, PI - arc_from, 12, GOLD, maxf(1.0, 1.4 * u))
	if outfit.get("belt", false):
		_belt(ci, u, kind, sx, torso_center, torso_radius, outfit)
	if headwear == "hood":  # the hood's cowl lies over the shoulders
		_ellipse_outlined(ci, (torso_center + Vector2(sx * -1.0, -1.5)) * u, Vector2(8.5 if side else 10.5, 6.0) * u, outfit.get("hood_color", HOOD_COLORS[0]), 0.9 * u)
	match clothes:
		"worker":  # a leather waistcoat
			if not outfit.get("apron", false) and kind != NORTH:
				_ellipse(ci, (torso_center + Vector2(0.0, 0.6)) * u, torso_radius * Vector2(0.6, 0.78) * u, Color(LEATHER, 0.55))
		"formal":  # a white collar
			if kind == SOUTH:
				_ellipse_outlined(ci, (torso_center + Vector2(0.0, -4.8)) * u, Vector2(3.6, 1.7) * u, LINEN, 0.7 * u)
		"warm":  # a scarf round the neck
			_ellipse_outlined(ci, (torso_center + Vector2(sx * -1.0, -4.6)) * u, Vector2(7.2 if side else 8.6, 3.0) * u, outfit.get("scarf", SCARF_COLORS[0]), 0.9 * u)
			if kind == SOUTH:  # the ends hang down the front
				_ellipse_outlined(ci, (torso_center + Vector2(3.4, -1.4)) * u, Vector2(1.9, 3.4) * u, outfit.get("scarf", SCARF_COLORS[0]), 0.8 * u)
		"winter":  # a fur collar
			_ellipse_outlined(ci, (torso_center + Vector2(sx * -1.0, -4.8)) * u, Vector2(8.2 if side else 10.2, 3.6) * u, FUR, 0.9 * u)

	# Hands, coming out of the sleeves.
	for s in [] if lying else [-1.0, 1.0]:
		var hand := Vector2(swing * s * 4.5, 4.5) if side else Vector2(s * 11.5 * body + sway, 4.0 + swing * s * 2.0)
		var cuff := hand + (Vector2(0.0, -1.6) if side else Vector2(-s * 1.4, -1.4))
		_ellipse_outlined(ci, cuff * u, Vector2(2.4, 2.2) * u, top.darkened(0.18), 0.8 * u)
		_ellipse_outlined(ci, hand * u, Vector2(2.6, 2.6) * u, GLOVE if clothes == "winter" else skin, 0.9 * u)
		if bool(outfit.get("stick", false)) and s == 1.0 and not lying:  # a walking stick in the near hand
			var grip := hand + Vector2(0.4, -0.6)
			var foot := Vector2(grip.x + 0.8, 14.0)
			ci.draw_line(grip * u, foot * u, OUTLINE, maxf(1.5, 3.4 * u))
			ci.draw_line(grip * u, foot * u, WOOD, maxf(1.0, 2.0 * u))
			ci.draw_arc((grip + Vector2(-1.4, -0.6)) * u, 1.8 * u, PI * 0.9, PI * 2.05, 8, WOOD, maxf(1.0, 1.8 * u))

	var stoop := elder and not lying
	var head := Vector2(sx * 1.8 + sway * 0.6 + (sx * 1.2 if stoop else 0.0), -5.5 + bob + (1.8 if stoop else (1.0 if stage == "toddler" else (0.6 if stage == "child" else 0.0))))
	var head_radius := float(build["head"])
	var hair_radius := head_radius + 0.9
	var covered := headwear == "hood" or headwear == "coif"

	# Long hair hangs behind the head, over the shoulders.
	if style == 1 and not covered and not balding and kind == NORTH:
		_ellipse_outlined(ci, (head + Vector2(0, 5.0)) * u, Vector2(hair_radius, 10.5) * u, hair, 0.9 * u)
	elif style == 1 and not covered and not balding and side:
		_ellipse_outlined(ci, (head + Vector2(-sx * 3.5, 4.5)) * u, Vector2(5.0, 8.5) * u, hair, 0.9 * u)

	_ellipse_outlined(ci, head * u, Vector2(head_radius, head_radius) * u, skin, 1.1 * u)
	_ellipse(ci, (head + Vector2(-2.5, -3.0)) * u, Vector2(3.5, 3.0) * u, Color(1, 1, 1, 0.10))  # light on the brow

	var hair_color := hair
	if style == 2:  # shaved: just a shadow of stubble
		hair_color = skin.darkened(0.12).lerp(hair, 0.35)
		hair_radius = head_radius + 0.2
	if not covered and balding:
		_balding(ci, hair_color, kind, sx, head, hair_radius, u)
	elif not covered:
		_hair_cap(ci, hair_color, kind, sx, head, hair_radius, u)
		if stage == "toddler" and style != 2:  # a curl on top
			ci.draw_arc((head + Vector2(sx * 1.0, -hair_radius - 0.2)) * u, 2.2 * u, PI * 0.15, PI * 1.55, 8, hair_color, maxf(1.0, 1.8 * u))
		if style == 1 and kind == SOUTH:  # side locks falling in front of the shoulders
			for s in [-1.0, 1.0]:
				_ellipse_outlined(ci, (head + Vector2(s * (hair_radius - 1.4), 4.5)) * u, Vector2(2.8, 7.0) * u, hair, 0.8 * u)
		if style == 3 and headwear == "":  # bun
			var bun := head + Vector2(0, -hair_radius + 0.5)
			if side:
				bun = head + Vector2(-sx * (hair_radius - 0.5), -3.0)
			_ellipse_outlined(ci, bun * u, Vector2(3.4, 3.4) * u, hair, 0.8 * u)

	# Beard under the face: none from behind.
	var beard := int(outfit.get("beard", 0))
	if beard > 0 and kind != NORTH:
		var beard_color := hair.darkened(0.05)
		if kind == SOUTH:
			_ellipse_outlined(ci, (head + Vector2(0, 6.0 + beard * 0.4)) * u, Vector2(3.6 + beard * 1.1, 1.8 + beard * 0.8) * u, beard_color, 0.7 * u)
			ci.draw_line((head + Vector2(-1.4, 4.6)) * u, (head + Vector2(1.4, 4.6)) * u, beard_color.darkened(0.3), maxf(1.0, 0.9 * u))  # moustache
		else:
			_ellipse_outlined(ci, (head + Vector2(sx * 4.4, 5.4 + beard * 0.3)) * u, Vector2(2.2 + beard * 0.6, 1.8 + beard * 0.6) * u, beard_color, 0.7 * u)

	_face_marks(ci, u, kind, sx, head, stage, skin)

	match headwear:
		"hood":
			_hood(ci, u, kind, sx, head, hair_radius, skin, outfit.get("hood_color", HOOD_COLORS[0]))
		"coif":
			_coif(ci, u, kind, sx, head, hair_radius, skin, outfit.get("trim", false), hair)
		"straw_hat":
			_hat(ci, u, kind, sx, head, STRAW, STRAW.darkened(0.12), Color(0.45, 0.30, 0.18), 12.5, false, Color.WHITE)
		"cap":
			_cap(ci, u, kind, sx, head, outfit.get("cap_color", CAP_COLORS[0]))
		"nightcap":
			_cap(ci, u, kind, sx, head, Color(0.88, 0.88, 0.92))
		"fur_cap":
			_cap(ci, u, kind, sx, head, FUR_BROWN)
			if kind != NORTH:  # a pale fur band
				ci.draw_arc((head + Vector2(sx * 0.8, 1.0)) * u, (hair_radius - 0.2) * u, PI * 1.12, PI * 1.88, 12, FUR, maxf(1.5, 2.4 * u))
		"feather_hat":
			var hat_color: Color = outfit.get("hat_color", HAT_COLORS[0])
			_hat(ci, u, kind, sx, head, hat_color, hat_color.lightened(0.12), GOLD, 10.0, true, outfit.get("feather", FEATHER_COLORS[0]))
		"circlet":
			if kind == NORTH:
				ci.draw_arc(head * u, (hair_radius - 1.5) * u, 0.0, TAU, 20, GOLD, maxf(1.0, 1.4 * u))
			else:
				ci.draw_arc((head + Vector2(sx * 0.8, 1.5)) * u, (hair_radius - 0.5) * u, PI * 1.08, PI * 1.92, 12, GOLD, maxf(1.0, 1.6 * u))
				ci.draw_circle((head + Vector2(sx * 3.0, -6.6)) * u, 1.4 * u, Color(0.75, 0.18, 0.22))

	if wedding and kind != NORTH:  # a garland of little flowers over the brow
		for i in 7:
			var angle := PI * (1.12 + 0.76 * i / 6.0)
			var spot := head + Vector2(cos(angle) * (hair_radius - 0.4), sin(angle) * (hair_radius - 0.6) + 1.0)
			if side:
				spot = head + Vector2(sx * (cos(angle) * 2.0 + 1.0), sin(angle) * (hair_radius - 0.6) + 1.0)
			ci.draw_circle(spot * u, 1.5 * u, [Color(0.98, 0.98, 0.95), Color(0.95, 0.62, 0.72), Color(0.99, 0.86, 0.40)][i % 3])

	# Eyes: two from the front, one in profile, none from behind.
	if kind == SOUTH and lying:  # eyes shut
		for s in [-1.0, 1.0]:
			ci.draw_line((head + Vector2(s * 3.3 - 1.6, 1.2)) * u, (head + Vector2(s * 3.3 + 1.6, 1.2)) * u, EYE, maxf(1.0, 1.3 * u))
	elif kind == SOUTH:
		for s in [-1.0, 1.0]:
			_ellipse(ci, (head + Vector2(s * 3.3, 1.0)) * u, Vector2(1.3, 1.5) * u, EYE)
	elif side:
		_ellipse(ci, (head + Vector2(sx * 4.6, 0.8)) * u, Vector2(1.3, 1.5) * u, EYE)


## What a builder is carrying: a bundle of planks, a stone block, held in front.
static func draw_carry(ci: CanvasItem, carrying: Dictionary, facing: Vector2i, u: float) -> void:
	var kind := facing_kind(facing)
	var anchor := Vector2(0.0, 2.0) if kind == SOUTH else (Vector2(0.0, -1.0) if kind == NORTH else Vector2(6.0 * (1.0 if kind == EAST else -1.0), 3.0))
	var shown := 0
	for resource_id in carrying:
		var color := Color(str(DataRegistry.get_def("resources", str(resource_id)).get("color", "#b0a090")))
		for i in mini(int(carrying[resource_id]), 3):
			var spot := anchor + Vector2(-5.0 + shown * 3.2, 7.5 - shown * 1.6)
			ci.draw_rect(Rect2(spot * u, Vector2(8.0, 4.0) * u), OUTLINE)
			ci.draw_rect(Rect2((spot + Vector2(0.6, 0.6)) * u, Vector2(6.8, 2.8) * u), color)
			shown += 1


## The tool in a person's hand (data/tools.json): drawn at the right hand, tilted, and swung while
## `working`. A satchel hangs at the hip instead.
static func draw_tool(ci: CanvasItem, tool_id: String, facing: Vector2i, u: float, clock: float, working: bool) -> void:
	var kind := facing_kind(facing)
	var flip := -1.0 if kind == WEST else 1.0
	var steel := Color(0.66, 0.68, 0.72)
	var wood := Color(0.40, 0.28, 0.16)
	if tool_id == "healers_satchel":
		var hip := Vector2(-10.0 * flip, 6.0)
		ci.draw_set_transform(hip * u, 0.0, Vector2.ONE)
		ci.draw_rect(Rect2(Vector2(-5, -4) * u, Vector2(10, 9) * u), OUTLINE)
		ci.draw_rect(Rect2(Vector2(-4, -3) * u, Vector2(8, 7) * u), Color(0.60, 0.42, 0.26))
		ci.draw_rect(Rect2(Vector2(-4, -3) * u, Vector2(8, 3) * u), Color(0.48, 0.32, 0.19))
		ci.draw_line(Vector2(-1.5, 2) * u, Vector2(1.5, 2) * u, Color(0.86, 0.80, 0.55), maxf(1.0, u))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var hand := Vector2(10.5 * flip, 3.0)
	if kind == EAST:
		hand = Vector2(7.0, 3.0)
	elif kind == NORTH:
		hand = Vector2(10.0, 0.0)
	var angle := (-0.5 + (sin(clock * 7.0) * 0.55 if working else 0.0)) * flip
	ci.draw_set_transform(hand * u, angle, Vector2(flip, 1.0))
	var haft_top := -18.0
	match tool_id:
		"fishing_rod":
			haft_top = -30.0
		"sickle", "herb_knife":
			haft_top = -9.0
		"hammer", "smiths_hammer":
			haft_top = -14.0
	ci.draw_line(Vector2(0, 3) * u, Vector2(0, haft_top) * u, OUTLINE, maxf(1.5, 3.0 * u))
	ci.draw_line(Vector2(0, 3) * u, Vector2(0, haft_top) * u, wood, maxf(1.0, 1.8 * u))
	match tool_id:
		"axe":
			ci.draw_colored_polygon(_scaled(PackedVector2Array([Vector2(0.5, -18), Vector2(8, -21), Vector2(9, -11), Vector2(0.5, -12)]), u), steel)
		"pickaxe":
			ci.draw_line(Vector2(-9, -16) * u, Vector2(9, -18) * u, OUTLINE, maxf(1.5, 3.4 * u))
			ci.draw_line(Vector2(-9, -16) * u, Vector2(9, -18) * u, steel, maxf(1.0, 2.2 * u))
		"sickle":
			ci.draw_arc(Vector2(4, -9) * u, 5.0 * u, PI * 0.5, PI * 1.5, 8, steel, maxf(1.5, 2.0 * u))
		"herb_knife":
			ci.draw_colored_polygon(_scaled(PackedVector2Array([Vector2(-1.2, -9), Vector2(1.2, -9), Vector2(0, -16)]), u), steel)
		"fishing_rod":
			ci.draw_line(Vector2(0, -30) * u, Vector2(5, -20) * u, Color(0.85, 0.85, 0.80), maxf(1.0, 0.7 * u))
		"hammer":
			ci.draw_rect(Rect2(Vector2(-4, -17) * u, Vector2(8, 5) * u), steel)
		"smiths_hammer":
			ci.draw_rect(Rect2(Vector2(-5.5, -19) * u, Vector2(11, 7) * u), Color(0.50, 0.52, 0.58))
			ci.draw_rect(Rect2(Vector2(-5.5, -19) * u, Vector2(11, 2.5) * u), steel)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rosy cheeks on the young, lines on the old.
static func _face_marks(ci: CanvasItem, u: float, kind: int, sx: float, head: Vector2, stage: String, skin: Color) -> void:
	if kind == NORTH:
		return
	if stage == "toddler" or stage == "child":
		if kind == SOUTH:
			for s in [-1.0, 1.0]:
				ci.draw_circle((head + Vector2(s * 5.2, 3.8)) * u, 1.8 * u, CHEEK)
		else:
			ci.draw_circle((head + Vector2(sx * 3.4, 4.0)) * u, 1.8 * u, CHEEK)
	elif stage == "elder":
		var line := skin.darkened(0.24)
		var width := maxf(1.0, 0.8 * u)
		if kind == SOUTH:
			ci.draw_line((head + Vector2(-3.4, -3.6)) * u, (head + Vector2(3.4, -3.6)) * u, line, width)
			ci.draw_line((head + Vector2(-2.4, -2.2)) * u, (head + Vector2(2.4, -2.2)) * u, line, width)
			for s in [-1.0, 1.0]:  # crow's feet
				ci.draw_line((head + Vector2(s * 5.4, 0.4)) * u, (head + Vector2(s * 6.8, -0.5)) * u, line, width)
				ci.draw_line((head + Vector2(s * 5.4, 1.4)) * u, (head + Vector2(s * 6.8, 2.0)) * u, line, width)
		else:
			ci.draw_line((head + Vector2(sx * 1.0, -3.4)) * u, (head + Vector2(sx * 5.6, -3.2)) * u, line, width)
			ci.draw_line((head + Vector2(sx * 3.4, 0.9)) * u, (head + Vector2(sx * 2.0, 0.2)) * u, line, width)


## Thin hair left round the sides and back of a bald head.
static func _balding(ci: CanvasItem, color: Color, kind: int, sx: float, head: Vector2, radius: float, u: float) -> void:
	if kind == NORTH:
		ci.draw_arc(head * u, (radius - 1.4) * u, PI * 0.08, PI * 0.92, 10, color, maxf(2.0, 3.6 * u))
		return
	for s in ([-1.0, 1.0] if kind == SOUTH else [-sx]):
		_ellipse_outlined(ci, (head + Vector2(s * (radius - 1.5), 0.8)) * u, Vector2(2.3, 3.8) * u, color, 0.7 * u)


## A baby is a swaddled bundle with a little round head, asleep (eyes shut) or awake, and crying
## when `outfit.crying` is set.
static func _swaddled(ci: CanvasItem, u: float, kind: int, sx: float, asleep: bool, outfit: Dictionary, skin: Color, hair: Color, top: Color) -> void:
	var wrap := Color(0.92, 0.90, 0.82)
	_ellipse(ci, Vector2(2.0, 10.0) * u, Vector2(10.0, 5.0) * u, Color(0, 0, 0, 0.22))
	_ellipse_outlined(ci, Vector2(0.0, 3.5) * u, Vector2(8.6, 10.8) * u, wrap, 1.1 * u)
	_ellipse(ci, Vector2(-2.2, 0.5) * u, Vector2(4.2, 6.0) * u, Color(1, 1, 1, 0.28))
	var band := top.lightened(0.2)
	ci.draw_line(Vector2(-7.6, 5.0) * u, Vector2(7.6, 5.0) * u, band, maxf(1.5, 2.6 * u))
	for fold in [[-6.0, -1.0, 5.0, 10.0], [6.0, -1.0, -5.0, 10.0]]:
		ci.draw_line(Vector2(fold[0], fold[1]) * u, Vector2(fold[2], fold[3]) * u, wrap.darkened(0.15), maxf(1.0, u))
	var head := Vector2(sx * 1.2, -7.2)
	var head_radius := 8.4
	_ellipse_outlined(ci, head * u, Vector2(head_radius, head_radius - 0.4) * u, skin, 1.1 * u)
	_ellipse(ci, (head + Vector2(-2.5, -3.0)) * u, Vector2(3.0, 2.6) * u, Color(1, 1, 1, 0.10))
	if kind == NORTH:  # the back of its head: soft fuzz
		_ellipse_outlined(ci, (head + Vector2(0.0, -0.4)) * u, Vector2(head_radius, head_radius - 0.8) * u, hair, 0.9 * u)
		return
	_ellipse_outlined(ci, (head + Vector2(sx * 0.8, -head_radius + 1.2)) * u, Vector2(3.6, 2.2) * u, hair, 0.7 * u)  # a tuft
	var crying := bool(outfit.get("crying", false))
	var shut := asleep or crying
	var spots: Array = [-1.0, 1.0] if kind == SOUTH else [sx]
	for s in spots:
		var at := head + (Vector2(s * 3.4, 0.8) if kind == SOUTH else Vector2(s * 4.4, 0.6))
		if shut:
			ci.draw_line((at + Vector2(-1.5, 0.0)) * u, (at + Vector2(1.5, 0.0)) * u, EYE, maxf(1.0, 1.3 * u))
		else:
			_ellipse(ci, at * u, Vector2(1.5, 1.7) * u, EYE)
		ci.draw_circle((at + Vector2(s * 1.8, 3.0)) * u, 1.7 * u, CHEEK)
	var mouth := head + (Vector2(0.0, 4.4) if kind == SOUTH else Vector2(sx * 3.6, 4.4))
	if crying:
		_ellipse(ci, mouth * u, Vector2(2.4, 2.0) * u, Color(0.45, 0.10, 0.10))
	else:
		ci.draw_line((mouth + Vector2(-1.1, 0.0)) * u, (mouth + Vector2(1.1, 0.0)) * u, skin.darkened(0.35), maxf(1.0, 0.9 * u))


## Hair covering the top of the head (and all of it from behind).
static func _hair_cap(ci: CanvasItem, color: Color, kind: int, sx: float, head: Vector2, radius: float, u: float) -> void:
	if kind == NORTH:
		_ellipse_outlined(ci, head * u, Vector2(radius, radius) * u, color, 0.9 * u)
		_ellipse(ci, (head + Vector2(-2.0, -2.5)) * u, Vector2(radius * 0.45, radius * 0.35) * u, Color(1, 1, 1, 0.10))
		return
	var points := PackedVector2Array()
	if kind == SOUTH:
		for i in range(13):
			var a := lerpf(-PI * 0.93, -PI * 0.07, i / 12.0)
			points.append(head + Vector2(cos(a), sin(a)) * radius)
		points.append(head + Vector2(radius * 0.9, -radius * 0.18))
		points.append(head + Vector2(0.0, -radius * 0.52))
		points.append(head + Vector2(-radius * 0.9, -radius * 0.18))
	else:
		for i in range(15):
			var a := lerpf(-PI * 0.30, -PI * 1.20, i / 14.0)
			points.append(head + Vector2(cos(a) * sx, sin(a)) * radius)
		points.append(head + Vector2(sx * radius * 0.15, radius * 0.15))
	_polygon_outlined(ci, points, color, u)
	_ellipse(ci, (head + Vector2(-2.0, -radius * 0.62)) * u, Vector2(radius * 0.40, radius * 0.18) * u, Color(1, 1, 1, 0.12))  # sheen


## A belt at the waist; burghers hang a purse from it and the gentry wear a gilt buckle.
static func _belt(ci: CanvasItem, u: float, kind: int, sx: float, center: Vector2, radius: Vector2, outfit: Dictionary) -> void:
	var y := 4.6
	var half := radius.x * sqrt(maxf(0.0, 1.0 - pow(y / radius.y, 2.0))) - 0.3
	var from := center + Vector2(-half, y)
	var to := center + Vector2(half, y)
	ci.draw_line(from * u, to * u, LEATHER, maxf(1.0, 1.8 * u))
	var buckle := GOLD if outfit.get("trim", false) else Color(0.62, 0.60, 0.55)
	if kind == SOUTH:
		ci.draw_rect(Rect2((center + Vector2(-1.3, y - 1.3)) * u, Vector2(2.6, 2.6) * u), buckle)
	if outfit.get("pouch", false) and kind != NORTH:
		var at := center + Vector2((half - 2.5) * (sx if sx != 0.0 else 1.0), y + 2.2)
		_ellipse_outlined(ci, at * u, Vector2(2.2, 2.6) * u, LEATHER.lightened(0.15), 0.7 * u)


## An expecting mother's belly, rounding out the front of her clothes: `size` 0 (just showing) to
## 1 (due). From behind it does not show.
static func _bump(ci: CanvasItem, u: float, kind: int, sx: float, center: Vector2, size: float, top: Color) -> void:
	var at := center + (Vector2(sx * (4.5 + 2.5 * size), 3.4) if kind != SOUTH else Vector2(0.0, 5.0 + 2.0 * size))
	var radius := Vector2(3.0 + 2.8 * size, 3.6 + 2.4 * size) if kind != SOUTH else Vector2(5.0 + 3.6 * size, 3.6 + 3.2 * size)
	_ellipse(ci, (at + Vector2(0.8, 1.4)) * u, radius * u, Color(0, 0, 0, 0.18))  # it throws a little shade
	_ellipse_outlined(ci, at * u, radius * u, top.lightened(0.10), 0.9 * u)
	_ellipse(ci, (at + Vector2(-radius.x * 0.28, -radius.y * 0.30)) * u, radius * Vector2(0.46, 0.40) * u, Color(1, 1, 1, 0.20))
	if kind == SOUTH and size > 0.35:  # the gown pulled tight across it
		ci.draw_arc(at * u, radius.x * 0.82 * u, PI * 0.15, PI * 0.85, 8, top.darkened(0.22), maxf(1.0, 0.9 * u))


## A linen apron over the front of the clothes, tied behind.
static func _apron(ci: CanvasItem, u: float, kind: int, sx: float, center: Vector2, radius: Vector2) -> void:
	if kind == NORTH:  # only the strings show, with a bow
		ci.draw_line((center + Vector2(-radius.x + 1.5, 4.6)) * u, (center + Vector2(radius.x - 1.5, 4.6)) * u, LINEN, maxf(1.0, 1.2 * u))
		_ellipse(ci, (center + Vector2(-1.6, 5.2)) * u, Vector2(1.6, 1.1) * u, LINEN)
		_ellipse(ci, (center + Vector2(1.6, 5.2)) * u, Vector2(1.6, 1.1) * u, LINEN)
		return
	var points := PackedVector2Array()
	var left := -6.0 if kind == SOUTH else (0.0 if sx > 0.0 else -radius.x * 0.7)
	var right := 6.0 if kind == SOUTH else (radius.x * 0.7 if sx > 0.0 else 0.0)
	for i in 9:
		var x := lerpf(left, right, i / 8.0)
		points.append(center + Vector2(x, radius.y * sqrt(maxf(0.0, 1.0 - pow(x / radius.x, 2.0))) - 0.6))
	points.append(center + Vector2(right, 3.0))
	points.append(center + Vector2(left, 3.0))
	_polygon_outlined(ci, points, LINEN, u)


## A hood: drawn over the hair, with the face showing through its opening (and a tail hanging
## down the back).
static func _hood(ci: CanvasItem, u: float, kind: int, sx: float, head: Vector2, radius: float, skin: Color, color: Color) -> void:
	var r := radius + 0.7
	var outline := PackedVector2Array()  # a round hood drawn up into a soft point
	var tip_x := -sx * 3.0
	for i in 24:
		var a := TAU * i / 24.0 - PI * 0.5
		var point := head + Vector2(cos(a), sin(a)) * r
		var peak := maxf(0.0, -sin(a))
		point += Vector2(tip_x * peak * peak, -2.8 * pow(peak, 6.0))
		outline.append(point)
	if kind == NORTH:
		var tail := PackedVector2Array([head + Vector2(-2.5, r - 2.0), head + Vector2(2.5, r - 2.0), head + Vector2(0.8, r + 7.0), head + Vector2(-0.8, r + 7.0)])
		_polygon_outlined(ci, tail, color.darkened(0.1), u)
	_polygon_outlined(ci, outline, color, u)
	_ellipse(ci, (head + Vector2(-2.5, -3.5)) * u, Vector2(r * 0.45, r * 0.3) * u, Color(1, 1, 1, 0.12))
	if kind == SOUTH:
		_ellipse(ci, (head + Vector2(0, 1.8)) * u, Vector2(7.3, 7.0) * u, color.darkened(0.40))
		_ellipse(ci, (head + Vector2(0, 2.2)) * u, Vector2(6.6, 6.4) * u, skin)
		ci.draw_arc((head + Vector2(0, 1.8)) * u, 7.3 * u, PI * 1.1, PI * 1.9, 10, color.lightened(0.15), maxf(1.0, u))  # turned-back edge
	elif kind != NORTH:
		_ellipse(ci, (head + Vector2(sx * 4.0, 1.5)) * u, Vector2(5.2, 6.6) * u, color.darkened(0.40))
		_ellipse(ci, (head + Vector2(sx * 4.6, 1.8)) * u, Vector2(4.4, 6.0) * u, skin)


## A linen coif tied under the chin; the gentry wear a gold band over it.
static func _coif(ci: CanvasItem, u: float, kind: int, sx: float, head: Vector2, radius: float, skin: Color, band: bool, hair: Color) -> void:
	var r := radius + 0.3
	_ellipse_outlined(ci, head * u, Vector2(r, r) * u, LINEN, 0.9 * u)
	_ellipse(ci, (head + Vector2(1.6, 2.0)) * u, Vector2(r * 0.8, r * 0.75) * u, Color(0.3, 0.25, 0.15, 0.10))  # the cloth's shading
	_ellipse(ci, (head + Vector2(-2.4, -3.2)) * u, Vector2(r * 0.4, r * 0.28) * u, Color(1, 1, 1, 0.18))
	if kind == NORTH:
		ci.draw_line((head + Vector2(0, -r + 1.0)) * u, (head + Vector2(0, r - 2.5)) * u, LINEN.darkened(0.14), maxf(1.0, 0.9 * u))  # the seam
		_ellipse_outlined(ci, (head + Vector2(0, r - 1.5)) * u, Vector2(2.4, 1.8) * u, LINEN.darkened(0.08), 0.7 * u)  # the knot
	elif kind == SOUTH:
		_ellipse(ci, (head + Vector2(0, 2.4)) * u, Vector2(6.8, 6.4) * u, skin)
		_ellipse(ci, (head + Vector2(0, -2.6)) * u, Vector2(5.0, 1.8) * u, hair)  # hair showing at the brow
		ci.draw_arc((head + Vector2(0, 2.4)) * u, 6.8 * u, PI * 1.05, PI * 1.95, 14, LINEN.darkened(0.22), maxf(1.0, 1.1 * u))
	else:
		_ellipse(ci, (head + Vector2(sx * 4.8, 1.8)) * u, Vector2(4.4, 5.8) * u, skin)
		_ellipse(ci, (head + Vector2(sx * 4.6, -2.8)) * u, Vector2(3.0, 1.6) * u, hair)
	if band:
		if kind == NORTH:
			ci.draw_arc(head * u, (r - 1.5) * u, 0.0, TAU, 20, GOLD, maxf(1.0, 1.3 * u))
		else:
			ci.draw_arc((head + Vector2(sx * 0.8, 1.8)) * u, (r - 0.4) * u, PI * 1.1, PI * 1.9, 12, GOLD, maxf(1.0, 1.4 * u))


## A brimmed hat seen from the front and a little above: the brim as a flat ellipse over the
## brow and the crown above it. Straw for field work; felt with a feather for the gentry.
static func _hat(ci: CanvasItem, u: float, kind: int, sx: float, head: Vector2, brim: Color, crown: Color, band: Color, width: float, feather: bool, feather_color: Color) -> void:
	var brim_center := head + (Vector2(0, -3.5) if kind == NORTH else Vector2(sx * 0.5, -5.5))
	var brim_radius := Vector2(width, 6.0 if kind == NORTH else 4.6)
	var crown_center := brim_center + Vector2(-sx * 0.4, -3.4)
	_ellipse_outlined(ci, brim_center * u, brim_radius * u, brim, 0.9 * u)
	_ellipse(ci, (brim_center + Vector2(-1.5, -1.0)) * u, brim_radius * 0.6 * u, Color(1, 1, 1, 0.10))
	_ellipse_outlined(ci, crown_center * u, Vector2(6.6, 5.0) * u, crown, 0.9 * u)
	ci.draw_arc((crown_center + Vector2(0, 1.2)) * u, 6.2 * u, PI * 0.05, PI * 0.95, 10, band, maxf(1.0, 1.6 * u))
	if feather:
		var base := crown_center + Vector2(-sx * 3.0 + (4.0 if sx == 0.0 else 0.0), -1.0)
		var back := -sx if sx != 0.0 else 1.0
		var plume := PackedVector2Array([base, base + Vector2(back * 4.0, -5.0), base + Vector2(back * 10.0, -6.5), base + Vector2(back * 7.0, -3.0), base + Vector2(back * 2.0, 0.5)])
		_polygon_outlined(ci, plume, feather_color, u)


## A soft felt cap worn tipped to one side, with a little stalk on top.
static func _cap(ci: CanvasItem, u: float, kind: int, sx: float, head: Vector2, color: Color) -> void:
	var center := head + (Vector2(0, -2.5) if kind == NORTH else Vector2(sx * 0.6 + 1.0, -5.0))
	var radius := Vector2(9.8, 8.0) if kind == NORTH else Vector2(9.6, 5.6)
	_ellipse_outlined(ci, center * u, radius * u, color, 0.9 * u)
	_ellipse(ci, (center + Vector2(-2.0, -1.5)) * u, radius * 0.5 * u, Color(1, 1, 1, 0.12))
	if kind != NORTH:
		ci.draw_arc((center + Vector2(0, 0.5)) * u, (radius.x - 0.6) * u, PI * 0.1, PI * 0.9, 10, color.darkened(0.30), maxf(1.0, 1.3 * u))
	_ellipse_outlined(ci, (center + Vector2(0.5, -radius.y + 0.6)) * u, Vector2(1.4, 1.4) * u, color.darkened(0.15), 0.6 * u)


static func _ellipse_points(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points


static func _ellipse(ci: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	ci.draw_colored_polygon(_ellipse_points(center, radius), color)


static func _ellipse_outlined(ci: CanvasItem, center: Vector2, radius: Vector2, color: Color, outline_width: float) -> void:
	ci.draw_colored_polygon(_ellipse_points(center, radius + Vector2(outline_width, outline_width)), OUTLINE)
	ci.draw_colored_polygon(_ellipse_points(center, radius), color)


static func _polygon_outlined(ci: CanvasItem, points: PackedVector2Array, color: Color, u: float) -> void:
	ci.draw_colored_polygon(_scaled(points, u), color)
	var closed := _scaled(points, u)
	closed.append(closed[0])
	ci.draw_polyline(closed, OUTLINE, maxf(1.0, 1.0 * u))


static func _scaled(points: PackedVector2Array, u: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point * u)
	return result
