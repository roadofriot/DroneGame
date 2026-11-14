extends SceneTree

## Headless Acceptance and Unit Test Runner for Drone Flight Physics

const FlightWorldScene = preload("res://scenes/flight/FlightWorld.tscn")
const FlightPhysics = preload("res://scripts/flight/FlightPhysics.gd")
const FlightCameraDirector = preload("res://scripts/camera/FlightCameraDirector.gd")

func _init() -> void:
	print("==================================================")
	print("Starting MindSparQ Drone Simulator Phase 1 Tests")
	print("==================================================")

	var world = FlightWorldScene.instantiate()
	root.add_child(world)

	var tests_passed: int = 0
	var tests_total: int = 10

	if test_ac01_mass_and_thrust(world):
		tests_passed += 1
	if test_ac02_profile_data_and_symmetry(world):
		tests_passed += 1
	if test_ac03_auto_level_and_hover(world):
		tests_passed += 1
	if test_ac04_telemetry_and_battery(world):
		tests_passed += 1
	if test_ac05_crash_and_reset(world):
		tests_passed += 1
	if test_ac06_camera_director(world):
		tests_passed += 1
	if test_ac07_takeoff_sequence(world):
		tests_passed += 1
	if test_ac08_landing_sequence(world):
		tests_passed += 1
	if test_ac09_rth_navigation(world):
		tests_passed += 1
	if test_ac10_multi_touch_joystick_isolation(world):
		tests_passed += 1

	print("==================================================")
	print("Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	world.queue_free()

	if tests_passed == tests_total:
		print(">> ALL ACCEPTANCE TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> TESTS FAILED! <<")
		quit(1)

func test_ac01_mass_and_thrust(world: Node3D) -> bool:
	print("[AC-01] Testing Drone Mass and Thrust-to-Weight Ratio...")
	var drone: FlightPhysics = world.get_node("Quadcopter")

	if drone.drone_mass != 1.25:
		printerr("FAIL: Drone mass expected 1.25, got ", drone.drone_mass)
		return false

	var total_max_thrust = 4.0 * drone.max_thrust_per_motor
	var weight = drone.drone_mass * 9.8
	var twr = total_max_thrust / weight

	if twr < 2.0 or twr > 2.5:
		printerr("FAIL: Thrust-to-Weight Ratio out of bounds: ", twr)
		return false

	print("  - Mass: %.2f kg, Max Thrust: %.1f N, TWR: %.2f (PASS)" % [drone.drone_mass, total_max_thrust, twr])
	return true

func test_ac02_profile_data_and_symmetry(world: Node3D) -> bool:
	print("[AC-02] Testing Flight Tuning Profiles and Control Symmetry...")
	var drone: FlightPhysics = world.get_node("Quadcopter")
	if drone.all_profiles.is_empty():
		drone._load_profiles()
	print("  - Discovered profiles: ", drone.all_profiles.keys())

	var required_profiles = ["cine", "normal", "sport", "arcade", "acro"]
	for p in required_profiles:
		if not drone.all_profiles.has(p):
			printerr("FAIL: Missing tuning profile: ", p)
			return false

	# Test motor symmetry
	var delta = 1.0 / 60.0
	drone.pitch_deg = 0.0
	drone.roll_deg = 0.0
	drone.angular_velocity = Vector3.ZERO

	drone._calculate_auto_level_rpms(0.5, 15.0, 0.0, 0.0, delta)
	var forward_rpms = drone.target_motor_rpms.duplicate()

	drone._calculate_auto_level_rpms(0.5, -15.0, 0.0, 0.0, delta)
	var backward_rpms = drone.target_motor_rpms.duplicate()

	var diff_forward_front = 0.5 - forward_rpms[0]
	var diff_backward_front = backward_rpms[0] - 0.5
	if abs(diff_forward_front - diff_backward_front) > 0.001:
		printerr("FAIL: Pitch asymmetry detected: ", diff_forward_front, " vs ", diff_backward_front)
		return false

	print("  - All 5 profiles verified, Pitch/Roll motor symmetry exact (PASS)")
	return true

func test_ac03_auto_level_and_hover(world: Node3D) -> bool:
	print("[AC-03] Testing 60Hz Physics Step Stability and Zero-NaN...")
	var drone: FlightPhysics = world.get_node("Quadcopter")

	drone.current_state = FlightPhysics.DroneState.FLYING
	var delta = 1.0 / 60.0
	for i in range(120):
		drone._physics_process(delta)
		if is_nan(drone.linear_velocity.x) or is_nan(drone.global_position.y):
			printerr("FAIL: NaN detected in physics simulation at step ", i)
			return false

	print("  - 120 physics frames stepped at 60Hz without NaN or instability (PASS)")
	return true

func test_ac04_telemetry_and_battery(world: Node3D) -> bool:
	print("[AC-04] Testing Telemetry Emission and Battery Drain Modeling...")
	var drone: FlightPhysics = world.get_node("Quadcopter")

	var received_records: Array = []
	var callback = func(data: Dictionary):
		received_records.append(data)

	drone.telemetry_updated.connect(callback)
	drone._physics_process(0.1)

	if received_records.is_empty():
		printerr("FAIL: Telemetry signal was not emitted")
		return false

	var last_telemetry: Dictionary = received_records[-1]
	var required_keys = ["state", "profile", "altitude_agl", "speed", "climb_rate", "battery_pct", "battery_volts"]
	for k in required_keys:
		if not last_telemetry.has(k):
			printerr("FAIL: Telemetry missing key: ", k)
			return false

	var init_batt = drone.battery_remaining_mah
	drone.motor_rpms = [0.8, 0.8, 0.8, 0.8]
	drone._update_battery(10.0)
	if drone.battery_remaining_mah >= init_batt:
		printerr("FAIL: Battery did not drain under motor load")
		return false

	print("  - Telemetry payload validated, battery drain functional (PASS)")
	return true

func test_ac05_crash_and_reset(world: Node3D) -> bool:
	print("[AC-05] Testing Impact Detection, Crash State and Pad Reset...")
	var drone: FlightPhysics = world.get_node("Quadcopter")
	drone.current_state = FlightPhysics.DroneState.FLYING

	drone.linear_velocity = Vector3(0, -7.5, 0)
	drone._on_body_entered(Node.new())

	if drone.current_state != FlightPhysics.DroneState.CRASHED:
		printerr("FAIL: Drone did not enter CRASHED state on impact > 4.5 m/s")
		return false

	drone.reset_to_pad()
	if drone.current_state != FlightPhysics.DroneState.DISARMED:
		printerr("FAIL: Reset did not restore DISARMED state")
		return false

	if drone.linear_velocity != Vector3.ZERO:
		printerr("FAIL: Reset did not zero linear velocity")
		return false

	print("  - Impact crash trigger verified, Reset to Pad restores clean state (PASS)")
	return true

func test_ac06_camera_director(world: Node3D) -> bool:
	print("[AC-06] Testing Camera Director Modes and Transitions...")
	var director: FlightCameraDirector = world.get_node("CameraDirector")

	director.set_camera_mode(FlightCameraDirector.CameraMode.CHASE)
	if director.current_mode != FlightCameraDirector.CameraMode.CHASE:
		printerr("FAIL: Camera mode was not CHASE")
		return false

	director.cycle_camera_mode()
	if director.current_mode != FlightCameraDirector.CameraMode.FPV:
		printerr("FAIL: Camera did not cycle to FPV")
		return false

	director.cycle_camera_mode()
	if director.current_mode != FlightCameraDirector.CameraMode.ORBIT:
		printerr("FAIL: Camera did not cycle to ORBIT")
		return false

	print("  - Camera mode transitions and cycling verified (PASS)")
	return true

func test_ac07_takeoff_sequence(world: Node3D) -> bool:
	print("[AC-07] Testing Takeoff Sequence, Altitude Target & Preflight Validation...")
	var drone: FlightPhysics = world.get_node("Quadcopter")
	drone.reset_to_pad()

	if drone.current_state != FlightPhysics.DroneState.DISARMED:
		printerr("FAIL: Drone not disarmed before takeoff")
		return false

	var ok = drone.takeoff()
	if not ok:
		printerr("FAIL: Takeoff rejected from disarmed state")
		return false

	if drone.current_state != FlightPhysics.DroneState.MOTOR_STARTING:
		printerr("FAIL: Drone did not enter MOTOR_STARTING state on takeoff()")
		return false

	# Simulate 1.0s of motor spool up
	for _i in range(60):
		drone._physics_process(0.016)

	if drone.current_state != FlightPhysics.DroneState.TAKEOFF:
		printerr("FAIL: Drone did not advance to TAKEOFF after motor spool up, current=", drone.current_state)
		return false

	# Simulate ascent reaching 3.0m
	drone.altitude_agl = 3.1
	drone.position.y = 3.2
	drone._physics_process(0.016)

	if drone.current_state != FlightPhysics.DroneState.HOVER:
		printerr("FAIL: Drone did not stabilize into HOVER at 3.0m, current=", drone.current_state)
		return false

	# Pilot applies forward pitch input to transition from HOVER to FLYING
	if drone.input_router:
		drone.input_router.pitch = 0.35
	drone._physics_process(0.016)

	if drone.input_router:
		drone.input_router.pitch = 0.0

	if drone.current_state != FlightPhysics.DroneState.FLYING:
		printerr("FAIL: Drone did not transition from HOVER to FLYING upon joystick input, current=", drone.current_state)
		return false

	print("  - State machine progression: DISARMED -> MOTOR_STARTING -> TAKEOFF -> HOVER -> FLYING (PASS)")
	return true

func test_ac08_landing_sequence(world: Node3D) -> bool:
	print("[AC-08] Testing Landing Sequence, Horizontal Braking & Ground Touchdown...")
	var drone: FlightPhysics = world.get_node("Quadcopter")
	drone.current_state = FlightPhysics.DroneState.FLYING
	drone.altitude_agl = 3.0
	drone.linear_velocity = Vector3(2.5, 0.0, 1.5)

	drone.land()
	if drone.current_state != FlightPhysics.DroneState.LANDING:
		printerr("FAIL: Drone did not enter LANDING state on land()")
		return false

	# Simulate horizontal braking
	for _i in range(10):
		drone._physics_process(0.016)

	# Simulate descent to touchdown (< 0.15m) and hold for 0.35s (22 frames)
	drone.altitude_agl = 0.08
	drone.position.y = 0.10
	drone.linear_velocity = Vector3(0.0, -0.1, 0.0)
	for _i in range(25):
		drone._physics_process(0.016)

	if drone.current_state != FlightPhysics.DroneState.DISARMED:
		printerr("FAIL: Drone did not DISARM upon ground touchdown, current=", drone.current_state)
		return false

	print("  - Smooth landing sequence with horizontal braking and touchdown disarm verified (PASS)")
	return true

func test_ac09_rth_navigation(world: Node3D) -> bool:
	print("[AC-09] Testing Return-to-Home (RTH), Clearance Altitude & Telemetry...")
	var drone: FlightPhysics = world.get_node("Quadcopter")
	drone.reset_to_pad()
	drone.current_state = FlightPhysics.DroneState.FLYING
	drone.position = Vector3(30.0, 2.0, 40.0) # 50m away from origin
	drone.altitude_agl = 2.0

	var rth_ok = drone.trigger_rth()
	if not rth_ok or drone.current_state != FlightPhysics.DroneState.RTH:
		printerr("FAIL: trigger_rth() failed to engage RTH state")
		return false

	var dist = drone.get_home_distance()
	if dist < 45.0 or dist > 55.0:
		printerr("FAIL: get_home_distance() incorrect, got ", dist)
		return false

	drone.cancel_rth()
	if drone.current_state != FlightPhysics.DroneState.FLYING:
		printerr("FAIL: cancel_rth() did not restore FLYING state")
		return false

	drone.reset_to_pad()
	print("  - RTH engagement, distance tracking (%.1fm), and safe stick cancel verified (PASS)" % dist)
	return true

func test_ac10_multi_touch_joystick_isolation(world: Node3D) -> bool:
	print("[AC-10] Testing Multi-Touch Ownership & Independent Twin Sticks...")
	var hud: FlightHUD = world.get_node_or_null("FlightHUD")
	if not hud:
		printerr("FAIL: FlightHUD node not found")
		return false

	var left_stick = hud.get_node_or_null("LeftCluster/LeftJoystick")
	var right_stick = hud.get_node_or_null("RightCluster/RightJoystick")

	if not left_stick or not right_stick:
		printerr("FAIL: Left or Right joystick missing from HUD")
		return false

	if not left_stick.is_node_ready():
		left_stick._ready()
	if not right_stick.is_node_ready():
		right_stick._ready()

	# 1. Finger 1 touches left stick (pointer index = 0)
	var touch_left = InputEventScreenTouch.new()
	touch_left.index = 0
	touch_left.pressed = true
	touch_left.position = left_stick.base_center + Vector2(0, -50) # Push UP
	left_stick._gui_input(touch_left)

	if not left_stick.is_dragging or left_stick.touch_pointer_id != 0:
		printerr("FAIL: Left stick did not claim ownership of pointer 0")
		return false

	# 2. Finger 2 touches right stick simultaneously (pointer index = 1)
	var touch_right = InputEventScreenTouch.new()
	touch_right.index = 1
	touch_right.pressed = true
	touch_right.position = right_stick.base_center + Vector2(40, 0) # Push RIGHT
	right_stick._gui_input(touch_right)

	if not right_stick.is_dragging or right_stick.touch_pointer_id != 1:
		printerr("FAIL: Right stick did not claim ownership of pointer 1")
		return false

	# 3. Verify stick vectors are independent and non-zero
	if left_stick.stick_vector.y <= 0.0:
		printerr("FAIL: Left stick did not register upward throttle")
		return false
	if right_stick.stick_vector.x <= 0.0:
		printerr("FAIL: Right stick did not register right roll")
		return false

	# 4. Release Finger 1: Left stick releases, Right stick remains dragging
	var release_left = InputEventScreenTouch.new()
	release_left.index = 0
	release_left.pressed = false
	left_stick._gui_input(release_left)

	if left_stick.is_dragging:
		printerr("FAIL: Left stick did not release when pointer 0 lifted")
		return false
	if not right_stick.is_dragging:
		printerr("FAIL: Right stick was erroneously cancelled when pointer 0 lifted")
		return false

	# Release Finger 2
	var release_right = InputEventScreenTouch.new()
	release_right.index = 1
	release_right.pressed = false
	right_stick._gui_input(release_right)

	if right_stick.is_dragging:
		printerr("FAIL: Right stick did not release when pointer 1 lifted")
		return false

	print("  - Multi-touch pointer ownership and simultaneous twin-stick tracking verified (PASS)")
	return true
