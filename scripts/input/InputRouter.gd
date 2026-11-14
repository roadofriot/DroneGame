class_name InputRouter
extends Node

## InputRouter: Master Unified Input Abstraction for Drone Flight
## Seamlessly binds Touchscreen Twin-Sticks, Desktop Keyboard (WASD + Arrows),
## and standard Gamepad Analog Sticks without axis inversion or input collisions.

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

# Normalized flight control outputs [-1.0 .. +1.0]
var throttle: float = 0.0 # +1 = Climb, -1 = Descend
var yaw: float = 0.0      # +1 = Clockwise / Turn Right, -1 = Counterclockwise / Turn Left
var pitch: float = 0.0    # +1 = Pitch Forward, -1 = Pitch Backward
var roll: float = 0.0     # +1 = Roll Right, -1 = Roll Left

# Virtual joystick inputs (from on-screen HUD)
var virtual_throttle: float = 0.0
var virtual_yaw: float = 0.0
var virtual_pitch: float = 0.0
var virtual_roll: float = 0.0

# Tuning Parameters
@export var deadzone: float = 0.08
@export var expo: float = 0.30
@export var invert_pitch: bool = false
@export var gamepad_mode: int = 2 # 2 = Mode 2 (Standard RC: L=Throttle/Yaw, R=Pitch/Roll), 1 = Mode 1

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == 0:
		# Neutralize all analog inputs immediately upon disconnection
		throttle = 0.0
		yaw = 0.0
		pitch = 0.0
		roll = 0.0
		virtual_throttle = 0.0
		virtual_yaw = 0.0
		virtual_pitch = 0.0
		virtual_roll = 0.0

func _process(_delta: float) -> void:
	_poll_flight_inputs()
	_poll_action_triggers()

func _poll_flight_inputs() -> void:
	# 1. Desktop Keyboard Controls (Section 4.4 & Section 15 Specifications)
	# W / S : Pitch Forward / Backward
	var key_pitch: float = 0.0
	if Input.is_key_pressed(KEY_W):
		key_pitch += 1.0
	if Input.is_key_pressed(KEY_S):
		key_pitch -= 1.0

	# A / D : Roll Left / Right
	var key_roll: float = 0.0
	if Input.is_key_pressed(KEY_D):
		key_roll += 1.0
	if Input.is_key_pressed(KEY_A):
		key_roll -= 1.0

	# Arrow Up / Down : Throttle Increase / Decrease
	var key_throttle: float = 0.0
	if Input.is_key_pressed(KEY_UP):
		key_throttle += 1.0
	if Input.is_key_pressed(KEY_DOWN):
		key_throttle -= 1.0

	# Arrow Left / Right or Q / E : Yaw Left / Right
	var key_yaw: float = 0.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_E):
		key_yaw += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q):
		key_yaw -= 1.0

	# 2. Gamepad Analog Stick Inputs
	var joy_throttle: float = 0.0
	var joy_yaw: float = 0.0
	var joy_pitch: float = 0.0
	var joy_roll: float = 0.0

	if gamepad_mode == 2:
		# Standard RC Drone Mode 2 (Left = Throttle/Yaw, Right = Pitch/Roll)
		joy_throttle = -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y) # Push up -> +1
		joy_yaw = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		joy_pitch = -Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)    # Push up -> +1
		joy_roll = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	else:
		# Section 4.6 Mode 1 (Left = Pitch/Roll, Right = Throttle/Yaw)
		joy_pitch = -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		joy_roll = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		joy_yaw = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		joy_throttle = -Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)

	# Combine Keyboard + Gamepad + Virtual Touch Sticks (Whichever source has highest active magnitude)
	var raw_throttle = _combine_inputs(key_throttle, joy_throttle, virtual_throttle)
	var raw_yaw = _combine_inputs(key_yaw, joy_yaw, virtual_yaw)
	var raw_pitch = _combine_inputs(key_pitch, joy_pitch, virtual_pitch)
	var raw_roll = _combine_inputs(key_roll, joy_roll, virtual_roll)

	if invert_pitch:
		raw_pitch = -raw_pitch

	# Apply deadzone and cubic expo curve for smooth, professional control feel
	throttle = _apply_expo(_apply_deadzone(raw_throttle, deadzone), expo)
	yaw = _apply_expo(_apply_deadzone(raw_yaw, deadzone), expo)
	pitch = _apply_expo(_apply_deadzone(raw_pitch, deadzone), expo)
	roll = _apply_expo(_apply_deadzone(raw_roll, deadzone), expo)

func _poll_action_triggers() -> void:
	# Key 'T' -> Take Off
	if Input.is_key_pressed(KEY_T):
		if not is_processing_input_action("key_t"):
			set_meta("key_t", true)
			takeoff_requested.emit()
			takeoff_land_requested.emit()
	else:
		set_meta("key_t", false)

	# Key 'L' -> Land
	if Input.is_key_pressed(KEY_L):
		if not is_processing_input_action("key_l"):
			set_meta("key_l", true)
			land_requested.emit()
			takeoff_land_requested.emit()
	else:
		set_meta("key_l", false)

	# Key 'H' or 'R' -> Return to Home (RTH) / Reset
	if Input.is_key_pressed(KEY_H):
		if not is_processing_input_action("key_h"):
			set_meta("key_h", true)
			rth_requested.emit()
	else:
		set_meta("key_h", false)

	if Input.is_key_pressed(KEY_R):
		if not is_processing_input_action("key_r"):
			set_meta("key_r", true)
			reset_requested.emit()
	else:
		set_meta("key_r", false)

	# Key 'P' or 'Escape' -> Pause / Resume
	if Input.is_key_pressed(KEY_P) or Input.is_key_pressed(KEY_ESCAPE):
		if not is_processing_input_action("key_pause"):
			set_meta("key_pause", true)
			pause_requested.emit()
	else:
		set_meta("key_pause", false)

	# Key 'C' -> Change Camera
	if Input.is_key_pressed(KEY_C):
		if not is_processing_input_action("key_c"):
			set_meta("key_c", true)
			camera_toggle_requested.emit()
	else:
		set_meta("key_c", false)

	# Key 'M' -> Flight Mode Cycle
	if Input.is_key_pressed(KEY_M):
		if not is_processing_input_action("key_m"):
			set_meta("key_m", true)
			flight_mode_cycle_requested.emit()
	else:
		set_meta("key_m", false)

	# Key 'F' -> Flip / Stunt
	if Input.is_key_pressed(KEY_F):
		if not is_processing_input_action("key_f"):
			set_meta("key_f", true)
			stunt_requested.emit("front_flip")
	else:
		set_meta("key_f", false)

	# Key 'Space' -> Takeoff if disarmed, Emergency Stop if flying
	if Input.is_key_pressed(KEY_SPACE):
		if not is_processing_input_action("key_space"):
			set_meta("key_space", true)
			takeoff_land_requested.emit()
			takeoff_requested.emit()
	else:
		set_meta("key_space", false)

	# Key 'X' -> Emergency Motor Cut
	if Input.is_key_pressed(KEY_X):
		if not is_processing_input_action("key_x"):
			set_meta("key_x", true)
			emergency_cut_requested.emit()
	else:
		set_meta("key_x", false)

	# Gamepad standard action buttons
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A):
		if not is_processing_input_action("joy_a"):
			set_meta("joy_a", true)
			takeoff_land_requested.emit()
			takeoff_requested.emit()
	else:
		set_meta("joy_a", false)

	if Input.is_joy_button_pressed(0, JOY_BUTTON_B):
		if not is_processing_input_action("joy_b"):
			set_meta("joy_b", true)
			land_requested.emit()
	else:
		set_meta("joy_b", false)

	if Input.is_joy_button_pressed(0, JOY_BUTTON_Y):
		if not is_processing_input_action("joy_y"):
			set_meta("joy_y", true)
			reset_requested.emit()
	else:
		set_meta("joy_y", false)

	if Input.is_joy_button_pressed(0, JOY_BUTTON_X):
		if not is_processing_input_action("joy_x"):
			set_meta("joy_x", true)
			flight_mode_cycle_requested.emit()
	else:
		set_meta("joy_x", false)

	if Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		if not is_processing_input_action("joy_lb"):
			set_meta("joy_lb", true)
			camera_toggle_requested.emit()
	else:
		set_meta("joy_lb", false)

	if Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		if not is_processing_input_action("joy_rb"):
			set_meta("joy_rb", true)
			stunt_requested.emit("front_flip")
	else:
		set_meta("joy_rb", false)

func is_processing_input_action(action_meta: String) -> bool:
	return has_meta(action_meta) and get_meta(action_meta) == true

func _combine_inputs(key_val: float, joy_val: float, touch_val: float) -> float:
	var abs_k = absf(key_val)
	var abs_j = absf(joy_val)
	var abs_t = absf(touch_val)
	if abs_t >= abs_k and abs_t >= abs_j:
		return touch_val
	elif abs_j >= abs_k:
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
	virtual_yaw = clampf(stick_x, -1.0, 1.0)
	virtual_throttle = clampf(stick_y, -1.0, 1.0)

func set_virtual_right_stick(stick_x: float, stick_y: float) -> void:
	virtual_roll = clampf(stick_x, -1.0, 1.0)
	virtual_pitch = clampf(stick_y, -1.0, 1.0)

# Direct Public Command Methods
func request_takeoff() -> void:
	takeoff_requested.emit()
	takeoff_land_requested.emit()

func request_land() -> void:
	land_requested.emit()
	takeoff_land_requested.emit()

func request_takeoff_land() -> void:
	takeoff_land_requested.emit()

func request_rth() -> void:
	rth_requested.emit()

func request_reset() -> void:
	reset_requested.emit()

func request_camera_toggle() -> void:
	camera_toggle_requested.emit()

func request_flight_mode_cycle() -> void:
	flight_mode_cycle_requested.emit()

func request_stunt(stunt_type: String) -> void:
	stunt_requested.emit(stunt_type)

func request_pause() -> void:
	pause_requested.emit()

func request_emergency_cut() -> void:
	emergency_cut_requested.emit()
