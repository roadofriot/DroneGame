class_name FlightPhysics
extends RigidBody3D

## FlightPhysics: Professional 60Hz Quadcopter Flight Simulation & State Machine.
## Implements 4-motor thrust dynamics, auto-level PID, ground effect, battery consumption,
## automated Take-Off sequence, Landing, Return-To-Home (RTH), and 5 distinct flight modes.

signal telemetry_updated(data: Dictionary)
signal flight_mode_changed(mode_name: String)
signal drone_state_changed(state_name: String)
signal drone_crashed(impact_force: float)
signal landing_completed
signal takeoff_completed
signal preflight_failed(reason: String)
signal rth_state_changed(is_active: bool, distance: float)
signal flight_boundary_reached(boundary_type: String)

enum DroneState {
	DISARMED,
	PREFLIGHT_CHECK,
	MOTOR_STARTING,
	TAKEOFF,
	HOVER,
	FLYING,
	LANDING,
	RTH,
	CRASHED
}

@export var input_router: InputRouter
@export var raycast_ground: RayCast3D
@export var stunt_engine: StuntEngine

# Physical Constants
@export var drone_mass: float = 1.25
@export var arm_length: float = 0.22 # Motor arm moment length in meters
@export var max_thrust_per_motor: float = 7.0 # 4 * 7 = 28 N (TWR ~ 2.28)
@export var motor_spool_speed: float = 20.0 # Spool response factor
@export var linear_drag: float = 0.55
@export var angular_drag: float = 4.0
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
var total_flight_time: float = 0.0

# Takeoff & Hover Automation (Configurable default 3.0m)
@export var auto_target_altitude: float = 3.0
@export var max_flight_altitude: float = 60.0 # meters AGL ceiling
@export var max_horizontal_range: float = 250.0 # meters horizontal boundary from pad
var state_timer: float = 0.0
var spawn_transform: Transform3D

# RTH State
var rth_phase: int = 0 # 0: Ascend, 1: Cruise, 2: Land
var rth_clearance_altitude: float = 5.0

# Automatic Altitude Lock & Station Keeping State
var held_flight_altitude: float = 3.0
var has_flight_altitude_lock: bool = false

# Tuned Critical-Damped PID Controllers for Rock-Solid Stability
var pitch_pid_p: float = 5.5
var pitch_pid_d: float = 2.8
var roll_pid_p: float = 5.5
var roll_pid_d: float = 2.8
var yaw_rate_p: float = 4.2

func _init() -> void:
	_load_profiles()

func _ready() -> void:
	mass = drone_mass
	gravity_scale = 1.0
	linear_damp = 0.5
	angular_damp = 2.0
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
			"stunts_enabled": true,
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
	if all_profiles.has(profile_name):
		active_profile_name = profile_name
		active_profile = all_profiles[profile_name]
		pitch_pid_p = active_profile.get("auto_level_strength", 6.0)
		roll_pid_p = pitch_pid_p
		flight_mode_changed.emit(active_profile.get("name", profile_name.capitalize()))

# --- Physics Process Loop (Fixed 60Hz Timestep) ---

func _physics_process(delta: float) -> void:
	var safe_delta = clampf(delta, 0.001, 0.033)

	# Guard against numerical instability
	if not linear_velocity.is_finite() or linear_velocity.length_squared() > 40000.0:
		linear_velocity = Vector3.ZERO
	if not angular_velocity.is_finite() or angular_velocity.length_squared() > 10000.0:
		angular_velocity = Vector3.ZERO
	var cur_p = global_position if is_inside_tree() else position
	if not cur_p.is_finite():
		if is_inside_tree():
			global_position = spawn_transform.origin + Vector3(0.0, 0.2, 0.0)
		else:
			position = spawn_transform.origin + Vector3(0.0, 0.2, 0.0)

	_update_telemetry()
	_update_battery(safe_delta)

	if current_state != DroneState.DISARMED and current_state != DroneState.CRASHED:
		total_flight_time += safe_delta

	match current_state:
		DroneState.DISARMED:
			_process_disarmed(safe_delta)
		DroneState.PREFLIGHT_CHECK:
			_process_preflight_check(safe_delta)
		DroneState.MOTOR_STARTING:
			_process_motor_starting(safe_delta)
		DroneState.TAKEOFF:
			_process_taking_off(safe_delta)
		DroneState.HOVER:
			_process_hover(safe_delta)
		DroneState.FLYING:
			_process_flying(safe_delta)
		DroneState.LANDING:
			_process_landing(safe_delta)
		DroneState.RTH:
			_process_rth(safe_delta)
		DroneState.CRASHED:
			_process_crashed(safe_delta)

	_apply_motor_forces(safe_delta)
	_emit_telemetry()

func _update_telemetry() -> void:
	var use_global = is_inside_tree() and is_node_ready() and get_viewport() != null
	var cur_trans = global_transform if use_global else transform
	var cur_y = global_position.y if use_global else position.y
	if cur_y == 0.0 and position.y != 0.0:
		cur_y = position.y
	altitude_msl = cur_y

	if raycast_ground and raycast_ground.is_inside_tree() and raycast_ground.is_colliding():
		var col_pt = raycast_ground.get_collision_point()
		if col_pt.is_finite():
			altitude_agl = maxf(0.0, altitude_msl - col_pt.y)
			# print("DBG: col_pt=", col_pt, " msl=", altitude_msl, " agl=", altitude_agl)
		else:
			altitude_agl = maxf(0.0, altitude_msl)
	else:
		altitude_agl = maxf(0.0, altitude_msl)

	var horizontal_vel = Vector2(linear_velocity.x, linear_velocity.z)
	ground_speed = horizontal_vel.length()
	climb_rate = linear_velocity.y

	# Calculate pitch and roll angles in degrees (Forward tilt / Bank right are positive)
	var forward = -cur_trans.basis.z
	var right = cur_trans.basis.x

	pitch_deg = -rad_to_deg(asin(clampf(forward.y, -1.0, 1.0)))
	roll_deg = -rad_to_deg(asin(clampf(right.y, -1.0, 1.0)))

	# Compass heading (0..360 where 0 = North / -Z axis)
	var forward_flat = Vector2(-forward.x, -forward.z)
	if forward_flat.length_squared() > 0.0001:
		forward_flat = forward_flat.normalized()
		heading_deg = fposmod(rad_to_deg(atan2(forward_flat.x, forward_flat.y)), 360.0)

func _update_battery(delta: float) -> void:
	if battery_remaining_mah <= 0.0:
		battery_remaining_mah = 0.0
		battery_percent = 0.0
		if current_state == DroneState.FLYING or current_state == DroneState.HOVER:
			land()
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

# --- State Process Handlers ---

func _process_disarmed(_delta: float) -> void:
	for i in range(4):
		target_motor_rpms[i] = 0.0

func _process_preflight_check(delta: float) -> void:
	state_timer += delta
	if state_timer >= 0.2:
		var err = _perform_preflight_check()
		if not err.is_empty():
			current_state = DroneState.DISARMED
			preflight_failed.emit(err)
			drone_state_changed.emit("DISARMED")
			print("[VALIDATION] PREFLIGHT_FAILED: %s" % err)
			return

		current_state = DroneState.MOTOR_STARTING
		state_timer = 0.0
		drone_state_changed.emit("MOTOR_STARTING")
		print("[VALIDATION] PREFLIGHT_PASSED")
		print("[MOTORS] STARTING")

func _process_motor_starting(delta: float) -> void:
	state_timer += delta
	# Gradual idle spool-up to 25% RPM
	for i in range(4):
		target_motor_rpms[i] = 0.25

	if state_timer >= 0.5:
		current_state = DroneState.TAKEOFF
		state_timer = 0.0
		drone_state_changed.emit("TAKEOFF")
		print("[FLIGHT] TAKEOFF_STARTED")

func _process_taking_off(delta: float) -> void:
	# Vertical ascent towards configured auto_target_altitude (3.0m)
	var alt_error = auto_target_altitude - altitude_agl
	if alt_error <= 0.15:
		current_state = DroneState.HOVER
		state_timer = 0.0
		drone_state_changed.emit("HOVER")
		takeoff_completed.emit()
		print("[FLIGHT] HOVER_REACHED — Altitude stabilized at %.2fm" % altitude_agl)
		return

	# Upward thrust
	var hover_thrust = (drone_mass * 9.8) / (4.0 * max_thrust_per_motor)
	var climb_thrust = clampf(hover_thrust + (alt_error * 0.20), 0.0, 0.95)
	_calculate_auto_level_rpms(climb_thrust, 0.0, 0.0, 0.0, delta)

func _process_hover(delta: float) -> void:
	var in_throttle = input_router.throttle if input_router else 0.0
	var in_pitch = input_router.pitch if input_router else 0.0
	var in_roll = input_router.roll if input_router else 0.0
	var in_yaw = input_router.yaw if input_router else 0.0

	# When pilot touches or moves joysticks, transition seamlessly to manual flight
	if abs(in_throttle) > 0.08 or abs(in_pitch) > 0.08 or abs(in_roll) > 0.08 or abs(in_yaw) > 0.08:
		current_state = DroneState.FLYING
		drone_state_changed.emit("FLYING")
		print("[FLIGHT] MANUAL_CONTROL_ENABLED")
		_process_flying(delta)
		return

	# Maintain stable hover via Altitude Hold PID
	var alt_error = auto_target_altitude - altitude_agl
	var hover_thrust = (drone_mass * 9.8) / (4.0 * max_thrust_per_motor)
	var hold_thrust = clampf(hover_thrust + (alt_error * 0.18) - (linear_velocity.y * 0.12), 0.15, 0.90)
	_calculate_auto_level_rpms(hold_thrust, 0.0, 0.0, 0.0, delta)

func _process_flying(delta: float) -> void:
	if stunt_engine and stunt_engine.is_performing_stunt():
		stunt_engine.process_stunt_physics(delta, self)
		return

	var in_throttle = input_router.throttle if input_router else 0.0
	var in_yaw = input_router.yaw if input_router else 0.0
	var in_pitch = input_router.pitch if input_router else 0.0
	var in_roll = input_router.roll if input_router else 0.0

	# Enforce Flight Boundaries (Ceiling and Horizontal Geofence)
	if altitude_agl >= max_flight_altitude:
		if in_throttle > 0.0:
			in_throttle = 0.0
		flight_boundary_reached.emit("MAX_ALTITUDE")

	var dist_home = get_home_distance()
	if dist_home >= max_horizontal_range:
		var home_flat = Vector2(spawn_transform.origin.x, spawn_transform.origin.z)
		var cur_pos = global_position if is_inside_tree() else position
		var cur_flat = Vector2(cur_pos.x, cur_pos.z)
		var to_home_2d = (home_flat - cur_flat).normalized()
		var breach_depth = dist_home - max_horizontal_range
		var push_force = Vector3(to_home_2d.x, 0.0, to_home_2d.y) * clampf(breach_depth * 8.0, 4.0, 25.0)
		apply_central_force(push_force)
		flight_boundary_reached.emit("GEOFENCE_RADIUS")

	var hover_thrust = (drone_mass * 9.8) / (4.0 * max_thrust_per_motor)
	var base_thrust: float = hover_thrust

	# Station-keeping Altitude Hold when vertical stick is neutral
	if active_profile.get("altitude_hold", true):
		if abs(in_throttle) < 0.04:
			if not has_flight_altitude_lock:
				held_flight_altitude = clampf(altitude_agl, 0.4, max_flight_altitude)
				has_flight_altitude_lock = true
			var alt_err = held_flight_altitude - altitude_agl
			var vert_damping = linear_velocity.y * 0.40
			base_thrust = clampf(hover_thrust + (alt_err * 0.22) - vert_damping, 0.15, 0.88)
		else:
			has_flight_altitude_lock = false
			held_flight_altitude = altitude_agl
			base_thrust = hover_thrust + (in_throttle * 0.45)
	else:
		base_thrust = hover_thrust + (in_throttle * 0.45)

	# Tilt compensation: when tilted, increase thrust to maintain altitude
	var cur_basis_tilt = global_transform.basis.orthonormalized() if (is_inside_tree() and is_node_ready()) else transform.basis.orthonormalized()
	var tilt_comp = 1.0 / maxf(cur_basis_tilt.y.dot(Vector3.UP), 0.35)
	base_thrust = clampf(base_thrust * tilt_comp, 0.0, 1.0)

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

	# --- True 3D Physical Translation & Aerodynamic Propulsion ---
	var cur_basis = global_transform.basis.orthonormalized() if (is_inside_tree() and is_node_ready()) else transform.basis.orthonormalized()
	var forward_flat = -Vector3(cur_basis.z.x, 0.0, cur_basis.z.z)
	if forward_flat.length_squared() > 0.0001:
		forward_flat = forward_flat.normalized()
	else:
		forward_flat = Vector3(0.0, 0.0, -1.0)

	var right_flat = Vector3(cur_basis.x.x, 0.0, cur_basis.x.z)
	if right_flat.length_squared() > 0.0001:
		right_flat = right_flat.normalized()
	else:
		right_flat = Vector3(1.0, 0.0, 0.0)

	var max_h_speed = active_profile.get("max_horizontal_speed_mps", 14.0)
	var cur_h_vel = Vector3(linear_velocity.x, 0.0, linear_velocity.z)

	if abs(in_pitch) > 0.03 or abs(in_roll) > 0.03:
		# Pilot commanding horizontal translation
		var target_h_vel = (forward_flat * in_pitch + right_flat * in_roll) * max_h_speed
		var h_force = (target_h_vel - cur_h_vel) * 5.5 * drone_mass
		if h_force.is_finite():
			apply_central_force(h_force)
	else:
		# Rock-solid GPS-style horizontal braking when sticks centered
		if cur_h_vel.length() > 0.01:
			var brake_force = -cur_h_vel * 4.6 * drone_mass
			if brake_force.is_finite():
				apply_central_force(brake_force)
		if cur_h_vel.length() < 0.08:
			linear_velocity.x = move_toward(linear_velocity.x, 0.0, 12.0 * delta)
			linear_velocity.z = move_toward(linear_velocity.z, 0.0, 12.0 * delta)
		angular_velocity.x = move_toward(angular_velocity.x, 0.0, 14.0 * delta)
		angular_velocity.z = move_toward(angular_velocity.z, 0.0, 14.0 * delta)

	# Direct yaw angular response
	if abs(in_yaw) > 0.03:
		var max_yaw_rate_rad = deg_to_rad(active_profile.get("max_yaw_rate_deg", 120.0))
		var target_yaw_w = in_yaw * max_yaw_rate_rad
		var cur_yaw_w = angular_velocity.y
		var yaw_torque_impulse = (target_yaw_w - cur_yaw_w) * 4.5 * (drone_mass * 0.045)
		apply_torque(Vector3(0.0, yaw_torque_impulse, 0.0))
	else:
		angular_velocity.y = move_toward(angular_velocity.y, 0.0, 12.0 * delta)

func _process_landing(delta: float) -> void:
	# 1. Active horizontal braking
	var h_vel = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if h_vel.length() > 0.05:
		apply_central_force(-h_vel.normalized() * minf(h_vel.length() * 4.0, 10.0))

	# 2. Controlled vertical descent (-0.65 m/s)
	var target_descent = -0.65
	var vel_error = target_descent - linear_velocity.y
	var hover_thrust = (drone_mass * 9.8) / (4.0 * max_thrust_per_motor)
	var descent_thrust = clampf(hover_thrust + (vel_error * 0.12), 0.15, 0.70)
	_calculate_auto_level_rpms(descent_thrust, 0.0, 0.0, 0.0, delta)

	# 3. Touchdown confirmation
	if altitude_agl < 0.16 and abs(linear_velocity.y) < 0.35:
		state_timer += delta
		if state_timer >= 0.25:
			current_state = DroneState.DISARMED
			for i in range(4):
				target_motor_rpms[i] = 0.0
				motor_rpms[i] = 0.0
			drone_state_changed.emit("DISARMED")
			landing_completed.emit()
			print("[FLIGHT] LANDING_CONFIRMED — MOTORS_STOPPED")

func _process_rth(delta: float) -> void:
	# Cancel RTH if user moves pitch/roll joystick manually
	var in_pitch = input_router.pitch if input_router else 0.0
	var in_roll = input_router.roll if input_router else 0.0
	if abs(in_pitch) > 0.25 or abs(in_roll) > 0.25:
		cancel_rth()
		_process_flying(delta)
		return

	var home_pos = spawn_transform.origin
	var cur_pos = global_position if is_inside_tree() else position
	var to_home = home_pos - cur_pos
	to_home.y = 0.0
	var dist_home = to_home.length()

	match rth_phase:
		0:
			# Phase 0: Ascend to safety clearance altitude
			var alt_err = rth_clearance_altitude - altitude_agl
			if alt_err <= 0.25:
				rth_phase = 1
				print("[FLIGHT] RTH_CRUISE_STARTED — Distance: %.1f m" % dist_home)
				return
			var hover_thrust = (drone_mass * 9.8) / (4.0 * max_thrust_per_motor)
			var climb_thrust = clampf(hover_thrust + (alt_err * 0.18), 0.2, 0.85)
			_calculate_auto_level_rpms(climb_thrust, 0.0, 0.0, 0.0, delta)

		1:
			# Phase 1: Cruise toward home pad
			if dist_home <= 1.2:
				rth_phase = 2
				print("[FLIGHT] RTH_ARRIVED_OVER_HOME — Initiating Autoland")
				land()
				return

			var dir_home = to_home.normalized()
			# Pitch forward towards home
			var target_pitch_angle = 12.0
			var target_yaw_angle = rad_to_deg(atan2(-dir_home.x, -dir_home.z))
			var yaw_err = wrapf(target_yaw_angle - heading_deg, -180.0, 180.0)
			var yaw_rate = deg_to_rad(clampf(yaw_err * 2.5, -90.0, 90.0))

			# Maintain altitude
			var alt_err = rth_clearance_altitude - altitude_agl
			var hover_thrust = (drone_mass * 9.8) / (4.0 * max_thrust_per_motor)
			var hold_thrust = clampf(hover_thrust + (alt_err * 0.14) - (linear_velocity.y * 0.1), 0.2, 0.85)
			_calculate_auto_level_rpms(hold_thrust, target_pitch_angle, 0.0, yaw_rate, delta)

		2:
			# Phase 2: Land
			_process_landing(delta)

func _process_crashed(_delta: float) -> void:
	for i in range(4):
		target_motor_rpms[i] = 0.0

# --- Core Flight Commands ---

func takeoff() -> bool:
	print("[INPUT] TAKEOFF_BUTTON_PRESSED")
	print("[COMMAND] TAKEOFF_REQUESTED")

	if current_state == DroneState.FLYING or current_state == DroneState.HOVER or current_state == DroneState.TAKEOFF:
		print("[VALIDATION] Cannot Take Off: Already airborne")
		preflight_failed.emit("Already airborne")
		return false

	var err = _perform_preflight_check()
	if not err.is_empty():
		print("[VALIDATION] PREFLIGHT_FAILED: %s" % err)
		preflight_failed.emit(err)
		return false

	print("[VALIDATION] PREFLIGHT_PASSED")
	current_state = DroneState.MOTOR_STARTING
	state_timer = 0.0
	drone_state_changed.emit("MOTOR_STARTING")
	print("[MOTORS] STARTING")
	return true

func land() -> void:
	print("[COMMAND] LAND_REQUESTED")
	if current_state == DroneState.FLYING or current_state == DroneState.HOVER or current_state == DroneState.TAKEOFF or current_state == DroneState.RTH:
		current_state = DroneState.LANDING
		state_timer = 0.0
		drone_state_changed.emit("LANDING")
		print("[FLIGHT] LANDING_INITIATED")

func trigger_rth() -> bool:
	print("[COMMAND] RTH_REQUESTED")
	if current_state == DroneState.DISARMED or current_state == DroneState.CRASHED:
		print("[VALIDATION] Cannot RTH: Drone not airborne")
		return false

	if current_state == DroneState.RTH:
		cancel_rth()
		return false

	current_state = DroneState.RTH
	rth_phase = 0
	rth_clearance_altitude = maxf(altitude_agl, 5.0)
	drone_state_changed.emit("RTH")
	rth_state_changed.emit(true, get_home_distance())
	print("[FLIGHT] RTH_ACTIVATED — Clearance Altitude: %.1f m" % rth_clearance_altitude)
	return true

func cancel_rth() -> void:
	if current_state == DroneState.RTH:
		current_state = DroneState.FLYING
		drone_state_changed.emit("FLYING")
		rth_state_changed.emit(false, get_home_distance())
		print("[FLIGHT] RTH_CANCELLED — Manual Control Restored")

func emergency_motor_cut() -> void:
	print("[COMMAND] EMERGENCY_MOTOR_CUT")
	for i in range(4):
		target_motor_rpms[i] = 0.0
		motor_rpms[i] = 0.0
	current_state = DroneState.DISARMED
	drone_state_changed.emit("DISARMED")

func reset_to_pad() -> void:
	print("[COMMAND] RESET_REQUESTED")
	if stunt_engine and stunt_engine.is_stunting:
		stunt_engine.is_stunting = false
		stunt_engine.stunt_phase = StuntEngine.StuntState.IDLE
	if is_inside_tree() and is_node_ready():
		global_transform = spawn_transform
	else:
		transform = spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	for i in range(4):
		motor_rpms[i] = 0.0
		target_motor_rpms[i] = 0.0
	battery_remaining_mah = battery_capacity_mah
	battery_percent = 100.0
	total_flight_time = 0.0
	current_state = DroneState.DISARMED
	drone_state_changed.emit("DISARMED")
	print("[FLIGHT] RESET_COMPLETE — Placed on Pad")

func get_home_distance() -> float:
	var home_flat = Vector2(spawn_transform.origin.x, spawn_transform.origin.z)
	var cur_pos = global_position if (is_inside_tree() and is_node_ready()) else position
	var cur_flat = Vector2(cur_pos.x, cur_pos.z)
	return home_flat.distance_to(cur_flat)

func _perform_preflight_check() -> String:
	if not linear_velocity.is_finite():
		return "Physics body coordinates invalid"
	if battery_percent < 5.0:
		return "Battery critically low"
	if current_state == DroneState.CRASHED:
		return "Drone crashed — Press Reset first"
	if altitude_agl > 0.8:
		return "Drone not grounded on launch surface"
	return ""

# --- Physics Calculations ---

func _calculate_auto_level_rpms(base_thrust: float, target_pitch_deg: float, target_roll_deg: float, target_yaw_rate: float, _delta: float) -> void:
	var pitch_err = deg_to_rad(target_pitch_deg - pitch_deg)
	var roll_err = deg_to_rad(target_roll_deg - roll_deg)

	var cur_basis = global_transform.basis.orthonormalized() if (is_inside_tree() and is_node_ready()) else transform.basis.orthonormalized()
	var local_ang_vel = cur_basis.transposed() * angular_velocity

	var pitch_torque = (pitch_err * pitch_pid_p) - (local_ang_vel.x * pitch_pid_d)
	var roll_torque = (roll_err * roll_pid_p) - (local_ang_vel.z * roll_pid_d)
	var yaw_torque = target_yaw_rate - (local_ang_vel.y * yaw_rate_p)

	target_motor_rpms[0] = clampf(base_thrust - pitch_torque + roll_torque + (yaw_torque * 0.2), 0.0, 1.0)
	target_motor_rpms[1] = clampf(base_thrust - pitch_torque - roll_torque - (yaw_torque * 0.2), 0.0, 1.0)
	target_motor_rpms[2] = clampf(base_thrust + pitch_torque + roll_torque - (yaw_torque * 0.2), 0.0, 1.0)
	target_motor_rpms[3] = clampf(base_thrust + pitch_torque - roll_torque + (yaw_torque * 0.2), 0.0, 1.0)

func _calculate_acro_rpms(base_thrust: float, in_pitch: float, in_roll: float, in_yaw: float, _delta: float) -> void:
	var cur_basis = global_transform.basis.orthonormalized() if (is_inside_tree() and is_node_ready()) else transform.basis.orthonormalized()
	var local_ang_vel = cur_basis.transposed() * angular_velocity
	var p_rate = (in_pitch * 5.0) - local_ang_vel.x
	var r_rate = (in_roll * 5.0) - local_ang_vel.z
	var y_rate = (in_yaw * 4.0) - local_ang_vel.y

	target_motor_rpms[0] = clampf(base_thrust - p_rate + r_rate + y_rate, 0.0, 1.0)
	target_motor_rpms[1] = clampf(base_thrust - p_rate - r_rate - y_rate, 0.0, 1.0)
	target_motor_rpms[2] = clampf(base_thrust + p_rate + r_rate - y_rate, 0.0, 1.0)
	target_motor_rpms[3] = clampf(base_thrust + p_rate - r_rate + y_rate, 0.0, 1.0)

func _apply_motor_forces(delta: float) -> void:
	for i in range(4):
		motor_rpms[i] = move_toward(motor_rpms[i], target_motor_rpms[i], motor_spool_speed * delta)

	var total_rpm: float = 0.0
	for rpm in motor_rpms:
		total_rpm += rpm

	var total_thrust = total_rpm * max_thrust_per_motor

	if altitude_agl < ground_effect_dist and altitude_agl > 0.05:
		var ge_factor = 1.0 - (altitude_agl / ground_effect_dist)
		total_thrust *= (1.0 + (ge_factor * ground_effect_mult))

	var cur_basis = global_transform.basis.orthonormalized() if (is_inside_tree() and is_node_ready()) else transform.basis.orthonormalized()
	var thrust_vector = cur_basis.y * total_thrust
	if thrust_vector.is_finite():
		apply_central_force(thrust_vector)

	# Physical Differential Motor Torques applied to RigidBody
	var pitch_diff = (motor_rpms[0] + motor_rpms[1]) - (motor_rpms[2] + motor_rpms[3])
	var pitch_torque = pitch_diff * max_thrust_per_motor * arm_length

	var roll_diff = (motor_rpms[1] + motor_rpms[3]) - (motor_rpms[0] + motor_rpms[2])
	var roll_torque = roll_diff * max_thrust_per_motor * arm_length

	var yaw_diff = (motor_rpms[0] + motor_rpms[3]) - (motor_rpms[1] + motor_rpms[2])
	var yaw_torque = -yaw_diff * max_thrust_per_motor * 0.12

	var motor_torque_local = Vector3(pitch_torque, yaw_torque, roll_torque)
	var motor_torque_world = cur_basis * motor_torque_local
	if motor_torque_world.is_finite():
		apply_torque(motor_torque_world)

	# Cap angular velocity to prevent oscillation
	var ang_vel = angular_velocity
	if ang_vel.length() > 8.0:
		angular_velocity = ang_vel.normalized() * 8.0

	var lin_speed = linear_velocity.length()
	if lin_speed > 0.001 and linear_velocity.is_finite():
		var max_drag_force = (drone_mass * lin_speed) / maxf(delta, 0.001) * 0.45
		var natural_drag = lin_speed * linear_drag * lin_speed
		var final_drag = minf(natural_drag, max_drag_force)
		apply_central_force(-linear_velocity.normalized() * final_drag)

	var ang_speed = angular_velocity.length()
	if ang_speed > 0.001 and angular_velocity.is_finite():
		var approx_inertia = drone_mass * 0.045
		var max_damping_torque = (approx_inertia * ang_speed) / maxf(delta, 0.001) * 0.45
		var natural_torque = ang_speed * angular_drag
		var final_torque = minf(natural_torque, max_damping_torque)
		apply_torque(-angular_velocity.normalized() * final_torque)

func _emit_telemetry() -> void:
	var home_dist = get_home_distance()
	var est_return_sec = (home_dist / maxf(ground_speed, 6.0)) if home_dist > 1.0 else 0.0
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
		"motor_rpms": motor_rpms,
		"home_distance": home_dist,
		"est_rth_time": est_return_sec,
		"flight_time": total_flight_time,
		"rth_active": current_state == DroneState.RTH,
		"gps_status": "3D RTK LOCK" if altitude_agl > 0.2 else "STANDBY",
		"rc_signal": 100 if altitude_agl < 100.0 else max(25, 100 - int(altitude_agl * 0.2))
	}
	telemetry_updated.emit(data)

# --- Signal Callbacks ---

func _on_takeoff_land_requested() -> void:
	match current_state:
		DroneState.DISARMED:
			takeoff()
		DroneState.FLYING, DroneState.HOVER, DroneState.TAKEOFF, DroneState.RTH:
			land()
		DroneState.LANDING:
			# Abort landing and resume flying
			current_state = DroneState.FLYING
			drone_state_changed.emit("FLYING")
		DroneState.CRASHED:
			reset_to_pad()

func _on_reset_requested() -> void:
	reset_to_pad()

func _on_stunt_requested(stunt_type: String) -> void:
	if stunt_engine:
		stunt_engine.trigger_stunt(stunt_type, self)

func _on_flight_mode_cycle_requested() -> void:
	var mode_keys = ["normal", "cine", "sport", "arcade", "acro"]
	var curr_idx = mode_keys.find(active_profile_name)
	var next_idx = (curr_idx + 1) % mode_keys.size()
	set_flight_profile(mode_keys[next_idx])

func _on_body_entered(_body: Node) -> void:
	if current_state == DroneState.DISARMED:
		return
	var impact_velocity = linear_velocity.length()
	if impact_velocity > 4.5:
		current_state = DroneState.CRASHED
		drone_state_changed.emit("CRASHED")
		drone_crashed.emit(impact_velocity)
