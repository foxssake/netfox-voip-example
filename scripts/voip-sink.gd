extends VoiceSink
class_name VoipSink

@export var max_frames_per_packet = 128
@export var sampling_rate = 11025

# Assume source is at app mix rate
var source_sampling_rate = ProjectSettings.get_setting_with_override("audio/driver/mix_rate")

var _transmit_buffer: PackedVector2Array = PackedVector2Array()
var _last_buffer: PackedVector2Array

func push_voice(buffer: PackedVector2Array):
	if is_multiplayer_authority():
		_transmit_buffer.append_array(buffer)
	else:
		super(buffer)

func encode_voice(frames: PackedVector2Array) -> PackedByteArray:
	var mono_frames = to_mono(frames)
	mono_frames = resample(mono_frames, source_sampling_rate, sampling_rate)
	var bytes = quantize8(mono_frames)

	return bytes

func decode_voice(bytes: PackedByteArray) -> PackedVector2Array:
	var mono_frames = dequantize8(bytes)
	mono_frames = resample(mono_frames, sampling_rate, source_sampling_rate)
	var frames = to_stereo(mono_frames)

	return frames

func to_mono(frames: PackedVector2Array) -> PackedFloat32Array:
	var mono_frames = PackedFloat32Array()
	mono_frames.resize(frames.size())
	
	for i in range(frames.size()):
		mono_frames[i] = frames[i].x
	
	return mono_frames

func to_stereo(mono_frames: PackedFloat32Array) -> PackedVector2Array:
	var frames = PackedVector2Array()
	frames.resize(mono_frames.size())
	
	for i in range(frames.size()):
		frames.set(i, Vector2(mono_frames[i], mono_frames[i]))
	
	return frames

func resample(frames: PackedFloat32Array, source_rate: int, target_rate: int) -> PackedFloat32Array:
	var result = PackedFloat32Array()
	
	var source_frames = frames.size()
	var target_frames = source_frames / float(source_rate) * target_rate
	
	result.resize(target_frames)
	for i in range(target_frames):
		var f = i / float(target_frames)
		
		result[i] = frames[floor(f * source_frames)]
	
	return result

func quantize8(frames: PackedFloat32Array) -> PackedByteArray:
	var quants = PackedByteArray()
	quants.resize(frames.size() * 1)

	for i in range(frames.size()):
		var f = frames[i]
		f = inverse_lerp(-1, 1, f)
		f = clampf(f, 0, 1)

		quants.encode_u8(i * 1, f * 255)
	
	return quants

func dequantize8(quants: PackedByteArray) -> PackedFloat32Array:
	var frames = PackedFloat32Array()
	frames.resize(quants.size() / 1)
	
	for i in range(frames.size()):
		var f = quants.decode_u8(i * 1) / 255.0
		f = lerp(-1, 1, f)
		
		frames[i] = f
	
	return frames

func _process(_dt):
	if is_multiplayer_authority():
		for i in range(0, _transmit_buffer.size(), max_frames_per_packet):
			var frames = _transmit_buffer.slice(i, i + max_frames_per_packet)
			var bytes = encode_voice(frames)

			rpc("_transmit_voice", bytes)
		_transmit_buffer.clear()
	else:
		if _playback_buffer.is_empty():
			push_voice(_last_buffer)

@rpc("authority", "unreliable", "call_remote")
func _transmit_voice(data: PackedByteArray):
	var frames = decode_voice(data)
	push_voice(frames)
	_last_buffer = frames
