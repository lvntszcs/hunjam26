class_name InsideRole
extends Role
## The player inside the flat: looks through the peephole and opens the door.

enum State { FAR, MOVING, PEEKING, OPEN }

const APPROACH := &"approach"
const STEP_BACK := &"step_back"
const OPEN_DOOR := &"open_door"
const COMMANDS: Array[StringName] = [APPROACH, STEP_BACK, OPEN_DOOR]

## Ki lehet-e nyitni az ajtót a szoba közepéről (messziről).
@export var can_open_from_far := true
## Ki lehet-e nyitni az ajtót kukucskálás közben (azonnal, hátralépés nélkül).
@export var can_open_from_peephole := true
@export var doorway: Doorway

var state := State.FAR


func get_commands() -> Array[StringName]:
	return COMMANDS


func press(command: StringName) -> void:
	if state == State.MOVING or state == State.OPEN:
		return  # animáció / nyitott ajtó közben nem reagálunk
	match command:
		OPEN_DOOR:
			if _can_open_door():
				_open_door()
		APPROACH:
			if state == State.FAR:
				_enter_peephole()
		STEP_BACK:
			if state == State.PEEKING:
				_exit_peephole()


func _can_open_door() -> bool:
	return (state == State.FAR and can_open_from_far) \
			or (state == State.PEEKING and can_open_from_peephole)


func _enter_peephole() -> void:
	state = State.MOVING
	await doorway.approach_peephole()
	state = State.PEEKING


func _exit_peephole() -> void:
	state = State.MOVING
	await doorway.leave_peephole()
	state = State.FAR


func _open_door() -> void:
	state = State.MOVING
	await doorway.open()
	state = State.OPEN
	await doorway.closed  # az ajtó magától csukódik be
	state = State.FAR
