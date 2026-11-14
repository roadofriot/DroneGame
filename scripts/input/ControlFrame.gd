class_name ControlFrame
extends RefCounted

## ControlFrame: Normalized Flight Input Data Contract.
## Guarantees uniform axis ranges [-1.0 .. +1.0] across Keyboard, Gamepad, and Touch.
## Axis conventions:
## - throttle: +1.0 = Climb (Up), -1.0 = Descend (Down)
## - yaw:      +1.0 = Turn Right (Clockwise / Neg Y rot), -1.0 = Turn Left (Counter-Clockwise)
## - pitch:    +1.0 = Pitch Forward (-Z heading frame), -1.0 = Pitch Backward (+Z heading frame)
## - roll:     +1.0 = Roll Right (+X heading frame), -1.0 = Roll Left (-X heading frame)

var throttle: float = 0.0
var yaw: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0

func _init(p_throttle: float = 0.0, p_yaw: float = 0.0, p_pitch: float = 0.0, p_roll: float = 0.0) -> void:
	throttle = clampf(p_throttle, -1.0, 1.0)
	yaw = clampf(p_yaw, -1.0, 1.0)
	pitch = clampf(p_pitch, -1.0, 1.0)
	roll = clampf(p_roll, -1.0, 1.0)

func clamp_values() -> void:
	throttle = clampf(throttle, -1.0, 1.0)
	yaw = clampf(yaw, -1.0, 1.0)
	pitch = clampf(pitch, -1.0, 1.0)
	roll = clampf(roll, -1.0, 1.0)

func reset() -> void:
	throttle = 0.0
	yaw = 0.0
	pitch = 0.0
	roll = 0.0

func duplicate_frame() -> ControlFrame:
	return ControlFrame.new(throttle, yaw, pitch, roll)

func to_dict() -> Dictionary:
	return {
		"throttle": throttle,
		"yaw": yaw,
		"pitch": pitch,
		"roll": roll
	}
