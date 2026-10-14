class_name Animal
extends RefCounted
## One animal in the world, as plain data (data/animals.json says what kinds there are). Like a
## Pawn it knows where it stands and where it is walking, and never draws anything: AnimalView does.
## Wild animals graze, run from people and can be hunted; domestic ones belong to a household (the
## player's, or the town's) or to nobody (a stray), and may be led, ridden or fed. See Fauna.

var id := 0
var kind := ""
## Pets and mounts have names; wild animals have none.
var name := ""
var tile := Vector2i.ZERO
var facing := Vector2i(1, 0)
var path: Array[Vector2i] = []
## The step in progress, as for a person.
var step_to := Vector2i.ZERO
var step_ticks_total := 0
var step_ticks_done := 0
## "household" (the player's), "town" or "" (wild, or a stray with nobody).
var owner := ""
var home_lot := ""
var hp := 1
## The person it follows (0 for nobody) and the person riding it.
var leader := 0
var rider := 0
## Until which tick it runs from people; the tick it next thinks; the tick it was last fed and how
## many days it has gone hungry; a wounded animal making for the one who hurt it (0 for none).
var alert_until := 0
var think_at := 0
var fed_day := 0
var hungry_days := 0
var charging := 0
## A look: which of the kind's colours it has (0 up).
var coat := 0


func def() -> Dictionary:
	return DataRegistry.get_def("animals", kind)


func is_wild() -> bool:
	return str(def().get("type", "wild")) == "wild"


func is_pet() -> bool:
	return bool(def().get("pet", false))


func is_moving() -> bool:
	return step_ticks_total > 0


func display_name() -> String:
	return name if name != "" else str(def().get("name", kind))


## "Biscuit the dog", or just "the deer".
func title() -> String:
	var species := str(def().get("name", kind)).to_lower()
	return "%s the %s" % [name, species] if name != "" else "the %s" % species


## 0 to 1 progress through the step in progress.
func step_progress() -> float:
	if step_ticks_total <= 0:
		return 0.0
	return float(step_ticks_done) / float(step_ticks_total)


func committed_tile() -> Vector2i:
	return step_to if is_moving() else tile


## One motion tick: the animal takes its steps like a person does, at its own pace.
func tick(world: WorldState) -> void:
	if step_ticks_total == 0:
		if path.is_empty():
			return
		var next: Vector2i = path[0]
		if not world.is_walkable(next.x, next.y):
			path.clear()  # the world changed under it
			return
		path.remove_at(0)
		var cost := float(def().get("move_ticks", 2.4))
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
		"id": id, "kind": kind, "name": name, "tile": [tile.x, tile.y], "facing": [facing.x, facing.y],
		"path": saved_path, "step_to": [step_to.x, step_to.y], "step_total": step_ticks_total, "step_done": step_ticks_done,
		"owner": owner, "home_lot": home_lot, "hp": hp, "leader": leader, "rider": rider,
		"alert_until": alert_until, "think_at": think_at, "fed_day": fed_day, "hungry_days": hungry_days,
		"charging": charging, "coat": coat,
	}


static func from_dict(data: Dictionary) -> Animal:
	var animal := Animal.new()
	animal.id = int(data.get("id", 0))
	animal.kind = str(data.get("kind", ""))
	animal.name = str(data.get("name", ""))
	animal.tile = _vec(data.get("tile", [0, 0]))
	animal.facing = _vec(data.get("facing", [1, 0]))
	for cell in data.get("path", []):
		animal.path.append(_vec(cell))
	animal.step_to = _vec(data.get("step_to", [0, 0]))
	animal.step_ticks_total = int(data.get("step_total", 0))
	animal.step_ticks_done = int(data.get("step_done", 0))
	animal.owner = str(data.get("owner", ""))
	animal.home_lot = str(data.get("home_lot", ""))
	animal.hp = int(data.get("hp", 1))
	animal.leader = int(data.get("leader", 0))
	animal.rider = int(data.get("rider", 0))
	animal.alert_until = int(data.get("alert_until", 0))
	animal.think_at = int(data.get("think_at", 0))
	animal.fed_day = int(data.get("fed_day", 0))
	animal.hungry_days = int(data.get("hungry_days", 0))
	animal.charging = int(data.get("charging", 0))
	animal.coat = int(data.get("coat", 0))
	return animal


static func _vec(value: Variant) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1])) if value is Array and value.size() >= 2 else Vector2i.ZERO
