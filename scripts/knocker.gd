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
##
## Poses (same picture in every view): [member idle_texture] while walking or
## standing, [member knock_ready_texture] while knocking at the door
## ([method set_knocking]) with [member knock_hit_texture] flashed on every
## hit of the knock rhythm ([method knock_hit]), [member caught_texture] while
## frozen.

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
## Shown while walking up or away, or standing without knocking.
@export var idle_texture: Texture2D
## Hand raised, between hits, while knocking at the door.
@export var knock_ready_texture: Texture2D
## Knuckles on the door: shown on every hit of the knock rhythm.
@export var knock_hit_texture: Texture2D
## Seconds the hit picture stays before the hand is raised again.
@export var knock_hit_duration := 0.1
## Shown while caught in the doorway (frozen).
@export var caught_texture: Texture2D
## How big the knocker is in the room view (seen through the open door), so he
## fits in the door frame: shrunk towards [member room_anchor_x] /
## [member room_anchor_y] (design pixels, 1280x720; where his feet stand).
@export_range(0.3, 1.0, 0.01) var room_scale := 0.9:
	set(value):
		room_scale = value
		_apply_room_fit()
@export var room_anchor_x := 660.0:
	set(value):
		room_anchor_x = value
		_apply_room_fit()
@export var room_anchor_y := 720.0:
	set(value):
		room_anchor_y = value
		_apply_room_fit()
## The figure seen through the peephole: drawn as a close-up (enlarged
## around [member close_up_focus_x] / [member close_up_focus_y], which lands
## in the middle of the view), so the fisheye is full of the knocker.
@export var close_up_figure: TextureRect
## How much the peephole figure is enlarged (1 = as in the other views).
@export_range(1.0, 5.0, 0.05) var close_up_zoom := 2.0:
	set(value):
		close_up_zoom = value
		_apply_close_up()
## The point of the knocker picture (design pixels, 1280x720) put in the
## middle of the peephole view: his face by default.
@export var close_up_focus_x := 630.0:
	set(value):
		close_up_focus_x = value
		_apply_close_up()
@export var close_up_focus_y := 110.0:
	set(value):
		close_up_focus_y = value
		_apply_close_up()
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
var _scene_offsets: Array[Vector4] = []  # left, top, right, bottom as in the scene
var _tween: Tween
var _frozen := false
## Doorway test data per picture: {"rows": Array[Vector2i], "size": Vector2},
## see [method _row_spans]. Figure pictures are scanned once, up front.
var _figure_spans := {}
var _doorway_spans := {}
## True while the knocking phase runs (see [method set_knocking]).
var knocking := false
## Seconds the hit picture still shows (see [method knock_hit]).
var _hit_left := 0.0

## True while the knocker is gone and the disguise shows instead.
var disguised := false
## One full-screen disguise picture next to each figure.
var _disguise_rects: Array[TextureRect] = []
var _disguise_frame := 0
var _disguise_time := 0.0


func _ready() -> void:
	for figure in figures:
		_rest_offsets.append(Vector2(figure.offset_left, figure.offset_right))
		_scene_offsets.append(Vector4(figure.offset_left, figure.offset_top,
				figure.offset_right, figure.offset_bottom))
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not disguise_frames.is_empty():
			var rect := _make_disguise_rect()
			# Right above the figure, in the same view.
			figure.add_sibling.call_deferred(rect)
			_disguise_rects.append(rect)
	set_process(false)
	_apply_close_up()
	_apply_room_fit()
	set_presence(0.0)
	var poses: Array[Texture2D] = [idle_texture, knock_ready_texture, knock_hit_texture]
	if room_figure:
		poses.append(room_figure.texture)
	for texture in poses:
		if texture and not _figure_spans.has(texture):
			_figure_spans[texture] = _row_spans(texture, true)
	if doorway_wall and doorway_wall.texture:
		_doorway_spans = _row_spans(doorway_wall.texture, false)


## Shrinks the room figure towards its anchor (by its offsets, not scale, so
## the doorway catch, which reads the rect, sees the same size).
func _apply_room_fit() -> void:
	var index := figures.find(room_figure)
	if index < 0 or index >= _scene_offsets.size():
		return  # not ready yet
	var view := Vector2(1280, 720)
	var anchor := Vector2(room_anchor_x, room_anchor_y)
	var shrink := 1.0 - room_scale
	var base := _scene_offsets[index]
	room_figure.offset_top = base.y + anchor.y * shrink
	room_figure.offset_bottom = base.w - (view.y - anchor.y) * shrink
	_rest_offsets[index] = Vector2(base.x + anchor.x * shrink,
			base.z - (view.x - anchor.x) * shrink)
	set_presence(presence)


## Enlarges the peephole figure around the focus point and moves that point
## to the middle of the view (sliding still shifts it sideways from there).
func _apply_close_up() -> void:
	var index := figures.find(close_up_figure)
	if index < 0 or index >= _scene_offsets.size():
		return  # not ready yet
	var view := Vector2(1280, 720)
	var focus := Vector2(close_up_focus_x, close_up_focus_y)
	var move := view / 2.0 - focus
	var base := _scene_offsets[index]
	close_up_figure.pivot_offset = focus
	close_up_figure.scale = Vector2.ONE * close_up_zoom
	close_up_figure.offset_top = base.y + move.y
	close_up_figure.offset_bottom = base.w + move.y
	_rest_offsets[index] = Vector2(base.x + move.x, base.z + move.x)
	set_presence(presence)


## Knocking pose on / off (it only shows while the knocker stands at the
## door; walking shows the idle picture).
func set_knocking(on: bool) -> void:
	if on == knocking:
		return
	knocking = on
	_hit_left = 0.0
	_update_process()
	_update_pose()


## One hit of the knock rhythm: knuckles on the door for
## [member knock_hit_duration], then the hand goes up again.
func knock_hit() -> void:
	if _frozen or knock_hit_texture == null:
		return
	_hit_left = knock_hit_duration
	_update_process()
	_update_pose()


func _update_process() -> void:
	set_process(disguised or _hit_left > 0.0)


## Puts the picture for the current state on every figure.
func _update_pose() -> void:
	var texture := idle_texture
	if _frozen and caught_texture:
		texture = caught_texture
	elif presence >= 1.0 and _hit_left > 0.0:
		texture = knock_hit_texture
	elif presence >= 1.0 and knocking and knock_ready_texture:
		texture = knock_ready_texture
	if texture == null:
		return  # no poses set: keep the scene's picture
	for figure in figures:
		var rect := figure as TextureRect
		if rect and rect.texture != texture:
			rect.texture = texture


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
	_update_process()
	set_presence(presence)


## Cycles the disguise frames and ends a knock hit.
func _process(delta: float) -> void:
	if disguised and disguise_fps > 0.0:
		_disguise_time += delta
		var frame_length := 1.0 / disguise_fps
		if _disguise_time >= frame_length:
			_disguise_time = fmod(_disguise_time, frame_length)
			_disguise_frame = (_disguise_frame + 1) % disguise_frames.size()
			_show_disguise_frame()
	if _hit_left > 0.0:
		_hit_left -= delta
		if _hit_left <= 0.0:
			_hit_left = 0.0
			_update_process()
			_update_pose()


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
	_update_pose()
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
	set_knocking(false)
	presence = 0.0


## Caught: stops right where it is and ignores slides until [method unfreeze].
func freeze() -> void:
	if _tween:
		_tween.kill()
	_frozen = true
	_hit_left = 0.0
	_update_process()
	_update_pose()


## Lets it move again; the caller decides where it goes next.
func unfreeze() -> void:
	_frozen = false
	_update_pose()


## True if even one opaque pixel of the room figure lies inside the doorway
## (a transparent pixel of the wall), as currently drawn. The disguise is
## never caught.
func is_in_doorway() -> bool:
	var figure := room_figure
	if disguised or not is_present() or figure == null or figure.texture == null or _doorway_spans.is_empty():
		return false
	if not _figure_spans.has(figure.texture):
		_figure_spans[figure.texture] = _row_spans(figure.texture, true)
	var figure_spans: Dictionary = _figure_spans[figure.texture]
	var figure_rows: Array[Vector2i] = figure_spans.rows
	var doorway_rows: Array[Vector2i] = _doorway_spans.rows
	var figure_draw := _drawn_rect(figure)
	var wall_draw := doorway_wall.get_global_rect()
	var figure_size: Vector2 = figure_spans.size
	var wall_size: Vector2 = _doorway_spans.size
	# Walk the doorway one scanned wall row at a time.
	for wall_y in doorway_rows.size():
		var door := doorway_rows[wall_y]
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
## or transparent; (-1, -1) for rows with none. Pictures wider than the
## 1280 design width are scanned at half size (still one design pixel).
## Returns {"rows": ..., "size": the scanned size}.
static func _row_spans(texture: Texture2D, opaque: bool) -> Dictionary:
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()
	if img.get_width() > 1280:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_NEAREST)
	img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	var width := img.get_width()
	var rows: Array[Vector2i] = []
	for y in img.get_height():
		var row := y * width * 4 + 3  # alpha of the row's first pixel
		var first := -1
		for x in width:
			if (data[row + x * 4] >= 128) == opaque:
				first = x
				break
		var last := -1
		if first >= 0:
			for x in range(width - 1, first - 1, -1):
				if (data[row + x * 4] >= 128) == opaque:
					last = x
					break
		rows.append(Vector2i(first, last))
	return {"rows": rows, "size": Vector2(img.get_size())}
