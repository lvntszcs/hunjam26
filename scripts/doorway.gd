class_name Doorway
extends Node
## The door and what the players see around it: camera moves, fades, the
## peephole view, the corridor behind the open door and the prank in it.
##
## Pure presentation and door state; game rules live in Main and the roles.

## Emitted the moment the door starts to open.
signal opening
## Emitted once the door has fully closed again.
signal closed

## Ennyi másodperc után csukódik be magától a nyitott ajtó.
@export var open_duration := 2.0
@export var camera: CameraController
@export var fader: ScreenFader
## The camera zooms onto the centre of this control when approaching the peephole.
@export var peephole_target: Control
@export var peephole_view: CanvasLayer
@export var corridor_view: CanvasLayer
@export var prank: CanvasItem
@export var doorknob_target: Control

@export var close_zoom := Vector2(10, 10)
@export var close_zoom_knob := Vector2(2, 2)
## True from the start of opening until the door has fully closed.
var is_open := false
var _close_timer: SceneTreeTimer


func approach_peephole() -> void:
	await camera.go_close(peephole_target.get_global_rect().get_center(),close_zoom).finished
	await fader.fade_to(1.0)
	peephole_view.show()
	await fader.fade_to(0.0)

## Zooms onto the door knob. Only a camera move: the door stays closed.
func approach_doorknob() -> void:
	await camera.go_close(doorknob_target.get_global_rect().get_center(), close_zoom_knob).finished


func leave_doorknob() -> void:
	await camera.go_back().finished


func leave_peephole() -> void:
	await fader.fade_to(1.0)
	peephole_view.hide()
	await fader.fade_to(0.0)
	await camera.go_back().finished


## Opens the door; returns once the corridor is visible. The door then closes
## by itself after [member open_duration] and emits [signal closed].
func open() -> void:
	is_open = true
	opening.emit()
	await fader.fade_to(1.0)
	peephole_view.hide()
	corridor_view.show()
	await fader.fade_to(0.0)
	_close_after_delay()


func place_prank() -> void:
	prank.show()


func close_time_left() -> float:
	return _close_timer.time_left if _close_timer else 0.0


func _close_after_delay() -> void:
	_close_timer = get_tree().create_timer(open_duration, false)
	await _close_timer.timeout
	_close_timer = null
	await fader.fade_to(1.0)
	corridor_view.hide()
	prank.hide()  # nyitás után a csali resetel
	camera.snap_back()  # ha kukucskálásból nyitottunk, a kamera még ráközelített
	await fader.fade_to(0.0)
	is_open = false
	closed.emit()
