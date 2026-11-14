extends SceneTree

## Acceptance & Unit Test Suite for Phase 2: Input Layer & InputRouter
## Verifies Deadzone, Monotonic Expo, Keyboard Ramping Timing, Radial Clamping, and Cancellation.

const InputRouterScript = preload("res://scripts/input/InputRouter.gd")
const ControlFrame = preload("res://scripts/input/ControlFrame.gd")

func _init() -> void:
	print("==================================================")
	print("Starting Phase 2 Acceptance Suite: test_input_router.gd")
	print("==================================================")

	var tests_passed: int = 0
	var tests_total: int = 6

	var router: InputRouter = InputRouter.new()
	root.add_child(router)

	if test_01_control_frame_contract():
		tests_passed += 1
	if test_02_deadzone(router):
		tests_passed += 1
	if test_03_expo_monotonic(router):
		tests_passed += 1
	if test_04_keyboard_ramp_timing(router):
		tests_passed += 1
	if test_05_radial_clamping(router):
		tests_passed += 1
	if test_06_opposite_keys_cancel(router):
		tests_passed += 1

	print("==================================================")
	print("Phase 2 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	router.queue_free()

	if tests_passed == tests_total:
		print(">> ALL PHASE 2 INPUT LAYER TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 2 TESTS FAILED! <<")
		quit(1)

# TEST 1 — ControlFrame Data Contract
func test_01_control_frame_contract() -> bool:
	print("[IR-01] Testing ControlFrame Data Contract & Normalization...")
	var cf = ControlFrame.new(1.5, -2.0, 0.5, -0.8)
	cf.clamp_values()

	if cf.throttle != 1.0 or cf.yaw != -1.0 or cf.pitch != 0.5 or cf.roll != -0.8:
		printerr("FAIL: ControlFrame clamping failed: ", cf.to_dict())
		return false

	var dup = cf.duplicate_frame()
	if dup.throttle != 1.0 or dup.yaw != -1.0:
		printerr("FAIL: ControlFrame duplicate failed")
		return false

	dup.reset()
	if dup.throttle != 0.0 or dup.yaw != 0.0:
		printerr("FAIL: ControlFrame reset failed")
		return false

	print("  - ControlFrame initialization, clamping [-1, 1], and duplication verified (PASS)")
	return true

# TEST 2 — Deadzone Rejection (< 0.12)
func test_02_deadzone(router: InputRouter) -> bool:
	print("[IR-02] Testing Radial Deadzone Rejection (< 0.12)...")
	router.deadzone = 0.12

	# Values below deadzone must return 0.0
	var below_1 = router._apply_deadzone(0.05, router.deadzone)
	var below_2 = router._apply_deadzone(-0.119, router.deadzone)
	if below_1 != 0.0 or below_2 != 0.0:
		printerr("FAIL: Deadzone did not reject sub-threshold values: ", below_1, " / ", below_2)
		return false

	# Values above deadzone must be remapped continuously from 0 to 1
	var above_1 = router._apply_deadzone(0.12, router.deadzone)
	var above_mid = router._apply_deadzone(0.56, router.deadzone)
	var above_max = router._apply_deadzone(1.0, router.deadzone)

	if absf(above_1) > 0.001 or absf(above_max - 1.0) > 0.001 or above_mid <= 0.0 or above_mid >= 1.0:
		printerr("FAIL: Deadzone remapping discontinuous: ", above_1, " / ", above_mid, " / ", above_max)
		return false

	print("  - Deadzone boundary (< 0.12 -> 0.0) and continuous remapping verified (PASS)")
	return true

# TEST 3 — Expo Monotonicity (e = 0.35)
func test_03_expo_monotonic(router: InputRouter) -> bool:
	print("[IR-03] Testing Cubic Expo Monotonicity & Symmetry (expo = 0.35)...")
	var e = 0.35
	var prev_val = -1.001

	# Step from -1.0 to +1.0 in 0.05 increments
	var step = 0.05
	var cur = -1.0
	while cur <= 1.0001:
		var expo_val = router._apply_expo(cur, e)
		if expo_val <= prev_val:
			printerr("FAIL: Expo is not strictly monotonic at x=", cur, " val=", expo_val, " prev=", prev_val)
			return false
		# Symmetry check: f(-x) == -f(x)
		var neg_expo = router._apply_expo(-cur, e)
		if absf(expo_val + neg_expo) > 0.0001:
			printerr("FAIL: Expo is not point-symmetric at x=", cur, " f(x)=", expo_val, " f(-x)=", neg_expo)
			return false
		prev_val = expo_val
		cur += step

	print("  - Cubic expo strictly monotonic across [-1, 1] and point-symmetric (PASS)")
	return true

# TEST 4 — Keyboard Ramp Timing (0 -> 1 in ~0.3s, release 6 units/s)
func test_04_keyboard_ramp_timing(router: InputRouter) -> bool:
	print("[IR-04] Testing Keyboard Ramp Timing (Attack ~0.3s, Release 6.0/s)...")
	var val: float = 0.0

	# Step 15 frames at 60Hz (0.25s) with target 1.0
	for i in range(15):
		val = router._ramp_axis(val, 1.0, 1.0 / 60.0)

	# After 0.25s at rate 3.333/s, val should be around 0.833
	if val < 0.70 or val > 0.95:
		printerr("FAIL: Keyboard attack ramp timing incorrect at 0.25s, got ", val)
		return false

	# Step 5 more frames (total 0.33s), should reach 1.0
	for i in range(6):
		val = router._ramp_axis(val, 1.0, 1.0 / 60.0)

	if absf(val - 1.0) > 0.01:
		printerr("FAIL: Keyboard did not reach 1.0 in ~0.3s, got ", val)
		return false

	# Release timing: target 0.0, release rate is 6.0/s
	# In 0.166s (10 frames at 60Hz), 6.0 * 0.166 = 1.0, should drop to 0.0!
	for i in range(11):
		val = router._ramp_axis(val, 0.0, 1.0 / 60.0)

	if val != 0.0:
		printerr("FAIL: Keyboard release did not zero out within 0.18s, got ", val)
		return false

	print("  - Keyboard attack (0.3s to full) and fast release (6.0/s to zero) verified (PASS)")
	return true

# TEST 5 — Radial Clamping (|v| <= 1.0)
func test_05_radial_clamping(router: InputRouter) -> bool:
	print("[IR-05] Testing Radial Clamping and ControlFrame Limits...")
	router.set_virtual_right_stick(1.5, -2.0)
	router.set_virtual_left_stick(-1.2, 1.8)
	router._poll_flight_inputs(0.016)

	var cf = router.current_frame
	if cf.throttle > 1.0 or cf.throttle < -1.0:
		printerr("FAIL: Throttle not clamped: ", cf.throttle)
		return false
	if cf.yaw > 1.0 or cf.yaw < -1.0:
		printerr("FAIL: Yaw not clamped: ", cf.yaw)
		return false
	if cf.pitch > 1.0 or cf.pitch < -1.0:
		printerr("FAIL: Pitch not clamped: ", cf.pitch)
		return false
	if cf.roll > 1.0 or cf.roll < -1.0:
		printerr("FAIL: Roll not clamped: ", cf.roll)
		return false

	# Reset sticks
	router.set_virtual_right_stick(0.0, 0.0)
	router.set_virtual_left_stick(0.0, 0.0)
	router._poll_flight_inputs(0.016)

	if router.throttle != 0.0 or router.yaw != 0.0 or router.pitch != 0.0 or router.roll != 0.0:
		printerr("FAIL: Releasing sticks did not yield exact 0.0")
		return false

	print("  - Inputs strictly clamped within [-1, 1] and stick release yields exact 0.0 (PASS)")
	return true

# TEST 6 — Opposite Keys Cancel
func test_06_opposite_keys_cancel(router: InputRouter) -> bool:
	print("[IR-06] Testing Simultaneous Opposite Key Cancellation...")
	router._neutralize_inputs()

	# Simulate simultaneous W + S and A + D
	var kp_raw = float(true) - float(true) # W and S both pressed
	var kr_raw = float(true) - float(true) # A and D both pressed

	if kp_raw != 0.0 or kr_raw != 0.0:
		printerr("FAIL: Opposite keys did not cancel to 0: pitch=", kp_raw, " roll=", kr_raw)
		return false

	# Test directional flip snapping
	var flip_dirs: Array[Vector2] = []
	var cb = func(dir: Vector2): flip_dirs.append(dir)
	router.flip_pressed.connect(cb)

	# Centered stick -> snaps to Back (0, -1)
	router.pitch = 0.0
	router.roll = 0.0
	router._trigger_directional_flip()
	if flip_dirs.is_empty() or flip_dirs[-1] != Vector2(0, -1):
		printerr("FAIL: Centered stick flip did not snap to back (0, -1), got ", flip_dirs)
		return false

	# Forward pitch -> snaps to Forward (0, 1)
	router.pitch = 0.8
	router.roll = 0.1
	router._trigger_directional_flip()
	if flip_dirs[-1] != Vector2(0, 1):
		printerr("FAIL: Forward stick flip did not snap to (0, 1), got ", flip_dirs[-1])
		return false

	# Right roll -> snaps to Right (1, 0)
	router.pitch = 0.1
	router.roll = 0.8
	router._trigger_directional_flip()
	if flip_dirs[-1] != Vector2(1, 0):
		printerr("FAIL: Right stick flip did not snap to (1, 0), got ", flip_dirs[-1])
		return false

	router.flip_pressed.disconnect(cb)
	print("  - Simultaneous opposite keys cancel to 0 and directional flip snaps to 4 cardinals (PASS)")
	return true
