extends CanvasLayer
## Always-visible debug panel docked to the right edge (debug builds only).
## Mouse-only: its controls never take keyboard/gamepad focus, so gameplay
## keys like Space can't trigger them.

const MIN_RELEASE_DELAY := 0.1
const MAX_RELEASE_DELAY := 30.0

## Door opening / hand animation pacing rows:
## [label, target ("doorway", "hand" or "camera"), property, step, min, max, value format].
const PACING_ROWS := [
	["Camera move", "camera", "duration", 0.1, 0.1, 5.0, "%.1f s"],
	["Knob look-up", "doorway", "knob_look_up_duration", 0.1, 0.1, 5.0, "%.1f s"],
	["Hand reach", "hand", "open_fps", 1.0, 1.0, 30.0, "%.0f fps"],
	["Half-open hold", "doorway", "half_open_duration", 0.05, 0.0, 3.0, "%.2f s"],
	["Corridor reveal", "doorway", "reveal_duration", 0.1, 0.0, 5.0, "%.1f s"],
	["Door stays open", "doorway", "open_duration", 0.5, 0.5, 15.0, "%.1f s"],
	["Hand idle", "hand", "idle_fps", 1.0, 1.0, 30.0, "%.0f fps"],
]
## Pixel dissolve transition rows (same format, all on the ScreenFader).
const TRANSITION_ROWS := [
	["Flip to red", "fader", "cover_duration", 0.05, 0.0, 3.0, "%.2f s"],
	["Fade to view", "fader", "reveal_duration", 0.05, 0.0, 3.0, "%.2f s"],
	["Flip softness", "fader", "cover_softness", 0.05, 0.0, 1.0, "%.2f"],
	["Fade softness", "fader", "reveal_softness", 0.05, 0.0, 1.0, "%.2f"],
	["Pixel size", "fader", "pixel_size", 1.0, 1.0, 32.0, "%.0f px"],
]

## Peephole lens (fisheye) shader rows: [label, shader parameter, step, min, max, value format].
const LENS_ROWS := [
	["Radius", "radius", 0.01, 0.05, 1.0, "%.2f"],
	["Edge softness", "softness", 0.01, 0.0, 0.5, "%.2f"],
	["Bend strength", "strength", 0.1, 0.0, 3.0, "%.1f"],
	["Bend curve", "curve", 0.25, 0.5, 6.0, "%.2f"],
	["Centre zoom", "zoom", 0.05, 0.25, 4.0, "%.2fx"],
	["Vignette", "vignette", 0.05, 0.0, 1.0, "%.2f"],
]
## Lens presets to compare quickly; "Scene" restores what main.tscn has.
const LENS_PRESETS := {
	"Flat": {"strength": 0.0, "curve": 2.0, "zoom": 1.0, "vignette": 0.2},
	"Subtle": {"strength": 0.4, "curve": 2.0, "zoom": 1.0, "vignette": 0.4},
	"Fisheye": {"strength": 1.5, "curve": 2.0, "zoom": 1.25, "vignette": 0.6},
	"Bulge": {"strength": 3.0, "curve": 3.5, "zoom": 1.6, "vignette": 0.7},
}

const LIGHT := Color(0.76862746, 0.83137256, 0.8666667)

var _doorway: Doorway
var _outside_role: OutsideRole
var _players: Array[PlayerController]
var _input_lock_time_left: Callable
var _last_joypad_events: Dictionary[int, String]
## Value label -> [getter Callable, format], refreshed every frame.
var _live_values: Dictionary[Label, Array]
## The peephole lens material and its values as loaded from the scene.
var _lens: ShaderMaterial
## Collapsible section header -> [body, title]; at most one open at a time.
var _sections: Dictionary[Button, Array]
var _lens_scene_values: Dictionary[String, float]

@onready var _status: Label = %Status
@onready var _timers: Label = %Timers
@onready var _phase_idle: Button = %PhaseIdle
@onready var _phase_knocking: Button = %PhaseKnocking
@onready var _release_delay: Label = %ReleaseDelay
@onready var _knock_button: Button = %TestKnock


func setup(
	doorway: Doorway,
	outside_role: OutsideRole,
	players: Array[PlayerController],
	input_lock_time_left: Callable,
) -> void:
	_doorway = doorway
	_outside_role = outside_role
	_players = players
	_input_lock_time_left = input_lock_time_left


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_build_property_rows(%Pacing, PACING_ROWS)
	_build_property_rows(%Transition, TRANSITION_ROWS)
	_build_lens_rows()
	_make_collapsible(%PacingTitle, %Pacing)
	_make_collapsible(%TransitionTitle, %Transition)
	_make_collapsible(%LensTitle, %Lens)


## Turns a section title into a header button that folds its rows away.
## All sections start closed; opening one closes the others.
func _make_collapsible(title: Label, body: Control) -> void:
	var header := Button.new()
	header.flat = true
	header.toggle_mode = true
	header.focus_mode = Control.FOCUS_NONE
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for color in [&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		header.add_theme_color_override(color, LIGHT)
	title.add_sibling(header)
	title.hide()
	_sections[header] = [body, title.text]
	header.toggled.connect(func(open: bool) -> void: _open_section(header if open else null))
	_open_section(null)


func _open_section(open_header: Button) -> void:
	for header: Button in _sections:
		var open := header == open_header
		var entry: Array = _sections[header]
		header.set_pressed_no_signal(open)
		header.text = ("▾ " if open else "▸ ") + entry[1]
		(entry[0] as Control).visible = open


## Rows of [label, target, property, step, min, max, format] stepping a property.
func _build_property_rows(container: Container, rows: Array) -> void:
	var targets := {"doorway": _doorway, "hand": _doorway.hand, "fader": _doorway.fader,
			"camera": _doorway.camera}
	for row: Array in rows:
		var target: Object = targets[row[1]]
		if target == null:
			continue  # e.g. no Hand node in the scene
		var property: StringName = row[2]
		_add_stepper(container, row[0],
				func() -> float: return float(target.get(property)),
				func(value: float) -> void: target.set(property, value),
				row[3], row[4], row[5], row[6])


## Live controls for the peephole fisheye shader (the Peephole/Mask material).
func _build_lens_rows() -> void:
	var mask := _doorway.peephole_view.get_node_or_null("Mask") as CanvasItem
	_lens = mask.material as ShaderMaterial if mask else null
	if _lens == null:
		%LensTitle.text = "Peephole lens (not found)"
		return
	for row: Array in LENS_ROWS:
		var parameter: String = row[1]
		_lens_scene_values[parameter] = _lens_value(parameter)
		_add_stepper(%Lens, row[0],
				func() -> float: return _lens_value(parameter),
				func(value: float) -> void: _lens.set_shader_parameter(parameter, value),
				row[2], row[3], row[4], row[5])

	var presets := HFlowContainer.new()
	presets.add_child(_action_button("Scene", _apply_lens.bind(_lens_scene_values)))
	for preset_name: String in LENS_PRESETS:
		presets.add_child(_action_button(preset_name, _apply_lens.bind(LENS_PRESETS[preset_name])))
	presets.add_child(_action_button("Copy", _copy_lens_values))
	%Lens.add_child(presets)


## Falls back to the shader's own default when the material doesn't set it.
func _lens_value(parameter: String) -> float:
	var value: Variant = _lens.get_shader_parameter(parameter)
	if value == null:
		value = RenderingServer.shader_get_parameter_default(_lens.shader.get_rid(), parameter)
	return float(value) if value is float or value is int else 0.0  # null when headless


func _apply_lens(values: Dictionary) -> void:
	for parameter: String in values:
		_lens.set_shader_parameter(parameter, values[parameter])


## Puts the current lens values on the clipboard in .tscn form, ready to paste
## over the Peephole/Mask material lines in main.tscn (also printed).
func _copy_lens_values() -> void:
	var lines := PackedStringArray()
	for row: Array in LENS_ROWS:
		lines.append("shader_parameter/%s = %s" % [row[1], snappedf(_lens_value(row[1]), 0.001)])
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	print("Peephole lens:\n" + text)


## A "label  −  value  +" row; the value label refreshes every frame.
func _add_stepper(container: Container, text: String, getter: Callable,
		setter: Callable, step: float, min_value: float, max_value: float,
		value_format: String) -> void:
	var line := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 52
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var change := func(delta: float) -> void:
		setter.call(clampf(snappedf(getter.call() + delta, step), min_value, max_value))
	line.add_child(name_label)
	line.add_child(_action_button("−", change.bind(-step)))
	line.add_child(value_label)
	line.add_child(_action_button("+", change.bind(step)))
	container.add_child(line)
	_live_values[value_label] = [getter, value_format]


func _action_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	if text.length() > 1:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button


func _process(_delta: float) -> void:
	_refresh()
	_fit_to_screen()


## The panel grows with its content; past the screen height the middle part
## scrolls (the footer with the timers and buttons always stays visible).
func _fit_to_screen() -> void:
	var scroll: ScrollContainer = %Scroll
	var panel: Control = $Panel
	var others := panel.get_combined_minimum_size().y - scroll.custom_minimum_size.y
	var room := get_viewport().get_visible_rect().size.y - 16.0 - others
	var height := minf(%Content.get_combined_minimum_size().y, maxf(room, 40.0))
	if not is_equal_approx(scroll.custom_minimum_size.y, height):
		scroll.custom_minimum_size.y = height


func _input(event: InputEvent) -> void:
	var button := event as InputEventJoypadButton
	if button:
		var action := "pressed" if button.pressed else "released"
		_last_joypad_events[button.device] = "Button %d %s" % [button.button_index, action]


func _refresh() -> void:
	var lines := PackedStringArray(["Door: %s" % ("open" if _doorway.is_open else "closed")])
	for controller in _players:
		var model := controller.model
		var side := "outside" if controller.role == _outside_role else "inside"
		var pad := str(controller.joypad_id) if controller.has_joypad() else "none"
		lines.append("%s (%s)  HP %d/%d  Pad %s" % [
			model.display_name, side, model.health, model.max_health, pad,
		])
		lines.append("  " + _last_joypad_events.get(controller.joypad_id, "no button events"))
	_status.text = "\n".join(lines)

	var knocking := _outside_role.is_knocking()
	_phase_idle.set_pressed_no_signal(not knocking)
	_phase_knocking.set_pressed_no_signal(knocking)
	_release_delay.text = "%.1f s" % _outside_role.release_delay
	for label: Label in _live_values:
		var entry: Array = _live_values[label]
		label.text = entry[1] % float(entry[0].call())
	_knock_button.disabled = _doorway.is_open
	_timers.text = "Knock release  %s\nDoor close  %s\nInput lock  %s" % [
		_format_timer(_outside_role.release_time_left()),
		_format_timer(_doorway.close_time_left()),
		_format_timer(_input_lock_time_left.call()),
	]


func _format_timer(seconds: float) -> String:
	return "%.2f s" % seconds if seconds > 0.0 else "—"


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		_last_joypad_events.erase(device)


func _on_phase_pressed(phase: OutsideRole.Phase) -> void:
	if phase == OutsideRole.Phase.IDLE:
		_outside_role.reset_state()
	else:
		_activate_knock()


func _change_release_delay(step: float) -> void:
	var seconds := snappedf(_outside_role.release_delay + step, 0.1)
	_outside_role.set_release_delay(clampf(seconds, MIN_RELEASE_DELAY, MAX_RELEASE_DELAY))


func _activate_knock() -> void:
	_outside_role.press(OutsideRole.KNOCK)
	_outside_role.release(OutsideRole.KNOCK)


func _reset_round() -> void:
	get_tree().reload_current_scene()
