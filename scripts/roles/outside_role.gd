class_name OutsideRole
extends Role
## The player outside the door: knocks and places pranks.

enum Phase { IDLE, KNOCKING }

const KNOCK := &"knock"
const PLACE_PRANK := &"place_prank"
const COMMANDS: Array[StringName] = [KNOCK, PLACE_PRANK]

## Knocking state-ben töltött idő kopogás után (másodperc).
@export var release_delay := 1.5
@export var doorway: Doorway
## The figure outside the door: slides in while knocking.
@export var knocker: Knocker

var phase := Phase.IDLE
var _knock_held := false

@onready var _release_timer: Timer = $ReleaseTimer
@onready var _knock_player: KnockPlayer = $KnockPlayer


func _ready() -> void:
	_release_timer.one_shot = true
	_release_timer.timeout.connect(_on_release_timer_timeout)


func get_commands() -> Array[StringName]:
	return COMMANDS


func is_knocking() -> bool:
	return phase == Phase.KNOCKING


func release_time_left() -> float:
	return _release_timer.time_left


func set_release_delay(seconds: float) -> void:
	release_delay = seconds
	if not _release_timer.is_stopped():
		_release_timer.start(release_delay)


func press(command: StringName) -> void:
	match command:
		KNOCK:
			_knock_held = true
			_release_timer.stop()
			if knocker:
				knocker.slide_in()
			if phase != Phase.KNOCKING:
				phase = Phase.KNOCKING
				_knock_player.play_random_pattern()
				print("Outer-KNOCKING")
		PLACE_PRANK:
			if not doorway.is_open:
				doorway.place_prank()  # placeholder csali: csak a nyitott ajtón át látszik


func release(command: StringName) -> void:
	if command == KNOCK and _knock_held:
		_knock_held = false
		if phase == Phase.KNOCKING:
			_release_timer.start(release_delay)
			# Gone exactly when the knocking phase ends: while it is still
			# visible, opening the door catches it.
			if knocker:
				knocker.slide_out(release_delay)


func _on_release_timer_timeout() -> void:
	if phase == Phase.KNOCKING and not _knock_held:
		phase = Phase.IDLE
		_knock_player.stop()  # no knocking heard once the knocker is idle
		print("Outer-IDLE")


func reset_state() -> void:
	_knock_held = false
	_release_timer.stop()
	_knock_player.stop()
	if knocker:
		knocker.hide_now()
	phase = Phase.IDLE
