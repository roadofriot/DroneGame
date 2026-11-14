class_name InputRouter
extends Node

## InputRouter: Unified input abstraction for Drone Flight
## Handles Keyboard, Physical Gamepad, and Virtual Touch Joysticks without conflict.

signal takeoff_land_requested
signal reset_requested
signal camera_toggle_requested
signal flight_mode_cycle_requested
signal stunt_requested(stunt_type: String)

# Normalized control values [-1.0 .. 1.0]
var throttle: float = 0.0
var yaw: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0

# Virtual joystick overrides (from on-screen HUD controls)
var virtual_throttle: float = 0.0
var virtual_yaw: float = 0.0
var virtual_pitch: float = 0.0
var virtual_roll: float = 0.0
var virtual_override_active: bool = false

# Tuning
@export var deadzone: float = 0.08
@export var expo: float = 0.25
@export var invert_pitch: bool = false

func _process(_delta: float) -> void:
	_poll_inputs()
	_check_action_triggers()

func _poll_inputs() -> void:
	# Read physical inputs (Keyboard / Gamepad)
	var raw_throttle: float = 0.0
	if Input.is_action_pressed("throttle_up"):
		raw_throttle += 1.0
	if Input.is_action_pressed("throttle_down"):
		raw_throttle -= 1.0

	var raw_yaw: float = 0.0
	if Input.is_action_pressed("yaw_right"):
		raw_yaw += 1.0
	if Input.is_action_pressed("yaw_left"):
		raw_yaw -= 1.0

	var raw_pitch: float = 0.0
	if Input.is_action_pressed("pitch_forward"):
		raw_pitch += 1.0
	if Input.is_action_pressed("pitch_backward"):
		raw_pitch -= 1.0

	var raw_roll: float = 0.0
	if Input.is_action_pressed("roll_right"):
		raw_roll += 1.0
	if Input.is_action_pressed("roll_left"):
		raw_roll -= 1.0

	# Combine with virtual touch sticks (whichever has larger magnitude)
	var final_throttle: float = raw_throttle if abs(raw_throttle) >= abs(virtual_throttle) else virtual_throttle
	var final_yaw: float = raw_yaw if abs(raw_yaw) >= abs(virtual_yaw) else virtual_yaw
	var final_pitch: float = raw_pitch if abs(raw_pitch) >= abs(virtual_pitch) else virtual_pitch
	var final_roll: float = raw_roll if abs(raw_roll) >= abs(virtual_roll) else virtual_roll

	if invert_pitch:
		final_pitch = -final_pitch

	# Apply deadzone & expo
	throttle = _apply_expo(_apply_deadzone(final_throttle, deadzone), expo)
	yaw = _apply_expo(_apply_deadzone(final_yaw, deadzone), expo)
	pitch = _apply_expo(_apply_deadzone(final_pitch, deadzone), expo)
	roll = _apply_expo(_apply_deadzone(final_roll, deadzone), expo)

func _check_action_triggers() -> void:
	if Input.is_action_just_pressed("flight_takeoff_land"):
		takeoff_land_requested.emit()
	if Input.is_action_just_pressed("flight_reset"):
		reset_requested.emit()
	if Input.is_action_just_pressed("camera_mode"):
		camera_toggle_requested.emit()
	if Input.is_action_just_pressed("flight_mode_next"):
		flight_mode_cycle_requested.emit()

func set_virtual_left_stick(stick_x: float, stick_y: float) -> void:
	# Left stick: X = yaw (-1=left, 1=right), Y = throttle (1=up, -1=down)
	virtual_yaw = clampf(stick_x, -1.0, 1.0)
	virtual_throttle = clampf(stick_y, -1.0, 1.0)

func set_virtual_right_stick(stick_x: float, stick_y: float) -> void:
	# Right stick: X = roll (-1=left, 1=right), Y = pitch (1=forward, -1=back)
	virtual_roll = clampf(stick_x, -1.0, 1.0)
	virtual_pitch = clampf(stick_y, -1.0, 1.0)

func request_takeoff_land() -> void:
	takeoff_land_requested.emit()

func request_reset() -> void:
	reset_requested.emit()

func request_camera_toggle() -> void:
	camera_toggle_requested.emit()

func request_flight_mode_cycle() -> void:
	flight_mode_cycle_requested.emit()

func request_stunt(type: String) -> void:
	stunt_requested.emit(type)

func _apply_deadzone(val: float, dz: float) -> float:
	var abs_val: float = absf(val)
	if abs_val <= dz:
		return 0.0
	var sign_val: float = signf(val)
	return sign_val * ((abs_val - dz) / (1.0 - dz))

func _apply_expo(val: float, ex: float) -> float:
	# Expo curve: y = (1 - ex) * x + ex * x^3
	return (1.0 - ex) * val + ex * (val * val * val)
