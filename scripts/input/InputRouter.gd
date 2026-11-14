class_name InputRouter
extends Node

const ControlFrame = preload("res://scripts/input/ControlFrame.gd")

## InputRouter: Unified Multi-Source Input Layer for Drone Flight.
## Normalizes Keyboard, Gamepad, and Virtual Touch inputs into an immutable ControlFrame.
## Implements radial deadzone (Input.get_vector), cubic expo curves, conditional keyboard ramping,
## and directional flip vector snapping.

# Phase 2 Core Action Signals
signal takeoff_land_pressed
signal reset_pressed
signal flip_pressed(dir: Vector2)

# Backward Compatibility Signals
signal takeoff_requested
signal land_requested
signal rth_requested
signal takeoff_land_requested
signal reset_requested
signal camera_toggle_requested
signal flight_mode_cycle_requested
signal stunt_requested(stunt_type: String)
signal pause_requested
signal emergency_cut_requested
signal photo_requested

enum InputSource { KEYBOARD, GAMEPAD, TOUCH, NONE }
var last_input_source: InputSource = InputSource.NONE

# Normalized Flight Outputs
var current_frame: RefCounted = null

# Direct property accessors for backward compatibility
var throttle: float = 0.0:
	set(val):
		throttle = val
		if current_frame: current_frame.throttle = val
var yaw: float = 0.0:
	set(val):
		yaw = val
		if current_frame: current_frame.yaw = val
var pitch: float = 0.0:
	set(val):
		pitch = val
		if current_frame: current_frame.pitch = val
var roll: float = 0.0:
	set(val):
		roll = val
		if current_frame: current_frame.roll = val

# Virtual stick inputs (from on-screen HUD)
var virtual_throttle: float = 0.0
var virtual_yaw: float = 0.0
var virtual_pitch: float = 0.0
var virtual_roll: float = 0.0

# Tuning Parameters
@export var deadzone: float = 0.12 # Configurable radial deadzone
@export var expo: float = 0.35     # Configurable cubic expo
@export var invert_pitch: bool = false
@export var gamepad_mode: int = 2  # Mode 2 (Default): Left=Throttle/Yaw, Right=Pitch/Roll

# Keyboard Ramping State (0 -> 1 in ~0.3s = rate 3.33/s, release 6.0 units/s)
const KEY_ATTACK_RATE: float = 3.333
const KEY_RELEASE_RATE: float = 6.0
var _k_throttle: float = 0.0
var _k_yaw: float = 0.0
var _k_pitch: float = 0.0
var _k_roll: float = 0.0

# Key Debounce State for Actions
var _key_states: Dictionary = {}

func _init() -> void:
	current_frame = ControlFrame.new()

func _ready() -> void:
	if not current_frame:
		current_frame = ControlFrame.new()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == 0:
		_neutralize_inputs()

func _neutralize_inputs() -> void:
	throttle = 0.0
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	virtual_throttle = 0.0
	virtual_yaw = 0.0
	virtual_pitch = 0.0
	virtual_roll = 0.0
	_k_throttle = 0.0
	_k_yaw = 0.0
	_k_pitch = 0.0
	_k_roll = 0.0
	current_frame.reset()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		last_input_source = InputSource.KEYBOARD
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		last_input_source = InputSource.GAMEPAD
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		last_input_source = InputSource.TOUCH

func _physics_process(delta: float) -> void:
	_poll_flight_inputs(delta)
	_poll_action_triggers()

func _poll_flight_inputs(delta: float) -> void:
	# 1. Desktop Keyboard Inputs (InputMap actions if pressed, fallback to physical keys)
	var kp_raw: float = 0.0
	if Input.is_action_pressed("pitch_forward") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_I):
		kp_raw += 1.0
	if Input.is_action_pressed("pitch_backward") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_K):
		kp_raw -= 1.0

	var kr_raw: float = 0.0
	if Input.is_action_pressed("roll_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_L):
		kr_raw += 1.0
	if Input.is_action_pressed("roll_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_J):
		kr_raw -= 1.0

	var kt_raw: float = 0.0
	if Input.is_action_pressed("throttle_up") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		kt_raw += 1.0
	if Input.is_action_pressed("throttle_down") or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		kt_raw -= 1.0

	var ky_raw: float = 0.0
	if Input.is_action_pressed("yaw_right") or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_D):
		ky_raw += 1.0
	if Input.is_action_pressed("yaw_left") or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		ky_raw -= 1.0

	# Clamp keyboard targets to [-1.0, 1.0]
	kp_raw = clampf(kp_raw, -1.0, 1.0)
	kr_raw = clampf(kr_raw, -1.0, 1.0)
	kt_raw = clampf(kt_raw, -1.0, 1.0)
	ky_raw = clampf(ky_raw, -1.0, 1.0)

	# Keyboard Ramping: ONLY applied when the active/last source is Keyboard
	if last_input_source == InputSource.KEYBOARD or (last_input_source == InputSource.NONE and (absf(kp_raw) > 0.0 or absf(kr_raw) > 0.0 or absf(kt_raw) > 0.0 or absf(ky_raw) > 0.0)):
		_k_pitch = _ramp_axis(_k_pitch, kp_raw, delta)
		_k_roll = _ramp_axis(_k_roll, kr_raw, delta)
		_k_throttle = _ramp_axis(_k_throttle, kt_raw, delta)
		_k_yaw = _ramp_axis(_k_yaw, ky_raw, delta)
	else:
		_k_pitch = kp_raw
		_k_roll = kr_raw
		_k_throttle = kt_raw
		_k_yaw = ky_raw

	# 2. Gamepad Inputs (Unsmoothed, Radial Deadzone via get_vector)
	var joy_left = Vector2.ZERO
	var joy_right = Vector2.ZERO
	if Input.get_connected_joypads().size() > 0:
		joy_left = Input.get_vector("yaw_left", "yaw_right", "throttle_up", "throttle_down", deadzone)
		joy_right = Input.get_vector("roll_left", "roll_right", "pitch_forward", "pitch_backward", deadzone)

	var joy_throttle: float = 0.0
	var joy_yaw: float = 0.0
	var joy_pitch: float = 0.0
	var joy_roll: float = 0.0

	if gamepad_mode == 2:
		joy_throttle = -joy_left.y
		joy_yaw = joy_left.x
		joy_pitch = -joy_right.y
		joy_roll = joy_right.x
	else:
		joy_pitch = -joy_left.y
		joy_roll = joy_left.x
		joy_yaw = joy_right.x
		joy_throttle = -joy_right.y

	# 3. Combine Inputs across Keyboard, Gamepad, and Virtual Touch (Highest active magnitude wins)
	var raw_throttle = _combine_inputs(_k_throttle, joy_throttle, virtual_throttle)
	var raw_yaw = _combine_inputs(_k_yaw, joy_yaw, virtual_yaw)
	var raw_pitch = _combine_inputs(_k_pitch, joy_pitch, virtual_pitch)
	var raw_roll = _combine_inputs(_k_roll, joy_roll, virtual_roll)

	if invert_pitch:
		raw_pitch = -raw_pitch

	# 4. Apply Deadzone and Cubic Expo Curve: f(x) = x * (1 - e) + e * (x^3)
	var processed_throttle = _apply_expo(_apply_deadzone(raw_throttle, deadzone), 0.0) # Linear throttle
	var processed_yaw = _apply_expo(_apply_deadzone(raw_yaw, deadzone), expo)
	var processed_pitch = _apply_expo(_apply_deadzone(raw_pitch, deadzone), expo)
	var processed_roll = _apply_expo(_apply_deadzone(raw_roll, deadzone), expo)

	# Update ControlFrame
	current_frame.throttle = clampf(processed_throttle, -1.0, 1.0)
	current_frame.yaw = clampf(processed_yaw, -1.0, 1.0)
	current_frame.pitch = clampf(processed_pitch, -1.0, 1.0)
	current_frame.roll = clampf(processed_roll, -1.0, 1.0)

	# Sync legacy public properties
	throttle = current_frame.throttle
	yaw = current_frame.yaw
	pitch = current_frame.pitch
	roll = current_frame.roll

func _ramp_axis(current_val: float, target_val: float, delta: float) -> float:
	if absf(target_val) > 0.01:
		return move_toward(current_val, target_val, KEY_ATTACK_RATE * delta)
	else:
		return move_toward(current_val, 0.0, KEY_RELEASE_RATE * delta)

func _poll_action_triggers() -> void:
	# Takeoff / Land Toggle
	if Input.is_action_just_pressed("flight_takeoff_land") or Input.is_action_just_pressed("ui_accept") or _is_key_just_pressed(KEY_SPACE) or _is_key_just_pressed(KEY_T):
		takeoff_land_pressed.emit()
		takeoff_land_requested.emit()
		takeoff_requested.emit()

	# Land Only Key
	if _is_key_just_pressed(KEY_L):
		land_requested.emit()
		takeoff_land_pressed.emit()
		takeoff_land_requested.emit()

	# Return to Home (RTH)
	if _is_key_just_pressed(KEY_H):
		rth_requested.emit()

	# Reset to Pad
	if Input.is_action_just_pressed("flight_reset") or _is_key_just_pressed(KEY_R):
		reset_pressed.emit()
		reset_requested.emit()

	# Camera Toggle
	if Input.is_action_just_pressed("camera_mode") or _is_key_just_pressed(KEY_C):
		camera_toggle_requested.emit()

	# Flight Mode Cycle
	if Input.is_action_just_pressed("flight_mode_next") or _is_key_just_pressed(KEY_M):
		flight_mode_cycle_requested.emit()

	# Pause / Escape
	if _is_key_just_pressed(KEY_P) or _is_key_just_pressed(KEY_ESCAPE):
		pause_requested.emit()

	# Emergency Cut
	if _is_key_just_pressed(KEY_X):
		emergency_cut_requested.emit()

	# Flip / Stunt Action (Snaps to 4 Cardinal Directions based on Stick at Press Time)
	if Input.is_action_just_pressed("stunt_flip") or _is_key_just_pressed(KEY_F):
		_trigger_directional_flip()

	# Gamepad Button Debouncing
	_poll_gamepad_buttons()

func _poll_gamepad_buttons() -> void:
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A):
		if not get_meta("_joy_a_held", false):
			set_meta("_joy_a_held", true)
			takeoff_land_pressed.emit()
			takeoff_land_requested.emit()
			takeoff_requested.emit()
	else:
		set_meta("_joy_a_held", false)

	if Input.is_joy_button_pressed(0, JOY_BUTTON_B):
		if not get_meta("_joy_b_held", false):
			set_meta("_joy_b_held", true)
			land_requested.emit()
	else:
		set_meta("_joy_b_held", false)

	if Input.is_joy_button_pressed(0, JOY_BUTTON_Y):
		if not get_meta("_joy_y_held", false):
			set_meta("_joy_y_held", true)
			reset_pressed.emit()
			reset_requested.emit()
	else:
		set_meta("_joy_y_held", false)

	if Input.is_joy_button_pressed(0, JOY_BUTTON_X):
		if not get_meta("_joy_x_held", false):
			set_meta("_joy_x_held", true)
			_trigger_directional_flip()
	else:
		set_meta("_joy_x_held", false)

	if Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		if not get_meta("_joy_lb_held", false):
			set_meta("_joy_lb_held", true)
			camera_toggle_requested.emit()
	else:
		set_meta("_joy_lb_held", false)

	if Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		if not get_meta("_joy_rb_held", false):
			set_meta("_joy_rb_held", true)
			_trigger_directional_flip()
	else:
		set_meta("_joy_rb_held", false)

func _trigger_directional_flip() -> void:
	var stick_x = roll
	var stick_y = pitch

	var snap_dir = Vector2(0, -1) # Default: Back flip if stick is centered

	if absf(stick_x) > 0.25 or absf(stick_y) > 0.25:
		if absf(stick_y) >= absf(stick_x):
			snap_dir = Vector2(0, 1) if stick_y > 0.0 else Vector2(0, -1)
		else:
			snap_dir = Vector2(1, 0) if stick_x > 0.0 else Vector2(-1, 0)

	flip_pressed.emit(snap_dir)

	# Emit backward-compatible stunt name
	var stunt_name = "back_flip"
	if snap_dir == Vector2(0, 1):
		stunt_name = "front_flip"
	elif snap_dir == Vector2(1, 0):
		stunt_name = "barrel_roll_right"
	elif snap_dir == Vector2(-1, 0):
		stunt_name = "barrel_roll_left"
	stunt_requested.emit(stunt_name)

func _is_key_just_pressed(keycode: int) -> bool:
	var pressed = Input.is_key_pressed(keycode)
	var was_pressed = _key_states.get(keycode, false)
	_key_states[keycode] = pressed
	return pressed and not was_pressed

func _combine_inputs(key_val: float, joy_val: float, touch_val: float) -> float:
	var ak = absf(key_val)
	var aj = absf(joy_val)
	var at = absf(touch_val)
	if at >= ak and at >= aj:
		return touch_val
	elif aj >= ak:
		return joy_val
	else:
		return key_val

func _apply_deadzone(val: float, dz: float) -> float:
	if absf(val) < dz:
		return 0.0
	var sign_val = signf(val)
	return sign_val * ((absf(val) - dz) / (1.0 - dz))

func _apply_expo(val: float, ex: float) -> float:
	return (1.0 - ex) * val + ex * (val * val * val)

# Virtual Stick Setters
func set_virtual_left_stick(stick_x: float, stick_y: float) -> void:
	last_input_source = InputSource.TOUCH
	virtual_yaw = clampf(stick_x, -1.0, 1.0)
	virtual_throttle = clampf(stick_y, -1.0, 1.0)

func set_virtual_right_stick(stick_x: float, stick_y: float) -> void:
	last_input_source = InputSource.TOUCH
	virtual_roll = clampf(stick_x, -1.0, 1.0)
	virtual_pitch = clampf(stick_y, -1.0, 1.0)

# Public Command Methods
func request_takeoff() -> void:
	takeoff_land_pressed.emit()
	takeoff_requested.emit()
	takeoff_land_requested.emit()

func request_land() -> void:
	takeoff_land_pressed.emit()
	land_requested.emit()
	takeoff_land_requested.emit()

func request_takeoff_land() -> void:
	takeoff_land_pressed.emit()
	takeoff_land_requested.emit()

func request_rth() -> void:
	rth_requested.emit()

func request_reset() -> void:
	reset_pressed.emit()
	reset_requested.emit()

func request_camera_toggle() -> void:
	camera_toggle_requested.emit()

func request_flight_mode_cycle() -> void:
	flight_mode_cycle_requested.emit()

func request_stunt(stunt_type: String) -> void:
	_trigger_directional_flip()

func request_pause() -> void:
	pause_requested.emit()

func request_emergency_cut() -> void:
	emergency_cut_requested.emit()

func is_processing_input_action(_action_meta: String) -> bool:
	return false
