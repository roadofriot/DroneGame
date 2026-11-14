class_name DroneRig
extends Node3D

## DroneRig: Visual presentation, procedural drone assembly, rotor spin animation,
## high-RPM blur disc swapping, state/nav LEDs, and gimbal camera stabilization.

const DroneSpec = preload("res://scripts/flight/DroneSpec.gd")
const DroneModelBuilder = preload("res://scripts/flight/DroneModelBuilder.gd")

@export var flight_physics: FlightPhysics
@export var drone_spec: DroneSpec
@export var use_procedural_model: bool = false # When true, builds procedural model from drone_spec

@export_group("Legacy Rig References")
@export var gimbal_pitch_mount: Node3D
@export var gimbal_camera: Camera3D
@export var prop_fl: Node3D
@export var prop_fr: Node3D
@export var prop_rl: Node3D
@export var prop_rr: Node3D

# Visual Rotor RPM scale
@export var max_rotor_speed_rad: float = 85.0
@export var blur_threshold_rpm: float = 0.38

# Gimbal Pitch Tilt Target
var gimbal_pitch_target_deg: float = -15.0 # Slight downward tilt for FPV framing

# Procedural model references
var procedural_data: Dictionary = {}
var _anim_time: float = 0.0

func _ready() -> void:
	if use_procedural_model and drone_spec:
		apply_drone_spec(drone_spec)

func apply_drone_spec(spec: DroneSpec) -> void:
	drone_spec = spec
	if not drone_spec:
		return

	# Hide legacy static nodes if procedural model is requested
	var fuselage = get_node_or_null("Fuselage")
	if fuselage: fuselage.visible = false
	for arm_name in ["Arm_FL", "Arm_FR", "Arm_RL", "Arm_RR"]:
		var a = get_node_or_null(arm_name)
		if a: a.visible = false

	# Build procedural mesh hierarchy
	procedural_data = DroneModelBuilder.build_drone(self, drone_spec)

	# If flight_physics exists, update its physics with the spec
	if flight_physics and flight_physics.flight_controller:
		var phys_dict = drone_spec.get_physical_dict()
		flight_physics.drone_mass = drone_spec.mass
		flight_physics.mass = drone_spec.mass
		flight_physics.arm_length = drone_spec.arm_length
		flight_physics.max_thrust_per_motor = drone_spec.max_motor_thrust
		flight_physics.flight_controller.configure(flight_physics.active_profile, phys_dict)

func _process(delta: float) -> void:
	_anim_time += delta
	var rpms: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var current_state_name: String = "DISARMED"
	var altitude_agl: float = 0.0
	var body_pitch: float = 0.0
	var battery_pct: float = 100.0

	if flight_physics:
		rpms = flight_physics.motor_rpms
		altitude_agl = flight_physics.altitude_agl
		body_pitch = flight_physics.pitch_deg
		battery_pct = flight_physics.battery_percent
		if flight_physics.state_machine:
			current_state_name = flight_physics.state_machine.get_state_name()
		else:
			current_state_name = FlightPhysics.DroneState.keys()[flight_physics.current_state]

	# 1. Animate Procedural Model (if active)
	if not procedural_data.is_empty():
		_animate_procedural_drone(rpms, delta, current_state_name, altitude_agl, body_pitch, battery_pct)

	# 2. Animate Legacy Pre-baked Mesh Nodes (for backward compatibility)
	# FL (CW = -rotation.y), FR (CCW = +rotation.y)
	# RL (CCW = +rotation.y), RR (CW = -rotation.y)
	if prop_fl and prop_fl.visible:
		prop_fl.rotate_y(-rpms[0] * max_rotor_speed_rad * delta)
	if prop_fr and prop_fr.visible:
		prop_fr.rotate_y(rpms[1] * max_rotor_speed_rad * delta)
	if prop_rl and prop_rl.visible:
		prop_rl.rotate_y(rpms[2] * max_rotor_speed_rad * delta)
	if prop_rr and prop_rr.visible:
		prop_rr.rotate_y(-rpms[3] * max_rotor_speed_rad * delta)

	# 3. Gimbal stabilization against body pitch
	if gimbal_pitch_mount:
		var target_local_pitch = deg_to_rad(gimbal_pitch_target_deg - body_pitch)
		gimbal_pitch_mount.rotation.x = lerp_angle(gimbal_pitch_mount.rotation.x, target_local_pitch, 10.0 * delta)

func _animate_procedural_drone(rpms: Array[float], delta: float, state_name: String, agl: float, body_pitch: float, battery_pct: float) -> void:
	var rotors = procedural_data.get("rotors", [])
	var blur_discs = procedural_data.get("blur_discs", [])
	var blades = procedural_data.get("blades", [])

	# Motor rotations & Prop Blur Discs
	# 0: FL (CW: -Y), 1: FR (CCW: +Y), 2: RL (CCW: +Y), 3: RR (CW: -Y)
	var dirs = [-1.0, 1.0, 1.0, -1.0]
	for i in range(mini(4, rotors.size())):
		var r_node: Node3D = rotors[i]
		if r_node:
			r_node.rotate_y(dirs[i] * rpms[i] * max_rotor_speed_rad * delta)

		var is_fast = (rpms[i] >= blur_threshold_rpm)
		if i < blur_discs.size() and blur_discs[i]:
			blur_discs[i].visible = is_fast
		if i < blades.size() and blades[i]:
			blades[i].visible = not is_fast

	# Camera Gimbal Stabilization
	var gimbal: Node3D = procedural_data.get("gimbal", null)
	if gimbal:
		var target_local_pitch = deg_to_rad(gimbal_pitch_target_deg - body_pitch)
		gimbal.rotation.x = lerp_angle(gimbal.rotation.x, target_local_pitch, 10.0 * delta)

	# Dynamic Contact Ground Shadow
	var shadow: MeshInstance3D = procedural_data.get("contact_shadow", null)
	if shadow:
		# Reposition shadow locally to project down to ground (clamped)
		shadow.position.y = -agl
		var scale_factor = clampf(1.0 / (1.0 + agl * 0.45), 0.15, 1.0)
		shadow.scale = Vector3(scale_factor, 1.0, scale_factor)
		if shadow.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = shadow.material_override
			mat.albedo_color.a = clampf(0.65 * scale_factor, 0.0, 0.65)

	# State Beacon LED Multi-Mode Signaling
	# DISARMED: slow red pulse (1 Hz)
	# ARMED / FLYING: solid green
	# FLIPPING: solid cyan
	# LOW BATTERY (< 20%): fast blinking red (4 Hz)
	# CRASHED: off / dark
	var mat_led: StandardMaterial3D = procedural_data.get("mat_state_led", null)
	if mat_led:
		match state_name:
			"DISARMED":
				var pulse = (sin(_anim_time * 3.0) + 1.0) * 0.5 # 0.0 to 1.0
				mat_led.albedo_color = Color(1.0 * pulse, 0.1, 0.1, 1.0)
				mat_led.emission = mat_led.albedo_color
				mat_led.emission_energy_multiplier = 0.5 + pulse * 2.5
			"FLYING", "HOVER", "TAKEOFF", "LANDING", "RTH":
				if battery_pct < 20.0:
					# Fast blink red for low battery
					var blink = 1.0 if fmod(_anim_time, 0.25) > 0.125 else 0.1
					mat_led.albedo_color = Color(blink, 0.0, 0.0, 1.0)
					mat_led.emission = mat_led.albedo_color
					mat_led.emission_energy_multiplier = 3.5 * blink
				else:
					mat_led.albedo_color = Color(0.1, 0.95, 0.2, 1.0)
					mat_led.emission = mat_led.albedo_color
					mat_led.emission_energy_multiplier = 3.0
			"FLIPPING":
				mat_led.albedo_color = Color(0.1, 0.85, 1.0, 1.0)
				mat_led.emission = mat_led.albedo_color
				mat_led.emission_energy_multiplier = 4.0
			"CRASHED":
				mat_led.albedo_color = Color(0.1, 0.02, 0.02, 1.0)
				mat_led.emission = Color(0.0, 0.0, 0.0, 1.0)
				mat_led.emission_energy_multiplier = 0.0
