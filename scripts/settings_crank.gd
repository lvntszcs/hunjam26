extends PixelButton
## The settings crank in the menu: each click toggles between the normal
## texture and [member pressed_texture], and shows [member buttons] only
## while it is on. Only its visible pixels are clickable (see PixelButton).

## Emitted on every click with the new state.
signal toggled(on: bool)

## Shown while the crank is switched on.
@export var pressed_texture: Texture2D
## Shown only while the crank is on (any node with a "visible" property,
## e.g. the Buttons CanvasLayer). Children of this node are included too.
@export var buttons: Array[Node] = []

var is_on := false
var _normal_texture: Texture2D


func _ready() -> void:
	super._ready()
	_normal_texture = texture
	_update_buttons()


func _on_pressed() -> void:
	set_on(not is_on)


func set_on(on: bool) -> void:
	is_on = on
	texture = pressed_texture if on and pressed_texture else _normal_texture
	_update_buttons()
	toggled.emit(is_on)


func _update_buttons() -> void:
	for node in buttons:
		if node and "visible" in node:
			node.visible = is_on
	for child in get_children():
		var item := child as CanvasItem
		if item:
			item.visible = is_on
