class_name Knocker
extends Node
## The knocker standing outside the door (dummy art for now).
##
## The outside is drawn in several views (behind the opening door in the room,
## through the peephole, the corridor once you step out), so there is one
## figure per view. [member presence] (0 = gone, 1 = in place) drives all of
## them together: they slide in from the right and back out.
##
## When the door opens, [method is_in_doorway] tells whether any of it shows in
## the doorway; [method freeze] then pins it in place.

## One figure per outside view; all move together.
@export var figures: Array[Control] = []
## The figure drawn behind the door in the room; the doorway test uses it.
@export var room_figure: TextureRect
## The wall around the door; its transparent pixels are the doorway.
@export var doorway_wall: TextureRect
## How far off to the right the figures wait while away (design pixels).
@export var slide_distance := 1280.0
@export var slide_in_duration := 0.35
## Used by [method slide_out] when no duration is given.
@export var slide_out_duration := 1.5
## Disguise (see [method set_disguised]): full-screen frames shown in place
## (no sliding) instead of the figures, cycled as an animation.
@export var disguise_frames: Array[Texture2D] = []
## Disguise animation frames per second.
@export var disguise_fps := 3.0
## Moves the disguise picture (design pixels, + is right / down). It is
## applied in all three views, so they stay aligned.
@export var disguise_offset := Vector2.ZERO:
	set(value):
		disguise_offset = value
		set_presence(presence)
## Size of the disguise picture (1 = full screen), from its top-left corner.
@export_range(0.1, 3.0, 0.01) var disguise_scale := 1.0:
	set(value):
		disguise_scale = value
		set_presence(presence)

## 0 = fully away, 1 = standing in front of the door.
var presence := 0.0:
	set = set_presence

var _rest_offsets: Array[Vector2] = []  # (offset_left, offset_right) per figure
var _tween: Tween
var _frozen := false
## Per texture row: Vector2i(first, last) opaque / transparent column, or (-1, -1).
var _figure_rows: Array[Vector2i] = []
var _doorway_rows: Array[Vector2i] = []

## True while the knocker is gone and the disguise shows instead.
var disguised := false
## One full-screen disguise picture next to each figure.
var _disguise_rects: Array[TextureRect] = []
var _disguise_frame := 0
var _disguise_time := 0.0


func _ready() -> void:
	for figure in figures:
		_rest_offsets.append(Vector2(figure.offset_left, figure.offset_right))
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not disguise_frames.is_empty():
			var rect := _make_disguise_rect()
			# Right above the figure, in the same view.
			figure.add_sibling.call_deferred(rect)
			_disguise_rects.append(rect)
	set_process(false)
	set_presence(0.0)
	if room_figure and room_figure.texture:
		_figure_rows = _row_spans(room_figure.texture, true)
	if doorway_wall and doorway_wall.texture:
		_doorway_rows = _row_spans(doorway_wall.texture, false)


## On: the knocker vanishes at once (no slide) and the disguise animation
## plays in its place until switched off. Off: the disguise vanishes; the
## knocker stays gone until it slides in again. Ignored while frozen.
func set_disguised(on: bool) -> void:
	if disguise_frames.is_empty() or on == disguised or (on and _frozen):
		return
	disguised = on
	if on:
		if _tween:
			_tween.kill()
		presence = 0.0
	_disguise_frame = 0
	_disguise_time = 0.0
	_show_disguise_frame()
	set_process(on)
	set_presence(presence)


## Cycles the disguise frames.
func _process(delta: float) -> void:
	if disguise_fps <= 0.0:
		return
	_disguise_time += delta
	var frame_length := 1.0 / disguise_fps
	if _disguise_time >= frame_length:
		_disguise_time = fmod(_disguise_time, frame_length)
		_disguise_frame = (_disguise_frame + 1) % disguise_frames.size()
		_show_disguise_frame()


func _show_disguise_frame() -> void:
	for rect in _disguise_rects:
		rect.texture = disguise_frames[_disguise_frame]


func _make_disguise_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "Disguise"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rect.texture = disguise_frames[0]
	rect.visible = false
	return rect


func set_presence(value: float) -> void:
	presence = clampf(value, 0.0, 1.0)
	if _rest_offsets.size() != figures.size():
		return  # not ready yet
	# Shift the offsets (not position), so anchoring keeps working on resize.
	var shift := (1.0 - presence) * slide_distance
	for i in figures.size():
		figures[i].offset_left = _rest_offsets[i].x + shift
		figures[i].offset_right = _rest_offsets[i].y + shift
		figures[i].visible = presence > 0.0 and not disguised
	for rect in _disguise_rects:
		# The picture is drawn as big as its parent view (the screen), scaled.
		var view_size := Vector2(1280, 720)
		var parent := rect.get_parent() as Control
		if parent:
			view_size = parent.size
		elif rect.is_inside_tree():
			view_size = rect.get_viewport_rect().size
		var picture_size := view_size * disguise_scale
		rect.offset_left = disguise_offset.x
		rect.offset_top = disguise_offset.y
		rect.offset_right = rect.offset_left + picture_size.x
		rect.offset_bottom = rect.offset_top + picture_size.y
		rect.visible = disguised


func is_present() -> bool:
	return presence > 0.0


func is_frozen() -> bool:
	return _frozen


## Slides in quickly (from wherever it currently is). Ignored while frozen.
func slide_in() -> void:
	_slide_to(1.0, slide_in_duration, Tween.EASE_OUT)


## Slides out slowly; [param duration] defaults to [member slide_out_duration].
## Ignored while frozen.
func slide_out(duration: float = -1.0) -> void:
	_slide_to(0.0, duration if duration > 0.0 else slide_out_duration, Tween.EASE_IN_OUT)


## Gone immediately (e.g. when the roles are swapped); also unfreezes.
func hide_now() -> void:
	if _tween:
		_tween.kill()
	_frozen = false
	presence = 0.0


## Caught: stops right where it is and ignores slides until [method unfreeze].
func freeze() -> void:
	if _tween:
		_tween.kill()
	_frozen = true


## Lets it move again; the caller decides where it goes next.
func unfreeze() -> void:
	_frozen = false


## True if even one opaque pixel of the room figure lies inside the doorway
## (a transparent pixel of the wall), as currently drawn. The disguise is
## never caught.
func is_in_doorway() -> bool:
	var figure := room_figure
	var figure_rows := _figure_rows
	if disguised or not is_present() or figure_rows.is_empty() or _doorway_rows.is_empty():
		return false
	var figure_draw := _drawn_rect(figure)
	var wall_draw := doorway_wall.get_global_rect()
	var figure_size := Vector2(figure.texture.get_size())
	var wall_size := Vector2(doorway_wall.texture.get_size())
	# Walk the doorway one wall texture row at a time.
	for wall_y in _doorway_rows.size():
		var door := _doorway_rows[wall_y]
		if door.x < 0:
			continue
		var screen_y := wall_draw.position.y + (wall_y + 0.5) * wall_draw.size.y / wall_size.y
		var fig_y := int((screen_y - figure_draw.position.y) * figure_size.y / figure_draw.size.y)
		if fig_y < 0 or fig_y >= figure_rows.size():
			continue
		var body := figure_rows[fig_y]
		if body.x < 0:
			continue
		var door_left := wall_draw.position.x + door.x * wall_draw.size.x / wall_size.x
		var door_right := wall_draw.position.x + (door.y + 1) * wall_draw.size.x / wall_size.x
		var body_left := figure_draw.position.x + body.x * figure_draw.size.x / figure_size.x
		var body_right := figure_draw.position.x + (body.y + 1) * figure_draw.size.x / figure_size.x
		if body_left < door_right and body_right > door_left:
			return true
	return false


func _slide_to(target: float, full_duration: float, easing: Tween.EaseType) -> void:
	if _frozen or disguised:
		return
	if _tween:
		_tween.kill()
	# A partial slide (e.g. pressed again while sliding out) takes
	# proportionally less time, so the speed stays the same.
	var duration := full_duration * absf(target - presence)
	if duration <= 0.0:
		presence = target
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(easing)
	_tween.tween_property(self, "presence", target, duration)


## Where the texture actually lands on screen (TextureRect stretch modes used
## here: scale to fill, or keep aspect centred).
static func _drawn_rect(rect: TextureRect) -> Rect2:
	var area := rect.get_global_rect()
	if rect.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		return area
	var tex := Vector2(rect.texture.get_size())
	var scale := minf(area.size.x / tex.x, area.size.y / tex.y)
	var size := tex * scale
	return Rect2(area.position + (area.size - size) / 2.0, size)


## Per row, the first and last column whose pixel is opaque ([param opaque])
## or transparent; (-1, -1) for rows with none.
static func _row_spans(texture: Texture2D, opaque: bool) -> Array[Vector2i]:
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()
	var rows: Array[Vector2i] = []
	for y in img.get_height():
		var first := -1
		var last := -1
		for x in img.get_width():
			if (img.get_pixel(x, y).a >= 0.5) == opaque:
				if first < 0:
					first = x
				last = x
		rows.append(Vector2i(first, last))
	return rows
