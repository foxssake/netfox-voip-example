extends Node
class_name VoiceSink

## A programmatic audio player.
##
## Audio data is pushed into its buffer to be played through the configured
## [member voice_player].

## This [AudioStreamPlayer3D] will receive data pushed into the sink.
@export var voice_player: AudioStreamPlayer3D

## How many samples to push into the stream per iteration.
##
## Decreasing this can increase CPU load as it will be more iterations to push
## all the data. Increasing the push rate might introduce delay as the sink
## will need to wait more before it can push the next batch of audio.
@export var push_rate = 512

var _voice_playback: AudioStreamGeneratorPlayback
var _playback_buffer: PackedVector2Array = PackedVector2Array()

## Signal emitted whenever an audio buffer is pushed into the
## [member voice_player], effectively playing it.
signal on_playback(buffer: PackedVector2Array)

## Push a set of audio samples for playback.
##
## Note that the samples will be saved internally and pushed to the
## [member voice_player] whenever it can play them back. This avoids buffer 
## overflows in the [AudioStreamGeneratorPlayback].
func push_voice(buffer: PackedVector2Array):
	_playback_buffer.append_array(buffer)
	if not voice_player.playing:
		voice_player.play()
		_voice_playback = voice_player.get_stream_playback()

	if not _voice_playback.can_push_buffer(buffer.size()):
		buffer = buffer.slice(0, _voice_playback.get_frames_available())

	_voice_playback.push_buffer(buffer)
	on_playback.emit(buffer)

func _ready():
	voice_player.stream = AudioStreamGenerator.new()

func _process(_dt):
	if not _playback_buffer.size():
		return
	
	if not voice_player.playing:
		voice_player.play()
		_voice_playback = voice_player.get_stream_playback()
	
	var idx = 0
	while _voice_playback.can_push_buffer(push_rate) and idx < _playback_buffer.size():
		_voice_playback.push_buffer(_playback_buffer.slice(idx, idx + push_rate))
		idx += push_rate
	
	if idx < _playback_buffer.size():
		_playback_buffer = _playback_buffer.slice(idx, _playback_buffer.size())
	else:
		_playback_buffer.clear()
