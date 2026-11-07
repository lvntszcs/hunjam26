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
	&"approach_doorknob": &"approach_doorknob",
	&"step_back": &"step_back",
	&"open_door": &"open_door",
	&"knock": &"knock",
	&"place_prank": &"place_prank",
	&"disguise": &"disguise",
}


## The InputMap action bound to [param command], or an empty StringName.
func action_for(command: StringName) -> StringName:
	return bindings.get(command, &"")
