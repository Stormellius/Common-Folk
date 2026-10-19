class_name PersonRig
extends RefCounted
## Moves a painted person in parts. A person is a stack of pictures of the same size (the body, the hair, each
## garment), and data/rigs.json says where to cut them (tools/make_rigs.py works the cuts out from the body): the
## head, the torso, two arms and two legs. Every layer is cut in the same places and each part is moved the same
## way whatever layer it is of, so any hair or clothes go on any body and move with it.
##
## A layer has a "mode": "full" (cut into all the parts), "skirt" (everything but the legs, with the part below the
## hip swinging as one: a skirt, a dress, a long coat) or "upper" (head and torso only: hair).
##
## The motion is plain numbers (see `motion`), so it can be tested without a screen. Angles turn clockwise when
## positive; the parts of the figure on the left of the picture are `a`, those on the right `b`.

const SEAM := 0.006  # parts overlap by this much of the picture's width, so that no line shows between them
const LAP := 0.028   # and by this much where a part turns or lifts (arms into the torso, legs under it), of its height or width


static func rig_for(set_id: String) -> Dictionary:
	return DataRegistry.get_def("rigs", "rig." + set_id.trim_prefix("people."))


## How far each part is from rest. `phase` is the walk cycle (0 when standing), `act` what they are doing besides
## ("work" with a tool, "busy" with something at hand, "talk", "close" or ""), `clock` the time in seconds, `u` the size of the person in pixels per unit.
static func motion(phase: float, act: String, clock: float, u: float) -> Dictionary:
	var m := { "lift_a": 0.0, "lift_b": 0.0, "leg_a": 0.0, "leg_b": 0.0, "arm_a": 0.0, "arm_b": 0.0,
		"arm_a_y": 0.0, "arm_b_y": 0.0, "arm_a_s": 1.0, "arm_b_s": 1.0, "bob": 0.0, "lean": 0.0, "head": 0.0, "hem": 0.0 }
	if phase != 0.0:  # the walk: a foot lifts and swings forward while the other pushes back, the arms the other way
		var s := sin(phase)
		m["lift_a"] = maxf(0.0, s) * 2.6 * u
		m["lift_b"] = maxf(0.0, -s) * 2.6 * u
		m["leg_a"] = s * 0.12
		m["leg_b"] = -s * 0.12
		m["arm_a"] = s * 0.10
		m["arm_b"] = s * 0.10
		m["arm_a_y"] = -s * 1.6 * u
		m["arm_b_y"] = s * 1.6 * u
		m["bob"] = -absf(s) * 1.1 * u
		m["lean"] = s * 0.022
		m["head"] = -s * 0.018
		m["hem"] = s * 0.05
		return m
	match act:
		"work":  # both arms raised toward the viewer and brought down again with the tool, the body going with them
			var w := sin(clock * 7.0)
			var raise := 0.5 + 0.5 * w
			m["arm_a"] = 0.10 + 0.14 * raise
			m["arm_b"] = -(0.10 + 0.14 * raise)
			m["arm_a_s"] = 1.0 - 0.38 * raise
			m["arm_b_s"] = 1.0 - 0.38 * raise
			m["arm_a_y"] = -1.1 * raise * u
			m["arm_b_y"] = -1.1 * raise * u
			m["bob"] = -absf(w) * 1.0 * u
			m["lean"] = w * 0.025
			m["head"] = -w * 0.02
		"busy":  # hands at work on something: first one forward and then the other, a little
			var b := sin(clock * 4.2)
			m["arm_a_s"] = 1.0 - 0.24 * (0.5 + 0.5 * b)
			m["arm_b_s"] = 1.0 - 0.24 * (0.5 - 0.5 * b)
			m["arm_a_y"] = -0.8 * (0.5 + 0.5 * b) * u
			m["arm_b_y"] = -0.8 * (0.5 - 0.5 * b) * u
			m["arm_a"] = 0.05 * b
			m["arm_b"] = 0.05 * b
			m["bob"] = -absf(b) * 0.35 * u
			m["head"] = sin(clock * 1.3) * 0.015
		"talk":  # a nod, and one hand lifted now and then
			var t := clock * 3.1
			m["head"] = sin(t) * 0.035
			m["bob"] = -maxf(0.0, sin(t * 1.0)) * 0.5 * u
			var gesture := maxf(0.0, sin(clock * 1.7))
			m["arm_b"] = -0.32 * gesture
			m["arm_b_s"] = 1.0 - 0.30 * gesture
			m["arm_b_y"] = -1.4 * gesture * u
		"close":  # swaying a little, close to somebody
			m["lean"] = sin(clock * 1.4) * 0.035
			m["head"] = sin(clock * 1.4 + 1.0) * 0.03
	return m


## Whether a layer of this kind goes in one piece below the hip (a skirt, a dress, a long coat).
static func is_skirt(rig: Dictionary, layer_name: String) -> bool:
	return layer_name in (rig.get("skirts", []) as Array)


## Draws every layer, in order, in parts. `base` puts the figure where it stands (and turns it to face left or
## right); `rect` is where the whole picture goes, unflipped, in the same coordinates.
static func draw(ci: CanvasItem, layers: Array, rig: Dictionary, base: Transform2D, rect: Rect2, m: Dictionary) -> void:
	var neck := float(rig["neck"])
	var shoulder := float(rig["shoulder"])
	var hand := float(rig["hand"])
	var hip := float(rig["hip"])
	var arm_a := float(rig["arm_a"])
	var arm_b := float(rig["arm_b"])
	var mid := float(rig["mid"])
	var w := rect.size.x
	var h := rect.size.y
	var sx := SEAM
	var sy := SEAM * w / maxf(h, 1.0)
	var lx := LAP
	var ly := LAP
	var feet := Vector2(rect.position.x + w * 0.5, rect.end.y)
	var torso := _about(feet, float(m["lean"]), Vector2(0.0, float(m["bob"])))
	var head := torso * _about(Vector2(feet.x, rect.position.y + h * neck), float(m["head"]), Vector2.ZERO)
	var shoulder_a := Vector2(rect.position.x + w * arm_a * 0.85, rect.position.y + h * (shoulder + 0.03))
	var shoulder_b := Vector2(rect.position.x + w * (1.0 - (1.0 - arm_b) * 0.85), shoulder_a.y)
	var arm_xf_a := torso * _about(shoulder_a, float(m["arm_a"]), Vector2(0.0, float(m["arm_a_y"])), float(m["arm_a_s"]))
	var arm_xf_b := torso * _about(shoulder_b, float(m["arm_b"]), Vector2(0.0, float(m["arm_b_y"])), float(m["arm_b_s"]))
	var hip_a := Vector2(rect.position.x + w * mid * 0.5, rect.position.y + h * hip)
	var hip_b := Vector2(rect.position.x + w * (mid + (1.0 - mid) * 0.5), hip_a.y)
	var leg_xf_a := _about(hip_a, float(m["leg_a"]), Vector2(0.0, -float(m["lift_a"])))
	var leg_xf_b := _about(hip_b, float(m["leg_b"]), Vector2(0.0, -float(m["lift_b"])))
	var hem_xf := torso * _about(Vector2(feet.x, rect.position.y + h * hip), float(m["hem"]), Vector2.ZERO)
	for layer: Dictionary in layers:
		var texture: Texture2D = layer["tex"]
		if texture == null:
			continue
		var tint: Color = layer["tint"]
		var mode := str(layer["mode"])
		var put := func(box: Vector4, xf: Transform2D) -> void:
			_part(ci, texture, tint, base * xf, rect, box)
		if mode == "full":
			put.call(Vector4(0.0, hip - ly, mid + sx, 1.0), leg_xf_a)
			put.call(Vector4(mid - sx, hip - ly, 1.0, 1.0), leg_xf_b)
		if mode == "skirt":
			put.call(Vector4(0.0, hip - ly, 1.0, 1.0), hem_xf)
		if mode == "upper":
			put.call(Vector4(0.0, neck - ly, 1.0, hip + ly), torso)
			put.call(Vector4(0.0, 0.0, 1.0, neck + ly), head)
			continue
		put.call(Vector4(0.0, neck - ly, 1.0, shoulder), torso)
		put.call(Vector4(arm_a - lx, shoulder, arm_b + lx, hand), torso)
		put.call(Vector4(0.0, hand, 1.0, hip + ly), torso)
		put.call(Vector4(0.0, 0.0, 1.0, neck + ly), head)
		put.call(Vector4(0.0, shoulder - ly, arm_a + lx, hand + sy), arm_xf_a)
		put.call(Vector4(arm_b - lx, shoulder - ly, 1.0, hand + sy), arm_xf_b)


## Draws the part of a picture inside `box` (fractions of it: x0, y0, x1, y1), moved by `xf`. It is a textured quad
## with the move already in its corners, so whatever transform the caller has set still applies on top.
static func _part(ci: CanvasItem, texture: Texture2D, tint: Color, xf: Transform2D, rect: Rect2, box: Vector4) -> void:
	if box.z <= box.x or box.w <= box.y:
		return
	var left := rect.position.x + box.x * rect.size.x
	var top := rect.position.y + box.y * rect.size.y
	var right := rect.position.x + box.z * rect.size.x
	var bottom := rect.position.y + box.w * rect.size.y
	var corners := PackedVector2Array([xf * Vector2(left, top), xf * Vector2(right, top), xf * Vector2(right, bottom), xf * Vector2(left, bottom)])
	var uvs := PackedVector2Array([Vector2(box.x, box.y), Vector2(box.z, box.y), Vector2(box.z, box.w), Vector2(box.x, box.w)])
	ci.draw_polygon(corners, PackedColorArray([tint, tint, tint, tint]), uvs, texture)


## Turning by `angle` about `pivot` (and shortening by `length`, 1 for none), then moving by `offset`.
static func _about(pivot: Vector2, angle: float, offset: Vector2, length: float = 1.0) -> Transform2D:
	var shorten := Transform2D(Vector2(1.0, 0.0), Vector2(0.0, length), Vector2.ZERO)
	return Transform2D(angle, pivot + offset) * shorten * Transform2D(0.0, -pivot)
