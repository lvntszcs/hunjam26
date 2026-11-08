class_name StartPage
extends CanvasLayer
## The main menu, with its gamepad controls (PlayStation layout):
##
## - Cross (bottom face button): the same as clicking PLAY.
## - Circle (right face button): zooms in on the settings box (opening it) or
##   back out to the menu as it was.
## - While zoomed in: D-pad up / down picks the upper (SFX) or the lower
##   (MUSIC) knob, D-pad left / right turns it down / up, which sets that
##   bus's volume.

## Clicking PLAY; Cross presses it too.
@export var start_button: PixelButton
## The settings box; zooming in opens it, zooming out puts it back as it was.
@export var crank: Node
## The upper knob (SFX volume) and the lower one (MUSIC volume).
@export var sfx_knob: Control
@export var music_knob: Control

@export_group("Zoom")
## The point of the menu (design pixels) put in the middle of the screen when
## zoomed in: the settings box.
@export var panel_focus := Vector2(952, 262)
@export var panel_zoom := 2.6
@export var zoom_time := 0.45

@export_group("Volume")
@export var sfx_bus: StringName = &"SFX"
@export var music_bus: StringName = &"Music"
## How much one D-pad press changes a volume (volume goes from 0 to 1).
@export_range(0.01, 0.5, 0.01) var volume_step := 0.1
## The knob's turn at the lowest / highest volume, in degrees from upright.
@export var knob_min_angle := -135.0
@export var knob_max_angle := 135.0
## Middle of the knob in its (full-screen) picture, the point it turns around.
@export var knob_center := Vector2(993, 247)
## Seconds a knob takes to turn to its new place.
@export var knob_turn_time := 0.12
## Picking a knob (and zooming in) gives it a little twist back and forth, so
## you see which one is picked (no tint: the art has two tones only).
@export var pick_wiggle_angle := 12.0
@export var pick_wiggle_time := 0.3

var zoomed := false
## 0 = SFX (upper), 1 = MUSIC (lower).
var _picked := 0
var _crank_was_on := false
var _zoom_tween: Tween
var _knob_tweens: Array[Tween] = [null, null]


func _ready() -> void:
	if start_button == null:
		start_button = get_node_or_null("Start") as PixelButton
	if crank == null:
		crank = get_node_or_null("Settings")
	if sfx_knob == null:
		sfx_knob = get_node_or_null("Buttons/SoundButton") as Control
	if music_knob == null:
		music_knob = get_node_or_null("Buttons/MusicButton") as Control
	for bus in [sfx_bus, music_bus]:
		_ensure_bus(bus)
	for index in 2:
		var knob := _knob(index)
		if knob:
			knob.pivot_offset = knob_center
			knob.rotation_degrees = _angle_for(_volume(index))
	visibility_changed.connect(_on_visibility_changed)
	# Every clickable picture in the menu (play, the crank, the knobs) clicks.
	for button in find_children("*", "PixelButton", true, false):
		(button as PixelButton).pressed.connect(func() -> void: Sfx.play(Sfx.BUTTON_PRESS))


## _input, not _unhandled_input: main claims an unassigned gamepad on its
## first press (and swallows it) in its own _input, which runs after this.
func _input(event: InputEvent) -> void:
	var button := event as InputEventJoypadButton
	if button == null or not button.pressed or not visible:
		return
	match button.button_index:
		JOY_BUTTON_A:  # Cross
			if not zoomed and start_button:
				start_button.pressed.emit()
		JOY_BUTTON_B:  # Circle
			Sfx.play(Sfx.BUTTON_PRESS)
			set_zoomed(not zoomed)
		JOY_BUTTON_DPAD_UP:
			if zoomed:
				_pick(0)
		JOY_BUTTON_DPAD_DOWN:
			if zoomed:
				_pick(1)
		JOY_BUTTON_DPAD_LEFT:
			if zoomed:
				_change_volume(_picked, -volume_step)
		JOY_BUTTON_DPAD_RIGHT:
			if zoomed:
				_change_volume(_picked, volume_step)


## Shows the menu again (e.g. after a game), with the settings box's knobs
## shown only if it is open.
func open() -> void:
	show()
	for layer in _layers():
		if layer != self:
			layer.visible = crank == null or not ("is_on" in crank) or crank.is_on


## Zooms in on the settings box (opening it) or back out.
func set_zoomed(on: bool) -> void:
	if on == zoomed:
		return
	zoomed = on
	if crank and "is_on" in crank:
		if on:
			_crank_was_on = crank.is_on
			if not crank.is_on:
				crank.set_on(true)
		elif crank.is_on != _crank_was_on:
			crank.set_on(_crank_was_on)
	if on:
		_wiggle(_picked)
	var view := Vector2(1280, 720)
	var target_scale := Vector2.ONE * (panel_zoom if on else 1.0)
	var target_offset := (view / 2.0 - panel_focus * panel_zoom) if on else Vector2.ZERO
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Nested CanvasLayers (the knobs) don't follow this layer: zoom each.
	for layer in _layers():
		_zoom_tween.tween_property(layer, "scale", target_scale, zoom_time)
		_zoom_tween.tween_property(layer, "offset", target_offset, zoom_time)


func _pick(index: int) -> void:
	_picked = index
	_wiggle(index)


func _change_volume(index: int, delta: float) -> void:
	var bus := AudioServer.get_bus_index(_bus_name(index))
	if bus < 0:
		return
	var volume := clampf(snappedf(_volume(index) + delta, volume_step), 0.0, 1.0)
	AudioServer.set_bus_volume_linear(bus, volume)
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	var knob := _knob(index)
	if knob == null:
		return
	if not is_equal_approx(knob.rotation_degrees, _angle_for(volume)):
		Sfx.play_random(Sfx.KNOB_TURNS)
	if _knob_tweens[index]:
		_knob_tweens[index].kill()
	_knob_tweens[index] = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_knob_tweens[index].tween_property(knob, "rotation_degrees", _angle_for(volume), knob_turn_time)


## Linear volume (0..1) of the bus of knob [param index].
func _volume(index: int) -> float:
	var bus := AudioServer.get_bus_index(_bus_name(index))
	if bus < 0 or AudioServer.is_bus_mute(bus):
		return 0.0
	return clampf(AudioServer.get_bus_volume_linear(bus), 0.0, 1.0)


func _angle_for(volume: float) -> float:
	return lerpf(knob_min_angle, knob_max_angle, volume)


## A short twist of knob [param index] around its volume's angle.
func _wiggle(index: int) -> void:
	var knob := _knob(index)
	if knob == null:
		return
	Sfx.play_random(Sfx.KNOB_TURNS)
	if _knob_tweens[index]:
		_knob_tweens[index].kill()
	var rest := _angle_for(_volume(index))
	var step := pick_wiggle_time / 4.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(knob, "rotation_degrees", rest + pick_wiggle_angle, step)
	tween.tween_property(knob, "rotation_degrees", rest - pick_wiggle_angle, step * 2.0)
	tween.tween_property(knob, "rotation_degrees", rest, step)
	_knob_tweens[index] = tween


func _knob(index: int) -> Control:
	return sfx_knob if index == 0 else music_knob


func _bus_name(index: int) -> StringName:
	return sfx_bus if index == 0 else music_bus


## This layer and the CanvasLayers nested in it.
func _layers() -> Array[CanvasLayer]:
	var layers: Array[CanvasLayer] = [self]
	for nested in find_children("*", "CanvasLayer", true, false):
		layers.append(nested as CanvasLayer)
	return layers


## Leaving the menu: back to the normal view for next time.
func _on_visibility_changed() -> void:
	if visible or not zoomed:
		return
	zoomed = false
	if _zoom_tween:
		_zoom_tween.kill()
	for layer in _layers():
		layer.scale = Vector2.ONE
		layer.offset = Vector2.ZERO


## Adds [param bus] (sending to Master) if the bus layout lacks it.
static func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")
