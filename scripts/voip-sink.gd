extends VoiceSink
class_name VoipSink

@export var max_frames_per_packet = 128
@export_enum("No compression:-1", "FastLZ", "Deflate", "zstd", "gzip", "brotli")
var compression_mode: int = FileAccess.COMPRESSION_DEFLATE
@export var sampling_rate = 11025

# Assume source is at app mix rate
var source_sampling_rate = ProjectSettings.get_setting_with_override("audio/driver/mix_rate")

var _transmit_buffer: PackedVector2Array = PackedVector2Array()
var _last_buffer: PackedVector2Array

var _uncompressed_bytes_sent = 0
var _bytes_sent = 0

class CompressedFrame:
	var data: PackedByteArray
	var size: int
	
	func _init(p_data: PackedByteArray, p_size: int):
		data = p_data
		size = p_size

func _ready():
	super()

	while is_inside_tree():
		if is_multiplayer_authority() and _uncompressed_bytes_sent > 0:
			print("Traffic sent: %.2f kbps (%s) / %.2f kbps %d%%" % [_bytes_sent / 1024, compression_mode, _uncompressed_bytes_sent / 1024, 100 * _bytes_sent / _uncompressed_bytes_sent])
		
		_uncompressed_bytes_sent = 0
		_bytes_sent = 0
		await get_tree().create_timer(1).timeout

func push_voice(buffer: PackedVector2Array):
	if is_multiplayer_authority():
		_transmit_buffer.append_array(buffer)
	else:
		super(buffer)

func encode_voice(frames: PackedVector2Array) -> CompressedFrame:
	var mono_frames = to_mono(frames)
	mono_frames = resample(mono_frames, source_sampling_rate, sampling_rate)

	var bytes = quantize8(mono_frames)
	var compressed_bytes = compress(bytes)

	return CompressedFrame.new(compressed_bytes, bytes.size())

func decode_voice(compressed_frame: CompressedFrame) -> PackedVector2Array:
	var decompressed = decompress(compressed_frame.data, compressed_frame.size)
	var mono_frames = dequantize8(decompressed)
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

func encode_delta16(frames: PackedFloat32Array, max_step: float = 0.125) -> PackedByteArray:
	var deltas = PackedByteArray()
	deltas.resize(frames.size() * 2)
	
	var at = 0.0
	
	for i in range(frames.size()):
		var f = frames[i]
		var d = f - at
		d = clampf(d, -max_step, max_step)
		var v = d / max_step
		v = inverse_lerp(-1, 1, v)
		
		deltas.encode_u16(i * 2, v * 65535.0)
		at += d
	
	return deltas

func decode_delta16(deltas: PackedByteArray, max_step: float = 0.125) -> PackedFloat32Array:
	var frames = PackedFloat32Array()
	frames.resize(deltas.size() / 2)
	
	var at = 0.0
	
	for i in range(frames.size()):
		var d = deltas.decode_u16(i * 2) / 65535.0
		d = lerp(-max_step, max_step, d)
		
		at += d
		frames[i] = d
	
	return frames

func encode_delta8(frames: PackedFloat32Array, max_step: float = 0.5) -> PackedByteArray:
	var deltas = PackedByteArray()
	deltas.resize(frames.size() * 1)
	
	var at = 0.0
	
	for i in range(frames.size()):
		var f = frames[i]
		var d = f - at
		d = clampf(d, -max_step, max_step)
		var v = d / max_step
		v = inverse_lerp(-1, 1, v)
		
		deltas.encode_u8(i * 1, v * 255.0)
		at += d
	
	return deltas

func decode_delta8(deltas: PackedByteArray, max_step: float = 0.5) -> PackedFloat32Array:
	var frames = PackedFloat32Array()
	frames.resize(deltas.size() / 1)
	
	var at = 0.0
	
	for i in range(frames.size()):
		var d = deltas.decode_u8(i * 1) / 255.0
		d = lerp(-max_step, max_step, d)
		
		at += d
		frames[i] = d
	
	return frames

func quantize16(frames: PackedFloat32Array) -> PackedByteArray:
	var quants = PackedByteArray()
	quants.resize(frames.size() * 2)

	for i in range(frames.size()):
		var f = frames[i]
		f = inverse_lerp(-1, 1, f)
		f = clampf(f, 0, 1)

		quants.encode_u16(i * 2, f * 65535)
	
	return quants

func dequantize16(quants: PackedByteArray) -> PackedFloat32Array:
	var frames = PackedFloat32Array()
	frames.resize(quants.size() / 2)
	
	for i in range(frames.size()):
		var f = quants.decode_u16(i * 2) / 65535.0
		f = lerp(-1, 1, f)
		
		frames[i] = f
	
	return frames

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

func compress(data: PackedByteArray) -> PackedByteArray:
	if compression_mode < 0:
		return data
	else:
		return data.compress(compression_mode)

func decompress(data: PackedByteArray, size: int) -> PackedByteArray:
	if compression_mode < 0:
		return data
	else:
		return data.decompress(size, compression_mode)

func _process(_dt):
	if is_multiplayer_authority():
		for i in range(0, _transmit_buffer.size(), max_frames_per_packet):
			var frames = _transmit_buffer.slice(i, i + max_frames_per_packet)
			var packet = encode_voice(frames)
			
			_uncompressed_bytes_sent += packet.size
			_bytes_sent += packet.data.size()

			rpc("_transmit_voice", packet.data, packet.size)
		_transmit_buffer.clear()
	else:
		if _playback_buffer.is_empty():
			push_voice(_last_buffer)

@rpc("authority", "unreliable", "call_remote")
func _transmit_voice(data: PackedByteArray, size: int):
	var compressed_frame = CompressedFrame.new(data, size)
	var frames = decode_voice(compressed_frame)
	push_voice(frames)
	_last_buffer = frames
