class_name PostFx
extends CanvasLayer
## Full-screen post-process layer (pixel wobble + grain, see
## shaders/pixel_wobble.gdshader). Proof of concept: the toggle key switches it
## on and off so it can be compared in the running game.

@export var toggle_key: Key = KEY_F2


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == toggle_key:
		visible = not visible
		print("PostFx: %s" % ("on" if visible else "off"))
		get_viewport().set_input_as_handled()
