class_name KnockingMachine
extends TextureRect
## The prank left at the door: a knocking machine (the Knocker's auto-knocker
## modifier card).
##
## If Granny looks through the peephole while it knocks, it gives itself away:
## [method break_down] stops it and it topples over, broken. She sees it lying
## there through the peephole only ([member peephole_copy]), then it slides
## away out of the view; opening the door
## finds nothing (it is gone from the room and corridor views) until it is
## taken away when the door closes (or the round ends).
##
## While shown (from [method Doorway.place_prank] until the door closes) it
## keeps knocking: a random rhythm from its KnockPlayer child, a pause, the
## next rhythm... On every hit it flips to the second frame for a moment.
## Once the inside player has stepped out (its view, the parent CanvasLayer,
## is shown) it falls silent and stands still.
## The pictures are full-screen, so this node covers the whole view.

## [0] = resting, [1] = hitting.
@export var frames: Array[Texture2D] = []
## Seconds the hitting frame stays on per knock.
@export var hit_frame_time := 0.1
## Random pause between two rhythms (seconds).
@export var pause_min := 0.6
@export var pause_max := 1.5
## The same machine drawn in other views (e.g. behind the opening door in
## the room, through the peephole). They follow this node's picture,
## visibility and toppling.
@export var copies: Array[TextureRect] = []
## The copy seen through the peephole: the only view that still shows the
## machine once it is broken.
@export var peephole_copy: TextureRect
## Where the machine stands in its (full-screen, 1280x720) picture: it
## topples over around this point.
@export var foot_point := Vector2(638, 670)
## How far it tips over when it breaks (degrees) and how long that takes.
@export var broken_tilt := 38.0
@export var break_time := 0.35
## After toppling it lies there for [member leave_delay] seconds, then slides
## down out of the view in [member leave_time] seconds.
@export var leave_delay := 0.4
@export var leave_time := 0.6

## True once it gave itself away (see [method break_down]).
var broken := false
var _break_tween: Tween

var _running := false
## Bumped by every start/stop, so an older knocking loop knows to stop.
var _generation := 0
## Bumped by every hit, so only the latest hit switches back to resting.
var _hit := 0

@onready var _knock_player: KnockPlayer = $KnockPlayer
## The corridor view: shown once the inside player has stepped out.
@onready var _view := get_parent() as CanvasLayer


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_knock_player.knocked.connect(_on_knocked)
	visibility_changed.connect(_on_visibility_changed)
	if _view:
		_view.visibility_changed.connect(_on_visibility_changed)
	for copy in copies:
		if copy:
			copy.mouse_filter = MOUSE_FILTER_IGNORE
	_show_frame(0)
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	for copy in copies:
		if copy:
			copy.visible = visible
	if not visible:
		_mend()
	var stepped_out := _view != null and _view.visible
	if visible and not stepped_out and not broken:
		_start()
	else:
		_stop()


## True while it is out there knocking (placed and not broken).
func is_active() -> bool:
	return visible and not broken


## Seen through the peephole: it stops knocking and topples over, broken.
## With [param in_every_view] (the door was opened on it) it topples over in
## every view instead of vanishing from all but the peephole.
func break_down(in_every_view := false) -> void:
	if broken or not visible:
		return
	broken = true
	_stop()
	Sfx.play(Sfx.MACHINE_BREAK)
	if _break_tween:
		_break_tween.kill()
	_break_tween = create_tween().set_parallel()
	for rect in _all_rects():
		rect.pivot_offset = foot_point
		_break_tween.tween_property(rect, "rotation", deg_to_rad(broken_tilt), break_time) 				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		# Then away, down out of the view.
		_break_tween.tween_property(rect, "position:y", rect.position.y + rect.size.y, leave_time) 				.set_delay(break_time + leave_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Opening the door finds nothing: gone from every view but the peephole.
		if rect != peephole_copy and not in_every_view:
			rect.self_modulate.a = 0.0


## Back to new (taken away when the door closes or the round ends).
func _mend() -> void:
	broken = false
	if _break_tween:
		_break_tween.kill()
	for rect in _all_rects():
		rect.rotation = 0.0
		rect.position.y = 0.0
		rect.self_modulate.a = 1.0


func _all_rects() -> Array[TextureRect]:
	var rects: Array[TextureRect] = [self]
	for copy in copies:
		if copy:
			rects.append(copy)
	return rects


func _start() -> void:
	if _running:
		return
	_running = true
	_generation += 1
	var generation := _generation
	while generation == _generation:
		if _knock_player.patterns.is_empty():
			return
		var pattern: Array = _knock_player.patterns.pick_random()
		_knock_player.play_pattern(pattern)
		var length := _knock_player.pattern_length(pattern)
		await get_tree().create_timer(length + randf_range(pause_min, pause_max), false).timeout


func _stop() -> void:
	_running = false
	_generation += 1
	_knock_player.stop()
	_show_frame(0)


func _on_knocked(_hit_index: int) -> void:
	_hit += 1
	var hit := _hit
	_show_frame(1)
	await get_tree().create_timer(hit_frame_time, false).timeout
	if hit == _hit:
		_show_frame(0)


func _show_frame(index: int) -> void:
	if index < frames.size() and frames[index]:
		texture = frames[index]
		for copy in copies:
			if copy:
				copy.texture = frames[index]
