class_name InputRouter
extends Node

## InputRouter: Physics-Synced Unified Input for Drone Flight
## Input polling moved to _physics_process for frame-perfect 60Hz sync.
## Keyboard axes use move_toward() ramping for smooth acceleration/deceleration.

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
var throttle: float = 0.0
var yaw: float     = 0.0
var pitch: float   = 0.0
var roll: float    = 0.0

# Virtual joystick inputs (from on-screen HUD)
var virtual_throttle: float = 0.0
var virtual_yaw:      float = 0.0
var virtual_pitch:    float = 0.0
var virtual_roll:     float = 0.0

# Tuning Parameters
@export var deadzone:     float = 0.08
@export var expo:         float = 0.30
@export var invert_pitch: bool  = false
@export var gamepad_mode: int   = 2

# Keyboard ramp state (smooth acceleration, fast release)
var _k_throttle: float = 0.0
var _k_yaw:      float = 0.0
var _k_pitch:    float = 0.0
var _k_roll:     float = 0.0

const KEY_RAMP_UP:   float = 4.5   # seconds to full deflection
const KEY_RAMP_DOWN: float = 7.0   # seconds to zero on release

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == 0:
		throttle = 0.0; yaw = 0.0; pitch = 0.0; roll = 0.0
		virtual_throttle = 0.0; virtual_yaw = 0.0
		virtual_pitch = 0.0; virtual_roll = 0.0

# Physics-synced flight input (60 Hz)
func _physics_process(delta: float) -> void:
	_poll_flight_inputs(delta)

# UI action triggers (render frame — one-shot)
func _process(_delta: float) -> void:
	_poll_action_triggers()

func _poll_flight_inputs(delta: float) -> void:
	# --- Keyboard raw targets ---
	var kp_raw: float = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	var kr_raw: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var kt_raw: float = float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))
	var ky_raw: float = (float(Input.is_key_pressed(KEY_RIGHT)) + float(Input.is_key_pressed(KEY_E))) \
	                  - (float(Input.is_key_pressed(KEY_LEFT))  + float(Input.is_key_pressed(KEY_Q)))
	ky_raw = clampf(ky_raw, -1.0, 1.0)

	# --- Smooth keyboard ramp ---
	if absf(kp_raw) > 0.01:
		_k_pitch    = move_toward(_k_pitch,    kp_raw, KEY_RAMP_UP   * delta)
	else:
		_k_pitch    = move_toward(_k_pitch,    0.0,    KEY_RAMP_DOWN * delta)
	if absf(kr_raw) > 0.01:
		_k_roll     = move_toward(_k_roll,     kr_raw, KEY_RAMP_UP   * delta)
	else:
		_k_roll     = move_toward(_k_roll,     0.0,    KEY_RAMP_DOWN * delta)
	if absf(kt_raw) > 0.01:
		_k_throttle = move_toward(_k_throttle, kt_raw, KEY_RAMP_UP   * delta)
	else:
		_k_throttle = move_toward(_k_throttle, 0.0,    KEY_RAMP_DOWN * delta)
	if absf(ky_raw) > 0.01:
		_k_yaw      = move_toward(_k_yaw,      ky_raw, KEY_RAMP_UP   * delta)
	else:
		_k_yaw      = move_toward(_k_yaw,      0.0,    KEY_RAMP_DOWN * delta)

	# --- Gamepad (radial deadzone via get_vector) ---
	var joy_left  = Vector2.ZERO
	var joy_right = Vector2.ZERO
	if Input.get_connected_joypads().size() > 0:
		joy_left  = Input.get_vector("yaw_left",  "yaw_right",  "throttle_up", "throttle_down", deadzone)
		joy_right = Input.get_vector("roll_left",  "roll_right", "pitch_forward","pitch_backward", deadzone)

	var joy_throttle: float
	var joy_yaw:      float
	var joy_pitch:    float
	var joy_roll:     float

	if gamepad_mode == 2:
		joy_throttle = -joy_left.y
		joy_yaw      =  joy_left.x
		joy_pitch    = -joy_right.y
		joy_roll     =  joy_right.x
	else:
		joy_pitch    = -joy_left.y
		joy_roll     =  joy_left.x
		joy_yaw      =  joy_right.x
		joy_throttle = -joy_right.y

	# --- Combine (highest magnitude wins) ---
	var raw_throttle = _combine(_k_throttle, joy_throttle, virtual_throttle)
	var raw_yaw      = _combine(_k_yaw,      joy_yaw,      virtual_yaw)
	var raw_pitch    = _combine(_k_pitch,    joy_pitch,    virtual_pitch)
	var raw_roll     = _combine(_k_roll,     joy_roll,     virtual_roll)

	if invert_pitch:
		raw_pitch = -raw_pitch

	throttle = _expo(_dz(raw_throttle), expo)
	yaw      = _expo(_dz(raw_yaw),      expo)
	pitch    = _expo(_dz(raw_pitch),    expo)
	roll     = _expo(_dz(raw_roll),     expo)

# Keyboard debounce state for action triggers
var _key_states: Dictionary = {}

func _is_key_just_pressed(keycode: int) -> bool:
	var pressed = Input.is_key_pressed(keycode)
	var was_pressed = _key_states.get(keycode, false)
	_key_states[keycode] = pressed
	return pressed and not was_pressed

func _poll_action_triggers() -> void:
	if Input.is_action_just_pressed("ui_accept") or _is_key_just_pressed(KEY_SPACE) or _is_key_just_pressed(KEY_T):
		takeoff_land_requested.emit()
		takeoff_requested.emit()
	if _is_key_just_pressed(KEY_L):
		land_requested.emit()
		takeoff_land_requested.emit()
	if _is_key_just_pressed(KEY_H):
		rth_requested.emit()
	if _is_key_just_pressed(KEY_R):
		reset_requested.emit()
	if _is_key_just_pressed(KEY_P) or _is_key_just_pressed(KEY_ESCAPE):
		pause_requested.emit()
	if _is_key_just_pressed(KEY_C):
		camera_toggle_requested.emit()
	if _is_key_just_pressed(KEY_M):
		flight_mode_cycle_requested.emit()
	if _is_key_just_pressed(KEY_F):
		stunt_requested.emit("front_flip")
	if _is_key_just_pressed(KEY_X):
		emergency_cut_requested.emit()
	if _is_key_just_pressed(KEY_O):
		photo_requested.emit()
	# Gamepad buttons
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A):
		if not get_meta("_joy_a_held", false):
			set_meta("_joy_a_held", true)
			takeoff_land_requested.emit(); takeoff_requested.emit()
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
			reset_requested.emit()
	else:
		set_meta("_joy_y_held", false)
	if Input.is_joy_button_pressed(0, JOY_BUTTON_X):
		if not get_meta("_joy_x_held", false):
			set_meta("_joy_x_held", true)
			flight_mode_cycle_requested.emit()
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
			stunt_requested.emit("front_flip")
	else:
		set_meta("_joy_rb_held", false)

func is_processing_input_action(_action_meta: String) -> bool:
	return false  # Legacy stub — no longer used

func _combine(key_val: float, joy_val: float, touch_val: float) -> float:
	var ak = absf(key_val); var aj = absf(joy_val); var at = absf(touch_val)
	if at >= ak and at >= aj: return touch_val
	elif aj >= ak:            return joy_val
	else:                     return key_val

func _dz(val: float) -> float:
	if absf(val) < deadzone: return 0.0
	return signf(val) * ((absf(val) - deadzone) / (1.0 - deadzone))

func _expo(val: float, ex: float) -> float:
	return (1.0 - ex) * val + ex * (val * val * val)

# Virtual Stick Setters (called from FlightHUD)
func set_virtual_left_stick(stick_x: float, stick_y: float) -> void:
	virtual_yaw      = clampf(stick_x, -1.0, 1.0)
	virtual_throttle = clampf(stick_y, -1.0, 1.0)

func set_virtual_right_stick(stick_x: float, stick_y: float) -> void:
	virtual_roll  = clampf(stick_x, -1.0, 1.0)
	virtual_pitch = clampf(stick_y, -1.0, 1.0)

# Public Command Methods
func request_takeoff()           -> void: takeoff_requested.emit();      takeoff_land_requested.emit()
func request_land()              -> void: land_requested.emit();         takeoff_land_requested.emit()
func request_takeoff_land()      -> void: takeoff_land_requested.emit()
func request_rth()               -> void: rth_requested.emit()
func request_reset()             -> void: reset_requested.emit()
func request_camera_toggle()     -> void: camera_toggle_requested.emit()
func request_flight_mode_cycle() -> void: flight_mode_cycle_requested.emit()
func request_stunt(stunt_type: String) -> void: stunt_requested.emit(stunt_type)
func request_pause()             -> void: pause_requested.emit()
func request_emergency_cut()     -> void: emergency_cut_requested.emit()
