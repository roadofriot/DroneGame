class_name FlipController
extends RefCounted

## FlipController: Physically consistent 4-axis aerobatic flip controller for MindSparQ Drone Simulator.
## Phases: IDLE -> BOOST -> ROTATE -> RECOVER -> IDLE.
## Pure RefCounted logic: Computes target angular velocity overrides and thrust scaling for FlightController.
## ZERO scene-tree/node access.

enum Phase {
	IDLE,
	BOOST,
	ROTATE,
	RECOVER
}

const PHASE_NAMES: Dictionary = {
	Phase.IDLE: "IDLE",
	Phase.BOOST: "BOOST",
	Phase.ROTATE: "ROTATE",
	Phase.RECOVER: "RECOVER"
}

# Runtime State
var phase: Phase = Phase.IDLE
var axis_local: Vector3 = Vector3.ZERO
var timer: float = 0.0
var angle_accum: float = 0.0

# Tunable Parameters (per-profile via configure())
var flip_rate_rad: float = deg_to_rad(720.0) # Target rotation rate (rad/s)
var boost_time: float = 0.12 # Upward pop duration (s)
var lead_rad: float = 0.90 # Lead angle before TAU to trigger recovery (rad)
var timeout: float = 1.5 # Safety timeout per phase (s)

func _init() -> void:
	reset()

func reset() -> void:
	phase = Phase.IDLE
	axis_local = Vector3.ZERO
	timer = 0.0
	angle_accum = 0.0

func configure(flip_rate_deg: float = 720.0, b_time: float = 0.12, l_rad: float = 0.90) -> void:
	flip_rate_rad = deg_to_rad(flip_rate_deg)
	boost_time = b_time
	lead_rad = l_rad

## Snaps 2D stick direction to 3D rotation axis in Godot body frame:
## - Front flip (dir.y > 0): -X (Vector3(-1, 0, 0)) -> pitch forward / nose down
## - Back flip (dir.y <= 0 and abs(dir.y) >= abs(dir.x)): +X (Vector3(1, 0, 0)) -> pitch back / nose up
## - Left roll (dir.x < 0): +Z (Vector3(0, 0, 1)) -> roll left / bank left
## - Right roll (dir.x > 0): -Z (Vector3(0, 0, -1)) -> roll right / bank right
static func dir_to_axis(dir: Vector2) -> Vector3:
	if absf(dir.x) > absf(dir.y):
		return Vector3(0.0, 0.0, 1.0) if dir.x < 0.0 else Vector3(0.0, 0.0, -1.0)
	else:
		return Vector3(-1.0, 0.0, 0.0) if dir.y > 0.0 else Vector3(1.0, 0.0, 0.0)

## Requests flip initiation. Validates all safety preconditions:
## - Must be currently IDLE (no active flip)
## - AGL must be >= 4.0 meters
## - Battery percentage must be >= 20% (0.20)
## - Flight mode must not be Acro
func request(dir: Vector2, agl: float, battery_pct: float, is_acro: bool) -> bool:
	if phase != Phase.IDLE:
		return false
	if agl < 4.0:
		return false
	if battery_pct < 0.20:
		return false
	if is_acro:
		return false

	axis_local = dir_to_axis(dir)
	phase = Phase.BOOST
	timer = 0.0
	angle_accum = 0.0
	return true

## Step function: Computes flight overrides during flip maneuver.
## - w_local: Current angular velocity in body frame (body.transposed() * w_world)
## - up_y: Drone up-vector Y component in world frame (up.y = body.y.y)
## - dt: Simulation delta time
## Returns dictionary with optional 'w_target' and 'thrust_scale'.
func step(w_local: Vector3, up_y: float, dt: float) -> Dictionary:
	if phase == Phase.IDLE:
		return {}

	timer += dt

	match phase:
		Phase.BOOST:
			# BOOST: Vertical pop at 1.6x thrust to counter subsequent altitude loss
			if timer >= boost_time:
				phase = Phase.ROTATE
				timer = 0.0
				angle_accum = 0.0
				return {
					"w_target": axis_local * flip_rate_rad,
					"thrust_scale": 0.5
				}
			return {
				"thrust_scale": 1.6
			}

		Phase.ROTATE:
			# ROTATE: High rotational rate target around axis_local
			# Cut thrust to 0.0 when inverted (up_y < 0.0) to prevent pulling the drone into the ground!
			var thrust_s: float = 0.0 if up_y < 0.0 else 0.5
			var rate_proj: float = absf(w_local.dot(axis_local))
			angle_accum += rate_proj * dt

			# Exit rotation at TAU - lead (~0.9 rad lead allows deceleration to settle upright)
			if angle_accum >= (TAU - lead_rad) or timer >= timeout:
				phase = Phase.RECOVER
				timer = 0.0
				return {
					"thrust_scale": 1.2
				}

			return {
				"w_target": axis_local * flip_rate_rad,
				"thrust_scale": thrust_s
			}

		Phase.RECOVER:
			# RECOVER: Angle mode auto-levels with 1.2x thrust to arrest descent.
			# Exit when upright (up_y > 0.9) and angular rate is settled (|w| < 1.5 rad/s), or timeout
			var ang_speed: float = w_local.length()
			if (up_y > 0.9 and ang_speed < 1.5) or timer >= timeout:
				phase = Phase.IDLE
				timer = 0.0
				return {}

			return {
				"thrust_scale": 1.2
			}

	return {}

func is_active() -> bool:
	return phase != Phase.IDLE

func cancel() -> void:
	phase = Phase.IDLE
	timer = 0.0
	angle_accum = 0.0

func get_phase_name() -> String:
	return PHASE_NAMES.get(phase, "UNKNOWN")
