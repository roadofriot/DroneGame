class_name FlightHUD
extends CanvasLayer

## FlightHUD: Full telemetry overlay, twin-stick virtual joysticks, and drone control action buttons.

@export var input_router: InputRouter
@export var flight_physics: FlightPhysics
@export var camera_director: FlightCameraDirector

# Left and Right Virtual Sticks
@onready var left_joystick: VirtualJoystick = $LeftCluster/LeftJoystick
@onready var right_joystick: VirtualJoystick = $RightCluster/RightJoystick

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

func _ready() -> void:
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

	if flight_physics:
		flight_physics.telemetry_updated.connect(_on_telemetry_updated)
		flight_physics.drone_state_changed.connect(_on_drone_state_changed)
		flight_physics.drone_crashed.connect(_on_drone_crashed)

func _on_left_stick_moved(vec: Vector2) -> void:
	if input_router:
		input_router.set_virtual_left_stick(vec.x, vec.y)

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
	if input_router:
		input_router.request_takeoff_land()

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

func _on_telemetry_updated(data: Dictionary) -> void:
	if label_flight_mode:
		label_flight_mode.text = data.get("profile", "NORMAL").to_upper()

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
