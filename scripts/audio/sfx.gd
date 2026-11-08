extends Node
## One-shot sound effects (autoload "Sfx", the scene scenes/sfx.tscn):
## Sfx.play(Sfx.XRAY) from anywhere. They play on the SFX bus, so the menu's
## SFX knob sets their volume.
##
## Each sound's own level is set on the scene's root node in the Inspector
## (open scenes/sfx.tscn). The knock rhythms have their own players and levels
## (KnockPlayer.volume_db on each KnockPlayer node).

const CARD_CHOOSE := preload("res://assets/sfx/card/card_choose.mp3")
const CARD_SELECTED := preload("res://assets/sfx/card/card_selected.mp3")
const DEATH_GRANNY := preload("res://assets/sfx/death/death_granny.mp3")
const DEATH_KNOCKER := preload("res://assets/sfx/death/death_knocker.mp3")
const MACHINE_BREAK := preload("res://assets/sfx/machine/machine_break.mp3")
const BUSH := preload("res://assets/sfx/bush_sound.mp3")
const BUTTON_PRESS := preload("res://assets/sfx/button_press.mp3")
const DELIVERY_GUY := preload("res://assets/sfx/delivery_guy.mp3")
const FLIPFLOP_HIT := preload("res://assets/sfx/flipflop_hit.mp3")
const XRAY := preload("res://assets/sfx/xray.mp3")
## Picked at random, never the same twice in a row.
const KNOB_TURNS: Array[AudioStream] = [
	preload("res://assets/sfx/knob/knob_turn_01.mp3"),
	preload("res://assets/sfx/knob/knob_turn_02.mp3"),
	preload("res://assets/sfx/knob/knob_turn_03.mp3"),
]

@export_group("Levels")
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var card_choose_db := 0.0
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var card_selected_db := 0.0
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var death_granny_db := 0.0
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var death_knocker_db := 0.0
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var machine_break_db := 0.0
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var bush_db := 0.0
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var button_press_db := 0.0
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var delivery_guy_db := 0.0
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var flipflop_hit_db := 0.0
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var xray_db := 0.0
## All three knob turns.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var knob_turn_db := 0.0
@export_group("")

const BUS := &"SFX"
## Sounds that can play at the same time.
const VOICES := 8

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_random := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		add_child(player)
		_players.append(player)


## Plays [param stream] once at its level (see "Levels"), plus
## [param extra_db], on [param bus] (one that sends to SFX, e.g. "Death" with
## its reverb). Returns the player, e.g. to stop it early.
func play(stream: AudioStream, extra_db := 0.0, bus := BUS) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = level_of(stream) + extra_db
	player.bus = bus if AudioServer.get_bus_index(bus) >= 0 else BUS
	player.play()
	return player


## The level set for [param stream] (dB; 0 for a sound not listed).
func level_of(stream: AudioStream) -> float:
	if stream in KNOB_TURNS:
		return knob_turn_db
	match stream:
		CARD_CHOOSE: return card_choose_db
		CARD_SELECTED: return card_selected_db
		DEATH_GRANNY: return death_granny_db
		DEATH_KNOCKER: return death_knocker_db
		MACHINE_BREAK: return machine_break_db
		BUSH: return bush_db
		BUTTON_PRESS: return button_press_db
		DELIVERY_GUY: return delivery_guy_db
		FLIPFLOP_HIT: return flipflop_hit_db
		XRAY: return xray_db
	return 0.0


## Plays one of [param streams] at random (not the one it played last time).
func play_random(streams: Array[AudioStream], volume_db := 0.0) -> AudioStreamPlayer:
	if streams.is_empty():
		return null
	var key := streams.hash()
	var index := randi() % streams.size()
	if streams.size() > 1 and index == _last_random.get(key, -1):
		index = (index + 1 + randi() % (streams.size() - 1)) % streams.size()
	_last_random[key] = index
	return play(streams[index], volume_db)
