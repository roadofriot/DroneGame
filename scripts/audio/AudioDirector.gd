class_name AudioDirector
extends Node

## AudioDirector: Dynamic motor RPM audio synthesis, realistic engine profiles (Turbo/Racer/Cine),
## wind ambience modulation, procedural sound effects (Coin, Gate, Crash, Fanfare), and bus volume control.

signal volume_changed(bus_name: String, linear_val: float)
signal engine_profile_changed(profile_name: String)

enum MotorSoundProfile { TURBO, RACER, CINEMATIC }

@export var target_drone: FlightPhysics

var motor_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var is_audio_muted: bool = false
var is_drone_sound_muted: bool = true # Drone motor sound stopped / muted by default
var master_volume: float = 1.0
var sfx_volume: float = 0.85
var motor_volume: float = 0.8
var wind_volume: float = 0.55

var current_sound_profile: MotorSoundProfile = MotorSoundProfile.TURBO
var motor_streams: Dictionary = {}

# Pre-synthesized SFX Streams
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
	motor_player.stream = motor_streams.get(current_sound_profile, null)
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

	var can_play_motor = not is_drone_sound_muted and not is_audio_muted
	var is_airborne = target_drone.current_state in [
		FlightPhysics.DroneState.FLYING,
		FlightPhysics.DroneState.HOVER,
		FlightPhysics.DroneState.TAKEOFF,
		FlightPhysics.DroneState.RTH,
		FlightPhysics.DroneState.LANDING,
		FlightPhysics.DroneState.MOTOR_STARTING
	]

	# Dynamic pitch scaling based on selected profile
	var min_pitch = 0.70
	var max_pitch = 2.35
	if current_sound_profile == MotorSoundProfile.RACER:
		min_pitch = 0.85
		max_pitch = 2.70
	elif current_sound_profile == MotorSoundProfile.CINEMATIC:
		min_pitch = 0.60
		max_pitch = 1.85

	motor_player.pitch_scale = clampf(min_pitch + (avg_rpm * (max_pitch - min_pitch)), 0.4, 3.0)

	if can_play_motor and is_airborne:
		if is_inside_tree() and not motor_player.playing:
			motor_player.play()
		motor_player.volume_db = linear_to_db(motor_volume * clampf(0.25 + (avg_rpm * 0.75), 0.1, 1.0))
	else:
		if motor_player.playing:
			motor_player.stop()

	# Update wind audio based on ground speed (0 to 25 m/s)
	var speed = target_drone.ground_speed
	if speed > 1.5 and is_airborne and not is_audio_muted:
		if is_inside_tree() and not wind_player.playing:
			wind_player.play()
		var wind_ratio = clampf(speed / 20.0, 0.0, 1.0)
		wind_player.volume_db = linear_to_db(wind_volume * wind_ratio)
		wind_player.pitch_scale = 0.8 + (wind_ratio * 0.4)
	else:
		if wind_player.playing:
			wind_player.stop()

func cycle_motor_sound_profile() -> String:
	var next_idx = (int(current_sound_profile) + 1) % MotorSoundProfile.size()
	current_sound_profile = next_idx as MotorSoundProfile
	if motor_player and motor_streams.has(current_sound_profile):
		var was_playing = motor_player.playing
		var cur_pitch = motor_player.pitch_scale
		motor_player.stream = motor_streams[current_sound_profile]
		if was_playing and is_inside_tree() and not is_audio_muted and not is_drone_sound_muted:
			motor_player.play()
			motor_player.pitch_scale = cur_pitch

	var profile_name = MotorSoundProfile.keys()[current_sound_profile]
	engine_profile_changed.emit(profile_name)
	return profile_name

func toggle_drone_sound() -> bool:
	is_drone_sound_muted = not is_drone_sound_muted
	if is_drone_sound_muted and motor_player and motor_player.playing:
		motor_player.stop()
	return is_drone_sound_muted

func toggle_all_sound() -> bool:
	return toggle_mute()

func toggle_mute() -> bool:
	is_audio_muted = not is_audio_muted
	if is_audio_muted:
		if motor_player and motor_player.playing: motor_player.stop()
		if wind_player and wind_player.playing: wind_player.stop()
		if sfx_player and sfx_player.playing: sfx_player.stop()
	return is_audio_muted

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

# --- Procedural Audio Synthesizers (100% Offline, Rich Harmonics) ---

func _synthesize_all_audio_streams() -> void:
	# 3 Distinct Motor Audio Profiles
	motor_streams[MotorSoundProfile.TURBO] = _generate_rich_motor_stream(150.0, 4, 0.22)
	motor_streams[MotorSoundProfile.RACER] = _generate_rich_motor_stream(220.0, 3, 0.55)
	motor_streams[MotorSoundProfile.CINEMATIC] = _generate_rich_motor_stream(105.0, 4, 0.08)

	stream_coin_pickup = _generate_harmonic_chime([880.0, 1760.0], 0.35)
	stream_gate_passed = _generate_arpeggio([523.25, 659.25, 783.99, 1046.50], 0.45)
	stream_crash = _generate_crash_impact(0.5)
	stream_fanfare = _generate_arpeggio([440.0, 554.37, 659.25, 880.0], 0.6)

static func _generate_rich_motor_stream(fundamental_hz: float, blade_count: int, harshness: float, sample_rate: int = 22050) -> AudioStreamWAV:
	var duration: float = 1.0
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(duration * sample_rate)

	var total_samples = wav.loop_end
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)

	var blade_freq = fundamental_hz * float(blade_count) * 0.5
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		# 1. Brushless motor coil magnetic tones (fundamental + 2nd & 3rd harmonics)
		var s1 = sin(TAU * fundamental_hz * t) * 0.45
		var s2 = sin(TAU * fundamental_hz * 2.0 * t) * (0.24 + harshness * 0.16)
		var s3 = sin(TAU * fundamental_hz * 3.0 * t) * (0.12 + harshness * 0.12)
		# 2. Propeller aerodynamic blade-pass chop modulation
		var chop = 0.82 + 0.18 * sin(TAU * blade_freq * t)
		# 3. Micro-turbulent airflow hiss
		var hash_val = fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var hiss = (hash_val * 2.0 - 1.0) * (0.035 + harshness * 0.05)
		
		var sample = (s1 + s2 + s3 + hiss) * chop
		var val = int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val)

	wav.data = bytes
	return wav

# Backwards compatibility helper for existing tests
static func _generate_motor_drone_stream(duration: float, fundamental_hz: float, sample_rate: int = 22050) -> AudioStreamWAV:
	return _generate_rich_motor_stream(fundamental_hz, 4, 0.22, sample_rate)

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
		var white = rng.randf_range(-1.0, 1.0)
		prev = (prev * 0.94) + (white * 0.06)
		var val = int(clampf(prev * volume_mult * 3.0, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val)

	wav.data = bytes
	return wav
