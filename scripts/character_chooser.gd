class_name CharacterChooser
extends CanvasLayer
## Character select screen shown after the start page.
##
## Each player slides their controller picture between three slots: where
## the two pictures start (left and right) and halfway between them.
## Player 1 uses A / D, player 2 the arrow keys.
##
## S (player 1) / Down (player 2) locks the character under the picture:
## only the left and right slots hold a character, and a character can be
## locked by one player only (first come, first served). Pressing it again
## unlocks. Enter confirms once both players are locked.

## Emitted when Enter is pressed; the game starts after this.
signal confirmed

## Player 1's picture (A / D). Defaults to the "Controller" child.
@export var controller_one: Control
## Player 2's picture (arrow keys). Defaults to the "Controller2" child.
@export var controller_two: Control
## Seconds a picture takes to slide to the next slot.
@export var move_time := 0.12
## Tint of a picture while its player has locked a character.
@export var locked_color := Color("#551822")

## The three slot x positions, left to right.
var _slots: Array[float] = []
## Slot index (0, 1, 2) of each player's picture.
var _slot_of: Array[int] = [0, 2]
var _tweens: Array[Tween] = [null, null]
## Whether each player has locked the character under their picture.
var _locked: Array[bool] = [false, false]


func _ready() -> void:
	if controller_one == null:
		controller_one = get_node_or_null("Controller") as Control
	if controller_two == null:
		controller_two = get_node_or_null("Controller2") as Control
	set_process_unhandled_input(false)
	if controller_one == null or controller_two == null:
		push_warning("CharacterChooser: Controller and Controller2 are both needed")
		return
	var one_x := controller_one.position.x
	var two_x := controller_two.position.x
	_slots = [minf(one_x, two_x), (one_x + two_x) / 2.0, maxf(one_x, two_x)]
	if one_x > two_x:
		_slot_of = [2, 0]


## Shows the screen and starts listening to the keys.
func open() -> void:
	_set_shown(true)
	set_process_unhandled_input(true)


## Hides the screen and stops listening to the keys.
func close() -> void:
	_set_shown(false)
	set_process_unhandled_input(false)


## The slot (0 = left, 1 = middle, 2 = right) player [param player] chose.
func slot_of(player: int) -> int:
	return _slot_of[player]


func _unhandled_input(event: InputEvent) -> void:
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
				confirmed.emit()
		_:
			return
	get_viewport().set_input_as_handled()


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
	var picture := controller_one if player == 0 else controller_two
	picture.modulate = locked_color if locked else Color.WHITE


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


## Hiding a CanvasLayer does not hide the CanvasLayers nested in it.
func _set_shown(shown: bool) -> void:
	visible = shown
	for nested in find_children("*", "CanvasLayer", true, false):
		nested.visible = shown
