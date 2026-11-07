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
@export_range(1.0, 30.0, 0.5) var idle_fps := 6.0
## Frames per second of the one-shot open animation.
@export_range(1.0, 30.0, 0.5) var open_fps := 10.0

var _idle_frames: Array[Texture2D] = []
var _open_frames: Array[Texture2D] = []
var _frames: Array[Texture2D] = []
var _fps := 1.0
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
			var texture := load(dir.path_join(file)) as Texture2D
			if texture:
				frames.append(texture)
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
	_start(_idle_frames, idle_fps, true)


## Plays the open animation once and returns when its last frame is shown.
func play_open() -> void:
	if _open_frames.is_empty():
		return
	_playing_open = true
	_start(_open_frames, open_fps, false)
	await open_finished


func _start(frames: Array[Texture2D], fps: float, loop: bool) -> void:
	_frames = frames
	_fps = fps
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
	var frame_length := 1.0 / _fps
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
