extends Camera2D

@export var duration := 0.6

var home_position: Vector2

func _ready():
	home_position = get_viewport_rect().size / 2
	position = home_position

func move_to(target: Vector2, target_zoom: Vector2) -> Tween:
	var t = create_tween().set_parallel()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "position", target, duration)
	t.tween_property(self, "zoom", target_zoom, duration)
	return t

func go_close(target: Vector2, close_zoom_opt: Vector2) -> Tween:
	return move_to(target, close_zoom_opt)

func go_back() -> Tween:
	return move_to(home_position, Vector2.ONE)

func snap_back():
	position = home_position
	zoom = Vector2.ONE
