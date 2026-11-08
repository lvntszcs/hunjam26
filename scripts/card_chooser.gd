@tool
class_name CardChooser
extends CanvasLayer
## Card select screen, shown after the character select.
##
## Three cards on the left for player 1 and three on the right for player 2,
## each set laid out in a row, every card a little askew so they look put
## down by hand. A player moves between their own cards
## (player 1: A / D, player 2: arrow keys); the card they are on is lifted
## and enlarged. S (player 1) / Down (player 2) locks it, pressing again
## unlocks. Enter confirms once both players have locked a card.
##
## The cards are laid out by this script (also in the editor): change the
## rows with the exports below, not by moving the cards.

## Emitted when Enter is pressed with both cards locked.
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
## Each card is turned by a random angle up to this much either way (degrees),
## so the row doesn't look machine-placed.
@export var max_tilt_degrees := 2.5:
	set(value):
		max_tilt_degrees = value
		_layout(true)
## Each card is nudged by a random amount up to this much (design pixels).
@export var max_nudge := Vector2(4, 6):
	set(value):
		max_nudge = value
		_layout(true)
## Size of a card (1 = as drawn on the full-screen picture).
@export var card_scale := 0.55:
	set(value):
		card_scale = value
		_layout(true)
## The card a player is on: this much bigger and lifted this many pixels.
@export var hover_scale := 1.15
@export var hover_lift := 40.0
@export var move_time := 0.12
## Tint of a card once its player has locked it.
@export var locked_color := Color("#551822")

## Index (0..2) of the card each player is on, within their own three.
var _choice: Array[int] = [1, 1]
var _locked: Array[bool] = [false, false]
var _tweens: Array[Tween] = []
## Per card: a fixed random value in -1..1 for the tilt, and for the nudge.
var _tilt: Array[float] = []
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
		_tilt.append(randf_range(-1.0, 1.0))
		_nudge.append(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)))
	_layout(true)


## Shows the screen and starts listening to the keys.
func open() -> void:
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
			_set_locked(0, not _locked[0])
		KEY_DOWN:
			_set_locked(1, not _locked[1])
		KEY_ENTER, KEY_KP_ENTER:
			if is_ready():
				confirmed.emit()
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


func _set_locked(player: int, locked: bool) -> void:
	if cards.size() < PER_PLAYER * 2:
		return
	_locked[player] = locked
	_layout(false)


## Places every card in its row; the chosen ones lifted and enlarged.
## [param instant] skips the slide (first layout, editor).
func _layout(instant: bool) -> void:
	if cards.size() < PER_PLAYER * 2 or _tilt.size() < cards.size() or not is_inside_tree():
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
		var center := left_center if player == 0 else right_center
		for i in PER_PLAYER:
			var index := player * PER_PLAYER + i
			var card := cards[index]
			var chosen := i == _choice[player] and not Engine.is_editor_hint()
			# Side by side, each slightly askew and off its spot.
			var angle := deg_to_rad(max_tilt_degrees) * _tilt[index]
			var spot := center + Vector2((i - (PER_PLAYER - 1) / 2.0) * card_spacing, 0.0)
			spot += _nudge[index] * max_nudge
			var lift := Vector2(0.0, -hover_lift if chosen else 0.0)
			var card_center := spot + lift
			# The card is drawn in the middle of its full-screen picture.
			var shift := card_center - view / 2.0
			var size := card_scale * (hover_scale if chosen else 1.0)
			var tint := locked_color if chosen and _locked[player] else Color.WHITE
			card.pivot_offset = view / 2.0
			card.z_index = 1 if chosen else 0
			if instant:
				card.offset_left = shift.x
				card.offset_right = shift.x
				card.offset_top = shift.y
				card.offset_bottom = shift.y
				card.rotation = angle
				card.scale = Vector2.ONE * size
				card.modulate = tint
			else:
				var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(card, "offset_left", shift.x, move_time)
				tween.tween_property(card, "offset_right", shift.x, move_time)
				tween.tween_property(card, "offset_top", shift.y, move_time)
				tween.tween_property(card, "offset_bottom", shift.y, move_time)
				tween.tween_property(card, "rotation", angle, move_time)
				tween.tween_property(card, "scale", Vector2.ONE * size, move_time)
				tween.tween_property(card, "modulate", tint, move_time)
				_tweens.append(tween)


## Hiding a CanvasLayer does not hide the CanvasLayers nested in it.
func _set_shown(shown: bool) -> void:
	visible = shown
	for nested in find_children("*", "CanvasLayer", true, false):
		nested.visible = shown
