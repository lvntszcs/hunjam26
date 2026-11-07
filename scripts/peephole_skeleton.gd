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
	var bounce := -absf(sin(_stride)) * 5.0
	draw_set_transform(Vector2(0, bounce))
	var hip := Vector2(-9, -65)
	var shoulder := Vector2(4, -109)
	_draw_leg(hip + Vector2(4, 0), _stride + PI, FAR_BONE)
	_draw_arm(shoulder + Vector2(4, 0), _stride, FAR_BONE)
	_draw_bone(hip, shoulder, FAR_BONE, 4.5)
	_draw_ribcage(hip, shoulder)
	_draw_leg(hip, _stride, BONE)
	_draw_bone(hip + Vector2(-5, -4), hip + Vector2(7, -1), BONE, 8.0)
	draw_circle(hip + Vector2(3, -3), 2.4, SHADOW)
	_draw_bone(shoulder, shoulder + Vector2(6, -11), BONE, 4.0)
	_draw_arm(shoulder, _stride + PI, BONE)
	_draw_skull(shoulder + Vector2(10, -20 + bounce))


func _draw_ribcage(hip: Vector2, shoulder: Vector2) -> void:
	for rib in range(6):
		var root := shoulder.lerp(hip, 0.1 + 0.1 * rib)
		var span := 12.0 + 7.0 * sin(float(rib) * PI / 6.0)
		var arc := PackedVector2Array([
			root + Vector2(-4, -2),
			root + Vector2(-5, 2),
			root + Vector2(1, 6),
			root + Vector2(span - 3, 5),
			root + Vector2(span, 1),
		])
		draw_polyline(arc, SHADOW, 4.0)
		draw_polyline(arc, BONE, 2.1)
		draw_circle(root, 2.0, FAR_BONE)


func _draw_leg(hip: Vector2, phase: float, color: Color) -> void:
	var swing := cos(phase)
	var thigh_angle := 0.1 + 1.02 * swing
	var knee_bend := 0.42 + 0.65 * (1.0 - swing) * 0.5 + 0.18 * sin(phase)
	var knee := hip + Vector2.DOWN.rotated(-thigh_angle) * 32.0
	var ankle := knee + Vector2.DOWN.rotated(knee_bend - thigh_angle) * 32.0
	_draw_bone(hip, knee, color, 4.0)
	_draw_bone(knee, ankle, color, 3.0)
	_draw_bone(knee + Vector2(-2, 2), ankle + Vector2(-2, 0), FAR_BONE, 1.4)
	_draw_bone(ankle, ankle + Vector2(10, 3 - 4 * swing), color, 3.0)


func _draw_arm(shoulder: Vector2, phase: float, color: Color) -> void:
	var swing := cos(phase)
	var upper_angle := -0.25 + 1.0 * swing
	var forearm := Vector2.DOWN.rotated(-(upper_angle + 1.2 + 0.22 * swing))
	var elbow := shoulder + Vector2.DOWN.rotated(-upper_angle) * 21.0
	var wrist := elbow + forearm * 19.0
	_draw_bone(shoulder, elbow, color, 3.5)
	_draw_bone(elbow, wrist, color, 2.5)
	var palm := wrist + forearm * 4.0
	_draw_bone(wrist, palm, color, 3.0)
	for finger in range(-1, 2):
		var tip := palm + forearm * 4.0 + forearm.orthogonal() * (finger * 1.8)
		draw_line(palm, tip, color, 1.2)


func _draw_bone(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, SHADOW, width + 3.0)
	draw_line(from, to, color, width)
	draw_circle(to, width * 0.52, color)


func _draw_skull(center: Vector2) -> void:
	draw_set_transform(center)
	var profile := PackedVector2Array([
		Vector2(-11, -6), Vector2(-7, -11), Vector2(1, -13), Vector2(8, -11),
		Vector2(12, -6), Vector2(11, -1), Vector2(14, 3), Vector2(11, 6),
		Vector2(10, 11), Vector2(3, 13), Vector2(-3, 9), Vector2(-4, 5),
		Vector2(-9, 3),
	])
	draw_colored_polygon(profile, BONE)
	profile.append(profile[0])
	draw_polyline(profile, SHADOW, 2.5)
	draw_circle(Vector2(6, -3), 3.6, SHADOW)
	draw_circle(Vector2(10, 3), 1.5, SHADOW)
	draw_line(Vector2(2, 8), Vector2(11, 7), SHADOW, 1.6)
	for tooth in range(3):
		var x := 4 + tooth * 2
		draw_line(Vector2(x, 6), Vector2(x, 9), SHADOW, 1.0)
