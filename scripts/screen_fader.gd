class_name ScreenFader
extends ColorRect
## Full-screen transition between views: a pixel dissolve.
##
## [code]fade_to(1.0)[/code] covers: every pixel flips from the current view to
## the cover colour, each at a random moment. [code]fade_to(0.0)[/code] reveals:
## every pixel fades from the cover colour to the new view, in a new random
## pattern. Swap what is shown while covered.

const DISSOLVE_SHADER := preload("res://shaders/pixel_dissolve.gdshader")

## Seconds for every pixel to flip to the cover colour.
@export var cover_duration := 0.3
## Seconds for every pixel to fade to the new view.
@export var reveal_duration := 0.3
## Per-pixel fade length while covering (0 = hard flip).
@export_range(0.0, 1.0) var cover_softness := 0.0
## Per-pixel fade length while revealing (0 = hard flip).
@export_range(0.0, 1.0) var reveal_softness := 0.5
## Cell size in design pixels (1 = every pixel on its own).
@export_range(1.0, 32.0) var pixel_size := 1.0:
	set(value):
		pixel_size = maxf(value, 1.0)
		_update_grid()

## 0 = clear, 1 = fully covered.
var progress := 0.0:
	set = _set_progress

var _material: ShaderMaterial


func _ready() -> void:
	_material = material as ShaderMaterial
	if _material == null or _material.shader != DISSOLVE_SHADER:
		_material = ShaderMaterial.new()
		_material.shader = DISSOLVE_SHADER
		material = _material
	_material.set_shader_parameter("cover_color", color)
	color = Color.WHITE  # the shader draws the colour
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_update_grid)
	_update_grid()
	_set_progress(progress)


## Covers ([param target] 1) or reveals ([param target] 0); returns when done.
## [param duration] defaults to [member cover_duration] / [member reveal_duration].
func fade_to(target: float, duration: float = -1.0) -> void:
	var covering := target > progress
	if duration < 0.0:
		duration = cover_duration if covering else reveal_duration
	_material.set_shader_parameter("softness", cover_softness if covering else reveal_softness)
	_material.set_shader_parameter("seed", randf() * 1000.0)  # new pattern each time
	var tween := create_tween()
	tween.tween_property(self, "progress", target, duration)
	await tween.finished


func _set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	visible = progress > 0.0
	if _material:
		_material.set_shader_parameter("progress", progress)


func _update_grid() -> void:
	if _material:
		_material.set_shader_parameter("grid", (size / pixel_size).ceil())
