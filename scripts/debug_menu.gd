extends CanvasLayer

var _doorway: Doorway
var _outside_role: OutsideRole
var _players: Array[PlayerController]

@onready var _status: Label = %Status
@onready var _resume_button: Button = %Resume
@onready var _knock_button: Button = %TestKnock


func setup(doorway: Doorway, outside_role: OutsideRole, players: Array[PlayerController]) -> void:
	_doorway = doorway
	_outside_role = outside_role
	_players = players


func _input(event: InputEvent) -> void:
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
	var lines := PackedStringArray([
		"Ajtó: %s" % ("nyitva" if _doorway.is_open else "zárva"),
		"Kopogás: %s" % ("aktív" if _outside_role.is_knocking() else "inaktív"),
	])
	for controller in _players:
		var model := controller.model
		var role_name := "kint" if controller.role == _outside_role else "bent"
		var joypad := str(controller.joypad_id) if controller.has_joypad() else "nincs"
		lines.append("%s (%s)  ·  Élet %d/%d  ·  Kontroller %s" % [
			model.display_name, role_name, model.health, model.max_health, joypad,
		])
	_status.text = "\n".join(lines)
	_knock_button.disabled = _doorway.is_open
	# A held knock may be released while gameplay input is paused.
	_outside_role.release(OutsideRole.KNOCK)
	get_tree().paused = true
	show()
	_resume_button.grab_focus()


func _resume() -> void:
	hide()
	get_tree().paused = false


func _test_knock() -> void:
	_resume()
	_outside_role.press(OutsideRole.KNOCK)
	_outside_role.release(OutsideRole.KNOCK)


func _restart() -> void:
	_resume()
	get_tree().reload_current_scene()
