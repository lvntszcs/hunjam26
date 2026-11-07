class_name Doorway
extends Node
## The door and what the players see around it: camera moves, fades, the
## peephole view, the corridor behind the open door and the prank in it.
##
## Pure presentation and door state; game rules live in Main and the roles.

## Emitted the moment the door starts to open.
signal opening
## Emitted when the opening first shows (the door swings half or fully open):
## from here on, whatever stands in the doorway is seen.
signal swung_open
## Emitted once the door has fully closed again.
signal closed
## Emitted once the peephole view is fully shown.
signal peephole_entered
## Emitted when leaving the peephole view starts.
signal peephole_left

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
## The door picture; its texture switches between the three phases below.
@export var door: TextureRect
@export var door_closed_texture: Texture2D
@export var door_half_open_texture: Texture2D
@export var door_open_texture: Texture2D
## The inside player's hand; reaches for the handle before the door opens.
@export var hand: Hand
## Ennyi másodpercig áll félig nyitva az ajtó.
@export var half_open_duration := 0.3
## Ennyi másodpercig látszik a folyosó a nyitott ajtón át, mielőtt kimegyünk.
@export var reveal_duration := 0.8

@export var close_zoom := Vector2(10, 10)
@export var close_zoom_knob := Vector2(2, 2)
## Kilincstől nyitva ennyi pixellel néz fel a kamera a nyitott ajtóra.
@export var knob_look_up := 280.0
## Ennyi másodperc alatt néz fel a kamera kilincstől nyitáskor.
@export var knob_look_up_duration := 0.6
## True from the start of opening until the door has fully closed.
var is_open := false
var _close_timer: SceneTreeTimer


func approach_peephole() -> void:
	await camera.go_close(peephole_target.get_global_rect().get_center(),close_zoom).finished
	await fader.fade_to(1.0)
	peephole_view.show()
	await fader.fade_to(0.0)
	peephole_entered.emit()

## Zooms onto the door knob while the hand reaches for it and keeps holding
## the handle. The door stays closed until [method open] or
## [method leave_doorknob].
func approach_doorknob() -> void:
	var move := camera.go_close(doorknob_target.get_global_rect().get_center(), close_zoom_knob)
	if hand:
		await hand.play_grab()
	if move.is_running():
		await move.finished


func leave_doorknob() -> void:
	if hand:
		hand.play_idle()  # let go of the handle
	await camera.go_back().finished


func leave_peephole() -> void:
	peephole_left.emit()
	await fader.fade_to(1.0)
	peephole_view.hide()
	await fader.fade_to(0.0)
	await camera.go_back().finished


## Opens the door; returns once the corridor is visible. The door then closes
## by itself after [member open_duration] and emits [signal closed].
## With [param from_knob] the hand already holds the handle: it just pulls,
## the camera stays close and looks up into the doorway.
func open(from_knob := false) -> void:
	is_open = true
	opening.emit()
	# Back to the room view first, so the opening door is actually visible.
	# From the knob we are already at the door: open it from right there.
	if peephole_view.visible:
		await fader.fade_to(1.0)
		peephole_view.hide()
		camera.snap_back()
		await fader.fade_to(0.0)
	elif camera.zoom != Vector2.ONE and not from_knob:
		await camera.go_back().finished
	# The hand reaches and grabs the handle (OPEN frames); its last frame pulls
	# the handle and is drawn for the half-open door, so they switch together.
	# From the knob the hand is already holding the handle: it just pulls.
	if hand:
		if from_knob:
			hand.play_pull()
		else:
			await hand.play_open()
	# Closed -> half open -> open; the corridor shows through the opening...
	door.texture = door_half_open_texture
	swung_open.emit()
	await get_tree().create_timer(half_open_duration).timeout
	door.texture = door_open_texture
	if hand:
		hand.play_idle()  # the handle swung away with the door: let go
	# Opened from the knob close-up: look up from the handle into the doorway.
	var tilt: Tween = null
	if from_knob and camera.zoom != Vector2.ONE:
		tilt = camera.move_to(camera.position + Vector2(0.0, -knob_look_up), camera.zoom,
				knob_look_up_duration)
	await get_tree().create_timer(reveal_duration).timeout
	if tilt and tilt.is_running():
		await tilt.finished
	# ...and only then do we step out.
	await fader.fade_to(1.0)
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
	door.texture = door_closed_texture
	if hand:
		hand.play_idle()
	camera.snap_back()  # ha kukucskálásból nyitottunk, a kamera még ráközelített
	await fader.fade_to(0.0)
	is_open = false
	closed.emit()
