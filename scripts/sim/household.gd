class_name Household
extends RefCounted
## The people the player looks after. The player controls one of them at a time (the
## selected one) and can switch; the others keep following whatever orders they have.

var pawns: Array[Pawn] = []
var selected_id := -1
## Everyone who died, in order: { "name", "cause", "day" }.
var dead: Array[Dictionary] = []
## The household's shared purse, in coins (see Economy). The town's people each carry their own.
var coins := 0
var _next_id := 1


## `first_id` is where numbering starts: the player's household uses 1, the town 1000 and up.
func _init(first_id: int = 1) -> void:
	_next_id = first_id


func add_pawn(pawn: Pawn) -> void:
	pawn.id = _next_id
	_next_id += 1
	pawns.append(pawn)
	if selected_id == -1 and not pawn.is_infant():
		selected_id = pawn.id


## Takes in someone who already has an id and a history (a partner moving in), without renumbering them.
func adopt(pawn: Pawn) -> void:
	pawns.append(pawn)
	if selected_id == -1 and not pawn.is_infant():
		selected_id = pawn.id


func get_pawn(id: int) -> Pawn:
	for pawn in pawns:
		if pawn.id == id:
			return pawn
	return null


func selected() -> Pawn:
	return get_pawn(selected_id)


## Takes a person out of the household (they died). If they were the one being controlled,
## control passes to the next person in the list. Returns the new selected person, or null if
## nobody is left.
func remove_pawn(id: int) -> Pawn:
	var index := -1
	for i in pawns.size():
		if pawns[i].id == id:
			index = i
	if index == -1:
		return selected()
	pawns.remove_at(index)
	if pawns.is_empty():
		selected_id = -1
	elif selected_id == id:
		selected_id = -1
		for offset in pawns.size():
			var next := pawns[(index + offset) % pawns.size()]
			if not next.is_infant():
				selected_id = next.id
				break
	return selected()


## Returns false if there is no such pawn.
func select(id: int) -> bool:
	var chosen := get_pawn(id)
	if chosen == null or chosen.is_infant():
		return false  # babies are carried, not controlled
	selected_id = id
	return true


## The people the player can control: everyone but the babies.
func playable() -> Array[Pawn]:
	var found: Array[Pawn] = []
	for pawn in pawns:
		if not pawn.is_infant():
			found.append(pawn)
	return found


## Selects the next (or with a negative step, previous) household member.
func cycle_selection(step: int = 1) -> void:
	if pawns.is_empty():
		return
	var index := 0
	for i in pawns.size():
		if pawns[i].id == selected_id:
			index = i
			break
	for attempt in pawns.size():
		index = posmod(index + step, pawns.size())
		if not pawns[index].is_infant():
			selected_id = pawns[index].id
			return


# --- saving --------------------------------------------------------------------

func to_dict() -> Dictionary:
	var saved_pawns: Array = []
	for pawn in pawns:
		saved_pawns.append(pawn.to_dict())
	return { "pawns": saved_pawns, "selected": selected_id, "next_id": _next_id, "dead": dead.duplicate(true), "coins": coins }


static func from_dict(data: Dictionary, first_id: int = 1) -> Household:
	var household := Household.new(first_id)
	for saved in data.get("pawns", []):
		if saved is Dictionary:
			household.pawns.append(Pawn.from_dict(saved))
	for entry in data.get("dead", []):
		if entry is Dictionary:
			household.dead.append({ "name": str(entry.get("name", "")), "cause": str(entry.get("cause", "")), "day": int(entry.get("day", 0)) })
	household.coins = int(data.get("coins", Economy.start_coins()))  # an older save gets a starting purse
	household._next_id = int(data.get("next_id", first_id + household.pawns.size()))
	household.selected_id = int(data.get("selected", -1))
	var chosen := household.get_pawn(household.selected_id)
	if chosen == null or chosen.is_infant():
		var playable := household.playable()
		household.selected_id = playable[0].id if not playable.is_empty() else -1
	return household
