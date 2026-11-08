class_name CharacterChooser
extends CanvasLayer
## Character select screen shown after the start page.
##
## Each player slides their controller picture between three slots: where
## the two pictures start (left and right) and halfway between them.
## Player 1 uses A / D, player 2 the arrow keys; on a gamepad, the D-pad or
## the left stick moves the picture of the player holding it.
##
## S (player 1) / Down (player 2) / D-pad down or X locks the character under the
## picture:
## only the left and right slots hold a character, and a character can be
## locked by one player only (first come, first served). Pressing it again
## unlocks. Once both players are locked, the screen confirms by itself after
## [member confirm_delay] (unless someone unlocks first); Enter skips the wait.

## Emitted once both players are locked (see [member confirm_delay]).
signal confirmed

## How far the left stick has to be pushed sideways to move a picture (it has
## to come back towards the middle before it moves it again).
const STICK_THRESHOLD := 0.6

## Player 1's picture (A / D). Defaults to the "Controller" child.
@export var controller_one: Control
## Player 2's picture (arrow keys). Defaults to the "Controller2" child.
@export var controller_two: Control
## Seconds a picture takes to slide to the next slot.
@export var move_time := 0.12
## A player's picture while they have locked a character (in place of
## their normal picture, which comes back on unlock).
@export var locked_texture: Texture2D
## The character pictures standing in the left and right slots.
@export var characters: Array[TextureRect] = []
## Per character (same order): the second picture of its selected
## animation. While a character is locked (selected) it flips between its
## normal texture and this one; unlocked, it shows its normal texture.
@export var selected_textures: Array[Texture2D] = []
## Seconds to wait, once both players are locked, before confirming.
@export var confirm_delay := 1.0
## Frames per second of the selected animation (each frame is one picture).
@export_range(0.5, 30.0, 0.5) var selected_fps := 4.0

## The two players (player 1 first), for their gamepads. Set by main.
var players: Array[PlayerController] = []
## Per player: the side (-1, 0, 1) the left stick is pushed to.
var _stick: Array[int] = [0, 0]
## The three slot x positions, left to right.
var _slots: Array[float] = []
## Slot index (0, 1, 2) of each player's picture.
var _slot_of: Array[int] = [0, 2]
var _tweens: Array[Tween] = [null, null]
## Whether each player has locked the character under their picture.
var _locked: Array[bool] = [false, false]
## Each player's picture texture from the scene, restored on unlock.
var _controller_textures: Array[Texture2D] = [null, null]
## Each character's texture from the scene, restored on unlock.
var _idle_textures: Array[Texture2D] = []
## Per character: whether its selected animation plays, and its frame.
var _selected: Array[bool] = [false, false]
var _frame: Array[int] = [0, 0]
var _frame_time := 0.0
## True once [signal confirmed] was emitted (until the screen opens again).
var _confirmed := false
## Counts lock changes, so a wait started before one is dropped.
var _lock_change := 0


func _ready() -> void:
	if controller_one == null:
		controller_one = get_node_or_null("Controller") as Control
	if controller_two == null:
		controller_two = get_node_or_null("Controller2") as Control
	set_process_unhandled_input(false)
	set_process(false)
	for character in characters:
		_idle_textures.append(character.texture if character else null)
	if controller_one == null or controller_two == null:
		push_warning("CharacterChooser: Controller and Controller2 are both needed")
		return
	_controller_textures = [_texture_of(controller_one), _texture_of(controller_two)]
	var one_x := controller_one.position.x
	var two_x := controller_two.position.x
	_slots = [minf(one_x, two_x), (one_x + two_x) / 2.0, maxf(one_x, two_x)]
	if one_x > two_x:
		_slot_of = [2, 0]


## Shows the screen and starts listening to the keys.
func open() -> void:
	_set_shown(true)
	set_process_unhandled_input(true)
	_confirmed = false
	set_process(_selected.has(true))


## Hides the screen and stops listening to the keys.
func close() -> void:
	_set_shown(false)
	set_process_unhandled_input(false)
	set_process(false)


## The slot (0 = left, 1 = middle, 2 = right) player [param player] chose.
func slot_of(player: int) -> int:
	return _slot_of[player]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if _joypad_input(event):
			get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_A:
			_step(0, -1)
		KEY_D:
			_step(0, 1)
		KEY_LEFT:
			_step(1, -1)
		KEY_RIGHT:
			_step(1, 1)
		KEY_S:
			_toggle_lock(0)
		KEY_DOWN:
			_toggle_lock(1)
		KEY_ENTER, KEY_KP_ENTER:
			if is_ready():
				_confirm()
		_:
			return
	get_viewport().set_input_as_handled()


## D-pad left / right or the left stick moves the picture of the player the
## gamepad belongs to, D-pad down or X locks / unlocks. True if it was used.
func _joypad_input(event: InputEvent) -> bool:
	var player := _player_of_joypad(event.device)
	if player < 0:
		return false
	var motion := event as InputEventJoypadMotion
	if motion:
		if motion.axis != JOY_AXIS_LEFT_X:
			return false
		var side := 0
		if motion.axis_value <= -STICK_THRESHOLD:
			side = -1
		elif motion.axis_value >= STICK_THRESHOLD:
			side = 1
		elif absf(motion.axis_value) > STICK_THRESHOLD / 2.0:
			return true  # between: keep the last side, so it doesn't flicker
		if side != _stick[player] and side != 0:
			_step(player, side)
		_stick[player] = side
		return true
	var button := event as InputEventJoypadButton
	if not button.pressed:
		return false
	match button.button_index:
		JOY_BUTTON_DPAD_LEFT:
			_step(player, -1)
		JOY_BUTTON_DPAD_RIGHT:
			_step(player, 1)
		# X is the PlayStation cross: the bottom face button (A on Xbox).
		JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_A:
			_toggle_lock(player)
		_:
			return false
	return true


## Which player (0 or 1) gamepad [param device] belongs to, or -1.
func _player_of_joypad(device: int) -> int:
	for player in mini(players.size(), 2):
		if players[player] and players[player].joypad_id == device:
			return player
	return -1


## True once both players have locked a character.
func is_ready() -> bool:
	return _locked[0] and _locked[1]


## Locks or unlocks the character under [param player]'s picture. The
## middle slot has no character, and a character the other player already
## locked cannot be taken.
func _toggle_lock(player: int) -> void:
	if _slots.is_empty():
		return
	if _locked[player]:
		_set_locked(player, false)
		return
	var slot := _slot_of[player]
	if slot == 1:
		return
	var other := 1 - player
	if _locked[other] and _slot_of[other] == slot:
		return
	_set_locked(player, true)


func _set_locked(player: int, locked: bool) -> void:
	_locked[player] = locked
	_lock_change += 1
	var picture := controller_one if player == 0 else controller_two
	if picture is TextureRect and locked_texture:
		(picture as TextureRect).texture = locked_texture if locked else _controller_textures[player]
	_show_selected(_slot_of[player], locked)
	if locked and is_ready():
		_confirm_after_delay()


## Confirms after [member confirm_delay] if both players are still locked.
func _confirm_after_delay() -> void:
	var change := _lock_change
	await get_tree().create_timer(confirm_delay).timeout
	# Still the same locks (nobody unlocked and locked again meanwhile)?
	if change == _lock_change and is_ready() and visible:
		_confirm()


func _confirm() -> void:
	if _confirmed:
		return
	_confirmed = true
	confirmed.emit()


## Starts the selected animation of the character in [param slot] (0 = left,
## 2 = right), starting on its selected picture, or stops it and shows its
## normal picture again.
func _show_selected(slot: int, selected: bool) -> void:
	var index := 0 if slot == 0 else 1
	if index >= characters.size() or characters[index] == null:
		return
	_selected[index] = selected
	_frame[index] = 1 if selected else 0
	if selected and not is_processing():
		_frame_time = 0.0
	_update_texture(index)
	set_process(_selected.has(true))


## Advances the selected animations.
func _process(delta: float) -> void:
	if selected_fps <= 0.0:
		return
	_frame_time += delta
	var frame_length := 1.0 / selected_fps
	if _frame_time < frame_length:
		return
	_frame_time = fmod(_frame_time, frame_length)
	for index in _selected.size():
		if _selected[index]:
			_frame[index] = 1 - _frame[index]
			_update_texture(index)


## Frame 0 is the character's normal picture, frame 1 its selected one.
func _update_texture(index: int) -> void:
	if index >= characters.size() or characters[index] == null:
		return
	var texture: Texture2D = null
	if _frame[index] == 1 and index < selected_textures.size():
		texture = selected_textures[index]
	characters[index].texture = texture if texture else _idle_textures[index]


## Moves [param player]'s picture one slot in [param direction] (-1 or 1).
## A locked picture stays where it is.
func _step(player: int, direction: int) -> void:
	if _slots.is_empty() or _locked[player]:
		return
	var slot := clampi(_slot_of[player] + direction, 0, _slots.size() - 1)
	if slot == _slot_of[player]:
		return
	_slot_of[player] = slot
	var picture := controller_one if player == 0 else controller_two
	if _tweens[player]:
		_tweens[player].kill()
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(picture, "position:x", _slots[slot], move_time)
	_tweens[player] = tween


static func _texture_of(picture: Control) -> Texture2D:
	return (picture as TextureRect).texture if picture is TextureRect else null


## Hiding a CanvasLayer does not hide the CanvasLayers nested in it.
func _set_shown(shown: bool) -> void:
	visible = shown
	for nested in find_children("*", "CanvasLayer", true, false):
		nested.visible = shown
