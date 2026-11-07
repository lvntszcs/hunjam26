class_name KnockPlayer
extends Node
## Plays door-knock rhythms. [method play_random_pattern] picks one of
## [member patterns] and, on every hit, plays a random knock sample from
## [constant SOUND_DIR] (files named knock_01.wav, knock_02.wav, ...).
## Drop more knock_NN.wav files into the folder; they are picked up on start.

## Emitted on every hit, e.g. for a door shake or debug display.
signal knocked(hit_index: int)
## Emitted when a pattern has played all of its hits.
signal pattern_finished

const SOUND_DIR := "res://assets/sfx/knock"
const SOUND_FILE_PATTERN := "^knock_\\d+\\.wav$"

## Rhythm patterns: the time of each hit, in seconds from the first one.
## Keep them shorter than OutsideRole.release_delay, since the rhythm is cut
## off when the knocking phase ends.
@export var patterns: Array[PackedFloat32Array] = [
	PackedFloat32Array([0.0, 0.3]),  # kop-kop
	PackedFloat32Array([0.0, 0.25, 0.5]),  # three even
	PackedFloat32Array([0.0, 0.15, 0.3, 0.45]),  # four quick
	PackedFloat32Array([0.0, 0.12, 0.24, 0.6, 0.72, 0.84]),  # impatient: 3 + 3
	PackedFloat32Array([0.0, 0.2, 0.3, 0.4, 0.6, 1.0, 1.2]),  # shave and a haircut, two bits
]
## Random pitch spread per hit (0.05 = +-5 %), so repeats sound less mechanical.
@export_range(0.0, 0.3, 0.01) var pitch_variation := 0.05
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db := 0.0
@export var bus: StringName = &"Master"
## Simultaneous knocks allowed (hits can overlap the previous knock's tail).
@export_range(1, 8) var voices := 3

var _sounds: Array[AudioStream] = []
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _last_sound := -1
var _active := false
## Bumped by every play/stop, so an older rhythm still waiting on a timer
## knows it has been replaced and stops.
var _generation := 0


func _ready() -> void:
	_sounds = load_knock_sounds()
	if _sounds.is_empty():
		push_warning("KnockPlayer: no knock_NN.wav files in %s" % SOUND_DIR)
	for i in voices:
		var player := AudioStreamPlayer.new()
		player.bus = bus
		player.volume_db = volume_db
		add_child(player)
		_players.append(player)


## Finds the knock samples. ResourceLoader.list_directory() also works in
## exported builds, where only the imported versions of the .wav files exist.
static func load_knock_sounds() -> Array[AudioStream]:
	var regex := RegEx.create_from_string(SOUND_FILE_PATTERN)
	var sounds: Array[AudioStream] = []
	var files := Array(ResourceLoader.list_directory(SOUND_DIR))
	files.sort()
	for file: String in files:
		if regex.search(file):
			var stream := load(SOUND_DIR.path_join(file)) as AudioStream
			if stream:
				sounds.append(stream)
	return sounds


func sound_count() -> int:
	return _sounds.size()


func is_playing_pattern() -> bool:
	return _active


## Starts a random pattern, replacing any rhythm still playing.
func play_random_pattern() -> void:
	if patterns.is_empty():
		return
	play_pattern(patterns.pick_random())


func play_pattern(hit_times: PackedFloat32Array) -> void:
	_generation += 1
	var generation := _generation
	_active = true
	var elapsed := 0.0
	for i in hit_times.size():
		var wait := hit_times[i] - elapsed
		if wait > 0.0:
			await get_tree().create_timer(wait, false).timeout
			elapsed = hit_times[i]
		if generation != _generation:
			return  # stopped or replaced meanwhile
		_play_hit()
		knocked.emit(i)
	_active = false
	pattern_finished.emit()


## Cuts the current rhythm off; hits already sounding ring out.
func stop() -> void:
	_generation += 1
	_active = false


func _play_hit() -> void:
	if _sounds.is_empty():
		return
	var index := randi() % _sounds.size()
	if _sounds.size() > 1 and index == _last_sound:
		index = (index + 1 + randi() % (_sounds.size() - 1)) % _sounds.size()
	_last_sound = index
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _sounds[index]
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
