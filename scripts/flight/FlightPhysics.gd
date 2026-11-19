class_name FlightPhysics
extends RigidBody3D

## FlightPhysics: Physically consistent Quadcopter Flight Simulation & State Machine.
## Integrates FlightController (pure-logic RefCounted) for attitude P-loop,
## collective altitude hold, and differential X-quad motor mixing.

const ControlFrame = preload("res://scripts/input/ControlFrame.gd")
const FlightController = preload("res://scripts/flight/FlightController.gd")
const FlightStateMachine = preload("res://scripts/flight/FlightStateMachine.gd")
const FlipController = preload("res://scripts/flight/FlipController.gd")
const FlightModeManager = preload("res://scripts/flight/FlightModeManager.gd")
const BrakeController = preload("res://scripts/flight/BrakeController.gd")
const HeadlessController = preload("res://scripts/flight/HeadlessController.gd")
const TrimManager = preload("res://scripts/flight/TrimManager.gd")
const BatteryModel = preload("res://scripts/flight/BatteryModel.gd")
const RTHController = preload("res://scripts/flight/RTHController.gd")
const HapticsManager = preload("res://scripts/flight/HapticsManager.gd")

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

# Flight State & State Machine
var state_machine: FlightStateMachine = null
var current_state: DroneState = DroneState.DISARMED:
	set(val):
		current_state = val
		if state_machine:
			match val:
				DroneState.DISARMED:
					state_machine.state = FlightStateMachine.State.DISARMED
				DroneState.MOTOR_STARTING, DroneState.TAKEOFF:
					state_machine.state = FlightStateMachine.State.TAKEOFF
				DroneState.HOVER, DroneState.FLYING, DroneState.RTH:
					state_machine.state = FlightStateMachine.State.FLYING
				DroneState.LANDING:
					state_machine.state = FlightStateMachine.State.LANDING
				DroneState.CRASHED:
					state_machine.state = FlightStateMachine.State.CRASHED
			state_machine.is_armed = (val != DroneState.DISARMED and val != DroneState.CRASHED)

var active_profile_name: String = "normal"
var active_profile: Dictionary = {}
var all_profiles: Dictionary = {}
var flight_controller: FlightController = null
var flip_controller: FlipController = null
var flight_mode_manager: FlightModeManager = null
var brake_controller: BrakeController = null
var headless_controller: HeadlessController = null
var trim_manager: TrimManager = null
var battery_model: BatteryModel = null
var rth_controller: RTHController = null
var is_boosted: bool = false
var is_braking: bool = false
var gimbal_pitch_user_deg: float = -15.0
var battery: float = 1.0 # Normalized battery remaining [0.0, 1.0]

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
	flight_controller = FlightController.new()
	state_machine = FlightStateMachine.new()
	flip_controller = FlipController.new()
	flight_mode_manager = FlightModeManager.new()
	brake_controller = BrakeController.new()
	headless_controller = HeadlessController.new()
	trim_manager = TrimManager.new()
	battery_model = BatteryModel.new(56.24)
	rth_controller = RTHController.new()
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
		input_router.takeoff_land_pressed.connect(_on_takeoff_land_requested)
		input_router.takeoff_land_requested.connect(_on_takeoff_land_requested)
		input_router.reset_pressed.connect(_on_reset_requested)
		input_router.reset_requested.connect(_on_reset_requested)
		input_router.flight_mode_cycle_requested.connect(_on_flight_mode_cycle_requested)
		input_router.stunt_requested.connect(_on_stunt_requested)
		if input_router.has_signal("flip_pressed"):
			input_router.flip_pressed.connect(_on_flip_pressed)

	if Engine.has_singleton("WorldOrigin"):
		var wo = Engine.get_singleton("WorldOrigin")
		wo.register_drone(self)
	if Engine.has_singleton("GameState"):
		var gs = Engine.get_singleton("GameState")
		gs.set_true_home(spawn_transform.origin)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if Engine.has_singleton("WorldOrigin"):
		var wo = Engine.get_singleton("WorldOrigin")
		var shift = wo.consume_physics_shift()
		if not shift.is_zero_approx():
			var t = state.transform
			t.origin -= shift
			state.transform = t
			spawn_transform.origin -= shift

		if input_router.has_signal("emergency_stop_pressed"):
			input_router.emergency_stop_pressed.connect(_on_emergency_stop_pressed)
		if input_router.has_signal("emergency_cut_requested"):
			input_router.emergency_cut_requested.connect(_on_emergency_stop_pressed)
		if input_router.has_signal("brake_pressed"):
			input_router.brake_pressed.connect(func(b): is_braking = b)
		if input_router.has_signal("boost_pressed"):
			input_router.boost_pressed.connect(func(b): is_boosted = b)
		if input_router.has_signal("headless_toggle_requested"):
			input_router.headless_toggle_requested.connect(func(): headless_controller.toggle())
		if input_router.has_signal("trim_pitch_requested"):
			input_router.trim_pitch_requested.connect(func(d): trim_manager.adjust_pitch(d))
		if input_router.has_signal("trim_roll_requested"):
			input_router.trim_roll_requested.connect(func(d): trim_manager.adjust_roll(d))
		if input_router.has_signal("camera_tilt_requested"):
			input_router.camera_tilt_requested.connect(func(d): gimbal_pitch_user_deg = clampf(gimbal_pitch_user_deg + d * 30.0, -90.0, 20.0))

	if battery_model:
		battery_model.battery_warning_low.connect(func(_pct): HapticsManager.play_haptic(HapticsManager.Effect.BATTERY_LOW))
		battery_model.auto_rth_triggered.connect(func(): trigger_rth())
		battery_model.forced_landing_triggered.connect(func(): land())

	if state_machine:
		state_machine.state_name_changed.connect(func(n): drone_state_changed.emit(n))
		state_machine.takeoff_completed.connect(func(): takeoff_completed.emit())
		state_machine.landing_completed.connect(func(): landing_completed.emit())
		state_machine.crash_detected.connect(func(r): drone_crashed.emit(15.0))

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
			if data is Dictionary:
				if data.has("drone_physical"):
					all_profiles["drone_physical"] = data["drone_physical"]
				if data.has("profiles"):
					for k in data["profiles"].keys():
						all_profiles[k] = data["profiles"][k]

func set_flight_profile(profile_name: String) -> void:
	if all_profiles.has(profile_name):
		active_profile_name = profile_name
		active_profile = all_profiles[profile_name]
		pitch_pid_p = active_profile.get("auto_level_strength", 6.0)
		roll_pid_p = pitch_pid_p
		if flight_controller:
			var phys_data = all_profiles.get("drone_physical", {
				"mass_kg": drone_mass,
				"arm_length_m": arm_length,
				"max_total_thrust_n": max_thrust_per_motor * 4.0,
				"max_motor_thrust_n": max_thrust_per_motor
			})
			flight_controller.configure(active_profile, phys_data)
		if flip_controller:
			var flip_rate = active_profile.get("flip_rate_deg", 720.0)
			var boost_t = active_profile.get("flip_boost_time", 0.12)
			var lead_r = active_profile.get("flip_lead_rad", 0.90)
			flip_controller.configure(flip_rate, boost_t, lead_r)
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

	if state_machine:
		state_machine.update(safe_delta, altitude_agl, ground_speed, linear_velocity.y, pitch_deg)
		if state_machine.is_crashed():
			for i in range(4):
				target_motor_rpms[i] = 0.0
				motor_rpms[i] = 0.0

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

	# Downward raycast via PhysicsDirectSpaceState3D every physics tick
	var ray_agl: float = -1.0
	if is_inside_tree() and get_world_3d():
		var space_state = get_world_3d().direct_space_state
		var origin_pt = global_position if use_global else position
		var target_pt = origin_pt + Vector3(0.0, -100.0, 0.0)
		var query = PhysicsRayQueryParameters3D.create(origin_pt, target_pt)
		query.exclude = [get_rid()]
		var result = space_state.intersect_ray(query)
		if not result.is_empty() and result.has("position"):
			ray_agl = maxf(0.0, origin_pt.y - result["position"].y)

	if ray_agl >= 0.0:
		altitude_agl = ray_agl
	elif raycast_ground and raycast_ground.is_inside_tree() and raycast_ground.is_colliding():
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
	if is_boosted:
		drain_mah *= 2.0 # Pilot boost mode doubles power consumption

	battery_remaining_mah = maxf(0.0, battery_remaining_mah - drain_mah)
	battery_percent = (battery_remaining_mah / battery_capacity_mah) * 100.0
	battery = battery_percent / 100.0
	battery_voltage = 13.6 + (battery_percent / 100.0) * 3.2

	if battery_model:
		battery_model.remaining_wh = (battery_percent / 100.0) * battery_model.capacity_wh
		if battery_percent <= 15.0 and current_state == DroneState.FLYING:
			trigger_rth()
		elif battery_percent <= 5.0 and (current_state == DroneState.FLYING or current_state == DroneState.HOVER or current_state == DroneState.RTH):
			land()

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
	# Phase 5: FlipController aerobatic maneuvers take precedence during active flips
	if flip_controller and flip_controller.is_active():
		var cur_b = global_transform.basis.orthonormalized() if (is_inside_tree() and is_node_ready()) else transform.basis.orthonormalized()
		var local_w = cur_b.transposed() * angular_velocity
		var up_y = cur_b.y.y
		var override = flip_controller.step(local_w, up_y, delta)
		var neutral_frame = ControlFrame.new(0.0, 0.0, 0.0, 0.0)
		var out = flight_controller.step(cur_b, angular_velocity, linear_velocity, neutral_frame, override, delta)
		for i in range(4):
			target_motor_rpms[i] = clampf(out.motors[i] / max_thrust_per_motor, 0.0, 1.0)
		if not flip_controller.is_active():
			if state_machine:
				state_machine.transition_to(FlightStateMachine.State.FLYING, "FLIP_COMPLETED")
				drone_state_changed.emit("FLYING")
		return

	if stunt_engine and stunt_engine.is_performing_stunt():
		stunt_engine.process_stunt_physics(delta, self)
		return

	var in_throttle = input_router.throttle if input_router else 0.0
	var in_yaw = input_router.yaw if input_router else 0.0
	var in_pitch = input_router.pitch if input_router else 0.0
	var in_roll = input_router.roll if input_router else 0.0

	# Apply Trim
	if trim_manager:
		var trimmed = trim_manager.apply_trim(Vector2(in_roll, in_pitch))
		in_roll = trimmed.x
		in_pitch = trimmed.y

	# Apply Headless Mode
	if headless_controller and headless_controller.is_enabled:
		var corrected = headless_controller.process_stick(Vector2(in_roll, in_pitch), deg_to_rad(heading_deg))
		in_roll = corrected.x
		in_pitch = corrected.y

	# Apply Active Braking in ANGLE mode
	if brake_controller and (flight_mode_manager == null or flight_mode_manager.current_mode == FlightModeManager.Mode.ANGLE):
		var heading_b = Basis(Vector3.UP, deg_to_rad(heading_deg))
		var brake_res = brake_controller.compute_brake_tilt(linear_velocity, heading_b, Vector2(in_roll, in_pitch), 0.12, flight_controller.max_tilt, is_braking)
		if brake_res.active:
			in_pitch += brake_res.pitch_offset / maxf(0.001, flight_controller.max_tilt)
			in_roll += brake_res.roll_offset / maxf(0.001, flight_controller.max_tilt)
			in_pitch = clampf(in_pitch, -1.0, 1.0)
			in_roll = clampf(in_roll, -1.0, 1.0)

	# Apply Pilot Boost (x1.4 tilt and climb)
	if is_boosted:
		in_pitch = clampf(in_pitch * 1.4, -1.0, 1.0)
		in_roll = clampf(in_roll * 1.4, -1.0, 1.0)
		if in_throttle > 0.0:
			in_throttle = clampf(in_throttle * 1.4, 0.0, 1.0)

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

	var cur_basis = global_transform.basis.orthonormalized() if (is_inside_tree() and is_node_ready()) else transform.basis.orthonormalized()

	# Fetch unified ControlFrame
	var frame: ControlFrame = null
	if input_router and input_router.current_frame:
		frame = input_router.current_frame.duplicate_frame()
		if in_throttle != 0.0: frame.throttle = in_throttle
		if in_yaw != 0.0: frame.yaw = in_yaw
		if in_pitch != 0.0: frame.pitch = in_pitch
		if in_roll != 0.0: frame.roll = in_roll
	else:
		frame = ControlFrame.new(in_throttle, in_yaw, in_pitch, in_roll)

	if altitude_agl >= max_flight_altitude and frame.throttle > 0.0:
		frame.throttle = 0.0

	var out = flight_controller.step(cur_basis, angular_velocity, linear_velocity, frame, {}, delta)
	for i in range(4):
		target_motor_rpms[i] = clampf(out.motors[i] / max_thrust_per_motor, 0.0, 1.0)

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
	if rth_controller:
		rth_controller.record_home(spawn_transform.origin)
		var cur_pos = global_position if is_inside_tree() else position
		rth_controller.start_rth(cur_pos, altitude_agl)
	drone_state_changed.emit("RTH")
	rth_state_changed.emit(true, get_home_distance())
	print("[FLIGHT] RTH_ACTIVATED — Clearance Altitude: %.1f m" % rth_clearance_altitude)
	return true

func cancel_rth() -> void:
	if rth_controller:
		rth_controller.cancel("PILOT_CANCELLED")
	if current_state == DroneState.RTH:
		current_state = DroneState.FLYING
		drone_state_changed.emit("FLYING")
		rth_state_changed.emit(false, get_home_distance())
		print("[FLIGHT] RTH_CANCELLED — Manual Control Restored")

func _on_emergency_stop_pressed() -> void:
	print("[SAFETY] EMERGENCY_STOP_TRIGGERED — Zeroing motors immediately")
	if flip_controller:
		flip_controller.cancel()
	for i in range(4):
		target_motor_rpms[i] = 0.0
		motor_rpms[i] = 0.0
	if state_machine:
		state_machine.handle_emergency_stop()
	else:
		current_state = DroneState.CRASHED
	drone_crashed.emit(25.0)

func emergency_motor_cut() -> void:
	_on_emergency_stop_pressed()

func reset_to_pad() -> void:
	print("[COMMAND] RESET_REQUESTED")
	if flip_controller:
		flip_controller.cancel()
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
	battery = 1.0
	if battery_model:
		battery_model.reset()
	if rth_controller:
		rth_controller.cancel("RESET_TO_PAD")
	total_flight_time = 0.0
	current_state = DroneState.DISARMED
	drone_state_changed.emit("DISARMED")
	print("[FLIGHT] RESET_COMPLETE — Placed on Pad")

func get_home_distance() -> float:
	var home_pos = spawn_transform.origin
	var cur_pos = global_position if (is_inside_tree() and is_node_ready()) else position
	if Engine.has_singleton("WorldOrigin"):
		var wo = Engine.get_singleton("WorldOrigin")
		home_pos = wo.to_true_world(home_pos)
		cur_pos = wo.to_true_world(cur_pos)
	var home_flat = Vector2(home_pos.x, home_pos.z)
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
	var yaw_torque = yaw_diff * max_thrust_per_motor * 0.016

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
	var f_mode = flight_mode_manager.get_mode_name() if flight_mode_manager else "ANGLE"
	var time_rem = battery_model.get_estimated_time_remaining_seconds() if battery_model else 900.0

	var cur_pos = global_position if (is_inside_tree() and is_node_ready()) else position
	var home_p = spawn_transform.origin
	if Engine.has_singleton("WorldOrigin"):
		var wo = Engine.get_singleton("WorldOrigin")
		cur_pos = wo.to_true_world(cur_pos)
		home_p = wo.to_true_world(home_p)

	var data = {
		"state": DroneState.keys()[current_state],
		"profile": active_profile.get("name", "Normal"),
		"flight_mode": f_mode,
		"altitude_agl": altitude_agl,
		"altitude_msl": altitude_msl,
		"speed": ground_speed,
		"climb_rate": climb_rate,
		"heading": heading_deg,
		"pitch": pitch_deg,
		"roll": roll_deg,
		"battery_pct": battery_percent,
		"battery_volts": battery_voltage,
		"battery_time_remaining": time_rem,
		"motor_rpms": motor_rpms,
		"drone_pos": cur_pos,
		"home_pos": home_p,
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
	if flip_controller and flip_controller.is_active():
		return
	if stunt_engine:
		stunt_engine.trigger_stunt(stunt_type, self)

func _on_flip_pressed(dir: Vector2) -> void:
	if stunt_engine and stunt_engine.is_performing_stunt():
		return
	perform_flip(dir)

func perform_flip(dir: Vector2 = Vector2(0, -1)) -> bool:
	if not flip_controller or not state_machine:
		return false
	if not state_machine.is_flying():
		return false
	var is_acro: bool = (active_profile_name == "acro" or active_profile.get("name", "") == "Acro / Manual")
	var requested: bool = flip_controller.request(dir, altitude_agl, battery, is_acro)
	if requested:
		state_machine.transition_to(FlightStateMachine.State.FLIPPING, "FLIP_STARTED")
		drone_state_changed.emit("FLIPPING")
		HapticsManager.play_haptic(HapticsManager.Effect.FLIP_COMPLETED)
		print("[FLIGHT] FLIP_INITIATED — Direction: %s" % str(dir))
		return true
	return false

func is_flipping() -> bool:
	return flip_controller != null and flip_controller.is_active()

func _on_flight_mode_cycle_requested() -> void:
	if flight_mode_manager:
		flight_mode_manager.cycle_mode()
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
		HapticsManager.play_haptic(HapticsManager.Effect.COLLISION)
