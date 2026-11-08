class_name CameraController
extends Camera2D
## Moves and zooms the room camera between the home view and close-ups.

@export var duration := 0.6

var home_position: Vector2


func _ready() -> void:
	# The window can change size after startup (resizing, fullscreen, the
	# editor's embedded game view). Inside scenes/game_frame.tscn the game's
	# viewport stays 1280x720 (dark-red bars fill the rest), but follow it
	# anyway in case main.tscn is run on its own.
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()
	position = home_position


## Recentres the home view on the visible area and limits the camera to it.
func _fit_to_viewport() -> void:
	var at_home := zoom.is_equal_approx(Vector2.ONE) and position.is_equal_approx(home_position)
	var view_size := get_viewport_rect().size
	home_position = view_size / 2
	# Never show anything outside the scene, even mid-zoom.
	limit_left = 0
	limit_top = 0
	limit_right = int(view_size.x)
	limit_bottom = int(view_size.y)
	if at_home:
		position = home_position


## Moves and zooms together so [param target] travels in a straight line to
## the centre of the screen (tweening position and zoom separately makes it arc).
## [param time] overrides [member duration] when not negative.
func move_to(target: Vector2, target_zoom: Vector2, time := -1.0) -> Tween:
	var start_pos := position
	var start_zoom := zoom
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(t: float) -> void: _apply_move(t, start_pos, start_zoom, target, target_zoom),
		0.0, 1.0, duration if time < 0.0 else time)
	return tween


func _apply_move(t: float, p0: Vector2, z0: Vector2, p1: Vector2, z1: Vector2) -> void:
	# Geometric zoom: each step scales by the same factor, so it reads as steady.
	zoom = Vector2(z0.x * pow(z1.x / z0.x, t), z0.y * pow(z1.y / z0.y, t))
	# The close-up point (the more zoomed end) slides in a straight line on
	# screen: towards the centre when zooming in, back out when zooming out.
	if z1.x >= z0.x:
		var offset_in := (p1 - p0) * z0 * (1.0 - t)
		position = p1 - offset_in / zoom
	else:
		var offset_out := (p0 - p1) * z1 * t
		position = p0 - offset_out / zoom


func go_close(target: Vector2, close_zoom_target: Vector2) -> Tween:
	return move_to(target, close_zoom_target)


func go_back() -> Tween:
	return move_to(home_position, Vector2.ONE)


func snap_back() -> void:
	position = home_position
	zoom = Vector2.ONE
