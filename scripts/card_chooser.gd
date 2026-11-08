@tool
class_name CardChooser
extends CanvasLayer
## Card select screen, shown after the character select.
##
## Three cards on the left for Granny's player and three on the right for the
## Knocker's (see [member player_sides]),
## each set laid out in a row, every card nudged a little off its spot so
## they look put down by hand. Under each card a D-pad picture shows the
## button that chooses it: left, down, right, from left to right on each side
## (gamepad D-pad; keyboard: A / S / D for player 1, the arrow keys for
## player 2, on whichever side they play). Choosing is final and leaves no mark on the card (it is a
## secret from the other player): that player's cards slide out of the
## screen, and once both players' cards are gone the screen confirms.
##
## The screen comes before every round of a match: a card a side chose in an
## earlier round of the match stays in its row (to learn from) but cannot be
## chosen again; [member unavailable_texture] replaces its D-pad picture (see
## [method start_match]).
##
## The cards are laid out by this script (also in the editor): change the
## rows with the exports below, not by moving the cards.

## Emitted once both players chose a card and their cards left the screen.
signal confirmed

## Cards per player.
const PER_PLAYER := 3

## All the cards: the first three are player 1's (left), the next three
## player 2's (right). Defaults to the children of the "Cards" node.
## The pictures are full-screen with the card drawn in the middle.
@export var cards: Array[Control] = []
## Centre of the left / right row, in design pixels.
@export var left_center := Vector2(325, 400):
	set(value):
		left_center = value
		_layout(true)
@export var right_center := Vector2(965, 400):
	set(value):
		right_center = value
		_layout(true)
## Distance between the centres of two neighbouring cards in a row.
@export var card_spacing := 192.0:
	set(value):
		card_spacing = value
		_layout(true)
## Each card is nudged by a random amount up to this much (design pixels), so
## the row doesn't look machine-placed. No rotation or scaling: either one
## breaks the dithering.
@export var max_nudge := Vector2(4, 6):
	set(value):
		max_nudge = value
		_layout(true)
## Per position in a row (left, middle, right): the D-pad picture under the
## card, showing the button that chooses it.
@export var button_textures: Array[Texture2D] = []:
	set(value):
		button_textures = value
		_layout(true)
## Shown in place of the D-pad picture under a card that cannot be chosen
## (chosen in an earlier round of the match).
@export var unavailable_texture: Texture2D:
	set(value):
		unavailable_texture = value
		_layout(true)
## Size of [member unavailable_texture] (its square; its art fills the
## picture, the D-pad's does not).
@export var unavailable_size := 72.0:
	set(value):
		unavailable_size = value
		_layout(true)
## Size of a D-pad picture (its square, in design pixels).
@export var button_size := 110.0:
	set(value):
		button_size = value
		_layout(true)
## Distance from a card's centre down to its D-pad picture's centre.
@export var button_offset := 210.0:
	set(value):
		button_offset = value
		_layout(true)
## Size of a card (1 = as drawn on the full-screen picture).
@export var card_scale := 0.55:
	set(value):
		card_scale = value
		_layout(true)
## Seconds after choosing before the cards slide away.
@export var leave_delay := 0.2
## Seconds the cards take to slide out of the screen (down).
@export var leave_time := 0.45

## The two players (player 1 first), for their gamepads. Set by main.
var players: Array[PlayerController] = []
## Per player (same order): their side, 0 = left (Granny), 1 = right
## (Knocker). Set by main from the character choice.
var player_sides: Array[int] = [0, 1]
## Index (0..2) of the card each player chose, within their own three.
var _choice: Array[int] = [1, 1]
var _locked: Array[bool] = [false, false]
## Per card: its D-pad picture (made by this script).
var _buttons: Array[TextureRect] = []
## Per player: the slide out of the screen, and whether it has finished.
var _leave_tweens: Array[Tween] = [null, null]
var _gone: Array[bool] = [false, false]
## Per side: the cards (0..2) it chose in earlier rounds of this match.
var _used: Array[Array] = [[], []]
## Per card: a fixed random nudge, -1..1 on each axis.
var _nudge: Array[Vector2] = []


func _ready() -> void:
	if cards.is_empty():
		var holder := get_node_or_null("Cards")
		if holder:
			for child in holder.get_children():
				if child is Control:
					cards.append(child)
	set_process_unhandled_input(false)
	if cards.size() < PER_PLAYER * 2:
		push_warning("CardChooser: needs %d cards" % (PER_PLAYER * 2))
		return
	for card in cards:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The card picture is shrunk to about a quarter: without mipmaps its
		# fine dithering turns into a moire that changes with the zoom.
		card.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_nudge.append(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)))
		var button := TextureRect.new()
		button.name = card.name + "Button"
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		button.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		card.get_parent().add_child(button)
		_buttons.append(button)
	_layout(true)


## Shows the screen (cards back in their rows) and starts listening to the
## keys.
func open() -> void:
	for player in 2:
		if _leave_tweens[player]:
			_leave_tweens[player].kill()
		_leave_tweens[player] = null
		_locked[player] = false
		_gone[player] = false
	_layout(true)
	_set_shown(true)
	set_process_unhandled_input(true)


## A new match: every card is available again.
func start_match() -> void:
	_used = [[], []]
	_layout(true)


## Hides the screen and stops listening to the keys.
func close() -> void:
	_set_shown(false)
	set_process_unhandled_input(false)


## The card (0..2, left to right within their own row) player
## [param player] chose.
func card_of(player: int) -> int:
	return _choice[player]


## True once both players have locked a card.
func is_ready() -> bool:
	return _locked[0] and _locked[1]


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var player := -1
	var card := -1
	var key := event as InputEventKey
	var pad := event as InputEventJoypadButton
	if key and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_A:
				player = _side_of(0)
				card = 0
			KEY_S:
				player = _side_of(0)
				card = 1
			KEY_D:
				player = _side_of(0)
				card = 2
			KEY_LEFT:
				player = _side_of(1)
				card = 0
			KEY_DOWN:
				player = _side_of(1)
				card = 1
			KEY_RIGHT:
				player = _side_of(1)
				card = 2
	elif pad and pad.pressed:
		match pad.button_index:
			JOY_BUTTON_DPAD_LEFT:
				card = 0
			JOY_BUTTON_DPAD_DOWN:
				card = 1
			JOY_BUTTON_DPAD_RIGHT:
				card = 2
		player = _player_of_joypad(pad.device)
	if player < 0 or card < 0:
		return
	_choose(player, card)
	get_viewport().set_input_as_handled()


## Which side (0 = left, 1 = right) gamepad [param device] belongs to, or -1.
func _player_of_joypad(device: int) -> int:
	for player in mini(players.size(), 2):
		if players[player] and players[player].joypad_id == device:
			return _side_of(player)
	return -1


## The side (0 = left, 1 = right) player [param player] (0 or 1) plays on.
func _side_of(player: int) -> int:
	return player_sides[player] if player < player_sides.size() else player


## [param player] chooses card [param card] (0..2) of their row (final):
## nothing marks it, their cards just slide out of the screen.
func _choose(player: int, card: int) -> void:
	if cards.size() < PER_PLAYER * 2 or _locked[player] or _used[player].has(card):
		return
	_choice[player] = card
	_locked[player] = true
	_used[player].append(card)
	_leave(player)


## Slides [param player]'s cards down out of the screen; confirms once both
## players' cards are gone.
func _leave(player: int) -> void:
	var view_height: float = ProjectSettings.get_setting("display/window/size/viewport_height", 720)
	var wait := create_tween()
	wait.tween_interval(leave_delay)
	_leave_tweens[player] = wait
	await wait.finished
	if _leave_tweens[player] != wait:
		return  # the screen was opened again meanwhile
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	# Far enough for a card (drawn in the middle of its picture).
	var drop := view_height
	for i in PER_PLAYER:
		var index := player * PER_PLAYER + i
		var card := cards[index]
		tween.tween_property(card, "offset_top", card.offset_top + drop, leave_time).set_delay(i * 0.04)
		tween.tween_property(card, "offset_bottom", card.offset_bottom + drop, leave_time).set_delay(i * 0.04)
		if index < _buttons.size():
			var button := _buttons[index]
			tween.tween_property(button, "position:y", button.position.y + drop, leave_time).set_delay(i * 0.04)
	_leave_tweens[player] = tween
	await tween.finished
	if _leave_tweens[player] != tween:
		return
	_gone[player] = true
	if _gone[0] and _gone[1] and visible:
		confirmed.emit()


## Places every card (and its D-pad picture) in its row.
func _layout(_instant: bool) -> void:
	if cards.size() < PER_PLAYER * 2 or _nudge.size() < cards.size() or not is_inside_tree():
		return
	# The design size (the editor's own viewport would be the wrong size).
	var view := Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
			ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	for player in 2:
		var center := left_center if player == 0 else right_center
		for i in PER_PLAYER:
			var index := player * PER_PLAYER + i
			var card := cards[index]
			# Side by side, each slightly off its spot.
			var spot := center + Vector2((i - (PER_PLAYER - 1) / 2.0) * card_spacing, 0.0)
			spot += _nudge[index] * max_nudge
			# Whole pixels only: the dithered picture is shrunk a lot, and a card
			# landing between pixels samples it differently from its neighbours.
			var card_center := spot.round()
			# The card is drawn in the middle of its full-screen picture.
			var shift := card_center - view / 2.0
			var size := card_scale  # all the same size: scaling apart breaks the dithering
			card.pivot_offset = view / 2.0
			card.offset_left = shift.x
			card.offset_right = shift.x
			card.offset_top = shift.y
			card.offset_bottom = shift.y
			card.rotation = 0.0
			card.scale = Vector2.ONE * size
			card.modulate = Color.WHITE
			# Chosen in an earlier round of this match: stays, but can't be chosen.
			var available := not _used[player].has(i)
			if index < _buttons.size():
				var button := _buttons[index]
				if available or unavailable_texture == null:
					button.texture = button_textures[i] if i < button_textures.size() else null
					button.size = Vector2.ONE * button_size
				else:
					button.texture = unavailable_texture
					button.size = Vector2.ONE * unavailable_size
				button.position = (card_center + Vector2(0.0, button_offset)
						- button.size / 2.0).round()


## Hiding a CanvasLayer does not hide the CanvasLayers nested in it.
func _set_shown(shown: bool) -> void:
	visible = shown
	for nested in find_children("*", "CanvasLayer", true, false):
		nested.visible = shown
