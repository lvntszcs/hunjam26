class_name PeepholeEvent
extends Node
## Optional scare while looking through the peephole: with [member chance] an
## image appears at a random moment, the light flickers, and after
## [member duration] seconds the player is pushed back from the door.
##
## Self-contained: it only listens to Doorway signals and touches its own
## nodes. Delete the node (or set chance to 0) and nothing else changes.

@export var doorway: Doorway
@export var inside_role: InsideRole
## The image that appears inside the peephole view (starts hidden). It gets
## only part of the background's dimming, so it is shaded but never vanishes.
@export var apparition: CanvasItem
## The peephole background; only this flickers.
@export var background: CanvasItem

## Ekkora eséllyel történik meg egy belenézéskor (0 = soha, 1 = mindig).
@export_range(0.0, 1.0) var chance := 0.3
## A belenézés után véletlenszerűen ennyi idő között jelenik meg (másodperc).
@export var min_delay := 0.5
@export var max_delay := 1.5
## Ennyi ideig tart, utána visszadob a szoba közepére.
@export var duration := 2.0
## Fényerő a pislákolás sötét pillanataiban (0 = teljes sötét).
@export_range(0.0, 1.0) var dim_brightness := 0.4
## Mennyit kap a kép a háttér sötétedéséből (0 = semmit, 1 = ugyanannyit).
@export_range(0.0, 1.0) var apparition_shade := 0.8
## Egy pislákolási lépés hossza ezek között (másodperc).
@export var flicker_min := 0.04
@export var flicker_max := 0.18

## Bumped to cancel whatever run is in progress.
var _run := 0


func _ready() -> void:
	_reset()
	doorway.peephole_entered.connect(_on_peephole_entered)
	doorway.peephole_left.connect(_cancel)
	doorway.opening.connect(_cancel)


func _on_peephole_entered() -> void:
	_run += 1
	if randf() >= chance:
		return
	var run := _run
	await get_tree().create_timer(randf_range(min_delay, max_delay)).timeout
	if run != _run:
		return  # left the peephole or opened the door meanwhile
	apparition.show()
	var end_ms := Time.get_ticks_msec() + int(duration * 1000.0)
	while run == _run and Time.get_ticks_msec() < end_ms:
		var lit := randf() < 0.6
		_set_brightness(1.0 if lit else randf_range(0.0, dim_brightness))
		await get_tree().create_timer(randf_range(flicker_min, flicker_max)).timeout
	if run != _run:
		return
	_reset()
	inside_role.force_step_back()


func _cancel() -> void:
	_run += 1
	_reset()


func _reset() -> void:
	apparition.hide()
	_set_brightness(1.0)


func _set_brightness(value: float) -> void:
	background.modulate = Color(value, value, value, 1.0)
	var shade := lerpf(1.0, value, apparition_shade)
	apparition.modulate = Color(shade, shade, shade, 1.0)
