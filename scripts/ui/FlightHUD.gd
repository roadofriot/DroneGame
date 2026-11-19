class_name FlightHUD
extends CanvasLayer

const ArtificialHorizon = preload("res://scripts/ui/ArtificialHorizon.gd")
const HeadingStrip = preload("res://scripts/ui/HeadingStrip.gd")
const HomeArrow = preload("res://scripts/ui/HomeArrow.gd")
const FlightModeManager = preload("res://scripts/flight/FlightModeManager.gd")
const FlipController = preload("res://scripts/flight/FlipController.gd")

## FlightHUD: Professional Drone Telemetry HUD & Remote Controller Interface (Phase 8).
## Features:
## - Vector Artificial Horizon (pitch ladder & roll line)
## - Vector Heading Strip (0..360° with cardinal marks)
## - Dynamic Home Arrow + Distance
## - Dual Speed (m/s & km/h / mph)
## - Dual Altitude (AGL & MSL) and Vertical Speed (V/S)
## - Battery bar / % / estimated flight time remaining
## - Flight mode badge (ANGLE, HORIZON, ACRO) and State badge
## - Warning banners (LOW BATTERY, RTH ACTIVE, TOO LOW FOR FLIP, BRAKE ACTIVE)
## - Gated Contextual Touch Controls (Takeoff/Land, Flip, Mode, RTH, Brake)

signal world_select_requested

@export var input_router: InputRouter
@export var flight_physics: FlightPhysics
@export var camera_director: FlightCameraDirector
@export var audio_director: AudioDirector

# Settings
var settings_service: SettingsService

# Procedural Vector HUD Elements
@onready var artificial_horizon: ArtificialHorizon = get_node_or_null(
	"CenterCluster/ArtificialHorizon"
)
@onready var heading_strip: HeadingStrip = get_node_or_null("HeadingStrip")
@onready var home_arrow: HomeArrow = get_node_or_null("RightTelemetryCluster/HomeArrow")

# Virtual Joysticks
@onready var left_joystick: VirtualJoystick = get_node_or_null("LeftCluster/LeftJoystick")
@onready var right_joystick: VirtualJoystick = get_node_or_null("RightCluster/RightJoystick")

# Top Bar Elements
@onready var btn_location: Button = get_node_or_null("TopBar/HBox/BtnLocation")
@onready var label_gps: Label = get_node_or_null("TopBar/HBox/GPSPill/LabelGPS")
@onready var label_battery: Label = get_node_or_null("TopBar/HBox/BatteryPill/LabelBattery")
@onready var battery_progress_bar: ProgressBar = get_node_or_null(
	"TopBar/HBox/BatteryPill/BatteryProgressBar"
)
@onready var label_signal: Label = get_node_or_null("TopBar/HBox/SignalPill/LabelSignal")
@onready var label_satellites: Label = get_node_or_null("TopBar/HBox/SatPill/LabelSatellites")
@onready var label_camera_status: Label = get_node_or_null(
	"TopBar/HBox/CamStatusPill/LabelCameraStatus"
)
@onready var label_mode_badge: Label = get_node_or_null("TopBar/HBox/ModeBadgePill/LabelModeBadge")
@onready var label_state_badge: Label = get_node_or_null(
	"TopBar/HBox/StateBadgePill/LabelStateBadge"
)
@onready var btn_menu: Button = get_node_or_null("TopBar/HBox/BtnMenu")

# Left Zoom / Gimbal Controls
@onready var btn_zoom_in: Button = get_node_or_null("LeftZoomColumn/BtnZoomIn")
@onready var btn_zoom_reset: Button = get_node_or_null("LeftZoomColumn/BtnZoomReset")
@onready var btn_zoom_out: Button = get_node_or_null("LeftZoomColumn/BtnZoomOut")

# Center Controls
@onready var btn_mode_cine: Button = get_node_or_null(
	"CenterControls/ModeContainer/ModeHBox/BtnModeCine"
)
@onready var btn_mode_normal: Button = get_node_or_null(
	"CenterControls/ModeContainer/ModeHBox/BtnModeNormal"
)
@onready var btn_mode_sport: Button = get_node_or_null(
	"CenterControls/ModeContainer/ModeHBox/BtnModeSport"
)
@onready var btn_mode_cycle: Button = get_node_or_null(
	"CenterControls/ModeContainer/ModeHBox/BtnModeCycle"
)
@onready var btn_failsafe: Button = get_node_or_null("CenterControls/ActionHBox/BtnFailsafe")
@onready var btn_takeoff: Button = get_node_or_null("CenterControls/ActionHBox/BtnTakeoff")
@onready var btn_rth: Button = get_node_or_null("CenterControls/ActionHBox/BtnRTH")
@onready var btn_brake: Button = get_node_or_null("CenterControls/ActionHBox/BtnBrake")
@onready var btn_cam_toggle: Button = get_node_or_null("CenterControls/ActionHBox/BtnCamToggle")
@onready var btn_flip: Button = get_node_or_null("CenterControls/ActionHBox/BtnFlip")

# Right Telemetry & Sensor Cluster
@onready var label_h: Label = get_node_or_null("RightTelemetryCluster/TelemetryBox/VBox/LabelH")
@onready var label_hs: Label = get_node_or_null("RightTelemetryCluster/TelemetryBox/VBox/LabelHS")
@onready var label_d: Label = get_node_or_null("RightTelemetryCluster/TelemetryBox/VBox/LabelD")
@onready var label_vs: Label = get_node_or_null("RightTelemetryCluster/TelemetryBox/VBox/LabelVS")
@onready var sensor_icon: Label = get_node_or_null(
	"RightTelemetryCluster/SensorBox/HBox/SensorIcon"
)
@onready var sensor_label: Label = get_node_or_null(
	"RightTelemetryCluster/SensorBox/HBox/SensorLabel"
)

# Center Overlay
@onready var label_state_banner: Label = get_node_or_null("CenterOverlay/StateBanner")
@onready var proximity_warning: Label = get_node_or_null("CenterOverlay/ProximityWarning")

# Settings Modal
@onready var settings_modal: PanelContainer = get_node_or_null("SettingsModal")
@onready var btn_drone_sound: Button = get_node_or_null("SettingsModal/VBox/BtnDroneSound")
@onready var btn_engine: Button = get_node_or_null("SettingsModal/VBox/BtnEngine")
@onready var btn_sound: Button = get_node_or_null("SettingsModal/VBox/BtnSound")
@onready var btn_reset: Button = get_node_or_null("SettingsModal/VBox/BtnReset")
@onready var btn_worlds: Button = get_node_or_null("SettingsModal/VBox/BtnWorlds")
@onready var btn_close_settings: Button = get_node_or_null("SettingsModal/VBox/BtnCloseSettings")

# Backward Compatibility Aliases for Unit Tests
@onready var btn_land: Button = btn_takeoff
@onready var btn_mode: Button = btn_mode_normal
@onready var btn_camera: Button = btn_cam_toggle
@onready var btn_stunt: Button = btn_flip

var banner_hide_timer: float = 0.0
var active_flight_mode: String = "normal"
var _last_low_battery_alert: float = 100.0
var current_altitude_agl: float = 0.0
var current_drone_state: String = "DISARMED"

func _ready() -> void:
	if not settings_service:
		settings_service = SettingsService.new()

	if not audio_director:
		audio_director = get_node_or_null("../AudioDirector")
	if not flight_physics:
		flight_physics = get_node_or_null("../Quadcopter")
	if not input_router:
		input_router = get_node_or_null("../InputRouter")
	if not camera_director:
		camera_director = get_node_or_null("../CameraDirector")

	# Virtual Joysticks Setup
	if left_joystick:
		left_joystick.stick_name = "THROTTLE / YAW"
		left_joystick.stick_type = "LEFT"
		left_joystick.stick_moved.connect(_on_left_stick_moved)
		left_joystick.stick_released.connect(_on_left_stick_released)

	if right_joystick:
		right_joystick.stick_name = "PITCH / ROLL"
		right_joystick.stick_type = "RIGHT"
		right_joystick.stick_moved.connect(_on_right_stick_moved)
		right_joystick.stick_released.connect(_on_right_stick_released)

	# Left Zoom / Gimbal Buttons
	if btn_zoom_in:
		btn_zoom_in.pressed.connect(_on_btn_zoom_in_pressed)
	if btn_zoom_reset:
		btn_zoom_reset.pressed.connect(_on_btn_zoom_reset_pressed)
	if btn_zoom_out:
		btn_zoom_out.pressed.connect(_on_btn_zoom_out_pressed)

	# Center Action Buttons
	if btn_takeoff:
		btn_takeoff.pressed.connect(_on_btn_takeoff_pressed)
	if btn_rth:
		btn_rth.pressed.connect(_on_btn_rth_pressed)
	if btn_brake:
		btn_brake.pressed.connect(_on_btn_brake_pressed)
	if btn_failsafe:
		btn_failsafe.pressed.connect(_on_btn_failsafe_pressed)
	if btn_cam_toggle:
		btn_cam_toggle.pressed.connect(_on_btn_cam_toggle_pressed)
	if btn_flip:
		btn_flip.pressed.connect(_on_btn_flip_pressed)

	# Mode Selectors
	if btn_mode_cine:
		btn_mode_cine.pressed.connect(func(): _set_flight_mode_profile("cine"))
	if btn_mode_normal:
		btn_mode_normal.pressed.connect(func(): _set_flight_mode_profile("normal"))
	if btn_mode_sport:
		btn_mode_sport.pressed.connect(func(): _set_flight_mode_profile("sport"))
	if btn_mode_cycle:
		btn_mode_cycle.pressed.connect(_on_btn_mode_cycle_pressed)

	# Top Bar Buttons
	if btn_location:
		btn_location.pressed.connect(func(): world_select_requested.emit())
	if btn_menu:
		btn_menu.pressed.connect(_toggle_settings_modal)

	# Settings Modal Handlers
	if btn_drone_sound:
		btn_drone_sound.pressed.connect(_on_btn_drone_sound_pressed)
		_update_drone_sound_button_label()
	if btn_engine:
		btn_engine.pressed.connect(_on_btn_engine_pressed)
		_update_engine_button_label()
	if btn_sound:
		btn_sound.pressed.connect(_on_btn_sound_pressed)
		_update_sound_button_label()
	if btn_reset:
		btn_reset.pressed.connect(_on_btn_reset_pressed)
	if btn_worlds:
		btn_worlds.pressed.connect(func(): world_select_requested.emit())
	if btn_close_settings:
		btn_close_settings.pressed.connect(func(): if settings_modal: settings_modal.visible = false)

	# Connect Flight Physics Signals
	if flight_physics:
		flight_physics.telemetry_updated.connect(_on_telemetry_updated)
		flight_physics.drone_state_changed.connect(_on_drone_state_changed)
		flight_physics.drone_crashed.connect(_on_drone_crashed)
		flight_physics.preflight_failed.connect(_on_preflight_failed)
		flight_physics.rth_state_changed.connect(_on_rth_state_changed)
		flight_physics.flight_boundary_reached.connect(_on_flight_boundary_reached)

	# Connect Camera Director Signals
	if camera_director:
		camera_director.camera_mode_changed.connect(_on_camera_mode_changed)

	_update_mode_buttons_ui("normal")
	_show_banner("SYSTEMS INITIALIZED — READY FOR TAKEOFF", 3.0)

func _process(delta: float) -> void:
	if banner_hide_timer > 0.0:
		banner_hide_timer -= delta
		if banner_hide_timer <= 0.0 and label_state_banner:
			if flight_physics and flight_physics.current_state in [
				FlightPhysics.DroneState.FLYING,
				FlightPhysics.DroneState.DISARMED
			]:
				label_state_banner.visible = false

# -----------------------------------------------------------------------------
# Virtual Joysticks
# -----------------------------------------------------------------------------
func _on_left_stick_moved(vec: Vector2) -> void:
	if input_router:
		input_router.set_virtual_left_stick(vec.x, vec.y)

	if flight_physics and flight_physics.current_state == FlightPhysics.DroneState.DISARMED:
		if vec.y > 0.35:
			flight_physics.takeoff()

func _on_left_stick_released() -> void:
	if input_router:
		input_router.set_virtual_left_stick(0.0, 0.0)

func _on_right_stick_moved(vec: Vector2) -> void:
	if input_router:
		input_router.set_virtual_right_stick(vec.x, vec.y)

func _on_right_stick_released() -> void:
	if input_router:
		input_router.set_virtual_right_stick(0.0, 0.0)

# -----------------------------------------------------------------------------
# Zoom & Gimbal Handlers
# -----------------------------------------------------------------------------
func _on_btn_zoom_in_pressed() -> void:
	if camera_director:
		camera_director.zoom_in()
		_show_banner("गिम्बल / क्यामेरा जुम + (Zoom In)", 1.2)

func _on_btn_zoom_reset_pressed() -> void:
	if camera_director:
		camera_director.recenter()
		_show_banner("क्यामेरा रिसेट (Camera Recentered)", 1.2)

func _on_btn_zoom_out_pressed() -> void:
	if camera_director:
		camera_director.zoom_out()
		_show_banner("गिम्बल / क्यामेरा जुम − (Zoom Out)", 1.2)

# -----------------------------------------------------------------------------
# Flight Mode Handling
# -----------------------------------------------------------------------------
func _set_flight_mode_profile(mode_name: String) -> void:
	active_flight_mode = mode_name.to_lower()
	if flight_physics:
		flight_physics.set_flight_profile(active_flight_mode)
	_update_mode_buttons_ui(active_flight_mode)
	_show_banner("FLIGHT TUNING: %s" % active_flight_mode.to_upper(), 2.0)

func _on_btn_mode_cycle_pressed() -> void:
	if flight_physics and flight_physics.flight_mode_manager:
		var cur_m = flight_physics.flight_mode_manager.current_mode
		var next_m = (int(cur_m) + 1) % 3
		flight_physics.flight_mode_manager.set_mode(next_m as FlightModeManager.Mode)
		var m_name = flight_physics.flight_mode_manager.get_mode_name()
		if label_mode_badge:
			label_mode_badge.text = "MODE: %s" % m_name
		if btn_mode_cycle:
			btn_mode_cycle.text = "MODE: %s" % m_name
		_show_banner("FLIGHT MODE: %s" % m_name, 2.0)

func _update_mode_buttons_ui(mode_name: String) -> void:
	if btn_mode_cine:
		btn_mode_cine.text = "★ Cine" if mode_name == "cine" else "Cine"
	if btn_mode_normal:
		btn_mode_normal.text = "★ Normal" if mode_name == "normal" else "Normal"
	if btn_mode_sport:
		btn_mode_sport.text = "★ Sport" if mode_name == "sport" else "Sport"

# -----------------------------------------------------------------------------
# Action Buttons & Gating
# -----------------------------------------------------------------------------
func _on_btn_takeoff_pressed() -> void:
	if flight_physics:
		if flight_physics.current_state == FlightPhysics.DroneState.DISARMED:
			flight_physics.takeoff()
		elif flight_physics.current_state == FlightPhysics.DroneState.CRASHED:
			flight_physics.reset_to_pad()
			_show_banner("DRONE RECOVERED TO LAUNCH PAD", 2.5)
		else:
			flight_physics.land()
	elif input_router:
		input_router.takeoff_requested.emit()

func _on_btn_rth_pressed() -> void:
	if flight_physics:
		if flight_physics.current_state == FlightPhysics.DroneState.RTH:
			flight_physics.cancel_rth()
			_show_banner("RTH CANCELLED — MANUAL RESTORED", 2.5)
			if btn_rth:
				btn_rth.text = "🏠 RTH"
		else:
			if flight_physics.trigger_rth():
				_show_banner("🏠 RTH ACTIVE — RETURNING TO PAD", 3.0)
				if btn_rth:
					btn_rth.text = "❌ Cancel RTH"
			else:
				_show_banner("RTH NOT AVAILABLE ON GROUND", 2.0)
	elif input_router:
		input_router.rth_requested.emit()

func _on_btn_brake_pressed() -> void:
	if flight_physics and flight_physics.brake_controller:
		var is_braking = not flight_physics.brake_controller.force_brake_active
		flight_physics.brake_controller.set_force_brake(is_braking)
		if is_braking:
			_show_banner("🛑 BRAKE ACTIVE", 2.0)
			if btn_brake:
				btn_brake.text = "🛑 Braking..."
		else:
			_show_banner("BRAKE RELEASED", 1.5)
			if btn_brake:
				btn_brake.text = "🛑 Brake"

func _on_btn_failsafe_pressed() -> void:
	if flight_physics:
		if flight_physics.current_state in [
			FlightPhysics.DroneState.FLYING,
			FlightPhysics.DroneState.HOVER,
			FlightPhysics.DroneState.TAKEOFF
		]:
			if flight_physics.altitude_agl > 2.0:
				flight_physics.trigger_rth()
				_show_banner("🛡️ FAILSAFE ACTIVATED — RETURNING HOME", 3.5)
			else:
				flight_physics.emergency_motor_cut()
				_show_banner("🛡️ EMERGENCY MOTOR CUT ACTIVATED", 3.0)
		else:
			_show_banner("FAILSAFE STANDBY — DRONE GROUNDED", 2.0)

func _on_btn_cam_toggle_pressed() -> void:
	if camera_director:
		camera_director.cycle_camera_mode()
	elif input_router:
		input_router.request_camera_toggle()

func _on_camera_mode_changed(mode_name: String) -> void:
	if btn_cam_toggle:
		btn_cam_toggle.text = "📷 %s" % mode_name.substr(0, 3).to_upper()
	_show_banner("CAMERA: %s" % mode_name.to_upper(), 1.5)

func _on_btn_flip_pressed() -> void:
	var state = current_drone_state
	var alt = current_altitude_agl
	if flight_physics:
		alt = flight_physics.altitude_agl
		state = FlightPhysics.DroneState.keys()[flight_physics.current_state]

	if state != "FLYING" and state != "HOVER":
		_show_banner("⚠️ CANNOT FLIP ON GROUND — TAKE OFF FIRST", 2.0)
		return
	if alt < 3.0:
		_show_banner("⚠️ TOO LOW FOR FLIP (Min 3.0m required)", 2.5)
		return

	if flight_physics:
		var flip_dir = Vector2(0.0, 1.0) # Default front flip
		if right_joystick and right_joystick.stick_vector.length() > 0.35:
			var sv = right_joystick.stick_vector
			if absf(sv.y) >= absf(sv.x):
				flip_dir = Vector2(0.0, 1.0) if sv.y > 0.0 else Vector2(0.0, -1.0)
			else:
				flip_dir = Vector2(1.0, 0.0) if sv.x > 0.0 else Vector2(-1.0, 0.0)

		var ok = flight_physics.perform_flip(flip_dir)
		if ok:
			_show_banner("🤸 360° FLIP EXECUTING", 2.0)
		else:
			_show_banner("⚠️ FLIP REFUSED (Safety Check)", 2.0)

# -----------------------------------------------------------------------------
# Settings Drawer
# -----------------------------------------------------------------------------
func _toggle_settings_modal() -> void:
	if settings_modal:
		settings_modal.visible = not settings_modal.visible

func _on_btn_drone_sound_pressed() -> void:
	if audio_director and audio_director.has_method("toggle_drone_sound"):
		audio_director.toggle_drone_sound()
		_update_drone_sound_button_label()

func _update_drone_sound_button_label() -> void:
	if btn_drone_sound:
		var muted = audio_director.is_drone_sound_muted if audio_director else false
		btn_drone_sound.text = "🚁 Drone Sound: OFF" if muted else "🚁 Drone Sound: ON"

func _on_btn_engine_pressed() -> void:
	if audio_director and audio_director.has_method("cycle_motor_sound_profile"):
		var p_name = audio_director.cycle_motor_sound_profile()
		_update_engine_button_label(p_name)
		_show_banner("ENGINE SOUND: %s" % p_name.to_upper(), 2.0)

func _update_engine_button_label(p_name: String = "") -> void:
	if btn_engine:
		if p_name == "" and audio_director and "current_sound_profile" in audio_director:
			p_name = AudioDirector.MotorSoundProfile.keys()[audio_director.current_sound_profile]
		btn_engine.text = "⚙️ Engine: %s" % (p_name.to_upper() if p_name != "" else "TURBO")

func _on_btn_sound_pressed() -> void:
	if audio_director:
		audio_director.toggle_all_sound()
		_update_sound_button_label()

func _update_sound_button_label() -> void:
	if btn_sound:
		var muted = audio_director.is_audio_muted if audio_director else false
		btn_sound.text = "🔇 Master Audio: MUTE" if muted else "🔊 Master Audio: ON"

func _on_btn_reset_pressed() -> void:
	if flight_physics:
		flight_physics.reset_to_pad()
		_show_banner("RESET TO LAUNCH PAD", 2.5)
	if settings_modal:
		settings_modal.visible = false

# -----------------------------------------------------------------------------
# Diagnostics & Telemetry Sync
# -----------------------------------------------------------------------------
func _show_banner(msg: String, duration: float = 3.0) -> void:
	if label_state_banner:
		label_state_banner.text = msg
		label_state_banner.visible = true
		banner_hide_timer = duration

func show_landmark_discovered_banner(lm: Dictionary) -> void:
	var name_str = lm.get("name", "Landmark")
	var loc_str = lm.get("location", "Nepal")
	var xp = lm.get("xp_reward", 150)
	var coins = lm.get("coin_reward", 200)
	var banner_text = "✨ LANDMARK DISCOVERED!\n%s (%s)\n+%d XP | +%d COINS" % [
		name_str.to_upper(), loc_str, xp, coins
	]
	_show_banner(banner_text, 4.5)

func show_destination_reached_banner(st: Dictionary, results: Dictionary) -> void:
	var st_name = st.get("name", "Destination")
	var next_name = results.get("unlocked_next", "Next Region")
	var km = results.get("travel_distance_km", 0.0)
	var banner_text = "🏁 STAGE COMPLETE: %s!\nNEXT UNLOCKED: %s (%.1f KM)" % [
		st_name.to_upper(), next_name.to_upper(), km
	]
	_show_banner(banner_text, 6.0)

func _on_preflight_failed(reason: String) -> void:
	_show_banner("PREFLIGHT FAILED: %s" % reason.to_upper(), 4.0)

func _on_flight_boundary_reached(boundary_type: String) -> void:
	if boundary_type == "MAX_ALTITUDE":
		_show_banner("⚠️ MAX ALTITUDE CEILING REACHED (60m)", 2.5)
	else:
		_show_banner("⚠️ GEOFENCE BOUNDARY REACHED", 2.5)

func _on_rth_state_changed(is_active: bool, distance: float) -> void:
	if btn_rth:
		btn_rth.text = "❌ Cancel RTH" if is_active else "🏠 RTH"
	if is_active:
		_show_banner("🏠 RTH ACTIVE — DISTANCE: %.1f m" % distance, 3.5)

func _on_drone_crashed(impact: float) -> void:
	_show_banner("CRASHED (IMPACT %.1f m/s) — PRESS RECOVER" % impact, 5.0)

func _on_drone_state_changed(state_name: String) -> void:
	current_drone_state = state_name
	if label_state_badge:
		label_state_badge.text = "STATE: %s" % state_name.to_upper()

	match state_name:
		"PREFLIGHT_CHECK":
			_show_banner("PREFLIGHT CHECK PASSED", 2.0)
		"MOTOR_STARTING":
			_show_banner("MOTORS SPOOLING UP...", 2.0)
		"TAKEOFF":
			_show_banner("TAKEOFF (TARGET 3.0m)...", 3.0)
		"HOVER":
			_show_banner("HOVER STABILIZED — JOYSTICKS ACTIVE", 2.5)
		"LANDING":
			_show_banner("AUTOLAND ACTIVE...", 3.0)
		"RTH":
			_show_banner("🏠 RTH ACTIVE — RETURNING HOME", 3.5)
		"DISARMED":
			_show_banner("MOTORS STOPPED — READY FOR TAKEOFF", 2.5)

	# Update Takeoff button text & contextual flip gating
	if btn_takeoff:
		if state_name == "DISARMED":
			btn_takeoff.text = "🛫 Take Off"
		elif state_name == "CRASHED":
			btn_takeoff.text = "🔄 Recover"
		else:
			btn_takeoff.text = "🛬 Land"

	if btn_flip:
		var can_flip = (state_name in ["FLYING", "HOVER"])
		btn_flip.disabled = not can_flip
		btn_flip.modulate = Color(1, 1, 1, 1.0) if can_flip else Color(1, 1, 1, 0.4)

func _on_telemetry_updated(data: Dictionary) -> void:
	current_altitude_agl = data.get("altitude_agl", current_altitude_agl)
	current_drone_state = data.get("state", current_drone_state)

	var prof = data.get("profile", "Normal")
	_update_mode_buttons_ui(prof.to_lower())

	var is_imp = settings_service.is_imperial() if settings_service else false

	# Mode & State Badges
	var mode_name = data.get("flight_mode", "ANGLE")
	if label_mode_badge:
		label_mode_badge.text = "MODE: %s" % mode_name
	if btn_mode_cycle:
		btn_mode_cycle.text = "MODE: %s" % mode_name

	var state_name = data.get("state", "DISARMED")
	if label_state_badge:
		label_state_badge.text = "STATE: %s" % state_name

	# Procedural Vectors: Artificial Horizon & Heading Strip
	var p_pitch = data.get("pitch", 0.0)
	var p_roll = data.get("roll", 0.0)
	var p_heading = data.get("heading", 0.0)

	if artificial_horizon:
		artificial_horizon.set_attitude(p_pitch, p_roll)
	if heading_strip:
		heading_strip.heading_deg = p_heading

	# Home Arrow & Bearing
	if home_arrow:
		home_arrow.is_imperial = is_imp
		var d_pos = data.get("drone_pos", Vector3.ZERO)
		var h_pos = data.get("home_pos", Vector3.ZERO)
		home_arrow.update_home_vector(d_pos, deg_to_rad(p_heading), h_pos)

	# Battery & Time Remaining
	var pct = data.get("battery_pct", 100.0)
	var volts = data.get("battery_volts", 15.2)
	var t_rem = data.get("battery_time_remaining", 900.0)
	var rem_min = int(t_rem) / 60
	var rem_sec = int(t_rem) % 60

	if label_battery:
		label_battery.text = "🔋 %d%% (%.1fV) [%02d:%02d]" % [int(pct), volts, rem_min, rem_sec]
		if pct < 15.0:
			label_battery.add_theme_color_override("font_color", Color.RED)
		elif pct < 25.0:
			label_battery.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label_battery.add_theme_color_override("font_color", Color(0.2, 0.95, 0.45))

	if battery_progress_bar:
		battery_progress_bar.value = pct

	# Warning Banner for Low Battery
	if pct <= 25.0 and _last_low_battery_alert > 25.0:
		_show_banner("⚠️ LOW BATTERY WARNING (%d%%) — AUTO-RTH AT 15%%" % int(pct), 3.5)
	elif pct <= 15.0 and _last_low_battery_alert > 15.0:
		_show_banner("🚨 CRITICAL BATTERY (%d%%) — AUTO-RTH ACTIVATED" % int(pct), 4.0)
	_last_low_battery_alert = pct

	# RC Signal & GPS
	if label_signal:
		var rc = data.get("rc_signal", 100.0)
		label_signal.text = "((o)) RC %d%%" % int(rc)
	if label_gps:
		var gps_stat = data.get("gps_status", "STANDBY")
		label_gps.text = "📶 GPS (%s)" % ("3D LOCK" if gps_stat == "3D RTK LOCK" else "STANDBY")

	# Speeds (m/s & km/h or ft/s & mph)
	var spd_ms = data.get("speed", 0.0)
	var climb = data.get("climb_rate", 0.0)
	var alt_agl = data.get("altitude_agl", 0.0)
	var alt_msl = data.get("altitude_msl", 0.0)
	var dist = data.get("home_distance", 0.0)

	if label_hs:
		if is_imp:
			var spd_mph = spd_ms * 2.23694
			var spd_fts = spd_ms * 3.28084
			label_hs.text = "SPD: %.1f ft/s (%.1f mph)" % [spd_fts, spd_mph]
		else:
			var spd_kmh = spd_ms * 3.6
			label_hs.text = "SPD: %.1f m/s (%.1f km/h)" % [spd_ms, spd_kmh]

	# Altitudes AGL + MSL
	if label_h:
		if is_imp:
			label_h.text = "ALT: AGL %.1fft | MSL %.1fft" % [alt_agl * 3.28084, alt_msl * 3.28084]
		else:
			label_h.text = "ALT: AGL %.1fm | MSL %.1fm" % [alt_agl, alt_msl]

	# Vertical Speed
	if label_vs:
		if is_imp:
			label_vs.text = "V/S: %+.1f ft/s" % (climb * 3.28084)
		else:
			label_vs.text = "V/S: %+.1f m/s" % climb
		if climb < -2.5:
			label_vs.add_theme_color_override("font_color", Color.RED)
		elif climb > 0.5:
			label_vs.add_theme_color_override("font_color", Color(0.2, 0.95, 0.5))
		else:
			label_vs.add_theme_color_override("font_color", Color(0.8, 0.9, 1))

	if label_d:
		if is_imp:
			label_d.text = "DIST: %.1f ft" % (dist * 3.28084)
		else:
			label_d.text = "DIST: %.1f m" % dist

	# Flip Button Dynamic Visual Gating
	if btn_flip:
		var can_flip = (alt_agl >= 3.0 and state_name in ["FLYING", "HOVER"])
		btn_flip.modulate = Color(1, 1, 1, 1.0) if can_flip else Color(1, 1, 1, 0.4)

	# Terrain / Obstacle proximity
	if sensor_icon and sensor_label:
		if alt_agl < 1.0 and spd_ms > 1.5:
			sensor_icon.text = "((🚨))"
			sensor_icon.add_theme_color_override("font_color", Color.RED)
			sensor_label.text = "TERRAIN CRITICAL"
			if proximity_warning:
				proximity_warning.visible = true
				proximity_warning.text = "⚠️ TERRAIN PROXIMITY ALERT"
		elif alt_agl < 2.5:
			sensor_icon.text = "((⚠️))"
			sensor_icon.add_theme_color_override("font_color", Color.YELLOW)
			sensor_label.text = "ALTITUDE LOW"
			if proximity_warning:
				proximity_warning.visible = false
		else:
			sensor_icon.text = "((🔔))"
			sensor_icon.add_theme_color_override("font_color", Color(0.2, 0.95, 0.5))
			sensor_label.text = "SENSORS NORMAL"
			if proximity_warning:
				proximity_warning.visible = false
