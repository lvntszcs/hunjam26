class_name Hand
extends TextureRect
## The inside player's first-person hand in the room view.
##
## Frames are full-size (wall-sized, transparent around the hand) PNGs loaded
## from [constant IDLE_DIR] and [constant OPEN_DIR], played in file-name
## order. Add or replace frames there; no code or scene changes needed.
## IDLE loops; OPEN plays once and holds its last frame until
## [method play_idle] is called. The OPEN frames are drawn to match the door:
## the next-to-last grabs the closed door's handle, the last one pulls it
## with the door half open.

## Emitted when the OPEN animation has shown its last frame.
signal open_finished

const IDLE_DIR := "res://assets/hand/idle"
const OPEN_DIR := "res://assets/hand/open"

## Frames per second of the looping idle animation.
@export_range(1.0, 30.0, 0.5) var idle_fps := 3.0
## Frames per second of the one-shot open animation.
@export_range(1.0, 30.0, 0.5) var open_fps := 10.0

var _idle_frames: Array[Texture2D] = []
var _open_frames: Array[Texture2D] = []
var _frames: Array[Texture2D] = []
## Speed of the current open animation, if not open_fps (see [method play_open]).
var _fps_override := 0.0
var _loop := true
var _frame := 0
var _frame_time := 0.0
var _playing_open := false
var _open_done := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_idle_frames = load_frames(IDLE_DIR)
	_open_frames = load_frames(OPEN_DIR)
	if _idle_frames.is_empty():
		push_warning("Hand: no frames in %s" % IDLE_DIR)
	if _open_frames.is_empty():
		push_warning("Hand: no frames in %s" % OPEN_DIR)
	play_idle()


## All textures in [param dir], sorted by file name. ResourceLoader.list_directory()
## also works in exported builds, where only the imported versions exist.
static func load_frames(dir: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var files := Array(ResourceLoader.list_directory(dir))
	files.sort()
	for file: String in files:
		if file.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]:
			var frame := load(dir.path_join(file)) as Texture2D
			if frame:
				frames.append(frame)
	return frames


func idle_frame_count() -> int:
	return _idle_frames.size()


func open_frame_count() -> int:
	return _open_frames.size()


func is_playing_open() -> bool:
	return _playing_open


## Loops the idle animation (from its first frame).
func play_idle() -> void:
	_playing_open = false
	_start(_idle_frames, true)


## Plays the open animation up to the frame that grabs the closed door's
## handle (the next-to-last one) and holds it there, until [method play_idle]
## or [method play_open] is called. Returns once the handle is grabbed.
func play_grab() -> void:
	if _open_frames.size() < 2:
		return  # no separate grab frame to hold
	_playing_open = true
	_start(_open_frames.slice(0, _open_frames.size() - 1), false)
	await open_finished


## The reverse of [method play_grab]: lets go of the handle by playing the
## grab frames backwards, then loops idle. Returns once the idle loop starts.
func play_release() -> void:
	if _open_frames.size() < 2:
		play_idle()
		return
	var frames := _open_frames.slice(0, _open_frames.size() - 1)
	frames.reverse()
	_playing_open = true
	_start(frames, false)
	await open_finished
	# open_finished fires as the last frame appears; show it for a full frame
	# too, or the hand would jump straight from the grab to idle.
	await get_tree().create_timer(1.0 / open_fps).timeout
	play_idle()


## Jumps straight to the last open frame (pulling the handle, drawn for the
## half-open door). Used when the hand already holds the handle.
func play_pull() -> void:
	if _open_frames.is_empty():
		return
	var last: Array[Texture2D] = [_open_frames.back()]
	_playing_open = false
	_frames = last
	_loop = false
	_frame = 0
	_frame_time = 0.0
	_open_done = true
	texture = last[0]


## Plays the open animation once and returns when its last frame is shown.
## [param fps] overrides [member open_fps] for this one (0 = open_fps).
func play_open(fps := 0.0) -> void:
	if _open_frames.is_empty():
		return
	_playing_open = true
	_start(_open_frames, false)
	_fps_override = fps
	await open_finished


func _start(frames: Array[Texture2D], loop: bool) -> void:
	_fps_override = 0.0
	_frames = frames
	_loop = loop
	_frame = 0
	_frame_time = 0.0
	_open_done = false
	texture = _frames[0] if not _frames.is_empty() else null
	if not loop and _frames.size() == 1:
		_finish_open.call_deferred()


func _process(delta: float) -> void:
	if _frames.size() < 2 or _open_done:
		return
	_frame_time += delta
	# Read every frame, so speed changes (e.g. from the debug menu) apply at once.
	var fps := idle_fps if _loop else (_fps_override if _fps_override > 0.0 else open_fps)
	var frame_length := 1.0 / fps
	while _frame_time >= frame_length:
		_frame_time -= frame_length
		if _frame < _frames.size() - 1:
			_frame += 1
		elif _loop:
			_frame = 0
		texture = _frames[_frame]
		if not _loop and _frame == _frames.size() - 1:
			# The last open frame (pulling the handle) is drawn to match the
			# half-open door, so the door moves on this same frame.
			_finish_open()
			return


func _finish_open() -> void:
	_open_done = true
	if _playing_open:
		open_finished.emit()
