class_name Pawn
extends RefCounted
## One person in the world, as plain data. It knows where it stands and where it is
## walking, but never draws anything: PawnView reads these fields and does the drawing.
##
## A walk is a list of tiles (`path`). One step at a time the pawn commits to the next
## tile, spends a few game ticks crossing it (more in forest, more on diagonals), and
## arrives. Because it only advances on clock ticks, pausing and speed changes just work.

## Game minutes to cross one open tile in a straight line.
const BASE_MOVE_TICKS := 3.0

var id := 0
var display_name := ""
var gender := "female"
## Colors as hex strings plus a hair style number; see PawnArt.
var look: Dictionary = {}

## The tile the pawn stands on (or is leaving, while a step is in progress).
var tile := Vector2i.ZERO
## Direction of the last step. (0, 1) is facing south, toward the camera.
var facing := Vector2i(0, 1)
## Tiles still to walk, not including the step in progress.
var path: Array[Vector2i] = []

## The step in progress: heading to `step_to`, `step_ticks_done` of `step_ticks_total` done.
var step_to := Vector2i.ZERO
var step_ticks_total := 0
var step_ticks_done := 0


func is_moving() -> bool:
	return step_ticks_total > 0


func has_orders() -> bool:
	return is_moving() or not path.is_empty()


## 0 to 1 progress through the step in progress.
func step_progress() -> float:
	if step_ticks_total <= 0:
		return 0.0
	return float(step_ticks_done) / float(step_ticks_total)


## The tile the pawn will be standing on once its current step is finished.
## New orders must start from here, or the pawn would turn around mid-step.
func committed_tile() -> Vector2i:
	return step_to if is_moving() else tile


func goal_tile() -> Vector2i:
	if not path.is_empty():
		return path[path.size() - 1]
	return committed_tile()


func tick(world: WorldState) -> void:
	if step_ticks_total == 0:
		if path.is_empty():
			return
		var next: Vector2i = path[0]
		if not world.is_walkable(next.x, next.y):
			path.clear()  # the world changed under us
			return
		path.remove_at(0)
		var diagonal := next.x != tile.x and next.y != tile.y
		var cost := BASE_MOVE_TICKS * maxf(world.get_move_cost(next.x, next.y), 1.0)
		if diagonal:
			cost *= 1.41421
		step_to = next
		step_ticks_total = maxi(1, roundi(cost))
		step_ticks_done = 0
		facing = next - tile
	step_ticks_done += 1
	if step_ticks_done >= step_ticks_total:
		tile = step_to
		step_ticks_total = 0
		step_ticks_done = 0


# --- saving --------------------------------------------------------------------

func to_dict() -> Dictionary:
	var saved_path: Array = []
	for cell in path:
		saved_path.append(_vec_to_array(cell))
	return {
		"id": id,
		"name": display_name,
		"gender": gender,
		"look": look.duplicate(),
		"tile": _vec_to_array(tile),
		"facing": _vec_to_array(facing),
		"path": saved_path,
		"step_to": _vec_to_array(step_to),
		"step_total": step_ticks_total,
		"step_done": step_ticks_done,
	}


static func from_dict(data: Dictionary) -> Pawn:
	var pawn := Pawn.new()
	pawn.id = int(data.get("id", 0))
	pawn.display_name = str(data.get("name", ""))
	pawn.gender = str(data.get("gender", "female"))
	var saved_look: Variant = data.get("look", {})
	pawn.look = saved_look.duplicate() if saved_look is Dictionary else {}
	if pawn.look.has("hair_style"):
		pawn.look["hair_style"] = int(pawn.look["hair_style"])  # JSON numbers load as floats
	pawn.tile = _array_to_vec(data.get("tile", [0, 0]))
	pawn.facing = _array_to_vec(data.get("facing", [0, 1]))
	for cell in data.get("path", []):
		pawn.path.append(_array_to_vec(cell))
	pawn.step_to = _array_to_vec(data.get("step_to", [0, 0]))
	pawn.step_ticks_total = int(data.get("step_total", 0))
	pawn.step_ticks_done = int(data.get("step_done", 0))
	return pawn


static func _vec_to_array(v: Vector2i) -> Array:
	return [v.x, v.y]


static func _array_to_vec(a: Variant) -> Vector2i:
	if a is Array and a.size() >= 2:
		return Vector2i(int(a[0]), int(a[1]))  # JSON numbers load as floats
	return Vector2i.ZERO
