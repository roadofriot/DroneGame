class_name FlightPhysics
extends RigidBody3D

## FlightPhysics: Deterministic 60Hz quadcopter flight simulation.
## Implements 4-motor thrust dynamics, auto-level PID, ground effect, and battery consumption.

signal telemetry_updated(data: Dictionary)
signal flight_mode_changed(mode_name: String)
signal drone_state_changed(state_name: String)
signal drone_crashed(impact_force: float)
signal landing_completed

enum DroneState { DISARMED, TAKING_OFF, FLYING, LANDING, CRASHED }

@export var input_router: InputRouter
@export var raycast_ground: RayCast3D
@export var stunt_engine: StuntEngine

# Physical Constants
@export var drone_mass: float = 1.25
@export var max_thrust_per_motor: float = 7.0 # 4 * 7 = 28 N (TWR ~ 2.28)
@export var motor_spool_speed: float = 12.0 # Spool response factor
@export var linear_drag: float = 0.55
@export var angular_drag: float = 5.0
@export var ground_effect_dist: float = 1.5
@export var ground_effect_mult: float = 0.25

# Flight State
var current_state: DroneState = DroneState.DISARMED
var active_profile_name: String = "normal"
var active_profile: Dictionary = {}
var all_profiles: Dictionary = {}

# Motor RPMs [0.0 .. 1.0] for FL, FR, RL, RR
var motor_rpms: Array[float] = [0.0, 0.0, 0.0, 0.0]
var target_motor_rpms: Array[float] = [0.0, 0.0, 0.0, 0.0]

# Battery System
var battery_capacity_mah: float = 3800.0
var battery_remaining_mah: float = 3800.0
var battery_percent: float = 100.0
var battery_voltage: float = 15.2

# Telemetry
var altitude_agl: float = 0.0 # Above Ground Level
var altitude_msl: float = 0.0 # Mean Sea Level (Y coord)
var ground_speed: float = 0.0
var climb_rate: float = 0.0
var heading_deg: float = 0.0
var pitch_deg: float = 0.0
var roll_deg: float = 0.0

# Auto-Takeoff / Land Automation
var auto_target_altitude: float = 1.8
var auto_timer: float = 0.0
var spawn_transform: Transform3D

# PID Controllers for Auto-Level
var pitch_pid_p: float = 6.0
var pitch_pid_d: float = 1.2
var roll_pid_p: float = 6.0
var roll_pid_d: float = 1.2
var yaw_rate_p: float = 3.5

func _init() -> void:
	_load_profiles()

func _ready() -> void:
	mass = drone_mass
	gravity_scale = 1.0
	linear_damp = 0.1
	angular_damp = 0.1
	max_contacts_reported = 4
	contact_monitor = true
	spawn_transform = global_transform

	_load_profiles()
	set_flight_profile("normal")

	if input_router:
		input_router.takeoff_land_requested.connect(_on_takeoff_land_requested)
		input_router.reset_requested.connect(_on_reset_requested)
		input_router.flight_mode_cycle_requested.connect(_on_flight_mode_cycle_requested)
		input_router.stunt_requested.connect(_on_stunt_requested)

	if not stunt_engine:
		stunt_engine = get_node_or_null("StuntEngine")
		if not stunt_engine:
			stunt_engine = StuntEngine.new()
			stunt_engine.name = "StuntEngine"
			add_child(stunt_engine)

	body_entered.connect(_on_body_entered)

func _load_profiles() -> void:
	# Default baseline for all 5 modes
	all_profiles = {
		"cine": {
			"name": "Cinematic",
			"max_tilt_deg": 14.0,
			"max_climb_mps": 3.0,
			"max_descent_mps": 2.5,
			"max_yaw_rate_deg": 60.0,
			"auto_level_strength": 8.0,
			"altitude_hold": true,
			"expo": 0.35
		},
		"normal": {
			"name": "Normal",
			"max_tilt_deg": 28.0,
			"max_climb_mps": 6.0,
			"max_descent_mps": 4.5,
			"max_yaw_rate_deg": 120.0,
			"auto_level_strength": 6.0,
			"altitude_hold": true,
			"expo": 0.25
		},
		"sport": {
			"name": "Sport",
			"max_tilt_deg": 52.0,
			"max_climb_mps": 10.0,
			"max_descent_mps": 8.0,
			"max_yaw_rate_deg": 220.0,
			"auto_level_strength": 4.5,
			"altitude_hold": false,
			"expo": 0.2
		},
		"arcade": {
			"name": "Arcade",
			"max_tilt_deg": 40.0,
			"max_climb_mps": 8.0,
			"max_descent_mps": 6.0,
			"max_yaw_rate_deg": 180.0,
			"auto_level_strength": 7.0,
			"altitude_hold": true,
			"stunts_enabled": true,
			"expo": 0.15
		},
		"acro": {
			"name": "Acro",
			"max_tilt_deg": 180.0,
			"max_climb_mps": 14.0,
			"max_descent_mps": 12.0,
			"max_yaw_rate_deg": 450.0,
			"auto_level_strength": 0.0,
			"altitude_hold": false,
			"stunts_enabled": true,
			"expo": 0.1
		}
	}

	var file_path = "res://data/tuning/drone_profiles.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.new()
		if json.parse(json_text) == OK:
			var data = json.data
			if data is Dictionary and data.has("profiles"):
				for k in data["profiles"].keys():
					all_profiles[k] = data["profiles"][k]

func set_flight_profile(profile_name: String) -> void:
	if all_profiles.is_empty():
		_load_profiles()
	if all_profiles.has(profile_name):
		active_profile_name = profile_name
		active_profile = all_profiles[profile_name]
		pitch_pid_p = active_profile.get("auto_level_strength", 6.0)
		roll_pid_p = pitch_pid_p
		flight_mode_changed.emit(active_profile.get("name", profile_name.capitalize()))

func _physics_process(delta: float) -> void:
	# Clamp delta to prevent integration explosion on hitch / startup
	var safe_delta = clampf(delta, 0.001, 0.033)

	# Guard against runaway physics or NaN
	if not linear_velocity.is_finite() or linear_velocity.length_squared() > 40000.0:
		linear_velocity = Vector3.ZERO
	if not angular_velocity.is_finite() or angular_velocity.length_squared() > 10000.0:
		angular_velocity = Vector3.ZERO
	if not global_position.is_finite():
		global_position = Vector3(0.0, 0.2, 0.0)

	_update_telemetry()
	_update_battery(safe_delta)

	match current_state:
		DroneState.DISARMED:
			_process_disarmed(safe_delta)
		DroneState.TAKING_OFF:
			_process_taking_off(safe_delta)
		DroneState.FLYING:
			_process_flying(safe_delta)
		DroneState.LANDING:
			_process_landing(safe_delta)
		DroneState.CRASHED:
			_process_crashed(safe_delta)

	_apply_motor_forces(safe_delta)
	_emit_telemetry()

func _update_telemetry() -> void:
	var cur_trans = global_transform if is_inside_tree() else transform
	if not cur_trans.is_finite():
		return
	altitude_msl = global_position.y if is_inside_tree() else position.y
	if raycast_ground and raycast_ground.is_inside_tree() and raycast_ground.is_colliding():
		var col_pt = raycast_ground.get_collision_point()
		if col_pt.is_finite():
			altitude_agl = maxf(0.0, altitude_msl - col_pt.y)
		else:
			altitude_agl = maxf(0.0, altitude_msl)
	else:
		altitude_agl = maxf(0.0, altitude_msl)

	var horizontal_vel = Vector2(linear_velocity.x, linear_velocity.z)
	ground_speed = horizontal_vel.length()
	climb_rate = linear_velocity.y

	# Calculate pitch and roll angles in degrees
	var forward = -cur_trans.basis.z
	var right = cur_trans.basis.x

	pitch_deg = rad_to_deg(asin(clampf(forward.y, -1.0, 1.0)))
	roll_deg = rad_to_deg(asin(clampf(right.y, -1.0, 1.0)))

	# Compass heading (0..360 where 0 = North / -Z axis)
	var forward_flat = Vector2(-forward.x, -forward.z)
	if forward_flat.length_squared() > 0.0001:
		forward_flat = forward_flat.normalized()
		heading_deg = fposmod(rad_to_deg(atan2(forward_flat.x, forward_flat.y)), 360.0)

func _update_battery(delta: float) -> void:
	if battery_remaining_mah <= 0.0:
		battery_remaining_mah = 0.0
		battery_percent = 0.0
		if current_state == DroneState.FLYING:
			current_state = DroneState.LANDING
		return

	var total_motor_load: float = 0.0
	for rpm in motor_rpms:
		total_motor_load += rpm
	total_motor_load /= 4.0

	var idle_drain_amps = 0.6
	var max_thrust_amps = 28.0
	var current_amps = idle_drain_amps + (total_motor_load * max_thrust_amps)

	var drain_mah = (current_amps * 1000.0) * (delta / 3600.0)
	battery_remaining_mah = maxf(0.0, battery_remaining_mah - drain_mah)
	battery_percent = (battery_remaining_mah / battery_capacity_mah) * 100.0
	battery_voltage = 13.6 + (battery_percent / 100.0) * 3.2

func _process_disarmed(delta: float) -> void:
	for i in range(4):
		target_motor_rpms[i] = 0.0

func _process_taking_off(delta: float) -> void:
	# Automated liftoff sequence to auto_target_altitude
	var alt_error = auto_target_altitude - altitude_agl
	if alt_error <= 0.15:
		current_state = DroneState.FLYING
		drone_state_changed.emit("FLYING")
		return

	# Upward thrust
	var hover_thrust = (drone_mass * 9.8) / (4.0 * max_thrust_per_motor)
	var climb_thrust = clampf(hover_thrust + (alt_error * 0.15), 0.0, 0.95)

	# Keep level during takeoff
	_calculate_auto_level_rpms(climb_thrust, 0.0, 0.0, 0.0, delta)

func _process_flying(delta: float) -> void:
	if stunt_engine and stunt_engine.is_performing_stunt():
		stunt_engine.process_stunt_physics(delta, self)
		return

	var in_throttle = input_router.throttle if input_router else 0.0
	var in_yaw = input_router.yaw if input_router else 0.0
	var in_pitch = input_router.pitch if input_router else 0.0
	var in_roll = input_router.roll if input_router else 0.0

	var hover_thrust = (drone_mass * 9.8) / (4.0 * max_thrust_per_motor)
	var base_thrust = hover_thrust + (in_throttle * 0.45)

	# In Acro mode, direct rate control without auto-level
	if active_profile_name == "acro":
		_calculate_acro_rpms(base_thrust, in_pitch, in_roll, in_yaw, delta)
	else:
		# Auto-level mode: Pitch/Roll stick commands target angles
		var max_tilt = active_profile.get("max_tilt_deg", 28.0)
		var target_pitch = in_pitch * max_tilt
		var target_roll = in_roll * max_tilt
		var max_yaw_rate = active_profile.get("max_yaw_rate_deg", 120.0)
		var target_yaw_rate = in_yaw * deg_to_rad(max_yaw_rate)

		_calculate_auto_level_rpms(base_thrust, target_pitch, target_roll, target_yaw_rate, delta)

func _process_landing(delta: float) -> void:
	var target_descent = -0.7 # m/s
	var vel_error = target_descent - linear_velocity.y
	var hover_thrust = (drone_mass * 9.8) / (4.0 * max_thrust_per_motor)
	var descent_thrust = clampf(hover_thrust + (vel_error * 0.08), 0.15, 0.75)

	_calculate_auto_level_rpms(descent_thrust, 0.0, 0.0, 0.0, delta)

	if altitude_agl < 0.12 and abs(linear_velocity.y) < 0.2:
		current_state = DroneState.DISARMED
		drone_state_changed.emit("DISARMED")
		landing_completed.emit()

func _process_crashed(delta: float) -> void:
	for i in range(4):
		target_motor_rpms[i] = 0.0

func _calculate_auto_level_rpms(base_thrust: float, target_pitch_deg: float, target_roll_deg: float, target_yaw_rate: float, _delta: float) -> void:
	# Error in pitch & roll
	var pitch_err = deg_to_rad(target_pitch_deg - pitch_deg)
	var roll_err = deg_to_rad(target_roll_deg - roll_deg)

	# Angular velocities relative to drone frame using transpose (stable inverse for orthogonal rotation)
	var cur_basis = global_transform.basis.orthonormalized() if is_inside_tree() else transform.basis.orthonormalized()
	var local_ang_vel = cur_basis.transposed() * angular_velocity

	# Torques
	var pitch_torque = (pitch_err * pitch_pid_p) - (local_ang_vel.x * pitch_pid_d)
	var roll_torque = (roll_err * roll_pid_p) - (local_ang_vel.z * roll_pid_d)
	var yaw_torque = target_yaw_rate - (local_ang_vel.y * yaw_rate_p)

	# Motor Layout:
	# 0: Front-Left  (CW)   - pitch + roll + yaw
	# 1: Front-Right (CCW)  - pitch - roll - yaw
	# 2: Rear-Left   (CCW)  + pitch + roll - yaw
	# 3: Rear-Right  (CW)   + pitch - roll + yaw
	target_motor_rpms[0] = clampf(base_thrust - pitch_torque + roll_torque + (yaw_torque * 0.2), 0.0, 1.0)
	target_motor_rpms[1] = clampf(base_thrust - pitch_torque - roll_torque - (yaw_torque * 0.2), 0.0, 1.0)
	target_motor_rpms[2] = clampf(base_thrust + pitch_torque + roll_torque - (yaw_torque * 0.2), 0.0, 1.0)
	target_motor_rpms[3] = clampf(base_thrust + pitch_torque - roll_torque + (yaw_torque * 0.2), 0.0, 1.0)

func _calculate_acro_rpms(base_thrust: float, in_pitch: float, in_roll: float, in_yaw: float, _delta: float) -> void:
	var cur_basis = global_transform.basis.orthonormalized() if is_inside_tree() else transform.basis.orthonormalized()
	var local_ang_vel = cur_basis.transposed() * angular_velocity
	var p_rate = (in_pitch * 5.0) - local_ang_vel.x
	var r_rate = (in_roll * 5.0) - local_ang_vel.z
	var y_rate = (in_yaw * 4.0) - local_ang_vel.y

	target_motor_rpms[0] = clampf(base_thrust - p_rate + r_rate + y_rate, 0.0, 1.0)
	target_motor_rpms[1] = clampf(base_thrust - p_rate - r_rate - y_rate, 0.0, 1.0)
	target_motor_rpms[2] = clampf(base_thrust + p_rate + r_rate - y_rate, 0.0, 1.0)
	target_motor_rpms[3] = clampf(base_thrust + p_rate - r_rate + y_rate, 0.0, 1.0)

func _apply_motor_forces(delta: float) -> void:
	# Spool motors towards targets
	for i in range(4):
		motor_rpms[i] = move_toward(motor_rpms[i], target_motor_rpms[i], motor_spool_speed * delta)

	# Sum of upward motor thrust along local Y axis
	var total_rpm: float = 0.0
	for rpm in motor_rpms:
		total_rpm += rpm

	var total_thrust = total_rpm * max_thrust_per_motor

	# Ground effect lift boost
	if altitude_agl < ground_effect_dist and altitude_agl > 0.05:
		var ge_factor = 1.0 - (altitude_agl / ground_effect_dist)
		total_thrust *= (1.0 + (ge_factor * ground_effect_mult))

	var cur_basis = global_transform.basis.orthonormalized() if is_inside_tree() else transform.basis.orthonormalized()
	var thrust_vector = cur_basis.y * total_thrust
	if thrust_vector.is_finite():
		apply_central_force(thrust_vector)

	# Aerodynamic Linear Drag with explicit stability cap
	var lin_speed = linear_velocity.length()
	if lin_speed > 0.001 and linear_velocity.is_finite():
		var max_drag_force = (drone_mass * lin_speed) / maxf(delta, 0.001) * 0.45
		var natural_drag = lin_speed * linear_drag * lin_speed
		var final_drag = minf(natural_drag, max_drag_force)
		apply_central_force(-linear_velocity.normalized() * final_drag)

	# Angular Damping with explicit stability cap
	var ang_speed = angular_velocity.length()
	if ang_speed > 0.001 and angular_velocity.is_finite():
		var approx_inertia = drone_mass * 0.045
		var max_damping_torque = (approx_inertia * ang_speed) / maxf(delta, 0.001) * 0.45
		var natural_torque = ang_speed * angular_drag
		var final_torque = minf(natural_torque, max_damping_torque)
		apply_torque(-angular_velocity.normalized() * final_torque)

func _emit_telemetry() -> void:
	var data = {
		"state": DroneState.keys()[current_state],
		"profile": active_profile.get("name", "Normal"),
		"altitude_agl": altitude_agl,
		"altitude_msl": altitude_msl,
		"speed": ground_speed,
		"climb_rate": climb_rate,
		"heading": heading_deg,
		"pitch": pitch_deg,
		"roll": roll_deg,
		"battery_pct": battery_percent,
		"battery_volts": battery_voltage,
		"motor_rpms": motor_rpms
	}
	telemetry_updated.emit(data)

func _on_takeoff_land_requested() -> void:
	match current_state:
		DroneState.DISARMED:
			current_state = DroneState.TAKING_OFF
			drone_state_changed.emit("TAKING_OFF")
		DroneState.FLYING, DroneState.TAKING_OFF:
			current_state = DroneState.LANDING
			drone_state_changed.emit("LANDING")
		DroneState.LANDING:
			# Abort landing and resume flying
			current_state = DroneState.FLYING
			drone_state_changed.emit("FLYING")
		DroneState.CRASHED:
			reset_to_pad()

func _on_reset_requested() -> void:
	reset_to_pad()

func reset_to_pad() -> void:
	if stunt_engine and stunt_engine.is_stunting:
		stunt_engine.is_stunting = false
		stunt_engine.stunt_phase = StuntEngine.StuntState.IDLE
	global_transform = spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	for i in range(4):
		motor_rpms[i] = 0.0
		target_motor_rpms[i] = 0.0
	battery_remaining_mah = battery_capacity_mah
	battery_percent = 100.0
	current_state = DroneState.DISARMED
	drone_state_changed.emit("DISARMED")

func _on_stunt_requested(stunt_type: String) -> void:
	if stunt_engine:
		stunt_engine.trigger_stunt(stunt_type, self)

func _on_flight_mode_cycle_requested() -> void:
	var mode_keys = ["normal", "cine", "sport", "arcade", "acro"]
	var curr_idx = mode_keys.find(active_profile_name)
	var next_idx = (curr_idx + 1) % mode_keys.size()
	set_flight_profile(mode_keys[next_idx])

func _on_body_entered(body: Node) -> void:
	if current_state == DroneState.DISARMED:
		return
	var impact_velocity = linear_velocity.length()
	if impact_velocity > 4.5:
		current_state = DroneState.CRASHED
		drone_state_changed.emit("CRASHED")
		drone_crashed.emit(impact_velocity)
