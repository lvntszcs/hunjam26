class_name Knocker
extends Node
## The knocker standing outside the door (dummy art for now).
##
## The outside is drawn in several views (behind the opening door in the room,
## through the peephole, the corridor once you step out), so there is one
## figure per view. [member presence] (0 = gone, 1 = in place) drives all of
## them together: they slide in from the right and back out.

## One figure per outside view; all move together.
@export var figures: Array[Control] = []
## How far off to the right the figures wait while away (design pixels).
@export var slide_distance := 1280.0
@export var slide_in_duration := 0.35
## Used by [method slide_out] when no duration is given.
@export var slide_out_duration := 1.5

## 0 = fully away, 1 = standing in front of the door.
var presence := 0.0:
	set = set_presence

var _rest_offsets: Array[Vector2] = []  # (offset_left, offset_right) per figure
var _tween: Tween


func _ready() -> void:
	for figure in figures:
		_rest_offsets.append(Vector2(figure.offset_left, figure.offset_right))
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_presence(0.0)


func set_presence(value: float) -> void:
	presence = clampf(value, 0.0, 1.0)
	if _rest_offsets.size() != figures.size():
		return  # not ready yet
	# Shift the offsets (not position), so anchoring keeps working on resize.
	var shift := (1.0 - presence) * slide_distance
	for i in figures.size():
		figures[i].offset_left = _rest_offsets[i].x + shift
		figures[i].offset_right = _rest_offsets[i].y + shift
		figures[i].visible = presence > 0.0


func is_present() -> bool:
	return presence > 0.0


## Slides in quickly (from wherever it currently is).
func slide_in() -> void:
	_slide_to(1.0, slide_in_duration, Tween.EASE_OUT)


## Slides out slowly; [param duration] defaults to [member slide_out_duration].
func slide_out(duration: float = -1.0) -> void:
	_slide_to(0.0, duration if duration > 0.0 else slide_out_duration, Tween.EASE_IN_OUT)


## Gone immediately (e.g. when the roles are swapped).
func hide_now() -> void:
	if _tween:
		_tween.kill()
	presence = 0.0


func _slide_to(target: float, full_duration: float, ease: Tween.EaseType) -> void:
	if _tween:
		_tween.kill()
	# A partial slide (e.g. pressed again while sliding out) takes
	# proportionally less time, so the speed stays the same.
	var duration := full_duration * absf(target - presence)
	if duration <= 0.0:
		presence = target
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	_tween.tween_property(self, "presence", target, duration)
