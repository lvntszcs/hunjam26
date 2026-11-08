class_name InputProfile
extends Resource
## Maps role commands to InputMap actions for one player.
##
## Roles only know abstract commands (e.g. &"knock"); the profile decides which
## input action triggers them. Give each player their own profile (other keys,
## a gamepad, ...) and any role can be played with any profile.

## Command name -> InputMap action name.
@export var bindings: Dictionary[StringName, StringName] = {
	&"approach": &"approach",
	&"peek_hold": &"peek_hold",
	&"approach_doorknob": &"approach_doorknob",
	&"step_back": &"step_back",
	&"open_door": &"open_door",
	&"knock": &"knock",
	&"knock_at_door": &"knock_at_door",
	&"place_prank": &"place_prank",
	&"disguise": &"disguise",
	&"use_modifier": &"use_modifier",
}


## The InputMap action bound to [param command], or an empty StringName.
func action_for(command: StringName) -> StringName:
	return bindings.get(command, &"")
