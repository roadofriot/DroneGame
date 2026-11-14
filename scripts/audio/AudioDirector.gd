class_name AudioDirector
extends Node

## AudioDirector: Dynamic motor RPM audio synthesis, wind ambience modulation,
## procedural sound effects (Coin, Gate, Crash, Fanfare), and bus volume control.

signal volume_changed(bus_name: String, linear_val: float)

@export var target_drone: FlightPhysics

var motor_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var is_audio_muted: bool = false
var master_volume: float = 1.0
var sfx_volume: float = 0.8
var motor_volume: float = 0.7
var wind_volume: float = 0.5

# Pre-synthesized Audio Streams
var stream_motor_loop: AudioStreamWAV
var stream_coin_pickup: AudioStreamWAV
var stream_gate_passed: AudioStreamWAV
var stream_crash: AudioStreamWAV
var stream_fanfare: AudioStreamWAV

func _ready() -> void:
	_synthesize_all_audio_streams()
	_setup_audio_players()

func _setup_audio_players() -> void:
	motor_player = AudioStreamPlayer.new()
	motor_player.name = "MotorAudioPlayer"
	motor_player.stream = stream_motor_loop
	motor_player.volume_db = linear_to_db(motor_volume)
	add_child(motor_player)

	wind_player = AudioStreamPlayer.new()
	wind_player.name = "WindAudioPlayer"
	wind_player.stream = _generate_noise_stream(2.0, 0.4)
	wind_player.volume_db = -80.0 # Starts silent
	add_child(wind_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXAudioPlayer"
	sfx_player.volume_db = linear_to_db(sfx_volume)
	add_child(sfx_player)

func _process(_delta: float) -> void:
	if not target_drone or is_audio_muted:
		return

	# Update motor audio pitch based on average motor RPM [0.0 .. 1.0]
	var total_rpm: float = 0.0
	for rpm in target_drone.motor_rpms:
		total_rpm += rpm
	var avg_rpm = total_rpm / 4.0

	if target_drone.current_state == FlightPhysics.DroneState.FLYING or target_drone.current_state == FlightPhysics.DroneState.TAKING_OFF:
		if is_inside_tree() and not motor_player.playing:
			motor_player.play()
		# Pitch ranges from 0.65 (idle hover) to 2.2 (full punchout)
		motor_player.pitch_scale = clampf(0.65 + (avg_rpm * 1.55), 0.5, 2.5)
		motor_player.volume_db = linear_to_db(motor_volume * clampf(0.2 + (avg_rpm * 0.8), 0.1, 1.0))
	else:
		if motor_player.playing:
			motor_player.stop()

	# Update wind audio based on ground speed (0 to 25 m/s)
	var speed = target_drone.ground_speed
	if speed > 1.5 and target_drone.current_state == FlightPhysics.DroneState.FLYING:
		if is_inside_tree() and not wind_player.playing:
			wind_player.play()
		var wind_ratio = clampf(speed / 20.0, 0.0, 1.0)
		wind_player.volume_db = linear_to_db(wind_volume * wind_ratio)
		wind_player.pitch_scale = 0.8 + (wind_ratio * 0.4)
	else:
		if wind_player.playing:
			wind_player.stop()

func play_coin_pickup() -> void:
	if sfx_player and stream_coin_pickup and not is_audio_muted:
		sfx_player.stream = stream_coin_pickup
		sfx_player.pitch_scale = randf_range(0.96, 1.04)
		if is_inside_tree(): sfx_player.play()

func play_gate_passed() -> void:
	if sfx_player and stream_gate_passed and not is_audio_muted:
		sfx_player.stream = stream_gate_passed
		sfx_player.pitch_scale = 1.0
		if is_inside_tree(): sfx_player.play()

func play_crash() -> void:
	if sfx_player and stream_crash and not is_audio_muted:
		sfx_player.stream = stream_crash
		sfx_player.pitch_scale = randf_range(0.9, 1.1)
		if is_inside_tree(): sfx_player.play()

func play_mission_completed() -> void:
	if sfx_player and stream_fanfare and not is_audio_muted:
		sfx_player.stream = stream_fanfare
		sfx_player.pitch_scale = 1.0
		if is_inside_tree(): sfx_player.play()

func set_master_volume(linear: float) -> void:
	master_volume = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	volume_changed.emit("Master", master_volume)

func set_sfx_volume(linear: float) -> void:
	sfx_volume = clampf(linear, 0.0, 1.0)
	if sfx_player:
		sfx_player.volume_db = linear_to_db(sfx_volume)
	volume_changed.emit("SFX", sfx_volume)

func toggle_mute() -> bool:
	is_audio_muted = not is_audio_muted
	if is_audio_muted:
		if motor_player: motor_player.stop()
		if wind_player: wind_player.stop()
		if sfx_player: sfx_player.stop()
	return is_audio_muted

# --- Procedural Audio Synthesizers (100% Offline, Zero External Files) ---

func _synthesize_all_audio_streams() -> void:
	stream_motor_loop = _generate_motor_drone_stream(1.0, 140.0)
	stream_coin_pickup = _generate_harmonic_chime([880.0, 1760.0], 0.35)
	stream_gate_passed = _generate_arpeggio([523.25, 659.25, 783.99, 1046.50], 0.45)
	stream_crash = _generate_crash_impact(0.5)
	stream_fanfare = _generate_arpeggio([440.0, 554.37, 659.25, 880.0], 0.6)

static func _generate_motor_drone_stream(duration: float, fundamental_hz: float, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(duration * sample_rate)

	var total_samples = wav.loop_end
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)

	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		# Complex multi-harmonic motor whine: fundamental + 2nd harmonic + 4th harmonic
		var s1 = sin(TAU * fundamental_hz * t) * 0.55
		var s2 = sin(TAU * fundamental_hz * 2.0 * t) * 0.30
		var s3 = sin(TAU * fundamental_hz * 4.0 * t) * 0.15
		var val = int(clampf(s1 + s2 + s3, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val)

	wav.data = bytes
	return wav

static func _generate_harmonic_chime(frequencies: Array[float], duration: float, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	var total_samples = int(duration * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)

	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var env = exp(-t * 10.0) # Fast exponential decay
		var s: float = 0.0
		for freq in frequencies:
			s += sin(TAU * freq * t)
		s = (s / float(frequencies.size())) * env
		var val = int(clampf(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val)

	wav.data = bytes
	return wav

static func _generate_arpeggio(notes: Array[float], duration: float, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	var total_samples = int(duration * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)

	var note_duration = duration / float(notes.size())

	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var note_idx = mini(int(t / note_duration), notes.size() - 1)
		var freq = notes[note_idx]
		var note_t = fmod(t, note_duration)
		var env = exp(-note_t * 6.0)
		var s = sin(TAU * freq * t) * env
		var val = int(clampf(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val)

	wav.data = bytes
	return wav

static func _generate_crash_impact(duration: float, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	var total_samples = int(duration * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)

	var rng = RandomNumberGenerator.new()
	rng.seed = 98765

	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var env = exp(-t * 12.0)
		var noise = rng.randf_range(-1.0, 1.0)
		var sub_thud = sin(TAU * 55.0 * t) * 0.7
		var s = (noise * 0.5 + sub_thud) * env
		var val = int(clampf(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val)

	wav.data = bytes
	return wav

static func _generate_noise_stream(duration: float, volume_mult: float, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(duration * sample_rate)

	var total_samples = wav.loop_end
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)

	var rng = RandomNumberGenerator.new()
	rng.seed = 44332

	var prev = 0.0
	for i in range(total_samples):
		# Low-pass filtered pink noise for wind roar
		var white = rng.randf_range(-1.0, 1.0)
		prev = (prev * 0.94) + (white * 0.06)
		var val = int(clampf(prev * volume_mult * 3.0, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val)

	wav.data = bytes
	return wav
