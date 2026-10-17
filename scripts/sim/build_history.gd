class_name BuildHistory
extends RefCounted
## The player's building, remembered for Ctrl+Z. A step is one click, or one click-and-drag, and is a list of
## what that did (see BuildEditor for the kinds of operation). It lives only as long as the game is open.

const LIMIT := 80

## Steps that can be undone, the latest last; and steps that were undone and can be done again.
var done: Array[Array] = []
var undone: Array[Array] = []

## Set while undoing and redoing, which are not steps of their own.
var paused := false

var _open: Array[Dictionary] = []
var _stroking := false


## A click or a drag starts: everything done until `end` is one step.
func begin() -> void:
	end()
	_stroking = true


func end() -> void:
	_stroking = false
	if not _open.is_empty():
		_push(_open)
		_open = []


## Remembers one thing that was done. Outside a click or drag it is a step of its own.
func add(operation: Dictionary) -> void:
	if paused:
		return
	_open.append(operation)
	if not _stroking:
		end()


func _push(step: Array[Dictionary]) -> void:
	done.append(step)
	undone.clear()  # a new change closes off whatever could have been done again
	if done.size() > LIMIT:
		done.pop_front()


func can_undo() -> bool:
	return not done.is_empty()


func can_redo() -> bool:
	return not undone.is_empty()


func clear() -> void:
	done.clear()
	undone.clear()
	_open = []
	_stroking = false
