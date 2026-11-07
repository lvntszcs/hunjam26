class_name CameraController
extends Camera2D
## Moves and zooms the room camera between the home view and close-ups.

@export var close_zoom := Vector2(10, 10)
@export var duration := 0.6

var home_position: Vector2


func _ready() -> void:
	home_position = get_viewport_rect().size / 2
	position = home_position


func move_to(target: Vector2, target_zoom: Vector2) -> Tween:
	var tween := create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target, duration)
	tween.tween_property(self, "zoom", target_zoom, duration)
	return tween


func go_close(target: Vector2) -> Tween:
	return move_to(target, close_zoom)


func go_back() -> Tween:
	return move_to(home_position, Vector2.ONE)


func snap_back() -> void:
	position = home_position
	zoom = Vector2.ONE
