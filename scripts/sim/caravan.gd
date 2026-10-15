class_name Caravan
extends RefCounted
## One trading caravan (data/caravans.json): an ox cart with two drivers that travels the roads
## from town to town, camps on the market square for a couple of days, buys and sells there, and
## takes passengers who pay a fare. Like an animal it knows where it is and where it is going, and
## never draws anything; CaravanView does.

var id := 0
var name := ""
var tile := Vector2i.ZERO
var facing := Vector2i(1, 0)
var path: Array[Vector2i] = []
var step_to := Vector2i.ZERO
var step_ticks_total := 0
var step_ticks_done := 0
## "travelling" or "camped"; the town it is in (camped) or has come from and is heading for, and the
## one it will go to next; the tile it is making for.
var state := "travelling"
var at_town := ""
var from_town := ""
var to_town := ""
var next_town := ""
var goal := Vector2i.ZERO
## When it arrived and when it leaves.
var arrived_tick := 0
var leaves_tick := 0
## What it has to sell (good id -> how many), how much more of each it will buy, and the goods it pays
## most for.
var stock: Dictionary = {}
var demand: Dictionary = {}
var wants: Array[String] = []
## The people riding (ids), the two drivers' looks (as for a person), and the ox's coat.
var passengers: Array[int] = []
var looks: Array[Dictionary] = []
var coat := 0


func is_moving() -> bool:
	return step_ticks_total > 0


func step_progress() -> float:
	if step_ticks_total <= 0:
		return 0.0
	return float(step_ticks_done) / float(step_ticks_total)


## One motion tick along the road.
func tick(world: WorldState) -> void:
	if step_ticks_total == 0:
		if path.is_empty():
			return
		var next: Vector2i = path[0]
		if not world.is_walkable(next.x, next.y):
			path.clear()  # something was built in the way: the system works out another way
			return
		path.remove_at(0)
		var cost := float(DataRegistry.get_def("caravans", "caravan").get("move_ticks", 2.2))
		if next.x != tile.x and next.y != tile.y:
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


func to_dict() -> Dictionary:
	var saved_path: Array = []
	for cell in path:
		saved_path.append([cell.x, cell.y])
	return {
		"id": id, "name": name, "tile": [tile.x, tile.y], "facing": [facing.x, facing.y], "path": saved_path,
		"step_to": [step_to.x, step_to.y], "step_total": step_ticks_total, "step_done": step_ticks_done,
		"state": state, "at_town": at_town, "from_town": from_town, "to_town": to_town, "next_town": next_town,
		"goal": [goal.x, goal.y], "arrived": arrived_tick, "leaves": leaves_tick,
		"stock": stock.duplicate(), "demand": demand.duplicate(), "wants": Array(wants),
		"passengers": Array(passengers), "looks": looks.duplicate(true), "coat": coat,
	}


static func from_dict(data: Dictionary) -> Caravan:
	var caravan := Caravan.new()
	caravan.id = int(data.get("id", 0))
	caravan.name = str(data.get("name", "A caravan"))
	caravan.tile = _vec(data.get("tile", [0, 0]))
	caravan.facing = _vec(data.get("facing", [1, 0]))
	for cell in data.get("path", []):
		caravan.path.append(_vec(cell))
	caravan.step_to = _vec(data.get("step_to", [0, 0]))
	caravan.step_ticks_total = int(data.get("step_total", 0))
	caravan.step_ticks_done = int(data.get("step_done", 0))
	caravan.state = str(data.get("state", "travelling"))
	caravan.at_town = str(data.get("at_town", ""))
	caravan.from_town = str(data.get("from_town", ""))
	caravan.to_town = str(data.get("to_town", ""))
	caravan.next_town = str(data.get("next_town", ""))
	caravan.goal = _vec(data.get("goal", [0, 0]))
	caravan.arrived_tick = int(data.get("arrived", 0))
	caravan.leaves_tick = int(data.get("leaves", 0))
	for key in ["stock", "demand"]:
		var saved: Variant = data.get(key, {})
		if saved is Dictionary:
			for good in saved:
				(caravan.stock if key == "stock" else caravan.demand)[str(good)] = int(saved[good])
	for good in data.get("wants", []):
		caravan.wants.append(str(good))
	for passenger in data.get("passengers", []):
		caravan.passengers.append(int(passenger))
	for saved_look in data.get("looks", []):
		if saved_look is Dictionary:
			var look: Dictionary = saved_look.duplicate()
			if look.has("hair_style"):
				look["hair_style"] = int(look["hair_style"])
			caravan.looks.append(look)
	caravan.coat = int(data.get("coat", 0))
	return caravan


static func _vec(value: Variant) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1])) if value is Array and value.size() >= 2 else Vector2i.ZERO
