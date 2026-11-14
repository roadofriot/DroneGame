class_name DroneRig
extends Node3D

## DroneRig: Visual presentation, rotor spin animation, and gimbal camera stabilization.

@export var flight_physics: FlightPhysics
@export var gimbal_pitch_mount: Node3D
@export var gimbal_camera: Camera3D

# Propeller Mesh Nodes
@export var prop_fl: Node3D
@export var prop_fr: Node3D
@export var prop_rl: Node3D
@export var prop_rr: Node3D

# Visual Rotor RPM scale
@export var max_rotor_speed_rad: float = 85.0

# Gimbal Pitch Tilt Target
var gimbal_pitch_target_deg: float = -15.0 # Slight downward tilt for FPV framing

func _process(delta: float) -> void:
	if not flight_physics:
		return

	var rpms = flight_physics.motor_rpms

	# Spin propellers:
	# FL (CW = -rotation.y), FR (CCW = +rotation.y)
	# RL (CCW = +rotation.y), RR (CW = -rotation.y)
	if prop_fl:
		prop_fl.rotate_y(-rpms[0] * max_rotor_speed_rad * delta)
	if prop_fr:
		prop_fr.rotate_y(rpms[1] * max_rotor_speed_rad * delta)
	if prop_rl:
		prop_rl.rotate_y(rpms[2] * max_rotor_speed_rad * delta)
	if prop_rr:
		prop_rr.rotate_y(-rpms[3] * max_rotor_speed_rad * delta)

	# Gimbal stabilization
	if gimbal_pitch_mount:
		# Stabilize against body pitch
		var body_pitch = flight_physics.pitch_deg
		var target_local_pitch = deg_to_rad(gimbal_pitch_target_deg - body_pitch)
		gimbal_pitch_mount.rotation.x = lerp_angle(gimbal_pitch_mount.rotation.x, target_local_pitch, 10.0 * delta)
