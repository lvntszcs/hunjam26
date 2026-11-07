class_name PlayerController
extends Node
## Reads one player's input and forwards it, as commands, to their current Role.
##
## The controller does not know what a command does; swap [member role] to make
## the same player play a different side.

signal role_changed(new_role: Role)

@export var model: PlayerModel
@export var input_profile: InputProfile
## The role this player plays. Can be reassigned at runtime.
@export var role: Role:
	set = set_role
## The gamepad device this player uses, or -1 for none (keyboard only).
## Set by Main when a controller connects or presses its first button.
@export var joypad_id: int = -1

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
	role = new_role
	if role:
		role.player = model
	role_changed.emit(role)


func has_joypad() -> bool:
	return joypad_id >= 0


func _unhandled_input(event: InputEvent) -> void:
	if role == null or input_profile == null or event.is_echo():
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.device != joypad_id:
			return
	for command in role.get_commands():
		var action := input_profile.action_for(command)
		if action.is_empty() or not InputMap.has_action(action):
			continue
			
		if event.is_action_pressed(action):
			role.press(command)
		elif event.is_action_released(action):
			role.release(command)
