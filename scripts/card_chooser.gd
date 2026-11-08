@tool
class_name CardChooser
extends CanvasLayer
## Card select screen, shown after the character select.
##
## Three cards on the left for player 1 and three on the right for player 2,
## each set laid out in a row, every card nudged a little off its spot so
## they look put down by hand. A player moves between their own cards
## (player 1: A / D, player 2: arrow keys); the card they are on is lifted.
## S (player 1) / Down (player 2) chooses it: that player's cards slide out
## of the screen, and once both players' cards are gone the screen confirms.
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
## Size of a card (1 = as drawn on the full-screen picture).
@export var card_scale := 0.55:
	set(value):
		card_scale = value
		_layout(true)
## The card a player is on is lifted this many pixels.
@export var hover_lift := 40.0
@export var move_time := 0.12
## Seconds after choosing before the cards slide away. The chosen card is
## not marked in any way: the choice is a secret from the other player.
@export var leave_delay := 0.2
## Seconds the cards take to slide out of the screen (down).
@export var leave_time := 0.45

## Index (0..2) of the card each player is on, within their own three.
var _choice: Array[int] = [1, 1]
var _locked: Array[bool] = [false, false]
var _tweens: Array[Tween] = []
## Per player: the slide out of the screen, and whether it has finished.
var _leave_tweens: Array[Tween] = [null, null]
var _gone: Array[bool] = [false, false]
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


## Hides the screen and stops listening to the keys.
func close() -> void:
	_set_shown(false)
	set_process_unhandled_input(false)


## The card (0..2, left to right within their own fan) player
## [param player] locked.
func card_of(player: int) -> int:
	return _choice[player]


## True once both players have locked a card.
func is_ready() -> bool:
	return _locked[0] and _locked[1]


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
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
			_choose(0)
		KEY_DOWN:
			_choose(1)
		_:
			return
	get_viewport().set_input_as_handled()


## Moves [param player] one card in [param direction] (-1 or 1) within
## their own fan. A locked choice stays where it is.
func _step(player: int, direction: int) -> void:
	if _locked[player]:
		return
	var choice := clampi(_choice[player] + direction, 0, PER_PLAYER - 1)
	if choice == _choice[player]:
		return
	_choice[player] = choice
	_layout(false)


## [param player] chooses the card they are on (final): their cards
## slide out of the screen.
func _choose(player: int) -> void:
	if cards.size() < PER_PLAYER * 2 or _locked[player]:
		return
	_locked[player] = true
	_layout(false)
	_leave(player)


## Slides [param player]'s cards down out of the screen; confirms once both
## players' cards are gone.
func _leave(player: int) -> void:
	var view_height: float = ProjectSettings.get_setting("display/window/size/viewport_height", 720)
	# The lift settles first (other layouts skip this player from here).
	var wait := create_tween()
	wait.tween_interval(leave_delay)
	_leave_tweens[player] = wait
	await wait.finished
	if _leave_tweens[player] != wait:
		return  # the screen was opened again meanwhile
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	# Far enough for the lifted card (drawn in the middle of its picture).
	var drop := view_height + hover_lift
	for i in PER_PLAYER:
		var card := cards[player * PER_PLAYER + i]
		tween.tween_property(card, "offset_top", card.offset_top + drop, leave_time).set_delay(i * 0.04)
		tween.tween_property(card, "offset_bottom", card.offset_bottom + drop, leave_time).set_delay(i * 0.04)
	_leave_tweens[player] = tween
	await tween.finished
	if _leave_tweens[player] != tween:
		return
	_gone[player] = true
	if _gone[0] and _gone[1] and visible:
		confirmed.emit()


## Places every card in its row; the chosen ones lifted.
## [param instant] skips the slide (first layout, editor).
func _layout(instant: bool) -> void:
	if cards.size() < PER_PLAYER * 2 or _nudge.size() < cards.size() or not is_inside_tree():
		return
	for tween in _tweens:
		if tween:
			tween.kill()
	_tweens.clear()
	# The design size (the editor's own viewport would be the wrong size).
	var view := Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
			ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	for player in 2:
		if _leave_tweens[player] and not instant:
			continue  # chose already: its cards are leaving (or gone)
		var center := left_center if player == 0 else right_center
		for i in PER_PLAYER:
			var index := player * PER_PLAYER + i
			var card := cards[index]
			var chosen := i == _choice[player] and not Engine.is_editor_hint()
			# Side by side, each slightly off its spot.
			var spot := center + Vector2((i - (PER_PLAYER - 1) / 2.0) * card_spacing, 0.0)
			spot += _nudge[index] * max_nudge
			var lift := Vector2(0.0, -hover_lift if chosen else 0.0)
			# Whole pixels only: the dithered picture is shrunk a lot, and a card
			# landing between pixels samples it differently from its neighbours.
			var card_center := (spot + lift).round()
			# The card is drawn in the middle of its full-screen picture.
			var shift := card_center - view / 2.0
			var size := card_scale  # all the same size: scaling apart breaks the dithering
			card.pivot_offset = view / 2.0
			card.z_index = 1 if chosen else 0
			if instant:
				card.offset_left = shift.x
				card.offset_right = shift.x
				card.offset_top = shift.y
				card.offset_bottom = shift.y
				card.rotation = 0.0
				card.scale = Vector2.ONE * size
				card.modulate = Color.WHITE
			else:
				var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(card, "offset_left", shift.x, move_time)
				tween.tween_property(card, "offset_right", shift.x, move_time)
				tween.tween_property(card, "offset_top", shift.y, move_time)
				tween.tween_property(card, "offset_bottom", shift.y, move_time)
				tween.tween_property(card, "scale", Vector2.ONE * size, move_time)
				_tweens.append(tween)


## Hiding a CanvasLayer does not hide the CanvasLayers nested in it.
func _set_shown(shown: bool) -> void:
	visible = shown
	for nested in find_children("*", "CanvasLayer", true, false):
		nested.visible = shown
