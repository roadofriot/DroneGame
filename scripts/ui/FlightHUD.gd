class_name FlightHUD
extends CanvasLayer

## FlightHUD: Professional Drone Telemetry HUD & Remote Controller Interface.
## Built to exactly match the Drone Controller Guide specification:
## - Top bar: Location, GPS strength, Battery %, RC Signal strength, Satellites, 4K 60fps REC, Menu.
## - Left vertical: Gimbal Tilt / Zoom adjustment (+, Reset, -).
## - Left stick: Throttle / Yaw with 8 directional arrows and bilingual axis indicators.
## - Center controls: Cine/Normal/Sport mode buttons, Failsafe, Take Off / Land, RTH, Camera View toggle.
## - Right side: Telemetry stats (H, HS, D) and Obstacle Avoidance Sensor status.
## - Right stick: Pitch / Roll with 8 directional arrows and bilingual axis indicators.
## - Settings drawer: Drone motor sound ON/OFF, Engine sound profile, Master audio, Reset to pad, Worlds.

signal world_select_requested

@export var input_router: InputRouter
@export var flight_physics: FlightPhysics
@export var camera_director: FlightCameraDirector
@export var audio_director: AudioDirector

# Virtual Joysticks
@onready var left_joystick: VirtualJoystick = get_node_or_null("LeftCluster/LeftJoystick")
@onready var right_joystick: VirtualJoystick = get_node_or_null("RightCluster/RightJoystick")

# Top Bar Elements
@onready var btn_location: Button = get_node_or_null("TopBar/HBox/BtnLocation")
@onready var label_gps: Label = get_node_or_null("TopBar/HBox/GPSPill/LabelGPS")
@onready var label_battery: Label = get_node_or_null("TopBar/HBox/BatteryPill/LabelBattery")
@onready var label_signal: Label = get_node_or_null("TopBar/HBox/SignalPill/LabelSignal")
@onready var label_satellites: Label = get_node_or_null("TopBar/HBox/SatPill/LabelSatellites")
@onready var label_camera_status: Label = get_node_or_null("TopBar/HBox/CamStatusPill/LabelCameraStatus")
@onready var btn_menu: Button = get_node_or_null("TopBar/HBox/BtnMenu")

# Left Zoom / Gimbal Controls
@onready var btn_zoom_in: Button = get_node_or_null("LeftZoomColumn/BtnZoomIn")
@onready var btn_zoom_reset: Button = get_node_or_null("LeftZoomColumn/BtnZoomReset")
@onready var btn_zoom_out: Button = get_node_or_null("LeftZoomColumn/BtnZoomOut")

# Center Controls
@onready var btn_mode_cine: Button = get_node_or_null("CenterControls/ModeContainer/ModeHBox/BtnModeCine")
@onready var btn_mode_normal: Button = get_node_or_null("CenterControls/ModeContainer/ModeHBox/BtnModeNormal")
@onready var btn_mode_sport: Button = get_node_or_null("CenterControls/ModeContainer/ModeHBox/BtnModeSport")
@onready var btn_failsafe: Button = get_node_or_null("CenterControls/ActionHBox/BtnFailsafe")
@onready var btn_takeoff: Button = get_node_or_null("CenterControls/ActionHBox/BtnTakeoff")
@onready var btn_rth: Button = get_node_or_null("CenterControls/ActionHBox/BtnRTH")
@onready var btn_cam_toggle: Button = get_node_or_null("CenterControls/ActionHBox/BtnCamToggle")
@onready var btn_flip: Button = get_node_or_null("CenterControls/ActionHBox/BtnFlip")

# Right Telemetry & Sensor Cluster
@onready var label_h: Label = get_node_or_null("RightTelemetryCluster/TelemetryBox/VBox/LabelH")
@onready var label_hs: Label = get_node_or_null("RightTelemetryCluster/TelemetryBox/VBox/LabelHS")
@onready var label_d: Label = get_node_or_null("RightTelemetryCluster/TelemetryBox/VBox/LabelD")
@onready var sensor_icon: Label = get_node_or_null("RightTelemetryCluster/SensorBox/HBox/SensorIcon")
@onready var sensor_label: Label = get_node_or_null("RightTelemetryCluster/SensorBox/HBox/SensorLabel")

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

func _ready() -> void:
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

	# Auto-takeoff assistance when player pushes throttle stick up while disarmed
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
# Mode Selection (Cine, Normal, Sport)
# -----------------------------------------------------------------------------
func _set_flight_mode_profile(mode_name: String) -> void:
	active_flight_mode = mode_name.to_lower()
	if flight_physics:
		flight_physics.set_flight_profile(active_flight_mode)
	_update_mode_buttons_ui(active_flight_mode)
	var title = "सामान्य (Normal)"
	if active_flight_mode == "cine":
		title = "सिनेमाई (Cine Smooth)"
	elif active_flight_mode == "sport":
		title = "खेलकुद (Sport Agility)"
	_show_banner("उडान मोड: %s" % title, 2.0)

func _update_mode_buttons_ui(mode_name: String) -> void:
	# Update button text/highlights
	if btn_mode_cine:
		btn_mode_cine.text = "★ Cine (सिनेमाई)" if mode_name == "cine" else "Cine (सिनेमाई)"
	if btn_mode_normal:
		btn_mode_normal.text = "★ Normal (सामान्य)" if mode_name == "normal" else "Normal (सामान्य)"
	if btn_mode_sport:
		btn_mode_sport.text = "★ Sport (खेलकुद)" if mode_name == "sport" else "Sport (खेलकुद)"

# -----------------------------------------------------------------------------
# Primary Action Buttons (Take Off, Land, RTH, Failsafe)
# -----------------------------------------------------------------------------
func _on_btn_takeoff_pressed() -> void:
	if flight_physics:
		if flight_physics.current_state == FlightPhysics.DroneState.DISARMED:
			flight_physics.takeoff()
		elif flight_physics.current_state == FlightPhysics.DroneState.CRASHED:
			flight_physics.reset_to_pad()
			_show_banner("DRONE RECOVERED TO LAUNCH PAD", 2.5)
		else:
			# If airborne, button functions as Land
			flight_physics.land()
	elif input_router:
		input_router.takeoff_requested.emit()

func _on_btn_rth_pressed() -> void:
	if flight_physics:
		if flight_physics.current_state == FlightPhysics.DroneState.RTH:
			flight_physics.cancel_rth()
			_show_banner("RTH रद्द गरियो — नियन्त्रण फिर्ता (Manual Restored)", 2.5)
			if btn_rth:
				btn_rth.text = "🏠 RTH"
		else:
			if flight_physics.trigger_rth():
				_show_banner("स्वचालित घर फर्किने सुरु (RTH Active)", 3.0)
				if btn_rth:
					btn_rth.text = "❌ RTH रोक्नुहोस्"
			else:
				_show_banner("RTH उपलब्ध छैन: ड्रोन हावामा छैन", 2.5)
	elif input_router:
		input_router.rth_requested.emit()

func _on_btn_failsafe_pressed() -> void:
	if flight_physics:
		if flight_physics.current_state in [
			FlightPhysics.DroneState.FLYING,
			FlightPhysics.DroneState.HOVER,
			FlightPhysics.DroneState.TAKEOFF
		]:
			# Trigger Failsafe RTH or controlled emergency autoland
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
	_show_banner("क्यामेरा दृश्य: %s" % mode_name.to_upper(), 1.5)

func _on_btn_flip_pressed() -> void:
	if not flight_physics:
		return
	if flight_physics.current_state != FlightPhysics.DroneState.FLYING and flight_physics.current_state != FlightPhysics.DroneState.HOVER:
		_show_banner("हवामा उड्दा मात्र फ्लिप गर्न सकिन्छ (Fly before flipping)", 2.0)
		return

	# Choose flip based on last right stick movement or cycle
	var stunt_type = "front_flip"
	if right_joystick and right_joystick.stick_vector.length() > 0.35:
		var sv = right_joystick.stick_vector
		if absf(sv.y) >= absf(sv.x):
			stunt_type = "front_flip" if sv.y > 0.0 else "back_flip"
		else:
			stunt_type = "barrel_roll_right" if sv.x > 0.0 else "barrel_roll_left"
	else:
		var stunts = ["front_flip", "barrel_roll_left", "back_flip", "barrel_roll_right"]
		stunt_type = stunts[randi() % stunts.size()]

	if flight_physics.stunt_engine:
		flight_physics.stunt_engine.custom_stunts_enabled = true
		var success = flight_physics.stunt_engine.execute_stunt(stunt_type, flight_physics)
		flight_physics.stunt_engine.custom_stunts_enabled = false
		if success:
			_show_banner("🤸 %s EXECUTED!" % stunt_type.to_upper().replace("_", " "), 2.0)
		else:
			var check = flight_physics.stunt_engine.can_perform_stunt(flight_physics)
			_show_banner("⚠️ " + check.get("reason", "Cannot perform stunt"), 2.0)

# -----------------------------------------------------------------------------
# Settings Drawer & Audio Toggles
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
		btn_drone_sound.text = "🚁 ड्रोन साउन्ड: OFF" if muted else "🚁 ड्रोन साउन्ड: ON"

func _on_btn_engine_pressed() -> void:
	if audio_director and audio_director.has_method("cycle_motor_sound_profile"):
		var p_name = audio_director.cycle_motor_sound_profile()
		_update_engine_button_label(p_name)
		_show_banner("इन्जिन साउन्ड प्रोफाइल: %s" % p_name.to_upper(), 2.0)

func _update_engine_button_label(p_name: String = "") -> void:
	if btn_engine:
		if p_name == "" and audio_director and "current_sound_profile" in audio_director:
			p_name = AudioDirector.MotorSoundProfile.keys()[audio_director.current_sound_profile]
		btn_engine.text = "⚙️ इन्जिन: %s" % (p_name.to_upper() if p_name != "" else "TURBO")

func _on_btn_sound_pressed() -> void:
	if audio_director:
		audio_director.toggle_all_sound()
		_update_sound_button_label()

func _update_sound_button_label() -> void:
	if btn_sound:
		var muted = audio_director.is_audio_muted if audio_director else false
		btn_sound.text = "🔇 मास्टर साउन्ड: MUTE" if muted else "🔊 मास्टर साउन्ड: ON"

func _on_btn_reset_pressed() -> void:
	if flight_physics:
		flight_physics.reset_to_pad()
		_show_banner("प्याडमा रिसेट भयो (Reset to Launch Pad)", 2.5)
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

func _on_preflight_failed(reason: String) -> void:
	_show_banner("उडान सुरु गर्न सकिएन: %s" % reason.to_upper(), 4.0)

func _on_flight_boundary_reached(boundary_type: String) -> void:
	if boundary_type == "MAX_ALTITUDE":
		_show_banner("⚠️ अधिकतम उचाइ सीमा पुग्यो (६० मि.)", 2.5)
	else:
		_show_banner("⚠️ जियोफेन्स सीमा पुग्यो (Geofence Breach)", 2.5)

func _on_rth_state_changed(is_active: bool, distance: float) -> void:
	if btn_rth:
		btn_rth.text = "❌ RTH रोक्नुहोस्" if is_active else "🏠 RTH"
	if is_active:
		_show_banner("घर फर्किंदै छ — दुरी: %.1f मि." % distance, 3.5)

func _on_drone_crashed(impact: float) -> void:
	_show_banner("क्र्यास भयो (प्रभाव %.1f m/s) — रिसेट थिच्नुहोस्" % impact, 5.0)

func _on_drone_state_changed(state_name: String) -> void:
	match state_name:
		"PREFLIGHT_CHECK":
			_show_banner("प्रि-फ्लाइट परीक्षण सफल (Ready)", 2.0)
		"MOTOR_STARTING":
			_show_banner("मोटरहरू सुरु हुँदै...", 2.0)
		"TAKEOFF":
			_show_banner("उडान सुरु (३ मिटर उचाइ लक्ष्य)...", 3.0)
		"HOVER":
			_show_banner("उचाइ स्थिर — जोइस्टिक सक्रिय", 2.5)
		"LANDING":
			_show_banner("स्वचालित अवतरण (Autoland Active)...", 3.0)
		"RTH":
			_show_banner("स्वचालित घर फर्किने (RTH Active)...", 3.5)
		"DISARMED":
			_show_banner("मोटरहरू बन्द — टेक-अफका लागि तयार", 2.5)

	# Update Takeoff button text dynamically
	if btn_takeoff:
		if state_name == "DISARMED":
			btn_takeoff.text = "🛫 Take Off"
			btn_takeoff.disabled = false
		elif state_name == "CRASHED":
			btn_takeoff.text = "🔄 Recover"
			btn_takeoff.disabled = false
		else:
			btn_takeoff.text = "🛬 Land"
			btn_takeoff.disabled = false

func _on_telemetry_updated(data: Dictionary) -> void:
	var prof = data.get("profile", "Normal")
	_update_mode_buttons_ui(prof.to_lower())

	# Battery
	if label_battery:
		var pct = data.get("battery_pct", 100.0)
		var volts = data.get("battery_volts", 15.2)
		label_battery.text = "🔋 %d%% (%.1fV)" % [int(pct), volts]
		if pct < 20.0:
			label_battery.add_theme_color_override("font_color", Color.RED)
		elif pct < 40.0:
			label_battery.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label_battery.add_theme_color_override("font_color", Color(0.2, 0.95, 0.45))

	# RC Signal
	if label_signal:
		var rc = data.get("rc_signal", 100.0)
		label_signal.text = "((o)) RC सिग्नल बल (%d%%)" % int(rc)

	# Satellites & GPS
	if label_gps:
		var gps_stat = data.get("gps_status", "STANDBY")
		label_gps.text = "📶 GPS सिग्नल (%s)" % ("बलियो" if gps_stat == "3D RTK LOCK" else "मध्यम")

	# Telemetry Box (Right side)
	var alt = data.get("altitude_agl", 0.0)
	var spd = data.get("speed", 0.0)
	var dist = data.get("home_distance", 0.0)

	if label_h:
		label_h.text = "H:  %.1f मि. (हवाई उचाइ)" % alt
	if label_hs:
		label_hs.text = "HS: %.1f मि./से (स्पीड)" % spd
	if label_d:
		label_d.text = "D:  %.1f मि. (दुरी)" % dist

	# Obstacle Avoidance Sensor & Proximity
	if sensor_icon and sensor_label:
		if alt < 1.0 and spd > 1.5:
			sensor_icon.text = "((🚨))"
			sensor_icon.add_theme_color_override("font_color", Color.RED)
			sensor_label.text = "चेतावनी: नजिक अवरोध!\nTerrain Critical Warning"
			if proximity_warning:
				proximity_warning.visible = true
				proximity_warning.text = "⚠️ TERRAIN PROXIMITY ALERT"
		elif alt < 2.5:
			sensor_icon.text = "((⚠️))"
			sensor_icon.add_theme_color_override("font_color", Color.YELLOW)
			sensor_label.text = "चेतावनी: जमिन नजिक\nAltitude Low Caution"
			if proximity_warning:
				proximity_warning.visible = false
		else:
			sensor_icon.text = "((🔔))"
			sensor_icon.add_theme_color_override("font_color", Color(0.2, 0.95, 0.5))
			sensor_label.text = "चेतावनी र सेन्सर:\nObstacle Sensor Active"
			if proximity_warning:
				proximity_warning.visible = false
