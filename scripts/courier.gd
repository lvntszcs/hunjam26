class_name Courier
extends TextureRect
## The courier (futár), the Knocker's modifier card: he turns up at a
## neighbour's door and knocks there. Through the wall that knock sounds
## duller than the Knocker's (the KnockPlayer child plays on the "Muffled" bus:
## a low-pass filter and a little reverb, set up in default_bus_layout.tres).
##
## If Granny opens her door to it, she loses a life (nobody is at her door);
## he stays in view until the door closes again.
## If she doesn't, he leaves after [member stay_time] seconds.
##
## The picture is full-screen (1280x720 design) and is drawn in every outside
## view: this node in the corridor, [member copies] in the others (the
## peephole, behind the opening door). [member figure_offset] and
## [member figure_scale] put him in front of the neighbour's door.

## Seconds he stays and knocks before leaving.
@export var stay_time := 5.0
## Random pause between two knock rhythms (seconds).
@export var pause_min := 0.5
@export var pause_max := 1.2
## The same courier in the other outside views.
@export var copies: Array[TextureRect] = []
## Where the picture goes (design pixels, + is right / down) and how big it
## is (1 = full screen), from its top-left corner.
@export var figure_offset := Vector2(-125, 95):
	set(value):
		figure_offset = value
		_layout()
@export_range(0.1, 2.0, 0.01) var figure_scale := 0.6:
	set(value):
		figure_scale = value
		_layout()

## Bumped by every arrival / leave, so an old knocking loop or leave timer
## does nothing.
var _generation := 0

@onready var _knock_player: KnockPlayer = $KnockPlayer


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for copy in copies:
		if copy:
			copy.mouse_filter = MOUSE_FILTER_IGNORE
			copy.texture = texture
	_layout()
	_set_shown(false)


## True while he is out there.
func is_active() -> bool:
	return visible


## He turns up and starts knocking at the neighbour's door; he leaves after
## [member stay_time] seconds. False if he is already here.
func arrive() -> bool:
	if visible:
		return false
	_generation += 1
	var generation := _generation
	_set_shown(true)
	_knock_loop(generation)
	get_tree().create_timer(stay_time, false).timeout.connect(func() -> void:
		if generation == _generation:
			leave())
	return true


## Granny opened her door to his knock: he stops knocking and stays where he
## is (seen through the open door) until [method leave] (the door closes).
func caught() -> void:
	if not visible:
		return
	_generation += 1  # no more knocks, and the leave timer does nothing
	_knock_player.stop()


## Gone at once (time is up, the door closed again, or the round ends).
func leave() -> void:
	_generation += 1
	_knock_player.stop()
	_set_shown(false)


func _knock_loop(generation: int) -> void:
	while generation == _generation:
		if _knock_player.patterns.is_empty():
			return
		var pattern: Array = _knock_player.patterns.pick_random()
		_knock_player.play_pattern(pattern)
		var length := float(pattern[-1]) if not pattern.is_empty() else 0.0
		await get_tree().create_timer(length + randf_range(pause_min, pause_max), false).timeout


func _set_shown(on: bool) -> void:
	visible = on
	for copy in copies:
		if copy:
			copy.visible = on


func _layout() -> void:
	var picture_size := Vector2(1280, 720) * figure_scale
	for rect: TextureRect in [self] + copies:
		if rect == null:
			continue
		rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
		rect.offset_left = figure_offset.x
		rect.offset_top = figure_offset.y
		rect.offset_right = figure_offset.x + picture_size.x
		rect.offset_bottom = figure_offset.y + picture_size.y
