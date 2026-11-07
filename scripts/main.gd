extends Control

enum State { FAR, MOVING, PEEKING, OPEN }
var state := State.FAR

## Ki lehet-e nyitni az ajtót a szoba közepéről (messziről).
@export var can_open_from_far := true
## Ki lehet-e nyitni az ajtót kukucskálás közben (azonnal, hátralépés nélkül).
@export var can_open_from_peephole := true
## Ennyi másodperc után csukódik be magától a nyitott ajtó.
@export var open_duration := 2.0
@export var close_zoom_handle := Vector2(2,2)
@export var close_zoom := Vector2(10, 10)


@onready var cam = $Camera2D
@onready var hole = $Hole
@onready var peephole = $Peephole
@onready var corridor = $Corridor
@onready var black = $Fade/Black
@onready var prank = $Corridor/Prank
@onready var handle = $Handle

var door_open := false  # nyitástól a csukás végéig igaz

func _unhandled_input(event):
	if event.is_action_pressed("place_prank") and not door_open:
		prank.visible = true  # placeholder csali: csak a nyitott ajtón át látszik
		return
	if state == State.MOVING or state == State.OPEN:
		return  # animáció / nyitott ajtó közben nem reagálunk
	if event.is_action_pressed("open_door"):
		if (state == State.FAR and can_open_from_far) \
				or (state == State.PEEKING and can_open_from_peephole):
			open_door()
	elif event.is_action_pressed("approach") and state == State.FAR:
		enter_peephole()
	elif event.is_action_pressed("step_back") and state == State.PEEKING:
		exit_peephole()

func enter_peephole():
	state = State.MOVING
	await cam.go_close(hole.get_center(),close_zoom).finished
	await fade_to(1.0)
	peephole.visible = true
	await fade_to(0.0)
	state = State.PEEKING

func exit_peephole():
	state = State.MOVING
	await fade_to(1.0)
	peephole.visible = false
	await fade_to(0.0)
	await cam.go_back().finished
	state = State.FAR

func open_door():
	state = State.MOVING
	await cam.go_close(handle.get_center(),close_zoom_handle).finished
	door_open = true
	await fade_to(1.0)
	peephole.visible = false
	corridor.visible = true
	await fade_to(0.0)
	state = State.OPEN
	await get_tree().create_timer(open_duration).timeout
	close_door()

func close_door():
	state = State.MOVING
	await fade_to(1.0)
	corridor.visible = false
	prank.visible = false  # nyitás után a csali resetel
	cam.snap_back()  # ha kukucskálásból nyitottunk, a kamera még ráközelített
	await fade_to(0.0)
	door_open = false
	state = State.FAR

func fade_to(alpha: float, time := 0.3):
	var t = create_tween()
	t.tween_property(black, "modulate:a", alpha, time)
	await t.finished
