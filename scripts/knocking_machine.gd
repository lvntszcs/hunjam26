class_name KnockingMachine
extends TextureRect
## The prank left at the door: a knocking machine.
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
## the room). They follow this node's picture and visibility.
@export var copies: Array[TextureRect] = []

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
	var stepped_out := _view != null and _view.visible
	if visible and not stepped_out:
		_start()
	else:
		_stop()


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
		var length := float(pattern[-1]) if not pattern.is_empty() else 0.0
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
