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
## Shown when the match is won (confetti on the winner), before the menu.
@export var victory_screen: VictoryScreen
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
## The X-ray goggles going on (full-screen frames, first to last): played
## before the blink, held while it runs, then played backwards to take them off.
@export var xray_frames: Array[Texture2D] = []
## Goggle animation frames per second.
@export var xray_fps := 12.0
## Shows [member xray_frames] (full screen, over the room view only).
@export var xray_glasses: TextureRect
## The courier modifier's figure (knocks at a neighbour's door).
@export var courier: Courier
## The muffin: Granny's arm bringing it out (frames, first to last), then she
## opens the door.
@export var muffin_frames: Array[Texture2D] = []
@export var muffin_fps := 8.0
## Seconds the last muffin frame holds before the door opens.
@export var muffin_hold := 0.5
## Shows [member muffin_frames] (over the room view only).
@export var muffin_hand: TextureRect
## The muffin held out in the hallway once the door is open (last frame).
@export var muffin_hallway: TextureRect
## Once the door is open: seconds a hooked Knocker takes to walk up in front of
## the doorframe, and seconds until the muffin's outcome (caught / Granny
## loses a life) is decided.
@export var muffin_lure_time := 2.0
@export var muffin_wait := 2.6
## True if the smell hooked the Knocker when the muffin came out.
var _muffin_lured := false
## The flip-flop (full-screen frames): Granny raises it, swings, and throws.
@export var flipflop_frames: Array[Texture2D] = []
@export var flipflop_fps := 12.0
## Frames [0, raise) lift it up when the card is used; the last of them holds
## until the door opens.
@export var flipflop_raise_frames := 4
## A hit plays frames [raise, hit_end); a throw (into the bush) plays the rest
## to the end, the flip-flop flying off.
@export var flipflop_hit_end := 9
## Seconds she stands in the hallway holding it up before swinging / throwing.
@export var flipflop_swing_delay := 0.4
## Lives the Knocker loses when the flip-flop hits him in the doorway.
@export var flipflop_damage := 2
## Shows the flip-flop in the room view and in the hallway.
@export var flipflop_hand: TextureRect
@export var flipflop_hallway: TextureRect
## The burst where the flip-flop lands (the last frames of the animation,
## from [member flipflop_burst_from], cut to [member flipflop_burst_region]
## in the frames' own pixels). It is drawn by [member flipflop_burst],
## centred on whoever got hit.
@export var flipflop_burst: TextureRect
@export var flipflop_burst_from := 10
@export var flipflop_burst_region := Rect2(1155, 150, 400, 400)
## Size of the burst on screen (design pixels).
@export var flipflop_burst_size := 300.0
## Where the burst goes (design pixels, 1280x720 hallway): on the caught
## Knocker, or on the bush he hides in.
@export var flipflop_hit_point := Vector2(660, 230)
@export var flipflop_bush_point := Vector2(1060, 330)
## Bumped by every burst and round reset, so an old burst stops.
var _burst_token := 0
## True from the card until the next door opening.
var _flipflop_ready := false
## Bumped by every flip-flop animation and round reset, so an old one stops.
var _flipflop_token := 0
## Bumped by every muffin and round reset, so an old one stops.
var _muffin_token := 0
## True from the muffin until the door has closed again.
var _muffin_on := false

## Round wins needed to win the match (2 = best of 3).
@export_range(1, 5) var rounds_to_win := 2

## Set when either player runs out of health; once the door has closed the
## next round starts, or, if the match is decided, back to the main menu.
var _round_over_pending := false
var _match_over := false
## Per player: the modifier they picked for this round (or none), and
## whether they used it already (once per round).
var _modifiers: Dictionary[PlayerController, Modifier] = {}
var _modifier_used: Dictionary[PlayerController, bool] = {}
## Seconds the bush (BushModifier) lasts: then the Knocker steps out of it and
## the card is used up.
@export var bush_duration := 5.0
## Bumped whenever a bush countdown starts or the round resets, so an old
## countdown does nothing.
var _bush_token := 0
## Rounds won in this match, per role.
var _resident_wins := 0
var _knocker_wins := 0
var _input_lock_timer: SceneTreeTimer
## True while a menu transition runs; repeated presses are ignored meanwhile.
var _transitioning := false
## False while the start page or the character choose screen is up.
var _in_game := true
var _see_through_tween: Tween
## True while the goggles are on and the wall blinks (the X-ray sees).
var _seeing_through := false

@onready var _health_hud: HealthHud = $HealthHud


func _ready() -> void:
	doorway.swung_open.connect(_on_doorway_swung_open)
	doorway.closed.connect(_on_doorway_closed)
	for controller in players:
		if controller.model:
			controller.model.defeated.connect(_on_player_defeated.bind(controller))
		controller.modifier_requested.connect(_on_modifier_requested)
	if inside_role:
		inside_role.peeked.connect(_on_granny_peeked)
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
	if victory_screen == null:
		victory_screen = get_node_or_null("Victory") as VictoryScreen
	if victory_screen:
		victory_screen.continued.connect(_on_victory_continued)
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
	var in_victory := victory_screen != null and victory_screen.visible
	_health_hud.visible = not (in_start_menu or in_character_menu or in_card_menu or in_victory)


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


## Each player gets the modifier on the card they picked (their side's), for
## the coming round, unused.
func _give_modifiers() -> void:
	_modifiers.clear()
	_modifier_used.clear()
	if card_chooser == null:
		return
	for index in players.size():
		var side: int = card_chooser.player_sides[index] if index < card_chooser.player_sides.size() else index
		var modifier := card_chooser.modifier_of(side)
		if modifier:
			_modifiers[players[index]] = modifier
		_modifier_used[players[index]] = false


## D-pad up / Q: the player uses the modifier they picked this round, once.
## Q is shared by every keyboard player: it goes to a player without a
## gamepad, Granny's if neither has one.
func _on_modifier_requested(controller: PlayerController, from_keyboard: bool) -> void:
	if from_keyboard:
		if controller.has_joypad():
			return
		var all_keyboard := players.all(func(c: PlayerController) -> bool: return not c.has_joypad())
		if all_keyboard and not controller.role is InsideRole:
			return
	use_modifier(controller)


## Activates [param controller]'s modifier for this round. Nothing happens if
## they have none, used it already, or it isn't for the role they play.
## Returns true if it was used.
func use_modifier(controller: PlayerController) -> bool:
	if not _in_game or _transitioning:
		return false
	# Nobody uses a modifier while Granny looks through the peephole.
	if inside_role and inside_role.state == InsideRole.State.PEEKING:
		return false
	var modifier: Modifier = _modifiers.get(controller)
	if modifier == null or _modifier_used.get(controller, false):
		return false
	if not modifier.fits(controller.role):
		return false
	if not modifier.activate(self, controller):
		return false  # couldn't take effect now: still theirs to use
	if modifier.spent_on_activate():
		spend_modifier(controller)
	return true


## [param controller]'s modifier counts as used for this round.
func spend_modifier(controller: PlayerController) -> void:
	var modifier: Modifier = _modifiers.get(controller)
	if modifier == null or _modifier_used.get(controller, false):
		return
	_modifier_used[controller] = true
	print("%s used %s" % [controller.model.display_name if controller.model else "?", modifier.display_name])


## The auto-knocker: the knocking machine at the door starts knocking. False
## if it can't be placed now (the door is open, or it is already there).
func place_knocking_machine() -> bool:
	var machine := doorway.prank
	if machine == null or doorway.is_open or machine.visible:
		return false
	doorway.place_prank()
	return true


## The bush: the Knocker at the door turns into a thuja. Opening the door on
## it costs Granny a life, not him (nobody shows in the doorway). False if he
## is already disguised, or the door is open.
func disguise_knocker() -> bool:
	if outside_role == null or not outside_role.disguise():
		return false
	_check_bush_seen()  # put on during the X-ray: seen at once
	_bush_token += 1
	var token := _bush_token
	get_tree().create_timer(bush_duration).timeout.connect(_on_bush_timeout.bind(token))
	return true


## The bush's time is up: the Knocker steps out and the card is used. Nothing
## if he dropped it already (knocking) or the door is open on it.
func _on_bush_timeout(token: int) -> void:
	if token != _bush_token or outside_role == null or outside_role.knocker == null:
		return
	if not outside_role.knocker.disguised or doorway.is_open:
		return
	outside_role.knocker.set_disguised(false)
	_spend_bush()
	print("Bush ran out")


## The bush is spent once Granny has seen it: the door opened on it, or the
## X-ray goggles showed it through the wall.
func _spend_bush() -> void:
	for controller in players:
		if controller.role == outside_role:
			spend_modifier(controller)


## While the X-ray runs, a bush out there is seen through the wall: the
## Knocker's card is used up (he can't put it on again this round).
func _check_bush_seen() -> void:
	if not is_see_through_on() or outside_role == null or outside_role.knocker == null:
		return
	if outside_role.knocker.disguised:
		_spend_bush()
		print("Bush seen through the X-ray")


## True while the wall and door blink see-through (the X-ray goggles).
func is_see_through_on() -> bool:
	return _seeing_through


## The courier: he knocks at a neighbour's door (muffled). Opening the door
## to it costs Granny a life (nobody is at her door); otherwise he leaves
## after a few seconds. False if the door is open or he is already here.
func send_courier() -> bool:
	if courier == null or doorway.is_open:
		return false
	return courier.arrive()


## The muffin: Granny brings out the deadly smelling cupcake and opens the
## door. A Knocker anywhere in the corridor is drawn to the door by the smell
## and caught (he loses a life); with nobody there, she loses one. False if
## she can't open the door right now.
func serve_muffin() -> bool:
	if muffin_hand == null or muffin_frames.is_empty() or _muffin_on or doorway.is_open:
		return false
	if inside_role == null or not inside_role.can_open_now():
		return false
	_muffin_on = true
	_muffin_token += 1
	_play_muffin(_muffin_token)
	return true


func _play_muffin(token: int) -> void:
	inside_role.set_locked(true)
	# The smell: a Knocker in range (anywhere in the corridor) as she brings
	# it out stops, hooked; once the door is open he walks up to it.
	_muffin_lured = outside_role.lure()
	if _muffin_lured:
		print("The muffin smell hooks the Knocker")
	muffin_hand.texture = muffin_frames[0]
	muffin_hand.show()
	for frame in muffin_frames:
		muffin_hand.texture = frame
		await get_tree().create_timer(1.0 / maxf(muffin_fps, 0.1), false).timeout
		if token != _muffin_token:
			return
	await get_tree().create_timer(muffin_hold, false).timeout
	if token != _muffin_token:
		return
	inside_role.set_locked(false)
	inside_role.open_now()


## The door is open with the muffin held out in the hallway: a hooked
## Knocker walks up in front of the doorframe and is caught; with nobody
## coming, Granny loses a life.
func _resolve_muffin(token: int) -> void:
	if muffin_hallway:
		muffin_hallway.texture = muffin_frames[-1]
		muffin_hallway.show()
	if _muffin_lured:
		outside_role.draw_in(muffin_lure_time)
	await get_tree().create_timer(muffin_wait, false).timeout
	if token != _muffin_token:
		return
	if _muffin_lured:
		outside_role.freeze()
		if outside_role.player:
			outside_role.player.take_damage(1)
		print("Elkapva (muffin)")
	else:
		if inside_role and inside_role.player:
			inside_role.player.take_damage(1)
		print("Muffin: nobody came")


## The flip-flop: Granny's next door opening is powered up; she raises the
## flip-flop and holds it until then. False if it is already up or the door
## is open.
func ready_flipflop() -> bool:
	if flipflop_hand == null or flipflop_frames.is_empty() or _flipflop_ready or doorway.is_open:
		return false
	_flipflop_ready = true
	_play_flipflop(flipflop_hand, 0, mini(flipflop_raise_frames, flipflop_frames.size()), false)
	return true


## Plays flip-flop frames [from, to) on [param rect]; hides it afterwards if
## [param hide_after], otherwise the last frame stays.
func _play_flipflop(rect: TextureRect, from: int, to: int, hide_after: bool) -> void:
	_flipflop_token += 1
	var token := _flipflop_token
	rect.texture = flipflop_frames[clampi(from, 0, flipflop_frames.size() - 1)]
	rect.show()
	for index in range(from, mini(to, flipflop_frames.size())):
		rect.texture = flipflop_frames[index]
		await get_tree().create_timer(1.0 / maxf(flipflop_fps, 0.1), false).timeout
		if token != _flipflop_token:
			return
	if hide_after:
		rect.hide()


## The door opened with the flip-flop up: [param outcome] is "hit", "throw"
## (into the bush) or "broken" (nobody there). It plays in the hallway once
## that shows; the flip-flop stays in her hand there until the door closes
## (unless thrown).
func _flipflop_in_hallway(outcome: String) -> void:
	_flipflop_ready = false
	_flipflop_token += 1
	var token := _flipflop_token
	var waited := 0.0
	while not doorway.corridor_view.visible and waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if token != _flipflop_token:
			return
	flipflop_hand.hide()
	if flipflop_hallway == null:
		return
	# She steps out holding it up, as in the room...
	var raise := mini(flipflop_raise_frames, flipflop_frames.size())
	var held := flipflop_frames[maxi(raise - 1, 0)]
	flipflop_hallway.texture = held
	flipflop_hallway.show()
	await get_tree().create_timer(flipflop_swing_delay, false).timeout
	if token != _flipflop_token:
		return
	match outcome:
		"hit":
			# ...swings at him: the burst lands on him, and she holds it up
			# again until the door closes.
			await _play_flipflop(flipflop_hallway, raise, flipflop_hit_end, false)
			if flipflop_hallway.visible:
				flipflop_hallway.texture = held
				_play_burst(flipflop_hit_point)
		"throw":
			# ...throws it (up to the frame it leaves her hand), and it
			# bursts on the bush.
			await _play_flipflop(flipflop_hallway, raise, flipflop_burst_from, true)
			if token == _flipflop_token - 1 and doorway.corridor_view.visible:
				_play_burst(flipflop_bush_point)
		_:
			pass  # nobody there: she just stands there holding it


## The flip-flop's burst, centred on [param at] (design pixels).
func _play_burst(at: Vector2) -> void:
	if flipflop_burst == null or flipflop_burst_from >= flipflop_frames.size():
		return
	_burst_token += 1
	var token := _burst_token
	var half := Vector2.ONE * flipflop_burst_size / 2.0
	flipflop_burst.position = at - half
	flipflop_burst.size = half * 2.0
	flipflop_burst.show()
	for index in range(flipflop_burst_from, flipflop_frames.size()):
		var piece := AtlasTexture.new()
		piece.atlas = flipflop_frames[index]
		piece.region = flipflop_burst_region
		flipflop_burst.texture = piece
		await get_tree().create_timer(1.0 / maxf(flipflop_fps, 0.1), false).timeout
		if token != _burst_token:
			return
	flipflop_burst.hide()


func _end_flipflop() -> void:
	_flipflop_token += 1
	_burst_token += 1
	if flipflop_burst:
		flipflop_burst.hide()
	_flipflop_ready = false
	if flipflop_hand:
		flipflop_hand.hide()
	if flipflop_hallway:
		flipflop_hallway.hide()


func _end_muffin() -> void:
	_muffin_token += 1
	_muffin_on = false
	_muffin_lured = false
	if inside_role:
		inside_role.set_locked(false)
	if muffin_hand:
		muffin_hand.hide()
	if muffin_hallway:
		muffin_hallway.hide()


## Granny looks through the peephole: a knocking machine out there gives
## itself away and breaks.
func _on_granny_peeked() -> void:
	var machine := doorway.prank as KnockingMachine
	if machine and machine.is_active():
		machine.break_down()
		print("Knocking machine spotted")


## [member see_through_key] starts the wall and door blink (in game, debug
## builds only: in the game it is the X-ray goggles modifier).
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not _in_game or not OS.is_debug_build() or key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode != see_through_key:
		return
	start_see_through()
	get_viewport().set_input_as_handled()


## The wall and door blink see-through (the X-ray goggles). Starting it again
## mid-blink starts it over.
func start_see_through() -> void:
	if _see_through_tween:
		_see_through_tween.kill()
	_see_through_tween = create_tween()
	# Granny puts the goggles on first...
	var frame_time := _xray_frames_time()
	if frame_time > 0.0:
		_see_through_tween.tween_callback(xray_glasses.show)
		_see_through_tween.tween_method(_set_xray_frame, 0.0, float(xray_frames.size()), frame_time)
	_see_through_tween.tween_callback(func() -> void:
		_seeing_through = true
		_check_bush_seen())
	_see_through_tween.tween_method(_set_see_through_time, 0.0, see_through_duration, see_through_duration)
	# The last wave may stop halfway; ease back to opaque instead of popping.
	_see_through_tween.tween_method(_set_see_through_alpha, _see_through_alpha_at(see_through_duration), 1.0, see_through_fade_back) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_see_through_tween.tween_callback(func() -> void: _seeing_through = false)
	# ...and takes them off again.
	if frame_time > 0.0:
		_see_through_tween.tween_method(_set_xray_frame, float(xray_frames.size()), 0.0, frame_time)
		_see_through_tween.tween_callback(xray_glasses.hide)


## Stops the X-ray at once: goggles off, wall and door opaque.
func stop_see_through() -> void:
	if _see_through_tween:
		_see_through_tween.kill()
	_seeing_through = false
	_set_see_through_alpha(1.0)
	if xray_glasses:
		xray_glasses.hide()


## Seconds the goggle animation takes one way (0 if there is none).
func _xray_frames_time() -> float:
	if xray_glasses == null or xray_frames.is_empty() or xray_fps <= 0.0:
		return 0.0
	return xray_frames.size() / xray_fps


## Shows goggle frame [param t] (0..frame count; the last one holds).
func _set_xray_frame(t: float) -> void:
	var index := clampi(int(t), 0, xray_frames.size() - 1)
	xray_glasses.texture = xray_frames[index]


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
	if courier:
		courier.leave()  # gone once the door is shut again
	if _muffin_on:
		_end_muffin()
	if not _flipflop_ready:
		_end_flipflop()  # the flip-flop used at this opening goes away
	if _round_over_pending:
		_round_over_pending = false
		if _match_over:
			_show_victory()
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
	stop_see_through()
	if courier:
		courier.leave()
	_end_muffin()
	_end_flipflop()
	_bush_token += 1  # a bush countdown from the last round does nothing
	if doorway.prank:
		doorway.prank.hide()  # the knocking machine goes with the round
	for controller in players:
		if controller.role:
			controller.role.reset_state()
		if controller.model:
			controller.model.reset()


## The match is won: through the light colour to the winner with confetti.
func _show_victory() -> void:
	if victory_screen == null:
		_return_to_menu()
		return
	if _transitioning:
		return
	_in_game = false
	_set_player_input(false)
	var granny_won := _resident_wins > _knocker_wins
	await _menu_transition(_splash_color(), func() -> void:
		_reset_round()
		victory_screen.show_winner(granny_won))


## Pressed on from the victory screen: back to the main menu.
func _on_victory_continued() -> void:
	if _transitioning:
		return
	await _menu_transition(_splash_color(), func() -> void:
		victory_screen.close()
		if start_page.has_method("open"):
			start_page.open()
		else:
			start_page.show())


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
	_give_modifiers()
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
	# A modifier played out at this opening: let the corridor be seen longer.
	var machine := doorway.prank as KnockingMachine
	var knocker_figure := outside_role.knocker
	if _muffin_on or _flipflop_ready or (courier and courier.is_active()) or (machine and machine.visible) \
			or (knocker_figure and knocker_figure.disguised):
		doorway.hold_open()
	if courier and courier.is_active():
		courier.caught()  # she opened to his knock: he stops and stays in view
	if _muffin_on:
		_resolve_muffin(_muffin_token)  # decided once the smell had its time
		return
	var flipflop := _flipflop_ready
	if outside_role.is_in_doorway():
		outside_role.freeze()
		if outside_role.player:
			outside_role.player.take_damage(flipflop_damage if flipflop else 1)
		if flipflop:
			_flipflop_in_hallway("hit")
		print("Elkapva" + (" (flip-flop)" if flipflop else ""))
	elif flipflop and outside_role.knocker and outside_role.knocker.disguised:
		# She would have caught him, but he is the bush: she throws the
		# flip-flop into it like a boomerang. He loses a life, she doesn't.
		_spend_bush()
		if outside_role.player:
			outside_role.player.take_damage(1)
		_flipflop_in_hallway("throw")
		print("Flip-flop into the bush")
	else:
		if outside_role.knocker and outside_role.knocker.disguised:
			_spend_bush()  # Granny saw the bush
		if flipflop:
			_flipflop_in_hallway("broken")
			print("The flip-flop broke")
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
