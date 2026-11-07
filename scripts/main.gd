extends Control
## Wires players, roles and the doorway together and owns the round rules.
##
## Scene layout:
##   Doorway  - presentation and door state
##   Roles    - InsideRole, OutsideRole (one per side of the door)
##   Players  - PlayerController per player, each holding a PlayerModel and a Role

@export var doorway: Doorway
@export var outside_role: OutsideRole
@export var players: Array[PlayerController] = []


func _ready() -> void:
	doorway.opening.connect(_on_doorway_opening)


## Swaps the roles of the first two players. Meant to be called between
## rounds, while nobody is mid-action.
func swap_roles() -> void:
	assert(players.size() >= 2, "swap_roles() needs two players")
	var first_role := players[0].role
	players[0].role = players[1].role
	players[1].role = first_role


func _on_doorway_opening() -> void:
	if outside_role.is_knocking():
		if outside_role.player:
			outside_role.player.take_damage(1)
		print("Elkapva")
	else:
		print("Pranked")
