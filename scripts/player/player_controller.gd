class_name PlayerController
extends Node
## Reads one player's input and forwards it, as commands, to their current Role.
##
## The controller does not know what a command does; swap [member role] to make
## the same player play a different side.

signal role_changed(new_role: Role)

const TRIGGER_PRESS_THRESHOLD := 0.25
const TRIGGER_RELEASE_THRESHOLD := 0.15

@export var model: PlayerModel
@export var input_profile: InputProfile
## The role this player plays. Can be reassigned at runtime.
@export var role: Role:
	set = set_role
## The gamepad device this player uses, or -1 for none (keyboard only).
## Set by Main when a controller connects or presses its first button.
@export var joypad_id: int = -1

var _trigger_held := false


func _ready() -> void:
	if model:
		model.reset()
	if role:
		role.player = model


func set_role(new_role: Role) -> void:
	if role == new_role:
		return
	if role and role.player == model:
		role.player = null
	_trigger_held = false
	role = new_role
	if role:
		role.player = model
	role_changed.emit(role)


func has_joypad() -> bool:
	return joypad_id >= 0


func _process(_delta: float) -> void:
	if is_processing_unhandled_input():
		_update_trigger_hold()


func _update_trigger_hold() -> void:
	if role == null:
		return
	var pull := 0.0
	if has_joypad():
		pull = maxf(
			Input.get_joy_axis(joypad_id, JOY_AXIS_TRIGGER_LEFT),
			Input.get_joy_axis(joypad_id, JOY_AXIS_TRIGGER_RIGHT))
	var threshold := TRIGGER_RELEASE_THRESHOLD if _trigger_held else TRIGGER_PRESS_THRESHOLD
	var held := pull >= threshold
	if held != _trigger_held:
		_trigger_held = held
		role.set_trigger_held(held)


func _unhandled_input(event: InputEvent) -> void:
	if role == null or input_profile == null or event.is_echo():
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.device != joypad_id:
			return
		if event is InputEventJoypadButton:
			_update_trigger_hold()
	for command in role.get_commands():
		var action := input_profile.action_for(command)
		if action.is_empty() or not InputMap.has_action(action):
			continue

		if event.is_action_pressed(action):
			role.press(command)
		elif event.is_action_released(action):
			role.release(command)
