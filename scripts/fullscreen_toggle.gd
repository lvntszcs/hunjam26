extends Node
## F11 toggles fullscreen everywhere in the game (autoload).
##
## In the web build the browser's own F11 never arrives: the game canvas
## takes the key. So the game handles it itself: on the web it asks the
## browser to put the canvas fullscreen (the key press counts as the user
## gesture the browser needs; the page's iframe allows fullscreen).


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F11:
		return
	var fullscreen := DisplayServer.window_get_mode() in [
			DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen
			else DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()
