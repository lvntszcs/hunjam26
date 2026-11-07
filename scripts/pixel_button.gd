class_name PixelButton
extends TextureRect
## A clickable picture whose clickable area is its visible pixels only.
##
## Menu pictures are full-screen and mostly transparent, so a plain
## TextureRect would catch clicks meant for whatever lies under its empty
## parts. This one lets those clicks through and emits [signal pressed] when
## its visible part is clicked.

signal pressed

## Pixels at least this opaque count as part of the button.
@export_range(0.0, 1.0) var alpha_threshold := 0.5

var _image: Image
var _image_source: Texture2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_on_pressed()
		pressed.emit()
		accept_event()


## Override to react to a click before [signal pressed] is emitted.
func _on_pressed() -> void:
	pass


## Only the visible pixels are clickable.
func _has_point(point: Vector2) -> bool:
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return false
	var image := _get_image()
	if image == null:
		return Rect2(Vector2.ZERO, size).has_point(point)
	# The texture is stretched over the whole rect (expand_mode ignores size).
	var pixel := Vector2i((point / size) * Vector2(image.get_size()))
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height():
		return false
	return image.get_pixelv(pixel).a >= alpha_threshold


func _get_image() -> Image:
	if _image_source != texture:
		_image_source = texture
		_image = texture.get_image()
		if _image and _image.is_compressed():
			_image.decompress()
	return _image
