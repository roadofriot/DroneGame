class_name TrimManager
extends RefCounted

## TrimManager: Sub-Trim Offset Calibration & Persistence (Phase 7).
## Adjusts fine roll and pitch trim within [-0.2, +0.2] in 0.02 increments.
## Persists trim values across sessions in user://settings.cfg.

const CONFIG_PATH: String = "user://settings.cfg"
const TRIM_SECTION: String = "flight_trim"
const MAX_TRIM: float = 0.20
const STEP_TRIM: float = 0.02

var pitch_trim: float = 0.0
var roll_trim: float = 0.0

signal trim_changed(pitch: float, roll: float)

func _init() -> void:
	load_trim()

func adjust_pitch(direction: float) -> float:
	var delta = signf(direction) * STEP_TRIM
	pitch_trim = clampf(pitch_trim + delta, -MAX_TRIM, MAX_TRIM)
	trim_changed.emit(pitch_trim, roll_trim)
	save_trim()
	return pitch_trim

func adjust_roll(direction: float) -> float:
	var delta = signf(direction) * STEP_TRIM
	roll_trim = clampf(roll_trim + delta, -MAX_TRIM, MAX_TRIM)
	trim_changed.emit(pitch_trim, roll_trim)
	save_trim()
	return roll_trim

func reset_trim() -> void:
	pitch_trim = 0.0
	roll_trim = 0.0
	trim_changed.emit(pitch_trim, roll_trim)
	save_trim()

func apply_trim(stick: Vector2) -> Vector2:
	return Vector2(
		clampf(stick.x + roll_trim, -1.0, 1.0),
		clampf(stick.y + pitch_trim, -1.0, 1.0)
	)

func save_trim() -> void:
	var config = ConfigFile.new()
	config.load(CONFIG_PATH) # Load existing file if present so we don't overwrite other settings
	config.set_value(TRIM_SECTION, "pitch_trim", pitch_trim)
	config.set_value(TRIM_SECTION, "roll_trim", roll_trim)
	config.save(CONFIG_PATH)

func load_trim() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		pitch_trim = clampf(config.get_value(TRIM_SECTION, "pitch_trim", 0.0), -MAX_TRIM, MAX_TRIM)
		roll_trim = clampf(config.get_value(TRIM_SECTION, "roll_trim", 0.0), -MAX_TRIM, MAX_TRIM)
	else:
		pitch_trim = 0.0
		roll_trim = 0.0
