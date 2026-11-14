class_name FlightHUD
extends CanvasLayer

## FlightHUD: Full telemetry overlay, twin-stick virtual joysticks, and drone control action buttons.

@export var input_router: InputRouter
@export var flight_physics: FlightPhysics
@export var camera_director: FlightCameraDirector
@export var audio_director: AudioDirector

# Left and Right Virtual Sticks
@onready var left_joystick: VirtualJoystick = $LeftCluster/LeftJoystick
@onready var right_joystick: VirtualJoystick = $RightCluster/RightJoystick

signal world_select_requested

# Top Telemetry Labels
@onready var label_flight_mode: Label = $TopBar/HBox/ModePill/LabelMode
@onready var label_battery: Label = $TopBar/HBox/BatteryPill/LabelBattery
@onready var label_speed: Label = $TopBar/HBox/SpeedPill/LabelSpeed
@onready var label_altitude: Label = $TopBar/HBox/AltPill/LabelAlt
@onready var label_climb: Label = $TopBar/HBox/ClimbPill/LabelClimb
@onready var label_heading: Label = $TopBar/HBox/HeadingPill/LabelHeading

# Horizon / Pitch-Roll Indicator
@onready var horizon_indicator: Control = get_node_or_null("CenterOverlay/ArtificialHorizon")
@onready var label_state_banner: Label = $CenterOverlay/StateBanner
@onready var proximity_warning: Label = $CenterOverlay/ProximityWarning

# Action Buttons
@onready var btn_takeoff_land: Button = $BottomBar/HBox/BtnTakeoffLand
@onready var btn_camera: Button = $BottomBar/HBox/BtnCamera
@onready var btn_reset: Button = $BottomBar/HBox/BtnReset
@onready var btn_mode: Button = $BottomBar/HBox/BtnMode
@onready var btn_sound: Button = get_node_or_null("BottomBar/HBox/BtnSound")
@onready var btn_engine: Button = get_node_or_null("BottomBar/HBox/BtnEngine")
@onready var btn_stunt: Button = get_node_or_null("BottomBar/HBox/BtnStunt")
@onready var btn_worlds: Button = get_node_or_null("BottomBar/HBox/BtnWorlds")

func _ready() -> void:
	if not audio_director:
		audio_director = get_node_or_null("../AudioDirector")

	if left_joystick:
		left_joystick.stick_moved.connect(_on_left_stick_moved)
		left_joystick.stick_released.connect(_on_left_stick_released)

	if right_joystick:
		right_joystick.stick_moved.connect(_on_right_stick_moved)
		right_joystick.stick_released.connect(_on_right_stick_released)

	if btn_takeoff_land:
		btn_takeoff_land.pressed.connect(_on_btn_takeoff_land_pressed)
	if btn_camera:
		btn_camera.pressed.connect(_on_btn_camera_pressed)
	if btn_reset:
		btn_reset.pressed.connect(_on_btn_reset_pressed)
	if btn_mode:
		btn_mode.pressed.connect(_on_btn_mode_pressed)
	if btn_sound:
		btn_sound.pressed.connect(_on_btn_sound_pressed)
		_update_sound_button_label()
	if btn_engine:
		btn_engine.pressed.connect(_on_btn_engine_pressed)
		_update_engine_button_label()
	if btn_stunt:
		btn_stunt.pressed.connect(_on_btn_stunt_pressed)
	if btn_worlds:
		btn_worlds.pressed.connect(func(): world_select_requested.emit())

	if flight_physics:
		flight_physics.telemetry_updated.connect(_on_telemetry_updated)
		flight_physics.drone_state_changed.connect(_on_drone_state_changed)
		flight_physics.drone_crashed.connect(_on_drone_crashed)
		if flight_physics.stunt_engine:
			flight_physics.stunt_engine.stunt_started.connect(_on_stunt_started)
			flight_physics.stunt_engine.stunt_completed.connect(_on_stunt_completed)
			flight_physics.stunt_engine.stunt_failed.connect(_on_stunt_failed)

func _on_left_stick_moved(vec: Vector2) -> void:
	if input_router:
		input_router.set_virtual_left_stick(vec.x, vec.y)

	# Auto-takeoff when player pushes throttle stick up while disarmed
	if flight_physics and flight_physics.current_state == FlightPhysics.DroneState.DISARMED:
		if vec.y > 0.25:
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

func _on_btn_takeoff_land_pressed() -> void:
	if flight_physics:
		if flight_physics.current_state == FlightPhysics.DroneState.DISARMED:
			flight_physics.takeoff()
		elif flight_physics.current_state == FlightPhysics.DroneState.FLYING:
			flight_physics.land()
	elif input_router:
		input_router.request_takeoff_land()

func _on_btn_sound_pressed() -> void:
	if audio_director:
		audio_director.toggle_mute()
		_update_sound_button_label()

func _update_sound_button_label() -> void:
	if btn_sound:
		var muted = audio_director.is_audio_muted if audio_director else false
		btn_sound.text = "🔇 MUTE" if muted else "🔊 SOUND"

func _on_btn_engine_pressed() -> void:
	if audio_director and audio_director.has_method("cycle_motor_sound_profile"):
		var p_name = audio_director.cycle_motor_sound_profile()
		_update_engine_button_label(p_name)

func _update_engine_button_label(p_name: String = "") -> void:
	if btn_engine:
		if p_name == "" and audio_director and "current_sound_profile" in audio_director:
			p_name = AudioDirector.MotorSoundProfile.keys()[audio_director.current_sound_profile]
		btn_engine.text = "⚙️ %s" % (p_name.to_upper() if p_name != "" else "TURBO")

func _on_btn_camera_pressed() -> void:
	if camera_director:
		camera_director.cycle_camera_mode()
	elif input_router:
		input_router.request_camera_toggle()

func _on_btn_reset_pressed() -> void:
	if input_router:
		input_router.request_reset()

func _on_btn_mode_pressed() -> void:
	if input_router:
		input_router.request_flight_mode_cycle()

func _on_btn_stunt_pressed() -> void:
	if input_router:
		input_router.request_stunt("front_flip")

func _on_stunt_started(stunt_type: String) -> void:
	if label_state_banner:
		label_state_banner.text = "EXECUTING %s..." % stunt_type.to_upper().replace("_", " ")
		label_state_banner.visible = true

func _on_stunt_completed(stunt_type: String, score: int, quality: String) -> void:
	if label_state_banner:
		label_state_banner.text = "STUNT COMPLETE: %s +%d PTS (%s)!" % [stunt_type.to_upper().replace("_", " "), score, quality]
		label_state_banner.visible = true

func _on_stunt_failed(reason: String) -> void:
	if label_state_banner:
		label_state_banner.text = "STUNT ABORTED: %s" % reason
		label_state_banner.visible = true

func _on_telemetry_updated(data: Dictionary) -> void:
	if label_flight_mode:
		var prof = data.get("profile", "NORMAL")
		label_flight_mode.text = prof.to_upper()
		if btn_stunt:
			btn_stunt.visible = (prof.to_upper() in ["ARCADE", "ACRO"])

	if label_battery:
		var pct = data.get("battery_pct", 100.0)
		var volts = data.get("battery_volts", 15.2)
		label_battery.text = "%d%%  (%.1fV)" % [int(pct), volts]
		if pct < 20.0:
			label_battery.add_theme_color_override("font_color", Color.RED)
		elif pct < 40.0:
			label_battery.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label_battery.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))

	if label_speed:
		var spd = data.get("speed", 0.0)
		label_speed.text = "SPD: %.1f m/s" % spd

	if label_altitude:
		var agl = data.get("altitude_agl", 0.0)
		label_altitude.text = "ALT: %.1f m" % agl

	if label_climb:
		var cr = data.get("climb_rate", 0.0)
		var sign_char = "+" if cr >= 0.0 else ""
		label_climb.text = "V/S: %s%.1f m/s" % [sign_char, cr]

	if label_heading:
		var hdg = int(data.get("heading", 0.0))
		var card = _cardinal_direction(hdg)
		label_heading.text = "HDG: %03d° %s" % [hdg, card]

	# Update Takeoff/Land button text based on state
	var state = data.get("state", "DISARMED")
	if btn_takeoff_land:
		if state == "DISARMED":
			btn_takeoff_land.text = "TAKEOFF"
		elif state == "CRASHED":
			btn_takeoff_land.text = "RECOVER"
		else:
			btn_takeoff_land.text = "LAND"

	# Proximity Alert
	if proximity_warning:
		var alt = data.get("altitude_agl", 0.0)
		var spd = data.get("speed", 0.0)
		if alt < 0.6 and state == "FLYING" and spd > 2.0:
			proximity_warning.visible = true
			proximity_warning.text = "⚠️ TERRAIN PROXIMITY"
		else:
			proximity_warning.visible = false

func _on_drone_state_changed(state_name: String) -> void:
	if label_state_banner:
		match state_name:
			"TAKING_OFF":
				label_state_banner.text = "LIFTOFF SEQUENCE ACTIVE"
				label_state_banner.visible = true
			"LANDING":
				label_state_banner.text = "AUTOLAND ACTIVE"
				label_state_banner.visible = true
			"CRASHED":
				label_state_banner.text = "CRASH DETECTED — PRESS RESET"
				label_state_banner.visible = true
			_:
				label_state_banner.visible = false

func _on_drone_crashed(impact: float) -> void:
	if label_state_banner:
		label_state_banner.text = "CRASH (IMPACT %.1f m/s) — PRESS R TO RESET" % impact
		label_state_banner.visible = true

func _cardinal_direction(deg: int) -> String:
	if deg >= 338 or deg < 23:
		return "N"
	elif deg < 68:
		return "NE"
	elif deg < 113:
		return "E"
	elif deg < 158:
		return "SE"
	elif deg < 203:
		return "S"
	elif deg < 248:
		return "SW"
	elif deg < 293:
		return "W"
	else:
		return "NW"
