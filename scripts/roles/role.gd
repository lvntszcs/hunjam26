@abstract
class_name Role
extends Node
## One side of the encounter at the door (e.g. inside or outside).
##
## A PlayerController drives whichever Role it holds. Roles can be handed
## between players at runtime, so a role must never assume who plays it.

## The player currently playing this role, or null if nobody holds it.
var player: PlayerModel


## The commands this role reacts to. An InputProfile maps them to actions.
@abstract func get_commands() -> Array[StringName]


## Called when the action bound to [param command] is pressed (no echoes).
func press(_command: StringName) -> void:
	pass


## Called when the action bound to [param command] is released.
func release(_command: StringName) -> void:
	pass
