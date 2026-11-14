class_name FlightModeManager
extends RefCounted

## FlightModeManager: Modular Flight Mode Selector & Stick Controller (Phase 7).
## Handles ANGLE (Self-Level), HORIZON (Self-Level to 70% stick, then full rate),
## and ACRO (Pure Rate, Direct Throttle).
## ZERO scene-tree/node access.

enum Mode {
	ANGLE,
	HORIZON,
	ACRO
}

const MODE_NAMES: Dictionary = {
	Mode.ANGLE: "ANGLE",
	Mode.HORIZON: "HORIZON",
	Mode.ACRO: "ACRO"
}

var current_mode: Mode = Mode.ANGLE

signal mode_changed(new_mode: Mode, mode_name: String)

func _init(initial_mode: Mode = Mode.ANGLE) -> void:
	current_mode = initial_mode

func set_mode(mode: Mode) -> void:
	if current_mode != mode:
		current_mode = mode
		mode_changed.emit(current_mode, get_mode_name())

func cycle_mode() -> Mode:
	var next = (int(current_mode) + 1) % 3
	set_mode(next as Mode)
	return current_mode

func get_mode_name() -> String:
	return MODE_NAMES.get(current_mode, "ANGLE")

## Evaluates stick deflection in [-1, 1] and blends angle auto-level vs rate commands.
## - stick: Vector2(roll, pitch) in [-1, 1]
## - auto_level_att: Target angular velocity computed by Attitude P-loop (rad/s)
## - max_rate_rad: Maximum rotational rate for full manual deflection (rad/s)
## Returns blended target angular velocity Vector2(roll_rate, pitch_rate) in rad/s.
func process_attitude_target(stick: Vector2, auto_level_att: Vector2, max_rate_rad: float) -> Vector2:
	match current_mode:
		Mode.ANGLE:
			# Pure self-leveling attitude P-loop
			return auto_level_att

		Mode.ACRO:
			# Pure direct rate command (stick maps directly to angular velocity)
			return stick * max_rate_rad

		Mode.HORIZON:
			# Hybrid: Self-leveling within 70% deflection, smoothly blends to 100% rate at edge
			var deflection = stick.length()
			if deflection <= 0.70:
				return auto_level_att
			else:
				var alpha = clampf((deflection - 0.70) / 0.30, 0.0, 1.0)
				var rate_cmd = stick * max_rate_rad
				return auto_level_att.lerp(rate_cmd, alpha)

	return auto_level_att
