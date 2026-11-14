class_name BrakeController
extends RefCounted

## BrakeController: Active Velocity Braking & Position Damping (Phase 7).
## Adds counter-tilt from horizontal velocity in the heading frame when sticks
## are centered or when the brake action is held, rapidly arresting drift.
## ZERO scene-tree/node access.

# Velocity-to-tilt damping gain (rad / (m/s))
var kv_auto: float = 0.08
var kv_forced: float = 0.16
var max_counter_tilt_ratio: float = 0.60 # Clamped to 60% of max tilt

## Computes pitch and roll counter-tilt angles to arrest drift.
## - v_world: World linear velocity Vector3
## - heading_basis: Basis representing only current yaw heading (UP = Vector3.UP)
## - stick_deflection: Vector2(roll, pitch) from pilot input
## - deadzone: Stick radial deadzone radius (e.g. 0.12)
## - max_tilt_rad: Drone maximum allowable tilt angle in radians
## - is_brake_held: True if pilot is holding explicit brake button
## Returns Dictionary with { "active": bool, "pitch_offset": float, "roll_offset": float }
func compute_brake_tilt(v_world: Vector3, heading_basis: Basis, stick_deflection: Vector2,
		deadzone: float, max_tilt_rad: float, is_brake_held: bool = false) -> Dictionary:
	var stick_mag = stick_deflection.length()
	var should_brake = is_brake_held or (stick_mag <= deadzone)

	if not should_brake:
		return {
			"active": false,
			"pitch_offset": 0.0,
			"roll_offset": 0.0
		}

	# Project horizontal world velocity into heading (yaw) frame:
	# In heading frame: Forward = -Z, Right = +X
	var v_horiz = Vector3(v_world.x, 0.0, v_world.z)
	var v_local = heading_basis.transposed() * v_horiz

	var gain = kv_forced if is_brake_held else kv_auto
	var max_tilt_limit = max_tilt_rad * max_counter_tilt_ratio

	# Sign Conventions:
	# Forward velocity (v_local.z < 0): tilt nose up (pitch backward / pitch_offset < 0)
	# Backward velocity (v_local.z > 0): tilt nose down (pitch forward / pitch_offset > 0)
	# Rightward velocity (v_local.x > 0): bank left (roll_offset < 0)
	# Leftward velocity (v_local.x < 0): bank right (roll_offset > 0)
	var pitch_tilt = clampf(v_local.z * gain, -max_tilt_limit, max_tilt_limit)
	var roll_tilt = clampf(-v_local.x * gain, -max_tilt_limit, max_tilt_limit)

	return {
		"active": true,
		"pitch_offset": pitch_tilt,
		"roll_offset": roll_tilt
	}
