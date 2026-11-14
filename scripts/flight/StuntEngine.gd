class_name StuntEngine
extends Node

## StuntEngine: Physics-aware aerobatic flight maneuver controller.
## Handles Front Flips, Back Flips, and Barrel Rolls with altitude gating,
## dynamic motor differential torques, stability recovery, and quality scoring.

signal stunt_started(stunt_type: String)
signal stunt_completed(stunt_type: String, score: int, quality: String)
signal stunt_failed(reason: String)
signal cooldown_updated(time_remaining: float, total_cooldown: float)

enum StuntState { IDLE, PRE_BOOST, ROTATING, RECOVERY }

# Configuration
@export var min_altitude_required: float = 3.0 # Meters AGL
@export var cooldown_duration: float = 1.8 # Seconds between stunts
@export var stunt_duration: float = 0.65 # Seconds for complete 360 maneuver
@export var custom_stunts_enabled: bool = false # Override flight mode gate if requested

# Runtime State
var is_stunting: bool = false
var current_stunt: String = ""
var stunt_phase: StuntState = StuntState.IDLE
var stunt_timer: float = 0.0
var cooldown_timer: float = 0.0
var start_altitude: float = 0.0
var target_drone: FlightPhysics

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(0.0, cooldown_timer - delta)
		cooldown_updated.emit(cooldown_timer, cooldown_duration)

func is_performing_stunt() -> bool:
	return is_stunting

func can_perform_stunt(drone: FlightPhysics) -> Dictionary:
	if drone == null:
		return {"allowed": false, "reason": "No drone reference"}

	if drone.current_state != FlightPhysics.DroneState.FLYING:
		return {"allowed": false, "reason": "Drone must be airborne in FLYING state"}

	var stunts_allowed: bool = custom_stunts_enabled
	if drone.active_profile.has("stunts_enabled"):
		stunts_allowed = stunts_allowed or drone.active_profile.get("stunts_enabled", false)

	if not stunts_allowed:
		return {"allowed": false, "reason": "Stunts only permitted in Arcade or Acro mode"}

	if cooldown_timer > 0.0:
		return {"allowed": false, "reason": "Stunt thrusters cooling down (%.1fs)" % cooldown_timer}

	if drone.altitude_agl < min_altitude_required:
		return {"allowed": false, "reason": "Minimum altitude of %.1fm required (current: %.1fm)" % [min_altitude_required, drone.altitude_agl]}

	if absf(drone.pitch_deg) > 40.0 or absf(drone.roll_deg) > 40.0:
		return {"allowed": false, "reason": "Drone attitude too steep; level flight required"}

	return {"allowed": true, "reason": "Ready"}

func execute_stunt(stunt_type: String, drone: FlightPhysics = null) -> bool:
	if drone == null:
		drone = target_drone if target_drone else get_parent() as FlightPhysics
	return trigger_stunt(stunt_type, drone)

func trigger_stunt(stunt_type: String, drone: FlightPhysics) -> bool:
	var check = can_perform_stunt(drone)
	if not check.get("allowed", false):
		var reason = check.get("reason", "Cannot perform stunt")
		stunt_failed.emit(reason)
		return false

	is_stunting = true
	current_stunt = stunt_type.to_lower()
	stunt_timer = 0.0
	stunt_phase = StuntState.PRE_BOOST
	start_altitude = drone.altitude_agl
	target_drone = drone

	stunt_started.emit(current_stunt)
	return true

func process_stunt_physics(delta: float, drone: FlightPhysics) -> void:
	if not is_stunting:
		return

	# Ground proximity & crash abort checks
	if drone.altitude_agl < 0.6 or drone.current_state == FlightPhysics.DroneState.CRASHED:
		_abort_stunt(drone, "Altitude loss or impact during stunt")
		return

	stunt_timer += delta

	var hover_thrust: float = (drone.drone_mass * 9.8) / (4.0 * drone.max_thrust_per_motor)

	# Phase Breakdown:
	# 0.00 .. 0.12s : PRE_BOOST (Upward pop)
	# 0.12 .. 0.52s : ROTATING (High differential torque for 360 roll/flip)
	# 0.52 .. 0.65s : RECOVERY (Counter torque + Auto-level catch)
	if stunt_timer < 0.12:
		stunt_phase = StuntState.PRE_BOOST
		# Pop upward
		for i in range(4):
			drone.target_motor_rpms[i] = clampf(hover_thrust + 0.35, 0.0, 1.0)

	elif stunt_timer < 0.52:
		stunt_phase = StuntState.ROTATING
		var cur_basis = drone.global_transform.basis.orthonormalized() if (drone.is_inside_tree() and drone.is_node_ready()) else drone.transform.basis.orthonormalized()
		var is_inverted: bool = cur_basis.y.y < 0.0
		var mid_thrust = 0.15 if is_inverted else (hover_thrust * 0.7)
		var rot_w: float = 15.5 # rad/s for crisp 360 degree maneuver

		match current_stunt:
			"front_flip":
				# Nose down: Cut front (0, 1), Boost rear (2, 3)
				drone.target_motor_rpms[0] = clampf(mid_thrust - 0.5, 0.0, 1.0)
				drone.target_motor_rpms[1] = clampf(mid_thrust - 0.5, 0.0, 1.0)
				drone.target_motor_rpms[2] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.target_motor_rpms[3] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.angular_velocity = cur_basis * Vector3(-rot_w, 0.0, 0.0)
			"back_flip":
				# Nose up: Boost front (0, 1), Cut rear (2, 3)
				drone.target_motor_rpms[0] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.target_motor_rpms[1] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.target_motor_rpms[2] = clampf(mid_thrust - 0.5, 0.0, 1.0)
				drone.target_motor_rpms[3] = clampf(mid_thrust - 0.5, 0.0, 1.0)
				drone.angular_velocity = cur_basis * Vector3(rot_w, 0.0, 0.0)
			"roll_left", "barrel_roll_left":
				# Roll left: Boost right (1, 3), Cut left (0, 2)
				drone.target_motor_rpms[0] = clampf(mid_thrust - 0.5, 0.0, 1.0)
				drone.target_motor_rpms[1] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.target_motor_rpms[2] = clampf(mid_thrust - 0.5, 0.0, 1.0)
				drone.target_motor_rpms[3] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.angular_velocity = cur_basis * Vector3(0.0, 0.0, rot_w)
			"roll_right", "barrel_roll_right":
				# Roll right: Boost left (0, 2), Cut right (1, 3)
				drone.target_motor_rpms[0] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.target_motor_rpms[1] = clampf(mid_thrust - 0.5, 0.0, 1.0)
				drone.target_motor_rpms[2] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.target_motor_rpms[3] = clampf(mid_thrust - 0.5, 0.0, 1.0)
				drone.angular_velocity = cur_basis * Vector3(0.0, 0.0, -rot_w)
			"yaw_spin_360", "spin_360":
				# 360 Yaw Rotation: Boost CW (0, 3), cut CCW (1, 2)
				drone.target_motor_rpms[0] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.target_motor_rpms[1] = clampf(mid_thrust - 0.45, 0.0, 1.0)
				drone.target_motor_rpms[2] = clampf(mid_thrust - 0.45, 0.0, 1.0)
				drone.target_motor_rpms[3] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.angular_velocity = cur_basis * Vector3(0.0, rot_w, 0.0)
			_:
				# Default front flip fallback
				drone.target_motor_rpms[0] = clampf(mid_thrust - 0.5, 0.0, 1.0)
				drone.target_motor_rpms[1] = clampf(mid_thrust - 0.5, 0.0, 1.0)
				drone.target_motor_rpms[2] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.target_motor_rpms[3] = clampf(mid_thrust + 0.55, 0.0, 1.0)
				drone.angular_velocity = cur_basis * Vector3(-rot_w, 0.0, 0.0)

	else:
		stunt_phase = StuntState.RECOVERY
		# Auto-level brake catch targeting level attitude (0 deg pitch, 0 deg roll)
		drone.angular_velocity = drone.angular_velocity.move_toward(Vector3.ZERO, delta * 35.0)
		drone._calculate_auto_level_rpms(hover_thrust, 0.0, 0.0, 0.0, delta)

	# Check maneuver completion
	if stunt_timer >= stunt_duration:
		var pitch_err = absf(drone.pitch_deg)
		var roll_err = absf(drone.roll_deg)
		var ang_vel_mag = drone.angular_velocity.length()

		if pitch_err <= 30.0 and roll_err <= 30.0 and ang_vel_mag <= 4.0:
			_complete_stunt(drone)
		elif stunt_timer >= stunt_duration + 0.4:
			# Failed to stabilize in time
			_abort_stunt(drone, "Recovery failed: attitude unstable")

func _complete_stunt(drone: FlightPhysics) -> void:
	var alt_diff = absf(drone.altitude_agl - start_altitude)
	var score: int = 500
	var quality: String = "OK"

	if alt_diff <= 0.8:
		score = 1000
		quality = "PERFECT"
	elif alt_diff <= 1.8:
		score = 750
		quality = "GREAT"
	else:
		score = 500
		quality = "ACCEPTABLE"

	is_stunting = false
	stunt_phase = StuntState.IDLE
	cooldown_timer = cooldown_duration

	stunt_completed.emit(current_stunt, score, quality)

func _abort_stunt(drone: FlightPhysics, reason: String) -> void:
	is_stunting = false
	stunt_phase = StuntState.IDLE
	cooldown_timer = cooldown_duration
	stunt_failed.emit(reason)
