class_name HeadlessController
extends RefCounted

## HeadlessController: Pilot-Centric Reference Orientation (Phase 7).
## Captures reference heading upon takeoff/arming, and rotates pitch/roll stick inputs
## by (current_yaw - reference_yaw) so stick forward always flies away from the pilot.
## ZERO scene-tree/node access.

var is_enabled: bool = false
var ref_heading_rad: float = 0.0

signal headless_toggled(enabled: bool)

func record_reference_heading(current_heading_rad: float) -> void:
	ref_heading_rad = current_heading_rad

func toggle() -> bool:
	is_enabled = not is_enabled
	headless_toggled.emit(is_enabled)
	return is_enabled

func set_enabled(enabled: bool) -> void:
	if is_enabled != enabled:
		is_enabled = enabled
		headless_toggled.emit(is_enabled)

## Transforms pilot 2D stick vector (roll, pitch) based on heading delta.
## - stick: Vector2(roll, pitch) where pitch > 0 is forward, roll > 0 is right
## - current_heading_rad: Current drone yaw heading angle about +Y (radians)
## Returns Vector2(roll_corrected, pitch_corrected) in [-1, 1].
func process_stick(stick: Vector2, current_heading_rad: float) -> Vector2:
	if not is_enabled:
		return stick

	var delta_yaw = current_heading_rad - ref_heading_rad

	# Rotate stick vector by -delta_yaw:
	# [roll_out ] = [ cos(dy)   sin(dy) ] [ roll_in  ]
	# [pitch_out] = [ -sin(dy)  cos(dy) ] [ pitch_in ]
	var cos_y = cos(delta_yaw)
	var sin_y = sin(delta_yaw)

	var rot_roll = stick.x * cos_y + stick.y * sin_y
	var rot_pitch = -stick.x * sin_y + stick.y * cos_y

	# Clamp to unit circle / [-1, 1]
	var len_sq = rot_roll * rot_roll + rot_pitch * rot_pitch
	if len_sq > 1.0:
		var norm = 1.0 / sqrt(len_sq)
		rot_roll *= norm
		rot_pitch *= norm

	return Vector2(rot_roll, rot_pitch)
