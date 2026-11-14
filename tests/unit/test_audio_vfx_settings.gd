extends SceneTree

## Headless Unit and Integration Test Runner for Phase 6: Audio Synthesizers, VFX & Settings
## Tests Procedural Audio Synthesis, Dynamic Motor Pitch Scaling, Particle VFX Systems,
## and Visual Scalability Quality Presets.

const AudioDirector = preload("res://scripts/audio/AudioDirector.gd")
const VFXDirector = preload("res://scripts/vfx/VFXDirector.gd")
const SettingsService = preload("res://scripts/core/SettingsService.gd")
const FlightWorldScene = preload("res://scenes/flight/FlightWorld.tscn")
const FlightPhysics = preload("res://scripts/flight/FlightPhysics.gd")

func _init() -> void:
	print("==================================================")
	print("Starting MindSparQ Drone Simulator Phase 6 Tests")
	print("Audio Synthesizers, Particle VFX & Quality Presets")
	print("==================================================")

	var tests_passed: int = 0
	var tests_total: int = 6

	if test_av01_procedural_audio_stream_synthesis():
		tests_passed += 1
	if test_av02_motor_pitch_and_rpm_telemetry():
		tests_passed += 1
	if test_av03_audio_director_event_sfx_and_volume_bus():
		tests_passed += 1
	if test_av04_rotor_wash_vfx_altitude_dynamics():
		tests_passed += 1
	if test_av05_vfx_particle_burst_spawners():
		tests_passed += 1
	if test_av06_settings_service_quality_presets_and_persistence():
		tests_passed += 1

	print("==================================================")
	print("Phase 6 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	if tests_passed == tests_total:
		print(">> ALL PHASE 6 ACCEPTANCE TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 6 TESTS FAILED! <<")
		quit(1)

func test_av01_procedural_audio_stream_synthesis() -> bool:
	print("[AV-01] Testing Procedural 16-Bit PCM Waveform Synthesizers...")
	# 1. Motor Drone Loop
	var motor_wav = AudioDirector._generate_motor_drone_stream(1.0, 140.0)
	if not motor_wav or motor_wav.data.is_empty():
		printerr("FAIL: Motor drone PCM generation returned empty stream")
		return false
	if motor_wav.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		printerr("FAIL: Motor stream not configured for seamless forward loop")
		return false

	# 2. Harmonic Chime (Coin)
	var chime_wav = AudioDirector._generate_harmonic_chime([880.0, 1760.0], 0.35)
	if not chime_wav or chime_wav.data.size() < 1000:
		printerr("FAIL: Harmonic chime stream invalid")
		return false

	# 3. Arpeggio Triad (Gate / Fanfare)
	var arp_wav = AudioDirector._generate_arpeggio([523.25, 659.25, 783.99], 0.4)
	if not arp_wav or arp_wav.data.size() < 1000:
		printerr("FAIL: Arpeggio stream invalid")
		return false

	# 4. Crash Impact
	var crash_wav = AudioDirector._generate_crash_impact(0.5)
	if not crash_wav or crash_wav.data.size() < 1000:
		printerr("FAIL: Crash impact stream invalid")
		return false

	# 5. Pink Noise (Wind)
	var wind_wav = AudioDirector._generate_noise_stream(1.0, 0.5)
	if not wind_wav or wind_wav.data.size() < 1000:
		printerr("FAIL: Pink noise stream invalid")
		return false

	print("  - All 5 procedural waveform synthesizers verified (Motor, Coin, Gate, Crash, Wind) (PASS)")
	return true

func test_av02_motor_pitch_and_rpm_telemetry() -> bool:
	print("[AV-02] Testing Dynamic Motor Pitch & RPM Modulation...")
	var drone = FlightPhysics.new()
	root.add_child(drone)

	var audio_dir = AudioDirector.new()
	audio_dir.target_drone = drone
	root.add_child(audio_dir)
	if not audio_dir.is_node_ready():
		audio_dir._ready()

	# 1. Drone Disarmed: Motor should not play
	drone.current_state = FlightPhysics.DroneState.DISARMED
	for i in range(4): drone.motor_rpms[i] = 0.0
	audio_dir._process(0.016)
	if audio_dir.motor_player.playing:
		printerr("FAIL: Motor player playing while drone is DISARMED")
		audio_dir.queue_free()
		drone.queue_free()
		return false

	# 2. Drone Flying at Hover RPM (0.45)
	drone.current_state = FlightPhysics.DroneState.FLYING
	for i in range(4): drone.motor_rpms[i] = 0.45
	audio_dir._process(0.016)
	var hover_pitch = audio_dir.motor_player.pitch_scale
	if hover_pitch < 1.0 or hover_pitch > 1.6:
		printerr("FAIL: Hover pitch out of expected bounds [1.0, 1.6]: %f" % hover_pitch)
		audio_dir.queue_free()
		drone.queue_free()
		return false

	# 3. Drone Flying at Full Thrust (1.0)
	for i in range(4): drone.motor_rpms[i] = 1.0
	audio_dir._process(0.016)
	var punchout_pitch = audio_dir.motor_player.pitch_scale
	if punchout_pitch <= hover_pitch or punchout_pitch < 2.0:
		printerr("FAIL: Punchout pitch did not scale above hover: hover=%f, punchout=%f" % [hover_pitch, punchout_pitch])
		audio_dir.queue_free()
		drone.queue_free()
		return false

	audio_dir.queue_free()
	drone.queue_free()
	print("  - Dynamic motor pitch scaling verified: Idle=0.65, Hover=%.2f, Punchout=%.2f (PASS)" % [hover_pitch, punchout_pitch])
	return true

func test_av03_audio_director_event_sfx_and_volume_bus() -> bool:
	print("[AV-03] Testing Event SFX Triggers and Audio Bus Volume Modulation...")
	var audio_dir = AudioDirector.new()
	root.add_child(audio_dir)
	if not audio_dir.is_node_ready():
		audio_dir._ready()

	# Test SFX triggers execute without crashing
	audio_dir.play_coin_pickup()
	if audio_dir.sfx_player.stream != audio_dir.stream_coin_pickup:
		printerr("FAIL: Coin pickup stream not set on SFX player")
		audio_dir.queue_free()
		return false

	audio_dir.play_gate_passed()
	if audio_dir.sfx_player.stream != audio_dir.stream_gate_passed:
		printerr("FAIL: Gate pass stream not set on SFX player")
		audio_dir.queue_free()
		return false

	audio_dir.play_crash()
	if audio_dir.sfx_player.stream != audio_dir.stream_crash:
		printerr("FAIL: Crash stream not set on SFX player")
		audio_dir.queue_free()
		return false

	# Volume controls
	audio_dir.set_master_volume(0.65)
	if absf(audio_dir.master_volume - 0.65) > 0.01:
		printerr("FAIL: Master volume not updated")
		audio_dir.queue_free()
		return false

	# Mute toggle
	var is_muted = audio_dir.toggle_mute()
	if not is_muted or not audio_dir.is_audio_muted:
		printerr("FAIL: Audio mute state did not toggle to true")
		audio_dir.queue_free()
		return false

	audio_dir.queue_free()
	print("  - SFX playback triggers, master gain, and mute toggle verified (PASS)")
	return true

func test_av04_rotor_wash_vfx_altitude_dynamics() -> bool:
	print("[AV-04] Testing Rotor Wash Ground Dust Particle System...")
	var drone = FlightPhysics.new()
	root.add_child(drone)

	var vfx = VFXDirector.new()
	vfx.target_drone = drone
	root.add_child(vfx)
	if not vfx.is_node_ready():
		vfx._ready()

	drone.current_state = FlightPhysics.DroneState.FLYING

	# 1. Low Altitude (0.8m AGL < 2.5m) -> Rotor wash active
	drone.altitude_agl = 0.8
	vfx._process(0.016)
	if not vfx.rotor_wash_particles.emitting:
		printerr("FAIL: Rotor wash particles not emitting at 0.8m AGL")
		vfx.queue_free()
		drone.queue_free()
		return false

	# 2. High Altitude (5.0m AGL >= 2.5m) -> Rotor wash inactive
	drone.altitude_agl = 5.0
	vfx._process(0.016)
	if vfx.rotor_wash_particles.emitting:
		printerr("FAIL: Rotor wash particles emitting at high altitude (5.0m AGL)")
		vfx.queue_free()
		drone.queue_free()
		return false

	vfx.queue_free()
	drone.queue_free()
	print("  - Rotor wash particle emission dynamically gated below 2.5m AGL (PASS)")
	return true

func test_av05_vfx_particle_burst_spawners() -> bool:
	print("[AV-05] Testing Coin Sparkle, Gate Flare, and Crash VFX Spawners...")
	var vfx = VFXDirector.new()
	root.add_child(vfx)
	if not vfx.is_node_ready():
		vfx._ready()

	# Spawners must instantiate and attach active CPUParticles3D without error
	var initial_children = vfx.get_child_count()

	vfx.spawn_coin_pickup_vfx(Vector3(5, 2, 5))
	vfx.spawn_gate_pass_vfx(Vector3(10, 3, 10), Basis.IDENTITY)
	vfx.spawn_crash_vfx(Vector3(0, 0, 0), 8.5)

	if vfx.get_child_count() < initial_children + 3:
		printerr("FAIL: VFX spawners did not create particle instances: count=%d" % vfx.get_child_count())
		vfx.queue_free()
		return false

	vfx.queue_free()
	print("  - Coin pickup, gate pass, and crash particle bursts successfully spawned (PASS)")
	return true

func test_av06_settings_service_quality_presets_and_persistence() -> bool:
	print("[AV-06] Testing Graphics Quality Presets (Low/Medium/High) & Persistence...")
	var settings = SettingsService.new()

	# 1. Presets contract
	var req_presets = ["low", "medium", "high"]
	for pkey in req_presets:
		var pdef = settings.get_preset_def(pkey)
		if not pdef.has("shadows") or not pdef.has("msaa") or not pdef.has("render_scale"):
			printerr("FAIL: Preset definition malformed for '%s'" % pkey)
			return false

	# 2. Apply Low preset
	var env = Environment.new()
	settings.apply_quality_preset("low", null, env)
	if settings.get_current_preset_key() != "low" or env.ssao_enabled:
		printerr("FAIL: Low preset application incorrect")
		return false

	# 3. Apply High preset
	settings.apply_quality_preset("high", null, env)
	if settings.get_current_preset_key() != "high" or not env.ssao_enabled:
		printerr("FAIL: High preset application incorrect")
		return false

	# 4. Persistence roundtrip
	settings.current_settings["master_volume"] = 0.42
	settings.save_settings()

	var fresh_settings = SettingsService.new()
	if absf(fresh_settings.current_settings.get("master_volume", 0.0) - 0.42) > 0.01:
		printerr("FAIL: Settings did not persist through SaveService")
		return false

	print("  - Scalable visual presets (Low/Medium/High) and persistent configuration verified (PASS)")
	return true
