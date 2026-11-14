extends SceneTree

## Dedicated Unit & Acceptance Test Suite for FlightController (Phase 3)
## Validates pure-logic flight dynamics, sign conventions, collective altitude hold,
## X-quad mixer differential desaturation, heading frame transformations, and frame-rate independence.

const FlightController = preload("res://scripts/flight/FlightController.gd")
const ControlFrame = preload("res://scripts/input/ControlFrame.gd")

func _init() -> void:
	print("==================================================")
	print("Starting Phase 3 Flight Core Acceptance Tests")
	print("==================================================")

	var tests_passed: int = 0
	var tests_total: int = 8

	if test_fc01_pitch_sign():
		tests_passed += 1
	if test_fc02_roll_sign():
		tests_passed += 1
	if test_fc03_yaw_sign():
		tests_passed += 1
	if test_fc04_throttle_sign():
		tests_passed += 1
	if test_fc05_heading_90_relative():
		tests_passed += 1
	if test_fc06_altitude_hold_hover():
		tests_passed += 1
	if test_fc07_framerate_independence():
		tests_passed += 1
	if test_fc08_mixer_non_negative_and_desaturation():
		tests_passed += 1

	print("==================================================")
	print("Phase 3 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	if tests_passed == tests_total:
		print(">> ALL PHASE 3 FLIGHT CORE TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 3 FLIGHT CORE TESTS FAILED! <<")
		quit(1)

func test_fc01_pitch_sign() -> bool:
	print("[FC-01] Testing Pitch+ Directional Sign (Moves -Z in Heading Frame)...")
	var fc = FlightController.new()
	var cmd = ControlFrame.new(0.0, 0.0, 1.0, 0.0) # Pitch Forward = +1.0
	var body = Basis.IDENTITY # Level orientation
	var w = Vector3.ZERO
	var v = Vector3.ZERO

	# Step for 10 ticks to let motor spool
	var out: Dictionary = {}
	for _i in range(10):
		out = fc.step(body, w, v, cmd, {}, 1.0 / 120.0)

	var motors: PackedFloat32Array = out.motors
	var torque: Vector3 = out.torque_local

	# In Godot, forward = -Z. Pitching forward commands negative torque about X (raising rear, lowering nose).
	# Rear motors (RL=2, RR=3) must push harder than front motors (FL=0, FR=1)
	var rear_sum = motors[2] + motors[3]
	var front_sum = motors[0] + motors[1]

	if torque.x >= 0.0 or rear_sum <= front_sum:
		printerr("FAIL: Pitch+ did not produce negative pitch torque or rear thrust dominance. torque.x=", torque.x, " rear=", rear_sum, " front=", front_sum)
		return false

	print("  - Pitch+ torque.x = %.3f < 0, Rear thrust (%.2f N) > Front thrust (%.2f N) (PASS)" % [torque.x, rear_sum, front_sum])
	return true

func test_fc02_roll_sign() -> bool:
	print("[FC-02] Testing Roll+ Directional Sign (Roll-Right Moves +X in Heading Frame)...")
	var fc = FlightController.new()
	var cmd = ControlFrame.new(0.0, 0.0, 0.0, 1.0) # Roll Right = +1.0
	var body = Basis.IDENTITY
	var w = Vector3.ZERO
	var v = Vector3.ZERO

	var out: Dictionary = {}
	for _i in range(10):
		out = fc.step(body, w, v, cmd, {}, 1.0 / 120.0)

	var motors: PackedFloat32Array = out.motors
	var torque: Vector3 = out.torque_local

	# Roll right: Left motors (FL=0, RL=2) must push harder than right motors (FR=1, RR=3)
	# Producing bank to right (negative torque about Z in Godot coordinates)
	var left_sum = motors[0] + motors[2]
	var right_sum = motors[1] + motors[3]

	if torque.z >= 0.0 or left_sum <= right_sum:
		printerr("FAIL: Roll+ did not produce negative roll torque or left thrust dominance. torque.z=", torque.z, " left=", left_sum, " right=", right_sum)
		return false

	print("  - Roll+ torque.z = %.3f < 0, Left thrust (%.2f N) > Right thrust (%.2f N) (PASS)" % [torque.z, left_sum, right_sum])
	return true

func test_fc03_yaw_sign() -> bool:
	print("[FC-03] Testing Yaw+ Directional Sign (Yaw-Right = Negative Rotation About +Y)...")
	var fc = FlightController.new()
	var cmd = ControlFrame.new(0.0, 1.0, 0.0, 0.0) # Yaw Right = +1.0
	var body = Basis.IDENTITY
	var w = Vector3.ZERO
	var v = Vector3.ZERO

	var out: Dictionary = {}
	for _i in range(10):
		out = fc.step(body, w, v, cmd, {}, 1.0 / 120.0)

	var motors: PackedFloat32Array = out.motors
	var torque: Vector3 = out.torque_local

	# Yaw right: Clockwise from above = negative torque about +Y axis.
	# CCW motors (FR=1, RL=2) must push harder than CW motors (FL=0, RR=3)
	var ccw_sum = motors[1] + motors[2]
	var cw_sum = motors[0] + motors[3]

	if torque.y >= 0.0 or ccw_sum <= cw_sum:
		printerr("FAIL: Yaw+ did not produce negative yaw torque or CCW rotor dominance. torque.y=", torque.y, " ccw=", ccw_sum, " cw=", cw_sum)
		return false

	print("  - Yaw+ torque.y = %.3f < 0, CCW thrust (%.2f N) > CW thrust (%.2f N) (PASS)" % [torque.y, ccw_sum, cw_sum])
	return true

func test_fc04_throttle_sign() -> bool:
	print("[FC-04] Testing Throttle+ Directional Sign (Moves +Y Upward)...")
	var fc = FlightController.new()
	var body = Basis.IDENTITY
	var w = Vector3.ZERO
	var v = Vector3.ZERO

	# Neutral throttle (hover equilibrium: ~ mass * 9.81 = 1.25 * 9.81 = 12.26 N)
	var cmd_neutral = ControlFrame.new(0.0, 0.0, 0.0, 0.0)
	var out_neutral: Dictionary = {}
	for _i in range(20):
		out_neutral = fc.step(body, w, v, cmd_neutral, {}, 1.0 / 120.0)

	# Full climb throttle (+1.0)
	var fc_climb = FlightController.new()
	var cmd_climb = ControlFrame.new(1.0, 0.0, 0.0, 0.0)
	var out_climb: Dictionary = {}
	for _i in range(20):
		out_climb = fc_climb.step(body, w, v, cmd_climb, {}, 1.0 / 120.0)

	var neutral_force = out_neutral.force_local.y
	var climb_force = out_climb.force_local.y

	if climb_force <= neutral_force or climb_force < 18.0:
		printerr("FAIL: Throttle+ did not produce increased vertical force. climb=", climb_force, " neutral=", neutral_force)
		return false

	print("  - Hover force: %.2f N, Climb force: %.2f N > Hover (PASS)" % [neutral_force, climb_force])
	return true

func test_fc05_heading_90_relative() -> bool:
	print("[FC-05] Testing Heading-Relative Motion After 90° Yaw Rotation...")
	var fc = FlightController.new()
	# Rotate drone by 90° clockwise around +Y (heading = -90° / looking towards +X)
	var rotated_body = Basis(Vector3.UP, deg_to_rad(-90.0))
	var cmd = ControlFrame.new(0.0, 0.0, 1.0, 0.0) # Pitch Forward in Pilot's Heading frame
	var w = Vector3.ZERO
	var v = Vector3.ZERO

	var out: Dictionary = {}
	for _i in range(15):
		out = fc.step(rotated_body, w, v, cmd, {}, 1.0 / 120.0)

	var motors: PackedFloat32Array = out.motors
	# In the body frame, pitch forward still requires rear motors (2, 3) > front motors (0, 1)
	var rear_sum = motors[2] + motors[3]
	var front_sum = motors[0] + motors[1]

	if rear_sum <= front_sum:
		printerr("FAIL: 90° rotated drone did not maintain heading-relative pitch response. rear=", rear_sum, " front=", front_sum)
		return false

	print("  - 90° Yaw Frame Pitch: Rear (%.2f N) > Front (%.2f N) in heading frame (PASS)" % [rear_sum, front_sum])
	return true

func test_fc06_altitude_hold_hover() -> bool:
	print("[FC-06] Testing Altitude Hold Equilibrium & Zero-Drift at Centered Throttle...")
	var fc = FlightController.new()
	var body = Basis.IDENTITY
	var w = Vector3.ZERO
	var v = Vector3.ZERO # In equilibrium hover
	var cmd = ControlFrame.new(0.0, 0.0, 0.0, 0.0)

	var dt = 1.0 / 120.0
	var sim_pos_y: float = 3.0
	var sim_vel_y: float = 0.0

	# Step 10 seconds (1200 ticks at 120Hz) in 1D vertical simulation
	for _tick in range(1200):
		v.y = sim_vel_y
		var out = fc.step(body, w, v, cmd, {}, dt)
		var net_accel_y = (out.force_local.y - (fc.mass * fc.G)) / fc.mass
		sim_vel_y += net_accel_y * dt
		sim_pos_y += sim_vel_y * dt

	var drift = abs(sim_pos_y - 3.0)
	var final_speed = abs(sim_vel_y)

	if drift > 0.10 or final_speed > 0.05:
		printerr("FAIL: Altitude hold drifted excessively. final_pos=", sim_pos_y, " drift=", drift, " speed=", final_speed)
		return false

	print("  - 10s Altitude hold: final y=%.3fm, drift=%.3fm (< 0.10m), final vy=%.4fm/s (PASS)" % [sim_pos_y, drift, final_speed])
	return true

func test_fc07_framerate_independence() -> bool:
	print("[FC-07] Testing Frame-Rate Independence (1/60s vs 1/240s)...")
	# Simulate a 1-second climb at dt = 1/60
	var fc_60 = FlightController.new()
	var body = Basis.IDENTITY
	var w = Vector3.ZERO
	var v_60 = Vector3.ZERO
	var cmd = ControlFrame.new(0.5, 0.0, 0.0, 0.0)
	var pos_y_60: float = 0.0

	var dt_60 = 1.0 / 60.0
	for _i in range(60):
		var out = fc_60.step(body, w, v_60, cmd, {}, dt_60)
		var acc = (out.force_local.y - (fc_60.mass * fc_60.G)) / fc_60.mass
		v_60.y += acc * dt_60
		pos_y_60 += v_60.y * dt_60

	# Simulate the same 1-second climb at dt = 1/240
	var fc_240 = FlightController.new()
	var v_240 = Vector3.ZERO
	var pos_y_240: float = 0.0
	var dt_240 = 1.0 / 240.0
	for _i in range(240):
		var out = fc_240.step(body, w, v_240, cmd, {}, dt_240)
		var acc = (out.force_local.y - (fc_240.mass * fc_240.G)) / fc_240.mass
		v_240.y += acc * dt_240
		pos_y_240 += v_240.y * dt_240

	var diff = abs(pos_y_60 - pos_y_240)
	var rel_diff = diff / maxf(pos_y_60, 0.001)

	if rel_diff > 0.05:
		printerr("FAIL: Frame rate difference exceeded 5%: 60Hz pos=", pos_y_60, " 240Hz pos=", pos_y_240, " rel_diff=", rel_diff)
		return false

	print("  - 60Hz y=%.3fm vs 240Hz y=%.3fm: Difference = %.3f%% (< 5.0%%) (PASS)" % [pos_y_60, pos_y_240, rel_diff * 100.0])
	return true

func test_fc08_mixer_non_negative_and_desaturation() -> bool:
	print("[FC-08] Testing Mixer Non-Negativity & Saturation Desaturation...")
	var fc = FlightController.new()
	var body = Basis.IDENTITY
	var w = Vector3.ZERO
	var v = Vector3.ZERO

	# Extreme simultaneous pitch + roll + yaw input that would saturate individual motors
	var cmd = ControlFrame.new(1.0, 1.0, 1.0, 1.0)
	var out = fc.step(body, w, v, cmd, {}, 1.0 / 120.0)

	var motors: PackedFloat32Array = out.motors
	for i in range(4):
		if motors[i] < 0.0:
			printerr("FAIL: Motor ", i, " produced negative thrust: ", motors[i])
			return false
		if motors[i] > fc.max_motor + 0.001:
			printerr("FAIL: Motor ", i, " exceeded max thrust: ", motors[i], " > ", fc.max_motor)
			return false

	print("  - All 4 motors non-negative [%.2f, %.2f, %.2f, %.2f] and bounded <= %.1f N (PASS)" % [motors[0], motors[1], motors[2], motors[3], fc.max_motor])
	return true
