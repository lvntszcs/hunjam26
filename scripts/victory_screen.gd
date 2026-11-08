class_name VictoryScreen
extends CanvasLayer
## Shown when a best-of match is won: the winner stands in the middle with
## confetti raining on them (looping frames). Cross (bottom face button),
## Enter, Space or a click continues ([signal continued]).

## The player pressed to go on (once per showing).
signal continued

## The winner's picture (full-screen art, moved so the figure is centred).
@export var winner: TextureRect
## The confetti over the winner (full-screen frames).
@export var confetti: TextureRect
@export var confetti_frames: Array[Texture2D] = []
@export var confetti_fps := 10.0
@export var granny_texture: Texture2D
@export var knocker_texture: Texture2D
## How far each picture is moved so its figure stands in the middle (the
## figures are not centred in their pictures).
@export var granny_shift := Vector2(92, 0)
@export var knocker_shift := Vector2(-120, 0)
## Seconds before a press continues (so a press meant for the game doesn't
## skip the screen).
@export var min_show_time := 1.0

var _frame := 0
var _frame_time := 0.0
var _shown_for := 0.0
var _done := false


func _ready() -> void:
	if winner == null:
		winner = get_node_or_null("Winner") as TextureRect
	if confetti == null:
		confetti = get_node_or_null("Confetti") as TextureRect
	set_process(false)
	set_process_input(false)


## Shows the screen with Granny ([param granny] true) or the Knocker as the
## winner.
func show_winner(granny: bool) -> void:
	if winner:
		winner.texture = granny_texture if granny else knocker_texture
		var shift := granny_shift if granny else knocker_shift
		winner.offset_left = shift.x
		winner.offset_right = shift.x
		winner.offset_top = shift.y
		winner.offset_bottom = shift.y
	_frame = 0
	_frame_time = 0.0
	_shown_for = 0.0
	_done = false
	_show_frame()
	show()
	set_process(true)
	set_process_input(true)


func close() -> void:
	hide()
	set_process(false)
	set_process_input(false)


func _process(delta: float) -> void:
	_shown_for += delta
	if confetti_frames.is_empty() or confetti_fps <= 0.0:
		return
	_frame_time += delta
	var frame_length := 1.0 / confetti_fps
	while _frame_time >= frame_length:
		_frame_time -= frame_length
		_frame = (_frame + 1) % confetti_frames.size()
		_show_frame()


func _show_frame() -> void:
	if confetti and not confetti_frames.is_empty():
		confetti.texture = confetti_frames[_frame % confetti_frames.size()]


func _input(event: InputEvent) -> void:
	if _done or _shown_for < min_show_time:
		return
	var go := false
	var pad := event as InputEventJoypadButton
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if pad and pad.pressed and pad.button_index == JOY_BUTTON_A:
		go = true
	elif key and key.pressed and not key.echo and key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		go = true
	elif click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		go = true
	if go:
		_done = true
		get_viewport().set_input_as_handled()
		continued.emit()
