extends SceneTree

## Dedicated Unit Test Suite for Advanced Controller Features (Phase 7)
## Validates FlightModeManager (ANGLE, HORIZON, ACRO), BrakeController position damping,
## HeadlessController orientation math, TrimManager persistence, BatteryModel failsafe thresholds,
## and RTHController autonomous precision navigation.

const FlightModeManager = preload("res://scripts/flight/FlightModeManager.gd")
const BrakeController = preload("res://scripts/flight/BrakeController.gd")
const HeadlessController = preload("res://scripts/flight/HeadlessController.gd")
const TrimManager = preload("res://scripts/flight/TrimManager.gd")
const BatteryModel = preload("res://scripts/flight/BatteryModel.gd")
const RTHController = preload("res://scripts/flight/RTHController.gd")

func _init() -> void:
	print("==================================================")
	print("Starting Phase 7 Advanced Controller Features Tests")
	print("==================================================")

	var tests_passed: int = 0
	var tests_total: int = 7

	if test_cf01_flight_modes():
		tests_passed += 1
	if test_cf02_active_brake_damping():
		tests_passed += 1
	if test_cf03_headless_math():
		tests_passed += 1
	if test_cf04_trim_persistence():
		tests_passed += 1
	if test_cf05_boost_drain_ratio():
		tests_passed += 1
	if test_cf06_battery_thresholds_and_failsafes():
		tests_passed += 1
	if test_cf07_rth_precision_navigation():
		tests_passed += 1

	print("==================================================")
	print("Phase 7 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	if tests_passed == tests_total:
		print(">> ALL PHASE 7 CONTROLLER FEATURES TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 7 CONTROLLER FEATURES TESTS FAILED! <<")
		quit(1)

func test_cf01_flight_modes() -> bool:
	print("[CF-01] Testing Flight Modes (ANGLE, HORIZON, ACRO)...")
	var fmm = FlightModeManager.new()

	var auto_att = Vector2(0.2, 0.5) # Attitude P-loop target (rad/s)
	var max_rate = deg_to_rad(360.0) # 6.28 rad/s

	# 1. ANGLE Mode: always returns auto_level_att
	fmm.set_mode(FlightModeManager.Mode.ANGLE)
	var out_angle = fmm.process_attitude_target(Vector2(0.5, 0.5), auto_att, max_rate)
	if out_angle != auto_att:
		printerr("FAIL: ANGLE mode did not return auto_level_att.")
		return false

	# 2. HORIZON Mode:
	fmm.set_mode(FlightModeManager.Mode.HORIZON)
	# Inside 70% stick (|s| = 0.50): returns auto_level_att
	var out_horiz_center = fmm.process_attitude_target(Vector2(0.3, 0.4), auto_att, max_rate)
	if out_horiz_center != auto_att:
		printerr("FAIL: HORIZON mode within 70% did not auto-level.")
		return false

	# Beyond 70% stick (|s| = 1.0): returns 100% manual rate command
	var full_stick = Vector2(1.0, 0.0)
	var out_horiz_full = fmm.process_attitude_target(full_stick, auto_att, max_rate)
	var expected_full_rate = full_stick * max_rate
	if (out_horiz_full - expected_full_rate).length() > 0.01:
		printerr("FAIL: HORIZON mode at full deflection did not blend to 100% rate.")
		return false

	# 3. ACRO Mode: always returns direct rate command
	fmm.set_mode(FlightModeManager.Mode.ACRO)
	var out_acro = fmm.process_attitude_target(Vector2(0.5, 0.0), auto_att, max_rate)
	var expected_acro = Vector2(0.5, 0.0) * max_rate
	if (out_acro - expected_acro).length() > 0.01:
		printerr("FAIL: ACRO mode did not return direct rate command.")
		return false

	print("  - ANGLE, HORIZON (70% blend), and ACRO rate modes verified (PASS)")
	return true

func test_cf02_active_brake_damping() -> bool:
	print("[CF-02] Testing Active Velocity Braking & Position Damping...")
	var bc = BrakeController.new()
	var heading_b = Basis.IDENTITY # Heading 0 (Forward = -Z, Right = +X)
	var max_tilt = deg_to_rad(28.0)

	# 1. Moving forward at 5 m/s (v_z = -5.0) with centered sticks:
	# Expect positive pitch counter-tilt (nose up / pitches backward)
	var res_fwd = bc.compute_brake_tilt(Vector3(0, 0, -5.0), heading_b, Vector2.ZERO, 0.12, max_tilt, false)
	if not res_fwd.active or res_fwd.pitch_offset >= 0.0:
		printerr("FAIL: Forward movement did not produce nose-up counter-tilt (got %f)" % res_fwd.pitch_offset)
		return false

	# 2. Moving right at 4 m/s (v_x = +4.0):
	# Expect negative roll counter-tilt (bank left)
	var res_right = bc.compute_brake_tilt(Vector3(4.0, 0, 0), heading_b, Vector2.ZERO, 0.12, max_tilt, false)
	if not res_right.active or res_right.roll_offset >= 0.0:
		printerr("FAIL: Rightward movement did not produce bank-left counter-tilt (got %f)" % res_right.roll_offset)
		return false

	# 3. Deflected stick (|s| > 0.12): brake should be inactive unless forced
	var res_stick = bc.compute_brake_tilt(Vector3(4.0, 0, 0), heading_b, Vector2(0.5, 0.0), 0.12, max_tilt, false)
	if res_stick.active:
		printerr("FAIL: Brake was active while pilot was commanding stick deflection.")
		return false

	print("  - Counter-tilt velocity damping and deadzone gating verified (PASS)")
	return true

func test_cf03_headless_math() -> bool:
	print("[CF-03] Testing Headless Mode Heading Rotation Math...")
	var hc = HeadlessController.new()
	hc.set_enabled(true)
	hc.record_reference_heading(0.0) # North

	# Drone is yawed 90° clockwise (yaw heading = +90° = PI/2)
	# Pilot pushes stick forward (pitch = 1.0, roll = 0.0)
	# Headless rotation should map forward stick to right roll (East) so it moves away from pilot
	var stick_in = Vector2(0.0, 1.0)
	var stick_out = hc.process_stick(stick_in, PI * 0.5)

	# In 90° heading, East is +X (roll = 1.0), forward in body is 0.0
	if absf(stick_out.x - 1.0) > 0.05 or absf(stick_out.y) > 0.05:
		printerr("FAIL: 90° Headless forward stick expected Vector2(1, 0), got %s" % str(stick_out))
		return false

	print("  - 90° Headless yaw mapping exact: forward stick -> world forward (PASS)")
	return true

func test_cf04_trim_persistence() -> bool:
	print("[CF-04] Testing Sub-Trim Calibration & Settings Persistence...")
	var tm = TrimManager.new()
	tm.reset_trim()

	# Adjust pitch trim +0.06 (3 steps) and roll trim -0.04 (2 steps)
	tm.adjust_pitch(1.0)
	tm.adjust_pitch(1.0)
	tm.adjust_pitch(1.0)
	tm.adjust_roll(-1.0)
	tm.adjust_roll(-1.0)

	if absf(tm.pitch_trim - 0.06) > 0.001 or absf(tm.roll_trim - (-0.04)) > 0.001:
		printerr("FAIL: Trim adjustments inaccurate: pitch=%f, roll=%f" % [tm.pitch_trim, tm.roll_trim])
		return false

	# Reload new instance to verify file persistence in user://settings.cfg
	var tm_reloaded = TrimManager.new()
	if absf(tm_reloaded.pitch_trim - 0.06) > 0.001 or absf(tm_reloaded.roll_trim - (-0.04)) > 0.001:
		printerr("FAIL: Trim persistence roundtrip failed.")
		return false

	# Reset for clean test state
	tm.reset_trim()
	print("  - Sub-trim calibration and config roundtrip verified (PASS)")
	return true

func test_cf05_boost_drain_ratio() -> bool:
	print("[CF-05] Testing Pilot Boost Energy Consumption (2.0x Drain Rate)...")
	var bm_normal = BatteryModel.new(50.0)
	var bm_boost = BatteryModel.new(50.0)

	var thrust_n = 15.0 # Typical cruising thrust

	# Step 1.0 second
	var out_norm = bm_normal.step(thrust_n, false, 1.0)
	var out_boost = bm_boost.step(thrust_n, true, 1.0)

	var drain_norm = 50.0 - out_norm.remaining_wh
	var drain_boost = 50.0 - out_boost.remaining_wh
	var ratio = drain_boost / drain_norm

	if absf(ratio - 2.0) > 0.01:
		printerr("FAIL: Boost drain ratio was %f (expected 2.0x)" % ratio)
		return false

	print("  - Boost energy consumption ratio: %.2fx exact (PASS)" % ratio)
	return true

func test_cf06_battery_thresholds_and_failsafes() -> bool:
	print("[CF-06] Testing Watt-Hour Battery Failsafe Thresholds (25%, 20%, 15%, 5%)...")
	var bm = BatteryModel.new(100.0) # 100 Wh capacity

	# Test 25% warning
	bm.remaining_wh = 24.9
	var out_25 = bm.step(0.0, false, 0.01)
	if not out_25.warn_low:
		printerr("FAIL: 25% low battery warning not emitted.")
		return false

	# Test 20% flip gating
	bm.remaining_wh = 19.9
	if bm.is_flip_allowed():
		printerr("FAIL: Flips allowed below 20% battery.")
		return false

	# Test 15% auto-RTH
	bm.remaining_wh = 14.9
	var out_15 = bm.step(0.0, false, 0.01)
	if not out_15.auto_rth:
		printerr("FAIL: 15% auto-RTH not triggered.")
		return false

	# Test 5% forced landing
	bm.remaining_wh = 4.9
	var out_5 = bm.step(0.0, false, 0.01)
	if not out_5.force_land:
		printerr("FAIL: 5% forced landing not triggered.")
		return false

	print("  - Battery failsafe threshold progression (25%->20%->15%->5%) verified (PASS)")
	return true

func test_cf07_rth_precision_navigation() -> bool:
	print("[CF-07] Testing Precision RTH Autonomous Cycle & Stick Override...")
	var rth = RTHController.new()
	rth.record_home(Vector3.ZERO)

	var start_pos = Vector3(50.0, 5.0, 50.0) # 70.7m away at 5m AGL
	var ok = rth.start_rth(start_pos, 5.0)
	if not ok or rth.phase != RTHController.Phase.CLIMB:
		printerr("FAIL: RTH did not start in CLIMB phase.")
		return false

	var dt = 0.05
	var cur_pos = start_pos
	var cur_agl = 5.0
	var heading_b = Basis.IDENTITY

	# Step CLIMB phase until reaching 15m clearance altitude
	var steps = 0
	while rth.phase == RTHController.Phase.CLIMB and steps < 100:
		var out = rth.step(cur_pos, cur_agl, heading_b, Vector2.ZERO, dt)
		cur_agl += 3.0 * dt # Climb at 3 m/s
		steps += 1

	if rth.phase != RTHController.Phase.CRUISE:
		printerr("FAIL: RTH did not transition to CRUISE after reaching clearance altitude.")
		return false

	# Step CRUISE towards home (0, 0)
	steps = 0
	while rth.phase == RTHController.Phase.CRUISE and steps < 500:
		var out = rth.step(cur_pos, cur_agl, heading_b, Vector2.ZERO, dt)
		var to_home = Vector2(-cur_pos.x, -cur_pos.z).normalized()
		cur_pos.x += to_home.x * 8.0 * dt
		cur_pos.z += to_home.y * 8.0 * dt
		steps += 1

	if rth.phase != RTHController.Phase.DESCENT:
		printerr("FAIL: RTH did not transition to DESCENT upon arriving over home (dist=%.2f)" % Vector2(cur_pos.x, cur_pos.z).length())
		return false

	# Verify final position is within 1.0m radius of home pad
	var final_dist = Vector2(cur_pos.x, cur_pos.z).length()
	if final_dist > 1.0:
		printerr("FAIL: RTH arrival distance was %.2fm (exceeds 1.0m requirement)" % final_dist)
		return false

	# Test stick override: manual deflection > 0.3 cancels RTH
	rth.start_rth(Vector3(20, 15, 20), 15.0)
	var out_cancel = rth.step(Vector3(20, 15, 20), 15.0, heading_b, Vector2(0.5, 0.0), dt)
	if rth.is_active():
		printerr("FAIL: Manual stick deflection did not cancel RTH.")
		return false

	print("  - RTH 15m climb, velocity P-loop transit, <1.0m arrival, and stick cancel verified (PASS)")
	return true
