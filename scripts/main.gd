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
## Szerepcsere után ennyi másodpercig nem fogadunk inputot.
@export var swap_wait := 2.0

## Set when the knocker runs out of health; the swap waits until the door closes.
var _swap_pending := false


func _ready() -> void:
	doorway.opening.connect(_on_doorway_opening)
	doorway.closed.connect(_on_doorway_closed)
	for controller in players:
		if controller.model:
			controller.model.defeated.connect(_on_player_defeated)
	_assign_joypads()


## Swaps the roles of the first two players. Meant to be called between
## rounds, while nobody is mid-action.
func swap_roles() -> void:
	assert(players.size() >= 2, "swap_roles() needs two players")
	var first_role := players[0].role
	players[0].role = players[1].role
	players[1].role = first_role
	for controller in players:
		if controller.role:
			controller.role.reset_state()
	# Only the knocker has health, so the new one starts from full.
	if outside_role.player:
		outside_role.player.reset()
	print("swap")


func _on_player_defeated() -> void:
	_swap_pending = true


func _on_doorway_closed() -> void:
	if _swap_pending:
		_swap_pending = false
		swap_roles()
		await _block_input(swap_wait)


## Ignores every player's input for [param seconds].
func _block_input(seconds: float) -> void:
	for controller in players:
		controller.set_process_unhandled_input(false)
	await get_tree().create_timer(seconds).timeout
	for controller in players:
		controller.set_process_unhandled_input(true)


func _on_doorway_opening() -> void:
	if outside_role.is_knocking():
		if outside_role.player:
			outside_role.player.take_damage(1)
		print("Elkapva")
	else:
		print("Pranked")

func _assign_joypads() -> void:
	var joypads := Input.get_connected_joypads()

	for i in range(mini(joypads.size(),players.size())):
		players[i].joypad_id = joypads[i]
