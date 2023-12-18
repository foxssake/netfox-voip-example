extends Node
class_name VoiceSink

@export var voice_player: AudioStreamPlayer3D
@export var push_rate = 512

var voice_playback: AudioStreamGeneratorPlayback

var _playback_buffer: PackedVector2Array = PackedVector2Array()

signal on_playback(buffer: PackedVector2Array)

func _ready():
	voice_player.stream = AudioStreamGenerator.new()

func _process(_dt):
	if not _playback_buffer.size():
		return
	
	if not voice_player.playing:
		voice_player.play()
		voice_playback = voice_player.get_stream_playback()
	
	var idx = 0
	while voice_playback.can_push_buffer(push_rate) and idx < _playback_buffer.size():
		voice_playback.push_buffer(_playback_buffer.slice(idx, idx + push_rate))
		idx += push_rate
	
	if idx < _playback_buffer.size():
		_playback_buffer = _playback_buffer.slice(idx, _playback_buffer.size())
	else:
		_playback_buffer.clear()

func push_voice(buffer: PackedVector2Array):
	_playback_buffer.append_array(buffer)
	if not voice_player.playing:
		voice_player.play()
		voice_playback = voice_player.get_stream_playback()

	if not voice_playback.can_push_buffer(buffer.size()):
		buffer = buffer.slice(0, voice_playback.get_frames_available())

	voice_playback.push_buffer(buffer)
	on_playback.emit(buffer)
