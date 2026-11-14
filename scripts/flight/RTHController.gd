class_name RTHController
extends RefCounted

## RTHController: Precision Return-to-Home Autonomous Navigation (Phase 7).
## Executes 3-phase automated recovery:
## 1. CLIMB: Ascend to max(current_agl, clearance_alt = 15.0m).
## 2. CRUISE: Navigates towards launch coordinates via planar velocity P-loop (max 8.0 m/s).
## 3. DESCENT & TOUCHDOWN: Decelerates within 1.0m radius, descends at 0.8 m/s to ground.
## Any pilot stick deflection > 0.3 immediately cancels RTH and returns full manual control.
## ZERO scene-tree/node access.

enum Phase {
	IDLE,
	CLIMB,
	CRUISE,
	DESCENT,
	TOUCHDOWN
}

const PHASE_NAMES: Dictionary = {
	Phase.IDLE: "IDLE",
	Phase.CLIMB: "CLIMB",
	Phase.CRUISE: "CRUISE",
	Phase.DESCENT: "DESCENT",
	Phase.TOUCHDOWN: "TOUCHDOWN"
}

var phase: Phase = Phase.IDLE
var home_position_world: Vector3 = Vector3.ZERO
var clearance_altitude: float = 15.0 # Minimum cruise altitude AGL (m)
var target_cruise_altitude: float = 15.0
var max_cruise_speed: float = 8.0 # Max horizontal transit speed (m/s)
var home_arrival_radius: float = 1.0 # 1.0m radius threshold to initiate descent
var kp_nav: float = 1.2 # Position error -> commanded velocity P-gain

signal rth_phase_changed(phase: Phase, phase_name: String)
signal rth_completed()
signal rth_cancelled(reason: String)

func record_home(home_pos: Vector3) -> void:
	home_position_world = home_pos

func start_rth(current_pos_world: Vector3, current_agl: float) -> bool:
	if phase != Phase.IDLE:
		return false

	target_cruise_altitude = maxf(current_agl, clearance_altitude)
	phase = Phase.CLIMB
	rth_phase_changed.emit(phase, get_phase_name())
	return true

func cancel(reason: String = "PILOT_STICK_OVERRIDE") -> void:
	if phase != Phase.IDLE:
		phase = Phase.IDLE
		rth_cancelled.emit(reason)
		rth_phase_changed.emit(phase, get_phase_name())

func is_active() -> bool:
	return phase != Phase.IDLE

func get_phase_name() -> String:
	return PHASE_NAMES.get(phase, "IDLE")

## Step function: Evaluates navigation step.
## - current_pos: World coordinates Vector3
## - current_agl: Altitude above ground level (m)
## - heading_basis: Current drone yaw heading basis
## - stick_input: Raw pilot stick Vector2(roll, pitch)
## - delta: Timestep in seconds
## Returns Dictionary with commanded { "active": bool, "pitch_cmd": float, "roll_cmd": float, "throttle_cmd": float, "done": bool }
func step(current_pos: Vector3, current_agl: float, heading_basis: Basis,
		stick_input: Vector2, delta: float) -> Dictionary:
	if phase == Phase.IDLE:
		return {"active": false}

	# Failsafe: Pilot stick deflection > 0.3 cancels RTH
	if stick_input.length() > 0.3:
		cancel("PILOT_STICK_OVERRIDE")
		return {"active": false}

	var to_home_world = Vector2(home_position_world.x - current_pos.x, home_position_world.z - current_pos.z)
	var horiz_dist = to_home_world.length()

	var pitch_cmd: float = 0.0
	var roll_cmd: float = 0.0
	var throttle_cmd: float = 0.0

	match phase:
		Phase.CLIMB:
			# Climb vertically to target_cruise_altitude
			throttle_cmd = 0.65
			var alt_err = target_cruise_altitude - current_agl
			if alt_err <= 0.3:
				phase = Phase.CRUISE
				rth_phase_changed.emit(phase, get_phase_name())

		Phase.CRUISE:
			# Maintain cruise altitude (throttle = 0.0 holds altitude in ANGLE mode)
			throttle_cmd = 0.0

			if horiz_dist <= home_arrival_radius:
				phase = Phase.DESCENT
				rth_phase_changed.emit(phase, get_phase_name())
			else:
				# Transform world vector to home into heading frame:
				# World vector: X = East, Z = South.
				# Drone heading frame: Forward = -Z, Right = +X.
				var target_dir_world = Vector3(to_home_world.x, 0.0, to_home_world.y).normalized()
				var target_dir_heading = heading_basis.transposed() * target_dir_world

				var speed_cmd = clampf(horiz_dist * kp_nav, 0.5, max_cruise_speed)
				var norm_speed = speed_cmd / max_cruise_speed

				# In heading frame: target_dir_heading.z < 0 is forward -> pitch_cmd > 0
				# target_dir_heading.x > 0 is right -> roll_cmd > 0
				pitch_cmd = clampf(-target_dir_heading.z * norm_speed * 0.75, -1.0, 1.0)
				roll_cmd = clampf(target_dir_heading.x * norm_speed * 0.75, -1.0, 1.0)

		Phase.DESCENT:
			# Controlled vertical descent over home pad (-0.8 m/s climb rate equivalent)
			throttle_cmd = -0.45

			# Fine position corrections over pad
			if horiz_dist > 0.15:
				var target_dir_world = Vector3(to_home_world.x, 0.0, to_home_world.y).normalized()
				var target_dir_heading = heading_basis.transposed() * target_dir_world
				pitch_cmd = clampf(-target_dir_heading.z * 0.15, -0.2, 0.2)
				roll_cmd = clampf(target_dir_heading.x * 0.15, -0.2, 0.2)

			if current_agl <= 0.18:
				phase = Phase.TOUCHDOWN
				rth_phase_changed.emit(phase, get_phase_name())

		Phase.TOUCHDOWN:
			throttle_cmd = -1.0
			phase = Phase.IDLE
			rth_completed.emit()
			return {"active": false, "done": true}

	return {
		"active": true,
		"pitch_cmd": pitch_cmd,
		"roll_cmd": roll_cmd,
		"throttle_cmd": throttle_cmd,
		"done": false
	}
