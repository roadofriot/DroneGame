class_name FlightController
extends RefCounted

## FlightController: Pure-logic, physically consistent flight controller for MindSparQ Drone Simulator.
## Handles attitude P-loop in heading frame, collective climb rate with altitude hold,
## X-quad motor mixing with saturation desaturation, and first-order motor spool lag.
## ZERO scene-tree/node access.

const ControlFrame = preload("res://scripts/input/ControlFrame.gd")

const G: float = 9.81

# Physical Parameters (loaded from config)
var mass: float = 1.25
var inertia: Vector3 = Vector3(0.012, 0.02, 0.012) # x=pitch, y=yaw, z=roll
var arm_d: float = 0.12 # Moment arm x/z offset (m)
var yaw_k: float = 0.016 # Yaw torque / motor thrust ratio
var max_motor: float = 7.0 # Max thrust per motor (N) -> 4 * 7 = 28 N (TWR 2.28)
var motor_tau: float = 0.04 # Motor electrical/mechanical lag time constant (s)

# Flight Profile Tuning Parameters
var max_tilt: float = deg_to_rad(28.0)
var max_yaw_rate: float = deg_to_rad(120.0)
var max_climb: float = 6.0
var max_descent: float = 4.5
var kp_att: float = 8.0 # Attitude error -> target angular rate
var kp_rate: float = 35.0 # Rate error -> angular acceleration -> torque
var kd_rate: float = 0.35 # Rate D-damping factor for oscillation suppression
var kp_climb: float = 4.0 # Vertical speed error -> collective acceleration
var ki_climb: float = 1.5 # Vertical speed error integral gain
var altitude_hold: bool = true
var is_acro: bool = false

# Internal State
var motor: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0]) # [0:FL, 1:FR, 2:RL, 3:RR]
var _heading: float = 0.0
var _climb_integral: float = 0.0
var _prev_rate_error: Vector3 = Vector3.ZERO

func _init() -> void:
	reset()

func reset() -> void:
	motor = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	_heading = 0.0
	_climb_integral = 0.0
	_prev_rate_error = Vector3.ZERO

func configure(profile_data: Dictionary, physical_data: Dictionary = {}) -> void:
	if not physical_data.is_empty():
		mass = physical_data.get("mass_kg", mass)
		arm_d = physical_data.get("arm_d", physical_data.get("arm_length_m", 0.22) * 0.55)
		max_motor = physical_data.get("max_motor_thrust_n", physical_data.get("max_total_thrust_n", 28.0) / 4.0)
		yaw_k = physical_data.get("yaw_k", yaw_k)
		motor_tau = physical_data.get("motor_tau", motor_tau)
		var in_arr = physical_data.get("inertia", [])
		if in_arr is Array and in_arr.size() == 3:
			inertia = Vector3(in_arr[0], in_arr[1], in_arr[2])

	if not profile_data.is_empty():
		max_tilt = deg_to_rad(profile_data.get("max_tilt_deg", 28.0))
		max_yaw_rate = deg_to_rad(profile_data.get("max_yaw_rate_deg", 120.0))
		max_climb = profile_data.get("max_climb_mps", 6.0)
		max_descent = profile_data.get("max_descent_mps", 4.5)
		kp_att = profile_data.get("kp_att", profile_data.get("auto_level_strength", 8.0))
		kp_rate = profile_data.get("kp_rate", 35.0)
		kp_climb = profile_data.get("kp_climb", 4.0)
		altitude_hold = profile_data.get("altitude_hold", true)
		is_acro = (profile_data.get("name", "") == "Acro / Manual" or kp_att <= 0.001)

## Step function: Computes physical local force, torque, and motor thrusts.
## - body: Orthonormalized basis of drone (forward = -body.z, up = body.y, right = body.x)
## - w_world: Angular velocity in world space
## - v_world: Linear velocity in world space
## - cmd: Normalized ControlFrame (throttle, yaw, pitch, roll in [-1, 1])
## - override: Optional override dictionary (e.g. from Stunt/Flip controller: w_target, thrust_scale)
## - dt: Simulation timestep
func step(body: Basis, w_world: Vector3, v_world: Vector3,
		cmd: RefCounted, override: Dictionary, dt: float) -> Dictionary:
	var safe_dt: float = maxf(dt, 0.001)
	var up: Vector3 = body.y
	var yaw_basis: Basis = _heading_basis(body)

	var w_local: Vector3 = body.transposed() * w_world
	var w_target: Vector3 = Vector3.ZERO
	var thrust: float = 0.0

	if is_acro:
		# Acro mode: Direct rate control
		w_target.x = -cmd.pitch * max_tilt
		w_target.z = -cmd.roll * max_tilt
		w_target.y = -cmd.yaw * max_yaw_rate
		var hover_thrust: float = mass * G
		thrust = hover_thrust * (1.0 + cmd.throttle * 0.95)
	else:
		# 1) Angle mode: sticks define desired body-up in heading (yaw) frame
		# Godot coordinates: forward = -Z, right = +X, up = +Y
		# pitch > 0 (forward) tilts body-up toward -Z
		# roll > 0 (right) tilts body-up toward +X
		var desired_up: Vector3 = yaw_basis * Vector3(
			sin(cmd.roll * max_tilt),
			1.0,
			-sin(cmd.pitch * max_tilt)
		).normalized()

		# 2) Attitude error -> rate target (in body frame)
		var err_local: Vector3 = body.transposed() * up.cross(desired_up)
		w_target = Vector3(err_local.x, 0.0, err_local.z) * kp_att
		# Yaw stick = yaw-rate target (yaw-right = negative rotation about +Y)
		w_target.y = -cmd.yaw * max_yaw_rate

		# 3) Collective: throttle stick = climb-rate command (center = altitude hold)
		var vz_cmd: float = 0.0
		if cmd.throttle >= 0.0:
			vz_cmd = cmd.throttle * max_climb
		else:
			vz_cmd = cmd.throttle * max_descent

		var vz_err: float = vz_cmd - v_world.y
		if absf(cmd.throttle) > 0.06:
			_climb_integral = move_toward(_climb_integral, 0.0, 4.0 * safe_dt)
		elif altitude_hold:
			_climb_integral = clampf(_climb_integral + vz_err * safe_dt * ki_climb, -2.5, 2.5)

		var az: float = G + kp_climb * vz_err + _climb_integral
		thrust = mass * maxf(0.1, az) / maxf(up.y, 0.5) # Tilt compensation

	# 4) Flip / Stunt overrides
	if not override.is_empty():
		if override.has("w_target"):
			w_target = override.w_target
		if override.has("thrust_scale"):
			thrust = mass * G * override.thrust_scale

	# 5) Rate PID-loop -> angular acceleration -> torque with D-term damping
	var rate_error: Vector3 = w_target - w_local
	var d_rate: Vector3 = (rate_error - _prev_rate_error) / safe_dt
	_prev_rate_error = rate_error
	d_rate.x = clampf(d_rate.x, -50.0, 50.0)
	d_rate.y = clampf(d_rate.y, -50.0, 50.0)
	d_rate.z = clampf(d_rate.z, -50.0, 50.0)

	var damping_scale: float = kd_rate * kp_rate * 0.04
	var torque: Vector3 = (rate_error * kp_rate + d_rate * damping_scale) * inertia

	# 6) Motor mixer & first-order spool lag
	return _mix(thrust, torque, safe_dt)

func _heading_basis(body: Basis) -> Basis:
	var f: Vector3 = -body.z
	f.y = 0.0
	if f.length_squared() > 0.001:
		_heading = atan2(-f.x, -f.z)
	return Basis(Vector3.UP, _heading)

## X-Quad Mixer for motor configuration:
## Motor 0 (FL): Front-Left  [x = -d, z = -d, CW]
## Motor 1 (FR): Front-Right [x = +d, z = -d, CCW]
## Motor 2 (RL): Rear-Left   [x = -d, z = +d, CCW]
## Motor 3 (RR): Rear-Right  [x = +d, z = +d, CW]
func _mix(T: float, tq: Vector3, dt: float) -> Dictionary:
	var d: float = arm_d
	var four_d: float = 4.0 * d
	var four_yk: float = 4.0 * yaw_k

	# Nominal thrust allocation per motor
	var f: PackedFloat32Array = PackedFloat32Array([
		T / 4.0 + tq.x / four_d - tq.z / four_d + tq.y / four_yk, # 0: FL
		T / 4.0 + tq.x / four_d + tq.z / four_d - tq.y / four_yk, # 1: FR
		T / 4.0 - tq.x / four_d - tq.z / four_d - tq.y / four_yk, # 2: RL
		T / 4.0 - tq.x / four_d + tq.z / four_d + tq.y / four_yk  # 3: RR
	])

	# Saturation desaturation: shift all motors equally if maximum thrust is exceeded,
	# preserving commanded control torque differentials.
	var hi: float = maxf(maxf(f[0], f[1]), maxf(f[2], f[3]))
	if hi > max_motor:
		var excess: float = hi - max_motor
		for i in range(4):
			f[i] -= excess

	# Motor lag filter (tau ~ 0.04s) & non-negative clamping
	var a: float = 1.0 - exp(-dt / motor_tau)
	var force_y: float = 0.0
	for i in range(4):
		var target_f: float = clampf(f[i], 0.0, max_motor)
		motor[i] += (target_f - motor[i]) * a
		force_y += motor[i]

	# Reconstruct actual local torques produced by the lagged motor thrusts
	var actual_torque: Vector3 = Vector3(
		d * (motor[0] + motor[1] - motor[2] - motor[3]),       # Pitch (about X)
		yaw_k * (motor[0] - motor[1] - motor[2] + motor[3]),   # Yaw (about Y)
		d * (-motor[0] + motor[1] - motor[2] + motor[3])       # Roll (about Z)
	)

	return {
		"force_local": Vector3(0.0, force_y, 0.0),
		"torque_local": actual_torque,
		"motors": motor.duplicate()
	}
