extends Node
class_name VoiceSource

signal on_data(buffer: PackedVector2Array)

@export var bus_name = "Record"
@export var autostart = true

var bus: int
var capture: AudioEffectCapture
var voice_player: AudioStreamPlayer

var _is_recording = false

func _ready():
	bus = AudioServer.get_bus_index(bus_name)
	capture = find_capture_effect(bus)
	
	if not capture:
		push_error("No capture effect on bus \"%s\"!" % [bus_name])
		set_process(false)
		return
	
	voice_player = AudioStreamPlayer.new()
	add_child(voice_player)
	voice_player.owner = self

	voice_player.stream = AudioStreamMicrophone.new()
	voice_player.bus = bus_name
	
	if autostart:
		start()

func start():
	_is_recording = true
	voice_player.play()

func stop():
	_is_recording = false
	voice_player.stop()

func _process(delta):
	if not _is_recording:
		return

	var frames_available = capture.get_frames_available()
	if frames_available:
		var frames = capture.get_buffer(frames_available)
		on_data.emit(frames)

func find_capture_effect(bus_idx: int) -> AudioEffectCapture:
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var effect = AudioServer.get_bus_effect(bus_idx, i)
		if effect is AudioEffectCapture:
			return effect

	return null
