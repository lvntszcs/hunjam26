extends Control
## Wires players, roles and the doorway together and owns the round rules.
##
## Scene layout:
##   Doorway  - presentation and door state
##   Roles    - InsideRole, OutsideRole (one per side of the door)
##   Players  - PlayerController per player, each holding a PlayerModel and a Role

const HealthHud := preload("res://scripts/health_hud.gd")

@export var doorway: Doorway
@export var outside_role: OutsideRole
@export var inside_role: InsideRole
@export var players: Array[PlayerController] = []
## The start menu. While it is shown the players' game controls are off.
@export var start_page: CanvasLayer
## Clicking it hides [member start_page] and turns the game controls on.
@export var start_button: PixelButton
## Shown after the start page; Enter on it starts the game.
@export var character_chooser: CharacterChooser
## Shown after the character select; Enter on it starts the game.
@export var card_chooser: CardChooser
## Seconds for each half (cover / reveal) of the dissolve between the boot
## splash, the start page, the character select and the game.
@export var menu_transition_duration := 0.5
## Pressing [member see_through_key] in the game makes these blink softly
## (sine) between opaque and [member see_through_alpha] for
## [member see_through_duration] seconds, faster and faster.
## Defaults to the Wall and Door nodes.
@export var see_through: Array[CanvasItem] = []
@export var see_through_key: Key = KEY_X
## The most transparent the blink gets.
@export_range(0.0, 1.0) var see_through_alpha := 0.5
@export var see_through_duration := 3.0
## Blinks per second at the start of the effect.
@export var see_through_start_rate := 0.3
## Blinks per second at the end of the effect.
@export var see_through_end_rate := 1.5
## Seconds to ease back to opaque after the last blink.
@export var see_through_fade_back := 0.4

## Round wins needed to win the match (2 = best of 3).
@export_range(1, 5) var rounds_to_win := 2

## Set when either player runs out of health; once the door has closed the
## next round starts, or, if the match is decided, back to the main menu.
var _round_over_pending := false
var _match_over := false
## Rounds won in this match, per role.
var _resident_wins := 0
var _knocker_wins := 0
var _input_lock_timer: SceneTreeTimer
## True while a menu transition runs; repeated presses are ignored meanwhile.
var _transitioning := false
## False while the start page or the character choose screen is up.
var _in_game := true
var _see_through_tween: Tween

@onready var _health_hud: HealthHud = $HealthHud


func _ready() -> void:
	doorway.swung_open.connect(_on_doorway_swung_open)
	doorway.closed.connect(_on_doorway_closed)
	for controller in players:
		if controller.model:
			controller.model.defeated.connect(_on_player_defeated.bind(controller))
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
		character_chooser.players = players
	if card_chooser == null:
		card_chooser = get_node_or_null("CardChoose") as CardChooser
	if card_chooser:
		card_chooser.confirmed.connect(_on_card_confirmed)
		card_chooser.players = players
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	# The menus visible in the editor decide where the game starts:
	# start page -> character choose -> card choose -> game.
	if start_page and start_page.visible:
		_in_game = false
		_set_player_input(false)
		if character_chooser:
			character_chooser.close()
		if card_chooser:
			card_chooser.close()
	elif character_chooser and character_chooser.visible:
		_in_game = false
		_set_player_input(false)
		character_chooser.open()
		if card_chooser:
			card_chooser.close()
	elif card_chooser and card_chooser.visible:
		_in_game = false
		_set_player_input(false)
		card_chooser.open()
	if see_through.is_empty():
		for node_name in ["Wall", "Door"]:
			var item := get_node_or_null(node_name) as CanvasItem
			if item:
				see_through.append(item)
	_health_hud.setup(players)
	_show_wins()
	_sync_health_hud_visibility()
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
	_sync_health_hud_visibility()
	await doorway.fader.fade_to(0.0, menu_transition_duration)
	_transitioning = false


func _sync_health_hud_visibility() -> void:
	var in_start_menu := start_page != null and start_page.visible
	var in_character_menu := character_chooser != null and character_chooser.visible
	var in_card_menu := card_chooser != null and card_chooser.visible
	_health_hud.visible = not (in_start_menu or in_character_menu or in_card_menu)


## A button or trigger press on an unassigned gamepad joins the next free player.
## The joining button press itself is swallowed.
## (_input runs before any PlayerController's _unhandled_input.)
func _input(event: InputEvent) -> void:
	var joining: bool = event is InputEventJoypadButton and event.is_pressed()
	var motion := event as InputEventJoypadMotion
	if motion:
		joining = (motion.axis == JOY_AXIS_TRIGGER_LEFT or motion.axis == JOY_AXIS_TRIGGER_RIGHT) \
				and motion.axis_value >= PlayerController.TRIGGER_PRESS_THRESHOLD
	if joining and not _joypad_owner(event.device) and _claim_joypad(event.device):
		get_viewport().set_input_as_handled()


## [member see_through_key] starts the wall and door blink (in game only).
## Pressing it again mid-blink starts it over.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not _in_game or key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode != see_through_key:
		return
	if _see_through_tween:
		_see_through_tween.kill()
	_see_through_tween = create_tween()
	_see_through_tween.tween_method(_set_see_through_time, 0.0, see_through_duration, see_through_duration)
	# The last wave may stop halfway; ease back to opaque instead of popping.
	_see_through_tween.tween_method(_set_see_through_alpha, _see_through_alpha_at(see_through_duration), 1.0, see_through_fade_back) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	get_viewport().set_input_as_handled()


## Blink at [param t] seconds into the effect. The rate grows linearly from
## [member see_through_start_rate] to [member see_through_end_rate], so the
## phase is its integral; (1 - cos) starts and ends each wave at opaque.
func _set_see_through_time(t: float) -> void:
	_set_see_through_alpha(_see_through_alpha_at(t))


func _see_through_alpha_at(t: float) -> float:
	var rate_growth := (see_through_end_rate - see_through_start_rate) / maxf(see_through_duration, 0.001)
	var phase := TAU * (see_through_start_rate * t + 0.5 * rate_growth * t * t)
	var depth := (1.0 - cos(phase)) / 2.0  # 0 = opaque, 1 = most transparent
	return lerpf(1.0, see_through_alpha, depth)


func _set_see_through_alpha(alpha: float) -> void:
	for item in see_through:
		if item:
			item.modulate.a = alpha


## Gives each player the role of the character they locked on the character
## screen: Granny (left slot) plays inside the door, the Knocker (right slot)
## outside, whichever controller they hold. The card screen's sides follow.
func _assign_roles_from_choice() -> void:
	if players.size() < 2 or character_chooser == null:
		return
	var sides: Array[int] = [0, 1]
	for index in 2:
		var granny := character_chooser.slot_of(index) == 0
		players[index].role = inside_role if granny else outside_role
		sides[index] = 0 if granny else 1
	if card_chooser:
		card_chooser.player_sides = sides


## [param loser] ran out of health: the other role wins the round.
func _on_player_defeated(loser: PlayerController) -> void:
	if _round_over_pending:
		return  # one winner per round
	if loser.role is InsideRole:
		_knocker_wins += 1
	else:
		_resident_wins += 1
	_match_over = maxi(_resident_wins, _knocker_wins) >= rounds_to_win
	_round_over_pending = true
	_show_wins()


func _on_doorway_closed() -> void:
	outside_role.let_go()
	if _round_over_pending:
		_round_over_pending = false
		if _match_over:
			_return_to_menu()
		else:
			_next_round()


## A new match: no rounds won yet.
func _start_match() -> void:
	_resident_wins = 0
	_knocker_wins = 0
	_match_over = false
	_round_over_pending = false
	_show_wins()
	if card_chooser:
		card_chooser.start_match()


func _show_wins() -> void:
	# Best of (2 * rounds_to_win - 1): each side has rounds_to_win circles.
	_health_hud.show_wins(_resident_wins, _knocker_wins, rounds_to_win)


## The round is decided but the match is not: through the dark red to the
## card screen (each side picks a card it has not had yet this match), then a
## fresh round, same roles, full health.
func _next_round() -> void:
	if _transitioning:
		return
	_set_player_input(false)
	if card_chooser:
		_in_game = false
		await _menu_transition(doorway.fader.cover_color, func() -> void:
			_reset_round()
			card_chooser.open())
		return
	await _menu_transition(doorway.fader.cover_color, _reset_round)
	if _in_game:
		_set_player_input(true)


func _reset_round() -> void:
	for controller in players:
		if controller.role:
			controller.role.reset_state()
		if controller.model:
			controller.model.reset()


## Someone is out of health: through the dark red back to the main menu, with
## the roles and health reset for the next game.
func _return_to_menu() -> void:
	if _transitioning:
		return
	_in_game = false
	_set_player_input(false)
	await _menu_transition(doorway.fader.cover_color, func() -> void:
		_reset_round()
		if start_page.has_method("open"):
			start_page.open()
		else:
			start_page.show())


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
		_in_game = true
		_set_player_input(true)


## Enter on the character choose screen: through the light colour to the
## card choose screen (or straight into the game without one).
func _on_character_confirmed() -> void:
	if _transitioning:
		return
	character_chooser.set_process_unhandled_input(false)  # no second Enter
	_assign_roles_from_choice()
	_start_match()
	if card_chooser:
		await _menu_transition(_splash_color(), func() -> void:
			character_chooser.close()
			card_chooser.open())
		return
	await _menu_transition(doorway.fader.cover_color, character_chooser.close)
	_start_game()


## Both cards chosen (and slid away): through the dark red into the round.
func _on_card_confirmed() -> void:
	if _transitioning:
		return
	card_chooser.set_process_unhandled_input(false)
	await _menu_transition(doorway.fader.cover_color, func() -> void:
		card_chooser.close()
		_reset_round())
	_start_game()


## Hands the controls to the players.
func _start_game() -> void:
	_in_game = true
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
		if inside_role and inside_role.player:
			inside_role.player.take_damage(1)
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
