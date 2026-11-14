class_name FlightCameraDirector
extends Node3D

## FlightCameraDirector: Multi-camera manager supporting Chase, FPV, Orbit, and Top-Down.

enum CameraMode { CHASE, FPV, ORBIT, TOP_DOWN }

@export var target_drone: FlightPhysics
@export var chase_camera: Camera3D
@export var fpv_camera: Camera3D

# Chase camera tuning
@export var chase_distance: float = 3.2
@export var chase_height: float = 1.1
@export var position_smooth_speed: float = 8.0
@export var rotation_smooth_speed: float = 12.0
@export var velocity_lookahead_factor: float = 0.25

var current_mode: CameraMode = CameraMode.CHASE
var orbit_angle: float = 0.0

func _ready() -> void:
	set_camera_mode(CameraMode.CHASE)

func set_camera_mode(mode: CameraMode) -> void:
	current_mode = mode
	match current_mode:
		CameraMode.CHASE, CameraMode.ORBIT, CameraMode.TOP_DOWN:
			if chase_camera:
				chase_camera.current = true
			if fpv_camera:
				fpv_camera.current = false
		CameraMode.FPV:
			if fpv_camera:
				fpv_camera.current = true
			if chase_camera:
				chase_camera.current = false

func cycle_camera_mode() -> void:
	var next_mode = (current_mode + 1) % 4
	set_camera_mode(next_mode as CameraMode)

func _physics_process(delta: float) -> void:
	if not target_drone:
		return

	match current_mode:
		CameraMode.CHASE:
			_update_chase_camera(delta)
		CameraMode.ORBIT:
			_update_orbit_camera(delta)
		CameraMode.TOP_DOWN:
			_update_top_down_camera(delta)
		CameraMode.FPV:
			pass # FPV camera is a child of the drone's gimbal mount

func _update_chase_camera(delta: float) -> void:
	if not chase_camera:
		return

	var drone_pos = target_drone.global_position
	var drone_basis = target_drone.global_transform.basis

	# Camera stays behind the drone along drone's horizontal facing direction
	var forward = -drone_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	var target_cam_pos = drone_pos - (forward * chase_distance) + (Vector3.UP * chase_height)

	# Velocity lookahead
	var vel_offset = target_drone.linear_velocity * velocity_lookahead_factor
	var look_target = drone_pos + (forward * 0.8) + (vel_offset * 0.3)

	chase_camera.global_position = chase_camera.global_position.lerp(target_cam_pos, position_smooth_speed * delta)
	var cur_rot = chase_camera.global_transform.basis
	chase_camera.look_at(look_target, Vector3.UP)
	var target_rot = chase_camera.global_transform.basis
	chase_camera.global_transform.basis = cur_rot.slerp(target_rot, rotation_smooth_speed * delta)

func _update_orbit_camera(delta: float) -> void:
	if not chase_camera:
		return
	orbit_angle += deg_to_rad(25.0) * delta
	var drone_pos = target_drone.global_position
	var offset = Vector3(sin(orbit_angle) * chase_distance, chase_height * 1.2, cos(orbit_angle) * chase_distance)
	chase_camera.global_position = drone_pos + offset
	chase_camera.look_at(drone_pos, Vector3.UP)

func _update_top_down_camera(delta: float) -> void:
	if not chase_camera:
		return
	var drone_pos = target_drone.global_position
	var target_pos = drone_pos + Vector3(0.0, 7.5, 0.0)
	chase_camera.global_position = chase_camera.global_position.lerp(target_pos, position_smooth_speed * delta)
	chase_camera.look_at(drone_pos, Vector3.FORWARD)
