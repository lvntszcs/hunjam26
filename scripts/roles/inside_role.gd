class_name InsideRole
extends Role
## The player inside the flat: looks through the peephole and opens the door.

## Granny got to the peephole and looks through it.
signal peeked

enum State { FAR, MOVING, PEEKING, AT_KNOB, OPEN, GRABBING_KNOB, RELEASING_KNOB }

const APPROACH := &"approach"
const APPROACH_DOORKNOB := &"approach_doorknob"
const STEP_BACK := &"step_back"
const OPEN_DOOR := &"open_door"
## Held to look through the peephole (left stick up): stepping up on the push,
## back on the let-go.
const PEEK_HOLD := &"peek_hold"
const COMMANDS: Array[StringName] = [APPROACH, PEEK_HOLD, APPROACH_DOORKNOB, STEP_BACK, OPEN_DOOR]

## Ki lehet-e nyitni az ajtót a szoba közepéről (messziről).
@export var can_open_from_far := true
## Ki lehet-e nyitni az ajtót kukucskálás közben (azonnal, hátralépés nélkül).
@export var can_open_from_peephole := true
@export var doorway: Doorway

var state := State.FAR
var _trigger_held := false
var _release_after_grab := false
var _open_after_grab := false
## The peek was let go while still walking up: step back once there.
var _leave_after_peek := false
var _walking_to_peephole := false
## True while a modifier plays out (the muffin): Granny's own input is ignored.
var _locked := false


func get_commands() -> Array[StringName]:
	return COMMANDS


func set_trigger_held(held: bool) -> void:
	_trigger_held = held
	if _locked:
		return
	if held:
		_release_after_grab = false
		if state == State.FAR:
			_enter_doorknob()
		elif state == State.PEEKING:
			_exit_peephole()
	elif state == State.GRABBING_KNOB:
		_release_after_grab = true
	elif state == State.AT_KNOB:
		_exit_doorknob()


func press(command: StringName) -> void:
	if _locked:
		return
	if state == State.GRABBING_KNOB:
		if _trigger_held and command == OPEN_DOOR:
			_open_after_grab = true
		return
	if state == State.MOVING or state == State.RELEASING_KNOB or state == State.OPEN:
		return  # animáció / nyitott ajtó közben nem reagálunk
	match command:
		OPEN_DOOR:
			if _can_open_door():
				_open_door()
		APPROACH, PEEK_HOLD:
			if state == State.FAR:
				_leave_after_peek = false
				_enter_peephole()
		STEP_BACK:
			if state == State.PEEKING:
				_exit_peephole()
			elif state == State.AT_KNOB and not _trigger_held:
				_exit_doorknob()
		APPROACH_DOORKNOB:
			if state == State.FAR:
				_enter_doorknob()


## True if Granny stands still where she can open the door right now (in the
## room or holding the handle), not walking or looking through the peephole.
func can_open_now() -> bool:
	return state == State.FAR or state == State.AT_KNOB


## Ignores Granny's own input while on (see [method open_now]).
func set_locked(on: bool) -> void:
	_locked = on


## Opens the door for her (the muffin), if she can right now.
func open_now() -> bool:
	if not can_open_now():
		return false
	_open_door()
	return true


func _can_open_door() -> bool:
	return (state == State.FAR and can_open_from_far) \
			or (state == State.PEEKING and can_open_from_peephole) \
			or state == State.AT_KNOB


func _enter_doorknob() -> void:
	state = State.GRABBING_KNOB
	await doorway.approach_doorknob()
	state = State.AT_KNOB
	var release_after_grab := _release_after_grab
	_release_after_grab = false
	if _open_after_grab:
		_open_after_grab = false
		_open_door()
	elif release_after_grab:
		_exit_doorknob()


func _exit_doorknob() -> void:
	state = State.RELEASING_KNOB
	await doorway.leave_doorknob()
	_return_to_far()


func _enter_peephole() -> void:
	state = State.MOVING
	_walking_to_peephole = true
	await doorway.approach_peephole()
	_walking_to_peephole = false
	state = State.PEEKING
	peeked.emit()
	if _trigger_held or _leave_after_peek:
		_leave_after_peek = false
		_exit_peephole()


## Letting go of the peek (left stick back): step back from the peephole, or
## right after getting there if still walking up.
func release(command: StringName) -> void:
	if _locked or command != PEEK_HOLD:
		return
	if state == State.PEEKING:
		_exit_peephole()
	elif _walking_to_peephole:
		_leave_after_peek = true


func _exit_peephole() -> void:
	state = State.MOVING
	await doorway.leave_peephole()
	_return_to_far()


func _open_door() -> void:
	var from_knob := state == State.AT_KNOB  # kéz már a kilincsen: csak lehúzza
	state = State.MOVING
	await doorway.open(from_knob)
	state = State.OPEN
	await doorway.closed  # az ajtó magától csukódik be
	_return_to_far()


func _return_to_far() -> void:
	state = State.FAR
	if _trigger_held:
		_enter_doorknob()


func reset_state() -> void:
	_trigger_held = false
	_locked = false
	_leave_after_peek = false
	_walking_to_peephole = false
	_release_after_grab = false
	_open_after_grab = false
