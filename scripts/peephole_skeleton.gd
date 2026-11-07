extends Node2D
## One corridor run after a continuous look through the peephole.

const BONE := Color("#c4d4dd")
const FAR_BONE := Color("#a18488")
const SHADOW := Color("#301017")

@export var doorway: Doorway
@export var wait_duration := 15.0
@export var run_duration := 1.45

var _sequence: Tween
var _stride := 0.0


func _ready() -> void:
	doorway.peephole_entered.connect(_schedule_run)
	doorway.peephole_left.connect(_cancel_run)
	doorway.opening.connect(_cancel_run)


func _schedule_run() -> void:
	_cancel_run()
	_sequence = create_tween()
	_sequence.tween_interval(wait_duration)
	_sequence.tween_callback(_begin_run)
	_sequence.tween_method(_animate_run, 0.0, 1.0, run_duration)
	_sequence.tween_callback(hide)


func _cancel_run() -> void:
	if _sequence:
		_sequence.kill()
		_sequence = null
	hide()


func _begin_run() -> void:
	_animate_run(0.0)
	show()


func _animate_run(progress: float) -> void:
	var view := get_viewport_rect()
	var art_scale := view.size.y / 720.0
	var travel := view.size.x * 0.5 + 60.0 * art_scale
	position = view.get_center() + Vector2(lerpf(-travel, travel, progress), 125.0 * art_scale)
	scale = Vector2.ONE * art_scale
	_stride = progress * TAU * 5.0
	queue_redraw()


func _draw() -> void:
	var bounce := -absf(sin(_stride)) * 6.0
	draw_set_transform(Vector2(0, bounce))
	var hip := Vector2(-7, -47)
	var shoulder := Vector2(6, -87)
	_draw_leg(hip, _stride + PI, FAR_BONE)
	_draw_arm(shoulder, _stride, FAR_BONE)
	_draw_bone(hip, shoulder, BONE, 5.0)
	_draw_bone(hip + Vector2(-6, -1), hip + Vector2(8, 1), BONE, 7.0)
	for rib in range(4):
		var root := shoulder.lerp(hip, 0.17 + 0.13 * rib)
		_draw_bone(root, root + Vector2(13 - rib, 3), BONE, 3.0)
	_draw_leg(hip, _stride, BONE)
	_draw_arm(shoulder, _stride + PI, BONE)
	_draw_skull(shoulder + Vector2(8, -21))


func _draw_leg(hip: Vector2, phase: float, color: Color) -> void:
	var swing := sin(phase)
	var knee := hip + Vector2(20 * swing + 5, 22 - 11 * maxf(swing, 0.0))
	var ankle := hip + Vector2(27 * sin(phase - 0.55), 43 - 16 * maxf(swing, 0.0))
	_draw_bone(hip, knee, color, 5.0)
	_draw_bone(knee, ankle, color, 4.0)
	_draw_bone(ankle, ankle + Vector2(10, 1), color, 4.0)


func _draw_arm(shoulder: Vector2, phase: float, color: Color) -> void:
	var swing := sin(phase)
	var elbow := shoulder + Vector2(16 * swing - 5, 17)
	var hand := elbow + Vector2(14 + 6 * swing, -9 - 4 * swing)
	_draw_bone(shoulder, elbow, color, 4.0)
	_draw_bone(elbow, hand, color, 3.0)


func _draw_bone(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, SHADOW, width + 3.0)
	draw_line(from, to, color, width)
	draw_circle(to, width * 0.52, color)


func _draw_skull(center: Vector2) -> void:
	draw_rect(Rect2(center + Vector2(-5, 1), Vector2(20, 15)), SHADOW)
	draw_circle(center, 15.0, SHADOW)
	draw_circle(center, 13.0, BONE)
	draw_rect(Rect2(center + Vector2(-3, 3), Vector2(16, 11)), BONE)
	draw_circle(center + Vector2(6, -3), 4.0, SHADOW)
	draw_rect(Rect2(center + Vector2(11, 3), Vector2(3, 3)), SHADOW)
	draw_line(center + Vector2(1, 10), center + Vector2(13, 10), SHADOW, 2.0)
