class_name KnockPlayer
extends Node
## Plays door-knock rhythms. [method play_random_pattern] picks one of
## [member patterns] and, on every hit, plays a random knock sample from
## [constant SOUND_DIR] (files named knock_01.mp3, knock_02.mp3, ...; .wav
## works too). Drop more knock_NN files into the folder; they are picked up on
## start.
##
## With [member rhythm_sound] set, a pattern plays that one recording instead
## (a whole rhythm, e.g. the knocking machine), and the hits only drive
## [signal knocked].

## Emitted on every hit, e.g. for a door shake or debug display.
signal knocked(hit_index: int)
## Emitted when a pattern has played all of its hits.
signal pattern_finished

const SOUND_DIR := "res://assets/sfx/knock"
const SOUND_FILE_PATTERN := "^knock_\\d+\\.(wav|mp3)$"

## Rhythm patterns: the time of each hit, in seconds from the first one.
## Keep them shorter than OutsideRole.release_delay, since the rhythm is cut
## off when the knocking phase ends.
## Plain nested arrays of float literals on purpose: the editor can only read
## a constant default. With PackedFloat32Array(...) calls it saw no default,
## showed an empty list and saved that into the scene, silencing the knocks.
@export var patterns: Array[Array] = [
	[0.0, 0.3],  # kop-kop
	[0.0, 0.25, 0.5],  # three even
	[0.0, 0.15, 0.3, 0.45],  # four quick
	[0.0, 0.12, 0.24, 0.6, 0.72, 0.84],  # impatient: 3 + 3
	[0.0, 0.2, 0.3, 0.4, 0.6, 1.0, 1.2],  # shave and a haircut, two bits
]
## Random pitch spread per hit (0.05 = +-5 %), so repeats sound less mechanical.
@export_range(0.0, 0.3, 0.01) var pitch_variation := 0.05
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db := 0.0
## The knocks are sound effects: the menu's SFX knob sets this bus's volume.
@export var bus: StringName = &"SFX"
## Simultaneous knocks allowed (hits can overlap the previous knock's tail).
@export_range(1, 8) var voices := 3
## A recording of a whole rhythm: played once at a pattern's start instead of
## a sample per hit.
@export var rhythm_sound: AudioStream

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
	if patterns.is_empty():
		push_warning("KnockPlayer: 'patterns' is empty, knocks will be silent. " \
				+ "Check the node in the Inspector (Revert restores the defaults).")
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


## [param hit_times]: seconds from the first hit, e.g. [0.0, 0.25, 0.5].
func play_pattern(hit_times: Array) -> void:
	_generation += 1
	var generation := _generation
	_active = true
	var elapsed := 0.0
	for i in hit_times.size():
		var hit_time := float(hit_times[i])
		var wait := hit_time - elapsed
		if wait > 0.0:
			await get_tree().create_timer(wait, false).timeout
			elapsed = hit_time
		if generation != _generation:
			return  # stopped or replaced meanwhile
		if rhythm_sound:
			if i == 0:
				_play_stream(rhythm_sound, 1.0)
		else:
			_play_hit()
		knocked.emit(i)
	_active = false
	pattern_finished.emit()


## Cuts the current rhythm off; hits already sounding ring out (a whole
## [member rhythm_sound] stops at once).
func stop() -> void:
	_generation += 1
	_active = false
	if rhythm_sound:
		for player in _players:
			player.stop()


## Seconds a pattern takes to sound (the rhythm recording's length, if set).
func pattern_length(hit_times: Array) -> float:
	var length := float(hit_times[-1]) if not hit_times.is_empty() else 0.0
	if rhythm_sound:
		length = maxf(length, rhythm_sound.get_length())
	return length


func _play_hit() -> void:
	if _sounds.is_empty():
		return
	var index := randi() % _sounds.size()
	if _sounds.size() > 1 and index == _last_sound:
		index = (index + 1 + randi() % (_sounds.size() - 1)) % _sounds.size()
	_last_sound = index
	_play_stream(_sounds[index], 1.0 + randf_range(-pitch_variation, pitch_variation))


func _play_stream(stream: AudioStream, pitch: float) -> void:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()
