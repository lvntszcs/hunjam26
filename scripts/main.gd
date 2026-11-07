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
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


## A button press on a gamepad nobody owns gives it to the next free player.
## Browsers only reveal a gamepad after its first button press, so on the web
## this is how controllers join; the joining press itself is swallowed.
## (_input runs before any PlayerController's _unhandled_input.)
func _input(event: InputEvent) -> void:
	var button := event as InputEventJoypadButton
	if button == null or not button.pressed or _joypad_owner(button.device):
		return
	if _claim_joypad(button.device):
		get_viewport().set_input_as_handled()


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


## Hands out the gamepads already connected at startup (desktop builds).
func _assign_joypads() -> void:
	for device in Input.get_connected_joypads():
		_claim_joypad(device)


## Gives [param device] to the first player without a gamepad.
## Returns false if every player already has one.
func _claim_joypad(device: int) -> bool:
	for controller in players:
		if not controller.has_joypad():
			controller.joypad_id = device
			print("%s: controller %d" % [controller.model.display_name, device])
			return true
	return false


func _joypad_owner(device: int) -> PlayerController:
	for controller in players:
		if controller.joypad_id == device:
			return controller
	return null


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var holder := _joypad_owner(device)
	if connected:
		if holder == null:
			_claim_joypad(device)
	elif holder:
		holder.joypad_id = -1  # free the slot for the next controller
