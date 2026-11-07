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

## 0 = fully away, 1 = standing in front of the door.
var presence := 0.0:
	set = set_presence

var _rest_offsets: Array[Vector2] = []  # (offset_left, offset_right) per figure
var _tween: Tween
var _frozen := false
## Per texture row: Vector2i(first, last) opaque / transparent column, or (-1, -1).
var _figure_rows: Array[Vector2i] = []
var _doorway_rows: Array[Vector2i] = []


func _ready() -> void:
	for figure in figures:
		_rest_offsets.append(Vector2(figure.offset_left, figure.offset_right))
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_presence(0.0)
	if room_figure and room_figure.texture:
		_figure_rows = _row_spans(room_figure.texture, true)
	if doorway_wall and doorway_wall.texture:
		_doorway_rows = _row_spans(doorway_wall.texture, false)


func set_presence(value: float) -> void:
	presence = clampf(value, 0.0, 1.0)
	if _rest_offsets.size() != figures.size():
		return  # not ready yet
	# Shift the offsets (not position), so anchoring keeps working on resize.
	var shift := (1.0 - presence) * slide_distance
	for i in figures.size():
		figures[i].offset_left = _rest_offsets[i].x + shift
		figures[i].offset_right = _rest_offsets[i].y + shift
		figures[i].visible = presence > 0.0


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
## (a transparent pixel of the wall), as currently drawn.
func is_in_doorway() -> bool:
	if not is_present() or _figure_rows.is_empty() or _doorway_rows.is_empty():
		return false
	var figure_draw := _drawn_rect(room_figure)
	var wall_draw := doorway_wall.get_global_rect()
	var figure_size := Vector2(room_figure.texture.get_size())
	var wall_size := Vector2(doorway_wall.texture.get_size())
	# Walk the doorway one wall texture row at a time.
	for wall_y in _doorway_rows.size():
		var door := _doorway_rows[wall_y]
		if door.x < 0:
			continue
		var screen_y := wall_draw.position.y + (wall_y + 0.5) * wall_draw.size.y / wall_size.y
		var fig_y := int((screen_y - figure_draw.position.y) * figure_size.y / figure_draw.size.y)
		if fig_y < 0 or fig_y >= _figure_rows.size():
			continue
		var body := _figure_rows[fig_y]
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
	if _frozen:
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
