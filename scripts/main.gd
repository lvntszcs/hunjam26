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
## The start menu. While it is shown the players' game controls are off.
@export var start_page: CanvasLayer
## Clicking it hides [member start_page] and turns the game controls on.
@export var start_button: PixelButton
## Shown after the start page; Enter on it starts the game.
@export var character_chooser: CharacterChooser
## Seconds for each half (cover / reveal) of the dissolve between the boot
## splash, the start page, the character select and the game.
@export var menu_transition_duration := 0.5

## Set when the knocker runs out of health; the swap waits until the door closes.
var _swap_pending := false
var _input_lock_timer: SceneTreeTimer
## True while a menu transition runs; repeated presses are ignored meanwhile.
var _transitioning := false


func _ready() -> void:
	doorway.swung_open.connect(_on_doorway_swung_open)
	doorway.closed.connect(_on_doorway_closed)
	for controller in players:
		if controller.model:
			controller.model.defeated.connect(_on_player_defeated)
	_assign_joypads()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Fall back to the default node names if the exports were left empty.
	if start_page == null:
		start_page = get_node_or_null("StartPage") as CanvasLayer
	if start_button == null and start_page:
		start_button = start_page.get_node_or_null("Start") as PixelButton
	if character_chooser == null:
		character_chooser = get_node_or_null("CharacterChoose") as CharacterChooser
	if character_chooser:
		character_chooser.confirmed.connect(_on_character_confirmed)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	# The menus visible in the editor decide where the game starts:
	# start page -> character choose -> game.
	if start_page and start_page.visible:
		_set_player_input(false)
		if character_chooser:
			character_chooser.close()
	elif character_chooser and character_chooser.visible:
		_set_player_input(false)
		character_chooser.open()
	if OS.is_debug_build():
		var debug_menu := preload("res://scenes/debug_menu.tscn").instantiate()
		debug_menu.setup(doorway, outside_role, players, _input_lock_time_left)
		add_child(debug_menu)
	_play_intro()


## The boot splash's light background dissolves into the first screen.
func _play_intro() -> void:
	_transitioning = true
	doorway.fader.cover_now(_splash_color())
	await doorway.fader.fade_to(0.0, menu_transition_duration)
	_transitioning = false


## The boot splash background (the light colour), so the dissolve starts
## exactly where the splash ends.
func _splash_color() -> Color:
	return ProjectSettings.get_setting("application/boot_splash/bg_color", Color(0.769, 0.831, 0.867))


## Dissolves to [param tint], runs [param swap] while covered, then dissolves
## into whatever is shown now.
func _menu_transition(tint: Color, swap: Callable) -> void:
	_transitioning = true
	await doorway.fader.fade_to(1.0, menu_transition_duration, tint)
	swap.call()
	await doorway.fader.fade_to(0.0, menu_transition_duration)
	_transitioning = false


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
	outside_role.let_go()
	if _swap_pending:
		_swap_pending = false
		swap_roles()
		await _block_input(swap_wait)


## Start button: through the light colour to the character choose screen.
func _on_start_pressed() -> void:
	if _transitioning or not start_page.visible:
		return
	if character_chooser:
		await _menu_transition(_splash_color(), func() -> void:
			_hide_start_page()
			character_chooser.open())
	else:
		await _menu_transition(doorway.fader.cover_color, _hide_start_page)
		_set_player_input(true)


## Enter on the character choose screen: through the dark red into the game,
## then hand the controls to the players.
func _on_character_confirmed() -> void:
	if _transitioning:
		return
	character_chooser.set_process_unhandled_input(false)  # no second Enter
	await _menu_transition(doorway.fader.cover_color, character_chooser.close)
	_set_player_input(true)


func _hide_start_page() -> void:
	start_page.hide()
	# Hiding a CanvasLayer does not hide CanvasLayers nested in it (Buttons).
	for layer in start_page.find_children("*", "CanvasLayer", true, false):
		layer.hide()


## Ignores every player's input for [param seconds].
func _block_input(seconds: float) -> void:
	_set_player_input(false)
	_input_lock_timer = get_tree().create_timer(seconds, false)
	await _input_lock_timer.timeout
	_input_lock_timer = null
	_set_player_input(true)


func _set_player_input(enabled: bool) -> void:
	for controller in players:
		controller.set_process_unhandled_input(enabled)


func _input_lock_time_left() -> float:
	return _input_lock_timer.time_left if _input_lock_timer else 0.0


## Caught if even one pixel of the knocker shows in the opened doorway.
func _on_doorway_swung_open() -> void:
	if outside_role.is_in_doorway():
		outside_role.freeze()
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
