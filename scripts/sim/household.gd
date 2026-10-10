class_name Household
extends RefCounted
## The people the player looks after. The player controls one of them at a time (the
## selected one) and can switch; the others keep following whatever orders they have.

var pawns: Array[Pawn] = []
var selected_id := -1
var _next_id := 1


func add_pawn(pawn: Pawn) -> void:
	pawn.id = _next_id
	_next_id += 1
	pawns.append(pawn)
	if selected_id == -1:
		selected_id = pawn.id


func get_pawn(id: int) -> Pawn:
	for pawn in pawns:
		if pawn.id == id:
			return pawn
	return null


func selected() -> Pawn:
	return get_pawn(selected_id)


## Returns false if there is no such pawn.
func select(id: int) -> bool:
	if get_pawn(id) == null:
		return false
	selected_id = id
	return true


## Selects the next (or with a negative step, previous) household member.
func cycle_selection(step: int = 1) -> void:
	if pawns.is_empty():
		return
	var index := 0
	for i in pawns.size():
		if pawns[i].id == selected_id:
			index = i
			break
	selected_id = pawns[posmod(index + step, pawns.size())].id


# --- saving --------------------------------------------------------------------

func to_dict() -> Dictionary:
	var saved_pawns: Array = []
	for pawn in pawns:
		saved_pawns.append(pawn.to_dict())
	return { "pawns": saved_pawns, "selected": selected_id, "next_id": _next_id }


static func from_dict(data: Dictionary) -> Household:
	var household := Household.new()
	for saved in data.get("pawns", []):
		if saved is Dictionary:
			household.pawns.append(Pawn.from_dict(saved))
	household._next_id = int(data.get("next_id", household.pawns.size() + 1))
	household.selected_id = int(data.get("selected", -1))
	if household.get_pawn(household.selected_id) == null:
		household.selected_id = household.pawns[0].id if not household.pawns.is_empty() else -1
	return household
