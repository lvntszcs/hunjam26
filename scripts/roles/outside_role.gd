class_name OutsideRole
extends Role
## The player outside the door: knocks and places pranks.

enum Phase { IDLE, KNOCKING }

const KNOCK := &"knock"
const KNOCK_AT_DOOR := &"knock_at_door"
const PLACE_PRANK := &"place_prank"
const DISGUISE := &"disguise"
## PLACE_PRANK and DISGUISE are not commands any more: the knocking machine
## and the bush are modifier cards (AutoKnockerModifier, BushModifier).
const COMMANDS: Array[StringName] = [KNOCK, KNOCK_AT_DOOR]

## Knocking state-ben töltött idő kopogás után (másodperc).
@export var release_delay := 1.5
@export var doorway: Doorway
## The figure outside the door: slides in while knocking.
@export var knocker: Knocker

var phase := Phase.IDLE
var _knock_held := false
var _trigger_held := false

@onready var _release_timer: Timer = $ReleaseTimer
@onready var _knock_player: KnockPlayer = $KnockPlayer


func _ready() -> void:
	_release_timer.one_shot = true
	_release_timer.timeout.connect(_on_release_timer_timeout)
	_knock_player.knocked.connect(_on_knocked)
	set_process(false)


## While KNOCK is held but the knocker is still walking up: knocks as soon as
## it stands at the door.
func _process(_delta: float) -> void:
	if not _knock_held or doorway.is_open:
		set_process(false)
	elif is_at_door():
		set_process(false)
		_start_knocking()


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


func set_trigger_held(held: bool) -> void:
	_trigger_held = held
	if held:
		if knocker and not doorway.is_open:
			knocker.slide_in()
	elif not _knock_held:
		_stop_knocking()
		if knocker:
			knocker.slide_out(knocker.slide_in_duration)


func press(command: StringName) -> void:
	match command:
		KNOCK:
			if doorway.is_open:
				return
			_knock_held = true
			_release_timer.stop()
			if knocker:
				knocker.set_disguised(false)  # knocking again drops the disguise
				knocker.slide_in()
			# Every press knocks once more, also during the knocking phase
			# (e.g. walking away, then back). Only a knocker standing at the
			# door can knock; until it gets there, _process waits (no sound,
			# no knocking phase).
			if is_at_door():
				_start_knocking()
			else:
				set_process(true)
		KNOCK_AT_DOOR:
			if not doorway.is_open and _trigger_held and is_at_door():
				_start_knocking()
				if not _knock_held:
					_release_timer.start(release_delay)
		PLACE_PRANK:
			if not doorway.is_open:
				doorway.place_prank()  # placeholder csali: csak a nyitott ajtón át látszik
		DISGUISE:
			disguise()


func release(command: StringName) -> void:
	if command == KNOCK and _knock_held:
		_knock_held = false
		if phase == Phase.KNOCKING:
			_release_timer.start(release_delay)
			# Gone exactly when the knocking phase ends: while it is still
			# visible, opening the door catches it.
			if knocker and not _trigger_held:
				knocker.slide_out(release_delay)
		elif knocker and not _trigger_held:
			knocker.slide_out()  # let go before reaching the door: never knocked


func _on_release_timer_timeout() -> void:
	if not _knock_held:
		_stop_knocking()


func _start_knocking() -> void:
	phase = Phase.KNOCKING
	if knocker:
		knocker.set_knocking(true)
	_knock_player.play_random_pattern()
	print("Outer-KNOCKING")


func _stop_knocking() -> void:
	_release_timer.stop()
	if phase == Phase.KNOCKING:
		phase = Phase.IDLE
		_knock_player.stop()  # no knocking heard once the knocker is idle
		if knocker:
			knocker.set_knocking(false)
		print("Outer-IDLE")


## Every hit of the rhythm: the knocker's knuckles on the door.
func _on_knocked(_hit_index: int) -> void:
	if knocker:
		knocker.knock_hit()


## The knocker standing at the door vanishes at once and the disguise (tuja)
## plays in its place until the door has closed again; it works from far
## away too. False if it can't now (the door is open, or already disguised).
func disguise() -> bool:
	if knocker == null or doorway.is_open or knocker.disguised or knocker.is_frozen():
		return false
	knocker.set_disguised(true)
	return knocker.disguised


## The muffin's smell: a knocker anywhere in the corridor (not disguised)
## stops knocking and stands still, hooked, until [method draw_in]. False if
## he is out of range.
func lure() -> bool:
	if knocker == null or knocker.disguised or knocker.is_frozen() or not knocker.is_present():
		return false
	_release_timer.stop()
	_stop_knocking()
	knocker.hold_still()
	return true


## The hooked knocker walks up in front of the open door in [param duration]
## seconds.
func draw_in(duration: float) -> void:
	if knocker:
		knocker.pull_in(duration)


## True when the knocker stands right behind the door (fully slid in, not
## disguised): only then can it knock.
func is_at_door() -> bool:
	return knocker == null or (not knocker.disguised and knocker.presence >= 1.0)


## True if any of the knocker shows in the doorway right now.
func is_in_doorway() -> bool:
	return knocker != null and knocker.is_in_doorway()


## Caught in the doorway: the knocker stops where it is and the knocking
## phase holds until [method let_go].
func freeze() -> void:
	_release_timer.paused = true
	if knocker:
		knocker.freeze()


## The door has closed again: carry on from where the knocker was frozen.
func let_go() -> void:
	_release_timer.paused = false
	if knocker:
		knocker.set_disguised(false)  # the inside player is back in the room
	if knocker == null or (not knocker.is_frozen() and not _trigger_held):
		return
	knocker.unfreeze()
	if _trigger_held or _knock_held:
		knocker.slide_in()
		if _knock_held and phase != Phase.KNOCKING:
			set_process(true)  # still held: knocks once back at the door
	elif not _release_timer.is_stopped():
		knocker.slide_out(_release_timer.time_left / maxf(knocker.presence, 0.01))
	else:
		knocker.slide_out(release_delay)


func reset_state() -> void:
	set_process(false)
	_knock_held = false
	_trigger_held = false
	_release_timer.paused = false
	_release_timer.stop()
	_knock_player.stop()
	if knocker:
		knocker.hide_now()
		knocker.set_disguised(false)
	phase = Phase.IDLE
