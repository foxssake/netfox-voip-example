extends Node
class_name VoiceSource

## Provides audio data _captured from an audio _bus.

## Emitted whenever audio data is _captured from the audio _bus.
signal on_data(buffer: PackedVector2Array)

## The _bus name to use as source.
##
## Note that this _bus [b]must[/b] have a [AudioEffect_capture] added, otherwise 
## audio data cannot be recorded.
@export var bus_name = "Record"

## Set to true to automatically start recording.
@export var autostart = true

var _bus: int
var _capture: AudioEffectCapture
var _voice_player: AudioStreamPlayer

var _is_recording = false

func _ready():
	_bus = AudioServer.get_bus_index(bus_name)
	_capture = _find_capture_effect(_bus)
	
	if not _capture:
		push_error("No _capture effect on _bus \"%s\"!" % [bus_name])
		set_process(false)
		return
	
	_voice_player = AudioStreamPlayer.new()
	add_child(_voice_player)
	_voice_player.owner = self

	_voice_player.stream = AudioStreamMicrophone.new()
	_voice_player.bus = bus_name
	
	if autostart:
		start()

func start():
	_is_recording = true
	_voice_player.play()

func stop():
	_is_recording = false
	_voice_player.stop()

func _process(delta):
	if not _is_recording:
		return

	var frames_available = _capture.get_frames_available()
	if frames_available:
		var frames = _capture.get_buffer(frames_available)
		on_data.emit(frames)

func _find_capture_effect(bus_idx: int) -> AudioEffectCapture:
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var effect = AudioServer.get_bus_effect(bus_idx, i)
		if effect is AudioEffectCapture:
			return effect

	return null
