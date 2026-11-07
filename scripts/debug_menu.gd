extends CanvasLayer
## Always-visible debug panel docked to the right edge (debug builds only).
## Mouse-only: its controls never take keyboard/gamepad focus, so gameplay
## keys like Space can't trigger them.

const MIN_RELEASE_DELAY := 0.1
const MAX_RELEASE_DELAY := 30.0

var _doorway: Doorway
var _outside_role: OutsideRole
var _players: Array[PlayerController]
var _input_lock_time_left: Callable
var _last_joypad_events: Dictionary[int, String]

@onready var _status: Label = %Status
@onready var _timers: Label = %Timers
@onready var _phase_idle: Button = %PhaseIdle
@onready var _phase_knocking: Button = %PhaseKnocking
@onready var _release_delay: Label = %ReleaseDelay
@onready var _knock_button: Button = %TestKnock


func setup(
	doorway: Doorway,
	outside_role: OutsideRole,
	players: Array[PlayerController],
	input_lock_time_left: Callable,
) -> void:
	_doorway = doorway
	_outside_role = outside_role
	_players = players
	_input_lock_time_left = input_lock_time_left


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _process(_delta: float) -> void:
	_refresh()


func _input(event: InputEvent) -> void:
	var button := event as InputEventJoypadButton
	if button:
		var action := "pressed" if button.pressed else "released"
		_last_joypad_events[button.device] = "Button %d %s" % [button.button_index, action]


func _refresh() -> void:
	var lines := PackedStringArray(["Door: %s" % ("open" if _doorway.is_open else "closed")])
	for controller in _players:
		var model := controller.model
		var side := "outside" if controller.role == _outside_role else "inside"
		var pad := str(controller.joypad_id) if controller.has_joypad() else "none"
		lines.append("%s (%s)  HP %d/%d  Pad %s" % [
			model.display_name, side, model.health, model.max_health, pad,
		])
		lines.append("  " + _last_joypad_events.get(controller.joypad_id, "no button events"))
	_status.text = "\n".join(lines)

	var knocking := _outside_role.is_knocking()
	_phase_idle.set_pressed_no_signal(not knocking)
	_phase_knocking.set_pressed_no_signal(knocking)
	_release_delay.text = "%.1f s" % _outside_role.release_delay
	_knock_button.disabled = _doorway.is_open
	_timers.text = "Knock release  %s\nDoor close  %s\nInput lock  %s" % [
		_format_timer(_outside_role.release_time_left()),
		_format_timer(_doorway.close_time_left()),
		_format_timer(_input_lock_time_left.call()),
	]


func _format_timer(seconds: float) -> String:
	return "%.2f s" % seconds if seconds > 0.0 else "—"


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		_last_joypad_events.erase(device)


func _on_phase_pressed(phase: OutsideRole.Phase) -> void:
	if phase == OutsideRole.Phase.IDLE:
		_outside_role.reset_state()
	else:
		_activate_knock()


func _change_release_delay(step: float) -> void:
	var seconds := snappedf(_outside_role.release_delay + step, 0.1)
	_outside_role.set_release_delay(clampf(seconds, MIN_RELEASE_DELAY, MAX_RELEASE_DELAY))


func _activate_knock() -> void:
	_outside_role.press(OutsideRole.KNOCK)
	_outside_role.release(OutsideRole.KNOCK)


func _reset_round() -> void:
	get_tree().reload_current_scene()
