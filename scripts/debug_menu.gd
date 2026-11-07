extends CanvasLayer

var _doorway: Doorway
var _outside_role: OutsideRole
var _players: Array[PlayerController]
var _input_lock_time_left: Callable
var _last_joypad_events: Dictionary[int, String]

@onready var _status: Label = %Status
@onready var _timers: Label = %Timers
@onready var _phase: OptionButton = %Phase
@onready var _release_delay: SpinBox = %ReleaseDelay
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
	_phase.add_item("IDLE", OutsideRole.Phase.IDLE)
	_phase.add_item("KNOCKING", OutsideRole.Phase.KNOCKING)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	if visible and event is InputEventJoypadButton:
		var action := "lenyomva" if event.pressed else "felengedve"
		_last_joypad_events[event.device] = "Gomb %d · %s" % [event.button_index, action]
		_refresh_status()

	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3 or (visible and key.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		if visible:
			_resume()
		else:
			_open()


func _open() -> void:
	# A held knock may be released while gameplay input is paused.
	_outside_role.release(OutsideRole.KNOCK)
	get_tree().paused = true
	_release_delay.set_value_no_signal(_outside_role.release_delay)
	_refresh_status()
	show()
	_phase.grab_focus()


func _refresh_status() -> void:
	var lines := PackedStringArray([
		"Ajtó: %s" % ("nyitva" if _doorway.is_open else "zárva"),
	])
	for controller in _players:
		var model := controller.model
		var role_name := "kint" if controller.role == _outside_role else "bent"
		var joypad := str(controller.joypad_id) if controller.has_joypad() else "nincs"
		lines.append("%s (%s)  ·  Élet %d/%d  ·  Kontroller %s" % [
			model.display_name, role_name, model.health, model.max_health, joypad,
		])
		lines.append(_last_joypad_events.get(controller.joypad_id, "Még nincs gombesemény"))
	_status.text = "\n".join(lines)

	_phase.select(_phase.get_item_index(_outside_role.phase))
	_knock_button.disabled = _doorway.is_open
	_timers.text = "Hátralévő idő (szünetel)\nKopogás: %s\nAjtócsukás: %s\nInputzár: %s" % [
		_format_timer(_outside_role.release_time_left()),
		_format_timer(_doorway.close_time_left()),
		_format_timer(_input_lock_time_left.call()),
	]


func _format_timer(seconds: float) -> String:
	return "%.2f mp" % seconds if seconds > 0.0 else "—"


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		_last_joypad_events.erase(device)
	if visible:
		_refresh_status()


func _on_phase_selected(index: int) -> void:
	if _phase.get_item_id(index) == OutsideRole.Phase.IDLE:
		_outside_role.reset_state()
	else:
		_activate_knock()
	_refresh_status()


func _on_release_delay_changed(seconds: float) -> void:
	_outside_role.set_release_delay(seconds)
	_refresh_status()


func _resume() -> void:
	hide()
	get_tree().paused = false


func _test_knock() -> void:
	_activate_knock()
	_resume()


func _activate_knock() -> void:
	_outside_role.press(OutsideRole.KNOCK)
	_outside_role.release(OutsideRole.KNOCK)


func _reset_round() -> void:
	_resume()
	get_tree().reload_current_scene()
