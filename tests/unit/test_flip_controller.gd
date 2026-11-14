extends SceneTree

## Dedicated Unit Test Suite for FlipController (Phase 5)
## Validates 4-way cardinal rotation axes, altitude/battery/acro preconditions,
## inversion thrust cutoff, and complete simulated 4-direction flip cycles.

const FlipController = preload("res://scripts/flight/FlipController.gd")

func _init() -> void:
	print("==================================================")
	print("Starting Phase 5 Flip Controller Tests")
	print("==================================================")

	var tests_passed: int = 0
	var tests_total: int = 7

	if test_flp01_cardinal_rotation_axes():
		tests_passed += 1
	if test_flp02_low_altitude_rejection():
		tests_passed += 1
	if test_flp03_low_battery_rejection():
		tests_passed += 1
	if test_flp04_acro_mode_rejection():
		tests_passed += 1
	if test_flp05_inversion_thrust_cut():
		tests_passed += 1
	if test_flp06_full_flip_simulation_all_4_directions():
		tests_passed += 1
	if test_flp07_timeout_safety_handoff():
		tests_passed += 1

	print("==================================================")
	print("Phase 5 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	if tests_passed == tests_total:
		print(">> ALL PHASE 5 FLIP CONTROLLER TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 5 FLIP CONTROLLER TESTS FAILED! <<")
		quit(1)

func test_flp01_cardinal_rotation_axes() -> bool:
	print("[FLP-01] Testing 4-Way Cardinal Rotation Axes in Body Frame...")

	# Front flip: -X (nose down)
	var axis_front = FlipController.dir_to_axis(Vector2(0, 1))
	if axis_front != Vector3(-1, 0, 0):
		printerr("FAIL: Front flip axis expected Vector3(-1, 0, 0), got %s" % str(axis_front))
		return false

	# Back flip: +X (nose up)
	var axis_back = FlipController.dir_to_axis(Vector2(0, -1))
	if axis_back != Vector3(1, 0, 0):
		printerr("FAIL: Back flip axis expected Vector3(1, 0, 0), got %s" % str(axis_back))
		return false

	# Left roll: +Z (bank left)
	var axis_left = FlipController.dir_to_axis(Vector2(-1, 0))
	if axis_left != Vector3(0, 0, 1):
		printerr("FAIL: Left roll axis expected Vector3(0, 0, 1), got %s" % str(axis_left))
		return false

	# Right roll: -Z (bank right)
	var axis_right = FlipController.dir_to_axis(Vector2(1, 0))
	if axis_right != Vector3(0, 0, -1):
		printerr("FAIL: Right roll axis expected Vector3(0, 0, -1), got %s" % str(axis_right))
		return false

	# Centered stick defaults to back flip (+X)
	var axis_neutral = FlipController.dir_to_axis(Vector2(0, 0))
	if axis_neutral != Vector3(1, 0, 0):
		printerr("FAIL: Neutral stick expected back flip Vector3(1, 0, 0), got %s" % str(axis_neutral))
		return false

	print("  - All 4 cardinal axes match Godot coordinate system conventions (PASS)")
	return true

func test_flp02_low_altitude_rejection() -> bool:
	print("[FLP-02] Testing Low-Altitude Rejection (Precondition: AGL >= 4.0m)...")
	var fc = FlipController.new()

	# Under 4.0m -> Rejected
	var rejected = fc.request(Vector2(0, 1), 3.9, 1.0, false)
	if rejected or fc.is_active():
		printerr("FAIL: Flip allowed at 3.9m AGL (below 4.0m minimum).")
		return false

	# At or above 4.0m -> Accepted
	var accepted = fc.request(Vector2(0, 1), 4.0, 1.0, false)
	if not accepted or not fc.is_active() or fc.phase != FlipController.Phase.BOOST:
		printerr("FAIL: Flip rejected at 4.0m AGL.")
		return false

	print("  - Altitude safety gate enforced at exactly 4.0m AGL (PASS)")
	return true

func test_flp03_low_battery_rejection() -> bool:
	print("[FLP-03] Testing Low-Battery Rejection (Precondition: Battery >= 20%)...")
	var fc = FlipController.new()

	# Under 20% -> Rejected
	var rejected = fc.request(Vector2(0, -1), 10.0, 0.19, false)
	if rejected or fc.is_active():
		printerr("FAIL: Flip allowed at 19% battery.")
		return false

	# At or above 20% -> Accepted
	var accepted = fc.request(Vector2(0, -1), 10.0, 0.20, false)
	if not accepted or not fc.is_active():
		printerr("FAIL: Flip rejected at 20% battery.")
		return false

	print("  - Battery threshold 20% strictly enforced (PASS)")
	return true

func test_flp04_acro_mode_rejection() -> bool:
	print("[FLP-04] Testing Acro Mode Rejection (Flip disabled in pure manual rate mode)...")
	var fc = FlipController.new()

	var rejected = fc.request(Vector2(1, 0), 10.0, 1.0, true)
	if rejected or fc.is_active():
		printerr("FAIL: Flip allowed in Acro mode.")
		return false

	print("  - Acro mode flip request safely rejected (PASS)")
	return true

func test_flp05_inversion_thrust_cut() -> bool:
	print("[FLP-05] Testing Inversion Thrust Cutoff (up_y < 0 -> thrust_scale = 0)...")
	var fc = FlipController.new()
	fc.configure(720.0, 0.12, 0.90)
	fc.request(Vector2(0, 1), 10.0, 1.0, false)

	# Step past BOOST phase (0.12s)
	fc.step(Vector3.ZERO, 1.0, 0.13)
	if fc.phase != FlipController.Phase.ROTATE:
		printerr("FAIL: FlipController failed to enter ROTATE phase.")
		return false

	# Test upright during ROTATE: up_y = 0.8 -> thrust_scale = 0.5
	var out_upright = fc.step(Vector3.ZERO, 0.8, 0.01)
	if out_upright.get("thrust_scale", 1.0) != 0.5:
		printerr("FAIL: Upright thrust_scale in ROTATE expected 0.5, got %s" % str(out_upright.get("thrust_scale")))
		return false

	# Test inverted during ROTATE: up_y = -0.5 -> thrust_scale = 0.0
	var out_inverted = fc.step(Vector3.ZERO, -0.5, 0.01)
	if out_inverted.get("thrust_scale", 1.0) != 0.0:
		printerr("FAIL: Inverted thrust_scale in ROTATE expected 0.0, got %s" % str(out_inverted.get("thrust_scale")))
		return false

	print("  - Inverted thrust cutoff verified: 0.0 when up_y < 0, 0.5 when upright (PASS)")
	return true

func test_flp06_full_flip_simulation_all_4_directions() -> bool:
	print("[FLP-06] Testing Full Flip Simulation for All 4 Cardinal Directions...")
	var directions: Array = [
		{"name": "Front Flip", "dir": Vector2(0, 1), "axis": Vector3(-1, 0, 0)},
		{"name": "Back Flip", "dir": Vector2(0, -1), "axis": Vector3(1, 0, 0)},
		{"name": "Left Roll", "dir": Vector2(-1, 0), "axis": Vector3(0, 0, 1)},
		{"name": "Right Roll", "dir": Vector2(1, 0), "axis": Vector3(0, 0, -1)}
	]

	var dt: float = 1.0 / 120.0 # 120 Hz simulation tick

	for item in directions:
		var fc = FlipController.new()
		fc.configure(720.0, 0.12, 0.90)
		var ok = fc.request(item["dir"], 10.0, 1.0, false)
		if not ok:
			printerr("FAIL: Request rejected for %s" % item["name"])
			return false

		var sim_time: float = 0.0
		var alt: float = 10.0
		var vert_vel: float = 0.0
		var current_basis: Basis = Basis.IDENTITY
		var w_body: Vector3 = Vector3.ZERO
		var min_alt: float = alt

		while fc.is_active() and sim_time < 2.0:
			var up_y = current_basis.y.y
			var out = fc.step(w_body, up_y, dt)

			# Simulating flight dynamics response:
			var target_w = out.get("w_target", Vector3.ZERO)
			if fc.phase == FlipController.Phase.RECOVER:
				# Angle-mode recovery: torque drives current_basis.y toward Vector3.UP
				var err = current_basis.transposed() * current_basis.y.cross(Vector3.UP)
				target_w = Vector3(err.x, 0.0, err.z) * 12.0

			# Rate controller response (tau ~ 0.03s)
			w_body += (target_w - w_body) * (dt / 0.03)

			# Integrate rotation
			if w_body.length_squared() > 0.0001:
				var rot_axis = w_body.normalized()
				var rot_angle = w_body.length() * dt
				current_basis = current_basis * Basis(rot_axis, rot_angle)
				current_basis = current_basis.orthonormalized()

			# Integrate vertical physics (gravity = 9.81, hover thrust = 9.81)
			var thrust_s = out.get("thrust_scale", 1.0)
			var effective_up = maxf(0.0, current_basis.y.y)
			var thrust_accel = 9.81 * thrust_s * effective_up
			var total_accel_y = thrust_accel - 9.81

			vert_vel += total_accel_y * dt
			alt += vert_vel * dt
			min_alt = minf(min_alt, alt)
			sim_time += dt

		var alt_loss = 10.0 - min_alt
		var final_up_y = current_basis.y.y

		if fc.is_active():
			printerr("FAIL: %s did not finish (exceeded 2.0s)." % item["name"])
			return false

		if sim_time > 1.2:
			printerr("FAIL: %s took %.3fs (exceeds 1.2s acceptance limit)." % [item["name"], sim_time])
			return false

		if alt_loss > 2.0:
			printerr("FAIL: %s altitude loss was %.2fm (exceeds 2.0m limit)." % [item["name"], alt_loss])
			return false

		if final_up_y < 0.90:
			printerr("FAIL: %s final up_y is %.2f (must be > 0.90 upright)." % [item["name"], final_up_y])
			return false

		print("  - %s completed in %.2fs (Altitude Loss: %.2fm, Final up.y: %.2f) (PASS)" % [
			item["name"], sim_time, alt_loss, final_up_y
		])

	return true

func test_flp07_timeout_safety_handoff() -> bool:
	print("[FLP-07] Testing Safety Timeout Handoff to Normal Flight (No Forced Crash)...")
	var fc = FlipController.new()
	fc.configure(720.0, 0.12, 0.90)
	fc.request(Vector2(0, 1), 10.0, 1.0, false)

	# Simulate a drone that is artificially stuck inverted with high angular rate
	# Force it through BOOST
	fc.step(Vector3.ZERO, 1.0, 0.13)
	if fc.phase != FlipController.Phase.ROTATE:
		printerr("FAIL: Did not enter ROTATE phase.")
		return false

	# Step ROTATE for 1.55s without completing angle
	var out = fc.step(Vector3.ZERO, -1.0, 1.55)
	if fc.phase != FlipController.Phase.RECOVER:
		printerr("FAIL: ROTATE timeout did not transition to RECOVER.")
		return false

	# Step RECOVER for 1.55s without reaching upright
	fc.step(Vector3(5.0, 0.0, 0.0), -1.0, 1.55)
	if fc.is_active():
		printerr("FAIL: RECOVER timeout did not hand back to IDLE.")
		return false

	print("  - Timeout safety handoff gracefully returns to IDLE after 1.5s per phase (PASS)")
	return true
